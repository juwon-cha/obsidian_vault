# Preset 시스템 프리팹 sync 목록

## 1. sync할 프리팹 목록 (의존성 순)

> TO에 이미 존재하는 항목은 ~~취소선~~ 표시.

- [ ] `LoadoutSlotButton.prefab` — `BunkerDefense/Assets/_Project/3_Prefabs/UI/Loadout/LoadoutSlotButton.prefab`
  - 의존 스크립트: `LoadoutSlotButton` (GUID 재매핑 필요)
- [ ] `LoadoutPopupUI.prefab` — `BunkerDefense/Assets/Resources/UI/LoadoutPopupUI.prefab`
  - 의존 스크립트: `LoadoutPopupUI`, `LoadoutHeroSkillModule`, `LoadoutMinionModule`, `BunkerSkinSkillSlotUI`, `LoadoutCharacterModule`, `LoadoutUnitSkillModule`, `LoadoutBunkerSkinModule`, `LoadoutSlotButton`, `UnitSkinSkillSlotUI` (대부분 GUID 재매핑 필요)
  - TO 대응 경로: `WiggleDefender/Assets/Resources/UI/LoadoutPopupUI.prefab` (미존재)
- [ ] `LoadoutRenamePopupUI.prefab` — `BunkerDefense/Assets/Resources/UI/LoadoutRenamePopupUI.prefab`
  - 의존 스크립트: `LoadoutRenamePopupUI` (GUID 재매핑 필요)
  - TO 대응 경로: `WiggleDefender/Assets/Resources/UI/LoadoutRenamePopupUI.prefab` (미존재)
- ~~`EquipmentSlot.prefab`~~ — TO에 이미 존재: `WiggleDefender/Assets/_Project/3_Prefabs/UI/Equipment/EquipmentSlot.prefab`

## 2. 프리팹별 SerializeField 연결 목록

### LoadoutPopupUI.prefab

| 필드명 | 타입 | 비고 |
|---|---|---|
| `_closeButton` | `Button` | Header |
| `_slotNumberImage` | `Image` | Header |
| `_loadoutNameText` | `TextMeshProUGUI` | Header |
| `_dropdownButton` | `Button` | Header |
| `_dropdownMenu` | `GameObject` | Header |
| `_dropdownCloseBackground` | `Button` | Dropdown |
| `_dropdownContent` | `RectTransform` | Dropdown |
| `_dropdownAnimDuration` | `float` | Dropdown (기본값 0.2f) |
| `_renameButton` | `Button` | Dropdown Buttons |
| `_unequipAllButton` | `Button` | Dropdown Buttons |
| `_copyButton` | `Button` | Dropdown Buttons |
| `_pasteButton` | `Button` | Dropdown Buttons |
| `_pasteSlotNumberImage` | `Image` | Dropdown Buttons |
| `_pasteButtonText` | `TextMeshProUGUI` | Dropdown Buttons |
| `_moduleScrollRect` | `ScrollRect` | Modules |
| `_heroSkillModule` | `LoadoutHeroSkillModule` | Modules |
| `_unitSkillModule` | `LoadoutUnitSkillModule` | Modules |
| `_bunkerSkinModule` | `LoadoutBunkerSkinModule` | Modules |
| `_minionModule` | `LoadoutMinionModule` | Modules |
| `_characterModule` | `LoadoutCharacterModule` | Modules |
| `_slotButtons` | `LoadoutSlotButton[MaxLoadoutSlots]` | 배열 (PresetTypes.MAX_LOADOUT_SLOTS 크기) |
| `_slotNumberSprites` | `List<Sprite>` | 슬롯 번호 스프라이트 |
| `_slotNumberOnSprites` | `List<Sprite>` | 슬롯 번호 On 스프라이트 |
| `_slotNumberOffSprites` | `List<Sprite>` | 슬롯 번호 Off 스프라이트 |

### LoadoutSlotButton.prefab

