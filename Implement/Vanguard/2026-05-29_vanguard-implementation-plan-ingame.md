# Project Ember Vanguard 구현 계획 - 인게임

> 최초 작성 2026-05-29 · **2026-06-06 전면 개정**(이 파일이 현행본)
> 상위 문서: [[2026-05-29_vanguard-implementation-plan-overview]]
> 짝 문서: [[2026-05-29_vanguard-implementation-plan-outgame]]
> 개정 근거: **카오스 페스티벌 — 서버 API 명세 (기획서 포함)** + 기획서 5종(플로우/인게임/스테이지보정/티어/매칭) + 위키(원작 FTD) 대조

인게임(전투) 영역: 전투 모델, 진행 플로우, 고스트 생성, 메커니즘 매핑, 검증, 치팅 방지, 클래스 설계.

---

## 0. 개정 요약 (2026-05-29 → 2026-06-06) ⚠️ 필독

원본 계획은 **"녹화/재생(replay) 고스트"** 모델로 작성되었으나, 확정된 서버 API 명세와 매칭/인게임/티어 기획서, 그리고 위키(원작 FTD)는 **"loadout만 저장 + 결정론적 벤치마크(replay 아님)"** 모델로 못박혀 있다. 이 차이가 인게임 아키텍처의 절반을 뒤집으므로, 영향 받는 섹션을 전면 개정한다.

### 0-1. 본질: 비동기 PvP — 상대는 "반응하는 적"이 아니라 "고정된 기준점"
- 매칭은 비동기다. 서버가 상대 클론의 **loadout + match_seed + 라운드 보정**을 내려준다.
- **상대 고스트의 성적은 결정론적 벤치마크**다: `f(상대 loadout, match_seed, 라운드 보정, 자동 카드선택 정책)`. 내 플레이는 이 함수의 인자가 아니다 → 상대 성적표는 매칭 시점에 고정.
- **내 성적표는 내가 실제로 플레이해야 채워진다.** 따라서 승패는 매칭 순간이 아니라 내 플레이로 결정되고, 클라가 결과를 서버에 제출한다. ← **이게 비동기 PvP가 성립하는 이유**(위키 듀얼 화면: 상대는 정적 프로필 + "Points granted if you win" + "There is always a Risk that your opponent can win").
- **결정성 범위 정정(중요)**: 결정성이 필요한 건 **상대 벤치마크뿐**이며, 그것도 계산 위치에 따라 클라 부담이 갈린다(§4 방안 A/B). **내 전투는 결정적일 필요가 없다** — 평소 전투처럼 구동하고 결과만 보고하면 서버가 상한·체크섬으로 검증한다.

| # | 항목 | 원본(2026-05-29) | 확정(2026-06-06, 기획서+명세+위키) | 영향 |
|---|---|---|---|
| C1 | **상대 표현** | 녹화 리플레이 재생(HP/적수 커브 샘플) | **loadout만 저장 → 결정론적 벤치마크**(명세 2-3/2-4/13-4 "과거 기록 재생이 아님") | §1·2·4·6 재작성 |
| C2 | **결정성** | "재생이라 결정성 불필요" | **상대 벤치마크에만** 필요(내 전투는 불요). 위치는 §4 방안 A/B 결정 | §2·4·7 재작성 |
| C3 | **상대 처리 위치** | "재생" | **서버 사전계산 전송(A)** 또는 **클라 시뮬+서버 재시뮬 검증(B)** | §4·10 결정 항목 |
| C4 | **스테이지 보정** | 매치 1개(전투 전체 공통) | **매치당 3개 선정 → Round1/2/3에 1개씩 배정**, 직전 매치와 교집합 ≤1 | §5 신규 5-0 추가 |
| C5 | **120초 페이즈** | Termination(양측 요새 -1000 HP/s) | **2차 광폭화 = 적 이동속도 증가로 확정**(기획서+명세 13-2 일치). 드레인은 위키/구계획 잔재 → 제거 | §5-5 확정 |
| C6 | **점수 산출** | 가중합(생존시간·HP·처치수) 클라 계산 후 비교 | **라운드 BO3 승패 판정**(클리어/생존/동률 타이브레이크) → 서버가 점수표로 산정 | §5-8 재작성 |
| C7 | **결과 API** | `/vanguard/match/result` {myScore, replayData} | **`/vanguard/battle/result`** {rounds[], checksum} (replay 없음) | §8 재작성 |
| C8 | **보너스 카드 조건** | 코드: 내 적수 > 고스트 적수 | 기획서/명세: **내 적수 < 고스트 적수**(내가 우세할 때) | §5-3 로직 반전 수정 |
| C9 | **CPS 초월 점수** | 17 | **20** (매칭 기획서·명세 §11) | §9 수치 정정 |
| C10 | **무승부** | 라운드 동률 시 무승부 처리(구 기획서) | **무승부 없음** — 동시 패배·매치 동률 시 단일 승자 강제 산출 | §5-8 확정 |

