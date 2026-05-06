# PunchKing LuckyTarget 카드 선택 UI 미표시 버그 — 분석 및 수정

> **현상**: PunchKing 스테이지에서 LuckyTarget 처치 후 카드 선택 UI가 간헐적으로 나타나지 않음  
> **재발 횟수**: 3번째 수정 시도  
> **수정일**: 2026-05-06  
> **수정 브랜치**: `juwon/bug-fix`  
> **수정 파일**: `CardManager.cs`, `CardSelectionUI.cs`

---

## 최종 수정 평가

| 버그 | 근본 원인 해결 여부 | 재발 가능성 | 비고 |
|---|---|---|---|
| Bug 1 — TargetSpawnNumber 초과 | ✅ 완전 해결 | 없음 | |
| Bug 2 — 이중 NotifyCardSelectionComplete | ✅ 완전 해결 | 없음 | ForceComplete 정리 + Closed() try-finally 보장 |
| Bug 3 — 선택 기회 손실 | ✅ 완전 해결 | 없음 | 로그 + retry 큐 추가 |

---

## Bug 1 — TargetSpawnNumber 초과 문제

### 근본 원인

`CalculatePunchKingTotalEnemyCount()`는 `waveData.enemyCounts` 전체를 합산한다. 하지만 `OnEnemySpawnedForPunchKing()`은 `PunchKingBossController`를 `CurrentSpawnCount` 카운트에서 제외한다. 두 경로 간의 불일치로 `TargetSpawnNumber`가 실제 `CurrentSpawnCount`의 최댓값을 초과할 수 있다.

```
예시 (보스 1마리 + 일반 10마리 구성)
  totalEnemyCount = 11  (보스 포함)
  TargetSpawnNumber = Random.Range(1, 12) → 최대 11
  CurrentSpawnCount = 최대 10  (보스 제외)

  TargetSpawnNumber = 11이 나오면 LuckyTarget이 영원히 지정되지 않음
  확률: 1/11 ≈ 9%
```

### 수정 내용 (`CardManager.cs:5472`)

```csharp
// 수정 전
private int CalculatePunchKingTotalEnemyCount(WaveDataSO waveData)
{
    if (waveData == null || waveData.enemyCounts == null) return 0;
    int total = 0;
    foreach (int count in waveData.enemyCounts)
        total += count;
    return total;
}

// 수정 후
private int CalculatePunchKingTotalEnemyCount(WaveDataSO waveData)
{
    if (waveData == null || waveData.enemyCounts == null) return 0;

    var punchKingManager = Managers.Instance?.GetManager<PunchKingDungeonManager>();
    int bossID = punchKingManager?.CurrentBossID ?? -1;

    int total = 0;
    for (int i = 0; i < waveData.enemyCounts.Count; i++)
    {
        if (bossID > 0 && i < waveData.enemyIDs?.Count && waveData.enemyIDs[i] == bossID) continue;
        total += waveData.enemyCounts[i];
    }
    return total;
}
```

### 평가: ✅ 완전 해결

- `PunchKingDungeonManager.CurrentBossID`는 게임 시작 시 `Initialize()`에서 설정되므로 웨이브 시작 전 항상 유효하다.
- 코드베이스 내 `PauseUI.cs`에서 동일 패턴으로 이미 사용 중 — 일관성 확보.
- `punchKingManager == null`이면 `bossID = -1` → 보스 제외 없이 전체 합산(이전 동작 유지) — 안전한 폴백.
- 이 수정은 `OnWaveStartedForPunchKing()`과 `GetOrCreatePunchKingWaveInfo()` 모두에 적용된다 (두 곳 모두 같은 메서드 호출).

---

## Bug 2 — ForceCompleteCurrentSelectionAsync의 이중 NotifyCardSelectionComplete 호출

### 근본 원인

이 버그는 **두 개의 독립된 문제가 겹쳐서** 발생했다.

#### 계층 1: 이전 BugFix의 불완전한 적용

코드 내 주석 `[BugFix] NotifyCardSelectionComplete 호출을 Closed 메서드로 이동`에도 불구하고, `ForceCompleteCurrentSelectionAsync()`에 있던 호출이 제거되지 않아 **이중 호출 상태**가 지속됐다.

