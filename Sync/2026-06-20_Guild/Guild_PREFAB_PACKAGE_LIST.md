# Guild 프리팹 패키지 목록 (Phase 5-A)

- 시스템: Guild (KEYS: Guild, Clan)
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 범위: META UI 프리팹만 (가입/관리/레벨/상점/기부/버프/선물/할인/미션/채팅/로비/홀/랭킹/인력사무소). 레이드 프리팹 제외 (2차).
- 생성일: 2026-06-20

## 0. 핵심 결론 요약

- 재귀 스캔 결과 길드 META 프리팹 **44개** (엔트리 18 + 중첩 슬롯 26). 전부 **신규 복사** (TO에 길드 프리팹 0개).
- 외부 공유 의존 프리팹 9개 중 **7개는 TO에 이미 존재(GUID 일치)** → ⬛ 스킵. **2개(Marine_Mini_UI, Gacha_Box)는 TO에 없음** → GUID 참조복구 위험.
- **결정적 경로 차이**: BD는 `Assets/Resources/UI/`, WD는 `Assets/Resources_moved/UI/` + Addressables. 엔트리 팝업 18개는 반드시 `Resources_moved/UI/`에 배치하고 Addressable 등록 필요.
- `ItemDisplayComponent`, `MinionDisplayIcon`, `GuildContributionPanel`, `GuildQuestPanel`, `GuildChatPanel`, `GuildLobbyMemberWanderer`는 **독립 프리팹이 아니라 부모 팝업에 임베드된 GameObject** → 별도 복사 대상 아님(부모 프리팹에 포함되어 따라옴).
- META 코드는 포팅 완료(컴파일 그린). BottomTabHUD 길드 탭 코드도 이미 배선됨(`GuildEntryRouter.EnterAsync`).

---

## 1. sync할 프리팹 목록 (의존성 순: leaf → root)

상태 범례: 🆕 신규 복사 / ⬛ 스킵(TO 존재·동일) / ⚠️ 업데이트 / 🔵 수동판단
FROM 경로 접두사: `/tmp/sync_Guild_1781924940/Assets/`

### 1-A. 공통/리프 슬롯 (먼저 복사)

| 순서 | 파일명 | 상태 | FROM경로 | TO처리 |
|---|---|---|---|---|
| 1 | GuildIcon.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Common/GuildIcon.prefab` | `_Project/3_Prefabs/UI/Guild/Common/` 신규 |
| 2 | Slider_Progress.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Slider_Progress.prefab` | `_Project/3_Prefabs/UI/Guild/` 신규 |
| 3 | GuildHistorySlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildHistorySlot.prefab` | 신규 (※코드 GuildHistorySlot 존재) |

### 1-B. 채팅 슬롯 (LobbyUI 의존)

| 순서 | 파일명 | 상태 | FROM경로 | TO처리 |
|---|---|---|---|---|
| 4 | GuildChatSlot_Date.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 5 | GuildChatSlot_Mine.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 6 | GuildChatSlot_Other.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 7 | GuildChatSlot_System.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 8 | GuildChatSlot_LeaderDm.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 9 | GuildChatSlot_Gift_Mine.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |
| 10 | GuildChatSlot_Gift_Other.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Chat/` | 신규 |

### 1-C. 기능별 슬롯/서브슬롯

