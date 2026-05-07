# FROM→TO sync 마스터 프롬프트 템플릿

## 사용법

1. **빠른 치환 목록**을 보고 `{중괄호}` 를 전부 실제 값으로 교체한다.
2. `=== 마스터 프롬프트 시작 ===` 부터 `=== 마스터 프롬프트 끝 ===` 까지 전체를 복사한다.
3. Claude CLI에 아래 두 파일과 함께 붙여넣는다:
   - `WD_SYNC_GUIDE.md`
   - `SYSTEM_ANALYSIS_TEMPLATE.md`
4. Claude가 각 Phase 완료 후 결과를 보고하고 진행 여부를 물어보면 응답한다.

---

## 빠른 치환 목록

| 플레이스홀더 | 설명 | 채울 값 |
|---|---|---|
| `{시스템명}` | sync할 시스템 이름 | |
| `{FROM_PATH}` | 소스 프로젝트 루트 경로 (Phase 5-B 필수) | |
| `{TO_PATH}` | 대상 프로젝트 루트 경로 (Phase 5-B 필수) | |
| `{grep키워드목록}` | FROM grep 대상 키워드들 (`\|`로 구분, 아래 작성 지침 참조) | |
| `{TO파일키워드목록}` | TO 파일명 grep 키워드들 (`\|`로 구분, 아래 작성 지침 참조) | |
| `{SaveDataClassName}` | SaveData 클래스명 — **없으면 Phase 3의 해당 줄 삭제** | |

### grep 키워드 작성 지침

**많을수록 좋다.** 클래스명이 FROM/TO 사이에 조금 달라도 걸리도록, 아래 유형을 전부 나열한다:

| 유형 | 예시 (Preset 시스템) |
|------|-------------------|
| 핵심 매니저 클래스명 | `PresetManager` |
| 타입/열거형 파일명 | `PresetTypes`, `EPresetSlot` |
| 인터페이스명 | `IPresetCapable` |
| SaveData 클래스명 | `PresetSaveData` |
| 공통 접두어/접미어 (부분 일치) | `Preset` ← 이것 하나로도 위 항목 대부분을 커버 |
| 관련 이벤트/메서드 명 (특이한 것만) | `PresetChanged`, `LoadPreset` |

> **팁**: `Preset`처럼 시스템 이름 자체를 키워드에 포함하면, 클래스명 변경·약어·주석에서도 참조 파일이 누락되지 않는다.
>
> 예: `{grep키워드목록}` = `PresetManager\|PresetTypes\|IPresetCapable\|PresetSaveData\|EPresetSlot\|Preset`

---

=== 마스터 프롬프트 시작 ===

첨부한 WD_SYNC_GUIDE.md와 SYSTEM_ANALYSIS_TEMPLATE.md를 먼저 읽어줘.
그리고 아래 순서대로 {시스템명} 시스템을 FROM 프로젝트에서 TO 프로젝트로 sync할 거야.

각 Phase가 끝날 때마다:
1. 결과를 요약해서 보고한다.
2. "다음 Phase N을 진행할까요?" 라고 물어보고 내 응답을 기다린다.
3. 내가 승인하면 다음 Phase로 넘어간다.
4. 내가 수정 요청을 하면 해당 Phase를 다시 수행한다.

Phase 4(sync 실행)는 내가 명시적으로 "sync 시작" 또는 "진행해" 라고 해야만 시작한다.
절대로 내 승인 없이 다음 Phase로 넘어가지 마.

---

## Phase 0 — FETCH_HEAD 설정 확인

sync을 시작하기 전에 FROM 코드를 읽을 수 있는지 확인해줘.

```bash
git ls-tree FETCH_HEAD --name-only | head -5
```

- 출력이 정상이면 Phase 1로 진행한다.
- 오류가 나면 WD_SYNC_GUIDE.md 섹션 8의 FETCH_HEAD 설정 절차를 먼저 실행하고, 완료 후 나에게 보고한다.

