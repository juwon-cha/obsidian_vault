# Vanguard 인게임 전투 UI(VanguardInGameUI) 구현 종합 문서 (2026-06-03)

## 문서 목적

뱅가드 로비에서 **Match/Duel** 진입 → 매칭 성공 → **매칭 인트로(VS) 연출** → **인게임 스플릿 전투 HUD** 표시 → 전투 시작. 그중 **인게임 UI 프리팹 + 스크립트**를 이 문서만 보고 제작할 수 있도록 정리한다.

- 전투 로직(고스트/녹화/페이즈/점수/칩효과)은 이미 [[2026-05-29_vanguard-implementation-plan-ingame]] 에 상세 설계됨. **본 문서는 그 위에 얹는 "보이는 UI"** 만 다룬다(중복 설계 금지).
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]](아웃게임 터렛/칩 장착 UI)
- `[설계 판단]` = 위키/스샷에 없어 설계로 보완한 부분.

> ⚠️ **인게임 로직은 현재 구조에서 벗어나지 않는다**(사용자 요구). GameScene 재활용, `BaseStagePlayService` 상속, `UIManager.Show<T>()` 프리팹 구동 — 전부 기존 패턴. 신규는 **UI 프리팹/스크립트 + 카메라 뷰포트 분기**뿐.

> 🔄 **2026-06-06 개정**: 매칭 성공 시의 **유저 정보 인트로(VS) 화면**과 **인게임 스플릿 전투 HUD**를 **단일 프리팹 `VanguardInGameUI`** 로 통합하고, 두 영역을 활성/비활성(애니메이션 연출 포함) 전환하는 구조로 확정. (이전 명칭 `VanguardBattleUI` → `VanguardInGameUI`. 사유는 §0-A 참조.)

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 인게임 UI | **신규 `VanguardInGameUI : UIBase`** 프리팹 1개. 내부에 **① 매칭 인트로(VS) 패널 + ② 스플릿 전투 HUD** 를 모두 포함, CanvasGroup로 전환 (`GameUI`는 띄우지 않음) |
| 표시 시점 | `VanguardStagePlayService`가 전투 시작 시 `uiManager.Show<VanguardInGameUI>(matchData)` — **PunchKing이 `Show<GameUI>()` 하는 자리와 동일 패턴** |
| 인트로→전투 전환 | `UIBase.OpenedAsync`에서 **인트로 연출 재생 → await → 전투 HUD 활성 + 전투 시작 신호**. 단일 프리팹 안에서 처리(§0-A) |
| 씬 | `GameScene` 재활용 (`SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)`) |
| 스플릿 | 하단 = 내 실제 전투(메인 카메라 뷰포트 축소), 상단 = 상대 고스트 패널. `InGameModeVariant`에 Vanguard 분기 추가 |
| 재사용 | 인트로 카드 = **`VanguardDuelOpponentSlot` 재사용**(프로필/프레임/티어/메달수/이름). 전투 헤더 = `VanguardRankingDisplaySlot`. 그 외 `GameUI`의 속도/일시정지/HP바 로직, `EliteHealthBar`, `DamageTextManager`, `PauseUI` |
| 신규 컴포넌트 | `VanguardInGameUI.cs`(루트), `VanguardMatchIntroPanel.cs`(VS 인트로), `VanguardGhostPanel.cs`(상단 고스트) — 3개 |
| 데이터 주입 | `Show<VanguardInGameUI>(matchData)` 1회로 인트로·헤더 모두 채움(2회 전달 불필요). 전투 중 self/ghost 값은 `VanguardManager.Update()`가 매 프레임 push |

---

## 0-A. 설계 판단 — "인트로 + 전투 HUD = 단일 프리팹" 평가 `[중요]`

> 사용자 제안: 매칭 성공 시 유저 정보(프로필/프레임/티어/메달/이름)를 보여주는 인트로 UI와 실제 인게임 스플릿 전투 UI를 **하나의 프리팹**에 담고, 활성/비활성(애니메이션 포함)으로 전환. **→ 동의. 이 방식이 더 빠르고 안전하다.** 근거와 주의점은 아래.

**찬성 근거**

1. **코드 근거 — `UIBase`가 이미 비동기 연출 훅을 제공.** `UIBase.OpenedAsync(object[])`는 주석에 *"애니메이션 시간만큼 대기"* 라고 명시(`UI/UIBase.cs:81`). 단일 프리팹에서 `OpenedAsync`를 override해 **인트로 연출 재생 → await → 전투 HUD 활성** 을 한 메서드 안에서 자연스럽게 처리할 수 있다. 별도 프리팹 2개를 `UIManager`로 순차 Show/Hide하며 크로스페이드를 맞추는 것보다 타이밍 제어가 단순하다.
2. **스샷 근거 — 이미지1 배경에 전투 HUD가 이미 보임.** VS 오버레이 뒤로 전투 헤더(`Rapetor`/`TopTap_on_YT`), 일시정지·`x2` 버튼, ◆ 카운터가 흐릿하게 깔려 있다. 즉 실제 게임도 **전투 HUD가 먼저 깔린 위에 인트로가 덮였다가 사라지는** 구조 → 단일 프리팹 한 캔버스에 두 레이어를 두는 방식과 정확히 일치.
3. **데이터 1회 주입.** 인트로 카드와 전투 헤더는 **동일 매칭 데이터**(self/opponent 프로필·프레임·티어·메달·이름)를 쓴다. `Show<VanguardInGameUI>(matchData)` 한 번으로 둘 다 채우면 프로필 아이콘/프레임 비동기 로드도 1회로 끝남(2개 프리팹이면 중복 로드).
4. **수명주기·정리 일원화.** 이벤트 구독/해제, 카메라 rect 복원, 풀 정리를 `Opened`/`Closed` 한 쌍에서 처리. 진입점도 서비스에서 `Show` 1회뿐 → 회귀 위험·연동 코드 최소.

**주의점(반드시 지킬 것)**

- **스크립트는 모듈로 분리.** 한 프리팹이라도 스크립트까지 한 덩어리로 만들지 말 것. 루트 `VanguardInGameUI.cs`(흐름/전환/전투 HUD) + `VanguardMatchIntroPanel.cs`(인트로 전담) + `VanguardGhostPanel.cs`(고스트)로 책임 분리.
- **전투 시작 게이트.** 인트로 연출이 끝나기 전엔 전투 진행(스폰/타이머)이 시작되면 안 됨. `OpenedAsync`에서 인트로 await 후 전투 시작 신호(`VanguardStagePlayService.BeginBattle()` 등)를 호출 — 인트로 동안은 `Time`/스폰 정지 또는 미시작 상태 유지.
- **입력 차단.** 인트로 패널은 자체 `CanvasGroup.blocksRaycasts = true`로 하단 전투 HUD 버튼(일시정지/배속/카드) 오입력 방지. 연출 종료 시 인트로 비활성 + raycast 해제.
- **인트로는 비활성 후 파괴하지 않음.** 같은 프리팹 내 오브젝트이므로 `SetActive(false)`로만 끄기(재대전/리매치 시 재활용 가능). 프리팹 자체 파괴는 `UIManager.Hide`가 담당.

