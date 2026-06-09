# Vanguard 전용 칩 시스템 구현 명세

> 대상: 클라이언트 개발자
> 범위: Vanguard(카오스 페스티벌) 전용 칩 — 데이터 시트 3종 → 풀/드랍/인벤토리/장착/효과/UI 전체
> 데이터 테이블: `VanguardUnitChipPoolData`, `VanguardEquipmentChipPoolData`, `VanguardChipDropData`
> 기존 골격: `Core/Managers/Vanguard/Chip/*`, `UI/Vanguard/Component/Vanguard*ChipPanel.cs`, `Vanguard*ChipRow/Slot`, `VanguardChipDetailPopup`
> 이 문서 하나로 Vanguard 칩 시스템을 데이터·로직·UI까지 완결 구현할 수 있도록 작성됨.
> 연계 문서: `Vanguard_서버연동_파이어베이스저장_구현명세.md`(②=`VanguardSaveData` 저장소, 권위 모델).

---

## 0. 핵심 설계 한 장 요약

Vanguard 칩은 **본 게임 `ChipManager`와 분리된 시즌 전용 칩 빌드**다. 두 종류로 나뉘고, UI 패널이 1:1 대응한다.

| 칩 종류 | 데이터 시트 | 들어갈 패널 | 슬롯 식별 | chipId 타입 |
|---|---|---|---|---|
| **Unit 칩** (유닛 전용) | `VanguardUnitChipPoolData` | **`VanguardExclusiveChipPanel`** | 대상 유닛(EUnitType)별 행 | int |
| **Equipment 칩** (장비 공용) | `VanguardEquipmentChipPoolData` | **`VanguardGeneralChipPanel`** (6슬롯) | 장착 부위(EquipmentType) | string |

- **권위(중요)**: Vanguard 칩 인벤토리·장착·슬롯해금·상자개봉은 전부 **클라 권위**(서버연동 문서 §0.2 "듀얼코인/카드/로드아웃=클라"와 동일 범주). 서버엔 칩 상자/상점 엔드포인트가 없다. 모든 상태는 **②`VanguardSaveData`**(`ESaveDataType.Vanguard`)에 저장한다.
- 단, 장착된 칩은 **매칭용 클론에 동기화**된다: `loadout.chips`로 `enter`/`loadout/save`에 실어 보내고, 서버는 등급으로 CPS만 계산(§6).
- 시즌 리셋 대상: Vanguard 칩 빌드는 시즌마다 초기화(서버연동 문서 §5.4). `VanguardEmberMark`(영구재화)만 시즌 간 유지.

데이터 흐름:
```
[3 DataSheet SO] ──parse──> VanguardChipPoolTable / VanguardChipDropTable  (런타임 인덱스)
        │                              │
        │                      상자 개봉(드랍)  ─────────────┐
        ▼                                                    ▼
VanguardChipService : IVanguardChipProvider  ←─ 인벤토리/슬롯/장착 상태 (②VanguardSaveData)
        │  (OnChanged)                                       │
        ▼                                                    ▼
GeneralChipPanel(6) / ExclusiveChipPanel(유닛그리드)   전투 시 ChipEffectManager 로 효과 적용 + CPS 계산
```

---

## 1. 데이터 레이어 — DataSheet SO 3종 + 파서

> ⚠️ **CLAUDE.md 규칙**: `SOs/SO/DataSheet/` 의 SO는 Google Sheet에서 자동 생성되는 파일이라 **직접 수정 금지**. 커스텀 로직은 별도 `*Table`/`*Parser` 클래스로 분리한다.

### 1.1 컬럼 → 타입 매핑 (반드시 합의)

테이블 헤더의 "칩 장착 부위(EChipSlotType)"는 **두 풀에서 의미가 다르다.** 프로젝트엔 `EChipSlotType` enum이 없으므로 아래로 해석한다.

| 풀 | "칩 장착 부위" 의미 | 매핑 타입 | "효과 대상 유닛" |
|---|---|---|---|
| Unit 칩 | **대상 유닛 자신** (Turret/Archon/DrFrost/Carrier/AirMan/Ninja/Vessel/Marauder/Templer/Dragoon/Thor) | `EUnitType` (소유 유닛) | 동일 유닛 1종 |
| Equipment 칩 | **장비 부위** (Shield/Helmet/Armor/Weapon/EnergyCore/Boots) | `EquipmentType` | 비어있음=전체 / 그룹(`Marine,Vessel,Ninja` 등) |

