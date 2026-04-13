---
name: issue-planner
description: |
  GitHub Issues URLを渡すだけで、全オープンIssueを並列分析し、
  Codex CLIによる原因調査を経て詳細な実装計画をIssueコメントに自動投稿する。
  Grok補助分析を条件付きで挟み、長文Issue・大量コメント・外部依存・X由来知見の整理を強化する。
  Agent Teamsによる動的ワーカー並列処理。計画済みIssueは自動スキップ。
  トリガー: "issue-planner", "issue計画", "全issue分析", "一括計画",
  "issueプランナー", "実装計画一括"
  使用場面: (1) 全オープンIssueの一括実装計画作成、(2) バックログの棚卸し・優先度付け、
  (3) 新メンバーへのタスク可視化
---

# Issue Planner スキル

## 概要

GitHub Issues URLまたはリポジトリ名を渡すだけで、全オープンIssueを**Agent Teamsで並列分析**し、
**Codex CLI（read-only）**による原因調査を経て、詳細な実装計画をIssueコメントに自動投稿する。
複雑Issueでは **Grok-4.2系（`x-ai/grok-4.20-multi-agent`）** を補助分析として挟み、
長いIssue本文・大量コメント・外部知見・Xポスト由来の論点を整理してから Codex 本調査へ渡す。

```
URL入力 -> Issue Scanner Agent -> JSON読取 -> チーム作成 -> ワーカー並列処理(Codex Scout -> Grok補助分析 -> Codex本調査 -> 計画 -> レビュー -> 投稿) -> 完了レポート
```

## 計画

- Grok補助分析を `issue-planner` の標準フローへ追加する
- `--grok auto|on|off` と `--grok-timeout-ms` の運用ルールを明記する
- `Codex Scout -> Grok Context Synthesis -> Codex Main Analysis` の3段構成を references に反映する
- `tasks/todo.md` と `tasks/lessons.md` を追加し、進捗と再発防止を記録する

## Next Steps

- `SKILL.md` に役割分担、起動条件、オプション、チェックリストを追加する
- `references/worker-workflow.md` に Grok 実行テンプレートとフォールバックを追加する
- `references/multi-perspective-review.md`、`references/plan-template.md`、`references/error-handling-antipatterns.md`、`references/leader-workflow.md` を更新する
- `tasks/todo.md` と `tasks/lessons.md` を新規作成する

## トリガー条件

- `/issue-planner` コマンド
- 「issue計画」「全issue分析」「一括計画」等のキーワード
- GitHub Issues URL または リポジトリ名の入力

## 入力形式

以下のいずれかを受け付ける:
- **GitHub Issues URL**: `https://github.com/owner/repo/issues`
- **リポジトリ名**: `owner/repo`（例: `Robbits-CO-LTD/digital-management-consulting-app`）

## プロジェクトディレクトリの推定

MEMORY.md の「プロジェクトパス」セクションからリポジトリに対応するローカルディレクトリを特定する。
見つからない場合はユーザーに確認する。

既知のマッピング:
- `Robbits-CO-LTD/digital-management-consulting-app`:
  - 自宅PC: `C:/Users/zooyo/OneDrive/ドキュメント/digital-management-consulting-app/`
  - 会社PC: `C:/Users/zooyo/Documents/GitHub/DX/digital-management-consulting-app/`
  - **判定**: `ls` で存在するパスを使用する

## モデル役割と実行オプション

### 役割分担

| モデル | 役割 | 使いどころ |
|--------|------|-----------|
| Claude Opus 4.6 | オーケストレーション、文脈整理、統合判断 | リーダー進行、Reviewer A/B/D、最終統合 |
| GPT-5.4 / Codex | コード根拠付きの精密分析 | 関連ファイル特定、Before/After、影響範囲、final-check |
| Grok-4.2系 | 長文統合と広い外部知見の補助分析 | 長いIssue、大量コメント、外部依存、Xポスト由来の知見整理 |

### オプション

| オプション | 既定値 | 意味 |
|-----------|--------|------|
| `--grok auto|on|off` | `auto` | `auto` は条件一致時のみ起動、`on` は常時起動、`off` は無効 |
| `--grok-timeout-ms <ms>` | `600000` | Grok補助分析のタイムアウト。既定は10分 |

