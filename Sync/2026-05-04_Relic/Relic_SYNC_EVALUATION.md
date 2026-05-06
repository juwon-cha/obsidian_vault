# Relic(유물) 시스템 이식 평가 보고서

> 평가일: 2026-05-06
> 평가 대상: 2026-05-03 ~ 2026-05-04 Relic 시스템 이식 작업
> 이식 브랜치: `feature/juwon/RelicSystem`
> 평가 기준: `temp-bunker/dev` 브랜치 (2026-05-06 기준)

---

## 1. 요약

이식 자체는 대부분 정상 완료되었으나, **sync 계획 문서의 분석 브랜치(`feature/relic_skill`)와 실제 실행 기준 브랜치(`dev`) 간의 커밋 격차**로 인해 일부 핵심 파일이 누락되었다.

| 구분 | 결과 |
|------|------|
| 계획된 파일 이식 | ✅ 대부분 완료 |
| 핵심 UI 파일(`RelicGachaMainUI.cs`) | ❌ 누락 |
| 핵심 서비스(`RelicGachaService.cs`) | ❌ 누락 |
| DataSheet 파일 2종 | ❌ 누락 |
| SO 파일 4종 | ❌ 누락 |
| 유닛 컨트롤러 신화 스킬 (11개) | ✅ 완료 (WD 전용 partial 파일 구조로) |
| AcquisitionRouteManager 라우트 | ⚠️ 임시 처리 (RelicGachaPopup으로 매핑) |
| LobbyMainUI 뽑기 버튼 | ⚠️ 잘못된 대상으로 연결 |

---

## 2. 누락 파일 목록

### 2-1. 핵심 파일 (다음 이식 작업 최우선 대상)

| 파일 | 소스(temp-bunker/dev) | 누락 원인 |
|------|----------------------|-----------|
| `UI/Relic/RelicGachaMainUI.cs` | 존재 | 계획 문서가 `feature/relic_skill` 기준 → dev에 없다고 오판 |
| `Core/Managers/Relic/RelicGachaService.cs` | 존재 | 동일 원인 |

### 2-2. DataSheet 파일

| 파일 | temp-bunker/dev | WD |
|------|----------------|----|
| `SOs/Class/DataSheet/RelicGachaConfigDataData.cs` | ✅ 존재 | ❌ 없음 |
| `SOs/Class/DataSheet/RelicPityDataData.cs` | ✅ 존재 | ❌ 없음 |

### 2-3. SO 파일

| 파일 | temp-bunker/dev | WD |
|------|----------------|----|
| `SOs/SO/DataSheet/RelicGachaConfigDataSO.cs` | ✅ 존재 | ❌ 없음 |
| `SOs/SO/DataSheet/RelicGachaConfigDataParser.cs` | ✅ 존재 | ❌ 없음 |
| `SOs/SO/DataSheet/RelicPityDataSO.cs` | ✅ 존재 | ❌ 없음 |
| `SOs/SO/DataSheet/RelicPityDataParser.cs` | ✅ 존재 | ❌ 없음 |

> **영향**: `RelicGachaService` 및 뽑기 천장(pity) 시스템이 동작하려면 이 파일들이 필요.

### 2-4. 파일명 불일치 (확인 필요)

| 항목 | temp-bunker/dev | WD | 비고 |
|------|----------------|-----|------|
| WeightData SO | `RelicWeightDataSO.cs` | `RelicWeightTableSO.cs` | 이름 상이 — 동일 역할인지 확인 필요 |
| WeightData Parser | `RelicWeightDataParser.cs` | `RelicWeightTableDataParser.cs` | 동일 |
| WeightData Data | `RelicWeightDataData.cs` | `RelicWeightTableData.cs` | 동일 |

> WD 이식 당시 파일명을 변경한 것으로 추정. 내부 구조 및 참조 일치 여부 확인 필요.

---

## 3. 부작용 (이미 발생한 문제)

### 3-1. LobbyMainUI 뽑기 버튼 대상 오류

```csharp
// 현재 WD LobbyMainUI.cs (잘못된 상태)
Managers.Instance?.GetManager<UIManager>()?.Show<RelicGachaPopup>(); // 연출 팝업 — 파라미터 없으면 즉시 닫힘

// 올바른 상태 (RelicGachaMainUI 이식 후)
Managers.Instance?.GetManager<UIManager>()?.Show<RelicGachaMainUI>();
```

`RelicGachaPopup`은 뽑기 결과 애니메이션 전용 팝업이므로, 파라미터 없이 열면 `Opened()` 내에서 즉시 `Hide()`된다. 로비 뽑기 버튼이 현재 **무반응** 상태.

### 3-2. AcquisitionRouteManager 임시 처리

```csharp
// 현재 AcquisitionRouteManager.cs (임시)
case EAcquisitionRouteType.RelicGacha:
    return (typeof(RelicGachaPopup), true); // RelicGachaMainUI로 교체 필요
```

`RelicGachaMainUI` 이식 후 `typeof(RelicGachaPopup)` → `typeof(RelicGachaMainUI)` 로 교체.

---

## 4. 근본 원인 분석

### 4-1. 계획 문서의 브랜치 불일치

이식 계획(2026-05-04)은 BD `feature/relic_skill` 브랜치를 분석 기준으로 작성되었다.

