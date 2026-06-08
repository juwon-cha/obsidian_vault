# Vanguard 유닛 상세 팝업(VanguardUnitDetailPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

`VanguardUnitSetupPopup`의 **ExclusiveChipPanel**에서 **`VanguardChipSlot`이 "장착 가능" 상태일 때 클릭**하면 뜨는 팝업(첨부 이미지: 유닛(수호자) + 칩 슬롯 4개 + 해당 유닛 카드 8장)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- **네이밍 제안**: `VanguardUnitInfoPopup` → **`VanguardUnitDetailPopup`** 권장. 근거: 재활용 대상이 `ChipSlotDisplay Variant - **EquipmentDetailPopup**`이고, 위키 정의가 "터렛을 탭하면 **사용 중 카드 + 장착 칩**을 본다"(Detail 성격). `Info`는 시즌 규칙 팝업([[2026-06-04_vanguard-info-popup-ui]] `VanguardInfoPopup`)과 혼동 → **Detail**로 구분. (이하 `VanguardUnitDetailPopup` 사용)
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]](부모 = 터렛/유닛 장착 팝업·칩 슬롯), [[2026-06-04_vanguard-info-popup-ui]](배경 탭 닫기 패턴)
- `[설계 판단]` = 스샷/위키 미표기 보완.

> ⚠️ **부모 네이밍 정합**: 본 문서는 사용자 현행 명칭 `VanguardUnitSetupPopup` / `ExclusiveChipPanel` / `VanguardChipSlot` 을 부모로 가정한다. (이는 [[2026-06-03_vanguard-turret-setup-ui]]의 `VanguardTurretSetupPopup`/`VanguardExclusiveChipRow`/`ChipSlotDisplay`가 발전·개명된 형태로 본다. 클래스명만 현행에 맞추면 됨.)

---

## 0. 결론 먼저 (TL;DR)

| 항목    | 결정                                                                                                        |
| ----- | --------------------------------------------------------------------------------------------------------- |
| 클래스   | 신규 `VanguardUnitDetailPopup : UIBase`(+`ICardDetailDisplay`) + `VanguardChipCardProvider`(더미/서버)          |
| 프리팹   | 신규 `Resources_moved/UI/VanguardUnitDetailPopup.prefab` (`Show<T>` 로드 규약)                                  |
| 진입    | `VanguardChipSlot`(장착 가능 상태) 클릭 → `Show<VanguardUnitDetailPopup>(unitType)`                               |
| 유닛    | 좌측 대형 유닛 이미지 + 이름(수호자) — `CardVisualConfig.GetUnitIconPath(unitType)`                                     |
| 칩 슬롯  | 유닛 우측 세로 4슬롯 — **`ChipSlotDisplay Variant - EquipmentDetailPopup` 재활용**(`SetState(EChipSlotState, Chip)`) |
| 카드 8장 | 하단 ScrollView — **`CardInfo`(`UnitCardItem`) 재활용**(`Initialize(UnitCardDisplayData, this)`)               |
| 데이터   | 서버 제공 8장(미연동 → `_useDummy` 더미). 칩 슬롯 상태는 부모 `VanguardChipService`/Provider                                |
| 닫기    | **배경(빈 곳) 탭 닫기** (`-빈 곳을 눌러 닫기-`) — 별도 X 없음                                                               |

---

## 1. 진입 플로우

```
VanguardUnitSetupPopup > ExclusiveChipPanel > VanguardChipSlot (장착 가능 상태) 클릭
  └─ Show<VanguardUnitDetailPopup>(EUnitType unitType)   // 어떤 유닛(수호자 등)인지 전달
       ├─ 유닛 이미지/이름 표시
       ├─ 해당 유닛의 칩 슬롯 4개 상태 표시 (미장착/해금80/잠김…)
       └─ 해당 유닛 카드 8장 표시 (서버/더미)
  └─ 배경 탭 → 닫기
```

- `VanguardChipSlot`의 "장착 가능" 상태 = `EChipSlotState.Empty`(해금됐고 빈 슬롯). 그 클릭 콜백(`OnEmptySlotClicked` 또는 본 슬롯의 클릭)이 `Show<VanguardUnitDetailPopup>(unitType)` 호출.
- 파라미터: `param[0] is EUnitType`(유닛 식별). 슬롯 인덱스도 필요하면 `param[1] is int`.

