# Project Ember Vanguard — 기존 컨텐츠(Horde/Ark/RaceTower) 재활용 데이터 테이블 전수 분석 (2026-06-02)

> 상위: [[2026-05-29_vanguard-implementation-plan-overview]] · 관련: [[2026-05-31_vanguard-server-api-spec]]
> 목적: 위키(Project Ember: Vanguard) 기능을 WiggleDefender로 이식할 때, **Horde·Ark·RaceTower의 기존 데이터 테이블(SO/JSON) 중 재활용 가능한 것**을 하나도 빠짐없이 매핑.
> 방법: 세 컨텐츠의 `SOs/SO/DataSheet`·`SOs/Class/DataSheet`·`Resources/JsonFiles`·`Resources/ScriptableObjects` 전수 조사 + 위키 기능 대조.

---

## 0. 한 장 요약 — 재활용 매트릭스

적합도: ◎ 거의 그대로 / ○ 필드 일부 추가·키 교체 / △ 구조/패턴만 차용

| Vanguard 기능 (위키) | 최적 재활용 테이블 | 시스템 | 적합도 | 핵심 근거 |
|---|---|---|---|---|
| 리더보드 랭크 보상 | `ArkRankingData` ↔ `HordeTierRewardData` | Ark/Horde | ◎ | 이미 `VanguardRankingRewardSO`로 이식 완료 |
| 티어 마일스톤 보상(랭크 무관) | **`HordeTierRewardData`** | Horde | ◎ | `HordeRank(ETierType)+cutline+minClearPoint` 구조가 그대로 |
| 칩(Chip) 정의 | **`HordeBuffData`** / `RaceTowerBuffData` | Horde/RaceTower | ◎ | 등급별 수치(20/30/40%)=`normalValue/epicValue/specialValue` |
| Ember/Vanguard Pass(배틀패스) | **`HordeBattlePass`** / `ArkPassData` | Horde/Ark | ◎ | level+3트랙 보상+XP 구조 동일, `BattlePassManager` 공유 |
| 터렛/칩 슬롯 해제 비용 | **`ArkOptionData1`** | Ark | ◎ | `slotUnlockCost1~4` = 1st free/80/150/220 그대로 |
| Auto-Patrol(방치 보상) | `ArkPatrolData` / `RaceTowerPatrolData` | Ark/RaceTower | ○ | `patrolType(일반/쾌속)+base+increase`. stage→tier 키만 교체 |
| 상자 가챠 확률 | `ArkGachaConfigData` | Ark | ○ | 타입별 weight 분포(Rare~Ultimate) |
| 교환 상점(Ember Mark) | `RaceTowerShopData` / `ArkShopData` | RaceTower/Ark | ○ | cost/reward/limit/cycle/reqStage |
| IAP 현금 패키지 | `ArkShopData` + `ArkSkipPackageData` | Ark | ○ | productId+보상, isAd/cycle |
| 요새(Fortress) 업그레이드 | `ArkOptionData2` | Ark | ○ | `cost+increasePerUse`(50+10/레벨) 패턴 |
| 적/웨이브 정의 | `ArkStageData` / `RaceTowerStageData`+`RaceTowerWaveData` | Ark/RaceTower | ○ | hp/atk 계수+웨이브 구성, 티어 스케일 |
| 주간 터렛/카드 세트 | `RaceTowerWeeklyOpenData` + `ArkUnitBanData`/`ArkModuleBanData` | RaceTower/Ark | △ | 요일/주차별 오픈 + weight 선택 |
| 스테이지·도달 보상(초반 10전 보너스 등) | `ArkStageRewardData` / `RaceTowerAchieveData` | Ark/RaceTower | △ | reqStage→보상 1회성 |
| 티어 시스템(점수→티어) | `ETierType`+grade(HordeRankingService) | Horde | △ | 임계값은 서버. 클라 표시는 `EVanguardTier`/`VanguardTierUtil`(완료) |
| 재화 6종 표시 | `CurrencyDataSO`+`ECurrencyType` | 공유 | ◎ | Vanguard 재화 1285~1290 이미 등록 |
| 프로필 프레임/7일 메달 | `ProfileFrameRuntimeDataSO` | 공유 | ◎ | 슬롯에서 이미 사용 |

> 네가 떠올린 4개(티어/랭킹/랭킹보상/상점) 외에 **칩·배틀패스·슬롯해제·방치보상·가챠확률·요새업글·적/웨이브·주간세트·스테이지보상·프로필프레임**까지 재활용 가능. 가장 가치 큰 추가 발견은 **칩=HordeBuffData**, **배틀패스=HordeBattlePass/ArkPassData**, **슬롯해제=ArkOptionData1**.

