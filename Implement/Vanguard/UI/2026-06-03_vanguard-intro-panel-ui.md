# Vanguard 시즌 인트로 패널(VanguardIntroPanel) 구현 종합 문서 (2026-06-03)

## 문서 목적

`VanguardLobbyUI`가 보유한 3패널 중 **인트로 패널(`VanguardIntroPanel`)** — 로비 진입 전 시즌 소개/게이트 화면 — 의 프리팹 + 스크립트를 이 문서만 보고 제작할 수 있도록 정리한다. **Ark의 `ArkIntroPanel` 역할**과 동일하며 그 패턴을 답습한다.

- 표시 요소(요구): **티어별 보상**(아이콘 4 + "더 많이"), **이번 시즌 포대(터렛/유닛, 가로 스크롤)**, **이번 시즌 적(가로 스크롤)**, 가디언 아트, 로어 텍스트, **입장** 버튼 + 시즌 카운트다운.
- 게이팅: **시즌 비활성 → 입장 차단(곧 시작 카운트다운)**, **시즌 활성 → 입장 가능**.
- 짝 문서: [[2026-06-03_vanguard-turret-setup-ui]], [[2026-06-03_vanguard-ingame-battle-ui]], 상위 [[2026-05-29_vanguard-implementation-plan-outgame]]
- `[설계 판단]` = 위키/스샷 미표기 보완.

---

## 0. 결론 먼저 (TL;DR)

| 항목 | 결정 |
|---|---|
| 클래스 | 기존 `VanguardIntroPanel : MonoBehaviour`(스켈레톤) 본문 채움 — `ArkIntroPanel` 미러 |
| 생명주기 | `VanguardLobbyUI`가 `Initialize()`/`OpenPanel()`/`Cleanup()` 호출 (이미 연결됨) |
| 카운트다운 | `ArkIntroPanel.UpdateCountdown()`/`FormatCountdown()` 패턴 복제 (`Update()` 1초 갱신) |
| 시즌 상태 | **신규 `VanguardScheduleService`**(ArkScheduleService 미러) — `IsSeasonActive()`/`GetTimeUntilStart()`/`GetTimeRemaining()` |
| 티어 보상 | `ItemDisplayComponent` 4개 + "더 많이" → `VanguardRankingRewardPanel`/리워드 리스트 팝업 |
| 시즌 터렛 | 가로 ScrollRect + **신규 `VanguardTurretIconSlot`** (`TurretDataSO.spritePath`) |
| 시즌 적 | 가로 ScrollRect + **신규 `VanguardEnemyIconSlot`** + ⓘ → 적 정보 팝업 |
| 신규 스크립트 | `VanguardTurretIconSlot.cs`, `VanguardEnemyIconSlot.cs` (+ `VanguardScheduleService.cs` 데이터측) |
| 게이트 | 입장 = `IsSeasonActive()` 시 interactable, 아니면 비활성 + "곧 시작:HH:MM:SS" |

---

## 1. 진입 / 전환 플로우 (확인된 코드)

`VanguardLobbyUI`(이미 존재, `UIBase`)가 3패널 오케스트레이션:

```csharp
// VanguardLobbyUI.cs (확인)
[SerializeField] private VanguardLobbyPanel  _lobbyPanel;
[SerializeField] private VanguardIntroPanel  _introPanel;
[SerializeField] private VanguardResultPanel _resultPanel;

public override async Task OpenedAsync(object[] param) {
    CacheManagers();
    _lobbyPanel?.Initialize();
    _introPanel?.Initialize();   // ← 본 패널 1회 바인딩
    _resultPanel?.Initialize();
    await SetupAsync();          // enter 분기 → ShowLobby / OpenIntroPanel / OpenResultPanel
}
public void OpenIntroPanel() { ActivateOnly(_introPanel.gameObject); _introPanel.OpenPanel(); }
public void ShowLobby()      { ActivateOnly(_lobbyPanel.gameObject); _lobbyPanel.Refresh(); }
```

전환 흐름:

```
DungeonSelectUI → Show<VanguardLobbyUI>()
  └─ OpenedAsync → SetupAsync (enter 분기)  ※ 현재 [TEST] 블록이 바로 ShowLobby
       ├─ 시즌 활성 + 이미 진입 → ShowLobby()
       ├─ 첫 진입/시즌 안내 → OpenIntroPanel()   ★ 본 패널
       └─ 이전 시즌 보상 → OpenResultPanel()
VanguardIntroPanel.입장(Enter) → VanguardLobbyUI.ShowLobby()
VanguardIntroPanel.뒤로(Back)  → Hide<VanguardLobbyUI>()  (현 스켈레톤 그대로)
```

> ⚠️ `VanguardIntroPanel` 스켈레톤엔 이미 `_enterButton`/`_backButton`/`_titleText`/`_descriptionText`/`_countdownText` 필드 + `OnClickEnter`(TODO)/`OnClickBack`(`Hide<VanguardLobbyUI>`)가 있음. **본 문서는 여기에 보상/터렛/적/게이트를 추가**한다. `OnClickEnter`는 `GetComponentInParent<VanguardLobbyUI>().ShowLobby()` 호출로 채움.

---

## 2. 이미지 상세 분석 (위→아래)

| 영역 | 스샷 | 매핑 |
|---|---|---|
| 타이틀 | `스파크 프로젝트 / 뱅가드` + ⓘ | `_titleText`(로컬라이즈) + 규칙 팝업 버튼. KR 빌드는 Ember→**스파크** 리네임 |
| **티어 보상** | 4 아이콘: 상자 `1` · 주황칩 `12` · 보라 다이아 `450` · 골드 `19000` + `더 많이` | `ItemDisplayComponent` 4개 + `_rewardListButton` |
| **이번 시즌 포대** | 가로 스크롤, 터렛 6+ 아이콘(메크/캐논/…) | ScrollRect(가로) + `VanguardTurretIconSlot` (위키=9종) |
| **이번 시즌 적** | 가로 스크롤, 적 5+ 아이콘 + ⓘ | ScrollRect(가로) + `VanguardEnemyIconSlot` + 적 정보 팝업 |
| 가디언 아트 | 의자에 앉은 메크 + 홀로그램 사이드 패널 | 정적 Image/Animator (연출용) |
| 로어 | "현실에 머무는 지구 연합 정부…최후의 뱅가드가 됩니다." | `_descriptionText`(로컬라이즈) |
| 입장 | 녹색 `입장` 버튼 | `_enterButton` (게이트 대상) |
| 카운트다운 | `곧 시작: 18시간 35분 37초` | `_countdownText` (시즌 시작 전 = "곧 시작") |
| 뒤로 | 좌하단 ◁ | `_backButton` |

좌표 참고: 원본 1080×2340(표시 923×2000, ×1.17). 티어보상 행 y≈360–460, 포대 행 y≈540–640, 적 행 y≈760–840(원본 기준).

---

## 3. 위키 근거 (Fandom V0.13.7)

> 출처: [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard). 인트로 패널에 직접 영향하는 항목만 정리(요약).

| 항목 | 내용 | 패널 반영 |
|---|---|---|
| 레벨 게이트 | **유저 Lv45 공개, Lv50부터 입장 가능** | 입장 버튼 활성 조건에 레벨 게이트 추가 |
| 주간 일정 | 매주 **화 00:00 UTC ~ 수 24:00 UTC** | 카운트다운 = 다음 화 00:00 UTC까지("곧 시작") / 진행 중엔 종료까지 |
| 시즌 포대 | **이벤트 페이즈마다 9터렛 지정**. 칩 뽑기는 그 터렛의 전용+범용 칩만 | "이번 시즌 포대" = 9종 가로 스크롤 |
| 시즌 적 | **라운드당 일반 6 + 정예 2**. "Set: Enemies"가 정예/일반 적 정보 표시 | "이번 시즌 적" 가로 스크롤 + ⓘ 정보 팝업 |
| 티어 보상 | Tier Milestones(섹션 4): Ember Mark/Glory Key/Diamond/Gold 등 | 4 아이콘 프리뷰 + "더 많이"=전체 보상표 |
| 적 정보 | "Event Info & Rules → Set: Enemies" | "이번 시즌 적" ⓘ → 적 도감 팝업 |