> `EUnitType`로 유닛/카드/칩슬롯을 모두 조회. 부모가 어떤 유닛 행을 눌렀는지만 넘기면 됨.

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 상단 재화 | 좌상단 ◆`0` | `_currencyText`(선택, Standard DS) |
| B | 유닛 패널 | `수호자` 헤더 + 대형 메크 이미지 | `_unitNameText` + `_unitImage` |
| C | 칩 슬롯 1 | `미장착` | `_chipSlots[0]` (`EChipSlotState.Empty`) |
| C | 칩 슬롯 2 | `해금에 ◆80 가 필요합니다` + `해금` | `_chipSlots[1]` (`EChipSlotState.Unlockable`, cost 80) |
| C | 칩 슬롯 3·4 | 🔒 `먼저 이전 슬롯을 해제해 주세요` | `_chipSlots[2..3]` (`EChipSlotState.CantUnequip`=잠김 표기 / 또는 Locked 상태) |
| D | 카드 그리드 | 8장(2×4): 에너지 가동 / 일제 사격 탄환 / 급속 사격 / 충격 탄환(보라) / 지속 에너지 충전 / 일제 사격 탄환 / 관통 탄환 / 관통 강화(보라) | **ScrollView + `CardInfo`(`UnitCardItem`) ×8** |
| E | 닫기 안내 | `-빈 곳을 눌러 닫기-` | `_backgroundButton` + 안내 텍스트 |

### 칩 슬롯 상태 매핑 (`EChipSlotState` — 기존 enum)

| 스샷 | 상태 | ChipSlotDisplay 표시 |
|---|---|---|
| 미장착 | `Empty` | 빈 슬롯(장착 가능, 클릭 시 칩 선택) |
| 장착됨(있을 때) | `Equipped` | 칩 아이콘 + 해제 버튼 |
| 해금 80 | `Unlockable` | "해금" 버튼 + 비용(`OnUnlockClicked`) |
| 먼저 이전 슬롯 해제 | `CantUnequip` 또는 Locked | 🔒 + 안내(선행 슬롯 미해금) |

> 슬롯 4개 비용 구조 = 무료/80/150/220([[2026-05-29_vanguard-implementation-plan-outgame]] 3장). 스샷의 "해금 80" = 2번째 슬롯. 3·4번째는 선행 미해금이라 잠김.

### 카드 타입/색상

- 청록(일반) = `ECardType.Common/Spawn`, 보라(충격 탄환·관통 강화) = `Combo`/`Promotion` 등. `UnitCardItem`이 `cardType`으로 배경/텍스트 색 자동 처리(`UpdateVisualStyle`/`UpdateCardTextColor`).

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **ChipSlotDisplay Variant - EquipmentDetailPopup** | `3_Prefabs/UI/Equipment/ChipSlotDisplay Variant - EquipmentDetailPopup.prefab` (`UI/Components/ChipSlotDisplay.cs`) | **칩 슬롯 4개 그대로** | `SetState(EChipSlotState, Chip)` · `OnUnlockClicked`/`OnUnequipClicked`/`OnEquippedChipClicked`/`OnEmptySlotClicked` · `PlayEffect()` |
| **CardInfo (UnitCardItem)** | `3_Prefabs/UI/CardInfo/CardInfo.prefab` (`UI/Components/UnitCardItem.cs`) | **카드 1장 그대로** | `Initialize(UnitCardDisplayData, ICardDetailDisplay)` · 내부서 이름/설명/랭크/아이콘/타입색 처리 |
| **UnitCardDisplayData** | `UI/Data/UnitCardDisplayData.cs` | 카드 표시 데이터 | `CreateFromCardData(CardDataSO, isUnlocked, currentLevel)` |
| **CardDataSO** | `SOs/SO/DataSheet/CardDataSO.cs` | 카드 원본 | `cardName`/`cardDescription`/`cardType`/`targetUnit`/`cardRank` |
| **CardVisualConfig** | (UnitCardItem이 사용) | 유닛 아이콘 경로 | `GetUnitIconPath(EUnitType)` → `ResourceManager.LoadResource<Sprite>` |
| **VanguardPopupBase** | `UI/Vanguard/Popup/VanguardPopupBase.cs` | 베이스(선택) | `uiPosition=Popup` · `ClosePopup()` |
| **VanguardInfoPopup**(패턴) | [[2026-06-04_vanguard-info-popup-ui]] | 배경 탭 닫기 + 스케일 연출 패턴 | `_backgroundButton`+`PlayShowAnimation` |

