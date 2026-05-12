# BurgerPyramid 층별 승급 통계 추적 구현

> 작성일: 2026-05-11  
> 브랜치: feature/juwon/Event  
> 목적: 기획자가 BurgerPyramid 이벤트의 층별 승급 경로(일반 잭팟 / 층 천장 / 글로벌 천장)와 층별 실제 스핀 횟수를 시즌 단위로 분석할 수 있도록 데이터 수집 로직 추가

---

## 배경

기획자가 유저들이 각 층을 어떤 경로로 승급하는지 분석하고 싶다는 요청이 있었음.  
기존 테이블에는 현재 플로어(`bpCurrentFloor`)와 층별 스핀 횟수(`bpFloorSpinCounts`)만 존재했으나,  
`bpFloorSpinCounts`는 타겟 수령 시 초기화되기 때문에 누적 이력이 남지 않는 구조였음.

추가로 기획자가 **어느 층에서 스핀을 멈추고 이탈하는지** 파악하고 싶다는 요청이 있었음.  
`burger_pyramid_cycle_complete`는 타겟 수령 시에만 전송되어 미완성 사이클을 추적할 수 없었으므로,  
`burger_pyramid_progress_snapshot` 이벤트를 별도 추가함.

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
// ── 플로어 진행 (기존 필드에 bpFieldResetCount 추가)
public int bpFieldResetCount = 0;  // 시즌 내 완료한 사이클 수

// 층별 승급 통계 (타겟 수령 시 서버 전송 후 초기화)
public int[] bpCycleJackpotAdvanceCounts = new int[5];    // 층별 일반 잭팟 승급 여부
public int[] bpCycleFloorPityAdvanceCounts = new int[5];  // 층별 층 천장 승급 여부
public int bpCycleGlobalPityTriggered = 0;                // 글로벌 천장 발동 여부 (단일 int)
```

**`bpCycleJackpotAdvanceCounts` / `bpCycleFloorPityAdvanceCounts`**
- **단위**: 사이클(타겟 수령 1회 = 1사이클)
- **인덱스**: `[0]` = 1층→2층, `[1]` = 2층→3층, `[2]` = 3층→4층, `[3]` = 4층→5층
- **초기화 시점**: `ResetField()` (사이클 완료 후), `ResetForNewSeason()` (시즌 변경 시)
- **인덱스 [4] 항상 0**: 5층은 타겟 지급층이므로 잭팟/층 천장 승급 자체가 없다.

**`bpFieldResetCount`**
- `ResetField()` 호출 시마다 `++` 증가 → 시즌 내 완료한 사이클 수를 나타냄
- `ResetForNewSeason()` 에서 `0`으로 초기화
- `burger_pyramid_cycle_complete` 캡처 시점에서 `bpFieldResetCount + 1` = 현재 완료 중인 사이클 번호

### 2. Airbridge 이벤트 — 두 종류

승급 통계는 서버 DB가 아닌 `AnalyticsEventLogger`를 통해 **Airbridge로만** 전송된다 (`.AirbridgeOnly()` 적용, Firebase 전송 없음).  
Airbridge는 배열 타입을 지원하지 않으므로 배열을 개별 키로 펼쳐서 전송한다.

#### `burger_pyramid_cycle_complete` — 사이클 완료 시

| 파라미터 키 | 값 | 설명 |
|---|---|---|
| `season_number` | int | 현재 시즌 번호 |
| `cycle_number` | int | 시즌 내 몇 번째 사이클 (1부터 시작) |
| `floor1_jackpot` ~ `floor4_jackpot` | 0 또는 1 | 층별 일반 잭팟 승급 여부 |
| `floor1_floor_pity` ~ `floor4_floor_pity` | 0 또는 1 | 층별 층 천장 승급 여부 |
| `global_pity_triggered` | 0 또는 1 | 글로벌 천장 발동 여부 |
| `floor1_spins` ~ `floor4_spins` | int | 층별 실제 소모 스핀 횟수 |

#### `burger_pyramid_progress_snapshot` — 미완성 사이클 상태 캡처

| 파라미터 키 | 값 | 설명 |
|---|---|---|
| `season_number` | int | 현재 시즌 번호 (`_saveData.seasonNumber` 사용) |
| `completed_cycles` | int | 이미 완료한 사이클 수 (0이면 첫 사이클 진행 중) |
| `current_floor` | 1~5 | 현재 층 |
| `floor1_spins` ~ `floor4_spins` | int | 현재 사이클 층별 스핀 횟수 |
| `total_spins` | int | 현재 사이클 총 스핀 횟수 |
| `snapshot_reason` | string | `season_end` / `daily_reset` / `session_end` |

---

## 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `SaveDataTypes.cs` | `BurgerPyramidSaveData`에 int 1개(`bpFieldResetCount`) + 배열 2개 + int 1개(`bpCycleGlobalPityTriggered`) 추가 |
| `BurgerPyramidServerTypes.cs` | 변경 없음 (승급 통계 필드를 서버로 보내지 않음) |
| `EventBurgerPyramidService.cs` | 변경 없음 |
| `BurgerPyramidManager.cs` | 6곳 수정 (하단 상세 참조) |

---

## `BurgerPyramidManager.cs` 변경 상세

### (1) `AdvanceFloor(bool isPity = false)` — `isPity` 파라미터 추가 및 기록

```csharp
// 변경 전
public Dictionary<ECurrencyType, int> AdvanceFloor()

