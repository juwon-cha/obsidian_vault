# Vanguard 뽑기 50연 천장 — 확정 칩 선택 기능 구현 명세

> 작성일: 2026-06-11
> 목표: 뱅가드 칩 뽑기를 50회 진행하면, 지정된 풀에서 **원하는 칩 1개를 확정 선택**해 획득할 수 있는 기능 구현.
> 패턴: 기존 **스킨 선택 상자(SelectionBox + SkinSelectionPopup)** 시스템과 동일한 구조로 구현.

---

## 1. 현재 코드 분석 결과

### 1.1 천장 백엔드는 이미 절반 구현되어 있음 ★

`VanguardChipGachaService.cs`에 50연 천장 코어 로직이 **이미 존재**한다. 카운트 적립/판정/수령이 전부 있고, **없는 것은 ① "어떤 칩을 선택할 수 있는지"의 데이터 테이블, ② 선택 검증, ③ 선택 UI와 진입점**이다.

`Assets/_Project/1_Scripts/Core/Managers/Vanguard/Chip/VanguardChipGachaService.cs`:

```csharp
// ── 50연 천장 (상자별 분리) ───────────
public bool IsPityReady(EVanguardChestType t) =>
    (t == EVanguardChestType.Standard ? _save?.vanguardStandardChestCount : _save?.vanguardSpecialChestCount)
        >= VanguardChipConst.PityThreshold;

public async UniTask ClaimPityAsync(EVanguardChestType t, string chosenChipId)
{
    if (_save == null || !IsPityReady(t) || string.IsNullOrEmpty(chosenChipId)) return;
    AddOwnedChip(chosenChipId);
    if (t == EVanguardChestType.Standard) _save.vanguardStandardChestCount -= VanguardChipConst.PityThreshold;
    else _save.vanguardSpecialChestCount -= VanguardChipConst.PityThreshold;
    if (_saveAsync != null) await _saveAsync();
}

public int GetPityCount(EVanguardChestType t) =>
    t == EVanguardChestType.Standard ? (_save?.vanguardStandardChestCount ?? 0) : (_save?.vanguardSpecialChestCount ?? 0);
```

- `OpenChestAsync` / `OpenChestMultiAsync`가 개봉 1회마다 `IncrementPity(chestType)` 호출 → `VanguardSaveData.vanguardStandardChestCount` / `vanguardSpecialChestCount`에 적립 (`ESaveDataType.Vanguard`, 클라 권위).
- `RerollLastResultAsync`(모듈3 새로고침)는 천장 카운트 미증가 — 기존 정책 유지.
- `VanguardChipConst.PityThreshold = 50`.
- **문제점**: 현재 `ClaimPityAsync`는 `chosenChipId`를 **검증 없이** 받는다. 아무 칩 ID나 넣으면 지급된다. 선택 가능 풀 데이터 신설 후 반드시 검증을 추가해야 한다 (§4.2).
- 호출부 검색 결과: `ClaimPityAsync`를 호출하는 UI/코드가 **아직 없다** (치트의 `GetPityCount` 표시만 존재). 시그니처 변경이 안전하다.

### 1.2 스킨 선택 상자 시스템 (미러링할 패턴)

| 역할 | 스킨 시스템 | 파일 |
|---|---|---|
| 박스 정의 테이블 | `SelectionBoxData` (boxId → groupId, nameKey, rarity) | `SOs/SO/DataSheet/SelectionBoxDataSO.cs` |
| 선택 풀 테이블 | `SelectionBoxGroupData` (groupId → currencyType 목록) | `SOs/SO/DataSheet/SelectionBoxGroupDataSO.cs` |
| 데이터 로드/조회 | `ShopManager.BuildSkinSelectionCache()` → `TryGetSkinSelectionBox(boxId)`, `GetSkinSelectionEntries(groupId)` | `Core/Managers/ShopManager.cs` |
| 선택 팝업 | `SkinSelectionPopup.ShowAndGetSelectionAsync(boxId)` → `UniTask<ECurrencyType?>` 반환 (확정/취소) | `UI/Shop/SkinSelectionPopup.cs` |
| 선택 항목 셀 | `SkinSelectionSimpleItemUI.Setup(currency, rarity, onToggle)` | `UI/Shop/SkinSelectionSimpleItemUI.cs` |
| 프리팹 | `Assets/Resources_moved/UI/SkinSelectionPopup.prefab` | — |
| 진입점 | `EventShopItemUI.HandleSelectionBoxIconClickAsync()` → 팝업 await → 선택 결과로 지급 | `UI/Shop/EventShopItemUI.cs` |

핵심 흐름 (그대로 가져올 부분):

```
진입 UI → uiManager.Show<SkinSelectionPopup>()
        → await popup.ShowAndGetSelectionAsync(boxId)   // UniTaskCompletionSource 패턴
        → 팝업: 박스 조회 → groupId의 entries 나열 → 단일 선택 토글 → 확정/취소
        → 반환값으로 보상 지급
```

### 1.3 뱅가드 칩 데이터 구조 (선택 풀의 원천)

