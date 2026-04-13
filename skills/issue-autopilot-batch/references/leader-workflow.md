<!-- 抽出元: SKILL.md「リーダーワークフロー（12ステップ）」セクション（旧 行349-611） -->

# リーダーワークフロー（12ステップ）

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
  prompt: 上記「Batch Planning Agent プロンプトテンプレート」セクションの内容
  （入力形式・リポジトリ・project_dir をプレースホルダに埋めて渡す）
```

サブエージェント完了後、`tasks/batch-plan.json` が生成される -> Step 3 へ

## Step 3: batch-plan.json 読み取り + バリデーション

1. `tasks/batch-plan.json` の存在確認
2. JSON読み取り + 必須フィールド検証:
   - `execution_order` が空でないこと
   - `issues` 配列の各要素に `number`, `title`, `has_plan_comment` が存在すること
   - `total_target_count` がバッチサイズ上限5件以内であること
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

提示フォーマットに推定時間を含める:
```
バッチ対象分析:
  対象: X件（fix Y件 + feat Z件）
  実行順序: #A -> #B -> #C
  推定所要時間: 約XX分（実績ベース: 5 Issue/hour）
  ⚠️ feat #C は影響範囲が広いためE2Eテスト深度を強化します
```

## Step 6: チーム作成 + タスク作成 + 状態ファイル初期化

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

## Step 7: パイプライン実行ループ

**7-pre. コンテキスト復元ガード（各イテレーション冒頭、必須）**

パイプラインループの各イテレーション開始時:
1. `tasks/batch-pipeline-state.json` を Read する
2. `context.next_action` を確認し、次のアクションを把握する
3. 各 issue の `phase` と `processed_events` を確認し、現在位置を特定
4. GitHub実状態照合（ワーカー未応答リカバリ）:
   phase が "A_completed" かつ e2e_result が null のIssueについて:
   a. `gh pr view <PR番号> --json state,mergedAt` → MERGED なら staging merge 完了
   b. `gh issue view <番号> --json state` → CLOSED なら Issue close 完了
   c. 両方 true → 状態ファイルを B_completed + e2e_result: "PASS" に補正
   d. Issueコメントから E2E結果を抽出して worker_summary を補完
   e. processed_events に "phaseB_e2e_pass" を追加
   f. ラベルを implementing → implemented に更新、completed_count をインクリメント
   g. ログ出力: 「Issue #{番号}: ワーカー未応答 -- GitHub実状態から B_completed に自動補正」
5. 上記の情報に基づいて処理を継続する

※ Compaction が発生していてもいなくても、この手順は同一。
   1ファイルのみ Read するため、復元コストは ~2,500トークンに抑制。

**7a. Issue[N] のワーカー起動（フェーズA）**
- `implementing` ラベル付与（`--remove-label planned` と同一コマンドで原子的に実行）
- バッチコンテキスト注入: `tasks/batch-pipeline-state.json` から変更ファイル一覧 + `tasks/batch-plan.json` から当該Issueの `conflict_notes`, `e2e_test_hints` を読み取りプロンプトに含める
- **batch-plan.json の `conflict_pairs` で検出された競合ファイルがある場合、変更概要（1行サマリ）も注入**

```bash
gh issue edit {number} --repo owner/repo --add-label "implementing" --remove-label "planned"
```

**7b. Issue[N] ワーカーからフェーズA完了報告を受信**
- **冪等性チェック**: `processed_events` に `"phaseA_complete"` が含まれていれば -> スキップ
- **実装計画カバレッジ検証（必須、省略禁止）**:
  1. ワーカーの報告から `plan_steps_covered`（実装したステップ一覧）を確認する
  2. `batch-plan.json` の当該Issueの実装計画ステップ数と照合する
  3. **全ステップがカバーされていない場合**: ワーカーに不足ステップを指摘し、追加実装を指示する（merge許可を保留）
  4. **「PRマージ = 実装完了」と見なしてはならない**: PRの変更内容が計画の各ステップに対応しているかファイル単位で照合する
  5. 検証結果を状態ファイルに記録: `plan_coverage: "6/6"` or `"2/6 - 不足: Steps 1,4,5,6"`
  5. `phase2_code_review_status` を確認（PASS/NO_FINDINGS が理想、SKIPPED/FAILED も許容）
  - Issue #1133教訓: ワーカーが6ステップ中2ステップしか実装せずPRマージされた。残り4ステップの実装が別PRで必要になった
- 状態ファイル更新: phase -> "A_completed", pr_number, changed_files を記録
- `worker_summary` <- ワーカー報告の1行要約（競合注意点・特記事項）
- `processed_events` に `"phaseA_complete"` を追加
- `context.next_action` を更新（例: "#{N} mergeゲート判定 -> 次Issue起動判定"）

**7c. staging mergeゲート判定（原子的に実行）:**
- 前Issue[N-1]のE2Eが通過済み -> Issue[N]にmerge許可トークンを送信
- 前Issue[N-1]のE2Eが未完了 -> 許可保留

**7d. 次Issue[N+1]のワーカー起動 + バッチコンテキスト更新**
1. `tasks/batch-pipeline-state.json` から既変更ファイル一覧を読み取り
2. `tasks/batch-plan.json` から次Issue[N+1]の `conflict_notes`, `e2e_test_hints` を読み取り
3. ワーカープロンプトにバッチコンテキストとして注入
4. E2E失敗でスキップされたIssueの変更ファイルは一覧から除外

**7e. E2E通過通知を受けたら:**
- **冪等性チェック**: `processed_events` に `"phaseB_e2e_pass"` / `"phaseB_e2e_fail"` が含まれていれば -> スキップ
- **E2E報告ゲート検証（B14ガードレール、7項目）:**

  | CHECK | 検証内容 | 不合格時 |
  |-------|---------|---------|
  | 1 | summary整合性: total == passed + failed + skipped | ワーカーに差し戻し |
  | 2 | core_operation.tested == true | ワーカーに差し戻し |
  | 3 | SKIP項目にskip_reason必須 | ワーカーに差し戻し |
  | 4 | L2テストが1件以上存在 | ワーカーに差し戻し |
  | 5 | deploy_verification.performed == true | ワーカーに差し戻し |
  | 6 | issue_reproduction.tested == true | ワーカーに差し戻し |
  | 7 | ブラウザ外操作を含むテストで `browser_boundary` が記載されているか | ワーカーに差し戻し |

  不合格時: ワーカーに不足項目を指摘し再テスト指示。e2e_resultは記録しない。
- 状態ファイル更新: phase -> "B_completed", e2e_result, e2e_test_items, **e2e_report（要約版）** を記録
- `worker_summary` を E2E結果で補完（例: "E2E PASS。ログイン->ダッシュボード正常"）
- `processed_events` に `"phaseB_e2e_pass"` / `"phaseB_e2e_fail"` を追加
- `context.error_patterns` に新発見パターンを追記（**上限5件、FIFOで古いものを押し出し**）
- `context.next_action` を更新（例: "#{N} implemented -> #{N+1} merge許可発行"）
- `context.consecutive_failures` を更新（PASS->0にリセット、FAIL->+1加算。ただしPRE-EXISTING/FLAKYは非カウント）
- Issue[N]に `implemented` ラベル付与 + Issueクローズ
- 待機中のIssue[N+1]があればmerge許可トークンを送信

**7f. 進捗レポート更新**

**7g. Issue間クールダウン（30秒）**

**7h. ワーカー未応答リカバリ（検知条件: ワーカーからのフェーズB完了報告が一定時間届かない、またはresume時にA_completed+e2e_result=nullを検出）**

リカバリ3分岐パターン:

1. **PR merged + Issue closed（全完了）**:
   - ワーカーがPhase B全工程を完了したが報告のみ未送信
   - 状態ファイルを B_completed + e2e_result: "PASS" に補正
   - processed_events に "phaseB_e2e_pass" を追加
   - ラベルを implementing → implemented に更新
   - completed_count をインクリメント
   - 次Issue の merge許可トークンを発行 -> パイプライン継続

2. **PR merged + Issue open（E2E結果不明）**:
   - staging mergeは完了したがE2E結果が不明
   - Issueコメントに E2E結果が記録されていれば、その結果に従って処理
   - E2E結果が見つからなければ、新ワーカーでE2Eテストから再実行（Step 14以降）

3. **PR not merged（フェーズB未開始/途中）**:
   - 既存の冪等リカバリ手順を適用（ブランチ/PR存在確認 -> 未完了ステップのみ再実行）

## Step 8: 全Issue完了サマリ

## Step 8.5: バッチ統合回帰テスト（main PR作成前、必須）

**目的**: 全Issueの変更が統合された状態でのリグレッション検出。

**実行条件**: 完了Issue数が2件以上の場合に必須。1件のみはスキップ可。

**テスト範囲:**
1. 全完了Issueの主要E2Eテスト項目を統合（状態ファイルの `e2e_test_items` から収集）
2. プロジェクトのスモークテスト（ログイン->ダッシュボード->主要機能の動作確認）
3. コンソールエラー0件確認

**回帰テスト品質基準（教訓 #10 + #4 + batch-20260304教訓）:**
- 統合回帰テストは個別E2Eの代替ではない
- 状態ファイルの `e2e_test_items` を全件テストする（各Issueの主要テスト項目を機械的に収集）
- 「表示確認のみ」は回帰テストの最低ライン。各Issueの修正対象操作を最低1つ実際に操作で再現する
- UI表示修正のテストでは必ずスクリーンショットで視覚確認する（snapshotテキストのみ不可）
- サブエージェント並列実行を活用してスループットを上げる
- **feat Issue は回帰テストで重点対象とする（教訓 #4）**: feat は影響範囲が広いため、個別E2Eで通過していても統合時にリグレッションが発生しやすい。feat の変更ファイルと共通ファイルを持つ他Issueの機能を優先的にテストする

**失敗時:**
- 失敗箇所の原因Issueを特定（状態ファイルの changed_files と照合）
- 当該IssueのPRをrevert -> staging安定化 -> 再テスト
- staging->main PR作成は回帰テスト通過後にのみ実行

**Step 8.7: CodeRabbitレビュー指摘の棚卸し（回帰テスト通過後）**
全PRのCodeRabbitコメントを収集し、3分類で処理:
1. **即時修正**: バグ・セキュリティ指摘 -> その場で修正コミット
2. **技術的負債Issue**: リファクタ・パフォーマンス改善提案 -> `gh issue create --label "tech-debt"` で起票
3. **無視**: 誤検知・スタイル好みの差異 -> スキップ（理由を状態ファイルに記録）

**Step 8.8: changelog.ts 更新（Release PR作成前、必須）**

> **教訓（autopilot-batch-20260307）**: changelog更新をRelease PR作成後やマージ後に行うと、PRに含まれずmainに追加コミットが発生する。Release PR作成前にstagingで更新・コミットすること。

1. サブエージェントにchangelog更新を委任:
   ```bash
   Agent tool (subagent_type: general-purpose):
     "git diff staging...HEAD の変更内容をもとに frontend/src/data/changelog.ts を更新してください"
   ```
2. バッチで完了した全Issueの変更内容を `changelog.ts` に追記する
3. 日付・バージョン・各Issueのタイトルと変更概要を記載
4. stagingブランチにコミット・プッシュ
5. **この更新がRelease PRに含まれることを確認してから** Step 9 に進む

## Step 9: staging->main マージPR作成

**Release PR承認依頼の明示的報告（batch-20260305教訓）:**
バッチ完了時にRelease PRの状態を必ずユーザーに明示的に報告する:
```
Release PR #XXXX を作成しました。マージ承認をお願いします。
URL: https://github.com/owner/repo/pull/XXXX
```
「PR作成しました」だけで止まらず、マージ承認依頼を含めること。

```bash
gh pr create --base main --head staging \
  --title "Release: バッチ実装 (#11, #14, #15)" \
  --body "$(cat <<'EOF'
