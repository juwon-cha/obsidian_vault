# Vanguard 티어 진행 팝업(VanguardTierProgressPopup) 구현 종합 문서 (2026-06-04)

## 문서 목적

매치 종료 후 **티어/승점 변동을 연출로 보여주는 팝업**(첨부 이미지: Silver 2 엠블럼 + 메달 + 60/100 게이지 + Battle Score 내역)의 프리팹 + 스크립트를 이 문서만 보고 한 번에 제작할 수 있도록 정리한다.

- 네이밍 확정: **`VanguardTierProgressPopup`** (`VanguardMatchResultPopup`은 승패 결과 UI용으로 예약, `VanguardResultPanel`은 시즌 정산용).
- 역할: 게이지가 `pointDelta`만큼 차오르고/내려가고, 100 도달 시 **승급 연출**(엠블럼 교체), 음수로 0 미만 시 **강등 연출**. 순수 표시/연출 팝업 — 티어 계산은 서버 권위.
- 짝 문서: [[2026-06-03_vanguard-ingame-battle-ui]](전투 결과 플로우), [[2026-06-03_vanguard-duel-matching-popup-ui]](승리 포인트 출처), 상위 [[2026-05-29_vanguard-implementation-plan-ingame]] §8(서버 응답)
- `[설계 판단]` = 스샷/위키 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 신규 `VanguardTierProgressPopup : VanguardPopupBase` 1개 (+ `VanguardScoreEntryRow` 행 1개) |
| 프리팹 | 신규 `Resources_moved/UI/VanguardTierProgressPopup.prefab` (`Show<T>` 로드 경로 규약) |
| 데이터 입력 | `Opened(param[0] = VanguardTierProgressData)` — **prev/new 티어·포인트 + 점수 내역 리스트**를 호출자가 전달 (팝업은 계산 안 함) |
| 티어 뱃지/이름 | `VanguardTierUtil.GetTierSprite/GetDisplayName` 재사용. 디비전 로마자(II)는 신규 헬퍼 |
| 게이지 기준 | `VanguardRankService.PointsPerDivision = 100` (디비전당 100, `NextTierPoints`) |
| 승급/강등 순회 | `EVanguardTier` 인코딩 활용 신규 헬퍼 `GetNextTier/GetPrevTier` (그룹 경계 105→201 처리) |
| 연출 | DOTween: 게이지 `DOValue` → 오버플로 시 엠블럼 스왑+셰브론 플래시 → 잔여 게이지. **탭 = 스킵/닫기** |
| 닫힘 후 | 호출자가 `RankService.UpdateFromServerAsync(newTier, newPoints)` + 로비 `Refresh()` |

---

## 1. 호출 플로우 (어디서 띄우나)

```
전투 종료 → 서버 /vanguard/match/result 응답 { win, pointDelta, newScore, newTier, rewards }   // ingame §8
  └─ (승패 결과 UI: VanguardMatchResultPopup — 별도 문서) 닫힘
       └─ Show<VanguardTierProgressPopup>(new VanguardTierProgressData {
              prevTier  = rankService.Tier,            // 캐시(아직 갱신 전)
              prevPoints= rankService.CurrentPoints,
              newTier   = response.newTier,
              newPoints = response.newScore,
              scoreEntries = { ("vanguard_score_victory", +100), ("vanguard_score_triumph", +30), ... }
          })
            └─ 연출 종료/탭 → ClosePopup
                 └─ 호출자: rankService.UpdateFromServerAsync(newTier, newPoints) → 로비 Refresh()
```

> ⚠️ **갱신 순서 중요**: `RankService` 캐시를 팝업 표시 **전에** 갱신하면 prev 값을 잃는다. → **팝업이 닫힌 뒤 갱신**(또는 호출자가 prev를 미리 떠놓고 전달). 본 문서는 "닫힌 뒤 갱신"을 표준으로 한다.
> [TEST] 서버 미연결: `_useTestData`로 더미 `VanguardTierProgressData` 주입(Silver2, 60→190 등) — `ApplyLocalCache` 패턴과 동일 사상.

---

## 2. 이미지 상세 분석