- **`VanguardEquipmentChipPoolData`** (General 칩): `chipId`(**string**, 예 "52001"), `chipName`, `slotType`(EquipmentType), `targetUnits`, `rarityType`, `poolWeight`
- **`VanguardUnitChipPoolData`** (Exclusive 칩): `chipId`(**int**), `chipName`, `slotType`(EUnitType=소유 유닛), `targetUnits`, `rarityType`, `poolWeight`
- 두 풀은 부팅 시 `VanguardManager.BuildChipTables()`에서 `VanguardChipPoolTable.Build()`로 통합 인덱싱됨. **통합 키는 string chipId** (Unit은 `int.ToString()` 변환). `VanguardChipPoolTable.Get(chipId)`로 Entry 조회 가능.
- **`VanguardChipDropData`**: 현재 PK가 **string `id`** (`vanguard_standard_chest`, `vanguard_special_chest`) + 등급별 가중치 7종. 에셋 2개 존재 (`Assets/Resources/ScriptableObjects/VanguardChipDropData/`).
- 표시용 변환: `VanguardChipFactory.ToChip(entry, count)` → `Chip` 객체 (마스터 효과 데이터 `ChipManager.GetChipEffectData(int)` 재사용). UI 셀은 `ChipInventoryItem.Initialize(chip)` 재활용 가능.

---

## 2. 데이터 테이블 설계

스킨 시스템의 2테이블 구조(SelectionBoxData / SelectionBoxGroupData)를 미러링하되, 뱅가드는 "박스" 역할을 **상자(Chest) 자체**가 하므로 박스 테이블을 신설하는 대신 **`VanguardChipDropData`에 컬럼을 추가**하고, **선택 그룹 테이블 1개만 신설**한다.

### 2.1 [수정] VanguardChipDropData — int ID 및 천장 그룹 연결 추가

> ⚠️ `SOs/SO/DataSheet/` 클래스는 구글 시트 자동 생성이므로 **SO 클래스를 직접 수정하지 말 것**. 구글 시트에 컬럼을 추가하고 재생성한다. 커스텀 로직이 필요하면 `VanguardChipDropDataParser.cs` 분리(기존 `VanguardChipDropDataSOExtensions.cs`처럼 확장 메서드로 처리해도 됨).

추가 컬럼 3개:

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `dropId` | int | 드랍 테이블 정수 PK (신규). 외부 테이블 참조용 |
| `pityGroupId` | int | 천장 확정 선택 그룹 ID → `VanguardChipSelectionGroupData.groupId`. **0이면 천장 선택 비활성** |
| `pityTitleKey` | string | 선택 팝업 타이틀 로컬라이즈 키 |

차팅 (전체 모습, 기존 컬럼 포함):

```
[VanguardChipDropData]
ID      드랍 테이블ID             일반  고급  희귀  서사  전설  신화  초월  천장선택그룹ID  천장팝업타이틀키
int     string                   int   int   int   int   int   int   int   int            string
dropId  id                       commonWeight ... transcendWeight        pityGroupId    pityTitleKey
3001    vanguard_standard_chest  0     0     490   300   150   50    10   4001           vanguard_pity_select_standard_title
3002    vanguard_special_chest   0     0     0     0     800   150   50   4002           vanguard_pity_select_special_title
```

- ID 대역: SelectionBoxData(1xxx)/스킨 그룹(2xxx)과 겹치지 않게 **dropId=3xxx, pityGroupId=4xxx** 사용.
- 가중치 컬럼명 주의: 시트의 "신화"는 코드에서 `mysticWeight` 필드 ↔ `EChipRarityType.Mythic` 매핑 (`VanguardChipDropDataSOExtensions.GetWeight` 참조).

### 2.2 [신규] VanguardChipSelectionGroupData — 천장 확정 선택 풀

SelectionBoxGroupData 미러. `ECurrencyType` 대신 **칩 ID(int)** 를 나열한다.

```
[VanguardChipSelectionGroupData]
index   ID       칩 ID
int     int      int
index   groupId  chipId
1       4001     52001
2       4001     52002
3       4001     52003
4       4001     52016
...
20      4002     52031
21      4002     52032
22      4002     52033
...
```

차팅 규칙:

- `chipId`는 `VanguardEquipmentChipPoolData`(General) / `VanguardUnitChipPoolData`(Exclusive)의 chipId를 **그대로** 적는다. General/Exclusive 혼재 가능 — 런타임에 `chipId.ToString()`으로 통합 풀(`VanguardChipPoolTable`)을 조회하므로 종류 컬럼이 필요 없다.
- 등급/이름/아이콘 컬럼은 **두지 않는다**. 전부 풀 테이블에서 chipId로 역참조한다 (스킨 그룹이 currencyRarity를 중복 차팅했던 것과 달리, 칩은 풀 테이블이 단일 진실 소스이므로 중복 차팅 시 불일치 리스크만 생김).
- 천장 선택 풀 구성은 기획 결정 사항. 예: 일반상자(4001)=신화 칩 전체, 특수상자(4002)=초월 칩 전체. 일부만 노출하는 것도 가능(테이블에 적은 칩만 노출됨).
- SO 생성 위치: `Assets/Resources/ScriptableObjects/VanguardChipSelectionGroupData/` (행당 .asset 1개, 기존 DataSheet 파이프라인과 동일).