Phase 0 완료 후 보고 형식:
- FETCH_HEAD 상태 (정상 / 설정 필요)
- 설정이 필요했다면 완료 여부
- "Phase 1(FROM 전수조사)을 진행할까요?"

---

## Phase 1 — FROM 전수조사

아래 명령으로 FROM에서 {시스템명} 시스템을 참조하는 파일을 전부 찾아줘.

```bash
git grep -l "{grep키워드목록}" FETCH_HEAD -- "*.cs"
```

동시에 TO에서도 관련 파일이 이미 있는지 확인해줘.

```bash
grep -rl "{TO파일키워드목록}" Assets/_Project/1_Scripts --include="*.cs" -l
```

Phase 1 완료 후 보고 형식:
- FROM에서 발견된 파일 목록 (경로 전체)
- TO에 이미 존재하는 파일 목록
- "Phase 2(병렬 분석)를 진행할까요?"

---

## Phase 2 — 병렬 FROM 파일 분석

Phase 1에서 찾은 FROM 파일들을 병렬로 분석해줘.
파일이 3개 이상이면 병렬 에이전트를 띄워서 동시에 읽어.

각 파일마다 추출할 항목:
① 클래스명 / 역할 한 줄 요약
② FROM 전용 패턴 감지 (아래 패턴 중 해당하는 것):
   ServiceAccessor / [Inject] / MessageBroker / using Geuneda / using UniRx /
   BaseService / DateTime.Now / Resources.Load / ToUniTask / async void / SavePlayerDataAsync
③ 필드 목록 (타입 + 이름)
④ 이벤트 목록 (public event)
⑤ public/protected 메서드 시그니처 전체
⑥ 다른 매니저를 호출하는 위치 (ServiceAccessor.Get 또는 _xxxManager. 패턴)

분석 후 추가로:

**A. FROM 전용 패턴 표**
파일명 | 감지된 패턴 | TO 변환 규칙 번호

**B. sync 유형 분류** (WD_SYNC_GUIDE.md 섹션 2 Step 4 기준)
각 파일을 DIRECT / ADAPTED / PARTIAL / BLOCKED 중 하나로 분류한다.
PARTIAL이 있으면 그 이유(미sync 의존성)를 명시한다.

**C. 3가지 의존성 존재 확인** (WD_SYNC_GUIDE.md 섹션 2 Step 3 참조)

```bash
# C-1. 매니저 메서드 확인
grep -rn "메서드명" Assets/_Project/1_Scripts/Core/Managers/

# C-2. UI 컴포넌트 메서드 확인 (sync 파일이 호출하는 기존 TO 컴포넌트 메서드)
grep -rn "SetPresetNumbers\|RefreshAll\|등호출메서드" Assets/_Project/1_Scripts/UI/

# C-3. uiManager.Show<T>()에서 T가 TO에 존재하는지 확인
git show FETCH_HEAD:{파일경로} | grep -n "Show<\|Hide<"
grep -rn "class SkillEquipPopup\|class 해당클래스명" Assets/_Project/1_Scripts/UI/

# C-4. partial class라면: 동일 클래스 다른 partial의 메서드 참조 확인
git show FETCH_HEAD:{Partial파일경로} | grep -n "\.[A-Z][a-zA-Z]*(\|^[[:space:]]*[A-Z][a-zA-Z]*(" | grep -v "\/\/\|public\|private\|protected\|override\|class "
grep -n "해당메서드명" Assets/_Project/1_Scripts/Core/Managers/FooManager.cs
```

Phase 2 완료 후 보고 형식:
- 파일별 분석 결과 요약
- FROM 전용 패턴 표 (파일명 | 감지된 패턴 | 변환 규칙 번호)
- **sync 유형 표** (파일명 | 유형 | PARTIAL이면 미sync 의존성 명시)
- TO 의존성 존재 확인 결과 — 매니저/UI컴포넌트/Show<T>/partial 내부 (✅ 존재 / ⚠️ 없음)
- sync 예상 주의사항 (있으면)
- "Phase 3(문서 생성)를 진행할까요?"

