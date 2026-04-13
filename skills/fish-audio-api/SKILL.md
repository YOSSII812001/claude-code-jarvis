---
name: fish-audio-api
description: |
  Fish Audio API Reference。TTS/STT/WebSocket/Model/Wallet 全エンドポイント仕様、
  認証、エラーコード、レート制限、料金体系。
  このスキルは fish-audio メインスキルから内部参照される。直接トリガーされない。
---

# Fish Audio API Reference

## 概要

| 項目 | 値 |
|------|-----|
| ベースURL | `https://api.fish.audio` |
| 認証 | Bearer Token（`Authorization: Bearer {FISH_API_KEY}`） |
| レスポンス形式 | JSON（TTS はストリーミングバイナリ） |
| WebSocket | MessagePack 形式 |
| SDK | Python (`fish-audio-sdk`)、JavaScript (`fish-audio`) |

## エンドポイント一覧

| メソッド | パス | 説明 |
|---------|------|------|
| POST | /v1/tts | Text-to-Speech（音声合成） |
| POST | /v1/asr | Speech-to-Text（音声認識） |
| WSS | /v1/tts/live | WebSocket TTS Live Streaming |
| POST | /model | 音声モデル作成 |
| GET | /model/{id} | モデル詳細取得 |
| GET | /model | モデル一覧取得 |
| PATCH | /model/{id} | モデル更新 |
| DELETE | /model/{id} | モデル削除 |
| GET | /wallet/{user_id}/api-credit | APIクレジット残高 |
| GET | /wallet/{user_id}/package | パッケージ情報 |

## 動的読み込みルール

`references/` 配下のファイルは **必要時にのみ Read で読み込む**こと。
SKILL.md だけで概要を把握し、詳細パラメータやコード例が必要な場合にのみ該当ファイルを参照する。

## リファレンス一覧

| ファイル | 内容 |
|---------|------|
| [authentication.md](references/authentication.md) | 認証方式、APIキー取得、SDK初期化 |
| [tts-endpoint.md](references/tts-endpoint.md) | TTS エンドポイント全パラメータ、Multi-speaker、Instant Clone |
| [stt-endpoint.md](references/stt-endpoint.md) | STT エンドポイント、対応形式、セグメント出力 |
| [websocket-live.md](references/websocket-live.md) | WebSocket Live TTS、MessagePack プロトコル |
| [model-endpoints.md](references/model-endpoints.md) | モデル CRUD 全エンドポイント |
| [billing-and-limits.md](references/billing-and-limits.md) | 料金体系、同時実行ティア、Wallet API |
| [error-codes.md](references/error-codes.md) | HTTP ステータス、422詳細、リトライ戦略 |

## 関連スキル

- **fish-audio** — Fish Audio 統合スキル（メイン）。このスキルの親スキル
- **fish-audio-docs** — ドキュメント・ガイド・ベストプラクティス集
