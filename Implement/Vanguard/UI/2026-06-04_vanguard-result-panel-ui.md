# Vanguard 시즌 결과 패널(VanguardResultPanel) 구현 종합 문서 (2026-06-04)

## 문서 목적

시즌 종료 후 첫 진입 시 보여줄 **이전 시즌 정산 패널**(첨부 이미지: 최종 티어 엠블럼 + 이정표 보상 + 나의 랭킹 + 랭킹 보상 + 수령)의 프리팹 UI 배치 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- 구현 대상 = 기존 스켈레톤 **`VanguardResultPanel : MonoBehaviour`** 본문 채움 (프리팹: `3_Prefabs/UI/Vanguard/VanguardResultPanel.prefab`, `VanguardLobbyUI`의 `_resultPanel` 슬롯에 이미 연결).
- 참조 구현(사용자 지정): **`ArkResultPanel`** — 정산 표시→서버 claim→보상 지급→표시 팝업→콜백 플로우가 완성돼 있어 그대로 미러.
- 짝 문서: [[2026-06-03_vanguard-intro-panel-ui]](3패널 오케스트레이션), [[2026-06-04_vanguard-tier-progress-popup-ui]](티어 표시 헬퍼 공유), 상위 [[2026-05-29_vanguard-implementation-plan-outgame]] 8장(시즌 보상·중복수령 방지)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 기존 `VanguardResultPanel` 본문 채움 — **`ArkResultPanel` 미러** + Vanguard 차이(티어 엠블럼/이정표/메달) |
| 표시 4요소 | ① 최종 티어 엠블럼(+디비전 로마자) ② **이정표 보상**(티어 마일스톤, 슬롯 5) ③ **나의 랭킹** 행(순위/닉/티어/메달 + 리더보드 버튼) ④ **랭킹 보상**(순위 구간, 슬롯 4 + 프레임) |
| 수령 플로우 | Ark와 동일: 서버 claim(atomic 리셋) 성공 → `ModifyCurrency(out obtained)` → `RewardClaimPopupUI.ShowAlreadyClaimedRewards`(**CLAUDE.md 보상 Pattern 2**) → 기간제 프레임(7일) → 콜백(로비/인트로 전환) |
| 중복수령 방지 | **클라 영구 플래그 금지** — 서버 enter 응답 `prevSeasonSettlement` 유무 + claim atomic 리셋 (outgame 8장 확정 방침) |
| 데이터 | 랭킹 보상=`VanguardRankingRewardDataSO`(currency1~4+frameId, 위키 401+→Gold 500과 일치 확인) · 이정표 보상=티어 마일스톤 테이블(⚠️ 차팅 미확정) |
| 재사용 | `ItemDisplayComponent` · `VanguardTierUtil`/`VanguardTierMath`(티어 진행 팝업 문서와 공유) · `RewardClaimPopupUI` · `VanguardRankingInfoPopup` · Ark의 연출/claim 코드 |

---

## 1. 진입 / 수령 플로우 (확인된 코드 + 확정 방침)

`VanguardLobbyUI`(확인): 3패널 보유, `OpenResultPanel() → _resultPanel.ShowResult()`. `SetupAsync()`의 TODO가 진입 분기:

```
VanguardLobbyUI.OpenedAsync → SetupAsync (enter API)
  └─ enter 응답에 prevSeasonSettlement 있음 → OpenResultPanel()   ★ 본 패널
       └─ [수령] → 서버 claimSeasonReward (atomic 리셋, 서버 권위)
            ├─ 실패 → 버튼 복구 + 토스트 (패널 유지)
            └─ 성공 → 재화 지급(ModifyCurrency) → ShowAlreadyClaimedRewards 팝업
                 └─ 콜백 → ShowLobby() (또는 새 시즌 첫 진입이면 OpenIntroPanel())
  └─ 정산 없음 → ShowLobby() / 첫 진입 → OpenIntroPanel()
```

