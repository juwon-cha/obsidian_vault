# Vanguard 3라운드 종료 클래시 연출(VanguardMatchEndClashCutscene) 구현 종합 문서 (2026-06-09)

## 문서 목적

3라운드(2선승제)가 끝나는 순간 재생되는 **대각선 분할 VS "클래시" 연출**(첨부 GIF: 좌 `TopTap_on_YT`(블루) ↔ 우 `Bobbabadoh`(핑크), 가운데 황금 번개선 + 스파크, 양측 ◆`x1`·랭크 뱃지(`II`/`I`)·아바타)의 프리팹 + 스크립트 + Editor 빌더를 **이 문서만 보고 완전하게 제작·구현**할 수 있도록 정리한다. **GIF와 최대한 동일한 형태/연출**이 목표.

- **들어갈 자리(확정)**: 이미 존재하는 `VanguardInGameUI.PlayMatchEndSequenceAsync()` 가 현재 빈 TODO 스텁이다(`UI/Vanguard/UI/VanguardInGameUI.cs:279`). **이 메서드 본문이 곧 본 연출의 호출 지점**이다. 라운드 3 종료 → `OnRoundDecidedAsync` 가 `Time.timeScale=0` 으로 전투를 멈춘 직후 호출되고, 연출이 끝나면 `ShowResultPopup()`(`VanguardGameResultUI`) 으로 넘어간다.
- **네이밍**: 신규 컴포넌트 **`VanguardMatchEndClashCutscene`**(연출 본체) + **`VanguardClashCard`**(좌/우 클래시 카드 1장). 둘 다 `UI/Vanguard/Component/`.
- 짝 문서: [[2026-06-04_vanguard-round-result-banner-ui]](라운드별 ◆+점수 배너 — 본 연출의 "축약판"), [[2026-06-03_vanguard-ingame-battle-ui]](호스트 `VanguardInGameUI` / VS 인트로 `VanguardMatchIntroPanel`), [[2026-06-04_vanguard-game-result-ui]](연출 직후 진입하는 최종 결과 팝업)
- `[설계 판단]` = GIF/명세 미표기 보완.

> **관계 정리(중요)**: 인게임에는 이미 라운드 결과 표현이 3개 레이어로 나뉜다 — ① 상시 가운데 밴드 점수(`SetRoundScore`) ② 라운드마다 뜨는 ◆+점수 배너(`VanguardRoundResultBanner`) ③ **3R 종료 시 1회 뜨는 본 클래시 연출(신규)**. 본 문서는 ③을 채운다. 기존 ②와 충돌하지 않으며, ②가 라운드 1·2·3 점수 펄스를 담당하고 ③이 매치 종료의 "결정타" 연출을 담당한다(§1 흐름).

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 신규 클래스 | `VanguardMatchEndClashCutscene : MonoBehaviour`(연출 본체) + `VanguardClashCard : MonoBehaviour`(좌/우 카드) — **`UIBase` 아님**, `VanguardInGameUI` 자식 컴포넌트 |
| 신규 프리팹 | `VanguardMatchEndClashCutscene.prefab` → **`VanguardInGameUI` 프리팹의 자식**(전체 화면 오버레이, `_roundResultBanner` 와 형제). 기본 비활성 |
| 신규 Editor 빌더 | `VanguardMatchEndClashCutsceneBuilder.cs` (`[MenuItem("Vanguard/Build MatchEndClashCutscene")]`) — `VanguardRoundResultBannerBuilder` 패턴 답습 |
| 진입 | `VanguardInGameUI.PlayMatchEndSequenceAsync()` 본문에서 `await _matchEndClash.PlayAsync(self, opponent, selfScore, opponentScore, selfWon)` (라운드 3 종료, `Time.timeScale=0` 상태) |
| 출구 | 연출 완료 → 호출자가 곧바로 `ShowResultPopup()`(`VanguardGameResultUI`) → `Hide<VanguardInGameUI>()` |
| 레이아웃 | **대각선 2분할**(좌상→우하 황금선). **좌=자신(블루)** / **우=상대(핑크/마젠타)**. 카드는 평행사변형(skew)으로 분할선에 맞물림 |
| 카드 표시 | 아바타(프로필+프레임) · 닉네임 · 티어 뱃지 + 디비전 로마자(`II`/`I`) · ◆ 마크 + 누적 점수(`x{score}`) |
| 연출 | dim 인 → 양 카드 좌/우에서 슬라이드 인 → 중앙 충돌(황금선 점화 + 스파크 버스트 + 쉐이크 + SFX) → 승자 강조(펄스/밝기) · 패자 디밍 → hold → 페이드아웃 |
| 전투 정지 | **이미 호출자(`OnRoundDecidedAsync`)가 `Time.timeScale=0`** 로 멈춤. 본 연출은 **전부 `SetUpdate(true)` + `DelayType.UnscaledDeltaTime`** 으로 timeScale 무관 동작(필수) |
| 데이터 | `VanguardInGameUI._selfData`/`_opponentData`(`VanguardDuelOpponent`) + `_selfScore`/`_opponentScore`. 추가 서버 연동 불필요(이미 보유) |
| 재사용 | `VanguardTierUtil.GetTierSprite/GetDisplayName` · `VanguardTierMath.GetDivisionRoman`(`II`/`I`) · 프로필 로드 소스(ContentUnlockManager/ResourceManager, `VanguardDuelOpponentSlot` 와 동일) · DOTween |

> **왜 별도 컴포넌트인가**: GIF의 연출은 ② 배너(가로 띠 + ◆/점수만)와 레이아웃·강도가 다르다(대각선 분할, 카드 슬라이드 충돌, 스파크/쉐이크, 승패 강조). 단순 토글이 아니라 **슬라이드-충돌-강조-페이드** 시퀀스를 한 곳에 캡슐화해야 유지보수·타이밍 제어가 깔끔하다 → `PlayAsync`(UniTask) 단일 진입으로 설계. `VanguardMatchIntroPanel.PlayAsync` / `VanguardRoundResultBanner.ShowRoundResultAsync` 와 동일한 await 캡슐화 패턴.

---

## 1. 노출 / 흐름 (확인된 코드 기준)

`VanguardInGameUI.cs`(실코드) 의 라운드 흐름은 이미 완성돼 있고, **본 연출이 들어갈 한 줄만 비어 있다**:

```
스네이크 끝점 도달 → EventManager.Dispatch(VanguardRoundDecided, {SelfWon})
  └─ VanguardInGameUI.OnVanguardRoundDecided(e)            // :232 (재진입 가드 _roundBusy)
       └─ OnRoundDecidedAsync(_currentRound + 1, e.SelfWon) // :242
            ├─ _selfScore/_opponentScore++  (무승부 없음)
            ├─ Time.timeScale = 0  +  _touchBlocker ON       // 전투 정지(연출 집중)
            ├─ await _roundResultBanner.ShowRoundResultAsync(...) // ② 라운드 배너(매 라운드)
            ├─ SetRoundScore(...)                            // 가운데 밴드 동기화
            ├─ round >= 3 ?
            │    ├─ await PlayMatchEndSequenceAsync()  ★ 본 문서 — 여기서 클래시 연출 재생
            │    ├─ ShowResultPopup()                  → Show<VanguardGameResultUI>(data)
            │    ├─ VanguardOpponentField.Clear()
            │    └─ Hide<VanguardInGameUI>()            // 이후 this 파괴
            └─ round < 3 ?
                 └─ await VanguardOpponentField.ResetRoundAndRespawnAsync() → timeScale 복원 → 다음 라운드
```

- **본 연출은 `Time.timeScale=0` 상태에서 시작**된다(호출자가 이미 멈춤). 따라서 **모든 트윈은 `SetUpdate(true)`, 모든 대기는 `UniTask.Delay(..., DelayType.UnscaledDeltaTime)`**. (CLAUDE.md + 기존 배너/인트로와 동일)
- 연출 완료 후 호출자가 즉시 결과 팝업을 띄우므로, **클래시는 마지막에 페이드아웃하여 결과 팝업으로 자연스럽게 넘긴다**(또는 마지막 프레임을 hold 한 채 끝내고 결과 팝업이 위에 덮어도 됨 — §5-1 `_fadeOutAtEnd` 토글).
- ② `VanguardRoundResultBanner` 와의 순서: 현재 코드는 **3R 종료에도 배너를 먼저 보여준 뒤** `PlayMatchEndSequenceAsync` 를 호출한다. 즉 사용자는 "라운드3 점수 배너 → 클래시 연출 → 결과 팝업" 순으로 본다. 배너가 중복으로 느껴지면 §6 "옵션 B"로 3R에서는 배너를 건너뛰고 클래시만 재생하도록 분기할 수 있다(권장 옵션 제시).

---

## 2. GIF 상세 분석 (프레임 단위)

> 첨부 GIF는 Bandicam 녹화(상단 워터마크) + 하단에 재생/편집 컨트롤(▶, ✎)이 보이는 **레퍼런스 게임 영상**이다. UI 본체만 분석한다.

### 2-1. 정적 레이아웃 (충돌 직후 hold 프레임)

| # | 영역 | GIF | 매핑 |
|---|---|---|---|
| A | 화면 분할 | 좌상→우하 **황금 번개선**으로 2분할. 좌하=블루 진영, 우상=핑크 진영 | `_clashLine`(Image, 대각선) + `_dimLeft`/`_dimRight`(진영 색 반투명) |
| B | 좌 카드(자신) | `TopTap_on_YT` + 아바타(원형) + 방패형 랭크 뱃지 `II` + ◆ `x1` | `_selfCard`(`VanguardClashCard`, 블루 톤) |
| C | 우 카드(상대) | 육각 엠블럼 `I` + 랭크 뱃지 + ◆ `x1` + `Bobbabadoh` | `_opponentCard`(`VanguardClashCard`, 핑크 톤) |
| D | 중앙 충돌 FX | 황금선 위로 주황 **스파크 입자** 분출 | `_sparkBurst`(ParticleSystem 또는 Image 플래시) |
| E | 카드 형태 | 양 카드가 **평행사변형(skew)** 으로 분할선에 맞물림(좌는 우상단이 잘림, 우는 좌하단이 잘림) | 카드 배경 Image(skew 스프라이트) 또는 약한 Z회전 |
| (배경) | 흐릿한 전장 | 뒤에 전투 화면이 약하게 비침 | 본 연출은 **전체 화면 오버레이**(완전 딤 아님, 살짝 비침) |

- ◆ 옆 `x1` = **각 진영의 누적 라운드 승수**(= `_selfScore`/`_opponentScore`). 색: 자신=블루, 상대=핑크/마젠타(팀 색 고정).
- 랭크 뱃지의 `II`/`I` = **티어 디비전 로마자** → `VanguardTierMath.GetDivisionRoman(tier)`. 뱃지 스프라이트 = `VanguardTierUtil.GetTierSprite(tier)`.
- 아바타 = 프로필 아이콘 + 프레임(원형). 닉네임은 카드 색 진영 쪽에 표기.

### 2-2. 애니메이션 시퀀스 (시간 순서) `[설계 판단 — GIF 거동 기반]`

```
t0   dim/배경 오버레이 페이드 인 (0.15s)               // _dim* alpha 0→1
t1   양 카드 화면 밖 → 중앙으로 슬라이드 인 (동시, 0.25s) // self 좌(-X)→정위치, opponent 우(+X)→정위치, Ease.OutCubic
t2   충돌 순간(카드가 맞물리는 시점):
       - _clashLine 점화(alpha 0→1 + 살짝 스케일/플리커)
       - _sparkBurst 1회 재생(파티클 Emit 또는 플래시 Image DOFade 펄스)
       - 전체 컨테이너 쉐이크 (DOShakeAnchorPos, 0.2s)
       - SFX 1회 (AudioUtils.PlaySFXUnscaled)
t3   승자 강조 (0.2s): 승자 카드 DOScale 펄스(1→1.12→1) + 밝기↑ / 패자 카드 색 디밍(살짝 어둡게)
       승자 ◆ 점수 펄스 (이미 누적값 표시 — 별도 +1 증가 연출은 ②배너가 담당하므로 여기선 강조만)
t4   hold (_holdSeconds ≈ 1.5s)
t5   페이드 아웃 (_fadeOutDuration ≈ 0.3s) → 비활성  // _fadeOutAtEnd=true 일 때
```