**대안과 기각 사유**

- *대안: 인트로 별도 프리팹(`VanguardMatchIntroUI`) + 전투 별도 프리팹(`VanguardInGameUI`)을 순차 Show/Hide.* → 더 "모듈"해 보이나 (a) 매칭 데이터/프로필 로드 2회, (b) 인트로 Hide와 전투 Show의 크로스페이드 타이밍을 `UIManager` 너머로 수동 동기화, (c) 진입점 2곳 → 코드/회귀 비용 증가. 인트로는 전투 시작에 강결합된 **수초짜리 전이 연출**이라 분리 이득이 적음. **기각.** (단, 인트로 연출이 향후 독립 기능으로 커지면 그때 분리 검토.)

---

## 1. 진입 플로우 (확인된 코드 기준)

```
VanguardLobbyPanel.OnClickMatch()  (또는 VanguardDuelSelectPopup.ChallengeAsync)
  └─ await VanguardManager.FindMatchAsync(EVanguardMode)         // ingame 10장: { matchId, opponentClone, matchSeed }
       └─ SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, vanguardStageId)   // SceneManager.cs:158 → "GameScene"
            └─ [GameScene 로드 / CurrentGameMode=Vanguard, SelectedStageID 세팅]
                 └─ StageManager → VanguardStagePlayService.StartVanguardBattleAsync(matchData)   // ingame 10장
                      ├─ uiManager.Show<VanguardInGameUI>(matchData)   ★ 본 문서 UI 진입점
                      │    └─ OpenedAsync: 인트로(VS) 연출 재생 → await → 전투 HUD 활성
                      └─ (인트로 종료 콜백/await 후) RunRoundsAsync(...)   // 기존 ProcessWavesAsync 골격
```

**근거 — PunchKing의 동일 패턴** (`StageServices/PunchKingStagePlayService.cs:586-595`):

```csharp
// GameUI 표시 (펀치킹 모드 서비스가 자동 활성화됨)
uiManager?.Show<GameUI>();
// GameUI.Show 이후 직접 호출 (이벤트 타이밍 때문)
var gameUI = uiManager?.IsOpened<GameUI>() as GameUI;
if (gameUI != null && punchKingManager != null)
    gameUI.SetCountdownMode(punchKingManager.TimeLimitSeconds);
```

→ Vanguard도 **`VanguardStagePlayService`에서 `Show<VanguardInGameUI>(matchData)` + 초기화 직접 호출**. 일반 모드는 `GameUI`가 씬 자동활성, Vanguard만 전용 UI로 치환(`GameUI`는 띄우지 않음). 모드 분기는 서비스 단위라 **중앙 스위치 불필요**(각 StagePlayService가 자기 UI를 띄우는 현 구조 유지).

> `LoadGameSceneAsync(GameModeType, int)`(`SceneManager.cs:158`)가 `CurrentGameMode`/`SelectedStageID` 세팅 후 `"GameScene"` 로드. `GameUI.Opened(object[] param)`는 `param[0] is StageDataSO`를 옵션 인자로 받음 → `VanguardInGameUI`도 `matchData`를 `param[0]`으로 받는 동일 시그니처.

---

## 2. 이미지 상세 분석

### 2-0. 이미지1 — 매칭 인트로(VS) 화면 `[신규]`

매칭 성공 직후 표시되는 **VS 인트로 오버레이**. 두 유저 카드가 대각선 미러로 배치되고 가운데 번개형 **VS** 배지. **배경에 전투 HUD가 흐릿하게 보임** → 전투 HUD가 먼저 깔린 위에 인트로가 덮이는 구조(§0-A 근거2).

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 상대 카드(상단, 핑크) | `Rapetor` + 프로필 아이콘 + 프레임(별/메달형) | `VanguardDuelOpponentSlot` 재사용 — `_profileIcon`/`_profileFrame`/`_userName` |
| 상대 티어 메달 | 카드 좌측 붉은 엠블럼 | `_tierBadge` (`VanguardTierUtil.GetTierSprite`) |
| 상대 메달 수 | 금색 보석 + `x100` | `_medalCountText` = `$"x{opponent.medalCount}"` (코드 `:59`와 정확히 일치) |
| VS 배지(중앙) | 노란 번개형 육각 `VS` | 신규 연출 오브젝트 `_vsBadge` (스케일/플래시 애니) |
| 내 카드(하단, 블루) | `TopTap_on_YT` + 캐릭터 아바타 + 무지개 프레임 | self용 `VanguardDuelOpponentSlot` (또는 self 바인딩 분기) |
| 내 메달 수 | 금색 보석 + `x99` | `_medalCountText` |
| 내 티어 메달 | 붉은 엠블럼 | `_tierBadge` |

`[설계 판단]` 인트로 카드는 **`VanguardDuelOpponentSlot`을 그대로 재사용**(프로필/프레임/티어/메달수/이름이 이미 직렬화 필드로 존재). 단 인트로에선 `_challengeButton`/`_winPointText`/`_doublePointBadge`는 숨김(또는 인트로 전용 경량 바인딩 메서드 추가). self 카드는 듀얼 후보 데이터가 없으므로 `PlayerDataManager`/`VanguardManager.RankService`에서 채우는 self 바인딩 분기 필요(§6-2).

### 2-1. 이미지2 상단 — 상대 고스트(A_Cat) 영역 (미러)

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 상대 요새(GTS) | 최상단, 터렛 3문 + 구조물 | 고스트 요새 아트(정적/애니, 미러) |
| 보스 HP바 | `EL` 라벨 + 게이지 + `4000` | 정예/보스 HP — **`EliteHealthBar` 재사용** (단, 고스트는 비주얼 재생) |
| 터렛 클러스터 | 흰 점박이 원형 다수(군집) | 상대 배치 터렛 — 고스트 v2 비주얼(아이콘) |
| 적(박쥐형) + `9x` | 보스 위 주황 호 `9x` | 정예 페이즈 배수 = `EliteHealthBar._healthPhaseText` ("x9") |
| 우측 적 + `6x`, `-827` | 박쥐형 + 데미지 | 페이즈 배수 + 데미지 숫자 |

`[설계 판단]` 상단은 **전투 시뮬레이션이 아니라 고스트 재생**([[2026-05-29_vanguard-implementation-plan-ingame]] 4장 v1/v2). v1=HP바+생존 적 수만, v2=적 스프라이트 위치 재생. 본 UI는 **v1 우선**(HP바/카운트/요새), v2는 `VanguardGhostPanel` 확장으로 후속.

### 2-2. 이미지2 가운데 — 공유 HUD 띠

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 상대 헤더 | `A_Cat` + 아바타 + ◆`1` | `VanguardRankingDisplaySlot`. ◆ = Vanguard Mark(랭크 포인트/승리 시 획득 점수) |
| 컨트롤 | `‖`(일시정지) · `x2`(배속) · 카드/티켓 아이콘 | **`GameUI` 재사용**: `_pauseButton`/`_gameSpeedButton`. 카드 버튼 = 라운드 고정 카드 보기(위키 2-A) |
| 라운드/스코어 배지 | 원형 `2 / 2`(상=상대, 하=나) | 양측 진행/점수 비교 표기. 신규 `_selfRoundText`/`_opponentRoundText` (의미는 §10 확인) |
| Berserk 타이머 | `Berserk in: 34` | 페이즈 3단계 카운트다운(2-A). 신규 `_berserkTimerText`/`_phaseLabel` |
| 내 헤더 | `TopTap_on_YT` + 아바타 + ◆`0` | `VanguardRankingDisplaySlot`. self는 `MyRankingItem` |

