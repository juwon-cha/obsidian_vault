# ContentsContinueUI — Phase 5-A 프리팹 패키지 목록

- FROM: `/tmp/sync_ContentsContinueUI_1780395871`
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- SYSTEM: ContentsContinueUI / KEYS: ContentsContinue
- 생성일: 2026-06-02

---

## 0. 의존성 트리 (한눈 요약)

```
ContentsContinueUI.prefab (진입점/팝업, 신규)
├─ [nested] Button - BackgroundClose.prefab        ⬛ TO 존재(GUID 동일)
├─ [nested] TopBox.prefab (_Common)                ⬛ TO 존재(GUID 동일)
└─ [SerializeField GameObject] ContentsContinueItemUI.prefab (런타임 Instantiate, 신규)
       ├─ [nested] VFX_UI_Slot_Rotation.prefab     ⬛ TO 존재(GUID 동일)
       ├─ [SerializeField] ItemDisplayComponent    ⬛ TO 존재(GUID 동일)
       └─ [SerializeField] RedDotComponent         ⬛ TO 존재(GUID 동일)

ContentsContinueTimelineUI.prefab (진입점/팝업, 신규)
├─ [nested] Button - BackgroundClose.prefab        ⬛ TO 존재(GUID 동일)
├─ [nested] TopBox.prefab (_Common)                ⬛ TO 존재(GUID 동일)
└─ [SerializeField GameObject] ContentsContinueLevelSection.prefab (런타임 Instantiate, 신규)
       └─ [SerializeField GameObject] ContentsContinueCardUI.prefab (런타임 Instantiate, 신규)
              ├─ [nested] Button - ItemDisplayPrefab.prefab  ⬛ TO 존재(GUID 동일)
              ├─ [SerializeField] ItemDisplayComponent       ⬛ TO 존재(GUID 동일)
              └─ [SerializeField] RedDotComponent            ⬛ TO 존재(GUID 동일)
```

- **nested** = 프리팹 YAML 내 `m_SourcePrefab` PrefabInstance (에디터 타임 중첩).
- **SerializeField GameObject** = 코드에서 `Instantiate(prefab, parent)` 로 런타임 생성. 프리팹은 진입 프리팹의 SerializeField 슬롯에 연결되어 있음(중첩 인스턴스 아님).

---

## 1. sync할 프리팹 목록 (의존성 순 — leaf first, 진입점 last)

| 순서 | 프리팹 파일명 | 상태 | FROM 경로 | TO 경로(있으면) | TO 처리 |
|---|---|---|---|---|---|
| 1 | Button - BackgroundClose.prefab | ⬛ 스킵 | Assets/_Project/3_Prefabs/UI/Buttons/Button - BackgroundClose.prefab | Assets/_Project/3_Prefabs/UI/Buttons/Button - BackgroundClose.prefab | 이미 존재, GUID 동일(069400...). 복사·재임포트 불필요 |
| 2 | TopBox.prefab (_Common) | ⬛ 스킵 | Assets/_Project/3_Prefabs/UI/_Common/TopBox.prefab | Assets/_Project/3_Prefabs/UI/_Common/TopBox.prefab | 이미 존재, GUID 동일(0f33a1...). `Parts/TopBox`(bd5756...)는 별개 프리팹이니 혼동 주의 |
| 3 | Button - ItemDisplayPrefab.prefab | ⬛ 스킵 | Assets/_Project/3_Prefabs/UI/Buttons/Button - ItemDisplayPrefab.prefab | Assets/_Project/3_Prefabs/UI/Buttons/Button - ItemDisplayPrefab.prefab | 이미 존재, GUID 동일(aa6258...) |
| 4 | VFX_UI_Slot_Rotation.prefab | ⬛ 스킵 | Assets/Marine/Prefab/UI/VFX_UI_Slot_Rotation.prefab | Assets/Marine/Prefab/UI/VFX_UI_Slot_Rotation.prefab | 이미 존재, GUID 동일(f9528b...) |
| 5 | ContentsContinueCardUI.prefab | 🆕 신규 | Assets/_Project/3_Prefabs/UI/ContentsContinue/ContentsContinueCardUI.prefab | (없음) | 동일 경로 신규 복사. 복사 후 m_Script GUID 리맵 필요(§5) |
| 6 | ContentsContinueLevelSection.prefab | 🆕 신규 | Assets/_Project/3_Prefabs/UI/ContentsContinue/ContentsContinueLevelSection.prefab | (없음) | 동일 경로 신규 복사. CardUI SerializeField 슬롯이 5번을 가리킴(GUID bc4af6 유지). m_Script 리맵 필요 |
| 7 | ContentsContinueItemUI.prefab | 🆕 신규 | Assets/_Project/3_Prefabs/UI/ContentsContinue/ContentsContinueItemUI.prefab | (없음) | 동일 경로 신규 복사. m_Script 리맵 필요 |
| 8 | ContentsContinueUI.prefab | 🆕 신규 | Assets/Resources/UI/ContentsContinueUI.prefab | (없음) | ⚠️ **경로 변경**: TO는 `Assets/Resources_moved/UI/ContentsContinueUI.prefab` 로 배치(WD Addressables 컨벤션). ItemUI SerializeField 슬롯이 7번을 가리킴(GUID ff1d8b 유지). m_Script 리맵 필요 |
| 9 | ContentsContinueTimelineUI.prefab | 🆕 신규 | Assets/Resources/UI/ContentsContinueTimelineUI.prefab | (없음) | ⚠️ **경로 변경**: TO는 `Assets/Resources_moved/UI/ContentsContinueTimelineUI.prefab`. LevelSection SerializeField 슬롯이 6번을 가리킴(GUID 972aa2 유지). m_Script 리맵 필요 |