**여전히 유효한 자산**: §12의 코드 훅 매핑(적 스폰/요새/칩/카드 경로)은 모델과 무관하게 그대로 쓴다. 바뀌는 건 "상대를 어떻게 만들고 검증하느냐"이지, "내 전투를 어떻게 구동하느냐"가 아니다.

---

## 1. 전투 모델 — 클론 즉석 시뮬 스플릿 레이스 `[전면 개정 C1·C3]`

```
상대 = 상대의 loadout(편성+칩+강화레벨)으로 산출되는 결정론적 벤치마크
- 전투 시작 전: 서버 match/find → 상대 clone의 loadout + match_seed + stage_modifier (+ 방안 A면 상대 타임라인) 수신
- 전투 중:   내 전투(실제 입력)만 실제 구동. 하단 고스트는 벤치마크 타임라인 표시
- 전투 종료: 라운드별 내 결과 업로드 → 서버가 내 결과 vs 상대 벤치마크 비교·정산
- 내 데이터: loadout만 클론 풀에 저장(전투 기록 저장 안 함)
```

> ⚠️ 원본의 "마리오카트 고스트(녹화 재생)" 비유는 폐기. 정확한 비유는 **타임어택의 고정 기준 기록**이다 — 상대 기록은 내 주행과 무관하게 정해져 있고, 나는 내 주행으로 그 기록을 넘느냐를 겨룬다. 비동기 PvP가 성립하는 핵심(§0-1).

**모델이 요구하는 것 (정정 — 원본/이전 개정의 과장 교정)**
- **내 전투에는 추가 제약 없음**: 평소처럼 구동하고 결과만 보고. 결정성·2번째 시뮬 모두 내 전투엔 불요.
- **상대 벤치마크 산출만** 필요하며, 그 위치가 핵심 결정(§4): 서버가 만들어 내려주면(방안 A) 클라는 시뮬·결정성 모두 0이고, 클라가 만들면(방안 B) 그 고스트 시뮬만 결정적이어야 한다.
- `Managers.Instance` 싱글톤(EnemyManager 등)이 1개뿐인 제약은 **방안 A에서 자연 해소**(클라는 내 전투 1개만 구동). 방안 B를 택할 때만 두 번째 시뮬 위치 문제가 생긴다.

> 원본 §1 "이 모델이 회피하는 문제" 중 **실시간 서버 불필요는 여전히 유효**(HTTP req/res로 충분). 싱글톤·비결정성 회피는 방안 A에선 유효, 방안 B에선 부분 재등장.

---

## 1-A. 전투 아키텍처 패턴 (씬 재활용 + 패턴 선택) `[유지]`

원본 그대로 유효하다. GameScene 재활용 + `VanguardBattleUI` 프리팹 + 카메라 뷰포트 변형, Session Context(payload) 주축 + Strategy(Match/Duel) + FSM(전투 페이즈)의 하이브리드. (원본 §1-A 본문 유지)

단 payload 구조는 C1 반영해 `opponentClone`을 **replay 데이터가 아니라 loadout 스냅샷**으로 정정한다:

```csharp
public class VanguardMatchData
{
    public EVanguardMode mode;                 // Match / Duel
    public string battleId;                    // ★ 신규: 서버 세션 멱등 키
    public IVanguardMatchProcessor processor;  // 입장료/보상/랭킹만 담당
    public VanguardLoadoutSnapshot opponentLoadout; // ★ 변경: replay → loadout 스냅샷(고스트 시뮬 입력)
    public int matchSeed;                      // 결정적 시뮬 시드(고스트+부수 무작위 공유)
    public VanguardStageModifierSet stageModifiers; // ★ 신규: 라운드별 보정 3종(§5-0)
    public Action<VanguardResult> onComplete;  // 결과 송신 콜백
}
```

---

## 2. 공정성 / 시드 모델 `[전면 개정 C2]`

**확정 규칙 — 양측 동일 환경에서 각자 시뮬**
- 카드 세트·적 구성은 서버가 시즌 자동 생성으로 고정(명세 §10). 클라 임의 draw 금지.
- 내 전투와 상대 고스트는 **동일 `match_seed` + 동일 `stage_modifier` + 동일 스테이지**에서 시뮬된다. 입력(편성/칩/조작)만 다르다 → 시드 운 편차 없음.
- 상대 고스트는 "녹화 재생"이 아니라 같은 시드로 돌린 결정적 시뮬이므로, **결정성이 깨지면 서버 검증(opp_* 대조)에서 탈락**한다.

**구현 방침 (결정성 범위 — 정정)**
- **내 전투에는 결정성 요구 없음.** 평소 전투처럼 `Time.deltaTime`·물리·일반 RNG 사용 가능. 나는 플레이하고 결과만 보고 → 서버가 상한·체크섬·휴리스틱으로 검증(재현 아님).
- **결정성은 "상대 벤치마크"에만** 필요하다. 그리고 그 부담의 크기는 벤치마크를 어디서 만드느냐에 달렸다(§4):
  - **방안 A(서버 사전계산)**: 클라 결정성 요구 **0**. 서버가 시뮬해 타임라인을 내려주고 클라는 표시만.
  - **방안 B(클라 시뮬)**: **그 고스트 시뮬만** 결정적이어야 함. `UnityEngine.Random` 금지·`match_seed` 기반 `System.Random`·고정 틱 누적·float 순서 보장 + 서버 재시뮬 동치성(허용 오차 밴드 협상).
