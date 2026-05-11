# BurgerPyramid 층별 승급 통계 추적 구현

> 작성일: 2026-05-11  
> 브랜치: feature/juwon/Event  
> 목적: 기획자가 BurgerPyramid 이벤트의 층별 승급 경로(일반 잭팟 / 층 천장 / 글로벌 천장)와 층별 실제 스핀 횟수를 시즌 단위로 분석할 수 있도록 데이터 수집 로직 추가

---

## 배경

기획자가 유저들이 각 층을 어떤 경로로 승급하는지 분석하고 싶다는 요청이 있었음.  
기존 테이블에는 현재 플로어(`bpCurrentFloor`)와 층별 스핀 횟수(`bpFloorSpinCounts`)만 존재했으나,  
`bpFloorSpinCounts`는 타겟 수령 시 초기화되기 때문에 누적 이력이 남지 않는 구조였음.

---

## 승급 경로 분류

BurgerPyramid에는 층 승급을 유발하는 경로가 정확히 세 가지 존재한다.

| 경로 | 발생 조건 | 코드 진입점 |
|---|---|---|
| **일반 잭팟** | 랜덤 확률로 잭팟 당첨 | `SpinAsync()` → `AdvanceFloor(isPity: false)` |
| **층 천장** | 해당 층 스핀 횟수가 임계값(60/40/30/20) 도달 | `SpinAsync()` → `AdvanceFloor(isPity: true)` |
| **글로벌 천장** | 전체 스핀 횟수가 150 도달 | `HandleGlobalGuaranteed()` → 직접 5층으로 점프 |

글로벌 천장은 `AdvanceFloor()`를 거치지 않고 `bpCurrentFloor`를 `MaxFloor`로 직접 설정하는 코드 경로임에 주의.

### 글로벌 천장은 항상 4층(MaxFloor-1)에서만 발동

`AdvanceFloor()`는 잭팟이 천장보다 일찍 터진 경우 미사용 스핀을 `bpTotalSpins`에 패딩한다.

```csharp
int unusedSpins = GetFloorPityThreshold(oldFloor) - GetFloorSpinCount(oldFloor);
if (unusedSpins > 0)
    _saveData.bpTotalSpins += unusedSpins;
```

이 패딩으로 인해 잭팟 타이밍과 무관하게 각 층 승급 후 `bpTotalSpins`는 항상 해당 층까지의 누적 임계값과 같아진다.

```
층 1 완료 → bpTotalSpins = 60   (패딩 포함)
층 2 완료 → bpTotalSpins = 100
층 3 완료 → bpTotalSpins = 130
층 4 — 20번째 스핀 → bpTotalSpins = 150 = GlobalGuaranteedThreshold → 글로벌 천장 발동
```

`60 + 40 + 30 + 20 = 150`이므로 글로벌 천장은 구조적으로 4층에서만 발동된다.  
따라서 배열이 아닌 단일 int `global_pity_triggered`(0 또는 1)로 충분하다.

> **주의**: `GlobalGuaranteedThreshold = 150`은 코드에서 `const int`로 정의되어 있다.  
> 각 층 임계값(60+40+30+20)은 SO에서 런타임 로드되지만, const와 SO 합이 일치해야 단일 int 설계가 유효하다.  
> 층별 임계값을 변경하는 경우 반드시 이 const도 함께 업데이트해야 한다.

---

## 추가된 데이터

### 1. `BurgerPyramidSaveData` — 필드 추가 (`SaveDataTypes.cs`)

```csharp
// 층별 승급 통계 (타겟 수령 시 서버 전송 후 초기화)
public int[] bpCycleJackpotAdvanceCounts = new int[5];    // 층별 일반 잭팟 승급 여부
public int[] bpCycleFloorPityAdvanceCounts = new int[5];  // 층별 층 천장 승급 여부
public int bpCycleGlobalPityTriggered = 0;                // 글로벌 천장 발동 여부 (단일 int)
```

