# Vanguard 매칭 대기 팝업(VanguardMatchingPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

로비에서 **Match(또는 Duel) 진입 시 상대 매칭을 기다리는 동안** 뜨는 팝업(첨부 이미지: 로비 위 딤 + 원형 스피너 + "Matching in: 10s" 카운트다운)의 프리팹 + 스크립트를 이 문서만 보고 완전하게 제작할 수 있도록 정리한다.

- **네이밍**: **`VanguardMatchingPopup`**. 현재 `VanguardLobbyPanel.StartMatchAsync`의 임시 `ServerLoadingPopupUI.Show("vanguard_matching")`를 대체.
- 짝 문서: [[2026-06-03_vanguard-duel-matching-popup-ui]](듀얼 후보 선택), [[2026-06-03_vanguard-ingame-battle-ui]](매칭 성공 후 인게임), 상위 [[2026-05-29_vanguard-implementation-plan-ingame]] §3(매칭→씬 진입)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 신규 `VanguardMatchingPopup : UIBase` (간단 — 스피너 + 카운트다운 + 취소) |
| 프리팹 | 신규 `Resources_moved/UI/VanguardMatchingPopup.prefab` (로비 위 딤 오버레이) |
| 진입 | `VanguardLobbyPanel.OnClickMatch`/(Duel 도전) → `Show<VanguardMatchingPopup>(VanguardMatchingArgs)` |
| 표시 | 딤(로비 비침) + 회전 스피너 + `Matching in: {N}s` 카운트다운 |
| 동작 | 카운트다운 + (병렬) `FindMatchAsync(mode)` → 성공/시간초과 → onComplete → 닫고 `GameScene` 진입 |
| 취소 | (선택) 취소 시 매칭 중단 — **Duel은 상대 못 찾으면 토큰 미소모**(위키 패치 f) |
| 데이터 | `VanguardManager.FindMatchAsync`(미연동 → 더미 N초 후 성공) |

---

## 1. 진입 / 흐름

```
VanguardLobbyPanel.OnClickMatch()  (또는 Duel 도전 확정 — VanguardDuelSelectPopup)
  └─ Show<VanguardMatchingPopup>(new VanguardMatchingArgs { mode, opponent, onComplete, onCancel })
       ├─ 딤 + 스피너 + "Matching in: Ns" 카운트다운 시작
       ├─ (병렬) VanguardManager.FindMatchAsync(mode) — 상대 클론 탐색
       ├─ 매칭 성공(또는 카운트다운 0) → onComplete(VanguardMatchData)
       │     └─ 팝업 닫기 → SceneManager.LoadGameSceneAsync(GameModeType.Vanguard, stageId)
       └─ (취소 시) → onCancel → 팝업 닫기 (Duel: 상대 없으면 토큰 미소모)
```

- 현재 `VanguardLobbyPanel`은 임시로 `EnterVanguardSceneAsync()`(매칭 우회 즉시 씬 진입). → **`StartMatchAsync(mode)` 복구 시 그 안에서 본 팝업을 띄우도록** 교체.
- Match 모드 = 자동 탐색(스샷의 카운트다운). Duel 모드 = 후보 선택 후 도전 → 매칭(상대 확정이라 짧을 수 있음).

---

## 2. 이미지 상세 분석

| # | 영역 | 스샷 | 매핑 |
|---|---|---|---|
| A | 배경 | 로비가 어둡게 비침(전체 딤) | 반투명 Image(로비 위 오버레이) |
| B | 스피너 | 중앙 원형 회전 게이지/링 | `_spinner`(회전 연출) |
| C | 카운트다운 | `Matching in: 10s` | `_countdownText`(로컬라이즈 포맷) |
| D | (취소) | 스샷엔 명시적 버튼 없음 | `_cancelButton`/`_dimButton`(선택, §9) |

