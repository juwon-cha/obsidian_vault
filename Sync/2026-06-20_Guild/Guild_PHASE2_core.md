# Guild Phase 2 — Core 매니저 + 모듈 분석

- 작성일: 2026-06-20
- 영역: `Core/Managers/GuildManager*.cs` (7) + `Core/Managers/Guild/` (18) + `Core/Managers/RedDotManager.Guild.cs` (1) = **26 파일**
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- READ-ONLY 분석. 본 문서 1개만 생성.

---

## 0. 한눈에 (요약 수치)

| 항목 | 값 |
|------|----|
| 분석 파일 | 26 |
| ServiceAccessor.Get<T>() 총합 | **59건** |
| MainInstaller.Resolve | 3파일 (GiftSeason / DiscountModule / QuestModule) |
| using Geuneda.Services | 3파일 (동일) |
| MessageBroker (Subscribe/Publish/Unsubscribe) | GuildManager 본체+partial 대부분 + QuestModule + DiscountModule + RedDot |
| MessageBroker 이벤트 종류 | **31종** (§5) |
| DateTime.Now | 0건 (전부 ServerTimeManager.NowUnscaled, 폴백만 DateTime.UtcNow) |
| Resources.Load / ToUniTask / async void / SavePlayerDataAsync | 0건 |

분류 합계: **DIRECT 13 / ADAPTED 11 / PARTIAL 2 / BLOCKED 0**

---

## 1. WD 인프라 정합성 (변환 전제) — ★중요

| BD(FROM) | WD(TO) 실측 | 변환 |
|---|---|---|
| `GuildManager : BaseService` | WD에 **BaseService 없음**. `BaseManager` / `BaseSystemManager` 존재 (InitializeAsync/IsInitialized/Cleanup 동일 시그니처) | `: BaseManager` 로 교체 |
| `ServiceAccessor.Get<T>()` | `Managers.Instance.GetManager<T>()` (매니저 내부는 상속 `GetManager<T>()`도 가능, plain 모듈은 `Managers.Instance.GetManager<T>()`) | 기계적 치환 |
| `MainInstaller.Resolve<ITickService>()` | WD는 Doozy `TickService` (`Assets/Doozy/.../TickService.cs`). Geuneda ITickService 없음 | GiftSeason/Quest 의 tick 구독을 WD Tick 또는 Update 루프로 재배선 (ADAPTED) |
| `MainInstaller.Resolve<IMessageBrokerService>()` | 없음. EventManager(static) | EventManager 로 치환 |
| `MessageBroker.Subscribe<T>/PublishSafe/Unsubscribe` (Geuneda) | EventManager.Subscribe<T>(GameEventType.X, h)/Dispatch/Unsubscribe (static) | **이벤트 31종을 GameEventType 으로 신규 등록 + 페이로드 타입 매핑** |
| `DailyResetMessage` | `EventManager.Subscribe<TimeEventData>(GameEventType.DailyReset, ...)` | TimeEventData 핸들러로 치환 |
| `IServerService _serverManager = GetManager<ServerManager>()` | WD에 `ServerManager` + `IServerService` 존재 | DIRECT (서버 서비스는 Phase2 server 영역) |
| `BalanceDataManager.LoadBalanceData(tableName)` | WD 존재 (동일 시그니처) | DIRECT |
| `BalanceTableNames.CLAN_*` | WD `BalanceTableNames` 에 **CLAN_ 상수 없음** | 상수 14종 추가 필요 (server/data 영역과 협의) |
| `ClanConstDataParser` | WD에 **없음** (Donation/Raid가 `ClanConstDataParser.DailyDonationLimit` 등 참조) | 동반 이식 필요 (Phase1 §20) |
| `ServerTimeManager.NowUnscaled` | WD 존재 | DIRECT |

> 핵심 함정: BD의 `MessageBroker`(Geuneda)는 WD의 UniRx `MessageBroker`(Plugins/UniRx)와 **이름만 같고 다른 것**. 절대 UniRx로 매핑하지 말고 EventManager로 가야 한다. WD 컨벤션은 EventManager 단일.

---

## 2. Managers.cs 등록 (MANAGER_DEFINITIONS)

- **GuildManager** — 1개만 등록. `new ManagerDefinition(typeof(GuildManager), <order>, "Lobby", true, true)`.
  - 참조 모델: RedDotManager(order 355) **앞**에 둘 것 — RedDotManager.Guild 평가가 GuildManager 캐시에 의존. ContentUnlockManager/CurrencyManager/ServerManager/DamageCalculationManager/StageManager 보다 뒤.
  - `IsInitialized` 가드, `InitializeAsync`/`Cleanup` override 존재 → BaseManager 패턴 그대로.
