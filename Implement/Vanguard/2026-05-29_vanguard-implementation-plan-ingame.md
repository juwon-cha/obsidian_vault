# Project Ember Vanguard 구현 계획 - 인게임 (2026-05-29)

> 상위 문서: [[2026-05-29_vanguard-implementation-plan-overview]]
> 짝 문서: [[2026-05-29_vanguard-implementation-plan-outgame]]

인게임(전투) 영역: 전투 모델, 진행 플로우, 고스트 재생, 메커니즘 매핑, 녹화, 치팅 방지, 클래스 설계.

---

## 1. 전투 모델 — 클론 고스트 레이스 `[설계 판단]`

```
상대 = 녹화된 고스트 (살아있는 네트워크 객체 X)
- 전투 시작 전: 상대 클론 데이터 1회 다운로드
- 전투 중: 네트워크 0회, 상대는 로컬 재생
- 전투 종료 후: 결과 1회 업로드 + 내 전투가 다음 사람의 클론이 됨
```

마리오카트 고스트 / 트랙매니아 페이스라인과 동일 개념. 나는 내 전투를 실제로 플레이하고, 상대 기록과 나란히 달린다.

**이 모델이 회피하는 문제**
- `Managers.Instance` 싱글톤 → 두 번째 전투 시뮬 불필요 (상대는 재생)
- 적 이동 비결정성(`Time.deltaTime`, float) → 재현이 아니라 재생이라 무관
- 실시간 서버 → HTTP 요청/응답만으로 충분

---

## 1-A. 전투 아키텍처 패턴 (씬 재활용 + 패턴 선택)

### 씬 — GameScene 재활용 (새 씬 불필요)

WiggleDefender는 모든 인게임이 단일 GameScene을 모드별로 재활용한다. Vanguard 스플릿뷰도 **새 씬 없이** 이 구조를 그대로 쓴다. 근거:

```
스플릿뷰는 "두 개의 전투 월드"가 아니다.
  위(Self) : 내 실제 전투 — EnemyManager 1개, 기존 그대로
  아래(Ghost): 고스트 재생 UI 패널 — HP바/적수 재생, 시뮬레이션 아님
→ GameScene은 여전히 전투 월드 1개만 구동 (싱글톤 충돌 없음)
```

- **인게임 UI는 씬에 박힌 게 아니라 `UIManager.Show<T>()` 프리팹 구동** — 모드별로 다른 UI를 띄운다(`ArkGameResultUI` 등 선례). → Vanguard 스플릿뷰 = 신규 UI 프리팹 `VanguardBattleUI` 하나.
- **모드별 카메라/레이아웃 변형 선례 존재**: `Utils/InGameModeVariant.cs`가 360모드에서 카메라 `orthographicSize`·배경을 변형. 스플릿 카메라(상/하 뷰포트)도 같은 자리에서 `GameModeType.Vanguard` 분기로 처리.
- 고스트(아래)는 `VanguardGhostPlayer`(4장)의 UI 재생이므로 **GameScene에 추가 월드/매니저를 띄우지 않는다.**

> 결론: **GameScene + `VanguardBattleUI` 프리팹 + 카메라 뷰포트 변형**으로 스플릿뷰 구현. 새 씬 제작 불필요.

### 패턴 — 하나가 아니라 레이어별 하이브리드

이 프로젝트는 이미 세 패턴을 레이어별로 섞어 쓰며, 본 계획도 그 방향으로 수렴해 있다.

| 패턴 | 적용 범위 | 프로젝트 대응 |
|---|---|---|
| **Session Context (payload)** | ✅ **주축** | `VanguardMatchData` payload + 결과 콜백(`SubmitResultAsync`). 클론고스트+HTTP req/res 모델과 1:1 |
| **Strategy / DI** | ✅ **Match/Duel 차이에만** | `StagePlayService`가 이미 모드별 폴리모픽. 그 안에서 Match/Duel은 작은 `IVanguardMatchProcessor`로 |
| **FSM Flow** | ✅ **전투 페이즈에만** | normal→Berserk(60s)→Termination(120s). PunchKing `CheckEnrageCondition` 선례. **신규 글로벌 FlowManager는 만들지 않음** |

**왜 이 조합인가**
- **Session Context 주축**: Vanguard 본질이 "서버 payload 수신 → 전투 → 결과 송신". 상태를 클라에 박지 않고 payload로 흘리는 게 정확히 맞음.
- **Strategy는 좁게**: 전투 전체를 추상화하면 과함. Match/Duel이 실제로 갈리는 건 **입장료 소모 · 보상 계산 · 랭킹 포인트** 3가지뿐. 전투 씬은 이를 모름.
- **FSM 신규 금지**: Lobby→Entry→Combat→Result는 이미 `로비UI → 매칭 → SceneManager.LoadGameScene → StagePlayService → 결과`로 기존 매니저가 처리. 별도 FlowManager는 책임 중복. FSM이 필요한 건 전투 내부 페이즈뿐 → `VanguardStagePlayService` 내 시간 게이트.

