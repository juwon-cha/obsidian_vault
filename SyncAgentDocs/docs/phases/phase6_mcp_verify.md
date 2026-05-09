# Phase 6 — 프리팹 싱크 검증 (mcp-unity / 파일 레벨 폴백)

## 입력 파라미터
- TO_PATH: {to}
- SYSTEM: {system}
- OUTPUT_DIR: {output_dir}
- 검증 대상: Phase 5-B/5-C에서 sync된 프리팹 목록 (`{output_dir}/{system}_PREFAB_SYNC_REPORT.md` 또는 `{system}_PREFAB_PATCH_REPORT.md`)

---

## Step 1. mcp-unity 연결 확인

`mcp__mcp-unity__get_console_logs` 도구를 호출한다.

- **성공(로그 반환 또는 빈 배열 반환)** → [mcp-unity 경로](#mcp-unity-경로)로 이동
- **실패(연결 오류 / 도구 없음)** → [파일 레벨 폴백 경로](#파일-레벨-폴백-경로)로 이동

---

## mcp-unity 경로

### Step 2-A. 재컴파일 실행

```
mcp__mcp-unity__recompile_scripts
```

재컴파일 요청 후 콘솔 로그를 다시 조회한다:

```
mcp__mcp-unity__get_console_logs
```

### Step 3-A. 로그 분석

수신한 로그를 아래 기준으로 분류한다.

**에러(error) 로그 - sync된 파일 연관 여부 판단:**

sync된 프리팹 파일명 목록을 리포트에서 읽어두고,
각 에러 로그의 메시지·파일 경로가 그 목록과 겹치는지 확인한다.

| 분류 | 기준 | 처리 |
|------|------|------|
| 🔴 sync 연관 에러 | 로그에 sync된 파일명 또는 시스템 키워드 포함 | 즉시 리포트에 기록 + 원인 분석 |
| 🟡 기존 에러 | sync 이전부터 있던 것으로 추정 | 리포트에 기록 (참고용) |
| ✅ 에러 없음 | error 로그 없음 | 정상 |

**누락 레퍼런스 패턴 (특히 주의):**
```
MissingReferenceException
Could not find a part of the path
The referenced script on this Behaviour is missing
```
이 패턴이 sync된 파일명과 함께 등장하면 → 🔴 sync 연관으로 분류

### Step 4-A. 연관 에러 원인 분석

🔴 sync 연관 에러가 있을 경우:

1. 에러 메시지에서 파일 경로·GUID·컴포넌트명을 추출한다
2. 해당 프리팹 파일을 Read로 읽어 문제 GUID/참조를 확인한다
3. 원인을 특정한다:
   - GUID 교체 누락 → 해당 GUID를 TO에서 역추적해 교체
   - 에셋 복사 누락 → FROM에서 복사 후 저장
   - LocalizeStringEvent 구조 불완전 → Phase 5-B Step 6-C 절차 재수행
4. 수정 후 `mcp__mcp-unity__recompile_scripts` 재실행 → 로그 재확인

### Step 5-A. 씬 정보 교차 확인 (선택)

sync된 프리팹이 현재 열려있는 씬에 배치된 경우,
`mcp__mcp-unity__get_scene_info`로 해당 오브젝트의 실제 컴포넌트 목록을 확인한다.

```
mcp__mcp-unity__get_gameobject  (target: sync된 프리팹 루트 오브젝트명)
```

반환된 컴포넌트 목록과 리포트의 예상 컴포넌트 목록이 일치하면 ✅.

---

## 파일 레벨 폴백 경로

> mcp-unity 없이 파일 시스템만으로 검증한다.
> Unity Editor가 열려 있지 않거나 mcp-unity가 설치되지 않은 경우에 실행된다.

### Step 2-B. 리포트에서 sync된 프리팹 목록 읽기

`{output_dir}/{system}_PREFAB_SYNC_REPORT.md` 파일을 Read로 읽어
처리된 프리팹 경로 목록을 추출한다.

### Step 3-B. GUID 전수 재확인

각 sync된 TO 프리팹 파일에 대해:

```bash
# ① 표준 GUID 전체 추출
grep -oP '(?<=guid: )[a-f0-9]{32}' "{to_prefab}" | sort -u > /tmp/phase6_guids.txt

# ② 임베디드 GUID 전체 추출 (LocalizeStringEvent 등)
grep -oP '(?<=GUID:)[a-f0-9]{32}' "{to_prefab}" | sort -u >> /tmp/phase6_guids.txt

sort -u /tmp/phase6_guids.txt > /tmp/phase6_guids_dedup.txt
```

각 GUID에 대해 TO에서 해결 가능한지 확인:
```bash
while IFS= read -r guid; do
  result=$(grep -rl "$guid" "{to}/Assets" --include="*.meta" 2>/dev/null | head -1)
  if [ -z "$result" ]; then
    # PackageCache 확인
    result=$(grep -rl "$guid" "{to}/Library/PackageCache" --include="*.meta" 2>/dev/null | head -1)
  fi
  [ -z "$result" ] && echo "UNRESOLVED: $guid"
done < /tmp/phase6_guids_dedup.txt
```

미해결 GUID가 나오면:
1. FROM에서 해당 파일을 역추적해 복사 시도
2. 그래도 없으면 리포트에 기록

### Step 4-B. 컴포넌트 카운트 비교

Phase 5-B 리포트의 예상 컴포넌트 수와 실제 TO 프리팹의 카운트를 비교한다:

```bash
# MonoBehaviour 컴포넌트 수 비교
echo "FROM: $(grep -c '!u!114' '{from_prefab}' 2>/dev/null || echo 0)"
echo "TO:   $(grep -c '!u!114' '{to_prefab}' 2>/dev/null || echo 0)"

# LocalizeStringEvent 카운트 비교
echo "FROM LSE: $(grep -c 'LocalizeStringEvent' '{from_prefab}' 2>/dev/null || echo 0)"
echo "TO   LSE: $(grep -c 'LocalizeStringEvent' '{to_prefab}' 2>/dev/null || echo 0)"
```

불일치 시 Phase 5-B Step 6-B/6-C 절차를 재수행한다.

### Step 5-B. .meta 파일 누락 확인

sync된 에셋 중 `.meta` 파일이 없으면 Unity에서 GUID가 재생성되므로 반드시 확인한다:

```bash
find "{to}/Assets" -name "*.prefab" -newer "{to}/Assets" | while read f; do
  [ ! -f "${f}.meta" ] && echo "META MISSING: $f"
done
```

---

## Step 6. 검증 리포트 생성

`{OUTPUT_DIR}/{system}_VERIFY_REPORT.md` 파일로 저장:

```markdown
# {system} 프리팹 검증 리포트

## 검증 방식
- [ ] mcp-unity (Unity Editor 연결)
- [ ] 파일 레벨 폴백

## 검증 결과

### ✅ 정상 확인된 프리팹
| 프리팹 | 확인 내용 |
|--------|---------|
| {파일명}.prefab | GUID 전수 확인 / 컴포넌트 카운트 일치 |

### 🔴 수정 필요 (sync 연관 에러)
| 프리팹 | 에러 | 조치 |
|--------|------|------|
| {파일명}.prefab | MissingReference: {컴포넌트} | {GUID 재교체 / 에셋 재복사} |
(없으면 생략)

### ⚠️ 미해결 항목 (수동 확인 필요)
| 항목 | 내용 |
|------|------|
| {GUID} | TO/PackageCache 어디에도 없음 |
(없으면 생략)

### 🟡 기존 에러 (sync 무관)
(mcp-unity 경로에서만 기록. 없으면 생략)
```

---

## 완료 보고 형식

```
## Phase 6 결과 ({검증 방식: mcp-unity | 파일 레벨 폴백})

- 검증 프리팹: N개
- 🔴 수정 필요: N건 → {수정 완료 N건 / 수동 확인 필요 N건}
- ✅ 이상 없음: N개
- 리포트: {OUTPUT_DIR}/{system}_VERIFY_REPORT.md

{수정 필요 항목이 있으면:}
⚠️ 아래 항목은 Unity Editor에서 직접 확인이 필요해:
  - {항목 목록}

{파일 레벨 폴백으로 실행된 경우에만 아래 팁을 추가:}
💡 Unity Editor를 열고 mcp-unity를 연결하면 재컴파일 + 콘솔 에러를 자동 검증할 수 있어.
   설치: GitHub에서 "CoderGamester/mcp-unity" 검색 → 프로젝트의 .mcp.json.example 참고
```