생성될 클래스 (자동 생성 결과 예상):

```csharp
// SOs/Class/DataSheet/VanguardChipSelectionGroupDataData.cs
[System.Serializable]
public class VanguardChipSelectionGroupDataData
{
    public int index;     // index
    public int groupId;   // ID
    public int chipId;    // 칩 ID
}

// SOs/SO/DataSheet/VanguardChipSelectionGroupDataSO.cs
[CreateAssetMenu(fileName = "VanguardChipSelectionGroupData", menuName = "GameData/CreateVanguardChipSelectionGroupDataData")]
public class VanguardChipSelectionGroupDataSO : ScriptableObject
{
    public int index;
    public int groupId;
    public int chipId;
}
```

### 2.3 대안 검토 (채택하지 않음)

- **완전 2테이블 미러** (VanguardChipSelectionData 박스 테이블 신설): 상자가 2개뿐이라 행 2개짜리 테이블이 하나 더 생길 뿐 이득이 없음. 향후 상자 종류가 늘면 그때 분리해도 마이그레이션 비용이 낮다.
- **등급 기반 자동 풀** (테이블 없이 "초월 전체" 같은 룰): 차팅 자유도(특정 칩 제외 등)가 없어서 기각.

---

## 3. 런타임 테이블 — VanguardChipSelectionTable (신규)

`VanguardChipDropTable`과 동일한 static 테이블 패턴.

**파일**: `Assets/_Project/1_Scripts/Core/Managers/Vanguard/Chip/VanguardChipSelectionTable.cs`

```csharp
using System.Collections.Generic;

/// <summary>
/// 뱅가드 천장(50연) 확정 칩 선택 풀 — groupId → 선택 가능 Entry 목록.
/// VanguardChipSelectionGroupData 시트의 chipId를 VanguardChipPoolTable에서 역참조해 인덱싱.
/// ※ 반드시 VanguardChipPoolTable.Build() 이후에 Build() 호출.
/// </summary>
public static class VanguardChipSelectionTable
{
    private static readonly Dictionary<int, List<VanguardChipPoolTable.Entry>> _byGroupId = new();
    private static readonly List<VanguardChipPoolTable.Entry> Empty = new();

    public static bool IsBuilt => _byGroupId.Count > 0;

    public static void Build(IReadOnlyList<VanguardChipSelectionGroupDataSO> rows)
    {
        _byGroupId.Clear();
        if (rows == null) return;

        foreach (var r in rows)
        {
            if (r == null || r.groupId <= 0 || r.chipId <= 0) continue;

            // 통합 풀 역참조 — 오차팅(풀에 없는 chipId) 방어: 스킵 + 경고 (VanguardChipPoolTable.Build 패턴 미러)
            var entry = VanguardChipPoolTable.Get(r.chipId.ToString());
            if (entry == null)
            {
                RLog.LogWarning($"[VanguardChipSelectionTable] 풀에 없는 chipId → 스킵 (groupId={r.groupId}, chipId={r.chipId})");
                continue;
            }

            if (!_byGroupId.TryGetValue(r.groupId, out var list))
                _byGroupId[r.groupId] = list = new List<VanguardChipPoolTable.Entry>();
            list.Add(entry);
        }

        // 노출 정렬: 등급 내림차순 → chipId 오름차순 (스킨 그룹의 currencyType 정렬 미러)
        foreach (var kv in _byGroupId)
            kv.Value.Sort((a, b) => b.rarity != a.rarity ? b.rarity.CompareTo(a.rarity)
                                                          : string.CompareOrdinal(a.chipId, b.chipId));
    }

    public static IReadOnlyList<VanguardChipPoolTable.Entry> GetEntries(int groupId)
        => _byGroupId.GetValueOrDefault(groupId) ?? Empty;

    public static bool Contains(int groupId, string chipId)
    {
        var list = _byGroupId.GetValueOrDefault(groupId);
        if (list == null) return false;
        foreach (var e in list) if (e.chipId == chipId) return true;
        return false;
    }
}
```

### 3.1 VanguardManager.BuildChipTables() 수정

```csharp
private void BuildChipTables()
{
    var rm = GetManager<ResourceManager>();
    if (rm == null) return;

    var unitPool  = rm.LoadAllResourcesInFolder<VanguardUnitChipPoolDataSO>("ScriptableObjects/VanguardUnitChipPoolData");
    var equipPool = rm.LoadAllResourcesInFolder<VanguardEquipmentChipPoolDataSO>("ScriptableObjects/VanguardEquipmentChipPoolData");
    var drops     = rm.LoadAllResourcesInFolder<VanguardChipDropDataSO>("ScriptableObjects/VanguardChipDropData");
    var selection = rm.LoadAllResourcesInFolder<VanguardChipSelectionGroupDataSO>("ScriptableObjects/VanguardChipSelectionGroupData"); // [추가]

    VanguardChipPoolTable.Build(unitPool, equipPool);
    VanguardChipDropTable.Build(drops);
    VanguardChipSelectionTable.Build(selection); // [추가] 반드시 PoolTable 이후

    if (!VanguardChipPoolTable.IsBuilt)
        RLog.LogWarning("[VanguardManager] 칩 풀 테이블 비어 있음 — ...");
    if (!VanguardChipSelectionTable.IsBuilt) // [추가]
        RLog.LogWarning("[VanguardManager] 천장 선택 테이블 비어 있음 — VanguardChipSelectionGroupData .asset 차팅 필요(천장 확정 선택 비활성).");
}
```

