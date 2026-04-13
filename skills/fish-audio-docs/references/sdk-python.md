# Python SDK ガイド — Fish Audio

## インストール

```bash
# uv（推奨）
uv add fish-audio-sdk

# Poetry
poetry add fish-audio-sdk

# Conda
conda install -c conda-forge fish-audio-sdk

# pip
pip install fish-audio-sdk
```

**要件**: Python 3.9+

## 認証

```python
from fish_audio_sdk import FishAudio

# 直接指定
client = FishAudio(api_key="your-api-key")

# 環境変数（推奨）
# FISH_API_KEY が設定されていれば自動取得
client = FishAudio()
```

## Core Clients

| クライアント | 用途 |
|---|---|
| `client.tts` | テキスト → 音声変換 |
| `client.asr` | 音声 → テキスト変換 |
| `client.voices` | ボイスモデル管理 |
| `client.account` | アカウント情報・クレジット |

## 同期パターン — FishAudio

### TTS（テキスト → 音声）

```python
from fish_audio_sdk import FishAudio, TTSConfig, Prosody

client = FishAudio(api_key="your-api-key")

# シンプルな変換
audio = client.tts.convert(
    text="Hello, world!",
    reference_id="voice-model-id",
)
with open("output.mp3", "wb") as f:
    f.write(audio)

# 詳細設定
config = TTSConfig(
    format="wav",
    chunk_length=200,
    temperature=0.7,
    top_p=0.8,
    prosody=Prosody(speed=1.2, volume=5),
)

audio = client.tts.convert(
    text="[happy] Great to meet you!",
    reference_id="voice-model-id",
    config=config,
)
```

### ASR（音声 → テキスト）

```python
with open("audio.mp3", "rb") as f:
    result = client.asr.transcribe(
        audio=f.read(),
        language="ja",
        ignore_timestamps=False,
    )

print(result.text)
for seg in result.segments:
    print(f"[{seg.start:.1f}s - {seg.end:.1f}s] {seg.text}")
```

### Voices（ボイスモデル管理）

```python
# 一覧取得
voices = client.voices.list(page=1, page_size=10)
for voice in voices:
    print(f"{voice.id}: {voice.name}")

# 取得
voice = client.voices.get("voice-model-id")

# 作成（Persistent Clone）
voice = client.voices.create(
    name="My Voice",
    description="Custom voice model",
    audio_files=["clip1.wav", "clip2.wav"],
    transcripts=["Transcript for clip 1.", "Transcript for clip 2."],
    enhance_audio_quality=True,
)

# 更新
client.voices.update("voice-model-id", name="Updated Name")

# 削除
client.voices.delete("voice-model-id")
```

### Account（アカウント情報）

```python
credits = client.account.get_credits()
print(f"Remaining credits: {credits.balance}")

package = client.account.get_package()
print(f"Plan: {package.name}")
```

## 非同期パターン — AsyncFishAudio

全メソッドが `await` 対応:

```python
from fish_audio_sdk import AsyncFishAudio

client = AsyncFishAudio(api_key="your-api-key")

# TTS
audio = await client.tts.convert(
    text="Async hello!",
    reference_id="voice-model-id",
)

# ASR
with open("audio.mp3", "rb") as f:
    result = await client.asr.transcribe(audio=f.read())

# Voices
voices = await client.voices.list()
```

## TTSConfig / Prosody 型

```python
from fish_audio_sdk import TTSConfig, Prosody

config = TTSConfig(
    format="mp3",           # "mp3" | "wav" | "pcm" | "opus"
    mp3_bitrate=128,        # 64 | 128 | 192
    chunk_length=200,       # 100-300
    temperature=0.7,        # 0-1.0
    top_p=0.8,              # 0-1.0
    latency="normal",       # "normal" | "balanced"
    prosody=Prosody(
        speed=1.0,          # 0.5-2.0
        volume=0,           # -20 ~ +20
    ),
    normalize_loudness=False,
)
```

## ReferenceAudio 型（Instant Clone 用）

```python
from fish_audio_sdk import ReferenceAudio

with open("sample.wav", "rb") as f:
    ref = ReferenceAudio(
        audio=f.read(),
        text="This is the reference transcript.",
    )

audio = client.tts.convert(
    text="Clone this voice!",
    references=[ref],
)
```

## ストリーミング

### HTTP ストリーミング

```python
# 同期
for chunk in client.tts.stream(
    text="Streaming audio generation.",
    reference_id="voice-model-id",
):
    play_audio(chunk)

# 非同期
async for chunk in client.tts.stream(
    text="Async streaming.",
    reference_id="voice-model-id",
):
    play_audio(chunk)
```

### WebSocket ストリーミング

```python
# シンプルなWebSocketストリーミング
async for chunk in client.tts.stream_websocket(
    text="WebSocket streaming example.",
    reference_id="voice-model-id",
    format="mp3",
    latency="balanced",
):
    play_audio(chunk)
```

### FlushEvent を使った段階的生成

```python
ws = await client.tts.connect_websocket(
    reference_id="voice-model-id",
    format="mp3",
    latency="low",
)

# 段階的にテキスト送信 → flush で生成トリガー
await ws.send_text("First part of the speech. ")
await ws.flush()

async for audio_chunk in ws.receive():
    play_audio(audio_chunk)

await ws.send_text("Second part continues here. ")
await ws.flush()

async for audio_chunk in ws.receive():
    play_audio(audio_chunk)

await ws.close()
```

## ユーティリティ

```python
from fish_audio_sdk import save, play, stream

# ファイルに保存
save(audio_bytes, "output.mp3")

# 直接再生（ローカルスピーカー）
play(audio_bytes)

# ストリーミング再生
stream(client.tts.stream(text="Hello!", reference_id="id"))
```

## エラーハンドリング

```python
from fish_audio_sdk import (
    FishAudioError,
    AuthenticationError,
    RateLimitError,
    ValidationError,
)

try:
    audio = client.tts.convert(text="Hello!", reference_id="id")
except AuthenticationError:
    print("APIキーが無効です")
except RateLimitError as e:
    print(f"レート制限に到達。{e.retry_after}秒後にリトライ")
except ValidationError as e:
    print(f"リクエストが不正: {e.message}")
except FishAudioError as e:
    print(f"予期しないエラー: {e}")
```

## 完全な例: TTS + ファイル保存

```python
import asyncio
from fish_audio_sdk import AsyncFishAudio, TTSConfig, Prosody

async def main():
    client = AsyncFishAudio()

    config = TTSConfig(
        format="mp3",
        mp3_bitrate=192,
        prosody=Prosody(speed=1.0, volume=0),
    )

    texts = [
        "[calm] Welcome to our presentation.",
        "[enthusiastic] Today we'll cover exciting new features!",
        "[serious] Let's look at the data first.",
    ]

    for i, text in enumerate(texts):
        audio = await client.tts.convert(
            text=text,
            reference_id="voice-model-id",
            config=config,
        )
        with open(f"slide_{i+1}.mp3", "wb") as f:
            f.write(audio)
        print(f"Generated slide_{i+1}.mp3")

asyncio.run(main())
```
