# E2E報告JSONスキーマ

ワーカーのフェーズB完了時E2E報告で必須のJSON構造。自由テキスト報告は禁止（アンチパターン#21）。

```json
{
  "e2e_result": "PASS | FAIL",
  "test_items": [
    {
      "id": 1, "screen": "設定画面",
      "depth_level": "L2",
      "operation_flow": "スライダー→値変更→保存→再読→値確認",
      "result": "PASS | FAIL | SKIP",
      "skip_reason": null,
      "evidence": "screenshot-1.png",
      "browser_boundary": null
    }
  ],
  "summary": { "total": 5, "passed": 5, "failed": 0, "skipped": 0 },
  "core_operation": {
    "tested": true,
    "description": "キャンセルボタン: disabled=false確認→クリック→API中断確認"
  },
  "deploy_verification": { "performed": true, "dom_matched": true },
  "issue_reproduction": { "tested": true, "resolved": true },
  "console_errors": 0,
  "confidence_gate": {
    "C1": "はい/いいえ — 修正対象の機能を直接操作したか + 具体的操作内容",
    "C2": "はい/いいえ — ユーザーとして使えるか + 確認した操作フロー",
    "C3": "はい/いいえ — 全項目にPASS/FAIL/SKIPが記入されているか",
    "C4": "はい/いいえ — ビルド成功だけで判断していないか + 実動作確認内容",
    "C5": "はい/いいえ — 修正前→後の動作差分を確認したか"
  },
  "change_coverage_map": {
    "path/to/modified-file.js": { "tested_by": [1, 3], "category": "user_facing" },
    "path/to/logger.js": { "tested_by": [], "category": "observability_only" }
  }
}
```

## フィールドルール

- `test_items` に `depth_level: "L2"` が **1件以上必須**（アンチパターン#23）
- `core_operation.tested` が `true` 必須（アンチパターン#22）
- `confidence_gate` の C1〜C5 **全5問回答必須**（アンチパターン#24、ガードレールB16）
- `summary.total == summary.passed + summary.failed + summary.skipped` 必須
- `change_coverage_map` の `category: "user_facing"` エントリは `tested_by` が **空配列不可**（アンチパターン#28）
- `category: "observability_only"` エントリは `tested_by` 空配列を許容（モニタリング/ログ変更はE2Eブロッカーとしない）
- `test_items[].browser_boundary` はブラウザ外操作（ファイルDL・印刷・クリップボード等）の制約に抵触するテスト項目で**必須**。形式: `{ "constraint": "制約内容", "verified_scope": "検証済み範囲", "unverified_scope": "未検証範囲", "workaround_used": "代替手段" }`（Issue #1596教訓）

## リーダーE2E報告ゲート検証（B14ガードレール、8項目）

| CHECK | 検証内容 | 不合格時 |
|-------|---------|---------|
| 1 | summary整合性: total == passed + failed + skipped | ワーカーに差し戻し |
| 2 | core_operation.tested == true | ワーカーに差し戻し |
| 3 | SKIP項目にskip_reason必須 | ワーカーに差し戻し |
| 4 | L2テストが1件以上存在 | ワーカーに差し戻し |
| 5 | deploy_verification.performed == true | ワーカーに差し戻し |
| 6 | issue_reproduction.tested == true | ワーカーに差し戻し |
| 7 | `change_coverage_map` 存在 + `user_facing` の `tested_by` が空配列でない | ワーカーに差し戻し |
| 8 | ブラウザ外操作を含むテストで `browser_boundary` が記載されているか | ワーカーに差し戻し |

不合格時: ワーカーに不足項目を指摘し再テスト指示。e2e_resultは記録しない。