> 스샷 4 아이콘(상자1/주황12/다이아450/골드19000)은 **티어 보상 프리뷰**. 위키 Tier Milestones는 Ember Mark·Glory Key·Diamond·Gold·Etching Solvent 등 다수 → "더 많이"로 전체 표 노출.

---

## 4. 재사용 자산 분석

| 자산 | 경로 | 재사용 방식 | 핵심 API |
|---|---|---|---|
| **ArkIntroPanel** | `UI/Ark/Component/ArkIntroPanel.cs` | **로직 복제** (카운트다운/보상/Open연출) | `Update()→UpdateCountdown()` · `FormatCountdown(TimeSpan)` · `SetupRewardDisplay()` · `OpenRulePopup()`/`OpenRewardListPopup()` · `PlayOpenUI()`(딜레이 후 SetActive) |
| **ItemDisplayComponent** | `UI/Components/ItemDisplayComponent.cs` | **그대로** (티어 보상 4 아이콘) | `SetupItem(ECurrencyType, int)` / `SetupItem(type, amount, CurrencyDataSO)` · `_itemIcon`/`_itemCountText`/`_itemRarityBackground` |
| **ArkScheduleService** | `Core/Managers/ArkServices/ArkScheduleService.cs` | **미러 → `VanguardScheduleService`** | `IsArkScheduleActive()` · `GetTimeUntilStart()` · `GetTimeRemaining()` (ServerTime 기반, ISO8601 파싱) |
| **VanguardSeasonService** | `Core/Managers/Vanguard/VanguardSeasonService.cs` | 시즌 메타 | `CurrentSeasonData`(start/end) · `EnterSeasonAsync()` |
| **TurretDataSO** | `SOs/SO/DataSheet/TurretDataSO.cs` | 터렛 아이콘 | `spritePath` → `ResourceManager.LoadResource<Sprite>(path)` |
| **EnemyDataSO** | `SOs/SO/DataSheet/EnemyDataSO.cs` | 적 아이콘 | ⚠️ `splinePath`만 있음(아이콘 경로 아님) → **아이콘 경로 매핑 필요**(§8) |
| **VanguardRankingRewardDataSO** | `SOs/SO/DataSheet/VanguardRankingRewardDataSO.cs` | "더 많이" 전체 보상 | `rank`/`currency1~4Type`/`rank1~4Count`/`rewardFrameId`/`minTier` |
| **VanguardRankingRewardSlot/Panel** | `UI/Vanguard/Component/VanguardRankingRewardSlot.cs` | "더 많이" 팝업 내용 | `Init(VanguardRankingRewardDataSO, maxRank, myRank)` |
| **RulePanelPopup** | (VanguardLobbyPanel에서 사용) | ⓘ 규칙 | `Show<RulePanelPopup>()` |

### 신규 컴포넌트 (2개)

- `VanguardTurretIconSlot.cs` — 가로 스크롤 1칸(터렛 아이콘[+레어/이름]).
- `VanguardEnemyIconSlot.cs` — 가로 스크롤 1칸(적 아이콘[+정예 표식]).

---

## 5. 게이팅 로직 (시즌 비활성/활성)

```
VanguardScheduleService.IsSeasonActive()  &&  userLevel >= 50   →  입장 가능
그 외:
  - 시즌 시작 전:  _enterButton.interactable = false; "곧 시작: " + GetTimeUntilStart()
  - 시즌 종료/대기: _enterButton.interactable = false; 안내 텍스트
  - 레벨 미달:    _enterButton.interactable = false; "Lv50 필요" 토스트/표기
```

