# Vanguard 정보 팝업(VanguardInfoPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

`VanguardLobbyPanel`의 이벤트 정보 버튼(현재 `Show<RulePanelPopup>` 임시 연결)을 눌렀을 때 뜨는 **탭형 정보 팝업** — **[이번 시즌 적]**/ **[모드 규칙]**(텍스트 규칙) — 의 프리팹 + 스크립트를 이 문서만 보고 한 번에 제작할 수 있도록 정리한다.

- 사용자 방침(확정): **`StageInfoPopupUI` 프리팹/구조 재활용** — Panel-Content(스테이지 정보 패널) 자리에 "이번 시즌 적", **ClearListPanel 변형** 자리에 "모드 규칙"(`RulePanelPopup` 텍스트 구성 재활용).
- 짝 문서: [[2026-06-03_vanguard-intro-panel-ui]](인트로 ⓘ 연동), [[2026-05-29_vanguard-implementation-plan-outgame]]
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 신규 클래스 | `VanguardInfoPopup : UIBase` 1개 (StageInfoPopupUI의 탭/캐러셀 로직 축소 복제) |
| 프리팹 | `StageInfoPopupUI.prefab` **복제 후 개조** → `VanguardInfoPopup.prefab` (`Resources_moved/UI/`) |
| 탭1 "이번 시즌 적" | **`StageInfoPopupUI.Partial.cs`의 Snake 표시 경로 복제**(WD는 Snake 타입 적만 사용) — 단일/다중 레이아웃 + ◀▶ + 페이지 도트(`EnemyDisplayComponent`) + **일반 적 가로 스트립**(`_enemyDisplayPrefab` 인스턴스) |
| 탭2 "모드 규칙" | ClearListPanel 자리 → **규칙 텍스트 패널**(RulePanelPopup의 제목+본문 ×2 구성: 기본 규칙/모드 규칙) |
| 데이터 | 시즌 적(정예 2 + 일반 6) = `VanguardSeasonService`(미구현 → Stub), 규칙 = Localization 키 |
| 진입 | `VanguardLobbyPanel.OnClickEventInfo()` → `Show<VanguardInfoPopup>()` (+ 인트로 ⓘ 2곳) |
| 닫기 | X 버튼 + **빈 곳(배경) 클릭 닫기** (StageInfoPopupUI `_backgroundButton` 패턴) |

---

## 1. 진입 지점 (확인된 코드)

`VanguardLobbyPanel.cs`(확인):

```csharp
private void OnClickEventInfo()
{
    // TODO: Vanguard 규칙 Localization 키 전달.
    _uiManager?.Show<RulePanelPopup>();   // ← Show<VanguardInfoPopup>() 로 교체
}
```

추가 진입(연계, [[2026-06-03_vanguard-intro-panel-ui]]의 TODO 해소):

| 호출처 | 호출 | 초기 탭 |
|---|---|---|
| `VanguardLobbyPanel` ⓘ(이벤트 정보) | `Show<VanguardInfoPopup>()` | 기본=이번 시즌 적 |
| `VanguardIntroPanel` 타이틀 ⓘ | `Show<VanguardInfoPopup>(VanguardInfoTab.Rules)` | 모드 규칙 |
| `VanguardIntroPanel` 적 ⓘ | `Show<VanguardInfoPopup>(VanguardInfoTab.Enemies)` | 이번 시즌 적 |

> `Opened(param)`의 `param[0] is VanguardInfoTab`으로 초기 탭 지정(미전달 시 Enemies).

---

## 2. 이미지 상세 분석

### 2-1. 공통 프레임 (두 탭 공유)

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 타이틀 바 | `스파크 프로젝트: 뱅가드` + `X` | `_titleText` + `_closeButton` |
| 탭 2개 | `이번 시즌 적` / `모드 규칙` (사선 인디케이터, 활성=밝은 청록) | StageInfoPopupUI 탭 시스템( `_tabIndicatorImage` X스케일 ±1 플립 + 텍스트 색) 그대로 |
| 배경 닫기 | `-빈 곳을 눌러 닫기-` 안내 + 배경 클릭 | `_backgroundButton` + 안내 텍스트 |
| 등장 연출 | 팝업 스케일 + 배경 페이드 | `PlayShowAnimation()`(DOTween) 그대로 |