### Grok auto の起動条件

以下のいずれかに該当した場合のみ、Grok補助分析を起動する:

- 外部依存シグナルがある
- Issue本文 + コメントが6000字以上
- コメントが6件以上
- `candidate_files` が8件以上
- `pre_tier_score` が6以上
- Xポストやコミュニティ知見の横断収集が必要

### Grok の実行モード

| mode | 条件 | 内容 | timeout |
|------|------|------|---------|
| `repo_context_only` | 通常の Grok 起動 | Issue本文、コメント、候補ファイル、関連PR題名を整理 | `600000ms` |
| `extended_knowledge` | `x_research_required=true` | 上記 + Xポストや広いコミュニティ知見の整理 | `600000ms` |

---

## 核心ルール（14項目）

### 1. Issue Scanner Agentへの委任
- リーダーはIssue一覧/コメントを直接取得しない（コンテキスト汚染防止）
- サブエージェントに委任し、`tasks/issue-scan.json` 経由で結果を受け取る
- 詳細: references/issue-scanner-agent.md

### 2. スキップ判定（二重投稿防止）
- `planned` ラベル付きIssue -> スキップ
- コメントに `## 実装計画` / `## Implementation Plan` が存在 -> スキップ + ラベル補完
- 詳細: references/error-handling-antipatterns.md

### 3. 動的ワーカー数
- 0件: 処理終了、1-5件: 1ワーカー、6-12件: 2ワーカー、13+件: 3ワーカー
- Issue Scanner Agent が `recommended_worker_count` として算出

### 4. Codex調査（stdin経由必須 + タイムアウト防止）
- API 400エラー防止のため、プロンプトはファイル経由（stdin）で渡す
- read-only sandbox、MCP無効化
- **Codex Scout は 240000ms、Codex Main Analysis は 300000ms（5分）を必ず指定**
- **出力永続化: `2>&1 | tee /tmp/codex_output_{number}.txt` 必須**（kill時の部分結果回収用）
- タイムアウト時の段階的フォールバック（5段階: 部分出力回収 → プロンプト短縮 → reasoning引下げ → skip-git → スキップ）

### 5. Grok補助分析（条件付き起動 + 10分タイムアウト）
- Grok は `--grok auto|on|off` で制御する
- `auto` では複雑Issue、長文Issue、外部依存、Xポスト由来知見が必要な場合だけ起動する
- **Grok timeout は既定で `600000ms`（10分）を使う**
- `tasks/issue-planner/grok/issue-{number}.json` に中間成果物を保存する
- Grok の内容は補助情報であり、ファイルパス・行番号・型・API可否は Codex とローカル確認で再検証する

### 6. Grok出力の信頼境界
- `external_knowledge` と `x_signal_summary` の各項目に `confidence` と `verification_required` を必須で持たせる
- `verification_required=true` の情報は、裏取りなしで最終計画へ書かない
- Xポストやコミュニティ知見は「未検証補助情報」として扱う

### 7. 多角的レビュー（Tier別動的 2-4体並列 + Tier別完了率ゲート）
- Step 3.6 のTier判定結果に基づきレビュアー数を動的に決定:

| Tier | レビュアー構成 | completion_rate閾値 |
|------|-------------|-------------------|
| C (< 6) | A（技術正確性）+ C（Devil's Advocate） = 2体 | ≥ 50% (1/2) |
| B (≥ 6) | A + B（アーキ適合性）+ C = 3体 | ≥ 67% (2/3) |
| A (≥ 12) | A + B + C + D（Security Reviewer）= 4体 | ≥ 75% (3/4) |

- **全レビュアー完了待ち必須**（未完了のまま統合に進むことは禁止）
- severity別統合: critical=必須修正、major=修正推奨、minor=テスト追加、suggestion=反映しない
- **レビュー完了率ゲート（定量）**: 投稿可否を以下の数値で機械的に判定する
  - `review_completion_rate`: 成功レビュアー数 / tier_reviewer_count
- `critical_open`: 未解消のcritical指摘数
- 投稿可: `completion_rate >= Tier別閾値` かつ `critical_open == 0`
- 投稿不可: 閾値未達 または `critical_open > 0` → 計画見直し or スキップ
- 詳細: references/multi-perspective-review.md

