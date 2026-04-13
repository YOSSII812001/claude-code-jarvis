# モデルエンドポイント

## Create Model — モデル作成

- **URL**: `POST https://api.fish.audio/model`
- **Content-Type**: `multipart/form-data`

### パラメータ

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|-----------|-----|------|-----------|------|
| type | string | Yes | — | `"tts"` 固定 |
| title | string | Yes | — | モデル名 |
| train_mode | string | Yes | — | `"fast"` |
| voices | file[] | Yes | — | トレーニング音声ファイル（10秒以上推奨） |
| visibility | string | No | `"private"` | `public`, `unlist`, `private` |
| description | string | No | — | モデル説明 |
| cover_image | file | No | — | カバー画像 |
| texts | string[] | No | — | 各音声ファイルのトランスクリプト |
| tags | string[] | No | — | タグ |
| enhance_audio_quality | boolean | No | `false` | 音質強化前処理 |

### レスポンス (201)

```json
{
  "_id": "model_abc123",
  "type": "tts",
  "title": "My Voice Model",
  "description": "",
  "visibility": "private",
  "state": "training",
  "author": {
    "_id": "user_xyz",
    "nickname": "username"
  },
  "created_at": "2025-01-15T10:30:00Z"
}
```

### コード例

#### cURL

```bash
curl -X POST "https://api.fish.audio/model" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -F "type=tts" \
  -F "title=My Voice Model" \
  -F "train_mode=fast" \
  -F "voices=@voice_sample_1.wav" \
  -F "voices=@voice_sample_2.wav" \
  -F "visibility=private" \
  -F "enhance_audio_quality=true"
```

#### Python

```python
from fish_audio_sdk import Session

session = Session(api_key="your_api_key")

model = session.create_model(
    type="tts",
    title="My Voice Model",
    train_mode="fast",
    voices=["voice_sample_1.wav", "voice_sample_2.wav"],
    visibility="private",
    enhance_audio_quality=True,
)
print(f"Model ID: {model._id}, State: {model.state}")
```

#### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

const model = await client.createModel({
  type: "tts",
  title: "My Voice Model",
  train_mode: "fast",
  voices: [
    fs.readFileSync("voice_sample_1.wav"),
    fs.readFileSync("voice_sample_2.wav"),
  ],
  visibility: "private",
});
console.log(`Model ID: ${model._id}`);
```

---

## Get Model — モデル詳細取得

- **URL**: `GET https://api.fish.audio/model/{id}`

### レスポンス (200)

```json
{
  "_id": "model_abc123",
  "type": "tts",
  "title": "My Voice Model",
  "description": "A custom voice model",
  "visibility": "public",
  "state": "trained",
  "author": {
    "_id": "user_xyz",
    "nickname": "username"
  },
  "samples": [
    { "url": "https://...", "text": "sample text" }
  ],
  "tags": ["japanese", "female"],
  "languages": ["ja"],
  "like_count": 42,
  "task_count": 1500,
  "created_at": "2025-01-15T10:30:00Z"
}
```

### コード例

#### cURL

```bash
curl "https://api.fish.audio/model/MODEL_ID" \
  -H "Authorization: Bearer $FISH_API_KEY"
```

#### Python

```python
model = session.get_model("MODEL_ID")
print(f"{model.title} ({model.state})")
```

#### JavaScript

```javascript
const model = await client.getModel("MODEL_ID");
console.log(`${model.title} (${model.state})`);
```

---

## List Models — モデル一覧取得

- **URL**: `GET https://api.fish.audio/model`

### クエリパラメータ

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| page_size | integer | `10` | 1ページあたりの件数 |
| page_number | integer | `1` | ページ番号 |
| title | string | — | タイトル検索 |
| tag | string | — | タグフィルタ |
| self | boolean | `false` | 自分のモデルのみ |
| author_id | string | — | 特定ユーザーのモデル |
| language | string | — | 言語フィルタ |
| title_language | string | — | タイトル言語フィルタ |
| sort_by | string | `score` | ソート: `score`, `task_count`, `created_at` |

### レスポンス (200)

```json
{
  "total": 150,
  "items": [
    {
      "_id": "model_abc123",
      "title": "Voice Model",
      "state": "trained",
      "languages": ["ja"],
      "like_count": 42,
      "task_count": 1500
    }
  ]
}
```

### コード例

#### cURL

```bash
# 自分のモデル一覧
curl "https://api.fish.audio/model?self=true&page_size=20" \
  -H "Authorization: Bearer $FISH_API_KEY"

# 日本語モデル検索
curl "https://api.fish.audio/model?language=ja&sort_by=task_count" \
  -H "Authorization: Bearer $FISH_API_KEY"
```

#### Python

```python
models = session.list_models(self=True, page_size=20)
for model in models.items:
    print(f"{model._id}: {model.title}")
```

#### JavaScript

```javascript
const models = await client.listModels({ self: true, pageSize: 20 });
for (const model of models.items) {
  console.log(`${model._id}: ${model.title}`);
}
```

---

## Update Model — モデル更新

- **URL**: `PATCH https://api.fish.audio/model/{id}`
- **Content-Type**: `application/json`

### ボディ（すべてオプション）

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| title | string | モデル名 |
| description | string | 説明 |
| visibility | string | `public`, `unlist`, `private` |
| tags | string[] | タグ |
| cover_image | string | カバー画像URL |

### レスポンス (200)

更新済みモデルオブジェクト。

### コード例

#### cURL

```bash
curl -X PATCH "https://api.fish.audio/model/MODEL_ID" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Model Name",
    "visibility": "public",
    "tags": ["japanese", "professional"]
  }'
```

#### Python

```python
updated = session.update_model("MODEL_ID",
    title="Updated Model Name",
    visibility="public",
    tags=["japanese", "professional"],
)
```

#### JavaScript

```javascript
const updated = await client.updateModel("MODEL_ID", {
  title: "Updated Model Name",
  visibility: "public",
  tags: ["japanese", "professional"],
});
```

---

## Delete Model — モデル削除

- **URL**: `DELETE https://api.fish.audio/model/{id}`

### レスポンス

| コード | 説明 |
|--------|------|
| 200 | 削除成功 |
| 401 | 認証エラー |
| 422 | 無効なモデルID |

### コード例

#### cURL

```bash
curl -X DELETE "https://api.fish.audio/model/MODEL_ID" \
  -H "Authorization: Bearer $FISH_API_KEY"
```

#### Python

```python
session.delete_model("MODEL_ID")
```

#### JavaScript

```javascript
await client.deleteModel("MODEL_ID");
```
