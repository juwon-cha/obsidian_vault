# Vanguard 카드 정보 팝업(VanguardCardInfoPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

`VanguardExclusiveChipRow`의 **`Btn_Info`** 버튼을 누르면 뜨는 **전체 화면 "카드 정보" 팝업**(첨부 이미지: 상단 "활성화 가능" 기능 슬롯 + 중앙 "없음" + 하단 "비활성화됨" 카드 스크롤)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- **네이밍**: 헤더가 "카드 정보" → **`VanguardCardInfoPopup`** (시즌 규칙 `VanguardInfoPopup`과 구분).
- 화면 전체를 덮음. **두 개의 스크롤뷰**(위=활성화 가능 기능 슬롯 / 아래=비활성화된 카드).
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]](부모 행·Btn_Info), [[2026-06-04_vanguard-unit-detail-popup-ui]](CardInfo 재활용·배경 탭 닫기)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 신규 `VanguardCardInfoPopup : UIBase` + `VanguardCardFunctionSlot`(기능 1행) + provider(더미/서버) |
| 프리팹 | 신규 `Resources_moved/UI/VanguardCardInfoPopup.prefab` (전체 화면) |
| 진입 | `VanguardExclusiveChipRow._infoButton`(Btn_Info) → `Show<VanguardCardInfoPopup>()` |
| 상단 스크롤 | "활성화 가능" 기능 슬롯(`VanguardCardFunctionSlot`) — 1번=항상 활성(활성화됨), 2번=획득하기→배틀패스 |
| 중앙 | "없음"(현재 활성 카드 없음) 빈 상태 placeholder |
| 하단 스크롤 | "비활성화됨" — 서버가 이번 시즌에 할당하지 않은 카드 — **`CardInfo`(`UnitCardItem`) 재활용** |
| 획득하기 | → 뱅가드 배틀패스(`VanguardShopPopup`의 `_battlePassPanel`) |
| 닫기 | **배경(빈 곳) 탭 닫기** + 헤더 X (`-빈 곳을 눌러 닫기-`) |
| 데이터 | 기능 2종(Adversity/Initiative) + 비활성 카드 리스트 = provider(미연동 → 더미) |

---

## 1. 진입 / 액션 플로우

```
VanguardUnitSetupPopup > ExclusiveChipPanel > VanguardExclusiveChipRow > Btn_Info 클릭
  └─ Show<VanguardCardInfoPopup>()    // 전체 화면
       ├─ 상단: 활성화 가능 기능 2슬롯
       │    1) Adversity Boost — 항상 활성("활성화됨")
       │    2) Initiative Boost — "획득하기" → 뱅가드 배틀패스
       ├─ 중앙: "없음"(현재 활성 카드 없음) placeholder
       └─ 하단: 비활성화된 카드 스크롤(서버 미할당, 이번 시즌 제외)
  └─ 배경 탭 / X → 닫기
[획득하기]
  └─ Hide<VanguardCardInfoPopup>() → Show<VanguardShopPopup>(배틀패스 탭) // VanguardBattlePassPanel
```

- `VanguardExclusiveChipRow`는 이미 `[SerializeField] private Button _infoButton;` 보유. **`_infoButton.onClick` → `Show<VanguardCardInfoPopup>()`** 연결만 추가(행 또는 부모 패널에서).
- 행별로 다른 내용을 보일 필요가 있으면 `Show<VanguardCardInfoPopup>(rowIndex/unitType)` 로 컨텍스트 전달(현재 스샷은 유닛 무관 공통 — §9 확인).

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 헤더 | `카드 정보` 명판 + `X` | `_titleText` + `_closeButton` |
| B | 섹션1 라벨 | `◀ 활성화 가능 ▶` | 정적 라벨 |
| C | 기능 슬롯 1 | "전투 20,40,60초 시점에 아군 수가 적군보다 적으면 무작위 카드 1장 획득" + `활성화됨` | `VanguardCardFunctionSlot`(Adversity, 활성) |
| C | 기능 슬롯 2 | "매 턴 시작 시 무작위로 활성화 가능 카드 1장 획득" + `획득하기` | `VanguardCardFunctionSlot`(Initiative, 미보유→획득) |
| D | 중앙 placeholder | `🚫 없음` | `_noneStateRoot`(활성 카드 없음 빈 상태) |
| E | 섹션2 라벨 | `◀ 비활성화됨 ▶` | 정적 라벨 |
| F | 비활성 카드 | 4장: 레이저 발사(3) / 미러링 수호(3) / 펄스 탄환(2) / 불꽃 탄환(2) + 설명 | **ScrollView + `CardInfo`(`UnitCardItem`) ×N** |
| G | 닫기 안내 | `-빈 곳을 눌러 닫기-` | `_backgroundButton` + 안내 |