- `EquipmentType`(기존): `Shield, Helmet, Armor, Weapon, EnergyCore, Boots` — **정확히 6개** → General 패널 6슬롯과 1:1.
- `EChipRarityType`(기존): `Common0, Uncommon1, Rare2, Epic3, Legendary4, Mythic5, Transcend6` — 드랍 테이블 7개 가중치 컬럼과 1:1.
- `EUnitType`(기존): `Marine, Turret, Archon, DrFrost, Marauder, Templer, Dragoon, Vessel, Carrier, Bunker, Ninja, Thor, AirMan, None`.

> 테이블 표기 정리 필요(파서에서 방어): Equipment 풀에 `weapon`(소문자 54330/56326), `mythic`(소문자 55131/55325) 오타가 있다 → 파서는 **대소문자 무시 파싱**. Unit 풀에 chipId 공란 1행(Turret/Transcend/weight4)이 있다 → **chipId 없는 행은 스킵 + 경고 로그**.

### 1.2 SO 정의 (자동 생성 규격)

```csharp
// SOs/SO/DataSheet/VanguardUnitChipPoolDataSO.cs  — 시트 VanguardUnitChipPoolData (자동생성, 직접수정금지)
[CreateAssetMenu(fileName = "VanguardUnitChipPoolData", menuName = "GameData/CreateVanguardUnitChipPoolData")]
public class VanguardUnitChipPoolDataSO : ScriptableObject
{
    public int chipId;                 // 52003 ...
    public string chipName;            // (자동명: 빈 값이면 Chip.chipName 규칙 사용)
    public EUnitType ownerUnit;        // "칩 장착 부위" = 대상 유닛
    public List<EUnitType> targetUnits;// "효과 대상 유닛" (= ownerUnit 1종)
    public EChipRarityType rarityType; // Rare~Transcend
    public int poolWeight;             // 동일 등급 내 선택 가중치
}

// SOs/SO/DataSheet/VanguardEquipmentChipPoolDataSO.cs — 시트 VanguardEquipmentChipPoolData
[CreateAssetMenu(fileName = "VanguardEquipmentChipPoolData", menuName = "GameData/CreateVanguardEquipmentChipPoolData")]
public class VanguardEquipmentChipPoolDataSO : ScriptableObject
{
    public string chipId;              // 52001 ... (string)
    public string chipName;
    public EquipmentType slotType;     // Shield/Helmet/Armor/Weapon/EnergyCore/Boots
    public List<EUnitType> targetUnits;// 비어있음=전체, 또는 그룹
    public EChipRarityType rarityType;
    public int poolWeight;
}

// SOs/SO/DataSheet/VanguardChipDropDataSO.cs — 시트 VanguardChipDropData
[CreateAssetMenu(fileName = "VanguardChipDropData", menuName = "GameData/CreateVanguardChipDropData")]
public class VanguardChipDropDataSO : ScriptableObject
{
    public string id;                  // "vanguard_standard_chest" | "vanguard_special_chest"
    public int commonWeight;
    public int uncommonWeight;
    public int rareWeight;
    public int epicWeight;
    public int legendaryWeight;
    public int mysticWeight;
    public int transcendWeight;

    // 인덱서 (rarity → weight) — 파서/테이블에서 사용
    public int GetWeight(EChipRarityType r) => r switch
    {
        EChipRarityType.Common    => commonWeight,
        EChipRarityType.Uncommon  => uncommonWeight,
        EChipRarityType.Rare      => rareWeight,
        EChipRarityType.Epic      => epicWeight,
        EChipRarityType.Legendary => legendaryWeight,
        EChipRarityType.Mythic    => mysticWeight,
        EChipRarityType.Transcend => transcendWeight,
        _ => 0
    };
}
```

드랍 테이블 값(참고):

| id | Rare | Epic | Legend | Mythic | Transcend | 합 |
|---|---|---|---|---|---|---|
| vanguard_standard_chest | 490 | 300 | 150 | 50 | 10 | 1000 |
| vanguard_special_chest | 0 | 0 | 550 | 300 | 150 | 1000 |

