# SkillEquipPopup sync 분석 문서
## FROM 프로젝트(BunkerDefense) → TO 프로젝트(WiggleDefender)

> **작성일**: 2026-04-07
> **소스**: FROM 프로젝트 (`/Volumes/solidigm/repo/BunkerDefense`)
> **대상**: TO 프로젝트 (`juwon/UpdateSync` 브랜치)
> **범용 규칙 참조**: `WD_SYNC_GUIDE.md`

---

## 사전 조건 — FROM 소스 확인

```bash
# BunkerDefense 로컬 경로 직접 접근 (FETCH_HEAD 미설정 시 대체)
ls /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/
```

---

## 0. sync 전 grep 전수조사 결과

```bash
# FROM에서 SkillEquipPopup 참조 파일 목록
grep -rl "SkillEquipPopup\|SkillEquipPanel\|UnitFilterButtonEntry\|UnitFilterButton" \
    /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts --include="*.cs"

# TO에서 동일 키워드 참조 파일 목록
grep -rl "SkillEquipPopup\|SkillEquipPanel\|UnitFilterButtonEntry\|UnitFilterButton" \
    /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts --include="*.cs"
```

| FROM 파일 | 역할 | FROM 전용 패턴 | sync 유형 | TO 처리 방법 |
|---------|------|------------|---------|-------------|
| `UI/Skin/SkillEquipPopup.cs` | 영웅 스킬 장착 팝업 (UIBase 상속) | 없음 (TO 패턴과 동일) | **PARTIAL** | 신규 생성. TO의 기존 `SkillEquipPanel` 교체 대상 |
| `UI/Skin/UnitFilterButtonEntry.cs` | UnitFilterButton + EUnitType 연결 struct | 없음 | **DIRECT** | 신규 생성 (TO에 없음) |
| `UI/Skin/HeroSkinUI.cs` | 영웅 스킨 선택·해금·장착·랭크업 UI | 없음 (LimitBreak 필드만 추가) | **ADAPTED** | 기존 TO 파일 수정: `_skillEquipPanel` → `SkillEquipPopup` 방식, LimitBreak 필드 추가 |
| `UI/Loadout/LoadoutHeroSkillModule.cs` | 로드아웃 팝업의 영웅 스킬 표시 모듈 | 없음 | **ADAPTED** | 기존 TO 파일 수정: TODO 주석 해제 |
| `UI/UnitSkin/UnitSkinSkillEquipPanelUI.cs` | 유닛 스킨 스킬 장착 패널 UI | 없음 | **ADAPTED** | 기존 TO 파일 수정: 필터 기능 추가 |
| `UI/Skin/BunkerSkinDetailPanel.cs` | 벙커 스킨 상세 정보 패널 | 없음 | **DIRECT** | sync 불필요 (TO에 이미 동일 존재) |
| `UI/BunkerSkin/BunkerSkinSkillEquipPanelUI.cs` | 벙커 스킨 스킬 3슬롯 장착/해제 패널 | 없음 | **DIRECT** | sync 불필요 |
| `UI/Loadout/LoadoutBunkerSkinModule.cs` | 로드아웃 팝업의 벙커 스킨 스킬 표시 모듈 | 없음 | **DIRECT** | sync 불필요 |
| `UI/Loadout/LoadoutUnitSkillModule.cs` | 로드아웃 팝업의 유닛 스킬 표시 모듈 | 없음 | **DIRECT** | sync 불필요 |
| `UI/UnitSkin/UnitSkinDetailPanel.cs` | 유닛 스킨 상세 정보 패널 | 없음 | **DIRECT** | sync 불필요 |
| `UI/UnitSkin/UnitSkinSkillItemUI.cs` | 유닛 스킨 스킬 목록 아이템 UI | 없음 | **DIRECT** | sync 불필요 |

> **sync 유형 기준** (상세: `WD_SYNC_GUIDE.md` 섹션 2 Step 3a)
> - **DIRECT**: FROM 전용 패턴 없음, 의존성 전부 TO 존재 → 그대로 복사 or sync 불필요
> - **ADAPTED**: 규칙 1~15 변환이 아닌 로직 차이 수정 필요 → 기존 TO 파일 수정
> - **PARTIAL**: 일부 의존성이 TO에 없음 → 대체/추가/스텁 처리 후 아래 표에 기록

> **⚠️ 이 표가 완성되기 전까지 sync을 시작하지 않는다. 외부 호출자 누락과 PARTIAL 파일 미확인이 가장 흔한 실패 원인.**

### 0.1 PARTIAL 파일 의존성 상세

| 파일 | 미sync 의존성 | TO 대체 처리 | 향후 조치 |
|------|------------|------------|---------|
| `UI/Skin/SkillEquipPopup.cs` (FROM → TO 신규) | `UnitFilterButtonEntry` struct — TO에 없음 | 함께 신규 생성 | 이 파일 생성 전에 먼저 `UnitFilterButtonEntry.cs` 생성 |
| `UI/Skin/HeroSkinUI.cs` (수정 대상) | `SkillEquipPopup` 클래스 — TO에 없음 (현재 `SkillEquipPanel` 사용) | `SkillEquipPanel` SerializeField 제거, `_uiManager.Show<SkillEquipPopup>()` 방식으로 교체 | `SkillEquipPopup` sync 후 이 파일 수정 |
| `UI/Loadout/LoadoutHeroSkillModule.cs` (수정 대상) | `SkillEquipPopup` 클래스 — TO에 없음 (TODO 주석으로 보류 중) | `SkillEquipPopup` sync 후 TODO 주석 해제 | `SkillEquipPopup` sync 후 즉시 주석 해제 |

---

## 1. FROM vs TO 현재 상태 비교

### 1.1 TO에 이미 존재하는 요소

