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

### 2. Airbridge 이벤트 파라미터 (`BurgerPyramidManager.cs`)

승급 통계는 서버 DB가 아닌 `AnalyticsEventLogger`를 통해 Firebase Analytics + Airbridge로 전송된다.  
Airbridge는 배열 타입을 지원하지 않으므로 배열을 개별 키로 펼쳐서 전송한다.

| 파라미터 키 | 값 | 설명 |
|---|---|---|
| `season_number` | int | 현재 시즌 번호 |
| `floor1_jackpot` ~ `floor4_jackpot` | 0 또는 1 | 층별 일반 잭팟 승급 여부 |
| `floor1_floor_pity` ~ `floor4_floor_pity` | 0 또는 1 | 층별 층 천장 승급 여부 |
| `global_pity_triggered` | 0 또는 1 | 글로벌 천장 발동 여부 |
| `floor1_spins` ~ `floor4_spins` | int | 층별 실제 소모 스핀 횟수 |

---

## 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `SaveDataTypes.cs` | `BurgerPyramidSaveData`에 배열 2개 + int 1개 추가 |
| `BurgerPyramidServerTypes.cs` | 변경 없음 (승급 통계 필드를 서버로 보내지 않음) |
| `EventBurgerPyramidService.cs` | 변경 없음 |
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

### (5) `SendTargetRewardRecordAsync()` — Airbridge 이벤트 전송

```csharp
// 첫 await 이전에 동기적으로 실행 — ResetField()보다 먼저 데이터 캡처
var jackpotCounts   = (int[])(_saveData?.bpCycleJackpotAdvanceCounts?.Clone()   ?? new int[MaxFloor]);
var floorPityCounts = (int[])(_saveData?.bpCycleFloorPityAdvanceCounts?.Clone() ?? new int[MaxFloor]);
var spinCounts      = (int[])(_saveData?.bpFloorSpinCounts?.Clone()             ?? new int[MaxFloor]);
int globalPity      = _saveData?.bpCycleGlobalPityTriggered ?? 0;

AnalyticsEventLogger.LogEvent(new AnalyticsEventParams("burger_pyramid_cycle_complete")
    .WithParameter("season_number",        _currentSeasonNumber)
    .WithParameter("floor1_jackpot",       jackpotCounts[0])
    .WithParameter("floor2_jackpot",       jackpotCounts[1])
    .WithParameter("floor3_jackpot",       jackpotCounts[2])
    .WithParameter("floor4_jackpot",       jackpotCounts[3])
    .WithParameter("floor1_floor_pity",    floorPityCounts[0])
    .WithParameter("floor2_floor_pity",    floorPityCounts[1])
    .WithParameter("floor3_floor_pity",    floorPityCounts[2])
    .WithParameter("floor4_floor_pity",    floorPityCounts[3])
    .WithParameter("global_pity_triggered", globalPity)
    .WithParameter("floor1_spins",         spinCounts[0])
    .WithParameter("floor2_spins",         spinCounts[1])
    .WithParameter("floor3_spins",         spinCounts[2])
    .WithParameter("floor4_spins",         spinCounts[3]));
```

`bpFloorSpinCounts`는 기존 필드를 그대로 사용한다.  
`AnalyticsEventLogger.LogEvent()`는 동기 호출이므로 첫 `await` 이전에 완료된다.

`SendTargetRewardRecordAsync`는 두 경로에서 호출된다: `GrantTargetItemAndGetObtained()`(일반 타겟 보상)와 `GrantTargetSkinBoxAsync()`(스킨 박스 타겟 보상). 이벤트 전송 로직이 메서드 내부에 있으므로 두 경로 모두 자동으로 처리된다.

---

## 타이밍 안전성

`SendTargetRewardRecordAsync`는 `.Forget()`으로 호출된 직후 `ResetField()`가 실행된다.

