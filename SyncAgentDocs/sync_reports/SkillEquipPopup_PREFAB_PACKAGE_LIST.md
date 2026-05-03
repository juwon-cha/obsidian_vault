# SkillEquipPopup - Phase 5-A: 프리팹 패키지 목록

생성일: 2026-04-07  
FROM: `/Volumes/solidigm/repo/BunkerDefense`  
TO: `/Volumes/solidigm/repo/WiggleDefender`

---

## 1. sync 스크립트와 SerializeField 요약

### SkillEquipPopup.cs (UIBase 상속 - 신규)
| 필드 | 타입 | 설명 |
|---|---|---|
| `_panelContainer` | GameObject | 패널 컨테이너 |
| `_closeButton` | Button | 닫기 버튼 1 |
| `_closeButton2` | Button | 닫기 버튼 2 |
| `_skillSlots[3]` | SkillSlotUI[] | 스킬 장착 슬롯 3개 |
| `_skillListContainer` | Transform | 스킬 목록 컨테이너 |
| `_skillItemPrefab` | SkillItemUI | 스킬 아이템 프리팹 참조 |
| `_skillListScrollRect` | ScrollRect | 스크롤 뷰 |
| `_unitFilterAllButton` | Button | 전체 필터 버튼 |
| `_unitFilterButtons[]` | UnitFilterButtonEntry[] | 유닛별 필터 버튼 배열 |
| `_emptySlotSprite` | Sprite | 빈 슬롯 스프라이트 |

### SkillEquipPanel.cs (MonoBehaviour - 기존 유지)
| 필드 | 타입 | 설명 |
|---|---|---|
| `panelContainer` | GameObject | 패널 컨테이너 |
| `closeButton` | Button | 닫기 버튼 1 |
| `closeButton2` | Button | 닫기 버튼 2 |
| `skillSlots[3]` | SkillSlotUI[] | 스킬 장착 슬롯 3개 |
| `skillListContainer` | Transform | 스킬 목록 컨테이너 |
| `skillItemPrefab` | SkillItemUI | 스킬 아이템 프리팹 참조 |
| `skillListScrollRect` | ScrollRect | 스크롤 뷰 |
| `emptySlotSprite` | Sprite | 빈 슬롯 스프라이트 |

### UnitSkinSkillEquipPanelUI.cs (UIBase 상속 - 수정)
| 필드 | 타입 | 설명 |
|---|---|---|
| `_panelContainer` | GameObject | 패널 컨테이너 |
| `_closeButton` | Button | 닫기 버튼 1 |
| `_closeButton2` | Button | 닫기 버튼 2 |
| `_skillSlots[3]` | UnitSkinSkillSlotUI[] | 스킬 슬롯 3개 (인라인) |
| `_emptySlotSprite` | Sprite | 빈 슬롯 스프라이트 |
| `_skillListContainer` | Transform | 스킬 목록 컨테이너 |
| `_skillItemPrefab` | UnitSkinSkillItemUI | 아이템 프리팹 참조 |
| `_skillListScrollRect` | ScrollRect | 스크롤 뷰 |
| `_unitFilterAllButton` | Button | 전체 필터 버튼 |
| `_unitFilterButtons[]` | UnitFilterButtonEntry[] | 유닛별 필터 버튼 배열 |

### BunkerSkinSkillEquipPanelUI.cs (UIBase 상속 - 수정)
| 필드 | 타입 | 설명 |
|---|---|---|
| `_panelContainer` | GameObject | 패널 컨테이너 |
| `_closeButton` | Button | 닫기 버튼 1 |
| `_closeButton2` | Button | 닫기 버튼 2 |
| `_skillSlots[3]` | BunkerSkinSkillSlotUI[] | 스킬 슬롯 3개 (인라인) |
| `_emptySlotSprite` | Sprite | 빈 슬롯 스프라이트 |
| `_skillListContainer` | Transform | 스킬 목록 컨테이너 |
| `_skillItemPrefab` | BunkerSkinSkillItemUI | 아이템 프리팹 참조 |
| `_skillListScrollRect` | ScrollRect | 스크롤 뷰 |

---

## 2. 재귀 스캔 발견 프리팹 전체 목록

### 루트 프리팹 (진입점)

| 프리팹명 | FROM 경로 | GUID (FROM) |
|---|---|---|
| SkillEquipPopup.prefab | `Resources/UI/SkillEquipPopup.prefab` | d45575af54d034e2db98b2c9e967a800 (SkillEquipPopup.cs 스크립트 참조) |
| SkillEquipPanel.prefab | `Resources/UI/SkillEquipPanel.prefab` | - |
| SkillEquipPanel - Advance.prefab | `Resources/UI/SkillEquipPanel - Advance.prefab` | - |
| UnitSkinSkillEquipPanelUI.prefab | `Resources/UI/UnitSkinSkillEquipPanelUI.prefab` | - |
| BunkerSkinSkillEquipPanelUI.prefab | `Resources/UI/BunkerSkinSkillEquipPanelUI.prefab` | - |

