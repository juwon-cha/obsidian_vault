# sync-agent

Unity 프로젝트 간 시스템 이식(sync) 워크플로우를 자동화하는 Claude Code 플러그인.

페이즈별 자동 진행(Phase 0~6), 컨텍스트 최적화(상태 파일 + `/clear` 후 이어가기), 프로젝트별 가이드 자동 생성(`/sync-init`)을 지원한다.

---

## 무엇을 하는가

다른 Unity 프로젝트(FROM)에서 특정 시스템을 현재 프로젝트(TO)로 옮길 때:

1. **`/sync-init`** — TO 프로젝트 컨벤션을 자동 감지하고 프로젝트 전용 sync 가이드 생성 (한 번만 실행)
2. **`/sync`** — FROM/TO 페이즈별 비교·분석·실행. 양쪽 매트릭스 비교, FROM 전용 패턴 변환, 프리팹 GUID 재매핑까지 자동화

---

## 설치

Claude Code 환경에서:

```
/plugin marketplace add juwon-cha-rocketdan/sync-agent-plugin
/plugin install sync-agent@sync-agent-marketplace
```

> `juwon-cha-rocketdan/sync-agent-plugin`는 GitHub의 `owner/repo` 형식.
> repo가 비공개라면 `git@github.com:owner/repo.git` 또는 로컬 clone 경로를 marketplace add에 전달.

설치 후 다음 명령이 슬래시 명령으로 등록된다:
- `/sync` — 페이즈별 sync 워크플로우
- `/sync-init` — 프로젝트 컨벤션 자동 감지 + 가이드 생성

---

## 첫 사용 (동료가 처음 받는 경우)

### 1. 자기 TO 프로젝트 루트로 이동

```bash
cd /Users/your.name/projects/YourUnityProject
```

### 2. `/sync-init` 실행

```
/sync-init
```

다음을 자동 감지·확인한다:
- 매니저 베이스 클래스 (예: `BaseManager`, `BaseService`)
- 매니저 접근 패턴 (예: `Managers.Instance.GetManager<T>()`, `ServiceAccessor.Get<T>()`)
- 이벤트 시스템 (`EventManager` static / `MessageBroker` DI / UniRx 등)
- 리소스 로딩, SaveData 메커니즘, Localization, 시간 시스템
- 스크립트 루트 경로, Managers 등록 파일 위치

복수 후보가 발견되면 선택 질문. 감지가 끝나면 FROM 프로젝트 정보도 물어본다 (BunkerDefense 사용자라면 "BD" 옵션 선택).

결과로 `{TO_PROJECT}/.claude/docs/{TO_SHORT}_SYNC_GUIDE.md`가 생성된다 (예: `PM_SYNC_GUIDE.md`).

### 3. 생성된 가이드 검토

자동 감지는 80% 정도 커버한다. 다음 항목은 직접 검토·보강 필요:
- 시그니처 축 변경 매핑 (예: `TakeDamage(EUnitRaceType)` → `TakeDamage(EElementType)`)
- 프로젝트 특이 매니저 메서드 (다중 오버라이드)
- IAP / 결제 / 서버 통신 등 프로젝트 전용 패턴

가이드 파일을 열어서 `자동 감지가 놓쳤을 수 있는 부분` 섹션의 체크리스트를 채우면 됨.

### 4. 실제 sync 시작

```
/sync
```

대화형 마법사 또는:

```
/sync --from origin/temp-bunker \
      --system BattlePass \
      --keys BattlePassManager,BattlePass \
      --phase 5a
```

---

## 명령어 레퍼런스

### `/sync` 옵션

| 플래그 | 설명 |
|------|------|
| `--from <소스>` | FROM 프로젝트 (로컬 경로 / `origin/브랜치` / git URL) |
| `--to <경로>` | TO 프로젝트 루트 (생략 시 현재 디렉토리) |
| `--system <이름>` | sync할 시스템명 (영문) |
| `--keys <키워드,...>` | 쉼표 구분 검색 키워드 |
| `--phase <4\|5a\|5b\|5c>` | 실행 범위 |
| `--plan <경로>` | 기존 분석 문서로 Phase 1~3 스킵 |
| `--output <경로>` | 산출물 저장 경로 |
| `--cancel` | 진행 중 작업 취소 |
| `--cleanup` | 임시 worktree 정리 |

`/sync` 단독 실행 시 대화형 마법사 진행.

### `/sync-init` 옵션

| 플래그 | 설명 |
|------|------|
| `--to <경로>` | TO 프로젝트 루트 (생략 시 현재 디렉토리) |
| `--name <약어>` | 가이드 파일 prefix (예: `PM` → `PM_SYNC_GUIDE.md`) |
| `--from-project <이름>` | FROM 프로젝트 (생략 시 질문) |
| `--force` | 기존 가이드 덮어쓰기 |

