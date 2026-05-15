# 범용 프로젝트 sync 가이드 ({{FROM_PROJECT}} → {{TO_PROJECT}})

> 이 문서는 `/sync-init`이 자동 생성했다. {{FROM_PROJECT_SHORT}}의 어떤 기능/시스템을 {{TO_PROJECT_SHORT}}로 sync할 때든 항상 적용되는 규칙과 절차를 정의한다.
> 시스템별 세부 내용은 별도 분석 문서(`{SYSTEM}_SYNC_PLAN.md`)에 작성하고, 이 문서를 함께 참조하여 sync한다.
>
> **이 가이드는 자동 감지로 채워졌다. 프로젝트 특이 규칙이 있으면 직접 추가·수정해줘.**

---

## 1. {{FROM_PROJECT_SHORT}} vs {{TO_PROJECT_SHORT}} 아키텍처 차이 (항상 적용)

### 1.1 매니저 베이스 클래스

| 항목 | {{FROM_PROJECT_SHORT}} 프로젝트 | {{TO_PROJECT_SHORT}} 프로젝트 |
|------|--------------|----------------|
| 매니저 베이스 클래스 | `{{FROM_BASE_MANAGER}}` ({{FROM_BASE_TYPE}}) | `{{TO_BASE_MANAGER}}` ({{TO_BASE_TYPE}}) |
| 매니저 접근 | `{{FROM_ACCESSOR}}` | `{{TO_ACCESSOR}}` |
| 이벤트 시스템 | `{{FROM_EVENT}}` | `{{TO_EVENT}}` |
| 리소스 로딩 | `{{FROM_RESOURCE_LOAD}}` | `{{TO_RESOURCE_LOAD}}` |
| SaveData 패턴 | `{{FROM_SAVE}}` | `{{TO_SAVE}}` |
| Localization | `{{FROM_LOCALIZATION}}` | `{{TO_LOCALIZATION}}` |
| 시간 시스템 | `{{FROM_TIME}}` | `{{TO_TIME}}` |
| 스크립트 루트 | (FROM 경로) | `{{TO_SCRIPTS_ROOT}}` |
| Managers 등록 파일 | (FROM 경로) | `{{TO_MANAGERS_FILE}}` |

### 1.2 항상 적용되는 변환 규칙

> **⚠️ 이 섹션은 템플릿이다. 자동 감지 결과를 바탕으로 채워졌지만, 프로젝트별 특이 규칙은 수동으로 보강 필요.**

#### 규칙 1. `{{FROM_BASE_MANAGER}}` → `{{TO_BASE_MANAGER}}`

```csharp
// FROM
public class FooManager : {{FROM_BASE_MANAGER}} { }

// TO
public class FooManager : {{TO_BASE_MANAGER}} { }
```

> 베이스 타입이 {{FROM_BASE_TYPE}} → {{TO_BASE_TYPE}}로 바뀌면 생성자/Awake 동작이 달라진다. 규칙 2 참조.

#### 규칙 2. POCO ↔ MonoBehaviour 변환 (해당 시)

{{FROM_BASE_TYPE}}와 {{TO_BASE_TYPE}}가 다를 때만 적용.

- POCO → MonoBehaviour: 생성자에서 하던 초기화를 필드 선언부 또는 `Awake`/`InitializeAsync`로 이동, `readonly` 필드는 선언부 초기화식 유지
- MonoBehaviour → POCO: `Awake`/`Start` 로직을 생성자 또는 `InitializeAsync`로 이동, `[SerializeField]` 제거

```csharp
// FROM (POCO 가정) — 생성자에서 초기화
public FooManager()
{
    _items = new List<Item>();
}
private readonly List<Item> _items;

// TO (MonoBehaviour 가정) — 필드 선언부 초기화식
private readonly List<Item> _items = new List<Item>();
```

#### 규칙 3. `{{FROM_ACCESSOR}}` → `{{TO_ACCESSOR}}`

```csharp
// FROM
_fooManager = {{FROM_ACCESSOR}}<FooManager>();

// TO
_fooManager = {{TO_ACCESSOR}}<FooManager>();
```

