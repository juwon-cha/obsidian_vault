# Vanguard 인게임 전투 UI(VanguardBattleUI) 구현 종합 문서 (2026-06-03)

## 문서 목적

뱅가드 로비에서 **Match/Duel** 진입 → `GameScene` 이동 → **뱅가드 전용 인게임 UI(스플릿뷰)** 표시 → 전투 시작. 그중 **인게임 UI 프리팹 + 스크립트**를 이 문서만 보고 제작할 수 있도록 정리한다.

- 전투 로직(고스트/녹화/페이즈/점수/칩효과)은 이미 [[2026-05-29_vanguard-implementation-plan-ingame]] 에 상세 설계됨. **본 문서는 그 위에 얹는 "보이는 UI"** 만 다룬다(중복 설계 금지).
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]](아웃게임 터렛/칩 장착 UI)
- `[설계 판단]` = 위키/스샷에 없어 설계로 보완한 부분.

> ⚠️ **인게임 로직은 현재 구조에서 벗어나지 않는다**(사용자 요구). GameScene 재활용, `BaseStagePlayService` 상속, `UIManager.Show<T>()` 프리팹 구동 — 전부 기존 패턴. 신규는 **UI 프리팹/스크립트 + 카메라 뷰포트 분기**뿐.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 인게임 UI | **신규 `VanguardBattleUI : UIBase`** 프리팹 1개 (`GameUI`를 대체, 기존 GameUI는 건드리지 않음) |
| 표시 시점 | `VanguardStagePlayService`가 전투 시작 시 `uiManager.Show<VanguardBattleUI>()` — **PunchKing이 `Show<GameUI>()` 하는 자리와 동일 패턴** |
| 씬 | `GameScene` 재활용 (`SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)`) |
| 스플릿 | 하단 = 내 실제 전투(메인 카메라 뷰포트 축소), 상단 = 상대 고스트 패널. `InGameModeVariant`에 Vanguard 분기 추가 |
| 재사용 | `GameUI`의 속도/일시정지/HP바 로직, `EliteHealthBar`(정예 HP + "x10" 배수), `DamageTextManager`(데미지 숫자), `VanguardRankingDisplaySlot`(플레이어 헤더), `PauseUI` |
| 신규 컴포넌트 | `VanguardBattleUI.cs`, `VanguardGhostPanel.cs`(상단 고스트 패널) — 2개 |
| 데이터 주입 | `VanguardStagePlayService`/`VanguardManager.Update()`가 매 프레임 self/ghost 값 push (이벤트 + Bind 혼용) |

---

## 1. 진입 플로우 (확인된 코드 기준)

