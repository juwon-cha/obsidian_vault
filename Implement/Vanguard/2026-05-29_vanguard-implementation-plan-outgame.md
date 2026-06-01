# Project Ember Vanguard 구현 계획 - 아웃게임 (2026-05-29)

> 상위 문서: [[2026-05-29_vanguard-implementation-plan-overview]]
> 짝 문서: [[2026-05-29_vanguard-implementation-plan-ingame]]

아웃게임(로비/메타) 영역: 진입, 재화, 로드아웃, 상점, 패스, 칩, 랭킹, 매칭, 서버 API.

---

## 0. 기존 컨텐츠 재사용 전략 (HordeDungeon / Ark / RaceTower 분석 결과)
[2026-05-31_VanguardLobbyUI-impl-plan.md](UI/2026-05-31_VanguardLobbyUI-impl-plan.md)
WiggleDefender의 던전 컨텐츠는 모두 Galaxy Defense 던전을 거의 그대로 이식한 것이며, 아웃게임 구조가 잘 확립돼 있다. Vanguard 아웃게임은 **새로 만드는 게 아니라 세 컨텐츠의 검증된 시스템을 조합**하는 것이 핵심이다.

### 한 줄 요약

```
Vanguard 아웃게임 = RaceTower(서브서비스 골격)
                  + Ark(시즌/순찰/가챠천장/enter플로우)
                  + Horde(티어랭킹/시즌보상/전용패스)
```

### 시스템별 "어디서 가져올지" 매핑

| Vanguard 아웃게임 시스템 | 베이스 컨텐츠 | 재사용 대상 (구체 클래스) |
|---|---|---|
| **매니저+서브서비스 골격** | **RaceTower** | `RaceTowerManager` (new + `Initialize(주입)` + public 프로퍼티 노출) |
| **2단계 지연 로드** | RaceTower | `LoadSoDataAsync`(레드닷용) / `EnsureDataLoadedAsync`(입장용) |
| **차팅 데이터 로드** | RaceTower | `BalanceDataManager`(서버) → 로컬 JSON 폴백 + `*Parser.cs` 패턴 |
| **시즌 진입/리셋** | **Ark** | `ArkSeasonService` — `/ark/enter`로 `rankingStartDate` 수신 → `lastSeasonStartDate`와 비교 → `isNewSeason` → 전체 리셋. **Vanguard 주간 시즌 리셋의 정확한 템플릿** |
| **enter 진입 플로우** | Ark/Horde | enter API → 이전시즌 보상 판단 → RankRewardPopup → 수령 → 본 컨텐츠 진입 |
| **Auto-Patrol + Dual Token 충전** | **Ark** | `ArkPatrolService` — 오프라인 누적(MAX 8h) + 충전제(MAX 4, 6h/충전). Dual Token 4h 충전과 구조 동일 |
| **상자 50회 천장/리프레시** | Ark | `ArkGachaService` — 천장/리프레시 카운트/pending 복구(비정상 종료 대비) |
| **상점(확률/구매/일일주간리셋)** | RaceTower | `RaceTowerShopService` — SO 로드 + 구매한도 + Daily/Weekly 리셋 |
| **티어 랭킹 + 시즌 보상** | **Horde** | `HordeRankingService` + `HordeRankRewardPopupUI` — tier×grade 보상표, 현재/이전 시즌 탭 |
| **전용 패스(Ember/Vanguard)** | **Horde** | `HordeBattlePassUI`/`HordeBattlePassPanel` (Horde 전용 패스) + 공용 `BattlePassManager` |
| **중복 수령 방지** | Horde | rewardStatus 영구 기록(절대 리셋X) + 서버 claim API atomicity |
| **로비 진입점** | 공통 | `DungeonSlotDisplay` → `TryEnter...Async()` → enter API → UI Show |
| **레드닷** | RaceTower | 노드 트리 사전 등록 + 팝업 오픈 시점 갱신 |

### 공통 공유 인프라 (그대로 사용, 신규 구현 불필요)

```
CurrencyManager       — 재화 (ECurrencyType 6종 이미 추가됨)
SaveDataManager       — 세이브 (ESaveDataType.Vanguard만 추가)
ServerTimeManager     — 시즌/충전 타이머 (DateTime.Now 금지, NowUnscaled)
BalanceDataManager    — 서버 우선 차팅 → 로컬 JSON 폴백
ResourceManager       — SO 로드
BaseServerService     — API 베이스 (RequestApiAsync<T>)
ContentUnlockManager  — 레벨 게이트(Lv45/50)
RedDotManager         — 레드닷
BattlePassManager     — 패스 진행/보상
DungeonSlotDisplay    — 로비 던전 슬롯 진입
```

### 재사용률 평가

- RaceTower 분석 결과: **아웃게임 골격의 80%+ 구조 재사용 가능**
- 신규로 "발명"해야 하는 것은 사실상 **PvP 매칭/클론 시스템뿐** (아웃게임에선 매칭 API, 인게임에선 녹화/고스트)
- 나머지(시즌/상점/패스/랭킹/순찰/재화/세이브)는 전부 기존 패턴 복제 + 데이터 치환

### 빠르게 구현 가능한 순서 (기획 미확정 상태에서)

기획 확정 없이도 **기존 패턴 복제만으로 진행 가능한 것**과 **기획/밸런싱 대기**를 구분:

| 즉시 구현 가능 (패턴 복제) | 기획/서버 합의 대기 |
|---|---|
| Manager + 서브서비스 빈 골격 (RaceTower 복제) | 점수 산출식 가중치 |
| `VanguardSaveData` + `ESaveDataType.Vanguard` | 티어별 포인트 증감식 |
| `VanguardServerService` 골격 + 등록 | 매칭 정책(Match/Duel 범위) |
| 시즌 진입/리셋 로직 (ArkSeasonService 복제) | 주차별 9터렛/적 풀 |
| enter 플로우 + 로비 진입점 (Horde/Ark 복제) | 상자 확률 최종 밸런스 |
| 상점/순찰/패스 골격 (구조만, 데이터는 placeholder) | 봇 클론 더미 빌드 |

> **결론**: 기획이 안 나와도 "골격 + 시즌/진입/세이브/서버연동"까지는 기존 패턴 복제로 빠르게 진행 가능. 데이터/밸런싱이 필요한 부분만 placeholder로 비워두고 나중에 채운다.

---

## 1. 이벤트 진입 / 시즌 주기

