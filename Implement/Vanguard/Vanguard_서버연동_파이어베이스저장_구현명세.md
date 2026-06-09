# Vanguard 서버 API 연동 & 파이어베이스 데이터 저장 구현 명세

> 대상: 클라이언트 개발자
> 범위: Vanguard(카오스 페스티벌, 주간 PvP) 10개 서버 엔드포인트 연동 + `ESaveDataType.Vanguard` 파이어베이스 저장
> 기준 서버 명세: `vanguard-api-spec_2026-06-06` (기준 브랜치 `wiggle`)
> 기준 클라 코드: `Assets/_Project/1_Scripts/Core/Managers/Vanguard/*`, `.../Server/VanguardServerService.cs`
> 이 문서 하나만으로 서버 API 연동과 파이어베이스 저장을 완결할 수 있도록 작성됨.

---

## 0. 전체 아키텍처 — 가장 먼저 이해할 것

Vanguard 데이터는 **물리적으로는 둘 다 Firebase**지만 **논리적으로 완전히 다른 두 저장소**에 나뉘어 산다. 어떤 데이터가 어느 쪽인지 헷갈리면 전부 깨지므로 이 구분이 핵심이다.

### 0.1 두 개의 저장소

| | ① Vanguard 서버 컬렉션 | ② 클라 gameData 블롭 |
|---|---|---|
| 무엇 | `vanguard_player`, `vanguard_season`, `vanguard_live_clone`, `vanguard_record_clone`, `vanguard_battle`, `vanguard_duel_session` | `ESaveDataType.Vanguard` 키의 JSON 한 덩어리 (= `VanguardSaveData`) |
| 누가 씀 | **Vanguard 클라우드 함수만** | **클라이언트만** |
| 클라 접근 | 10개 POST 엔드포인트로만 트리거 (직접 read/write 불가) | `SaveDataManager.SaveDataAsync/LoadDataAsync` → `/gameData/save`·`/loadAll` |
| 권위 | 서버 권위 (점수/티어/카오스/랭킹/매칭/클론/시즌/멱등) | 클라 권위 (보상지급/재화/카드/로드아웃/강화/순찰/패스/상점) |
| 본 문서 섹션 | §1~§4 (서버 API 연동) | §5 (파이어베이스 저장) |

### 0.2 권위 모델 (서버 명세 0.5 그대로)

- **서버 권위**: 점수·티어·카오스·랭킹·매칭 상대 배정·클론 저장·시즌 자동 생성·전투 결과 멱등 처리.
- **클라 권위**: 보상 지급·재화 차감·`extra_reward`·듀얼 코인·자동순찰/공격력/슬롯·스테이지 보정·**카드/보너스카드**·광폭화·레벨45 해금.
- 서버는 전투를 **재시뮬하지 않고 `checksum` 검증도 하지 않는다.** 점수는 서버가 승/패 + 클라 플래그(`swift`/`comeback`)로 직접 계산하므로 점수 숫자 위조는 불가.

> **카드 지급 결론(합의됨)**: 시즌 카드(밴 아닌 유닛 카드)는 **클라 권위로 클라가 지급**하고 ②에 저장한다. 서버 카드 인벤토리/엔드포인트는 만들지 않는다. (§4.7 참조)

### 0.3 서비스 레이어 구조 (기존 코드 패턴)

```
UI / 플로우
   └─ VanguardManager (BaseManager)            ← 모드 진입점, 서브서비스 조합
        ├─ VanguardSeasonService (POCO)        ← enter + 시즌 리셋 판정
        ├─ VanguardRankService   (POCO)        ← 티어/점수 캐시(②) + 해금 판정
        ├─ VanguardStatService   (POCO)        ← 요새 공격력 강화(②)
        └─ (추가) 로드아웃/칩/상점/패스/순찰/카드 서비스
   └─ ServerManager.GetManager<ServerManager>()
        └─ VanguardServerService : BaseServerService   ← 10개 엔드포인트 실제 통신
             └─ RequestApiAsync<ServerResponse<T>>(endpoint, body)
                  └─ ServerManager.RequestApiWithAutoReloginAsync (암호화/재시도/재로그인/네트워크대기)
```

- **HTTP·암호화·재시도·자동 재로그인·네트워크 대기**는 전부 `BaseServerService.RequestApiAsync` → `ServerManager.RequestApiWithAutoReloginAsync`가 처리한다. 새 엔드포인트마다 직접 HTTP를 짜지 않는다.
- 베이스 URL은 `FirebaseRemoteConfigManager.GetServerUrl()` 동적 조회(폴백 `https://wiggledefender.web.app/v1`). 엔드포인트 경로 앞에 자동으로 붙는다.
- 요청 바디는 `MiddleWare.decryptData`로 복호화되는 암호화 페이로드로 전송된다(프레임워크가 처리). 본 문서의 JSON은 모두 **복호화된 평문** 기준.

### 0.4 현재 구현 상태 → 목표

| 항목 | 현재 | 목표 |
|---|---|---|
| `VanguardServerService` | `enter`, `match/result` 2개 **placeholder** | 명세 10개 엔드포인트 |
| 엔드포인트 경로 | `/vanguard/match/result` 등 임시 | 명세 경로(`/vanguard/battle/result` 등)로 교체 |
| DTO | `rankingStartDate` 1필드 등 골격 | snake_case 매핑 완비 |
| 시즌 판정 키 | `rankingStartDate` 문자열 비교 | `season_id` 비교 |
| `VanguardSaveData` | 4필드 | 클라 권위 데이터 전체(§5.2) |

---

## 1. 공통 규약 & 응답 구조

### 1.1 인증 / 호출 규칙

- 모든 Vanguard API는 로그인 세션 필수(`MiddleWare.sessionCheck`). 세션 만료 시 `9997 SESSION_EXPIRED` → 프레임워크가 `SessionExpiredPopupUI` 자동 처리.
- 모든 요청은 `POST` + JSON 바디. 빈 바디는 `{}`.
- 베이스 경로 `/v1/vanguard` (BASE_URL이 `/v1`까지 포함하므로 서비스에는 `/vanguard/...`로 등록).
- 레벨 45 해금 게이트는 **클라가 판정**(서버 미검증). 서버는 `7202`를 정의만 하고 쓰지 않는다.
- 시각 값은 전부 UTC ISO 8601.
- 시즌 운영: **화 00:00 ~ 수 24:00 UTC (48시간)**, 매주 반복. 그 외 시간 입장 시 `7201`.

### 1.2 응답 공통 구조 — `ServerResponse<T>`

서버 와이어 포맷은 `{ "result": { "code", "message", "data" } }`이며, **프레임워크(`RequestApiWithAutoReloginAsync`)가 `result` 봉투를 벗겨 `ServerResponse<T>`로 역직렬화**한다. 따라서 우리가 정의할 DTO는 **`data` 페이로드만** 모델링하면 된다.

```csharp
// Core/Data/Server/ServerCommonTypes.cs (기존, 수정 불필요)
public class ServerResponse<T>
{
    public int code;            // 200 성공, 그 외 에러코드
    public string message;
    public string originalUrl;
    public string utcTimeString;
    public long utcTime;
    public bool exitSignal;
    public bool hasError;       // 프레임워크가 set (code != 200 또는 통신 실패)
    public T data;              // ← 엔드포인트별 응답
}
```

