# Vanguard 전용 칩 시스템 — 통합 구현 명세 v2 (뽑기 · 인벤토리 · 장착 · 효과 · 테스트)

> 대상: 클라이언트 개발자
> 목표: **이 문서 하나만 보고 Vanguard 칩의 전 기능(컴파일 복구 → 데이터 → 뽑기 → 인벤토리 → 장착 → 효과 → 매칭 동기화 → 테스트)을 구현**한다.
> v2 작성 기준: 2026-06-10 코드베이스 실사. 문서 내 모든 타입/시그니처는 실제 코드와 대조 검증됨.

---

## 0. v1 → v2 변경 요약

| 항목 | v1 | v2 (확정) |
|---|---|---|
| 컴파일 | 에러 발생(원인 미기재) | **§1에서 원인/수정 절차 명시** |
| Unit 풀 "칩 장착 부위" 타입 | `EUnitType ownerUnit` (SO에 없는 필드 참조) | 시트 타입 `EUnitType`, 필드명은 **`slotType` 유지** |
| General 슬롯 모델 | 부위당 1칩 (총 6칩) | **부위당 6칩 슬롯** (본게임 ChipManager 미러, 프리팹 일치) |
| Exclusive 슬롯 모델 | 유닛 그리드 col1/col2 = 유닛당 2칩 | **유닛당 4칩 슬롯** (VanguardUnitDetailPopup 프리팹 일치). 유닛 그리드 col1/col2 해금은 "배치 칸 해금"으로 의미 분리 |
| 슬롯 해금 | General 전부 기본 해금 | **General/Exclusive 모두 첫 슬롯만 기본, 이후 DS 순차 해금** |
| 장착 저장 인덱스 | kind + slotIndex(평면) | kind + **인코딩 인덱스(ownerKey×10+chipSlot)** §4.2 |
| 테스트 데이터 | 없음 | **JSON 3종 생성·설치 완료**(§2.3). SO 변환 절차 포함 |
| DEV 테스트 | 없음 | 전체 칩 자동 지급 + 치트 모듈 + 상점 임시 뽑기 버튼 (§10) |

**기존 칩 시스템 재활용 전략(확정)** — "그대로 재활용" 방침이 맞다. 이미 재활용 중/재활용할 것:

| 재활용 대상 | 위치 | 용도 |
|---|---|---|
| `Chip` 클래스 | `SOs/Class/Chip/Chip.cs` | 인벤토리/장착/표시 모델 그대로 사용 (`chipId`는 string — Vanguard 풀 ID 그대로 담음) |
| 마스터 칩 효과 데이터 | `ChipManager.GetChipEffectData(int chipID)` | 효과 수치. **Vanguard 풀의 모든 chipId(734종)가 마스터 효과 에셋에 1:1 존재함을 검증 완료** |
| `ChipEffectManager` + `DamageCalculationManager.ChipEffect.cs` | 전투 효과 파이프라인 | §8의 컨텍스트 오버라이드만 추가, 데미지 경로 무변경 |
| `ChipSlotDisplay`, `ChipInventoryItem`, `ChipInfoDisplay`, `ChipFilterPopupUI`, `FilterService` | `UI/Components`, `UI/Popups` | Vanguard 칩 UI 전부 이 컴포넌트로 구성(이미 프리팹에 배치됨) |
| `EChipRarityType`, `EChipSlotState`, `EquipmentType`, `EUnitType` | `Core/Enums`, `Core/Data/Enums` | 그대로 사용. **새 enum 만들지 않는다** |
| 가챠 골격 | `VanguardChipGachaService`(이미 구현됨) | 2단계 가중 룰렛 + 천장 — 수정 불필요(§6) |
| 분리 유지 | 저장소(`VanguardSaveData` ② vs `ESaveDataType.Chips`), 인벤토리 모델(풀ID+count 스택 vs 인스턴스), 시즌 리셋 | 본게임 칩과 절대 섞지 않는다 |

---

## 1. ★ 긴급: 컴파일 에러 원인과 복구 절차

### 1.1 원인 (확정)

1. **`EChipSlotType` enum이 프로젝트에 존재하지 않는다.** 구글 시트의 타입 행이 `EChipSlotType`으로 차팅된 상태에서 클래스가 자동 생성되어, 아래 4개 파일이 존재하지 않는 타입을 참조 중 → CS0246.
   - `SOs/SO/DataSheet/VanguardUnitChipPoolDataSO.cs`
   - `SOs/SO/DataSheet/VanguardEquipmentChipPoolDataSO.cs`
   - `SOs/Class/DataSheet/VanguardUnitChipPoolDataData.cs`
   - `SOs/Class/DataSheet/VanguardEquipmentChipPoolDataData.cs`
2. **`VanguardChipPoolTable.Build()`가 SO에 없는 필드를 참조한다.**
   - `u.ownerUnit` — `VanguardUnitChipPoolDataSO`에 `ownerUnit` 필드가 없음(실제 필드명 `slotType`) → CS1061.
   - `equipmentSlot = e.slotType` — `EChipSlotType` → `EquipmentType` 암시적 변환 불가 → CS0029.
3. **`VanguardChipDropTable.RollRarity()`가 SO에 없는 `GetWeight(EChipRarityType)`를 호출한다** (자동생성 `VanguardChipDropDataSO`에는 메서드를 넣을 수 없음) → CS1061. §3.2의 확장 메서드로 해결.

### 1.2 복구 절차

시트는 이미 수정되어 있다(Unit 풀 `slotType: EUnitType`, Equipment 풀 `slotType: EquipmentType`).

1. **클래스 재생성**: `Tools > GoogleSheetManager`(전체 시트 동기화)로 `VanguardUnitChipPoolData`/`VanguardEquipmentChipPoolData` 클래스 4종을 재생성한다. 시트 동기화를 당장 돌릴 수 없으면 아래 "재생성 결과와 동일한 내용"으로 수기 수정해도 된다(시트 타입이 이미 맞으므로 다음 동기화 때 덮어써도 동일).

```csharp
// SOs/SO/DataSheet/VanguardUnitChipPoolDataSO.cs  (Data 클래스도 동일 필드)
[CreateAssetMenu(fileName = "VanguardUnitChipPoolData", menuName = "GameData/CreateVanguardUnitChipPoolDataData")]
public class VanguardUnitChipPoolDataSO : ScriptableObject
{
    public int chipId;
    public string chipName;
    public EUnitType slotType;            // 칩 장착 부위 = 소유 유닛  ← EChipSlotType에서 변경
    public List<EUnitType> targetUnits;   // 효과 대상 유닛 (= slotType과 동일 1종)
    public EChipRarityType rarityType;
    public int poolWeight;
}

// SOs/SO/DataSheet/VanguardEquipmentChipPoolDataSO.cs  (Data 클래스도 동일 필드)
[CreateAssetMenu(fileName = "VanguardEquipmentChipPoolData", menuName = "GameData/CreateVanguardEquipmentChipPoolDataData")]
public class VanguardEquipmentChipPoolDataSO : ScriptableObject
{
    public string chipId;                 // ★ Equipment 풀만 string
    public string chipName;
    public EquipmentType slotType;        // 장착 슬롯 타입(6부위)  ← EChipSlotType에서 변경
    public List<EUnitType> targetUnits;   // 공란=전체 유닛
    public EChipRarityType rarityType;
    public int poolWeight;
}
```

