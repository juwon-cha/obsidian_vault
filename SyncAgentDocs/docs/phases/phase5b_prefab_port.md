# Phase 5-B — 프리팹 자동 sync 실행

## 입력 파라미터
- FROM_LOCAL: {from_local}   ← Phase 0에서 확정된 실제 로컬 경로
- TO_PATH: {to}
- SYSTEM: {system}
- KEYS: {keys}
- OUTPUT_DIR: {output_dir}   ← 산출물 저장 경로
- PREFAB_LIST: `{output_dir}/{system}_PREFAB_PACKAGE_LIST.md`

## 참조 문서
아래 파일을 Read로 읽는다:
- `{output_dir}/{system}_PREFAB_PACKAGE_LIST.md`

## 작업

Phase 5-A 목록을 기반으로 FROM → TO 프리팹 sync을 실행한다.
**목록의 의존성 순서(리프 → 루트)를 반드시 지킨다.**
Unity 에디터 없이 파일 시스템에서 직접 복사·GUID 교체로 처리한다.

---

### Step 1. 목록 확인 — 처리 대상 분류

Phase 5-A 목록에서 처리 대상만 추린다:
- ✅ 처리 대상: **신규 복사** + **⚠️ 업데이트 필요**
- ❌ 처리 제외: **⬛ 스킵** (구조 동일) + **🔵 수동 판단** (TO가 의도적으로 다른 구조)

🔵 수동 판단 항목은 리포트에 목록만 남기고 sync하지 않는다.

---

### Step 2. 각 프리팹 GUID·fileID 의존성 추출

처리 대상 프리팹마다 **FROM 프리팹 파일**을 Read로 읽어서 모든 GUID 참조를 **두 가지 패턴으로 반드시 각각** 추출한다.

> **⚠️ Unity 프리팹 YAML에는 GUID 포맷이 두 가지 공존한다.**
> 표준 포맷만 추출하면 `LocalizeStringEvent`의 테이블 참조가 **조용히 누락**된다.
> 아래 두 명령어를 모두 실행하고 결과를 합산해야 한다.

```bash
# ① 표준 GUID 추출 ({fileID: x, guid: xxx, type: y} 포맷)
# → m_Script, m_SourcePrefab, m_Sprite, m_Texture, m_Material, m_Font 등
grep -oP '(?<=guid: )[a-f0-9]{32}' "{from_prefab}" | sort -u

# ② 임베디드 GUID 추출 (m_TableCollectionName: GUID:xxx 포맷)
# → LocalizeStringEvent 컴포넌트, 일부 SpriteAtlas 등에서 사용
grep -oP '(?<=GUID:)[a-f0-9]{32}' "{from_prefab}" | sort -u
```

두 결과를 합쳐서 전체 GUID 목록으로 처리한다.

**스프라이트·텍스처는 GUID와 fileID를 함께 기록한다:**
```yaml
# fileID가 0이면 에셋 자체 참조
# fileID가 21300000 이상이면 텍스처 내 서브 스프라이트 참조
m_Sprite: {fileID: 21300004, guid: xxxxxxxx, type: 3}
```

각 GUID → FROM `Assets/`의 `.meta` 파일 역추적 → 파일명·확장자 확인:
```bash
# 파일명에 공백이 있을 수 있으므로 결과를 그대로 사용
grep -rl "{guid}" "{from}/Assets" --include="*.meta" 2>/dev/null
```

> **GUID 역추적 실패 시**: FROM Assets/에서 찾지 못한 GUID는 조용히 스킵하지 않는다.
> Step 3-P(PackageCache 탐색)를 시도하고, 그래도 못 찾으면
> **⚠️ 미해결 GUID** 목록에 기록하고 계속 진행한다.

---

### Step 2-L. LocalizeStringEvent 사전 스캔 (필수 — 재귀 포함)

> **이 단계는 Step 2 직후 반드시 실행한다.**
> LocalizeStringEvent의 `m_StringReference`는 임베디드 GUID 포맷을 사용하므로
> Step 2의 ①번 추출 명령어에 걸리지 않는다. 별도 스캔이 필요하다.

