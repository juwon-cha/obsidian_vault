# Vanguard 듀얼 매칭 팝업(DuelMatchingPopup) 구현 종합 문서 (2026-06-03)

## 문서 목적

로비에서 **Duel 토큰이 충분한 상태에서 Duel 버튼**을 누르면 뜨는 **상대 선택 팝업**(첨부 이미지)의 프리팹 + 스크립트를 이 문서만 보고 제작할 수 있도록 정리한다. 첨부 이미지와 **완전히 동일한 형태**를 목표로 한다.

- 구현 대상 = 기존 스켈레톤 **`VanguardDuelSelectPopup : VanguardPopupBase`** 본문 채움. (프리팹: `Resources_moved/UI/VanguardDuelSelectPopup.prefab`) — 사내 명칭 "DuelMatchingPopup"은 이 클래스에 매핑.
- 짝 문서: [[2026-06-03_vanguard-intro-panel-ui]], [[2026-06-03_vanguard-ingame-battle-ui]], [[2026-06-03_vanguard-turret-setup-ui]]
- `[설계 판단]` = 위키/스샷 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 기존 `VanguardDuelSelectPopup : VanguardPopupBase` 본문 채움 (프리팹/이름 유지) |
| 핵심 구성 | 헤더 + 시즌타이머 + 내 전투력(공격력/칩수) + **후보 3행** + 하단 보너스 안내 + 새로고침 + 포기 |
| 신규 스크립트 | `VanguardDuelOpponentSlot.cs`(후보 1행) + `IVanguardDuelProvider`/Stub(데이터) |
| 재사용 | `VanguardRankingDisplaySlot`(프로필/프레임/티어/닉) · `VanguardTierUtil`(티어 뱃지/이름) · `ItemDisplayComponent`(보상/재화) · `VanguardPopupBase`(닫기/생명주기) · `TopCurrencyBoxComponent`(상단 재화) |
| 진입 | `VanguardLobbyPanel.OnClickDuel` → 토큰 충분 시 `Show<VanguardDuelSelectPopup>()` |
| 도전 | `도전` → 해당 후보 클론으로 `FindMatchAsync(EVanguardMode.Duel)` → `LoadGameSceneAsync(Vanguard)` |
| 재화 | `ECurrencyType.VanguardDualToken`(소모) · 승리 시 2배 포인트 + Special 열쇠 1 |

---

## 1. 진입 / 액션 플로우 (확인된 코드 기준)

`VanguardLobbyPanel`(확인): `_duelButton.onClick → OnClickDuel() → _uiManager?.Show<VanguardDuelSelectPopup>()`. 듀얼 토큰 보유량은 `_duelTokenText`(=`CurrencyManager.GetCurrency(ECurrencyType.VanguardDualToken)`)로 이미 표기 중.

```
VanguardLobbyPanel.OnClickDuel()
  └─ (토큰 >= 1 확인) → Show<VanguardDuelSelectPopup>()
       └─ Opened → 후보 3명 요청(서버/Provider) + 내 전투력/시즌타이머 표시
            ├─ [도전] 행 → 해당 후보 클론으로 듀얼 시작
            │     └─ VanguardManager.FindMatchAsync(EVanguardMode.Duel, opponent)
            │          └─ SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)  // → VanguardBattleUI (인게임 문서)
            ├─ [새로고침] → 후보 3명 재요청 (Refresh)
            └─ [포기] → 듀얼 토큰 소모/취소 (위키: 상대 없으면 토큰 미소모)
```

> ⚠️ **토큰 소모 시점**(위키 패치 f): "Duel Mode 매칭 취소 시 상대를 못 찾으면 토큰 미소모". → **도전 확정(전투 진입) 시 소모**, 포기/취소는 미소모로 구현. 소모는 서버 권위.

---