2. **`VanguardChipPoolTable.Build()` 수정** — §3.1 전체 코드로 교체 (`u.slotType`/`e.slotType` 사용).
3. `VanguardChipDropDataSO`는 수정 불필요. 단 §3.2의 `GetWeight()` 확장 메서드를 추가한다(현재 `VanguardChipDropTable.RollRarity`가 호출하는데 SO에 없음 — 자동생성 SO는 수정 금지이므로 **확장 메서드**로 분리, CLAUDE.md `{ClassName}Parser` 규칙 준수).

> ⚠️ `SOs/SO/DataSheet/`·`SOs/Class/DataSheet/`는 자동 생성 영역. 위 1번 수기 수정은 "재생성 결과 선반영"일 뿐이며, 커스텀 로직은 절대 넣지 않는다.

---

## 2. 데이터 레이어

### 2.1 시트 3종 (확정 스키마)

| 시트 | chipId | slotType | targetUnits | rarityType | poolWeight |
|---|---|---|---|---|---|
| `VanguardUnitChipPoolData` | int | `EUnitType` (소유 유닛) | `List<EUnitType>` (=slotType 1종) | `EChipRarityType` | int |
| `VanguardEquipmentChipPoolData` | string | `EquipmentType` (6부위) | `List<EUnitType>` (공란=전체) | `EChipRarityType` | int |
| `VanguardChipDropData` | id: string | 7등급 가중치 int×7 | | | |

드랍표 값:

| id | Rare | Epic | Legendary | Mythic | Transcend | 합 |
|---|---|---|---|---|---|---|
| vanguard_standard_chest | 490 | 300 | 150 | 50 | 10 | 1000 |
| vanguard_special_chest | 0 | 0 | 550 | 300 | 150 | 1000 |

**시트 정리 필요 사항(차팅 담당 전달):**
- Unit 풀에 **chipId 공란 행 1개**(Turret/Transcend/가중치4) 존재 → 행 제거 또는 ID 채움. 런타임은 스킵+경고 처리되지만 데이터 누락이다.
- 소문자 표기 `weapon`(54330, 56326), `mythic`(55131, 55325) → 파서가 대소문자 무시라 동작엔 문제 없으나 정정 권장.
- 뽑기용 추가 시트는 **불필요** — 위 3종이면 뽑기까지 전부 돌아간다(통합 풀 2단계 룰렛, §6).

### 2.2 데이터 파이프라인 (기존 구조 그대로)

```
구글 시트 ─(GoogleSheetManager 동기화)→ Assets/Resources/JsonFiles/{시트명}.json
        └→ SOs/Class·SO/DataSheet/{시트명}Data(.cs)/{시트명}SO(.cs) 클래스 생성
JSON ─(Tools > JsonToSO 메뉴, DynamicMenuCreator)→ Assets/Resources/ScriptableObjects/{시트명}/{chipId}.asset (행별 SO)
.asset ─(VanguardManager.BuildChipTables, 부팅 1회)→ VanguardChipPoolTable / VanguardChipDropTable
```

- JSON 포맷: `{ "datas": [ {행}, ... ] }`. enum은 문자열/숫자 모두 파싱됨(대소문자 무시), `List<EUnitType>`은 문자열 배열.
- `.asset` 파일명 = 첫 컬럼(chipId) 값.
- 로드: `ResourceManager.LoadAllResourcesInFolder<T>("ScriptableObjects/{시트명}")` — `VanguardManager.BuildChipTables()`에 이미 구현돼 있음(수정 불필요).

### 2.3 테스트 데이터 (★ JSON 설치 완료 — SO 변환만 하면 됨)

**판정: 이 시스템의 테스트 데이터는 "JSON + 변환된 SO .asset" 둘 다 필요하다.** 런타임 코드(`BuildChipTables`)는 **SO .asset 폴더**를 읽고, 그 .asset은 에디터 툴이 **JSON**에서 생성하기 때문. 따라서 정본인 JSON을 만들어 두었고, .asset은 에디터에서 1회 변환한다.

설치된 파일 (시트 전체 데이터 기반, 검증 완료):

| 파일 | 내용 |
|---|---|
| `Assets/Resources/JsonFiles/VanguardUnitChipPoolData.json` | 211행 (Rare22/Epic32/Legendary52/Mythic50/Transcend55) — chipId 공란 행 1개는 제외 |
| `Assets/Resources/JsonFiles/VanguardEquipmentChipPoolData.json` | 523행 (Rare88/Epic97/Legendary108/Mythic116/Transcend114), 소문자 표기 정규화 완료 |
| `Assets/Resources/JsonFiles/VanguardChipDropData.json` | 상자 2행 |

검증된 사실: 중복 ID 없음 · 등급↔ID대역(5{등급}xxx) 전건 일치 · Transcend 가중치 분포 unit 47×40/23×10/9×1/4×4, equip 47×101/23×8/4×5 · **풀의 모든 chipId가 기존 마스터 효과 에셋(`Assets/Resources/ScriptableObjects/ChipEffects*Data/{chipId}.asset`, 총 1,290개)에 존재** → 효과 재사용(§5) 성립.

**SO 변환 절차(에디터, §1 컴파일 복구 후):**
1. `Tools > JsonToSO > CreateVanguardUnitChipPoolDataSO`
2. `Tools > JsonToSO > CreateVanguardEquipmentChipPoolDataSO`
3. `Tools > JsonToSO > CreateVanguardChipDropDataSO`
   (또는 `Tools > Data > 모든 JSON → SO 변환` 일괄 실행)
4. 결과 확인: `Assets/Resources/ScriptableObjects/VanguardUnitChipPoolData/` 211개, `.../VanguardEquipmentChipPoolData/` 523개, `.../VanguardChipDropData/` 2개.
5. 플레이 진입 시 로그에 "칩 풀 테이블 비어 있음" 경고가 **없으면** 로드 성공.

---

## 3. 런타임 테이블

### 3.1 `VanguardChipPoolTable` — Build()만 아래로 교체

파일: `Core/Managers/Vanguard/Chip/VanguardChipPoolTable.cs`. Entry 구조/인덱스/조회 API는 현행 유지, `Build`의 필드 참조만 수정한다.

```csharp
public static void Build(IReadOnlyList<VanguardUnitChipPoolDataSO> unit,
                         IReadOnlyList<VanguardEquipmentChipPoolDataSO> equip)
{
    _all.Clear(); _byRarity.Clear(); _exclusiveByUnit.Clear(); _generalBySlot.Clear(); _byId.Clear();

    if (unit != null)
    {
        foreach (var u in unit)
        {
            if (u == null) continue;
            if (u.chipId == 0) { RLog.LogWarning($"[VanguardChipPoolTable] Unit 칩 chipId 공란 → 스킵 (name={u.chipName})"); continue; }
            Add(new Entry
            {
                chipId = u.chipId.ToString(),
                kind = EVanguardChipKind.Exclusive,
                rarity = u.rarityType,
                poolWeight = Mathf.Max(1, u.poolWeight),
                targetUnits = u.targetUnits ?? new List<EUnitType>(),
                ownerUnit = u.slotType,                       // ★ "칩 장착 부위" = 소유 유닛 (EUnitType)
            });
        }
    }

    if (equip != null)
    {
        foreach (var e in equip)
        {
            if (e == null || string.IsNullOrEmpty(e.chipId))
            { if (e != null) RLog.LogWarning($"[VanguardChipPoolTable] Equipment 칩 chipId 공란 → 스킵 (name={e.chipName})"); continue; }
            Add(new Entry
            {
                chipId = e.chipId,
                kind = EVanguardChipKind.General,
                rarity = e.rarityType,
                poolWeight = Mathf.Max(1, e.poolWeight),
                targetUnits = e.targetUnits ?? new List<EUnitType>(),
                equipmentSlot = e.slotType,                   // ★ EquipmentType 그대로 (변환 불필요)
            });
        }
    }
}
```