- **18개 모듈은 plain C# 클래스** — Managers.cs 등록 금지. `GuildManager.InitializeAsync()` 안에서 `new` 로 생성 (현 코드 그대로). EGuildApiKey 는 enum.
- **RedDotManager.Guild.cs** 는 RedDotManager 의 partial — 별도 등록 불필요. RedDotManager 는 이미 WD에 등록됨(order 355). 단 길드 message 핸들러 31종 구독을 RedDotManager 본체의 Subscribe 블록(WD)에 추가 배선해야 함(ADAPTED).
- **GuildServerService** (Phase2 server 영역 담당) 도 Managers 등록 대상 — 본 영역 아님, 참고만.

---

## 3. GuildManager.InitializeAsync() 모듈 생성 패턴

`InitializeAsync()`에서 순차 `new` + `Initialize()` (Quest만 `await InitializeAsync()`):

```
LevelTable, FlagCatalog, Discount, Contribution, ShopCatalog, ShopGroupTable → new + Initialize()
Quest → new + await InitializeAsync()
Rental, GiftCatalog → new + Initialize()
InitializeGiftSeason()  (partial: GiftSeason new + tick 구독)
InitializeRaidModules() (partial: RaidSeason/RaidMemberReward/RaidPersonalReward)
```

Cleanup()은 역순 `?.Cleanup()` + null. **Cleanup에서 `MessageBroker.Unsubscribe<DailyResetMessage>(this)` → EventManager.Unsubscribe 로 치환 필수** (구독 누수 방지).

각 모듈은 `GuildCatalogModuleBase<TRow>` 상속 → `Initialize()` 에서 `GuildDataLoader.LoadJson(TableName, LocalResourcePath)` → `JsonHelper.FromJson`. WD에 JsonHelper/BalanceDataManager/ResourceManager 존재하므로 GuildDataLoader는 DIRECT(ServiceAccessor 2건만 치환).

---

## 4. EGuildApiKey / RunDedupedAsync dedup 메커니즘

- `EGuildApiKey` enum 10값: MyGuild/MainRedDot/Shop/Discount/Quest/Donation/Rental/Ranking/JoinRequests/Raid.
- `RunDedupedAsync(key, fetcher)`: `Dictionary<EGuildApiKey, List<UniTaskCompletionSource>> _inflightWaiters`.
  - 진행 중인 key면 호출자가 자체 UniTaskCompletionSource를 받고 waiters에 추가 → 단일 fetch로 합침 (`UniTask.Preserve` multi-subscriber 비안전성 회피).
  - 완료 시 `_inflightWaiters.Remove(key)` 후 waiters 일괄 `TrySetResult/TrySetException`.
  - Cleanup에서 모든 waiter `TrySetException(OperationCanceledException)`.
- **WD 의존 없음** (순수 UniTask). DIRECT. WD에 동일 디둡 인프라 없으니 그대로 이식.

---

## 5. MessageBroker 이벤트 전수 (GameEventType 신규 등록 목록) — ★31종

발행/구독으로 본 영역에서 등장하는 메시지 타입. **모두 GameEventType enum + 페이로드 타입을 WD에 신규 등록해야 함.**

생명주기/상태:
1. `GuildJoinedMessage` { Guild }
2. `GuildLeftMessage` { GuildIdx, Disbanded, Kicked }
3. `GuildUpdatedMessage` { Guild }
4. `GuildJoinRequestSentMessage` { GuildIdx }
5. `GuildJoinRequestCanceledMessage` { GuildIdx }
6. `GuildJoinTypeChangedMessage` { JoinType }
7. `GuildLeaderChangedMessage` { OldGamerId, NewGamerId }
8. `GuildMemberLeftMessage` { GamerId, WasKicked }
9. `GuildMemberJoinedMessage` { GamerId }
10. `GuildPendingJoinRequestCountChangedMessage` { Count }
11. `GuildMainRedDotChangedMessage` { }

공헌/버프/통화:
12. `GuildLevelUpMessage` { OldLevel, NewLevel }
13. `GuildCurrencyChangedMessage` { Currency, Contribution }
14. `GuildDailyDonationChangedMessage` { DonationCount, MaxDonation }
15. `GuildBuffChangedMessage` { Buff }

채팅/선물:
16. `GuildChatReceivedMessage` { Chat }
17. `GuildDmReceivedMessage` { Dm }
18. `GuildGiftClaimStateChangedMessage` { GiftIdxs }

선물 시즌:
19. `GuildGiftSeasonExpiredMessage` { ExpiredSeasonIndex }

