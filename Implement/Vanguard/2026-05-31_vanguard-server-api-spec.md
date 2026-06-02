# Project Ember Vanguard — 서버 API 명세 (2026-05-31, rev2)

> 상위: [[2026-05-29_vanguard-implementation-plan-overview]]
> rev2 변경점: **리더보드 랭크 보상 "자격 컷(minTier/minPoints)" 정산 로직 추가** (§2-6, §3, §6-3, §9, §10).
> 보상 테이블의 서버/클라 소스 관계 명확화 — **서버는 클라 SO를 참조하지 않는다.**

---

## 0. 한 장 요약 (TL;DR)

Vanguard는 실시간 대전이 아니라 **주간 비동기 PvP 랭킹 이벤트**다.

```
1) 플레이어는 서버에서 "상대의 스냅샷(클론)"을 받아온다 (getOtherGamerData 패턴)
2) 클라에서 그 클론을 고스트로 재생하며 자기 전투를 플레이
3) 결과(점수)를 서버에 제출 → 서버가 승패·포인트·티어를 계산·저장
4) 내 전투 기록은 "다음 사람의 클론"으로 서버에 저장된다
```

→ 실시간 소켓 불필요. **전부 REST(요청/응답)로 처리.** 기존 `/gameData/getOtherGamerData`(랭킹 프로필 스냅샷), `/ark/enter`(시즌), `/raceTower/clear`(결과 제출) 패턴의 조합/확장이다.

**서버가 책임지는 것(권위)**: 점수·티어·랭킹 계산, 매칭, 보상 지급(+자격 컷 판정), 시즌 리셋, 재화 잔량, 치팅 검증.
**클라가 책임지는 것**: 전투 실행, 결과 보고, 화면 표시용 캐시.

---

## 1. 통신 규약 (공통)

### 1-1. 프로토콜
- **REST over HTTPS**, JSON 바디. (기존 클라가 BestHTTP로 암호화/재시도/재로그인 처리)
- 인증: 기존 게임 세션 토큰(gamerId 식별). Vanguard 전용 인증 없음.

### 1-2. 응답 봉투 — 모든 응답 동일 구조 `ServerResponse<T>`
```jsonc
{
  "code": 0,              // 0 = 성공, 그 외 = 에러 코드
  "hasError": false,      // 에러 여부 (클라가 가장 먼저 체크)
  "message": "",          // 에러 메시지(있으면)
  "data": { ... }         // 실제 페이로드 (API마다 T가 다름)
}
```
> 클라는 `hasError` 확인 후 `data`를 사용. 이 봉투는 전 컨텐츠 공통이므로 Vanguard도 그대로 따른다.

### 1-3. 공통 에러 코드 (기존 컨벤션 참고 — 서버와 합의)
| code | 의미 | 클라 처리 |
|---|---|---|
| 0 | 성공 | data 사용 |
| 6000 | 점검 중 | 점검 팝업 |
| 6001 | 집계/정산 중 | 토스트 후 차단 |
| 4xx | 잘못된 요청/검증 실패 | 에러 토스트 |
| 401 | 세션 만료 | 재로그인 |

> Vanguard 전용 에러(예: 매칭 실패, 토큰 부족)도 code로 구분할지 메시지로 구분할지 합의 필요.

---

## 2. 서버 데이터 모델 (저장해야 할 것)

문서/컬렉션 단위로 정리(MongoDB류 가정). **이름은 합의 후 확정.**

### 2-1. `VanguardSeason` — 시즌 정의 (운영/차팅이 주입)
```jsonc
{
  "seasonId": "2026-W23",
  "startDate": "2026-06-02T00:00:00.000Z",   // ISO8601 UTC
  "endDate":   "2026-06-03T24:00:00.000Z",
  "weeklyTurretIds": [101,102,...],          // 그 주차 9종 터렛
  "enemyPool": { "regular": [...], "elite": [...] },  // 적 풀 (전 플레이어 동일)
  "cardSets": [ { "round": 1, "cardIds": [...] }, ... ], // 라운드별 고정 카드 세트
  "rewardTableId": "vanguard-rank-reward-v1"  // → §2-6 보상 테이블 참조
}
```
> 핵심: **터렛/적/카드 세트는 전 플레이어 공유 고정값**(위키 규칙). 클라가 임의 생성하지 않고 서버가 내려준다.

