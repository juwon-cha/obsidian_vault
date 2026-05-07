# Phase 0 — 소스 프로젝트 접근 설정

## 입력 파라미터
- FROM: {from}        ← 로컬 경로 / origin/<브랜치> / remote URL
- TO_PATH: {to}
- SYSTEM: {system}

---

## Step 1 — FROM 타입 감지

아래 규칙으로 `{from}`의 타입을 판별한다:

| 패턴 | 타입 | 예시 |
|------|------|------|
| `/`로 시작하거나 `~`로 시작 | **로컬 경로** | `/Volumes/repo/BunkerDefense` |
| `origin/` 또는 `upstream/` 등 `<remote>/` 형태 | **remote 브랜치** | `origin/temp-bunker` |
| `git@` 또는 `https://`로 시작 | **remote URL** | `git@github.com:org/BD.git` |

---

## Step 2 — 타입별 처리

### [A] 로컬 경로인 경우

```bash
ls "{from}" > /dev/null 2>&1 && echo "EXISTS" || echo "NOT_FOUND"
ls "{from}/Assets" > /dev/null 2>&1 && echo "UNITY" || echo "NOT_UNITY"
```

- EXISTS + UNITY → `FROM_LOCAL={from}` 확정, Step 3으로 이동
- 경로 없음 → 오류 보고 후 중단
- Unity 아님 → 경고 후 사용자에게 계속 여부 확인

---

### [B] remote 브랜치인 경우 (`origin/temp-bunker` 등)

**1. remote 이름과 브랜치명 분리:**
```
remote = "origin"        ← 첫 번째 `/` 앞
branch = "temp-bunker"   ← 첫 번째 `/` 뒤
```

**2. fetch:**
```bash
cd "{to}" && git fetch {remote} {branch}
```

**3. 임시 worktree 생성:**
```bash
WORKTREE_PATH="/tmp/sync_{system}_{timestamp}"
cd "{to}" && git worktree add "$WORKTREE_PATH" {remote}/{branch}
echo "WORKTREE_PATH=$WORKTREE_PATH"
```

**4. Unity 프로젝트 확인:**
```bash
ls "$WORKTREE_PATH/Assets" > /dev/null 2>&1 && echo "UNITY" || echo "NOT_UNITY"
```

- UNITY → `FROM_LOCAL=$WORKTREE_PATH` 확정
- NOT_UNITY → 경고 후 사용자에게 계속 여부 확인

**5. 상태 파일에 worktree 경로 기록 (나중에 정리하기 위해):**
```bash
python3 -c "
import json, os
_base = os.path.expanduser('~/Documents/obsidian_vault')
sync_base = os.path.join(_base, 'Sync') if os.path.isdir(_base) else os.path.expanduser('~/Downloads/Sync')
state_path = os.path.join(sync_base, os.path.basename('{to}'), '.sync_state.json')
with open(state_path, 'r') as f:
    state = json.load(f)
state['from_local'] = '$WORKTREE_PATH'
state['worktree_created'] = True
state['worktree_path'] = '$WORKTREE_PATH'
with open(state_path, 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
"
```

---

### [C] remote URL인 경우 (`git@...` 또는 `https://...`)

> `--branch` 플래그가 함께 전달된 경우 해당 브랜치를, 없으면 기본 브랜치를 사용한다.

**1. sparse clone으로 빠르게 가져오기:**
```bash
WORKTREE_PATH="/tmp/sync_{system}_{timestamp}"
git clone --depth=1 --single-branch \
  {branch_flag} \
  "{from}" "$WORKTREE_PATH"
```

**2. Unity 프로젝트 확인:**
```bash
ls "$WORKTREE_PATH/Assets" > /dev/null 2>&1 && echo "UNITY" || echo "NOT_UNITY"
```

**3. 상태 파일에 기록:**
```bash
python3 -c "
import json, os
_base = os.path.expanduser('~/Documents/obsidian_vault')
sync_base = os.path.join(_base, 'Sync') if os.path.isdir(_base) else os.path.expanduser('~/Downloads/Sync')
state_path = os.path.join(sync_base, os.path.basename('{to}'), '.sync_state.json')
with open(state_path, 'r') as f:
    state = json.load(f)
state['from_local'] = '$WORKTREE_PATH'
state['worktree_created'] = True
state['worktree_path'] = '$WORKTREE_PATH'
with open(state_path, 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
"
```

---

## Step 3 — 소스 구조 확인

`FROM_LOCAL`이 확정되면 기본 구조를 확인한다:

```bash
ls "{from_local}/Assets/_Project/1_Scripts/" 2>/dev/null | head -10
```

스크립트 폴더가 확인되면 Phase 0 완료.

---

## Step 4 — 워크트리 정리 안내 (worktree 생성한 경우)

이식 완료 후 반드시 정리가 필요함을 사용자에게 안내:

```
💡 임시 worktree가 생성됐어: {worktree_path}
   이식 완료 후 아래 명령어로 정리해줘:

   cd {to} && git worktree remove {worktree_path}

   또는 /sync --cleanup 으로 자동 정리할 수 있어.
```

---

## 완료 보고 형식

```
## Phase 0 결과
- FROM 타입: [로컬 경로 / remote 브랜치 / remote URL]
- FROM 원본: {from}
- FROM 로컬 경로: {from_local}
- 임시 worktree: [없음 / {worktree_path}]
- TO 경로: {to}
- 소스 구조: [정상 확인됨]
```