## 2. 이미지 상세 분석 (완전 동일 목표)

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 헤더 타이틀 | `상대를 선택하세요` | `_titleText`(로컬라이즈) |
| B | 서브헤더 | `스파크 프로젝트: 뱅가드` + 시즌타이머 `45:18:11` | `_subTitleText` + `_seasonTimerText`(VanguardLobbyPanel 타이머 패턴) |
| C | 좌상단 | `돌아가기`(홈 아이콘) | `_backButton`(=Base `_closeButton`) |
| D | 내 티어 뱃지 | 중앙 `골드3 III` | `VanguardTierUtil.GetTierSprite/GetDisplayName` |
| E | 우상단 | `포기` | `_forfeitButton`(토큰 포기/취소) |
| F | 내 전투력 | `내 전투력` ◆`240` ⚙`42` | `_myAttackText`(◆=Attack) + `_myChipCountText`(⚙=Chip Count) |
| G | 후보 행 ×3 | 아래 표 | `VanguardDuelOpponentSlot` ×3 |
| H | 하단 보너스 | `승리 시 포인트 2배와 스페셜 스파크 열쇠 1개를 추가 획득 🎫` | `_bonusNoticeText`(로컬라이즈) |
| I | 하단 재화 | 회색 ◆`240` | `_currencyText`(보유 Standard DS, 비활성 표시) |
| J | 새로고침 | `🎥 새로고침`(보라 버튼) | `_refreshButton` |
| K | 코너 네비 | 포대/자동순찰 흐릿한 아이콘 | (로비 네비 배경 — 비활성/장식) |

### 후보 행(G) 1개 구성

| 요소 | 스샷(예: 1행) | 매핑 |
|---|---|---|
| 프로필 + 프레임 | 원형 아바타 + 랭크 엠블럼 | `VanguardRankingDisplaySlot`의 `LoadProfileIconAsync/LoadProfileFrameAsync` |
| 닉네임 + 리그아이콘 | `△ GJG_RT` | `_userName`(닉 컬러 적용) |
| 티어 뱃지 + 디비전 | `골드3 III` | `VanguardTierUtil` |
| 메달/포인트 수 | 노란 ◇ `x2` (행마다 x2/x0/x2) | `_medalCountText` `[설계 판단]`(승점 보너스/메달 — §10 확인) |
| 공격력 | ◆`260` | `_attackText` |
| 칩 수 | ⚙`32` | `_chipCountText` |
| 도전 버튼 | 청록 `도전` | `_challengeButton` |
| 승리 포인트 | `승리: +100` + `x2` 뱃지 | `_winPointText` + `_doublePointBadge` |

후보 데이터(3명): 공격력 260/400/100, 칩수 32/56/5, 티어 골드3/골드1/실버2, 승리 +100/+130/+70 (전부 x2).

---

## 3. 위키 근거 (Fandom V0.13.7 — "10. Dual Token Info")

> 출처: [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard). 듀얼 매칭 화면 관련만 정리(요약).

| 항목 | 내용 | 팝업 반영 |
|---|---|---|
| 상단 표시 | 내 **공격력 + 칩 수** | F. 내 전투력 |
| 후보 3 | 각 후보의 **현재 뱅가드 랭크 · 공격력 · 칩 수 · 승리 시 획득 포인트** | G. 후보 행 4데이터 |
| 새로고침 | 첫 3후보가 맘에 안 들면 **리프레시** 가능 | J. 새로고침 |
| 포기 | 마지막 옵션은 **듀얼 토큰 폐기/포기** | E. 포기 |
| 듀얼 토큰 | 승/패 무관 Special DS 100. **승리 시 포인트 2배 + Special 열쇠 1 추가** | H. 하단 보너스 + x2 뱃지 |
| 포인트 변동 | ±포인트는 **상대 랭크에 따라 변동** | 후보별 승리 포인트가 다름(+100/+130/+70) |
| 매칭 취소 | (패치 f) 상대 못 찾으면 **토큰 미소모** | 소모 시점 = 도전 확정 |
| 전략(참고) | 낮은 포인트 후보에 베팅해 승리 확률↑(Special 열쇠 확보가 핵심) | (밸런스 — UI 영향 없음) |

> 스샷의 "스페셜 스파크 열쇠"=위키 Special Ember Key(KR 빌드 Ember→스파크 리네임). "전투력 ◆"=Attack Icon, "⚙"=Chip Logo.

---

