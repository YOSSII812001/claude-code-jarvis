# クアドレビュー詳細手順

実装完了後に実施する **4系統のレビュー** の詳細手順。
まずLintチェックでコード品質を担保し、PR作成後に /sub-review・Codex差分レビュー・CodeRabbitの3系統を並列で実施する。
/sub-review は Anthropic 公式 `/code-review` プラグインのアーキテクチャに準拠し、4つの専門エージェントが信頼度スコアリングで誤検知をフィルタリングする。

> **重要: PR作成直後に `--watch` でブロックしない。先にCodex差分レビュー+/sub-reviewを起動し、その後に `--watch` で待機する。**

## レビュー体制

| レビュー | 方式 | 焦点 |
|---------|------|------|
| **Lintチェック** | PR作成前にローカル実行 | コード品質・型エラー・スタイル |
| **/sub-review** | `/sub-review` コマンド（4並列エージェント） | 4観点の専門レビュー + 信頼度スコアリング |
| **Codex差分レビュー** | Taskツール（Bash）で起動 | 別LLMによるセカンドオピニオン |
| **/code-review** | 公式プラグイン（PR作成後に実行） | CLAUDE.md/REVIEW.md準拠・git履歴・PR履歴（**soft gate**） |
| **CodeRabbit** | PR作成時に自動起動 | 静的解析・一般的なコード品質 |

## /sub-review の4エージェント（公式 `/code-review` プラグイン準拠）

| Agent | 観点 | 主なチェック内容 |
|-------|------|-----------------|
| **Agent 1** | 構造・設計 | 関心の分離、アーキテクチャ整合性、責務の明確さ |
| **Agent 2** | バグ・エッジケース | 型エラー、null未処理、非同期エラー、セキュリティ |
| **Agent 3** | 可読性・保守性 | サイレント障害、マジックナンバー、過度な複雑さ |
| **Agent 4** | 規約準拠 | CLAUDE.md違反、命名規則、ファイル配置 |

## 信頼度スコアリング（0-100、閾値: 80）

- 76-100: 確実（コードから直接証明可能） → **報告対象**
- 0-75: 推測〜高確度 → 除外（誤検知フィルタリング）

## フロー図

```
実装完了 → Lintチェック → 【Codex final-check】 → ビルド確認 → コミット → プッシュ → PR作成（staging向け）
  ↓
┌──────────────────────────────────────────────────────┐
│ ① Phase 1 + Phase 2 を並列起動（計6 Task）           │
│                                                      │
│ Phase 1（hard gate）:                                 │
│   Task 1: Codex CLI (Codex差分レビュー)               │
│   Task 2-5: /sub-review（4並列エージェント）           │
│     Agent 1: 構造・設計  Agent 2: バグ・エッジケース    │
│     Agent 3: 可読性・保守性  Agent 4: 規約準拠         │
│                                                      │
│ Phase 2（soft gate）:                                 │
│   Task 6: /code-review（公式プラグイン）               │
│     → CLAUDE.md/REVIEW.md準拠・git履歴 → PRコメント   │
│                                                      │
│ ※ CodeRabbit は PR作成時に自動起動済み（soft gate）   │
└──────────────────────────────────────────────────────┘
  ↓
② gh pr checks <PR番号> --watch（バックグラウンド）
  ↓
③ 4つのレビュー結果を統合（信頼度≥80のみ採用、重複統合） → 修正 → 再プッシュ
```

## 実行手順（この順番を厳守）

**ステップ1: Lint + 型チェック（PR作成前・パイプライン⓪〜①に対応）**
```bash
npm run lint
cd frontend && npm run type-check
```
> Lint・型チェックにエラーがある場合は修正してから次へ進む。

**ステップ1.5: Codex final-check（Lint通過後、ビルド前）**
codexスキルの「final-check」に従い、workspace-writeで軽微修正を自動適用。
タイムアウト・失敗時はスキップして続行。

**ステップ1.9: ビルド確認**
```bash
cd frontend && npx vite build
```
> ビルドエラーがある場合は修正してからコミットする。

**ステップ2: PR作成**
```bash
git push origin <branch>
gh pr create --base staging --title "タイトル" --body "説明"
```

**ステップ3: Codex差分レビュー + /sub-review を即座に並列起動**

PR作成直後、`--watch` より先に Phase 1（5 Task）+ Phase 2（1 Task）を同時起動する（計6つの Task ツール）。

