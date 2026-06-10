# Vanguard 전용 칩 시스템 — 통합 구현 명세 (뽑기 · 인벤토리 · 장착 전체)

> 대상: 클라이언트 개발자
> 목표: **이 문서 하나로 Vanguard 칩의 모든 기능(데이터 → 뽑기 → 인벤토리 적재 → 장착 → 효과/CPS → UI)을 한 번에 구현**한다.
> 데이터 시트: `VanguardUnitChipPoolData`, `VanguardEquipmentChipPoolData`, `VanguardChipDropData`
> 기존 골격: `Core/Managers/Vanguard/Chip/*`, `UI/Vanguard/Component/Vanguard*ChipPanel.cs`, `Vanguard*ChipRow/Slot`, `VanguardChipDetailPopup`
> 저장소(②) / 권위 모델: `Vanguard_서버연동_파이어베이스저장_구현명세.md` 참조
> **확정 사항: 칩 뽑기는 통합 풀(Unit+Equipment 합산) 2단계 가중 추첨.**

---

## 0. 시스템 한눈에 보기

Vanguard 칩은 **본 게임 `ChipManager`와 분리된 시즌 전용 칩 빌드**다. 두 종류로 나뉘고 UI 패널이 1:1 대응한다.

| 칩 종류 | 데이터 시트 | 패널 | 슬롯 식별 | chipId | `EVanguardChipKind` |
|---|---|---|---|---|---|
| **Unit 칩** | `VanguardUnitChipPoolData` | `VanguardExclusiveChipPanel` | 대상 유닛(EUnitType)별 | int | `Exclusive` |
| **Equipment 칩** | `VanguardEquipmentChipPoolData` | `VanguardGeneralChipPanel` (6) | 장착 부위(EquipmentType) | string | `General` |

전체 파이프라인:
```
[3 DataSheet SO] ─parse→ VanguardChipPoolTable / VanguardChipDropTable
                                   │
       ┌── 뽑기(상자 개봉) ───────┘                 §2
       │   열쇠 차감 → 등급 룰렛 → 통합후보 poolWeight 룰렛 → 결과 칩
       ▼
   인벤토리 적재 (kind 자동 분류)  ── ② VanguardSaveData.vanguardOwnedChips     §3
       │
       ▼
   장착 (General 6부위 / Exclusive 유닛별)  ── ② vanguardEquippedChips         §4
       │
       ├→ 전투: ChipEffectManager 로 효과 적용                                  §5
       └→ 매칭: loadout.chips 로 클론 동기화 + 등급→CPS                          §6
```

**권위**: 뽑기·인벤토리·장착·슬롯해금은 전부 **클라 권위**(서버 칩 엔드포인트 없음). 전 상태 **②`VanguardSaveData`**(`ESaveDataType.Vanguard`)에 저장, 시즌마다 리셋(`VanguardEmberMark` 영구재화만 유지). 장착 칩만 매칭 클론에 등급으로 노출.

---

## 1. 데이터 레이어 (DataSheet SO 3종 + 런타임 테이블)

> ⚠️ CLAUDE.md: `SOs/SO/DataSheet/` SO는 Google Sheet 자동 생성 → **직접 수정 금지**. 커스텀 로직은 `*Table` 클래스로 분리.

### 1.1 타입 매핑 (필수 합의)

| 풀 | "칩 장착 부위" 의미 | 매핑 | "효과 대상 유닛" |
|---|---|---|---|
| Unit | 대상 유닛 자신 (Turret/Archon/DrFrost/Carrier/AirMan/Ninja/Vessel/Marauder/Templer/Dragoon/Thor) | `EUnitType` ownerUnit | 동일 유닛 1종 |
| Equipment | 장비 부위 (Shield/Helmet/Armor/Weapon/EnergyCore/Boots) | `EquipmentType` | 비어있음=전체 / 그룹 |

기존 enum:
- `EquipmentType`: `Shield, Helmet, Armor, Weapon, EnergyCore, Boots` (6) → General 6슬롯과 1:1.
- `EChipRarityType`: `Common0, Uncommon1, Rare2, Epic3, Legendary4, Mythic5, Transcend6` → 드랍표 7컬럼과 1:1.
- `EUnitType`: `Marine, Turret, Archon, DrFrost, Marauder, Templer, Dragoon, Vessel, Carrier, Bunker, Ninja, Thor, AirMan, None`.

> 시트 방어(파서): 소문자 `weapon`(54330/56326)·`mythic`(55131/55325) → **대소문자 무시 파싱**. chipId 공란 행(Unit Turret/Transcend) → **스킵 + 경고 로그**.

### 1.2 SO 정의 (자동 생성 규격)