## 4. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **VanguardPopupBase** | `UI/Vanguard/Popup/VanguardPopupBase.cs` | 베이스(닫기/Popup 위치) | `_closeButton`→`ClosePopup()` · `uiPosition=Popup` |
| **VanguardRankingDisplaySlot** | `UI/Vanguard/Component/VanguardRankingDisplaySlot.cs` | **후보 행의 프로필/프레임/닉/티어 표시에 부분 재사용** | `LoadProfileIconAsync(int)` · `LoadProfileFrameAsync(int)` · `_userName`/`_tierBadgeImage`/`_tierNameText` · `TextUtility.ApplyNicknameColor` |
| **VanguardTierUtil** | `UI/Vanguard/VanguardTierUtil.cs` | 티어 뱃지/이름 | `GetTierSprite(EVanguardTier)` · `GetDisplayName(EVanguardTier)` |
| **ItemDisplayComponent** | `UI/Components/ItemDisplayComponent.cs` | 하단 보너스 아이콘(Special 열쇠 등) | `SetupItem(ECurrencyType, int)` |
| **TopCurrencyBoxComponent** | (VanguardLobbyPanel 사용) | 상단/하단 재화 | `Initialize(ECurrencyType[], CurrencyManager)` · `Refresh()` |
| 시즌 타이머 | `VanguardLobbyPanel` SeasonTimer 패턴 | 서브헤더 `45:18:11` | `ServerTimeManager` 기반 1초 루프 복제 |

> **후보 행 설계 선택**: `VanguardRankingDisplaySlot`는 랭킹 보드용(LoopGridView 풀 키 의존)이라 **그대로 행으로 쓰기보다**, 프로필/프레임/티어 표시 로직만 차용한 **전용 `VanguardDuelOpponentSlot`** 신규 작성을 권장(도전 버튼/승리포인트/공격력/칩수 등 듀얼 고유 요소 때문). 프로필 로드는 동일 `LoadProfileIconAsync` 경로(공통 base `RankingDisplaySlot`)를 재사용.

### 신규 스크립트 (1개 + 데이터)

- `VanguardDuelOpponentSlot.cs` — 후보 1행(프로필/티어/공격력/칩수/승리포인트/도전).
- `IVanguardDuelProvider` + `VanguardDuelProviderStub` — 후보 3명/새로고침/도전·포기 토큰 처리(서버 `VanguardServerService` 미구현 단계 추상화).

---

## 5. UI 프리팹 구조 (전체 하이어라키)

> 기존 `VanguardDuelSelectPopup.prefab` 내부를 채운다. 루트에 `VanguardDuelSelectPopup.cs`. `Show<T>`가 Resources에서 찾으므로 이름/경로 유지.

```
VanguardDuelSelectPopup (루트, ▶ VanguardDuelSelectPopup.cs, VanguardPopupBase)
├─ Dim
├─ Window
│  ├─ Header
│  │  ├─ TitleText ("상대를 선택하세요")              → _titleText
│  │  ├─ SubTitleText ("스파크 프로젝트: 뱅가드")       → _subTitleText
│  │  ├─ SeasonTimerText ("45:18:11")                 → _seasonTimerText
│  │  ├─ Btn_Back (돌아가기)                           → _closeButton (Base)
│  │  ├─ MyTierBadge (골드3 III)                       → _myTierBadge / _myTierName
│  │  └─ Btn_Forfeit ("포기")                          → _forfeitButton
│  │
│  ├─ MyPowerBar ("내 전투력")
│  │  ├─ AttackText (◆ 240)                            → _myAttackText
│  │  └─ ChipCountText (⚙ 42)                          → _myChipCountText
│  │
│  ├─ OpponentList (VerticalLayoutGroup, 3행)
│  │  └─ [VanguardDuelOpponentSlot x3]                 → _opponentSlots[3] (또는 _slotPrefab+_listParent)
│  │     ├─ Profile (Image) + Frame (Image)            → _profileIcon / _profileFrame
│  │     ├─ NameText + LeagueIcon                       → _userName
│  │     ├─ TierBadge + TierName (골드3 III)            → _tierBadge / _tierName
│  │     ├─ MedalCount (◇ x2)                           → _medalCountText
│  │     ├─ AttackText (◆ 260)                          → _attackText
│  │     ├─ ChipCountText (⚙ 32)                        → _chipCountText
│  │     ├─ Btn_Challenge ("도전")                      → _challengeButton
│  │     └─ WinInfo ("승리: +100" + "x2")               → _winPointText / _doublePointBadge
│  │
│  ├─ BonusNotice ("승리 시 포인트 2배 + 스페셜 열쇠 1") → _bonusNoticeText (+ ItemDisplayComponent 선택)
│  ├─ CurrencyText (회색 ◆ 240, 보유 Standard DS)        → _currencyText
│  └─ Btn_Refresh ("🎥 새로고침")                        → _refreshButton
```

