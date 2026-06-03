# Vanguard 터렛 장착(칩) UI 구현 종합 문서 (2026-06-03)

## 문서 목적

`VanguardLobbyPanel`의 **Btn_Turret** 클릭 시 뜨는 **터렛/칩 장착 팝업(`VanguardTurretSetupPopup`)** 의 프리팹 + 스크립트를 **이 문서만 보고 한 번에** 제작할 수 있도록 정리한다.

- 첨부 레퍼런스 화면 2종: **Exclusive Chip 탭**(전용 칩 슬롯 행 목록) / **General Chip 탭**(메크 도형 + 6 범용 칩 슬롯)
- 관련 상위 계획: [[2026-05-29_vanguard-implementation-plan-outgame]] 3장(터렛 로드아웃·칩 관리 UI), [[2026-05-29_vanguard-implementation-plan-overview]]
- 본 문서의 일부 화면 구성·구분 규칙은 위키에 명시되지 않아 `[설계 판단]` 으로 표기한다(상위 문서 컨벤션 답습).

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 베이스 클래스 | `VanguardPopupBase`(이미 존재, `UIBase` 상속) → `VanguardTurretSetupPopup` 본문 채움 |
| 진입 | `VanguardLobbyPanel.OnClickTurret()` → `_uiManager.Show<VanguardTurretSetupPopup>()` **이미 연결됨** |
| 신규 스크립트 | `VanguardTurretSetupPopup.cs`(본문), `VanguardExclusiveChipRow.cs`(전용 탭 1행) — 2개 |
| 재사용 컴포넌트 | `ChipSlotDisplay`, `ChipSlotIndicator`, `ChipInventoryItem`, `ChipInfoDIsplay`, `ChipFilterPopupUI`, `TopCurrencyBoxComponent`, `RedDotComponent` |
| 참고 레퍼런스 | `EquipmentPopup.cs`(탭/인벤토리/필터/장착연출의 완성 패턴 — 그대로 축소 복제) |
| 데이터 백엔드 | `VanguardChipService`(미구현, [[2026-05-29_vanguard-implementation-plan-outgame]] T1) → **어댑터 인터페이스로 추상화**, 当面 스텁/테스트 데이터로 빌드 가능 |
| 재화 | `ECurrencyType.VanguardStandardDS`(슬롯 해제) |

> ⚠️ Vanguard 칩 인벤토리는 본 게임 `ChipManager`와 **분리**된다(`VanguardChipService`, 시즌 리셋 대상). UI 컴포넌트(`ChipSlotDisplay`/`ChipInventoryItem`)는 동일하게 재사용하되, **데이터 소스는 Vanguard 전용 서비스**여야 한다. 서비스 미구현 단계에서는 `IVanguardChipProvider` 어댑터로 분리해 컴파일-그린 + 테스트 데이터로 선개발한다.

---

## 1. 진입점 (확인된 코드)

`Assets/_Project/1_Scripts/UI/Vanguard/Component/VanguardLobbyPanel.cs`

```csharp
[SerializeField] private Button _turretButton;     // ← Btn_Turret
[SerializeField] private RedDotComponent _turretRedDot;
...
_turretButton.onClick.AddListener(OnClickTurret);  // Initialize()에서 1회 바인딩
...
private void OnClickTurret() => _uiManager?.Show<VanguardTurretSetupPopup>();
```

`Assets/_Project/1_Scripts/UI/Vanguard/Popup/VanguardTurretSetupPopup.cs` — **현재 빈 스켈레톤**:

```csharp
/// <summary> Vanguard 터렛/칩 세팅 팝업 (스켈레톤). 9터렛 로드아웃·칩 관리 — 내용은 후속 STEP. </summary>
public class VanguardTurretSetupPopup : VanguardPopupBase { }
```

`VanguardPopupBase`(이미 존재) — Popup 생명주기 + 닫기 버튼 제공:

```csharp
public abstract class VanguardPopupBase : UIBase
{
    [SerializeField] protected Button _closeButton;
    protected UIManager _uiManager;
    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _uiManager = Managers.Instance.GetManager<UIManager>();
        if (_closeButton != null) _closeButton.onClick.AddListener(ClosePopup);
    }
    protected virtual void ClosePopup() => _uiManager?.Hide(this);
}
```

**프리팹은 이미 존재**: `Assets/Resources_moved/UI/VanguardTurretSetupPopup.prefab` (스켈레톤 — 본 문서대로 내부를 채운다). `Show<T>`가 Resources에서 프리팹을 찾으므로 프리팹 이름/경로는 **유지**할 것.

---

## 2. 화면 분석 (첨부 레퍼런스 → 위키 매핑)

위키 칩 관리 UI 정의([[2026-05-29_vanguard-implementation-plan-outgame]] 3장):

