# vessel_transcend_a sync 분석 문서
## FROM 프로젝트 (BunkerDefense) → TO 프로젝트 (WriggleDefender)

> **작성일**: 2026-06-04
> **SYSTEM**: vessel_transcend_a (UnitSkin × Vessel × Transcend)
> **소스(FROM)**: `C:/Users/JuwonCha/AppData/Local/Temp/sync_vessel_transcend_a_20260603_231737` (BunkerDefense, BD)
> **대상(TO)**: `C:/JuwonCha/WriggleDefender` (WriggleDefender, WD) — 브랜치 `juwon/UpdateSync`
> **grep 키워드**: `UnitSkin\|VesselTranscend\|vessel_transcend_a`
> **참고 플랜**: `2026-05-13_UnitSkin_dragoon_transcend_a/UnitSkin_dragoon_transcend_a_SYNC_PLAN.md` (구조 참고용)
> **WD_SYNC_GUIDE**: 본 환경에 부재. 컨벤션은 dragoon 플랜에서 추론.

---

## 사전 조건 — FROM_LOCAL 확인

```bash
ls "C:/Users/JuwonCha/AppData/Local/Temp/sync_vessel_transcend_a_20260603_231737/Assets" > /dev/null 2>&1 && echo "OK" || echo "NOT_FOUND"
```

---

## 0. sync 전 grep 전수조사 결과 (Phase 1+2 종합)

> **이 표는 FROM에서 `vessel_transcend_a` 키워드 또는 BD enum 값 `819`가 등장하는 모든 파일을 망라한다.**
> CS 파일은 1건(ECurrencyType.cs)뿐이며 나머지는 데이터/리소스/프리팹이다.

| FROM 파일 | 역할 | FROM 전용 패턴 | sync 유형 | TO 처리 방법 |
|---|---|---|---|---|
| `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` | enum 정의 | BD 값 `819` 사용 | **ADAPTED** | TO 기존 파일에 `vessel_transcend_a = 1285` 1줄 추가 (WD 컨벤션) |
| `Assets/Resources/JsonFiles/UnitSkinData.json` | 스킨 데이터 | `costAmount1/2` 필드 보유 (WD 스키마에 없음), `costType1=819`, `costType2=374` | **PARTIAL** | 5개 entry 추가, 필드 삭제+재매핑 |
| `Assets/Resources/JsonFiles/CurrencyData.json` | 재화 데이터 | `currencyType=819`, `memo` 빈 값 | **ADAPTED** | 1개 entry 추가, `currencyType: 1285` |
| `Assets/Resources/JsonFiles/ProfileIconData.json` | 프로필 아이콘 데이터 | `iconNameKey=Profile_Icon_Name_59` (off-by-1) | **ADAPTED** | 1개 entry 추가, iconNameKey 정책 결정 필요 |
| `Assets/Resources/ScriptableObjects/UnitSkinData/30591.asset` ~ `30595.asset` (×5) | UnitSkin SO 에셋 | `costType1=819`, `costType2=374`, `costAmount1/2` 보유 | **ADAPTED** | 파일명 그대로 복사, 내부 필드 재매핑 |
| `Assets/Resources/ScriptableObjects/CurrencyData/819.asset` | Currency SO 에셋 | `m_Name=819`, `currencyType=819` | **ADAPTED** | `1285.asset`으로 rename + 내부 필드 재매핑 |
| `Assets/Resources/ScriptableObjects/ProfileIconData/58.asset` | ProfileIcon SO 에셋 | `m_Script guid=4bd52e65...` (WD GUID와 불일치!) | **ADAPTED** | 파일명 그대로, m_Script guid 재매핑 필수 |
| `Assets/Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` (+.meta) | 애니메이션 컨트롤러 | 없음 | **DIRECT** | WD `Resources_moved/Anim/IngameUnitSkin/`에 복사 |
| `Assets/_Project/4_Animations/Vessel/Vessel_Attack_Skin2.anim` (+.meta) | 애니메이션 클립 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/4_Animations/Vessel/Vessel_Charge_Idle_Skin2.anim` (+.meta) | 애니메이션 클립 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/4_Animations/Vessel/Vessel_Charge_Skin2.anim` (+.meta) | 애니메이션 클립 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/4_Animations/Vessel/Vessel_Idle_Skin2.anim` (+.meta) | 애니메이션 클립 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_effect_06_vessel.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 (파일명 공백 주의) |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_effect_vessel_energy.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_attack1.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charge.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger1.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger2.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger3.png` (+.meta) | 텍스처 | 없음 | **DIRECT** | 동일 경로 복사 |
| `Assets/Resources/Sprites/Icon/icon_vessel_transcend_a.png` (+.meta) | UI 아이콘 | 없음 | **DIRECT** | WD `Resources_moved/Sprites/Icon/`에 복사 |
| `Assets/Resources/Sprites/Icon/item_vessel_transcend_a.png` (+.meta) | 아이템 아이콘 | 사용처 미확인 | **DIRECT** | 동일 경로 복사 (안전 차원) |
| `Assets/Resources/Sprites/Skin/Unit/vessel_transcend_a/` 폴더 | 유닛 스프라이트 | 없음 | **DIRECT** | WD `Resources_moved/Sprites/Skin/Unit/`에 폴더 전체 복사 |
| `Assets/_Project/3_Prefabs/Units/Vessel/MovingVesselController.prefab` | 베셀 프리팹 | `_skinVisuals` 리스트에 BD entry 추가 | **PARTIAL** | Unity 에디터에서 수동 편집 필수 |
| `Assets/_Project/3_Prefabs/Units/Vessel/SmallVesselController.prefab` | 베셀 프리팹 | 동일 | **PARTIAL** | Unity 에디터에서 수동 편집 필수 |

> **sync 유형 합계**: DIRECT 16건 / ADAPTED 9건 / PARTIAL 3건 / BLOCKED 0건
>
> **⚠️ 외부 호출자 누락 확인 완료** — CS 코드에서 `ECurrencyType.vessel_transcend_a` 또는 `819` 식별자 직접 참조는 FROM/TO 모두 **0건**. 모두 데이터에서 숫자값으로만 참조됨 (Phase 2 §E 확인). 따라서 enum 1줄 추가 후 데이터/리소스만 갱신하면 결선 완료.

### 0.1 PARTIAL 파일 의존성 상세

