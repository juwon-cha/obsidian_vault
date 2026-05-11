# BurgerPyramid 층별 승급 통계 추적 구현

> 작성일: 2026-05-11  
> 브랜치: feature/juwon/Event  
> 목적: 기획자가 BurgerPyramid 이벤트의 층별 승급 경로(일반 잭팟 / 층 천장 / 글로벌 천장)를 시즌 단위로 분석할 수 있도록 데이터 수집 로직 추가

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

---

## 추가된 데이터

### 1. `BurgerPyramidSaveData` — 3개 배열 추가 (`SaveDataTypes.cs`)

```csharp
// 층별 승급 통계 (타겟 수령 시 서버 전송 후 초기화)
public int[] bpCycleJackpotAdvanceCounts = new int[5];
public int[] bpCycleFloorPityAdvanceCounts = new int[5];
public int[] bpCycleGlobalPityAdvanceCounts = new int[5];
```

- **단위**: 사이클(타겟 수령 1회 = 1사이클)
- **인덱스**: `[0]` = 1층→2층, `[1]` = 2층→3층, `[2]` = 3층→4층, `[3]` = 4층→5층
- **초기화 시점**: 타겟 수령 후 `ResetField()` 호출 시, 시즌 변경 시 `ResetForNewSeason()` 호출 시

### 2. `BurgerPyramidRecordRequest` — 3개 필드 추가 (`BurgerPyramidServerTypes.cs`)

```csharp
public int[] jackpot_advance_counts;
public int[] floor_pity_advance_counts;
public int[] global_pity_advance_counts;
```

기존 타겟 수령 기록 요청(`/burgerpyramid/record`)에 포함되어 서버로 전송됨.

---

## 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `SaveDataTypes.cs` | `BurgerPyramidSaveData`에 3개 배열 필드 추가 |
| `BurgerPyramidServerTypes.cs` | `BurgerPyramidRecordRequest`에 3개 배열 필드 추가 |
| `EventBurgerPyramidService.cs` | JSON 직렬화 시 3개 배열을 `JArray`로 포함 |
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
// 변경 전
var targetObtained = AdvanceFloor();

// 변경 후
bool forcePromotion = IsFloorPityReached(currentFloor);
var result = RouletteService.SpinCurrentFloor(forcePromotion);
if (result.IsTarget)
    var targetObtained = AdvanceFloor(isPity: forcePromotion);