### 신규 작성 (2개 + 데이터)

- `VanguardUnitDetailPopup.cs`(본체, `ICardDetailDisplay` 구현).
- `VanguardChipCardProvider`(또는 인터페이스) — 유닛별 카드 8장 + 칩 슬롯 상태 공급(서버 미연동 → 더미).
- (선택) 카드 상세 패널 `ShowCardDetail` 처리 — 기존 `CardDetailPanelBase` 재사용 가능(§9).

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> 신규 `VanguardUnitDetailPopup.prefab`(`Resources_moved/UI/`). 루트 `VanguardUnitDetailPopup.cs`, `uiPosition=Popup`. `VanguardInfoPopup`의 배경 탭 닫기 패턴 답습.

```
VanguardUnitDetailPopup (루트, ▶ VanguardUnitDetailPopup.cs)
├─ Background (Image + Button)                          → _backgroundButton (빈 곳 탭 닫기)
│  └─ CloseHintText ("-빈 곳을 눌러 닫기-")             (정적 라벨)
├─ TopCurrency (◆ 0)                                    → _currencyText (선택)
├─ TopSection (HorizontalLayout)
│  ├─ UnitPanel
│  │  ├─ UnitNameText ("수호자")                        → _unitNameText
│  │  └─ UnitImage (대형 메크)                          → _unitImage
│  └─ ChipSlotColumn (VerticalLayout, 4슬롯)
│     └─ [ChipSlotDisplay Variant x4] [재사용]          → _chipSlots[4]
├─ CardSection
│  └─ ScrollRect (세로 또는 그리드)                      → _cardScrollRect
│     └─ Viewport/Content (GridLayoutGroup, 4열)        → _cardContent
│        └─ (런타임) CardInfo(UnitCardItem) x8           → _cardItemPrefab
└─ (선택) CardDetailPanel (카드 클릭 상세, 기본 비활성)   → _cardDetailPanel
```

- 카드 그리드: 스샷은 2행 4열. `GridLayoutGroup`(Constraint=Fixed Column Count=4) + `ScrollRect`(8장 이상 시 스크롤). `ContentSizeFitter` 권장.
- 칩 슬롯 컬럼: 유닛 패널 우측에 세로 4개(`ChipSlotDisplay Variant` 인스턴스를 프리팹에 직접 배치 → `_chipSlots[4]` 연결).

---

## 5. 스크립트 설계

### 5-1. 데이터 공급 (더미/서버 추상화)

```csharp
using System.Collections.Generic;

/// <summary> 유닛 상세에 필요한 데이터 공급. 서버 미연동 단계는 더미. </summary>
public interface IVanguardUnitDetailProvider
{
    // 유닛 카드 8장 (서버 제공 고정 세트, ingame §5-2)
    List<CardDataSO> GetUnitCards(EUnitType unitType);
    // 칩 슬롯 상태 (4개)
    int SlotCount { get; }                       // 4
    EChipSlotState GetSlotState(EUnitType unitType, int slotIndex);
    Chip GetEquippedChip(EUnitType unitType, int slotIndex);
    int GetSlotUnlockCost(EUnitType unitType, int slotIndex); // 무료/80/150/220
}
```

- 더미 구현 `VanguardUnitDetailProviderStub`: `GetUnitCards`는 `ResourceManager`로 카드 SO 8개 로드 또는 인스펙터 주입 더미 리스트. 슬롯 상태는 [Empty, Unlockable(80), Locked, Locked] 고정.
- 정식: `VanguardManager.ChipService`/서버 카드 세트와 연결.

### 5-2. `VanguardUnitDetailPopup.cs` (참조 구현)