| 파일 | 미sync 의존성 / 변환 사유 | TO 대체 처리 | 향후 조치 |
|---|---|---|---|
| `UnitSkinData.json` (BD entry) | BD 스키마: `costAmount1`, `costAmount2` 필드 보유 / WD 스키마: 두 필드 없음 | 필드 두 개 **삭제** 후 추가 | 시트 동기화 시 자동 정리 |
| `UnitSkinData.json` / `*.asset` (BD entry) | `costType2: 374` (BD 토큰 재화). WD transcend 컨벤션은 `1055` | `374` → `1055` 강제 치환 | 시트 PIC에 vessel 행 추가 시 동일하게 `1055` 입력 |
| `MovingVesselController.prefab` / `SmallVesselController.prefab` | `_skinVisuals` 리스트에 `skinId: vessel_transcend_a` + nested prefab instance 추가. BD prefab을 그대로 머지하면 fileID 충돌 | Unity 에디터에서 수동 편집 (텍스트 머지 금지) | 본 sync 작업자가 직접 에디터 실행 |
| `ProfileIconData/58.asset` | BD `m_Script guid: 4bd52e65199d1bc46a19cccea1737ecf` vs WD ProfileIconDataSO guid: `14ae038bb36d30c4b9548f59cf924a4c` | 복사 후 `m_Script` guid 재매핑 필수 (아니면 SO 클래스 binding 깨짐) | — |

---

## 1. FROM vs TO 현재 상태 비교

### 1.1 TO에 이미 존재하는 요소 (변경 불필요)

| 파일/클래스 | TO 경로 | 상태 |
|---|---|---|
| `UnitSkinManager.cs` + `.Preset.cs` + `.Cheat.cs` | `Core/Managers/` | ✅ 존재 — `unitSkinId: string` 키 기반, 신규 스킨 자동 인식 |
| `VesselController.cs` / `.SkinSkill.cs` | `Core/Controllers/Vessel/` | ✅ 존재 — vessel_transcend_a 리터럴 없음. WD 아키텍처 적용 완료 |
| `ECurrencyType.cs` | `Core/Enums/` | ✅ 존재 — `RaceCurrency = 1283`, `dragoon_transcend_a = 1284`까지 (line 778) |
| `UnitSkinData.json` | `Resources/JsonFiles/` | ✅ 존재 — 마지막 entry id `30590` (dragoon_transcend_a rank5) |
| `CurrencyData.json` | `Resources/JsonFiles/` | ✅ 존재 — 마지막 entry currencyType `1284` (dragoon_transcend_a) |
| `ProfileIconData.json` | `Resources/JsonFiles/` | ✅ 존재 — 마지막 entry iconIndex `57` (marine_transcend_i) |
| `UnitSkinData/30586.asset` ~ `30590.asset` | `Resources/ScriptableObjects/` | ✅ 존재 — dragoon_transcend_a rank1~5. WD `m_Script` guid `7049d4123a48b4a1bb19a9a90842d29c` |
| `CurrencyData/1284.asset` | `Resources/ScriptableObjects/` | ✅ 존재 — dragoon_transcend_a. `m_Script` guid `bb74e6198ac5c5642b52405b5a150591` |
| `ProfileIconData/57.asset` | `Resources/ScriptableObjects/` | ✅ 존재 — 마지막 entry. `m_Script` guid `14ae038bb36d30c4b9548f59cf924a4c` |
| `Managers.cs` | `Core/Managers/` | ✅ 변경 없음 (`ManagerDefinition` 추가 불요 — UnitSkinManager 기존 등록) |
| `VFX_Vessel_Loop_New.prefab` | `_Project/3_Prefabs/...` | ✅ 존재 (guid `df592532ade415141adad6103120bf6e`) |
| `Vessel_Anim_Skin.controller` | `Resources_moved/Anim/IngameUnitSkin/` | ✅ 존재 — vessel_mythic_a용. Skin2는 별개 |
| `UnitSkinResourceConfig.asset` | `SOs/SO/...` | ✅ 존재 — vessel_* 엔트리 미등록. **vessel은 등록 정책 외 — 편집 불필요** |

### 1.2 TO에 없는 요소 (sync 필요)

| 카테고리 | 항목 | 작업 |
|---|---|---|
| **enum 추가** | `ECurrencyType.vessel_transcend_a = 1285` | 1줄 추가 (line 779) |
| **JSON entry 추가** | `UnitSkinData.json` — 5개 entry (id 30591~30595) | 마지막 `]}` 직전 삽입 + 변환 |
| **JSON entry 추가** | `CurrencyData.json` — 1개 entry (currencyType 1285) | 마지막 `]}` 직전 삽입 + 변환 |
| **JSON entry 추가** | `ProfileIconData.json` — 1개 entry (iconIndex 58) | 마지막 `]}` 직전 삽입 + 변환 |
| **신규 .asset** | `UnitSkinData/30591.asset` ~ `30595.asset` (5개) + `.meta` | 복사 + 내부 필드 변환 |
| **신규 .asset** | `CurrencyData/1285.asset` + `.meta` | BD `819.asset` 복사 → rename + 필드 변환 |
| **신규 .asset** | `ProfileIconData/58.asset` + `.meta` | 복사 + `m_Script guid` 재매핑 |
| **신규 controller** | `Vessel_Anim_Skin2.controller` + `.meta` | DIRECT 복사 |
| **신규 .anim** | `Vessel_Attack_Skin2.anim`, `Vessel_Charge_Idle_Skin2.anim`, `Vessel_Charge_Skin2.anim`, `Vessel_Idle_Skin2.anim` (4개) + `.meta` | DIRECT 복사 |
| **신규 텍스처** | `special skin_*` 7개 + `.meta` | DIRECT 복사 (파일명 공백) |
| **신규 PNG** | `icon_vessel_transcend_a.png`, `item_vessel_transcend_a.png` (+meta) | DIRECT 복사 |
| **신규 폴더** | `Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/` (png 2개 + meta 3개) | DIRECT 복사 |
| **수정 (수동/에디터)** | `MovingVesselController.prefab`, `SmallVesselController.prefab` | Unity 에디터 작업 |
| **조건부** | `link.xml` | IL2CPP 영향 없음 (enum 값만 추가). 작업 불필요 |
| **조건부** | `Managers.cs` | 변경 불필요 (Phase 2 §H, line 50~ ManagerDefinition 배열 검증 완료) |

---

## 2. FROM 원본 파일 분석

### 2.1 `ECurrencyType.cs` — enum 1줄 추가

**FROM 위치**: `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs:784`

```csharp
vessel_transcend_a = 819,
```

**FROM 전용 패턴**: BD 값 `819`는 WD에서 사용 불가 (충돌 위험). WD는 `RaceCurrency = 1283`, `dragoon_transcend_a = 1284`까지 사용. → WD에서는 **`vessel_transcend_a = 1285`**.

**의존성**: 없음. enum 값이 데이터(JSON/.asset)의 `costType1`, `currencyType` 숫자 필드와 결선됨.

---

### 2.2 `UnitSkinData.json` — entry 5개 추가 (PARTIAL)

**FROM 위치**: `Assets/Resources/JsonFiles/UnitSkinData.json:1902~1996`

