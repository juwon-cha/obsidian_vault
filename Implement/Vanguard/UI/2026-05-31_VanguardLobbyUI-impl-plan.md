# VanguardLobbyUI 구현 계획 (2026-05-31)

> 상위: [[2026-05-29_vanguard-implementation-plan-overview]] / [[2026-05-29_vanguard-implementation-plan-outgame]]
> 컨텐츠 진입점인 메인 로비 UI. RaceTowerLobbyUI 패턴을 베이스로 한다.

Gemini 1차 분석을 받았으나 **일반 Unity 패턴**이라 이 프로젝트 컨벤션과 어긋나는 부분이 있어 교정·보완한다.

**베이스 레퍼런스: `ArkLobbyPanel`** (RaceTowerLobbyUI보다 Vanguard에 더 유사 — 아래 0-A 참조).

---

## 0-A. 베이스 레퍼런스 = ArkLobbyPanel (구조 결정)

VanguardLobbyUI는 RaceTowerLobbyUI보다 **ArkLobby 구조와 더 흡사**하다. 메인 전투 뷰로 가는 버튼 + 랭킹/상점 버튼 + 공격력 박스 + 하단 액션 버튼(레드닷/잠금) 구성이 거의 일치한다.

### Ark의 실제 구조 (확인됨)

```
ArkLobbyUI : UIBase          ← 오케스트레이터 (Show/Hide/Opened 생명주기, 패널 전환)
  ├ ArkLobbyPanel  : MonoBehaviour   ← 메인 로비 뷰 (재화/버튼/공격력/적/슬롯)
  ├ ArkIntroPanel  : MonoBehaviour   ← 시즌 인트로
  └ ArkResultPanel : MonoBehaviour   ← 이전 시즌 결과/보상
```

→ **Vanguard도 동일 분리 채택**:

```
VanguardLobbyUI : UIBase           ← 오케스트레이터
  └ VanguardLobbyPanel : MonoBehaviour  ← 메인 로비 뷰 (스샷 화면 = 이 패널)
  (필요 시 VanguardIntroPanel / VanguardResultPanel 추가 — 이전시즌 보상 표시용)
```

> 1차 스코프는 `VanguardLobbyPanel` 하나로 시작. 시즌 인트로/결과 패널은 Ark처럼 후속 추가 가능. **UIBase 생명주기는 `VanguardLobbyUI`가, 화면 요소(1~12)는 `VanguardLobbyPanel`이 담당.**

### ArkLobbyPanel에서 그대로 가져올 요소

| Vanguard 요소 | ArkLobbyPanel 대응 (확인됨) |
|---|---|
| 상단 재화 박스 (2) | `_topCurrencyBox` (`TopCurrencyBoxComponent`) |
| 정보 버튼 (3) | `_arkInfoButton` / `_stageInfoButton` |
| 랭킹 버튼 (5) | `_rankingButton` |
| 상점 버튼 + 레드닷 (6) | `_shopButton` + `_shopButtonRedDot` |
| 공격력 박스 (8) | `_attackPowerBox` / `_attackPowerText` + `_attackPowerRedDot` |
| 적 라인업 (7) | `_enemyBox` / `_enemyListCanvasGroup` |
| 시즌 타이머 | `_countdownText` |
| 진행 게이지 (4) | `_subStageGaugeSlider` / `_mainStageGaugeImage` (Vanguard는 티어 게이지로 치환) |
| 하단 액션 버튼 (9~12) | `_unitButton`+RedDot / `_startButton` / `_patrolButton`+RedDot |
| CanvasGroup 영역 분리 | `_topCanvasGroup` / `_bottomCanvasGroup` (페이드·차단 제어) |

> 즉 **VanguardLobbyPanel = ArkLobbyPanel의 경량/치환 버전**. Ark의 모듈/유닛슬롯/방주 클로즈업 등 Vanguard에 없는 요소는 제거하고, 티어 게이지·Match/Duel·Turret/Auto-Patrol로 치환.

---

## 0. Gemini 분석 교정 포인트 (프로젝트 컨벤션 불일치)