- **단위**: 사이클(타겟 수령 1회 = 1사이클)
- **인덱스**: `[0]` = 1층→2층, `[1]` = 2층→3층, `[2]` = 3층→4층, `[3]` = 4층→5층
- **초기화 시점**: 타겟 수령 후 `ResetField()` 호출 시, 시즌 변경 시 `ResetForNewSeason()` 호출 시
- **인덱스 [4] 항상 0**: `bpCycleJackpotAdvanceCounts[4]`와 `bpCycleFloorPityAdvanceCounts[4]`는 항상 0이다. 5층은 타겟 지급층이므로 잭팟/층 천장 승급 자체가 없다.

### 2. `BurgerPyramidRecordRequest` — 4개 필드 추가 (`BurgerPyramidServerTypes.cs`)

```csharp
public int[] jackpot_advance_counts;    // 층별 일반 잭팟 승급 여부 (0 또는 1)
public int[] floor_pity_advance_counts; // 층별 층 천장 승급 여부 (0 또는 1)
public int global_pity_triggered;       // 글로벌 천장 발동 여부 (0 또는 1)
public int[] floor_spin_counts;         // 층별 실제 스핀 횟수
```

기존 타겟 수령 기록 요청(`/burgerpyramid/record`)에 포함되어 서버로 전송됨.

**승급 타입 필드들과 스핀 횟수 배열을 함께 보내는 이유:**  
스핀 횟수만으로도 층 천장 여부를 역산할 수 있지만(`floor_spin_counts[i] == threshold[i]`이면 층 천장),  
그러려면 서버가 시즌별 임계값을 알고 있어야 한다. 임계값이 시즌마다 바뀔 수 있으므로  
명시적 타입 필드를 함께 전송해 서버 쿼리를 단순하게 유지한다.

---

## 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `SaveDataTypes.cs` | `BurgerPyramidSaveData`에 배열 2개 + int 1개 추가 |
| `BurgerPyramidServerTypes.cs` | `BurgerPyramidRecordRequest`에 배열 3개 + int 1개 추가 |
| `EventBurgerPyramidService.cs` | JSON 직렬화 시 배열 3개는 `JArray`, int 1개는 그대로 포함 |
| `BurgerPyramidManager.cs` | 승급 기록 로직 4곳 수정 (하단 상세 참조) |

---

## `BurgerPyramidManager.cs` 변경 상세

### (1) `AdvanceFloor(bool isPity = false)` — 파라미터 추가 및 기록

```csharp
// 변경 전
public Dictionary<ECurrencyType, int> AdvanceFloor()

// 변경 후
public Dictionary<ECurrencyType, int> AdvanceFloor(bool isPity = false)
{
    int oldFloor = _saveData.bpCurrentFloor;
    if (isPity)
        _saveData.bpCycleFloorPityAdvanceCounts[oldFloor - 1]++;
    else
        _saveData.bpCycleJackpotAdvanceCounts[oldFloor - 1]++;
    // ...
}
```

### (2) `SpinAsync()` — `forcePromotion` 전달

```csharp
// 변경 전 (실제 변경된 한 줄)
var targetObtained = AdvanceFloor();

// 변경 후
var targetObtained = AdvanceFloor(isPity: forcePromotion);
```

`forcePromotion`, `RouletteService.SpinCurrentFloor(forcePromotion)`, `result.IsTarget` 분기는 변경 전에도 존재하던 코드다. 실제 변경은 `AdvanceFloor()` → `AdvanceFloor(isPity: forcePromotion)` 한 줄뿐이다.

### (3) `HandleGlobalGuaranteed()` — 글로벌 천장 기록

```csharp
if (_saveData.bpCurrentFloor < MaxFloor)
{
    int oldFloor = _saveData.bpCurrentFloor;
    _saveData.bpCycleGlobalPityTriggered = 1;  // 배열 대신 단일 int
    _saveData.bpCurrentFloor = MaxFloor;
    // ...
}
```

글로벌 천장은 구조적으로 4층(MaxFloor-1)에서만 발동되므로 배열이 필요 없다.

### (4) `ResetField()` — 초기화

```csharp
_saveData.bpCycleJackpotAdvanceCounts = new int[MaxFloor];
_saveData.bpCycleFloorPityAdvanceCounts = new int[MaxFloor];
_saveData.bpCycleGlobalPityTriggered = 0;
// bpFloorSpinCounts는 기존부터 ResetField()에서 초기화되고 있음
```

