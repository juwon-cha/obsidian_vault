# PunchKing 일일 입장권 미지급 버그 — 분석 및 수정

> **현상**: 주간 시즌 리셋 후 PunchKing 던전 첫 입장 시 일일 입장권이 0개여서 다이아를 소모해야만 플레이 가능  
> **수정일**: 2026-05-07  
> **수정 브랜치**: `juwon/bug-fix`  
> **수정 파일**: `PunchKingDungeonManager.cs`

---

## 재현 조건

1. PunchKing 던전에서 당일 입장권 1장을 모두 사용해 플레이
2. 앱 종료
3. **같은 날** 서버 주간 시즌 리셋 발생 (금요일 자정 UTC 기준)
4. 앱 재실행 후 PunchKing 로비 진입
5. 서버가 이전 시즌 랭킹 보상 팝업 표시 (`HasPreviousSeasonReward = true`)
6. 보상 수령 후 게임 시작 시도 → **"입장권 구매" 패널이 나타남**

---

## 근본 원인

### 관련 코드 구조

`PunchKingDungeonManager.InitializeAsync()`는 앱 시작 시 다음 순서로 리셋을 처리한다:

```csharp
await LoadSaveDataAsync();
await ProcessDailyResetAsync();   // 1. 일일 리셋
await ProcessWeeklyResetAsync();  // 2. 주간 리셋
```

#### `ProcessDailyResetAsync()` 조건

```csharp
if (now.Date > lastReset.Date)   // 캘린더 날짜가 바뀐 경우에만 실행
{
    _saveData.currentChallenges = 1;
    _saveData.lastDailyResetDate = now.Date.ToBinary();
    ...
}
```

#### `ProcessWeeklyResetAsync()` 조건 (수정 전)

```csharp
DateTime lastFriday = GetLastFridayUtc(now);  // 이번 주 금요일 날짜 계산

if (lastReset < lastFriday)   // 마지막 주간 리셋이 이번 주 금요일 이전이면 실행
{
    _saveData.weeklyBestDamage = 0;
    _saveData.weeklyRankRewardClaimed = false;
    _saveData.lastWeeklyResetDate = lastFriday.ToBinary();
    // currentChallenges 는 건드리지 않음!
    ...
}
```

### 버그 발생 흐름

| 시점 | 상태 |
|---|---|
| 금요일 오전: 앱 실행 | `ProcessDailyResetAsync()` 실행 → `currentChallenges = 1`, `lastDailyResetDate = 금요일` |
| 금요일 오전: 게임 플레이 | `TryUseChallengeAsync()` → `currentChallenges = 0`. 저장됨 |
| 금요일 자정: 서버 시즌 리셋 | 서버 `prevMyRank` 갱신, `HasPreviousSeasonReward = true` 상태 생성 |
| **금요일 재실행 (버그 발생)** | |
| `ProcessDailyResetAsync()` | `금요일 > 금요일` = **FALSE** → 티켓 미지급, `currentChallenges = 0` 유지 |
| `ProcessWeeklyResetAsync()` | `지난주금요일 < 이번주금요일` = **TRUE** → 주간 데이터 리셋, 하지만 `currentChallenges` 미변경 |
| PunchKing 로비 진입 | 서버: `HasPreviousSeasonReward = true` 표시 |
| 보상 수령 후 게임 시작 | `CurrentChallenges = 0` → **"입장권 구매" 패널 표시** |

### 핵심 문제

**일일 리셋과 주간 리셋이 서로 독립적으로 동작** 하기 때문에, 주간 리셋이 일어나더라도 같은 날 일일 리셋이 이미 실행됐다면 새 주의 첫 입장권이 지급되지 않는다.

- `ProcessDailyResetAsync()` → 캘린더 날짜 변경 시에만 티켓 지급 (`now.Date > lastDailyResetDate.Date`)
- `ProcessWeeklyResetAsync()` → 주간 데이터만 리셋, `currentChallenges` 미처리

