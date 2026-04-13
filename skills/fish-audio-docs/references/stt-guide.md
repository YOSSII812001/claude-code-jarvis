# STT ガイド — Fish Audio

## 概要

Fish Audio STT（Speech-to-Text）は音声ファイルからテキストを生成する。
タイムスタンプ取得、スピーカー検出（diarization）、自動フォーマッティングに対応。

## 対応形式と制限

### 対応音声形式

MP3, WAV, M4A, OGG, FLAC, AAC

### 制限

| 項目 | 制限値 |
|---|---|
| 最大ファイルサイズ | 20 MB |
| 最大音声長 | 60分 |
| 最小音声長 | 1秒 |

## 言語設定

| 設定 | 値 | 説明 |
|---|---|---|
| 自動検出 | `"auto"` または省略 | 音声から自動判定（デフォルト） |
| 英語 | `"en"` | 英語に固定 |
| 中国語 | `"zh"` | 中国語に固定 |
| 日本語 | `"ja"` | 日本語に固定 |
| 韓国語 | `"ko"` | 韓国語に固定 |
| フランス語 | `"fr"` | フランス語に固定 |
| ドイツ語 | `"de"` | ドイツ語に固定 |

**推奨**: 言語が既知の場合は手動指定で精度向上。

## タイムスタンプ取得

レスポンスの `segments` 配列にタイムスタンプ情報が含まれる:

```json
{
  "text": "Hello, how are you today?",
  "duration": 3.5,
  "segments": [
    { "start": 0.0, "end": 1.2, "text": "Hello," },
    { "start": 1.3, "end": 2.1, "text": "how are you" },
    { "start": 2.2, "end": 3.5, "text": "today?" }
  ]
}
```

### `ignore_timestamps` パラメータ

| 値 | 動作 | 用途 |
|---|---|---|
| `true` | タイムスタンプなし（高速） | テキストのみ必要な場合 |
| `false` | タイムスタンプ付き（詳細） | 字幕生成、音声編集 |

## スピーカー検出（Diarization）

複数話者を自動識別:

```json
{
  "segments": [
    { "start": 0.0, "end": 2.5, "text": "Let's begin.", "speaker": "SPEAKER_00" },
    { "start": 2.8, "end": 5.1, "text": "Sounds good.", "speaker": "SPEAKER_01" }
  ]
}
```

## 自動フォーマッティング

STTは以下を自動処理:

- **大文字化**: 文頭の大文字化
- **句読点**: ピリオド、カンマの自動挿入
- **段落分割**: 長いポーズでの段落分離

## 認識精度

| 音声環境 | 精度目安 |
|---|---|
| プロフェッショナル録音 | 95-98% |
| アマチュア録音 | 90-95% |
| 電話音声 | 85-90% |
| 騒音環境 | 75-85% |

## コード例

### cURL

```bash
curl -X POST "https://api.fish.audio/v1/asr" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -F file=@audio.mp3 \
  -F language="ja" \
  -F ignore_timestamps=false
```

### Python

```python
from fish_audio_sdk import FishAudio

client = FishAudio(api_key="your-api-key")

with open("audio.mp3", "rb") as f:
    result = client.asr.transcribe(
        audio=f.read(),
        language="ja",
        ignore_timestamps=False,
    )

print(result.text)
for segment in result.segments:
    print(f"[{segment.start:.1f}s - {segment.end:.1f}s] {segment.text}")
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: "your-api-key" });

const result = await client.speechToText.convert({
  file: fs.createReadStream("audio.mp3"),
  language: "ja",
  ignore_timestamps: false,
});

console.log(result.text);
for (const segment of result.segments) {
  console.log(`[${segment.start.toFixed(1)}s - ${segment.end.toFixed(1)}s] ${segment.text}`);
}
```
