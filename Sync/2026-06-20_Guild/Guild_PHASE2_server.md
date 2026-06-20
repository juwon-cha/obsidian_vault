# Guild Phase 2 — 서버서비스 + 모델 + Enum + 이벤트 + 데이터시트 분석

- 작성일: 2026-06-20
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 담당 영역: Server/Guild, Models/Guild, Enums/EGuild*, Events/Guild, DataSheet Clan* 클래스/SO
- READ-ONLY 분석

---

## 0. 파일 수 요약

| 영역 | 개수 | 비고 |
|------|------|------|
| Server/Guild .cs | 24 | GuildServerService(.cs + 11 partial = 12) + GuildResponseTypes(.cs + 10 partial = 11) + GuildEnumParser + GuildErrorMessage |
| Models/Guild .cs | 13 파일 (14 클래스) | GuildGiftBox.cs 안에 GuildGiftBox + GuildGiftClaim 2개 |
| Enums EGuild*.cs | 7 | |
| Events/Guild .cs | 3 | GuildEvents / GuildRaidEvents / ClanQuestEvents |
| DataSheet Class (`SOs/Class/DataSheet/Clan*Data.cs`) | 14 | |
| DataSheet SO (`SOs/SO/DataSheet/Clan*SO.cs`) | 14 | |
| **본 영역 합계** | **75 파일** | |

---

## 1. 서버 엔드포인트 전수 목록 (Critical)

### 결론
- **총 57개 엔드포인트** (ENDPOINT 상수 57개 = RequestApiAsync 호출 57건, 모두 1:1).
- **route prefix 는 전부 `/guild/`**. `/clan/` 라우트는 **0건**.
- 문서의 "56 endpoints" 는 과소 (실측 57). 문서의 "/guild/ prefix" 주장은 **정확**.
  - 참고: 단순 정규식(`"/guild/[A-Za-z0-9/_]*"`)으로 grep하면 56으로 보이는데, 이는 `/guild/raid/quest/claim-all` 의 하이픈이 문자클래스에서 빠져 누락된 탓. ENDPOINT 상수 기준 정확 카운트는 57.

### partial별 분포 (RequestApiAsync 호출 수)
| partial | 호출 수 |
|---------|---------|
| Common | 14 |
| Management | 11 |
| Chat | 8 |
| Raid | 7 |
| Quest | 4 |
| Discount | 3 |
| Rental | 3 |
| Buff | 2 |
| Donation | 2 |
| Shop | 2 |
| RedDot | 1 |
| **합계** | **57** |

> 주의: GuildServerService.cs 헤더 주석은 "36개 엔드포인트(Common 13 + ...)" 라 적혀 있으나 이는 옛 주석. 실제 partial(Discount/Rental/RedDot/Raid 추가)로 57까지 늘어남. 주석 무시.

### 전체 라우트 목록 (57)
```
/guild/buff/getTodayBuff
/guild/buff/rerollBuff
/guild/cancelJoinRequest
/guild/chat/claimGift
/guild/chat/claimGiftMulti
/guild/chat/getChatList
/guild/chat/getDmList
/guild/chat/getGiftInfo
/guild/chat/sendChat
/guild/chat/sendDm
/guild/chat/sendGift
/guild/createGuild
/guild/discount/participate
/guild/discount/purchase
/guild/discount/today
/guild/donation/donate
/guild/donation/getDailyDonation
/guild/getGroupRanking
/guild/getGuildByUid
/guild/getHistory
/guild/getMainRedDot
/guild/getMyCombatPower
/guild/getMyGuild
/guild/joinGuild
/guild/leaveGuild
/guild/listMyJoinRequests
/guild/listServerGuilds
/guild/management/acceptJoinRequest
/guild/management/kickMember
/guild/management/listJoinRequests
/guild/management/rejectJoinRequest
/guild/management/setMemberRank
/guild/management/transferLeader
/guild/management/updateGuildIcon
/guild/management/updateGuildName
/guild/management/updateIntro
/guild/management/updateJoinType
/guild/management/updateNotice
/guild/quest/claimMission
/guild/quest/claimProgress
/guild/quest/incrementProgress
/guild/quest/status
/guild/quickJoin
/guild/raid/buff/strengthen
/guild/raid/clear
/guild/raid/enter
/guild/raid/quest/claim
/guild/raid/quest/claim-all
/guild/raid/quest/status
/guild/raid/ranking
/guild/rental/confirm
/guild/rental/listCandidates
/guild/rental/setMyMinionInfo
/guild/searchGuild
/guild/setMyCombatPower
/guild/shop/buyShopItem
/guild/shop/getCatalog
```

