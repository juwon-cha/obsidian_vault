# Relic System — Prefab Package List (Phase 5a)
생성일: 2026-05-04  
BD worktree: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker`  
WD 루트: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`

---

## 경로 매핑 규칙

| BD 경로 패턴 | WD 경로 패턴 | 비고 |
|---|---|---|
| `Assets/Resources/` | `Assets/Resources_moved/` | WD에서 리소스 폴더 이동됨 |
| `Assets/_Project/` | `Assets/_Project/` | 동일 |
| `Assets/Marine/` | `Assets/Marine/` | 동일 |

> **GUID 교체 필수**: 모든 `.prefab` 파일 내 `m_Script` guid를 WD `.cs.meta`의 guid로 교체해야 함.

---

## 1. UI 메인 프리팹 (6개)

BD → WD, 경로 패턴: `Resources/UI/` → `Resources_moved/UI/`

| # | 파일명 | BD 경로 | WD 목표 경로 | 연결 스크립트 |
|---|---|---|---|---|
| 1 | `RelicMainUI.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicMainUI.cs` |
| 2 | `RelicUpgradeUI.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicUpgradeUI.cs` |
| 3 | `RelicDescriptionPopup.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicDescriptionPopup.cs` |
| 4 | `RelicEquipPickerUI.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicEquipPickerUI.cs` |
| 5 | `RelicGachaPopup.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicGachaPopup.cs` |
| 6 | `RelicResultPopup.prefab` | `Assets/Resources/UI/` | `Assets/Resources_moved/UI/` | `RelicResultPopup.cs` |

---

## 2. UI 컴포넌트 프리팹 (9개)

BD → WD, 경로: `_Project/3_Prefabs/UI/Relic/` (신규 폴더 생성 필요)

| # | 파일명 | BD 경로 | WD 목표 경로 | 연결 스크립트 |
|---|---|---|---|---|
| 1 | `RelicDisplayComponent.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | `RelicDisplayComponent.cs` |
| 2 | `RelicDescComponent.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | `RelicEquippedDescComponent.cs` |
| 3 | `RelicEquipPickerItemComponent.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | `RelicEquipPickerItemComponent.cs` |
| 4 | `RelicIcon.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | `RelicIcon.cs` |
| 5 | `RelicLevelBox.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | `RelicLevelBox.cs` |
| 6 | `RelicStatBox.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | *(UI-only, 스크립트 없음)* |
| 7 | `RelicUnlockPreviewSlot.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | *(UI-only)* |
| 8 | `RelicUpgradeText.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | *(UI-only)* |
| 9 | `StarOverlay.prefab` | `_Project/3_Prefabs/UI/Relic/` | `_Project/3_Prefabs/UI/Relic/` | *(UI-only)* |

---

## 3. VFX 프리팹 (6개)

### 3-A. Marine/Prefab (유닛별 이펙트)

| # | 파일명 | BD 경로 | WD 목표 경로 |
|---|---|---|---|
| 1 | `VFX_Carrier_Relic_Explo.prefab` | `Assets/Marine/Prefab/Carrier/` | `Assets/Marine/Prefab/Carrier/` |
| 2 | `VFX_Dragoon_Relic_Explo.prefab` | `Assets/Marine/Prefab/Dragoon/` | `Assets/Marine/Prefab/Dragoon/` |
| 3 | `VFX_Vessel_Relic_Deffensive.prefab` | `Assets/Marine/Prefab/Vessel/` | `Assets/Marine/Prefab/Vessel/` |

### 3-B. Resources/EffectPrefabs (Resources.Load 대상)

| # | 파일명 | BD 경로 | WD 목표 경로 | 비고 |
|---|---|---|---|---|
| 4 | `VFX_Thor_Relic_Skill.prefab` | `Assets/Resources/EffectPrefabs/Thor/` | `Assets/Resources_moved/EffectPrefabs/Thor/` | Thor 폴더 신규 생성 필요 |
| 5 | `VFX_Vessel_Relic_Deffensive_Explo.prefab` | `Assets/Resources/EffectPrefabs/Vessel/` | `Assets/Resources_moved/EffectPrefabs/Vessel/` | Vessel 폴더 신규 생성 필요 |
| 6 | `VFX_Vessel_Relic_Deffensive_Hit.prefab` | `Assets/Resources/EffectPrefabs/Vessel/` | `Assets/Resources_moved/EffectPrefabs/Vessel/` | |

### 3-C. _Project/7_VFX (레이저/체인 이펙트)

| # | 파일명 | BD 경로 | WD 목표 경로 |
|---|---|---|---|
| 7 | `Dragoon_relicSkill.prefab` | `Assets/_Project/7_VFX/VFX/Laser & Chain/` | `Assets/_Project/7_VFX/VFX/Laser & Chain/` |

---

## 4. 텍스처 / 스프라이트 (108개)

### 4-A. 유물 아이콘 (Relic Icon sprites) — 33개

경로: `Resources/Sprites/Icon/Relic/` → `Resources_moved/Sprites/Icon/Relic/` (신규 폴더)