**BD 원본 (rank1, 30591)**:
```json
{
  "id": 30591,
  "unitSkinId": "vessel_transcend_a",
  "targetUnit": 7,
  "skinRarity": 2,
  "skinRank": 1,
  "effectValue1": 20.0,
  "effectType2": 1,
  "effectValue2": 25.0,
  "skillDescription": "unit_skin_transcend_desc2",
  "skinSkillType": 2,
  "skillValue": 0.0,
  "cardID": 208121,
  "costType1": 819,
  "costAmount1": 1,
  "costType2": 374,
  "costAmount2": 1,
  "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
}
```

**FROM 전용 패턴 → WD 변환**:
- `costType1: 819` → `1285` (WD enum 재매핑)
- `costType2: 374` → `1055` (WD transcend 컨벤션 — Phase 2 §I-2)
- `costAmount1`, `costAmount2` 필드 **삭제** (WD 스키마 미보유 — `30586.asset` 비교 검증)
- `effectType2: 1` 유지 (WD 추론 불가, BD 값 보존 — Phase 2 §I-1)
- `id`, `unitSkinId`, `targetUnit`, `cardID`, `animatorPath` 등은 그대로 유지

---

### 2.3 `CurrencyData.json` — entry 1개 추가 (ADAPTED)

**FROM 위치**: `Assets/Resources/JsonFiles/CurrencyData.json:10900~10914`

**BD 원본**:
```json
{
  "currencyType": 819,
  "currencyTypeS": "vessel_transcend_a",
  "currencyName": "vessel_transcend_a_name",
  "iconScale": 1.0,
  "iconPath": "Sprites/Icon/icon_vessel_transcend_a",
  "rarity": 6,
  "description": "skin_desc_unit",
  "acquisitionPaths": ["route_event"],
  "acquisitionRouteTypes": ["Default"]
}
```

**변환**:
- `currencyType: 819` → `1285`
- BD에 `memo` 필드 없음 / WD dragoon에는 `"memo": "데 드라군"` 존재 → **시트 PIC가 vessel 행에 한글 memo 추가 시 동기화 필요** (sync 직접 반영은 빈 문자열 또는 생략 처리)

---

### 2.4 `ProfileIconData.json` — entry 1개 추가 (ADAPTED)

**FROM 위치**: `Assets/Resources/JsonFiles/ProfileIconData.json:525~533`

**BD 원본**:
```json
{
  "iconIndex": 58,
  "order": 50,
  "iconNameKey": "Profile_Icon_Name_59",
  "iconPath": "Sprites/Icon/icon_vessel_transcend_a",
  "unlockCondition": 101,
  "unlockValueString": "vessel_transcend_a",
  "unlockDescriptionKey": "icon_vessel_transcend_a"
}
```

**변환**:
- `iconIndex: 58` 유지 (WD `57`까지 사용, 58 슬롯 빈 상태)
- `iconNameKey: Profile_Icon_Name_59` → **`Profile_Icon_Name_58` 권장** (WD 컨벤션: iconIndex N ↔ Name_N+1 매핑이 WD에서 일관됨. WD 57.asset = `Profile_Icon_Name_58` 검증). 단, 시트 정책과 충돌 가능 → 시트 PIC 확인 필요 (Phase 2 §I-4).
- `order: 50` — WD 직전 entry `order: 30` (marine_transcend_i)과 비교. 정렬 충돌 가능 → 시트에서 정책 확인. **현 sync는 BD 값 50 유지** (디자이너 검수 안내)
- `iconPath`, `unlockCondition`, `unlockValueString`, `unlockDescriptionKey` 그대로

---

### 2.5 `UnitSkinData/30591.asset` ~ `30595.asset` — ADAPTED

**FROM 위치**: `Assets/Resources/ScriptableObjects/UnitSkinData/30591.asset` ~ `30595.asset`

**BD 원본 (30591)**:
```yaml
%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!114 &11400000
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: 7049d4123a48b4a1bb19a9a90842d29c, type: 3}
  m_Name: 30591
  m_EditorClassIdentifier: Assembly-CSharp::UnitSkinDataSO
  id: 30591
  unitSkinId: vessel_transcend_a
  targetUnit: 7
  skinRarity: 2
  skinRank: 1
  effectValue1: 20
  effectType2: 1
  effectValue2: 25
  skillDescription: unit_skin_transcend_desc2
  skinSkillType: 2
  skillValue: 0
  cardID: 208121
  costType1: 819
  costAmount1: 1
  costType2: 374
  costAmount2: 1
  animatorPath: Anim/IngameUnitSkin/Vessel_Anim_Skin2
```

**변환**:
- `m_Script` guid `7049d4123a48b4a1bb19a9a90842d29c` — WD와 **일치** (확인 완료)
- `m_Name`, `id` — 파일명과 그대로 유지 (30591~30595 슬롯 빈 상태, 충돌 없음 — Phase 2 §I-3)
- `costType1: 819` → `1285`
- `costType2: 374` → `1055`
- `costAmount1`, `costAmount2` 필드 **삭제** (WD 스키마)
- 나머지 필드 그대로

---

### 2.6 `CurrencyData/819.asset` — ADAPTED (rename + 필드 재매핑)

**FROM 위치**: `Assets/Resources/ScriptableObjects/CurrencyData/819.asset`

**BD 원본**:
```yaml
%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!114 &11400000
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: bb74e6198ac5c5642b52405b5a150591, type: 3}
  m_Name: 819
  m_EditorClassIdentifier: Assembly-CSharp::CurrencyDataSO
  currencyType: 819
  currencyTypeS: vessel_transcend_a
  memo: 
  currencyName: vessel_transcend_a_name
  iconScale: 1
  iconPath: Sprites/Icon/icon_vessel_transcend_a
  rarity: 6
  description: skin_desc_unit
  acquisitionPaths:
  - route_event
  acquisitionRouteTypes: ffffffff
```

**변환**:
- 파일명: `819.asset` → `1285.asset` (+ `.meta` 함께 rename)
- `m_Script` guid `bb74e6198ac5c5642b52405b5a150591` — WD와 **일치** (확인 완료)
- `m_Name: 819` → `1285`
- `currencyType: 819` → `1285`
- 나머지 필드 그대로 (memo 빈 값 유지, 시트에 한글 추가 권장)

---

### 2.7 `ProfileIconData/58.asset` — ADAPTED (m_Script guid 재매핑 필수!)

**FROM 위치**: `Assets/Resources/ScriptableObjects/ProfileIconData/58.asset`

**BD 원본**:
```yaml
%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!114 &11400000
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 0}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: 4bd52e65199d1bc46a19cccea1737ecf, type: 3}
  m_Name: 58
  m_EditorClassIdentifier: Assembly-CSharp::ProfileIconDataSO
  iconIndex: 58
  order: 50
  iconNameKey: Profile_Icon_Name_59
  iconPath: Sprites/Icon/icon_vessel_transcend_a
  unlockCondition: 101
  unlockValueString: vessel_transcend_a
  unlockDescriptionKey: icon_vessel_transcend_a
```

