# 유저 재화 초기화 버그 분석

> **작성일:** 2026-04-29  
> **분류:** 데이터 손실 / 서버 저장 버그  
> **심각도:** 🔴 Critical — 기존 유저의 재화가 기본값으로 덮어쓰임  
> **대표 유저:** 1RUY6Q

---

## 1. 요약

게임 로드 시 서버 응답이 불완전하게 파싱되면서 일부 재화가 메모리에 **0으로 올라옵니다.**  
이후 세션 중 다른 재화가 수정되면 `autoSave`가 트리거되고, 메모리의 0값이 서버로 전송되어 **기존 DB 값을 덮어씁니다.**

> ⚠️ **재화가 강제로 0이 된 것이 아니라, 처음부터 메모리에 0으로 올라온 것이 원인입니다.**  
> `ResetToDefault()`와 `InitializeCurrencies()`는 기존 유저 세션 중에는 호출되지 않습니다.

---

## 2. 버그 발생 타임라인 (유저 1RUY6Q, 04-26)

```
08:30:21  loadAll 응답 수신
          └─ additionalCurrencies 배열이 불완전하게 파싱됨
             ├─ ac_1(gold), ac_2(gem), ac_3(stamina), ac_10, ac_12, ac_220
             │   → named field로 정상 적용
             └─ ac_5, ac_6, ac_7 ...
                 → 파싱 누락 → 메모리에 0으로 남음
          └─ PlayerData도 일부 필드 파싱 실패
             ├─ level, exp, totalGamePlayCount → 정상
             └─ cumulativeLoginDays, lastSaveTime → 0으로 세팅

(47분간 세션 진행)
          └─ 수정된 재화: ac_1 +151, ac_2 -915, ac_3 +4, ac_10 -1767, ac_12 -46, ac_220 +2
          └─ 미수정 재화: ac_5, ac_6, ac_7 ... → 계속 메모리에 0 유지

09:17:43  ModifyCurrency 호출 (로그인 보상 등)
          └─ autoSave = true → SaveCurrencyDataAsync() 트리거
          └─ BuildAdditionalCurrenciesForSave(): amount <= 0이면 skip
              → ac_5, ac_6, ac_7 ... 저장 payload에 미포함
          └─ 서버로 전송: { gold:3300, gem:100, additionalCurrencies:[ac_220:3, ...] }
          └─ 서버가 currency 문서 전체 교체 (upsert/overwrite)
          └─ DB: ac_5 = 3885 → 0 (해당 키 삭제됨)
```

---

## 3. 근본 원인 — 취약점이 3개 레이어에 동일하게 존재

### 취약점 공통 구조: `totalGamePlayCount == 0`이면 가드가 열림

세 곳 모두 `totalGamePlayCount > 0`이 아니면 재화 0 값을 허용합니다.  
그런데 `totalGamePlayCount`는 로딩 최적화 과정에서 저장 누락이 생길 수 있고, Ark 전용 유저에서 0일 수도 있어 신뢰도가 낮습니다.

| 레이어 | 위치 | 역할 |
|--------|------|------|
| `LoadAllDataFromServerOnceInternalAsync` | `SaveDataManager.cs:2460` | 서버 응답을 메모리에 올릴 때 0 수용 여부 결정 |
| `ApplyServerCurrencyData` | `PlayerDataManager.cs` | 서버 데이터를 적용할 때 0 수용 여부 결정 |
| `ShouldBlockCurrencySave` | `CurrencyManager.cs:1589` | 저장 시 0값 전송 차단 여부 결정 |

```csharp
// 세 곳 모두 동일한 패턴
if (playerDataMgr == null || playerDataMgr.TotalGamePlayCount > 0)
{
    return true; // 저장 차단
}
// TotalGamePlayCount == 0이면 가드 통과 → 0 허용 ← 취약점
```

---

## 4. 원인 규명을 위한 조사 순서

> ### 🔴 1순위 — 08:30:21 **loadAll response body 확인**
>
> **이것 하나로 원인이 확정됩니다.**  
> 서버가 잘못된 값을 반환한 것인지, 클라이언트가 정상 응답을 잘못 파싱한 것인지 판단 가능합니다.
>
> **확인 포인트:**
> - `currency.additionalCurrencies` 배열의 항목 수와 내용
>   - `ac_220`이 포함됐는지, `ac_5`(ECurrencyType 5)가 있었는지
> - `player.cumulativeLoginDays` 값
>   - 서버가 0을 반환했는지, 아니면 응답에 필드 자체가 없었는지
>
> | 결과 | 의미 |
> |------|------|
> | 서버가 정상값을 반환 → 클라이언트가 0으로 적용 | **클라이언트 파싱 버그** |
> | 서버가 처음부터 0 또는 빈 배열 반환 | **서버 응답 문제** |

---

### 🟡 2순위 — 09:17:43 saveAll request body 확인

