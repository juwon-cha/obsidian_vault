# Vanguard 카드 지급 시스템 — 시즌 8장 + 인게임 스테이지 1장

> 작성: 2026-06-04 · 갱신: 2026-06-04 (테이블 방식 확정 — 구성 변경을 서버 배포 없이 시트로) · 범위: 시즌 랜덤 카드(8장) 지급 + 인게임 스테이지 카드(시즌 카드 제외 1장) 지급 로직 설계
> 근거: [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) V0.13.7 원문 · `CardManager.cs` · `VanguardManager.cs`(SeasonService/RankService/StatService) · `BalanceDataManager.cs`
> 연관: [[2026-06-03_vanguard-ingame-battle-ui]] §2-A (위키 인게임 규칙)

---

## 0. TL;DR

- 시즌 8장과 인게임 1장은 **요구사항이 다른 두 시스템**: 시즌 8장 = 결정적(deterministic)·전 플레이어 동일·**서버 권위** / 인게임 1장 = 비결정적·개인 랜덤·**클라 로컬**.
- 카드 선정 규칙은 `VanguardCardRuleData` 신규 시트로 데이터화. 기존 제안의 `poolFilter` 문자열 조건식은 **삭제** (양쪽 식 파서 필요 → 과설계). **기획자가 시즌마다 카드를 기입하는 테이블이 아님** — 카드는 서버가 랜덤 선정, 테이블엔 "뽑는 구성"만 1회 기입.
- 서버 선정 로직은 룰 행을 순회하는 **범용 코드**로 작성 → 구성 변경(장수 조정·랭크 확장·특정 카드 고정)은 **시트 수정만으로** 가능, 서버 배포 불필요 (§4-1). 단 반영은 **다음 시즌 생성부터**, 클라 시즌 카드 UI는 **가변 개수 레이아웃** 필수.
- 시드 랜덤을 클라/서버가 각자 돌리지 **말 것** (C# `System.Random` ≠ 서버 RNG). **서버가 시즌 생성 시 1회 선정 → 시즌 문서에 `seasonCardIds[8]` 저장 → `/vanguard/enter` 응답으로 전달**.
- 인게임 1장은 기존 `CardManager.GetAvailableCards()` + `SelectCardsByWeight()`에 **Vanguard 분기(시즌 카드 제외) 하나만 추가**.

---

## 1. 위키 원작 구조 (설계 근거)

위키 V0.13.7 "Event Info & Rules" 핵심 규칙:

> "Each event phase designates 9 turrets. Chip draws will only include their exclusive and general chips."
> "Each round features a fixed Turret Card set — **all players use the same cards**."

| 원작 | 의미 | WiggleDefender 대응 |
|---|---|---|
| 시즌(주간 페이즈)마다 지정 유닛 9종 회전 | 유닛 풀이 시즌 컨텍스트 | `VanguardSeasonData.targetUnits[]` |
| 라운드 고정 카드 세트, 전 플레이어 동일 | 비동기 PVP 공정성 → 모두 같은 카드 | **시즌 랜덤 카드 8장** (시즌별 회전, 전원 동일) |
| Ember Pass: 라운드 시작마다 랜덤 활성 카드 1장 (Initiative Boost) | 개인별 랜덤, 공정성 제약 없음 | **인게임 스테이지 1장 지급** (시즌 카드 제외) |
| 본편 성장 미적용 (다이아 제외) | 인게임은 시즌 내 자원만 | 카드 풀 필터에 아웃게임 레벨 제한 무시 여부 결정 필요 (§7) |

핵심: **시즌 8장은 "나와 고스트(상대 기록)가 같은 조건"이어야 하므로 결정적이어야 하고, 인게임 1장은 개인 보상이라 일반 랜덤이면 충분.**

---

## 2. 기존 테이블 제안 해석

제안받은 `vanguard-card-rule-v1` 테이블 = "8장을 하드코딩하지 않고 **선정 규칙을 데이터로** 두자"는 설계. 행 하나 = 버킷 하나:

| 행 | 의미 |
|---|---|
| rank1 / Common / 3장 | 시즌 유닛의 랭크1 일반카드 풀에서 3장 |
| rank1 / Promotion / 1장 | 랭크1→2 진급카드 1장 (랭크2 해금 필수) |
| rank2 / Common / 3장 | 랭크2 일반카드 3장 |
| rank2 / Promotion / 1장 | 랭크2→3 진급카드 1장 |

합계 8장. rank1→2 구성인 이유: CardManager의 기존 랭크 게이팅(진급카드 획득 → 다음 랭크 카드 해금) 동선을 시즌 세트 안에서 완결시키기 위함.

컬럼 해석:

- **ruleId**: 4행을 하나의 규칙 버전으로 묶는 키. `VanguardSeasonData.cardRuleId`가 참조 → 시즌별 구성 변경(예: rank3까지 12장)을 코드 수정 없이 시트에서.
- **pickMode**: `SEEDED_RANDOM` = 시즌 시드로 선정(시즌마다 회전, 전원 동일) / `FIXED` = 기획자 직접 지정.
- **poolFilter**: CardData 후보 필터 조건식 문자열.
- **DB_IGNORE**: 시트→DB 임포트 시 무시되는 주석 컬럼.

### 문제점과 단순화

`poolFilter` 문자열 조건식(`targetUnit==유닛 & cardRank==1 & ...`)은 클라+서버 양쪽에 식 파서가 필요 → 과설계.

- `cardRank`, `cardType`은 이미 별도 컬럼 → 중복.
- `targetUnit`은 테이블 데이터가 아니라 **시즌 런타임 컨텍스트** (이번 시즌 지정 유닛).

→ poolFilter 삭제, 필터를 코드 규약으로 고정:

```
풀 = CardData where
    targetUnit ∈ 시즌 지정 유닛 (VanguardSeasonData.targetUnits)
  && cardRank == row.cardRank
  && cardType == row.cardType
  && weight > 0
```

---

## 3. 최종 테이블 설계

### 3-1. VanguardCardRuleData (신규 시트, 서버+클라 공용)

```
ruleId                  cardRank  cardType    pickCount  fixedCardIDs      DB_IGNORE
string                  int       ECardType   int        List<int>(선택)
vanguard-card-rule-v1   1         Common      3          (빈칸=시드랜덤)    랭크1 일반 3장
vanguard-card-rule-v1   1         Promotion   1                            랭크1→2 진급 1장
vanguard-card-rule-v1   2         Common      3                            랭크2 일반 3장
vanguard-card-rule-v1   2         Promotion   1                            랭크2→3 진급 1장
```

기존 파이프라인(Google Sheets → 서버 → `BalanceDataManager` AES 캐시 → 클라)에 그대로 태움. **시트 = 단일 소스.**

#### 컬럼 상세

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `ruleId` | string | 여러 행을 하나의 "규칙 세트"로 묶는 그룹 키. `VanguardSeasonData.cardRuleId`가 이 값을 참조. **같은 ruleId를 가진 행 전체 = 한 시즌의 카드 구성.** 새 구성을 만들려면 `-v2` 행들을 추가하고 시즌 데이터의 참조만 바꿈 — 기존 v1 행은 남겨두므로 롤백도 시트에서 가능. |
| `cardRank` | int | 이 행이 뽑을 카드의 랭크. **`CardData.cardRank`와 정확히 매칭**되는 필터 값. 1이면 랭크1 카드 풀만 대상. |
| `cardType` | ECardType | 이 행이 뽑을 카드 타입. **`CardData.cardType`과 매칭.** `Spawn(0)/Common(1)/Chain(2)/Promotion(3)/Combo(4)` 중 하나. 시트엔 enum 이름 문자열로 기입(기존 CardData 시트의 cardType 표기 규약과 동일하게). |
| `pickCount` | int | 이 (rank, type) 버킷에서 자동 선정할 장수. 풀 크기보다 크면 "풀 전체" 선정 + 서버 경고 로그 (시트 실수 방어). |
| `fixedCardIDs` | List<int> (선택) | **빈칸 = SEEDED_RANDOM** (시즌 시드로 자동 선정, 시즌마다 회전). **값 있음 = FIXED** (기입한 cardID를 그대로 사용, 랜덤 안 함). 원안의 `pickMode` 컬럼을 흡수한 것. 기입 시 개수가 `pickCount`와 다르거나 풀 조건(rank/type 불일치) 위반이면 시트 검증 단계에서 에러. |
| `DB_IGNORE` | - | 주석 컬럼. 시트→DB 임포트 시 무시됨 (기존 파이프라인 관례). 기획 메모용. |

#### 행(row) 의미

**행 1개 = 버킷 1개 = "(cardRank, cardType) 조합의 풀에서 pickCount장을 뽑아라"는 명령.** 서버는 시즌 생성 시 `cardRuleId` 매칭 행을 위에서부터 순회하며 행마다 독립적으로 선정하고, 결과를 이어붙인 것이 시즌 카드 세트. 전체 합 = 시즌 카드 수 (현재 3+1+3+1 = **8장**).

| 행 | 읽는 법 | 기획 의도 |
|---|---|---|
| `(1, Common, 3)` | 시즌 유닛의 랭크1 일반카드 풀에서 시드 랜덤 3장 | 초반 빌드 다양성 |
| `(1, Promotion, 1)` | 랭크1→2 진급카드 풀에서 1장 | 랭크2 카드 해금 경로 보장 (이게 없으면 아래 랭크2 카드가 영원히 잠김) |
| `(2, Common, 3)` | 랭크2 일반카드 풀에서 3장 | 중후반 빌드 |
| `(2, Promotion, 1)` | 랭크2→3 진급카드 풀에서 1장 | 최종 성장 구간 |

#### 테이블에 없는 것 (의도적)

- **`targetUnit`**: 테이블 데이터가 아니라 시즌 런타임 컨텍스트 → `VanguardSeasonData.targetUnits[]`에서 옴. 룰은 유닛에 독립적이라 모든 시즌이 재사용.
- **`weight > 0` 등 공통 필터**: 코드 규약으로 고정 (§4-1). 식 문자열로 시트에 넣으면 파서가 필요해져 과설계.
- **시드**: 서버가 `hash(seasonId + 행 식별자)`로 계산. 시트에 둘 이유 없음.

### 3-2. VanguardSeasonData (신규 또는 서버 시즌 문서)

```
seasonId · rankingStartDate · targetUnits[] · cardRuleId
```

- 시즌 유닛 회전도 여기서 관리.
- 선정 결과 `seasonCardIds[8]`는 시트가 아니라 **서버가 시즌 생성 시 계산해 저장하는 런타임 값**.

### 3-3. CardData (기존, 변경 없음)

`cardID / cardRank / cardType / targetUnit / weight / maxCount / parentCardIDs ...` — 필터에 필요한 컬럼이 이미 전부 있음.

> ⚠️ `SOs/SO/DataSheet/` 자동생성 SO 직접 수정 금지. 커스텀 로직 필요 시 `VanguardCardRuleDataParser.cs` 분리 (ArkStageDataSOParser 패턴).

---

## 4. 시즌 8장 선정 — 서버 권위 (권장 구조)

### ❌ 피해야 할 방식: 클라/서버가 같은 시드로 각자 선정

C# `System.Random`과 서버(Node 등) RNG는 알고리즘이 달라 같은 시드여도 결과가 다름. 동일 커스텀 RNG를 양쪽 구현해도 한쪽이 어긋나는 순간 전 유저 덱이 갈라지는 사고. (참고: 현재 코드베이스에 시드 랜덤 사용처 없음 — CardManager는 `UnityEngine.Random` 직접 사용)

### ✅ 권장: 서버 1회 선정 + 저장 + 전달

```
[서버 — 시즌 생성 시 1회]
시즌 문서 생성 (rankingStartDate 등)
  → VanguardCardRuleData 로드 (cardRuleId 매칭 행들)
  → 버킷별: CardData 필터 (§2 규약)
       → seed = hash(seasonId + ruleId + cardRank + cardType)
       → 풀을 cardID 오름차순 정렬 후 Fisher-Yates → pickCount장 선정
  → 시즌 문서에 seasonCardIds: [8개 ID] 저장   ← 권위값

[클라 — 시즌 진입 시]
VanguardSeasonService.EnterSeasonAsync()
  → VanguardEnterResponse에 seasonCardIds 필드 추가 수신
  → VanguardSaveData에 캐시 (lastSeasonStartDate와 함께)
  → CardManager._allCardData에서 ID → CardDataSO 매핑 (표시/적용)
```

- 결정성 문제 원천 차단. 클라는 ID 8개만 수신.
- 기존 `EnterSeasonAsync()`가 이미 `rankingStartDate`로 새 시즌 판정 중 → 응답 필드 하나 추가 수준의 변경.
- 클라 측 룰 테이블 용도: 검증 / 오프라인 폴백 / UI 표시로 한정.

### 4-1. 서버 선정 로직 — 반드시 "범용 코드"로

서버 코드에 "8장", "랭크1·2" 같은 구성 가정을 **하드코딩하지 않고** 룰 행을 순회:

```js
// 시즌 생성 시 1회
const rows = loadTable('VanguardCardRuleData')
  .filter(r => r.ruleId === season.cardRuleId);

const seasonCardIds = rows.flatMap(row => {
  if (row.fixedCardIDs?.length) return row.fixedCardIDs;        // FIXED

  const pool = cardData.filter(c =>                              // 풀 필터 (코드 규약)
    season.targetUnits.includes(c.targetUnit) &&
    c.cardRank === row.cardRank &&
    c.cardType === row.cardType &&
    c.weight > 0);

  const seed = hash(season.id, row.ruleId, row.cardRank, row.cardType);
  return seededPick(sortById(pool), row.pickCount, seed);        // SEEDED_RANDOM
});

await saveSeasonDoc(season.id, { seasonCardIds });               // 권위값 저장
```

이렇게 짜두면 **시트 수정만으로** (서버 배포 없이) 가능한 변경:

| 변경 | 시트 작업 |
|---|---|
| 장수 조정 (Common 3→4장) | 해당 행 `pickCount` 수정 |
| 랭크3 확장 (8→12장) | `(3, Common, 3)`, `(3, Promotion, 1)` 행 추가 |
| 특정 카드 고정 | `fixedCardIDs` 기입 |
| 구성 전면 교체 | `-v2` 행 세트 추가 + 시즌 데이터 `cardRuleId` 교체 |

**코드 수정이 여전히 필요한 변경** (테이블 스키마가 표현 못 하는 것): 새 필터 차원(예: 특정 effectType 제외), 새 선정 방식, `targetUnit` 외 풀 기준. 즉 자유도는 "rank × type × 장수 × 고정" 조합 안.

### 4-2. 운영 주의점

1. **적용 시점**: 선정은 시즌 생성 시 1회 → 시트 수정은 **다음 시즌부터** 반영. 진행 중 시즌의 `seasonCardIds`는 이미 저장된 값이라 불변 (이게 정상 — 중간에 바뀌면 비동기 PVP 공정성 붕괴).
2. **클라 UI 가변 레이아웃**: 서버는 장수 변경에 자유로워도 클라 시즌 카드 UI가 8슬롯 고정이면 깨짐. 표시 UI는 수신한 ID 개수 기반(List + 동적 슬롯)으로 구현.
3. **시트 검증**: `pickCount > 풀 크기`, `fixedCardIDs` 개수/조건 불일치는 시즌 생성 시 검증·경고. 시트 실수가 시즌 전체 사고로 번지는 걸 방어.

---

## 5. 클라 — VanguardCardService (신규 서브서비스)

기존 패턴(POCO 서브서비스 + VanguardManager 오케스트레이션, RaceTowerManager 선례) 준수:

```csharp
public class VanguardCardService
{
    private List<int> _seasonCardIds = new();                    // 서버 권위 8장
    private readonly HashSet<int> _grantedStageCardIds = new();  // 이번 매치 스테이지 지급분

    public IReadOnlyList<int> SeasonCardIds => _seasonCardIds;

    // EnterSeasonAsync 응답 수신 시 호출
    public void UpdateFromServer(int[] seasonCardIds)
    {
        _seasonCardIds = seasonCardIds?.ToList() ?? new List<int>();
    }

    public List<CardDataSO> GetSeasonCards(CardManager cardManager)
        => _seasonCardIds
            .Select(cardManager.GetCardDataByID)
            .Where(c => c != null)
            .ToList();

    public void ResetMatchState() => _grantedStageCardIds.Clear();
}
```

시즌 8장 노출 방식 (기획 결정 필요, §7):

- **A. 선택지 풀**: 위키 원작처럼 8장이 인게임 카드 선택지의 풀 (라운드 고정 세트 = 선택지로 제공).
- **B. 단순 지급**: 매치 시작 시 `_acquiredCardIDs`에 주입.

어느 쪽이든 `cardRank` 순서(rank1 3+1 → rank2 3+1) 덕에 기존 랭크 게이팅이 그대로 동작.

---

## 6. 클라 — 인게임 스테이지 1장 지급 (시즌 카드 제외)

새로 만들 것 거의 없음. CardManager에 이미 존재:

- `GetAvailableCards()` — 9가지 필터(랭크 제한·선행카드·maxCount·진급 정책 등) 구현 완료. **종족 던전이 "Spawn 제외" 특수 분기를 넣은 선례** → 같은 자리에 Vanguard 분기 추가.
- `SelectCardsByWeight(pool, 1)` — 가중치 랜덤.

```csharp
// CardManager.GetAvailableCards() 내, 종족 던전 분기 옆
if (_currentGameMode == GameModeType.Vanguard)
{
    var vanguardManager = Managers.Instance.GetManager<VanguardManager>();
    var excluded = vanguardManager.CardService.SeasonCardIds;

    availableCards.RemoveAll(card =>
        excluded.Contains(card.cardID) ||      // 시즌 8장 제외
        card.cardType == ECardType.Spawn);     // 기획 따라: 유닛은 시즌 고정이므로
}
```

지급 시점 (라운드/스테이지 클리어 핸들러):

```csharp
// 선택 UI를 거치는 경우 — 기존 큐 시스템 활용
cardManager.EnqueueEliteCardSelectionRequest(playerLevel, false, forceCardCount: 1);

// 선택 없이 즉시 1장 지급인 경우
var pool = cardManager.GetAvailableCards(...);
var picked = cardManager.SelectCardsByWeight(pool, 1);
await cardManager.ProcessCardAcquisitionAsync(picked[0]);
```

- 이 랜덤은 `UnityEngine.Random` 그대로 사용 (개인 보상 → 결정성 불필요).
- **치팅 검증(경량)**: 매치 결과 보고 시 이번 매치에서 받은 카드 ID 목록 동봉 → 서버가 "시즌 카드 아님 / 풀에 존재함" 정도만 검증.

---

## 7. 미해결 / 기획 확정 필요

- [ ] 시즌 8장 노출 방식: 선택지 풀(A, 위키 원작) vs 시작 시 자동 지급(B)
- [ ] 인게임 1장: 선택 UI(3장 중 1장?) vs 즉시 1장 자동 지급
- [ ] 스테이지 지급 풀에서 Spawn/Combo 타입 제외 여부 (유닛이 시즌 고정이라면 Spawn 제외가 자연스러움)
- [ ] 본편 성장 미적용 규칙 → `unitLevelLimit` / `cardRank` 아웃게임 제한 필터를 Vanguard에서 무시할지
- [ ] Ember Pass 대응(패스 보유 시 라운드 시작 랜덤 활성 카드)을 이 스테이지 1장과 통합할지 별도 시스템일지
- [ ] 시즌 유닛 수 (원작 9터렛 → 우리는 몇 유닛?)
- [ ] `VanguardEnterResponse.seasonCardIds` 서버 스펙 반영 ([[2026-05-31_vanguard-server-api-spec]]에 추가 필요)

---

## 8. 구현 체크리스트

1. [ ] 시트에 `VanguardCardRuleData` 추가 → 기존 파이프라인 로드 확인 (클라+서버)
2. [ ] 서버: 시즌 생성 시 8장 선정·저장, `/vanguard/enter` 응답에 `seasonCardIds` 추가
3. [ ] 클라: `VanguardCardService` 신설 (VanguardManager 서브서비스 패턴)
4. [ ] 클라: `VanguardEnterResponse` 파싱 확장 + `VanguardSaveData` 캐시
5. [ ] 클라: `CardManager.GetAvailableCards()` Vanguard 분기 + 라운드 클리어 지급 훅
5-1. [ ] 클라: 시즌 카드 표시 UI를 가변 개수(List 기반) 레이아웃으로 (§4-2)
5-2. [ ] 서버: 시트 검증 (pickCount > 풀 크기 / fixedCardIDs 불일치 경고) (§4-2)
6. [ ] CLAUDE.md 준수: GetManager만 / `async void` 금지 / EventManager static / `DateTime.Now` 금지(`ServerTimeManager.NowUnscaled`) / 매직넘버 const / 로컬라이즈 키
7. [ ] 검증: 같은 시즌 두 계정 동일 8장 / 스테이지 지급에서 시즌 8장 절대 미출현 / 시즌 전환 시 회전 / 진급카드 게이팅 정상

---

## 참고 파일 경로

| 항목 | 경로 |
|---|---|
| VanguardManager | `Assets/_Project/1_Scripts/Core/Managers/Vanguard/VanguardManager.cs` |
| VanguardSeasonService | `Assets/_Project/1_Scripts/Core/Managers/Vanguard/VanguardSeasonService.cs` |
| CardManager | `Assets/_Project/1_Scripts/Core/Managers/CardManager.cs` |
| CardDataSO / CardDataData | `Assets/_Project/1_Scripts/SOs/SO/DataSheet/CardDataSO.cs` / `SOs/Class/DataSheet/CardDataData.cs` |
| ECardType (Spawn/Common/Chain/Promotion/Combo) | `Assets/_Project/1_Scripts/Core/Enums/CardTypes.cs` |
| BalanceDataManager (시트 캐시) | `Assets/_Project/1_Scripts/Core/Managers/BalanceDataManager.cs` |
| VanguardSaveData | `Assets/_Project/1_Scripts/Core/Managers/SaveDataTypes.cs` |
| Parser 선례 | `ArkStageDataSOParser.cs` |
