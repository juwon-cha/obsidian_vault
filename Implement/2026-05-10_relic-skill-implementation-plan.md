# Relic Skill Implementation Plan (2026-05-10)

## 개요

기획 방향에 따라 디버프 최소화 / 광역 피해 위주 / 기존 스킬과 중복 제거를 목표로 총 **7개 skillId, 11개 rank 항목**을 변경한다.  
DataSheet SO 파일은 수정하지 않으며, 구글 시트 자동 반영 후 코드만 수정한다.

---

## 성능 최적화 원칙

구현 전 확인한 기존 코드 패턴을 기반으로 아래 원칙을 적용한다.

| 항목 | 기존 코드 패턴 | 적용 원칙 |
|---|---|---|
| Physics2D AoE 쿼리 | `MarauderController`는 NonAlloc 버전 사용 / `HammerProjectile`은 `OverlapCircleAll` 사용 | 신규 AoE는 모두 `OverlapCircleNonAlloc` + 클래스 레벨 재사용 버퍼 적용 |
| 컨트롤러 참조 | `HammerProjectile._ownerThor` 이미 보유 / `ShurikenProjectile._sourceUnit` 이미 보유 | 델리게이트(`Action<T>`) 대신 기존 참조로 직접 호출 |
| 타입 캐스팅 | `(_sourceUnit as NinjaController)` 패턴이 이미 피해 계산에서 사용 중 | 핫패스(`OnHitEnemy`) 내 `is`/`as` 캐스팅 제거, 초기화 시 1회 캐싱 |
| 피해 배율 합산 | `MovingVesselController`의 배율은 덧셈 방식(`totalPercentageModifier`) | `Update()` 별도 루프 없이 피해 계산 시점에 경과 시간으로 즉시 계산 |

---

## 변경 목록 요약

| # | skillId | rank | 변경 유형 |
|---|---|---|---|
| 1 | TemplerMultiHit | 10 | 마비 해제 폭발 → 번개 전이 시마다 피해 +5% |
| 2 | DrFrostBlizzardGrowth | 5 | 빙결 부여 → 눈보라 피해 +30% / 피해간격 감소 / 쿨타임 -3초 |
| 3 | DrFrostBlizzardGrowth | 10 | 빙결 해제 폭발 → 25% 확률로 눈사람 1개 추가 생성 |
| 4 | DragoonLaserBind | 0 | 속박 부여 → 40% 확률로 2회 추가 타격 |
| 5 | MarauderShotgunBlast | 10 | 취약 적 **사망 시** 지뢰 → 취약 적 **공격 시** 폭발 + 지뢰 1개 |
| 6 | VesselDefensiveShield | 5 | 마비 부여 → 비행시간 +25% / 매 초 피해 15%씩 증가 |
| 7 | NinjaMythic | 5 | 공격횟수+2 / 중상 부여 → 공격횟수+1 / 명중 시 25% 확률로 수리검 +1 |
| 8 | NinjaMythic | 10 | 중상 적 피해 증가 → 수리검 명중 시 폭발 (소형 제외) |
| 9 | ThorElectricPull | 0 | 잔상 전기장판 + 끌어당기기 → 망치 데미지 +40% / 소멸 시 광역 폭발 |
| 10 | ThorElectricPull | 5 | 전기장판 지속시간 연장 → 토르의 망치 지속시간 +3초 |
| 11 | ThorElectricPull | 10 | 끌어당기기 강화 → 소멸 시 작은 전기장판 2개 분산 후 폭발 |

---

## 상세 구현 계획

### 1. TemplerMultiHit — rank 10

**변경 내용**
- 기존: 마비가 풀릴 때 원본 공격력의 50% 피해
- 변경: 번개가 전이될 때마다 피해 5%씩 추가 증가 (arg1 = 5)

**구현 방식**  
`StormProjectileController`는 이미 `_remainingBounces`로 남은 전이 횟수를 관리한다.  
`Initialize()` 시점에 최대 바운스 수를 `_maxBounces`에 저장해두면,  
`_maxBounces - _remainingBounces`로 현재까지 전이된 횟수를 추가 자료구조 없이 알 수 있다.  
배율 계산은 HitEnemy() 진입 시점에 한 번만 수행하며, 결과를 바로 피해 계산에 전달한다.

**구체적 수정 사항**

`TemplerController.RelicSkill.cs`
```csharp
// 기존 rank=10 필드 교체
// private bool _relicParalysisRemoveDamageEnabled;
// private float _relicParalysisRemoveDamagePercent;

private bool  _relicChainDamageBoostEnabled;
private float _relicChainDamageBoostPercent; // arg1 = 5f

// OnApplyRelicRankEffect case 10
case 10:
    _relicChainDamageBoostEnabled  = true;
    _relicChainDamageBoostPercent  = data.arg1; // 5f
    break;

// 외부 접근용 프로퍼티
public bool  RelicChainDamageBoostEnabled  => _relicChainDamageBoostEnabled;
public float RelicChainDamageBoostPercent  => _relicChainDamageBoostPercent;
```

