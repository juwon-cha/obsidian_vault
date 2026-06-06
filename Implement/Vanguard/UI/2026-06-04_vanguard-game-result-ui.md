# Vanguard 전투 결과 UI(VanguardGameResultUI) 구현 종합 문서 (2026-06-04)

## 문서 목적

매치/듀얼 전투 종료 직후 뜨는 **전투 결과 화면**(첨부 이미지: Defeat + 0:3 + Rewards Obtained + 양 플레이어 정보 + 라운드별 피해량 스크롤 + Back)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다. **이미지와 최대한 동일한 형태**가 목표.

- 참조 구현(사용자 지정): **`ArkGameResultUI`** — `Show<T>(GameResultData)` 진입, `Time.timeScale=0`, ItemScrollView(보상)/UnitStatScrollView(통계)/순차 등장 연출이 완성돼 있어 골격을 그대로 미러.
- 사용자 방침(확정):
  - **Rewards Obtained = `ItemScrollView`(`_itemScrollContent`+`_itemDisplayPrefab`) 그대로 재활용**.
  - **각 라운드 피해량 = 신규 프리팹**으로 만들어 **`UnitStatScrollView`의 Content**에 배치.
  - **ItemScrollView와 UnitStatScrollView 사이에 플레이어 정보 패널** 1개 추가(양 플레이어 표시).
- 짝 문서: [[2026-06-03_vanguard-ingame-battle-ui]](전투/녹화 데이터 출처), [[2026-06-04_vanguard-tier-progress-popup-ui]](티어 헬퍼 공유), [[2026-06-03_vanguard-duel-matching-popup-ui]](듀얼 보상=Special DS 100)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 신규 클래스 | `VanguardGameResultUI : UIBase` (ArkGameResultUI 미러) |
| 신규 컴포넌트 | `VanguardRoundStatBlock`(라운드 1블록) · `VanguardTurretDmgRow`(터렛 1행) · `VanguardResultPlayerInfo`(플레이어 정보 1명) |
| 신규 프리팹 | `VanguardGameResultUI.prefab`(루트) · `VanguardRoundStatBlock.prefab` · `VanguardTurretDmgRow.prefab` |
| 재활용 | **ItemScrollView**(`_itemScrollContent`+`ItemDisplayComponent`) · **UnitStatScrollView**(`_unitStatsScrollContent` → 라운드 블록 컨테이너로 용도 변경) · `VanguardTierUtil`/`VanguardTierMath`(티어 뱃지/디비전) · ArkGameResultUI 연출 시퀀스 |
| 데이터 | 신규 `VanguardGameResultData`(score/양 플레이어 요약/라운드 리스트/보상/Extra Rewards) — ingame 녹화/결과에서 구성 |
| 진입 | 전투 종료 → `Show<VanguardGameResultUI>(VanguardGameResultData)` (`VanguardStagePlayService` 결과 콜백) |
| 출구 | 단일 **Back** 버튼 → 로비(`LoadLobbySceneAsync` 또는 Vanguard 로비 복귀) |
| 부가 버튼 | Card Info(좌상단, 카드/칩 보기) · Discord(우상단, 외부 링크) |

---

## 1. 진입 / 출구 플로우

```
전투 종료 (VanguardStagePlayService.OnBattleEnd → result 콜백, ingame §10)
  └─ Show<VanguardGameResultUI>(VanguardGameResultData)   // Time.timeScale=0, 승패 SFX
       ├─ Rewards Obtained / Player Info / Round 스크롤 표시 + 순차 등장 연출
       ├─ [Card Info] → 이번 매치 카드/칩 보기 (VanguardInfoPopup 또는 Overview)
       ├─ [Discord] → 외부 링크 (Application.OpenURL — 외부 이동 확인 필요)
       └─ [Back] → 로비 복귀
            └─ (티어 변동 있으면 로비에서 VanguardTierProgressPopup 연계 — 별도 문서)
```

> ArkGameResultUI는 `Opened(param[0] is GameResultData)`로 받음 → Vanguard는 `param[0] is VanguardGameResultData`. `Time.timeScale=0f`(일시정지) + `Closed`에서 `GameSpeedConstants.RestoreTimeScale()`는 동일.
> 결과 화면은 승/패 모두 노출(듀얼은 승패 무관 보상 — 위키). 패배(스샷)도 Rewards Obtained 표시됨.

---

