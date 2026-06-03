# Phase 2 결과 — vessel_transcend_a

생성일: 2026-06-03
FROM: `C:/Users/JuwonCha/AppData/Local/Temp/sync_vessel_transcend_a_20260603_231737` (BunkerDefense, BD)
TO:   `C:/JuwonCha/WriggleDefender` (WriggleDefender, WD)
SYSTEM: vessel_transcend_a (UnitSkin × Vessel × Transcend)
KEYS:  `UnitSkin`, `VesselTranscend`, `vessel_transcend_a`
참고: `2026-05-13_UnitSkin_dragoon_transcend_a/UnitSkin_dragoon_transcend_a_SYNC_PLAN.md` (변환 패턴 참고)

---

## A. 파일별 상세 분석

### A-1. `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` — **DIRECT (1줄 추가)**

- FROM: `vessel_transcend_a = 819` (line 784, dragoon=726 / RaceCurrency=1071 사이)
- TO: 미존재. WD 마지막 값 `RaceCurrency = 1283` → `dragoon_transcend_a = 1284` 다음.
- **결정**: WD에 `vessel_transcend_a = 1285` 추가 (line 779 위치).
- enum 값 BD 819 → WD 1285 재매핑. 호출 그래프상 CS 코드에서 enum을 식별자로 참조하는 곳은 없음 (§E 참조).

### A-2. `VesselController.cs`, `VesselController.SkinSkill.cs` — **변경 없음 (재확인)**

- FROM/TO 모두 존재. `vessel_transcend_a` 리터럴 미포함. WD는 이미 WD 아키텍처(`Managers.Instance.GetManager<>`) 사용.
- Phase 1 결론 그대로 유지.

### A-3. `Assets/Resources/JsonFiles/UnitSkinData.json` — **PARTIAL (값 변환 필요)**

- FROM에 vessel_transcend_a rank1~5 (id 30591~30595) 존재. TO 없음.
- WD JSON 마지막 ID = 30590 (`dragoon_transcend_a` rank5). 30591~30595 슬롯이 빈 상태 → **ID 그대로 사용 가능**.
- ID 충돌 위험: 없음 (dragoon 플랜과 다른 점).
- **변환 규칙 (BD → WD)**:
  - `costType1`: `819` → `1285`
  - `costType2`: `374` → `1055` (WD 전 transcend 스킨 공통값. BD 374는 WD 컨벤션과 불일치)
  - `costAmount1`, `costAmount2`: WD JSON 스키마에 두 필드가 없음 → **삭제** (예: dragoon_transcend_a WD entry 참고)
  - `animatorPath`: `Anim/IngameUnitSkin/Vessel_Anim_Skin2` 유지 (vessel_mythic_a가 `Vessel_Anim_Skin` 사용 → Skin2도 같은 위치)
  - `effectType2`: `1` 유지 (단, WD vessel_mythic_a는 `0`. BD 값과 다르므로 **추정 불가**, BD 값 유지 권장)
- 시트 자동 생성(`SOs/SO/DataSheet/UnitSkinDataSO.cs`)이지만, JSON 자체는 데이터 파일이라 직접 갱신 가능.

### A-4. `Assets/Resources/JsonFiles/CurrencyData.json` — **DIRECT (값 변환)**

- FROM line 10900~10914에 vessel_transcend_a 엔트리 (`currencyType: 819`).
- TO 미존재. 마지막 entry = `dragoon_transcend_a` (`currencyType: 1284`).
- **변환**: `currencyType: 819` → `1285`. 나머지 필드 그대로.
  - `currencyTypeS: vessel_transcend_a`
  - `currencyName: vessel_transcend_a_name`
  - `iconPath: Sprites/Icon/icon_vessel_transcend_a`
  - `rarity: 6`, `description: skin_desc_unit`, `acquisitionPaths: [route_event]`
- BD에는 `memo` 필드 없음(빈 값). WD dragoon은 `memo: "데 드라군"` 보유 → 시트에서 한글 메모 추가 시 동기화 필요(시트 PIC 작업).

### A-5. `Assets/Resources/JsonFiles/ProfileIconData.json` — **ADAPTED (iconIndex 재할당)**