### 2-2. 탭1 — 이번 시즌 적 (이미지 1)

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 섹션 라벨 | `이번 시즌 적` (코너 액센트) | 정적 라벨 |
| 정예 캐러셀 | `◀` 큰 적 이미지 `▶`, 이름 **주황** `정예 외계 거상`, 페이지 도트 2개 | **Snake 표시 경로**(`StageInfoPopupUI.Partial.cs`): `DisplaySnakeEnemies`의 단일/다중 레이아웃(`_singleEnemyLayout`/`_multiEnemyLayout`) + `ShowPrev/NextSnake` + `EnemyDisplayComponent`(`Initialize(count)`/`SetToggleState(idx)` = 도트) |
| 일반 적 스트립 | 가로 스크롤: `…석`, `우주 큐브`, `암석 여행자`, `외성…` + 구분선 | `_normalEnemiesContainer` + `_enemyDisplayPrefab` 인스턴스(`SetPartitionLineActive`) — **6종, 가로 ScrollRect** |

- 정예 이름 주황색 = 정예 표식(`정예` 접두 + 색). 페이지 도트 2 = **정예 2종**(위키 일치).
- **WD Vanguard 적 = 전부 Snake 타입**(사용자 확정) → 캐러셀/스트립 모두 Snake 적 ID를 `EnemyDisplayComponent.SetupAsync`로 표시(파셜의 `SetupEnemyDisplay`와 동일 경로). 캐러셀이 1종이면 `_singleEnemyLayout`, 2종 이상이면 `_multiEnemyLayout`(파셜 분기 그대로).
- 적 클릭 시 툴팁(`EnemyTooltip`)은 StageInfoPopupUI 기능 그대로 유지 가능(선택).

### 2-3. 탭2 — 모드 규칙 (이미지 2)

| 섹션 | 내용(스샷, 위키와 일치) |
|---|---|
| **기본 규칙** | 1. 이벤트 기간 총 9개 포대 지정, 칩 뽑기엔 해당 포대 전용 칩+공용 칩만 등장. 2. 이벤트마다 일반 적 6종 + 정예 적 2종, 전투 시 무작위 출현 |
| **모드 규칙** | 1. 매주 화 UTC 0시 ~ 수 UTC 24시 오픈. 2. 입장 시 외부 성장 수치/자원 휴대 불가(다이아몬드 제외). 3. 처음 10회 전투 일반 엠버 열쇠 +1, 5회 이후 데이터 조각으로 상자 개봉 가능 |

→ `RulePanelPopup`의 4텍스트 구성(`_dungeonTitleText/_dungeonDescriptionText/_ruleTitleText/_ruleDescriptionText`)과 동형: **섹션 제목 + 본문 ×2** (+ 스크롤). 텍스트는 전부 Localization 키.

> 규칙 원문 출처: [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) "Event Info & Rules" — 스샷의 KR 텍스트와 1:1 대응(Basic Rules 2항 + Gameplay Rules 중 3항 발췌 구성).

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API/필드 |
|---|---|---|---|
| **StageInfoPopupUI** | `_Project/1_Scripts/UI/StageInfoPopupUI.cs` + 프리팹 | **프리팹 복제 + 공통 로직 복제** | 탭: `SwitchTab`/`UpdateTabDisplay`/`_tabIndicatorImage`(X스케일 플립) · 일반적: `_normalEnemiesContainer`+`_enemyDisplayPrefab`+`DisplayNormalEnemies` · 닫기: `_backgroundButton`/`_closeButton` · 연출: `PlayShowAnimation` |
| **StageInfoPopupUI.Partial** ★ | **`_InGame/Scripts/UI/StageInfoPopupUI.Partial.cs`** (WD측 파셜) | **적 이미지 표시의 1차 참조** — WD는 Snake 타입 적만 사용, ◀▶도 Snake 경로에 바인딩됨 | `ProcessSnakeData()`(웨이브→enemyID 수집·중복제거·최대3) · `DisplaySnakeEnemies()`(**1종=`_singleEnemyLayout`+`_singleEnemyDisplay` / 2종+=`_multiEnemyLayout`** 분기) · `UpdateMultiSnakeDisplay()`(`SetupEnemyDisplay`+`SetToggleState`) · `ShowNext/PreviousSnake()`(순환) · `SetupButtons()`(◀▶→Snake 핸들러) |
| **EnemyDisplayComponent** | `UI/Components/`(StageInfoPopupUI 사용) | **그대로** (캐러셀 본체/스트립 1칸) | `SetupAsync(EStageType, enemyID)` · `Initialize(int count)` · `SetToggleState(int idx)`(페이지 도트) · `SetPartitionLineActive(bool)` |
| **EnemyTooltip** | `UI/EnemyTooltip`(Resources) | 선택(적 클릭 상세) | `ShowTooltip(enemyID, pos, onClosed)` |
| **RulePanelPopup** | `UI/Popups/RulePanelPopup.cs` | **텍스트 구성만 차용** (제목+본문 ×2). 팝업 자체는 재사용 X | `_dungeonTitleText/_dungeonDescriptionText/_ruleTitleText/_ruleDescriptionText` 4텍스트 패턴 |
| 시즌 적 데이터 | `VanguardSeasonService`(미구현) | [[2026-06-03_vanguard-intro-panel-ui]] §8과 동일 provider | `GetSeasonEliteIds()`(2) / `GetSeasonRegularIds()`(6) — Stub 선개발 |