```
Bag      — 보유 칩 확인 (인벤토리 그리드)
Filter   — 터렛 타입별 칩 표시 (ChipFilterPopupUI 재사용)
Overview — 장착 칩 스탯 표시 (Overview/Deploy 토글의 한쪽)
Deploy   — 터렛 배치 조정 (토글의 다른쪽)
```

### 2-1. Exclusive Chip 탭 (이미지 1)

```
┌ 상단: 재화(Standard DS) 카운트 ──────────────┐
│ [Row 1]  슬롯아이콘(0/0/0 인디케이터) | Unlock 100 | Locked | 📖 │
│ [Row 2]  슬롯아이콘                  | Unlock 100 | Locked | 📖 │
│ [Row 3]  슬롯아이콘                  | Unlock 100 | Locked | 📖 │
├ Bag | 🔻Filter | [Overview]/[Deploy] 토글 ──┤
│ ✏️ ── ( None ) ── (선택 칩 상세/장착 타겟)     │
├ [Exclusive Chip] / General Chip (하단 탭)     │
└ ◁ 뒤로 ───────────────────────────────────────┘
```

`[설계 판단]` **Exclusive Chip = 특정 터렛에 종속된 전용 칩 슬롯**. 각 Row = 전용 칩 슬롯 1개(또는 한 터렛의 전용 슬롯 묶음). 1번 슬롯은 기본 해제, 이후 슬롯은 `Unlock {cost}`(Standard DS) → 그 다음 슬롯 `Locked`(선행 해제 필요). 화면의 `Unlock 100`은 예시값이며 **실비용은 서버 권위**(터렛 슬롯 해제 비용 무료/80/150/220 표 참조, 칩 슬롯은 기획 확정 전 — 4장 가정값 사용).

### 2-2. General Chip 탭 (이미지 2)

```
┌ 상단: 재화 ──────────────────────────────────┐
│   [슬롯1]            메크/터렛 도형            [슬롯4] │
│   [슬롯2]         (deployed turret art)        [슬롯5] │
│   [슬롯3]                                       [슬롯6] │
├ Bag | 🔻Filter | [Overview] ─────────────────┤
│ ✏️ ── ( None ) ──                              │
├ Exclusive Chip / [General Chip] (하단 탭)      │
└ ◁ 뒤로 ───────────────────────────────────────┘
```

`[설계 판단]` **General Chip = 모든 유닛 공용 칩(`Chip.targetUnits` 비어있음)**. 본 게임 `EquipmentPopup`의 "칩 도형 6슬롯" 레이아웃과 **동일 패턴**. 6개 `ChipSlotDisplay`를 도형 좌/우 3개씩 배치.

### 2-3. 공통(두 탭 공유) 영역

- **상단 재화 박스**: `TopCurrencyBoxComponent` (Standard DS 1종 이상).
- **Bag(인벤토리 그리드)**: `ScrollRect` + `GridLayoutGroup` content + `ChipInventoryItem` 동적 생성(`EquipmentPopup` 패턴 그대로).
- **Filter 버튼**: `ChipFilterPopupUI` 호출.
- **Overview/Deploy 토글**: 하단 정보 패널 모드 전환. Overview = 장착 칩 합산 스탯 표시(`ChipInfoDIsplay`/커스텀), Deploy = 9터렛 배치 조정(별도, 본 문서 범위 밖 → 버튼만 두고 TODO).
- **선택 칩 상세 + 장착 타겟(`None`/✏️)**: 인벤토리에서 칩 선택 시 상세 + "장착" 액션.
- **하단 탭(Exclusive/General)** + **닫기(◁)**.

---

## 3. 재사용 자산 분석 (가장 중요)

> 결론: **신규 프리팹은 "팝업 루트"와 "Exclusive 행" 2개뿐**, 나머지는 기존 칩 컴포넌트 프리팹을 인스턴스/Variant로 재사용.

### 3-1. 재사용 컴포넌트 (그대로 사용)

