<!-- 抽出元: SKILL.md「Issue Scanner Agent」セクション（旧 行66-200） -->

# Issue Scanner Agent の詳細

## 概要

リーダーのコンテキスト汚染を防ぐため、Issue一覧取得・スキップ判定・ワーカー数算出をサブエージェントに委任する。

## 中間出力: `tasks/issue-scan.json`

Issue Scanner Agent が書き出すスキャン結果。リーダーは Read で読み取るのみ。

```json
{
  "scan_id": "issue-planner-YYYYMMDD-HHMM",
  "repo": "owner/repo",
  "project_dir": "C:/Users/zooyo/Documents/GitHub/DX/...",
  "target_issues": [
    { "number": 42, "title": "ログイン画面のレスポンシブ対応" }
  ],
  "skipped_issues": [
    { "number": 38, "reason": "planned ラベル済", "title": "認証API改修" },
    { "number": 40, "reason": "計画コメント済（ラベル補完実施）", "title": "通知機能追加" }
  ],
  "labels_created": [],
  "labels_補完_applied": [40],
  "total_open_count": 19,
  "total_target_count": 2,
  "total_skipped_count": 17,
  "recommended_worker_count": 1
}
```

**設計判断**:
- `target_issues` に body を含めない（ワーカーが Step 2 で `gh issue view` で取得するため不要）
- `recommended_worker_count` を含める（リーダーが動的ワーカー数テーブルの判定を実行する必要をなくす）

## Issue Scanner Agent プロンプトテンプレート

リーダーが Agent tool でスポーンする際のプロンプト（subagent_type: general-purpose）:

```
あなたは issue-planner の Issue Scanner Agent です。
リポジトリの全オープンIssueをスキャンし、計画対象のIssueを特定して JSON ファイルに出力します。

## 環境情報
- リポジトリ: {owner}/{repo}
- プロジェクトディレクトリ: {project_dir}
- Windows環境、Bash使用

## Phase 0: ラベル準備

`planned` ラベルの存在を確認し、なければ作成する。

```bash
gh label list --repo {owner}/{repo} --search "planned" --json name -q '.[].name'

# なければ作成（緑色）
gh label create "planned" --repo {owner}/{repo} --color "0E8A16" --description "実装計画が作成済み"
```

## Phase 1: Issue一覧取得（軽量ラベルフィルタ）

**重要: `--json` に comments や body を含めないこと（JSON肥大化防止）。**

```bash
gh issue list --repo {owner}/{repo} --state open --limit 200 \
  --json number,title,labels \
  -q '.[] | "\(.number)\t\(.title)\t\([.labels[].name] | join(","))"'
```

`planned` ラベル付きIssueをスキップ対象に振り分ける。

## Phase 2: 個別コメントチェック（ラベルなしIssueのみ）

```bash
for num in {残りのIssue番号}; do
  has_plan=$(gh issue view $num --repo {owner}/{repo} --json comments \
    -q '[.comments[].body] | map(select(contains("## 実装計画") or contains("## Implementation Plan"))) | length')
  if [ "$has_plan" -gt 0 ] 2>/dev/null; then
    echo "SKIP #$num (計画コメント済)"
  else
    echo "TARGET #$num"
  fi
done
```

### Phase 2b: ラベル補完

計画コメント済みだがラベルなしのIssueに `planned` ラベルを追加する。

```bash
for num in {計画コメント済みのIssue番号}; do
  gh issue edit $num --repo {owner}/{repo} --add-label "planned"
done
```

## Phase 3: ワーカー数決定

動的ワーカー数テーブルに従い recommended_worker_count を算出する。

| 未計画Issue数 | ワーカー数 |
|:---:|:---:|
| 0 | 0（処理終了） |
| 1〜5 | 1 |
| 6〜12 | 2 |
| 13+ | 3 |

## Phase 4: issue-scan.json 書き出し

Write ツールで {project_dir}/tasks/issue-scan.json に結果を書き出す（Bash の echo/cat は使用しない）。

スキーマ:
```json
{
  "scan_id": "issue-planner-{YYYYMMDD}-{HHMM}",
  "repo": "{owner}/{repo}",
  "project_dir": "{project_dir}",
  "target_issues": [{ "number": N, "title": "..." }],
  "skipped_issues": [{ "number": N, "reason": "...", "title": "..." }],
  "labels_created": ["planned"],
  "labels_補完_applied": [N],
  "total_open_count": N,
  "total_target_count": N,
  "total_skipped_count": N,
  "recommended_worker_count": N
}
```

## Phase 5: 完了報告

SendMessage でリーダーに完了を報告する:
「Issue スキャン完了: 対象 {total_target_count}件, スキップ {total_skipped_count}件, 推奨ワーカー数 {recommended_worker_count}」

## 注意事項
- `gh issue list --json` に comments や body を含めないこと
- ユーザーに直接質問しないこと（問題があればリーダーにSendMessage）
- gh コマンドには必ず --repo {owner}/{repo} を付けること
```
