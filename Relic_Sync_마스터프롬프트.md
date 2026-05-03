# Relic 시스템 sync 마스터 프롬프트

> 이 문서를 /sync 실행 전 Claude에게 통째로 붙여넣거나,  
> `/sync` 커맨드의 `$ARGUMENTS`로 아래 플래그를 전달한다.

---

## 즉시 실행 플래그 (권장)

```
/sync \
  --from <temp-bunker 로컬 경로> \
  --to /path/to/WiggleDefender \
  --system Relic \
  --keys RelicManager,RelicGachaService,RelicMainUI,RelicUpgradeUI,RelicGachaMainUI,RelicGachaPopup,RelicData,RelicSaveData,ERelicGrade,ERelicSkillType,DragoonLaserBind,ZeusRapidFire,MarauderShotgunBlast,TemplerMultiHit,TurretDelayedExplosion,NinjaMythic,AirManWindExtra,ThorElectricPull,VesselDefensiveShield,CarrierSpecialInterceptor,DrFrostBlizzardGrowth \
  --phase 5a
```

> `--from` 경로는 temp-bunker 워크트리 실제 경로로 교체.  
> `--phase 5a` = 스크립트 sync + 프리팹 목록 생성 (프리팹 자동 복사 원하면 `5b` 또는 `5c`).

---

## 배경 컨텍스트 (Phase 0~4 Agent에게 전달)

```
[시스템 설명]
Relic(유물) 시스템을 BunkerDefense(BD)에서 WiggleDefender(WD)로 sync한다.
유물은 4슬롯 장착, 등급(Rare/Epic/Legendary/Mythic), 랭크업(1~10), 강화(0~100),
가챠(뽑기), 신화 전용 스킬(11개 유닛)로 구성된 후기 콘텐츠다.

[두 프로젝트의 핵심 차이]
1. 매니저 접근: ServiceAccessor.Get<T>() → Managers.Instance.GetManager<T>()
2. 이벤트: MessageBroker → EventManager (STATIC, GetManager 사용 금지)
3. 매니저 등록: BD의 ManagerFactory.cs → WD의 Managers.cs MANAGER_DEFINITIONS 배열
4. UI 베이스: BD의 UIBase → WD의 UIBase (UI/UIBase.cs), API는 동일
5. 비동기: UniTask + Async suffix (async void 금지, async UniTaskVoid 사용)
6. DOTween: await tween.AsyncWaitForCompletion() — ToUniTask() 절대 금지
7. 시간: DateTime.Now 금지 → ServerTimeManager.NowUnscaled
8. 로컬라이제이션: 하드코딩 한국어/영어 금지 → LocalizationManager.GetLocalizedText()
9. 서버 로딩: 모든 서버 API 호출에 ServerLoadingPopupUI.Show/Hide 패턴 적용
10. 리소스: Resources.Load 금지 → ResourceManager.LoadResource<T>()

[WD 실제 코드 검증 결과 — 반드시 준수]
- Managers.cs priority: RelicManager는 334 ("Lobby") — ContentUnlockManager(321) 이후
- DamageCalculationManager.RelicEffect.cs: lazy-init 캐싱 필수 (priority 175로 RelicManager보다 먼저 초기화됨)
  → ChipEffect.cs 패턴 참고: _relicManager = Managers.Instance?.GetManager<RelicManager>()  null-check 후 반환
- ETargetItemType.Relic: 이미 존재 — 추가 금지. TargetDisplayComponent.cs에 case만 추가
- Core/Gacha/ 폴더: WD에 없음 — RelicGachaProbabilityDataSource.cs는 sync 불가
  → RelicGachaProbabilityPopup.cs 신규 작성으로 대체 (RelicManager에서 확률 데이터 직접 조회)
- GachaManager: 칩 전용, Relic 뽑기와 무관 — EGachaType.Relic 추가해도 GachaManager 로직에 끼워 넣지 않음
- MinionLevelBox.cs를 RelicLevelBox.cs의 LocalizationManager 적용 참고 파일로 활용

[sync 금지 파일]
- RelicGachaProbabilityDataSource.cs (IGachaProbabilityDataSource 인터페이스 WD에 없음)

[신규 작성 필요 파일]
- RelicGachaProbabilityPopup.cs (RelicManager에서 확률 테이블 직접 가져오는 WD 스타일 팝업)

[BLOCKER — sync 시작 전 기획 확인 필요]
- Feature_Relic 해금 레벨/조건 (ContentUnlockManager에 추가 시 필요)
- Localization 키 목록 (데이터시트에 등록 여부 확인)
- 이 항목들은 TO-DO 주석으로 남기고 나머지 sync 진행
```

---

## Phase별 세부 지시

### Phase 0 — 소스 탐색 준비
```
BD 프로젝트에서 아래 경로를 원격 fetch 또는 로컬 워크트리로 접근:
BunkerDefense/Assets/_Project/1_Scripts/

확인 목표:
1. Core/Managers/Relic/ 하위 파일 목록
2. UI/Relic/ 하위 파일 목록
3. 각 유닛 컨트롤러 (Archon, DrFrost, Marauder, Templer, Turret, Ninja, AirMan, Thor, Vessel, Carrier, Dragoon)의 Relic 관련 메서드 존재 여부
4. SOs/Class/DataSheet/Relic* 파일 목록
5. SOs/SO/DataSheet/Relic* 파일 목록
```

