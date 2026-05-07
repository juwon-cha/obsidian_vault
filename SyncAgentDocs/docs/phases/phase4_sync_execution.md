# Phase 4 — sync 실행

## 입력 파라미터
- TO_PATH: {to}
- SYSTEM: {system}
- SYNC_PLAN: `{output_dir}/{system}_SYNC_PLAN.md`

## 참조 문서
아래 문서를 Read로 읽는다:
- `{to}/.claude/docs/WD_SYNC_GUIDE.md`
- `{output_dir}/{system}_SYNC_PLAN.md`

## 작업

SYNC_PLAN.md의 **섹션 5 체크리스트 순서대로** sync을 진행한다.
순서를 임의로 바꾸지 않는다.

### sync 규칙
WD_SYNC_GUIDE.md의 규칙 1~15를 적용한다.

### 각 항목 작업 방식
1. 해당 FROM 파일을 `cat "{from_local}/{경로}"`로 읽는다
2. TO 파일이 이미 존재하면 Read 도구로 읽는다
3. 변환 규칙 적용 후 Write/Edit 도구로 저장한다
4. SYNC_PLAN.md의 체크리스트 항목을 [x]로 표시한다
5. 파일 하나 완료 시 한 줄로 보고한다

### 중단 조건 (아래 상황이면 즉시 멈추고 보고)
- SYNC_PLAN에 기록되지 않은 TO 메서드 누락 발견
- 메서드 시그니처가 PLAN과 다름
- FROM 코드의 TO 대응 패턴 판단 불가
- 예상치 못한 의존성 발견

### PARTIAL 파일 처리 규칙 (PLAN 섹션 0.1 순서대로)
1. TO에 동등한 UIBase가 있으면 `Show<대체클래스>`로 교체
2. sync 파일이 호출하는 기존 TO 클래스에 메서드가 없으면 TO 파일을 Read 후 메서드 추가
3. partial class에서 참조하는 메서드가 TO에 없으면 TO 동등 로직으로 인라인 대체
4. 불가능하면 해당 호출을 주석 처리하고 `// TODO: {의존성} sync 후 복원` 남김

## 완료 보고 형식

```
## Phase 4 결과
- 체크리스트: N/N 완료
- sync된 파일 목록:
  - [파일명] — [DIRECT/ADAPTED/PARTIAL]
- PARTIAL 처리 내역:
  - 대체한 것: ...
  - 추가한 것: ...
  - 주석 처리한 것: ...
- ⚠️ 중단 없이 완료 / ⚠️ N개 항목에서 판단 필요
```
