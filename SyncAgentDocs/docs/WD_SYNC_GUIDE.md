# 범용 프로젝트 sync 가이드 (FROM → TO)

> 이 문서는 FROM의 어떤 기능/시스템을 TO로 sync할 때든 항상 적용되는 규칙과 절차를 정의한다.
> 시스템별 세부 내용은 별도 분석 문서(`{SYSTEM}_SYNC_PLAN.md`)에 작성하고, 이 문서를 함께 참조하여 sync한다.

---

## 1. FROM vs TO 아키텍처 차이 (항상 적용)

### 1.1 매니저 베이스 클래스

| 항목 | FROM 프로젝트 | TO 프로젝트 |
|------|--------------|----------------|
| 순수 C# 매니저 | `BaseService` (MonoBehaviour 아님) | **없음** — 모든 매니저는 `BaseManager : MonoBehaviour` |
| 매니저 등록 | `ManagerFactory.cs` — `isPureService` 플래그 있음 | `Managers.cs` — MonoBehaviour만, `isPureService` 없음 |
| 매니저 접근 | `GetManager<T>()` | `Managers.Instance.GetManager<T>()` (동일) |
| DI 컨테이너 | `MainInstaller`, `IServiceLocator`, `ServiceAccessor` | **없음** |
| 이벤트 시스템 | `MessageBroker`, `IMessageBroker` (인스턴스 DI) | `EventManager` (STATIC) |
| 리액티브 | `UniRx` (`ReactiveProperty`, `Observable`) | `UniTask` + C# 이벤트 |

### 1.2 항상 적용되는 변환 규칙 15가지

#### 규칙 1. `BaseService` → `BaseManager`

```csharp
// FROM
public class FooManager : BaseService { }

// TO
public class FooManager : BaseManager { }
```

> `IsInitialized`, `GetManager<T>()`, `base.InitializeAsync()`, `base.Cleanup()` 모두 동일하게 사용 가능.

#### 규칙 2. 생성자 초기화 → 필드 선언부 초기화식

`BaseService`는 순수 C# 클래스이므로 생성자가 있다. `BaseManager`는 MonoBehaviour이므로 생성자가 없다.

```csharp
// FROM — 생성자에서 초기화
public FooManager()
{
    _items = new List<Item>();
    _map = new Dictionary<string, Item>();
}
private readonly List<Item> _items;
private readonly Dictionary<string, Item> _map;

// TO — 필드 선언부 초기화식으로 변환, readonly 유지 가능
private readonly List<Item> _items = new List<Item>();
private readonly Dictionary<string, Item> _map = new Dictionary<string, Item>();
```

#### 규칙 3. `ServiceAccessor.Get<T>()` → `Managers.Instance.GetManager<T>()`

```csharp
// FROM
_fooManager = ServiceAccessor.Get<FooManager>();

// TO
_fooManager = Managers.Instance.GetManager<FooManager>();
```

> 대부분의 경우 `Opened()` 또는 `InitializeAsync()` 내부에서 캐싱한다.

#### 규칙 4. `using Geuneda.Services;` 제거

FROM의 일부 파일에 `using Geuneda.Services;` 또는 `using Geuneda.*`가 있다. TO에 해당 네임스페이스가 없으므로 제거.

#### 규칙 5. `MessageBroker` → `EventManager` (STATIC)

```csharp
// FROM — 인스턴스 주입 방식
[Inject] private IMessageBroker _messageBroker;
_messageBroker.Subscribe<FooEventData>(OnFoo);
_messageBroker.PublishSafe(new FooEventData());

// TO — STATIC 방식
EventManager.Subscribe<FooEventData>(GameEventType.FooEvent, OnFoo);
EventManager.Dispatch<FooEventData>(GameEventType.FooEvent, data);
// 해제
EventManager.Unsubscribe<FooEventData>(GameEventType.FooEvent, OnFoo);
```

> **주의**: `EventManager`는 절대 `GetManager<EventManager>()`로 접근하지 않는다. STATIC 클래스.

#### 규칙 6. `UniRx` → UniTask / C# 이벤트

```csharp
// FROM — UniRx ReactiveProperty
private readonly ReactiveProperty<int> _count = new ReactiveProperty<int>(0);
_count.Subscribe(v => OnCountChanged(v)).AddTo(this);

// TO — 일반 C# 프로퍼티 + 이벤트
private int _count;
public event Action<int> OnCountChanged;
```