### 2-3. 이미지2 하단 — 내 전투(TopTap_on_YT) 영역 (인터랙티브)

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 적 + 데미지 숫자 | 빨강 적, `-30 -38 x10`, `-53 -1233 -67 x10` | `DamageTextManager.ShowDamageText` + `EliteHealthBar` 페이즈 `x10` |
| 터렛 공격 | 좌하단 초록 레이저, 청록 탄막 | 실제 전투 유닛(기존 컨트롤러), UI 아님 |
| 내 요새 HP | 최하단 `3850` + 게이지 | **`GameUI._baseHealthSlider`** 로직 재사용 (`GameEventType.BaseDamaged`) |
| 요새 방어 아이콘 | 게이지 옆 ◆/하트 `8` | 칩/방어 스택 표기 `[설계 판단]` — 칩#5 면역 스택 등 |

### 2-4. 화면 방향 — 문서와의 정합 `[중요]`

스샷은 **내 전투 = 하단**, 고스트 = 상단. [[2026-05-29_vanguard-implementation-plan-ingame]] 10장 스플릿 스케치는 "Self=상단"으로 적혀 있으나 **스샷이 정답**(타워디펜스에서 내 요새가 화면 하단이 자연스러움). → 본 UI는 **Self=하단, Ghost=상단**으로 확정. 인게임 문서 10장의 카메라 rect를 아래에 맞춰 정정(메인 카메라 = 하단 0.0~0.5, 상단 0.5~1.0 = 고스트 패널).

---

## 2-A. 위키 원문 근거 — 인게임 전투 규칙 (Fandom, V0.13.7 기준)

> 출처: [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) "Event Info & Rules". 인게임 UI에 직접 영향하는 규칙만 발췌·정리(원문 요약, 무단 전재 아님).

**전투 진행 규칙 (확정)**

| 규칙 | 내용 | UI 영향 |
|---|---|---|
| 라운드 구성 | 매 라운드 일반 6 + 정예 2 중 무작위 추출, **전 플레이어 동일 고정 세트** | 정예 2기 → `EliteHealthBar` 동시 최대 2개 |
| 카드 | 매 라운드 **고정 터렛 카드 세트(전 플레이어 동일)**. Ember Pass 보유 시 라운드 시작마다 랜덤 활성 카드 1장(Initiative Boost) | HUD 카드 버튼 = 라운드 시작 카드 보기/선택 |
| 적 스케일 | 적 HP·공격이 **현재 티어에 비례** 증가 | (로직) 게이지엔 절대값 표기 |
| 텔레포트 | 적이 **텔레포트할 때마다 HP·공격 증가** | 텔레포트 순간 스탯업 연출/배수 갱신 |
| **페이즈 타이밍** | **60초 → Berserk**(적 CC 면역). **추가 60초(=120초) → Termination**(양측 요새 매초 -1000 HP) | 중앙 타이머 3단계 + Berserk 표식 + 양측 HP 드레인 |
| 성장 미적용 | 본편 성장치 전투 미반영(다이아 제외) | - |
| 점수 | 매치 후 ±포인트는 **상대 랭크에 따라 변동** | 결과 화면(범위 밖) |

**UI 요구사항으로 정리**

1. **중앙 페이즈 타이머 3단계**: `0~60s = "Berserk in: N"` → `60~120s = "Termination in: N"` + Berserk 활성 표식(적 CC 면역 상태) → `120s+ = "Termination"`(드레인 진행, 타이머 종료).
2. **Termination 동시 드레인**: 120초 진입 시 **self/ghost 양측 요새 HP바가 동시에 매초 -1000** 급감 → 양쪽 HP바에 드레인 연출(붉은 점멸 등).
3. **정예 HP바 2개 + 배수/텔레포트**: 라운드당 정예 2 → `EliteHealthBar` 풀 동시 2개. 스샷의 `9x/6x/x10` = 정예 페이즈 배수(`_healthPhaseText`). 텔레포트 시 갱신.
4. **헤더/인트로 데이터**: Duel 선택 화면이 상대의 **현재 랭크(Vanguard Mark ◆) · 공격력 · 칩 수 · 메달 수 · 승리 시 점수**를 보여줌(`VanguardDuelOpponentSlot`) → 인트로 카드와 인게임 헤더(self/opponent)도 동일 데이터 소스 재사용.

> **Battle Report(결과)**: 위키 — Overview(장착 칩 스탯 표시)가 승/패 결과 리포트에도 동일하게 표시됨. → 결과 화면은 [[2026-06-03_vanguard-turret-setup-ui]]의 Overview 패널을 재사용(본 문서 범위 밖, 결과 UI 설계 시 연계).

---

## 3. 재사용 자산 분석

> 신규 프리팹은 `VanguardInGameUI`(루트) + `VanguardMatchIntroPanel`(인트로) + `VanguardGhostPanel`(상단)뿐. 나머지는 기존 컴포넌트/이벤트 재사용.

| 자산 | 경로 | 재사용 방식 | 핵심 API/필드 |
|---|---|---|---|
| **VanguardDuelOpponentSlot** | `UI/Vanguard/Component/VanguardDuelOpponentSlot.cs` | **인트로 카드로 재사용** (프로필/프레임/티어/메달수/이름) | `_profileIcon`/`_profileFrame`/`_userName`/`_tierBadge`/`_tierName`/`_medalCountText`(`x{medalCount}`) · `Bind(VanguardDuelOpponent)` · `LoadProfileIconAsync`/`LoadProfileFrameAsync` |
| **GameUI** | `UI/GameUI.cs` (`:13 UIBase`) | **로직 참고/복제** (그대로 띄우지 않음) | 속도: `_gameSpeedButton`/`_gameSpeedButtonImage`/`_gameSpeedSprites`/`OnGameSpeedButtonClicked():550`/`UpdateGameSpeedButtonImage():628` · 일시정지: `_pauseButton`/`OnPauseButtonClicked():671` · 요새HP: `_baseHealthSlider`/`_baseHealthFillImage`/`_baseHealthText`/`HandleBaseDamaged():1273` · 보스HP: `_bossHealthSlider`/`HandleBossHealthUpdate():1230` · 카운트다운: `SetCountdownMode(float)` |
| **EliteHealthBar** | `UI/Components/EliteHealthBar.cs` (MonoBehaviour) | **그대로 재사용** (정예 HP바 + "x10/x9" 배수 = 스샷의 9x/6x/x10) | `Initialize(BaseEnemyController, EliteHealthUpdateEventData)` · `UpdateHealthBar(EliteHealthUpdateEventData)` · `_healthPhaseText`("x10") · `UpdateEliteHealthBarPosition():129` · 풀: `GameUI.InitializeEliteHealthBarPool():1103` |
| **DamageTextManager** | `Core/Managers/DamageTextManager.cs` (`BaseManager`) | **그대로 재사용** (데미지 숫자) | `ShowDamageText(float, Vector3 world, Transform follow, EDamageTextType):95` / `DamageText.Show(...)` |
| **VanguardRankingDisplaySlot** | `UI/Vanguard/Component/VanguardRankingDisplaySlot.cs` | **헤더로 재사용** (아바타/이름/티어/점수) | `Init(VanguardRankingItem)` / `Init(VanguardMyRankingItem)` · base `_profileIconImage`/`_profileFrameImage`/`_userName` · `_tierBadgeImage`/`_pointsText` · `LoadProfileIconAsync`/`LoadProfileFrameAsync`(base) |
| **UIBase** | `UI/UIBase.cs` | **인트로→전투 전환 훅** | `OpenedAsync(object[])`("애니메이션 시간만큼 대기" 주석:81) override → 인트로 연출 await · `ClosedAsync`/`Closed`(정리) |
| **PauseUI** | `UI/PauseUI.cs` | `OnPauseButtonClicked`가 호출 → 그대로 | 일시정지 팝업 |
| **InGameModeVariant** | `Utils/InGameModeVariant.cs` | **Vanguard 분기 추가** (스플릿 카메라) | 선례 `Mode360Setter()`가 `mainCamera.orthographicSize`/배경 변형 |
| 이벤트 | `Core/EventData/EventDataTypes.cs` | 구독 | `GameEventType.BaseDamaged` / `BossHealthUpdate` / `EliteHealthUpdate` / `StageStarted` |