| 항목 | 값 | 비고 |
|---|---|---|
| 미리보기 가능 레벨 | 유저 Lv.45 | UI 노출만 |
| 참여 가능 레벨 | 유저 Lv.50 | 전투 진입 |
| 운영 주기 | 매주 화 00:00 ~ 수 24:00 (UTC) | 주간 시즌 |
| 성장 진행도 적용 | 다이아 등급 제외 전부 미적용 | 이벤트 내 별도 스탯 |

**구현 — `ArkSeasonService` 패턴 복제 (베이스: Ark, `ArkServices/ArkSeasonService.cs`)**
- 시즌 리셋 로직은 ArkSeasonService를 거의 그대로 복제. **코드 확인된 정확한 흐름** (`EnterArkSeasonAsync():58`):
  ```
  await serverManager.EnterArkAsync()  → /ark/enter (빈 JObject body)
  → response.data.seasonData.rankingStartDate (string, ISO8601 "2025-12-05T00:00:00.000Z")
  → saveData.lastSeasonStartDate (string) 와 비교
  → 다르면 isNewSeason=true → ResetSeasonProgress(saveData, newStart) 호출
  ```
- ⚠️ **비교는 문자열 동등이 아니라 DateTime 파싱 후 비교**(`ArkSeasonService:118-145`): `DateTime.TryParse(.., InvariantCulture, DateTimeStyles.RoundtripKind, out ..)` 로 ms 포맷 차이 무시, 파싱 실패 시에만 문자열 fallback. → `lastSeasonStartDate`/`rankingStartDate`는 **`ToBinary`가 아니라 ISO 문자열**로 저장. 세이브 필드 `ArkSaveDataType.lastSeasonStartDate`(`SaveDataTypes.cs:266`)와 동형으로 `VanguardSaveData`에 추가.
- 리셋 전 이전 시즌 보상 표시용으로 `prevSeasonMaxClearedStage = maxClearedStage` 보존(`:152`).
- `ResetSeasonProgress()`(`:205-298`)가 시즌 리셋 대상 전부 초기화(재화/스탯/카드/유닛슬롯/상점기록 + **순찰 필드** `lastPatrolCheckTime=0`/`fastPatrolCharges=0` + 가챠 리프레시 카운트). Vanguard도 칩 인벤토리/상자 카운트/일일 카운트를 여기서 초기화 — **단 서버 권위 항목은 서버가 리셋**(클라는 캐시만).
- 이전 시즌 보상 수령 후 **반드시** `/vanguard/...resetLastSeasonData` 류 호출 필요(미호출 시 `enter`마다 보상 재지급. Ark는 `ResetArkLastSeasonDataAsync()` → `/ark/resetLastSeasonData`, `ArkService.cs:60-62` 주석).
- 시간은 `ServerTimeManager.NowUnscaled` 사용 (CLAUDE.md: `DateTime.Now` 금지). ⚠️ ArkSeasonService 자체는 시간매니저를 안 쓰고 **서버 `rankingStartDate` 문자열만 신뢰** — 클라 날짜 보정 코드가 전혀 없음.
- 진입 게이트는 `ContentUnlockManager` 연동(아래 11-2장 편집 타깃 참조).
- ⚠️ 메모리 주의: Ark 시즌은 금요일 시작이며 "시즌 시작 전 lastSeasonStartDate가 미래인 것은 정상, 클라 보정 금지". Vanguard도 동일 규칙 적용. enter 오케스트레이션은 매니저가 아니라 **로비 UI**(`ArkLobbyUI.SetupAsync():218-346`)에서: ServerLoadingPopup → enter → 이전시즌 보상 판단 → ResultPanel → claim → 본 컨텐츠.

---

## 2. 재화 시스템 (6종)

| 재화 | 용도 (위키 정확) | enum 후보 |
|---|---|---|
| Standard Data Shards | **GTS(요새) 공격 강화 + 터렛/칩 슬롯 해제 + Standard Ember Crate 개봉** | `VanguardStandardDS` |
| Special Data Shards | 요새 공격 강화 + Special Ember Crate 개봉 | `VanguardSpecialDS` |
| Standard Key | Standard Crate 개봉 (칩 획득) | `VanguardStandardKey` |
| Special Key | Special Crate 개봉 (고급 칩) | `VanguardSpecialKey` |
| Dual Token | PvP 듀얼 참여 (4시간당 +1 자연충전). 승패 불문 Special DS 100, 승리 시 2배 포인트 + Special Key 추가 | `VanguardDualToken` |
| Ember Mark | 영구 보상 재화 (시즌 간 유지). **Ember Shop에서 희귀 아이템 교환** | `VanguardEmberMark` |

> ⚠️ Standard DS는 "터렛/칩 슬롯 해제"에도 쓰임 (3장 슬롯 비용 참조). Ember Mark는 Exchange Shop 교환 재화 (C-2 참조).

**구현**
- 기존 `CurrencyManager.ModifyCurrency()` 경로 사용. `ECurrencyType`에 6종 추가.
- ⚠️ BD↔WD enum 값 불일치 주의 (메모리: ECurrencyType는 enum 이름 기준 리맵 필수).
- Dual Token 자연충전: 서버 타임스탬프 기반 계산 (클라 타이머 신뢰 금지).

---

## 3. 터렛 로드아웃 (주간 9종)

| 항목 | 내용 |
|---|---|
| 주당 터렛 수 | 9종 (해당 주차 고정, 플레이어 선택 불가) |
| 전투 투입 | 9종 중 일부 조합 선택 |
| 운용 전략 | 시너지 3종 고정 / 매치마다 핫스왑 |
| 슬롯 잠금 | 전투 진입 후 터렛 슬롯 잠금 가능 (위키 V0.13.3) |
| 새로고침(Refresh) | Vanguard Pass 보유 시 +1, 리롤 90~100% 권장 |

### 터렛 슬롯 해제 비용 (위키)

| 슬롯 | 비용 |
|---|---|
| 1번째 | 무료 |
| 2번째 | Standard DS 80 |
| 3번째 | Standard DS 150 |
| 4번째 | Standard DS 220 |

### 칩 관리 UI (위키)

```
Bag      — 보유 칩 확인
Filter   — 터렛 타입별 칩 표시
Overview — 장착 칩 스탯 표시
Deploy   — 터렛 배치 조정
```
- 터렛 제거 시 장착돼 있던 칩은 **자동으로 Bag으로 복구** (의도된 설계).