```csharp
[CreateAssetMenu(fileName = "VanguardUnitChipPoolData", menuName = "GameData/CreateVanguardUnitChipPoolData")]
public class VanguardUnitChipPoolDataSO : ScriptableObject
{
    public int chipId; public string chipName;
    public EUnitType ownerUnit;          // "칩 장착 부위" = 대상 유닛
    public List<EUnitType> targetUnits;  // "효과 대상 유닛" (= ownerUnit)
    public EChipRarityType rarityType; public int poolWeight;
}

[CreateAssetMenu(fileName = "VanguardEquipmentChipPoolData", menuName = "GameData/CreateVanguardEquipmentChipPoolData")]
public class VanguardEquipmentChipPoolDataSO : ScriptableObject
{
    public string chipId; public string chipName;
    public EquipmentType slotType;       // 6부위
    public List<EUnitType> targetUnits;  // 공란=전체 / 그룹
    public EChipRarityType rarityType; public int poolWeight;
}

[CreateAssetMenu(fileName = "VanguardChipDropData", menuName = "GameData/CreateVanguardChipDropData")]
public class VanguardChipDropDataSO : ScriptableObject
{
    public string id;  // "vanguard_standard_chest" | "vanguard_special_chest"
    public int commonWeight, uncommonWeight, rareWeight, epicWeight, legendaryWeight, mysticWeight, transcendWeight;
    public int GetWeight(EChipRarityType r) => r switch {
        EChipRarityType.Common=>commonWeight, EChipRarityType.Uncommon=>uncommonWeight,
        EChipRarityType.Rare=>rareWeight, EChipRarityType.Epic=>epicWeight,
        EChipRarityType.Legendary=>legendaryWeight, EChipRarityType.Mythic=>mysticWeight,
        EChipRarityType.Transcend=>transcendWeight, _=>0 };
}
```

드랍표 값:

| id | Rare | Epic | Legend | Mythic | Transcend | 합 |
|---|---|---|---|---|---|---|
| vanguard_standard_chest | 490 | 300 | 150 | 50 | 10 | 1000 |
| vanguard_special_chest | 0 | 0 | 550 | 300 | 150 | 1000 |

### 1.3 런타임 통합 인덱스 — `VanguardChipPoolTable`

두 풀을 한 테이블로 합쳐 인덱싱(통합 풀 뽑기의 핵심).

```csharp
public static class VanguardChipPoolTable
{
    public sealed class Entry
    {
        public string chipId;              // 통합 키 (Unit은 int.ToString())
        public EVanguardChipKind kind;     // Exclusive(Unit) | General(Equipment)
        public EChipRarityType rarity;
        public int poolWeight;
        public List<EUnitType> targetUnits;
        public EquipmentType equipmentSlot;// General 전용
        public EUnitType ownerUnit;        // Exclusive 전용
    }

    private static readonly List<Entry> _all = new();
    private static readonly Dictionary<EChipRarityType, List<Entry>> _byRarity = new();   // ← 통합 풀 뽑기
    private static readonly Dictionary<EUnitType, List<Entry>> _exclusiveByUnit = new();
    private static readonly Dictionary<EquipmentType, List<Entry>> _generalBySlot = new();
    private static readonly Dictionary<string, Entry> _byId = new();
    private static readonly List<Entry> Empty = new();

    public static void Build(IReadOnlyList<VanguardUnitChipPoolDataSO> unit,
                             IReadOnlyList<VanguardEquipmentChipPoolDataSO> equip)
    {
        _all.Clear(); _byRarity.Clear(); _exclusiveByUnit.Clear(); _generalBySlot.Clear(); _byId.Clear();
        foreach (var u in unit)
        {
            if (u == null || u.chipId == 0) { continue; }
            Add(new Entry { chipId=u.chipId.ToString(), kind=EVanguardChipKind.Exclusive,
                rarity=u.rarityType, poolWeight=Mathf.Max(1,u.poolWeight),
                targetUnits=u.targetUnits ?? new(), ownerUnit=u.ownerUnit });
        }
        foreach (var e in equip)
        {
            if (e == null || string.IsNullOrEmpty(e.chipId)) continue;
            Add(new Entry { chipId=e.chipId, kind=EVanguardChipKind.General,
                rarity=e.rarityType, poolWeight=Mathf.Max(1,e.poolWeight),
                targetUnits=e.targetUnits ?? new(), equipmentSlot=e.slotType });
        }
    }

    private static void Add(Entry e)
    {
        _all.Add(e); _byId[e.chipId] = e;
        if (!_byRarity.TryGetValue(e.rarity, out var rl)) _byRarity[e.rarity] = rl = new();
        rl.Add(e);
        if (e.kind == EVanguardChipKind.Exclusive)
        { if (!_exclusiveByUnit.TryGetValue(e.ownerUnit, out var ul)) _exclusiveByUnit[e.ownerUnit]=ul=new(); ul.Add(e); }
        else
        { if (!_generalBySlot.TryGetValue(e.equipmentSlot, out var sl)) _generalBySlot[e.equipmentSlot]=sl=new(); sl.Add(e); }
    }

    public static Entry Get(string chipId) => _byId.GetValueOrDefault(chipId);
    public static IReadOnlyList<Entry> ByRarity(EChipRarityType r) => _byRarity.GetValueOrDefault(r) ?? Empty;
    public static IReadOnlyList<Entry> ExclusiveForUnit(EUnitType u) => _exclusiveByUnit.GetValueOrDefault(u) ?? Empty;
    public static IReadOnlyList<Entry> GeneralForSlot(EquipmentType s) => _generalBySlot.GetValueOrDefault(s) ?? Empty;
}
```