- 후보 3행: **고정 3슬롯 배열**(`_opponentSlots[3]`) 권장(항상 3개, 풀링 불필요). 새로고침 시 각 슬롯 `Bind` 재호출.
- 시즌 타이머: `VanguardLobbyPanel`의 `SeasonTimerLoopAsync` 패턴 복제(CancellationToken, `Closed`에서 취소).

---

## 6. 스크립트 설계

### 6-1. 데이터 모델 + Provider (신규)

```csharp
using System;
using System.Collections.Generic;
using Cysharp.Threading.Tasks;

/// <summary> 듀얼 후보 1명 (서버 제공). 클론 replay는 도전 확정 시 별도 다운로드(인게임 문서). </summary>
public class VanguardDuelOpponent
{
    public string userId;
    public string nickName;
    public int    profileIcon;
    public int    profileFrame;
    public int    appliedPassType;   // 닉 컬러
    public EVanguardTier tier;
    public int    attack;            // 공격력 ◆
    public int    chipCount;         // 칩 수 ⚙
    public int    winPoint;          // 승리 시 획득 포인트 (상대 랭크 보정)
    public int    medalCount;        // ◇ 표기 (의미 §10)
}

/// <summary> 듀얼 후보 제공/도전/새로고침/포기. 서버(VanguardServerService) 미구현 단계는 Stub. </summary>
public interface IVanguardDuelProvider
{
    int MyAttack { get; }
    int MyChipCount { get; }
    EVanguardTier MyTier { get; }
    int DualTokenCount { get; }

    UniTask<List<VanguardDuelOpponent>> RequestChoicesAsync();  // 3명
    UniTask<bool> RefreshChoicesAsync(out int cost);            // 새로고침(정책에 따라 무료/유료)
    UniTask<bool> ForfeitAsync();                               // 포기(토큰 폐기/취소 — 미소모 가능)
    UniTask<VanguardMatchData> ChallengeAsync(VanguardDuelOpponent opp); // 도전: 토큰 소모 + 클론 다운로드
}
```

### 6-2. `VanguardDuelSelectPopup.cs` (참조 구현)