| # | 요소 | 스샷 | 매핑 |
|---|---|---|---|
| A | 딤 배경 | 전체 어두움, 버튼 없음 | `_dimButton` — **탭=스킵/닫기** `[설계 판단]` |
| B | 글로우 백드롭 | 다이아 형태 붉은/주황 발광 + 그리드 | 정적 Image(+은은한 회전/펄스 연출 선택) |
| C | 좌우 셰브론 | 주황 대형 ◀▶ 날개 | 장식 + **승급/강등 연출 플래시** 대상 `[설계 판단]` |
| D | 티어 엠블럼 | 육각 실버 엠블럼 | `_tierEmblemImage` ← `VanguardTierUtil.GetTierSprite(tier)` |
| E | 디비전 표식 | 엠블럼 상단 `II` 명판 | `_divisionText`(로마자) — 신규 헬퍼(§5-3) |
| F | 티어명 | `Silver 2` | `_tierNameText` ← `VanguardTierUtil.GetDisplayName(tier)` |
| G | 메달 패널 | 노란 메달 ×2 | `_medalIcons[]` 토글 — 의미는 §9 확인(듀얼 팝업 ◇x2와 동일 계열) |
| H | 진행 게이지 | 핑크 바 `60/100` 중앙 텍스트 | `_pointSlider` + `_pointText` — 기준 `NextTierPoints`(100) |
| I | Battle Score 헤더 | 핑크 띠 `Battle Score` | `_battleScoreHeader`(로컬라이즈) |
| J | 점수 내역 | `Victory +100` / `Triumph +30` (세로) | `VanguardScoreEntryRow` 동적 생성(라벨+증감) |

- 스샷 상태 해석: 현재 Silver 2, 디비전 내 60/100, 이번 매치 +130(=Victory100+Triumph30) → 연출상 60→100(승급 또는 오버플로)→… 흐름의 한 프레임.
- 좌측 연필/우하단 커서는 스크린샷 도구 아티팩트 — UI 아님.

---

## 3. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **VanguardPopupBase** | `UI/Vanguard/Popup/VanguardPopupBase.cs` | 베이스 | `_closeButton`(딤에 연결 가능) · `uiPosition=Popup` · `ClosePopup()` |
| **VanguardTierUtil** | `UI/Vanguard/VanguardTierUtil.cs` | 엠블럼/이름 | `GetTierSprite(EVanguardTier)`(그룹 단위 스프라이트) · `GetDisplayName` |
| **VanguardRankService** | `Core/Managers/Vanguard/VanguardRankService.cs` | 기준값/캐시 갱신 | `Tier`/`CurrentPoints`/`NextTierPoints`(=100) · `UpdateFromServerAsync(tier, points)` · `ApplyLocalCache`(테스트) |
| **EVanguardTier** | `Core/Enums/Vanguard/EVanguardTier.cs` | 승급/강등 순회 | 인코딩: 그룹=`value/100`, **값이 클수록 높은 랭크**, 그룹 내 1~5 오름차순(101=Bronze5 최하). 디비전 라벨은 enum 이름 끝자리(내림차순 라벨) |
| DOTween | - | 게이지/엠블럼 연출 | `DOValue`/`DOScale`/`DOFade`/Sequence |
| 로비 티어 표시 | `VanguardLobbyPanel.UpdateTierDisplay()` | 표기 규칙 일치 확인용 | `value = current/next`, `"{cur}/{next}"` 텍스트 |

> 전용 티어업 팝업 선례는 코드베이스에 없음(Relic/Minion RankUp은 장비 강화 UI) — 연출부는 본 문서가 신규 설계.

### 신규 작성 (3개)

- `VanguardTierProgressPopup.cs` — 본체.
- `VanguardScoreEntryRow.cs` — Battle Score 1행(라벨+값).
- `VanguardTierMath`(static 헬퍼 또는 `VanguardTierUtil` 확장) — `GetNextTier/GetPrevTier/GetDivisionRoman`.

---

## 4. UI 프리팹 구조 (전체 하이어라키)