> **효과 수치**는 풀에 없다. Vanguard 칩 효과는 기존 마스터 칩 효과 데이터를 `chipId`로 재사용한다(§5).

---

## 2. 칩 뽑기 (통합 풀 — 확정)

### 2.1 재화 / 상자 (기존 `ECurrencyType`)

| 재화 | enum | 용도 |
|---|---|---|
| 표준 열쇠 | `VanguardStandardKey (1288)` | `vanguard_standard_chest` 개봉 |
| 특수 열쇠 | `VanguardSpecialKey (1289)` | `vanguard_special_chest` 개봉 |
| 표준 DS | `VanguardStandardDS (1286)` | 슬롯 해금 / 공격력 |
| 특수 DS | `VanguardSpecialDS (1287)` | (특수 용도) |
| 듀얼 토큰 | `VanguardDualToken (1290)` | 듀얼 |
| 엠버 마크 | `VanguardEmberMark (1291)` | 영구재화(시즌 유지) |

상자 1회 개봉 비용(예): 표준상자 = `VanguardStandardKey` 1, 특수상자 = `VanguardSpecialKey` 1. (확정값은 기획 — 상수로 분리)

### 2.2 드랍 알고리즘 (2단계 가중 추첨, 통합 풀)

```
상자 개봉 1회:
 1) 등급 룰렛   — 상자 id의 7개 등급 가중치로 룰렛 (Common/Uncommon은 0 → Rare 이상)
 2) 후보 룰렛   — 해당 등급의 [Unit + Equipment 통합] 후보에서 poolWeight 로 룰렛   ← 통합 풀
 3) 결과 칩 반환
```

```csharp
public static class VanguardChipDropTable
{
    private static readonly Dictionary<string, VanguardChipDropDataSO> _chests = new();
    public static void Build(IReadOnlyList<VanguardChipDropDataSO> rows)
    { _chests.Clear(); foreach (var r in rows) if (r != null) _chests[r.id] = r; }

    public static VanguardChipPoolTable.Entry Roll(string chestId, System.Random rng)
    {
        var chest = _chests.GetValueOrDefault(chestId);
        if (chest == null) return null;

        var rarity = RollRarity(chest, rng);                       // 1) 등급
        var candidates = VanguardChipPoolTable.ByRarity(rarity);   // 2) 통합 후보 (Unit+Equipment)
        if (candidates.Count == 0) return null;
        return WeightedPick(candidates, e => e.poolWeight, rng);   // 3) poolWeight 룰렛
    }

    private static EChipRarityType RollRarity(VanguardChipDropDataSO c, System.Random rng)
    {
        int total = 0;
        foreach (EChipRarityType r in System.Enum.GetValues(typeof(EChipRarityType))) total += c.GetWeight(r);
        if (total <= 0) return EChipRarityType.Rare;
        int roll = rng.Next(total), acc = 0;
        foreach (EChipRarityType r in System.Enum.GetValues(typeof(EChipRarityType)))
        { acc += c.GetWeight(r); if (roll < acc) return r; }
        return EChipRarityType.Rare;
    }

    private static T WeightedPick<T>(IReadOnlyList<T> list, System.Func<T,int> w, System.Random rng)
    {
        int total = 0; foreach (var x in list) total += System.Math.Max(1, w(x));
        int roll = rng.Next(total), acc = 0;
        foreach (var x in list) { acc += System.Math.Max(1, w(x)); if (roll < acc) return x; }
        return list[list.Count - 1];
    }
}
```

> 통합 풀이므로 Rare~Mythic은 전부 poolWeight=1 → 해당 등급 전체(Unit+Equipment)에서 **균등 추첨**. Transcend만 47/23/9/4 차등 → 희소 초월칩이 덜 나옴.

### 2.3 뽑기 → 인벤토리 적재 (kind 자동 분류)