### 3.2 `VanguardChipDropDataSO.GetWeight` — 확장 메서드로 신규 추가

`VanguardChipDropTable.RollRarity`가 호출 중이나 자동생성 SO에는 없다. **신규 파일** `Core/Managers/Vanguard/Chip/VanguardChipDropDataSOExtensions.cs`:

```csharp
/// 자동생성 SO(VanguardChipDropDataSO) 수정 금지 — 등급별 가중치 조회를 확장 메서드로 분리.
public static class VanguardChipDropDataSOExtensions
{
    public static int GetWeight(this VanguardChipDropDataSO c, EChipRarityType r) => r switch
    {
        EChipRarityType.Common => c.commonWeight,
        EChipRarityType.Uncommon => c.uncommonWeight,
        EChipRarityType.Rare => c.rareWeight,
        EChipRarityType.Epic => c.epicWeight,
        EChipRarityType.Legendary => c.legendaryWeight,
        EChipRarityType.Mythic => c.mysticWeight,
        EChipRarityType.Transcend => c.transcendWeight,
        _ => 0,
    };
}
```

`VanguardChipDropTable`(2단계 가중 룰렛)은 현행 코드 그대로 유지 — 검증 완료.

---

## 4. 슬롯 모델 (확정 정본)

### 4.1 구조

```
[General — 장비 칩]   부위(EquipmentType 6) × 부위당 칩 슬롯 6  = 최대 36칩
   진입: VanguardUnitSetupPopup General 탭 → 부위 슬롯 클릭 → VanguardChipDetailPopup(부위)
   해금: 각 부위의 슬롯0 기본 해금, 슬롯1~5 VanguardStandardDS 순차 해금
   제약: entry.equipmentSlot == 해당 부위

[Exclusive — 유닛 칩] 유닛(EUnitType) × 유닛당 칩 슬롯 4
   진입: VanguardUnitSetupPopup Exclusive 탭(배치 그리드) → 유닛 칸 클릭 → VanguardUnitDetailPopup(유닛)
   해금: 슬롯0 기본 해금, 슬롯1~3 VanguardStandardDS 순차 해금
   제약: entry.ownerUnit == 해당 유닛 (targetUnits 포함 판정으로 동일)

[배치 그리드 — 칩 아님] VanguardExclusiveChipPanel의 row×3 그리드는 "유닛 배치 칸".
   col0 기본, col1/col2는 DS 해금(기존 ExclusiveCol1/2Cost). 기존 코드/저장(vanguardUnlockedExclusiveSlots) 그대로 유지.
```

### 4.2 저장 인덱스 인코딩

`VanguardEquippedChip.slotIndex` 및 칩 슬롯 해금 리스트 값은 다음과 같이 인코딩한다.

```
slotIndex = ownerKey * 10 + chipSlot
  General  : ownerKey = (int)EquipmentType (0..5),  chipSlot 0..5   → 예: Weapon(3) 슬롯2 = 32
  Exclusive: ownerKey = (int)EUnitType    (0..12),  chipSlot 0..3   → 예: Turret(1) 슬롯0 = 10
  ※ EUnitType.None(9999) 금지. kind가 분리 저장되므로 kind 간 충돌 없음.
```

### 4.3 상수 — `VanguardChipConst` 전체 교체

```csharp
/// 뱅가드 칩 시스템 상수. 매직넘버 분리(CLAUDE.md). 비용은 기획 확정 전 임시값.
public static class VanguardChipConst
{
    public const int GeneralSlotCount = 6;             // EquipmentType 6부위 (General 탭 부위 슬롯 수)
    public const int GeneralChipSlotsPerType = 6;      // 부위당 칩 슬롯 수
    public const int ExclusiveChipSlotsPerUnit = 4;    // 유닛당 칩 슬롯 수
    public const int SlotEncodeStride = 10;            // slotIndex = ownerKey * 10 + chipSlot

    public const int ExclusiveColumns = 3;             // 배치 그리드 열 수 (col0=기본 해금)
    public const int ExclusiveCol1Cost = 80;           // 배치 칸 해금 비용 (VanguardStandardDS)
    public const int ExclusiveCol2Cost = 150;

    public const int PityThreshold = 50;               // 50연 천장

    // 칩 슬롯 순차 해금 비용 (index = chipSlot, 0은 기본 해금). VanguardStandardDS.
    public static readonly int[] GeneralChipSlotCosts   = { 0, 40, 80, 120, 160, 200 };
    public static readonly int[] ExclusiveChipSlotCosts = { 0, 80, 150, 250 };

    public static int Encode(int ownerKey, int chipSlot) => ownerKey * SlotEncodeStride + chipSlot;
}
```

---

## 5. 저장 (② `VanguardSaveData`)

파일: `Core/Managers/SaveDataTypes.cs`. 기존 칩 필드 5종은 유지하고 **2필드 추가**.

```csharp
// ── 칩 시스템 (클라 권위, 시즌 리셋 대상) ──
public List<VanguardOwnedChip>    vanguardOwnedChips = new();          // (기존) 뽑기 적립 인벤토리: 풀 chipId + count 스택
public List<VanguardEquippedChip> vanguardEquippedChips = new();       // (기존) 장착: kind + 인코딩 slotIndex(§4.2) → chipId
public List<int> vanguardUnlockedExclusiveSlots = new();               // (기존) ★배치 그리드 칸★ 해금 (의미 유지)
public int vanguardStandardChestCount = 0;                             // (기존) 표준상자 천장
public int vanguardSpecialChestCount  = 0;                             // (기존) 특수상자 천장
public List<int> vanguardUnlockedGeneralChipSlots = new();             // (추가) General 칩 슬롯 해금 (인코딩 값, slot0 미저장)
public List<int> vanguardUnlockedExclusiveChipSlots = new();           // (추가) Exclusive 칩 슬롯 해금 (인코딩 값, slot0 미저장)
```

보조 타입(기존 그대로): `VanguardOwnedChip { string chipId; int count; }`, `VanguardEquippedChip { int kind; int slotIndex; string chipId; }`

`VanguardSeasonService.ResetSeasonProgress`의 칩 리셋 블록에 추가:

```csharp
s.vanguardUnlockedGeneralChipSlots.Clear();
s.vanguardUnlockedExclusiveChipSlots.Clear();
// (기존 5종 Clear/0 유지. VanguardEmberMark 영구재화는 CurrencyManager 소관 — 건드리지 않음)
```

권위/저장 요약: 보유·장착·해금·천장 = 클라 권위 ②(`ESaveDataType.Vanguard`) / 풀·드랍·효과 정의 = SO / 장착 칩의 매칭 노출 = `loadout.chips`(§9) / 전투 효과 결과 = 비저장.

---

## 6. 칩 뽑기 — 기존 구현 유지 (검증 완료)

`Core/Managers/Vanguard/Chip/VanguardChipGachaService.cs`는 **수정 없이 그대로 사용한다.** 검증된 동작:

- `OpenChestAsync(EVanguardChestType)` / `OpenChestMultiAsync(type, count)`: 열쇠(`VanguardStandardKey 1288` / `VanguardSpecialKey 1289`) 1개/N개 차감 → `VanguardChipDropTable.Roll`(등급 룰렛 → 통합 풀 poolWeight 룰렛) → `vanguardOwnedChips` count 적립(kind 자동 — chipId가 어느 풀이든 단일 리스트) → 상자별 천장 카운트++ → ② 저장.
- 천장: `IsPityReady` / `ClaimPityAsync(type, chosenChipId)` / `GetPityCount` — 상자별 50회, 선택 칩 지급 후 카운트 -50.
- `CurrencyManager.CanAfford(type, n, true)`가 부족 시 재화 획득 안내 표시까지 처리.