> ⚠️ **중복 수령 방지 원칙(outgame 8장 — Horde 검증 결론)**: 클라에 영구 `rewardStatus` 플래그를 만들지 않는다. 서버가 enter 응답의 정산 데이터 유무로 노출을 결정하고, claim은 서버에서 atomic하게 리셋된다. Ark도 동일(`ClaimPreviousSeasonRewardAsync` 성공 후에만 지급).
> ⚠️ **보상 지급 패턴(CLAUDE.md)**: 이미 서버에서 수령 확정된 보상 → `ModifyCurrency(...)` 후 `popup.ShowAlreadyClaimedRewards(rewards, title, desc)` (**Pattern 2**). `RewardClaimPopupUI`의 일반 claim 경로(Pattern 1)와 혼용 금지.

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 헤더 | `스파크 프로젝트 / 뱅가드` 명판 | `_titleText`(로컬라이즈) — 인트로/팝업과 동일 명판 아트 |
| B | 최종 티어 엠블럼 | 보라(다이아) 대형 엠블럼 + 상단 `IV` 명판 | `_tierEmblemImage` ← `VanguardTierUtil.GetTierSprite` + `_divisionText` ← `VanguardTierMath.GetDivisionRoman` |
| C | **이정표 보상** | 섹션 라벨 + 아이콘 5: 골드 19000 · 다이아 250 · 캐니스터 20 · 주황칩 6 · 파랑상자 1 | `_milestoneRewardItems`(`ItemDisplayComponent` ×5 고정 슬롯, Ark `_rewardItemList` 패턴) |
| D | **나의 랭킹** 라벨 + 리더보드 버튼 | 우측 작은 왕관 아이콘 버튼 | `_rankingButton` → `Show<VanguardRankingInfoPopup>(prevRankingInfo)` (Ark 동일) |
| E | 나의 랭킹 행 | `500+` · 보라 리그 엠블럼 · `Userfl4w6x` / 우측: `IV` 티어뱃지 · `다이아4` · ◇`x3` | `_rankText`/`_leagueEmblemImage`/`_userNameText` + `_myTierBadge`/`_myTierName`/`_medalCountText` |
| F | **랭킹 보상** | 섹션 라벨 + 골드 `500` 1개 | `_rankingRewardItems`(`ItemDisplayComponent` ×4 고정 슬롯) + `_rewardFrameImage`(프레임 보상) |
| G | 배경 | 하단 요새 아트 + 보라 안개 | 정적 배경 이미지 |
| H | 수령 버튼 | 노란 대형 `수령` | `_claimButton` + `_claimButtonText`(로컬라이즈 `claim_button` — Ark 동일 키) |

**위키 대조 검증**: 스샷 순위 `500+` → 위키 랭킹 보상 **401+ 구간 = Gold ×500** 과 정확히 일치(F의 골드 500). 이정표 보상(C)은 위키 "Tier Milestones"(Ember Mark/Glory Key/Diamond/Gold 등) — 최종 티어(다이아4)까지의 마일스톤 누적. 위키 "Medals are Valid for 7 Days" → 상위권 프레임/메달 보상은 **7일 기간제**(Ark 프레임 처리와 동일).

---

## 3. 재사용 자산 분석 (ArkResultPanel 1:1 매핑)

| Ark (`UI/Ark/Component/ArkResultPanel.cs` — 실코드 검증) | Vanguard 대응 | 비고 |
|---|---|---|
| `OpenPanel(previousRank, prevMaxClearedStage, onClaimCallback, prevRankingInfo)` | `ShowResult(VanguardSeasonResultData, Action onClaim)` | 시그니처만 Vanguard 데이터로 |
| 랭킹 표시(top3 스프라이트 vs 텍스트) | `500+` 텍스트 표기(+top3 스프라이트 옵션) | `_topRankSprites` 재사용 가능 |
| `GetRewardDataForRank(rank)` — 구간 탐색(1,2,…,401 오름차순, `rank>=cur && rank<next`) | **동일 로직** — `VanguardRankingRewardDataSO` 리스트 대상 | SO 구조 동일(currency1~4/rank1~4Count/rewardFrameId) |
| `SetupRewardDisplay()` — 고정 슬롯 `List<ItemDisplayComponent>` 토글+`SetupItem` | 랭킹 보상 4슬롯 + 이정표 5슬롯 2벌 | |
| `SetupFrameReward(frameId)` + `ProcessTimedFrameRewardAsync(frameId, prevSeasonEndTime)` — **시즌 종료+7일 기간제** | **그대로 복제** (위키 "7 Days" 일치) | claim 전에 `prevSeasonEndTime` 캐싱 주의(Ark 주석) |
| `ClaimRewardAsync()` — `_isClaiming` 가드 → 서버 claim → `ModifyCurrency(out obtainedItems, autoSave:false)` 누적 → `SaveCurrencyDataAsync` → `ShowAlreadyClaimedRewards` → 콜백 | **그대로 복제** (서버 API만 Vanguard) | CLAUDE.md Pattern 2 |
| `PlayOpenAnimation()` — CanvasGroup 페이드 + 콘텐츠 OutBack 스케일, 트윈 2개 각각 `AsyncWaitForCompletion()` await | **그대로 복제** | `ToUniTask()` 금지 주석 포함 |
| `OnClickRankingButton()` → `Show<ArkRankingInfoPopup>(prevRankingInfo)` | → `Show<VanguardRankingInfoPopup>(prevRankingInfo)` | 팝업 이미 존재 |
| `SetupUserAndStageDisplay()` — 닉네임(`PlayerDataManager.UserNickname`)+프로필 아이콘 로드 | 닉네임 동일. 프로필 대신 리그 엠블럼 옵션 | 스테이지 게이지(`SetupMainStageGauge`)는 **미사용** |