**구현**
- 주차별 9종 터렛 셋은 서버 차팅 우선 (메모리: StageData 서버 차팅 우선 원칙 동일 적용).
- 로드아웃 스냅샷은 인게임 전투/클론 녹화에서 사용 → `VanguardLoadoutSnapshot` 구조체로 직렬화.
- 슬롯 해제 비용/상태는 서버 권위 (PvP 공정성). 칩 장착/Bag 복구 UI는 기존 칩 장착 UI 패턴 재사용.

---

## 4. 요새 공격(Fortress Attack) 업그레이드

| 항목 | 값 (위키) |
|---|---|
| 업그레이드 재화 | Standard DS & Special DS |
| Standard DS 비용 | 50부터 시작, 업그레이드마다 +10 |
| Special DS 비용 | 항상 100 |
| 레벨업당 효과 | Attack +20, Glorious Guardians Heart +50 |

**구현**
- 전투력 가산은 인게임 `DamageCalculationManager.BaseAttackPower` 체인에 Vanguard 보너스로 합류 (상세는 인게임 문서).
- 아웃게임에선 업그레이드 레벨/비용 상태 관리만 담당 (`VanguardManager`).

---

## 5. 상점 (Ember Shop)

### 5-1. 상자 확률

**일반 상자 (Standard Chest)**

| 등급 | 확률 |
|---|---|
| Rare | 49% |
| Epic | 30% |
| Legendary | 15% |
| Supreme | 5% |
| Ultimate | 1% |

**특수 상자 (Special Chest)**

| 등급 | 확률 |
|---|---|
| Legendary | 55% |
| Supreme | 30% |
| Ultimate | 15% |

**칩 획득 개수 확률 (1회 개봉 시, 위키)**

| 획득 개수 | 1개 | 2개 | 3개 | 4개 | 5개 |
|---|---|---|---|---|---|
| 확률 | 45% | 30% | 15% | 8% | 2% |

- **50회 뽑기마다** 선택형 칩 보상 1회 (상자 타입별 카운트 분리).

### 5-2. 유료 구매

| 상품 | 가격 | 제한 |
|---|---|---|
| Dual Token x10 | $19.99 | 최대 4회 |
| Special Key x5 | $9.99 | 최대 2회 |
| Special Key x15 | $29.99 | 최대 2회 |
| Special DS x1,000 | $4.99 | 최대 2회 |
| Special DS x4,000 | $19.99 | 최대 2회 |
| Special DS x10,000 | $49.99 | 무제한 |

**구현 — `ArkGachaService`(가중치뽑기/리프레시) + `RaceTowerShopService`(구매/리셋) (베이스: Ark + RaceTower)**
- ⚠️ **코드 확인 정정**: `ArkGachaService`에는 **50회 천장(pity)이 없다**. Ark는 등급별 가중치 픽(`commonWeight/chainWeight/...`) + 소진 등급 드롭아웃 + 중복 폴백 방식이며, "천장"에 해당하는 건 리프레시 횟수 기반 **비용 증가**(`cost + refreshCount * increasePerUse`, `ArkGachaService.GetGachaCost():671`)뿐이다.
  → 따라서 Vanguard의 "50회마다 선택형 칩"은 **신규 카운터로 직접 구현**한다 (상자 타입별 분리). PvP 보상이라 **서버 권위**(클라 저장 금지).
- 상자 뽑기 도중 비정상 종료 대비 **pending 복구**는 Ark에 실제로 존재하나, **`ArkGachaService`가 아니라 `ArkManager`** 에 있다: `SetPendingGacha()`/`TryGetPendingGacha()`/`ClearPendingGacha()` (`ArkManager.cs:2012/2037/2081`) + 세이브 필드 `hasPendingGacha`/`pendingGachaResults`/`pendingGachaTimestamp` (`SaveDataTypes.cs:260`). 결과 화면 진입 전 캐시 → 로비 재진입 시 복원 → 소비 후 클리어. 이 3종 패턴을 `VanguardManager`로 복제.
- 교환상점(구매한도/일일·주간 리셋): `RaceTowerShopService` 패턴 복제 (SO 로드 + `purchaseLimit` + Daily/Weekly 리셋 시각).
- 유료 상품: 기존 `IAPManager` + `ShopService` 패턴. (CLAUDE.md: 결제는 `agent_docs/iap_system.md` 참조)
- ⚠️ 50회 천장 카운터는 **서버 권위**로 관리 (PvP 보상이라 클라 위변조 시 부정 획득). Ark는 클라 저장이지만 Vanguard는 서버.

### 5-3. Ember Exchange Shop (정식 기능 — 1차 스코프 포함)

최신 위키 기준 Ember Exchange Shop은 **이미 구현·운영 중인 정식 기능**이다 (패치노트에 새로고침 타이머 수정 항목 존재).
- **Ember Mark로 희귀 아이템을 교환**하는 상점.
- 새로고침 타이머 보유 (주기적 상품 갱신) → `RaceTowerShopService`의 Daily/Weekly 리셋 + Ark 이벤트 상점 패턴 조합.
- 교환 품목 리스트(가격/재고)는 차팅 데이터로 관리 (기획 데이터 입력 대기).

---

## 6. 패스 시스템

| 패스 | 가격 | 보상 (최신 위키 기준) |
|---|---|---|
| Free Pass | 무료 | Standard DS x1,200 |
| Ember Pass | 980 다이아 | Standard DS x6,000, Standard Key x13, **Lv.30 선택형 칩 1개**, **Initiative Boost** |
| Vanguard Pass | $9.99 | Special DS x1,500, Special Key x6, **칩 추출 시 추가 무료 리프레시**, **Lv.30 선택형 칩 1개** |

**Initiative Boost (Ember Pass 특전)**
- 라운드 시작 시 무작위 활성화 카드 1장 획득 (지급 카드: Combo / T3 Chain — 인게임 문서 5장 참조)

**Vanguard Pass 특전**
- 칩 추출(상자 개봉) 시 추가 무료 리프레시 제공 (force reroll 폭 확대)

