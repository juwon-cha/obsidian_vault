# SkillEquipPopup - Phase 5-B: 프리팹 sync 결과 리포트

생성일: 2026-04-07  
FROM: `/Volumes/solidigm/repo/BunkerDefense`  
TO: `/Volumes/solidigm/repo/WiggleDefender`

---

## 1. 처리 결과 요약

| 구분 | 개수 | 파일명 |
|---|---|---|
| 신규 복사 | 2개 | SkillEquipPopup.prefab, SkillEquipPanel - Advance.prefab |
| 업데이트 | 2개 | UnitSkinSkillEquipPanelUI.prefab, SkillEquipPanel.prefab |
| 스킵 | 5개 | BunkerSkinSkillEquipPanelUI.prefab, SkillSlot.prefab, Toggle - UnitFilter.prefab, Button - BackgroundClose.prefab, TopBox.prefab |
| 수동 판단 (TO 유지) | 3개 | SkillItemUI.prefab, UnitSkinSkillItemUI.prefab, BunkerSkinSkillItemUI.prefab |
| **합계** | **12개** | |

---

## 2. GUID 교체 내역

| FROM GUID | TO GUID | 파일명 | 적용 프리팹 |
|---|---|---|---|
| d45575af54d034e2db98b2c9e967a800 | ba691d32b5c244626a9bc1b1dbb7082d | SkillEquipPopup.cs | SkillEquipPopup.prefab |

**GUID 교체 총계: 1건 (스크립트 1건)**

---

## 3. GUID 동일 확인 (교체 불필요)

다음 GUID들은 FROM/TO에서 동일하여 교체 없이 그대로 사용됨:

| GUID | 파일명 | 타입 |
|---|---|---|
| bcdb8daaae5240ad888229db168552ce | SkillSlotUI.cs | 스크립트 |
| c4be921faa8b86c4495507c5e0d26efa | UnitFilterButton.cs | 스크립트 |
| 63bd0b48f0618314ca7f7d9a5d139081 | SkillEquipPanel.cs | 스크립트 |
| 063735d525d3b4d13924421157ad8ac5 | UnitSkinSkillSlotUI.cs | 스크립트 |
| b016d214bc78b47e3a899cf527eb2297 | UnitSkinSkillEquipPanelUI.cs | 스크립트 |
| e20f7fac042af3d4f9fce7278bb29264 | PopupAnimationComponent.cs | 스크립트 |
| 769a6d23c1b3e8e4b9a54925ea6811b8 | SkillSlot.prefab | 프리팹 |
| 613df23e8c585a6468487f568a43f81d | Toggle - UnitFilter.prefab | 프리팹 |
| 069400c98789ca641b0df3c8d6163d51 | Button - BackgroundClose.prefab | 프리팹 |
| 5745039d37b40c54893362d6371a80c2 | SkillItemUI.prefab | 프리팹 |
| 77941cb3f6fc642249e7c5dd82eda0b7 | UnitSkinSkillItemUI.prefab | 프리팹 |
| 26e405e1c9110c94f9d6368f98c32a34 | Aggro M SDF.asset | 폰트 |
| d611576b0b01f2c4f815a0bc27dec8ef | UI_dailly_title.png | 텍스처 |
| 9e1f9125e891aa94da25e95652e60f9c | UI_dailly_bg.png | 텍스처 |
| 5190530a481a24144932049b7b7e6bc8 | UI_dailly_bg1.png | 텍스처 |
| 6b2dc60ca661e254fa375832256505b6 | UI_base_monster book_btn close.png | 텍스처 |
| 4af2994f90a611e4dae7667280f7a43c | UI_character_equipment_frame.png | 텍스처 |
| a28673a881b634005acdaa759e6532ff | UI_load out_skill_page on.png | 텍스처 |
| eb2c3ac3d0bcb4a8a9a3c503f4ee0e02 | UI_load out_skill_page off.png | 텍스처 |
| 1fb5f854de485c94ba5c4f24307367e4 | UI_character_pofile_frame.png | 텍스처 |
| fe87c0e1cc204ed48ad3b37840f39efc | Image.cs (UGUI) | 패키지 |
| 31a19414c41e5ae4aae2af33fee712f6 | Mask.cs (UGUI) | 패키지 |
| f4688fdb7df04437aeb418b961361dc5 | TextMeshProUGUI.cs (TMP) | 패키지 |
| 56eb0353ae6e5124bb35b17aff880f16 | LocalizeStringEvent.cs | 패키지 |
| 59f8146938fff824cb5fd77236b75775 | VerticalLayoutGroup.cs | 패키지 |
| 3245ec927659c4140ac4f8d17403cc18 | ContentSizeFitter.cs | 패키지 |
| 30649d3a9faa99c48a7b1166b86bf2a0 | HorizontalLayoutGroup.cs | 패키지 |
| 1aa08ab6e0800fa44ae55d278d1423e3 | ScrollRect.cs | 패키지 |
| 4e29b1a8efbd4b44bb3f3716e73f07ff | Button.cs (UGUI) | 패키지 |
| 8a8695521f0d02e499659fee002a26c2 | GridLayoutGroup.cs | 패키지 |