| 순서 | 파일명 | 상태 | FROM경로 | TO처리 |
|---|---|---|---|---|
| 11 | GuildMemberSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Hall/` | 신규 |
| 12 | GuildJoinRequestReviewSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Hall/` | 신규 |
| 13 | GuildLevelEffectSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Hall/` | 신규 |
| 14 | WanderSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Hall/` | 신규 (코드: GuildLobbyMemberWanderSlot) |
| 15 | GuildJoinSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildJoinSlot.prefab` | 신규 |
| 16 | GuildSearch.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildSearch.prefab` | 신규 (코드: GuildSearchComponent) |
| 17 | GuildRankingSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildRankingSlot.prefab` | 신규 (GuildIcon 중첩) |
| 18 | GuildShopItemSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildShopItemSlot.prefab` | 신규 |
| 19 | GuildRentalCandidateSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildRentalCandidateSlot.prefab` | 신규 (MinionDisplayIcon 참조) |
| 20 | GuildGiftClaimerSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildGiftClaimerSlot.prefab` | 신규 |
| 21 | GuildQuestSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildMission/` | 신규 (Slider_Progress 중첩) |
| 22 | GuildTreasure.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/GuildMission/` | 신규 (코드: GuildQuestProgressNode) |
| 23 | GuildDiscountSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Discount/` | 신규 (코드: GuildDiscountRewardSlot) |
| 24 | GuildDiscountParticipantSlot.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Discount/` | 신규 |
| 25 | Btn_ClosedBox.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Gift/` | 신규 (GiftBox 내부, 코드: GuildGiftSlot) |
| 26 | SentClaimed.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Gift/` | 신규 (GuildGiftSlot 변형) |
| 27 | SentNoClaimed.prefab | 🆕 | `_Project/3_Prefabs/UI/Guild/Gift/` | 신규 (GuildGiftSlot 변형) |

### 1-D. 엔트리 팝업/스크린 (root, 마지막 복사) — TO는 `Resources_moved/UI/`

| 순서 | 파일명 | 상태 | FROM경로 | TO처리 |
|---|---|---|---|---|
| 28 | GuildIconChoicePopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 29 | GuildSearch 의존 GuildJoinPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 30 | GuildCreatePopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 31 | GuildManagementPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 32 | GuildJoinRequestManagementPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 33 | GuildHallUI.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 34 | GuildRankingPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 35 | GuildLevelDetailPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 36 | GuildContributionPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 37 | GuildMissionPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 38 | GuildDiscountPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 39 | GuildShopPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 40 | GuildPersonnelOfficeUI.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 41 | GuildGiftBoxPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 42 | GuildGiftDetailPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 43 | GuildGiftSendConfirmPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 44 | GuildGiftRewardEffectPopup.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable |
| 45 | GuildLobbyUI.prefab | 🆕 | `Resources/UI/` | `Resources_moved/UI/` + Addressable (채팅7+WanderSlot 중첩, LobbyChatUI/GuildChatPanel/Wanderer 임베드) |

> 임베드(독립 프리팹 아님, 부모에 포함): `GuildContributionPanel`(→Contribution팝업), `GuildQuestPanel`(→Mission팝업/Hall), `GuildChatPanel`·`LobbyChatUI`·`GuildLobbyMemberWanderer`·`GuildQuestRewardPanel`·`ItemDisplayComponent`·`MinionDisplayIcon`·`TopBox`. 별도 복사 불필요 — 부모 프리팹 복사 시 함께 직렬화됨.

### 1-E. 외부 공유 의존 프리팹 (길드 프리팹이 참조, 신규 아님)

| 파일명 | 상태 | TO경로 / 비고 |
|---|---|---|
| RedDotComponent.prefab | ⬛ 스킵 | `Resources_moved/Prefabs/UI/` GUID 일치 |
| Reddot.prefab | ⬛ 스킵 | `Resources_moved/Prefabs/UI/` GUID 일치 |
| PlayerInfoHUD.prefab | ⬛ 스킵 | `Resources_moved/UI/` GUID 일치 |
| TopCurrencyBoxComponent.prefab | ⬛ 스킵 | `_Project/3_Prefabs/UI/Parts/` GUID 일치 |
| TopBox.prefab | ⬛ 스킵 | `_Project/3_Prefabs/UI/_Common/` GUID 일치 |
| Button - BackgroundClose.prefab | ⬛ 스킵 | `_Project/3_Prefabs/UI/Buttons/` GUID 일치 |
| Button - ItemDisplayPrefab.prefab | ⬛ 스킵 | `_Project/3_Prefabs/UI/Buttons/` GUID 일치 |
| **Marine_Mini_UI.prefab** | 🔴 누락 | TO에 없음 → 참조복구 위험 (5b) |
| **Gacha_Box.prefab** | 🔴 누락 | TO에 없음 (FROM: `_Project/3_Prefabs/UI/Event/InfinityCraft/`) → 참조복구 위험 (5b) |

---

## 2. 프리팹별 SerializeField 연결 목록 (임포트 후 수동 와이어링 체크리스트)