**변환** (⚠️ 다른 SO 에셋과 다름):
- 파일명 `58.asset` 그대로 사용 (WD 빈 슬롯)
- `m_Script` guid `4bd52e65199d1bc46a19cccea1737ecf` → **`14ae038bb36d30c4b9548f59cf924a4c`** (WD ProfileIconDataSO 실 GUID. 검증 완료)
- `m_Name`, `iconIndex` — `58` 그대로
- `iconNameKey: Profile_Icon_Name_59` → `Profile_Icon_Name_58` 권장 (WD 일관성)
- 나머지 필드 그대로

---

### 2.8 `Vessel_Anim_Skin2.controller` + 의존 .anim 4종 + 텍스처 7종 — DIRECT

| FROM 파일 | TO 경로 | 비고 |
|---|---|---|
| `Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` (+meta, guid `5549fbd8b125be543acd5100e9b0dd76`) | `Resources_moved/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` | WD는 Resources_moved 사용 |
| `_Project/4_Animations/Vessel/Vessel_Attack_Skin2.anim` (+meta) | 동일 경로 | controller 의존 |
| `_Project/4_Animations/Vessel/Vessel_Charge_Idle_Skin2.anim` (+meta) | 동일 경로 | controller 의존 |
| `_Project/4_Animations/Vessel/Vessel_Charge_Skin2.anim` (+meta) | 동일 경로 | controller 의존 |
| `_Project/4_Animations/Vessel/Vessel_Idle_Skin2.anim` (+meta) | 동일 경로 | controller 의존 |
| `_Project/6_Textures/Units/Vessel/special skin_effect_06_vessel.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_effect_vessel_energy.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_attack1.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charge.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger1.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger2.png` (+meta) | 동일 경로 | anim sprite GUID |
| `_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger3.png` (+meta) | 동일 경로 | anim sprite GUID `04043b24...` 매핑 확인됨 (Phase 2 §G-5) |

### 2.9 아이콘 PNG + 유닛 스프라이트 폴더 — DIRECT

| FROM 파일 | TO 경로 |
|---|---|
| `Resources/Sprites/Icon/icon_vessel_transcend_a.png` (+meta, guid `81502f37c101142c28e1995a31ce51d1`) | `Resources_moved/Sprites/Icon/` |
| `Resources/Sprites/Icon/item_vessel_transcend_a.png` (+meta, guid `e6d7bb6e9deca4b20af821472970c8d1`) | `Resources_moved/Sprites/Icon/` |
| `Resources/Sprites/Skin/Unit/vessel_transcend_a/vessel_transcend_a.png` (+meta, guid `eb4d5158d360b4e909a9c6cd4e166d2a`) | `Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/` |
| `Resources/Sprites/Skin/Unit/vessel_transcend_a/vessel_transcend_a_full.png` (+meta, guid `7b41b6a15c9df49a9a49947edd236a48`) | `Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/` |
| `Resources/Sprites/Skin/Unit/vessel_transcend_a.meta` (폴더 .meta) | `Resources_moved/Sprites/Skin/Unit/vessel_transcend_a.meta` |

### 2.10 프리팹 편집 — PARTIAL (Unity 에디터 작업)

| 파일 | 작업 |
|---|---|
| `_Project/3_Prefabs/Units/Vessel/MovingVesselController.prefab` | `VesselSkinVisual._skinVisuals`에 `{skinId: vessel_transcend_a, visualObject: <VFX 인스턴스>}` 추가 |
| `_Project/3_Prefabs/Units/Vessel/SmallVesselController.prefab` | 동일 |

VFX prefab `VFX_Vessel_Loop_New.prefab` (guid `df592532ade415141adad6103120bf6e`)은 WD에 이미 존재. nested prefab instance로 추가 후 fileID 연결.

---

## 섹션 2.5 — 숨겨진 인프라 의존성 감사

### 2.5.1 Utils/ 폴더 비교
| 파일명 | FROM | TO | sync 필요 |
|---|---|---|---|
| (변경 없음 — Phase 1 §2-A) | — | — | ❌ |

### 2.5.2 JSON 직렬화 인프라
| 항목 | FROM | TO | 일치 여부 |
|---|---|---|---|
| `_jsonSerializer` 초기화 / Newtonsoft converter | (변경 없음) | (변경 없음) | ✅ |

### 2.5.3 커스텀 타입 동반 인프라
해당 없음. ECurrencyType은 단순 enum, SaveData에 추가 필드 없음.

### 2.5.4 감사 결론
- **sync 필요 인프라 파일**: 0개
- **초기화 코드 수정 필요**: 0곳
- 추가 인프라 의존성 없음. enum 1줄 + 데이터/리소스 복사 + 프리팹 에디터 작업만 필요.

---

## 3. TO 호출 대상 메서드 존재 확인

### 3.1 매니저 메서드

| 호출 메서드 | TO 위치 | 상태 |
|---|---|---|
| `UnitSkinManager.GetCurrentUnlockedRank(string)` | `Core/Managers/UnitSkinManager.cs` | ✅ |
| `UnitSkinManager.GetMaxRank(string)` | 동일 | ✅ |
| `UnitSkinManager.HasNextRank(string)` | 동일 | ✅ |
| `UnitSkinManager.TryGetUnlockCost(string, out ECurrencyType, out int)` | 동일 | ✅ |
| `UnitSkinManager.TryGetRankUpCosts(...)` | 동일 | ✅ |
| `UnitSkinManager.IsSkinUnlocked(...)` | 동일 | ✅ |
| `UnitSkinManager.GetSkinRank(string)` | 동일 | ✅ |
| `CurrencyManager.ModifyCurrency(ECurrencyType, int, ...)` | `Core/Managers/CurrencyManager.cs` | ✅ — 새 enum 자동 호환 |

→ **신규 호출 추가 불필요**. 데이터/리소스만 등록되면 매니저가 자동 인식.

### 3.2 UI 컴포넌트 메서드
해당 없음. 신규 UI 코드 sync 없음.

### 3.3 Show<T> UI 클래스 존재 확인
해당 없음. 기존 `UnitSkinPopupUI`, `UnitSkinDetailPopup` 활용.

### 3.4 partial class 내부 참조 메서드
해당 없음.

### 3.5 호출 그래프 역방향 추적 (Phase 2-E)

| 진입점 | FROM 호출자 수 | TO 동일 호출자 존재 | 처리 |
|---|---|---|---|
| `ECurrencyType.vessel_transcend_a` (CS 식별자) | 0 | 0 | enum 추가만 — 호출자 없음 |
| `costType1: 819` (BD) / `1285` (WD) (데이터) | 7건 (JSON 5 + .asset 1 + currency.asset 1) | 0 | 본 sync에서 모두 추가 |
| `vessel_transcend_a` (string 키) | UnitSkinManager `unitSkinId` 검색 | UnitSkinManager 자동 처리 | 데이터 등록 후 자동 |
| Localization 키 `vessel_transcend_a_name`, `icon_vessel_transcend_a`, `Profile_Icon_Name_58`(or 59) | 시트 자동 생성 | TO에 미존재 | 시트 PIC가 추가 |

