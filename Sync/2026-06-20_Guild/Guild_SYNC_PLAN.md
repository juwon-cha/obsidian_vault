# Guild 시스템 Sync 계획서 (BD → WD) — Phase 3 종합

- 작성일: 2026-06-20
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense @ bunker-defense/dev)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- SYSTEM: Guild
- 본 문서: 실행 인가 전 검토용 최종 계획. Phase 1/2 산출물(인벤토리 + core/server/ui1/ui2/raid/infra 6분석) 종합.
- 전략 노선: **Path A — geuneda 프레임워크 미이식, 길드 코드를 WD 컨벤션(Managers/EventManager/BaseManager)으로 전면 포팅** (메모리 룰 "sync 시 WD 구조 변경 금지" 준수).

---

## 섹션 0.2 ⚠️ 미결정 사항 (사용자 결정 필요 — 최우선)

실행 인가 전 아래 3건을 먼저 확정해야 함. 각 STEP 순서와 규모가 여기서 갈림.

### 결정 1. 레이드 스코프 (메타-only vs 메타+레이드)
- **메타-only (권장 1차)**: 가입/관리/레벨/상점/기부/버프/선물/할인/미션/채팅. 약 10영업일. 레이드 전투 의존(저수준 물리·전용 씬·보스 패턴) 전부 제외.
- **메타+레이드 (2차)**: 위 + 레이드 보스 전투. 추가 +1주. 저수준 물리 재작성·GameUI/GameResultUI 인라인·전용 씬/모드 분기까지.
- **권장: 단계 분리.** 1차 메타 출시 → 2차 레이드. 체크리스트도 STEP7까지 1차, [2차]로 레이드 분리.

### 결정 2. SceneManager 구조 (전용 씬 vs 단일 GameScene 모드 분기)
- BD: 전용 `GuildBossScene` + `LoadGuildRaidSceneAsync(stageId)` + `SceneNames.GUILD_RAID` + `IsGameplayScene` 헬퍼.
- WD: 단일 `GameScene` + `GameModeType` 분기(PunchKing/Vanguard 선례). 전용 씬 도입은 "WD 구조 변경 금지" 룰과 충돌.
- **권장: WD 방식(단일 GameScene + `GameModeType.GuildRaid` 분기) 채택.** 단 보스/스폰/HUD 프리팹이 GuildBossScene 배치에 강결합돼 있으면 분기 흡수 작업량이 큼 → 레이드 2차에서 처리. **사용자 OK 필요.**

### 결정 3. ECurrencyType 리맵 vs 서버 enum-int 통신
- `ClanCurrency`(BD 1128) / `ClanContribution`(BD 1129)이 WD `RandomChip0_108=1128` / `RandomChip0_109=1129`와 **정면 충돌**(검증됨, ECurrencyType.cs:592-593).
- 안전값 리맵 제안: `ClanCurrency=1302`, `ClanContribution=1303` (WD 끝값 1301 다음).
- ⚠️ **함정**: `GuildEnumParser.ResolveCurrencyType(int)`이 서버 currency_type 정수코드를 `(ECurrencyType)N`으로 직접 캐스팅. 서버가 enum **정수 ID**로 통신하면 리맵이 서버와 어긋남 → 보물상자(GuildGiftBox) 통화 매핑 깨짐.
- **권장: 리맵 채택 + `ResolveCurrencyType`를 명시 매핑 테이블(서버코드→WD enum)로 수정.** 단 **서버 담당과 "통화를 정수로 보내는지 이름으로 보내는지" 확인 후 확정.**

---

## 섹션 0. 전수조사 결과 (영역별 요약)

총 FROM 길드 관련 `.cs` **218개**. 이식 대상 산정:
- **이식 포트 대상 = 177개** (218 − Configs/Clan* 28 − 치트 13 − DataSheet 자동생성 14×2=28 [시트 재생성으로 대체]).
  - 단 DataSheet Class/SO 28개는 "코드 복사"가 아니라 **WD DataSheet 파이프라인(시트 차팅) 재생성**으로 산출 → 사실상 포트 코드 0, 데이터 작업.
- 순수 코드 변환 대상(모듈/매니저/서버/모델/enum/이벤트/UI/레이드) = **149개** + 동반 인프라(GuildUtils/GuildRedDotKeys/ClanConstDataParser 등).
- **치트 13(`#if DEV`)은 MVP 제외.** DataSheet Configs 28은 영구 제외(WD에 폴더 없음, DataSheet SO로 대체).