할인:
20. `GuildDiscountTodayChangedMessage` { }

레이드:
21. `GuildRaidStatusUpdatedMessage` { }

퀘스트(Clan* 접두 — 별도 Events 파일 GuildEvents/ClanQuestEvents):
22. `ClanQuestStatusRefreshedMessage` { }
23. `ClanQuestProgressChangedMessage` { Condition }
24. `ClanQuestClaimedMessage` { QuestId }
25. `ClanQuestProgressTierClaimedMessage` { TierIndex }
26. `ClanQuestExpChangedMessage` { TotalExp }

구독만 (외부 도메인 — WD에 이미 존재할 가능성 높음, 이름 매칭 확인 필요):
27. `DailyResetMessage` → WD: `TimeEventData` / `GameEventType.DailyReset`
28. `StageStartedMessage` (StageData 포함) — WD 존재 여부 확인
29. `ApplicationPauseChangedMessage` { IsPaused }
30. `ContentUnlockedMessage` — WD 존재 여부 확인
31. QuestConditionBinder 가 Bind 하는 외부 메시지 (ChipRefinedMessage / DoubleRewardClaimedMessage / PunchKingChallengeUsedMessage / ArkChallengeStartedMessage / EnemyDiedMessage / GachaDrawEventData / RaceTowerRewardClaimedMessage / CurrencyChangedEventData) — **이건 QuestConditionBinder.cs(UI 영역?) 소속**, GuildQuestModule 이 의존. WD 동등 이벤트 매핑 필요 (PARTIAL).

> 22~26 의 `Clan*` 접두는 BD에서 `Core/Events/Guild/ClanQuestEvents.cs` 등에 정의(Phase1 §7). 이벤트 정의 파일은 본 영역이 아니므로 동반 이식 + GameEventType 등록은 Events 영역과 협업.

---

## 6. 파일별 분류표

### 6-a. GuildManager 본체 + partial (7)

| 파일 | 역할 | ServiceAcc | 분류 | 비고 |
|------|------|:---:|------|------|
| GuildManager.cs | 길드 비즈니스 매니저(캐시/이벤트/도메인). 가입/창설/관리/권한/공헌/버프/메인레드닷/dedup | 6 | **ADAPTED** | `:BaseService`→`:BaseManager`, DailyResetMessage→TimeEventData, Publish 13종→EventManager.Dispatch |
| GuildManager.Chat.cs | 채팅/DM/폴링/도배가드(60s·20)/선물(send·claim·multi). UniTaskVoid 폴링루프 | 6 | **ADAPTED** | `ServiceAccessor.Get<UIManager>().Show<GuildGiftDetailPopup>` 는 UI영역 의존(PARTIAL성). LocalizationManager/ToastManager 직접 호출 OK |
| GuildManager.Donation.cs | 공헌 후처리 + 일일공헌 캐시. CurrencyManager 차감/적립 | 0 | **ADAPTED** | GetManager 이미 사용. Publish(DailyDonationChanged). ClanConstDataParser 의존 |
| GuildManager.GiftSeason.cs | 선물 시즌 만료 감시(ITickService 1s tick) | 2 | **ADAPTED** | `MainInstaller.Resolve<ITickService>` + `using Geuneda.Services`. WD Tick/Update 재배선 |
| GuildManager.Raid.cs | 레이드 도메인(enter/clear/strengthen/ranking/quest). JSON diff 캐시, _pendingRaidClear Preserve | 8 | **ADAPTED** | Newtonsoft.Json(WD OK), StageManager/ResourceManager/UIManager/BottomTabHUD 의존, Publish(RaidStatusUpdated). ClanConstDataParser.RaidSpendGem |
| GuildManager.Rental.cs | 미니언 로드아웃 서버 동기화 글루 | 0 | **DIRECT** | GetManager<MinionManager> 사용 |
| GuildManager.Shop.cs | 상점 구매 후처리(그룹 누진). GuildShopCurrencyMapper 의존 | 0 | **ADAPTED** | GetManager 사용. GuildShopCurrencyMapper(타 영역) 의존 |

### 6-b. RedDot partial (1)

| 파일 | 역할 | ServiceAcc | 분류 | 비고 |
|------|------|:---:|------|------|
| RedDotManager.Guild.cs | 길드 레드닷 키(GuildRedDotKeys static) + 7개 leaf 평가 + message 핸들러 17개 | 7 | **ADAPTED** | RedDotManager partial. SetRedDotActive/AddNode/_redDotNodes 는 WD RedDotManager에 존재 확인 필요. message 핸들러를 WD RedDotManager Subscribe 블록에 신규 배선 |