### 자식 프리팹 (재귀 스캔 발견)

| 프리팹명 | FROM 경로 | GUID (FROM) | 참조하는 루트 |
|---|---|---|---|
| SkillSlot.prefab | `_Project/3_Prefabs/UI/Skin/SkillSlot.prefab` | 769a6d23c1b3e8e4b9a54925ea6811b8 | SkillEquipPopup, SkillEquipPanel, SkillEquipPanel-Advance, UnitSkinSkillEquipPanelUI |
| Toggle - UnitFilter.prefab | `_Project/3_Prefabs/UI/Buttons/Toggle - UnitFilter.prefab` | 613df23e8c585a6468487f568a43f81d | SkillEquipPopup, UnitSkinSkillEquipPanelUI |
| Button - BackgroundClose.prefab | `_Project/3_Prefabs/UI/Buttons/Button - BackgroundClose.prefab` | 069400c98789ca641b0df3c8d6163d51 | SkillEquipPopup, SkillEquipPanel, SkillEquipPanel-Advance, UnitSkinSkillEquipPanelUI, BunkerSkinSkillEquipPanelUI |
| TopBox.prefab | `_Project/3_Prefabs/UI/_Common/TopBox.prefab` | 0f33a15fc7b1e474580f3385b7d7acf7 | BunkerSkinSkillEquipPanelUI |
| SkillItemUI.prefab | `_Project/3_Prefabs/UI/Skin/SkillItemUI.prefab` | 5745039d37b40c54893362d6371a80c2 | SkillEquipPopup, SkillEquipPanel, SkillEquipPanel-Advance |
| UnitSkinSkillItemUI.prefab | `_Project/3_Prefabs/UI/Skin/UnitSkinSkillItemUI.prefab` | 77941cb3f6fc642249e7c5dd82eda0b7 | UnitSkinSkillEquipPanelUI |
| BunkerSkinSkillItemUI.prefab | `_Project/3_Prefabs/UI/Skin/BunkerSkinSkillItemUI.prefab` | 188633ababc2f4a119963ce72de791dd | BunkerSkinSkillEquipPanelUI |

---

## 3. TO 상태 분류

### 신규 복사 필요 (TO에 없음)

| 프리팹명 | FROM 경로 | TO 예정 경로 |
|---|---|---|
| SkillEquipPopup.prefab | `BunkerDefense/Assets/Resources/UI/SkillEquipPopup.prefab` | `WiggleDefender/Assets/Resources/UI/SkillEquipPopup.prefab` |
| SkillEquipPanel - Advance.prefab | `BunkerDefense/Assets/Resources/UI/SkillEquipPanel - Advance.prefab` | `WiggleDefender/Assets/Resources/UI/SkillEquipPanel - Advance.prefab` |

**신규 복사: 2개**

---

### ⚠️ 업데이트 필요 (TO에 있으나 FROM이 더 최신)

| 프리팹명 | FROM 노드 수 | TO 노드 수 | 차이 내용 |
|---|---|---|---|
| SkillEquipPanel.prefab | 41 노드 | 36 노드 | FROM에 `filterBox` 노드 추가 (유닛 필터 버튼 영역). SkillEquipPanel 클래스에 unitFilter 관련 필드 없음 - SkillEquipPopup sync 과정에서 FROM의 구 SkillEquipPanel이 filterBox를 시험적으로 추가했을 가능성. 수동 확인 필요. |
| UnitSkinSkillEquipPanelUI.prefab | 87 노드 | 57 노드 | FROM에 `Scroll View - FillterBox` 추가, UnitFilter 버튼 13개 인라인 포함. `_unitFilterButtons[]` SerializeField 연결됨. TO에는 필터 영역 자체가 없음. |

**업데이트 필요: 2개**

---

### ⬛ 스킵 (FROM = TO, 동일 구조)

| 프리팹명 | 노드 수 | 판단 근거 |
|---|---|---|
| BunkerSkinSkillEquipPanelUI.prefab | 60 노드 (FROM = TO) | m_Name 목록, m_SourcePrefab GUID 목록, SerializeField 연결 내용 모두 동일 |
| SkillSlot.prefab | 12 노드 (FROM = TO) | 구조 동일 |
| Toggle - UnitFilter.prefab | 7 노드 (FROM = TO) | 구조 동일 |
| Button - BackgroundClose.prefab | 6 노드 (FROM = TO) | 구조 동일 |
| TopBox.prefab | 10 노드 (FROM = TO) | 구조 동일 |

**스킵: 5개**

---

### 🔵 수동 판단 필요

