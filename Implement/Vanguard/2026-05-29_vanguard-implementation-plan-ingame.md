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

## 2. 공정성 / 시드 모델

| 모델 | 방식 | 채택 |
|---|---|---|
| A. 점수 기반 (느슨) | 각자 자기 시드로 플레이, 정규화 점수 비교. 고스트는 체감용 | ✅ v1 |
| B. 동일 시드 (엄격) | 매치 시드 공유 + 클론 재시뮬 | 후순위 |

**시드 RNG 규칙 (중요)**
- 매치 전용 `System.Random(matchSeed)` 인스턴스 사용.
- `UnityEngine.Random` **절대 금지** — 전역 시드라 녹화/재생 불일치 유발.
- 적 draw, 카드 draw 등 전투 내 모든 랜덤은 이 인스턴스 경유.

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

### 5-1. 공유 웨이브 (6 Regular + 2 Elite)
- 기존 `StageManager`의 `WaveDataSO` + Ark 모드의 동적 웨이브 생성(`clonedWaveData`) 패턴 재사용.
- 웨이브 구성을 `System.Random(matchSeed)`로 결정적 draw.

```csharp
var rng = new System.Random(matchSeed);
int regularId = regularPool[rng.Next(regularPool.Count)];
int eliteId   = elitePool[rng.Next(elitePool.Count)];
```

### 5-2. 라운드 시작 카드 1장
- 기존 `CardManager` 큐/가중치 시스템 재사용. 라운드 시작 시 시드 RNG로 1장 강제 지급.
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
                _cardManager.GrantRandomCard(ECardPool.ComboOrT3Chain);
        }
    }
}
```
- `EnemyManager.AliveEnemyCount` 기존 프로퍼티 재사용.
- v1 점수모델에선 고스트 적 수가 다른 시드 기준 → 체감/연출용 (모델 A 트레이드오프).

### 5-4. Berserk Mode (60초 — 적 CC 면역)
```csharp
// 60초 경과 시 플래그 ON
_berserkActive = true;

// BaseEnemyController.Skill / DebuffController 디버프 적용부 가드
public void ApplyDebuff(DebuffType type, ...)
{
    if (IsControlDebuff(type) && VanguardContext.IsBerserk) return; // CC 무효
    ...
}
```

### 5-5. Termination Mode (120초 — 양측 -1000 HP/s)
```csharp
if (_elapsedTime >= 120f)
{
    float drain = 1000f * Time.deltaTime;
    _baseSystemManager.CurrentBase.TakeDamage(drain); // 내 요새 (기존 메서드)
    _ghostPlayer.ApplyTerminationDrain(drain);         // 고스트 요새도 동일 감소
}
```
- `BaseController.TakeDamage()` 기존 메서드 재사용.

### 5-6. 요새 70% 이하 피해 면역 (칩 #5)
- `BaseController`에 이미 `CheckAndTriggerImmunity()` / 위급 면역 칩 로직 존재.
- Vanguard 칩 6종을 `ChipManager` 데이터로 추가하면 기존 `ChipEffectManager` 경로 탑승.

### 5-7. 칩 #6 (치명타 시 최대HP % 추가피해)
- 데미지 파이프라인은 가산(additive) 원칙 (CLAUDE.md): `total = base + (stack - 1)` 형태.
- ⚠️ 곱연산(`finalDamage *= ...`) 금지.

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

| 기능 | 처리 |
|---|---|
| 적 스폰/이동/HP | ✅ `EnemyManager` + `EnemyMovementComponent` 재사용 (이미 transform 이동) |
| 요새 HP/피격/면역 | ✅ `BaseController` / `BaseSystemManager` 재사용 |
| 카드 | ✅ `CardManager` 재사용 + Vanguard 풀 분기 |
| 칩 효과 | ✅ `ChipManager` / `ChipEffectManager` 재사용 + 신규 칩 6종 데이터 추가 |
| 데미지 계산 | ✅ `DamageCalculationManager` 재사용 |
| 웨이브 진행 | ✅ `StageManager.ProcessWavesAsync` 재사용 + 분기 (Ark 패턴) |
| **전투 플로우 제어** | 🆕 `VanguardStagePlayService` |
| **상대 고스트 재생** | 🆕 `VanguardGhostPlayer` (전투 로직 없음) |
| **녹화** | 🆕 `VanguardReplayRecorder` |
| **시드 RNG** | 🆕 매치 전용 `System.Random` |
| **스플릿 카메라(v2)** | 🆕 `cullingMask` 레이어 분리 |

---

## 10. 핵심 클래스 스켈레톤

```csharp
// VanguardStagePlayService.cs — StageManager 내부 인스턴스화 (PunchKingStagePlayService 패턴)
public class VanguardStagePlayService
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

    public async UniTask StartVanguardBattleAsync(VanguardMatchData match, CancellationToken token)
    {
        _matchRng = new System.Random(match.matchSeed);
        _ghostPlayer = new VanguardGhostPlayer();
        _ghostPlayer.LoadReplay(match.opponentClone);
        _recorder = new VanguardReplayRecorder();
        _recorder.BeginRecording(match.matchSeed, GetMyLoadoutSnapshot());

        await RunRoundsAsync(token); // 기존 ProcessWavesAsync 골격 + Vanguard 분기
    }

    public void UpdateBattle(float dt) // GameUI Update 루프에서 호출
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
}
```

```csharp
// VanguardManager.cs (아웃게임이지만 전투 진입 트리거 담당)
public class VanguardManager : BaseManager
{
    private VanguardService _service;

    public VanguardLoadout MyLoadout { get; private set; }
    public int MyScore { get; private set; }
    public EVanguardTier MyTier { get; private set; }

    public async UniTask<VanguardMatchData> FindMatchAsync(EVanguardMode mode)
    {
        var popup = ServerLoadingPopupUI.Show(
            LocalizationManager.GetLocalizedText("vanguard_matching"));
        try { return await _service.RequestMatchAsync(mode, MyScore, MyTier); }
        finally { ServerLoadingPopupUI.Hide(); }
    }
}
```

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
