# DavyJones SYNC PLAN
생성일: 2026-05-07
FROM: temp-bunker/dev (3975fa1a14)
TO: WiggleDefender

## 개요
마린 DavyJones 스킨 이식. 총 38개 파일 신규 추가 + 2개 .cs 수정 + 1개 JSON 수정.
- 이미지/스프라이트: 22개 (UI 텍스처 12 + 인게임 텍스처 8 + 아이콘 1 + marine_transcend_i 폴더 2)
- 애니메이션: 3개 (.anim) + 1개 (.controller)
- 프리팹: 7개
- SO 파일: 5개

---

## 작업 목록

### Step 1. .cs enum 수정 (스크립트 수정)

#### EEffectType.cs
**파일**: `Assets/_Project/1_Scripts/Core/Enums/EEffectType.cs`
**작업**: `MarineHitEffect_Skin_Chainsaw = 1028,` 다음 줄에 추가

```csharp
MarineHitEffect_Skin_DavyJones = 1029, // 마린 피격 효과 스킨 데비존스
```

#### EMuzzleEffectType.cs
**파일**: `Assets/_Project/1_Scripts/Core/Enums/EMuzzleEffectType.cs`
**작업**: `ChainsawStimpack = 79,` 다음 줄 (enum 닫기 `}` 앞)에 추가

```csharp
DavyJones = 80,
DavyJonesStimpack = 81,
```

---

### Step 2. 이미지/스프라이트 복사

**UI 텍스처 (12개)** — `Assets/Marine/UI_Marine_Texture/`

```bash
FROM=/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker
TO=/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_2.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_2.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_3.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_3.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_4.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_4.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_5.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_5.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_6.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_6.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_7.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_7.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_8.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_backgrond_8.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_body.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_body.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_hand_l.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_hand_l.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_hand_r.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_hand_r.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_shoulder_l.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_shoulder_l.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"

cp "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_shoulder_r.png" \
   "$FROM/Assets/Marine/UI_Marine_Texture/UI_skin_davyjones_marine_shoulder_r.png.meta" \
   "$TO/Assets/Marine/UI_Marine_Texture/"
```

**인게임 스킨 텍스처 (8개)** — `Assets/_Project/6_Textures/Units/Marine/`

```bash
cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_1.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_1.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_2.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_2.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_3.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_3.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_4.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_4.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_5.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_5.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_arm_l.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_arm_l.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_arm_r.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_arm_r.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"

cp "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_hand_l.png" \
   "$FROM/Assets/_Project/6_Textures/Units/Marine/skin_davyjones_marine_hand_l.png.meta" \
   "$TO/Assets/_Project/6_Textures/Units/Marine/"
```

**프로필 아이콘 (1개)** — `Assets/Resources_moved/Sprites/UI/Profile/Icons/`
경로 변환: FROM `Assets/Resources/` → TO `Assets/Resources_moved/`

```bash
cp "$FROM/Assets/Resources/Sprites/UI/Profile/Icons/icon_skin_marine_davyjones.png" \
   "$FROM/Assets/Resources/Sprites/UI/Profile/Icons/icon_skin_marine_davyjones.png.meta" \
   "$TO/Assets/Resources_moved/Sprites/UI/Profile/Icons/"
```

**marine_transcend_i 폴더 (2개, 신규 폴더)** — `Assets/Resources_moved/Sprites/Skin/Hero/marine_transcend_i/`
WD에 해당 폴더 없음 — 신규 생성 필요

```bash
mkdir -p "$TO/Assets/Resources_moved/Sprites/Skin/Hero/marine_transcend_i"

cp "$FROM/Assets/Resources/Sprites/Skin/Hero/marine_transcend_i/UI_Marine_Skin_DavyJones.anim" \
   "$FROM/Assets/Resources/Sprites/Skin/Hero/marine_transcend_i/UI_Marine_Skin_DavyJones.anim.meta" \
   "$FROM/Assets/Resources/Sprites/Skin/Hero/marine_transcend_i/skin_frame_marine_transcend_i.png" \
   "$FROM/Assets/Resources/Sprites/Skin/Hero/marine_transcend_i/skin_frame_marine_transcend_i.png.meta" \
   "$TO/Assets/Resources_moved/Sprites/Skin/Hero/marine_transcend_i/"
```