| 영역 | 파일수 | 주요 FROM 패턴 | sync유형 분포 | TO 처리 |
|------|-------|---------------|--------------|---------|
| GuildManager 본체+partial | 7 | ServiceAccessor 59, MessageBroker 13발행, `:BaseService`, ITickService | ADAPTED 6 / DIRECT 1 | `:BaseManager`, GetManager 치환, EventManager 배선, Tick→Update 재배선 |
| RedDotManager.Guild partial | 1 | ServiceAccessor 7, message 핸들러 17 | ADAPTED 1 | WD RedDotManager partial로 합류, 구독 배선 |
| Guild/ 모듈 | 18 | ServiceAccessor, MainInstaller(3), Geuneda(3) | DIRECT 6 / ADAPTED 5 / PARTIAL 7 | plain C# 유지, 내부 호출만 치환. PARTIAL=DataSheet 선행 |
| Server/Guild | 24 | BaseServerService(호환), SA 1 | DIRECT 23 / ADAPTED 1 | 라우트 57 그대로, ResolveCurrencyType만 손봄. **매니저 등록 안 함** |
| Models/Guild | 13(14클래스) | Geuneda 무의존, ToModel 자체포함 | DIRECT 13 | 무변환 |
| Enums EGuild* | 7 | 의존 0 | DIRECT 7 | 신규 추가 |
| Events/Guild | 3(30메시지) | `:IMessage`(Geuneda) | ADAPTED 3 | IMessage 제거, GameEventType 30 신규 + EventManager 재배선 |
| UI/Guild 비-Chat/비-Raid | 45 | ServiceAccessor 198, MessageBroker 38, MainInstaller(2) | DIRECT 12 / ADAPTED 31 / PARTIAL 2 | UI 골격 DIRECT, DI/이벤트 치환 |
| UI/Guild Chat | 9 | SA, MB 5종, InvalidateRowHeightCache | ADAPTED 8 / PARTIAL 1(GiftSlot) | LoopGridView 백포팅 동반 |
| UI/Guild Raid | 10 | SA 67(영역합), SceneManager.LoadGuildRaid, Nobi | ADAPTED 4 / PARTIAL 6 | 레이드 런타임 의존 → 2차 |
| 레이드 컨트롤러 | 6 | SA, MB, LowLevelPhysics2D | DIRECT 2 / ADAPTED 3 / PARTIAL 1 | PatternController는 Collider2D 재작성 |
| 레이드 게임모드 서비스 | 4(+1 POCO) | IGameModeConfigurator/BaseStagePlay(존재), BaseGameModeUI/StandardGameResult(부재) | ADAPTED 2 / 인라인 2 | Configurator/StagePlay 직접 이식, UI/Result는 GameUI/GameResultUI 인라인 |
| 레이드 SO 스크립트 | 2 | 순수 SO | DIRECT 2 | 무변환 |
| 치트 | 13 | `#if DEV` | (제외) | MVP 제외 |
| DataSheet Class/SO | 14×2=28 | 자동생성 컨벤션 | (시트 재생성) | WD DataSheet 파이프라인으로 생성 |
| SOs/Configs/Clan* | 28 | geuneda gamedata Config | (영구 제외) | DataSheet SO로 대체 |

**전체 sync유형 분포 (포트 코드 149 기준 근사):** DIRECT ~42 / ADAPTED ~58 / PARTIAL ~17 / 인라인재작성 ~3 / 제외 26(치트13+Configs는 별도).

### 변환 부담 합계 (실측, Phase 2 영역별 합산)
- **ServiceAccessor.Get<T>() 총 ~337건**: core 59 + ui1 198 + ui2 67 + server 1 + raid 12(컨트롤러 12 추정) ≈ 337. (문서의 582는 과대, 워크트리 버전차)
- **MainInstaller.Resolve**: ~11파일 (GiftSeason/Quest/Discount 모듈 + ui1 2 + ui2 + 게임모드 서비스).
- **MessageBroker 사용**: ~32파일.
- **using Geuneda**: FROM 29파일 (Services 15 + DataExtensions 14) → 전부 제거.