---

## 2. 이벤트(메시지) 전수 목록 (Critical)

### 결론
- **총 30개** (문서 "31" 은 과대 1개).
  - GuildEvents: **21** (문서 22 — 1개 과대. 5번 라인의 주석을 클래스로 오인했을 가능성)
  - GuildRaidEvents: **4** (문서 4 일치)
  - ClanQuestEvents: **5** (문서 5 일치)
- 모든 메시지는 `: IMessage` 구현. **`IMessage` 는 Geuneda 패키지 정의** (`using Geuneda.Services`). WD에는 IMessage / MessageBroker 가 없음.
  → **변환 필수**: IMessage 메시지 클래스 → WD EventManager static 패턴(`GameEventType` enum 항목 추가 + `EventManager.Dispatch<T>/Subscribe<T>`)으로 재배선. 30종 모두.

### GuildEvents (21)
GuildJoinedMessage, GuildLeftMessage, GuildUpdatedMessage, GuildMemberJoinedMessage,
GuildMemberLeftMessage, GuildLeaderChangedMessage, GuildLevelUpMessage, GuildCurrencyChangedMessage,
GuildJoinRequestSentMessage, GuildJoinRequestCanceledMessage, GuildJoinTypeChangedMessage,
GuildChatReceivedMessage, GuildDmReceivedMessage, GuildBuffChangedMessage,
GuildDailyDonationChangedMessage, GuildPersonnelOfficeClosedMessage,
GuildPendingJoinRequestCountChangedMessage, GuildDiscountTodayChangedMessage,
GuildMainRedDotChangedMessage, GuildGiftSeasonExpiredMessage, GuildGiftClaimStateChangedMessage

### GuildRaidEvents (4)
GuildRaidStatusUpdatedMessage, GuildRaidStrengthenedMessage,
GuildRaidRankingRefreshedMessage, GuildRaidQuestProgressMessage

### ClanQuestEvents (5)
ClanQuestProgressChangedMessage, ClanQuestClaimedMessage, ClanQuestExpChangedMessage,
ClanQuestProgressTierClaimedMessage, ClanQuestStatusRefreshedMessage

> 메모 참조 (`project_eventmanager_generic_vs_simple_tables.md`): WD EventManager 의 제네릭 Dispatch<T>/Subscribe<T> 와 단순 Action 테이블은 별개. 30종 모두 페이로드를 가지므로 제네릭 계열로 일관 배선할 것.

---

## 3. Enum 목록 (7) + ECurrencyType 추가 필요 (Critical)

### EGuild* 7종
| Enum | 값 |
|------|-----|
| EGuildChatMessageType | MEMBER, LEADER_DM, SYSTEM, GIFT |
| EGuildChatSlotKind | MineMember, OtherMember, System, LeaderDm, MineGift, OtherGift, DateSeparator |
| EGuildDonateType | FREE, AD, GEM |
| EGuildGiftStatus | OPEN, DEPLETED, EXPIRED |
| EGuildHistoryType | JOIN, LEAVE, KICK, LEADER_TRANSFER, JOIN_REQUEST_REJECTED, JOIN_TYPE_CHANGE, INTRO_CHANGE, NOTICE_CHANGE, ICON_CHANGE, NAME_CHANGE, RANK_CHANGE, GUILD_LEVEL_UP, DISBAND |
| EGuildJoinType | FREE, APPROVAL |
| EGuildMemberRank | LEADER, SUB_LEADER, MEMBER |

- 7개 enum 모두 WD에 없음 → 그대로 신규 이식. 의존성/Geuneda 없음.

### ★ ECurrencyType 추가 필요 (5개) — 값 충돌 주의
길드 코드가 사용하는 ECurrencyType 항목 (실사용):
`ClanCurrency`, `ClanContribution`, `ClanGiftEpic`, `ClanGiftLegendary`, `ClanGiftMythic`
(주의: `ClanGift` (suffix 없음) 은 GuildGiftCatalogModule.cs 의 **doc 주석 텍스트(`ClanGift*`)** 일 뿐 실제 enum 참조 아님 → 추가 불필요.)

WD ECurrencyType 에는 위 5개가 **전부 없음** → 추가 필요.

**값 충돌 (★ 반드시 리맵):**
| 항목 | BD 값 | WD 충돌 |
|------|-------|---------|
| ClanGiftEpic | 820 | (BD 820 = WD 미사용 추정, 확인 필요) |
| ClanGiftLegendary | 821 | " |
| ClanGiftMythic | 822 | " |
| ClanCurrency | 1128 | **WD `RandomChip0_108 = 1128` 와 충돌** |
| ClanContribution | 1129 | **WD `RandomChip0_109 = 1129` 와 충돌** |