뽑은 칩은 **`VanguardChipPoolTable.Get(chipId).kind`로 종류를 판정**해 같은 `vanguardOwnedChips` 리스트에 적립한다. Bag 분리는 조회 시 kind 필터로 처리(§3.1)하므로, 적재 자체는 하나의 인벤토리에 quantity 누적이면 충분하다.

```csharp
// VanguardChipGachaService — 클라 권위, ②저장
public class VanguardChipGachaService
{
    private VanguardSaveData _save;
    private Func<UniTask> _saveAsync;
    private CurrencyManager _currency;
    private System.Random _rng = new();

    public void Initialize(VanguardSaveData save, Func<UniTask> saveAsync, CurrencyManager currency)
    { _save = save; _saveAsync = saveAsync; _currency = currency; }

    /// 상자 1회 개봉. 성공 시 뽑힌 Entry 반환(실패 null).
    public async UniTask<VanguardChipPoolTable.Entry> OpenChestAsync(EVanguardChestType chestType)
    {
        var (chestId, keyType) = Resolve(chestType);

        // 1) 열쇠 차감 (클라 권위)
        if (!_currency.CanAfford(keyType, 1, true)) return null;
        if (!_currency.SpendCurrency(keyType, 1)) return null;

        // 2) 통합 풀 추첨
        var entry = VanguardChipDropTable.Roll(chestId, _rng);
        if (entry == null) return null;

        // 3) 인벤토리 적재 (kind 자동 — entry.kind 가 General/Exclusive 결정)
        AddOwnedChip(entry.chipId);

        // 4) 천장 카운트 (상자 타입별 분리)
        IncrementPity(chestType);

        await _saveAsync();
        return entry;
    }

    /// N회 개봉(10연 등). 열쇠 일괄 검사 후 순차 추첨.
    public async UniTask<List<VanguardChipPoolTable.Entry>> OpenChestMultiAsync(EVanguardChestType chestType, int count)
    {
        var (chestId, keyType) = Resolve(chestType);
        if (!_currency.CanAfford(keyType, count, true)) return null;
        if (!_currency.SpendCurrency(keyType, count)) return null;

        var results = new List<VanguardChipPoolTable.Entry>(count);
        for (int i = 0; i < count; i++)
        {
            var e = VanguardChipDropTable.Roll(chestId, _rng);
            if (e == null) continue;
            AddOwnedChip(e.chipId);
            IncrementPity(chestType);
            results.Add(e);
        }
        await _saveAsync();
        return results;
    }

    private void AddOwnedChip(string chipId)
    {
        var owned = _save.vanguardOwnedChips.Find(x => x.chipId == chipId);
        if (owned == null) { owned = new VanguardOwnedChip { chipId = chipId, count = 0 }; _save.vanguardOwnedChips.Add(owned); }
        owned.count++;
    }

    private void IncrementPity(EVanguardChestType type)
    {
        if (type == EVanguardChestType.Standard) _save.vanguardStandardChestCount++;
        else if (type == EVanguardChestType.Special) _save.vanguardSpecialChestCount++;
    }

    private (string chestId, ECurrencyType key) Resolve(EVanguardChestType t) => t switch
    {
        EVanguardChestType.Standard => ("vanguard_standard_chest", ECurrencyType.VanguardStandardKey),
        EVanguardChestType.Special  => ("vanguard_special_chest",  ECurrencyType.VanguardSpecialKey),
        _ => (null, ECurrencyType.None)
    };
}
```

### 2.4 50연 천장 (선택형 보상)

`EVanguardChestType.Standard/Special` **각각 카운트 분리**(②). 카운트가 50 도달 시:
- 선택형 칩 보상 팝업(원하는 등급/부위 또는 지정 풀에서 선택) → `AddOwnedChip(선택 chipId)` → 카운트 -50(또는 0 리셋, 기획 확정).
- 천장 도달 판정은 `OpenChestAsync` 직후 `vanguard*ChestCount >= 50` 체크로 트리거.

```csharp
public bool IsPityReady(EVanguardChestType t) =>
    (t == EVanguardChestType.Standard ? _save.vanguardStandardChestCount : _save.vanguardSpecialChestCount) >= VanguardChipConst.PityThreshold; // 50

public async UniTask ClaimPityAsync(EVanguardChestType t, string chosenChipId)
{
    if (!IsPityReady(t)) return;
    AddOwnedChip(chosenChipId);
    if (t == EVanguardChestType.Standard) _save.vanguardStandardChestCount -= VanguardChipConst.PityThreshold;
    else _save.vanguardSpecialChestCount -= VanguardChipConst.PityThreshold;
    await _saveAsync();
}
```

### 2.5 결과 표시

