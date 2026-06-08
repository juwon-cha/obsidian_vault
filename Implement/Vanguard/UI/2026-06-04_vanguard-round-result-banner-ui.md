# Vanguard 라운드 결과 배너(VanguardRoundResultBanner) 구현 종합 문서 (2026-06-04)

## 문서 목적

`VanguardInGameUI` 내부에 넣을, **라운드(총 3) 승패가 결정될 때마다 점수를 표시하는 배너 UI**(첨부 이미지: 상단 상대 `Hankong_K ◆1` / 하단 자신 `TopTap_on_YT ◆0`)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- **접근 방식(질문 답변)**: "프리팹을 `VanguardInGameUI`에 넣고 승패 결정 시 활성/비활성" — **좋은 접근**입니다. 단순 토글보다 **show→연출→hold→hide**를 캡슐화한 배너 컴포넌트로 만들면 점수 증가 강조·승/패 색 강조까지 깔끔하게 처리되고, 라운드 흐름(다음 라운드/최종 결과)으로의 콜백도 명확해집니다. (아래 §0 결론 참조)
- **네이밍**: **`VanguardRoundResultBanner`**.
- 짝 문서: [[2026-06-03_vanguard-ingame-battle-ui]](인게임 HUD 설계 — `VanguardInGameUI`), [[2026-06-04_vanguard-game-result-ui]](3라운드 종료 후 최종 결과)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 신규 `VanguardRoundResultBanner : MonoBehaviour` (UIBase 아님 — `VanguardInGameUI` 자식 컴포넌트) |
| 프리팹 | 신규 `VanguardRoundResultBanner.prefab` → **`VanguardInGameUI` 프리팹의 자식**으로 배치(기본 비활성) |
| 노출 | `VanguardInGameUI`가 라운드 결정 시 `ShowRoundResultAsync(...)` 호출 → 활성→연출→hold→비활성 |
| 표시 | 상대(상단·마젠타) / 자신(하단·블루) 헤더 + ◆ 누적 점수. 이긴 쪽 점수 펄스 강조 |
| 라운드 | **총 3라운드 고정**(0:0 → … → 최종). 라운드별 1회 배너. **무승부 없음**(매 라운드 1승자) |
| 표시 요소 | **◆ 아이콘 + 점수만**(Round 라벨/WIN·LOSE 텍스트 없음) |
| 전투 정지 | **배너 중 전투 일시정지**(승패 결정 = 연출 집중). `Time.timeScale=0` + `_touchBlocker` ON |
| 재활용 | `VanguardRankingDisplaySlot`(헤더 — 이미 `VanguardInGameUI`가 사용) · DOTween |
| 흐름 | 라운드 결정 → 전투 정지 → 배너 → 복귀(다음 라운드) / **3R 후 → 매칭 종료 연출 → `VanguardGameResultUI`** |
| 데이터 | `VanguardStagePlayService`가 라운드 승패+누적점수 주입(미연동 → `_testMode`) |

> **단순 토글 vs 배너 컴포넌트**: 토글(SetActive)만으로도 되지만, ① 점수 증가 연출 ② 승/패 색 강조 ③ hold 후 자동 닫힘 + 완료 콜백을 한 곳에 캡슐화하려면 `ShowRoundResultAsync`로 감싸는 편이 유지보수·연동에 유리. 본 문서는 이 방식으로 설계.
> **확정(기획)**: 전투 정지=연출 집중 / 표기=아이콘+점수만 / 무승부 없음 / 3R 후 매칭 종료 연출 → 매칭 결과 팝업.

---

## 1. 노출 / 흐름

```
전투 진행 → 라운드 N 승패 결정 (VanguardStagePlayService)  // 무승부 없음, 매 라운드 1승자
  └─ VanguardInGameUI.OnRoundDecidedAsync(round, selfWon)
       ├─ 전투 일시정지(Time.timeScale=0) + _touchBlocker ON   // 연출 집중 (확정)
       ├─ 누적 점수 갱신 (selfWon ? self++ : opponent++)
       ├─ _roundResultBanner.ShowRoundResultAsync(round, selfWon, selfScore, opponentScore)
       │     활성 → 점수 +1 펄스(아이콘+점수만) → hold(~1.5s) → 비활성
       ├─ VanguardInGameUI.SetRoundScore(selfScore, opponentScore)  // 상시 밴드 동기화(기존 메서드)
       ├─ 전투 재개(timeScale 복원) + _touchBlocker OFF
       └─ round < 3 → 다음 라운드 진행
          round == 3 → 매칭 종료 연출 → Show<VanguardGameResultUI>(결과)
```