결과 표시: 뽑힌 `Entry`는 `VanguardChipFactory.ToChip(entry, 1)`로 변환해 노출. 신규 획득 여부는 `owned.count == 1`로 판정해 `Chip.IsNew = true` 세팅(NEW 뱃지). 전용 연출 팝업은 후속 작업(테스트 단계는 §10의 토스트/치트 로그로 충분).

`VanguardChipFactory`(기존 파일)도 수정 불필요 — `ChipManager.GetChipEffectData(int)`로 마스터 효과(`ChipEffectData { chipID, slotType, targetUnits, effectType, effectValue, subEffectValue, weight, description }`)를 주입해 `Chip`을 만든다. `Chip.chipId`(string)에 풀 chipId가 그대로 들어간다.

> 정식 진입점은 뱅가드 상점 상자 구매 → 열쇠 → 개봉 플로우지만, 상점 구매가 미구현이므로 테스트 진입점은 §10.

---

## 7. 인벤토리 + 장착 서비스

### 7.1 `IVanguardChipProvider` v2 — 전체 교체

파일: `Core/Managers/Vanguard/Chip/IVanguardChipProvider.cs`. 칩 슬롯 연산을 `(kind, ownerKey, chipSlot)`로 명시 분리한다(배치 그리드 연산과 의미 충돌 제거). **기존 평면 `GetEquippedChip/EquipChipAsync/UnequipChipAsync(kind, slotIndex)`는 삭제** — 호출처는 전부 §8에서 함께 수정한다.

```csharp
using System;
using System.Collections.Generic;
using Cysharp.Threading.Tasks;

/// Vanguard 전용 칩 데이터 소스. 본게임 ChipManager와 분리(시즌 리셋 대상).
/// ownerKey: General=(int)EquipmentType, Exclusive=(int)EUnitType. chipSlot: General 0..5, Exclusive 0..3.
public interface IVanguardChipProvider
{
    // ── Bag (kind별 보유 칩, count 스택) ──
    IReadOnlyList<Chip> GetBag(EVanguardChipKind kind);

    // ── 칩 슬롯 (부위/유닛별) ──
    Chip GetEquippedChip(EVanguardChipKind kind, int ownerKey, int chipSlot);
    bool IsChipSlotUnlocked(EVanguardChipKind kind, int ownerKey, int chipSlot);
    /// 0=이미 해금, -1=선행 슬롯 미해금(잠김), >0=해금 비용(VanguardStandardDS)
    int GetChipSlotUnlockCost(EVanguardChipKind kind, int ownerKey, int chipSlot);
    UniTask<bool> UnlockChipSlotAsync(EVanguardChipKind kind, int ownerKey, int chipSlot);
    UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int ownerKey, int chipSlot, Chip chip);
    UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int ownerKey, int chipSlot);

    // ── 배치 그리드 (Exclusive 탭의 유닛 칸 — 칩 슬롯 아님, 기존 의미 유지) ──
    bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex);       // General은 항상 true
    int GetSlotUnlockCost(EVanguardChipKind kind, int slotIndex);
    UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex);

    int GeneralSlotCount { get; }      // 6 (부위 수)
    int ExclusiveSlotCount { get; }    // 배치 그리드 칸 수

    // ── 전투/매칭용 ──
    List<Chip> GetAllEquippedChips();  // 장착 칩 전체 (효과 컨텍스트·loadout 직렬화 입력)

    event Action OnChanged;
}
```

`VanguardChipProviderStub`도 동일 시그니처로 갱신한다(메모리 딕셔너리, 즉시 반환 + OnChanged — 기존 패턴 유지).

### 7.2 `VanguardChipService` v2 — 전체 교체

파일: `Core/Managers/Vanguard/Chip/VanguardChipService.cs`