| 필드명 | 타입 | 비고 |
|---|---|---|
| `_button` | `Button` | |
| `_numberImage` | `Image` | |
| `_presetNameText` | `TextMeshProUGUI` | |
| `_selectedIndicator` | `GameObject` | |
| `_unlockedOverlay` | `GameObject` | |
| `_lockedOverlay` | `GameObject` | |
| `_normalColor` | `Color` | 기본값: white |
| `_selectedColor` | `Color` | 기본값: (1, 0.8, 0.2, 1) |

### LoadoutRenamePopupUI.prefab

| 필드명 | 타입 | 비고 |
|---|---|---|
| `_popupContainer` | `GameObject` | |
| `_backgroundCanvasGroup` | `CanvasGroup` | |
| `_backgroundButton` | `Button` | |
| `_nameInputField` | `TMP_InputField` | maxLength=20 |
| `_placeholderText` | `TextMeshProUGUI` | |
| `_guideText` | `TextMeshProUGUI` | |
| `_characterCountText` | `TextMeshProUGUI` | |
| `_confirmButton` | `Button` | |
| `_cancelButton` | `Button` | |
| `_confirmButtonText` | `TextMeshProUGUI` | |
| `_animationDuration` | `float` | 기본값: 0.3f |

### 서브 모듈 SerializeField (모두 LoadoutModuleBase 상속)

공통 (LoadoutModuleBase):
| 필드명 | 타입 |
|---|---|
| `_moduleRoot` | `GameObject` |
| `_titleText` | `TextMeshProUGUI` |
| `_countText` | `TextMeshProUGUI` |
| `_editButton` | `Button` |
| `_shortcutButton` | `Button` |

LoadoutHeroSkillModule 추가:
| `_skillSlots` | `SkillSlotUI[3]` |

LoadoutUnitSkillModule 추가:
| `_skillSlots` | `UnitSkinSkillSlotUI[3]` |

LoadoutBunkerSkinModule 추가:
| `_skillSlots` | `BunkerSkinSkillSlotUI[3]` |

LoadoutMinionModule 추가:
| `_minionIconSlots` | `List<Image>` |
| `_minionNameTexts` | `List<TextMeshProUGUI>` |
| `_emptySlotSprite` | `Sprite` |

LoadoutCharacterModule 추가:
| `_equipmentSlots` | `EquipmentSlot[6]` |
| `_unequipChipsButton` | `Button` |

## 3. Show<T> 외부 UI 참조 확인

| 호출 위치 | 대상 클래스 | TO 스크립트 존재 | TO 프리팹 존재 | 처리 |
|---|---|---|---|---|
| `LoadoutPopupUI.ShowRenamePopup()` | `LoadoutRenamePopupUI` | O | X | **sync 필요** |
| `LoadoutPopupUI.BuySlotAsync()` | `GemShopPopup` | O | O | 기존 프리팹 사용 |
| `LoadoutBunkerSkinModule` | `BunkerSkinSkillEquipPanelUI` | O | O | 기존 프리팹 사용 |
| `LoadoutCharacterModule` | `EquipmentPopup` | O | O | 기존 프리팹 사용 |
| `LoadoutMinionModule` | `MinionMainUI` | O | O | 기존 프리팹 사용 |
| `LoadoutUnitSkillModule` | `UnitSkinSkillEquipPanelUI` | O | O | 기존 프리팹 사용 |

## 4. 임포트 후 UIManager 등록 필요 목록

UIManager는 `Resources/UI/{ClassName}.prefab` 경로 규칙으로 자동 로드 (`LoadResource<GameObject>`)하므로, 아래 경로에 프리팹을 배치해야 한다.

- [ ] `LoadoutPopupUI` — `WiggleDefender/Assets/Resources/UI/LoadoutPopupUI.prefab`
- [ ] `LoadoutRenamePopupUI` — `WiggleDefender/Assets/Resources/UI/LoadoutRenamePopupUI.prefab`