> 대부분의 경우 `Opened()` 또는 `InitializeAsync()` 내부에서 캐싱한다.

#### 규칙 4. FROM 전용 namespace 제거

FROM 프로젝트의 `using` 중 TO에 없는 namespace를 제거한다.
일반적 후보: `using Geuneda.*`, `using VContainer`, `using MessagePipe` 등.

```bash
# TO에 해당 namespace가 정의되어 있는지 확인
grep -rE "namespace\s+Geuneda" "{{TO_SCRIPTS_ROOT}}" --include="*.cs"
```

#### 규칙 5. `{{FROM_EVENT}}` → `{{TO_EVENT}}`

이벤트 시스템 변환. 양쪽 패턴이 같으면 이 규칙은 스킵.

```csharp
// FROM
{{FROM_EVENT}} 패턴으로 발행·구독

// TO
{{TO_EVENT}} 패턴으로 발행·구독
```

> **주의**: `EventManager`가 static이면 절대 `GetManager<EventManager>()`로 접근하지 않는다.

#### 규칙 6. UniRx Reactive → 일반 이벤트 (해당 시)

FROM에서 `ReactiveProperty`, `Observable`, `CompositeDisposable`을 사용했고 TO가 UniRx를 쓰지 않으면:

```csharp
// FROM (UniRx)
private readonly ReactiveProperty<int> _count = new ReactiveProperty<int>(0);
_count.Subscribe(v => OnCountChanged(v)).AddTo(this);

// TO
private int _count;
public event Action<int> OnCountChanged;
```

#### 규칙 7. `[Inject]` DI 어트리뷰트 제거 (해당 시)

FROM이 DI 컨테이너를 쓰고 TO가 안 쓰는 경우:

```csharp
// FROM
[Inject] private SaveDataManager _saveDataManager;

// TO
private SaveDataManager _saveDataManager;
public override async UniTask InitializeAsync()
{
    _saveDataManager = {{TO_ACCESSOR}}<SaveDataManager>();
}
```

#### 규칙 8. `async void` → `async UniTaskVoid`

이벤트 핸들러, 버튼 콜백 등 반환값 없는 모든 비동기 메서드에 적용.

```csharp
// 잘못된 패턴
private async void OnFooClicked() { ... }

// TO
private async UniTaskVoid OnFooClicked() { ... }
```

#### 규칙 9. DOTween `.ToUniTask()` 금지

```csharp
// 금지
await tween.ToUniTask();

// TO
await tween.AsyncWaitForCompletion();
```

#### 규칙 10. `DateTime.Now` → `{{TO_TIME}}` (런타임 코드에만)

Editor 코드(`UnityEditor` namespace, `EditorWindow` 상속)에는 적용하지 않는다.

```csharp
// FROM (런타임 코드)
var now = DateTime.Now;

// TO
var now = {{TO_TIME}};

// Editor 코드는 그대로 유지
string entry = $"[{DateTime.Now:HH:mm:ss}] {message}"; // ✅ EditorWindow에서는 OK
```

#### 규칙 11. `{{FROM_RESOURCE_LOAD}}` → `{{TO_RESOURCE_LOAD}}`

```csharp
// FROM
var prefab = {{FROM_RESOURCE_LOAD}}<GameObject>("Path/To/Prefab");

// TO
var prefab = await {{TO_RESOURCE_LOAD}}<GameObject>("Path/To/Prefab");
```

> `Resources.Load` → Addressables 전환은 await 추가가 필요할 수 있음.

#### 규칙 12. 하드코딩 문자열 → `{{TO_LOCALIZATION}}`

```csharp
// 금지
someText.text = "프리셋 저장됨";

// TO
someText.text = {{TO_LOCALIZATION}}("key");
```

#### 규칙 13. `{{FROM_SAVE}}` → `{{TO_SAVE}}`

저장 패턴이 다르면 변환 필요.

