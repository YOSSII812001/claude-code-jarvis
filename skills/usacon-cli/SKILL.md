---
name: usacon-cli
description: |
  UsaconCLI - コマンドラインインターフェース。企業管理、AI分析実行、チャット、補助金検索、レポートエクスポート、経営戦略、インサイトなどの操作を実行。
  トリガー: "usacon-cli", "UsaconCLI", "CLIコマンド", "usaconコマンド", "@usacon/cli"
---

# UsaconCLI - コマンドラインインターフェース

## 概要

デジタル経営コンサルティングアプリ「ウサコン」のCLIインターフェース。
ターミナルから企業管理、AI分析実行、チャット、補助金検索、レポートエクスポート、経営戦略、インサイトなどの操作を実行できる。
引数なしで起動するとInk/React製のインタラクティブTUIモードが立ち上がる。

**トリガー:** `usacon-cli`, `UsaconCLI`, `CLIコマンド`, `usaconコマンド`, `@usacon/cli`

## プロジェクト情報

| 項目 | 値 |
|------|-----|
| **パッケージ名** | `@usacon/cli` |
| **ローカルパス** | `C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app\packages\usacon-cli` |
| **エントリポイント** | `src/cli.ts` (bin) / `src/index.ts` (library) |
| **Node.js** | >= 20.18.1 |
| **ビルドツール** | tsup (ESM + CJS + DTS) |
| **テストフレームワーク** | Vitest |
| **UIフレームワーク** | Ink v5 + React 18 (TUIモード) |
| **CLIフレームワーク** | Commander.js v13 |
| **npm** | [`@usacon/cli`](https://www.npmjs.com/package/@usacon/cli) v0.1.1（2026-03-23公開） |
| **npm Organization** | `usacon`（Owner: `robbits0802`） |

## パッケージ依存関係

```
@usacon/app-core → @usacon/api-client → @usacon/cli
```

- **app-core**: 型定義、定数（EXIT_CODES, CREDIT_COSTS）、Zodスキーマ
- **api-client**: UsaconHttpClient、SSEパーサー、エラー型
- **usacon-cli**: コマンド実装、TUI、セッション管理

## インストール・セットアップ

### 開発用セットアップ

```bash
cd C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app\packages\usacon-cli
npm install    # 依存関係インストール
npm run build  # tsupでビルド（dist/ に出力）
npm link       # グローバルコマンドとして登録
usacon --help  # 動作確認
```

### 重要な注意点

- **コード変更後は `npm run build && npm link` が必要**（ソース直接実行ではない）
- tsup.config.ts で `noExternal: ['@usacon/api-client', '@usacon/app-core']` — ワークスペースパッケージをバンドルに含む
- ビルド成果物: `dist/cli.js`（bin）、`dist/index.js`（ESM）、`dist/index.cjs`（CJS）

### npmパッケージとしてインストール（利用者向け）

```bash
npm install -g @usacon/cli        # 初回インストール
npm update -g @usacon/cli         # 更新
npm install -g @usacon/cli@latest # 最新版強制インストール
```

## ビルド・テスト・リント

| コマンド | 説明 |
|---------|------|
| `npm run build` | tsupでESM/CJS/DTSビルド |
| `npm run dev` | tsup --watch（開発モード） |
| `npm run test` | Vitest全テスト実行 |
| `npm run test:watch` | Vitest ウォッチモード |
| `npm run type-check` | tsc --noEmit 型チェック |
| `npm run clean` | dist/ 削除 |

## npm公開・バージョン更新フロー

```bash
npm run build              # ビルド確認
npm pack --dry-run         # パッケージ内容確認（28ファイル、190.7KB）
npm version patch          # バージョン更新（patch/minor/major）
npm publish --access public  # 公開（@usacon スコープのため --access public 必須）
```

### 2FA バイパス（Windows Hello/パスキー環境）

npm の 2FA が Windows Hello/パスキーで設定されている場合、CLI から OTP を生成できない。
Granular Access Token の 2FA バイパス機能を使う：

1. npmjs.com → Settings → Security → 2FA レベルを「Require 2FA **or** granular token with bypass」に変更・保存
2. Access Tokens → Granular Access Token → **Bypass 2FA** チェック ON → 生成
3. `npm publish --access public --//registry.npmjs.org/:_authToken=<granular-token>`

**注意:** 通常の Classic Token では 2FA バイパス不可。必ず Granular Token を使用する。

### CLI修正のリリースフロー（パイプラインとの統合）

```
コード修正 → テスト → PR → staging merge → E2E → Issue close
→ staging→main merge → Vercel Production Ready
→ package.json version bump → npm run build → npm publish
→ ユーザーに `npm update -g @usacon/cli` を案内
```

## グローバルオプション

| オプション | 説明 |
|-----------|------|
| `--json` | JSON形式で出力（非TTY環境では自動適用） |
| `--watch` | ジョブ完了まで待機（ポーリング）※コマンド側の実装は限定的 |
| `--follow` | SSEストリームをフォロー ※コマンド側の実装は限定的 |
| `--verbose` | デバッグ出力を有効化 |
| `--no-color` | カラー出力を無効化 |
| `-V, --version` | バージョン表示 |
| `-h, --help` | ヘルプ表示 |

## コマンド一覧

### 認証・セッション

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon login` | - | Email/Passwordで認証（`--force` で既存トークン破棄・再認証） |
| `usacon logout` | - | 認証情報を削除 |
| `usacon status` | - | 認証状態・トークン有効期限・ユーザー情報を表示 |

### 設定管理

| コマンド | 説明 |
|---------|------|
| `usacon settings` | 現在の設定を表示（userId, locale, theme, timezone, max_tokens, selected_company_id） |
| `usacon settings set <key> <value>` | 設定値を更新 |

**有効なキー:** `locale`, `theme`, `timezone`, `max_tokens`, `selected_company_id`

### 企業管理

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon company list` | `c ls` | 企業一覧を表示（ID, 名前, 業界, 規模） |
| `usacon company show <id>` | `c show` | 企業の全フィールド詳細を表示 |
| `usacon company new` | `c new` | 対話形式で企業を新規登録 |
| `usacon company new --url <url>` | - | URLからAI自動抽出で企業登録 |
| `usacon company import <file>` | `c import` | YAML/JSONファイルから企業を登録（Zodバリデーション） |
| `usacon company edit <id>` | `c edit` | 企業情報を編集 |
| `usacon company delete <id>` | `c delete` | 企業を削除（`--yes` で確認スキップ） |
| `usacon company duplicate <id>` | `c duplicate` | 企業を複製（`--name` でカスタム名指定可） |
| `usacon company limit` | `c limit` | 企業登録上限の状態を表示（plan, current, limit, canCreate） |

**company edit オプション:**
- `--name <name>` — 企業名
- `--industry <industry>` — 業界
- `--size <size>` — 規模（small/medium/large）
- `--employees <n>` — 従業員数
- `--revenue <n>` — 売上高

### AI分析

| コマンド | エイリアス | クレジット | タイムアウト |
|---------|----------|----------|------------|
| `usacon analyze transformation <companyId>` | `a` | 2 | 5分 |
| `usacon analyze maturity <companyId>` | `a` | 1 | 5分 |
| `usacon analyze csf <companyId>` | `a` | 1 | 10分 |
| `usacon analyze digital-strategy <companyId>` | `a` | 4 | 15分 |

**分析の前提条件:**
- P1-1（transformation）→ P1-2（maturity）→ CSF → digital-strategy の順序依存あり
- クレジット不足時は402エラー

### チャット

| コマンド | 説明 |
|---------|------|
| `usacon chat "<message>"` | AIアシスタントにメッセージ送信（SSEストリーミング応答、3cr/メッセージ） |
| `usacon chat history` | 過去のスレッド一覧を表示 |
| `usacon chat history --company-id <id>` | 指定企業のスレッド一覧をフィルタ |
| `usacon chat history <threadId>` | 特定スレッドのメッセージ一覧を表示 |
| `usacon chat delete <threadId>` | スレッドを削除（`--yes` で確認スキップ） |

- Markdown応答はmarked-terminalでレンダリング
- `<human_input>` XMLラップでプロンプトインジェクション対策
- `--json` でNDJSON形式のイベントストリーム出力

### クレジット

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon credits` | `cr` | クレジット残高・プラン情報・分析コスト一覧を表示 |

### 補助金

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon subsidy search "<query>"` | `s search` | SSEストリーミングで補助金検索 |
| `usacon subsidy search "<query>" --company-id <id>` | - | 企業に合った補助金をターゲット検索 |
| `usacon subsidy show <id>` | `s show` | 補助金の詳細を表示（名称・概要・金額・期間・地域・業種等） |
| `usacon subsidy favorite list` | `s fav ls` | お気に入り補助金の一覧を表示 |
| `usacon subsidy favorite add <subsidyId>` | `s fav add` | お気に入りに追加 |
| `usacon subsidy favorite remove <id>` | `s fav rm` | お気に入りから解除 |

**favorite add オプション:**
- `--name <name>` — 補助金名（省略時はAPI自動取得）
- `--memo <memo>` — メモ
- `--company-id <companyId>` — 企業と関連付け

### ジョブ管理

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon job list <companyId>` | `j list` | 分析実行履歴を表示 |
| `usacon job status <companyId> <runId>` | `j status` | 特定分析のステータスを確認 |
| `usacon job result <companyId> --type <type>` | `j result` | 最新分析結果を取得（type: transformation/maturity/csf/digital-strategy） |

### レポート

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon report list` | `r ls` | レポート一覧を表示 |
| `usacon report list --company <id>` | - | 企業でフィルタしたレポート一覧 |
| `usacon report export <id>` | `r export` | レポートをエクスポート |
| `usacon report delete <id>` | `r rm` | レポートを削除（`-y` / `--yes` で確認スキップ） |
| `usacon report weekly list` | `r weekly ls` | 週間レポート一覧を表示 |
| `usacon report weekly show <id>` | `r weekly show` | 週間レポート詳細（サマリー・テーマ・Q&A）を表示 |

**report export オプション:**
- `--format <format>` — 出力形式: `pdf`, `md`, `pptx`（デフォルト: md）
- `-o, --output <path>` — 出力ファイルパス

### データエクスポート

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon export csv` | `ex csv` | 分析データをCSVファイルとして出力（BOM付き日本語Excel対応） |
| `usacon export xlsx` | `ex xlsx` | 分析データをExcelファイルとして出力 |

**共通オプション（必須）:**
- `--company <id>` — 企業ID
- `--type <type>` — 分析タイプ（transformation/maturity/csf/digital-strategy）

**任意オプション:**
- `-o, --output <path>` — 出力ファイルパス（省略時はデフォルトファイル名）

### バッチ分析

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon batch analyze` | `b analyze` | JSONLファイルからバッチ分析実行 |

**バッチオプション:**
- `--input <file>` (必須): JSONL入力ファイル（10MBサイズ上限）
- `--concurrency <n>`: 並列度 1-5（デフォルト: 1、現在は逐次実行）
- `--retry-failed`: 前回失敗した項目のみ再試行（`.usacon-batch-state.json` から読み込み）
- `--dry-run`: 実行せずクレジット消費量の見積もりのみ表示

**JSONL入力形式:**
```jsonl
{"companyId": "uuid-here", "analysisType": "transformation"}
{"companyId": "uuid-here", "analysisType": "maturity"}
```

### 経営戦略

| コマンド | エイリアス | 説明 |
|---------|----------|------|
| `usacon strategy list <companyId>` | `st ls` | 戦略一覧を表示（`--limit`, `--offset` でページネーション） |
| `usacon strategy show <companyId>` | `st show` | 最新の戦略詳細を表示（vision, mission, coreValues等） |
| `usacon strategy show <companyId> <strategyId>` | - | 特定の戦略詳細を表示 |
| `usacon strategy generate <companyId>` | `st gen` | AI経営戦略分析を実行・結果表示 |

### インサイト

| コマンド | 説明 |
|---------|------|
| `usacon insights [companyId]` | インサイト一覧を表示（スコア・軸・タグ付き、企業IDでフィルタ可） |
| `usacon insights show <threadId>` | インサイトの詳細を表示 |

### スレッド管理

| コマンド | 説明 |
|---------|------|
| `usacon threads [companyId]` | スレッド一覧を表示（ピン・お気に入り状態付き、企業IDでフィルタ可） |
| `usacon threads pin <threadId>` | ピン状態をトグル |
| `usacon threads favorite <threadId>` | お気に入り状態をトグル（エイリアス: `fav`） |

## エイリアス早見表

| 短縮形 | 正式コマンド |
|--------|------------|
| `c` | `company` |
| `c ls` | `company list` |
| `a` | `analyze` |
| `s` | `subsidy` |
| `s fav` | `subsidy favorite` |
| `cr` | `credits` |
| `r` | `report` |
| `r ls` | `report list` |
| `r rm` | `report delete` |
| `r weekly ls` | `report weekly list` |
| `j` | `job` |
| `b` | `batch` |
| `st` | `strategy` |
| `st ls` | `strategy list` |
| `st gen` | `strategy generate` |
| `ex` | `export` |
| `threads fav` | `threads favorite` |

## インタラクティブTUIモード

### 起動方法

```bash
usacon           # 引数なしで起動（TTY環境のみ）
usacon --verbose # デバッグ出力付きで起動
```

- 非TTY環境（パイプ、CI）ではヘルプテキストにフォールバック
- Ink + React を動的インポート（コマンドモード起動時間 < 500ms を維持）

### TUIコンポーネント構成

```
App.tsx
  +-- Header.tsx          # タイトル + バージョン
  +-- CompanySelector.tsx  # Tab/矢印で企業選択
  +-- MessageArea.tsx      # チャットメッセージ表示
  +-- InputArea.tsx        # テキスト入力 + 送信
  +-- StatusBar.tsx        # ストリーミング状態表示
```

### キーボードショートカット

| キー | アクション |
|------|----------|
| `Enter` | メッセージ送信 |
| `Shift + Enter` | 改行挿入 |
| `Backspace` | 最後の文字を削除 |
| `Tab` | 企業セレクタを開閉 |
| `Up/Down` | 企業セレクタ内で移動 |
| `Ctrl + C` | 終了 |

### 状態管理

- `useReducer` でTUI全体の状態を管理（`src/tui/reducer.ts`）
- SSEストリーミングでリアルタイム応答表示
- `fetchCompanies` / `sendMessage` はprops注入でHTTP/認証レイヤーと疎結合

## 認証・設定

### 認証フロー

1. `usacon login` でEmail/Password入力（対話形式 or 環境変数）
2. Supabase `signInWithPassword` でトークン取得
3. AES-256-GCM暗号化で `~/.usacon/credentials.json` に保存
4. 以降のコマンドでトークンを自動読み込み・リフレッシュ（`ensureFreshToken()`）

### 設定ファイルの優先順位

1. **環境変数**（最優先）
2. **設定ファイル**: `~/.usacon/config.json`
3. **ビルトインデフォルト**: 本番Supabaseプロジェクト

### 環境変数

| 変数名 | 説明 |
|--------|------|
| `USACON_SUPABASE_URL` | Supabase URL |
| `USACON_SUPABASE_ANON_KEY` | Supabase Anon Key |
| `USACON_API_BASE_URL` | APIベースURL |
| `USACON_TOKEN` | アクセストークン直接指定（CI/CD用、暗号化バイパス） |
| `USACON_EMAIL` | ログイン用メール（CI/CD用） |
| `USACON_PASSWORD` | ログイン用パスワード（CI/CD用） |

### ファイル構造

| パス | 説明 | パーミッション |
|------|------|-------------|
| `~/.usacon/` | 設定ディレクトリ | 0700 |
| `~/.usacon/config.json` | 設定ファイル | 0600 |
| `~/.usacon/credentials.json` | 暗号化トークン | 0600 |
| `~/.usacon/.master-key` | AES暗号化マスターキー | 0600 |

## ディレクトリ構成

```
packages/usacon-cli/
  +-- src/
  |   +-- cli.ts                  # binエントリポイント（#!/usr/bin/env node）
  |   +-- index.ts                # ライブラリエントリポイント + run()
  |   +-- commands/
  |   |   +-- index.ts            # 全コマンドのre-export
  |   |   +-- config.ts           # 設定管理（getConfig/saveConfig）
  |   |   +-- login.ts            # usacon login
  |   |   +-- logout.ts           # usacon logout
  |   |   +-- status.ts           # usacon status
  |   |   +-- company.ts          # usacon company (list/show/new/import/edit/delete/duplicate/limit)
  |   |   +-- analyze.ts          # usacon analyze (transformation/maturity/csf/digital-strategy)
  |   |   +-- credits.ts          # usacon credits
  |   |   +-- chat.ts             # usacon chat (message/history/delete, SSEストリーミング)
  |   |   +-- subsidy.ts          # usacon subsidy (search/show/favorite, SSEストリーミング)
  |   |   +-- job.ts              # usacon job (list/status/result)
  |   |   +-- report.ts           # usacon report (list/export/delete/weekly)
  |   |   +-- batch.ts            # usacon batch analyze (JSONL入力, dry-run)
  |   |   +-- export.ts           # usacon export (csv/xlsx)
  |   |   +-- settings.ts         # usacon settings (display/set)
  |   |   +-- strategy.ts         # usacon strategy (list/show/generate)
  |   |   +-- insights.ts         # usacon insights (list/show)
  |   |   +-- threads.ts          # usacon threads (list/pin/favorite)
  |   +-- session/
  |   |   +-- index.ts            # re-export
  |   |   +-- auth.ts             # Supabase認証（login/logout）
  |   |   +-- credentials.ts      # AES-256-GCM暗号化トークン管理
  |   |   +-- refresh.ts          # JWTトークンリフレッシュ
  |   +-- tui/
  |   |   +-- index.ts            # startTui() — 動的インポートでInk起動
  |   |   +-- App.tsx             # メインAppコンポーネント
  |   |   +-- Header.tsx          # ヘッダー表示
  |   |   +-- CompanySelector.tsx # 企業選択UI
  |   |   +-- MessageArea.tsx     # メッセージ表示
  |   |   +-- InputArea.tsx       # テキスト入力
  |   |   +-- StatusBar.tsx       # ステータスバー
  |   |   +-- reducer.ts          # useReducer アクション/リデューサー
  |   |   +-- types.ts            # TUI型定義
  |   +-- utils/
  |   |   +-- index.ts            # re-export
  |   |   +-- client.ts           # createAuthenticatedClient() + handleApiError()
  |   |   +-- output.ts           # カラー出力・JSON出力ユーティリティ
  |   |   +-- paths.ts            # ~/.usacon/ パス管理
  |   |   +-- activeJobs.ts       # SIGINT/SIGTERMグレースフルシャットダウン
  |   +-- __tests__/              # テストファイル（Vitest）
  +-- dist/                       # ビルド成果物
  +-- package.json
  +-- tsup.config.ts
  +-- tsconfig.json
  +-- README.md
```

## 開発時の注意事項

### API応答のsnake_case/camelCase対応

APIレスポンスは `snake_case`（Supabaseカラム名そのまま）だが、app-coreの型定義は `camelCase`。
各コマンドでは `mapXxx()` 関数で明示的に変換している。

```typescript
// credits.ts の例
function mapCreditBalance(raw: Record<string, unknown>): CreditBalance {
  return {
    creditsRemaining: (raw.credits_remaining ?? raw.creditsRemaining ?? 0) as number,
    // ...
  };
}
```

### SSEストリーミング

chat.ts と subsidy.ts では、undici Pool を直接使用してSSEストリームを取得。
UsaconHttpClient はRaw ReadableStreamを公開しないため、直接undiciを使用する設計。

### 非TTY環境での動作

Claude Code の bash は非TTY → `--json` が自動適用される。
テキスト出力（テーブル形式、Markdown）のテストはユーザーが手動で実施する必要がある。

### E2Eテスト基準

CLIパッケージの修正では `npm run build && usacon <command>` でのコマンド実行テストが本E2E。
ビルド成功だけでは不十分（E2E品質基準 Issue #1305-#1307教訓）。

### ファイルサイズ制限

company import および batch analyze の入力ファイルは10MB上限。

### CJSビルドでの `import.meta` 警告

tsupのCJS出力で `import.meta` に関する警告が出るが、機能影響なし（後日対応予定）。

### 日付表示

表示ヘルパーでは `Asia/Tokyo` タイムゾーンで日付をフォーマット。

## テスト計画

包括的テスト計画（全140項目）は GitHub Issue #1399 に記載。
15セクション・6フェーズに分割され、Claude実施可能（約95件）とユーザー実施必須（約45件）に分類。

## CLI実装の完了条件（必須）

CLI実装はコード修正だけで完了扱いにしない。以下のすべてを確認すること：

| # | 確認項目 | コマンド | 判定基準 |
|---|---------|---------|---------|
| 1 | グローバルビルド | `npm run build` | エラーなし |
| 2 | パッケージリンク | `npm link` | 成功 |
| 3 | 実機起動確認 | `usacon --version` | バージョン表示 |
| 4 | 対象コマンド実行 | `usacon <modified-command>` | 期待通りの出力 |
| 5 | ヘルプ表示 | `usacon <command> --help` | オプション一覧表示 |

**アンチパターン**: コード修正 → `npm run build` 成功 → 完了とする（実機起動確認なし）
→ ビルド成功 ≠ 使える。必ずコマンドとして実行して動作確認すること。

## セキュリティ改善ロードマップ

| 項目 | 現状 | 優先度 |
|------|------|--------|
| sourcemap対策 | 含まれていない（良好） | - |
| error出力のsanitize | rawスタックトレースのまま | 中 |
| failing test | 1件残存（gap-analysis Commander v13互換） | 高 |
| credential保護 | AES-256-GCMでローカル暗号化 | 中 |

## 関連スキル

- `usacon` (`~/.claude/skills/usacon/SKILL.md`) — Webアプリ全体のガイド（本スキルはCLIパッケージに特化）
- `issue-flow` — GitHub Issue実装の自動ワークフロー
- `issue-autopilot-batch` — バッチIssue実装

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-03-12 | 初版作成 — ソースコード全量調査に基づく |
| 2026-03-13 | 全面改訂 — Issue #1399テスト計画に基づき全コマンド網羅 |
| 2026-03-17 | CLI実装の完了条件セクション追加 — ビルド成功だけでなく実機起動確認まで必須化 |
| 2026-03-18 | YAML frontmatter追加、トラブルシューティング・チェックリスト追加（skill-improve audit対応） |
| 2026-03-23 | npm公開ワークフロー・セキュリティロードマップ追加 — npm初回公開（v0.1.1）に伴う運用知識のスキル化 |

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| `npm publish` で EOTP エラー | 2FA が Windows Hello の場合、Granular Token + bypass 2FA を使用（上記セクション参照） |
| `usacon` コマンドが見つからない | `npm link` or `npx tsx src/index.ts` で直接実行 |
| app-core ビルドエラー（DTS解決） | worktree後は `cd packages/app-core && npm run build` を先に実行 |
| Commander v13互換エラー | gap-analysis の既知問題。`--help` フラグテストをスキップ |
| TUI起動後すぐ終了する | stdin が TTY でない環境（CI等）では `--no-interactive` を付与 |

## CLI品質チェックリスト

- [ ] `npm run build` が全パッケージで成功するか
- [ ] `usacon --version` でバージョンが表示されるか
- [ ] 新規コマンドに `--help` テキストが設定されているか
- [ ] テスト（`npm test`）が全件パスするか
- [ ] TUIモードで新規メニュー項目が表示されるか