- 전부 `SetUpdate(true)`(timeScale=0). 슬라이드/쉐이크/펄스/페이드 모두 동일.
- 승/패 판정: `selfWon = _selfScore > _opponentScore`(호출자가 전달). 2선승제이므로 3R 종료 시 항상 한쪽이 2승.

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API/필드 |
|---|---|---|---|
| **VanguardInGameUI** | `UI/Vanguard/UI/VanguardInGameUI.cs` | **호스트**(연출 보유·구동) | `PlayMatchEndSequenceAsync()`(:279 스텁 → 본문 채움) · `_selfData`/`_opponentData`(`VanguardDuelOpponent` :91-92) · `_selfScore`/`_opponentScore`(:84-85) · `_touchBlocker` |
| **VanguardDuelOpponent** | `UI/Vanguard/Popup/VanguardDuelProvider.cs` | 카드 데이터 모델(이미 보유) | `nickName`/`profileIcon`/`profileFrame`/`appliedPassType`/`tier`/`medalCount` … |
| **VanguardTierUtil** | `UI/Vanguard/VanguardTierUtil.cs` | 티어 뱃지/표시명 | `GetTierSprite(EVanguardTier)` · `GetDisplayName(EVanguardTier)` |
| **VanguardTierMath** | `UI/Vanguard/VanguardTierMath.cs` | 디비전 로마자(`II`/`I`) | `GetDivisionRoman(EVanguardTier)` |
| **프로필 로드 소스** | (DuelOpponentSlot 와 동일) | 아바타/프레임 비동기 로드 | `ContentUnlockManager.GetProfileIconData()/GetProfileFrameData()` + `ResourceManager.LoadResourceAsync<Sprite>` |
| **TextUtility** | (기존) | 닉네임 컬러(패스 타입) | `TextUtility.ApplyNicknameColor(tmp, appliedPassType)` |
| **AudioUtils** | (기존) | 충돌 SFX(정지 중) | `AudioUtils.PlaySFXUnscaled("...").Forget()` |
| **DOTween** | - | 슬라이드/쉐이크/펄스/페이드 | `DOAnchorPos`/`DOScale`/`DOFade`/`DOShakeAnchorPos` + `SetUpdate(true)` + `AsyncWaitForCompletion()` |
| **Editor 빌더 패턴** | `Editor/Vanguard/VanguardRoundResultBannerBuilder.cs` | 프리팹 코드 생성 미러 | `NewUI`/`AddImage`/`AddTMP`/`Anchor`/`AnchorBand`/`Stretch`/`WireRef`/`EnsureDir` + `SaveAsPrefabAsset` |

### 신규 작성 (3개 파일)

1. `UI/Vanguard/Component/VanguardClashCard.cs` — 좌/우 카드 1장(아바타/이름/뱃지/디비전/◆+점수).
2. `UI/Vanguard/Component/VanguardMatchEndClashCutscene.cs` — 연출 본체(`PlayAsync`).
3. `Editor/Vanguard/VanguardMatchEndClashCutsceneBuilder.cs` — 프리팹 빌더(`[MenuItem]`).
4. (호스트 수정) `VanguardInGameUI` 에 `_matchEndClash` 필드 1개 + `PlayMatchEndSequenceAsync` 본문 3줄.

> **프로필 로드 코드 중복 회피**: `VanguardDuelOpponentSlot` 의 `LoadProfileIconAsync/LoadProfileFrameAsync` 와 동일 로직을 `VanguardClashCard` 에 복제한다(슬롯은 가로 카드라 레이아웃 재사용 불가). 추후 공통 헬퍼(`VanguardProfileLoader`)로 추출 가능하나 본 문서 범위 밖.

---

## 4. UI 프리팹 구조 (하이어라키)

> 신규 `VanguardMatchEndClashCutscene.prefab`(`Assets/_Project/3_Prefabs/UI/Vanguard/`). **`VanguardInGameUI` 프리팹의 자식**(전체 화면, `_roundResultBanner` 와 형제, 그 위 레이어). 루트 기본 비활성.

```
VanguardMatchEndClashCutscene (루트, ▶ VanguardMatchEndClashCutscene.cs, CanvasGroup, 기본 비활성)
├─ DimLeft  (좌하 삼각/평행사변형 영역, 블루 반투명)            → _dimLeft   (Image)
├─ DimRight (우상 삼각/평행사변형 영역, 마젠타 반투명)          → _dimRight  (Image)
├─ ClashLine (좌상→우하 황금 대각선, 점화 대상)                → _clashLine (Image, 기본 alpha 0)
├─ SparkBurst (중앙, 스파크 입자/플래시)                       → _sparkBurst (ParticleSystem 또는 Image)
├─ CardsRoot (쉐이크 대상 컨테이너)                            → _cardsRoot (RectTransform)
│  ├─ SelfCard      [VanguardClashCard] (좌·블루, skew)        → _selfCard
│  └─ OpponentCard  [VanguardClashCard] (우·마젠타, skew)      → _opponentCard
└─ (선택) FlashOverlay (충돌 순간 전체 화면 흰색 플래시)        → _flashOverlay (Image, alpha 0)
```

### 4-1. `VanguardClashCard` 프리팹 구조 (카드 1장)

```
VanguardClashCard (▶ VanguardClashCard.cs, RectTransform)
├─ Background (평행사변형 카드 배경, 진영 색 — skew 스프라이트 또는 약한 회전) → (정적)
├─ ProfileFrame (Image)                                        → _profileFrame
├─ ProfileIcon (Image, 프레임 안 원형 아바타)                  → _profileIcon
├─ NameText (TMP)                                              → _nameText
├─ TierBadge (Image) + DivisionText (TMP, "II")               → _tierBadge / _divisionText
├─ MarkIcon (◆ Image, 진영 색 틴트)                           → _markIcon
└─ ScoreText (TMP, "x1")                                       → _scoreText  (펄스 대상 = 이 Transform 또는 카드 루트)
```

- 좌 카드(자신): 블루 톤. 우 카드(상대): 마젠타 톤. **카드 내부 요소 배치는 좌우 미러**(자신 카드는 아바타가 우측=분할선 쪽, 상대 카드는 아바타가 좌측=분할선 쪽 — GIF 참조). 미러는 프리팹에서 좌우 앵커만 반전.
- `skew`: 전용 평행사변형 스프라이트가 가장 깔끔. 없으면 카드 루트에 약한 `localRotation`(z ±6°) 으로 근사(텍스트 가독성 위해 자식 텍스트는 역회전 보정).

---

## 5. 스크립트 설계

### 5-1. `VanguardMatchEndClashCutscene.cs` (연출 본체 — 참조 구현)