---

## Phase 3 — 분석 문서 생성

Phase 2 결과와 첨부한 SYSTEM_ANALYSIS_TEMPLATE.md를 참고해서
~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_SYNC_PLAN.md 를 생성해줘.
(obsidian 없으면 ~/Downloads/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_SYNC_PLAN.md)

채워야 하는 섹션:
- 섹션 0: grep 전수조사 결과 표 (FROM 파일 | 역할 | FROM 전용 패턴 | **sync 유형** | TO 처리 방법) + **섹션 0.1 PARTIAL 파일 의존성 상세 표**
- 섹션 1: TO 현재 상태 비교 (존재 항목 / sync 필요 항목)
- 섹션 2: FROM 원본 파일 분석 (파일별 FROM 전용 패턴 체크리스트 + 필드/이벤트/메서드)
- 섹션 3: TO 호출 대상 메서드 존재 확인 표 — **3.1 매니저 메서드 / 3.2 UI 컴포넌트 메서드 / 3.3 Show<T> UI 클래스 / 3.4 partial 내부 참조** (✅ / ⚠️)
- 섹션 4: TO 수정 필요 기존 파일 목록 및 수정 내용 (before/after 코드 스니펫 포함) — **PARTIAL 처리로 추가/수정해야 할 TO 기존 파일도 여기 포함**
- 섹션 5: sync 체크리스트 (공통 + 신규 파일 + 기존 파일 수정 + **PARTIAL 파일 처리**)
- 섹션 6: 이 시스템 특유의 주의사항 (초기화 순서, 런타임 주의사항 포함) + **PARTIAL 처리 내역 및 향후 조치**
- 섹션 7: diff 비교 전략 — 신규 생성 파일 전체의 diff 확인 명령어 (`git show FETCH_HEAD:{경로} > /tmp/from_{파일명}` + `diff` 명령) 및 예상 diff 노이즈 표 (파일 | 적용 규칙 | 예상 diff). 변환 불필요 파일은 "diff 0줄" 명시.

SaveData 클래스 위치는 SaveDataTypes.cs가 아닐 수 있으므로 반드시 grep으로 확인:

```bash
grep -rn "class {SaveDataClassName}" Assets/_Project/1_Scripts/
```

Managers.cs priority 결정을 위해 기존 priority 목록 확인:

```bash
grep -n "ManagerDefinition" Assets/_Project/1_Scripts/Core/Managers/Managers.cs
```

Phase 3 완료 후 보고 형식:
- 생성된 파일 경로
- 섹션별 핵심 내용 요약 (특히 ⚠️ 항목)
- 체크리스트 항목 수 (공통 N개 / 신규 파일 N개 / 기존 수정 N개)
- "문서를 검토한 뒤 'sync 시작'이라고 말해줘. Phase 4(sync 실행)를 바로 진행할까요?"

---

## Phase 4 — sync 실행

생성된 {시스템명}_SYNC_PLAN.md 의 체크리스트 순서대로 sync을 진행해줘.
(체크리스트에 기록된 순서가 곧 sync 순서다. 임의로 순서를 바꾸지 마.)

sync 규칙: 첨부한 WD_SYNC_GUIDE.md (규칙 1~15) 적용

각 항목 작업 시:
- WD의 해당 파일을 Read로 읽은 뒤 수정을 시작한다.
- 체크리스트 항목 완료 시 [x] 표시한다.
- 파일 하나 완료할 때마다 완료 사실을 한 줄로 보고한다.

⚠️ 아래 상황이 발생하면 즉시 sync을 중단하고 보고한다:
- SYNC_PLAN.md에 기록되지 않은 TO 메서드 누락 발견
- 메서드 시그니처가 PLAN과 다름
- FROM 코드의 TO 대응 패턴을 판단하기 어려운 경우
- 예상치 못한 의존성이 발견된 경우

