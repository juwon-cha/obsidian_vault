# Vanguard 유닛 배치 팝업(VanguardUnitDeployPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

`VanguardUnitSetupPopup`의 **ExclusiveChipPanel**에서 `VanguardExclusiveChipRow` 내부 **`VanguardChipSlot`에 아무 유닛도 장착되지 않은 상태로 클릭**하면 뜨는 **전체 화면 유닛 배치 팝업**(첨부 이미지: 상단 칩 슬롯 행 + "Drag the turret to change its position" + 하단 유닛 그리드 + Complete)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- **네이밍 제안**: **`VanguardUnitDeployPopup`** 권장. 근거: 위키의 "**Deploy** Screen lets you move Turret setup around" + 화면 안내 "Drag the turret to change its position"가 정확히 이 화면(유닛 배치/이동). (대안: `VanguardUnitEquipPopup`.) 이하 `VanguardUnitDeployPopup` 사용.
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]](부모·슬롯), [[2026-06-04_vanguard-unit-detail-popup-ui]](장착됐을 때 클릭 시 상세 팝업)
- 전체 화면을 덮음. 장착 방식 = **드래그앤드롭** + **슬롯 클릭→유닛 클릭**.
- `[설계 판단]` = 스샷/위키 미표기 보완.

> **분기 정리**(중요): `VanguardChipSlot`(해금된 EquippedSlot) 클릭 시 — **유닛 장착됨 → `VanguardUnitDetailPopup`**(상세) / **유닛 미장착(빈 "+") → `VanguardUnitDeployPopup`**(본 문서, 배치). 즉 `OnEquippedSlotClicked` 라우팅을 "유닛 유무"로 분기.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 신규 `VanguardUnitDeployPopup : UIBase` + 유닛 1칸 핸들러(기존 `UIEventHandler` 재활용) + 배치 데이터 provider |
| 프리팹 | 신규 `Resources_moved/UI/VanguardUnitDeployPopup.prefab` (전체 화면) |
| 진입 | `VanguardChipSlot`(해금·유닛 미장착) 클릭 → `Show<VanguardUnitDeployPopup>()` |
| 상단 슬롯 | **`VanguardExclusiveChipPanel`+`VanguardExclusiveChipRow`+`VanguardChipSlot` 재활용**(드롭 타깃) |
| 유닛 그리드 | 하단 ScrollView — **`VanguardUnitIconSlot` 프리팹 재활용** + `UIEventHandler`(클릭/드래그) |
| 장착 1 (드래그) | 유닛 아이콘 드래그 → `VanguardChipSlot` 위 드롭 → 장착 |
| 장착 2 (클릭) | `VanguardChipSlot` 클릭(선택) → 유닛 아이콘 클릭 → 선택 슬롯에 장착 |
| 재배치 | 슬롯의 유닛을 다른 슬롯으로 드래그 → 이동/교체 ("Drag the turret to change its position") |
| 확정 | 하단 **Complete** → 배치 커밋(서버 권위) + 닫기 → 부모 Refresh |
| 데이터 | 9유닛(`EUnitType`)·슬롯 배치 = `VanguardLoadoutService`/Provider(미연동 → 더미) |

---

## 1. 진입 / 확정 플로우

```
VanguardUnitSetupPopup > ExclusiveChipPanel > VanguardExclusiveChipRow > VanguardChipSlot
  (해금 상태 + 유닛 미장착 "+") 클릭
   └─ VanguardChipSlot.OnEquippedSlotClicked → (부모 라우팅) Show<VanguardUnitDeployPopup>()
        ├─ 상단: 칩 슬롯 행들(드롭 타깃) — 현재 배치 상태 표시
        ├─ 하단: 유닛 그리드(9종) 스크롤
        ├─ 드래그/클릭으로 유닛 ↔ 슬롯 배치/이동
        └─ [Complete] → 배치 커밋(provider, 서버 권위) → Hide → 부모 ExclusiveChipPanel.Refresh()
```