> ⚠️ **파셜 구조 주의**: `StageInfoPopupUI`는 `partial`이며 base의 `SetupButtons()`가 `#if !SS` 가드, 파셜(`_InGame`)의 `SetupButtons()`가 실사용본(◀▶=Snake 핸들러). **복제 시 base의 정예/보스 경로(`ShowPrevious(Next)EliteBossEnemy`/`DisplayEliteBossEnemies`)가 아니라 파셜의 Snake 경로를 따라야** 스샷과 동일하게 동작한다. `VanguardInfoPopup`은 WD 전용 신규 클래스이므로 파셜 분리 없이 단일 파일에 Snake 패턴만 담으면 됨.

### 재사용하지 않는 것 (StageInfoPopupUI에서 제거)

- ❌ 보상 스크롤뷰(`_rewardScrollContent`/`CalculateMaxRewards`) — Vanguard 정보 팝업에 보상 없음.
- ❌ 클리어 리스트 서버 조회(`LoadClearListAsync`/`ClearListItemComponent`) — 탭2는 정적 규칙 텍스트로 치환.
- ❌ 스테이지 약점/내성(`DisplayStageResistances`), 스테이지명/설명(StageDataSO 기반).
- ❌ `StageDataSO`/`StageManager` 의존 전체 — 시즌 적 ID 리스트만 받는다.

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> **제작법**: `StageInfoPopupUI.prefab` 복제 → `VanguardInfoPopup.prefab`(`Resources_moved/UI/`, `Show<T>` 로드 경로) → 아래대로 개조. 루트 스크립트를 `VanguardInfoPopup.cs`로 교체.

```
VanguardInfoPopup (루트, ▶ VanguardInfoPopup.cs, uiPosition=Popup)
├─ Background (Image + Button)                        → _backgroundButton (빈 곳 클릭 닫기)
│  └─ CloseHintText ("-빈 곳을 눌러 닫기-")            (정적 라벨)
├─ PopupContainer (스케일 연출 대상)                   → _popupContainer
│  ├─ TitleBar
│  │  ├─ TitleText ("스파크 프로젝트: 뱅가드")          → _titleText
│  │  └─ Btn_Close (X)                                 → _closeButton
│  ├─ TabBar
│  │  ├─ Btn_EnemiesTab ("이번 시즌 적")               → _enemiesTabButton (+Indicator)
│  │  ├─ Btn_RulesTab ("모드 규칙")                    → _rulesTabButton (+Indicator)
│  │  └─ TabIndicatorImage (사선, X스케일 ±1 플립)      → _tabIndicatorImage
│  │
│  ├─ EnemiesPanel (탭1 — 기존 StageInfoPanel 개조)     → _enemiesPanel
│  │  ├─ SectionLabel ("이번 시즌 적")
│  │  ├─ EliteCarousel (파셜 Snake 표시 3종 레이아웃 그대로 유지)
│  │  │  ├─ NoEnemyOverlay (0종 폴백)                   → _noEnemyOverlay
│  │  │  ├─ SingleEnemyLayout (1종일 때)                → _singleEnemyLayout
│  │  │  │  └─ EnemyDisplay [재사용]                    → _singleEnemyDisplay
│  │  │  └─ MultiEnemyLayout (2종+ — 스샷 상태)         → _multiEnemyLayout
│  │  │     ├─ Btn_Prev (◀)                            → _previousEnemyButton
│  │  │     ├─ EnemyDisplay [재사용 EnemyDisplayComponent] → _multiEnemyDisplay (이름 주황 + 페이지 도트)
│  │  │     └─ Btn_Next (▶)                            → _nextEnemyButton
│  │  └─ NormalEnemyStrip (가로 ScrollRect)
│  │     └─ Viewport/Content (HorizontalLayoutGroup)   → _normalEnemiesContainer
│  │        └─ (런타임) EnemyDisplay 프리팹 x6           → _enemyDisplayPrefab
│  │
│  └─ RulesPanel (탭2 — 기존 ClearListPanel 개조)       → _rulesPanel
│     └─ ScrollRect(세로) / Content (VerticalLayoutGroup)
│        ├─ Section1Title ("기본 규칙", 코너 액센트)     → _basicRuleTitleText
│        ├─ Section1Body (1~2항)                        → _basicRuleBodyText
│        ├─ Section2Title ("모드 규칙")                  → _modeRuleTitleText
│        └─ Section2Body (1~3항)                        → _modeRuleBodyText
```

