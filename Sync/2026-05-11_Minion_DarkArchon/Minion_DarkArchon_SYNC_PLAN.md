# Minion_DarkArchon SYNC PLAN
> 작성일: 2026-05-11 | FROM: temp-bunker/dev | TO: WiggleDefender (juwon/UpdateSync)

---

## 섹션 0 — FROM 파일 전수조사 표

| 파일명 | 역할 | FROM 전용 패턴 | Sync 유형 | TO 처리 방법 |
|--------|------|---------------|-----------|-------------|
| `Minion_DarkPriest_Controller.cs` | DarkPriest 미니언 컨트롤러 (BaseMinionController 상속). ConfigureSkill에서 DarkConfig SO 주입 | 없음 | **신규 추가** | 그대로 복사 |
| `DarkPriestTrapSkill.cs` | 함정 스킬 핵심 로직 (Idle→Activated→Moving→Explode 상태머신). IObjectPoolService, LowLevelPhysicsHelper 사용 | `using Geuneda.Services;` / `ServiceAccessor.Get<IObjectPoolService>()` / `ServiceAccessor.TryGet<UnitSpawnManager>()` / `LowLevelPhysicsHelper.OverlapCircle` | **신규 추가 (변환 필요)** | 변환 후 복사 |
| `MinionDarkTrapComponent.cs` | 함정 오브젝트 상태머신 컴포넌트 (PooledObject<T> 상속). ITickService로 Update 구독 | `using Geuneda.Services;` / `ITickService` / `MainInstaller.Resolve<ITickService>()` / `_tickService.SubscribeOnUpdate` / `UnsubscribeOnUpdate` / `LowLevelPhysicsHelper.OverlapCircle` | **신규 추가 (변환 필요)** | 변환 후 복사 |
| `MinionDarkConfigSO.cs` | 암흑 사제 튜닝 Config ScriptableObject (연출 상수·매직넘버 전용) | 없음 | **신규 추가** | 그대로 복사 |
| `MinionEnums.cs` | EMinionSkillType enum | — | **기존 수정** | `DarkPriestTrap = 2503` 1줄 추가 |
| `MinionSkillRegistry.cs` | 스킬 팩토리 레지스트리 | — | **기존 수정** | `Register(DarkPriestTrap)` 추가 |
| `MinionManager.cs` | 미니언 매니저 | BaseService→BaseManager, MessageBroker→EventManager 전환 완료 | **복사 금지** | TO가 이미 최신 |
| `BaseMinionController.cs` | 기본 미니언 컨트롤러 | TO에 360도 공격 모드 등 추가 기능 있음 | **복사 금지** | TO가 이미 최신 |

**요약**: 신규 추가 4 / 기존 수정 2 / 복사 금지 2

---

## 섹션 1 — TO 현재 상태

### 존재 항목 (복사 불필요)
- `MinionManager.cs` — BaseService → BaseManager, MessageBroker → EventManager 전환 완료. WD 추가 기능 포함.
- `BaseMinionController.cs` — 360도 공격 모드, WD 전용 로직 포함. FROM보다 최신.
- `MinionSkillRegistry.cs` — DarkPriestTrap 미등록 상태 (현재 11개 스킬 등록). **수정 필요**.
- `MinionEnums.cs` — `DarkPriestTrap` 없음. **수정 필요**.
- `DebuffController.cs` — `OnDebuffApplied` 이벤트만 있음. `OnDebuffEnded` 없음. **추가 필요 (블로커)**.
- `DebuffType.cs` — `Confuse` 없음. 현재 `Overload`까지 정의. **추가 필요 (블로커)**.
- `EEffectType.cs` — `VFX_Minion_Dark_Trap_Explo`, `VFX_Minion_Dark_Trap_Black` 없음. 현재 `VFX_Minion_Rtan_Skill_Cross = 3012`까지. **추가 필요 (블로커)**.

### Sync 필요 항목 (신규/수정/블로커)

| 항목 | 유형 | 우선순위 |
|------|------|---------|
| `EDebuffType.Confuse` 추가 | 블로커 | 1순위 |
| `EEffectType.VFX_Minion_Dark_Trap_Explo/Black` 추가 | 블로커 | 1순위 |
| `DebuffController.OnDebuffEnded` 이벤트 추가 | 블로커 | 1순위 |
| `Confuse` 디버프 처리 로직 구현 (ApplyDebuff/OnDebuffEnd/이동속도) | 블로커 | 1순위 |
| `MinionEnums.cs` — DarkPriestTrap 추가 | 기존 수정 | 2순위 |
| `MinionSkillRegistry.cs` — DarkPriestTrap 등록 | 기존 수정 | 2순위 |
| `MinionDarkConfigSO.cs` 신규 추가 | 신규 | 3순위 |
| `Minion_DarkPriest_Controller.cs` 신규 추가 | 신규 | 3순위 |
| `DarkPriestTrapSkill.cs` 변환 후 추가 | 신규 | 3순위 |
| `MinionDarkTrapComponent.cs` 변환 후 추가 | 신규 | 3순위 |
| 프리팹 3개 | 에셋 | 4순위 |

---

## 섹션 2 — FROM 원본 파일 분석 (변환 필요 파일 상세)

### 2-1. DarkPriestTrapSkill.cs

- **클래스명**: `DarkPriestTrapSkill : BaseMinionSkill`
- **역할**: 암흑 사제 함정 스킬 핵심 로직. 쿨타임마다 함정 오브젝트를 스폰하고, 함정 폭발 콜백에서 데미지·디버프·분열·Mythic 처리를 담당.
- **주요 메서드 시그니처**:
  - `protected override void OnInitialize(MinionSkillContext context)`
  - `protected override bool OnCanExecute(MinionSkillContext context)`
  - `protected override void OnExecute(MinionSkillContext context, Transform target)`
  - `private MinionDarkTrapComponent SpawnTrap(MinionSkillContext context, Vector3 position, bool isSmall, ESpawnSource source)`
  - `private void HandleExplosion(MinionSkillContext context, Vector3 position, List<BaseEnemyController> hits, float scale, bool isSmall, bool canSplit)`
  - `private void TryApplyConfuse(MinionSkillContext context, BaseEnemyController enemy)`
  - `private void RegisterMythicConfuseEndCallback(MinionSkillContext context, BaseEnemyController enemy)`
  - `private async UniTask MoveTransitionEffectAsync(Vector3 startPos, Vector3 endPos, float scaleMultiplier, CancellationToken token)`

- **FROM 전용 패턴 체크리스트**:
  - [x] `using Geuneda.Services;` — 제거
  - [x] `using MarinRPG.Physics;` — 제거 (Physics2D 직접 사용)
  - [x] `#if UNITY_6000_5_OR_NEWER / using Unity.U2D.Physics; #else using UnityEngine.LowLevelPhysics2D; #endif` — 제거
  - [x] `ServiceAccessor.Get<IObjectPoolService>()` → `Managers.Instance.GetManager<ObjectPoolManager>()`
  - [x] `_objectPoolService.GetPool<MinionDarkTrapComponent>(prefab)` → `objectPoolManager.GetPool<MinionDarkTrapComponent>(prefab)`
  - [x] `_trapPool.Spawn()` → `_trapPool.Get()` (WD ObjectPool API)
  - [x] `ServiceAccessor.TryGet<UnitSpawnManager>(out var spawnManager)` → `Managers.Instance?.GetManager<UnitSpawnManager>()`
  - [x] `LowLevelPhysicsHelper.OverlapCircle(PhysicsWorld.defaultWorld, pos, range, PhysicsLayerMapping.HitEnemyFilter)` → `Physics2D.OverlapCircleAll(pos, range, LayerMask.GetMask("Enemy"))`
  - [x] `IObjectPoolService _objectPoolService` → `ObjectPoolManager _objectPoolManager`
  - [x] `IObjectPool<MinionDarkTrapComponent> _trapPool` → `IObjectPool<MinionDarkTrapComponent> _trapPool` (동일)

> **주의**: `Managers.Instance` 직접 접근 부분 (`MoveTransitionEffectAsync` 내 `EffectManager` 조회)은 이미 WD 패턴으로 작성되어 있어 변환 불필요.

**변환 후 전체 코드**:

```csharp
using System;
using System.Collections.Generic;
using System.Threading;
using Cysharp.Threading.Tasks;
using UnityEngine;
using Random = UnityEngine.Random;

/// <summary>
/// 암흑 사제 함정 스킬 (미니언 ID: 2503)
///
/// 기본 공격 (isBaseAttack=true, 25031):
///   - arg1: 함정 설치 쿨타임(초)
///   - arg2: 함정 수명(초)
///   - arg3: 폭발 피해 계수(%)
///   - arg4: 인식 반지름
///   - arg5: 폭발 반지름 (인식 반지름보다 크게 설계)
///
/// 스킬 (isBaseAttack=false):
///   - Uncommon (25032): arg1=혼란 부여 확률(%), arg2=사도(Templer) 보유 시 추가 함정 소환 대기시간(초)
///   - Rare     (25033): arg1=함정 인식/폭발 반지름 증가율(%) — 폭발 VFX도 동일 배율
///   - Epic     (25034): arg1=정마름모 분열 좌표 변화량 (소형 함정 4개)
///   - Legendary(25025): arg1=혼란 확률 추가(%), arg2=혼란 적 이동속도 추가(%)
///   - Mythic   (25036): 혼란이 끝날 때 소형 함정 1개 생성
/// </summary>
public class DarkPriestTrapSkill : BaseMinionSkill
{
    private const string KEY_DARK_CONFIG = "DarkConfig";

    private const int SPAWN_POSITION_ATTEMPTS = 4;
    private const float APOSTLE_FALLBACK_DISTANCE_RATIO = 1.5f;

    /// <summary>
    /// 함정 스폰 호출 출처. 디버깅 시 어느 경로로 생성된 함정인지 식별하기 위함.
    /// </summary>
    private enum ESpawnSource
    {
        Main,      // OnExecute (시간 단위 메인 설치)
        Split,     // Epic 분열
        Apostle,   // Uncommon 사도 추가 함정 (전이)
        Mythic,    // Mythic 혼란 종료 시 소형 함정
    }

    public static void SetDarkConfig(MinionSkillContext context, MinionDarkConfigSO config)
    {
        context.SetSkillData(KEY_DARK_CONFIG, config);
    }

    private static readonly Vector3[] SPLIT_DIRECTIONS =
    {
        new Vector3(1f, 0f, 0f),
        new Vector3(-1f, 0f, 0f),
        new Vector3(0f, 1f, 0f),
        new Vector3(0f, -1f, 0f),
    };

    private MinionDarkConfigSO _config;

    private float _spawnCooldown;
    private float _lastSpawnTime = float.NegativeInfinity;

    private float _trapLifetime;
    private float _baseDetectionRadius;
    private float _baseExplosionRadius;
    private float _baseDamageCoef;

    private bool _hasUncommon;
    private float _confuseChance;
    private float _apostleSpawnDelay;

    private bool _hasRare;
    private float _rangeMultiplier = 1f;

    private bool _hasEpic;
    private float _splitOffset;

    private bool _hasLegendary;
    private float _legendaryConfuseChanceBonus;
    private float _legendarySpeedBonusPercent;

    private bool _hasMythic;

    private ObjectPoolManager _objectPoolManager;
    private IObjectPool<MinionDarkTrapComponent> _trapPool;

    private readonly Dictionary<MinionDarkTrapComponent, CancellationTokenSource> _apostleTimers
        = new Dictionary<MinionDarkTrapComponent, CancellationTokenSource>();

    public override EMinionSkillType SkillType => EMinionSkillType.DarkPriestTrap;

    /// <summary>
    /// 암흑 사제는 사거리 내 적 유무와 관계없이 시간 단위로 함정을 설치한다.
    /// 적 없는 분기에서 BaseMinionSkill의 차단을 풀고, 자체 _spawnCooldown으로 발동을 제어한다.
    /// </summary>
    public override bool RequiresEnemyForSpecialSkill => false;

    protected override void OnInitialize(MinionSkillContext context)
    {
        base.OnInitialize(context);
        _objectPoolManager = Managers.Instance.GetManager<ObjectPoolManager>();
        CacheSkillParams(context);
        // 등장 즉시 설치되지 않도록 쿨타임 시계를 지금 시점으로 시작.
        _lastSpawnTime = Time.time;
    }

    /// <summary>
    /// Config는 컨트롤러가 ConfigureSkill 단계에서 SetSkillData로 주입한다.
    /// _skill.Initialize → ConfigureSkill 순서이므로 OnInitialize 시점에는 비어 있어, 첫 사용 시점에 lazy 해석한다.
    /// </summary>
    private MinionDarkConfigSO ResolveConfig(MinionSkillContext context)
    {
        if (_config != null) return _config;
        _config = context.GetSkillData<MinionDarkConfigSO>(KEY_DARK_CONFIG);
        if (_config == null)
        {
            RLog.LogWarning($"[MinionDark] Config SO가 컨트롤러에서 주입되지 않았습니다. (key={KEY_DARK_CONFIG})");
        }
        return _config;
    }

    private void CacheSkillParams(MinionSkillContext context)
    {
        var baseData = context.BaseAttackData;
        _spawnCooldown = baseData?.arg1 ?? 0f;
        _trapLifetime = baseData?.arg2 ?? 0f;
        _baseDamageCoef = baseData?.arg3 ?? 0f;
        _baseDetectionRadius = baseData?.arg4 ?? 0f;
        _baseExplosionRadius = baseData?.arg5 ?? 0f;

        _hasUncommon = false;
        _confuseChance = 0f;
        _apostleSpawnDelay = 0f;
        _hasRare = false;
        _rangeMultiplier = 1f;
        _hasEpic = false;
        _splitOffset = 0f;
        _hasLegendary = false;
        _legendaryConfuseChanceBonus = 0f;
        _legendarySpeedBonusPercent = 0f;
        _hasMythic = false;

        var skillDataList = context.GetSkillDataByRarity(false);
        if (skillDataList == null) return;

        var effectiveRarity = context.EffectiveRarity;
        for (int i = 0; i < skillDataList.Count; i++)
        {
            var data = skillDataList[i];
            if ((int)data.skillRarity > (int)effectiveRarity) continue;

            switch (data.skillRarity)
            {
                case EMinionRarity.Uncommon:
                    _hasUncommon = true;
                    _confuseChance = data.arg1;
                    _apostleSpawnDelay = data.arg2;
                    break;
                case EMinionRarity.Rare:
                    _hasRare = true;
                    _rangeMultiplier = 1f + data.arg1 / 100f;
                    break;
                case EMinionRarity.Epic:
                    _hasEpic = true;
                    _splitOffset = data.arg1;
                    break;
                case EMinionRarity.Legendary:
                    _hasLegendary = true;
                    _legendaryConfuseChanceBonus = data.arg1;
                    _legendarySpeedBonusPercent = data.arg2;
                    break;
                case EMinionRarity.Mythic:
                    _hasMythic = true;
                    break;
            }
        }

#if DEV
        RLog.Log($"[MinionDark] 스킬 초기화 | 유효 등급={effectiveRarity}");
        RLog.Log($"[MinionDark] 기본 | 쿨타임={_spawnCooldown}, 수명={_trapLifetime}, 피해계수={_baseDamageCoef}%, 인식={_baseDetectionRadius}, 폭발={_baseExplosionRadius}");
        if (_hasUncommon) RLog.Log($"[MinionDark] Uncommon | 혼란확률={_confuseChance}%, 사도추가소환대기={_apostleSpawnDelay}");
        if (_hasRare) RLog.Log($"[MinionDark] Rare | 범위배율={_rangeMultiplier:F2}x");
        if (_hasEpic) RLog.Log($"[MinionDark] Epic | 분열 오프셋={_splitOffset}");
        if (_hasLegendary) RLog.Log($"[MinionDark] Legendary | 혼란확률+{_legendaryConfuseChanceBonus}%, 이동속도+{_legendarySpeedBonusPercent}%");
        if (_hasMythic) RLog.Log($"[MinionDark] Mythic | 혼란 종료 시 소형 함정 생성");
#endif
    }

    protected override void OnCleanup()
    {
        base.OnCleanup();
        CancelAllApostleTimers();
        _trapPool = null;
        _objectPoolManager = null;
    }

    protected override bool OnCanExecute(MinionSkillContext context)
    {
        var cfg = ResolveConfig(context);
        if (cfg == null || cfg.TrapPrefab == null) return false;
        if (_spawnCooldown <= 0f) return false;
        return Time.time - _lastSpawnTime >= _spawnCooldown;
    }

    protected override void OnExecute(MinionSkillContext context, Transform target)
    {
        Vector3 spawnPos = PickRandomSpawnPosition(context);
        SpawnTrap(context, spawnPos, isSmall: false, source: ESpawnSource.Main);
        _lastSpawnTime = Time.time;
    }

    private Vector3 PickRandomSpawnPosition(MinionSkillContext context)
    {
        var origin = context.Transform != null ? context.Transform.position : Vector3.zero;
        float range = context.AttackRange;
        float minDist = _config != null ? _config.SpawnAreaMinDistance : 0.3f;

        // 1. 사거리 내 적이 있으면 적 근처 랜덤 위치 선호
        var nearbyEnemy = PickRandomEnemyInRange(origin, range);
        if (nearbyEnemy != null)
        {
            float nearRadius = _config != null ? _config.SpawnNearEnemyRadius : 1f;
            Vector2 nearOffset = Random.insideUnitCircle * Mathf.Max(0f, nearRadius);
            Vector3 candidate = nearbyEnemy.transform.position + new Vector3(nearOffset.x, nearOffset.y, 0f);
            return ClampToValidArea(candidate, context);
        }

        // 2. 적 없음: 사거리 내 랜덤 (기존)
        for (int attempt = 0; attempt < SPAWN_POSITION_ATTEMPTS; attempt++)
        {
            Vector2 offset = Random.insideUnitCircle * range;
            if (offset.sqrMagnitude >= minDist * minDist)
            {
                return ClampToValidArea(origin + new Vector3(offset.x, offset.y, 0f), context);
            }
        }

        Vector2 fallback = Random.insideUnitCircle.normalized * Mathf.Max(minDist, range * 0.5f);
        return ClampToValidArea(origin + new Vector3(fallback.x, fallback.y, 0f), context);
    }

    private Vector3 PickApostleArrivalPosition(MinionSkillContext context, Vector3 startPos)
    {
        float minDist = _config != null ? _config.ApostleMinTransitionDistance : 1.5f;
        for (int attempt = 0; attempt < SPAWN_POSITION_ATTEMPTS; attempt++)
        {
            Vector3 candidate = PickRandomSpawnPosition(context);
            if (Vector3.Distance(candidate, startPos) >= minDist)
                return candidate;
        }

        Vector2 dir = Random.insideUnitCircle.normalized;
        if (dir.sqrMagnitude < 0.0001f) dir = Vector2.up;
        return ClampToValidArea(startPos + new Vector3(dir.x, dir.y, 0f) * minDist * APOSTLE_FALLBACK_DISTANCE_RATIO, context);
    }

    private static readonly List<BaseEnemyController> _enemyPickBuffer = new List<BaseEnemyController>(16);

    private BaseEnemyController PickRandomEnemyInRange(Vector3 origin, float range)
    {
        _enemyPickBuffer.Clear();

        var results = Physics2D.OverlapCircleAll((Vector2)origin, range, LayerMask.GetMask("Enemy"));

        for (int i = 0; i < results.Length; i++)
        {
            var enemy = results[i].GetComponentInParent<BaseEnemyController>();
            if (enemy != null && enemy.IsAlive)
                _enemyPickBuffer.Add(enemy);
        }

        if (_enemyPickBuffer.Count == 0) return null;
        return _enemyPickBuffer[Random.Range(0, _enemyPickBuffer.Count)];
    }

    private Vector3 ClampToValidArea(Vector3 position, MinionSkillContext context)
    {
        if (_config == null) return position;

        position.x = Mathf.Clamp(position.x, _config.MinX, _config.MaxX);

        float minY = _config.MinY;
        float maxY = context?.AttackRange ?? minY;
        if (maxY < minY) maxY = minY;
        position.y = Mathf.Clamp(position.y, minY, maxY);
        return position;
    }

    private MinionDarkTrapComponent SpawnTrap(MinionSkillContext context, Vector3 position, bool isSmall, ESpawnSource source)
    {
        var prefab = _config?.TrapPrefab;
        if (prefab == null || _objectPoolManager == null) return null;

        if (_trapPool == null)
        {
            _trapPool = _objectPoolManager.GetPool<MinionDarkTrapComponent>(prefab);
        }

        var trap = _trapPool.Get();
        if (trap == null) return null;

        float scale = isSmall ? _config.SplitChildScale : 1f;
        float detection = _baseDetectionRadius * scale * _rangeMultiplier;
        float explosion = _baseExplosionRadius * scale * _rangeMultiplier;
        float collisionThreshold = _config.CollisionThreshold * scale * _rangeMultiplier;

        trap.transform.position = position;
        trap.Initialize(
            _config.ActivationDelay,
            _trapLifetime,
            detection,
            explosion,
            scale,
            _config.DetectionPollInterval,
            _config.TrapMoveSpeed,
            collisionThreshold,
            _config.DrawGizmos,
            _config.DetectionColor,
            _config.ExplosionColor);

        bool canSplit = !isSmall && _hasEpic;
        bool isApostleEligible = !isSmall && source != ESpawnSource.Apostle && _hasUncommon && _apostleSpawnDelay > 0f;

        BindTrapCallbacks(context, trap, scale, isSmall, canSplit, isApostleEligible);

#if DEV
        RLog.Log($"[MinionDark] 함정 스폰 | 출처={source}, 위치={position}, 소형={isSmall}, 인식={detection:F2}, 폭발={explosion:F2}, scale={scale:F2}");
#endif
        return trap;
    }

    private void BindTrapCallbacks(MinionSkillContext context, MinionDarkTrapComponent trap, float scale, bool isSmall, bool canSplit, bool isApostleEligible)
    {
        trap.OnActivated = t =>
        {
            if (!isApostleEligible) return;
            if (!IsTemplerActive()) return;
            ScheduleApostleAdditionalTrap(context, t);
        };

        trap.OnExploded = (pos, hits, t) =>
        {
            CancelApostleTimer(t);
            HandleExplosion(context, pos, hits, scale, isSmall, canSplit);
        };

        trap.OnExpired = t =>
        {
            CancelApostleTimer(t);
        };
    }

    private void HandleExplosion(MinionSkillContext context, Vector3 position, List<BaseEnemyController> hits, float scale, bool isSmall, bool canSplit)
    {
        float damageCoef = _baseDamageCoef * scale;

        var damageResult = CalculateDamageResultWithCoefficient(context, damageCoef);
        float damage = damageResult.finalDamage;
        int minionId = context.Data?.id ?? 0;
        var raceType = context.RaceType;

        float vfxScale = scale * _rangeMultiplier;
        PlayEffectWithScale(EEffectType.VFX_Minion_Dark_Trap_Explo, position, new Vector3(vfxScale, vfxScale, 1f));

        for (int i = 0; i < hits.Count; i++)
        {
            var enemy = hits[i];
            if (enemy == null || !enemy.IsAlive) continue;

            enemy.TakeDamage(damage, raceType, minionId, position);
            PlayHitEffect(enemy.transform.position);

            if (!isSmall)
            {
                TryApplyConfuse(context, enemy);
            }
        }

#if DEV
        RLog.Log($"[MinionDark] 폭발 | 위치={position}, 적={hits.Count}명, 데미지={damage:F0}, 소형={isSmall}, 분열={canSplit}");
#endif

        if (canSplit)
        {
            SpawnSplitTraps(context, position);
        }
    }

    private void TryApplyConfuse(MinionSkillContext context, BaseEnemyController enemy)
    {
        if (!_hasUncommon) return;
        if (enemy.EnemyData != null && enemy.EnemyData.enemyType == EEnemyType.Boss) return;

        float chance = _confuseChance + (_hasLegendary ? _legendaryConfuseChanceBonus : 0f);
        if (chance <= 0f) return;

        if (Random.Range(0f, 100f) >= chance) return;

        float speedMultiplier = 1f + (_hasLegendary ? _legendarySpeedBonusPercent / 100f : 0f);

        enemy.ApplyDebuff(
            EDebuffType.Confuse,
            durationMultiplier: 1f,
            stacks: 1,
            sourceDamage: 0f,
            sourceUnit: null,
            fixedDuration: null,
            effectMultiplier: speedMultiplier);

        if (_hasMythic)
        {
            RegisterMythicConfuseEndCallback(context, enemy);
        }
    }

    private void RegisterMythicConfuseEndCallback(MinionSkillContext context, BaseEnemyController enemy)
    {
        var debuffController = enemy.GetComponent<DebuffController>();
        if (debuffController == null) return;

        Action<EDebuffType> handler = null;
        var capturedEnemy = enemy;
        var capturedContext = context;
        handler = debuffType =>
        {
            if (debuffType != EDebuffType.Confuse) return;
            debuffController.OnDebuffEnded -= handler;

            if (capturedEnemy == null) return;
            Vector3 spawnPos = capturedEnemy.transform != null
                ? capturedEnemy.transform.position
                : (capturedContext.Transform != null ? capturedContext.Transform.position : Vector3.zero);

            SpawnTrap(capturedContext, ClampToValidArea(spawnPos, capturedContext), isSmall: true, source: ESpawnSource.Mythic);
        };

        debuffController.OnDebuffEnded += handler;
    }

    private void SpawnSplitTraps(MinionSkillContext context, Vector3 origin)
    {
        if (_splitOffset <= 0f) return;

        int count = Mathf.Min(_config != null ? _config.SplitCount : SPLIT_DIRECTIONS.Length, SPLIT_DIRECTIONS.Length);
        float scale = _config != null ? _config.SplitChildScale : 0.5f;
        for (int i = 0; i < count; i++)
        {
            Vector3 splitPos = ClampToValidArea(origin + SPLIT_DIRECTIONS[i] * _splitOffset, context);
            LaunchSplitTrapAsync(context, origin, splitPos, scale).Forget();
        }

#if DEV
        RLog.Log($"[MinionDark] Epic 분열 {count}개 | 중심={origin}, 오프셋={_splitOffset}, scale={scale:F2}");
#endif
    }

    private async UniTaskVoid LaunchSplitTrapAsync(MinionSkillContext context, Vector3 startPos, Vector3 spawnPos, float scaleMultiplier)
    {
        try
        {
            await MoveTransitionEffectAsync(startPos, spawnPos, scaleMultiplier, CancellationToken.None);
            SpawnTrap(context, spawnPos, isSmall: true, source: ESpawnSource.Split);
        }
        catch (OperationCanceledException) { }
    }

    private void ScheduleApostleAdditionalTrap(MinionSkillContext context, MinionDarkTrapComponent trap)
    {
        var cts = new CancellationTokenSource();
        _apostleTimers[trap] = cts;
        ApostleAdditionalTrapAsync(context, trap, _apostleSpawnDelay, cts.Token).Forget();
    }

    private async UniTaskVoid ApostleAdditionalTrapAsync(MinionSkillContext context, MinionDarkTrapComponent originTrap, float delay, CancellationToken token)
    {
        try
        {
            await UniTask.Delay(TimeSpan.FromSeconds(delay), DelayType.DeltaTime, cancellationToken: token);
            if (token.IsCancellationRequested) return;
            if (originTrap == null || !originTrap.IsActivated || originTrap.IsExploded) return;
            if (context.Transform == null) return;

            Vector3 startPos = originTrap.transform.position;
            Vector3 spawnPos = PickApostleArrivalPosition(context, startPos);

            await MoveTransitionEffectAsync(startPos, spawnPos, scaleMultiplier: 1f, token);
            if (token.IsCancellationRequested) return;

            SpawnTrap(context, spawnPos, isSmall: false, source: ESpawnSource.Apostle);

#if DEV
            RLog.Log($"[MinionDark] 사도 추가 함정 도착 → 스폰 | 시작={startPos}, 도착={spawnPos}");
#endif
        }
        catch (OperationCanceledException) { }
        finally
        {
            _apostleTimers.Remove(originTrap);
        }
    }

    private async UniTask MoveTransitionEffectAsync(Vector3 startPos, Vector3 endPos, float scaleMultiplier, CancellationToken token)
    {
        var effectManager = Managers.Instance?.GetManager<EffectManager>();
        if (effectManager == null) return;

        var effect = await effectManager.PlayEffectWithDurationAsync(
            EEffectType.VFX_Minion_Dark_Trap_Black, startPos, customDuration: -1f);
        if (effect == null) return;

        Vector3 originalScale = effect.transform.localScale;
        effect.transform.localScale = originalScale * scaleMultiplier;

        try
        {
            var curve = _config?.TransitionArcCurve;
            float duration = _config != null ? _config.TransitionEffectDuration : 1f;
            float elapsed = 0f;
            while (elapsed < duration)
            {
                if (token.IsCancellationRequested) break;
                elapsed += Time.deltaTime;
                float t = duration > 0f ? Mathf.Clamp01(elapsed / duration) : 1f;
                float progressRatio = (curve != null && curve.length > 0)
                    ? Mathf.Clamp01(curve.Evaluate(t))
                    : t;
                if (effect != null)
                    effect.transform.position = Vector3.Lerp(startPos, endPos, progressRatio);
                await UniTask.Yield(PlayerLoopTiming.Update, token).SuppressCancellationThrow();
            }
        }
        finally
        {
            if (effect != null)
            {
                effect.transform.localScale = originalScale;
                effect.StopEffect();
            }
        }
    }

    private void CancelApostleTimer(MinionDarkTrapComponent trap)
    {
        if (_apostleTimers.TryGetValue(trap, out var cts))
        {
            cts.Cancel();
            cts.Dispose();
            _apostleTimers.Remove(trap);
        }
    }

    private void CancelAllApostleTimers()
    {
        foreach (var kv in _apostleTimers)
        {
            kv.Value?.Cancel();
            kv.Value?.Dispose();
        }
        _apostleTimers.Clear();
    }

    private static bool IsTemplerActive()
    {
        var spawnManager = Managers.Instance?.GetManager<UnitSpawnManager>();
        if (spawnManager == null) return false;
        return spawnManager.GetSpawnedUnit(EUnitType.Templer) != null;
    }
}
```