> `Observable.Timer`, `Observable.Interval` → `UniTask.Delay`, `UniTask.DelayFrame` 으로 교체.
> `CompositeDisposable` / `.AddTo(this)` 패턴 → 이벤트 구독 해제를 `Cleanup()`에서 수동으로 처리.

#### 규칙 7. `[Inject]` DI 어트리뷰트 제거

```csharp
// FROM
[Inject] private SaveDataManager _saveDataManager;

// TO — InitializeAsync()에서 직접 가져옴
private SaveDataManager _saveDataManager;
public override async UniTask InitializeAsync()
{
    _saveDataManager = GetManager<SaveDataManager>();
    // ...
}
```

#### 규칙 8. `async void` → `async UniTaskVoid`

```csharp
// FROM / 잘못된 패턴
private async void OnFooClicked() { ... }

// TO
private async UniTaskVoid OnFooClicked() { ... }
```

> 이벤트 핸들러, 버튼 콜백 등 반환값이 없는 모든 비동기 메서드에 적용.

#### 규칙 9. DOTween `.ToUniTask()` 금지

```csharp
// 금지
await tween.ToUniTask();

// TO
await tween.AsyncWaitForCompletion();
```

#### 규칙 10. `DateTime.Now` → `ServerTimeManager.NowUnscaled`

```csharp
// FROM / 금지
var now = DateTime.Now;

// TO
var now = ServerTimeManager.NowUnscaled;
```

#### 규칙 11. `Resources.Load` → `ResourceManager.LoadResource<T>()`

```csharp
// FROM / 금지
var prefab = Resources.Load<GameObject>("Path/To/Prefab");

// TO
var prefab = await ResourceManager.LoadResource<GameObject>("Path/To/Prefab");
```

#### 규칙 12. 하드코딩 문자열 → `LocalizationManager`

```csharp
// FROM / 금지
someText.text = "프리셋 저장됨";

// TO
someText.text = LocalizationManager.GetLocalizedText("key");
```

#### 규칙 13. `SavePlayerDataAsync()` → `SaveDataAsync(ESaveDataType, data)`

```csharp
// FROM 패턴 (다양한 형태)
await _saveDataManager.SavePlayerDataAsync();
await SaveAsync();

// TO
await _saveDataManager.SaveDataAsync(ESaveDataType.Foo, _saveData);
```

#### 규칙 14. Partial Class 패턴

FROM은 `FooManager.cs` + `FooManager.Preset.cs` 형태로 partial class를 많이 사용한다.

```csharp
// FROM: FooManager.Preset.cs
public partial class FooManager
{
    // 프리셋 관련 메서드
}

// TO 변환: 동일하게 partial class 파일 신규 생성
// Assets/_Project/1_Scripts/Core/Managers/FooManager.Preset.cs
public partial class FooManager  // ← 두 번째 partial에는 : BaseManager 생략
{
    // ⚠️ partial 두 번째 파일에는 : BaseManager를 쓰지 않는다
}
```

> **주의**: partial class의 두 번째 파일에는 상속 선언(`: BaseManager`)을 반복하지 않는다. 첫 번째 파일에만 선언.

#### 규칙 15. Partial Class — 내부 참조 메서드 존재 확인

partial class 파일이 동일 클래스의 다른 partial 파일에 있는 private 메서드를 호출하는 경우, **TO의 해당 메서드가 FROM과 이름·시그니처가 동일한지** 반드시 확인한다.

```csharp
// FROM: ChipManager.Preset.cs
_chipInventory.Sort(ChipSortComparison); // ← FROM에는 존재, TO에는 없음

// TO: ChipManager.cs에서 확인
grep -n "ChipSortComparison\|SortChipInventory" Assets/_Project/1_Scripts/Core/Managers/ChipManager.cs
// 결과: TO는 SortChipInventory()를 사용 → 인라인 LINQ 정렬로 대체
```

> **처리**: FROM 메서드가 TO에 없으면 TO의 동등 메서드로 교체하거나, 해당 로직을 인라인으로 작성한다. 새 메서드를 임의로 추가하지 않는다.

---

## 1.3 숨겨진 인프라 의존성 규칙