### Phase 1 — 파일 탐색 (키워드 기준)
```
검색 키워드:
  RelicManager, RelicGachaService, RelicMainUI, RelicUpgradeUI,
  RelicGachaMainUI, RelicGachaPopup, RelicData, RelicSaveData,
  ERelicGrade, ERelicSkillType,
  DragoonLaserBind, ZeusRapidFire, MarauderShotgunBlast, TemplerMultiHit,
  TurretDelayedExplosion, NinjaMythic, AirManWindExtra, ThorElectricPull,
  VesselDefensiveShield, CarrierSpecialInterceptor, DrFrostBlizzardGrowth

추가 탐색:
- 위 키워드로 grep된 파일 외 연쇄 의존 파일 (import/using 역추적)
- RelicBoxData*, RelicDropData*, RelicWeightData*, RelicRotateTable*,
  RelicPityData*, RelicRankupData*, RelicGachaConfig*
```

### Phase 2 — 병렬 분석
```
각 파일에 대해 분석:
1. BD 패턴 → WD 패턴 변환 목록 (ServiceAccessor, MessageBroker, UIBase 등)
2. WD에 없는 의존성 (인터페이스, 유틸 클래스) 목록
3. 로컬라이제이션 적용 필요 문자열 목록
4. 서버 API 호출 위치 목록 (ServerLoadingPopupUI 패턴 적용 위치)
5. DOTween 사용 위치 (ToUniTask() → AsyncWaitForCompletion() 교체 위치)
```

### Phase 3 — sync 계획 생성
```
아래 Relic_sync_계획.md의 sync 순서(Phase 1~9)를 기반으로 SYNC_PLAN.md 생성.

각 파일 항목에:
- 원본 경로 (BD)
- 대상 경로 (WD)
- 변환 필요 항목 목록
- 예상 복잡도 (Low/Medium/High)
- BLOCKER 여부 명시

특히 DamageCalculationManager.RelicEffect.cs는 lazy-init 패턴 적용을 계획에 명시.
```

### Phase 4 — sync 실행
```
계획 검토 후 "sync 시작" 확인 받은 뒤 진행.

실행 순서:
1. Phase 1 (Enum/타입) → 컴파일 확인
2. Phase 2 (DataSheet/SO) → 컴파일 확인
3. Phase 3 (RelicManager, RelicGachaService, DamageCalculationManager.RelicEffect.cs)
4. Phase 4 (Managers.cs, ContentUnlockManager, RedDotManager 등)
5. Phase 5 (UI 파일들, RelicGachaProbabilityPopup 신규 작성 포함)
6. Phase 6 (LobbyMainUI, UnitUpgradeUI, TargetDisplayComponent case 추가)
7. Phase 7 (UnitController virtual 메서드 + 11개 유닛 신화 스킬)
8. Phase 8 (JsonToSO.cs 에디터 도구)

각 Phase 완료 후:
- 컴파일 에러 목록 확인
- BLOCKER 항목은 TODO 주석 처리 후 계속 진행
```

### Phase 5a — 프리팹 목록 생성
```
BD/Assets/Prefabs 또는 BD/Assets/_Project/Prefabs/UI/Relic/ 하위에서
sync 필요한 프리팹 목록 문서 생성.

포함 항목:
- UI 프리팹 (RelicMainUI, RelicUpgradeUI, RelicGachaMainUI, RelicGachaPopup 등)
- 컴포넌트 프리팹 (RelicIcon, RelicDisplayComponent 등)
- 유물 아이콘 스프라이트 아틀라스
- 뽑기 연출 애니메이션 클립
- 각 항목의 BD 경로, WD 목적지 경로, GUID 충돌 여부
```

---

## 완료 기준

아래 항목이 모두 충족되면 sync 완료:

- [ ] WD에서 컴파일 에러 0개 (BLOCKER 주석 제외)
- [ ] RelicManager `InitializeAsync()` 정상 호출 확인
- [ ] 뽑기 1회 실행 → `RelicGachaDrawn` 이벤트 발행 확인
- [ ] 유물 장착 → `DamageCalculationManager.GetRelicUnitDamageBonus()` 값 반영 확인
- [ ] `TargetDisplayComponent`에서 `ETargetItemType.Relic` case 처리 확인
- [ ] BLOCKER 항목 TODO 주석으로 전부 마킹됨
- [ ] Phase 9 프리팹 sync 작업 목록 생성됨 (실제 sync은 별도 작업)

---

## 참고 문서

- `Relic_sync_계획.md` — 전체 파일 목록, 변환 규칙, 체크리스트
- `PotingAgentDocs/commands/sync.md` — /sync 슬래시 커맨드
- `PotingAgentDocs/docs/WD_SYNC_GUIDE.md` — WD sync 전반 가이드
- `PotingAgentDocs/docs/SYNC_PROMPT_TEMPLATE.md` — 범용 sync 프롬프트 템플릿
- `PotingAgentDocs/docs/phases/` — 페이즈별 독립 실행 문서
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/DamageCalculationManager.ChipEffect.cs` — lazy-init 패턴 참고
- `WiggleDefender/Assets/_Project/1_Scripts/UI/Minion/Upgrade/MinionLevelBox.cs` — LocalizationManager 패턴 참고