### 8. 投稿順序の厳守
- **コメント投稿 -> 成功確認 -> ラベル追加**（逆順禁止）
- `planned` ラベル適用は**必須**（漏れると次回再計画対象になる）

### 9. ワーカー間タスク分配（反対端方式）
- planner-1: ID昇順、planner-2: ID降順で取得
- ownerフィールドで二重取得を防止
- 先に完了したワーカーは残りの未着手タスクを自動的に拾う

### 10. チームシャットダウンフロー
- shutdown_request -> 各ワーカーのshutdown_approved確認 -> TeamDelete
- 未応答なら30秒待機後にTeamDelete

### 11. Codex final-check（投稿前の最終検証）
- レビュー統合・修正適用後（Step 4.5c完了後）、投稿前に**Codex read-onlyで最終計画を検証**する
- **目的**: レビュー修正の適用自体が生む矛盾・型不整合・影響範囲漏れを検出する（設計レビューとは異なる「実装安全性」の検証）
- **検証観点**: (1)修正後のBefore/Afterコードが実ファイルと整合するか (2)critical修正で追加した変更が他の実装ステップと矛盾しないか (3)影響範囲テーブルに漏れがないか
- **ゲート**: `final_check_pass`=true で投稿可。false の場合は指摘箇所を修正してから投稿
- **スキップ条件**: composite_grade が A かつ critical_open==0 の場合のみ省略可（品質十分と判定）
- 詳細: references/worker-workflow.md（Step 4.7）

### 12. レビュー完了率の報告義務
- ワーカーの完了報告（Step 6）に以下を**必須**で含める:
  - `tier`: A/B/C（Step 3.6で判定）
  - `tier_score`: スコア値
  - `reviewer_count`: 2/3/4（Tier別）
  - `review_completion_rate`: {N}/{tier_reviewer_count}（例: 3/3、2/2）
  - `critical_open`: 未解消critical数（0であること）
  - `final_check`: pass/skip/fail
  - `composite_grade`: A/B/C/D
- リーダーの完了レポートに全IssueのTier分布 + レビュー完了率サマリを含める

### 13. Grok利用状況の報告義務
- ワーカーの完了報告に `grok_used`, `grok_status`, `grok_mode`, `grok_timeout_ms` を含める
- リーダーの完了レポートに `Grok used/skipped/failed/timeout` 件数を含める

### 14. ブランチ検証（コード調査前の必須チェック — Issue #1808教訓）
- **コード調査（Step 3）の前に、ローカルリポジトリのブランチ状態を必ず確認する**
- Issue本文に「PR #NNNで対応済み」「#NNNで移行完了」等の記述がある場合、`gh pr view` でマージ先ブランチを確認する
- **調査対象ブランチの決定ルール**:
  1. Issueが参照するPRが staging にマージ済み → staging を基準に調査
  2. Issueが参照するPRが main にマージ済み → main を基準に調査
  3. PRの参照がない → staging（最新コード）を基準に調査
- サブエージェント（Explore/Codex Scout）に渡すプロンプトには「{branch}ブランチを基準に調査せよ」と明示する
- **アンチパターン**: ローカルの default ブランチ（main）をそのまま読んで、staging に先行マージされた変更を「未実装」と誤判定する
- 詳細: references/worker-workflow.md（Step 2.5）

---

## リーダーワークフロー概要（9ステップ）

| Step | 内容 | 詳細 |
|------|------|------|
| 1 | 入力解析 | URL/リポ名からowner/repoを抽出 |
| 1.5 | **ゲートキーパー（早期終了判定）** | `gh issue list --state open --json number,labels` で (1) オープンIssue 0件 or (2) 全件が `planned` ラベル付きなら即終了。**Issue Scanner Agent を起動せずコスト0で終了**。部分的に計画済みの場合は未計画件数を表示して続行 |
| 2 | Issue Scanner Agent 起動 | サブエージェントに委任（失敗時1回再起動、それでも失敗ならリーダーフォールバック） |
| 3 | issue-scan.json 読み取り + バリデーション | 必須フィールド + 整合性チェック |
| 4 | フィルタリング結果報告 | 対象0件なら終了 |
| 5 | ワーカー数決定 | recommended_worker_count使用 |
| 6 | チーム展開 | TeamCreate -> TaskCreate -> ワーカースポーン |
| 7 | 監視・進捗報告 | エラー時は再割当 -> リーダー直接処理 -> スキップ |
| 8 | 完了処理 | サマリ（優先度順）-> シャットダウン -> TeamDelete |

