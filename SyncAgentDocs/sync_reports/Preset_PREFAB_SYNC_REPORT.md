# Preset 프리팹 sync 리포트

## 복사된 프리팹

| 프리팹 | FROM 경로 | TO 경로 |
|--------|-----------|---------|
| LoadoutSlotButton.prefab | `BunkerDefense/Assets/_Project/3_Prefabs/UI/Loadout/LoadoutSlotButton.prefab` | `WiggleDefender/Assets/_Project/3_Prefabs/UI/Loadout/LoadoutSlotButton.prefab` |
| LoadoutRenamePopupUI.prefab | `BunkerDefense/Assets/Resources/UI/LoadoutRenamePopupUI.prefab` | `WiggleDefender/Assets/Resources/UI/LoadoutRenamePopupUI.prefab` |
| LoadoutPopupUI.prefab | `BunkerDefense/Assets/Resources/UI/LoadoutPopupUI.prefab` | `WiggleDefender/Assets/Resources/UI/LoadoutPopupUI.prefab` |

---

## GUID 교체 목록 (TO 기존 스크립트 사용)

| 클래스명 | FROM GUID | TO GUID |
|----------|-----------|---------|
| LoadoutSlotButton.cs | `fed372bb3ca81497e9884c0f7ef65ed3` | `bc2931beb0fce40c39d339a5e7f6dfa2` |
| LoadoutRenamePopupUI.cs | `caea152036c05442fb29f2c3a7602310` | `092a4e0b8aeae45e98e63d3e1209a608` |
| LoadoutPopupUI.cs | `f383de7c21e8c4f1e867fb06dccf8c6c` | `467cf61f685b84505ab84a2f29d5a012` |
| LoadoutBunkerSkinModule.cs | `28833b336b2994ca9a1393f90ae982d2` | `634e6f8a235f343938f7b0afae1e6998` |
| LoadoutHeroSkillModule.cs | `2a6711479482046468bffbf0e5f06450` | `4382cbcde70af4a0fbc0bc46006cb3b9` |
| LoadoutCharacterModule.cs | `3b467b9692753446ea0fb77f3be05bf4` | `55ba98fb48d53466ebf2550477ad562a` |
| LoadoutMinionModule.cs | `d11ae06d5e7d34360868b587c1507b37` | `b6798debfea464d169da1fcbb7ae5ee7` |
| LoadoutUnitSkillModule.cs | `edcd54d44351f4882a24232a6680ed3d` | `9543728d875464d6a93c15fb73a13796` |

**스크립트 GUID 동일 (FROM = TO, 교체 불필요):**
- BaseButton.cs: `4855175192ee1e5449464a10397c6980`
- UnitSkinSkillSlotUI.cs: `063735d525d3b4d13924421157ad8ac5`
- BunkerSkinSkillSlotUI.cs: `dcc4fec792030429eabef3317375547a`
- EquipmentSlot.cs: `984f71183705d8e4ea7bd384a3e1b21d`
- SkillSlotUI.cs: `bcdb8daaae5240ad888229db168552ce`
- LocalizeStringEvent.cs: `56eb0353ae6e5124bb35b17aff880f16`
- TMP_InputField.cs: `2da0c512f12947e489f739169773d7ca`
- LayoutElement.cs: `306cc8c2b49d7114eaa3623786fc2126`
- RectMask2D.cs: `3312d7739989d2b4e91e6319e9a96d76`
- ScrollRect.cs: `1aa08ab6e0800fa44ae55d278d1423e3`
- HorizontalLayoutGroup.cs: `30649d3a9faa99c48a7b1166b86bf2a0`
- Mask.cs: `31a19414c41e5ae4aae2af33fee712f6`
- ContentSizeFitter.cs: `3245ec927659c4140ac4f8d17403cc18`
- VerticalLayoutGroup.cs: `59f8146938fff824cb5fd77236b75775`
- GridLayoutGroup.cs: `8a8695521f0d02e499659fee002a26c2`

---

## GUID 교체 목록 (TO 기존 에셋 사용)