### 규칙 I-1. Utils/ 폴더 파일 누락 확인
sync 키워드로 검색되지 않더라도, FROM의 `Utils/` 폴더에만 있는 파일은
sync 시스템이 간접적으로 의존할 수 있다.
Phase 1 Step 2-I에서 FROM/TO Utils/ 폴더를 비교하여 누락 파일을 반드시 확인한다.

### 규칙 I-2. SaveData 포함 시스템 — JSON 직렬화 인프라 확인
SaveData 타입이 포함된 시스템을 sync할 때:
1. FROM `SaveDataManager`의 `_jsonSerializer` 초기화 방식을 확인
2. 커스텀 `JsonConverter`가 등록되어 있으면 해당 Converter 파일을 함께 sync
3. TO `SaveDataManager`의 초기화 코드를 FROM과 동일하게 맞춤

**증상**: `Error reading string. Unexpected token: StartArray` 류의 역직렬화 오류
**원인**: 커스텀 Converter 없이 `JsonSerializer.CreateDefault()` 사용
**해결**: Converter 파일 sync + `CreateJsonSerializer()` 패턴 적용

### 규칙 I-3. 커스텀 제네릭 컨테이너 사용 시 동반 파일 확인
`SerializableDictionary`, `ObservableList` 등 커스텀 제네릭 타입을 SaveData에서 사용하는 경우,
해당 타입을 처리하는 `JsonConverter`나 직렬화 헬퍼가 필요할 수 있다.
sync 파일에서 커스텀 컨테이너 타입이 발견되면 관련 인프라 파일을 함께 확인한다.

### 규칙 I-4. 확장 메서드·헬퍼 파일 확인
sync 파일이 `*Extensions.cs` 또는 `*Helper.cs`의 확장 메서드를 사용하는 경우,
해당 파일이 TO에 존재하는지 확인한다. 없으면 함께 sync한다.

### 규칙 I-5. 프리팹 sync 시 임베디드 GUID 포맷 주의

Unity 프리팹 YAML에는 GUID 포맷이 **두 가지**가 공존한다:

| 포맷 | 예시 | 사용처 |
|------|------|--------|
| 표준 포맷 | `{fileID: x, guid: abc123, type: 3}` | m_Script, m_SourcePrefab, m_Sprite 등 대부분 |
| 임베디드 포맷 | `m_TableCollectionName: GUID:abc123` | LocalizeStringEvent, 일부 SpriteAtlas |

**핵심 문제**: `grep "guid:"` 패턴은 표준 포맷만 잡는다. 임베디드 포맷의 `GUID:` 는 별도 추출이 필요하다.

```bash
# 표준 GUID 추출
grep -oP '(?<=guid: )[a-f0-9]{32}' {prefab} | sort -u

# 임베디드 GUID 추출 (이것을 빠뜨리면 LocalizeStringEvent가 조용히 누락됨)
grep -oP '(?<=GUID:)[a-f0-9]{32}' {prefab} | sort -u
```

**LocalizeStringEvent의 m_StringReference 구조 (4개 필드 전부 필요):**
```yaml
m_StringReference:
  m_TableReference:
    m_TableCollectionName: GUID:{table_collection_asset_guid}   ← 임베디드 GUID
  m_TableEntryReference:
    m_KeyId: {숫자}                                              ← 프로젝트마다 다를 수 있음
```

**sync 시 처리 순서:**
1. FROM과 TO의 Table Collection GUID 비교 → 다르면 교체
2. 각 m_KeyId가 TO Table에 존재하는지 확인 → 없으면 `⚠️ 누락 Localization 키`로 기록
3. sync 완료 후 FROM과 TO의 LocalizeStringEvent 수 비교 (재귀 포함) → 수가 다르면 복원

> **증상**: Unity 에디터에서 해당 Text 오브젝트가 빈 문자열로 표시되거나
> Inspector에서 StringReference가 None/Missing으로 보임.
> 프리팹 YAML을 보면 컴포넌트 자체가 없거나 m_StringReference 구조가 불완전함.

---

## 2. sync 전 필수 분석 절차

> **⚠️ 사전 조건**: FROM 코드를 읽으려면 FETCH_HEAD가 설정되어 있어야 한다. 최초 1회만 필요하므로 **섹션 8 'FROM 프로젝트 FETCH_HEAD 설정'을 먼저 실행**한 뒤 이 절차를 따른다.

### Step 1. FROM에서 참조 파일 전수조사

