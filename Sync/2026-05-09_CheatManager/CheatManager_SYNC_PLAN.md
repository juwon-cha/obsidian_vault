# CheatManager SYNC_PLAN
생성일: 2026-05-09
FROM: /tmp/sync_CheatManager_1778331022
TO: /Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender
브랜치: juwon/CheatManager

---

## 섹션 0. FROM 파일 전수조사

| 파일 | FROM 존재 | 비고 |
|------|-----------|------|
| CheatManager.cs | O | Geuneda.Services, ITickService 사용 (WD와 구조 다름) |
| CheatCommandLibrary.cs | O | sync 금지 |
| Editor/CheatManagerWindow.cs | O | UI Toolkit 기반, 874줄 |
| Editor/CheatManagerWindow.uxml | O | TwoPaneSplitView 구조 |
| Editor/CheatManagerWindow.uss | O | UI Toolkit 스타일시트 |
| Editor/CardCheatWindow.cs | O | WD에도 동일 파일 존재 (이번 sync 범위 외) |
| Editor/CardCheatWindow.uxml | O | 범위 외 |
| Editor/CardCheatWindow.uss | O | 범위 외 |
| SandboxModeUtility.cs | O | 범위 외 |
| TimeScaleApplier.cs | O | 범위 외 |

**FROM 총 파일 수: 10개 (meta 제외)**
**이번 sync 대상: 3개 (CheatManagerWindow.cs / .uxml / .uss)**

---

## 섹션 1. TO 현재 상태 비교

| 파일 | WD 존재 | 현재 구현 방식 | 비고 |
|------|---------|---------------|------|
| CheatManagerWindow.cs | O | IMGUI (OnGUI + EditorGUILayout), 366줄 | 교체 대상 |
| CheatManagerWindow.uxml | X | 없음 | 신규 추가 |
| CheatManagerWindow.uss | X | 없음 | 신규 추가 |
| CheatManager.cs | O | BaseManager 상속, ICheatRuntime 구현 | 변경 없음 |
| CheatCommandLibrary.cs | O | General/Economy/Stage 카테고리 | 변경 금지 |

**WD Editor/ 폴더 내 기존 파일:**
- CardCheatWindow.cs / .uxml / .uss (범위 외)
- StageBalanceTesterWindow.cs (범위 외)
- CheatManagerWindow.cs (교체 대상)

---

## 섹션 2. CheatManagerWindow.cs FROM 원본 분석

### FROM 방식: UI Toolkit 기반
- `CreateGUI()` 진입점, UXML로 구조 로드, USS로 스타일 적용
- `TwoPaneSplitView` — 좌측 카테고리 ListView (160px 고정) + 우측 커맨드 패널
- `ToolbarSearchField` — 실시간 필터링
- `Foldout` — 카테고리별 커맨드 그룹핑 (전체 선택 시)
- `ListView` — 카테고리 내비게이션
- Log 패널 — Foldout 접힘/펼침, ScrollView 내 VisualElement 동적 추가

### 패턴 체크리스트

| 패턴 | FROM 존재 여부 | WD 적용 가능 여부 |
|------|--------------|-----------------|
| `using Geuneda.Services` | **없음** (CheatManager.cs에만 있음) | 해당 없음 |
| `ITickService` | **없음** (CheatManager.cs에만 있음) | 해당 없음 |
| `ManagerFactory` | **없음** | 해당 없음 |
| `using UnityEditor.UIElements` | O | O (WD에 UnityEditor.UIElements 사용 가능) |
| `Managers.Instance.GetManager<T>()` | O | O (WD 표준 패턴) |
| `ECurrencyType` | O | O (WD에 존재) |
| `ICheatRuntime` | O | O (WD CheatManager.cs에 정의됨) |
| `IBaseManager` | O | O (WD에 존재) |
| `RLog.LogException` | O | O (WD에 존재) |
| `LocalizationManager.GetLocalizedText()` | O | O (WD 표준 패턴 준수) |
| `CurrencyManager` | O | O (WD에 존재) |
| `DateTime.Now` | O (Log 메서드에서 타임스탬프용) | ⚠️ 주의: CLAUDE.md 금지 사항. 로그 표시용이므로 `ServerTimeManager.NowUnscaled` 대체 불필요 (화면 표시용 시각). 단, 정책에 따라 교체 검토 필요 |