| 등급 | 유닛 | 파일명 |
|---|---|---|
| Epic (11개) | Archon, Bullgom, Carrier, Dr.Frost, AirMan, Assassin(Ninja), Dragoon, Templer, Thor, Turret, Vessel | `UI_legacy icon_Epic_{unit}.png` |
| Legendary (11개) | Archon, Bullgom, Carrier, Dr.Frost, AirMan, Assassin(Ninja), Dragoon, Templer, Thor, Turret, Vessel | `UI_legacy icon_legendary_{unit}.png` |
| Mythic (11개) | Archon, Bullgom, Carrier, Dr.Frost, AirMan, Assassin(Ninja), Dragoon, Templer, Thor, Turret, Vessel | `UI_legacy icon_Unique_{unit}.png` |

### 4-B. 유물 조각 아이콘 (Relic Piece sprites) — 38개

경로: `Resources/Sprites/Currency/Relic/` → `Resources_moved/Sprites/Currency/Relic/` (신규 폴더)

| 종류 | 파일 수 | 파일명 패턴 |
|---|---|---|
| Epic 조각 (유닛별) | 11개 | `UI_legacy piece icon_Epic_{unit}.png` |
| Legendary 조각 (유닛별) | 11개 | `UI_legacy piece icon_legendary_{unit}.png` |
| Unique(Mythic) 조각 (유닛별) | 11개 | `UI_legacy piece icon_Unique_{unit}.png` |
| 재료 아이템 | 4개 | `item_legacy box.png`, `item_legacy hammer.png`, `item_legacy piece box.png`, `item_legacy stone.png` |
| 등급 대표 이미지 | 1개 | `UI_legacy piece icon_legendary.png` |

### 4-C. UI 스프라이트 — 합계 19개

**Gacha_Relic** (`Resources/Sprites/UI/Gacha_Relic/` → `Resources_moved/Sprites/UI/Gacha_Relic/`, 신규 폴더, 15개):
- `UI_shop_frame_gacha3.png`, `UI_shop_frame_gacha3_question mark.png`, `UI_shop_img_gacha3.png`
- `gacha_circle.png`, `gacha_goldbox.png`, `gacha_goldbox_gripL.png`, `gacha_goldbox_gripR.png`, `gacha_goldbox_lid.png`
- `gacha_hammer_gold.png`, `gacha_iron.png`
- `gacha_lock_brokenL_gold.png`, `gacha_lock_brokenR_gold.png`, `gacha_lock_fragmentL_gold.png`, `gacha_lock_fragmentR_gold.png`, `gacha_lock_gold.png`

**Relic UI 프레임** (`Resources/Sprites/UI/Relic/` → `Resources_moved/Sprites/UI/Relic/`, 신규 폴더, 3개):
- `UI_legacy_lobby_frame_Unique.png`
- `UI_legacy_lobby_frame_epic.png`
- `UI_legacy_lobby_frame_legendary.png`

### 4-D. _Project 텍스처 — 합계 18개

경로: `_Project/6_Textures/Relic/` → `_Project/6_Textures/Relic/` (신규 폴더)

| 서브폴더 | 파일 수 | 주요 파일 |
|---|---|---|
| `RelicEquip/` | 3개 | `UI_legacy_wear_bg.png`, `UI_legacy_wear_frame.png`, `UI_legacy_wear_img.png` |
| `RelicStar/` | 5개 | `UI_legacy_lobby_frame_star0~4.png` |
| `RelicUpgrade/` | 7개 | `UI_legacy_info1_icon.png`, `UI_legacy_info2_icon.png`, `UI_legacy_info_bg1~5.png` |
| 루트 | 8개 | `UI_icon_legacy.png`, `UI_legacy_lobby_bg.png`, `UI_legacy_lobby_bg2.png`, `UI_legacy_lobby_frame_gaege bg.png`, `UI_legacy_lobby_header1.png`, `UI_legacy_lobby_header2.png`, `UI_legacy_lobby_icon.png`, `UI_legacy_lobby_stat frame_bg.png`, `UI_legacy_lobby_title.png`, `UI_legacy_lobby_title 1.png`, `UI_legacy_lobby_title2.png`, `UI_legacy_wear_icon.png` |

---

## 5. 애니메이션 (4개)

경로: `_Project/4_Animations/UI/` → `_Project/4_Animations/UI/` (동일 폴더)

| # | 파일명 | 비고 |
|---|---|---|
| 1 | `RelicUpgradeUI.anim` | 강화 연출 클립 |
| 2 | `RelicUpgradeUI.controller` | 강화 애니메이터 |
| 3 | `Relic_Icon.anim` | 아이콘 등장 클립 |
| 4 | `Relic_Icon.controller` | 아이콘 애니메이터 |

---

## 6. 복사 순서 및 작업 절차

