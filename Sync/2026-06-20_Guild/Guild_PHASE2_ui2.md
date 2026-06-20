# Guild Sync Phase2 - UI2 (채팅 + 레이드 UI + 잔여 슬롯)

- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 담당 영역: `*Chat*`, `*Raid*` + 그 외 채팅/레이드 슬롯
- 분석 파일: 19개 (Chat 9 + Raid 10)

---

## 0. 핵심 결론 (가장 먼저 읽을 것)

이 19개 파일 전부 **BD 전용 아키텍처(ServiceAccessor / MainInstaller(Zenject) / IMessageBrokerService)** 에 강하게 묶여 있다.
WD에는 이 세 가지가 **모두 존재하지 않는다.** 따라서 **단순 파일 복사(DIRECT) 가능 파일은 0개**.
모든 파일이 최소 ADAPTED, 레이드는 대부분 PARTIAL(런타임 미이식 의존).

WD 부재 확인:
- `ServiceAccessor` : WD에 없음 (이 19파일에서 `ServiceAccessor.Get<T>` 총 **67회** 호출)
- `MainInstaller` / Zenject `IMessageBrokerService` : WD에 없음
- `MessageBroker` (BD UIBase의 `protected IMessageBrokerService MessageBroker` 프로퍼티) : WD UIBase에 없음
- `GuildManager` : WD에 없음 (= 길드 도메인 자체가 미이식, 별도 매니저 에이전트 영역)
- `Nobi.UiRoundedCorners.ImageWithRoundedCorners` : WD .cs/패키지 없음 (프리팹에서 GUID로만 참조 흔적). **컴파일 차단 요소**
- `ECurrencyType.ClanCurrency` : WD enum에 없음 (WD는 Vanguard 계열만 보유) → enum-name 리맵 필요

WD 부재 = **이 영역은 길드 매니저/서버레이어/도메인 모델 선이식 없이는 컴파일 불가**.
=> Phase2 결론: UI 파일 자체는 구조 파악 완료, 실제 이식은 길드 백본(GuildManager + ServiceAccessor 대체 + MessageBroker→EventManager 변환) 선행 필수.

---

## 1. ServiceAccessor 총건 (담당 19파일)

| 매니저 | 호출 수 |
|---|---|
| GuildManager | 25 |
| UIManager | 15 |
| ServerTimeManager | 7 |
| PlayerDataManager | 4 |
| CurrencyManager | 4 |
| ContentUnlockManager | 4 |
| ServerManager | 3 |
| ResourceManager | 2 |
| MembershipManager | 2 |
| SceneManager | 1 |
| **합계** | **67** |

WD 변환 시 `ServiceAccessor.Get<X>()` → `Managers.Instance.GetManager<X>()` 로 전면 치환 필요.
(단, UIManager/ResourceManager/SceneManager 등은 WD에도 동일 매니저 존재. GuildManager는 부재 → 백본 선이식.)

---

## 2. MessageBroker 이벤트 목록 (GameEventType 후보)

BD는 `MessageBroker.Subscribe<T>/Unsubscribe<T>/PublishSafe` (제네릭 메시지 타입) 패턴.
WD는 **정적 `EventManager.Subscribe<T>(GameEventType.X, handler)` + `EventManager.Dispatch<T>`** 패턴.
=> 메시지 타입을 GameEventType enum 항목 + payload struct/class 로 변환해야 함.
(주의: MEMORY의 "EventManager 제네릭vs단순 테이블" — 제네릭/단순 계열 일치시킬 것.)

담당 파일에서 구독/발행되는 메시지 타입:

| 메시지 타입 | 출현 파일 | 용도 |
|---|---|---|
| `GuildChatReceivedMessage` | GuildChatPanel, LobbyChatUI | 신규 채팅 수신 → 리스트 append / 미리보기 갱신 |
| `GuildMemberJoinedMessage` | GuildChatPanel | 시스템 메시지(가입) 로컬 append |
| `GuildMemberLeftMessage` | GuildChatPanel | 시스템 메시지(탈퇴/추방, `WasKicked`) |
| `GuildLevelUpMessage` | GuildChatPanel | 시스템 메시지(레벨업, `NewLevel`) |
| `GuildGiftClaimStateChangedMessage` | GuildChatPanel | 선물 수령 상태 변경(`GiftIdxs[]`) → 슬롯 재바인딩 |
| `GuildRaidStatusUpdatedMessage` | GuildRaidLobbyUI | 레이드 status 갱신 재렌더 |
| `GuildLeftMessage` | GuildRaidLobbyUI, GuildRaidRankingPopup, GuildRaidQuestPopup | 길드 탈퇴/해체 시 UI 자동 닫기 |
| `DailyResetMessage` | GuildRaidLobbyUI | 자정 리셋 시 로비 자동 닫기 (WD에도 유사 존재 가능 — 확인 필요) |