## 2. 이미지 상세 분석 (위→아래)

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 결과 타이틀 | `Defeat`(명판) | `_resultTitleText`(Victory/Defeat) + `_successOverlay`/`_failureOverlay` (Ark 재사용) |
| B | 서브타이틀 | `Project Ember` | `_subTitleText`(로컬라이즈, KR=스파크) |
| C | 스코어 | `0 : 3` | `_scoreText`(self:opponent 라운드 승수) |
| D | Card Info | 좌상단 카드 아이콘 버튼 | `_cardInfoButton` → 카드/칩 보기 |
| E | Discord | 우상단 Discord 버튼 | `_discordButton` → 외부 링크 |
| F | Rewards Obtained | 라벨 + 아이콘 3(100·120·1) | **ItemScrollView 재활용**: `_itemScrollContent`+`_itemDisplayPrefab` |
| G | Extra Rewards | `Extra Rewards: 15/20` 바 | `_extraRewardText`(+선택 게이지) |
| H | **플레이어 정보 패널** | 좌(teal) TopTap_on_YT / 우(red) A_Cat | **신규 패널**: `_selfPlayerInfo`/`_opponentPlayerInfo` (`VanguardResultPlayerInfo`) |
| H-1 | 플레이어 1명 | 아바타 · ◆`200` ⚙`34` · `II Silver 2` · ◇`x1` · 우상단 원형 아이콘 | `VanguardResultPlayerInfo` 필드들 |
| I | **라운드 블록 ×N** | `Round 1 Defeat` + 양측 DMG + 터렛 3행 | **신규 `VanguardRoundStatBlock`** → `_roundScrollContent`(=UnitStatScrollView Content) |
| I-1 | 터렛 1행 | 아이콘 + 레벨원 `1` + `292.71k` | **신규 `VanguardTurretDmgRow`** |
| J | Back | 하단 청록 `Back` | `_backButton` |

### 플레이어 정보 패널(H) 세부 — 좌/우 대칭

```
[아바타]  이름(TopTap_on_YT)        ◆ 200   ⚙ 34   (우상단 원형 아이콘)
          [티어뱃지 II] Silver 2   ◇ x1
```
- 좌=self(teal 톤), 우=opponent(red 톤). ◆=공격력, ⚙=칩 수(듀얼 매칭 팝업과 동일 데이터). ◇=메달 수.

### 라운드 블록(I) 세부 — 한 블록에 양측 동시

```
──────── Round 1   [Defeat](라운드 결과 태그) ────────
 DMG  666.43k                    │  DMG  430.85k
 Turret            DMG           │  Turret            DMG
 [🔫] (1)  292.71k               │  [🔫] (1)  169.69k
 [🔫] (1)  248.43k               │  [🔫] (1)  167.02k
 [🔫] (1)  125.29k               │  [🔫] (1)   94.13k
```
- 좌 컬럼=self, 우 컬럼=opponent. 각 컬럼: 총 DMG + 헤더("Turret/DMG") + 터렛 행 N개(스샷=3). 라운드 결과 태그(Defeat/Victory)는 각 블록 헤더 우측.

---

## 3. 재사용 자산 분석 (ArkGameResultUI 매핑)

| Ark (`UI/ArkGameResultUI.cs` — 실코드 검증) | Vanguard 대응 | 비고 |
|---|---|---|
| `Awake`: `uiPosition=Popup` + `SetupButtons` + `InitializeUI` | 동일 | |
| `Opened`: `Time.timeScale=0f` + `Show<T>(GameResultData)` + 승패 SFX(`VictoryResult`/`DefeatResult`) | 동일(`VanguardGameResultData`) | |
| `Closed`: `RestoreTimeScale` + cleanup | 동일 | `_pauseForGacha` 분기는 불필요(제거) |
| **ItemScrollView**: `_itemScrollContent`+`_itemDisplayPrefab`+`CreateItemDisplay`(`ItemDisplayComponent.SetupItem/SetShowDetailPopup/SetInteractable`) | **그대로** (Rewards Obtained) | 2배 보상 오버레이(`SetDoubleRewardDisplay`)도 그대로 사용 가능 |
| **UnitStatScrollView**: `_unitStatsScrollContent`+`_unitStatsDisplayPrefab`+`CreateUnitStatsDisplayComponent` | **컨테이너만 재활용** → `_roundScrollContent`에 `VanguardRoundStatBlock` 생성 | 유닛별 행 대신 **라운드 블록** |
| 연출: `ShowResultAnimation`(배경 페이드→오버레이+타이틀→패널 페이드→아이템 순차→스탯 순차→버튼) | **구조 복제** + 플레이어 패널 단계 추가 | `ShowItemsSequentiallyAsync`/`ShowUnitStatsSequentiallyAsync` 패턴 재사용 |
| 버튼: `_confirmButton`/`_returnButton`(자동모드/다음스테이지) | **단일 `_backButton`** 으로 단순화 | 자동모드/가챠/카운트다운 전부 제거 |
| `SetInitialAnimationState`/`ShowResultOverlayWithTextAnimation` | 복제(스코어/서브타이틀 추가) | |