### 3.2 VanguardChipDropTable — 상자 SO 조회 접근자 추가

천장 그룹/타이틀 키를 상자 데이터에서 꺼내야 하므로 접근자 1개 추가:

```csharp
// VanguardChipDropTable.cs 에 추가
public static VanguardChipDropDataSO GetChest(string chestId)
    => string.IsNullOrEmpty(chestId) ? null : _chests.GetValueOrDefault(chestId);
```

---

## 4. 서비스 수정 — VanguardChipGachaService

### 4.1 선택 풀 조회 API 추가

```csharp
/// <summary>해당 상자의 천장 확정 선택 가능 칩 목록 (차팅 없으면 빈 목록 = 비활성).</summary>
public IReadOnlyList<VanguardChipPoolTable.Entry> GetPitySelectableEntries(EVanguardChestType t)
{
    var (chestId, _) = Resolve(t);
    var chest = VanguardChipDropTable.GetChest(chestId);
    if (chest == null || chest.pityGroupId <= 0) return System.Array.Empty<VanguardChipPoolTable.Entry>();
    return VanguardChipSelectionTable.GetEntries(chest.pityGroupId);
}

/// <summary>선택 팝업 타이틀 로컬라이즈 키.</summary>
public string GetPityTitleKey(EVanguardChestType t)
{
    var (chestId, _) = Resolve(t);
    return VanguardChipDropTable.GetChest(chestId)?.pityTitleKey;
}
```

### 4.2 ClaimPityAsync — 선택 풀 검증 추가 (필수)

반환 타입을 `UniTask<bool>`로 변경해 UI가 성공/실패를 알 수 있게 한다. (현재 호출부 없음 → 시그니처 변경 안전)

```csharp
/// <summary>
/// 50연 천장 수령 — 선택 풀(VanguardChipSelectionTable)에 있는 칩만 허용.
/// 성공 시 보유 +1, 해당 상자 카운트 50 차감(초과분 이월 유지).
/// </summary>
public async UniTask<bool> ClaimPityAsync(EVanguardChestType t, string chosenChipId)
{
    if (_save == null || !IsPityReady(t) || string.IsNullOrEmpty(chosenChipId)) return false;

    // [추가] 검증: 천장 선택 풀에 차팅된 칩만 지급 (임의 chipId 주입 방어)
    var (chestId, _) = Resolve(t);
    var chest = VanguardChipDropTable.GetChest(chestId);
    if (chest == null || chest.pityGroupId <= 0
        || !VanguardChipSelectionTable.Contains(chest.pityGroupId, chosenChipId))
    {
        RLog.LogWarning($"[VanguardChipGachaService] 천장 선택 풀에 없는 칩 수령 시도 → 거부 (chest={t}, chipId={chosenChipId})");
        return false;
    }

    AddOwnedChip(chosenChipId);
    if (t == EVanguardChestType.Standard) _save.vanguardStandardChestCount -= VanguardChipConst.PityThreshold;
    else _save.vanguardSpecialChestCount -= VanguardChipConst.PityThreshold;
    if (_saveAsync != null) await _saveAsync();
    return true;
}
```

세이브 데이터는 **수정 불필요** — `vanguardStandardChestCount` / `vanguardSpecialChestCount`(`SaveDataTypes.cs`, `ESaveDataType.Vanguard`)를 그대로 쓴다. 클라 권위(서버 미동기) 정책도 기존 칩 시스템과 동일하게 유지.

---

## 5. UI 구현 — SkinSelectionPopup 복사

### 5.1 프리팹

1. `Assets/Resources_moved/UI/SkinSelectionPopup.prefab` 복제 → **`VanguardChipSelectionPopup.prefab`** (같은 폴더).
   - UIManager가 클래스명으로 프리팹을 로드하므로 **프리팹 이름 = 클래스명** 필수.
2. 루트의 `SkinSelectionPopup` 컴포넌트를 `VanguardChipSelectionPopup`으로 교체 (UI Refs 7개 재연결: `_titleText`, `_contentRoot`, `_optionItemPrefab`, `_scrollRect`, `_confirmButton`, `_cancelButton`, `_backgroundCloseButton`).
3. `_optionItemPrefab`(선택 항목 셀)도 복제 후 `SkinSelectionSimpleItemUI` → `VanguardChipSelectionItemUI`로 교체. 셀 구성(`_label`, `_button`, `_itemIcon`, `_itemBg`, `_selectedMark`, `_iconButton`)은 그대로 재사용.

### 5.2 VanguardChipSelectionPopup (신규)