---

### 2-2. MinionDarkTrapComponent.cs

- **클래스명**: `MinionDarkTrapComponent : PooledObject<MinionDarkTrapComponent>`
- **역할**: 함정 오브젝트 상태머신 (Idle→Activated→Moving→Exploded). 데미지/디버프 로직은 없고, 스킬에 콜백(OnActivated, OnExploded, OnExpired)으로 위임.
- **주요 메서드 시그니처**:
  - `public override void OnSpawn()` — 상태 초기화, `Update` 활성화
  - `public override void OnDespawn()` — `Update` 해제, 콜백 null 초기화
  - `public void Initialize(float activationDelay, float lifetime, float detectionRadius, float explosionRadius, float visualScale, float pollInterval, float moveSpeed, float collisionThreshold, bool drawGizmos, Color detectionGizmoColor, Color explosionGizmoColor)`
  - `private void Tick(float deltaTime)` → **`private void Update()`** 로 전환

- **FROM 전용 패턴 체크리스트**:
  - [x] `using Geuneda.Services;` — 제거
  - [x] `using MarinRPG.Physics;` — 제거
  - [x] `#if UNITY_6000_5_OR_NEWER ... #endif` using 블록 — 제거
  - [x] `ITickService _tickService` 필드 — 제거
  - [x] `Action<float> _tickHandler` 필드 — 제거
  - [x] `bool _isTickSubscribed` 필드 — 제거
  - [x] `_tickHandler = Tick;` (Awake) — 제거
  - [x] `SubscribeTick()` / `UnsubscribeTick()` 메서드 전체 — 제거
  - [x] `OnSpawn()` 내 `SubscribeTick()` 호출 — 제거
  - [x] `OnDespawn()` / `OnDestroy()` 내 `UnsubscribeTick()` 호출 — 제거
  - [x] `private void Tick(float deltaTime)` → `private void Update()` (deltaTime 인자 → `Time.deltaTime` 직접 사용)
  - [x] `LowLevelPhysicsHelper.OverlapCircle(PhysicsWorld.defaultWorld, pos, radius, PhysicsLayerMapping.HitEnemyFilter)` → `Physics2D.OverlapCircleAll((Vector2)pos, radius, LayerMask.GetMask("Enemy"))`
  - [x] `LowLevelPhysicsHelper.GetOwner<BaseEnemyController>(results[i])` → `results[i].GetComponentInParent<BaseEnemyController>()`
  - [x] `using var results = ...` (`using` 해제 불필요) — 일반 배열로 변환