```csharp
using System;
using System.Collections.Generic;
using Cysharp.Threading.Tasks;

/// 뱅가드 칩 인벤토리/장착/해금 (클라 권위, ②VanguardSaveData). VanguardChipProviderStub 대체 실구현.
/// 슬롯 모델 §4: General 부위당 6슬롯 / Exclusive 유닛당 4슬롯, 첫 슬롯만 기본 해금 + DS 순차 해금.
/// 저장 인덱스 = ownerKey*10+chipSlot (VanguardChipConst.Encode).
public class VanguardChipService : IVanguardChipProvider
{
    private VanguardSaveData _save;
    private Func<UniTask> _saveAsync;
    private CurrencyManager _currency;
    private IVanguardDeployProvider _deploy;

    public event Action OnChanged;
    public int GeneralSlotCount => VanguardChipConst.GeneralSlotCount;
    public int ExclusiveSlotCount { get; private set; }

    public void Initialize(VanguardSaveData save, Func<UniTask> saveAsync,
                           CurrencyManager currency, IVanguardDeployProvider deploy, int exclusiveSlotCount)
    {
        _save = save; _saveAsync = saveAsync; _currency = currency; _deploy = deploy;
        ExclusiveSlotCount = exclusiveSlotCount;
    }

    // ── Bag ──────────────────────────────
    public IReadOnlyList<Chip> GetBag(EVanguardChipKind kind)
    {
        var list = new List<Chip>();
        if (_save?.vanguardOwnedChips == null) return list;
        foreach (var owned in _save.vanguardOwnedChips)
        {
            if (owned == null) continue;
            var entry = VanguardChipPoolTable.Get(owned.chipId);
            if (entry == null || entry.kind != kind) continue;   // kind 필터로 General/Exclusive 분리
            list.Add(VanguardChipFactory.ToChip(entry, owned.count));
        }
        return list;
    }

    // ── 칩 슬롯 ──────────────────────────
    private List<int> UnlockedList(EVanguardChipKind kind) => kind == EVanguardChipKind.General
        ? (_save.vanguardUnlockedGeneralChipSlots ??= new List<int>())
        : (_save.vanguardUnlockedExclusiveChipSlots ??= new List<int>());

    private static int[] Costs(EVanguardChipKind kind) => kind == EVanguardChipKind.General
        ? VanguardChipConst.GeneralChipSlotCosts
        : VanguardChipConst.ExclusiveChipSlotCosts;

    private static int MaxChipSlots(EVanguardChipKind kind) => kind == EVanguardChipKind.General
        ? VanguardChipConst.GeneralChipSlotsPerType
        : VanguardChipConst.ExclusiveChipSlotsPerUnit;

    public Chip GetEquippedChip(EVanguardChipKind kind, int ownerKey, int chipSlot)
    {
        if (_save?.vanguardEquippedChips == null) return null;
        int idx = VanguardChipConst.Encode(ownerKey, chipSlot);
        var key = _save.vanguardEquippedChips.Find(x => x.kind == (int)kind && x.slotIndex == idx);
        if (key == null) return null;
        var entry = VanguardChipPoolTable.Get(key.chipId);
        return entry == null ? null : VanguardChipFactory.ToChip(entry, 1);
    }

    public bool IsChipSlotUnlocked(EVanguardChipKind kind, int ownerKey, int chipSlot)
    {
        if (chipSlot <= 0) return true;                                   // 첫 슬롯 기본 해금
        if (chipSlot >= MaxChipSlots(kind)) return false;
        return _save != null && UnlockedList(kind).Contains(VanguardChipConst.Encode(ownerKey, chipSlot));
    }

    public int GetChipSlotUnlockCost(EVanguardChipKind kind, int ownerKey, int chipSlot)
    {
        if (chipSlot >= MaxChipSlots(kind)) return -1;
        if (IsChipSlotUnlocked(kind, ownerKey, chipSlot)) return 0;
        if (!IsChipSlotUnlocked(kind, ownerKey, chipSlot - 1)) return -1; // 선행 슬롯 미해금 → 순차 가드
        return Costs(kind)[chipSlot];
    }

    public async UniTask<bool> UnlockChipSlotAsync(EVanguardChipKind kind, int ownerKey, int chipSlot)
    {
        if (_save == null || _currency == null) return false;
        int cost = GetChipSlotUnlockCost(kind, ownerKey, chipSlot);
        if (cost <= 0) return false;
        if (!_currency.CanAfford(ECurrencyType.VanguardStandardDS, cost, true)) return false;
        if (!_currency.SpendCurrency(ECurrencyType.VanguardStandardDS, cost)) return false;

        int idx = VanguardChipConst.Encode(ownerKey, chipSlot);
        var list = UnlockedList(kind);
        if (!list.Contains(idx)) list.Add(idx);

        if (_saveAsync != null) await _saveAsync();
        OnChanged?.Invoke();
        return true;
    }

    public async UniTask<bool> EquipChipAsync(EVanguardChipKind kind, int ownerKey, int chipSlot, Chip chip)
    {
        if (chip == null || _save == null) return false;
        if (!IsChipSlotUnlocked(kind, ownerKey, chipSlot)) return false;
        if (!IsEquippable(kind, ownerKey, chip)) return false;

        _save.vanguardEquippedChips ??= new List<VanguardEquippedChip>();
        int idx = VanguardChipConst.Encode(ownerKey, chipSlot);
        // 동일 칩 중복 장착 금지(스왑): 같은 chipId가 어느 슬롯에 있든 제거 + 대상 슬롯 기존 칩 제거.
        _save.vanguardEquippedChips.RemoveAll(x => x.chipId == chip.chipId);
        _save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == idx);
        _save.vanguardEquippedChips.Add(new VanguardEquippedChip { kind = (int)kind, slotIndex = idx, chipId = chip.chipId });

        if (_saveAsync != null) await _saveAsync();
        OnChanged?.Invoke();
        return true;
    }

    public async UniTask<bool> UnequipChipAsync(EVanguardChipKind kind, int ownerKey, int chipSlot)
    {
        if (_save?.vanguardEquippedChips == null) return false;
        int idx = VanguardChipConst.Encode(ownerKey, chipSlot);
        if (_save.vanguardEquippedChips.RemoveAll(x => x.kind == (int)kind && x.slotIndex == idx) == 0) return false;
        if (_saveAsync != null) await _saveAsync();
        OnChanged?.Invoke();
        return true;
    }

    /// 장착 제약: General=부위 일치 / Exclusive=소유 유닛 일치(targetUnits 포함 판정).
    private static bool IsEquippable(EVanguardChipKind kind, int ownerKey, Chip chip)
    {
        var entry = VanguardChipPoolTable.Get(chip.chipId);
        if (entry == null || entry.kind != kind) return false;
        if (kind == EVanguardChipKind.General)
            return entry.equipmentSlot == (EquipmentType)ownerKey;
        var unit = (EUnitType)ownerKey;
        return entry.ownerUnit == unit
               || (entry.targetUnits != null && entry.targetUnits.Contains(unit));
    }

    // ── 배치 그리드 (기존 의미/저장 유지) ──
    public bool IsSlotUnlocked(EVanguardChipKind kind, int slotIndex)
    {
        if (kind == EVanguardChipKind.General) return true;
        if (slotIndex % VanguardChipConst.ExclusiveColumns == 0) return true;   // col0 항상 해금
        return _save?.vanguardUnlockedExclusiveSlots != null
               && _save.vanguardUnlockedExclusiveSlots.Contains(slotIndex);
    }

    public int GetSlotUnlockCost(EVanguardChipKind kind, int slotIndex)
    {
        if (kind == EVanguardChipKind.General || IsSlotUnlocked(kind, slotIndex)) return 0;
        int col = slotIndex % VanguardChipConst.ExclusiveColumns;
        return col == 1 ? VanguardChipConst.ExclusiveCol1Cost : VanguardChipConst.ExclusiveCol2Cost;
    }

    public async UniTask<bool> UnlockSlotAsync(EVanguardChipKind kind, int slotIndex)
    {
        if (kind != EVanguardChipKind.Exclusive || IsSlotUnlocked(kind, slotIndex)) return false;
        if (_save == null || _currency == null) return false;
        int cost = GetSlotUnlockCost(kind, slotIndex);
        if (!_currency.CanAfford(ECurrencyType.VanguardStandardDS, cost, true)) return false;
        if (!_currency.SpendCurrency(ECurrencyType.VanguardStandardDS, cost)) return false;
        _save.vanguardUnlockedExclusiveSlots ??= new List<int>();
        if (!_save.vanguardUnlockedExclusiveSlots.Contains(slotIndex)) _save.vanguardUnlockedExclusiveSlots.Add(slotIndex);
        if (_saveAsync != null) await _saveAsync();
        OnChanged?.Invoke();
        return true;
    }

    // ── 전투/매칭 ──
    public List<Chip> GetAllEquippedChips()
    {
        var list = new List<Chip>();
        if (_save?.vanguardEquippedChips == null) return list;
        foreach (var e in _save.vanguardEquippedChips)
        {
            if (e == null) continue;
            var entry = VanguardChipPoolTable.Get(e.chipId);
            if (entry != null) list.Add(VanguardChipFactory.ToChip(entry, 1));
        }
        return list;
    }
}
```

매니저 조립(`VanguardManager.InitializeAsync`)은 현행 그대로(`BuildChipTables()` → `ChipService.Initialize(...)` → `ChipGacha.Initialize(...)`) — §10.1의 DEV 지급 한 줄만 추가.

---

## 8. UI — 파일별 수정 지시 (프리팹/컴포넌트 재활용)

공통 원칙: 데이터는 `IVanguardChipProvider`만 의존, `Managers.Instance.GetManager<VanguardManager>().ChipService` 주입. **모든 `_useStubProvider` 필드/분기 제거.**

### 8.1 `VanguardChipDetailPopup` (General 부위 팝업) — 수정

`UI/Vanguard/Popup/VanguardChipDetailPopup.cs`. `Show<VanguardChipDetailPopup>((EquipmentType)i, provider)`로 열림(현행 유지).

- `_useStubProvider` 제거. provider 미전달 시 `VanguardManager.ChipService` 폴백.
- `ownerKey = (int)equipmentType`를 보관하고 슬롯 i에 대해:
  - `IsChipSlotUnlocked(General, ownerKey, i)` → 해금 시 `GetEquippedChip(General, ownerKey, i)`로 `SetState(Equipped/Empty)`.
  - 미해금 시 `GetChipSlotUnlockCost(General, ownerKey, i)`가 `> 0`일 때만 해금 버튼 활성(기존 "cost>0 순차 가드" 코드 그대로 — v2 서비스가 -1을 반환하므로 자연 동작).
  - `slot.OnUnequipClicked` → `UnequipChipAsync(General, ownerKey, i)`.
  - `slot.OnEmptySlotClicked` → **칩 선택 팝업(§8.3)** 오픈: `Show<VanguardChipSelectPopup>(EVanguardChipKind.General, ownerKey, i, _provider)`.
  - 빈 슬롯 클릭이 동작하려면 `ChipSlotDisplay.IsSwapMode = true`로 세팅(`OnPointerClick`이 SwapMode에서만 Empty 클릭을 전달함 — 기존 컴포넌트 동작).