sync 대상 파일(FROM 원본)에 있던 메서드를 임의로 추가하거나 누락시키지 마.
단, SYNC_PLAN.md 섹션 0.1에 기록된 **기존 TO 파일에 대한 메서드 추가**는 허용된다 (아래 PARTIAL 규칙 참조).
판단이 불확실하면 멈추고 보고해.

**PARTIAL 파일 처리 규칙** (SYNC_PLAN.md 섹션 0.1에 기록된 항목 순서대로, 우선순위 순):
1. TO에 동등한 UIBase가 있으면 `Show<대체클래스>`로 교체
2. sync 파일이 호출하는 기존 TO 클래스에 메서드가 없으면 해당 TO 파일을 Read한 뒤 메서드 추가
3. partial class에서 참조하는 메서드가 TO에 없으면 TO 동등 로직으로 인라인 대체
4. 위 방법이 불가능하면 해당 호출을 주석 처리하고 `// TODO: {의존성} sync 후 복원` 을 남김
5. 모든 PARTIAL 처리 완료 후 Unity에서 컴파일 에러 0개인지 확인 요청

Phase 4 완료 후 보고 형식:
- 체크리스트 완료 현황 (N/N)
- PARTIAL 처리 내역 요약 (대체한 것, 추가한 것, 주석 처리한 것)
- "Unity 에디터에서 컴파일 에러를 확인해줘. 에러가 있으면 알려줘. 에러가 없으면 'Phase 5 진행해'라고 말해줘."

---

## Phase 5-A — 프리팹 sync 목록 생성

sync된 스크립트를 분석해서 프리팹 sync에 필요한 정보를
~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_PREFAB_PACKAGE_LIST.md 로 생성해줘.

### 분석 절차

**Step 1. sync된 UIBase/MonoBehaviour 상속 클래스 목록 추출**
```bash
grep -rn "class.*:.*UIBase\|class.*:.*MonoBehaviour" {TO_PATH}/Assets/_Project/1_Scripts/UI/ --include="*.cs" | grep -iE "{TO파일키워드목록}"
```

**Step 2. 각 클래스의 SerializeField 추출**

각 UI 스크립트 파일을 Read로 읽어서 다음을 추출:
- `[SerializeField]` 필드 전체 (타입·필드명·배열 크기 힌트)
- `Show<T>()` / `Hide<T>()` 호출에서 T 목록
- 자식 프리팹으로 분리되어야 할 컴포넌트 (다른 스크립트를 참조하는 배열/리스트)

**Step 3. TO 프리팹 폴더에서 이미 존재하는 프리팹 대조**
```bash
find {TO_PATH}/Assets -name "*.prefab" | sort
```

**Step 4. 의존성 기반 sync 순서 결정**

자식 프리팹 → 부모 프리팹 순서로 정렬 (자식이 먼저 있어야 부모 프리팹의 레퍼런스가 성립).

### 생성할 문서 구조

```markdown
## 1. sync할 프리팹 목록 (의존성 순)
- [ ] {자식모듈}.prefab
- [ ] {메인팝업}.prefab
(TO에 이미 존재하는 것은 ~~취소선~~ 표시)

## 2. 프리팹별 SerializeField 연결 목록
| 프리팹 | 필드명 | 타입 | 배열 크기 | 주의사항 |

## 3. Show<T> 외부 UI 참조 확인
| 호출 위치 | 대상 클래스 | TO 존재 여부 | 처리 |
(⚠️ TODO 주석 처리된 것도 포함)

## 4. 임포트 후 UIManager 등록 필요 목록
- [ ] {클래스명} — {프리팹 예상 경로}
```

Phase 5-A 완료 후 보고 형식:
- 생성된 파일 경로
- sync 대상 프리팹 수 / TO에 이미 존재하는 수
- ⚠️ 항목 요약 (TODO 주석, 배열 크기 큰 것, 스프라이트 리스트 등)
- "'Phase 5-B 진행해'라고 말하면 프리팹 자동 sync을 실행할게."