sync할 시스템의 관련 키워드를 **최대한 많이** 나열해서 FROM 전체를 grep한다. **이 단계를 건너뛰거나 키워드가 부족하면 외부 호출자 누락으로 sync 실패.**

```bash
# FETCH_HEAD = FROM의 dev 브랜치
# 키워드는 많을수록 좋다 — 클래스명·타입명·인터페이스명·SaveData명·시스템 접두어 전부 포함
git grep -l "FooManager\|FooTypes\|IFooCapable\|FooSaveData\|EFooSlot\|Foo" FETCH_HEAD -- "*.cs"
```

**키워드 선정 기준** (아래 유형을 전부 포함):

| 유형 | 예시 |
|------|------|
| 핵심 매니저 클래스명 | `FooManager` |
| 타입/열거형 파일명 | `FooTypes`, `EFooSlot` |
| 인터페이스명 | `IFooCapable` |
| SaveData 클래스명 | `FooSaveData` |
| 시스템 접두어 (부분 일치) | `Foo` ← 위 항목들을 한 번에 커버 + 클래스명이 살짝 달라도 잡힘 |
| 특이한 이벤트/메서드명 | `OnFooChanged`, `LoadFoo` |

> **팁**: 시스템 이름 자체(`Foo`)를 키워드에 추가하면 클래스명 변경·약어·주석에 숨어있는 참조 파일도 누락되지 않는다. FROM과 TO에서 이름이 조금 다를 때 특히 유효하다.

결과 파일 목록을 전부 확인하고 sync 계획 문서에 기록한다.

### Step 2. TO에 이미 존재하는 파일 확인

```bash
# 여러 키워드를 OR로 묶어 한 번에 탐색 (파일명 + 내용 양쪽 커버)
grep -rl "FooManager\|FooTypes\|IFooCapable\|Foo" Assets/_Project/1_Scripts --include="*.cs" -l
```

신규 생성 / 수정 / 해당 없음을 분류한다.

### Step 3. 호출 대상 메서드 TO 존재 여부 확인

FROM 코드에서 다른 클래스의 메서드·필드를 호출하는 **모든** 위치를 찾아 TO에서도 동일한 시그니처로 존재하는지 확인한다. 매니저뿐만 아니라 **UI 컴포넌트도 포함**한다.

```bash
# WD에서 매니저 메서드 존재 확인
grep -n "methodName" Assets/_Project/1_Scripts/Core/Managers/TargetManager.cs

# WD에서 UI 컴포넌트 메서드 존재 확인 (예: ChipInventoryItem.SetPresetNumbers)
grep -rn "SetPresetNumbers\|RefreshAll" Assets/_Project/1_Scripts/UI/
```

**체크해야 할 3가지 호출 유형:**

| 호출 유형 | 예시 | 확인 방법 |
|----------|------|----------|
| 매니저 메서드 | `_chipManager.GetEquippedChipsInSlotType(slotType)` | 해당 Manager.cs grep |
| UI 컴포넌트 메서드 | `itemObj.SetPresetNumbers("2")` | 해당 Component.cs grep |
| partial 내부 참조 | `_chipInventory.Sort(ChipSortComparison)` | 동일 클래스 다른 partial grep |

**⚠️ 특히 주의**: FROM에서 추가되고 TO에는 아직 없는 메서드 (예: 프리셋 sync 시 `ChipItemSaveData.effectValue`처럼 TO SaveData 타입에 필드가 없는 경우).

### Step 4. sync 파일별 유형 분류

Step 1~3 분석 결과를 바탕으로 각 sync 대상 파일에 **sync 유형**을 부여한다. 이 분류가 sync 순서와 주의사항을 결정한다.

| 유형 | 정의 | 처리 |
|------|------|------|
| **DIRECT** | FROM 전용 패턴 없음, 의존성 전부 TO에 존재 | 그대로 복사 |
| **ADAPTED** | FROM 전용 패턴(규칙 1~15)만 변환하면 됨, 의존성 전부 TO에 존재 | 규칙 적용 후 복사 |
| **PARTIAL** | 일부 의존성이 TO에 없음 (미sync 클래스/메서드) | 의존 부분을 대체/스텁 처리 후 기록 |
| **BLOCKED** | 선행 sync 파일이 완료되어야 작업 가능 | 선행 파일 완료 후 진행 |

