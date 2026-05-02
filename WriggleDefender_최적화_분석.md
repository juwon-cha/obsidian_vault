# WriggleDefender 성능 최적화 분석
> 참조 커밋: [BunkerDefense e09ea61](https://github.com/geuneda/BunkerDefense/commit/e09ea61f56240c18db6799959310d03a1bd9b6a7) · [3c71c69](https://github.com/geuneda/BunkerDefense/commit/3c71c69f6732cc1c35af2be4d574311aa1d1f7d7) · [1e2007d](https://github.com/geuneda/BunkerDefense/commit/1e2007df884f9f5cd12fc1d82be918e55b3cb5cc)
> 분석 일자: 2026-05-02

---

## 개요

BunkerDefense(temp-bunker) 최적화 커밋과 WriggleDefender 코드를 직접 대조 분석한 결과. 아래 항목들이 미적용 상태로 확인됨.

---

## 🔴 P1 — 즉시 적용 권장

> 프레임당 반복 호출, GC 누적 효과가 가장 큰 지점

### 1. `BaseController.MaxHealth` 프레임 캐싱

**파일:** `Assets/_Project/1_Scripts/Core/Controllers/Bunker/BaseController.cs`

`MaxHealth` getter 안에서 `GetManager<ArkManager>()`, `GetManager<PunchKingDungeonManager>()`, `GetManager<DamageCalculationManager>()`, `GetManager<BunkerUpgradeManager>()`를 매번 호출. `TakeDamage`, `Heal`, `HealthRatio` 등 피격·회복 흐름에서 수십 번 접근되므로 Dictionary 조회가 그 배수로 발생.

```csharp
// 현재: MaxHealth 접근마다 최대 4개 GetManager 호출
public float MaxHealth
{
    get
    {
        var arkManager = Managers.Instance?.GetManager<ArkManager>();
        var punchKingManager = Managers.Instance?.GetManager<PunchKingDungeonManager>();
        ...
    }
}

// 개선: Time.frameCount 기반 1프레임 캐시
private int _maxHealthCachedFrame = -1;
private float _cachedMaxHealth;

public float MaxHealth
{
    get
    {
        if (Time.frameCount != _maxHealthCachedFrame)
        {
            _maxHealthCachedFrame = Time.frameCount;
            _cachedMaxHealth = CalculateMaxHealth(); // 기존 getter 로직을 private 메서드로 추출
        }
        return _cachedMaxHealth;
    }
}
```

---

### 2. `BaseController.ChipEffect.cs` / `BaseEnemyController.ChipEffect.cs` — 핫패스 GetManager 31회

**파일:**
- `Assets/_Project/1_Scripts/Core/Controllers/Bunker/BaseController.ChipEffect.cs` (GetManager **17회**)
- `Assets/_Project/1_Scripts/Core/Controllers/Enemy/BaseEnemyController.ChipEffect.cs` (GetManager **14회**)

`GetChipBunkerDefenseBonus`, `ProcessCriticalMaxHealthDamage`, `ProcessAllAttackMaxHealthDamage`, `ApplyFullHealthCriticalChipEffect` 등 피격마다 호출되는 메서드 내부에서 각각 `GetManager`를 직접 호출. `GetManager<T>()`는 내부적으로 Dictionary 조회라서 피격 1회당 최대 31회 중복 발생 가능.

```csharp
// 현재: 메서드마다 각각 GetManager
private float GetChipBunkerDefenseBonus()
{
    var chipEffectManager = Managers.Instance?.GetManager<ChipEffectManager>();
    ...
}
private float GetChipHealOnKillBonus()
{
    var chipEffectManager = Managers.Instance?.GetManager<ChipEffectManager>(); // 또 조회
    ...
}

// 개선: partial class 공유 필드, Initialize 시 1회 캐싱, Cleanup 시 null 처리
private ChipEffectManager _chipEffectManager;
private DamageCalculationManager _damageCalcManagerRef;
private GameStatisticsManager _gameStatisticsManagerRef;

// Initialize():
_chipEffectManager = Managers.Instance.GetManager<ChipEffectManager>();
_damageCalcManagerRef = Managers.Instance.GetManager<DamageCalculationManager>();
_gameStatisticsManagerRef = Managers.Instance.GetManager<GameStatisticsManager>();

// Cleanup():
_chipEffectManager = null;
_damageCalcManagerRef = null;
_gameStatisticsManagerRef = null;
```

---

### 3. `ChipEffectManager.GetAppliedEffects` + LINQ `.Where().ToList()` — 피격당 최대 15개 할당

**파일:**
- `Assets/_Project/1_Scripts/Core/Managers/ChipEffectManager.cs` (line 169)
- `Assets/_Project/1_Scripts/Core/Controllers/Enemy/BaseEnemyController.ChipEffect.cs`

`GetAppliedEffects(unitType)`는 매번 `new List<AppliedChipEffect>()`를 생성해 반환. 이를 받아서 `.Where(...).ToList()` LINQ 체이닝까지 적용하면 호출 1회당 최소 3개 오브젝트 할당. `BaseEnemyController.ChipEffect.cs`에서 이 패턴이 5개 메서드에 반복돼 피격 1회당 최대 15개 할당 가능.

```csharp
// 현재 (3중 할당 × 5개 메서드):
var effects = chipEffectManager.GetAppliedEffects(attackerUnitType)  // new List
    .Where(e => e.effectType == EChipEffectType.FullHealthCriticalDamage)  // IEnumerable 박싱
    .ToList();  // 또 new List

// 개선 방향 1: GetAppliedEffects 내부 캐시 리스트를 IReadOnlyList<T>로 직접 반환
// 개선 방향 2: .Where().ToList() 제거, for(int i) 직접 순회
for (int i = 0; i < effects.Count; i++)
{
    if (effects[i].effectType == EChipEffectType.FullHealthCriticalDamage)
    {
        totalBonus += effects[i].effectValue;
    }
}
```

---

### 4. `DamageText.cs` — DOTween Sequence + string interpolation

**파일:** `Assets/_Project/1_Scripts/UI/DamageText.cs`

`PlayAnimation()`(line 361~378)에서 매 `Show()` 호출마다 `DOTween.Sequence()` 1개 + `Tweener` 4~5개를 새로 할당. `FormatDamageText()`(line 308, 312, 316)도 `$"{damage / 1000f:F1}K"` string interpolation으로 string 오브젝트 할당. 전투 중 초당 수십~수백 회 생성되므로 GC 누적이 큼.

```csharp
// 현재: Show() 호출마다 Sequence + Tweener 4~5개 할당
_animationSequence = DOTween.Sequence()
    .Append(_rectTransform.DOScale(...))   // Tweener 할당
    .Join(_textComponent.DOFade(...))      // Tweener 할당
    .Append(_rectTransform.DOScale(...))
    .Insert(..., _rectTransform.DOAnchorPos(...))
    .Insert(..., _textComponent.DOFade(...));

// FormatDamageText: 매 피격마다 string 할당
baseText = $"{damage / 1000f:F1}K";

// 개선 방향 1: Update()에서 수동 보간으로 교체 (BunkerDefense 동일 방식)
// EaseOutBack / EaseOutQuart / EaseInQuad 이징 함수 직접 구현
// 3단계: 팝 등장(0~0.1s) → 이동+정규화(0.1~0.5s) → 페이드아웃(0.4~0.8s)

// 개선 방향 2: string → TMP SetText (내부 StringBuilder 재사용, GC 0)
// ⚠️ BunkerDefense 선례: float.IsNaN / IsInfinity / 극단값 클램프 방어 코드 필수
//    TMP SetText 내부에서 float→Decimal→Int64 변환 시 OverflowException 발생 사례 있음
private void SetDamageText(float damage, EDamageTextType damageType)
{
    const float maxDisplayable = 9e15f;
    if (float.IsNaN(damage) || float.IsInfinity(damage) || damage > maxDisplayable)
        damage = maxDisplayable;

    if (damage >= 1000f)
        _textComponent.SetText("{0:F1}K", damage / 1000f);
    else if (damage >= 100f)
        _textComponent.SetText("{0:F0}", damage);
    else
        _textComponent.SetText("{0:F1}", damage);
}
```

---

### 5. `EffectManager` — `_activeEffects` List→HashSet + `RemoveFromActiveEffects` O(n) 제거

**파일:** `Assets/_Project/1_Scripts/Core/Managers/EffectManager.cs` (line 38, 525~582)

`_activeEffects.Remove(effectInstance)`가 `List<T>` 기반 O(n) 선형 탐색. `RemoveFromActiveEffects`(line 575)에서 `foreach (var kvp in _activeEffectsByID)`로 전체 Dictionary를 순회하며 검색. 이펙트 완료마다 발생하는 핫패스.

```csharp
// 현재:
private readonly List<EffectInstance> _activeEffects = new List<EffectInstance>();

private void RemoveFromActiveEffects(EffectInstance effectInstance)
{
    _activeEffects.Remove(effectInstance);              // O(n)
    foreach (var kvp in _activeEffectsByID)             // 전체 Dictionary 순회
    {
        if (kvp.Value.Remove(effectInstance)) break;
    }
}

// 개선:
// 1) List → HashSet (Remove O(n) → O(1))
private readonly HashSet<EffectInstance> _activeEffects = new HashSet<EffectInstance>();

// 2) EffectInstance에 CachedEffectID 프로퍼티 추가 (PlayEffectAsync 시 설정)
// EffectInstance.cs:
public int CachedEffectID { get; private set; }

// 3) RemoveFromActiveEffects O(1) 직접 조회
private void RemoveFromActiveEffects(EffectInstance effectInstance)
{
    _activeEffects.Remove(effectInstance);  // O(1)
    if (_activeEffectsByID.TryGetValue(effectInstance.CachedEffectID, out var list))
        list.Remove(effectInstance);        // O(1) 직접 접근
}
```

---

## 🟠 P2 — 순차 적용 권장

> 전투 핫패스(프로젝타일·매니저) 구간

### 6. `BlizzardController.cs` / `ExplosiveProjectileController.cs` — 루프 내 반복 GetManager

**파일:**
- `Assets/_Project/1_Scripts/Core/Controllers/DrFrost/BlizzardController.cs` (GetManager **9회**)
- `Assets/_Project/1_Scripts/Core/Controllers/Marauder/ExplosiveProjectileController.cs` (GetManager **10회**)

전투 처리 루프 안에서 `GetManager<DamageCalculationManager>()`, `GetManager<DetectionManager>()`, `GetManager<EffectManager>()` 등을 반복 호출. 또한 `BlizzardController.cs` line 393에서 `_enemiesInArea`, `_tempEnemyBuffer` 필드가 있는데도 `var validEnemies = new List<>()` 를 별도 생성.

```csharp
// 개선: Initialize 시 캐싱, Cleanup 시 null 처리
private DamageCalculationManager _damageCalcManager;
private DetectionManager _detectionManager;
private EffectManager _effectManager;
private UnitSpawnManager _unitSpawnManager;

// BlizzardController line 393:
// var validEnemies = new List<>() → _tempEnemyBuffer.Clear() 후 재사용
```

---

### 7. `EnemyManager.HasEliteOrBossAlive()` / `GetAttackingEnemyCount()` — new List 복사 제거

**파일:** `Assets/_Project/1_Scripts/Core/Managers/EnemyManager.cs` (line 137~175)

칩 효과 발동마다 호출되는 두 메서드가 lock 내부에서 `new List<BaseEnemyController>(_aliveEnemies)`를 생성한 뒤 `foreach`로 순회. 적 수만큼 capacity를 할당하는 복사본이 불필요.

```csharp
// 현재:
lock (_aliveEnemiesLock)
{
    enemiesCopy = new List<BaseEnemyController>(_aliveEnemies); // 불필요한 복사
}
foreach (var enemy in enemiesCopy) { ... }

// 개선: lock 내부에서 직접 for 루프로 처리 (스냅샷 불필요)
lock (_aliveEnemiesLock)
{
    for (int i = 0; i < _aliveEnemies.Count; i++)
    {
        var enemy = _aliveEnemies[i];
        if (enemy?.EnemyData?.enemyType == EEnemyType.Elite ||
            enemy?.EnemyData?.enemyType == EEnemyType.Boss)
            return true;
    }
}
return false;
```

---

### 8. `EffectManager.EnforceMaxActiveEffects` — `RemoveAt(0)` O(n) + Queue 전환

**파일:** `Assets/_Project/1_Scripts/Core/Managers/EffectManager.cs` (line 529~537)

가장 오래된 이펙트 제거 시 `effectList.RemoveAt(0)` 는 List 전체를 앞당기는 O(n) 연산.

```csharp
// 현재:
effectList.RemoveAt(0);           // O(n) — 전체 앞당김
_activeEffects.Remove(oldestEffect); // O(n) — 선형 탐색

// 개선: effectList를 Queue<EffectInstance>로 변경
// _activeEffectsByID: Dictionary<int, Queue<EffectInstance>>
// Dequeue() → O(1)
// _activeEffects → HashSet (P1-5번과 연계)
```

---

### 9. `EffectManager.HandleEffectCompletion` — async 상태 머신 → 콜백 방식

**파일:** `Assets/_Project/1_Scripts/Core/Managers/EffectManager.cs` (line 543)

이펙트가 완료될 때마다 `async UniTaskVoid` 상태 머신 박스가 힙에 할당됨. 전투 중 이펙트 수십 개가 동시 완료되는 상황에서 누적.

```csharp
// 현재: 매 이펙트마다 async 상태 머신 박스 할당
private async UniTaskVoid HandleEffectCompletion(EffectInstance effectInstance, UniTask playTask)
{
    await playTask;
    RemoveFromActiveEffects(effectInstance);
}

// 개선: EffectInstance 완료 시 콜백 직접 호출
// EffectInstance.cs에 추가:
private System.Action<EffectInstance> _completionCallback;
public void SetCompletionCallback(System.Action<EffectInstance> cb) => _completionCallback = cb;
// CompleteEffect() 안:
_completionCallback?.Invoke(this);
_completionCallback = null;

// EffectManager.PlayEffectInternalAsync:
effectInstance.SetCompletionCallback(RemoveFromActiveEffects);
effectInstance.PlayEffectAsync(...).Forget();
// HandleEffectCompletion 메서드 삭제
```

---

### 10. `DetectionManager` — 매 호출마다 `new List` 생성

**파일:** `Assets/_Project/1_Scripts/Core/Managers/DetectionManager.cs`

- `DetectedEnemies` 프로퍼티(line 78): 매 접근마다 `new List<>(_detectedEnemiesSnapshot)` 반환
- `GetDetectedEnemiesSnapshot()`(line 193): 호출마다 `new List<>(Count)` 생성 + `foreach` 순회
- `GetEnemiesInRange()`(line 117, 119): 빈 경우 `new List<>()`, 일반 경우도 `new List<>()` 생성

`GetDetectedEnemiesSnapshot()`은 `TemplerController`, `AirManProjectile`, `StormProjectileController`, `NinjaController`, `ElectricOrbController` 등 10개 이상 컨트롤러에서 매 공격 틱마다 호출됨.

`GetEnemiesInRange()`처럼 결과를 호출자에게 전달해야 하는 경우, 재사용 버퍼 방식은 복잡도가 높으므로 Unity 내장 `ListPool<T>` 도입이 현실적인 대안.

> ⚠️ **BunkerDefense 롤백 교훈 (커밋 1e2007d):** Clear+Add 방식은 동기 콜백(ApplyRuptureEffect 등) 재진입 시 순회 중인 리스트가 붕괴되는 버그 발생. WriggleDefender도 파열 효과 등 동기 콜백이 DetectionManager에 재진입할 가능성이 동일하게 존재. `new List<>(source)` 방식 유지가 안전하며, 할당 비용 절감은 ListPool 또는 호출 빈도 감소로 접근할 것.

```csharp
// 개선 예시: ListPool<T> 활용
using UnityEngine.Pool;

public List<BaseEnemyController> GetEnemiesInRange(float range, bool canDetectStealth)
{
    var result = ListPool<BaseEnemyController>.Get(); // 풀에서 재사용
    lock (_lock)
    {
        for (int i = 0; i < _detectedEnemies.Count; i++)
        {
            ...
            result.Add(_detectedEnemies[i]);
        }
    }
    return result;
    // 호출자 책임: ListPool<BaseEnemyController>.Release(result) 호출
}
```

---

## 🟡 P3 — 점진적 개선

### 11. 전투 핫패스 `foreach` → `for(int i)` 변환

`GlobalChipEffects`가 `IReadOnlyList<T>` 인터페이스로 반환되므로 `foreach` 사용 시 interface enumerator 박싱 발생 가능. 아래 파일부터 우선 적용.

| 파일 | foreach 수 | 호출 빈도 |
|---|:---:|---|
| `AirManProjectile.cs` | 8개 | 매 틱 |
| `StormProjectileController.cs` | 5개 | 매 틱 |
| `TemplerController.cs` | 4개 | 매 공격 |
| `BlizzardController.cs` | 3개 | 매 폭발 |
| `EnemyManager.cs` | 2개 | 칩 효과마다 |
| `BaseController.ChipEffect.cs` | 다수 | 피격마다 |

---

### 12. `DebuffController` — `ContainsKey` + indexer 이중 조회 → `TryGetValue`

전투 중 디버프 적용·조회마다 Dictionary를 두 번 접근하는 패턴. 개별 임팩트는 작으나 누적 효과 있음.

```csharp
// 현재:
_activeDebuffs.ContainsKey(debuffType) ? _activeDebuffs[debuffType].currentStacks : 0

// 개선:
_activeDebuffs.TryGetValue(debuffType, out var data) ? data.currentStacks : 0
```

---

### 13. `DetectionManager.CleanupDistanceCache` — Dictionary `foreach` enumerator 할당

**파일:** `Assets/_Project/1_Scripts/Core/Managers/DetectionManager.cs` (line 826)

0.1초 간격 호출에서 `foreach (var kvp in _enemyDistanceCache)` 가 Dictionary enumerator 박싱 유발.

---

### 14. `EffectInstance.CancellationTokenSource` 재사용

**파일:** `Assets/_Project/1_Scripts/Core/Controllers/EffectInstance.cs` (line 376)

`ExecuteEffectSequenceAsync`에서 매번 `new CancellationTokenSource()` 생성. 정상 완료 시 재사용 패턴 적용 가능. 단, 취소 처리 로직 복잡도가 높아 신중하게 적용.

---

## ❌ 적용 제외 항목

| 항목 | 사유 |
|---|---|
| DetectionManager Clear+Add 재사용 | BunkerDefense에서 재진입 버그로 **롤백** 결정. WriggleDefender도 동일 위험 — 보류 |
| EnemyManager `_aliveEnemiesSnapshot` dirty 플래그 | EnemyManager 구조 차이로 별도 확인 필요 |

---

## 요약 로드맵

| 순서 | 파일 | 작업 요약 | 기대 효과 |
|:---:|---|---|---|
| 1 | `DamageText.cs` | DOTween → Update 수동 보간 + TMP SetText 전환 (오버플로우 방어 포함) | Show()마다 Sequence 1개 + Tweener 4~5개 + string 할당 제거 |
| 2 | `BaseController.cs` | MaxHealth 프레임 캐싱 | 피격마다 GetManager 4회 제거 |
| 3 | `BaseController.ChipEffect.cs` | ChipEffectManager 등 필드 캐싱 | 17회 GetManager 제거 |
| 4 | `BaseEnemyController.ChipEffect.cs` | 동일 + LINQ `.Where().ToList()` → for루프 | 14회 GetManager + 피격당 최대 15 할당 제거 |
| 5 | `ChipEffectManager.cs` | `GetAppliedEffects` new List 근본 제거 | 피격당 핵심 할당 제거 |
| 6 | `EffectManager.cs` | `_activeEffects` HashSet 전환 + `RemoveFromActiveEffects` O(1) + `EnforceMaxActiveEffects` Queue 전환 | Remove O(n)→O(1) |
| 7 | `EnemyManager.cs` | `HasEliteOrBossAlive` / `GetAttackingEnemyCount` lock 내 직접 순회 | new List 복사 제거 |
| 8 | `BlizzardController.cs` | 매니저 캐싱 + validEnemies 버퍼 재사용 | GetManager 9회 제거 |
| 9 | `ExplosiveProjectileController.cs` | 매니저 캐싱 | GetManager 10회 제거 |
| 10 | `EffectManager.cs` | `HandleEffectCompletion` → 콜백 방식 | 이펙트 완료마다 async 상태 머신 제거 |
| 11 | `DetectionManager.cs` | `GetEnemiesInRange` ListPool 도입 + `CleanupDistanceCache` for 변환 | 공격 사이클 할당 감소 |
| 12 | 핫패스 전반 | `AirManProjectile`, `StormProjectile`, `TemplerController` foreach → for + `DebuffController` TryGetValue | 점진적 GC 감소 |