**파일**: `Assets/_Project/1_Scripts/UI/Vanguard/Popup/VanguardChipSelectionPopup.cs`

`SkinSelectionPopup.cs`를 복사한 뒤 아래만 바꾼다. 골격(UniTaskCompletionSource, 단일 선택 토글, 확정/취소, ScrollToSelected)은 **그대로 유지**.

| 항목 | 스킨 (원본) | 뱅가드 (변경) |
|---|---|---|
| 선택 값 타입 | `ECurrencyType?` | `string` chipId (null/empty = 취소) |
| 데이터 소스 | `ShopManager.TryGetSkinSelectionBox` / `GetSkinSelectionEntries` | `VanguardManager.ChipGacha.GetPitySelectableEntries(chestType)` |
| Show 파라미터 | `int rewardBoxId, int? selectionItemId` | `EVanguardChestType chestType` |
| 타이틀 | `box.boxNameKey` | `ChipGacha.GetPityTitleKey(chestType)` |
| PlayerPrefs 사전 선택(찜) | `eventshop_{itemId}` 저장/복원 | **제거** — 선택 즉시 지급이므로 불필요 |

```csharp
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 뱅가드 50연 천장 확정 칩 선택 팝업 — SkinSelectionPopup 미러.
/// GetPitySelectableEntries(chestType) 목록에서 1개 선택 → 확정 시 chipId 반환(취소 null).
/// 지급은 호출측(VanguardShopPanel)이 ClaimPityAsync로 수행.
/// </summary>
public class VanguardChipSelectionPopup : UIBase
{
    [Header("UI Refs")]
    [SerializeField] private TextMeshProUGUI _titleText;
    [SerializeField] private Transform _contentRoot;
    [SerializeField] private GameObject _optionItemPrefab;   // VanguardChipSelectionItemUI 프리팹
    [SerializeField] private ScrollRect _scrollRect;
    [SerializeField] private Button _confirmButton;
    [SerializeField] private Button _cancelButton;
    [SerializeField] private Button _backgroundCloseButton;

    private EVanguardChestType _chestType;
    private string _selected;   // 선택된 chipId (null = 미선택)
    private readonly Dictionary<string, VanguardChipSelectionItemUI> _itemLookup = new();
    private UniTaskCompletionSource<string> _tcs;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        if (_confirmButton != null) _confirmButton.onClick.AddListener(OnClickConfirm);
        if (_cancelButton != null) _cancelButton.onClick.AddListener(OnClickCancel);
        if (_backgroundCloseButton != null) _backgroundCloseButton.onClick.AddListener(OnClickCancel);
    }

    public async UniTask<string> ShowAndGetSelectionAsync(EVanguardChestType chestType)
    {
        _chestType = chestType;
        _selected = null;
        BuildList();
        _tcs = new UniTaskCompletionSource<string>();
        return await _tcs.Task;
    }

    private void BuildList()
    {
        ClearList();

        var gacha = Managers.Instance?.GetManager<VanguardManager>()?.ChipGacha;
        if (gacha == null) { ToastManager.ShowToast(LocalizationManager.GetLocalizedText("data_not_found")); return; }

        var titleKey = gacha.GetPityTitleKey(_chestType);
        if (_titleText != null && !string.IsNullOrEmpty(titleKey))
            _titleText.text = LocalizationManager.GetLocalizedText(titleKey);

        var entries = gacha.GetPitySelectableEntries(_chestType);
        if (entries == null || entries.Count == 0)
        { ToastManager.ShowToast(LocalizationManager.GetLocalizedText("data_not_found")); return; }

        foreach (var e in entries)
        {
            var chipId = e.chipId;
            var go = Instantiate(_optionItemPrefab, _contentRoot);
            var ui = go.GetComponent<VanguardChipSelectionItemUI>();
            if (ui == null) continue;

            ui.Setup(e, isOn => OnClickSelect(chipId, isOn));
            ui.SetSelected(_selected == chipId);
            _itemLookup[chipId] = ui;
        }
    }

    // OnClickSelect / OnClickConfirm / OnClickCancel / RefreshSelectionVisuals / ClearList / OnDestroy
    // → SkinSelectionPopup과 동일 구조 (ECurrencyType? → string, Hide<VanguardChipSelectionPopup>() 로만 치환)

    private void OnClickConfirm()
    {
        AudioUtils.PlayButtonClick();
        _tcs?.TrySetResult(_selected);
        Managers.Instance?.GetManager<UIManager>()?.Hide<VanguardChipSelectionPopup>();
    }

    private void OnClickCancel()
    {
        AudioUtils.PlayButtonClick();
        _tcs?.TrySetResult(null);
        Managers.Instance?.GetManager<UIManager>()?.Hide<VanguardChipSelectionPopup>();
    }
}
```

> 주의: 팝업이 뒤로가기/강제 Hide로 닫히는 경우 `_tcs`가 미완료로 남을 수 있다. 원본 SkinSelectionPopup과 동일한 리스크이므로, `Closed(object[] param)` 오버라이드에서 `_tcs?.TrySetResult(null)`을 한 번 더 호출해 방어하는 것을 권장 (원본 대비 개선점).

