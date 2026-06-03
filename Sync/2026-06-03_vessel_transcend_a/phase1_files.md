# Phase 1 결과 — vessel_transcend_a

생성일: 2026-06-03
FROM: C:/Users/JuwonCha/AppData/Local/Temp/sync_vessel_transcend_a_20260603_231737 (BunkerDefense)
TO:   C:/JuwonCha/WriggleDefender
SYSTEM: vessel_transcend_a (UnitSkin × Vessel × Transcend)
KEYS:  UnitSkin | VesselTranscend | vessel_transcend_a
grep 패턴: `UnitSkin\|VesselTranscend\|vessel_transcend_a`

---

## 1. FROM 발견 파일

### 1-A. 좁은 패턴 (VesselTranscend | vessel_transcend_a) — 실제 영향 파일
- `Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` [TO 기존 존재 — enum 1개 추가만 필요]
  - BD: `vessel_transcend_a = 819`
  - WD: 미존재. WD 마지막 값 `dragoon_transcend_a = 1284` 다음 → **WD에서는 `vessel_transcend_a = 1285`** 로 재할당

### 1-B. 넓은 패턴 (UnitSkin 포함) — 시스템 프레임워크 파일 (per-skin 영향 없음)
다음 56개 파일은 `UnitSkin` 키워드로 매칭됐으나 vessel_transcend_a 리터럴을 포함하지 않으며 UnitSkin 시스템 공유 코드.
WD에 모두 동일 이름의 파일이 존재(아래 §3에 명시). per-skin sync 범위로는 **CS 수정 불필요**.

대표 파일 (전체 목록은 grep 결과 참조):
- Core/Managers/UnitSkinManager.cs / .Preset.cs / .Cheat.cs (WD에 .Cheat.cs 별도 존재)
- Core/Managers/SkinManager.cs, SaveDataManager.cs, SaveDataTypes.cs, RedDotManager.cs,
  PresetManager.cs, RankingProfileSaveManager.cs, ContentUnlockManager.cs, CardManager.cs,
  UnitSpawnManager.cs, DamageCalculationManager.cs / .ChipEffect.cs
