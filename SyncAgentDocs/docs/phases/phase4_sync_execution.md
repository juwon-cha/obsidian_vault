# Phase 4 — sync 실행

## 입력 파라미터
- TO_PATH: {to}
- SYSTEM: {system}
- SYNC_PLAN: `{output_dir}/{system}_SYNC_PLAN.md`

## 참조 문서
아래 문서를 Read로 읽는다. **프로젝트별 sync 가이드는 Phase 3과 동일한 우선순위로 탐색**:

```bash
# Phase 3 Step "참조 문서"와 동일한 5단계 탐색 (상태 파일 → TO .claude/docs → 플러그인 번들 → 글로벌 obsidian → Downloads 폴백)
```

- `$guide_path` (위 순서로 결정된 sync 가이드 — 예: `WD_SYNC_GUIDE.md`, `PM_SYNC_GUIDE.md`)
- `{output_dir}/{system}_SYNC_PLAN.md`

## 작업

SYNC_PLAN.md의 **섹션 5 체크리스트 순서대로** sync을 진행한다.
순서를 임의로 바꾸지 않는다.

### sync 규칙
WD_SYNC_GUIDE.md의 규칙 1~16을 적용한다.

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

### Unity 에디터 작업 추적 (코드 작업과 분리)

Phase 4 진행 중 다음 항목이 발견되면 **코드 변경 결과에 자동 반영되지 않으므로** 별도 목록에 누적한다. 보고 시 `🟧 사용자 작업` 섹션으로 명확히 분리해서 출력한다.

| 유형 | 트리거 패턴 | 누적 항목 형식 |
|------|----------|-------------|
| 신규 매니저 prefab 컴포넌트 부착 | 신규 `XxxManager.cs` 작성 | `Managers prefab에 XxxManager 컴포넌트 추가` |
| SerializeField 슬롯 연결 | UI 파일 신규 작성 + `[SerializeField]` 발견 | `XxxUI.prefab의 슬롯 N개 연결 필요 (SYNC_PLAN 섹션 8.2 참조)` |
| SO 값 추가/수정 | 신규 enum/타입을 DataSheet에서 참조 | `XxxDataSheet.asset에 신규 항목 추가 필요` |
| Addressables 등록 | `LoadResource<T>` 호출에 새 키 등장 | `Addressables에 "{address}" 등록 필요` |
| Localization 키 추가 | `LocalizationManager.GetLocalizedText("key")` 호출에 새 키 | `Localization Table에 "key" 추가 필요` |
| 임시 PARTIAL 대체 (사용자 후처리 필요) | `// TODO: ... sync 후 복원` 주석 추가 | `XxxPopup → YyyPopup 임시 대체 (sync 완료 시 복원)` |

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

## 🟧 사용자 작업 — Unity 에디터 (코드 작업으로 자동 처리 안 됨)

> 아래 항목은 파일 시스템에서 처리할 수 없으니 Unity 에디터에서 직접 작업해줘.
> 누락 시 런타임 동작 안 함 / 매니저 null / 누락 레퍼런스 등 발생.

### Prefab 컴포넌트 부착
- [ ] {prefab 경로}에 `{Component}` 컴포넌트 추가
- [ ] (없으면 이 섹션 생략)

### SerializeField 슬롯 연결
- [ ] {prefab 경로}: `_fieldName` 슬롯 연결 (예상 타입: {Type})
- [ ] (배열 크기 큰 경우 SYNC_PLAN 섹션 8.2 참조)

### SO / DataSheet 값 추가
- [ ] {SO 경로}: enum {EType.NewValue} 항목 추가
- [ ] (없으면 이 섹션 생략)

### Addressables / Localization 등록
- [ ] Addressables 키 "{address}" 등록 (그룹: {예상 그룹})
- [ ] Localization 키 "{key}" 추가
- [ ] (없으면 이 섹션 생략)

### PARTIAL 임시 대체 (sync 완료 후 복원 필요)
- [ ] {파일명}:{줄번호} `// TODO: {의존성} sync 후 복원` — 향후 {의존성} sync 시 원복
- [ ] (없으면 이 섹션 생략)

→ 위 항목을 모두 처리한 뒤 'Phase 5 진행해' 또는 'Phase 6 진행해' 라고 말해줘.
```

> **누적 항목이 없는 카테고리는 출력하지 않는다.** 모든 카테고리가 비면 `🟧 사용자 작업` 섹션 전체를 생략하고 `✅ Unity 에디터 추가 작업 없음`으로 대체 출력.