호출 측 표준 가드:

```csharp
var res = await serverManager.SomeVanguardApiAsync(...);
if (res == null || res.hasError || res.data == null)
{
    RLog.LogError($"[Vanguard] API 실패 code={res?.code} msg={res?.message}");
    // 7201/7203/7206 등 도메인 분기는 res.code로 처리 (§1.3)
    return;
}
var data = res.data; // 안전
```

### 1.3 에러 코드 사전

**글로벌**

| 코드 | 식별자 | 처리 |
|---|---|---|
| 100 | UNKNOWN_ERROR | 일반 에러 팝업 |
| 101 | BANNED_USER | 차단 안내 |
| 102 | EXPIRED_TOKEN | 자동 재로그인(프레임워크) |
| 103 | UNKNOWN_USER_ERROR | 유저 조회 실패 |
| 9990 | MAINTENANCE | 점검 팝업 |
| 9997 | SESSION_EXPIRED | `SessionExpiredPopupUI` 자동 |
| 9998 | CAN_NOT_CALL | 호출 차단 |

**Vanguard 도메인 (7201~7211)**

| 코드 | 식별자 | 클라 처리 |
|---|---|---|
| 7201 | VANGUARD_SEASON_CLOSED | "입장 시간 아님" 안내, 로비 비활성 |
| 7202 | VANGUARD_NOT_UNLOCKED | (정의만, 서버 미사용) 레벨45는 클라 판정 |
| 7203 | VANGUARD_MATCH_NOT_FOUND | 매칭 재시도/안내 |
| 7204 | VANGUARD_DUAL_TOKEN_INSUFFICIENT | (정의만) 듀얼 코인은 클라 검사 |
| 7206 | VANGUARD_BATTLE_INVALID | 세션 만료/입장 선행 안 됨 → enter 재호출 유도 |
| 7207 | VANGUARD_RESULT_INVALID | (정의만, checksum 미사용으로 미발생) |
| 7208 | VANGUARD_TIER_LOCKED | 리더보드/듀얼 미해금 안내 |
| 7209 | VANGUARD_DUEL_IN_PROGRESS | 듀얼 대기 중 일반매칭 차단 |
| 7210 | VANGUARD_DUEL_REFRESH_EXHAUSTED | 새로고침 버튼 비활성 |
| 7211 | VANGUARD_DUEL_CANDIDATE_INVALID | 듀얼 세션 재시작 유도 |

> `7205`는 존재하지 않음(매칭은 `extra_reward`로 막지 않음).

### 1.4 에러 로컬라이즈

- 패턴: `server_error_{code}` (예: `server_error_7201`). 로컬라이즈 키를 추가하고 `LocalizationManager.GetLocalizedText($"server_error_{res.code}")`로 노출.
- 9997은 프레임워크가 `SessionExpiredPopupUI`를 자동 띄우므로 별도 처리 불필요.

---

## 2. 서버 API 연동 — 구현 골격 3단계

새 엔드포인트 1개를 붙이는 작업은 항상 다음 3곳을 건드린다.

1. **`VanguardServerService`** — 엔드포인트 상수 + 메서드 추가 (`RequestApiAsync` 호출).
2. **`ServerManager`** — 동일 시그니처 public 래퍼 추가(필드 `_vanguardServerService`는 이미 생성·초기화됨).
3. **DTO** — 요청/응답 클래스 (`[Serializable]` + snake_case `[JsonProperty]`).

### 2.1 `VanguardServerService` 작성 패턴 (공통 템플릿)

`VanguardServerService.cs`는 현재 placeholder다. 아래 패턴으로 10개를 채운다. (기존 `EnterVanguardAsync` 동형)

```csharp
public class VanguardServerService : BaseServerService
{
    // §3의 각 엔드포인트 경로 (BASE_URL이 /v1 포함 → /vanguard 부터)
    private const string ENTER_ENDPOINT             = "/vanguard/enter";
    private const string RESET_LAST_SEASON_ENDPOINT = "/vanguard/resetLastSeasonData";
    private const string LOADOUT_SAVE_ENDPOINT      = "/vanguard/loadout/save";
    private const string MATCH_FIND_ENDPOINT        = "/vanguard/match/find";
    private const string BATTLE_RESULT_ENDPOINT     = "/vanguard/battle/result";
    private const string RANK_ENDPOINT              = "/vanguard/rank";
    private const string DUEL_START_ENDPOINT        = "/vanguard/duel/start";
    private const string DUEL_REFRESH_ENDPOINT      = "/vanguard/duel/refresh";
    private const string DUEL_CONFIRM_ENDPOINT      = "/vanguard/duel/confirm";
    private const string DUEL_ABANDON_ENDPOINT      = "/vanguard/duel/abandon";

    // 공통 호출 헬퍼 — 초기화 가드 + 예외 래핑
    private async UniTask<ServerResponse<T>> CallAsync<T>(string endpoint, JObject body) where T : class
    {
        if (!IsInitialized)
        {
            LogError("서비스가 초기화되지 않았습니다.");
            return new ServerResponse<T> { hasError = true, message = "Service not initialized" };
        }
        try
        {
            LogInfo(endpoint);
            return await RequestApiAsync<ServerResponse<T>>(endpoint, body ?? new JObject());
        }
        catch (Exception ex)
        {
            LogError($"{endpoint} 오류: {ex.Message}");
            return new ServerResponse<T> { hasError = true, message = ex.Message };
        }
    }

    public UniTask<ServerResponse<VanguardEnterResponse>> EnterVanguardAsync(VanguardEnterRequest req)
        => CallAsync<VanguardEnterResponse>(ENTER_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardEmptyResponse>> ResetLastSeasonDataAsync()
        => CallAsync<VanguardEmptyResponse>(RESET_LAST_SEASON_ENDPOINT, new JObject());

    public UniTask<ServerResponse<VanguardLoadoutSaveResponse>> SaveLoadoutAsync(VanguardLoadoutSaveRequest req)
        => CallAsync<VanguardLoadoutSaveResponse>(LOADOUT_SAVE_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardMatchFindResponse>> MatchFindAsync(VanguardMatchFindRequest req)
        => CallAsync<VanguardMatchFindResponse>(MATCH_FIND_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardBattleResultResponse>> SubmitBattleResultAsync(VanguardBattleResultRequest req)
        => CallAsync<VanguardBattleResultResponse>(BATTLE_RESULT_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardRankResponse>> GetRankAsync(VanguardRankRequest req)
        => CallAsync<VanguardRankResponse>(RANK_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardDuelStartResponse>> DuelStartAsync()
        => CallAsync<VanguardDuelStartResponse>(DUEL_START_ENDPOINT, new JObject());

    public UniTask<ServerResponse<VanguardDuelRefreshResponse>> DuelRefreshAsync(VanguardDuelIdRequest req)
        => CallAsync<VanguardDuelRefreshResponse>(DUEL_REFRESH_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardDuelConfirmResponse>> DuelConfirmAsync(VanguardDuelConfirmRequest req)
        => CallAsync<VanguardDuelConfirmResponse>(DUEL_CONFIRM_ENDPOINT, ToBody(req));

    public UniTask<ServerResponse<VanguardEmptyResponse>> DuelAbandonAsync(VanguardDuelIdRequest req)
        => CallAsync<VanguardEmptyResponse>(DUEL_ABANDON_ENDPOINT, ToBody(req));

    // 요청 DTO → JObject. null 안전. (snake_case 직렬화기 사용 — 아래 주의 참조)
    private static JObject ToBody(object req)
        => req == null ? new JObject() : JObject.FromObject(req);
}
```