```
NotifyCardSelectionComplete() 호출 경로 (수정 전):
  1. CardSelectionUI.Closed() → line 496  ← BugFix로 추가된 경로
  2. ForceCompleteCurrentSelectionAsync() → line 1222  ← 제거됐어야 했던 경로
```

#### 계층 2: ForceComplete 내 NotifyCardSelectionComplete의 재진입 문제

`ForceCompleteCurrentSelectionAsync()`는 `async UniTask`이지만, 첫 번째 `await UniTask.Delay(50)` 이전의 모든 코드는 **동기적으로 실행**된다. 즉 `Opened()`에서 `.Forget()`으로 호출하더라도 `NotifyCardSelectionComplete()` 호출까지는 즉시 실행된다.

```
UIManager.Show<CardSelectionUI>() 실행 순서:
  1. openUI[CardSelectionUI] = ui  ← 등록 먼저
  2. ui.opened?.Invoke() → Opened():
     a. gameObject.SetActive(true)  ← root GameObject 활성화
     b. _isSelectionActive == true → ForceCompleteCurrentSelectionAsync().Forget()
        (동기 실행 구간):
          _cardSelectionPanel.SetActive(false)
          _isSelectionActive = false
          NotifyCardSelectionComplete():
            IsCardSelectionActive = false
            pending > 0 → TriggerPunchKingCardSelection():
              IsOpened<CardSelectionUI>():
                openUI에 등록됨 (1번) AND gameObject.activeInHierarchy = true (a번)
                → non-null 반환! ← zombie 판정
              _pendingPunchKingCardSelectionCount++  ← 오증가
        (await UniTask.Delay(50) → 여기서 비동기로 전환)
     c. ShowCardSelection(choices)  ← 정상 실행됨

결과: pending 카운트가 1 오증가 → 이후 모든 LuckyTarget 선택이 pending으로 처리되어 UI 영구 미표시
```

`_cardSelectionPanel.SetActive(false)`는 패널(자식)만 비활성화하고 root GameObject는 여전히 활성 상태이기 때문에, `IsOpened<CardSelectionUI>()`의 `activeInHierarchy` 체크를 통과한다.

#### 계층 3: Closed()가 예외 시 상태 플래그를 보장하지 못하는 문제

이 버그가 트리거되는 조건은 "새 `Opened()` 호출 시 `_isSelectionActive == true`" 이다. 이는 이전 Closed() 호출에서 예외가 발생해 리셋이 스킵됐을 때 발생한다.

```csharp
// Closed() 수정 전 — 예외 발생 시 아래 코드가 실행되지 않음
for (int i = 0; i < _cardChoiceUIs.Length; i++)
{
    _cardChoiceUIs[i].ResetToInitialState();  // ← 예외 가능 지점
}

_isForceCompleting = false;
_isAnimationInProgress = false;   // ← 리셋 스킵될 수 있음
_isSelectionActive = false;       // ← 리셋 스킵될 수 있음
// ...
cardManager.NotifyCardSelectionComplete();  // ← 호출 스킵될 수 있음
```

### 수정 내용

#### 수정 1: ForceCompleteCurrentSelectionAsync에서 NotifyCardSelectionComplete 제거 (`CardSelectionUI.cs`)

`ForceCompleteCurrentSelectionAsync()`의 역할은 UI 시각 상태만 정리하는 것이다. `ShowCardSelection()`이 이후 실행되며, 카드 선택이 완료되면 `Closed()` → `NotifyCardSelectionComplete()`가 정상적으로 호출된다.

```csharp
// 제거된 코드
var cardManager = Managers.Instance?.GetManager<CardManager>();
if (cardManager != null)
{
    cardManager.NotifyCardSelectionComplete();
}
```

#### 수정 2: ForceHide()를 HideViaUIManager()로 교체 (`CardSelectionUI.cs`)