> **결선 검증 결과**: CS publisher/subscriber 0건, 데이터-side는 sync 대상에 모두 포함. PARTIAL 누락 없음.

### 3.6 시그니처 축 변경 매핑
해당 없음 (enum 값만 변경 — 축 변경 아님).

---

## 4. TO에서 수정이 필요한 기존 파일

### 4.1 `ECurrencyType.cs` — enum 1줄 추가

**파일**: `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` (line 778~779)

**Before**:
```csharp
    /// <summary>
    /// 종족던전 재화
    /// </summary>
    RaceCurrency = 1283,

    dragoon_transcend_a = 1284,
}
```

**After**:
```csharp
    /// <summary>
    /// 종족던전 재화
    /// </summary>
    RaceCurrency = 1283,

    dragoon_transcend_a = 1284,
    vessel_transcend_a = 1285,
}
```

---

### 4.2 `UnitSkinData.json` — entry 5개 추가

**파일**: `Assets/Resources/JsonFiles/UnitSkinData.json` (line 1701~1702, 말미 `]}` 직전)

**Before** (현재 마지막 entry):
```json
  {
    "id": 30590,
    "unitSkinId": "dragoon_transcend_a",
    ...
    "costType1": 1284,
    "costType2": 1055,
    "animatorPath": "Prefabs/Skin/ChainLineVFX_Skin2"
  }
]}
```

**After**:
```json
  {
    "id": 30590,
    "unitSkinId": "dragoon_transcend_a",
    ...
    "costType1": 1284,
    "costType2": 1055,
    "animatorPath": "Prefabs/Skin/ChainLineVFX_Skin2"
  },
  {
    "id": 30591,
    "unitSkinId": "vessel_transcend_a",
    "targetUnit": 7,
    "skinRarity": 2,
    "skinRank": 1,
    "effectValue1": 20.0,
    "effectType2": 1,
    "effectValue2": 25.0,
    "skillDescription": "unit_skin_transcend_desc2",
    "skinSkillType": 2,
    "skillValue": 0.0,
    "cardID": 208121,
    "costType1": 1285,
    "costType2": 1055,
    "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
  },
  {
    "id": 30592,
    "unitSkinId": "vessel_transcend_a",
    "targetUnit": 7,
    "skinRarity": 2,
    "skinRank": 2,
    "effectValue1": 40.0,
    "effectType2": 1,
    "effectValue2": 50.0,
    "skillDescription": "unit_skin_transcend_desc",
    "skinSkillType": 2,
    "skillValue": 50.0,
    "cardID": 208121,
    "costType1": 1285,
    "costType2": 1055,
    "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
  },
  {
    "id": 30593,
    "unitSkinId": "vessel_transcend_a",
    "targetUnit": 7,
    "skinRarity": 2,
    "skinRank": 3,
    "effectValue1": 60.0,
    "effectType2": 1,
    "effectValue2": 75.0,
    "skillDescription": "unit_skin_transcend_desc",
    "skinSkillType": 2,
    "skillValue": 100.0,
    "cardID": 208121,
    "costType1": 1285,
    "costType2": 1055,
    "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
  },
  {
    "id": 30594,
    "unitSkinId": "vessel_transcend_a",
    "targetUnit": 7,
    "skinRarity": 2,
    "skinRank": 4,
    "effectValue1": 80.0,
    "effectType2": 1,
    "effectValue2": 100.0,
    "skillDescription": "unit_skin_transcend_desc",
    "skinSkillType": 2,
    "skillValue": 150.0,
    "cardID": 208121,
    "costType1": 1285,
    "costType2": 1055,
    "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
  },
  {
    "id": 30595,
    "unitSkinId": "vessel_transcend_a",
    "targetUnit": 7,
    "skinRarity": 2,
    "skinRank": 5,
    "effectValue1": 100.0,
    "effectType2": 1,
    "effectValue2": 125.0,
    "skillDescription": "unit_skin_transcend_desc",
    "skinSkillType": 2,
    "skillValue": 200.0,
    "cardID": 208121,
    "costType1": 1285,
    "costType2": 1055,
    "animatorPath": "Anim/IngameUnitSkin/Vessel_Anim_Skin2"
  }
]}
```

> ⚠️ `costAmount1`, `costAmount2` 필드 **제거됨** (WD 스키마 미보유, dragoon entry 비교 검증). `costType2`는 BD `374` → WD `1055`로 치환.

---

### 4.3 `CurrencyData.json` — entry 1개 추가

**파일**: `Assets/Resources/JsonFiles/CurrencyData.json` (말미 `]}` 직전)

**Before** (현재 마지막 entry):
```json
  {
    "currencyType": 1284,
    "currencyTypeS": "dragoon_transcend_a",
    "memo": "데 드라군",
    ...
  }
]}
```

**After**:
```json
  {
    "currencyType": 1284,
    "currencyTypeS": "dragoon_transcend_a",
    "memo": "데 드라군",
    ...
  },
  {
    "currencyType": 1285,
    "currencyTypeS": "vessel_transcend_a",
    "currencyName": "vessel_transcend_a_name",
    "iconScale": 1.0,
    "iconPath": "Sprites/Icon/icon_vessel_transcend_a",
    "rarity": 6,
    "description": "skin_desc_unit",
    "acquisitionPaths": ["route_event"],
    "acquisitionRouteTypes": ["Default"]
  }
]}
```

> ⚠️ `memo` 필드: BD 빈 값 → 본 sync에서는 생략. 시트 PIC가 한글 메모 추가 시 동기화 (예: `"memo": "데 베셀"`).

---

### 4.4 `ProfileIconData.json` — entry 1개 추가

**파일**: `Assets/Resources/JsonFiles/ProfileIconData.json` (말미 `]}` 직전)

**Before**:
```json
  {
    "iconIndex": 57,
    "order": 30,
    "iconNameKey": "Profile_Icon_Name_58",
    "iconPath": "Sprites/UI/Profile/Icons/icon_skin_marine_davyjones",
    "unlockCondition": 102,
    "unlockValueString": "marine_transcend_i",
    "unlockDescriptionKey": "icon_marine_transcend_i"
  }
]}
```

**After**:
```json
  {
    "iconIndex": 57,
    "order": 30,
    "iconNameKey": "Profile_Icon_Name_58",
    "iconPath": "Sprites/UI/Profile/Icons/icon_skin_marine_davyjones",
    "unlockCondition": 102,
    "unlockValueString": "marine_transcend_i",
    "unlockDescriptionKey": "icon_marine_transcend_i"
  },
  {
    "iconIndex": 58,
    "order": 50,
    "iconNameKey": "Profile_Icon_Name_58",
    "iconPath": "Sprites/Icon/icon_vessel_transcend_a",
    "unlockCondition": 101,
    "unlockValueString": "vessel_transcend_a",
    "unlockDescriptionKey": "icon_vessel_transcend_a"
  }
]}
```