## Summary
- Issue #11: Auth API（E2E PASS）
- Issue #14: Dashboard（E2E PASS）
- Issue #15: Reports（E2E PASS）

## Test plan
- [x] 各Issue個別E2Eテスト完了
- [x] バッチ統合回帰テスト完了
- [ ] 本番デプロイ後の動作確認

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Step 10: ユーザーにmainマージ承認を依頼 -> 承認後の自動継続

**10a. ユーザーに承認依頼（詳細メッセージ必須）:**
```
Release PR #XX のマージ承認をお願いします。
- 含まれるIssue: #A, #B, #C（全件E2E PASS）
- 統合回帰テスト: PASS
- CodeRabbitレビュー棚卸し: 完了（技術的負債Issue N件起票済み）
承認後、mainマージ -> 本番デプロイ監視 -> 本番E2E確認まで自動継続します。
```
→ ASSERT_NEXT: "10b-1: gh pr merge（承認受信後、即時実行）"

**10b. ユーザー承認後、以下を途中停止せずに自動継続（必須・ASSERT_NEXT連鎖区間）:**

> **アンチパターン（禁止）**: mainマージ完了をユーザーに報告して止まる。
> ユーザーが「mainデプロイ完了」と手動で伝えるまで待つ。
> vercel-watchをバックグラウンドで起動したまま完了報告する。