```

`forcePromotion`이 이미 존재하던 변수이므로 추가 계산 없이 전달만 하면 됨.

### (3) `HandleGlobalGuaranteed()` — 글로벌 천장 기록

```csharp
if (_saveData.bpCurrentFloor < MaxFloor)
{
    int oldFloor = _saveData.bpCurrentFloor;
    _saveData.bpCycleGlobalPityAdvanceCounts[oldFloor - 1]++;  // 추가
    _saveData.bpCurrentFloor = MaxFloor;
    // ...
}
```

글로벌 천장 발동 시 중간 층을 스킵하는 구조이므로, 발동 시점의 현재 층(`oldFloor`)만 기록함.  
(예: 2층에서 글로벌 천장 → `[1]++`. 3층, 4층은 기록하지 않음)

### (4) `ResetField()` — 배열 초기화

```csharp
_saveData.bpCycleJackpotAdvanceCounts = new int[MaxFloor];
_saveData.bpCycleFloorPityAdvanceCounts = new int[MaxFloor];
_saveData.bpCycleGlobalPityAdvanceCounts = new int[MaxFloor];
```

### (5) `SendTargetRewardRecordAsync()` — 데이터 캡처 및 전송

```csharp
var recordRequest = new BurgerPyramidRecordRequest
{
    // ...기존 필드...
    jackpot_advance_counts    = (int[])(_saveData?.bpCycleJackpotAdvanceCounts?.Clone()     ?? new int[MaxFloor]),
    floor_pity_advance_counts = (int[])(_saveData?.bpCycleFloorPityAdvanceCounts?.Clone()   ?? new int[MaxFloor]),
    global_pity_advance_counts= (int[])(_saveData?.bpCycleGlobalPityAdvanceCounts?.Clone()  ?? new int[MaxFloor])
};
```

---

## 타이밍 안전성

`SendTargetRewardRecordAsync`는 `.Forget()`으로 호출된 직후 `ResetField()`가 실행된다.

```
SendTargetRewardRecordAsync().Forget()   ← 비동기 시작
_currencyManager.ModifyCurrency(...)
ResetField()                             ← 배열 초기화
```

C# async/await의 특성상, `SendTargetRewardRecordAsync` 내부 코드는 첫 번째 `await` 전까지 **동기적으로** 실행된다.  
`recordRequest` 객체 빌드(배열 `.Clone()` 포함)는 첫 `await`(`_serverManager.BurgerPyramidRecordAsync(recordRequest)`) 이전에 완료되므로, 이후 `ResetField()`가 배열을 교체해도 전송 데이터는 영향받지 않는다.

---

## 서버 전송 데이터 예시

```json
{
  "season_number": 2,
  "select_count": 45,
  "rewardItem": { "item_id": "SkinBox", "item_count": 1 },
  "jackpot_advance_counts":     [2, 1, 0, 0, 0],
  "floor_pity_advance_counts":  [0, 1, 1, 0, 0],
  "global_pity_advance_counts": [0, 0, 0, 1, 0]
}
```

위 예시의 해석:
- 1층→2층: 잭팟 2회로 승급
- 2층→3층: 잭팟 1회 + 층천장 1회 (총 2사이클 합산 시)
- 4층→5층: 글로벌 천장 1회 발동

---

## 기획자가 이 데이터로 할 수 있는 분석

서버에 `(user_id, season_number, 기존 필드들, jackpot_advance_counts[], floor_pity_advance_counts[], global_pity_advance_counts[])`를 저장하면 아래 분석이 가능하다.

### 층별 천장 발동률
```sql
-- 2층 승급 중 층 천장이 얼마나 발동했는가 (시즌별)
SELECT
    season_number,
    SUM(floor_pity_advance_counts[1]) AS floor2_pity,
    SUM(jackpot_advance_counts[1])    AS floor2_jackpot
FROM burger_pyramid_records
GROUP BY season_number;
```

### 글로벌 천장 발동 비율
```sql
-- 전체 수령 건 중 글로벌 천장이 발동된 비율
SELECT
    season_number,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN global_pity_advance_counts[0] + global_pity_advance_counts[1]
                  + global_pity_advance_counts[2] + global_pity_advance_counts[3] > 0
             THEN 1 ELSE 0 END) AS global_pity_claims
FROM burger_pyramid_records
GROUP BY season_number;
```

### 시즌별 승급 경로 퍼널
```sql
-- 시즌별로 각 층에서 어떤 경로로 승급했는지 비율
SELECT
    season_number,
    SUM(jackpot_advance_counts[0])     AS floor1_jackpot,
    SUM(floor_pity_advance_counts[0])  AS floor1_floor_pity,
    SUM(global_pity_advance_counts[0]) AS floor1_global_pity
FROM burger_pyramid_records
GROUP BY season_number;
```

---

## 데이터 수집 한계 (검토 포인트)

| 상황 | 수집 여부 | 이유 |
|---|---|---|
| 타겟 수령 완료된 사이클 | ✅ 수집됨 | `SendTargetRewardRecordAsync` 경유 |
| 시즌 종료 시 미완성 사이클 | ❌ 수집 안 됨 | API 호출 없이 시즌 리셋됨 |
| 글로벌 천장으로 스킵된 중간 층 | 의도적 미수집 | 실제 플레이하지 않은 층이므로 제외 |

미완성 사이클 데이터가 중요한 경우, 시즌 종료 시점에 별도 아카이브 API 호출을 추가하는 것을 검토할 수 있음.

---

## 백엔드 팀 요청 사항

기존 `/burgerpyramid/record` 엔드포인트 request body에 아래 3개 필드가 추가됨.  
서버에서 이 필드를 DB에 저장하도록 처리 요청.

```
jackpot_advance_counts     : int[5]
floor_pity_advance_counts  : int[5]
global_pity_advance_counts : int[5]
```