개봉 결과(`Entry` 또는 `List<Entry>`)를 결과 팝업에 전달. 각 결과는 `VanguardChipFactory.ToChip(entry, 1)`(§5)로 표시용 `Chip` 변환 후, 등급/부위/대상유닛/효과를 노출. 신규 획득 여부(`owned.count == 1`)로 NEW 뱃지 처리.

---

## 3. 인벤토리 (Bag) — kind 필터 조회

뽑기는 단일 리스트(`vanguardOwnedChips`)에 적립하고, **조회 시 kind로 분리**해 각 패널에 공급한다.

```csharp
// VanguardChipService (IVanguardChipProvider 구현) — §4와 동일 클래스
public IReadOnlyList<Chip> GetBag(EVanguardChipKind kind)
{
    var list = new List<Chip>();
    foreach (var owned in _save.vanguardOwnedChips)
    {
        var entry = VanguardChipPoolTable.Get(owned.chipId);
        if (entry == null || entry.kind != kind) continue;   // ← General/Exclusive 분리
        list.Add(VanguardChipFactory.ToChip(entry, owned.count));
    }
    return list;
}
```

- General 패널 Bag = `GetBag(General)` → 부위(EquipmentType)별 필터해 노출.
- Exclusive 패널 Bag = `GetBag(Exclusive)` → 유닛(targetUnits)별 필터해 노출.

---

## 4. 칩 장착 (Equip)

### 4.1 슬롯 모델 (확정)

> 현재 골격은 일부 [TEST]/stub 상태라 불일치가 있다. 아래를 **정본**으로 통일하고, `VanguardChipDetailPopup`의 `_useStubProvider`/순차해금 테스트 코드는 제거·정렬한다.

**General (공용) — `VanguardGeneralChipPanel` (6슬롯)**
- 슬롯 `index = 0..5` = `(EquipmentType)index` (`Shield/Helmet/Armor/Weapon/EnergyCore/Boots`).
- **전부 기본 해금**(해금 비용 없음). 각 슬롯엔 `slotType`이 일치하는 General 칩 1개 장착.
- `IsSlotUnlocked(General, *) = true`, `GetSlotUnlockCost(General, *) = 0`.

**Exclusive (전용) — `VanguardExclusiveChipPanel` (유닛 그리드) (4슬롯)*
- `idx = row * columns + col` (`columns = 3`).
- `col == 0` = 유닛 칸(항상 해금, 칩 슬롯 아님). `col == 1, 2` = 전용 칩 슬롯.
- `col 1`은 `VanguardStandardDS`로 해금(저렴), `col 2`는 더 비싸게 해금.
- 각 전용 슬롯엔 그 행 유닛을 `targetUnits`에 포함하는 Unit 칩 1개 장착.

상수:
```csharp
public static class VanguardChipConst
{
    public const int GeneralSlotCount = 6;        // = EquipmentType 6
    public const int ExclusiveColumns = 3;        // col0=유닛, col1/col2=칩 슬롯
    public const int ExclusiveCol1Cost = 80;      // VanguardStandardDS (기획 확정값)
    public const int ExclusiveCol2Cost = 150;
    public const int PityThreshold = 50;
}
```

### 4.2 `VanguardChipService : IVanguardChipProvider`

`VanguardChipProviderStub`을 대체. 인벤토리(§3) + 슬롯/장착 상태(②) + 통화 차감 + `OnChanged`.

