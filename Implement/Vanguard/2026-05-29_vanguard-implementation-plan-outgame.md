# Project Ember Vanguard 구현 계획 - 아웃게임 (2026-05-29)

> 상위 문서: [[2026-05-29_vanguard-implementation-plan-overview]]
> 짝 문서: [[2026-05-29_vanguard-implementation-plan-ingame]]

아웃게임(로비/메타) 영역: 진입, 재화, 로드아웃, 상점, 패스, 칩, 랭킹, 매칭, 서버 API.

---

## 1. 이벤트 진입 / 시즌 주기

| 항목 | 값 | 비고 |
|---|---|---|
| 미리보기 가능 레벨 | 유저 Lv.45 | UI 노출만 |
| 참여 가능 레벨 | 유저 Lv.50 | 전투 진입 |
| 운영 주기 | 매주 화 00:00 ~ 수 24:00 (UTC) | 주간 시즌 |
| 성장 진행도 적용 | 다이아 등급 제외 전부 미적용 | 이벤트 내 별도 스탯 |

**구현**
- 시즌 주기 관리는 기존 `ArkSeasonService` / `EventScheduleManager` 패턴 복제.
- 시간은 `ServerTimeManager.NowUnscaled` 사용 (CLAUDE.md: `DateTime.Now` 금지).
- 진입 게이트는 `ContentUnlockManager` 연동.

---

## 2. 재화 시스템 (6종)

| 재화 | 용도 | enum 후보 |
|---|---|---|
| Standard Data Shards | 공격력 부스트, 일반 상자 개방 | `VanguardStandardDS` |
| Special Data Shards | 특수 상자 개방 | `VanguardSpecialDS` |
| Standard Key | 일반 상자 오픈 | `VanguardStandardKey` |
| Special Key | 특수 상자 오픈 | `VanguardSpecialKey` |
| Dual Token | PvP 듀얼 참여 비용 (4시간당 +1 자연충전, 위키 기준) | `VanguardDualToken` |
| Ember Mark | 영구 보상 재화 (시즌 간 유지) | `VanguardEmberMark` |

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

**구현**
- 주차별 9종 터렛 셋은 서버 차팅 우선 (메모리: StageData 서버 차팅 우선 원칙 동일 적용).
- 로드아웃 스냅샷은 인게임 전투/클론 녹화에서 사용 → `VanguardLoadoutSnapshot` 구조체로 직렬화.

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

- **50회 뽑기마다** 선택형 칩 보상 1회 (상자 타입별 카운트 분리).

### 5-2. 유료 구매

| 상품 | 가격 | 제한 |
|---|---|---|
| Dual Token x10 | $19.99 | 최대 4회 |
| Special Key x5 | $9.99 | 최대 2회 |
| Special Key x15 | $29.99 | 최대 2회 |
| Special DS x1,000 | $4.99 | - |
| Special DS x4,000 | $19.99 | - |
| Special DS x10,000 | $49.99 | - |

**구현**
- 상자 뽑기: 기존 `GachaManager` / `EventLuckyRollService` 패턴 복제.
- 유료 상품: 기존 `IAPManager` + `ShopService` 패턴. (CLAUDE.md: 결제는 `agent_docs/iap_system.md` 참조)
- 50회 천장 카운터는 서버 권위로 관리.

---

## 6. 패스 시스템

| 패스 | 가격 | 보상 |
|---|---|---|
| Free Pass | 무료 | Standard DS x1,200 |
| Ember Pass | 980 다이아 | Standard DS x6,000, Standard Key x13, **Lv.30 선택형 칩 1개** |
| Vanguard Pass | $9.99 | Special DS x1,500, Special Key x6, **무료 새로고침 +1**, **Lv.30 선택형 칩 1개**, **Initiative Boost** |

**Initiative Boost (Vanguard Pass 특전)**
- 매 전투에서 랜덤 라운드 1회 시작 시 카드 1장 선제 지급
- 지급 카드: Combo / T3 Chain 카드만 (인게임 문서 5장 참조)

**구현**
- 패스 진행/보상 수령: 기존 `BattlePassManager` 패턴 복제.
- 보상 수령 시 중복 지급 방지: CLAUDE.md `RewardClaimPopupUI` 패턴 준수 (팝업 클레임 시 `ModifyCurrency` 직접 호출 금지).

---

## 7. 칩 시스템

### 7-1. 신규 특수 칩 6종 (위키 2026/01/12 패치)

| # | 효과 | Rare / Epic / Legendary |
|---|---|---|
| 1 | 공격력(ATK) 증가 | +20% / +30% / +40% |
| 2 | 치명타율(Crit Rate) 증가 | +40% / +60% / +80% |
| 3 | 요새 HP 증가 | +20% / +30% / +40% |
| 4 | 요새 HP 10초마다 회복 | 4% / 6% / 8% |
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

**리더보드 보상 (Ember Mark)**

| 순위 | 보상 | 순위 | 보상 |
|---|---|---|---|
| 1 | x40 | 11~20 | x15 |
| 2 | x35 | 21~50 | x10 |
| 3 | x30 | 51~100 | x5 |
| 4~5 | x25 | | |
| 6~10 | x20 | | |

**구현**
- 리더보드 조회: 기존 `RankingService.GetArkRankingAsync()` 패턴 복제 → `GetVanguardRankingAsync()`.
- 랭킹 프로필 스냅샷: 기존 `RankingProfileSnapshotData` 패턴 재사용.

---

## 9. Auto-Patrol (자동 순찰)

| 항목 | 내용 |
|---|---|
| 해금 | Silver 1 도달 시 |
| 동작 | 일정 간격 자동 보상 수집 + Quick Patrol 즉시 수령 |
| 보상 | 현재 랭크 비례 |

**구현**
- 기존 `PatrolManager` / `ArkPatrolService` 패턴 거의 그대로 복제.

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

## 12. 아웃게임 신규 클래스

| 클래스 | 역할 |
|---|---|
| `VanguardManager : BaseManager` | 재화/로드아웃/시즌/랭크/요새업글/클론 상태 오케스트레이션 |
| `VanguardService : BaseServerService` | 위 11장 API 전부 |
| `VanguardLoadoutSnapshot` (struct/DTO) | 9터렛 선택 + 칩 + 강화레벨 직렬화 (인게임 공유) |
| `EVanguardTier`, `EVanguardMode` (enum) | 티어/모드 구분 |

**Managers.cs 등록**: 초기화 순서 확인 필요 (CardManager/ChipManager/CurrencyManager 이후).