```
VanguardTierProgressPopup (루트, ▶ VanguardTierProgressPopup.cs, uiPosition=Popup)
├─ Dim (Image + Button, 전체)                         → _dimButton (탭=스킵→닫기)
├─ GlowBackdrop (다이아 발광 + 그리드, 정적/펄스)       → _glowBackdrop
├─ EmblemGroup
│  ├─ ChevronLeft (주황 ◀ 날개)                       → _chevronLeft  (승급 플래시)
│  ├─ ChevronRight (주황 ▶ 날개)                      → _chevronRight
│  ├─ TierEmblem (Image, 육각 엠블럼)                  → _tierEmblemImage
│  └─ DivisionPlaque (상단 명판)
│     └─ DivisionText (TMP, "II")                     → _divisionText
├─ TierNameText (TMP, "Silver 2")                     → _tierNameText
├─ MedalPanel (어두운 라운드 패널, HorizontalLayout)
│  └─ MedalIcon x5 (노란 메달, 기본 비활성)             → _medalIcons[5]
├─ PointBar
│  ├─ Slider (핑크 Fill)                               → _pointSlider
│  └─ PointText (TMP 중앙, "60/100")                   → _pointText
└─ BattleScorePanel
   ├─ Header (핑크 띠, "Battle Score")                 → _battleScoreHeaderText
   └─ ScoreList (VerticalLayoutGroup)                  → _scoreListParent
      └─ (런타임) VanguardScoreEntryRow xN              → _scoreEntryRowPrefab
```

### 신규 프리팹: `VanguardScoreEntryRow.prefab`

- 위치: `Assets/_Project/3_Prefabs/UI/Vanguard/VanguardScoreEntryRow.prefab`
- 구성: `LabelText`(좌, "Victory") + `ValueText`(우 또는 이어서, "+100"). 한 줄 TMP 2개.

### 메달 패널

- 고정 5슬롯(디비전 최대치 가정) 배치 후 개수만큼 SetActive `[설계 판단]` — 실제 최대 개수는 §9 확인 후 조정.

---

## 5. 스크립트 설계

### 5-1. 데이터 모델

```csharp
using System.Collections.Generic;

/// <summary> 티어 진행 팝업 입력 데이터. 호출자가 서버 응답 + 갱신 전 캐시로 구성. </summary>
public class VanguardTierProgressData
{
    public EVanguardTier prevTier;
    public int prevPoints;            // 갱신 전 디비전 내 포인트 (0~99)
    public EVanguardTier newTier;     // 서버 응답 newTier
    public int newPoints;             // 서버 응답 newScore (디비전 내 포인트)
    public int medalCount;            // 메달 수 (§9 의미 확정 전까지 표기만)
    public List<(string labelKey, int delta)> scoreEntries; // 예: ("vanguard_score_victory", +100)
}
```

### 5-2. `VanguardTierProgressPopup.cs` (참조 구현)