### 6-c. Guild/ 모듈 (18)

| 파일 | 역할 | ServiceAcc | 분류 | 비고 |
|------|------|:---:|------|------|
| EGuildApiKey.cs | dedup 키 enum(10) | 0 | **DIRECT** | 의존 0 |
| GuildCatalogModuleBase.cs | 카탈로그 시트 베이스(ID→Row dict + ordered) | 0 | **DIRECT** | JsonHelper.FromJson(WD OK) |
| GuildDataLoader.cs | 시트 로딩 헬퍼(BalanceDataManager→ResourceManager 폴백) | 2 | **DIRECT** | 치환만 |
| GuildLevelTableModule.cs | ClanLevelData + EGuildLevelEffect enum + 핫패스 캐시 | 0 | **PARTIAL** | ClanLevelDataData(시트 자동생성) 의존 → DataSheet 영역 |
| GuildFlagCatalogModule.cs | ClanFlagData + 스프라이트 캐시(ResourceUtility.LoadSprite) | 0 | **PARTIAL** | ResourceUtility WD 존재 확인 필요, ClanFlagDataData 의존 |
| GuildContributionModule.cs | ClanContributionData + GetDonateType | 0 | **DIRECT** | EGuildDonateType 의존(enum 영역) |
| GuildDiscountModule.cs | ClanDiscountData + 서버 today/participate/purchase 캐시 | 10 | **ADAPTED** | `MainInstaller.Resolve<IMessageBrokerService>`+`using Geuneda`. PublishTodayChanged→EventManager. ClanDiscountDataParser 의존 |
| ClanDiscountDataParser.cs | ClanDiscountData JSON DTO+enum 파서 | 0 | **DIRECT** | Enum.TryParse(ECurrencyType). DataSheet 클래스 의존 |
| GuildShopCatalogModule.cs | ClanShopData 서버 카탈로그 캐시 | 1 | **DIRECT** | 치환만. GuildShopCatalogResponse/Item(server 영역) |
| GuildShopGroupTableModule.cs | ClanShopGroupData 누진 단계 테이블 | 0 | **PARTIAL** | ClanShopGroupDataData 시트 의존 |
| GuildGiftCatalogModule.cs | ClanGiftData + ClanGiftIconConfigSO 로드 | 1 | **PARTIAL** | `ResourceManager.LoadResource<ClanGiftIconConfigSO>("CustomSO/Guild/...")` SO+경로 의존(에셋 영역) |
| GuildGiftSeasonModule.cs | ClanGiftSeasonData 활성시즌 판정 | 0 | **PARTIAL** | ClanGiftSeasonDataData 시트 의존 |
| GuildRentalModule.cs | 인력사무소 후보/대여확정/미니언동기화 | 6 | **ADAPTED** | ApplyGuildDocFromResponse 콜백, Rental DTO(server 영역) 의존. 치환 다수 |
| GuildQuestModule.cs | 일일퀘스트(시트+서버status/increment/claim, 디바운스 flush, limbo) | 9 | **ADAPTED** | `MainInstaller(ITick+IMessageBroker)`+`using Geuneda`+Firebase.Crashlytics. QuestConditionBinder 의존(외부 이벤트 12종). 가장 복잡 |
| GuildRaidRewardModuleBase.cs | 누적피해 보상 시트 베이스 + GrantClaimedRewards | 1 | **DIRECT** | CurrencyManager 치환만 |
| GuildRaidMemberRewardModule.cs | ClanRaidMemberReward 구체화 | 0 | **PARTIAL** | 시트 클래스 의존 |
| GuildRaidPersonalRewardModule.cs | ClanRaidPersonalReward 구체화 | 0 | **PARTIAL** | 시트 클래스 의존 |
| GuildRaidSeasonModule.cs | ClanRaidSeasonData 시즌 lookup | 0 | **PARTIAL** | 시트 클래스 의존 |

> PARTIAL 표기는 대부분 "코드 자체는 DIRECT인데 DataSheet 자동생성 클래스(ClanXxxData)·서버 ResponseType·CustomSO·enum 이 아직 이식 안 됨"에 걸림. 이들이 이식되면 즉시 컴파일됨. **순수 코드 변환 난이도는 낮음**, 의존 순서가 관건.

---

## 7. 외부 의존성 (본 영역 밖, 이식 선행/협업 필요)