| 에셋명 | FROM GUID | TO GUID |
|--------|-----------|---------|
| UI_dailly_bg.png | `9e1f9125e891aa94da25e95652e60f9c` | `97a1039ed1da2d0469ddb540b17b93e5` |
| Aggro M SDF.asset (폰트) | `26e405e1c9110c94f9d6368f98c32a34` | `26e405e1c9110c94f9d6368f98c32a34` (동일) |
| Aggro M SDF - Outline.mat | `4c3a72a85454bbf4cb226a04cb60f14a` | `4c3a72a85454bbf4cb226a04cb60f14a` (동일) |
| UI_shop_btn_gacha2.png | `023281c49fe49409e8f310f12bc47a68` | `023281c49fe49409e8f310f12bc47a68` (동일) |
| UI_setting_btn.png | `077dd4a297f72bb40a73937c735d9c76` | `077dd4a297f72bb40a73937c735d9c76` (동일) |
| UI_shop_btn_gacha1.png | `0ed47bba59cab4cf687811c31affdf25` | `0ed47bba59cab4cf687811c31affdf25` (동일) |
| UI_character_equipment_frame.png | `4af2994f90a611e4dae7667280f7a43c` | `4af2994f90a611e4dae7667280f7a43c` (동일) |
| UI_lobby_stage info_frame.png | `94ea3fa94d53ec144a3e754bd409ed28` | `94ea3fa94d53ec144a3e754bd409ed28` (동일) |
| UI_lobby_box_reword_frame2.png | `a7bd477f14041488c814481ea82b4eee` | `a7bd477f14041488c814481ea82b4eee` (동일) |
| UI_lobby_box_reword_frame1.png | `aec7abd92808f4b5b96e001ffcfb10e4` | `aec7abd92808f4b5b96e001ffcfb10e4` (동일) |
| ui_wipe out_btn.png | `dbe3ba6e79e8d4984b4475975a3165c5` | `dbe3ba6e79e8d4984b4475975a3165c5` (동일) |
| UI_card_info_bg.png | `e50ab8f0ea209f94eba49b23616da4c8` | `e50ab8f0ea209f94eba49b23616da4c8` (동일) |
| UI_base_monster book_bg1.png | `3c953de09e3d703439820f88b4ff0ef7` | `3c953de09e3d703439820f88b4ff0ef7` (동일) |
| UI_load out_skill_frame.png | `c22fb80e6a478408ba88dbb731f5c594` | `c22fb80e6a478408ba88dbb731f5c594` (동일) |
| TopBox.prefab | `0f33a15fc7b1e474580f3385b7d7acf7` | `0f33a15fc7b1e474580f3385b7d7acf7` (동일) |
| Button - BackgroundClose.prefab | `069400c98789ca641b0df3c8d6163d51` | `069400c98789ca641b0df3c8d6163d51` (동일) |
| SkillSlot.prefab | `769a6d23c1b3e8e4b9a54925ea6811b8` | `769a6d23c1b3e8e4b9a54925ea6811b8` (동일) |
| EquipmentSlot.prefab | `3ac929fd14f0299479c3fd12cd6d3d21` | `3ac929fd14f0299479c3fd12cd6d3d21` (동일) |
| BottomBox.prefab | `31b247fe6dafd8241afecf36b387e868` | `31b247fe6dafd8241afecf36b387e868` (동일) |

---

## 신규 복사된 에셋 (FROM에만 있던 것)

모두 `Assets/_Project/6_Textures/Loadout/` 폴더에 복사됨:

| 에셋명 | TO 경로 |
|--------|---------|
| UI_load out_btn_on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_btn_on.png` |
| UI_load out_btn_off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_btn_off.png` |
| UI_load out_icon_1off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_1off.png` |
| UI_load out_frame2.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_frame2.png` |
| UI_load out_top frame.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_top frame.png` |
| UI_load out_top icon.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_top icon.png` |
| UI_load out_title.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_title.png` |
| UI_load out_bg.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_bg.png` |
| UI_load out_minion_frame.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_minion_frame.png` |
| UI_load out_frame_title.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_frame_title.png` |
| UI_load out_frame1.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_frame1.png` |
| UI_load out_icon_5on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_5on.png` |
| UI_load out_icon_2off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_2off.png` |
| UI_load out_skill_page on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_skill_page on.png` |
| UI_load out_icon_6on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_6on.png` |
| UI_load out_icon_5off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_5off.png` |
| UI_load out_icon_3on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_3on.png` |
| UI_load out_icon_3off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_3off.png` |
| UI_load out_icon_4off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_4off.png` |
| UI_load out_skill_page off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_skill_page off.png` |
| UI_load out_icon_6off.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_6off.png` |
| UI_load out_icon_4on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_4on.png` |
| UI_load out_icon_2on.png | `WiggleDefender/Assets/_Project/6_Textures/Loadout/UI_load out_icon_2on.png` |

---

## 신규 생성된 폴더

| 폴더 | 메모 |
|------|------|
| `WiggleDefender/Assets/_Project/3_Prefabs/UI/Loadout/` | LoadoutSlotButton.prefab 수납용으로 신규 생성 |

---

## 주의사항

### UIManager 등록 필요
LoadoutRenamePopupUI.prefab과 LoadoutPopupUI.prefab은 `Resources/UI/` 에 있으므로 `uiManager.Show<LoadoutRenamePopupUI>()` / `uiManager.Show<LoadoutPopupUI>()` 호출 시 UIManager에 등록되어 있어야 합니다. 등록 방식을 TO 프로젝트 패턴에 맞게 확인하세요.

### SerializeField 배열 확인
LoadoutPopupUI에는 다음 모듈들이 SerializeField로 연결됩니다:
- `LoadoutCharacterModule`
- `LoadoutHeroSkillModule`
- `LoadoutUnitSkillModule`
- `LoadoutMinionModule`
- `LoadoutBunkerSkinModule`
- `LoadoutSlotButton` (슬롯 버튼 배열)

Unity 에디터에서 Inspector를 열어 직렬화 연결이 정상인지 확인하세요.

### 이미지 임포트 설정 확인
신규 복사된 23개 PNG 파일은 FROM의 .meta(TextureImporter 설정)를 그대로 복사했습니다. Sprite Mode, Pixels Per Unit 등 임포트 설정이 TO 프로젝트 표준과 다를 수 있으니 확인하세요.

### Localization 확인
LoadoutRenamePopupUI.prefab에는 `LocalizeStringEvent` 컴포넌트가 포함되어 있습니다. TO 프로젝트의 Localization Table에 해당 키가 등록되어 있는지 확인하세요.
