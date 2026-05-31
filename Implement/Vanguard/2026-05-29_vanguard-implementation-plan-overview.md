# Project Ember Vanguard 구현 계획 - 개요 (2026-05-29)

## 문서 목적

Galaxy Defense: Fortress TD의 **Project Ember Vanguard** 컨텐츠를 WiggleDefender(MarinRPG)에 이식/구현하기 위한 계획 문서.
본 문서는 전체 개요이며, 상세 내용은 아래 두 문서로 분리한다.

- [[2026-05-29_vanguard-implementation-plan-outgame]] — 아웃게임(로비/메타) 시스템
- [[2026-05-29_vanguard-implementation-plan-ingame]] — 인게임(전투) 시스템

> **출처 주의**: 메커니즘/수치는 [Project Ember Vanguard Wiki](https://official-galaxy-defense-ftd-wiki.fandom.com/wiki/Project_Ember_Vanguard) 분석 기반.
> 일부 구현 방식(매칭/전투 모델/서버 구조)은 위키에 명시되지 않아 **설계 판단으로 보완**한 부분이며, 본문에 `[설계 판단]` 으로 표기한다.

---

## 핵심 컨셉 요약

Vanguard는 **주간 PvP 랭킹 이벤트**다. 세 가지 축으로 구성된다.

| 축 | 내용 |
|---|---|
| PvP 전투 | 9종 터렛 + 칩 빌드로 적 웨이브를 방어, 상대와 비교해 승패 결정 |
| 칩 빌드 | 상자/패스로 칩 수집, 빌드 최적화가 랭킹의 핵심 |
| 수익화 | Ember Pass / Vanguard Pass + 상자/재화 판매 |

---

## 가장 중요한 전투 모델 결정 `[설계 판단]`

실시간 PvP가 아니라 **클론 고스트 레이스(async ghost PvP)** 방식으로 구현한다.

```
상대는 "살아있는 네트워크 객체"가 아니라 "녹화된 고스트"다.
- 전투 시작 전: 상대 클론 데이터 1회 다운로드 (HTTP)
- 전투 중: 네트워크 통신 0회, 상대는 로컬 재생
- 전투 종료 후: 결과 1회 업로드 (HTTP) + 내 전투가 다음 사람의 클론이 됨
```

### 이 방식을 택하는 이유 (현재 코드 제약)

| 제약 | 클론 고스트로 회피되는가 |
|---|---|
| `Managers.Instance` 전역 싱글톤 (4,100+ 호출부) → 두 전투 인스턴스 동시 실행 불가 | ✅ 상대는 재생이라 두 번째 시뮬 불필요 |
| 적 이동 `Time.deltaTime` 기반 + float 비결정성 → Lockstep 불가 | ✅ 상대를 재현(re-sim)하지 않고 재생(replay)하므로 무관 |
| 실시간 서버 운영 부담(매칭/재연결/리전) | ✅ HTTP 요청/응답만으로 충분 |

> Photon/WebSocket 모두 **불필요**. 기존 BestHTTP 기반 `BaseServerService` 패턴으로 전부 처리 가능.

---

## 아키텍처 방향 — RaceTower 패턴 답습

코드 확인 결과 **RaceTower 모드**가 복합 컨텐츠(스테이지/상점/랭킹/주간오픈/버프)를 다루는 가장 완성된 패턴이다. Vanguard도 복합 컨텐츠이므로 RaceTower 패턴을 그대로 따른다.

> **아웃게임 재사용 전략 (HordeDungeon/Ark/RaceTower 분석 결론)**: Vanguard 아웃게임 = **RaceTower(서브서비스 골격) + Ark(시즌/순찰/가챠천장/enter) + Horde(티어랭킹/시즌보상/전용패스)** 의 조합. 아웃게임 골격의 **80%+가 기존 패턴 복제로 구현 가능**하며, 신규 발명은 **PvP 매칭/클론 시스템**뿐이다. 시스템별 베이스 컨텐츠 매핑은 [[2026-05-29_vanguard-implementation-plan-outgame]] 0장 참조.

### RaceTower 실제 구조 (확인된 사실)

```
RaceTowerManager : BaseManager        ← 오케스트레이터 (Managers.cs 등록)
  - RaceTowerSaveData _saveData        ← 모드 전용 세이브 데이터 객체
  - 서브서비스들을 new + Initialize(의존성 주입) 후 public 프로퍼티로 노출:
      StageService / CardService / ShopService /
      BuffService / AchieveService / WeeklyOpenService
  ※ 서브서비스는 BaseManager 아님. 일반 클래스 + Initialize(saveData, currencyMgr, ...)

RaceTowerServerService : BaseServerService  ← Server/ 폴더, ServerManager가 초기화
RaceTowerStagePlayService                    ← StageServices/ 폴더, StageManager가 인스턴스화
RaceTower*DataSO + *DataParser               ← SOs/, 차팅 데이터 (서버 우선 → 로컬 JSON 폴백)
UI/RaceTower/                                ← UI 일체
```

**핵심 패턴 3가지**
1. **Manager = 조합 루트**: 서브서비스를 `new` + `Initialize(주입)` 하고 `public { get; private set; }`로 노출
2. **서브서비스 = 일반 클래스**: `BaseManager`가 아니라 POCO. `_saveData` 공유 + 의존성 주입. 데이터는 `LoadXXXAsync()`로 지연 로드 (`BalanceDataManager` 서버 우선 → 로컬 JSON 폴백)
3. **전투/서버 분리**: 전투 플로우는 `StageServices/`, 서버 API는 `Server/` 폴더로 분리

### Vanguard 신규 클래스 (RaceTower 구조 매핑)

| 분류 | 클래스 | 역할 | 대응 RaceTower |
|---|---|---|---|
| **오케스트레이터** | `VanguardManager : BaseManager` | 서브서비스 조합 + 세이브/시즌/랭크 상태 | `RaceTowerManager` |
| 서브서비스(POCO) | `VanguardSeasonService` | 주간 시즌 오픈/리셋 | `RaceTowerWeeklyOpenService` |
| 서브서비스(POCO) | `VanguardShopService` | 상자/상점 (확률/천장) | `RaceTowerShopService` |
| 서브서비스(POCO) | `VanguardChipService` | Vanguard 칩 인벤토리(분리/리셋) | `RaceTowerCardService` |
| 서브서비스(POCO) | `VanguardLoadoutService` | 9터렛 로드아웃/요새 업글 | `RaceTowerStageService` |
| 서브서비스(POCO) | `VanguardRankService` | 티어/포인트/리더보드 캐시 | `RaceTowerAchieveService` |
| 서버 API | `VanguardServerService : BaseServerService` | 매칭/결과/리더보드/상자/패스 | `RaceTowerServerService` |
| 전투 플로우 | `VanguardStagePlayService` | StageManager 내부 전투 구동 | `RaceTowerStagePlayService` |
| 전투 보조(경량) | `VanguardGhostPlayer` | 상대 고스트 재생 (전투 로직 없음) | (RaceTower엔 없음, PvP 고유) |
| 전투 보조(경량) | `VanguardReplayRecorder` | 내 전투 녹화 → 클론 생성 | (RaceTower엔 없음, PvP 고유) |
| 세이브 | `VanguardSaveData` | 모드 전용 세이브 데이터 객체 | `RaceTowerSaveData` |

> RaceTower와 유일한 차이는 **PvP 클론 시스템**(`VanguardGhostPlayer` / `VanguardReplayRecorder`). 둘 다 `VanguardStagePlayService` 내부에 두므로 전체 골격은 RaceTower와 동일하다.

---

## 구현 우선순위 (마일스톤)

### 순서 원칙 — "토대 먼저, 최대 리스크를 조기에"

```
아웃게임 전부 → 인게임 전부  ❌ (지양)
  - 의존성 역행: 인게임 전투 결과(점수/replay 구조) → 아웃게임 랭킹/매칭/보상이 소비
    → 매칭·랭킹을 먼저 만들면 추측이고, 인게임 확정 시 재작업
  - 리스크 집중: 아웃게임 = 기존 패턴 복제(low-risk) / 인게임 클론고스트 = unproven(high-risk)
    → 최대 미지수를 늦게 건드리면 늦게 터진다

토대(공유) → 인게임 코어로 모델 검증 → 점수 확정 → 나머지 메타 → 매칭  ✅
```

### 마일스톤

| 단계 | 범위 | 산출물 | 비고 |
|---|---|---|---|
| **M1** | **토대 (양쪽 공유)** | `GameModeType.Vanguard`, `ECurrencyType` 6종, `VanguardManager` + `VanguardServerService` 빈 골격 + Managers/ServerManager 등록, 진입 게이트(Lv45/50) + 시즌 주기(`VanguardSeasonService`) | churn 거의 0. 무조건 먼저 (아웃게임 T0) |
| **M2** | **인게임 코어 수직슬라이스 (de-risk)** | `VanguardStagePlayService`로 싱글 전투 관통: 웨이브+카드+Berserk(60s)+Termination(120s), **가짜 고스트** | **최대 리스크 조기 검증.** 클론 모델 성립 여부 판정 |
| **M3** | 녹화/재생 검증 | `VanguardReplayRecorder` + `VanguardGhostPlayer` 최소 동작, 상대 HP/적수 미니멀 표시 | 클론 고스트가 실제로 되는지 확인 |
| **M4** | **점수 구조 확정** | 전투 결과 DTO(생존시간/잔여HP/처치수/replay) 포맷 픽스 | 아웃게임 T3의 입력이 여기서 확정됨 |
| **M5** | 나머지 아웃게임 데이터/메타 | 칩6종 데이터+전투적용, 요새 업글, 로드아웃9종, 상점, 패스, Auto-Patrol | 안정된 기반 위에서 (아웃게임 T1~T2) |
| **M6** | 매칭/랭킹/서버연동 | 매칭 API, 결과 제출, 점수/랭크 산출, 리더보드, **봇 클론 시드** | 점수 구조 확정(M4) 후 (아웃게임 T3) |
| **M7 (선택)** | 스플릿 비주얼 | 고스트 적 스프라이트 렌더 (cullingMask) | 폴리시 |

> **시즌 초기 봇 클론 시드 데이터**(개발자 제작 더미 replay)를 M6에 반드시 포함. 위키의 "초기 매칭 문제"가 클론 풀 공백 현상.

> 아웃게임 세부 우선순위(T0~T3 티어)는 [[2026-05-29_vanguard-implementation-plan-outgame]] 참조. M1=T0, M5=T1~T2, M6=T3에 대응.

---

## 미해결/확인 필요 사항

**기획/밸런싱 협의**
- [ ] 위키에 전투 화면 구성(스플릿 여부)·라운드 수가 명시되지 않음 → 실게임 영상/Discord 확인 필요
- [ ] 점수 산출식 가중치(W_TIME / W_HP / W_KILL) 밸런싱 → 기획 협의
- [ ] Match 모드 vs Duel 모드 매칭 정책 차이 → 기획 협의
- [ ] Tier Milestones 보상의 정확한 티어 구간별 수치 (위키 표기 불명확) → 기획 확정

**최신 위키 기준으로 확정 (이전 가정 폐기)**
- [x] **Initiative Boost = Ember Pass 특전** / Vanguard Pass = 칩 추출 추가 리프레시 (아웃게임 6장)
- [x] **Ember Exchange Shop = 정식 운영 기능, 1차 스코프 포함** (Ember Mark 교환 상점, 아웃게임 5-3). "Coming Soon/제외" 가정 폐기
- [x] **카드 세트·적 구성 = 전 플레이어 동일 고정 세트** → 공정성 모델은 "고정 공유 시나리오 + 점수 비교"로 확정 (A/B 구분 대체, 인게임 2장)
- [x] 리더보드 보상: 순위별 4종(Ember Mark/Etching Solvent/Diamond/Gold) + 401위까지 + 7일 유효 (아웃게임 8장)
- [x] 적 티어 스케일링 + 텔레포트 시 스탯 증가 (인게임 5-1)
- [x] 칩 #4 회복은 Termination Phase 제외 (인게임 5-6)
- [x] 터렛 슬롯 해제 비용(무료/80/150/220) + 칩 관리 UI (아웃게임 3장)
- [x] 칩 획득 개수 확률(45/30/15/8/2%) (아웃게임 5장)
- [x] Auto-Patrol 구체 수치 (아웃게임 9장)

**여전히 위키 표기 자체가 불명확 (실게임/기획 확정 필요)**
- [ ] Tier Milestones 보상의 정확한 티어 구간별 수치 (위키 데이터 뒤섞임, 아웃게임 8-1)
- [ ] 점수 산출식 가중치(W_TIME / W_HP / W_KILL) — 밸런싱
- [ ] 전투 화면 구성(스플릿 여부)·정확한 라운드 수