`StormProjectileController.cs`
```csharp
// Initialize() 시 최대 바운스 수 저장 (int 필드 1개 추가)
private int _maxBounces;

// Initialize() 내부
_maxBounces = bounceCount; // 기존 bounceCount 파라미터 재활용

// HitEnemy() 내 피해 계산 직전 — 메서드 분리 없이 인라인 계산
// (호출 빈도가 낮아 인라인이 오히려 명확)
float relicMultiplier = 1f;
if (_templerController.RelicChainDamageBoostEnabled)
{
    int chainCount = _maxBounces - _remainingBounces;
    relicMultiplier = 1f + chainCount * (_templerController.RelicChainDamageBoostPercent / 100f);
}
var damageResult = CalculateUnitDamage(EUnitType.Templer, damageMultiplier * relicMultiplier, 0, position);
```

**수정 파일**
- `TemplerController.RelicSkill.cs` — 필드 교체, case 10 로직 변경
- `StormProjectileController.cs` — `_maxBounces` int 필드 추가, `HitEnemy()` 피해 계산에 인라인 배율 적용

---

### 2. DrFrostBlizzardGrowth — rank 5

**변경 내용**
- 기존: 빙결 3초 부여
- 변경: 눈보라 피해 +30%, 피해간격 감소 30%, 쿨타임 -3초 (arg1 = 30, arg2 = 3)

**구현 방식**  
`BlizzardController.Initialize()`에 이미 `damage`, `damageInterval` 파라미터가 있다.  
DrFrost가 블리자드를 생성할 때 유물 배율을 적용한 값으로 넘기면 된다.  
`BlizzardController` 자체는 수정하지 않고, 호출부(`DrFrostController`)에서만 값을 보정한다.  
쿨타임은 `ApplyCooldownAfterBlizzard()` 또는 쿨타임 계산 위치에서 직접 차감한다.

**구체적 수정 사항**

`DrFrostController.RelicSkill.cs`
```csharp
// 기존 rank=5 필드 교체
// private bool _relicFreezeEnabled;
// private float _relicFreezeDuration;

private bool  _relicBlizzardBuffEnabled;
private float _relicBlizzardDamageBonus; // arg1 = 30f (%)
private float _relicCooldownReduction;   // arg2 = 3f (초)

// OnApplyRelicRankEffect case 5
case 5:
    _relicBlizzardBuffEnabled = true;
    _relicBlizzardDamageBonus = data.arg1; // 30f
    _relicCooldownReduction   = data.arg2; // 3f
    break;

// 외부 접근용 프로퍼티
public bool  RelicBlizzardBuffEnabled => _relicBlizzardBuffEnabled;
public float RelicBlizzardDamageBonus => _relicBlizzardDamageBonus;
public float RelicCooldownReduction   => _relicCooldownReduction;
```

`DrFrostController.cs` — `LaunchBlizzard()` 및 쿨타임 설정부
```csharp
// BlizzardController.Initialize() 호출 전에만 보정값 적용 (BlizzardController는 수정 없음)
float blizzardDamage   = calculatedDamage;
float blizzardInterval = _drFrostData.damageInterval;

if (RelicBlizzardBuffEnabled)
{
    blizzardDamage   *= (1f + RelicBlizzardDamageBonus / 100f);  // +30%
    blizzardInterval *= (1f - RelicBlizzardDamageBonus / 100f);  // 간격 -30%
}

blizzard.Initialize(blizzardDamage, duration, width, blizzardInterval, ...);

// 쿨타임 차감 (ApplyCooldownAfterBlizzard 또는 쿨타임 계산 위치)
float finalCooldown = _drFrostData.attackCooldown;
if (RelicBlizzardBuffEnabled)
    finalCooldown = Mathf.Max(0f, finalCooldown - RelicCooldownReduction);
```

**수정 파일**
- `DrFrostController.RelicSkill.cs` — 필드 교체, case 5 로직 변경
- `DrFrostController.cs` — `LaunchBlizzard()` 호출부 보정, 쿨타임 차감 적용
- `BlizzardController.cs` — **수정 없음** (기존 파라미터 그대로 활용)

---

### 3. DrFrostBlizzardGrowth — rank 10

**변경 내용**
- 기존: 빙결 종료 시 200% 폭발 피해
- 변경: 눈사람 생성 시 25% 확률로 눈사람 1개 추가 생성 (arg1 = 25, arg2 = 1)

**구현 방식**  
눈사람(드론)이 스폰되는 시점인 `DelayedLaunchDrone()`에 확률 체크 후  
기존 `SpawnDrone()` 메서드를 그대로 한 번 더 호출한다.  
새로운 스폰 메서드나 별도 코루틴 없이 기존 호출 패턴을 그대로 재사용한다.

**구체적 수정 사항**

`DrFrostController.RelicSkill.cs`
```csharp
// 기존 rank=10 필드 교체
// private bool _relicFreezeExplosionEnabled;
// private float _relicFreezeExplosionPercent;

private bool  _relicExtraSnowmanEnabled;
private float _relicExtraSnowmanChance; // arg1 = 25f (%)
private int   _relicExtraSnowmanCount;  // arg2 = 1

// OnApplyRelicRankEffect case 10
case 10:
    _relicExtraSnowmanEnabled = true;
    _relicExtraSnowmanChance  = data.arg1;      // 25f
    _relicExtraSnowmanCount   = (int)data.arg2; // 1
    break;

// 외부 접근용 프로퍼티
public bool  RelicExtraSnowmanEnabled => _relicExtraSnowmanEnabled;
public float RelicExtraSnowmanChance  => _relicExtraSnowmanChance;
public int   RelicExtraSnowmanCount   => _relicExtraSnowmanCount;
```