> ⚠️ `iconNameKey`는 WD 컨벤션에 따라 `Profile_Icon_Name_58`로 적용 (BD는 `Profile_Icon_Name_59`). 시트 정책 확인 필요 — 시트 PIC가 BD 키 그대로 발급 시 본 패치도 `_59`로 수정.
> ⚠️ `order: 50` — 직전 entry 30과 비교 시 정렬 충돌 가능성 있음 (Phase 2 §I-4).

---

### 4.5 신규 .asset (5개 UnitSkin) — 파일 복사 + 필드 재매핑

**Before (BD `30591.asset`)** / **After (WD `30591.asset`)**:

```yaml
# BD 원본 (FROM)
m_Name: 30591
id: 30591
unitSkinId: vessel_transcend_a
...
costType1: 819
costAmount1: 1
costType2: 374
costAmount2: 1
animatorPath: Anim/IngameUnitSkin/Vessel_Anim_Skin2
```

```yaml
# WD 적용 (TO)
m_Name: 30591
id: 30591
unitSkinId: vessel_transcend_a
...
costType1: 1285
costType2: 1055
animatorPath: Anim/IngameUnitSkin/Vessel_Anim_Skin2
```

**변환 작업**:
1. BD `30591.asset` ~ `30595.asset` (+ `.meta`) 5쌍을 WD `Assets/Resources/ScriptableObjects/UnitSkinData/`에 그대로 복사
2. 각 파일에서:
   - `costType1: 819` → `1285` (sed/Edit)
   - `costType2: 374` → `1055`
   - `costAmount1: 1` 줄 **삭제**
   - `costAmount2: 1` 줄 **삭제**
   - 나머지(m_Name, id, m_Script guid 등) 그대로
3. `.meta`의 guid는 BD 것 그대로 (TO에 중복 없음 확인됨)

---

### 4.6 신규 .asset (Currency 1개) — rename + 필드 재매핑

**Before (BD `819.asset`)** / **After (WD `1285.asset`)**:

```yaml
# BD 원본 (파일명: 819.asset)
m_Name: 819
currencyType: 819
currencyTypeS: vessel_transcend_a
memo: 
...
```

```yaml
# WD 적용 (파일명: 1285.asset)
m_Name: 1285
currencyType: 1285
currencyTypeS: vessel_transcend_a
memo: 
...
```

**변환 작업**:
1. BD `CurrencyData/819.asset` (+ `.meta`)를 WD `Assets/Resources/ScriptableObjects/CurrencyData/1285.asset` (+ `.meta`)로 **rename 복사**
2. `m_Name: 819` → `1285`
3. `currencyType: 819` → `1285`
4. `m_Script` guid `bb74e6198ac5c5642b52405b5a150591` — WD 일치 (변경 불요)
5. 나머지 필드 그대로

---

### 4.7 신규 .asset (ProfileIcon 1개) — 복사 + m_Script guid 재매핑 ⚠️

**Before (BD `58.asset`)** / **After (WD `58.asset`)**:

```yaml
# BD 원본 (파일명: 58.asset)
m_Script: {fileID: 11500000, guid: 4bd52e65199d1bc46a19cccea1737ecf, type: 3}
m_Name: 58
iconIndex: 58
order: 50
iconNameKey: Profile_Icon_Name_59
iconPath: Sprites/Icon/icon_vessel_transcend_a
unlockCondition: 101
unlockValueString: vessel_transcend_a
unlockDescriptionKey: icon_vessel_transcend_a
```

```yaml
# WD 적용 (파일명: 58.asset)
m_Script: {fileID: 11500000, guid: 14ae038bb36d30c4b9548f59cf924a4c, type: 3}
m_Name: 58
iconIndex: 58
order: 50
iconNameKey: Profile_Icon_Name_58
iconPath: Sprites/Icon/icon_vessel_transcend_a
unlockCondition: 101
unlockValueString: vessel_transcend_a
unlockDescriptionKey: icon_vessel_transcend_a
```

**변환 작업**:
1. BD `ProfileIconData/58.asset` (+ `.meta`)를 WD `Assets/Resources/ScriptableObjects/ProfileIconData/58.asset` (+ `.meta`)로 복사
2. **`m_Script` guid `4bd52e65199d1bc46a19cccea1737ecf` → `14ae038bb36d30c4b9548f59cf924a4c`** (필수! WD ProfileIconDataSO와 결선)
3. `iconNameKey: Profile_Icon_Name_59` → `Profile_Icon_Name_58` (WD 컨벤션)
4. 나머지 필드 그대로

---

### 4.8 Prefab 편집 (Unity 에디터 — 텍스트 머지 금지)

**파일**:
- `Assets/_Project/3_Prefabs/Units/Vessel/MovingVesselController.prefab`
- `Assets/_Project/3_Prefabs/Units/Vessel/SmallVesselController.prefab`

**작업 절차** (각 prefab):
1. Unity 에디터에서 prefab 오픈 (Prefab Mode)
2. 기존 vessel_mythic_a용 VFX object 옆에 `VFX_Vessel_Loop_New.prefab` (guid `df592532ade415141adad6103120bf6e`)를 nested prefab instance로 추가
3. 베셀 루트 GameObject의 `VesselSkinVisual` 컴포넌트 → `_skinVisuals` 리스트에 새 entry 추가:
   - `skinId`: `vessel_transcend_a`
   - `visualObject`: 위 2번에서 생성한 nested prefab instance
4. Save (Ctrl+S)

> ⚠️ **텍스트 yaml 머지 금지**: prefab 파일은 fileID 충돌·instance 생성 매핑이 복잡하여 자동 머지 시 깨질 위험 큼 (Phase 2 §G-8, §I-6).

---

## 5. sync 체크리스트

### 공통 (가이드 문서 섹션 3)

- [x] `ECurrencyType.cs` — `vessel_transcend_a = 1285` 추가 (line 779)
- [x] `SaveDataTypes.cs` / `SaveDataManager.cs` — **변경 없음** (enum 자동 통합)
- [x] `Managers.cs` — **변경 없음** (Phase 2 검증 완료)
- [x] `link.xml` — **불필요** (enum 추가, IL2CPP stripping 위험 없음)

### 신규 파일 생성 (복사 + 필요 시 rename/필드 수정)

