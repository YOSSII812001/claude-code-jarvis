---
name: qwen-coder
description: |
  Qwen3-Coder-Next（80B MoE）をClaude Codeで使用するためのガイド。
  claude-code-router（ccr）経由でOpenRouterに接続。
  起動方法・切り替え・同時使用・設定の確認に使用。
  トリガー: "qwen", "Qwen", "qwen-coder", "Qwen起動", "Qwenの使い方",
  "Qwenに切り替え", "Qwen3", "qwen3-coder-next"
  使用場面: (1) Qwen起動方法を忘れた, (2) ClaudeとQwenの切り替え方法確認,
  (3) 同時使用の確認, (4) 設定・APIキー確認
---

# Qwen3-Coder-Next スキル

## 概要

Qwen3-Coder-Next（Alibaba製、80B MoE）を **claude-code-router（ccr）** 経由でOpenRouterに接続して使用する。
ccr がAnthropicのベータヘッダー（context-management等）を自動変換するため、OpenRouter直結で発生するエラーを回避できる。

通常の `claude` コマンドはAnthropicに直接接続。Qwenを使う場合のみ `ccr code` で起動する。

> **重要**: Claude Code が OAuth（`claude auth login`）でログイン済みの場合、OAuth認証が `ANTHROPIC_API_KEY` より優先される。
> `--bare` フラグを付けて OAuth を無効化しないと ccr のプロキシがバイパスされる。

## モデル情報

| 項目 | 値 |
|------|-----|
| モデルID | `qwen/qwen3-coder-next` |
| パラメータ | 80B（活性化: 3B、MoE方式） |
| コンテキスト長 | 256K tokens |
| 料金 | 入力 $0.12/1M, 出力 $0.75/1M |
| ベンチマーク | SWE-Bench Verified: 70.6% |
| 特徴 | コーディングエージェント特化、Non-thinkingモード |

---

## 起動方法

### ユーザーが「ccr起動して」「Qwen起動して」と言ったら

Claude が新しい PowerShell ウィンドウを開いて ccr を自動起動する（新規セッション）:

```bash
powershell.exe -Command "Start-Process powershell -ArgumentList '-NoExit', '-Command', 'C:\Users\zooyo\.claude\scripts\qwen-multi.cmd'"
```

### ユーザーが「Qwen再開して」「前のセッション続けて」と言ったら

直前のQwenセッションを再開する:

```bash
powershell.exe -Command "Start-Process powershell -ArgumentList '-NoExit', '-Command', 'C:\Users\zooyo\.claude\scripts\qwen-multi.cmd --continue'"
```

### ユーザーが「Qwenセッション選んで」と言ったら

最近のセッション一覧から選択して再開する:

```bash
powershell.exe -Command "Start-Process powershell -ArgumentList '-NoExit', '-Command', 'C:\Users\zooyo\.claude\scripts\qwen-multi.cmd --resume'"
```

### 起動コマンド早見表

| ユーザーの指示 | 引数 |
|---|---|
| 「Qwen起動」「ccr起動」 | （なし） → 新規セッション |
| 「Qwen再開」「続きから」「前のセッション」 | `--continue` → 直前のセッション再開 |
| 「セッション選んで」「履歴から」 | `--resume` → 一覧から選択 |

### `--dangerously-skip-permissions` について

Qwen セッションは `--dangerously-skip-permissions` で起動する。全ツール呼び出しが確認なしで自動実行さ��る。

### `ANTHROPIC_AUTH_TOKEN=dummy` で無効化されるもの
| 機能 | 代替手段 |
|------|---------|
| CLAUDE.md 自動読み込み | `--add-dir` で指定済み |
| MCP プラグイン | `--mcp-config mcp-bare.json` で指定済み |
| フック（JARVIS/ずんだもん等） | 実行されない |
| auto-memory | 無効 |
| スキル | `/skill-name` は引き続き使用可能 |

---

## 同時使用（Claude + Qwen 2ターミナル並行）

ターミナルを複数開いて同時に使用できる。

```
ターミナルA: claude                  → Anthropic API（OAuth）→ Claude Opus 4.6
ターミナルB: qwen-multi.cmd          → ccr (localhost:3456) → OpenRouter → Qwen
```

`ANTHROPIC_AUTH_TOKEN=dummy` + `--dangerously-skip-permissions` により、OAuth無効化＋全ツール自動実行。

**注意**: 同じプロジェクトの同じファイルを両セッションで同時編集すると競合する。

---

## マルチエージェント構成（司令塔 + ワーカー）

Qwen3.6-plus を司令塔（オーケストレーター）、Qwen3-Coder-Next を複数ワーカーとして使う。

### 起動

「ccr起動して」で Claude が新規ウィンドウで自動起動。または手動:
```
C:\Users\zooyo\.claude\scripts\qwen-multi.cmd
```

### 仕組み

```
メインエージェント（model: sonnet）→ ccr: default → qwen/qwen3.6-plus（司令塔）
サブエージェント（model: haiku） → ccr: background → qwen/qwen3-coder-next（ワーカー）
```

