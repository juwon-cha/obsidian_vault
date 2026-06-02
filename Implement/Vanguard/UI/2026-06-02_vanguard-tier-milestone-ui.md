# Vanguard — Tier Milestone 보상 UI 프리팹 구조 & 구현 계획 (2026-06-02)

> 상위: [[2026-05-29_vanguard-implementation-plan-overview]] · 관련: [[2026-06-02_vanguard-reusable-data-tables]]
> 대상: 위키 §4 "Tier Milestones"(티어 진행 보상). 리더보드 랭크 보상(§5)과는 **별개** 시스템.
> 참고 이미지: 세로 스크롤 리스트 — 행마다 [좌: 티어 뱃지 + 티어명] / [우: 보상 아이템(아이콘+수량) + 수령(달성) 체크박스]. 하단 고정 안내문.

---

## 0. 요약

- **배틀패스 UI(`BattlePassPanelBase`) 패턴 그대로 차용**: ScrollRect 안 Content에 행 프리팹을 `Instantiate`로 **동적 생성**.
- 신규 프리팹 2개: **`VanguardTierMilestonePanel`**(스크롤 컨테이너) + **`VanguardTierMilestoneSlot`**(행).
- 데이터: 시트→자동생성 **`VanguardTierMilestoneSO`**(티어별 1행). `HordeTierRewardData` 구조 차용.
- 지급은 **이벤트 종료 후 서버가 최고 달성 티어 기준으로 자동 지급**(하단 안내문) → UI는 **표시 + 달성 체크**만. 행별 수령 버튼/액션 없음. (랭크 보상과 동일 권위 모델)

---

## 1. 화면 분석 (참고 이미지)

- 행 구성(위→아래, **높은 티어가 위**): … 플래티넘3 / 골드1 / 골드2 / 골드3 / 실버1 / 실버2 … → `(int)EVanguardTier` **내림차순** 정렬, 디비전은 1이 상위.
- 각 행:
  - **좌측**: 티어 뱃지(메달 스프라이트 + 디비전 숫자 I/II/III) + 티어명 텍스트("플래티넘3").
  - **우측**: 보상 아이템 1개(아이콘 + 수량) + 그 아래 **체크박스**(달성/수령 표시).
- **하단 고정 안내문**: "보상은 이벤트 기간 동안 달성한 최고 등급을 기준으로 이벤트 종료 후 지급됩니다".
- 좌상단 Back 화살표(팝업 닫기).

> 해석: 체크박스는 "이 티어를 달성했는가" 표시(내 최고 티어 ≥ 해당 행 티어). 실제 재화 지급은 시즌 종료 후 서버. 따라서 **행별 Claim 버튼 없음**, 순수 표시형.

---

## 2. 프리팹 구조

### 2-1. `VanguardTierMilestonePanel.prefab` (스크롤 컨테이너)

```
VanguardTierMilestonePanel            (RectTransform, VanguardTierMilestonePanel.cs)
├── Header                            (선택) 타이틀/Back 버튼 — 팝업이 따로 가지면 생략
├── ScrollView                        (ScrollRect; vertical only, horizontal=off)
│   ├── Viewport                      (Mask + Image)
│   │   └── Content                   (RectTransform)
│   │        ├── VerticalLayoutGroup  (spacing, padding, childForceExpandWidth)
│   │        └── ContentSizeFitter    (Vertical=PreferredSize)
│   │        └── [동적 생성된 VanguardTierMilestoneSlot 들이 자식으로 들어감]
│   ├── Scrollbar Vertical            (선택)
└── FooterNotice                      (TMP_Text; "…최고 등급 기준 … 종료 후 지급" 고정 안내문, 로컬라이즈 키)
```

**인스펙터 직렬화 필드 (BattlePassPanelBase 패턴 대응)**
- `[SerializeField] GameObject _slotPrefab` — `VanguardTierMilestoneSlot` (= `_battlePassItemPrefab` 대응)
- `[SerializeField] RectTransform _scrollContent` — ScrollView/Viewport/Content (= `_battlePassScrollContent` 대응)
- `[SerializeField] TMP_Text _footerNoticeText` — 하단 안내문(또는 프리팹에 고정 텍스트로 둬도 됨)

### 2-2. `VanguardTierMilestoneSlot.prefab` (행 1개)

```
VanguardTierMilestoneSlot             (RectTransform, LayoutElement(preferredHeight), VanguardTierMilestoneSlot.cs)
├── Left
│   ├── TierBadge        (Image)              ← VanguardTierUtil.GetTierSprite(tier) (group: bronze/silver/...)
│   │   └── DivisionLabel(TMP_Text or Image)  ← 디비전 숫자 I/II/III (오버레이)
│   └── TierNameText     (TMP_Text)           ← VanguardTierUtil.GetDisplayName(tier) "플래티넘 3"
├── Right
│   ├── RewardContainer  (HorizontalLayoutGroup)
│   │   └── RewardItem×N (ItemDisplayComponent)  ← 재화 아이콘 + 수량 (이미지엔 1개, 구조는 N개 지원)
│   └── AchievedCheck    (GameObject/Image)    ← 달성 시 체크 ON
```