- `ArkIntroPanel`은 입장 버튼이 없고 게이팅이 상위(로비 플로우)에 있으나, **본 패널은 입장 버튼을 직접 게이팅**한다(요구사항). 카운트다운 텍스트는 Ark의 `GetTimeUntilStart→GetTimeRemaining` fallback 그대로.
- 레벨 게이트(Lv50)는 위키 근거. `ContentUnlockManager`/유저 레벨 조회로 판정(프로젝트 표준 경로 사용).

---

## 6. UI 프리팹 구조 (전체 하이어라키)

> 기존 `VanguardIntroPanel.prefab`(`3_Prefabs/UI/Vanguard/`) 내부를 채운다. 루트에 `VanguardIntroPanel.cs`. `VanguardLobbyUI` 프리팹의 `_introPanel` 슬롯에 연결돼 있음.

```
VanguardIntroPanel (루트, ▶ VanguardIntroPanel.cs)
├─ Top
│  ├─ TitleText ("스파크 프로젝트 / 뱅가드")          → _titleText
│  └─ Btn_Info (ⓘ)                                    → _infoButton (→ RulePanelPopup)
│
├─ TierRewardSection
│  ├─ Label ("티어 보상")
│  ├─ RewardRow (HorizontalLayoutGroup)
│  │  └─ [ItemDisplayComponent x4]                     → _itemDisplayComponents (List)
│  └─ Btn_More ("더 많이")                             → _rewardListButton (→ 보상 전체 팝업)
│
├─ SeasonTurretSection
│  ├─ Label ("이번 시즌 포대")
│  └─ ScrollRect (horizontal=true, vertical=false)     → _turretScrollRect
│     └─ Viewport/Content (HorizontalLayoutGroup + ContentSizeFitter) → _turretContent
│        └─ (런타임) VanguardTurretIconSlot xN          → _turretIconSlotPrefab
│
├─ SeasonEnemySection
│  ├─ Label ("이번 시즌 적") + Btn_EnemyInfo (ⓘ)        → _enemyInfoButton
│  └─ ScrollRect (horizontal)                          → _enemyScrollRect
│     └─ Viewport/Content (HorizontalLayoutGroup)      → _enemyContent
│        └─ (런타임) VanguardEnemyIconSlot xN           → _enemyIconSlotPrefab
│
├─ GuardianArt (Image/Animator + 사이드 홀로 패널)     (정적 연출)
├─ DescriptionText (로어)                              → _descriptionText
│
└─ Bottom
   ├─ Btn_Enter ("입장")                               → _enterButton
   ├─ CountdownText ("곧 시작: …")                      → _countdownText
   └─ Btn_Back (◁)                                     → _backButton
```

### 가로 스크롤 셋업 (포대/적 공통)

- `ScrollRect`: `horizontal=true`, `vertical=false`, Movement=Clamped.
- Content: `HorizontalLayoutGroup`(spacing/childAlignment) + `ContentSizeFitter`(Horizontal=PreferredSize).
- 슬롯은 런타임 `Instantiate`(소량이라 풀링 불필요) 또는 자식 토글(ArkIntroPanel `_bannedUnitsContainer` 패턴).

---

## 7. 스크립트 설계

### 7-1. `VanguardIntroPanel.cs` (스켈레톤 확장 — 참조 구현)