`DrFrostController.cs` — `DelayedLaunchDrone()` 내부
```csharp
private async UniTaskVoid DelayedLaunchDrone(Vector3 targetPosition)
{
    await UniTask.Delay(350); // 기존 0.35초 지연 유지

    SpawnDrone(targetPosition); // 기존 드론 생성 (그대로 유지)

    // 유물 rank=10: 확률로 추가 드론 생성 — SpawnDrone() 재호출만으로 처리
    if (RelicExtraSnowmanEnabled)
    {
        for (int i = 0; i < RelicExtraSnowmanCount; i++)
        {
            if (UnityEngine.Random.value < RelicExtraSnowmanChance / 100f)
                SpawnDrone(targetPosition); // 동일 위치, 동일 메서드
        }
    }
}
```

**수정 파일**
- `DrFrostController.RelicSkill.cs` — 필드 교체, case 10 로직 변경
- `DrFrostController.cs` — `DelayedLaunchDrone()` 에 확률 추가 생성 삽입

---

### 4. DragoonLaserBind — rank 0

**변경 내용**
- 기존: 메인 레이저 피격 적에게 공격 시간동안 [속박] 3초 부여
- 변경: 레이저로 적 공격 시 40% 확률로 2회 추가 타격 (arg1 = 40, arg2 = 2)

**구현 방식**  
기존 `TryApplyRelicBind()` 메서드를 `TryApplyRelicExtraHit()`로 교체한다.  
추가 타격은 기존 `CalculateCurrentDamage()`를 그대로 호출하므로 치명타·배율이 동일하게 유지된다.  
`Random.value` 체크는 확률 발동 시에만 for 루프가 진입하므로 불필요한 연산이 없다.

**구체적 수정 사항**

`DragoonController.RelicSkill.cs`
```csharp
// 기존 rank=0 필드 교체
// private bool _relicBindEnabled;
// private float _relicBindDuration;

private bool  _relicExtraHitEnabled;
private float _relicExtraHitChance; // arg1 = 40f (%)
private int   _relicExtraHitCount;  // arg2 = 2

// OnApplyRelicRankEffect case 0
case 0:
    _relicExtraHitEnabled = true;
    _relicExtraHitChance  = data.arg1;      // 40f
    _relicExtraHitCount   = (int)data.arg2; // 2
    break;

// TryApplyRelicBind() → TryApplyRelicExtraHit() 로 교체
// (기존 CalculateCurrentDamage / TakeDamage 호출 패턴 그대로 유지)
public void TryApplyRelicExtraHit(BaseEnemyController target, Vector3 targetPos)
{
    if (!_relicExtraHitEnabled || target == null || !target.IsAlive) return;
    if (UnityEngine.Random.value > _relicExtraHitChance / 100f) return;

    for (int i = 0; i < _relicExtraHitCount; i++)
    {
        var damageResult = CalculateCurrentDamage(_additionalDamageMultiplier, 0f, targetPos);
        target.TakeDamage(damageResult.finalDamage, UnitRace, damageResult.isCritical, EUnitType.Dragoon, targetPos);
    }
}
```

`DragoonController.cs` — `ApplyDamageToTarget()` 내부
```csharp
// 기존 TryApplyRelicBind() 호출을 교체
TryApplyRelicExtraHit(target, targetPos);
```

**수정 파일**
- `DragoonController.RelicSkill.cs` — 필드 교체, case 0 로직 변경, 메서드 교체
- `DragoonController.cs` — `ApplyDamageToTarget()` 호출 교체

---

### 5. MarauderShotgunBlast — rank 10

**변경 내용**
- 기존: 취약 적 **사망 시** 폭발 + 부유지뢰 생성
- 변경: 취약 적 **공격 시** 폭발 + 부유지뢰 1개 생성 (arg1 = 1)

**구현 방식**  
기존 `OnRelicKilledVulnerableEnemy()` 및 사망 이벤트 구독을 제거하고,  
이미 존재하는 `OnRelicBuckshotHit()` 내부에 취약 상태 체크를 추가한다.  
`ApplyRelicExplosion()`과 `CreateRelicMine()`은 기존 메서드를 그대로 재호출한다.  
연속 발동 방지를 위한 쿨다운은 `float` 하나로 처리하며, `Time.time`과의 단순 비교로 오버헤드가 없다.

**구체적 수정 사항**