```csharp
using System.Collections.Generic;
using System.Threading;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary> Vanguard 듀얼 후보 선택 팝업. 후보 3명 중 1명에 도전 / 새로고침 / 포기. </summary>
public class VanguardDuelSelectPopup : VanguardPopupBase
{
    #region Serialized
    [Header("Header")]
    [SerializeField] private TextMeshProUGUI _titleText;
    [SerializeField] private TextMeshProUGUI _subTitleText;
    [SerializeField] private TextMeshProUGUI _seasonTimerText;
    [SerializeField] private Image _myTierBadge;
    [SerializeField] private TextMeshProUGUI _myTierName;
    [SerializeField] private Button _forfeitButton;

    [Header("My Power")]
    [SerializeField] private TextMeshProUGUI _myAttackText;
    [SerializeField] private TextMeshProUGUI _myChipCountText;

    [Header("Opponents (3)")]
    [SerializeField] private VanguardDuelOpponentSlot[] _opponentSlots; // 길이 3

    [Header("Bottom")]
    [SerializeField] private TextMeshProUGUI _bonusNoticeText;
    [SerializeField] private TextMeshProUGUI _currencyText;
    [SerializeField] private Button _refreshButton;

    [Header("[TEST]")]
    [SerializeField] private bool _useStub = true;
    #endregion

    private VanguardManager _vanguardManager;
    private CurrencyManager _currencyManager;
    private IVanguardDuelProvider _provider;
    private CancellationTokenSource _timerCts;
    private bool _bound;

    protected override void Awake()
    {
        base.Awake(); // uiPosition=Popup, _closeButton(돌아가기) 바인딩
        if (_bound) return;
        _bound = true;
        _forfeitButton.onClick.AddListener(OnClickForfeit);
        _refreshButton.onClick.AddListener(OnClickRefresh);
    }

    public override void Opened(params object[] param)
    {
        base.Opened(param);
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();
        _currencyManager = Managers.Instance.GetManager<CurrencyManager>();
        _provider = _useStub ? new VanguardDuelProviderStub()
                             : _vanguardManager?.DuelProvider; // TODO: VanguardServerService 연결

        if (_titleText != null) _titleText.text = LocalizationManager.GetLocalizedText("vanguard_duel_select_title");
        if (_subTitleText != null) _subTitleText.text = LocalizationManager.GetLocalizedText("vanguard_title");
        if (_bonusNoticeText != null) _bonusNoticeText.text = LocalizationManager.GetLocalizedText("vanguard_duel_bonus_notice");

        RefreshMyInfo();
        StartSeasonTimer();
        LoadChoicesAsync().Forget();

        for (int i = 0; i < _opponentSlots.Length; i++)
        {
            var slot = _opponentSlots[i];
            if (slot != null) slot.OnChallenge = (opp) => ChallengeAsync(opp).Forget();
        }
    }

    protected override void ClosePopup() { StopSeasonTimer(); base.ClosePopup(); }

    private void RefreshMyInfo()
    {
        if (_provider == null) return;
        if (_myAttackText != null) _myAttackText.text = _provider.MyAttack.ToString();
        if (_myChipCountText != null) _myChipCountText.text = _provider.MyChipCount.ToString();
        if (_myTierBadge != null) _myTierBadge.sprite = VanguardTierUtil.GetTierSprite(_provider.MyTier);
        if (_myTierName != null) _myTierName.text = VanguardTierUtil.GetDisplayName(_provider.MyTier);
        if (_currencyText != null) _currencyText.text =
            _currencyManager.GetCurrency(ECurrencyType.VanguardStandardDS).ToString();
    }

    private async UniTaskVoid LoadChoicesAsync()
    {
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        List<VanguardDuelOpponent> choices = null;
        try { choices = await _provider.RequestChoicesAsync(); }
        finally { ServerLoadingPopupUI.Hide(); }

        for (int i = 0; i < _opponentSlots.Length; i++)
        {
            bool has = choices != null && i < choices.Count;
            _opponentSlots[i].gameObject.SetActive(has);
            if (has) _opponentSlots[i].Bind(choices[i]);
        }
    }

    private void OnClickRefresh() => RefreshChoicesAsync().Forget();
    private async UniTaskVoid RefreshChoicesAsync()
    {
        // 새로고침 정책(무료/유료)은 §7. 유료면 비용 확인 후.
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        try { await _provider.RefreshChoicesAsync(out _); }
        finally { ServerLoadingPopupUI.Hide(); }
        LoadChoicesAsync().Forget();
    }

    private void OnClickForfeit() => ForfeitAsync().Forget();
    private async UniTaskVoid ForfeitAsync()
    {
        // 위키: 상대 못 찾으면 토큰 미소모. 포기는 확인 팝업 후 처리 권장.
        await _provider.ForfeitAsync();
        _uiManager?.Hide(this);
    }

    private async UniTaskVoid ChallengeAsync(VanguardDuelOpponent opp)
    {
        if (opp == null) return;
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("vanguard_matching"));
        VanguardMatchData match = null;
        try { match = await _provider.ChallengeAsync(opp); } // 토큰 소모 + 클론 다운로드
        finally { ServerLoadingPopupUI.Hide(); }

        if (match == null) { ToastManager.ShowToast(LocalizationManager.GetLocalizedText("vanguard_match_failed")); return; }

        _uiManager?.Hide(this);
        // 인게임 진입 (인게임 문서): GameScene 로드 → VanguardStagePlayService가 VanguardBattleUI 표시
        var sceneManager = Managers.Instance.GetManager<SceneManager>();
        sceneManager.LoadGameSceneAsync(GameModeType.Vanguard, match.stageId).Forget();
    }

    // 시즌 타이머 (VanguardLobbyPanel.SeasonTimerLoopAsync 복제)
    private void StartSeasonTimer() { /* ServerTimeManager 기반 1초 루프 → _seasonTimerText */ }
    private void StopSeasonTimer() { _timerCts?.Cancel(); _timerCts?.Dispose(); _timerCts = null; }
}
```

### 6-3. `VanguardDuelOpponentSlot.cs` (신규 — 후보 1행)