**구현 — `Horde 전용 패스` UI + 공용 `BattlePassManager` (베이스: HordeDungeon)**
- Horde가 이미 컨텐츠 전용 패스 UI를 보유: `HordeBattlePassUI` / `HordeBattlePassPanel`. 이를 복제해 `VanguardPassUI` 구성.
- 패스 진행/보상 수령 백엔드: 공용 `BattlePassManager` 패턴 복제.
- Ember Pass / Vanguard Pass 2종 트랙 → Horde 배틀패스의 무료/유료 트랙 구조 차용.
- 보상 수령 시 중복 지급 방지: CLAUDE.md `RewardClaimPopupUI` 패턴 준수 (팝업 클레임 시 `ModifyCurrency` 직접 호출 금지).

---

## 7. 칩 시스템

### 7-1. 신규 특수 칩 6종 (위키 2026/01/12 패치)

| # | 효과 | Rare / Epic / Legendary |
|---|---|---|
| 1 | 공격력(ATK) 증가 | +20% / +30% / +40% |
| 2 | 치명타율(Crit Rate) 증가 | +40% / +60% / +80% |
| 3 | 요새 HP 증가 | +20% / +30% / +40% |
| 4 | 요새 HP 10초마다 회복 (**Termination Phase 제외**) | 4% / 6% / 8% |
| 5 | 요새 70% 이하 시 전체 피해 면역 | 3s / 4.5s / 6s |
| 6 | 치명타 시 대상 최대HP % 추가피해 (최대 N배) | 4%(2x) / 6%(3x) / 8%(4x) |

> 칩 #6이 랭킹 상승의 핵심(위키). 인게임 데미지 파이프라인에 반드시 반영.

### 7-2. 칩 수집 전략 (참고)
- Rare/Epic 전부 수집 우선 → 이후 Special Key로 특수 상자 노림.

**구현**
- 기존 `ChipManager` / `ChipEffectManager` 재사용. **신규 칩 효과 enum + 데이터만 추가**하면 기존 효과 경로 탑승.
- DataSheet SO는 자동 생성이므로 직접 수정 금지 (CLAUDE.md). `{ClassName}Parser.cs`로 커스텀 처리.
- 칩 효과의 실제 데미지 적용은 인게임 문서 5장에서 다룸.

---

## 8. 랭킹 / 티어 / 리더보드

| 항목 | 내용 |
|---|---|
| 등급 구조 | **Bronze → Silver → Gold → Platinum → Diamond → Vanguard** (낮음→높음). Bronze~Diamond 각 5디비전, Vanguard 단일 최상위(디비전 없음, 리더보드 절대순위로 가름). 티어 내 디비전은 **내림차순 넘버링(1=최상위)** — 위키: "drop rank until Diamond 3 or 4". → `EVanguardTier` 참조 |
| 리더보드 해금 | Gold 3 도달 시 |
| 마일스톤 정산 | 시즌 중 도달한 **최고 티어** 기준 |
| Challenge/Patrol 보상 | 현재 랭크에 비례 스케일 |
| 포인트 증감 | 상대 랭크에 따라 가변 (ELO식 보정) |

### 8-0. 티어 시스템 전체 구조 (기획 확정 — 2026-05-31)

Vanguard 티어는 단순 순위표가 아니라 **① 인게임 난이도 조절기 + ② 방치보상 해금키 + ③ 시즌 보상 자격 증명**을 겸하는 복합 척도다.

#### (1) 티어 사다리 (낮음 → 높음)

```
Bronze → Silver → Gold → Platinum → Diamond → Vanguard
└─────────── 각 5디비전 ───────────┘   └ 단일(디비전 없음) ┘
```

- **기본 티어 그룹 5종**(Bronze/Silver/Gold/Platinum/Diamond)은 각각 **5개 세부 디비전** 보유.
- **디비전 넘버링은 내림차순**: 숫자가 작을수록 상위. 예) `Diamond 5`(다이아 입구) → … → `Diamond 1`(다이아 정점) → 승급 시 `Vanguard`. (근거: 위키 전략 *"drop rank until you are in Diamond 3 or 4"* — Diamond 1이 Diamond 최상위. League식 IV→I 컨벤션과 동일.)
- 신규 진입자는 각 티어의 **가장 큰 숫자 디비전**(예 Bronze 5)에서 시작해 1까지 올린 뒤 다음 티어로 승급.
- **최상위 `Vanguard`는 단일 티어**(디비전 없음). 여기부터는 디비전이 아니라 **리더보드 절대순위**로 가린다. (위키 정점 메달이 1위 단독 `Ultimate`인 점과 일치.)
- enum: `EVanguardTier` (`Core/Enums/Vanguard/EVanguardTier.cs`). 정수값이 클수록 상위 랭크라 `(int)` 비교로 승급/강등 판정.

> ⚠️ **명명 결정 (의도적 분기)**: 원작에서 'Vanguard'는 컨텐츠 타이틀이고 정점 메달은 'Ultimate'로 보이나, WiggleDefender에서는 **최상위 티어 이름을 `Vanguard`로 확정**한다(기획 결정). 컨텐츠명과 티어명이 겹치므로, 코드/데이터에서는 `EVanguardTier.Vanguard`(티어)와 `GameModeType.Vanguard`(컨텐츠)를 문맥으로 구분.

#### (2) 승급/매칭 (ELO 상대평가)

- 디비전 승급에 **포인트** 필요. 초반 구간은 **디비전당 100포인트**(로비 UI: `Bronze 1 = 40/100`).
- 매치/듀얼 종료 후 증감 포인트는 **고정이 아니라 상대 랭크 기반 가변**: 높은 티어를 이기면 +多, 낮은 티어에게 지면 −多 (ELO식).
- **Duel 승리 시 포인트 2배** → 듀얼 후보 3명 중 확실히 이길 상대를 골라 점수 펌핑이 유효 전략.
- ⚠️ PvP라 **포인트/티어 산출은 서버 권위**. 클라는 캐시만(8장 구현 참조).

#### (3) 티어별 인게임 난이도 스케일링

- Vanguard는 본편 성장치 미적용(평등 조건)이지만, **현재 티어가 높을수록 적 HP·공격력이 강제 상승**(위키: *"Enemy HP and Attack scale with your current tier"*).
- 구현은 인게임 문서 5-1 참조(티어별 `stageHpCoefficient/atkCoefficient`를 `BuildStageData`에서 주입 → `ApplyStageAndWaveCoefficients` 자동 전파).

#### (4) 티어 달성 해금

| 달성 티어 | 해금 |
|---|---|
| **Silver 1** | Auto-Patrol(자동순찰) — 9장. 방치형 시간당 Standard DS + Standard Key |
| **Gold 3** | Leaderboard(리더보드) 메뉴 — 전체 랭킹 조회 |

