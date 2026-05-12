# Minion_DarkArchon PREFAB_PACKAGE_LIST

생성일: 2026-05-11
시스템: Minion_DarkArchon (암흑 사제)
FROM: /tmp/sync_Minion_DarkArchon_1778500357
TO: /Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender

---

## 1. sync할 프리팹 목록 (의존성 순)

| 순서 | 프리팹 파일명 | 상태 | FROM 경로 | TO 처리 |
|------|-------------|------|----------|---------|
| 1 | `Minion_DarkArchon.prefab` (아트 원본) | 🆕 신규 복사 | `Assets/Marine/Prefab/Minion/Minion_DarkArchon.prefab` | TO에 없음 → `Assets/Marine/Prefab/Minion/`에 복사 |
| 2 | `VFX_Minion_Dark_Trap.prefab` (함정 런타임, TrapPrefab) | ⚠️ 업데이트 필요 | `Assets/Marine/Prefab/Minion/VFX_Minion_Dark_Trap.prefab` | TO 동일 경로에 존재 (오브젝트 수 TO:40 → FROM:52, MinionDarkTrapComponent 누락) → 덮어쓰기 |
| 3 | `VFX_Minion_Dark_Trap_Explo.prefab` (폭발 VFX) | ⚠️ 업데이트 필요 | `Assets/Resources/EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Explo.prefab` | TO는 `Marine/Prefab/Minion/`에 있으나 정규 경로는 `Resources/EffectPrefabs/Minion/` — guid 동일(9e356114). TO Marine 경로 파일을 FROM Resources 버전으로 교체하고 경로 이동 검토 필요 (EffectInstance 컴포넌트 누락) |
| 4 | `VFX_Minion_Dark_Trap_Black.prefab` (전이 VFX) | 🆕 신규 복사 | `Assets/Resources/EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Black.prefab` | TO에 없음 → `Assets/Resources/EffectPrefabs/Minion/`에 복사 (EEffectType 3015, ResourceManager 직접 로드 경로) |
| 5 | `Minion_DarkArchon.prefab` (Resources 런타임) | ⚠️ 업데이트 필요 | `Assets/Resources/Prefabs/Minion/Minion_DarkArchon.prefab` | TO는 `Resources_moved/Prefabs/Minion/`에 존재 (오브젝트 수 TO:3 → FROM:6, Minion_DarkPriest_Controller 컴포넌트 누락) → 덮어쓰기 후 경로 검토 |
| 6 | `Minion_DarkArchon_UI.prefab` (UI 아이콘) | 🆕 신규 복사 | `Assets/_Project/3_Prefabs/UI/Character/Minion_DarkArchon_UI.prefab` | TO에 없음 → `Assets/_Project/3_Prefabs/UI/Character/`에 복사 |

### 비고: Marine 아트 전용 프리팹 (동일 파일, 정보성)
| 파일명 | FROM 경로 | 비고 |
|--------|----------|------|
| `VFX_Minion_Dark_Trap_Black.prefab` | `Assets/Marine/Prefab/Minion/VFX_Minion_Dark_Trap_Black.prefab` | guid 다름(c7bd807f) — Marine 아트 전용 버전. Resources 버전(db0efd63)과 별개. 런타임에는 Resources 버전만 사용. Marine 버전은 아트팀 작업용으로 sync 불필요 |

---

## 2. 프리팹별 SerializeField 연결 목록

| 프리팹 | 필드명 | 타입 | 값/참조 | 비고 |
|--------|--------|------|---------|------|
| `Minion_DarkArchon.prefab` (Resources) | `_icon` | Sprite | guid: b1beb6994478f4358bd4bedc0b85d4fe | 아이콘 스프라이트 |
| `Minion_DarkArchon.prefab` (Resources) | `_darkConfig` | MinionDarkConfigSO | guid: 556496375a7b4444f8cd65044642d1e3 (`Assets/_Project/11_SO/MinionDarkConfig.asset`) | TO에 SO 에셋 없음 → 별도 sync 필요 |
| `Minion_DarkArchon.prefab` (Resources) | (animator) | — | 자식 프리팹: `Marine/Prefab/Minion/Minion_DarkArchon.prefab` (guid: 831f791b) | Resources 버전이 Marine 버전을 자식으로 포함 |
| `VFX_Minion_Dark_Trap.prefab` | MinionDarkTrapComponent | 스크립트 컴포넌트 | guid: 33a33b471e09843e08b1ae755c901c98 | FROM에 추가됨. TO에 없어서 업데이트 필요 |
| `VFX_Minion_Dark_Trap_Explo.prefab` | EffectInstance | 스크립트 컴포넌트 | — | FROM에 추가됨. TO에 없어서 업데이트 필요 |
| `Minion_DarkArchon_UI.prefab` | m_Controller | RuntimeAnimatorController | guid: bd379ac19d96f1542beabccf9953e584 | 애니메이션 컨트롤러 참조 |
| `Minion_DarkArchon_UI.prefab` | m_Sprite (Image) | Sprite | (내부 PSB 참조) | — |

