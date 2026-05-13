# UnitSkin_SYNC_PLAN.md
생성일: 2026-05-13
FROM: /tmp/sync_UnitSkin_1778659946 (origin/bunker-defense/dev)
TO: /Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender
대상 스킨: dragoon_transcend_a

## ⚠️ 범위 제한
- CS 파일 수정 최소화 (ECurrencyType.cs enum 값 1개만 추가)
- WD 코드 구조 변경 없음
- 주 작업: 데이터 복사 + 이미지 리소스 복사

---

## 섹션 0 — 스크립트 분석 결과

### DragoonController.SkinSkill.cs
- **차이 없음** — WD가 이미 WD 아키텍처(Managers.Instance.GetManager, Physics2D.Raycast)로 올바르게 구현됨
- BD는 서비스 레이어(ServiceAccessor, LowLevelPhysicsHelper) 기반으로 WD에 이식 불필요

### EUnitSkinSkillType.cs
- **동일** — 두 파일 완전히 일치. 변경 없음.

### ECurrencyType.cs
- **WD에 `dragoon_transcend_a` enum 값 없음**
- BD: `dragoon_transcend_a = 726` (BD 체계, WD에 그대로 사용 불가)
- WD 마지막 값: `RaceCurrency = 1283` → **WD에서는 `dragoon_transcend_a = 1284` 로 추가**
- CurrencyData 에셋 파일명도 `1284.asset` 사용

---

## 섹션 1 — DataSheet 데이터 변경사항

### 1-1. UnitSkinData.json / UnitSkinData SO 에셋

#### BD/WD ID 매핑 충돌 주의
BD와 WD는 동일한 SO 에셋 파일명(숫자 ID)을 사용하지만 스킨 할당이 다르다.

| ID 범위 | BD 내용 | WD 현재 내용 |
|---|---|---|
| 30576~30580 | marauder_transcend_a rank1~5 | carrier_transcend_a rank1~5 |
| 30581~30585 | dragoon_transcend_a rank1~5 | marauder_transcend_a rank1~5 |
| 30586~30590 | carrier_transcend_a rank1~5 | 없음 (MISSING) |
| 30591~30595 | vessel_transcend_a rank1~5 | 없음 (MISSING) |

**결론**: WD는 BD보다 스킨 순서가 다르게 채워져 있음.
- WD는 30586~30595가 완전히 비어 있음 (JSON에도 없고 .asset도 없음)
- BD에는 30581~30585가 dragoon_transcend_a이지만, WD의 30581~30585는 marauder_transcend_a

#### WD에 추가해야 할 신규 항목
WD JSON 기준 마지막 ID = 30585 (marauder_transcend_a rank5)
BD에서 WD로 가져올 신규 ID 블록:

**dragoon_transcend_a (rank1~5): ID 30586~30590으로 WD에 신규 추가 필요**
- ID는 WD 빈 공간(30586~30590) 활용 권장
- BD 에셋(30581~30585)을 그대로 복사하면 WD의 marauder 에셋을 덮어씀 → 사용 불가

> ⚠️ **ID 재할당 필요**: BD의 30581~30585(dragoon_transcend_a)는 WD에서 30586~30590으로 복사해야 한다. 단순 복사 불가, ID 재지정 후 복사.

**carrier_transcend_a, vessel_transcend_a 추가 여부**: 이번 sync 범위가 dragoon_transcend_a이면 30591~30595(carrier/vessel)는 제외. 단 WD에는 30586~30595의 JSON/에셋이 없으므로 이번 sync 작업 후 추후 추가 필요.