```bash
# 10b-1: mainにマージ（--merge推奨、squashは重複リスクあり）
gh pr merge <PR番号> --merge
# → ASSERT_NEXT: "10b-2: vercel-watch Production"

# 10b-2: vercel-watch で本番デプロイ完了を監視（フォアグラウンド同期待機）
# run_in_background: true, timeout: 360000 で起動し、TaskOutput通知を待つ
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" \
  -WaitForReady -Environment Production -Interval 10
# → ASSERT_NEXT: "10b-3: 2段階デプロイ確認"

# 10b-3: 2段階デプロイの確認（重要: MEMORY.md「Vercel本番デプロイの2段階構造」参照）
# vercel-watchのReady検知後、robbits0802のProductionデプロイがReadyか確認
vercel ls digital-management-consulting-app --yes 2>&1 | head -10
# -> robbits0802 ユーザーの Production デプロイが Ready でない場合、追加待機
# → ASSERT_NEXT: "10c: 本番E2E確認"
```

**10c. 本番E2E確認（スモークテスト）:** → ASSERT_NEXT: "Step 11: 完了報告 + TeamDelete"

vercel-watch Ready検知 + robbits0802デプロイ確認後、自動で本番確認を実行:

```
1. https://usacon-ai.com にアクセス（Playwright MCP）
2. ログイン -> ダッシュボード表示確認
3. バッチで実装した各機能の動作確認（状態ファイルの e2e_test_items から主要項目を抽出）
4. コンソールエラー0件確認
5. 結果をユーザーに報告
```