---

## 3. MinionDarkConfigSO SO 에셋 설정 목록

SO 에셋: `Assets/_Project/11_SO/MinionDarkConfig.asset`
- **guid**: 556496375a7b4444f8cd65044642d1e3
- **FROM 경로**: `Assets/_Project/11_SO/MinionDarkConfig.asset`
- **TO 상태**: 없음 (신규 복사 필요)

### 설정값 (FROM 기준)

| 필드 | 값 | 비고 |
|------|----|------|
| `TrapPrefab` (_trapPrefab) | `VFX_Minion_Dark_Trap.prefab` (guid: 96e6202645a05c3498050f993ee564e1) | `Assets/Marine/Prefab/Minion/` 경로 |
| `_activationDelay` | 1f | 등장 후 활성화 대기 시간(초) |
| `_detectionPollInterval` | 0.05f | 인식 폴링 주기(초) |
| `_spawnAreaMinDistance` | 0.3f | 최소 스폰 거리 |
| `_spawnNearEnemyRadius` | 1f | 적 주변 랜덤 스폰 반경 |
| `_minY` | -2f | 스폰 영역 최소 Y |
| `_minX` | -2.9f | 맵 좌측 X 한계 |
| `_maxX` | 2.9f | 맵 우측 X 한계 |
| `_trapMoveSpeed` | 6f | 함정 이동 속도 (units/sec) |
| `_collisionThreshold` | 0.5f | 충돌 판정 거리 |
| `_transitionEffectDuration` | 1f | 전이 이펙트 비행 시간(초) |
| `_apostleMinTransitionDistance` | 1.5f | Apostle 최소 전이 거리 |
| `_splitCount` | 4 | Epic 분열 함정 개수 |
| `_splitChildScale` | 0.5f | 소형 함정 스케일 배율 |

---

## 4. 임포트 후 필요한 에디터 작업

- [ ] `MinionDarkConfig.asset` SO 에셋 복사 후, Inspector에서 `TrapPrefab` 필드에 `VFX_Minion_Dark_Trap.prefab` 연결 확인
- [ ] `Minion_DarkArchon.prefab` (Resources/Resources_moved) — `_darkConfig` 필드에 `MinionDarkConfig.asset` 연결 확인
- [ ] `VFX_Minion_Dark_Trap_Explo.prefab` 경로 정리: TO의 `Marine/Prefab/Minion/` 위치를 `Resources/EffectPrefabs/Minion/`으로 이동할지, 아니면 현 위치를 유지할지 판단 (guid 동일하므로 이동 시 AssetDatabase 경로 갱신 필요)
- [ ] `EEffectType` enum 3014/3015 (`VFX_Minion_Dark_Trap_Explo`, `VFX_Minion_Dark_Trap_Black`) — EffectData SO(`137.asset`, `138.asset`)도 TO에 존재하는지 확인 및 복사
- [ ] `Minion_DarkArchon_UI.prefab`의 AnimatorController (guid: bd379ac19d96f1542beabccf9953e584) TO에 존재 여부 확인 (`Assets/_Project/4_Animations/Minion/Clips/DarkArchon/Minion_DarkArchon.controller`)
- [ ] `Minion_DarkArchon.prefab` (Resources 버전) TO 경로 결정: `Resources_moved/Prefabs/Minion/` 유지 vs `Resources/Prefabs/Minion/` 신규 생성 (ResourceManager 로드 경로 확인 필요)
- [ ] Unity 에디터에서 recompile 후 MinionDarkTrapComponent, Minion_DarkPriest_Controller 스크립트 참조 정상 연결 확인

---

## 5. EffectData SO 에셋 (별도 확인 필요)

| effectID | effectType (EEffectType) | prefabPath | FROM 경로 | TO 상태 |
|----------|--------------------------|-----------|-----------|---------|
| 137 | 3014 (VFX_Minion_Dark_Trap_Explo) | `EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Explo` | `Assets/Resources/ScriptableObjects/EffectData/137.asset` | 확인 필요 |
| 138 | 3015 (VFX_Minion_Dark_Trap_Black) | `EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Black` | `Assets/Resources/ScriptableObjects/EffectData/138.asset` | 확인 필요 |
