# WriggleDefender UI 최적화 분석
> 분석 일자: 2026-05-02
> 분석 대상: `Assets/_Project/1_Scripts/UI/` 전체 + `UIManager.cs`
> 방향: 기존 코드 구조 유지, 최소 변경으로 최대 효과

---

## 🔴 P1 — 즉시 적용 권장

### 1. `GameUI.UpdateArkRemainingEnemyCount()` — 매 프레임 GetManager + string 포맷

**파일:** `Assets/_Project/1_Scripts/UI/GameUI.cs` (라인 449~462)

`Update()` → `UpdateArkRemainingEnemyCount()` 직접 호출 체인. 방주 모드가 활성화된 동안 **매 프레임** `GetManager<EnemyManager>()` Dictionary 조회 + `LocalizationManager.GetLocalizedTextFormat(...)` string 포맷팅이 반복됨. 적 수가 바뀌지 않아도 매번 텍스트를 갱신.

```csharp
// 현재: 매 프레임 GetManager + string 포맷 + TMP 갱신
private void UpdateArkRemainingEnemyCount()
{
    if (!_isArkMode || _arkRemainingEnemyPanel == null || _arkRemainingEnemyText == null) return;

    var enemyManager = Managers.Instance?.GetManager<EnemyManager>(); // 매 프레임 Dictionary 조회
    if (enemyManager != null)
    {
        int aliveEnemyCount = enemyManager.AliveEnemyCount;
        _arkRemainingEnemyText.text = LocalizationManager.GetLocalizedTextFormat(...); // 매 프레임 string 할당
    }
}

// 개선: EnemyManager 캐싱 + 이전 값과 다를 때만 갱신
private EnemyManager _enemyManager;
private int _lastDisplayedEnemyCount = -1;

// Initialize() 시:
_enemyManager = Managers.Instance.GetManager<EnemyManager>();

private void UpdateArkRemainingEnemyCount()
{
    if (!_isArkMode || _arkRemainingEnemyPanel == null || _arkRemainingEnemyText == null) return;
    if (_enemyManager == null) return;

    int aliveEnemyCount = _enemyManager.AliveEnemyCount;
    if (aliveEnemyCount == _lastDisplayedEnemyCount) return; // 변화 없으면 스킵
    _lastDisplayedEnemyCount = aliveEnemyCount;

    _arkRemainingEnemyText.text = LocalizationManager.GetLocalizedTextFormat("ARK_REMANING_ENEMY_COUNT", aliveEnemyCount);
}
```

---

### 2. `GameUI.UpdateGameTime()` — 매 프레임 string 생성

**파일:** `Assets/_Project/1_Scripts/UI/GameUI.cs` (라인 941~974)

시간은 초 단위로만 변하는데 매 프레임(60fps 기준 초당 60번) 동일한 문자열을 반복 할당·갱신.

```csharp
// 현재: 매 프레임 string interpolation → 새 string 할당
_gameTimeText.text = $"{minutes:00}:{seconds:00}";  // 일반 모드 (라인 964)
_gameTimeText.text = $"{minutes:00}:{seconds:00}";  // 카운트다운 모드 (라인 972)

// 개선: 초(int)가 바뀔 때만 텍스트 갱신 (5줄 추가)
private int _lastDisplayedSeconds = -1;

private void UpdateGameTime()
{
    if (!_isGameTimeActive || _gameTimeText == null) return;
    _gameElapsedTime += Time.deltaTime;

    int totalSeconds = Mathf.FloorToInt(_isCountdownMode ? _countdownTime : _gameElapsedTime);
    if (totalSeconds == _lastDisplayedSeconds) return;  // 초 변화 없으면 스킵
    _lastDisplayedSeconds = totalSeconds;

    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    _gameTimeText.text = $"{minutes:00}:{seconds:00}";
}
```

**초당 1회로 TMP 갱신 횟수 98% 감소.**

---

### 3. `GameUI` 이벤트 핸들러 — string interpolation (피격·회복마다)

**파일:** `Assets/_Project/1_Scripts/UI/GameUI.cs` (라인 1272, 1307, 1237)

전투 중 BaseDamaged / BaseHealed 이벤트마다 발생:

```csharp
// 라인 1272, 1307 — 기지 체력 갱신 (피격·회복마다)
_baseHealthText.text = $"{eventData.CurrentHealth:F0}/{eventData.MaxHealth:F0}";
// 위 한 줄에서 string 2개 생성 (각 포맷 결과 + 이어붙인 최종 string)

// 라인 1237 — 보스 페이즈 변경마다
_bossHealthPhaseText.text = $"x{eventData.HealthPhase}";
```