#### dragoon_transcend_a 데이터 내용 (BD 기준)
| id(BD) | id(WD 신규) | rank | effectValue1 | effectValue2 | costType1 | cardID | animatorPath |
|---|---|---|---|---|---|---|---|
| 30581 | 30586 | 1 | 20 | 25 | **1284** | 207121 | Anim/IngameUnitSkin/Dragoon_Anim_Skin2 |
| 30582 | 30587 | 2 | 40 | 50 | **1284** | 207121 | Anim/IngameUnitSkin/Dragoon_Anim_Skin2 |
| 30583 | 30588 | 3 | 60 | 75 | **1284** | 207121 | Anim/IngameUnitSkin/Dragoon_Anim_Skin2 |
| 30584 | 30589 | 4 | 80 | 100 | **1284** | 207121 | Anim/IngameUnitSkin/Dragoon_Anim_Skin2 |
| 30585 | 30590 | 5 | 100 | 125 | **1284** | 207121 | Anim/IngameUnitSkin/Dragoon_Anim_Skin2 |

### 1-2. CurrencyData 에셋 (신규, WD ID = 1284)
BD에만 존재하는 신규 재화. WD에 없음.
- BD 원본: `CurrencyData/726.asset` (BD currencyType = 726)
- **WD 파일명: `1284.asset`** (WD 마지막 ID 1283 다음)
- currencyType: **1284** (WD 기준 재할당)
- currencyTypeS: dragoon_transcend_a
- memo: 드래군 스킨 재화
- currencyName: dragoon_transcend_a_name
- iconPath: Sprites/Icon/icon_dragoon_transcend_a
- rarity: 6

**복사 후 내부 ID 필드 수정 필요**: BD `726.asset` → WD `1284.asset`, 내부 `currencyType: 1284`로 변경

---

## 섹션 2 — UnitSkinResourceConfigSO 변경사항

### BD UnitSkinResourceConfig 엔트리 목록 (9개)
```
drfrost_legendary_a, turret_legendary_a, turret_transcend_a,
ninja_mythic_a, marauder_legendary_a, carrier_mythic_a,
drfrost_transcend_a*, ninja_transcend_a, carrier_transcend_a
```
> * BD에는 `drfrost_transcend _a` (공백 포함 오타). WD에는 `drfrost_transcend_a` (정상).

### WD UnitSkinResourceConfig 엔트리 목록 (10개)
```
drfrost_legendary_a, turret_legendary_a, turret_transcend_a,
ninja_mythic_a, marauder_legendary_a, carrier_mythic_a,
drfrost_transcend_a, ninja_transcend_a, carrier_transcend_a,
marauder_transcend_a (WD에만 존재)
```

### 결론
- BD의 UnitSkinResourceConfig에는 **dragoon_transcend_a 엔트리가 없음**
- WD에는 marauder_transcend_a 엔트리가 추가된 상태
- dragoon_transcend_a는 `Dragoon_Anim_Skin2` controller를 animatorPath로 사용 (JSON 기준)
- UnitSkinResourceConfig에 dragoon_transcend_a 엔트리 추가 필요 여부는 스킨 타입에 따라 결정:
  - `_subObjectType: 1` (Animator 타입) 사용 예상 (drfrost_transcend_a 패턴 참고)
  - UnitSkinResourceConfig.asset을 BD에서 복사하면 WD 전용 marauder_transcend_a 엔트리 소실됨 → **직접 편집 필요**

---

## 섹션 3 — 복사 필요 이미지/에셋 목록

### 3-1. 아이콘 이미지

| 파일 | FROM | TO | 크기 |
|---|---|---|---|
| icon_dragoon_transcend_a.png | `/tmp/sync_UnitSkin_1778659946/Assets/Resources/Sprites/Icon/icon_dragoon_transcend_a.png` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/Resources_moved/Sprites/Icon/icon_dragoon_transcend_a.png` | 52K |
| icon_dragoon_transcend_a.png.meta | 동일 경로.meta | 동일 경로.meta | - |

> WD 아이콘 경로는 `Resources_moved/Sprites/Icon/` (기존 스킨 아이콘 위치 기준)

### 3-2. 유닛 스킨 스프라이트

| 파일 | FROM | TO | 크기 |
|---|---|---|---|
| dragoon_transcend_a/ (폴더 전체) | `/tmp/sync_UnitSkin_1778659946/Assets/Resources/Sprites/Skin/Unit/dragoon_transcend_a/` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/Resources_moved/Sprites/Skin/Unit/dragoon_transcend_a/` | - |
| dragoon_transcend_a.png | 폴더 내 | 폴더 내 | 132K |
| dragoon_transcend_a_full.png | 폴더 내 | 폴더 내 | 66K |
| dragoon_transcend_a.png.meta | 폴더 내 | 폴더 내 | 4.0K |
| dragoon_transcend_a_full.png.meta | 폴더 내 | 폴더 내 | 4.0K |
| (폴더 .meta) dragoon_transcend_a.meta | `/tmp/sync_UnitSkin_1778659946/Assets/Resources/Sprites/Skin/Unit/dragoon_transcend_a.meta` | 동일 경로 대응 | - |