- FROM line 525~533:
  ```json
  { "iconIndex": 58, "order": 50, "iconNameKey": "Profile_Icon_Name_59",
    "iconPath": "Sprites/Icon/icon_vessel_transcend_a", "unlockCondition": 101,
    "unlockValueString": "vessel_transcend_a", "unlockDescriptionKey": "icon_vessel_transcend_a" }
  ```
- TO 마지막 entry: `iconIndex: 57, order: 30, iconNameKey: "Profile_Icon_Name_58", unlockValueString: "marine_transcend_i"`.
- WD에 `iconIndex: 58` 슬롯이 빈 상태(BD ProfileIconData.json의 iconIndex=58 vessel ↔ WD 동일 슬롯 미사용) → **iconIndex 58 그대로 사용 가능**.
- `iconNameKey: Profile_Icon_Name_59`는 WD 컨벤션상 iconIndex+1 패턴(WD dragoon=54 + Name_54, BD vessel=58 + Name_59 = BD-side off-by-1) → **WD에서는 `Profile_Icon_Name_58`로 맞추는 것이 일관성에 부합** (단, 시트가 BD 키 그대로 발급할 수 있어 시트 동기화 시 결정).
- ⚠️ 이전 entry(iconIndex 57, marine_transcend_i)는 `order: 30`. WD에서 `order: 50`은 정렬 충돌 가능 → 시트에서 order 정책 확인 필요. **dragoon 플랜에는 없던 신규 카테고리** (보고서 §주의사항 참조).

### A-6. `Assets/Resources/ScriptableObjects/CurrencyData/819.asset` — **ADAPTED (이름·필드 재매핑)**

- FROM: `m_Name: 819`, `currencyType: 819`.
- TO 미존재.
- **변환**: 파일명 `819.asset` → `1285.asset`. 내부 `m_Name: 1285`, `currencyType: 1285`. 나머지 필드(YAML guid `bb74e6...`, currencyTypeS, iconPath 등) 그대로.

### A-7. `Assets/Resources/ScriptableObjects/UnitSkinData/30591~30595.asset` — **ADAPTED (필드 재매핑)**

- FROM: 5개 .asset 존재 (id 30591~30595).
- TO: 마지막 30590 (dragoon_transcend_a rank5). 30591~30595 슬롯 빈 상태 → **파일명 그대로 복사 가능** (ID 재할당 불필요).
- **변환 규칙** (각 asset 내부):
  - `costType1: 819` → `1285`
  - `costType2: 374` → `1055` (WD 컨벤션)
  - `costAmount1`, `costAmount2` 필드 **삭제** (WD 스키마 미보유. dragoon WD .asset 비교)
  - `animatorPath: Anim/IngameUnitSkin/Vessel_Anim_Skin2` 그대로
  - `effectType2: 1` BD 값 유지 (WD 추론 불가)
- BD `m_Script guid`(`7049d4123a48b4a1bb19a9a90842d29c`)는 WD `UnitSkinDataSO`의 GUID와 동일 → 안전.

### A-8. `Assets/Resources/ScriptableObjects/ProfileIconData/58.asset` — **ADAPTED**

- FROM: `iconIndex: 58`, `order: 50`, `iconNameKey: Profile_Icon_Name_59`.
- TO 마지막 = `57.asset`. 58.asset 슬롯 빈 상태 → **파일명 `58.asset` 그대로 사용**.
- 내부 필드는 §A-5 결정 반영 (iconNameKey 정책 결정 필요).
- `m_Script guid 4bd52e65199d1bc46a19cccea1737ecf` 확인 필요(TO ProfileIconDataSO와 일치하는지). WD `54.asset`도 동일 GUID 사용 → 일치 확인.

### A-9. `Assets/Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` — **DIRECT (복사)**

- FROM 존재 (`/Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller`, guid `5549fbd8b125be543acd5100e9b0dd76`).
- TO 미존재. WD에는 `Vessel_Anim_Skin.controller`(guid `bab2744bd034cfb4da9589540f8493ed`, `Resources_moved/Anim/IngameUnitSkin/`) 만 존재.
- **복사 대상 경로**: WD `Assets/Resources_moved/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller`(+.meta).
- controller가 참조하는 모션 GUID 4종 → §데이터/에셋 인벤토리 참조 (의존 anim 4개 동반 복사).