| 파일/클래스 | TO 경로 | 상태 |
|------------|---------|------|
| `SkillEquipPanel` | `Assets/_Project/1_Scripts/UI/Skin/SkillEquipPanel.cs` | ✅ 존재 — MonoBehaviour 기반, UIBase 미상속. **SkillEquipPopup sync 후 삭제 or 병존** |
| `UIBase` | `Assets/_Project/1_Scripts/UI/UIBase.cs` | ✅ 존재 — `Opened(object[])`, `HideDirect()` 시그니처 확인 완료 |
| `FilterButtonBase<T>` | `Assets/_Project/1_Scripts/UI/Button/FilterButton.cs` | ✅ 존재 — `SetToggleState(bool, bool)`, `Data` 프로퍼티 확인 완료 |
| `UnitFilterButton` | `Assets/_Project/1_Scripts/UI/Button/UnitFilterButton.cs` | ✅ 존재 — `FilterButtonBase<EUnitType>` 상속 확인 완료 |
| `FilterAllButton<T>` | `Assets/_Project/1_Scripts/UI/Button/FilterAllButton.cs` | ✅ 존재 |
| `ResourceUtility.LoadSprite()` | TO 스크립트 다수에서 사용 확인 | ✅ 존재 |
| `ResourceUtility.GetUnitIconPath()` | TO 스크립트 다수에서 사용 확인 | ✅ 존재 |
| `EUnitType.Bunker` | TO `EUnitType` enum | ✅ 존재 |
| `SkinManager` 관련 메서드들 | `SkinManager.cs` | ✅ 존재 (SkillEquipPanel.cs에서 이미 사용 중) |
| `SkillSlotUI` | `Assets/_Project/1_Scripts/UI/Skin/SkillSlotUI.cs` | ✅ 존재 |
| `SkillItemUI` | `Assets/_Project/1_Scripts/UI/Skin/SkillItemUI.cs` | ✅ 존재 |

### 1.2 TO에 없는 요소 (sync 필요)

| 카테고리 | 항목 | 작업 |
|----------|------|------|
| **새 파일** | `UnitFilterButtonEntry.cs` | 신규 생성 (5줄 struct) |
| **새 파일** | `SkillEquipPopup.cs` | FROM `SkillEquipPopup.cs` 그대로 복사 (DIRECT 패턴, 변환 불필요) |
| **수정** | `HeroSkinUI.cs` | `_skillEquipPanel` 필드 → `_uiManager.Show<SkillEquipPopup>()` 방식으로 교체, LimitBreak 필드 추가 |
| **수정** | `LoadoutHeroSkillModule.cs` | TODO 주석 해제 |
| **수정** | `UnitSkinSkillEquipPanelUI.cs` | 필터 기능(UnitFilterButtonEntry[], FilterButtonBase 로직) 추가 |
| **UIManager 등록** | `SkillEquipPopup` | 프리팹 임포트 후 UIManager에 등록 필요 |

---

## 2. FROM 원본 파일 분석

### 2.1 `SkillEquipPopup.cs` (신규 sync — PARTIAL)

**FROM 전용 패턴 확인**:
```bash
grep -n "ServiceAccessor\|Inject\|MessageBroker\|using Geuneda\|using UniRx\|BaseService\|DateTime\.Now\|Resources\.Load\|ToUniTask\|async void\|SavePlayerDataAsync" \
    /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/SkillEquipPopup.cs
# 결과: 해당 없음 (모두 WD 패턴 사용)
```

**FROM 전용 패턴 (변환 필요)**: **없음** — 이미 TO 패턴과 동일하게 작성됨.

**필드**:
```csharp
[SerializeField] private GameObject _panelContainer;
[SerializeField] private Button _closeButton;
[SerializeField] private Button _closeButton2;
[SerializeField] private SkillSlotUI[] _skillSlots = new SkillSlotUI[3];
[SerializeField] private Transform _skillListContainer;
[SerializeField] private SkillItemUI _skillItemPrefab;
[SerializeField] private ScrollRect _skillListScrollRect;
[SerializeField] private Button _unitFilterAllButton;
[SerializeField] private UnitFilterButtonEntry[] _unitFilterButtons;   // ← UnitFilterButtonEntry 필요
[SerializeField] private Sprite _emptySlotSprite;

private SkinManager _skinManager;
private UIManager _uiManager;
private List<SkinSkillDataSO> _unlockedSkills = new List<SkinSkillDataSO>();
private readonly List<SkillItemUI> _skillItemUIs = new List<SkillItemUI>();
private readonly Dictionary<int, int> _skillLevels = new Dictionary<int, int>();
private readonly HashSet<EUnitType> _selectedUnitTypes = new HashSet<EUnitType>();
private readonly List<FilterButtonBase<EUnitType>> _activeFilterButtons = new List<FilterButtonBase<EUnitType>>();
private bool _isAllFilterOn;
private bool _isInitialized;
```

**이벤트 (구독)**:
```csharp
_skinManager.OnSkillsEquipped += OnSkillsEquipped;   // 해제: OnDestroy
_skinManager.OnSkinRankUp += OnSkinRankUp;            // 해제: OnDestroy
```

**메서드 목록** (FROM 원본 순서 유지):
```csharp
protected override void Awake()
private void Start()
private void OnDestroy()
public override void Opened(object[] param)    // UIBase override
public override void HideDirect()              // UIBase override
private void Initialize()
public void ShowPanel()
public void HidePanel()
private void RefreshSkillData()
private void UpdateSkillSlots()
private void OnSkillSlotClicked(int slotIndex)
private void CreateSkillItems()
private void ApplySkillFilter()
private void RefreshAllSkillItemsUI()
private Sprite GetUnitIcon(EUnitType unitType)
private void ShowSkillTooltip(SkinSkillDataSO skillData, int skillLevel)
private void InitializeUnitFilterButtons()
private void OnAllFilterButtonClicked()
private void OnUnitFilterChanged(EUnitType unitType, bool isOn)
private async UniTaskVoid AutoEquipSkillAsync(int skillID)
private async UniTaskVoid UnequipSkillAsync(int slotIndex, int subIndex)
private void RefreshAfterChange()
private void OnSkillsEquipped(List<int> equippedSkillIDs)
private void OnSkinRankUp(int skinID, int newRank)
```

