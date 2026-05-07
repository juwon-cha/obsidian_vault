# PunchKing 일일 입장권 미지급 버그 — 분석 및 수정

> **현상**: 주간 시즌 리셋 후 PunchKing 던전 첫 입장 시 일일 입장권이 0개여서 다이아를 소모해야만 플레이 가능  
> **수정일**: 2026-05-07  
> **수정 브랜치**: `juwon/bug-fix`  
> **수정 파일**: `PunchKingDungeonManager.cs`, `PunchKingRankRewardPopupUI.cs`, `PunchKingLobbyUI.cs`

---

## 게임 스펙

- PunchKing은 하루 최대 **3회** 플레이 가능 (기본 1회 + 다이아 구매 최대 2회)
- 매일 앱 실행 시 `ProcessDailyResetAsync()`가 기본 입장권 1회 지급
- 주간(매주 금요일 UTC 기준) 서버 시즌 리셋 발생 시 이전 시즌 랭킹 보상 팝업 표시

---

## 버그 현상

- 주간 시즌 리셋 후 PunchKing 로비 **첫 입장 시** 입장권이 0개
- 로비 진입 토스트에 "입장권 지급 + **0**" 표시
- START 버튼 클릭 시 다이아 구매 패널이 즉시 표시됨

---

## 재현 조건

1. 주간 리셋 이전에 PunchKing을 플레이해 당일 입장권 1회 모두 소진
2. 앱이 자정을 넘겨 실행 중이거나, 이후 앱을 재실행
3. 서버 주간 시즌 리셋 발생 (금요일 자정 UTC 기준)
4. PunchKing 로비 진입 → 이전 시즌 랭킹 보상 팝업 표시
5. 보상 수령 → 게임 시작 시도 → **"입장권 구매" 패널 표시**

---

## 근본 원인 (2가지 경로)

### 공통 구조

`PunchKingDungeonManager.InitializeAsync()`는 앱 시작 시 다음 순서로 리셋을 처리한다:

```csharp
await LoadSaveDataAsync();
await ProcessDailyResetAsync();   // 1. 일일 리셋
await ProcessWeeklyResetAsync();  // 2. 주간 리셋
```

`ProcessDailyResetAsync()` 조건:
```csharp
if (now.Date > lastReset.Date)  // 캘린더 날짜가 바뀐 경우에만 실행
{
    _saveData.currentChallenges = 1;
    _saveData.lastDailyResetDate = now.Date.ToBinary();
    ...
}
```

---

### 원인 A — `ProcessWeeklyResetAsync()`가 입장권을 지급하지 않음

**발생 경로**: 앱이 자정을 넘겨 실행 중인 경우

| 시점 | 상태 |
|---|---|
| 목요일: 플레이 | `currentChallenges = 0`, `lastDailyResetDate = 목요일` |
| 목요일 → 금요일 자정 (앱 실행 중) | `DailyReset` **이벤트** 발동 → `currentChallenges = 1`, `lastDailyResetDate = 금요일` |
| 금요일: 서버 시즌 리셋 | `HasPreviousSeasonReward = true` |
| 금요일: 플레이 → 소진 | `currentChallenges = 0` |
| **금요일 재실행** | |
| `ProcessDailyResetAsync()` | `금요일 > 금요일` = **FALSE** → 미지급 |
| `ProcessWeeklyResetAsync()` | `lastWeeklyResetDate(지난주금요일) < lastFriday(이번주금요일)` = **TRUE** → 실행되지만 `currentChallenges` 미변경 |
| 결과 | `currentChallenges = 0` ❌ |

> `WeeklyReset` **이벤트**는 월요일 자정에만 발동된다. 금요일 재실행 시 `lastWeeklyResetDate`가 아직 이전 주 금요일이므로 주간 리셋 조건이 TRUE가 되지만, 수정 전 코드는 `currentChallenges`를 건드리지 않았다.

---

### 원인 B — 서버 `ResetLastSeason` 호출이 클라우드 세이브를 덮어씀

**발생 경로**: 주간 보상 수령 후 다음 앱 실행 시