| 컴포넌트 | 스크립트 경로 | 프리팹 | 본 UI에서의 용도 | 핵심 API |
|---|---|---|---|---|
| **ChipSlotDisplay** | `UI/Components/ChipSlotDisplay.cs` | `3_Prefabs/UI/Equipment/ChipSlotDisplay.prefab` | General 탭 6슬롯 / Exclusive 행 내 슬롯 | `SetState(EChipSlotState, Chip)` · `OnUnlockClicked` · `OnUnequipClicked` · `OnEquippedChipClicked` · `OnEmptySlotClicked` · `IsSwapMode` · `PlayEffect()` |
| **ChipSlotIndicator** | `UI/Components/ChipSlotIndicator.cs` | `3_Prefabs/UI/Equipment/ChipSlotIndicator.prefab` | 미니 슬롯 상태 인디케이터(행의 0/0/0 표기) | `SetState(state, chip)` · `PlaySuccessAnimation(chip)` |
| **ChipInventoryItem** | `UI/Components/ChipInventoryItem.cs` | `3_Prefabs/UI/Equipment/ChipInventoryItem.prefab` | Bag 그리드 1칸 | `Initialize(Chip, bool isInInventory=true)` · `OnChipClicked` · `SetSelected/SetBlocked/SetAttention` · `GetChip()` · `SetPresetNumbers` |
| **ChipInfoDIsplay** | `UI/Components/ChipInfoDIsplay.cs` | (EquipmentPopup 내 패널 참고) | 선택 칩 상세 + 액션 버튼(장착) | `SetChip(Chip, params (string,Action<IActionPayload>)[])` · `SetEmpty()` |
| **ChipFilterPopupUI** | `UI/Popups/ChipFilterPopupUI.cs` | `Resources_moved/UI/ChipFilterPopupUI.prefab` | Filter 팝업 | `Show<ChipFilterPopupUI>(new object[]{ (Action<ChipFilterOptions>)cb, options })` |
| **TopCurrencyBoxComponent** | (`VanguardLobbyPanel`에서 사용 확인) | - | 상단 재화 | `Initialize(ECurrencyType[], CurrencyManager)` · `Refresh()` · `OnCurrencyChanged(type)` |
| **RedDotComponent** | - | - | 탭/슬롯 레드닷 | `NodeID` 세팅 |

### 3-2. 참고 레퍼런스 (복제 대상, 직접 재사용X)

| 레퍼런스 | 무엇을 베낄까 |
|---|---|
| **`EquipmentPopup.cs`** (`UI/Popups/EquipmentPopup.cs`) | ① 탭 전환(`SwitchTab` + GameObject visibility 토글) ② 인벤토리 빌드/정리(`RefreshChipInventoryItems`/`ClearInventoryItems`, `List<GameObject> _inventoryItems`) ③ 필터 적용(`OnFilterConfirmed(ChipFilterOptions)` → `FilterService.ApplyChipFilter`) ④ 칩 장착 가능/블락/레드닷 판정 로직 ⑤ 슬롯 클릭→인벤토리 선택→장착 플로우 |
| **`EquipmentSlot` + `_equipmentSlots[]` 초기화** | General 탭 6슬롯을 배열로 두고 인덱스→슬롯타입 매핑(`InitializeEquipmentSlots`) |
| **`ChipFilterOptions` / `FilterService.ApplyChipFilter`** | 필터 결과를 인벤토리 아이템 `SetActive(pass)` 로 반영 |

### 3-3. 재사용하지 않는 것 (주의)

- ❌ 본 게임 `ChipManager`에 직접 장착/해제하면 **메인 칩 빌드를 오염**시킨다. → Vanguard 전용 데이터 소스(`IVanguardChipProvider`)로 분리.
- ❌ `EquipmentManager`/`SkinManager`/영웅 스킨 애님 — 본 UI 불필요(메크 아트는 정적 이미지/애니).

---

## 4. 데이터/매니저 연동 + 어댑터 설계

### 4-1. 데이터 소스 추상화 `[설계 판단]`

`VanguardChipService`(미구현)에 직결하지 않고 어댑터로 분리 → 서비스 완성 전 테스트 데이터로 빌드, 완성 후 구현체만 교체.

```csharp
public enum EVanguardChipKind { General = 0, Exclusive = 1 }

public interface IVanguardChipProvider
{
    // Bag
    IReadOnlyList<Chip> GetBag(EVanguardChipKind kind);
    // 슬롯 상태 (kind + 슬롯 인덱스)
    bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex);
    Chip GetEquippedChip(EVanguardChipKind kind, int slotIndex);
    int GetSlotUnlockCost(EVanguardChipKind kind, int slotIndex);     // Standard DS
    int GeneralSlotCount { get; }     // 6
    int ExclusiveSlotCount { get; }   // 행 수 (예: 3)

    // 액션 (서버 권위 → UniTask)
    UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex);
    UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int slotIndex, Chip chip);
    UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int slotIndex);

    // 변경 통지
    event Action OnChanged;
}
```

- **구현 1 (선개발)**: `VanguardChipProviderStub : IVanguardChipProvider` — 로컬 더미 칩 + 즉시 성공. `[TEST]` 토글로 사용.
- **구현 2 (정식)**: `VanguardChipService`가 인터페이스 구현. 슬롯 해제/장착은 `VanguardServerService` 통해 서버 권위(PvP 공정성, [[2026-05-29_vanguard-implementation-plan-outgame]] 3장).

### 4-2. Exclusive / General 구분 규칙 `[설계 판단]`

