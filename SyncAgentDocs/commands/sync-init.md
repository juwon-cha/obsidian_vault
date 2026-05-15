---
description: TO 프로젝트의 컨벤션을 자동 감지해 프로젝트 전용 {ProjectName}_SYNC_GUIDE.md를 생성한다. /sync 실행 전 한 번만 실행하면 됨.
---

입력된 인수: $ARGUMENTS

---

## 개요

`/sync-init`은 동료가 자기 Unity 프로젝트에서 한 번 실행하는 부트스트랩 명령이다.
TO 프로젝트의 매니저 베이스 클래스, 접근 패턴, 이벤트 시스템, SaveData 메커니즘 등을 자동 감지하고,
플러그인에 번들된 `_SYNC_GUIDE.template.md`에 그 값들을 치환해서
`{TO_PATH}/.claude/docs/{ProjectName}_SYNC_GUIDE.md`를 생성한다.

생성된 가이드는 `/sync` 페이즈 실행 시 자동 탐색되어 사용된다.

---

## Step 0 — 입력 파라미터 파싱

`$ARGUMENTS`에서 옵션 파싱:

```
--to     <경로>          TO 프로젝트 루트 (생략 시 현재 디렉토리)
--name   <이름>          가이드 파일명 prefix (예: PM → PM_SYNC_GUIDE.md). 생략 시 폴더명에서 추론.
--from-project <이름>    FROM 프로젝트 이름 (예: BD, BunkerDefense). 생략 시 사용자에게 질문.
--force                  기존 가이드가 있어도 덮어쓰기
```

`--to` 미지정 시:
```bash
pwd
ls Assets 2>/dev/null && echo "UNITY_PROJECT" || echo "NOT_UNITY"
```
Unity 프로젝트 아니면 오류 보고 후 중단.

---

## Step 1 — 기존 가이드 존재 확인

```bash
existing=$(ls "{to}"/.claude/docs/*_SYNC_GUIDE.md 2>/dev/null | head -1)
[ -n "$existing" ] && echo "EXISTING: $existing"
```

기존 파일이 있고 `--force`가 없으면:
```
⚠️ 이미 가이드가 존재해: {경로}
   덮어쓰려면 --force 플래그 추가, 다른 이름으로 만들려면 --name 옵션 사용.
   기존 가이드를 검토만 하려면 그대로 두고 /sync 실행하면 돼.
```
→ 중단

---

## Step 2 — TO 프로젝트 컨벤션 자동 감지

다음 패턴을 grep으로 탐지한다. 모두 `{to}/Assets` 하위에서 검색.

### 2-A. 매니저 베이스 클래스

```bash
# "Manager" 접미사를 가진 클래스가 상속하는 베이스 클래스 후보 추출
grep -hrE "class\s+\w+Manager\s*:\s*\w+" "{to}/Assets" --include="*.cs" 2>/dev/null \
  | sed -E 's/.*class\s+\w+Manager\s*:\s*(\w+).*/\1/' \
  | sort | uniq -c | sort -rn | head -5
```

**후보 해석:**
- 빈도 1위가 `BaseManager` / `BaseService` / `MonoBehaviour` 등 → **TO_BASE_MANAGER** 결정 후보
- 단일 후보면 자동 확정, 복수 후보면 사용자에게 AskUserQuestion으로 선택 요청

```bash
# 베이스 클래스 자체가 MonoBehaviour 상속하는지 확인 → POCO인지 MB인지 판별
grep -hE "class\s+{후보}\s*:\s*\w+" "{to}/Assets" --include="*.cs"
```

→ `MonoBehaviour` 상속이면 **`TO_BASE_TYPE = MonoBehaviour`**, 아니면 `POCO`.

### 2-B. 매니저 접근 패턴

```bash
# 3가지 접근 패턴 빈도 비교
pat1=$(grep -rE "Managers\.Instance\.GetManager<" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
pat2=$(grep -rE "ServiceAccessor\.Get<" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
pat3=$(grep -rE "ServiceLocator\.Get<" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
pat4=$(grep -rE "DI\.Resolve<\|Container\.Resolve<" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)

echo "Managers.Instance.GetManager<>: $pat1"
echo "ServiceAccessor.Get<>:          $pat2"
echo "ServiceLocator.Get<>:           $pat3"
echo "DI/Container.Resolve<>:         $pat4"
```

**해석:**
- 최다 빈도 패턴을 **TO_ACCESSOR**로 확정
- 모두 0이면 사용자에게 질문 (`AskUserQuestion`)

### 2-C. 이벤트 시스템

```bash
em_static=$(grep -rE "EventManager\.(Subscribe|Dispatch|Unsubscribe)" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
mb_inst=$(grep -rE "MessageBroker\.(Subscribe|Publish|PublishSafe)" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
unirx=$(grep -rE "ReactiveProperty|Observable\.(Timer|Interval)" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)

echo "EventManager (static):  $em_static"
echo "MessageBroker (DI):     $mb_inst"
echo "UniRx Reactive:         $unirx"
```