- `VanguardInGameUI`는 이미 `SetRoundScore(self, opponent)`(상시 가운데 밴드 텍스트)와 `_selfHeader`/`_opponentHeader`(`VanguardRankingDisplaySlot`) 보유. 배너는 **결정 순간의 강조 오버레이**.
- 3라운드 고정. 라운드 종료마다 1회(무승부 없음). **마지막(3R) 후엔 매칭 종료 연출 → 매칭 결과 팝업**(바로 결과 UI 아님, §6).
- **전투 일시정지**: 승패 결정 연출에 집중하기 위해 배너 동안 `Time.timeScale=0`. → 배너 연출은 DOTween `SetUpdate(true)`로 timeScale 무관 동작(필수).

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 상대 헤더(상단) | 아바타 + `Hankong_K` (마젠타 톤) | `_opponentHeader`(`VanguardRankingDisplaySlot`) |
| B | 상대 점수 | `◆ 1` (마젠타) | `_opponentScoreText` + ◆ 아이콘 |
| C | 자신 헤더(하단) | 아바타 + `TopTap_on_YT` (블루 톤) | `_selfHeader` |
| D | 자신 점수 | `◆ 0` (블루) | `_selfScoreText` |
| E | 구분 띠 | 마젠타/블루 2분할 가로 띠 | 배경 이미지(상=마젠타, 하=블루) |
| (배경) | 흐릿한 일시정지/x2/카드 | 전투 HUD가 뒤에 비침 | 배너는 반투명 오버레이(전투 위) |

- ◆ = Vanguard Mark(승점/라운드 점수) 아이콘. 색: **상대=마젠타, 자신=블루**(팀 색 고정).
- 배너는 가운데 밴드 영역에 겹쳐 표시(전투 HUD 위). 전체 화면 딤은 아님(전투가 비침).

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **VanguardInGameUI** | `UI/Vanguard/UI/VanguardInGameUI.cs` | 부모(배너 보유·구동) | `SetRoundScore(int,int)` · `_selfHeader`/`_opponentHeader` · `_touchBlocker` |
| **VanguardRankingDisplaySlot** | `UI/Vanguard/Component/VanguardRankingDisplaySlot.cs` | 헤더(아바타/이름) | `Init(VanguardRankingItem)`/`Init(VanguardMyRankingItem)` · `LoadProfileIconAsync` |
| **VanguardTierUtil**(선택) | `UI/Vanguard/VanguardTierUtil.cs` | 티어 뱃지(필요 시) | `GetTierSprite/GetDisplayName` |
| DOTween | - | 점수 펄스/페이드 | `DOScale`/`DOFade`/Sequence + `SetUpdate(true)` |

> 헤더 아바타/이름은 부모(`VanguardInGameUI`)가 이미 셋업하므로, 배너는 **점수만** 자체 표시하고 헤더는 부모 참조를 받거나 동일 데이터(self/opponent 요약)를 주입받아 표시. 중복 로드 피하려면 부모가 self/opponent 프로필을 배너에 한 번 Bind.

### 신규 작성 (1개)

- `VanguardRoundResultBanner.cs` — 점수 표시 + 연출 + show/hide.
- (부모 측) `VanguardInGameUI`에 `OnRoundDecided` 훅 + `_roundResultBanner` 필드 추가(연동).

---

## 4. UI 프리팹 구조 (하이어라키)

> 신규 `VanguardRoundResultBanner.prefab`. **`VanguardInGameUI` 프리팹의 자식**(가운데 밴드 위 오버레이)로 배치. 루트 기본 비활성(SetActive(false)).

```
VanguardRoundResultBanner (루트, ▶ VanguardRoundResultBanner.cs, CanvasGroup, 기본 비활성)
├─ DimStrip (가운데 밴드 영역 한정 반투명, 전체화면 아님)
├─ OpponentRow (상단, 마젠타)
│  ├─ OpponentHeader [VanguardRankingDisplaySlot 또는 아바타+이름] → _opponentHeader
│  ├─ MarkIcon (◆ 마젠타)
│  └─ OpponentScoreText ("1")                          → _opponentScoreText
└─ SelfRow (하단, 블루)
   ├─ SelfHeader                                        → _selfHeader
   ├─ MarkIcon (◆ 블루)
   └─ SelfScoreText ("0")                               → _selfScoreText
```