```csharp
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// 매치 후 티어/승점 변동 연출 팝업. 게이지 채움 → 승급/강등 시 엠블럼 교체 → 잔여 게이지.
/// 순수 표시 전용: 티어 산출은 서버 권위, 캐시 갱신은 닫힌 뒤 호출자가 수행(§1).
/// </summary>
public class VanguardTierProgressPopup : VanguardPopupBase
{
    #region Serialized
    [Header("배경/연출")]
    [SerializeField] private Button _dimButton;             // 탭=스킵/닫기
    [SerializeField] private GameObject _glowBackdrop;
    [SerializeField] private Image _chevronLeft;
    [SerializeField] private Image _chevronRight;

    [Header("티어 표시")]
    [SerializeField] private Image _tierEmblemImage;
    [SerializeField] private TextMeshProUGUI _divisionText;  // 로마자 "II"
    [SerializeField] private TextMeshProUGUI _tierNameText;  // "Silver 2"
    [SerializeField] private GameObject[] _medalIcons;       // 5슬롯 토글

    [Header("게이지")]
    [SerializeField] private Slider _pointSlider;
    [SerializeField] private TextMeshProUGUI _pointText;     // "60/100"

    [Header("Battle Score")]
    [SerializeField] private TextMeshProUGUI _battleScoreHeaderText;
    [SerializeField] private Transform _scoreListParent;
    [SerializeField] private VanguardScoreEntryRow _scoreEntryRowPrefab;

    [Header("연출 설정")]
    [SerializeField] private float _fillDurationPerDivision = 0.6f; // 디비전 1칸 채움 시간
    [SerializeField] private float _promoteFlashDuration = 0.4f;

    [Header("[TEST]")]
    [SerializeField] private bool _useTestData = true;
    #endregion

    private const int PointsPerDivision = 100; // RankService.PointsPerDivision과 동일 (차팅 대체 시 동기화)

    private VanguardTierProgressData _data;
    private readonly List<GameObject> _scoreRows = new();
    private Sequence _seq;
    private bool _skipped;

    protected override void Awake()
    {
        base.Awake(); // uiPosition=Popup
        _dimButton?.onClick.AddListener(OnTap);
    }

    public override void Opened(params object[] param)
    {
        base.Opened(param);

        _data = (param != null && param.Length > 0) ? param[0] as VanguardTierProgressData : null;
        if (_data == null && _useTestData) _data = BuildTestData();
        if (_data == null) { ClosePopup(); return; }

        if (_battleScoreHeaderText != null)
            _battleScoreHeaderText.text = LocalizationManager.GetLocalizedText("vanguard_battle_score");

        BuildScoreRows();
        ApplyTierVisual(_data.prevTier, _data.prevPoints);
        SetMedals(_data.medalCount);
        PlayProgressAsync().Forget();
    }

    public override void Closed(params object[] param)
    {
        _seq?.Kill();
        ClearScoreRows();
        base.Closed(param);
    }

    // ─────────── 연출 ───────────
    private async UniTaskVoid PlayProgressAsync()
    {
        // prev→new 사이의 디비전 단계 시퀀스 계산 (승급: 100 채우고 다음 티어 0부터 / 강등: 0 뚫고 이전 티어 100부터)
        var steps = VanguardTierMath.BuildProgressSteps(
            _data.prevTier, _data.prevPoints, _data.newTier, _data.newPoints, PointsPerDivision);

        foreach (var step in steps)
        {
            if (_skipped) break;

            // step: (tier, fromPoints, toPoints, isPromote, isDemote)
            ApplyTierVisual(step.tier, step.fromPoints);

            _seq?.Kill();
            _seq = DOTween.Sequence().SetUpdate(true);
            float dur = _fillDurationPerDivision *
                        Mathf.Abs(step.toPoints - step.fromPoints) / (float)PointsPerDivision;

            _seq.Append(_pointSlider.DOValue(step.toPoints / (float)PointsPerDivision, dur).SetEase(Ease.OutQuad));
            _seq.OnUpdate(() => UpdatePointText(step.tier));
            await _seq.AsyncWaitForCompletion();   // CLAUDE.md: ToUniTask 금지

            if (step.isPromote && !_skipped) await PlayPromoteFlashAsync(step.nextTier);
            if (step.isDemote && !_skipped) await PlayDemoteFlashAsync(step.nextTier);
        }

        // 스킵 포함 최종 상태 고정
        ApplyTierVisual(_data.newTier, _data.newPoints);
    }

    private async UniTask PlayPromoteFlashAsync(EVanguardTier nextTier)
    {
        // 셰브론 플래시 + 엠블럼 펀치 스케일 → 엠블럼/명판/이름 교체
        _seq?.Kill();
        _seq = DOTween.Sequence().SetUpdate(true);
        if (_chevronLeft != null) _seq.Join(_chevronLeft.DOFade(1f, _promoteFlashDuration * 0.5f).SetLoops(2, LoopType.Yoyo));
        if (_chevronRight != null) _seq.Join(_chevronRight.DOFade(1f, _promoteFlashDuration * 0.5f).SetLoops(2, LoopType.Yoyo));
        _seq.Join(_tierEmblemImage.transform.DOPunchScale(Vector3.one * 0.2f, _promoteFlashDuration));
        await _seq.AsyncWaitForCompletion();

        AudioUtils.PlaySFXUnscaled("ButtonClick").Forget(); // TODO: 전용 승급 SFX 키로 교체
        ApplyTierVisual(nextTier, 0);
    }

    private async UniTask PlayDemoteFlashAsync(EVanguardTier prevTier)
    {
        // 간단 페이드 다운 연출 후 교체 (승급의 절제 버전)
        _seq?.Kill();
        _seq = DOTween.Sequence().SetUpdate(true);
        _seq.Join(_tierEmblemImage.DOFade(0.3f, _promoteFlashDuration * 0.5f).SetLoops(2, LoopType.Yoyo));
        await _seq.AsyncWaitForCompletion();
        ApplyTierVisual(prevTier, PointsPerDivision);
    }

    // ─────────── 표시 ───────────
    private void ApplyTierVisual(EVanguardTier tier, int points)
    {
        if (_tierEmblemImage != null) _tierEmblemImage.sprite = VanguardTierUtil.GetTierSprite(tier);
        if (_tierNameText != null) _tierNameText.text = VanguardTierUtil.GetDisplayName(tier);
        if (_divisionText != null) _divisionText.text = VanguardTierMath.GetDivisionRoman(tier);
        if (_pointSlider != null) _pointSlider.value = points / (float)PointsPerDivision;
        if (_pointText != null) _pointText.text = $"{points}/{PointsPerDivision}";
    }

    private void UpdatePointText(EVanguardTier tier)
    {
        if (_pointText == null || _pointSlider == null) return;
        int cur = Mathf.RoundToInt(_pointSlider.value * PointsPerDivision);
        _pointText.text = $"{cur}/{PointsPerDivision}";
    }

    private void SetMedals(int count)
    {
        if (_medalIcons == null) return;
        for (int i = 0; i < _medalIcons.Length; i++)
            if (_medalIcons[i] != null) _medalIcons[i].SetActive(i < count);
    }

    private void BuildScoreRows()
    {
        ClearScoreRows();
        if (_data.scoreEntries == null) return;
        foreach (var (labelKey, delta) in _data.scoreEntries)
        {
            var row = Instantiate(_scoreEntryRowPrefab, _scoreListParent);
            row.Bind(LocalizationManager.GetLocalizedText(labelKey), delta);
            _scoreRows.Add(row.gameObject);
        }
    }

    private void ClearScoreRows()
    {
        foreach (var go in _scoreRows) if (go != null) Destroy(go);
        _scoreRows.Clear();
    }

    // ─────────── 입력 ───────────
    private void OnTap()
    {
        if (!_skipped) { _skipped = true; _seq?.Complete(); ApplyTierVisual(_data.newTier, _data.newPoints); return; } // 1탭=스킵
        ClosePopup();                                                                                                  // 2탭=닫기
    }

    private VanguardTierProgressData BuildTestData() => new()
    {
        prevTier = EVanguardTier.Silver2, prevPoints = 60,
        newTier = EVanguardTier.Silver1, newPoints = 90,   // 60→100 승급→90 (멀티 스텝 검증)
        medalCount = 2,
        scoreEntries = new() { ("vanguard_score_victory", 100), ("vanguard_score_triumph", 30) },
    };
}
```