> **snake_case 직렬화 주의**: 서버는 요청/응답 모두 snake_case를 기대한다. 본 문서 DTO는 요청·응답 모든 필드에 `[JsonProperty("snake_case")]`를 명시하므로 기본 `JObject.FromObject`로 충분하다. (전역 snake_case `ContractResolver`를 쓰면 `[JsonProperty]` 생략 가능하나, 혼선 방지를 위해 명시 권장.)

### 2.2 `ServerManager` public 래퍼 패턴

`ServerManager`의 `#region Vanguard API`에 1:1 래퍼를 추가한다(기존 `EnterVanguardAsync` 동형). `_vanguardServerService`는 이미 생성·초기화되어 있다.

```csharp
#region Vanguard API
public async UniTask<ServerResponse<VanguardEnterResponse>> EnterVanguardAsync(VanguardEnterRequest req)
{
    if (_vanguardServerService == null)
        return new ServerResponse<VanguardEnterResponse> { hasError = true, message = "Server not initialized" };
    return await _vanguardServerService.EnterVanguardAsync(req);
}
// ... 나머지 9개 동일 패턴 (ResetLastSeasonData/SaveLoadout/MatchFind/SubmitBattleResult/GetRank/DuelStart/DuelRefresh/DuelConfirm/DuelAbandon)
#endregion
```

> 기존 placeholder인 `SubmitVanguardMatchResultAsync` / `VanguardMatchResultRequest/Response`는 `battle/result`로 대체되므로 **제거하거나 새 시그니처로 교체**한다. `VanguardManager.ReportMatchResultAsync`가 이를 호출하므로 같이 수정(§4.3).

---

## 3. 엔드포인트별 상세 + DTO

> 모든 DTO는 `[Serializable]` + Newtonsoft `[JsonProperty("snake_case")]`. 응답은 `data` 페이로드만 모델링.

공통 빈 응답 / 공통 서브 타입:

```csharp
[Serializable] public class VanguardEmptyResponse { }

[Serializable]
public class VanguardLoadoutDto
{
    [JsonProperty("turret_slots")] public int[] turretSlots;     // 장착 터렛 id 배열
    [JsonProperty("chips")]        public JObject chips;          // { "slot1": { "grade": "legend" }, ... } 자유형
}

[Serializable]
public class VanguardOpponentDto
{
    [JsonProperty("clone_type")]       public string cloneType;       // "LIVE" | "RECORD"
    [JsonProperty("display_nickname")] public string displayNickname; // LIVE=실닉 / RECORD=랜덤닉
    [JsonProperty("profile_icon")]     public int profileIcon;
    [JsonProperty("profile_border")]   public int profileBorder;
    [JsonProperty("tier")]             public int tier;
    [JsonProperty("atk")]              public int atk;
    [JsonProperty("chip_count")]       public int chipCount;
    [JsonProperty("loadout")]          public VanguardLoadoutDto loadout; // 고스트 시뮬용
}
```

### 3.1 `POST /vanguard/enter` — 로비 진입 / 재조회

시즌 상태 + 밴/주간터렛 + 내 티어/점수/카오스 + 직전 시즌 정산을 통합 반환. 신규/새 시즌이면 서버가 브론즈 II 문서 생성 + 시즌 자동생성 + Live Clone 갱신. **모드 진입의 시작점.**

**Request**
```csharp
[Serializable]
public class VanguardEnterRequest
{
    [JsonProperty("loadout")]        public VanguardLoadoutDto loadout;  // 선택, Live Clone 저장
    [JsonProperty("profile_icon")]   public int? profileIcon;            // 선택
    [JsonProperty("profile_border")] public int? profileBorder;          // 선택
    [JsonProperty("atk")]            public int? atk;                    // 선택, 매칭/클론 메타
}
```

**Response (`data`)**
```csharp
[Serializable]
public class VanguardEnterResponse
{
    [JsonProperty("season_id")]                public string seasonId;            // "2026-W23"
    [JsonProperty("end_date")]                 public string endDate;             // 수 24:00 UTC ISO8601
    [JsonProperty("ban_unit_ids")]             public int[] banUnitIds;           // 이번 시즌 밴 2종
    [JsonProperty("weekly_turret_ids")]        public int[] weeklyTurretIds;      // 11 - 2 = 9
    [JsonProperty("my_tier")]                  public int myTier;
    [JsonProperty("my_score")]                 public int myScore;
    [JsonProperty("score_in_division")]        public int scoreInDivision;
    [JsonProperty("chaos")]                    public int chaos;
    [JsonProperty("chaos_capped")]             public bool chaosCapped;
    [JsonProperty("highest_tier_this_season")] public int highestTierThisSeason;
    [JsonProperty("win_streak")]               public int winStreak;
    [JsonProperty("lose_streak")]              public int loseStreak;
    [JsonProperty("duel_state")]               public string duelState;           // "IDLE" | "WAITING"
    [JsonProperty("is_leaderboard_unlocked")]  public bool isLeaderboardUnlocked;
    [JsonProperty("is_auto_patrol_unlocked")]  public bool isAutoPatrolUnlocked;
    [JsonProperty("is_duel_unlocked")]         public bool isDuelUnlocked;
    [JsonProperty("prev_season_settlement")]   public VanguardSettlementDto prevSeasonSettlement; // null 가능
}

[Serializable]
public class VanguardSettlementDto
{
    [JsonProperty("season_id")] public string seasonId;
    [JsonProperty("rank")]      public int rank;
    [JsonProperty("tier")]      public int tier;
    [JsonProperty("score")]     public int score;
    [JsonProperty("chaos")]     public int chaos;
}
```

- `prev_season_settlement`: 직전 시즌 미수령 보상이 있으면 객체, 없거나 이미 수령했으면 `null`.
- **에러**: 시즌 시간 외 `7201`.

### 3.2 `POST /vanguard/resetLastSeasonData` — 직전 시즌 보상 수령 확정

보상은 **클라가 지급(§4.6)** 하고, 서버는 직전 시즌 문서의 `reward_claimed`만 set해 중복 수령을 막는다. 호출 후 다음 `enter`의 `prev_season_settlement`는 `null`.

- Request: `{}` (DTO 불필요)
- Response: `VanguardEmptyResponse`
- 에러: 세션 에러만.

### 3.3 `POST /vanguard/loadout/save` — 편성 저장 (Live Clone 동기화)

편성/칩 변경 시 Live Clone 동기화 전용. **재화 차감 없음.**