### (5) `SendTargetRewardRecordAsync()` — 데이터 캡처 및 전송

```csharp
var recordRequest = new BurgerPyramidRecordRequest
{
    // ...기존 필드...
    jackpot_advance_counts    = (int[])(_saveData?.bpCycleJackpotAdvanceCounts?.Clone()   ?? new int[MaxFloor]),
    floor_pity_advance_counts = (int[])(_saveData?.bpCycleFloorPityAdvanceCounts?.Clone() ?? new int[MaxFloor]),
    global_pity_triggered     = _saveData?.bpCycleGlobalPityTriggered ?? 0,
    floor_spin_counts         = (int[])(_saveData?.bpFloorSpinCounts?.Clone()             ?? new int[MaxFloor])
};
```

`bpFloorSpinCounts`는 새로운 save data 필드가 아닌 기존 필드를 그대로 사용한다.  
`ResetField()` 실행 전에 request 객체가 동기적으로 빌드되므로 타이밍 안전성이 보장된다.

`SendTargetRewardRecordAsync`는 두 경로에서 호출된다: `GrantTargetItemAndGetObtained()`(일반 타겟 보상)와 `GrantTargetSkinBoxAsync()`(스킨 박스 타겟 보상). request 빌드 로직이 메서드 내부에 있으므로 두 경로 모두 자동으로 처리된다.

---

## 타이밍 안전성

`SendTargetRewardRecordAsync`는 `.Forget()`으로 호출된 직후 `ResetField()`가 실행된다.

```
SendTargetRewardRecordAsync().Forget()   ← 비동기 시작
_currencyManager.ModifyCurrency(...)
ResetField()                             ← 배열 초기화
```

C# async/await의 특성상, `SendTargetRewardRecordAsync` 내부 코드는 첫 번째 `await` 전까지 **동기적으로** 실행된다.  
`recordRequest` 객체 빌드(`.Clone()` 포함)는 첫 `await`(`_serverManager.BurgerPyramidRecordAsync(recordRequest)`) 이전에 완료되므로,  
이후 `ResetField()`가 배열을 교체해도 전송 데이터는 영향받지 않는다.

---

## 서버 전송 데이터 예시

승급 타입 배열의 각 인덱스는 **단일 사이클 내 0 또는 1만 가능**하다.  
한 사이클은 1층→5층 단방향이므로 같은 층을 두 번 승급할 수 없기 때문이다.

```json
// 단일 사이클 레코드 예시
// 해석: 1층→잭팟(23스핀), 2층→층천장(40스핀), 3층→잭팟(8스핀), 4층→20번째 스핀에서 글로벌천장 발동
{
  "season_number": 2,
  "select_count": 45,
  "rewardItem": { "item_id": "SkinBox", "item_count": 1 },
  "jackpot_advance_counts":    [1, 0, 1, 0, 0],
  "floor_pity_advance_counts": [0, 1, 0, 0, 0],
  "global_pity_triggered":     1,
  "floor_spin_counts":         [23, 40, 8, 20, 0]
}
```

`global_pity_triggered = 1`이면 4층에서 글로벌 천장이 발동됐음을 의미한다.  
`floor_spin_counts[3] == 20`은 4층 임계값(20스핀)까지 정상 진행 후 발동됐음을 나타낸다. 4층이 "스킵"되는 구조가 아니라, 4층의 마지막 스핀과 동시에 글로벌 천장이 발동된다.  
`floor_spin_counts[4]`(5층)는 스핀 없이 타겟이 지급되므로 항상 0이다.

### 시즌 내 다중 사이클 누적 예시

한 시즌에 사이클을 3회 완료한 경우, 서버에는 레코드 3개가 적재된다.

| 레코드 | jackpot[0] | floor_pity[0] | global_pity_triggered | floor_spin[0] |
|---|---|---|---|---|
| 사이클 1 | 1 | 0 | 0 | 23 |
| 사이클 2 | 0 | 1 | 1 | 60 |
| 사이클 3 | 1 | 0 | 0 | 11 |
| **시즌 SUM / AVG** | **2** | **1** | **1** | **AVG 31.3** |