---

## 1. 보상 — 랭킹 / 티어 마일스톤

### 1-1. 리더보드 랭크 보상 (위키 §5) — 이식 완료
- 채택: `ArkRankingDataSO` 미러 → `VanguardRankingRewardSO`(작업 완료).
- 대안/참고: **`HordeTierRewardData`** 가 사실 구조적으로 더 가깝다 — `HordeRank(ETierType)`, `rankingCutline`, `currency1~3Type/rank1~3Count`, `rewardIconId`, **`minClearPoint`**(=점수컷)까지 한 테이블에 있음. (Ark는 `minClearStage` 한 칸뿐)

### 1-2. 티어 마일스톤 보상 (위키 §4 "Current Ranking", 랭크 무관 티어 진행 보상) — ◎
- 채택: **`HordeTierRewardData`** (`HordeTierRewardDataSO` / `HordeTierRewardDataData`).
  - 경로: `Assets/Resources/ScriptableObjects/HordeTierRewardData/{0~31}.asset`, JSON `Resources/JsonFiles/HordeTierRewardData.json`
  - 필드: `id, HordeRank(ETierType), rankingCutline, currency1~3Type/rank1~3Count, rewardIconId, minClearPoint`
- 매핑: `HordeRank` → `EVanguardTier`, 나머지(통화3종+아이콘) 그대로. 랭크 무관 "티어 도달 보상"이라 cutline 미사용 가능.
- 비고: 위키 Tier Milestones는 Ark 모델과 안 맞고 **Horde 티어보상 구조가 정답**.

---

## 2. 칩 (Chip) — 위키 §6, "Chip Priority" — ◎ 최대 발견

- 채택: **`HordeBuffData`** (`HordeBuffDataSO` / `HordeBuffDataData`).
  - 경로: SO 클래스 `SOs/SO/DataSheet/HordeBuffDataSO.cs`, JSON `Resources/JsonFiles/HordeBuffData.json`
  - 필드: `buffId, buffName, buffDescription, effectType(int), weight, normalValue, epicValue, specialValue`
- 매핑 근거: 위키 칩이 **등급별 수치 스케일**을 가짐 — "ATK +20/30/40%", "Crit Rate +40/60/80%", "Fortress HP +600/800/1000/1200/1400". 이게 `normalValue/epicValue/specialValue`(+필요시 확장) 와 정확히 대응. `weight`는 상자 뽑기 가중치, `effectType`은 칩 효과 종류.
- 대안: `RaceTowerBuffData`(`buffId,buffName,buffDescription,targetUnitRace,value`) — 단일 value라 등급 스케일엔 Horde가 우위.
- 추가 필요: 칩 **rarity(Rare~Ultimate)** 컬럼, 등급이 5단계인 칩 대응(값 배열 확장).

---

## 3. 패스 — Ember Pass / Vanguard Pass (위키 Ember Pass) — ◎

- 채택: **`HordeBattlePass`** (`HordeBattlePassSO`/`HordeBattlePassData`) 또는 **`ArkPassData`**.
  - Horde 경로: `Resources/ScriptableObjects/HordeBattlePass/{1~30}.asset`, JSON `Resources/JsonFiles/HordeBattlePass.json`
  - Horde 필드: `level, firstRewardType/Value, secondRewardType/Value, thirdRewardType/Value, battlePassLevelXP` → **3트랙(무료/유료1/유료2)** 와 정확히 일치.
  - Ark 필드: `level, first/second/thirdRewardType/Value, secondSlotModuleId/thirdSlotModuleId, battlePassLevelXP`
- 공유 프레임워크: `BattlePassManager` + `agent_docs/battlepass.md`.
- 추가 필요: 위키의 **Lv30 선택형 칩 보상**(selectable chip) 표현(보상 슬롯에 "선택 칩" 타입 추가).

---

## 4. 슬롯 해제 / 비용 — 위키 §12, §8

### 4-1. 터렛·칩 슬롯 해제 비용 (위키 §12: 1st free / 2nd 80 / 3rd 150 / 4th 220 DS) — ◎
- 채택: **`ArkOptionData1`** (`ArkOptionData1SO`).
  - 경로: `Resources/ScriptableObjects/ArkOptionData1/`, JSON `Resources/JsonFiles/ArkOptionData1.json`
  - 필드: `slotUnlockCost1~4, rankUnlockCost2~3` → 칸별 해제 비용과 1:1.