**해석:**
- 최다 빈도가 `EventManager` static → **TO_EVENT = "EventManager-static"**
- `MessageBroker` → **TO_EVENT = "MessageBroker-DI"**
- 둘 다 있으면 사용자 질문

### 2-D. 리소스 로딩

```bash
res_load=$(grep -rE "Resources\.Load" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
addr=$(grep -rE "Addressables\.|LoadAssetAsync<\|AddressableGroup" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
res_mgr=$(grep -rE "ResourceManager\.LoadResource<" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)

echo "Resources.Load:               $res_load"
echo "Addressables direct:          $addr"
echo "ResourceManager wrapper:      $res_mgr"
```

**해석:** 최다 빈도를 **TO_RESOURCE_LOAD**로 확정. 모두 0이면 "Resources.Load (기본)"로 가정.

### 2-E. SaveData 메커니즘

```bash
save_typed=$(grep -rE "SaveDataAsync\(ESaveDataType" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
save_player=$(grep -rE "SavePlayerDataAsync\(" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
firebase=$(grep -rE "FirebaseKeys\.\|FirebaseDatabase" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)

echo "SaveDataAsync(ESaveDataType): $save_typed"
echo "SavePlayerDataAsync (legacy): $save_player"
echo "Firebase keys system:         $firebase"
```

**해석:**
- `SaveDataAsync(ESaveDataType, data)` 빈도 ≥ 1 → 타입 기반 시스템 사용
- `SavePlayerDataAsync` 빈도 ≥ 1 → 레거시 통합 저장 패턴
- 둘 다 있으면 신·구 혼재 → 사용자 결정

### 2-F. Localization

```bash
loc_mgr=$(grep -rE "LocalizationManager\.GetLocalizedText" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
unity_loc=$(grep -rE "LocalizeStringEvent\|LocalizedString" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)

echo "LocalizationManager wrapper:  $loc_mgr"
echo "Unity Localization direct:    $unity_loc"
```

### 2-G. 시간 시스템

```bash
server_time=$(grep -rE "ServerTimeManager\.NowUnscaled\|ServerTimeManager\.Now" "{to}/Assets" --include="*.cs" 2>/dev/null | wc -l)
echo "ServerTimeManager:            $server_time"
```

### 2-H. 스크립트 루트 경로

```bash
# 가장 깊은 매니저 경로 추출
sample_path=$(find "{to}/Assets" -name "*Manager.cs" -type f 2>/dev/null | head -1)
scripts_root=$(echo "$sample_path" | sed -E 's|/Managers/.*||;s|/Core/.*||;s|/Managers.cs||')
echo "Scripts root: $scripts_root"
```

### 2-I. Managers 등록 파일

```bash
managers_file=$(find "{to}/Assets" -name "Managers.cs" -o -name "ManagerFactory.cs" -o -name "ServiceInstaller.cs" 2>/dev/null | head -3)
echo "Manager registration file: $managers_file"
```

---

## Step 3 — 감지 결과 요약 + 사용자 확인

```
🔍 TO 프로젝트 컨벤션 감지 결과:

  매니저 베이스 클래스:    BaseManager (MonoBehaviour)         [확정]
  매니저 접근 패턴:        Managers.Instance.GetManager<T>()    [확정 — 47건]
  이벤트 시스템:           EventManager (static)                [확정 — 134건]
  리소스 로딩:             ResourceManager.LoadResource<T>()    [확정 — 23건]
  SaveData 메커니즘:       SaveDataAsync(ESaveDataType, data)   [확정 — 18건]
  Localization:           LocalizationManager.GetLocalizedText [확정 — 56건]
  시간 시스템:             ServerTimeManager.NowUnscaled        [확정 — 12건]
  스크립트 루트:           Assets/_Project/1_Scripts/
  Managers 등록 파일:      Assets/_Project/1_Scripts/Core/Managers/Managers.cs

  FROM 프로젝트 이름:      ???  ← 미지정 시 질문
  TO 프로젝트 이름 (가이드 prefix): WiggleDefender → "WD"

  이대로 진행할까?
    y → 가이드 생성
    e → 수동 수정 (각 항목 다시 질문)
    n → 중단
```

### 미감지·복수 후보 항목 처리

각 항목이 자동 확정되지 못한 경우 `AskUserQuestion`으로 사용자에게 선택지 제공.
예: 이벤트 시스템에서 EventManager·MessageBroker 둘 다 발견되면:

```
question: "이 프로젝트의 메인 이벤트 시스템을 선택해줘"
header: "이벤트 시스템"
options:
  - EventManager (static) — 사용 47건
  - MessageBroker (DI) — 사용 134건
  - 둘 다 (분석 문서에 명시)
```

### FROM 프로젝트 이름

```
question: "FROM 프로젝트 (이식 소스)는 어떤 컨벤션을 가지고 있어?"
header: "FROM 프로젝트"
options:
  - BunkerDefense (BD) — BaseService, ServiceAccessor, MessageBroker, UniRx
  - 다른 프로젝트 — 수동 명세
```