> **참고**: `marine_transcend_i` 폴더 내 파일 목록
> - `UI_Marine_Skin_DavyJones.anim` (+ .meta)
> - `skin_frame_marine_transcend_i.png` (+ .meta)

---

### Step 3. 애니메이션 파일 복사

**인게임 .anim (3개)** — `Assets/_Project/4_Animations/Marine/`

```bash
cp "$FROM/Assets/_Project/4_Animations/Marine/Marine_Idle_Skin_DavyJones.anim" \
   "$FROM/Assets/_Project/4_Animations/Marine/Marine_Idle_Skin_DavyJones.anim.meta" \
   "$TO/Assets/_Project/4_Animations/Marine/"

cp "$FROM/Assets/_Project/4_Animations/Marine/Marine_Walk_Skin_DavyJones.anim" \
   "$FROM/Assets/_Project/4_Animations/Marine/Marine_Walk_Skin_DavyJones.anim.meta" \
   "$TO/Assets/_Project/4_Animations/Marine/"

cp "$FROM/Assets/_Project/4_Animations/Marine/UI_Marine_Skin_DavyJones.anim" \
   "$FROM/Assets/_Project/4_Animations/Marine/UI_Marine_Skin_DavyJones.anim.meta" \
   "$TO/Assets/_Project/4_Animations/Marine/"
```

**Animator Controller (1개)** — `Assets/Resources_moved/Anim/IngameHeroSkin/`
경로 변환: FROM `Assets/Resources/` → TO `Assets/Resources_moved/`

```bash
cp "$FROM/Assets/Resources/Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones.controller" \
   "$FROM/Assets/Resources/Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones.controller.meta" \
   "$TO/Assets/Resources_moved/Anim/IngameHeroSkin/"
```

---

### Step 4. 프리팹 복사

**주의**: 아래 베이스 프리팹이 WD에 **존재함**:
- `MarineHitEffect` 베이스 (GUID `7e1fb688d2b5855419afa1f6b5745f16`): `Assets/Resources_moved/EffectPrefabs/Marine/MarineHitEffect.prefab`
- `MarineMuzzleFlash` 베이스 (GUID `524884b6e1530d045aaa765c6f41faee`): `Assets/_Project/3_Prefabs/Units/Marine/MarineMuzzleFlash.prefab`

**UI 스킨 프리팹 (2개)** — `Assets/Marine/Prefab/UI/UI_Marine_Skin/`

```bash
cp "$FROM/Assets/Marine/Prefab/UI/UI_Marine_Skin/VFX_UI_Marine_Skin_DavyJones_Back.prefab" \
   "$FROM/Assets/Marine/Prefab/UI/UI_Marine_Skin/VFX_UI_Marine_Skin_DavyJones_Back.prefab.meta" \
   "$TO/Assets/Marine/Prefab/UI/UI_Marine_Skin/"

cp "$FROM/Assets/Marine/Prefab/UI/UI_Marine_Skin/VFX_UI_Marine_Skin_DavyJones_Front.prefab" \
   "$FROM/Assets/Marine/Prefab/UI/UI_Marine_Skin/VFX_UI_Marine_Skin_DavyJones_Front.prefab.meta" \
   "$TO/Assets/Marine/Prefab/UI/UI_Marine_Skin/"
```

**히트 이펙트 프리팹 (1개)** — `Assets/Resources_moved/EffectPrefabs/Marine/`
경로 변환: FROM `Assets/Resources/` → TO `Assets/Resources_moved/`

```bash
cp "$FROM/Assets/Resources/EffectPrefabs/Marine/MarineHitEffect_Skin_DavyJones.prefab" \
   "$FROM/Assets/Resources/EffectPrefabs/Marine/MarineHitEffect_Skin_DavyJones.prefab.meta" \
   "$TO/Assets/Resources_moved/EffectPrefabs/Marine/"
```