- 타입 필드: `SUM`으로 시즌 내 경로별 승급 횟수 집계
- 스핀 횟수: `AVG`로 층별 평균 소모 스핀 수 집계

---

## 기획자가 이 데이터로 할 수 있는 분석

### 층별 천장 발동률
```sql
-- 2층 승급 중 층 천장이 얼마나 발동했는가 (시즌별)
SELECT
    season_number,
    SUM(floor_pity_advance_counts[1]) AS floor2_pity,
    SUM(jackpot_advance_counts[1])    AS floor2_jackpot,
    ROUND(SUM(floor_pity_advance_counts[1]) * 100.0 / COUNT(*), 1) AS floor2_pity_rate
FROM burger_pyramid_records
GROUP BY season_number;
```

### 층별 평균 소모 스핀 수
```sql
-- 잭팟으로 승급한 경우만 필터링해 실질 평균 산출
SELECT
    season_number,
    AVG(floor_spin_counts[0]) FILTER (WHERE jackpot_advance_counts[0] = 1) AS floor1_avg_spins,
    AVG(floor_spin_counts[1]) FILTER (WHERE jackpot_advance_counts[1] = 1) AS floor2_avg_spins,
    AVG(floor_spin_counts[2]) FILTER (WHERE jackpot_advance_counts[2] = 1) AS floor3_avg_spins
FROM burger_pyramid_records
GROUP BY season_number;
```

### 글로벌 천장 발동 비율
```sql
-- 전체 수령 건 중 글로벌 천장이 발동된 비율
SELECT
    season_number,
    COUNT(*) AS total_claims,
    SUM(global_pity_triggered) AS global_pity_claims,
    ROUND(SUM(global_pity_triggered) * 100.0 / COUNT(*), 1) AS global_pity_rate
FROM burger_pyramid_records
GROUP BY season_number;
```

### 시즌별 승급 경로 퍼널
```sql
SELECT
    season_number,
    SUM(jackpot_advance_counts[0])    AS floor1_jackpot,
    SUM(floor_pity_advance_counts[0]) AS floor1_floor_pity,
    SUM(jackpot_advance_counts[1])    AS floor2_jackpot,
    SUM(floor_pity_advance_counts[1]) AS floor2_floor_pity,
    SUM(jackpot_advance_counts[2])    AS floor3_jackpot,
    SUM(floor_pity_advance_counts[2]) AS floor3_floor_pity,
    SUM(jackpot_advance_counts[3])    AS floor4_jackpot,
    SUM(floor_pity_advance_counts[3]) AS floor4_floor_pity,
    SUM(global_pity_triggered)        AS global_pity_total
FROM burger_pyramid_records
GROUP BY season_number;
```

---

## 데이터 수집 한계 (검토 포인트)

| 상황                  | 수집 여부    | 이유                                             |
| ------------------- | -------- | ---------------------------------------------- |
| 타겟 수령 완료된 사이클       | ✅ 수집됨    | `SendTargetRewardRecordAsync` 경유               |
| 시즌 종료 시 미완성 사이클     | ❌ 수집 안 됨 | API 호출 없이 시즌 리셋됨                               |
| 글로벌 천장 발동 시 4층 스핀 수 | ✅ 정상 수집  | `floor_spin_counts[3] = 20` (층 임계값 도달 시 동시 발동) |

미완성 사이클 데이터가 중요한 경우, 시즌 종료 시점에 별도 아카이브 API 호출을 추가하는 것을 검토할 수 있음.

---

## 백엔드 팀 요청 사항

기존 `/burgerpyramid/record` 엔드포인트 request body에 아래 4개 필드가 추가됨.  
서버에서 이 필드를 DB에 저장하도록 처리 요청.

```
jackpot_advance_counts    : int[5]  // 층별 일반 잭팟 승급 여부 (0 또는 1)
floor_pity_advance_counts : int[5]  // 층별 층 천장 승급 여부 (0 또는 1)
global_pity_triggered     : int     // 글로벌 천장 발동 여부 (0 또는 1) — 항상 4층에서만 발동
floor_spin_counts         : int[5]  // 층별 실제 소모 스핀 횟수 (스킵 층은 0)
```