- 라우팅: `VanguardChipSlot.OnEquippedSlotClicked`를 부모(`VanguardUnitSetupPopup`/`VanguardExclusiveChipPanel`)가 설정 — 슬롯에 유닛 있으면 Detail, 없으면 Deploy. (현재 슬롯 기본 동작은 Detail 직접 오픈 → **빈 슬롯은 Deploy로 분기**하도록 부모가 핸들러 주입.)
- 본 팝업은 **전 슬롯**의 배치를 한 화면에서 편집(스샷이 row 1·2·3 전부 표시).

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 상단 재화 | 좌상단 ◆`0` | `_currencyText`(선택) |
| B | 칩 슬롯 행 ×3 | 각 행: `+`(빈 유닛 슬롯) · `Unlock 100` · `Locked` · 📖 | **`VanguardExclusiveChipPanel`(rows/slots) 재활용** → 드롭 타깃 |
| C | 안내 텍스트 | `Drag the turret to change its position` | `_dragHintText`(로컬라이즈) |
| D | 유닛 그리드 | 9유닛 아이콘(2~3열 그리드, 스크롤) | ScrollView + **`VanguardUnitIconSlot` ×9** |
| E | 확정 버튼 | 하단 청록 `Complete` | `_completeButton` |
| F | 배경 | 전체 화면 어두운 배경 | 전체 화면 Image(불투명/딤) |

- 빈 유닛 슬롯의 `+` = `VanguardChipSlot` EquippedSlot의 "유닛 미장착" 비주얼. 유닛 배치 시 `+` → 유닛 아이콘.
- 그리드 9칸 = `VanguardExclusiveChipPanel.DefaultUnits`(Marine/Turret/Archon/DrFrost/Marauder/Templer/Dragoon/Vessel/Carrier)와 동일 9종.

---

## 3. 재사용 자산 분석 (실제 구현 확인)

| 자산 | 경로 | 재사용 방식 | 핵심 API (실코드) |
|---|---|---|---|
| **VanguardExclusiveChipPanel** | `UI/Vanguard/Component/VanguardExclusiveChipPanel.cs` | 상단 슬롯 행 = 드롭 타깃 | `Initialize(IVanguardChipProvider, Action<int> onUnlock)` · `Refresh()` · `_rows[]`/`_columns`/`DefaultUnits` |
| **VanguardExclusiveChipRow** | `UI/Vanguard/Component/VanguardExclusiveChipRow.cs` | 행 | `Slots` (`VanguardChipSlot[]`) |
| **VanguardChipSlot** | `UI/Vanguard/Component/VanguardChipSlot.cs` | 드롭 타깃 + 유닛 표시 | `SetUnitType(EUnitType)` · `UnitType` · `SetState(EChipSlotState, Chip)` · `OnEquippedSlotClicked`/`OnUnlockClicked` · `IPointerClickHandler` |
| **VanguardUnitIconSlot** | `UI/Vanguard/Component/VanguardUnitIconSlot.cs` (+prefab) | 유닛 그리드 1칸 | `Setup(string unitName)` (`Sprites/Units/{unitName}`) |
| **UIEventHandler** | `UI/UIEventHandler.cs` | 유닛 칸/슬롯에 **클릭·드래그 이벤트** 부여 | `OnClickEvent`/`OnBeginDragEvent`/`OnDragEvent`/`OnEndDragEvent` (`Action<PointerEventData>`) |
| **IVanguardChipProvider** | (부모가 사용) | 슬롯 해금 상태 | `IsSlotUnlocked`/`GetSlotUnlockCost`(EVanguardChipKind.Exclusive, idx) |
| **VanguardPopupBase**(선택) | `UI/Vanguard/Popup/VanguardPopupBase.cs` | 베이스 | `uiPosition=Popup` |

### 신규 작성 (1~2개)

- `VanguardUnitDeployPopup.cs`(본체 — 드래그 코디네이터 + 클릭 선택 + Complete).
- `IVanguardDeployProvider`(또는 `VanguardLoadoutService` 확장) — 9유닛 목록 + 슬롯별 배치 유닛 get/set/커밋(미연동 → 더미).
- ※ 드래그용 신규 컴포넌트 불필요 — **`UIEventHandler`** 를 유닛 칸/슬롯 아이콘에 붙여 팝업이 이벤트를 받는다.

---

## 4. UI 프리팹 구조 (전체 하이어라키)