| 기타 재사용 | 경로 | 용도 |
|---|---|---|
| `ItemDisplayComponent` | `UI/Components/` | 보상 아이콘+수량 |
| `VanguardTierUtil` / `VanguardTierMath` | `UI/Vanguard/` | 플레이어 패널 티어 뱃지/이름/디비전 로마자 |
| `UnitIconUtil`/`CardVisualConfig` 등 아이콘 경로 | (터렛 아이콘) | `VanguardTurretDmgRow` 아이콘 — 터렛 UI 문서(`TurretDataSO.spritePath`)와 동일 경로 |

### 가져오지 않는 것 (Ark에서 제거)

- ❌ 가챠 플로우(`HandleGachaFlow`/`_pauseForGacha`/`ArkShopPopup`), 자동 모드(토글/카운트다운), 다음 스테이지(`HandleNextStage`), 기지 체력 텍스트, 스테이지 보상 지급(`GrantStageRewards` — Vanguard 보상은 서버 권위로 별도).

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> 신규 `VanguardGameResultUI.prefab`(`Resources_moved/UI/`). 루트 `VanguardGameResultUI.cs`, `uiPosition=Popup`.

```
VanguardGameResultUI (루트, ▶ VanguardGameResultUI.cs)
├─ Background (CanvasGroup, 어두운 전장 배경)            → _backgroundCanvasGroup
├─ ResultPanel (CanvasGroup)                            → _resultPanel / _resultPanelCanvasGroup
│  ├─ Header
│  │  ├─ SuccessOverlay / FailureOverlay                → _successOverlay / _failureOverlay
│  │  ├─ ResultTitleText ("Defeat"/"Victory")           → _resultTitleText
│  │  ├─ SubTitleText ("Project Ember")                 → _subTitleText
│  │  ├─ ScoreText ("0 : 3")                            → _scoreText
│  │  ├─ Btn_CardInfo (좌상단)                          → _cardInfoButton
│  │  └─ Btn_Discord (우상단)                           → _discordButton
│  │
│  ├─ RewardsSection
│  │  ├─ Label ("Rewards Obtained")
│  │  ├─ ItemScrollView (ScrollRect)                    → (재활용)
│  │  │  └─ Viewport/Content                            → _itemScrollContent
│  │  │     └─ (런타임) ItemDisplayComponent xN          → _itemDisplayPrefab
│  │  └─ ExtraRewardText ("Extra Rewards: 15/20")       → _extraRewardText (+_extraRewardGauge 선택)
│  │
│  ├─ PlayerInfoPanel (신규, ItemScrollView와 RoundScroll 사이)
│  │  ├─ SelfInfo  [VanguardResultPlayerInfo] (teal)    → _selfPlayerInfo
│  │  └─ OpponentInfo [VanguardResultPlayerInfo] (red)  → _opponentPlayerInfo
│  │
│  ├─ UnitStatScrollView (ScrollRect, 세로)             → (재활용 컨테이너)
│  │  └─ Viewport/Content (VerticalLayoutGroup+SizeFitter) → _roundScrollContent
│  │     └─ (런타임) VanguardRoundStatBlock xN           → _roundStatBlockPrefab
│  │
│  └─ Btn_Back ("Back")                                 → _backButton
```

### 4-1. 신규 프리팹: `VanguardResultPlayerInfo` (패널 1명)

```
VanguardResultPlayerInfo (▶ VanguardResultPlayerInfo.cs)
├─ ProfileIcon (Image) + Frame                          → _profileIcon / _profileFrame
├─ NameText                                             → _nameText
├─ AttackText (◆)                                       → _attackText
├─ ChipCountText (⚙)                                    → _chipCountText
├─ TierBadge (Image) + DivisionText + TierNameText      → _tierBadge / _divisionText / _tierNameText
├─ MedalCountText (◇ "x1")                              → _medalCountText
└─ CornerIcon (우상단 원형, 선택)                        → _cornerIcon
```

### 4-2. 신규 프리팹: `VanguardRoundStatBlock` (라운드 1블록)