| 항목 | Gemini (교정 전) | **WiggleDefender 실제 (교정 후)** |
|---|---|---|
| 베이스 클래스 | `MonoBehaviour` (단일) | **`VanguardLobbyUI : UIBase`(오케스트레이터) + `VanguardLobbyPanel : MonoBehaviour`(뷰)** — ArkLobby 패턴 (0-A) |
| 네임스페이스 | `TeamSparta.WiggleDefender.Vanguard` | **네임스페이스 없음** (프로젝트 전역 무네임스페이스) |
| 필드 명명 | `btnBack`, `txtTimeLeft` (camelCase) | **`_backButton`, `_timeLeftText`** (`_underscore` + SerializeField) |
| 생명주기 | `Start()` / `OnDestroy()` | **`Awake()`(매니저 캐시) / `Opened(object[])`(구독·갱신) / `Closed(object[])`(해제)** |
| 화면 전환 | `Debug.Log` 자리표시 | **`_uiManager.Show<T>(params)` / `Hide<T>()`** |
| 파라미터 전달 | 커스텀 메서드 | **`object[] param`** (UIManager.Show 인자) |
| 이벤트 | `btn.onClick`만 | onClick + **`EventManager`(STATIC) Subscribe/Unsubscribe** |
| 재화 표시 | 재화별 프리팹 수동 | **`TopCurrencyBoxComponent` 재사용** (최대 4종) |
| 문자열 | 하드코딩 | **`LocalizationManager.GetLocalizedText()`** (CLAUDE.md 필수) |
| 티어 enum | `Tier { Bronze, Silver1, Gold3, Ultimate }` 임의 | **`EVanguardTier`** — ⚠️ 단 현재 enum에 Bronze/Platinum 없음(아래 6장) |
| 매니저 접근 | 직접 참조 | **`Managers.Instance.GetManager<T>()`** |
| 서버 호출 | 없음 | **`ServerLoadingPopupUI.Show/Hide`** 래핑 (Match/Duel) |

> Gemini의 **최적화 조언(레이아웃 리빌드 방지·Anchor 분할·팝업 캔버스 분리)은 타당** → 그대로 채택.

---

## 1. 스크린샷 요소 매핑 (1~12)

| # | 요소 | 위치 | 동작 |
|---|---|---|---|
| 1 | Back | 좌상단 홈 아이콘 | 로비 Hide → 메인 전투 뷰 복귀 |
| 2 | Currency List | 상단 바 (스샷 3종) | `TopCurrencyBoxComponent` |
| 3 | Event Info & Rules | 타이틀 옆 `?` | `RulePanelPopup` (규칙 텍스트) |
| - | 시즌 타이머 | 우상단 `45:43:00` | 시즌 종료까지 카운트다운 |
| 4 | Tier 진행도 | 중앙 (Bronze 1, 40/100) | 티어 뱃지 + 진행 바 |
| 5 | Leaderboard | 우측 (포디움) | `Gold 3` 해금. 미달 시 Lock |
| 6 | Ember Shop | 우측 (바구니 + `!`) | 상점 팝업. RedDot |
| 7 | Next Enemies | 중앙 (3슬롯) | 다음 매치 적 미리보기 |
| 8 | Fortress Attack | 중앙 하단 (`🔥100`) | 요새 공격 업그레이드 팝업 |
| 9 | Match | 하단 노랑 (Extra Rewards 11/20) | 일반 매칭 |
| 10 | Duel | 하단 청록 (`0/1` 토큰) | 듀얼 매칭 (토큰 소모) |
| 11 | Auto-Patrol | 하단 우측 | `Silver 1` 해금. 미달 시 Lock |
| 12 | Turret | 하단 좌측 (`!`) | 터렛/칩 세팅. RedDot |

**하단 바 좌→우 순서**: Turret(12) │ Duel(10) │ Match(9) │ Auto-Patrol(11). Fortress(8)는 하단 바 위 중앙.

---

## 2. 프리팹 계층 구조 (ArkLobby 패턴 — UIBase + Panel 분리)

