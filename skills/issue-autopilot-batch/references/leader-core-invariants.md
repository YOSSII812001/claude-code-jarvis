# リーダー横断的ルール（ASSERT_NEXT + 状態初期化）

## ASSERT_NEXT（自動継続アサーション）

**定義**: ASSERT_NEXT句のあるStepは、完了後に即時次Stepを実行する義務がある。途中停止は**アンチパターン#20違反**。

```
[Step N 完了] → ASSERT_NEXT: "Step N+1: {具体的アクション}"
               → 即時実行（停止禁止）
               → 停止 = アンチパターン#20違反 + ガードレールB15違反
```

**最重要区間（完了感バイアスの危険区間）:**
```
Step 10a 承認受信
  → ASSERT_NEXT: "10b-1: gh pr merge"
  → ASSERT_NEXT: "10b-2: vercel-watch Production"
  → ASSERT_NEXT: "10b-3: 2段階デプロイ確認"
  → ASSERT_NEXT: "10c: 本番E2E確認"
  → ASSERT_NEXT: "Step 11: 完了報告 + TeamDelete"
この区間は途中停止一切不可。
```

---

## 状態ファイル初期化仕様（Step 6）

```
TeamCreate -> TaskCreate（各Issue分） -> tasks/batch-pipeline-state.json 初期化
初期化時に batch-plan.json の execution_order, issues（number, title, branch_hint,
conflict_notes, e2e_test_hints）を batch-pipeline-state.json にコピー。

各 issue に以下の初期値を設定:
  worker_summary: ""（空文字列）
  processed_events: []（空配列）

context オブジェクトの初期値:
  error_patterns: []
  staging_notes: ""
  next_action: "#{最初のIssue番号} ワーカー起動（フェーズA）"
  consecutive_failures: 0
```

→ 初期化完了後、そのまま Step 7 へ進む
