# Guild PHASE2 — 레이드 전투 + 게임모드 서비스 + 치트 (FROM 분석)

- 작성일: 2026-06-20
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 담당 영역: 길드 레이드 보스 컨트롤러 + 게임모드 4종 서비스 + SO 스크립트 + 치트
- READ-ONLY 분석

---

## 0. 파일 목록 (총 14 .cs)

### 레이드 보스 컨트롤러 (`Core/Controllers/Enemy/GuildRaid/`) — 6
| 파일 | KB | 클래스/역할 | 베이스 |
|------|----|----|----|
| GuildBossController.cs | 16K | 길드 레이드 보스 공통 베이스(무한 누적 불사·패턴 스케줄·데미지 라우팅·벙커 피해) | **abstract : BaseBossController** |
| StellaBoss50101Controller.cs | 38K | Stella(50101) 손/도끼/레이저 패턴 구현 | **: GuildBossController** |
| GuildRaidPatternController.cs | 11K | 패턴 객체 타격판정(저수준 물리)+DetectionManager 등록 | **: BaseEnemyController** |
| GuildRaidBossEntranceSpawner.cs | 1.8K | 등장연출 프리팹 스폰(MonoBehaviour) | MonoBehaviour |
| GuildRaidAnimationEventRelay.cs | 1.1K | AnimationEvent → 보스 중계(레이저 발사 개시) | MonoBehaviour |
| GuildRaidDamageEventData.cs | 0.5K | 누적 피해 HUD 이벤트 DTO | **: IMessage** (Geuneda) |

### 게임모드 서비스 (Guild 디렉터리 밖) — 4 + 1 보조
| 파일 | 클래스 | 베이스 |
|------|----|----|
| `Core/GameModes/GuildRaidModeConfigurator.cs` | GuildRaidModeConfigurator | **: IGameModeConfigurator** |
| `Core/Managers/StageServices/GuildRaidStagePlayService.cs` | GuildRaidStagePlayService | **: BaseStagePlayService** |
| `UI/GameModeUI/GuildRaidGameModeUIService.cs` | GuildRaidGameModeUIService | **: BaseGameModeUIService** |
| `UI/GameResult/GuildRaidGameResultService.cs` | GuildRaidGameResultService | **: StandardGameResultService** |
| `Core/GameModes/GuildRaidInitialSelectionData.cs` | GuildRaidInitialSelectionData (POCO: CardDataSO[] Choices) | (없음) |

### SO 스크립트 (`SOs/Guild/`) — 2
| 파일 | 역할 |
|------|----|
| GuildBossUIPrefabRegistrySO.cs | bossId → (로비 UI 프리팹, 등장연출 프리팹) 매핑. 순수 ScriptableObject, 추가 의존성 없음 |
| GuildRaidEntranceConfigSO.cs | 입장 규칙(총/무료 횟수·비용 색상). 순수 SO. **이식 DIRECT** |

### 치트 — 13 (#if DEV, 선택)
- `Core/Managers/Cheat/Guild/IGuildCheatRuntime.cs` (`: ICheatRuntime`)
- `Core/Managers/Cheat/Guild/Editor/` : GuildCheatToolWindow.cs(+.uss/.uxml) + GuildCheatCommandLibrary.cs + 9개 partial(.Common/.Management/.Permission/.Chat/.Donation/.Buff/.Quest/.Shop/.Rental/.Util)
- 전부 `#if DEV` 가드. 길드 일반 도메인(채팅/기부/퀘스트/상점/대여) 치트. **레이드 전투와 무관** — `GuildRaidStagePlayService.SkipClearSubmitCheat` 하나만 레이드 관련(스토리 플레이서비스 내부 정적 필드).

---

## 1. ★★★ 게임모드 서비스 4종 베이스클래스 TO 존재 여부 (가장 중요) ★★★