`MarauderController.RelicSkill.cs`
```csharp
// rank=10 추가 필드
private int   _relicMineCount;    // arg1 = 1
private float _relicMineLastTime; // 쿨다운 추적 (float 1개)
private const float RELIC_MINE_COOLDOWN = 2f; // QA 후 [SerializeField]로 노출

// OnApplyRelicRankEffect case 10
case 10:
    _relicMineEnabled = true;
    _relicMineCount   = Mathf.Max(1, (int)data.arg1); // 1
    break;

// OnRelicBuckshotHit() — rank=5 취약 부여 뒤에 rank=10 통합
public void OnRelicBuckshotHit(BaseEnemyController enemy)
{
    // rank=5: 취약 부여 (기존 유지)
    if (_relicVulnerableEnabled)
        enemy.ApplyDebuff(EDebuffType.Vulnerable, 1f, 1, 0f, this, _relicVulnerableDuration);

    // rank=10: 취약 적 공격 시 즉시 폭발 + 부유지뢰
    // ApplyRelicExplosion() / CreateRelicMine() 기존 메서드 재호출
    if (_relicMineEnabled && enemy.HasDebuff(EDebuffType.Vulnerable))
    {
        if (Time.time - _relicMineLastTime >= RELIC_MINE_COOLDOWN)
        {
            _relicMineLastTime = Time.time;
            ApplyRelicExplosion(enemy.transform.position);
            for (int i = 0; i < _relicMineCount; i++)
                CreateRelicMine(enemy.transform.position);
        }
    }
}

// 제거: OnRelicKilledVulnerableEnemy() 및 적 사망 이벤트 구독 코드
```

> `BaseEnemyController.HasDebuff(EDebuffType)` 가 없으면 `GetDebuffRemainingTime()` 등 기존 메서드로 취약 상태 확인

**수정 파일**
- `MarauderController.RelicSkill.cs` — `OnRelicBuckshotHit()`에 rank10 통합, 사망 이벤트 구독 제거, `_relicMineCount` 필드 추가

---

### 6. VesselDefensiveShield — rank 5

**변경 내용**
- 기존: 발사 후 첫 N초간 충돌 적에게 마비 부여
- 변경: 지우개 비행시간 +25%, 소환 후 매 초 피해 15%씩 증가 (arg1 = 25, arg2 = 15)

**구현 방식**  
`MovingVesselController`의 피해 배율은 `totalPercentageModifier`에 덧셈 합산하는 기존 패턴을 사용한다.  
별도 `Update()` 루프를 추가하지 않고, 기존 피해 계산 시점에 `Time.time - _relicSpawnTime`으로  
경과 시간을 즉시 계산해 `totalPercentageModifier`에 추가한다.  
`_relicSpawnTime`은 `Initialize()` 또는 `OnSpawn()` 에서 한 번 저장한다.

**구체적 수정 사항**

`VesselController.RelicSkill.cs`
```csharp
// 기존 rank=5 필드 교체
// private bool _relicParalysisEnabled;
// private float _relicParalysisDuration;
// private float _relicParalysisWindow;

private bool  _relicVesselBuffEnabled;
private float _relicDurationBonus;    // arg1 = 25f (%)
private float _relicTimedDamageBonus; // arg2 = 15f (초당 %)

// OnApplyRelicRankEffect case 5
case 5:
    _relicVesselBuffEnabled = true;
    _relicDurationBonus     = data.arg1; // 25f
    _relicTimedDamageBonus  = data.arg2; // 15f
    break;

// 외부 접근용 프로퍼티
public bool  RelicVesselBuffEnabled  => _relicVesselBuffEnabled;
public float RelicDurationBonus      => _relicDurationBonus;
public float RelicTimedDamageBonus   => _relicTimedDamageBonus;
```

`VesselController.cs` — 배슬 발사 시 Initialize() 호출부
```csharp
// duration만 보정해서 넘김 — Initialize() 시그니처 변경 없음
float finalDuration = baseDuration;
if (RelicVesselBuffEnabled)
    finalDuration *= (1f + RelicDurationBonus / 100f); // +25%

movingVessel.Initialize(damage, damageRadius, moveSpeed, finalDuration, damageInterval, ...);

// 시간 기반 피해 보너스 설정 전달
if (RelicVesselBuffEnabled)
    movingVessel.SetRelicTimedDamageBonus(RelicTimedDamageBonus);
```

`MovingVesselController.cs`
```csharp
// 신규 필드 — float 2개만 추가
private float _relicTimedDamageBonusPercent; // 15f (0이면 비활성)
private float _relicSpawnTime;

public void SetRelicTimedDamageBonus(float bonusPerSecond)
{
    _relicTimedDamageBonusPercent = bonusPerSecond;
}

// Initialize() 또는 OnSpawn() 내
_relicTimedDamageBonusPercent = 0f;
_relicSpawnTime = Time.time; // 스폰 시각 저장

// 기존 피해 계산부 (totalPercentageModifier 합산 위치)
// Update() 추가 없이, 기존 패턴에 한 줄 추가
float damageStackBonus   = _cardEffects.currentDamageStackMultiplier - 1f;
float wallBounceBonus    = _cardEffects.currentWallBounceMultiplier  - 1f;
float vesselDamageBonus  = _vesselController.VesselDamagePercentageModifier - 1f;
float relicTimedBonus    = _relicTimedDamageBonusPercent > 0f                          // 비활성이면 0
    ? (Time.time - _relicSpawnTime) * (_relicTimedDamageBonusPercent / 100f)
    : 0f;
float totalPercentageModifier = 1f + damageStackBonus + wallBounceBonus + vesselDamageBonus + relicTimedBonus;
// 이후 기존 DamageCalculationManager.CalculateUnitDamage(..., totalPercentageModifier, ...) 호출 유지
```

