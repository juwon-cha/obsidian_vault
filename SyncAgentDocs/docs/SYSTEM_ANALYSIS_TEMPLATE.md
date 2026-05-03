# {시스템명} sync 분석 문서
## FROM 프로젝트 → TO 프로젝트

> **작성일**: {날짜}
> **소스**: FROM 프로젝트 (`temp-bunker` 브랜치 `dev`)
> **대상**: TO 프로젝트 (`juwon/...` 브랜치)
> **범용 규칙 참조**: `WD_SYNC_GUIDE.md`

---

## 사전 조건 — FETCH_HEAD 설정 확인

아래 명령이 출력을 반환하면 설정 완료. 오류가 나면 `WD_SYNC_GUIDE.md`의 **'FROM 프로젝트 FETCH_HEAD 설정'** 섹션을 먼저 실행한다.

```bash
git ls-tree FETCH_HEAD --name-only | head -5
```

---

## 0. sync 전 grep 전수조사 결과

아래 명령으로 FROM에서 이 시스템을 참조하는 모든 파일을 찾는다.

```bash
# 키워드를 최대한 많이 나열 (클래스명·타입명·인터페이스명·SaveData명·시스템 접두어 전부 포함)
# 예: "FooManager\|FooTypes\|IFooCapable\|FooSaveData\|EFooSlot\|Foo"
git grep -l "{grep키워드목록}" FETCH_HEAD -- "*.cs"

# TO에도 관련 파일이 있는지 동일 키워드로 확인
grep -rl "{TO파일키워드목록}" Assets/_Project/1_Scripts --include="*.cs" -l

# 찾은 각 파일에서 FROM 전용 패턴 일괄 확인 (변환 필요 여부 판별)
git show FETCH_HEAD:{파일경로} | grep -n "ServiceAccessor\|Inject\|MessageBroker\|using Geuneda\|using UniRx\|BaseService\|DateTime\.Now\|Resources\.Load\|ToUniTask\|async void\|SavePlayerDataAsync"
```

| FROM 파일 | 역할 | FROM 전용 패턴 | sync 유형 | TO 처리 방법 |
|---------|------|------------|---------|-------------|
| `Core/Managers/FooManager.cs` | 핵심 매니저 | BaseService, ServiceAccessor, MessageBroker | **ADAPTED** | 신규 생성 (규칙 1,3,4,5 적용) |
| `Core/Managers/FooManager.Preset.cs` | Partial 확장 | (동일) | **ADAPTED** | 신규 생성 (규칙 4) |
| `UI/FooPopupUI.cs` | UI | ServiceAccessor, Show<SkillEquipPopup> | **PARTIAL** | 신규 생성 / SkillEquipPopup → HeroSkinDetailPopup 대체 |
| `Core/Managers/BarManager.cs` | 외부 호출자 | 없음 (TO 패턴) | **DIRECT** | 수정 (호출 추가) |
| *(grep 결과 전부 기록)* | | | | |

> **sync 유형 기준** (상세: `WD_SYNC_GUIDE.md` 섹션 2 Step 3a)
> - **DIRECT**: FROM 전용 패턴 없음, 의존성 전부 TO 존재 → 그대로 복사
> - **ADAPTED**: 규칙 1~15 변환만 필요, 의존성 전부 TO 존재 → 규칙 적용 후 복사
> - **PARTIAL**: 일부 의존성이 TO에 없음 → 대체/추가/스텁 처리 후 아래 표에 기록
> - **BLOCKED**: 선행 sync 파일 완료 후 진행

> **⚠️ 이 표가 완성되기 전까지 sync을 시작하지 않는다. 외부 호출자 누락과 PARTIAL 파일 미확인이 가장 흔한 실패 원인.**

### 0.1 PARTIAL 파일 의존성 상세

*(PARTIAL 유형 파일이 있을 때만 작성. 이 표가 향후 수정 대상 목록이 된다.)*

| 파일 | 미sync 의존성 | TO 대체 처리 | 향후 조치 |
|------|------------|------------|---------|
| `UI/FooPopupUI.cs` | `SkillEquipPopup` (TO 미sync) | `HeroSkinDetailPopup`으로 임시 대체 | SkillEquipPopup sync 시 이 파일도 함께 수정 |
| `UI/FooComponent.cs` | `SetPresetNumbers()` (TO 컴포넌트에 없음) | ChipInventoryItem에 메서드 추가 | — |
| *(추가 PARTIAL 항목)* | | | |