| 기타 재사용 | 경로 | 용도 |
|---|---|---|
| `ItemDisplayComponent` | `UI/Components/` | 보상 아이콘+수량 (`SetupItem(ECurrencyType,int)` / `SetInteractable` / `SetShowDetailPopup`) |
| `VanguardTierUtil` / `VanguardTierMath` | `UI/Vanguard/` | 티어 엠블럼/표시명/디비전 로마자([[2026-06-04_vanguard-tier-progress-popup-ui]] §5-3 헬퍼 공유) |
| `VanguardRankingRewardDataSO` | `SOs/SO/DataSheet/` | 랭킹 보상 구간(rank/currency1~4/rewardFrameId/minTier) |
| `RewardClaimPopupUI` | (CLAUDE.md) | `ShowAlreadyClaimedRewards(rewards, title, desc, null)` |
| `VanguardRankingInfoPopup` | `UI/Vanguard/Popup/` | 이전 시즌 리더보드 |

### Ark에서 가져오지 않는 것

- ❌ 스테이지 진행도 보상(`_stageRewardContainer`/`SetupMainStageGauge`) → Vanguard는 **이정표(티어 마일스톤) 보상**으로 대체(데이터 소스 다름, 표시는 동일하게 고정 슬롯).
- ❌ `_maxClearedStageText` → 최종 티어 엠블럼(B)로 대체.

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> 기존 `VanguardResultPanel.prefab` 내부 배치. 루트에 `VanguardResultPanel.cs`(스켈레톤 교체 아님 — 본문 확장). 패널은 `VanguardLobbyUI` 내부 자식이므로 자체 Dim 불필요.

```
VanguardResultPanel (루트, ▶ VanguardResultPanel.cs, CanvasGroup) → _canvasGroup
└─ Content (RectTransform — 스케일 연출 대상)            → _contentRectTransform
   ├─ Background (하단 요새 아트 + 보라 안개, 정적)
   ├─ Header
   │  └─ TitleText 명판 ("스파크 프로젝트 / 뱅가드")       → _titleText
   ├─ TierEmblemGroup
   │  ├─ TierEmblem (Image, 대형)                         → _tierEmblemImage
   │  └─ DivisionPlaque → DivisionText ("IV")             → _divisionText
   ├─ MilestoneSection
   │  ├─ SectionLabel (".. ◀ 이정표 보상 ▶ ..")
   │  └─ RewardRow (HorizontalLayoutGroup)
   │     └─ [ItemDisplayComponent x5 고정]                 → _milestoneRewardItems (List)
   ├─ MyRankingSection
   │  ├─ SectionLabel (".. ◀ 나의 랭킹 ▶ ..")
   │  ├─ Btn_Ranking (우상단 왕관 아이콘)                   → _rankingButton
   │  └─ MyRankingRow (어두운 띠)
   │     ├─ RankText ("500+")                              → _rankText
   │     ├─ RankImage (top3 스프라이트용, 기본 비활성)       → _rankImage (+_topRankSprites[3])
   │     ├─ LeagueEmblem (보라 원형)                        → _leagueEmblemImage
   │     ├─ UserNameText ("Userfl4w6x")                    → _userNameText
   │     └─ MyTierGroup (우측)
   │        ├─ TierBadge (IV 뱃지)                          → _myTierBadgeImage
   │        ├─ TierNameText ("다이아4")                     → _myTierNameText
   │        └─ MedalCountText (◇ "x3")                     → _medalCountText
   ├─ RankingRewardSection
   │  ├─ SectionLabel (".. ◀ 랭킹 보상 ▶ ..")              → _rankingRewardRoot (구간 보상 없으면 통째 숨김)
   │  ├─ RewardRow (HorizontalLayoutGroup)
   │  │  └─ [ItemDisplayComponent x4 고정]                  → _rankingRewardItems (List)
   │  └─ FrameReward (프레임 보상, 기본 비활성)              → _rewardFrameRoot / _rewardFrameImage
   └─ Bottom
      └─ Btn_Claim (노란 대형 "수령")                       → _claimButton / _claimButtonText
```

- 섹션 라벨 장식(`.... ◀ ▶ ....`)은 아트 이미지+TMP 조합(3섹션 공통 스타일).
- 스켈레톤의 `_closeButton`은 스샷에 없음 → 유지하되 비활성(수령이 유일한 출구) 또는 claim 실패 폴백용 `[설계 판단]`.

---

## 5. 스크립트 설계

### 5-1. 데이터 모델