```
VanguardRoundStatBlock (▶ VanguardRoundStatBlock.cs, CanvasGroup)
├─ Header
│  ├─ RoundLabel ("Round 1")                            → _roundLabelText
│  └─ ResultTag ("Defeat"/"Victory")                    → _resultTagText
├─ SelfColumn
│  ├─ TotalDmgText ("666.43k")                          → _selfTotalDmgText
│  ├─ SubHeader ("Turret" / "DMG")
│  └─ TurretRows (VerticalLayoutGroup)                  → _selfTurretRowParent
│     └─ (런타임) VanguardTurretDmgRow xN                → _turretDmgRowPrefab
└─ OpponentColumn
   ├─ TotalDmgText ("430.85k")                          → _opponentTotalDmgText
   ├─ SubHeader
   └─ TurretRows                                        → _opponentTurretRowParent
```

### 4-3. 신규 프리팹: `VanguardTurretDmgRow` (터렛 1행)

```
VanguardTurretDmgRow (▶ VanguardTurretDmgRow.cs)
├─ TurretIcon (Image)                                   → _icon
├─ LevelBadge → LevelText ("1")                         → _levelText
└─ DmgText ("292.71k")                                  → _dmgText
```

---

## 5. 스크립트 설계

### 5-1. 데이터 모델

```csharp
using System.Collections.Generic;

public class VanguardTurretDmgEntry
{
    public int turretId;
    public int level;
    public double damage;       // 원시값 (표기는 k/m 포맷)
}

public class VanguardRoundResult
{
    public int roundNumber;     // 1,2,3...
    public bool selfWon;        // 라운드 결과 (태그 Victory/Defeat)
    public double selfTotalDmg;
    public double opponentTotalDmg;
    public List<VanguardTurretDmgEntry> selfTurrets;      // 3개
    public List<VanguardTurretDmgEntry> opponentTurrets;  // 3개
}

public class VanguardPlayerSummary
{
    public string nickName;
    public int profileIcon, profileFrame, appliedPassType;
    public int attack;          // ◆
    public int chipCount;       // ⚙
    public EVanguardTier tier;
    public int medalCount;      // ◇
}

/// <summary> Vanguard 전투 결과 — VanguardStagePlayService 결과 + 녹화 통계로 구성. </summary>
public class VanguardGameResultData
{
    public bool isWin;
    public int selfScore, opponentScore;                  // "0 : 3"
    public VanguardPlayerSummary self;
    public VanguardPlayerSummary opponent;
    public List<(ECurrencyType type, int amount)> rewards; // Rewards Obtained
    public int extraRewardCurrent, extraRewardMax;         // 15/20
    public List<VanguardRoundResult> rounds;
}
```

### 5-2. `VanguardGameResultUI.cs` (참조 구현, ArkGameResultUI 미러)