"다른 프로젝트" 선택 시:
- FROM 매니저 베이스 클래스 입력
- FROM 매니저 접근 패턴 입력
- FROM 이벤트 시스템 입력
- (등등)

---

## Step 4 — 가이드 생성

`_SYNC_GUIDE.template.md`를 Read로 읽고 아래 치환자를 채운다:

| 치환자 | 값 |
|--------|------|
| `{{FROM_PROJECT}}` | FROM 프로젝트 이름 (예: BunkerDefense) |
| `{{FROM_PROJECT_SHORT}}` | FROM 약어 (예: BD) |
| `{{TO_PROJECT}}` | TO 프로젝트 이름 |
| `{{TO_PROJECT_SHORT}}` | TO 약어 (예: WD) |
| `{{FROM_BASE_MANAGER}}` | FROM 베이스 클래스 (예: BaseService) |
| `{{TO_BASE_MANAGER}}` | TO 베이스 클래스 (예: BaseManager) |
| `{{FROM_BASE_TYPE}}` | POCO 또는 MonoBehaviour |
| `{{TO_BASE_TYPE}}` | POCO 또는 MonoBehaviour |
| `{{FROM_ACCESSOR}}` | FROM 접근 패턴 (예: ServiceAccessor.Get<T>()) |
| `{{TO_ACCESSOR}}` | TO 접근 패턴 (예: Managers.Instance.GetManager<T>()) |
| `{{FROM_EVENT}}` | FROM 이벤트 시스템 |
| `{{TO_EVENT}}` | TO 이벤트 시스템 |
| `{{FROM_RESOURCE_LOAD}}` | FROM 리소스 로딩 |
| `{{TO_RESOURCE_LOAD}}` | TO 리소스 로딩 |
| `{{FROM_SAVE}}` | FROM SaveData 패턴 |
| `{{TO_SAVE}}` | TO SaveData 패턴 |
| `{{FROM_LOCALIZATION}}` | FROM Localization |
| `{{TO_LOCALIZATION}}` | TO Localization |
| `{{FROM_TIME}}` | FROM 시간 시스템 |
| `{{TO_TIME}}` | TO 시간 시스템 |
| `{{TO_SCRIPTS_ROOT}}` | TO 스크립트 루트 경로 |
| `{{TO_MANAGERS_FILE}}` | TO Managers 등록 파일 경로 |
| `{{GUIDE_NAME}}` | 생성될 가이드 파일명 (예: WD_SYNC_GUIDE.md) |

치환 결과를 다음 경로에 저장:

```bash
mkdir -p "{to}/.claude/docs"
{치환 결과를 Write 도구로 저장}
out_path="{to}/.claude/docs/{TO_PROJECT_SHORT}_SYNC_GUIDE.md"
```

---

## Step 5 — Sync 상태 파일에 가이드 경로 등록 (있는 경우)

```bash
SYNC_BASE=$([ -d "$HOME/Documents/obsidian_vault" ] && echo "$HOME/Documents/obsidian_vault/Sync" || echo "$HOME/Downloads/Sync")
STATE_DIR="$SYNC_BASE/$(basename {to})"
state_file="$STATE_DIR/.sync_state.json"

if [ -f "$state_file" ]; then
  python3 -c "
import json
with open('$state_file', 'r') as f:
    state = json.load(f)
state['sync_guide_path'] = '$out_path'
with open('$state_file', 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
print('상태 파일에 sync_guide_path 등록 완료')
"
fi
```

상태 파일이 없으면 스킵 (아직 `/sync`를 실행하지 않은 상태). 첫 `/sync` 실행 시 자동 등록됨.

---

## Step 6 — 다음 단계 안내

```
✅ {TO_PROJECT_SHORT}_SYNC_GUIDE.md 생성 완료
   경로: {out_path}

📋 다음 단계:
   1. 생성된 가이드를 한 번 검토해줘 — 자동 감지가 놓친 프로젝트 특이 규칙이 있으면 수동 추가
   2. /sync 명령으로 실제 이식 작업 시작
      예: /sync --from origin/temp-bunker --system BattlePass --keys BattlePassManager,BattlePass

💡 가이드를 다시 생성하려면 /sync-init --force
   가이드 일부만 수정하려면 위 파일을 직접 편집
```

---

## 완료 보고 형식

```
## /sync-init 결과
- 감지된 컨벤션 N개 (자동 확정 N / 사용자 확인 N)
- 생성된 가이드: {경로}
- 상태 파일 연결: ✅ / ⚠️ 미실행 (첫 /sync 시 자동)
- ⚠️ 수동 검토 권장 항목: {목록 또는 "없음"}
```

---

## 도움말

```
사용법:
  /sync-init
      현재 디렉토리에서 자동 감지 + 가이드 생성

  /sync-init --to /path/to/project
      특정 경로의 프로젝트에서 실행

  /sync-init --name PM --from-project BD
      대화 없이 즉시 생성 (PM_SYNC_GUIDE.md, FROM=BD)

  /sync-init --force
      기존 가이드 덮어쓰기
```