### A-10. `Assets/Resources/Sprites/Icon/icon_vessel_transcend_a.png` — **DIRECT (복사)**

- FROM: 존재 (guid `81502f37c101142c28e1995a31ce51d1`).
- TO 미존재. WD에 `icon_dragoon_transcend_a.png`는 있으므로 동일 경로 사용 가능.
- **복사 대상**: WD `Assets/Resources_moved/Sprites/Icon/icon_vessel_transcend_a.png`(+.meta).

### A-11. `Assets/Resources/Sprites/Icon/item_vessel_transcend_a.png` — **ADAPTED (옵션 / dragoon 플랜 외)**

- FROM: 존재 (guid `e6d7bb6e9deca4b20af821472970c8d1`).
- TO 미존재. WD에 `item_dragoon_transcend_a.png`도 없음(dragoon 플랜이 누락한 항목).
- FROM 내부에서도 메타 외 다른 곳 참조 없음 → **현재 데이터로는 사용처 추적 불가**. 시트(상점/UI 카드)에서 참조될 가능성 있음.
- **권장**: 안전을 위해 함께 복사. 사용처 미확인 시에도 GUID 보존하면 시트 결과와 자연 연결.

### A-12. `Assets/Resources/Sprites/Skin/Unit/vessel_transcend_a/` 폴더 — **DIRECT (복사)**

- FROM: 폴더 안에 `vessel_transcend_a.png`(132KB 추정), `vessel_transcend_a_full.png`, 각 `.meta` + 폴더 `.meta`.
- TO 미존재.
- **복사 대상**: WD `Assets/Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/` 전체.

---

## B. FROM 전용 패턴 표

| 패턴 | FROM 위치 | WD 적용 가능 | 비고 |
|---|---|---|---|
| `ECurrencyType.vessel_transcend_a = 819` | ECurrencyType.cs:784 | enum 1줄 추가 (=1285) | DIRECT |
| `costAmount1`, `costAmount2` 필드 | UnitSkinData JSON/SO | **제거** | WD 스키마에 없음 |
| `costType2: 374` (BD 토큰류 재화) | UnitSkinData JSON/SO | `1055`로 치환 | WD transcend 공통값 |
| `Anim/IngameUnitSkin/Vessel_Anim_Skin2` | animatorPath | **그대로 사용** | vessel_mythic_a의 `Vessel_Anim_Skin` 패턴과 동일 위치 |
| 서비스 레이어 호출 (`_objectPoolService` 등) | VesselController.SkinSkill.cs | 적용 불필요 (WD가 이미 WD-style) | 변경 없음 |
| `iconNameKey: Profile_Icon_Name_59` (off-by-1) | ProfileIconData.json/58.asset | `Profile_Icon_Name_58` 후보 | 시트 정책 확인 필요 |
| `memo` 한글 텍스트 (CurrencyData) | BD엔 미존재 / WD 컨벤션 있음 | 시트 PIC 작업 | sync 범위 외 |

---

## C. 의존성 확인 (매니저·UI·Show<T>)

### C-1. 매니저 메서드 (UnitSkinManager 등)
- WD `UnitSkinManager`: `GetCurrentUnlockedRank(string)`, `GetMaxRank(string)`, `HasNextRank(string)`, `TryGetUnlockCost(string, out ECurrencyType, out int)`, `TryGetRankUpCosts(...)`, `IsSkinUnlocked(string|int)`, `GetSkinRank(string)`, `GetNextSkinData(string)` 등 모두 `unitSkinId: string`을 키로 사용.
- 신규 스킨 추가 시 추가 메서드 호출 없음. 데이터/리소스만 등록되면 자동 동작.

### C-2. UI 컴포넌트 메서드
- UnitSkinDetailPopup / UnitSkinPopupUI / SkinSelectionSimpleItemUI: 데이터 SO를 통한 일반 표시. per-skin 코드 없음.

### C-3. `uiManager.Show<T>()` 대상
- vessel_transcend_a 관련 신규 UI 클래스 없음. 기존 UnitSkinPopupUI/UnitSkinDetailPopup 활용.

