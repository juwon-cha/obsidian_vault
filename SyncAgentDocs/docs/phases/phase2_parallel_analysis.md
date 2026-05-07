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

### sync 예상 주의사항
- ...

### 인프라 의존성 감사 결과
(Step 2-I에서 발견된 누락 인프라 파일 목록)
| 파일명 | 유형 | TO 존재 여부 | 처리 방안 |
|--------|------|------------|---------|
| SerializableDictionaryConverter.cs | JSON Converter | ❌ 없음 | Phase 4에서 sync 필요 |
```
