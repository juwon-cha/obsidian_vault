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
- Managers.cs priority: RelicManager는 334 ("Lobby") — 삽입 위치: ChipEffectManager(333) 다음 줄
- GetManager 패턴: BaseManager 상속 클래스 내부에서는 GetManager<T>() 단축형 사용 (ChipEffect.cs 실제 패턴)
  → 외부에서는 Managers.Instance.GetManager<T>(), 내부에서는 GetManager<T>()
- DamageCalculationManager.RelicEffect.cs: lazy-init 필수 (priority 175 vs RelicManager 334)
  → if (_relicManager == null) _relicManager = GetManager<RelicManager>();  // 단축형
- ETargetItemType.Relic: 이미 존재 — 추가 금지. TargetDisplayComponent.cs switch에 case만 추가
- EAcquisitionRouteType.RelicGacha: WD에 존재하는 enum에 추가 필요
  → 로컬라이제이션 키: route_relicgacha, AcquisitionRouteManager.GetTargetUIType() switch에도 case 추가
- Core/Gacha/ 폴더: WD에 없음 → RelicGachaProbabilityPopup.cs 신규 작성으로 대체
- GachaManager: 칩 전용 — EGachaType.Relic 추가해도 GachaManager 로직 수정 금지
- ContentUnlockManager._unlockConditions 배열 (line ~253)에 Feature_Relic 조건 추가
- RedDotManager.EnsureEssentialNodes()에 Lobby.Relic.*, Lobby.Relic.RelicGacha.* 노드 추가
- UnitController 신화 스킬 훅: StartBehavior() 말미에 ApplyRelicSkills() 호출
  → InitializeAsync() 아님 주의 (유닛 데이터 설정 이후이므로 StartBehavior가 올바른 위치)
- Archon: 기존 partial 14개 — ArchonController.RelicSkill.cs 신규 partial 추가, LaserType.RelicFan은 Types.cs에 추가

[sync 금지 파일]
- RelicGachaProbabilityDataSource.cs (IGachaProbabilityDataSource 인터페이스 WD에 없음)

[신규 작성 필요 파일]
- RelicGachaProbabilityPopup.cs (RelicManager에서 확률 테이블 직접 조회하는 WD 스타일 팝업)
- ArchonController.RelicSkill.cs (Archon 전용 신규 partial)