```csharp
using System.Collections.Generic;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 유닛 상세 팝업: 유닛 이미지 + 칩 슬롯 4개(ChipSlotDisplay 재활용) + 카드 8장(CardInfo 재활용).
/// VanguardUnitSetupPopup의 VanguardChipSlot(장착 가능) 클릭 시 Show<T>(unitType).
/// </summary>
public class VanguardUnitDetailPopup : UIBase, ICardDetailDisplay
{
    #region Serialized
    [Header("배경/닫기")]
    [SerializeField] private Button _backgroundButton;
    [SerializeField] private CanvasGroup _backgroundCanvasGroup;
    [SerializeField] private GameObject _popupContainer;

    [Header("유닛")]
    [SerializeField] private TextMeshProUGUI _unitNameText;
    [SerializeField] private Image _unitImage;
    [SerializeField] private TextMeshProUGUI _currencyText;

    [Header("칩 슬롯 (ChipSlotDisplay Variant - EquipmentDetailPopup x4)")]
    [SerializeField] private ChipSlotDisplay[] _chipSlots; // 4

    [Header("카드 (CardInfo / UnitCardItem)")]
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

    private EUnitType _unitType;
    private IVanguardUnitDetailProvider _provider;
    private readonly List<GameObject> _cardItems = new();
    private Sequence _showSequence;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _backgroundButton?.onClick.AddListener(ClosePopup);
        if (_popupContainer != null) _popupContainer.transform.localScale = Vector3.zero;
        if (_backgroundCanvasGroup != null) _backgroundCanvasGroup.alpha = 0f;
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _unitType = (param != null && param.Length > 0 && param[0] is EUnitType t) ? t : default;
        _provider = _useDummy ? new VanguardUnitDetailProviderStub()
                              : Managers.Instance.GetManager<VanguardManager>()?.UnitDetailProvider; // TODO

        SetupUnit();
        SetupChipSlots();
        SetupCards();
        if (_cardDetailPanel != null) _cardDetailPanel.SetActive(false);
        PlayShowAnimation();
    }

    public override void Closed(object[] param)
    {
        _showSequence?.Kill();
        ClearCards();
        base.Closed(param);
    }

    // ─────────── 유닛 ───────────
    private void SetupUnit()
    {
        if (_unitNameText != null) _unitNameText.text = LocalizationManager.GetLocalizedText(GetUnitNameKey(_unitType));
        if (_unitImage != null)
        {
            string path = CardVisualConfig.GetUnitIconPath(_unitType);
            _unitImage.sprite = Managers.Instance.GetManager<ResourceManager>().LoadResource<Sprite>(path);
        }
        // 재화 표기(선택)
    }

    // ─────────── 칩 슬롯 (ChipSlotDisplay 재활용) ───────────
    private void SetupChipSlots()
    {
        if (_chipSlots == null) return;
        for (int i = 0; i < _chipSlots.Length; i++)
        {
            int idx = i;
            var slot = _chipSlots[i];
            if (slot == null) continue;

            var state = _provider.GetSlotState(_unitType, idx);
            var chip = _provider.GetEquippedChip(_unitType, idx);
            slot.SetState(state, chip);

            slot.OnUnlockClicked      = () => OnSlotUnlock(idx);
            slot.OnEmptySlotClicked   = () => OnSlotEmptyClicked(idx);   // 칩 장착 흐름(부모 위임)
            slot.OnUnequipClicked     = () => OnSlotUnequip(idx);
            slot.OnEquippedChipClicked= () => OnSlotEmptyClicked(idx);   // 스왑
        }
    }

    private void OnSlotUnlock(int idx)
    {
        int cost = _provider.GetSlotUnlockCost(_unitType, idx);
        // TODO: 부모/서비스 UnlockSlotAsync (서버 권위). 성공 시 SetupChipSlots 재호출.
    }
    private void OnSlotEmptyClicked(int idx) { /* 칩 인벤토리에서 선택→장착 (부모 ExclusiveChipPanel 흐름과 연계) */ }
    private void OnSlotUnequip(int idx) { /* 해제 (서버 권위) → 재표시 */ }

    // ─────────── 카드 8장 (CardInfo 재활용) ───────────
    private void SetupCards()
    {
        ClearCards();
        var cards = _provider.GetUnitCards(_unitType);
        if (cards == null) return;
        foreach (var so in cards)
        {
            var item = Instantiate(_cardItemPrefab, _cardContent);
            // 상세 팝업에선 전부 해금 표시(=true). 잠금 표기 필요 시 provider가 판단.
            var display = UnitCardDisplayData.CreateFromCardData(so, isUnlocked: true, currentLevel: 0);
            item.Initialize(display, this);  // this = ICardDetailDisplay
            _cardItems.Add(item.gameObject);
        }
    }

    private void ClearCards()
    {
        foreach (var go in _cardItems) if (go != null) Destroy(go);
        _cardItems.Clear();
    }

    // ICardDetailDisplay — 카드 클릭 시 상세 표시 (선택)
    public void ShowCardDetail(UnitCardDisplayData cardData)
    {
        // 선택: _cardDetailPanel 활성 + 내용 채움, 또는 기존 CardDetailPanelBase 재사용. 미구현 시 무시 가능.
    }

    // ─────────── 닫기/연출 ───────────
    private void ClosePopup() => Managers.Instance.GetManager<UIManager>()?.Hide<VanguardUnitDetailPopup>();

    private void PlayShowAnimation()
    {
        _showSequence?.Kill();
        _showSequence = DOTween.Sequence().SetUpdate(true);
        if (_backgroundCanvasGroup != null) _showSequence.Append(_backgroundCanvasGroup.DOFade(0.8f, _animationDuration));
        if (_popupContainer != null)
        {
            _popupContainer.transform.localScale = Vector3.zero;
            _showSequence.Join(_popupContainer.transform.DOScale(1f, _animationDuration).SetEase(Ease.OutBack));
        }
    }

    private string GetUnitNameKey(EUnitType t) => $"unit_name_{t}"; // [설계 판단] 유닛명 로컬라이즈 키 규칙
}
```

