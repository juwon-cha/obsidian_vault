# ContentsContinueUI SYNC_PLAN

> FROM: `bunker-defense/dev` (worktree `/tmp/sync_ContentsContinueUI_1780395871`)
> TO  : `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
> 시스템: 콘텐츠 예고(ContentsContinue) — 레벨 해금 콘텐츠를 예고/보상 수령하는 로비 팝업
> Phase 범위: 0~5-C
> 본 문서는 `WD_SYNC_GUIDE.md`(규칙 1~16)와 함께 사용한다.

---

## 섹션 0 — grep 전수조사 결과 (sync 유형 분류)

| FROM 파일 | 역할 | FROM 전용 패턴 | sync 유형 | TO 처리 |
|---|---|---|---|---|
| `UI/ContentsContinue/ContentsContinueUI.cs` | 리스트형 예고 팝업 | `ServiceAccessor`, `OpenedAsync/ClosedAsync: UniTask` | **ADAPTED** | 규칙3 + UniTask→Task |
| `UI/ContentsContinue/ContentsContinueItemUI.cs` | 예고 아이템 슬롯 | `ServiceAccessor`, `Resources.Load<Sprite>` | **ADAPTED** | 규칙3 + (규칙11 검토) |
| `UI/ContentsContinue/ContentsContinueCardUI.cs` | 타임라인 카드 | `ServiceAccessor` | **ADAPTED** | 규칙3 |
| `UI/ContentsContinue/ContentsContinueLevelSectionUI.cs` | 타임라인 레벨 섹션 | 없음 | **DIRECT** | 그대로 복사 |
| `UI/ContentsContinue/ContentsContinueTimelineUI.cs` | 타임라인형 예고 팝업 | `ServiceAccessor`, `OpenedAsync/ClosedAsync: UniTask` | **ADAPTED** | 규칙3 + UniTask→Task |
| `Core/Managers/ContentsContinueManager.cs` | 데이터/수령/저장 관리 | `BaseService`, `ServiceAccessor`, `MessageBroker.PublishSafe`, `ESaveDataType.ContentsContinue` | **ADAPTED** | 규칙1/3/5 + 선행 인프라 |
| `SOs/SO/DataSheet/ContentsContinueDataSO.cs` | DataSheet 생성 SO | 없음(생성물) | **DIRECT** | 그대로 복사 |
| `SOs/Class/DataSheet/ContentsContinueDataData.cs` | DataSheet 생성 클래스 | 없음(생성물) | **DIRECT** | 그대로 복사 |

**공유 인프라(부분 병합 — PARTIAL merge):** SaveDataTypes.cs, SaveDataManager.cs, GameEventTypes.cs(+이벤트 데이터), Managers.cs, RedDotManager.cs, LobbyMainUI.cs, PlayerDataManager.cs, CheatCommandLibrary.cs, JsonToSO.cs

**이식 제외:** `Core/Base/ManagerFactory.cs` (BD 전용, WD는 `Managers.cs` 등록) / InfinityCraft 관련 전부 (WD-only divergence)

집계: DIRECT 3 / ADAPTED 6 / PARTIAL(부분병합) 9 / BLOCKED 0

---

## 섹션 0.1 — PARTIAL/주의 의존성 상세

- **[ADAPTED] ContentsContinueItemUI.cs** — `Resources.Load<Sprite>(iconPath)` 1곳(약 287행). 규칙11상 `ResourceManager.LoadResource<T>()` 권장이나, 아이콘 경로가 Addressables/Resources_moved로 이전됐는지 확인 필요. 1차 sync는 원본 동작 유지(컴파일/런타임 안전), 경로 검증은 Phase 4 말미 TODO.
- **[BLOCKED→해소] UI 5개** — `ContentsContinueManager` + `ContentsContinueDataData`가 WD에 없으면 컴파일 불가. 매니저/데이터 클래스를 **먼저** 이식하면 해소.
- **이벤트 클래스 선행** — `GameEventType.ContentsContinueClaimChanged` enum + POCO 이벤트 데이터를 **publisher/subscriber보다 먼저** 추가해야 컴파일 그린(커밋 순서 주의).
- **ECurrencyType 리맵** — DataSheet `.asset` 데이터 차팅 시 `currencyType`은 BD↔WD enum 값 불일치 가능 → **enum 이름 기준 리맵** 필수(메모리 규칙). 클래스 .cs는 그대로 DIRECT.

---

## 섹션 1 — TO 현재 상태

- WD에 `ContentsContinue` 참조 **전무** → 완전 신규 시스템.
- 공유 인프라 파일은 모두 이미 존재(부분 병합 대상).
- 의존 매니저/컴포넌트 전부 WD 존재 확인: `UIManager`, `PlayerDataManager`, `CurrencyManager`, `SaveDataManager`, `RedDotManager`, `AcquisitionRouteManager`, `RewardClaimPopupUI`, `ItemDisplayComponent`, `RedDotComponent`, `AudioUtils`, `RLog`, `LocalizationManager`. 의존 enum `ECurrencyType`, `EAcquisitionRouteType` 존재.

---

## 섹션 2 — FROM 원본 분석 (핵심)

### ContentsContinueManager (ADAPTED)
- 베이스: `BaseService` → **`BaseManager`** (규칙1). `override async UniTask InitializeAsync()` + `await base.InitializeAsync()`는 WD `BaseManager`도 동일 → 본문 유지.
- 필드: `const int HIDE_LEVEL_OFFSET=10`, `List<ContentsContinueDataData> _allContents/_activeContents`, `HashSet<int> _claimedIndices`, `ContentsContinueClaimChangedEventData _claimChangedEventData`(이벤트 전환 후 단순 POCO).
- 프로퍼티: `EContentsContinueUIMode UIMode`, `bool IsAllRewardsClaimed`, `int HideLevel`.
- public 메서드: `GetActiveContents()`, `IsClaimed(int)`, `HasUnclaimedReward()`, `ClaimContentReward(int, out Dictionary<ECurrencyType,int>)`, `GetSaveData()`, `LoadFromSaveData(List<int>)`, (`#if DEV`)`ResetAllClaimsForTest()`.
- private: `CheckAllRewardsClaimed`, `DispatchClaimChangedEvent(int)`, `LoadContentsContinueData`, `SaveClaimDataAsync()`.
- 내부 enum: `EContentsContinueUIMode { ItemSlot, Timeline }` (파일 상단 전역 enum — 함께 이식).
- 변환:
  - `ServiceAccessor.Get<PlayerDataManager/CurrencyManager/SaveDataManager>()` → `GetManager<T>()` (규칙3).
  - `MessageBroker.PublishSafe(_claimChangedEventData)` → `EventManager.Dispatch(GameEventType.ContentsContinueClaimChanged, _claimChangedEventData)` (규칙5).
  - 저장: `SaveDataAsync(ESaveDataType.ContentsContinue, GetSaveData())` — API 동일, enum/클래스 선행 추가 필요.
  - 데이터 로드: `Resources.LoadAll<ContentsContinueDataSO>("ScriptableObjects/ContentsContinueData")` — WD DataSheet 로드 컨벤션 확인(타 DataSO 로드 방식 모방). 데이터 .asset 없으면 빈 리스트 graceful 처리.
  - `DateTime.Now`/`async void`/`[Inject]`/`SavePlayerDataAsync` **없음**.