### TO에 추가할 enum/매니저 (명시 — 섹션 4에 before/after)
- `Managers.cs`: GuildManager 1줄 (5-arg ctor). GuildServerService/GuildRaidManager **등록 안 함**.
- `ECurrencyType`: ClanGiftEpic=820, ClanGiftLegendary=821, ClanGiftMythic=822, ClanCurrency=1302(리맵), ClanContribution=1303(리맵).
- `EContentType`: UI_Guild, Dungeon_GuildRaid (둘 다 Lv.25).
- `GameModeType`: GuildRaid.
- `EBottomTabType`: Guild (Dungeon과 ComingSoon 사이).
- `GameEventTypes.cs`: 길드 이벤트 **30종** + 레이드 인게임 3종(GuildRaidDamageUpdated / GuildRaidBossPatternStarted / GuildRaidInitialCardSelectionComplete) = 최대 33 신규 enum.
- EGuild* enum 7종 (신규 파일).
- BalanceTableNames: CLAN_* 상수 14종.

### TO 기존 파일 수정 (섹션 4 상세)
BottomTabHUD.cs / ContentUnlockManager.cs / LobbyMainUI.cs / SceneManager.cs(레이드, 2차) / GameResultData(레이드, 2차).

---

## 섹션 0.1 PARTIAL 파일/영역 의존성

PARTIAL의 실체는 대부분 "코드는 DIRECT인데 선행 의존이 미이식"임. 이식 순서가 관건.

- **모듈 PARTIAL 7개(LevelTable/Flag/ShopGroup/GiftCatalog/GiftSeason/RaidMemberReward/RaidPersonalReward/RaidSeason)**: DataSheet 자동생성 `Clan*DataData`/`Clan*SO` 선행 필요. 시트 재생성 후 즉시 컴파일.
- **UI PARTIAL 2개(GuildContributionPanel/GuildQuestPanel)**: `MainInstaller.Resolve<IMessageBrokerService>` 인스턴스 DI → EventManager 정적 경로 재배선 + Geuneda using 제거.
- **Chat PARTIAL(GuildChatGiftSlot)**: 선물 도메인(GuildGiftBox 모델 + ClanGiftIconConfigSO) 선행.
- **Raid UI PARTIAL 6개(RaidLobby/RaidRanking/RaidQuest 팝업·패널)**: 레이드 런타임(StagePlayService·전용 씬·GuildManager.Raid·DamageCalc 길드버프) 미이식 시 컴파일 불가 → **레이드 2차 묶음**. UI만 단독 이식 불가.
- **레이드 컨트롤러 PARTIAL(GuildRaidPatternController)**: 저수준 물리(LowLevelPhysics2D) 레이어 부재 → Collider2D 재작성.
- **게임모드 인라인 2개(GameModeUI/GameResult)**: 베이스 부재 → GameUI/GameResultUI 인라인 분기.

> **핵심 의존 사슬**: enum/모델/DataSheet/server → ClanConstDataParser/GuildUtils/GuildRedDotKeys → 모듈 → GuildManager 본체 → RedDot 배선 → UI 메타 → 채팅 → 진입점. [2차] 레이드 런타임 → 레이드 UI. 역순이면 빌드 깨짐.

---

## 섹션 1. TO 현재 상태

### 1-a. 존재 인프라 (재사용, 검증 완료 33종 OK)
UIManager, UIBase, Managers, EventManager(static), GameEventTypes, CurrencyManager, ECurrencyType, SaveDataManager, SaveDataTypes, LocalizationManager, ResourceManager, ServerTimeManager, BaseServerService, RedDotManager(+Core/RedDot, UI/RedDot/RedDotComponent), SceneManager, GameModeType, IBossController, BaseBossController, ContentUnlockManager, ContentTypes, EBottomTabType, BottomTabHUD, ObjectPoolManager, PooledObject, CardSelectionUI, CardManager, GameResultUI, GameUI, DamageCalculationManager, StageManager, EnemyManager, LoopGridView/LoopGridViewItem, DetectionManager(RegisterEnemy/UnregisterEnemy).
- 게임모드 패턴: **IGameModeConfigurator / BaseStagePlayService 존재** (참조 문서가 "없다"고 한 것은 오류). RankingDisplaySlot / BaseTopRankSlot / ItemDisplayComponent / TopCurrencyBoxComponent / RewardClaimPopupUI / ServerLoadingPopupUI / RankingUserDetailPopup / DescriptionPopup 존재.
- 참조 모델: PunchKingDungeonManager(338) / PunchKingBossController / Vanguard 패턴.

### 1-b. 신규 필요 (TO에 전무)
- 길드 .cs 0개(전무). 길드 코드 전체 신규 이식.
- enum/매니저/이벤트 추가분(섹션 0 목록).
- 동반 인프라: GuildUtils, GuildRedDotKeys, ClanConstDataParser, ClanDiscountDataParser, BalanceTableNames.CLAN_*.
- **LoopGridView.InvalidateRowHeightCache()** 백포팅 (채팅, 4회 호출).
- **Nobi.UiRoundedCorners** 패키지 (GuildRaidQuestSlot, 2차).
- 레이드: GameResultData.FromGuildRaid 팩토리 + GuildRaidTotalDamage 필드, GuildRaidPatternController Collider2D 재작성.