```csharp
// FROM
{{FROM_SAVE}} 호출

// TO
{{TO_SAVE}} 호출
```

#### 규칙 14. Partial Class 패턴

partial class는 양쪽 모두 사용 가능하지만 **첫 번째 파일에만 상속 선언**한다.

```csharp
// FooManager.cs (첫 번째 partial)
public partial class FooManager : {{TO_BASE_MANAGER}} { ... }

// FooManager.Preset.cs (두 번째 partial — 상속 선언 없음)
public partial class FooManager { ... }
```

#### 규칙 15. Partial Class — 내부 참조 메서드 존재 확인

partial 파일이 동일 클래스 다른 partial 파일의 private 메서드를 호출하는 경우, TO에 해당 메서드가 동일 이름·시그니처로 존재하는지 확인.

```bash
# TO 동일 클래스에서 메서드 존재 확인
grep -n "메서드명" {{TO_SCRIPTS_ROOT}}/.../{ClassName}.cs
```

없으면 TO 동등 메서드로 교체하거나 인라인 작성. 새 메서드 임의 추가 금지.

#### 규칙 16. 시그니처 축 변경 — enum 축 교체 + 다중 오버라이드 전수 처리

FROM과 TO의 동일 이름 메서드가 타입 파라미터(특히 enum)는 다를 수 있다.

| FROM 시그니처 | TO 시그니처 | 처리 |
|--------------|-----------|------|
| `TakeDamage(float damage, EUnitRaceType raceType, ...)` | `TakeDamage(float damage, EElementType elementType, ...)` | enum 축 변경 — 호출자·override 모두 새 enum으로 |

베이스 클래스에 동명 시그니처가 N개 있고 파생 클래스에서 일부만 override하면 나머지 시그니처는 base가 실행되어 의도 누락. 베이스 시그니처 전수 추출 후 파생의 override 카운트 일치 확인.

> ⚠️ **이 규칙은 프로젝트마다 다르다.** /sync-init은 자동 감지 불가. 양쪽 코드를 검토해서 enum 축이나 다중 오버라이드 함정이 있으면 수동으로 매핑 테이블 추가.

---

## 1.3 숨겨진 인프라 의존성 규칙

> **이 섹션은 프로젝트 무관 공통 규칙이라 템플릿에 그대로 들어간다.**

### 규칙 I-1. Utils/ 폴더 파일 누락 확인
sync 키워드로 검색되지 않더라도, FROM의 `Utils/` 폴더에만 있는 파일은 sync 시스템이 간접적으로 의존할 수 있다.
Phase 1 Step 2-I에서 FROM/TO Utils/ 폴더를 비교하여 누락 파일을 반드시 확인한다.

### 규칙 I-2. SaveData 포함 시스템 — JSON 직렬화 인프라 확인
SaveData 타입이 포함된 시스템을 sync할 때:
1. FROM `SaveDataManager`의 JsonSerializer 초기화 방식 확인
2. 커스텀 `JsonConverter`가 등록되어 있으면 해당 Converter 파일을 함께 sync
3. TO `SaveDataManager`의 초기화 코드를 FROM과 동일하게 맞춤

### 규칙 I-3. 커스텀 제네릭 컨테이너 사용 시 동반 파일 확인
`SerializableDictionary`, `ObservableList` 등 커스텀 제네릭 타입을 SaveData에서 사용하는 경우, 관련 JsonConverter나 직렬화 헬퍼가 필요할 수 있다.

### 규칙 I-4. 확장 메서드·헬퍼 파일 확인
sync 파일이 `*Extensions.cs` 또는 `*Helper.cs`의 확장 메서드를 사용하는 경우, 해당 파일이 TO에 존재하는지 확인.

### 규칙 I-5. 프리팹 sync 시 임베디드 GUID 포맷 주의

Unity 프리팹 YAML에는 GUID 포맷이 **두 가지**가 공존한다:

| 포맷 | 예시 | 사용처 |
|------|------|--------|
| 표준 포맷 | `{fileID: x, guid: abc123, type: 3}` | m_Script, m_SourcePrefab, m_Sprite 등 대부분 |
| 임베디드 포맷 | `m_TableCollectionName: GUID:abc123` | LocalizeStringEvent, 일부 SpriteAtlas |

```bash
# 표준 GUID 추출
grep -oP '(?<=guid: )[a-f0-9]{32}' {prefab} | sort -u

# 임베디드 GUID 추출
grep -oP '(?<=GUID:)[a-f0-9]{32}' {prefab} | sort -u
```

---

## 2. sync 전 필수 분석 절차

> 본 섹션 이하는 워크플로우(Phase 1~7) 가이드라 프로젝트 무관 공통 — 원본 `WD_SYNC_GUIDE.md`의 섹션 2~9 그대로 적용.
> 차이가 나는 부분만 자동 치환됨:
> - `Managers.Instance.GetManager<T>()` → `{{TO_ACCESSOR}}<T>`
> - `BaseService`/`BaseManager` → `{{FROM_BASE_MANAGER}}`/`{{TO_BASE_MANAGER}}`
> - 그 외 워크플로우 자체는 동일

**Step 1~5 (FROM 전수조사·TO 기존 파일 확인·호출 대상 메서드 확인·sync 유형 분류·SaveData 필드 일치 확인) 절차는 `WD_SYNC_GUIDE.md` 섹션 2 참조.**

---

## 3. 신규 매니저 sync 시 공통 수정 파일

### 3.1 SaveData 타입 정의 파일
프로젝트에 맞는 SaveData enum/타입 정의 파일을 찾아 수정. 자동 감지 결과:
- TO SaveData 패턴: `{{TO_SAVE}}`
- 위치는 `grep -rn "class.*SaveData" {{TO_SCRIPTS_ROOT}}`로 확인

### 3.2 SaveDataManager 매핑 (해당 시)
타입 기반 저장 시스템(`SaveDataAsync(ESaveDataType, T)`)을 사용한다면, SaveDataManager의 switch 3곳에 신규 enum 추가.

### 3.3 Managers 등록 파일 수정
경로: `{{TO_MANAGERS_FILE}}`

신규 매니저를 ManagerDefinition 배열(또는 동등 패턴)에 추가. priority는 기존 매니저들의 priority를 grep으로 확인 후 의존 매니저보다 큰 숫자 사용.

### 3.4 `Assets/link.xml` — IL2CPP 빌드에서 문제 발생 시에만

`typeof()` 기반 등록은 일반적으로 link.xml 불필요. `Activator.CreateInstance` 또는 `Type.GetType`을 사용하는 경우에만 추가.

---

## 4~9. (워크플로우 공통 — `WD_SYNC_GUIDE.md`와 동일)

원본 `WD_SYNC_GUIDE.md`의 섹션 4(UI 파일 sync 주의사항)~섹션 9(워크트리 정리)는 프로젝트 무관 공통이므로 그대로 따른다. 차이는 위 규칙 1~16의 치환된 부분에만 있다.

---

## 자동 감지가 놓쳤을 수 있는 부분 (수동 추가 권장)

`/sync-init`은 다음 항목을 자동 감지하지 못한다. 프로젝트에 해당하면 직접 추가:

- [ ] **시그니처 축 변경 매핑** (규칙 16) — FROM과 TO의 enum 차이 등
- [ ] **프로젝트 특이 매니저 메서드 시그니처** — 예: `TakeDamage`, `Heal` 류의 다중 오버라이드
- [ ] **DataSheet 자동 생성 규칙** — `SOs/SO/DataSheet/` 같은 자동 생성 폴더 위치
- [ ] **Localization 키 명명 규칙**
- [ ] **Addressable 그룹 명명 규칙**
- [ ] **IAP / 결제 시스템 패턴** (해당 프로젝트만)
- [ ] **서버 통신 패턴** (ServerLoadingPopupUI 등 프로젝트 전용 헬퍼)

---

## 변경 이력

- {{DATE}}: `/sync-init`이 자동 생성
- 이후 수동 편집 사항은 여기 추가