> **주의**: Update()는 MonoBehaviour 표준 메서드이므로 OnSpawn/OnDespawn에서 별도 활성화/비활성화 필요 없음. 단, Despawn 후 Update가 계속 돌지 않도록 `_state == Exploded` 체크는 Tick 최상단에 그대로 유지됨. OnDespawn에서 `enabled = false`를 명시적으로 처리하거나, `PooledObject<T>` 베이스의 풀 반환 시 gameObject가 SetActive(false)되어 Update가 자동 중단된다면 그대로 사용 가능. PooledObject 구현 방식에 따라 확인 필요.

**변환 후 전체 코드**:

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 암흑 사제(2503) 함정 컴포넌트
/// - Idle → activationDelay 대기 → Activated → 인식 폴링 → 적 발견 시 Moving (적 추적) → 충돌 시 폭발
///   또는 수명 만료 시 Expire
/// - 데미지/디버프/분열/Mythic 콜백 등 게임플레이 로직은 스킬(DarkPriestTrapSkill) 측에서 콜백으로 처리
/// </summary>
public class MinionDarkTrapComponent : PooledObject<MinionDarkTrapComponent>
{
    private enum EState
    {
        Idle,
        Activated,
        Moving,
        Exploded,
    }

    [Header("인식범위 비주얼 (자식 오브젝트 - 외곽링 + 내부 파티클 등 2개)")]
    [SerializeField, Tooltip("인식범위를 시각화하는 자식 Transform 배열. 인식 반지름 변화에 맞춰 스케일이 자동 조정됨")]
    private Transform[] _detectionVisuals;

    [SerializeField, Tooltip("스케일 1일 때 인식범위 비주얼의 외경(지름). 비주얼 자체 크기에 맞춰 입력")]
    private float _detectionVisualBaseSize = 2f;

    private EState _state;
    private float _activationDelay;
    private float _lifetime;
    private float _detectionRadius;
    private float _explosionRadius;
    private float _visualScale = 1f;
    private float _pollInterval = 0.05f;
    private float _moveSpeed;
    private float _collisionThreshold;
    private float _idleElapsed;
    private float _activeElapsed;
    private float _pollAccumulator;
    private bool _drawGizmos;
    private Color _detectionGizmoColor;
    private Color _explosionGizmoColor;

    private Vector3 _moveDestination;
    private BaseEnemyController _moveTargetEnemy;