```csharp
using Cysharp.Threading.Tasks;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 3라운드(2선승제) 종료 시 1회 재생되는 대각선 분할 VS 클래시 연출. VanguardInGameUI 자식.
/// PlayAsync: dim 인 → 양 카드 슬라이드 인 → 중앙 충돌(황금선+스파크+쉐이크+SFX) → 승자 강조 → hold → 페이드아웃.
/// 호출 시점에 전투는 이미 Time.timeScale=0 (호출자가 멈춤) → 모든 트윈/대기는 timeScale 무관(SetUpdate(true)/Unscaled).
/// 좌=자신(블루) / 우=상대(마젠타). CLAUDE.md: DOTween 대기는 AsyncWaitForCompletion(ToUniTask 금지).
/// </summary>
public class VanguardMatchEndClashCutscene : MonoBehaviour
{
    #region Serialized
    [Header("그룹")]
    [SerializeField] private CanvasGroup _canvasGroup;
    [SerializeField] private RectTransform _cardsRoot;     // 쉐이크 대상

    [Header("진영 dim / 분할선 / 스파크")]
    [SerializeField] private Image _dimLeft;
    [SerializeField] private Image _dimRight;
    [SerializeField] private Image _clashLine;             // 기본 alpha 0 → 충돌 시 점화
    [SerializeField] private ParticleSystem _sparkBurst;   // 없으면 _flashOverlay 로 대체
    [SerializeField] private Image _flashOverlay;          // 선택: 충돌 순간 흰 플래시

    [Header("카드")]
    [SerializeField] private VanguardClashCard _selfCard;     // 좌(블루)
    [SerializeField] private VanguardClashCard _opponentCard; // 우(마젠타)

    [Header("연출 타이밍 (초)")]
    [SerializeField, Min(0f)] private float _dimInDuration = 0.15f;
    [SerializeField, Min(0f)] private float _slideInDuration = 0.25f;
    [SerializeField, Min(0f)] private float _slideOffsetX = 1200f;   // 카드 시작 X 오프셋(화면 밖)
    [SerializeField, Min(0f)] private float _shakeDuration = 0.2f;
    [SerializeField, Min(0f)] private float _shakeStrength = 40f;
    [SerializeField, Min(0f)] private float _winnerPulseScale = 1.12f;
    [SerializeField, Min(0f)] private float _holdSeconds = 1.5f;
    [SerializeField, Min(0f)] private float _fadeOutDuration = 0.3f;
    [SerializeField] private bool _fadeOutAtEnd = true;             // false면 마지막 프레임 hold(결과 팝업이 덮음)
    [SerializeField] private string _clashSfxKey = "VanguardClash"; // 없으면 빈 문자열

    [Header("패자 디밍 색")]
    [SerializeField] private Color _loserTint = new Color(0.55f, 0.55f, 0.6f, 1f);
    #endregion

    private Sequence _seq;
    private Vector2 _selfHome, _opponentHome;
    private bool _homeCached;

    private void Awake()
    {
        gameObject.SetActive(false);
        if (_canvasGroup != null) _canvasGroup.alpha = 0f;
    }

    /// <summary>
    /// 클래시 연출 재생. self/opponent=카드 데이터, selfScore/opponentScore=최종 누적 점수(◆ x{score}),
    /// selfWon=내가 매치 승자(2승). hold 후 종료까지 await — 호출자가 결과 팝업으로 진행.
    /// </summary>
    public async UniTask PlayAsync(VanguardDuelOpponent self, VanguardDuelOpponent opponent,
                                   int selfScore, int opponentScore, bool selfWon)
    {
        gameObject.SetActive(true);
        CacheHomePositions();

        // 카드 바인딩 (좌=자신 블루 / 우=상대 마젠타)
        _selfCard?.Bind(self, selfScore, isSelf: true);
        _opponentCard?.Bind(opponent, opponentScore, isSelf: false);

        // 초기 상태: dim 0, 분할선 0, 카드 화면 밖, 플래시 0
        if (_canvasGroup != null) _canvasGroup.alpha = 1f; // CanvasGroup은 켜고 내부 요소로 페이드 제어
        SetAlpha(_dimLeft, 0f); SetAlpha(_dimRight, 0f); SetAlpha(_clashLine, 0f); SetAlpha(_flashOverlay, 0f);
        if (_selfCard != null)     ((RectTransform)_selfCard.transform).anchoredPosition     = _selfHome + Vector2.left  * _slideOffsetX;
        if (_opponentCard != null) ((RectTransform)_opponentCard.transform).anchoredPosition = _opponentHome + Vector2.right * _slideOffsetX;
        ResetCardTint();

        _seq?.Kill();
        _seq = DOTween.Sequence().SetUpdate(true); // timeScale=0 중에도 동작

        // 1) dim 인
        if (_dimLeft != null)  _seq.Join(_dimLeft.DOFade(0.78f, _dimInDuration).SetUpdate(true));
        if (_dimRight != null) _seq.Join(_dimRight.DOFade(0.78f, _dimInDuration).SetUpdate(true));

        // 2) 양 카드 슬라이드 인 (동시)
        if (_selfCard != null)
            _seq.Join(((RectTransform)_selfCard.transform).DOAnchorPos(_selfHome, _slideInDuration).SetEase(Ease.OutCubic).SetUpdate(true));
        if (_opponentCard != null)
            _seq.Join(((RectTransform)_opponentCard.transform).DOAnchorPos(_opponentHome, _slideInDuration).SetEase(Ease.OutCubic).SetUpdate(true));

        // 3) 충돌 순간: 분할선 점화 + 스파크 + 플래시 + 쉐이크 + SFX
        _seq.AppendCallback(() =>
        {
            if (_clashLine != null) _clashLine.DOFade(1f, 0.08f).SetUpdate(true);
            if (_sparkBurst != null) { _sparkBurst.Clear(); _sparkBurst.Play(); }
            if (_flashOverlay != null) _flashOverlay.DOFade(0.6f, 0.05f).SetUpdate(true).OnComplete(() => _flashOverlay.DOFade(0f, 0.2f).SetUpdate(true));
            if (_cardsRoot != null) _cardsRoot.DOShakeAnchorPos(_shakeDuration, _shakeStrength, 18, 90, false, true).SetUpdate(true);
            if (!string.IsNullOrEmpty(_clashSfxKey)) AudioUtils.PlaySFXUnscaled(_clashSfxKey).Forget();
        });

        // 4) 승자 강조 + 패자 디밍
        _seq.AppendInterval(_shakeDuration);
        _seq.AppendCallback(() =>
        {
            var winner = selfWon ? _selfCard : _opponentCard;
            var loser  = selfWon ? _opponentCard : _selfCard;
            loser?.SetTint(_loserTint);
            if (winner != null)
            {
                var t = winner.transform;
                t.localScale = Vector3.one;
                DOTween.Sequence().SetUpdate(true)
                    .Append(t.DOScale(_winnerPulseScale, 0.15f).SetEase(Ease.OutBack).SetUpdate(true))
                    .Append(t.DOScale(1f, 0.12f).SetUpdate(true));
            }
        });

        // 5) hold
        _seq.AppendInterval(_holdSeconds);

        // 6) 페이드 아웃 (옵션)
        if (_fadeOutAtEnd && _canvasGroup != null)
            _seq.Append(_canvasGroup.DOFade(0f, _fadeOutDuration).SetUpdate(true));

        await _seq.AsyncWaitForCompletion(); // CLAUDE.md: ToUniTask 금지
        if (_fadeOutAtEnd) gameObject.SetActive(false);
    }

    private void CacheHomePositions()
    {
        if (_homeCached) return;
        _homeCached = true;
        if (_selfCard != null)     _selfHome     = ((RectTransform)_selfCard.transform).anchoredPosition;
        if (_opponentCard != null) _opponentHome = ((RectTransform)_opponentCard.transform).anchoredPosition;
    }

    private void ResetCardTint() { _selfCard?.SetTint(Color.white); _opponentCard?.SetTint(Color.white); }
    private static void SetAlpha(Image img, float a) { if (img != null) { var c = img.color; c.a = a; img.color = c; } }

    private void OnDisable() => _seq?.Kill();
}
```