#### (5) 시즌 보상 최소 티어 컷 (어뷰징 방지)

시즌 종료 시 최종 순위 보상에는 **순위별 최소 티어 조건**이 걸리며, 미달 시 해당 순위 보상 수령 불가 (위키 리더보드 표 `Minimum X` 인용):

| 순위 구간 | 최소 티어 |
|---|---|
| 101~200위 | Diamond 2 이상 |
| 201~400위 | Platinum 2 이상 |
| 401위~ | Gold 3 이상 |

> 1~100위는 명시 컷이 없으나 점수 구조상 자연히 Diamond 이상 최상위권만 진입 가능. 서버가 보상 지급 시 **최소 티어 충족 여부를 반드시 검증**(클라 신뢰 금지).

**리더보드 보상 (위키 정확 — 순위마다 4종 보상, 보상 유효기간 7일)**

| 순위 | Ember Mark | Etching Solvent | Diamond | Gold |
|---|---|---|---|---|
| 1 | 40 | 200 | 2,000 | 20,000 |
| 2 | 36 | 190 | 1,900 | 19,000 |
| 3 | 32 | 180 | 1,800 | 18,000 |
| 4 | 28 | 170 | 1,700 | 17,000 |
| 5 | 24 | 160 | 1,600 | 16,000 |
| 6~10 | 20 | 120 | 1,200 | 12,000 |
| 11~20 | 15 | 100 | 1,000 | 10,000 |
| 21~50 | 10 | 60 | 600 | 6,000 |
| 51~100 | 5 | 40 | 400 | 4,000 |
| 101~200 | - | 20 | 200 | 2,000 |
| 201~400 | - | - | 100 | 1,000 |
| 401~ | - | - | - | 500 |

> 메달(보상) 유효기간 7일. `Etching Solvent`/`Diamond`/`Gold`는 기존 공용 재화이므로 별도 enum 불필요 (Ember Mark만 Vanguard 전용).

### 8-1. Tier Milestones 보상 (위키 원문 추출 — `api.php` 경유)

⚠️ **티어 사다리(8-0)와 별개 개념**: "Tier Milestones"는 `Ember - Ranking 1/2/3` **3개 마일스톤 브래킷**의 일회성 도달 보상이다(전체 티어 디비전 보상표가 아님). 시즌 중 도달한 **최고 티어 기준 정산**. 위키 raw 테이블에서 추출한 값:

| 브래킷(이미지) | 보상(원문) |
|---|---|
| `Ranking 3` | Ember Mark ×2 |
| `Ranking 1` | Glory Key ×6, Diamond ×200, Ember Mark ×1, Glory Key ×4, Gold ×10,000, "25.00% Equal Chance" + (filler: AG Hyperion/Arc/Violet/Dawn 캐릭터) |
| `Ranking 2` | Glory Key ×2, Diamond ×150, Gold ×6,000, Etching Solvent ×20, Diamond ×100, Gold ×3,000 |

> ⚠️ 위키 테이블의 행 병합(rowspan)이 어지러워 **어느 브래킷이 어느 티어 구간에 대응하는지는 불명확**(이미지 파일명만 1/2/3). 정확한 티어 구간 매핑/수치는 실게임 확정 필요. `Glory Key`(=Glory Chest Key)는 기존 공용 재화 여부 확인 후 재화 매핑.

**구현 — `Horde` 티어 랭킹 패턴 복제 (베이스: HordeDungeon)**
- Vanguard 티어(Bronze~Diamond ×5디비전 + Vanguard 단일) 구조는 Horde의 **tier × grade 보상 매트릭스**와 가장 유사(grade 1~4 → Vanguard는 디비전 1~5로 확장). Horde 랭킹/보상 UI를 복제:
  - `HordeRankingInfoPopup` — 현재/이전 시즌 탭, 티어 기반 표시
  - `HordeRankRewardPopupUI` + `HordeRankRewardSlot` — tier×grade 보상표
  - `HordeTierImage` / `HordeTierPromotionPanel` / `HordeTierSelectButton` — 티어 비주얼
- 리더보드 조회: `RankingService.GetArkRankingAsync()` / `GetHordeRankingAsync()` 패턴 복제 → `GetVanguardRankingAsync()`.
- 시즌 보상 수령: Horde `claimSeasonReward` API 패턴 + **중복수령 방지**.
  - ⚠️ **코드 확인 정정**: Horde 시즌 보상의 중복방지에는 **클라 영구 `rewardStatus` 플래그가 없다**(이전 가정 폐기). 실제 메커니즘은 **서버 권위 atomic**:
    1. 서버가 `enter` 응답(`HordeEnterResponse.prevSeasonSettlement` = `PrevTierInfo`)에 **미수령 보상이 있을 때만** 정산 데이터를 포함.
    2. `HordeDungeonUI.HandlePostEnterAsync():1189` 가 `prevSeasonSettlement != null` 일 때만 `HordeRankRewardPopupUI` 표시.
    3. `ClaimHordeSeasonRewardAsync()`(`/infinityRanking/claimSeasonReward`)가 성공 후 서버에서 정산을 클리어 → 다음 `enter`엔 미포함 → 재지급 불가.
    4. 클라는 **서버 claim 성공 후에만** 재화 지급(`HordeRankRewardPopupUI.ClaimRewardAsync():604` → `GiveRewardsToPlayerAsync():707`), 이후 `RewardClaimPopupUI.ShowAlreadyClaimedRewards()`(표시 전용).
  - → Vanguard도 **클라 영구 플래그를 만들지 말고** 이 서버-권위 흐름을 그대로 복제. (단, BattlePass의 레벨별 `isFirst/Second/ThirdRewardClaimed`는 클라 영구 기록이 맞음 — 6장 참조.)
- 랭킹 프로필 스냅샷: 기존 `RankingProfileSnapshotData` 패턴 재사용.
- ⚠️ Vanguard는 PvP라 점수/티어가 **서버 권위**. 클라는 캐시만, 산출은 서버가 수행 (Horde보다 서버 의존 강함).

---

## 9. Auto-Patrol (자동 순찰)

| 항목 | 내용 (위키 정확) |
|---|---|
| 해금 | Silver 1 도달 시 |
| 시간당 보상 | Standard DS (티어 기반 수량) + Standard Key ×1 (최대 시간당 1개) |
| Quick-Patrol (6시간마다) | 시간당 보상의 **2배** + Standard Key ×2 |
| 보상 스케일 | 현재 티어 비례 |