- **General** = `Chip.targetUnits` 가 비어있음(모든 유닛 적용). 본 게임 규칙과 동일.
- **Exclusive** = `Chip.targetUnits` 에 특정 터렛 유닛 포함. Provider가 `kind`로 미리 필터링해 Bag을 분리 제공.

### 4-3. CLAUDE.md 준수 체크

- 매니저 접근: `Managers.Instance.GetManager<T>()` 만. (`VanguardManager` → `.ChipProvider`/`.LoadoutService` 노출)
- 이벤트: `EventManager` **static** (구독/해제). `CurrencyChanged` 구독.
- 시간: `DateTime.Now` 금지. (본 UI엔 미사용)
- 텍스트: 하드코딩 금지 → `LocalizationManager.GetLocalizedText(key)`.
- 서버콜: `ServerLoadingPopupUI.Show(...)` / `finally { Hide(); }`.
- async: `UniTask` + `Async` 접미, `async void` 금지(`UniTaskVoid`).
- 슬롯 해제 비용 등: 매직넘버 금지 → Provider/const.

---

## 5. UI 프리팹 구조 (전체 하이어라키)

> 루트는 기존 `VanguardTurretSetupPopup.prefab` 유지. 아래 구조로 자식 구성. `[재사용]`=기존 프리팹 인스턴스, `[신규]`=새로 배치.

```
VanguardTurretSetupPopup (루트, Canvas/CanvasGroup, ▶ VanguardTurretSetupPopup.cs)
├─ Dim (전체 암막, 클릭=닫기 옵션)
├─ Window (RectTransform, 9:16 세로)
│  ├─ Top
│  │  ├─ Btn_Back (◁)                         → _closeButton (Base가 바인딩)
│  │  └─ TopCurrencyBox [재사용 TopCurrencyBoxComponent]   → _topCurrencyBox
│  │
│  ├─ Content (탭 전환 영역)
│  │  ├─ ExclusiveTabContent (GameObject 토글) → _exclusiveTabContent
│  │  │  └─ RowList (VerticalLayoutGroup)
│  │  │     └─ [Row x N] [신규 VanguardExclusiveChipRow.prefab]  → _exclusiveRowParent
│  │  │        ├─ SlotIcon [재사용 ChipSlotDisplay]   → slot
│  │  │        ├─ MiniIndicators [재사용 ChipSlotIndicator x3]
│  │  │        ├─ Btn_Unlock + CostText(Standard DS)  → unlockButton/costText
│  │  │        ├─ LockedState (GameObject)
│  │  │        └─ Btn_Info (📖)
│  │  │
│  │  └─ GeneralTabContent (GameObject 토글)   → _generalTabContent
│  │     ├─ TurretArt (Image/Animator, 정적)
│  │     └─ Slots
│  │        └─ [ChipSlotDisplay x6] [재사용]  → _generalSlots[6] (좌3/우3)
│  │
│  ├─ Shared (두 탭 공유)
│  │  ├─ BagHeader
│  │  │  ├─ Label "Bag"
│  │  │  ├─ Btn_Filter (🔻)                    → _filterButton
│  │  │  └─ ModeToggle [Overview | Deploy]      → _overviewButton/_deployButton
│  │  ├─ BagScroll (ScrollRect)                 → _inventoryScrollRect
│  │  │  └─ Viewport/Content (GridLayoutGroup)  → _inventoryContent
│  │  │     └─ (런타임) ChipInventoryItem [재사용 prefab] → _chipInventoryItemPrefab
│  │  └─ DetailPanel
│  │     ├─ Btn_Edit (✏️)
│  │     └─ ChipInfo [재사용 ChipInfoDIsplay] / "None" 상태  → _chipInfoDisplay / _noneState
│  │
│  └─ BottomTabs
│     ├─ Btn_ExclusiveTab                       → _exclusiveTabButton
│     └─ Btn_GeneralTab                         → _generalTabButton
```

### 5-1. 신규 프리팹: `VanguardExclusiveChipRow.prefab`

- 위치: `Assets/_Project/3_Prefabs/UI/Vanguard/VanguardExclusiveChipRow.prefab`
- 컴포넌트: `VanguardExclusiveChipRow.cs`(아래 6-2)
- 내부: `ChipSlotDisplay` 1 + `ChipSlotIndicator` 0~3 + Unlock 버튼/비용 텍스트 + Locked 오버레이 + Info 버튼.

### 5-2. GridLayoutGroup 설정(Bag)

- `_inventoryContent` 에 `GridLayoutGroup`(Cell Size 칩아이템 크기, Constraint=Fixed Column Count, 보통 4~5열) + `ContentSizeFitter`(Vertical=PreferredSize). `EquipmentPopup`의 Bag content와 동일 셋업 복사.

---

## 6. 스크립트 설계

### 6-1. `VanguardTurretSetupPopup.cs` (본문 — 참조 구현)