> `OnDespawn()` 에서 `_relicTimedDamageBonusPercent = 0f` 초기화 필수 (풀 재사용 시 잔류 방지)

**수정 파일**
- `VesselController.RelicSkill.cs` — 필드 교체, case 5 로직 변경
- `VesselController.cs` — Initialize() 호출부에서 duration 보정 및 `SetRelicTimedDamageBonus()` 전달
- `MovingVesselController.cs` — `SetRelicTimedDamageBonus()` 추가, 기존 `totalPercentageModifier` 합산에 `relicTimedBonus` 한 줄 추가, `OnDespawn()` 초기화

---

### 7. NinjaMythic — rank 5

**변경 내용**
- 기존: 어쌔신 공격 횟수 +2, 공격에 [중상] 5초 부여
- 변경: 어쌔신 공격 횟수 +1, 명중 시 25% 확률로 수리검 +1 (arg1 = 25, arg2 = 1)

**구현 방식**  
`ShurikenProjectile`은 이미 `_sourceUnit`을 `UnitController`로 저장하며,  
피해 계산 시 `(_sourceUnit as NinjaController)` 패턴을 사용하고 있다.  
`OnHitEnemy()`는 수리검 1발당 1회 호출되는 핫패스이므로,  
`LaunchShuriken()` 시점에 `NinjaController`로 한 번 캐싱해두고 이후 null 체크만 수행한다.  
이렇게 하면 `is`/`as` 타입 캐스팅이 핫패스에서 완전히 제거된다.

**구체적 수정 사항**

`NinjaController.RelicSkill.cs`
```csharp
// 기존 rank=5 필드 교체
// private bool _relicApplyWounded;
// private float _relicWoundedDuration;

private float _relicExtraShurikenChance; // arg1 = 25f (%)
private int   _relicExtraShurikenCount;  // arg2 = 1

// OnApplyRelicRankEffect case 5
case 5:
    _maxAttackCount          += 1;           // 공격 횟수 +1 (기존 패턴 유지)
    _relicExtraShurikenChance = data.arg1;   // 25f
    _relicExtraShurikenCount  = (int)data.arg2; // 1
    break;

// 외부 접근용 프로퍼티
public float RelicExtraShurikenChance => _relicExtraShurikenChance;
public int   RelicExtraShurikenCount  => _relicExtraShurikenCount;
```

`NinjaController.cs` — 수리검 명중 콜백 (기존 `_objectPoolManager`, `_shurikenPrefab` 재활용)
```csharp
public void OnShurikenHit(BaseEnemyController target, Vector3 hitPosition)
{
    if (_relicExtraShurikenChance <= 0f || target == null || !target.IsAlive) return;
    if (UnityEngine.Random.value > _relicExtraShurikenChance / 100f) return;

    for (int i = 0; i < _relicExtraShurikenCount; i++)
    {
        // 기존 LaunchShurikens()와 동일한 풀 취득 패턴
        var shuriken = _objectPoolManager.GetPool<ShurikenProjectile>(_shurikenPrefab).Get();
        shuriken.LaunchShuriken(hitPosition, target, EShurikenType.Normal,
                                AllShurikenSplitChance, this);
    }
}
```

`ShurikenProjectile.cs` — 초기화 시 캐싱, `OnHitEnemy()` 에서 캐시 참조
```csharp
// 기존 _sourceUnit 필드 옆에 캐시 추가
private NinjaController _ninjaController; // LaunchShuriken 시 1회 캐싱

// LaunchShuriken() 및 LaunchShurikenDirectional() 내부 — sourceUnit 저장 직후
_sourceUnit       = sourceUnit;
_ninjaController  = sourceUnit as NinjaController; // 1회만 캐싱

// OnHitEnemy() 내부 — is/as 없이 null 체크만
if (_ninjaController != null)
    _ninjaController.OnShurikenHit(enemy, transform.position);
```

**수정 파일**
- `NinjaController.RelicSkill.cs` — 필드 교체, case 5 로직 변경
- `NinjaController.cs` — `OnShurikenHit()` 콜백 추가
- `ShurikenProjectile.cs` — `_ninjaController` 캐시 필드 추가, `LaunchShuriken()` / `LaunchShurikenDirectional()` 에서 캐싱, `OnHitEnemy()` 에서 캐시 참조

---

### 8. NinjaMythic — rank 10

**변경 내용**
- 기존: 중상에 걸린 적 공격 시 50% 추가 피해
- 변경: 수리검 명중 시 폭발 (소형 수리검 제외), 폭발 데미지 50% (arg1 = 50)

**구현 방식**  
7번에서 캐싱한 `_ninjaController`를 그대로 참조한다.  
AoE 피해는 `MarauderController.RelicSkill.cs`와 동일한 NonAlloc 패턴을 사용한다.  
`OverlapCircleAll` 대신 `OverlapCircleNonAlloc`에 클래스 레벨 정적 버퍼를 사용해  
수리검 명중마다 배열을 할당하지 않는다.  
폭발 AoE 로직은 `NinjaController.ApplyRelicShurikenExplosion()`으로 이동해  
ShurikenProjectile을 간결하게 유지한다.

**구체적 수정 사항**