**Request**
```csharp
[Serializable]
public class VanguardLoadoutSaveRequest
{
    [JsonProperty("loadout")]        public VanguardLoadoutDto loadout;
    [JsonProperty("profile_icon")]   public int? profileIcon;
    [JsonProperty("profile_border")] public int? profileBorder;
    [JsonProperty("atk")]            public int? atk;
}
```
**Response**
```csharp
[Serializable] public class VanguardLoadoutSaveResponse { [JsonProperty("saved")] public bool saved; }
```
- 에러: 시즌 시간 외 `7201`.

### 3.4 `POST /vanguard/match/find` — 일반 매칭

상대 클론 1명 배정 + 전투 세션 생성. 시작 시점 본인 스냅을 Record 풀에 추가.

**Request**
```csharp
[Serializable] public class VanguardMatchFindRequest { [JsonProperty("atk")] public int? atk; }
```
**Response (`data`)**
```csharp
[Serializable]
public class VanguardMatchFindResponse
{
    [JsonProperty("battle_id")]  public string battleId;
    [JsonProperty("status")]     public string status;     // "MATCHED"
    [JsonProperty("match_seed")] public long matchSeed;      // 클라 고스트 결정적 시뮬 시드
    [JsonProperty("opponent")]   public VanguardOpponentDto opponent;
}
```
- `match_seed` + `opponent.loadout`으로 클라가 상대 고스트를 즉석 시뮬레이션(서버 리플레이 저장 없음).
- **에러**: `7201`(시간 외) / `7206`(enter 선행 안 됨=시즌 문서 없음) / `7209`(듀얼 대기 중) / `7203`(후보 전무).

### 3.5 `POST /vanguard/battle/result` — 전투 결과 제출

3판 2선승 결과를 받아 점수/티어/카오스/연승 정산. **멱등성 보장**. 보상 지급은 클라(응답에 보상 필드 없음).

**Request**
```csharp
[Serializable]
public class VanguardBattleResultRequest
{
    [JsonProperty("battle_id")]    public string battleId;       // match/find 또는 duel/confirm 발급값
    [JsonProperty("match_result")] public VanguardRoundResult matchResult;
    [JsonProperty("swift")]        public bool swift;             // 클라 판정 보너스 플래그
    [JsonProperty("comeback")]     public bool comeback;
}

[Serializable]
public class VanguardRoundResult
{
    [JsonProperty("my_round_wins")]  public int myRoundWins;
    [JsonProperty("opp_round_wins")] public int oppRoundWins;     // 승패 = my > opp (무승부 없음)
}
```
**Response (`data`)**
```csharp
[Serializable]
public class VanguardBattleResultResponse
{
    [JsonProperty("win")]               public bool win;
    [JsonProperty("match_outcome")]     public string matchOutcome;    // "WIN" | "LOSE"
    [JsonProperty("score_breakdown")]   public VanguardScoreBreakdown scoreBreakdown;
    [JsonProperty("new_tier")]          public int newTier;
    [JsonProperty("tier_changed")]      public string tierChanged;     // "UP" | "DOWN" | "NONE"
    [JsonProperty("score_in_division")] public int scoreInDivision;
    [JsonProperty("chaos")]             public int chaos;
    [JsonProperty("chaos_capped")]      public bool chaosCapped;
    [JsonProperty("win_streak")]        public int winStreak;
    [JsonProperty("lose_streak")]       public int loseStreak;
}

[Serializable]
public class VanguardScoreBreakdown
{
    [JsonProperty("base")]            public int baseScore;
    [JsonProperty("swift_win")]       public int swiftWin;
    [JsonProperty("comeback_win")]    public int comebackWin;
    [JsonProperty("win_streak")]      public int winStreakBonus;
    [JsonProperty("dual_multiplier")] public int dualMultiplier;   // 듀얼=2, 일반=1
    [JsonProperty("loss_penalty")]    public int lossPenalty;      // 패배 시 음수
    [JsonProperty("point_delta")]     public int pointDelta;       // 최종 반영(카오스 동결 시 0)
}
```
- **멱등**: 이미 `RESOLVED`된 `battle_id` 재제출은 에러가 아니라 **저장된 결과를 그대로 반환**. 점수 중복 반영 없음 → 네트워크 불안정 시 재시도해도 안전.
- **에러**: `7206`(battle_id 없음/소유자 불일치/세션 만료/시즌 문서 없음).

### 3.6 `POST /vanguard/rank` — 리더보드

시즌 누적 글로벌 랭킹 + 내 순위. **골드 III(301) 이상**만 조회.

**Request**
```csharp
[Serializable] public class VanguardRankRequest { [JsonProperty("page")] public int page = 1; } // 50명/페이지
```
**Response (`data`)**
```csharp
[Serializable]
public class VanguardRankResponse
{
    [JsonProperty("leaderboard_id")] public string leaderboardId;
    [JsonProperty("required_tier")]  public int requiredTier;       // 301
    [JsonProperty("ranking")]        public VanguardRankEntry[] ranking;
    [JsonProperty("my_rank")]        public int myRank;             // 20위 밖도 산출
    [JsonProperty("my_tier")]        public int myTier;
    [JsonProperty("my_chaos")]       public int myChaos;
    [JsonProperty("my_score")]       public int myScore;
}

[Serializable]
public class VanguardRankEntry
{
    [JsonProperty("rank")]             public int rank;
    [JsonProperty("gamer_id")]         public string gamerId;
    [JsonProperty("display_nickname")] public string displayNickname;
    [JsonProperty("tier")]             public int tier;
    [JsonProperty("chaos")]            public int chaos;
    [JsonProperty("score")]            public int score;             // 누적 래더 점수
    [JsonProperty("chaos_reached_at")] public string chaosReachedAt; // null 가능
}
```
- 정렬: `score` 내림차순 → 카오스 100 동률은 `chaos_reached_at` 빠른 순.
- **에러**: 티어 < 301 → `7208`.

### 3.7 `POST /vanguard/duel/start` — 듀얼 시작

티어 `-1/0/+1` 후보 3인 제공 + `WAITING` 진입. 듀얼 코인 차감은 클라 권위. 실버 II(201) 이상.

- Request: `{}`
**Response (`data`)**
```csharp
[Serializable]
public class VanguardDuelStartResponse
{
    [JsonProperty("duel_id")]      public string duelId;
    [JsonProperty("refresh_left")] public int refreshLeft;       // 1
    [JsonProperty("expire_at")]    public string expireAt;        // 30분
    [JsonProperty("candidates")]   public VanguardDuelCandidate[] candidates; // 최대 3
}

[Serializable]
public class VanguardDuelCandidate
{
    [JsonProperty("candidate_id")]       public string candidateId;
    [JsonProperty("clone_type")]         public string cloneType;
    [JsonProperty("display_nickname")]   public string displayNickname;
    [JsonProperty("tier")]               public int tier;
    [JsonProperty("profile_icon")]       public int profileIcon;
    [JsonProperty("profile_border")]     public int profileBorder;
    [JsonProperty("atk")]                public int atk;
    [JsonProperty("chip_count")]         public int chipCount;
    [JsonProperty("win_points_preview")] public int winPointsPreview; // 듀얼 ×2 반영, swift/comeback 제외
    // loadout 은 start/refresh 시 미노출 — confirm 응답에서만 공개
}
```
- **에러**: `7201`(시간 외) / `7206`(입장 선행 안 됨) / `7208`(티어 < 201) / `7209`(이미 듀얼 대기 중).