**구현 — `ArkPatrolService` 패턴 복제 (베이스: Ark, `ArkServices/ArkPatrolService.cs`)**
- ArkPatrolService 구조 거의 그대로 (**코드 확인된 상수/필드**):
  - 상수(`:14-19`): `MAX_ACCUMULATION_HOURS=8`, `REWARD_INTERVAL_HOURS=1`, `MAX_FAST_PATROL_CHARGES=4`, `FAST_PATROL_CHARGE_HOURS=6`.
  - 세이브 필드(`SaveDataTypes.cs:321-324`): `long lastPatrolCheckTime`(ToBinary), `bool isPatrolInitialized`, `int fastPatrolCharges`, `long lastFastPatrolChargeTime`(ToBinary).
  - 누적 보상 계산: `GetAccumulatedTime():97`(now−FromBinary, `[0,8h]` 클램프) → `CalculateAccumulatedRewards():116`(`hourlyReward = baseAmount + GetStageBonus(...)`, ×시간) → `ClaimAccumulatedRewards():201` **나머지 보존 리셋**(정수 시간만 소비, `lastPatrolCheckTime = (now − remainder).ToBinary()`).
  - 충전제: `UpdateFastPatrolChargesInternal():436` — **정수 간격만큼 앵커 전진**(`lastChargeTime.AddHours(chargesToAdd*6)`)이라 소비할 때마다 타이머가 리셋되지 않음. `GetTimeUntilNextCharge():256`.
- **Dual Token 4시간 충전도 동일 구조 재사용** — 위 충전 로직에서 **간격 상수만 6h→4h** 로 바꾸면 됨. "정수 간격 앵커 전진" 패턴이 나머지 시간을 보존하므로 토큰 1개 소비 시 충전 타이머 리셋 안 됨. 단, full→non-full로 떨어지는 순간(`ExecuteFastPatrol():295`의 `:335-341`)에만 `lastChargeTime = now`로 재시작.
- 시각은 모두 `ServerTimeManager.NowUnscaled ?? DateTime.UtcNow` 기반 (오프라인 보정).

---

## 10. 매칭 시스템 `[설계 판단]`

전투 모델이 클론 고스트(인게임 문서 참조)이므로, 매칭은 **상대 클론(녹화+로드아웃)을 찾아주는 것**이다.

### 공정성 모델: 점수 기반 (v1)

| 모델 | 방식 | v1 |
|---|---|---|
| A. 점수 기반 | 각자 자기 시드로 플레이, 정규화 점수로 비교. 고스트는 체감용 페이스라인 | ✅ |
| B. 동일 시드 | 매치 시드 공유 + 클론 재시뮬 | 후순위 (결정성/듀얼인스턴스 필요) |

> 주간 이벤트라 동시 접속 적음 → 시드별 클론 풀 분할(B)은 매칭 공백 발생. A로 시작.

### Match 모드 (무료)
```
같은 티어 ±1 (0~10s) → 같은 티어 전체 (10~30s)
→ 인접 티어 확장 (30s~) → 봇/구버전 클론 대체
```

### Duel 모드 (Dual Token 소모)
```
[토큰 소모 전] 후보 N명 제시 → 새로고침(discard) 가능
[선택 확정 시] 토큰 소모, 상대 못 찾으면 환불
승리 시 포인트 2배 + Special Key 추가 (위키)
```

---

## 11. 서버 API (아웃게임)

기존 `BaseServerService.RequestApiAsync<T>()` 사용 → 암호화/재시도/재로그인 자동.

```
POST /vanguard/init
  → { season, myRank, score, currencies, weeklyTurrets[], loadout, fortressUpgrade }

POST /vanguard/match/find
  req: { mode: "MATCH"|"DUEL", myScore, tier }
  → { matchId, opponentClone, matchSeed }        // 즉시 매칭
  → { matchId: null, status: "WAITING" }          // 대기 → 폴링
GET  /vanguard/match/status?matchId=...
  → { status, opponentClone, matchSeed }

POST /vanguard/duel/candidates   req:{ myScore }  → { candidates[] }   // 후보 제시
POST /vanguard/duel/confirm      req:{ opponentId } → { matchId, opponentClone, matchSeed }

GET  /vanguard/leaderboard
POST /vanguard/chest/open        req:{ chestType } → { chip, pityCount }
POST /vanguard/pass/claim        req:{ passType, level } → { rewards }
POST /vanguard/patrol/collect    → { rewards }
POST /vanguard/fortress/upgrade  req:{ useSpecial } → { newLevel, cost }
```

> 결과 제출(`/vanguard/match/result`)은 전투 산출물이므로 인게임 문서에서 정의.

**서버 호출 UX (CLAUDE.md 준수)**
```csharp
var popup = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("vanguard_matching"));
try { var res = await vanguardService.RequestMatchAsync(...); }
finally { ServerLoadingPopupUI.Hide(); }
```

---

## 12. 아웃게임 신규 클래스 (RaceTower 패턴)

RaceTowerManager가 서브서비스를 조합하는 구조를 그대로 차용한다.

### 오케스트레이터 + 세이브

| 클래스 | 역할 | 대응 RaceTower |
|---|---|---|
| `VanguardManager : BaseManager` | 서브서비스 조합 루트. 세이브/시즌/선택상태 보유 | `RaceTowerManager` |
| `VanguardSaveData` | 모드 전용 세이브 데이터 객체 (Manager가 보유) | `RaceTowerSaveData` |

### 서브서비스 (POCO — BaseManager 아님, `new` + `Initialize(주입)`)

| 클래스 | 역할 | 대응 RaceTower |
|---|---|---|
| `VanguardSeasonService` | 주간 시즌 오픈/리셋 판정 | `RaceTowerWeeklyOpenService` |
| `VanguardLoadoutService` | 9터렛 로드아웃 + 요새 업그레이드 상태 | `RaceTowerStageService` |
| `VanguardChipService` | Vanguard 칩 인벤토리 (영구칩과 분리 + 시즌 리셋) | `RaceTowerCardService` |
| `VanguardShopService` | 상자 확률/천장(50회) + 유료상품 | `RaceTowerShopService` |
| `VanguardRankService` | 티어/포인트/리더보드 캐시 | `RaceTowerAchieveService` |