### 2-2. `VanguardPlayer` — 플레이어별 시즌 상태 (서버 권위)
```jsonc
{
  "gamerId": "...",
  "seasonId": "2026-W23",
  "score": 1840,                 // ★ 서버만 갱신
  "tier": 303,                   // ★ score에서 파생 (enum 정수)
  "currencies": {                // ★ 서버 권위 재화
    "standardDS": 0, "specialDS": 0,
    "standardKey": 0, "specialKey": 0,
    "dualToken": 0, "emberMark": 0
  },
  "dualTokenChargeAt": "...",    // 다음 토큰 충전 시각 (4h 룰)
  "extraRewardCount": 10,        // Match용 (1h당 +1, 최대 10)
  "extraRewardChargeAt": "...",
  "chipInventory": [...],        // ★ 시즌 칩 (영구칩과 분리)
  "chestPityCount": { "standard": 0, "special": 0 }, // 50회 천장 카운트
  "fortressLevel": 0,
  "loadout": { "turretSlots": [...], "chips": {...} },
  "lastSeasonSettlement": { ... } | null  // 이전 시즌 보상(미수령 시) — §6-3에서 산출
}
```

### 2-3. `VanguardClone` — 매칭용 스냅샷 (★ 비동기 PvP 핵심)
```jsonc
{
  "gamerId": "...",
  "seasonId": "2026-W23",
  "tier": 303,
  "score": 1840,
  "nickname": "...", "profileIcon": 5, "profileBorder": 2,
  "atk": 12000,
  "chipCount": 7,
  "loadout": { "turretSlots": [...], "chips": {...} },  // 고스트 비주얼용
  "replay": {                                            // 고스트 재생용
    "matchSeed": 123456,
    "fortressHpCurve": [[t,hp],...],
    "aliveCountCurve": [[t,count],...],
    "finalResult": { "survivalTime": 95.2, "hpRemaining": 3200, "score": 1840 }
  },
  "updatedAt": "..."
}
```
> **결과 제출 시 갱신**된다. 다른 플레이어가 이 문서를 fetch해 상대로 삼는다. (= `getOtherGamerData` 패턴의 Vanguard 버전)

### 2-4. `VanguardMatch` — 멱등성/검증용 (선택이지만 권장)
```jsonc
{
  "matchId": "uuid",
  "gamerId": "...", "opponentGamerId": "...",
  "mode": "MATCH" | "DUEL",
  "status": "PENDING" | "RESOLVED",
  "createdAt": "...", "resolvedAt": "..."
}
```
> `matchId`로 **같은 결과 제출이 두 번 와도 한 번만 처리**(멱등성). 네트워크 끊김 대비 필수.

### 2-5. 봇 클론 시드 (시즌 초기 매칭 공백 방지)
시즌 첫날 `VanguardClone` 풀이 비어 있으면 매칭 불가. **티어별 난이도 더미 클론**을 시즌 시작 시 서버가 미리 주입. (기획이 더미 빌드/리플레이 제공)