**프로젝타일 프리팹 (2개)** — `Assets/Resources_moved/Prefabs/HeroSkin/`
경로 변환: FROM `Assets/Resources/` → TO `Assets/Resources_moved/`

```bash
cp "$FROM/Assets/Resources/Prefabs/HeroSkin/Marine_NormalProjectile_Skin_DavyJones.prefab" \
   "$FROM/Assets/Resources/Prefabs/HeroSkin/Marine_NormalProjectile_Skin_DavyJones.prefab.meta" \
   "$TO/Assets/Resources_moved/Prefabs/HeroSkin/"

cp "$FROM/Assets/Resources/Prefabs/HeroSkin/Marine_StimProjectile_Skin_DavyJones.prefab" \
   "$FROM/Assets/Resources/Prefabs/HeroSkin/Marine_StimProjectile_Skin_DavyJones.prefab.meta" \
   "$TO/Assets/Resources_moved/Prefabs/HeroSkin/"
```

**머즐 플래시 프리팹 (2개)** — `Assets/_Project/3_Prefabs/Units/Marine/`

```bash
cp "$FROM/Assets/_Project/3_Prefabs/Units/Marine/MarineMuzzleFlash_Skin_DavyJones.prefab" \
   "$FROM/Assets/_Project/3_Prefabs/Units/Marine/MarineMuzzleFlash_Skin_DavyJones.prefab.meta" \
   "$TO/Assets/_Project/3_Prefabs/Units/Marine/"

cp "$FROM/Assets/_Project/3_Prefabs/Units/Marine/MarineStimpackMuzzleFlash_Skin_DavyJones.prefab" \
   "$FROM/Assets/_Project/3_Prefabs/Units/Marine/MarineStimpackMuzzleFlash_Skin_DavyJones.prefab.meta" \
   "$TO/Assets/_Project/3_Prefabs/Units/Marine/"
```

---

### Step 5. MarineSkinData SO 파일 복사 (5개)

**대상**: `Assets/Resources/ScriptableObjects/MarineSkinData/1096.asset` ~ `1100.asset`
**경로**: FROM → TO 동일 (`Assets/Resources/` 그대로 유지)

```bash
for id in 1096 1097 1098 1099 1100; do
  cp "$FROM/Assets/Resources/ScriptableObjects/MarineSkinData/${id}.asset" \
     "$FROM/Assets/Resources/ScriptableObjects/MarineSkinData/${id}.asset.meta" \
     "$TO/Assets/Resources/ScriptableObjects/MarineSkinData/"
done
```

---

### Step 6. MarineSkinData.json 수정

**파일**: `Assets/Resources/JsonFiles/MarineSkinData.json`
**작업**: `datas` 배열 끝에 아래 5개 항목 추가