- 카드(F)는 청록 = 일반(`ECardType`), 랭크 숫자(좌하단 원). `UnitCardItem`이 이름/설명/랭크/아이콘/타입색 처리.
- 기능 슬롯(C) 텍스트 = 위키 매핑: 1=Adversity Boost(20/40/60s, 항상), 2=Initiative Boost(라운드 시작 랜덤 카드 = Ember/Vanguard Pass 특전).

### 기능 슬롯 버튼 상태

| 상태 | 버튼 | 의미 |
|---|---|---|
| 항상 활성(Adversity) | `활성화됨`(비활성/라벨) | 무료 기본 기능 |
| 미보유(Initiative) | `획득하기`(활성) | 클릭 → 배틀패스 이동 |
| 보유(패스 구매 후) | `활성화됨` | 이미 획득 |

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **CardInfo (UnitCardItem)** | `3_Prefabs/UI/CardInfo/CardInfo.prefab` (`UI/Components/UnitCardItem.cs`) | 비활성 카드 1장 | `Initialize(UnitCardDisplayData, ICardDetailDisplay)` |
| **UnitCardDisplayData** | `UI/Data/UnitCardDisplayData.cs` | 카드 표시 데이터 | `CreateFromCardData(CardDataSO, isUnlocked, currentLevel)` |
| **CardDataSO** | `SOs/SO/DataSheet/CardDataSO.cs` | 카드 원본 | `cardName`/`cardDescription`/`cardType`/`cardRank` |
| **VanguardExclusiveChipRow** | `UI/Vanguard/Component/VanguardExclusiveChipRow.cs` | Btn_Info 진입점 | `_infoButton` (이미 존재) |
| **VanguardShopPopup** | `UI/Vanguard/Popup/VanguardShopPopup.cs` | 배틀패스 이동 대상 | `_battlePassPanel`(`VanguardBattlePassPanel`) 보유 |
| **VanguardBattlePassPanel** | `UI/Vanguard/Component/VanguardBattlePassPanel.cs` | Initiative 획득처 | `ShowPanel()` (BattlePassPanelBase) |
| **VanguardInfoPopup**(패턴) | [[2026-06-04_vanguard-info-popup-ui]] | 배경 탭 닫기 + 섹션 라벨 + 스케일 연출 | `_backgroundButton`+`PlayShowAnimation` |
| (선택) **CardDetailPanelBase** | `UI/Panels/CardDetailPanelBase.cs` | 카드 클릭 상세 | `ICardDetailDisplay.ShowCardDetail` |

### 신규 작성 (2개 + 데이터)

- `VanguardCardInfoPopup.cs`(본체, `ICardDetailDisplay` 구현 — 카드 클릭 상세 선택).
- `VanguardCardFunctionSlot.cs`(기능 1행: 설명 + 활성화됨/획득하기 버튼).
- `IVanguardCardInfoProvider`(기능 2종 상태 + 비활성 카드 리스트) — 미연동 → 더미.

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> 신규 `VanguardCardInfoPopup.prefab`(`Resources_moved/UI/`). 루트 `VanguardCardInfoPopup.cs`. **전체 화면**(stretch + 딤/불투명 배경). `uiPosition=Popup`.

