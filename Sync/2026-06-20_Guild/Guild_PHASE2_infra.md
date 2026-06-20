# Guild Sync — Phase 2 Step D+E (인프라 초기화 + 결선 검증)

- FROM = `/tmp/sync_Guild_1781924940` (BunkerDefense, 풀 프로젝트 2270 cs)
- TO = `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 작성일 2026-06-20

---

## 0. 최상위 결론 (먼저 읽을 것)

이번 Step D/E 조사의 핵심은 **enum 몇 개 추가**가 아니라 **아키텍처 분기**다.

1. **FROM(BD)은 이미 `com.geuneda.services` 프레임워크로 전환 완료**. 길드 시스템은 이 프레임워크 위에 세워져 있다.
   - 길드 이벤트는 `GameEventType` enum이 **아니라** `Geuneda.Services.IMessage` + `MessageBroker.PublishSafe(...)` 패턴을 쓴다.
   - FROM에는 **`GameEventTypes.cs`도 `EventManager.cs`도 존재하지 않는다** (전부 삭제됨, 잔존 GameEventType 참조 2건뿐 — 길드와 무관한 레거시).
   - `GuildManager : BaseService` (FROM `Core/Base/BaseService.cs`), `GuildServerService : BaseServerService`.
2. **TO(WD)는 아직 구(舊) 아키텍처**: `EventManager` + `GameEventTypes` enum, `BaseManager` 기반.
   - WD에는 `Geuneda.Services` / `MainInstaller` / `ServiceAccessor` / `IMessageBrokerService` / `IMessage` / `MessageBroker.PublishSafe` / `BaseService`가 **전혀 없다** (manifest.json에 geuneda 패키지 0개).

> **따라서 "GameEventType에 길드 이벤트 31개 추가"는 불가능/불필요하다.** 길드 이벤트는 enum 항목이 아니라 30개의 `IMessage` 클래스 파일(이미 `Events/Guild/` 3파일에 들어있음)이며, 동작하려면 그 클래스들이 의존하는 `Geuneda.Services` 프레임워크가 WD에 먼저 깔려야 한다.

### 선행 블로커 (이게 안 되면 나머지 전부 무의미)
길드 코드가 컴파일조차 되려면 WD에 다음이 있어야 한다:
- `com.geuneda.services` 패키지 (manifest.json) — `Geuneda.Services` 네임스페이스, `IMessage`, `IMessageBrokerService`, `MainInstaller`, `ServiceAccessor`, `MessageBroker.PublishSafe`
- `Core/Base/BaseService.cs` (`abstract class BaseService : IBaseManager, IDisposable`)
- (선택) `com.geuneda.gamedata` / `nativeui` / `uiservice` — 길드가 직접 쓰는지는 Phase 2 다른 Step에서 확인 필요

이건 길드 단독 sync 범위를 넘어서는 **프레임워크 이식**이다. 별도 선행 페이즈로 다루거나, 길드 코드를 WD의 `EventManager`/`GameEventType`/`BaseManager`로 **포팅(개조)**해야 한다. 후자는 메모리 룰 "sync 시 WD 구조 변경 금지"와 충돌하므로 사용자 결정 필요.

---

## 1. Managers.cs 등록 비교

### FROM (ManagerFactory.cs)
FROM은 `MANAGER_DEFINITIONS`가 별도 `Core/Base/ManagerFactory.cs`에 있다. 길드 등록은 **단 1줄**:
```csharp
new ManagerDefinition(typeof(GuildManager), 330, "Lobby", true, true, false), // 길드 시스템 매니저 (서버/세이브 이후, 내부 GuildQuestModule 포함)
```
- priority **330**, category **"Lobby"**, autoInitialize **true**, essential **true**, isMonoBehaviour **false**
- `GuildServerService`는 **매니저가 아님** (BaseServerService 서비스, GuildManager 내부에서 사용). MANAGER_DEFINITIONS에 없음.
- `GuildRaidManager`는 **존재하지 않음**. 길드 레이드 로직은 `GuildManager.Raid.cs`(partial) + `GuildRaidStagePlayService` + 컨트롤러들이 담당.

### TO (Managers.cs)
TO는 `MANAGER_DEFINITIONS`가 `Managers.cs` 안에 인라인(별도 ManagerFactory 없음). 동형 매니저 우선순위:
```csharp
new ManagerDefinition(typeof(DailyQuestManager), 330, "Lobby", true, true),       // isMono 인자 생략(기본 true 아님 — 4인자 생성자)
new ManagerDefinition(typeof(GuideQuestManager), 330, "Lobby", true, true),
new ManagerDefinition(typeof(ContentsContinueManager), 326, "Lobby", true, true),
...
new ManagerDefinition(typeof(VanguardManager), 342, "Lobby", true, true),
```
- TO `DailyQuestManager : BaseManager` (FROM은 `GuildManager : BaseService` — 베이스 클래스 자체가 다름).

### 결론: TO에 추가할 라인
> 단, **GuildManager가 BaseManager로 포팅되거나 BaseService가 WD에 이식된 뒤에만** 유효.
```csharp
// Managers.cs MANAGER_DEFINITIONS, DailyQuest/GuideQuest 인근(priority 330 "Lobby")에 추가:
new ManagerDefinition(typeof(GuildManager), 330, "Lobby", true, true, false), // 길드 시스템 매니저
```
- GuildServerService: 추가 **안 함** (서비스).
- GuildRaidManager: **없음** (추가 안 함).
- isMonoBehaviour=false 인자(6인자 생성자) 사용 — TO에 6인자 생성자 있는지 확인 필요(있음: line 34 `ManagerDefinition(System.Type, int, string, bool=true, ...)` 형태, isMono 오버로드 존재 확인됨).
- CheatManager 쪽: FROM `Cheat/Guild/` 디렉터리 존재 → 치트 등록은 Step별 cheat 파일 처리(인프라 범위 외).

---

## 2. Enum 확장 비교

### 2-1. ECurrencyType (`Core/Enums/ECurrencyType.cs`)
FROM 길드 재화:
| 이름 | FROM 값 | TO 충돌 여부 |
|---|---|---|
| `ClanGiftEpic` | 820 | 비어있음 → **820 그대로 OK** |
| `ClanGiftLegendary` | 821 | 비어있음 → **821 그대로 OK** |
| `ClanGiftMythic` | 822 | 비어있음 → **822 그대로 OK** |
| `ClanCurrency` (길드 재화) | 1128 | **충돌!** TO 1128 = `RandomChip0_108` |
| `ClanContribution` (공헌도) | 1129 | **충돌!** TO 1129 = `RandomChip0_109` |

WD ECurrencyType 마지막 값은 1301(`VanguardChipSelectBoxTranscend`). 메모리 룰: currencyType은 **enum 이름 기준 리맵 필수**.

> **제안 추가(리맵 적용):**
> ```csharp
> ClanGiftEpic = 820,
> ClanGiftLegendary = 821,
> ClanGiftMythic = 822,
> ClanCurrency = 1302,       // FROM 1128 → 충돌 회피 리맵
> ClanContribution = 1303,   // FROM 1129 → 충돌 회피 리맵
> ```
> ⚠️ 1128/1129 리맵 시: 서버/시트가 `ClanCurrency`/`ClanContribution`을 **정수가 아닌 enum 이름**으로 직렬화/매핑하는지 반드시 확인. 정수 ID로 서버 통신하면 리맵이 서버와 불일치. (메모리 `project_ecurrencytype_bd_wd_divergence` 참조)

### 2-2. ESaveDataType + FirebaseKeys (`Core/Managers/SaveDataTypes.cs`)
**추가 불필요.** FROM에도 길드 save type/FirebaseKey **없음**. 길드는 전면 **서버 권위**(Firebase realtime 컬렉션), 클라는 GuildManager 인메모리 캐시만 유지하고 SaveData에 영속하지 않음. (sub-agent 검증 완료)

### 2-3. EContentType (`Core/Enums/ContentTypes.cs`)
FROM 추가분 (명시적 int 500번대로 격리):
```csharp
UI_Guild = 500,           // 레벨 25 (길드)
Dungeon_GuildRaid = 501,  // 레벨 25 (길드 레이드)
```
> TO에 동일하게 추가. (TO는 현재 enum 끝이 `Feature_Relic`. 500/501은 비어있음 → 그대로 OK.)
> 추가 주의: FROM의 `ContentUnlockEventData`는 `: BaseEventData, Geuneda.Services.IMessage` 로 IMessage 상속이 붙어있음. TO는 `: BaseEventData`만. **WD 포팅 시 IMessage 부분 제거**(Geuneda 미존재).

### 2-4. GameModeType (`Core/GameModes/GameModeType.cs`)
FROM 추가분:
```csharp
GuildRaid,       // 길드 레이드 모드 - GuildBossScene, 무적 보스 누적 피해량 경쟁
```
> TO enum 끝(`Vanguard,`) 뒤에 `GuildRaid,` 추가.
> ⚠️ FROM에는 `Gold` 모드가 없음(WD엔 있음). enum 순서/값 차이 무시하고 **이름만** 추가.

### 2-5. EBottomTabType (`Core/Enums/EBottomTabType.cs`)
- TO: `{Shop, HeroUpgrade, Lobby, UnitUpgrade, Dungeon, ComingSoon}`
- FROM: `{Shop, HeroUpgrade, Lobby, UnitUpgrade, Headquarter, Guild, ComingSoon}`
> **구조 분기 주의:** FROM은 `Dungeon` 대신 `Headquarter`+`Guild`. WD는 `Dungeon`을 유지하므로 **단순히 `Guild`만 추가**:
> ```csharp
> public enum EBottomTabType { Shop, HeroUpgrade, Lobby, UnitUpgrade, Dungeon, Guild, ComingSoon }
> ```
> `Headquarter`는 WD에 없는 개념 → 추가하지 말 것.

### 2-6. GameEventTypes (`Core/Enums/GameEventTypes.cs`)
**추가 항목 = 0.** (Step 프롬프트의 "31개 추가" 전제는 잘못됨.)
- FROM엔 GameEventTypes.cs 자체가 없음. 길드 이벤트는 아래 30개 `IMessage` 클래스로 존재(이미 `Events/Guild/` 3파일에 포함, enum 아님):

**GuildEvents.cs (21):** GuildJoinedMessage, GuildLeftMessage, GuildUpdatedMessage, GuildMemberJoinedMessage, GuildMemberLeftMessage, GuildLeaderChangedMessage, GuildLevelUpMessage, GuildCurrencyChangedMessage, GuildJoinRequestSentMessage, GuildJoinRequestCanceledMessage, GuildJoinTypeChangedMessage, GuildChatReceivedMessage, GuildDmReceivedMessage, GuildBuffChangedMessage, GuildDailyDonationChangedMessage, GuildPersonnelOfficeClosedMessage, GuildPendingJoinRequestCountChangedMessage, GuildDiscountTodayChangedMessage, GuildMainRedDotChangedMessage, GuildGiftSeasonExpiredMessage, GuildGiftClaimStateChangedMessage

**GuildRaidEvents.cs (4):** GuildRaidStatusUpdatedMessage, GuildRaidStrengthenedMessage, GuildRaidRankingRefreshedMessage, GuildRaidQuestProgressMessage

**ClanQuestEvents.cs (5):** ClanQuestProgressChangedMessage, ClanQuestClaimedMessage, ClanQuestExpChangedMessage, ClanQuestProgressTierClaimedMessage, ClanQuestStatusRefreshedMessage

> **이 30개를 WD GameEventType enum으로 강제 변환하려면** 모든 publish/subscribe 호출부(MessageBroker.PublishSafe → EventManager.Dispatch, RecvSubscribe → EventManager.Subscribe)와 페이로드(메시지 클래스의 프로퍼티 → EventData 파생)도 전부 개조해야 함. 사실상 길드 전 모듈 재배선. **권장: Geuneda 프레임워크 이식이 더 단순/안전.**

---

## 3. SaveDataManager JsonSerializer 비교
양쪽 **동일**:
```csharp
private static JsonSerializer CreateJsonSerializer()
{
    var settings = new JsonSerializerSettings();
    settings.Converters.Add(new SerializableDictionaryConverter());
    return JsonSerializer.Create(settings);
}
```
- 단일 컨버터 `SerializableDictionaryConverter`. **길드 전용 커스텀 컨버터 없음.** 길드는 서버 권위라 SaveData 직렬화 의존 0. → SaveDataManager **수정 불필요**.

---

## 4. 결선 검증 (call graph) — TO에서 수정해야 할 기존 파일

> 모두 **Geuneda/BaseService 선행 이식 후**에만 실제 컴파일/동작.

### 4-1. BottomTabHUD.cs (`UI/BottomTabHUD.cs`) — 수정 필요
FROM 결선:
- 배열 크기 `new BottomTabButton[6]` (Guild 포함). TO는 `[5]` → **6으로**.
- `SetSelectedTab` switch에 `EBottomTabType.Guild` case → `OpenGuildTab()` 호출.
- `OpenGuildTab()` 신규 메서드: `GuildEntryRouter.EnterAsync().Forget();`
- 탭 락 처리(FROM line ~920): 미해금 시 버튼 GameObject 자체 SetActive(false), 해금되면 활성:
  ```csharp
  if (tab.tabType == EBottomTabType.Guild) {
      bool isGuildUnlocked = IsTabUnlocked(EBottomTabType.Guild);
      tab.button.gameObject.SetActive(isGuildUnlocked);
      if (!isGuildUnlocked) return;
  }
  ```
- 레드닷 매핑: `EBottomTabType.Guild => GuildRedDotKeys.Root`
- 락 토스트: `EBottomTabType.Guild => "guild_require_level_25"` (로컬라이즈 키 확인)
- `IsTabUnlocked` 본문은 양쪽 동일 → ContentUnlockManager에 위임하므로 추가 변경 불필요.
- ⚠️ FROM은 `Headquarter` 탭도 있음 → WD엔 없으므로 Headquarter 관련 결선은 **이식 제외**.

### 4-2. ContentUnlockManager.cs — 수정 필요
- `GetTabContentType` switch에 `EBottomTabType.Guild => EContentType.UI_Guild` 추가 (FROM line 199).
- `_unlockConditions` 배열에 추가 (FROM line 260, 276):
  ```csharp
  new ContentUnlockCondition(EContentType.UI_Guild, 25),
  new ContentUnlockCondition(EContentType.Dungeon_GuildRaid, 25),
  ```
- BD 해금 레벨 = **Lv.25** (UI_Guild, Dungeon_GuildRaid 둘 다).

### 4-3. LobbyMainUI.cs — 수정 필요(검토)
- FROM 길드 진입은 **`GuildEntryRouter.EnterAsync()`** 라우터 패턴:
  - 가입중 → `GuildMainUI` 표시
  - 미가입 → `GuildRecruitmentsUI`(검색/가입) 표시
- FROM LobbyMainUI는 `GuildJoinedMessage`/`GuildLeftMessage`/`GuildMainRedDotChangedMessage` 구독(레드닷/표시 갱신).
- TO `UI/LobbyMainUI.cs`가 대응 파일. 진입 버튼/레드닷 결선 추가 필요. (구독은 WD에선 EventManager로 개조 or Geuneda 이식.)
- `GuildEntryRouter`는 길드 UI 패키지의 일부 → Phase 2 다른 Step(개별 길드 파일)에서 이식.

### 4-4. SceneManager.cs — 수정 필요 (구조 분기 주의 ⚠️)
- FROM: 별도 씬 `GUILD_RAID = "GuildBossScene"` + 제네릭 `LoadGameplaySceneAsync(mode, stageId, sceneName)` + 래퍼 `LoadGuildRaidSceneAsync(stageId)`. 또 `LastPlayedGuildRaidStageID`, `IsGameplayScene` 헬퍼, 게임오버/로비복귀(`GuildRaidLobbyUI` 재오픈) 등 광범위 결선.
- TO: 단일 `LoadGameSceneAsync(mode, stageId)` → 항상 `SceneNames.GAME`. 제네릭 씬 인자 없음.
- PunchKing/Vanguard 분기는 TO에서 `if (CurrentGameMode == GameModeType.PunchKing/Vanguard)` 형태로 **씬은 공유(GameScene)** 하고 모드 분기만 함. 길드 레이드는 FROM에서 **별도 씬(GuildBossScene)** 을 씀 → WD 패턴(단일 GameScene)과 충돌.
- **선택지:**
  1. (WD 구조 유지) GuildBossScene을 GameScene 모드 분기로 흡수 — 컨트롤러/스폰/HUD가 GuildBossScene 프리팹 의존하면 큰 작업.
  2. (FROM 구조 도입) `GuildBossScene` 씬 자산 + `LoadGuildRaidSceneAsync` + `IsGameplayScene` 헬퍼를 이식 — SceneManager에 신규 진입점 추가. 메모리 룰 "sync 시 WD 구조 변경 금지"와 부분 충돌 → **사용자 결정 필요**.
  - 최소 추가 항목(2안 기준): `SceneNames.GUILD_RAID="GuildBossScene"`, `LoadGuildRaidSceneAsync`, `LastPlayedGuildRaidStageID`, GuildRaid 게임오버/로비복귀 분기. GameModeType.GuildRaid case는 GameScene이 아닌 별도 씬을 로드.

### 4-5. MessageBroker publisher/subscriber 정합성
- 길드 publish는 전부 `GuildManager.*` / `GuildQuestModule` 등 길드 매니저 내부. subscribe는 `UI/Guild/*` + `LobbyMainUI`(레드닷). **non-guild TO 파일이 길드 메시지를 구독하는 케이스 없음** (LobbyMainUI만 길드 메시지 구독 → 이건 의도된 결선, 위 4-3에서 처리).
- 역방향(길드가 비길드 메시지 구독): `ClanQuestProgressChangedMessage`가 `EDailyQuestCondition`을 인자로 씀 → 길드 퀘스트가 일일퀘스트 조건 체계를 재사용. WD `EDailyQuestCondition` 존재 확인됨(enum 파일 있음). 추가 컨디션 필요 시 별도 확인.
- **핵심 리스크는 채널 불일치가 아니라 채널 자체(MessageBroker IMessage)가 WD에 없다는 것** — §0 블로커.

---

## 5. 주의사항 (요약)
1. **최대 블로커**: `com.geuneda.services` 프레임워크 + `BaseService`가 WD에 없음. 길드는 이 위에 세워짐. 이식 or 길드 코드 전면 포팅 중 택1 — 사용자 결정 필요.
2. **GameEventType 추가 0개** (프롬프트 전제 오류). 길드 이벤트=30개 IMessage 클래스(파일로 이식), enum 아님.
3. **ECurrencyType 1128/1129 충돌** → ClanCurrency/ClanContribution을 1302/1303으로 리맵. 단 서버가 enum 정수ID로 통신하면 리맵 금지(이름 직렬화 확인 필수).
4. **SaveData/JsonSerializer 변경 0** (길드 서버 권위).
5. **EBottomTabType**: Guild만 추가, Headquarter는 WD 미존재라 제외.
6. **SceneManager 구조 분기**: GuildBossScene 별도 씬 vs WD 단일 GameScene. 구조 변경 금지 룰과 충돌 → 사용자 결정.
7. **ContentUnlockEventData**의 `Geuneda.Services.IMessage` 상속은 WD 포팅 시 제거.
8. 해금 레벨 BD Lv.25 (UI_Guild, Dungeon_GuildRaid).