```csharp
using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary> 듀얼 후보 1행. 프로필/티어/공격력/칩수/승리포인트/도전. </summary>
public class VanguardDuelOpponentSlot : MonoBehaviour
{
    [SerializeField] private Image _profileIcon;
    [SerializeField] private Image _profileFrame;
    [SerializeField] private TextMeshProUGUI _userName;
    [SerializeField] private Image _tierBadge;
    [SerializeField] private TextMeshProUGUI _tierName;
    [SerializeField] private TextMeshProUGUI _medalCountText;
    [SerializeField] private TextMeshProUGUI _attackText;
    [SerializeField] private TextMeshProUGUI _chipCountText;
    [SerializeField] private TextMeshProUGUI _winPointText;
    [SerializeField] private GameObject _doublePointBadge; // "x2"
    [SerializeField] private Button _challengeButton;

    public Action<VanguardDuelOpponent> OnChallenge;
    private VanguardDuelOpponent _data;

    private void Awake() => _challengeButton.onClick.AddListener(() => OnChallenge?.Invoke(_data));

    public void Bind(VanguardDuelOpponent o)
    {
        _data = o;
        if (_userName != null) { _userName.text = o.nickName; TextUtility.ApplyNicknameColor(_userName, o.appliedPassType); }
        if (_tierBadge != null) _tierBadge.sprite = VanguardTierUtil.GetTierSprite(o.tier);
        if (_tierName != null) _tierName.text = VanguardTierUtil.GetDisplayName(o.tier);
        if (_attackText != null) _attackText.text = o.attack.ToString();
        if (_chipCountText != null) _chipCountText.text = o.chipCount.ToString();
        if (_medalCountText != null) _medalCountText.text = $"x{o.medalCount}";
        if (_winPointText != null) _winPointText.text =
            LocalizationManager.GetLocalizedTextFormat("vanguard_duel_win_point", o.winPoint); // "승리: +{0}"
        if (_doublePointBadge != null) _doublePointBadge.SetActive(true); // 듀얼 항상 2배

        // 프로필/프레임 로드: RankingDisplaySlot 공통 경로 재사용 (ResourceManager/ContentUnlock)
        // ProfileIconLoader.LoadIconAsync(o.profileIcon, _profileIcon).Forget();
        // ProfileIconLoader.LoadFrameAsync(o.profileFrame, _profileFrame).Forget();
    }
}
```

> 프로필 아이콘/프레임 로드는 `RankingDisplaySlot.LoadProfileIconAsync/LoadProfileFrameAsync`가 쓰는 동일 소스(`ContentUnlockManager`/`ResourceManager`)를 공용 헬퍼로 빼서 재사용(중복 구현 금지). 기존 `VanguardRankingDisplaySlot`이 이미 그 경로를 사용 중.

---

## 7. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 후보 3명(랭크/공격력/칩수/승리포인트) | ⚠️ 서버 API 미구현 | `VanguardServerService.RequestDuelChoicesAsync()`(신규). 미구현 단계 `VanguardDuelProviderStub` 더미 |
| 내 공격력/칩수 | 부분 | `VanguardLoadoutService`(공격력=요새 업글+칩) / `VanguardChipService`(칩수). 임시 캐시 |
| 토큰 소모 시점 | 정책 | **도전 확정 시 소모**(서버). 포기/취소/상대없음 = 미소모(위키 패치 f) |
| 새로고침 비용 | ⚠️ 미정 | 위키 명시 없음 → 1차 **무료**(또는 토큰?) 가정, §10 확인 |
| 승리 포인트 산출 | 서버 | 상대 랭크 보정(위키). 후보마다 다름 |
| 메달 ◇ `x2` 의미 | ⚠️ 불명 | §10 확인. 우선 `medalCount` 필드로 표기만 |
| 도전 → 전투 | 인게임 문서 | `FindMatchAsync(Duel)`+클론 → `LoadGameSceneAsync(Vanguard)` → `VanguardBattleUI` |

### CLAUDE.md 준수
- 매니저 `GetManager<T>()` / 서버콜 `ServerLoadingPopupUI.Show~finally Hide` / `async void` 금지(`UniTaskVoid`) / 텍스트 로컬라이즈 / 시간 `ServerTimeManager` / 매직넘버 const·Provider.

---

## 8. 단계별 구현 절차 (체크리스트)

**A. 데이터**

1. [ ] `VanguardDuelOpponent` 모델 + `IVanguardDuelProvider` + `VanguardDuelProviderStub` 작성.
2. [ ] (정식) `VanguardServerService.RequestDuelChoicesAsync/Refresh/Challenge/Forfeit` + `VanguardManager.DuelProvider` 노출.

**B. 스크립트**

