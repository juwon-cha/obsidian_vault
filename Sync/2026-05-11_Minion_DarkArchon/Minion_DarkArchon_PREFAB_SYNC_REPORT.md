# Minion_DarkArchon Phase 5-B PREFAB SYNC REPORT

- 실행일: 2026-05-11
- FROM: /tmp/sync_Minion_DarkArchon_1778500357
- TO: /Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender

---

## GUID 매핑 (스크립트)

| 스크립트 | FROM GUID | TO GUID |
|---------|-----------|---------|
| MinionDarkTrapComponent | `33a33b471e09843e08b1ae755c901c98` | `60b5d5e8f16814c42ab88fbdc7b5ce1e` |
| Minion_DarkPriest_Controller | `d12bcf48423254c8d8bdcdd1ae06a4c9` | `c8985ef07348d4a48b0e1e385002d9a3` |
| MinionDarkConfigSO | `3e0274046a3ac4bd79e45357033115ac` | `2c606a944ccfc44dca64804ae026c171` (asset 복사로 처리) |

---

## 프리팹 처리 결과

| # | 파일 | 처리 | GUID 교체 | TO 경로 |
|---|------|------|-----------|---------|
| 1 | `Minion_DarkArchon.prefab` (Marine) | 🆕 신규 복사 | 없음 | `Assets/Marine/Prefab/Minion/` |
| 2 | `VFX_Minion_Dark_Trap.prefab` | ⚠️ 업데이트 | MinionDarkTrapComponent 1건 | `Assets/Marine/Prefab/Minion/` |
| 3 | `VFX_Minion_Dark_Trap_Explo.prefab` | ⚠️ 업데이트 | 없음 (에셋 GUID 모두 TO 존재) | `Assets/Marine/Prefab/Minion/` + `Assets/Resources/EffectPrefabs/Minion/` |
| 4 | `VFX_Minion_Dark_Trap_Black.prefab` | 🆕 신규 복사 | 없음 | `Assets/Resources/EffectPrefabs/Minion/` |
| 5 | `Minion_DarkArchon.prefab` (Resources) | ⚠️ 업데이트 | Minion_DarkPriest_Controller 1건 | `Assets/Resources_moved/Prefabs/Minion/` |
| 6 | `Minion_DarkArchon_UI.prefab` | 🆕 신규 복사 | 없음 | `Assets/_Project/3_Prefabs/UI/Character/` (신규 폴더 생성) |

---

## 추가 에셋 복사 결과

| 파일 | FROM 경로 | TO 경로 | 비고 |
|------|-----------|---------|------|
| `MinionDarkConfig.asset` | `Assets/_Project/11_SO/` | `Assets/_Project/11_SO/` (신규 폴더 생성) | GUID: `556496375a7b4444f8cd65044642d1e3` |
| `icon_minion_10.png` | `Assets/Resources/Sprites/Icon/Minion/` | `Assets/Resources_moved/Sprites/Icon/Minion/` | GUID: `b1beb6994478f4358bd4bedc0b85d4fe` |
| `EffectData/137.asset` | `Assets/Resources/ScriptableObjects/EffectData/` | `Assets/Resources/ScriptableObjects/EffectData/` | 암흑사제 함정 폭발 |
| `EffectData/138.asset` | `Assets/Resources/ScriptableObjects/EffectData/` | `Assets/Resources/ScriptableObjects/EffectData/` | 암흑사제 함정 전이 |
| `Assets/Resources/EffectPrefabs/` (신규 폴더) | - | `Assets/Resources/EffectPrefabs/` | EffectPrefabs.meta + Minion/ 생성 |

---

## 사후 검증 결과

| 프리팹 | 미해결 GUID | 비고 |
|--------|------------|------|
| `Minion_DarkArchon.prefab` (Marine) | ✅ 없음 | |
| `VFX_Minion_Dark_Trap.prefab` | ✅ 없음 | |
| `VFX_Minion_Dark_Trap_Explo.prefab` (Marine) | ✅ 없음 | |
| `VFX_Minion_Dark_Trap_Explo.prefab` (Resources) | ✅ 없음 | |
| `VFX_Minion_Dark_Trap_Black.prefab` | ✅ 없음 | |
| `Minion_DarkArchon.prefab` (Resources_moved) | ✅ 없음 | |
| `Minion_DarkArchon_UI.prefab` | ⚠️ 1건: `fe87c0e1cc204ed48ad3b37840f39efc` | Unity 빌트인 `UnityEngine.UI.Image` — .meta 없음이 정상, TO 기존 프리팹들도 동일하게 참조 중 |

---

## 요약

- 신규 복사: 3개 (Minion_DarkArchon.prefab Marine, VFX_Minion_Dark_Trap_Black.prefab, Minion_DarkArchon_UI.prefab)
- 업데이트: 3개 (VFX_Minion_Dark_Trap.prefab, VFX_Minion_Dark_Trap_Explo.prefab x2, Minion_DarkArchon.prefab Resources)
- GUID 교체: 2건 (스크립트 2 / 에셋 0)
- 신규 에셋: 7개 (MinionDarkConfig.asset, icon_minion_10.png, EffectData/137.asset, EffectData/138.asset, EffectPrefabs 폴더, UI/Character 폴더)
- 미해결 GUID: 1건 (Unity 빌트인 정상)
