# Phase 5-A — 프리팹 sync 목록 생성

## 입력 파라미터
- FROM_LOCAL: {from_local}   ← Phase 0에서 확정된 실제 로컬 경로
- TO_PATH: {to}
- SYSTEM: {system}
- KEYS: {keys}
- OUTPUT_DIR: {output_dir}   ← 산출물 저장 경로

## 작업

sync된 스크립트를 분석해서 어떤 프리팹을 FROM에서 가져와야 하는지 목록을 만든다.
**중첩된 자식 프리팹을 놓치지 않기 위해 반드시 FROM 프리팹에서 재귀 스캔을 수행한다.**

---

### Step 1. TO sync 스크립트에서 진입점 프리팹 파악

TO에서 sync된 UI 클래스 목록 추출:
```bash
grep -rn "class.*:.*UIBase\|class.*:.*MonoBehaviour\|class.*:.*UIPopup" \
  "{to}/Assets/_Project/1_Scripts/UI/" --include="*.cs" | grep -iE "{keys_pipe}"
```

각 클래스에 대해 FROM에서 대응하는 프리팹 탐색 (진입점 프리팹):
```bash
find "{from}/Assets" -name "*.prefab" | grep -iE "{keys_pipe}"
grep -rl "{keys_pipe}" "{from}/Assets" --include="*.prefab" -l 2>/dev/null
```

---

### Step 2. 각 클래스의 SerializeField 추출 (TO 스크립트 기준)

각 TO 스크립트 파일을 Read로 읽어서:
- `[SerializeField]` 필드 전체 (타입·필드명)
- `Show<T>()` / `Hide<T>()` 호출에서 T 목록

---

### Step 3. FROM 진입점 프리팹 재귀 스캔 — 중첩 자식 프리팹 전체 감지

> **핵심**: TO가 아닌 **FROM 프리팹**을 기준으로 스캔한다.
> TO에 동일 파일명의 프리팹이 있어도 FROM이 최신 버전일 수 있으므로
> 반드시 FROM에서 구조를 읽어야 한다.

**재귀 스캔 알고리즘:**

```
visited_guids = {}
scan_queue = [진입점 프리팹 GUID 목록]
결과_목록 = []

while scan_queue가 비어있지 않을 때:
    guid = scan_queue에서 꺼내기
    if guid in visited_guids: continue
    visited_guids.add(guid)

    1. FROM Assets에서 해당 GUID의 .meta 파일 역추적
       grep -r "{guid}" "{from}/Assets" --include="*.meta" -l

    2. .prefab.meta 파일이면:
       a. FROM 프리팹 파일을 Read로 읽는다
       b. YAML에서 m_SourcePrefab guid 전체 추출
          (PrefabInstance 아래의 guid 필드)
       c. 추출된 guid들을 scan_queue에 추가
       d. 이 프리팹을 결과_목록에 추가 → Step 4로 TO 상태 확인

    3. .prefab.meta가 아니면 스킵 (스크립트, 이미지 등)
```

**재귀 종료 조건**: scan_queue가 빌 때 (더 이상 새 프리팹 GUID 없음)

---

### Step 4. 각 발견 프리팹의 TO 상태 분류

Step 3에서 발견된 각 프리팹에 대해:

```bash
find "{to}/Assets" -name "{파일명}.prefab"
```

**TO에 없음 → 신규 복사**

**TO에 있음 → FROM과 구조 비교 필요:**
FROM 프리팹과 TO 프리팹을 모두 Read로 읽어서 비교:
- GameObject 수 (자식 오브젝트 수)
- m_Component 항목 (컴포넌트 종류 및 수)
- m_SourcePrefab 참조 (중첩 프리팹 참조 구조)

| 비교 결과 | 분류 | Phase 5-B 처리 |
|---------|------|----------------|
| FROM = TO 구조 동일 | ⬛ 스킵 | 처리 불필요 |
| FROM에 자식/컴포넌트 추가됨 | ⚠️ 업데이트 필요 | FROM으로 교체 (GUID 재매핑) |
| TO가 의도적으로 다른 구조 | 🔵 수동 판단 | 목록에 표시만, sync 안 함 |

> **판별 기준**: 자식 오브젝트 수가 FROM > TO 이면 "업데이트 필요"로 분류한다.
> TO가 의도적으로 다른 경우(예: BottomBox처럼 아예 다른 레이아웃)는
> 파일명은 같지만 컨텐츠가 완전히 다르므로 "수동 판단"으로 표시한다.

---

### Step 5. 의존성 기반 sync 순서 결정

재귀 스캔 결과를 의존성 트리 기준으로 정렬:
- 다른 프리팹에 의존하지 않는 것(리프 노드)이 가장 먼저
- 루트 프리팹(진입점)이 가장 마지막

---

### 생성할 파일
`{OUTPUT_DIR}/{system}_PREFAB_PACKAGE_LIST.md`

```markdown
## 1. sync할 프리팹 목록 (의존성 순)

| 순서 | 프리팹 파일명 | 상태 | FROM 경로 | TO 처리 |
|------|-------------|------|----------|---------|
| 1 | {리프프리팹}.prefab | 신규 | {from경로} | 복사 |
| 2 | {중간프리팹}.prefab | ⚠️ 업데이트 | {from경로} | FROM으로 교체 |
| 3 | {루트프리팹}.prefab | 신규 | {from경로} | 복사 |
| — | {동일프리팹}.prefab | ⬛ 스킵 | — | 처리 불필요 |
| — | {다른구조프리팹}.prefab | 🔵 수동 판단 | — | TO 유지 |

## 2. 프리팹별 SerializeField 연결 목록
| 프리팹 | 필드명 | 타입 | 비고 |

## 3. Show<T> 외부 UI 참조 확인
| 호출 위치 | 대상 클래스 | TO 존재 여부 | 처리 |

## 4. 임포트 후 UIManager 등록 필요 목록
- [ ] {클래스명} — {프리팹 예상 경로}
```

---

## 완료 보고 형식

```
## Phase 5-A 결과
- 생성 파일: {OUTPUT_DIR}/{system}_PREFAB_PACKAGE_LIST.md
- 재귀 스캔 발견 프리팹 총 N개:
  - 신규 복사: N개
  - ⚠️ 업데이트 필요 (TO에 있지만 FROM이 더 새 버전): N개
  - ⬛ 스킵 (구조 동일): N개
  - 🔵 수동 판단 (TO가 의도적으로 다른 구조): N개
- ⚠️ 주의사항: ...
```