> 각 서브서비스는 `Initialize(VanguardSaveData saveData, CurrencyManager, SaveDataManager, ServerTimeManager ...)` 형태로 의존성 주입받고, `LoadXXXAsync()`로 데이터 지연 로드(서버 우선 → 로컬 JSON 폴백). `VanguardManager`가 `public { get; private set; }`로 노출.

### 서버 API + 공유 DTO

| 클래스 | 역할 | 대응 RaceTower |
|---|---|---|
| `VanguardServerService : BaseServerService` | 위 11장 API 전부 (Server/ 폴더) | `RaceTowerServerService` |
| `VanguardLoadoutSnapshot` (DTO) | 9터렛+칩+강화레벨 직렬화 (인게임 공유) | - |
| `EVanguardTier` / `EVanguardMode` / `EVanguardChestType` (enum) | ✅ 이미 작성 가능한 토대 | - |

### 차팅 데이터 (필요 시)

| 클래스 | 역할 | 대응 RaceTower |
|---|---|---|
| `Vanguard*DataSO` + `Vanguard*DataParser` | 상자 확률/패스보상/티어 등 차팅 | `RaceTower*DataSO` + Parser |

> DataSheet SO는 자동 생성이므로 직접 수정 금지. 커스텀 로직은 `Vanguard*DataParser.cs`로 분리 (CLAUDE.md).

### 등록 위치 (기존 파일 수정)

- **Managers.cs**: `VanguardManager` `ManagerDefinition` 추가. priority는 RaceTowerManager(341) 부근 "Lobby" 카테고리. CurrencyManager/CardManager/ChipManager 이후.
- **ServerManager.cs**: `_vanguardServerService` 필드 + `new` + `InitializeAsync` + `Cleanup` 라인 추가 (RaceTowerServerService와 동일 위치 패턴).

---

## 13. 검증된 구현 레퍼런스 (2026-05-31 코드 분석)

모든 경로 `Assets/_Project/1_Scripts/` 기준. 아래 "기존 RaceTower 라인"을 그대로 복제(mirror)하는 것이 가장 안전.

### 13-1. 신규 파일 생성 위치 (폴더 컨벤션 — RaceTower 동일)

| 클래스 | 생성 경로 |
|---|---|
| `VanguardManager` + 서브서비스 5종 | `Core/Managers/Vanguard/` |
| `Vanguard*DataParser` (래퍼/Raw) | `Core/Managers/Vanguard/VanguardUtility/` |
| `VanguardServerService` | `Core/Managers/Server/` |
| `VanguardStagePlayService` | `Core/Managers/StageServices/` (인게임 문서) |
| 데이터 POCO(`Vanguard*DataData`) | `SOs/Class/DataSheet/` |
| 로컬 폴백 SO(`Vanguard*DataSO`) | `SOs/SO/DataSheet/` (자동생성 영역 — 직접 수정 금지) |
| `VanguardSaveData` POCO | **`Core/Managers/SaveDataTypes.cs`** (RaceTowerSaveData가 `:146`에 있는 것처럼 같은 파일에 추가) |

### 13-2. 기존 파일 편집 타깃 (정확한 라인 — "RaceTower 라인 복제")

| 시스템 | 파일:라인 | 작업 |
|---|---|---|
| EContentType | `Core/Enums/ContentTypes.cs:43` | `Dungeon_Vanguard` 추가 (`Dungeon_RaceTower` 뒤) |
| 레벨 게이트 | `Core/Managers/ContentUnlockManager.cs:265` | `new ContentUnlockCondition(EContentType.Dungeon_Vanguard, 50)` 추가 (`requiredLevel>0 && requiredAttempts==0`이면 `CheckAndUnlockContentsByLevel():293`이 자동 해금). 미리보기 Lv45는 별도 처리 |
| 매니저 등록 | `Core/Managers/Managers.cs:~142` | `new ManagerDefinition(typeof(VanguardManager), 342, "Lobby", true, true)` (RaceTower 341 뒤, PushNotification 350 앞). ctor: `(Type, int priority, string category, bool autoInit=true, bool essential=true)` |
| 게임 시작 분기 | `Core/Managers/Managers.cs:1174` 직후 | RaceTower 블록(`:1163-1174`) 형식 복제 → `if (sceneManager.CurrentGameMode == GameModeType.Vanguard) { var vm = GetManager<VanguardManager>(); if (vm!=null){ await vm.StartVanguardGameAsync(stageID); return; } ... }` |
| 서버서비스 6곳 | `Core/Managers/ServerManager.cs:61, 606, 629, 657, 679, 2230-2291` | `_raceTowerServerService` 라인을 각각 복제: 필드선언 / `new` / `InitializeAsync(this)` / `Cleanup()` / `=null` / public 래퍼 region |
| 세이브 enum | `Core/Managers/SaveDataTypes.cs:74` | `Vanguard,` 추가 (`RaceTower,` 뒤) |
| Firebase 키 | `Core/Managers/SaveDataTypes.cs:138` | `public const string VANGUARD = "vanguard";` 추가 |
| 세이브 역직렬화 맵 | `Core/Managers/SaveDataManager.cs:1267` | `ESaveDataType.Vanguard => jObject.ToObject<VanguardSaveData>(_jsonSerializer),` |
| 세이브 Firebase키 맵 | `Core/Managers/SaveDataManager.cs:1196, 1281` | Vanguard↔"vanguard" 양방향 arm 추가 |
| 차팅 테이블명 | `Core/Data/BalanceTableNames.cs:113` (+ 로드 매니페스트 배열 `:~160`) | `VANGUARD_*` const 추가 (`= "VanguardXxxData"`). 시작 시 로드 필요하면 배열에도 |
| 로비 슬롯 진입 | `UI/Components/DungeonSlotDisplay.cs:55(switch), 141(reddot), 181(클릭)` | RaceTower/PunchKing arm 복제 → `SetVanguardMode()` + `CheckVanguard()` |

### 13-3. 서브서비스 주입 시그니처 (RaceTower 실측 — Initialize 인자)