(Common/Uncommon은 두 상자 모두 0 → Rare 이상만 출현.)

### 1.3 런타임 인덱스 — `VanguardChipPoolTable`

SO 리스트를 받아 빠른 조회 인덱스를 만든다. (`VanguardTierTable` 패턴)

```csharp
public static class VanguardChipPoolTable
{
    // 풀 종류 구분
    public sealed class Entry
    {
        public string chipId;             // 두 풀 통합 키 (Unit은 int.ToString())
        public EVanguardChipKind kind;    // Exclusive(Unit) | General(Equipment)
        public EChipRarityType rarity;
        public int poolWeight;
        public List<EUnitType> targetUnits;
        public EquipmentType equipmentSlot; // General 전용
        public EUnitType ownerUnit;         // Exclusive 전용
    }

    private static readonly List<Entry> _all = new();
    // 인덱스
    private static readonly Dictionary<EChipRarityType, List<Entry>> _byRarity = new();      // 드랍용
    private static readonly Dictionary<EUnitType, List<Entry>> _exclusiveByUnit = new();     // 유닛별 전용칩
    private static readonly Dictionary<EquipmentType, List<Entry>> _generalBySlot = new();   // 부위별 공용칩
    private static readonly Dictionary<string, Entry> _byId = new();

    public static void Build(IReadOnlyList<VanguardUnitChipPoolDataSO> unit,
                             IReadOnlyList<VanguardEquipmentChipPoolDataSO> equip)
    {
        Clear();
        foreach (var u in unit)
        {
            if (u == null || u.chipId == 0) continue; // 공란 행 스킵
            Add(new Entry {
                chipId = u.chipId.ToString(), kind = EVanguardChipKind.Exclusive,
                rarity = u.rarityType, poolWeight = Mathf.Max(1, u.poolWeight),
                targetUnits = u.targetUnits, ownerUnit = u.ownerUnit });
        }
        foreach (var e in equip)
        {
            if (e == null || string.IsNullOrEmpty(e.chipId)) continue;
            Add(new Entry {
                chipId = e.chipId, kind = EVanguardChipKind.General,
                rarity = e.rarityType, poolWeight = Mathf.Max(1, e.poolWeight),
                targetUnits = e.targetUnits ?? new(), equipmentSlot = e.slotType });
        }
    }

    private static void Add(Entry e)
    {
        _all.Add(e); _byId[e.chipId] = e;
        _byRarity.GetOrAdd(e.rarity).Add(e);
        if (e.kind == EVanguardChipKind.Exclusive) _exclusiveByUnit.GetOrAdd(e.ownerUnit).Add(e);
        else _generalBySlot.GetOrAdd(e.equipmentSlot).Add(e);
    }

    public static Entry Get(string chipId) => _byId.GetValueOrDefault(chipId);
    public static IReadOnlyList<Entry> ByRarity(EChipRarityType r) => _byRarity.GetValueOrDefault(r) ?? Empty;
    public static IReadOnlyList<Entry> ExclusiveForUnit(EUnitType u) => _exclusiveByUnit.GetValueOrDefault(u) ?? Empty;
    public static IReadOnlyList<Entry> GeneralForSlot(EquipmentType s) => _generalBySlot.GetValueOrDefault(s) ?? Empty;
}
```

> **효과 수치는 어디서?** 풀 테이블엔 효과값이 없다. Vanguard 칩 효과는 **기존 마스터 칩 효과 데이터를 chipId로 재사용**한다(`ChipManager`/`ChipEffectDataSO`의 `chipEffectDataId`/`effectType`/`effectValue`). 즉 풀 테이블은 "Vanguard에서 어떤 칩이 어떤 확률로 나오는가"만 정의하고, 효과 정의는 본 게임 칩 데이터와 공유한다(§5). 파서는 `chipId → ChipEffectDataSO` 매핑을 연결한다.

---

## 2. 드랍/가챠 — `VanguardChipDropTable` + 상자 개봉

### 2.1 재화 / 상자 (기존 `ECurrencyType`)