---

## 섹션 2. 변환 규칙 상세

### 2-a. ServiceAccessor / MainInstaller → Managers.Instance.GetManager<T>()
```csharp
// Before
var ui = ServiceAccessor.Get<UIManager>();
var guild = MainInstaller.Resolve<GuildManager>();
// After
var ui = Managers.Instance.GetManager<UIManager>();
var guild = Managers.Instance.GetManager<GuildManager>();
```
- 매니저 클래스 내부에서는 상속 `GetManager<T>()`도 가능. plain 모듈은 `Managers.Instance.GetManager<T>()` 명시.
- 약 337건 기계적 치환.

### 2-b. MessageBroker(IMessage) → EventManager(static)
```csharp
// Before
_messageBroker.Subscribe<GuildLeftMessage>(OnGuildLeft);
MessageBroker.PublishSafe(new GuildLeftMessage { GuildIdx = id, Kicked = kicked });
_messageBroker.Unsubscribe<GuildLeftMessage>(this);   // owner 기반
// After
EventManager.Subscribe<GuildLeftMessage>(GameEventType.GuildLeft, OnGuildLeft);
EventManager.Dispatch<GuildLeftMessage>(GameEventType.GuildLeft, new GuildLeftMessage { GuildIdx = id, Kicked = kicked });
EventManager.Unsubscribe<GuildLeftMessage>(GameEventType.GuildLeft, OnGuildLeft);  // 핸들러 기반
```
- 페이로드 클래스(`Guild*Message`)는 **그대로 재사용, `: IMessage`만 제거**.
- ⚠️ `Unsubscribe<T>(this)` owner기반 → WD는 **핸들러기반** `Unsubscribe<T>(GameEventType, handler)`. 단순 치환 불가, 구독 해제부를 핸들러 명시로 재작성. Cleanup/Closed 누락 시 누수.
- ⚠️ 제네릭 `Dispatch<T>/Subscribe<T>` 테이블과 단순 Action 테이블은 별개(메모리 `eventmanager_generic_vs_simple`). 30종 전부 페이로드 보유 → 제네릭 계열로 일관.
- `DailyResetMessage` → WD `TimeEventData` / `GameEventType.DailyReset`로 매핑. `CurrencyChangedEventData`는 WD 기존 이벤트 사용(신규 X).

### 2-c. GuildManager : BaseService → : BaseManager
- WD에 BaseService 없음. `BaseManager`로 교체. `InitializeAsync`/`IsInitialized`/`Cleanup` 시그니처 동일, base 호출만 확인.
- ContentUnlockEventData 등 `: BaseEventData, Geuneda.Services.IMessage` → `: BaseEventData`만 남김.

### 2-d. using Geuneda.* 제거
- `using Geuneda.Services;` / `using Geuneda.DataExtensions;` 전 파일 제거(29파일).

### 2-e. ITickService → WD Tick/Update 재배선 (ADAPTED)
- GiftSeason(1s tick)·Quest(debounce tick)가 `MainInstaller.Resolve<ITickService>().SubscribeOnUpdate`. WD엔 Geuneda ITickService 없음.
- → 매니저 Update 루프 또는 Doozy TickService로 재배선. **미배선 시 선물시즌 만료·퀘스트 flush가 영구 정지(무증상 버그).**

### 2-f. 저수준 물리 → Collider2D 재작성 (레이드, 2차)
- `GuildRaidPatternController`의 LowLevelPhysics2D(PhysicsBody/PhysicsShape/PhysicsWorld) → WD `CircleCollider2D`(trigger) + `BaseEnemyController` 피격 경로로 재작성. DetectionManager 등록은 유지.

---

## 섹션 3. TO 호출대상 존재 확인

### 호환 인프라 (DIRECT 가능)
BaseServerService.RequestApiAsync<T>(skipQueueWait 명명인자 포함) 일치 / ServerResponse<T> 계약 일치 / JsonHelper / AudioUtils / BalanceDataManager.LoadBalanceData / RewardClaimPopupUI / ServerLoadingPopupUI / ToastManager / LocalizationManager / RedDotComponent(NodeID) / TopCurrencyBoxComponent / RankingDisplaySlot / BaseTopRankSlot / ItemDisplayComponent / IGameModeConfigurator / BaseStagePlayService / BaseBossController(InitializeBossAsync 등 시그니처 일치).

