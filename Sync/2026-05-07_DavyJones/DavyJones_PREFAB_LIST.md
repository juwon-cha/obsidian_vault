# DavyJones 프리팹 패키지 목록
생성일: 2026-05-07
상태: Phase 4 복사 완료

---

## 복사된 프리팹 (7개)

| 프리팹 | 경로 (Assets/ 기준) | GUID | FROM 일치 |
|--------|---------------------|------|-----------|
| VFX_UI_Marine_Skin_DavyJones_Back | Marine/Prefab/UI/UI_Marine_Skin/ | 5cb14bc0221d79840980789da22cc720 | ✅ |
| VFX_UI_Marine_Skin_DavyJones_Front | Marine/Prefab/UI/UI_Marine_Skin/ | 226ab6ac2c803144b8f97d3e5ab39ffb | ✅ |
| MarineHitEffect_Skin_DavyJones | Resources_moved/EffectPrefabs/Marine/ | e480196d5bba49443856ac61804504b4 | ✅ |
| Marine_NormalProjectile_Skin_DavyJones | Resources_moved/Prefabs/HeroSkin/ | 4787b8d267cdca44b9cc8e38d7e87af4 | ✅ |
| Marine_StimProjectile_Skin_DavyJones | Resources_moved/Prefabs/HeroSkin/ | e1c5e874ab7000a4586e74c0ec6801f6 | ✅ |
| MarineMuzzleFlash_Skin_DavyJones | _Project/3_Prefabs/Units/Marine/ | cc3ebaaa48f44e64481c74677f3e8c40 | ✅ |
| MarineStimpackMuzzleFlash_Skin_DavyJones | _Project/3_Prefabs/Units/Marine/ | d43a81b002136e14087fc6b72de64ff0 | ✅ |

> **참고**: FROM(temp-bunker) 기준 경로 차이 — `Resources/` → `Resources_moved/` (TO 프로젝트의 Resources 마이그레이션 반영)

---

## GUID 유효성 검사

총 17개 고유 참조 GUID 검사 결과: **유효 15개 / 무효 2개**

### VFX_UI_Marine_Skin_DavyJones_Back

| GUID | 파일 | 상태 |
|------|------|------|
| 10e0147ae2a3c504fa1fd3a6c0be2926 | `_Project/7_VFX/Shockwave/shader/Ice_Area4.shader` | ✅ |
| 16f0b0b6d0b7542bfbd20a3e05b04ff1 | UIParticle.cs (com.coffee.ui-particle 패키지) | ✅ (패키지) |
| 3a036914be2d4714ab8944d90a002828 | `Marine/Shader/Wind_7.mat` | ❌ TO에 없음 |
| 5c9ed24e04ca798489d20735458ec329 | `_Project/7_VFX/Material/1Add_mat.mat` | ✅ |
| 8d13d82a058c8ff488c3af9f87c577cc | `_Project/7_VFX/Material/1AB_mat.mat` | ✅ |
| e4527d32a263c274c9ab1fbf4c0a9740 | `_Project/7_VFX/Texture/circle.png` | ✅ |
| ee0ddf2b2a7eb934d88d5c7143a101c5 | `_Project/7_VFX/Texture/sickle06 2.png` | ✅ |

### VFX_UI_Marine_Skin_DavyJones_Front

| GUID | 파일 | 상태 |
|------|------|------|
| 08053766ee41f5e4cb49d092f07c8cd7 | `_Project/7_VFX/Texture/Flash32.png` | ✅ |
| 16f0b0b6d0b7542bfbd20a3e05b04ff1 | UIParticle.cs (com.coffee.ui-particle 패키지) | ✅ (패키지) |
| 8d13d82a058c8ff488c3af9f87c577cc | `_Project/7_VFX/Material/1AB_mat.mat` | ✅ |
| e4527d32a263c274c9ab1fbf4c0a9740 | `_Project/7_VFX/Texture/circle.png` | ✅ |

### MarineHitEffect_Skin_DavyJones

| GUID | 파일 | 상태 |
|------|------|------|
| 7e1fb688d2b5855419afa1f6b5745f16 | `Resources_moved/EffectPrefabs/Marine/MarineHitEffect.prefab` | ✅ |

### Marine_NormalProjectile_Skin_DavyJones