```csharp
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 전투 결과 UI. Rewards(ItemScrollView 재활용) + 플레이어 정보 패널 + 라운드별 피해량 스크롤.
/// ArkGameResultUI 골격 미러(Time.timeScale=0 / 순차 등장 연출). 출구는 단일 Back.
/// </summary>
public class VanguardGameResultUI : UIBase
{
    #region Serialized
    [Header("배경/패널")]
    [SerializeField] private GameObject _resultPanel;
    [SerializeField] private CanvasGroup _backgroundCanvasGroup;
    [SerializeField] private CanvasGroup _resultPanelCanvasGroup;

    [Header("헤더")]
    [SerializeField] private GameObject _successOverlay;
    [SerializeField] private GameObject _failureOverlay;
    [SerializeField] private TextMeshProUGUI _resultTitleText;
    [SerializeField] private TextMeshProUGUI _subTitleText;
    [SerializeField] private TextMeshProUGUI _scoreText;
    [SerializeField] private Button _cardInfoButton;
    [SerializeField] private Button _discordButton;

    [Header("Rewards Obtained (ItemScrollView 재활용)")]
    [SerializeField] private Transform _itemScrollContent;
    [SerializeField] private GameObject _itemDisplayPrefab;
    [SerializeField] private TextMeshProUGUI _extraRewardText;

    [Header("플레이어 정보 패널 (신규)")]
    [SerializeField] private VanguardResultPlayerInfo _selfPlayerInfo;
    [SerializeField] private VanguardResultPlayerInfo _opponentPlayerInfo;

    [Header("라운드 스크롤 (UnitStatScrollView 재활용)")]
    [SerializeField] private Transform _roundScrollContent;
    [SerializeField] private VanguardRoundStatBlock _roundStatBlockPrefab;

    [Header("버튼")]
    [SerializeField] private Button _backButton;

    [Header("연출")]
    [SerializeField] private float _animationDuration = 0.25f;
    [SerializeField] private string _discordUrl = "https://discord.gg/..."; // [설계 판단] 실제 URL 주입
    #endregion

    private VanguardGameResultData _data;
    private readonly List<GameObject> _rewardItems = new();
    private readonly List<GameObject> _roundBlocks = new();
    private Sequence _showSequence;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _backButton.onClick.AddListener(OnClickBack);
        _cardInfoButton?.onClick.AddListener(OnClickCardInfo);
        _discordButton?.onClick.AddListener(OnClickDiscord);
        InitializeUI();
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        Time.timeScale = 0f;

        if (param != null && param.Length > 0 && param[0] is VanguardGameResultData data)
        {
            _data = data;
            ShowGameResult();
            AudioUtils.PlaySFXUnscaled(data.isWin ? "VictoryResult" : "DefeatResult").Forget();
        }
        else { RLog.LogError("[VanguardGameResultUI] 결과 데이터 없음"); Closed(null); }
    }

    public override void Closed(object[] param)
    {
        _showSequence?.Kill();
        ClearList(_rewardItems);
        ClearList(_roundBlocks);
        GameSpeedConstants.RestoreTimeScale();
        base.Closed(param);
    }

    private void OnDestroy() { _showSequence?.Kill(); DOTween.Kill(this); }

    private void InitializeUI()
    {
        _resultPanel?.SetActive(false);
        if (_backgroundCanvasGroup != null) _backgroundCanvasGroup.alpha = 0f;
        if (_resultPanelCanvasGroup != null) _resultPanelCanvasGroup.alpha = 0f;
        _successOverlay?.SetActive(false);
        _failureOverlay?.SetActive(false);
    }

    // ─────────── 구성 ───────────
    private void ShowGameResult()
    {
        UpdateHeader();
        UpdateRewards();
        UpdatePlayerInfo();
        UpdateRounds();
        ShowResultAnimation();   // ArkGameResultUI.ShowResultAnimation 구조 미러
    }

    private void UpdateHeader()
    {
        if (_resultTitleText != null)
            _resultTitleText.text = LocalizationManager.GetLocalizedText(_data.isWin ? "result_victory" : "result_defeat");
        if (_subTitleText != null) _subTitleText.text = LocalizationManager.GetLocalizedText("vanguard_title_sub");
        if (_scoreText != null) _scoreText.text = $"{_data.selfScore} : {_data.opponentScore}";
    }

    private void UpdateRewards()
    {
        ClearList(_rewardItems);
        foreach (Transform c in _itemScrollContent) Destroy(c.gameObject);
        if (_data.rewards != null)
        {
            foreach (var (type, amount) in _data.rewards)
            {
                if (amount <= 0) continue;
                var go = Instantiate(_itemDisplayPrefab, _itemScrollContent);
                var item = go.GetComponent<ItemDisplayComponent>();
                item.SetupItem(type, amount);
                item.SetShowDetailPopup(true);
                item.SetInteractable(true);
                go.transform.localScale = Vector3.zero; // 순차 등장 초기 상태
                _rewardItems.Add(go);
            }
        }
        if (_extraRewardText != null)
            _extraRewardText.text = LocalizationManager.GetLocalizedTextFormat(
                "vanguard_extra_rewards", _data.extraRewardCurrent, _data.extraRewardMax);
    }

    private void UpdatePlayerInfo()
    {
        _selfPlayerInfo?.Bind(_data.self, isSelf: true);
        _opponentPlayerInfo?.Bind(_data.opponent, isSelf: false);
    }

    private void UpdateRounds()
    {
        ClearList(_roundBlocks);
        foreach (Transform c in _roundScrollContent) Destroy(c.gameObject);
        if (_data.rounds == null) return;
        foreach (var round in _data.rounds)
        {
            var block = Instantiate(_roundStatBlockPrefab, _roundScrollContent);
            block.Bind(round);
            block.gameObject.transform.localScale = Vector3.zero; // 순차 등장
            _roundBlocks.Add(block.gameObject);
        }
    }

    // ─────────── 연출 (ArkGameResultUI 미러, 단순화) ───────────
    private void ShowResultAnimation()
    {
        _showSequence?.Kill();
        _showSequence = DOTween.Sequence().SetUpdate(true);
        _resultPanel?.SetActive(true);

        if (_backgroundCanvasGroup != null) _showSequence.Append(_backgroundCanvasGroup.DOFade(1f, _animationDuration).SetUpdate(true));
        _showSequence.AppendCallback(() => { (_data.isWin ? _successOverlay : _failureOverlay)?.SetActive(true); });
        if (_resultPanelCanvasGroup != null) _showSequence.Append(_resultPanelCanvasGroup.DOFade(1f, _animationDuration).SetUpdate(true));
        _showSequence.AppendCallback(() => ShowSequentiallyAsync(_rewardItems, 0.1f).Forget());
        _showSequence.AppendInterval(_rewardItems.Count * 0.1f + 0.3f);
        _showSequence.AppendCallback(() => ShowSequentiallyAsync(_roundBlocks, 0.075f).Forget());
    }

    private async UniTaskVoid ShowSequentiallyAsync(List<GameObject> items, float interval)
    {
        foreach (var go in items)
        {
            if (go == null) continue;
            var cg = go.GetComponent<CanvasGroup>() ?? go.AddComponent<CanvasGroup>();
            cg.alpha = 0f;
            var seq = DOTween.Sequence().SetUpdate(true);
            seq.Append(go.transform.DOScale(1f, 0.25f).SetEase(Ease.OutBack).SetUpdate(true));
            seq.Join(cg.DOFade(1f, 0.25f).SetUpdate(true));
            await UniTask.Delay((int)(interval * 1000), DelayType.UnscaledDeltaTime);
        }
    }

    // ─────────── 버튼 ───────────
    private void OnClickBack()
    {
        Closed(null);
        var sceneManager = Managers.Instance.GetManager<SceneManager>();
        sceneManager?.LoadLobbySceneAsync().Forget(); // TODO: Vanguard 로비 복귀 경로 확정
    }

    private void OnClickCardInfo() => Managers.Instance.GetManager<UIManager>()?.Show<VanguardInfoPopup>(); // 또는 매치 카드/칩 Overview
    private void OnClickDiscord() => Application.OpenURL(_discordUrl); // ⚠️ 외부 링크

    private void ClearList(List<GameObject> list)
    {
        foreach (var go in list) if (go != null) Destroy(go);
        list.Clear();
    }
}
```

