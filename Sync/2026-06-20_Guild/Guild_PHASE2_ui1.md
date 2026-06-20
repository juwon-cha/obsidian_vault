# Guild PHASE2 - UI/Guild 분석 (담당: 비-Chat / 비-Raid 전체, 45파일)

- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 범위: `UI/Guild/` 하위에서 이름에 **Chat / Raid 미포함** 파일 전체(루트 팝업/허브/로비/엔트리 + Components/). Chat*, Raid* UI는 타 에이전트 담당.

> 주의: 알파벳 단순 절반 분할은 Components/ 와 루트팝업을 부자연스럽게 가르므로, 프롬프트의 "Chat/Raid 미포함" 하드룰 + 명시 파일목록(Create/Join/Management/Mission/Ranking/Shop/Discount/Contribution/Gift*/Icon/Level/Personnel + 로비/허브/엔트리)에 맞춰 **비-Chat/비-Raid 45파일 전체**를 분석함.

---

## 1. 핵심 변환 결론 (가장 중요)

| FROM 패턴 | TO(WD) 존재? | 변환 방향 | 영향 |
|---|---|---|---|
| `ServiceAccessor.Get<T>()` | **없음** | → `Managers.Instance.GetManager<T>()` | **198건** 전 파일 |
| `MessageBroker.Subscribe/Unsubscribe<T>` (static) | **없음** | → 정적 `EventManager.Subscribe/Dispatch<T>(GameEventType, ...)` | 38+건 / 19파일 |
| `MainInstaller.Resolve<IMessageBrokerService>()` (instance DI) | **없음(VContainer류 DI 부재 추정)** | → 동일 EventManager 경로로 통합 | Geuneda 2파일만 |
| `MessageBroker.Unsubscribe<T>(this)` (owner 기반) | EventManager는 핸들러 기반 | → `Unsubscribe<T>(type, handler)` 시그니처 재작성 | 구독 해제 전부 |
| `MessageBroker.PublishSafe(new XxxMessage())` | 없음 | → `EventManager.Dispatch<T>(GameEventType.Xxx, data)` | 1건(PersonnelOfficeUI) |

WD UIBase 라이프사이클은 BD와 동일(`Opened(object[])`/`Closed(object[])`, `UIManager.Show<T>(params object[])`) → **UI 골격은 DIRECT**, 변환부담은 DI/이벤트 배선에 집중됨.

---

## 2. 클래스 / 상속 / 역할

### 루트 팝업·허브 (UIBase 상속, UIManager.Show 대상)
- `GuildHallUI`(483) — 길드 정보 딥뷰(내/남 길드 모드), 멤버리스트 슬롯풀. ServiceAccessor 15, MB구독 5(Left/Updated/MemberJoined/MemberLeft/LeaderChanged).
- `GuildLobbyUI`(390) — 길드 로비 메인. SA 16, MB구독 2(Left/Updated).
- `GuildManagementPopup`(694, **최대**) — 길드 관리(길드장 편집/가입타입토글 flush). SA 23(최다), MB구독 4. NameRegex 등 검증로직.
- `GuildGiftBoxPopup`(594) — 선물상자. SA 13, MB구독 4(Currency/Left/GiftSeasonExpired/GiftClaimState), TopCurrency 없음.
- `GuildDiscountPopup`(482) — 길드 할인. SA 16, MB구독 3(Left/DiscountTodayChanged/DailyReset), RewardClaimPopupUI 사용.
- `GuildLevelDetailPopup`(313) — 레벨 상세. SA 6, MB구독 3.
- `GuildShopPopup`(298) — 길드 상점. SA 12, **TopCurrencyBoxComponent 유일 사용**, RewardClaimPopupUI, ToastManager.
- `GuildJoinPopup`(281) — 가입/검색. SA 9, MB구독 1(Joined), Show<GuildCreatePopup/GuildHallUI>.
- `GuildGiftDetailPopup`(264) — 선물 상세. SA 9, ResourceManager.LoadResourceAsync<Sprite>.
- `GuildIconChoicePopup`(248) — 아이콘 선택. SA 4.
- `GuildJoinRequestManagementPopup`(240) — 가입신청 관리. SA 6, MB구독 2(JoinTypeChanged/Left).
- `GuildPersonnelOfficeUI`(223) — 인사부. SA 3, MB구독 1(Left), **MessageBroker.PublishSafe(GuildPersonnelOfficeClosedMessage)**.
- `GuildRankingPopup`(206) — 랭킹. SA 3, RankingUserDetailPopup 사용.
- `GuildGiftRewardEffectPopup`(165) — 선물 보상 연출. SA 3.
- `GuildGiftSendConfirmPopup`(149) — 선물 보내기 확인. SA 5.
- `GuildContributionPopup`(108) — 기여. SA 2, MB구독 4(Left/Updated/LevelUp/DailyReset).
- `GuildMissionPopup`(103) — 미션(Quest 탭 컨테이너). SA 2, MB구독 1.

