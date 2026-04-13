# エラーコード

## HTTP ステータスコード一覧

| コード | 説明 | 再試行可 | 対処法 |
|--------|------|---------|--------|
| 400 | Bad Request | No | リクエスト形式を確認 |
| 401 | Unauthorized | No | APIキーの有効性を確認 |
| 402 | Payment Required | No | クレジットをチャージ |
| 403 | Forbidden | No | リソースへのアクセス権を確認 |
| 404 | Not Found | No | リソースIDが正しいか確認 |
| 422 | Unprocessable Entity | No | パラメータが仕様に準拠しているか確認 |
| 429 | Too Many Requests | Yes | 指数バックオフで再試行 |
| 500 | Internal Server Error | Yes | 再試行後、改善しなければサポートへ連絡 |

## 422 エラー詳細構造

バリデーションエラーは詳細な位置情報を含む。

```json
{
  "status": 422,
  "message": "Validation error",
  "details": [
    {
      "loc": ["body", "text"],
      "type": "value_error",
      "msg": "field required"
    },
    {
      "loc": ["body", "temperature"],
      "type": "value_error",
      "msg": "ensure this value is less than or equal to 1"
    }
  ]
}
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| details[].loc | array | エラー箇所のパス（例: `["body", "text"]`） |
| details[].type | string | エラー種別 |
| details[].msg | string | エラーメッセージ |

## SDK 例外クラス

### Python

```python
from fish_audio_sdk import (
    FishAudioError,        # 基底クラス
    AuthenticationError,   # 401
    RateLimitError,        # 429
    ValidationError,       # 422
)

from fish_audio_sdk import Session

session = Session(api_key="your_api_key")

try:
    result = session.tts(request)
except AuthenticationError:
    print("APIキーが無効です")
except RateLimitError as e:
    print(f"レート制限: {e.retry_after}秒後に再試行")
except ValidationError as e:
    print(f"バリデーションエラー: {e.details}")
except FishAudioError as e:
    print(f"APIエラー: {e.status_code} - {e.message}")
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

try {
  const result = await client.tts(request);
} catch (error) {
  if (error.status === 401) {
    console.error("APIキーが無効です");
  } else if (error.status === 429) {
    console.error(`レート制限: ${error.retryAfter}秒後に再試行`);
  } else if (error.status === 422) {
    console.error("バリデーションエラー:", error.details);
  } else {
    console.error(`APIエラー: ${error.status} - ${error.message}`);
  }
}
```

## リトライ戦略

### 429 Too Many Requests

指数バックオフで再試行する。

```python
import time

def retry_with_backoff(func, max_retries=5):
    for attempt in range(max_retries):
        try:
            return func()
        except RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            wait = min(2 ** attempt, 30)  # 1s → 2s → 4s → 8s → 16s（最大30s）
            time.sleep(wait)
```

### 500 Internal Server Error

最大3回リトライ、改善しなければサポートへ連絡。

```python
def retry_server_error(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return func()
        except FishAudioError as e:
            if e.status_code != 500 or attempt == max_retries - 1:
                raise
            time.sleep(1)
```

### cURL でのエラーハンドリング

```bash
# レスポンスコードを確認
HTTP_CODE=$(curl -s -o response.json -w "%{http_code}" \
  -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text": "test", "reference_id": "MODEL_ID"}')

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "成功"
elif [ "$HTTP_CODE" -eq 429 ]; then
  echo "レート制限 — 再試行してください"
elif [ "$HTTP_CODE" -eq 402 ]; then
  echo "クレジット不足 — チャージしてください"
else
  echo "エラー: $HTTP_CODE"
  cat response.json
fi
```