```csharp
using System.Collections.Generic;

/// <summary> 이전 시즌 정산 데이터 — enter 응답 prevSeasonSettlement 매핑. </summary>
public class VanguardSeasonResultData
{
    public EVanguardTier finalTier;       // 최종 티어 (다이아4)
    public int finalRank;                 // 최종 순위 (0/음수 = 순위권 외 → "N+" 표기)
    public int medalCount;                // ◇ 메달 수
    public List<(ECurrencyType type, int amount)> milestoneRewards; // 이정표(티어 마일스톤) 보상 — 서버 계산 권장(§7)
    public string prevSeasonEndTimeRaw;   // ISO8601 — 기간제 프레임 만료 계산용
    public VanguardRankingResponse prevRankingInfo; // 이전 시즌 리더보드 (없으면 버튼 숨김)
}
```

### 5-2. `VanguardResultPanel.cs` (본문 — 참조 구현, ArkResultPanel 미러)

```csharp
using System;
using System.Collections.Generic;
using System.Globalization;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 이전 시즌 결과/보상 패널 (ArkResultPanel 미러).
/// 표시: 최종 티어 엠블럼 / 이정표 보상 / 나의 랭킹 / 랭킹 보상. 수령은 서버 권위(클라 영구 플래그 금지).
/// </summary>
public class VanguardResultPanel : MonoBehaviour
{
    #region Serialized
    [Header("헤더/티어")]
    [SerializeField] private TextMeshProUGUI _titleText;
    [SerializeField] private Image _tierEmblemImage;
    [SerializeField] private TextMeshProUGUI _divisionText;

    [Header("이정표 보상 (티어 마일스톤)")]
    [SerializeField] private List<ItemDisplayComponent> _milestoneRewardItems; // 5 고정

    [Header("나의 랭킹")]
    [SerializeField] private TextMeshProUGUI _rankText;       // "500+"
    [SerializeField] private Image _rankImage;                // top3 (기본 비활성)
    [SerializeField] private Sprite[] _topRankSprites;        // 1~3등
    [SerializeField] private Image _leagueEmblemImage;
    [SerializeField] private TextMeshProUGUI _userNameText;
    [SerializeField] private Image _myTierBadgeImage;
    [SerializeField] private TextMeshProUGUI _myTierNameText;
    [SerializeField] private TextMeshProUGUI _medalCountText; // "x3"
    [SerializeField] private Button _rankingButton;

    [Header("랭킹 보상")]
    [SerializeField] private GameObject _rankingRewardRoot;
    [SerializeField] private List<ItemDisplayComponent> _rankingRewardItems; // 4 고정
    [SerializeField] private GameObject _rewardFrameRoot;
    [SerializeField] private Image _rewardFrameImage;

    [Header("버튼")]
    [SerializeField] private Button _claimButton;
    [SerializeField] private TextMeshProUGUI _claimButtonText;
    [SerializeField] private Button _closeButton; // 스샷 미존재 — 폴백용(기본 비활성)

    [Header("연출 (Ark PlayOpenAnimation 동일)")]
    [SerializeField] private CanvasGroup _canvasGroup;
    [SerializeField] private RectTransform _contentRectTransform;
    [SerializeField] private float _fadeInDuration = 0.3f;
    [SerializeField] private float _scaleInDuration = 0.3f;
    #endregion

    private VanguardManager _vanguardManager;
    private UIManager _uiManager;
    private PlayerDataManager _playerDataManager;

    private VanguardSeasonResultData _data;
    private VanguardRankingRewardDataSO _rankingRewardData;
    private Action _onClaimCallback;
    private bool _isClaiming;
    private bool _bound;

    public void Initialize()
    {
        _uiManager = Managers.Instance.GetManager<UIManager>();
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();
        _playerDataManager = Managers.Instance.GetManager<PlayerDataManager>();

        if (_bound) return;
        _bound = true;
        _claimButton.onClick.AddListener(OnClickClaim);
        _closeButton?.onClick.AddListener(OnClickClose);
        _rankingButton?.onClick.AddListener(OnClickRanking);
    }

    /// <summary>VanguardLobbyUI.OpenResultPanel()에서 호출. 정산 데이터 + 수령 완료 콜백.</summary>
    public void ShowResult(VanguardSeasonResultData data, Action onClaimCallback)
    {
        _data = data;
        _onClaimCallback = onClaimCallback;
        _isClaiming = false;
        if (_data == null) { _onClaimCallback?.Invoke(); return; } // 정산 없음 → 즉시 통과

        Setup();
        PlayOpenAnimationAsync().Forget();
    }

    /// <summary>스켈레톤 호환(무인자) — Manager 캐시(LastEnterResponse)에서 정산 데이터 변환해 호출.</summary>
    public void ShowResult()
    {
        // TODO(서버): _vanguardManager.SeasonService.BuildPrevSeasonResultData() 연결. 미연결 단계는 테스트 더미.
        ShowResult(BuildTestData(), () => GetComponentInParent<VanguardLobbyUI>()?.ShowLobby());
    }

    public void Cleanup() { }

    // ─────────── Setup ───────────
    private void Setup()
    {
        gameObject.SetActive(true);
        _claimButton.interactable = true;
        if (_claimButtonText != null) _claimButtonText.text = LocalizationManager.GetLocalizedText("claim_button"); // Ark 동일 키
        if (_titleText != null) _titleText.text = LocalizationManager.GetLocalizedText("vanguard_title");
        if (_closeButton != null) _closeButton.gameObject.SetActive(false);

        SetupTierEmblem();
        SetupMilestoneRewards();
        SetupMyRankingRow();
        SetupRankingRewards();

        // 초기 연출 상태 (Ark 동일)
        if (_canvasGroup != null) _canvasGroup.alpha = 0f;
        if (_contentRectTransform != null) _contentRectTransform.localScale = Vector3.zero;
    }

    private void SetupTierEmblem()
    {
        if (_tierEmblemImage != null) _tierEmblemImage.sprite = VanguardTierUtil.GetTierSprite(_data.finalTier);
        if (_divisionText != null) _divisionText.text = VanguardTierMath.GetDivisionRoman(_data.finalTier);
    }

    private void SetupMilestoneRewards()
    {
        foreach (var it in _milestoneRewardItems) it?.gameObject.SetActive(false);
        if (_data.milestoneRewards == null) return;
        int i = 0;
        foreach (var (type, amount) in _data.milestoneRewards)
        {
            if (amount <= 0 || i >= _milestoneRewardItems.Count) continue;
            var item = _milestoneRewardItems[i++];
            item.gameObject.SetActive(true);
            item.SetupItem(type, amount);
            item.SetInteractable(false);
        }
    }

    private void SetupMyRankingRow()
    {
        // 순위: top3 스프라이트 / 일반 숫자 / 순위권 외 "N+" (Ark SetupRankDisplay 변형)
        bool top3 = _data.finalRank >= 1 && _data.finalRank <= 3 && _topRankSprites?.Length >= _data.finalRank;
        if (_rankImage != null)
        {
            _rankImage.gameObject.SetActive(top3);
            if (top3) _rankImage.sprite = _topRankSprites[_data.finalRank - 1];
        }
        if (_rankText != null)
        {
            _rankText.gameObject.SetActive(!top3);
            _rankText.text = _data.finalRank > 0 ? _data.finalRank.ToString()
                : LocalizationManager.GetLocalizedTextFormat("vanguard_rank_over", GetLastBracketStart()); // "500+"
        }

        if (_userNameText != null)
            _userNameText.text = string.IsNullOrEmpty(_playerDataManager?.UserNickname) ? "-" : _playerDataManager.UserNickname;

        if (_myTierBadgeImage != null) _myTierBadgeImage.sprite = VanguardTierUtil.GetTierSprite(_data.finalTier);
        if (_myTierNameText != null) _myTierNameText.text = VanguardTierUtil.GetDisplayName(_data.finalTier);
        if (_medalCountText != null) _medalCountText.text = $"x{_data.medalCount}";

        bool hasRankingInfo = _data.prevRankingInfo != null;
        if (_rankingButton != null) _rankingButton.gameObject.SetActive(hasRankingInfo);
    }

    private void SetupRankingRewards()
    {
        foreach (var it in _rankingRewardItems) it?.gameObject.SetActive(false);
        _rewardFrameRoot?.SetActive(false);

        _rankingRewardData = GetRewardDataForRank(_data.finalRank);
        bool has = _rankingRewardData != null;
        _rankingRewardRoot?.SetActive(has);
        if (!has) return;

        var pairs = new[]
        {
            (_rankingRewardData.currency1Type, _rankingRewardData.rank1Count),
            (_rankingRewardData.currency2Type, _rankingRewardData.rank2Count),
            (_rankingRewardData.currency3Type, _rankingRewardData.rank3Count),
            (_rankingRewardData.currency4Type, _rankingRewardData.rank4Count),
        };
        for (int i = 0; i < pairs.Length && i < _rankingRewardItems.Count; i++)
        {
            if (pairs[i].Item2 <= 0) continue;
            _rankingRewardItems[i].gameObject.SetActive(true);
            _rankingRewardItems[i].SetupItem(pairs[i].Item1, pairs[i].Item2);
            _rankingRewardItems[i].SetInteractable(false);
        }

        SetupFrameReward(_rankingRewardData.rewardFrameId); // Ark SetupFrameReward 복제 (ContentUnlockManager 경유)
    }

    /// <summary>Ark GetRewardDataForRank 동일 — 오름차순 구간 탐색. finalRank<=0은 최하 구간(401+)으로 폴백.</summary>
    private VanguardRankingRewardDataSO GetRewardDataForRank(int rank)
    {
        var list = _vanguardManager?.RankService?.GetRankingRewardList(); // TODO: SO 리스트 로드 경로 노출
        if (list == null || list.Count == 0) return null;
        if (rank <= 0) return list[^1]; // 순위권 외 → 마지막(401+) 구간 [설계 판단 — 위키: 401+도 보상 있음]

        for (int i = 0; i < list.Count; i++)
        {
            int next = (i + 1 < list.Count) ? list[i + 1].rank : int.MaxValue;
            if (rank >= list[i].rank && rank < next) return list[i];
        }
        return null;
    }

    private int GetLastBracketStart()
    {
        var list = _vanguardManager?.RankService?.GetRankingRewardList();
        return (list != null && list.Count > 0) ? list[^1].rank + 99 : 500; // "401+" 구간 → 표기 500 [설계 판단 — §9]
    }

    private void SetupFrameReward(int frameId) { /* ArkResultPanel.SetupFrameReward:331 복제 (frameId==0 → root 숨김) */ }

    // ─────────── 수령 (ArkResultPanel.ClaimRewardAsync 미러) ───────────
    private void OnClickClaim()
    {
        if (_isClaiming) return;
        ClaimRewardAsync().Forget();
    }

    private async UniTaskVoid ClaimRewardAsync()
    {
        _isClaiming = true;
        _claimButton.interactable = false;

        // 기간제 프레임 만료 계산용 — claim(리셋) 전에 캐싱 (Ark 주석 동일)
        string cachedPrevSeasonEnd = _data.prevSeasonEndTimeRaw;

        bool success = false;
        var popup = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        try { success = await _vanguardManager.ClaimPreviousSeasonRewardAsync(); } // TODO: VanguardServerService claim
        finally { ServerLoadingPopupUI.Hide(); }

        if (!success)
        {
            _isClaiming = false;
            _claimButton.interactable = true;
            ToastManager.ShowToast(LocalizationManager.GetLocalizedText("maintenance_message"));
            return;
        }

        // 보상 합산: 이정표 + 랭킹 구간 (AddRewardIfValid 패턴)
        var rewards = new Dictionary<ECurrencyType, int>();
        if (_data.milestoneRewards != null)
            foreach (var (t, a) in _data.milestoneRewards) AddRewardIfValid(rewards, t, a);
        if (_rankingRewardData != null)
        {
            AddRewardIfValid(rewards, _rankingRewardData.currency1Type, _rankingRewardData.rank1Count);
            AddRewardIfValid(rewards, _rankingRewardData.currency2Type, _rankingRewardData.rank2Count);
            AddRewardIfValid(rewards, _rankingRewardData.currency3Type, _rankingRewardData.rank3Count);
            AddRewardIfValid(rewards, _rankingRewardData.currency4Type, _rankingRewardData.rank4Count);
        }

        // 지급: ModifyCurrency(out obtained, autoSave:false) 누적 → 일괄 저장 (Ark :639 동일)
        var currencyManager = Managers.Instance.GetManager<CurrencyManager>();
        var actualRewards = new Dictionary<ECurrencyType, int>();
        bool didModify = false;
        foreach (var r in rewards)
        {
            if (r.Value <= 0) continue;
            if (!currencyManager.ModifyCurrency(r.Key, r.Value, out var obtained, isNaturalRecovery: false, autoSave: false)) continue;
            if (obtained != null)
                foreach (var o in obtained)
                    if (o.Value > 0) actualRewards[o.Key] = actualRewards.GetValueOrDefault(o.Key) + o.Value;
            didModify = true;
        }
        if (didModify) currencyManager.SaveCurrencyDataAsync().Forget();

        // 기간제 프레임 (시즌 종료 + 7일 — 위키 "Valid for 7 Days") — Ark ProcessTimedFrameRewardAsync 복제
        if (_rankingRewardData != null && _rankingRewardData.rewardFrameId > 0)
            await ProcessTimedFrameRewardAsync(_rankingRewardData.rewardFrameId, cachedPrevSeasonEnd);

        // 표시 팝업 — CLAUDE.md 보상 Pattern 2 (이미 지급 완료, 표시만)
        if (actualRewards.Count > 0)
        {
            string title = LocalizationManager.GetLocalizedText("vanguard_prev_season_reward_title");
            string desc = LocalizationManager.GetLocalizedText("vanguard_prev_season_reward_desc");
            var claimPopup = _uiManager?.Show<RewardClaimPopupUI>();
            claimPopup?.ShowAlreadyClaimedRewards(actualRewards, title, desc, null);
        }

        _onClaimCallback?.Invoke(); // 로비/인트로 전환 (VanguardLobbyUI가 주입)
    }

    private static void AddRewardIfValid(Dictionary<ECurrencyType, int> rewards, ECurrencyType type, int amount)
    {
        if (amount <= 0) return;
        rewards[type] = rewards.GetValueOrDefault(type) + amount;
    }

    private async UniTask ProcessTimedFrameRewardAsync(int frameId, string prevSeasonEndRaw)
    {
        // ArkResultPanel.ProcessTimedFrameRewardAsync:715 복제:
        // ISO8601 파싱(InvariantCulture/RoundtripKind) → +7일 → ContentUnlockManager.UnlockTimedProfileFrame(frameId, expiration)
        await UniTask.CompletedTask;
    }

    // ─────────── 연출/기타 ───────────
    private async UniTaskVoid PlayOpenAnimationAsync()
    {
        // Ark PlayOpenAnimation:506 동일 — 트윈 2개 시작 후 각각 AsyncWaitForCompletion await (ToUniTask 금지)
        Tween fade = _canvasGroup != null ? _canvasGroup.DOFade(1f, _fadeInDuration) : null;
        if (_contentRectTransform != null)
        {
            var scale = _contentRectTransform.DOScale(Vector3.one, _scaleInDuration).SetEase(Ease.OutBack);
            var sAwait = scale.AsyncWaitForCompletion();
            if (fade != null) { var fAwait = fade.AsyncWaitForCompletion(); await sAwait; await fAwait; }
            else await sAwait;
        }
        else if (fade != null) await fade.AsyncWaitForCompletion();
    }

    private void OnClickRanking()
    {
        if (_data?.prevRankingInfo == null) return;
        _uiManager?.Show<VanguardRankingInfoPopup>(new object[] { _data.prevRankingInfo });
    }

    private void OnClickClose() => GetComponentInParent<VanguardLobbyUI>()?.ShowLobby(); // 폴백 전용

    private VanguardSeasonResultData BuildTestData() => new()
    {
        finalTier = EVanguardTier.Diamond4, finalRank = 0, medalCount = 3,
        milestoneRewards = new() { (ECurrencyType.Gold, 19000), (ECurrencyType.Gem, 250) /* +캐니스터/칩/상자 */ },
        prevRankingInfo = null,
    };
}
```

