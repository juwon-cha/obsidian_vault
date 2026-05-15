# Phase 2 — 병렬 FROM 파일 분석

## 입력 파라미터
- FROM_LOCAL: {from_local}   ← Phase 0에서 확정된 실제 로컬 경로
- TO_PATH: {to}
- SYSTEM: {system}
- Phase 1 결과: FROM 발견 파일 목록, grep 패턴

## 작업

Phase 1에서 발견된 FROM 파일들을 분석한다.
**파일이 3개 이상이면 반드시 Agent 도구(병렬)를 사용한다.**

각 파일 분석:
```bash
cat "{from_local}/{파일경로}"
```

각 파일에서 추출:
① 클래스명 / 역할 한 줄 요약
② FROM 전용 패턴 감지:
   - ServiceAccessor / [Inject] / MessageBroker
   - using Geuneda / using UniRx / BaseService
   - DateTime.Now / Resources.Load / ToUniTask
   - async void / SavePlayerDataAsync
③ 필드 목록 (타입 + 이름)
④ 이벤트 목록 (public event)
⑤ public/protected 메서드 시그니처 전체
⑥ 다른 매니저 호출 위치

분석 완료 후:

**A. FROM 전용 패턴 표**
| 파일명 | 감지된 패턴 | TO 변환 규칙 번호 |

**B. sync 유형 분류**
DIRECT / ADAPTED / PARTIAL / BLOCKED 중 하나.
PARTIAL이면 미sync 의존성 명시.

**D. 인프라 초기화 비교** (SaveData·직렬화 관련 파일이 있는 경우)

FROM과 TO의 핵심 인프라 클래스 초기화 패턴을 비교한다:

```bash
# SaveDataManager JsonSerializer 설정 비교
grep -A 10 "JsonSerializer\|CreateJsonSerializer" \
  "{from_local}/Assets/_Project/1_Scripts/Core/Managers/SaveDataManager.cs" 2>/dev/null
grep -A 10 "JsonSerializer\|CreateJsonSerializer" \
  "{to}/Assets/_Project/1_Scripts/Core/Managers/SaveDataManager.cs"

# Manager 등록/초기화 패턴 비교
grep -n "Add\|Register\|Initialize" \
  "{from_local}/Assets/_Project/1_Scripts/Core/Managers/Managers.cs" 2>/dev/null | head -30
grep -n "Add\|Register\|Initialize" \
  "{to}/Assets/_Project/1_Scripts/Core/Managers/Managers.cs" | head -30
```

FROM에만 있는 등록/초기화 항목은 Phase 3 문서 섹션 4에 기록한다.

**C. 3가지 의존성 확인**
```bash
# 매니저 메서드 확인
grep -rn "메서드명" "{to}/Assets/_Project/1_Scripts/Core/Managers/"

# UI 컴포넌트 메서드 확인
grep -rn "호출메서드명" "{to}/Assets/_Project/1_Scripts/UI/"

# uiManager.Show<T>() 대상 클래스 확인
grep -rn "class 대상클래스명" "{to}/Assets/_Project/1_Scripts/UI/"
```

**E. 호출 그래프 역방향 추적 — 외부 호출자 누락 감지**

> **핵심**: "TO에 메서드가 있는가"(C)만으로는 부족하다. **그 메서드가 FROM에서 누구한테 호출되는가**를 같이 추적해야 한다. 호출자가 TO에 미이식이면 sync된 메서드는 0건 호출되는 죽은 코드가 된다. publisher/subscriber 0건 함정이 가장 흔한 결선 누락 케이스.

각 sync 대상 파일의 핵심 진입점 메서드(public 메서드, 이벤트 발행, StartGame/EndGame류)에 대해:

```bash
# 1. FROM에서 누가 이 메서드를 호출하는지 전수조사
grep -rn "\.StartFooGame\|\.EndFooGame\|\.NotifyFooChanged" "{from_local}/Assets" --include="*.cs"

# 2. 위에서 찾은 호출자 파일들이 sync 대상 목록에 있는지 확인
#    (목록에 없으면 → 호출자 자체가 미이식 → 호출 추가가 필요한 기존 TO 파일)

# 3. 호출자가 TO 기존 파일이라면 TO에 동일 호출이 있는지 확인
grep -rn "\.StartFooGame\|\.EndFooGame" "{to}/Assets/_Project/1_Scripts" --include="*.cs"
```

