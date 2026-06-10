# 뱅가드 모듈 시스템 구현 계획

> 분석 기준: `feature/juwon/vanguard` 브랜치의 뱅가드 코드 + 현재 Ark 모듈 시스템.
> 뱅가드 전용 모듈 4종 데이터 테이블과 ArkModuleData 35종을 비교 분석한 결과 및 구현 계획.

---

## 1. 분석 결론 요약

| 뱅가드 모듈 | 효과 | Ark 대응 | 판정 |
|---|---|---|---|
| 1. 열세 시 카드 획득 (20/40/60초) | 해당 시점에 아군이 열세면 무작위 카드 1장 | `PeriodicCardSelection`(아크 34번) — **의미 불일치** | **기존 뱅가드 로직 재활용** — 메커니즘이 이미 `VanguardStagePlayService.CheckBonusCard()`에 기본 룰로 구현돼 있음. 모듈 게이트만 추가 |
| 2. 매 턴(라운드) 시작 시 카드 1장 | 무작위 활성화 가능 카드 획득 | `StageStartCardSelection`(아크 5번) 유사 | **신규 타입** + 카드 지급 파이프라인(`GrantVanguardBonusCard`) 재활용 |
| 3. 칩 뽑기 새로고침 1회 | 칩 가챠 결과 reroll | 없음 (`GachaExtraSlot`/`NormalGachaExtraCardChance` 계열이 개념상 유사) | **완전 신규** — `VanguardChipGachaService` 훅 + UI 작업 필요 |
| 4. 시즌 최대 순찰 시간 14시간 | 순찰 누적 상한 증가 | 없음 (`MembershipManager.GetTotalPatrolMaxTimeIncrease()` 패턴이 선례) | **신규 타입** + 기존 순찰 상한 훅 패턴 재활용 |

핵심: **효과 4종 중 재활용할 수 있는 것은 "효과 구현"이 아니라 "인프라"다.**
Ark 모듈 시스템의 데이터 구조·서비스 아키텍처·저장/시즌 리셋·획득(가중치 추첨)·UI를 그대로 가져오고, 효과 타입 4종은 모두 뱅가드 측 신규 enum 값으로 추가하는 것을 권장한다.

---

## 2. 재활용 대상 (Ark 모듈 인프라)

### 2.1 데이터 구조 — 그대로 재활용
`ArkModuleDataData`(자동생성)와 뱅가드 모듈 테이블의 컬럼이 완전히 동일하다.

```csharp
// Assets/_Project/1_Scripts/SOs/Class/DataSheet/ArkModuleDataData.cs
public int moduleId;
public string moduleName;          // 로컬라이제이션 키 (vanguard_module_name_N)
public string moduleDescription;   // 로컬라이제이션 키
public EModuleType moduleType;     // 공유 enum
public List<float> effectValues;
public int weight;
```

→ 구글 시트에서 `VanguardModuleDataData` / `VanguardModuleDataSO` 자동생성 (`SOs/SO/DataSheet/` — **직접 수정 금지**, 커스텀 로직 필요 시 `VanguardModuleDataParser.cs` 별도 생성).

`EModuleType`(`Core/Enums/EModuleType.cs`)은 아크 전용 네임스페이스가 아닌 전역 공유 enum이므로 뱅가드 값을 같은 enum에 추가하면 된다 (§4.1).

### 2.2 서비스 아키텍처 — 패턴 재활용
`ArkModuleService`(`Core/Managers/ArkServices/ArkModuleService.cs`, 2174줄)의 구조:

- 소유/활성 분리: `saveData.ownedModules` / `activeModules` (`List<string>`)
- 조회: `IsModuleActive(id)`, `IsModuleOwned(id)`, `GetActiveModulesByType(EModuleType)`, `GetAllActiveModules()`
- 효과 합산: `CalculateModuleEffect(EModuleType, effectIndex)` — 활성 모듈 순회 후 합산
- 획득: `AddModule(id)` — 소유+자동 활성화+이벤트 발송
- 런타임 상태: `ResetRuntimeState()` — 전투 시작 시 1회성 트리거 플래그 초기화
- 의존성은 생성자 콜백 주입 (`Func<ArkSaveDataType>`, `Action _save`, `Func<bool> _getIsArkMode` 등)

