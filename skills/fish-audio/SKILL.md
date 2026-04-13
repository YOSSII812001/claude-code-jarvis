---
name: fish-audio
description: |
  Fish Audio メインスキル。高品質AI音声合成(TTS)・音声認識(STT)・Voice Cloning プラットフォーム。
  用途に応じて fish-audio-docs（開発者ガイド）/ fish-audio-api（API仕様）を動的に選択。
  S2-Pro推奨（80+言語、100ms遅延）。Python/JavaScript SDK対応。
  トリガー: "fish audio", "fish-audio", "音声合成", "TTS", "音声生成",
  "音声認識", "STT", "voice cloning", "音声クローン", "フィッシュオーディオ",
  "FishAudio", "tts api", "音声API"
---

# Fish Audio — AI音声プラットフォーム

TTS / STT / Voice Cloning / リアルタイムストリーミング対応。
- **API**: `https://api.fish.audio` — 認証: `Authorization: Bearer $FISH_API_KEY`
- **ドキュメント**: https://docs.fish.audio
- **SDK**: Python(`fish-audio-sdk`) / JavaScript(`fish-audio`)

## クイックリファレンス

| モデル | 言語 | 遅延 | 感情制御 | Multi-speaker | 推奨 |
|--------|------|------|----------|---------------|------|
| S2-Pro | 80+ | ~100ms | `[bracket]` 自然言語 | Yes | **推奨** |
| S1 | 13 | 標準 | `(emotion)` 括弧 | No | 前世代 |

| API | 料金 |
|-----|------|
| TTS | $15 / 百万UTF-8バイト |
| STT | $0.36 / 秒 |

**同時実行**: 5 (Starter) → 15 (≥$100) → 50 (≥$1,000)

## ルーティング

ユーザーの質問を以下6系統で分類し、該当ファイルを Read して回答する。
基点パス: `C:\Users\zooyo\.claude\skills\`

### 系統1: 概要・一般
> 「Fish Audioとは」「料金」「モデル比較」 → **このファイルで回答**。詳細が必要なら `fish-audio-api/references/billing-and-limits.md` を Read。

### 系統2: 使い方・チュートリアル
> 「使い方」「SDK」「入門」「セットアップ」 → `fish-audio-docs/references/` を Read:
> - 初めて → `getting-started.md` | TTS → `tts-guide.md` | Voice Clone → `voice-cloning.md`
> - STT → `stt-guide.md` | Python → `sdk-python.md` | JS → `sdk-javascript.md`
> - 統合 → `integrations.md` | セルフホスト → `self-hosting.md` | 最適化 → `best-practices.md`

### 系統3: API仕様
> 「エンドポイント」「パラメータ」「リクエスト」 → `fish-audio-api/references/` を Read:
> - TTS → `tts-endpoint.md` | STT → `stt-endpoint.md` | モデル → `model-endpoints.md`
> - 認証 → `authentication.md` | エラー → `error-codes.md`

### 系統4: リアルタイム・ストリーミング
> 「WebSocket」「リアルタイム」「低遅延」 → 両方 Read:
> 1. `fish-audio-api/references/websocket-live.md`（仕様）
> 2. `fish-audio-docs/references/streaming-guide.md`（使い方）

### 系統5: Voice Cloning
> 「音声クローン」「カスタムボイス」「モデル作成」 → 両方 Read:
> 1. `fish-audio-docs/references/voice-cloning.md`（使い方・品質基準）
> 2. `fish-audio-api/references/model-endpoints.md`（API仕様）

### 系統6: トラブルシューティング・課金
> 「エラー」「429」「402」「クレジット」 → 該当ファイルを Read:
> - エラー → `fish-audio-api/references/error-codes.md`
> - 課金 → `fish-audio-api/references/billing-and-limits.md`
> - 品質問題 → `fish-audio-docs/references/best-practices.md`

### 実装系（「コードを書いて」「実装して」）
系統3（API仕様）→ 系統2（該当ガイド+SDK）の順で Read し、統合して実装。

## 関連スキル（内部参照用）
- `fish-audio-docs` — 開発者ガイド (`~/.claude/skills/fish-audio-docs/`)
- `fish-audio-api` — API Reference (`~/.claude/skills/fish-audio-api/`)