### 5-3. Localization 키 (신규)

| 키 | 내용 |
|---|---|
| `vanguard_milestone_reward` / `vanguard_my_ranking` / `vanguard_ranking_reward` | 섹션 라벨 3종 (이정표 보상/나의 랭킹/랭킹 보상) |
| `vanguard_rank_over` | "{0}+" (순위권 외 표기) |
| `vanguard_prev_season_reward_title` / `_desc` | 수령 팝업 제목/설명 (Ark `ark_previous_season_reward_*` 대응) |
| (기존) `claim_button` / `vanguard_title` / `maintenance_message` | 재사용 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 정산 데이터(finalTier/finalRank/medalCount/prevSeasonEndTime/prevRankingInfo) | ⚠️ 서버 enter 응답 미구현 | `prevSeasonSettlement` 스키마 → [[2026-05-31_vanguard-server-api-spec]] 동기화. `VanguardSeasonService`가 `VanguardSeasonResultData`로 변환해 `VanguardLobbyUI`가 주입 |
| **이정표(티어 마일스톤) 보상 목록** | ⚠️ 차팅 미확정(outgame 8-1: 위키 표기 불명확) | **서버가 계산해 내려주는 방식 권장**(티어별 누적 규칙을 클라에 박지 않음). 클라 SO로 갈 경우 티어 마일스톤 테이블 신설 |
| 랭킹 보상 구간 | `VanguardRankingRewardDataSO` 존재 | `GetRankingRewardList()` 로드 경로를 `RankService`(또는 Manager)에 노출 — TODO |
| claim API | ⚠️ 미구현 | `VanguardManager.ClaimPreviousSeasonRewardAsync()` → `VanguardServerService`(atomic 리셋). Ark `ClaimPreviousSeasonRewardAsync` 미러 |
| 기간제 프레임 | 패턴 존재 | Ark `ProcessTimedFrameRewardAsync` 복제(시즌 종료+7일, **claim 전 종료시각 캐싱** 필수) |
| 메달 ◇x3 | ⚠️ 의미 미확정 | 듀얼/티어진행 문서와 공통 미해결 — 표기만 |