    private float _collisionPollAccumulator;

#if DEV
    private float _moveStartTime;
    private Vector3 _moveStartPosition;
#endif

    /// <summary>활성화 직후 1회 발생 (사도 추가 함정 타이머 시작용)</summary>
    public Action<MinionDarkTrapComponent> OnActivated;

    /// <summary>폭발 시점 발생 - 인자: 폭발 중심, 폭발 반지름 내 적 리스트, 함정 자신</summary>
    public Action<Vector3, List<BaseEnemyController>, MinionDarkTrapComponent> OnExploded;

    /// <summary>수명 만료로 미발동 디스폰 시 발생 (Uncommon 추가 함정 타이머 취소용)</summary>
    public Action<MinionDarkTrapComponent> OnExpired;

    public bool IsActivated => _state == EState.Activated || _state == EState.Moving;
    public bool IsExploded => _state == EState.Exploded;
    public float ExplosionRadius => _explosionRadius;
    public float DetectionRadius => _detectionRadius;

    private static readonly List<BaseEnemyController> _explosionTargetsBuffer = new List<BaseEnemyController>(16);

    public override void OnSpawn()
    {
        _state = EState.Idle;
        _idleElapsed = 0f;
        _activeElapsed = 0f;
        _pollAccumulator = 0f;
        _collisionPollAccumulator = 0f;
        _moveTargetEnemy = null;

        SetVisualScale(_visualScale);
        SetDetectionVisualsActive(true);
    }

    public override void OnDespawn()
    {
        OnActivated = null;
        OnExploded = null;
        OnExpired = null;
        _moveTargetEnemy = null;
    }

    /// <summary>
    /// 함정 라이프사이클 파라미터 설정 (Spawn 직후 호출)
    /// </summary>
    public void Initialize(
        float activationDelay,
        float lifetime,
        float detectionRadius,
        float explosionRadius,
        float visualScale,
        float pollInterval,
        float moveSpeed,
        float collisionThreshold,
        bool drawGizmos,
        Color detectionGizmoColor,
        Color explosionGizmoColor)
    {
        _activationDelay = activationDelay;
        _lifetime = lifetime;
        _detectionRadius = detectionRadius;
        _explosionRadius = explosionRadius;
        _visualScale = visualScale;
        _pollInterval = pollInterval;
        _moveSpeed = moveSpeed;
        _collisionThreshold = collisionThreshold;
        _drawGizmos = drawGizmos;
        _detectionGizmoColor = detectionGizmoColor;
        _explosionGizmoColor = explosionGizmoColor;

        SetVisualScale(_visualScale);
        ApplyDetectionVisualScale();

#if DEV
        RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] Initialize | pos={transform.position} activationDelay={activationDelay:F2} lifetime={lifetime:F2} detection={detectionRadius:F2} explosion={explosionRadius:F2} moveSpeed={moveSpeed:F2} collisionThreshold={collisionThreshold:F3}");
#endif
    }

    private void Update()
    {
        float deltaTime = Time.deltaTime;

        if (_state == EState.Exploded) return;

        if (_state == EState.Idle)
        {
            _idleElapsed += deltaTime;
            if (_idleElapsed >= _activationDelay)
            {
                Activate();
            }
            return;
        }

        if (_state == EState.Moving)
        {
            Vector3 target = _moveTargetEnemy != null && _moveTargetEnemy.IsAlive
                ? _moveTargetEnemy.transform.position
                : _moveDestination;
            UpdateMove(deltaTime, target, onArrived: Explode);
            if (_state == EState.Exploded) return;

            if (PollCollisionAndExplode(deltaTime)) return;

            _activeElapsed += deltaTime;
            if (_activeElapsed >= _lifetime)
            {
                Expire();
            }
            return;
        }

        // Activated
        _activeElapsed += deltaTime;
        if (_activeElapsed >= _lifetime)
        {
            Expire();
            return;
        }

        _pollAccumulator += deltaTime;
        if (_pollAccumulator < _pollInterval) return;
        _pollAccumulator -= _pollInterval;

        if (TryFindEnemyInDetection(out var enemy))
        {
            BeginExplosionMove(enemy);
        }
    }

    private void UpdateMove(float deltaTime, Vector3 target, Action onArrived)
    {
        Vector3 cur = transform.position;
        float step = _moveSpeed * deltaTime;
        float dist = Vector3.Distance(cur, target);
        float threshold = Mathf.Max(_collisionThreshold, 0.001f);

        if (dist <= threshold)
        {
            transform.position = target;
            onArrived?.Invoke();
            return;
        }

        if (dist <= step)
        {
            transform.position = target;
            return;
        }

        transform.position = Vector3.MoveTowards(cur, target, step);
    }

    private bool PollCollisionAndExplode(float deltaTime)
    {
        _collisionPollAccumulator += deltaTime;
        if (_collisionPollAccumulator < _pollInterval) return false;
        _collisionPollAccumulator -= _pollInterval;

        if (TryFindEnemyInRadius(_collisionThreshold, out _))
        {
            Explode();
            return true;
        }
        return false;
    }

    private void Activate()
    {
        _state = EState.Activated;
        _activeElapsed = 0f;
        _pollAccumulator = _pollInterval;

#if DEV
        RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] Activate (Idle→Activated) | pos={transform.position} idleElapsed={_idleElapsed:F3} pollInterval={_pollInterval:F3}");
#endif

        OnActivated?.Invoke(this);
    }

    private void BeginExplosionMove(BaseEnemyController enemy)
    {
        if (enemy == null)
        {
#if DEV
            RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] BeginExplosionMove → enemy=null → 즉시 Explode | pos={transform.position}");
#endif
            Explode();
            return;
        }

        _moveTargetEnemy = enemy;
        _moveDestination = enemy.transform.position;

        _state = EState.Moving;
        _collisionPollAccumulator = 0f;
        SetDetectionVisualsActive(false);

#if DEV
        _moveStartTime = Time.time;
        _moveStartPosition = transform.position;

        float distToEnemy = Vector3.Distance(transform.position, enemy.transform.position);
        float threshold = Mathf.Max(_collisionThreshold, 0.001f);
        RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] BeginExplosionMove (Activated→Moving) | trap={transform.position} enemy={enemy.transform.position} dist={distToEnemy:F3} collisionThreshold={threshold:F3} willInstantExplode={(distToEnemy <= threshold)}");
#endif
    }

    private void Expire()
    {
        if (_state == EState.Exploded) return;
        _state = EState.Exploded;
#if DEV
        RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] Expire (수명만료, prevState→Exploded) | pos={transform.position} activeElapsed={_activeElapsed:F3} lifetime={_lifetime:F3}");
#endif
        OnExpired?.Invoke(this);
        Despawn();
    }

    private void Explode()
    {
        if (_state == EState.Exploded) return;
#if DEV
        var prevState = _state;
#endif
        _state = EState.Exploded;

        var hitEnemies = CollectEnemiesInExplosion();

#if DEV
        float moveDuration = Time.time - _moveStartTime;
        float moveDistance = Vector3.Distance(_moveStartPosition, transform.position);
        RLog.Log($"[MinionDark 트랩#{GetInstanceID()}] Explode ({prevState}→Exploded) | pos={transform.position} hits={hitEnemies.Count} activeElapsed={_activeElapsed:F3} moveDuration={moveDuration:F3} moveDistance={moveDistance:F3}");
#endif

        try
        {
            OnExploded?.Invoke(transform.position, hitEnemies, this);
        }
        finally
        {
            hitEnemies.Clear();
            Despawn();
        }
    }

    private bool TryFindEnemyInDetection(out BaseEnemyController firstEnemy)
    {
        return TryFindEnemyInRadius(_detectionRadius, out firstEnemy);
    }

    private bool TryFindEnemyInRadius(float radius, out BaseEnemyController firstEnemy)
    {
        firstEnemy = null;
        if (radius <= 0f) return false;

        var results = Physics2D.OverlapCircleAll((Vector2)transform.position, radius, LayerMask.GetMask("Enemy"));

        for (int i = 0; i < results.Length; i++)
        {
            var enemy = results[i].GetComponentInParent<BaseEnemyController>();
            if (enemy != null && enemy.IsAlive)
            {
                firstEnemy = enemy;
                return true;
            }
        }

        return false;
    }

    private List<BaseEnemyController> CollectEnemiesInExplosion()
    {
        _explosionTargetsBuffer.Clear();

        var results = Physics2D.OverlapCircleAll((Vector2)transform.position, _explosionRadius, LayerMask.GetMask("Enemy"));

        for (int i = 0; i < results.Length; i++)
        {
            var enemy = results[i].GetComponentInParent<BaseEnemyController>();
            if (enemy != null && enemy.IsAlive)
            {
                _explosionTargetsBuffer.Add(enemy);
            }
        }

        return _explosionTargetsBuffer;
    }

    private void SetVisualScale(float scale)
    {
        transform.localScale = new Vector3(scale, scale, 1f);
    }

    private void ApplyDetectionVisualScale()
    {
        if (_detectionVisuals == null || _detectionVisuals.Length == 0) return;
        if (_detectionVisualBaseSize <= 0f || _visualScale <= 0f) return;

        float baseRadius = _detectionVisualBaseSize * 0.5f;
        float childScale = _detectionRadius / (_visualScale * baseRadius);
        Vector3 v = new Vector3(childScale, childScale, 1f);

        for (int i = 0; i < _detectionVisuals.Length; i++)
        {
            if (_detectionVisuals[i] != null)
                _detectionVisuals[i].localScale = v;
        }
    }

    private void SetDetectionVisualsActive(bool active)
    {
        if (_detectionVisuals == null) return;
        for (int i = 0; i < _detectionVisuals.Length; i++)
        {
            if (_detectionVisuals[i] != null)
                _detectionVisuals[i].gameObject.SetActive(active);
        }
    }