```csharp
public class VanguardChipService : IVanguardChipProvider
{
    private VanguardSaveData _save;
    private Func<UniTask> _saveAsync;
    private CurrencyManager _currency;
    private IVanguardDeployProvider _deploy;   // Exclusive 행 유닛 조회

    public event Action OnChanged;
    public int GeneralSlotCount => VanguardChipConst.GeneralSlotCount;
    public int ExclusiveSlotCount { get; private set; }

    public void Initialize(VanguardSaveData save, Func<UniTask> saveAsync,
                           CurrencyManager currency, IVanguardDeployProvider deploy, int exclusiveSlotCount)
    { _save=save; _saveAsync=saveAsync; _currency=currency; _deploy=deploy; ExclusiveSlotCount=exclusiveSlotCount; }

    // ── 조회 ──────────────────────────────
    public IReadOnlyList<Chip> GetBag(EVanguardChipKind kind) { /* §3 */ ... }

    public bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex)
    {
        if (kind == EVanguardChipKind.General) return true;                  // 6슬롯 고정
        if (slotIndex % VanguardChipConst.ExclusiveColumns == 0) return true;// col0(유닛) 항상
        return _save.vanguardUnlockedExclusiveSlots.Contains(slotIndex);
    }

    public Chip GetEquippedChip(EVanguardChipKind kind, int slotIndex)
    {
        var key = _save.vanguardEquippedChips.Find(x => x.kind == (int)kind && x.slotIndex == slotIndex);
        if (key == null) return null;
        var entry = VanguardChipPoolTable.Get(key.chipId);
        return entry == null ? null : VanguardChipFactory.ToChip(entry, 1);
    }

    public int GetSlotUnlockCost(EVanguardChipKind kind, int slotIndex)
    {
        if (kind == EVanguardChipKind.General || IsSlotUnlocked(kind, slotIndex)) return 0;
        int col = slotIndex % VanguardChipConst.ExclusiveColumns;
        return col == 1 ? VanguardChipConst.ExclusiveCol1Cost : VanguardChipConst.ExclusiveCol2Cost;
    }

    // ── 액션 ──────────────────────────────
    public async UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex)
    {
        if (kind != EVanguardChipKind.Exclusive || IsSlotUnlocked(kind, slotIndex)) return false;
        int cost = GetSlotUnlockCost(kind, slotIndex);
        if (!_currency.CanAfford(ECurrencyType.VanguardStandardDS, cost, true)) return false;
        if (!_currency.SpendCurrency(ECurrencyType.VanguardStandardDS, cost)) return false;
        _save.vanguardUnlockedExclusiveSlots.Add(slotIndex);
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }

    public async UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int slotIndex, Chip chip)
    {
        if (chip == null || !IsSlotUnlocked(kind, slotIndex)) return false;
        if (!IsEquippable(kind, slotIndex, chip)) return false;        // §4.3 제약
        // 같은 칩이 다른 슬롯에 장착돼 있으면 스왑(중복 장착 금지) — 기획 확정 따라
        _save.vanguardEquippedChips.RemoveAll(x => x.chipId == chip.chipId);
        _save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == slotIndex);
        _save.vanguardEquippedChips.Add(new VanguardEquippedChip { kind=(int)kind, slotIndex=slotIndex, chipId=chip.chipId });
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }

    public async UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int slotIndex)
    {
        int removed = _save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == slotIndex);
        if (removed == 0) return false;
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }
}
```

### 4.3 장착 제약 검증 (`IsEquippable`)

```csharp
private bool IsEquippable(EVanguardChipKind kind, int slotIndex, Chip chip)
{
    var entry = VanguardChipPoolTable.Get(chip.chipId);
    if (entry == null || entry.kind != kind) return false;

    if (kind == EVanguardChipKind.General)
        return entry.equipmentSlot == (EquipmentType)slotIndex;        // 부위 일치 (슬롯 0..5 = EquipmentType)

    // Exclusive: 행 유닛이 targetUnits 에 포함 + 칩 슬롯(col!=0)
    if (slotIndex % VanguardChipConst.ExclusiveColumns == 0) return false; // 유닛 칸엔 장착 불가
    var rowUnit = _deploy?.GetSlotUnit(slotIndex);                          // 행 유닛
    return rowUnit.HasValue && entry.targetUnits.Contains(rowUnit.Value);
}
```

### 4.4 장착 플로우 (UI ↔ 서비스)

```
[General] 패널 슬롯 i 클릭
   → VanguardChipDetailPopup((EquipmentType)i, provider) 오픈
   → Bag(General).Where(slotType == (EquipmentType)i) 후보 노출
   → 후보 선택 → EquipChipAsync(General, i, chip)
   → OnChanged → 패널/팝업 Refresh

[Exclusive] 행(유닛) 칩 슬롯(col≥1) 클릭
   → 미해금: GetSlotUnlockCost 확인 → CanAfford → UnlockSlotAsync(Exclusive, idx)
   → 해금됨: 칩 선택 팝업 → Bag(Exclusive).Where(targetUnits.Contains(rowUnit)) 후보 → EquipChipAsync(Exclusive, idx, chip)
   → OnChanged → 패널 Refresh
```

- `VanguardManager`에서 stub 대신 `VanguardChipService`를 `new + Initialize` 후 패널/팝업에 주입. UI는 `IVanguardChipProvider`만 의존하므로 패널 코드 변경 불필요.
- `VanguardChipDetailPopup`: `_useStubProvider` 제거, 주입 provider만 사용. General은 §4.1대로 해금 개념 없음 → 순차 해금 테스트 분기 제거(또는 `GetSlotUnlockCost==0`이라 자연히 비활성).

---

## 5. 칩 효과 적용 (전투)

Vanguard 칩 효과는 **기존 칩 효과 파이프라인 재사용**(`agent_docs/chip_system.md`).

