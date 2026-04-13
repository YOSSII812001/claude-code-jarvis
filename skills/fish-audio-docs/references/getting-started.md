# Getting Started — Fish Audio

## Fish Audio とは

Fish Audio は次世代の音声AIプラットフォーム。主要機能:

- **TTS (Text-to-Speech)**: テキストから高品質音声を生成（80+言語、100ms遅延）
- **STT (Speech-to-Text)**: 音声からテキストへの変換（タイムスタンプ付き）
- **Voice Cloning**: 音声サンプルから声を複製（10秒から可能）
- **Streaming**: WebSocket経由のリアルタイム音声生成

## アカウント作成

1. [fish.audio/auth/signup](https://fish.audio/auth/signup) にアクセス
2. メールアドレスまたはGitHub/Google アカウントで登録
3. メール認証を完了

## APIキー取得

1. [fish.audio](https://fish.audio) にログイン
2. ダッシュボード → **API Keys** セクション
3. **Create API Key** をクリック
4. キー名を入力して生成
5. 表示されたキーをコピー（再表示不可）

## 環境変数設定

```bash
# .env または シェルプロファイル
export FISH_API_KEY="your-api-key-here"
```

**注意**: APIキーをバージョン管理に含めないこと。`.env` ファイルは `.gitignore` に追加する。

## 最初の TTS リクエスト

### cURL

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_API_KEY" \
  -H "Content-Type: application/json" \
  -o output.mp3 \
  -d '{
    "text": "Hello, welcome to Fish Audio!",
    "reference_id": "e58b0d7efca34aa8b7fed4a0b8074cec"
  }'
```

### Python

```python
from fish_audio_sdk import FishAudio

client = FishAudio(api_key="your-api-key")

audio = client.tts.convert(
    text="Hello, welcome to Fish Audio!",
    reference_id="e58b0d7efca34aa8b7fed4a0b8074cec",
)
with open("output.mp3", "wb") as f:
    f.write(audio)
```

### JavaScript

```javascript
import { FishAudioClient } from "fish-audio";

const client = new FishAudioClient({ apiKey: "your-api-key" });

const audio = await client.textToSpeech.convert({
  text: "Hello, welcome to Fish Audio!",
  reference_id: "e58b0d7efca34aa8b7fed4a0b8074cec",
});
// audio は ArrayBuffer
const fs = await import("fs");
fs.writeFileSync("output.mp3", Buffer.from(audio));
```

## モデル選択ガイド

| モデル | 言語数 | レイテンシ | 特徴 |
|---|---|---|---|
| **S2-Pro**（推奨） | 80+ | ~100ms | 最新・高品質、感情制御、Multi-speaker対応 |
| S1（前世代） | 13 | ~200ms | 安定性重視、旧プロジェクト互換用 |

**推奨**: 新規プロジェクトでは常に **S2-Pro** を使用する。

## プリセットボイス

すぐに使えるプリセットボイス（`reference_id` で指定）:

| ボイス名 | ID | 特徴 |
|---|---|---|
| E-girl | `e58b0d7efca34aa8b7fed4a0b8074cec` | 明るいアニメ風女性 |
| Energetic Male | `1c3ea70eb66d4c1c9e37dc1da4091e15` | 活発な男性 |
| Sarah | `d8639b471f7c41618ba1768ddb2a0e04` | 落ち着いた女性 |
| Adrian | `52a5f3ccdebc4a98b1e7e8b40e2a3e6f` | ニュートラル男性 |
| Selene | `a1b2c3d4e5f647389012345678901234` | プロフェッショナル女性 |
| Ethan | `f1e2d3c4b5a6478990123456789abcde` | カジュアル男性 |

## 次のステップ

- TTS の詳細 → `tts-guide.md`
- 声の複製 → `voice-cloning.md`
- SDK の詳細 → `sdk-python.md` / `sdk-javascript.md`