### ⚠️ 누락 (동반 이식/백포팅/재작성 필요)
| 항목 | 상태 | 처리 |
|------|------|------|
| **LowLevelPhysics2D 레이어** | TO 전무 | GuildRaidPatternController를 Collider2D로 재작성(권장). 물리레이어 통째 이식 금지(WD 표준 충돌계 이중화) |
| **LoopGridView.InvalidateRowHeightCache()** | WD에 없음(BD에만) | WD LoopGridView.cs에 메서드 1개 백포팅: `public void InvalidateRowHeightCache() { mRowHeightOverrides.Clear(); }` (기존동작 불변, 안전) |
| **Nobi.UiRoundedCorners** | WD .cs/패키지 부재 | 패키지 추가 또는 GuildRaidQuestSlot 라운드코너 의존 제거(2차) |
| **BaseGameModeUIService** | TO 없음 | GameUI.cs 인라인 분기(`_isGuildRaidMode`, 누적피해 HUD). PunchKing 데미지 HUD 선례 |
| **StandardGameResultService** | TO 없음 | GameResultUI.cs 인라인 분기. RaceTower 인라인 region 선례 |
| **GameResultData.FromGuildRaid / GuildRaidTotalDamage** | TO엔 FromPunchKingResult만 | 팩토리+필드 추가 |

### Phase4 grep 검증 항목 (레이드)
BaseBossController의 `AccumulatedDamage` / `GetDamageTextOrigin` / minionId TakeDamage 오버로드 / `EEnemyType.RaidBoss` 불사로직 / `BaseSystemManager.DamageBase(ignoreReflectShield, maxHealthReduction)` 정합. CardManager의 GetCardChoicesArray/SetPreserveInitialSelection/ApplyPreBattleCardEffects/ClearInGameCardData. GameStatisticsManager/CameraShakeManager/EffectManager 존재.

---

## 섹션 4. TO 수정 필요 기존 파일 (before/after)

### 4-1. Managers.cs (★ ctor 5-arg 검증 완료 — 6-arg 없음)
ManagerDefinition은 `(Type, int priority, string category, bool autoInitialize=true, bool essential=true)` **5-arg만 존재** (Managers.cs:34). 인프라 분석의 6-arg `, false)` 형태는 **오류**. isMonoBehaviour/SceneRequired 파라미터 없음.
```csharp
// 추가 (priority 330 "Lobby" 군, DailyQuest/GuideQuest 인근. RedDotManager 355 앞)
new ManagerDefinition(typeof(GuildManager), 330, "Lobby", true, true), // 길드 시스템 매니저
```
- GuildServerService / GuildRaidManager: **추가 안 함**.

### 4-2. ECurrencyType.cs
```csharp
// 끝부분(1301 VanguardChipSelectBoxTranscend 다음)에 추가
ClanGiftEpic = 820,        // 무료 선물 통화(에픽)
ClanGiftLegendary = 821,   // 무료 선물 통화(레전더리)
ClanGiftMythic = 822,      // 무료 선물 통화(미식)
ClanCurrency = 1302,       // 길드 재화 (BD 1128 → RandomChip0_108 충돌 회피 리맵)
ClanContribution = 1303,   // 공헌도 (BD 1129 → RandomChip0_109 충돌 회피 리맵)
```
⚠️ `GuildEnumParser.ResolveCurrencyType` 명시 매핑 수정 동반(결정 3).

### 4-3. ContentTypes.cs (EContentType)
```csharp
// Feature_Relic 다음에 추가 (500번대 격리)
UI_Guild = 500,           // 길드 UI (Lv.25)
Dungeon_GuildRaid = 501,  // 길드 레이드 던전 (Lv.25)
```

### 4-4. GameModeType.cs
```csharp
// Vanguard 다음에 추가
GuildRaid, // 길드 레이드 모드 - 무적 보스 누적 피해량 경쟁
```

### 4-5. EBottomTabType.cs
```csharp
public enum EBottomTabType { Shop, HeroUpgrade, Lobby, UnitUpgrade, Dungeon, Guild, ComingSoon }
```
- FROM의 `Headquarter`는 WD 미존재 → 제외, `Guild`만 추가.