- 해금 호출은 기존 `UnlockSlotAsync(General, idx)` 대신 `UnlockChipSlotAsync(General, ownerKey, i)`로 교체. 재화 부족 토스트/`ServerLoadingPopupUI` 패턴은 기존 코드 유지.

### 8.2 `VanguardUnitDetailPopup` (Exclusive 유닛 팝업) — 수정

`UI/Vanguard/Popup/VanguardUnitDetailPopup.cs`. `Show<VanguardUnitDetailPopup>(EUnitType)`로 열림(현행 유지, `VanguardChipSlot.OnEquippedSlotButtonClicked`가 이미 호출).

- `_useStubProvider` 제거 → `_provider = Managers.Instance.GetManager<VanguardManager>()?.ChipService;`
- `ownerKey = (int)_unitType`. `_chipSlots`(ChipSlotDisplay 4개) 각 i에 대해 §8.1과 동일 패턴을 `(Exclusive, ownerKey, i)`로 적용:
  - 기존 `IsSlotUnlocked(Exclusive, idx)`/`GetSlotUnlockCost`/`UnlockSlotAsync` 호출을 전부 `IsChipSlotUnlocked`/`GetChipSlotUnlockCost`/`UnlockChipSlotAsync(Exclusive, ownerKey, i)`로 교체 (현행 코드는 배치 그리드 의미와 충돌하는 버그).
  - `OnSlotClicked(i)`(현재 빈 구현) → `Show<VanguardChipSelectPopup>(EVanguardChipKind.Exclusive, ownerKey, i, _provider)`.
  - 각 슬롯 `IsSwapMode = true`.

### 8.3 `VanguardChipSelectPopup` — 신규 (유일한 신규 UI)

`UI/Vanguard/Popup/VanguardChipSelectPopup.cs` + 프리팹. **전부 기존 컴포넌트 재활용**: 리스트 셀 `ChipInventoryItem`, 상세 `ChipInfoDisplay`, 베이스 `VanguardPopupBase`(닫기/생명주기).

```csharp
/// 칩 선택 팝업: 슬롯에 장착할 후보 칩 리스트 → 선택 → 장착.
/// Opened param: [0]=EVanguardChipKind, [1]=ownerKey(int), [2]=chipSlot(int), [3]=IVanguardChipProvider
public class VanguardChipSelectPopup : VanguardPopupBase
{
    [SerializeField] private Transform _content;                    // ScrollRect content
    [SerializeField] private ChipInventoryItem _itemPrefab;        // 재활용
    [SerializeField] private ChipInfoDisplay _infoDisplay;         // 재활용 (선택 칩 상세)
    [SerializeField] private BaseButton _equipButton;
    // Opened: 후보 = provider.GetBag(kind)
    //   .Where(General → chip.slotType == (EquipmentType)ownerKey
    //          Exclusive → chip.targetUnits.Contains((EUnitType)ownerKey))
    //   정렬: rarity 내림차순 → chipId.
    // 셀 클릭 → _infoDisplay.SetChip + 선택 표시. 장착 버튼 →
    //   await provider.EquipChipAsync(kind, ownerKey, chipSlot, selected); 성공 시 Hide.
    //   (이미 다른 슬롯에 장착된 칩 선택 시 스왑됨 — 서비스가 처리)
}
```

### 8.4 `VanguardUnitSetupPopup` — 소폭 수정

- Bag 표시(`GetBag(_currentKind)` + `ChipFilterPopupUI` 필터)는 현행 유지 — 열람/상세 전용. 장착은 §8.1/§8.2 팝업에서 수행.
- `OpenChipDetail(int slotIndex)`의 `Show<VanguardChipDetailPopup>((EquipmentType)slotIndex, _provider)` 현행 유지.
- 배치 그리드 해금(`UnlockSlotAsync(Exclusive, idx)`) 현행 유지(의미 그대로).
- **팝업 Closed 시 `VanguardManager.SaveLoadoutAsync().Forget()` 1회 호출 추가** — 장착 변경의 매칭 클론 동기화(§9). 장착 때마다 호출하지 않고 닫힐 때 모아서 1회.

### 8.5 `VanguardGeneralChipPanel` — Refresh 보강

부위 슬롯은 "부위 대표 + 장착 수 인디케이터"로 표시:

```csharp
public void Refresh()
{
    if (_provider == null || _slots == null) return;
    for (int i = 0; i < _slots.Length; i++)
    {
        var slot = _slots[i]; if (slot == null) continue;
        Chip first = null; int equipped = 0;
        for (int s = 0; s < VanguardChipConst.GeneralChipSlotsPerType; s++)
        {
            var c = _provider.GetEquippedChip(EVanguardChipKind.General, i, s);
            if (c != null) { equipped++; first ??= c; }
        }
        slot.SetState(first != null ? EChipSlotState.Equipped : EChipSlotState.Empty, first);
        // TODO(표시): _chipIndicators에 equipped 수만큼 점등 — VanguardChipSlot에 SetIndicatorFill(int) 추가
    }
}
```

`VanguardExclusiveChipPanel`/`VanguardChipSlot`은 수정 불필요(배치 그리드 의미 유지).

---

## 9. 전투 효과 적용 + 매칭 클론 동기화

### 9.1 `ChipEffectManager`에 Vanguard 컨텍스트 오버라이드 추가

본게임 효과 파이프라인(`GetTotalEffectValue(EUnitType, EChipEffectType)` → `DamageCalculationManager.ChipEffect.cs`)을 그대로 쓰되, **Vanguard 전투 중엔 효과 소스만 교체**한다(Ark 모드의 "칩 효과 차단" 패턴과 동형). `Core/Managers/ChipEffectManager.cs`:

```csharp
// ── Vanguard 전용 칩 컨텍스트 (null = 비활성, 본게임 장착 칩 사용) ──
private List<Chip> _vanguardChipContext;

/// Vanguard 전투 진입 시 호출 — 본게임 장착 칩 대신 이 목록으로 효과를 계산한다.
public void SetVanguardChipContext(IReadOnlyList<Chip> chips)
{
    _vanguardChipContext = chips != null ? new List<Chip>(chips) : new List<Chip>();
    RefreshAllEffects();
}

/// Vanguard 전투 이탈 시 반드시 호출 — 전역 상태 오염 금지(매니저 규칙).
public void ClearVanguardChipContext()
{
    _vanguardChipContext = null;
    RefreshAllEffects();
}
```

`RefreshAllEffects()`의 본게임 칩 순회 블록(`_chipManager.EquippedChips` foreach) **직전**에 분기 추가:

```csharp
if (_vanguardChipContext != null)
{
    foreach (var chip in _vanguardChipContext)
        if (chip != null) ApplyChipEffect(chip, chip.slotType, 0);   // 기존 ApplyChipEffect 재사용
    foreach (EUnitType unitType in System.Enum.GetValues(typeof(EUnitType)))
        OnChipEffectsChanged?.Invoke(unitType);
    return;   // 본게임 장착 칩은 적용하지 않음
}
```

- Exclusive 칩은 `targetUnits`(소유 유닛 1종)로 유닛 한정 적용, General 칩은 `targetUnits` 공란이면 전역 적용 — `ApplyChipEffect`의 기존 분기가 그대로 처리한다.
- 데미지 모디파이어는 `DamageCalculationManager.ChipEffect.cs` 경로 무변경. 합산 규칙은 항상 가산(additive) — `ChipEffectSumData` 규칙 그대로.

### 9.2 진입/이탈 훅

Vanguard 전투 시작 지점(`VanguardStagePlayService` 구동 직전 — `StageManager`의 Vanguard 스테이지 시작 경로, `BuildStageDataAsync` 호출부와 동일 위치):