```
VanguardLobbyPanel.OnClickMatch()  (또는 OnClickDuel)
  └─ await VanguardManager.FindMatchAsync(EVanguardMode)         // ingame 10장: { matchId, opponentClone, matchSeed }
       └─ SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, vanguardStageId)   // SceneManager.cs:158 → "GameScene"
            └─ [GameScene 로드 / CurrentGameMode=Vanguard, SelectedStageID 세팅]
                 └─ StageManager → VanguardStagePlayService.StartVanguardBattleAsync(matchData)   // ingame 10장
                      ├─ uiManager.Show<VanguardBattleUI>(matchData)   ★ 본 문서 UI 진입점
                      ├─ (VanguardBattleUI.Opened에서 split 카메라/헤더/HP바 초기화)
                      └─ RunRoundsAsync(...)   // 기존 ProcessWavesAsync 골격
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

→ Vanguard도 **`VanguardStagePlayService`에서 `Show<VanguardBattleUI>()` + 초기화 직접 호출**. 일반 모드는 `GameUI`가 씬 자동활성, Vanguard만 전용 UI로 치환(`GameUI`는 띄우지 않음). 모드 분기는 서비스 단위라 **중앙 스위치 불필요**(각 StagePlayService가 자기 UI를 띄우는 현 구조 유지).

> `LoadGameSceneAsync(GameModeType, int)`(`SceneManager.cs:158`)가 `CurrentGameMode`/`SelectedStageID` 세팅 후 `"GameScene"` 로드. `GameUI.Opened(object[] param)`는 `param[0] is StageDataSO`를 옵션 인자로 받음 → `VanguardBattleUI`도 `matchData`를 `param[0]`으로 받는 동일 시그니처.

---

## 2. 이미지 상세 분석 (스플릿 PvP 전투 화면)

화면은 **세로 2분할 미러 스플릿**. 위=상대 고스트(거꾸로/미러), 아래=내 전투. 가운데 띠=공유 HUD.

### 2-1. 상단 — 상대 고스트(A_Cat) 영역 (미러)

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 상대 요새(GTS) | 최상단, 터렛 3문 + 구조물 | 고스트 요새 아트(정적/애니, 미러) |
| 보스 HP바 | `EL` 라벨 + 게이지 + `4000` | 정예/보스 HP — **`EliteHealthBar` 재사용** (단, 고스트는 비주얼 재생) |
| 터렛 클러스터 | 흰 점박이 원형 다수(군집) | 상대 배치 터렛 — 고스트 v2 비주얼(아이콘) |
| 적(박쥐형) + `9x` | 보스 위 주황 호 `9x` | 정예 페이즈 배수 = `EliteHealthBar._healthPhaseText` ("x9") |
| 우측 적 + `6x`, `-827` | 박쥐형 + 데미지 | 페이즈 배수 + 데미지 숫자 |

`[설계 판단]` 상단은 **전투 시뮬레이션이 아니라 고스트 재생**([[2026-05-29_vanguard-implementation-plan-ingame]] 4장 v1/v2). v1=HP바+생존 적 수만, v2=적 스프라이트 위치 재생. 본 UI는 **v1 우선**(HP바/카운트/요새), v2는 `VanguardGhostPanel` 확장으로 후속.

### 2-2. 가운데 — 공유 HUD 띠

| 요소 | 스샷 | 매핑 |
|---|---|---|
| 상대 헤더 | `A_Cat` + 아바타 + ◆`1` | `VanguardRankingDisplaySlot`. ◆ = Vanguard Mark(랭크 포인트/승리 시 획득 점수) |
| 컨트롤 | `‖`(일시정지) · `x2`(배속) · 카드/티켓 아이콘 | **`GameUI` 재사용**: `_pauseButton`/`_gameSpeedButton`. 카드 버튼 = 라운드 고정 카드 보기(위키 2-A) |
| 라운드/스코어 배지 | 원형 `2 / 2`(상=상대, 하=나) | 양측 진행/점수 비교 표기. 신규 `_selfRoundText`/`_opponentRoundText` (의미는 §10 확인) |
| Berserk 타이머 | `Berserk in: 34` | 페이즈 3단계 카운트다운(2-A). 신규 `_berserkTimerText`/`_phaseLabel` |
| 내 헤더 | `TopTap_on_YT` + 아바타 + ◆`0` | `VanguardRankingDisplaySlot`. self는 `MyRankingItem` |

### 2-3. 하단 — 내 전투(TopTap_on_YT) 영역 (인터랙티브)

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
4. **헤더 데이터**: Duel 선택 화면이 상대의 **현재 랭크(Vanguard Mark ◆) · 공격력 · 칩 수 · 승리 시 점수**를 보여줌 → 인게임 헤더(self/opponent)도 동일 데이터 소스(랭크/공격력/칩 수) 사용 가능.

> **Battle Report(결과)**: 위키 — Overview(장착 칩 스탯 표시)가 승/패 결과 리포트에도 동일하게 표시됨. → 결과 화면은 [[2026-06-03_vanguard-turret-setup-ui]]의 Overview 패널을 재사용(본 문서 범위 밖, 결과 UI 설계 시 연계).

---

## 3. 재사용 자산 분석

> 신규 프리팹은 `VanguardBattleUI`(루트) + `VanguardGhostPanel`(상단)뿐. 나머지는 기존 컴포넌트/이벤트 재사용.

| 자산 | 경로 | 재사용 방식 | 핵심 API/필드 |
|---|---|---|---|
| **GameUI** | `UI/GameUI.cs` (`:13 UIBase`) | **로직 참고/복제** (그대로 띄우지 않음) | 속도: `_gameSpeedButton`/`_gameSpeedButtonImage`/`_gameSpeedSprites`/`OnGameSpeedButtonClicked():550`/`UpdateGameSpeedButtonImage():628` · 일시정지: `_pauseButton`/`OnPauseButtonClicked():671` · 요새HP: `_baseHealthSlider`/`_baseHealthFillImage`/`_baseHealthText`/`HandleBaseDamaged():1273` · 보스HP: `_bossHealthSlider`/`HandleBossHealthUpdate():1230` · 카운트다운: `SetCountdownMode(float)` |
| **EliteHealthBar** | `UI/Components/EliteHealthBar.cs` (MonoBehaviour) | **그대로 재사용** (정예 HP바 + "x10/x9" 배수 = 스샷의 9x/6x/x10) | `Initialize(BaseEnemyController, EliteHealthUpdateEventData)` · `UpdateHealthBar(EliteHealthUpdateEventData)` · `_healthPhaseText`("x10") · `UpdateEliteHealthBarPosition():129` · 풀: `GameUI.InitializeEliteHealthBarPool():1103` |
| **DamageTextManager** | `Core/Managers/DamageTextManager.cs` (`BaseManager`) | **그대로 재사용** (데미지 숫자) | `ShowDamageText(float, Vector3 world, Transform follow, EDamageTextType):95` / `DamageText.Show(...)` |
| **VanguardRankingDisplaySlot** | `UI/Vanguard/Component/VanguardRankingDisplaySlot.cs` | **헤더로 재사용** (아바타/이름/티어/점수) | `Init(VanguardRankingItem)` / `Init(VanguardMyRankingItem)` · `_profileIconImage`/`_userName`/`_tierBadgeImage`/`_pointsText` · `LoadProfileIconAsync(int)`(base) |
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
    // 상단 절반은 VanguardBattleUI의 GhostPanel(UI)로 채움
    // v1: 카메라 1대(하단만). v2에서 상단 고스트 적 스프라이트 필요 시
    //     cullingMask 분리한 2번째 카메라(rect 0,0.5,1,0.5) 추가 검토 (ingame 4장 v2)
}
```