- 탭 인디케이터/색상/사운드(`AudioUtils.PlaySFXUnscaled("BottomTab")`)/연출은 원본 프리팹 설정 유지.
- 일반 적 스트립: 원본 `_normalEnemiesContainer`에 **가로 ScrollRect**만 추가(6종 스크롤, 스샷처럼 일부 잘림 허용). 구분선은 `SetPartitionLineActive`.

---

## 5. 스크립트 설계

### 5-1. `VanguardInfoPopup.cs` (신규 — 참조 구현)

```csharp
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public enum VanguardInfoTab { Enemies = 0, Rules = 1 }

/// <summary>
/// Vanguard 정보 팝업: [이번 시즌 적](정예 캐러셀+일반 스트립) / [모드 규칙](텍스트).
/// StageInfoPopupUI의 탭/캐러셀/닫기 패턴 축소 복제. 데이터는 시즌 적 ID 리스트만 사용.
/// </summary>
public class VanguardInfoPopup : UIBase
{
    #region Serialized
    [Header("컨테이너/닫기")]
    [SerializeField] private GameObject _popupContainer;
    [SerializeField] private CanvasGroup _backgroundCanvasGroup;
    [SerializeField] private Button _backgroundButton;
    [SerializeField] private Button _closeButton;
    [SerializeField] private TextMeshProUGUI _titleText;

    [Header("탭")]
    [SerializeField] private Button _enemiesTabButton;
    [SerializeField] private Button _rulesTabButton;
    [SerializeField] private GameObject _enemiesTabIndicator;
    [SerializeField] private GameObject _rulesTabIndicator;
    [SerializeField] private Image _tabIndicatorImage;
    [SerializeField] private GameObject _enemiesPanel;
    [SerializeField] private GameObject _rulesPanel;
    [SerializeField] private Color _activeTabTextColor = Color.white;
    [SerializeField] private Color _inactiveTabTextColor = new(0.6f, 0.6f, 0.6f, 1f);

    [Header("탭1: 정예 캐러셀 (파셜 Snake 3종 레이아웃)")]
    [SerializeField] private GameObject _noEnemyOverlay;        // 0종 폴백
    [SerializeField] private GameObject _singleEnemyLayout;     // 1종
    [SerializeField] private EnemyDisplayComponent _singleEnemyDisplay;
    [SerializeField] private GameObject _multiEnemyLayout;      // 2종+ (스샷 상태)
    [SerializeField] private Button _previousEnemyButton;
    [SerializeField] private Button _nextEnemyButton;
    [SerializeField] private EnemyDisplayComponent _multiEnemyDisplay;

    [Header("탭1: 일반 적 스트립")]
    [SerializeField] private Transform _normalEnemiesContainer;
    [SerializeField] private GameObject _enemyDisplayPrefab;

    [Header("탭2: 규칙 텍스트 (RulePanelPopup 4텍스트 패턴)")]
    [SerializeField] private TextMeshProUGUI _basicRuleTitleText;
    [SerializeField] private TextMeshProUGUI _basicRuleBodyText;
    [SerializeField] private TextMeshProUGUI _modeRuleTitleText;
    [SerializeField] private TextMeshProUGUI _modeRuleBodyText;

    [Header("연출")]
    [SerializeField] private float _animationDuration = 0.3f;

    [Header("[TEST]")]
    [SerializeField] private bool _useTestData = true;
    #endregion

    private VanguardManager _vanguardManager;
    private readonly List<int> _eliteIds = new();   // 2종
    private readonly List<int> _regularIds = new(); // 6종
    private readonly List<EnemyDisplayComponent> _normalDisplays = new();
    private int _eliteIndex;
    private VanguardInfoTab _currentTab = VanguardInfoTab.Enemies;
    private Sequence _showSequence;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;

        _backgroundButton?.onClick.AddListener(ClosePopup);
        _closeButton?.onClick.AddListener(ClosePopup);
        _previousEnemyButton?.onClick.AddListener(ShowPreviousElite);
        _nextEnemyButton?.onClick.AddListener(ShowNextElite);
        _enemiesTabButton?.onClick.AddListener(() => SwitchTab(VanguardInfoTab.Enemies));
        _rulesTabButton?.onClick.AddListener(() => SwitchTab(VanguardInfoTab.Rules));

        if (_popupContainer != null) _popupContainer.transform.localScale = Vector3.zero;
        if (_backgroundCanvasGroup != null) _backgroundCanvasGroup.alpha = 0f;
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();

        if (_titleText != null) _titleText.text = LocalizationManager.GetLocalizedText("vanguard_title");
        SetupRuleTexts();
        LoadSeasonEnemies();

        // 초기 탭 (param[0] = VanguardInfoTab, 기본 Enemies)
        var tab = (param != null && param.Length > 0 && param[0] is VanguardInfoTab t) ? t : VanguardInfoTab.Enemies;
        _currentTab = tab;
        UpdateTabDisplay();
        if (tab == VanguardInfoTab.Enemies) RefreshEnemiesTab();

        PlayShowAnimation();
    }

    public override void Closed(object[] param)
    {
        _showSequence?.Kill();
        CleanupNormalDisplays();
        base.Closed(param);
    }

    // ─────────── 데이터 ───────────
    private void LoadSeasonEnemies()
    {
        _eliteIds.Clear(); _regularIds.Clear();
        if (!_useTestData && _vanguardManager?.SeasonService != null)
        {
            // TODO: VanguardSeasonService.GetSeasonEliteIds()/GetSeasonRegularIds() (인트로 문서 §8과 공유)
            // _eliteIds.AddRange(...); _regularIds.AddRange(...);
        }
        else
        {
            _eliteIds.AddRange(GetTestEliteIds());      // 2종
            _regularIds.AddRange(GetTestRegularIds());  // 6종
        }
    }

    private void SetupRuleTexts()
    {
        if (_basicRuleTitleText != null) _basicRuleTitleText.text = LocalizationManager.GetLocalizedText("vanguard_rule_basic_title");
        if (_basicRuleBodyText  != null) _basicRuleBodyText.text  = LocalizationManager.GetLocalizedText("vanguard_rule_basic_body");
        if (_modeRuleTitleText  != null) _modeRuleTitleText.text  = LocalizationManager.GetLocalizedText("vanguard_rule_mode_title");
        if (_modeRuleBodyText   != null) _modeRuleBodyText.text   = LocalizationManager.GetLocalizedText("vanguard_rule_mode_body");
    }

    // ─────────── 탭 (StageInfoPopupUI.SwitchTab/UpdateTabDisplay 축소 복제) ───────────
    private void SwitchTab(VanguardInfoTab tab)
    {
        AudioUtils.PlaySFXUnscaled("BottomTab").Forget();
        if (_currentTab == tab) return;
        _currentTab = tab;
        UpdateTabDisplay();
        if (tab == VanguardInfoTab.Enemies) RefreshEnemiesTab();

        if (_tabIndicatorImage != null)
        {
            var s = _tabIndicatorImage.transform.localScale;
            s.x = (tab == VanguardInfoTab.Enemies) ? 1f : -1f;
            _tabIndicatorImage.transform.DOScale(s, 0.2f).SetEase(Ease.OutQuad).SetUpdate(true);
        }
    }

    private void UpdateTabDisplay()
    {
        _enemiesTabIndicator?.SetActive(_currentTab == VanguardInfoTab.Enemies);
        _rulesTabIndicator?.SetActive(_currentTab == VanguardInfoTab.Rules);
        _enemiesPanel?.SetActive(_currentTab == VanguardInfoTab.Enemies);
        _rulesPanel?.SetActive(_currentTab == VanguardInfoTab.Rules);

        var eLabel = _enemiesTabButton?.GetComponentInChildren<TextMeshProUGUI>(true);
        var rLabel = _rulesTabButton?.GetComponentInChildren<TextMeshProUGUI>(true);
        if (eLabel != null) eLabel.color = _currentTab == VanguardInfoTab.Enemies ? _activeTabTextColor : _inactiveTabTextColor;
        if (rLabel != null) rLabel.color = _currentTab == VanguardInfoTab.Rules ? _activeTabTextColor : _inactiveTabTextColor;
    }

    // ─────────── 탭1: 정예 캐러셀 (StageInfoPopupUI.Partial의 Snake 패턴 복제) ───────────
    // WD Vanguard 적 = 전부 Snake 타입. DisplaySnakeEnemies와 동일한 0/1/2+ 레이아웃 분기.
    private void RefreshEnemiesTab()
    {
        _eliteIndex = 0;
        DisplayEliteCarousel();   // = DisplaySnakeEnemies 미러
        DisplayNormalEnemies();
    }

    private void DisplayEliteCarousel()
    {
        if (_eliteIds.Count == 0)
        {
            _noEnemyOverlay?.SetActive(true);
            _singleEnemyLayout?.SetActive(false);
            _multiEnemyLayout?.SetActive(false);
        }
        else if (_eliteIds.Count == 1)
        {
            _noEnemyOverlay?.SetActive(false);
            _singleEnemyLayout?.SetActive(true);
            _multiEnemyLayout?.SetActive(false);
            if (_singleEnemyDisplay != null) SetupEnemy(_singleEnemyDisplay, _eliteIds[0]).Forget();
        }
        else // 2종+ (스샷: 정예 2종 + 도트 2개)
        {
            _noEnemyOverlay?.SetActive(false);
            _singleEnemyLayout?.SetActive(false);
            _multiEnemyLayout?.SetActive(true);
            _multiEnemyDisplay?.Initialize(_eliteIds.Count);  // 페이지 도트 수
            UpdateEliteDisplay();                              // = UpdateMultiSnakeDisplay 미러
        }
    }

    private void UpdateEliteDisplay()
    {
        if (_multiEnemyDisplay == null || _eliteIds.Count <= _eliteIndex) return;
        SetupEnemy(_multiEnemyDisplay, _eliteIds[_eliteIndex]).Forget();
        _multiEnemyDisplay.SetToggleState(_eliteIndex);        // 도트 갱신
        _previousEnemyButton?.gameObject.SetActive(true);      // 파셜과 동일: 항상 활성(순환)
        _nextEnemyButton?.gameObject.SetActive(true);
        // 정예 이름 주황 표기는 EnemyDisplayComponent 내 이름 색/접두("정예 ") 옵션으로 처리 [설계 판단]
    }

    private void ShowPreviousElite()  // = ShowPreviousSnake 미러
    {
        AudioUtils.PlaySFXUnscaled("BottomTab").Forget();
        if (_eliteIds.Count <= 1) return;
        _eliteIndex = (_eliteIndex - 1 + _eliteIds.Count) % _eliteIds.Count;
        UpdateEliteDisplay();
    }

    private void ShowNextElite()  // = ShowNextSnake 미러
    {
        AudioUtils.PlaySFXUnscaled("BottomTab").Forget();
        if (_eliteIds.Count <= 1) return;
        _eliteIndex = (_eliteIndex + 1) % _eliteIds.Count;
        UpdateEliteDisplay();
    }

    private void DisplayNormalEnemies()  // StageInfoPopupUI.DisplayNormalEnemies 복제
    {
        CleanupNormalDisplays();
        bool first = true;
        foreach (var id in _regularIds)
        {
            var go = Instantiate(_enemyDisplayPrefab, _normalEnemiesContainer);
            var disp = go.GetComponent<EnemyDisplayComponent>();
            if (disp == null) continue;
            SetupEnemy(disp, id).Forget();
            disp.SetPartitionLineActive(!first);
            first = false;
            _normalDisplays.Add(disp);
        }
    }

    private async UniTask SetupEnemy(EnemyDisplayComponent disp, int enemyId)
        => await disp.SetupAsync(EStageType.Normal, enemyId); // Vanguard 전용 EStageType 필요 시 확장 [설계 판단]

    private void CleanupNormalDisplays()
    {
        foreach (var d in _normalDisplays)
            if (d != null && d.gameObject != null) Destroy(d.gameObject);
        _normalDisplays.Clear();
    }

    // ─────────── 닫기/연출 (StageInfoPopupUI 복제) ───────────
    private void ClosePopup() => Managers.Instance.GetManager<UIManager>()?.Hide<VanguardInfoPopup>();

    private void PlayShowAnimation()
    {
        _showSequence?.Kill();
        _showSequence = DOTween.Sequence();
        if (_backgroundCanvasGroup != null) _showSequence.Append(_backgroundCanvasGroup.DOFade(0.8f, _animationDuration));
        if (_popupContainer != null)
        {
            _popupContainer.transform.localScale = Vector3.zero;
            _showSequence.Join(_popupContainer.transform.DOScale(1f, _animationDuration).SetEase(Ease.OutBack));
        }
    }

    // ── 테스트 더미 ──
    private List<int> GetTestEliteIds()   => new() { /* 정예 2종 enemyID */ };
    private List<int> GetTestRegularIds() => new() { /* 일반 6종 enemyID */ };
}
```