1. `VanguardChipFactory.ToChip(entry, count)`가 `chipId`로 마스터 효과 데이터를 찾아 `Chip` 효과 필드를 채움.
2. 전투 진입(`VanguardStagePlayService`) 시 **Vanguard 장착 칩 집합**을 효과 컨텍스트로 주입(본 게임 전역 칩과 분리). 이탈 시 clear → 전역 상태 오염 금지(매니저 규칙).
3. 데미지 모디파이어는 `DamageCalculationManager.ChipEffect.cs` 경로(유닛별 `GetTotalEffectValue`).

```csharp
public static class VanguardChipFactory
{
    public static Chip ToChip(VanguardChipPoolTable.Entry e, int count)
    {
        var eff = ChipEffectDataProvider.Get(e.chipId);  // 기존 마스터 효과 데이터 (chipId 매핑)
        return new Chip {
            chipId = e.chipId, rarity = e.rarity,
            slotType = e.kind == EVanguardChipKind.General ? e.equipmentSlot : default, // Exclusive는 미사용
            targetUnits = e.targetUnits,
            chipEffectDataId = eff?.id ?? 0,
            effectType = eff?.effectType ?? default,
            effectValue = eff?.effectValue ?? 0f,
            subEffectValue = eff?.subEffectValue ?? 0f,
            description = eff?.description,
            quantity = count,
        };
    }
}
```

> Exclusive 칩은 `kind`+`targetUnits`로만 식별(`slotType` 무시).

---

## 6. 매칭 클론 동기화 + CPS

장착 칩은 `loadout.chips`로 `enter`/`loadout/save`에 실어 보냄(서버연동 문서 §3.1/3.3). 서버는 **등급만** 보고 CPS 계산.

- 직렬화: 장착 칩 `rarity` → grade 문자열. 예 `{ "slot1": { "grade": "legend" }, ... }`.
- **CPS**(서버연동 명세 2.4): 희귀1 / 서사3 / 전설8 / 신화10 / 초월20.

```csharp
static string ToGrade(EChipRarityType r) => r switch {
    EChipRarityType.Rare=>"rare", EChipRarityType.Epic=>"epic", EChipRarityType.Legendary=>"legend",
    EChipRarityType.Mythic=>"mythic", EChipRarityType.Transcend=>"transcend", _=>"rare" };
```

> grade 키는 서버 `chips` 파싱과 1:1 합의 필요. 장착 변경 시 `loadout/save` 호출로 클론 갱신.

---

## 7. 파이어베이스 저장 (②`VanguardSaveData`)

```csharp
// VanguardSaveData 추가 필드 (전부 클라 권위)
public List<VanguardOwnedChip>    vanguardOwnedChips = new();              // 뽑기 적립 인벤토리
public List<VanguardEquippedChip> vanguardEquippedChips = new();          // 장착 (kind+slot → chipId)
public List<int> vanguardUnlockedExclusiveSlots = new();                  // 재화 해금한 Exclusive 슬롯
public int vanguardStandardChestCount = 0;                                // 표준상자 천장 카운트
public int vanguardSpecialChestCount  = 0;                                // 특수상자 천장 카운트

[Serializable] public class VanguardOwnedChip    { public string chipId; public int count; }
[Serializable] public class VanguardEquippedChip { public int kind; public int slotIndex; public string chipId; }
```

소유권/저장:

| 데이터 | 권위 | 저장 |
|---|---|---|
| 보유 칩 / 장착 / 슬롯해금 / 천장카운트 | 클라 | ② |
| 풀/드랍/효과 정의 | 데이터시트 | SO(내장) |
| 장착 칩(매칭 노출) | 클라→서버 | `loadout.chips` 클론 동기화 |
| 전투 효과 결과 | 클라 | 비저장 |

시즌 리셋(`ResetSeasonProgress`, 새 시즌 첫 enter):
```csharp
s.vanguardOwnedChips.Clear();
s.vanguardEquippedChips.Clear();
s.vanguardUnlockedExclusiveSlots.Clear();
s.vanguardStandardChestCount = 0;
s.vanguardSpecialChestCount = 0;
// VanguardEmberMark(영구재화)는 CurrencyManager 소관, 시즌 유지 — 건드리지 않음.
```

---

## 8. 매니저 조립 (`VanguardManager`)

```csharp
// InitializeAsync 내 (SeasonService 등과 동일 패턴)
_chipGachaService = new VanguardChipGachaService();
_chipGachaService.Initialize(_saveData, SaveDataAsync, GetManager<CurrencyManager>());

ChipService = new VanguardChipService();
ChipService.Initialize(_saveData, SaveDataAsync, GetManager<CurrencyManager>(), _deployProvider, exclusiveSlotCount);

// 데이터 빌드 (앱 부팅/SO 로드 시 1회)
VanguardChipPoolTable.Build(unitChipPoolSOs, equipmentChipPoolSOs);
VanguardChipDropTable.Build(chipDropSOs);
```