**PARTIAL 처리 원칙 (우선순위 순):**
1. TO에 동등한 역할의 UIBase 클래스가 있으면 `Show<대체클래스>`로 교체
2. sync 파일이 호출하는 기존 TO 컴포넌트에 메서드가 없으면 해당 TO 파일에 메서드를 추가 (예: `ChipInventoryItem.SetPresetNumbers()`, `EquipmentPopup.RefreshAll()`)
3. partial class에서 참조하는 메서드가 TO에 없으면 TO 동등 로직으로 인라인 대체 (규칙 15)
4. 위 방법 모두 불가능하면 해당 호출을 주석 처리하고 `// TODO: {의존성} sync 후 복원` 을 남김

**PARTIAL 처리 후 반드시 sync 계획 문서 섹션 0.1에 기록:**
```
- [PARTIAL] LoadoutHeroSkillModule.cs
  - SkillEquipPopup: TO 미sync → 주석 처리 + TODO
  - 향후 SkillEquipPopup sync 시 이 파일도 함께 수정 필요
```

### Step 5. SaveData 타입 필드 일치 확인

FROM의 SaveData 클래스와 TO의 대응 클래스를 필드 단위로 비교한다.

```bash
# FROM의 FooSaveData 필드 확인
git show FETCH_HEAD:Assets/_Project/1_Scripts/... | grep -A 30 "class FooSaveData"

# TO의 대응 클래스 확인 — SaveDataTypes.cs가 기본이지만 별도 파일에 있을 수 있음
grep -rn "class FooSaveData" Assets/_Project/1_Scripts/
```

> **⚠️ 주의**: TO의 SaveData 클래스는 `SaveDataTypes.cs`에 항상 있지 않다. 예: `MinionSaveData`는 `Core/Data/Minion/MinionSaveData.cs`에 있다. grep으로 실제 위치를 확인한다.

**결과별 처리:**

| grep 결과 | 처리 방법 |
|-----------|----------|
| TO에 클래스 존재, 필드 일치 | 그대로 사용 |
| TO에 클래스 존재, 필드 누락 | 해당 필드만 TO SaveData 클래스에 추가 |
| TO에 클래스 자체가 없음 | FROM에서 전체 복사 후 `[Serializable]` 확인, 섹션 3.1~3.2 절차 수행 |

---

## 3. 신규 매니저 sync 시 공통 수정 파일

sync 대상이 **새 매니저**라면 아래 파일들을 반드시 수정한다.

### 3.1 `SaveDataTypes.cs` 수정

```csharp
// 1. ESaveDataType enum에 추가 (순서 변경 금지 — Firebase key 매핑 깨짐)
public enum ESaveDataType
{
    // ...기존 항목...
    Foo,  // ← 마지막에 추가
}

// 2. FirebaseKeys에 상수 추가
public static class FirebaseKeys
{
    // ...기존 항목...
    public const string FOO = "foo";  // ← 추가
}
```

### 3.2 `SaveDataManager.cs` 수정 (3곳)

```csharp
// 수정 1: FirebaseKey → ESaveDataType 매핑 switch
FirebaseKeys.FOO => ESaveDataType.Foo,

// 수정 2: DeserializeDataByType() switch
SaveDataTypes.ESaveDataType.Foo => jObject.ToObject<FooSaveDataType>(_jsonSerializer),

// 수정 3: ESaveDataType → FirebaseKey 매핑 switch
SaveDataTypes.ESaveDataType.Foo => SaveDataTypes.FirebaseKeys.FOO,
```

### 3.3 `Managers.cs` 수정

```csharp
// MANAGER_DEFINITIONS 배열에 추가
new ManagerDefinition(typeof(FooManager), {priority}, "Lobby", true, true),
```

**priority 결정 방법** — `InitializeAsync()` 에서 `GetManager<T>()`로 가져오는 매니저들의 priority보다 **낮은 숫자**를 써야 한다(숫자가 낮을수록 먼저 초기화).

```bash
# Managers.cs에서 기존 매니저들의 priority 확인
grep -n "ManagerDefinition" Assets/_Project/1_Scripts/Core/Managers/Managers.cs
```

예: `FooManager.InitializeAsync()` 에서 `SaveDataManager`(priority 10)와 `BarManager`(priority 20)를 참조하면,
FooManager의 priority는 **21 이상**으로 설정한다.

### 3.4 `Assets/link.xml` — IL2CPP 빌드에서 문제 발생 시에만