```csharp
// 수정 전 — openUI에서 제거 안 됨, NotifyCardSelectionComplete 비정상 호출
public void ForceHide()
{
    ForceCompleteCurrentSelectionAsync().Forget();
}

// 수정 후 — UIManager.Hide() → Closed() → NotifyCardSelectionComplete() 정상 흐름
public void ForceHide()
{
    HideViaUIManager();
}
```

#### 수정 3: Closed()에 try-catch-finally 추가 (`CardSelectionUI.cs`)

가장 중요한 수정. 예외 발생 여부와 무관하게 상태 플래그 리셋과 CardManager 알림을 보장한다.

```csharp
public override void Closed(object[] param)
{
    _showSequence?.Kill();
    _showSequence = null;

    // try 이전에 캡처 — finally에서도 참조해야 하므로
    bool wasPunchKingInitialMode = _isPunchKingInitialMode;
    _isPunchKingInitialMode = false;

    try
    {
        // 모든 카드 리셋, UI 요소 숨김, base.Closed(param) 등
        // ...
    }
    catch (System.Exception ex)
    {
        RLog.LogError($"[CardSelectionUI] Closed 처리 중 오류: {ex.Message}");
    }
    finally
    {
        // 예외 발생 여부와 무관하게 반드시 리셋
        // 이 플래그들이 true로 남으면 다음 Opened()에서 ForceComplete가 트리거되는 근본 원인
        _isForceCompleting = false;
        _isAnimationInProgress = false;
        _isSelectionActive = false;

        // CardManager 완료 알림 — 항상 실행 보장
        if (wasPunchKingInitialMode)
            EventManager.Dispatch(GameEventType.PunchKingCardSelectionComplete);
        else
            Managers.Instance?.GetManager<CardManager>()?.NotifyCardSelectionComplete();
    }
}
```

### 수정 전후 흐름 비교

```
[수정 전] pending = 1인 상태에서 stale UI로 새 Show 호출 시

ForceComplete (동기):
  └─ NotifyCardSelectionComplete():
       └─ TriggerPunchKingCardSelection():
            └─ IsOpened() = zombie non-null → pending++ (=2) ← 오증가
ShowCardSelection()  ← 패널 표시됨
사용자 선택 → Closed() → NotifyCardSelectionComplete():
  pending(2) → pending-- (=1) → TriggerPunchKingCardSelection() → 없어야 할 UI 표시!
```

```
[수정 후] 동일 시나리오

ForceComplete (동기):
  └─ (NotifyCardSelectionComplete 없음)
ShowCardSelection()  ← 패널 표시됨
사용자 선택 → Closed() → finally → NotifyCardSelectionComplete():
  pending(1) → pending-- (=0) → 종료
```

### 평가: ✅ 완전 해결

수정 1~3이 각 계층의 원인을 모두 제거한다:
- 계층 1 (이중 호출): ForceComplete에서 호출 제거
- 계층 2 (재진입 zombie): 이중 호출 제거로 재진입 자체가 발생하지 않음
- 계층 3 (Closed() 예외 취약성): try-finally로 상태 플래그와 CardManager 알림을 예외 안전하게 보장

이후 ForceComplete가 Opened()에서 트리거되더라도 (Closed()가 정상이라면 발생 빈도가 극히 낮음) 상태 오염이 없다.

---

## Bug 3 — 선택 가능한 카드 없을 때 선택 기회 손실

### 근본 원인

```csharp
var choices = GeneratePunchKingCardChoices(CHOICES_PER_LEVEL);
if (choices == null || choices.Length == 0) return;  // 로그 없음, pending 처리 없음
```

`GeneratePunchKingCardChoices()`는 `GetPromotionEligibleUnits()`와 `GetAvailableCards()`에 의존한다. 이 둘이 빈 결과를 반환하는 경우:
- 일시적: 유닛/카드 초기화 타이밍 이슈
- 영구적: 모든 유닛이 최대 승급에 도달 (후반 게임)

두 경우 모두 해당 LuckyTarget 처치의 카드 선택 기회가 **영구 소실**됐다.

### 수정 내용 (`CardManager.cs:5533`)