매 프레임은 아니지만 전투 강도에 따라 초당 수십 회 발생.

```csharp
// 개선: ZString 사용 (프로젝트에 이미 포함됨)
using (var sb = ZString.CreateStringBuilder())
{
    sb.Append((int)eventData.CurrentHealth);
    sb.Append('/');
    sb.Append((int)eventData.MaxHealth);
    _baseHealthText.SetTextFormat(sb);
}

// 또는 TMP 내장 포맷 (단순한 경우)
_bossHealthPhaseText.SetText("x{0}", eventData.HealthPhase);
```

> 프로젝트에 ZString이 이미 포함되어 있음 (`Assets/Scripts/ZString/`). 적극 활용 가능.

---

### 4. `GameUI.UpdateSteampackPosition()` — 매 프레임 WorldToScreenPoint

**파일:** `Assets/_Project/1_Scripts/UI/GameUI.cs` (라인 762~784)

매 프레임 `WorldToScreenPoint` + `ClampToScreen`(`_steampackPanelRect.rect.width/height` 레이아웃 쿼리)을 반복 호출.

```csharp
// 현재: 매 프레임 WorldToScreenPoint + rect 쿼리
Vector3 screenPos = _mainCamera.WorldToScreenPoint(marineWorldPos);
screenPos = ClampToScreen(screenPos); // rect.width/height 접근

// 개선: 30fps 주기 제한 (4줄 추가)
private float _steampackUpdateTimer;
private const float STEAMPACK_UPDATE_INTERVAL = 0.033f; // ~30fps

private void UpdateSteampackPosition()
{
    _steampackUpdateTimer += Time.deltaTime;
    if (_steampackUpdateTimer < STEAMPACK_UPDATE_INTERVAL) return;
    _steampackUpdateTimer = 0f;

    if (_trackedMarine == null || _steampackPanelRect == null || _mainCamera == null) return;
    if (!_steampackPanel.activeInHierarchy) return;

    // 기존 로직 그대로
}
```

`rect.width/height`는 Awake에서 캐싱 가능:
```csharp
private float _cachedHalfWidth;
private float _cachedHalfHeight;
// Awake: _cachedHalfWidth = _steampackPanelRect.rect.width * 0.5f;
```

---

### 5. `UIManager` — `ContainsKey` + 인덱서 이중 조회 (9곳)

**파일:** `Assets/_Project/1_Scripts/Core/Managers/UIManager.cs` (라인 131, 220, 278, 347, 413, 482, 508, 606, 1052)

```csharp
// 현재: 두 번 조회 (라인 131~133 예시)
if (openUI.ContainsKey(type))
{
    var existingUI = openUI[type]?.GetComponent<T>(); // 두 번째 Dictionary 조회
}
if (closeUI.ContainsKey(type))
{
    var closedObject = closeUI[type]; // 두 번째 Dictionary 조회
}

// 개선: TryGetValue 단일 조회
if (openUI.TryGetValue(type, out var existing))
{
    var existingUI = existing?.GetComponent<T>();
    ...
}
if (closeUI.TryGetValue(type, out var closedObject))
{
    ...
}
```

UIManager는 모든 UI의 진입점이므로 누적 효과 있음. 변경량 적고 리스크 낮음.

---

### 6. `RedDotComponent.ShowRedDotWithAnimation()` — Kill() 누락

**파일:** `Assets/_Project/1_Scripts/UI/RedDot/RedDotComponent.cs` (라인 568~582)

`HideRedDotWithAnimation()`은 `_currentAnimation?.Kill()`이 있는데, `ShowRedDotWithAnimation()`에는 없어서 이전 시퀀스가 살아있는 상태에서 새 시퀀스가 중복 생성됨. RedDotComponent는 씬 전체에 수십 개 붙어있어 트윈 누적 시 부담됨.

```csharp
// 현재: Kill() 없이 새 Sequence 생성
private void ShowRedDotWithAnimation()
{
    var sequence = DOTween.Sequence(); // 이전 _currentAnimation 살아있어도 신규 생성
    ...
    _currentAnimation = sequence;
}

// 개선: 1줄 추가
private void ShowRedDotWithAnimation()
{
    _currentAnimation?.Kill(); // ← 추가
    var sequence = DOTween.Sequence();
    ...
}
```

---

## 🟠 P2 — 순차 적용 권장

### 7. `isDestroyOnHide = true` 빈번 UI — false 전환 검토

**현황:** UIBase 기본값 `isDestroyOnHide = true`. 게임 중 반복 호출되는 UI가 매번 Instantiate→Destroy를 반복.

**인게임 빈도 높음 (우선 적용):**