| 의존 | 소속 | 비고 |
|------|------|------|
| ClanConstDataParser | Phase1 §20 (Core/Data) | Donation/Raid 가 DailyDonationLimit/GemCost/RaidSpendGem 참조. **선행 이식** |
| QuestConditionBinder | UI영역? (Guild 밖) | GuildQuestModule 핵심 의존. 외부 이벤트 12종 Bind. WD 동등 이벤트 매핑 |
| GuildShopCurrencyMapper | server/UI 영역 | Shop.cs costType/rewardCurrencyType→ECurrencyType |
| GuildErrorMessage | server 영역(§4) | KickWithFeedback 등에서 Resolve |
| GuildUtils | UI/Guild (Phase1 §3-d) | ErrorCodeGuildNotJoined/MessageGuildNotJoined |
| Guild (모델), GuildMember, GuildChatMessage, GuildRaidStatus 등 | Core/Models/Guild(§5) | 캐시 타입 |
| 모든 ServerResponse<GuildXxxResponse>, GuildDoc, *.ToModel() | server ResponseTypes(§4) | |
| ClanXxxDataData (14종) | DataSheet 자동생성(§16/17) | 모듈 시트 행 타입 |
| ClanGiftIconConfigSO | SOs/SO/Config(§19) | GiftCatalog |
| EGuild* enum (JoinType/MemberRank/DonateType/LevelEffect) | Enums(§6) + EGuildLevelEffect는 LevelTableModule 내부 정의 |
| EDailyQuestCondition 의 Clan* 값(ClanChat/ClanContribution/ClanShopPurchase) | DailyQuest enum | WD에 추가 필요 가능성 |
| BalanceTableNames.CLAN_* (14) | Core/Data | WD에 없음 → 추가 |

---

## 8. 주의사항 / 함정 (TOP 5)

1. **MessageBroker 동음이의 함정**: BD `MessageBroker`(Geuneda DI)를 WD의 UniRx `MessageBroker`(Plugins/UniRx)로 매핑하면 안 됨. WD 컨벤션은 **EventManager(static)**. 31종 메시지를 GameEventType+페이로드로 신규 등록하고, 제네릭/단순 테이블 일치(메모리 참고: Dispatch<T>/Subscribe<T> 일치)에 주의. PublishSafe→Dispatch.

2. **BaseService 부재**: BD `GuildManager : BaseService` → WD엔 BaseService 없음. `BaseManager`로 교체. InitializeAsync/IsInitialized/Cleanup override 시그니처는 동일하나 base 호출 확인. Managers.cs 에 GuildManager 1개만 등록(order는 RedDotManager 355 앞, ServerManager/ContentUnlock/Currency/DamageCalc 뒤).

3. **ITickService 부재**: GiftSeason(1s tick)·Quest(debounce tick) 가 `MainInstaller.Resolve<ITickService>().SubscribeOnUpdate`. WD엔 Geuneda ITickService 없음 → Doozy TickService 또는 매니저 Update/UniTask 루프로 재배선. 미배선 시 선물시즌 만료·퀘스트 flush 가 영구 정지(런타임 무증상 버그).

4. **DataSheet 의존 = PARTIAL 8개의 실체**: 모듈 코드는 거의 DIRECT지만 `ClanXxxData`(14 자동생성)·`CLAN_*` BalanceTableNames·CustomSO 가 선행돼야 컴파일. **이식 순서**: enum/모델/DataSheet/server ResponseType → ClanConstDataParser/QuestConditionBinder → 본 영역 모듈 → GuildManager 본체 → RedDot 배선. 역순이면 빌드 깨짐.

5. **레드닷 권위 이원화 보존**: RedDot.Guild 는 "메인레드닷 통합 flag(미로드 시 권위) vs detail 캐시(로드 후 권위)" 가드가 핵심. detail 미로드 시 leaf 를 false 로 강제하지 않는 로직(IsPendingJoinRequestCountLoaded/IsDailyDonationLoaded/Discount.CachedToday/Quest.IsStatusLoaded/CachedRaidQuestStatus null 체크)을 그대로 보존해야 false-positive/누락 안 생김. 동적 노드(MissionQuest/Progress) + 집계 노드(QuestAggregate/ProgressAggregate) 전환 로직 유지.

추가:
- `_pendingRaidClear` Preserve 레이스 가드(clear→enter 순서) 보존 — 깨면 도전횟수/누적피해 오갱신.
- Quest limbo(`_invalidatedDailyKey`) 로직 — 자정 drift 시 진행도 유실 방지. 단순화 금지.
- 채팅 폴링 `UniTaskVoid` + CancellationTokenSource: async void 아님(OK). Cleanup의 StopChatPolling 보존.
- `GuildGiftDetailPopup` 등 UI 직접 Show 는 UI영역 이식 후에야 컴파일(Chat.cs 한정 PARTIAL 성격).