---

## 페이즈 구조

| Phase | 작업 |
|-------|------|
| 0 | FROM 소스 접근 (로컬·remote 브랜치·git URL 지원, 자동 worktree) |
| 1 | FROM 전수조사 + 숨겨진 인프라 의존성 탐지 |
| 2 | 병렬 파일 분석 + FROM 전용 패턴 감지 + 호출 그래프 역추적 |
| 3 | `{system}_SYNC_PLAN.md` 분석 문서 생성 |
| 4 | 실제 sync 실행 (변환 규칙 1~16 적용) |
| 5-A | 가져올 프리팹 목록 생성 (재귀 스캔) |
| 5-B | 프리팹 자동 sync (GUID 교체·LocalizeStringEvent 처리) |
| 5-C | 기존 프리팹 패치 (미리보기 + 확인) |
| 6 | sync 검증 (mcp-unity 또는 파일 레벨 폴백 + 8개 결선 체크리스트) |

각 페이즈는 독립적으로 실행 가능. 페이즈 완료 후 `/clear`로 컨텍스트 정리해도 상태 파일이 남아 `/sync` 재실행 시 이어서 진행됨.

---

## 산출물 저장 위치

플러그인은 어떤 파일도 git 추적 프로젝트 내부에 저장하지 않는다.

| 우선순위 | 경로 | 조건 |
|---------|------|------|
| 1 | `~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{system}/` | Obsidian vault 존재 시 |
| 2 | `~/Downloads/Sync/{YYYY-MM-DD}_{system}/` | 폴백 |

`--output` 플래그로 명시적 지정 가능.

---

## 가이드 파일 우선순위

페이즈 실행 시 sync 가이드를 다음 순서로 탐색:

1. 상태 파일에 저장된 `sync_guide_path` (가장 강한 우선순위 — `/sync-init`이 자동 등록)
2. `{TO_PATH}/.claude/docs/*_SYNC_GUIDE.md` (TO 프로젝트 커스텀)
3. `${CLAUDE_PLUGIN_ROOT}/docs/*_SYNC_GUIDE.md` (플러그인 번들)
4. `~/Documents/obsidian_vault/SyncAgentDocs/docs/WD_SYNC_GUIDE.md` (개발자 환경)
5. `~/Downloads/SyncAgentDocs/docs/WD_SYNC_GUIDE.md` (최종 폴백)

페이즈 문서(phase0~phase6) 도 동일한 순서로 탐색.

---

## 트러블슈팅

### Q. `/sync`가 "phase 파일을 찾을 수 없어"를 출력함
플러그인이 제대로 설치됐는지 확인: `/plugin list` 후 `sync-agent`가 enabled인지 본다.
재설치: `/plugin uninstall sync-agent && /plugin install sync-agent@sync-agent-marketplace`

### Q. `/sync-init`이 매니저 베이스 클래스를 못 찾아
프로젝트가 일반적인 `class XxxManager : Base` 패턴을 안 쓰는 경우. `--name`과 함께 수동 진행하고, 생성된 가이드를 직접 채워주면 됨.

### Q. 상태 파일이 이상해 / 처음부터 다시 하고 싶어
```
/sync --cancel
```
변경사항 되돌리기 또는 상태 파일만 삭제 선택 가능.

### Q. 임시 worktree가 너무 많이 쌓였어
```
/sync --cleanup
```
또는 수동: `cd {TO} && git worktree list` 후 `git worktree remove <path>`.

---

## 변환 규칙

`WD_SYNC_GUIDE.md`(또는 `/sync-init`이 생성한 프로젝트 가이드)의 규칙 1~16을 따른다.
가장 함정이 큰 규칙 두 가지:

- **규칙 15** — Partial class에서 동일 클래스 다른 partial 파일의 메서드를 호출할 때, TO에 그 메서드가 존재하는지 확인 (없으면 인라인 대체)
- **규칙 16** — `TakeDamage(EUnitRaceType)` → `TakeDamage(EElementType)` 같은 enum 축 변경. 베이스 클래스에 다중 오버라이드가 있으면 전부 일관되게 변환

Phase 6의 Step 0 "흔히 끊기는 8개 체크리스트"가 sync 후 자동 검사.

---

## 기여 / 피드백

이슈·PR 환영. 특히 `/sync-init`의 자동 감지 패턴(다른 프로젝트 컨벤션 추가)이 가장 큰 개선 포인트.

---

## 라이선스

MIT