```csharp
using System;
using System.Collections.Generic;
using Cysharp.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

/// <summary>
/// Vanguard 시즌 인트로 패널 (ArkIntroPanel 대응). 티어보상/시즌포대/시즌적/카운트다운 + 입장 게이트.
/// 생명주기는 VanguardLobbyUI가 호출: Initialize / OpenPanel / Cleanup.
/// </summary>
public class VanguardIntroPanel : MonoBehaviour
{
    #region Serialized
    [Header("Top")]
    [SerializeField] private TextMeshProUGUI _titleText;
    [SerializeField] private Button _infoButton;

    [Header("티어 보상")]
    [SerializeField] private List<ItemDisplayComponent> _itemDisplayComponents; // 4개
    [SerializeField] private Button _rewardListButton; // "더 많이"

    [Header("이번 시즌 포대 (가로 스크롤)")]
    [SerializeField] private ScrollRect _turretScrollRect;
    [SerializeField] private Transform _turretContent;
    [SerializeField] private VanguardTurretIconSlot _turretIconSlotPrefab;

    [Header("이번 시즌 적 (가로 스크롤)")]
    [SerializeField] private ScrollRect _enemyScrollRect;
    [SerializeField] private Transform _enemyContent;
    [SerializeField] private VanguardEnemyIconSlot _enemyIconSlotPrefab;
    [SerializeField] private Button _enemyInfoButton;

    [Header("Texts / Buttons")]
    [SerializeField] private TextMeshProUGUI _descriptionText;
    [SerializeField] private TextMeshProUGUI _countdownText;
    [SerializeField] private Button _enterButton;
    [SerializeField] private Button _backButton;

    [Header("[TEST]")]
    [SerializeField] private bool _useTestData = true;
    #endregion

    private UIManager _uiManager;
    private VanguardManager _vanguardManager;
    private readonly List<GameObject> _turretSlots = new();
    private readonly List<GameObject> _enemySlots = new();
    private int _lastCountdownSeconds = -1;
    private bool _bound;

    public void Initialize()
    {
        _uiManager = Managers.Instance.GetManager<UIManager>();
        _vanguardManager = Managers.Instance.GetManager<VanguardManager>();
        if (_bound) return;
        _bound = true;
        _enterButton.onClick.AddListener(OnClickEnter);
        _backButton.onClick.AddListener(OnClickBack);
        _infoButton?.onClick.AddListener(() => _uiManager.Show<RulePanelPopup>());
        _rewardListButton?.onClick.AddListener(OnClickRewardList);
        _enemyInfoButton?.onClick.AddListener(OnClickEnemyInfo);
    }

    public void OpenPanel()
    {
        _lastCountdownSeconds = -1;
        if (_titleText != null) _titleText.text = LocalizationManager.GetLocalizedText("vanguard_title");
        if (_descriptionText != null) _descriptionText.text = LocalizationManager.GetLocalizedText("vanguard_intro_desc");
        SetupTierRewards();
        SetupSeasonTurrets();
        SetupSeasonEnemies();
        RefreshGate();
    }

    public void Cleanup()
    {
        ClearSlots(_turretSlots);
        ClearSlots(_enemySlots);
    }

    private void Update()
    {
        UpdateCountdown();   // ArkIntroPanel.UpdateCountdown 복제 + 게이트 갱신
    }

    // ─────────── 티어 보상 (ArkIntroPanel.SetupRewardDisplay 복제) ───────────
    private void SetupTierRewards()
    {
        foreach (var it in _itemDisplayComponents) it?.gameObject.SetActive(false);
        // 대표 보상 4종 (서버/SO 합산). 미구현 단계는 테스트 더미.
        var preview = _vanguardManager?.RankService?.GetTierRewardPreview()  // TODO: provider
                      ?? GetTestRewardPreview();
        int i = 0;
        foreach (var kv in preview)
        {
            if (i >= _itemDisplayComponents.Count) break;
            _itemDisplayComponents[i].gameObject.SetActive(true);
            _itemDisplayComponents[i].SetupItem(kv.Key, kv.Value);
            i++;
        }
    }

    // ─────────── 시즌 포대 (9종 가로 스크롤) ───────────
    private void SetupSeasonTurrets()
    {
        ClearSlots(_turretSlots);
        var ids = _vanguardManager?.LoadoutService?.GetSeasonTurretIds()  // TODO: 미구현
                  ?? GetTestTurretIds();
        foreach (var id in ids)
        {
            var slot = Instantiate(_turretIconSlotPrefab, _turretContent);
            slot.Setup(id);
            _turretSlots.Add(slot.gameObject);
        }
    }

    // ─────────── 시즌 적 (가로 스크롤) ───────────
    private void SetupSeasonEnemies()
    {
        ClearSlots(_enemySlots);
        var enemies = _vanguardManager?.SeasonService?.GetSeasonEnemyIds()  // TODO: 미구현
                      ?? GetTestEnemyIds();
        foreach (var id in enemies)
        {
            var slot = Instantiate(_enemyIconSlotPrefab, _enemyContent);
            slot.Setup(id);
            _enemySlots.Add(slot.gameObject);
        }
    }

    // ─────────── 카운트다운 + 게이트 (ArkIntroPanel 패턴) ───────────
    private void UpdateCountdown()
    {
        var schedule = _vanguardManager?.ScheduleService; // TODO: VanguardScheduleService
        if (_countdownText == null || schedule == null) return;

        TimeSpan remain = schedule.GetTimeUntilStart();
        bool beforeStart = remain > TimeSpan.Zero;
        if (!beforeStart) remain = schedule.GetTimeRemaining();

        int sec = (int)remain.TotalSeconds;
        if (sec == _lastCountdownSeconds) return;
        _lastCountdownSeconds = sec;

        string key = beforeStart ? "vanguard_starts_in" : "vanguard_ends_in";
        _countdownText.text = LocalizationManager.GetLocalizedTextFormat(key, FormatCountdown(remain));
        RefreshGate();
    }

    private void RefreshGate()
    {
        var schedule = _vanguardManager?.ScheduleService;
        bool active = schedule != null && schedule.IsSeasonActive();
        bool levelOk = IsUserLevelEnough(); // Lv50 (위키)
        if (_enterButton != null) _enterButton.interactable = active && levelOk;
    }

    private void OnClickEnter()
    {
        var lobby = GetComponentInParent<VanguardLobbyUI>();
        lobby?.ShowLobby();   // 인트로 → 로비
    }
    private void OnClickBack() => _uiManager?.Hide<VanguardLobbyUI>();
    private void OnClickRewardList() => _uiManager?.Show<VanguardRankingInfoPopup>(); // or 보상 전체 팝업
    private void OnClickEnemyInfo()  => _uiManager?.Show<RulePanelPopup>();           // 적 도감 (TODO 전용)

    private void ClearSlots(List<GameObject> list)
    {
        foreach (var go in list) if (go != null) Destroy(go);
        list.Clear();
    }

    private string FormatCountdown(TimeSpan t) { /* ArkIntroPanel.FormatCountdown 복제 (days/hours/minutes_seconds 키) */ return ""; }
    private bool IsUserLevelEnough() { /* ContentUnlockManager/유저레벨 >= 50 */ return true; }

    // ── 테스트 더미 (서버/SO 연결 전) ──
    private Dictionary<ECurrencyType,int> GetTestRewardPreview() => new() { /* 대표 4종 */ };
    private List<int> GetTestTurretIds() => new();
    private List<int> GetTestEnemyIds()  => new();
}
```