#if UNITY_EDITOR
    private void OnDrawGizmosSelected()
    {
        if (!_drawGizmos) return;
        Gizmos.color = _detectionGizmoColor;
        Gizmos.DrawWireSphere(transform.position, _detectionRadius);
        Gizmos.color = _explosionGizmoColor;
        Gizmos.DrawWireSphere(transform.position, _explosionRadius);
    }
#endif
}
```

---

## 섹션 3 — TO 의존성 확인 표

### 3-1. 매니저 메서드 확인

| 메서드 | 파일 | 상태 |
|--------|------|------|
| `Managers.Instance.GetManager<ObjectPoolManager>()` | `ObjectPoolManager.cs` | ✅ 존재 |
| `ObjectPoolManager.GetPool<T>(prefab)` | `ObjectPoolManager.cs` L241 | ✅ 존재 (`GetPool<T>(T prefab, int? defaultCapacity, int? maxSize)`) |
| `IObjectPool<T>.Get()` | ObjectPool API | ✅ WD 표준 패턴 |
| `Managers.Instance.GetManager<UnitSpawnManager>()` | `UnitSpawnManager.cs` | ✅ 존재 |
| `UnitSpawnManager.GetSpawnedUnit(EUnitType)` | `UnitSpawnManager.cs` L252 | ✅ 존재 |
| `EUnitType.Templer` | UnitType enum | ✅ 존재 |
| `Managers.Instance.GetManager<EffectManager>()` | `EffectManager.cs` | ✅ 존재 |
| `EffectManager.PlayEffectWithDurationAsync(EEffectType, pos, customDuration)` | `EffectManager.cs` | ✅ 확인 필요 (시그니처 동일 여부) |
| `Physics2D.OverlapCircleAll(pos, radius, layerMask)` | Unity API | ✅ WD 전반 사용 중 |
| `GetComponentInParent<BaseEnemyController>()` | Unity API | ✅ WD 전반 사용 중 |
| `DebuffController.ApplyDebuff(EDebuffType, ...)` | `DebuffController.cs` L159 | ✅ 존재 |

### 3-2. 블로커 항목

#### 블로커 1: `EDebuffType.Confuse` 없음

- **파일**: `/Assets/_Project/1_Scripts/Core/Enums/DebuffType.cs`
- **현재 상태**: `Overload`까지만 정의 (명시적 값 없이 순서로 부여됨)
- **영향**: `DarkPriestTrapSkill.TryApplyConfuse()` 에서 `enemy.ApplyDebuff(EDebuffType.Confuse, ...)` 호출 시 컴파일 에러

**처리 방안**:
```csharp
// DebuffType.cs — Overload 다음에 추가
/// <summary>
/// 혼란 - 암흑 사제 함정 전용. 이동 속도 감소 + 방향 혼란 효과
/// </summary>
Confuse
```

#### 블로커 2: `EEffectType.VFX_Minion_Dark_Trap_Explo`, `VFX_Minion_Dark_Trap_Black` 없음

- **파일**: `/Assets/_Project/1_Scripts/Core/Enums/EEffectType.cs`
- **현재 상태**: `VFX_Minion_Rtan_Skill_Cross = 3012`까지 정의
- **영향**: `DarkPriestTrapSkill.HandleExplosion()` 및 `MoveTransitionEffectAsync()`에서 컴파일 에러

**처리 방안**:
```csharp
// EEffectType.cs — 3012 다음에 추가
VFX_Minion_Dark_Trap_Explo = 3013,   // 암흑 사제 함정 폭발 이펙트
VFX_Minion_Dark_Trap_Black = 3014,   // 암흑 사제 함정 전이(비행) 이펙트
```
> 추가 후 EffectManager의 이펙트 데이터 테이블(SO 또는 DataSheet)에도 `3013`, `3014` 항목 등록 필요.

#### 블로커 3: `DebuffController.OnDebuffEnded` 이벤트 없음

- **파일**: `/Assets/_Project/1_Scripts/Core/Controllers/Enemy/DebuffController.cs`
- **현재 상태**: `OnDebuffApplied` 이벤트만 존재. 내부 `private void OnDebuffEnd(EDebuffType, DebuffInstance)` 메서드는 있으나 외부 이벤트 없음.
- **영향**: `RegisterMythicConfuseEndCallback()` 에서 `debuffController.OnDebuffEnded += handler` 구독 시 컴파일 에러

**처리 방안**:

1. `DebuffController.cs` 이벤트 선언부에 추가:
```csharp
// OnDebuffApplied 아래에 추가 (L22 근처)
/// <summary>
/// 디버프가 제거(만료/강제 해제)될 때 발생하는 이벤트 (타입만 전달)
/// </summary>
public event Action<EDebuffType> OnDebuffEnded;
```

2. `private void OnDebuffEnd(EDebuffType debuffType, DebuffInstance debuff)` (L1030) 메서드 끝에 발동 추가:
```csharp
private void OnDebuffEnd(EDebuffType debuffType, DebuffInstance debuff)
{
    switch (debuffType)
    {
        // ... 기존 case들 ...
        case EDebuffType.Confuse:
            StopConfuseEffect();
            break;
    }
    // 이벤트 발동 (Mythic 콜백 등 외부 구독자에게 알림)
    OnDebuffEnded?.Invoke(debuffType);
}
```

3. `Cleanup()` 메서드 (L720 근처)에 null 초기화 추가:
```csharp
OnDebuffEnded = null;
```

#### 블로커 4: `Confuse` 디버프 처리 로직 미구현

- `ApplyDebuff(EDebuffType.Confuse, ...)` 호출은 가능하나, DebuffController 내부의 적용/해제 로직이 없으면 런타임에 아무 효과 없음.

**최소 구현 방안** (이동 속도 감소 기준):

```csharp
// DebuffController.cs — Overload 케이스 근처에 추가

// ApplyDebuff switch 내부 (적용 시)
case EDebuffType.Confuse:
    StartConfuseEffect(effectMultiplier);
    break;

// OnDebuffEnd switch 내부 (해제 시)  
case EDebuffType.Confuse:
    StopConfuseEffect();
    break;

// 이펙트 메서드 (기존 SlowEffect 패턴 참조)
[SerializeField] private GameObject _confuseEffectObject;

private void StartConfuseEffect(float speedMultiplier)
{
    // 이동 속도 감소: Slow 패턴과 동일하게 MovementComponent에 적용
    // speedMultiplier는 1.0 기준 (1.2 = 20% 증가, 0.8 = 20% 감소)
    // Legendary의 경우 speedMultiplier > 1.0 (적 이동속도가 오히려 증가 — 혼란 효과)
    if (_confuseEffectObject != null) _confuseEffectObject.SetActive(true);
    // TODO: MovementComponent 속도 배율 적용
}

private void StopConfuseEffect()
{
    if (_confuseEffectObject != null) _confuseEffectObject.SetActive(false);
    // TODO: MovementComponent 속도 배율 복원
}
```

> Confuse의 실제 게임 효과(이동속도 변화폭, 방향 전환 여부 등)는 기획 문서 확인 후 구현. 최소한 블로커 해소를 위해 빈 메서드로도 컴파일 가능.

---

## 섹션 4 — TO 수정 필요 기존 파일

### 4-1. MinionEnums.cs — `DarkPriestTrap` 추가

**파일**: `/Assets/_Project/1_Scripts/Core/Enums/MinionEnums.cs`

```csharp
// Before (L52~53 근처)
    ZealotProjectile = 2501,     // 질럿 투사체 (지속 다중 공격)
    RtanSpear = 2502,            // 르탄이 투창 (무제한 관통)

// After
    ZealotProjectile = 2501,     // 질럿 투사체 (지속 다중 공격)
    RtanSpear = 2502,            // 르탄이 투창 (무제한 관통)
    DarkPriestTrap = 2503,       // 암흑 사제 함정 설치