### 5-2. 호출부 수정 (`VanguardLobbyPanel.cs`)

```csharp
private void OnClickEventInfo() => _uiManager?.Show<VanguardInfoPopup>();
// 인트로 패널(별도 문서): 타이틀 ⓘ → Show<VanguardInfoPopup>(VanguardInfoTab.Rules)
//                        적 ⓘ   → Show<VanguardInfoPopup>(VanguardInfoTab.Enemies)
```

### 5-3. Localization 키 (신규)

| 키 | 내용(스샷 기준) |
|---|---|
| `vanguard_rule_basic_title` | 기본 규칙 |
| `vanguard_rule_basic_body` | 1. 이벤트 기간 동안 총 9개의 포대가 지정… 2. 일반 적 6종과 정예 적 2종… 무작위 출현 |
| `vanguard_rule_mode_title` | 모드 규칙 |
| `vanguard_rule_mode_body` | 1. 매주 화요일 UTC 0시~수요일 UTC 24시… 2. 외부 성장 수치/자원 휴대 불가(다이아 제외)… 3. 처음 10회 전투 열쇠 +1, 5회 이후 데이터 조각 개봉 |
| `vanguard_close_hint` | -빈 곳을 눌러 닫기- |
| (기존) `vanguard_title` | 스파크 프로젝트: 뱅가드 |

