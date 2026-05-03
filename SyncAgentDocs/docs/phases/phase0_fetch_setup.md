# Phase 0 — FETCH_HEAD 설정 확인

## 입력 파라미터
- FROM_PATH: {from}
- TO_PATH: {to}
- SYSTEM: {system}

## 작업

TO 프로젝트 디렉토리(`{to}`)에서 FETCH_HEAD가 FROM 프로젝트를 가리키는지 확인한다.

```bash
cd "{to}" && git ls-tree FETCH_HEAD --name-only 2>/dev/null | head -5
```

**정상인 경우 (파일 목록 출력됨):**
- Phase 0 완료, 다음 페이즈 진행 가능

**오류인 경우:**
아래 절차로 FETCH_HEAD를 설정한다:

```bash
cd "{to}" && git fetch "{from}" HEAD
```

설정 후 다시 확인:
```bash
cd "{to}" && git ls-tree FETCH_HEAD --name-only | head -5
```

## 완료 보고 형식

다음 형식으로 결과를 반환한다:

```
## Phase 0 결과
- FETCH_HEAD 상태: [정상 / 설정 필요했음 (설정 완료)]
- FROM 경로: {from}
- TO 경로: {to}
```