### 5-3. `VanguardResultPlayerInfo.cs` (신규)

```csharp
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class VanguardResultPlayerInfo : MonoBehaviour
{
    [SerializeField] private Image _profileIcon;
    [SerializeField] private Image _profileFrame;
    [SerializeField] private TextMeshProUGUI _nameText;
    [SerializeField] private TextMeshProUGUI _attackText;
    [SerializeField] private TextMeshProUGUI _chipCountText;
    [SerializeField] private Image _tierBadge;
    [SerializeField] private TextMeshProUGUI _divisionText;
    [SerializeField] private TextMeshProUGUI _tierNameText;
    [SerializeField] private TextMeshProUGUI _medalCountText;

    public void Bind(VanguardPlayerSummary s, bool isSelf)
    {
        if (s == null) return;
        if (_nameText != null) { _nameText.text = s.nickName; TextUtility.ApplyNicknameColor(_nameText, s.appliedPassType); }
        if (_attackText != null) _attackText.text = s.attack.ToString();
        if (_chipCountText != null) _chipCountText.text = s.chipCount.ToString();
        if (_tierBadge != null) _tierBadge.sprite = VanguardTierUtil.GetTierSprite(s.tier);
        if (_tierNameText != null) _tierNameText.text = VanguardTierUtil.GetDisplayName(s.tier);
        if (_divisionText != null) _divisionText.text = VanguardTierMath.GetDivisionRoman(s.tier);
        if (_medalCountText != null) _medalCountText.text = $"x{s.medalCount}";
        // 프로필/프레임 로드: RankingDisplaySlot 공통 경로 헬퍼 재사용
    }
}
```

### 5-4. `VanguardRoundStatBlock.cs` + `VanguardTurretDmgRow.cs` (신규)

```csharp
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class VanguardRoundStatBlock : MonoBehaviour
{
    [SerializeField] private TextMeshProUGUI _roundLabelText;
    [SerializeField] private TextMeshProUGUI _resultTagText;
    [SerializeField] private TextMeshProUGUI _selfTotalDmgText;
    [SerializeField] private TextMeshProUGUI _opponentTotalDmgText;
    [SerializeField] private Transform _selfTurretRowParent;
    [SerializeField] private Transform _opponentTurretRowParent;
    [SerializeField] private VanguardTurretDmgRow _turretDmgRowPrefab;

    public void Bind(VanguardRoundResult r)
    {
        if (_roundLabelText != null)
            _roundLabelText.text = LocalizationManager.GetLocalizedTextFormat("vanguard_round_n", r.roundNumber);
        if (_resultTagText != null)
            _resultTagText.text = LocalizationManager.GetLocalizedText(r.selfWon ? "result_victory" : "result_defeat");
        if (_selfTotalDmgText != null) _selfTotalDmgText.text = NumberFormatUtil.ToShort(r.selfTotalDmg);       // 666.43k
        if (_opponentTotalDmgText != null) _opponentTotalDmgText.text = NumberFormatUtil.ToShort(r.opponentTotalDmg);

        BuildRows(_selfTurretRowParent, r.selfTurrets);
        BuildRows(_opponentTurretRowParent, r.opponentTurrets);
    }

    private void BuildRows(Transform parent, List<VanguardTurretDmgEntry> turrets)
    {
        foreach (Transform c in parent) Destroy(c.gameObject);
        if (turrets == null) return;
        foreach (var t in turrets)
        {
            var row = Instantiate(_turretDmgRowPrefab, parent);
            row.Bind(t);
        }
    }
}
```

