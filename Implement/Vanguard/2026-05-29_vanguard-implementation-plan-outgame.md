# Project Ember Vanguard 구현 계획 - 아웃게임 (2026-05-29)

> 상위 문서: [[2026-05-29_vanguard-implementation-plan-overview]]
> 짝 문서: [[2026-05-29_vanguard-implementation-plan-ingame]]

아웃게임(로비/메타) 영역: 진입, 재화, 로드아웃, 상점, 패스, 칩, 랭킹, 매칭, 서버 API.

---

## 0. 기존 컨텐츠 재사용 전략 (HordeDungeon / Ark / RaceTower 분석 결과)

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

**구현 — `ArkSeasonService` 패턴 복제 (베이스: Ark)**
- 시즌 리셋 로직은 ArkSeasonService를 거의 그대로 복제:
  ```
  enter API(/vanguard/enter) → rankingStartDate(서버) 수신
  → saveData.lastSeasonStartDate 와 비교
  → 다르면 isNewSeason=true → ResetSeasonProgress() 호출
  ```
- `ResetSeasonProgress()`에서 시즌 리셋 대상 초기화 (Vanguard 칩 인벤토리/상자 천장/일일 카운트 등 — 단, 이들은 서버 권위면 서버가 리셋).
- 시간은 `ServerTimeManager.NowUnscaled` 사용 (CLAUDE.md: `DateTime.Now` 금지).
- 진입 게이트는 `ContentUnlockManager` 연동.
- ⚠️ 메모리 주의: Ark 시즌은 금요일 시작이며 "시즌 시작 전 lastSeasonStartDate가 미래인 것은 정상, 클라 보정 금지". Vanguard도 동일 규칙 적용.

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

**구현 — `ArkGachaService`(천장/리프레시) + `RaceTowerShopService`(구매/리셋) (베이스: Ark + RaceTower)**
- 상자 뽑기 + 50회 천장: `ArkGachaService` 패턴 복제 (천장 카운트 + 리프레시 + **pending 복구**: 뽑기 도중 비정상 종료 대비 결과 캐싱/복원).
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
| 등급 구조 | Silver → Gold → Diamond (Gold/Diamond에 각 +2 티어, 위키 V0.13.5) |
| 리더보드 해금 | Gold 3 도달 시 |
| 마일스톤 정산 | 시즌 중 도달한 **최고 티어** 기준 |
| Challenge/Patrol 보상 | 현재 랭크에 비례 스케일 |
| 포인트 증감 | 상대 랭크에 따라 가변 (ELO식 보정) |

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

### 8-1. Tier Milestones 보상 `[재확인 필요]`

위키에 Tier 1/2/3 마일스톤 보상이 있으나 데이터가 뒤섞여 보임. 확인된 항목:
- **Tier 3**: Ember Mark ×2
- **Tier 1/2**: Glory Key, Diamond, Gold, Etching Solvent 등 (정확한 구간/수치 위키 재확인 필요)

> ⚠️ 마일스톤 보상의 정확한 티어 구간별 수치는 위키 표기가 불명확 → 실게임/기획 확정 필요.

**구현 — `Horde` 티어 랭킹 패턴 복제 (베이스: HordeDungeon)**
- Vanguard 티어(Silver/Gold/Diamond) 구조는 Horde의 **tier × grade 보상 매트릭스**와 가장 유사. Horde 랭킹/보상 UI를 복제:
  - `HordeRankingInfoPopup` — 현재/이전 시즌 탭, 티어 기반 표시
  - `HordeRankRewardPopupUI` + `HordeRankRewardSlot` — tier×grade 보상표
  - `HordeTierImage` / `HordeTierPromotionPanel` / `HordeTierSelectButton` — 티어 비주얼
- 리더보드 조회: `RankingService.GetArkRankingAsync()` / `GetHordeRankingAsync()` 패턴 복제 → `GetVanguardRankingAsync()`.
- 시즌 보상 수령: Horde `claimSeasonReward` API 패턴 + **중복수령 방지**(rewardStatus 영구 기록 + 서버 atomicity).
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

**구현 — `ArkPatrolService` 패턴 복제 (베이스: Ark)**
- ArkPatrolService 구조 거의 그대로:
  - 오프라인 누적 보상: `lastPatrolCheckTime`(ToBinary) + 누적 상한(Ark는 8h)
  - 충전제 Quick Patrol: `charges` + `lastChargeTime` + 충전 간격(Ark는 6h/충전, MAX 4)
- **Dual Token 4시간 충전도 동일 구조 재사용** — ArkPatrolService의 충전 로직을 토큰 충전에 적용.
- 시각은 모두 `ServerTimeManager` 기반 (오프라인 보정).

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