```
[Canvas] VanguardLobbyUI (UIBase — 오케스트레이터, Show/Hide/Opened/Closed)
 └── SafeArea
      └── VanguardLobbyPanel (MonoBehaviour — 메인 로비 뷰, ArkLobbyPanel 대응)
           ├── TopCanvasGroup ............... 상단 영역 (페이드/입력차단 제어용 CanvasGroup)
           │    ├── Btn_Back ............................ (1)
           │    ├── TopCurrencyBox (TopCurrencyBoxComponent) ... (2) ※ 재사용
           │    └── TitleGroup
           │         ├── Txt_Title (Localized)
           │         ├── Btn_EventInfo ................. (3)
           │         └── Txt_TimeLeft ................. 시즌 타이머 (Ark _countdownText)
           │
           ├── CenterGroup
           │    ├── TierGauge ......................... (4) (Ark 게이지 치환)
           │    │    ├── Img_TierBadge
           │    │    ├── Txt_TierName (Localized)
           │    │    ├── Slider_TierProgress (fillAmount)
           │    │    └── Txt_TierProgress ("40/100")
           │    ├── AttackPowerBox .................... (8) (Ark _attackPowerBox 대응)
           │    │    ├── Txt_AttackValue ("100")
           │    │    └── RedDot
           │    └── NextEnemiesGroup .................. (7) (Ark _enemyBox 대응)
           │         └── EnemySlot_1 / _2 / _3
           │
           ├── RightButtonBox ........................ (Ark _rightButtonBox 대응)
           │    ├── Btn_Leaderboard ................... (5) + Lock_Overlay (Gold3)
           │    └── Btn_EmberShop ..................... (6) + RedDot
           │
           └── BottomCanvasGroup ..................... 하단 영역 (Ark _bottomCanvasGroup)
                ├── Btn_Turret ...................... (12) + RedDot  (Ark _unitButton 대응)
                ├── Btn_Duel ........................ (10) + Txt_TokenCost("0/1")
                ├── Btn_Match ....................... (9)  + Txt_ExtraRewards("11/20") (Ark _startButton 대응)
                └── Btn_AutoPatrol .................. (11) + Lock_Overlay (Silver1) (Ark _patrolButton 대응)
```

> **UIBase는 `VanguardLobbyUI`, 화면 요소는 `VanguardLobbyPanel`**. ArkLobbyUI가 `_arkLobbyPanel`을 SerializeField로 들고 Opened에서 패널을 초기화하는 구조 그대로. (1차엔 패널 1개, 시즌 인트로/결과 패널은 후속 추가 가능)

> **팝업은 이 프리팹에 두지 않는다.** `UIManager.Show<T>()`로 별도 프리팹 호출. UIManager가 팝업 생명주기를 관리하므로 로비 프리팹 내부에 중첩하지 않는 게 정석.

> **CanvasGroup 영역 분리**: Ark처럼 Top/Bottom을 CanvasGroup으로 나누면 매칭 진입 등에서 입력 차단·페이드를 영역 단위로 제어 가능 (Gemini의 "팝업 캔버스 분리" 취지를 프로젝트 방식으로).

> **레이아웃**: 하단 버튼은 `HorizontalLayoutGroup` 대신 RectTransform Anchor 비율 분할 (Gemini 조언 채택). 크기 고정이라 리빌드 불필요.

---

## 3. 스크립트 스켈레톤 (ArkLobby 패턴 — UIBase + Panel 분리)

### 3-A. 오케스트레이터 — VanguardLobbyUI : UIBase

```csharp
using UnityEngine;

/// <summary>
/// Vanguard 로비 UI 오케스트레이터. ArkLobbyUI 패턴.
/// 생명주기(Show/Hide/Opened/Closed)와 패널 보유를 담당하고,
/// 화면 요소는 VanguardLobbyPanel이 처리한다.
/// </summary>
public class VanguardLobbyUI : UIBase
{
    [SerializeField] private VanguardLobbyPanel _lobbyPanel;
    // (후속) [SerializeField] private VanguardIntroPanel _introPanel;
    // (후속) [SerializeField] private VanguardResultPanel _resultPanel;

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _lobbyPanel.Initialize();   // 패널에 매니저/이벤트/갱신 위임
        _lobbyPanel.Refresh();
    }

    public override void Closed(object[] param)
    {
        _lobbyPanel.Cleanup();      // 이벤트 해제 위임
        base.Closed(param);
    }
}
```

### 3-B. 메인 뷰 — VanguardLobbyPanel : MonoBehaviour