### 재사용하지 않는 것

- ❌ `GameUI` 프리팹 자체를 띄우지 않음(스플릿 레이아웃·헤더가 달라 별도 프리팹). 단, **스크립트 로직은 최대한 복제**(속도/일시정지/요새HP 핸들러).
- ❌ 상단 고스트에 `EnemyManager`/전투 컨트롤러 사용 금지(싱글톤 1전투 원칙, ingame 4장).

---

## 4. 카메라 / 뷰포트 (스플릿)

`Utils/InGameModeVariant.cs` 에 Vanguard 분기 추가 (`Mode360Setter` 패턴 답습):

```csharp
// InGameModeVariant — GameModeType.Vanguard 분기
private void ModeVanguardSplitSetter()
{
    // 메인 카메라 = 화면 하단 절반만 렌더 (내 전투)
    _mainCamera.rect = new Rect(0f, 0f, 1f, 0.5f);
    // 상단 절반은 VanguardInGameUI의 GhostPanel(UI)로 채움
    // v1: 카메라 1대(하단만). v2에서 상단 고스트 적 스프라이트 필요 시
    //     cullingMask 분리한 2번째 카메라(rect 0,0.5,1,0.5) 추가 검토 (ingame 4장 v2)
}
```

- 진입: 360모드 분기와 동일 자리에서 `SceneManager.CurrentGameMode == GameModeType.Vanguard` 체크.
- `orthographicSize`는 하단 절반에 전체 전장이 들어오도록 조정(360모드가 8f로 바꾸는 것과 동형). 정확값은 플레이 테스트.
- **카메라 1대 유지(v1)** → 싱글톤/성능 안전. 상단은 순수 UI 패널.
- **인트로 중에는 카메라 rect를 풀스크린(또는 인트로 연출 우선)으로 둘지** 결정 필요: 인트로 동안 전투가 미시작이므로 카메라 rect 분할은 **전투 HUD 활성 시점에 적용**하는 것이 자연스러움(인트로 페이드아웃과 동기). `[설계 판단]`

---

## 5. UI 프리팹 구조 (전체 하이어라키)

> 신규 프리팹 `Assets/_Project/3_Prefabs/UI/Vanguard/VanguardInGameUI.prefab`. 루트에 `VanguardInGameUI.cs`. `uiPosition = eUIPosition.HUD`(전투 HUD). **두 최상위 그룹(IntroPanel / BattleHud)을 CanvasGroup로 전환.**

```
VanguardInGameUI (루트 Canvas, ▶ VanguardInGameUI.cs)
│
├─ IntroPanel (CanvasGroup, 매칭 인트로/VS, ▶ VanguardMatchIntroPanel.cs)  → _introPanel
│  ├─ Dim (반투명 배경 — 뒤 전투 HUD를 가림)
│  ├─ OpponentCard [재사용 VanguardDuelOpponentSlot]   → _opponentCard  (Rapetor / x100 / 프레임/티어)
│  ├─ VsBadge (번개형 "VS", 스케일/플래시 애니)          → _vsBadge
│  └─ SelfCard [재사용 VanguardDuelOpponentSlot]        → _selfCard     (TopTap_on_YT / x99)
│
└─ BattleHud (CanvasGroup, 스플릿 전투, 인트로 종료 후 활성)  → _battleHud
   ├─ GhostPanel (상단 0.5~1.0, ▶ VanguardGhostPanel.cs)   → _ghostPanel
   │  ├─ GhostFortressArt (Image/Animator, 미러)
   │  ├─ GhostFortressHp (Slider + Fill + Text "4000")     → _ghostFortressHp / _ghostFortressHpText
   │  ├─ GhostBossBar [재사용 EliteHealthBar/유사]          → 고스트 보스 HP(비주얼)
   │  ├─ GhostTurretIcons (배치 아이콘, v2)
   │  └─ GhostEnemyLayer (v2: 적 스프라이트 재생 컨테이너)   → _ghostEnemyLayer
   │
   ├─ MidHud (가운데 띠)
   │  ├─ OpponentHeader [재사용 VanguardRankingDisplaySlot] → _opponentHeader  (A_Cat ◆)
   │  ├─ Controls
   │  │  ├─ Btn_Pause                                       → _pauseButton
   │  │  ├─ Btn_Speed (+Image)                              → _gameSpeedButton / _gameSpeedButtonImage
   │  │  └─ Btn_Card (카드/티켓)                            → _cardButton
   │  ├─ RoundBadge (원형 "2/2")                            → _selfRoundText / _opponentRoundText
   │  ├─ BerserkTimer ("Berserk in: 34")                    → _berserkTimerText / _phaseLabel
   │  └─ SelfHeader [재사용 VanguardRankingDisplaySlot]     → _selfHeader  (TopTap_on_YT ◆)
   │
   ├─ SelfHud (하단, 내 전투 위 오버레이)
   │  ├─ SelfFortressHp (Slider + Fill + Text "3850")       → _selfFortressHp / _selfFortressHpText / _selfFortressHpFill
   │  ├─ SelfFortressGuardIcon (◆/하트 "8")                 → _selfGuardCountText  [설계 판단]
   │  ├─ BossHpBar (상단 떠있는 정예/보스 게이지)            → _bossHealthSlider / _bossHealthPanel
   │  └─ EliteHpBarContainer (풀 부모)                       → _eliteHealthBarContainer (+_eliteHealthBarPrefab)
   │
   └─ TouchBlocker (카드 선택/일시정지 중 입력 차단, GameUI 패턴)  → _touchBlocker
```

