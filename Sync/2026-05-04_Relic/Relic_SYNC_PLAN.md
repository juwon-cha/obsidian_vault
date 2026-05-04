# Relic(유물) 시스템 Sync 계획 - BunkerDefense → WiggleDefender

> 작성일: 2026-05-04
> 검토일: 2026-05-04 (Phase 2 실제 코드 대조 검증)
> 소스: BunkerDefense (worktree: temp-bunker / feature/relic_skill)
> 타겟: WiggleDefender (branch: feature/juwon/RelicSystem)

---

## 목차
1. [시스템 개요](#1-시스템-개요)
2. [핵심 차이점 및 변환 규칙](#2-핵심-차이점-및-변환-규칙)
3. [신규 파일 목록 (직접 이식)](#3-신규-파일-목록-직접-이식)
4. [기존 파일 수정 목록](#4-기존-파일-수정-목록)
5. [Sync 실행 순서 (의존성 역순)](#5-sync-실행-순서-의존성-역순)
6. [파일별 변환 가이드 (핵심 파일)](#6-파일별-변환-가이드-핵심-파일)
7. [누락 검증 체크리스트](#7-누락-검증-체크리스트)
8. [BLOCKER 목록](#8-blocker-목록)

---

## 1. 시스템 개요

Relic(유물) 시스템은 수집/장착/강화로 전투력을 증강하는 후기 콘텐츠.
**4개 슬롯 장착**, **등급 (Epic/Legendary/Mythic)**, **랭크업(1~10)**, **강화(0~100레벨)**, **뽑기(가챠)**, **신화 전용 스킬**로 구성.

```
GachaManager (뽑기 담당 - BD 구조)
├── InitializeRelicGacha()
├── DrawRelics(count), DrawRelicAdGachaAsync()
├── RelicGachaProbabilityDataSource (lazy, 확률 팝업용)
└── RelicDropTableData, RelicWeightTableData, RelicRotateTableData

RelicManager (핵심 매니저)
├── SaveDataManager → ESaveDataType.Relics
├── BalanceDataManager → RELIC_* 10개 테이블
├── DamageCalculationManager → 보너스 반영 (partial)
└── CurrencyManager → 재화 조각/뽑기 티켓

UI
├── RelicMainUI (창고 + 장착 탭) — Panel/
├── RelicUpgradeUI (강화/랭크업) — Upgrade/
├── RelicGachaPopup (뽑기 연출)
└── GachaUI.cs (BD 기존 뽑기 UI, 유물 뽑기 패널 포함) [수정]

신화 스킬 (유닛별 partial/override)
├── Archon → ZeusRapidFire
├── DrFrost → DrFrostBlizzardGrowth
├── Marauder → MarauderShotgunBlast
├── Templer → TemplerMultiHit
├── Turret → TurretDelayedExplosion
├── Ninja → NinjaMythic
├── AirMan → AirManWindExtra
├── Thor → ThorElectricPull
├── Vessel → VesselDefensiveShield
├── Carrier → CarrierSpecialInterceptor
└── Dragoon → DragoonLaserBind
```

---

## 2. 핵심 차이점 및 변환 규칙

### 2-1. 매니저 접근 패턴

| 항목 | BunkerDefense | WiggleDefender |
|------|---------------|----------------|
| 매니저 접근 | `ServiceAccessor.Get<T>()` | `Managers.Instance.GetManager<T>()` |
| DI 접근 | `MainInstaller.TryResolve<T>()` | `Managers.Instance.GetManager<T>()` |
| 매니저 베이스 | `BaseService` (순수 C#) | `BaseManager` (MonoBehaviour 기반) |
| 매니저 등록 | `ServiceAccessor` + geuneda DI | `MANAGER_DEFINITIONS[]` 배열 (Managers.cs) |

**변환 규칙:**
```csharp
// Before (BunkerDefense)
ServiceAccessor.Get<RelicManager>()
MainInstaller.TryResolve<IMessageBrokerService>()

// After (WiggleDefender) — BaseManager 상속 내부
GetManager<RelicManager>()                    // 단축형 (권장)
Managers.Instance.GetManager<RelicManager>()  // 외부 접근형

// BaseManager 외부 (UnitController 등 MonoBehaviour)
Managers.Instance?.GetManager<RelicManager>()
```

### 2-2. 이벤트 시스템

| 항목 | BunkerDefense | WiggleDefender |
|------|---------------|----------------|
| 발행 | `MessageBroker.PublishSafe(new RelicAcquiredMessage())` | `EventManager.Dispatch<RelicEventData>(GameEventType.RelicAcquired, data)` |
| 구독 | `_messageBroker.Subscribe<RelicAcquiredMessage>(Handler)` | `EventManager.Subscribe<RelicEventData>(GameEventType.RelicAcquired, Handler)` |
| 해제 | `_subscription.Dispose()` | `EventManager.Unsubscribe<T>(GameEventType, Handler)` — `Cleanup()` 또는 `OnClosed()`에서 |

**BD의 IMessage 구현 클래스 5개 → WD BaseEventData 상속으로 변환:**

| BD (RelicManager 하단 동봉) | WD 변환 |
|---------------------------|---------|
| `class RelicAcquiredMessage : IMessage` | `class RelicEventData : BaseEventData { int RelicId; ERelicGrade Grade; }` |
| `class RelicEnhancedMessage : IMessage` | 동일 `RelicEventData` 재사용 |
| `class RelicRankedUpMessage : IMessage` | 동일 `RelicEventData` 재사용 |
| `class RelicEquippedMessage : IMessage` | 동일 `RelicEventData` 재사용 |
| `class RelicUnequippedMessage : IMessage` | 동일 `RelicEventData` 재사용 |
| (RelicGachaDrawn은 별도 필요시) | `class RelicGachaDrawnEventData : BaseEventData { List<RelicGachaResult> Results; }` |

**추가할 GameEventType 값:**
```csharp
RelicAcquired,       // 유물 획득 (뽑기/해금)
RelicEnhanced,       // 유물 강화
RelicRankedUp,       // 유물 랭크업
RelicEquipped,       // 유물 장착
RelicUnequipped,     // 유물 해제
RelicGachaDrawn,     // 유물 뽑기 실행
```

### 2-3. UI 베이스 클래스

BunkerDefense의 `UIBase` → WiggleDefender의 `UIBase`로 교체.
- `Show<T>()` / `Hide<T>()` API는 동일.
- `Opened(params object[])` / `Closed(params object[])` 콜백 동일.
- BD의 `ServiceAccessor.Get<UIManager>()` → WD의 `Managers.Instance.GetManager<UIManager>()`

### 2-4. 매니저 등록 방법

```csharp
// WiggleDefender Assets/_Project/1_Scripts/Core/Managers/Managers.cs
// MANAGER_DEFINITIONS 배열에 추가 (ChipEffectManager(333) 바로 다음)
new ManagerDefinition(typeof(RelicManager), 334, "Lobby", true, true), // 유물 시스템 매니저
```

> 검증됨: WD priority 334에는 PresetManager, RankingProfileSaveManager, TreasureBoxManager, PatrolManager가 공존. 동일 priority 허용.

### 2-5. SaveData 저장 패턴

```csharp
await saveDataManager.LoadDataAsync<T>(ESaveDataType.Relics)
await saveDataManager.SaveDataAsync(ESaveDataType.Relics, data)
```

**[수정] SaveDataTypes.Relics — WD에 없음. 반드시 추가 필요.**

WD `SaveDataTypes.cs`에 추가할 내용:
```csharp
// ESaveDataType enum에 추가 (BurgerPyramid 다음)
Relics,        // 유물 시스템 데이터
RelicGacha,    // 유물 뽑기 천장/보장 데이터

// FirebaseKeys 클래스에 추가
public const string RELICS = "relics";
public const string RELIC_GACHA = "relicgacha";
```

BD SaveDataTypes.cs에 이미 정의된 클래스 (그대로 복사):
```csharp
// BD line 3394~3396
public class RelicSystemSaveData
{
    public List<RelicSaveData> playerRelics = new List<RelicSaveData>();
}
```

### 2-6. [수정] RelicGachaService.cs — BD에 없음

기존 계획에 RelicGachaService.cs 별도 파일이 있다고 명시했으나, **BD에는 이 파일이 없다.**
Relic 가챠 로직은 **GachaManager.cs** 에 통합되어 있음.

구조 요약:
- `GachaManager.InitializeRelicGacha()` — SO에서 테이블 파싱
- `GachaManager.DrawRelics(count)` / `DrawRelicAdGachaAsync()` — 실제 뽑기
- `GachaManager.CanRelicGacha(count)` — 비용 확인
- `GachaManager.GetRelicGachaProbabilityDataSource()` — 확률 팝업용 데이터
- **WD도 GachaManager에 Relic 가챠 메서드를 추가하는 방식으로 이식.**

### 2-7. [수정] ECurrencyType 충돌 확인 결과

BD의 Relic 재화 번호(689~1099) vs WD 기존 값 분석:

| 번호 범위 | BD Relic 재화 | WD 충돌 여부 |
|-----------|--------------|-------------|
| 689~721 | RelicEpic_piece1001~1011, RelicLegend~, RelicMythic~ | **충돌 없음** (WD에 Relic 재화 없음) |
| 729~730 | Relic_Gacha_ticket, Relicbox_Mityic_0 | **충돌 없음** |
| 1093~1099 | RelicUpgradeCurrency, RelicRankupCurrency_*, Relicbox_* | **충돌** ⚠️ |

**충돌 상세 (1093~1099 범위):**

| 번호 | BD Relic 재화 | WD 기존 재화 |
|------|--------------|-------------|
| 1093 | `RelicUpgradeCurrency` | `airman_transcend_a` |
| 1094 | `RelicRankupCurrency_Epic` | `ninja_transcend_a` |
| 1095 | `RelicRankupCurrency_Legendary` | `RandomEquipment1_11` |
| 1096 | `RelicRankupCurrency_Mythic` | `RandomEquipment1_12` |
| 1097 | `Relicbox_Epic_1` | `RandomEquipment1_13` |
| 1098 | `Relic_piecebox_Epic` | `RandomEquipment1_14` |
| 1099 | `Relicbox_Legendary_1` | `RandomEquipment2_11` |

**[결론] 1093~1099 범위 7개 항목 충돌 → WD 기존 값 유지, Relic 재화를 1187부터 재배정.**

WD ECurrencyType.cs 현재 마지막 값: `weapon_transcend_h = 1186`

```csharp
// WD ECurrencyType.cs 1186 다음에 추가 (충돌 없는 번호부터)
// === Relic 재화 ===
// 조각 재화 (689~730: BD와 동일 — WD에 해당 번호 없으므로 그대로 사용 가능)
RelicEpic_piece1001 = 689,
RelicEpic_piece1002 = 690,
// ... (1001~1011)
RelicLegend_piece1001 = 700,
// ... (1001~1011)
RelicMythic_piece1001 = 711,
// ... (1001~1011)
Relic_Gacha_ticket = 729,
Relicbox_Mityic_0 = 730,

// 업그레이드/랭크업/상자 재화 (1093~1099 충돌 → 1187부터 재배정)
RelicUpgradeCurrency = 1187,
RelicRankupCurrency_Epic = 1188,
RelicRankupCurrency_Legendary = 1189,
RelicRankupCurrency_Mythic = 1190,
Relicbox_Epic_1 = 1191,
Relic_piecebox_Epic = 1192,
Relicbox_Legendary_1 = 1193,
```

> **주의**: 689~730 범위는 WD에 사용 중인 항목이 없으므로 BD 번호 그대로 이식 가능.
> 단, GoogleSheets DataSheet의 숫자값도 WD에 맞춰 업데이트 필요 (BLOCKER-6).

### 2-8. [수정] RedDotManager 노드 경로

BD RedDotManager에서 실제 확인된 Relic 노드 경로:
```
"Lobby.Upgrade.Unit.Relic"   ← 실제 BD 코드 (기존 계획 "Lobby.Relic" 와 다름)
```

BD RedDotManager 구독 메시지:
```csharp
_messageBroker.Subscribe<RelicAcquiredMessage>(OnRelicChangedForRedDot);
_messageBroker.Subscribe<RelicEnhancedMessage>(OnRelicChangedForRedDot);
_messageBroker.Subscribe<RelicRankedUpMessage>(OnRelicChangedForRedDot);
```

WD 변환 (노드 경로 수정 + EventManager 전환):
```csharp
// WD RedDotManager.cs에서:
EventManager.Subscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicChangedForRedDot);
EventManager.Subscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicChangedForRedDot);
EventManager.Subscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicChangedForRedDot);

// Cleanup에서:
EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicChangedForRedDot);
EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicChangedForRedDot);
EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicChangedForRedDot);

// EnsureEssentialNodes() 튜플 배열에 추가:
("Lobby.Upgrade.Unit.Relic", "Lobby.Upgrade.Unit", "유물"),
```

BD의 `CheckUnitUpgradeAvailability()` 내 유물 체크 로직 (RelicManager API 사용):
```csharp
const string relicNodeId = "Lobby.Upgrade.Unit.Relic";
var relicManager = Managers.Instance?.GetManager<RelicManager>();
if (relicManager != null && relicManager.IsInitialized)
{
    bool canRelicAny = false;
    var allRelics = relicManager.GetAllRelicData();
    foreach (var rd in allRelics)
    {
        bool canUnlock = !relicManager.IsOwned(rd.id) && relicManager.CanAffordUnlock(rd.id);
        bool canRankUp  = relicManager.IsOwned(rd.id) && relicManager.CanRankUp(rd.id);
        bool canLevelUp = relicManager.IsOwned(rd.id) && relicManager.CanEnhance(rd.id);
        if (canUnlock || canRankUp || canLevelUp) { canRelicAny = true; break; }
    }
    SetRedDotActive(relicNodeId, canRelicAny);
}
```

### 2-9. DamageCalculationManager 초기화 순서 문제

`DamageCalculationManager` priority: **175** (System)
`RelicManager` priority: **334** (Lobby)

필수 lazy-init 패턴:
```csharp
// DamageCalculationManager.RelicEffect.cs
public partial class DamageCalculationManager
{
    private RelicManager _relicManager;

    private float GetRelicPercentageDamageModifiers(EUnitType? unitType = null)
    {
        var arkManager = Managers.Instance?.GetManager<ArkManager>();
        if (arkManager != null && arkManager.IsArkMode) return 0f;

        if (_relicManager == null)
        {
            _relicManager = GetManager<RelicManager>(); // BaseManager 단축형
            if (_relicManager == null) return 0f;
        }
        return _relicManager.GetUnitDamageBonus(unitType);
    }
}
```

### 2-10. [수정] RelicGachaProbabilityDataSource sync 불가

WD에는 `IGachaProbabilityDataSource` 인터페이스가 없음.
BD의 `RelicGachaProbabilityDataSource.cs` 는 `GachaProbabilityListPopup` + `GachaProbabilityDetailPopup` (BD 전용) 와 연동.

WD 처리 방향 (권장):
- `RelicGachaProbabilityPopup.cs` 신규 UI 파일 작성 (독립 팝업)
- BD `GachaUI.cs`의 `ShowRelicGachaProbabilityPopup()` 로직을 WD용으로 재작성

### 2-11. [수정] 가챠 UI 구조 — RelicGachaMainUI 없음

BD에 `RelicGachaMainUI.cs` 파일이 없음. 유물 뽑기 UI는 **`GachaUI.cs` (Shop 폴더)** 에 통합되어 있음.

WD 처리 방향:
- **BD `GachaUI.cs`의 Relic 관련 코드를 WD `GachaUI.cs`에 추가** (Relic 가챠 패널, 버튼 핸들러)
- `RelicGachaPopup.cs` 는 별도 파일로 이식 (뽑기 연출만 담당)
- 기존 계획의 `RelicGachaMainUI.cs` 신규 파일 대신 `GachaUI.cs` 수정으로 변경

### 2-12. [수정] UnitController RelicSkill 구조 (BD 실제 확인)

BD `UnitController.cs`에 이미 RelicSkill 기반 구조 완비:
```csharp
// BD UnitController.cs 실제 코드 (WD에 그대로 추가)
protected virtual ERelicSkillType RelicSkillType => ERelicSkillType.None;
protected bool _hasRelicSkill;
protected List<RelicSkillDataData> _relicSkillDataList = new List<RelicSkillDataData>();
protected int _relicSkillRank;

protected virtual void InitializeRelicSkills()
{
    _hasRelicSkill = false;
    _relicSkillDataList.Clear();
    _relicSkillRank = 0;
    if (RelicSkillType == ERelicSkillType.None) return;
    var relicManager = GetRelicManager(); // BD: ServiceAccessor 패턴
    var saveData = relicManager.CanUseRelicSkill(RelicSkillType);
    if (saveData != null)
    {
        _hasRelicSkill = true;
        _relicSkillRank = saveData.currentRank;
        _relicSkillDataList = relicManager.GetRelicSkillDataList(RelicSkillType, _relicSkillRank);
        ApplyRelicSkillEffect();
    }
}

protected virtual void ApplyRelicSkillEffect()
{
    foreach (var data in _relicSkillDataList)
        OnApplyRelicRankEffect(data);
}

protected virtual void OnApplyRelicRankEffect(RelicSkillDataData data) { }
```

**훅 포인트**: 각 유닛 컨트롤러의 `InitializeAsync()` 또는 내부 초기화 메서드 말미에 `InitializeRelicSkills()` 호출.
WD의 경우 `ServiceAccessor.Get<RelicManager>()` → `Managers.Instance?.GetManager<RelicManager>()` 로 변환.

### 2-13. DragoonController.RelicSkill.cs — 거의 그대로 복사 가능

BD 파일: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/Core/Controllers/Dragoon/DragoonController.RelicSkill.cs`

이미 WD 패턴 준수 확인:
- `Managers.Instance.GetManager<EnemyManager>()` 사용
- `await tween.AsyncWaitForCompletion()` 사용 (DOTween)
- `async UniTaskVoid` 사용
- `MoveRelicExtraLaserToTargetAsync().Forget()` 사용

단 한 곳만 변환 필요:
- BD `ServiceAccessor.Get<RelicManager>()` → WD `Managers.Instance?.GetManager<RelicManager>()` (있다면)

### 2-14. CLAUDE.md 전체 준수 체크리스트

| 규칙 | BD 패턴 | WD 변환 | 해당 파일 |
|------|---------|---------|-----------|
| 비동기 | `async void` | `async UniTaskVoid` | RelicGachaPopup, 모듈류 |
| DOTween | `tween.ToUniTask()` | `await tween.AsyncWaitForCompletion()` | DragoonController.RelicSkill (이미 OK) |
| 이벤트 해제 | `subscription.Dispose()` | `EventManager.Unsubscribe` in `Cleanup()`/`OnClosed()` | 모든 UI + RelicManager |
| 로컬라이제이션 | 하드코딩 문자열 | `LocalizationManager.GetLocalizedText("relic_*")` | 모든 UI 파일 |
| 리소스 로드 | `Resources.Load<T>()` | `ResourceManager.LoadResource<T>()` | RelicIcon, RelicUtility |
| 시간 | `DateTime.Now` | `ServerTimeManager.NowUnscaled` | 뽑기 쿨타임 관련 |
| 오브젝트 탐색 | `FindObjectOfType<T>()` | `GetManager<T>()` | 전체 |
| 매직 넘버 | 리터럴 숫자 | `const` 또는 `[SerializeField]` | RelicManager |
| 서버 API | 직접 호출 | `ServerLoadingPopupUI.Show/Hide` 패턴 | 뽑기/강화/랭크업 호출부 |

---

## 3. 신규 파일 목록 (직접 이식)

### 3-1. Core/Managers/Relic/ (신규 디렉토리)

BD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/Core/Managers/Relic/`

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/Relic/`

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicManager.cs` | 핵심 매니저 (초기화, 데이터 조회, 강화/랭크업 API) | `BaseService` → `BaseManager`, `ServiceAccessor` → `GetManager<T>()`, `MessageBroker` → `EventManager`, IMessage 클래스 → BaseEventData 상속 |
| `RelicDataSOParser.cs` | JSON → RelicData 변환 파서 | 변환 없음 (정적 유틸) |
| `RelicRankupDataSOParser.cs` | JSON → RelicRankupDataData 변환 파서 | 변환 없음 |
| `RelicSkillDataSOParser.cs` | JSON → RelicSkillDataData 변환 파서 | 변환 없음 |

> [수정] `RelicGachaService.cs` BD에 없음 — 가챠 로직은 GachaManager에 통합되어 있음. 이식 시 GachaManager에 Relic 가챠 메서드 추가.

### 3-2. Data/Relic/ (신규 디렉토리)

BD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/Data/Relic/`

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Data/Relic/`

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicData.cs` | 밸런스 데이터 컨테이너 (읽기 전용) | 변환 없음 |
| `RelicSaveData.cs` | 플레이어 유물 저장 데이터 | 변환 없음 |

### 3-3. SOs/Class/DataSheet/ (DataSheet 자동생성 클래스)

BD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/SOs/Class/DataSheet/`

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/SOs/Class/DataSheet/`

> Google Sheets 자동생성 파일 — 그대로 복사 가능 (NEVER MODIFY 규칙 준수)

| 파일명 | 역할 |
|--------|------|
| `RelicBoxDataData.cs` | 유물 상자 드롭 데이터 |
| `RelicDataData.cs` | 유물 기본 정보 |
| `RelicDropDataData.cs` | 유물 드롭 등급 데이터 |
| `RelicDropTableData.cs` | 유물 드롭 테이블 |
| `RelicGachaConfigDataData.cs` | 뽑기 설정 (비용, 천장) |
| `RelicGachaProbabilityEntry.cs` | 뽑기 확률 항목 |
| `RelicGachaResult.cs` | 뽑기 결과 구조체 |
| `RelicPityDataData.cs` | 천장 시스템 데이터 |
| `RelicRankupDataData.cs` | 랭크업 소재/코스트 |
| `RelicRotateTableData.cs` | 픽업 로테이션 테이블 |
| `RelicSkillDataData.cs` | 신화 스킬 데이터 (arg1~7) |
| `RelicUpgradeDataData.cs` | 강화 레벨별 데이터 |
| `RelicWeightDataData.cs` | 확률 가중치 테이블 |
| `RelicWeightTableData.cs` | 가중치 테이블 래퍼 |

### 3-4. SOs/SO/DataSheet/ (ScriptableObject + Parser)

BD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/SOs/SO/DataSheet/`

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/SOs/SO/DataSheet/`

> SO 파일 자체는 그대로 복사 가능. `[CreateAssetMenu]` 경로 충돌 여부 확인 필요.

| 파일명 | 역할 |
|--------|------|
| `RelicBoxDataSO.cs` + `RelicBoxDataSOParser.cs` | 유물 상자 SO + JSON 파서 |
| `RelicDataSO.cs` | 유물 기본 SO |
| `RelicDropDataSO.cs` + `RelicDropTableDataParser.cs` | 유물 드롭 SO + 파서 |
| `RelicGachaConfigDataSO.cs` + `RelicGachaConfigDataParser.cs` | 뽑기 설정 SO + 파서 |
| `RelicPityDataSO.cs` + `RelicPityDataParser.cs` | 천장 SO + 파서 |
| `RelicRankupDataSO.cs` | 랭크업 SO |
| `RelicRotateTableSO.cs` + `RelicRotateTableDataParser.cs` | 로테이션 SO + 파서 |
| `RelicSkillDataSO.cs` | 스킬 데이터 SO |
| `RelicUpgradeDataSO.cs` + `RelicUpgradeDataSOParser.cs` | 강화 SO + 파서 |
| `RelicWeightDataSO.cs` + `RelicWeightDataParser.cs` | 가중치 SO + 파서 |

### 3-5. Core/Managers/ (partial 클래스 신규)

| BD 파일 | WD 대상 경로 | 변환 사항 |
|---------|------------|-----------|
| `DamageCalculationManager.RelicEffect.cs` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/DamageCalculationManager.RelicEffect.cs` | lazy-init 패턴 필수 (섹션 2-9 참조) |

### 3-6. UI/Relic/Panel/ (신규 디렉토리)

BD 경로: `.../UI/Relic/Panel/`
WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/Relic/Panel/`

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicDescriptionPopup.cs` | 유물 설명 팝업 | `ServiceAccessor` → `GetManager<T>()`, 로컬라이제이션 적용 |
| `RelicDisplayComponent.cs` | 유물 그리드 아이콘 컴포넌트 | `ServiceAccessor` → `GetManager<T>()` |
| `RelicEquipPickerItemComponent.cs` | 장착 선택 리스트 아이템 | `ServiceAccessor` → `GetManager<T>()` |
| `RelicEquipPickerUI.cs` | 유물 장착 관리 팝업 (4슬롯) | `ServiceAccessor` → `GetManager<T>()`, 로컬라이제이션 적용 |
| `RelicEquippedDescComponent.cs` | 장착 유물 설명 컴포넌트 | `ServiceAccessor` → `GetManager<T>()` |
| `RelicEquippedSlotComponent.cs` | 장착 슬롯 컴포넌트 | 변환 없음 |
| `RelicIcon.cs` | 아이콘 애니메이터 | 변환 없음 |
| `RelicMainUI.cs` | 유물 메인 UI (창고/장착 탭) | `ServiceAccessor` → `GetManager<T>()`, `MessageBroker` → `EventManager`, 로컬라이제이션 적용 |

### 3-7. UI/Relic/ (신규 디렉토리)

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/Relic/`

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicGachaPopup.cs` | 뽑기 연출 팝업 | `ServiceAccessor` → `GetManager<T>()`, `async UniTaskVoid` 확인 |
| `RelicGachaProbabilityPopup.cs` | **신규 작성** (BD의 `RelicGachaProbabilityDataSource` 대체) | RelicManager에서 확률 데이터 직접 조회, WD 스타일 신규 작성 |
| `RelicUtility.cs` | 정적 유틸 (색상, 스프라이트) | `Resources.Load` → `ResourceManager.LoadResource<T>()` 확인 |

### 3-8. UI/Relic/Upgrade/ (신규 디렉토리)

WD 경로: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/Relic/Upgrade/`

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicUpgradeModuleBase.cs` | 업그레이드 모듈 추상 베이스 | 변환 없음 (순수 C#) |
| `RelicUnlockModule.cs` | 해금 모듈 | `ServiceAccessor` → `GetManager<T>()`, 서버 API 패턴 적용 |
| `RelicLevelUpModule.cs` | 강화 모듈 | `ServiceAccessor` → `GetManager<T>()`, 서버 API 패턴 적용 |
| `RelicRankUpModule.cs` | 랭크업 모듈 | `ServiceAccessor` → `GetManager<T>()`, 서버 API 패턴 적용 |
| `RelicLevelBox.cs` | 레벨/랭크 변화 표시 컴포넌트 | 로컬라이제이션 적용 (MinionLevelBox.cs 패턴 참고) |
| `RelicResultPopup.cs` | 강화/랭크업 결과 팝업 | 로컬라이제이션 적용 |
| `RelicUpgradeUI.cs` | 강화/랭크업 메인 UI | `ServiceAccessor` → `GetManager<T>()`, `MessageBroker` → `EventManager`, 로컬라이제이션 적용 |

### 3-9. Core/Controllers/Dragoon/ (partial 클래스 신규)

| BD 파일 | WD 대상 경로 |
|---------|------------|
| `DragoonController.RelicSkill.cs` | `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Controllers/Dragoon/DragoonController.RelicSkill.cs` |

> 거의 그대로 복사 가능 (이미 `Managers.Instance.GetManager`, `async UniTaskVoid`, `AsyncWaitForCompletion` 패턴 준수). `ServiceAccessor` 사용 부분만 확인 후 변환.

---

## 4. 기존 파일 수정 목록

### 4-1. Enum 파일 수정

| 파일 (WD 절대 경로) | 추가 내용 |
|------|-----------|
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/GameEnums.cs` | `ERelicGrade { Epic=0, Legendary=1, Mythic=2 }` enum 추가<br>`ERelicSkillType { None, TurretDelayedExplosion, ZeusRapidFire, DrFrostBlizzardGrowth, MarauderShotgunBlast, TemplerMultiHit, NinjaMythic, AirManWindExtra, ThorElectricPull, VesselDefensiveShield, CarrierSpecialInterceptor, DragoonLaserBind }` enum 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/ECurrencyType.cs` | Relic 조각(689~721), 티켓(729~730), 업그레이드/랭크업/상자(1187~1193) 추가. **1093~1099는 WD 기존 항목이므로 절대 수정 금지** |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/ContentTypes.cs` | `Feature_Relic` 추가 (해금 레벨 미정 — BLOCKER-1) |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/EGachaType.cs` | `Relic` 추가 (WD GachaManager Relic 가챠 연동용) |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/GameEventTypes.cs` | `RelicAcquired, RelicEnhanced, RelicRankedUp, RelicEquipped, RelicUnequipped, RelicGachaDrawn` 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/ETargetItemType.cs` | **수정 불필요** — `Relic` 이미 존재 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Enums/EAcquisitionRouteType.cs` | `RelicGacha` 추가 (로컬라이제이션 키: `route_relicgacha`) |

### 4-2. Data/Config 파일 수정

| 파일 (WD 절대 경로) | 추가 내용 |
|------|-----------|
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Data/BalanceTableNames.cs` | `RELIC_DATA, RELIC_UPGRADE_DATA, RELIC_SKILL_DATA, RELIC_RANKUP_DATA, RELIC_BOX_DATA, RELIC_DROP_TABLE, RELIC_WEIGHT_TABLE, RELIC_ROTATE_TABLE, RELIC_GACHA_CONFIG, RELIC_PITY_DATA` 상수 10개 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/SaveDataTypes.cs` | `ESaveDataType.Relics, ESaveDataType.RelicGacha` 추가<br>`FirebaseKeys.RELICS = "relics"`, `FirebaseKeys.RELIC_GACHA = "relicgacha"` 추가<br>`RelicSystemSaveData` 클래스 추가 (BD 3394~3396행 복사) |

### 4-3. 매니저 파일 수정

| 파일 (WD 절대 경로) | 수정 내용 |
|------|-----------|
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/Managers.cs` | `MANAGER_DEFINITIONS` 배열의 ChipEffectManager(333) 다음 줄에 `new ManagerDefinition(typeof(RelicManager), 334, "Lobby", true, true)` 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/DamageCalculationManager.cs` | 기본 전투력 계산에 `GetRelicUnitDamageBonus()` 호출 추가 (RelicEffect partial 연동) |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/ContentUnlockManager.cs` | `_unlockConditions` 리스트에 `Feature_Relic` 조건 추가 (해금 레벨 미정 — BLOCKER-1) |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/RedDotManager.cs` | `EnsureEssentialNodes()` 튜플 배열에 `("Lobby.Upgrade.Unit.Relic", "Lobby.Upgrade.Unit", "유물")` 추가<br>구독/해제 코드 추가 (섹션 2-8 참조)<br>`CheckUnitUpgradeAvailability()` 내 유물 체크 로직 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/GachaManager.cs` | Relic 가챠 메서드 추가 (`InitializeRelicGacha`, `DrawRelics`, `CanRelicGacha`, `GetRelicGachaProbabilityDataSource` 등) — BD GachaManager에서 Relic 관련 코드만 추출하여 이식 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/FirebaseRemoteConfigManager.cs` | `IsRelicGachaEnabled` bool 프로퍼티 추가 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/AcquisitionRouteManager.cs` | `GetTargetUIType()` switch에 `case EAcquisitionRouteType.RelicGacha:` 추가 |

**Managers.cs 삽입 코드:**
```csharp
// ChipEffectManager(333) 다음 줄에 추가
new ManagerDefinition(typeof(RelicManager), 334, "Lobby", true, true), // 유물 시스템 매니저
```

**AcquisitionRouteManager.cs 추가 코드:**
```csharp
case EAcquisitionRouteType.RelicGacha:
    return (typeof(RelicGachaPopup), true); // 또는 GachaUI로 이동하도록 설정
```

### 4-4. UI 파일 수정

| 파일 (WD 절대 경로) | 수정 내용 |
|------|-----------|
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/LobbyMainUI.cs` | `_relicGachaButton` 추가, `OnRelicGachaButtonClicked()` → `GachaUI` 또는 `RelicGachaPopup` 열기, 해금/리모트컨피그 조건으로 버튼 가시성 관리 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/UnitUpgradeUI.cs` | `_relicButton` 추가, `OnRelicButtonClicked()` → `Show<RelicMainUI>()`, 레드닷 컴포넌트 연결 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/Components/TargetDisplayComponent.cs` | `ETargetItemType.Relic` case 추가 — enum은 이미 있지만 switch 케이스 없음. `RelicIcon` 컴포넌트 연결 |
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/UI/Shop/GachaUI.cs` | Relic 가챠 패널/버튼 추가, `DrawRelicGacha()` 핸들러, `ShowRelicGachaProbabilityPopup()` 추가 — BD `GachaUI.cs`의 Relic 관련 코드 이식 |

### 4-5. 유닛 컨트롤러 수정 (신화 스킬 sync)

**UnitController.cs (베이스 클래스) 추가 코드:**

파일: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Controllers/BaseClass/UnitController.cs`

```csharp
// 필드 추가 (기존 필드 그룹 하단)
protected bool _hasRelicSkill;
protected List<RelicSkillDataData> _relicSkillDataList = new List<RelicSkillDataData>();
protected int _relicSkillRank;
private RelicManager _relicManager;

// 프로퍼티/메서드 추가
protected virtual ERelicSkillType RelicSkillType => ERelicSkillType.None;

private RelicManager GetRelicManager()
{
    if (_relicManager == null)
        _relicManager = Managers.Instance?.GetManager<RelicManager>();
    if (_relicManager != null && !_relicManager.IsInitialized)
        _relicManager = null;
    return _relicManager;
}

protected virtual void InitializeRelicSkills()
{
    _hasRelicSkill = false;
    _relicSkillDataList.Clear();
    _relicSkillRank = 0;
    if (RelicSkillType == ERelicSkillType.None) return;
    var relicManager = GetRelicManager();
    if (relicManager == null) return;
    var saveData = relicManager.CanUseRelicSkill(RelicSkillType);
    if (saveData != null)
    {
        _hasRelicSkill = true;
        _relicSkillRank = saveData.currentRank;
        _relicSkillDataList = relicManager.GetRelicSkillDataList(RelicSkillType, _relicSkillRank);
        ApplyRelicSkillEffect();
    }
}

protected virtual void ApplyRelicSkillEffect()
{
    foreach (var data in _relicSkillDataList)
        OnApplyRelicRankEffect(data);
}

protected virtual void OnApplyRelicRankEffect(RelicSkillDataData data) { }
```

**각 유닛 컨트롤러 수정 목록:**

| WD 파일 | BD 파일 (호출 위치 확인됨) | 신화 스킬 타입 | InitializeRelicSkills() 호출 위치 |
|---------|--------------------------|---------------|----------------------------------|
| `ArchonController.cs` | BD line 277 | `ZeusRapidFire` | `InitializeAsync()` 말미 |
| `DrFrostController.cs` | BD line 192, 197 | `DrFrostBlizzardGrowth` | `InitializeAsync()` 말미 (override InitializeRelicSkills) |
| `TurretController.cs` | BD line 216 | `TurretDelayedExplosion` | `InitializeAsync()` 말미 |
| `TemplerController.cs` | BD line 364 | `TemplerMultiHit` | `InitializeAsync()` 말미 |
| `AirManController.cs` | BD line 370 | `AirManWindExtra` | `InitializeAsync()` 말미 |
| `NinjaController.cs` | BD line 218 | `NinjaMythic` | `InitializeAsync()` 말미 |
| `ThorController.cs` | BD line 310 | `ThorElectricPull` | `InitializeAsync()` 말미 |
| `VesselController.cs` | BD line 235, 720 | `VesselDefensiveShield` | `InitializeAsync()` 말미 (override InitializeRelicSkills) |
| `MarauderController.cs` | BD line 238, 1656 | `MarauderShotgunBlast` | `InitializeAsync()` 말미 (override InitializeRelicSkills) |
| `CarrierController.cs` | BD line 172, 790 | `CarrierSpecialInterceptor` | `InitializeAsync()` 말미 (override InitializeRelicSkills) |
| `DragoonController.cs` + `DragoonController.RelicSkill.cs` | BD Dragoon partial | `DragoonLaserBind` | partial 파일에서 override InitializeRelicSkills |

BD 유닛 컨트롤러 경로:
```
/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/Core/Controllers/
├── Archon/ArchonController.cs
├── DrFrost/DrFrostController.cs + BlizzardController.cs
├── Dragoon/DragoonController.cs + DragoonController.RelicSkill.cs
├── Marauder/MarauderController.cs + ExplosiveProjectileController.cs
├── Templer/TemplerController.cs
├── Turret/TurretController.cs
├── Carrier/CarrierController.cs + InterceptorController.cs
├── Vessel/VesselController.cs + MovingVesselController.cs
└── Units/AirManController.cs + NinjaController.cs + ThorController.cs
    └── Projectiles/AirManProjectile.cs + HammerProjectile.cs
```

WD 유닛 컨트롤러 경로:
```
/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Controllers/
(동일 구조 확인 필요)
```

> Archon 주의: WD Archon은 partial 파일이 14개. `ArchonController.RelicSkill.cs` 신규 partial 파일 추가 권장. `LaserType.RelicFan`은 `ArchonController.Types.cs`에 추가.

### 4-6. 에디터 유틸 수정

| 파일 (WD 절대 경로) | 수정 내용 |
|------|-----------|
| `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Utils/Editor/JsonToSO.cs` | Relic 관련 SO 변환 케이스 7종 추가 (RelicPityData, RelicDropData, RelicWeightData, RelicRotateTable, RelicGachaConfigData, RelicRankupData, RelicBoxData) |

---

## 5. Sync 실행 순서 (의존성 역순)

### Phase 1 — 타입/데이터 정의 (의존성 없음)
1. `GameEnums.cs` → `ERelicGrade`, `ERelicSkillType` 추가
2. `ECurrencyType.cs` → Relic 재화 타입 추가 (689~730: 그대로, 1187~1193: 재배정 번호)
3. `ContentTypes.cs` → `Feature_Relic` 추가 (해금 레벨 플레이스홀더로)
4. `EGachaType.cs` → `Relic` 추가
5. `GameEventTypes.cs` → Relic 이벤트 타입 6개 추가
6. `EAcquisitionRouteType.cs` → `RelicGacha` 추가
7. `BalanceTableNames.cs` → RELIC_* 테이블 이름 10개 추가
8. `SaveDataTypes.cs` → `Relics`, `RelicGacha`, `RelicSystemSaveData` 추가
9. DataSheet Data 클래스 14개 복사

### Phase 2 — 순수 데이터/SO 파일 (Phase 1 의존)
10. `RelicData.cs`, `RelicSaveData.cs` 복사
11. `RelicGachaResult.cs`, `RelicGachaProbabilityEntry.cs` 복사
12. SO 클래스 17개 복사
13. SO Parser 클래스 복사

### Phase 3 — 핵심 매니저 (Phase 1~2 의존)
14. `RelicManager.cs` sync (`ServiceAccessor` → `GetManager`, `MessageBroker` → `EventManager`, `BaseService` → `BaseManager`)
15. `DamageCalculationManager.RelicEffect.cs` sync (partial 클래스, lazy-init 필수)

### Phase 4 — GachaManager Relic 통합 (Phase 3 의존)
16. `GachaManager.cs` → Relic 가챠 메서드 추가 (BD GachaManager에서 Relic 전용 코드 추출)

### Phase 5 — 기존 매니저 연동 (Phase 3~4 의존)
17. `Managers.cs` → RelicManager 등록 (priority: 334)
18. `DamageCalculationManager.cs` → RelicEffect 호출 연동 (null-safe 필수)
19. `ContentUnlockManager.cs` → Feature_Relic 추가
20. `RedDotManager.cs` → Relic 레드닷 노드 + 이벤트 구독 추가
21. `FirebaseRemoteConfigManager.cs` → `IsRelicGachaEnabled` 추가
22. `AcquisitionRouteManager.cs` → RelicGacha 경로 추가

### Phase 6 — UI 시스템 (Phase 3~5 의존)
23. `RelicUtility.cs` 복사
24. `RelicIcon.cs` 복사
25. `RelicLevelBox.cs` sync (LocalizationManager 적용, MinionLevelBox.cs 참고)
26. `RelicUpgradeModuleBase.cs` sync
27. `RelicUnlockModule.cs`, `RelicLevelUpModule.cs`, `RelicRankUpModule.cs` sync (서버 API 패턴)
28. `RelicDisplayComponent.cs`, `RelicEquippedSlotComponent.cs` 등 컴포넌트 sync
29. `RelicResultPopup.cs`, `RelicDescriptionPopup.cs` sync
30. `RelicEquipPickerUI.cs` sync
31. `RelicMainUI.cs` sync (이벤트: OnOpened/OnClosed 패턴)
32. `RelicUpgradeUI.cs` sync
33. `RelicGachaPopup.cs` sync (async UniTaskVoid 확인)
34. `RelicGachaProbabilityPopup.cs` 신규 작성 (BD `RelicGachaProbabilityDataSource` 대체)

### Phase 7 — 기존 UI 연동 (Phase 6 의존)
35. `LobbyMainUI.cs` → 유물 뽑기 버튼 추가
36. `UnitUpgradeUI.cs` → 유물 버튼 추가
37. `TargetDisplayComponent.cs` → `ETargetItemType.Relic` case 추가
38. `GachaUI.cs` → Relic 가챠 패널/버튼 추가 (BD GachaUI Relic 코드 이식)

### Phase 8 — 유닛 컨트롤러 신화 스킬 (Phase 3 의존)
39. `UnitController.cs` → RelicSkill 기본 virtual 메서드 추가
40. 각 유닛 컨트롤러 신화 스킬 구현 (11개 유닛 + 관련 Projectile)
41. `DragoonController.RelicSkill.cs` 신규 파일 추가 (거의 그대로 복사)
42. `ArchonController.RelicSkill.cs` 신규 partial 파일 추가 + `ArchonController.Types.cs` LaserType.RelicFan 추가

### Phase 9 — 에디터 도구
43. `JsonToSO.cs` → Relic SO 변환 7종 추가

### Phase 10 — 프리팹/에셋 sync (C# 완성 후 별도 진행)
44. BD → WD: `UI/Relic/` 하위 프리팹 전체 복사 + GUID 교체
45. BD → WD: 유물 아이콘 스프라이트 아틀라스 복사
46. BD → WD: 뽑기 연출 애니메이션 클립 복사
47. Unity Inspector에서 MissingReference 전수 점검

---

## 6. 파일별 변환 가이드 (핵심 파일)

### RelicManager.cs

```csharp
// Before (BunkerDefense)
public class RelicManager : BaseService
{
    private SaveDataManager _saveDataManager => ServiceAccessor.Get<SaveDataManager>();
    public override async UniTask InitializeAsync()
    {
        _messageBroker = MainInstaller.TryResolve<IMessageBrokerService>();
        ...
    }
    private void NotifyRelicAcquired(int relicId)
    {
        _messageBroker.PublishSafe(new RelicAcquiredMessage { RelicId = relicId });
    }
    public override void Cleanup()
    {
        _subscriptions.ForEach(s => s.Dispose());
    }
}

// After (WiggleDefender)
public class RelicManager : BaseManager
{
    private SaveDataManager SaveDataManager => GetManager<SaveDataManager>();

    public override async UniTask InitializeAsync()
    {
        // EventManager는 정적 접근, 구독 불필요 시 비워도 됨
        ...
    }
    private void NotifyRelicAcquired(int relicId)
    {
        EventManager.Dispatch(GameEventType.RelicAcquired,
            new RelicEventData { RelicId = relicId });
    }
    public override void Cleanup()
    {
        // 필요한 EventManager.Unsubscribe 호출
    }
}
```

### RelicMainUI.cs (이벤트 구독/해제 패턴)

```csharp
// Before (BunkerDefense) — BD 실제 코드: MessageBroker 구독
// After (WiggleDefender)
public override void Opened(params object[] param)
{
    base.Opened(param);
    _relicManager ??= Managers.Instance.GetManager<RelicManager>();
    _uiManager ??= Managers.Instance.GetManager<UIManager>();

    EventManager.Subscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicChanged);
    EventManager.Subscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicChanged);
    EventManager.Subscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicChanged);
    EventManager.Subscribe<CurrencyEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
    // ... 기존 초기화 로직
}

public override void Closed(params object[] param)
{
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicChanged);
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicChanged);
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicChanged);
    EventManager.Unsubscribe<CurrencyEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
    base.Closed(param);
}
```

### 서버 API 호출 패턴 (강화/랭크업/뽑기)

```csharp
// WD 필수 패턴 (CLAUDE.md)
private async UniTaskVoid OnUnlockButtonClickedAsync()
{
    var popup = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("relic_unlock_loading"));
    try
    {
        await serverManager.RelicUnlockAsync(relicId);
    }
    finally
    {
        ServerLoadingPopupUI.Hide();
    }
}
// async void 금지 → async UniTaskVoid
```

### GachaManager.cs Relic 가챠 추가 패턴

BD GachaManager에서 추출할 메서드 목록:
```
InitializeRelicGacha()          → BD line 967
DrawRelicsByCount(int count)    → BD line 1086
DrawRelicAdGachaAsync()         → BD line 219
CanRelicGacha(int count)        → BD line 350
DrawRelics(int count)           → BD line 356
GetRelicGachaProbabilities()    → BD line 359
GetActiveRelicRotateItems()     → BD line 362
GetRelicGachaProbabilityDataSource() → BD line 1265
```

BD GachaManager.cs 경로:
`/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker/Assets/_Project/1_Scripts/Core/Managers/GachaManager.cs`

WD GachaManager.cs 경로:
`/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/GachaManager.cs`

변환 사항: `ServiceAccessor.Get<T>()` → `GetManager<T>()`

---

## 7. 누락 검증 체크리스트

### UI 계층 → 매니저 계층
- [ ] `RelicMainUI` → `RelicManager.GetAllRelicData()`, `IsOwned()`, `CanRankUp()`, `CanEnhance()`, `CanAffordUnlock()` 구현됨
- [ ] `RelicUpgradeUI` → `RelicManager.EnhanceRelic()`, `RankUpRelic()`, `UnlockRelic()` 구현됨
- [ ] `GachaUI (Relic 패널)` → `GachaManager.DrawRelics()`, `CanRelicGacha()` 구현됨
- [ ] `RelicEquipPickerUI` → `RelicManager.ApplyEquipPlan()` 구현됨

### 매니저 계층 → 데이터 계층
- [ ] `RelicManager` → `RelicData`, `RelicSaveData`, `RelicUpgradeDataData`, `RelicRankupDataData`, `RelicSkillDataData` 전부 정의됨
- [ ] `GachaManager (Relic)` → `RelicGachaResult`, `RelicRotateTableData`, `RelicWeightTableData`, `RelicPityDataData` 전부 정의됨

### 데이터 계층 → Enum 계층
- [ ] `ERelicGrade` 사용처: `RelicDataData`, `RelicSaveData`, `RelicRankupDataData`, `RelicDropDataData`
- [ ] `ERelicSkillType` 사용처: `RelicDataData`, `RelicSkillDataData`, `UnitController`
- [ ] `ECurrencyType` 사용처: `RelicBoxDataData`, `RelicWeightDataData`, `RelicPityDataData`, `GachaManager`

### 저장 시스템
- [ ] `ESaveDataType.Relics` → `RelicSystemSaveData` (플레이어 보유/장착)
- [ ] `ESaveDataType.RelicGacha` → 천장/보장 카운터 데이터

### 이벤트 시스템
- [ ] `RelicManager` 발행: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`, `RelicEquipped`, `RelicUnequipped`
- [ ] `GachaManager` 발행: `RelicGachaDrawn`
- [ ] `RelicMainUI` 구독: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`, `CurrencyChanged`
- [ ] `RelicUpgradeUI` 구독: `CurrencyChanged`
- [ ] `GachaUI` 구독: `CurrencyChanged`
- [ ] `RedDotManager` 구독: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`

### 신화 스킬 (11개 유닛)
- [ ] `TurretDelayedExplosion` ← `TurretController`
- [ ] `ZeusRapidFire` ← `ArchonController` + `ArchonController.RelicSkill.cs` (신규 partial)
- [ ] `TemplerMultiHit` ← `TemplerController`
- [ ] `DrFrostBlizzardGrowth` ← `DrFrostController` + `BlizzardController`
- [ ] `DragoonLaserBind` ← `DragoonController` + `DragoonController.RelicSkill.cs` (거의 그대로 복사)
- [ ] `MarauderShotgunBlast` ← `MarauderController` + `ExplosiveProjectileController`
- [ ] `VesselDefensiveShield` ← `VesselController` + `MovingVesselController`
- [ ] `CarrierSpecialInterceptor` ← `CarrierController` + `InterceptorController`
- [ ] `NinjaMythic` ← `NinjaController`
- [ ] `ThorElectricPull` ← `ThorController` + `HammerProjectile`
- [ ] `AirManWindExtra` ← `AirManController` + `AirManProjectile`

### 기타 연동
- [ ] `DamageCalculationManager.RelicEffect.cs` — lazy-init + `GetManager<T>()` 단축형
- [ ] `GachaUI` → Relic 가챠 패널 + `RelicGachaPopup` 연동
- [ ] `ContentUnlockManager` → `Feature_Relic` + `_unlockConditions` 배열
- [ ] `RedDotManager` → `"Lobby.Upgrade.Unit.Relic"` 노드 (기존 계획의 `"Lobby.Relic"` 경로 아님)
- [ ] `FirebaseRemoteConfigManager` → `IsRelicGachaEnabled`
- [ ] `BalanceDataManager` → RELIC_* 10개 테이블 로드 확인
- [ ] `JsonToSO.cs` → Relic SO 변환 7종
- [ ] `TargetDisplayComponent.cs` → `ETargetItemType.Relic` case (enum은 이미 존재)
- [ ] `EAcquisitionRouteType.cs` → `RelicGacha` (로컬라이제이션 키: `route_relicgacha`)
- [ ] `AcquisitionRouteManager.cs` → `RelicGacha` 케이스
- [ ] `LaserType.RelicFan` → `ArchonController.Types.cs`
- [ ] CLAUDE.md 전체 준수: `async UniTaskVoid`, `DOTween.AsyncWaitForCompletion()`, `LocalizationManager`, `ResourceManager`, `GetManager`
- [ ] ECurrencyType 1093~1099: WD 기존 항목 유지 (수정 금지), Relic 재배정 번호(1187~) 사용

---

## 8. BLOCKER 목록

| # | 내용 | 담당 | 현황 |
|---|------|------|------|
| BLOCKER-1 | `Feature_Relic` 해금 레벨 — 기획팀 확인 필요 (`ContentUnlockManager._unlockConditions`) | 기획 | 미확인 |
| BLOCKER-2 | Localization 키 17종 (`relic_*`) — 데이터시트 사전 등록 필요 | 기획/데이터 | 미확인 |
| BLOCKER-3 | `route_relicgacha` 로컬라이제이션 키 — 데이터시트 등록 필요 | 기획/데이터 | 미확인 |
| BLOCKER-4 | 신화 스킬 rank effect 정의서 — 11개 유닛 × rank 0/5/10 효과값 (`arg1~7` 매핑). BD 소스에서 확인 후 Phase 8 진입 | 개발 | BD 소스에서 확인 가능 |
| BLOCKER-5 | 프리팹/스프라이트 에셋 sync (Phase 10) — C# 완성 후 별도 진행 | 개발 | C# 완성 후 |
| BLOCKER-6 | ECurrencyType 번호 재배정(1187~) — GoogleSheets DataSheet 숫자값도 WD 기준으로 업데이트 필요 | 기획/데이터 | 충돌 범위 확인됨 |

**Localization 키 목록 (BLOCKER-2):**
```
relic_grade_epic / relic_grade_legendary / relic_grade_mythic
relic_upgrade_header / relic_rankup_header / relic_unlock_header
relic_gacha_title / relic_gacha_result_header
relic_equip_slot_empty / relic_equip_slot_header
relic_desc_popup_title
relic_result_enhanced / relic_result_ranked_up
relic_profile_attack_power
relic_unlock_loading / relic_enhance_loading / relic_rankup_loading
route_relicgacha
```

---

## 부록 — BunkerDefense 소스 경로 참조

BD worktree 루트: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/.claude/worktrees/temp-bunker`

```
Assets/_Project/1_Scripts/
├── Core/
│   ├── Controllers/
│   │   ├── Archon/ArchonController.cs (.LaserCore .LaserDamage .Types)
│   │   ├── BaseClass/UnitController.cs
│   │   ├── Carrier/CarrierController.cs, InterceptorController.cs
│   │   ├── DrFrost/DrFrostController.cs, BlizzardController.cs
│   │   ├── Dragoon/DragoonController.cs, DragoonController.RelicSkill.cs
│   │   ├── Marauder/MarauderController.cs, ExplosiveProjectileController.cs
│   │   ├── Templer/TemplerController.cs
│   │   ├── Thor/ThorController.cs, HammerProjectile.cs (Units/Thor 하위)
│   │   ├── Turret/TurretController.cs
│   │   ├── Units/AirManController.cs, NinjaController.cs
│   │   │   └── Projectiles/AirManProjectile.cs
│   │   └── Vessel/VesselController.cs, MovingVesselController.cs
│   ├── Data/BalanceTableNames.cs
│   ├── Enums/ContentTypes.cs, ECurrencyType.cs, EGachaType.cs, ETargetItemType.cs, GameEnums.cs
│   ├── Gacha/RelicGachaProbabilityDataSource.cs  ← WD에 sync 불가, 신규 팝업으로 대체
│   └── Managers/
│       ├── AcquisitionRouteManager.cs
│       ├── ContentUnlockManager.cs
│       ├── DamageCalculationManager.cs, DamageCalculationManager.RelicEffect.cs
│       ├── FirebaseRemoteConfigManager.cs
│       ├── GachaManager.cs  ← Relic 가챠 로직 포함 (DrawRelics, InitializeRelicGacha 등)
│       ├── RedDotManager.cs
│       ├── SaveDataManager.cs
│       ├── SaveDataTypes.cs  ← RelicSystemSaveData 포함
│       └── Relic/
│           ├── RelicDataSOParser.cs
│           ├── RelicManager.cs  ← 핵심 매니저 (가챠 서비스 포함 아님)
│           ├── RelicRankupDataSOParser.cs
│           └── RelicSkillDataSOParser.cs
├── Data/Relic/
│   ├── RelicData.cs
│   └── RelicSaveData.cs
├── SOs/
│   ├── Class/DataSheet/  (RelicBoxDataData.cs 외 13종)
│   └── SO/DataSheet/     (RelicDataSO.cs 외 16종)
└── UI/
    ├── Components/TargetDisplayComponent.cs
    ├── Minion/Upgrade/MinionLevelBox.cs  ← RelicLevelBox 참고용
    ├── Relic/
    │   ├── Panel/ (RelicMainUI.cs 외 7종)
    │   ├── RelicGachaPopup.cs  ← 뽑기 연출 (RelicGachaMainUI.cs 없음)
    │   ├── RelicUtility.cs
    │   └── Upgrade/ (RelicUpgradeUI.cs 외 6종)
    └── Shop/
        ├── GachaUI.cs  ← Relic 가챠 버튼/패널 포함 (유물 뽑기 진입점)
        └── GachaProbabilityPopup.cs  ← 칩 전용, Relic에 재사용 불가
```

---

*이 문서는 BunkerDefense feature/relic_skill 브랜치 전수 분석 + WiggleDefender 실제 코드베이스 Phase 2 대조 검증을 통해 작성/수정되었습니다.*
*WD 코드베이스 검증일: 2026-05-04*
*기존 계획(2026-05-03) 대비 주요 변경: RelicGachaService 없음 확인, SaveDataTypes.Relics 추가 필요 확인, ECurrencyType 충돌 범위(1093~1099) 특정 및 재배정 번호 확정, RedDotManager 노드 경로 수정(`Lobby.Upgrade.Unit.Relic`), GachaUI.cs 기존 파일 수정 방식으로 변경*