- 진입: 360모드 분기와 동일 자리에서 `SceneManager.CurrentGameMode == GameModeType.Vanguard` 체크.
- `orthographicSize`는 하단 절반에 전체 전장이 들어오도록 조정(360모드가 8f로 바꾸는 것과 동형). 정확값은 플레이 테스트.
- **카메라 1대 유지(v1)** → 싱글톤/성능 안전. 상단은 순수 UI 패널.

---

## 5. UI 프리팹 구조 (전체 하이어라키)

> 신규 프리팹 `Assets/_Project/3_Prefabs/UI/Vanguard/VanguardBattleUI.prefab`. 루트에 `VanguardBattleUI.cs`. `uiPosition = eUIPosition.HUD`(전투 HUD).

```
VanguardBattleUI (루트 Canvas/CanvasGroup, ▶ VanguardBattleUI.cs)
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

- **데미지 숫자**는 `DamageTextManager`(BaseManager)가 자체 캔버스에 띄우므로 프리팹에 둘 필요 없음. 단, Vanguard 캔버스/카메라 정합 확인.
- `EliteHpBarContainer`/`_eliteHealthBarPrefab`은 `GameUI`의 `InitializeEliteHealthBarPool()` 로직 복제.

---

## 6. 스크립트 설계

### 6-1. `VanguardBattleUI.cs` (참조 구현)

> `GameUI`의 속도/일시정지/요새HP 핸들러를 복제하고, self/ghost 분리 + 헤더 + Berserk 타이머를 추가. 데이터는 이벤트 구독 + `VanguardStagePlayService`의 per-frame `Bind()` 혼용. CLAUDE.md 준수.

```csharp
using System;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 인게임 스플릿 전투 HUD. 하단=내 전투, 상단=상대 고스트 패널.
/// VanguardStagePlayService가 Show<VanguardBattleUI>(matchData)로 띄우고 매 프레임 Bind로 값 주입.
/// </summary>
public class VanguardBattleUI : UIBase
{
    #region Serialized

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
    [SerializeField] private GameObject _berserkActiveIndicator;  // 60~120s 적 CC 면역 표식
    [SerializeField] private GameObject _terminationActiveIndicator; // 120s+ 양측 드레인 표식
    [SerializeField] private GameObject _touchBlocker;