### 3.8 `POST /vanguard/duel/refresh` — 듀얼 후보 새로고침

후보 3인 재생성. 듀얼당 **1회** 한정.

**Request**
```csharp
[Serializable] public class VanguardDuelIdRequest { [JsonProperty("duel_id")] public string duelId; }
```
**Response (`data`)**
```csharp
[Serializable]
public class VanguardDuelRefreshResponse
{
    [JsonProperty("duel_id")]      public string duelId;
    [JsonProperty("refresh_left")] public int refreshLeft;   // 0
    [JsonProperty("candidates")]   public VanguardDuelCandidate[] candidates;
}
```
- **에러**: `7211`(유효 세션/플레이어 없음) / `7210`(이미 새로고침 사용).

### 3.9 `POST /vanguard/duel/confirm` — 듀얼 상대 확정

선택 후보로 DUAL 전투 세션 생성 → `IDLE` 복귀. 이후 결과는 `battle/result`로 제출(승리 점수 ×2).

**Request**
```csharp
[Serializable]
public class VanguardDuelConfirmRequest
{
    [JsonProperty("duel_id")]      public string duelId;
    [JsonProperty("candidate_id")] public string candidateId;
}
```
**Response (`data`)**
```csharp
[Serializable]
public class VanguardDuelConfirmResponse
{
    [JsonProperty("battle_id")]  public string battleId;
    [JsonProperty("match_seed")] public long matchSeed;
    [JsonProperty("opponent")]   public VanguardOpponentDto opponent; // 이 시점에 loadout 공개
}
```
- **에러**: `7211`(유효 세션/플레이어 없음 / candidate_id가 후보에 없음).

### 3.10 `POST /vanguard/duel/abandon` — 듀얼 포기

후보 폐기 + `IDLE` 복귀. 코인 미반환(클라).

- Request: `VanguardDuelIdRequest` (`{ "duel_id" }`)
- Response: `VanguardEmptyResponse`
- 에러: 세션 에러만(대기 세션이 없어도 정상 응답).

---

## 4. 클라이언트 플로우 통합

### 4.1 enter 플로우 (로비 진입의 시작점)

`VanguardManager.EnterSeasonAsync` → `VanguardSeasonService.EnterSeasonAsync`를 명세 응답에 맞게 확장한다. **시즌 판정 키를 `season_id`로 교체**한다.

```csharp
// VanguardSeasonService (확장)
public async UniTask<VanguardEnterResponse> EnterSeasonAsync(VanguardEnterRequest req)
{
    var sm = _getServerManager?.Invoke();
    if (sm == null) return null;

    var res = await sm.EnterVanguardAsync(req);
    if (res == null || res.hasError || res.data == null)
    {
        // res.code == 7201 → 시즌 시간 외: 로비 비활성 + 안내
        RLog.LogError($"[VanguardSeasonService] enter 실패 code={res?.code}");
        return null;
    }

    var data = res.data;

    // 1) 새 시즌 판정 (season_id 비교)
    bool isNewSeason = _saveData.lastSeasonId != data.seasonId;
    if (isNewSeason)
    {
        ResetSeasonProgress(_saveData, data.seasonId);            // §5.4: 클라 권위 항목만 리셋
        await GrantSeasonCardsIfNeededAsync(data.banUnitIds, data.seasonId); // §4.7
    }

    // 2) 서버 권위 캐시 반영 (티어/점수/카오스/연승) — 표시용
    await _rankService.UpdateFromServerAsync(
        (EVanguardTier)data.myTier, data.scoreInDivision,
        data.chaos, data.chaosCapped, data.winStreak, data.loseStreak,
        data.highestTierThisSeason);

    // 3) 밴/주간터렛/해금 플래그는 세션 캐시 (영구저장 불필요, enter마다 갱신)
    _currentBanUnitIds      = data.banUnitIds;
    _currentWeeklyTurretIds = data.weeklyTurretIds;
    _currentEndDateUtc      = data.endDate;

    // 4) 직전 시즌 정산 → 보상 지급 플로우 (§4.6)
    if (data.prevSeasonSettlement != null)
        await ClaimPrevSeasonRewardAsync(data.prevSeasonSettlement);

    await _saveAsync.Invoke();
    return data;
}
```

> **레벨 45 해금**: 서버는 검증하지 않는다. 로비 진입 전 클라가 `PlayerLevel >= 45`를 먼저 게이트한다.

### 4.2 match 플로우

```
match/find → (battle_id, match_seed, opponent.loadout)
   → 클라가 match_seed + opponent.loadout 으로 고스트 즉석 시뮬 (VanguardGhostSim)
   → 3판 2선승 진행, 클라가 swift/comeback 판정
   → battle/result 제출 (멱등)
   → 응답 score_breakdown/new_tier 로 티어 진행 연출 (VanguardTierProgressPopup)
   → 연출 종료 후 RankService 캐시 갱신/저장
```

- **듀얼 대기 중(`duel_state == WAITING`)에는 match/find 금지** → `7209`. enter의 `duel_state`로 사전 차단.
- `swift`/`comeback` 정의(클라 판정): 초고속 = 상대 필드 꿈틀이 ≥50% 남았는데 내가 전멸시킴 / 역전 = 상대가 내 바디 ≥70% 먼저 깠는데 내가 먼저 전멸시킴.

### 4.3 battle/result 제출 (기존 `ReportMatchResultAsync` 교체)

기존 placeholder `VanguardMatchResultRequest/Response`를 §3.5 DTO로 교체하고, `VanguardManager.ReportMatchResultAsync`를 아래로 수정한다.

```csharp
public async UniTask<bool> ReportBattleResultAsync(VanguardBattleResultRequest req)
{
    var sm = GetManager<ServerManager>();
    var uiManager = GetManager<UIManager>();
    if (sm == null || uiManager == null) return false;

    ServerResponse<VanguardBattleResultResponse> res;
    var popup = ServerLoadingPopupUI.Show(LocalizationManager.GetLocalizedText("vanguard_match_result_loading"));
    try { res = await sm.SubmitBattleResultAsync(req); }
    finally { ServerLoadingPopupUI.Hide(); }

    if (res == null || res.hasError || res.data == null)
    {
        RLog.LogError($"[VanguardManager] battle/result 실패 code={res?.code}");
        return false; // 7206 → enter 재호출 유도
    }

    var d = res.data;
    var progressData = new VanguardTierProgressData
    {
        prevTier   = RankService.Tier,
        prevPoints = RankService.CurrentPoints,
        newTier    = (EVanguardTier)d.newTier,
        newPoints  = d.scoreInDivision,
        scoreEntries = ToScoreEntries(d.scoreBreakdown), // breakdown → 표시 줄
    };
    var closed = new UniTaskCompletionSource();
    progressData.onClosed = () => closed.TrySetResult();
    uiManager.Show<VanguardTierProgressPopup>(progressData);
    await closed.Task; // 연출 종료 대기 (연출 중 로비 선갱신 방지)

    // 연출 끝난 뒤 캐시 갱신 (카오스/연승 포함)
    await RankService.UpdateFromServerAsync(
        (EVanguardTier)d.newTier, d.scoreInDivision, d.chaos, d.chaosCapped, d.winStreak, d.loseStreak,
        Math.Max((int)RankService.HighestTier, d.newTier));

    // 승리 시 보상 지급은 클라 권위 (재화/카드 등) — 여기서 처리
    return true;
}
```