- **표기 = ◆ 아이콘 + 점수만**(확정). Round 라벨/WIN·LOSE 텍스트 없음.
- 색/레이아웃: 상단 row 마젠타, 하단 row 블루(스샷). 가운데 분할 띠.
- 부모 가운데 밴드(`_selfRoundText`/`_opponentRoundText`)와 동일 위치에 겹치도록 RectTransform 배치(배너 활성 시 강조).
- 헤더를 `VanguardRankingDisplaySlot`로 둘지, 단순 아바타+이름으로 둘지는 부모 헤더와 일관되게(부모가 이미 슬롯 사용 → 동일 프리팹 권장).

---

## 5. 스크립트 설계

### 5-1. `VanguardRoundResultBanner.cs` (참조 구현)

```csharp
using System;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 라운드 승패 결정 시 점수를 강조 표시하는 배너. VanguardInGameUI 자식.
/// ShowRoundResultAsync: 활성 → 점수 갱신/펄스 → hold → 비활성. (총 3라운드)
/// </summary>
public class VanguardRoundResultBanner : MonoBehaviour
{
    #region Serialized
    [SerializeField] private CanvasGroup _canvasGroup;
    [SerializeField] private TextMeshProUGUI _selfScoreText;
    [SerializeField] private TextMeshProUGUI _opponentScoreText;
    [SerializeField] private Transform _selfScorePulseTarget;     // 점수 펄스 대상(자신)
    [SerializeField] private Transform _opponentScorePulseTarget; // 점수 펄스 대상(상대)
    [SerializeField] private VanguardRankingDisplaySlot _selfHeader;     // 선택(부모가 Bind)
    [SerializeField] private VanguardRankingDisplaySlot _opponentHeader; // 선택

    [Header("연출 설정")]
    [SerializeField] private float _fadeDuration = 0.25f;
    [SerializeField] private float _holdDuration = 1.5f;
    [SerializeField] private float _pulseScale = 1.3f;
    #endregion

    private Sequence _seq;

    private void Awake()
    {
        gameObject.SetActive(false);
        if (_canvasGroup != null) _canvasGroup.alpha = 0f;
    }

    /// <summary>
    /// 라운드 결과 표시. selfWon=이번 라운드 승자(자신 여부). selfScore/opponentScore=갱신된 누적 점수.
    /// 완료(hold 후 닫힘)까지 await 가능 — 호출자가 다음 라운드/결과로 진행.
    /// </summary>
    public async UniTask ShowRoundResultAsync(int round, bool selfWon, int selfScore, int opponentScore)
    {
        gameObject.SetActive(true);
        // 표기는 ◆ 아이콘 + 점수만 (Round 라벨/WIN·LOSE 없음 — 확정)

        // 갱신 전(직전) 점수로 먼저 표시 → 펄스와 함께 증가 강조
        int prevSelf = selfWon ? selfScore - 1 : selfScore;
        int prevOpp  = selfWon ? opponentScore : opponentScore - 1;
        if (_selfScoreText != null) _selfScoreText.text = Mathf.Max(0, prevSelf).ToString();
        if (_opponentScoreText != null) _opponentScoreText.text = Mathf.Max(0, prevOpp).ToString();

        _seq?.Kill();
        _seq = DOTween.Sequence().SetUpdate(true); // timeScale=0 중에도 동작

        // 1) 페이드 인
        if (_canvasGroup != null) { _canvasGroup.alpha = 0f; _seq.Append(_canvasGroup.DOFade(1f, _fadeDuration)); }

        // 2) 이긴 쪽 점수 +1 반영 + 펄스
        _seq.AppendCallback(() =>
        {
            if (selfWon && _selfScoreText != null) _selfScoreText.text = selfScore.ToString();
            else if (!selfWon && _opponentScoreText != null) _opponentScoreText.text = opponentScore.ToString();
        });
        var pulse = selfWon ? _selfScorePulseTarget : _opponentScorePulseTarget;
        if (pulse != null)
        {
            _seq.Append(pulse.DOScale(_pulseScale, 0.15f).SetEase(Ease.OutBack).SetUpdate(true));
            _seq.Append(pulse.DOScale(1f, 0.12f).SetUpdate(true));
        }

        // 3) hold
        _seq.AppendInterval(_holdDuration);

        // 4) 페이드 아웃
        if (_canvasGroup != null) _seq.Append(_canvasGroup.DOFade(0f, _fadeDuration));

        await _seq.AsyncWaitForCompletion(); // CLAUDE.md: ToUniTask 금지
        gameObject.SetActive(false);
    }

    /// <summary>헤더(아바타/이름)를 부모가 1회 Bind (중복 로드 방지).</summary>
    public void BindHeaders(VanguardRankingItem self, VanguardRankingItem opponent)
    {
        _selfHeader?.Init(self);
        _opponentHeader?.Init(opponent);
    }

    private void OnDisable() { _seq?.Kill(); }
}
```

