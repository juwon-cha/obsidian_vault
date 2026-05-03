# Phase 1 — FROM 전수조사

## 입력 파라미터
- FROM_PATH: {from}
- TO_PATH: {to}
- SYSTEM: {system}
- KEYS: {keys}  (쉼표 구분)

## 작업

### Step 1. KEYS를 grep 패턴으로 변환
쉼표 구분 키워드를 `\|` 구분 패턴으로 변환한다.
예: `PresetManager,PresetTypes,Preset` → `PresetManager\|PresetTypes\|Preset`

### Step 2. FROM 파일 탐색
TO 프로젝트에서 FETCH_HEAD를 통해 FROM 파일을 검색한다:

```bash
cd "{to}" && git grep -l "{grep_pattern}" FETCH_HEAD -- "*.cs"
```

### Step 2-I. 숨겨진 인프라 의존성 탐지

Phase 1의 grep 키워드로는 잡히지 않지만 sync 시스템이 간접적으로 의존하는
인프라 파일들을 탐지한다.

#### A. FROM Utils/ 폴더와 TO Utils/ 폴더 비교

FROM에만 있는 유틸리티 파일을 찾는다:
```bash
# FROM Utils 파일 목록
git ls-tree FETCH_HEAD Assets/_Project/1_Scripts/Utils/ --name-only 2>/dev/null

# TO Utils 파일 목록
ls "{to}/Assets/_Project/1_Scripts/Utils/"
```

FROM에만 존재하는 파일은 **인프라 의존성 후보**로 기록한다.

#### B. sync 대상 파일들의 커스텀 using 분석

sync 대상 파일마다 커스텀 네임스페이스/타입 참조를 추출한다:
```bash
# Unity/System 표준 라이브러리 제외하고 커스텀 using만 추출
git show FETCH_HEAD:{파일경로} | grep "^using " | \
  grep -vE "UnityEngine|UnityEditor|System\.|Cysharp|Newtonsoft|TMPro|DG\.|UnityEngine\." | \
  sort -u
```

추출된 커스텀 네임스페이스/클래스가 있으면 FROM에서 해당 파일을 탐색:
```bash
git grep -l "{커스텀_클래스명}" FETCH_HEAD -- "*.cs"
```

TO에 해당 파일이 없으면 **sync 필요 인프라 파일**로 분류한다.

#### C. 알려진 인프라 패턴 체크리스트

아래 패턴 중 sync 파일에서 발견되는 것을 확인한다:

```bash
# JSON Converter 탐지 (SaveData 포함 시스템)
git grep -l "JsonConverter\|JsonSerializer.Create\|JsonSerializerSettings" FETCH_HEAD -- "*.cs" | \
  grep -v "SaveDataManager"

# 커스텀 제네릭 컨테이너 사용 탐지
git grep -l "SerializableDictionary\|ObservableList\|SerializableHashSet" FETCH_HEAD -- "*.cs" | \
  grep -v "SerializableDictionary.cs"

# 확장 메서드 파일 탐지
git ls-tree -r FETCH_HEAD --name-only | grep -iE "Extensions\.cs|Helper\.cs" | \
  grep "_Project"

# 암호화·압축 유틸리티 탐지
git grep -l "Encrypt\|Decrypt\|Cipher\|AES\b\|Base64" FETCH_HEAD -- "*.cs" | \
  grep "_Project"
```

탐지된 파일들을 **인프라 의존성 후보 목록**에 추가한다.

#### D. 인프라 의존성 후보 → 필요 여부 판별

각 후보 파일에 대해 TO에 존재하는지 확인:
```bash
find "{to}/Assets/_Project/1_Scripts" -name "{파일명}.cs"
```

| 판별 결과 | 처리 |
|---------|------|
| TO에 없음 | Phase 4 체크리스트에 추가 (sync 필요) |
| TO에 있음 (내용 동일) | 스킵 |
| TO에 있음 (내용 다름) | Phase 2에서 상세 비교 후 판단 |

### Step 3. TO 기존 파일 확인
```bash
grep -rl "{grep_pattern_pipe}" "{to}/Assets/_Project/1_Scripts" --include="*.cs" -l
```

### Step 4. 결과 정리

발견된 각 FROM 파일에 대해:
- `git show FETCH_HEAD:{경로}` 로 파일 존재 확인 (경로 형식: `Assets/...`)
- TO에 같은 이름 파일이 있으면 "기존 존재" 표시

## 완료 보고 형식

```
## Phase 1 결과

### FROM 발견 파일 (N개)
- Assets/.../파일명.cs [TO에 기존 존재 / 신규]
- ...

### TO 기존 관련 파일 (N개)
- Assets/.../파일명.cs
- ...

### grep 패턴 (Phase 2에서 재사용)
{grep_pattern}
```
