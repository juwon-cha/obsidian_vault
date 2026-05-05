# Relic 기존 프리팹 패치 리포트

생성일: 2026-05-05  
Phase: 5-C

---

## 패치된 프리팹

| 프리팹 | 경로 | 추가된 항목 | 결과 |
|--------|------|------------|------|
| `GachaPanel.prefab` | `Assets/_Project/3_Prefabs/UI/Shop/Gacha/` | RelicGachaBox 계층 전체 (113 블록) + GachaUI MonoBehaviour 12개 _relic* 필드 바인딩 | ✅ 적용 (+2,829줄) |
| `UnitUpgradeUI.prefab` | `Assets/Resources_moved/UI/` | Button - Relic GameObject (10 블록) + _relicButton 필드 바인딩 | ✅ 적용 (+301줄) |

---

## 스킵된 프리팹

| 프리팹 | 이유 |
|--------|------|
| `GeneralShopPanel.prefab` | 분석 결과 _relic* 오버라이드 불필요. GachaPanel.prefab 패치로 자동 해결됨 |
| `ShopMainUI.prefab` | GachaPanel이 ShopMainUI가 아닌 GeneralShopPanel에 포함됨 |

---

## GachaPanel.prefab 패치 상세

### 추가된 RelicGachaBox 계층

```
ContentBox
  └ RelicGachaBox (새로 추가)
      ├ IconBox (RectTransform + Image)
      ├ ADBox
      │   ├ Button - RelicAdGachaButton (Button + Image)
      │   └ _relicAdCountdownPanel
      │       └ relicAdCountdownText (TMP)
      ├ ButtonBox
      │   ├ Button - RelicSingleButton (Button + Image + CostBox)
      │   └ Button - RelicTenButton (Button + Image + CostBox)
      ├ _relicGuaranteedBox (RectTransform + Image)
      ├ Button - RelicProbabilityButton (Button + Image)
      └ TitleBox (TMP)
```

### GachaUI MonoBehaviour 바인딩

| 필드 | 연결 대상 | 새 fileID |
|------|-----------|-----------|
| `_relicGachaPanel` | RelicGachaBox (GO) | 9204376513596452598 |
| `_relicSingleGachaButton` | Button-RelicSingleButton (Button) | 9204376513596452636 |
| `_relicTenGachaButton` | Button-RelicTenButton (Button) | 9204376513596452682 |
| `_relicAdGachaButton` | Button-RelicAdGachaButton (PrefabInstance stripped) | 9204376513596452822 |
| `_relicSingleCostText` | RelicSingleButton 코스트 TMP | 9204376513596452672 |
| `_relicTenCostText` | RelicTenButton 코스트 TMP | 9204376513596452718 |
| `_relicSingleCostIcon` | RelicSingleButton 코스트 아이콘 Image | 9204376513596452664 |
| `_relicTenCostIcon` | RelicTenButton 코스트 아이콘 Image | 9204376513596452710 |
| `_relicAdCountdownPanel` | _relicAdCountdownPanel (GO) | 9204376513596452788 |
| `_relicAdCountdownText` | relicAdCountdownText (TMP) | 9204376513596452806 |
| `_relicProbabilityButton` | Button-RelicProbabilityButton (Button) | 9204376513596452816 |
| `_relicGuaranteedBox` | _relicGuaranteedBox (GO) | 9204376513596452734 |

---

## UnitUpgradeUI.prefab 패치 상세

### 추가된 Button - Relic

```
TopBox (기존)
  └ Button - Relic (새로 추가)
      ├ RectTransform: AnchorMin(1,0.5), AnchorMax(1,0.5), AnchoredPos(-44,-2), SizeDelta(147,147)
      ├ Image: UI_icon_legacy.png
      └ Text (TMP): "유물", fontSize 45
```

| 필드 | 연결 대상 | 새 fileID |
|------|-----------|-----------|
| `_relicButton` | Button-Relic (Button 컴포넌트) | 9191881567751121335 |

---

## ⚠️ Unity 에디터 확인 필요

1. `GachaPanel.prefab` 열기 → RelicGachaBox Inspector 연결 상태 확인
2. `UnitUpgradeUI.prefab` 열기 → TopBox에 Button-Relic 표시 여부 확인
3. `GeneralShopPanel.prefab` 열기 → GachaPanel 인스턴스에서 _relic* 필드 자동 연결 여부 확인
4. `GachaUI` 스크립트에서 null 참조 없는지 확인