```csharp
using System;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 메인 로비 뷰 (스크린샷 화면). ArkLobbyPanel 대응 — 경량/치환 버전.
/// </summary>
public class VanguardLobbyPanel : MonoBehaviour
{
    #region Serialized Fields

    [Header("1. Top / Title")]
    [SerializeField] private Button _backButton;
    [SerializeField] private Button _eventInfoButton;
    [SerializeField] private TextMeshProUGUI _timeLeftText;

    [Header("2. Currency")]
    [SerializeField] private TopCurrencyBoxComponent _currencyBox;

    [Header("4. Tier")]
    [SerializeField] private Image _tierBadgeImage;
    [SerializeField] private TextMeshProUGUI _tierNameText;
    [SerializeField] private Slider _tierProgressSlider;
    [SerializeField] private TextMeshProUGUI _tierProgressText;

    [Header("5/6. Right")]
    [SerializeField] private Button _leaderboardButton;
    [SerializeField] private GameObject _leaderboardLock;
    [SerializeField] private Button _shopButton;
    [SerializeField] private RedDotComponent _shopRedDot;

    [Header("7. Next Enemies")]
    [SerializeField] private Image[] _nextEnemyIcons; // 3개

    [Header("8~12. Bottom")]
    [SerializeField] private Button _fortressAttackButton;
    [SerializeField] private TextMeshProUGUI _fortressAttackValueText;
    [SerializeField] private Button _turretButton;
    [SerializeField] private RedDotComponent _turretRedDot;
    [SerializeField] private Button _duelButton;
    [SerializeField] private TextMeshProUGUI _duelTokenText;
    [SerializeField] private Button _matchButton;
    [SerializeField] private TextMeshProUGUI _extraRewardsText;
    [SerializeField] private Button _autoPatrolButton;
    [SerializeField] private GameObject _autoPatrolLock;

    #endregion

    #region Cached Managers
    private VanguardManager _manager;
    private UIManager _uiManager;
    private ServerTimeManager _serverTimeManager;
    private CurrencyManager _currencyManager;
    #endregion

    private bool _bound;

    /// <summary>VanguardLobbyUI.Opened()에서 호출. 매니저 캐시 + onClick 바인딩(1회) + 이벤트 구독.</summary>
    public void Initialize()
    {
        _manager = Managers.Instance.GetManager<VanguardManager>();
        _uiManager = Managers.Instance.GetManager<UIManager>();
        _serverTimeManager = Managers.Instance.GetManager<ServerTimeManager>();
        _currencyManager = Managers.Instance.GetManager<CurrencyManager>();

        if (!_bound)
        {
            _bound = true;
            _backButton.onClick.AddListener(OnClickBack);
            _eventInfoButton.onClick.AddListener(OnClickEventInfo);
            _leaderboardButton.onClick.AddListener(OnClickLeaderboard);
            _shopButton.onClick.AddListener(OnClickShop);
            _fortressAttackButton.onClick.AddListener(OnClickFortressAttack);
            _turretButton.onClick.AddListener(OnClickTurret);
            _duelButton.onClick.AddListener(OnClickDuel);
            _matchButton.onClick.AddListener(OnClickMatch);
            _autoPatrolButton.onClick.AddListener(OnClickAutoPatrol);
        }

        // 재화 박스 초기화 (표시 재화 종류는 기획 확인 — 스샷상 3종)
        _currencyBox.Initialize(
            new[] { ECurrencyType.VanguardStandardDS, ECurrencyType.VanguardEmberMark, ECurrencyType.VanguardDualToken },
            _currencyManager);

        // STATIC EventManager 구독
        EventManager.Subscribe<CurrencyChangedEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);

        StartTimerLoop().Forget(); // 시즌 카운트다운
    }

    /// <summary>VanguardLobbyUI.Closed()에서 호출. 이벤트 해제. (onClick은 파괴 시 자동 소멸)</summary>
    public void Cleanup()
    {
        EventManager.Unsubscribe<CurrencyChangedEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
    }

    #region Refresh
    public void Refresh() => RefreshAll();

    private void RefreshAll()
    {
        UpdateTierDisplay();
        UpdateNextEnemies();
        UpdateLockStates();
        UpdateBottomCounters();
        UpdateRedDots();
    }

    private void UpdateTierDisplay()
    {
        var rank = _manager.RankService;
        _tierNameText.text = LocalizationManager.GetLocalizedText(rank.TierLocKey);
        _tierProgressSlider.value = rank.NextTierPoints > 0 ? (float)rank.CurrentPoints / rank.NextTierPoints : 1f;
        _tierProgressText.text = $"{rank.CurrentPoints}/{rank.NextTierPoints}";
        // _tierBadgeImage.sprite = ResourceManager로 티어 뱃지 로드
    }

    private void UpdateNextEnemies()
    {
        var enemies = _manager /* .NextEnemies */;
        for (int i = 0; i < _nextEnemyIcons.Length; i++)
        {
            // 서버 제공 다음 매치 적 라인업 (전 플레이어 동일 고정 세트)
        }
    }

    private void UpdateLockStates()
    {
        bool leaderboardUnlocked = _manager.RankService.Tier >= EVanguardTier.Gold3;
        _leaderboardButton.interactable = leaderboardUnlocked;
        _leaderboardLock.SetActive(!leaderboardUnlocked);

        bool patrolUnlocked = _manager.RankService.Tier >= EVanguardTier.Silver1;
        _autoPatrolButton.interactable = patrolUnlocked;
        _autoPatrolLock.SetActive(!patrolUnlocked);
    }
    #endregion

    #region OnClick (UIManager.Show 사용)
    private void OnClickBack() => _uiManager?.Hide<VanguardLobbyUI>();
    private void OnClickEventInfo() => _uiManager?.Show<RulePanelPopup>(/* 규칙 Loc 키들 */);
    private void OnClickLeaderboard() => _uiManager?.Show<VanguardLeaderboardPopup>();
    private void OnClickShop() => _uiManager?.Show<VanguardShopPopup>();
    private void OnClickFortressAttack() => _uiManager?.Show<VanguardFortressUpgradePopup>();
    private void OnClickTurret() => _uiManager?.Show<VanguardTurretSetupPopup>();
    private void OnClickMatch() => StartMatchAsync(EVanguardMode.Match).Forget();
    private void OnClickDuel() => _uiManager?.Show<VanguardDuelSelectPopup>();
    private void OnClickAutoPatrol() => _uiManager?.Show<VanguardAutoPatrolPopup>();

    private async UniTaskVoid StartMatchAsync(EVanguardMode mode)
    {
        var popup = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("vanguard_matching"));
        try { /* var match = await _manager.FindMatchAsync(mode); → 게임씬 진입 */ }
        finally { ServerLoadingPopupUI.Hide(); }
    }
    #endregion

    private void OnCurrencyChanged(CurrencyChangedEventData data) { /* 재화 박스 갱신 */ }

    private async UniTaskVoid StartTimerLoop() { /* ServerTimeManager 기반 시즌 종료 카운트다운 */ }
}
```

