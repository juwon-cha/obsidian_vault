# SkillEquipPopup 기존 프리팹 패치 리포트

## 패치된 프리팹
없음

## 스킵된 프리팹
| 프리팹 | 이유 |
|--------|------|
| SkillEquipPopup.prefab | 스크립트 GUID 차이는 Phase 5-B sync 시 정상 리타겟팅 완료 상태 |
| BunkerSkinSkillEquipPanelUI.prefab | m_characterHorizontalScale 3개 차이는 Unity 버전 간 TMP 직렬화 포맷 차이 (기능 영향 없음) |
| SkillEquipPanel.prefab | FROM == TO 완전 동일 |
| UnitSkinSkillEquipPanelUI.prefab | FROM == TO 완전 동일 |
| SkillItemUI.prefab | 🔵 TO가 FROM보다 최신 (EquipText 노드 추가됨) — TO 유지 |
| UnitSkinSkillItemUI.prefab | 🔵 TO가 FROM보다 최신 — TO 유지 |
| BunkerSkinSkillItemUI.prefab | 🔵 TO가 FROM보다 최신 — TO 유지 |

## ⚠️ 수동 확인 필요
- Unity 에디터에서 SkillEquipPopup 프리팹 열어서 UIManager에 등록 필요
- UnitSkinSkillEquipPanelUI 프리팹의 _unitFilterButtons[] SerializeField 배열 연결 필요 (13개 Toggle - UnitFilter)
- SkillEquipPopup 프리팹의 _unitFilterButtons[] SerializeField 배열 연결 필요
- SkillEquipPanel.prefab의 filterBox 노드 활용 여부 검토 (SkillEquipPanel.cs에 해당 SerializeField 없음 — deprecated 여부 확인)