#### A. 처리 대상 프리팹 전체 — LocalizeStringEvent 카운트 스캔

처리 대상 프리팹(신규 + 업데이트)과 그 중첩 자식 프리팹까지 **재귀적으로** 스캔한다:

```bash
# FROM 프리팹의 LocalizeStringEvent 수 확인
grep -c "LocalizeStringEvent" "{from_prefab}" 2>/dev/null || echo "0"

# 중첩 자식 프리팹이 있는 경우 각각도 확인
# (Step 3의 재귀 스캔에서 발견된 자식 프리팹 경로 사용)
for child_prefab in {재귀 스캔에서 발견된 자식 프리팹 경로 목록}; do
  count=$(grep -c "LocalizeStringEvent" "$child_prefab" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "$count 개 발견: $child_prefab"
  fi
done
```

결과를 아래 표로 기록한다:

| 프리팹 | FROM LocalizeStringEvent 수 | 비고 |
|--------|---------------------------|------|
| {파일명}.prefab | N개 | 처리 필요 |
| {파일명}.prefab | 0개 | 스킵 |

#### B. LocalizeStringEvent가 있는 프리팹 — 필드 상세 추출

카운트가 1개 이상인 프리팹마다 FROM 파일에서 아래 필드를 추출한다:

```bash
# m_TableCollectionName (테이블 GUID), m_KeyId (항목 ID) 한 번에 추출
grep -E "m_TableCollectionName|m_KeyId" "{from_prefab}"
```

예상 출력:
```
      m_TableCollectionName: GUID:b70af4818baaa49728f7235359d344b6
      m_KeyId: 22919712571645957
      m_TableCollectionName: GUID:b70af4818baaa49728f7235359d344b6
      m_KeyId: 57020548486520832
```

#### C. Table Collection GUID — FROM vs TO 비교

```bash
# FROM 테이블 Collection asset GUID 확인
grep -rl "StringTableCollection" "{from}/Assets" --include="*.asset" -l 2>/dev/null | head -3
# 각 파일의 guid 확인
grep "^guid:" {위에서_찾은_asset경로}.meta

# TO 테이블 Collection asset GUID 확인
grep -rl "StringTableCollection" "{to}/Assets" --include="*.asset" -l 2>/dev/null | head -3
grep "^guid:" {위에서_찾은_asset경로}.meta
```

| 결과 | 처리 |
|------|------|
| FROM GUID == TO GUID | `m_TableCollectionName` 교체 불필요, m_KeyId만 확인 |
| FROM GUID != TO GUID | 프리팹 내 모든 `m_TableCollectionName: GUID:{from_guid}` → `GUID:{to_guid}` 교체 |

#### D. m_KeyId — FROM vs TO Table 일치 확인

Table Collection GUID 처리 후, 각 KeyId가 TO의 Localization Table에 존재하는지 확인한다:

```bash
# TO Localization Table asset에서 KeyId 존재 확인
grep -r "{key_id}" "{to}/Assets" --include="*.asset" -l 2>/dev/null
```

| 결과 | 처리 |
|------|------|
| TO Table에 있음 | m_KeyId 그대로 유지 |
| TO Table에 없음 | 키 이름을 FROM asset에서 찾아 TO Table에 키가 있는지 이름으로 재탐색 |
| 이름으로도 없음 | 리포트 `⚠️ 누락 Localization 키` 섹션에 기록 후 계속 |

---

### Step 3. 의존성별 처리 방법 결정

