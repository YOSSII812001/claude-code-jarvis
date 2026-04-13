# リーダーワークフロー: Step 1-6（計画フェーズ）

## Step 1: 入力解析 + resumeチェック

入力形式を解析し、resumeモードか新規バッチかを判定。

- **resumeモード**:
  1. `tasks/batch-pipeline-state.json` を読み込む
  2. `context.next_action` を確認 -> 次のアクションを把握
  3. `context.error_patterns` を確認 -> 蓄積された学習を復元
  4. 各 issue の `phase` + `processed_events` を確認 -> 現在位置を特定
  5. -> Step 7 へ直行（コンテキスト復元ガード経由）
  ※ `context` フィールドが存在しない場合（v1 batch からの resume）: context なしで続行（後方互換性を維持）
- **新規バッチ**: 入力形式（Issue番号リスト / all-planned / milestone）を記録 -> Step 2 へ

## Step 2: Batch Planning Agent 起動

サブエージェント（general-purpose）を起動し、Issue分析・計画策定を委任。
リーダーのコンテキストにIssue詳細や実装計画コメントを読み込まない。

```
Agent tool 起動:
  subagent_type: general-purpose
  prompt: 「Batch Planning Agent プロンプトテンプレート」（references/batch-planning-agent.md）
  （入力形式・リポジトリ・project_dir をプレースホルダに埋めて渡す）
```

サブエージェント完了後、`tasks/batch-plan.json` が生成される -> Step 3 へ

## Step 3: batch-plan.json 読み取り + バリデーション

1. `tasks/batch-plan.json` の存在確認
2. JSON読み取り + 必須フィールド検証:
   - `execution_order` が空でないこと
   - `issues` 配列の各要素に `number`, `title`, `has_plan_comment` が存在すること
   - `total_target_count` がバッチサイズ上限5件以内であること
   - **`issues` 配列の各要素に `tier` フィールドが存在すること（null は許容 = 手動計画）**
   - **`tier` が非null の場合、値が "A", "B", "C" のいずれかであること**
   - **Tier A Issueに対し、GitHub上で `fortress-review-required` ラベルが付与されていることを確認**
3. バリデーション失敗時はエラー報告して停止

結果をユーザーに報告:
```
バッチ対象分析（Batch Planning Agent 出力）:
  対象: X件（#11, #13, #14, #15）
  実行順序: #11 -> #14 -> #13 -> #15
  スキップ: Y件（#12: implementing, #16: PRあり）
  ファイル競合: {conflict_pairs の件数}件検出
```

## Step 4: （欠番 -- Step 3 に統合）

## Step 5: ユーザーに実行計画を提示

`tasks/batch-plan.json` の `execution_order`, `issues`, `conflict_pairs` を元に計画を提示。

**推定所要時間の算出（教訓 #4）:**
```
fix件数 = Issueタイトルに "fix" / "バグ" / "修正" を含む件数
feat件数 = 上記以外（feat / 新機能 / 追加 / 改善）
推定時間 = (fix件数 + feat件数) × 13分 + feat件数 × 5分 + 統合回帰テスト15分

例: fix 4件 + feat 1件 = 5×13 + 1×5 + 15 = 85分（実績66分、余裕込み）
```

提示フォーマットにTier情報と推定時間を含める:
```
バッチ対象分析:
  対象: X件（fix Y件 + feat Z件）
  実行順序: #A(Tier C) -> #B(Tier B) -> #C(Tier A)
  Tier A（fortress-review対象）: #C
  推定所要時間: 約XX分（Tier C ~9分, Tier B ~13分, Tier A ~18分）
  ⚠️ Tier A Issue #C は fortress-review を実装前に自動実行します
  ⚠️ feat #B は影響範囲が広いためE2Eテスト深度を強化します
```

## Step 6: チーム作成 + タスク作成 + 状態ファイル初期化

→ 状態初期化の具体的仕様は `references/leader-core-invariants.md` を参照

### Step 6 完了後

状態ファイル初期化完了を確認し、そのまま Step 7（パイプライン実行ループ）へ進む。