```

### 4-2. MinionSkillRegistry.cs — `DarkPriestTrap` 등록

**파일**: `/Assets/_Project/1_Scripts/Core/Controllers/Minion/Skills/MinionSkillRegistry.cs`

```csharp
// Before (르탄이 스킬 등록 다음)
        // 르탄이 스킬 (2502)
        Register(EMinionSkillType.RtanSpear, () => new RtanSpearSkill());

        _isInitialized = true;

// After
        // 르탄이 스킬 (2502)
        Register(EMinionSkillType.RtanSpear, () => new RtanSpearSkill());

        // 암흑 사제 스킬 (2503)
        Register(EMinionSkillType.DarkPriestTrap, () => new DarkPriestTrapSkill());

        _isInitialized = true;
```

### 4-3. DebuffType.cs — `Confuse` 추가

**파일**: `/Assets/_Project/1_Scripts/Core/Enums/DebuffType.cs`

```csharp
// Before
    /// <summary>
    /// 과부하 - 마비 쿨타임 중 적용되는 받는 피해 증가 디버프
    /// </summary>
    Overload
};

// After
    /// <summary>
    /// 과부하 - 마비 쿨타임 중 적용되는 받는 피해 증가 디버프
    /// </summary>
    Overload,
    /// <summary>
    /// 혼란 - 암흑 사제 함정 전용. 이동 속도 증가/방향 혼란 효과
    /// </summary>
    Confuse
};
```

### 4-4. EEffectType.cs — `VFX_Minion_Dark_Trap_Explo`, `VFX_Minion_Dark_Trap_Black` 추가

**파일**: `/Assets/_Project/1_Scripts/Core/Enums/EEffectType.cs`

```csharp
// Before
    VFX_Minion_Rtan_Skill_Cross = 3012,     // 르탄이 십자 공격 이펙트
}

// After
    VFX_Minion_Rtan_Skill_Cross = 3012,     // 르탄이 십자 공격 이펙트
    VFX_Minion_Dark_Trap_Explo = 3013,      // 암흑 사제 함정 폭발 이펙트
    VFX_Minion_Dark_Trap_Black = 3014,      // 암흑 사제 함정 전이(비행) 이펙트
}
```

### 4-5. DebuffController.cs — `OnDebuffEnded` 이벤트 추가

**파일**: `/Assets/_Project/1_Scripts/Core/Controllers/Enemy/DebuffController.cs`

변경 위치 3곳:

**① 이벤트 선언 (L22 근처)**
```csharp
// Before
    public event Action<EDebuffType, float, float, DebuffController> OnDebuffApplied;

// After
    public event Action<EDebuffType, float, float, DebuffController> OnDebuffApplied;

    /// <summary>
    /// 디버프가 제거될 때 발생하는 이벤트 (타입 전달)
    /// </summary>
    public event Action<EDebuffType> OnDebuffEnded;
```

**② `private void OnDebuffEnd()` 메서드 끝 (L1064 근처)**
```csharp
// Before (switch 블록 닫힌 직후)
        }
    }

// After
        }
        OnDebuffEnded?.Invoke(debuffType);
    }
```

**③ `Cleanup()` 메서드 (L720 근처, `OnDebuffApplied = null;` 바로 아래)**
```csharp
// Before
    OnDebuffApplied = null;

// After
    OnDebuffApplied = null;
    OnDebuffEnded = null;