### 5-3. `VanguardTierMath` (static 헬퍼 — 신규)

```csharp
using System.Collections.Generic;

/// <summary>
/// EVanguardTier 인코딩(그룹=value/100, 그룹 내 1~5 오름차순, 클수록 높은 랭크) 기반 순회/표기 헬퍼.
/// 연출용 클라 계산 전용 — 실제 티어 산출은 서버 권위.
/// </summary>
public static class VanguardTierMath
{
    /// <summary>다음(승급) 티어. 그룹 경계: x05 → (x+1)01 (예: Bronze1(105)→Silver5(201)). Ultimate는 그대로.</summary>
    public static EVanguardTier GetNextTier(EVanguardTier tier)
    {
        if (tier == EVanguardTier.None || tier == EVanguardTier.Ultimate) return tier;
        int v = (int)tier;
        int next = (v % 100 < 5) ? v + 1 : (v / 100 + 1) * 100 + 1;
        return (EVanguardTier)next; // Diamond1(505)→Ultimate(601)도 본 식으로 충족
    }

    /// <summary>이전(강등) 티어. 그룹 경계: x01 → (x-1)05. Bronze5/None은 그대로.</summary>
    public static EVanguardTier GetPrevTier(EVanguardTier tier)
    {
        if (tier <= EVanguardTier.Bronze5) return tier;
        int v = (int)tier;
        int prev = (v % 100 > 1) ? v - 1 : (v / 100 - 1) * 100 + 5;
        if (tier == EVanguardTier.Ultimate) prev = (int)EVanguardTier.Diamond1;
        return (EVanguardTier)prev;
    }

    /// <summary>디비전 로마자 (enum 이름 끝자리: Silver2 → "II"). Ultimate/None은 빈 문자열.</summary>
    public static string GetDivisionRoman(EVanguardTier tier)
    {
        if (tier == EVanguardTier.None || tier == EVanguardTier.Ultimate) return string.Empty;
        char last = tier.ToString()[^1];
        return last switch { '1' => "I", '2' => "II", '3' => "III", '4' => "IV", '5' => "V", _ => string.Empty };
    }

    public readonly struct ProgressStep
    {
        public readonly EVanguardTier tier;     // 이 스텝에서 표시 중인 티어
        public readonly int fromPoints, toPoints;
        public readonly bool isPromote, isDemote;
        public readonly EVanguardTier nextTier; // 승급/강등 후 티어
        public ProgressStep(EVanguardTier t, int f, int to, bool pro, bool dem, EVanguardTier nt)
        { tier = t; fromPoints = f; toPoints = to; isPromote = pro; isDemote = dem; nextTier = nt; }
    }

    /// <summary>
    /// prev→new 연출 스텝 빌드.
    /// 승급: (tier, from→100, promote) 반복 후 (newTier, 0→newPoints).
    /// 강등: (tier, from→0, demote) 반복 후 (newTier, 100→newPoints).
    /// 동일 티어: 단일 스텝 (from→to). 비교는 enum 값(클수록 높음).
    /// </summary>
    public static List<ProgressStep> BuildProgressSteps(
        EVanguardTier prevTier, int prevPoints, EVanguardTier newTier, int newPoints, int perDivision)
    {
        var steps = new List<ProgressStep>();
        var tier = prevTier; int pts = prevPoints;

        while (tier < newTier) // 승급 체인
        {
            var nt = GetNextTier(tier);
            steps.Add(new ProgressStep(tier, pts, perDivision, true, false, nt));
            tier = nt; pts = 0;
        }
        while (tier > newTier) // 강등 체인
        {
            var pt = GetPrevTier(tier);
            steps.Add(new ProgressStep(tier, pts, 0, false, true, pt));
            tier = pt; pts = perDivision;
        }
        if (pts != newPoints)   // 동일 티어 내 잔여 이동
            steps.Add(new ProgressStep(tier, pts, newPoints, false, false, tier));
        return steps;
    }
}
```