```csharp
// RaceTowerManager.InitializeAsync() 실제 패턴 (:163-204)
_serverTimeManager = Managers.Instance.GetManager<ServerTimeManager>();
_saveDataManager   = Managers.Instance.GetManager<SaveDataManager>();
_currencyManager   = Managers.Instance.GetManager<CurrencyManager>();
// 생성 + 동기 의존성 주입 (데이터 로드는 분리)
ShopService = new RaceTowerShopService();
ShopService.Initialize(_saveData, _currencyManager, _saveDataManager, _serverTimeManager);
// 데이터는 이후 2단계 지연로드
```
- `RaceTowerShopService.Initialize(saveData, CurrencyManager, SaveDataManager, ServerTimeManager)` + `LoadShopDataAsync()`(balance-first→`JsonFiles/RaceTowerShopData`).
- `RaceTowerBuffService.Initialize(saveData, SaveDataManager, ServerTimeManager)` + `LoadBuffData(IEnumerable<SO>)`(매니저가 로드해 push).
- `RaceTowerAchieveService.Initialize(saveData, Func<EUnitRaceType,int>, Func<int>, CurrencyManager, SaveDataManager)` — **델리게이트 주입**.
- `RaceTowerStageService` 만 예외: `Initialize` 없이 `InitializeAsync()` 내부에서 `BalanceDataManager`/`ResourceManager` 캐시 + `UniTask.WhenAll(LoadStageDataAsync, LoadWaveDataAsync)`.

### 13-4. 2단계 지연 로드 (레드닷용 vs 입장용) — 복제 권장

`RaceTowerManager` 필드 `_soDataLoaded`/`_soLoadTcs`(phase1, 레드닷) + `_dataSosLoaded`/`_dataLoadTcs`(phase2, 입장). TCS 디둡 관용구:
```csharp
if (_xLoaded) return;
if (_xTcs != null) { await _xTcs.Task; return; }
_xTcs = new UniTaskCompletionSource();
try { /* load */ _xLoaded = true; _xTcs.TrySetResult(); }
catch (Exception ex) { _xTcs.TrySetException(ex); _xTcs = null; throw; }
```
- phase1 `LoadSoDataAsync()`: 레드닷 계산용 경량 데이터(상점/업적/주간오픈) → `RefreshRedDots()`.
- phase2 `EnsureDataLoadedAsync()`: 입장 직전 무거운 차팅(스테이지/웨이브/버프). `StartVanguardGameAsync` 진입부에서 `await EnsureDataLoadedAsync()`.

### 13-5. 차팅 로드 관용구 (모든 테이블 동일)

```csharp
var json = balanceDataManager?.LoadBalanceData(BalanceTableNames.VANGUARD_XXX);   // 서버 차팅 우선
if (string.IsNullOrEmpty(json))
    json = resourceManager.LoadResource<TextAsset>("JsonFiles/VanguardXxx")?.text;  // 로컬 폴백
var wrapper = JsonUtility.FromJson<VanguardXxxListWrapper>(json);                   // Parser.cs의 래퍼
```
> ⚠️ 메모리: 데이터 이식 시 `currencyType`/`rewardCurrencyType`는 BD↔WD enum **이름 기준 리맵 필수**. SOs/SO/DataSheet/ 직접 수정 금지 → `VanguardXxxDataParser.cs`로 분리.

### 13-6. 패스(BattlePassManager) 트랙 매핑 (실측)

- `BattlePassManager`(`:BaseManager`)는 `battlePassTypeID` 문자열로 키잉. trackIndex **0=Free, 1=유료1, 2=유료2**. → Ember/Vanguard 2종을 trackIndex 0/1(/2)에 매핑 또는 별도 typeID 2개.
- 클레임: `ClaimBattlePassReward(typeID, level, trackIndex, saveImmediately=true)` / `ClaimAllRewardsInBatch(typeID)` / `CanClaimReward(...)`. **클레임이 내부에서 직접 `ModifyCurrency` 호출** → UI는 반드시 `RewardClaimPopupUI.ShowAlreadyClaimedRewards()`(표시 전용)로 보여줘야 이중지급 방지(`ArkBattlePassPanel.cs:298` 과거 버그 주석).
- 레벨별 영구 수령기록: `BattlePassLevelRewardSaveData{ isFirst/Second/ThirdRewardClaimed }`(`SaveDataTypes.cs:1977`). **이건 클라 영구 기록이 맞음**(시즌 보상과 다름).
- UI 복제: `HordeBattlePassUI:BattlePassUI`(`_currentBattlePassTypeID="HordeBattlePass"`) + `HordeBattlePassPanel:BattlePassPanelBase`(`SecondTrackUnlockCost=>980` 젬, track2=IAP). → `VanguardPassUI`/`VanguardPassPanel`로 복제 + `GetMaxLevel`/`GetNextLevelXP`/SO캐시 분기 추가 + `VanguardBattlePassSO` 데이터.

### 13-7. 티어 랭킹(HordeRankingService) 매핑 (실측)

- `HordeRankingService`(POCO, `HordeDungeonManager`가 `new` + `RankingService` 프로퍼티 노출, `InitializeAsync()`에서 `ResourceManager.LoadAllAsync<HordeTierRewardDataSO>("ScriptableObjects/HordeTierRewardData")`).
- 보상 매트릭스 키 = `(ETierType tier, int grade)`, grade 1~4는 `rankingCutline`(1/6/21/51)에서 역산. `GetRankRewards(tier,grade)` → `Dictionary<ECurrencyType,int>`(3슬롯 합산).
- → Vanguard는 `ETierType`→`EVanguardTier`, `HordeTierRewardDataData`(`id/HordeRank/rankingCutline/currency1~3Type/rank1~3Count/rewardIconId/minClearPoint`)→`VanguardTierRewardData`로 치환.
- UI 복제: `HordeRankingInfoPopup`(Ranking/Reward 탭, 8 티어버튼×4 grade슬롯), `HordeRankRewardPopupUI`(이전시즌 정산/클레임), `HordeRankRewardSlot`, `HordeTierImage`/`HordeTierSelectButton`/`HordeTierPromotionPanel`.
- 리더보드 조회: `RankingService`(`:BaseServerService`)의 `GetHordeRankingAsync()`/`GetArkRankingAsync()` 패턴 → `GetVanguardRankingAsync()`. 프로필 스냅샷 `RankingProfileSnapshotData`(`RankingProfileDataTypes.cs:29`) 재사용.
- 시즌 타이밍 유틸 재사용: `HordeDungeonManager.GetSecondsUntilNextFriday()` → `DateTimeUtils.GetSecondsUntilNextFriday(serverTime.NowUnscaled)`.
- ⚠️ Vanguard는 PvP라 점수/티어 **서버 권위**. 클라는 캐시만.