---

## 1. FROM vs TO 현재 상태 비교

### 1.1 TO에 이미 존재하는 요소

| 파일/클래스 | TO 경로 | 상태 |
|------------|---------|------|
| `BarManager.cs` | `Core/Managers/` | ✅ 존재 — 호출 추가 필요 |
| `{타입명}SaveData` | `SaveDataTypes.cs:NNNN` | ✅ 존재 — 필드 일치 확인 필요 |

### 1.2 TO에 없는 요소 (sync 필요)

| 카테고리 | 항목 | 작업 |
|----------|------|------|
| **새 파일** | `FooManager.cs` | 신규 생성 |
| **수정** | `SaveDataTypes.cs` | enum + FirebaseKey + SaveData 타입 |
| **수정** | `SaveDataManager.cs` | 3곳 (섹션 3.2 가이드 참조) |
| **수정** | `Managers.cs` | ManagerDefinition 추가 |
| **조건부** | `link.xml` | IL2CPP 빌드 후 매니저 null/생성 실패 시에만 생성 |

---

## 2. FROM 원본 파일 분석

### 2.1 `FooManager.cs` (핵심 매니저)

**FROM 전용 패턴 빠른 확인**:
```bash
git show FETCH_HEAD:{파일경로} | grep -n "ServiceAccessor\|Inject\|MessageBroker\|using Geuneda\|using UniRx\|BaseService\|DateTime\.Now\|Resources\.Load\|ToUniTask\|async void\|SavePlayerDataAsync"
```

**FROM 전용 패턴 (변환 필요)**:
- [ ] `BaseService` → `BaseManager` (규칙 1)
- [ ] 생성자 초기화 → 필드 초기화식 (규칙 2)
- [ ] `using Geuneda.Services;` 제거 (규칙 4)
- [ ] `ServiceAccessor.Get<BarManager>()` → `GetManager<BarManager>()` (규칙 3)
- [ ] `[Inject]` 어트리뷰트 제거 + `InitializeAsync()`에서 수동 취득 (규칙 7)
- [ ] `MessageBroker` → `EventManager` STATIC (규칙 5)
- [ ] `UniRx` → `UniTask` / C# 이벤트 (규칙 6)
- [ ] `async void` → `async UniTaskVoid` (규칙 8)
- [ ] `tween.ToUniTask()` → `tween.AsyncWaitForCompletion()` (규칙 9)
- [ ] `DateTime.Now` → `ServerTimeManager.NowUnscaled` (규칙 10)
- [ ] `Resources.Load` → `ResourceManager.LoadResource<T>()` (규칙 11)
- [ ] 하드코딩 문자열 → `LocalizationManager.GetLocalizedText()` (규칙 12)
- [ ] `SavePlayerDataAsync()` → `SaveDataAsync(ESaveDataType.X, data)` (규칙 13)
- [ ] Partial class 두 번째 파일에 `: BaseManager` 중복 선언 없는지 확인 (규칙 14)
- [ ] partial class가 있는 경우: 동일 클래스 다른 partial 파일의 private 메서드를 호출하면 WD에도 동일 메서드가 존재하는지 확인 (규칙 15)
- [ ] *(추가 발견 패턴 기록)*

**필드**:
```csharp
private FooSaveData _saveData;
private BarManager _barManager;
// ...
```

**이벤트**:
```csharp
public event Action<int> OnFooChanged;
// ...
```

**메서드 목록** (FROM 원본 순서 유지):
```csharp
public override async UniTask InitializeAsync()
public override void Cleanup()
public async UniTask<bool> DoSomethingAsync(int param)
// ...
```

---

### 2.2 `{다른파일}.cs`

*(같은 형식으로 반복)*

---

## 섹션 2.5 — 숨겨진 인프라 의존성 감사

sync 파일들이 직접 참조하지 않지만 런타임에 필요한 인프라 파일 목록.

### 2.5.1 Utils/ 폴더 비교
| 파일명 | FROM 존재 | TO 존재 | sync 필요 |
|--------|---------|---------|---------|
| SerializableDictionaryConverter.cs | ✅ | ❌ | ✅ |