→ 뱅가드는 이미 `VanguardStatService`("ArkStatService 패턴 통일"), `VanguardRankService` 등 **Ark 서비스를 POCO로 미러링하는 관례**가 있다. 같은 방식으로 `VanguardModuleService`(POCO)를 신설한다.

### 2.3 시즌 리셋 — 패턴 재활용
```csharp
// ArkSeasonService.cs:245-248
saveData.ownedModules.Clear();
saveData.activeModules.Clear();
```
→ `VanguardSeasonService.ResetSeasonProgress()`에 동일 처리 추가. 모듈 4("시즌동안")가 명시하듯 뱅가드 모듈은 시즌 스코프.

### 2.4 획득(가중치 추첨) — 패턴 재활용
`ArkGachaService`의 모듈 추첨 구조: `weight` 기반 추첨, `_addModule` / `_isModuleOwned` 콜백, 미보유 후보 소진 시 Fallback, 선택지 노출(`ArkModulePackageService`의 3택 선택 UI도 재활용 후보). 뱅가드 모듈 4종 모두 weight=1이므로 균등 추첨으로 시작 가능.

### 2.5 UI — 재활용
`ArkModuleListPopup`, `ArkModuleDetailPopup`, `ArkModuleSlot`, `ArkModuleIconSlot` (`UI/Ark/`) → 뱅가드 스킨으로 복제 또는 데이터소스 추상화 후 공용화. 설명 텍스트는 테이블의 로컬라이제이션 키 사용 (`LocalizationManager.GetLocalizedText()` — 하드코딩 금지).

---

## 3. 재활용 불가/주의 대상 (Ark 모듈 35종 분류)

향후 뱅가드 모듈을 확장할 때를 위한 분류:

**전투 범용 — 뱅가드에서 재사용 가능 (조건부)**
타입별 최종피해 6종(`IceEnemyDamageBonus` 등), `TimeBasedDamageBonus`, `AttackToHealthBonus`(디버프 대상 피해), `PeriodicEnemySlowdown`, `PeriodicEnemyDamage`, `TimedRandomUnitCooldownBonus`, `TimedRandomUnitsDamageBonus`, `BunkerDamageReduction`(상시 피해 증가), `ModuleCountDamageBonus`, `CardCountAttackBonus`.
뱅가드 전투는 동일한 유닛/적/카드/데미지 시스템(`BaseStagePlayService` 기반) 위에서 돌아가므로 기술적으로 재사용 가능하다. 단, **뱅가드는 비동기 PvP라서 전투력에 직접 개입하는 모듈은 매치 공정성·서버 재검증 설계가 선행돼야 한다** (§4.6).

**저지율(resistance rate) 의존 — 재해석 필요**
`LowHealthCardSelection`, `HealthThresholdCooldownReset`, `EliteHealthReduction`/`EliteEnemyDamageReduction`(저지율 임계 데미지), `HealOnKillChance`(부활), `LowHealthDamageBonus`, `SuicideEnemyDamageReduction`/`StartBattleShield`(게임오버 직전 효과). 아크의 저지율/게임오버 개념에 묶여 있어 뱅가드 라운드 구조(클리어 타임 경쟁)와 맞지 않음.

**아크 경제 전용 — 재활용 불가 (개념만 차용)**
`ArkGemRewardBonus`, `SpecialGachaCostCap`, `GachaGoldBonus`, `StatUpgradeGoldCostCap`, `StageRewardDoubleChance`, `NormalGachaExtraCardChance`, `GachaExtraSlot`. 아크 재화·카드 가챠에 종속. 다만 "가챠/경제에 개입하는 모듈"이라는 설계 선례 자체는 뱅가드 모듈 3(칩 새로고침)의 근거가 된다.