| 파일 종류 | 판별 | 처리 |
|---------|------|------|
| `.prefab` (m_SourcePrefab) | Phase 5-A 목록에 있음 | 의존성 순서대로 처리됨 |
| `.prefab` (m_SourcePrefab) | Phase 5-A 목록에 없음 | ⚠️ 누락 — 목록에 추가 후 먼저 처리 |
| `.cs` (스크립트) | TO에 sync됨 | `asset` 스킵, `.meta`만 복사 |
| `.png`/`.sprite` (fileID=0 또는 단일 스프라이트) | TO에 같은 파일명 있음 | GUID → TO 버전으로 교체 |
| `.png`/`.sprite` (fileID=0 또는 단일 스프라이트) | TO에 없음 | FROM asset + meta 복사 |
| `.png` (fileID≥21300000, 서브 스프라이트) | TO에 같은 파일명 있음 | Step 3-S 수행 |
| `.png` (fileID≥21300000, 서브 스프라이트) | TO에 없음 | FROM asset + meta 복사 |
| `.spriteatlas` | TO에 같은 파일명 있음 | GUID 교체 |
| `.spriteatlas` | TO에 없음 | FROM asset + meta 복사 |
| `.mat`/`.ttf` 등 | TO에 같은 파일명 있음 | GUID 교체 |
| `.mat`/`.ttf` 등 | TO에 없음 | FROM asset + meta 복사 |
| 패키지 스크립트 (Localization 등) | Assets/에서 못 찾음 | Step 3-P 수행 |

**파일명 매칭 시 공백 처리 주의:**
```bash
# 파일명에 공백이 있을 수 있으므로 반드시 따옴표로 감싸서 find 실행
find "{to}/Assets" -name "{파일명}.png" 2>/dev/null
# 못 찾으면 대소문자 무시 검색도 시도
find "{to}/Assets" -iname "{파일명}.png" 2>/dev/null
```

> **m_SourcePrefab 누락 감지**: Step 2에서 추출한 `.prefab` GUID가 Phase 5-A 목록에
> 없는 경우 — 재귀 스캔에서 놓친 것이므로 즉시 FROM에서 해당 프리팹을 찾아
> 처리 목록 맨 앞에 추가하고 동일한 GUID 교체 절차를 수행한다.

---

### Step 3-S. 서브 스프라이트 검증 (fileID ≥ 21300000인 경우)

텍스처 내 슬라이싱된 스프라이트는 GUID(텍스처 파일)와 fileID(슬라이스 번호)로 식별된다.
TO에 같은 파일명의 텍스처가 있어도, 슬라이스 설정이 다르면 해당 fileID의 스프라이트가 없을 수 있다.

1. TO에서 같은 파일명의 `.meta` 파일을 읽어 FROM의 fileID가 존재하는지 확인:
```bash
# TO .meta 파일에서 해당 fileID를 가진 스프라이트 항목 탐색
grep -A5 "fileID: {fileID}" "{to}/Assets/.../{파일명}.png.meta" 2>/dev/null
```

2. **fileID가 TO .meta에 존재하면**: GUID만 TO 버전으로 교체 (fileID는 유지)
3. **fileID가 TO .meta에 없으면**: FROM asset + meta 통째로 복사 (TO의 기존 파일 덮어쓰기 전 확인)

> **덮어쓰기 전 확인**: TO에 이미 같은 파일명 텍스처가 있고 FROM 버전으로 교체해야 할 때,
> 사용자에게 "TO의 기존 텍스처를 FROM 버전으로 교체할까?" 확인 후 진행한다.

---

### Step 3-P. 패키지 스크립트 GUID 매핑 (Assets/에서 못 찾은 GUID)

Step 2에서 추출한 GUID 중 TO `Assets/`에서 대응 파일을 찾지 못한 경우,
FROM의 `Library/PackageCache`에서 역추적한다:

```bash
grep -rl "{미해결_guid}" "{from}/Library/PackageCache" --include="*.meta" 2>/dev/null
```

파일명 확인 후 TO PackageCache에서 동일 파일명 탐색:
```bash
find "{to}/Library/PackageCache" -name "{파일명}.meta" 2>/dev/null
grep "^guid:" {위에서_찾은_경로}
```

**대표 패키지 스크립트 (자주 등장):**
| 클래스명 | 패키지 |
|---------|--------|
| `LocalizeStringEvent` | com.unity.localization |
| `LocalizedString` | com.unity.localization |
| `TMP_InputField` | com.unity.ugui (TextMeshPro) |
| `LayoutElement`, `ScrollRect`, `RectMask2D`, `Mask` | com.unity.ugui |

> 패키지 버전이 같으면 FROM=TO GUID가 동일 → 교체 불필요.
> PackageCache에서도 못 찾으면 **⚠️ 미해결 GUID** 목록에 기록 후 계속.
> 프리팹에 패키지 스크립트 GUID가 전혀 없으면 Step 3-P 스킵.