- 라운드 시작 카드 등 **공유 시나리오의 부수 무작위**는 양안 공통으로 `match_seed` 기반 `System.Random`(클라/서버 동일 산출) — 카드 풀 자체는 서버 고정(§10).

---

## 3. 전투 진행 플로우 `[개정 C1·C4·C7]`

```
① VanguardServerService.FindMatchAsync(MATCH)
     → { battle_id, match_seed, stage_modifier(3종), opponent.loadout }   // §명세 5-1
② 상대 loadout + 라운드별 보정 로컬 보관 (replay 보관 아님)
③ SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, vanguardStageId)
④ StageManager → VanguardStagePlayService.StartVanguardBattleAsync()
     - matchSeed 로 System.Random 초기화
     - VanguardGhostSim.Init(opponentLoadout, matchSeed)  → 상대 고스트 시뮬 준비(§4)
     - (녹화 Recorder 불필요 — 결과는 라운드 집계로 생성)
⑤ 라운드 루프 (BO3, 2승 확정돼도 3라운드 진행)
     - Round r: stageModifiers[r] 적용(§5-0)
     - 6 Regular + 2 Elite (서버 고정 구성)
     - 라운드 시작 시 카드 선택
     - 20/40/60s: 보너스 카드 체크(내 적수 < 고스트 적수)
     - 60s: 1차 광폭화(적 CC 면역)
     - 120s: 2차 광폭화(적 이동속도 증가)
     - 라운드 종료 → 라운드 승패 판정(§5-8)
⑥ 매치 종료 → rounds[] 집계(내 결과 + 고스트 결과)
⑦ VanguardServerService.SubmitBattleResultAsync(battle_id, rounds[], checksum)  // §명세 7-1
     → { win, score_breakdown, new_tier, score_in_division, chaos, rewards, ... }
     - 서버가 내 결과 vs 상대 벤치마크 비교 후 점수·티어 정산(클라는 표시만)
```

---

## 4. 상대 고스트 표현 — 벤치마크 계산 위치 결정 `[전면 개정 C1·C2·C3]`

원본의 v1(HP/적수 커브 재생)·v2(녹화 position 재생)는 **녹화 데이터를 전제**하므로 폐기. 상대는 결정론적 벤치마크이므로 **누군가는 그 성적(타임라인)을 계산**해야 한다. 클라가 표시에 필요한 값은 적고 명확하다: **20/40/60초 시점 생존 적 수**(보너스 카드 트리거용) + **클리어/생존 시각·최종 잔여 적·잔여 HP**(승패 비교용) + HP바 보간용 커브.

### 방안 A — 서버가 벤치마크 계산·전송 (클라 단순 / 권장 1순위)
서버가 매칭 시 상대 loadout을 시뮬해 타임라인 `{alive@20/40/60, clear_time, survival_time, final_enemies_left, final_hp_left, hp_curve}`을 만들어 `match/find` 응답에 실어 내려준다.

```
장점: 클라는 상대 시뮬을 아예 안 함 → 클라 결정성 요구 0.
      내 전투만 구동, 하단 고스트 패널은 받은 타임라인 재생(원본 v1 커브 샘플링 코드 재활용).
      승패·opp_* 비교를 서버가 자기 벤치마크로 수행 → opp_* 클라 보고/검증 불필요.
전제: 서버가 전투 시뮬 보유. ※ 명세는 이미 검증용 서버 재시뮬을 전제하므로,
      그 시뮬로 벤치마크까지 만들면 클라 시뮬을 통째로 제거 가능(중복 제거).
```

### 방안 B — 클라가 고스트 시뮬 + 서버 재시뮬 검증 (명세 문자 그대로)
클라가 상대 loadout을 `match_seed`로 시뮬(헤드리스 or 사전 1회 계산 후 재생)해 고스트를 만들고, 결과의 `opp_*`를 서버가 재시뮬로 대조(불일치 7207).

```
장점: 서버 전투 시뮬 부담이 (전수 생성이 아니라) 검증 샘플링 수준일 수 있음.
단점: 클라 전투 코어를 "결정적 + 렌더 분리 가능"으로 리팩토링(§2 방안 B 조건).
      클라/서버 float 동치성(허용 오차 밴드) 협상 필요.
```

> ⚠️ **설계 결정 (서버팀과)**: A(서버 벤치마크 전송) vs B(클라 시뮬+검증). **A를 권장** — 클라 결정성 부담이 0이고, 서버가 어차피 가져야 할 시뮬을 한 번만 쓰면 되기 때문. 단 서버 전투 시뮬 구현 비용은 서버팀 판단 영역. 스플릿 카메라/UI 레이아웃(원본 §10)은 두 방안 공통으로 유효.

---

## 5. 위키/기획서 메커니즘 → 구현 매핑