```csharp
// payload에 전략을 실어 보낸다 (Context + Strategy 결합)
public class VanguardMatchData
{
    public EVanguardMode mode;                 // Match / Duel
    public IVanguardMatchProcessor processor;  // 입장료/보상/랭킹만 담당 (전투 무관)
    public VanguardReplayData opponentClone;   // 고스트 재생용
    public int matchSeed;                      // 부수 무작위용 고정 시드
    public Action<VanguardResult> onComplete;  // 전투 종료 콜백 (= 결과 송신)
}

/// <summary>Match/Duel 차이만 담당. 전투 로직과 분리.</summary>
public interface IVanguardMatchProcessor
{
    bool TryConsumeEntry();                     // Match: ExtraReward 차감 / Duel: Dual Token 차감
    VanguardReward CalculateReward(VanguardResult result);
    int CalculatePointDelta(VanguardResult result, int opponentRank);
}
// → NormalMatchProcessor / DuelMatchProcessor 2구현체
```

> `VanguardStagePlayService`(10장)는 `VanguardMatchData`를 받아 전투만 구동하고, 종료 시 `onComplete`로 결과를 던진다. 입장료/보상/랭킹은 `processor`가, 페이즈 전이는 서비스 내부 시간 게이트가 담당한다.

---

## 2. 공정성 / 시드 모델 (위키 기준 — 고정 공유 시나리오)

**위키 규칙 — 카드 세트·적 구성은 모든 플레이어 동일**
- 위키 원문: *라운드별 터렛 카드 세트 고정, 모든 플레이어 동일.* / *라운드당 일반 6 + 정예 2, 모든 플레이어 동일.*
- 즉 카드 세트와 적 구성은 **무작위가 아니라 그 주차에 결정론적으로 고정·공유**된다.

**공정성 모델 — "고정 공유 시나리오 + 점수 비교"**
- 모든 플레이어가 **동일한 카드 세트 + 동일한 적 구성**을 상대한다 → 시드 운 편차가 원천적으로 없음.
- 각자 자기 시간에 같은 시나리오를 플레이하고, **점수**(생존시간/잔여HP/처치수)로 비교한다.
- 상대(클론)는 같은 시나리오를 플레이한 녹화 고스트 → 직접 비교 가능 (시드 일치 문제 없음).
- 이 모델은 기존 "A(느슨)/B(엄격)" 구분을 대체한다: **시나리오가 고정 공유이므로 A의 단순함 + B의 공정성을 동시에 확보.**

**구현 방침 (위키 준수)**
- 카드 후보 세트·적 구성은 **서버가 내려준 주차 고정 세트**를 그대로 사용. 클라이언트가 임의 draw하지 않는다.
- `UnityEngine.Random` **절대 금지**. 세트 내에서 순서/위치 등 부수적 무작위가 필요하면 서버가 내려준 고정 시드로 `System.Random` 사용 (녹화/재생 일치 보장).

---

## 3. 전투 진행 플로우

```
① VanguardService.RequestMatchAsync() → { matchId, opponentClone, matchSeed }
② 상대 클론(고스트 데이터) 로컬 보관
③ SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, vanguardStageId)
④ StageManager → VanguardStagePlayService.StartVanguardBattleAsync()
     - matchSeed 로 System.Random 초기화
     - VanguardGhostPlayer.LoadReplay(opponentClone)  → 상대 패널 재생 시작
     - VanguardReplayRecorder.BeginRecording()          → 내 전투 녹화 시작
⑤ 전투 진행 (기존 ProcessWavesAsync 골격 재사용 + 분기)
     - 라운드마다 6 Regular + 2 Elite draw (시드 기반)
     - 라운드 시작 시 랜덤 카드 1장
     - 20/40/60s: Adversity Boost 체크
     - 60s: Berserk (적 CC 면역)
     - 120s: Termination (양측 요새 HP -1000/s)
⑥ 종료 조건 도달 → 점수 산출
⑦ VanguardService.SubmitResultAsync() → { win, pointDelta, newScore, newTier, rewards }
     - 동시에 내 replayData가 "다음 사람의 클론"으로 서버 저장
```

---

## 4. 상대 고스트 표현 — 2단계

### v1 — 미니멀 (추천)

전투 로직 없이 **HP바 + 생존 적 수 + 로드아웃 아이콘**만 재생. `EnemyManager` 전혀 사용 안 함 → 싱글톤 충돌 0.

```csharp
// VanguardGhostPlayer.cs
public class VanguardGhostPlayer
{
    private VanguardReplayData _replay;
    private float _elapsedTime;

    public float CurrentFortressHp { get; private set; }
    public int   CurrentAliveCount { get; private set; }

    public void LoadReplay(VanguardReplayData replay) => _replay = replay;

    public void UpdateGhost(float deltaTime)
    {
        _elapsedTime += deltaTime;
        CurrentFortressHp = SampleCurve(_replay.fortressHpCurve, _elapsedTime);
        CurrentAliveCount = SampleCurve(_replay.aliveCountCurve, _elapsedTime);
    }

    public void ApplyTerminationDrain(float drain)
        => CurrentFortressHp = Mathf.Max(0f, CurrentFortressHp - drain);
}
```

### v2 — 리치 (폴리시, M6)

상대 측에 적 스프라이트를 녹화 위치대로 띄움 (전투 로직 없는 순수 비주얼). 카메라 분리:
```
카메라 A (내 전투):    cullingMask = "VanguardSelf"
카메라 B (상대 고스트): cullingMask = "VanguardGhost"
고스트 적 → 녹화 position 샘플 보간 이동, HP/충돌/AI 전부 없음
```

---