| GUID | 파일 | 상태 |
|------|------|------|
| 1702c1375f51e994188eee2d221452b6 | `_Project/7_VFX/Material/Eyes_Trail_ADD.mat` | ✅ |
| 1f7c67cb286275c4b9ca69d4c0e5351a | `_Project/1_Scripts/Core/Controllers/Marine/MarineProjectileController.cs` | ✅ |
| 4ff077d9462740a4d906522bb0b883e3 | `Marine/Prefab/Marine/VFX_Machine_Projectile.prefab` | ✅ |
| 69784f9041328904884974242cd701e2 | `Marine/Prefab/Marine/VFX_Nature_Projectile.prefab` | ✅ |
| 80fdd58383a881b41990192fc561fb0a | `_Project/7_VFX/Texture/Shot3.png` | ✅ |
| 8d13d82a058c8ff488c3af9f87c577cc | `_Project/7_VFX/Material/1AB_mat.mat` | ✅ |

### Marine_StimProjectile_Skin_DavyJones

| GUID | 파일 | 상태 |
|------|------|------|
| 10e0147ae2a3c504fa1fd3a6c0be2926 | `_Project/7_VFX/Shockwave/shader/Ice_Area4.shader` | ✅ |
| 1702c1375f51e994188eee2d221452b6 | `_Project/7_VFX/Material/Eyes_Trail_ADD.mat` | ✅ |
| 1f7c67cb286275c4b9ca69d4c0e5351a | `_Project/1_Scripts/Core/Controllers/Marine/MarineProjectileController.cs` | ✅ |
| 4ff077d9462740a4d906522bb0b883e3 | `Marine/Prefab/Marine/VFX_Machine_Projectile.prefab` | ✅ |
| 5c9ed24e04ca798489d20735458ec329 | `_Project/7_VFX/Material/1Add_mat.mat` | ✅ |
| 69784f9041328904884974242cd701e2 | `Marine/Prefab/Marine/VFX_Nature_Projectile.prefab` | ✅ |
| 722c40efae43b624bae470ffd9158974 | `_Project/7_VFX/Texture/circle_soft03.png` | ✅ |
| 80fdd58383a881b41990192fc561fb0a | `_Project/7_VFX/Texture/Shot3.png` | ✅ |
| 8d13d82a058c8ff488c3af9f87c577cc | `_Project/7_VFX/Material/1AB_mat.mat` | ✅ |

### MarineMuzzleFlash_Skin_DavyJones

| GUID | 파일 | 상태 |
|------|------|------|
| 524884b6e1530d045aaa765c6f41faee | `_Project/3_Prefabs/Units/Marine/MarineMuzzleFlash.prefab` | ✅ |
| 5c9ed24e04ca798489d20735458ec329 | `_Project/7_VFX/Material/1Add_mat.mat` | ✅ |

### MarineStimpackMuzzleFlash_Skin_DavyJones

| GUID | 파일 | 상태 |
|------|------|------|
| 2d9b4d37bf2a5324d9074912e2cd4354 | `_Project/3_Prefabs/Units/Marine/MarineStimpackMuzzleFlash.prefab` | ✅ |

---

## 결론

- 유효한 참조: **15개**
- 무효한 참조: **1개** (패키지 GUID는 별도 분류)
- 패키지 참조 (meta 없음, 정상): **1개**

### 무효 참조 상세

| GUID | 원본 파일 (FROM) | 사용 프리팹 | 비고 |
|------|-----------------|-------------|------|
| 3a036914be2d4714ab8944d90a002828 | `Marine/Shader/Wind_7.mat` | VFX_UI_Marine_Skin_DavyJones_Back | TO에 `Wind6.mat`은 있으나 `Wind_7.mat` 없음 |

### 패키지 참조 (정상)

| GUID | 패키지 | 파일 | 비고 |
|------|--------|------|------|
| 16f0b0b6d0b7542bfbd20a3e05b04ff1 | com.coffee.ui-particle | UIParticle.cs | Library/PackageCache에 존재, .meta 없음이 정상 |

---

## Phase 5-B 필요 작업

`Wind_7.mat` (GUID: `3a036914be2d4714ab8944d90a002828`)이 TO에 없음.

- FROM 경로: `Assets/Marine/Shader/Wind_7.mat`
- 영향 프리팹: `VFX_UI_Marine_Skin_DavyJones_Back.prefab` (머티리얼 참조)
- 조치: FROM에서 `Wind_7.mat` + `Wind_7.mat.meta`를 TO의 `Assets/Marine/Shader/`로 복사해야 함