| BD 베이스 | TO 존재? | 결론 |
|------|------|------|
| **IGameModeConfigurator** | ✅ 존재 (`Core/GameModes/IGameModeConfigurator.cs`, Standard/Endless 구현 2종) | **DIRECT(어댑트)** |
| **BaseStagePlayService** | ✅ 존재 (`Core/Managers/StageServices/`, PunchKing/RaceTower/Vanguard 3종 구현) | **DIRECT(어댑트)** |
| **BaseGameModeUIService** | ❌ **TO에 없음** (grep 0건) | **BLOCKED → 인라인 재작성** |
| **StandardGameResultService** | ❌ **TO에 없음** (grep 0건, `UI/GameModeUI/` 디렉터리 자체 부재) | **BLOCKED → 인라인 재작성** |

### → 종합 결론: **PARTIAL (2 DIRECT-어댑트 + 2 인라인 재작성)**

**문서(Guild_Migration_BD_to_WD.md)의 "WD엔 Configurator/StagePlay 패턴이 아예 없으니 단일 GuildRaidManager로 통합" 주장은 절반만 맞음:**

- **Configurator/StagePlay 2종은 통합 불필요** — WD에 동일 패턴 존재. WD `StandardModeConfigurator` / `BaseStagePlayService`를 그대로 베이스로 직접 이식 가능.
  - `Managers.cs:970` 에서 `IGameModeConfigurator configurator`를 모드별로 생성(현재 Endless/Standard 분기) → **GuildRaid 분기 추가 + GuildBossScene/GameModeType.GuildRaid 게이트**만 하면 됨.
  - `StageManager.cs`가 `_punchKingStagePlayService`/`_raceTowerStagePlayService`를 필드로 소유하고 `HandleGameOver`(713)·`StartStage`(972)에서 모드별로 분기 → **GuildRaid 스테이지ID 게이트 + `_guildRaidStagePlayService` 필드 추가** 동형 작업.
  - `GuildRaidStagePlayService`는 `MainInstaller.Resolve<IMessageBrokerService>()` / `ServiceAccessor.Get<T>()` → WD `EventManager`(static) / `Managers.Instance.GetManager<T>()`로 치환 필요(변환 부담만, 구조 변경 없음).

- **GameModeUI/GameResult 2종은 BD 아키텍처가 WD에 없으므로 인라인 통합 필요** (문서 주장과 동일 방향):
  - WD는 BaseGameModeUIService 추상화 대신 **`GameUI.cs` 내부에 모드별 분기**를 둠 (예: `_isPunchKingMode`, `HandlePunchKingDamageUpdated`, EventManager 구독). `GameUI.cs:262` 주석에 "BD GameModeUIService 아키텍처 대신 WD GameUI 내부 분기로 동일 효과"라고 명시.
    → `GuildRaidGameModeUIService`(누적 피해 HUD)는 **`GameUI.cs`에 `_isGuildRaidMode` 분기 + 누적피해 텍스트 트윈을 인라인 추가**로 구현. PunchKing 데미지 HUD 분기가 그대로 모범 사례.
  - WD는 StandardGameResultService 대신 **`GameResultUI.cs` 내부 인라인 분기**를 둠 (`GameResultUI.cs:1364` "BD RaceTowerGameResultService 동작 인라인 이식" region이 선례).
    → `GuildRaidGameResultService`(누적 피해 점수·항상 성공 오버레이·재도전/2배보상 숨김)는 **GameResultUI에 GuildRaid 인라인 분기 추가**로 구현. RaceTower 인라인 region이 그대로 모범.

> 즉 단일 GuildRaidManager로 억지 통합할 필요는 없고, **2종은 WD 동일 패턴 직접 이식, 2종은 GameUI/GameResultUI 인라인**이 정답.

---

## 2. ★ LowLevelPhysicsHelper / 저수준 물리 — 동반 이식 필요 (TO에 없음, 최대 리스크) ★

`GuildRaidPatternController.cs`가 BD의 **저수준 물리(LowLevelPhysics2D) 레이어**에 의존하는데, **TO엔 이 레이어 전체가 없음**:

- 사용 심볼: `PhysicsBody`, `PhysicsShape`, `PhysicsWorld.defaultWorld`, `LowLevelPhysicsHelper.CreateKinematicCircle/SafeDestroy`, `PhysicsLayerMapping.Enemy`, `using MarinRPG.Physics`, `using UnityEngine.LowLevelPhysics2D` (또는 `Unity.U2D.Physics`).
- FROM 소스: `Core/Physics/` 3파일 — **LowLevelPhysicsHelper.cs / PhysicsLayerMapping.cs / WallBoundaryPhysicsBody.cs**.
- **TO 검증 결과:**
  - `Core/Physics/` 디렉터리 **없음**.
  - `namespace MarinRPG.Physics` / `LowLevelPhysicsHelper` / `PhysicsBody`(저수준) **0건**.
  - TO `BaseEnemyController`는 **표준 Unity `Collider2D` + `OnTriggerStay2D` + `CircleCollider2D`** 방식(923/1063행). 즉 BD와 WD의 적 타격 판정 메커니즘이 **근본적으로 다름**.

### 처리 방안 (택1, Phase3 결정 필요):
- **(A) 동반 이식** — `Core/Physics/LowLevelPhysicsHelper.cs` + `PhysicsLayerMapping.cs`를 WD로 이식. 단 BD 전역 적/발사체 히트 판정이 이 저수준 물리에 맞물려 있을 가능성 → **PatternController만 위해 물리 레이어를 들이면 WD 표준 Collider2D 경로와 이중화**. 발사체 owner 캐스팅 경로(`OverlapCircle → GetOwner<BaseEnemyController>`)도 BD 저수준 물리 전제.
- **(B) WD 표준 Collider2D로 재작성** ★권장 — `GuildRaidPatternController`를 **`CircleCollider2D`(trigger) + `BaseEnemyController` 기존 피격 경로**로 다시 짠다. 역할이 단순(타격대상 등록 + 데미지 보스 위임)이라 재작성 분량 적음. WD `DetectionManager.RegisterEnemy/UnregisterEnemy`는 존재(검증 OK)하므로 등록 로직은 그대로, 물리 바디 생성/추적(`Update`의 `_patternBody.position`)만 collider offset 갱신으로 치환.
- `WallBoundaryPhysicsBody.cs`는 레이드와 무관(벽 경계) → 동반 이식 불필요.
- `#if UNITY_6000_5_OR_NEWER` 분기: TO Unity = **6000.2.8f1** → `else` 경로(`UnityEngine.LowLevelPhysics2D`) 사용. (A) 채택 시에도 6000.5 미만이라 `Unity.U2D.Physics` 경로는 비활성.

> **StellaBoss50101Controller도 패턴 객체의 PhysicsBody를 전제**로 함(주석 197/453/602행: "PhysicsBody가 transform을 매 프레임 따라가며 타격"). 단 StellaBoss 자체는 LowLevelPhysicsHelper를 직접 호출하지 않고 PatternController에 위임 → **PatternController만 (B)로 재작성하면 StellaBoss는 영향 최소**.

---

## 3. 보스 컨트롤러 IBossController / BaseBossController 호환성

- TO `BaseBossController`(`Core/Controllers/Enemy/BaseBossController.cs`) + `IBossController`(`Core/Interface/IBossController.cs`) **존재 확인 OK**.
- BD `GuildBossController`가 오버라이드/사용하는 멤버 → **TO BaseBossController에 모두 존재**(시그니처 일치 확인):
  - `InitializeBossAsync()` (protected virtual UniTask) ✅
  - `StartBossLogicAsync()` (virtual UniTask) ✅
  - `OnBossDefeatedAsync()` (virtual UniTask) ✅
  - `PlayEnterAnimationAsync(Vector3)` (virtual UniTask) ✅
  - `GetDesiredSpawnPosition()` (virtual Vector3) ✅
  - `Die()` / `ForceStop()` (override) ✅
  - `_hasMultiplePhases`, `_bossCancellationTokenSource` (protected 필드) ✅
  - `TakeDamage` 4종 오버로드 ✅