### 5-0. 라운드별 스테이지 보정 `[신규 C4]`
명세 2-7 + 스테이지보정 기획서 확정 규칙:
- 매칭 생성 시 **활성 보정 풀에서 중복 없이 3개** 선정 → **Round1/2/3에 1개씩** 배정.
- 동일 경기 내 보정 중복 불가. **직전 매치 보정과 교집합 2개 이상이면 재추첨**(최대 1개까지만 중복 허용).
- 보정 종류: 내성(속성 피해 -), 약점(속성 피해 +), 체력 계수(HP×), 이동속도(+). 속성: FIRE/ELECTRIC/ICE/ENERGY/HUMAN.
- 클라는 보정을 **로비에서 사전 공개**하고, 라운드 진입 시 해당 라운드 보정을 전투에 적용.

```csharp
// payload의 stageModifiers[roundIndex]를 라운드 시작 시 적용.
// 적용 지점: 적 스폰/스탯 산출부(체력계수·이동속도)와 데미지 수신부(내성·약점).
//  - 체력계수 → BuildStageData의 stageHpCoefficient에 곱(§5-1 경로 재사용)
//  - 이동속도 → 적 컨트롤러 이동속도 배율
//  - 내성/약점(속성 피해 증감) → DamageCalculationManager 속성 피해 단계에 가산(곱연산 금지)
```
> 보정값(예: -0.5, ×2.0, +0.2)은 서버가 `stage_modifier.effects[]`로 내려주므로 클라는 수치를 하드코딩하지 않는다.

### 5-1. 공유 웨이브 (6 Regular + 2 Elite) `[유지]`
원본 그대로. `BaseStagePlayService.ProcessWavesAsync():125` 상속(PunchKing 경로), 6Reg+2Elite는 `SpawnEliteAndBossAsync:241`/`SpawnElitesForWaveAsync:268` 오버라이드. 서버 고정 구성 주입, 클라 임의 draw 금지.

**적 스탯 티어 스케일링 / 텔레포트 시 증가** — 원본 §5-1 코드 검증 내용 유지: `BuildStageData`에서 티어별 `stageHpCoefficient/stageAtkCoefficient` 주입(`ApplyStageAndWaveCoefficients:1191` 자동 전파), 텔레포트 증가는 `TeleportShieldSkill.ActivateTeleportShieldAsync():134`에서 `FinalAttackDamage/FinalMaxHealth/CurrentHealth *= x`.

### 5-2. 라운드 시작 카드 `[유지]`
원본 §5-2 유지. `GeneratePunchKingCardChoices(int):2319` 복제 → `GenerateVanguardCardChoices`, 초기 선택 루프는 `PunchKingStagePlayService.ShowInitialCardSelectionsAsync():138` 패턴. 풀은 서버 시즌 고정 세트(명세 §10-2). draw 무작위는 `match_seed` 기반 `System.Random`.

### 5-3. 보너스 카드 (20/40/60초) `[로직 반전 수정 C8]`
기획서(인게임 §5)·명세 13-3 확정 조건: **"내 필드 적 개체수 < 상대(고스트) 필드 적 개체수"** = 내가 더 잘 막고 있을 때 보상.

```csharp
private void CheckBonusCard()
{
    foreach (float mark in new[] { 20f, 40f, 60f })
    {
        if (_elapsedTime >= mark && !_checkedBonusTimes.Contains(mark))
        {
            _checkedBonusTimes.Add(mark);
            // ★ 수정: 원본은 (내 적수 > 고스트 적수)로 부등호가 반대였음
            if (_enemyManager.AliveEnemyCount < _ghostSim.CurrentAliveCount)
                GrantVanguardBonusCard(); // GetRandomArkCardFiltered / GenerateVanguardCardChoices
        }
    }
}
```
- 보너스 풀 = `CardData(해당 유닛) − 시즌 배정 8장`(명세 10-3). 서버가 풀 소속·`match_seed` 산출을 재검증(풀 외/8장 거부).
- 즉석 시뮬 모델에서는 고스트 적수가 **동일 시드 결정 시뮬값**이라 원본 v1의 "다른 시드라 체감용" 트레이드오프가 사라진다(정확 비교 가능). ✅ 개선점.
- 패스(980 다이아) 구매 시 매 라운드 시작 무작위 활성 카드 1장 추가(기획서 인게임 §5).

### 5-4. 1차 광폭화 (60초 — 적 CC 면역) `[유지, 명칭 정정]`
기획서 명칭은 "1차 광폭화". 구현은 원본 §5-4 유지: `DebuffController.ApplyDebuff():164` 면역 체크부(`:177-201`)에 런타임 면역 플래그 추가(`IsDebuffImmune` 동형). CC 계열(`Paralysis`/`Slow`/`Overload`)을 `IsControlDebuff`로 분류해 60초 창 동안 무효.

### 5-5. 120초 페이즈 — 2차 광폭화(적 이동속도 증가) `[확정 C5]`
최신 기획서(플로우·인게임)와 최신 API 명세(13-2)가 **둘 다 "120초 = 2차 광폭화 = 적(꿈틀이) 이동속도 증가"**로 일치. 원본 계획 §5-5와 위키(원작 FTD)의 "Termination = 양측 요새 -1000 HP/s 드레인"은 **구버전 사양 → 제거**한다. (WiggleDefender는 드레인 대신 이동속도 증가로 변경했고, 따라야 할 두 최신 소스가 합의돼 있으므로 확정.)