---

## Phase 5-B — 프리팹 자동 sync 실행

> **필수 입력값** (아래 세 줄을 실제 값으로 교체한 뒤 실행)
> ```
> FROM_PATH = {FROM_PATH}        # 예: /Volumes/solidigm/repo/FROM프로젝트
> TO_PATH   = {TO_PATH}          # 예: /Volumes/solidigm/repo/TO프로젝트
> KEYWORDS  = {키워드1, 키워드2}  # 예: Loadout, Preset
> ```

Phase 5-A에서 생성한 목록과 위 입력값을 기반으로 FROM → TO 프리팹 sync을 실행해줘.
Unity 에디터 없이 파일 시스템에서 직접 복사·GUID 교체로 처리한다.

### 실행 절차

**Step 1. FROM에서 대상 프리팹 탐색**
```bash
# 파일명 기준
find {FROM_PATH}/Assets -name "*.prefab" | grep -iE "KEYWORD1|KEYWORD2"
# 내용 기준 (파일명에 키워드 없는 경우 보완)
grep -rl "KEYWORD1\|KEYWORD2" {FROM_PATH}/Assets --include="*.prefab" -l
```

**Step 2. 각 프리팹의 GUID 의존성 전체 추출**

각 `.prefab` 파일을 Read로 읽어서 YAML에서 모든 GUID 참조를 추출:
```
m_Script, m_Sprite, m_Texture, m_Material, m_Font, m_Mesh 등
```
각 GUID에 대해 FROM의 `.meta` 파일을 역추적해서 파일명·확장자를 확인.

**Step 3. 의존성별 처리 방법 결정**

| 파일 종류 | 판별 | 처리 |
|---------|------|------|
| `.prefab` | sync 대상 | FROM → TO 경로에 복사 |
| `.cs` (스크립트) | 이미 TO에 sync됨 | `asset` 스킵, `.meta`만 복사 → GUID 통일 |
| `.png`/`.sprite` 등 이미지 | TO에 **같은 파일명**이 있으면 | FROM asset 스킵, 프리팹 YAML의 GUID를 TO 버전으로 교체 |
| `.png`/`.sprite` 등 이미지 | TO에 없으면 (신규) | FROM asset + meta 모두 복사 |
| `.mat`/`.ttf` 등 기타 에셋 | TO에 **같은 파일명**이 있으면 | GUID 교체 |
| `.mat`/`.ttf` 등 기타 에셋 | TO에 없으면 (신규) | FROM asset + meta 복사 |

> **스프라이트 파일명 매칭 방법**
> ```bash
> # TO 전체에서 같은 파일명 탐색
> find {TO_PATH}/Assets -name "파일명.png"
> # 있으면 → TO .meta의 guid 값을 읽어서 프리팹 YAML에 치환
> # 없으면 → FROM asset + meta 복사
> ```

**Step 4. 프리팹 YAML GUID 교체 실행**

스프라이트·머티리얼 등 TO에 이미 존재하는 에셋은 프리팹 파일 내부의 GUID를 TO 버전으로 교체:
```bash
# FROM GUID → TO GUID 치환 (sed 또는 파일 직접 수정)
sed -i 's/guid: {FROM_GUID}/guid: {TO_GUID}/g' {복사된_프리팹_경로}
```

**Step 5. 파일 배치 — TO 경로 결정 원칙**

- FROM 경로의 `Assets/` 이하 구조를 TO의 `Assets/` 이하에 동일하게 유지
- TO에 해당 폴더가 없으면 생성
- 이미 동일 파일명의 프리팹이 TO에 있으면 덮어쓰기 전 확인 후 진행

**Step 6. 처리 완료 리포트 생성**