**결론**: 의존성 추가 불필요.

---

## D. 인프라 초기화 비교

- SaveDataManager / SaveDataTypes / JsonSerializer / Managers.cs 변경 불요. enum 추가만으로 새 통화가 SaveData currency 딕셔너리에 자동 포함됨 (`ECurrencyType` 키 사용).
- ManagerFactory 변경 불요.

**결론**: 인프라 무변경.

---

## E. 호출 그래프 역방향 추적

### E-1. CS 코드 직접 참조
- `grep "ECurrencyType\.vessel_transcend_a"`: FROM에서 **0건** (ECurrencyType.cs 정의 외).
- `grep "vessel_transcend_a"` (전체): CS는 ECurrencyType.cs만. 나머지는 JSON/asset/prefab/Localization.
- 따라서 CS 코드 호출자/참조자는 없음. enum은 **데이터(JSON/asset)에서 숫자값으로만 참조**됨.

### E-2. 데이터 측 참조
- BD `costType1: 819` 사용처: UnitSkinData.json (5건), CurrencyData.json (1건), CurrencyData/819.asset (1건). 모두 sync 대상.
- WD에 동일 패턴: dragoon (`costType1: 1284`) 이미 정상 동작 → vessel(1285)도 enum 추가하면 그대로 연결.

### E-3. 프리팹 측 참조
- BD `MovingVesselController.prefab`, `SmallVesselController.prefab`의 `_skinVisuals` 리스트에 `skinId: vessel_transcend_a` 엔트리 추가됨.
  - 각 entry의 `visualObject`는 BD가 prefab 안에 추가한 `VFX_Vessel_Loop_New.prefab` instance (guid `df592532ade415141adad6103120bf6e`)를 가리킴.
  - WD에도 동일 GUID로 `VFX_Vessel_Loop_New.prefab` 존재 → WD prefab에도 동일 instance를 nested prefab으로 추가하고 `_skinVisuals`에 `skinId: vessel_transcend_a` + visualObject fileID 연결 필요.
  - **위험**: prefab 편집(Unity 에디터 작업)이 필요. 텍스트 머지로는 불완전.

---

## F. 결선 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| ECurrencyType enum 추가 1건 (=1285) | ✅ | DIRECT |
| 데이터 JSON 3건 갱신 (UnitSkin + Currency + ProfileIcon) | ✅ | PARTIAL/ADAPTED |
| SO asset 7건 신규 복사 (UnitSkin×5 + Currency×1 + ProfileIcon×1) | ✅ | ADAPTED |
| 애니메이션 controller 1건 + 의존 anim 4건 복사 | ✅ | DIRECT |
| 텍스처 7건 (special skin_*) 복사 | ✅ | DIRECT (신규 발견) |
| 아이콘 png 2건 (icon, item) 복사 | ✅ | DIRECT |
| 스프라이트 폴더 (`vessel_transcend_a/`) 복사 | ✅ | DIRECT |
| UnitSkinResourceConfig.asset 편집 | ❌ 불필요 | BD/TO 모두 vessel 엔트리 없음. vessel_mythic_a도 미등록 → 동일 정책 |
| 프리팹 편집 (Moving/SmallVesselController) | ⚠️ | Unity 에디터 작업 필요 |
| 로컬라이제이션 키 추가 | ⚠️ | 시트 PIC 작업 (CLAUDE.md 규칙) |
| DataSheet SO 자동 생성 파일 직접 수정 | ❌ 금지 | CLAUDE.md 규칙 |

---

## G. 데이터·에셋 인벤토리 (Phase 3 patch용 정확 경로)

### G-1. CS 1건
- `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` — `RaceCurrency = 1283`, `dragoon_transcend_a = 1284` 다음에 `vessel_transcend_a = 1285,` 추가 (line ~779).

### G-2. JSON 3건 (`Assets/Resources/JsonFiles/`)
- `CurrencyData.json` — 말미 `]}` 직전에 vessel entry 1개 추가 (currencyType 1285).
- `UnitSkinData.json` — 말미에 vessel rank1~5 (id 30591~30595) 5개 추가.
- `ProfileIconData.json` — 말미 `]}` 직전에 vessel profile icon 1개 추가 (iconIndex 58).