WD는 `typeof(FooManager)`를 통해 `AddComponent(type)` 방식으로 매니저를 생성한다. `typeof()`는 IL2CPP가 정적으로 추적 가능하므로 **일반적으로 link.xml이 필요 없다.**

다음 상황에서만 추가한다:
- IL2CPP 빌드 후 해당 매니저가 null이거나 생성에 실패하는 경우
- `Activator.CreateInstance(type)` 또는 `Type.GetType("string")` 방식을 사용하는 경우

```xml
<!-- Assets/link.xml (없으면 신규 생성) -->
<linker>
  <assembly fullname="Assembly-CSharp">
    <type fullname="FooManager" preserve="all"/>
  </assembly>
</linker>
```

---

## 4. UI 파일 sync 시 주의사항

### 4.1 FROM UI 파일의 패턴 확인

FROM의 UI 파일은 두 가지 패턴이 섞여 있다:

| 패턴 | 판별 방법 | TO 변환 필요 여부 |
|------|----------|-----------------|
| TO 패턴 | `Managers.Instance?.GetManager<T>()` 사용 | ❌ 변환 불필요, 그대로 복사 |
| FROM 전용 패턴 | `ServiceAccessor.Get<T>()`, `[Inject]`, `MessageBroker` 사용 | ✅ 변환 필요 |

```bash
# FROM UI 파일의 FROM 전용 패턴 일괄 확인
git show FETCH_HEAD:Assets/_Project/1_Scripts/UI/SomeUI.cs | grep -n "ServiceAccessor\|Inject\|MessageBroker\|using Geuneda\|using UniRx"
```

### 4.2 `uiManager.Show<T>()` 참조 클래스 존재 확인

FROM UI 파일은 `uiManager.Show<TargetUI>()` 패턴으로 다른 팝업을 열 수 있다. **TargetUI 클래스가 TO에 존재하지 않으면 컴파일 에러.**

```bash
# FROM 파일에서 Show<T> 호출 전체 추출
git show FETCH_HEAD:{파일경로} | grep -n "Show<\|Hide<"

# 각 T에 대해 TO 존재 확인
grep -rn "class TargetUI" Assets/_Project/1_Scripts/UI/
```

TO에 없는 클래스가 발견되면:
1. TO에 동등한 역할의 UIBase 클래스가 있는지 확인 → 있으면 대체
2. 없으면 PARTIAL로 분류하고 해당 Show<> 호출을 주석 처리 또는 TODO로 남김
3. 섹션 2 Step 4 처리 원칙에 따라 sync 계획 문서 섹션 0.1에 기록

### 4.3 새 sync 파일이 기존 TO 클래스의 메서드를 호출하는 경우

sync할 새 파일(예: `LoadoutPopupUI.cs`)이 기존 TO 클래스(예: `EquipmentPopup`)의 메서드를 호출하면, 해당 메서드가 TO에 **이미 public으로 존재하는지** 확인한다.

```bash
# sync 파일에서 외부 객체의 메서드 호출 추출 (인스턴스.대문자메서드 패턴)
git show FETCH_HEAD:{sync파일경로} | grep -n "\.[A-Z][a-zA-Z]*(" | grep -v "\/\/"
# 추출된 메서드명을 TO 대상 클래스에서 확인
grep -n "public.*RefreshAll\|public.*SetPresetNumbers" Assets/_Project/1_Scripts/UI/Popups/EquipmentPopup.cs
```

TO에 없는 메서드가 있으면 해당 TO 클래스에 추가한다. 메서드 추가 시 **기존 private 메서드를 wrapping하는 public 메서드** 패턴을 사용한다.

```csharp
// 기존 TO private 메서드를 public으로 노출
public void RefreshAll()
{
    RefreshEquipmentSlots();
    RefreshInventory();
    UpdateHeroPower();
}
```

### 4.4 TO에서 UI 파일 위치

TO의 UI 폴더 구조를 먼저 확인하고 대응 위치를 찾는다.

```bash
find Assets/_Project/1_Scripts/UI -type d
```

---

## 5. diff 비교 전략

### 5.1 파일명과 경로 유지 원칙

sync한 파일의 이름과 경로를 FROM 원본과 동일하게 유지한다. diff 노이즈 최소화.

### 5.2 메서드 순서와 위치 유지 원칙

