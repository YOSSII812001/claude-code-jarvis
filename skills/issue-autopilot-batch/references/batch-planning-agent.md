<!-- 抽出元: SKILL.md「Batch Planning Agent（計画策定サブエージェント）」セクション（旧 行75-196）
     + 「対象Issue取得とスキップ判定」セクション（旧 行257-278）
     + 「実行順序の決定」セクション（旧 行281-320） -->

# Batch Planning Agent（計画策定サブエージェント）

## batch-plan.json スキーマ

Batch Planning Agent が `tasks/batch-plan.json` に書き出す計画データ（不変）。リーダーは Read で読み取るのみ。

```json
{
  "batch_id": "autopilot-batch-20260304-1430",
  "repo": "owner/repo",
  "project_dir": "C:/Users/zooyo/Documents/GitHub/DX/...",
  "input_mode": "all-planned",
  "execution_order": [11, 14, 13, 15],
  "issues": [
    {
      "number": 11, "title": "Auth API", "branch_hint": "feat/issue-11-auth-api",
      "priority": "P1", "effort": "M",
      "tier": "B",
      "tier_score": 8,
      "tier_breakdown": "data=3,auth=0,arch=4,scope=2,ops=0",
      "affected_files": ["src/auth.ts", "src/api/login.ts", "src/lib/session.ts"],
      "dependencies": [], "conflict_notes": "src/auth.ts は #14 と共有",
      "e2e_test_hints": ["ログイン画面表示確認", "認証APIレスポンス検証"],
      "has_plan_comment": true
    }
  ],
  "skipped": [{ "number": 12, "title": "UI改善", "reason": "implementing ラベル" }],
  "conflict_pairs": [{ "issues": [11, 14], "shared_files": ["src/auth.ts"], "recommended_order": "..." }],
  "codex_preflight_used": true, "codex_fallback": false,
  "total_target_count": 4, "total_skipped_count": 1
}
```

**`batch-plan.json` と `batch-pipeline-state.json` の関係:**
- `batch-plan.json`: 計画データ（不変）-- Batch Planning Agent が書き出し、リーダーが読み取るのみ
- `batch-pipeline-state.json`: 実行状態（可変）-- Step 6 で plan -> state にコピー、実行中に随時更新
- **resumeモードでは `batch-pipeline-state.json` のみ使用**（`batch-plan.json` に依存しない）

## Batch Planning Agent プロンプトテンプレート