```csharp
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class VanguardTurretDmgRow : MonoBehaviour
{
    [SerializeField] private Image _icon;
    [SerializeField] private TextMeshProUGUI _levelText;
    [SerializeField] private TextMeshProUGUI _dmgText;

    public void Bind(VanguardTurretDmgEntry t)
    {
        var rm = Managers.Instance.GetManager<ResourceManager>();
        // 터렛 아이콘: TurretData.spritePath (터렛 UI 문서와 동일 경로)
        // var data = TurretDataLookup(t.turretId); _icon.sprite = rm.LoadResource<Sprite>(data.spritePath);
        if (_levelText != null) _levelText.text = t.level.ToString();
        if (_dmgText != null) _dmgText.text = NumberFormatUtil.ToShort(t.damage); // 292.71k
    }
}
```

> `NumberFormatUtil.ToShort`는 프로젝트 기존 숫자 축약 유틸 사용(없으면 k/m 포맷 헬퍼 신설). 스샷 표기: 666.43k / 191.29k.

### 5-5. Localization 키 (신규)

| 키 | 내용 |
|---|---|
| `result_victory` / `result_defeat` | Victory / Defeat (기존 있으면 재사용) |
| `vanguard_title_sub` | Project Ember (KR=스파크 프로젝트) |
| `vanguard_extra_rewards` | "Extra Rewards: {0}/{1}" |
| `vanguard_round_n` | "Round {0}" |
| `rewards_obtained` / `turret` / `dmg` 라벨 | 섹션/헤더 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 라운드별 터렛 DMG | ⚠️ 집계 필요 | 전투 중 유닛별/라운드별 DMG 집계 → `VanguardStagePlayService`/녹화(`VanguardReplayRecorder`, ingame §6)에서 `VanguardRoundResult` 구성. 상대(고스트) DMG는 클론 replay에 포함 |
| 양 플레이어 요약(공격력/칩수/티어/메달) | 부분 | self=`VanguardLoadoutService`/`RankService`, opponent=매치 데이터(`VanguardMatchData.opponentClone`) |
| Rewards Obtained | 서버 | 듀얼=승패 무관 Special DS 100 등(위키). 매치=Extra Reward 소비 보상. 서버 결과 응답 기반 |
| Extra Rewards 15/20 | 서버 | Match 진입권(시간 회복, 위키 9장). 결과 응답의 잔여치 |
| 스코어 0:3 | 결과 | 라운드 승수 집계 |
| 터렛 아이콘 | 기존 경로 | `TurretDataSO.spritePath`([[2026-06-03_vanguard-turret-setup-ui]]와 동일) |
| Discord URL | 설정 | 실제 URL 주입. **외부 링크 이동** — 정책 확인 |

### CLAUDE.md 준수
- `GetManager<T>()`만 / DOTween `SetUpdate(true)`(timeScale=0 중 동작) / `async void` 금지(UniTaskVoid) / 텍스트 로컬라이즈 / `Closed`에서 시퀀스 Kill + 동적 오브젝트 정리 / 매직넘버 const.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] 데이터 모델(5-1) 추가: `VanguardTurretDmgEntry`/`VanguardRoundResult`/`VanguardPlayerSummary`/`VanguardGameResultData`.
2. [ ] `VanguardTurretDmgRow.cs` / `VanguardRoundStatBlock.cs` / `VanguardResultPlayerInfo.cs` 작성(5-3/5-4).
3. [ ] `VanguardGameResultUI.cs` 작성(5-2). 빌드-그린.
4. [ ] 라운드/유닛 DMG 집계를 `VanguardStagePlayService` 결과 빌드에 연결(미구현 시 테스트 더미 주입).

**B. 프리팹**