> `onClick.RemoveAllListeners`는 `UIBase`가 Destroy 관리하므로 RaceTowerLobbyUI처럼 생략 가능(파괴 시 리스너도 소멸). 단 `EventManager` 구독은 STATIC이라 **반드시 Closed에서 Unsubscribe** (CLAUDE.md).

---

## 4. 재사용 컴포넌트 (신규 제작 불필요)

| 기능 | 재사용 자산 |
|---|---|
| 상단 재화 바 (2) | `TopCurrencyBoxComponent` (최대 4종, CurrencyManager 연동) |
| 규칙 팝업 (3) | `RulePanelPopup` (RaceTower `_infoButton` 패턴) |
| 레드닷 (6, 12) | `RedDotComponent` |
| 서버 로딩 (9, 10) | `ServerLoadingPopupUI.Show/Hide` |
| 로비 생명주기 | `UIBase` + `UIManager.Show/Hide` |
| 잠금 오버레이 (5, 11) | Lock GameObject 토글 (RaceTower `_closedOverlay` 패턴) |

---

## 5. 진입 / 네비게이션 플로우

```
DungeonSelectUI (던전 슬롯)
   └ Vanguard 슬롯 클릭
      → VanguardManager.EnterAsync() (서버 /vanguard/enter, ServerLoadingPopupUI 래핑)
      → 이전 시즌 보상 있으면 RankRewardPopup 먼저 (Horde/Ark 패턴)
      → UIManager.Show<VanguardLobbyUI>()

VanguardLobbyUI
   ├ Back        → Hide<VanguardLobbyUI> (+ DungeonSelect 복귀)
   ├ Match/Duel  → 매칭 → 게임씬(GameModeType.Vanguard) 진입
   └ 그 외 버튼   → 각 팝업 Show
```