| 파일 | 빈도 | 변경 시 효과 |
|------|------|------------|
| `BossNotificationUI.cs` (라인 17) | 보스마다 | Instantiate/Destroy 제거 |
| `EliteStartNotificationUI.cs` (라인 17) | 정예마다 | 동일 |
| `HordeBuffPopupUI.cs` (라인 19) | 버프 팝업마다 | 동일 |
| `PauseUI.cs` (라인 111) | 일시정지마다 | 동일 |
| `Toast/ToastUI.cs` (라인 75) | 알림마다 | 동일 |

**카드 관련 (카드 선택마다, Show 호출 40회+ 확인됨):**

| 파일 | 비고 |
|------|------|
| `NormalCardDetailPanel.cs` (라인 56) | 카드 상세 조회마다 |
| `CombineCardDetailPanel.cs` (라인 60) | 조합 카드 상세마다 |
| `SingleChainCardDetailPanel.cs` (라인 56) | 연쇄 카드 상세마다 |
| `DoubleChainCardDetailPanel.cs` (라인 64) | 동일 |
| `LinearThreeChainCardDetailPanel.cs` (라인 63) | 동일 |

```csharp
// 변경: 1줄
uiOptions.isDestroyOnHide = false; // false → UIManager.closeUI에 자동 캐시

// ⚠️ 주의: Opened()/Closed()에서 상태 완전 초기화되는지 확인 필요
// UIManager는 closeUI에서 꺼낼 때 SetActive(true) 후 Opened() 재호출함 — 검증 후 적용
```

---

### 8. `ArkLobbyPanel.cs` — DOTween 96개 vs Kill() 8개 정밀 점검

**파일:** `Assets/_Project/1_Scripts/UI/Ark/Component/ArkLobbyPanel.cs`

`_openSequence`, `_scrollUpSequence`는 생성 전 Kill() 패턴이 있어 안전하지만, 나머지 DOTween 88개(= 96 - 8 Kill 대응분)에 대해 반복 호출 가능한 메서드 안에서의 누적 여부 확인 필요.

```csharp
// 점검 패턴: 반복 호출되는 메서드에서 Kill() 없이 새 Sequence 생성 여부
public void PlaySomeAnimation()
{
    // _someSequence?.Kill(); ← 이게 없으면 위험
    _someSequence = DOTween.Sequence()
        .Append(...)
        .Append(...);
}
```

---

### 9. `DamageText.cs` — DOTween Sequence + string interpolation

**파일:** `Assets/_Project/1_Scripts/UI/DamageText.cs` (라인 340~378)

*(인게임 최적화 문서에서 분석됨 — UI 관점에서 재기술)*

`Show()` 호출마다 `DOTween.Sequence()` 1개 + `Tweener` 4~5개 할당. `FormatDamageText()`에서 `$"{damage / 1000f:F1}K"` string interpolation으로 string 할당. 전투 중 초당 수십~수백 회 생성.

```csharp
// 현재: Show() 호출마다 Sequence + Tweener 4~5개 + string 할당
_animationSequence = DOTween.Sequence()
    .Append(_rectTransform.DOScale(...))
    .Join(_textComponent.DOFade(...))
    .Append(_rectTransform.DOScale(...))
    .Insert(..., _rectTransform.DOAnchorPos(...))
    .Insert(..., _textComponent.DOFade(...));

baseText = $"{damage / 1000f:F1}K"; // 매 피격마다 string 할당

// 개선 방향: Update() 수동 보간으로 교체 (BunkerDefense 동일 방식)
// EaseOutBack / EaseOutQuart / EaseInQuad 이징 함수 직접 구현
// 3단계: 팝 등장(0~0.1s) → 이동+스케일 정규화(0.1~0.5s) → 페이드아웃(0.4~0.8s)
// string: _textComponent.SetText("{0:F1}K", damage / 1000f)
```

> ⚠️ `SetText(format, float)` 전환 시 `float.IsNaN` / `float.IsInfinity` / `damage > 9e15f` 클램프 방어 코드 필수.
> TMP 내부 `float→Decimal→Int64` 변환 경로에서 OverflowException 발생 사례 있음 (BunkerDefense 선례).

---

## 🟡 P3 — 점진적 개선

### 10. `SetActive` 연속 호출 시 레이아웃 리빌드 최적화

**영향 파일:** `GameUI.cs` (SetActive 24곳), `EquipmentRefinementUIComponent.cs` (71곳), `HordeLegacyRankingPopup.cs` (26곳) 등

`SetActive(true/false)`를 LayoutGroup 자식에서 연속 호출하면 부모 LayoutGroup 전체가 매번 리빌드됨.