→ 메모(`project_ecurrencytype_bd_wd_divergence.md`) 원칙대로 **이름 기준 리맵 필수**. ClanCurrency/ClanContribution 은 BD 값 1128/1129 를 그대로 쓰면 WD RandomChip 과 겹치므로 **WD에서 안전한 미사용 정수로 재할당**해야 함. 820~822 도 WD 측 충돌 여부를 추가 확인 후 안전값 부여.

→ **`ResolveCurrencyType(int rawCode)` 주의** (GuildEnumParser): 서버 currency_type 정수코드를 `(ECurrencyType)N` 으로 직접 캐스팅함(1=Gem 특례 외). BD enum 값과 서버 코드가 1:1이라는 전제. WD 리맵으로 값을 바꾸면 **이 캐스팅이 깨진다**. 리맵 시 ResolveCurrencyType 을 명시 매핑 테이블(서버코드→WD enum)로 수정하거나, 서버가 보내는 코드가 1(Gem)/None 외 Clan 계열을 쓰는지 호출부(GuildGiftBox 보물상자) 검증 필요.

---

## 4. 모델 목록 (13파일 / 14클래스) + ToModel

| 파일 | 클래스 | 비고 |
|------|--------|------|
| Guild.cs | Guild | 길드 본체 POCO |
| GuildBuff.cs | GuildBuff | |
| GuildBuffEffect.cs | GuildBuffEffect | |
| GuildChatMessage.cs | GuildChatMessage | |
| GuildGiftBox.cs | GuildGiftBox + GuildGiftClaim | 2 클래스. Claim.isClaimedByMe = Doc.ToModel 시점 myGamerId 매칭으로 채움 |
| GuildHistoryEntry.cs | GuildHistoryEntry | |
| GuildJoinRequest.cs | GuildJoinRequest | |
| GuildListEntry.cs | GuildListEntry | |
| GuildMember.cs | GuildMember | |
| GuildRaidGuildRank.cs | GuildRaidGuildRank | |
| GuildRaidMemberRank.cs | GuildRaidMemberRank | |
| GuildRaidStatus.cs | GuildRaidStatus | /guild/raid/enter 응답 GuildRaidStatusDoc.ToModel() 결과 |
| GuildRaidStrengthen.cs | GuildRaidStrengthen | |

### ToModel() 매핑 (서버 Doc → 모델 POCO)
- ToModel() 은 **GuildResponseTypes.* 파일의 Doc 클래스 인스턴스 메서드** (외부 확장 메서드 아님 → 추가 의존성 없음, 그대로 이식 가능).
- ToModel() 보유 파일: `GuildResponseTypes.cs`, `GuildResponseTypes.Buff.cs`, `GuildResponseTypes.Chat.cs`, `GuildResponseTypes.Raid.cs` (총 ~12 메서드).
- 모델 파일 자체는 Geuneda/ServiceAccessor/MessageBroker 의존 **없음** → 무변환 이식.

---

## 5. BaseServerService 호환성 (Critical 검증)

- ✅ `GuildServerService : BaseServerService` (partial, `GuildServerService.cs`).
- ✅ 모든 API가 `RequestApiAsync<ServerResponse<TResponse>>(ENDPOINT, body, ...)` 사용.
- ✅ WD `BaseServerService.RequestApiAsync<T>` 시그니처 일치:
  `protected async UniTask<T> RequestApiAsync<T>(string endpoint, JObject requestData = null, int maxRetriesCount = 3, bool autoRetryInfinity = false, bool skipQueueWait = false, bool silentMode = false) where T : class`
  - BD 호출부가 쓰는 `skipQueueWait:` 명명 인자도 **WD에 그대로 존재** → 무변환.
- ✅ ServerResponse<T>(localizeKey/message) 계약도 WD 호환 (GuildErrorMessage.Resolve 가 사용).

→ **서버 서비스 레이어는 WD BaseServerService 와 완전 호환.** Geuneda 의존 없음. 라우트/DTO/EnumParser/ErrorMessage 그대로 이식 가능 (단 ECurrencyType 리맵 영향만).

---

## 6. Naming duality 확인 (Critical)