- 로비 요소(재화/티어/Next Enemies 등)는 **딤 뒤로 비치기만** 함 — 팝업은 로비를 가리지 않고 어둡게 덮는 오버레이.
- 스피너는 원형 링(스샷). 단순 `RectTransform.DORotate` 무한 회전 또는 이미지 fillAmount 애니.

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **ServerLoadingPopupUI**(패턴) | `UI/.../ServerLoadingPopupUI.cs` | 스피너/딤 연출 패턴 참고(딤+스피너) | `Show(string)`/`Hide()`/`SetMessage` — 단, 카운트다운 없음 → 전용 팝업 신설 |
| **VanguardPopupBase**(선택) | `UI/Vanguard/Popup/VanguardPopupBase.cs` | 베이스 | `uiPosition=Popup` |
| **VanguardManager** | `Core/Managers/Vanguard/VanguardManager.cs` | 매칭 | `FindMatchAsync(EVanguardMode)`(ingame 10장, 미구현 TODO) |
| **VanguardLobbyPanel** | `UI/Vanguard/Component/VanguardLobbyPanel.cs` | 진입점 | `StartMatchAsync(mode)`(임시) → 본 팝업으로 교체 |
| DOTween | - | 스피너 회전 | `DORotate`(무한) `SetUpdate(true)` |

> `ServerLoadingPopupUI`는 메시지+스피너만 있고 **카운트다운(N초)** 이 없어 그대로 못 씀 → 전용 `VanguardMatchingPopup` 신설(스피너 연출 패턴만 차용).

### 신규 작성 (1개 + 인자)

- `VanguardMatchingPopup.cs`(스피너 + 카운트다운 + 매칭 await + 취소).
- `VanguardMatchingArgs`(mode/opponent/onComplete/onCancel) — `Opened(param)` 전달.

---

## 4. UI 프리팹 구조 (하이어라키)

> 신규 `VanguardMatchingPopup.prefab`(`Resources_moved/UI/`). 루트 `VanguardMatchingPopup.cs`, `uiPosition=Popup`. 전체 딤(로비 비침).

```
VanguardMatchingPopup (루트, ▶ VanguardMatchingPopup.cs)
├─ Dim (Image, 화면 전체 반투명 + raycast 차단)          → _dimButton (선택: 탭 취소)
├─ Center
│  ├─ SpinnerRing (Image, 회전 연출)                     → _spinner
│  └─ CountdownText ("Matching in: 10s")                → _countdownText
└─ (선택) Btn_Cancel                                     → _cancelButton
```

- Dim: 반투명(예: alpha 0.6~0.8) — 로비가 비치도록. raycast target ON(하위 입력 차단).
- Spinner: 원형 이미지 무한 회전(`DORotate(360, dur, RotateMode.FastBeyond360).SetLoops(-1)`), `SetUpdate(true)`.
- 취소 UI는 스샷에 없으나 Duel 토큰 정책상 필요할 수 있어 옵션으로 둠(§9).

---

## 5. 스크립트 설계

### 5-1. 진입 인자

```csharp
using System;

/// <summary> 매칭 팝업 인자. 모드/상대(듀얼)/완료·취소 콜백. </summary>
public class VanguardMatchingArgs
{
    public EVanguardMode mode;               // Match / Duel
    public VanguardDuelOpponent opponent;    // Duel일 때 선택된 상대(없으면 자동 탐색)
    public Action<VanguardMatchData> onComplete; // 매칭 성공 → 호출자가 씬 진입
    public Action onCancel;                  // 취소 → 호출자 정리(듀얼 토큰 미소모 등)
    public int countdownSeconds;             // 표시용 카운트다운(예: 10). 0이면 무한 스피너만
}
```

### 5-2. `VanguardMatchingPopup.cs` (참조 구현)

