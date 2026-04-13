# TTS エンドポイント (Text-to-Speech)

## 基本情報

- **URL**: `POST https://api.fish.audio/v1/tts`
- **Content-Type**: `application/json`
- **レスポンス**: ストリーミングバイナリ（指定フォーマット）

## 必須ヘッダー

| ヘッダー | 値 | 説明 |
|---------|-----|------|
| Authorization | `Bearer {FISH_API_KEY}` | 認証トークン |
| Content-Type | `application/json` | リクエスト形式 |
| model | `s1` または `s2-pro` | 使用モデル |

## リクエストパラメータ

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|-----------|-----|------|-----------|------|
| text | string | Yes | — | 合成するテキスト |
| reference_id | string/array | Yes* | — | 話者モデルID。配列で複数話者指定可（S2-Pro） |
| references | array | No | — | Instant Voice Clone 用リファレンス音声 |
| format | string | No | `mp3` | 出力形式: `wav`, `pcm`, `mp3`, `opus` |
| sample_rate | integer | No | モデル依存 | サンプルレート (Hz) |
| temperature | float | No | `0.7` | 生成の多様性 (0-1) |
| top_p | float | No | `0.7` | トークンサンプリング閾値 (0-1) |
| repetition_penalty | float | No | `1.2` | 繰り返し抑制ペナルティ |
| chunk_length | integer | No | `300` | チャンクサイズ (100-300) |
| min_chunk_length | integer | No | `50` | 最小チャンクサイズ (0-100) |
| normalize | boolean | No | `true` | テキスト正規化の有無 |
| latency | enum | No | `normal` | レイテンシモード: `low`, `balanced`, `normal` |
| max_new_tokens | integer | No | `1024` | 最大生成トークン数 |
| prosody | object | No | — | 韻律制御（後述） |
| mp3_bitrate | integer | No | `128` | MP3ビットレート: `64`, `128`, `192` |
| opus_bitrate | integer | No | `-1000` | Opusビットレート: `-1000`(auto), `24`, `32`, `48`, `64` |

*`reference_id` または `references` のいずれかが必要。

## Prosody（韻律制御）

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| speed | float | `1.0` | 速度 (0.5-2.0) |
| volume | float | `0` | 音量調整 (-20 ~ +20 dB) |
| normalize_loudness | boolean | `false` | ラウドネス正規化 |

## Multi-speaker（S2-Pro のみ）

`reference_id` を配列で指定し、テキスト内で `<|speaker:N|>` タグで話者を切り替える。

```json
{
  "reference_id": ["speaker_id_1", "speaker_id_2"],
  "text": "<|speaker:0|>こんにちは。<|speaker:1|>はじめまして。"
}
```

## Instant Voice Clone

`references` 配列でリファレンス音声とテキストを直接渡す。モデル登録不要。

```json
{
  "text": "こんにちは",
  "references": [
    {
      "audio": "<base64_encoded_audio>",
      "text": "リファレンス音声のトランスクリプト"
    }
  ]
}
```

## レスポンス

- **200**: ストリーミングバイナリ音声データ（Content-Type は指定形式に準拠）
- **401**: 認証エラー
- **402**: クレジット不足
- **422**: バリデーションエラー

## コード例

### cURL — 基本

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -H "model: s1" \
  -d '{
    "text": "こんにちは、世界！",
    "reference_id": "MODEL_ID_HERE",
    "format": "mp3"
  }' \
  --output output.mp3
```

### cURL — カスタムパラメータ

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -H "model: s1" \
  -d '{
    "text": "速度とピッチを調整した音声です。",
    "reference_id": "MODEL_ID_HERE",
    "format": "wav",
    "temperature": 0.5,
    "top_p": 0.8,
    "latency": "low",
    "prosody": {
      "speed": 1.2,
      "volume": 5
    }
  }' \
  --output output.wav
```

### cURL — Multi-speaker (S2-Pro)

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -H "model: s2-pro" \
  -d '{
    "reference_id": ["SPEAKER_A_ID", "SPEAKER_B_ID"],
    "text": "<|speaker:0|>おはようございます。<|speaker:1|>おはようございます、いい天気ですね。"
  }' \
  --output multi_speaker.mp3
```

### Python — 基本

```python
from fish_audio_sdk import Session, TTSRequest

session = Session(api_key="your_api_key")

# ストリーミング生成
with open("output.mp3", "wb") as f:
    for chunk in session.tts(TTSRequest(
        text="こんにちは、世界！",
        reference_id="MODEL_ID_HERE",
        format="mp3",
    )):
        f.write(chunk)
```

### Python — カスタムパラメータ

```python
from fish_audio_sdk import Session, TTSRequest, Prosody

session = Session(api_key="your_api_key")

request = TTSRequest(
    text="速度調整した音声です。",
    reference_id="MODEL_ID_HERE",
    format="wav",
    temperature=0.5,
    latency="low",
    prosody=Prosody(speed=1.2, volume=5),
)

with open("output.wav", "wb") as f:
    for chunk in session.tts(request):
        f.write(chunk)
```

### JavaScript — 基本

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

const response = await client.tts({
  text: "こんにちは、世界！",
  reference_id: "MODEL_ID_HERE",
  format: "mp3",
});

const buffer = Buffer.from(await response.arrayBuffer());
fs.writeFileSync("output.mp3", buffer);
```

### JavaScript — ストリーミング

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

const stream = await client.tts({
  text: "ストリーミングで音声を生成します。",
  reference_id: "MODEL_ID_HERE",
  format: "mp3",
  latency: "low",
  prosody: { speed: 1.1, volume: 0 },
}, { stream: true });

const writer = fs.createWriteStream("output.mp3");
for await (const chunk of stream) {
  writer.write(chunk);
}
writer.end();
```