```csharp
var vm = Managers.Instance.GetManager<VanguardManager>();
Managers.Instance.GetManager<ChipEffectManager>()?.SetVanguardChipContext(vm?.ChipService?.GetAllEquippedChips());
```

전투 종료/씬 이탈(라운드 루프 종료, 포기, 씬 전환 Cleanup 등 **모든 출구**)에서:

```csharp
Managers.Instance.GetManager<ChipEffectManager>()?.ClearVanguardChipContext();
```

> 안전망: `VanguardStagePlayService.Cleanup()`(BaseStagePlayService 수명 종료)에서 Clear를 한 번 더 호출해 누수 방지.

### 9.3 매칭 클론 동기화 (이미 구현됨 — 확인만)

`VanguardManager.BuildLoadoutDto()`가 `vanguardEquippedChips`를 `chips["slot{n}"] = { "grade": ... }`로 직렬화한다(구현 완료, 등급 변환 `ChipRarityToGrade`: rare/epic/legend/mythic/transcend). CPS는 서버 권위(희귀1/서사3/전설8/신화10/초월20). 클라가 할 일은 **장착 변경 후 `SaveLoadoutAsync()` 호출**(§8.4에서 처리)뿐.

---

## 10. DEV 테스트 환경

### 10.1 DEV에서 전체 칩 자동 지급

`VanguardManager.InitializeAsync()` 맨 끝에 추가(멱등 — 이미 보유한 칩은 건드리지 않음, 시즌 리셋 후 재진입 시 자동 재지급):

```csharp
#if DEV
        await GrantAllChipsForDevAsync();
#endif
```

```csharp
#if DEV
    /// DEV 전용: 풀 테이블의 모든 칩을 1개 이상 보유하도록 지급(멱등). 칩 슬롯 해금 테스트용 DS는 치트로 지급.
    private async UniTask GrantAllChipsForDevAsync()
    {
        if (_saveData == null || !VanguardChipPoolTable.IsBuilt) return;
        _saveData.vanguardOwnedChips ??= new List<VanguardOwnedChip>();
        int added = 0;
        foreach (EChipRarityType r in Enum.GetValues(typeof(EChipRarityType)))
        {
            foreach (var entry in VanguardChipPoolTable.ByRarity(r))
            {
                var owned = _saveData.vanguardOwnedChips.Find(x => x.chipId == entry.chipId);
                if (owned == null) { _saveData.vanguardOwnedChips.Add(new VanguardOwnedChip { chipId = entry.chipId, count = 1 }); added++; }
            }
        }
        if (added > 0)
        {
            await SaveDataAsync();
            RLog.Log($"[VanguardManager][DEV] 뱅가드 칩 전체 지급: 신규 {added}종 (총 {_saveData.vanguardOwnedChips.Count}종)");
        }
    }
#endif
```

### 10.2 치트 모듈 (F10 콘솔)

`Core/Managers/Cheat/CheatCommandLibrary.cs`(파일 전체가 `#if DEV`)에 `VanguardChipModule` 추가하고 `CreateCommands()`에 `commands.AddRange(VanguardChipModule.CreateCommands());` 등록:

```csharp
private static class VanguardChipModule
{
    public static IEnumerable<CheatCommand> CreateCommands()
    {
        yield return new CheatCommand(
            "vanguard.add_chip_currency", "Vanguard", "뱅가드 칩 재화 지급",
            "표준/특수 열쇠와 표준 DS를 지급합니다.",
            new[]
            {
                CheatCommandParameter.CreateInt("keys", "표준/특수 열쇠 수량", 50),
                CheatCommandParameter.CreateInt("ds", "표준 DS 수량", 2000),
            },
            context =>
            {
                var cm = context.RequireManager<CurrencyManager>();
                int keys = context.GetParameter<int>("keys");
                int ds = context.GetParameter<int>("ds");
                cm.ModifyCurrency(ECurrencyType.VanguardStandardKey, keys);
                cm.ModifyCurrency(ECurrencyType.VanguardSpecialKey, keys);
                cm.ModifyCurrency(ECurrencyType.VanguardStandardDS, ds);
                context.Log($"열쇠 각 {keys}, 표준DS {ds} 지급");
                return UniTask.CompletedTask;
            });

        yield return new CheatCommand(
            "vanguard.open_chest", "Vanguard", "뱅가드 상자 개봉",
            "표준/특수 상자를 N회 개봉합니다(열쇠 차감).",
            new[]
            {
                CheatCommandParameter.CreateBool("special", "특수 상자", false),
                CheatCommandParameter.CreateInt("count", "개봉 횟수", 10),
            },
            async context =>
            {
                var vm = context.RequireManager<VanguardManager>();
                var type = context.GetParameter<bool>("special") ? EVanguardChestType.Special : EVanguardChestType.Standard;
                var results = await vm.ChipGacha.OpenChestMultiAsync(type, context.GetParameter<int>("count"));
                if (results == null) { context.Log("개봉 실패(열쇠 부족/테이블 미빌드)"); return; }
                foreach (var e in results) context.Log($"  {e.rarity} {e.kind} chipId={e.chipId}");
                context.Log($"{type} {results.Count}개 개봉, 천장 {vm.ChipGacha.GetPityCount(type)}/{VanguardChipConst.PityThreshold}");
            });

        yield return new CheatCommand(
            "vanguard.grant_all_chips", "Vanguard", "뱅가드 칩 전체 지급",
            "풀 테이블의 모든 칩을 1개씩 보유 처리합니다(미보유분만).",
            Array.Empty<CheatCommandParameter>(),
            async context =>
            {
                var vm = context.RequireManager<VanguardManager>();
                await vm.GrantAllChipsForDevAsync();          // §10.1 메서드를 internal/public으로 노출
                context.Log("전체 칩 지급 완료");
            });

        yield return new CheatCommand(
            "vanguard.reset_chips", "Vanguard", "뱅가드 칩 초기화",
            "보유/장착/칩슬롯 해금/천장을 모두 리셋합니다.",
            Array.Empty<CheatCommandParameter>(),
            async context =>
            {
                var vm = context.RequireManager<VanguardManager>();
                var s = vm.SaveData;
                s.vanguardOwnedChips.Clear(); s.vanguardEquippedChips.Clear();
                s.vanguardUnlockedGeneralChipSlots.Clear(); s.vanguardUnlockedExclusiveChipSlots.Clear();
                s.vanguardStandardChestCount = 0; s.vanguardSpecialChestCount = 0;
                await vm.SaveChipDataForDevAsync();           // SaveDataAsync 래퍼(DEV 노출) 추가
                context.Log("칩 데이터 리셋 완료");
            });
    }
}
```

(§10.1의 `GrantAllChipsForDevAsync`와 저장 래퍼는 `#if DEV public`으로 노출.)

### 10.3 상점 임시 뽑기 버튼

`VanguardShopPopup`의 Shop 탭 패널(`VanguardShopPanel`)에 임시 버튼 2개(표준 1회 / 특수 1회) 추가:

- 프리팹: 버튼 2개를 `[DEV]` 라벨로 배치, `[SerializeField] private Button _devStandardChestButton, _devSpecialChestButton;`
- 코드(`VanguardShopPanel.Init()`):

