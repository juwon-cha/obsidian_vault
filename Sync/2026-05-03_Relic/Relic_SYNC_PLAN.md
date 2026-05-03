# Relic(유물) 시스템 sync 계획 - BunkerDefense → WiggleDefender

> 작성일: 2026-05-03  
> 검토일: 2026-05-03 (WD 실제 코드베이스 대조 후 수정)
> 소스: `BunkerDefense` 프로젝트 (remote: temp-bunker)
> 타겟: `WiggleDefender` 프로젝트  

---

## 목차
1. [시스템 개요](#1-시스템-개요)
2. [핵심 차이점 (sync 시 주의사항)](#2-핵심-차이점-sync-시-주의사항)
3. [전체 파일 목록](#3-전체-파일-목록)
   - 3-1. 신규 생성 파일 (직접 sync)
   - 3-2. 기존 파일 수정 목록
4. [sync 순서 (의존성 역순)](#4-sync-순서-의존성-역순)
5. [파일별 sync 가이드](#5-파일별-sync-가이드)
6. [누락 검증 체크리스트](#6-누락-검증-체크리스트)

---

## 1. 시스템 개요

Relic(유물) 시스템은 수집/장착/강화로 전투력을 증강하는 후기 콘텐츠.  
**4개 슬롯 장착**, **등급 (Rare/Epic/Legendary/Mythic)**, **랭크업(1~10)**, **강화(0~100레벨)**, **뽑기(가챠)**, **신화 전용 스킬** 으로 구성.

```
RelicManager (핵심)
├── RelicGachaService (뽑기 비즈니스 로직)
├── SaveDataManager → ESaveDataType.Relics, RelicGacha
├── BalanceDataManager → RELIC_* 10개 테이블
├── DamageCalculationManager → 보너스 반영
└── CurrencyManager → 재화 조각/뽑기 티켓

UI
├── RelicMainUI (창고 + 장착 탭)
├── RelicUpgradeUI (강화/랭크업 팝업)
├── RelicGachaMainUI (뽑기 팝업)
└── RelicGachaPopup (뽑기 연출)

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

## 2. 핵심 차이점 (sync 시 주의사항)

### 2-1. 매니저 접근 패턴

| 항목 | BunkerDefense | WiggleDefender |
|------|---------------|----------------|
| 매니저 접근 | `ServiceAccessor.Get<T>()` | `Managers.Instance.GetManager<T>()` |
| DI 접근 | `MainInstaller.TryResolve<T>()` | 동일: `Managers.Instance.GetManager<T>()` |
| 매니저 베이스 | `BaseService` | `BaseManager` (MonoBehaviour 기반) |
| 매니저 등록 | `ManagerFactory` 클래스 별도 | `MANAGER_DEFINITIONS[]` 정적 배열 (Managers.cs) |

> ⚠️ **WD의 ManagerFactory 파일은 없다.** `Core/Base/ManagerFactory.cs`가 아닌 `Core/Managers/Managers.cs`의 `MANAGER_DEFINITIONS` 배열에 등록한다.

**변환 규칙:**
```csharp
// Before (BunkerDefense)
ServiceAccessor.Get<RelicManager>()
MainInstaller.TryResolve<IMessageBrokerService>()

// After (WiggleDefender) — 외부에서 접근 시
Managers.Instance.GetManager<RelicManager>()

// After (WiggleDefender) — BaseManager 상속 클래스 내부에서 (DamageCalculationManager 등)
// BaseManager에 GetManager<T>() 단축 메서드가 존재. 아래 두 표현은 동일함.
GetManager<RelicManager>()               // 내부 단축형 (ChipEffect.cs 실제 사용 패턴)
Managers.Instance.GetManager<RelicManager>()  // 외부 접근형
// (MessageBroker는 EventManager로 교체)
```

### 2-2. 이벤트 시스템

| 항목 | BunkerDefense | WiggleDefender |
|------|---------------|----------------|
| 발행 | `MessageBroker.PublishSafe(new RelicAcquiredMessage())` | `EventManager.Dispatch<RelicEventData>(GameEventType.RelicAcquired, data)` |
| 구독 | `_messageBroker.Subscribe<RelicAcquiredMessage>(Handler)` | `EventManager.Subscribe<RelicEventData>(GameEventType.RelicAcquired, Handler)` |
| 해제 | `_subscription.Dispose()` | `EventManager.Unsubscribe<T>(GameEventType, Handler)` - `Cleanup()`에서 |

**추가할 GameEventType 값 (GameEventTypes.cs):**
```csharp
// 유물 시스템 이벤트
RelicAcquired,       // 유물 획득 (뽑기/해금)
RelicEnhanced,       // 유물 강화 (enhanceLevel 증가)
RelicRankedUp,       // 유물 랭크업 (rank 증가)
RelicEquipped,       // 유물 장착
RelicUnequipped,     // 유물 해제
RelicGachaDrawn,     // 유물 뽑기 실행
```

**이벤트 데이터 클래스 (신규):**
```csharp
public class RelicEventData { public int RelicId; public ERelicGrade Grade; }
public class RelicGachaDrawnEventData { public List<RelicGachaResult> Results; }
```

### 2-3. UI 베이스 클래스

BunkerDefense의 `UIBase` → WiggleDefender의 `UIBase` (`UI/UIBase.cs`)로 교체.  
`Show<T>()` / `Hide<T>()` API는 동일하게 유지.  
`OnOpened()` / `OnClosed()` 콜백도 동일.

### 2-4. 매니저 등록 방법

```csharp
// WiggleDefender Core/Managers/Managers.cs의 MANAGER_DEFINITIONS 배열에 추가
// ⚠️ 현재 최고 Lobby priority는 364(IAPManager). RelicManager는 CurrencyManager(295),
//     ContentUnlockManager(321) 이후이면 충분하므로 334 사용 (PresetManager 동일 priority와 공존 가능)
new ManagerDefinition(typeof(RelicManager), 334, "Lobby", true, true),
```

> ✅ **검증됨**: priority 334에 이미 PresetManager, RankingProfileSaveManager, TreasureBoxManager, PatrolManager가 공존. 동일 priority는 허용.

### 2-5. SaveData 저장 패턴

BunkerDefense와 WiggleDefender 모두 동일한 API 사용:
```csharp
await saveDataManager.LoadDataAsync<T>(ESaveDataType.Relics)
await saveDataManager.SaveDataAsync(ESaveDataType.Relics, data)
```
**단, `ESaveDataType` enum + `FirebaseKeys` 상수 추가 필요** (아래 수정 목록 참조)

### 2-6. ContentUnlockManager

BunkerDefense의 `EContentType` → WiggleDefender의 `EContentType` 에 추가:
```csharp
Feature_Relic,  // 유물 시스템 해금 (해금 레벨/조건은 기획 확인 필요 ⚠️ BLOCKER)
```

### 2-7. ⚠️ [신규] DamageCalculationManager 초기화 순서 문제 (중요)

`DamageCalculationManager`는 priority **175** (System, 게임 시작 직후 초기화).  
`RelicManager`는 priority **334** (Lobby, 훨씬 나중에 초기화).  

→ `DamageCalculationManager.RelicEffect.cs` partial에서 `RelicManager`를 직접 필드로 참조하면 초기화 전 NullReferenceException 발생.

**필수 패턴 — DamageCalculationManager.ChipEffect.cs 실제 코드 기반:**
```csharp
// DamageCalculationManager.RelicEffect.cs
public partial class DamageCalculationManager
{
    // ✅ ChipEffect.cs 실제 패턴: null 체크 후 GetManager<T>() 단축형 사용
    private RelicManager _relicManager;

    private float GetRelicPercentageDamageModifiers(EUnitType? unitType = null)
    {
        // ArkManager 체크 패턴 (ChipEffect.cs 동일 구조)
        var arkManager = Managers.Instance?.GetManager<ArkManager>();
        if (arkManager != null && arkManager.IsArkMode) return 0f;

        // lazy-init: BaseManager 내부이므로 GetManager<T>() 단축형 사용
        if (_relicManager == null)
        {
            _relicManager = GetManager<RelicManager>();
            if (_relicManager == null)
            {
                RLog.LogError("[RelicEffect] RelicManager 초기화되지 않음.");
                return 0f;
            }
        }
        // 이후 _relicManager 사용...
        return _relicManager.GetUnitDamageBonus(unitType);
    }
}
```
> ⚠️ `Managers.Instance?.GetManager<RelicManager>()` 대신 `GetManager<RelicManager>()` 단축형을 사용한다. 두 표현은 동일하지만 WD 내부 관례는 단축형.

### 2-8. ⚠️ [신규] ETargetItemType.Relic 이미 존재

`Core/Enums/ETargetItemType.cs`에 `Relic`이 **이미 정의됨**. 중복 추가 금지.  
단, `UI/Components/TargetDisplayComponent.cs`의 switch 문에 `case ETargetItemType.Relic:` 케이스가 없으므로 **이 케이스만 추가**해야 함.

### 2-9. ⚠️ [신규] RelicGachaProbabilityDataSource sync 불가

WD에는 `IGachaProbabilityDataSource` 인터페이스가 없음. WD의 `GachaProbabilityPopup`은 `EGachaType`을 직접 받아 `GachaManager`(칩 전용)에서 데이터를 가져오는 구조.  
**Relic 뽑기 확률 팝업**은 다음 둘 중 하나로 처리:
- **(권장)** `RelicGachaProbabilityPopup.cs` 신규 UI 파일 작성 (기존 GachaProbabilityPopup과 독립)
- EGachaType.Relic 추가 후 GachaProbabilityPopup 확장 (기존 팝업 수정 필요 → 리스크 있음)

> `RelicGachaProbabilityDataSource.cs`는 sync 대상에서 **제거**하거나 신규 팝업으로 흡수.  
> `Core/Gacha/` 폴더는 WD에 없으므로 해당 파일 배치 시 `Core/Managers/Relic/`에 병합.

### 2-10. ⚠️ [신규] 서버 API 호출 패턴 (CLAUDE.md 필수)

유물 뽑기 등 서버 API 호출 시 반드시 WD의 ServerLoadingPopupUI 패턴 적용:
```csharp
var popup = ServerLoadingPopupUI.Show("뽑기 중...");
try
{
    await serverManager.RelicGachaDrawAsync(count);
}
finally
{
    ServerLoadingPopupUI.Hide();
}
```

### 2-11. ⚠️ [신규] LocalizationManager 적용 (CLAUDE.md 필수)

BD에서 하드코딩된 한국어/영어 문자열 전부 교체:
```csharp
// Before (BunkerDefense)
headerText.text = "유물 강화";

// After (WiggleDefender)
headerText.text = LocalizationManager.GetLocalizedText("relic_upgrade_header");
```
> 로컬라이제이션 키가 WD 데이터시트에 없으면 기획팀과 사전 협의 필요. ⚠️ BLOCKER

### 2-12. ⚠️ [신규] CLAUDE.md 전체 준수 체크리스트

sync 작업 중 모든 파일에 아래 규칙이 적용됐는지 확인한다.

| 규칙 | BD 패턴 | WD 변환 | 해당 파일 |
|------|---------|---------|-----------|
| **비동기** | `async void` | `async UniTaskVoid` | RelicGachaMainUI, 모듈류 |
| **DOTween** | `tween.ToUniTask()` | `await tween.AsyncWaitForCompletion()` | 신화 스킬 컨트롤러, 뽑기 연출 |
| **이벤트 해제** | `subscription.Dispose()` | `EventManager.Unsubscribe` in `Cleanup()` | 모든 UI + RelicManager |
| **로컬라이제이션** | 하드코딩 문자열 | `LocalizationManager.GetLocalizedText("relic_*")` | 모든 UI 파일 |
| **리소스 로드** | `Resources.Load<T>()` | `ResourceManager.LoadResource<T>()` 또는 `LoadResourceAsync<T>()` | RelicIcon, RelicUtility |
| **시간** | `DateTime.Now` | `ServerTimeManager.NowUnscaled` | RelicGachaService (쿨타임 관련) |
| **오브젝트 탐색** | `FindObjectOfType<T>()` | `GetManager<T>()` | 전체 |
| **매직 넘버** | 리터럴 숫자 | `const` 또는 `[SerializeField]` | RelicManager (슬롯 수 4 등) |

**Localization 키 네이밍 규칙:**
```
접두사: relic_
예시 키 목록 (기획팀 등록 필요 ⚠️ BLOCKER):
  relic_grade_rare / relic_grade_epic / relic_grade_legendary / relic_grade_mythic
  relic_upgrade_header / relic_rankup_header / relic_unlock_header
  relic_gacha_title / relic_gacha_result_header
  relic_equip_slot_empty / relic_equip_slot_header
  relic_desc_popup_title
  relic_result_enhanced / relic_result_ranked_up
  route_relicgacha    ← EAcquisitionRouteType.RelicGacha 로컬라이제이션 키
```

### 2-13. ⚠️ [신규] 프리팹 및 스프라이트 에셋 sync

C# 스크립트 sync 후 UI 프리팹, 유물 아이콘 스프라이트, 연출 애니메이션을 별도로 sync해야 함.  
스크립트만 sync하면 Unity에서 MissingReference 에러 다수 발생.  
→ Phase 9 (에셋 sync) 별도 진행 필요 (5b/5c 프리팹 sync 플로우 적용).

---

## 3. 전체 파일 목록

### 3-1. 신규 생성 파일 (BunkerDefense → WiggleDefender 직접 sync 후 패턴 변환)

#### 📁 Core/Managers/Relic/ (신규 디렉토리)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicManager.cs` | 핵심 매니저 (초기화, 데이터 조회, 강화/랭크업 API) | ServiceAccessor → GetManager, MessageBroker → EventManager, BaseService → BaseManager |
| `RelicGachaService.cs` | 뽑기 비즈니스 로직 (확률, 천장, 로테이션) | ServiceAccessor → GetManager, MessageBroker → EventManager, 순수 C# 클래스 → RelicManager 내부 `new`로 생성 방식 확인 |
| `RelicGachaProbabilityDataSource.cs` | ~~`IGachaProbabilityDataSource` 구현~~ | ⚠️ **sync 불가** - WD에 인터페이스 없음. `RelicGachaProbabilityPopup.cs` 신규 작성으로 대체 |
| `RelicDataSOParser.cs` | JSON → RelicData 변환 파서 | 변환 없음 (정적 유틸) |
| `RelicRankupDataSOParser.cs` | JSON → RelicRankupDataData 변환 파서 | 변환 없음 |
| `RelicSkillDataSOParser.cs` | JSON → RelicSkillDataData 변환 파서 | 변환 없음 |

#### 📁 Data/Relic/ (신규 디렉토리)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicData.cs` | 밸런스 데이터 컨테이너 (읽기 전용) | 변환 없음 |
| `RelicSaveData.cs` | 플레이어 유물 저장 데이터 | 변환 없음 |

#### 📁 SOs/Class/DataSheet/ (DataSheet 자동생성 클래스)

> ⚠️ 이 파일들은 Google Sheets 자동생성 파일이므로 그대로 복사 가능

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

#### 📁 SOs/SO/DataSheet/ (ScriptableObject + Parser)

> ⚠️ SO 파일은 그대로 복사 가능. `[CreateAssetMenu]` 경로 충돌 여부 확인

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

#### 📁 Core/Managers/ (partial 클래스)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `DamageCalculationManager.RelicEffect.cs` | `DamageCalculationManager`의 유물 보너스 계산 partial | ⚠️ **lazy-init 캐싱 패턴 필수** (2-7 참조). 직접 필드 참조 금지 |

#### 📁 UI/Relic/Panel/ (신규 디렉토리)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicDescriptionPopup.cs` | 유물 설명 팝업 | UIBase 교체, ServiceAccessor → GetManager, 로컬라이제이션 적용 |
| `RelicDisplayComponent.cs` | 유물 그리드 아이콘 컴포넌트 | ServiceAccessor → GetManager |
| `RelicEquipPickerItemComponent.cs` | 장착 선택 리스트 아이템 | ServiceAccessor → GetManager |
| `RelicEquipPickerUI.cs` | 유물 장착 관리 팝업 (4슬롯) | UIBase 교체, ServiceAccessor → GetManager, 로컬라이제이션 적용 |
| `RelicEquippedDescComponent.cs` | 장착 유물 설명 컴포넌트 | ServiceAccessor → GetManager |
| `RelicEquippedSlotComponent.cs` | 장착 슬롯 컴포넌트 | 변환 없음 |
| `RelicIcon.cs` | 아이콘 애니메이터 | 변환 없음 |
| `RelicMainUI.cs` | 유물 메인 UI (창고/장착 탭) | UIBase 교체, ServiceAccessor → GetManager, MessageBroker → EventManager, 로컬라이제이션 적용 |

#### 📁 UI/Relic/ (신규 디렉토리)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicGachaMainUI.cs` | 뽑기 메인 팝업 | UIBase 교체, ServiceAccessor → GetManager, MessageBroker → EventManager, 서버 API 패턴 적용, 로컬라이제이션 적용 |
| `RelicGachaPopup.cs` | 뽑기 연출 팝업 | UIBase 교체, ServiceAccessor → GetManager |
| `RelicGachaProbabilityPopup.cs` | ⚠️ **신규 작성** (BD의 RelicGachaProbabilityDataSource 대체) | RelicManager에서 확률 데이터 직접 조회, WD 스타일로 신규 작성 |
| `RelicUtility.cs` | 정적 유틸 (색상, 스프라이트) | 변환 없음 |

#### 📁 UI/Relic/Upgrade/ (신규 디렉토리)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `RelicUpgradeModuleBase.cs` | 업그레이드 모듈 추상 베이스 | 변환 없음 (순수 C#) |
| `RelicUnlockModule.cs` | 해금 모듈 | ServiceAccessor → GetManager, 서버 API 패턴 적용 |
| `RelicLevelUpModule.cs` | 강화 모듈 | ServiceAccessor → GetManager, 서버 API 패턴 적용 |
| `RelicRankUpModule.cs` | 랭크업 모듈 | ServiceAccessor → GetManager, 서버 API 패턴 적용 |
| `RelicLevelBox.cs` | 레벨/랭크 변화 표시 컴포넌트 | 로컬라이제이션 적용 (MinionLevelBox.cs 패턴 참고) |
| `RelicResultPopup.cs` | 강화/랭크업 결과 팝업 | UIBase 교체, 로컬라이제이션 적용 |
| `RelicUpgradeUI.cs` | 강화/랭크업 메인 UI | UIBase 교체, ServiceAccessor → GetManager, MessageBroker → EventManager, 로컬라이제이션 적용 |

#### 📁 Core/Controllers/Dragoon/ (부분 클래스 신규)

| 파일명 | 역할 | 변환 필요 사항 |
|--------|------|----------------|
| `DragoonController.RelicSkill.cs` | Dragoon 신화 스킬 partial 클래스 | GetManager 패턴 확인, DOTween 사용 시 `await tween.AsyncWaitForCompletion()` (CLAUDE.md 준수) |

---

### 3-2. 기존 파일 수정 목록

#### 🔧 Enum 파일 수정

| 파일 | 추가 내용 |
|------|-----------|
| `Core/Enums/GameEnums.cs` | `ERelicGrade { Rare=-1, Epic=0, Legendary=1, Mythic=2 }` enum 추가<br>`ERelicSkillType { None, TurretDelayedExplosion, ZeusRapidFire, ... }` enum 추가 |
| `Core/Enums/ECurrencyType.cs` | Relic 조각 재화 (에픽/전설/신화/레어별 11~19종), 업그레이드 재화, 뽑기 티켓, 뽑기 상자 타입 추가 |
| `Core/Enums/ContentTypes.cs` | `Feature_Relic` 추가 (⚠️ 해금 레벨은 기획 확인 필요 — **BLOCKER**) |
| `Core/Enums/EGachaType.cs` | `Relic` 추가 (단, GachaManager는 칩 전용 → Relic 뽑기는 RelicGachaService가 담당) |
| `Core/Enums/GameEventTypes.cs` | `RelicAcquired, RelicEnhanced, RelicRankedUp, RelicEquipped, RelicUnequipped, RelicGachaDrawn` 추가 |
| `Core/Enums/ETargetItemType.cs` | ✅ **수정 불필요** — `Relic` 이미 존재 |
| `Core/Enums/EAcquisitionRouteType.cs` | ✅ **WD에 존재 확인됨** — `RelicGacha` 추가 필요. 주석 형식: `route_{EnumName}` |

**EAcquisitionRouteType 추가 내용:**
```csharp
// Core/Enums/EAcquisitionRouteType.cs 마지막 항목 뒤에 추가
RelicGacha,      // route_relicgacha - 유물 뽑기
```
> 로컬라이제이션 키 형식: `route_relicgacha` (기존 패턴: `route_gacha`, `route_minion` 등과 동일)

#### 🔧 Data/Config 파일 수정

| 파일 | 추가 내용 |
|------|-----------|
| `Core/Data/BalanceTableNames.cs` | `RELIC_DATA, RELIC_UPGRADE_DATA, RELIC_SKILL_DATA, RELIC_RANKUP_DATA, RELIC_BOX_DATA, RELIC_DROP_TABLE, RELIC_WEIGHT_TABLE, RELIC_ROTATE_TABLE, RELIC_GACHA_CONFIG, RELIC_PITY_DATA` 상수 10개 추가 |
| `Core/Managers/SaveDataTypes.cs` | `ESaveDataType.Relics`, `ESaveDataType.RelicGacha` 추가<br>`FirebaseKeys.RELICS = "relics"`, `RELIC_GACHA = "relicgacha"` 추가 |

#### 🔧 매니저 파일 수정

| 파일 | 수정 내용 |
|------|-----------|
| `Core/Managers/Managers.cs` | ⚠️ **ManagerFactory.cs 아님** — `MANAGER_DEFINITIONS` 배열에 추가. **삽입 위치: ChipEffectManager(333) 바로 뒤, PresetManager(334) 앞** |
| `Core/Managers/DamageCalculationManager.cs` | 기본 전투력 계산에 `GetRelicUnitDamageBonus()`, `GetRelicTypeAttackBonus()` 호출 추가 (RelicEffect partial 연동) |
| `Core/Managers/ContentUnlockManager.cs` | `_unlockConditions` 리스트(line ~253)에 `Feature_Relic` 조건 추가 |
| `Core/Managers/RedDotManager.cs` | `EnsureEssentialNodes()` 튜플 배열에 Relic 노드 추가 |
| `Core/Managers/FirebaseRemoteConfigManager.cs` | `IsRelicGachaEnabled` bool 프로퍼티 추가 |
| `Core/Managers/AcquisitionRouteManager.cs` | `GetTargetUIType()` switch에 `RelicGacha` case 추가 |

**Managers.cs 삽입 코드:**
```csharp
// ChipEffectManager(333) 다음 줄에 추가
new ManagerDefinition(typeof(RelicManager), 334, "Lobby", true, true), // 유물 시스템 매니저
```

**ContentUnlockManager.cs 추가 코드:**
```csharp
// _unlockConditions 리스트 (line ~253) 의 Feature_Minion(40) 다음에 추가
new ContentUnlockCondition(EContentType.Feature_Relic, ??), // ⚠️ BLOCKER: 해금 레벨 기획 확인 필요
```

**RedDotManager.cs 추가 코드:**
```csharp
// EnsureEssentialNodes() 내 튜플 배열에 추가 (Minion 노드 그룹 다음 권장)
("Lobby.Relic",                    "Lobby",             "유물"),
("Lobby.Relic.RelicGacha",         "Lobby.Relic",       "유물 가챠"),
("Lobby.Relic.RelicGacha.pity",    "Lobby.Relic.RelicGacha", "유물 가챠 천장"),
("Lobby.Relic.RelicUpgrade",       "Lobby.Relic",       "유물 강화"),
```

**AcquisitionRouteManager.cs 추가 코드:**
```csharp
// GetTargetUIType() switch에 추가
case EAcquisitionRouteType.RelicGacha:
    return (typeof(RelicGachaMainUI), true);
```

#### 🔧 UI 파일 수정

| 파일 | 수정 내용 |
|------|-----------|
| `UI/LobbyMainUI.cs` | `_relicGachaButton` 추가, `OnRelicGachaButtonClicked()` → `Show<RelicGachaMainUI>()`, 해금/리모트컨피그 조건으로 버튼 가시성 관리 |
| `UI/UnitUpgradeUI.cs` | `_relicButton` 추가, `OnRelicButtonClicked()` → `Show<RelicMainUI>()`, 레드닷 컴포넌트 연결 |
| `UI/Components/TargetDisplayComponent.cs` | ⚠️ **`ETargetItemType.Relic` case 추가** — enum은 이미 있지만 switch 케이스 없음. `RelicIcon` 컴포넌트 연결 |
| `UI/Shop/GachaUI.cs` (존재 시) | 유물 뽑기 티켓 표시 UI 추가 |

#### 🔧 유닛 컨트롤러 수정 (신화 스킬 sync)

| 파일 | 신화 스킬 타입 | 수정 내용 |
|------|---------------|-----------|
| `Core/Controllers/BaseClass/UnitController.cs` | - | `protected virtual ERelicSkillType RelicSkillType => ERelicSkillType.None;`<br>`protected virtual void InitializeRelicSkills() {}`<br>`protected virtual void OnApplyRelicRankEffect(RelicSkillDataData data) {}` 추가 |
| `ArchonController.cs` (+ LaserCore/LaserDamage/Types) | `ZeusRapidFire` | rank0: 레이저 간격 감소, rank5: 부채꼴 레이저(`LaserType.RelicFan`), rank10: 취약 보너스 |
| `DrFrostController.cs` + `BlizzardController.cs` | `DrFrostBlizzardGrowth` | rank0: 블리자드 범위 성장, rank5: 냉동 효과, rank10: 냉동 폭발 |
| `MarauderController.cs` + `ExplosiveProjectileController.cs` | `MarauderShotgunBlast` | rank0: 벅샷 발사, rank5: 취약 디버프, rank10: 지뢰 생성 |
| `TemplerController.cs` | `TemplerMultiHit` | rank0: 다중 히트, rank5: 마비 추가 피해, rank10: 마비 해제 피해 |
| `TurretController.cs` | `TurretDelayedExplosion` | rank0: 지연 폭발, rank5: 존 피해 증가, rank10: 점화 부여 |
| `NinjaController.cs` | `NinjaMythic` | rank0: 중상 부여, rank10: 중상 보너스 피해 |
| `AirManController.cs` + `AirManProjectile.cs` | `AirManWindExtra` | rank0: 추가 폭풍 발사, rank10: 폭풍 성장 효과 |
| `ThorController.cs` + `HammerProjectile.cs` | `ThorElectricPull` | rank0: 전기장 활성화, rank5: 지속시간 증가, rank10: 당김 효과 |
| `VesselController.cs` + `MovingVesselController.cs` | `VesselDefensiveShield` | rank0: 방어 실드, rank5: 마비 효과, rank10: 폭발 효과 |
| `CarrierController.cs` + `InterceptorController.cs` | `CarrierSpecialInterceptor` | rank0: 특수 요격기 활성화 |
| `DragoonController.cs` | `DragoonLaserBind` | `DragoonController.RelicSkill.cs` partial 연동 (신규 파일) |

#### 🔧 에디터 유틸 수정

| 파일 | 수정 내용 |
|------|-----------|
| `Utils/Editor/JsonToSO.cs` | Relic 관련 SO 변환 케이스 추가 (RelicPityData, RelicDropData, RelicWeightData, RelicRotateTable, RelicGachaConfigData, RelicRankupData, RelicBoxData) |

---

## 4. sync 순서 (의존성 역순)

의존성이 없는 것부터 먼저, 의존성이 있는 것은 나중에 작업.

### Phase 1 - 타입/데이터 정의 (의존성 없음)
1. `GameEnums.cs` → `ERelicGrade`, `ERelicSkillType` 추가
2. `ECurrencyType.cs` → Relic 재화 타입 추가
3. `ContentTypes.cs` → `Feature_Relic` 추가
4. `EGachaType.cs` → `Relic` 추가
5. `GameEventTypes.cs` → Relic 이벤트 타입 6개 추가
6. `BalanceTableNames.cs` → RELIC_* 테이블 이름 10개 추가
7. `SaveDataTypes.cs` → `Relics`, `RelicGacha` 추가
8. DataSheet Data 클래스 13개 복사 (`RelicBoxDataData.cs` 등)

### Phase 2 - 순수 데이터/SO 파일 (Phase 1 의존)
9. `RelicData.cs`, `RelicSaveData.cs` 복사
10. `RelicGachaResult.cs`, `RelicGachaProbabilityEntry.cs` 복사
11. SO 클래스 17개 복사 (`RelicDataSO.cs` 등)
12. SO Parser 클래스 복사 (`RelicDataSOParser.cs` 등)

### Phase 3 - 핵심 매니저 (Phase 1~2 의존)
13. `RelicManager.cs` sync (ServiceAccessor → GetManager, MessageBroker → EventManager)
14. `RelicGachaService.cs` sync (ServiceAccessor → GetManager)
15. `DamageCalculationManager.RelicEffect.cs` sync (partial 클래스, **lazy-init 필수**)

### Phase 4 - 기존 매니저 연동 (Phase 3 의존)
16. `Managers.cs` → RelicManager 등록 (priority: 334)
17. `DamageCalculationManager.cs` → RelicEffect 호출 연동 (**null-safe 필수**)
18. `ContentUnlockManager.cs` → Feature_Relic 추가
19. `RedDotManager.cs` → Relic 레드닷 노드 추가
20. `FirebaseRemoteConfigManager.cs` → IsRelicGachaEnabled 추가
21. `AcquisitionRouteManager.cs` → Relicgacha 경로 추가

### Phase 5 - UI 시스템 (Phase 3~4 의존)
22. `RelicUtility.cs` 복사
23. `RelicIcon.cs` 복사
24. `RelicLevelBox.cs` sync (**LocalizationManager 적용**, MinionLevelBox.cs 참고)
25. `RelicUpgradeModuleBase.cs` sync
26. `RelicUnlockModule.cs`, `RelicLevelUpModule.cs`, `RelicRankUpModule.cs` sync (**서버 API 패턴**)
27. `RelicDisplayComponent.cs`, `RelicEquippedSlotComponent.cs` 등 컴포넌트 sync
28. `RelicResultPopup.cs`, `RelicDescriptionPopup.cs` sync
29. `RelicEquipPickerUI.cs` sync
30. `RelicMainUI.cs` sync
31. `RelicUpgradeUI.cs` sync
32. `RelicGachaPopup.cs` sync
33. `RelicGachaMainUI.cs` sync (**서버 API 패턴**)
34. `RelicGachaProbabilityPopup.cs` **신규 작성** (BD의 RelicGachaProbabilityDataSource 대체)

### Phase 6 - 기존 UI 연동 (Phase 5 의존)
35. `LobbyMainUI.cs` → 유물 뽑기 버튼 추가
36. `UnitUpgradeUI.cs` → 유물 버튼 추가
37. `TargetDisplayComponent.cs` → **`ETargetItemType.Relic` case 추가** (enum은 추가 불필요)

### Phase 7 - 유닛 컨트롤러 신화 스킬 (Phase 3 의존)
38. `UnitController.cs` → RelicSkill 기본 virtual 메서드 추가
39. 각 유닛 컨트롤러 신화 스킬 구현 (11개 유닛)
40. `DragoonController.RelicSkill.cs` 신규 파일 추가

### Phase 8 - 에디터 도구
41. `JsonToSO.cs` → Relic SO 변환 추가

### Phase 9 - 프리팹/에셋 sync ⚠️ [신규]
42. BD → WD: `UI/Relic/` 하위 프리팹 전체 복사 + GUID 교체
43. BD → WD: 유물 아이콘 스프라이트 아틀라스 복사
44. BD → WD: 뽑기 연출 애니메이션 클립 복사
45. Unity Inspector에서 MissingReference 전수 점검

---

## 5. 파일별 sync 가이드

### RelicManager.cs (가장 복잡)

```csharp
// Before (BunkerDefense)
public class RelicManager : BaseService, IRelicManager
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
    private SaveDataManager SaveDataManager => Managers.Instance.GetManager<SaveDataManager>();
    
    public override async UniTask InitializeAsync()
    {
        // EventManager 구독 없음 (RelicManager는 발행만)
        ...
    }
    
    private void NotifyRelicAcquired(int relicId)
    {
        EventManager.Dispatch(GameEventType.RelicAcquired, 
            new RelicEventData { RelicId = relicId });
    }
    
    public override void Cleanup()
    {
        // EventManager는 Unsubscribe 필요 시 여기서
    }
}
```

### RelicMainUI.cs (이벤트 구독 패턴)

```csharp
// Before (BunkerDefense)
protected override void OnOpened()
{
    _subscriptions.Add(
        _messageBroker.Subscribe<RelicAcquiredMessage>(_ => RefreshCurrentTab())
    );
    _subscriptions.Add(
        _messageBroker.Subscribe<CurrencyChangedEventData>(_ => RefreshWarehouseRedDots())
    );
}

protected override void OnClosed()
{
    _subscriptions.ForEach(s => s.Dispose());
    _subscriptions.Clear();
}

// After (WiggleDefender)
protected override void OnOpened()
{
    EventManager.Subscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicAcquired);
    EventManager.Subscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicEnhanced);
    EventManager.Subscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicRankedUp);
    EventManager.Subscribe<CurrencyEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
}

protected override void OnClosed()
{
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicAcquired, OnRelicAcquired);
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicEnhanced, OnRelicEnhanced);
    EventManager.Unsubscribe<RelicEventData>(GameEventType.RelicRankedUp, OnRelicRankedUp);
    EventManager.Unsubscribe<CurrencyEventData>(GameEventType.CurrencyChanged, OnCurrencyChanged);
}
```

### 유닛 컨트롤러 신화 스킬 패턴

**UnitController.cs 구조 (WD 실제 확인):**
- `Start()` → `StartBehavior()` (virtual, 각 유닛에서 override)
- `InitializeAsync()` (abstract) → 유닛 데이터 설정 후 호출됨
- `ApplyRelicSkills()`는 **`InitializeAsync()` 완료 후** 호출해야 함 (유닛 데이터가 먼저 설정돼야 함)

```csharp
// UnitController.cs에 추가 (protected virtual 메서드들)
protected virtual ERelicSkillType RelicSkillType => ERelicSkillType.None;
protected virtual void OnApplyRelicRankEffect(RelicSkillDataData data) { }

// ✅ 훅 포인트: StartBehavior() 말미에 호출
protected virtual void StartBehavior()
{
    // ... 기존 로직 ...
    ApplyRelicSkills();  // 마지막에 추가
}

private void ApplyRelicSkills()
{
    if (RelicSkillType == ERelicSkillType.None) return;
    // BaseManager 외부이므로 Managers.Instance 경유
    var relicManager = Managers.Instance?.GetManager<RelicManager>();
    if (relicManager == null) return;
    var skillDataList = relicManager.GetRelicSkillData(RelicSkillType);
    foreach (var data in skillDataList)
    {
        if (relicManager.CanUseRelicSkill(RelicSkillType, data.rank))
            OnApplyRelicRankEffect(data);
    }
}
```

**신화 스킬 DOTween 패턴 (CLAUDE.md 필수):**
```csharp
// ❌ 금지
await tween.ToUniTask();

// ✅ 올바른 방식
await tween.AsyncWaitForCompletion();

// ✅ async UniTaskVoid (fire-and-forget, async void 금지)
private async UniTaskVoid PlayRelicSkillEffectAsync()
{
    var tween = transform.DOScale(1.2f, 0.3f);
    await tween.AsyncWaitForCompletion();
    // ...
}
```

**⚠️ Archon 구조 주의:**
WD의 Archon은 partial 파일이 **14개**다 (`ArchonController.Animation.cs`, `.Attack.cs`, `.Audio.cs`, `.CardEffects.cs`, `.ChipEffect.cs`, `.Debuff.cs`, `.Effects.cs`, `.Helpers.cs`, `.LaserCore.cs`, `.LaserDamage.cs`, `.LaserUpdate.cs`, `.Rupture.cs`, `.Sweeping.cs`, `.Types.cs`).
신화 스킬은 기존 파일 수정 대신 **`ArchonController.RelicSkill.cs` 신규 partial 파일 추가** 권장.
`LaserType.RelicFan` 추가는 `ArchonController.Types.cs`에서 처리.

---

## 6. 누락 검증 체크리스트

역순 분석으로 누락 여부 검증.

### UI 계층 → 매니저 계층 검증
- [x] `RelicMainUI` → `RelicManager` 필요 메서드 전부 구현됨
- [x] `RelicUpgradeUI` → `RelicManager.EnhanceRelic()`, `RankUpRelic()` 구현됨
- [x] `RelicGachaMainUI` → `RelicGachaService.DrawRelics()`, `CanRelicGacha()` 구현됨
- [x] `RelicEquipPickerUI` → `RelicManager.ApplyEquipPlan()` 구현됨

### 매니저 계층 → 데이터 계층 검증
- [x] `RelicManager` → `RelicData`, `RelicSaveData`, `RelicUpgradeDataData`, `RelicRankupDataData`, `RelicSkillDataData` 전부 정의됨
- [x] `RelicGachaService` → `RelicGachaResult`, `RelicGachaSaveData`, `RelicRotateTableData`, `RelicWeightDataData`, `RelicPityDataData` 전부 정의됨

### 데이터 계층 → Enum 계층 검증
- [x] `ERelicGrade` 사용처: `RelicDataData`, `RelicSaveData`, `RelicRankupDataData`, `RelicDropDataData`
- [x] `ERelicSkillType` 사용처: `RelicDataData`, `RelicSkillDataData`, `UnitController`
- [x] `ECurrencyType` 사용처: `RelicBoxDataData`, `RelicWeightDataData`, `RelicPityDataData`, `RelicGachaService`

### 저장 시스템 검증
- [x] `ESaveDataType.Relics` → `RelicSystemSaveData` (플레이어 보유/장착)
- [x] `ESaveDataType.RelicGacha` → `RelicGachaSaveData` (천장 카운트, 보장 카운터)

### 이벤트 시스템 검증
- [x] `RelicManager` 발행: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`, `RelicEquipped`, `RelicUnequipped`
- [x] `RelicGachaService` 발행: `RelicGachaDrawn`
- [x] `RelicMainUI` 구독: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`, `CurrencyChanged`
- [x] `RelicUpgradeUI` 구독: `CurrencyChanged`
- [x] `RelicGachaMainUI` 구독: `CurrencyChanged`
- [x] `RedDotManager` 구독: `RelicAcquired`, `RelicEnhanced`, `RelicRankedUp`

### 신화 스킬 검증 (11개 유닛)
- [x] `TurretDelayedExplosion` ← `TurretController`
- [x] `ZeusRapidFire` ← `ArchonController` (LaserCore, LaserDamage, Types 포함)
- [x] `TemplerMultiHit` ← `TemplerController`
- [x] `DrFrostBlizzardGrowth` ← `DrFrostController` + `BlizzardController`
- [x] `DragoonLaserBind` ← `DragoonController` + `DragoonController.RelicSkill.cs`
- [x] `MarauderShotgunBlast` ← `MarauderController` + `ExplosiveProjectileController`
- [x] `VesselDefensiveShield` ← `VesselController` + `MovingVesselController`
- [x] `CarrierSpecialInterceptor` ← `CarrierController` + `InterceptorController`
- [x] `NinjaMythic` ← `NinjaController`
- [x] `ThorElectricPull` ← `ThorController` + `HammerProjectile`
- [x] `AirManWindExtra` ← `AirManController` + `AirManProjectile`

### 기타 연동 검증
- [x] `DamageCalculationManager` → `RelicEffect.cs` partial 연동 (lazy-init + `GetManager<T>()` 단축형)
- [x] `LobbyMainUI` → 유물 뽑기 버튼 + 해금/리모트컨피그 조건
- [x] `ContentUnlockManager` → `Feature_Relic` + `_unlockConditions` 배열 추가
- [x] `RedDotManager` → `Lobby.Relic.*` 4개 노드 추가
- [x] `FirebaseRemoteConfigManager` → `IsRelicGachaEnabled`
- [x] `BalanceDataManager` → RELIC_* 10개 테이블 로드 확인
- [x] `JsonToSO.cs` → Relic SO 변환 7종 추가
- [x] `TargetDisplayComponent.cs` → `ETargetItemType.Relic` case 추가 (enum은 이미 존재)
- [x] `EAcquisitionRouteType.cs` → `RelicGacha` 추가 (WD에 존재 확인, 로컬라이제이션 키: `route_relicgacha`)
- [x] `AcquisitionRouteManager.cs` → `GetTargetUIType()` switch에 `RelicGacha → RelicGachaMainUI` 케이스 추가
- [x] `ArchonController.RelicSkill.cs` 신규 partial 파일 추가 (기존 14개 partial 파일과 별도)
- [x] `LaserType.RelicFan` → `ArchonController.Types.cs`에 추가
- [x] CLAUDE.md 전체 준수: async UniTaskVoid, DOTween.AsyncWaitForCompletion(), LocalizationManager, ResourceManager, GetManager

### ⚠️ BLOCKER 목록 (sync 시작 전 확인 필수)
- [ ] **[BLOCKER-1]** `Feature_Relic` 해금 레벨 — 기획팀 확인 필요 (ContentUnlockManager `_unlockConditions`)
- [ ] **[BLOCKER-2]** Localization 키 17종 (`relic_*`) — 데이터시트 사전 등록 필요
- [ ] **[BLOCKER-3]** `route_relicgacha` 로컬라이제이션 키 — 데이터시트 등록 필요
- [ ] **[BLOCKER-4]** 신화 스킬 rank effect 정의서 — 11개 유닛 × rank 0/5/10 효과값 (`arg1~7` 매핑) BD 소스에서 확인 후 Phase 7 진입
- [ ] **[BLOCKER-5]** 프리팹/스프라이트 에셋 sync (Phase 9) — C# 완성 후 별도 진행

---

## 부록 - BunkerDefense 소스 경로 참조

> ⚠️ 소스 프로젝트는 remote `temp-bunker` 브랜치. 실제 경로는 sync 작업 전 확인 필요.

```
BunkerDefense/Assets/_Project/1_Scripts/
├── Core/
│   ├── Base/ManagerFactory.cs  ← ⚠️ WD는 Managers.cs로 통합
│   ├── Controllers/
│   │   ├── Archon/ArchonController.cs (.LaserCore .LaserDamage .Types)
│   │   ├── BaseClass/UnitController.cs
│   │   ├── Carrier/CarrierController.cs, InterceptorController.cs
│   │   ├── DrFrost/DrFrostController.cs, BlizzardController.cs
│   │   ├── Dragoon/DragoonController.cs, .RelicSkill.cs
│   │   ├── Marauder/MarauderController.cs, ExplosiveProjectileController.cs
│   │   ├── Templer/TemplerController.cs
│   │   ├── Thor/ThorController.cs, HammerProjectile.cs
│   │   ├── Turret/TurretController.cs
│   │   ├── Units/AirManController.cs, NinjaController.cs, ThorController.cs
│   │   │   └── Projectiles/AirManProjectile.cs
│   │   └── Vessel/VesselController.cs, MovingVesselController.cs
│   ├── Data/BalanceTableNames.cs
│   ├── Enums/ContentTypes.cs, ECurrencyType.cs, EEffectType.cs, EGachaType.cs, ETargetItemType.cs, GameEnums.cs
│   ├── Gacha/RelicGachaProbabilityDataSource.cs  ← ⚠️ WD에 sync 불가, 신규 팝업으로 대체
│   └── Managers/
│       ├── AcquisitionRouteManager.cs
│       ├── ContentUnlockManager.cs
│       ├── CurrencyManager.cs
│       ├── DamageCalculationManager.cs, .RelicEffect.cs
│       ├── FirebaseRemoteConfigManager.cs
│       ├── RedDotManager.cs
│       ├── SaveDataManager.cs
│       ├── SaveDataTypes.cs
│       └── Relic/
│           ├── RelicDataSOParser.cs
│           ├── RelicGachaService.cs
│           ├── RelicManager.cs
│           ├── RelicRankupDataSOParser.cs
│           └── RelicSkillDataSOParser.cs
├── Data/Relic/
│   ├── RelicData.cs
│   └── RelicSaveData.cs
├── SOs/
│   ├── Class/DataSheet/  (RelicBoxDataData.cs 외 12종)
│   └── SO/DataSheet/     (RelicDataSO.cs 외 16종)
└── UI/
    ├── LobbyMainUI.cs
    ├── Components/TargetDisplayComponent.cs
    ├── Minion/Upgrade/MinionLevelBox.cs  ← RelicLevelBox 참고용
    ├── Relic/
    │   ├── Panel/ (RelicMainUI.cs 외 7종)
    │   ├── RelicGachaMainUI.cs, RelicGachaPopup.cs, RelicUtility.cs
    │   └── Upgrade/ (RelicUpgradeUI.cs 외 6종)
    ├── Shop/GachaUI.cs
    └── UnitUpgradeUI.cs
```

---

*이 문서는 BunkerDefense relic 파일 전수 분석 + WiggleDefender 실제 코드베이스 대조 검증을 통해 작성/수정되었습니다.*  
*WD 코드베이스 검증일: 2026-05-03*