### FROM 주요 메서드 목록

| 메서드 | 역할 |
|--------|------|
| `Open()` | MenuItem 진입점, minSize 700×500 |
| `CreateGUI()` | UXML 로드, USS 적용, 이벤트 바인딩 |
| `OnDestroy()` | 이벤트 구독 해제 |
| `InitializeUIReferences()` | Q<T>() 로 UI 요소 참조 취득 |
| `BindEvents()` | 검색, 버튼, ListView 이벤트 등록 |
| `OnPlayModeStateChanged()` | PlayMode 전환 시 경고박스/캐시 갱신 |
| `UpdateWarningBox()` | play mode 아니면 경고 표시 |
| `RefreshCommands()` | CheatCommandLibrary.CreateCommands() 호출 후 재구성 |
| `BuildCategoryList()` | _categoryItems 재구성 + ListView Rebuild |
| `GetCategoryOrder()` | Stage→Economy→General→기타 정렬 |
| `MakeCategoryItem()` / `BindCategoryItem()` | ListView 셀 생성/바인딩 |
| `OnCategorySelectionChanged()` | 카테고리 선택 시 우측 패널 갱신 |
| `RebuildCommandList()` | _commandContainer 재구성 |
| `GetFilteredCommands()` | 검색어 필터 적용 |
| `CreateCategoryFoldout()` | 전체 뷰에서 카테고리별 Foldout 생성 |
| `CreateCommandElement()` | 커맨드 카드 UI 생성 |
| `CreateParameterField()` | 파라미터 타입별 입력 필드 디스패치 |
| `CreateIntField()` | IntegerField + 범위 클램핑 |
| `CreateFloatField()` | FloatField + 범위 클램핑 |
| `CreateBoolField()` | Toggle |
| `CreateStringField()` | TextField |
| `CreateEnumField()` | EnumField 또는 ECurrencyType 전용 검색 UI |
| `CreateCurrencyEnumField()` | 검색+드롭다운 복합 UI (ECurrencyType 전용) |
| `GetCurrencyDisplayInfoList()` | 캐시된 통화 표시명 리스트 반환 |
| `GetCurrencyDisplayName()` | 런타임 시 Localization 적용, 아닐 시 enum 이름 |
| `ClearCurrencyDisplayCache()` | PlayMode 전환 시 캐시 초기화 |
| `GetOrCreateState()` | 커맨드별 상태 생성/조회 |
| `ResetState()` | 파라미터 초기값 복구 |
| `ExecuteCommandAsync()` | UniTaskVoid, CheatCommandContext 생성 후 실행 |
| `ShowResultMessage()` | 성공/실패 레이블 동적 추가 |
| `SetAllFoldoutsState()` | 모두 접기/펼치기 |
| `UpdateCommandCount()` | 커맨드 수 레이블 갱신 |
| `UpdateStatusBar()` | 상태바 텍스트 갱신 |
| `Log()` | ICheatRuntime 구현, 로그 컨테이너에 Label 추가 |
| `RequireManager<T>()` | ICheatRuntime 구현, PlayMode 체크 후 매니저 반환 |

---

## 섹션 3. 의존성 확인 표

| 타입/인터페이스 | WD 존재 | 위치 | 비고 |
|----------------|---------|------|------|
| `ICheatRuntime` | O | CheatManager.cs에 정의 | `Log()`, `RequireManager<T>()` 인터페이스 |
| `ECurrencyType` | O | Currency 관련 enum | FROM과 호환 |
| `IBaseManager` | O | 매니저 시스템 | FROM과 호환 |
| `CheatCommand` | O | CheatCommandLibrary.cs | 변경 금지 파일에 정의 |
| `CheatCommandLibrary.CreateCommands()` | O | CheatCommandLibrary.cs | FROM과 동일 호출 방식 |
| `CheatCommandParameter` | O | CheatCommandLibrary.cs | FROM과 호환 |
| `CheatParameterType` | O | CheatCommandLibrary.cs | Int/Float/Bool/Enum/String |
| `CheatCommandContext` | O | CheatManager.cs 또는 별도 | FROM과 동일 생성자 시그니처 확인 필요 |
| `Managers.Instance.GetManager<T>()` | O | Managers.cs | WD 표준 패턴 |
| `CurrencyManager` | O | 매니저 시스템 | GetCurrencyData() 메서드 존재 확인 필요 |
| `LocalizationManager.GetLocalizedText()` | O | 매니저 시스템 | WD 표준 패턴 준수 |
| `RLog.LogException()` | O | 로깅 시스템 | FROM과 동일 |
| `VisualTreeAsset` | O | UnityEngine.UIElements | Unity 6 기본 제공 |
| `TwoPaneSplitView` | O | UnityEngine.UIElements | Unity 6 기본 제공 |
| `ToolbarSearchField` | O | UnityEditor.UIElements | Editor 전용 |