**비고**:
- `HidePanel()`이 내부에서 `_uiManager.Hide<SkillEquipPopup>()`를 호출함 → UIBase 방식과 일치
- TO의 기존 `SkillEquipPanel.cs`(MonoBehaviour)와 로직 90% 동일하나 UIBase 상속 + 유닛 필터 기능이 추가됨
- DOTween 애니메이션(`ShowPanelAnimation` / `HidePanelAnimation`)이 FROM에는 없음. TO `SkillEquipPanel`에는 있었으나 `SkillEquipPopup`에는 없으므로, sync 시 **DOTween 코드는 추가하지 않음** (FROM 원본 유지)

---

### 2.2 `UnitFilterButtonEntry.cs` (신규 sync — DIRECT)

**FROM 전용 패턴**: 없음

```csharp
[Serializable]
public struct UnitFilterButtonEntry
{
    public EUnitType unitType;
    public UnitFilterButton button;
}
```

그대로 복사. 의존성:
- `EUnitType` ✅ TO 존재
- `UnitFilterButton` ✅ TO 존재

---

### 2.3 `HeroSkinUI.cs` (ADAPTED — 기존 TO 파일 수정)

**FROM vs TO 핵심 차이점**:

| 항목 | FROM (BunkerDefense) | TO (WiggleDefender 현재) |
|------|---------------------|------------------------|
| 스킬 장착 열기 방식 | `_uiManager?.Show<SkillEquipPopup>()` | `_skillEquipPanel.ShowPanel()` (SerializeField 직접 참조) |
| `_skillEquipPanel` 필드 | 없음 (주석: "SkillEquipPopup은 UIManager.Show로 열림") | `[SerializeField] private SkillEquipPanel _skillEquipPanel;` |
| `_limitBreakButtonBox` 필드 | `[SerializeField] private GameObject _limitBreakButtonBox;` | 없음 |
| `_limitBreakButton` 필드 | `[SerializeField] private Button _limitBreakButton;` | 없음 |
| `_limitBreakStarSprite` 필드 | `[SerializeField] private Sprite _limitBreakStarSprite;` | 없음 |
| `UpdateButtonStates()` | `isLimitBreak` 조건 분기 (`showRankUp` / `showLimitBreak`) | 단순 `isMaxLevel` 판단 |
| `UpdateRankStars()` | LimitBreak 스프라이트 분기 (`filledSprite`, `emptySprite` 선택) | `_starFilledSprite` / `_starEmptySprite` 단순 적용 |
| `RegisterButtonEvents()` | `_limitBreakButton?.onClick.AddListener(ShowRankUpPopup)` | 없음 |
| `ShowSkillEquipPanel()` | `_uiManager?.Show<SkillEquipPopup>()` | `_skillEquipPanel.gameObject.SetActive(true)` + `ShowPanel()` |

**주의사항**: FROM에서 `LimitBreak` 관련 UI는 코드 내에 `// TODO(skin-limit-break): 스킨 초월 시스템 보류` 주석이 달려 있어 `isLimitBreak = false`로 강제 비활성화됨. 필드는 추가하되 기능은 비활성화 상태로 유지.

---

### 2.4 `LoadoutHeroSkillModule.cs` (ADAPTED — 기존 TO 파일 수정)

**FROM vs TO 차이**:
- FROM `OnEditButtonClicked()`: `_uiManager.Show<SkillEquipPopup>();`
- TO `OnEditButtonClicked()`: TODO 주석으로 비활성화
  ```csharp
  // TODO: SkillEquipPopup sync 필요!
  // _uiManager.Show<SkillEquipPopup>();
  ```

수정 범위가 1줄이므로 `SkillEquipPopup` sync 완료 즉시 주석 해제하면 됨.

---

### 2.5 `UnitSkinSkillEquipPanelUI.cs` (ADAPTED — 기존 TO 파일 수정)

**FROM vs TO 핵심 차이점**:

| 항목 | FROM (BunkerDefense) | TO (WiggleDefender 현재) |
|------|---------------------|------------------------|
| 유닛 필터 필드 | `_unitFilterAllButton`, `_unitFilterButtons[]`, `_selectedUnitTypes`, `_activeFilterButtons`, `_isAllFilterOn` | 없음 |
| `UIBase.Opened()` | override 구현 있음 | 없음 (UIBase 상속은 동일) |
| `UIBase.HideDirect()` | override 구현 있음 | 없음 |
| `ShowPanel()` | 필터 초기화 포함 (`InitializeUnitFilterButtons()`, `ApplySkillFilter()`) | DOTween 애니메이션 포함, 필터 없음 |
| `HidePanel()` | 단순 `_uiManager.Hide<>()` | DOTween 애니메이션 포함 후 `_uiManager.Hide<>()` |
| `Initialize()` | UIBase `protected override void Awake()` 패턴, `_isInitialized` guard | 일반 `private void Initialize()`, guard 없음 |
| `_isInitialized` guard | 있음 | 없음 |

**sync 전략**: TO 파일에 필터 관련 필드와 메서드(`InitializeUnitFilterButtons()`, `OnAllFilterButtonClicked()`, `OnUnitFilterChanged()`, `ApplySkillFilter()`)를 추가. DOTween 애니메이션은 TO의 기존 코드를 유지(FROM에는 없음). UIBase override 메서드(`Opened()`, `HideDirect()`)도 추가.

---

## 3. TO 호출 대상 메서드 존재 확인

### 3.1 SkinManager 메서드 (SkillEquipPopup에서 호출)