## 5. 위키 메커니즘 → 구현 매핑

### 5-1. 공유 웨이브 (6 Regular + 2 Elite — 전 플레이어 동일) `[코드 검증 반영]`
- 위키 기준 적 구성은 **모든 플레이어 동일한 고정 세트**. 서버가 주차/라운드별 웨이브 구성을 내려준다.
- 기존 `WaveDataSO` 재사용하되 **구성은 서버 제공 고정값**을 그대로 주입.
- ⚠️ **웨이브 엔진이 둘이다 — Vanguard는 `BaseStagePlayService` 경로 채택**:
  - `StageManager.ProcessWavesAsync()`(private, `:1012`) = 일반/Ark/RaceTower용.
  - `BaseStagePlayService.ProcessWavesAsync()`(`StageServices/BaseStagePlayService.cs:125`) = **PunchKing이 상속**하는 서비스 경로. Vanguard도 이걸 상속.
  - 6 Regular + 2 Elite 라운드 구성은 `BaseStagePlayService`의 오버라이드 훅 `SpawnEliteAndBossAsync():241` / `SpawnElitesForWaveAsync():268`에서 주입(깨끗한 오버라이드 지점). 적 스폰은 `EnemyManager.StartWaveSpawnAsync(WaveDataSO):188` / 위치지정 `SpawnSingleEnemyAtPositionAsync(id, pos, giveExp):1643`.
  - 진입: `StageManager.StartStageWithStageDataAsync():838`의 모드 분기(`:924-961`, RaceTower/PunchKing 분기가 있는 자리)에 `GameModeType.Vanguard` 분기 추가 → `_vanguardStagePlayService`로 위임. 서비스 필드는 `StageManager.InitializeAsync():26-32`에서 `new VanguardStagePlayService(); .Initialize(this)`(this=`IStageServiceContext`).

```csharp
// 서버가 내려준 고정 웨이브 구성을 그대로 사용 (클라 임의 draw 금지)
foreach (var round in serverWaveConfig.rounds)
{
    // round.regularIds (6), round.eliteIds (2) — 전 플레이어 동일
}
```

**적 스탯 스케일링 (위키 신규 — 중요)** `[코드 검증 반영]`
- 적 HP/공격은 **현재 티어에 따라 스케일링**된다 (티어 높을수록 강함).
- 적이 **텔레포트할 때마다 HP·공격이 증가**한다.
- **티어 스케일링 — 권장 구현(컨트롤러 수정 0):** 적 스탯은 `BaseEnemyController.ApplyStageAndWaveCoefficients(EnemyDataSO):1191`에서 `enemyData.maxHealth/attackDamage × StageManager.GetStageHealthCoefficient() × waveCoeff`로 산출되고 `FinalMaxHealth/FinalAttackDamage/CurrentHealth`(`:1235-1237`)에 들어간다. `GetStageHealthCoefficient():2022`는 `CurrentStageData.stageHpCoefficient × _currentDynamicBalanceHpMultiplier`. → **티어별 `stageHpCoefficient/stageAtkCoefficient`를 가진 Vanguard `StageDataSO`를 `BuildStageData`에서 만들면** 적 컨트롤러를 건드리지 않고 티어 스케일이 전파된다(가장 깨끗). Ark의 `_currentDynamicBalanceHpMultiplier`(`StageManager.cs:524`, `CalculateDynamicBalanceHpMultiplier():2419`)와 동일한 주입 경로.
  - ⚠️ HP 동적배율은 `stageHpCoefficient`에만 곱해지고 **ATK 동적배율은 없음**(ATK는 `stageAtkCoefficient`만). 티어 ATK 스케일이 필요하면 `GetStageAttackCoefficient()` 경로에 동형 배율을 추가하거나 `BuildStageData`의 `atkCoeff`에 티어배율을 곱해 둔다.
- **텔레포트 시 스탯 증가 — 훅 위치:** 적 텔레포트는 `EEnemySkillType.TeleportShield`(`EEnemyTypes.cs:75`) → `TeleportShieldSkill`(`Skills/TeleportShieldSkill.cs`). 발동 진입은 `BaseEnemyController.CheckAndActivateTeleportShield(finalDamage):360`, 실제 텔레포트는 `TeleportShieldSkill.ActivateTeleportShieldAsync():134`. → **여기서 `_owner.FinalAttackDamage *= x; _owner.FinalMaxHealth *= x; _owner.CurrentHealth *= x;`** 추가(런타임 배율 선례: `BaseEnemyController.DevMultiplyHealth():989`).