> 신규 `VanguardUnitDeployPopup.prefab`(`Resources_moved/UI/`). 루트 `VanguardUnitDeployPopup.cs`. **전체 화면**(루트 RectTransform stretch + 불투명/딤 배경). `uiPosition` = Popup(최상위).

```
VanguardUnitDeployPopup (루트, ▶ VanguardUnitDeployPopup.cs, 전체화면)
├─ FullScreenBg (Image, 화면 전체 덮음 + 입력 차단)       → (raycast target)
├─ TopCurrency (◆ 0)                                     → _currencyText (선택)
├─ ChipSlotArea
│  └─ ExclusiveChipPanel [재사용 VanguardExclusiveChipPanel] → _chipPanel
│     └─ VanguardExclusiveChipRow x3 → VanguardChipSlot…   (드롭 타깃)
├─ DragHintText ("Drag the turret to change its position") → _dragHintText
├─ UnitGrid
│  └─ ScrollRect
│     └─ Viewport/Content (GridLayoutGroup)               → _unitGridContent
│        └─ (런타임) VanguardUnitIconSlot x9 [재사용]       → _unitIconSlotPrefab
│           └─ (+UIEventHandler 컴포넌트)                   (클릭/드래그)
├─ DragGhostLayer (드래그 중 아이콘이 따라다니는 최상위 레이어) → _dragGhostLayer
└─ Btn_Complete ("Complete")                              → _completeButton
```

- **드롭 타깃**: 각 `VanguardChipSlot`. 드롭 판정은 `eventData` 레이캐스트 → `GetComponentInParent<VanguardChipSlot>()`(슬롯 코드 수정 불필요).
- **DragGhostLayer**: 드래그 중 생성하는 임시 유닛 아이콘(Canvas 최상위, raycast off)이 포인터를 따라감.
- 그리드: `GridLayoutGroup`(열 수 스샷 기준 3~4) + `ScrollRect` + `ContentSizeFitter`.
- 유닛 아이콘 프리팹에 **`UIEventHandler`** 추가(없으면) → 팝업이 인스턴스마다 이벤트 구독.

---

## 5. 스크립트 설계

### 5-1. 데이터 공급 (더미/서버 추상화)

```csharp
using System.Collections.Generic;

/// <summary> 유닛 배치 데이터. 슬롯 인덱스(행*열+칸) ↔ 배치 유닛. 서버 미연동 단계는 더미. </summary>
public interface IVanguardDeployProvider
{
    IReadOnlyList<EUnitType> GetAvailableUnits();          // 그리드 9종
    EUnitType? GetSlotUnit(int slotIndex);                 // 슬롯에 배치된 유닛(없으면 null)
    bool IsSlotUnlocked(int slotIndex);                    // 해금 슬롯만 배치 가능
    void SetSlotUnit(int slotIndex, EUnitType? unit);      // 로컬 반영(편집 중)
    UniTask<bool> CommitAsync();                           // Complete 시 서버 커밋(서버 권위)
}
```

- 더미 `VanguardDeployProviderStub`: 9유닛 = `VanguardExclusiveChipPanel.DefaultUnits`, 슬롯 배치는 메모리 dict, `CommitAsync` 즉시 true.
- 정식: `VanguardManager.LoadoutService`(9터렛 로드아웃, [[2026-05-29_vanguard-implementation-plan-outgame]] 3장)와 연결. 슬롯 해금은 기존 `IVanguardChipProvider` 사용.

### 5-2. `VanguardUnitDeployPopup.cs` (참조 구현)