    private const float BERSERK_AT = 60f;
    private const float TERMINATION_AT = 120f;

    #endregion

    private UIManager _uiManager;
    private float _maxFortressHp;

    public override void Opened(object[] param)
    {
        base.Opened(param);
        uiPosition = eUIPosition.HUD;
        _uiManager = Managers.Instance.GetManager<UIManager>();

        VanguardMatchData match = (param != null && param.Length > 0) ? param[0] as VanguardMatchData : null;
        SetupHeaders(match);
        InitEliteHealthBarPool();         // GameUI.InitializeEliteHealthBarPool 복제

        _pauseButton.onClick.AddListener(OnPauseClicked);
        _gameSpeedButton.onClick.AddListener(OnSpeedClicked);
        _cardButton.onClick.AddListener(OnCardClicked);

        // 요새/보스/정예 HP 이벤트 (GameUI와 동일 구독)
        EventManager.Subscribe<BaseDamageEventData>(GameEventType.BaseDamaged, HandleBaseDamaged);
        EventManager.Subscribe<BossHealthUpdateEventData>(GameEventType.BossHealthUpdate, HandleBossHealthUpdate);
        EventManager.Subscribe<EliteHealthUpdateEventData>(GameEventType.EliteHealthUpdate, HandleEliteHealthUpdate);

        UpdateSpeedButtonImage();
    }

    public override void Closed(object[] param)
    {
        EventManager.Unsubscribe<BaseDamageEventData>(GameEventType.BaseDamaged, HandleBaseDamaged);
        EventManager.Unsubscribe<BossHealthUpdateEventData>(GameEventType.BossHealthUpdate, HandleBossHealthUpdate);
        EventManager.Unsubscribe<EliteHealthUpdateEventData>(GameEventType.EliteHealthUpdate, HandleEliteHealthUpdate);
        base.Closed(param);
    }

    private void SetupHeaders(VanguardMatchData match)
    {
        var rank = Managers.Instance.GetManager<VanguardManager>()?.RankService;
        // _selfHeader.Init(rank?.MyRankingItem);
        // _opponentHeader.Init(match?.opponentClone?.profile);  // 고스트 프로필
    }