```
VanguardCardInfoPopup (루트, ▶ VanguardCardInfoPopup.cs, 전체화면)
├─ Background (Image + Button, 화면 전체)               → _backgroundButton (빈 곳 탭 닫기)
│  └─ CloseHintText ("-빈 곳을 눌러 닫기-")             (정적)
├─ Window
│  ├─ Header
│  │  ├─ TitleText ("카드 정보")                        → _titleText
│  │  └─ Btn_Close (X)                                  → _closeButton
│  ├─ Section1Label ("활성화 가능")
│  ├─ FunctionScroll (ScrollRect ①)                     → _functionScrollRect
│  │  └─ Viewport/Content (VerticalLayoutGroup)         → _functionContent
│  │     └─ (런타임) VanguardCardFunctionSlot xN         → _functionSlotPrefab
│  ├─ NoneState ("🚫 없음", 중앙)                        → _noneStateRoot
│  ├─ Section2Label ("비활성화됨")
│  └─ CardScroll (ScrollRect ②, 가로 또는 그리드)        → _cardScrollRect
│     └─ Viewport/Content (HorizontalLayoutGroup/Grid)  → _cardContent
│        └─ (런타임) CardInfo(UnitCardItem) xN           → _cardItemPrefab
└─ (선택) CardDetailPanel (카드 클릭 상세, 기본 비활성)   → _cardDetailPanel
```

- 비활성 카드 스크롤(②): 스샷은 가로 4장(가로 스크롤). `HorizontalLayoutGroup` + `ScrollRect`(horizontal). 카드 수 많으면 그리드도 가능.
- 기능 스크롤(①): 세로 2슬롯(스샷). 더 많으면 스크롤. `VerticalLayoutGroup`.
- 섹션 라벨(`◀ … ▶`)은 [[2026-06-04_vanguard-info-popup-ui]] 스타일 아트 재사용.

---

## 5. 스크립트 설계

### 5-1. 데이터 공급 (더미/서버 추상화)

```csharp
using System.Collections.Generic;

/// <summary> 카드 정보 팝업 데이터. 기능 2종 상태 + 비활성(미할당) 카드 리스트. 서버 미연동 단계는 더미. </summary>
public interface IVanguardCardInfoProvider
{
    // 활성화 가능 기능 (스샷=2). 항상활성 + 패스 특전.
    IReadOnlyList<VanguardCardFunctionInfo> GetFunctions();
    // 이번 시즌 서버 미할당(비활성) 카드
    List<CardDataSO> GetDeactivatedCards();
}

public class VanguardCardFunctionInfo
{
    public string descriptionKey;   // 로컬라이즈 키
    public bool isActivated;        // true=활성화됨 / false=획득하기
    public bool acquirableViaPass;  // 획득하기 버튼 노출 여부(패스 특전)
}
```

- 더미 `VanguardCardInfoProviderStub`:
  - `GetFunctions()` → [ {Adversity, isActivated=true, acquirable=false}, {Initiative, isActivated=(패스 보유?), acquirable=true} ].
  - `GetDeactivatedCards()` → CardDataSO 더미 4장(레이저 발사/미러링 수호/펄스 탄환/불꽃 탄환).
- 정식: 기능 활성은 `BattlePassManager`/패스 보유 체크(Initiative=Ember/Vanguard Pass 특전, 위키). 비활성 카드는 서버 시즌 세트의 여집합.

### 5-2. `VanguardCardFunctionSlot.cs` (신규)

```csharp
using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary> "활성화 가능" 기능 1행: 설명 + (활성화됨 라벨 / 획득하기 버튼). </summary>
public class VanguardCardFunctionSlot : MonoBehaviour
{
    [SerializeField] private TextMeshProUGUI _descriptionText;
    [SerializeField] private GameObject _activatedBadge;  // "활성화됨"
    [SerializeField] private Button _acquireButton;       // "획득하기"

    private Action _onAcquire;

    private void Awake() => _acquireButton.onClick.AddListener(() => _onAcquire?.Invoke());

    public void Bind(VanguardCardFunctionInfo info, Action onAcquire)
    {
        _onAcquire = onAcquire;
        if (_descriptionText != null) _descriptionText.text = LocalizationManager.GetLocalizedText(info.descriptionKey);

        bool showAcquire = !info.isActivated && info.acquirableViaPass;
        if (_activatedBadge != null) _activatedBadge.SetActive(info.isActivated);
        if (_acquireButton != null) _acquireButton.gameObject.SetActive(showAcquire);
    }
}
```