詳細: references/leader-workflow.md

## ワーカーワークフロー概要（12ステップ）

| Step | 内容 |
|------|------|
| 1 | タスク取得（反対端方式） |
| 2 | Issue詳細取得（`gh issue view`） |
| 2.5 | **ブランチ検証**（Issue参照PRのマージ先を確認し、調査対象ブランチを決定 — Issue #1808教訓） |
| 3.0 | Codex Scout（軽量事前調査、JSON出力） |
| 3.1 | Grok Context Synthesis（条件付き、10分タイムアウト） |
| 3.2 | Codex Main Analysis（stdin経由、read-only） |
| 3.5 | コード現状検証（`git log`で最新状態確認、複雑度分類） |
| 3.5b | 外部依存の実現可能性検証（**条件付き**: 外部ライブラリ/API新規導入時のみ） |
| 3.6 | Tier判定（Codex Scout + Grok + Codex Main Analysis の結果から15シグナルスコアリング → 動的レビュアー数決定。fortress-review方式） |
| 4 | 計画組み立て（テンプレートに構造化） |
| 4.2 | 計画前提の実在性検証（export境界・プロパティ名・API能力・本番設定 — Issue #1638教訓） |
| 4.3 | Issue突き合わせ（計画 vs Issue要件のカバレッジ照合 — Issue #1638教訓） |
| 4.5 | 多角的レビュー（Tier別動的 2-4体並列 + Tier別完了率ゲート） |
| 4.7 | Codex final-check（**条件付き**: composite_grade A かつ critical_open==0 なら省略可） |
| 5 | 投稿（コメント -> ラベル順序厳守）※投稿ゲート: `completion_rate >= Tier別閾値` かつ `critical_open==0`。Tier Aは `fortress-review-required` ラベルも付与 |
| 6 | 完了報告（`tier` + `tier_score` + `reviewer_count` + `review_completion_rate` + `critical_open` + `final_check` + `composite_grade` + `grok_*` 必須）+ 次タスク取得 |

詳細: references/worker-workflow.md

---

## エラーハンドリング概要

| エラー | 対応 |
|--------|------|
| Issue Scanner Agent 失敗 | 再起動 -> リーダーフォールバック |
| Grok認証エラー | `grok_status=skipped_auth` として Codex 単独へ降格 |
| Grokタイムアウト（10分） | 1回だけ再試行 -> 失敗時 `partial_timeout` または `timeout` として Codex 単独へ降格 |
| Grok JSONパース失敗 | `skipped_parse_error` として Codex 単独へ降格 |
| Codexタイムアウト/kill | 部分出力回収 → 段階的フォールバック（5段階） |
| Bash timeout kill | /tmp/codex_output_{number}.txt から部分結果回収 → 十分なら採用、不十分なら短縮版で再実行 |
| API 400 | プロンプト短縮 -> reasoning引下げ -> skip-git -> スキップ |
| OpenRouter 402/429 | クレジット確認 or 待機後に Grok を1回だけ再試行 |
| GitHubレートリミット | 全ワーカー一時停止 -> 60秒待機 |
| コメント投稿失敗 | リトライ -> ローカル保存 |

詳細: references/error-handling-antipatterns.md

## アンチパターン概要

主要なもの:
- Codexをメインスレッドで直接実行（コンテキスト圧迫）
- コメント前にラベル追加（計画なしラベル）
- `gh issue list` に comments/body を含める（JSON肥大化）
- Reviewer C未完了のまま統合に進む（レビュー品質低下）
- レビュー完了率を確認せずに投稿する（completion_rate < 67% or critical_open > 0 で投稿）
- Codex final-check をスキップ条件外で省略する（レビュー修正が矛盾を生むリスク）
- Tier判定をスキップしてレビュアー数を固定する（低リスクIssueに過剰コスト、高リスクIssueに不十分なカバレッジ）
- リーダーがIssue一覧/コメントを直接取得（コンテキスト汚染）
- Grok のファイルパスや行番号を未検証のまま採用する
- Xポスト由来の知見を `verification_required=true` のまま最終計画へ書く
- **ローカルの default ブランチ（main）をそのまま読んで staging の先行変更を見落とす**（Issue #1808教訓）