```csharp
// 현재: 자식 여러 개 연속 SetActive → 매번 리빌드
_hordeBuffPanel.SetActive(show);
_bossHealthPanel.SetActive(show);
_eliteHealthPanel.SetActive(show);

// 개선: LayoutGroup이 있는 경우만 적용
var layout = _panelParent.GetComponent<LayoutGroup>();
if (layout != null) layout.enabled = false;

_hordeBuffPanel.SetActive(show);
_bossHealthPanel.SetActive(show);
_eliteHealthPanel.SetActive(show);

if (layout != null)
{
    layout.enabled = true;
    LayoutRebuilder.ForceRebuildLayoutImmediate(_panelParent); // 1회만
}
```

LayoutGroup 없는 패널에는 불필요. **해당 여부 확인 후 선택 적용.**

---

### 11. `GetComponent` 반복 호출 패턴 점검

**파일:** `PlayerInfoHUD.cs` 등

`SetupSettingsButtonRedDot()` / `SetupProfileButtonRedDot()`은 Awake에서 1회만 호출되어 현재는 문제 없음. 단, 이벤트 수신 시마다 `GetComponentInChildren`을 호출하는 패턴이 다른 파일에 있다면 lazy 캐시 또는 Awake 1회 캐싱으로 교체.

```csharp
// 위험 패턴: 이벤트 핸들러에서 매번 GetComponent
private void OnSomeEvent()
{
    var comp = _button.GetComponentInChildren<RedDotComponent>(); // 매 이벤트마다
}

// 안전 패턴: Awake 1회 캐싱
private RedDotComponent _redDotComponent;
private void Awake() => _redDotComponent = _button.GetComponentInChildren<RedDotComponent>();
```

---

## 수정된 DOTween 위험도 평가

기존 분석에서 위험도 표시가 잘못된 파일:

| 파일 | 기존 평가 | 수정 평가 | 사유 |
|------|----------|----------|------|
| `BottomTabHUD.cs` | 🟡 확인 필요 | 🟢 양호 | `Dictionary<EBottomTabType, Sequence>`로 탭별 관리, 생성 전 Kill() 선행 확인 |
| `GameResultUI.cs` | 🟡 확인 필요 | 🟢 양호 | `_showSequence?.Kill()` + `DOTween.KillAll` + `DOTween.Kill(this)` 패턴 존재 |
| `ArkLobbyPanel.cs` | 🔴 확인 필요 | 🔴 **정밀 점검 필요** | Kill 8개 대비 DOTween 96개 — 핵심 시퀀스 2개 외 나머지 미검증 |

---

## 요약 — 적용 우선순위

| # | 항목 | 파일 | 변경 크기 | 효과 |
|:---:|------|------|:---:|---|
| 1 | `UpdateArkRemainingEnemyCount()` GetManager 캐싱 + 변화 감지 | GameUI.cs | 6줄 | 방주 모드 매 프레임 GetManager + string 할당 제거 |
| 2 | `UpdateGameTime()` 초 단위 갱신 | GameUI.cs | 5줄 | 매 프레임 string 할당 제거 (98% 감소) |
| 3 | `UpdateSteampackPosition()` 30fps 주기 + rect 캐싱 | GameUI.cs | 6줄 | 프레임당 WorldToScreenPoint 절반 감소 |
| 4 | 이벤트 핸들러 string interpolation → ZString | GameUI.cs | 5곳 | 피격·회복마다 string 할당 제거 |
| 5 | `UIManager` TryGetValue 전환 | UIManager.cs | 9곳 1줄씩 | Dictionary 조회 횟수 절반 |
| 6 | `RedDotComponent` Kill() 추가 | RedDotComponent.cs | 1줄 | 트윈 누적 방지 |
| 7 | 빈번 UI `isDestroyOnHide = false` | Boss/Elite/Pause/Toast/Card 패널 등 | 1줄씩 | Instantiate/Destroy 사이클 제거 |
| 8 | `ArkLobbyPanel` DOTween 정밀 점검 | ArkLobbyPanel.cs | 파일별 | 트윈 누적 방지 |
| 9 | `DamageText` DOTween → Update 보간 | DamageText.cs | 중간 | Show()마다 GC 대폭 감소 |
| 10 | SetActive 레이아웃 리빌드 제어 | 다수 | 선택 적용 | UI 반응성 향상 |

> **구조 변경 없이 즉시 가능:** 1, 2, 3, 5, 6
> **1줄 변경 + 검증 필요:** 4, 7
> **중간 규모 수정:** 9 (DamageText 애니메이션 방식 교체)
> **점검 후 결정:** 8, 10