```csharp
#if DEV
    if (_devStandardChestButton != null) { _devStandardChestButton.gameObject.SetActive(true);
        _devStandardChestButton.onClick.AddListener(() => OpenChestForDevAsync(EVanguardChestType.Standard).Forget()); }
    if (_devSpecialChestButton != null) { _devSpecialChestButton.gameObject.SetActive(true);
        _devSpecialChestButton.onClick.AddListener(() => OpenChestForDevAsync(EVanguardChestType.Special).Forget()); }
#else
    if (_devStandardChestButton != null) _devStandardChestButton.gameObject.SetActive(false);
    if (_devSpecialChestButton != null) _devSpecialChestButton.gameObject.SetActive(false);
#endif

#if DEV
private async UniTaskVoid OpenChestForDevAsync(EVanguardChestType type)
{
    var vm = Managers.Instance.GetManager<VanguardManager>();
    var entry = await vm.ChipGacha.OpenChestAsync(type);   // 열쇠 부족 시 CanAfford가 안내 표시
    if (entry == null) return;
    ToastManager.ShowToast($"{entry.rarity} {(entry.kind == EVanguardChipKind.General ? "장비" : "유닛")}칩 획득! (id {entry.chipId})");
}
#endif
```

> 정식 상점 구매 플로우(상자 상품 → 열쇠 → 개봉 연출)가 붙으면 이 버튼은 제거한다.

---

## 11. 구현 체크리스트 (순서대로)

**A. 컴파일 복구 + 데이터**
- [ ] 시트 동기화(또는 §1.2 수기)로 4개 클래스 재생성 — `EChipSlotType` 참조 소멸
- [ ] `VanguardChipPoolTable.Build` §3.1로 교체 (`u.slotType`/`e.slotType`)
- [ ] `VanguardChipDropDataSOExtensions.GetWeight` 신규 (§3.2)
- [ ] 에디터에서 JSON→SO 변환 3종 실행, .asset 211/523/2개 확인 (§2.3)
- [ ] 플레이 진입 → "칩 풀 테이블 비어 있음" 경고 없음 확인

**B. 저장 + 서비스**
- [ ] `VanguardSaveData`에 칩 슬롯 해금 2필드 추가 + `ResetSeasonProgress` 갱신 (§5)
- [ ] `VanguardChipConst` v2 교체 (§4.3)
- [ ] `IVanguardChipProvider` v2 교체 + `VanguardChipProviderStub` 갱신 (§7.1)
- [ ] `VanguardChipService` v2 교체 (§7.2)

**C. UI**
- [ ] `VanguardChipDetailPopup` 수정: stub 제거, (General, 부위, i) 칩슬롯 API, 칩 선택 팝업 연결 (§8.1)
- [ ] `VanguardUnitDetailPopup` 수정: stub 제거, (Exclusive, 유닛, i) 칩슬롯 API, 칩 선택 팝업 연결 (§8.2)
- [ ] `VanguardChipSelectPopup` 신규 + 프리팹 (§8.3)
- [ ] `VanguardUnitSetupPopup` Closed 시 `SaveLoadoutAsync` (§8.4), `VanguardGeneralChipPanel.Refresh` 보강 (§8.5)

**D. 효과 + DEV**
- [ ] `ChipEffectManager` Vanguard 컨텍스트 + 전투 진입/이탈 훅 (§9.1~9.2)
- [ ] DEV 전체 칩 지급 (§10.1), 치트 모듈 (§10.2), 상점 임시 버튼 (§10.3)

**E. 검증**
- [ ] 치트 `vanguard.open_chest`로 표준/특수 각 1,000회+ → 등급 분포가 드랍표 비율(±오차)과 일치, Transcend 내 47/23/9/4 차등 확인
- [ ] 뽑은 칩이 kind에 맞는 Bag(General/Exclusive 탭)에만 노출
- [ ] General 부위 불일치 칩 / Exclusive 비대상 유닛 칩 장착 차단, 동일 칩 중복 장착 시 스왑
- [ ] 칩 슬롯 순차 해금: 선행 미해금 시 버튼 비활성, DS 차감, 부족 시 토스트
- [ ] 같은 provider를 쓰는 Setup 팝업·상세 팝업 간 OnChanged 갱신 동기화
- [ ] Vanguard 전투 중 칩 효과 적용(전용 유닛 한정/장비 전역) + 본게임 복귀 시 컨텍스트 Clear(본게임 칩 효과 정상 복원)
- [ ] 장착 변경 → Setup 팝업 닫기 → `loadout/save` chips grade 전송 확인
- [ ] 시즌 전환 → 칩 빌드 전량 리셋(해금 2필드 포함), EmberMark 유지
- [ ] DEV 빌드 첫 진입 시 전체 칩(734종) 자동 보유

---

## 부록 A. 검증된 참조 시그니처 (문서 코드가 의존하는 실제 API)

| API | 시그니처 (파일) |
|---|---|
| 통화 | `bool CanAfford(ECurrencyType, int amount, bool isShowItemDisplay = false)` / `bool SpendCurrency(ECurrencyType, int, bool autoSave = true)` / `bool ModifyCurrency(ECurrencyType, int, ...)` (`CurrencyManager.cs`) |
| 저장 | `UniTask<bool> SaveDataAsync(SaveDataTypes.ESaveDataType, object)` / `UniTask<T> LoadDataAsync<T>(...)` (`SaveDataManager.cs`), `ESaveDataType.Vanguard` 존재 |
| 마스터 효과 | `ChipEffectData GetChipEffectData(int chipID)` → `{ chipID, slotType(EquipmentType), targetUnits, effectType, effectValue, subEffectValue, weight, description }` (`ChipManager.cs`) |
| 효과 조회 | `float GetTotalEffectValue(EUnitType, EChipEffectType)` / `GetTotalSubEffectValue(...)` (`ChipEffectManager.cs`) |
| 리소스 | `T[] LoadAllResourcesInFolder<T>(string folderPath)` (`ResourceManager.cs`) |
| UI | `T Show<T>(params object[] param)` / `void Hide<T>(params object[] param)` (`UIManager.cs`), `ServerLoadingPopupUI.Show(string)/Hide()`, `ToastManager.ShowToast(string)` |
| 재화 enum | `VanguardStandardDS=1286, VanguardSpecialDS=1287, VanguardStandardKey=1288, VanguardSpecialKey=1289, VanguardDualToken=1290, VanguardEmberMark=1291` (`ECurrencyType.cs`) |
| 칩 enum | `EChipRarityType { Common..Transcend=6 }`, `EChipSlotState { Empty, Equipped, CantUnequip=3, Unlockable=4 }`, `EquipmentType { Shield..Boots }` (Transcend 마스터 효과 폴더명은 `ChipEffectsSpecialData`) |
| DEV 심볼 | `#if DEV` (치트 전체), `#if UNITY_EDITOR \|\| DEV` (타임머신 등) |

## 부록 B. 풀 통계 (설치된 테스트 데이터 기준)

- Unit 풀 211종: 유닛 11종(Turret/Archon/DrFrost/Carrier/AirMan/Ninja/Vessel/Marauder/Templer/Dragoon/Thor — Marine 없음).
- Equipment 풀 523종: Shield 89 / Helmet 81 / Armor 76 / Weapon 95 / EnergyCore 92 / Boots 90. targetUnits 그룹: 공란(전체) / Marine / Marine,Vessel,Ninja / Archon,Dragoon,Carrier / Turret,Marauder / Templer,Thor / DrFrost,AirMan.
- poolWeight: Rare~Mythic 전부 1(등급 내 균등), Transcend만 47/23/9/4 차등.
- 등급 ID 대역: Rare 52xxx / Epic 53xxx / Legendary 54xxx / Mythic 55xxx / Transcend 56xxx — 마스터 칩 효과 에셋과 1:1.

_작성 기준: 제공 시트 3종 + 2026-06-10 코드베이스 실사(모든 경로/시그니처 검증). 통합 풀 뽑기 확정, 효과 수치는 기존 마스터 칩 효과 데이터(chipId 매핑) 재사용._