---

### Step 3-L. ~~LocalizeStringEvent KeyId 교체~~

> **이 단계는 Step 2-L로 통합 이동되었다.**
> LocalizeStringEvent 처리는 Step 2 직후 Step 2-L에서 수행한다.

---

### Step 4. 프리팹 파일 저장 (의존성 순서대로)

각 프리팹에 대해:
1. FROM 프리팹을 Read로 읽는다
2. Step 2~3-L에서 확정된 GUID 교체를 모두 적용한다
3. 교체된 내용을 TO 경로에 Write로 저장한다
4. FROM `.meta` 파일도 Read → TO 경로에 Write한다

**TO 경로 결정 원칙:**
- FROM `Assets/` 이하 구조 → TO `Assets/` 이하 동일하게 유지
- TO에 없는 폴더는 `mkdir -p`로 생성
- ⚠️ 업데이트 필요 항목: 기존 TO 파일을 FROM 버전으로 덮어쓴다

---

### Step 5. 신규 에셋 복사 (Step 3에서 TO에 없는 것으로 확인된 것)

```bash
cp "{from_asset_path}" "{to_asset_path}"
cp "{from_asset_path}.meta" "{to_asset_path}.meta"
```

---

### Step 6. 사후 검증 패스 — GUID 전수 확인 + LocalizeStringEvent 카운트 비교

> **이 단계는 누락 에셋을 조용히 넘기지 않기 위한 필수 단계다.**
> GUID 해결 여부와 LocalizeStringEvent 보존 여부를 모두 검증한다.

#### A. GUID 전수 확인

sync된 모든 프리팹 파일을 다시 Read로 읽어서 **두 가지 포맷의 GUID를 모두** 추출한 뒤,
각 GUID가 TO에서 해결되는지 확인한다:

```bash
# ① 표준 GUID 전체 추출
grep -oP '(?<=guid: )[a-f0-9]{32}' "{to_prefab}" | sort -u

# ② 임베디드 GUID 전체 추출 (LocalizeStringEvent 포함)
grep -oP '(?<=GUID:)[a-f0-9]{32}' "{to_prefab}" | sort -u

# 각 GUID → TO에서 해결 여부 확인
grep -rl "{guid}" "{to}/Assets" --include="*.meta" 2>/dev/null
# 없으면 PackageCache 확인
grep -rl "{guid}" "{to}/Library/PackageCache" --include="*.meta" 2>/dev/null
```

**GUID 결과 분류:**
| 상태 | 처리 |
|------|------|
| TO Assets/ 또는 PackageCache에서 찾음 | ✅ 정상 |
| 어디에서도 못 찾음 | ⚠️ 미해결 GUID → 리포트에 기록 |

미해결 GUID가 있으면:
1. FROM에서 해당 파일을 다시 역추적한다
2. 파일을 찾으면 즉시 복사한다 (Step 5 재실행)
3. 그래도 못 찾으면 리포트 `⚠️ 미해결 GUID` 섹션에 상세 기록

#### B. LocalizeStringEvent 카운트 비교 (재귀 포함)

Step 2-L에서 기록한 FROM 카운트와 sync된 TO 프리팹의 카운트를 비교한다.
**중첩 자식 프리팹이 있는 경우 자식 프리팹도 각각 비교한다.**

```bash
# sync된 TO 프리팹의 LocalizeStringEvent 수 확인
grep -c "LocalizeStringEvent" "{to_prefab}" 2>/dev/null || echo "0"

# FROM과 TO 한 번에 비교
echo "FROM: $(grep -c 'LocalizeStringEvent' '{from_prefab}')"
echo "TO:   $(grep -c 'LocalizeStringEvent' '{to_prefab}')"
```

| 비교 결과 | 처리 |
|----------|------|
| FROM == TO | ✅ 정상 |
| FROM > TO | ⚠️ LocalizeStringEvent 누락 — FROM에서 누락된 블록을 찾아 TO에 복원 |
| FROM < TO | ⚠️ 예상치 못한 추가 — TO 프리팹에 의도치 않은 컴포넌트 있는지 확인 |