**확인 필요 항목:**
- `CheatCommandContext` 생성자 — `new CheatCommandContext(this, parameterValues)` 형식이 WD와 동일한지
- `CurrencyManager.GetCurrencyData(ECurrencyType)` — 반환 타입과 `currencyName` 프로퍼티 존재 여부

---

## 섹션 4. CheatManagerWindow.cs 수정 사항

FROM 파일 (`/tmp/sync_CheatManager_1778331022/.../CheatManagerWindow.cs`)은 **이미 WD 호환 코드**이다.
`using Geuneda.Services`는 `CheatManagerWindow.cs`에 없고 `CheatManager.cs`에만 존재하므로, 제거 작업 불필요.

### 적용 시 변경 항목 (없음 — 무수정 적용 가능)

| 항목 | 처리 | 이유 |
|------|------|------|
| `using Geuneda.Services` | 불필요 | FROM CheatManagerWindow.cs에 없음 |
| `ITickService` | 불필요 | FROM CheatManagerWindow.cs에 없음 |
| UXML 경로 상수 | 그대로 사용 | `Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.uxml` — WD 경로 동일 |
| USS 경로 상수 | 그대로 사용 | 동일 |
| `Managers.Instance.GetManager<T>()` | 그대로 사용 | WD 표준 패턴 |
| `DateTime.Now` | 검토 | Log 타임스탬프용. CLAUDE.md 금지 사항이나 화면 표시용(로그 시각)이므로 예외 인정 가능. 보수적으로 적용하려면 `ServerTimeManager.NowUnscaled`로 교체 |
| `minSize` | 변경 없음 | FROM: 700×500, WD: 520×480 — FROM 값 적용됨 |

### 최종 판단: FROM 파일 그대로 복사 적용 가능
수정 없이 FROM 파일을 WD 경로에 복사하면 된다.

---

## 섹션 5. sync 체크리스트

### 파일 작업
- [ ] **CheatManagerWindow.cs** — FROM 버전으로 전체 교체 (수정 불필요)
  - FROM: `/tmp/sync_CheatManager_1778331022/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.cs`
  - TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.cs`
- [ ] **CheatManagerWindow.uxml** — FROM에서 신규 복사
  - FROM: `/tmp/sync_CheatManager_1778331022/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.uxml`
  - TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.uxml`