### 3-3. 애니메이션 컨트롤러

| 파일 | FROM | TO | 크기 | 비고 |
|---|---|---|---|---|
| Dragoon_Anim_Skin2.controller | `/tmp/sync_UnitSkin_1778659946/Assets/Resources/Anim/IngameUnitSkin/Dragoon_Anim_Skin2.controller` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/Resources_moved/Anim/IngameUnitSkin/Dragoon_Anim_Skin2.controller` | 5.9K | WD에 없음 |
| Dragoon_Anim_Skin2.controller.meta | 동일 경로.meta | 동일 경로.meta | 188B | - |

### 3-4. DataSheet SO 에셋 (신규 ID 기준 — ID 재할당 후 복사)

> BD의 30581~30585를 WD에서 30586~30590으로 복사하되, 파일명과 내부 id 필드를 변경해야 함.

| BD 파일명 | WD 생성 파일명 | unitSkinId | rank |
|---|---|---|---|
| 30581.asset | 30586.asset | dragoon_transcend_a | 1 |
| 30582.asset | 30587.asset | dragoon_transcend_a | 2 |
| 30583.asset | 30588.asset | dragoon_transcend_a | 3 |
| 30584.asset | 30589.asset | dragoon_transcend_a | 4 |
| 30585.asset | 30590.asset | dragoon_transcend_a | 5 |

경로: `Assets/Resources/ScriptableObjects/UnitSkinData/`

각 에셋에서 `id:` 필드와 `m_Name:` 필드를 30586~30590으로 변경 후 저장.

### 3-5. CurrencyData SO 에셋

| 파일 | FROM | TO | 비고 |
|---|---|---|---|
| 726.asset | `/tmp/sync_UnitSkin_1778659946/Assets/Resources/ScriptableObjects/CurrencyData/726.asset` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/Resources/ScriptableObjects/CurrencyData/726.asset` | WD에 없음 |
| 726.asset.meta | 동일 경로.meta | 동일 경로.meta | - |

### 3-6. JSON 파일 업데이트

| 파일 | 작업 |
|---|---|
| `Assets/Resources/JsonFiles/UnitSkinData.json` | BD의 dragoon_transcend_a 5개 항목을 id 30586~30590으로 재할당하여 WD JSON 끝에 추가 |

---

## 섹션 4 — 체크리스트

### 이미지/스프라이트 복사
- [x] `icon_dragoon_transcend_a.png` + `.meta` → WD `Resources_moved/Sprites/Icon/`
- [x] `dragoon_transcend_a/` 폴더 전체 (png×2 + meta×2 + 폴더meta) → WD `Resources_moved/Sprites/Skin/Unit/`
- [x] `Dragoon_Anim_Skin2.controller` + `.meta` → WD `Resources_moved/Anim/IngameUnitSkin/`

### DataSheet SO 에셋 복사 (ID 재할당)
- [x] BD `30581.asset` → WD `30586.asset` (id 필드 30586, m_Name 30586으로 변경)
- [x] BD `30582.asset` → WD `30587.asset` (id 필드 30587, m_Name 30587으로 변경)
- [x] BD `30583.asset` → WD `30588.asset` (id 필드 30588, m_Name 30588으로 변경)
- [x] BD `30584.asset` → WD `30589.asset` (id 필드 30589, m_Name 30589으로 변경)
- [x] BD `30585.asset` → WD `30590.asset` (id 필드 30590, m_Name 30590으로 변경)
- [x] 각 에셋의 `.meta` 파일도 함께 복사 (GUID는 BD 것 그대로 사용 가능)