> 슬롯/컴포넌트 타입 필드(중첩 프리팹·임베드)는 ★ 표기. 임포트 후 인스펙터에서 끊긴 참조 우선 확인.
> `GetPool<T>()` 사용 0건 — 슬롯 스폰은 SerializeField 프리팹 + Instantiate, 채팅은 LoopGridView.

### 엔트리 팝업/스크린

**GuildContributionPopup** ─ ★GuildContributionPanel `_contributionPanel`, ★GuildIcon `_guildIcon`, Button `_closeButton`/`_backgroundButton`, TextMeshProUGUI `_levelText`/`_expText`, Slider `_expSlider`

**GuildCreatePopup** ─ ★GuildIcon `_guildIcon`, TMP_InputField `_nameInput`/`_introInput`/`_noticeInput`, TextMeshProUGUI `_nameValidationText`/`_costText`, Toggle `_joinTypeToggle`, Button `_createButton`/`_closeButton`/`_backGroundCloseButton`

**GuildDiscountPopup** ─ ★GuildDiscountRewardSlot `_rewardSlotPrefab`, ★GuildDiscountParticipantSlot `_participantSlotPrefab`, TextMeshProUGUI `_resetTimerText`/`_originalPriceText`/`_discountedPriceText`/`_participantCountText`/`_actionButtonText`, RectTransform `_rewardContent`/`_participantRoot`, GameObject `_discountedPriceRoot`/`_badgeObject`/`_actionButtonDim`, Button `_actionButton`/`_closeButton`

**GuildGiftBoxPopup** ─ ★GuildGiftSlot `_pendingSlotPrefab`/`_sentSlotPrefab`/`_sentSlotUnclaimedPrefab`, RectTransform `_pendingRoot`/`_sentRoot`, GameObject `_sendSlotEmpty`, Button `_claimAllButton`/`_closeButton`/`_backgroundButton`/`_resetTimerInfoButton`, TextMeshProUGUI `_resetTimerText`

**GuildGiftDetailPopup** ─ ★GuildGiftClaimerSlot `_claimerSlotPrefab`, Image `_gradeBoxImage`/`_senderIconImage`/`_senderFrameImage`, Sprite `_epicBoxSprite`/`_legendaryBoxSprite`/`_mythicBoxSprite`, TextMeshProUGUI `_senderNickText`/`_myClaimedAmountText`/`_claimersProgressText`/`_amountProgressText`, RectTransform `_claimerRoot`, Button `_closeButton`/`_backgroundButton`

**GuildGiftRewardEffectPopup** ─ Image `_boxTopImage`/`_boxBottomImage`/`_lockImage`, List&lt;GradeVfxEntry&gt; `_gradeVfx`, Animator `_effectAnimator` (※런타임 구동, controller 에셋 참조 없음)
  - 동반 릴레이 **GuildGiftRewardEffectAnimRelay**: ★GuildGiftRewardEffectPopup `_popup`

**GuildGiftSendConfirmPopup** ─ Image `_boxImage`/`_rewardCurrencyImage`, TextMeshProUGUI `_rewardAmountText`/`_maxClaimersText`, Button `_sendButton`/`_closeButton`/`_backgroundButton`

**GuildHallUI** ─ ★GuildIcon `_flagIcon`, ★GuildMemberSlot `_slotPrefab`, TextMeshProUGUI `_guildName`/`_combatPowerText`/`_introText`/`_levelText`/`_expText`/`_memberCountText`/`_uidText`/`_memberRankButtonText`, Slider `_expSlider`, RectTransform `_slotContent`, GameObject `_emptyLabel`/`_ownerControlsRoot`/`_buffRoot`/`_memberPanel`, Button `_uidCopyButton`/`_managementButton`/`_rankingButton`/`_closeButton`/`_buffButton`/`_bgCloseButton`/`_memberInfoButton`/`_memberKickButton`/`_memberRankButton`

**GuildIconChoicePopup** ─ ★GuildIcon `_iconPrefab`/`_previewIcon`, RectTransform `_content`, Button `_confirmButton`/`_purchaseButton`/`_closeButton`/`_backGroundCloseButton`, TextMeshProUGUI `_costText`