### 2.5.2 JSON 직렬화 인프라 (SaveData 포함 시스템)
| 항목 | FROM | TO | 일치 여부 |
|------|------|----|---------|
| `_jsonSerializer` 초기화 | `CreateJsonSerializer()` | `JsonSerializer.CreateDefault()` | ❌ → 수정 필요 |
| 등록된 JsonConverter | `SerializableDictionaryConverter` | 없음 | ❌ → sync 필요 |

### 2.5.3 커스텀 타입 동반 인프라
| 커스텀 타입 | 사용 위치 | 필요 인프라 | TO 존재 여부 |
|-----------|---------|-----------|-----------|
| `SerializableDictionary<,>` | PresetSaveData | SerializableDictionaryConverter | ❌ |

### 2.5.4 감사 결론
- **sync 필요 인프라 파일**: N개
- **초기화 코드 수정 필요**: N곳
- Phase 4 체크리스트에 반영됨: ✅

---

## 3. TO 호출 대상 메서드 존재 확인

sync할 코드가 호출하는 TO 기존 클래스의 메서드·필드를 **3가지 유형별로** 전부 확인한다.

### 3.1 매니저 메서드

| 호출 메서드 | TO 위치 | 상태 |
|------------|---------|------|
| `BarManager.DoBar(int)` | `BarManager.cs:NNN` | ✅ |
| `SaveDataManager.SaveDataAsync(ESaveDataType, T)` | `SaveDataManager.cs:NNN` | ✅ |
| `BazManager.GetBazData(int)` | `BazManager.cs:NNN` | ✅ |
| `FooSaveData.someField` | `SaveDataTypes.cs:NNN` | ⚠️ WD에 없음 → 추가 필요 |

### 3.2 UI 컴포넌트 메서드 (sync 파일이 기존 TO 컴포넌트를 호출하는 경우)

*(sync한 새 파일이 기존 TO UI 컴포넌트의 메서드를 호출하면 여기에 기록)*

```bash
# sync 파일의 메서드 호출 추출 후 TO 대상 클래스에서 확인
grep -n "methodName" Assets/_Project/1_Scripts/UI/Components/TargetComponent.cs
```

| 호출 메서드 | TO 대상 클래스 | 상태 | 처리 |
|------------|-------------|------|------|
| `itemObj.SetPresetNumbers(str)` | `ChipInventoryItem.cs` | ⚠️ WD에 없음 | 메서드 추가 |
| `popup.RefreshAll()` | `EquipmentPopup.cs` | ⚠️ WD에 없음 | public 래퍼 메서드 추가 |
| *(추가 항목)* | | | |

### 3.3 Show<T> UI 클래스 존재 확인

*(sync 파일에서 uiManager.Show<T>() 호출하는 T를 전부 추출)*

```bash
git show FETCH_HEAD:{sync파일경로} | grep -n "Show<\|Hide<"
```

| 참조 클래스 | TO 존재 여부 | 처리 |
|-----------|-----------|------|
| `SkillEquipPopup` | ⚠️ TO 미sync | `HeroSkinDetailPopup`으로 임시 대체 → PARTIAL 기록 |
| `LoadoutRenamePopupUI` | ✅ sync 대상에 포함 | — |
| *(추가 항목)* | | |

### 3.4 partial class 내부 참조 메서드

*(partial class 파일이 있을 때: 같은 클래스 다른 partial에서 호출하는 private 메서드 확인)*

```bash
# FROM partial 파일에서 메서드 호출 추출 (대문자 시작 메서드명 패턴)
git show FETCH_HEAD:{Partial파일경로} | grep -n "\.[A-Z][a-zA-Z]*(\|[^\.][A-Z][a-zA-Z]*(" | grep -v "\/\/\|public\|private\|protected\|override\|class "
# 추출된 메서드명을 TO 동일 클래스에서 확인
grep -n "메서드명" Assets/_Project/1_Scripts/Core/Managers/FooManager.cs
```

| FROM 메서드 | TO FooManager.cs 존재 여부 | 처리 |
|----------|--------------------------|------|
| `ChipSortComparison` | ⚠️ 없음 (TO는 SortChipInventory 사용) | 인라인 LINQ 정렬로 대체 |
| *(추가 항목)* | | |

---

## 4. TO에서 수정이 필요한 기존 파일

*(가이드 문서 섹션 3의 공통 항목 외 이 시스템에 특화된 수정 사항만 기록)*

### 4.1 `SaveDataTypes.cs` (또는 해당 SaveData 파일)