> `EquipmentPopup`의 칩 탭 로직을 축소 복제하되 데이터 소스는 `IVanguardChipProvider`. CLAUDE.md 규칙 준수. 컴파일-그린 우선, 실제 연출/Deploy는 TODO 가드.

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 터렛/칩 장착 팝업. Exclusive(전용) / General(범용) 두 탭 + 공유 Bag/Filter/Overview.
/// 데이터는 IVanguardChipProvider 어댑터를 통해 접근 (VanguardChipService 미구현 단계는 Stub).
/// </summary>
public class VanguardTurretSetupPopup : VanguardPopupBase
{
    #region Serialized

    [Header("상단 재화")]
    [SerializeField] private TopCurrencyBoxComponent _topCurrencyBox;

    [Header("탭")]
    [SerializeField] private Button _exclusiveTabButton;
    [SerializeField] private Button _generalTabButton;
    [SerializeField] private GameObject _exclusiveTabContent;
    [SerializeField] private GameObject _generalTabContent;

    [Header("Exclusive 탭")]
    [SerializeField] private Transform _exclusiveRowParent;
    [SerializeField] private VanguardExclusiveChipRow _exclusiveRowPrefab;

    [Header("General 탭 (6 슬롯)")]
    [SerializeField] private ChipSlotDisplay[] _generalSlots; // 길이 6

    [Header("Bag / Filter / Mode")]
    [SerializeField] private Button _filterButton;
    [SerializeField] private Button _overviewButton;
    [SerializeField] private Button _deployButton;
    [SerializeField] private ScrollRect _inventoryScrollRect;
    [SerializeField] private Transform _inventoryContent;
    [SerializeField] private ChipInventoryItem _chipInventoryItemPrefab;

    [Header("Detail")]
    [SerializeField] private ChipInfoDIsplay _chipInfoDisplay;
    [SerializeField] private GameObject _noneState;

    [Header("[TEST] 서버 미연결 (Stub 사용)")]
    [SerializeField] private bool _useStubProvider = true;

    #endregion

    private VanguardManager _vanguardManager;
    private CurrencyManager _currencyManager;
    private IVanguardChipProvider _provider;

    private EVanguardChipKind _currentKind = EVanguardChipKind.General;
    private readonly List<GameObject> _inventoryItems = new();
    private ChipInventoryItem _selectedItem;
    private ChipFilterOptions _filterOptions = new();
    private readonly List<VanguardExclusiveChipRow> _exclusiveRows = new();
    private bool _bound;

    protected override void Awake()
    {
        base.Awake(); // uiPosition=Popup, _closeButton 바인딩
        if (_bound) return;
        _bound = true;

        _exclusiveTabButton.onClick.AddListener(() => SwitchTab(EVanguardChipKind.Exclusive));
        _generalTabButton.onClick.AddListener(() => SwitchTab(EVanguardChipKind.General));
        _filterButton.onClick.AddListener(OnClickFilter);
        _overviewButton.onClick.AddListener(() => SetMode(true));
        _deployButton.onClick.AddListener(() => SetMode(false));
    }

    public override void Opened(params object[] param)
    {
        base.Opened(param);
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();
        _currencyManager = Managers.Instance.GetManager<CurrencyManager>();

        _provider = _useStubProvider
            ? new VanguardChipProviderStub()
            : _vanguardManager?.ChipProvider;   // TODO: VanguardChipService 구현 후 연결

        _topCurrencyBox?.Initialize(new[] { ECurrencyType.VanguardStandardDS }, _currencyManager);
        _topCurrencyBox?.Refresh();

        if (_provider != null) _provider.OnChanged += RefreshAll;
        EventManager.Subscribe<CurrencyChangedEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);