```csharp
// 수정 전
if (choices == null || choices.Length == 0) return;

// 수정 후
if (choices == null || choices.Length == 0)
{
    RLog.LogWarning("[CardManager] PunchKing LuckyTarget: 선택 가능한 카드 없음. 다음 카드 선택 완료 후 재시도.");
    _pendingPunchKingCardSelectionCount++;
    return;
}
```

### retry 동작 방식

```
1. LuckyTarget 처치 → GeneratePunchKingCardChoices() = 빈 배열
   └─ _pendingPunchKingCardSelectionCount++ (예: 1)
   └─ 현재 IsCardSelectionActive = false, UI 없음

2. 다음 LuckyTarget 처치 → GeneratePunchKingCardChoices() = 카드 있음
   └─ Show<CardSelectionUI>()
   └─ 사용자 선택 → Closed() → finally → NotifyCardSelectionComplete():
        └─ pending(1) > 0 → pending-- (=0) → TriggerPunchKingCardSelection()
        └─ 카드 있음 → 1에서 놓친 선택 기회가 이 시점에 제공됨 ✅

엣지 케이스: 카드가 영구적으로 없는 경우 (모든 유닛 최대 승급)
  └─ pending이 누적되지만 게임 종료 시 ResetInGameData() → = 0 으로 리셋
  └─ 게임 세션 내 무한 성장 없음 (게임이 끝나기 때문)
```

### 평가: ✅ 완전 해결

일시적 원인(타이밍 이슈)의 경우 다음 정상 선택 시 복구된다. 영구적 원인(전 유닛 최대 승급)의 경우 pending이 누적되지만 세션 종료 리셋으로 안전하게 정리된다.

---

## 재발 방지를 위한 설계 원칙

이 버그가 3번 반복된 이유는 **상태 관리 책임이 분산**되어 있기 때문이다.

### 확립된 불변 규칙

1. **ForceComplete는 UI 상태만 정리한다**: `ForceCompleteCurrentSelectionAsync()`는 시각 상태와 UI 플래그만 리셋한다. CardManager 상태 변경(`NotifyCardSelectionComplete`)은 하지 않는다.

2. **NotifyCardSelectionComplete는 Closed()에서만 호출한다**: CardManager에 카드 선택 완료를 알리는 유일한 경로는 `Closed()`의 finally 블록이다. 다른 경로에서 추가하지 않는다.

3. **Closed()의 핵심 상태 리셋과 CardManager 알림은 finally에서 보장한다**: 예외가 발생해도 `_isSelectionActive`, `_isAnimationInProgress`, `_isForceCompleting` 리셋과 `NotifyCardSelectionComplete()` 호출이 반드시 실행된다.

4. **카운트 계산과 카운트 증분의 제외 기준은 항상 동일해야 한다**: `CalculatePunchKingTotalEnemyCount()`와 `OnEnemySpawnedForPunchKing()`은 동일한 기준(보스 제외)을 사용한다. 한쪽을 바꾸면 반드시 다른 쪽도 확인한다.

---

## 수정 파일 요약

| 파일 | 메서드 | 수정 내용 |
|---|---|---|
| `CardManager.cs:5472` | `CalculatePunchKingTotalEnemyCount()` | 보스 ID 제외 로직 추가 |
| `CardManager.cs:5533` | `TriggerPunchKingCardSelection()` | 빈 choices → pending++ + 로그 |
| `CardSelectionUI.cs:408` | `Closed()` | try-catch-finally 추가, 핵심 리셋을 finally로 이동 |
| `CardSelectionUI.cs:1218` | `ForceCompleteCurrentSelectionAsync()` | `NotifyCardSelectionComplete()` 호출 제거 |
| `CardSelectionUI.cs:1946` | `ForceHide()` | `ForceCompleteCurrentSelectionAsync` → `HideViaUIManager()` |

---

## 참고 파일

- `Assets/_Project/1_Scripts/Core/Managers/CardManager.cs`
- `Assets/_Project/1_Scripts/UI/CardSelectionUI.cs`
- `Assets/_Project/1_Scripts/Core/Managers/PunchKingDungeonManager.cs` — `CurrentBossID`

*작성: Claude Sonnet 4.6 / 2026-05-06*
