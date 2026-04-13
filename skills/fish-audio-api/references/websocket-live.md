# WebSocket Live TTS

## 基本情報

- **URL**: `WSS wss://api.fish.audio/v1/tts/live`
- **プロトコル**: WebSocket + MessagePack
- **用途**: リアルタイム音声ストリーミング（低レイテンシ）

## 必須ヘッダー

| ヘッダー | 値 | 説明 |
|---------|-----|------|
| Authorization | `Bearer {FISH_API_KEY}` | 認証トークン |
| model | `s1` または `s2-pro` | 使用モデル |

## メッセージ形式

すべてのメッセージは **MessagePack** でエンコードされる。

## クライアント → サーバー

### StartEvent（初期化、接続ごとに1回）

```json
{
  "event": "start",
  "request": {
    "text": "",
    "format": "mp3",
    "reference_id": "MODEL_ID_HERE",
    "latency": "normal",
    "temperature": 0.7,
    "top_p": 0.7,
    "chunk_length": 300,
    "prosody": {
      "speed": 1.0,
      "volume": 0
    }
  }
}
```

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| event | string | Yes | `"start"` 固定 |
| request.text | string | No | 空文字列でOK（テキストは TextEvent で送る） |
| request.format | string | No | `mp3`, `wav`, `pcm`, `opus` |
| request.reference_id | string | Yes | 話者モデルID |
| request.latency | string | No | `low`, `balanced`, `normal` |
| request.temperature | float | No | 0-1 |
| request.top_p | float | No | 0-1 |
| request.chunk_length | int | No | 100-300 |
| request.prosody | object | No | 韻律制御 |

### TextEvent（複数回送信可）

```json
{
  "event": "text",
  "text": "送信するテキスト"
}
```

テキストは段階的に送信可能。5-10単語ごと、完全な単語＋スペースで区切ることを推奨。

### FlushEvent（オプション、バッファ強制フラッシュ）

```json
{
  "event": "flush"
}
```

バッファに残っているテキストの音声生成を即座に開始させる。文の区切りで使用推奨。

### CloseEvent（完了通知）

```json
{
  "event": "stop"
}
```

## サーバー → クライアント

### AudioEvent（複数回）

```json
{
  "event": "audio",
  "audio": "<binary_chunk>"
}
```

生成された音声データのチャンク。受信したらすぐに再生またはバッファリングする。

### FinishEvent（終了通知）

```json
{
  "event": "finish",
  "reason": "stop"
}
```

| reason | 説明 |
|--------|------|
| `stop` | 正常完了 |
| `error` | エラー発生 |

## 接続ライフサイクル

```
接続確立
  → StartEvent（1回）
  → TextEvent × N回
  → FlushEvent（任意）
  → TextEvent × N回
  → CloseEvent
  ← AudioEvent × N回（非同期で随時受信）
  ← FinishEvent
接続終了
```

## レイテンシモード

| モード | 初回音声までの遅延 | 用途 |
|--------|-------------------|------|
| `normal` | ~500ms | 高品質、バッチ処理 |
| `balanced` | ~300ms | 品質とレイテンシのバランス |
| `low` | 最速 | リアルタイム会話、チャットボット |

## 運用ガイドライン

### 再接続

- 接続断はネットワーク障害やサーバー再起動で発生する
- **指数バックオフ**で自動再接続を実装する（1s → 2s → 4s → 8s、最大30s）
- 再接続時は新しい StartEvent から開始する

### バックプレッシャー

- サーバーからの AudioEvent を消費しないとバッファが溢れる
- 再生速度に合わせて AudioEvent を処理すること
- バッファが溜まりすぎた場合は古いチャンクを破棄するか接続を再開する

### テキストバッファリング

- 1文字ずつではなく、5-10単語ごとにまとめて送信
- 完全な単語＋スペースで区切る（単語の途中で分割しない）
- 句読点の位置で FlushEvent を送ると自然な区切りになる

## コード例

### Python

```python
import asyncio
import msgpack
import websockets

async def stream_tts():
    uri = "wss://api.fish.audio/v1/tts/live"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "model": "s1",
    }

    async with websockets.connect(uri, extra_headers=headers) as ws:
        # StartEvent
        start_event = msgpack.packb({
            "event": "start",
            "request": {
                "text": "",
                "format": "mp3",
                "reference_id": "MODEL_ID_HERE",
                "latency": "low",
            }
        })
        await ws.send(start_event)

        # TextEvent（段階的送信）
        sentences = ["こんにちは、世界。", "今日はいい天気ですね。"]
        for sentence in sentences:
            text_event = msgpack.packb({
                "event": "text",
                "text": sentence,
            })
            await ws.send(text_event)

            # FlushEvent（文の区切り）
            flush_event = msgpack.packb({"event": "flush"})
            await ws.send(flush_event)

        # CloseEvent
        close_event = msgpack.packb({"event": "stop"})
        await ws.send(close_event)

        # AudioEvent 受信
        audio_chunks = []
        while True:
            data = await ws.recv()
            msg = msgpack.unpackb(data)
            if msg["event"] == "audio":
                audio_chunks.append(msg["audio"])
            elif msg["event"] == "finish":
                print(f"完了: {msg['reason']}")
                break

        # 音声保存
        with open("output.mp3", "wb") as f:
            for chunk in audio_chunks:
                f.write(chunk)

asyncio.run(stream_tts())
```

### JavaScript

```javascript
import WebSocket from "ws";
import msgpack from "@msgpack/msgpack";
import fs from "fs";

const ws = new WebSocket("wss://api.fish.audio/v1/tts/live", {
  headers: {
    Authorization: `Bearer ${process.env.FISH_API_KEY}`,
    model: "s1",
  },
});

const audioChunks = [];

ws.on("open", () => {
  // StartEvent
  ws.send(msgpack.encode({
    event: "start",
    request: {
      text: "",
      format: "mp3",
      reference_id: "MODEL_ID_HERE",
      latency: "low",
    },
  }));

  // TextEvent
  const sentences = ["こんにちは、世界。", "今日はいい天気ですね。"];
  for (const sentence of sentences) {
    ws.send(msgpack.encode({ event: "text", text: sentence }));
    ws.send(msgpack.encode({ event: "flush" }));
  }

  // CloseEvent
  ws.send(msgpack.encode({ event: "stop" }));
});

ws.on("message", (data) => {
  const msg = msgpack.decode(data);
  if (msg.event === "audio") {
    audioChunks.push(Buffer.from(msg.audio));
  } else if (msg.event === "finish") {
    console.log(`完了: ${msg.reason}`);
    fs.writeFileSync("output.mp3", Buffer.concat(audioChunks));
    ws.close();
  }
});

ws.on("error", (err) => {
  console.error("WebSocket エラー:", err.message);
});
```