**GuildJoinPopup** ─ ★GuildJoinSlot `_slotPrefab`, ★GuildSearchComponent `_searchComponent`, RectTransform `_slotContent`, Button `_quickJoinButton`/`_createButton`/`_closeButton`

**GuildJoinRequestManagementPopup** ─ ★GuildJoinRequestReviewSlot `_slotPrefab`, RectTransform `_slotContent`, GameObject `_emptyLabel`, Button `_acceptAllButton`/`_rejectAllButton`/`_backgroundCloseButton`/`_closeButton`

**GuildLevelDetailPopup** ─ ★GuildLevelEffectSlot `_slotPrefab`, TextMeshProUGUI `_levelText`/`_expText`/`_pageLevelText`, Slider `_expSlider`, RectTransform `_slotContent`, Button `_prevButton`/`_nextButton`/`_closeButton`/`_backgroundButton`

**GuildLobbyUI** ─ ★GuildChatPanel `_chatPanel`, ★GuildLobbyMemberWanderer `_memberWanderer`, Image `_guildIconImage`, TextMeshProUGUI `_guildNameText`/`_guildLevelText`, RectTransform `_guildChatRoot`, Button `_hallButton`/`_raidButton`/`_missionButton`/`_supplyButton`/`_shopButton`/`_minionCoopButton`/`_chatBackdropButton`/`_closeButton`
  - ※ `_raidButton`은 레이드(2차) 진입 — META 임포트 단계에선 비활성/숨김 권장

**GuildManagementPopup** ─ ★GuildIcon `_guildIcon`, TextMeshProUGUI `_guildUidText`, TMP_InputField `_nameInput`/`_noticeInput`/`_introInput`, Toggle `_freeJoinToggle`, GameObject `_guildIconChangeIndicator`/`_joinTypeSection`, Button `_guildUidCopyButton`/`_nameEditButton`/`_noticeEditButton`/`_introEditButton`/`_joinRequestManagementButton`/`_leaveButton`/`_closeButton`/`_backgroundButton`

**GuildMissionPopup** ─ ★GuildQuestPanel `_questPanel`, Button `_openContributionButton`/`_closeButton`/`_backGroundCloseButton`

**GuildPersonnelOfficeUI** ─ ★GuildRentalCandidateSlot `_slotPrefab`, RectTransform `_slotContent`, TextMeshProUGUI `_rentalCountText`, GameObject `_emptyLabel`/`_loadingIndicator`/`_moveToLobbyDimOverlay`, Button `_closeButton`/`_moveToLobbyButton`

**GuildRankingPopup** ─ ★GuildIcon `_firstFlagIcon`/`_secondFlagIcon`/`_thirdFlagIcon`, ★GuildRankingSlot `_restSlotPrefab`/`_myGuildSlot`, TextMeshProUGUI `_first/_second/_third NameText`·`CombatPowerText`, RectTransform `_restListContent`, Button `_firstButton`/`_secondButton`/`_thirdButton`/`_closeButton`/`_backgroundCloseButton`

**GuildShopPopup** ─ ★TopCurrencyBoxComponent `_topCurrencyBox`, ★GuildShopItemSlot `_slotPrefab`, RectTransform `_slotContent`, GameObject `_loadingOverlay`, Button `_closeButton`

### 임베드 패널 (부모 프리팹 안에서 와이어링)

**GuildContributionPanel** ─ ItemDisplayComponent `_itemDisplayPrefab`, RectTransform `_slotContent`, Button `_freeButton`/`_adButton`/`_gemButton`, GameObject `_adDimObject`/`_allRewardsClaimedObject`, TextMeshProUGUI `_adCountdownText`/`_gemCostText`

**GuildQuestPanel** ─ ★GuildQuestProgressNode `_progressNodePrefab`, ★GuildQuestSlot `_slotPrefab`, ★GuildQuestRewardPanel `_rewardPanel`, Slider `_progressSlider`, RectTransform `_progressNodeContent`/`_slotContent`

**GuildQuestRewardPanel** ─ ItemDisplayComponent `_rewardSlot1`/`_rewardSlot2`, Button `_backdropButton`

**GuildChatPanel** ─ ★LobbyChatUI `_lobbyChatUI`, LoopGridView `_loopGridView`, TMP_InputField `_inputField`, GameObject `_chatInputRoot`/`_topBox`/`_loadingMoreIndicator`, Button `_sendButton`/`_giftButton`/`_chatPanelCloseButton`/`_jumpToBottomButton`, Toggle `_lockToggle`