### 7-2. `VanguardTurretIconSlot.cs` (신규)

```csharp
using UnityEngine;
using UnityEngine.UI;

/// <summary> 시즌 포대 가로 스크롤 1칸. TurretDataSO.spritePath로 아이콘 로드. </summary>
public class VanguardTurretIconSlot : MonoBehaviour
{
    [SerializeField] private Image _icon;
    [SerializeField] private Image _rarityFrame; // 선택
    [SerializeField] private Button _button;     // 선택: 상세

    public void Setup(int turretId)
    {
        var rm = Managers.Instance.GetManager<ResourceManager>();
        var data = /* TurretData 조회: ResourceManager/DataManager로 TurretDataSO 획득 */ ;
        if (data != null && _icon != null)
            _icon.sprite = rm.LoadResource<Sprite>(data.spritePath);
        // _rarityFrame.sprite = ResourceUtility... (있으면)
    }
}
```

### 7-3. `VanguardEnemyIconSlot.cs` (신규)

```csharp
using UnityEngine;
using UnityEngine.UI;

/// <summary> 시즌 적 가로 스크롤 1칸. EnemyDataSO 아이콘(경로 매핑 §8) + 정예 표식. </summary>
public class VanguardEnemyIconSlot : MonoBehaviour
{
    [SerializeField] private Image _icon;
    [SerializeField] private GameObject _eliteBadge; // 정예 표식

    public void Setup(int enemyId, bool isElite = false)
    {
        var rm = Managers.Instance.GetManager<ResourceManager>();
        // EnemyDataSO엔 splinePath만 있어 아이콘 경로 매핑 필요(§8)
        string iconPath = VanguardEnemyIconMap.GetIconPath(enemyId); // TODO
        if (_icon != null && !string.IsNullOrEmpty(iconPath))
            _icon.sprite = rm.LoadResource<Sprite>(iconPath);
        if (_eliteBadge != null) _eliteBadge.SetActive(isElite);
    }
}
```