```
SendTargetRewardRecordAsync().Forget()   ← 비동기 시작
_currencyManager.ModifyCurrency(...)
ResetField()                             ← 배열 초기화
```

C# async/await의 특성상, `SendTargetRewardRecordAsync` 내부 코드는 첫 번째 `await` 전까지 **동기적으로** 실행된다.  
`.Clone()` 배열 캡처와 `AnalyticsEventLogger.LogEvent()` 호출은 첫 `await`(`_serverManager.BurgerPyramidRecordAsync(...)`) 이전에 완료되므로,  
이후 `ResetField()`가 배열을 교체해도 전송 데이터는 영향받지 않는다.

---

## Airbridge 이벤트 예시

승급 타입 파라미터는 **단일 사이클 내 0 또는 1만 가능**하다.  
한 사이클은 1층→5층 단방향이므로 같은 층을 두 번 승급할 수 없기 때문이다.

```
// 이벤트명: burger_pyramid_cycle_complete
// 해석: 1층→잭팟(23스핀), 2층→층천장(40스핀), 3층→잭팟(8스핀), 4층→20번째 스핀에서 글로벌천장 발동

season_number        = 2
floor1_jackpot       = 1,  floor2_jackpot      = 0,  floor3_jackpot      = 1,  floor4_jackpot      = 0
floor1_floor_pity    = 0,  floor2_floor_pity   = 1,  floor3_floor_pity   = 0,  floor4_floor_pity   = 0
global_pity_triggered = 1
floor1_spins         = 23, floor2_spins        = 40, floor3_spins        = 8,  floor4_spins        = 20
```

`global_pity_triggered = 1`이면 4층에서 글로벌 천장이 발동됐음을 의미한다.  
`floor4_spins = 20`은 4층 임계값(20스핀)까지 정상 진행 후 발동됐음을 나타낸다. 4층이 "스킵"되는 구조가 아니라, 4층의 마지막 스핀과 동시에 글로벌 천장이 발동된다.  
`floor4_spins`(5층에 해당하는 파라미터 없음)는 5층이 스핀 없이 타겟 지급층이므로 전송하지 않는다.

### 시즌 내 다중 사이클 누적 예시

한 시즌에 사이클을 3회 완료한 경우, Airbridge에는 이벤트 3건이 적재된다.

| 이벤트 | floor1_jackpot | floor1_floor_pity | global_pity_triggered | floor1_spins |
|---|---|---|---|---|
| 사이클 1 | 1 | 0 | 0 | 23 |
| 사이클 2 | 0 | 1 | 1 | 60 |
| 사이클 3 | 1 | 0 | 0 | 11 |
| **시즌 SUM / AVG** | **2** | **1** | **1** | **AVG 31.3** |

- 승급 경로 파라미터: `SUM`으로 시즌 내 경로별 승급 횟수 집계
- 스핀 횟수 파라미터: `AVG`로 층별 평균 소모 스핀 수 집계

---

## 기획자가 이 데이터로 할 수 있는 분석

데이터는 Airbridge 대시보드 또는 Airbridge Raw Data Export(BigQuery/S3 연동)에서 조회한다.  
이벤트명: `burger_pyramid_cycle_complete`

### 층별 천장 발동률
```sql
-- 2층 승급 중 층 천장이 얼마나 발동했는가 (시즌별)
SELECT
    season_number,
    SUM(floor2_floor_pity) AS floor2_pity,
    SUM(floor2_jackpot)    AS floor2_jackpot,
    ROUND(SUM(floor2_floor_pity) * 100.0 / COUNT(*), 1) AS floor2_pity_rate
FROM burger_pyramid_cycle_complete
GROUP BY season_number;
```