```markdown
## Phase 5-B sync 리포트

### 복사된 프리팹
- {파일명}.prefab → {TO 경로}

### GUID 교체된 에셋 (TO 기존 파일 사용)
- {파일명}.png : FROM guid {aaa} → TO guid {bbb}

### 신규 복사된 에셋 (FROM에만 있던 것)
- {파일명}.png → {TO 경로}

### 스킵된 스크립트 (asset 제외, .meta만 복사)
- {클래스명}.cs.meta → {TO 스크립트 경로}

### ⚠️ 수동 확인 필요
- Missing Script: {클래스명} (TO에 미sync 스크립트)
- UIManager 등록 필요: {클래스명 목록}
- 배열/리스트 SerializeField 확인: Phase 5-A 섹션 2 참조
```

Phase 5-B 완료 후 보고 형식:
- 리포트 요약 (복사 N개 / GUID 교체 N개 / 신규 에셋 N개 / 스킵 N개)
- ⚠️ 수동 확인 필요 항목 목록
- "Unity 에디터를 열어서 reimport가 완료되면 Missing Script와 UIManager 등록을 확인해줘."

=== 마스터 프롬프트 끝 ===

---

## 변형 패턴

### A. 분석만 할 때 (sync 없이 문서만)

Phase 4·5 전체 블록을 삭제하고,
Phase 3 완료 후 멘트를 아래로 교체:

> "문서 생성 완료. sync은 별도로 지시해줘."

### B. 이미 분석 문서가 있을 때 (Phase 4만)

아래 내용만 복사해서 WD_SYNC_GUIDE.md와 함께 붙여넣기:

---

~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_SYNC_PLAN.md 를 읽고 sync을 진행해줘.
첨부한 WD_SYNC_GUIDE.md (규칙 1~15)를 적용해.

체크리스트에 기록된 순서대로 진행한다. 각 파일 작업 전 TO 파일을 Read로 읽고 시작.
체크리스트 항목 완료 시 [x] 표시.

⚠️ PLAN에 없는 메서드 누락 / 시그니처 불일치 / 패턴 판단 불가 / 예상치 못한 의존성 → 즉시 중단하고 보고.
sync 대상 FROM 파일의 메서드를 임의로 추가하거나 누락시키지 마.
단, SYNC_PLAN.md 섹션 0.1에 기록된 기존 TO 파일 메서드 추가(PARTIAL 처리)는 수행한다.

---

### C. Phase 2 결과 검토 후 진행할 때

Phase 2 프롬프트 끝에 아래 문장 추가:

> "분석 결과 출력 후, sync 예상 난이도와 주의사항을 한 줄씩 정리해줘. 확인 후 문서 생성을 지시할게."

### D. 스크립트 sync 완료 후 프리팹 목록만 생성할 때 (Phase 5-A만)

아래 내용만 복사해서 붙여넣기:

---

~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_SYNC_PLAN.md 를 읽고 Phase 5-A(프리팹 sync 목록 생성)만 진행해줘.

FROM_PATH = {FROM_PATH}
TO_PATH   = {TO_PATH}
KEYWORDS  = {키워드1, 키워드2}

출력 파일: `~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_PREFAB_PACKAGE_LIST.md`
분석 절차는 SYNC_PROMPT_TEMPLATE.md의 Phase 5-A 절차를 따른다.

---

### E. 목록 확인 후 프리팹 자동 sync만 실행할 때 (Phase 5-B만)

아래 내용만 복사해서 붙여넣기:

---

~/Documents/obsidian_vault/Sync/{YYYY-MM-DD}_{시스템명}/{시스템명}_PREFAB_PACKAGE_LIST.md 를 읽고 Phase 5-B(프리팹 자동 sync)를 실행해줘.

FROM_PATH = {FROM_PATH}
TO_PATH   = {TO_PATH}
KEYWORDS  = {키워드1, 키워드2}

실행 절차는 SYNC_PROMPT_TEMPLATE.md의 Phase 5-B 절차를 따른다.
실행 전 처리 계획을 먼저 보고하고 확인을 받은 뒤 진행해.

---