### 5.3 VanguardChipSelectionItemUI (신규)

**파일**: `Assets/_Project/1_Scripts/UI/Vanguard/Component/VanguardChipSelectionItemUI.cs`

`SkinSelectionSimpleItemUI` 복사. `ECurrencyType` 기반 표시를 칩 Entry 기반으로 치환:

```csharp
public void Setup(VanguardChipPoolTable.Entry entry, System.Action<bool> onToggle)
{
    _chipId = entry.chipId;
    _chip = VanguardChipFactory.ToChip(entry, 1);   // 마스터 효과/설명 재사용

    // 라벨: 칩 효과 설명(마스터 데이터) — 칩 이름 로컬라이즈 키 체계가 따로 있으면 그걸 사용
    if (_label != null) _label.text = LocalizationManager.GetLocalizedText(_chip.description);

    // 아이콘/프레임: 기존 칩 UI 규칙 재사용 (ChipInventoryItem 미러)
    if (_itemIcon != null)
        _itemIcon.sprite = ResourceUtility.LoadSprite(ResourceUtility.GetChipIconPath(entry.rarity));
    if (_itemBg != null)
        _itemBg.sprite = ResourceUtility.LoadSprite(ResourceUtility.GetChipRarityFramePath(entry.rarity));

    _onToggle = onToggle;
    // _button/_iconButton 바인딩, SetSelected(false) → 원본과 동일
}
```

- 단일 선택 토글/`SetSelected`/`_selectedMark` 로직은 원본 그대로.
- `_iconButton`(상세 보기): 원본은 스킨 상세 팝업 3종 분기 — 뱅가드는 칩 효과 설명이 핵심이므로 **`ChipInfoDisplay`/툴팁 재사용** 또는 셀에 설명 텍스트를 직접 노출하고 상세 버튼은 제거해도 무방. General/Exclusive 구분 표시(장착 부위 vs 소유 유닛 아이콘)는 `entry.kind`로 분기.

### 5.4 진입점 — VanguardShopPanel

**파일**: `Assets/_Project/1_Scripts/UI/Vanguard/Component/VanguardShopPanel.cs`

상자별 천장 게이지 + 선택 버튼 추가:

```csharp
[Header("Pity (50연 천장 확정 선택)")]
[SerializeField] private Button _normalPityButton;
[SerializeField] private Button _specialPityButton;
[SerializeField] private TextMeshProUGUI _normalPityCountText;   // "n / 50"
[SerializeField] private TextMeshProUGUI _specialPityCountText;
[SerializeField] private GameObject _normalPityReadyMark;        // IsPityReady 시 점등 (단순 토글 마크)
[SerializeField] private GameObject _specialPityReadyMark;

private bool _pityClaiming; // 연타 방어

private void UpdatePityUI()
{
    var gacha = Managers.Instance.GetManager<VanguardManager>()?.ChipGacha;
    if (gacha == null) return;

    UpdatePityRow(gacha, EVanguardChestType.Standard, _normalPityButton, _normalPityCountText, _normalPityReadyMark);
    UpdatePityRow(gacha, EVanguardChestType.Special,  _specialPityButton, _specialPityCountText, _specialPityReadyMark);
}

private void UpdatePityRow(VanguardChipGachaService gacha, EVanguardChestType type,
    Button button, TextMeshProUGUI countText, GameObject readyMark)
{
    bool hasPool = gacha.GetPitySelectableEntries(type).Count > 0; // 차팅 없으면 기능 숨김
    bool ready = hasPool && gacha.IsPityReady(type);

    if (button != null)
    {
        button.gameObject.SetActive(hasPool);
        button.interactable = ready;
    }
    if (countText != null)
        countText.text = $"{Mathf.Min(gacha.GetPityCount(type), VanguardChipConst.PityThreshold)} / {VanguardChipConst.PityThreshold}";
    if (readyMark != null) readyMark.SetActive(ready);
}

private async UniTaskVoid OnPityButtonClickedAsync(EVanguardChestType type)
{
    if (_pityClaiming) return;
    var gacha = Managers.Instance.GetManager<VanguardManager>()?.ChipGacha;
    if (gacha == null || !gacha.IsPityReady(type)) return;

    var uiManager = Managers.Instance.GetManager<UIManager>();
    var popup = uiManager?.Show<VanguardChipSelectionPopup>();
    if (popup == null) return;

    string chosen = await popup.ShowAndGetSelectionAsync(type);
    if (string.IsNullOrEmpty(chosen)) return;   // 취소 — 카운트 유지

    _pityClaiming = true;
    try
    {
        bool ok = await gacha.ClaimPityAsync(type, chosen);
        if (ok)
        {
            // 결과 표시: 기존 뽑기 결과 흐름과 동일하게 (현재는 토스트, 결과 연출 들어오면 교체)
            var entry = VanguardChipPoolTable.Get(chosen);
            ToastManager.ShowToast(LocalizationManager.GetLocalizedText("vanguard_pity_claim_success"));
            UpdatePityUI();
        }
    }
    finally { _pityClaiming = false; }
}
```