**상태 집계:** 신규 5 / ⚠️업데이트 0 / ⬛스킵 4 / 🔵수동 0

> 진입점 2종은 FROM이 `Assets/Resources/UI/` 에 있으나, WD는 동일 종류 팝업을 `Assets/Resources_moved/UI/`(Addressables)에 둔다(예: `RewardClaimPopupUI.prefab`). UIManager가 `LoadResource<GameObject>("UI/{name}")` → Resources 미존재 시 `Assets/Resources_moved/` Addressables로 폴백하므로, 진입 프리팹은 `Resources_moved/UI/`에 배치하고 Addressables 등록(에디터/Importer 위임)이 필요하다.

---

## 2. 프리팹별 SerializeField 연결 목록

### ContentsContinueUI.prefab → `ContentsContinueUI.cs`
| 필드명 | 타입 | 비고 |
|---|---|---|
| backgroundButton | Button | 배경 클릭 닫기 |
| closeButton | Button | 닫기 버튼 |
| contentPreviewListParent | Transform | 아이템 부모(레이아웃) |
| contentPreviewItemPrefab | GameObject | **→ ContentsContinueItemUI.prefab (ff1d8b...) 런타임 Instantiate** |
| titleText | TextMeshProUGUI | 타이틀 |
| canvasGroup | CanvasGroup | 오픈 페이드 |
| popupTransform | Transform | 오픈/클로즈 스케일 |

### ContentsContinueTimelineUI.prefab → `ContentsContinueTimelineUI.cs`
| 필드명 | 타입 | 비고 |
|---|---|---|
| backgroundButton | Button | |
| closeButton | Button | |
| contentPreviewListParent | Transform | 섹션 부모 |
| contentPreviewLevelSectionPrefab | GameObject | **→ ContentsContinueLevelSection.prefab (972aa2...) 런타임 Instantiate** |
| titleText | TextMeshProUGUI | |
| canvasGroup | CanvasGroup | |
| popupTransform | Transform | |