**LocalizeStringEvent 누락 시 복원 절차:**
1. FROM 프리팹에서 `grep -n "LocalizeStringEvent" {from_prefab}`으로 위치 확인
2. 해당 컴포넌트 블록 전체를 Read로 읽어서 TO 프리팹에 추가
3. m_TableCollectionName GUID와 m_KeyId를 Step 2-L C, D 절차로 재처리
4. TO 프리팹 파일을 Write로 저장

#### C. m_StringReference 구조 무결성 확인

LocalizeStringEvent가 있는 프리팹의 m_StringReference 구조가 완전한지 확인한다:

```bash
# m_StringReference 구조 확인 (4개 필드가 모두 있어야 함)
grep -A4 "m_StringReference:" "{to_prefab}" | grep -E "m_TableReference|m_TableCollectionName|m_TableEntryReference|m_KeyId"
```

정상 구조:
```yaml
m_StringReference:
  m_TableReference:
    m_TableCollectionName: GUID:{table_guid}
  m_TableEntryReference:
    m_KeyId: {key_id}
```

4개 필드 중 하나라도 빠지면 해당 컴포넌트 YAML 블록을 FROM에서 다시 복사한다.

---

### Step 7. 처리 완료 리포트 생성

`{OUTPUT_DIR}/{system}_PREFAB_SYNC_REPORT.md` 파일로 저장:

```markdown
## Phase 5-B sync 리포트

### 처리된 프리팹 (신규 + 업데이트)
| 프리팹 | 처리 | TO 경로 |
|--------|------|---------|
| {파일명}.prefab | 신규 복사 | {경로} |
| {파일명}.prefab | 업데이트 (N → M 오브젝트) | {경로} |

### 스킵된 프리팹
| 프리팹 | 이유 |
|--------|------|
| {파일명}.prefab | 구조 동일 |
| {파일명}.prefab | 🔵 TO가 의도적으로 다른 구조 |

### GUID 교체 내역 (스크립트)
| 클래스명 | FROM GUID | TO GUID |

### GUID 교체 내역 (에셋)
| 에셋명 | FROM GUID | TO GUID |

### 서브 스프라이트 처리 내역
| 텍스처 파일명 | fileID | 처리 |
|-------------|--------|------|
| {파일명}.png | 21300004 | TO .meta에 존재 → GUID 교체 |
| {파일명}.png | 21300006 | TO .meta에 없음 → FROM 전체 복사 |

### 패키지 GUID 처리
| 클래스명 | FROM GUID | TO GUID | 결과 |

### 신규 복사된 에셋 (FROM에만 있던 것)
- {파일명}.png → {TO 경로}

### ⚠️ 미해결 GUID (사후 검증에서 발견된 누락 에셋)
| 프리팹 | GUID | FROM 파일명 | 조치 |
|--------|------|------------|------|
| {파일명}.prefab | {guid} | {파일명} | 재복사 완료 / 수동 확인 필요 |
(없으면 이 섹션 생략)

### ⚠️ 누락 Localization 키
| 프리팹 | 키 이름 | 비고 |
|--------|---------|------|
| {파일명}.prefab | {키_이름} | TO Localization Table에 추가 필요 |
(없으면 이 섹션 생략)

### ⚠️ 수동 확인 필요
- UIManager 등록 필요: {클래스명 목록}
- SerializeField 배열 확인: {항목}
- 🔵 수동 판단 프리팹: {파일명}
```

---

## 완료 보고 형식

```
## Phase 5-B 결과
- 신규 복사: N개 / 업데이트: N개 / 스킵: N개 / 수동 판단: N개
- GUID 교체: N건 (스크립트 N / 에셋 N / 패키지 N)
- 서브 스프라이트 처리: N건 (GUID 교체 N / FROM 복사 N)
- 신규 에셋: N개
- 사후 검증: ✅ 미해결 GUID 없음 / ⚠️ 미해결 GUID N건 (재복사 N건 / 수동 확인 필요 N건)
- 리포트: {OUTPUT_DIR}/{system}_PREFAB_SYNC_REPORT.md
```
