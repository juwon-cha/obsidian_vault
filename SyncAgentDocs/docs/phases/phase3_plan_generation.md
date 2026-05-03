# Phase 3 — 분석 문서 생성

## 입력 파라미터
- TO_PATH: {to}
- SYSTEM: {system}
- Phase 2 결과: 파일별 분석, 패턴 표, 의존성 확인

## 참조 문서
아래 두 문서를 Read로 읽는다:
- `{to}/.claude/docs/WD_SYNC_GUIDE.md`
- `{to}/.claude/docs/SYSTEM_ANALYSIS_TEMPLATE.md`

## 작업

### 사전 확인
```bash
# SaveData 클래스 위치 확인
grep -rn "class {SaveDataClassName}" "{to}/Assets/_Project/1_Scripts/"

# Managers.cs priority 목록 확인
grep -n "ManagerDefinition" "{to}/Assets/_Project/1_Scripts/Core/Managers/Managers.cs"
```

### 생성할 파일

출력 경로는 상태 파일의 `output_dir` 값을 사용한다:
```bash
OUTPUT_DIR=$(python3 -c "import json; print(json.load(open('{to}/.claude/migration/.sync_state.json'))['output_dir'])")
mkdir -p "$OUTPUT_DIR"
```

저장 경로: `{OUTPUT_DIR}/{system}_SYNC_PLAN.md`
> 파일명 규칙: 영문만 사용. 예) `Relic_SYNC_PLAN.md`, `BattlePass_SYNC_PLAN.md`

SYSTEM_ANALYSIS_TEMPLATE.md를 기반으로 아래 섹션을 채운다:
- **섹션 0**: grep 전수조사 결과 표 (FROM 파일 | 역할 | FROM 전용 패턴 | sync 유형 | TO 처리 방법)
- **섹션 0.1**: PARTIAL 파일 의존성 상세 표
- **섹션 1**: TO 현재 상태 비교 (존재 항목 / sync 필요 항목)
- **섹션 2**: FROM 원본 파일 분석 (파일별 FROM 전용 패턴 체크리스트 + 필드/이벤트/메서드)
- **섹션 3**: TO 호출 대상 메서드 존재 확인 표 (3.1 매니저 / 3.2 UI컴포넌트 / 3.3 Show<T> / 3.4 partial)
- **섹션 4**: TO 수정 필요 기존 파일 목록 (before/after 코드 스니펫)
- **섹션 5**: sync 체크리스트 (공통 + 신규 파일 + 기존 수정 + PARTIAL 처리)
- **섹션 6**: 주의사항 (초기화 순서, 런타임 주의사항, PARTIAL 처리 내역)
- **섹션 7**: diff 비교 전략 (파일별 git diff 명령어 + 예상 diff 노이즈 표)

## 완료 보고 형식

```
## Phase 3 결과
- 생성 파일: {OUTPUT_DIR}/{system}_SYNC_PLAN.md
- 섹션별 핵심 내용:
  - 섹션 0: FROM 파일 N개 (DIRECT N / ADAPTED N / PARTIAL N / BLOCKED N)
  - 섹션 3: ⚠️ 항목 목록
  - 섹션 5: 체크리스트 총 N개 (공통 N / 신규 N / 기존 수정 N)
- ⚠️ 주의사항: ...
```