```csharp
using System.Threading;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 매칭 대기 팝업. 딤 + 회전 스피너 + "Matching in: Ns" 카운트다운.
/// 카운트다운과 병렬로 FindMatchAsync 진행 → 성공/시간초과 시 onComplete, 취소 시 onCancel.
/// </summary>
public class VanguardMatchingPopup : UIBase
{
    #region Serialized
    [SerializeField] private Button _dimButton;        // 선택: 탭 취소
    [SerializeField] private RectTransform _spinner;
    [SerializeField] private TextMeshProUGUI _countdownText;
    [SerializeField] private Button _cancelButton;     // 선택
    [SerializeField] private float _spinnerRotateDuration = 1.2f;

    [Header("[TEST]")]
    [SerializeField] private bool _useDummy = true;
    [SerializeField, Min(1)] private int _dummyMatchSeconds = 3; // 더미: N초 후 매칭 성공
    #endregion

    private VanguardMatchingArgs _args;
    private VanguardManager _vanguardManager;
    private CancellationTokenSource _cts;
    private Tween _spinTween;
    private bool _finished;

    protected override void Awake()
    {
        base.Awake();
        uiPosition = eUIPosition.Popup;
        _cancelButton?.onClick.AddListener(OnCancel);
        // _dimButton?.onClick.AddListener(OnCancel); // 탭 취소 허용 시
    }

    public override void Opened(object[] param)
    {
        base.Opened(param);
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();
        _args = (param != null && param.Length > 0) ? param[0] as VanguardMatchingArgs : null;

        StartSpinner();
        _cts = new CancellationTokenSource();
        RunAsync(_cts.Token).Forget();
    }

    public override void Closed(object[] param)
    {
        _spinTween?.Kill();
        CancelCts();
        base.Closed(param);
    }

    private void StartSpinner()
    {
        if (_spinner == null) return;
        _spinTween?.Kill();
        _spinTween = _spinner
            .DOLocalRotate(new Vector3(0, 0, -360f), _spinnerRotateDuration, RotateMode.FastBeyond360)
            .SetEase(Ease.Linear).SetLoops(-1).SetUpdate(true);
    }

    private async UniTaskVoid RunAsync(CancellationToken token)
    {
        // 카운트다운 UI + 매칭 병렬. 매칭 성공이 먼저면 즉시 완료, 아니면 카운트다운 종료 시 완료.
        int seconds = _args?.countdownSeconds > 0 ? _args.countdownSeconds : _dummyMatchSeconds;

        // 매칭 태스크
        var matchTask = FindMatchAsync(token);

        // 카운트다운 표시 (ignoreTimeScale)
        for (int t = seconds; t > 0; t--)
        {
            if (token.IsCancellationRequested) return;
            if (_countdownText != null)
                _countdownText.text = LocalizationManager.GetLocalizedTextFormat("vanguard_matching_in", t);
            // 매칭이 카운트다운 중 성공하면 바로 종료
            if (matchTask.Status == UniTaskStatus.Succeeded) break;
            await UniTask.Delay(1000, ignoreTimeScale: true, cancellationToken: token).SuppressCancellationThrow();
        }

        VanguardMatchData match;
        try { match = await matchTask; }
        catch (System.OperationCanceledException) { return; }

        if (_finished || token.IsCancellationRequested) return;
        _finished = true;

        // 완료 → 호출자가 씬 진입
        _args?.onComplete?.Invoke(match);
        Managers.Instance.GetManager<UIManager>()?.Hide<VanguardMatchingPopup>();
    }

    private async UniTask<VanguardMatchData> FindMatchAsync(CancellationToken token)
    {
        if (_useDummy)
        {
            await UniTask.Delay(_dummyMatchSeconds * 1000, ignoreTimeScale: true, cancellationToken: token);
            return new VanguardMatchData { mode = _args?.mode ?? EVanguardMode.Match /*, 더미 클론/시드 */ };
        }
        // 정식: 서버 매칭 (ingame §10). 상대 클론 + 시드 수신.
        return await _vanguardManager.FindMatchAsync(_args.mode /*, opponent */);
    }

    private void OnCancel()
    {
        if (_finished) return;
        _finished = true;
        CancelCts();
        _args?.onCancel?.Invoke();   // Duel: 상대 미발견 시 토큰 미소모 처리(호출자)
        Managers.Instance.GetManager<UIManager>()?.Hide<VanguardMatchingPopup>();
    }

    private void CancelCts()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;
    }
}
```

### 5-3. 호출부 (`VanguardLobbyPanel` — 교체)

```csharp
// OnClickMatch → 매칭 팝업 경유 (임시 EnterVanguardSceneAsync 대체)
private void OnClickMatch()
{
    var args = new VanguardMatchingArgs
    {
        mode = EVanguardMode.Match,
        countdownSeconds = 10,
        onComplete = match => EnterVanguardSceneAsync(match).Forget(),
        onCancel = () => { /* Match: 정리 */ },
    };
    _uiManager?.Show<VanguardMatchingPopup>(args);
}

private async UniTaskVoid EnterVanguardSceneAsync(VanguardMatchData match)
{
    var sceneManager = Managers.Instance.GetManager<SceneManager>();
    await sceneManager.LoadGameSceneAsync(GameModeType.Vanguard, VanguardStagePlayService.VANGUARD_STAGE_ID /*, match 주입 */);
}
```

> Duel: `VanguardDuelSelectPopup`의 "도전" → `Show<VanguardMatchingPopup>(args{mode=Duel, opponent})` → onComplete 시 씬 진입. onCancel 시 토큰 미소모(서버).

### 5-4. Localization 키