**MessageBroker / EventManager 메시지 결선 검증** (메시지 publisher가 sync 대상이면 필수):

```bash
# FROM의 메시지 publisher 위치
grep -rn "PublishSafe<FooEventData>\|MessageBroker.Publish.*FooEventData" "{from_local}/Assets" --include="*.cs"

# FROM의 메시지 subscriber 위치
grep -rn "Subscribe<FooEventData>" "{from_local}/Assets" --include="*.cs"

# TO에서 동일 이벤트(GameEventType.FooEvent)의 결선 상태
grep -rn "GameEventType\.FooEvent" "{to}/Assets/_Project/1_Scripts" --include="*.cs"
```

| 결과 | 처리 |
|------|------|
| FROM publisher N개 / FROM subscriber N개 / TO 둘 다 0건 | 정상 — sync 후 양쪽 같이 결선 |
| FROM publisher만 sync 대상, subscriber는 미sync | ⚠️ **PARTIAL** — sync 후 메시지 발행돼도 수신자 0건, 섹션 0.1에 기록 |
| FROM subscriber만 sync 대상, publisher는 TO 기존 파일 | TO 기존 파일에 publisher 호출 추가 필요 → 섹션 4에 기록 |

**매니저 등록 호출자 확인** (sync 대상이 신규 매니저인 경우):

```bash
# Managers.cs / ManagerFactory.cs 등록 누락 시 GetManager<T>() null 반환
grep -n "ManagerDefinition.*FooManager" "{to}/Assets/_Project/1_Scripts/Core/Managers/Managers.cs"
# 결과 0건 → 섹션 4에 등록 추가 항목 기록
```

> **Phase 3 섹션 4 반영 의무**: E 결과로 발견된 "TO 기존 파일에 호출 추가 필요" 항목은 모두 분석 문서 섹션 4(TO 수정 필요 기존 파일)에 before/after 스니펫과 함께 기록한다.

## 완료 보고 형식

```
## Phase 2 결과

### 파일별 분석 요약
| 파일명 | 클래스명 | 역할 | sync 유형 |
|--------|----------|------|----------|
| ...    | ...      | ...  | DIRECT/ADAPTED/PARTIAL/BLOCKED |

### FROM 전용 패턴 표
| 파일명 | 감지된 패턴 | 변환 규칙 번호 |

### PARTIAL 파일 의존성
| 파일명 | 미sync 의존성 | 처리 방안 |

### TO 의존성 존재 확인
| 항목 | 결과 |
| 매니저 메서드 | ✅/⚠️ |
| UI 컴포넌트 메서드 | ✅/⚠️ |
| Show<T> 대상 클래스 | ✅/⚠️ |

### 호출 그래프 역방향 추적 결과 (Step 2-E)
| 진입점 메서드/이벤트 | FROM 호출자 수 | TO 동일 호출자 존재 | 처리 |
|--------|------------|---------------|------|
| `FooManager.StartFooGame()` | 3 (BarManager, BazUI, QuxFlow) | 2 (BarManager 미호출) | 섹션 4에 BarManager 호출 추가 |
| `GameEventType.FooEvent` (publisher) | 2 | 0 | TO에 동일 발행 위치 신설 필요 |
| `GameEventType.FooEvent` (subscriber) | 1 | 0 | sync 대상에 포함되어 있는지 확인 |

### 결선 검증 결과
- publisher 0건 / subscriber 0건 패턴: [있음/없음]
- TO 기존 파일에 호출 추가 필요: N건 → 섹션 4 기록

### sync 예상 주의사항
- ...

### 인프라 의존성 감사 결과
(Step 2-I에서 발견된 누락 인프라 파일 목록)
| 파일명 | 유형 | TO 존재 여부 | 처리 방안 |
|--------|------|------------|---------|
| SerializableDictionaryConverter.cs | JSON Converter | ❌ 없음 | Phase 4에서 sync 필요 |
```