**LobbyChatUI** ─ TextMeshProUGUI `_previewText`, Button `_expandButton`

**GuildLobbyMemberWanderer** ─ ★GuildLobbyMemberWanderSlot `_slotPrefab`, RectTransform `_wanderArea`/`_obstacles[]`/`_spawnPoint`/`_shopFrontPoint`, Animator `_shopDoorAnimator`, + 다수 float 튜닝값(`_maxSpeed`/`_maxForce`/`_arrivalDistance`/`_avoidRadius`/`_idleDuration*`/`_shopInsideDuration*` 등)

### 슬롯 컴포넌트 (각 슬롯 프리팹 루트)

**GuildIcon** ─ Image `_iconImage`, GameObject `_selectOverlay`, Button `_button`
**GuildMemberSlot** ─ Image `_backgroundImage`/`_profileIconImage`/`_profileBorderImage`/`_onlineStatusImage`, Sprite `_normal/_mySelf BackgroundSprite`·`_online/_offline Sprite`, TextMeshProUGUI `_nickText`/`_levelText`/`_combatPowerText`/`_lastActiveText`, GameObject `_leaderIcon`, Button `_slotButton`, RectTransform `_panelAnchor`
**GuildJoinSlot** ─ Image `_flagImage`/`_actionButtonImage`, TextMeshProUGUI `_nameText`/`_levelText`/`_leaderNickText`/`_memberCountText`/`_actionLabel`, Sprite `_applySprite`/`_cancelSprite`, Button `_actionButton`/`_showDetailButton`
**GuildJoinRequestReviewSlot** ─ Image `_profileIconImage`/`_profileBorderImage`, TextMeshProUGUI `_nickText`, Button `_detailButton`/`_acceptButton`/`_rejectButton`
**GuildRankingSlot** ─ ★GuildIcon `_flagIcon`, Image `_rankIconImage`, Sprite `_rank1/_rank2/_rank3 Sprite`, TextMeshProUGUI `_rankText`/`_nameText`/`_combatPowerText`, Button `_button`
**GuildShopItemSlot** ─ ItemDisplayComponent `_rewardDisplay`, TextMeshProUGUI `_rewardNameText`/`_remainCountText`/`_costAmountText`, Button `_buyButton`, GameObject `_soldOutOverlay`
**GuildRentalCandidateSlot** ─ Image `_profileIconImage`/`_profileBorderImage`, TextMeshProUGUI `_nickText`/`_combatPowerText`, GameObject `_selectedHighlight`/`_alreadyRentedLockOverlay`, MinionDisplayIcon[] `_minionIcons`, Button `_slotButton`/`_detailButton`
**GuildGiftClaimerSlot** ─ Image `_profileIconImage`/`_profileBorderImage`, TextMeshProUGUI `_nickText`/`_amountText`
**GuildGiftSlot** (Btn_ClosedBox/SentClaimed/SentNoClaimed) ─ Image `_boxImage`, TMP_Text `_statusText`, Button `_slotButton`
**GuildLevelEffectSlot** ─ TextMeshProUGUI `_buffDescText`, string `_numberColorHex`
**GuildQuestSlot** ─ ItemDisplayComponent `_reward1Display`/`_reward2Display`, RedDotComponent `_actionRedDot`, Slider `_progressSlider`, TextMeshProUGUI `_descText`/`_progressText`/`_actionLabel`, Button `_actionButton`, GameObject `_claimedOverlay`, Image `_backgroundImage`, Sprite `_normal/_claimable BackgroundSprite`
**GuildQuestProgressNode** (GuildTreasure) ─ RedDotComponent `_clickRedDot`, TextMeshProUGUI `_requiredExpText`, Button `_clickButton`, Image `_boxImage`, Sprite `_normalClosed/_normalOpened/_specialClosed/_specialOpened`, GameObject `_claimableVfx`
**GuildDiscountRewardSlot** (GuildDiscountSlot) ─ ItemDisplayComponent `_itemDisplay`
**GuildDiscountParticipantSlot** ─ TextMeshProUGUI `_nickText`/`_discountText`
**GuildSearchComponent** (GuildSearch) ─ TMP_InputField `_searchInput`, Button `_searchButton`
**GuildLobbyMemberWanderSlot** (WanderSlot) ─ RectTransform `_characterRoot`, Animator `_animator`, TextMeshProUGUI `_nicknameText`, Color `_otherMemberColor`/`_myselfColor`, bool `_defaultFacingLeft`
**GuildHistorySlot** ─ TextMeshProUGUI `_messageText`/`_timeText`
**MinionRentalFlag** ─ Image `_profileIcon`/`_profileBorder`, TextMeshProUGUI `_label`, Sprite `_availableIconSprite`/`_availableBorderSprite`