**인스펙터 직렬화 필드 (VanguardRankingRewardSlot 패턴 대응)**
- `Image _tierBadge`, `TMP_Text _divisionLabel`(또는 디비전 스프라이트), `TMP_Text _tierNameText`
- `List<ItemDisplayComponent> _rewardItems` (이미지엔 1개지만 1~N 지원)
- `GameObject _achievedCheck` (체크 표시)

> 디비전 숫자: `VanguardTierUtil`은 **그룹 스프라이트**(bronze/silver/…)만 주므로, 디비전 I/II/III는 **별도 오버레이**(작은 TMP/스프라이트)로 표기 권장. (전용 아트가 디비전별 통짜 스프라이트면 그걸 쓰고 오버레이 생략.)

---

## 3. 데이터 모델

### 3-1. `VanguardTierMilestoneSO` (시트→자동생성, `HordeTierRewardData` 차용)

| 컬럼(필드) | 타입 | 의미 |
|---|---|---|
| `tier` | EVanguardTier | 이 행의 티어/디비전 (정렬·달성 판정 키) |
| `currency1Type` | ECurrencyType | 보상1 재화 |
| `reward1Count` | int | 보상1 수량 |
| `currency2Type`/`reward2Count` | ECurrencyType/int | (선택) 보상2 — 이미지엔 1개만 |
| `rewardIconId` | int | (선택) 별도 보상 아이콘 id. 0=재화 아이콘 사용 |

> 이미지의 각 티어는 보상 1개지만, `HordeTierRewardData`(currency1~3)처럼 다중 보상도 담을 수 있게 N개로 설계. 미사용 칸은 `None`/0 → 슬롯 자동 숨김(랭크 보상 슬롯 규칙 동일).
> 시트 작성/생성 규칙은 [[2026-06-02_vanguard-reusable-data-tables]] §1-2(HordeTierRewardData) 참조. `HordeRank`→`tier`로 컬럼명만 교체.

### 3-2. 로드 경로
- `Resources/ScriptableObjects/VanguardTierMilestone/*.asset` (시트 자동생성)
- 패널이 `ResourceManager.LoadAllResourcesInFolder<VanguardTierMilestoneSO>("ScriptableObjects/VanguardTierMilestone")` 로 로드 (랭크 보상 패널과 동일 패턴).

---

## 4. 구현 계획 (스크립트)

### 4-1. `VanguardTierMilestonePanel.cs`
```csharp
public class VanguardTierMilestonePanel : MonoBehaviour
{
    private const string SOFolder = "ScriptableObjects/VanguardTierMilestone";
    [SerializeField] private GameObject _slotPrefab;
    [SerializeField] private RectTransform _scrollContent;
    [SerializeField] private TMP_Text _footerNoticeText;     // 선택(프리팹 고정 가능)

    private readonly List<VanguardTierMilestoneSlot> _slots = new();

    // myHighestTier: 서버/RankService가 주는 "이번 시즌 최고 달성 티어"
    public void InitPanel(EVanguardTier myHighestTier)
    {
        CleanPanel();

        var list = Managers.Instance?.GetManager<ResourceManager>()
                      ?.LoadAllResourcesInFolder<VanguardTierMilestoneSO>(SOFolder);
        if (list == null) return;

        // 높은 티어가 위로
        var sorted = list.OrderByDescending(x => (int)x.tier).ToList();

        foreach (var so in sorted)
        {
            var go = Instantiate(_slotPrefab, _scrollContent);   // ← 배틀패스 동적생성 패턴
            var slot = go.GetComponent<VanguardTierMilestoneSlot>();
            bool achieved = (int)myHighestTier >= (int)so.tier;  // 최고 티어 이상이면 달성
            slot.Init(so, achieved);
            _slots.Add(slot);
        }
    }

    public void CleanPanel()
    {
        foreach (var s in _slots) if (s != null) Destroy(s.gameObject);
        _slots.Clear();
    }
}
```
> 항목 수가 적으면(Bronze5~Ultimate = 약 26행) 단순 `Instantiate`+`VerticalLayoutGroup`으로 충분. 행이 크게 늘면 `LoopGridView`(무한스크롤, 보드 패널 사용)로 교체 가능 — 그 경우 슬롯이 `LoopGridViewItem` 상속.

