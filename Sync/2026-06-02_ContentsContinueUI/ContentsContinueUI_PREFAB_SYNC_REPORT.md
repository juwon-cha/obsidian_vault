# ContentsContinueUI — Phase 5-B 프리팹 파일 포트 + GUID 리맵 리포트

- FROM: `/tmp/sync_ContentsContinueUI_1780395871`
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`
- 작업일: 2026-06-02
- 방식: Unity 미사용 (파일시스템 + GUID 텍스트 치환)

---

## 1. 처리된 프리팹 (신규 복사 5)

의존성 순(leaf → root)으로 처리:

| 순서 | 프리팹 | TO 배치 경로 | 메타 GUID 유지 |
|---|---|---|---|
| 1 | ContentsContinueCardUI.prefab | `Assets/_Project/3_Prefabs/UI/ContentsContinue/` | bc4af61ca12df4310a1e4c41497157c3 |
| 2 | ContentsContinueLevelSection.prefab | `Assets/_Project/3_Prefabs/UI/ContentsContinue/` | 972aa235c799144519b42084856da065 |
| 3 | ContentsContinueItemUI.prefab | `Assets/_Project/3_Prefabs/UI/ContentsContinue/` | ff1d8b7203a9140caa3b9056a1ee0847 |
| 4 | ContentsContinueUI.prefab | `Assets/Resources_moved/UI/` (⚠️ 경로 변경) | f835997a4944544ac89b3a34341ece60 |
| 5 | ContentsContinueTimelineUI.prefab | `Assets/Resources_moved/UI/` (⚠️ 경로 변경) | bad73935e45214c56aeb9d3003ed8464 |

- 진입 팝업 2종: FROM `Assets/Resources/UI/` → TO `Assets/Resources_moved/UI/` (WD Addressables 컨벤션, RewardClaimPopupUI와 동일).
- 서브 프리팹 3종: 동일 경로 유지. 메타 GUID 유지 → 상위 프리팹 SerializeField/Instantiate 슬롯 무손상.
- 각 프리팹 `.prefab` + `.meta` 복사 완료.

### 교차 참조(런타임 Instantiate 슬롯) 검증 — 정상
- `ContentsContinueUI.contentPreviewItemPrefab` → `ff1d8b…` (ItemUI) ✅
- `ContentsContinueTimelineUI.contentPreviewLevelSectionPrefab` → `972aa2…` (LevelSection) ✅
- `ContentsContinueLevelSection.cardPrefab` → `bc4af6…` (CardUI) ✅

---

## 2. 스킵 (공용 — TO에 GUID 동일 존재, 복사·치환 안 함)

| 프리팹/컴포넌트 | GUID | TO 위치 |
|---|---|---|
| Button - BackgroundClose.prefab | 069400c98789ca641b0df3c8d6163d51 | TO 존재 |
| TopBox.prefab (_Common) | 0f33a15fc7b1e474580f3385b7d7acf7 | TO 존재 |
| Button - ItemDisplayPrefab.prefab | aa625821719cd3c429659d24369154d7 | TO 존재 |
| VFX_UI_Slot_Rotation.prefab | f9528b44629b69748aa03bfd5a2df549 | TO 존재 |
| ItemDisplayComponent | 99b9e042d9d3a40438eef2c93d070852 | TO 존재 |
| RedDotComponent | 9a9cc6e741e1dac4985bd4e09c67e15d | TO 존재 |

---

## 3. GUID 교체 내역 — 스크립트 m_Script (5종, 프리팹별)

복사한 프리팹 YAML 내 FROM 스크립트 GUID → TO 스크립트 GUID 텍스트 치환(해당 GUID만, 블랭킷 치환 금지).

| 스크립트 | FROM GUID | → TO GUID | 치환 발생 프리팹(건수) |
|---|---|---|---|
| ContentsContinueCardUI | 974ee3c20ea434a1fb11cc1d0b312357 | 484e334758b304beaa29b66365160a15 | CardUI(1) |
| ContentsContinueLevelSectionUI | 25c447d9ba50b45a2b668892ff09b973 | 9d99cb4a924bd4071847f14240889b8e | LevelSection(1) |
| ContentsContinueItemUI | 661462ee71d634e1893fc83b916cf9ae | d6e4a515fc9ed4220adcff4d93b27132 | ItemUI(1), ContentsContinueUI(1), TimelineUI(1) |
| ContentsContinueUI | 349dd007542f54d2c9187e3d936d4de3 | d9e2bf8d8d9884bfbb36b34542473b92 | ContentsContinueUI(1) |
| ContentsContinueTimelineUI | 85632f2e1b4e9465a9c1a2ef4d2e71b8 | e0a954fb1693f42c48dced0fa2cd04a4 | TimelineUI(1) |

**총 8건 치환.**

> 주의 발견: 진입 팝업 `ContentsContinueUI.prefab` / `ContentsContinueTimelineUI.prefab` 내부에 **임베드된 ItemUI MonoBehaviour(템플릿 아이템)** 가 있어 ItemUI 스크립트 GUID(661462e)를 각각 1건씩 추가 보유. 둘 다 정상 리맵 완료(`m_EditorClassIdentifier: Assembly-CSharp::ContentsContinueItemUI` 확인). 미치환 시 Missing Script 발생할 뻔.

### GUID 교체 내역 — 에셋
없음. 공용 에셋/컴포넌트는 전부 TO에 동일 GUID 존재(리맵 불필요). UIEffect 등 패키지 GUID도 동일.

---

## 4. 신규 복사 에셋 (FROM-only, 프리팹 참조)

| 에셋 | GUID | FROM 경로 | TO 배치 경로 |
|---|---|---|---|
| icon_contents_1.png | 4ea7caee8ebab4a9d87e7dbd214695f2 | `Assets/Resources/Sprites/UI/ContentsContinue/icon_contents_1.png` | `Assets/Resources_moved/Sprites/UI/ContentsContinue/icon_contents_1.png` |

- `ContentsContinueItemUI.prefab` 의 Image 슬롯이 참조하는 **유일한** 프리팹-임베드 스프라이트. GUID 유지로 슬롯 무손상.
- Resources → Resources_moved 경로 적용(WD Addressables 컨벤션).
- `.png` + `.meta` 복사 완료.

---

## 5. 미해결 GUID

**없음.** 작성된 5개 프리팹의 참조 GUID 46개 전부 TO Assets(37072개 인덱스) 또는 TO Library/PackageCache(14131개 인덱스)에서 해결됨.

참고로 다음 12개는 TO Assets에 없지만 **TO PackageCache `com.coffee.ui-effect@e45bd4392164`** 에 존재(패키지 GUID, 프로젝트 간 동일) → 그대로 유지:
`1aa08ab6…, 30649d3a…, 306cc8c2…, 31a19414…, 3245ec92…, 4e29b1a8…, 59f81469…, 90ac5d06…(UIEffectTweener.cs), 938fce05…(UIEffect.cs), 944c3fa2…, f4688fdb…, fe87c0e1…`

---

## 6. 로컬라이즈 (Step C)

`LocalizeStringEvent` / `m_TableReference` / `TableEntryReference` — 5개 프리팹 전부 **0건**. table-collection GUID 검증 불필요(5-A 결론 재확인).

---

## 7. 사후 검증 (Step D)

- ✅ FROM 스크립트 GUID 잔존: **0건** (5개 프리팹 전수 검사).
- ✅ TO 스크립트 GUID 정상 배치:
  - CardUI=484e3347, LevelSection=9d99cb4a, ItemUI=d6e4a515, ContentsContinueUI=d9e2bf8d(+임베드 ItemUI d6e4a515), TimelineUI=e0a954fb(+임베드 ItemUI d6e4a515).
- ✅ 참조 GUID 46개 전부 해결(Assets 또는 PackageCache). 미해결 0.
- ✅ 교차 Instantiate 슬롯(ff1d8b/972aa2/bc4af6) 정상.
- → Missing Script 발생 없음(예상).

---

## 8. 수동 확인 필요 (사용자 / Unity 에디터)

### (A) Addressables 등록 — 진입 팝업 2종 (필수)
파일 직접 편집 금지 규칙에 따라 본 작업에서 미처리. Unity Importer/에디터에서 등록 필요:
- [ ] `Assets/Resources_moved/UI/ContentsContinueUI.prefab` → 주소 `UI/ContentsContinueUI`
- [ ] `Assets/Resources_moved/UI/ContentsContinueTimelineUI.prefab` → 주소 `UI/ContentsContinueTimelineUI`
- (서브 프리팹 3종 / 스프라이트는 SerializeField·Instantiate 슬롯 연결로만 사용 → Addressables 등록 대상 아님)

### (B) UIManager 등록
- 진입 팝업 2종은 `LoadResource<GameObject>("UI/{클래스명}")` 규약. 파일명=클래스명, Resources_moved/UI 배치 완료. UIManager 측 등록/호출 경로 확인.

### (C) SerializeField 슬롯 — Unity 임포트 후 시각 확인
- 메타·m_Script GUID는 정상이나, 실제 인스펙터 슬롯 연결(backgroundButton, closeButton, contentPreviewListParent, titleText, canvasGroup, popupTransform 등)은 프리팹 YAML 내부 fileID 참조라 별도 손상 없음. 임포트 후 Missing 없는지 1회 확인 권장.

### (D) ⚠️ 런타임 아이콘 로드 — 데이터/런타임 페이즈 이슈 (5-B 범위 외)
- `ContentsContinueItemUI.SetupContentIcon()` 가 `Resources.Load<Sprite>(_contentData.iconPath)` 직접 호출.
- FROM `Assets/Resources/Sprites/UI/ContentsContinue/` 에는 `icon_contents_1~6.png` + UI base 아이콘 다수 존재. 본 페이즈는 **프리팹이 직접 임베드 참조하는 `icon_contents_1.png` 1개만** 복사함.
- WD는 스프라이트를 `Resources_moved/`(Addressables)로 옮겨 `Resources.Load` 가 실패할 수 있음 → 데이터 sheet의 `iconPath` 가 가리키는 전체 아이콘 세트의 배치/로딩 방식은 **데이터/런타임 sync 페이즈에서 검증** 필요(코드에 `// TODO: ResourceManager/Addressables 경로 검증` 명시, 로드 실패 시 Image 비활성 graceful 처리됨).