### 5-3. `VanguardCardInfoPopup.cs` (참조 구현)

```csharp
using System.Collections.Generic;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 카드 정보 팝업: 상단 "활성화 가능" 기능 슬롯 + 하단 "비활성화됨" 카드 스크롤. 전체 화면.
/// VanguardExclusiveChipRow.Btn_Info 진입. 두 번째 기능 "획득하기" → 뱅가드 배틀패스.
/// </summary>
public class VanguardCardInfoPopup : UIBase, ICardDetailDisplay
{
    #region Serialized
    [Header("배경/헤더")]
    [SerializeField] private Button _backgroundButton;
    [SerializeField] private CanvasGroup _backgroundCanvasGroup;
    [SerializeField] private GameObject _popupContainer;
    [SerializeField] private TextMeshProUGUI _titleText;
    [SerializeField] private Button _closeButton;

    [Header("① 활성화 가능 기능")]
    [SerializeField] private ScrollRect _functionScrollRect;
    [SerializeField] private Transform _functionContent;
    [SerializeField] private VanguardCardFunctionSlot _functionSlotPrefab;

    [Header("중앙 없음")]
    [SerializeField] private GameObject _noneStateRoot;

    [Header("② 비활성화된 카드")]
    [SerializeField] private ScrollRect _cardScrollRect;
    [SerializeField] private Transform _cardContent;
    [SerializeField] private UnitCardItem _cardItemPrefab;

    [Header("카드 상세 (선택)")]
    [SerializeField] private GameObject _cardDetailPanel;

    [Header("연출")]
    [SerializeField] private float _animationDuration = 0.25f;

    [Header("[TEST]")]
    [SerializeField] private bool _useDummy = true;
    #endregion

    private IVanguardCardInfoProvider _provider;
    private UIManager _uiManager;
    private readonly List<GameObject> _functionSlots = new();
    private readonly List<GameObject> _cardItems = new();
    private Sequence _showSequence;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _backgroundButton?.onClick.AddListener(ClosePopup);
        _closeButton?.onClick.AddListener(ClosePopup);
        if (_popupContainer != null) _popupContainer.transform.localScale = Vector3.zero;
        if (_backgroundCanvasGroup != null) _backgroundCanvasGroup.alpha = 0f;
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _uiManager = Managers.Instance.GetManager<UIManager>();
        _provider = _useDummy ? new VanguardCardInfoProviderStub()
                              : Managers.Instance.GetManager<VanguardManager>()?.CardInfoProvider; // TODO

        if (_titleText != null) _titleText.text = LocalizationManager.GetLocalizedText("vanguard_card_info_title");
        if (_cardDetailPanel != null) _cardDetailPanel.SetActive(false);

        BuildFunctions();
        BuildDeactivatedCards();
        PlayShowAnimation();
    }

    public override void Closed(object[] param)
    {
        _showSequence?.Kill();
        ClearList(_functionSlots);
        ClearList(_cardItems);
        base.Closed(param);
    }

    // ─────────── ① 기능 슬롯 ───────────
    private void BuildFunctions()
    {
        ClearList(_functionSlots);
        var funcs = _provider.GetFunctions();
        foreach (var f in funcs)
        {
            var slot = Instantiate(_functionSlotPrefab, _functionContent);
            var captured = f;
            slot.Bind(captured, onAcquire: () => OnAcquireFunction(captured));
            _functionSlots.Add(slot.gameObject);
        }
        // "없음": 현재 활성(보유) 기능/카드가 하나도 없을 때 표기 (정책 §9 — 우선 항상 숨김 또는 활성 카드 0개일 때 표시)
        if (_noneStateRoot != null) _noneStateRoot.SetActive(false);
    }

    private void OnAcquireFunction(VanguardCardFunctionInfo info)
    {
        // 두 번째 기능(Initiative) 획득 → 뱅가드 배틀패스로 이동
        ClosePopup();
        var shop = _uiManager.Show<VanguardShopPopup>(/* TODO: 배틀패스 탭 지정 param */);
        // shop?.OpenBattlePassTab();  // VanguardShopPopup에 탭 전환 API 필요(§9). 내부 _battlePassPanel.ShowPanel()
    }

    // ─────────── ② 비활성 카드 ───────────
    private void BuildDeactivatedCards()
    {
        ClearList(_cardItems);
        var cards = _provider.GetDeactivatedCards();
        if (cards == null) return;
        foreach (var so in cards)
        {
            var item = Instantiate(_cardItemPrefab, _cardContent);
            // 비활성=잠금 표현. isUnlocked=false → UnitCardItem이 반투명/잠금 오버레이 처리.
            var display = UnitCardDisplayData.CreateFromCardData(so, isUnlocked: false, currentLevel: 0);
            item.Initialize(display, this);
            _cardItems.Add(item.gameObject);
        }
    }

    // ICardDetailDisplay — 카드 클릭 상세 (선택)
    public void ShowCardDetail(UnitCardDisplayData cardData) { /* _cardDetailPanel 또는 CardDetailPanelBase 재사용 */ }

    // ─────────── 닫기/연출 ───────────
    private void ClosePopup() => _uiManager?.Hide<VanguardCardInfoPopup>();

    private void PlayShowAnimation()
    {
        _showSequence?.Kill();
        _showSequence = DOTween.Sequence().SetUpdate(true);
        if (_backgroundCanvasGroup != null) _showSequence.Append(_backgroundCanvasGroup.DOFade(0.85f, _animationDuration));
        if (_popupContainer != null)
        {
            _popupContainer.transform.localScale = Vector3.zero;
            _showSequence.Join(_popupContainer.transform.DOScale(1f, _animationDuration).SetEase(Ease.OutBack));
        }
    }

    private void ClearList(List<GameObject> list)
    {
        foreach (var go in list) if (go != null) Destroy(go);
        list.Clear();
    }
}
```