### 5-2. `VanguardClashCard.cs` (카드 1장 — 신규)

```csharp
using System;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 클래시 연출 좌/우 카드 1장. 아바타(프로필+프레임)·닉네임·티어 뱃지+디비전 로마자·◆ 마크+누적 점수(x{score}).
/// 프로필/프레임 로드는 VanguardDuelOpponentSlot 과 동일 소스(ContentUnlockManager/ResourceManager).
/// </summary>
public class VanguardClashCard : MonoBehaviour
{
    [Header("프로필")]
    [SerializeField] private Image _profileIcon;
    [SerializeField] private Image _profileFrame;

    [Header("정보")]
    [SerializeField] private TextMeshProUGUI _nameText;
    [SerializeField] private Image _tierBadge;
    [SerializeField] private TextMeshProUGUI _divisionText; // "II" / "I"
    [SerializeField] private Image _markIcon;               // ◆ (진영 색 틴트는 프리팹에서)
    [SerializeField] private TextMeshProUGUI _scoreText;    // "x1" (누적 라운드 승수)

    [Header("틴트 대상 (패자 디밍)")]
    [SerializeField] private Graphic[] _tintTargets;        // 카드 배경/요소들 — 디밍에 함께 묶음

    /// <summary>카드 데이터 바인딩. score=누적 라운드 승수(◆ x{score}). isSelf=색/미러 분기는 프리팹에서 처리.</summary>
    public void Bind(VanguardDuelOpponent data, int score, bool isSelf)
    {
        if (data == null) return;

        if (_nameText != null)
        {
            _nameText.text = data.nickName;
            TextUtility.ApplyNicknameColor(_nameText, data.appliedPassType);
        }
        if (_tierBadge != null) _tierBadge.sprite = VanguardTierUtil.GetTierSprite(data.tier);
        if (_divisionText != null) _divisionText.text = VanguardTierMath.GetDivisionRoman(data.tier);
        if (_scoreText != null) _scoreText.text = $"x{Mathf.Max(0, score)}";

        LoadProfileIconAsync(data.profileIcon).Forget();
        LoadProfileFrameAsync(data.profileFrame).Forget();
    }

    /// <summary>패자 디밍/복원. 카드 배경·요소 색을 일괄 틴트.</summary>
    public void SetTint(Color c)
    {
        if (_tintTargets == null) return;
        foreach (var g in _tintTargets) if (g != null) g.color = c;
    }

    // ── VanguardDuelOpponentSlot 와 동일 로드 로직 (레이아웃이 달라 컴포넌트 자체는 재사용 불가) ──
    private async UniTaskVoid LoadProfileIconAsync(int iconIndex)
    {
        if (_profileIcon == null) return;
        var rm = Managers.Instance?.GetManager<ResourceManager>();
        var iconData = Managers.Instance?.GetManager<ContentUnlockManager>()?.GetProfileIconData();
        if (rm == null || iconData == null) return;
        try
        {
            var info = iconData.GetIconByIndex(iconIndex);
            if (info == null) return;
            if (info.iconSprite != null) _profileIcon.sprite = info.iconSprite;
            else if (!string.IsNullOrEmpty(info.iconPath))
            {
                var sp = await rm.LoadResourceAsync<Sprite>(info.iconPath);
                if (sp != null) _profileIcon.sprite = sp;
            }
        }
        catch (Exception ex) { RLog.LogError($"[VanguardClashCard] 프로필 아이콘 로드 오류: {ex.Message}"); }
    }

    private async UniTaskVoid LoadProfileFrameAsync(int frameIndex)
    {
        if (_profileFrame == null) return;
        var rm = Managers.Instance?.GetManager<ResourceManager>();
        var frameData = Managers.Instance?.GetManager<ContentUnlockManager>()?.GetProfileFrameData();
        if (rm == null || frameData == null) return;
        try
        {
            var info = frameData.GetFrameByIndex(frameIndex);
            if (info == null) return;
            if (info.frameSprite != null) _profileFrame.sprite = info.frameSprite;
            else if (!string.IsNullOrEmpty(info.framePath))
            {
                var sp = await rm.LoadResourceAsync<Sprite>(info.framePath);
                if (sp != null) _profileFrame.sprite = sp;
            }
        }
        catch (Exception ex) { RLog.LogError($"[VanguardClashCard] 프로필 프레임 로드 오류: {ex.Message}"); }
    }
}
```

### 5-3. `VanguardInGameUI` 연동 (호스트 — 추가분)

```csharp
// VanguardInGameUI.cs (추가)
[Header("3라운드 종료 클래시 연출")]
[SerializeField] private VanguardMatchEndClashCutscene _matchEndClash;

// 기존 스텁(:279)을 아래로 교체
/// <summary>3R 종료 후 매칭 종료 클래시 연출. 전투는 이미 timeScale=0 (OnRoundDecidedAsync). </summary>
private async UniTask PlayMatchEndSequenceAsync()
{
    if (_matchEndClash == null) return;
    bool selfWon = _selfScore > _opponentScore;
    await _matchEndClash.PlayAsync(_selfData, _opponentData, _selfScore, _opponentScore, selfWon);
}
```

- 추가 필드 1개 + 메서드 본문 3줄. **다른 흐름은 손대지 않는다**(점수/배너/결과 팝업은 기존 그대로). `Closed()` 추가 정리 불필요(연출은 자체 `OnDisable` 에서 `_seq.Kill()`, `Hide<VanguardInGameUI>()` 시 프리팹째 파괴).

### 5-4. Localization 키

- **없음**. 카드 텍스트는 닉네임(서버) · 디비전 로마자(`VanguardTierMath`) · 티어명(`VanguardTierUtil`, 이미 로컬라이즈) · `x{score}`(숫자) 뿐. 신규 로컬라이즈 키 불필요.
- SFX 키(`_clashSfxKey`)는 오디오 에셋 키(로컬라이즈 아님). 미지정 시 빈 문자열로 무음 처리.

---

## 6. Editor 빌더 (`VanguardMatchEndClashCutsceneBuilder.cs`)

> `VanguardRoundResultBannerBuilder` 패턴 그대로. 메뉴 `Vanguard/Build MatchEndClashCutscene` → 프리팹 생성 후 인스펙터에서 ◆/황금선/스파크/뱃지 스프라이트만 지정. 카드 내부 위젯은 빌더가 생성·와이어링한다.