### 5-4. `VanguardScoreEntryRow.cs` (신규)

```csharp
using TMPro;
using UnityEngine;

/// <summary> Battle Score 1행: "Victory +100" 형태. </summary>
public class VanguardScoreEntryRow : MonoBehaviour
{
    [SerializeField] private TextMeshProUGUI _labelText;
    [SerializeField] private TextMeshProUGUI _valueText;

    public void Bind(string label, int delta)
    {
        if (_labelText != null) _labelText.text = label;
        if (_valueText != null) _valueText.text = delta >= 0 ? $"+{delta}" : delta.ToString();
    }
}
```

### 5-5. Localization 키 (신규)

| 키 | 내용 |
|---|---|
| `vanguard_battle_score` | Battle Score |
| `vanguard_score_victory` | Victory |
| `vanguard_score_triumph` | Triumph (의미 확정 후 라벨 조정, §9) |
| (필요 시) `vanguard_score_duel_bonus` 등 | 점수 출처별 추가 |

---

## 6. 데이터 연동 + 가정 / TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| `pointDelta/newScore/newTier` | 서버 응답(ingame §8) | 호출자가 `VanguardTierProgressData`로 변환 전달. 클라 계산 금지(연출 스텝만 클라) |
| 점수 내역(Victory/Triumph 등) | ⚠️ 응답 스키마 미확정 | 서버가 breakdown 리스트 제공 권장 → [[2026-05-31_vanguard-server-api-spec]] 동기화. 미제공 시 `pointDelta` 단일 행 폴백 |
| `PointsPerDivision` | `VanguardRankService`에 `private const 100` | ⚠️ 현재 private — **public 상수/프로퍼티로 노출**하거나 `NextTierPoints` 사용으로 통일(중복 const 방지) |
| 메달 수 | ⚠️ 의미 미확정 | 듀얼 팝업 ◇x2와 동일 계열. 서버 필드 확정 전 `medalCount` 표기만 |
| Ultimate 도달 | 엣지 | `NextTierPoints=0` → 게이지 숨김/풀 처리. `GetNextTier(Ultimate)=Ultimate`로 무한루프 없음(while 조건이 enum 비교라 안전) |

### CLAUDE.md 준수

- DOTween 대기: `await tween.AsyncWaitForCompletion()` — **`ToUniTask()` 금지**(코드 반영됨).
- `async void` 금지(UniTaskVoid/UniTask) / `GetManager<T>()`만 / 텍스트 로컬라이즈 / 매직넘버 const(`PointsPerDivision` 동기화 주의) / `Closed`에서 시퀀스 Kill+행 정리.

---

## 7. 단계별 구현 절차 (체크리스트)

**A. 스크립트**