| 프리팹명 | FROM 노드 수 | TO 노드 수 | 판단 사유 |
|---|---|---|---|
| SkillItemUI.prefab | 32 노드 | 36 노드 | TO가 FROM보다 4개 노드 많음. TO에 `Text (TMP) - EquipText` 노드가 추가되어 있음. TO가 더 최신 버전. FROM으로 덮어쓰면 퇴행 발생. **복사 금지 - 현재 TO 유지.** |
| UnitSkinSkillItemUI.prefab | 32 노드 | 36 노드 | TO가 FROM보다 4개 노드 많음. TO에 `Text (TMP) - EquipText` 노드가 추가되어 있음. TO가 더 최신 버전. FROM으로 덮어쓰면 퇴행 발생. **복사 금지 - 현재 TO 유지.** |
| BunkerSkinSkillItemUI.prefab | 36 노드 | 36 노드 | 노드 수 동일하나, SerializeField fileID가 다름 (TO가 sync 과정에서 재생성됨). 내용상 동일한 것으로 판단. SkillItemUI, UnitSkinSkillItemUI와 일관성 상 **스킵 권장.** |

**수동 판단: 3개**

---

## 4. 의존성 기반 sync 순서 (리프 → 루트)

```
[Layer 0 - 리프 노드 (의존 없음, 스킵/수동판단)]
  ⬛ SkillSlot.prefab
  ⬛ Toggle - UnitFilter.prefab
  ⬛ Button - BackgroundClose.prefab
  ⬛ TopBox.prefab
  🔵 SkillItemUI.prefab          ← TO 유지 (더 최신)
  🔵 UnitSkinSkillItemUI.prefab  ← TO 유지 (더 최신)
  🔵 BunkerSkinSkillItemUI.prefab ← 스킵 권장

[Layer 1 - 패널 프리팹 (자식 의존)]
  ⬛ BunkerSkinSkillEquipPanelUI.prefab  ← 스킵
  ⚠️ UnitSkinSkillEquipPanelUI.prefab   ← FROM으로 업데이트 (필터 영역 추가)
  ⚠️ SkillEquipPanel.prefab             ← FROM으로 업데이트 확인 필요

[Layer 2 - 루트 팝업 (신규)]
  🆕 SkillEquipPanel - Advance.prefab  ← 신규 복사
  🆕 SkillEquipPopup.prefab            ← 신규 복사 (UIBase 등록 필요)
```

---

## 5. sync 시 주의사항

### SkillEquipPopup.prefab (신규 복사)
- UIBase 상속 클래스이므로 UIManager에 Resources/UI 경로로 등록해야 함
- `_unitFilterButtons[]`에 UnitFilterButton 컴포넌트 13개 배열 연결 필요 (UnitType 0~12)
- `_skillItemPrefab`이 SkillItemUI.prefab(guid: 5745039d37b40c54893362d6371a80c2)을 참조 - TO에서 guid가 다를 경우 재연결 필요

### SkillEquipPanel - Advance.prefab (신규 복사)
- SkillEquipPanel과 동일한 클래스(`SkillEquipPanel : MonoBehaviour`)를 사용
- LocalizeStringEvent 컴포넌트 추가됨 (guid: 56eb0353ae6e5124bb35b17aff880f16)
- SkillEquipPopup(UIBase 방식)과의 역할 분리를 팀에 확인 필요

### UnitSkinSkillEquipPanelUI.prefab (업데이트)
- FROM에 `Scroll View - FillterBox` 영역과 Toggle - UnitFilter 프리팹 13개가 추가됨
- `_unitFilterButtons[]` SerializeField 배열이 새로 연결됨 (unitType 0~12)
- `_unitFilterAllButton`도 새로 추가됨
- TO의 기존 SlotContainer, SkillInventory 영역은 유지하면서 필터 영역만 추가

### SkillEquipPanel.prefab (업데이트 - 수동 판단)
- FROM에 `filterBox` 노드 추가됨 (m_Name: filterBox, m_Name: Text (TMP))
- 그러나 SkillEquipPanel 스크립트에는 unitFilter 관련 SerializeField가 없음
- filterBox가 실제로 사용되는지 FROM 코드를 추가 검토 후 결정
- SkillEquipPopup sync으로 SkillEquipPanel이 deprecated 될 경우 스킵 가능

### SkillItemUI.prefab / UnitSkinSkillItemUI.prefab (🔵 수동 판단 - 복사 금지)
- **TO가 FROM보다 최신**: TO에 `Text (TMP) - EquipText` 노드 추가됨
- FROM으로 덮어쓰면 해당 노드 소실 → **현재 TO 파일 유지**

---

## 6. 최종 요약

| 구분 | 프리팹 수 | 파일명 |
|---|---|---|
| 신규 복사 | 2개 | SkillEquipPopup.prefab, SkillEquipPanel - Advance.prefab |
| ⚠️ 업데이트 필요 | 2개 | UnitSkinSkillEquipPanelUI.prefab, SkillEquipPanel.prefab |
| ⬛ 스킵 | 5개 | BunkerSkinSkillEquipPanelUI.prefab, SkillSlot.prefab, Toggle - UnitFilter.prefab, Button - BackgroundClose.prefab, TopBox.prefab |
| 🔵 수동 판단 | 3개 | SkillItemUI.prefab (TO 유지), UnitSkinSkillItemUI.prefab (TO 유지), BunkerSkinSkillItemUI.prefab (스킵 권장) |
| **합계** | **12개** | |
