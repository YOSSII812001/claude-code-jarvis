# Streaming ガイド — Fish Audio

## 概要

Fish Audio WebSocket TTS Live は、リアルタイムでテキストを音声に変換する。
LLMのストリーミング出力と組み合わせることで、低遅延の音声対話を実現する。

**エンドポイント**: `wss://api.fish.audio/v1/tts/live`

**プロトコル**: MessagePack 形式のバイナリメッセージ

## メッセージフロー

```
Client                              Server
  │                                    │
  │──── StartEvent ──────────────────>│  接続設定
  │                                    │
  │──── TextEvent("Hello") ─────────>│  テキスト送信
  │──── TextEvent(" world") ────────>│  追加テキスト
  │──── FlushEvent ──────────────────>│  生成トリガー
  │                                    │
  │<──── AudioEvent(binary) ──────────│  音声チャンク
  │<──── AudioEvent(binary) ──────────│  音声チャンク
  │<──── FinishEvent ─────────────────│  生成完了
  │                                    │
  │──── TextEvent("Next sentence") ─>│  次のテキスト
  │──── FlushEvent ──────────────────>│  生成トリガー
  │                                    │
  │<──── AudioEvent(binary) ──────────│  音声チャンク
  │<──── FinishEvent ─────────────────│  生成完了
  │                                    │
  │──── CloseEvent ──────────────────>│  切断
```

## クライアント → サーバー メッセージ

### StartEvent

接続時に最初に送信。設定を指定する:

```json
{
  "event": "start",
  "request": {
    "reference_id": "voice-model-id",
    "format": "mp3",
    "latency": "normal",
    "prosody": { "speed": 1.0, "volume": 0 }
  }
}
```

### TextEvent

読み上げるテキストを送信:

```json
{
  "event": "text",
  "text": "Hello, how are you "
}
```

### FlushEvent

蓄積されたテキストの音声生成をトリガー:

```json
{
  "event": "flush"
}
```

### CloseEvent

接続を閉じる:

```json
{
  "event": "close"
}
```

## サーバー → クライアント メッセージ

### AudioEvent

音声データのバイナリチャンク（MessagePack binary）。

### FinishEvent

1つの FlushEvent に対する音声生成の完了を通知:

```json
{
  "event": "finish"
}
```

## レイテンシモード

| モード | 最初の音声まで | 用途 |
|---|---|---|
| `normal` | ~500ms | 高品質優先 |
| `balanced` | ~300ms | バランス型 |
| `low` | 最速 | リアルタイム対話 |

## テキストバッファリング戦略

- **5-10単語ごと**に TextEvent を送信
- **完全な単語**（スペース区切り）で送信（単語の途中で分割しない）
- **文の区切り**（ピリオド、カンマ等）で FlushEvent を送信
- FlushEvent なしでは音声生成が始まらない

```
Good pattern:
  TextEvent("The weather is ")
  TextEvent("beautiful today.")
  FlushEvent()

Bad pattern:
  TextEvent("The weath")   # 単語の途中で分割
  TextEvent("er is...")
```

## 接続管理

- **接続の再利用**: 同一セッション内で複数の発話に再利用推奨
- **再接続**: 切断時は指数バックオフで再接続
- **Close code**: 正常終了は 1000、エラーは 1008 以上

## 再生最適化

- **バッファリング**: 2-3チャンク分の AudioEvent をバッファしてから再生開始
- **クロスフェード**: チャンク間で 10-20ms のクロスフェードで途切れ防止
- **再生キュー**: AudioEvent を順序どおりにキューに積む

## コード例

### Python（WebSocket ストリーミング）

```python
from fish_audio_sdk import FishAudio

client = FishAudio(api_key="your-api-key")

# ストリーミングTTS
async for chunk in client.tts.stream_websocket(
    text="Hello, this is a streaming example!",
    reference_id="voice-model-id",
    format="mp3",
    latency="balanced",
):
    # chunk はバイナリ音声データ
    play_audio(chunk)

# FlushEvent を使った段階的生成
import asyncio

async def streaming_tts():
    ws = await client.tts.connect_websocket(
        reference_id="voice-model-id",
        format="mp3",
        latency="low",
    )

    # テキストを段階的に送信
    await ws.send_text("First sentence. ")
    await ws.flush()  # 音声生成トリガー

    async for audio_chunk in ws.receive():
        play_audio(audio_chunk)

    await ws.send_text("Second sentence. ")
    await ws.flush()

    async for audio_chunk in ws.receive():
        play_audio(audio_chunk)

    await ws.close()
```

### JavaScript（WebSocket 直接接続）

```javascript
import msgpack from "msgpackr";

const ws = new WebSocket("wss://api.fish.audio/v1/tts/live");
ws.binaryType = "arraybuffer";

ws.onopen = () => {
  // StartEvent
  ws.send(
    msgpack.pack({
      event: "start",
      request: {
        reference_id: "voice-model-id",
        format: "mp3",
        latency: "balanced",
      },
    })
  );

  // TextEvent + FlushEvent
  ws.send(msgpack.pack({ event: "text", text: "Hello, world! " }));
  ws.send(msgpack.pack({ event: "flush" }));
};

ws.onmessage = (event) => {
  const msg = msgpack.unpack(new Uint8Array(event.data));
  if (msg.event === "audio") {
    // msg.audio はバイナリ音声データ
    playAudio(msg.audio);
  } else if (msg.event === "finish") {
    console.log("Audio generation complete");
  }
};
```

## LLM統合パターン

LLMのストリーミング出力をリアルタイムで音声化する:

```javascript
import { streamText } from "ai";
import msgpack from "msgpackr";

// WebSocket接続を確立
const ws = new WebSocket("wss://api.fish.audio/v1/tts/live");

// LLMストリーミング → TTS
const { textStream } = await streamText({
  model: yourModel,
  prompt: "Tell me a story",
});

let buffer = "";
for await (const chunk of textStream) {
  buffer += chunk;

  // 文の区切りで FlushEvent
  if (buffer.match(/[.!?]\s*$/)) {
    ws.send(msgpack.pack({ event: "text", text: buffer }));
    ws.send(msgpack.pack({ event: "flush" }));
    buffer = "";
  }
}

// 残りのテキストを送信
if (buffer.trim()) {
  ws.send(msgpack.pack({ event: "text", text: buffer }));
  ws.send(msgpack.pack({ event: "flush" }));
}
```
