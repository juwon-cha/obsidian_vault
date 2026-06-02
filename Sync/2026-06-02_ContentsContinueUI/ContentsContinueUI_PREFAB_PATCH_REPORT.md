# Phase 5-C: 기존 TO 프리팹 패치 프리뷰 + 안전 적용 리포트

- 일자: 2026-06-02
- 대상 시스템: ContentsContinueUI (BD→WD sync)
- FROM: `/tmp/sync_ContentsContinueUI_1780395871`
- TO: `/Users/juwon.cha.teamsparta/RiderProjects/WiggleDefender`

## 요약

| 구분 | 개수 |
|---|---|
| 자동 패치된 프리팹 (SAFE-APPLY) | **0개** |
| 수동 처리 프리팹 (MANUAL) | **1개** (`LobbyMainUI.prefab`) |

핵심 결론: 유일한 패치 후보인 ContentsContinue 버튼은 **레이아웃 판단이 필요한 신규 GameObject** 이고, **Unity 에디터가 실행 중**(PID 2051)이라 파일시스템 직접 주입은 위험. 따라서 자동 적용하지 않고 전부 MANUAL로 문서화함.

---

## 패치 대상 식별

### Phase 4 스크립트 변경 (TO `UI/LobbyMainUI.cs`)
- L223: `[Header("콘텐츠 예고")] [SerializeField] private Button _contentsContinueButton;`
- L632: `_contentsContinueButton.onClick.AddListener(OnContentsContinueClicked);` (onClick은 **코드에서 런타임 바인딩** — 프리팹 m_OnClick에는 안 들어감)
- L2126: `OnContentsContinueClicked()` → 모드에 따라 `ContentsContinueTimelineUI` / `ContentsContinueUI` Show
- L2155: `RefreshContentsContinueButtonVisible()` → 버튼 GameObject SetActive 토글

### 프리팹 존재 확인
- TO: `Assets/Resources_moved/UI/LobbyMainUI.prefab` ✅
- FROM: `Assets/Resources/UI/LobbyMainUI.prefab` ✅
  (WD는 Addressables로 `Resources_moved/` 경로 사용 — 정상)

### 그 외 프리팹
- RedDot 노드 `Lobby.ContentsContinue` 는 BD에서 버튼 하위 `RedDotComponent`(MonoBehaviour, `_autoRegister:1`)로 등록 — **별도 매니저 프리팹 변경 불필요**. 코드/컴포넌트 기반 자동 등록.
- `Show<ContentsContinueUI>` / `Show<ContentsContinueTimelineUI>` 대상은 신규 프리팹(Phase 5-B 영역)이며 기존 TO 프리팹 패치 대상 아님.
- **결론: 기존 TO 프리팹 패치 후보는 `LobbyMainUI.prefab` 단 하나.**

---

## FROM vs TO 비교 (LobbyMainUI.prefab)

### FROM(BD) ContentsContinue 버튼 구조
- GameObject `Button - ContentsContinueUI` (`&8318563879299813235`)
  - RectTransform `&5217251613439935760`: AnchoredPosition (0,0), SizeDelta 160×160
  - Button 컴포넌트 `&9137506792472931215` (m_OnClick = **빈 배열** — 코드 바인딩)
  - DOTweenAutoPlayOnLobbyOpen
  - 자식: `Image - Icon`, `Text (TMP)`, `RedDotComponent`
- 부모: `Layout - RightButtons` (`&5816770307534367187`)
- LobbyMainUI MonoBehaviour 의 `_contentsContinueButton: {fileID: 9137506792472931215}` (Button 컴포넌트 참조)

### TO(WD) 현황
- `ContentsContinue` / `콘텐츠예고` 검색 → **0건** (버튼 GameObject 없음, 예상대로)
- 단, LobbyMainUI MonoBehaviour 에 `_contentsContinueButton: {fileID: 0}` 필드는 **이미 존재**(Phase 4 스크립트 변경으로 직렬화됨, null 상태). → 버튼만 만들어 이 필드에 드래그하면 됨.

### 부모 컨테이너 비교 — 레이아웃 분기 확인 (핵심)

두 프리팹 모두 `Layout - RightButtons` 에 **VerticalLayoutGroup** 사용 (자식 위치는 레이아웃이 자동 관리, 형제 순서 + spacing 으로 결정).

| | BD (FROM) | WD (TO) |
|---|---|---|
| 자식 목록 | Ark, EventUI, DailyQuestUI, **ContentsContinueUI**, RankingBoardUI, NewbieTraning (6개) | (이름없음), DailyQuestUI, RankingBoardUI, EventUI, NewbieTraining (5개) |
| SizeDelta | 283 × 1200 | 176 × 0 |
| AnchoredPosition | (0, 0) | (112, 40) |
| 컴포넌트 수 | 4 | **7** (WD 전용 컴포넌트 3개 추가) |

→ **자식 집합·순서·컨테이너 사이즈/앵커가 BD와 WD가 완전히 다름.** WD에는 Ark 버튼도 없고 순서도 다름. VerticalLayoutGroup 특성상 "어느 형제 사이에 넣느냐"가 곧 화면상 위치를 결정하므로 **레이아웃 판단 필요**.

---

## 패치 분류