### 채팅 슬롯 (LoopGridViewItem)

| 슬롯 | 필드 |
|---|---|
| GuildChatMineSlot / OtherSlot / LeaderDmSlot | Image `_profileIconImage`/`_profileFrameImage`, TextMeshProUGUI `_nickText`/`_messageText`/`_relativeTimeText` |
| GuildChatSystemSlot | TextMeshProUGUI `_text` |
| GuildChatDateSeparatorSlot | TextMeshProUGUI `_dateText` |
| GuildChatGiftSlot | Image `_profileIconImage`/`_profileFrameImage`/`_backgroundImage`/`_arrowImage`, TextMeshProUGUI `_nickText`/`_giftNameText`/`_sentTimeText`/`_expireRemainingText`, GameObject `_expiredLabel`/`_dimOverlay`, Button `_claimButton`/`_claimedDetailButton` |

---

## 3. Show&lt;T&gt;/IsOpened&lt;T&gt; 외부 UI 참조 확인

| 호출위치 | 대상 | TO존재 | 처리 |
|---|---|---|---|
| GuildDiscountPopup, GuildGiftBoxPopup, GuildShopPopup, GuildContributionPanel, GuildQuestPanel | RewardClaimPopupUI | ✅ `Resources_moved/UI/` | ⬛ 스킵 |
| GuildHallUI, GuildJoinRequestReviewSlot, GuildRentalCandidateSlot | RankingUserDetailPopup | ✅ `Resources_moved/UI/` | ⬛ 스킵 |
| GuildEntryRouter, GuildJoinPopup, GuildManagementPopup, GuildPersonnelOfficeUI, GuildUtils | BottomTabHUD (IsOpened) | ✅ `Resources_moved/UI/` | ⬛ 스킵 (코드 배선됨) |
| GuildGiftBoxPopup | DescriptionPopup | ✅ `Resources_moved/UI/` | ⬛ 스킵 |
| GuildNicknameGate | NicknameChangePopupUI | ✅ `Resources_moved/UI/` | ⬛ 스킵 |
| GuildUtils | LobbyMainUI | ✅ `Resources_moved/UI/` | ⬛ 스킵 |
| 길드 내부 팝업 상호 호출 (Lobby→Hall/Mission/Shop/Discount/PersonnelOffice, Hall→Management/Ranking/Level, Gift 체인 등) | 길드 META 팝업 | 🆕 (본 목록 28~45) | 신규 임포트 후 Addressable 등록 필요 |
| GuildLobbyUI (주석처리) | GuildRaidLobbyUI | 🔵 레이드(2차) | META 단계 보류 |

---

## 4. 임포트 후 UIManager/Resources 등록 필요 목록

WD는 `Show<T>()` 시 `ResourceManager.LoadResource<GameObject>($"UI/{TypeName}")` → Addressables `Assets/Resources_moved/UI/{TypeName}.prefab` 로 해석. 아래 18개 엔트리 프리팹은 해당 경로에 배치 + Addressable 등록 필수 (파일명 = 클래스명).