**本番E2E確認の範囲:** バッチ統合回帰テスト（Step 8.5）の簡易版。
各Issueの主要機能が本番で正常に動作することを確認する。全項目の再テストは不要。

> **バッチ完了定義**: 本番E2E確認PASSをもってバッチ完了。Release PR承認依頼で止まらず、
> mainマージ -> 本番デプロイ監視 -> 本番E2E確認 -> 完了報告まで一気通貫で実行すること。

## Step 11: 完了報告 + チームシャットダウン + TeamDelete

**11a. ユーザーへの完了報告:**
```
バッチ実装完了レポート:
- 実装完了Issue: X件
- 本番デプロイ: 完了（vercel-watch確認済み）
- 本番E2E確認: PASS/FAIL
- 発見不具合: N件（Issue起票済み）
```

**11b. チームシャットダウン + TeamDelete**

## Step 12: クリーンアップ

**12a. 状態ファイルアーカイブ:**
完了した状態ファイルを `tasks/batch-archive/` に移動（次回バッチとの混同防止）。

**12b. ブランチクリーンアップ + ワーキングディレクトリ復帰:**
```bash
# mainブランチに復帰（featureブランチに留まる問題を防止）
git checkout main
git pull origin main

# バッチで作成したマージ済みブランチを削除
git branch --merged main | grep -E "feat/issue-" | xargs -r git branch -d
```
> **注意**: バッチ完了後にfeatureブランチに留まったまま次の作業を開始すると、意図しないブランチで作業する事故が起きる。

- **ブランチ復帰（必須）**: バッチ完了後に `git checkout staging` を実行し、featureブランチに留まらないようにする（batch-20260305教訓: 最後のfeatureブランチに留まったまま次回作業を開始するリスク）

---

## 進捗レポートフォーマット

```
バッチ実装進捗レポート（パイプライン方式）

| # | Issue | タイトル | 工数 | フェーズ | ステータス | PR |
|---|-------|---------|------|---------|----------|-----|
| 1 | #11   | Auth API | M   | B完了   | E2E PASS | #45 |
| 2 | #14   | Dashboard | S  | B実行中 | E2E中   | #46 |
| 3 | #13   | Payment  | L   | A実行中 | 実装中   | -   |
| 4 | #15   | Reports  | S   | -       | 待機     | -   |

経過時間: 45分 | 完了: 1/4 | 発見不具合: 0件
```

---