- `Init()`에서 버튼 바인딩(`OnPityButtonClickedAsync(...).Forget()`) + `UpdatePityUI()` 호출, 뽑기 실행 후(`OpenChestForDevAsync` 및 추후 실 뽑기 흐름)에도 `UpdatePityUI()` 갱신.
- 정식 레드닷이 필요하면 `RedDotComponent`(노드ID 기반)를 쓰되, 이 패널의 `InitRedDots()`가 아직 TODO(노드 미등록) 상태라 위 코드는 단순 `GameObject` 토글 마크로 작성했다. 레드닷 노드 등록 작업과 함께 묶어서 처리할 것.
- 게이지를 진행도 바(Image.fillAmount)로 만들 경우 `GetPityCount / PityThreshold` 사용.
- 보상 지급은 `ClaimPityAsync` 내부(`AddOwnedChip`)에서 끝난다. **스킨 패턴과 달리 `CurrencyManager.ModifyCurrency`를 호출하지 않는다** — 칩은 커런시가 아니라 `vanguardOwnedChips` 인벤토리다. (이중 지급 금지 원칙과 동일 맥락: 지급 경로는 서비스 한 곳뿐이어야 함.)

---

## 6. 전체 흐름

```
[뽑기]  VanguardShopPanel → ChipGacha.OpenChestAsync/MultiAsync
            └ IncrementPity(chestType) → vanguard{Standard|Special}ChestCount++ → SaveAsync

[천장]  VanguardShopPanel.UpdatePityUI  ←  GetPityCount / IsPityReady / GetPitySelectableEntries
            │ (count ≥ 50 && 풀 차팅됨 → 버튼 활성 + 레드닷)
            ▼
        OnPityButtonClickedAsync
            → uiManager.Show<VanguardChipSelectionPopup>()
            → await popup.ShowAndGetSelectionAsync(chestType)
                  └ ChipGacha.GetPitySelectableEntries(chestType)
                        └ VanguardChipDropTable.GetChest(chestId).pityGroupId
                              └ VanguardChipSelectionTable.GetEntries(groupId)  // 시트: VanguardChipSelectionGroupData
            → chipId 반환 (취소 시 null → 종료, 카운트 유지)
            → ChipGacha.ClaimPityAsync(chestType, chipId)
                  ├ VanguardChipSelectionTable.Contains 검증
                  ├ AddOwnedChip(chipId)          // vanguardOwnedChips +1
                  ├ count -= 50 (초과분 이월)
                  └ SaveAsync (ESaveDataType.Vanguard)
            → 결과 표시 + UpdatePityUI
```

---

## 7. 스킨 선택 상자 패턴과의 차이점 요약

| 항목 | 스킨 선택 상자 | 뱅가드 천장 선택 |
|---|---|---|
| 트리거 | 이벤트 상점 구매 (EProductType.SelectionBox) | 뽑기 50회 적립 (IsPityReady) |
| 선택 시점 | 구매 **전** 찜(PlayerPrefs `eventshop_{itemId}`) → 구매 시 지급 | 천장 도달 **후** 팝업에서 선택 → 즉시 지급 (PlayerPrefs 불필요) |
| 선택 대상 | `ECurrencyType` (스킨 커런시) | `chipId` (string, 통합 풀 키) |
| 지급 경로 | `CurrencyManager.ModifyCurrency(skin, 1)` | `VanguardChipGachaService.AddOwnedChip` (ClaimPityAsync 내부) |
| 데이터 | SelectionBoxData + SelectionBoxGroupData | VanguardChipDropData(컬럼 추가) + VanguardChipSelectionGroupData(신규) |
| 캐시 위치 | ShopManager (Dictionary 캐시) | static VanguardChipSelectionTable (기존 Drop/Pool 테이블과 통일) |
| 저장 | 영구 | 시즌 리셋 대상 (VanguardSaveData 정책 그대로) |

---

## 8. 엣지 케이스 / 주의사항

- **카운트 이월**: 50 초과 적립 가능. Claim 시 50만 차감하므로 100 이상이면 연속 수령 가능 — 수령 후 `UpdatePityUI()`로 `IsPityReady` 재평가하면 자연 처리됨.
- **취소**: 팝업 취소 시 카운트 미차감 — 다음에 다시 선택 가능.
- **오차팅 방어**: 그룹 시트의 chipId가 풀 테이블에 없으면 Build에서 스킵+경고 (`VanguardChipPoolTable` 빈 chipId 방어 패턴 미러). 그룹이 통째로 비면 천장 버튼 자체를 숨김(§5.4 `hasPool`).
- **검증 필수**: `ClaimPityAsync`에 풀 검증(§4.2)을 넣지 않으면 치트/버그로 임의 칩 지급 가능. 이번 작업의 필수 항목.
- **연타 방어**: `_pityClaiming` 플래그(§5.4). `ClaimPityAsync` 자체도 `IsPityReady` 재확인하므로 이중 안전.
- **시즌 리셋**: `vanguard*ChestCount`는 시즌 리셋 정책을 그대로 따른다(기존 명세 유지, 추가 작업 없음).
- **리롤(모듈3)**: 천장 카운트 미증가 — 기존 로직 변경 없음. 천장으로 받은 칩은 `_lastChipId`를 건드리지 않으므로 리롤 대상이 아님(현 구조 그대로 안전).
- **테이블 빌드 순서**: `VanguardChipSelectionTable.Build`는 반드시 `VanguardChipPoolTable.Build` **이후** (§3.1 순서 고정).
- **DataSheet 규칙**: SO 클래스/에셋 수동 수정 금지. 시트 수정 → 재생성. 커스텀 로직은 Parser/Extensions 분리.
- **하드코딩 금지**: "n / 50" 외 모든 노출 문자열은 `LocalizationManager.GetLocalizedText()` 사용.