```

---

## 섹션 5 — Sync 체크리스트

### Phase A — 블로커 해소 (컴파일 에러 유발)
- [x] `DebuffType.cs` — `Confuse` enum 값 추가 ✅
- [x] `EEffectType.cs` — `VFX_Minion_Dark_Trap_Explo = 3014`, `VFX_Minion_Dark_Trap_Black = 3015` 추가 ✅ ⚠️ 최초 sync 시 3013/3014로 잘못 입력되었다가 재sync에서 3014/3015로 수정
- [x] `DebuffController.cs` — `OnDebuffEnded` 이벤트 선언 추가 ✅
- [x] `DebuffController.cs` — `OnDebuffEnd()` 메서드에 `OnDebuffEnded?.Invoke(debuffType)` 추가 ✅
- [x] `DebuffController.cs` — `Cleanup()`에 `OnDebuffEnded = null` 추가 ✅
- [x] `DebuffController.cs` — `Confuse` 케이스 `ApplyDebuff` switch에 추가 ✅
- [x] `DebuffController.cs` — `OnDebuffEnd` switch에 `Confuse` 케이스 추가 ✅
- [x] `DebuffController.cs` — `StartConfuseEffect()` / `StopConfuseEffect()` 메서드 구현 ✅
- [x] EffectManager 이펙트 데이터 테이블에 `137.asset(Explo, effectType=3014)`, `138.asset(Black, effectType=3015)` 등록 ✅

### Phase B — 기존 파일 수정
- [x] `MinionEnums.cs` — `DarkPriestTrap = 2503` 추가 ✅
- [x] `MinionSkillRegistry.cs` — `DarkPriestTrap` 팩토리 등록 추가 ✅

### Phase C — 신규 파일 추가
- [x] `MinionDarkConfigSO.cs` 복사 → `Assets/_Project/1_Scripts/SOs/SO/MinionDarkConfigSO.cs` ✅
- [x] `Minion_DarkPriest_Controller.cs` 복사 → `Assets/_Project/1_Scripts/Core/Controllers/Minion/Minion_DarkPriest_Controller.cs` ✅
- [x] `DarkPriestTrapSkill.cs` **변환 후** 추가 → `Assets/_Project/1_Scripts/Core/Controllers/Minion/Skills/Implementations/DarkPriestTrapSkill.cs` ✅
- [x] `MinionDarkTrapComponent.cs` **변환 후** 추가 → `Assets/_Project/1_Scripts/Core/Components/MinionDarkTrapComponent.cs` ✅
- [ ] Unity 컴파일 확인 (에러 없음 검증) — Unity 에디터에서 직접 확인 필요

### Phase D — 프리팹 작업
- [x] `Assets/Resources/Prefabs/Minion/Minion_DarkArchon.prefab` 추가 ✅ (Resources_moved 대신 Resources/ 배치)
- [x] `Assets/Marine/Prefab/Minion/Minion_DarkArchon.prefab` 추가 ✅
- [x] `Assets/_Project/3_Prefabs/UI/Character/Minion_DarkArchon_UI.prefab` 추가 ✅
- [x] `Assets/Resources/EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Explo.prefab` 추가 ✅
- [x] `Assets/Resources/EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Black.prefab` 추가 ✅
- [x] `Assets/Marine/Prefab/Minion/VFX_Minion_Dark_Trap.prefab` 업데이트 (MinionDarkTrapComponent 추가) ✅
- [x] `MinionDarkConfig.asset` SO 에셋 복사 → `Assets/_Project/11_SO/MinionDarkConfig.asset` ✅
- [ ] Unity 에디터에서 Inspector 연결 확인 (TrapPrefab 필드, _darkConfig 필드)

### Phase E — 이미지 에셋 (재sync에서 추가 완료)
- [x] `skill_25031~25036.png` → `Assets/Resources_moved/Sprites/Icon/Minion/Skill/` 복사 ✅
- `Resources-Sprites.asset` Addressables 등록 불필요 — Addressables Importer가 자동 처리
- [x] `icon_minion_10.png` → `Assets/Resources_moved/Sprites/Icon/Minion/` 복사 ✅
- Addressables `icon_minion_10.png` 등록 불필요 — Addressables Importer가 자동 처리

### Phase F — 데이터 수정 (재sync에서 추가 완료)
- [x] `MinionManager.GetAllMinionData()` — `index` 오름차순 정렬 추가 ✅ (UI 표시 순서 보장)

### Phase H — JSON/SO 이식 (파싱 전 로컬 테스트용)

> 서버 밸런스 없이 로컬에서 바로 테스트하려면 이 Phase가 완료되어야 함.
> **currencyType 주의**: `MinionData.json`의 `rankupCurrencyType`은 FROM(673) → WD(1166)으로 매핑.

**SO 파일** (이미 완료):
- [x] `MinionData/10.asset` ✅
- [x] `MinionSkillData/25031~25036.asset` ✅
- [x] `EffectData/137.asset` (effectType=3014), `138.asset` (effectType=3015) ✅
- [x] `CurrencyData/1166.asset` (`MinionPiece_2503`) ✅

**JSON 파일**:
- [x] `MinionData.json` — DarkArchon (index=10, id=2503, rankupCurrencyType=**1166**) 추가 ✅
- [x] `MinionSkillData.json` — 25031~25036 (6개 스킬) 추가 ✅
- [x] `EffectData.json` — effectID 137 (Explo, effectType=3014), 138 (Black, effectType=3015) 추가 ✅

### Phase G — 검증
- [ ] Play Mode에서 암흑 사제 Uncommon 등급 함정 설치 동작 확인
- [ ] Mythic 등급: 혼란 디버프 종료 시 소형 함정 생성 확인
- [ ] Epic 등급: 폭발 후 4방향 소형 함정 분열 확인
- [ ] Uncommon + 사도(Templer) 보유 시 추가 함정 전이 동작 확인
- [ ] MinionMainUI에서 DarkArchon이 마지막(10번째)에 표시되는지 확인

---

## 섹션 7 — 파싱 전 로컬 테스트용 JSON/SO 이식

> 서버 밸런스 데이터가 없는 환경(로컬 테스트)에서도 DarkArchon이 정상 로드되려면 JSON 폴백 파일들이 완비되어야 한다.
> SO 파일은 `Resources/ScriptableObjects/` 아래 직접 배치, JSON은 `Resources/JsonFiles/`에 수정.

### 7-1. currencyType 매핑 (FROM → TO)

| 항목 | FROM (temp-bunker/dev) | TO (WiggleDefender) | 비고 |
|------|------------------------|----------------------|------|
| `rankupCurrencyType` (MinionData) | 673 | **1166** | WD의 `CurrencyData/1166.asset` (`MinionPiece_2503`) |

> FROM과 TO의 currencyType 체계가 다르므로 JSON 그대로 복사하면 안 됨. 반드시 WD 값(1166)으로 교체.

### 7-2. SO 파일 현황 (복사 완료)

| 파일 | 경로 | 상태 |
|------|------|------|
| `MinionDataSO` (DarkArchon) | `Resources/ScriptableObjects/MinionData/10.asset` | ✅ |
| `MinionSkillDataSO` (기본 공격) | `Resources/ScriptableObjects/MinionSkillData/25031.asset` | ✅ |
| `MinionSkillDataSO` (Uncommon~Mythic) | `Resources/ScriptableObjects/MinionSkillData/25032~25036.asset` | ✅ |
| `EffectDataSO` (함정 폭발) | `Resources/ScriptableObjects/EffectData/137.asset` | ✅ |
| `EffectDataSO` (함정 전이) | `Resources/ScriptableObjects/EffectData/138.asset` | ✅ |
| `CurrencyDataSO` (조각) | `Resources/ScriptableObjects/CurrencyData/1166.asset` | ✅ |

### 7-3. JSON 파일 수정 항목

#### MinionData.json

- **파일**: `Assets/Resources/JsonFiles/MinionData.json`
- **수정**: 배열 마지막에 DarkArchon 항목 추가
- **주의**: `rankupCurrencyType`을 FROM 값(673) 대신 WD 값(1166)으로 입력

```json
{
  "index": 10,
  "id": 2503,
  "name": "minion_name_2503",
  "raceType": 5,
  "minionRarity": 2,
  "moveType": 0,
  "attackType": 0,
  "skillType": 2503,
  "range": 8.0,
  "rankupCurrencyType": 1166,
  "prefabPath": "Prefabs/Minion/Minion_DarkArchon",
  "iconPath": "Sprites/Icon/Minion/icon_minion_10"
}
```

#### MinionSkillData.json

- **파일**: `Assets/Resources/JsonFiles/MinionSkillData.json`
- **수정**: 배열 마지막에 25031~25036 항목 6개 추가
- **currencyType 없음** — 이 파일은 매핑 불필요

```json
{"id":25031,"skillType":2503,"isBaseAttack":true,"iconPath":"Sprites/Icon/Minion/Skill/skill_25031","skillName":"skill_name_25031","skllDesc":"skill_desc_25031","skillRarity":0,"arg1":15.0,"arg2":10.0,"arg3":4000.0,"arg4":1.0,"arg5":1.0},
{"id":25032,"skillType":2503,"isBaseAttack":false,"iconPath":"Sprites/Icon/Minion/Skill/skill_25032","skillName":"skill_name_25032","skllDesc":"skill_desc_25032","skillRarity":0,"arg1":25.0,"arg2":2.0},
{"id":25033,"skillType":2503,"isBaseAttack":false,"iconPath":"Sprites/Icon/Minion/Skill/skill_25033","skillName":"skill_name_25033","skllDesc":"skill_desc_25033","skillRarity":1,"arg1":50.0},
{"id":25034,"skillType":2503,"isBaseAttack":false,"iconPath":"Sprites/Icon/Minion/Skill/skill_25034","skillName":"skill_name_25034","skllDesc":"skill_desc_25034","skillRarity":2,"arg1":2.0},
{"id":25035,"skillType":2503,"isBaseAttack":false,"iconPath":"Sprites/Icon/Minion/Skill/skill_25035","skillName":"skill_name_25035","skllDesc":"skill_desc_25035","skillRarity":3,"arg1":15.0,"arg2":100.0},
{"id":25036,"skillType":2503,"isBaseAttack":false,"iconPath":"Sprites/Icon/Minion/Skill/skill_25036","skillName":"skill_name_25036","skllDesc":"skill_desc_25036","skillRarity":4}
```

#### EffectData.json

- **파일**: `Assets/Resources/JsonFiles/EffectData.json`
- **수정**: 배열 마지막에 effectID 137/138 항목 추가
- **currencyType 없음** — 이 파일은 매핑 불필요

```json
{
  "effectID": 137,
  "optimizationSetting": true,
  "effectName": "암흑사제 함정 폭발",
  "effectType": 3014,
  "prefabPath": "EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Explo",
  "preDelay": 0.0,
  "scale": {"x": 1.0, "y": 1.0, "z": 1.0},
  "useRandomScale": false,
  "followParent": false
},
{
  "effectID": 138,
  "optimizationSetting": false,
  "effectName": "암흑사제 함정 전이",
  "effectType": 3015,
  "prefabPath": "EffectPrefabs/Minion/VFX_Minion_Dark_Trap_Black",
  "preDelay": 0.0,
  "scale": {"x": 1.0, "y": 1.0, "z": 1.0},
  "useRandomScale": false,
  "followParent": false
}
```

---

## 섹션 6 — 주의사항

### 복사 금지 파일

| 파일 | 이유 |
|------|------|
| `MinionManager.cs` | TO가 FROM보다 최신. BaseService→BaseManager, MessageBroker→EventManager 전환이 이미 완료된 WD 버전. FROM을 복사하면 전환 작업이 롤백됨. |
| `BaseMinionController.cs` | TO에 360도 공격 모드 등 WD 전용 추가 기능이 포함되어 있음. FROM 복사 시 해당 기능이 손실됨. |

### Confuse 디버프 미구현 시 런타임 동작

`EDebuffType.Confuse`를 enum에 추가하고 `ApplyDebuff`를 호출해도, `DebuffController` 내부에 `case EDebuffType.Confuse:` 처리가 없으면:
- **빌드**: 정상 (컴파일 에러 없음)
- **런타임**: `ApplyDebuff`의 switch에서 해당 케이스가 없어 적용 로직이 실행되지 않음 → 함정 폭발은 되지만 혼란 효과 없음
- **Mythic 콜백**: `OnDebuffEnded`가 발동되지 않으므로 소형 함정이 생성되지 않음
- **결론**: 테스트 단계에서 Uncommon 이상 등급의 함정 효과가 전혀 없어 즉시 발견 가능

### 프리팹 GUID 처리

- FROM의 프리팹은 FROM 프로젝트의 GUID를 가짐. TO에 `.prefab` 파일을 복사하면 `.meta` 파일의 GUID가 충돌 가능성 있음.
- **처리 방법**: Unity Editor에서 직접 새 프리팹 생성 후 컴포넌트 수동 설정 권장. 또는 `.meta` 파일 제외하고 `.prefab` 파일만 복사한 뒤 Unity가 신규 GUID 자동 생성하도록 처리.
- DataSheet에서 프리팹 경로를 참조하는 경우, 경로 문자열(`Assets/Resources/Prefabs/Minion/Minion_DarkArchon`)이 일치해야 `ResourceManager.LoadResource<T>()`가 정상 작동.

### Physics2D.OverlapCircleAll 성능 주의

- FROM의 `LowLevelPhysicsHelper`는 GC-free 방식(Unity Physics C# Job). 변환 후 `Physics2D.OverlapCircleAll`은 매 호출마다 배열 할당 발생.
- 함정이 많아질 경우(Legendary/Mythic 등급) 성능 영향 가능. 필요 시 `Physics2D.OverlapCircleNonAlloc` + 정적 배열로 교체 권장.
- 현재 WD 코드베이스(`BunkerTrapComponent.cs`, `ThorController.cs` 등)도 `OverlapCircleAll` 사용 중이므로 당장은 동일 패턴 유지.

### `PooledObject<T>`의 OnDespawn과 Update 연동

`MinionDarkTrapComponent`는 `PooledObject<T>`를 상속. TO의 `PooledObject<T>` 구현이 Despawn 시 `gameObject.SetActive(false)`를 호출한다면 `Update()`가 자동 중단되어 문제 없음. 만약 SetActive 방식이 아닌 경우, `OnDespawn()`에 `enabled = false;` 추가 또는 `Update()` 최상단에 상태 체크 강화 필요.