---

## 4. 구현 설계

### 4.1 EModuleType 신규 값 추가

```csharp
// Core/Enums/EModuleType.cs 에 추가
/// <summary>
/// [뱅가드] 전투 중 지정 시점들에 아군이 열세면 무작위 카드 1장 획득
/// effectValues: 체크 시점 목록 (초 단위, 기본: 20, 40, 60)
/// </summary>
VanguardTimedCatchupCardSelection,

/// <summary>
/// [뱅가드] 매 라운드 시작 시 무작위 활성화 가능 카드 획득
/// effectValues[0]: 카드 수 (기본: 1)
/// </summary>
VanguardRoundStartCardSelection,

/// <summary>
/// [뱅가드] 칩 뽑기 결과 새로고침(reroll) 가능
/// effectValues[0]: 새로고침 횟수 (기본: 1)
/// </summary>
VanguardChipGachaRefresh,

/// <summary>
/// [뱅가드] 시즌 동안 최대 순찰 누적 시간 상한 설정
/// effectValues[0]: 상한 (시간 단위, 기본: 14)
/// </summary>
VanguardPatrolMaxTimeCap,
```

**주의 — 모듈 1의 시트 타입**: 테이블에는 `PeriodicCardSelection`으로 기입돼 있으나, 아크 34번의 `PeriodicCardSelection`은 "{0}초 **주기**, 최대 {1}회" 의미이고 뱅가드 1번은 "{0},{1},{2}초 **시점** + 열세 조건"이다. effectValues 해석이 달라 같은 값을 공유하면 핸들러가 모드 분기로 오염된다. **신규 값 `VanguardTimedCatchupCardSelection`으로 시트 수정 권장.** (불가하면 핸들러에서 `IsVanguardMode()` 분기 — 차선책)

### 4.2 저장 데이터

```csharp
// SaveDataTypes.cs — VanguardSaveData 에 추가 (ArkSaveDataType 동형)
public List<string> ownedModules = new();   // 보유 모듈 (moduleId.ToString())
public List<string> activeModules = new();  // 활성 모듈
```

- 저장: `SaveDataAsync(ESaveDataType.Vanguard, data)` 경유 (SavePlayerDataAsync 금지)
- 시즌 리셋: `VanguardSeasonService.ResetSeasonProgress()`에서 두 리스트 Clear

### 4.3 VanguardModuleService (신규 POCO)

위치: `Core/Managers/Vanguard/VanguardModuleService.cs`
`VanguardManager`가 생성·보유 (칩 서비스들과 동일한 소유 구조).

```csharp
public sealed class VanguardModuleService
{
    public VanguardModuleService(
        Func<VanguardSaveData> getSaveData,
        Func<UniTask> saveAsync);                       // 칩 서비스와 동일한 주입 방식

    // ArkModuleService 동형 API (재활용)
    public bool IsModuleOwned(int moduleId);
    public bool IsModuleActive(int moduleId);
    public void AddModule(int moduleId);                // 획득 + 자동 활성화 + 이벤트
    public List<VanguardModuleDataSO> GetActiveModulesByType(EModuleType type);
    public float CalculateModuleEffect(EModuleType type, int effectIndex = 0);
    public void ResetRuntimeState();                    // 라운드/매치 시작 시

    // 뱅가드 모듈 4종 전용 조회 (ArkModuleService의 타입별 메서드 패턴)
    public IReadOnlyList<float> GetCatchupCardTimes();  // 모듈1: 없으면 null → 기본 룰 폴백 여부는 §5 결정
    public int GetRoundStartCardCount();                // 모듈2: 0이면 미보유
    public int GetChipGachaRefreshCount();              // 모듈3
    public bool TryGetPatrolMaxHoursCap(out int hours); // 모듈4
}
```

이벤트가 필요하면 `EventManager`(static) 사용, 구독 해제는 `Cleanup()`에서.

### 4.4 효과별 훅 포인트

