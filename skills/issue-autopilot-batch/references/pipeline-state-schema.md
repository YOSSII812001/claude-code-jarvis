<!-- 抽出元: SKILL.md「パイプライン状態ファイル（必須）」セクション（旧 行198-254）
     + 「ラベル状態機械」セクション（旧 行50-72） -->

# パイプライン状態スキーマ定義

## ラベル状態機械

```
planned -> implementing -> implemented
   ^         |
   +-- (失敗/中断で戻す)
```

| ラベル | 意味 | 種別 | 色 | 付与元 |
|--------|------|------|-----|--------|
| `planned` | 実装計画が作成済み | 状態 | 緑 `#0E8A16` | issue-planner / 手動計画投稿 |
| `implementing` | バッチ実装中 | 状態 | 黄 `#FBCA04` | issue-autopilot-batch |
| `implemented` | 実装完了・E2E通過 | 状態 | 青 `#0075CA` | issue-autopilot-batch |
| `implementation-failed` | 自動実装失敗 | 属性 | 赤 `#D73A4A` | issue-autopilot-batch |
| `regression` | リグレッション検出 | 属性 | 赤 `#B60205` | issue-autopilot-batch |
| `found-during-e2e` | E2E中に発見された既存バグ | 属性 | 橙 `#E4E669` | issue-autopilot-batch |
| `fortress-review-required` | fortress-review 必須 | 属性 | 紫 `#7057FF` | issue-planner（Tier A判定時） |

**ルール**: 状態ラベルは常に1つのみ。属性ラベルは状態ラベルと併用可能。

**fortress-review-required ラベルの管理:**
- issue-planner が Tier A 判定時に付与する
- autopilot-batch のワーカーはこのラベルを検知して実装前に fortress-review を実行する
- fortress-review 完了後もラベルは除去しない（実行済みの証跡として保持）

**重要: `planned` ラベル適用の義務**
Issueに実装計画をコメント投稿した場合、**必ず `gh issue edit <番号> --add-label planned` を実行すること**。
これは `issue-planner` 経由でも手動投稿でも同様。`planned` ラベルがないIssueはバッチ対象から漏れる。

---

## パイプライン状態ファイル（必須）

リーダーのコンテキスト依存を排除するため、状態ファイルを唯一の真実源（Single Source of Truth）として使用。

```json
// tasks/batch-pipeline-state.json
{
  "batch_id": "autopilot-batch-20260303-1200",
  "repo": "owner/repo",
  "execution_order": [11, 14, 13, 15],
  "issues": [
    {
      "number": 11, "title": "Auth API", "phase": "B_completed",
      "pr_number": 45, "branch": "feat/issue-11-auth",
      "tier": "B",
      "tier_score": 8,
      "fortress_review_result": null,
      "changed_files": ["src/auth.ts", "src/api/login.ts"],
      "e2e_result": "PASS", "retry_count": 0,
      "e2e_test_items": ["ログイン画面", "認証API"],
      "e2e_report": {
        "summary": { "total": 3, "passed": 3, "failed": 0, "skipped": 0 },
        "core_operation_tested": true,
        "deploy_verified": true,
        "has_l2_test": true
      },
      "worker_summary": "src/auth.ts のインポート順序を変更。#14との競合注意。",
      "coderabbit_status": "PASS",
      "processed_events": ["phaseA_complete", "coderabbit_checked", "phaseB_e2e_pass"]
    }
  ],
  "context": {
    "error_patterns": [],
    "staging_notes": "",
    "next_action": "#14 merge許可発行 -> #13 ワーカー起動",
    "consecutive_failures": 0
  },
  "current_staging_gate": "none",
  "completed_count": 1, "total_count": 4,
  "discovered_issues": []
}
```

## フィールド説明

| フィールド | 型 | 目的 |
|-----------|-----|------|
| `issues[].worker_summary` | string | ワーカー報告の1行要約。競合注意点・特記事項を記録 |
| `issues[].e2e_report` | object | E2E報告の要約版（summary, core_operation_tested, deploy_verified, has_l2_test）。全体の詳細はtasks/issue-{N}-e2e-report.jsonに保存（トークン節約） |
| `issues[].tier` | string \| null | "A" / "B" / "C" / null。issue-planner-meta から抽出。null は手動計画（メタデータなし）。リーダーはnull時Tier B扱い |
| `issues[].tier_score` | number \| null | Tier判定スコア。null はメタデータなし |
| `issues[].fortress_review_result` | string \| null | "Go" / "No-Go" / "条件付きGo" / "skipped" / null。Tier A Issue のみ設定。null は未実行。"skipped" はタイムアウト等で実行できなかった場合 |
| `issues[].processed_events` | string[] | 冪等性保証。処理済みイベントを記録し、Compaction後の二重処理を防止 |
| `issues[].coderabbit_status` | string | PASS \| FIXED \| TECH_DEBT \| SKIPPED。Phase A完了後のCodeRabbitレビュー結果。未確定のままmergeゲート判定に進めてはならない |
| `issues[].phase2_code_review_status` | string | PASS \| NO_FINDINGS \| SKIPPED \| FAILED |
| `issues[].phase2_code_review_normals` | number | Normal指摘件数 |
| `context.error_patterns` | string[] | E2E・Lint等で発見したパターン（最大5件、古いものはFIFOで押し出し） |
| `context.staging_notes` | string | staging環境の傾向・注意点 |
| `context.next_action` | string | **最重要** -- Compaction後に「次に何をすべきか」を即座に把握 |
| `context.consecutive_failures` | number | 連続失敗カウント（ガードレールB4との連携） |

**更新タイミング**: 各セーフポイント（フェーズA完了時、フェーズB完了時、Issue完了時）で必ず更新。

---

## resumeモードの復元手順

1. `tasks/batch-pipeline-state.json` を読み込む
2. `context.next_action` を確認 -> 次のアクションを即座に把握
3. `context.error_patterns` を確認 -> 蓄積された学習を復元
4. 各 issue の `phase` + `processed_events` を確認 -> 現在位置を特定
5. GitHub実状態照合（ワーカー未応答リカバリ）:
   phase が "A_completed" かつ e2e_result が null のIssueについて:
   `gh pr view` + `gh issue view` でGitHub実状態を確認し、
   全完了済みなら B_completed + e2e_result: "PASS" に自動補正
   （詳細手順: leader-workflow.md Step 7-pre ステップ4 参照）
6. `implementing` ラベルのIssueを特定し、状態ファイルのphaseと照合
7. 当該Issueのphaseに応じて再開（A未完了->フェーズA最初から、A完了->merge許可待機から）
8. 既完了Issueの `worker_summary` + PR番号・変更ファイルをバッチコンテキストとして復元

※ `context` フィールドが存在しない場合（v1 batch からの resume）: context なしで上記2-3をスキップし続行（後方互換性を維持）
