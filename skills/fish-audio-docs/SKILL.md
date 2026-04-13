---
name: fish-audio-docs
description: |
  Fish Audio 開発者ガイド。TTS/STT/Voice Cloning/Streaming の使い方、
  SDK（Python/JavaScript）、感情制御、セルフホスティング、ベストプラクティス。
  このスキルは fish-audio メインスキルから内部参照される。直接トリガーされない。
---

# Fish Audio 開発者ドキュメント

## 概要

Fish Audio は高品質な音声AI プラットフォーム。TTS（テキスト読み上げ）、STT（音声認識）、
Voice Cloning（声の複製）をAPI経由で提供する。S2-Proモデルは80+言語対応、100ms低遅延。

## 動的読み込みルール

`references/` 配下のファイルは **必要時にのみ Read で読み込む**こと。
全ファイルを一括読み込みしない。ユーザーの質問に関連するファイルだけを参照する。

**例:**
- TTS の質問 → `references/tts-guide.md` を Read
- Python SDK → `references/sdk-python.md` を Read
- 感情制御 → `references/tts-guide.md`（感情制御セクション含む）を Read

## リファレンス一覧

| ファイル | 内容 |
|---|---|
| `references/getting-started.md` | アカウント作成、APIキー取得、最初のリクエスト、モデル選択 |
| `references/tts-guide.md` | TTS パラメータ、Prosody制御、Multi-speaker、**感情制御**、コード例 |
| `references/voice-cloning.md` | Instant Clone / Persistent Clone、録音品質基準、倫理要件 |
| `references/stt-guide.md` | STT 対応形式、タイムスタンプ、スピーカー検出、精度テーブル |
| `references/streaming-guide.md` | WebSocket Live TTS、MessagePack、レイテンシモード、LLM統合 |
| `references/sdk-python.md` | Python SDK（同期/非同期）、TTSConfig、ストリーミング、エラー処理 |
| `references/sdk-javascript.md` | JavaScript SDK、TypeScript型、Voice操作、エラーハンドリング |
| `references/integrations.md` | Pipecat、LiveKit、n8n、Next.js、Express.js 連携 |
| `references/self-hosting.md` | fish-speech OSS、GPU要件、Conda/Docker セットアップ |
| `references/best-practices.md` | レート制限、コスト最適化、キャッシュ戦略、セキュリティ |

## 関連スキル

- **fish-audio** — メインスキル（APIリファレンス、エンドポイント詳細）
- **fish-audio-api** — API仕様スキル（OpenAPI準拠のエンドポイント定義）
