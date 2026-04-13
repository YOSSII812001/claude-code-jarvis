# Voice Cloning ガイド — Fish Audio

## 概要

Fish Audio Voice Cloning は音声サンプルから声を複製する。2つの方式がある:

| 方式 | 用途 | 永続性 | 最小音声長 |
|---|---|---|---|
| **Instant Clone** | 一時利用、テスト | セッション限り | 10秒 |
| **Persistent Clone** | プロダクション | モデルとして保存 | 10秒（推奨30-60秒） |

## Instant Clone

リクエスト時に音声ファイルとテキストを直接渡す方式。モデル作成不要:

### cURL

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -F text="Hello, this is my cloned voice!" \
  -F references="@sample.wav" \
  -F reference_texts="This is the original speech content." \
  -o output.mp3
```

### Python

```python
from fish_audio_sdk import FishAudio, ReferenceAudio

client = FishAudio(api_key="your-api-key")

with open("sample.wav", "rb") as f:
    ref = ReferenceAudio(audio=f.read(), text="This is the original speech content.")

audio = client.tts.convert(
    text="Hello, this is my cloned voice!",
    references=[ref],
)
with open("output.mp3", "wb") as f:
    f.write(audio)
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: "your-api-key" });

const audio = await client.textToSpeech.convert({
  text: "Hello, this is my cloned voice!",
  references: [
    {
      audio: fs.readFileSync("sample.wav"),
      text: "This is the original speech content.",
    },
  ],
});
fs.writeFileSync("output.mp3", Buffer.from(audio));
```

## Persistent Clone

音声モデルを作成・保存する方式。一度作成すれば `reference_id` で繰り返し使用可能:

### Python

```python
from fish_audio_sdk import FishAudio

client = FishAudio(api_key="your-api-key")

# モデル作成
voice = client.voices.create(
    name="My Custom Voice",
    description="Professional narration voice",
    audio_files=["clip1.wav", "clip2.wav"],
    transcripts=["First clip transcript.", "Second clip transcript."],
    enhance_audio_quality=True,
)
print(f"Voice ID: {voice.id}")

# 作成したモデルで TTS
audio = client.tts.convert(
    text="Now using my persistent voice model!",
    reference_id=voice.id,
)
with open("output.mp3", "wb") as f:
    f.write(audio)
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: "your-api-key" });

// モデル作成
const voice = await client.voices.ivc.create({
  name: "My Custom Voice",
  description: "Professional narration voice",
  voices: [
    {
      audio: fs.createReadStream("clip1.wav"),
      transcript: "First clip transcript.",
    },
    {
      audio: fs.createReadStream("clip2.wav"),
      transcript: "Second clip transcript.",
    },
  ],
});
console.log(`Voice ID: ${voice._id}`);

// 作成したモデルで TTS
const audio = await client.textToSpeech.convert({
  text: "Now using my persistent voice model!",
  reference_id: voice._id,
});
fs.writeFileSync("output.mp3", Buffer.from(audio));
```

## 録音品質基準

### 音声の長さ

| 条件 | 推奨 |
|---|---|
| 最小 | 10秒 |
| 最適 | 30-60秒 |
| 複数クリップ推奨 | 2-3クリップ × 15-20秒 |

### 録音環境

- **場所**: 静かな室内（反響の少ない部屋）
- **マイク**: USBコンデンサーマイク推奨（ヘッドセットでも可）
- **距離**: マイクから手幅分の距離（15-20cm）
- **フォーマット**: WAV/FLAC 推奨（非圧縮/ロスレス）

### 避けるべき環境

- 交通騒音（車、電車）
- 家電音（エアコン、冷蔵庫のコンプレッサー）
- 複数話者の混在
- エコーが強い大きな部屋
- 風切り音

## 品質向上テクニック

| テクニック | 効果 |
|---|---|
| トランスクリプト付与 | 音声とテキストの対応で精度向上 |
| `enhance_audio_quality=True` | サーバー側でノイズリダクション |
| 複数クリップ使用 | 声の特徴をより正確に捉える |
| 異なる文体で録音 | 表現力の幅が広がる |

## トラブルシューティング

| 問題 | 原因 | 解決策 |
|---|---|---|
| ロボット的な音声 | 音声サンプルが短すぎる | 30秒以上のサンプルを使用 |
| 声が一致しない | ノイズが多い、複数話者混在 | クリーンな環境で再録音 |
| 低品質な出力 | 圧縮音源を使用 | WAV/FLAC の非圧縮音源を使用 |
| アクセントの問題 | 参照音声と出力言語の不一致 | 出力言語と同じ言語で参照音声を録音 |
| 感情が平坦 | 参照音声の表現が乏しい | 表現豊かな音声サンプルを用意 |

## 倫理要件

- **自身の声**: 自分の声のクローンは自由に作成可能
- **他者の声**: 書面による明示的な同意が**必須**
- **公人の声**: 無断での複製・使用は**禁止**
- **商用利用**: 権利関係を事前に確認すること
- **悪用禁止**: なりすまし、詐欺目的での使用は利用規約違反