`NinjaController.RelicSkill.cs`
```csharp
// 기존 rank=10 필드 교체
// private bool _relicWoundedDamageEnabled;
// private float _relicWoundedBonusDamage;

private bool  _relicShurikenExplosionEnabled;
private float _relicShurikenExplosionDamagePercent; // arg1 = 50f (%)

// OnApplyRelicRankEffect case 10
case 10:
    _relicShurikenExplosionEnabled       = true;
    _relicShurikenExplosionDamagePercent = data.arg1; // 50f
    break;

// 외부 접근용 프로퍼티
public bool  RelicShurikenExplosionEnabled       => _relicShurikenExplosionEnabled;
public float RelicShurikenExplosionDamagePercent => _relicShurikenExplosionDamagePercent;
```

`NinjaController.cs` — AoE 처리 메서드 (MarauderController NonAlloc 패턴 적용)
```csharp
// 클래스 레벨 재사용 버퍼 (수리검이 여러 개 동시에 폭발해도 static으로 순차 처리)
private static readonly Collider2D[] _shurikenExplosionBuffer = new Collider2D[32];

public void ApplyRelicShurikenExplosion(Vector3 hitPosition)
{
    if (!_relicShurikenExplosionEnabled) return;

    float explosionDamage = CalculateUnitDamageValue() * (_relicShurikenExplosionDamagePercent / 100f);
    float explosionRadius = 1.5f; // [SerializeField]로 노출 — 기획 확정 후 조율

    // NonAlloc: 매 폭발마다 배열 할당 없음
    int count = Physics2D.OverlapCircleNonAlloc(hitPosition, explosionRadius,
                                                _shurikenExplosionBuffer, _enemyLayerMask);
    for (int i = 0; i < count; i++)
    {
        if (_shurikenExplosionBuffer[i].TryGetComponent<BaseEnemyController>(out var aoeEnemy)
            && aoeEnemy.IsAlive)
        {
            aoeEnemy.TakeDamage(explosionDamage, UnitRace, false, EUnitType.Ninja, hitPosition);
        }
    }
    // 폭발 이펙트 재생 (기존 EffectManager 활용)
}
```

`ShurikenProjectile.cs` — `OnHitEnemy()` 내부
```csharp
private void OnHitEnemy(BaseEnemyController enemy)
{
    // ... 기존 피해 처리 ...

    // rank=5: 확률 추가 수리검 (캐시된 참조 사용)
    if (_ninjaController != null)
        _ninjaController.OnShurikenHit(enemy, transform.position);

    // rank=10: Normal 수리검만 폭발 (캐시된 참조 + 타입 enum 체크만)
    if (_shurikenType == EShurikenType.Normal && _ninjaController != null)
        _ninjaController.ApplyRelicShurikenExplosion(transform.position);
}
```

**수정 파일**
- `NinjaController.RelicSkill.cs` — 필드 교체, case 10 로직 변경
- `NinjaController.cs` — `ApplyRelicShurikenExplosion()` 추가 (NonAlloc AoE 포함)
- `ShurikenProjectile.cs` — `OnHitEnemy()` 에서 캐시 참조로 rank5/10 처리

---

### 9. ThorElectricPull — rank 0

**변경 내용**
- 기존: 잔상 전기장판 생성 + 끌어당기기
- 변경: 망치 데미지 +40%, 소멸 시 광역 폭발 200 피해 (arg1 = 40, arg2 = 200)

**구현 방식**  
`HammerProjectile`은 이미 `_ownerThor`로 `ThorController`를 참조하고 있다.  
`Action<Vector3>` 델리게이트를 별도로 만들지 않고, `ProcessExplosion()` 완료 후  
`_ownerThor.OnRelicHammerExplosion(position)`을 직접 호출한다.  
데미지 배율 +40%는 기존 카드 효과와 동일하게 `_damageMultiplier`에 합산한다.

**구체적 수정 사항**

`ThorController.RelicSkill.cs`
```csharp
// 기존 rank=0 필드 완전 교체
// private bool _relicFieldEnabled;
// private float _relicFieldDuration;
// private float _relicFieldDamageInterval;
// private float _relicFieldDamageRatio;

private bool  _relicHammerBuffEnabled;
private float _relicHammerDamageBonus;     // arg1 = 40f (%)
private float _relicHammerExplosionDamage; // arg2 = 200f

// OnApplyRelicRankEffect case 0
case 0:
    _relicHammerBuffEnabled      = true;
    _relicHammerDamageBonus      = data.arg1; // 40f
    _relicHammerExplosionDamage  = data.arg2; // 200f
    break;

// 외부 접근용 프로퍼티
public bool  RelicHammerBuffEnabled      => _relicHammerBuffEnabled;
public float RelicHammerExplosionDamage  => _relicHammerExplosionDamage;
```