### 5-4. Localization 키 (신규)

| 키 | 내용 |
|---|---|
| `vanguard_card_info_title` | 카드 정보 |
| `vanguard_func_adversity_desc` | 전투 20,40,60초 시점에 아군 수가 적군보다 적으면 무작위 카드 1장 획득 |
| `vanguard_func_initiative_desc` | 매 턴 시작 시 무작위로 활성화 가능 카드 1장 획득 |
| `vanguard_func_activated` | 활성화됨 |
| `vanguard_func_acquire` | 획득하기 |
| `vanguard_section_activatable` / `vanguard_section_deactivated` | 활성화 가능 / 비활성화됨 |
| `vanguard_none` | 없음 |
| (재사용) 카드 `cardName`/`cardDescription` | UnitCardItem이 로컬라이즈 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 기능 2종 활성 상태 | 부분 | Adversity=항상 활성. Initiative=Ember/Vanguard Pass 특전 보유 여부(`BattlePassManager`/패스 체크). 더미는 [true, false] |
| 비활성(미할당) 카드 | ⚠️ 서버 | 이번 시즌 서버 세트의 여집합. `IVanguardCardInfoProvider.GetDeactivatedCards` — 더미 4장 |
| 획득하기 → 배틀패스 | 부분 | `VanguardShopPopup`이 `_battlePassPanel`(`VanguardBattlePassPanel`) 보유 → 탭 전환 API 필요(§9). 내부 `ShowPanel()` |
| "없음" 표기 조건 | ⚠️ 의미 미확정 | 중앙 placeholder — 현재 활성 카드 없음 표시로 가정(§9) |
| Btn_Info 컨텍스트 | 확인 | 행/유닛 무관 공통 vs 행별 — `Show<VanguardCardInfoPopup>(ctx)` |