- ⚠️ **확인 필요한 TO 멤버** (BD GuildBossController가 base에 있다고 가정하는 것):
  - `AccumulatedDamage` 프로퍼티 — 데미지 라우팅 핵심. TO BaseEnemy/BaseBoss에 존재하는지 Phase3에서 grep 필수. (PunchKing이 AddDamage 방식이라 했으니 PunchKingBossController 경로 비교 필요)
  - `GetDamageTextOrigin()` (protected virtual Vector3) — BD가 오버라이드. TO 존재 여부 확인.
  - `TakeDamage(float, EUnitRaceType, int minionId, Vector3)` 미니언 오버로드 — TO 존재 여부 확인(누락 시 미니언 데미지 라우팅 깨짐).
  - `BaseSystemManager.DamageBase(..., ignoreReflectShield, maxHealthReduction ...)` 시그니처 — 벙커 고정피해. WD `BaseSystemManager` 파라미터 일치 확인 필요.
  - `EnemyData.enemyType == RaidBoss(=5)` enum 값 — WD `EEnemyType`에 RaidBoss 존재 + HP 최소1 불사 로직 동작 확인.
- → 보스 베이스 자체는 **DIRECT(어댑트)**. 단 위 5개 멤버 정합성은 Phase3 grep 검증 항목.

---

## 4. FROM 전용 패턴 / 변환 부담 (레이드 6파일)