> 진입점은 기존 `DungeonSlotDisplay`/`DungeonSelectUI`에 Vanguard 슬롯을 추가하는 형태 (HordeDungeon `TryEnterHordeLobbyAsync` 패턴 복제).

---

## 6. 선결 과제 — EVanguardTier enum 보강 (사용자 직접 수정 예정)

현재 커밋된 `EVanguardTier`는 Silver~Diamond만 있다. 스크린샷("Bronze 1") + 리더보드 텍스트(Platinum)로 보아 실제 사다리는 더 길다.

**확정된 티어 사다리** (사용자 확인):
```
Bronze → Silver → Gold → Platinum → Diamond → Vanguard
```

→ 티어 비교(`>= EVanguardTier.Gold3` 등)가 정확하려면 enum 순서가 이 사다리와 일치해야 한다. **이 enum 보강은 사용자가 직접 수정 예정.**

- enum 순서: Bronze < Silver < Gold < Platinum < Diamond < Vanguard (최상위)
- 각 티어 세부 단계 수(Bronze 1~N 등)는 실게임 확인 후 채움
- UI 코드는 이 enum 확정을 전제로 `>=` 비교 사용 (해금: 리더보드 Gold3, Auto-Patrol Silver1)

---

## 7. 미해결 / 확인 필요

- [ ] 상단 재화 바에 표시할 **재화 종류·개수** (스샷 3종으로 보이나 정확한 종류 확인)
- [ ] `TopCurrencyBoxComponent`가 Vanguard 재화(서버 권위 잔량)를 표시 가능한지 — CurrencyManager에 동기화되는지 확인 (Ark는 `useArkCurrency` 플래그로 별도 조회. Vanguard도 유사 분기 필요할 수 있음)
- [ ] 티어 뱃지 스프라이트 리소스 경로/명명 규칙
- [ ] 시즌 타이머: 시즌 종료 시각을 `/vanguard/enter` 응답에서 받는지 (Ark `rankingEndDate` 패턴)
- [ ] Match `Extra Rewards 11/20`, Duel `0/1` 카운터의 데이터 출처(서버/로컬)
- [ ] Fortress Attack 값(`100`)이 로비에 상시 표시되는지, 어느 데이터인지

---

## 8. 구현 체크리스트

- [ ] (선결, 사용자) `EVanguardTier` 사다리 보강 (Bronze~Vanguard)
- [ ] `VanguardLobbyUI.cs` (UIBase 오케스트레이터, 패널 보유 + Opened/Closed)
- [ ] `VanguardLobbyPanel.cs` (MonoBehaviour 뷰, ArkLobbyPanel 대응, `_underscore` 필드)
- [ ] 프리팹: `VanguardLobbyUI > SafeArea > VanguardLobbyPanel` + Top/Bottom CanvasGroup 분리
- [ ] `TopCurrencyBoxComponent` 배치 + Initialize
- [ ] Lock 오버레이 (Leaderboard Gold3 / Auto-Patrol Silver1)
- [ ] RedDot (Shop/Turret) — `RedDotComponent`
- [ ] 시즌 타이머 루프 (`ServerTimeManager`, Ark `_countdownText` 패턴)
- [ ] OnClick → `UIManager.Show<T>` 연결 (팝업 클래스는 후속 문서에서 정의)
- [ ] `EventManager` 구독/해제 (Panel.Initialize/Cleanup, UIBase Opened/Closed가 호출)
- [ ] 하드코딩 문자열 → `LocalizationManager` 키
- [ ] DungeonSelect에 Vanguard 진입점 추가 (HordeDungeon `TryEnter...Async` 패턴)

> 팝업 클래스(VanguardShopPopup / VanguardLeaderboardPopup / VanguardTurretSetupPopup / VanguardDuelSelectPopup / VanguardFortressUpgradePopup / VanguardAutoPatrolPopup)는 **각각 별도 UI 구현 문서**로 분리 작성 예정.