### 4-6. GameEventTypes.cs (★ 인프라 "0개"는 오류 정정)
인프라 분석의 "추가 0개"는 **FROM에 GameEventTypes.cs가 없다**는 뜻일 뿐, **TO는 EventManager 경로로 이벤트를 나르므로 구독자 있는 이벤트마다 enum 1개씩 필요**. 메시지 클래스는 페이로드로 재사용하되 enum 식별자는 신규.
```csharp
// 파일 끝(ContentsContinueClaimChanged 다음)에 추가 — 길드 이벤트 30 + 레이드 인게임 3
// GuildEvents (21)
GuildJoined, GuildLeft, GuildUpdated, GuildMemberJoined, GuildMemberLeft, GuildLeaderChanged,
GuildLevelUp, GuildCurrencyChanged, GuildJoinRequestSent, GuildJoinRequestCanceled, GuildJoinTypeChanged,
GuildChatReceived, GuildDmReceived, GuildBuffChanged, GuildDailyDonationChanged, GuildPersonnelOfficeClosed,
GuildPendingJoinRequestCountChanged, GuildDiscountTodayChanged, GuildMainRedDotChanged,
GuildGiftSeasonExpired, GuildGiftClaimStateChanged,
// GuildRaidEvents (4)
GuildRaidStatusUpdated, GuildRaidStrengthened, GuildRaidRankingRefreshed, GuildRaidQuestProgress,
// ClanQuestEvents (5)
ClanQuestProgressChanged, ClanQuestClaimed, ClanQuestExpChanged, ClanQuestProgressTierClaimed, ClanQuestStatusRefreshed,
// 레이드 인게임 (3, [2차])
GuildRaidDamageUpdated, GuildRaidBossPatternStarted, GuildRaidInitialCardSelectionComplete,
```
- `DailyResetMessage`/`CurrencyChangedEventData`는 WD 기존 enum 재사용 → 신규 추가 안 함.

### 4-7. BottomTabHUD.cs
```csharp
// 배열 5→6
private BottomTabButton[] _tabButtons = new BottomTabButton[6];
// SetSelectedTab switch
case EBottomTabType.Guild: OpenGuildTab(); break;
// 신규 메서드
private void OpenGuildTab() => GuildEntryRouter.EnterAsync().Forget();
// 탭 락 (미해금 시 버튼 비활성)
if (tab.tabType == EBottomTabType.Guild) {
    bool unlocked = IsTabUnlocked(EBottomTabType.Guild);
    tab.button.gameObject.SetActive(unlocked);
    if (!unlocked) return;
}
// 레드닷 매핑: EBottomTabType.Guild => GuildRedDotKeys.Root
// 락 토스트: EBottomTabType.Guild => "guild_require_level_25"
```
- FROM Headquarter 결선은 이식 제외.

### 4-8. ContentUnlockManager.cs
```csharp
// GetTabContentType switch
case EBottomTabType.Guild: return EContentType.UI_Guild;
// _unlockConditions 배열
new ContentUnlockCondition(EContentType.UI_Guild, 25),
new ContentUnlockCondition(EContentType.Dungeon_GuildRaid, 25),
```

### 4-9. LobbyMainUI.cs
- 길드 진입 라우터(`GuildEntryRouter.EnterAsync()` — 가입중→GuildMainUI, 미가입→검색/가입 UI) 배선.
- `GuildJoined`/`GuildLeft`/`GuildMainRedDotChanged` 구독(EventManager) + 레드닷 갱신. Cleanup 해지.

### 4-10. SceneManager.cs ([2차], 결정 2 의존)
- 권장(WD 단일씬): `GameModeType.GuildRaid` 분기를 `LoadGameSceneAsync`에 추가, 씬은 GameScene 공유.
- 대안(BD 전용씬): `SceneNames.GUILD_RAID="GuildBossScene"` + `LoadGuildRaidSceneAsync` + `LastPlayedGuildRaidStageID` + 게임오버/로비복귀 분기. **구조 변경 룰 충돌 → 사용자 OK 필요.**

### 4-11. GameResultData ([2차])
```csharp
public int GuildRaidTotalDamage;  // 필드 추가
public static GameResultData FromGuildRaid(...) { ... }  // 팩토리 추가 (FromPunchKingResult 미러)
```

---

## 섹션 5. sync 체크리스트 (STEP별, 각 STEP 단독 컴파일 그린)

> 메모리 룰 "커밋마다 그린" 준수. 각 STEP 끝에서 `recompile_scripts` 그린 확인 후 커밋.

