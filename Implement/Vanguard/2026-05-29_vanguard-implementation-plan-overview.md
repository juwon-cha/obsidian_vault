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

## 아키텍처 방향 — 기존 모드 추가 패턴 답습

코드 확인 결과 Ark / PunchKing / RaceTower 모드가 **동일한 골격**으로 추가되어 있다. Vanguard도 그대로 따른다.

```
1) GameModeType 에 enum 값 추가 (Vanguard)
2) {Mode}Manager : BaseManager        ← 모드 상태/오케스트레이션
3) {Mode}Service : BaseServerService  ← 서버 API
4) {Mode}StagePlayService             ← StageManager 내부 전투 플로우 구동
5) 핵심 전투 엔진은 재사용 + 모드 분기
   (EnemyManager / CardManager / ChipManager /
    DamageCalculationManager / BaseSystemManager / StageManager)
```

### 신규 클래스 (총 5개, 그중 2개는 경량)

| 클래스 | 역할 | 영역 |
|---|---|---|
| `VanguardManager : BaseManager` | 재화/로드아웃/시즌/랭크/클론 상태 | 아웃게임 |
| `VanguardService : BaseServerService` | 매칭/결과/리더보드/상자/패스 API | 아웃게임 |
| `VanguardStagePlayService` | 전투 플로우 제어 (PunchKing 패턴) | 인게임 |
| `VanguardGhostPlayer` | 상대 고스트 재생 (전투 로직 없음, 경량) | 인게임 |
| `VanguardReplayRecorder` | 내 전투 녹화 → 클론 생성 (경량) | 인게임 |

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
| **M1** | **토대 (양쪽 공유)** | `GameModeType.Vanguard`, `ECurrencyType` 6종, `VanguardManager`/`Service` 빈 골격 + Managers 등록, 진입 게이트(Lv45/50) + 시즌 주기 | churn 거의 0. 무조건 먼저 (아웃게임 T0) |
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

- [ ] 위키에 전투 화면 구성(스플릿 여부)·라운드 수가 명시되지 않음 → 실게임 영상/Discord 확인 필요
- [ ] 점수 산출식 가중치(W_TIME / W_HP / W_KILL) 밸런싱 → 기획 협의
- [ ] Match 모드 vs Duel 모드 매칭 정책 차이 → 기획 협의
- [ ] Ember Exchange Shop은 위키상 "Coming Soon" → 1차 구현 제외