詳細: references/error-handling-antipatterns.md

---

## 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| references/issue-scanner-agent.md | Issue Scanner Agentの詳細、issue-scan.jsonスキーマ、プロンプトテンプレート |
| references/leader-workflow.md | リーダーワークフロー8ステップの完全な手順 |
| references/worker-workflow.md | ワーカーワークフロー7ステップ、Codex調査詳細、ワーカープロンプトテンプレート |
| references/multi-perspective-review.md | 3レビュアー並列レビュー、統合ルール、品質スコア算出、プロンプトテンプレート |
| references/plan-template.md | 実装計画テンプレート（Issueコメント形式） |
| references/error-handling-antipatterns.md | エラーハンドリング、アンチパターン、検証方法、ドライラン実績、改訂履歴 |

---

## クイックスタート

1. `/issue-planner https://github.com/owner/repo/issues` または `/issue-planner owner/repo`
2. Issue Scanner Agent が自動でスキャン -> issue-scan.json 生成
3. ユーザーにフィルタリング結果を報告
4. ワーカーが並列でCodex調査 -> 計画組み立て -> 3視点レビュー -> 投稿
5. 完了レポート（優先度順テーブル + 工数合計見積）

## 関連スキル

| スキル | 関連 |
|--------|------|
| `fortress-review` | Tier判定スコアリングの参照元。Tier A Issueの実装前に `/fortress-review` を推奨 |
| `codex-autopilot` | stdin経由Codex実行パターンの参考元 |
| `agent-teams` | Team/Task管理ワークフローの参考元 |
| `issue-flow` | 個別Issue実装フロー（計画テンプレート元） |
| `openrouter` | Grok-4.2系のモデル呼び出しパターンと認証の参考元 |
| `codex` | Codex CLIコマンド形式の参考元 |
| `github-cli` | gh コマンドリファレンス |

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| Codex CLIがタイムアウト | `codex exec` の `--timeout` 値を増やす（デフォルト120秒→300秒） |
| Grok がタイムアウトする | `--grok-timeout-ms 600000` を維持し、必要なら `--grok off` で Codex 単独へ切り替える |
| Grok が起動しない | `--grok on` で強制起動する。`auto` では起動条件を満たさないと実行されない |
| OpenRouter の認証に失敗する | `OPENROUTER_API_KEY` を確認し、失敗時は `grok_status=skipped_auth` のまま継続する |
| GitHub APIレート制限 | `gh auth status` でトークン確認。大量Issue時は間隔を空ける |
| ワーカーが応答しない | Task出力ファイルを確認。stuck時は `TaskStop` で停止→再起動 |
| 計画済みIssueが再計画される | `planned` ラベルが正しく付与されているか `gh issue view` で確認 |

## 計画品質チェックリスト