### Step 1 — 신규 폴더 생성
```bash
WD=Assets
mkdir -p "$WD/Resources_moved/Sprites/Currency/Relic"
mkdir -p "$WD/Resources_moved/Sprites/Icon/Relic/Epic"
mkdir -p "$WD/Resources_moved/Sprites/Icon/Relic/Legendary"
mkdir -p "$WD/Resources_moved/Sprites/Icon/Relic/Mythic"
mkdir -p "$WD/Resources_moved/Sprites/UI/Gacha_Relic"
mkdir -p "$WD/Resources_moved/Sprites/UI/Relic"
mkdir -p "$WD/Resources_moved/EffectPrefabs/Thor"
mkdir -p "$WD/Resources_moved/EffectPrefabs/Vessel"
mkdir -p "$WD/_Project/3_Prefabs/UI/Relic"
mkdir -p "$WD/_Project/6_Textures/Relic"
```

### Step 2 — 에셋 복사 (파일 + .meta)
각 카테고리별 `cp -r` 로 BD → WD 복사.  
`.meta` 파일 포함하여 복사.

### Step 3 — GUID 교체
각 `.prefab` 내 `m_Script` 항목의 guid를 WD `.cs.meta` guid로 교체.

**교체 대상 스크립트 (Phase 4에서 신규 생성됨):**

| 컴포넌트 | WD .cs.meta 위치 |
|---|---|
| `RelicMainUI` | `_Project/1_Scripts/UI/Relic/Panel/RelicMainUI.cs.meta` |
| `RelicUpgradeUI` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicUpgradeUI.cs.meta` |
| `RelicDescriptionPopup` | `_Project/1_Scripts/UI/Relic/Panel/RelicDescriptionPopup.cs.meta` |
| `RelicEquipPickerUI` | `_Project/1_Scripts/UI/Relic/Panel/RelicEquipPickerUI.cs.meta` |
| `RelicGachaPopup` | `_Project/1_Scripts/UI/Relic/RelicGachaPopup.cs.meta` |
| `RelicResultPopup` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicResultPopup.cs.meta` |
| `RelicDisplayComponent` | `_Project/1_Scripts/UI/Relic/Panel/RelicDisplayComponent.cs.meta` |
| `RelicEquippedDescComponent` | `_Project/1_Scripts/UI/Relic/Panel/RelicEquippedDescComponent.cs.meta` |
| `RelicEquipPickerItemComponent` | `_Project/1_Scripts/UI/Relic/Panel/RelicEquipPickerItemComponent.cs.meta` |
| `RelicIcon` | `_Project/1_Scripts/UI/Relic/Panel/RelicIcon.cs.meta` |
| `RelicLevelBox` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicLevelBox.cs.meta` |
| `RelicUpgradeModuleBase` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicUpgradeModuleBase.cs.meta` |
| `RelicUnlockModule` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicUnlockModule.cs.meta` |
| `RelicLevelUpModule` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicLevelUpModule.cs.meta` |
| `RelicRankUpModule` | `_Project/1_Scripts/UI/Relic/Upgrade/RelicRankUpModule.cs.meta` |
| `RelicEquippedSlotComponent` | `_Project/1_Scripts/UI/Relic/Panel/RelicEquippedSlotComponent.cs.meta` |
| `RelicGachaProbabilityPopup` | `_Project/1_Scripts/UI/Relic/RelicGachaProbabilityPopup.cs.meta` |
| `RelicUtility` | `_Project/1_Scripts/UI/Relic/RelicUtility.cs.meta` |

### Step 4 — Unity 재임포트 및 MissingReference 점검
- Unity Editor에서 `Assets → Refresh` (또는 Ctrl+R)
- 각 Relic 프리팹을 Inspector에서 열어 Missing Script / Missing Reference 없는지 확인

---

## 7. 총계

| 카테고리 | 파일 수 |
|---|---|
| UI 메인 프리팹 | 6 |
| UI 컴포넌트 프리팹 | 9 |
| VFX 프리팹 | 7 |
| 아이콘 스프라이트 | 33 |
| 조각/재료 스프라이트 | 38 |
| UI 스프라이트 | 19 |
| 텍스처 | 18 |
| 애니메이션 | 4 |
| **합계** | **134** |

---

## 8. 주의사항

1. **BD `RelicDescComponent.prefab`** — WD에서 `RelicEquippedDescComponent.cs`로 이름이 바뀜. GUID 교체 시 이 매핑을 주의.
2. **`RelicGachaProbabilityPopup.prefab`** — BD에는 없음. WD에서 신규 생성 필요 (스크립트 `RelicGachaProbabilityPopup.cs`는 이미 작성됨).
3. **VFX 프리팹의 파티클/머티리얼** — BD와 WD에서 동일 셰이더(`Marine/VFX` 등)를 사용한다면 GUID 불일치 없음. 다를 경우 머티리얼 GUID도 교체 필요.
4. **스프라이트 아틀라스** — BD에는 Relic 전용 `.spriteatlas` 없음. 개별 `.png`로 직접 참조.
5. **`Dragoon_relicSkill.prefab`** — 레이저 이펙트. `DragoonController.RelicSkill.cs`에서 `ResourceManager.LoadResource<GameObject>()` 로 로드. 경로 문자열이 스크립트에 하드코딩되어 있으면 `Resources_moved` 경로로 수정 필요.