### 4-2. `VanguardTierMilestoneSlot.cs`
```csharp
public class VanguardTierMilestoneSlot : MonoBehaviour
{
    [SerializeField] private Image _tierBadge;
    [SerializeField] private TMP_Text _divisionLabel;
    [SerializeField] private TMP_Text _tierNameText;
    [SerializeField] private List<ItemDisplayComponent> _rewardItems;
    [SerializeField] private GameObject _achievedCheck;

    public void Init(VanguardTierMilestoneSO so, bool achieved)
    {
        _tierBadge.sprite = VanguardTierUtil.GetTierSprite(so.tier);
        _tierNameText.text = VanguardTierUtil.GetDisplayName(so.tier);   // "플래티넘 3"
        SetDivisionLabel(so.tier);                                       // I/II/III 오버레이

        var pairs = new[] {
            (so.currency1Type, so.reward1Count),
            (so.currency2Type, so.reward2Count),
        };
        for (int i = 0; i < _rewardItems.Count; i++)
        {
            if (i < pairs.Length && pairs[i].Item2 > 0 && pairs[i].Item1 != ECurrencyType.None)
            { _rewardItems[i].gameObject.SetActive(true); _rewardItems[i].SetupItem(pairs[i].Item1, pairs[i].Item2); }
            else _rewardItems[i].gameObject.SetActive(false);
        }

        if (_achievedCheck != null) _achievedCheck.SetActive(achieved);
    }

    private void SetDivisionLabel(EVanguardTier tier)
    {
        // (int)tier % 100 → 디비전(내림차순 인코딩). Ultimate/None은 숨김.
        // 표기 규칙은 VanguardTierUtil.GetDisplayName과 일치시키거나 로마숫자 변환.
    }
}
```

### 4-3. 진입/배치
- **옵션 A (권장)**: 별도 팝업 `VanguardTierMilestonePopup`(또는 기존 `VanguardRankingInfoPopup`에 **3번째 탭** [랭킹]/[랭크보상]/[티어 마일스톤]). 이미지의 Back 화살표 = 팝업 닫기.
- **옵션 B**: 로비의 "Current Ranking(§4)" 진입점에서 단독 패널로.
- `myHighestTier`: 1차엔 `VanguardManager.RankService.Tier`(현재 티어)로 대체 표시 → 서버 연동 시 "시즌 최고 달성 티어" 필드로 교체.

---

## 5. 재활용 매핑 (무엇을 그대로 쓰는가)

| 요소 | 재활용 대상 | 방식 |
|---|---|---|
| 동적 생성(스크롤+Instantiate) | `BattlePassPanelBase.CreateBattlePassItems` 패턴 | 구조 차용 (`Instantiate(prefab, content)`) |
| 행 슬롯 보상 표시 | `ItemDisplayComponent.SetupItem(type, amount)` | 그대로 |
| 티어 뱃지/이름 | `VanguardTierUtil.GetTierSprite/GetDisplayName` | 그대로 |
| 데이터 테이블 | `HordeTierRewardData` 구조 | `tier` 컬럼으로 미러 → `VanguardTierMilestoneSO` |
| 미사용 보상칸 숨김 | `VanguardRankingRewardSlot` 규칙 | 동일(`amount<=0 || None` → 숨김) |
| 안내문/만료/지급 모델 | 랭크 보상 = 서버 정산 후 지급 | 동일 (행별 Claim 없음, 시즌 종료 후 서버 지급) |

---

## 6. 작업 체크리스트

- [ ] `VanguardTierMilestoneSO` 시트 컬럼 확정(`tier`=EVanguardTier, 보상 N개, rewardIconId) → 생성기로 SO 생성
- [ ] `VanguardTierMilestoneSlot.prefab` 제작 (뱃지/디비전/이름/보상N/체크)
- [ ] `VanguardTierMilestonePanel.prefab` 제작 (ScrollRect+Content+VLG+CSF, 하단 안내문)
- [ ] `VanguardTierMilestoneSlot.cs` / `VanguardTierMilestonePanel.cs` 작성
- [ ] 디비전 라벨(I/II/III) 표기 방식 확정(오버레이 vs 디비전별 스프라이트)
- [ ] 진입점 확정(별도 팝업 vs RankingInfoPopup 3번째 탭)
- [ ] `myHighestTier` 소스: 1차 RankService.Tier → 서버 "시즌 최고 티어" 연동
- [ ] 하단 안내문 로컬라이즈 키 등록
- [ ] 지급 로직은 서버(시즌 종료 정산) — 클라는 표시/달성 체크만 (서버 스펙 [[2026-05-31_vanguard-server-api-spec]]에 Tier Milestone 정산 추가 필요)

---

## 7. 미확정 / 합의 필요

- **달성 기준**: "최고 티어 이상이면 달성"으로 가정(누적). 디비전 단위로 끊는지(예: 플래티넘3 달성 = 플래티넘3 이하 전부 달성) 확정 필요 — `(int)tier` 비교로 처리 가능.
- **티어 범위**: Bronze5~Ultimate 전부 노출인지, 특정 티어부터인지(이미지엔 실버2가 최하단처럼 보임 — 스크롤 하단 더 있을 수 있음).
- **서버 지급**: 서버 스펙에 "Tier Milestone 정산"이 아직 없음 → 랭크 보상 정산(§6-3)과 별도로 "최고 달성 티어 → 마일스톤 보상" 정산 항목 추가 필요.
- **보상 개수**: 이미지엔 티어당 1개. 다중 보상 허용할지 기획 확정(SO는 N개 지원하도록 설계).
