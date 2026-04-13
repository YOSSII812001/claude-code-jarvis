# 横断テンプレート定義

全33スキルに一括適用する3つの共通セクションテンプレート。
git-worktree (9/10) をベストプラクティスとして参照。

---

## テンプレート1: 改訂履歴

**ルール:**
- カラム構成: `日付 | 変更内容 | 変更理由` の3列（変更者列は不要 — 全てClaude Code）
- 初版作成時: `初版作成` + スキルの目的を1行で記載
- 保持件数: 上限なし（直近から時系列降順で記載）
- 配置: SKILL.md の**最後のセクション**として配置

```markdown
---

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（改訂履歴・トラブルシューティング・関連スキル追加） | スキル品質改善計画 |
| YYYY-MM-DD | 初版作成 | [スキルの目的を1行で] |
```

---

## テンプレート2: トラブルシューティング

**ルール:**
- 見出し名: 全カテゴリ共通で `## トラブルシューティング`
- 最低2件のエントリ必須
- カテゴリ別にテーブル形式を変える
- 配置: 関連スキルセクションの**直前**

### リファレンス型（CLI系: stripe, supabase, vercel, github, obsidian, playwright等）

```markdown
## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| [具体的なエラーメッセージ] | [原因の説明] | [解決コマンドや手順] |
| [別の症状] | [原因] | [対処法] |
```

### ワークフロー型（issue-flow, autopilot, codex等）

```markdown
## トラブルシューティング

| ステップ | よくある問題 | 解決方法 |
|---------|-------------|---------|
| [ステップ名] | [問題の説明] | [解決手順] |
| [別のステップ] | [問題] | [解決方法] |
```

### マインドセット型（stoic, wellbeing, mba, ux-psychology等）

```markdown
## トラブルシューティング

### Q: [よくある質問や懸念]
**A:** [回答・対処法]

### Q: [別の質問]
**A:** [回答]
```

### MCP型（context7, google-sheets-mcp, claude-for-chrome等）

```markdown
## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| [問題の説明] | [解決手順] |
| [別の問題] | [対処法] |
```

---

## テンプレート3: 関連スキル

**ルール:**
- フォーマット: `- **スキル名** — 1行説明`（ダッシュ区切り）
- 最低2件、最大6件
- 双方向リンクは推奨だが強制しない（更新タイミングのズレを許容）
- 配置: トラブルシューティングの**直後**、改訂履歴の**直前**

```markdown
---

## 関連スキル

- **スキル名1** — このスキルとの関連を1行で説明
- **スキル名2** — このスキルとの関連を1行で説明
```

---

## カテゴリ分類表

| カテゴリ | スキル |
|---------|--------|
| リファレンス型(CLI) | stripe-cli, supabase-cli, vercel-cli, github-cli, obsidian-cli, playwright-cli |
| MCP型 | context7, google-sheets-mcp, claude-for-chrome |
| ワークフロー型 | issue-flow, issue-planner, issue-autopilot-batch, codex, codex-autopilot, skill-improve, e2e-test |
| マインドセット型 | stoic-daily-practice, wellbeing-mindset, mba-strategy-consultant, ux-psychology, ui-ux-pro-max, security-adversarial |
| プロジェクト型 | usacon, usacon-partner-registration, usacon-account-mgmt, liftkit, git-worktree, agent-teams, playwright, gbizinfo, jgrants, vercel-watch, design-review-checklist |