3. [ ] `VanguardDuelOpponentSlot.cs` 작성(6-3).
4. [ ] `VanguardDuelSelectPopup.cs` 본문 채움(6-2). 빌드-그린.
5. [ ] 프로필 로드 공용 헬퍼 정리(RankingDisplaySlot 경로 공유).

**C. 프리팹** (`VanguardDuelSelectPopup.prefab` 편집)

6. [ ] 5장 하이어라키 구성: Header / MyPowerBar / OpponentList(3) / Bottom.
7. [ ] 후보 행 프리팹 `VanguardDuelOpponentSlot` 1개 제작 → Window에 3개 배치 → `_opponentSlots[3]`.
8. [ ] 버튼 연결: `_closeButton`(돌아가기)/`_forfeitButton`/`_refreshButton`/각 행 `_challengeButton`.
9. [ ] 텍스트/뱃지 연결: 타이틀/서브/시즌타이머/내 티어·공격력·칩수/하단 보너스·재화.
10. [ ] `_useStub=true`로 에디터 플레이 테스트(후보 3명 더미 표시/새로고침/도전 토스트).

**D. 연동**

11. [ ] `VanguardLobbyPanel.OnClickDuel`에 토큰 보유 확인 추가(토큰 부족 시 토스트/상점).
12. [ ] `도전` → `FindMatchAsync(Duel)` + `LoadGameSceneAsync` 연결(인게임 문서).
13. [ ] Localization 키: `vanguard_duel_select_title`/`vanguard_duel_bonus_notice`/`vanguard_duel_win_point`/`vanguard_matching`/`vanguard_match_failed`.

---

## 9. 검증 체크리스트

- [ ] 토큰 충분 시 Duel → 팝업 오픈, 후보 3명(프로필/티어/공격력/칩수/승리포인트) 표시.
- [ ] 내 전투력(공격력◆/칩수⚙) + 내 티어 뱃지 + 시즌타이머 표시.
- [ ] `도전` → 매칭 로딩 → 클론 확보 시 GameScene 진입(`VanguardBattleUI`), 실패 시 토스트.
- [ ] `새로고침` → 후보 3명 재요청·갱신.
- [ ] `포기` → 토큰 폐기/취소(상대 없으면 미소모) + 팝업 닫힘.
- [ ] `돌아가기`(Base 닫기) → 팝업 닫힘, 시즌타이머 취소.
- [ ] 하단 보너스 안내(승리 2배 + Special 열쇠) 표기.
- [ ] 새로고침/도전 중복 클릭 방지(로딩 가드).
- [ ] CLAUDE.md 준수(GetManager/UniTask/로컬라이즈/ServerTime/매직넘버 없음).

---

## 10. 미해결 / 확인 필요

**위키로 확정**

- [x] 후보 3명 + 각 랭크/공격력/칩수/승리포인트. 새로고침·포기. 승리 2배 포인트 + Special 열쇠. 취소 시 토큰 미소모.

**확인 필요**

- [ ] **메달 ◇ `x2` 의미**: 승점 배수/메달 수/연승 — 위키 미표기. 실게임 확인 후 `medalCount` 소스 연결.
- [ ] **새로고침 비용/제한**: 무료 무제한 vs 횟수 제한 vs 토큰 — 기획 확정.
- [ ] **포기 확인 UX**: 토큰 폐기 확인 팝업 필요 여부.
- [ ] **듀얼 후보 풀**: 봇 클론 시드 포함 여부([[2026-05-29_vanguard-implementation-plan-ingame]] 6장 봇 클론).
- [ ] **하단 회색 ◆240**: 보유 Standard DS 표기인지 다른 값인지 — 실게임 확인.
- [ ] **서버 API 스키마**: 후보/도전/포기 응답 → [[2026-05-31_vanguard-server-api-spec]] 동기화.

---

> 작성: 2026-06-03 · 선행 코드 확인: `VanguardDuelSelectPopup`(스켈레톤)/`VanguardPopupBase`/`VanguardRankingDisplaySlot`(프로필·티어 로직)/`VanguardTierUtil`/`ItemDisplayComponent`/`VanguardLobbyPanel`(Duel 진입·시즌타이머·토큰표기). 위키 V0.13.7 "Dual Token Info"(후보3/공격력·칩수/승리포인트/새로고침/포기/2배·Special열쇠/취소 미소모) 반영. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