- Core/Enums/EUnitSkinSkillType.cs, ETargetItemType.cs, ProductTypes.cs
- Core/Controllers/BaseClass/UnitController.cs
- Core/Controllers/Vessel/VesselController.cs, VesselSkinVisual.cs
- Core/Controllers/{Carrier,Marauder,Ninja,DrFrost,Turret}Controller.cs
- Core/Data/Server/RankingProfileDataTypes.cs
- UI/UnitSkin/* (6 파일), UI/Skin/UnitSkinDetailPopup.cs, UI/BunkerSkin/BunkerSkinDetailPopup.cs,
  UI/Shop/SkinSelectionSimpleItemUI.cs, UI/Popups/SkinEffectOverviewPopup.cs,
  UI/Ranking/RankingUserDetailPopup.cs / RankingOwnedSkinIconUI.cs,
  UI/NewbiePackage/NewbiePackageDayReward.cs, UI/Components/TargetDisplayComponent.cs,
  UI/Loadout/LoadoutPopupUI.cs / LoadoutUnitSkillModule.cs,
  UI/Event/LuckyRoll/LuckyRollEventPanel.cs / LuckyRollSlotItemUI.cs,
  UI/SkinBoxDetailPopupUI.cs, UI/UnitUpgradeUI.cs, UI/UnitUpgradeDetailPopupUI.cs
- SOs/SO/SkinSystem/UnitSkinResourceConfigSO.cs
- SOs/Class/DataSheet/UnitSkinDataData.cs (※ SOs/SO/DataSheet/UnitSkinDataSO.cs는 auto-gen — skip)
- Data/Preset/PresetTypes.cs, Data/Enums/EProfileUnlockCondition.cs,
  Data/ScriptableObjects/ProfileIconRuntimeDataSO.cs, ProfileFrameRuntimeDataSO.cs
- Utils/ResourceUtility.cs, Utils/Editor/JsonToSO.cs
- Core/Base/ManagerFactory.cs
- Editor/Hub/Panels/DataSheetBrowserPanel.cs (FROM에만 존재, WD 미확인 — Editor 툴, sync 범위 외)

### 1-C. VesselController.SkinSkill.cs 비교
- FROM/TO 모두 존재. diff = 순전한 아키텍처 (BD `_objectPoolService.Spawn()` → WD `_objectPoolManager.Get()`).
- vessel_transcend_a 리터럴 없음. WD가 이미 올바른 WD 아키텍처로 구현됨. → **변경 없음**.
- (참고: dragoon 플랜의 `DragoonController.SkinSkill.cs` 결정과 동일 패턴)

### 1-D. VesselController.cs 비교
- FROM/TO 모두 존재. diff에는 RelicSkill, launchStack 등 vessel_transcend_a와 무관한 BD-only 시스템 다수 포함.
- `UnitSkin` 매치는 1398행의 `Managers.Instance.GetManager<UnitSkinManager>()` 일반 호출. → **변경 없음**.

---

## 2. 인프라 의존성 후보

### 2-A. Utils 폴더 비교 (FROM-only 파일)
없음. FROM의 `_Project/1_Scripts/Utils/` 파일은 모두 TO에 동일 이름으로 존재.
TO에 추가 파일(`ColliderBoxSetter.cs`, `InGameModeVariant.cs`, `PackagePopupDailyGate.cs`)이 있지만 TO-only이므로 sync 영향 없음.

### 2-B. using 의존성 / 인프라 패턴 (JsonConverter, SerializableDictionary, *Extensions, Encrypt/Decrypt)
1-A의 ECurrencyType.cs는 의존성 없는 enum 추가만 발생. 추가 인프라 sync 불필요.

**결론: 인프라 의존성 후보 = 0개. ECurrencyType enum 1개 추가만 CS 변경 필요.**

---

## 3. TO 기존 관련 파일
1-B에 열거된 모든 프레임워크 파일은 WD에 동일 이름으로 존재 (Grep TO 매치 65개 ⊇ FROM 매치 58개).
WD 전용 추가 파일:
- `Core/Managers/UnitSkinManager.Cheat.cs`
- `Core/Managers/Cheat/CheatCommandLibrary.cs`, `Cheat/Editor/CheatManagerWindow.cs`
- `Core/Managers/Managers.cs`, `CurrencyManager.cs`
- `Core/Controllers/Vessel/VesselController.RelicSkill.cs`
- `Core/Controllers/{Archon,Templer,Thor,AirMan,Dragoon}Controller.cs`

이들은 TO-only 시스템이며 vessel_transcend_a sync 범위 외.

---

## 4. grep 패턴 (Phase 2 재사용)
`UnitSkin\|VesselTranscend\|vessel_transcend_a`

좁은(실제 영향) 패턴: `VesselTranscend\|vessel_transcend_a`

---

## 5. 참고 문서 cross-check (dragoon plan 대비)

| 항목 | dragoon 플랜 | vessel 추정 | 비고 |
|---|---|---|---|
| ECurrencyType enum | `dragoon_transcend_a = 1284` 추가 | `vessel_transcend_a = 1285` 추가 | WD 마지막 값 1284 다음 |
| BD 원본 enum 값 | 726 | **819** (확인됨) | Phase 2에서 매핑 |
| Controller.SkinSkill.cs | 변경 없음 (WD 정상) | 변경 없음 (WD 정상, 확인됨) | 동일 결론 |
| UnitSkinData JSON | dragoon_transcend_a rank1~5 추가 (WD 30586~30590) | vessel_transcend_a rank1~5 추가 (WD에 빈 ID 블록 필요) | Phase 2에서 ID 충돌 확인 필요 |
| UnitSkinData SO 에셋 | 5개 .asset 복사 + ID 재할당 | 5개 .asset 복사 + ID 재할당 예상 | 동일 패턴 |
| CurrencyData SO 에셋 | `726.asset` → `1284.asset` (currencyType 재할당) | `819.asset` → `1285.asset` 예상 | 동일 패턴 |
| 아이콘 이미지 | `icon_dragoon_transcend_a.png` | `icon_vessel_transcend_a.png` + (추정) `item_vessel_transcend_a.png` | BD에 둘 다 존재함 확인 |
| 유닛 스킨 스프라이트 폴더 | `Sprites/Skin/Unit/dragoon_transcend_a/` | `Sprites/Skin/Unit/vessel_transcend_a/` | BD에 폴더 확인 |
| 애니메이션 컨트롤러 | `Dragoon_Anim_Skin2.controller` | (Vessel용 controller 존재 여부 Phase 2 확인) | JsonFiles/UnitSkinData.json 의 animatorPath 확인 필요 |
| UnitSkinResourceConfig.asset | dragoon 엔트리 수동 추가 | vessel 엔트리 수동 추가 예상 | BD에 vessel 엔트리 미존재 가능성 → Phase 2 확인 |
| 추가 JSON | UnitSkinData만 | UnitSkinData + CurrencyData + **ProfileIconData** (BD에 vessel_transcend_a 포함됨 — Phase 2 확인 대상) | dragoon 플랜에 없는 추가 항목 |

### 누락 의심 / 추가 발견
- **ProfileIconData.json** — BD JSON에 `vessel_transcend_a` 문자열 포함 확인됨. dragoon 플랜에는 없는 카테고리. Phase 2에서 WD 동기화 필요 여부 검토.
- **item_vessel_transcend_a.png** — dragoon에는 아이콘 1종만 있었으나 BD에 vessel용 item 아이콘이 추가 존재.
- BD ECurrencyType의 `vessel_transcend_a = 819` 값은 dragoon(726)보다 앞에 위치 → BD ID 순서와 무관하게 WD는 항상 1284+ 순차 할당.