> **⚠️ SaveData 클래스 위치 확인 필수**: WD의 SaveData 클래스가 `SaveDataTypes.cs`에 없을 수 있다.
> ```bash
> grep -rn "class FooSaveData" Assets/_Project/1_Scripts/
> ```

```csharp
// ESaveDataType에 추가
Foo,

// FirebaseKeys에 추가
public const string FOO = "foo";

// 신규 SaveData 타입 (WD에 없는 것만)
[Serializable]
public class FooSaveData
{
    // ...
}

// 기존 타입에 필드 추가 (BD에는 있고 WD에 없는 경우)
// BarSaveData에 추가:
public float missingField;
```

### 4.2 `{외부 호출자}.cs` 수정

**파일**: `Assets/_Project/1_Scripts/.../BarManager.cs`

FROM에서 `FooManager`를 호출하는 위치:

```csharp
// FROM: BarManager.cs:NNN — SomeMethod() 내부
NotifyFooStateChanged();   // ← 추가 필요 (TO에 없음)
```

**추가 위치**: `SomeMethod()` 내부, `OnSomethingChanged?.Invoke()` 직후

*(시스템별로 구체적인 before/after 코드 스니펫 기록)*

---

## 5. sync 체크리스트

> **사용법**: sync 작업 중 완료된 항목에 `[x]`를 표시한다.

### 공통 (가이드 문서 섹션 3)

- [ ] `SaveDataTypes.cs` — `ESaveDataType.Foo` 추가
- [ ] `SaveDataTypes.cs` — `FirebaseKeys.FOO` 추가
- [ ] `SaveDataTypes.cs` — 신규/수정 SaveData 타입
- [ ] `SaveDataManager.cs` — FirebaseKey→ESaveDataType switch 추가
- [ ] `SaveDataManager.cs` — `DeserializeDataByType()` switch 추가
- [ ] `SaveDataManager.cs` — ESaveDataType→FirebaseKey switch 추가
- [ ] `Managers.cs` — `ManagerDefinition(typeof(FooManager), {priority}, ...)` 추가
- [ ] `link.xml` — IL2CPP 빌드 후 FooManager null/생성 실패 시에만: `<type fullname="FooManager" preserve="all"/>` 추가

### 신규 파일 생성

- [ ] `FooManager.cs` — FROM 변환 규칙 적용 (가이드 규칙 1~15)
- [ ] `FooManager.Preset.cs` — partial class 신규 생성 (규칙 14: 두 번째 파일에 `: BaseManager` 없음)
- [ ] *(추가 파일)*

### 기존 파일 수정

- [ ] `BarManager.cs` — `NotifyFooStateChanged()` 호출 추가 (line ~NNN)
- [ ] *(추가 수정 항목)*

### PARTIAL 파일 처리

*(섹션 0.1에 기록된 PARTIAL 파일마다 항목 추가)*

- [ ] `FooPopupUI.cs` — `SkillEquipPopup` → `HeroSkinDetailPopup` 대체 적용
- [ ] `FooComponent.cs` — `SetPresetNumbers()` 메서드 TO 컴포넌트에 추가
- [ ] `BarPopup.cs` — `RefreshAll()` public 래퍼 메서드 TO 클래스에 추가
- [ ] *(추가 PARTIAL 처리 항목)*

### sync 후 검증 (가이드 문서 섹션 6)

- [ ] **컴파일 에러 없음** — Unity 에디터에서 0 errors 확인
  - [ ] FROM 전용 using/패턴 잔존 없음
  - [ ] PARTIAL 처리된 대체 클래스가 TO에 실제로 존재함 확인
  - [ ] 추가한 메서드(TO 컴포넌트에 추가한 것 포함) 시그니처 확인
- [ ] `Cleanup()` 내 이벤트 구독 해제 확인 (`-=`, `EventManager.Unsubscribe`)
- [ ] 저장 → 재시작 → 로드 정상 동작
- [ ] `SerializableDictionary` 사용 시: Newtonsoft.Json 직렬화 호환성 테스트
- [ ] FROM과 동일 시나리오 기능 테스트

---

## 6. 이 시스템 특유의 주의사항

*(sync 중 발견한 특이사항, 런타임 주의사항, 의존성 순서 등 기록)*

1. **초기화 순서**: `FooManager(priority N)` — `BarManager(priority M)` 이후에 초기화되어야 함.
2. *(추가 발견 시 기록)*