```csharp
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

/// <summary>
/// 전체 화면 유닛 배치 팝업. 상단 칩 슬롯 행(드롭 타깃) + 하단 유닛 그리드.
/// 드래그앤드롭 또는 슬롯 클릭→유닛 클릭으로 배치. Complete 시 커밋.
/// </summary>
public class VanguardUnitDeployPopup : UIBase
{
    #region Serialized
    [Header("재화")]
    [SerializeField] private TextMeshProUGUI _currencyText;

    [Header("상단 슬롯(재사용)")]
    [SerializeField] private VanguardExclusiveChipPanel _chipPanel;

    [Header("유닛 그리드")]
    [SerializeField] private TextMeshProUGUI _dragHintText;
    [SerializeField] private Transform _unitGridContent;
    [SerializeField] private VanguardUnitIconSlot _unitIconSlotPrefab;

    [Header("드래그")]
    [SerializeField] private RectTransform _dragGhostLayer;
    [SerializeField] private Image _dragGhostPrefab; // 단순 Image(아이콘)

    [Header("버튼")]
    [SerializeField] private Button _completeButton;

    [Header("선택 하이라이트")]
    [SerializeField] private GameObject _slotSelectionHighlight; // 선택 슬롯에 띄울 프레임

    [Header("[TEST]")]
    [SerializeField] private bool _useDummy = true;
    #endregion

    private IVanguardDeployProvider _provider;
    private IVanguardChipProvider _chipProvider; // 슬롯 해금 상태(부모와 공유)
    private readonly List<GameObject> _unitItems = new();
    private VanguardChipSlot _selectedSlot;
    private Image _dragGhost;
    private EUnitType _draggingUnit;
    private bool _dragging;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _completeButton.onClick.AddListener(OnClickComplete);
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _provider = _useDummy ? new VanguardDeployProviderStub() : Managers.Instance.GetManager<VanguardManager>()?.DeployProvider;
        _chipProvider = _useDummy ? new VanguardChipProviderStub() : Managers.Instance.GetManager<VanguardManager>()?.ChipProvider;

        if (_dragHintText != null) _dragHintText.text = LocalizationManager.GetLocalizedText("vanguard_deploy_drag_hint");

        SetupChipPanel();
        BuildUnitGrid();
        ClearSelection();
    }

    public override void Closed(object[] param)
    {
        ClearUnitGrid();
        DestroyGhost();
        base.Closed(param);
    }

    // ─────────── 상단 슬롯 (드롭 타깃) ───────────
    private void SetupChipPanel()
    {
        // 슬롯 해금/유닛 상태 표시. 각 슬롯 클릭 = 선택(클릭→유닛클릭 배치 플로우).
        _chipPanel.Initialize(_chipProvider, OnSlotUnlock);
        _chipPanel.Refresh();
        WireSlotEvents();
        RefreshSlotUnits();
    }

    // 각 VanguardChipSlot에 선택 클릭 + (배치된 유닛) 드래그 소스 연결
    private void WireSlotEvents()
    {
        foreach (var slot in EnumerateSlots())
        {
            int idx = SlotIndexOf(slot);
            // 클릭 = 슬롯 선택 (해금 슬롯만)
            slot.OnEquippedSlotClicked = () => { if (_chipProvider.IsSlotUnlocked(EVanguardChipKind.Exclusive, idx)) SelectSlot(slot); };
            // 배치된 유닛 드래그 소스: 슬롯 아이콘에 UIEventHandler 부착(프리팹/런타임) → 드래그 시작 시 해당 유닛으로 OnBeginUnitDrag
            var handler = slot.GetComponentInChildren<UIEventHandler>(true);
            if (handler != null)
            {
                var unit = _provider.GetSlotUnit(idx);
                handler.OnBeginDragEvent = e => { if (unit.HasValue) OnBeginUnitDrag(unit.Value, e); };
                handler.OnDragEvent      = OnUnitDrag;
                handler.OnEndDragEvent   = OnUnitDrop;
            }
        }
    }

    private void RefreshSlotUnits()
    {
        foreach (var slot in EnumerateSlots())
        {
            int idx = SlotIndexOf(slot);
            var u = _provider.GetSlotUnit(idx);
            if (u.HasValue) slot.SetUnitType(u.Value); // 아이콘 표시
            // 미배치는 "+" 비주얼(슬롯 프리팹의 빈 EquippedSlot 상태)
        }
    }

    // ─────────── 유닛 그리드 ───────────
    private void BuildUnitGrid()
    {
        ClearUnitGrid();
        foreach (var unit in _provider.GetAvailableUnits())
        {
            var slot = Instantiate(_unitIconSlotPrefab, _unitGridContent);
            slot.Setup(unit.ToString());           // Sprites/Units/{unitName}
            var handler = slot.GetComponent<UIEventHandler>() ?? slot.gameObject.AddComponent<UIEventHandler>();
            var captured = unit;
            handler.OnClickEvent     = _ => OnUnitClicked(captured);
            handler.OnBeginDragEvent = e => OnBeginUnitDrag(captured, e);
            handler.OnDragEvent      = OnUnitDrag;
            handler.OnEndDragEvent   = OnUnitDrop;
            _unitItems.Add(slot.gameObject);
        }
    }

    // ─────────── 클릭 배치 (슬롯 선택 → 유닛 클릭) ───────────
    private void SelectSlot(VanguardChipSlot slot)
    {
        _selectedSlot = slot;
        if (_slotSelectionHighlight != null)
        {
            _slotSelectionHighlight.SetActive(true);
            _slotSelectionHighlight.transform.position = slot.transform.position;
        }
    }
    private void ClearSelection()
    {
        _selectedSlot = null;
        if (_slotSelectionHighlight != null) _slotSelectionHighlight.SetActive(false);
    }

    private void OnUnitClicked(EUnitType unit)
    {
        if (_selectedSlot == null) return;                 // 슬롯 먼저 선택해야 장착
        AssignUnitToSlot(_selectedSlot, unit);
        ClearSelection();
    }

    // ─────────── 드래그 배치 ───────────
    private void OnBeginUnitDrag(EUnitType unit, PointerEventData e)
    {
        _dragging = true;
        _draggingUnit = unit;
        DestroyGhost();
        _dragGhost = Instantiate(_dragGhostPrefab, _dragGhostLayer);
        var sprite = Managers.Instance.GetManager<ResourceManager>()?.LoadResource<Sprite>($"Sprites/Units/{unit}");
        if (sprite != null) _dragGhost.sprite = sprite;
        _dragGhost.raycastTarget = false;
        _dragGhost.rectTransform.position = e.position;
    }
    private void OnUnitDrag(PointerEventData e)
    {
        if (_dragging && _dragGhost != null) _dragGhost.rectTransform.position = e.position;
    }
    private void OnUnitDrop(PointerEventData e)
    {
        if (!_dragging) return;
        _dragging = false;
        DestroyGhost();

        // 포인터 아래의 VanguardChipSlot 찾기 (레이캐스트)
        var slot = RaycastSlot(e);
        if (slot != null)
        {
            int idx = SlotIndexOf(slot);
            if (_chipProvider.IsSlotUnlocked(EVanguardChipKind.Exclusive, idx))
                AssignUnitToSlot(slot, _draggingUnit);
            else
                ToastManager.ShowToast(LocalizationManager.GetLocalizedText("vanguard_slot_locked"));
        }
    }

    private VanguardChipSlot RaycastSlot(PointerEventData e)
    {
        var results = new List<RaycastResult>();
        EventSystem.current.RaycastAll(e, results);
        foreach (var r in results)
        {
            var slot = r.gameObject.GetComponentInParent<VanguardChipSlot>();
            if (slot != null) return slot;
        }
        return null;
    }

    // ─────────── 배치 적용 ───────────
    private void AssignUnitToSlot(VanguardChipSlot slot, EUnitType unit)
    {
        int idx = SlotIndexOf(slot);
        // 중복 방지: 같은 유닛이 다른 슬롯에 있으면 스왑/제거 (정책 §9)
        _provider.SetSlotUnit(idx, unit);
        slot.SetUnitType(unit);
        AudioUtils.PlaySFXUnscaled("ButtonClick").Forget();
        RefreshSlotUnits();
    }

    private void OnSlotUnlock(int slotIndex) { /* 부모/서비스 해금 라우팅(서버 권위) → 성공 시 _chipPanel.Refresh() */ }

    // ─────────── 확정 ───────────
    private void OnClickComplete() => CompleteAsync().Forget();
    private async UniTaskVoid CompleteAsync()
    {
        var loading = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("loading"));
        bool ok;
        try { ok = await _provider.CommitAsync(); }
        finally { ServerLoadingPopupUI.Hide(); }
        if (!ok) { ToastManager.ShowToast(LocalizationManager.GetLocalizedText("maintenance_message")); return; }

        Managers.Instance.GetManager<UIManager>()?.Hide<VanguardUnitDeployPopup>();
        // 부모 ExclusiveChipPanel 갱신은 부모가 Hide 감지 또는 콜백으로 Refresh
    }

    // ─────────── 유틸 ───────────
    private IEnumerable<VanguardChipSlot> EnumerateSlots() { /* _chipPanel._rows[r].Slots 평탄화 — 패널에 슬롯 열거 getter 추가 권장 */ yield break; }
    private int SlotIndexOf(VanguardChipSlot slot) { /* row*_columns+col — 패널이 인덱스 매핑 제공 권장 */ return 0; }
    private void ClearUnitGrid() { foreach (var go in _unitItems) if (go) Destroy(go); _unitItems.Clear(); }
    private void DestroyGhost() { if (_dragGhost != null) Destroy(_dragGhost.gameObject); _dragGhost = null; }
}
```