### 5-2. 라운드 시작 카드 (세트는 전 플레이어 공유) `[코드 검증 반영]`
- ⚠️ 위키: **라운드별 터렛 카드 세트는 그 주차에 고정·전 플레이어 동일**. 무작위 풀이 아님.
- 따라서 카드 후보 세트는 **서버가 내려준 주차 고정 세트**를 사용. 그 세트 내에서의 draw(어떤 1장)는 `matchSeed` 기반.
- 기존 `CardManager`(`Core/Managers/CardManager.cs`) 큐/가중치 시스템 재사용하되, 풀을 Vanguard 고정 세트로 치환.
- ⚠️ **메서드명 정정**(계획의 `GrantRandomCard`/`GetCardChoicesArray`는 미존재):
  - 후보 N장 생성: `GeneratePunchKingCardChoices(int count):2319` (public, `SelectCardsByWeight` 경유) — 이걸 복제/재사용해 `GenerateVanguardCardChoices` 작성.
  - 랜덤 1장: `GetRandomArkCard(ECardType):142` / `GetRandomArkCardFiltered(ECardType, Func):175`.
  - 선택 적용: `SelectCard(int choiceIndex):3290`(`CurrentChoices[idx]` 읽음) → 내부 `ApplyCardEffect():3531`.
  - 라운드별 초기 선택 루프는 **서비스가** 구동(`PunchKingStagePlayService.ShowInitialCardSelectionsAsync():138` — 라운드마다 `GeneratePunchKingCardChoices` + `Show<CardSelectionUI>` + `WaitUntil` 패턴). Vanguard도 동일 패턴.
  - 사전 적용/초기화: `ApplyPreBattleCardEffects():1063`, `ClearInGameCardData():1023`, `SetPreserveInitialSelection(bool)`.
- 뽑은 카드(라운드, cardId)를 `Recorder`에 기록 → 클론 재현 가능.

### 5-3. Adversity Boost (20/40/60초)
```csharp
private void CheckAdversityBoost()
{
    foreach (float mark in new[] { 20f, 40f, 60f })
    {
        if (_elapsedTime >= mark && !_checkedBoostTimes.Contains(mark))
        {
            _checkedBoostTimes.Add(mark);
            if (_enemyManager.AliveEnemyCount > _ghostPlayer.CurrentAliveCount)
                GrantVanguardBoostCard(); // GeneratePunchKingCardChoices/GetRandomArkCardFiltered 재사용 (GrantRandomCard 미존재)
        }
    }
}
```
- `EnemyManager.AliveEnemyCount` 기존 프로퍼티 재사용 ✅ 확인(`EnemyManager.cs:107`).
- ⚠️ `GrantRandomCard`는 미존재 → 5-2의 실제 메서드(`GetRandomArkCardFiltered`/`GeneratePunchKingCardChoices`) 사용. Combo/T3 Chain 풀은 `Func<CardDataSO,bool>` 필터로 한정.
- v1 점수모델에선 고스트 적 수가 다른 시드 기준 → 체감/연출용 (모델 A 트레이드오프).

### 5-4. Berserk Mode (60초 — 적 CC 면역) `[코드 검증 반영]`
- **실제 가드 지점**: 디버프는 `BaseEnemyController.ApplyDebuff(EDebuffType, ...):1870` → `DebuffController.ApplyDebuff():164`. 면역 판정이 `DebuffController.cs:177-201`에 이미 있음:
  1. `_cachedPunchKingBoss.IsDebuffImmune(debuffType)` — **런타임 면역 훅**(시간창 면역의 정확한 선례)
  2. `EnemyData.immunDebuffTypes` 정적 면역 리스트(`:189-200`)
- → Berserk(60s) CC 면역은 `IsDebuffImmune`와 동형의 **런타임 면역 플래그/메서드를 적 컨트롤러에 추가**하고 `DebuffController.cs:177` 근처에서 체크. Berserk 창 동안 ON.
- CC로 막을 디버프 타입은 `EDebuffType`의 컨트롤 계열(`Paralysis`/`Slow`/`Overload` 등) — `IsControlDebuff` 헬퍼로 분류.
```csharp
// 60초 경과 시 VanguardManager 또는 StagePlayService가 Berserk 플래그 ON (per-frame 체크는 10장 참조)
// DebuffController.ApplyDebuff 면역 체크부에 추가:
if (IsControlDebuff(debuffType) && _owner.IsVanguardBerserkImmune) return; // CC 무효
```

### 5-5. Termination Mode (120초 — 양측 -1000 HP/s) `[코드 검증 반영]`
```csharp
if (_elapsedTime >= 120f)
{
    float drain = 1000f * Time.deltaTime;
    _baseSystemManager.CurrentBase.TakeDamage(drain); // 내 요새
    _ghostPlayer.ApplyTerminationDrain(drain);         // 고스트 요새도 동일 감소
}
```
- 요새 메서드 실측: `BaseController.TakeDamage(float damage, BaseEnemyController attacker=null):203`, `CurrentHealth`(프로퍼티명 — `CurrentHp` 아님, `:63`), `MaxHealth:79`, `Heal(float):330`, `DestroyBase():361`.
- ⚠️ **드레인은 `TakeDamage` 우회 권장**: `TakeDamage`는 `_isImmune`/`_moduleImmunityCharges`/회피/`ApplyDamageReduction`(`:226/248/268/284`)로 **조기 리턴·감산될 수 있다**. 칩 #5 면역 중엔 Termination 드레인이 무효화돼 버림. → 확정 드레인은 `CurrentHealth` 직접 감산 + `GameEventType.BaseDamaged` dispatch + `CurrentHealth<=0 → DestroyBase()` 경로(`:287-299` 형태)를 별도 메서드로. (기획상 Termination은 면역 무시 드레인이어야 함)
- ⚠️ `_baseSystemManager.CurrentBase` 프로퍼티명은 `BaseSystemManager`(`Core/Managers/BaseSystemManager.cs`) 실 API로 확인 후 사용(요새 컨트롤러 보유 매니저).