```csharp
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// 3라운드 종료 클래시 연출(VanguardMatchEndClashCutscene) 프리팹을 코드로 구성한다.
/// 좌(자신·블루)/우(상대·마젠타) 평행사변형 카드 + 중앙 황금 분할선 + 진영 dim.
/// 메뉴: Vanguard/Build MatchEndClashCutscene.
/// ※ 생성 후 VanguardInGameUI 자식으로 넣고 _matchEndClash 에 연결. 스프라이트(◆/황금선/뱃지/스파크)는 인스펙터 지정.
/// </summary>
public static class VanguardMatchEndClashCutsceneBuilder
{
    const string PrefabPath = "Assets/_Project/3_Prefabs/UI/Vanguard/VanguardMatchEndClashCutscene.prefab";

    static readonly Color DimBlue    = new Color(0.20f, 0.50f, 0.90f, 0f); // 좌(자신) — 시작 alpha 0
    static readonly Color DimMagenta = new Color(0.85f, 0.20f, 0.55f, 0f); // 우(상대) — 시작 alpha 0
    static readonly Color Gold       = new Color(1f, 0.82f, 0.25f, 0f);    // 분할선 — 시작 alpha 0

    [MenuItem("Vanguard/Build MatchEndClashCutscene")]
    public static void Build()
    {
        var root = NewUI("VanguardMatchEndClashCutscene", null);
        Stretch((RectTransform)root.transform);
        var cg = root.AddComponent<CanvasGroup>();
        var cut = root.AddComponent<VanguardMatchEndClashCutscene>();

        // 진영 dim (좌/우) — 우선 전체 스트레치, 분할은 스프라이트/마스크로 후처리
        var dimL = NewUI("DimLeft", root.transform);  Stretch((RectTransform)dimL.transform); var dimLImg = AddImage(dimL, DimBlue);
        var dimR = NewUI("DimRight", root.transform); Stretch((RectTransform)dimR.transform); var dimRImg = AddImage(dimR, DimMagenta);

        // 황금 분할선 (좌상→우하). 스프라이트 미지정 — 인스펙터에서 대각선 스프라이트 + z회전 지정.
        var line = NewUI("ClashLine", root.transform);
        Anchor((RectTransform)line.transform, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(40, 2400));
        line.transform.localRotation = Quaternion.Euler(0, 0, 28f);
        var lineImg = AddImage(line, Gold);

        // 스파크 버스트 자리(ParticleSystem 은 인스펙터에서 추가/지정 — 빈 오브젝트만 생성)
        var spark = NewUI("SparkBurst", root.transform);
        Anchor((RectTransform)spark.transform, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(10, 10));

        // 카드 루트(쉐이크 대상)
        var cardsRoot = NewUI("CardsRoot", root.transform); Stretch((RectTransform)cardsRoot.transform);

        var self = BuildCard(cardsRoot.transform, "SelfCard", new Vector2(-300, 0), true);
        var opp  = BuildCard(cardsRoot.transform, "OpponentCard", new Vector2(300, 0), false);

        // 와이어링
        WireRef(cut, "_canvasGroup", cg);
        WireRef(cut, "_cardsRoot", cardsRoot.GetComponent<RectTransform>());
        WireRef(cut, "_dimLeft", dimLImg);
        WireRef(cut, "_dimRight", dimRImg);
        WireRef(cut, "_clashLine", lineImg);
        WireRef(cut, "_selfCard", self);
        WireRef(cut, "_opponentCard", opp);

        EnsureDir(PrefabPath);
        PrefabUtility.SaveAsPrefabAsset(root, PrefabPath);
        Object.DestroyImmediate(root);
        AssetDatabase.SaveAssets(); AssetDatabase.Refresh();
        Debug.Log("[Vanguard] MatchEndClashCutscene 프리팹 빌드 완료 → " + PrefabPath +
                  "\n※ VanguardInGameUI 자식 배치 + _matchEndClash 연결. ◆/황금선/뱃지/스파크 스프라이트는 인스펙터 지정.");
    }

    // 카드 1장: 평행사변형 배경 + 프로필(프레임+아이콘) + 이름 + 티어뱃지+디비전 + ◆ + 점수.
    static VanguardClashCard BuildCard(Transform parent, string name, Vector2 pos, bool isSelf)
    {
        var teamColor = isSelf ? new Color(0.20f, 0.50f, 0.90f, 0.92f) : new Color(0.85f, 0.20f, 0.55f, 0.92f);
        var go = NewUI(name, parent);
        Anchor((RectTransform)go.transform, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), pos, new Vector2(520, 200));
        var card = go.AddComponent<VanguardClashCard>();

        var bg = NewUI("Background", go.transform); Stretch((RectTransform)bg.transform);
        var bgImg = AddImage(bg, teamColor);

        var frame = NewUI("ProfileFrame", go.transform);
        Anchor((RectTransform)frame.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), new Vector2(isSelf ? 170 : -170, 0), new Vector2(150,150));
        var frameImg = AddImage(frame, Color.white);
        var icon = NewUI("ProfileIcon", frame.transform);
        Anchor((RectTransform)icon.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), Vector2.zero, new Vector2(120,120));
        var iconImg = AddImage(icon, Color.white);

        var nameGo = NewUI("NameText", go.transform);
        Anchor((RectTransform)nameGo.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), new Vector2(isSelf ? -40 : 40, 55), new Vector2(320,60));
        var nameTmp = AddTMP(nameGo, isSelf ? "TopTap_on_YT" : "Bobbabadoh", 38, isSelf ? TextAlignmentOptions.Left : TextAlignmentOptions.Right);

        var badge = NewUI("TierBadge", go.transform);
        Anchor((RectTransform)badge.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), new Vector2(isSelf ? -130 : 130, -20), new Vector2(90,90));
        var badgeImg = AddImage(badge, Color.white);
        var divGo = NewUI("DivisionText", badge.transform);
        Anchor((RectTransform)divGo.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), Vector2.zero, new Vector2(80,80));
        var divTmp = AddTMP(divGo, isSelf ? "II" : "I", 40, TextAlignmentOptions.Center);

        var mark = NewUI("MarkIcon", go.transform);
        Anchor((RectTransform)mark.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), new Vector2(isSelf ? -30 : 30, -25), new Vector2(64,64));
        var markImg = AddImage(mark, teamColor);
        var scoreGo = NewUI("ScoreText", go.transform);
        Anchor((RectTransform)scoreGo.transform, new Vector2(0.5f,0.5f), new Vector2(0.5f,0.5f), new Vector2(isSelf ? 30 : -30, -25), new Vector2(120,70));
        var scoreTmp = AddTMP(scoreGo, "x1", 48, TextAlignmentOptions.Left);

        WireRef(card, "_profileIcon", iconImg);
        WireRef(card, "_profileFrame", frameImg);
        WireRef(card, "_nameText", nameTmp);
        WireRef(card, "_tierBadge", badgeImg);
        WireRef(card, "_divisionText", divTmp);
        WireRef(card, "_markIcon", markImg);
        WireRef(card, "_scoreText", scoreTmp);
        WireRefArray(card, "_tintTargets", new Graphic[] { bgImg, nameTmp, scoreTmp, divTmp });
        return card;
    }

    // ---------------- helpers (RoundResultBannerBuilder 와 동일) ----------------
    static GameObject NewUI(string name, Transform parent)
    {
        var go = new GameObject(name, typeof(RectTransform));
        if (parent != null) go.transform.SetParent(parent, false);
        return go;
    }
    static Image AddImage(GameObject go, Color c) { var i = go.GetComponent<Image>() ?? go.AddComponent<Image>(); i.color = c; return i; }
    static TextMeshProUGUI AddTMP(GameObject go, string t, float size, TextAlignmentOptions a)
    { var x = go.AddComponent<TextMeshProUGUI>(); x.text = t; x.fontSize = size; x.alignment = a; x.color = Color.white; return x; }
    static void Stretch(RectTransform rt) { rt.anchorMin = Vector2.zero; rt.anchorMax = Vector2.one; rt.pivot = new Vector2(0.5f,0.5f); rt.offsetMin = Vector2.zero; rt.offsetMax = Vector2.zero; }
    static void Anchor(RectTransform rt, Vector2 min, Vector2 max, Vector2 pos, Vector2 size)
    { rt.anchorMin = min; rt.anchorMax = max; rt.pivot = new Vector2(0.5f,0.5f); rt.anchoredPosition = pos; rt.sizeDelta = size; }
    static void WireRef(Component comp, string field, Object value)
    {
        var so = new SerializedObject(comp); var p = so.FindProperty(field);
        if (p != null) { p.objectReferenceValue = value; so.ApplyModifiedPropertiesWithoutUndo(); }
        else Debug.LogWarning($"[Vanguard] 필드 '{field}' 를 {comp.GetType().Name} 에서 찾지 못함");
    }
    static void WireRefArray(Component comp, string field, Object[] values)
    {
        var so = new SerializedObject(comp); var p = so.FindProperty(field);
        if (p == null) { Debug.LogWarning($"[Vanguard] 배열 필드 '{field}' 미발견"); return; }
        p.arraySize = values.Length;
        for (int i = 0; i < values.Length; i++) p.GetArrayElementAtIndex(i).objectReferenceValue = values[i];
        so.ApplyModifiedPropertiesWithoutUndo();
    }
    static void EnsureDir(string assetPath)
    {
        var dir = System.IO.Path.GetDirectoryName(assetPath).Replace('\\','/');
        if (!AssetDatabase.IsValidFolder(dir))
        {
            var parts = dir.Split('/'); var cur = parts[0];
            for (int i = 1; i < parts.Length; i++)
            { var next = cur + "/" + parts[i]; if (!AssetDatabase.IsValidFolder(next)) AssetDatabase.CreateFolder(cur, parts[i]); cur = next; }
        }
    }
}
#endif
```