---

## 수정 내용

### `PunchKingDungeonManager.ProcessWeeklyResetAsync()` 수정

주간 리셋 발생 시, 일일 티켓도 함께 지급하도록 일일 리셋 필드를 동일하게 초기화한다.

```csharp
// 수정 전
if (lastReset < lastFriday)
{
    _saveData.weeklyBestDamage = 0;
    _saveData.weeklyRankRewardClaimed = false;
    _saveData.lastWeeklyResetDate = lastFriday.ToBinary();

    if (_saveData.seasonalShopPurchases != null)
        _saveData.seasonalShopPurchases.Clear();

    await SaveDataAsync();
}

// 수정 후
if (lastReset < lastFriday)
{
    _saveData.weeklyBestDamage = 0;
    _saveData.weeklyRankRewardClaimed = false;
    _saveData.lastWeeklyResetDate = lastFriday.ToBinary();

    // 주간 리셋 시 일일 티켓도 지급
    // 이미 오늘 플레이한 경우 일일 리셋이 스킵되므로 여기서 강제 부여
    _saveData.currentChallenges = 1;
    _saveData.purchasedChallenges = 0;
    _saveData.todayBestDamage = 0;
    _saveData.lastDailyResetDate = now.Date.ToBinary();

    if (_saveData.dailyShopPurchases != null)
        _saveData.dailyShopPurchases.Clear();

    if (_saveData.seasonalShopPurchases != null)
        _saveData.seasonalShopPurchases.Clear();

    await SaveDataAsync();
}
```

---

## 수정 안전성 검증

| 시나리오 | 수정 전 | 수정 후 |
|---|---|---|
| **버그 시나리오**: 같은 날 플레이 후 주간 리셋, 재실행 | `currentChallenges = 0` ❌ | `currentChallenges = 1` ✅ |
| **정상 시나리오**: 다음 날 재실행 | 일일 리셋이 먼저 실행 → `currentChallenges = 1` ✅ | 일일 리셋(`=1`) 후 주간 리셋이 같은 값 덮어씀 → `currentChallenges = 1` ✅ |
| **주간 리셋 없음**: 새 날만 실행 | 일일 리셋만 동작 → `currentChallenges = 1` ✅ | 변경 없음 ✅ |
| **당일 재실행, 주간 리셋 없음** | 아무것도 실행 안 됨 → 유지 ✅ | 변경 없음 ✅ |

다음 날 재실행 시에는 `ProcessDailyResetAsync()`가 먼저 `currentChallenges = 1`을 설정하고, `ProcessWeeklyResetAsync()`가 같은 값으로 덮어쓰기 때문에 이중 지급 없이 안전하다.

---

## 함께 수정된 내용 (동일 세션)

### 1. `PunchKingRankRewardPopupUI.ClaimRewardAsync()` — `MarkWeeklyRankRewardClaimed()` 누락

보상 수령 성공 후 `weeklyRankRewardClaimed = true`로 마킹하는 호출이 빠져 있었다.

```csharp
// 수정 전
GiveRewardsToPlayer();
CloseUI();

// 수정 후
GiveRewardsToPlayer();
_punchKingManager?.MarkWeeklyRankRewardClaimed();  // 추가
CloseUI();
```

### 2. `PunchKingLobbyUI` — `DailyReset` 이벤트 미구독

로비가 열려 있는 상태에서 자정이 지나 `DailyReset` 이벤트가 발생해도 UI가 갱신되지 않는 문제.

```csharp
// SubscribeToEvents()에 추가
EventManager.Subscribe<TimeEventData>(GameEventType.DailyReset, HandleDailyReset);

// UnsubscribeFromEvents()에 추가
EventManager.Unsubscribe<TimeEventData>(GameEventType.DailyReset, HandleDailyReset);

// 핸들러 추가
private void HandleDailyReset(TimeEventData eventData)
{
    UpdateUI();
}
```