### 5-6. 요새 칩 효과 (칩 #4 회복 / 칩 #5 면역) `[코드 검증 반영]`
- **칩 #5 (70% 이하 피해 면역) — 기존 효과와 거의 동일**: `EChipEffectType.BunkerCriticalImmunity(=204)` + `BaseController.ChipEffect.cs:272 CheckAndTriggerImmunity()` 이미 존재. `HealthRatio*100 < effect.effectValue`(임계 %)면 `_isImmune=true; _immunityEndTime = Time.time + effect.subEffectValue;`(면역 지속) + 임계 1회성 기록(`_immunityThresholdsTriggered`). `TakeDamage:245`에서 호출, 만료는 `UpdateImmunityState()`(`Update()` 경유). → Vanguard 칩 #5는 **이 효과 데이터를 그대로 쓰거나**(70%/3·4.5·6s) 신규 `EChipEffectType` 한 줄 추가 후 이 분기 복제.
- **칩 #4 (10초마다 4/6/8% HP 회복) — 신규 인터벌 훅 필요**: 기존 요새 회복은 전부 이벤트성(`BunkerHealOnKill=208`/`BunkerHealOnEliteBossKill=209`/`BunkerHealOnCardSelection=207`)이라 **시간 인터벌 회복은 없음**. → `BaseController.Update()`(`:33`)에 10초 누적기 추가해 `Heal(MaxHealth * pct)` 호출. ⚠️ 위키 정확 — **Termination Phase(120s 후) 회복 비활성**: 틱 적용 시 `_elapsedTime < 120f` 가드 필수(드레인 상쇄 금지).
- Vanguard 칩 6종 효과 enum은 `Core/Data/Enums/ChipEnums.cs`의 `EChipEffectType` 끝에 추가. 적용 경로: `ChipEffectManager.ApplyChipEffect():407` → `_globalChipEffects`/`_unitChipEffects` 적재 → 소비처가 `GlobalChipEffects`(`:57`)/`UnitChipEffects`(`:52`)/`GetTotalEffectValue()`로 조회.

### 5-7. 칩 #6 (치명타 시 최대HP % 추가피해) `[코드 검증 반영]`
- **기존 효과 재활용 — 데미지 공식이 아니라 적 피격 시점에서 처리**: `EChipEffectType.CriticalMaxHealthDamage(=403)` / `CriticalPerMaxHealthDamage`(ChipEnums.cs:198) 이미 존재하고, 적용 메서드가 `BaseEnemyController.cs:384 ProcessCriticalMaxHealthDamage(isCritical, finalDamage, attackerUnitType)`. (대상 max-HP 참조가 필요해 데미지 공식이 아닌 적 컨트롤러 쪽에서 처리.) → Vanguard 칩 #6은 **이 경로를 미러링**(최대배율 2x/3x/4x를 `subEffectValue`로).
- 데미지 파이프라인 자체는 가산(additive) 원칙 (CLAUDE.md): `DamageCalculationManager.CalculateDamageWithAdvancedFormula():170`의 `totalPercentageBonus`에 합산(`:182-185`), 절대 `finalDamage *= ...` 금지. `BaseAttackPower:45` 확인.

### 5-8. 승패 + 점수
```csharp
float myScore = survivalTime              * W_TIME
              + (fortressHpRemaining / fortressMaxHp) * W_HP
              + enemiesKilled             * W_KILL;
// 서버가 myScore vs cloneScore 비교 → 승패 + pointDelta (상대 랭크 보정)
```
종료 조건: 내 요새 HP 0 / 모든 적 처치 / 시간 종료.

---

## 6. 클론 녹화 — "내가 남의 클론이 되는 과정"

모든 플레이어의 전투를 녹화해야 클론 풀이 채워진다.

```csharp
public class VanguardReplayData
{
    public int   matchSeed;
    public VanguardLoadoutSnapshot loadout;     // 9터렛 + 칩 + 강화레벨
    public List<HpSample>    fortressHpCurve;    // 0.5초 간격
    public List<CountSample> aliveCountCurve;
    public List<CardEvent>   cardEvents;         // (라운드, cardId) — v2 재현용
    public VanguardResult    finalResult;        // 생존시간, 잔여HP, 점수, 승리여부
}
```

- 크기: 수 KB (120초 × 2샘플/초). 전투 종료 시 `/vanguard/match/result`에 함께 업로드.
- 서버는 플레이어의 "이번 주 클론"으로 저장 (최고점 유지 or 최신 유지 — 정책 결정 필요).
- **시즌 초기 봇 클론 시드 데이터**(개발자 제작 더미 replay)를 미리 주입 → 매칭 공백 방지.

---

## 7. 치팅 방지

클라이언트가 점수를 제출하므로 서버 검증 필수.

```
1. 점수 상한 검증: 이론상 불가능한 점수(시간/HP/처치수 한계) 거부
2. 체크섬: loadout + seed + result 해시 검증
3. 커브 정합성: fortressHpCurve 단조성, 비정상 점프 탐지
4. replayData 보관 → 의심 계정 사후 재시뮬 감사
```
- 기존 `AntiCheatGuard.cs` 패턴 연계.
- 완전 서버 권위(모델 B)가 아니면 100% 방어 불가하나, 모바일 비대칭 PvP 표준 수준.

---

## 8. 인게임 서버 API

```
POST /vanguard/match/result
  req: { matchId, myScore, replayData, checksum }
  → { win, pointDelta, newScore, newTier, rewards }
```
> 매칭/조회 API는 아웃게임 문서 11장 참조.

