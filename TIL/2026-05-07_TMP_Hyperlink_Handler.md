# TIL - TextMeshPro 하이퍼링크 클릭 처리 (2026-05-07)

## 개요

Unity에서 `TextMeshProUGUI`에 입력된 `<link>` 태그를 감지해 외부 URL을 여는 컴포넌트를 구현했다.  
`NoticeDetailPopupUI`의 공지 본문 텍스트에서 하이퍼링크를 클릭 가능하게 만드는 작업이었다.

---

## TMP 리치 텍스트 포맷

```
<link="https://example.com"><color=#4A9EF5><u>링크 텍스트</u></color></link>
```

| 태그 | 역할 |
|---|---|
| `<link="URL">` | 클릭 가능한 링크 영역 지정 |
| `<color=...>` | 링크 색상 (hex 또는 named color 모두 가능) |
| `<u>` | 밑줄로 링크임을 시각적으로 표시 |

링크가 여러 개여도 추가 코드 없이 자동 처리된다.

---

## 구현: TMPHyperlinkHandler.cs

```csharp
[RequireComponent(typeof(TextMeshProUGUI))]
public class TMPHyperlinkHandler : MonoBehaviour, IPointerClickHandler
{
    private TextMeshProUGUI _tmpText;

    private void Awake()
    {
        _tmpText = GetComponent<TextMeshProUGUI>();
    }

    public void OnPointerClick(PointerEventData eventData)
    {
        // 링크가 하나도 없으면 intersection 계산 자체를 skip
        if (_tmpText.textInfo.linkCount == 0) return;

        // _tmpText.canvas: TMP가 내부적으로 캐싱하는 프로퍼티
        // ScreenSpaceOverlay면 null, 그 외(Camera/WorldSpace)면 worldCamera 사용
        var canvas = _tmpText.canvas;
        var camera = canvas.renderMode == RenderMode.ScreenSpaceOverlay ? null : canvas.worldCamera;

        int linkIndex = TMP_TextUtilities.FindIntersectingLink(_tmpText, eventData.position, camera);
        if (linkIndex == -1) return;

        var url = _tmpText.textInfo.linkInfo[linkIndex].GetLinkID();
        if (string.IsNullOrEmpty(url)) return;

        Application.OpenURL(url);
    }
}
```

사용법: `_contentText` GameObject에 이 컴포넌트를 Add Component로 추가하면 끝.  
TMP의 **Rich Text**, **Raycast Target** 체크 필요 (기본값으로 켜져 있음).

---

## 최적화 포인트

### 1. `_uiCamera` 필드 제거

**Before**
```csharp
private Camera _uiCamera;

private void Awake()
{
    var canvas = GetComponentInParent<Canvas>(); // 매번 부모 탐색
    _uiCamera = canvas.renderMode == RenderMode.ScreenSpaceOverlay ? null : canvas.worldCamera;
}
```

**After**
```csharp
// Awake에서 캐싱하지 않고 클릭 시점에 TMP 내장 캐시로 즉시 조회
var canvas = _tmpText.canvas;
var camera = canvas.renderMode == RenderMode.ScreenSpaceOverlay ? null : canvas.worldCamera;
```

- `GetComponentInParent<Canvas>()`는 계층을 직접 탐색하는 반면,  
  `_tmpText.canvas`는 TMP(`Graphic` 베이스 클래스)가 내부적으로 캐싱한 값을 반환한다.
- `Awake()`에서 캐싱하면 런타임에 Canvas renderMode가 바뀔 경우 stale 값이 될 수 있다.  
  클릭 시점에 조회하면 이 문제가 없고 필드도 줄어든다.

### 2. `linkCount == 0` 조기 반환

```csharp
if (_tmpText.textInfo.linkCount == 0) return;
```

- 링크 태그가 없는 일반 텍스트에서는 `FindIntersectingLink`의 내부 루프 실행 자체를 방지한다.
- 공지 본문 대부분이 링크 없는 텍스트일 경우, 매 클릭마다 불필요한 연산을 완전히 차단한다.

---

## 적용 위치

- **파일**: `Assets/_Project/1_Scripts/UI/Components/TMPHyperlinkHandler.cs`
- **프리팹**: `NoticeDetailPopupUI` → `_contentText` GameObject에 컴포넌트 추가