- [x] `Assets/Resources/ScriptableObjects/UnitSkinData/30591.asset` + `.meta` (필드 변환)
- [x] `Assets/Resources/ScriptableObjects/UnitSkinData/30592.asset` + `.meta` (필드 변환)
- [x] `Assets/Resources/ScriptableObjects/UnitSkinData/30593.asset` + `.meta` (필드 변환)
- [x] `Assets/Resources/ScriptableObjects/UnitSkinData/30594.asset` + `.meta` (필드 변환)
- [x] `Assets/Resources/ScriptableObjects/UnitSkinData/30595.asset` + `.meta` (필드 변환)
- [x] `Assets/Resources/ScriptableObjects/CurrencyData/1285.asset` + `.meta` (BD 819.asset rename + 필드 변환)
- [x] `Assets/Resources/ScriptableObjects/ProfileIconData/58.asset` + `.meta` (**m_Script guid 재매핑 필수** + iconNameKey 변경)
- [x] `Assets/Resources_moved/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` + `.meta`
- [x] `Assets/_Project/4_Animations/Vessel/Vessel_Attack_Skin2.anim` + `.meta`
- [x] `Assets/_Project/4_Animations/Vessel/Vessel_Charge_Idle_Skin2.anim` + `.meta`
- [x] `Assets/_Project/4_Animations/Vessel/Vessel_Charge_Skin2.anim` + `.meta`
- [x] `Assets/_Project/4_Animations/Vessel/Vessel_Idle_Skin2.anim` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_effect_06_vessel.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_effect_vessel_energy.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_attack1.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charge.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger1.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger2.png` + `.meta`
- [x] `Assets/_Project/6_Textures/Units/Vessel/special skin_unit_06_vessel_charger3.png` + `.meta`
- [x] `Assets/Resources_moved/Sprites/Icon/icon_vessel_transcend_a.png` + `.meta`
- [x] `Assets/Resources_moved/Sprites/Icon/item_vessel_transcend_a.png` + `.meta`
- [x] `Assets/Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/vessel_transcend_a.png` + `.meta`
- [x] `Assets/Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/vessel_transcend_a_full.png` + `.meta`
- [x] `Assets/Resources_moved/Sprites/Skin/Unit/vessel_transcend_a.meta` (폴더 meta)

(합계: 신규 파일 47개 = 데이터 .asset 14 + 애니메이션 10 + 텍스처 14 + 아이콘/폴더 9)

### 기존 파일 수정

- [x] `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` — `vessel_transcend_a = 1285,` 1줄 추가
- [x] `Assets/Resources/JsonFiles/UnitSkinData.json` — entry 5개 추가 (id 30591~30595, costType1=1285, costType2=1055, costAmount 필드 없음)
- [x] `Assets/Resources/JsonFiles/CurrencyData.json` — entry 1개 추가 (currencyType 1285)
- [x] `Assets/Resources/JsonFiles/ProfileIconData.json` — entry 1개 추가 (iconIndex 58, iconNameKey `Profile_Icon_Name_58`)
- [ ] `Assets/_Project/3_Prefabs/Units/Vessel/MovingVesselController.prefab` — Unity 에디터에서 `_skinVisuals` 수정 🟧
- [ ] `Assets/_Project/3_Prefabs/Units/Vessel/SmallVesselController.prefab` — Unity 에디터에서 `_skinVisuals` 수정 🟧

### 시트(DataSheet) PIC 안내 — **이 sync 작업의 ground truth**

- [ ] **UnitSkinData 시트**: vessel_transcend_a rank1~5 행 추가 (id 30591~30595, costType1=1285, costType2=1055)
- [ ] **CurrencyData 시트**: currencyType 1285 행 추가 (currencyTypeS=vessel_transcend_a, memo 한글, 기타 필드)
- [ ] **ProfileIconData 시트**: iconIndex 58 행 추가 (iconNameKey 정책 결정 — `Profile_Icon_Name_58` 권장)
- [ ] **LocalizationTables 시트**: `vessel_transcend_a_name`, `icon_vessel_transcend_a`, `Profile_Icon_Name_58` 번역 추가
- [ ] 시트 갱신 후 DataSheet SO 자동 생성 빌드 실행 → 본 sync의 직접 패치(`.asset`) 덮어쓰기 됨 (정상)

### PARTIAL 파일 처리

- [x] `UnitSkinData.json` — `costAmount1`, `costAmount2` 필드 제거 처리 완료 확인
- [x] `UnitSkinData.json` / `*.asset` — `costType2: 374` → `1055` 치환 완료 확인
- [x] `ProfileIconData/58.asset` — `m_Script guid` `14ae038bb36d30c4b9548f59cf924a4c`로 재매핑 확인
- [ ] `MovingVesselController.prefab` / `SmallVesselController.prefab` — Unity 에디터 작업 완료 🟧

### sync 후 검증

- [ ] **컴파일 에러 없음** — Unity 에디터에서 0 errors
- [ ] `ECurrencyType.vessel_transcend_a` 값이 `1285`로 인식되는지 (Inspector 또는 Cheat)
- [ ] `UnitSkinData` 30591~30595 SO가 Inspector에서 정상 로드되며 `m_Script` 누락(Missing) 없음
- [ ] `CurrencyData` 1285.asset Inspector 정상
- [ ] `ProfileIconData` 58.asset Inspector 정상 (m_Script binding 정상)
- [ ] 인게임에서 `vessel_transcend_a` 스킨 장착 시 외형 변경 확인 (프리팹 편집 검증)
- [ ] 애니메이션 sprite 누락(핑크) 없음 (특수 텍스처 7개 검증)
- [ ] 저장 → 재시작 → 로드 정상 (재화/스킨 상태 보존)
- [ ] BD와 동일 시나리오 동작 확인

---

## 6. 이 시스템 특유의 주의사항

### 6.1 [HIGH] 특수 텍스처 7개 누락 시 sprite 깨짐
`Vessel_*_Skin2.anim` 4개가 `special skin_*` 텍스처들의 sprite GUID에 hard-bind. 누락 시 인게임에서 핑크 sprite 또는 누락 sprite 표시.
파일명에 공백 포함(`"special skin_*"`) → 복사 스크립트에서 인용 필수.

### 6.2 [HIGH] Prefab 편집은 Unity 에디터 필수
`MovingVesselController.prefab`, `SmallVesselController.prefab` 양쪽에 vessel_transcend_a 시각 객체 추가. nested prefab instance 생성 + fileID 매핑 → 텍스트 머지 위험.
누락 시: 스킨 장착해도 외형 변경 없음(기본 외형 유지). 본 sync의 가장 큰 수동 작업.

### 6.3 [HIGH] ProfileIconData/58.asset `m_Script` GUID 재매핑 필수
BD `4bd52e65199d1bc46a19cccea1737ecf` ≠ WD `14ae038bb36d30c4b9548f59cf924a4c`. 그대로 복사 시 ProfileIconDataSO binding이 깨져 Missing Script로 표시됨.
UnitSkinDataSO / CurrencyDataSO는 양 프로젝트 GUID 일치 — ProfileIconDataSO만 다름.

### 6.4 [HIGH] effectType2 BD↔WD 추론 불가
WD vessel_mythic_a는 `effectType2: 0`. WD 타 transcend 스킨들은 unit별로 0/1/2/3/4 다양. BD vessel_transcend_a는 `1`.
본 sync는 BD 값(`1`) 유지하지만 게임 디자이너 검수 권장. 시트 동기화 시 vessel_transcend_a 행의 effectType2 컬럼 명시 확인 필요.

### 6.5 [MEDIUM] costType2 BD 374 → WD 1055
WD 전 transcend 스킨은 `costType2: 1055` 통일. BD는 `374` (BD 내부 토큰 재화 — VesselKit 추정, 미확인). WD 컨벤션 강제 적용.

### 6.6 [MEDIUM] ProfileIconData order 충돌 가능성
WD 직전 entry `iconIndex: 57, order: 30` vs BD vessel `iconIndex: 58, order: 50` — order 점프 발생. 정렬 정책상 충돌 가능. 시트 PIC가 정책 결정.

### 6.7 [MEDIUM] iconNameKey off-by-1 (BD 패턴 ≠ WD 패턴)
WD 컨벤션: `iconIndex N` → `iconNameKey: Profile_Icon_Name_N+1` (예: WD 57 → `Profile_Icon_Name_58`). BD vessel은 `iconIndex 58` → `Profile_Icon_Name_59`로 WD 패턴과 다름.
본 sync는 WD 일관성을 위해 `Profile_Icon_Name_58` 적용. 시트 PIC가 BD 키 그대로 발급 시 본 패치도 수정.

### 6.8 [LOW] `item_vessel_transcend_a.png` 사용처 미확인
BD에서 직접 참조 미발견. 시트(상점/아이템 카드)에서 참조 가능성 → GUID 보존 복사로 안전 처리.

### 6.9 [CRITICAL] DataSheet SO `*.cs` 직접 수정 금지 (CLAUDE.md 규칙)
- `Assets/_Project/1_Scripts/SOs/SO/DataSheet/*.cs` 및 `Assets/_Project/1_Scripts/SOs/Class/DataSheet/*` 자동 생성 파일은 절대 수정하지 말 것.
- 본 sync는 `.asset`(데이터)·JSON·CS enum만 직접 수정. 시트 PIC가 시트에 행 추가 → 다음 자동 생성 빌드 시 자동 동기화.
- **시트 PIC가 ground truth**이며 본 sync의 직접 반영은 임시 패치.

### 6.10 [INFO] ID 매핑 요약
- BD `ECurrencyType.vessel_transcend_a = 819` → WD `1285` (전역 +466, 다음 sync는 1286부터)
- BD/WD 모두 `UnitSkinData id 30591~30595`로 일치 (재할당 불요 — dragoon 플랜과 차이)
- BD/WD 모두 `ProfileIcon iconIndex 58`로 일치 (재할당 불요)
- enum 값 1285는 일회용. 다음 transcend 통화는 1286.

---

## 7. diff 비교 전략

### 7.1 신규 생성 파일 diff 확인 명령어

```bash
# Asset diff (필드 변환 검증)
FROM="C:/Users/JuwonCha/AppData/Local/Temp/sync_vessel_transcend_a_20260603_231737"
TO="C:/JuwonCha/WriggleDefender"

# UnitSkin SO 비교 (예: 30591)
diff "$FROM/Assets/Resources/ScriptableObjects/UnitSkinData/30591.asset" \
     "$TO/Assets/Resources/ScriptableObjects/UnitSkinData/30591.asset"

# Currency SO 비교 (rename 됐으므로 비교는 819 vs 1285)
diff "$FROM/Assets/Resources/ScriptableObjects/CurrencyData/819.asset" \
     "$TO/Assets/Resources/ScriptableObjects/CurrencyData/1285.asset"

# ProfileIcon SO 비교 (GUID 재매핑 검증)
diff "$FROM/Assets/Resources/ScriptableObjects/ProfileIconData/58.asset" \
     "$TO/Assets/Resources/ScriptableObjects/ProfileIconData/58.asset"

# 애니메이션·텍스처는 바이너리 — md5sum 비교
md5sum "$FROM/Assets/Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller" \
       "$TO/Assets/Resources_moved/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller"

# JSON git diff (TO만)
git -C "$TO" diff Assets/Resources/JsonFiles/UnitSkinData.json
git -C "$TO" diff Assets/Resources/JsonFiles/CurrencyData.json
git -C "$TO" diff Assets/Resources/JsonFiles/ProfileIconData.json

# CS enum git diff
git -C "$TO" diff Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs
```

### 7.2 예상 diff 노이즈

| 파일 | 적용 규칙 | 예상 diff |
|---|---|---|
| `ECurrencyType.cs` | enum 1줄 추가 | +1줄 |
| `UnitSkinData.json` | entry 5개 추가 (각 14줄) + 직전 entry 말미 `}` → `},` | +71줄 / -1줄 |
| `CurrencyData.json` | entry 1개 추가 (10줄) + 직전 `}` → `},` | +11줄 / -1줄 |
| `ProfileIconData.json` | entry 1개 추가 (9줄) + 직전 `}` → `},` | +10줄 / -1줄 |
| `UnitSkinData/30591.asset` ~ `30595.asset` | costType1/2 변환 + costAmount1/2 삭제 | 각 -2줄 / +0줄, 값 변경 2줄 |
| `CurrencyData/1285.asset` vs `819.asset` | m_Name, currencyType 변경 | 2줄 변경 |
| `ProfileIconData/58.asset` | m_Script guid + iconNameKey 변경 | 2줄 변경 |
| `Vessel_Anim_Skin2.controller` (+anim, +texture, +icon, +sprite) | 바이너리 신규 | git status: untracked → added |
| `Moving/SmallVesselController.prefab` | nested prefab instance 추가 + `_skinVisuals` entry | 수십 줄 (Unity 에디터 자동 생성) |

> 예상 diff 외의 변경이 발생하면 sync 오류로 간주.

---

## 8. 프리팹 패키징 목록

> **작성 시점**: Phase 4 완료 후 채워질 섹션. 현재는 생략 — 본 sync는 신규 UI 프리팹 없음.

### 8.1 패키지화할 프리팹 목록
- 해당 없음 (신규 UI 프리팹 없음. 기존 `MovingVesselController.prefab` / `SmallVesselController.prefab` 편집만)

### 8.2 SerializeField 연결 목록
| 프리팹 | 필드명 | 타입 | 배열 크기 | 주의사항 |
|---|---|---|---|---|
| `MovingVesselController.prefab` | `VesselSkinVisual._skinVisuals` | `List<SkinVisualEntry>` | 기존 +1 entry | `skinId: vessel_transcend_a`, `visualObject: <VFX_Vessel_Loop_New 인스턴스>` |
| `SmallVesselController.prefab` | 동일 | 동일 | 동일 | 동일 |

### 8.3 Show<T> 외부 UI 참조 확인
- 해당 없음 (UI 변경 없음)

### 8.4 임포트 후 UIManager 등록 필요 목록
- 해당 없음
