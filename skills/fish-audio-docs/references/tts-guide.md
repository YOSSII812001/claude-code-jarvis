# TTS ガイド — Fish Audio

## 概要

Fish Audio TTS は、テキストから自然な音声を生成する。S2-Proモデルで80+言語対応、
100msの低遅延を実現。感情制御、Multi-speaker、Prosody調整が可能。

## 基本パラメータ

| パラメータ | 型 | デフォルト | 説明 |
|---|---|---|---|
| `text` | string | **必須** | 読み上げテキスト |
| `reference_id` | string | — | 使用するボイスモデルID |
| `format` | string | `"mp3"` | 出力形式: `mp3`, `wav`, `pcm`, `opus` |
| `chunk_length` | int | `200` | テキストチャンク長（100-300） |
| `latency` | string | `"normal"` | レイテンシモード: `normal`, `balanced` |
| `temperature` | float | `0.7` | ランダム性（0-1.0、低=安定、高=多様） |
| `top_p` | float | `0.8` | 核サンプリング（0-1.0） |
| `mp3_bitrate` | int | `128` | MP3 ビットレート: 64, 128, 192 |

## Prosody 制御

音声の速度と音量を調整する:

| パラメータ | 範囲 | デフォルト | 説明 |
|---|---|---|---|
| `speed` | 0.5 - 2.0 | 1.0 | 読み上げ速度（1.0=通常） |
| `volume` | -20 ~ +20 | 0 | 音量調整（dB単位） |
| `normalize_loudness` | bool | false | ラウドネス正規化 |

## オーディオ形式

| 形式 | 用途 | 詳細 |
|---|---|---|
| **MP3** | 一般配信 | 64/128/192 kbps 選択可 |
| **WAV** | 高品質編集 | 44100Hz、非圧縮 |
| **PCM** | リアルタイム処理 | 16kHz、16bit、ヘッダなし |
| **Opus** | 低帯域配信 | 48kbps、WebRTC互換 |

## Multi-speaker（S2-Proのみ）

複数話者による会話音声を生成:

```
テキスト内でスピーカーを指定:
<|speaker:0|>こんにちは、田中です。
<|speaker:1|>はじめまして、鈴木です。
```

`reference_id` を配列で指定し、各スピーカーに異なるボイスを割り当てる:

```json
{
  "text": "<|speaker:0|>Hello! <|speaker:1|>Hi there!",
  "references": [
    {"id": "voice-id-1", "speaker": 0},
    {"id": "voice-id-2", "speaker": 1}
  ]
}
```

## 感情制御

### S2-Pro: ブラケット構文

S2-Proモデルでは、自然言語の `[bracket]` 構文で感情を制御する:

```
[happy] Today is a wonderful day!
[whispers sweetly] I have a secret to tell you.
[laughing nervously] Well, that was unexpected...
[sad, with a trembling voice] I can't believe it's over.
```

### S1: 括弧構文（前世代）

S1モデルでは `(emotion)` 構文を使用:

```
(happy) Today is a wonderful day!
(sad) I miss those times.
```

### 基本感情（24種）

| カテゴリ | 感情 |
|---|---|
| ポジティブ | `happy`, `excited`, `cheerful`, `enthusiastic`, `joyful`, `delighted` |
| ネガティブ | `sad`, `angry`, `frustrated`, `disappointed`, `annoyed`, `furious` |
| 穏やか | `calm`, `gentle`, `soothing`, `peaceful`, `relaxed`, `serene` |
| 強い | `confident`, `determined`, `authoritative`, `powerful`, `bold`, `assertive` |

### 高度な感情（25種）

| カテゴリ | 感情 |
|---|---|
| 親密 | `whispers`, `whispers sweetly`, `intimate`, `tender`, `loving` |
| 驚き | `surprised`, `shocked`, `amazed`, `astonished`, `bewildered` |
| 恐怖 | `scared`, `terrified`, `anxious`, `nervous`, `worried` |
| 皮肉 | `sarcastic`, `ironic`, `mocking`, `contemptuous`, `dismissive` |
| 物語 | `storytelling`, `dramatic`, `mysterious`, `suspenseful`, `narrator` |

### トーンマーカー（5種）

| マーカー | 効果 |
|---|---|
| `[speaks slowly]` | ゆっくり話す |
| `[speaks quickly]` | 早口で話す |
| `[speaks softly]` | 小さな声で話す |
| `[speaks loudly]` | 大きな声で話す |
| `[with emphasis]` | 強調して話す |

### オーディオエフェクト（10種）

| エフェクト | 効果 |
|---|---|
| `[laughing]` | 笑いながら |
| `[crying]` | 泣きながら |
| `[sighing]` | ため息交じりに |
| `[gasping]` | 息を呑んで |
| `[yawning]` | あくびしながら |
| `[coughing]` | 咳をしながら |
| `[clearing throat]` | 喉を鳴らして |
| `[humming]` | ハミングしながら |
| `[breathing heavily]` | 激しく息をしながら |
| `[whispering]` | ささやきながら |

### 感情制御のベストプラクティス

1. **文頭に配置**: 感情マーカーは文の先頭に置く
2. **1文1感情**: 1つの文に1つの感情マーカー
3. **段階的遷移**: 急な感情変化を避け、段階的に変える
4. **組み合わせ**: `[happy, speaking softly]` のように複合指定可能

```
[calm] Let me tell you a story.
[mysterious] It happened on a dark night.
[excited] And then, something amazing occurred!
[whispers] But nobody else knows about it.
```

## テキスト入力のベストプラクティス

- **適切な句読点**: ピリオド、カンマで自然なポーズを挿入
- **チャンク分割**: 200文字程度で分割（長文は品質低下の原因）
- **略語展開**: "Dr." → "Doctor"、"etc." → "et cetera" 等
- **数字の表記**: 文脈に応じて "100" → "one hundred" に展開
- **SSML非対応**: Fish Audio はSSMLを使用しない。自然言語で指示する

## コード例

### cURL

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -o output.mp3 \
  -d '{
    "text": "[happy] Good morning! How are you today?",
    "reference_id": "e58b0d7efca34aa8b7fed4a0b8074cec",
    "format": "mp3",
    "mp3_bitrate": 128,
    "prosody": {
      "speed": 1.0,
      "volume": 0
    }
  }'
```

### Python

```python
from fish_audio_sdk import FishAudio, TTSConfig, Prosody

client = FishAudio(api_key="your-api-key")

config = TTSConfig(
    format="mp3",
    mp3_bitrate=128,
    chunk_length=200,
    temperature=0.7,
    top_p=0.8,
    prosody=Prosody(speed=1.0, volume=0),
)

audio = client.tts.convert(
    text="[happy] Good morning! How are you today?",
    reference_id="e58b0d7efca34aa8b7fed4a0b8074cec",
    config=config,
)
with open("output.mp3", "wb") as f:
    f.write(audio)
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";

const client = new FishAudioClient({ apiKey: "your-api-key" });

const audio = await client.textToSpeech.convert({
  text: "[happy] Good morning! How are you today?",
  reference_id: "e58b0d7efca34aa8b7fed4a0b8074cec",
  format: "mp3",
  mp3_bitrate: 128,
  prosody: { speed: 1.0, volume: 0 },
});

const fs = await import("fs");
fs.writeFileSync("output.mp3", Buffer.from(audio));
```