추가 발행: BD UIBase가 `RewardPopupClosedMessage` 를 PublishSafe (담당 파일 외, 베이스 의존).

---

## 3. LoopGridView 호환성 (중요)

채팅은 가상 스크롤로 **LoopGridView** 를 사용한다.

WD 보유 확인:
- `Assets/_Project/1_Scripts/UI/Components/_InfiniteScroll/_ScrollView/LoopGridView.cs` ✅
- `LoopGridViewItem.cs` ✅ (채팅 슬롯 베이스가 이걸 상속)

WD에 존재하는 API (채팅이 사용):
`ArrangeType`(GridItemArrangeType), `ScrollRect`, `InitGridView`, `SetListItemCount`,
`NewListViewItem`, `ForceToCheckContentPos`, `MovePanelToItemByIndex`, `RefreshAllShownItem`,
`LoopGridViewSettingParam`/`GridFixedType`/`GridItemArrangeType.BottomLeftToTopRight`, `mRowHeightOverrides` ✅

**[차이 — 차단 요소]** `InvalidateRowHeightCache()`:
- **BD LoopGridView에는 존재**(line 239, 캐시 Clear). 채팅 패널에서 행높이 stale 방지로 **4회 호출**.
- **WD LoopGridView에는 없음**. (BD가 채팅 가변높이(선물 슬롯 등) 대응으로 추가한 메서드)
- => WD `LoopGridView.cs` 에 `InvalidateRowHeightCache()` 메서드 1개 백포팅 필요.
  (BD 구현: `public void InvalidateRowHeightCache() { mRowHeightOverrides.Clear(); }` — 단순)
- **주의**: LoopGridView는 공용 컴포넌트라 "구조 변경 금지" 룰에 닿을 수 있으나, 이건 신규 메서드 1개 **추가**(기존 동작 불변)라 안전. 가변높이 채팅 동작에 필수.
- 또는 BD LoopGridView.cs 전체를 sync(별도 컴포넌트 에이전트 영역과 조율 필요).

LoopGridView 채팅 아키텍처:
- `ArrangeType = BottomLeftToTopRight` + 콜백에서 itemIndex↔viewIndex 뒤집기(itemIndex 0 = 화면 하단 = 최신)
- 데이터 리스트(`_chatMessages`)는 자연 시간 오름차순 유지, `_viewItems`(채팅+날짜구분선 합성)로 렌더
- 무한스크롤 prepend(과거 로드), 옵티미스틱 전송(temp ID → 서버 chat swap), 행높이 캐시 무효화로 가변높이 처리

---

## 4. 슬롯 아키텍처 (GuildChatSlotBase + variants)

- `GuildChatSlotBase : LoopGridViewItem` (추상). 공통: 시간포맷, 서버시각, 프로필 아이콘/프레임 비동기 로드(`_bindToken` 재바인딩 안전), 멤버 캐시 조회.
- 종류 enum `EGuildChatSlotKind` (별도 enum 파일 — 다른 에이전트/공용. 본 영역서 사용만): MineMember, OtherMember, System, LeaderDm, MineGift, OtherGift, DateSeparator.
- 프리팹 매핑(`SlotPrefabName` dict)으로 `grid.NewListViewItem(prefabName)` 풀 조회:
  - GuildChatSlot_Mine / _Other / _System / _LeaderDm / _Gift_Mine / _Gift_Other / _Date
- 변형 6종:
  - `GuildChatMineSlot` : 본인 MEMBER. 프로필=PlayerDataManager 장착 인덱스 우선.
  - `GuildChatOtherSlot` : 타인 MEMBER. 멤버 캐시 조회, `AppliedPassType` 닉컬러.
  - `GuildChatLeaderDmSlot` : 길드장 DM. Other와 동일 구조.
  - `GuildChatSystemSlot` : 시스템 단일 텍스트(`GuildUtils.FormatChatSystemText`).
  - `GuildChatGiftSlot` : 선물상자(Mine/Other 공용). 카운트다운 Update, ClaimGift 플로우, `ClanGiftIconConfigSO` 등급 스프라이트. **399줄, 가장 복잡.**
  - `GuildChatDateSeparatorSlot` : `LoopGridViewItem` 직접 상속(채팅 데이터 없음). 날짜 한 줄.

---

## 5. 파일별 분석 + 분류

### Chat (9)