### JSON 업데이트
- [x] `UnitSkinData.json` — dragoon_transcend_a 5개 항목 추가 (id 30586~30590)

### ECurrencyType.cs 수정
- [x] WD `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` 맨 끝에 `dragoon_transcend_a = 1284,` 추가 (`RaceCurrency = 1283` 다음)

### CurrencyData SO 에셋 복사
- [x] BD `CurrencyData/726.asset` 복사 → WD `Resources/ScriptableObjects/CurrencyData/1284.asset` (내부 currencyType 필드 1284로 수정)

### UnitSkinResourceConfig.asset 편집
- [x] WD `UnitSkinResourceConfig.asset`에 dragoon_transcend_a 엔트리 수동 추가
  - `_unitSkinId: dragoon_transcend_a`
  - `_targetUnit: 6`
  - `_hitEffect: 0`
  - `_subObjectResources:` (Dragoon Anim Skin2 사용 여부에 따라 subObjectType:1로 animator 참조 추가)

### 최종 확인
- [ ] Unity 에디터에서 UnitSkinResourceConfig inspector 확인
- [ ] UnitSkinData SO 에셋 번호 30586~30590 정상 로드 확인
- [ ] icon_dragoon_transcend_a 아이콘 정상 표시 확인
- [ ] Dragoon_Anim_Skin2 controller 참조 정상 연결 확인

---

## 섹션 5 — 주의사항

### 5-1. ID 충돌 — 가장 중요한 위험
- BD의 30581~30585는 `dragoon_transcend_a`이나, **WD의 30581~30585는 이미 `marauder_transcend_a`로 사용 중**
- BD 에셋을 그대로 덮어쓰면 WD의 marauder_transcend_a 데이터가 파괴됨
- **반드시 WD의 빈 ID(30586~30590)로 재할당하여 복사해야 한다**

### 5-2. UnitSkinResourceConfig.asset 덮어쓰기 금지
- BD의 UnitSkinResourceConfig.asset(9개 엔트리)을 WD에 그대로 복사하면 WD 전용 `marauder_transcend_a` 엔트리(10번째)가 소실됨
- WD 파일에 dragoon_transcend_a 블록만 수동으로 추가해야 한다

### 5-3. BD UnitSkinResourceConfig에 dragoon_transcend_a 엔트리 없음
- BD의 UnitSkinResourceConfig에는 dragoon_transcend_a가 등록되어 있지 않음
- 참조 패턴은 drfrost_transcend_a (animator 단일 참조, subObjectType:1) 참고
- Dragoon_Anim_Skin2.controller의 GUID를 확인 후 수동 추가 필요

### 5-4. Dragoon_Anim_Skin2.controller — WD에 없는 신규 파일
- animatorPath: `Anim/IngameUnitSkin/Dragoon_Anim_Skin2` 참조
- WD에는 `Dragoon_Anim_Skin.controller`(기존 스킨용)만 있고 `Skin2`는 없음
- BD에서 복사 후 WD의 Resources_moved/Anim/IngameUnitSkin/에 배치

### 5-5. DataSheet SO 파일 GUID 정책
- CLAUDE.md 규칙: `SOs/SO/DataSheet/` 내 파일은 구글 시트 자동 생성 → 수정 금지
- SO 에셋(.asset)은 `Resources/ScriptableObjects/UnitSkinData/` 경로로 CS와 무관하게 복사 가능
- `.meta` 파일의 GUID는 BD 것을 그대로 유지해도 되나, WD 프로젝트에서 GUID 중복 발생 가능성 확인 필요

### 5-6. vessel_transcend_a / carrier_transcend_a 추가 에셋
- BD에는 vessel_transcend_a(30591~30595), carrier_transcend_a(30586~30590) 신규 에셋도 있음
- 이번 sync 범위는 dragoon_transcend_a이므로 제외
- 단, 위 번호들이 다음 sync에서 사용될 예정임을 인지하고 WD 30591 이후 ID 예약 필요