### 2-6. `VanguardRewardTable` — 리더보드 랭크 보상 테이블 (★ 서버 권위, 시트 export)
```jsonc
{
  "rewardTableId": "vanguard-rank-reward-v1",
  "rows": [
    // rank=구간 시작순위. 구간 끝은 다음 행 rank-1. 마지막 행은 무한(401-).
    // currencies 키는 서버 재화명. medalId=7일 유효 메달(프로필 프레임) id.
    // minTier=(EVanguardTier 정수) 최소 티어 컷(0=없음). minPoints=최소 점수 컷(0=없음).
    { "rank": 1,   "currencies": {"emberMark":40,"etchingSolvent":200,"diamond":2000,"gold":20000}, "medalId":4, "minTier":0,   "minPoints":50 },
    { "rank": 2,   "currencies": {"emberMark":36,"etchingSolvent":190,"diamond":1900,"gold":19000}, "medalId":3, "minTier":0,   "minPoints":50 },
    { "rank": 6,   "currencies": {"emberMark":20,"etchingSolvent":120,"diamond":1200,"gold":12000}, "medalId":3, "minTier":0,   "minPoints":50 },
    { "rank": 11,  "currencies": {"emberMark":15,"etchingSolvent":100,"diamond":1000,"gold":10000}, "medalId":2, "minTier":0,   "minPoints":35 },
    { "rank": 21,  "currencies": {"emberMark":10,"etchingSolvent":60, "diamond":600, "gold":6000},  "medalId":1, "minTier":0,   "minPoints":25 },
    { "rank": 51,  "currencies": {"emberMark":5, "etchingSolvent":40, "diamond":400, "gold":4000},  "medalId":0, "minTier":0,   "minPoints":5  },
    { "rank": 101, "currencies": {"etchingSolvent":20,"diamond":200,"gold":2000},                   "medalId":0, "minTier":504, "minPoints":0  }, // Diamond2
    { "rank": 201, "currencies": {"diamond":100,"gold":1000},                                       "medalId":0, "minTier":404, "minPoints":0  }, // Platinum2
    { "rank": 401, "currencies": {"gold":500},                                                      "medalId":0, "minTier":303, "minPoints":0  }  // Gold3
  ]
}
```
> ★ **이 테이블의 출처는 클라 표시용 SO와 동일한 마스터 시트지만, 서버는 클라 SO(Unity 에셋)를 직접 읽지 않는다.**
> 시트 → 서버측 export(JSON/DB) 파이프라인으로 서버가 자기 복사본을 가진다. (§3, §6-3 참고)
> minTier enum 정수: Diamond2=504, Platinum2=404, Gold3=303 (값이 클수록 상위).

---

## 3. 서버 권위 vs 클라 캐시 (치팅 방지의 핵심)

| 데이터 | 누가 진실 | 클라 |
|---|---|---|
| 점수 / 티어 / 리더보드 순위 | **서버 계산** | 표시용 캐시만 |
| 재화 잔량 (6종) | **서버** | 표시용 캐시 |
| 칩 인벤토리 / 상자 천장 카운트 | **서버** | 표시용 |
| 일일 카운터 / 토큰 충전 | **서버** | 표시용 |
| 매칭 상대(클론) | **서버 제공** | 받아서 재생 |
| 전투 실행 / 결과 산출 | 클라 실행 → **서버 검증** | 결과 보고 |
| **랭크 보상 지급 / 자격 컷 판정** | **서버 정산** | 보상 테이블 **표시용 SO만** |

> 원칙: **"클라가 보내는 모든 수치는 의심한다."** 점수는 클라가 계산해 보내되 서버가 상한/체크섬/replay로 검증. 보상·랭킹은 서버만 확정.
>
> ★ **보상 테이블 소스 주의**: 클라는 `VanguardRankingRewardSO`(Unity 에셋)로 보상 탭을 *표시*만 한다. 서버는 이 SO에 접근할 수 없으므로, 같은 마스터 시트에서 export한 **서버 자체 보상 테이블(§2-6)**로 지급·컷을 판정한다. 시트가 바뀌면 클라 SO 재생성 + 서버 export 재반영을 **함께** 해야 동기화가 유지된다.

---

## 4. 전체 API 목록

> 경로 prefix `/vanguard`. 모든 응답은 `ServerResponse<T>` 봉투. 아래는 `data`(T)만 표기.