### 4.4 duel 플로우

```
duel/start → 후보3 + duel_id (WAITING)
   ├─ (선택) duel/refresh → 후보 재생성 (1회)
   ├─ duel/confirm(candidate_id) → battle_id + opponent.loadout (IDLE 복귀)
   │     → 이후 match 와 동일하게 battle/result 제출 (dual_multiplier=2)
   └─ duel/abandon → 폐기 (IDLE 복귀, 코인 미반환)
```

- 듀얼 코인 차감/검사는 **클라 권위**: start 전 클라가 코인 검사·차감(②에 저장), 부족하면 클라가 막는다(서버 `7204` 미사용).

### 4.5 rank 플로우

- 골드 III(301) 미만이면 버튼 비활성(enter의 `is_leaderboard_unlocked` 또는 `VanguardRankService.IsLeaderboardUnlocked`로 판정). 호출 시 `7208`이면 안내.
- 페이지네이션: `page` 1부터, 50명/페이지.

### 4.6 직전 시즌 보상 (클라 지급 + resetLastSeasonData)

```csharp
async UniTask ClaimPrevSeasonRewardAsync(VanguardSettlementDto s)
{
    if (_saveData.lastRewardClaimedSeasonId == s.seasonId) return; // 로컬 가드

    // 1) 등수(s.rank)/티어(s.tier) 기준 보상 테이블 조회 (VanguardRankingRewardDataSO)
    var rewards = VanguardRankingRewardTable.GetRewards(s.rank, s.tier);
    // 2) 클라가 보상 지급 (RewardClaimPopupUI 패턴 — ModifyCurrency 중복 호출 금지)
    uiManager.Show<RewardClaimPopupUI>(rewards, titleKey, descKey);
    // 3) 서버에 수령 확정 → 다음 enter prev_season_settlement = null
    await GetManager<ServerManager>().ResetLastSeasonDataAsync();

    _saveData.lastRewardClaimedSeasonId = s.seasonId;
    await _saveAsync.Invoke();
}
```

- **순서 중요**: 보상 지급 → `resetLastSeasonData`. 지급 전 reset하면 보상 유실 위험. `reward_claimed` set 실패 시 재시도 큐에 넣고, 보상 중복 지급 방지용 로컬 가드(②의 `lastRewardClaimedSeasonId`)도 둔다.

### 4.7 시즌 카드 8장 클라 지급 (핵심)

`enter`가 준 `ban_unit_ids`로 **밴 아닌 유닛의 카드 8장**을 클라가 지급하고 ②에 저장. Ark `ArkGachaService`의 `_isUnitBanned` + `saveData.AddCard` 패턴 재사용.

```csharp
async UniTask GrantSeasonCardsIfNeededAsync(int[] banUnitIds, string seasonId)
{
    // 중복 지급 방지 (②)
    if (_saveData.lastCardGrantSeasonId == seasonId) return;

    var cardManager = GetManager<CardManager>();
    bool IsBanned(EUnitType u) => Array.IndexOf(banUnitIds, (int)u) >= 0;

    // 밴 아닌 유닛 카드 풀에서 8장 선정 (seasonId 기반 결정적 셔플 권장)
    var pool = new List<CardDataSO>();
    foreach (EUnitType u in Enum.GetValues(typeof(EUnitType)))
    {
        if (u == EUnitType.None || IsBanned(u)) continue;
        pool.AddRange(cardManager.GetArkUnitCards(u));
    }
    var grant = PickDeterministic(pool, 8, seasonId); // seed=hash(seasonId)

    foreach (var card in grant)
        _saveData.AddVanguardCard(card.cardID, 1); // ② (ArkSaveData.AddCard 동형)

    _saveData.lastCardGrantSeasonId = seasonId;
    await _saveAsync.Invoke();
}
```

> 지급 장수(8장)·선정 규칙은 기획 확정값을 따른다. 밴 데이터는 반드시 **`enter` 응답의 `ban_unit_ids`에서 파생**(클라가 임의 계산 금지 — 서버가 `hash(season_id)` 결정적 생성).

---

## 5. 파이어베이스 데이터 테이블 저장 (②)

### 5.1 저장 메커니즘

- 키: `ESaveDataType.Vanguard` (이미 enum에 존재).
- 저장: `await _saveDataManager.SaveDataAsync(ESaveDataType.Vanguard, _saveData);`
- 로드: `var loaded = await _saveDataManager.LoadDataAsync<VanguardSaveData>(ESaveDataType.Vanguard); _saveData = loaded ?? new VanguardSaveData();`
- 내부적으로 `SaveDataManager` → `GameDataService.SaveGameDataAsync(key, json)` → `/gameData/save`로 **유저당 JSON 한 덩어리** 저장(AES256 암호화). 대량 동시 저장은 `SaveMultipleDataAsync`.
- `VanguardManager`에 이미 `LoadSaveDataAsync`/`SaveDataAsync(=_saveAsync)`가 있으므로 그대로 사용.

### 5.2 `VanguardSaveData` 전체 스키마 (확장 후)

> 현재 4필드 → 클라 권위 데이터 전체로 확장. 모든 컬렉션은 `= new()` 기본 초기화(역직렬화 null 방지).

