---
name: usacon-discord
description: |
  UsaconプロジェクトのDiscordサーバー運用スキル。チャンネルへのコンテンツ投稿、
  コマンド一覧・機能紹介・リリースノート等の情報発信、チャンネルアクセス管理を支援。
  Discordプラグイン（reply/fetch_messages/edit_message/react）を使用。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(ls *)
  - Bash(mkdir *)
  - Glob
  - Grep
  - Agent
---

# Usacon Discord スキル

Usacon（デジタル経営コンサルティングアプリ）のDiscordサーバー運用を支援するスキル。

トリガー: "usacon-discord", "discord投稿", "discordに書いて", "チャンネルに投稿",
"ウサコンdiscord", "discord更新", "リリースノート投稿"

## Discordサーバー情報

- **サーバーID**: `1488797174832824440`
- **アクセス設定**: `~/.claude/channels/discord/access.json`

### チャンネル一覧

| チャンネル名 | チャンネルID | 用途 |
|-------------|-------------|------|
| ウサコンcli | `1488798437548752926` | UsaconCLIのコマンド一覧・使い方・技術情報 |
| ウサコンでできること | `1488798001651519608` | Usaconの機能紹介・ユースケース・活用事例 |
| ウサコンチャット初心者 | `1488828350880288918` | チャット機能の基本的な使い方ガイド |
| ウサコンチャット上級者 | `1488828422619926629` | アクション機能・複数企業分析・ファイル活用等の上級テクニック |
| 補助金検索 | `1488834808217079928` | 補助金検索機能の使い方・申請書類作成ガイド |
| 自己紹介 | `1488797175939989729` | ウサコンの自己紹介 |
| 雑談 | `1488846256095887450` | 自由な雑談チャンネル |

> チャンネル追加時はこのテーブルと `access.json` の `groups` を両方更新すること。

## 投稿ガイドライン

### 使用ツール

- **投稿**: `mcp__plugin_discord_discord__reply` （chat_id にチャンネルIDを指定）
- **履歴取得**: `mcp__plugin_discord_discord__fetch_messages`
- **編集**: `mcp__plugin_discord_discord__edit_message`
- **リアクション**: `mcp__plugin_discord_discord__react`
- **添付ファイル**: reply の `files` パラメータで絶対パスを指定

### フォーマット規約

1. **見出し**: `#` で大見出し、`##` でセクション分け
2. **コマンド**: バッククォート `` ` `` でインライン、コードブロックで複数行
3. **テーブル**: Markdownテーブルで構造化（Discordでは表示されないが可読性は維持）
4. **文字数制限**: Discordは1メッセージ2000文字制限。超える場合は自動分割される
5. **言語**: 日本語で記述

### 投稿カテゴリ別テンプレート

#### コマンド一覧（ウサコンcli チャンネル向け）
- CLIコマンドの全一覧
- インストール手順
- 各コマンドの詳細な使い方
- ソース: `packages/usacon-cli/src/commands/` を参照

#### 機能紹介（ウサコンでできること チャンネル向け）
- Usaconの主要機能一覧
- ユースケース・活用事例
- 新機能のお知らせ

#### リリースノート（いずれかのチャンネル）
- バージョン番号とリリース日
- 新機能・改善・バグ修正
- ソース: `CHANGELOG.md` を参照

## 関連スキル

- **usacon**: Usacon本体の開発・運用ガイド（アーキテクチャ、デプロイフロー等）
- **usacon-cli**: UsaconCLIの開発ガイド（コマンド実装、テスト等）
- **discord:access**: Discordチャンネルのアクセス管理（ペアリング、許可リスト）
- **discord:configure**: Discordボットの初期設定
- **discord-promotion**: Discordサーバーの宣伝・集客戦略（DISBOARD/ディス速/DCafe等の掲示板bot、宣伝サーバー、SNS活用）

## ワークフロー

### 1. チャンネルへの投稿

```
1. ユーザーの依頼内容を確認
2. 必要に応じてUsacon関連ソース（CLI commands/, CHANGELOG.md等）を調査
3. 投稿内容を作成
4. mcp__plugin_discord_discord__reply で chat_id=<チャンネルID> に投稿
5. 投稿結果を報告
```

### 2. 新チャンネルの追加

```
1. ユーザーからチャンネルIDを取得（Discord URL: /channels/<serverId>/<channelId>）
2. access.json の groups にチャンネルを追加
3. この SKILL.md のチャンネル一覧テーブルを更新
```

### 3. 既存投稿の更新

```
1. fetch_messages で対象チャンネルの履歴を取得
2. 更新対象のメッセージIDを特定
3. edit_message で内容を更新
```

## 現在の運用形態

- **Claude Code セッション依存**: Discord MCPプラグイン経由で投稿・応答
- Claude Code起動中のみメンション応答可能。常時稼働ではない
- `settings.local.json` に全Discord MCPツールをallow登録済み（許可ダイアログ不要）

## 常時稼働Bot化の設計メモ（未実装）

Vercel Serverless は常駐プロセスを持てないため、Discord Gateway（WebSocket）を直接ホストできない。
常時応答するBotにするには以下の2コンポーネント構成が必要。

### アーキテクチャ

```
Discord ← WebSocket → Gateway Bot (常駐) → HTTP → Usacon API (Vercel)
                        (Railway等)              /api/discord/chat
```

### Usacon API側（Vercel）
- 新規ルート `/api/discord/chat` を `api/_lib/routes/` に追加
- 既存の `claudeService.js` + プロンプト + 企業コンテキストをそのまま活用
- Bot専用APIキーで認証（`x-discord-bot-key` ヘッダー等）
- SSEストリーミングではなく通常JSONレスポンス（Discord向け）
- 参考: Stripe Webhookパターン（`/api/payment/webhook`）が既に存在

### Gateway Bot（常駐プロセス）
- **discord.js** で50〜100行の軽量Bot
- メンション検知 → Usacon API呼び出し → Discord返信
- ホスト先候補: Railway($5/月)、Render(無料・スリープあり)、Fly.io(無料枠あり)
- リポジトリ内配置案: `packages/discord-bot/`

### 実装時の主要ファイル
- チャットAPI: `api/_lib/routes/assistant.js` (POST /chat)
- Claude呼び出し: `api/_lib/services/claudeService.js`
- 認証ミドルウェア: `api/_lib/middleware/requireAssistantAuth.js`
- 企業コンテキスト変換: `assistant.js` 内の `toClaudeCompanyData()`
- プロンプト定義: `api/_lib/prompts/index.js`
- Express マウント: `api/server.js` (#195-226行目)

### 認証設計の注意点
- 現在のチャットAPIは `x-user-id` ヘッダー + Supabase Auth
- Discord Bot用には別の認証パス（APIキー方式）が必要
- Bot経由の場合、Discordユーザー↔Usaconユーザーの紐付けが課題
  - 案1: Discord userIdでUsaconアカウントを自動検索
  - 案2: Bot専用の汎用アカウントで応答（企業コンテキストなし）
  - 案3: 初回にUsaconアカウントとDiscord IDを連携登録

## Usaconプロジェクト参照先

- **プロジェクトパス**: `C:/Users/zooyo/Documents/GitHub/DX/digital-management-consulting-app/`
- **CLIコマンド定義**: `packages/usacon-cli/src/commands/`
- **CHANGELOG**: `CHANGELOG.md`（ルート）
- **Usaconスキル詳細**: `~/.claude/skills/usacon/SKILL.md`
- **UsaconCLIスキル詳細**: `~/.claude/skills/usacon-cli/SKILL.md`