### 4-1. `POST /vanguard/enter` — 이벤트 입장 (Ark `/ark/enter` 패턴)
**Request**: `{}` (빈 바디 — gamerId는 세션에서)
**Response data**:
```jsonc
{
  "seasonId": "2026-W23",
  "startDate": "...", "endDate": "...",
  "myTier": 303, "myScore": 1840,
  "currencies": { ... },
  "weeklyTurretIds": [...], "enemyPool": {...}, "cardSets": [...],
  "extraRewardCount": 10, "dualTokenCount": 2,
  "prevSeasonSettlement": { "rank": 12, "rewards": {...}, "medalId": 2 } | null, // §6-3 정산 결과
  "isLeaderboardUnlocked": true,   // tier >= Gold3
  "isAutoPatrolUnlocked": true     // tier >= Silver1
}
```
**서버 로직**:
1. 현재 시즌 조회. 플레이어의 `VanguardPlayer`가 없거나 `seasonId`가 바뀌었으면 → **시즌 리셋**(§7) 후 신규 생성.
2. 이전 시즌 미정산 보상 있으면 `prevSeasonSettlement`에 담아 반환(클라가 보상 팝업 표시).
3. 시즌 고정 세트(터렛/적/카드) 함께 반환.

### 4-2. `POST /vanguard/resetLastSeasonData` — 이전 시즌 보상 수령 확정
**Request**: `{}`  **Response**: `{}`
> 이전 시즌 보상 팝업을 닫은 뒤 호출. 서버는 `lastSeasonSettlement = null` 처리. **미호출 시 enter마다 보상 재지급되므로 필수.** (Ark `/ark/resetLastSeasonData`와 동일)

### 4-3. `POST /vanguard/match/find` — 매칭 (Match 모드)
**Request**: `{ "mode": "MATCH" }`
**Response data**:
```jsonc
{
  "matchId": "uuid",            // null이면 대기(아래 status)
  "status": "MATCHED" | "WAITING",
  "opponentGamerId": "...",
  "opponentClone": { ...VanguardClone... },  // 빌드 + replay
  "matchSeed": 123456
}
```
**서버 로직 (매칭)**:
1. `extraRewardCount > 0` 확인 (없으면 에러).
2. `VanguardClone` 풀에서 **내 score ± range** 안의 클론을 조회.
3. 없으면 range 확대 → 그래도 없으면 **봇 클론**으로 대체.
4. 최근 상대 반복 회피(직전 N명 제외).
5. `VanguardMatch`(PENDING) 생성 + `matchId` 발급, 클론 반환.
> 대기열이 필요하면 `WAITING` 반환 → 클라가 수 초 후 재요청(폴링). 비동기라 사실상 즉시 매칭이 정상.

### 4-4. `POST /vanguard/duel/candidates` — 듀얼 후보 3인 제시
**Request**: `{}`
**Response data**:
```jsonc
{ "candidates": [
  { "opponentGamerId":"...", "tier":303, "atk":12000, "chipCount":7, "winPoints":24 },
  ... (3개)
]}
```
> 토큰 **소모 전** 후보만 보여줌. 새로고침은 이 API 재호출.

### 4-5. `POST /vanguard/duel/confirm` — 듀얼 상대 확정 (토큰 소모)
**Request**: `{ "opponentGamerId": "..." }`
**Response data**: `{ "matchId", "opponentClone", "matchSeed" }`
**서버 로직**: `dualToken >= 1` 확인 → 1 차감 → `VanguardMatch` 생성. **상대 못 찾으면 토큰 차감하지 않음**(위키: 매칭 취소 시 토큰 미소모).

