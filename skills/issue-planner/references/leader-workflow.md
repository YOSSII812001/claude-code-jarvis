<!-- 抽出元: SKILL.md「リーダーワークフロー（8ステップ）」セクション（旧 行204-365） -->

# リーダーワークフロー（8ステップ）

## Step 1: 入力解析 + ブランチ検証

URLまたはリポジトリ名から `owner/repo` を抽出する。

```bash
# URL例: https://github.com/Robbits-CO-LTD/digital-management-consulting-app/issues
# -> owner = Robbits-CO-LTD
# -> repo = digital-management-consulting-app

# MEMORY.md からプロジェクトディレクトリを特定
# -> project_dir = C:/Users/zooyo/OneDrive/ドキュメント/digital-management-consulting-app/
```

### ブランチ検証（Issue #1808教訓）

リーダーはプロジェクトディレクトリ特定後、**コード調査の基準ブランチを確認**する。
ローカルの default ブランチ（main）をそのまま読むと、staging に先行マージされた変更を見落とすリスクがある。

```bash
# ローカルの現在のブランチを確認
git -C "{project_dir}" branch --show-current

# staging が存在し、main より進んでいるか確認
git -C "{project_dir}" log --oneline staging..main 2>/dev/null | head -3
git -C "{project_dir}" log --oneline main..staging 2>/dev/null | head -3
```

**判定ルール**: staging が main より ahead の場合、ワーカーに `TARGET_BRANCH=staging` を指示する。
ワーカープロンプトに `TARGET_BRANCH` を含め、Step 2.5 でのブランチ切り替えに使用する。

## Step 2: Issue Scanner Agent 起動

Issue一覧取得・スキップ判定・ワーカー数算出をサブエージェントに委任する。

```
Agent tool:
  subagent_type: "general-purpose"
  description: "Issue Scanner Agent"
  prompt: （前述「Issue Scanner Agent プロンプトテンプレート」に {owner}/{repo}, {project_dir} を埋め込んで使用）
```

サブエージェント完了後、Step 3 に進む。

**フォールバック**: サブエージェントが失敗した場合、1回再起動する。
それでも失敗した場合、リーダーが直接以下を実行する:
1. `planned` ラベル確認・作成
2. `gh issue list` で軽量一覧取得（Pass 1）
3. 個別コメントチェック（Pass 2）+ ラベル補完（Pass 2b）
4. `tasks/issue-scan.json` を手動作成

## Step 3: issue-scan.json 読み取り + バリデーション

Issue Scanner Agent が出力した `tasks/issue-scan.json` を読み取り、バリデーションする。

```
1. ファイル存在チェック:
   Read tool で {project_dir}/tasks/issue-scan.json を読み取る

2. JSON バリデーション（必須フィールド確認）:
   - scan_id: 文字列
   - repo: owner/repo 形式
   - target_issues: 配列（各要素に number, title）
   - skipped_issues: 配列（各要素に number, reason, title）
   - total_open_count, total_target_count, total_skipped_count: 数値
   - recommended_worker_count: 数値（0〜3）

3. 整合性チェック:
   - total_target_count == target_issues.length
   - total_skipped_count == skipped_issues.length
   - total_open_count == total_target_count + total_skipped_count

4. バリデーション失敗時:
   Issue Scanner Agent を再起動 -> 再度失敗ならリーダーフォールバック
```

## Step 4: フィルタリング結果報告

`issue-scan.json` のデータを元にユーザーに報告する。

**報告フォーマット:**
```
Issue分析結果:
  対象: X件（#1, #3, #7, ...）
  スキップ: Y件（#2: planned済, #5: 計画コメント済, ...）
  合計: Z件のオープンIssue
```

対象が0件の場合はここで終了。

## Step 5: ワーカー数決定

`issue-scan.json` の `recommended_worker_count` を使用する（Issue Scanner Agent が Phase 3 で算出済み）。

## Step 6: チーム展開

```
1. TeamCreate:
     team_name: "issue-planner-{timestamp}"
     description: "Issue実装計画の並列作成"

2. TaskCreate（各対象Issue分、データソースは issue-scan.json の target_issues）:
     subject: "Issue #{number} の実装計画作成"
     description: |
       ## 対象Issue
       - number: {number}
       - title: {title}
       - repo: owner/repo
       - project_dir: {project_dir}

       ※ Issue詳細（body）はワーカーが Step 2 で `gh issue view` で取得すること。

       ## 作業手順
       ワーカーワークフロー（6ステップ）に従って実行すること。
     activeForm: "Issue #{number} の実装計画を作成中"

3. Agent tool（ワーカースポーン）:
     subagent_type: "general-purpose"
     team_name: "issue-planner-{timestamp}"
     name: "planner-{N}"
     run_in_background: true
     mode: "bypassPermissions"
     prompt: |
       （後述「ワーカープロンプトテンプレート」を使用）
```

**重要**: ワーカーは `run_in_background: true` でスポーンし、リーダーは並行して進捗を監視する。

**ワーカー間タスク分配戦略（反対端方式）:**
```
ワーカー数=2の場合:
  planner-1: タスクID 1 -> 2 -> 3 -> ...（前方から順に取得）
  planner-2: タスクID N -> N-1 -> ...（後方から順に取得）

ワーカー数=3の場合:
  planner-1: タスクID 1, 2, 3, ...
  planner-2: タスクID中央付近から
  planner-3: タスクID N, N-1, N-2, ...
```
先に完了したワーカーは残りの未着手タスクを自動的に拾う（動的負荷分散）。
TaskUpdateの `owner` フィールドで二重取得を防止する。

## Step 7: 監視・進捗報告

- SendMessageの自動受信でワーカーの進捗を把握
- エラー報告を受けた場合:
  1. 別ワーカーへの再割り当てを検討
  2. 再割り当て不可能な場合、リーダーが直接処理を試行
  3. 最終手段としてスキップ -> ユーザーに報告
- 中間報告: 5件以上の対象がある場合、50%完了時点で中間報告

## Step 8: 完了処理

```
1. 結果サマリ表示（優先度順）:
   完了レポート:
     成功: X件（#1, #3, #7）
     失敗: Y件（#12: Codexタイムアウト）
     スキップ: Z件（#2: planned済）
     Grok used: A件 / skipped: B件 / failed: C件 / timeout: D件

   優先度順テーブル:
     | 優先度 | Issue | レビュースコア |
     |--------|-------|--------------|
     | P0 | #XX（即時対応が必要） | A (3/3完了) |
     | P1 | #XX, #YY（今スプリント） | B (2/3完了) |
     | P2 | ... | ... |

   工数合計見積:
     S: X件（約Yh）、M: X件（約Y-Zh）

   Grok利用サマリ:
     | 状態 | 件数 |
     |------|------|
     | success | X |
     | partial_timeout | X |
     | timeout | X |
     | skipped_auth / skipped_parse_error / skipped | X |

2. チームシャットダウン（確認フロー付き）:
   SendMessage type: "shutdown_request" -> 各ワーカー
   -> 各ワーカーの shutdown_approved / teammate_terminated を確認
   -> 全ワーカー終了を確認してから次へ（未応答なら30秒待機）

3. チームクリーンアップ:
   TeamDelete（全メンバー終了後にのみ実行）
```