---

## 9. 재사용 vs 신규

| 기능 | 처리 | 대응 RaceTower |
|---|---|---|
| 적 스폰/이동/HP | ✅ `EnemyManager`(`AliveEnemyCount:107`, `StartWaveSpawnAsync:188`) + 풀(`PoolManager`) 재사용 | 동일 |
| 요새 HP/피격/면역 | ✅ `BaseController`(`TakeDamage:203`/`CurrentHealth:63`/`Heal:330`/`CheckAndTriggerImmunity` in `.ChipEffect.cs:272`) / `BaseSystemManager` 재사용 | 동일 |
| 카드 | ✅ `CardManager` 재사용 + Vanguard 풀 분기 (`GeneratePunchKingCardChoices:2319` 복제) | 동일 |
| 칩 효과 | ✅ `ChipManager` / `ChipEffectManager`(`ApplyChipEffect:407`) 재사용 + 신규 칩 6종 enum(`ChipEnums.cs EChipEffectType`) 추가. 칩 #5=`BunkerCriticalImmunity(204)`·칩 #6=`CriticalMaxHealthDamage(403)` 기존 재활용 | - |
| 데미지 계산 | ✅ `DamageCalculationManager`(`BaseAttackPower:45`, `CalculateDamageWithAdvancedFormula:170`, 가산 `totalPercentageBonus:182`) 재사용 | 동일 |
| 웨이브 진행 | ✅ **`BaseStagePlayService.ProcessWavesAsync:125` 상속**(PunchKing 경로) — StageManager private 버전 아님 | 동일 |
| 스테이지 데이터 변환 | 🆕 `VanguardStagePlayService.BuildStageData()` (RaceTower와 동일 책임) | `RaceTowerStagePlayService` |
| **전투 플로우 제어** | 🆕 `VanguardStagePlayService` (`StageServices/` 폴더, StageManager가 인스턴스화) | `RaceTowerStagePlayService` |
| **상대 고스트 재생** | 🆕 `VanguardGhostPlayer` (전투 로직 없음) — PvP 고유, StagePlayService 내부 | (없음) |
| **녹화** | 🆕 `VanguardReplayRecorder` — PvP 고유, StagePlayService 내부 | (없음) |
| **시드 RNG** | 🆕 매치 전용 `System.Random` | - |
| **스플릿 카메라(v2)** | 🆕 `cullingMask` 레이어 분리 | - |

> `VanguardStagePlayService`는 RaceTower처럼 "데이터 변환 + 전투 플로우 제어" 책임을 가진다. RaceTower와 다른 점은 고스트 재생/녹화 2개를 내부에 추가로 들고 있다는 것뿐. 위치(`StageServices/`)·인스턴스화 방식(StageManager 내부 `_vanguardStagePlayService`)은 동일.

---

## 10. 핵심 클래스 스켈레톤

> ⚠️ **per-frame 틱 위치 정정 (코드 검증)**: `VanguardStagePlayService`는 **async 전용**이라 매 프레임 `Update`가 없다(`BaseStagePlayService`는 MonoBehaviour 아님). 따라서 아래 `UpdateBattle(dt)`를 "GameUI Update 루프에서 호출"하는 대신, **MonoBehaviour인 `BaseManager.Update()`** 에서 구동해야 한다. 선례: `GameStatisticsManager.Update():113`가 `_gameElapsedTime += Time.deltaTime` 누적 후 페이즈 체크(`PunchKingDungeonManager.CheckEnrageCondition():592`가 `Time.time - _gameStartTime >= _enrageTimeSeconds` 비교). → **20/40/60/120s 페이즈 체크는 `VanguardManager.Update()`(또는 전용 MonoBehaviour)** 에 두고, 거기서 `StagePlayService`의 상태/플래그를 갱신. `BaseStagePlayService`는 라운드 진행(async)만 담당.

```csharp
// VanguardStagePlayService.cs — StageManager 내부 인스턴스화, BaseStagePlayService 상속 (PunchKingStagePlayService 패턴)
// 라운드 진행은 async. 시간 페이즈 체크(UpdateBattle)는 VanguardManager.Update()가 호출.
public class VanguardStagePlayService : BaseStagePlayService // ← PunchKing과 동일 베이스
{
    private EnemyManager           _enemyManager;
    private CardManager            _cardManager;
    private BaseSystemManager      _baseSystemManager;
    private VanguardGhostPlayer    _ghostPlayer;
    private VanguardReplayRecorder _recorder;

    private System.Random _matchRng;
    private float _elapsedTime;
    private bool  _berserkActive;
    private readonly HashSet<float> _checkedBoostTimes = new HashSet<float>();

    private VanguardMatchData _match; // payload 보관 (mode/processor/onComplete 접근)

    public async UniTask StartVanguardBattleAsync(VanguardMatchData match, CancellationToken token)
    {
        _match = match;                                  // Session Context payload
        _matchRng = new System.Random(match.matchSeed);
        _ghostPlayer = new VanguardGhostPlayer();
        _ghostPlayer.LoadReplay(match.opponentClone);
        _recorder = new VanguardReplayRecorder();
        _recorder.BeginRecording(match.matchSeed, GetMyLoadoutSnapshot());

        await RunRoundsAsync(token); // 기존 ProcessWavesAsync 골격 + Vanguard 분기
    }

    public void UpdateBattle(float dt) // VanguardManager.Update()가 호출 (per-frame 틱 위치 정정 참조)
    {
        _elapsedTime += dt;
        _ghostPlayer.UpdateGhost(dt);
        _recorder.Sample(_elapsedTime,
            _baseSystemManager.CurrentBase.CurrentHealth,
            _enemyManager.AliveEnemyCount);

        CheckAdversityBoost(); // 20/40/60s
        CheckBerserk();        // 60s
        CheckTermination(dt);  // 120s
    }

    // 종료 시: Strategy(processor)로 보상/랭킹 산출, payload 콜백으로 결과 송신
    private void OnBattleEnd()
    {
        var result = BuildResult(_recorder, _elapsedTime); // 생존시간/잔여HP/처치수/replay
        var reward = _match.processor.CalculateReward(result);       // Match/Duel별
        result.reward = reward;
        _match.onComplete?.Invoke(result);  // = VanguardService.SubmitResultAsync 트리거
    }
}
```