```
あなたは issue-autopilot-batch の Batch Planning Agent です。
リーダーに代わってIssue分析・計画策定を実行し、結果を tasks/batch-plan.json に書き出してください。

## 入力情報
- リポジトリ: {repo}
- プロジェクトディレクトリ: {project_dir}
- 入力形式: {input_mode}（all-planned / Issue番号リスト / milestone:{name}）
- 指定Issue番号（リストモード時のみ）: {issue_numbers}

## Phase 0: ラベル準備
以下のラベルが存在しない場合のみ作成:
gh label create "implementing" --repo {repo} --color "FBCA04" --description "バッチ実装中" 2>/dev/null
gh label create "implemented" --repo {repo} --color "0075CA" --description "実装完了・E2E通過" 2>/dev/null
gh label create "regression" --repo {repo} --color "B60205" --description "リグレッション検出" 2>/dev/null
gh label create "found-during-e2e" --repo {repo} --color "E4E669" --description "E2E中発見の既存バグ" 2>/dev/null

## Phase 1: 対象Issue一覧取得
入力形式に応じてIssue一覧を取得:
- all-planned: gh issue list --repo {repo} --state open --label "planned" --limit 100 --json number,title,labels
- Issue番号リスト: 各番号を gh issue view で取得
- milestone: gh issue list --repo {repo} --milestone "{name}" --state open --label "planned" --limit 100 --json number,title,labels

## Phase 2: スキップ判定
各Issueについて以下をチェック:
- implementing/implemented/implementation-failed ラベル -> スキップ
- assignee設定済み -> スキップ
- オープンPRが存在（gh pr list --search "Issue #{number}"） -> スキップ
- 実装計画コメントなし（gh issue view で「## 実装計画」がない） -> スキップ
スキップ理由を skipped 配列に記録。

## Phase 3: 実装計画コメント解析
対象Issueごとに gh issue view --comments で実装計画コメントを取得し、以下を抽出:
- priority: P0-P3（デフォルト P2）
- effort: S/M/L/XL（デフォルト M）
- affected_files: 影響ファイル一覧（grep網羅検索で取得。上位N件制限なし）
- dependencies: 前提Issue番号リスト
- e2e_test_hints: テスト確認ポイント
- branch_hint: ブランチ名候補（feat/issue-{number}-{slug}）
- **tier情報パース（issue-planner-meta からの抽出）**:
  計画コメント本文から `<!-- issue-planner-meta` で始まるHTMLコメントブロックを検索し、以下を抽出:
  ```bash
  # 全コメントからissue-planner-metaを抽出
  gh issue view {number} --repo {repo} --json comments \
    --jq '.comments[].body' | grep -A 10 'issue-planner-meta'
  ```
  パース対象:
  - `tier: {A|B|C}` → issues[].tier（正規表現: `tier:\s*(A|B|C)`）
  - `tier_score: {N}` → issues[].tier_score（正規表現: `tier_score:\s*(\d+)`）
  - `tier_breakdown: data={N},auth={N},...` → issues[].tier_breakdown（正規表現: `tier_breakdown:\s*(.+)`）
  
  **パース失敗時（手動計画等でメタデータなし）**: tier=null, tier_score=null, tier_breakdown=null を設定。リーダー側でデフォルトTier B扱いとする。

## Phase 4: Codex Pre-flight（実行順序 + ファイル競合検出）
Phase 3 の抽出結果をまとめて Codex に送信（codex-autopilot スキルのパターンに準拠）:

cat > /tmp/batch_preflight.txt << 'CODEX_PROMPT_EOF'
あなたはシニアエンジニアです。以下のIssue一覧の最適な実行順序を決定してください。

[Issue一覧]
{各Issueの番号、タイトル、優先度、工数、影響ファイル、依存関係}

[ソートルール]
1. 依存関係（DAGトポロジカルソート、ファイル競合も依存として扱う）
2. 優先度（P0 > P1 > P2 > P3）
3. 工数（S < M < L < XL）
4. Issue番号（タイブレーカー）

[追加タスク]
- 同じファイルを変更するIssueペアを全て列挙
- 競合ペアの推奨実行順序を理由付きで提示
- 各競合ペアについて変更予定の関数/セクションの行範囲を特定し、高リスク（同一関数/セクション変更）と低リスク（同一ファイル・異なるセクション変更）を判定

出力形式: Issue番号の順序リスト + 競合ペア一覧（行範囲リスクレベル付き）
CODEX_PROMPT_EOF

# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/batch_preflight.txt | codex exec \
  --full-auto --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="medium" \
  -c features.rmcp_client=false - \
  2>&1 | tee /tmp/codex_preflight_output.txt
CODEX_EXIT=${PIPESTATUS[0]}
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Codex Pre-flight異常終了 (exit=$CODEX_EXIT) ==="
  cat /tmp/codex_preflight_output.txt
fi
rm -f /tmp/batch_preflight.txt

**Bash tool timeout: 240000ms（4分）** — 必ず指定すること。

Codex失敗/kill時のフォールバック:
1. /tmp/codex_preflight_output.txt から部分結果を回収 → 順序リストが読み取れれば採用
2. 部分結果が不十分な場合、ヒューリスティック順序（優先度->工数->Issue番号）でフォールバック
3. クリーンアップ: `rm -f /tmp/codex_preflight_output.txt`

6件以上は影響ファイル上位3件のみ送信。

## Phase 3 追加: Tier情報パース
対象Issueの計画コメントからHTMLコメント `<!-- issue-planner-meta` ブロックを検索し、
tier, tier_score, tier_breakdown を抽出してください。
パース方法: 正規表現 `tier:\s*(A|B|C)`, `tier_score:\s*(\d+)`, `tier_breakdown:\s*(.+)` でマッチ。
ブロックが見つからない場合は null を設定（手動計画のためメタデータなし）。

## Phase 5: batch-plan.json 書き出し
上記の分析結果を tasks/batch-plan.json に書き出す。スキーマは上記「batch-plan.json スキーマ」に準拠。
batch_id は "autopilot-batch-{YYYYMMDD}-{HHMM}" 形式で生成。
バッチサイズ上限5件を超える場合、エラーとして報告。

## Phase 6: リーダーへ完了報告
SendMessage でリーダーに完了を報告:
- 対象Issue数、スキップ数
- 実行順序サマリ
- 検出された競合ペア数
```

---

## 対象Issue取得とスキップ判定（Batch Planning Agent が実行）

**対象Issue取得（2パス方式）:**

```bash
# Pass 1: 軽量一覧取得
gh issue list --repo owner/repo --state open --label "planned" --limit 100 \
  --json number,title,labels \
  -q '.[] | "\(.number)\t\(.title)\t\([.labels[].name] | join(","))"'
```

**スキップ判定:**

| 条件 | 判定方法 |
|------|---------|
| `implementing` ラベル（resume以外） | 別セッションが処理中 |
| `implemented` ラベル | 実装完了済み |
| `implementation-failed` ラベル | 前回バッチで失敗（手動対応待ち） |
| assignee設定済み | 手動作業中 |
| オープンPRが存在 | `gh pr list --search "Issue #{number}"` |
| 実装計画コメントなし | `gh issue view` で `## 実装計画` がない |