### [1차 메타]
**STEP1 — enum/토대** (커밋: "feat: 길드 enum 토대 추가")
- ECurrencyType(5, 리맵) / EContentType(2) / GameModeType(1) / EBottomTabType(Guild) / GameEventTypes(30, 레이드3 제외 가능) / EGuild* 7 / BalanceTableNames.CLAN_*(14).
- 그린 기준: enum만 추가라 단독 컴파일 그린.

**STEP2 — 모델/서버/이벤트** (커밋: "feat: 길드 모델+서버서비스+이벤트 배선")
- Models/Guild 13 / Events/Guild 3(IMessage 제거) / Server/Guild 24(SA 1건 치환, ResolveCurrencyType 명시매핑) / GuildEnumParser / GuildErrorMessage / 동반 GuildUtils·GuildRedDotKeys·ClanConstDataParser·ClanDiscountDataParser.
- GuildServerService는 Managers 등록 안 함. 그린 기준: GuildManager 없이도 서버레이어/모델/이벤트 단독 컴파일.

**STEP3 — 모듈 + GuildManager** (커밋: "feat: 길드 매니저+모듈 이식")
- DataSheet 14×2 시트 재생성(STEP7 선행분 일부) 또는 임시 스텁 → Guild/ 모듈 18 → GuildManager 본체+partial 7(`:BaseManager`, GetManager/EventManager 치환, ITick→Update) → Managers.cs 등록 1줄 → RedDotManager.Guild partial 배선.
- 그린 기준: GuildManager + 모듈 컴파일, 매니저 초기화.

**STEP4 — UI 메타** (커밋: "feat: 길드 메타 UI 이식")
- UI/Guild 비-Chat/비-Raid 45 (DI/이벤트 치환, ContributionPanel/QuestPanel PARTIAL 재배선). 프리팹은 Phase5.
- 그린 기준: 메타 UI 컴파일.

**STEP5 — 채팅** (커밋: "feat: 길드 채팅 + LoopGridView 백포팅")
- LoopGridView.InvalidateRowHeightCache() 백포팅 → Chat 9 (슬롯6+베이스+패널+LobbyChatUI).
- 그린 기준: 채팅 컴파일, 가변높이 동작.

**STEP6 — 진입점/레드닷** (커밋: "feat: 길드 진입점+레드닷 배선")
- BottomTabHUD(배열6/case/락/레드닷) / ContentUnlockManager(2조건) / LobbyMainUI(라우터+구독).
- 그린 기준: 바텀탭 길드 진입 + 레드닷.

**STEP7 — 데이터시트** (커밋: "data: 길드 DataSheet 14종 차팅")
- Absurd Defense 시트에 Clan* 14 추가 → GoogleDriveSync로 SO/Class 재생성. 커스텀 파싱은 Parser 유지(자동생성 직접수정 금지).

### [2차 레이드] (결정 1·2 확정 후)
**STEP8 — 레이드 토대**: GameEventTypes 레이드3 / GameModeType.GuildRaid 분기 / GameResultData.FromGuildRaid+필드 / SceneManager(결정2) / SO 스크립트 2.
**STEP9 — 레이드 전투**: 보스 컨트롤러 6(GuildRaidPatternController Collider2D 재작성) / GuildRaidModeConfigurator+GuildRaidStagePlayService 직접이식 / GameUI·GameResultUI 인라인 / Nobi 패키지.
**STEP10 — 레이드 UI**: UI/Guild Raid 10.
**STEP11(선택) — 치트**: `#if DEV` 13.

---

## 섹션 6. 주의사항

1. **ITickService 부재**: GiftSeason/Quest tick을 Update/Doozy Tick으로 재배선. 미배선 시 선물시즌 만료·퀘스트 flush 영구정지(무증상). STEP3 필수.
2. **Unsubscribe 핸들러기반 누수**: owner기반 `Unsubscribe<T>(this)` → 핸들러기반 재작성. Cleanup/Closed에서 30종 전부 명시 해지. 누락 시 누수.
3. **DataSheet 선행**: 모듈 PARTIAL 7개는 Clan*DataData/SO 없으면 컴파일 불가. STEP7(또는 임시 스텁) 선행. 자동생성물 직접수정 금지, Parser 별도.
4. **레드닷 권위 이원화 보존**: "메인레드닷 통합flag(미로드시 권위) vs detail캐시(로드후 권위)" 가드 유지. detail 미로드 시 leaf를 false 강제하지 않는 null체크(PendingJoinRequest/DailyDonation/Discount.CachedToday/Quest.IsStatusLoaded/CachedRaidQuestStatus) 보존. 동적노드(MissionQuest/Progress)+집계노드 전환 유지.
5. **ECurrencyType 충돌**: 1128/1129 리맵(1302/1303). ResolveCurrencyType `(ECurrencyType)N` 캐스팅이 서버 정수코드와 어긋날 수 있음 → 명시매핑 + 서버 확인(결정 3).
6. **RunDedupedAsync 보존**: EGuildApiKey 10키 + UniTaskCompletionSource 디둡 그대로(UniTask.Preserve multi-subscriber 회피). Cleanup에서 모든 waiter TrySetException 보존.
7. **추가**: `_pendingRaidClear` Preserve 레이스가드 / Quest limbo(`_invalidatedDailyKey`) 자정drift / 채팅 폴링 UniTaskVoid+CTS(async void 아님) StopChatPolling 보존. MessageBroker 동음이의(UniRx와 다름, EventManager로) 주의.