### UI 5개 (ADAPTED/DIRECT)
- 베이스 `UIBase` 공통. WD `UIBase.OpenedAsync/ClosedAsync` 반환형이 **`Task`**(FROM은 `UniTask`) → `ContentsContinueUI`, `ContentsContinueTimelineUI` 시그니처만 `async Task`로 변경(본문 유지).
- 전 UI: `ServiceAccessor.Get<T>()` → `Managers.Instance.GetManager<T>()`.
- `LevelSectionUI`는 FROM 전용 패턴 없음 → DIRECT.
- 보상 수령은 CLAUDE.md 패턴 준수: `RewardClaimPopupUI.ShowAlreadyClaimedRewards(...)` 사용(이미 매니저가 ModifyCurrency 처리).

### DataSO/Data (DIRECT)
- 순수 생성 클래스, WD `SOs/SO/DataSheet/` · `SOs/Class/DataSheet/` 패턴 동일. 그대로 복사. 데이터 .asset/json은 Phase 4 후반.

---

## 섹션 3 — TO 호출 대상 존재 확인

| 항목 | 결과 |
|---|---|
| 3.1 매니저 메서드 (UIManager.Show/Hide, PlayerData.CurrentLevel, Currency, SaveData.SaveDataAsync, RedDot.SetRedDotActive, AcquisitionRoute.Execute) | ✅ 전부 존재 |
| 3.2 UI 컴포넌트 (ItemDisplayComponent.SetupItem/SetShowDetailPopup/SetInteractable/OnItemClicked, RedDotComponent.NodeID) | ✅ 존재 |
| 3.3 Show<T> 대상 (RewardClaimPopupUI, ContentsContinueUI, ContentsContinueTimelineUI) | ✅ (예고 UI는 신규 이식분) |
| 3.4 SaveData 필드 (ContentsContinueSaveDataType.claimedContentIndices) | ⚠️ TO에 클래스 없음 → 신규 추가 |