**모듈 1 — 열세 시 카드 (재활용도 최상)**
`VanguardStagePlayService`에 이미 동일 메커니즘이 기본 룰로 존재:

```csharp
// VanguardStagePlayService.cs
private static readonly float[] BONUS_CARD_TIMES = { 20f, 40f, 60f }; // §5-3
private void CheckBonusCard()  // 내 잔여 적 > 고스트 잔여 적이면 GrantVanguardBonusCard()
```

변경:
- `BONUS_CARD_TIMES` 상수 → 모듈 보유 시 `GetCatchupCardTimes()`(effectValues)로 대체
- 모듈 미보유 시 동작(기본 룰 유지 vs 기능 자체를 모듈화) 기획 확정 필요 (§6-③)
- `GrantVanguardBonusCard()`의 카드 풀 필터·`_matchRng` 결정론·`_pendingBonusCards` 서버 제출은 그대로 재사용

**모듈 2 — 라운드 시작 카드**
- 훅: `RunSingleRoundAsync(round, token)` 시작부 (또는 `ResetRoundPhaseState()` 직후)
- "무작위로 활성화 가능 카드" = `GrantVanguardBonusCard()`의 풀 구성(배치 유닛 대상 카드 − 기보유)과 동일 → 카드 수 파라미터만 받도록 메서드 분리 후 재사용
- 획득 카드는 `_pendingBonusCards`에 합산해 서버 제출 경로 유지
- "턴" 용어: 뱅가드에 턴 개념 없음. BO3 **라운드** 시작으로 해석 (§6-④ 확인)

**모듈 3 — 칩 뽑기 새로고침 (신규 작업 최다)**
- 훅: `VanguardChipGachaService.OpenChestAsync(chestType)` 결과 처리부
- 신규 API 예: `RerollLastResultAsync()` — 직전 결과를 폐기하고 동일 상자에서 재추첨, 매치/세션당 `GetChipGachaRefreshCount()`회 제한
- UI: 상자 결과 팝업에 "새로고침" 버튼 추가 (모듈 활성 시에만 노출)
- 정책 결정 필요: 천장(50회) 카운트 — reroll이 카운트를 추가로 올리는지, 폐기된 칩의 처리 (§6-①과 함께 확인)

**모듈 4 — 순찰 상한 14시간**
- 뱅가드 순찰 상한은 `VanguardTierDataSO`(티어 데이터) 기반 → 상한 계산부에 모듈 캡 적용:

```csharp
int maxHours = tierMaxHours;
if (moduleService.TryGetPatrolMaxHoursCap(out int cap))
    maxHours = Mathf.Max(maxHours, cap);   // "14시간으로 증가" = 상향 설정
```

- 선례: `PatrolManager.MaxAccumulationHours`가 `MembershipManager.GetTotalPatrolMaxTimeIncrease()`를 합산하는 구조(PatrolManager.cs:1390)와 동일한 주입 방식
- 시간 계산은 `ServerTimeManager.NowUnscaled` 사용 (DateTime.Now 금지)

### 4.5 획득 경로

테이블에 weight 컬럼이 있으므로 가중치 추첨 전제. `ArkGachaService`의 모듈 추첨 + `ArkModulePackageService`의 N택 선택 패턴 재활용. 실제 획득처(패스 보상/상점/듀얼 보상/티어 보상)는 기획 확정 필요 (§6-⑤). 4종뿐이므로 중복 획득 시 Fallback 정책도 함께.

### 4.6 서버 연동 (PvP 공정성)

뱅가드는 서버 재검증(match_seed 결정론, bonusCards 제출) 구조다. 모듈 도입 시:

- 전투 결과 제출에 **활성 모듈 목록 포함** → 서버가 보너스 카드 횟수·시점 재검증
- 고스트(상대) 대칭성: 현재 20/40/60초 보너스는 양측 대칭 적용(`GrantGhostBonusCard`). 모듈 게이트가 생기면 상대의 모듈 보유 여부를 매치 데이터(벤치마크)에 포함해야 대칭 유지 가능 (§6-⑥)
- 모듈 3·4는 클라 권위 영역(칩/순찰)이라 저장 데이터 검증 수준이면 충분