| 재화 | enum | 용도 |
|---|---|---|
| 표준 데이터 샤드 | `VanguardStandardDS (1286)` | 공격력 부스트 / 슬롯 해금 / 일반상자 |
| 특수 데이터 샤드 | `VanguardSpecialDS (1287)` | 특수상자 |
| 표준 열쇠 | `VanguardStandardKey (1288)` | `vanguard_standard_chest` 오픈 |
| 특수 열쇠 | `VanguardSpecialKey (1289)` | `vanguard_special_chest` 오픈 |
| 듀얼 토큰 | `VanguardDualToken (1290)` | PvP 듀얼 (4h당 +1) |
| 엠버 마크 | `VanguardEmberMark (1291)` | 영구 보상 재화(시즌 유지) |

### 2.2 드랍 알고리즘 (2단계 가중 추첨)

```
상자 개봉 1회:
 1) rarity 추첨  — 상자 id의 7개 등급 가중치(VanguardChipDropDataSO.GetWeight)로 룰렛
 2) 후보 칩 추첨 — 해당 rarity의 후보 리스트에서 poolWeight 로 룰렛
       후보 리스트 = (pool-kind 결정에 따름, 아래)
 3) 결과 칩을 인벤토리에 적립 (②), 중복이면 quantity++
```

```csharp
public static class VanguardChipDropTable
{
    private static readonly Dictionary<string, VanguardChipDropDataSO> _chests = new();
    public static void Build(IReadOnlyList<VanguardChipDropDataSO> rows)
    { _chests.Clear(); foreach (var r in rows) if (r != null) _chests[r.id] = r; }

    /// chestId: "vanguard_standard_chest" | "vanguard_special_chest"
    public static VanguardChipPoolTable.Entry Roll(string chestId, System.Random rng)
    {
        var chest = _chests.GetValueOrDefault(chestId);
        if (chest == null) return null;

        // 1) rarity 룰렛
        var rarity = RollRarity(chest, rng);
        // 2) 후보 = 해당 rarity 전체(Unit+Equipment 통합) — §2.3 정책
        var candidates = VanguardChipPoolTable.ByRarity(rarity);
        if (candidates.Count == 0) return null;
        // 3) poolWeight 룰렛
        return WeightedPick(candidates, e => e.poolWeight, rng);
    }

    private static EChipRarityType RollRarity(VanguardChipDropDataSO c, System.Random rng)
    {
        int total = 0; foreach (EChipRarityType r in System.Enum.GetValues(typeof(EChipRarityType))) total += c.GetWeight(r);
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

### 2.3 ⚠️ 확정 필요한 단 하나의 설계 결정 — "후보 풀 종류"

드랍 테이블은 **등급만** 룰렛한다. 등급 결정 후 후보를 **Unit 풀 / Equipment 풀 중 어디서 뽑을지**는 시트에 명시가 없다. 세 가지 안:

1. **통합 풀(기본 권장)**: 같은 등급의 Unit+Equipment를 한 후보군으로 합쳐 `poolWeight` 룰렛. (Rare~Mythic은 전부 weight 1이라 균등, Transcend만 47/23/9/4 차등) — 위 코드가 이 방식.
2. **상자별 풀 고정**: 예) standard=Equipment, special=Unit. → `VanguardChipDropDataSO`에 `poolKind` 컬럼 추가 후 `ByRarity` 대신 kind 필터.
3. **별도 kind 룰렛**: rarity 후 Unit/Equipment를 별도 가중치로 추첨. → 시트에 kind 가중치 추가 필요.

> 기획에 **상자가 Unit/Equipment를 섞어 주는지, 분리해 주는지**만 확인하면 된다. 미확정 시 1안(통합)으로 진행하고, 분리가 필요하면 드랍 SO에 `poolKind` 한 컬럼만 추가하면 코드 분기 최소.

### 2.4 50연 천장 선택형 보상 (`EVanguardChestType`)

`EVanguardChestType.Standard/Special` **각각 카운트 분리**. 상자 개봉마다 카운트++, 50 도달 시 선택형 칩(원하는 등급/부위 직접 선택) 보상 + 카운트 리셋. 카운트는 ②에 저장(`vanguardStandardChestCount`/`vanguardSpecialChestCount`). 천장 선택 풀/등급은 기획 확정값.

---

## 3. 인벤토리/장착 서비스 — `VanguardChipService : IVanguardChipProvider`

현재 `VanguardChipProviderStub`(로컬 더미)을 **실데이터 + ②저장** 구현으로 교체한다. 인터페이스는 그대로 사용(패널이 이미 의존).

### 3.1 인터페이스 계약 (기존, 변경 없음)

```csharp
public interface IVanguardChipProvider
{
    IReadOnlyList<Chip> GetBag(EVanguardChipKind kind);
    bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex);
    Chip GetEquippedChip(EVanguardChipKind kind, int slotIndex);
    int GetSlotUnlockCost(EVanguardChipKind kind, int slotIndex);   // VanguardStandardDS, 0=Locked(선행 필요)
    int GeneralSlotCount { get; }     // 6
    int ExclusiveSlotCount { get; }   // 유닛 그리드 슬롯 수
    UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex);
    UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int slotIndex, Chip chip);
    UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int slotIndex);
    event Action OnChanged;
}
```

### 3.2 슬롯 인덱싱 규약 (패널 코드와 일치 — 필수)

- **General**: 슬롯 `i = 0..5` ↔ `(EquipmentType)i` = `Shield/Helmet/Armor/Weapon/EnergyCore/Boots`. 슬롯은 항상 고정(해금 불필요, 패널 `Refresh`가 그렇게 가정). 슬롯 i엔 `slotType == (EquipmentType)i`인 General 칩만 장착 가능.
- **Exclusive**: `idx = row*columns + col`(columns=3). `col==0`은 항상 해금(유닛 칸), `col>=1`은 `VanguardStandardDS`로 재화 해금. 행 r은 배치 유닛(`IVanguardDeployProvider.GetSlotUnit(idx)`)에 대응하며, 그 유닛의 전용 슬롯에는 `targetUnits.Contains(rowUnit)`인 Unit 칩만 장착 가능.

### 3.3 구현 골격

```csharp
public class VanguardChipService : IVanguardChipProvider
{
    private VanguardSaveData _save;
    private Func<UniTask> _saveAsync;
    private CurrencyManager _currency;