### ContentsContinueItemUI.prefab → `ContentsContinueItemUI.cs`
| 필드명 | 타입 | 비고 |
|---|---|---|
| contentIcon | Image | iconPath `Resources.Load<Sprite>` (§5 경로 주의) |
| contenTitleText | TextMeshProUGUI | |
| contentDescText | TextMeshProUGUI | |
| unlockLevelText | TextMeshProUGUI | |
| unlockRewardDisplay | ItemDisplayComponent | ⬛ TO 존재(99b9e0... 동일) |
| unlockRewardVfx | GameObject | VFX_UI_Slot_Rotation 인스턴스 추정 |
| moveToContentButton | Button | |
| moveToContentButtonText | TextMeshProUGUI | |
| lockedDim | GameObject | 잠금 딤 |
| _redDotComponent | RedDotComponent | ⬛ TO 존재(9a9cc6... 동일). 비어있으면 런타임 AddComponent |
| _autoCreateRedDot | bool | 기본 true |

### ContentsContinueCardUI.prefab → `ContentsContinueCardUI.cs`
| 필드명 | 타입 | 비고 |
|---|---|---|
| contentIcon | Image | |
| contenTitleText | TextMeshProUGUI | |
| contentDescText | TextMeshProUGUI | |
| unlockLevelText | TextMeshProUGUI | |
| unlockRewardDisplay | ItemDisplayComponent | ⬛ TO 존재 |
| claimButton | Button | |
| moveToContentButton | Button | |
| claimButtonText | TextMeshProUGUI | |
| moveToContentButtonText | TextMeshProUGUI | |
| claimButtonClaimed | GameObject | |
| _redDotComponent | RedDotComponent | ⬛ TO 존재. 비어있으면 런타임 AddComponent |
| _autoCreateRedDot | bool | 기본 true |

### ContentsContinueLevelSection.prefab → `ContentsContinueLevelSectionUI.cs`
| 필드명 | 타입 | 비고 |
|---|---|---|
| levelText | TextMeshProUGUI | |
| spotImage | Image | 진행선 스팟 |
| upperLineImage | Image | |
| underLineImage | Image | |
| staticUpperLineImage | Image | 최상단 고정 라인 |
| cardContainer | Transform | 카드 부모 |
| cardPrefab | GameObject | **→ ContentsContinueCardUI.prefab (bc4af6...) 런타임 Instantiate** |
| activeColor | Color | |
| inactiveColor | Color | |

---

## 3. Show<T> / Hide<T> 외부 UI 참조 확인

| 호출 위치 | 대상 클래스 | TO 존재 | 처리 |
|---|---|---|---|
| ContentsContinueUI.CloseUI | Hide&lt;ContentsContinueUI&gt; | 자기 자신(신규) | 본 패키지로 임포트 |
| ContentsContinueTimelineUI.CloseUI | Hide&lt;ContentsContinueTimelineUI&gt; | 자기 자신(신규) | 본 패키지로 임포트 |
| ContentsContinueItemUI.ShowRewardPopup | Show&lt;RewardClaimPopupUI&gt; | ✅ 존재 | `Assets/Resources_moved/UI/RewardClaimPopupUI.prefab` 그대로 사용 |
| ContentsContinueItemUI.OnMoveToContentButtonClicked | Hide&lt;ContentsContinueUI&gt; | 자기 자신 | — |
| ContentsContinueCardUI.ShowRewardPopup | Show&lt;RewardClaimPopupUI&gt; | ✅ 존재 | 동일 |
| ContentsContinueCardUI.OnMoveToContentButtonClicked | Hide&lt;ContentsContinueTimelineUI&gt; | 자기 자신 | — |

> 외부 의존: `RewardClaimPopupUI`(TO 존재), `ItemDisplayComponent`/`RedDotComponent`(TO 존재, GUID 동일), 매니저 `ContentsContinueManager`/`AcquisitionRouteManager`/`RedDotManager`/`PlayerDataManager`/`UIManager`. 매니저 존재 여부는 스크립트 sync 단계(5-B/이전 페이즈) 책임 범위.

---

## 4. 임포트 후 UIManager 등록 필요 목록

진입 팝업 2종은 `LoadResource<GameObject>("UI/{클래스명}")` 규약을 따르므로 파일명=클래스명, `Resources_moved/UI/` 배치 + Addressables 등록이 핵심.

