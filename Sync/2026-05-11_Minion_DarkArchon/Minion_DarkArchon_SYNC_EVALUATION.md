# Minion_DarkArchon 이식 평가 보고서

- 초회 sync 일자: 2026-05-11
- 재sync (보완) 일자: 2026-05-12
- FROM: temp-bunker/dev | TO: WiggleDefender (juwon/UpdateSync)

---

## 종합 평가

| 항목 | 평가 |
|------|------|
| 스크립트 이식 | ✅ 양호 (변환 포함 정상 완료) |
| 프리팹 이식 | ⚠️ 미흡 (경로 불일치, 이미지 누락) |
| 데이터(SO) 이식 | ⚠️ 미흡 (EEffectType enum 값 오류) |
| UI 표시 순서 | ⚠️ 미흡 (정렬 로직 부재) |

---

## 미흡했던 항목 (재sync에서 수정)

### 1. 스킬 아이콘 이미지 누락

**문제**: `skill_25031.png` ~ `skill_25036.png` (암흑 사제 6개 스킬 아이콘)이 WD에 전혀 복사되지 않음.

**증상**: MinionMainUI에서 암흑 사제 스킬 탭 진입 시 모든 스킬 아이콘이 깨져 보임 (null Sprite).

**원인**: 
- SYNC_PLAN Phase D에 "이미지 에셋" 복사 항목이 명시되지 않음
- PREFAB_SYNC_REPORT에서 `icon_minion_10.png`만 처리하고 스킬 아이콘 6개는 누락
- temp-bunker/dev의 스킬 아이콘 경로(`Assets/Resources/Sprites/Icon/Minion/Skill/`)와 WD의 경로(`Assets/Resources_moved/Sprites/Icon/Minion/Skill/`)가 달라 수동 경로 변환이 필요했으나 sync 시 인지되지 않음

**수정**:
- `skill_25031~25036.png` (및 .meta) → `Assets/Resources_moved/Sprites/Icon/Minion/Skill/` 복사
- Addressables 등록은 Addressables Importer가 자동 처리 (수동 편집 불필요)

---

### 2. EEffectType enum 값 불일치

**문제**: `EEffectType.cs`에 추가된 값이 실제 EffectData SO의 effectType 값과 불일치.

| | Explo | Black |
|---|---|---|
| 최초 sync 시 작성된 EEffectType.cs | 3013 | 3014 |
| EffectData/137.asset (SO) | 3014 | — |
| EffectData/138.asset (SO) | — | 3015 |
| temp-bunker/dev EEffectType.cs (정답) | **3014** | **3015** |

**증상**: 함정 폭발 이펙트(`VFX_Minion_Dark_Trap_Explo`)와 전이 이펙트(`VFX_Minion_Dark_Trap_Black`)가 런타임에 재생되지 않음. EffectManager가 effectType으로 SO를 조회할 때 enum 값이 맞지 않아 미스.

**원인**: SYNC_PLAN 섹션 4-4에서 값을 `3013/3014`로 잘못 명시. temp-bunker/dev 원본을 직접 확인하지 않고 SYNC_PLAN 문서를 그대로 사용함.

**수정**: `EEffectType.cs` — `VFX_Minion_Dark_Trap_Explo = 3014`, `VFX_Minion_Dark_Trap_Black = 3015`로 수정.

---

### 3. MinionMainUI 표시 순서 오류

**문제**: 암흑 사제(index=10)가 MinionMainUI에서 마지막이 아닌 중간에 표시됨.

**원인**: `MinionManager.GetAllMinionData()`가 `Dictionary.Values.ToList()`를 그대로 반환. Dictionary의 iteration 순서는 삽입 순서나 해시값에 따라 결정되므로 `index` 필드가 무시됨.

**수정**: `return _minionDataMap.Values.OrderBy(x => x.index).ToList();`

---

## 잘 처리된 항목

- **스크립트 변환**: `DarkPriestTrapSkill.cs`, `MinionDarkTrapComponent.cs`의 FROM 전용 패턴(ITickService, LowLevelPhysicsHelper, ServiceAccessor 등) → WD 패턴 변환 정확히 완료
- **블로커 항목**: DebuffController `OnDebuffEnded` 이벤트, `Confuse` 디버프 처리 로직 추가 완료
- **GUID 교체**: 프리팹 내 스크립트 GUID 교체 (FROM GUID → TO GUID) 정확히 처리
- **프리팹 구조**: `VFX_Minion_Dark_Trap.prefab`에 `MinionDarkTrapComponent` 컴포넌트 추가 정상
- **MinionData/MinionSkillData**: SO 데이터 복사 및 내용 정상

---

## 이후 sync에서 적용할 교훈

### 교훈 1: 이미지 에셋 경로 확인 필수

FROM이 `Resources/`, TO가 `Resources_moved/`인 경우 단순 경로 복사로는 부족.
**대응**: Sync Plan 작성 시 "TO의 아이콘 경로 구조"를 명시적으로 검증하는 Phase 추가.

### 교훈 2: 새 enum 값 추가 시 FROM 직접 확인

SYNC_PLAN 문서에 기재된 값이 실제 FROM 코드와 다를 수 있음.
**대응**: enum 추가 전 `git show temp-bunker/dev:파일경로 | grep 관련키워드`로 직접 검증.

### 교훈 3: 연관 데이터(SO) - 코드 enum 일관성 검증

EffectData SO의 `effectType` 필드와 `EEffectType` enum 값 매핑 확인이 Phase에 포함되어야 함.
**대응**: Phase A 체크리스트에 "EffectData SO의 effectType 값과 추가되는 enum 값 일치 여부 확인" 항목 추가.

### 교훈 4: GetAllMinionData 정렬 누락

신규 미니언 추가 시 `index` 정렬이 보장되지 않으면 항상 순서 문제 발생 가능.
**대응**: `MinionManager.GetAllMinionData()` 자체에 `OrderBy(x => x.index)` 고정 → 이미 수정 완료.

---

## 재sync 완료 목록 (2026-05-12)

| 수정 항목 | 파일 |
|---------|------|
| 스킬 아이콘 6개 복사 | `Assets/Resources_moved/Sprites/Icon/Minion/Skill/skill_25031~25036.png` |
| EEffectType enum 수정 | `Assets/_Project/1_Scripts/Core/Enums/EEffectType.cs` |
| GetAllMinionData 정렬 추가 | `Assets/_Project/1_Scripts/Core/Managers/MinionManager.cs` |