// 변경 후
public Dictionary<ECurrencyType, int> AdvanceFloor(bool isPity = false)
{
    if (_saveData == null) return null;
    if (_saveData.bpCurrentFloor >= MaxFloor) { RequestSave(); return null; }

    int oldFloor = _saveData.bpCurrentFloor;

    if (isPity)
        _saveData.bpCycleFloorPityAdvanceCounts[oldFloor - 1]++;
    else
        _saveData.bpCycleJackpotAdvanceCounts[oldFloor - 1]++;

    // 천장보다 일찍 승급한 경우 미사용 스핀을 카운터에 반영 (기존 로직)
    int unusedSpins = GetFloorPityThreshold(oldFloor) - GetFloorSpinCount(oldFloor);
    if (unusedSpins > 0) { ... }
    // ...
}
```

### (2) `SpinAsync()` — `AdvanceFloor`에 `isPity` 전달

```csharp
// 변경 전
var targetObtained = AdvanceFloor();

// 변경 후
var targetObtained = AdvanceFloor(isPity: forcePromotion);
```

`forcePromotion`은 `IsFloorPityReached(currentFloor)`의 반환값으로, 기존에도 `RouletteService.SpinCurrentFloor(forcePromotion)`에 사용되던 변수다. 실제 변경은 이 한 줄뿐이다.

### (3) `HandleGlobalGuaranteed()` — 글로벌 천장 기록

```csharp
if (_saveData.bpCurrentFloor < MaxFloor)
{
    int oldFloor = _saveData.bpCurrentFloor;
    _saveData.bpCycleGlobalPityTriggered = 1;  // 배열 대신 단일 int
    _saveData.bpCurrentFloor = MaxFloor;
    EventManager.Dispatch<BurgerPyramidFloorAdvancedEventData>(...);
}
_saveData.bpIsTargetPending = true;
```

글로벌 천장은 구조적으로 4층(MaxFloor-1)에서만 발동되므로 배열이 필요 없다.

### (4) `ResetField()` — 사이클 통계 초기화 + 완료 카운터 증가

```csharp
public void ResetField()
{
    if (_saveData == null) return;

    _saveData.bpCurrentFloor = 1;
    for (int i = 0; i < MaxFloor; i++)
        _saveData.bpFloorSpinCounts[i] = 0;
    _saveData.bpTargetItemClaimed = false;
    _saveData.bpIsTargetPending = false;
    _saveData.bpTotalSpins = 0;
    _saveData.bpSpinsSinceLastJackpot = 0;
    _saveData.bpCycleJackpotAdvanceCounts = new int[MaxFloor];
    _saveData.bpCycleFloorPityAdvanceCounts = new int[MaxFloor];
    _saveData.bpCycleGlobalPityTriggered = 0;
    _saveData.bpFieldResetCount++;   // ← 완료 사이클 카운터 증가
    RequestSave();
}
```

`bpFieldResetCount`는 **증가만** 한다. 시즌 내 누적이므로, 0으로 초기화는 `ResetForNewSeason()`에서만 수행된다.

### (5) `SendTargetRewardRecordAsync()` — `burger_pyramid_cycle_complete` 이벤트 전송

```csharp
public async UniTask SendTargetRewardRecordAsync(ECurrencyType rewardType, int rewardAmount = 1)
{
    // ...
    try
    {
        var playerDataManager = Managers.Instance?.GetManager<PlayerDataManager>();

        // 첫 await 이전에 동기적으로 캡처 — 이후 ResetField()가 배열을 교체해도 영향 없음
        var jackpotCounts   = (int[])(_saveData?.bpCycleJackpotAdvanceCounts?.Clone()   ?? new int[MaxFloor]);
        var floorPityCounts = (int[])(_saveData?.bpCycleFloorPityAdvanceCounts?.Clone() ?? new int[MaxFloor]);
        var spinCounts      = (int[])(_saveData?.bpFloorSpinCounts?.Clone()             ?? new int[MaxFloor]);
        int globalPity      = _saveData?.bpCycleGlobalPityTriggered ?? 0;

        AnalyticsEventLogger.LogEvent(new AnalyticsEventParams("burger_pyramid_cycle_complete")
            .AirbridgeOnly()
            .WithParameter("season_number", _currentSeasonNumber)
            .WithParameter("cycle_number",  (_saveData?.bpFieldResetCount ?? 0) + 1)
            .WithParameter("floor1_jackpot",     jackpotCounts[0])
            .WithParameter("floor2_jackpot",     jackpotCounts[1])
            .WithParameter("floor3_jackpot",     jackpotCounts[2])
            .WithParameter("floor4_jackpot",     jackpotCounts[3])
            .WithParameter("floor1_floor_pity",  floorPityCounts[0])
            .WithParameter("floor2_floor_pity",  floorPityCounts[1])
            .WithParameter("floor3_floor_pity",  floorPityCounts[2])
            .WithParameter("floor4_floor_pity",  floorPityCounts[3])
            .WithParameter("global_pity_triggered", globalPity)
            .WithParameter("floor1_spins",       spinCounts[0])
            .WithParameter("floor2_spins",       spinCounts[1])
            .WithParameter("floor3_spins",       spinCounts[2])
            .WithParameter("floor4_spins",       spinCounts[3]));

        var recordRequest = new BurgerPyramidRecordRequest { ... };
        var response = await _serverManager.BurgerPyramidRecordAsync(recordRequest);  // ← 첫 await
        // ...
    }
}
```

**`cycle_number` 계산**: `(_saveData?.bpFieldResetCount ?? 0) + 1`  
캡처 시점에 `bpFieldResetCount`는 아직 증가 전(이후 `ResetField()`에서 증가)이므로, `+ 1`이 현재 완료 중인 사이클 번호가 된다.

`SendTargetRewardRecordAsync`는 두 경로에서 호출된다:
- `GrantTargetItemAndGetObtained()` — 일반 타겟 보상
- `GrantTargetSkinBoxAsync()` — 스킨 박스 타겟 보상

두 경로 모두 `SendTargetRewardRecordAsync().Forget()` 직후 `ResetField()`를 호출하는 동일한 패턴이므로, 이벤트 전송 로직이 메서드 내부에 있어 두 경로를 모두 자동으로 처리한다.

### (6) `SendProgressSnapshotLog()` — `burger_pyramid_progress_snapshot` 이벤트 전송

```csharp
private void SendProgressSnapshotLog(string reason)
{
    if (_saveData == null) return;
    if (_saveData.bpTotalSpins == 0 && _saveData.bpCurrentFloor == 1) return;

    var spinCounts = (int[])(_saveData.bpFloorSpinCounts?.Clone() ?? new int[MaxFloor]);

    AnalyticsEventLogger.LogEvent(new AnalyticsEventParams("burger_pyramid_progress_snapshot")
        .AirbridgeOnly()
        .WithParameter("season_number",    _saveData.seasonNumber)
        .WithParameter("completed_cycles", _saveData.bpFieldResetCount)
        .WithParameter("current_floor",    _saveData.bpCurrentFloor)
        .WithParameter("floor1_spins",     spinCounts[0])
        .WithParameter("floor2_spins",     spinCounts[1])
        .WithParameter("floor3_spins",     spinCounts[2])
        .WithParameter("floor4_spins",     spinCounts[3])
        .WithParameter("total_spins",      _saveData.bpTotalSpins)
        .WithParameter("snapshot_reason",  reason));
}
```

**`_saveData.seasonNumber` vs `_currentSeasonNumber` 사용 이유**  
`season_end` 발화 시점(`ResetForNewSeason()` 진입부)에서 `_currentSeasonNumber`는 이미 새 시즌 번호로 갱신되어 있다. `_saveData.seasonNumber`는 아직 리셋 전이므로 이전 시즌 번호를 정확히 가리킨다. 모든 reason에서 `_saveData.seasonNumber`를 쓰면 항상 올바른 값이 보장된다.

**전송 조건** (`bpTotalSpins == 0 && bpCurrentFloor == 1` 시 전송 안 함)  
사이클을 시작하지 않은 상태 — 아직 스핀도 안 했고 1층에 있는 초기 상태 — 의 노이즈를 제거한다.

**호출 위치 3곳**

| 호출 위치 | `reason` 값 |
|---|---|
| `OnApplicationPause(pauseStatus: true)` | `"session_end"` |
| `ResetForNewSeason()` — `_saveData.seasonNumber` 갱신 직전 | `"season_end"` |
| `PerformDailyReset()` — 퀘스트 리셋 직전 | `"daily_reset"` |

---

## 타이밍 안전성

### `burger_pyramid_cycle_complete` — `.Forget()` 패턴

`SendTargetRewardRecordAsync`는 `.Forget()`으로 호출된 직후 `ResetField()`가 실행된다.

```
SendTargetRewardRecordAsync().Forget()   ← 비동기 시작
_currencyManager.ModifyCurrency(...)
ResetField()                             ← 배열 초기화 + bpFieldResetCount++
```

C# async/await의 특성상, `SendTargetRewardRecordAsync` 내부 코드는 첫 번째 `await` 전까지 **동기적으로** 실행된다.  
`.Clone()` 배열 캡처와 `AnalyticsEventLogger.LogEvent()` 호출은 첫 `await`(`BurgerPyramidRecordAsync`) 이전에 완료되므로, 이후 `ResetField()`가 배열을 교체해도 전송 데이터는 영향받지 않는다.

### `burger_pyramid_progress_snapshot` — 동기 호출

`SendProgressSnapshotLog()`는 `async`가 아닌 동기 메서드다. 내부에서 `bpFloorSpinCounts`를 `.Clone()`하고 `AnalyticsEventLogger.LogEvent()`를 호출한다. 타이밍 문제 없음.

---

## Airbridge 이벤트 예시

### `burger_pyramid_cycle_complete`

승급 타입 파라미터는 **단일 사이클 내 0 또는 1만 가능**하다.  
한 사이클은 1층→5층 단방향이므로 같은 층을 두 번 승급할 수 없기 때문이다.

```
// 해석: 시즌 2, 첫 번째 사이클
//       1층→잭팟(23스핀), 2층→층천장(40스핀), 3층→잭팟(8스핀), 4층→20번째 스핀에서 글로벌천장 발동