### 5-2. `VanguardInGameUI` 연동 (부모 — 추가분)

```csharp
// VanguardInGameUI.cs (추가)
[Header("라운드 결과 배너")]
[SerializeField] private VanguardRoundResultBanner _roundResultBanner;

private int _selfScore, _opponentScore;
private const int VANGUARD_ROUND_COUNT = 3; // 3라운드 고정

/// <summary>라운드 승패 결정 시 서비스가 호출(실연동) / _testMode 데모. 무승부 없음(매 라운드 1승자). </summary>
public async UniTaskVoid OnRoundDecidedAsync(int round, bool selfWon)
{
    if (selfWon) _selfScore++; else _opponentScore++;

    // 전투 일시정지(연출 집중 — 확정). 배너는 SetUpdate(true)로 timeScale 무관 동작.
    float prevTimeScale = Time.timeScale;
    Time.timeScale = 0f;
    if (_touchBlocker != null) _touchBlocker.SetActive(true);

    if (_roundResultBanner != null)
        await _roundResultBanner.ShowRoundResultAsync(round, selfWon, _selfScore, _opponentScore);

    SetRoundScore(_selfScore, _opponentScore); // 상시 밴드 동기화(기존)

    if (round >= VANGUARD_ROUND_COUNT)
    {
        // 3R 종료 → 매칭 종료 연출 → 매칭 결과 팝업 (timeScale 0 유지: 결과는 정지 상태로 진입)
        if (_touchBlocker != null) _touchBlocker.SetActive(false);
        await PlayMatchEndSequenceAsync();   // 매칭 종료 연출 (별도)
        // 서비스가 VanguardGameResultData 구성 → Show<VanguardGameResultUI>(data) ([[2026-06-04_vanguard-game-result-ui]])
        // (VanguardGameResultUI가 자체적으로 Time.timeScale=0 유지/복원 — Ark 패턴)
        return;
    }

    // 다음 라운드 진행 → 전투 재개
    Time.timeScale = prevTimeScale;
    if (_touchBlocker != null) _touchBlocker.SetActive(false);
}

/// <summary>3R 종료 후 매칭 종료 연출(별도). 완료 후 결과 팝업으로. </summary>
private async UniTask PlayMatchEndSequenceAsync()
{
    // TODO: 매칭 종료 연출(승/패 전체 화면 연출 등). DOTween + SetUpdate(true). 미구현 시 짧은 대기.
    await UniTask.CompletedTask;
}
```

> 헤더 색(마젠타/블루)·아바타는 `OpenedAsync`에서 이미 셋업되므로, 배너는 점수만 갱신하면 됨. 배너 헤더를 따로 둘 경우 `BindHeaders`를 OpenedAsync에서 1회 호출.

### 5-3. Localization 키

- **없음**. 배너는 ◆ 아이콘 + 점수 숫자만 표기 → 로컬라이즈 텍스트 불필요.

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 라운드 승패/누적 점수 | ⚠️ 미연동 | `VanguardStagePlayService`가 라운드 종료 판정 → `VanguardInGameUI.OnRoundDecidedAsync(round, selfWon)`. `_testMode`는 타이머/더미로 데모 |
| 헤더(이름/아바타/색) | 부모 보유 | `VanguardInGameUI._selfHeader/_opponentHeader` 셋업 재사용. 색: 자신=블루/상대=마젠타 고정 |
| 라운드 수 | 확정 | **3 고정** · **무승부 없음**(매 라운드 1승자) |
| 일시정지 | 확정 | 배너 중 **전투 정지**(`Time.timeScale=0`, 연출 집중). 배너 연출은 `SetUpdate(true)` |
| 3R 후 흐름 | 확정 | **매칭 종료 연출(`PlayMatchEndSequenceAsync`) → 매칭 결과 팝업(`VanguardGameResultUI`)** ([[2026-06-04_vanguard-game-result-ui]]) |