### 신규 로컬라이즈 키

```
vanguard_pity_select_standard_title   # 일반상자 천장 선택 팝업 타이틀
vanguard_pity_select_special_title    # 특수상자 천장 선택 팝업 타이틀
vanguard_pity_claim_success           # 확정 칩 획득 토스트
vanguard_pity_progress_desc           # (선택) 천장 진행도 설명 문구
```

---

## 9. 구현 체크리스트

**데이터 (기획 협업)**
- [ ] 구글 시트 `VanguardChipDropData`에 `dropId`, `pityGroupId`, `pityTitleKey` 컬럼 추가 → SO 재생성
- [ ] 구글 시트 `VanguardChipSelectionGroupData` 신설 (index/groupId/chipId) → SO 생성, `Resources/ScriptableObjects/VanguardChipSelectionGroupData/`
- [ ] 천장 선택 풀 차팅 (4001=일반상자, 4002=특수상자 — 풀 구성은 기획 결정)
- [ ] 로컬라이즈 키 4종 차팅

**코드 (신규 2 + 수정 3)**
- [ ] 신규 `VanguardChipSelectionTable.cs` (§3)
- [ ] 신규 `VanguardChipSelectionPopup.cs` + `VanguardChipSelectionItemUI.cs` (§5.2~5.3)
- [ ] 수정 `VanguardChipDropTable.cs` — `GetChest()` 접근자 (§3.2)
- [ ] 수정 `VanguardManager.BuildChipTables()` — 선택 테이블 빌드 (§3.1)
- [ ] 수정 `VanguardChipGachaService.cs` — `GetPitySelectableEntries`/`GetPityTitleKey` 추가, `ClaimPityAsync` 검증 + `UniTask<bool>` (§4)
- [ ] 수정 `VanguardShopPanel.cs` — 천장 게이지/버튼/레드닷 (§5.4)

**프리팹**
- [ ] `SkinSelectionPopup.prefab` 복제 → `VanguardChipSelectionPopup.prefab` (Resources_moved/UI/, 이름=클래스명)
- [ ] 옵션 셀 프리팹 복제 → `VanguardChipSelectionItemUI` 교체

**테스트**
- [ ] 치트 추가: 천장 카운트 임의 설정 (`CheatCommandLibrary`에 뱅가드 상자 치트 있음 — 인접 위치에 `vanguard_pity_set <type> <count>` 추가 권장)
- [ ] 50회 미만 → 버튼 비활성 / 50회 도달 → 활성+레드닷
- [ ] 선택→확정 → 보유 +1, 카운트 -50, 저장 후 재시작에도 유지
- [ ] 취소 → 카운트 유지
- [ ] 풀에 없는 chipId로 `ClaimPityAsync` 직접 호출 → false 반환 확인
- [ ] 카운트 120 적립 → 2회 연속 수령 → 잔여 20 확인
- [ ] 그룹 미차팅 상태 → 천장 버튼 숨김 + 경고 로그

---

## 10. 참조 파일 인덱스

| 파일 | 역할 |
|---|---|
| `Core/Managers/Vanguard/Chip/VanguardChipGachaService.cs` | 뽑기/천장 코어 (수정) |
| `Core/Managers/Vanguard/Chip/VanguardChipDropTable.cs` | 상자 드랍 테이블 (수정) |
| `Core/Managers/Vanguard/Chip/VanguardChipPoolTable.cs` | 통합 칩 풀 (참조) |
| `Core/Managers/Vanguard/Chip/VanguardChipFactory.cs` | Entry→Chip 변환 (참조) |
| `Core/Managers/Vanguard/Chip/VanguardChipConst.cs` | `PityThreshold = 50` (참조) |
| `Core/Managers/Vanguard/VanguardManager.cs` | 테이블 빌드/세이브 (수정) |
| `Core/Managers/SaveDataTypes.cs` | `vanguard*ChestCount` (참조, 수정 없음) |
| `UI/Shop/SkinSelectionPopup.cs` | 복사 원본 |
| `UI/Shop/SkinSelectionSimpleItemUI.cs` | 복사 원본 |
| `UI/Vanguard/Component/VanguardShopPanel.cs` | 진입점 (수정) |
| `Assets/Resources_moved/UI/SkinSelectionPopup.prefab` | 프리팹 복사 원본 |
| `Assets/Resources/ScriptableObjects/VanguardChipDropData/` | 상자 에셋 2개 (시트 재생성 대상) |