- 패널/팝업 주입: `panel.Initialize(ChipService, ...)`, `Show<VanguardChipDetailPopup>((EquipmentType)i, ChipService)`.
- 뽑기 진입: `VanguardShopPopup`(상자 탭) → `OpenChestAsync/OpenChestMultiAsync` → 결과 팝업 → `IsPityReady`면 천장 팝업.

---

## 9. 구현 체크리스트

**데이터**
- [ ] SO 3종 생성(자동생성 규격), 시트 오타/공란 방어 파싱
- [ ] `VanguardChipPoolTable.Build`(통합 인덱스 byRarity/byUnit/bySlot), `VanguardChipDropTable.Build`
- [ ] `chipId → ChipEffectDataSO` 매핑(`ChipEffectDataProvider`)

**뽑기**
- [ ] `VanguardChipGachaService`: 열쇠 차감 → `Roll`(통합 풀) → `AddOwnedChip`(kind 자동) → 천장++
- [ ] 단일/다회(10연) 개봉, 결과 팝업, NEW 뱃지
- [ ] 50연 천장 카운트(상자별 분리) + 선택형 보상 `ClaimPityAsync`

**인벤토리/장착**
- [ ] `VanguardChipService : IVanguardChipProvider` 구현 + stub 교체 주입
- [ ] General 6슬롯=EquipmentType(해금 없음), Exclusive col1/col2 DS 해금
- [ ] `IsEquippable`(General 부위 일치 / Exclusive 행유닛 targetUnits 포함), 중복 장착 스왑 정책
- [ ] `VanguardChipDetailPopup` `_useStubProvider`/순차해금 테스트 코드 정리

**저장/효과/매칭**
- [ ] `VanguardSaveData` 칩 필드 5종 + 보조 타입 2종, 시즌 리셋 처리
- [ ] `VanguardChipFactory.ToChip` 효과 주입, Vanguard 전투 한정 효과 컨텍스트
- [ ] `loadout.chips` rarity→grade 직렬화 + grade 키 서버 합의(CPS 표 §6)

**검증**
- [ ] 표준/특수 상자 각 10,000회 시뮬 → 등급 분포가 드랍표 비율과 일치(±오차)
- [ ] Transcend poolWeight(47/23/9/4) 비율 검증
- [ ] 뽑은 칩이 kind에 맞는 Bag(General/Exclusive)에만 노출되는지
- [ ] General 부위 불일치 / Exclusive 비대상 유닛 칩 장착 차단
- [ ] 슬롯 해금 시 DS 차감·재화 부족 토스트
- [ ] 장착 변경 → `loadout/save` 클론 chips 동기화
- [ ] 시즌 전환 → 칩 빌드 전량 리셋, EmberMark 유지

---

## 부록 A: 풀 통계 (시트 기준)

- 등급 ID 대역: Rare 52xxx / Epic 53xxx / Legendary 54xxx / Mythic 55xxx / Transcend 56xxx.
- Unit 풀 유닛: Turret, Archon, DrFrost, Carrier, AirMan, Ninja, Vessel, Marauder, Templer, Dragoon, Thor (Marine 없음).
- Equipment 풀 부위: Shield/Helmet/Armor/Weapon/EnergyCore/Boots(6). targetUnits 그룹: `Marine,Vessel,Ninja` / `Archon,Dragoon,Carrier` / `Turret,Marauder` / `Templer,Thor` / `DrFrost,AirMan` / `Marine` / 공란(전체).
- poolWeight: Transcend(56xxx)만 차등(47/23/9/4), 그 외 등급 전부 1.

## 부록 B: 타입/슬롯 매핑 요약

| 시트 컬럼               | Unit 풀               | Equipment 풀               |
| ------------------- | -------------------- | ------------------------- |
| chipId              | int→string           | string                    |
| 칩 장착 부위             | `EUnitType`(소유유닛)    | `EquipmentType`(6부위)      |
| 효과 대상 유닛            | `[소유유닛]`             | `List<EUnitType>`(공란=전체)  |
| 등급                  | `EChipRarityType`    | `EChipRarityType`         |
| 가중치                 | poolWeight           | poolWeight                |
| `EVanguardChipKind` | Exclusive            | General                   |
| 패널                  | ExclusiveChipPanel   | GeneralChipPanel          |
| 슬롯 인덱스              | `row*3+col`(col0=유닛) | `0..5 = (EquipmentType)i` |
|                     |                      |                           |

---

_작성 기준: 제공 시트 3종 + 클라 칩 골격 스냅샷. 뽑기=통합 풀 확정. 효과 수치는 기존 마스터 칩 효과 데이터(chipId 매핑) 재사용._