> ⚠️ **슬롯 열거/인덱스 매핑**: `VanguardExclusiveChipPanel`은 현재 `_rows`가 private. 본 팝업이 슬롯을 순회/인덱싱하려면 패널에 **`IEnumerable<(int index, VanguardChipSlot slot)> EnumerateSlots()`** 같은 public getter를 추가하거나, 팝업이 `VanguardExclusiveChipRow.Slots`로 직접 순회(`_columns` 동일 규칙)하도록 패널 참조 구조를 맞춘다. (§9)

### 5-3. Localization 키 (신규)

| 키 | 내용 |
|---|---|
| `vanguard_deploy_drag_hint` | Drag the turret to change its position |
| `vanguard_slot_locked` | 잠긴 슬롯입니다(해금 필요) |
| (재사용) `complete`/`loading`/`maintenance_message` | Complete 버튼/로딩/실패 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 9유닛 목록 | 더미 | `VanguardExclusiveChipPanel.DefaultUnits` 또는 `LoadoutService`. 아이콘 `Sprites/Units/{EUnitType}` |
| 슬롯 배치(유닛↔슬롯) | ⚠️ 미연동 | `IVanguardDeployProvider`(메모리) → 정식 `VanguardLoadoutService`. **Complete에서 서버 커밋**(PvP 공정성, 서버 권위) |
| 슬롯 해금 상태 | 부모 공유 | `IVanguardChipProvider.IsSlotUnlocked/GetSlotUnlockCost(Exclusive, idx)` — 미해금 슬롯엔 배치 불가 |
| 슬롯 인덱스 매핑 | 패널 보강 | `VanguardExclusiveChipPanel`에 슬롯 열거/인덱스 getter 추가(§5-2 주의) |
| 빈 슬롯 "+" 비주얼 | 슬롯 | `VanguardChipSlot` EquippedSlot의 미배치(유닛 null) 표시 — "+" 아이콘 상태 필요(슬롯에 SetUnit(null) 류 추가 검토) |