- `CLAUDE_CODE_SUBAGENT_MODEL=haiku` で全サブエージェントが `haiku` として送信
- ccr の `routing/engine.js` が `model.includes('haiku')` → `background` カテゴリに分類
- ccr コードの変更は不要

### MCP（Playwright / context7）

`--mcp-config` で明示指定:
- 設定ファイル: `~/.claude/mcp-bare.json`
- Playwright MCP と context7 MCP を含む

### Agent ツール（サブエージェント）✅ 動作確認済み

`ANTHROPIC_AUTH_TOKEN=dummy` 方式（`--bare` 不要）により **Agent ツールが完全に動作**:
- サブエージェントは環境変数を継承 → ccr 経由で Qwen が応答
- `CLAUDE_CODE_SUBAGENT_MODEL=haiku` → ccr が `background` → `qwen3-coder-next` にルーティング
- TaskCreate, Skill, PlanMode, WebFetch 等の deferred ツールも全て利用可能

### 制約

- **WebSearch は使用不可**: Anthropic サーバーサイドツールのため ccr 経由では動作しない。Web 情報取得は WebFetch で URL 直接指定すること
- フック（JARVIS/ずんだもん等）は OAuth セッションと別環境のため未適用
- ccr cli.js のパッチが2箇所必要（npm update で上書き注意）:
  - `cli.js:48536` validator 緩和
  - `cli.js:55332-55416` 累積テキストチャンク差分化ガード
- 2重出力: 初回応答は修正済み。ツール結果後の応答で一部残存（次セッションで対応）

---

## アーキテクチャ

```
claude コマンド → Anthropic API（直接）              → Claude Opus 4.6
ccr code       → ccr (localhost:3456) → OpenRouter  → Qwen3-Coder-Next
                 ↑ ベータヘッダー変換
                 ↑ Anthropic Messages API → OpenAI Chat Completions 変換
```

### OpenRouter直結との違い

| 問題 | OpenRouter直結 | ccr 経由 |
|------|:-----------:|:--------:|
| context-management ヘッダー | 400エラー | 自動変換 |
| API形式変換 | 手動対応必要 | 自動 |
| ログ・監視 | なし | ccr ui で確認可 |

---

## 管理コマンド

| コマンド | 説明 |
|---------|------|
| `ccr start` | サーバー起動 |
| `ccr stop` | サーバー停止 |
| `ccr restart` | 再起動（設定変更後） |
| `ccr status` | 状態確認 |
| `ccr code` | ccr 経由で Claude Code 起動 |
| `ccr ui` | Web UI（リクエスト監視） |
| `ccr model` | 対話式モデル選択・設定 |

---

## 設定ファイルの場所

| ファイル | 場所 |
|---------|------|
| ccr 設定 | `~/.claude-code-router/config-router.json` |
| ccr ログ | `~/.claude-code-router/logs/` |
| ccr PIDファイル | `~/.claude-code-router/.ccr.pid` |
| OpenRouter APIキー | `C:\Users\zooyo\Documents\Obsidian Vault\OpenRouter\API key.md` |
| Claude Code 設定 | `~/.claude/settings.json` |

---

## モデル追加方法

`~/.claude-code-router/config.json` の `models` 配列にモデルIDを追加し、`ccr restart` で反映:

```json
{
  "Providers": [
    {
      "name": "openrouter",
      "models": [
        "qwen/qwen3-coder-next",
        "google/gemini-2.5-pro-preview"
      ]
    }
  ]
}
```

Router のルーティングルールも合わせて更新すること。

---

## トラブルシューティング

### ccr code が Anthropic API に接続してしまう（OAuth競合）

**症状**: `ccr code` で起動したのに Qwen ではなく Claude が応答する。

**原因**: Claude Code の OAuth 認証が `ANTHROPIC_API_KEY` 環境変数より優先される。

**解決**: `--bare` フラグで OAuth を無効化する:
```powershell
ccr code -- --bare
```

**確認**: `claude auth status` で `loggedIn: true` なら `--bare` が必要。

### ccr code でエラーが出る

```powershell
# サーバー状態確認
ccr status

# ログ確認（最新）
Get-Content ~/.claude-code-router/logs/*.log -Tail 50

# 再起動
ccr restart
```

### Qwenが本当に使われているか確認

`ccr ui` でリアルタイム監視。またはログに OpenRouter へのリクエストが記録される。

### OpenRouter のクレジット残高確認

https://openrouter.ai/settings/credits

### 402エラー（クレジット不足）

OpenRouter のクレジットを追加: https://openrouter.ai/settings/credits

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-12 | 2重出力バグ修正（cli.js/server.js SSE二重送信）、Agent未対応の制約を明記 |
| 2026-04-12 | マルチエージェント構成追加（sonnet/haikuマッピング方式）、mcp-bare.json、qwen-multi.cmd |
| 2026-04-12 | OAuth競合問題の解決（`--bare` フラグ）、設定ファイルパス修正、同時使用セクション更新 |
| 2026-04-10 | ccr方式に全面改訂（qwen.ps1方式から移行） |
| 2026-04-10 | 初版作成（OpenRouter経由、qwen.ps1起動方式） |