`LoadoutSlotButton`은 UIBase가 아닌 MonoBehaviour이므로 UIManager 등록 불필요. `LoadoutPopupUI.prefab` 내부에 인라인으로 포함된다.

## 5. sync 전 확인 사항

### FROM 프리팹 경로 목록

| 프리팹 | FROM 경로 |
|---|---|
| `LoadoutPopupUI.prefab` | `BunkerDefense/Assets/Resources/UI/LoadoutPopupUI.prefab` |
| `LoadoutRenamePopupUI.prefab` | `BunkerDefense/Assets/Resources/UI/LoadoutRenamePopupUI.prefab` |
| `LoadoutSlotButton.prefab` | `BunkerDefense/Assets/_Project/3_Prefabs/UI/Loadout/LoadoutSlotButton.prefab` |

### 스크립트 GUID 재매핑 필요 목록

프리팹 파일을 TO에 복사한 뒤, 아래 GUID를 텍스트 치환해야 프리팹이 TO 스크립트를 올바르게 참조한다.

| 클래스명 | FROM GUID | TO GUID | 일치 여부 |
|---|---|---|---|
| `LoadoutHeroSkillModule` | `2a6711479482046468bffbf0e5f06450` | `4382cbcde70af4a0fbc0bc46006cb3b9` | **불일치 — 재매핑 필요** |
| `LoadoutMinionModule` | `d11ae06d5e7d34360868b587c1507b37` | `b6798debfea464d169da1fcbb7ae5ee7` | **불일치 — 재매핑 필요** |
| `BunkerSkinSkillSlotUI` | `dcc4fec792030429eabef3317375547a` | `dcc4fec792030429eabef3317375547a` | 일치 (재매핑 불필요) |
| `LoadoutCharacterModule` | `3b467b9692753446ea0fb77f3be05bf4` | `55ba98fb48d53466ebf2550477ad562a` | **불일치 — 재매핑 필요** |
| `LoadoutUnitSkillModule` | `edcd54d44351f4882a24232a6680ed3d` | `9543728d875464d6a93c15fb73a13796` | **불일치 — 재매핑 필요** |
| `LoadoutBunkerSkinModule` | `28833b336b2994ca9a1393f90ae982d2` | `634e6f8a235f343938f7b0afae1e6998` | **불일치 — 재매핑 필요** |
| `LoadoutPopupUI` | `f383de7c21e8c4f1e867fb06dccf8c6c` | `467cf61f685b84505ab84a2f29d5a012` | **불일치 — 재매핑 필요** |
| `LoadoutSlotButton` | `fed372bb3ca81497e9884c0f7ef65ed3` | `bc2931beb0fce40c39d339a5e7f6dfa2` | **불일치 — 재매핑 필요** |
| `UnitSkinSkillSlotUI` | `063735d525d3b4d13924421157ad8ac5` | `063735d525d3b4d13924421157ad8ac5` | 일치 (재매핑 불필요) |
| `LoadoutRenamePopupUI` | `caea152036c05442fb29f2c3a7602310` | `092a4e0b8aeae45e98e63d3e1209a608` | **불일치 — 재매핑 필요** |

> **주의**: `SkillSlotUI`와 `EquipmentSlot`은 `LoadoutPopupUI.prefab` 내에서 인라인 오브젝트로 존재하지 않고 모듈 내부 배열(`_skillSlots[]`, `_equipmentSlots[]`)에 연결된 별도 GameObject다. `EquipmentSlot.prefab`은 TO에 이미 존재하므로 해당 GUID도 확인 후 재매핑 필요.

### sync 순서 (의존성 낮은 것 먼저)

1. `LoadoutSlotButton.prefab` (다른 프리팹이 의존)
2. `LoadoutRenamePopupUI.prefab` (독립 팝업)
3. `LoadoutPopupUI.prefab` (위 두 개 + 기존 서브모듈 참조)