### G-3. ScriptableObject .asset 7건 (`Assets/Resources/ScriptableObjects/`)
| BD 원본 | WD 생성 | 내부 ID 변환 |
|---|---|---|
| `UnitSkinData/30591.asset` | `UnitSkinData/30591.asset` | id 불변 / costType1 819→1285, costType2 374→1055, costAmount 필드 삭제 |
| `UnitSkinData/30592.asset` | `UnitSkinData/30592.asset` | 동일 |
| `UnitSkinData/30593.asset` | `UnitSkinData/30593.asset` | 동일 |
| `UnitSkinData/30594.asset` | `UnitSkinData/30594.asset` | 동일 |
| `UnitSkinData/30595.asset` | `UnitSkinData/30595.asset` | 동일 |
| `CurrencyData/819.asset` | `CurrencyData/1285.asset` | m_Name 819→1285, currencyType 819→1285 |
| `ProfileIconData/58.asset` | `ProfileIconData/58.asset` | iconNameKey 정책 결정 필요 (Profile_Icon_Name_58 vs 59) |

각 `.meta` 파일도 동반. BD GUID는 그대로 보존(TO에 중복 없음 확인됨).

### G-4. 애니메이션 (5건 + meta) — `Assets/Resources_moved/Anim/IngameUnitSkin/` (Resources_moved 경로 사용)
| 파일 | FROM 경로 | TO 경로 |
|---|---|---|
| `Vessel_Anim_Skin2.controller` | `Resources/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` | `Resources_moved/Anim/IngameUnitSkin/Vessel_Anim_Skin2.controller` |
| `.meta` (guid `5549fbd8b125be543acd5100e9b0dd76`) | 동일 | 동일 |

⚠️ controller가 참조하는 anim 4건 — `_Project/4_Animations/Vessel/`:
| 파일 |
|---|
| `Vessel_Attack_Skin2.anim` (+.meta) |
| `Vessel_Charge_Idle_Skin2.anim` (+.meta) |
| `Vessel_Charge_Skin2.anim` (+.meta) |
| `Vessel_Idle_Skin2.anim` (+.meta) |

→ FROM `Assets/_Project/4_Animations/Vessel/Vessel_*_Skin2.anim` 4개 모두 TO 동일 경로에 복사.

### G-5. 텍스처 (7건 + meta) — `Assets/_Project/6_Textures/Units/Vessel/`
**신규 발견 (dragoon 플랜에 없던 항목)**: Vessel_*_Skin2.anim들이 다음 sprite GUID들을 참조하며, 이 sprite들은 다음 텍스처 파일들에 포함됨:
| 파일 |
|---|
| `special skin_effect_06_vessel.png` (+.meta) |
| `special skin_effect_vessel_energy.png` (+.meta) |
| `special skin_unit_06_vessel_attack1.png` (+.meta) |
| `special skin_unit_06_vessel_charge.png` (+.meta) |
| `special skin_unit_06_vessel_charger1.png` (+.meta) |
| `special skin_unit_06_vessel_charger2.png` (+.meta) |
| `special skin_unit_06_vessel_charger3.png` (+.meta) |

→ FROM `_Project/6_Textures/Units/Vessel/special skin_*` 7개 모두 TO 동일 경로에 복사 (파일명에 공백 포함, 인용 주의).
※ Vessel_Idle_Skin2.anim에서 직접 확인된 GUID 4종(04043b24…, 48d5f7b5…, 67102c1a…, 829aa02a…) 중 04043b24…가 `special skin_unit_06_vessel_charger3.png.meta`에 매핑됨을 grep으로 확인. 나머지는 동일 폴더 내 다른 special skin_* 파일에 분산됨(전수 매핑 비검증, but 동반 복사로 안전).

### G-6. 아이콘 PNG (2건 + meta) — `Assets/Resources_moved/Sprites/Icon/`
| 파일 | FROM | TO |
|---|---|---|
| `icon_vessel_transcend_a.png` (guid `81502f37c101142c28e1995a31ce51d1`) | `Resources/Sprites/Icon/` | `Resources_moved/Sprites/Icon/` |
| `item_vessel_transcend_a.png` (guid `e6d7bb6e9deca4b20af821472970c8d1`) | 동일 | 동일 |