---

## 8. 데이터 연동 + 가정/TODO

| 데이터 | 상태 | 처리 |
|---|---|---|
| 시즌 활성/카운트다운 | ⚠️ 미구현 | **신규 `VanguardScheduleService`** (`ArkScheduleService` 미러): `IsSeasonActive()`/`GetTimeUntilStart()`/`GetTimeRemaining()`. `VanguardManager.ScheduleService`로 노출. 주간(화00:00~수24:00 UTC) 계산 |
| 시즌 9터렛 | ⚠️ 미구현 | `VanguardLoadoutService.GetSeasonTurretIds()` 추가(서버 차팅 우선, [[2026-05-29_vanguard-implementation-plan-outgame]] 3장). 미구현 단계 테스트 더미 |
| 시즌 적 | ⚠️ 미구현 | `VanguardSeasonService.GetSeasonEnemyIds()` 추가(라운드 일반6+정예2 풀) |
| 적 아이콘 경로 | ⚠️ `EnemyDataSO`에 아이콘 경로 없음(`splinePath`만) | `VanguardEnemyIconMap`(enemyId→spritePath) 또는 `EnemyDataSO`에 `iconPath` 추가. ⚠️ DataSheet SO 직접수정 금지 → **Parser/별도 맵** (CLAUDE.md) |
| 티어 보상 프리뷰 | 부분(`VanguardRankingRewardDataSO` 존재) | 대표 4종 합산 provider. "더 많이"=전체 표(`VanguardRankingRewardSlot`) |
| 유저 레벨(Lv50) | 표준 경로 | `ContentUnlockManager`/유저 레벨로 게이트 |

### CLAUDE.md 준수

- 매니저: `Managers.Instance.GetManager<T>()` 만. 시간: `ServerTimeManager`(스케줄). `DateTime.Now` 금지.
- 텍스트 로컬라이즈(`vanguard_title`/`vanguard_intro_desc`/`vanguard_starts_in`/`vanguard_ends_in` + Ark 공용 `shop_countdown_*`).
- DataSheet SO 직접수정 금지 → 적 아이콘은 별도 맵/Parser.
- `async void` 금지 / 이벤트 `Cleanup` 해제(본 패널은 onClick만이라 자동 소멸).

---

## 9. 단계별 구현 절차 (체크리스트)

**A. 데이터(선행 또는 더미)**

1. [ ] `VanguardScheduleService.cs` 추가(ArkScheduleService 미러) + `VanguardManager.ScheduleService` 노출.
2. [ ] `VanguardLoadoutService.GetSeasonTurretIds()` / `VanguardSeasonService.GetSeasonEnemyIds()` 추가(미구현 시 더미).
3. [ ] 적 아이콘 매핑(`VanguardEnemyIconMap` 또는 EnemyData Parser).

**B. 스크립트**

4. [ ] `VanguardTurretIconSlot.cs` / `VanguardEnemyIconSlot.cs` 작성(7-2/7-3).
5. [ ] `VanguardIntroPanel.cs` 본문 확장(7-1). 빌드-그린.

**C. 프리팹** (`VanguardIntroPanel.prefab` 편집)