- **인트로 카드는 `VanguardDuelOpponentSlot`을 재사용**하되 인트로 표시에 불필요한 `_challengeButton`/`_winPointText`는 비활성. self 카드 데이터는 §6-2 self 바인딩으로 채움.
- **데미지 숫자**는 `DamageTextManager`(BaseManager)가 자체 캔버스에 띄우므로 프리팹에 둘 필요 없음. 단, Vanguard 캔버스/카메라 정합 확인.
- `EliteHpBarContainer`/`_eliteHealthBarPrefab`은 `GameUI`의 `InitializeEliteHealthBarPool()` 로직 복제.

---

## 6. 스크립트 설계

### 6-1. `VanguardInGameUI.cs` (루트 — 흐름/전환/전투 HUD)

> `GameUI`의 속도/일시정지/요새HP 핸들러를 복제하고, **인트로→전투 전환**과 self/ghost 분리 + 헤더 + Berserk 타이머를 추가. 데이터는 이벤트 구독 + `VanguardManager`의 per-frame `BindFrame()` 혼용. CLAUDE.md 준수.

```csharp
using System;
using System.Threading.Tasks;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 인게임 UI 루트. 단일 프리팹에 ① 매칭 인트로(VS) + ② 스플릿 전투 HUD 를 포함하고,
/// OpenedAsync에서 인트로 연출을 재생/대기한 뒤 전투 HUD를 활성화한다.
/// 하단=내 전투, 상단=상대 고스트. VanguardStagePlayService가 Show<VanguardInGameUI>(matchData)로 띄움.
/// </summary>
public class VanguardInGameUI : UIBase
{
    #region Serialized

    [Header("Intro / Battle 그룹")]
    [SerializeField] private VanguardMatchIntroPanel _introPanel;
    [SerializeField] private CanvasGroup _battleHud;

    [Header("Self HUD (하단)")]
    [SerializeField] private Slider _selfFortressHp;
    [SerializeField] private Image _selfFortressHpFill;
    [SerializeField] private TextMeshProUGUI _selfFortressHpText;
    [SerializeField] private TextMeshProUGUI _selfGuardCountText; // ◆/하트 스택
    [SerializeField] private Slider _bossHealthSlider;
    [SerializeField] private GameObject _bossHealthPanel;
    [SerializeField] private GameObject _eliteHealthBarPrefab;
    [SerializeField] private Transform _eliteHealthBarContainer;

    [Header("Ghost Panel (상단)")]
    [SerializeField] private VanguardGhostPanel _ghostPanel;

    [Header("Mid HUD")]
    [SerializeField] private VanguardRankingDisplaySlot _selfHeader;
    [SerializeField] private VanguardRankingDisplaySlot _opponentHeader;
    [SerializeField] private Button _pauseButton;
    [SerializeField] private Button _gameSpeedButton;
    [SerializeField] private Image _gameSpeedButtonImage;
    [SerializeField] private Sprite[] _gameSpeedSprites;
    [SerializeField] private Button _cardButton;
    [SerializeField] private TextMeshProUGUI _selfRoundText;
    [SerializeField] private TextMeshProUGUI _opponentRoundText;
    [SerializeField] private TextMeshProUGUI _berserkTimerText;
    [SerializeField] private TextMeshProUGUI _phaseLabel;
    [SerializeField] private GameObject _berserkActiveIndicator;     // 60~120s 적 CC 면역 표식
    [SerializeField] private GameObject _terminationActiveIndicator; // 120s+ 양측 드레인 표식
    [SerializeField] private GameObject _touchBlocker;

    private const float BERSERK_AT = 60f;
    private const float TERMINATION_AT = 120f;

    #endregion

    private UIManager _uiManager;
    private float _maxFortressHp;
    private VanguardMatchData _match;

    // ─────────── 진입: 인트로 연출 → 전투 HUD 활성 ───────────
    public override async Task OpenedAsync(object[] param)
    {
        uiPosition = eUIPosition.HUD;
        _uiManager = Managers.Instance.GetManager<UIManager>();
        _match = (param != null && param.Length > 0) ? param[0] as VanguardMatchData : null;

        // 1) 전투 HUD는 일단 숨기고(데이터는 미리 세팅), 인트로만 노출
        if (_battleHud != null) { _battleHud.alpha = 0f; _battleHud.blocksRaycasts = false; }
        SetupHeaders(_match);
        InitEliteHealthBarPool();              // GameUI.InitializeEliteHealthBarPool 복제
        SubscribeEvents();
        UpdateSpeedButtonImage();

        // 2) 인트로(VS) 연출 재생 후 대기 (전투 시작 게이트)
        if (_introPanel != null)
            await _introPanel.PlayAsync(_match);   // 카드 바인딩 + VS 연출 + 페이드아웃까지 await

        // 3) 전투 HUD 페이드인 + 입력 허용
        if (_battleHud != null)
        {
            await _battleHud.DOFade(1f, 0.25f).AsyncWaitForCompletion(); // CLAUDE.md: ToUniTask 금지
            _battleHud.blocksRaycasts = true;
        }

        // 4) 전투 시작 신호 (스폰/타이머 시작) — 서비스에 위임
        Managers.Instance.GetManager<VanguardManager>()?.OnInGameUIReady();
    }

    public override void Closed(object[] param)
    {
        UnsubscribeEvents();
        base.Closed(param);
    }

    private void Awake_BindButtons() { /* Opened 시점에 1회 바인딩하거나 Awake에서 */ }

    private void SubscribeEvents()
    {
        _pauseButton.onClick.AddListener(OnPauseClicked);
        _gameSpeedButton.onClick.AddListener(OnSpeedClicked);
        _cardButton.onClick.AddListener(OnCardClicked);
        EventManager.Subscribe<BaseDamageEventData>(GameEventType.BaseDamaged, HandleBaseDamaged);
        EventManager.Subscribe<BossHealthUpdateEventData>(GameEventType.BossHealthUpdate, HandleBossHealthUpdate);
        EventManager.Subscribe<EliteHealthUpdateEventData>(GameEventType.EliteHealthUpdate, HandleEliteHealthUpdate);
    }

    private void UnsubscribeEvents()
    {
        _pauseButton.onClick.RemoveListener(OnPauseClicked);
        _gameSpeedButton.onClick.RemoveListener(OnSpeedClicked);
        _cardButton.onClick.RemoveListener(OnCardClicked);
        EventManager.Unsubscribe<BaseDamageEventData>(GameEventType.BaseDamaged, HandleBaseDamaged);
        EventManager.Unsubscribe<BossHealthUpdateEventData>(GameEventType.BossHealthUpdate, HandleBossHealthUpdate);
        EventManager.Unsubscribe<EliteHealthUpdateEventData>(GameEventType.EliteHealthUpdate, HandleEliteHealthUpdate);
    }

    private void SetupHeaders(VanguardMatchData match)
    {
        var rank = Managers.Instance.GetManager<VanguardManager>()?.RankService;
        // _selfHeader.Init(rank?.MyRankingItem);
        // _opponentHeader.Init(match?.opponentClone?.profile);  // 고스트 프로필
    }

    // ─────────── per-frame 값 주입 (VanguardManager.Update가 호출) ───────────
    public void BindFrame(float selfHp, float selfMaxHp, int selfAlive,
                          float ghostHp, float ghostMaxHp, int ghostAlive,
                          float elapsed)
    {
        _maxFortressHp = selfMaxHp;
        UpdateSelfFortress(selfHp, selfMaxHp);
        _ghostPanel?.Bind(ghostHp, ghostMaxHp, ghostAlive);
        UpdatePhase(elapsed);
    }

    private void UpdateSelfFortress(float hp, float max)
    {
        if (_selfFortressHp != null) _selfFortressHp.value = max > 0 ? hp / max : 0f;
        if (_selfFortressHpText != null) _selfFortressHpText.text = Mathf.CeilToInt(hp).ToString();
        if (_selfFortressHpFill != null)
        {
            float r = max > 0 ? hp / max : 0f;
            _selfFortressHpFill.color = r > 0.6f ? Color.green : (r > 0.3f ? Color.yellow : Color.red);
        }
    }

    // 위키(2-A): 0~60 Berserk 대기 / 60~120 Berserk(적 CC 면역)·Termination 대기 / 120+ Termination(양측 -1000HP/s)
    private void UpdatePhase(float elapsed)
    {
        bool berserk = elapsed >= BERSERK_AT;          // 60s+ : 적 CC 면역 활성
        bool termination = elapsed >= TERMINATION_AT;  // 120s+ : 양측 요새 드레인
        if (_berserkActiveIndicator != null) _berserkActiveIndicator.SetActive(berserk && !termination);
        if (_terminationActiveIndicator != null) _terminationActiveIndicator.SetActive(termination);

        if (!berserk) // 0~60s: Berserk까지 카운트다운
        {
            if (_phaseLabel != null) _phaseLabel.text = LocalizationManager.GetLocalizedText("vanguard_berserk_in");
            if (_berserkTimerText != null) _berserkTimerText.text = Mathf.CeilToInt(BERSERK_AT - elapsed).ToString();
        }
        else if (!termination) // 60~120s: Berserk 활성 + Termination까지 카운트다운
        {
            if (_phaseLabel != null) _phaseLabel.text = LocalizationManager.GetLocalizedText("vanguard_termination_in");
            if (_berserkTimerText != null) _berserkTimerText.text = Mathf.CeilToInt(TERMINATION_AT - elapsed).ToString();
        }
        else // 120s+: Termination 진행 (양측 HP바가 BindFrame 값으로 매초 급감)
        {
            if (_phaseLabel != null) _phaseLabel.text = LocalizationManager.GetLocalizedText("vanguard_termination");
            if (_berserkTimerText != null) _berserkTimerText.text = string.Empty;
        }
    }

    public void SetRoundScore(int self, int opponent)
    {
        if (_selfRoundText != null) _selfRoundText.text = self.ToString();
        if (_opponentRoundText != null) _opponentRoundText.text = opponent.ToString();
    }

    public void SetGuardCount(int count)
    {
        if (_selfGuardCountText != null) _selfGuardCountText.text = count.ToString();
    }

    // ─────────── 컨트롤 (GameUI 로직 복제) ───────────
    private void OnPauseClicked() => _uiManager?.Show<PauseUI>();   // GameUI.OnPauseButtonClicked 동형
    private void OnSpeedClicked()
    {
        GameSpeedConstants.CycleUserSelectedSpeed(); // GameUI.OnGameSpeedButtonClicked 경로 재사용
        UpdateSpeedButtonImage();
    }
    private void UpdateSpeedButtonImage()
    {
        // GameUI.UpdateGameSpeedButtonImage 복제: 현재 배속 인덱스 → _gameSpeedSprites
    }
    private void OnCardClicked() { /* 카드/리프레시 — CardManager 경로 (ingame 5-2) */ }

    // ─────────── HP 이벤트 핸들러 (GameUI 복제) ───────────
    private void HandleBaseDamaged(BaseDamageEventData e) { /* GameUI.HandleBaseDamaged:1273 복제 (self) */ }
    private void HandleBossHealthUpdate(BossHealthUpdateEventData e) { /* GameUI.HandleBossHealthUpdate:1230 복제 */ }
    private void HandleEliteHealthUpdate(EliteHealthUpdateEventData e) { /* 풀에서 EliteHealthBar 가져와 Initialize/UpdateHealthBar */ }
    private void InitEliteHealthBarPool() { /* GameUI.InitializeEliteHealthBarPool:1103 복제 */ }
}
```