⚠️ `item_vessel_transcend_a.png`는 FROM에서 사용처 미발견. **dragoon 플랜에 없던 항목**. 안전상 함께 복사 권장(시트에 참조 추가 가능성).

### G-7. 유닛 스프라이트 폴더 — `Assets/Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/`
| 파일 |
|---|
| `vessel_transcend_a.png` (guid `eb4d5158d360b4e909a9c6cd4e166d2a`, 단일 sprite) + `.meta` |
| `vessel_transcend_a_full.png` (guid `7b41b6a15c9df49a9a49947edd236a48`, 단일 sprite) + `.meta` |
| 폴더 `.meta` (vessel_transcend_a.meta) |

→ FROM `Resources/Sprites/Skin/Unit/vessel_transcend_a/` 폴더 전체 → TO `Resources_moved/Sprites/Skin/Unit/vessel_transcend_a/`.

### G-8. 프리팹 편집 (2건) — `Assets/_Project/3_Prefabs/Units/Vessel/`
| 파일 | 작업 |
|---|---|
| `MovingVesselController.prefab` | `_skinVisuals` 리스트에 `skinId: vessel_transcend_a` + `VFX_Vessel_Loop_New.prefab` 인스턴스 GameObject 추가 |
| `SmallVesselController.prefab` | 동일 |

⚠️ 프리팹 yaml 직접 머지는 fileID 충돌·instance ID 생성 등으로 위험. **Unity 에디터에서 작업 권장**:
1. WD vessel prefab 오픈 → VFX_Vessel_Loop_New nested prefab 인스턴스를 vessel_mythic_a 옆에 추가
2. VesselSkinVisual 컴포넌트의 _skinVisuals 리스트에 새 entry `skinId: vessel_transcend_a, visualObject: <새 인스턴스>` 등록

### G-9. UnitSkinResourceConfig.asset — **편집 불필요**
- BD와 TO 모두 vessel_* entry 없음(`vessel_mythic_a`조차 등록 안 됨). 기존 운영 정책상 vessel은 ResourceConfig 외에서 처리되는 것으로 판단. 따라서 vessel_transcend_a entry 추가도 **불필요** (단, 추후 운영 결정에 따라 변동 가능).

### G-10. Addressables — 미해당
- FROM `AddressableAssetsData/`에 vessel_transcend_a 참조 없음. Resources 경로 기반 로딩.

### G-11. DataSheet SO — **수정 금지 (CLAUDE.md 규칙)**
- `Assets/_Project/1_Scripts/SOs/SO/DataSheet/*.cs` 및 `Assets/_Project/1_Scripts/SOs/Class/DataSheet/*` 파일 직접 수정 금지.
- 시트(UnitSkinData, CurrencyData, ProfileIconData)에 vessel_transcend_a 행 추가 → 다음 자동 생성 시 .asset 갱신.
- **Phase 3 문서에 시트 PIC 안내 기록 필요**: 시트 측 작업이 ground truth, 본 sync의 .asset/.json 패치는 임시 직접 반영.

### G-12. 로컬라이제이션
- 신규 키: `vessel_transcend_a_name`, `icon_vessel_transcend_a`, `Profile_Icon_Name_58 (or 59)`.
- `LocalizationTables Shared Data.asset`는 시트 자동 생성 → 시트에 키·번역 추가 후 동기화.

---

## H. 인프라 감사

| 영역 | 결과 |
|---|---|
| Managers.cs | 변경 불필요 |
| ManagerFactory | 변경 불필요 |
| ServerTimeManager, SaveDataManager | 변경 불필요 |
| JsonSerializer / Encrypt 인프라 | 변경 불필요 |
| EventManager(static) 신규 이벤트 | 변경 불필요 |

---

## I. 주의사항