```csharp
// 2차 광폭화 = 이동속도 증가: 적 컨트롤러 이동속도 배율 ON.
// 60초 1차(CC 면역)와 동일한 per-frame 플래그 게이트(VanguardManager.Update에서 120s 도달 시 ON).
// 적용 지점: 적 컨트롤러 이동속도 산출부에 배율 곱(보정 이동속도와 동일 경로 — §5-0과 합산은 가산 원칙 검토).
```
> 드레인이 제거되므로 **원본 §5-6 칩 #4(인터벌 회복)의 "120초 후 회복 비활성" 가드는 명분이 약해진다.** 위키의 그 가드는 드레인 상쇄 방지용이었음. → 회복을 120초 후에도 유지할지 비활성할지는 밸런스 결정(미세, 기획 확인 권장). 코드상 가드는 플래그 한 줄이라 추후 토글 가능.

### 5-6. 요새 칩 효과 (칩 #4 회복 / 칩 #5 면역) `[유지]`
원본 §5-6 유지. 칩 #5(70% 이하 피해 면역, 위키 = 3/4.5/6초) = `EChipEffectType.BunkerCriticalImmunity(204)` + `CheckAndTriggerImmunity()` 재활용. 칩 #4(10초마다 4/6/8% 회복, 위키 확인) = `BaseController.Update():33`에 10초 누적기 + `Heal()`. 120초 페이즈가 이동속도 증가로 확정되어 드레인이 없으므로 `_elapsedTime<120f` 회복 가드는 필수 아님(§5-5 참조, 밸런스 토글로 보류).

### 5-7. 칩 #6 (치명타 시 최대HP% 추가피해) `[유지]`
원본 §5-7 유지. `CriticalMaxHealthDamage(403)` + `ProcessCriticalMaxHealthDamage():384` 미러링, 가산 원칙(`totalPercentageBonus` 합산).

### 5-8. 라운드 승패 판정 + 점수 `[전면 개정 C6]`
원본의 가중합 점수식(생존시간·HP·처치수 → cloneScore 비교)은 **폐기**. 확정 규칙은 라운드 단위 BO3 승패 판정이다(명세 13-1, 인게임 기획서 §6):

```
라운드 승패 (무승부 없음 — C10 확정):
  1순위 스테이지 클리어: 먼저 전체 적 처치한 쪽 승
  2순위 생존: 한쪽 먼저 요새 파괴(패배) 시 생존자 승
  동시 패배 타이브레이크(단일 승자 강제):
    ① 남은 적 개체수 적은 쪽 → ② 남은 적 체력 총합 적은 쪽
    → ③ 그래도 동일하면 미세 지표(최근 처치/요새 피해 시각)로 단일 승자,
       최종 fallback은 match_seed 기반 결정(동전던지기 대체) — 무승부로 두지 않음
매치: 3라운드 중 2승. 2승 확정돼도 3라운드 진행(보너스 점수 영향).
  매치 1:1:1·동률 상황도 동일 원칙으로 단일 승자(무승부 없음).
```

클라가 서버에 보내는 라운드 데이터(명세 7-1): `result(CLEAR/SURVIVE/LOSE)`, `clear_time`, `survival_time`, `enemies_left`, `enemy_hp_left`, `opp_enemies_left`/`opp_enemy_hp_left`(방안 B일 때만 — 방안 A면 서버가 자체 벤치마크 보유하므로 불필요), `bonus_cards[]`, `turret_damage[]`. **점수(point_delta)는 서버가 점수표(VanguardScoreData)로 산정** — 클라는 산정하지 않고 `score_breakdown`을 표시만 한다.

> **무승부 없음 확정(C10)**: 구 기획서의 "③ 모든 조건 동일 시 무승부 처리"는 폐기. 명세 §13-1/§3 "무승부 없음"을 따라 ③에서 단일 승자를 강제 산출한다(승패 정산은 서버 권위 — 위 규칙은 서버 판정 사양, 클라는 결과 표시).

---

## 6. 클론 저장 — "내가 남의 클론이 되는 과정" `[전면 개정 C1]`

원본의 `VanguardReplayData`(HP 커브/적수 커브/카드 이벤트 녹화)는 **폐기**. 클론은 **loadout만 저장**한다(명세 2-3/2-4, 매칭 기획서 2-1/2-2).

```csharp
public class VanguardLoadoutSnapshot   // 클론 저장 단위 + 고스트 시뮬 입력
{
    public int[] turretSlots;          // 9터렛 편성
    public ChipLoadout chips;          // 장착 칩
    public int atkBoostLevel;          // 전투력 강화 레벨
    // ※ HP/적수 커브·카드 이벤트 등 전투 기록은 저장하지 않음
}
```
- **저장 트리거**: Live Clone = 최초 진입/편성 변경/칩 변경 시 `/vanguard/loadout/save`로 갱신(이전 스냅 삭제). Record Clone = 전투 시작(인게임 진입) 시점 스냅(명세 2-4, 매칭 기획서 2-2).
- 결과 제출이 별도 replay를 만들지 않는다(명세 7-1 비고 8).