### 6-2. `VanguardMatchIntroPanel.cs` (매칭 인트로/VS — 신규)

> 두 유저 카드(self/opponent) 바인딩 + VS 배지 연출 + 페이드아웃까지 `PlayAsync`로 await 가능하게. 카드는 **`VanguardDuelOpponentSlot` 재사용**.

```csharp
using System.Threading.Tasks;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;

/// <summary> 매칭 성공 인트로(VS). self/opponent 카드 + VS 연출. 전투 로직 없음. </summary>
public class VanguardMatchIntroPanel : MonoBehaviour
{
    [SerializeField] private CanvasGroup _canvasGroup;
    [SerializeField] private VanguardDuelOpponentSlot _opponentCard;
    [SerializeField] private VanguardDuelOpponentSlot _selfCard;
    [SerializeField] private RectTransform _vsBadge;
    [SerializeField] private float _holdSeconds = 1.4f; // 카드 노출 유지(매직넘버는 직렬화/Const화)

    /// <summary> 카드 바인딩 → VS 연출 → 페이드아웃. 완료까지 await. </summary>
    public async Task PlayAsync(VanguardMatchData match)
    {
        gameObject.SetActive(true);
        if (_canvasGroup != null) { _canvasGroup.alpha = 1f; _canvasGroup.blocksRaycasts = true; }

        // opponent: 매칭 클론 데이터, self: 플레이어/랭크 데이터 (§아래 바인딩 분기)
        BindOpponent(match);
        BindSelf();

        // VS 배지 스케일 인 + 카드 슬라이드 인 (DOTween, CLAUDE.md: AsyncWaitForCompletion)
        if (_vsBadge != null)
        {
            _vsBadge.localScale = Vector3.zero;
            await _vsBadge.DOScale(1f, 0.35f).SetEase(Ease.OutBack).AsyncWaitForCompletion();
        }
        await UniTask.Delay((int)(_holdSeconds * 1000), DelayType.UnscaledDeltaTime);

        if (_canvasGroup != null)
            await _canvasGroup.DOFade(0f, 0.3f).AsyncWaitForCompletion();
        gameObject.SetActive(false); // 비활성만 (파괴는 UIManager.Hide가 담당)
    }

    private void BindOpponent(VanguardMatchData match)
    {
        // _opponentCard.Bind(match.ToDuelOpponent());  // 클론→DuelOpponent 매핑 (없으면 경량 바인딩 메서드 추가)
        // 인트로에선 challenge 버튼/winPoint 숨김
    }

    private void BindSelf()
    {
        // self는 DuelOpponent 데이터가 없으므로 PlayerDataManager + VanguardManager.RankService 로 채움.
        // VanguardDuelOpponentSlot에 BindSelf()/경량 바인딩 오버로드를 추가하거나, 인트로 전용 슬롯 사용.
    }
}
```