```
# 1つのメッセージで6つのTaskツールを並列起動

# === Phase 1（hard gate）: Codex差分 1 + /sub-review 4 ===
Task tool 1 (subagent_type: Bash):
  description: "Codex差分レビュー"
  prompt: codex exec --full-auto --sandbox read-only --cd "<project_dir>"
         "git diff staging...HEAD の内容をレビューしてください"

Task tool 2-5: /sub-review コマンドの手順に従い、4つの専門エージェントを並列起動
  Agent 1: 構造・設計分析
  Agent 2: バグ・エッジケース検出
  Agent 3: 可読性・保守性
  Agent 4: プロジェクト規約準拠
  （各エージェントに git diff を直接埋め込み、信頼度スコア付きで返却）

  ⚠️ 各エージェントのプロンプト末尾に以下を必ず追加すること（output_file空問題対策 #1000）:
  「レビュー結果は省略せず、最終回答として必ず全文を出力してください。
   結果が空にならないよう、必ずレビュー内容を含む回答で終了してください。」

# === Phase 2（soft gate）: /code-review 公式プラグイン ===
Task tool 6 (Skill: code-review):
  description: "/code-review（GitHub統合レビュー）"
  → PR番号を自動検出し、5 Sonnetエージェントが並列レビュー
  → 結果はGitHub PRコメントとして自動投稿
  → 失敗/スキップ時: Phase 1結果のみで続行（ブロッカーにしない）
```

**ステップ4: --watch をバックグラウンドで起動**

Codex差分レビュー + /sub-review を起動した後に、`--watch` をバックグラウンドで実行。

```bash
# バックグラウンドで実行（run_in_background: true）
gh pr checks <PR番号> --watch
```

**ステップ5: レビュー結果の統合**

Codex差分レビュー + /sub-review（4エージェント）の結果が先に返ってくるので、**信頼度≥80の指摘のみ統合**してユーザーに報告。
CodeRabbitと/code-reviewは `--watch` 完了後に**必ずレビュー内容を読む**（passだけで判断しない）。

> **重要: output_file空問題への対策（Issue #1000教訓）**
> `run_in_background: true` で起動したsub-reviewエージェントの `output_file` が空（1行のみ）になることがある。
> 結果取得時は以下の手順を必ず実施すること:
> 1. `TaskOutput` で `status: completed` を確認
> 2. `output_file` の行数を確認（空または1行の場合は空と判断）
> 3. 空の場合、エージェントを **resume** して再度結果を取得する
> 4. 全4エージェントの結果が揃ったことを確認してから統合に進む

> **重要: CodeRabbitの `pass` はチェックが完了したことを示すだけで、指摘がないことを意味しない。**
> 必ずPRコメントを取得して内容を確認すること。

```bash
# /code-review の結果を確認（Phase 2 soft gate）
# "Code review" を含むコメントを検索
gh api repos/<owner>/<repo>/pulls/<PR番号>/comments --jq '.[] | select(.body | contains("Code review")) | .body'
# → 🔴 Normal: 修正推奨（ブロッカーにはしない）
# → 🟡 Nit: 記録のみ
# → 🟣 Pre-existing: 記録のみ（このPR起因ではない）

# CodeRabbitレビュー内容を必ず読む（passでも省略しない）
gh api repos/<owner>/<repo>/pulls/<PR番号>/comments --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body'

# レビューコメントも確認
gh api repos/<owner>/<repo>/pulls/<PR番号>/reviews --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body'
```

## なぜこの順番か

- `--watch` は完了までブロックする（数分かかる）
- 先に `--watch` すると、Codex差分レビュー+/sub-reviewの起動がユーザーの手動指示待ちになる
- Codex差分レビュー+/sub-reviewを先に起動すれば、`--watch` の待ち時間中にレビューが並行して完了する

## `--auto` マージとCodeRabbitレビューのタイミング（PR #1205教訓）

> **`--auto` マージを使う場合、CodeRabbitのレビューがCIチェック後に到着する可能性を認識すること。**

`gh pr merge --squash --auto` はCIチェック通過時点で自動マージされる。CodeRabbitのレビューはCIとは独立したタイミングで完了するため、CIが先に通ればレビュー指摘を反映する前にマージされる。

**対応方針:**
- 通常のPRでは `--auto` を使用して問題ない（後続コミットで対応可能）
- 重要な修正では `--auto` を避け、CodeRabbitレビュー完了を待ってから手動マージ
- `--auto` マージ後にCodeRabbit指摘が来た場合は、追加コミットで対応する

## レビュー結果の統合と対応

**対応ルール:**
| 指摘タイプ | 対応 |
|-----------|------|
| **重大な問題（セキュリティ等）** | 必ず修正 |
| **軽微な指摘（命名、コメント等）** | 適宜修正（妥当な場合のみ） |
| **好みの問題** | スキップ可 |