    // ─────────── per-frame 값 주입 (VanguardStagePlayService/Manager.Update가 호출) ───────────
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

### 6-2. `VanguardGhostPanel.cs` (상단 고스트 패널 — 신규)

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

### 6-3. 데이터 주입 경로 (현 구조 유지)

[[2026-05-29_vanguard-implementation-plan-ingame]] 10장 per-frame 틱은 **`VanguardManager.Update()`**(MonoBehaviour `BaseManager`)에서 구동. 그 루프가 `VanguardBattleUI.BindFrame(...)` 호출:

```csharp
// VanguardManager.Update() 내부 (ingame 10장 UpdateBattle 자리)
var ui = _uiManager.IsOpened<VanguardBattleUI>() as VanguardBattleUI;
ui?.BindFrame(
    selfHp:   _baseSystemManager.CurrentBase.CurrentHealth,
    selfMaxHp:_baseSystemManager.CurrentBase.MaxHealth,
    selfAlive:_enemyManager.AliveEnemyCount,
    ghostHp:  _stagePlayService.Ghost.CurrentFortressHp,
    ghostMaxHp:_stagePlayService.Ghost.MaxFortressHp,
    ghostAlive:_stagePlayService.Ghost.CurrentAliveCount,
    elapsed:  _stagePlayService.ElapsedTime);
```

- self 요새 HP는 이벤트(`BaseDamaged`)로도 들어오므로 둘 중 하나로 통일 가능(이벤트 우선, Bind는 ghost/타이머 전용으로 좁혀도 됨).
- 라운드 스코어(`2/2`)는 라운드 종료 시 서비스가 `SetRoundScore` 호출.

---

## 7. 통합 지점 (현 구조 내 수정 위치)

| # | 파일 | 수정 |
|---|---|---|
| 1 | `VanguardLobbyPanel.cs` (`OnClickMatch`/`OnClickDuel`) | `FindMatchAsync` → `SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)` (현재 TODO 자리) |
| 2 | `StageManager.StartStageWithStageDataAsync()` 모드분기(`:924-961`) | `GameModeType.Vanguard` → `_vanguardStagePlayService` 위임 (ingame 5-1) |
| 3 | `VanguardStagePlayService` (신규, ingame 10장) | 전투 시작 시 `uiManager.Show<VanguardBattleUI>(matchData)` (PunchKing `Show<GameUI>` 자리와 동형) |
| 4 | `VanguardManager.Update()` | `VanguardBattleUI.BindFrame(...)` 매 프레임 호출 |
| 5 | `Utils/InGameModeVariant.cs` | `ModeVanguardSplitSetter()` 카메라 rect 분기 (4장) |
| 6 | `GameResultUI`/종료 | Vanguard 결과는 별도 결과 UI(아웃게임) — 본 문서 범위 밖 |

> ⚠️ 일반 모드 `GameUI`는 **건드리지 않는다**. Vanguard만 전용 UI를 띄우는 분기이므로 회귀 위험 최소.

---

## 8. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardGhostPanel.cs` 작성(6-2).
2. [ ] `VanguardBattleUI.cs` 작성(6-1). `GameUI`의 속도/일시정지/요새HP/정예풀 로직 복제. 빌드-그린.
3. [ ] `VanguardStagePlayService`에 `Show<VanguardBattleUI>(matchData)` + 초기화(이미 ingame 10장 설계 → UI 호출만 추가).
4. [ ] `VanguardManager.Update()`에 `BindFrame` 호출 연결.
5. [ ] `InGameModeVariant`에 `ModeVanguardSplitSetter()` 추가.

**B. 프리팹** (`VanguardBattleUI.prefab` 신규, `3_Prefabs/UI/Vanguard/`)

6. [ ] 5장 하이어라키대로 구성: GhostPanel(상) / MidHud(중) / SelfHud(하) / TouchBlocker.
7. [ ] MidHud: `VanguardRankingDisplaySlot` 2개(self/opponent) + Pause/Speed/Card 버튼 + RoundBadge + BerserkTimer 연결.
8. [ ] SelfHud: 요새 HP Slider/Fill/Text + GuardIcon + BossHpBar + EliteHpBarContainer(+prefab) 연결.
9. [ ] GhostPanel에 `VanguardGhostPanel` + 요새HP/aliveCount 연결.
10. [ ] 속도 버튼 스프라이트 배열(`_gameSpeedSprites`) = `GameUI`와 동일 에셋 참조.
11. [ ] `uiPosition = HUD` 확인, Canvas/sort order가 전투 위에 오도록.

**C. 통합/연동**

12. [ ] `VanguardLobbyPanel` Match/Duel → `LoadGameSceneAsync(Vanguard)` 연결.
13. [ ] `StageManager` 모드분기에 Vanguard 추가.
14. [ ] Localization 키: `vanguard_berserk_in`, `vanguard_termination_in`, `vanguard_termination`.
15. [ ] 카메라 rect/orthographicSize 플레이 테스트 조정(하단 절반에 전장 fit).

**D. 후속(v2, 폴리시)**

16. [ ] `VanguardGhostPanel.PlayGhostEnemies` — 고스트 적 스프라이트 위치 재생(ingame 4장 v2, cullingMask 카메라).
17. [ ] 데미지 숫자 캔버스/카메라 Vanguard 정합 확인.

---

## 9. 검증 체크리스트

- [ ] 로비 Match/Duel → GameScene 진입 → `VanguardBattleUI` 표시, `GameUI`는 안 뜸.
- [ ] 스플릿: 하단=내 전투(카메라), 상단=고스트 패널. 미러 방향 정합.
- [ ] 헤더 2개에 아바타/이름/티어/점수(◆) 정상 표기(self/opponent).
- [ ] 내 요새 HP Slider/숫자/색상(녹>황>적) 갱신(`BaseDamaged`).
- [ ] 정예/보스 HP바 + "x10/x9" 배수 표기(`EliteHealthBar` 재사용).
- [ ] 데미지 숫자 표시(`DamageTextManager`).
- [ ] Berserk 타이머 60s→0 카운트다운, 60s 후 Termination 표기 전환.
- [ ] 일시정지/배속 버튼 동작(PauseUI/배속 사이클) — `GameUI`와 동일 거동.
- [ ] 고스트 패널 HP/생존수가 `VanguardGhostPlayer` 값으로 재생.
- [ ] `Closed()`에서 이벤트 전부 해제(누수 없음).
- [ ] CLAUDE.md 준수: GetManager만 / `async void` 없음 / `EventManager` static / 텍스트 로컬라이즈 / 매직넘버 const화 / `DateTime.Now`·`UnityEngine.Random` 없음.

---

## 10. 미해결 / 확인 필요

**위키로 확정됨 (가정 폐기)**

- [x] **페이즈 타이밍**: 60s Berserk(적 CC 면역) / 120s Termination(양측 -1000HP/s). (2-A)
- [x] **라운드 구성**: 일반 6 + 정예 2 → `EliteHealthBar` 동시 최대 2개. (2-A)
- [x] **카드**: 라운드 고정 카드 세트(전 플레이어 동일) + Ember Pass 라운드 시작 랜덤 카드. (2-A)
- [x] **헤더 데이터**: 랭크(◆ Vanguard Mark)·공격력·칩 수 (Duel 선택 화면과 동일 소스). (2-A)

**여전히 위키 미표기 (실게임/기획 확정 필요)**

- [ ] **라운드 배지 `2/2` 정확한 의미**: 라운드 진행수 vs 처치 점수 vs 승점 — 위키에 in-game HUD 콜아웃이 없음(저자가 "추후 추가" 명시). 실게임 영상 확인.
- [ ] **요새 옆 아이콘 `8` 의미**: 위키 미표기. 후보 — 칩#5 면역 스택/방어막 수/웨이브. 확정 후 `SetGuardCount` 소스 연결.
- [ ] **고스트 보스/정예 HP바 범위**: v1에서 요새HP/생존수만 vs 보스바 포함 — 기획 결정.
- [ ] **데미지 숫자/UI 캔버스 정렬**: 스플릿 카메라 환경에서 월드→스크린 변환 정합(`DamageTextManager`가 메인 카메라 기준).
- [ ] **Self=하단 확정** 반영: [[2026-05-29_vanguard-implementation-plan-ingame]] 10장 카메라 rect(현재 Self=상단 표기) 정정 필요.
- [ ] **Localization 키 추가**: `vanguard_berserk_in`, `vanguard_termination_in`, `vanguard_termination`.

---

> 작성: 2026-06-03 · 선행 코드 확인: `GameUI`(`UI/GameUI.cs`, `Opened:234`/속도·일시정지·HP·정예풀), `PunchKingStagePlayService:586`(Show<GameUI> 패턴), `SceneManager.LoadGameSceneAsync:158`, `EliteHealthBar`, `DamageTextManager:95`, `VanguardRankingDisplaySlot`, `InGameModeVariant`(360 선례). 전투 로직은 [[2026-05-29_vanguard-implementation-plan-ingame]] 참조 — 본 문서는 UI 레이어 전담.
> 보완: 2026-06-03 · [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) V0.13.7 "Event Info & Rules" 분석 반영(§2-A 인게임 규칙: 페이즈 타이밍/라운드 6+2/고정 카드/티어·텔레포트 스케일/Termination 양측 드레인). 위키엔 인게임 스플릿 HUD 콜아웃이 없어(저자 "추후 추가" 명시) 일부 항목은 §10 미해결로 유지.