### 층별 평균 소모 스핀 수
```sql
-- 잭팟으로 승급한 경우만 필터링해 실질 평균 산출
SELECT
    season_number,
    AVG(floor1_spins) FILTER (WHERE floor1_jackpot = 1) AS floor1_avg_spins,
    AVG(floor2_spins) FILTER (WHERE floor2_jackpot = 1) AS floor2_avg_spins,
    AVG(floor3_spins) FILTER (WHERE floor3_jackpot = 1) AS floor3_avg_spins
FROM burger_pyramid_cycle_complete
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
FROM burger_pyramid_cycle_complete
GROUP BY season_number;
```

### 시즌별 승급 경로 퍼널
```sql
SELECT
    season_number,
    SUM(floor1_jackpot)    AS floor1_jackpot,
    SUM(floor1_floor_pity) AS floor1_floor_pity,
    SUM(floor2_jackpot)    AS floor2_jackpot,
    SUM(floor2_floor_pity) AS floor2_floor_pity,
    SUM(floor3_jackpot)    AS floor3_jackpot,
    SUM(floor3_floor_pity) AS floor3_floor_pity,
    SUM(floor4_jackpot)    AS floor4_jackpot,
    SUM(floor4_floor_pity) AS floor4_floor_pity,
    SUM(global_pity_triggered) AS global_pity_total
FROM burger_pyramid_cycle_complete
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

## Airbridge 커스텀 파라미터 등록 (필수)

**에어브릿지 콘솔에서 커스텀 파라미터를 사전 등록해야 Raw Data에 컬럼으로 수집된다.** 미등록 파라미터는 이벤트가 전송되어도 데이터가 유실된다.

**경로**: Airbridge 콘솔 → `Settings` → `Custom Attributes` → 파라미터 추가

| 파라미터 키                  | 타입  | 설명                   |
| ----------------------- | --- | -------------------- |
| `season_number`         | int | 시즌 번호                |
| `floor1_jackpot`        | int | 1층 일반 잭팟 승급 여부 (0/1) |
| `floor2_jackpot`        | int | 2층 일반 잭팟 승급 여부 (0/1) |
| `floor3_jackpot`        | int | 3층 일반 잭팟 승급 여부 (0/1) |
| `floor4_jackpot`        | int | 4층 일반 잭팟 승급 여부 (0/1) |
| `floor1_floor_pity`     | int | 1층 층 천장 승급 여부 (0/1)  |
| `floor2_floor_pity`     | int | 2층 층 천장 승급 여부 (0/1)  |
| `floor3_floor_pity`     | int | 3층 층 천장 승급 여부 (0/1)  |
| `floor4_floor_pity`     | int | 4층 층 천장 승급 여부 (0/1)  |
| `global_pity_triggered` | int | 글로벌 천장 발동 여부 (0/1)   |
| `floor1_spins`          | int | 1층 소모 스핀 수           |
| `floor2_spins`          | int | 2층 소모 스핀 수           |
| `floor3_spins`          | int | 3층 소모 스핀 수           |
| `floor4_spins`          | int | 4층 소모 스핀 수           |

> **이벤트 먼저 발생시킨 뒤 등록하면 그 이전 데이터는 소급 수집되지 않는다.** 릴리즈 전에 미리 등록할 것.

---

## Airbridge Raw Data Export 분석

Raw Data Export를 BigQuery/S3 등에 연결하면 파라미터가 다음 컬럼 구조로 적재된다.

```
event_name                              = "burger_pyramid_cycle_complete"
event_datetime                          = "2026-05-11T10:23:00Z"
custom_attributes.season_number         = 2
custom_attributes.floor1_jackpot        = 1
custom_attributes.floor2_floor_pity     = 1
custom_attributes.global_pity_triggered = 0
custom_attributes.floor1_spins          = 23
...
```

Raw Data는 수 시간 지연이 있어 실시간 모니터링보다 기획자 주간/월간 분석에 적합하다.

---

## 백엔드 팀 요청 사항

없음. 승급 통계는 Airbridge 이벤트로 전송되므로 `/burgerpyramid/record` 엔드포인트 변경 불필요.
