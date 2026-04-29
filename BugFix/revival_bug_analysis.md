# 부활 버그 분석 — 게임오버 직전 카드 선택 UI 충돌

> **작성일:** 2026-04-29  
> **분류:** Race Condition / UI 충돌  
> **심각도:** 🔴 High — 무과금 부활 및 게임 상태 불일치 유발 가능

---

## 1. 요약

게임오버 시점과 카드 선택 UI 표시 시점 사이에 **레이스 컨디션**이 존재합니다.  
`CardManager`가 `IsStageActive`만으로 게임 활성 여부를 판단하기 때문에, `GameRetryUI`가 화면에 표시된 상태에서도 카드 선택 UI가 열릴 수 있습니다.

---

## 2. 게임오버 흐름

```
[경로 A] 뱀이 끝 지점 도달
BaseSnakeController.GameOver()
  └─ isGameOverProcess = true
  └─ DelayedGameOverAsync() (fire-and-forget)
       └─ GameRetryUI.ShowAsync()      ← Time.timeScale = 0
       └─ await ReceiveAsync()         ← 플레이어 응답 대기
            ├─ (계속하기) → isGameOverProcess = false, return
            │               ※ ForceCloseCardSelectionUI 호출 없음!
            └─ (포기)     → ForceCloseCardSelectionUI()
                          → SendGameOverEvent()
                          → HandleGameOver() → IsStageActive = false

[경로 B] 기지 HP 0
BaseSystemManager.DelayedGameOverAsync()
  └─ Time.timeScale = 0
  └─ ForceCloseCardSelectionUI()   ← 즉시 호출
  └─ SendGameOverEvent()
```

> **핵심 문제:** `IsStageActive`는 `GameRetryUI`가 표시되는 내내 `true`를 유지합니다.  
> `SendGameOverEvent()` 이후에야 `false`로 바뀝니다.

---

## 3. 근본 원인

### CardManager.IsGameActive() — GameRetryUI를 전혀 체크하지 않음

```csharp
private bool IsGameActive()
{
    var stageManager = Managers.Instance.GetManager<StageManager>();
    bool isStageActive = stageManager.IsStageActive;
    if (!isStageActive) return false;
    // GameRetryUI가 열려있는지 전혀 확인하지 않음 ← 문제
    return true;
}
```

### CardManager의 딜레이는 UnscaledDeltaTime 사용

```csharp
await UniTask.Delay(100, DelayType.UnscaledDeltaTime, cancellationToken: token);
```

`Time.timeScale = 0`이어도 CardManager의 비동기 루프는 계속 동작합니다.

### _cardSelectionProcessCts는 게임오버 시 취소되지 않음

`ResetInGameData()`가 CTS를 취소하는데, 이 함수는 `StageStarted` 이벤트에서만 호출됩니다.  
즉, 게임오버 중에도 카드 선택 큐는 계속 처리됩니다.

---

## 4. 버그 시나리오

### 🔴 시나리오 A — 가장 흔한 케이스 (타이밍 레이스)

| 단계 | 발생 내용 |
|------|-----------|
| Frame N | 정예/보스 처치 → `EnqueueEliteCardSelectionRequest()` → 100ms 딜레이 대기 중 |
| Frame N+1 | 뱀 끝 도달 → `isGameOverProcess = true` → `GameRetryUI` 표시 |
| 100ms 후 | `ProcessCardSelectionQueueAsync` 깨어남 → `IsGameActive()` → `IsStageActive = true` → **통과** |
| 결과 | **CardSelectionUI가 GameRetryUI 위에 열림** |

---

### 🔴 시나리오 B — 카드 선택 도중 뱀 도달

| 단계 | 발생 내용 |
|------|-----------|
| 초기 상태 | `CardSelectionUI` 열려있음, `WaitForCardSelectionComplete()` 대기 중 |
| 동시 발생 | 뱀 끝 도달 → `GameRetryUI` 열림 → **두 UI가 동시에 화면에 표시** |
| 결과 | 플레이어가 카드 선택 → `CardSelectionUI` 닫힘 → 뒤에 있던 `GameRetryUI` 노출 (혼란 유발) |

---

### 🔴 시나리오 C — 부활 애니메이션 1.1초 중 카드 등장

```csharp
// GameRetryUI.cs
marineAnimator.Play("Respawn_Start");
await UniTask.Delay(TimeSpan.FromSeconds(1.1f), ignoreTimeScale: true); // ← unscaled
RocketDan.Msg.Publish(new OnClickAdContinue(true, ...));
uiManager?.Hide(); // 여기서야 RestoreTimeScale() 호출
```

"계속하기"를 눌러도 **1.1초 동안 `Time.timeScale = 0` + `IsStageActive = true`** 상태가 유지됩니다.  
이 사이에 CardManager가 큐를 처리하면 **부활 애니메이션 중에 카드 선택 UI가 나타납니다.**

---

### 🟡 시나리오 D — 부활 성공 후 ForceCloseCardSelectionUI 미호출