- 매핑: `slotUnlockCostN` 그대로. 재화만 `VanguardStandardDS`로.

### 4-2. 요새(Fortress) 공격 업그레이드 (위키 §8: 시작 50 +10/레벨, Special 100 고정, +20 ATK/+50 HP) — ○
- 채택: **`ArkOptionData2`** (`currencyType, cost, increasePerUse`) 의 비용증가 패턴.
  - 경로: `Resources/ScriptableObjects/ArkOptionData2/`, JSON 동일.
- 추가 필요: 레벨당 효과(+ATK/+HP) 컬럼. 비용 선형증가는 `cost+increasePerUse`로 표현 가능.

---

## 5. 방치 / 매치 보상 — 위키 §11, §9

### 5-1. Auto-Patrol (위키 §11: 티어별 시간당 DS+Key, 6h Quick-Patrol 2배) — ○
- 채택: **`ArkPatrolData`** 또는 **`RaceTowerPatrolData`** (동일 구조).
  - 필드: `patrolRewardID, currencyType, patrolType(일반/쾌속), baseAmount, increaseAmount, stageIncreaseInterval`
  - 경로(Ark): `Resources/ScriptableObjects/ArkPatrolData/`, JSON `Resources/JsonFiles/ArkPatrolData.json`
- 매핑: `patrolType` = 일반/Quick(2배) 그대로. **단 Vanguard는 stage가 아니라 tier 기준 증가** → `stageIncreaseInterval`을 tier 키로 교체. Key(시간당 1, Quick 2) 보상은 두 번째 currency 행으로.
- 참고 enum: `EPatrolType` 재사용.

### 5-2. Extra Reward (위키 §9: Match당 소량 DS, 1h당 +1, 최대 10) — △
- 소량 보상이라 별도 테이블 불필요할 수 있음. 필요 시 `ArkPatrolData` 한 행 또는 상수.

---

## 6. 상점 / 가챠 — 위키 §6

### 6-1. 상자 가챠 확률 (Standard/Special, Rare~Ultimate 확률, 1~5칩 확률) — ○
- 채택: **`ArkGachaConfigData`** (`gachaTypeName + commonWeight/chainWeight/promotionWeight/comboWeight/moduleWeight`).
  - 경로: `Resources/ScriptableObjects/ArkGachaConfigData/`, JSON `Resources/JsonFiles/ArkGachaConfigData.json`
- 매핑: 타입별(Standard/Special) 등급 weight 분포. **50회 천장(pity)은 서버 관리**(데이터 아님), 확률표만 재활용.

### 6-2. 교환 상점 (Ember Mark로 교환) — ○
- 채택: **`RaceTowerShopData`** (`itemID, order, rewardCurrencyType, rewardAmount, costType, costAmount, purchaseLimit, shopCycleType, reqStage`).
  - 경로: `Resources/ScriptableObjects/RaceTowerShopData/`, JSON 동일.
- 매핑: `costType=VanguardEmberMark`. 가장 일반적인 교환상점 스키마.

### 6-3. IAP 현금 패키지 (Special Key x5/x15, DS 팩, Dual Token x10) — ○
- 채택: **`ArkShopData`** (`productId, productType, shopCycleType, rewardAmount, maxCount, isAd, adCoolTime`) + **`ArkSkipPackageData`** (`productId, reward...`).
  - 경로: JSON `Resources/JsonFiles/ArkShopData.json`, SO `ArkSkipPackageData`.
- 매핑: `productId`(스토어 상품) + 보상 재화/수량 + `maxCount`(구매 제한).

---

## 7. 전투 데이터 — 적 / 웨이브 / 주간 세트 — 위키 §3, §7, §12

### 7-1. 적 / 웨이브 (regular 6 + elite 2, 티어 스케일, 텔레포트 시 증가) — ○
- 채택: **`ArkStageData`** 또는 **`RaceTowerStageData` + `RaceTowerWaveData`**.
  - Ark 필드: `stageID, stageHpCoefficient, waveIDs, enemyScale, enemyCounts, spawnIntervals, ...`
  - RaceTower 필드: `종족별 HpCoefficient, stageAtkCoefficient, waveIDs` + Wave `enemyIDs, enemyCounts, spawnIntervals, waveHp/AtkCoefficients`
- 매핑: HP/ATK 계수로 **티어별 스케일** 표현. 웨이브 구성(정규/엘리트)은 wave 테이블.