### 비-UIBase 유틸/엔트리
- `GuildUtils`(static, 281) — Show 라우팅 헬퍼(LobbyMainUI/GiftDetail 등), SA 4.
- `GuildEntryRouter`(static, 112) — 진입 라우팅. SA 7.
- `GuildNicknameGate`(static, 38) — 닉네임 게이트. SA 2.
- `GuildPersonnelOfficePresenter`(214, 일반 class) — 인사부 프레젠터. SA 1.
- `GuildGiftRewardEffectAnimRelay`(21, MonoBehaviour) — 애니 이벤트 릴레이.

### Components/ (전부 MonoBehaviour 슬롯/패널)
- `GuildLobbyMemberWanderer`(577) — 로비 멤버 배회 연출(둘째로 큼). SA 1.
- `GuildContributionPanel`(409) — 기여 패널. SA 9, **Geuneda.Services + MainInstaller.Resolve<IMessageBrokerService>**, MB구독 1(DailyDonationChanged).
- `GuildQuestPanel`(401) — 미션 본체. SA 6, **Geuneda.Services + MainInstaller.Resolve**, MB구독 5(ClanQuest* 전부).
- `GuildMemberSlot`(181) — SA 4, ResourceManager.LoadResourceAsync<Sprite>.
- `GuildRentalCandidateSlot`(180) — SA 4.
- `GuildQuestSlot`(151) — RedDotComponent(NodeID=GuildRedDotKeys.MissionQuest).
- `GuildLobbyMemberWanderSlot`(129) — SA 1.
- `GuildShopItemSlot`(118) — SA 1.
- `GuildJoinSlot`(112) — 가입 후보 슬롯.
- `GuildQuestProgressNode`(101) — RedDotComponent(NodeID=GuildRedDotKeys.MissionProgress).
- `GuildRankingSlot`(95), `GuildSearchComponent`(94, SA1), `GuildJoinRequestReviewSlot`(82, SA1), `MinionRentalFlag`(79, SA3), `GuildIcon`(70), `GuildHistorySlot`(48), `GuildQuestRewardPanel`(53), `GuildDiscountParticipantSlot`(47, SA1), `GuildLevelEffectSlot`(37), `GuildGiftClaimerSlot`(33), `GuildGiftSlot`(162), `GuildDiscountRewardSlot`(25).

---

## 3. ServiceAccessor.Get 총합: **198건**
주요 분포: Management 23, LobbyUI 16, DiscountPopup 16, HallUI 15, GiftBoxPopup 13, ShopPopup 12, ContributionPanel 9, GiftDetailPopup 9, JoinPopup 9, EntryRouter 7, QuestPanel 6, CreatePopup 6, LevelDetail 6 등.
조회 대상 매니저: 대부분 `GuildManager`, 그 외 `UIManager`, `ResourceManager`. → 전부 `Managers.Instance.GetManager<T>()`로 치환.

---

## 4. MessageBroker 이벤트 목록 (GameEventType 신규 등록 필요)

### 구독(Subscribe) — 20종
GuildLeftMessage, GuildUpdatedMessage, GuildJoinedMessage, GuildLevelUpMessage,
GuildMemberJoinedMessage, GuildMemberLeftMessage, GuildLeaderChangedMessage,
GuildJoinTypeChangedMessage, GuildDiscountTodayChangedMessage, GuildDailyDonationChangedMessage,
GuildGiftClaimStateChangedMessage, GuildGiftSeasonExpiredMessage,
GuildRaidStatusUpdatedMessage(※Raid연계지만 본 UI에서 구독), DailyResetMessage,
CurrencyChangedEventData,
ClanQuestProgressChangedMessage, ClanQuestClaimedMessage, ClanQuestExpChangedMessage,
ClanQuestProgressTierClaimedMessage, ClanQuestStatusRefreshedMessage

### 발행(Publish) — 1종
GuildPersonnelOfficeClosedMessage (PublishSafe, PersonnelOfficeUI)

> `CurrencyChangedEventData`는 WD에 동등 이벤트 존재 가능성 높음(Phase3 확인). 나머지 Guild*/ClanQuest* 메시지는 신규.
> EventManager 제네릭/단순 테이블 분리 주의(MEMORY: eventmanager_generic_vs_simple). 새 배선은 계열 일치 필수.

---

## 5. 공용 컴포넌트 의존 (TO 존재 여부 플래그)