- [ ] **CheatManagerWindow.uss** — FROM에서 신규 복사
  - FROM: `/tmp/sync_CheatManager_1778331022/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.uss`
  - TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/Cheat/Editor/CheatManagerWindow.uss`

### 사전 검증
- [ ] `CheatCommandContext` 생성자 시그니처 확인 — `new CheatCommandContext(ICheatRuntime, Dictionary<string,object>)` 형식인지
- [ ] `CurrencyManager.GetCurrencyData(ECurrencyType)` 존재 및 `.currencyName` 프로퍼티 확인
- [ ] 카테고리 순서 확인 — WD CheatCommandLibrary의 카테고리: **General / Economy / Stage** (FROM GetCategoryOrder와 완전 일치 확인됨)

### 적용 후 검증
- [ ] Unity Editor에서 컴파일 오류 없음
- [ ] `Tools > MarinRPG > Cheat Manager` 메뉴 열림 확인
- [ ] 좌측 카테고리 ListView에 All / General / Economy / Stage 표시
- [ ] 우측 커맨드 패널 커맨드 목록 표시
- [ ] 검색 필드 동작 (실시간 필터)
- [ ] Play Mode 진입 시 경고박스 숨김 확인
- [ ] 커맨드 실행 버튼 Play Mode에서 활성화 확인

---

## 섹션 6. 주의사항

### 1. UXML/USS .meta 파일 처리
신규 파일 추가 시 Unity가 `.meta` 파일을 자동 생성한다.
- 복사 후 Unity Editor를 열면 자동 생성됨 — 별도 처리 불필요
- FROM의 `.meta` 파일은 GUID가 다를 수 있으므로 **복사하지 않는다**

### 2. `DateTime.Now` 사용 (Log 메서드)
CLAUDE.md는 `DateTime.Now` 대신 `ServerTimeManager.NowUnscaled` 사용을 요구한다.
- 현재 FROM 코드: `$"[{DateTime.Now:HH:mm:ss}] {message}"`
- 이 위치는 에디터 로그 타임스탬프 표시용이므로 런타임 서버 시간과 무관
- 예외 인정 가능하나, 정책 준수 원칙에 따라 필요 시 교체:
  ```csharp
  // 교체 예시 (Application.isPlaying 체크 필요)
  string time = Application.isPlaying
      ? ServerTimeManager.NowUnscaled.ToString("HH:mm:ss")
      : DateTime.Now.ToString("HH:mm:ss");
  ```

### 3. WD 기존 CheatManagerWindow.cs.meta 보존
기존 `.cs.meta` 파일의 GUID를 유지해야 씬/에셋 참조가 깨지지 않는다.
- 에디터 윈도우는 일반적으로 씬에서 참조하지 않으나, 안전을 위해 **`.cs.meta`는 그대로 유지**
- 즉, `.cs` 파일만 덮어쓰고 `.meta`는 건드리지 않는다

### 4. `StageBalanceTesterWindow.cs` 등 무관 파일
WD에 있으나 FROM에 없는 파일 (`StageBalanceTesterWindow.cs`)은 sync 대상이 아니며 삭제하지 않는다.

### 5. 카테고리 정렬 검증 완료
- WD CheatCommandLibrary.cs 카테고리: `General`, `Economy`, `Stage`
- FROM GetCategoryOrder: Stage=0, Economy=1, General=2 → 순서: Stage → Economy → General
- WD 데이터와 FROM 정렬 로직 완전 호환

---

## 섹션 7. 적용 후 검증 방법

### 컴파일 검증
```
Unity Editor 열기
→ Console 창에서 오류 없음 확인
→ 특히 "UnknownIdentifier", "type or namespace not found" 없음 확인
```

### 기능 검증 순서
```
1. Unity Editor (Play Mode 해제 상태)
   Tools > MarinRPG > Cheat Manager (%#`) 단축키로 윈도우 열기
   → 노란색 경고박스 표시: "Play Mode에서만 커맨드를 실행할 수 있습니다."
   → 좌측: All / Stage / Economy / General 카테고리 리스트
   → 우측: 커맨드 카드 목록 표시

2. 검색 기능
   → 검색 필드에 키워드 입력 → 실시간 필터 동작
   → X 버튼으로 검색 초기화

3. 새로고침
   → 새로고침 버튼 클릭 → 커맨드 목록 재로드

4. 모두 접기 / 모두 펼치기
   → 전체 선택 시 Foldout 일괄 제어

5. Play Mode 진입
   → 경고박스 사라짐 확인
   → 실행 버튼 활성화 확인
   → 커맨드 실행 후 성공/실패 메시지 표시
   → 하단 로그 패널에 실행 기록 표시

6. ECurrencyType 파라미터 커맨드 테스트
   → Economy 카테고리 커맨드 중 ECurrencyType 파라미터 있는 것 선택
   → 검색 가능한 드롭다운 UI 표시 확인
   → Play Mode에서 통화명 로컬라이즈 표시 확인
```

### 회귀 검증
```
- CardCheatWindow: 기존 정상 동작 유지 확인 (Tools > MarinRPG > Card Cheat)
- StageBalanceTesterWindow: 기존 정상 동작 유지 확인
- CheatCommandLibrary: 커맨드 개수 변화 없음 확인
```