5. [ ] `VanguardTurretDmgRow.prefab`(아이콘+레벨+DMG) → `3_Prefabs/UI/Vanguard/`.
6. [ ] `VanguardRoundStatBlock.prefab`(헤더 + Self/Opponent 컬럼, 각 컬럼에 TurretRow 부모) → 행 프리팹 연결.
7. [ ] `VanguardResultPlayerInfo.prefab`(아바타/이름/공격력/칩수/티어/메달) — self/opponent 2개(teal/red 톤).
8. [ ] `VanguardGameResultUI.prefab` 신규(§4 하이어라키): Background/ResultPanel/Header(타이틀·서브·스코어·CardInfo·Discord)/RewardsSection(ItemScrollView+ExtraReward)/PlayerInfoPanel/UnitStatScrollView(라운드 컨테이너)/Back.
9. [ ] ItemScrollView/UnitStatScrollView ScrollRect+Content(레이아웃) 설정 — Ark 프리팹 셋업 복사.
10. [ ] 필드 연결 + `Resources_moved/UI/`에 클래스명으로 저장.

**C. 연동**

11. [ ] 전투 종료 → `Show<VanguardGameResultUI>(data)` 호출(`VanguardStagePlayService` 결과 콜백).
12. [ ] Back → 로비 복귀 경로 확정(LoadLobbyScene vs Vanguard 로비 재진입).
13. [ ] Card Info → `VanguardInfoPopup`(또는 매치 카드/칩 Overview), Discord URL 주입.
14. [ ] Localization 키 추가(5-5).

---

## 8. 검증 체크리스트

- [ ] 전투 종료 → 결과 UI 표시(Time.timeScale=0), 승패 SFX/오버레이/타이틀.
- [ ] 스코어 "0:3", 서브타이틀, Defeat/Victory 정확.
- [ ] Rewards Obtained: ItemScrollView에 보상 아이콘+수량(100/120/1) 순차 등장.
- [ ] Extra Rewards "15/20" 표기.
- [ ] 플레이어 패널: 좌=self/우=opponent, 공격력◆·칩수⚙·티어뱃지+디비전+이름·메달◇.
- [ ] 라운드 블록: Round N + 결과 태그 + 양측 총 DMG + 터렛 3행(아이콘/레벨/DMG, k 포맷), 라운드 수만큼 스크롤.
- [ ] Card Info / Discord / Back 동작. Back → 로비 복귀 + timeScale 복원.
- [ ] `Closed`에서 시퀀스 Kill + 동적 오브젝트(보상/라운드) 정리(누수 없음).
- [ ] CLAUDE.md: SetUpdate(true)/GetManager/로컬라이즈/async void 없음.

---

## 9. 미해결 / 확인 필요

- [ ] **라운드/터렛 DMG 집계 위치**: 전투 중 유닛별·라운드별 누적 집계 소스 — `VanguardStagePlayService`+녹화 연계([[2026-06-03_vanguard-ingame-battle-ui]] §6 replay). 상대 터렛 DMG가 클론 replay에 포함되는지 확정.
- [ ] **라운드 수**: 고정(3?) vs 가변 — 스코어 0:3과 라운드 수의 관계(베스트오브?) 확인.
- [ ] **메달 ◇x1 의미** — 전 문서 공통 미해결.
- [ ] **Card Info 버튼 동작**: 이번 매치 사용 카드/칩 전용 뷰 vs `VanguardInfoPopup` 재사용 — 기획 확정.
- [ ] **Discord 링크**: 실제 URL + 외부 이동 정책(확인 팝업 필요 여부).
- [ ] **Extra Rewards 게이지** 시각화: 텍스트만 vs 게이지 바.
- [ ] **티어 변동 연계**: 결과 UI Back 후 `VanguardTierProgressPopup` 노출 순서 — 로비 진입 시점 확정.

---

> 작성: 2026-06-04 · 선행 코드 확인: **`ArkGameResultUI` 전체 실코드**(Opened/timeScale:105, ItemScrollView `_itemScrollContent`+`CreateItemDisplay`:949, UnitStatScrollView `_unitStatsScrollContent`+`CreateUnitStatsDisplayComponent`:917, 순차 등장 `ShowItemsSequentiallyAsync`:1123/`ShowUnitStatsSequentiallyAsync`:1212, 연출 `ShowResultAnimation`:503), `ItemDisplayComponent`, `VanguardTierUtil`/`VanguardTierMath`. 스샷 레이아웃(Defeat/0:3/Rewards/플레이어패널/라운드블록/Back) 1:1 매핑. 사용자 방침(ItemScrollView 재활용·라운드 신규 프리팹→UnitStatScrollView·중간 플레이어 패널) 반영. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