        InitGeneralSlots();
        SetMode(true);                 // 기본 Overview
        SwitchTab(EVanguardChipKind.General);  // 기본 General 탭
    }

    public override void Closed(params object[] param)
    {
        if (_provider != null) _provider.OnChanged -= RefreshAll;
        EventManager.Unsubscribe<CurrencyChangedEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
        ClearInventoryItems();
        base.Closed(param);
    }

    #region Tab / Mode

    private void SwitchTab(EVanguardChipKind kind)
    {
        _currentKind = kind;
        _exclusiveTabContent.SetActive(kind == EVanguardChipKind.Exclusive);
        _generalTabContent.SetActive(kind == EVanguardChipKind.General);
        RefreshAll();
    }

    private void SetMode(bool overview)
    {
        // Overview = 장착 칩 스탯 / Deploy = 터렛 배치 조정(TODO)
        // TODO(Deploy): 9터렛 배치 조정 UI는 후속 STEP. 현재는 토글 비주얼만.
    }

    #endregion

    #region Refresh

    private void RefreshAll()
    {
        if (_provider == null) return;
        RefreshSlots();
        RefreshBag();
        RefreshDetail();
    }

    private void InitGeneralSlots()
    {
        for (int i = 0; i < _generalSlots.Length; i++)
        {
            int idx = i;
            var slot = _generalSlots[i];
            if (slot == null) continue;
            slot.OnUnlockClicked     = () => UnlockSlotAsync(EVanguardChipKind.General, idx).Forget();
            slot.OnEmptySlotClicked  = () => TryEquipSelectedTo(EVanguardChipKind.General, idx);
            slot.OnUnequipClicked    = () => UnequipAsync(EVanguardChipKind.General, idx).Forget();
            slot.OnEquippedChipClicked = () => TryEquipSelectedTo(EVanguardChipKind.General, idx); // 스왑
        }
    }

    private void RefreshSlots()
    {
        if (_currentKind == EVanguardChipKind.General)
        {
            for (int i = 0; i < _generalSlots.Length; i++)
                ApplySlotState(_generalSlots[i], EVanguardChipKind.General, i);
        }
        else
        {
            BuildExclusiveRows();
        }
    }

    private void ApplySlotState(ChipSlotDisplay slot, EVanguardChipKind kind, int idx)
    {
        if (slot == null) return;
        if (!_provider.IsSlotUnlocked(kind, idx)) { slot.SetState(EChipSlotState.Unlockable, null); return; }
        var chip = _provider.GetEquippedChip(kind, idx);
        slot.SetState(chip != null ? EChipSlotState.Equipped : EChipSlotState.Empty, chip);
    }

    private void BuildExclusiveRows()
    {
        // 단순화: 행 수만큼 재생성 (소량). 필요 시 풀링.
        foreach (var r in _exclusiveRows) if (r != null) Destroy(r.gameObject);
        _exclusiveRows.Clear();

        int count = _provider.ExclusiveSlotCount;
        for (int i = 0; i < count; i++)
        {
            int idx = i;
            var row = Instantiate(_exclusiveRowPrefab, _exclusiveRowParent);
            row.Bind(
                index: idx,
                unlocked: _provider.IsSlotUnlocked(EVanguardChipKind.Exclusive, idx),
                equipped: _provider.GetEquippedChip(EVanguardChipKind.Exclusive, idx),
                unlockCost: _provider.GetSlotUnlockCost(EVanguardChipKind.Exclusive, idx),
                onUnlock: () => UnlockSlotAsync(EVanguardChipKind.Exclusive, idx).Forget(),
                onSlotClick: () => TryEquipSelectedTo(EVanguardChipKind.Exclusive, idx),
                onUnequip: () => UnequipAsync(EVanguardChipKind.Exclusive, idx).Forget());
            _exclusiveRows.Add(row);
        }
    }

    private void RefreshBag()
    {
        ClearInventoryItems();
        var bag = _provider.GetBag(_currentKind);
        foreach (var chip in bag)
        {
            var item = Instantiate(_chipInventoryItemPrefab, _inventoryContent);
            item.Initialize(chip);
            item.OnChipClicked += OnBagItemClicked;
            // 필터 반영
            bool pass = FilterService.ApplyChipFilter(new[] { chip }, _filterOptions).Any();
            item.gameObject.SetActive(pass);
            _inventoryItems.Add(item.gameObject);
        }
    }

    private void RefreshDetail()
    {
        bool has = _selectedItem != null && _selectedItem.GetChip() != null;
        _noneState?.SetActive(!has);
        if (has)
            _chipInfoDisplay?.SetChip(_selectedItem.GetChip());
        else
            _chipInfoDisplay?.SetEmpty();
    }

    private void ClearInventoryItems()
    {
        foreach (var go in _inventoryItems)
        {
            if (go == null) continue;
            if (go.TryGetComponent(out ChipInventoryItem c)) c.OnChipClicked -= OnBagItemClicked;
            Destroy(go);
        }
        _inventoryItems.Clear();
    }

    #endregion

    #region Actions

    private void OnBagItemClicked(ChipInventoryItem item)
    {
        if (_selectedItem != null) _selectedItem.SetSelected(false);
        _selectedItem = item;
        _selectedItem.SetSelected(true);
        RefreshDetail();
    }

    private void TryEquipSelectedTo(EVanguardChipKind kind, int slotIndex)
    {
        var chip = _selectedItem?.GetChip();
        if (chip == null)
        {
            ToastManager.ShowToast(LocalizationManager.GetLocalizedText("toast_select_chip_first"));
            return;
        }
        EquipAsync(kind, slotIndex, chip).Forget();
    }

    private async UniTaskVoid EquipAsync(EVanguardChipKind kind, int slotIndex, Chip chip)
    {
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        try { await _provider.EquipChipAsync(kind, slotIndex, chip); }
        finally { ServerLoadingPopupUI.Hide(); }
        // OnChanged → RefreshAll 자동 호출
    }

    private async UniTaskVoid UnequipAsync(EVanguardChipKind kind, int slotIndex)
    {
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        try { await _provider.UnequipChipAsync(kind, slotIndex); }
        finally { ServerLoadingPopupUI.Hide(); }
    }

    private async UniTaskVoid UnlockSlotAsync(EVanguardChipKind kind, int slotIndex)
    {
        int cost = _provider.GetSlotUnlockCost(kind, slotIndex);
        if (_currencyManager.GetCurrency(ECurrencyType.VanguardStandardDS) < cost)
        {
            ToastManager.ShowToast(LocalizationManager.GetLocalizedText("toast_not_enough_currency"));
            return;
        }
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        try { await _provider.UnlockSlotAsync(kind, slotIndex); }
        finally { ServerLoadingPopupUI.Hide(); }
    }

    private void OnClickFilter()
    {
        _uiManager.Show<ChipFilterPopupUI>(new object[]
        {
            (Action<ChipFilterOptions>)OnFilterConfirmed,
            _filterOptions
        });
    }

    private void OnFilterConfirmed(ChipFilterOptions options)
    {
        if (options != null) _filterOptions = options;
        foreach (var go in _inventoryItems)
        {
            if (!go.TryGetComponent(out ChipInventoryItem c)) continue;
            bool pass = FilterService.ApplyChipFilter(new[] { c.GetChip() }, _filterOptions).Any();
            go.SetActive(pass);
        }
    }

    private void OnCurrencyChanged(CurrencyChangedEventData data)
    {
        _topCurrencyBox?.OnCurrencyChanged(data.CurrencyType);
    }

    #endregion
}
```

> **검증 필요 시그니처(빌드 전 Grep 확인 — CLAUDE.md 워크플로 4-2)**: `TopCurrencyBoxComponent.Initialize/Refresh/OnCurrencyChanged`, `ChipInfoDIsplay.SetChip/SetEmpty`, `ChipFilterPopupUI` param 순서, `ChipInventoryItem.OnChipClicked` 시그니처(`Action<ChipInventoryItem>`), `ToastManager.ShowToast`, `ServerLoadingPopupUI.Show/Hide`. 위 코드는 `EquipmentPopup` 실제 사용처 기준으로 작성됨.

### 6-2. `VanguardExclusiveChipRow.cs` (신규 컴포넌트)

```csharp
using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary> Exclusive Chip 탭의 한 행: 슬롯 + Unlock 비용 / Locked / Info. </summary>
public class VanguardExclusiveChipRow : MonoBehaviour
{
    [SerializeField] private ChipSlotDisplay _slot;
    [SerializeField] private Button _unlockButton;
    [SerializeField] private TextMeshProUGUI _unlockCostText;
    [SerializeField] private GameObject _lockedState;   // 선행 슬롯 미해제 상태
    [SerializeField] private GameObject _unlockState;   // 해제 가능(비용 표시)
    [SerializeField] private Button _infoButton;