```
Assets/Resources_moved/UI/GuildLobbyUI.prefab
Assets/Resources_moved/UI/GuildHallUI.prefab
Assets/Resources_moved/UI/GuildJoinPopup.prefab
Assets/Resources_moved/UI/GuildCreatePopup.prefab
Assets/Resources_moved/UI/GuildIconChoicePopup.prefab
Assets/Resources_moved/UI/GuildManagementPopup.prefab
Assets/Resources_moved/UI/GuildJoinRequestManagementPopup.prefab
Assets/Resources_moved/UI/GuildRankingPopup.prefab
Assets/Resources_moved/UI/GuildLevelDetailPopup.prefab
Assets/Resources_moved/UI/GuildContributionPopup.prefab
Assets/Resources_moved/UI/GuildMissionPopup.prefab
Assets/Resources_moved/UI/GuildDiscountPopup.prefab
Assets/Resources_moved/UI/GuildShopPopup.prefab
Assets/Resources_moved/UI/GuildPersonnelOfficeUI.prefab
Assets/Resources_moved/UI/GuildGiftBoxPopup.prefab
Assets/Resources_moved/UI/GuildGiftDetailPopup.prefab
Assets/Resources_moved/UI/GuildGiftSendConfirmPopup.prefab
Assets/Resources_moved/UI/GuildGiftRewardEffectPopup.prefab
```

> 슬롯 프리팹(27개)은 SerializeField 직접 참조라 Addressable 등록 불필요 — `_Project/3_Prefabs/UI/Guild/` 하위에 BD와 동일 구조로 배치만 하면 됨.
> Addressables 그룹 파일 직접 편집 금지 — Importer/에디터에 위임 (메모리 규칙).

---

## 5. 동반 에셋 인벤토리 (복사 대상, 본 단계에선 목록만)