- ✅ **런타임/라우트 = Guild* / `/guild/`**: 클래스 `GuildServerService`, `GuildManager`, 메시지 `Guild*Message`, 라우트 전부 `/guild/`.
- ✅ **데이터시트/SO/일부 응답·모델 보조 = Clan***:
  - DataSheet Class: `Clan*Data.cs` (14)
  - DataSheet SO: `Clan*SO.cs` (14, `[CreateAssetMenu(menuName="GameData/CreateClan...")]`)
  - 이벤트 일부: `ClanQuest*Message` (5)
  - 응답 Doc/모델 일부도 Clan 명 혼용 가능 (ClanQuest 계열)
- 즉 문서의 이중 명명 규칙(runtime/route=Guild, datasheet/SO/response=Clan) **확정**.

### DataSheet 14종 (Class/SO 쌍)
ClanConstData, ClanContributionData, ClanDiscountData, ClanFlagData, ClanGiftData,
ClanGiftSeasonData, ClanLevelData, ClanQuestData, ClanQuestProgressData,
ClanRaidMemberReward, ClanRaidPersonalReward, ClanRaidSeasonData, ClanShopData, ClanShopGroupData
- Class 파일명 규칙: `Clan*DataData.cs` (DataData 접미 — 자동생성 컨벤션), SO 파일명: `Clan*DataSO.cs` 또는 `Clan*RewardSO.cs`.
- 패턴: `[System.Serializable] class ClanXxxData` (Class) / `: ScriptableObject` (SO). Geuneda 의존 없음 = WD DataSheet 파이프라인과 동일 컨벤션 → 직접 이식 + 시트 차팅으로 재생성 가능.
- **주의**: 문서 §3-b의 `SOs/Configs/Clan*` 28개(BD geuneda gamedata Config) 는 **본 14 DataSheet 와 별개**이며 본 영역엔 미포함(이식 제외 대상).

---

## 7. 변환 분류 요약

| 영역 | 변환 부담 | 내용 |
|------|-----------|------|
| Server/Guild (24) | **거의 무변환** | BaseServerService/RequestApiAsync WD 호환. 단 ResponseTypes.Chat.cs 의 `ServiceAccessor.Get<GuildManager>()` 1건 → `Managers.Instance.GetManager<GuildManager>()` 치환. EnumParser ResolveCurrencyType 는 ECurrencyType 리맵 영향. |
| Models/Guild (13) | **무변환** | Geuneda 의존 없음, ToModel 자체포함 |
| Enums EGuild* (7) | **무변환** | 신규 추가 |
| ECurrencyType | **★ 리맵 필수** | 5개 추가, ClanCurrency/ClanContribution 값(1128/1129) WD RandomChip 충돌 → 안전값 재할당 + ResolveCurrencyType 매핑 점검 |
| Events/Guild (3, 30종) | **★ 전면 재배선** | IMessage(Geuneda) → WD EventManager static(GameEventType + Dispatch/Subscribe<T>). 30 메시지 + 발행/구독부 모두. (발행/구독부는 GuildManager/UI 측 = 타 영역) |
| DataSheet (14×2) | **무변환** | WD DataSheet 컨벤션 동일. 시트 차팅 재생성 가능 |

---

## 8. 주의사항 (인계)

1. **이벤트 30종(문서 31 아님)** — IMessage 전면 제거, EventManager 제네릭 테이블로 일관 배선. GameEventType enum 항목 30개 신규 추가 필요.
2. **엔드포인트 57개(문서 56 아님)** — 전부 `/guild/` 라우트. `/clan/` 없음. ENDPOINT 상수 그대로 이식.
3. **ECurrencyType 값 충돌**: ClanCurrency=1128 / ClanContribution=1129 가 WD RandomChip0_108/109 와 정면 충돌. **반드시 WD 안전 정수로 리맵.** GiftEpic/Legendary/Mythic(820~822) 도 WD 충돌 재확인.
4. **ResolveCurrencyType 캐스팅 함정**: `(ECurrencyType)N` 직접 캐스팅(GuildEnumParser) → ECurrencyType 값 리맵 시 서버 currency_type 코드 매핑이 깨질 수 있음. 보물상자 호출부(GuildGiftBox) 가 실제로 Clan 계열 코드를 받는지 확인 후 명시 매핑으로 전환.
5. **ServiceAccessor 1건**: ResponseTypes.Chat.cs:63 `ServiceAccessor.Get<GuildManager>()` → GetManager 치환 (Server 영역 내 유일한 Geuneda 잔재; Models/Enums/DataSheet 는 깨끗함).
6. **GuildServerService.cs 헤더 주석의 "36 엔드포인트"는 옛 정보** — 실제 57. 코드 신뢰.
7. DataSheet Class 파일명 `Clan*DataData.cs`(DataData 이중접미)는 자동생성 컨벤션 — WD 시트 재생성 시 동일 규칙 유지.
