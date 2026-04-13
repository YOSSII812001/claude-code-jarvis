# Fortress Review（動的多角レビュー）: $ARGUMENTS

## ゴール
絶対に失敗できない実装に対して、リスクレベルに応じた動的多角レビューを実施する。

## 実行手順
1. SKILL.md を読む: `~/.claude/skills/fortress-review/SKILL.md`
2. エージェントプロンプトを読む: `~/.claude/skills/fortress-review/references/agent-prompts.md`
3. SKILL.md の Step 0〜5 に従って実行

## 入力: $ARGUMENTS

### 入力形式の例
- `/fortress-review #123` — Issue番号を指定
- `/fortress-review https://github.com/org/repo/pull/456` — PR URLを指定
- `/fortress-review --tier A #123` — Tier手動指定
- `/fortress-review --dry-run #123` — Tier判定のみ（エージェント起動なし）
- `/fortress-review --no-codex #123` — Codexスキップ
- `/fortress-review --full #123` — Tier Cでもフルチーム
- `/fortress-review --skip-r2 #123` — Round 2スキップ

## 注意事項
- Human Gate（Step 3）は省略不可 — 必ずユーザーの判断を仰ぐ
- Codexエージェントは `codex exec --cd` 方式（Windows 8191文字制限回避）
- Claude SubAgentは差分埋め込み方式（ファイル探索禁止）