### 6-1. 클론 vs 봇 vs 벤치마크 — 3개념 구분 (혼동 주의)
세 가지는 서로 다른 층위다:

| 개념 | 무엇 | 누가/어떻게 만드나 |
|---|---|---|
| **실제 클론**(Live/Record) | 진짜 유저의 loadout 스냅샷 | **클라가 유저 정보(loadout)를 서버로 전송 → 서버가 저장**. Live=loadout/save, Record=전투 시작 시점. ← 평소 상대는 대부분 이것 |
| **봇 클론** | 합성 더미(실제 유저 아님) | 시즌 초반 매칭 공백 메우기용 fallback(명세 §11 탐색 Live→Record→완화→**봇**). **제작 주체는 명세 §17 TBD** — 유저 전송으로 만드는 게 아님 |
| **벤치마크** | 상대(클론이든 봇이든)의 **전투 성적 타임라인** | loadout으로 시뮬한 결과(alive@20/40/60·클리어시각·잔여). §4 방안 A(서버)/B(클라)에서 산출 |

> ✅ "클라가 유저 정보를 서버로 전송해 만든다"는 **실제 클론(Live/Record)** 생성 방식이 맞다. 다만 **봇은 그 경로가 아니다** — 봇은 합성 더미이고 제작 주체가 아직 미정(§17). 그리고 **벤치마크는 클론/봇 자체가 아니라 그 loadout을 시뮬한 성적**이라는 점이 핵심.
> ⚠️ 명세 §11엔 봇이 fallback으로 있지만, **매칭 기획서(Notion)엔 봇 언급이 없고** 시즌 초반 공백은 **Record Clone 유지(브론즈 하위 5%/10%, 명세 §16)**로 해결한다. → 봇을 별도로 둘지, Record 유지로 충분한지 자체가 확인 항목(§13-2에 추가).

---

## 7. 치팅 방지 `[전면 개정 C2]`

원본의 "replayData 보관 후 사후 재시뮬 감사"는 모델 변경으로 핵심이 바뀐다. 확정 방어선(명세 §14):

```
1. battle_id 멱등: RESOLVED 재제출은 저장값 반환, EXPIRED 7206
2. 내 결과 검증: 점수 상한 + checksum(loadout+seed+result 해시) + 이론상 불가 점수 거부
3. 상대 벤치마크는 서버 권위:
   - 방안 A: 서버가 벤치마크를 직접 보유 → 비교 자체가 서버 내부(클라 opp_* 조작 불가)
   - 방안 B: 서버가 상대 loadout 재시뮬해 클라 opp_*와 대조(불일치 7207)
4. 보너스 카드: 풀 소속 + match_seed 산출 검증(풀 외/8장 거부)
5. 매칭 어뷰징: 최근 5회 원본 UID 회피 / 랭크 파밍: 자격 컷 + highest_tier_this_season
```
> **방안 A의 치팅 방어 이점**: 상대 벤치마크가 서버 내부 값이라 클라가 상대 성적을 위조할 여지가 원천 차단된다(opp_* 보고 자체가 없음). 방안 B는 클라/서버 재시뮬 동치성에 검증이 의존하므로 허용 오차 밴드 협상 필요. → 치팅 방어 관점에서도 A가 유리.

---

## 8. 인게임 서버 API `[개정 C7]`

```
POST /vanguard/match/find    → { battle_id, match_seed, stage_modifier, opponent.loadout }  // 매칭+세션
POST /vanguard/battle/result                                                                  // 결과 제출
  req: { battle_id, rounds[ {result, clear_time, survival_time, enemies_left, enemy_hp_left,
                             opp_enemies_left, opp_enemy_hp_left, bonus_cards[], turret_damage[]} ],
         match_result{my_round_wins, opp_round_wins}, replay{match_seed}, checksum }
  → { win, score_breakdown, new_tier, tier_changed, score_in_division, division_threshold,
      chaos, chaos_capped, win_streak, lose_streak, reward_granted, extra_reward_count,
      rewards, duel_rewards }
```
> 듀얼은 `/vanguard/duel/confirm`이 battle_id를 발급(match_type=DUEL). 매칭/경제 API는 아웃게임 문서 + 명세 §3~9 참조.
> ⚠️ 표기 통일: **`duel`이 정식 표기.** 명세/코드에 남은 `dual`(재화 `dual_token`, match_type `DUAL`)은 **`duel`로 정정 요청**(`duel_token`, `DUEL`).

**클라 응답 매핑 주의**: `score_breakdown`은 고정 필드 구조(base/swift_win/comeback_win/win_streak/dual_multiplier/loss_penalty/point_delta)다. 클라 티어 진행 팝업은 `(labelKey, delta)` 가변 리스트(`VanguardTierProgressData.scoreEntries`)를 표시하도록 설계돼 있으므로, **둘 중 하나로 합의 필요**: ① 서버가 `score_entries:[{label_key,delta}]` 병행 제공(권장), 또는 ② 클라에 고정 필드→로컬라이즈 키 매핑 레이어 추가.