### CLAUDE.md 준수
- `GetManager<T>()`만 / 드래그/커밋 `async` → UniTask, `async void` 금지 / 서버콜 `ServerLoadingPopupUI` / 텍스트 로컬라이즈 / `Closed`에서 그리드·고스트 정리 / 매직넘버 const.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 데이터/패널 보강**

1. [ ] `IVanguardDeployProvider` + `VanguardDeployProviderStub`(9유닛 + 슬롯 dict + CommitAsync).
2. [ ] `VanguardExclusiveChipPanel`에 슬롯 열거/인덱스 public getter 추가(팝업 순회용).
3. [ ] (선택) `VanguardChipSlot`에 "유닛 미배치(+)" 표시 메서드(`SetUnit(EUnitType?)`) 보강.

**B. 스크립트**

4. [ ] `VanguardUnitDeployPopup.cs` 작성(5-2). 빌드-그린.
5. [ ] 부모 라우팅: 빈 슬롯 클릭 → `Show<VanguardUnitDeployPopup>()` (유닛 있으면 Detail).

**C. 프리팹** (`VanguardUnitDeployPopup.prefab` 신규, 전체화면)

6. [ ] 루트 stretch + FullScreenBg(raycast target, 입력 차단).
7. [ ] 상단: `VanguardExclusiveChipPanel`(+rows/slots) 배치 → `_chipPanel`. (스샷처럼 3행)
8. [ ] 안내 텍스트 → `_dragHintText`.
9. [ ] 유닛 그리드: ScrollRect + Content(GridLayoutGroup) → `_unitGridContent`, `_unitIconSlotPrefab`=`VanguardUnitIconSlot`.
10. [ ] DragGhostLayer(최상위, raycast off) + `_dragGhostPrefab`(Image).
11. [ ] Complete 버튼 → `_completeButton`. 선택 하이라이트 오브젝트 → `_slotSelectionHighlight`.
12. [ ] 유닛 아이콘 프리팹에 `UIEventHandler` 포함 확인.