| 파일 | 줄 | 역할 | UIBase/Show | 분류 | 비고 |
|---|---|---|---|---|---|
| GuildChatPanel.cs | 1051 | 채팅 영역 총괄(폴링/구독/확장축소/LoopGridView) | MonoBehaviour (UIBase 아님) | **ADAPTED** | ServiceAccessor 다수, MessageBroker(Zenject) 5종 구독, InvalidateRowHeightCache 의존, GuildManager 의존 |
| GuildChatSlotBase.cs | 128 | 채팅 슬롯 추상 베이스 | LoopGridViewItem | **ADAPTED** | ServiceAccessor(ServerTime/Guild/ContentUnlock/Resource) |
| LobbyChatUI.cs | 116 | 축소형 미리보기 스트립 | MonoBehaviour | **ADAPTED** | MainInstaller.Resolve, GuildChatReceivedMessage 자체 구독 |
| Slots/GuildChatMineSlot.cs | 68 | 본인 메시지 슬롯 | GuildChatSlotBase | **ADAPTED** | ServiceAccessor(PlayerData/Membership) |
| Slots/GuildChatOtherSlot.cs | 44 | 타인 메시지 슬롯 | GuildChatSlotBase | **ADAPTED** | TextUtility.ApplyNicknameColor |
| Slots/GuildChatLeaderDmSlot.cs | 40 | 길드장 DM 슬롯 | GuildChatSlotBase | **ADAPTED** | Other와 동일 |
| Slots/GuildChatSystemSlot.cs | 20 | 시스템 슬롯 | GuildChatSlotBase | **ADAPTED** | GuildUtils 의존만 |
| Slots/GuildChatDateSeparatorSlot.cs | 30 | 날짜 구분선 | LoopGridViewItem | **ADAPTED** | LocalizationManager만 (가장 가벼움) |
| Slots/GuildChatGiftSlot.cs | 399 | 선물상자 슬롯 | GuildChatSlotBase | **PARTIAL** | ClaimGift/OpenGiftDetail 서버플로우, ClanGiftIconConfigSO, GuildGiftBox 모델 — 선물 도메인 미이식 의존 |

### Raid (10)

| 파일 | 줄 | 역할 | UIBase/Show | 분류 | 비고 |
|---|---|---|---|---|---|
| GuildRaidLobbyUI.cs | 661 | 레이드 로비(보스소환/강화/입장/타이머/TOP3) | **UIBase** (Popup) | **PARTIAL** | `SceneManager.LoadGuildRaidSceneAsync`(레이드 인게임 미이식), GuildBossUIPrefabRegistrySO, GuildRaidStatus 모델, DamageCalc 연동, ECurrencyType.ClanCurrency, ClanConstDataParser.Raid* |
| GuildRaidRankingPopup.cs | 157 | 랭킹 팝업(멤버/길드 탭) | **UIBase** (Popup) | **PARTIAL** | GuildManager.GetRaidRankingAsync 서버, 두 패널 의존 |
| GuildRaidQuestPopup.cs | 160 | 미션 팝업(개인/길드 탭) | **UIBase** (Popup) | **PARTIAL** | GuildManager quest status/캐시, RaidPersonalReward/RaidMemberReward 모듈 |
| GuildRaidGuildRankingSlot.cs | 101 | 길드 랭킹 리스트 슬롯 | MonoBehaviour | **ADAPTED** | GuildIcon, GuildRaidGuildRank 모델 |
| GuildRaidGuildRankingPanel.cs | 170 | 길드 랭킹 패널(TOP3+리스트+내길드) | MonoBehaviour | **PARTIAL** | ServerManager.GetGuildByUidAsync, GuildHallUI(다른 길드 모드), DTO ToModel |
| GuildRaidMemberRankingSlot.cs | 47 | 멤버 랭킹 슬롯 | **RankingDisplaySlot** 상속 | **ADAPTED** | WD RankingDisplaySlot 존재 ✅, GuildRaidMemberRank.ToRankingItem |
| GuildRaidMemberRankingPanel.cs | 98 | 멤버 랭킹 패널(TOP3+리스트+내랭킹) | MonoBehaviour | **PARTIAL** | BaseTopRankSlot(WD 존재 ✅), PlayerDataManager.UserID, DTO |
| GuildRaidTop3RankingSlot.cs | 146 | 로비 TOP3 슬롯 View | MonoBehaviour | **ADAPTED** | ContentUnlockManager 프로필, GuildRaidMemberRank |
| GuildRaidQuestSlot.cs | 142 | 미션 슬롯(진행/보상/수령) | MonoBehaviour | **PARTIAL** | **Nobi.UiRoundedCorners 의존(WD 부재)**, ItemDisplayComponent(WD 존재 ✅), GuildRaidRewardTier, RedDotComponent |
| GuildRaidQuestPanel.cs | 180 | 미션 패널(슬롯생성/배치수령) | MonoBehaviour | **PARTIAL** | GuildManager.ClaimRaidQuestsAsync, RewardClaimPopupUI(WD 존재 ✅), GuildRaidQuestTracks |