```
분석 브랜치: feature/relic_skill
                    ↓
            RelicGachaMainUI.cs 없음
            RelicGachaService.cs 없음
                    ↓
        계획 문서에 "BD에 없음" 기록
```

그러나 `dev` 브랜치 커밋 `a4ddec289f`에서 아래 항목들이 추가되었다:
- `RelicGachaMainUI.cs` (뽑기 메인 UI)
- `RelicGachaService.cs` (뽑기 서비스)
- `RelicGachaConfigDataData.cs`, `RelicPityDataData.cs` 및 관련 SO/Parser 파일들

sync 에이전트가 계획 문서 기반으로 실행하면서 dev 브랜치 재검증 단계 없이 진행하여 이 파일들이 누락되었다.

### 4-2. 계획 문서의 "없음" 판단의 시효성 문제

2026-05-04 계획 문서 섹션 2-11:
> "BD에 `RelicGachaMainUI.cs` 파일이 없음"

이 판단은 **특정 브랜치, 특정 시점 기준**이었으나 문서에 명시되지 않았다. 이후 dev 브랜치에 해당 파일이 추가되면서 계획 문서가 구 버전이 되었음에도 이식 실행 시 재검증 없이 신뢰되었다.

---

## 5. 잘 된 점

- **유닛 컨트롤러 신화 스킬 11개**: temp-bunker/dev는 `DragoonController.RelicSkill.cs`만 별도 파일로 존재하고 나머지 10개는 컨트롤러 내부에 inline 구현되어 있다. WD는 모든 11개를 `.RelicSkill.cs` partial 파일로 분리하여 이식 — 코드 구조상 더 깔끔한 결과.
- **RelicGachaProbabilityPopup.cs**: BD에서 sync 불가 판단된 `RelicGachaProbabilityDataSource.cs` 대신 WD 전용 신규 파일을 작성 — 계획대로 올바르게 처리.
- **전체 파일 구조(Panel/, Upgrade/ 하위)**: 계획에 따라 정상 이식.
- **이식 계획 문서 2회 작성(2026-05-03, 2026-05-04)**: 실제 코드 대조 후 계획을 갱신하는 패턴은 올바름.

---

## 6. 다음 이식 작업 체크리스트

`RelicGachaMainUI.cs` 이식 시 함께 처리해야 할 항목:

### Phase A — DataSheet / SO 보완 (선행)
- [ ] `RelicGachaConfigDataData.cs` 이식
- [ ] `RelicPityDataData.cs` 이식
- [ ] `RelicGachaConfigDataSO.cs` + `RelicGachaConfigDataParser.cs` 이식
- [ ] `RelicPityDataSO.cs` + `RelicPityDataParser.cs` 이식
- [ ] WeightData 파일명 불일치 확인 (`RelicWeightDataData` vs `RelicWeightTableData`)

### Phase B — 서비스 계층
- [ ] `RelicGachaService.cs` 이식 (`ServiceAccessor` → `GetManager<T>()`, `MessageBroker` → `EventManager`)
- [ ] `GachaManager.cs`에 RelicGacha 메서드 추가 (현재 계획은 GachaManager 통합 방식 — RelicGachaService 별도 파일로 전환 여부 확인 필요)

### Phase C — UI 이식
- [ ] `RelicGachaMainUI.cs` 이식 (`ServiceAccessor` → `GetManager<T>()`, `async UniTaskVoid`, `LocalizationManager`, `ServerLoadingPopupUI` 패턴 적용)

### Phase D — 연동 수정
- [ ] `LobbyMainUI.cs`: `Show<RelicGachaPopup>()` → `Show<RelicGachaMainUI>()` 교체
- [ ] `AcquisitionRouteManager.cs`: `typeof(RelicGachaPopup)` → `typeof(RelicGachaMainUI)` 교체

---

## 7. 개선 제안 (다음 /sync 작업 시 반영)

### 7-1. 계획 문서에 분석 브랜치 명시

현재 계획 문서에 분석 대상 브랜치가 불분명하게 기술됨.

```markdown
# 권장 형식
> 소스 브랜치: temp-bunker/dev (분석 기준 커밋: abc1234)
> 분석일: 2026-05-04
> ⚠️ 이 계획은 위 커밋 시점 기준. 실행 전 최신 dev와 diff 재확인 필요.
```

### 7-2. 실행 전 "계획 문서 vs 최신 dev" 재검증 단계 추가

sync 에이전트 Phase 0 또는 Phase 1에서:
```
git diff {계획_커밋}..temp-bunker/dev -- Assets/_Project/1_Scripts/ | grep "^+" | grep "Relic"
```
로 계획 작성 후 dev에 추가된 Relic 관련 파일을 재확인하는 단계 추가.

### 7-3. "없음" 판단 항목 실행 직전 재확인

계획 문서에서 "BD에 없음", "sync 불가" 등으로 기록된 항목은 실행 시 `git ls-tree temp-bunker/dev`로 재확인 후 진행.

### 7-4. 핵심 UI 진입점 파일의 별도 체크

뽑기/메인/로비 등 사용자 진입점이 되는 `*MainUI.cs` 계열 파일은 별도 체크리스트 항목으로 관리.

---

*이 문서는 2026-05-06 기준 temp-bunker/dev 대조 및 WD 실제 코드베이스 분석을 통해 작성되었습니다.*
