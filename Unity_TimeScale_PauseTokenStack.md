# Unity Time.timeScale 관리 패턴: Pause Token Stack

## 배경

WiggleDefender 프로젝트에서 발생한 두 가지 버그를 수정하면서 `Time.timeScale` 관리 방식에 대한 설계 논의가 있었다.

- **버그 1**: 게임오버 이후 부활 UI가 떠 있는 상태에서 마지막 적이 죽으면 스테이지 클리어 판정이 나는 버그
- **버그 2**: Ark 스테이지 시작/클리어 시 카드 선택 UI가 열려도 게임이 멈추지 않는 버그

이 버그들을 수정하는 과정에서 `Time.timeScale = 0f`를 여러 곳에서 개별적으로 설정하면서 다음 문제들이 생겼다.

- `GameUI.HandleStageStarted`가 `CardManager`의 pause를 덮어씌움
- `ArkGameResultUI.Closed()`가 timeScale을 복원하면서 뒤이어 열리는 `ArkGachaResultPopup`이 멈추지 않음
- `DOTween.Sequence()`에 `SetUpdate(true)` 누락으로 `Time.timeScale = 0f` 상태에서 애니메이션이 프리징

---

## 현재 방식: Targeted Fix (타겟 수정)

### 적용된 수정들

```
CheckStageClearCondition()
  └─ UIManager.IsOpened<GameRetryUI>() 체크 추가 → 부활 UI 중 클리어 차단

CardManager.OnStageStarted()
  └─ Ark 스테이지 시작 카드 큐 등록 시 즉시 Time.timeScale = 0f

GameUI.HandleStageStarted()
  └─ HasPendingCardSelectionQueue 체크 → 카드 대기 중이면 timeScale 설정 생략

ArkGameResultUI.HandleGachaFlow()
  └─ Closed() 후 Time.timeScale = 0f 재설정 → 가챠 팝업 시퀀스 동안 유지

ArkGachaSlotUI.PlayAppear()
  └─ seq.SetUpdate(ignoreTimeScale) 추가 → timeScale = 0f에서도 애니메이션 정상 동작
```

### 장점

- 변경 범위가 최소화됨
- 기존에 잘 동작하는 코드를 건드리지 않음
- 각 버그가 독립적으로 수정되어 롤백이 쉬움

### 단점

- `HasPendingCardSelectionQueue` 같은 크로스-매니저 의존성이 생김
- pause/resume 로직이 여러 파일에 분산됨
- 새로운 popup/system을 추가할 때 매번 동일한 패턴을 수동으로 적용해야 함
- 복수의 pause 요청이 겹칠 때 순서를 보장하기 어려움

---

## 대안 방식: Pause Token Stack 패턴

### 개념

`Time.timeScale`을 직접 설정하는 대신, 각 시스템이 **pause 토큰**을 스택에 push/pop한다.
스택이 비어 있을 때만 게임이 진행된다.

```
PauseStack: [CardSelection, GameRetry]
  → 스택이 비어있지 않으므로 Time.timeScale = 0f

PauseStack: []
  → 스택이 비어있으므로 Time.timeScale = userSelectedSpeed
```

이 패턴은 Unity 커뮤니티에서 **PauseManager**, **TimeScaleStack**, **PauseSystem** 등의 이름으로 알려져 있다.

### 구현 계획

#### 1. PauseManager 클래스

```csharp
public class PauseManager : MonoBehaviour
{
    private readonly HashSet<string> _pauseTokens = new();
    private float _cachedGameSpeed = 1f;

    public void SetGameSpeed(float speed)
    {
        _cachedGameSpeed = speed;
        Refresh();
    }

    public void AddPause(string token)
    {
        _pauseTokens.Add(token);
        Refresh();
    }

    public void RemovePause(string token)
    {
        _pauseTokens.Remove(token);
        Refresh();
    }

    public bool IsPaused => _pauseTokens.Count > 0;

    private void Refresh()
    {
        Time.timeScale = _pauseTokens.Count > 0 ? 0f : _cachedGameSpeed;
    }
}
```

> 토큰으로 `string` 대신 `enum`을 쓰면 오타 위험이 없고, HashSet이 중복 등록을 자동 처리한다.

#### 2. 토큰 정의

```csharp
public static class PauseTokens
{
    public const string CardSelection = "CardSelection";
    public const string GameRetry     = "GameRetry";
    public const string GameResult    = "GameResult";
    public const string GachaResult   = "GachaResult";
    public const string StageStart    = "StageStart";
}
```

#### 3. 사용 예시