> `[설계 판단]` self 카드: `VanguardDuelOpponentSlot.Bind`는 `VanguardDuelOpponent`를 받으므로, self를 같은 슬롯으로 채우려면 (a) `VanguardDuelOpponentSlot`에 `BindSelf()` 오버로드 추가(PlayerData/RankService 사용, `VanguardRankingDisplaySlot.Init(MyRankingItem)`과 동일 소스), 또는 (b) self 정보를 담은 `VanguardDuelOpponent` 어댑터 생성. (a) 권장.

### 6-3. `VanguardGhostPanel.cs` (상단 고스트 패널 — 신규)

```csharp
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary> 상단 상대 고스트 재생 패널. 전투 로직 없음 — HP바/생존수/(v2)적 스프라이트만. </summary>
public class VanguardGhostPanel : MonoBehaviour
{
    [SerializeField] private Slider _fortressHp;
    [SerializeField] private TextMeshProUGUI _fortressHpText;
    [SerializeField] private TextMeshProUGUI _aliveCountText;
    [SerializeField] private Transform _enemyLayer;   // v2: 적 스프라이트 컨테이너

    public void Bind(float hp, float maxHp, int alive)
    {
        if (_fortressHp != null) _fortressHp.value = maxHp > 0 ? hp / maxHp : 0f;
        if (_fortressHpText != null) _fortressHpText.text = Mathf.CeilToInt(hp).ToString();
        if (_aliveCountText != null) _aliveCountText.text = alive.ToString();
    }

    // v2: VanguardGhostPlayer의 녹화 위치 샘플로 적 스프라이트 보간 이동 (ingame 4장 v2)
    // public void PlayGhostEnemies(...) { ... }
}
```

### 6-4. 데이터 주입 경로 (현 구조 유지)

[[2026-05-29_vanguard-implementation-plan-ingame]] 10장 per-frame 틱은 **`VanguardManager.Update()`**(MonoBehaviour `BaseManager`)에서 구동. 그 루프가 `VanguardInGameUI.BindFrame(...)` 호출:

```csharp
// VanguardManager.Update() 내부 (ingame 10장 UpdateBattle 자리)
var ui = _uiManager.IsOpened<VanguardInGameUI>() as VanguardInGameUI;
ui?.BindFrame(
    selfHp:   _baseSystemManager.CurrentBase.CurrentHealth,
    selfMaxHp:_baseSystemManager.CurrentBase.MaxHealth,
    selfAlive:_enemyManager.AliveEnemyCount,
    ghostHp:  _stagePlayService.Ghost.CurrentFortressHp,
    ghostMaxHp:_stagePlayService.Ghost.MaxFortressHp,
    ghostAlive:_stagePlayService.Ghost.CurrentAliveCount,
    elapsed:  _stagePlayService.ElapsedTime);
```

- **전투 시작 게이트**: `BindFrame`/스폰 루프는 `VanguardInGameUI.OpenedAsync`가 4) 단계에서 부르는 `VanguardManager.OnInGameUIReady()` 이후에만 진행. 인트로 동안은 미시작.
- self 요새 HP는 이벤트(`BaseDamaged`)로도 들어오므로 둘 중 하나로 통일 가능(이벤트 우선, Bind는 ghost/타이머 전용으로 좁혀도 됨).
- 라운드 스코어(`2/2`)는 라운드 종료 시 서비스가 `SetRoundScore` 호출.

---

## 7. 통합 지점 (현 구조 내 수정 위치)

| # | 파일 | 수정 |
|---|---|---|
| 1 | `VanguardLobbyPanel.cs` (`OnClickMatch`, `:272 TODO`) / `VanguardDuelSelectPopup.ChallengeAsync` (`:169 TODO`) | `FindMatchAsync` → `SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)` (현재 TODO 자리) |
| 2 | `StageManager.StartStageWithStageDataAsync()` 모드분기(`:924-961`) | `GameModeType.Vanguard` → `_vanguardStagePlayService` 위임 (ingame 5-1) |
| 3 | `VanguardStagePlayService` (신규, ingame 10장) | 전투 시작 시 `uiManager.Show<VanguardInGameUI>(matchData)` (PunchKing `Show<GameUI>` 자리와 동형) |
| 4 | `VanguardManager` | `OnInGameUIReady()` 추가(인트로 종료 후 스폰/타이머 시작) + `Update()`에 `BindFrame(...)` 매 프레임 호출 |
| 5 | `Utils/InGameModeVariant.cs` | `ModeVanguardSplitSetter()` 카메라 rect 분기 (4장). **전투 HUD 활성 시점에 rect 적용** |
| 6 | `VanguardDuelOpponentSlot.cs` | `BindSelf()`(또는 경량 인트로 바인딩) 오버로드 추가 — self 카드용(§6-2) |
| 7 | `GameResultUI`/종료 | Vanguard 결과는 별도 결과 UI(아웃게임) — 본 문서 범위 밖 |

> ⚠️ 일반 모드 `GameUI`는 **건드리지 않는다**. Vanguard만 전용 UI를 띄우는 분기이므로 회귀 위험 최소.

---

## 8. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardGhostPanel.cs` 작성(6-3).
2. [ ] `VanguardMatchIntroPanel.cs` 작성(6-2). `VanguardDuelOpponentSlot` 재사용, `PlayAsync`로 연출 await.
3. [ ] `VanguardDuelOpponentSlot.BindSelf()` 오버로드 추가(self 카드).
4. [ ] `VanguardInGameUI.cs` 작성(6-1). `OpenedAsync`에 인트로→전투 전환, `GameUI`의 속도/일시정지/요새HP/정예풀 로직 복제. 빌드-그린.
5. [ ] `VanguardStagePlayService`에 `Show<VanguardInGameUI>(matchData)` (이미 ingame 10장 설계 → UI 호출만 추가).
6. [ ] `VanguardManager`에 `OnInGameUIReady()` + `Update()`의 `BindFrame` 호출 연결.
7. [ ] `InGameModeVariant`에 `ModeVanguardSplitSetter()` 추가(전투 HUD 활성 시점 rect 적용).

**B. 프리팹** (`VanguardInGameUI.prefab` 신규, `3_Prefabs/UI/Vanguard/`)

8. [ ] 5장 하이어라키대로 구성: **IntroPanel(CanvasGroup) + BattleHud(CanvasGroup)** 2 그룹.
9. [ ] IntroPanel: `VanguardDuelOpponentSlot` 2개(self/opponent) + VsBadge + Dim. `VanguardMatchIntroPanel` 연결.
10. [ ] BattleHud/MidHud: `VanguardRankingDisplaySlot` 2개(self/opponent) + Pause/Speed/Card 버튼 + RoundBadge + BerserkTimer 연결.
11. [ ] BattleHud/SelfHud: 요새 HP Slider/Fill/Text + GuardIcon + BossHpBar + EliteHpBarContainer(+prefab) 연결.
12. [ ] BattleHud/GhostPanel에 `VanguardGhostPanel` + 요새HP/aliveCount 연결.
13. [ ] 속도 버튼 스프라이트 배열(`_gameSpeedSprites`) = `GameUI`와 동일 에셋 참조.
14. [ ] `uiPosition = HUD` 확인, Canvas/sort order가 전투 위에 오도록. IntroPanel이 BattleHud보다 위 레이어.