---

## 9. 재사용 vs 신규 `[개정]`

| 기능 | 처리 | 비고 |
|---|---|---|
| 적 스폰/이동/HP | ✅ `EnemyManager`/`PoolManager` 재사용 | 유지 |
| 요새 HP/피격/면역 | ✅ `BaseController`/`BaseSystemManager` 재사용 | 유지 |
| 카드 | ✅ `CardManager` + Vanguard 풀 분기 | 유지 |
| 칩 효과 | ✅ `ChipManager`/`ChipEffectManager` + 신규 칩 6종 enum | 유지 |
| 데미지 계산 | ✅ `DamageCalculationManager`(가산) | 유지. **속성 내성/약점 보정 적용부 추가**(§5-0) |
| 웨이브 진행 | ✅ `BaseStagePlayService.ProcessWavesAsync:125` 상속 | 유지 |
| 스테이지 데이터 변환 | 🆕 `VanguardStagePlayService.BuildStageData()` + **라운드별 보정 주입** | C4 |
| 전투 플로우 제어 | 🆕 `VanguardStagePlayService` | 유지 |
| **상대 고스트 시뮬** | 🆕 `VanguardGhostSim` (~~재생~~ → **결정적 시뮬**) | **C1·C3 — 방안 A/B 결정 필요(§4)** |
| ~~녹화~~ | ❌ **제거** (`VanguardReplayRecorder` 불필요 — loadout만 저장) | C1 |
| 시드 RNG | 🆕 매치 전용 `System.Random(match_seed)` | 유지 |
| **결정적 고스트 시뮬**(방안 B 한정) | 🆕 선행 점검/리팩토링 (UnityRandom·Time.deltaTime·float 순서) | C2 — 방안 B 채택 시 리스크 |
| 스플릿 카메라(v2) | 🆕 `cullingMask` 레이어 분리 | 유지 |