```json
[
  {
    "id": 1096,
    "heroSkinId": "marine_transcend_i",
    "skinRarity": 2,
    "targetUnit": 6,
    "skinRank": 1,
    "effectValue1": 20.0,
    "effectValue2": 25.0,
    "skillDescription": "hero_skin_dragoon_desc",
    "skinSkillCategoryType": 2,
    "skillValue": 1.0,
    "costType1": 816,
    "costAmount1": 1,
    "costType2": 348,
    "costAmount2": 1,
    "skinAnimatorPath": "Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones"
  },
  {
    "id": 1097,
    "heroSkinId": "marine_transcend_i",
    "skinRarity": 2,
    "targetUnit": 6,
    "skinRank": 2,
    "effectValue1": 40.0,
    "effectValue2": 50.0,
    "skillDescription": "hero_skin_dragoon_desc",
    "skinSkillCategoryType": 2,
    "skillValue": 2.0,
    "costType1": 816,
    "costAmount1": 1,
    "costType2": 348,
    "costAmount2": 1,
    "skinAnimatorPath": "Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones"
  },
  {
    "id": 1098,
    "heroSkinId": "marine_transcend_i",
    "skinRarity": 2,
    "targetUnit": 6,
    "skinRank": 3,
    "effectValue1": 60.0,
    "effectValue2": 75.0,
    "skillDescription": "hero_skin_dragoon_desc",
    "skinSkillCategoryType": 2,
    "skillValue": 3.0,
    "costType1": 816,
    "costAmount1": 1,
    "costType2": 348,
    "costAmount2": 1,
    "skinAnimatorPath": "Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones"
  },
  {
    "id": 1099,
    "heroSkinId": "marine_transcend_i",
    "skinRarity": 2,
    "targetUnit": 6,
    "skinRank": 4,
    "effectValue1": 80.0,
    "effectValue2": 100.0,
    "skillDescription": "hero_skin_dragoon_desc",
    "skinSkillCategoryType": 2,
    "skillValue": 4.0,
    "costType1": 816,
    "costAmount1": 1,
    "costType2": 348,
    "costAmount2": 1,
    "skinAnimatorPath": "Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones"
  },
  {
    "id": 1100,
    "heroSkinId": "marine_transcend_i",
    "skinRarity": 2,
    "targetUnit": 6,
    "skinRank": 5,
    "effectValue1": 100.0,
    "effectValue2": 125.0,
    "skillDescription": "hero_skin_dragoon_desc",
    "skinSkillCategoryType": 2,
    "skillValue": 5.0,
    "costType1": 816,
    "costAmount1": 1,
    "costType2": 348,
    "costAmount2": 1,
    "skinAnimatorPath": "Anim/IngameHeroSkin/Marine_Anim_Skin_DavyJones"
  }
]
```

---

## 블로커

없음. 베이스 프리팹 GUID 모두 WD에 존재 확인 완료.

---

## Step 7. Currency 데이터 추가 (후속 작업)

> **주의**: 마린 영웅 스킨 sync 시 항상 currency + weapon 스킨도 함께 처리해야 함.
> FROM ID(816/817) → WD ID(1187/1188) 변환 필요.

### CurrencyData SO (신규 GUID 생성)
- `Assets/Resources/ScriptableObjects/CurrencyData/1187.asset` — marine_transcend_i (FROM: 816, currencyType: 1187)
- `Assets/Resources/ScriptableObjects/CurrencyData/1188.asset` — weapon_transcend_i (FROM: 817, currencyType: 1188)

### 아이콘
- `Assets/Resources_moved/Sprites/Icon/icon_marine_transcend_i.png` — FROM `Resources/Sprites/Icon/`에서 복사

### weapon_transcend_i 스프라이트
- `Assets/Resources_moved/Sprites/Skin/Weapon/weapon_transcend_i/` (신규 폴더, 3개 파일)
  - `icon_inGame_marine_transcend_i.png`
  - `icon_outGame_marine_transcend_i.png`
  - `UI_anim_weapons_marine_transcend_i.png`

### WeaponskinData SO (5개, currencyType1 수정)
- `Assets/Resources/ScriptableObjects/WeaponskinData/2096~2100.asset`
- FROM 원본의 `currencyType1: 817` → `currencyType1: 1188` 로 수정 후 저장

### EffectData SO
- `Assets/Resources/ScriptableObjects/EffectData/139.asset` — effectType 1029 (DavyJones 피격 이펙트)

### ProfileIconData SO
- `Assets/Resources/ScriptableObjects/ProfileIconData/57.asset` — icon_skin_marine_davyjones

### JSON 수정
- `WeaponskinData.json`: id 2096~2100 항목 5개 추가 (currencyType1=1188)
- `MarineSkinData.json`: id 1096~1100의 `costType1: 816` → `costType1: 1187` 로 수정
- `CurrencyData.json`: currencyType 1187 (marine_transcend_i), 1188 (weapon_transcend_i) 항목 추가

---

## 체크리스트