    public event Action OnChanged;
    public int GeneralSlotCount => 6;
    public int ExclusiveSlotCount { get; private set; } // = 유닛수 * columns (배치 그리드 기준)

    public void Initialize(VanguardSaveData save, Func<UniTask> saveAsync, CurrencyManager currency, int exclusiveSlotCount)
    { _save = save; _saveAsync = saveAsync; _currency = currency; ExclusiveSlotCount = exclusiveSlotCount; }

    // Bag: ②의 보유 칩ID → 런타임 Chip 변환 (kind로 필터). 효과는 chipId로 마스터 효과데이터에서 채움.
    public IReadOnlyList<Chip> GetBag(EVanguardChipKind kind)
    {
        var list = new List<Chip>();
        foreach (var owned in _save.vanguardOwnedChips)
        {
            var entry = VanguardChipPoolTable.Get(owned.chipId);
            if (entry == null || entry.kind != kind) continue;
            list.Add(VanguardChipFactory.ToChip(entry, owned.count)); // §5 효과 주입
        }
        return list;
    }

    public bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex)
    {
        if (kind == EVanguardChipKind.General) return true;          // 6슬롯 고정
        if (slotIndex % 3 == 0) return true;                          // Exclusive col0 항상 해금
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
        if (IsSlotUnlocked(kind, slotIndex)) return 0;
        if (kind == EVanguardChipKind.Exclusive)
            return slotIndex % 3 == 1 ? VanguardChipConst.ExclusiveCol1Cost : VanguardChipConst.ExclusiveCol2Cost;
        return 0; // General은 해금 개념 없음
    }

    public async UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex)
    {
        if (kind != EVanguardChipKind.Exclusive || IsSlotUnlocked(kind, slotIndex)) return false;
        int cost = GetSlotUnlockCost(kind, slotIndex);
        if (!_currency.TrySpend(ECurrencyType.VanguardStandardDS, cost)) return false; // 클라 권위 차감
        _save.vanguardUnlockedExclusiveSlots.Add(slotIndex);
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }

    public async UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int slotIndex, Chip chip)
    {
        if (!IsSlotUnlocked(kind, slotIndex) || chip == null) return false;
        if (!IsEquippable(kind, slotIndex, chip)) return false;       // §3.4 제약 검증
        _save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == slotIndex);
        _save.vanguardEquippedChips.Add(new VanguardEquippedChip { kind = (int)kind, slotIndex = slotIndex, chipId = chip.chipId });
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }

    public async UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int slotIndex)
    {
        _save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == slotIndex);
        await _saveAsync(); OnChanged?.Invoke(); return true;
    }
}
```

### 3.4 장착 제약 검증 (`IsEquippable`)

```csharp
bool IsEquippable(EVanguardChipKind kind, int slotIndex, Chip chip)
{
    var entry = VanguardChipPoolTable.Get(chip.chipId);
    if (entry == null || entry.kind != kind) return false;
    if (kind == EVanguardChipKind.General)
        return entry.equipmentSlot == (EquipmentType)slotIndex;       // 부위 일치
    // Exclusive: 해당 행 유닛이 targetUnits에 포함돼야 함
    var rowUnit = _deployProvider.GetSlotUnit(slotIndex);
    return rowUnit.HasValue && entry.targetUnits.Contains(rowUnit.Value);
}
```

> `VanguardManager`에서 stub 대신 `VanguardChipService`를 `new + Initialize` 후 패널/팝업에 주입한다(`VanguardSeasonService` 패턴). UI는 인터페이스만 보므로 패널 코드 수정 불필요.

---

## 4. 파이어베이스 저장 (②`VanguardSaveData` 확장)

서버연동 문서 §5.2의 `equippedChips`를 아래로 구체화/확장한다. **모두 클라 권위**.

```csharp
// VanguardSaveData 에 추가
public List<VanguardOwnedChip>   vanguardOwnedChips   = new();        // 보유 칩 인벤토리
public List<VanguardEquippedChip> vanguardEquippedChips = new();      // 장착 상태 (kind+slot → chipId)
public List<int> vanguardUnlockedExclusiveSlots = new();              // 재화 해금한 Exclusive 슬롯 idx
public int vanguardStandardChestCount = 0;                            // 표준상자 50연 천장 카운트
public int vanguardSpecialChestCount  = 0;                            // 특수상자 50연 천장 카운트