1. [ ] `VanguardTierMath.cs` 작성(5-3) — 그룹 경계(105→201, 505→601) 단위테스트 권장.
2. [ ] `VanguardScoreEntryRow.cs` 작성(5-4).
3. [ ] `VanguardTierProgressData` + `VanguardTierProgressPopup.cs` 작성(5-1/5-2). 빌드-그린.
4. [ ] `VanguardRankService.PointsPerDivision` public 노출(또는 `NextTierPoints` 경유) 정리.

**B. 프리팹**

5. [ ] `VanguardScoreEntryRow.prefab` 제작(라벨+값 TMP 2개) → `3_Prefabs/UI/Vanguard/`.
6. [ ] `VanguardTierProgressPopup.prefab` 신규(§4 하이어라키) → `Resources_moved/UI/` (이름=클래스명).
7. [ ] 아트 배치: 글로우 백드롭/좌우 셰브론/육각 엠블럼 프레임/디비전 명판/메달 5슬롯/핑크 게이지/Battle Score 띠.
8. [ ] 필드 연결: `_dimButton`/`_tierEmblemImage`/`_divisionText`/`_tierNameText`/`_medalIcons[5]`/`_pointSlider`/`_pointText`/헤더/`_scoreListParent`/`_scoreEntryRowPrefab`/셰브론 2개.
9. [ ] `_useTestData=true` 에디터 테스트: Silver2 60→Silver1 90(승급 1회+잔여) 시나리오.

**C. 연동**

10. [ ] 전투 결과 플로우(승패 UI 닫힘 후)에서 `Show<VanguardTierProgressPopup>(data)` 호출 + 닫힘 후 `UpdateFromServerAsync`+로비 `Refresh()` (§1 순서).
11. [ ] Localization 키 추가(5-5).
12. [ ] 승급 전용 SFX 키 교체(TODO 주석 위치).

---

## 8. 검증 체크리스트

- [ ] 진입 시 prev 상태(엠블럼/디비전 로마자/이름/메달/게이지 from값) 정확 표시.
- [ ] 게이지 연출: 동일 티어 내 증가(60→90), 승급(60→100→교체→0→90), 강등(40→0→교체→100→70), **다중 디비전 점프** 모두 정상.
- [ ] 승급 시 엠블럼/명판/이름 동시 교체 + 셰브론 플래시. 그룹 경계(Bronze1→Silver5) 스프라이트 교체 확인.
- [ ] 탭 1회=연출 스킵(최종 상태 고정), 2회=닫기.
- [ ] Battle Score 행: 라벨 로컬라이즈 + 양수 `+` 접두/음수 그대로.
- [ ] Ultimate 도달/Ultimate에서 시작 엣지(게이지 처리) 크래시 없음.
- [ ] 닫힘 후 캐시 갱신 → 로비 티어 표시와 팝업 최종 상태 일치.
- [ ] `Closed`에서 시퀀스 Kill/행 정리(누수·중복 트윈 없음).
- [ ] CLAUDE.md: `AsyncWaitForCompletion` 사용(ToUniTask 금지)/로컬라이즈/매직넘버/async void 없음.

---

## 9. 미해결 / 확인 필요

- [ ] **메달(노란 ◇) 의미와 최대 개수**: 듀얼 팝업 ◇x2와 동일 계열 — 디비전 내 단계? 승수? 서버 필드 확정 필요(전 문서 공통 미해결).
- [ ] **"Triumph" 점수의 의미**: 압승 보너스? 듀얼 2배분? — 점수 breakdown 스키마 확정([[2026-05-31_vanguard-server-api-spec]]).
- [ ] **강등 연출 노출 여부**: 패배 시 본 팝업을 띄울지(스샷은 승리 케이스) — 기획 결정. 띄운다면 demote 경로 사용.
- [ ] **승급 시리즈/배치 규칙**: 100 도달 즉시 승급인지 승급전 존재인지 — 위키 미표기, 서버 정책 확정.
- [ ] **닫기 UX**: 탭 2회 vs 연출 후 자동 닫힘 vs 확인 버튼 — 기획 확정(현재 탭 2회).

---

> 작성: 2026-06-04 · 선행 코드 확인: `VanguardRankService`(`PointsPerDivision=100`/`NextTierPoints`/`UpdateFromServerAsync`/`ApplyLocalCache`), `EVanguardTier`(그룹=value/100·클수록 높은 랭크·그룹 경계 인코딩 — 헬퍼 식의 근거), `VanguardTierUtil`(그룹 단위 스프라이트·표시명), `VanguardPopupBase`. 전용 티어업 팝업 선례 없음 확인(신규 연출 설계). 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