> 빌더는 **레이아웃 골격 + 와이어링**만 만든다. 정확한 대각선 분할(마스크/스프라이트), ◆/황금선/뱃지/스파크 아트, skew 카드 배경은 **인스펙터에서 스프라이트 지정 + 미세 조정**으로 마무리(`VanguardRoundResultBanner` 도 동일하게 ◆ 스프라이트는 인스펙터 지정).

---

## 7. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| self/opponent 카드 데이터 | ✅ 이미 보유 | `VanguardInGameUI._selfData`/`_opponentData`(`VanguardDuelOpponent`). 추가 서버 연동 불필요 |
| 누적 점수(◆ x{score}) | ✅ 이미 보유 | `_selfScore`/`_opponentScore`. 2선승제 → 3R 종료 시 2:1 또는 1:2 |
| 티어 뱃지/디비전(`II`/`I`) | ✅ 유틸 존재 | `VanguardTierUtil.GetTierSprite` / `VanguardTierMath.GetDivisionRoman` |
| 프로필 아이콘/프레임 | ✅ 소스 존재 | `ContentUnlockManager` + `ResourceManager`(DuelOpponentSlot 동일 로직 복제) |
| 진입 시점 | ✅ 코드 존재 | `PlayMatchEndSequenceAsync()`(:279) 본문만 채움 |
| 전투 정지 | ✅ 호출자가 처리 | `OnRoundDecidedAsync` 가 `Time.timeScale=0` → 연출은 `SetUpdate(true)`/Unscaled |
| 황금선/스파크/skew/SFX 아트 | ⚠️ 아트 필요 | 분할 스프라이트·파티클·◆·뱃지·SFX 키 — 인스펙터 지정(미지정 시 무난한 폴백) |

### CLAUDE.md 준수
- `Managers.Instance.GetManager<T>()` 만 사용 / `EventManager` 는 static(본 연출은 직접 구독 안 함, 호스트가 처리) / DOTween 대기 `AsyncWaitForCompletion`(**ToUniTask 금지**) + `SetUpdate(true)`(정지 중 동작) / 대기 `DelayType.UnscaledDeltaTime` / `async void` 금지(`UniTask`/`UniTaskVoid`) / 텍스트는 로컬라이즈된 유틸 사용(신규 하드코딩 없음) / 매직넘버는 `[SerializeField]`/`const` / `OnDisable` 에서 시퀀스 Kill / `DateTime.Now`·`UnityEngine.Random` 미사용.

---

## 8. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardClashCard.cs` 작성(5-2) — `UI/Vanguard/Component/`.
2. [ ] `VanguardMatchEndClashCutscene.cs` 작성(5-1) — `UI/Vanguard/Component/`.
3. [ ] `VanguardInGameUI` 에 `_matchEndClash` 필드 추가 + `PlayMatchEndSequenceAsync` 본문 교체(5-3). 빌드-그린.

**B. 프리팹 (Editor 빌더)**

4. [ ] `VanguardMatchEndClashCutsceneBuilder.cs` 작성(6) — `Editor/Vanguard/`.
5. [ ] 메뉴 `Vanguard/Build MatchEndClashCutscene` 실행 → `VanguardMatchEndClashCutscene.prefab` 생성.
6. [ ] 인스펙터에서 스프라이트 지정: ◆ 마크, 황금 분할선, 티어 뱃지(유틸 자동), 프로필 프레임 기본, (선택) 스파크 ParticleSystem 추가 후 `_sparkBurst` 연결, (선택) FlashOverlay.
7. [ ] 대각선 분할(DimLeft/DimRight) 을 마스크/스프라이트로 좌하/우상 영역 분리(또는 단순 좌/우 반반). skew 카드 배경 적용.

**C. 연동**