```csharp
// CardSelectionUI.cs
public override void Opened(object[] param)
{
    base.Opened(param);
    Managers.Instance.GetManager<PauseManager>().AddPause(PauseTokens.CardSelection);
}

public override void Closed(object[] param)
{
    Managers.Instance.GetManager<PauseManager>().RemovePause(PauseTokens.CardSelection);
    base.Closed(param);
}

// GameRetryUI.cs
public override void Opened(object[] param)
{
    base.Opened(param);
    Managers.Instance.GetManager<PauseManager>().AddPause(PauseTokens.GameRetry);
}

public override void Closed(object[] param)
{
    Managers.Instance.GetManager<PauseManager>().RemovePause(PauseTokens.GameRetry);
    base.Closed(param);
}
```

#### 4. 기존 코드 마이그레이션 체크리스트

| 파일 | 현재 코드 | 변경 후 |
|---|---|---|
| `CardSelectionUI.cs` | `Time.timeScale = 0f` | `AddPause(CardSelection)` |
| `GameRetryUI.cs` | `Time.timeScale = 0f` | `AddPause(GameRetry)` |
| `ArkGameRetryUI.cs` | `Time.timeScale = 0f` | `AddPause(GameRetry)` |
| `ArkGameResultUI.cs` | `Time.timeScale = 0f` | `AddPause(GameResult)` |
| `ArkGachaResultPopup.cs` | (없음) | `AddPause(GachaResult)` |
| `GameUI.cs` | `Time.timeScale = userSpeed` | `SetGameSpeed(userSpeed)` |
| `CardManager.cs` | `Time.timeScale = 0f` | `AddPause(CardSelection)` |

#### 5. UIBase에 패턴 통합 (선택적 강화)

```csharp
// UIBase.cs에 훅 추가
public abstract class UIBase : MonoBehaviour
{
    protected virtual string PauseToken => null; // 오버라이드 시 자동 pause

    public virtual void Opened(object[] param)
    {
        if (PauseToken != null)
            Managers.Instance.GetManager<PauseManager>().AddPause(PauseToken);
    }

    public virtual void Closed(object[] param)
    {
        if (PauseToken != null)
            Managers.Instance.GetManager<PauseManager>().RemovePause(PauseToken);
    }
}

// CardSelectionUI.cs - 한 줄만 추가하면 끝
public class CardSelectionUI : UIBase
{
    protected override string PauseToken => PauseTokens.CardSelection;
}
```

### 주의사항 (도입 시 반드시 체크)

1. **Token leak 방지**: `Closed()`에서 토큰을 반환하지 않으면 게임이 영구 정지된다. `OnDestroy()`에서도 `RemovePause`를 호출하는 방어 코드 필요.

    ```csharp
    private void OnDestroy()
    {
        Managers.Instance?.GetManager<PauseManager>()?.RemovePause(PauseToken);
    }
    ```

2. **씬 전환 시 스택 초기화**: 씬이 바뀌면 PauseManager의 스택을 반드시 비워야 한다. 로비 씬에서는 스택이 항상 비어 있어야 한다.

3. **`Time.timeScale` 직접 할당 전면 금지**: 마이그레이션 이후 `Time.timeScale =` 직접 할당을 코드 리뷰에서 차단해야 한다. (CLAUDE.md Forbidden Items에 추가 권장)

4. **DOTween `SetUpdate(true)` 여전히 필요**: PauseManager가 있어도 popup 내부 DOTween 애니메이션은 `Time.timeScale = 0f`에서 멈춘다. popup이 열린 상태에서 보여야 하는 모든 DOTween은 `SetUpdate(true)` 처리가 필요하다.

---

## 결론: 언제 어떤 방식을 쓸까

| 상황 | 추천 방식 |
|---|---|
| 기존 프로젝트, 버그 수정 | Targeted Fix |
| 새 프로젝트 설계 단계 | Pause Token Stack |
| 기존 프로젝트 대규모 리팩토링 중 | Pause Token Stack (마이그레이션 포함) |
| popup이 2~3개 이하이고 겹치지 않음 | Targeted Fix로 충분 |
| popup이 많고 pause 중첩이 자주 발생 | Pause Token Stack |

> Pause Token Stack은 아키텍처적으로 더 좋지만, 기존 코드에 도입하려면 `Time.timeScale =` 할당을 전부 찾아서 교체해야 한다. 하나라도 누락되면 기존 기능이 깨지고, token leak은 재현하기 매우 어려운 버그를 만든다. 새 프로젝트라면 처음부터 이 패턴으로 설계하는 것이 이상적이다.