---

## 6. 스킵한 파일 (다른 UI 에이전트 담당 — Chat/Raid 미포함)

`Chat`/`Raid` 키워드가 없는 슬롯/팝업은 전부 다른 에이전트 영역이라 미분석:

- Guild 루트 팝업/UI(비-Raid): GuildContributionPopup, GuildCreatePopup, GuildDiscountPopup, GuildEntryRouter, GuildGiftBoxPopup, GuildGiftDetailPopup, GuildGiftRewardEffectAnimRelay, GuildGiftRewardEffectPopup, GuildGiftSendConfirmPopup, GuildHallUI, GuildIconChoicePopup, GuildJoinPopup, GuildJoinRequestManagementPopup, GuildLevelDetailPopup, GuildLobbyUI, GuildManagementPopup, GuildMissionPopup, GuildNicknameGate, GuildPersonnelOfficePresenter, GuildPersonnelOfficeUI, GuildRankingPopup, GuildShopPopup, GuildUtils
- Components(비-Chat/비-Raid 슬롯): GuildContributionPanel, GuildDiscountParticipantSlot, GuildDiscountRewardSlot, GuildGiftClaimerSlot, GuildGiftSlot, GuildHistorySlot, GuildIcon, GuildJoinRequestReviewSlot, GuildJoinSlot, GuildLevelEffectSlot, GuildLobbyMemberWanderSlot, GuildLobbyMemberWanderer, GuildMemberSlot, GuildQuestPanel, GuildQuestProgressNode, GuildQuestRewardPanel, GuildQuestSlot, GuildRankingSlot, GuildRentalCandidateSlot, GuildSearchComponent, GuildShopItemSlot

(주: 본 영역은 위 일부에 강하게 의존 — GuildGiftBoxPopup/GuildGiftDetailPopup(채팅 선물 클릭 라우팅), GuildHallUI(길드 랭킹 클릭), GuildIcon(랭킹 플래그), GuildUtils(전역 헬퍼). 동시 이식 필수.)

---

## 7. 주의사항 / 이식 순서 제언

1. **선행 필수(백본)**: GuildManager + ServiceAccessor 대체(=`Managers.Instance.GetManager<T>` 치환 규칙) + MessageBroker→EventManager(GameEventType 8종 신설) + Guild 도메인 모델/DTO/서버레이어. 이게 없으면 19파일 전부 컴파일 불가.
2. **LoopGridView**: `InvalidateRowHeightCache()` 1개 메서드 백포팅(또는 BD LoopGridView.cs sync). 가변높이 채팅 필수, 미적용 시 선물 슬롯 겹침.
3. **Nobi.UiRoundedCorners**: WD에 .cs/패키지 부재. GuildRaidQuestSlot/GuildQuestSlot 공용. 패키지 추가 또는 의존 제거(라운드코너 Refresh 로직) 필요. **컴파일 차단**.
4. **ECurrencyType.ClanCurrency**: WD enum 부재 → enum-name 기준 리맵(MEMORY: ECurrencyType BD↔WD 리맵 룰). RaidRewards/입장비용 영향.
5. **레이드 인게임(PARTIAL 핵심)**: `SceneManager.LoadGuildRaidSceneAsync`, GuildBossScene, DamageCalculationManager 길드 강화 보너스 = 레이드 런타임/전투. UI만으론 동작 불가 → 레이드 런타임 이식과 묶어야 함. (Flag PARTIAL)
6. **UIBase 차이**: WD UIBase에 `MessageBroker` 프로퍼티 없음. 레이드 팝업 4종이 `MessageBroker.Subscribe`를 베이스 경유로 호출 → EventManager 직접 호출로 치환.
7. WD 보유로 재활용 가능(확인됨): UIBase, UIManager.Show/Hide/IsOpened, RankingDisplaySlot, BaseTopRankSlot, ItemDisplayComponent, RedDotComponent, TopCurrencyBoxComponent, StageInfoPopupUI, LoadoutPopupUI, RewardClaimPopupUI, ServerLoadingPopupUI, LoopGridView/LoopGridViewItem, ServerTimeManager.NowUnscaled, LocalizationManager.

## 8. 분류 집계

- DIRECT: **0**
- ADAPTED: **9** (채팅 슬롯/베이스/패널 다수 + 일부 레이드 슬롯)
- PARTIAL: **10** (레이드 로비/팝업/패널 전부 + 채팅 선물 슬롯)