> 본문은 `\n` 줄바꿈 포함 단일 키(RulePanelPopup 방식). 항목별 분리 키가 필요하면 `_01/_02/_03` 분할.

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 시즌 정예 2 / 일반 6 ID | ⚠️ 미구현 | `VanguardSeasonService.GetSeasonEliteIds()/GetSeasonRegularIds()` — [[2026-06-03_vanguard-intro-panel-ui]] §8 `GetSeasonEnemyIds()`와 **동일 소스, 정예/일반 분리 형태로 통일** 권장. Stub 선개발 |
| 적 타입 | **확정: 전부 Snake** | WD Vanguard는 Snake 타입 적만 사용(사용자 확정). 표시 경로 = 파셜의 Snake 경로(`SetupEnemyDisplay`→`EnemyDisplayComponent.SetupAsync`) 그대로 |
| (대안) 웨이브 기반 수집 | 선택지 | 시즌 적 ID를 서버가 직접 안 내려주면 파셜 `ProcessSnakeData()` 방식 재사용 가능: Vanguard 주차 `waveIDs` → `LoadResourceAsync<WaveDataSO>("ScriptableObjects/WaveData/{id}")` → `enemyIDs` 수집·중복 제거. 단 파셜의 "최대 3개 제한"은 Vanguard(정예2+일반6)에 맞게 제거/변경 |
| 적 이미지 | 기존 경로 | `EnemyDisplayComponent.SetupAsync(EStageType, enemyID)`가 내부 처리(Snake 적도 동일 컴포넌트) — 인트로 문서의 "EnemyDataSO 아이콘 부재" 이슈는 **본 팝업엔 해당 없음** |
| `EStageType` 인자 | 확인 필요 | `SetupAsync`의 스테이지 타입이 표시(배경/등급)에 영향이면 Vanguard 전용 값 추가 검토(§8) |
| 규칙 텍스트 | 정적 | Localization 키(5-3). 하드코딩 금지 |