- 파일 내 메서드 선언 순서를 BD와 동일하게 유지 (임의 재배치 금지)
- `#region` 블록 이름과 범위 유지
- TO 전용 추가 코드는 해당 메서드 내 FROM 기준 삽입 위치에만 추가
- 변환이 불가피한 부분(규칙 1~15)은 동일 줄 위치에서 인라인으로 변경

### 5.3 변환이 불가피한 부분 (diff 노이즈 최소화)

| 변환 (규칙) | diff 영향 |
|------------|----------|
| `BaseService` → `BaseManager` (규칙 1) | 1줄 변경 |
| 생성자 → 필드 초기화식 (규칙 2) | 생성자 블록 삭제, 각 필드 1줄 변경 |
| `ServiceAccessor.Get<T>()` → `GetManager<T>()` (규칙 3) | 호출 개수만큼 변경 |
| `using Geuneda.Services;` 제거 (규칙 4) | 1줄 삭제 |
| `MessageBroker` → `EventManager` (규칙 5) | Subscribe/Publish 호출 개수만큼 변경 |
| `UniRx` → UniTask/C# 이벤트 (규칙 6) | ReactiveProperty 제거, 이벤트 선언 추가 |
| `[Inject]` 제거 + `InitializeAsync` 수동 취득 (규칙 7) | 어트리뷰트 1줄 삭제, InitializeAsync에 1줄 추가 |
| `async void` → `async UniTaskVoid` (규칙 8) | 반환 타입 1줄 변경 |
| `tween.ToUniTask()` → `AsyncWaitForCompletion()` (규칙 9) | 메서드명 변경 |
| `DateTime.Now` → `ServerTimeManager.NowUnscaled` (규칙 10) | 1줄 변경 |
| `Resources.Load` → `ResourceManager.LoadResource<T>()` (규칙 11) | 1줄 변경 + await 추가 |
| 하드코딩 문자열 → `LocalizationManager` (규칙 12) | 문자열 개수만큼 변경 |
| `SavePlayerDataAsync()` → `SaveDataAsync(type, data)` (규칙 13) | 1줄 변경 |
| partial class 두 번째 파일 상속 제거 (규칙 14) | 클래스 선언 1줄 변경 |
| partial 내부 메서드 인라인 교체 (규칙 15) | 교체된 줄 수 (LINQ 등으로 대체) |

### 5.4 diff 확인 권장 명령어

```bash
# FROM 파일을 임시로 추출
git show FETCH_HEAD:Assets/_Project/1_Scripts/Core/Managers/FooManager.cs > /tmp/from_FooManager.cs

# TO sync본과 비교
diff /tmp/from_FooManager.cs Assets/_Project/1_Scripts/Core/Managers/FooManager.cs

# side-by-side
diff -y --width=200 /tmp/from_FooManager.cs Assets/_Project/1_Scripts/Core/Managers/FooManager.cs | less
```

### 5.5 sync 계획 문서(섹션 7) 포함 의무

Phase 3에서 생성하는 `{시스템명}_SYNC_PLAN.md`에는 반드시 **섹션 7 "diff 비교 전략"** 을 포함한다.

섹션 7에 기재할 항목:
- 신규 생성 파일 전체의 `git show FETCH_HEAD:{경로} > /tmp/from_{파일명}` + `diff` 명령어
- 예상 diff 노이즈 표 (파일 | 적용 규칙 | 예상 diff)
- **변환 불필요 파일은 "0줄" 명시** — sync 후 0줄이 아니면 의도치 않은 변경으로 간주

---

## 6. sync 후 검증 체크리스트

### [ ] 6.1 컴파일 검증

- [ ] Unity 에디터에서 컴파일 에러 없음
- [ ] FROM 전용 namespace 참조 없음 (`Geuneda`, `VContainer`, `MessagePipe`, `UniRx` 등)
- [ ] `async void` 없음 → `async UniTaskVoid` 사용

### [ ] 6.2 SaveData 검증

- [ ] 저장 후 앱 재시작 → 데이터 정상 로드
- [ ] `SerializableDictionary` 사용 시: Newtonsoft.Json 직렬화 호환성 테스트 필수

### [ ] 6.3 이벤트 검증

- [ ] `Cleanup()` 내에서 C# 이벤트 구독 해제 확인 (`-=` 패턴)
- [ ] `Cleanup()` 내에서 `EventManager.Unsubscribe` 호출 확인
- [ ] FROM의 `CompositeDisposable.Dispose()` / `.AddTo(this)` 패턴이 TO에서 수동 해제로 교체되었는지 확인