**확인 포인트:**
- `allData` 배열에서 currency 항목의 `additionalCurrencies` 내용
  - `ac_5`, `ac_6` 등이 포함됐는지, 아니면 완전히 없는지
- currency 외 다른 dataType도 함께 전송됐는지

---

### 🟡 3순위 — Crashlytics 클라이언트 로그 (user 1RUY6Q, 08:30~09:17 구간)

**검색 키워드:**
- `[CurrencyResetGuard]`
- `[PlayerDataManager] Currency 데이터 로드`
- `additionalCurrencies`
- `ApplyAdditionalCurrenciesFromSaveData`
- `ECurrencyType 정의되지 않음` 또는 enum 관련 skip 로그

`ApplyAdditionalCurrenciesFromSaveData`에서 enum 미정의로 skip된 항목이 있으면 로그에 남아 있을 가능성이 있습니다. 없다면 로깅 추가가 필요합니다.

---

### 🟡 4순위 — 해당 유저의 이전 세션 currency save 기록

- 09:17:43 이전 마지막 saveAll 시점 확인
- 그 저장에서 `additionalCurrencies`에 `ac_5`, `ac_6` 등이 있었는지
- 없었다면 언제부터 사라졌는지 추적

---

## 5. 방어 코드 수정 방향

### Guards 추가 — 필요하지만 충분하지 않음

Guards는 0값이 DB에 기록되는 것을 막는 **방어선**이지, 메모리에 0이 올라오는 원인을 막지는 못합니다.  
근본 해결을 위해 `LoadAllData` 단계에서 0을 수용하는 것 자체를 먼저 차단해야 합니다.

**수정 우선순위:**

| 순위 | 위치 | 내용 |
|------|------|------|
| 1 | `LoadAllData` 단계 가드 | 여기서 차단하면 이후 레이어 전파 없음 |
| 2 | `Apply` / `Save` 레이어 가드 | 추가 방어선 |
| 3 | Root cause 추적 | 병행 진행 |

### 가드 조건 강화 예시

`totalGamePlayCount` 대신 `level`과 `cumulativeLoginDays`를 함께 사용하면 신뢰도가 높아집니다.

```csharp
// ShouldBlockCurrencySave — 세 레이어 모두 동일하게 적용
if (playerDataMgr == null
    || playerDataMgr.TotalGamePlayCount > 0
    || playerDataMgr.CurrentLevel > 1          // 추가
    || playerDataMgr.CumulativeLoginDays > 1)  // 추가
{
    return true; // 저장 차단
}
```

> **엣지 케이스 인지 필요:** `CumulativeLoginDays > 1` 조건은 level 1이고 당일 첫 접속한 유저에게 false입니다.  
> 같은 날 재화를 쌓고 버그를 만나면 여전히 보호받지 못합니다. 수용 가능한 수준이지만 인지는 필요합니다.

### 세 레이어 일관 적용 필수

```
LoadAllData 단계 (SaveDataManager)
    → 서버 응답을 메모리에 올릴 때 0 차단

Apply 단계 (PlayerDataManager)
    → 서버 데이터를 메모리에 적용할 때 0 차단

Save 단계 (CurrencyManager)
    → 서버로 저장 요청 시 0 전송 차단
```

세 곳이 서로 다른 기준을 쓰면 어느 한 레이어가 뚫릴 때 다른 레이어에서 잡지 못합니다.

---

## 6. DB 확인만으로는 충분하지 않은 이유

| 확인 대상 | 알 수 있는 것 | 한계 |
|-----------|--------------|------|
| DB (현재값) | `totalGamePlayCount`, `gold`가 실제로 0인지 | 이미 덮어쓰인 경우 원인 불명 |
| 서버 API 응답 로그 (08:30) | 클라이언트가 받은 실제 페이로드 | 로그가 없으면 확인 불가 |

핵심 질문은 **"DB에 0이 저장돼 있었나"** vs **"API가 일시적으로 0/null을 반환했나"** 입니다.  
DB만 보면 "현재 0이다"는 알지만 "왜 0이 됐는가"는 알기 어렵습니다.

---

## 7. 요약

```
[버그 입구] 08:30 loadAll 응답에서 additionalCurrencies 일부 파싱 실패
    ↓
[전파] 47분간 세션 진행 — 메모리의 0값은 수정되지 않고 그대로 유지
    ↓
[피해 확정] 09:17 autoSave → 0값 포함 payload가 서버로 전송 → DB 덮어씀
    ↓
[방어 실패] totalGamePlayCount = 0 조건으로 가드가 열려 있었음
```

**즉각 조치:** `08:30:21 loadAll response body` 서버 로그 확인 → 파싱 버그인지 서버 응답 문제인지 판단  
**방어 코드:** 세 레이어에 `level > 1` + `cumulativeLoginDays > 1` 조건 일관 적용