> CPS 칩 등급 점수(매칭 기획서·명세 §11): 희귀1/서사3/전설8/신화10/**초월20**(원본 17 → **20 정정 C9**). 단 CPS는 서버 내부 지표라 클라 구현 불요.

---

## 10. 핵심 클래스 스켈레톤 `[개정 C1·C3·C4]`

per-frame 페이즈 체크는 `VanguardManager.Update()`(MonoBehaviour)에서 구동(원본 §10 정정 유지). 라운드 진행은 `BaseStagePlayService`(async).

```csharp
public class VanguardStagePlayService : BaseStagePlayService
{
    private EnemyManager        _enemyManager;
    private CardManager         _cardManager;
    private BaseSystemManager   _baseSystemManager;
    private VanguardGhostSim    _ghostSim;   // ★ 재생 Recorder → 결정적 시뮬

    private System.Random _matchRng;
    private float _elapsedTime;
    private int   _currentRound;
    private bool  _berserkPhase1, _berserkPhase2;
    private readonly HashSet<float> _checkedBonusTimes = new();

    private VanguardMatchData _match;

    public async UniTask StartVanguardBattleAsync(VanguardMatchData match, CancellationToken token)
    {
        _match = match;
        _matchRng = new System.Random(match.matchSeed);
        _ghostSim = new VanguardGhostSim();
        _ghostSim.Init(match.opponentLoadout, match.matchSeed, match.stageModifiers); // loadout 시뮬
        // ※ Recorder 없음 — 결과는 라운드 집계로 생성
        await RunRoundsAsync(token); // 라운드별 stageModifiers[r] 적용
    }

    public void UpdateBattle(float dt) // VanguardManager.Update()가 호출
    {
        _elapsedTime += dt;
        _ghostSim.Tick(dt);            // 방안 A: 서버 타임라인 재생 / 방안 B: 클라 결정적 시뮬 진행
        CheckBonusCard();              // 20/40/60s (내 적수 < 고스트 적수)
        CheckBerserkPhase1();          // 60s  CC 면역
        CheckBerserkPhase2();          // 120s 이동속도↑
    }

    private void OnRoundEnd(int round)
    {
        var rr = BuildRoundResult(round, _enemyManager, _ghostSim); // 내 결과(+방안 B면 opp_*)
        _roundResults.Add(rr);
    }

    private void OnMatchEnd()
    {
        var result = BuildMatchResult(_roundResults); // rounds[] + checksum
        _match.onComplete?.Invoke(result);            // = SubmitBattleResultAsync
    }
}
```

`VanguardManager`/스플릿뷰 UI 스켈레톤은 원본 §10 유지(서브서비스 조합, `VanguardBattleUI` 상/하 패널). `Bind`에 넘기는 ghost 값의 출처가 "녹화 재생"에서 "`_ghostSim` 시뮬값(방안 A=서버 타임라인 / B=클라 시뮬)"으로 바뀌는 것만 차이.

---

## 11. CLAUDE.md 준수 체크리스트 `[유지 + 강화]`

원본 체크리스트 유지. 모델 변경으로 **결정성 항목은 방안 B 채택 시 필수**가 됨:
- [ ] (방안 B 한정) 고스트 시뮬 랜덤은 `System.Random(match_seed)`만 — `UnityEngine.Random` 금지 **(서버 재시뮬 검증 전제, 위반 시 7207)**
- [ ] (방안 B 한정) 고스트 시뮬이 `Time.deltaTime` 가변 프레임에 의존하지 않도록 고정 틱화 검토
- [ ] 공유 시나리오 부수 무작위(카드 draw 등)는 양안 공통 `match_seed` 기반
- [ ] (나머지 매니저 접근/UniTask/EventManager/ServerTime/가산 데미지/Parser/로컬라이즈 항목 원본 유지)

---

## 12. 검증된 인게임 구현 레퍼런스 (2026-05-31 코드 분석) `[유지]`

원본 §12 표 전체 유지 — 코드 훅 매핑은 모델과 무관하게 유효하다. 단 아래 세 줄만 갱신:

| 메커니즘 | 실제 훅 | 변경 |
|---|---|---|
| ~~녹화 Recorder~~ | ~~StagePlayService 내부~~ | ❌ 제거(loadout만 저장) |
| 상대 고스트 | `VanguardGhostSim`(방안 A=서버 타임라인 재생 / B=결정적 시뮬) | 재생 → 벤치마크, 방안 A/B 결정(§4) |
| 라운드별 보정 | `BuildStageData` + 데미지 속성 보정부 | 신규(§5-0) |

### 신규 클래스 생성 위치
| 클래스 | 경로 |
|---|---|
| `VanguardStagePlayService : BaseStagePlayService` | `Core/Managers/StageServices/` |
| `VanguardGhostSim`(POCO, 벤치마크 재생/시뮬) | `Core/Managers/Vanguard/` |
| `VanguardLoadoutSnapshot` / `VanguardStageModifierSet`(DTO) | `Core/Data/Server/` 또는 `Core/Managers/Vanguard/` |
| ~~`VanguardReplayRecorder` / `VanguardReplayData`~~ | ❌ 제거 |

---

## 13. 결정·확인 항목 정리 `[갱신]`

### 13-1. 이번 개정으로 확정된 것
- **무승부 없음**(C10): 동시 패배·매치 동률 시 단일 승자 강제(§5-8).
- **120초 = 2차 광폭화(적 이동속도 증가)**(C5): 기획서+명세 일치. 드레인 제거.
- **결정성 범위**(C2): 내 전투 불요, 상대 벤치마크만. 위치는 아래 13-2로.
- **비동기 PvP 성립**(§0-1): 상대는 결정론적 벤치마크(고정 기준점), 승패는 내 플레이로 결정·클라 제출.

### 13-2. 서버팀과 결정 (1순위)
- **상대 벤치마크 계산 위치**(C3): **방안 A(서버 사전계산·전송) 권장** vs 방안 B(클라 시뮬+재시뮬 검증). A면 클라 결정성 0 + 치팅 방어 우위. 서버 전투 시뮬 구현 비용만 판단하면 됨.
- (방안 B 채택 시에만) 클라/서버 재시뮬 float **허용 오차 밴드** 정의.
- **봇 클론 운용**(§6-1): 봇을 별도 제작·운용할지(명세 §11·§17), 아니면 Record Clone 유지(명세 §16)만으로 시즌 초반 공백을 메울지. 봇을 쓴다면 **제작 주체 확정 필요**(§17 TBD).

### 13-3. 계약/표기 확인
- **score_breakdown 표시 계약**(§8): 서버 `score_entries:[{label_key,delta}]` 병행 제공(권장) vs 클라 고정필드→키 매핑 레이어.
- **표기 `duel`로 확정**: 서버 필드 `dual_token`→`duel_token`, match_type `DUAL`→`DUEL` 정정 요청.
- **티어 정수 현행화**: EVanguardTier 101~601 확정. 명세 예시의 `205` 등 구버전 5디비전 인코딩 값 정정 필요(마일스톤 SO에서 겪은 "숫자 노출" 재발 방지).

### 13-4. 위키 대조 — 기획서 우선 적용된 차이 (참고)
> 위키=원작 FTD, 우리는 기획서 우선. 차이는 의도된 변경으로 간주하되 한 번씩 확인 권장.

- **자동순찰 해금**: 위키 Silver 1 / 기획서·티어테이블 **Silver 2** → 기획서 우선.
- **120초**: 위키 드레인 / 기획서·명세 **이동속도 증가** → 기획서 우선(§5-5).
- **자동순찰 보상 주기**: 위키 "6시간마다 Quick-Patrol(2배)" / 명세 "최대 8h" → 수치 확인.
- 위키 확인 수치(참고): extra_reward 시작 10·시간당 +1, 듀얼토큰 4h·구매 최대, 칩 상자 49/30/15/5/1·55/30/15, 칩 #4 4/6/8%·#5 3/4.5/6s·#6 4/6/8%(최대 2/3/4x), 패스 Ember 980다이아·Vanguard $9.99, 성장치 미적용(다이아 제외).