season_number         = 2
cycle_number          = 1
floor1_jackpot        = 1,  floor2_jackpot       = 0,  floor3_jackpot       = 1,  floor4_jackpot       = 0
floor1_floor_pity     = 0,  floor2_floor_pity    = 1,  floor3_floor_pity    = 0,  floor4_floor_pity    = 0
global_pity_triggered = 1
floor1_spins          = 23, floor2_spins         = 40, floor3_spins         = 8,  floor4_spins         = 20
```

`global_pity_triggered = 1`이면 4층에서 글로벌 천장이 발동됐음을 의미한다.  
`floor4_spins = 20`은 4층 임계값(20스핀)까지 정상 진행 후 발동됐음을 나타낸다. 4층이 "스킵"되는 구조가 아니라, 4층의 마지막 스핀과 동시에 글로벌 천장이 발동된다.

### 시즌 내 다중 사이클 — `cycle_complete` 3건 적재 예시

| `cycle_number` | `floor1_jackpot` | `floor1_floor_pity` | `global_pity_triggered` | `floor1_spins` |
|---|---|---|---|---|
| 1 | 1 | 0 | 0 | 23 |
| 2 | 0 | 1 | 1 | 60 |
| 3 | 1 | 0 | 0 | 11 |
| **SUM / AVG** | **2** | **1** | **1** | **AVG 31.3** |

- 승급 경로 파라미터: `SUM`으로 시즌 내 경로별 승급 횟수 집계
- 스핀 횟수 파라미터: `AVG`로 층별 평균 소모 스핀 수 집계

### `burger_pyramid_progress_snapshot`

```
// 해석: 시즌 2, 2사이클 완료 후 3번째 사이클 중 2층에서 시즌 종료