```csharp
[Serializable]
public class VanguardSaveData
{
    // ── 시즌 식별 / 리셋 ────────────────────────────────
    public string lastSeasonId = "";              // 새 시즌 판정 키 (enter season_id) ★신규
    public string lastSeasonStartDate = "";        // (구) 호환용
    public string lastCardGrantSeasonId = "";      // 시즌 카드 8장 지급 완료 플래그 ★신규
    public string lastRewardClaimedSeasonId = "";  // 직전 시즌 보상 수령 로컬 가드 ★신규

    // ── 서버 권위 값의 표시용 캐시 (진실값 아님, enter/battle/result 가 덮어씀) ──
    public int currentTier = (int)EVanguardTier.Bronze2;
    public int currentPoints = 0;                  // score_in_division
    public int chaos = 0;
    public bool chaosCapped = false;
    public int winStreak = 0;
    public int loseStreak = 0;
    public int highestTierThisSeason = (int)EVanguardTier.Bronze2;

    // ── 클라 권위: 재화 ─────────────────────────────────
    public int duelCoin = 0;                       // 듀얼 코인 (서버 미사용) ★신규
    public int exchangeCurrency = 0;               // 교환상점 재화/메달 등 (필요 시) ★신규

    // ── 클라 권위: 강화 (기존 유지) ──────────────────────
    public int fortressAttackLevel;                // 일반 강화 (Standard DS)
    public int fortressAttackPremiumLevel;         // 특수 강화 (Special DS)

    // ── 클라 권위: 슬롯 / 로드아웃 / 카드 ────────────────
    public List<int> unlockedTurretSlots = new();              // 해금 슬롯 ★신규
    public List<int> equippedTurretSlots = new();              // 편성 (loadout/save 로 클론 동기화) ★신규
    public List<VanguardChipSlotData> equippedChips = new();   // 장착 칩 ★신규
    public List<VanguardCardOwnedEntry> ownedCards = new();    // 보유 카드(시즌 8장 포함) ★신규
    public List<int> bonusCardConfig = new();                  // 보너스카드 설정 ★신규
    public bool berserkEnabled = false;                        // 광폭화 설정 ★신규

    // ── 클라 권위: 자동순찰 (Ark patrol 패턴) ─────────────
    public bool isPatrolInitialized = false;       // 시즌 시작 시 초기화 여부 ★신규
    public long lastPatrolCheckTime = 0;            // DateTime.ToBinary() ★신규
    public int fastPatrolCharges = 0;               // 쾌속 순찰 충전 ★신규
    public long lastFastPatrolChargeTime = 0;       // ★신규

    // ── 클라 권위: 스테이지 보정 ─────────────────────────
    public List<VanguardStageModifier> stageModifiers = new(); // ★신규

    // ── 클라 권위: 패스 / 상점 ──────────────────────────
    public bool hasPurchasedPaidPass = false;                  // 유료 패스 보유 ★신규
    public List<int> claimedPassTiers = new();                 // 수령한 패스 티어 ★신규
    public List<VanguardShopPurchaseEntry> shopPurchases = new(); // 일일/시즌 구매 한도 ★신규

    // ── 헬퍼 (ArkSaveData.AddCard/HasCard 동형) ─────────
    public int GetVanguardCardCount(int cardId)
        => ownedCards.Find(x => x.cardId == cardId)?.count ?? 0;

    public void AddVanguardCard(int cardId, int amount = 1)
    {
        var e = ownedCards.Find(x => x.cardId == cardId);
        if (e == null) { e = new VanguardCardOwnedEntry { cardId = cardId, count = 0 }; ownedCards.Add(e); }
        e.count += amount;
    }
    public bool HasVanguardCard(int cardId) => GetVanguardCardCount(cardId) > 0;
}

[Serializable] public class VanguardCardOwnedEntry    { public int cardId; public int count; }
[Serializable] public class VanguardChipSlotData      { public int slotIndex; public int chipId; public string grade; }
[Serializable] public class VanguardShopPurchaseEntry { public int productId; public int count; public string periodKey; }
[Serializable] public class VanguardStageModifier     { public int stage; public float modifier; }
```

> 위 필드는 시스템 도입 순서대로 점진 확장해도 된다. **핵심 원칙: 클라 권위 데이터는 전부 여기에, 서버 권위 데이터는 캐시로만.**

### 5.3 데이터 소유권 맵 (저장 결정표)

| 데이터 | 권위 | ②에 저장? |
|---|---|---|
| 점수 / 티어 / 카오스 / 연승 | 서버 | **표시 캐시만** (진실값은 enter/battle 응답) |
| 랭킹 / 리더보드 | 서버 | ✕ (rank API 매번 조회) |
| ban_unit_ids / weekly_turret_ids / end_date | 서버 | ✕ (세션 캐시만, enter마다 갱신) |
| Live/Record 클론 | 서버 | ✕ |
| recent_opponents | 서버 | ✕ |
| 듀얼 코인 | 클라 | **O** |
| 보유 카드(시즌 8장 포함) + 지급 플래그 | 클라 | **O** |
| 편성/로드아웃/칩 config | 클라 | **O** (+ loadout/save 로 클론 동기화) |
| 요새 공격력 강화 레벨 | 클라 | **O** (기존) |
| 슬롯 해금 / 보너스카드 / 광폭화 | 클라 | **O** |
| 자동순찰 상태(시각/충전/초기화) | 클라 | **O** |
| 스테이지 보정 | 클라 | **O** |
| 패스 진행/수령 / 상점 구매 기록 | 클라 | **O** |
| 시즌 식별(season_id) / 보상 수령 가드 | 클라 | **O** |
| 직전 시즌 보상 중복방지(`reward_claimed`) | **서버** | 서버가 set (②엔 보조 가드만) |
| battle_id / match_seed / 상대 loadout / duel 후보 / prev_season_settlement | 휘발성 | **✕ (저장 절대 금지)** — 만료·멱등이 서버에 있어 재사용하면 깨짐 |

### 5.4 시즌 리셋 시 처리

`ResetSeasonProgress`(새 시즌 첫 enter 시)에서 **무엇을 리셋하고 무엇을 보존할지** 명확히 구분한다.

```csharp
private void ResetSeasonProgress(VanguardSaveData s, string newSeasonId)
{
    s.lastSeasonId = newSeasonId;

    // 서버 권위 캐시: enter 응답이 새 시즌 값(브론즈 II/0)으로 곧 덮어쓰므로,
    //   로비 깜빡임 방지를 위해 미리 초기화:
    s.currentTier = (int)EVanguardTier.Bronze2;
    s.currentPoints = 0; s.chaos = 0; s.chaosCapped = false;
    s.winStreak = 0; s.loseStreak = 0; s.highestTierThisSeason = (int)EVanguardTier.Bronze2;

    // 클라 권위: 시즌마다 리셋해야 하는 것 (기획 확정 따라):
    s.unlockedTurretSlots.Clear();
    s.equippedTurretSlots.Clear();
    s.equippedChips.Clear();
    s.fortressAttackLevel = 0; s.fortressAttackPremiumLevel = 0;
    s.isPatrolInitialized = false; s.lastPatrolCheckTime = 0;
    s.fastPatrolCharges = 0; s.lastFastPatrolChargeTime = 0;
    s.stageModifiers.Clear();
    s.claimedPassTiers.Clear(); s.hasPurchasedPaidPass = false;
    s.shopPurchases.Clear();
    // 듀얼 코인/보유 카드: 시즌 캐리오버 여부는 기획 결정. 캐리오버면 보존.

    // 카드 지급 플래그(lastCardGrantSeasonId)는 GrantSeasonCardsIfNeededAsync 에서 갱신.
}
```

> ⚠️ **파괴적 전체 리셋 금지**: 서버는 시즌별 별도 문서(`(gamerId, season_id)`)로 관리하고, 다음 시즌 첫 enter 시 브론즈 II로 새로 시작한다(기존 시즌 문서 보존). 클라 ②도 같은 사상으로, 시즌 한정 진행만 리셋하고 캐리오버 항목은 보존한다.

---

## 6. 서버 측 컬렉션 (참고 — 클라가 직접 안 건드림)