---

## 4. 신규 에셋 복사

TO 프로젝트에 없어서 FROM에서 복사한 파일:

| 파일명 | FROM 경로 | TO 경로 |
|---|---|---|
| UI_skill_frame1.png | `BunkerDefense/.../Skin/Hero/` | `WiggleDefender/.../Skin/Hero/` |
| UI_skill_frame2.png | `BunkerDefense/.../Skin/Hero/` | `WiggleDefender/.../Skin/Hero/` |
| UI_skill_frame3.png | `BunkerDefense/.../Skin/Hero/` | `WiggleDefender/.../Skin/Hero/` |
| UI_skill_all_btn.png | `BunkerDefense/.../Skin/Hero/` | `WiggleDefender/.../Skin/Hero/` |

**신규 에셋 복사: 4개 (이미지 + .meta 각 4쌍 = 8개 파일)**

---

## 5. 사후 검증 결과

검증 방법: sync된 4개 프리팹의 모든 GUID(35개)를 TO Assets 및 PackageCache에서 grep으로 확인

```
✅ All GUIDs resolved! (35/35)
미해결 GUID: 0건
```

---

## 6. 후속 작업 (수동 필요)

### UIManager 등록 필요
`SkillEquipPopup.prefab`은 UIBase 상속 클래스이므로 UIManager에 등록이 필요합니다.  
Resources/UI 경로이므로 `uiManager.Show<SkillEquipPopup>()` 로 호출 가능합니다.

### SkillEquipPanel.prefab filterBox 검토
FROM의 SkillEquipPanel.prefab에는 `filterBox` 노드가 추가됐으나 `SkillEquipPanel.cs`에 해당 SerializeField가 없습니다.  
`SkillEquipPopup` (UIBase 방식)으로 전환 시 `SkillEquipPanel`이 deprecated될 수 있습니다. 팀 확인 권장.

### SkillEquipPanel - Advance.prefab 역할 확인
`SkillEquipPanel`과 동일한 클래스(`SkillEquipPanel : MonoBehaviour`)를 사용하며 `LocalizeStringEvent` 컴포넌트가 추가됩니다.  
`SkillEquipPopup`(UIBase 방식)과의 역할 분리를 팀에 확인 권장.

---

## 7. sync된 파일 목록

| 파일 | TO 경로 |
|---|---|
| SkillEquipPopup.prefab | `WiggleDefender/Assets/Resources/UI/SkillEquipPopup.prefab` |
| SkillEquipPopup.prefab.meta | `WiggleDefender/Assets/Resources/UI/SkillEquipPopup.prefab.meta` |
| SkillEquipPanel - Advance.prefab | `WiggleDefender/Assets/Resources/UI/SkillEquipPanel - Advance.prefab` |
| SkillEquipPanel - Advance.prefab.meta | `WiggleDefender/Assets/Resources/UI/SkillEquipPanel - Advance.prefab.meta` |
| UnitSkinSkillEquipPanelUI.prefab | `WiggleDefender/Assets/Resources/UI/UnitSkinSkillEquipPanelUI.prefab` |
| SkillEquipPanel.prefab | `WiggleDefender/Assets/Resources/UI/SkillEquipPanel.prefab` |
| UI_skill_frame1.png + .meta | `WiggleDefender/Assets/_Project/6_Textures/OutGame/Skin/Hero/` |
| UI_skill_frame2.png + .meta | `WiggleDefender/Assets/_Project/6_Textures/OutGame/Skin/Hero/` |
| UI_skill_frame3.png + .meta | `WiggleDefender/Assets/_Project/6_Textures/OutGame/Skin/Hero/` |
| UI_skill_all_btn.png + .meta | `WiggleDefender/Assets/_Project/6_Textures/OutGame/Skin/Hero/` |