season_number    = 2
completed_cycles = 2       ← 이미 완료한 사이클 수
current_floor    = 2       ← 현재 멈춘 층
floor1_spins     = 60      ← 3번째 사이클에서 1층을 천장까지 채움
floor2_spins     = 14      ← 2층에서 14스핀 후 이탈
floor3_spins     = 0
floor4_spins     = 0
total_spins      = 14      ← 현재 사이클 총 스핀 (floor2부터 카운트됨에 주의)
snapshot_reason  = "season_end"
```

> `total_spins`는 현재 사이클(`ResetField()` 이후)의 스핀 수만 카운트한다.  
> 위 예시에서 1층 60스핀은 층 천장 패딩(AdvanceFloor의 unusedSpins 로직)으로 `bpTotalSpins`에 반영되어 있으므로 `total_spins = 14`가 아니라 더 높을 수 있다. 실질적으로 "몇 층에서 멈췄는가"는 `current_floor`와 해당 층의 `floorN_spins`로 판단한다.

---

## 기획자가 이 데이터로 할 수 있는 분석

> **중요**: 이 이벤트들의 파라미터는 모두 Airbridge **커스텀 속성(customAttributes)** 으로 전송된다.  
> 커스텀 속성은 Airbridge 대시보드(Analytics → Events)에서 **필터 및 Breakdown으로 사용할 수 없다.**  
> 모든 집계·필터 분석은 **Raw Data Export(BigQuery/S3 연동)** 에서만 가능하다.

Airbridge 대시보드에서 확인 가능한 것은 이벤트 발생 건수(Count)뿐이다.

---

### 분석 A. 어느 층에서 이탈하는가 (`progress_snapshot`) — BigQuery

```sql
-- 시즌 종료 시점 기준, current_floor별 이탈 유저 수
SELECT
    CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.current_floor') AS INT64) AS current_floor,
    COUNT(DISTINCT user_id) AS user_count