- [x] EEffectType.cs 수정 (`MarineHitEffect_Skin_DavyJones = 1029`)
- [x] EMuzzleEffectType.cs 수정 (`DavyJones = 80`, `DavyJonesStimpack = 81`)
- [x] UI 텍스처 12개 복사 (`Assets/Marine/UI_Marine_Texture/`)
- [x] 인게임 스킨 텍스처 8개 복사 (`Assets/_Project/6_Textures/Units/Marine/`)
- [x] 프로필 아이콘 1개 복사 (`Assets/Resources_moved/Sprites/UI/Profile/Icons/`)
- [x] marine_transcend_i 폴더 신규 생성 및 파일 2개 복사
- [x] 인게임 .anim 3개 복사 (`Assets/_Project/4_Animations/Marine/`)
- [x] Animator Controller 1개 복사 (`Assets/Resources_moved/Anim/IngameHeroSkin/`)
- [x] UI 스킨 프리팹 2개 복사 (`Assets/Marine/Prefab/UI/UI_Marine_Skin/`)
- [x] 히트 이펙트 프리팹 1개 복사 (`Assets/Resources_moved/EffectPrefabs/Marine/`)
- [x] 프로젝타일 프리팹 2개 복사 (`Assets/Resources_moved/Prefabs/HeroSkin/`)
- [x] 머즐 플래시 프리팹 2개 복사 (`Assets/_Project/3_Prefabs/Units/Marine/`)
- [x] MarineSkinData SO 5개 복사 (`Assets/Resources/ScriptableObjects/MarineSkinData/`)
- [x] MarineSkinData.json 수정 (id 1096~1100 항목 추가)
- [x] Wind_7.mat 누락 에셋 복사 (`Assets/Marine/Shader/`)
- [x] UI_Marine.prefab 패치 (DavyJones 스킨 노드 추가)
- [x] icon_marine_transcend_i.png 복사 (`Assets/Resources_moved/Sprites/Icon/`)
- [x] weapon_transcend_i 스프라이트 3개 복사 (신규 폴더)
- [x] CurrencyData 1187.asset 생성 (marine_transcend_i)
- [x] CurrencyData 1188.asset 생성 (weapon_transcend_i)
- [x] WeaponskinData SO 2096~2100 복사 (currencyType1: 1188)
- [x] EffectData 139.asset 복사
- [x] ProfileIconData 57.asset 복사
- [x] WeaponskinData.json 수정 (id 2096~2100 추가)
- [x] MarineSkinData.json costType1 수정 (816→1187)
- [x] CurrencyData.json 수정 (currencyType 1187/1188 항목 추가)
- [x] ECurrencyType.cs 수정 (`marine_transcend_i = 1187`, `weapon_transcend_i = 1188` 추가)

## 마린 스킨 Sync 체크리스트 (이후 재사용)

다음에 마린 영웅 스킨을 sync할 때는 아래 항목을 모두 확인할 것:

| 항목 | 비고 |
|------|------|
| 스킨 텍스처 (UI + 인게임) | UI 12개, 인게임 8개 |
| 프로필 아이콘 | `icon_skin_marine_{name}.png` |
| `marine_transcend_{x}` 폴더 | anim + frame png |
| 애니메이션 (.anim × 3 + .controller × 1) | Resources → Resources_moved 경로 변환 |
| 프리팹 7개 | VFX_UI Back/Front, HitEffect, Projectile×2, MuzzleFlash×2 |
| MarineSkinData SO (id 10xx × 5) + JSON | costType1 = WD currency ID |
| **icon_marine_transcend_{x}.png** | Resources_moved/Sprites/Icon/ |
| **weapon_transcend_{x} 스프라이트** | Resources_moved/Sprites/Skin/Weapon/ |
| **CurrencyData SO 2개** | FROM ID→WD ID 변환, 신규 GUID |
| **CurrencyData.json** | currencyType 항목 추가 (marine + weapon) |
| **ECurrencyType.cs** | enum 값 2개 추가 (marine_transcend_{x}, weapon_transcend_{x}) |
| **WeaponskinData SO 5개** + JSON | currencyType1 = WD weapon currency ID |
| **EffectData SO** | effectType 번호 확인 |
| **ProfileIconData SO** | 프로필 아이콘 데이터 |
| .cs enum 수정 (EEffectType, EMuzzleEffectType) | |
| UI_Marine.prefab 패치 | 스킨 노드 + PrefabInstance 추가 |