| 컴포넌트 | FROM 사용 | TO 존재 | 비고 |
|---|---|---|---|
| `RewardClaimPopupUI` | 6파일(Discount/Shop/GiftBox 등) | ✅ `UI/RewardClaimPopupUI.cs` | DIRECT |
| `ServerLoadingPopupUI` | 12파일 | ✅ `UI/ServerLoadingPopupUI.cs` | DIRECT |
| `ToastManager.ShowToast(...)` | 22파일 | ✅ static API 일치 | DIRECT |
| `LocalizationManager` | 22파일 | ✅ | DIRECT |
| `TopCurrencyBoxComponent` | 1파일(ShopPopup) | ✅ `UI/Components/...` | DIRECT |
| `RedDotComponent`(.NodeID) | 3파일(QuestSlot/ProgressNode) | ✅ NodeID API 일치 | DIRECT, 단 `GuildRedDotKeys`는 신규(이번 sync 포함) |
| `LoopGridView` | 22건/여러 슬롯 | ✅ `UI/Components/_InfiniteScroll/_ScrollView/LoopGridView.cs` | DIRECT |
| `RankingUserDetailPopup` | HallUI | ✅ `UI/Ranking/...` | DIRECT |
| `DescriptionPopup` | GiftBoxPopup | ✅ `UI/Popups/DescriptionPopup.cs` | DIRECT |
| `ResourceManager.LoadResourceAsync<Sprite>` | GiftDetail/MemberSlot | ✅(ResourceManager 존재) | API명 Phase3 확인 |

> 거의 모든 공용 컴포넌트가 WD에 존재 → 변환 부담 낮음. 핵심 부담은 DI/이벤트뿐.

---

## 6. 분류 (DIRECT / ADAPTED / PARTIAL)

- **DIRECT (UI 골격 그대로, 변환 거의 없음)**: 슬롯/소형 컴포넌트 다수 —
  GuildDiscountRewardSlot, GuildGiftClaimerSlot, GuildLevelEffectSlot, GuildIcon,
  GuildHistorySlot, GuildQuestRewardPanel, GuildRankingSlot, GuildGiftSlot,
  GuildGiftRewardEffectAnimRelay, MinionRentalFlag, GuildLobbyMemberWanderSlot,
  GuildDiscountParticipantSlot (≈ 12파일)
- **ADAPTED (ServiceAccessor→GetManager + MessageBroker→EventManager 기계적 변환)**: 대다수 —
  루트 팝업 전부(Hall/Lobby/Management/GiftBox/Discount/Shop/Join/Level/Ranking/Contribution/Mission/IconChoice/PersonnelOffice/GiftDetail/GiftSend/GiftRewardEffect), Utils/EntryRouter/NicknameGate/Presenter, 그리고 SA만 쓰는 슬롯(MemberSlot/RentalCandidate/ShopItem/JoinRequestReview/Search/Wanderer) (≈ 31파일)
- **PARTIAL (DI 경로가 다중·재설계 필요)**: **2파일** —
  `GuildContributionPanel`, `GuildQuestPanel` (Geuneda.Services + `MainInstaller.Resolve<IMessageBrokerService>` 인스턴스 DI). WD에 해당 DI 없음 → EventManager 정적 경로로 재배선 + `using Geuneda.Services` 제거 필요.

집계: DIRECT 약 12 / ADAPTED 약 31 / PARTIAL 2.

---

## 7. 주의사항 (Phase3 인계)

1. **ServiceAccessor / MessageBroker / MainInstaller(=VContainer류 DI) 전부 WD 부재** → 변환 인프라가 본 sync의 최대 작업. 198 SA + 38 MB.
2. **MessageBroker.Unsubscribe<T>(this)** owner기반 → WD EventManager는 핸들러기반 `Unsubscribe<T>(GameEventType, handler)`. 단순 치환 불가, 구독 해제부 시그니처 재작성 필요(Cleanup/Closed에서 누락 시 누수).
3. **GameEventType enum 20+종 신규 등록** 필요(§4). ClanQuest* 5종, Guild* 12종, Gift 관련 포함. EventManager 제네릭 vs 단순 테이블 계열 일치 필수.
4. **GuildManager 의존**이 압도적 — Guild 백본(서비스/매니저)이 Phase2 타 영역에서 정상 이식돼야 UI가 컴파일됨(선행의존).
5. `GuildRaidStatusUpdatedMessage`는 Raid 백본 산출물인데 본 UI(추정 LobbyUI/HallUI)에서 구독 → Raid 담당 에이전트 산출물과 enum 공유 조율.
6. `GuildRedDotKeys`(RedDot 키 헬퍼)는 이번 sync 신규 의존 — Guild 코어와 함께 이식 확인.
7. `ResourceManager.LoadResourceAsync<Sprite>` 정확한 메서드명/시그니처 WD 측 확인(CLAUDE.md: `ResourceManager.LoadResource<T>()` 권장 표기와 다를 수 있음).
8. `CurrencyChangedEventData`는 WD에 동등 이벤트가 이미 있을 가능성 → 신규 대신 기존 매핑 검토.