    public void Bind(int index, bool unlocked, Chip equipped, int unlockCost,
                     Action onUnlock, Action onSlotClick, Action onUnequip)
    {
        _unlockButton.onClick.RemoveAllListeners();
        _unlockButton.onClick.AddListener(() => onUnlock?.Invoke());

        if (!unlocked)
        {
            bool purchasable = unlockCost > 0; // 0 이하 = 선행 필요(Locked)
            _unlockState.SetActive(purchasable);
            _lockedState.SetActive(!purchasable);
            if (_unlockCostText != null) _unlockCostText.text = unlockCost.ToString();
            _slot.SetState(EChipSlotState.Unlockable, null);
        }
        else
        {
            _unlockState.SetActive(false);
            _lockedState.SetActive(false);
            _slot.OnEmptySlotClicked    = () => onSlotClick?.Invoke();
            _slot.OnEquippedChipClicked = () => onSlotClick?.Invoke();
            _slot.OnUnequipClicked      = () => onUnequip?.Invoke();
            _slot.SetState(equipped != null ? EChipSlotState.Equipped : EChipSlotState.Empty, equipped);
        }
    }
}
```

### 6-3. `IVanguardChipProvider` + Stub (신규)

4-1의 인터페이스 + 테스트 구현. `VanguardChipProviderStub`은 더미 `Chip` 리스트 + 슬롯 dictionary로 즉시 성공 반환, `OnChanged` 발사. 정식 `VanguardChipService`는 [[2026-05-29_vanguard-implementation-plan-outgame]] T1에서 구현하며 본 인터페이스를 implement.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `Core/Enums/Vanguard/EVanguardChipKind.cs` 추가(General/Exclusive).
2. [ ] `Core/.../Vanguard/IVanguardChipProvider.cs` + `VanguardChipProviderStub.cs` 추가.
3. [ ] `UI/Vanguard/Component/VanguardExclusiveChipRow.cs` 추가.
4. [ ] `VanguardTurretSetupPopup.cs` 본문 채움(6-1). 빌드-그린 확인.
5. [ ] (정식 단계) `VanguardManager`에 `public IVanguardChipProvider ChipProvider { get; }` 노출.

**B. 프리팹 — Exclusive Row**

6. [ ] `ChipSlotDisplay.prefab` 인스턴스 + Unlock 버튼/비용텍스트/Locked·Unlock 상태/Info 버튼 배치 → `VanguardExclusiveChipRow.prefab` 저장. 컴포넌트 필드 연결.

**C. 프리팹 — 팝업 본체** (`VanguardTurretSetupPopup.prefab` 편집)

7. [ ] 5장 하이어라키대로 노드 구성(Top/Content/Shared/BottomTabs).
8. [ ] General 탭: `ChipSlotDisplay` 6개 배치(좌3/우3) → `_generalSlots[6]` 연결. 가운데 터렛 아트(Image/Animator).
9. [ ] Exclusive 탭: `RowList`(VerticalLayoutGroup) → `_exclusiveRowParent`, `_exclusiveRowPrefab` 연결.
10. [ ] Bag: `ScrollRect` + Content(`GridLayoutGroup`+`ContentSizeFitter`) → `_inventoryContent`, `_chipInventoryItemPrefab`(`ChipInventoryItem.prefab`) 연결.
11. [ ] Detail: `ChipInfoDIsplay` + None 상태 → `_chipInfoDisplay`/`_noneState`.
12. [ ] 버튼 연결: `_exclusiveTabButton/_generalTabButton/_filterButton/_overviewButton/_deployButton`, Base의 `_closeButton`.
13. [ ] `_topCurrencyBox`(TopCurrencyBoxComponent) 연결.
14. [ ] `_useStubProvider = true` 로 두고 에디터 플레이 테스트.

**D. 연동/마감**

15. [ ] Localization 키 추가: `toast_select_chip_first`, `toast_not_enough_currency`, `loading` 등(없으면).
16. [ ] (정식) Stub→`VanguardChipService` 교체, `_useStubProvider=false`.
17. [ ] Deploy 모드(9터렛 배치) — 별도 STEP(TODO 가드 유지).

---

## 8. 검증 체크리스트

- [ ] `VanguardLobbyPanel` Btn_Turret → 팝업 정상 오픈/닫기(Base `_closeButton`).
- [ ] 탭 전환: Exclusive/General 콘텐츠 토글 + Bag이 kind별로 분리 표시.
- [ ] 슬롯 상태: 미해제=Unlockable(비용 표기), 빈=Empty, 장착=Equipped(해제 버튼).
- [ ] Bag 칩 선택 → Detail 갱신(None↔칩 상세) → 슬롯 클릭 시 장착, OnChanged로 전체 갱신.
- [ ] Filter 적용 후 인벤토리 아이템 `SetActive` 반영.
- [ ] 재화 부족 시 해제 토스트, 충분 시 Stub 즉시 성공 → 슬롯 Unlockable→Empty 전환.
- [ ] `Closed()`에서 이벤트 해제 + 인벤토리 정리(누수/중복구독 없음).
- [ ] CLAUDE.md 금지사항 위반 없음(Find/async void/DateTime.Now/하드코딩 텍스트/매직넘버).
- [ ] 빌드 그린(시그니처 Grep 확인 후).

---

## 9. 미해결 / 확인 필요

- [ ] **칩 슬롯 해제 비용** 정확 수치(기획). 화면 `Unlock 100`은 예시. 터렛 슬롯은 무료/80/150/220(위키) — 칩 슬롯은 별도 확인.
- [ ] **Exclusive 행의 정확한 의미**(터렛당 1행인지/전용 슬롯 묶음인지) — 실게임 영상/기획 확정. 본 문서는 "전용 칩 슬롯 N행" 가정.
- [ ] **Deploy 모드 UX**(9터렛 배치 조정) — 별도 UI 문서로 분리 권장.
- [ ] **Overview 스탯 합산 표기** 포맷 — `ChipInfoDIsplay` 확장 또는 전용 패널 필요 여부.
- [ ] `VanguardChipService` / `VanguardServerService` 칩 장착·해제 API 스펙 → [[2026-05-31_vanguard-server-api-spec]] 와 동기화.

---

> 작성: 2026-06-03 · 선행 코드 확인 완료(`VanguardLobbyPanel`/`VanguardPopupBase`/`VanguardTurretSetupPopup`/`EquipmentPopup`/`ChipManager`/`ChipSlotDisplay`/`ChipInventoryItem`/`ChipFilterPopupUI`). 본 문서 단독으로 프리팹+스크립트 1회 제작 가능하도록 구성.