---

## 섹션 7. 프리팹/씬/에셋 인벤토리 (Phase 5a 대비)

| 카테고리 | 개수 | 경로 |
|----------|------|------|
| UI 프리팹 | 31 | `3_Prefabs/UI/Guild/`(Guild8/Chat7/Hall4/Raid4/Gift3/Discount2/Mission2/Common1) |
| 레이드 보스 프리팹 | 3 | `3_Prefabs/Boss/`(guild_monster_bull, Anim/Guild_Boss_50101_Back_Anim) + `UI/Character/guild_monster_bull_UI` |
| Resources 내 guild 프리팹 | 21 | `Assets/Resources/UI/` 산재 (Resources/UI/Guild 디렉터리 없음) |
| **프리팹 합계** | **52** | (guild/clan/stella) |
| 씬 | 1 | `0_Scenes/GuildBossScene.unity` (전용 레이드 씬, 결정 2 따라 사용/흡수) |
| 텍스처 | 159 | `6_Textures/Guild/`(전용) + Enemy/GuildRaid 3 + InGameBackground/GuildBoss 7 |
| 애니메이션 | 10 | UI 6 + Enemy/Boss 4 (문서 "17"은 과대) |
| SO(.asset) | 18 | `11_SO/Guild/` 2 + 폰트 SpriteAssets 2 + BalanceConfigs clan/guild 14 |
| 데이터시트 | 14 | Clan* 14종(시트 차팅 재생성) |

- **전수 복사 원칙**: `.meta` 포함 복사로 길드 내부 GUID 참조 보존.
- **GUID 참조복구 전략**: 길드 프리팹이 WD 공용 에셋(폰트/공용UI/통화아이콘)을 BD GUID로 참조 → 끊김. 끊긴 공용 참조는 일괄 스크립트 + 수동 재연결(Phase 5b). 내부 참조는 meta 복사로 자동 보존.
- `icon_lobby_guild.png`가 `Resources_moved/`(비활성)에 있음 → 사용 시 `Resources/`로 이동.
- Addressables 등록(BalanceConfigs 등)은 직접 편집 금지, Unity Importer 위임(메모리 룰).

---

## 섹션 8. 권장 출시 단위 + 예상 규모

### 출시 단위
1. **1차 (약 10영업일): 길드 메타** — 가입/관리/레벨/상점/기부/버프/선물/할인/미션/채팅. STEP1~7.
2. **2차 (+약 1주): 길드 레이드** — 보스전투/전용씬or모드분기/랭킹/미션. STEP8~10.
3. **선택: 치트** — `#if DEV`, 본빌드 무영향.

### 예상 규모
- 포트 코드 ~149파일 / ServiceAccessor ~337건 / MessageBroker ~32파일 / Geuneda using 29파일 제거.
- enum 추가 ~33 GameEventType + ECurrencyType 5 + 기타 enum. 매니저 등록 1.
- 프리팹 52 / 씬 1 / 텍스처 159 / 애니 10 / SO 18 / 데이터시트 14.
- 가속 가능(~70%, 기계적 변환). 병목: 프리팹 GUID 복구 / 레이드 씬·보스패턴 / 런타임 디버깅.

### 가장 큰 리스크 TOP 3
1. **프리팹 GUID 참조 복구** — WD 공용 에셋 참조 끊김. 1차 최대 병목(Phase 5b 집중).
2. **레이드 저수준 물리 부재** — GuildRaidPatternController Collider2D 재작성 필요(2차). 물리레이어 통째 이식은 WD 충돌계 이중화 위험.
3. **ECurrencyType 리맵 vs 서버 enum-int** — 서버가 정수ID로 통화 통신 시 보물상자 매핑 깨짐. 서버 확인 + 명시매핑 필수.