### [ ] 6.4 기능 검증

- [ ] BD와 동일한 시나리오로 기능 동작 확인
- [ ] 신규 유저 / 기존 유저 양쪽 케이스 테스트

---

## 7. 자주 발생하는 컴파일 에러 패턴

| 에러 원인 | 증상 | 해결 방법 |
|----------|------|----------|
| `using Geuneda.Services;` 잔존 | `ServiceAccessor`, `BaseService` not found | using 제거, 클래스 변환 |
| `using UniRx;` 잔존 | `ReactiveProperty`, `IObservable` not found | UniTask/C# 이벤트로 교체 |
| `[Inject]` 어트리뷰트 | `InjectAttribute` not found | 어트리뷰트 제거 + 수동 GetManager |
| FROM SaveData 필드 없음 | `FooSaveData does not contain 'field'` | TO SaveData 클래스에 필드 추가 |
| 선행 sync 파일 누락 | `FooManager does not contain 'Bar'` | sync 순서 문제 — 해당 메서드를 정의하는 파일을 먼저 sync하거나 BLOCKED 처리 |
| 생성자에서 readonly 초기화 | MonoBehaviour에 생성자 불가 | 필드 선언부 초기화식으로 변환 |
| `async void` 사용 | 비동기 예외 미처리, UniTask 경고 | `async UniTaskVoid`로 변경 |
| `tween.ToUniTask()` 사용 | `ToUniTask` not found 또는 런타임 오류 | `await tween.AsyncWaitForCompletion()` |
| `DateTime.Now` 사용 | 컴파일은 되지만 서버 시간과 불일치 | `ServerTimeManager.NowUnscaled` |
| partial class에 중복 상속 선언 | 중복 base class 컴파일 에러 | 두 번째 partial 파일에서 `: BaseManager` 제거 |
| partial class 내 메서드 참조 누락 | `FooManager does not contain 'ChipSortComparison'` | TO 동일 클래스에서 메서드 확인 → 없으면 TO 동등 메서드로 교체 (규칙 15) |
| 미sync UI 클래스 참조 | `The type or namespace 'SkillEquipPopup' could not be found` | TO에서 동등 UIBase 클래스 찾아 대체, 없으면 PARTIAL 처리 |
| sync 파일이 호출하는 TO 컴포넌트 메서드 누락 | `'EquipmentPopup' does not contain a definition for 'RefreshAll'` / `'ChipInventoryItem' does not contain a definition for 'SetPresetNumbers'` | 해당 TO 클래스에 메서드 추가 (섹션 4.3 참조) |

---

## 8. FROM 프로젝트 FETCH_HEAD 설정

FROM 코드를 읽으려면 먼저 FROM 브랜치를 fetch해야 한다.

```bash
# FROM remote 등록 (최초 1회)
git remote add temp-bunker {FROM_repo_url}

# FROM dev 브랜치 fetch
git fetch temp-bunker dev

# FETCH_HEAD로 FROM 파일 읽기
git show FETCH_HEAD:Assets/_Project/1_Scripts/Core/Managers/FooManager.cs

# FROM에서 특정 클래스 참조 파일 전수조사
git grep -l "FooManager\|FooTypes" FETCH_HEAD -- "*.cs"

# FROM 파일 목록 전체 확인
git ls-tree -r FETCH_HEAD --name-only | grep -i foo
```

---

## 9. sync 완료 후 워크트리 정리

`/sync` 에이전트는 작업 격리를 위해 임시 git worktree를 생성한다.
sync이 완료되고 결과물이 커밋되면 워크트리는 불필요하므로 반드시 정리한다.

```bash
# 1. 워크트리 폴더 삭제 (2GB+ 용량)
rm -rf .claude/worktrees/

# 2. git worktree 메타데이터 정리
git worktree prune

# 3. 임시 브랜치 삭제 (worktree-agent-{id} 형식)
git branch -D worktree-agent-{id}
```

> **sync 과정 기록**은 `~/Documents/obsidian_vault/Sync/` (또는 obsidian 없으면 `~/Downloads/Sync/`) 리포트 파일에 보존되므로
> 워크트리 브랜치를 남길 필요가 없다.
> 에이전트 자동화 시 sync 완료 단계에 위 정리 스텝을 포함할 것.