### CLAUDE.md 준수

- 보상: **Pattern 2**(`ModifyCurrency` 후 `ShowAlreadyClaimedRewards`) — Pattern 1(팝업이 지급)과 혼용 금지.
- DOTween: `AsyncWaitForCompletion()`(ToUniTask 금지). 서버콜: `ServerLoadingPopupUI.Show/finally Hide`. `async void` 금지. 텍스트 로컬라이즈. `DateTime.Now` 금지(프레임 만료는 서버 종료시각 기준).

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardSeasonResultData` 모델 추가(5-1).
2. [ ] `VanguardResultPanel.cs` 본문 확장(5-2) — Ark 미러 부분(`SetupFrameReward`/`ProcessTimedFrameRewardAsync`)은 `ArkResultPanel.cs:331/:715` 그대로 복제. 빌드-그린.
3. [ ] `VanguardManager.ClaimPreviousSeasonRewardAsync()` + `RankService.GetRankingRewardList()` 노출(서버 미구현 시 더미 true/SO 직로드).
4. [ ] `VanguardLobbyUI.SetupAsync`의 TODO 분기 연결: 정산 있음 → `OpenResultPanel()`(데이터+콜백 주입형 `ShowResult` 호출로 교체).

**B. 프리팹** (`VanguardResultPanel.prefab` 편집)

5. [ ] §4 하이어라키 배치: 루트 CanvasGroup + Content(스케일 연출) / 헤더 명판 / 대형 티어 엠블럼+디비전 명판 / 3섹션(이정표·나의랭킹·랭킹보상) / 수령 버튼 / 배경 요새 아트.
6. [ ] `ItemDisplayComponent` 고정 슬롯: 이정표 5개 + 랭킹 보상 4개 배치(HorizontalLayoutGroup).
7. [ ] 나의 랭킹 행: RankText/RankImage(top3)/리그엠블럼/닉네임/티어뱃지+이름/메달 텍스트 + 우상단 리더보드 버튼.
8. [ ] 프레임 보상 루트(기본 비활성) + 수령 버튼/텍스트 연결. `_closeButton` 기본 비활성.
9. [ ] 필드 연결 후 `VanguardLobbyUI` 프리팹의 `_resultPanel` 참조 유지 확인(이미 연결).

**C. 연동/마감**

10. [ ] Localization 키 추가(5-3).
11. [ ] 테스트: `BuildTestData()`(다이아4/순위권외/메달3) → 표시 4요소 + 수령 플로우(더미 claim) 확인.
12. [ ] RedDot/로비 버튼 갱신 필요 시 Ark 패턴(:594-600) 참조해 추가.

---

## 8. 검증 체크리스트

- [ ] 정산 있음 → 로비 대신 결과 패널 노출(연출: 페이드+OutBack 스케일).
- [ ] 티어 엠블럼/디비전 로마자(IV)/티어명(다이아4) 정확 표시.
- [ ] 이정표 보상 슬롯: 수량>0만 활성, 5개 초과분 무시.
- [ ] 나의 랭킹: top1~3 스프라이트 / 일반 숫자 / 순위권 외 "500+" 3분기 표기.
- [ ] 랭킹 보상: 구간 탐색 정확(401+ → Gold 500 — 위키 표와 대조), 구간 없음 시 섹션 숨김.
- [ ] 리더보드 버튼: prevRankingInfo 없으면 숨김, 있으면 이전 시즌 랭킹 팝업.
- [ ] 수령: 중복 클릭 가드 → 서버 claim 실패 시 버튼 복구+토스트 / 성공 시 지급→`ShowAlreadyClaimedRewards`→콜백 전환.
- [ ] 기간제 프레임: claim 전 종료시각 캐싱 → +7일 만료로 지급.
- [ ] 재진입(이미 수령) 시 서버가 정산 미제공 → 패널 미노출(클라 플래그 없음 확인).
- [ ] CLAUDE.md: 보상 Pattern 2 / AsyncWaitForCompletion / 로컬라이즈 / async void 없음.

---

## 9. 미해결 / 확인 필요

- [ ] **이정표 보상 산출 주체**: 서버 계산 내려주기(권장) vs 클라 티어 마일스톤 테이블 — 기획+서버 협의(위키 수치 자체가 불명확, outgame 8-1).
- [ ] **"500+" 표기 규칙**: 순위권 외 고정 라벨인지(리더보드 501위 밖), 구간 기반인지 — 실게임 확인 후 `GetLastBracketStart` 조정.
- [ ] **메달 ◇x3 의미** — 전 문서 공통 미해결(서버 필드 확정 대기).
- [ ] **리그 엠블럼(보라 원형) 아트 소스**: 티어 그룹 엠블럼 변형인지 별도 리그 아이콘인지.
- [ ] **수령 후 전환처**: 항상 로비 vs 새 시즌 진행 중이면 인트로 — `VanguardLobbyUI` 분기 정책([[2026-06-03_vanguard-intro-panel-ui]] §11과 공통).
- [ ] **claim API 스키마** → [[2026-05-31_vanguard-server-api-spec]] 동기화.

---

> 작성: 2026-06-04 · 선행 코드 확인: `VanguardResultPanel`(스켈레톤)/`VanguardLobbyUI`(OpenResultPanel·3패널)/**`ArkResultPanel` 전체 실코드**(구간탐색:196/보상슬롯:268/프레임:331/claim:562/ModifyCurrency out:639/ShowAlreadyClaimedRewards:687/기간제프레임:715/연출:506)/`VanguardRankingRewardDataSO`/`VanguardTierUtil`/`VanguardRankingInfoPopup`. 스샷-위키 대조(401+→Gold500 일치, 프레임 7일) 반영. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