### 7-2. 주간 터렛/카드 세트 (주차별 9종 고정) — △
- 채택: **`RaceTowerWeeklyOpenData`** (`Day, unitRaceTypeList`) 의 "요일/주기별 오픈" 패턴 + **`ArkUnitBanData`/`ArkModuleBanData`** (weight 선택)로 가용 카드 제한.
- 매핑: 주차별 `weeklyTurretIds`(서버 §2-1) 와 연동. 클라 테이블은 보조.

---

## 8. 공유 / 횡단 테이블 (특정 컨텐츠 아님)

| 항목 | 테이블 | 용도 |
|---|---|---|
| 재화 표시(아이콘/이름) | `CurrencyDataSO` + `ECurrencyType` | Vanguard 재화 6종(1285~1290) 이미 등록 — `ItemDisplayComponent.SetupItem`로 표시 |
| 프로필 프레임 / 7일 메달 | `ProfileFrameRuntimeDataSO`(`GetFrameByIndex`) | 랭크 보상 슬롯에서 이미 사용 |
| 상점 주기 | `EShopCycleType` | 일일/주간/시즌 주기 |
| 방치 타입 | `EPatrolType` | 일반/쾌속 |
| 배틀패스 진행 | `BattlePassManager` | XP/레벨/수령 공통 로직 |

---

## 9. 부록 — 세 컨텐츠 데이터 테이블 전체 인벤토리

### 9-1. Ark (13종)
스테이지 `ArkStageData` · 모듈 `ArkModuleData`/`ArkModuleBanData` · 가챠 `ArkGachaConfigData` · 상점 `ArkShopData` · 패스 `ArkPassData` · 순찰 `ArkPatrolData` · 랭킹 `ArkRankingData` · 랭킹그룹 `ArkRankingGroup` · 스테이지보상 `ArkStageRewardData` · 옵션 `ArkOptionData1`/`ArkOptionData2` · 유닛밴 `ArkUnitBanData` · 스킵패키지 `ArkSkipPackageData`
(SO+JSON 듀얼. 경로: `SOs/SO/DataSheet/*`, `Resources/JsonFiles/Ark*.json`, `Resources/ScriptableObjects/Ark*/`. 로더: `ArkDataService`)

### 9-2. Horde (5종 + 버프/세이브 래퍼)
스테이지보상 `HordeRewardData`(테마41~45×20) · 티어보상 `HordeTierRewardData`(8티어×4등급) · 레거시랭크보상 `HordeRankRewardData` · 배틀패스 `HordeBattlePass`(Lv1~30) · 버프 `HordeBuffData`(50종, normal/epic/special)
(경로: `Resources/ScriptableObjects/Horde*/`, `Resources/JsonFiles/Horde*.json`. 로더: `HordeDungeonManager`, `HordeRankingService`, `BattlePassManager`)

### 9-3. RaceTower (10종)
랭크보상 `RaceTowerRankRewardData`(구간→buffId) · 버프 `RaceTowerBuffData` · 스테이지 `RaceTowerStageData` · 웨이브 `RaceTowerWaveData` · 클리어보상 `RaceTowerRewardData` · 상점 `RaceTowerShopData` · 서버상금 `RaceTowerServerPriceData` · 업적 `RaceTowerAchieveData` · 방치 `RaceTowerPatrolData` · 주간개방 `RaceTowerWeeklyOpenData`
(SO+JSON 듀얼 + `*Parser`/`*Raw`/`*Wrapper`. 로더: `RaceTowerManager`, 우선 `BalanceDataManager` 폴백 `ResourceManager`)

---

## 10. 권장 우선순위 (이식 순서 제안)

1. **랭크 보상**(완료) → **티어 마일스톤**(`HordeTierRewardData` 미러) — 보상 화면 완성.
2. **칩**(`HordeBuffData` 미러) + **패스**(`HordeBattlePass`/`ArkPassData` 미러) — 핵심 성장/수익 루프.
3. **슬롯 해제**(`ArkOptionData1`) + **요새 업글**(`ArkOptionData2`) — 인게임 강화.
4. **가챠 확률**(`ArkGachaConfigData`) + **상점**(`RaceTowerShopData`/`ArkShopData`) — 상자/상점.
5. **Auto-Patrol**(`ArkPatrolData`) — 방치 보상.
6. **적/웨이브**(`ArkStageData`/`RaceTowerWave`) + **주간 세트** — 전투 콘텐츠.

> 모든 케이스 공통 원칙: **"상속이 아니라 미러링"** — 기존 SO를 직접 참조하지 말고 `Vanguard*` 전용 SO/시트를 복제 생성하고, 매니저/서비스만 Vanguard 쪽에 둔다. (랭크 보상 이식에서 검증된 패턴)