| 컬렉션 | 키 | 주요 필드 |
|---|---|---|
| `vanguard_season` | `season_id` | start_date, end_date, ban_unit_ids[], weekly_turret_ids[], is_settled |
| `vanguard_player` | (gamerId, season_id) | score, tier, highest_tier_this_season, score_in_division, chaos, chaos_max_reached_at, win_streak, lose_streak, recent_opponents[], loadout, duel_state, reward_claimed |
| `vanguard_live_clone` | gamerId | season_id, tier, score, atk, cps, nickname, profile_icon/border, loadout, status |
| `vanguard_record_clone` | clone_id | origin_uid, season_id, snap_tier, snap_score, atk, cps, loadout, status |
| `vanguard_battle` | battle_id | gamerId, season_id, opponent_ref, match_type(MATCH/DUAL), match_seed, status(PENDING/RESOLVED/EXPIRED), resolved_result, expire_at |
| `vanguard_duel_session` | duel_id | gamerId, season_id, candidates[], refresh_used, status(WAITING/CONFIRMED/ABANDONED/EXPIRED), expire_at |

- 클론은 `loadout`만 저장(리플레이 저장 안 함). 상대 전투는 `match_seed` + `opponent.loadout`으로 클라가 즉석 시뮬.
- 별도 정산 cron 없음: 직전 시즌 보상은 enter가 즉석 계산(`prev_season_settlement`), `resetLastSeasonData`가 중복 방지.

---

## 7. 점수/티어 상수 (참고)

**점수**: 승리 기본 +100 (카오스 티어 +85) / swift +10 / comeback +10 / 연승 3→+5·4→+10·5→+15·6→+20·7+→+25(고정) / 듀얼 승리 점수 ×2 (패배 차감은 일반과 동일).
계산: `WIN delta = base + swift + comeback + streakBonus` (듀얼 ×2), `LOSE delta = tier.losePenalty`(음수).

**티어 (`VanguardTierData.json`)**

| tierValue | 티어 | 승급 임계 | 패배 차감 | 자동순찰/듀얼 | 리더보드 |
|---|---|---|---|---|---|
| 101 | 브론즈 II | 300 | -5 | ✕ | ✕ |
| 102 | 브론즈 I | 300 | -5 | ✕ | ✕ |
| 201 | 실버 II | 300 | -15 | ✔ | ✕ |
| 202 | 실버 I | 300 | -15 | ✔ | ✕ |
| 301 | 골드 III | 400 | -25 | ✔ | ✔ |
| 302 | 골드 II | 400 | -25 | ✔ | ✔ |
| 303 | 골드 I | 400 | -25 | ✔ | ✔ |
| 401 | 플래티넘 III | 500 | -45 | ✔ | ✔ |
| 402 | 플래티넘 II | 500 | -45 | ✔ | ✔ |
| 403 | 플래티넘 I | 500 | -45 | ✔ | ✔ |
| 501 | 다이아몬드 IV | 500 | -60 | ✔ | ✔ |
| 502 | 다이아몬드 III | 500 | -60 | ✔ | ✔ |
| 503 | 다이아몬드 II | 500 | -60 | ✔ | ✔ |
| 504 | 다이아몬드 I | 500 | -60 | ✔ | ✔ |
| 601 | 카오스(Ultimate) | — | -90 | ✔ | ✔ |

승급: `score_in_division >= 임계` → 다음 티어(초과 이월). 강등: `< 0` → 이전 티어(부족 이월, 101 하단 0 고정). 카오스(601): `score_in_division/100 → chaos`(최대 100, 도달 시 동결, 동률은 먼저 달성 우선).

---

## 8. 구현 체크리스트

**서버 API 연동 (①)**
- [ ] `VanguardServerService`: 10개 엔드포인트 상수 + 메서드 (§2.1 템플릿)
- [ ] §3 DTO 정의 (Enter/Settlement/LoadoutDto/Opponent/MatchFind/BattleResult/ScoreBreakdown/Rank*/Duel*/Empty 등)
- [ ] 모든 DTO 필드 `[JsonProperty("snake_case")]` 명시
- [ ] `ServerManager`: 10개 public 래퍼 추가, 기존 `SubmitVanguardMatchResultAsync` 제거/교체
- [ ] `VanguardSeasonService.EnterSeasonAsync`: `season_id` 판정으로 교체 (§4.1)
- [ ] `VanguardManager.ReportBattleResultAsync`: `battle/result` 연동 + 연출 (§4.3)
- [ ] match/duel/rank 플로우 연결 (§4.2/4.4/4.5)
- [ ] 직전 시즌 보상 지급 + `resetLastSeasonData` (§4.6)
- [ ] 에러 분기: 7201/7203/7206/7208/7209/7210/7211 + `server_error_{code}` 로컬라이즈
- [ ] 멱등 재시도: battle/result 네트워크 실패 시 재제출 안전 확인

**파이어베이스 저장 (②)**
- [ ] `VanguardSaveData` 확장 (§5.2 전체 필드 + 헬퍼)
- [ ] 보조 `[Serializable]` 타입 4종 (CardOwnedEntry/ChipSlotData/ShopPurchaseEntry/StageModifier)
- [ ] `RankService.UpdateFromServerAsync` 시그니처 확장(카오스/연승/최고티어 반영)
- [ ] 시즌 카드 8장 클라 지급 + 지급 플래그 (§4.7)
- [ ] `ResetSeasonProgress`: 시즌 리셋/보존 항목 구분 (§5.4)
- [ ] 듀얼 코인 클라 검사·차감 (start 전)
- [ ] 저장 호출 지점마다 `SaveDataAsync(ESaveDataType.Vanguard, _saveData)` 누락 확인

**검증**
- [ ] 신규 유저 첫 enter → 브론즈 II + 카드 8장 지급 1회만
- [ ] 새 시즌 전환 → 시즌 한정 진행 리셋, 캐리오버 항목 보존
- [ ] battle/result 2회 제출 → 점수 1회만 반영(멱등)
- [ ] 직전 시즌 보상 → 지급 후 다음 enter `prev_season_settlement == null`
- [ ] 시즌 시간 외 → 7201로 로비 비활성
- [ ] 휘발성 데이터(battle_id 등) ②에 저장 안 됨 확인

---

## 부록: 명세 ↔ 기존 코드 매핑

| 명세 항목 | 기존 클라 자산 |
|---|---|
| enter | `VanguardSeasonService.EnterSeasonAsync` (확장) |
| battle/result | `VanguardManager.ReportMatchResultAsync` → `ReportBattleResultAsync` |
| 티어/점수 캐시 | `VanguardRankService` (`VanguardSaveData.currentTier/Points`) |
| 요새 공격력 강화 | `VanguardStatService` (`fortressAttackLevel`) |
| 티어 테이블 | `VanguardTierTable` / `VanguardTierDataSO` (`VanguardTierData.json`) |
| 카드 지급 패턴 | `ArkGachaService._isUnitBanned` + `ArkSaveData.AddCard` |
| 시즌 리셋 패턴 | `ArkSeasonService` / `VanguardSeasonService.ResetSeasonProgress` |
| 보상 지급 | `RewardClaimPopupUI` (ModifyCurrency 중복 금지) |
| 고스트 시뮬 | `VanguardGhostSim` (match_seed + opponent.loadout) |
| 통신/암호화/재시도 | `BaseServerService.RequestApiAsync` → `ServerManager.RequestApiWithAutoReloginAsync` |

---

_작성 기준: vanguard-api-spec_2026-06-06 / 클라 브랜치 코드 스냅샷. 서버 계약 변경 시 §3 DTO와 §2.1 엔드포인트 상수만 수정하면 됨._