| 키 | 내용 |
|---|---|
| `vanguard_matching_in` | "Matching in: {0}s" |
| (선택) `cancel` | 취소 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 매칭(상대 클론/시드) | ⚠️ 미구현 | `VanguardManager.FindMatchAsync(mode)`(ingame §10). 더미는 N초 후 성공 |
| 카운트다운 | UI | 표시용. 실제 매칭 완료 시 즉시 종료(카운트다운과 독립). 0초 도달 시 강제 완료 또는 연장(정책 §9) |
| 취소 정책 | 부분 | Match=정리만. **Duel=상대 미발견 시 토큰 미소모**(위키 패치 f) → onCancel에서 호출자가 처리 |
| 씬 진입 | 연계 | onComplete → `LoadGameSceneAsync(Vanguard)` + match 주입 → `VanguardInGameUI` |

### CLAUDE.md 준수
- DOTween 스피너 `SetUpdate(true)` / 카운트다운 `UniTask.Delay(ignoreTimeScale:true)` / `async void`는 `UniTaskVoid` / `GetManager<T>()` / 텍스트 로컬라이즈 / `Closed`에서 트윈 Kill + CTS 취소.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardMatchingArgs` + `VanguardMatchingPopup.cs` 작성(5-1/5-2). 빌드-그린.
2. [ ] `VanguardLobbyPanel.OnClickMatch`(+Duel 도전부)에서 본 팝업 경유로 교체(5-3).

**B. 프리팹** (`VanguardMatchingPopup.prefab` 신규)

3. [ ] 루트 + Dim(반투명, raycast 차단) → `_dimButton`(선택).
4. [ ] 중앙 SpinnerRing(원형 이미지) → `_spinner` + CountdownText → `_countdownText`.
5. [ ] (선택) Btn_Cancel → `_cancelButton`. `Resources_moved/UI/`에 클래스명 저장.

**C. 연동**

6. [ ] `_useDummy=true` 테스트: 카운트다운 표시 + N초 후 자동 완료 → 씬 진입.
7. [ ] Localization 키 추가. 정식 `FindMatchAsync` 연결.

---

## 8. 검증 체크리스트

- [ ] Match 클릭 → 팝업 오픈(로비 딤+비침), 스피너 회전 + "Matching in: Ns" 1초 갱신.
- [ ] 더미 N초 후(또는 매칭 성공) → onComplete → 팝업 닫고 GameScene 진입.
- [ ] 매칭이 카운트다운 중 성공하면 즉시 종료(카운트다운 안 기다림).
- [ ] (취소 활성 시) 취소 → onCancel → 닫힘. Duel은 토큰 미소모.
- [ ] `Closed`에서 스피너 Kill + CTS 취소(누수/중복 콜백 없음). 완료/취소 1회만(`_finished` 가드).
- [ ] CLAUDE.md 준수(SetUpdate/ignoreTimeScale/UniTaskVoid/로컬라이즈).

---

## 9. 미해결 / 확인 필요

- [ ] **취소 UI 유무**: 스샷엔 명시 버튼 없음. Duel 토큰 정책상 취소 필요할 수 있음 → 버튼/딤 탭 취소 여부 기획 확정.
- [ ] **카운트다운 0초 동작**: 강제 매칭 완료(봇/더미) vs 연장 vs 실패 — 위키 "초기 매칭 공백" 대응(봇 클론 시드, ingame §6).
- [ ] **Match vs Duel 카운트다운 차이**: Duel은 상대 확정이라 즉시일 수 있음(카운트다운 생략?) — 기획.
- [ ] **매칭 실패 처리**: 시간초과/오류 시 토스트 + 로비 복귀.
- [ ] **씬 진입 시 match 주입 방식**: `LoadGameSceneAsync` 파라미터 or `VanguardManager` 캐시 → `VanguardStagePlayService` 소비(ingame §10).

---

> 작성: 2026-06-04 · 선행 코드 확인: `VanguardLobbyPanel`(`OnClickMatch`/`EnterVanguardSceneAsync`/`StartMatchAsync` 임시 `ServerLoadingPopupUI.Show("vanguard_matching")`), `ServerLoadingPopupUI`(Show/Hide/SetMessage — 카운트다운 없음), `VanguardManager.FindMatchAsync`(ingame §10, 미구현). 스샷(딤+스피너+"Matching in: 10s") 매핑. 카운트다운+매칭 병렬 + 취소(듀얼 토큰 미소모) 설계. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