**D. 연동**

13. [ ] `_useDummy=true` 테스트: 드래그→드롭 장착 / 슬롯클릭→유닛클릭 장착 / 슬롯간 재배치 / Complete.
14. [ ] Localization 키 추가. 정식 provider(`LoadoutService`/서버 커밋) 교체.

---

## 8. 검증 체크리스트

- [ ] 빈 `VanguardChipSlot` 클릭 → 전체 화면 Deploy 팝업 오픈(화면 전체 덮음, 하위 입력 차단).
- [ ] 상단 슬롯 행 3개 + Unlock/Locked 표시(부모와 동일 상태).
- [ ] 유닛 그리드 9종 아이콘 표시 + 스크롤.
- [ ] **드래그앤드롭**: 유닛 아이콘 드래그 → 고스트가 포인터 따라감 → 해금 슬롯 위 드롭 시 장착(아이콘 반영). 미해금 슬롯 드롭 시 토스트.
- [ ] **클릭 배치**: 슬롯 클릭(하이라이트) → 유닛 클릭 → 선택 슬롯에 장착.
- [ ] **재배치**: 슬롯의 유닛을 다른 슬롯으로 드래그 → 이동/교체.
- [ ] Complete → 커밋(더미 true) → 닫기 → 부모 ExclusiveChipPanel 갱신.
- [ ] `Closed`에서 그리드/고스트 정리(누수 없음).
- [ ] CLAUDE.md 준수(GetManager/UniTask/로컬라이즈/async void 없음).

---

## 9. 미해결 / 확인 필요

- [ ] **슬롯 열거/인덱스 API**: `VanguardExclusiveChipPanel`에 public 슬롯 순회/인덱스 매핑 추가(현재 `_rows` private). 본 팝업과 부모가 동일 인덱스 규칙(row*columns+col) 공유.
- [ ] **빈 유닛("+") 상태**: `VanguardChipSlot`에 유닛 미배치 표시(SetUnit(null)/"+" 아이콘) 보강 필요 — 현재 `SetUnitType`는 항상 유닛 지정.
- [ ] **유닛 중복 배치 정책**: 같은 유닛을 두 슬롯에 둘 수 있는지 / 드롭 시 스왑·이동·복제 중 무엇인지 — 기획 확정(`AssignUnitToSlot`).
- [ ] **배치 슬롯 수 vs 9유닛**: 전투 투입 가능 슬롯 수(3?) 확인(위키: 9종 중 일부 조합 투입). 슬롯 cap과 그리드 9종 관계.
- [ ] **Complete 커밋 범위**: 슬롯 해금까지 한 번에 커밋인지, 배치만인지 — 서버 API([[2026-05-31_vanguard-server-api-spec]]).
- [ ] **그리드 열 수**: 스샷 기준(3~4열) 확정.

---

> 작성: 2026-06-04 · 선행 코드 확인(실구현): `VanguardChipSlot`(`SetUnitType`/`UnitType`/`OnEquippedSlotClicked`/`IPointerClickHandler`), `VanguardExclusiveChipPanel`(`Initialize`/`Refresh`/`DefaultUnits`/`_columns`), `VanguardExclusiveChipRow`(`Slots`), `VanguardUnitIconSlot`(`Setup(unitName)`, `Sprites/Units/{name}`), `UIEventHandler`(클릭/드래그 Action). 스샷(상단 슬롯행+드래그 안내+유닛그리드+Complete) 1:1 매핑. 드래그앤드롭 + 슬롯클릭→유닛클릭 2방식 모두 설계. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