- [ ] 全オープンIssueがスキャンされたか
- [ ] 各IssueにCodex調査結果が含まれているか
- [ ] 優先度順テーブルが出力に含まれているか
- [ ] `planned` ラベルが計画済みIssueに付与されたか
- [ ] 全Issueの `review_completion_rate >= Tier別閾値` か（C≥50%, B≥67%, A≥75%）
- [ ] 全Issueの `critical_open == 0` か（未解消critical指摘なし）
- [ ] Tier A Issueに `fortress-review-required` ラベルが付与されたか
- [ ] composite_grade A以外のIssueで `final_check == pass` か
- [ ] Grok起動Issueに `grok_status`, `grok_timeout_ms`, `grok_signals` が残っているか
- [ ] `verification_required=true` の Grok知見が未検証のまま最終計画に出ていないか
- [ ] コード調査が正しいブランチ（staging/main）を基準に実施されたか（Step 2.5）

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-05 | 初版作成 | Issue一括計画スキルの体系化 |
| 2026-03-18 | トラブルシューティング・改訂履歴・チェックリスト追加 | skill-improve audit対応 |
| 2026-03-24 | 4点改善: (1)plan-templateにエッジケース防御/テスタビリティ/ロールバック/分割Issue提案セクション追加 (2)Reviewer B/Cチェック項目強化+品質ゲート追加 (3)Step 2.1既存計画チェック+Step 4既存util判定ガイド追加 (4)改訂履歴更新 | Issue #1560教訓: レビューC→A改善プロセスの体系化 |
| 2026-03-25 | Step 3.5b「外部依存の実現可能性検証」追加（条件付き: 外部ライブラリ/API新規導入時のみ発動）。シグナル検出→実在確認→環境制約検証→方式比較の4段階。worker-workflow.md本体+テンプレート両方更新 | Issue #1577教訓: freee MCP方式の裏どりで方針転換。計画前に外部依存の実現可能性を検証するプロセスの体系化 |
| 2026-03-27 | 3点改善: (1)レビュー完了率の定量ゲート追加（`completion_rate>=67%` + `critical_open==0`）(2)Step 4.7「Codex final-check」追加（レビュー修正後の実装安全性検証）(3)完了報告にreview metrics必須化。核心ルール8→10項目に拡張 | レビュー完了率とCodex final-checkの教訓: 定性ルールの定量化、レビュー修正自体が生む矛盾の検出 |
| 2026-04-01 | Step 1.5「ゲートキーパー（早期終了判定）」追加。全件planned済み or オープン0件時にIssue Scanner Agent起動前に即終了 | トークンコスト最適化: Agent Teams+Codex並列呼び出しの空振り防止 |
| 2026-04-07 | fortress-review Tier判定を統合: (1)Step 3.6「Tier判定」新設（15シグナル×重みスコアリング）(2)レビュアー数を動的化（C:2体/B:3体/A:4体）(3)Reviewer D（Security Reviewer）追加（Tier Aのみ）(4)completion_rateをTier別閾値に変更（C≥50%/B≥67%/A≥75%）(5)Tier AにはIssueに`fortress-review-required`ラベル付与(6)完了報告にtier/tier_score/reviewer_count追加(7)計画テンプレートにissue-planner-metaメタデータ埋め込み | fortress-review「動的N方式」のパイプライン最上流への統合。低リスクIssueのトークン25-30%削減、高リスクIssueのカバレッジ強化 |
| 2026-04-12 | Grok補助分析を統合: (1)`--grok auto|on|off` と `--grok-timeout-ms` 追加 (2)Step 3 を `Codex Scout -> Grok Context Synthesis -> Codex Main Analysis` に再構成 (3)Grok の10分タイムアウト、X知見モード、信頼境界、メタデータを追加 | 長文Issue・大量コメント・外部依存・Xポスト由来知見の整理を強化しつつ、最終計画の根拠は Codex とローカル検証に固定するため |
| 2026-04-13 | worker-workflow: git fetch必須化(#1798教訓)、Grok知見の信頼境界フィルタリング追加 |
| 2026-04-11 | Step 2.5「ブランチ検証」新設 + 核心ルール14追加: (1)コード調査前にIssue参照PRのマージ先ブランチを確認 (2)staging/mainの判定ルール明記 (3)サブエージェントに調査対象ブランチを明示する義務 (4)アンチパターンに「mainブランチ固定読み取り」追加 | Issue #1808教訓: mainブランチのコードを読んでBlob移行を「未実装」と誤判定。stagingには既に反映済みだった |

## 進捗

- `issue-planner` スキル本体に Grok 補助分析の役割、起動条件、オプションを追加した
- reference 群に `Codex Scout -> Grok Context Synthesis -> Codex Main Analysis` の流れを反映した
- `tasks/todo.md` と `tasks/lessons.md` を追加し、作業記録と再発防止の置き場を作った

## Next Tasks

- 実運用で 2〜3 件の複雑Issueを使い、`grok_status` と `grok_timeout_ms` が期待どおりに記録されるか確認する
- `extended_knowledge` モードで拾った外部知見が、Reviewer A の実在性検証で弾けるか確認する
- 必要なら Phase 2 として、Grok を追加レビュアーに昇格させるかを別途評価する