### 5-3. Localization 키 (신규/재사용)

| 키 | 내용 |
|---|---|
| `unit_name_{EUnitType}` | 유닛 표시명 (수호자 등) — 기존 유닛명 키 있으면 재사용 |
| (재사용) 카드 `cardName`/`cardDescription` | CardDataSO에 키 보유, `UnitCardItem`이 로컬라이즈 |
| (재사용) `toast_leveln` | 카드 잠금 텍스트(UnitCardDisplayData) |
| `vanguard_close_hint` | -빈 곳을 눌러 닫기- |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 유닛 카드 8장 | ⚠️ 서버 미연동 | 위키: 라운드 고정 카드 세트(전 플레이어 동일, ingame §5-2). `IVanguardUnitDetailProvider.GetUnitCards` — 더미 8장(`CardDataSO` 로드/주입) |
| 칩 슬롯 4개 상태/비용 | 부모 보유 | `VanguardChipService`/부모 `ExclusiveChipPanel`과 동일 소스. 비용 무료/80/150/220 |
| 유닛 이미지 | 기존 경로 | `CardVisualConfig.GetUnitIconPath(EUnitType)` (UnitCardItem과 동일) |
| 칩 장착/해제/해금 | 서버 권위 | 부모 흐름 위임 또는 서비스 호출(`ServerLoadingPopupUI` 래핑). 본 팝업은 표시+트리거 |
| 카드 상세(`ShowCardDetail`) | 선택 | 기존 `CardDetailPanelBase` 재사용 가능 — 1차 미구현 허용 |

### CLAUDE.md 준수
- `GetManager<T>()`만 / DOTween 사용 시 `AsyncWaitForCompletion`(대기 필요 시, ToUniTask 금지) / `async void` 금지 / 텍스트 로컬라이즈 / `Closed`에서 시퀀스 Kill + 카드 정리 / 매직넘버 const.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `IVanguardUnitDetailProvider` + `VanguardUnitDetailProviderStub`(더미 8장 + 슬롯 4상태) 작성.
2. [ ] `VanguardUnitDetailPopup.cs` 작성(5-2, `ICardDetailDisplay` 구현). 빌드-그린.
3. [ ] (정식) `VanguardManager.UnitDetailProvider` 노출 + 서버 카드 세트 연결.

**B. 프리팹**

