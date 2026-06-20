# Guild 시스템 Phase 1 인벤토리 (FROM 전수조사)

- 작성일: 2026-06-20
- FROM (소스): `/tmp/sync_Guild_1781924940` (BunkerDefense @ bunker-defense/dev 워크트리)
- TO (대상): `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- SYSTEM: Guild
- 참조 문서: `/Users/juwon.cha.teamsparta/Downloads/Guild_Migration_BD_to_WD.md`
- 본 단계: READ-ONLY. 복사/수정 없음.

## grep 패턴 (Phase 2 재사용)

```
# 파일명 기반 탐색
find Assets -name "*.cs" \( -iname "*Guild*" -o -iname "*Clan*" \)

# 내용 기반
grep -rl 'Guild\|Clan' --include="*.cs"

# 변환 대상 패턴
ServiceAccessor    (DI 접근 → Managers.Instance.GetManager<T>())
MainInstaller      (DI resolve → GetManager)
MessageBroker      (이벤트 → EventManager static)
using Geuneda.Services       (DI 프레임워크 패키지)
using Geuneda.DataExtensions (gamedata 프레임워크 패키지)
```

---

## 1. FROM 발견 .cs 파일 — 카테고리별 (총 218개)

루트: `Assets/_Project/1_Scripts/`

| # | 카테고리 | 경로 | 개수 |
|---|----------|------|------|
| 1 | GuildManager + partial | `Core/Managers/GuildManager*.cs` (.cs/.Chat/.Donation/.GiftSeason/.Raid/.Rental/.Shop) | 7 |
| 2 | RedDot partial | `Core/Managers/RedDotManager.Guild.cs` | 1 |
| 3 | 모듈/지원 | `Core/Managers/Guild/` (모듈13 + 베이스2 + 지원3) | 18 |
| 4 | 서버 서비스 | `Core/Managers/Server/Guild/` (ServerService 12 + ResponseTypes 11 + EnumParser + ErrorMessage) | 24 |
| 5 | 모델 | `Core/Models/Guild/` | 13 |
| 6 | Enum | `Core/Enums/EGuild*.cs` | 7 |
| 7 | 이벤트 | `Core/Events/Guild/` (GuildEvents/GuildRaidEvents/ClanQuestEvents) | 3 |
| 8 | UI | `UI/Guild/` (전체 하위 포함) | 62 |
| 9 | 치트 (#if DEV) | `Core/Managers/Cheat/Guild/` (+ /Editor/) | 13 |
| 10 | 레이드 컨트롤러 | `Core/Controllers/Enemy/GuildRaid/` | 5 |
| 11 | 레이드 게임모드 | `Core/GameModes/GuildRaid*` (Configurator + InitialSelectionData) | 2 |
| 12 | 레이드 StagePlay | `Core/Managers/StageServices/GuildRaidStagePlayService.cs` | 1 |
| 13 | 레이드 GameModeUI | `UI/GameModeUI/GuildRaidGameModeUIService.cs` | 1 |
| 14 | 레이드 GameResult | `UI/GameResult/GuildRaidGameResultService.cs` | 1 |
| 15 | 레이드 SO 스크립트 | `SOs/Guild/` (BossUIPrefabRegistrySO, RaidEntranceConfigSO) | 2 |
| 16 | DataSheet SO (자동생성) | `SOs/SO/DataSheet/Clan*SO.cs` | 14 |
| 17 | DataSheet Class (자동생성) | `SOs/Class/DataSheet/Clan*Data.cs` | 14 |
| 18 | **SOs/Configs/Clan* (BD 전용, 제외 권장)** | `SOs/Configs/Clan*Config.cs + ConfigAsset.cs` | 28 |
| 19 | Gift 아이콘 Config SO | `SOs/SO/Config/ClanGiftIconConfigSO.cs` | 1 |
| 20 | Const 파서 | `Core/Data/ClanConstDataParser.cs` | 1 |
| | **합계** | | **218** |

### 문서(190) 대비
- 문서 190 (Guild* 158 + Clan* 32). **실측 218.**
- 차이 +28의 본체 = `SOs/Configs/Clan*` 28개 (BD의 geuneda gamedata DI Config 패턴, 아래 §3 참고). 문서 인벤토리에 미포함.
- 순수 이식 대상(Configs 28 제외, 치트 13 선택) = **190** (정확히 문서값과 일치).
- 즉 문서의 "190"은 **Configs 28 제외 + 치트 13 포함** 기준. Configs 28을 더하면 218.

---

## 2. 변환 부담 실측 (문서 수치와 불일치)

| 패턴 | 문서 주장 | **실측** | 비고 |
|------|-----------|----------|------|
| ServiceAccessor | 582건 / 77파일 | **413건 / 73파일** | 워크트리 버전이 문서 작성 시점보다 다름 |
| MainInstaller | (582에 합산) | **11파일** | |
| MessageBroker | 14파일 | **32파일** | 문서가 과소. 31종 이벤트 재배선 필요 |
| using Geuneda | **0건(WD 기준 오해)** | FROM에 **29파일** (Services 15 + DataExtensions 14) | 문서의 "0건"은 WD 검색결과. FROM(소스)엔 29파일 |
| Spawn/Despawn 풀링 | 0건 | **0건** (.Spawn 0, Despawn 1) | 일치. 풀링 변환 불필요 |
| 총 라인 | ~27,000 | **27,917** | 일치 수준 |

> 핵심: FROM 코드 자체는 Geuneda DI 패턴이라 `using Geuneda.Services` 15 + `using Geuneda.DataExtensions` 14파일을 제거/대체해야 함. 문서가 "0건"이라 한 건 WD(대상) 기준이며, 변환 대상인 FROM에는 명백히 존재.

---

## 3. 숨은 인프라 의존성

### 3-a. Geuneda.* 네임스페이스 = git 패키지 (소스 아님)
`Packages/manifest.json`에 등록된 외부 패키지:
- `com.geuneda.services` → `Geuneda.Services` (ServiceAccessor/MainInstaller)
- `com.geuneda.gamedata` → `Geuneda.DataExtensions`
- 기타: inputextensions, nativeui, uiservice, unity-cli-connector

→ **이식 불가/불필요**. WD는 이 DI 프레임워크를 안 씀. 해당 `using` 제거 + 호출 치환이 변환의 본체.

### 3-b. SOs/Configs/Clan* (28파일) — BD 전용 gamedata 패턴
- `Clan*Config.cs` (struct, 서버 JSON DTO 1:1) + `Clan*ConfigAsset.cs` 14쌍 = 28.
- `Geuneda.DataExtensions` 의존.
- **TO에 `SOs/Configs/` 폴더 자체가 없음.** WD는 `SOs/SO/DataSheet/` + `SOs/Class/DataSheet/` 패턴(시트 자동생성)을 사용.
- 분류: **이식 제외 권장** (WD DataSheet 패턴으로 대체). Phase2에서 모듈이 Config를 읽는 부분을 DataSheet SO 읽기로 변환.

### 3-c. ToModel() — 자체 포함 (의존성 아님)
- `GuildResponseTypes.*`의 서버 Doc → POCO 변환은 **인스턴스 메서드 `ToModel()`** (외부 확장 메서드 아님). 추가 의존성 없음. 그대로 이식 가능.

### 3-d. 헬퍼 의존성 — TO 존재 검증
| 헬퍼 | TO 상태 |
|------|---------|
| AudioUtils | TO에 있음 (`Core/Managers/AudioUtils.cs`) |
| JsonHelper | TO에 있음 (`Utils/JsonHelper.cs`) |
| GuildUtils | TO에 없음 → 길드 코드 자체 동반 이식(`UI/Guild/GuildUtils.cs`, 116회 참조) |
| **LowLevelPhysicsHelper** | **TO에 없음 (sync 필요)** → `GuildRaidPatternController.cs`가 사용. 레이드 단계에서 동반 이식 필요 |

### 3-e. 인프라 패턴 (모두 미해당)
- SerializableDictionary 0 / JsonConverter 0 / Encrypt-Decrypt 0 — 길드 파일에서 사용 없음.

### 3-f. Utils/ diff (FROM only)
- `GaussianRandom.cs` (FROM에만) — **길드와 무관**. 동반 이식 불필요.

---

## 4. TO 기존 관련 파일 / 호환 인프라 검증

### 4-a. TO 기존 길드 파일
- **Guild/Clan .cs: 0개** (전무).
- 에셋: `Assets/Resources_moved/Sprites/Clan/icon_lobby_guild.png` 1개만 (비활성 폴더 — Resources.Load 불가).

### 4-b. §1.2 호환 인프라 존재 검증 (TO)
모두 **존재 확인 (OK)** — 누락 없음:
UIManager, UIBase, Managers, EventManager, GameEventTypes, CurrencyManager, ECurrencyType,
SaveDataManager, SaveDataTypes, LocalizationManager, ResourceManager, ServerTimeManager,
BaseServerService, RedDotManager, Core/RedDot/(RedDotNode), UI/RedDot/RedDotComponent,
SceneManager, GameModeType, IBossController, BaseBossController, ContentUnlockManager,
ContentTypes, EBottomTabType, BottomTabHUD, ObjectPoolManager, PooledObject,
CardSelectionUI, CardManager, GameResultUI, GameUI, DamageCalculationManager,
StageManager, EnemyManager, LoopGridView(`UI/Components/_InfiniteScroll/_ScrollView/`).
- PunchKing 참조 모델: `PunchKingDungeonManager.cs`, `PunchKingBossController.cs` 존재.

### 4-c. ★ 문서 정정 — WD에 Configurator/StagePlay 패턴 **있음**
문서 §1.1 / §3.3는 "WD는 Configurator/StagePlay 분리 구조가 아예 없음 → 단일 GuildRaidManager로 통합"이라 주장하나, **실측 결과 TO에 존재**:
- `Core/GameModes/IGameModeConfigurator.cs`, `StandardModeConfigurator.cs`, `EndlessModeConfigurator.cs`
- `Core/Managers/StageServices/`: `BaseStagePlayService.cs`, `IStagePlayService.cs`, `IStageServiceContext.cs`, `PunchKingStagePlayService.cs`, `RaceTowerStagePlayService.cs`, `VanguardStagePlayService.cs`

→ `GuildRaidModeConfigurator` / `GuildRaidStagePlayService`는 단일 매니저로 억지 통합할 필요 없이 **WD의 동일 패턴으로 직접 이식 가능**. (단 GuildRaid에 맞춘 시그니처 정합 필요)
- 단, TO에 **없는** 것: `UI/GameModeUI/`(BaseGameModeUIService), `StandardGameResultService` 패턴. → 이 2개(`GuildRaidGameModeUIService`, `GuildRaidGameResultService`)는 WD 기존 `GameUI`/`GameResultUI`로 통합 필요.

---

## 5. 프리팹 / 씬 / SO / 에셋 경로 + 개수 (Phase 5a용, 복사 안 함)

### 프리팹
| 위치 | 개수 |
|------|------|
| `_Project/3_Prefabs/UI/Guild/` (재귀 전체) | **31** |
| └ /Guild 직하 8, /Chat 7, /Hall 4, /Raid 4, /Gift 3, /Discount 2, /GuildMission 2, /Common 1 | |
| 레이드 보스 프리팹 (Guild 디렉터리 밖) | 3 |
| └ `3_Prefabs/Boss/guild_monster_bull.prefab`, `3_Prefabs/Boss/Anim/Guild_Boss_50101_Back_Anim.prefab`, `3_Prefabs/UI/Character/guild_monster_bull_UI.prefab` | |
| `Assets/Resources/UI/` 내 guild-named 프리팹 | 21 |
| **프로젝트 전체 guild/clan/stella 프리팹** | **52** |

### 씬
- `_Project/0_Scenes/GuildBossScene.unity` (전용 레이드 씬) — 1개

### SO 에셋(.asset)
- `_Project/11_SO/Guild/`: `GuildRaidEntranceConfig.asset`, `GuildBossUIPrefabRegistry.asset` (2)
- `_Project/9_Fonts/SpriteAssets/` 내 guild 관련 2
- `AddressableAssets/BalanceConfigs/` 내 clan/guild 14 (밸런스 JSON 계열)
- guild/clan .asset 총 **18**

### 텍스처
- `_Project/6_Textures/Guild/`: **159**
- `_Project/6_Textures/Enemy/GuildRaid/`: 3
- `_Project/6_Textures/InGameBackground/GuildBoss/`: 7
- guild/clan 명칭 6_Textures 합 **105** (iname 기준; Guild/ 폴더는 159 — 폴더 전체가 길드 전용)

### 애니메이션 (.anim) — 총 10 (문서 "17"과 불일치)
- `_Project/4_Animations/UI/`: GuildLobbyUI_GuildNetwork, _GuildHall, _GuildRaid, _GuildShop, _GuildShop_idle, _GuildMission (6)
- `_Project/4_Animations/Enemy/Boss/`: Guild_Monster_Bull_UI_Idle, _Start, _Idle, Guild_Boss_Back_Anim (4)

### 데이터 시트 (자동생성 14종)
ClanLevelData, ClanShopData, ClanShopGroupData, ClanQuestData, ClanQuestProgressData,
ClanContributionData, ClanDiscountData, ClanFlagData, ClanGiftData, ClanGiftSeasonData,
ClanConstData, ClanRaidSeasonData, ClanRaidMemberReward, ClanRaidPersonalReward.

---

## 6. 문서(Guild_Migration_BD_to_WD.md) 대비 정정 사항

1. **총 .cs 218개** (문서 190). 차이 = `SOs/Configs/Clan*` 28개 미포함. 문서의 190 = Configs 28 제외 + 치트 13 포함 기준.
2. **ServiceAccessor 413건/73파일** (문서 582/77). 워크트리 버전 차이로 추정. Phase2에서 재확인 필요.
3. **MessageBroker 32파일** (문서 14) — 문서가 과소 추정.
4. **using Geuneda 29파일** (문서 "0건"은 WD 기준; FROM엔 존재). 변환 본체.
5. ★ **WD에 Configurator/StagePlay/IGameModeConfigurator 패턴 존재** (문서는 "아예 없음" 주장). `GuildRaidModeConfigurator`/`GuildRaidStagePlayService`는 단일 매니저 강제 통합 불필요 — WD 동일 패턴으로 직접 이식 가능. 단 `GameModeUI`/`StandardGameResultService`는 TO에 없어 GameUI/GameResultUI 통합 필요.
6. **애니메이션 10개** (문서 "17"). 실측 10 (.anim).
7. **SOs/Configs/Clan* 28개는 이식 제외 권장** (BD geuneda gamedata DI 패턴, TO에 폴더 없음, DataSheet SO로 대체).
8. **LowLevelPhysicsHelper** (TO 없음)가 `GuildRaidPatternController` 의존성 — 레이드 동반 이식 필요. 문서 미언급.
9. **GaussianRandom**(Utils FROM only)은 길드 무관 — 동반 이식 불필요.
10. 텍스처: `6_Textures/Guild/` 159개 (문서 "100+"는 보수적; 전체 텍스처 부담 더 큼).
11. `Resources/UI/Guild` 별도 디렉터리는 **없음**. Resources 내 guild 프리팹은 `Resources/UI/` 산재 21개. 문서의 "Resources/UI/Guild 동반 확인"은 디렉터리 부재.

---

## 7. Phase2 권고
- ServiceAccessor 413건 재확인(워크트리 vs 문서 582 격차).
- SOs/Configs/Clan* 28개 처리방침 확정(제외 + 모듈 DataSheet 전환).
- 레이드 Configurator/StagePlay는 WD 동일 패턴 직접 이식 경로로 재설계(문서 §3.3 통합안 수정).
- LowLevelPhysicsHelper, GuildUtils 동반 이식 목록 등재.