| 파일 | ServiceAccessor | MessageBroker/MainInstaller/IMessage | GetPool/Spawn | Geuneda using |
|------|----|----|----|----|
| GuildBossController | 2 | 4 (PublishSafe·MainInstaller.Resolve·IMessageBrokerService) | 0 | `Geuneda.Services` |
| StellaBoss50101Controller | 2 | 0 | 0 | (없음) |
| GuildRaidPatternController | 1 (TryGet) | 0 | 0 | (없음·MarinRPG.Physics) |
| GuildRaidBossEntranceSpawner | 0 | 0 | 0(Instantiate) | (없음) |
| GuildRaidAnimationEventRelay | 0 | 0 | 0 | (없음, C# event) |
| GuildRaidDamageEventData | 0 | 1 (IMessage) | 0 | `Geuneda.Services` |

게임모드 4서비스도 동일: `ServiceAccessor.Get<T>()` → `Managers.Instance.GetManager<T>()`, `MainInstaller.Resolve<IMessageBrokerService>()` + `Subscribe/Unsubscribe/PublishSafe` → **WD `EventManager`(static) Subscribe/Dispatch**로 전면 치환.

- `GuildRaidDamageEventData : IMessage` → WD 이벤트 DTO(POCO)로 바꾸고 `EventManager.Dispatch<GuildRaidDamageEventData>(GameEventType.XXX, data)` 패턴. **PunchKing이 이미 `PunchKingDamageEventData` + `GameEventType.PunchKingDamageUpdated`로 동형 구현** → 그대로 미러.
- `GuildRaidInitialCardSelectionCompleteMessage` / `GuildRaidBossPatternStartedMessage`(MessageBroker 메시지) → WD GameEventType enum 추가 필요. PunchKing의 `GameEventType.PunchKingGameStart` 패턴 미러.
- 풀링(GetPool/Spawn/Despawn): **레이드 6파일 0건**. 보스/패턴은 씬 배치 + `Instantiate`(EntranceSpawner). 풀링 변환 불필요.
- `GameStatisticsManager`(UnitDamageStats/MinionDamageStats/RentalMinionDamageStats/GetGameElapsedTime), `CameraShakeManager`, `EffectManager` 사용 → TO 존재 여부 Phase3 확인(StagePlayService 결산에 필수).

---

## 5. 게임모드 서비스 4종 세부

### GuildRaidModeConfigurator (`: IGameModeConfigurator`)
- `StandardModeConfigurator` 위임(DRY)으로 매니저 목록 재사용 → WD에서도 동일 위임 가능.
- 핵심 로직: `OnBeforeGameStartAsync`에서 ①등장연출(Guild_Boss_Back_Anim Animator normalizedTime>=1) 대기 ②카드 사전준비(`CardManager.ClearInGameCardData/ApplyPreBattleCardEffects/SetPreserveInitialSelection`) ③벙커 생성 ④유닛 스폰 ⑤HUD/레벨 UI ⑥**4중2 × 2회차 첫 진입 카드 선택**.
- `Time.timeScale=1` 고정 후 finally 복원(배속 무관 연출) — 그대로 이식.
- 전역 Find 금지 준수: `SceneManager.GetActiveScene().GetRootGameObjects()` 순회로 EntranceSpawner 탐색.
- 의존: `CardManager.GetCardChoicesArray(count)` / `SetPreserveInitialSelection` / `ApplyPreBattleCardEffects` — WD CardManager 시그니처 일치 확인 필요.

### GuildRaidStagePlayService (`: BaseStagePlayService`)
- 무한 누적형: `CheckClearCondition()=false`, `TryProcessClearCondition()=false`. 종료는 벙커파괴(`OnGuildRaidGameOver`)/치트강제(`OnStageCompleted`)만.
- `ProcessWavesAsync` override: 보스 1회 스폰(`SpawnBossForWaveAsync`) 후 잡몹 웨이브를 시트 타임라인으로 순환(소진 시 마지막 반복).
- `SyncWaveDataState`로 `_currentWaveData/_currentWaveIndex` + `_context.SyncCurrentWaveData` 동기화(override 경로라 base 자동 동기 안 탐).
- 결산: `GameResultData.FromGuildRaid(...)` 호출 → **TO엔 `FromPunchKingResult`만 존재, `FromGuildRaid` 없음** → **GameResultData에 `FromGuildRaid` 정적 팩토리 + `GuildRaidTotalDamage` 필드 추가 필요**.
- `GuildManager.SubmitRaidClear(damage)` / `CachedRaidStatus.BossId` 호출 → 길드 매니저(다른 Phase2 담당)와 인터페이스 정합 필요.
- `BaseStagePlayService` 멤버(`_currentStageData`/`_currentWaveData`/`_currentWaveIndex`/`_isActive`/`_context`/`_hasReachedLevel20`/`SpawnBossForWaveAsync`/`HandleLevelUp`) — WD base에 존재하는지 grep 확인(PunchKing/RaceTower가 같은 base 상속하므로 대부분 존재 예상).

### GuildRaidGameModeUIService (`: BaseGameModeUIService` — TO 없음)
- 누적 피해 패널/텍스트 DOTween 카운트업(`SetUpdate(true)`로 timeScale 무관). 카운트다운/신기록 없음.
- → **GameUI.cs 인라인 분기로 재작성** (PunchKing 데미지 HUD 미러).

### GuildRaidGameResultService (`: StandardGameResultService` — TO 없음)
- 점수=`GuildRaidTotalDamage.ToString("N0")`, 라벨=`damage_dealt`(펀치킹 공유 로컬키), 제목=`guild_raid_result_title`, 색=cyan.
- 항상 성공 오버레이(SuccessOverlay on/FailureOverlay off), 재도전/2배보상/VIP/신기록 전부 숨김.
- → **GameResultUI.cs 인라인 분기로 재작성** (RaceTower 인라인 region 미러).

---

## 6. 분류 요약

| 분류 | 개수 | 파일 |
|------|------|------|
| **DIRECT** (순수 SO·DTO·MonoBehaviour, 의존성 단순) | 4 | GuildRaidEntranceConfigSO, GuildBossUIPrefabRegistrySO, GuildRaidBossEntranceSpawner, GuildRaidAnimationEventRelay |
| **ADAPTED** (ServiceAccessor/MessageBroker→Managers/EventManager 치환, 베이스 존재) | 5 | GuildBossController, StellaBoss50101Controller, GuildRaidDamageEventData, GuildRaidModeConfigurator, GuildRaidStagePlayService, GuildRaidInitialSelectionData |
| **PARTIAL/재작성** (TO에 베이스/메커니즘 없음) | 3 | GuildRaidPatternController(저수준 물리→Collider2D 재작성), GuildRaidGameModeUIService(→GameUI 인라인), GuildRaidGameResultService(→GameResultUI 인라인) |
| **선택(#if DEV)** | 13 | 치트 13개 — 레이드 전투 무관, 길드 일반 도메인 |

(위 ADAPTED에 InitialSelectionData 포함 시 일부 중복 카운트, 코어 전투 13 + 치트 13)

---

## 7. 주의사항 / Phase3 검증 항목

1. **★ 저수준 물리(LowLevelPhysicsHelper) — TO 전무.** 권장=GuildRaidPatternController를 WD `Collider2D` 경로로 재작성(B안). 물리 레이어 통째 이식(A안)은 WD 표준 충돌계와 이중화 위험.
2. **★ 게임모드 서비스 = PARTIAL.** Configurator/StagePlay 2종은 WD 동일 패턴 직접 이식(Managers.cs 모드분기·StageManager 필드/게이트 추가). GameModeUI/GameResult 2종은 GameUI/GameResultUI 인라인(문서 통합방향 일부 맞음, 단일매니저 통합은 불필요).
3. `GameResultData`에 **`FromGuildRaid` 팩토리 + `GuildRaidTotalDamage` 필드 추가** 필수(TO엔 FromPunchKingResult만 있음).
4. `GameModeType`에 **GuildRaid 추가** + 스테이지 ID 대역 결정(PunchKing 7000번대 패턴 참고). `StageManager.HandleGameOver`/`StartStage` GuildRaid 게이트.
5. **GameEventType enum 추가**: GuildRaidDamageUpdated / GuildRaidBossPatternStarted / GuildRaidInitialCardSelectionComplete (BD MessageBroker 메시지 3종 대체). PunchKing 이벤트 미러.
6. BaseBossController 정합 grep: `AccumulatedDamage`, `GetDamageTextOrigin`, minionId TakeDamage 오버로드, `EEnemyType.RaidBoss` 불사 로직, `BaseSystemManager.DamageBase` 확장 파라미터(ignoreReflectShield/maxHealthReduction).
7. `CardManager` 정합: GetCardChoicesArray / SetPreserveInitialSelection / ApplyPreBattleCardEffects / ClearInGameCardData.
8. 매니저 정합: GameStatisticsManager(UnitDamageStats/MinionDamageStats/RentalMinionDamageStats/GetGameElapsedTime), CameraShakeManager, EffectManager, DetectionManager(RegisterEnemy/UnregisterEnemy ✅존재).
9. `Geuneda.Services` using 제거 + `IMessage`/`IMessageBrokerService`/`PublishSafe`/`MainInstaller` 전면 치환(레이드 6파일 중 2파일 + 게임모드 3서비스).
10. **GuildBossScene 전용 씬** + 등장연출 프리팹/레지스트리 SO(.asset) 와이어링 — Phase5(프리팹/씬) 영역. PatternController가 SerializeField로 보스에 4개 배선(`_fistPattern/_axePattern/_handLeft/_handRightPattern`).
11. 치트는 `#if DEV` 라 컴파일 분리 가능 — 레이드 MVP에서 제외해도 본 빌드 무영향. `IGuildCheatRuntime : ICheatRuntime`(TO에 ICheatRuntime/CheatManager 존재 확인) → 별도 이식 가능하나 길드 일반 도메인이라 본 레이드 작업과 독립.
12. 풀링 0건 — 변환 불필요. `EntranceSpawner`는 `Instantiate` 직사용(연출은 영속 배경, 풀 부적합).