### CLAUDE.md 준수
- `GetManager<T>()`만 / DOTween 사용 / `async void` 금지 / 텍스트 로컬라이즈 / `Closed`에서 슬롯·카드 정리 / 매직넘버 const.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardCardFunctionInfo` + `IVanguardCardInfoProvider` + `VanguardCardInfoProviderStub`(기능 2 + 비활성 카드 4) 작성.
2. [ ] `VanguardCardFunctionSlot.cs` 작성(5-2).
3. [ ] `VanguardCardInfoPopup.cs` 작성(5-3, `ICardDetailDisplay`). 빌드-그린.

**B. 프리팹** (`VanguardCardInfoPopup.prefab` 신규, 전체화면)

4. [ ] 루트 stretch + Background(탭 닫기)+안내 / Window / 헤더(타이틀+X).
5. [ ] 섹션1 라벨 + FunctionScroll(VerticalLayout) → `_functionContent`, `_functionSlotPrefab`(VanguardCardFunctionSlot).
6. [ ] NoneState("없음") → `_noneStateRoot`.
7. [ ] 섹션2 라벨 + CardScroll(HorizontalLayout) → `_cardContent`, `_cardItemPrefab`=`CardInfo.prefab`.
8. [ ] `VanguardCardFunctionSlot.prefab` 제작(설명 텍스트 + 활성화됨 라벨 + 획득하기 버튼).
9. [ ] 필드 연결 + `Resources_moved/UI/`에 클래스명 저장.

**C. 연동**

10. [ ] `VanguardExclusiveChipRow._infoButton.onClick` → `Show<VanguardCardInfoPopup>()` (행 또는 부모에서).
11. [ ] 획득하기 → `VanguardShopPopup` 배틀패스 탭 전환 API 연결.
12. [ ] Localization 키 추가, `_useDummy=true` 테스트(기능 2 + 비활성 카드 4 + 획득하기 이동).

---

## 8. 검증 체크리스트

- [ ] `Btn_Info` → 전체 화면 카드 정보 팝업 오픈(스케일+페이드), 배경 탭/X 닫기.
- [ ] 상단 기능 2슬롯: 1번 "활성화됨"(버튼 없음), 2번 "획득하기"(버튼 활성).
- [ ] "획득하기" → 팝업 닫고 뱅가드 배틀패스(VanguardShopPopup 배틀패스 탭) 진입.
- [ ] 중앙 "없음" placeholder 표시(조건부).
- [ ] 하단 비활성 카드: 이름/설명/랭크/아이콘 + 잠금(반투명) 표현, 가로 스크롤.
- [ ] 카드 클릭 시 상세(구현 시) / 미구현 시 안전.
- [ ] `Closed`에서 슬롯·카드 정리(누수 없음).
- [ ] CLAUDE.md 준수(GetManager/로컬라이즈/async void 없음).

---

## 9. 미해결 / 확인 필요

- [ ] **"없음"(중앙) 의미**: 현재 활성/획득한 카드 없음 표시인지, 별도 섹션 빈 상태인지 — 실게임 확인 후 `_noneStateRoot` 표시 조건 확정.
- [ ] **기능(Adversity/Initiative) 활성 판정 소스**: Initiative = 어떤 패스(Ember/Vanguard) 특전인지 + `BattlePassManager` 보유 체크 경로.
- [ ] **VanguardShopPopup 배틀패스 탭 전환 API**: `OpenBattlePassTab()` 류 public 진입점 필요(현재 `_battlePassPanel` private). 추가 또는 `Show<VanguardShopPopup>(param)` 규약.
- [ ] **비활성 카드 정의/소스**: "서버가 할당하지 않은 이번 시즌 카드" 정확 산출(시즌 세트 여집합) → [[2026-05-31_vanguard-server-api-spec]].
- [ ] **Btn_Info 컨텍스트**: 행/유닛 공통인지 행별인지 — 공통이면 파라미터 불필요.
- [ ] **카드 클릭 상세**: 전용 패널 vs `CardDetailPanelBase` 재사용.

---

> 작성: 2026-06-04 · 선행 코드 확인: `VanguardExclusiveChipRow`(`_infoButton` 존재), `UnitCardItem`/`UnitCardDisplayData.CreateFromCardData`/`CardDataSO`, `CardInfo.prefab`(=UnitCardItem), `VanguardShopPopup`(`_battlePassPanel`=`VanguardBattlePassPanel` 호스팅), `VanguardBattlePassPanel.ShowPanel`. 스샷(카드 정보/활성화 가능 기능 2 + 없음 + 비활성 카드 스크롤) 1:1 매핑. 두 스크롤뷰 구조 반영. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