**이벤트 결선:** publisher 1(ContentsContinueManager) / subscriber 2(RedDotManager, LobbyMainUI) — 전부 sync 범위 내. **publisher 0 / subscriber 0 함정 없음.** EventManager로 양쪽 동시 전환.

---

## 섹션 4 — TO 수정 필요 기존 파일 (부분 병합)

### 4.1 `Core/Managers/SaveDataTypes.cs`
- `ESaveDataType` enum **마지막**(`RaceTower,` 뒤, 약 61행)에 추가:
  ```csharp
  ContentsContinue, // 콘텐츠 예고 데이터
  ```
- `FirebaseKeys`에 추가:
  ```csharp
  public const string CONTENTS_CONTINUE = "contentscontinue";
  ```
- 파일 하단 신규 클래스:
  ```csharp
  [System.Serializable]
  public class ContentsContinueSaveDataType
  {
      public List<int> claimedContentIndices = new List<int>();
  }
  ```
- ⚠️ InfinityCraft enum/키는 추가하지 않음(WD-only divergence).

### 4.2 `Core/Managers/SaveDataManager.cs` (3곳 — 가이드 섹션 3.2)
- `DeserializeDataByType()` switch(~1205행)에 추가:
  ```csharp
  SaveDataTypes.ESaveDataType.ContentsContinue => jObject.ToObject<ContentsContinueSaveDataType>(_jsonSerializer),
  ```
- `GetFirebaseKey()` switch(~1281행)에 추가:
  ```csharp
  SaveDataTypes.ESaveDataType.ContentsContinue => SaveDataTypes.FirebaseKeys.CONTENTS_CONTINUE,
  ```
- FirebaseKey→ESaveDataType 역매핑 switch(~1141행)에 추가:
  ```csharp
  SaveDataTypes.FirebaseKeys.CONTENTS_CONTINUE => SaveDataTypes.ESaveDataType.ContentsContinue,
  ```

### 4.3 `Core/Enums/GameEventTypes.cs`
- `GameEventType` enum 마지막에 추가:
  ```csharp
  ContentsContinueClaimChanged, // 콘텐츠 예고 보상 수령 상태 변경
  ```
- 이벤트 데이터 클래스(WD 이벤트 데이터 컨벤션 위치, IMessage 미상속 POCO):
  ```csharp
  public class ContentsContinueClaimChangedEventData
  {
      public int ContentIndex;
  }
  ```
  (BD의 `Timestamp`/`UpdateTimestamp()`는 EventManager에서 불필요 → 제거)

### 4.4 `Core/Managers/Managers.cs`
- `MANAGER_DEFINITIONS` 배열에 추가(**5인자**, BD 6번째 인자 제거):
  ```csharp
  new ManagerDefinition(typeof(ContentsContinueManager), 326, "Lobby", true, true), // 콘텐츠 예고 매니저
  ```
- priority 근거: 의존 매니저 SaveData(290)/Currency(295)/PlayerData(302)보다 **큰 값**. 326은 현재 미사용(325·327 사이) → 안전.

### 4.5 `Core/Managers/RedDotManager.cs`
- RedDot 노드 등록 블록에 `NodeID="Lobby.ContentsContinue", Parent="Lobby"` 추가.
- 이벤트 구독: BD `MessageBroker.Subscribe<...>` → WD `EventManager.Subscribe<ContentsContinueClaimChangedEventData>(GameEventType.ContentsContinueClaimChanged, OnContentsContinueClaimChanged)` (구독 블록), 해제는 `UnsubscribeFromEvents()`.
- 핸들러 + 메서드:
  ```csharp
  private void OnContentsContinueClaimChanged(ContentsContinueClaimChangedEventData _) => CheckContentsContinueRewardAvailability();
  public void CheckContentsContinueRewardAvailability()
  {
      var manager = Managers.Instance?.GetManager<ContentsContinueManager>();
      if (manager == null) return;
      SetRedDotActive("Lobby.ContentsContinue", manager.HasUnclaimedReward());
  }
  ```