[BLOCKER — sync 시작 전 확인 필수, TODO 주석으로 마킹 후 진행]
- [BLOCKER-1] Feature_Relic 해금 레벨 (ContentUnlockManager _unlockConditions 배열)
- [BLOCKER-2] Localization 키 17종 (relic_* 접두사) 데이터시트 등록 여부
- [BLOCKER-3] route_relicgacha 로컬라이제이션 키 등록 여부
- [BLOCKER-4] 신화 스킬 rank 0/5/10 effect 정의서 — arg1~7 매핑값 (Phase 7 진입 전 BD 소스 확인 필수)
- [BLOCKER-5] 프리팹/스프라이트 에셋 (Phase 9, C# 완성 후 별도)
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
아래 Relic_SYNC_PLAN.md의 sync 순서(Phase 1~9)를 기반으로 SYNC_PLAN.md 생성.

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
   - ERelicGrade, ERelicSkillType, ECurrencyType(Relic 재화), EGachaType.Relic
   - EAcquisitionRouteType.RelicGacha  ← ✅ WD에 존재하는 enum에 추가
   - Feature_Relic (TODO: 해금 레벨 BLOCKER-1)
   - GameEventTypes 6종

2. Phase 2 (DataSheet/SO) → 컴파일 확인

3. Phase 3 (RelicManager, RelicGachaService, DamageCalculationManager.RelicEffect.cs)
   - DamageCalculationManager.RelicEffect.cs: GetManager<T>() 단축형 사용
   - if (_relicManager == null) _relicManager = GetManager<RelicManager>();

4. Phase 4 (기존 매니저 연동)
   - Managers.cs: ChipEffectManager(333) 다음 줄에 RelicManager(334) 추가
   - ContentUnlockManager.cs: _unlockConditions 배열 line ~253에 Feature_Relic 추가
   - RedDotManager.cs: EnsureEssentialNodes() 튜플 배열에 4개 노드 추가
   - AcquisitionRouteManager.cs: GetTargetUIType() switch에 RelicGacha case 추가

5. Phase 5 (UI 파일들, RelicGachaProbabilityPopup 신규 작성 포함)
   - 모든 하드코딩 문자열 → LocalizationManager.GetLocalizedText("relic_*") (BLOCKER-2)
   - async void → async UniTaskVoid 전환 확인
   - DOTween.ToUniTask() → AsyncWaitForCompletion() 전환 확인

6. Phase 6 (LobbyMainUI, UnitUpgradeUI, TargetDisplayComponent case 추가)

7. Phase 7 (신화 스킬) — BLOCKER-4 확인 후 진입
   - UnitController.StartBehavior() 말미에 ApplyRelicSkills() 추가
   - Archon: ArchonController.RelicSkill.cs 신규 partial, LaserType.RelicFan은 Types.cs에 추가
   - 11개 유닛 각각 RelicSkillType 프로퍼티 + OnApplyRelicRankEffect() override

8. Phase 8 (JsonToSO.cs 에디터 도구)

각 Phase 완료 후:
- 컴파일 에러 목록 확인
- BLOCKER 항목은 // TODO(BLOCKER-N): 설명 형식으로 주석 처리 후 계속 진행
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

- [ ] WD에서 컴파일 에러 0개 (BLOCKER TODO 주석 제외)
- [ ] RelicManager `InitializeAsync()` 정상 호출 확인
- [ ] 뽑기 1회 실행 → `RelicGachaDrawn` 이벤트 발행 확인
- [ ] 유물 장착 → `DamageCalculationManager.GetRelicUnitDamageBonus()` null-safe 반환 확인
- [ ] `TargetDisplayComponent`에서 `ETargetItemType.Relic` case 처리 확인
- [ ] `AcquisitionRouteManager` → `EAcquisitionRouteType.RelicGacha` → `RelicGachaMainUI` 연결 확인
- [ ] `RedDotManager` → `Lobby.Relic.*` 노드 4개 등록 확인
- [ ] BLOCKER-1~5 항목 전부 `// TODO(BLOCKER-N):` 주석으로 마킹됨
- [ ] Phase 9 프리팹 목록 문서 생성됨 (`{OUTPUT_DIR}/Relic_PREFAB_PACKAGE_LIST.md`)
- [ ] DOTween `AsyncWaitForCompletion()` 전환 완료 (ToUniTask 0개)
- [ ] `async void` 0개 (async UniTaskVoid로 전환 완료)

---

## 참고 문서

- `~/Documents/obsidian_vault/Sync/2026-05-03_Relic/Relic_SYNC_PLAN.md` — 전체 파일 목록, 변환 규칙, 체크리스트
- `~/.claude/commands/sync.md` — /sync 슬래시 커맨드 (글로벌)
- `~/Documents/obsidian_vault/SyncAgentDocs/docs/WD_SYNC_GUIDE.md` — WD sync 전반 가이드
- `~/Documents/obsidian_vault/SyncAgentDocs/docs/SYNC_PROMPT_TEMPLATE.md` — 범용 sync 프롬프트 템플릿
- `~/Documents/obsidian_vault/SyncAgentDocs/docs/phases/` — 페이즈별 독립 실행 문서
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/DamageCalculationManager.ChipEffect.cs` — lazy-init + GetManager<T>() 단축형 패턴 참고
- `WiggleDefender/Assets/_Project/1_Scripts/UI/Minion/Upgrade/MinionLevelBox.cs` — LocalizationManager 패턴 참고
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/RedDotManager.cs` — EnsureEssentialNodes() 노드 추가 위치 및 패턴 참고
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Managers/ContentUnlockManager.cs` — _unlockConditions 배열 (line ~253) 추가 위치 참고
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Controllers/Archon/ArchonController.Types.cs` — LaserType enum 추가 위치 참고
- `WiggleDefender/Assets/_Project/1_Scripts/Core/Controllers/BaseClass/UnitController.cs` — StartBehavior() 훅 포인트 참고