| 세션 | 시점 | 발생 내용 |
|---|---|---|
| **이전 세션** | 앱 실행 | `ProcessDailyResetAsync()` → `currentChallenges = 1`, `lastDailyResetDate = 오늘` → 클라우드 저장 |
| | 주간 보상 수령 | `ResetPunchKingLastSeasonDataAsync()` 호출 → **서버가 클라우드 세이브의 `currentChallenges = 0`으로 덮어씀** |
| | 클라이언트 메모리 | `currentChallenges = 1` (메모리는 정상) → 해당 세션은 정상 플레이 가능 |
| **다음 세션** | 앱 재실행 | 클라우드 로드: `currentChallenges = 0`, `lastDailyResetDate = 오늘` |
| | `ProcessDailyResetAsync()` | `오늘 > 오늘` = **FALSE** → 미지급 |
| | `ProcessWeeklyResetAsync()` | `lastWeeklyResetDate = 이번주금요일`이면 **FALSE** → 미실행 |
| | 로비 첫 입장 | `currentChallenges = 0` → 토스트 "0", START 클릭 시 구매 패널 ❌ |

> 서버의 `ResetPunchKingLastSeasonDataAsync()`가 `currentChallenges = 0`은 덮어쓰지만 `lastDailyResetDate`는 오늘 날짜 그대로 보존하기 때문에, 다음 세션에서 일일 리셋 조건이 FALSE가 된다.

---

## 수정 내용

### Fix 1 — `ProcessWeeklyResetAsync()`에 일일 티켓 지급 추가

원인 A 대응: 주간 리셋 발생 시 일일 리셋 필드를 함께 초기화한다.

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

### Fix 2 — `MarkWeeklyRankRewardClaimed()`에 `lastDailyResetDate` 초기화 추가

원인 B 대응: 보상 수령 후 `lastDailyResetDate = 0`으로 초기화해, 서버가 `currentChallenges`를 어떻게 변경하든 다음 앱 실행 시 일일 리셋이 반드시 발동되도록 보장한다.

```csharp
// 수정 전
public void MarkWeeklyRankRewardClaimed()
{
    if (_saveData == null) return;

    _saveData.weeklyRankRewardClaimed = true;
    SafeForget(SaveDataAsync()).Forget();
}

// 수정 후
public void MarkWeeklyRankRewardClaimed()
{
    if (_saveData == null) return;

    _saveData.weeklyRankRewardClaimed = true;
    // 서버의 ResetLastSeason 호출이 클라우드 세이브의 currentChallenges를 0으로 덮어쓸 수 있음
    // lastDailyResetDate를 초기화해 다음 앱 실행 시 일일 리셋이 반드시 발동되도록 보장
    _saveData.lastDailyResetDate = 0;
    SafeForget(SaveDataAsync()).Forget();
}
```

`lastDailyResetDate = 0`으로 설정하면 다음 실행 시 `ProcessDailyResetAsync()` 조건 `now.Date > DateTime.MinValue` = **항상 TRUE**가 되어 `currentChallenges = 1`이 보장된다.

---

## 수정 안전성 검증

| 시나리오 | Fix 1 | Fix 2 | 결과 |
|---|---|---|---|
| 원인 A: 자정 넘겨 플레이 → 재실행 | ✅ 주간 리셋 조건 TRUE 시 `currentChallenges = 1` 지급 | — | ✅ |
| 원인 B: 서버 덮어쓰기 → 다음 세션 | — | ✅ `lastDailyResetDate = 0` → 일일 리셋 강제 발동 | ✅ |
| 정상: 다음 날 앱 재실행 | 일일 리셋 먼저 실행 후 주간 리셋 중복 설정 (무해) | `lastDailyResetDate = 0` 없으면 Fix 2 비발동 (정상 케이스) | ✅ |
| 당일 재실행, 주간 리셋 없음 | 미변경 | 미변경 | ✅ |

Fix 2로 `lastDailyResetDate = 0`이 클라우드에 저장되면, 다음 실행의 `ProcessDailyResetAsync()`가 `purchasedChallenges = 0`, `todayBestDamage = 0`, `dailyShopPurchases 초기화`까지 함께 수행해 새 시즌 상태를 완전히 복원한다.

---

## 함께 수정된 내용 (동일 세션)

### 3. `PunchKingRankRewardPopupUI.ClaimRewardAsync()` — `MarkWeeklyRankRewardClaimed()` 누락

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

### 4. `PunchKingLobbyUI` — `DailyReset` 이벤트 미구독

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