- [ ] **ContentsContinueUI** — `Assets/Resources_moved/UI/ContentsContinueUI.prefab` (Addressables 주소 `UI/ContentsContinueUI` 또는 WD 규약 키)
- [ ] **ContentsContinueTimelineUI** — `Assets/Resources_moved/UI/ContentsContinueTimelineUI.prefab` (Addressables 주소 `UI/ContentsContinueTimelineUI`)
- [ ] (서브 프리팹 ItemUI / LevelSection / CardUI는 UIManager 등록 대상 아님 — SerializeField 슬롯 연결로만 사용, `_Project/3_Prefabs/UI/ContentsContinue/` 유지)

> Addressables 등록은 에디터/Importer에 위임(파일 직접 편집 금지 규칙).

---

## 5. LocalizeStringEvent / 임베디드 GUID 주의

### LocalizeStringEvent
**없음.** 5개 프리팹 전부 `LocalizeStringEvent` / `m_TableReference` / `TableEntryReference` 0건. 로컬라이즈는 전부 코드(`LocalizationManager.GetLocalizedText("키")`)로 처리되므로 table-collection GUID 검증 불필요.

### ⚠️ m_Script GUID 리맵 (필수 — 5-B/5-C 핵심 주의)
신규 5개 프리팹의 MonoBehaviour `m_Script`는 **FROM 스크립트 GUID**를 임베드하고 있는데, TO의 동명 스크립트 GUID와 **모두 다름**. 복사만 하면 프리팹의 MonoBehaviour가 Missing Script가 된다. 복사 후 프리팹 YAML 내 GUID 치환 필요:

| 스크립트 | FROM GUID | → TO GUID |
|---|---|---|
| ContentsContinueUI | 349dd007542f54d2c9187e3d936d4de3 | d9e2bf8d8d9884bfbb36b34542473b92 |
| ContentsContinueTimelineUI | 85632f2e1b4e9465a9c1a2ef4d2e71b8 | e0a954fb1693f42c48dced0fa2cd04a4 |
| ContentsContinueItemUI | 661462ee71d634e1893fc83b916cf9ae | d6e4a515fc9ed4220adcff4d93b27132 |
| ContentsContinueCardUI | 974ee3c20ea434a1fb11cc1d0b312357 | 484e334758b304beaa29b66365160a15 |
| ContentsContinueLevelSectionUI | 25c447d9ba50b45a2b668892ff09b973 | 9d99cb4a924bd4071847f14240889b8e |

### GUID 유지(리맵 불필요 — 동일하므로 그대로 연결됨)
- ItemDisplayComponent `99b9e042d9d3a40438eef2c93d070852` (FROM=TO)
- RedDotComponent `9a9cc6e741e1dac4985bd4e09c67e15d` (FROM=TO)
- 서브 프리팹 자체 GUID: ItemUI `ff1d8b...`, LevelSection `972aa2...`, CardUI `bc4af6...` — 신규 복사 시 .meta GUID 유지 → 진입/섹션 프리팹의 SerializeField·`cardPrefab` 슬롯이 깨지지 않음.
- 공용 nested 프리팹 4종(BackgroundClose 069400, _Common/TopBox 0f33a1, ItemDisplayPrefab aa6258, VFX_UI_Slot_Rotation f9528b) — TO에 동일 GUID 존재.

### ⚠️ Resources vs Resources_moved 경로
1. **진입 프리팹 배치**: FROM `Assets/Resources/UI/` → TO `Assets/Resources_moved/UI/` (WD Addressables 컨벤션, RewardClaimPopupUI와 동일). 서브 프리팹은 `_Project/3_Prefabs/UI/ContentsContinue/` 동일 경로 유지.
2. **런타임 아이콘 로드 주의**: `ContentsContinueItemUI.SetupContentIcon()` 가 `Resources.Load<Sprite>(_contentData.iconPath)` 직접 호출(코드에 `// TODO: ResourceManager/Addressables 경로 검증` 명시). WD는 스프라이트가 `Resources_moved/`(Addressables)에 있을 수 있어 `Resources.Load` 실패 가능 → 데이터 sheet의 `iconPath` 리소스가 TO 어디에 있는지 5-B/데이터 페이즈에서 검증 필요. (프리팹 슬롯 문제는 아님, 데이터/런타임 이슈)