FROM burger_pyramid_progress_snapshot
WHERE JSON_EXTRACT_SCALAR(custom_attributes, '$.snapshot_reason') = 'season_end'
GROUP BY current_floor
ORDER BY current_floor;
```

---

### 분석 B. 몇 번째 사이클에서 이탈하는가 (`progress_snapshot`) — BigQuery

```sql
-- completed_cycles 값별 분포 (0 = 첫 사이클도 완주 못한 유저)
SELECT
    CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.completed_cycles') AS INT64) AS completed_cycles,
    COUNT(DISTINCT user_id) AS user_count
FROM burger_pyramid_progress_snapshot
WHERE JSON_EXTRACT_SCALAR(custom_attributes, '$.snapshot_reason') = 'season_end'
GROUP BY completed_cycles
ORDER BY completed_cycles;
```

---

### 분석 C. 글로벌 천장 발동 비율 (`cycle_complete`) — BigQuery

```sql
SELECT
    CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.season_number') AS INT64) AS season_number,
    COUNT(*) AS total_claims,
    SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.global_pity_triggered') AS INT64)) AS global_pity_claims,
    ROUND(
        SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.global_pity_triggered') AS INT64)) * 100.0 / COUNT(*),
        1
    ) AS global_pity_rate
FROM burger_pyramid_cycle_complete
GROUP BY season_number;
```

---

### 분석 D. 층별 천장/잭팟 승급 비율 (`cycle_complete`) — BigQuery

```sql
SELECT
    CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.season_number') AS INT64) AS season_number,
    SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor2_jackpot')    AS INT64)) AS floor2_jackpot,
    SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor2_floor_pity') AS INT64)) AS floor2_floor_pity,
    SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor3_jackpot')    AS INT64)) AS floor3_jackpot,
    SUM(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor3_floor_pity') AS INT64)) AS floor3_floor_pity
FROM burger_pyramid_cycle_complete
GROUP BY season_number;
```

---

### 분석 E. 층별 평균 소모 스핀 수 (`cycle_complete`) — BigQuery

```sql
-- 잭팟으로 승급한 경우만 필터링해 실질 평균 산출
SELECT
    CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.season_number') AS INT64) AS season_number,
    AVG(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor1_spins') AS INT64))
        FILTER (WHERE CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor1_jackpot') AS INT64) = 1) AS floor1_avg_spins,
    AVG(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor2_spins') AS INT64))
        FILTER (WHERE CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor2_jackpot') AS INT64) = 1) AS floor2_avg_spins,
    AVG(CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor3_spins') AS INT64))
        FILTER (WHERE CAST(JSON_EXTRACT_SCALAR(custom_attributes, '$.floor3_jackpot') AS INT64) = 1) AS floor3_avg_spins
FROM burger_pyramid_cycle_complete
GROUP BY season_number;
```

---

## 데이터 수집 한계 (검토 포인트)

| 상황 | 수집 여부 | 이유 |
|---|---|---|
| 타겟 수령 완료된 사이클 | ✅ 수집됨 | `burger_pyramid_cycle_complete` 경유 |
| 시즌 종료 시 미완성 사이클 | ✅ 수집됨 | `burger_pyramid_progress_snapshot(season_end)` |
| 앱 백그라운드 전환 시 미완성 상태 | ✅ 수집됨 | `burger_pyramid_progress_snapshot(session_end)` |
| 일일 리셋 시 미완성 상태 | ✅ 수집됨 | `burger_pyramid_progress_snapshot(daily_reset)` |
| 글로벌 천장 발동 시 4층 스핀 수 | ✅ 수집됨 | `bpFloorSpinCounts[3]` (층 임계값 도달과 동시 발동) |
| 스핀 0회 사이클 초기 상태 | ❌ 전송 안 함 | `bpTotalSpins == 0 && bpCurrentFloor == 1` 조건으로 필터링 |

> `session_end`는 앱 강제 종료 시 `OnApplicationPause`가 발화되지 않을 수 있다.  
> 그 경우에도 `daily_reset`과 `season_end`가 보완적으로 상태를 기록한다.

---

## Airbridge 커스텀 파라미터 등록

**사전 등록 불필요.** Airbridge의 커스텀 속성(customAttributes)은 SDK 전송만으로 자동 수집된다. 콘솔에서 별도 등록 없이도 Raw Data Export에 데이터가 쌓인다.

단, 수집 구조는 파라미터별 개별 컬럼이 아닌 **단일 JSON 문자열 컬럼**이다. Raw Data 조회 시 JSON 파싱이 필요하다 (상단 BigQuery 예시 참고).

> 커스텀 속성이 Raw Data에서 개별 컬럼으로 분리되지 않는 이유는 Airbridge의 설계 방침이며, 콘솔 등록으로 해결되지 않는다. 개별 컬럼이 필요하다면 Airbridge의 **Semantic Attributes**(action, label, value 등)를 사용해야 하지만, 현재 파라미터 구조는 semantic attributes와 맞지 않으므로 JSON 파싱 방식이 현실적이다.

---

## Airbridge Raw Data Export 분석

Raw Data Export를 BigQuery/S3 등에 연결하면 파라미터가 다음 컬럼 구조로 적재된다.

커스텀 속성(customAttributes)은 파라미터별 개별 컬럼이 **아니라** `custom_attributes`라는 단일 JSON 문자열 컬럼 하나로 수집된다.

```
// burger_pyramid_cycle_complete — 실제 컬럼 구조
event_name         = "burger_pyramid_cycle_complete"
event_datetime     = "2026-05-11T10:23:00Z"
custom_attributes  = '{"season_number":2,"cycle_number":1,"floor1_jackpot":1,"floor2_jackpot":0,
                       "floor3_jackpot":1,"floor4_jackpot":0,"floor1_floor_pity":0,
                       "floor2_floor_pity":1,"floor3_floor_pity":0,"floor4_floor_pity":0,
                       "global_pity_triggered":1,"floor1_spins":23,"floor2_spins":40,
                       "floor3_spins":8,"floor4_spins":20}'

// burger_pyramid_progress_snapshot — 실제 컬럼 구조
event_name         = "burger_pyramid_progress_snapshot"
event_datetime     = "2026-05-11T23:59:00Z"
custom_attributes  = '{"season_number":2,"completed_cycles":2,"current_floor":2,
                       "floor1_spins":60,"floor2_spins":14,"floor3_spins":0,"floor4_spins":0,
                       "total_spins":74,"snapshot_reason":"season_end"}'
```

값을 꺼내려면 BigQuery 기준 `JSON_EXTRACT_SCALAR(custom_attributes, '$.파라미터명')` 함수를 사용한다 (상단 분석 쿼리 참고).

Raw Data는 수 시간 지연이 있어 실시간 모니터링보다 기획자 주간/월간 분석에 적합하다.

---