6. [ ] 6장 하이어라키대로 섹션 구성(Top/TierReward/SeasonTurret/SeasonEnemy/Guardian/Desc/Bottom).
7. [ ] 티어보상: `ItemDisplayComponent` 4개 배치 → `_itemDisplayComponents` + `_rewardListButton`.
8. [ ] 시즌 포대: 가로 ScrollRect + Content(HorizontalLayoutGroup) → `_turretScrollRect`/`_turretContent`/`_turretIconSlotPrefab`.
9. [ ] 시즌 적: 동일 + `_enemyInfoButton`.
10. [ ] 텍스트/버튼 연결: `_titleText`/`_descriptionText`/`_countdownText`/`_enterButton`/`_backButton`/`_infoButton`.
11. [ ] `VanguardLobbyUI` 프리팹의 `_introPanel` 슬롯에 본 패널 연결 확인(이미 연결).

**D. 게이트/연동**

12. [ ] `SetupAsync`(VanguardLobbyUI)에서 시즌 미진입/첫진입 시 `OpenIntroPanel()` 분기 연결.
13. [ ] 입장 게이트: `IsSeasonActive() && Lv50` → interactable.
14. [ ] Localization 키 추가.

---

## 10. 검증 체크리스트

- [ ] 시즌 **시작 전**: 입장 비활성 + "곧 시작:HH시간MM분SS초" 카운트다운 1초 갱신.
- [ ] 시즌 **진행 중**: 입장 활성, 카운트다운=종료까지. 입장 → `ShowLobby()` 로 로비 전환.
- [ ] **Lv50 미만**: 입장 비활성(+안내).
- [ ] 티어 보상 4 아이콘 정상(아이콘/수량), "더 많이" → 전체 보상 팝업.
- [ ] 시즌 포대 가로 스크롤 9종 표시/스크롤.
- [ ] 시즌 적 가로 스크롤 표시 + 정예 표식, ⓘ → 적 정보.
- [ ] 타이틀/로어 로컬라이즈, ⓘ → 규칙 팝업.
- [ ] 뒤로 → `Hide<VanguardLobbyUI>()`.
- [ ] `Cleanup()`에서 슬롯 정리(누수 없음).
- [ ] CLAUDE.md 준수(GetManager/ServerTime/로컬라이즈/DataSheet 비수정/async void 없음).

---

## 11. 미해결 / 확인 필요

**위키로 확정**

- [x] 레벨 게이트 Lv45 공개 / Lv50 입장. 주간 화00:00~수24:00 UTC. 9터렛/페이즈. 적 일반6+정예2.

**확인 필요**

- [ ] **시즌 터렛/적 데이터 소스**: 서버 차팅 스키마(turretIds/enemyIds) 확정 → [[2026-05-31_vanguard-server-api-spec]] 동기화.
- [ ] **적 아이콘 경로**: `EnemyDataSO`에 아이콘 필드 신설 vs 별도 맵 — 기존 적 도감 UI가 있으면 그 경로 재사용.
- [ ] **티어 보상 프리뷰 4종 선정 규칙**: 어떤 4종을 대표로 보일지(상위 티어 기준?) 기획 확정.
- [ ] **"더 많이" 팝업**: `VanguardRankingRewardPanel` 전용 팝업 신설 vs `VanguardRankingInfoPopup` 재사용.
- [ ] **적 정보 ⓘ**: 전용 적 도감 팝업 필요 여부(위키 "Set: Enemies").
- [ ] **Intro 노출 조건**: 첫 진입만 vs 매 시즌 vs 항상(시즌 전 대기 화면) — `VanguardLobbyUI.SetupAsync` 분기 기획 확정.

---

> 작성: 2026-06-03 · 선행 코드 확인: `VanguardIntroPanel`(스켈레톤)/`VanguardLobbyUI`(3패널 오케스트레이션)/`ArkIntroPanel`(카운트다운·보상·Open연출)/`ItemDisplayComponent`/`ArkScheduleService`/`VanguardSeasonService`/`TurretDataSO.spritePath`/`EnemyDataSO`/`VanguardRankingRewardDataSO`. 위키 V0.13.7(레벨/주간/9터렛/6+2적/티어보상) 반영. 본 문서 단독으로 프리팹+스크립트 제작 가능하도록 구성.