**CLAUDE.md 준수**: `GetManager<T>()`만 / `async void` 금지(UniTask) / 텍스트 로컬라이즈 / `Closed`에서 정리 / Find 계열 금지.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardInfoTab` enum + `VanguardInfoPopup.cs` 작성(5-1). 빌드-그린.
2. [ ] (데이터) `VanguardSeasonService`에 정예/일반 분리 getter 추가 또는 Stub.

**B. 프리팹**

3. [ ] `StageInfoPopupUI.prefab` 복제 → `Resources_moved/UI/VanguardInfoPopup.prefab`.
4. [ ] 루트 스크립트 교체(`StageInfoPopupUI`→`VanguardInfoPopup`) + 4장 하이어라키대로 개조:
   - StageInfoPanel → `EnemiesPanel`: 보상 스크롤/약점내성/스테이지명·설명 **삭제**. 캐러셀은 **파셜 Snake 3종 레이아웃(NoEnemyOverlay/Single/Multi) 전부 유지**(원본 프리팹의 `_noEliteBossOverlay`/`_singleEnemyLayout`/`_multiEnemyLayout` 트리오 그대로) + 일반 스트립에 가로 ScrollRect 추가.
   - ClearListPanel → `RulesPanel`: 클리어 리스트 아이템/상태텍스트 **삭제**, 세로 ScrollRect + 섹션 제목/본문 ×2 배치(RulePanelPopup 스타일).
5. [ ] 탭 라벨 텍스트 교체("이번 시즌 적"/"모드 규칙"), 타이틀 "스파크 프로젝트: 뱅가드".
6. [ ] 필드 연결: 컨테이너/배경버튼/X/탭 4종/캐러셀 3종/스트립 2종/규칙 텍스트 4종.
7. [ ] 배경에 `-빈 곳을 눌러 닫기-` 라벨 추가.

**C. 연동**

8. [ ] `VanguardLobbyPanel.OnClickEventInfo` → `Show<VanguardInfoPopup>()` 교체.
9. [ ] (선택) `VanguardIntroPanel` ⓘ 2곳 → 초기 탭 param 연결([[2026-06-03_vanguard-intro-panel-ui]] §7 `OnClickRewardList`/`OnClickEnemyInfo` TODO 해소).
10. [ ] Localization 키 5종 추가(5-3).
11. [ ] `_useTestData=true`로 에디터 테스트.

---

## 8. 검증 체크리스트

- [ ] 로비 ⓘ → 팝업 오픈(스케일+페이드 연출), 기본 탭=이번 시즌 적.
- [ ] 정예 캐러셀: ◀▶ 순환, 페이지 도트 2개 동기화, 이름 주황 표기.
- [ ] 일반 적 스트립: 6종 가로 스크롤 + 구분선, 이름 표기.
- [ ] 탭 전환: 인디케이터 플립 + 텍스트 색 + 패널 토글 + 사운드.
- [ ] 모드 규칙 탭: 기본 규칙/모드 규칙 섹션 텍스트(로컬라이즈) + 세로 스크롤.
- [ ] X 버튼 + 배경(빈 곳) 클릭 닫기 모두 동작.
- [ ] `Opened(param)` 초기 탭 지정 동작(Rules/Enemies).
- [ ] `Closed`에서 스트립 인스턴스 정리(누수 없음), 시퀀스 Kill.
- [ ] CLAUDE.md 준수(GetManager/UniTask/로컬라이즈/Find 금지).

---

## 9. 미해결 / 확인 필요

**확정됨 (2026-06-04 보완)**

- [x] **적 표시 참조 경로**: `StageInfoPopupUI.Partial.cs`(`_InGame/Scripts/UI/`)의 **Snake 경로**로 확정 — WD Vanguard는 Snake 타입 적만 사용(사용자 확정). base의 정예/보스 경로는 참조하지 않음.
- [x] **캐러셀 레이아웃**: 파셜과 동일한 0/1/2+ 분기(NoOverlay/Single/Multi) 유지.

**확인 필요**

- [ ] **`EnemyDisplayComponent.SetupAsync`의 `EStageType` 의미**: 표시 분기에 쓰이면 Vanguard 값 신설 여부 — 컴포넌트 내부 확인 후 결정.
- [ ] **정예 이름 주황/"정예" 접두 처리 위치**: EnemyDisplayComponent 옵션 vs 팝업에서 색 오버라이드.
- [ ] **적 클릭 툴팁(EnemyTooltip) 포함 여부**: StageInfoPopupUI 기능 유지할지 — 기획 결정.
- [ ] **시즌 적 ID 공급 방식**: 서버가 정예/일반 분리 ID를 직접 제공 vs Vanguard 주차 `waveIDs`에서 파셜 `ProcessSnakeData` 방식으로 수집(§6 대안) → [[2026-05-31_vanguard-server-api-spec]] 동기화. 인트로 패널 문서의 `GetSeasonEnemyIds()`와 형태 통일.
- [ ] **규칙 본문 분할 키** 필요 여부(번역 길이 대응).

---

> 작성: 2026-06-04 · 선행 코드 확인: `StageInfoPopupUI`(탭/일반스트립/배경닫기/연출 — 전부 실코드 검증), `RulePanelPopup`(4텍스트 패턴), `EnemyDisplayComponent` 사용부(`SetupAsync/Initialize/SetToggleState/SetPartitionLineActive`), `VanguardLobbyPanel.OnClickEventInfo`(현 RulePanelPopup 임시 연결). 스샷 2장(이번 시즌 적/모드 규칙 탭) + 위키 규칙 원문 대응 반영.
> 보완: 2026-06-04 · **`StageInfoPopupUI.Partial.cs`(`_InGame/Scripts/UI/`) 분석 반영** — WD는 Snake 타입 적만 사용하며 ◀▶이 파셜의 `ShowPrev/NextSnake`에 바인딩됨을 확인. 캐러셀을 파셜의 `DisplaySnakeEnemies` 0/1/2+ 레이아웃 분기(`_noEliteBossOverlay`/`_singleEnemyLayout`/`_multiEnemyLayout`)로 정정(§2-2/§3/§4/§5-1), 웨이브 기반 적 수집 대안(`ProcessSnakeData`) 추가(§6). 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