### LobbyMainUI 버튼 → **MANUAL (자동 적용 안 함)**

이유 (3가지 모두 해당, 하나만으로도 MANUAL):
1. **레이아웃 판단 필요**: 신규 GameObject + RectTransform. 부모 VerticalLayoutGroup 의 형제 집합/순서가 BD↔WD 상이 → 어느 위치(형제 인덱스)에 넣을지는 사람이 결정해야 함.
2. **Unity 실행 중(PID 2051)**: 실행 중인 에디터의 임포터와 디스크 직접 YAML 편집이 충돌할 위험. 코어 로비 프리팹에 블라인드 주입 금지.
3. **아이콘 스프라이트 미존재**: BD 버튼 아이콘 `icon_lobby_contants.png` (guid `bc3caa34d782d4bc58027ee33ef49916`) 가 WD에 아직 없음 → 주입해도 깨진 참조.

### SAFE-APPLY 후보: **없음**
- onClick 바인딩은 프리팹이 아니라 코드(`AddListener`)에서 처리되므로 "기존 버튼에 OnClick만 추가" 같은 순수 가산 패치가 성립하지 않음.
- 추가할 컴포넌트도 좌표/레이아웃 독립적이지 않음.

---

## 수동 작업 상세 (사용자가 Unity 에디터에서 할 일)

대상 프리팹: `Assets/Resources_moved/UI/LobbyMainUI.prefab`

1. **(선행) 아이콘 텍스처 임포트**
   - FROM `Assets/_Project/6_Textures/OutGame/Lobby/icon_lobby_contants.png` 를 WD 동일 경로로 복사 (Phase 5-A 리소스 단계에서 누락됐다면 여기서 확인). guid `bc3caa34d782d4bc58027ee33ef49916` 유지 권장.

2. **버튼 GameObject 생성**
   - 부모: `Layout - RightButtons` (VerticalLayoutGroup)
   - 가장 안전한 방법: 기존 형제 버튼(예: `Button - DailyQuestUI` 또는 `Button - EventUI`)을 **복제**하여 동일한 RectTransform/Image/Text/RedDot 구조·사이즈를 그대로 따르게 함 (WD 로비 스타일 일관성 확보, BD의 160×160 좌표는 무시 — VerticalLayoutGroup이 재계산).
   - 이름: `Button - ContentsContinueUI`

3. **버튼 구성**
   - `Image - Icon` 자식 스프라이트 = `icon_lobby_contants.png`
   - `Text (TMP)` 라벨 = `콘텐츠예고` (BD 원문값 참고. 가능하면 하드코딩 대신 LocalizationManager 키 사용 권장 — 기존 형제 버튼 라벨 방식 따를 것)
   - `RedDotComponent` 자식: MonoBehaviour `_nodeID: Lobby.ContentsContinue`, `_autoRegister: 1`, `_autoCreateRedDot: 1`, `_position: 1` (BD 값 동일하게)

4. **형제 순서(레이아웃 위치) 결정** — 기획/디자인 확인 필요
   - BD에서는 `DailyQuestUI` 다음, `RankingBoardUI` 앞. WD는 순서가 달라 그대로 못 옮김. WD 로비에서 노출 우선순위에 맞는 인덱스로 배치.

5. **필드 연결**
   - LobbyMainUI 컴포넌트의 `_contentsContinueButton` 필드(현재 None) ← 생성한 버튼의 **Button 컴포넌트** 드래그.

6. **OnClick 설정 불필요**
   - onClick은 코드(`OnContentsContinueClicked`)에서 `AddListener`로 런타임 바인딩됨. 프리팹 인스펙터 OnClick 리스트는 비워둘 것 (BD도 빈 배열).

### BD 참고값 정리
| 항목 | 값 |
|---|---|
| 버튼명 | `Button - ContentsContinueUI` |
| 부모 컨테이너 | `Layout - RightButtons` (VerticalLayoutGroup) |
| 연결 필드 | `_contentsContinueButton` (LobbyMainUI MonoBehaviour) |
| OnClick 메서드 | `LobbyMainUI.OnContentsContinueClicked` (코드 AddListener, 프리팹 미설정) |
| 아이콘 스프라이트 | `icon_lobby_contants.png` (guid `bc3caa34d782d4bc58027ee33ef49916`) |
| 라벨 텍스트 | `콘텐츠예고` (현지화 키 사용 권장) |
| RedDot 노드 | `Lobby.ContentsContinue` (RedDotComponent, _autoRegister:1) |
| BD RectTransform | 160×160, anchoredPos (0,0) — **WD에선 무시**(VerticalLayoutGroup 재계산) |

---

## 검증 체크리스트 (수동 작업 후)
- [ ] LobbyMainUI 인스펙터에서 `_contentsContinueButton` 가 None 이 아님
- [ ] 로비 진입 시 버튼 위치가 다른 RightButtons 버튼들과 정렬/간격 일관됨
- [ ] 버튼 클릭 시 모드에 따라 ContentsContinueUI / ContentsContinueTimelineUI 열림
- [ ] `RefreshContentsContinueButtonVisible()` 동작 (조건부 숨김) 정상
- [ ] RedDot `Lobby.ContentsContinue` 노드 정상 표시