`ThorController.cs`
```csharp
// 초기화 또는 데미지 배율 적용부 (기존 카드 효과와 동일한 합산 패턴)
if (RelicHammerBuffEnabled)
    _damageMultiplier += _relicHammerDamageBonus / 100f; // +0.4f

// ProcessExplosion() 에서 직접 호출받는 메서드 (델리게이트 없음)
public void OnRelicHammerExplosion(Vector3 explosionPos)
{
    if (!RelicHammerBuffEnabled) return;
    ApplyRelicHammerAoE(explosionPos, RelicHammerExplosionDamage);
}

// AoE 공통 메서드 — rank=0, rank=10 공유 (NonAlloc 패턴 적용)
private static readonly Collider2D[] _relicHammerHitBuffer = new Collider2D[32];

private void ApplyRelicHammerAoE(Vector3 center, float damage)
{
    int count = Physics2D.OverlapCircleNonAlloc(center, DamageRadius,
                                                _relicHammerHitBuffer, _enemyLayerMask);
    for (int i = 0; i < count; i++)
    {
        if (_relicHammerHitBuffer[i].TryGetComponent<BaseEnemyController>(out var enemy)
            && enemy.IsAlive)
        {
            enemy.TakeDamage(damage, UnitRace, false, EUnitType.Thor, center);
        }
    }
    // 폭발 이펙트 재생
}
```

`HammerProjectile.cs`
```csharp
// 기존 _ownerThor 참조를 활용해 직접 호출 (Action<Vector3> 불필요)
private async UniTask ProcessExplosion(Vector3 explosionPosition)
{
    // ... 기존 폭발 처리 (OverlapCircleAll 유지) ...

    // 유물 rank=0 폭발 — 델리게이트 없이 직접 호출
    _ownerThor.OnRelicHammerExplosion(explosionPosition);
}
```

**수정 파일**
- `ThorController.RelicSkill.cs` — 필드 완전 교체, case 0 로직 변경
- `ThorController.cs` — `_damageMultiplier` 보정, `OnRelicHammerExplosion()` / `ApplyRelicHammerAoE()` 구현 (NonAlloc)
- `HammerProjectile.cs` — `ProcessExplosion()` 에서 `_ownerThor` 직접 호출 추가 (새 필드 없음)

---

### 10. ThorElectricPull — rank 5

**변경 내용**
- 기존: 전기장판 지속시간 +3초
- 변경: 토르의 망치 지속시간(체공 시간) +3초 (arg1 = 3)

**구현 방식**  
Thor 컨셉이 전기장판 → 망치로 전환되므로, rank 5는 망치가 타겟에 도달한 후  
폭발 전까지 체공하는 시간을 3초 연장한다.  
`HammerProjectile`의 비행 완료 ~ 폭발 사이에 추가 대기를 삽입하며,  
`_ownerThor.RelicHammerExtraDuration`으로 직접 참조해 별도 setter 없이 처리한다.

**구체적 수정 사항**

`ThorController.RelicSkill.cs`
```csharp
// 기존 rank=5 필드 교체
// private float _relicFieldExtraDuration;

private float _relicHammerExtraDuration; // arg1 = 3f (초)

// OnApplyRelicRankEffect case 5
case 5:
    _relicHammerExtraDuration = data.arg1; // 3f
    break;

// 외부 접근용 프로퍼티 (기존 RelicFieldDuration 대체)
public float RelicHammerExtraDuration => _relicHammerExtraDuration;
```

`HammerProjectile.cs` — 비행 완료 후 폭발 직전
```csharp
// _ownerThor 기존 참조로 직접 읽음 — setter 불필요
private async UniTask FlyAndExplode(Vector3 targetPosition)
{
    await FlyToPosition(targetPosition);

    // 유물 rank=5: 소멸 전 추가 체공 (3초)
    float extraDuration = _ownerThor.RelicHammerExtraDuration;
    if (extraDuration > 0f)
        await UniTask.Delay((int)(extraDuration * 1000f));

    await ProcessExplosion(targetPosition);
}
```

**수정 파일**
- `ThorController.RelicSkill.cs` — 필드 교체, case 5 로직 변경
- `HammerProjectile.cs` — `FlyAndExplode()` 에 체공 딜레이 삽입 (`_ownerThor` 직접 참조)

---

### 11. ThorElectricPull — rank 10

**변경 내용**
- 기존: 끌어당기기 강화
- 변경: 소멸 시 작은 전기장판 2개 분산 후 폭발, 원본 폭발 피해의 70% (arg1 = 2, arg2 = 70)

**구현 방식**  
rank 0의 `OnRelicHammerExplosion()` 내부에서 rank 10 활성화 시  
`ApplyRelicHammerAoE()`를 분산 위치에 추가 호출한다.  
공통 AoE 메서드와 NonAlloc 버퍼를 rank 0과 그대로 공유하므로 추가 배열 할당이 없다.

**구체적 수정 사항**

`ThorController.RelicSkill.cs`
```csharp
// 기존 rank=10 필드 교체
// private bool _relicFieldPullEnabled;
// private float _relicFieldPullInterval;
// private float _relicFieldPullForce;

private bool  _relicSplitExplosionEnabled;
private int   _relicSplitExplosionCount; // arg1 = 2
private float _relicSplitExplosionRatio; // arg2 = 70f (%)

// OnApplyRelicRankEffect case 10
case 10:
    _relicSplitExplosionEnabled = true;
    _relicSplitExplosionCount   = (int)data.arg1; // 2
    _relicSplitExplosionRatio   = data.arg2;      // 70f
    break;
```