| 분류 | 위치(FROM) | 수량/내용 | 비고 |
|---|---|---|---|
| 텍스처 | `_Project/6_Textures/Guild/` | **159개** (서브: BackGround/Rental/Chat(+GiftBox)/Shop/Discount/Mission/Create/Hall) | Raid 폴더 제외 |
| UI 애니메이션 (clip) | `_Project/4_Animations/UI/` | GuildLobbyUI_GuildHall/Mission/Network/Shop/Shop_idle/**Raid** (.anim 6개) | Raid clip은 로비 탭 연출용이라 동반 필요 |
| UI 애니메이터 (controller) | `_Project/4_Animations/UI/` | GuildHall_Anim / GuildMission_Anim / GuildNetwork_Anim / GuildRaid_Anim / GuildShop_Anim (.controller 5개) | GuildLobbyUI가 참조 |
| SO 데이터 에셋 | `Resources/CustomSO/Guild/ClanGiftIconConfig.asset` | 1개 (선물 아이콘 매핑) | ClanGiftIconConfigSO.cs 이미 TO 존재(GUID 일치). TO 배치경로: `Resources/CustomSO/Guild/` 또는 `Resources_moved/CustomSO/Guild/` 결정 필요 |
| 스프라이트 | `Resources/Sprites/Clan/icon_lobby_guild.png` | 1개 | **이미 TO 존재(GUID 4a925ac… 일치)** → ⬛ 스킵 |
| (레이드 SO) | `_Project/11_SO/Guild/GuildBossUIPrefabRegistry.asset`, `GuildRaidEntranceConfig.asset` | 2개 | 🔵 레이드 2차 보류 |

### 🔴 GUID 참조복구 위험 항목 (Phase 5b 처리)

1. **Marine_Mini_UI.prefab** — 길드 프리팹이 참조하나 TO에 없음. 임포트 시 Missing Prefab. → 별도 이식 또는 WD 대체 캐릭터 미니UI로 리매핑 필요.
2. **Gacha_Box.prefab** — FROM `InfinityCraft/` 소속, TO에 없음. 선물/상자 연출에서 참조. → 이식 여부 결정 필요.
3. **ClanGiftIconConfig.asset 내부 currency/아이콘 GUID** — BD 아이콘/재화 스프라이트 GUID로 직렬화돼 있을 수 있음. WD 공유 스프라이트와 GUID 불일치 시 깨짐 → 임포트 후 검수.
4. **길드 프리팹의 폰트/재화아이콘 공유에셋 BD GUID 참조** — 엔트리/슬롯 프리팹이 BD 폰트(Aggro 등)·재화 아이콘을 BD GUID로 참조. WD에서 동일 GUID면 OK, 아니면 5b에서 리바인드. 서브에이전트 스캔 시 `/tmp` 슬라이스 밖으로 미해석된 `type:3` GUID 다수 확인됨 → 임포트 후 Missing 핑크 일괄 점검 필수.

---

## 6. 레이드 2차 보류 프리팹 목록 (분석 제외, 이름만)

- 씬: `GuildBossScene.unity`
- Resources/UI: `GuildRaidLobbyUI`, `GuildRaidQuestPopup`, `GuildRaidRankingPopup`
- 슬롯(`_Project/3_Prefabs/UI/Guild/Raid/`): `GuildRaidGuildRankingSlot`, `GuildRaidMemberRankingSlot`, `GuildRaidQuestSlot`, `GuildRaidTop3RankingSlot`
- 보스/몬스터: `guild_monster_bull.prefab`, `Guild_Boss_50101_Back_Anim.prefab`, StellaBoss 계열
- SO: `_Project/11_SO/Guild/GuildBossUIPrefabRegistry.asset`, `GuildRaidEntranceConfig.asset`
- 텍스처: `_Project/6_Textures/Guild/Raid/`, `6_Textures/Enemy/GuildRaid/`, `6_Textures/InGameBackground/GuildBoss/`
- 애니: `4_Animations/Enemy/Boss/Guild_Boss_Back_Anim.anim`, `Guild_Monster_Bull_*` (3개)
- 참고: GuildLobbyUI `_raidButton` + `GuildLobbyUI_GuildRaid` 탭 연출은 META 로비에 존재하나, 진입(`Show<GuildRaidLobbyUI>`)은 코드상 주석처리 → META 단계에선 버튼 비활성/숨김.

---

## 7. 🟧 사용자/에디터 작업 요약

1. **프리팹 임포트** (의존성 순 1→45)
   - 슬롯 27개 → `_Project/3_Prefabs/UI/Guild/` BD 동일 구조 신규 배치
   - 엔트리 18개 → `Resources_moved/UI/` 배치 + Addressable 등록 (파일명=클래스명 유지)
   - 임포트 직후 Missing(핑크) 스크립트/프리팹/스프라이트 일괄 점검
2. **SerializeField 연결** — §2 체크리스트. ★ 표기(중첩 슬롯/임베드 패널) 우선. GuildLobbyUI/Hall/Mission/Gift 체인이 필드 최다.
3. **누락 공유 프리팹 처리 (5b)** — Marine_Mini_UI, Gacha_Box 이식 또는 WD 대체 리바인드. ClanGiftIconConfig.asset 내부 GUID 검수.
4. **BottomTabHUD Guild 탭** — 코드(`EBottomTabType.Guild`→`GuildEntryRouter.EnterAsync`)는 배선 완료. **BottomTabHUD.prefab에 Guild 탭 버튼 GameObject + 아이콘(icon_lobby_guild, 이미 존재) + 해금 게이팅(25레벨, UI_Guild) 와이어링** 추가 필요.
5. **동반 에셋 복사** — 6_Textures/Guild 159개, UI anim clip 6 + controller 5, ClanGiftIconConfig.asset. icon_lobby_guild.png는 스킵(존재).
6. **DataSheet 차팅** — 길드 META 데이터 테이블(상점/할인/미션/레벨버프/기부 등) 구글시트 차팅 여부 별도 확인(본 Phase 범위 외, 코드 포팅 시 소비처 확인 권장).
7. **로컬라이즈** — `guild_loading`, `guild_require_level_25` 등 길드 로컬라이즈 키 등록 확인.

---

## 부록: 통계

- 재귀 스캔 길드 META 프리팹: **44** (엔트리 18 + 중첩 27 ※GuildHistorySlot 포함 시 / 핵심 슬롯 26)
  - 신규 복사: 44 (전부) / 업데이트: 0 / 스킵: 0(길드) / 수동판단: 0
- 외부 공유 의존 프리팹: 9 → 스킵 7, 누락(위험) 2
- SerializeField 연결 필요 프리팹/패널: **약 40개** (엔트리 18 + 슬롯/패널 22)
- GUID 참조복구 위험 항목: **4** (Marine_Mini_UI, Gacha_Box, ClanGiftIconConfig 내부, 폰트/재화 공유에셋 BD GUID)
- 레이드 2차 보류: 프리팹 7 + 씬 1 + 보스/몬스터 3 + SO 2 + 텍스처/애니 다수