```csharp
// BaseSnakeController.cs
if (result.Retry)
{
    _baseSystemManager.DeadCount += 1;
    isGameOverProcess = false;
    return; // ← ForceCloseCardSelectionUI 호출 없이 리턴!
}

// 포기 경로에서만 호출됨
ForceCloseCardSelectionUI();
SendGameOverEvent(reason);
```

부활 성공 시 `CardSelectionUI`가 열려있었다면 **그대로 잔류**합니다.

---

### 🟡 시나리오 E — BunkerHealOnCardSelection 칩에 의한 실질적 기지 회복

| 단계 | 발생 내용 |
|------|-----------|
| 전제 | `BunkerHealOnCardSelection` 칩 장착 + 기지 HP 매우 낮음 |
| 시나리오 A 발동 | `CardSelectionUI`가 `GameRetryUI` 위에 열림 |
| 플레이어 카드 선택 | `ApplyBunkerHealOnCardSelection()` → **기지 HP 회복** |
| 결과 | 광고/재화 소모 없이 기지 체력 증가 → 사실상 **무과금 부활** |

---

## 5. ForceCloseCardSelectionUI의 한계

```csharp
// BaseSnakeController.cs
private void ForceCloseCardSelectionUI()
{
    var cardSelectionUI = uiManager.IsOpened<CardSelectionUI>();
    if (cardSelectionUI != null)
        uiManager.Hide<CardSelectionUI>(); // UI만 닫음
    // ← CardManager의 _cardSelectionProcessCts를 취소하지 않음
    // ← 큐가 비어있지 않으면 다음 항목이 또 처리됨
}
```

UI를 닫아도 **CardManager의 큐와 CTS는 살아있어서** 게임오버 직후에도 새 카드 선택이 다시 열릴 수 있습니다.

---

## 6. 버그가 간헐적인 이유

| 조건 | 상세 |
|------|------|
| 정확한 타이밍 필요 | 정예/보스 사망 + 뱀 도착이 수 프레임 차이 내 발생 |
| CardManager 큐 딜레이 | 100ms await 도중 race window 발생 |
| 재현 어려움 | 테스트 환경에서 게임 진행 속도가 달라 타이밍이 맞지 않음 |
| 칩 의존 | 시나리오 E는 `BunkerHealOnCardSelection` 칩 미장착 시 미발동 |

---

## 7. 재현 조건

```
1. BunkerHealOnCardSelection 칩 장착
2. 기지 HP 10% 이하 상태
3. 정예/보스 처치 (카드 선택 큐에 1개 이상 대기)
4. 뱀이 끝 지점 도달
```

---

## 8. 수정 방향

### ✅ 권장: IsGameActive()에 GameRetryUI 체크 추가 (가장 방어적)

```csharp
private bool IsGameActive()
{
    var stageManager = Managers.Instance.GetManager<StageManager>();
    if (!stageManager.IsStageActive) return false;

    var uiManager = Managers.Instance.GetManager<UIManager>();
    if (uiManager?.IsOpened<GameRetryUI>() != null) return false;
    if (uiManager?.IsOpened<ArkGameRetryUI>() != null) return false;
    if (uiManager?.IsOpened<GameResultUI>() != null) return false; // 추가 권장

    return true;
}
```

- 시나리오 A, B, C, E를 **모두 커버**
- `GameResultUI`도 포함하면 결과 화면 이후 카드 선택 재발 방지 가능

---

### ✅ 병행 권장: 부활 성공 경로에 ForceCloseCardSelectionUI 추가

```csharp
// BaseSnakeController.cs — DelayedGameOverAsync
if (result.Retry)
{
    _baseSystemManager.DeadCount += 1;
    isGameOverProcess = false;
    ForceCloseCardSelectionUI(); // ← 추가 (시나리오 D 수정)
    return;
}
```

---

### 💡 추가 고려: ForceStopCardSelectionQueue() 신설

```csharp
// CardManager.cs
public void ForceStopCardSelectionQueue()
{
    _cardSelectionProcessCts?.Cancel();
    _cardSelectionProcessCts?.Dispose();
    _cardSelectionQueue.Clear();
    // CardSelectionUI도 강제 닫기
    var uiManager = Managers.Instance.GetManager<UIManager>();
    if (uiManager?.IsOpened<CardSelectionUI>() != null)
        uiManager.Hide<CardSelectionUI>();
}
```

`DelayedGameOverAsync` 진입 시 호출하면 큐 자체를 원천 차단할 수 있습니다.  
단, BaseSnakeController와 BaseSystemManager 두 경로 모두에 적용해야 하고 향후 경로 추가 시 누락 위험이 있으므로 **IsGameActive() 수정과 병행**하는 것을 권장합니다.

---

## 9. 수정 우선순위

| 우선순위 | 수정 내용 | 커버 시나리오 |
|---------|-----------|--------------|
| 1 | `CardManager.IsGameActive()`에 GameRetryUI/GameResultUI 체크 추가 | A, B, C, E |
| 2 | 부활 성공 경로(`result.Retry`)에 `ForceCloseCardSelectionUI()` 추가 | D |
| 3 | `ForceStopCardSelectionQueue()` 신설 및 게임오버 진입 시 호출 | A~E 전체 보강 |
