# 認証 (Authentication)

## 認証方式

Fish Audio API は **Bearer Token** 認証を使用する。すべてのリクエストに `Authorization` ヘッダーが必要。

```
Authorization: Bearer {FISH_API_KEY}
```

## APIキー取得手順

1. [fish.audio](https://fish.audio) にアクセスしログイン
2. ダッシュボード → **API Keys** セクションへ移動
3. **Create API Key** をクリック
4. 生成されたキーを安全に保存（再表示不可）

## 環境変数設定

```bash
# .env または シェル設定
export FISH_API_KEY=your_api_key_here
```

```powershell
# PowerShell
$env:FISH_API_KEY = "your_api_key_here"
```

## SDK 初期化

### Python

```python
from fish_audio_sdk import Session

# 環境変数 FISH_API_KEY から自動取得
session = Session()

# 直接指定
session = Session(api_key="your_api_key")
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";

// 環境変数から取得
const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

// 直接指定
const client = new FishAudioClient({ apiKey: "your_api_key" });
```

### cURL

```bash
curl -H "Authorization: Bearer $FISH_API_KEY" \
  https://api.fish.audio/model
```

## 認証エラー

APIキーが無効または未指定の場合、`401 Unauthorized` が返される。

```json
{
  "status": 401,
  "message": "Unauthorized"
}
```

## セキュリティ注意事項

- APIキーは **バージョン管理に含めない**（`.gitignore` に `.env` を追加）
- `.env` ファイルまたは環境変数で管理する
- クライアントサイドのコードにAPIキーを埋め込まない
- キーが漏洩した場合はダッシュボードから即座にローテーションする
