---
description: Unity 프로젝트 간 시스템 sync. 페이즈별 실행 + 컨텍스트 최적화.
---

입력된 인수: $ARGUMENTS

---

## Step 0 — 상태 파일 확인

먼저 현재 디렉토리에 상태 파일이 있는지 확인한다:

```bash
pwd
cat .claude/migration/.sync_state.json 2>/dev/null || echo "NO_STATE"
```

**상태 파일이 있고 `next_phase`가 `done`이 아닌 경우:**

```
🔄 이전 sync 작업이 있어:
   시스템: {state.system}  /  FROM: {state.from}
   다음 페이즈: Phase {state.next_phase}

이어서 진행할까?
   y → Phase {state.next_phase}부터 바로 시작
   n → 새로 시작
```

→ `y` 응답: [페이즈 실행](#페이즈-실행)으로 바로 이동
→ `n` 응답: 상태 파일 무시하고 [케이스 A/B](#케이스-a--플래그-즉시-실행)로 이동

**상태 파일이 없거나 `NO_STATE`인 경우:** → [케이스 A/B](#케이스-a--플래그-즉시-실행)로 이동

---

## 케이스 A — 플래그 즉시 실행

`$ARGUMENTS`에 `--from`이 포함된 경우 아래 플래그를 파싱한다:

```
--from  <소스>        소스 프로젝트 (필수). 세 가지 형태 지원:
                        로컬 경로:     /Volumes/repo/BunkerDefense
                        remote 브랜치: origin/temp-bunker
                                       브랜치 지정: origin/temp-bunker/dev
                                       💡 항상 최신 브랜치(dev 등)를 명시하는 것을 권장
                        remote URL:   git@github.com:org/BunkerDefense.git
--branch <브랜치>     --from이 remote URL일 때 브랜치 지정 (생략 시 기본 브랜치)
--to    <경로>        대상 프로젝트 루트 (생략 시 현재 디렉토리)
--system <이름>       sync할 시스템명 (필수). 영문으로 작성.
                        예) Relic, BattlePass, Preset, HordeDungeon
--keys  <키워드,...>  쉼표 구분 키워드 (--plan 사용 시 생략 가능)
--phase <4|5a|5b|5c> 실행 범위 (생략 시 대화로 선택)
--plan  <경로>        기존 분석 문서 경로. 지정 시 Phase 1~3 건너뛰고 Phase 4로 바로 실행.
                        obsidian 경로: ~/Documents/obsidian_vault/Sync/2026-05-03_Relic/{system}_SYNC_PLAN.md
                        프로젝트 경로: .claude/migration/{system}_SYNC_PLAN.md
                        절대 경로:    /any/path/to/{system}_SYNC_PLAN.md
--output <경로>       산출물 저장 디렉토리 (생략 시 자동 결정)
                        기본값: ~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{system}/
                        예) --output ~/Documents/obsidian_vault/Sync/2026-05-03_Relic
--cancel             진행 중인 sync 작업 취소 및 상태 초기화
--cleanup            sync 완료 후 임시 worktree 정리
```

`--cancel` 플래그가 있는 경우 → [취소 처리](#공통--취소-처리)로 이동
`--plan` 플래그가 있는 경우 → [플랜 파일 검증](#공통--플랜-파일-검증)으로 이동
그 외 → [FROM 검증](#공통--from-검증)으로 이동

---

## 케이스 B — 순차 대화형 마법사

`$ARGUMENTS`가 비어있으면 아래 순서로 **항목 하나씩** 질문한다.

### Step 1. TO 경로 — 현재 프로젝트 자동 감지

```bash
pwd
ls Assets 2>/dev/null && echo "UNITY_PROJECT" || echo "NOT_UNITY"
```

**현재 디렉토리가 Unity 프로젝트인 경우:**
```
📁 TO (대상 프로젝트)
   현재 프로젝트를 자동으로 감지했어: {현재경로}
   그대로 사용할게. 다른 경로를 쓰고 싶으면 입력해줘.
   (엔터를 치거나 "y"를 입력하면 현재 경로로 진행해)
```
→ "y" 또는 엔터 → 현재 경로를 TO로 확정
→ 다른 경로 입력 → 경로 검증 후 확정

**현재 디렉토리가 Unity 프로젝트가 아닌 경우:**
```
📁 TO (대상 프로젝트) 경로를 입력해줘:
   예) /Volumes/solidigm/repo/WiggleDefender
```

### Step 2. FROM 입력
```
📁 FROM (소스 프로젝트)를 입력해줘. 아래 세 가지 형태 모두 가능해:

   로컬 경로:     /Volumes/repo/BunkerDefense
   remote 브랜치: origin/temp-bunker          ← HEAD 브랜치
                  origin/temp-bunker/dev      ← 브랜치 직접 지정 (권장)
   remote URL:   git@github.com:org/BunkerDefense.git

💡 브랜치를 명시하지 않으면 remote의 HEAD 브랜치가 사용돼.
   최신 변경사항이 dev처럼 특정 브랜치에만 있는 경우 브랜치를 꼭 지정해줘.
```
→ 입력받으면 즉시 타입 감지 및 검증 (phase0_fetch_setup.md 참조)

### Step 3. 시스템명 입력
```
🎯 sync할 시스템명을 입력해줘:
   예) BattlePass, Preset, Loadout, HoreDungeon
```

### Step 3-B. 기존 분석 문서 자동 감지

시스템명이 확정되면 즉시 아래 경로에서 기존 분석 문서를 탐색한다:

```bash
# 1. 프로젝트 내부 표준 경로
ls "{to}/.claude/migration/{system}_SYNC_PLAN.md" 2>/dev/null && echo "FOUND_INTERNAL"

# 2. 프로젝트 내부 대소문자 변형 탐색
find "{to}/.claude/migration/" -iname "*{system}*plan*" -o -iname "*{system}*계획*" 2>/dev/null | head -3
```

**문서가 발견된 경우:**
```
📋 기존 분석 문서를 발견했어:
   {발견된 경로} ({파일 수정일})

어떻게 할까?
  y → 이 문서 기반으로 Phase 4부터 바로 시작  💡 토큰 절약
  p → 다른 경로의 문서를 직접 지정
  n → Phase 0부터 새로 분석
```

→ `y` 응답: 발견된 문서를 plan으로 확정 → [플랜 파일 검증](#공통--플랜-파일-검증)으로 이동
→ `p` 응답: 경로 직접 입력 받기 → [플랜 파일 검증](#공통--플랜-파일-검증)으로 이동
→ `n` 응답: Step 4로 이동 (전체 분석 진행)

**문서가 없는 경우:** Step 4로 이동

---

### Step 4. 키워드 입력
```
🔑 검색 키워드를 입력해줘 (쉼표로 구분, 많을수록 좋아):
   예) BattlePassManager, BattlePassTypes, BattlePass

   💡 팁: 시스템 이름 자체 (예: BattlePass) 를 포함하면
           클래스명이 달라도 관련 파일을 빠짐없이 찾을 수 있어.
```

### Step 5. 실행 범위 선택

AskUserQuestion 도구로 선택지를 보여준다:
- question: "sync 실행 범위를 선택해줘"
- header: "실행 범위"
- multiSelect: false
- options:
  - label: "Phase 0~4 — 스크립트 sync만"
    description: "BD→WD 스크립트 변환 및 sync. 프리팹 작업 없음."
  - label: "Phase 0~5-A — 스크립트 + 프리팹 목록"
    description: "스크립트 sync 후 가져와야 할 프리팹 목록 문서를 자동 생성."
  - label: "Phase 0~5-B — 스크립트 + 프리팹 자동 sync"
    description: "프리팹을 FROM→TO로 직접 복사. GUID 교체·스프라이트 처리 포함."
  - label: "Phase 0~5-C — 스크립트 + 프리팹 자동 sync + 기존 프리팹 패치"
    description: "5-B에 추가로, 기존 TO 프리팹에 FROM의 변경사항을 미리보기 후 패치."

---

## 공통 — 플랜 파일 검증

`--plan` 플래그가 있거나, 마법사에서 기존 문서를 선택한 경우.

### 1. 파일 존재 확인
```bash
ls "{plan_path}" > /dev/null 2>&1 && echo "EXISTS" || echo "NOT_FOUND"
```

파일이 없으면:
```
❌ 분석 문서를 찾을 수 없어: {plan_path}
경로를 다시 확인해줘. 또는 "새로 분석" 이라고 말하면 Phase 0부터 진행할게.
```

### 2. 문서 내용 요약 출력

파일이 있으면 Read 도구로 읽고 아래 형식으로 요약:
```
📋 Plan document found: {plan_path}

   System        : {문서에서 파악한 시스템명}
   Target files  : ~{N} files
   Key conversions: {핵심 변환 항목 3줄 요약}
   Blockers      : {있으면 목록, 없으면 "none"}

Phase 1~3 (file discovery / analysis / plan generation) will be skipped.
Proceeding: Phase 0 (source access) → Phase 4 (execution).

Type "start" to begin, or "re-analyze" to run full analysis from Phase 0.
```

### 3. 상태 파일에 plan 경로 저장

확인 후 상태 파일에 기록하고 `next_phase`를 `"0_plan"`으로 설정:
```bash
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="${HOME}/Documents/obsidian_vault/Sync/${DATE}_{system}"
[ -n "{output}" ] && OUTPUT_DIR="{output}"
mkdir -p "$OUTPUT_DIR"

mkdir -p "{to}/.claude/migration"
python3 -c "
import json
state = {
  'from': '{from}',
  'from_local': '',
  'to': '{to}',
  'system': '{system}',
  'keys': '',
  'phase_limit': '{phase}',
  'output_dir': '$OUTPUT_DIR',
  'next_phase': '0_plan',
  'plan_path': '{plan_path}',
  'completed_phases': {},
  'worktree_created': False,
  'worktree_path': ''
}
with open('{to}/.claude/migration/.sync_state.json', 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
"
```

### 4. 플랜 모드 페이즈 순서

| next_phase | 작업 | 비고 |
|------------|------|------|
| `0_plan` | Phase 0 실행 (소스 접근 + worktree만) | 파일 탐색 없이 접근만 |
| `4` | Phase 4 실행 (플랜 문서 기반으로 바로 실행) | 플랜 문서 전체를 Agent 프롬프트에 포함 |
| `5a/5b/5c` | Phase 5 실행 | phase_limit에 따라 |

---

## 공통 — 취소 처리

`--cancel` 플래그가 있거나, 페이즈 실행 중 사용자가 "중단해줘" / "취소해줘" 라고 말한 경우.

### 1. 상태 파일 확인
```bash
cat "{TO_PATH}/.claude/sync/.sync_state.json" 2>/dev/null || echo "NO_STATE"
```

상태 파일이 없으면:
```
현재 진행 중인 sync 작업이 없어.
```

### 2. 변경된 파일 목록 출력

```bash
cd "{TO_PATH}" && git diff --name-only HEAD
```

아래 형식으로 출력:
```
🛑 sync 작업 취소

완료된 페이즈: {completed_phases 목록}
마지막 진행: Phase {next_phase}

변경된 파일 목록:
  - Assets/...파일명.cs
  - Assets/...파일명.prefab
  - ...

어떻게 처리할까?
  r → 변경사항 전체 되돌리기 (git checkout -- .)
  k → 변경사항 유지하고 상태 파일만 삭제
  a → 취소 중단 (sync 계속 진행)
```

### 3. 선택에 따른 처리

**r 선택 (변경사항 되돌리기):**
```bash
cd "{TO_PATH}" && git checkout -- .
rm "{TO_PATH}/.claude/sync/.sync_state.json"
```
완료 후:
```
✅ 변경사항이 모두 되돌려졌어. sync 작업 전 상태로 복원됐어.
```

**k 선택 (상태 파일만 삭제):**
```bash
rm "{TO_PATH}/.claude/sync/.sync_state.json"
```
완료 후:
```
✅ 상태 파일을 삭제했어. 변경된 파일은 그대로 유지돼.
나중에 /sync 로 새 sync 작업을 시작할 수 있어.
```

**a 선택 (취소 중단):**
```
계속 진행할게. Phase {next_phase}부터 이어서 진행하려면 "다음 페이즈" 라고 말해줘.
```

---

## 공통 — FROM 검증

FROM 입력이 들어올 때마다 타입을 감지하고 즉시 검증한다:

**타입 감지 규칙:**

| 입력 패턴 | 타입 | Phase 0 처리 |
|-----------|------|--------------|
| `/` 또는 `~` 시작 | 로컬 경로 | 경로 존재 + Assets 폴더 확인 |
| `<remote>/` 형태 (예: `origin/temp-bunker`) | remote 브랜치 | `git fetch` + 임시 worktree 생성 |
| `git@` 또는 `https://` 시작 | remote URL | `git clone --depth=1` + 임시 worktree 생성 |

**로컬 경로 검증:**
```bash
ls "{from}" > /dev/null 2>&1 && echo "EXISTS" || echo "NOT_FOUND"
ls "{from}/Assets" > /dev/null 2>&1 && echo "UNITY" || echo "NOT_UNITY"
```

| 결과 | 출력 | 동작 |
|------|------|------|
| 존재 + Unity ✅ | `✅ {프로젝트명} 확인됨` | 다음 Step으로 이동 |
| 경로 없음 ❌ | `❌ 경로를 찾을 수 없어: {from}` | 같은 질문 재출력 |
| Unity 아님 ⚠️ | `⚠️ Unity 프로젝트가 아닌 것 같아 (Assets 폴더 없음)` | 같은 질문 재출력 |

**remote 타입:** Phase 0에서 worktree 생성 후 검증 — 여기서는 형식만 확인 후 수락.

---

## 공통 — 설정 확인 및 상태 저장

모든 항목이 수집되면:

### 1. 출력 디렉토리 결정

`--output` 플래그가 있으면 해당 경로를, 없으면 자동 생성한다:

```bash
if [ -n "{output}" ]; then
  OUTPUT_DIR="{output}"
else
  DATE=$(date +%Y-%m-%d)
  OUTPUT_DIR="$HOME/Documents/obsidian_vault/Sync/${DATE}_{system}"
fi
mkdir -p "$OUTPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
```

> 산출물(SYNC_PLAN.md, PREFAB_PACKAGE_LIST.md 등)은 모두 `OUTPUT_DIR`에 저장된다.
> `.sync_state.json`은 재실행 복원용이므로 프로젝트 내부에만 저장한다.

### 2. 상태 파일 저장
```bash
mkdir -p "{TO_PATH}/.claude/migration"
cat > "{TO_PATH}/.claude/migration/.sync_state.json" << 'STATEOF'
{
  "from": "{FROM_PATH}",
  "from_local": "",
  "to": "{TO_PATH}",
  "system": "{system}",
  "keys": "{keys}",
  "phase_limit": "{phase}",
  "output_dir": "{OUTPUT_DIR}",
  "next_phase": "0",
  "completed_phases": {},
  "worktree_created": false,
  "worktree_path": ""
}
STATEOF
```
> `from_local`과 `worktree_*` 필드는 Phase 0에서 remote 접근 시 자동으로 채워진다.

### 2. 권한 승인 방식 선택

AskUserQuestion 도구로 1단계 질문을 보여준다:
- question: "작업 중 권한 요청을 어떻게 처리할까?"
- header: "🔐 권한 승인 방식"
- multiSelect: false
- options:
  - label: "세션만 허용"
    description: "세션 동안 자동 승인. 종료 후 초기화. → 허용 범위 추가 선택"
  - label: "직접 승인"
    description: "Claude가 도구 사용 시마다 개별 요청. 기존 방식."

**"직접 승인" 선택 시:** 권한 설정 없이 바로 요약 출력으로 이동한다.

**"세션만 허용" 선택 시:** 아래 2단계 질문을 이어서 보여준다:

AskUserQuestion 도구로 2단계 질문을 보여준다:
- question: "세션 동안 어느 범위까지 자동 허용할까?"
- header: "🔐 허용 범위"
- multiSelect: false
- options:
  - label: "A. 전체 허용"
    description: "선택한 Phase 범위 내 모든 작업 자동 승인. 끊김 없이 쭉 진행."
  - label: "B. sync 실행 전만 확인"
    description: "탐색·분석(Phase 0~3)은 자동. Phase 4(실제 파일 수정) 직전에만 한번 확인."
  - label: "C. 페이즈 전환 시마다 확인"
    description: "각 Phase 시작 시 해당 Phase 권한만 묶어서 요청."
  - label: "D. 작업 유형별 허용"
    description: "읽기·탐색(git/grep/find/Read)은 자동. 쓰기·복사(Write/cp/mkdir)는 그때그때."

선택 결과에 따라 아래 권한을 세션 내 허용 목록으로 기억하고 이후 작업에 적용한다:

| 선택 | 자동 허용 항목 |
|------|--------------|
| A | git(fetch/grep/show/ls-tree), grep, find, python3, Read({from}/**), Read({to}/**), cp, mkdir, Write |
| B | git(fetch/grep/show/ls-tree), grep, find, python3, Read({from}/**), Read({to}/**) — Phase 4 직전 별도 확인 안내 |
| C | Phase별로 진입 시점에 해당 Phase 권한 목록 안내 후 진행 |
| D | git(fetch/grep/show/ls-tree), grep, find, Read({from}/**), Read({to}/**) |

> **B 옵션 Phase 4 진입 시 추가 안내:**
> ```
> ⚠️ 이제 Phase 4(실제 파일 수정)를 시작해.
>    아래 권한이 추가로 필요해:
>    - Write (TO 스크립트 파일 수정)
>    - python3 (상태 파일 업데이트)
>    계속 진행할까?
> ```

> **C 옵션 각 Phase 진입 시 안내 형식:**
> ```
> 🔐 Phase {N} 시작 — 아래 권한이 필요해:
>    - {해당 Phase 권한 목록}
>    진행할까?
> ```

### 3. 요약 출력

```
┌─────────────────────────────────────────────────────┐
│  ✅  sync 설정 확인                                   │
├─────────────────────────────────────────────────────┤
│  FROM    : {from}                                    │
│  (로컬)  : Phase 0에서 확정 예정                      │
│  TO      : {to}                                      │
│  System  : {system}                                  │
│  Keywords: {keys}                                    │
│  Phase   : 0~{phase}                                 │
│  Output  : {OUTPUT_DIR}                              │
│  권한 방식: {선택한 옵션}                              │
│                                                      │
│  💾 설정이 자동 저장됨                                │
│     /clear 후 /sync 재실행 시 이어서 진행 가능        │
└─────────────────────────────────────────────────────┘

"시작" 이라고 말하면 Phase 0부터 진행할게.
수정하고 싶은 항목이 있으면 알려줘.
```

---

## 페이즈 실행

"시작" 응답 또는 상태 파일에서 이어서 진행 시, `next_phase`부터 순서대로 실행한다.

### 각 페이즈 실행 절차

1. 해당 페이즈 문서를 Read 도구로 읽는다:
   ```
   {TO_PATH}/.claude/docs/phases/phase{N}_{name}.md
   ```

2. **Agent 도구로 실행한다** (서브에이전트가 독립 컨텍스트에서 파일 읽기/쓰기 수행):
   ```
   subagent_type: general-purpose
   prompt: [페이즈 문서 전체] + 아래 파라미터:
     FROM       = {from}             ← 원본 입력값 (remote URL/브랜치/로컬 경로)
     FROM_LOCAL = {from_local}       ← Phase 0에서 확정된 실제 로컬 경로
     TO_PATH    = {to}
     SYSTEM     = {system}
     KEYS       = {keys}
   ```
   > Phase 1 이후 파일 탐색은 FROM_LOCAL을 사용한다.

3. Agent가 반환한 요약 결과를 사용자에게 보고한다.

4. 상태 파일을 업데이트한다:
   ```bash
   # Python으로 JSON 업데이트 (jq 없이 안전하게)
   python3 -c "
   import json, sys
   with open('{TO_PATH}/.claude/sync/.sync_state.json', 'r') as f:
       state = json.load(f)
   state['completed_phases']['{N}'] = '{요약 한 줄}'
   state['next_phase'] = '{다음 페이즈}'
   with open('{TO_PATH}/.claude/sync/.sync_state.json', 'w') as f:
       json.dump(state, f, ensure_ascii=False, indent=2)
   "
   ```

5. 다음 안내를 출력한다:
   ```
   ✅ Phase {N} 완료.

   💡 컨텍스트를 절약하려면:
      /clear 실행 → /sync 재실행 → Phase {N+1} 이어서 자동 시작

   바로 계속하려면 "다음 페이즈" 라고 말해줘.
   작업을 중단하려면 "중단해줘" 라고 말해줘.
   ```

6. 사용자가 "중단해줘" 또는 "취소해줘" 라고 말한 경우:
   Agent 실행 중이라면 현재 Agent가 완료된 후 처리한다.
   완료 후 [취소 처리](#공통--취소-처리)로 이동한다.

### 페이즈 순서 및 문서 매핑

| next_phase | 문서 파일 | 비고 |
|------------|-----------|------|
| `0` | `phase0_fetch_setup.md` | 항상 실행 |
| `1` | `phase1_file_discovery.md` | 항상 실행 |
| `2` | `phase2_parallel_analysis.md` | 항상 실행 |
| `3` | `phase3_plan_generation.md` | 항상 실행 |
| `4` | `phase4_sync_execution.md` | **"sync 시작" 명시 시에만** |
| `5a` | `phase5a_prefab_list.md` | phase_limit이 5a, 5b, 5c인 경우 |
| `5b` | `phase5b_prefab_port.md` | phase_limit이 5b 또는 5c인 경우 |
| `5c` | `phase5c_existing_prefab_patch.md` | phase_limit이 5c인 경우 |

**Phase 4 주의**: 사용자가 명시적으로 "sync 시작" 또는 "진행해" 라고 말하기 전까지 절대 시작하지 않는다.
Phase 3 완료 시 아래 안내 출력:
```
📄 분석 문서가 생성됐어: {TO_PATH}/.claude/sync/{system}_SYNC_PLAN.md
검토 후 "sync 시작" 이라고 말해줘. 그 전까지 Phase 4는 실행되지 않아.
```

---

## 도움말

```
사용법:
  /sync
      순차 대화형 마법사 시작 (또는 이전 작업 이어서 진행)

  /sync --from <소스> --system <이름> --keys <키워드,...>
      TO는 현재 프로젝트 자동 감지, Phase는 대화로 선택

  /sync --from <소스> --to <경로> --system <이름> --keys <키워드,...> --phase <4|5a|5b|5c>
      모든 값 지정, 즉시 실행

  /sync --cancel
      진행 중인 sync 작업 취소. 변경사항 되돌리기 또는 상태 파일만 삭제 선택 가능.

  /sync --cleanup
      sync 완료 후 임시 worktree 정리.

--from 예시:
  로컬 경로:     --from /Volumes/repo/BunkerDefense
  remote 브랜치: --from origin/temp-bunker
  remote URL:   --from git@github.com:TeamSparta/BunkerDefense.git
  URL + 브랜치:  --from git@github.com:TeamSparta/BunkerDefense.git --branch develop

전체 예시:
  # 기본 (전체 분석 + 산출물 자동 저장)
  /sync --from origin/temp-bunker \
        --system BattlePass \
        --keys BattlePassManager,BattlePassTypes,BattlePass \
        --phase 5a
  # → 산출물: ~/Documents/obsidian_vault/Sync/2026-05-03_BattlePass/

  # 기존 분석 문서 활용 (Phase 1~3 스킵, 토큰 절약)
  /sync --from origin/temp-bunker \
        --system BattlePass \
        --plan ~/Documents/obsidian_vault/Sync/2026-05-03_BattlePass/BattlePass_SYNC_PLAN.md \
        --phase 4

  # 출력 경로 직접 지정
  /sync --from origin/temp-bunker \
        --system BattlePass \
        --keys BattlePassManager,BattlePassTypes \
        --output ~/Documents/obsidian_vault/Sync/2026-05-03_BattlePass \
        --phase 5a

💡 컨텍스트 절약 팁:
   각 페이즈 완료 후 /clear 를 실행해도 설정이 보존돼.
   /sync 를 다시 실행하면 중단된 페이즈부터 이어서 진행해.
```