8. [ ] `VanguardInGameUI` 프리팹의 자식으로 `VanguardMatchEndClashCutscene` 배치(`_roundResultBanner` 와 형제, 그 위 레이어) → `_matchEndClash` 필드 연결. 기본 비활성.
9. [ ] (옵션 B 채택 시) 3R 종료에서 `_roundResultBanner` 를 건너뛰도록 `OnRoundDecidedAsync` 분기(§아래).
10. [ ] (선택) `_clashSfxKey` 에 실제 SFX 에셋 키 지정.

> **옵션 B(권장 검토)**: 3R 종료 시 ②배너 + ③클래시가 연달아 뜨는 중복을 줄이려면, `OnRoundDecidedAsync` 에서 `round >= VANGUARD_ROUND_COUNT` 일 때 `ShowRoundResultAsync` 호출을 건너뛰고 곧장 클래시로 가도록 분기:
> ```csharp
> if (round < VANGUARD_ROUND_COUNT && _roundResultBanner != null)
>     await _roundResultBanner.ShowRoundResultAsync(round, selfWon, _selfScore, _opponentScore);
> SetRoundScore(_selfScore, _opponentScore);
> if (round >= VANGUARD_ROUND_COUNT) { await PlayMatchEndSequenceAsync(); ShowResultPopup(); ... }
> ```
> 옵션 A(현행 유지)는 라운드 배너 후 클래시 — 코드 무수정. 기획 톤에 맞춰 택1.

---

## 9. 검증 체크리스트

- [ ] 라운드 3 종료 시(2선승제 확정) 클래시 연출 1회 재생 → 결과 팝업 진입.
- [ ] **전투 정지 중(`Time.timeScale=0`) 정상 재생** — 슬라이드/쉐이크/펄스/페이드 모두 동작(`SetUpdate(true)`/Unscaled).
- [ ] 좌=자신(블루) / 우=상대(마젠타), 카드에 아바타·닉네임(패스 컬러)·티어 뱃지·디비전(`II`/`I`)·◆ `x{score}` 정확.
- [ ] 누적 점수 = `_selfScore`/`_opponentScore` 와 일치(2:1 또는 1:2).
- [ ] 충돌 순간: 황금선 점화 + 스파크/플래시 + 쉐이크 + SFX 동시.
- [ ] 승자 카드 펄스/밝기↑, 패자 카드 디밍. 승/패 판정(`selfWon=_selfScore>_opponentScore`) 정확.
- [ ] 페이드아웃 후 비활성(또는 `_fadeOutAtEnd=false` 시 hold 유지 → 결과 팝업이 덮음).
- [ ] `OnDisable`/재대전 시 시퀀스 Kill(중복 트윈·누수 없음).
- [ ] `VanguardInGameUI` 다른 흐름(점수/배너/결과/헤더) 회귀 없음.
- [ ] CLAUDE.md 준수(AsyncWaitForCompletion/SetUpdate/Unscaled/GetManager/UniTask/매직넘버 직렬화).

---

## 10. 미해결 / 확인 필요

**확정됨 (코드 기준)**

- [x] **진입 지점**: `VanguardInGameUI.PlayMatchEndSequenceAsync()`(:279) — 이미 호출 흐름 존재, 본문만 채움.
- [x] **전투 정지**: 호출 전 `OnRoundDecidedAsync` 가 `Time.timeScale=0`. → `SetUpdate(true)`/Unscaled 필수.
- [x] **데이터**: `_selfData`/`_opponentData`/`_selfScore`/`_opponentScore` 이미 보유. 추가 서버 연동 불필요.
- [x] **2선승제 / 무승부 없음**: 3R 고정, 종료 시 한쪽 2승.

**확인 필요 (GIF/실게임/기획)**

- [ ] **◆ `x1` 의미**: GIF가 `x1`/`x1`(=1:1) 로 보이는데 2선승제 최종은 2:1/1:2 여야 함 → `x{score}`(누적 라운드 승수)로 매핑했으나, GIF의 게임은 (a) 라운드마다 뜨는 연출(중간 점수)일 수도, (b) ◆가 점수 아닌 보상 마크일 수도 있음. **실게임에서 ◆ 숫자의 정확한 의미 확인**(점수 vs 보상). 본 문서는 누적 점수로 가정.
- [ ] **연출 노출 빈도**: 매 라운드 종료마다(중간 클래시) vs 3R 종료 1회만 — 본 문서는 "3라운드 종료" 요구에 맞춰 **3R 1회**로 설계. 매 라운드로 바꾸려면 `PlayAsync` 를 `OnRoundDecidedAsync` 본문에서 호출하고 `round`/`selfWon` 도 전달(컴포넌트는 그대로 재사용 가능).
- [ ] **②배너와의 관계**: 옵션 A(배너→클래시 연달아) vs 옵션 B(3R은 클래시만) — §8 택1, 기획 확정.
- [ ] **대각선 분할 구현**: 진영 dim 을 진짜 대각선(좌하/우상)으로 자를지(마스크/스프라이트) vs 좌/우 반반 단순화 — 아트 리소스에 따라 결정.
- [ ] **카드 skew**: 전용 평행사변형 스프라이트 vs z회전 근사 — 아트 확정.
- [ ] **스킵 허용**: 탭 스킵 여부/스킵 시 즉시 결과 팝업 — 기획 확정(`PlayAsync` 중간 취소 토큰 추가 가능).
- [ ] **SFX 키**: `_clashSfxKey` 실제 오디오 에셋 키 확정(`AudioUtils.PlaySFXUnscaled`).

---

> 작성: 2026-06-09 · 선행 코드 확인: **`VanguardInGameUI` 전체 실코드**(`PlayMatchEndSequenceAsync`:279 스텁 / `OnRoundDecidedAsync`:242 / `_selfData`·`_opponentData`:91-92 / `_selfScore`·`_opponentScore`:84-85 / `Time.timeScale=0`:251 / `ShowResultPopup`:286), `VanguardRoundResultBanner`(배너 + `SetUpdate(true)` 패턴), `VanguardMatchIntroPanel`(`PlayAsync` await 캡슐화 + `DOScale().SetUpdate(true).AsyncWaitForCompletion()`), `VanguardDuelOpponentSlot`(프로필/프레임 로드 + `BindIntro`), `VanguardDuelOpponent`(데이터 모델), `VanguardTierUtil.GetTierSprite/GetDisplayName`, `VanguardTierMath.GetDivisionRoman`(`II`/`I`), `VanguardRoundResultBannerBuilder`(Editor 빌더 패턴 — NewUI/AddImage/AddTMP/Anchor/WireRef/SaveAsPrefabAsset). 첨부 GIF(대각선 분할 VS 클래시 / 좌 블루·우 마젠타 / ◆ x1 / 뱃지 II·I / 스파크) 1:1 매핑. 본 문서 단독으로 프리팹+스크립트+Editor 빌더 제작 가능하도록 구성.
