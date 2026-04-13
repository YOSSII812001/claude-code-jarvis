# JavaScript SDK ガイド — Fish Audio

## インストール

```bash
# npm
npm install fish-audio

# yarn
yarn add fish-audio

# pnpm
pnpm add fish-audio
```

**要件**: Node.js 18+

## 認証

```javascript
import { FishAudioClient } from "fish-audio";

// 直接指定
const client = new FishAudioClient({ apiKey: "your-api-key" });

// 環境変数（推奨）
// FISH_API_KEY が設定されていれば自動取得
const client = new FishAudioClient();
```

## メソッドマッピング

| メソッド | 用途 |
|---|---|
| `client.textToSpeech.convert(request, model?)` | テキスト → 音声変換 |
| `client.speechToText.convert(request)` | 音声 → テキスト変換 |
| `client.voices.search(params?)` | ボイスモデル検索 |
| `client.voices.get(id)` | ボイスモデル取得 |
| `client.voices.ivc.create(request)` | ボイスモデル作成 |
| `client.voices.update(id, request)` | ボイスモデル更新 |
| `client.voices.delete(id)` | ボイスモデル削除 |
| `client.account.get_api_credit()` | クレジット残高取得 |
| `client.account.get_package()` | パッケージ情報取得 |

## TTS（テキスト → 音声）

### 基本的な使い方

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient({ apiKey: "your-api-key" });

const audio = await client.textToSpeech.convert({
  text: "Hello, world!",
  reference_id: "voice-model-id",
});

fs.writeFileSync("output.mp3", Buffer.from(audio));
```

### 詳細設定

```javascript
const audio = await client.textToSpeech.convert({
  text: "[happy] Great to meet you!",
  reference_id: "voice-model-id",
  format: "wav",
  chunk_length: 200,
  temperature: 0.7,
  top_p: 0.8,
  prosody: {
    speed: 1.2,
    volume: 5,
  },
});
```

## STT（音声 → テキスト）

```javascript
const result = await client.speechToText.convert({
  file: fs.createReadStream("audio.mp3"),
  language: "ja",
  ignore_timestamps: false,
});

console.log(result.text);
for (const segment of result.segments) {
  console.log(`[${segment.start}s - ${segment.end}s] ${segment.text}`);
}
```

## TypeScript 型

### TTSRequest

```typescript
interface TTSRequest {
  text: string;
  reference_id?: string;
  references?: ReferenceAudio[];
  format?: "mp3" | "wav" | "pcm" | "opus";
  mp3_bitrate?: 64 | 128 | 192;
  chunk_length?: number;      // 100-300
  temperature?: number;       // 0-1.0
  top_p?: number;             // 0-1.0
  latency?: "normal" | "balanced";
  prosody?: {
    speed?: number;           // 0.5-2.0
    volume?: number;          // -20 ~ +20
  };
  normalize_loudness?: boolean;
}
```

### ReferenceAudio

```typescript
interface ReferenceAudio {
  audio: Buffer | ReadStream;
  text: string;
}
```

### ASRResult

```typescript
interface ASRResult {
  text: string;
  duration: number;
  segments: Array<{
    start: number;
    end: number;
    text: string;
    speaker?: string;
  }>;
}
```

## Prosody 設定

```javascript
const audio = await client.textToSpeech.convert({
  text: "Speed and volume adjusted.",
  reference_id: "voice-model-id",
  prosody: {
    speed: 0.8,    // ゆっくり
    volume: 10,    // やや大きめ
  },
});
```

## Voice 操作

### 検索

```javascript
const voices = await client.voices.search({
  page: 1,
  page_size: 10,
});

for (const voice of voices.items) {
  console.log(`${voice._id}: ${voice.name}`);
}
```

### 取得

```javascript
const voice = await client.voices.get("voice-model-id");
console.log(voice.name, voice.description);
```

### 作成（Persistent Clone）

```javascript
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
console.log(`Created voice: ${voice._id}`);
```

### 更新

```javascript
await client.voices.update("voice-model-id", {
  name: "Updated Voice Name",
  description: "Updated description",
});
```

### 削除

```javascript
await client.voices.delete("voice-model-id");
```

## File / ReadStream の使い方

Voice Cloning やSTT でファイルを渡す場合:

```javascript
import fs from "fs";

// ReadStream（推奨 — 大きなファイル向け）
const stream = fs.createReadStream("audio.wav");

// Buffer（小さなファイル向け）
const buffer = fs.readFileSync("audio.wav");

// Instant Clone
const audio = await client.textToSpeech.convert({
  text: "Cloned voice!",
  references: [
    {
      audio: fs.createReadStream("sample.wav"),
      text: "Reference transcript.",
    },
  ],
});
```

## エラーハンドリング

```javascript
try {
  const audio = await client.textToSpeech.convert({
    text: "Hello!",
    reference_id: "voice-model-id",
  });
} catch (error) {
  if (error.status === 401) {
    console.error("認証エラー: APIキーが無効です");
  } else if (error.status === 429) {
    // レート制限 — 指数バックオフでリトライ
    const retryAfter = error.headers?.["retry-after"] || 5;
    console.error(`レート制限。${retryAfter}秒後にリトライ`);
    await new Promise((r) => setTimeout(r, retryAfter * 1000));
    // リトライ...
  } else if (error.status === 422) {
    console.error("バリデーションエラー:", error.message);
  } else {
    console.error("予期しないエラー:", error);
  }
}
```

### リトライ（指数バックオフ）

```javascript
async function withRetry(fn, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (error.status === 429 && attempt < maxRetries - 1) {
        const delay = Math.pow(2, attempt) * 1000;
        await new Promise((r) => setTimeout(r, delay));
        continue;
      }
      throw error;
    }
  }
}

const audio = await withRetry(() =>
  client.textToSpeech.convert({
    text: "Retry example",
    reference_id: "voice-model-id",
  })
);
```

## 完全な例: バッチ TTS 生成

```javascript
import { FishAudioClient } from "fish-audio";
import fs from "fs";

const client = new FishAudioClient();

const scripts = [
  { file: "intro.mp3", text: "[calm] Welcome to our podcast." },
  { file: "topic.mp3", text: "[enthusiastic] Today's topic is AI!" },
  { file: "outro.mp3", text: "[warm] Thanks for listening." },
];

for (const script of scripts) {
  const audio = await client.textToSpeech.convert({
    text: script.text,
    reference_id: "voice-model-id",
    format: "mp3",
    mp3_bitrate: 192,
    prosody: { speed: 1.0, volume: 0 },
  });

  fs.writeFileSync(script.file, Buffer.from(audio));
  console.log(`Generated: ${script.file}`);
}
```
