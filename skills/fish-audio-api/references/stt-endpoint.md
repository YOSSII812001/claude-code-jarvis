# STT エンドポイント (Speech-to-Text)

## 基本情報

- **URL**: `POST https://api.fish.audio/v1/asr`
- **Content-Type**: `multipart/form-data`
- **レスポンス**: JSON

## リクエストパラメータ

| パラメータ | 型 | 必須 | デフォルト | 説明 |
|-----------|-----|------|-----------|------|
| audio | binary | Yes | — | 音声ファイル |
| language | string | No | 自動検出 | 言語コード: `en`, `zh`, `ja`, `ko`, `fr`, `de`, `es` 等 |
| ignore_timestamps | boolean | No | `false` | `true`: 高速（タイムスタンプなし）、`false`: セグメント詳細付き |

## 対応音声形式

MP3, WAV, M4A, OGG, FLAC, AAC

## 制限

| 項目 | 値 |
|------|-----|
| 最大ファイルサイズ | 20 MB |
| 最大音声長 | 60分 |
| 最小音声長 | 1秒 |

## レスポンス (200)

```json
{
  "text": "文字起こしの結果テキスト",
  "duration": 15.5,
  "segments": [
    {
      "text": "文字起こしの",
      "start": 0.0,
      "end": 1.8
    },
    {
      "text": "結果テキスト",
      "start": 1.8,
      "end": 3.2
    }
  ]
}
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| text | string | 全文テキスト |
| duration | float | 音声の長さ（秒） |
| segments | array | タイムスタンプ付きセグメント（`ignore_timestamps=false` 時） |
| segments[].text | string | セグメントテキスト |
| segments[].start | float | 開始時刻（秒） |
| segments[].end | float | 終了時刻（秒） |

## エラー

| コード | 説明 |
|--------|------|
| 401 | 認証エラー |
| 402 | クレジット不足 |
| 422 | バリデーションエラー（形式非対応、サイズ超過等） |

## コード例

### cURL

```bash
curl -X POST "https://api.fish.audio/v1/asr" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -F "audio=@input.mp3" \
  -F "language=ja" \
  -F "ignore_timestamps=false"
```

### cURL — 高速モード（タイムスタンプなし）

```bash
curl -X POST "https://api.fish.audio/v1/asr" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -F "audio=@input.mp3" \
  -F "ignore_timestamps=true"
```

### Python

```python
from fish_audio_sdk import Session

session = Session(api_key="your_api_key")

# 基本的な音声認識
with open("input.mp3", "rb") as audio_file:
    result = session.asr(
        audio=audio_file,
        language="ja",
        ignore_timestamps=False,
    )

print(f"テキスト: {result.text}")
print(f"音声長: {result.duration}秒")

for segment in result.segments:
    print(f"[{segment.start:.1f}s - {segment.end:.1f}s] {segment.text}")
```

### Python — 高速モード

```python
from fish_audio_sdk import Session

session = Session(api_key="your_api_key")

with open("input.mp3", "rb") as audio_file:
    result = session.asr(
        audio=audio_file,
        ignore_timestamps=True,
    )

print(result.text)  # タイムスタンプなし、テキストのみ
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

const audioBuffer = fs.readFileSync("input.mp3");

const result = await client.asr({
  audio: audioBuffer,
  language: "ja",
  ignore_timestamps: false,
});

console.log(`テキスト: ${result.text}`);
console.log(`音声長: ${result.duration}秒`);

for (const segment of result.segments) {
  console.log(`[${segment.start.toFixed(1)}s - ${segment.end.toFixed(1)}s] ${segment.text}`);
}
```

### JavaScript — 高速モード

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

const result = await client.asr({
  audio: fs.readFileSync("input.mp3"),
  ignore_timestamps: true,
});

console.log(result.text);
```