### 4-6. `POST /vanguard/result` — 결과 제출 (RaceTower `/clear` 패턴 + 멱등성)
**Request**:
```jsonc
{
  "matchId": "uuid",
  "myResult": { "survivalTime": 95.2, "fortressHpRemaining": 3200, "enemiesKilled": 40 },
  "replay": { "matchSeed":123456, "fortressHpCurve":[...], "aliveCountCurve":[...] },
  "checksum": "..."          // loadout+seed+result 해시
}
```
**Response data**:
```jsonc
{
  "win": true,
  "pointDelta": +24,
  "newScore": 1864, "newTier": 303,
  "rewards": { "standardDS": 50, ... },     // 모드별(Match/Duel)
  "tierChanged": false
}
```
**서버 로직 (핵심)**:
1. `matchId` 조회 → 이미 `RESOLVED`면 **저장된 결과 그대로 반환**(멱등성).
2. `checksum`·점수 상한 검증(이론상 불가 점수 거부).
3. 내 결과 vs 상대(클론) `finalResult` 비교 → **승패 판정**.
4. **pointDelta 계산**(서버, 상대 랭크 보정 — §6).
5. `score/tier` 갱신, 보상 지급(모드별), `VanguardMatch=RESOLVED`.
6. **내 replay로 `VanguardClone` 갱신**(다음 사람의 상대가 됨).

### 4-7. `POST /vanguard/getRank` — 리더보드 (RaceTower `/getRank` 패턴)
**Request**: `{}`
**Response data**: `{ "ranking": [{rank,nickname,tier,score}...], "myRank": 12, "myScore": 1864 }`
> Gold3 미만이면 클라에서 잠금. 서버는 tier 검증 후 반환(또는 잠금 시 빈 목록).

### 4-8. 상점/패스/순찰/요새 (기존 패턴 복제 — 상세는 아웃게임 문서)
```
POST /vanguard/chest/open   { chestType }      → { chips:[...], pityCount }   // 50회 천장 서버 관리
POST /vanguard/pass/claim   { passType, level } → { rewards }
POST /vanguard/patrol/collect {}               → { rewards }                  // 누적/Quick 계산 서버
POST /vanguard/fortress/upgrade { useSpecial } → { newLevel, cost }
POST /vanguard/loadout/save { turretSlots, chips } → {}                       // 로드아웃 저장
POST /vanguard/slot/unlock  { slotIndex }      → { unlocked, cost }           // 터렛 슬롯 해제(DS 차감)
```

---

## 5. 매칭 로직 — 상세 (서버)

```
[클라] POST /vanguard/match/find
   │
[서버] 1. extraReward/토큰 검증
       2. 후보 쿼리: VanguardClone where seasonId=현재
                     AND score BETWEEN (my-range, my+range)
                     AND gamerId NOT IN (최근상대들, 본인)
       3. 후보 없음 → range 2배 확대 (최대 N회)
       4. 그래도 없음 → 봇 클론 풀에서 티어 맞춰 선택
       5. matchId 발급 + VanguardMatch(PENDING) 생성
       6. 선택된 클론 반환
   │
[클라] 클론 받아 고스트 재생 + 내 전투 → POST /vanguard/result
```

**합의 포인트**
- `range` 초기값/확대 정책 (예: ±100점 → ±300 → ±1000)
- 봇 클론 대체 임계(몇 초/몇 회 실패 후)
- 최근 상대 회피 범위(직전 몇 명)
- Match(무료)와 Duel(토큰)의 매칭 범위 차이

---

## 6. 점수 / 티어 / 랭킹 산출 — 상세 (서버 권위)

### 6-1. 점수(score) 증감 — ELO 계열 권장
```
pointDelta = base × f(opponentScore − myScore)
  - 상위 점수 상대 이기면 +많이 / 하위 상대에 지면 −많이
  - Duel 승리: pointDelta × 2 (위키)
```
> 정확한 공식/가중치는 **밸런싱 미정** → 기획·서버 합의. 클라는 결과만 받아 표시.

### 6-2. 티어(tier) — score 임계값에서 파생
```
score 구간 → tier (Bronze5 ... Diamond1 → Ultimate)
티어 enum 정수: 값이 클수록 높은 랭크 (Bronze5=101 ... Ultimate=601)
해금: Silver1(205) → Auto-Patrol / Gold3(303) → Leaderboard
```
> 티어 사다리: **Bronze→Silver→Gold→Platinum→Diamond→Ultimate**. Bronze~Diamond 각 5디비전, Ultimate 단일 최상위. 구간 임계값은 기획 확정.