| 호출 메서드 | TO 확인 방법 | 상태 |
|------------|------------|------|
| `_skinManager.GetUnlockedSkills()` | TO `SkillEquipPanel.cs`에서 이미 사용 중 | ✅ 존재 |
| `_skinManager.GetUnlockedSkinsOnly(ESkinType.Hero)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.IsSkinUnlocked(int)` | TO 다수 파일 사용 | ✅ 존재 |
| `_skinManager.GetSkinRank(int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.GetEquippedSkillsInSlot(int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.EquippedSkills` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.UnequipSkillAsync(int, int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.GetSkillData(int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.GetSlotTargetUnit(int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.GetEquippedCountInSlot(int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.EquipSkillAsync(int, int)` | TO `SkillEquipPanel.cs`에서 사용 중 | ✅ 존재 |
| `_skinManager.GetSkinData(int)` | TO 다수 파일 사용 | ✅ 존재 |
| `_skinManager.OnSkillsEquipped` 이벤트 | TO `SkillEquipPanel.cs`에서 구독 중 | ✅ 존재 |
| `_skinManager.OnSkinRankUp` 이벤트 | TO `SkillEquipPanel.cs`에서 구독 중 | ✅ 존재 |

### 3.2 UI 컴포넌트 메서드

| 호출 메서드 | TO 대상 클래스 | 상태 | 처리 |
|------------|-------------|------|------|
| `slot.Initialize(int, Action<int>)` | `SkillSlotUI.cs` | ✅ 존재 (SkillEquipPanel에서 사용 중) | — |
| `slot.UpdateDisplay()` | `SkillSlotUI.cs` | ✅ 존재 | — |
| `skillItem.Initialize(SkinSkillDataSO, int, Sprite, Action, Action)` | `SkillItemUI.cs` | ✅ 존재 (SkillEquipPanel에서 사용 중) | — |
| `skillItem.RefreshUI()` | `SkillItemUI.cs` | ✅ 존재 | — |
| `skillItem.GetTargetUnitType()` | `SkillItemUI.cs` | ⚠️ TO에 없음 | `SkillItemUI.cs`에 메서드 추가 필요 |
| `skillItem.GetSkillID()` | `SkillItemUI.cs` | ✅ line 79 존재 | — |
| `skillItem.UpdateSkillLevel(int)` | `SkillItemUI.cs` | ✅ line 87 존재 | — |
| `entry.button.Initialize(EUnitType, Sprite, null, Action<EUnitType,bool>, null)` | `UnitFilterButton.cs` → `FilterButtonBase<T>.Initialize()` | ✅ 존재 (시그니처 확인 완료) | — |
| `entry.button.SetToggleState(bool, bool)` | `FilterButtonBase<T>` | ✅ 존재 | — |
| `entry.button.Data` | `FilterButtonBase<T>` | ✅ 존재 | — |
| `ResourceUtility.LoadSprite(string)` | TO 다수 파일에서 사용 중 | ✅ 존재 | — |
| `ResourceUtility.GetUnitIconPath(EUnitType)` | TO 다수 파일에서 사용 중 | ✅ 존재 | — |

```bash
# sync 전 필수 확인 — SkillItemUI의 해당 메서드 존재 여부
grep -n "GetTargetUnitType\|GetSkillID\|UpdateSkillLevel" \
    /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts/UI/Skin/SkillItemUI.cs
```

### 3.3 Show<T> UI 클래스 존재 확인

```bash
grep -n "Show<\|Hide<" \
    /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/SkillEquipPopup.cs
```

| 참조 클래스 | TO 존재 여부 | 처리 |
|-----------|-----------|------|
| `SkillEquipPopup` (`Hide<SkillEquipPopup>()` — 자기 자신) | ⚠️ TO 미sync (이번 sync 대상) | `SkillEquipPopup.cs` 신규 생성 후 UIManager에 등록 |

---

## 4. TO에서 수정이 필요한 기존 파일

### 4.1 `HeroSkinUI.cs` 수정

**파일**: `Assets/_Project/1_Scripts/UI/Skin/HeroSkinUI.cs`

**변경 1: 필드 수정 — `_skillEquipPanel` 제거 + LimitBreak 필드 추가**

```csharp
// BEFORE (TO 현재)
[Header("스킬 장착 패널")]
[SerializeField] private SkillEquipPanel _skillEquipPanel;

[Header("별 아이콘")]
[SerializeField] private Sprite _starFilledSprite;
[SerializeField] private Sprite _starEmptySprite;
```

```csharp
// AFTER (FROM 패턴 적용)
[Header("스킬 장착 패널")]
// SkillEquipPopup은 UIManager.Show로 열림 (프리팹 직접 참조 불필요)

[Header("별 아이콘")]
[SerializeField] private Sprite _starFilledSprite;
[SerializeField] private Sprite _starEmptySprite;
[SerializeField] private Sprite _limitBreakStarSprite;
```

**변경 2: 버튼 필드 — LimitBreak 버튼 추가**

```csharp
// BEFORE (TO 현재)
[SerializeField] private GameObject _rankupButtonBox;
[SerializeField] private Button _rankUpButton;
[SerializeField] private Button _skillEquipButton;
```

```csharp
// AFTER
[SerializeField] private GameObject _rankupButtonBox;
[SerializeField] private Button _rankUpButton;
[SerializeField] private GameObject _limitBreakButtonBox;
[SerializeField] private Button _limitBreakButton;
[SerializeField] private Button _skillEquipButton;
```

**변경 3: `RegisterButtonEvents()` — LimitBreak 버튼 이벤트 추가**

```csharp
// BEFORE (TO 현재, RegisterButtonEvents 내)
_rankUpButton.onClick.AddListener(ShowRankUpPopup);
_skillEquipButton.onClick.AddListener(ShowSkillEquipPanel);
```

```csharp
// AFTER
_rankUpButton.onClick.AddListener(ShowRankUpPopup);
if (_limitBreakButton != null)
    _limitBreakButton.onClick.AddListener(ShowRankUpPopup);
_skillEquipButton.onClick.AddListener(ShowSkillEquipPanel);
```

**변경 4: `ShowSkillEquipPanel()` — UIManager.Show 방식으로 교체**

```csharp
// BEFORE (TO 현재)
private void ShowSkillEquipPanel()
{
    if (_currentSkinData == null || _skillEquipPanel == null) return;
    
    // First-click clear: ...
    try { ... }
    catch (System.Exception e) { ... }
    
    _skillEquipPanel.gameObject.SetActive(true);
    _skillEquipPanel.ShowPanel();
}
```

```csharp
// AFTER (FROM 패턴)
private void ShowSkillEquipPanel()
{
    if (_currentSkinData == null) return;

    // First-click clear: consume PlayerPrefs and deactivate this node's red dot
    try
    {
        const string prefKey = "RedDot.FirstUnlock.HeroSkin";
        if (PlayerPrefs.GetInt(prefKey, 0) == 1)
        {
            PlayerPrefs.SetInt(prefKey, 2);
            PlayerPrefs.Save();
            var redDotManager = Managers.Instance?.GetManager<RedDotManager>();
            redDotManager?.CheckHeroSkinSkillEquipAvailability();
        }
    }
    catch (System.Exception e)
    {
        RLog.LogWarning($"[HeroSkinUI] Failed to clear hero stat red dot on click: {e.Message}");
    }

    _uiManager?.Show<SkillEquipPopup>();
}
```

**변경 5: `UpdateRankStars()` — LimitBreak 스프라이트 분기 추가**

```csharp
// BEFORE (TO 현재)
private void UpdateRankStars()
{
    bool isUnlocked = _skinManager.IsSkinUnlocked(_currentSkinData.SkinID);
    int currentRank = isUnlocked ? _skinManager.GetSkinRank(_currentSkinData.SkinID) : 0;
    
    for (int i = 0; i < _rankStarsContainer.childCount && i < 5; i++)
    {
        var starImage = _rankStarsContainer.GetChild(i).GetComponent<Image>();
        if (starImage != null)
        {
            starImage.sprite = (i < currentRank) ? _starFilledSprite : _starEmptySprite;
        }
    }
}
```

```csharp
// AFTER (FROM 패턴)
private void UpdateRankStars()
{
    bool isUnlocked = _skinManager.IsSkinUnlocked(_currentSkinData.SkinID);
    int currentRank = isUnlocked ? _skinManager.GetSkinRank(_currentSkinData.SkinID) : 0;

    // TODO(skin-limit-break): 스킨 초월 시스템 보류 - 재활성화 시 원복
    // bool isLimitBreak = currentRank > SkinDataSO.NORMAL_MAX_RANK;
    bool isLimitBreak = false;
    int displayRank = isLimitBreak ? currentRank - SkinDataSO.NORMAL_MAX_RANK : currentRank;
    var filledSprite = isLimitBreak ? (_limitBreakStarSprite ?? _starFilledSprite) : _starFilledSprite;
    var emptySprite = isLimitBreak ? _starFilledSprite : _starEmptySprite;

    for (int i = 0; i < _rankStarsContainer.childCount && i < 5; i++)
    {
        var starImage = _rankStarsContainer.GetChild(i).GetComponent<Image>();
        if (starImage != null)
        {
            starImage.sprite = (i < displayRank) ? filledSprite : emptySprite;
        }
    }
}
```

**변경 6: `UpdateButtonStates()` — LimitBreak 버튼 분기 추가**

```csharp
// BEFORE (TO 현재 — 해금된 경우 내부 로직)
bool isMaxLevel = isUnlocked && (_skinManager.GetNextSkinData(...) != null);
bool canRankUp = _skinManager.CanRankUpSkin(_currentSkinData.SkinID);
var comp = _rankUpButton.gameObject.GetComponent<RedDotComponent>();
// ... RedDot 설정
_rankupButtonBox.gameObject.SetActive(isMaxLevel);
```

```csharp
// AFTER (FROM 패턴 — isLimitBreak 분기 추가)
bool hasNextRank = isUnlocked && (_skinManager.GetNextSkinData(_currentSkinData.SkinID, _currentSkinData.SkinType) != null);
// TODO(skin-limit-break): 스킨 초월 시스템 보류 - 재활성화 시 원복
// bool isLimitBreak = isUnlocked && _skinManager.IsInLimitBreakRange(_currentSkinData.SkinID);
bool isLimitBreak = false;

// 기존 canRankUp, RedDot 로직 동일

bool showRankUp = hasNextRank && !isLimitBreak;
bool showLimitBreak = hasNextRank && isLimitBreak;

// 한계돌파 버튼 레드닷
if (_limitBreakButton != null)
{
    var lbComp = _limitBreakButton.gameObject.GetComponent<RedDotComponent>();
    if (lbComp == null) lbComp = _limitBreakButton.gameObject.AddComponent<RedDotComponent>();
    lbComp.SetRedDotActive(canRankUp && showLimitBreak);
}

_rankupButtonBox.gameObject.SetActive(showRankUp);
if (_limitBreakButtonBox != null)
    _limitBreakButtonBox.SetActive(showLimitBreak);

// ... 해금 안된 경우
if (_limitBreakButtonBox != null)
    _limitBreakButtonBox.SetActive(false);
```

---

### 4.2 `LoadoutHeroSkillModule.cs` 수정

**파일**: `Assets/_Project/1_Scripts/UI/Loadout/LoadoutHeroSkillModule.cs`

```csharp
// BEFORE (TO 현재 — OnEditButtonClicked 내부)
if (_uiManager != null)
{
    // TODO: SkillEquipPopup sync 필요!
    // _uiManager.Show<SkillEquipPopup>();
}
```

```csharp
// AFTER
if (_uiManager != null)
{
    _uiManager.Show<SkillEquipPopup>();
}
```

---

### 4.3 `UnitSkinSkillEquipPanelUI.cs` 수정

**파일**: `Assets/_Project/1_Scripts/UI/UnitSkin/UnitSkinSkillEquipPanelUI.cs`

**변경 1: 필터 필드 추가 (기존 필드들 아래에 추가)**

```csharp
// 추가 위치: _skillListScrollRect 아래
[Header("유닛 필터")]
[SerializeField] private Button _unitFilterAllButton;
[SerializeField] private UnitFilterButtonEntry[] _unitFilterButtons;
```

**변경 2: Private 필드 추가**

```csharp
// 추가 위치: private 필드 블록 내
private readonly HashSet<EUnitType> _selectedUnitTypes = new HashSet<EUnitType>();
private readonly List<FilterButtonBase<EUnitType>> _activeFilterButtons = new List<FilterButtonBase<EUnitType>>();
private bool _isAllFilterOn;
private bool _isInitialized;
```

**변경 3: `Awake()` → `UIBase protected override void Awake()` 변환**

```csharp
// BEFORE
private void Awake()

// AFTER
protected override void Awake()
{
    base.Awake();
    // 기존 코드 유지
}
```

**변경 4: `Initialize()` — `_isInitialized` guard 추가 및 필터 초기화 제거**

```csharp
// BEFORE: Initialize()에서 RefreshSkillData() + UpdateUI() + RefreshAllSkillItemsUI() 직접 호출
// AFTER: Initialize()에는 매니저 캐싱, 슬롯 초기화, 버튼, 이벤트 구독만 수행
// (ShowPanel에서 RefreshSkillData → InitializeUnitFilterButtons → UpdateSkillSlots → CreateSkillItems → ApplySkillFilter 호출)

private void Initialize()
{
    if (_isInitialized) return;
    _isInitialized = true;
    // ... 기존 초기화 코드 (매니저, 슬롯, 버튼, 이벤트 구독만)
    // RefreshSkillData(), UpdateUI(), RefreshAllSkillItemsUI() 호출 제거
}
```

**변경 5: UIBase override 메서드 추가**

```csharp
// 추가 위치: UIBase Override 섹션 신규 추가
public override void Opened(object[] param)
{
    base.Opened(param);
    if (!_isInitialized) Initialize();
    ShowPanel();
}

public override void HideDirect()
{
    if (_panelContainer != null)
        _panelContainer.SetActive(false);
}
```

**변경 6: `ShowPanel()` — 필터 초기화 로직 추가**

```csharp
// BEFORE
public void ShowPanel()
{
    if (_unitSkinManager == null) ...
    RefreshSkillData();
    UpdateUI();
    RefreshAllSkillItemsUI();
    // DOTween 애니메이션...
}
```

```csharp
// AFTER (필터 추가, DOTween은 TO 기존 코드 유지)
public void ShowPanel()
{
    if (_unitSkinManager == null)
        _unitSkinManager = Managers.Instance?.GetManager<UnitSkinManager>();

    RefreshSkillData();
    _selectedUnitTypes.Clear();
    InitializeUnitFilterButtons();
    UpdateSkillSlots();
    CreateSkillItems();
    ApplySkillFilter();

    if (_panelContainer != null)
    {
        _panelContainer.SetActive(true);
        _panelContainer.transform.localScale = Vector3.zero;
        _panelContainer.transform.DOScale(Vector3.one, 0.3f)
            .SetEase(Ease.OutBack).SetUpdate(true);
    }
}
```

**변경 7: `CreateSkillItems()` 메서드 추가 (기존 `UpdateSkillList()` 교체 또는 병존)**

```csharp
// FROM의 CreateSkillItems()를 추가 (단순 재생성 방식, 매번 전체 재빌드)
private void CreateSkillItems()
{
    foreach (var item in _skillItemUIs)
    {
        if (item != null) Destroy(item.gameObject);
    }
    _skillItemUIs.Clear();

    foreach (var skinData in _unlockedSkillSkins)
    {
        var item = Instantiate(_skillItemPrefab, _skillListContainer);
        item.Initialize(skinData, OnSkillItemClicked);
        _skillItemUIs.Add(item);
    }
}
```

**변경 8: 필터 메서드 추가 (신규)**

```csharp
// 신규 추가 — UI Filter 섹션
private void InitializeUnitFilterButtons() { /* FROM 코드 그대로 */ }
private void OnAllFilterButtonClicked() { /* FROM 코드 그대로 */ }
private void OnUnitFilterChanged(EUnitType unitType, bool isOn) { /* FROM 코드 그대로 */ }
private void ApplySkillFilter()
{
    foreach (var item in _skillItemUIs)
    {
        if (item == null) continue;
        bool shouldShow = _selectedUnitTypes.Count == 0
            || _selectedUnitTypes.Contains(item.GetTargetUnitType());
        item.gameObject.SetActive(shouldShow);
    }
}
```

> **⚠️ 확인 결과**: `UnitSkinSkillItemUI.GetTargetUnitType()` — TO에 없음. `ApplySkillFilter()`에서 호출되므로 **sync 전에 `UnitSkinSkillItemUI.cs`에 메서드 추가 필요**.
> `GetSkinId()` (line 125) ✅, `UpdateSkillLevel(int)` (line 111) ✅ 존재 확인 완료.

---

## 5. sync 체크리스트

> **사용법**: sync 작업 중 완료된 항목에 `[x]`를 표시한다.

### 신규 파일 생성

- [ ] `UnitFilterButtonEntry.cs` — FROM 그대로 복사 (`Assets/_Project/1_Scripts/UI/Skin/UnitFilterButtonEntry.cs`)
- [ ] `SkillEquipPopup.cs` — FROM 그대로 복사 (`Assets/_Project/1_Scripts/UI/Skin/SkillEquipPopup.cs`)
  - [ ] FROM 전용 패턴 없음 확인 (변환 불필요)
  - [ ] `UnitFilterButtonEntry` 의존성: 위에서 먼저 생성됨 확인

### 기존 파일 수정

- [ ] `HeroSkinUI.cs`
  - [ ] `_skillEquipPanel` SerializeField 필드 제거
  - [ ] `_limitBreakButtonBox` (GameObject) 필드 추가
  - [ ] `_limitBreakButton` (Button) 필드 추가
  - [ ] `_limitBreakStarSprite` (Sprite) 필드 추가
  - [ ] `RegisterButtonEvents()` — `_limitBreakButton?.onClick.AddListener(ShowRankUpPopup)` 추가
  - [ ] `ShowSkillEquipPanel()` — `_skillEquipPanel.ShowPanel()` → `_uiManager?.Show<SkillEquipPopup>()` 교체, null 가드 조건 수정
  - [ ] `UpdateRankStars()` — LimitBreak 스프라이트 분기 추가 (`isLimitBreak = false`로 비활성화)
  - [ ] `UpdateButtonStates()` — `showRankUp` / `showLimitBreak` 분기, `_limitBreakButtonBox` 제어 추가

- [ ] `LoadoutHeroSkillModule.cs`
  - [ ] `OnEditButtonClicked()` — TODO 주석 해제, `_uiManager.Show<SkillEquipPopup>()` 활성화

- [ ] `UnitSkinSkillEquipPanelUI.cs`
  - [ ] `_unitFilterAllButton` (Button) SerializeField 추가
  - [ ] `_unitFilterButtons` (UnitFilterButtonEntry[]) SerializeField 추가
  - [ ] `_selectedUnitTypes` (HashSet) 필드 추가
  - [ ] `_activeFilterButtons` (List) 필드 추가
  - [ ] `_isAllFilterOn` (bool) 필드 추가
  - [ ] `_isInitialized` (bool) 필드 추가
  - [ ] `Awake()` → `protected override void Awake()` + `base.Awake()` 호출
  - [ ] `Initialize()` — `_isInitialized` guard 추가, 직접 데이터 로드 코드 제거
  - [ ] `UIBase.Opened(object[])` override 추가
  - [ ] `UIBase.HideDirect()` override 추가
  - [ ] `ShowPanel()` — 필터 초기화 로직 추가 (DOTween 코드 유지)
  - [ ] `CreateSkillItems()` 메서드 추가
  - [ ] `ApplySkillFilter()` 메서드 추가
  - [ ] `InitializeUnitFilterButtons()` 메서드 추가
  - [ ] `OnAllFilterButtonClicked()` 메서드 추가
  - [ ] `OnUnitFilterChanged()` 메서드 추가
  - [ ] `UnitSkinSkillItemUI.GetTargetUnitType()` — **TO에 없음, 추가 필요** (섹션 4.3 주의사항 참조)
  - [ ] `SkillItemUI.GetTargetUnitType()` — **TO에 없음, 추가 필요** (SkillEquipPopup.ApplySkillFilter()에서 호출)
  - [ ] `SkinDataSO.NORMAL_MAX_RANK` 상수 — **TO에 없음** → `HeroSkinUI.UpdateRankStars()`에서 LimitBreak 관련 코드 주석 처리로 대응

### sync 후 검증

- [ ] **컴파일 에러 없음** — Unity 에디터에서 0 errors 확인
  - [ ] `SkillEquipPanel` 참조 오류 없음 (HeroSkinUI에서 제거됨)
  - [ ] `UnitFilterButtonEntry` 타입 해석 에러 없음 (신규 생성됨)
  - [ ] `SkillEquipPopup` 타입 해석 에러 없음 (신규 생성됨)
  - [ ] `UnitSkinSkillItemUI.GetTargetUnitType()` 호출 시 컴파일 에러 없음
- [ ] `Cleanup()` / `OnDestroy()` 내 이벤트 구독 해제 확인
  - [ ] `SkillEquipPopup.OnDestroy()` — `OnSkillsEquipped`, `OnSkinRankUp` 해제 확인
  - [ ] `UnitSkinSkillEquipPanelUI.OnDestroy()` — `OnSkillEquipped`, `OnSkillUnequipped`, `OnSkinRankUp` 해제 확인
- [ ] 스킬 장착 팝업 열기/닫기 정상 동작
  - [ ] `HeroSkinUI` → 스킬 장착 버튼 클릭 → `SkillEquipPopup` 열림 확인
  - [ ] `LoadoutHeroSkillModule` → Edit 버튼 클릭 → `SkillEquipPopup` 열림 확인
  - [ ] `UnitSkinSkillEquipPanelUI` → 필터 버튼 표시 및 동작 확인
- [ ] UIManager에 `SkillEquipPopup` 프리팹 등록 확인
- [ ] 프리팹 인스펙터 SerializeField 연결 확인 (섹션 8 참조)

---

## 6. 이 시스템 특유의 주의사항

1. **sync 순서 엄수**:
   - `UnitFilterButtonEntry.cs` 먼저 생성
   - → `SkillEquipPopup.cs` 생성 (UnitFilterButtonEntry 의존성 해소)
   - → `HeroSkinUI.cs` 수정 (SkillEquipPopup 의존성 해소)
   - → `LoadoutHeroSkillModule.cs` 수정 (SkillEquipPopup 의존성 해소)
   - → `UnitSkinSkillEquipPanelUI.cs` 수정 (UnitFilterButtonEntry 의존성 해소)

2. **`SkillEquipPanel.cs` 처리**: TO에 기존 `SkillEquipPanel.cs`(MonoBehaviour)가 있음. `SkillEquipPopup.cs` sync 후 `SkillEquipPanel`에 대한 참조가 `HeroSkinUI`에서 제거되면, `SkillEquipPanel.cs` 파일은 **사용처 없음**이 됨. 최종 프리팹 정리 단계에서 삭제 여부 결정.

3. **LimitBreak 시스템 보류**: FROM `HeroSkinUI`에는 LimitBreak 관련 필드와 분기가 있으나, `isLimitBreak = false`로 강제 비활성화됨. TO에도 동일하게 필드는 추가하되 비활성 상태 유지.
   - ⚠️ **`SkinDataSO.NORMAL_MAX_RANK` — TO에 없음**. `UpdateRankStars()` 내 `isLimitBreak = false` 고정이므로 실제로 접근하지 않지만, 코드상 컴파일 에러가 날 수 있음. 해결책: 해당 줄을 주석 처리하거나 `SkinDataSO`에 상수 추가.
   ```bash
   # 확인 명령 (이미 확인됨: 없음)
   grep -rn "NORMAL_MAX_RANK" /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts --include="*.cs"
   # 가장 안전한 처리: UpdateRankStars()에서 isLimitBreak 관련 코드 전체 주석 처리
   ```

4. **`UnitSkinSkillEquipPanelUI` DOTween 유지**: FROM의 `UnitSkinSkillEquipPanelUI`는 DOTween 없이 단순 `SetActive`를 사용하지만, TO의 기존 버전은 DOTween 애니메이션이 있음. sync 시 TO의 DOTween 코드를 유지하고 필터 기능만 추가함.

5. **`_isInitialized` guard 충돌 주의**: TO `UnitSkinSkillEquipPanelUI`의 `Initialize()`는 현재 guard 없이 `Start()`에서 직접 호출됨. FROM 패턴 추가 시 `Start()`에서 기존 초기화 로직(`RefreshSkillData`, `UpdateUI`)을 제거하고 `_isInitialized` guard만 남겨야 중복 초기화를 방지함.

6. **`CreateSkillItems()` vs `UpdateSkillList()` 공존**: TO의 `UpdateSkillList()`는 개수 동일 시 refresh만, 다를 때 재빌드하는 최적화 로직. FROM의 `CreateSkillItems()`는 매번 전체 재빌드. `ShowPanel()`에서는 `CreateSkillItems()` 사용, 기존 `UpdateSkillList()`는 내부 최적화용으로 병존 가능.

7. **`EUnitType.Bunker` 필터 제외**: FROM `SkillEquipPopup.InitializeUnitFilterButtons()`에서 `EUnitType.None`과 `EUnitType.Bunker`를 필터 버튼에서 제외함. `EUnitType.Bunker`가 TO에 존재함 확인 완료 ✅.

---

## 7. diff 비교 전략

> 범용 원칙은 `WD_SYNC_GUIDE.md` 섹션 5 참조. 이 섹션에는 SkillEquipPopup 시스템에 특화된 diff 명령어만 기록한다.

### 7.1 신규 생성 파일 diff 확인 명령어

```bash
# UnitFilterButtonEntry.cs — 변환 불필요, diff 0줄이어야 함
diff /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/UnitFilterButtonEntry.cs \
     /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts/UI/Skin/UnitFilterButtonEntry.cs

# SkillEquipPopup.cs — 변환 불필요, diff 0줄이어야 함
diff /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/SkillEquipPopup.cs \
     /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts/UI/Skin/SkillEquipPopup.cs
```

### 7.2 수정 파일 diff 확인 명령어

```bash
# HeroSkinUI.cs — FROM vs TO 수정본 비교
diff /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/Skin/HeroSkinUI.cs \
     /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts/UI/Skin/HeroSkinUI.cs

# UnitSkinSkillEquipPanelUI.cs — 필터 기능 추가 확인
diff /Volumes/solidigm/repo/BunkerDefense/Assets/_Project/1_Scripts/UI/UnitSkin/UnitSkinSkillEquipPanelUI.cs \
     /Volumes/solidigm/repo/WiggleDefender/Assets/_Project/1_Scripts/UI/UnitSkin/UnitSkinSkillEquipPanelUI.cs
```

### 7.3 예상 diff 노이즈 (변환 규칙 적용 결과)

| 파일 | 변경 유형 | 예상 diff |
|------|----------|----------|
| `UnitFilterButtonEntry.cs` (신규) | DIRECT 복사 | 0줄 (완전 일치) |
| `SkillEquipPopup.cs` (신규) | DIRECT 복사 | 0줄 (완전 일치) |
| `HeroSkinUI.cs` (수정) | 필드 교체 + LimitBreak 추가 | ~30줄 변경 |
| `LoadoutHeroSkillModule.cs` (수정) | 주석 해제 | 2줄 변경 |
| `UnitSkinSkillEquipPanelUI.cs` (수정) | 필터 기능 전체 추가 | ~80줄 추가 |

---

## 8. 프리팹 패키징 목록

> **작성 시점**: Phase 4(sync 실행) 완료 후 컴파일 에러 0개 확인 시점에 작성한다.

### 8.1 FROM에서 패키지화할 프리팹 목록

- [ ] `SkillEquipPopup.prefab` — UIBase 상속 팝업. UIManager에 등록 필요.

### 8.2 프리팹별 SerializeField 연결 목록

| 프리팹 | 필드명 | 타입 | 배열 크기 | 주의사항 |
|--------|--------|------|----------|---------|
| `SkillEquipPopup` | `_panelContainer` | `GameObject` | — | |
| `SkillEquipPopup` | `_closeButton` | `Button` | — | |
| `SkillEquipPopup` | `_closeButton2` | `Button` | — | |
| `SkillEquipPopup` | `_skillSlots` | `SkillSlotUI[]` | 3 | ⚠️ 배열 3개 |
| `SkillEquipPopup` | `_skillListContainer` | `Transform` | — | |
| `SkillEquipPopup` | `_skillItemPrefab` | `SkillItemUI` | — | |
| `SkillEquipPopup` | `_skillListScrollRect` | `ScrollRect` | — | |
| `SkillEquipPopup` | `_unitFilterAllButton` | `Button` | — | |
| `SkillEquipPopup` | `_unitFilterButtons` | `UnitFilterButtonEntry[]` | 가변 | ⚠️ struct 배열: unitType + button 연결 필요 |
| `SkillEquipPopup` | `_emptySlotSprite` | `Sprite` | — | |

### 8.3 Show<T> 외부 UI 참조 확인

| 호출 위치 | 대상 클래스 | TO 존재 여부 | 처리 |
|----------|------------|------------|------|
| `HeroSkinUI.ShowSkillEquipPanel()` | `SkillEquipPopup` | ⚠️ 이번 sync 대상 | UIManager 등록 필요 |
| `LoadoutHeroSkillModule.OnEditButtonClicked()` | `SkillEquipPopup` | ⚠️ 이번 sync 대상 | UIManager 등록 필요 |
| `SkillEquipPopup.HidePanel()` | `SkillEquipPopup` (자기 자신) | ⚠️ 이번 sync 대상 | 신규 생성으로 해소 |

### 8.4 임포트 후 UIManager 등록 필요 목록

- [ ] `SkillEquipPopup` — `Assets/_Project/3_Prefabs/UI/Skin/SkillEquipPopup.prefab`