[Serializable] public class VanguardOwnedChip    { public string chipId; public int count; }
[Serializable] public class VanguardEquippedChip { public int kind; public int slotIndex; public string chipId; }
```

### 4.1 데이터 소유권

| 데이터 | 권위 | 저장 |
|---|---|---|
| 보유 칩 / 장착 / 슬롯해금 / 천장카운트 | 클라 | **②** |
| 칩 풀/드랍/효과 정의 | 데이터시트 | SO(앱 내장) |
| 장착 칩 목록(매칭 노출) | 클라 → 서버 | `loadout.chips`로 클론 동기화(§6) |
| 칩 효과 적용 결과(전투) | 클라 | 비저장(전투 중 계산) |

### 4.2 시즌 리셋 (`ResetSeasonProgress`)

새 시즌 첫 `enter` 시 Vanguard 칩 빌드는 초기화:

```csharp
s.vanguardOwnedChips.Clear();
s.vanguardEquippedChips.Clear();
s.vanguardUnlockedExclusiveSlots.Clear();
s.vanguardStandardChestCount = 0;
s.vanguardSpecialChestCount = 0;
// VanguardEmberMark(영구재화)는 CurrencyManager 소관이며 시즌 유지 — 여기서 건드리지 않음.
```

> 시즌 칩이 캐리오버되는지(예: 엠버 마크로 교환 보관)는 기획 확정. 기본은 전량 리셋.

---

## 5. 칩 효과 적용 (전투)

Vanguard 칩의 효과는 **기존 칩 효과 파이프라인을 재사용**한다(`agent_docs/chip_system.md`).

1. `VanguardChipFactory.ToChip(entry, count)`가 풀 엔트리의 `chipId`로 마스터 효과 데이터를 찾아 `Chip.effectType/effectValue/subEffectValue/chipEffectDataId`를 채운다.
2. 전투 진입(`VanguardStagePlayService`) 시, **Vanguard 장착 칩 집합**을 `ChipEffectManager`에 주입한다(본 게임 칩과 분리된 Vanguard 빌드로). 본 게임처럼 `Managers`의 전역 칩이 아니라, Vanguard 전투 컨텍스트에 한정해 적용해야 한다.
3. 데미지 모디파이어는 `DamageCalculationManager.ChipEffect.cs` 경로를 그대로 탄다(유닛별 `GetTotalEffectValue`).

```csharp
public static class VanguardChipFactory
{
    public static Chip ToChip(VanguardChipPoolTable.Entry e, int count)
    {
        var eff = ChipEffectDataProvider.Get(e.chipId); // 기존 마스터 효과 데이터 (chipId 매핑)
        return new Chip {
            chipId = e.chipId,
            rarity = e.rarity,
            slotType = e.kind == EVanguardChipKind.General ? e.equipmentSlot : default,
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

> ⚠️ Exclusive 칩의 `slotType`(EquipmentType)은 의미 없으므로 `default`로 두고 사용하지 않는다. Exclusive 식별은 `kind` + `targetUnits`로만 한다.
> ⚠️ Vanguard 효과 적용이 본 게임 칩 효과와 섞이지 않도록, Vanguard 전투는 **별도 효과 컨텍스트**를 쓰거나 진입/이탈 시 set/clear한다. (본 게임 `ChipManager` 전역 상태 오염 금지 — CLAUDE.md 매니저 규칙)

---

## 6. 매칭 클론 동기화 + CPS

장착된 Vanguard 칩은 `loadout.chips`로 서버에 전달돼 매칭/클론 표시에 쓰인다(서버연동 문서 §3.1/3.3).

- `loadout.chips` 직렬화: 서버는 **등급만** 본다. 예) `{ "slot1": { "grade": "legend" }, ... }`. 클라가 장착 칩의 `rarity` → grade 문자열로 변환해 채운다.
- **CPS(서버 내부 매칭 점수)** = 장착 칩 등급 점수 합 (서버연동 명세 2.4):

| 등급 | CPS |
|---|---|
| 희귀(Rare) | 1 |
| 서사(Epic) | 3 |
| 전설(Legendary) | 8 |
| 신화(Mythic) | 10 |
| 초월(Transcend) | 20 |

- 클라는 CPS를 직접 보낼 필요 없음(서버가 grade로 계산). 단 `atk`는 별도 메타로 전달.
- grade 문자열 키 합의 필요(예: `rare/epic/legend/mythic/transcend`). 서버 `chips` 파싱 키와 1:1 맞출 것.

---

## 7. UI 바인딩 (기존 컴포넌트와 연결)

| 컴포넌트 | 역할 | 연결 |
|---|---|---|
| `VanguardGeneralChipPanel` | 공용칩 6슬롯(부위별) | `Initialize(provider, onSlotClicked)` → `Refresh()`가 `GetEquippedChip(General, i)` 표시. 슬롯 클릭 → 부위별 Bag 필터 후 상세/장착 |
| `VanguardExclusiveChipPanel` | 유닛 그리드 전용칩 | `Initialize(provider, deployProvider, onUnlock)`. col0=유닛/배치, col≥1=`IsSlotUnlocked`/`GetSlotUnlockCost`로 해금 표시, 클릭 시 `UnlockSlotAsync` 라우팅 |
| `VanguardExclusiveChipRow` | 한 유닛 행의 슬롯 배열 | 패널이 `_rows[]`로 구동 |
| `VanguardChipSlot` | 슬롯 1칸 상태 표시 | `SetState(EChipSlotState, Chip)`, `SetUnit/SetUnitType`, `OnEquippedSlotClicked` |
| `VanguardChipDetailPopup` | 칩 상세/장착 | 선택 칩 + 대상 슬롯 + `EquipChipAsync` 호출 |

핵심 규칙:
- General 슬롯 i 클릭 → Bag에서 `kind=General && slotType==(EquipmentType)i` 필터해 후보 노출.
- Exclusive 행 유닛 클릭 → Bag에서 `kind=Exclusive && targetUnits.Contains(unit)` 필터.
- 모든 변경 후 `provider.OnChanged` → 컨테이너(`VanguardUnitSetupPopup`)가 두 패널 `Refresh()` 호출.

---

## 8. 구현 체크리스트

**데이터**
- [ ] DataSheet SO 3종 생성 (`VanguardUnitChipPoolDataSO`/`VanguardEquipmentChipPoolDataSO`/`VanguardChipDropDataSO`) — 시트 자동생성 규격
- [ ] 시트 정리: 소문자 `weapon`/`mythic` 오타, chipId 공란 행(Unit Turret/Transcend) → 파서 방어 + 시트 수정 요청
- [ ] `VanguardChipPoolTable.Build` (rarity/unit/slot 인덱스), `VanguardChipDropTable.Build`
- [ ] `chipId → ChipEffectDataSO` 매핑 연결(`ChipEffectDataProvider`)

**드랍/가챠**
- [ ] §2.3 후보 풀 정책 확정(통합/상자별/별도 룰렛) — 기본 통합
- [ ] 상자 개봉 플로우: 열쇠 차감(StandardKey/SpecialKey) → `Roll` → 인벤토리 적립(②) → 50연 천장 카운트
- [ ] 천장 선택형 보상 UI/풀

**서비스/저장**
- [ ] `VanguardChipService : IVanguardChipProvider` 구현, `VanguardManager`에서 stub 교체 주입
- [ ] `VanguardSaveData` 칩 필드 5종 + 보조 타입 2종 추가
- [ ] 슬롯 해금 `VanguardStandardDS` 차감(클라 권위), 장착 제약 검증(`IsEquippable`)
- [ ] 시즌 리셋 시 칩 빌드 초기화(EmberMark 제외)

**효과/매칭**
- [ ] `VanguardChipFactory.ToChip` 효과 주입, Vanguard 전투 한정 효과 컨텍스트(전역 오염 금지)
- [ ] `loadout.chips` 직렬화(rarity→grade) + grade 키 서버 합의, CPS 표(§6) 확인

**UI**
- [ ] General 6슬롯 = EquipmentType 매핑, Exclusive 유닛 필터, 상세/장착/해금 라우팅
- [ ] `OnChanged` → 두 패널 `Refresh` 연결

**검증**
- [ ] 표준/특수 상자 1000회 시뮬 → 등급 분포가 드랍표(490/300/150/50/10, 0/0/550/300/150)와 일치
- [ ] Transcend 후보 poolWeight(47/23/9/4) 비율 검증
- [ ] General 슬롯에 부위 불일치 칩 장착 차단 / Exclusive 비대상 유닛 칩 차단
- [ ] 장착 변경 → enter/loadout/save로 클론 chips 동기화 → 상대에게 등급 노출 확인
- [ ] 시즌 전환 → 칩 빌드 리셋, 엠버 마크 유지

---

## 부록 A: 풀 통계 (참고, 시트 기준)

- 등급 체계: Rare(52xxx) / Epic(53xxx) / Legendary(54xxx) / Mythic(55xxx) / Transcend(56xxx).
- Unit 풀 대상 유닛: Turret, Archon, DrFrost, Carrier, AirMan, Ninja, Vessel, Marauder, Templer, Dragoon, Thor (마린 제외 — Unit 전용칩에 Marine 없음).
- Equipment 풀 부위: Shield, Helmet, Armor, Weapon, EnergyCore, Boots (6). targetUnits 그룹 패턴: `Marine,Vessel,Ninja` / `Archon,Dragoon,Carrier` / `Turret,Marauder` / `Templer,Thor` / `DrFrost,AirMan` / `Marine` / 공란(전체).
- Transcend(56xxx)만 poolWeight 차등(47=표준, 23/9/4=희소). 그 외 등급은 전부 1(균등).

## 부록 B: 타입 매핑 요약

| 시트 컬럼 | Unit 풀 | Equipment 풀 |
|---|---|---|
| chipId | int → string화 | string |
| 칩 장착 부위 | `EUnitType`(소유 유닛) | `EquipmentType`(6부위) |
| 효과 대상 유닛 | `[소유유닛]` | `List<EUnitType>`(공란=전체/그룹) |
| 칩 등급 | `EChipRarityType` | `EChipRarityType` |
| 선택 가중치 | `poolWeight` | `poolWeight` |
| 패널 | `VanguardExclusiveChipPanel` | `VanguardGeneralChipPanel` |
| `EVanguardChipKind` | `Exclusive` | `General` |

---

_작성 기준: 제공 시트(VanguardUnitChipPoolData / VanguardEquipmentChipPoolData / VanguardChipDropData) + 클라 칩 골격 스냅샷. 효과 수치는 기존 마스터 칩 효과 데이터(chipId 매핑) 재사용._