**C. 통합/연동**

15. [ ] `VanguardLobbyPanel` Match / `VanguardDuelSelectPopup` Duel → `LoadGameSceneAsync(Vanguard)` 연결.
16. [ ] `StageManager` 모드분기에 Vanguard 추가.
17. [ ] Localization 키: `vanguard_berserk_in`, `vanguard_termination_in`, `vanguard_termination`.
18. [ ] 카메라 rect/orthographicSize 플레이 테스트 조정(하단 절반에 전장 fit).

**D. 후속(v2, 폴리시)**

19. [ ] `VanguardGhostPanel.PlayGhostEnemies` — 고스트 적 스프라이트 위치 재생(ingame 4장 v2, cullingMask 카메라).
20. [ ] 인트로 연출 폴리시(카드 슬라이드/VS 플래시/사운드).
21. [ ] 데미지 숫자 캔버스/카메라 Vanguard 정합 확인.

---

## 9. 검증 체크리스트

- [ ] 로비 Match/Duel → GameScene 진입 → `VanguardInGameUI` 표시, `GameUI`는 안 뜸.
- [ ] **인트로(VS)**: self/opponent 카드에 프로필/프레임/티어/메달수(x100·x99)/이름 정상 표기.
- [ ] **인트로→전투 전환**: 연출 종료 후 BattleHud 페이드인, 전투 시작 신호(`OnInGameUIReady`) 후에만 스폰/타이머 시작.
- [ ] 인트로 동안 하단 전투 버튼 오입력 없음(CanvasGroup blocksRaycasts).
- [ ] 스플릿: 하단=내 전투(카메라), 상단=고스트 패널. 미러 방향 정합.
- [ ] 헤더 2개에 아바타/이름/티어/점수(◆) 정상 표기(self/opponent).
- [ ] 내 요새 HP Slider/숫자/색상(녹>황>적) 갱신(`BaseDamaged`).
- [ ] 정예/보스 HP바 + "x10/x9" 배수 표기(`EliteHealthBar` 재사용).
- [ ] 데미지 숫자 표시(`DamageTextManager`).
- [ ] Berserk 타이머 60s→0 카운트다운, 60s 후 Termination 표기 전환.
- [ ] 일시정지/배속 버튼 동작(PauseUI/배속 사이클) — `GameUI`와 동일 거동.
- [ ] 고스트 패널 HP/생존수가 `VanguardGhostPlayer` 값으로 재생.
- [ ] `Closed()`에서 이벤트/버튼 리스너 전부 해제(누수 없음).
- [ ] CLAUDE.md 준수: GetManager만 / `async void` 없음(UniTaskVoid·Task) / `EventManager` static / 텍스트 로컬라이즈 / 매직넘버 const·직렬화 / `DateTime.Now`·`UnityEngine.Random` 없음 / DOTween `AsyncWaitForCompletion`(ToUniTask 금지).

---

## 10. 미해결 / 확인 필요

**위키로 확정됨 (가정 폐기)**

- [x] **페이즈 타이밍**: 60s Berserk(적 CC 면역) / 120s Termination(양측 -1000HP/s). (2-A)
- [x] **라운드 구성**: 일반 6 + 정예 2 → `EliteHealthBar` 동시 최대 2개. (2-A)
- [x] **카드**: 라운드 고정 카드 세트(전 플레이어 동일) + Ember Pass 라운드 시작 랜덤 카드. (2-A)
- [x] **헤더/인트로 데이터**: 랭크(◆ Vanguard Mark)·공격력·칩 수·메달 수 (`VanguardDuelOpponentSlot`/Duel 선택 화면과 동일 소스). (2-A)
- [x] **단일 프리팹 + 인트로/전투 전환 구조 확정**: `UIBase.OpenedAsync` 연출 훅 + 스샷 근거로 채택. (0-A)

**여전히 위키 미표기 (실게임/기획 확정 필요)**

- [ ] **인트로 노출 시간/스킵**: VS 연출 지속 초/탭 스킵 허용 여부. `_holdSeconds` 기본값과 스킵 정책 기획 확정.
- [ ] **인트로 카드 표기 항목**: 메달수(x100/x99) 외 공격력/칩수도 노출할지(이미지엔 메달만 보임). `VanguardDuelOpponentSlot` 필드 취사.
- [ ] **금색 보석 x100/x99 정확한 의미**: `medalCount`로 매핑했으나 메달/포인트/승수 중 무엇인지 실게임 확인.
- [ ] **라운드 배지 `2/2` 정확한 의미**: 라운드 진행수 vs 처치 점수 vs 승점 — 위키 in-game HUD 콜아웃 없음. 실게임 영상 확인.
- [ ] **요새 옆 아이콘 `8` 의미**: 위키 미표기. 후보 — 칩#5 면역 스택/방어막 수/웨이브. 확정 후 `SetGuardCount` 소스 연결.
- [ ] **고스트 보스/정예 HP바 범위**: v1에서 요새HP/생존수만 vs 보스바 포함 — 기획 결정.
- [ ] **데미지 숫자/UI 캔버스 정렬**: 스플릿 카메라 환경에서 월드→스크린 변환 정합(`DamageTextManager`가 메인 카메라 기준).
- [ ] **카메라 rect 적용 타이밍**: 인트로(풀스크린) → 전투(하단 절반) 전환 시 rect/orthographicSize 동기.
- [ ] **Localization 키 추가**: `vanguard_berserk_in`, `vanguard_termination_in`, `vanguard_termination`.

---

> 작성: 2026-06-03 · 선행 코드 확인: `GameUI`(`UI/GameUI.cs`, `Opened:234`/속도·일시정지·HP·정예풀), `PunchKingStagePlayService:586`(Show<GameUI> 패턴), `SceneManager.LoadGameSceneAsync:158`, `EliteHealthBar`, `DamageTextManager:95`, `VanguardRankingDisplaySlot`, `InGameModeVariant`(360 선례). 전투 로직은 [[2026-05-29_vanguard-implementation-plan-ingame]] 참조 — 본 문서는 UI 레이어 전담.
> 보완: 2026-06-03 · [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) V0.13.7 "Event Info & Rules" 분석 반영(§2-A 인게임 규칙).
> 개정: 2026-06-06 · **단일 프리팹 `VanguardInGameUI`(인트로 VS + 스플릿 전투 HUD)** 구조로 통합 확정(§0-A). 이미지1(VS 인트로) 분석 추가(§2-0), 인트로 카드는 `VanguardDuelOpponentSlot` 재사용. 코드 재확인: `UIBase.OpenedAsync`(연출 훅, `UIBase.cs:81`), `VanguardDuelOpponentSlot`(`_profileIcon`/`_profileFrame`/`_tierBadge`/`_medalCountText` `:14-21`,`:59`), `RankingDisplaySlot`(`_profileIconImage`/`_profileFrameImage` `:11-12`), `VanguardLobbyPanel:272`/`VanguardDuelSelectPopup:169` TODO 자리.