- `CheckInitialStates()`에 `CheckContentsContinueRewardAvailability();` 1줄. 레벨업 핸들러에도 동일 호출 추가.

### 4.6 `UI/LobbyMainUI.cs`
- `[SerializeField] private Button _contentsContinueButton;` (Button 필드 영역).
- 바인딩: `_contentsContinueButton.onClick.AddListener(OnContentsContinueClicked);`
- 구독: `SubscribeToEvents()`에 `EventManager.Subscribe<ContentsContinueClaimChangedEventData>(...)`, 해제 대응.
- `OnContentsContinueClicked()`: `Managers.Instance.GetManager<ContentsContinueManager>().UIMode`가 `Timeline`이면 `Show<ContentsContinueTimelineUI>()`, 아니면 `Show<ContentsContinueUI>()`.
- `RefreshContentsContinueButtonVisible()`: 전체 수령 && `_playerDataManager.CurrentLevel >= HideLevel`이면 숨김.
- `LobbyUIManager.cs`는 무관(수정 불필요).
- 적응: `ServiceAccessor`→`GetManager`, `MessageBroker`→`EventManager`.

### 4.7 `Core/Managers/PlayerDataManager.cs`
- 세이브 로드 적용 시퀀스(다른 `LoadDataAsync<...>` 블록들과 동일 위치)에 추가:
  ```csharp
  var ccData = await saveDataManager.LoadDataAsync<ContentsContinueSaveDataType>(SaveDataTypes.ESaveDataType.ContentsContinue);
  var ccManager = Managers.Instance?.GetManager<ContentsContinueManager>();
  if (ccData != null) ccManager?.LoadFromSaveData(ccData.claimedContentIndices);
  ```

### 4.8 `Core/Managers/Cheat/CheatCommandLibrary.cs`
- 등록: `commands.AddRange(ContentsContinueModule.CreateCommands());`
- `ContentsContinueModule` 추가 — **`reset_all` + `set_ui_mode` 2개만** (`reset_infinity_craft` 제외).

### 4.9 `Utils/Editor/JsonToSO.cs`
- MenuItem 1개:
  ```csharp
  [MenuItem("Tools/JsonToSO/CreateContentsContinueDataSO")]
  static void ContentsContinueDataDataInit()
  {
      DynamicMenuCreator.CreateMenusFromJson<ContentsContinueDataData>("ContentsContinueData.json", typeof(ContentsContinueDataSO));
  }
  ```

---

## 섹션 5 — sync 체크리스트

### 공통
- [x] FROM 전용 namespace 잔존 없음(`Geuneda`, `ServiceAccessor`, `MessageBroker`, `BaseService`, `UniRx`)
- [x] `async void` 없음
- [x] 이벤트 구독 해제(`Cleanup`/`UnsubscribeFromEvents`) 확인

### 신규 파일 (8)
- [x] `Core/Managers/ContentsContinueManager.cs` (ADAPTED, +내부 enum `EContentsContinueUIMode`)
- [x] `SOs/SO/DataSheet/ContentsContinueDataSO.cs` (DIRECT)
- [x] `SOs/Class/DataSheet/ContentsContinueDataData.cs` (DIRECT)
- [x] `UI/ContentsContinue/ContentsContinueUI.cs` (ADAPTED)
- [x] `UI/ContentsContinue/ContentsContinueItemUI.cs` (ADAPTED)
- [x] `UI/ContentsContinue/ContentsContinueCardUI.cs` (ADAPTED)
- [x] `UI/ContentsContinue/ContentsContinueLevelSectionUI.cs` (DIRECT)
- [x] `UI/ContentsContinue/ContentsContinueTimelineUI.cs` (ADAPTED)

### 기존 수정 (9)
- [x] SaveDataTypes.cs (enum+키+클래스)
- [x] SaveDataManager.cs (switch 3곳)
- [x] GameEventTypes.cs (enum+이벤트 데이터 클래스 — WD EventDataTypes.cs에 POCO 추가)
- [x] Managers.cs (ManagerDefinition 326)
- [x] RedDotManager.cs (노드+구독+체크)
- [x] LobbyMainUI.cs (버튼/진입/가시성/구독)
- [x] PlayerDataManager.cs (로드 블록)
- [x] CheatCommandLibrary.cs (모듈 2커맨드)
- [x] JsonToSO.cs (메뉴 1개)