`ThorController.cs` — `OnRelicHammerExplosion()` 내부
```csharp
public void OnRelicHammerExplosion(Vector3 explosionPos)
{
    if (!RelicHammerBuffEnabled) return;

    // rank=0: 기본 광역 폭발
    ApplyRelicHammerAoE(explosionPos, RelicHammerExplosionDamage);

    // rank=10: 분산 소형 폭발 추가
    // — ApplyRelicHammerAoE() 및 _relicHammerHitBuffer 재사용, 추가 할당 없음
    if (_relicSplitExplosionEnabled)
    {
        float splitDamage   = RelicHammerExplosionDamage * (_relicSplitExplosionRatio / 100f);
        float scatterRadius = DamageRadius * 1.5f; // 기획 조율 필요

        for (int i = 0; i < _relicSplitExplosionCount; i++)
        {
            Vector2 randomOffset = UnityEngine.Random.insideUnitCircle * scatterRadius;
            Vector3 splitPos     = explosionPos + new Vector3(randomOffset.x, randomOffset.y, 0f);
            ApplyRelicHammerAoE(splitPos, splitDamage); // 동일 메서드, 동일 버퍼 재사용
            // 소형 전기장판 이펙트 재생
        }
    }
}
```

**수정 파일**
- `ThorController.RelicSkill.cs` — 필드 교체, case 10 로직 변경
- `ThorController.cs` — `OnRelicHammerExplosion()` 에 분산 폭발 추가 (기존 `ApplyRelicHammerAoE()` 재호출)

---

## 수정 파일 전체 목록

| 파일 | 변경 항목 |
|---|---|
| `TemplerController.RelicSkill.cs` | rank10 필드·로직 교체 |
| `StormProjectileController.cs` | `_maxBounces` int 필드 추가, `HitEnemy()` 인라인 배율 적용 |
| `DrFrostController.RelicSkill.cs` | rank5·10 필드·로직 교체 |
| `DrFrostController.cs` | `LaunchBlizzard()` 호출부 보정, `DelayedLaunchDrone()` 추가 생성 |
| `DragoonController.RelicSkill.cs` | rank0 필드·로직 교체, `TryApplyRelicExtraHit()` 구현 |
| `DragoonController.cs` | `ApplyDamageToTarget()` 호출 교체 |
| `MarauderController.RelicSkill.cs` | rank10 트리거 변경, 사망 이벤트 구독 제거, `_relicMineCount` 추가 |
| `VesselController.RelicSkill.cs` | rank5 필드·로직 교체 |
| `VesselController.cs` | Initialize() 호출부 duration 보정, `SetRelicTimedDamageBonus()` 전달 |
| `MovingVesselController.cs` | `SetRelicTimedDamageBonus()` 추가, 기존 `totalPercentageModifier` 합산에 `relicTimedBonus` 삽입, `OnDespawn()` 초기화 |
| `NinjaController.RelicSkill.cs` | rank5·10 필드·로직 교체 |
| `NinjaController.cs` | `OnShurikenHit()` / `ApplyRelicShurikenExplosion()` 추가 (NonAlloc AoE) |
| `ShurikenProjectile.cs` | `_ninjaController` 캐시 필드 추가, 초기화 시 캐싱, `OnHitEnemy()` 캐시 참조 |
| `ThorController.RelicSkill.cs` | rank0·5·10 필드·로직 완전 교체 |
| `ThorController.cs` | `_damageMultiplier` 보정, `OnRelicHammerExplosion()` / `ApplyRelicHammerAoE()` 구현 (NonAlloc) |
| `HammerProjectile.cs` | `ProcessExplosion()` 에서 `_ownerThor` 직접 호출, `FlyAndExplode()` 체공 딜레이 삽입 |

---

## 구현 우선순위 및 주의사항

### 우선순위 (의존성 기준)

1. **Thor 전체** — rank0의 `ApplyRelicHammerAoE()` / `OnRelicHammerExplosion()` 구현 후 rank10 추가
2. **DrFrost rank5 → rank10** — rank5 블리자드 파라미터 변경 후 rank10 드론 추가
3. **나머지 독립 항목** — Templer / Dragoon / Marauder / Vessel / Ninja

### 공통 주의사항

- DataSheet SO 파일(`SOs/SO/DataSheet/`) 수정 금지 — 구글 시트 자동 생성 대상
- `_relicField*` 계열 기존 필드를 외부에서 참조하는 코드가 있으면 함께 정리
- Thor의 기존 `RelicFieldDuration` 프로퍼티를 외부에서 사용하는지 확인 후 제거 또는 대체
- Marauder rank10 쿨다운(`RELIC_MINE_COOLDOWN = 2f`)은 QA 후 `[SerializeField]`로 노출
- Ninja rank10 폭발 반경(`1.5f`)은 기획 확정 후 `[SerializeField]`로 노출
- Vessel rank5: `OnDespawn()` 에서 `_relicTimedDamageBonusPercent = 0f` 초기화 필수 (풀 재사용 시 잔류 방지)
- Thor NonAlloc 버퍼(`_relicHammerHitBuffer`)는 static이므로 Thor 유닛이 여러 개일 때 동시 폭발하지 않는지 확인 필요. 동시 폭발 가능성이 있다면 인스턴스 필드로 변경
