# Guild 프리팹 SYNC 리포트 (Phase 5-B: 잔여 GUID 참조복구)

- 생성일: 2026-06-20
- FROM: `/tmp/sync_Guild_1781924940` (BunkerDefense, READ ONLY)
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 작업 범위: Stage 1(벌크 복사, .meta GUID 보존) 이후 잔여 미해결 GUID 정리 + 누락 길드 에셋 복사 + LocalizeStringEvent 검증 + Unity 검증

---

## 1. 처리 프리팹 수

- 복사된 길드 프리팹 총 **52개** 중, 레이드(`GuildRaid*`) 프리팹 **7개**는 제약에 따라 **제외** → 실제 작업 대상 **META 프리팹 45개**.
  - 엔트리 팝업(Resources_moved/UI): 18개 (레이드 3개 제외)
  - 중첩 슬롯(_Project/3_Prefabs/UI/Guild/**): 27개 (레이드 4개 제외)
- 추출/중복제거한 마스터 GUID 집합(META 45개 기준): **298개**
  - Unity 빌트인: 1, TO/Assets 해석됨: 다수, PackageCache 해석됨: 22
  - 초기 미해결: 14 → 처리 후 **2** (아래)

> 참고: 레이드 프리팹 7개가 동봉되며 끌고 온 미해결 GUID(레이드 스크립트 10종, GuildRaid 보스 텍스처·머티리얼 등)는 레이드 2차 범위라 본 작업에서 처리하지 않음. 단 GuildRaid_Anim.controller / Glitch_Earth.mat / monster_virus_boss_crown 은 **META 프리팹(GuildLobbyUI, LeaderDm 채팅슬롯)** 이 직접 참조하므로 복사함(아래 case-b).

---

## 2. GUID 리맵 내역 (case-a 공유에셋 불일치)

| 에셋 | from GUID → to GUID | 영향 프리팹 수 |
|---|---|---|
| Gem_Icon SpriteAsset (`Gem_Icon.asset` → WD `gem_icon.asset`) | `355580013d7214845ab763d9c0b6a691` → `4856e33789068654aa9de43b7f6ec257` | **9** |

영향 프리팹: GuildContributionPopup, GuildGiftDetailPopup, GuildHallUI, GuildLevelDetailPopup, GuildMissionPopup, GuildPersonnelOfficeUI, GuildShopItemSlot, GuildChatSlot_Gift_Mine, GuildChatSlot_Gift_Other (TMP `m_spriteAsset` 참조, 총 82개 LocalizeStringEvent의 `<sprite>` 인라인용 젬 아이콘).

- 적용 후 FROM-guid 잔존 0 확인, TO-guid 정상 치환 확인.

---

## 3. 신규 복사 에셋 (case-b, 길드 소유 · GUID 보존하여 자동해석)

총 **20개 파일**(에셋 13 + .meta 동봉). 모두 FROM과 동일 상대경로(미러)로 복사, .meta 보존:

| 분류 | 에셋 | TO 경로 |
|---|---|---|
| 애니메이터 컨트롤러 (5) | GuildShop_Anim / GuildMission_Anim / GuildRaid_Anim / GuildHall_Anim / GuildNetwork_Anim `.controller` | `Assets/_Project/4_Animations/UI/` |
| 애니 클립 (6) | GuildLobbyUI_GuildShop / _GuildShop_idle / _GuildMission / _GuildRaid / _GuildHall / _GuildNetwork `.anim` | `Assets/_Project/4_Animations/UI/` |
| 머티리얼 (1) | Glitch_Earth.mat | `Assets/_Project/7_VFX/Shader/` |
| 셰이더 (1) | Glitch_Earth.shader | `Assets/Marine/Shader/` |
| 텍스처 (2) | GuildLobby_Earth.tga, monster_virus_boss_crown.png | `Assets/Marine/SpriteTexture/` |
| 스프라이트 (5) | icon_guild_1.png, icon_guild_2.png | `Assets/Resources_moved/Sprites/Clan/Flags/` |
|  | icon_gacha_box.png, icon_gacha_redbox.png, icon_guild_currency.png | `Assets/Resources_moved/Sprites/Currency/Guild/` |

- BD `Resources/Sprites/Clan|Currency` → WD `Resources_moved/Sprites/Clan|Currency` 매핑 적용.
- `Marine/` 최상위 경로는 WD에서도 동일 유지(Resources 아님).
- Glitch_Earth.mat의 dust_tile(`7e410ec5…`) 의존은 TO에 이미 동일 GUID로 존재 → 자동해석.

---

## 4. LocalizeStringEvent 처리

- META 프리팹의 LocalizeStringEvent `m_TableCollectionName` 참조: 전부 **`GUID:b70af4818baaa49728f7235359d344b6`** (82건).
- 해당 GUID = `LocalizationTables Shared Data.asset` → **FROM과 TO가 동일 GUID** → **테이블 컬렉션 리맵 불필요(무조치)**.
- m_KeyId 점검: 길드 프리팹이 쓰는 distinct KeyId **62개** 중 **61개가 TO 로컬라이즈 Shared Data에 미존재**(WD 로컬라이즈 차팅 미반영). 그중 58개는 FROM Shared Data에 존재 확인 → 실재하는 길드 키. ⚠️ 누락 로컬라이즈 키 섹션 참조.

---

## 5. ⚠️ 미해결 GUID (2건 — 비-길드 공유 프리팹, 에디터 판단 필요)

날조하지 않고 그대로 보고. 둘 다 **길드 소유가 아닌 공유 프리팹**으로, 자체 의존 트리(캐릭터/가챠연출)가 커서 단순 복사 시 추가 누수 위험 → 이식 vs WD 대체 리바인드 판단 필요(Phase 5b 위험항목 #1, #2).

| GUID | FROM 에셋 | 참조하는 META 프리팹 | 증상 |
|---|---|---|---|
| `0da5451b684074ba39711dd4a9d5decc` | `_Project/3_Prefabs/UI/Event/InfinityCraft/Gacha_Box.prefab` | GuildGiftRewardEffectPopup.prefab | Missing Prefab (선물 박스 오픈 연출) |
| `9e78102ec8a4c4a57a94d3f9fe04daec` | `_Project/3_Prefabs/UI/Character/Marine_Mini_UI.prefab` | Hall/WanderSlot.prefab | Missing Prefab (로비 배회 멤버 캐릭터 미니UI) |

---

## 6. ⚠️ 누락 로컬라이즈 키 (61건 — WD 차팅 미반영)

LocalizeStringEvent는 키 폴백으로 표시되며 프리팹 깨짐은 아님(비블로킹). WD 구글시트 로컬라이즈 차팅에 길드 키 등록 필요. 샘플(키명):
`clan_lobby_raid`, `GUILD_DONATION_LIMIT_EXCEEDED_TITLE`, `gulid_gift_luckyopen`, `guild_raid_wait_text`, `shop_ark_module_select_done` 외.

전체 누락 KeyId 목록은 `/tmp/missing_keyids.txt` (61개) — 길드 META 텍스트 전반(상점/할인/미션/기부/선물/채팅/레이드 안내) 키.

---

## 7. Unity 검증 결과

- `recompile_scripts`: **0 warning / 0 error** (에셋 리프레시 동반, 신규 case-b 에셋 임포트됨).
- `get_console_logs(error)`: **빈 배열 []** — 길드 프리팹 관련 "missing script / could not be loaded / import error" **0건**.
- 정적 재검증(현재 프리팹 파일 기준): META 45개 미해결 GUID = **2건**(위 §5, 의도된 에디터 판단 항목)뿐. Gem_Icon 리맵 후 해당 GUID 잔존 0.

→ **길드 프리팹 에러 0건.** 잔여 2건은 비-길드 공유 프리팹 누락으로 임포트 자체를 막지는 않음(인스펙터에 Missing Prefab 슬롯으로 표시).

---

## 8. 🟧 에디터/사용자 작업 (수동 필요)

1. **Addressable 등록** — `Resources_moved/UI/Guild*.prefab` 엔트리 팝업 **18개**(파일명=클래스명). Addressables 그룹 직접편집 금지 → Importer/에디터 위임.
2. **BottomTabHUD Guild 탭** — 코드(`EBottomTabType.Guild`→`GuildEntryRouter.EnterAsync`)는 배선 완료. BottomTabHUD.prefab에 Guild 탭 버튼 GameObject + 아이콘(icon_lobby_guild, 이미 존재) + 25레벨 해금 게이팅 와이어링 추가 필요.
3. **누락 공유 프리팹 처리(§5)** — Gacha_Box.prefab / Marine_Mini_UI.prefab 이식 또는 WD 대체 프리팹으로 리바인드. (GuildGiftRewardEffectPopup, WanderSlot의 Missing 슬롯)
4. **로컬라이즈 키 차팅(§6)** — 길드 META 로컬라이즈 키 61개 WD 구글시트 등록.
5. **SerializeField 연결** — .meta GUID 보존으로 대부분 자동연결. 예외는 위 §5 Missing 2건뿐. ★ 중첩 슬롯/임베드 패널은 PREFAB_PACKAGE_LIST §2 체크리스트로 임포트 후 인스펙터 확인 권장.
6. **레이드(2차) 보류** — `GuildRaid*` 프리팹 7개는 본 작업 제외. 동봉돼 있으나 GuildRaid 스크립트/보스 에셋 미이식 상태(2차 범위).

---

## 부록: 통계

- 작업 META 프리팹: **45** (레이드 7 제외)
- GUID 리맵: **1건**(Gem_Icon SpriteAsset) / 영향 프리팹 9
- 신규 복사 에셋: **20** (컨트롤러5 + 클립6 + 머티1 + 셰이더1 + 텍스처2 + 스프라이트5), .meta 동봉
- 미해결 GUID: **2** (비-길드 공유 프리팹, 에디터 판단)
- 누락 로컬라이즈 키: **61** (차팅 follow-up)
- Unity 검증: 길드 프리팹 에러 **0건**