```csharp
// VanguardManager.cs — RaceTowerManager 조합 패턴 답습
public class VanguardManager : BaseManager
{
    // 모드 전용 세이브 데이터 (Manager가 보유, 서브서비스와 공유)
    private VanguardSaveData _saveData = new VanguardSaveData();

    // 주입용 매니저 캐시
    private ServerTimeManager _serverTimeManager;
    private SaveDataManager   _saveDataManager;
    private CurrencyManager   _currencyManager;

    // 서브서비스 (POCO) — RaceTowerManager.StageService/ShopService... 패턴
    public VanguardSeasonService  SeasonService  { get; private set; }
    public VanguardLoadoutService LoadoutService { get; private set; }
    public VanguardChipService    ChipService    { get; private set; }
    public VanguardShopService    ShopService    { get; private set; }
    public VanguardRankService    RankService    { get; private set; }

    public override async UniTask InitializeAsync()
    {
        await base.InitializeAsync();

        _serverTimeManager = GetManager<ServerTimeManager>();
        _saveDataManager   = GetManager<SaveDataManager>();
        _currencyManager   = GetManager<CurrencyManager>();

        // new + Initialize(의존성 주입) — RaceTowerManager와 동일
        SeasonService = new VanguardSeasonService();
        SeasonService.Initialize(_saveData, _serverTimeManager);

        LoadoutService = new VanguardLoadoutService();
        LoadoutService.Initialize(_saveData, _saveDataManager);

        ChipService = new VanguardChipService();
        ChipService.Initialize(_saveData, _saveDataManager); // 영구칩과 분리된 시즌 인벤토리

        ShopService = new VanguardShopService();
        ShopService.Initialize(_saveData, _currencyManager, _saveDataManager, _serverTimeManager);

        RankService = new VanguardRankService();
        RankService.Initialize(_saveData);
    }

    public override void Cleanup()
    {
        SeasonService = null;
        LoadoutService = null;
        ChipService = null;
        ShopService = null;
        RankService = null;
        base.Cleanup();
    }

    // 전투 진입 트리거 — 서버 매칭은 VanguardServerService 경유
    public async UniTask<VanguardMatchData> FindMatchAsync(EVanguardMode mode)
    {
        var service = GetManager<ServerManager>().VanguardServerService;
        var popup = ServerLoadingPopupUI.Show(
            LocalizationManager.GetLocalizedText("vanguard_matching"));
        try { return await service.RequestMatchAsync(mode, RankService.Score, RankService.Tier); }
        finally { ServerLoadingPopupUI.Hide(); }
    }
}
```

### 스플릿뷰 카메라/UI 구성 (GameScene 재활용)

```csharp
// VanguardBattleUI.cs — 인게임 스플릿뷰. UIManager.Show<VanguardBattleUI>()로 띄움.
// 위(Self)=내 전투 HUD, 아래(Ghost)=상대 고스트 재생 패널. 전투 월드는 1개뿐.
public class VanguardBattleUI : UIBase
{
    [Header("Self (상단, 내 실제 전투)")]
    [SerializeField] private Slider _selfFortressHp;
    [SerializeField] private TextMeshProUGUI _selfAliveCount;

    [Header("Ghost (하단, 상대 재생)")]
    [SerializeField] private Slider _ghostFortressHp;
    [SerializeField] private TextMeshProUGUI _ghostAliveCount;
    [SerializeField] private VanguardGhostPanel _ghostPanel; // v2: 적 스프라이트 재생(선택)

    // VanguardManager.Update() 또는 StagePlayService가 매 프레임 값만 밀어준다
    public void Bind(float selfHp, int selfAlive, float ghostHp, int ghostAlive) { /* ... */ }
}
```

```
// 카메라 구성 — InGameModeVariant 패턴으로 GameModeType.Vanguard 분기
//   기본 모드: 카메라 1대 풀스크린
//   Vanguard : 메인 카메라 rect = 상단 0.5~1.0 (내 전투만 렌더)
//              아래 0.0~0.5 = VanguardBattleUI의 Ghost 패널(UI) 영역
//   ※ 아래는 "두 번째 카메라로 두 번째 월드를 렌더"하는 게 아니라 UI 패널.
//     v2에서 고스트 적 스프라이트를 보여줄 때만 별도 cullingMask 카메라 추가 검토.
```