### 6-3. 리더보드 — score 정렬 + 보상 + 자격 컷 (★ rev2 보강)
- **정렬**: score desc → 각 플레이어 `rank` 부여.
- **보상 테이블**: 구간별 4종 재화(Ember Mark / Etching Solvent / Diamond / Gold) + 7일 유효 메달, 401위까지. 출처는 §2-6 `VanguardRewardTable`(시트 export, **서버 권위**).
- **★ 자격 컷(eligibility)**: 순위 구간에 들어도 컷 미달이면 그 구간 보상 대상이 아니다.
  - **1~100위 구간 → 최소 점수 컷 `minPoints`** (1-10=50, 11-20=35, 21-50=25, 51-100=5)
  - **101위~ 구간 → 최소 티어 컷 `minTier`** (101-200=Diamond2, 201-400=Platinum2, 401+=Gold3)
  - 위키 구조상 한 구간은 둘 중 하나만 가짐(점수 컷 ⊕ 티어 컷).

**시즌 종료 정산 알고리즘(서버):**
```
1. score desc 정렬 → 각 플레이어 rank 부여
2. rank 로 보상 구간 결정 (rewardTable에서 rank가 속한 구간: row.rank ≤ rank < 다음 row.rank)
3. 컷 검사 (그 구간에 설정된 컷만):
     - 점수 컷 구간: score >= row.minPoints
     - 티어 컷 구간: tier  >= row.minTier
4. 통과 → 구간 보상 확정
   미달 → (정책 미정, §10) ⓐ 자격 되는 하위 구간으로 강등 지급  또는  ⓑ 미지급
5. 확정 보상을 VanguardPlayer.lastSeasonSettlement 에 저장 (7일 유효 메달 포함)
   → 다음 enter 시 prevSeasonSettlement 로 반환, resetLastSeasonData 로 수령 확정
```
> 클라는 이 컷을 계산하지 않는다. 보상 탭(`VanguardRankingRewardSO`)은 테이블 *표시*만, 실제 지급/자격 판정은 전부 서버. **서버는 클라 SO가 아니라 §2-6 서버 보상 테이블을 사용한다.**

---

## 7. 시즌 리셋 로직 — 상세 (Ark `ArkSeasonService` 패턴)

```
enter 시:
  서버 현재 seasonId vs VanguardPlayer.seasonId 비교
  다르면 (= 새 시즌):
    1. 이전 시즌 최종 순위/보상 산출(§6-3 정산) → lastSeasonSettlement 에 저장
    2. score=0, tier=초기, 시즌 재화/칩인벤토리/천장카운트/일일카운터 리셋
    3. 영구 보존: Ember Mark(영구 재화)는 유지
    4. VanguardPlayer.seasonId = 새 시즌
```
**합의 포인트**
- 리셋 시점: `enter` lazy 리셋 vs 시즌 전환 시 배치
- 무엇이 리셋/무엇이 영구인지 확정 (Ember Mark만 영구, 나머지 시즌)
- 시즌 종료~다음 시즌 시작 사이 정산 윈도우(집계 중 code 6001)

---

## 8. 멱등성 / 치팅 방지 — 상세

| 위협 | 방어 |
|---|---|
| 결과 중복 제출(네트워크 끊김) | `matchId` 멱등 — RESOLVED면 저장값 반환 |
| 점수 조작 | 서버 상한 검증 + checksum(loadout+seed+result) + replay 보관 후 사후 감사 |
| 재화/칩 조작 | 재화·칩·천장 전부 서버 권위 (클라 제출 무시) |
| 매칭 어뷰징(약한 상대 반복) | 최근 상대 회피 + score 기반 매칭 |
| 랭크 조작 보상 파밍(일부러 랭크 내려 보상) | **자격 컷(minPoints/minTier)** 으로 무위/저활동 보상 차단 (§6-3) |
| replay 위조 | replay 곡선 단조성/상한 검증 (선택), 의심 계정 재시뮬 |

