# Integrations ガイド — Fish Audio

## Pipecat 統合

[Pipecat](https://github.com/pipecat-ai/pipecat) はリアルタイム音声AIパイプラインフレームワーク。

### インストール

```bash
pip install "pipecat-ai[fish]"
```

### 基本的な使い方

```python
from pipecat.services.fish import FishAudioTTSService

tts = FishAudioTTSService(
    api_key="your-api-key",
    model_id="voice-model-id",
)

# パイプラインに組み込み
pipeline = Pipeline([
    llm_service,
    tts,
    audio_output,
])
```

### 設定オプション

```python
tts = FishAudioTTSService(
    api_key="your-api-key",
    model_id="voice-model-id",
    sample_rate=24000,
    language="ja",
)
```

## LiveKit 統合

LiveKit のエージェントフレームワークで Fish Audio TTS を使用:

```python
from livekit.agents import tts

fish_tts = tts.FishAudioTTS(
    api_key="your-api-key",
    model_id="voice-model-id",
)
```

## n8n 統合

コミュニティノード `n8n-nodes-fishaudio` で n8n ワークフローに統合:

```bash
# n8n コミュニティノードとしてインストール
# n8n UI → Settings → Community Nodes → Install
# パッケージ名: n8n-nodes-fishaudio
```

ノードの設定:
- **API Key**: Fish Audio APIキー
- **Operation**: TTS / STT / Voice Clone
- **Voice Model**: ボイスモデルID
- **Text**: 読み上げテキスト

## Next.js API Route 連携

### App Router（Route Handler）

```typescript
// app/api/tts/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const { text, voiceId } = await request.json();

  const response = await fetch("https://api.fish.audio/v1/tts", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.FISH_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text,
      reference_id: voiceId,
      format: "mp3",
    }),
  });

  const audioBuffer = await response.arrayBuffer();

  return new NextResponse(audioBuffer, {
    headers: {
      "Content-Type": "audio/mpeg",
      "Content-Disposition": 'inline; filename="speech.mp3"',
    },
  });
}
```

### ストリーミング対応

```typescript
// app/api/tts/stream/route.ts
import { NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const { text, voiceId } = await request.json();

  const response = await fetch("https://api.fish.audio/v1/tts", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.FISH_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text,
      reference_id: voiceId,
      format: "mp3",
    }),
  });

  // レスポンスボディをそのままストリーミング
  return new Response(response.body, {
    headers: {
      "Content-Type": "audio/mpeg",
      "Transfer-Encoding": "chunked",
    },
  });
}
```

## Express.js ミドルウェア

```javascript
import express from "express";
import { FishAudioClient } from "fish-audio";

const app = express();
const fishClient = new FishAudioClient({ apiKey: process.env.FISH_API_KEY });

// TTS ミドルウェア
app.post("/api/tts", express.json(), async (req, res) => {
  try {
    const { text, voiceId, format = "mp3" } = req.body;

    const audio = await fishClient.textToSpeech.convert({
      text,
      reference_id: voiceId,
      format,
    });

    res.set("Content-Type", format === "wav" ? "audio/wav" : "audio/mpeg");
    res.send(Buffer.from(audio));
  } catch (error) {
    if (error.status === 429) {
      res.status(429).json({ error: "Rate limit exceeded" });
    } else {
      res.status(500).json({ error: "TTS generation failed" });
    }
  }
});
```

## フロントエンドオーディオ再生（Web Audio API）

```javascript
// ブラウザでの音声再生
async function playTTS(text, voiceId) {
  const response = await fetch("/api/tts", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text, voiceId }),
  });

  const arrayBuffer = await response.arrayBuffer();
  const audioContext = new AudioContext();
  const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

  const source = audioContext.createBufferSource();
  source.buffer = audioBuffer;
  source.connect(audioContext.destination);
  source.start();

  return source; // stop() で停止可能
}

// HTML5 Audio 要素での再生（シンプル版）
async function playWithAudioElement(text, voiceId) {
  const response = await fetch("/api/tts", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text, voiceId }),
  });

  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const audio = new Audio(url);
  audio.play();

  audio.onended = () => URL.revokeObjectURL(url);
}
```