### 리소스 (Phase 4 후반 / 5)
- [ ] 프리팹 5개: `Resources/UI/ContentsContinueUI.prefab`, `Resources/UI/ContentsContinueTimelineUI.prefab`, `3_Prefabs/UI/ContentsContinue/{CardUI,LevelSection,ItemUI}.prefab`
- [ ] `Resources/JsonFiles/ContentsContinueData.json`
- [ ] `Resources/ScriptableObjects/ContentsContinueData/1~18.asset` (ECurrencyType 이름 기준 리맵)
- [ ] `Resources/Sprites/UI/ContentsContinue/` (스프라이트) — WD는 Resources_moved/Addressables 경로 확인

### 커밋 순서 (그린 유지)
1. enum/이벤트 데이터/SaveDataType/클래스 인프라 (컴파일 기반)
2. ContentsContinueManager + DataSO/Data + Managers.cs 등록
3. UI 5개 (매니저 의존 해소 후)
4. RedDot/Lobby/PlayerData/Cheat/JsonToSO 결선
5. 프리팹/데이터/스프라이트

---

## 섹션 6 — 주의사항

- **초기화 순서**: ContentsContinueManager priority=326 (>PlayerData 302). 등록 누락 시 `GetManager` null.
- **이벤트 선행**: GameEventType enum + POCO를 먼저 커밋하지 않으면 publisher/subscriber 동시 컴파일 실패.
- **WD divergence 보존**: ManagerFactory 이식 제외, InfinityCraft 전부 제외(Cheat `reset_infinity_craft` 포함).
- **ECurrencyType 리맵**: 데이터 .asset 차팅 시 enum 이름 기준(메모리 규칙). 클래스 .cs는 무수정.
- **DataSheet SO 규칙**: `SOs/SO/DataSheet/` 자동생성물 — 핸드 수정 금지. 생성 클래스 복사는 신규라 OK, 데이터는 JsonToSO 메뉴로 생성.
- **UIBase 반환형**: `OpenedAsync/ClosedAsync` UniTask→Task 2파일만.
- **Resources.Load**: ItemUI 아이콘 1곳 — 경로/Addressables 검증 TODO.

---

## 섹션 7 — diff 비교 전략

신규 파일은 변환분만 diff에 잡혀야 함:

```bash
W=/tmp/sync_ContentsContinueUI_1780395871
T=/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender
for f in \
  Core/Managers/ContentsContinueManager.cs \
  SOs/SO/DataSheet/ContentsContinueDataSO.cs \
  SOs/Class/DataSheet/ContentsContinueDataData.cs \
  UI/ContentsContinue/ContentsContinueUI.cs \
  UI/ContentsContinue/ContentsContinueItemUI.cs \
  UI/ContentsContinue/ContentsContinueCardUI.cs \
  UI/ContentsContinue/ContentsContinueLevelSectionUI.cs \
  UI/ContentsContinue/ContentsContinueTimelineUI.cs ; do
  echo "=== $f ==="; diff "$W/Assets/_Project/1_Scripts/$f" "$T/Assets/_Project/1_Scripts/$f"
done
```

| 파일 | 적용 규칙 | 예상 diff |
|---|---|---|
| ContentsContinueManager.cs | 규칙1/3/5 | base 1줄 + ServiceAccessor N줄 + MessageBroker 1~2줄 |
| ContentsContinueDataSO/Data.cs | 없음 | **0줄** |
| ContentsContinueLevelSectionUI.cs | 없음 | **0줄** |
| ContentsContinueUI.cs | 규칙3 + UniTask→Task | ServiceAccessor N줄 + 반환형 2줄 |
| ContentsContinueTimelineUI.cs | 규칙3 + UniTask→Task | 동일 |
| ContentsContinueItemUI.cs | 규칙3 (+규칙11 검토) | ServiceAccessor N줄 (+Resources.Load 1줄) |
| ContentsContinueCardUI.cs | 규칙3 | ServiceAccessor N줄 |

> DIRECT 파일이 0줄이 아니면 의도치 않은 변경 — 재검토.