> 완전 서버 시뮬(서버가 전투 재현)은 비용 큼 → v1은 "상한+체크섬+보관" 수준. 서버와 검증 강도 합의.

---

## 9. 서버 프로그래머 합의 체크리스트

- [ ] 응답 봉투 `ServerResponse<T>` + Vanguard 에러 코드 표
- [ ] 데이터 모델 5종(Season/Player/Clone/Match/**RewardTable**) 컬렉션명·필드 확정
- [ ] **클론 풀 구현**: `VanguardClone` 저장(결과 제출 시)·조회(매칭 시) — `getOtherGamerData` 재사용 여부
- [ ] **봇 클론 시드** 주입 방식(시즌 시작 시 더미 클론) — 기획이 빌드/replay 제공
- [ ] 매칭 range/확대/봇대체/최근상대회피 정책
- [ ] pointDelta 공식 + 티어 score 임계값 (기획 협의)
- [ ] `matchId` 멱등성 + 점수 검증 강도(상한/체크섬/replay)
- [ ] 시즌 리셋 시점·리셋/영구 항목·정산 윈도우
- [ ] 천장(50회)·일일카운터·토큰충전(4h)·ExtraReward(1h) **서버 계산**
- [ ] 상점/패스/순찰/요새/슬롯해제 API 재화 차감 검증
- [ ] **리더보드 보상 테이블 소스** = 클라 SO와 동일 마스터 시트의 서버측 export 확정 (서버는 SO 미참조)
- [ ] **리더보드 자격 컷(minPoints/minTier) 정산 적용** + 컷 미달 시 강등 지급 / 미지급 정책 확정

---

## 10. 미확정 (기획/밸런싱 대기)

- 점수 산출식 가중치, 티어 score 임계값, pointDelta 공식
- 매칭 범위 수치, 봇 클론 더미 빌드 세트
- 상자 확률 최종/천장 보상, 패스 레벨별 보상 테이블
- **리더보드 자격 컷 미달 시 처리**: 자격 되는 하위 구간으로 **강등 지급** vs **아예 미지급** (정책 미정)
- **`minPoints` 임계값 확정**(위키 "x50/x35/x25/x5"가 점수 컷인지 최종 확인) / 점수 컷 비교 기준(시즌 누적 score vs 디비전 내 점수)
- **`minTier` 임계값**(101-200=Diamond2 / 201-400=Platinum2 / 401+=Gold3) 확정
- **Etching Solvent → 서버/클라 재화 매핑 확정** (클라 임시: RefineCurrency)
- (전제 확인) 위키 미기재 "실시간 적 전송" 메커니즘 — 있으면 비동기 모델 재검토 (overview 참조)

---

## 부록 A. 클라이언트 호출 패턴 (참고 — 서버는 몰라도 됨)

기존 `BaseServerService` 재사용. 클라는 이렇게 호출한다(서버 입장에선 그냥 REST):
```csharp
var req = new JObject { ["mode"] = "MATCH" };
var res = await RequestApiAsync<ServerResponse<VanguardMatchResponse>>("/vanguard/match/find", req);
if (res.hasError) { /* 에러 처리 */ }
else { var clone = res.data.opponentClone; /* 고스트 재생 */ }
```
→ 서버는 위 4장 Request/Response 스펙만 맞추면 된다.

## 부록 B. 클라 보상 표시 vs 서버 보상 지급 (rev2 정리)

| 구분 | 클라 | 서버 |
|---|---|---|
| 보상 테이블 형태 | `VanguardRankingRewardSO` (Unity 에셋) | §2-6 `VanguardRewardTable` (JSON/DB) |
| 용도 | 보상 탭 **표시 전용** | **지급·자격 컷 판정** |
| `minTier`/`minPoints` | 보유하되 UI 미표시·로직 미사용 | 정산에서 실제 사용 |
| 데이터 출처 | 마스터 시트 → 생성기 | **동일 마스터 시트 → 서버 export** (클라 SO 미참조) |
| 동기화 | 시트 변경 시 SO 재생성 | 시트 변경 시 export 재반영 |