### CLAUDE.md 준수
- DOTween 대기 `AsyncWaitForCompletion`(ToUniTask 금지) + `SetUpdate(true)`(일시정지 중 동작) / `async void`는 `UniTaskVoid` / `GetManager<T>()` / 텍스트 로컬라이즈 / `OnDisable`에서 시퀀스 Kill.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardRoundResultBanner.cs` 작성(5-1).
2. [ ] `VanguardInGameUI`에 `_roundResultBanner` 필드 + `OnRoundDecidedAsync` + 누적 점수 필드 추가(5-2).

**B. 프리팹**

3. [ ] `VanguardRoundResultBanner.prefab` 제작: CanvasGroup + OpponentRow(마젠타·헤더·◆·점수) + SelfRow(블루·헤더·◆·점수). **◆ 아이콘 + 점수만**(라벨 없음).
4. [ ] **`VanguardInGameUI` 프리팹의 가운데 밴드 위에 자식으로 배치** → `_roundResultBanner` 연결. 기본 비활성.
5. [ ] 점수 텍스트/펄스 타깃/헤더 필드 연결.

**C. 연동**

6. [ ] `_testMode`: 일정 시간마다 `OnRoundDecidedAsync(round, selfWon)` 호출해 0:0→1:0→… 데모(전투 정지/재개 포함).
7. [ ] 실연동: `VanguardStagePlayService` 라운드 판정 → `OnRoundDecidedAsync` 호출. 3R 후 `PlayMatchEndSequenceAsync` → 결과 팝업 연결.

---

## 8. 검증 체크리스트

- [ ] 라운드 결정 시 배너 활성 → 페이드 인 → 이긴 쪽 점수 +1 펄스 → hold → 페이드 아웃 → 비활성.
- [ ] **◆ 아이콘 + 점수만** 표기(Round 라벨/WIN·LOSE 없음).
- [ ] 점수 누적 정확(0:0 → 라운드별 증가, 무승부 없음), 상시 밴드(`SetRoundScore`)와 일치.
- [ ] 색: 자신=블루(하단)/상대=마젠타(상단), 헤더 아바타/이름 표시.
- [ ] **배너 중 `Time.timeScale=0`(전투 정지)** + `_touchBlocker` ON, 1·2R 후 복원·재개.
- [ ] 3라운드 동안 매 라운드 1회, **3R 후 매칭 종료 연출 → 매칭 결과 팝업** 진입(정지 유지).
- [ ] `OnDisable`/재진입 시 시퀀스 Kill(중복 트윈·누수 없음). `SetUpdate(true)`로 정지 중에도 연출.
- [ ] CLAUDE.md 준수(AsyncWaitForCompletion/UniTaskVoid).

---

## 9. 미해결 / 확인 필요

**확정됨 (기획)**

- [x] **배너 중 전투 일시정지**: 승패 결정 = 연출 집중 → `Time.timeScale=0`.
- [x] **표기 = 아이콘 + 점수만** (Round 라벨/WIN·LOSE 없음).
- [x] **무승부 없음**: 매 라운드 1승자(3R 각 1승자).
- [x] **3R 후 흐름**: 매칭 종료 연출 → 매칭 결과 팝업(`VanguardGameResultUI`).

**확인 필요**

- [ ] **헤더 중복 여부**: 배너가 자체 헤더를 둘지, 부모 가운데 밴드를 강조만 할지 — 부모 밴드 재사용이면 배너는 점수 강조 오버레이로 축소 가능.
- [ ] **매칭 종료 연출 내용**: `PlayMatchEndSequenceAsync`의 구체 연출(승/패 전체 화면 등) — 기획/연출 확정.
- [ ] **점수 펄스 디테일**: 펄스 스케일/색 강조 수치(연출 톤).

---

> 작성: 2026-06-04 · 선행 코드 확인: `VanguardInGameUI`(`SetRoundScore`/`_selfHeader`·`_opponentHeader`/`_selfRoundText`·`_opponentRoundText`/`_touchBlocker`/`_testMode`), `VanguardRankingDisplaySlot`(헤더), `VanguardGameResultUI`(3R 후 최종 결과). 스샷(상대 마젠타 ◆/자신 블루 ◆ 점수 밴드) 매핑. 활성/비활성 토글 + show-연출-hide 캡슐화 방식 권장. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