---

## 5. 단계별 작업 계획

**Phase 1 — 데이터/저장 (의존성 없음)**
1. `EModuleType`에 뱅가드 4종 값 추가 + 시트의 모듈1 타입 교체 협의
2. 구글 시트 → `VanguardModuleDataData`/`SO` 자동생성 확인, `ResourceManager.LoadResource<T>()` 로드 경로 연결
3. `VanguardSaveData`에 `ownedModules`/`activeModules` 추가, 시즌 리셋 처리

**Phase 2 — 서비스**
4. `VanguardModuleService` 신설 (ArkModuleService 동형 API + 4종 조회 메서드)
5. `VanguardManager`에 서비스 생성/보유, `Managers` 초기화 순서 확인

**Phase 3 — 효과 훅**
6. 모듈 1: `CheckBonusCard()` 모듈 게이트 + effectValues 시점 적용
7. 모듈 2: 라운드 시작 카드 지급 (`GrantVanguardBonusCard` 분리·재사용)
8. 모듈 4: 순찰 상한 계산부 캡 적용

**Phase 4 — 칩 새로고침 (UI 포함, 가장 큼)**
9. `VanguardChipGachaService.RerollLastResultAsync()` + 천장 정책 반영
10. 상자 결과 팝업 UI에 새로고침 버튼

**Phase 5 — 획득/UI/서버**
11. 획득 경로 구현 (가중치 추첨/선택 UI — Ark 패턴 재활용)
12. 모듈 목록/상세 팝업 (Ark UI 재활용)
13. 전투 결과 제출에 모듈 목록 포함 + 서버 검증 협의
14. 검증: 모듈 유/무 각 케이스 전투 시뮬, 시즌 리셋 시 초기화 확인, 천장 카운트 회귀 테스트

---

## 6. 기획/데이터 확인 필요 사항 (구현 전 확정)

1. **모듈 3 effectValues = 10** — 설명은 "한번 더(1회)"인데 값이 10. 새로고침 횟수면 1이어야 함. 오기인지 다른 의미(비용? 확률?)인지 확인.
2. **모듈 4 effectValues = 5** — 설명은 "14시간". 상한이면 14, 증가량이면 +6(기본 8h 기준)이어야 함. 값 정리 필요.
3. **모듈 1 조건 해석** — 시트: "아군 수가 적군보다 적으면" / 기존 코드: "내 잔여 적 > 고스트 잔여 적"(뒤처진 쪽 보상). 동일 의도인지, 그리고 **모듈 미보유 시 기존 기본 룰을 제거하는지 유지하는지** 확정 필요.
4. **모듈 2 "턴"** — 뱅가드는 실시간 웨이브(턴 없음). BO3 라운드 시작으로 해석해도 되는지.
5. **획득 경로** — 패스/상점/듀얼/티어 보상 중 어디서 weight 추첨하는지, 4종 전부 보유 시 처리.
6. **고스트 대칭성** — 모듈 1을 모듈화하면 상대(고스트)의 모듈 보유 여부를 벤치마크에 반영할지, 서버 검증 스펙 협의.

---

## 7. 코드 규칙 체크리스트 (CLAUDE.md)

- 시트 자동생성 SO(`SOs/SO/DataSheet/`) 직접 수정 금지 → 커스텀 로직은 `VanguardModuleDataParser.cs`
- `Managers.Instance.GetManager<VanguardManager>()` 경유 접근, EventManager는 static
- `async UniTask` + Async 접미사, `async void` 금지
- 시간은 `ServerTimeManager.NowUnscaled`
- 모듈 이름/설명은 로컬라이제이션 키 (`vanguard_module_name_N`)
- 저장은 `SaveDataAsync(ESaveDataType.Vanguard, data)`
- 이벤트 구독 해제는 `Cleanup()`
