# Phase 5-C — 기존 프리팹 패치 (미리보기 + 확인 후 적용)

## 입력 파라미터
- FROM_PATH: {from}
- TO_PATH: {to}
- SYSTEM: {system}
- 패치 대상: Phase 5-A 목록의 🔵 수동 판단 항목 + 스크립트 분석으로 감지된 기존 TO 프리팹

> **안전 원칙**: 절대 자동 적용하지 않는다.
> 모든 변경사항을 미리보기로 보여주고 사용자 확인 후에만 패치한다.

---

## 작업

### Step 1. 패치 대상 프리팹 목록 확인

Phase 5-A 목록(`{to}/.claude/sync/{system}_PREFAB_PACKAGE_LIST.md`)에서
🔵 수동 판단 항목을 읽는다.

추가로, Phase 4에서 sync된 스크립트에서 기존 TO 프리팹을 참조하는 패턴을 탐색:
```bash
# sync된 스크립트에서 Show<T>, Hide<T> 호출 중 TO에 이미 존재하는 UI 클래스 찾기
grep -rn "Show<\|Hide<" "{to}/Assets/_Project/1_Scripts" --include="*.cs" | grep -iE "{keys_pipe}"
```

패치 대상 목록을 확정한다.

---

### Step 2. FROM/TO 프리팹 구조 비교 (대상마다 반복)

각 대상 프리팹에 대해:

1. FROM 프리팹 Read:
   ```bash
   find "{from}/Assets" -name "{파일명}.prefab"
   ```
   찾은 경로로 Read 도구 사용

2. TO 프리팹 Read:
   ```bash
   find "{to}/Assets" -name "{파일명}.prefab"
   ```

3. 구조 비교:

   **A. 새로운 GameObject 감지** (FROM에 있고 TO에 없는 것)
   - FROM YAML에서 `m_Name` 기준으로 GameObject 목록 추출
   - TO YAML에서 동일 추출
   - FROM에만 있는 항목 → 추가 후보

   **B. 기존 GameObject에 새로운 컴포넌트 감지**
   - 동일 이름 GameObject의 `m_Component` 목록 비교
   - FROM에만 있는 컴포넌트 → 추가 후보

   **C. OnClick 바인딩 변경 감지**
   - Button 컴포넌트의 `m_OnClick.m_PersistentCalls.m_Calls` 비교
   - FROM에만 있는 바인딩 → 추가 후보

---

### Step 3. 미리보기 출력 및 확인

비교 결과를 아래 형식으로 출력하고 사용자 확인을 기다린다:

```
📋 {파일명}.prefab 패치 예정:

[추가 GameObject]
  └ 경로: {부모경로}/{오브젝트명}
  └ 컴포넌트: {컴포넌트 목록}
  └ OnClick: {메서드명} (스크립트: {클래스명})
  └ 자식 오브젝트: {자식 목록}

[기존 GameObject에 컴포넌트 추가]
  └ 대상: {오브젝트명}
  └ 추가 컴포넌트: {컴포넌트명}

[OnClick 바인딩 추가]
  └ 대상 버튼: {버튼 경로}
  └ 메서드: {클래스명}.{메서드명}()

적용할까?
  y → 패치 적용
  n → 이 프리팹 스킵
  d → 상세 YAML diff 보기
```

**"d" 선택 시**: FROM과 TO의 관련 YAML 블록을 나란히 출력한다.

---

### Step 4. 패치 적용 (y 확인 후에만 실행)

#### 4-1. 새 GameObject 추가

1. FROM 프리팹에서 추가할 GameObject와 모든 자식 오브젝트의 YAML 블록 추출
2. TO 프리팹의 기존 최대 fileID 확인:
   ```
   TO 프리팹 YAML에서 모든 `--- !u![숫자] &[숫자]` 패턴의 숫자 추출 → 최댓값 확인
   ```
3. FROM 블록의 fileID를 새 값으로 재매핑 (최댓값 + 1, +2, +3, ... 순으로 할당)
4. 블록 내부의 fileID 참조도 동일하게 재매핑
5. GUID 참조 교체:
   - `.cs` GUID: FROM meta 역추적 → TO에서 동일 파일명 meta → TO GUID로 교체
   - `.png`/`.sprite` GUID: FROM meta 역추적 → TO에서 동일 파일명 탐색 → 있으면 TO GUID, 없으면 FROM GUID 유지
   - 패키지 스크립트(UGUI 등) GUID: 버전 동일하면 그대로
6. 부모 GameObject의 `m_Children` 리스트에 새 fileID 추가
7. 완성된 YAML 블록을 TO 프리팹 파일 끝에 추가
8. Write 도구로 TO 프리팹 파일 저장

#### 4-2. OnClick 바인딩 추가

1. TO 프리팹에서 대상 Button 컴포넌트 위치 확인
2. `m_PersistentCalls.m_Calls` 리스트에 새 바인딩 블록 추가:
   ```yaml
   - m_Target: {fileID: [TO의 스크립트 컴포넌트 fileID], guid: 00000000000000000000000000000000, type: 0}
     m_TargetAssemblyTypeName: {클래스명}, Assembly-CSharp
     m_MethodName: {메서드명}
     m_Mode: 1
     m_Arguments:
       m_ObjectArgument: {fileID: 0}
       m_ObjectArgumentAssemblyTypeName: UnityEngine.Object, UnityEngine
       m_IntArgument: 0
       m_FloatArgument: 0
       m_StringArgument:
       m_BoolArgument: 0
     m_CallState: 2
   ```
3. Write 도구로 저장

---

### Step 5. 패치 완료 리포트

`{to}/.claude/sync/{system}_PREFAB_PATCH_REPORT.md` 파일 생성:

```markdown
# {system} 기존 프리팹 패치 리포트

## 패치된 프리팹
| 프리팹 | 추가된 항목 | 결과 |
|--------|------------|------|
| {파일명}.prefab | Button_Preset (GameObject) + OnClick 바인딩 | ✅ 적용 |

## 스킵된 프리팹
| 프리팹 | 이유 |
|--------|------|
| {파일명}.prefab | 사용자 스킵 (n 선택) |

## ⚠️ 수동 확인 필요
- Unity 에디터에서 패치된 프리팹 열어서 Inspector 연결 상태 확인
- 추가된 버튼의 RectTransform 위치/크기가 레이아웃에 맞는지 확인
```

---

## 완료 보고 형식

```
## Phase 5-C 결과
- 패치된 프리팹: N개
- 스킵된 프리팹: N개
- 리포트: {to}/.claude/sync/{system}_PREFAB_PATCH_REPORT.md
- ⚠️ Unity 에디터에서 Inspector 확인 필요
```