---

## 7. diff 비교 전략

> 범용 원칙은 `WD_SYNC_GUIDE.md` 섹션 5 참조. 이 섹션에는 이 시스템에 특화된 diff 명령어와 예상 노이즈만 기록한다.

### 7.1 신규 생성 파일 diff 확인 명령어

*(sync 완료 후 파일마다 아래 패턴으로 FROM 원본과 비교한다)*

```bash
# FROM 원본 추출
git show FETCH_HEAD:Assets/_Project/1_Scripts/Core/Managers/FooManager.cs > /tmp/from_FooManager.cs

# TO sync본과 비교 (줄 단위)
diff /tmp/from_FooManager.cs Assets/_Project/1_Scripts/Core/Managers/FooManager.cs

# side-by-side (넓은 터미널)
diff -y --width=200 /tmp/from_FooManager.cs Assets/_Project/1_Scripts/Core/Managers/FooManager.cs | less
```

### 7.2 예상 diff 노이즈 (변환 규칙 적용 결과)

*(변환 불필요 파일은 diff가 0줄이어야 한다. 아래 표에 없는 변경이 생기면 sync 오류로 간주)*

| 파일 | 적용 규칙 | 예상 diff |
|------|----------|----------|
| `FooManager.cs` | 규칙 1 (`BaseService`→`BaseManager`) | 1줄 변경 |
| `FooManager.cs` | 규칙 N (해당 패턴) | N줄 변경 |
| `FooManager.Preset.cs` | 규칙 14 (두 번째 partial `: BaseManager` 없음) | 1줄 변경 |
| `BarManager.cs` (수정) | 추가 로직 삽입 | +N줄 |

---

## 8. 프리팹 패키징 목록

> **작성 시점**: Phase 4(sync 실행) 완료 후 컴파일 에러 0개 확인 시점에 작성한다.
> 이 섹션의 내용은 별도 파일 `{시스템명}_PREFAB_PACKAGE_LIST.md`로도 생성된다.

### 8.1 FROM에서 패키지화할 프리팹 목록 (패키지화 순서 = 의존성 순)

*(자식 프리팹 → 부모 프리팹 순서. TO에 이미 존재하는 것은 ~~취소선~~ 표시)*

- [ ] `{모듈프리팹}.prefab` — 자식 컴포넌트를 내부에 포함
- [ ] `{메인팝업}.prefab` — 위 모듈 프리팹 인스턴스를 자식으로 포함
- [ ] `{서브팝업}.prefab`

### 8.2 프리팹별 SerializeField 연결 목록

*(임포트 후 인스펙터에서 수동으로 연결해야 할 항목. 배열 크기가 크거나 Sprite 리스트인 경우 ⚠️ 표시)*

| 프리팹 | 필드명 | 타입 | 배열 크기 | 주의사항 |
|--------|--------|------|----------|---------|
| `FooPopupUI` | `_closeButton` | `Button` | — | |
| `FooPopupUI` | `_slotButtons` | `FooSlotButton[]` | 8 | ⚠️ 배열 8개 |
| `FooPopupUI` | `_slotNumberSprites` | `Sprite[]` | 8 | ⚠️ 스프라이트 교체 여부 확인 |
| `FooModule` | `_skillSlots` | `SkillSlotUI[]` | 3 | |
| *(추가 항목)* | | | | |

### 8.3 Show<T> 외부 UI 참조 확인

*(sync 파일에서 uiManager.Show<T>() 호출하는 T 전체. UIManager에 등록 여부 확인)*

| 호출 위치 | 대상 클래스 | TO 존재 여부 | 처리 |
|----------|------------|------------|------|
| `FooPopupUI` | `ConfirmPopupUI` | ✅ 기존 TO | — |
| `FooPopupUI` | `BarRenamePopupUI` | ✅ 이번 임포트 | UIManager 등록 필요 |
| `FooModule` | `SkillEquipPopup` | ⚠️ TODO 주석 | 향후 sync 시 복원 |
| *(추가 항목)* | | | |

### 8.4 임포트 후 UIManager 등록 필요 목록

*(UIBase를 상속하고 새로 임포트되는 프리팹 전체)*

- [ ] `{클래스명}` — `Assets/_Project/3_Prefabs/UI/{경로}/{파일명}.prefab`
- [ ] *(추가 항목)*
| *(추가 파일)* | | |