### I-1. effectType2 BD↔WD 추론 불가 (HIGH)
- WD vessel_mythic_a는 `effectType2: 0`, WD 다른 transcend skin들은 unit별로 0/1/2/3/4 다양. BD vessel_transcend_a는 1.
- 안전한 선택지는 BD 값(1)을 유지하는 것이지만, 게임 디자이너 검수 권장. **시트 동기화 시 vessel_transcend_a 행의 effectType2 컬럼 명시 확인 필요**.

### I-2. costType2 = 1055 vs BD 374 (MEDIUM)
- WD 전 transcend는 `costType2: 1055` 통일. BD vessel은 `374`(VesselKit? — BD enum 확인 필요). WD 컨벤션 적용을 우선.
- WD에서 `1055`가 무엇인지: WD CurrencyData.json에서 직접 확인 안 함. dragoon WD JSON 패턴 그대로 채용한다는 의미.

### I-3. ID 재할당 불필요 (LOW — dragoon 플랜과 차이)
- dragoon 플랜은 BD 30581~30585 → WD 30586~30590 재할당이 필요했지만, vessel은 BD/TO 모두 30591~30595 슬롯이 비어 있음 → **파일명·내부 id 그대로 사용**.

### I-4. ProfileIconData 동기화는 dragoon 플랜에 없던 항목 (NEW)
- BD에 `vessel_transcend_a` profile icon entry 존재. WD에는 없음. 추가 동기화 항목.
- iconNameKey `Profile_Icon_Name_59` vs `_58` — WD 패턴(iconIndex N → Name_N)에 따라 결정. 시트와 일치 시 자동 정리.

### I-5. 7개 텍스처 동반 복사 누락 시 애니메이션 깨짐 (HIGH)
- `Vessel_*_Skin2.anim`이 `special skin_*` 텍스처들의 sprite GUID에 hard-bind. **누락 시 핑크/누락 sprite 표시**.
- 파일명 공백("special skin_") → 복사 스크립트 인용 필요.

### I-6. 프리팹 편집은 Unity 에디터 필수 (HIGH)
- `MovingVesselController.prefab`, `SmallVesselController.prefab` 양쪽에 vessel_transcend_a 시각 객체 추가는 nested prefab instance 생성 + fileID 매핑이라 텍스트 머지 위험. **Unity 에디터에서 수동 작업** 권장.
- 누락 시: 인게임에서 vessel_transcend_a 스킨 장착 시에도 외형 변경 없음(기본 외형 유지).

### I-7. `item_vessel_transcend_a.png` 사용처 미확인 (LOW)
- BD에서 직접 참조 미발견. 그러나 GUID 보존 복사가 안전. 시트에서 상점 카드 등에 참조될 가능성.

### I-8. DataSheet SO 직접 수정 금지 (CRITICAL — CLAUDE.md)
- 본 sync는 `.asset`(데이터)만 직접 수정. CS 자동 생성 파일(`*DataSO.cs`, `*DataData.cs`) 절대 건드리지 말 것.
- 시트 PIC가 시트에 행 추가 → 다음 자동 생성 빌드 시 자동 동기화. **본 sync는 시트 갱신 전 임시 직접 반영**임을 Phase 3 문서에 명시.

### I-9. enum 값 1285는 일회용 — 다음 sync(carrier_transcend_a 등)에 영향 없음 (INFO)
- WD에서 vessel_transcend_a = 1285. 다음 신규 통화는 1286부터.
- dragoon 플랜 §5-6 "vessel/carrier 추가 에셋 예약" 메모는 vessel sync(이 작업)로 해소됨. carrier_transcend_a는 다음 sync에서 1286 등 할당 예정.

---

## J. Phase 3로의 핸드오프

- Phase 3 patch 구성 우선순위:
  1. ECurrencyType.cs 1줄 추가 (가장 안전, 자동화 가능)
  2. JSON 3건 갱신 (CurrencyData, UnitSkinData, ProfileIconData)
  3. .asset 7건 신규 추가 (필드 변환 포함)
  4. controller + anim + 텍스처 + 아이콘 + 스프라이트 파일 복사 (총 20+개 파일)
  5. 프리팹 편집은 Unity 에디터 가이드만 문서화
  6. 시트 PIC 안내(메모/로컬라이제이션/시트 자동 생성)

- **BLOCKED 항목 없음**. 모두 DIRECT/ADAPTED 처리 가능.