> 핵심: GameScene은 전투 월드 1개만 구동. 스플릿은 **메인 카메라 뷰포트를 상단으로 줄이고, 하단을 `VanguardBattleUI` 고스트 패널로 채우는** 레이아웃 변형. `InGameModeVariant`가 360모드에서 카메라를 바꾸듯, Vanguard 분기를 같은 자리에 추가한다.

---

## 11. CLAUDE.md 준수 체크리스트 (구현 시)

- [ ] 매니저 접근은 `Managers.Instance.GetManager<T>()` 만
- [ ] 비동기는 UniTask + `Async` 접미사, `async void` 금지
- [ ] 이벤트는 `EventManager` STATIC (GetManager 금지), `Cleanup()`에서 Unsubscribe
- [ ] 시간은 `ServerTimeManager.NowUnscaled` (DateTime.Now 금지)
- [ ] 랜덤은 `System.Random(matchSeed)` (UnityEngine.Random 금지)
- [ ] 데미지 배율은 가산 방식 (곱연산 금지)
- [ ] DataSheet SO 직접 수정 금지 → `{ClassName}Parser.cs`
- [ ] 하드코딩 한/영 금지 → `LocalizationManager.GetLocalizedText()`
- [ ] 신규 필드는 클래스 최상단 필드 영역 끝에 추가

---

## 12. 검증된 인게임 구현 레퍼런스 (2026-05-31 코드 분석)

모든 경로 `Assets/_Project/1_Scripts/` 기준.

### 12-1. 메커니즘 → 실제 훅 지점 매핑

| 메커니즘 | 실제 훅 (파일:라인) | 메모 |
|---|---|---|
| 전투 플로우 베이스 | `StageServices/BaseStagePlayService.cs` (`StartStageAsync:71`, `ProcessWavesAsync:125`, `OnBeforeStageStartAsync:110`) | PunchKing이 상속. Vanguard도 상속 |
| 서비스 등록 | `StageManager.InitializeAsync():26-32` (필드 + `Initialize(this)`), 모드분기 `StartStageWithStageDataAsync():924-961` | `_vanguardStagePlayService` 추가 |
| 6 Reg + 2 Elite | 오버라이드 `SpawnEliteAndBossAsync:241` / `SpawnElitesForWaveAsync:268` | 라운드 구성 주입 |
| per-frame 페이즈(20/40/60/120s) | **`VanguardManager.Update()`**(MonoBehaviour). 선례 `GameStatisticsManager.Update():113`, `PunchKingDungeonManager.CheckEnrageCondition():592` | 서비스(async)엔 Update 없음 |
| 적 티어 스케일 | `BuildStageData`에서 티어별 `stageHpCoefficient/atkCoefficient` → `ApplyStageAndWaveCoefficients:1191` 자동 전파 | 컨트롤러 수정 0 |
| 텔레포트 시 스탯↑ | `TeleportShieldSkill.ActivateTeleportShieldAsync():134` | `FinalAttackDamage/FinalMaxHealth/CurrentHealth *= x` |
| Berserk CC 면역(60s) | `DebuffController.ApplyDebuff():164` 면역체크(`:177-201`)에 런타임 플래그 추가. 선례 `IsDebuffImmune` | `EnemyData.immunDebuffTypes`는 정적면역 |
| Termination 드레인(120s) | `BaseController.CurrentHealth` 직접 감산 경로(면역 우회) | `TakeDamage`는 면역 시 무효화됨 |
| 칩 #4 10s 회복 | `BaseController.Update():33`에 인터벌 누적기 + `Heal()` | `_elapsedTime<120f` 가드 |
| 칩 #5 면역 | `EChipEffectType.BunkerCriticalImmunity(204)` + `BaseController.ChipEffect.cs:272 CheckAndTriggerImmunity()` | 기존 재활용 |
| 칩 #6 크리→maxHP% | `EChipEffectType.CriticalMaxHealthDamage(403)` + `BaseEnemyController.cs:384 ProcessCriticalMaxHealthDamage()` | 기존 재활용 |
| 카드 후보 생성 | `CardManager.GeneratePunchKingCardChoices(int):2319` (복제) | `GrantRandomCard` 미존재 |
| 카드 초기선택 루프 | `PunchKingStagePlayService.ShowInitialCardSelectionsAsync():138` 패턴 | Show+WaitUntil |

### 12-2. 신규 enum 추가 위치

- 칩 효과 6종: `Core/Data/Enums/ChipEnums.cs`의 `EChipEffectType` 끝에 추가.
- 데미지 소비처: 데미지계 칩 → `DamageCalculationManager`, 요새계 칩 → `BaseController.ChipEffect.cs`, 적 피격계 칩 → `BaseEnemyController`. (`ChipEffectManager`가 `GlobalChipEffects`/`UnitChipEffects`로 노출, 소비처가 조회)

### 12-3. 신규 클래스 생성 위치

| 클래스 | 경로 |
|---|---|
| `VanguardStagePlayService : BaseStagePlayService` | `Core/Managers/StageServices/` |
| `VanguardGhostPlayer` / `VanguardReplayRecorder`(POCO) | `Core/Managers/Vanguard/` 또는 StageServices 내부 |
| `VanguardReplayData` / `VanguardLoadoutSnapshot`(DTO) | `Core/Data/Server/` 또는 `Core/Managers/Vanguard/` |