4. [ ] `VanguardUnitDetailPopup.prefab` 신규(§4): Background(탭 닫기)+안내텍스트 / TopSection(UnitPanel + ChipSlotColumn) / CardSection(ScrollRect+Grid 4열).
5. [ ] 칩 슬롯: `ChipSlotDisplay Variant - EquipmentDetailPopup` 4개 배치 → `_chipSlots[4]`.
6. [ ] 카드: `CardInfo.prefab`을 `_cardItemPrefab`에 연결, `_cardContent`(GridLayoutGroup 4열) 설정.
7. [ ] 유닛 이미지/이름, 재화(선택), 배경 버튼 연결. `Resources_moved/UI/`에 클래스명으로 저장.

**C. 연동**

8. [ ] `VanguardChipSlot`(장착 가능 상태) 클릭 → `Show<VanguardUnitDetailPopup>(unitType)` 연결.
9. [ ] 칩 슬롯 해금/장착/해제 → 부모 `ExclusiveChipPanel`/`VanguardChipService` 경로 위임.
10. [ ] Localization 키 추가, `_useDummy=true`로 에디터 테스트(8장 + 슬롯 4상태).

---

## 8. 검증 체크리스트

- [ ] `VanguardChipSlot`(장착 가능) 클릭 → 팝업 오픈(스케일+페이드), 배경 탭 닫기.
- [ ] 유닛 이미지/이름(수호자) 정확.
- [ ] 칩 슬롯 4개: 미장착(Empty)/해금80(Unlockable)/잠김×2(선행 미해금) 상태별 표시 + 장착 시 칩 아이콘.
- [ ] 카드 8장: 이름/설명/랭크/아이콘/타입색(일반=청록, 보라=Combo/Promotion) 표시, 4열 그리드 + 스크롤.
- [ ] 카드 클릭 시 `ShowCardDetail` 동작(구현 시) / 미구현 시 무반응 안전.
- [ ] 슬롯 해금/장착 트리거가 부모 서비스로 위임되고, 성공 시 슬롯 재표시.
- [ ] `Closed`에서 카드 인스턴스 정리(누수 없음), 시퀀스 Kill.
- [ ] CLAUDE.md 준수(GetManager/로컬라이즈/async void 없음).

---

## 9. 미해결 / 확인 필요

- [ ] **부모 클래스 현행 명칭 확정**: `VanguardUnitSetupPopup`/`ExclusiveChipPanel`/`VanguardChipSlot` — [[2026-06-03_vanguard-turret-setup-ui]]와 명칭 통일(개명 반영).
- [ ] **카드 8장 구성**: 유닛 전용 칩 카드인지, 전용+공용 혼합인지(위키: 칩 뽑기는 전용+공용). 카드(`CardDataSO`)와 칩(`Chip`)의 관계 정리 — 본 화면 "카드"가 `CardDataSO`인지 `Chip` 효과인지 확정.
- [ ] **칩 슬롯 잠김 상태 enum**: `CantUnequip` 재활용 vs Locked 전용 상태 추가 — `EChipSlotState`에 "선행 미해금" 표현 확인.
- [ ] **카드 상세(`ShowCardDetail`)**: 전용 패널 vs 기존 `CardDetailPanelBase` 재사용 — 기획 결정.
- [ ] **유닛명 로컬라이즈 키**: 기존 유닛명 키 규칙 확인(`unit_name_*` 가정).
- [ ] **장착 흐름**: 칩 선택 UI를 본 팝업에서 직접 띄울지, 부모 ExclusiveChipPanel의 Bag에서 처리할지.

---

> 작성: 2026-06-04 · 선행 코드 확인: `UnitCardItem`(`Initialize(UnitCardDisplayData, ICardDetailDisplay)`/이름·설명·랭크·아이콘·타입색), `UnitCardDisplayData.CreateFromCardData`, `CardDataSO`(cardName/cardDescription/cardType/targetUnit/cardRank), `CardInfo.prefab`(=UnitCardItem), `ChipSlotDisplay Variant - EquipmentDetailPopup`(SetState/이벤트), `CardVisualConfig.GetUnitIconPath`. 스샷 레이아웃(유닛+칩슬롯4+카드8+배경탭닫기) 1:1 매핑. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
