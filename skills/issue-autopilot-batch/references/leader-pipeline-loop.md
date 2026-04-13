# リーダーワークフロー: Step 7（パイプライン実行ループ）

## 7-pre. コンテキスト復元ガード（各イテレーション冒頭、必須）

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

#### GitHub実状態照合の補正テーブル（Issue #1163教訓）

状態ファイルの `phase` が `A_completed` だが、GitHub上でPR merged / Issue closedの場合は自動補正する:

```bash
# PR状態確認
gh pr view <PR番号> --json state --jq '.state'
# Issue状態確認  
gh issue view <番号> --json state --jq '.state'
```

| 状態ファイル | GitHub PR | GitHub Issue | 補正アクション |
|-------------|-----------|-------------|--------------|
| A_completed | MERGED | CLOSED | → B_completed に補正、ラベルを implemented に更新 |
| A_completed | MERGED | OPEN | → Phase B途中。E2E未実施の可能性。Phase Bワーカー再起動 |
| A_completed | OPEN | OPEN | → 正常。Phase B開始待ち |

5. 上記の情報に基づいて処理を継続する

※ Compaction が発生していてもいなくても、この手順は同一。
   1ファイルのみ Read するため、復元コストは ~2,500トークンに抑制。

## 7-pre. サブエージェント遅延時の並行調査（教訓 #1745）

バックグラウンドで起動した調査サブエージェント（Batch Planning Agent、Exploreエージェント等）が**60秒以上**応答しない場合:
- リーダーは応答を待たず、**直接コード読み込み・`gh issue view`等で並行調査**を開始する
- サブエージェントの結果が後から届いた場合は、リーダーの調査結果と統合する
- サブエージェントの完了を待たずに結論を出せるなら先に出す

## 7a. Issue[N] のワーカー起動（フェーズA）

- `implementing` ラベル付与（`--remove-label planned` と同一コマンドで原子的に実行）
- バッチコンテキスト注入: `tasks/batch-pipeline-state.json` から変更ファイル一覧 + `tasks/batch-plan.json` から当該Issueの `conflict_notes`, `e2e_test_hints` を読み取りプロンプトに含める
- **Tier情報注入**: `tasks/batch-plan.json` から当該Issueの `tier`, `tier_score` を読み取りプロンプトに含める
- **レビューレーン数決定**: tier に基づき review_lane_count を算出（C→2, B/A→5, null→5）してプロンプトに含める
- **fortress-review-required ラベル検知**: `gh issue view {number} --json labels --jq '.labels[].name'` で確認。ラベルがある場合、ワーカープロンプトに fortress-review 実行指示を含める
- **batch-plan.json の `conflict_pairs` で検出された競合ファイルがある場合、変更概要（1行サマリ）も注入**

```bash
gh issue edit {number} --repo owner/repo --add-label "implementing" --remove-label "planned"
```

→ ワーカープロンプトテンプレートは `references/worker-prompt-template.md` を参照

## 7b. Issue[N] ワーカーからフェーズA完了報告を受信

- **冪等性チェック**: `processed_events` に `"phaseA_complete"` が含まれていれば -> スキップ
- **クアドレビュー数値ゲート検証（Tier別分母）**:
  1. 当該Issueの `tier` を `batch-plan.json` から確認
  2. 期待分母を算出: Tier C → 2、Tier B/A → 5、null → 5
  3. ワーカー報告の `review_lanes_completed` が `{期待分母}/{期待分母}` であること
  4. `critical_open=0` であること
  5. Phase 1 未達の場合、merge許可を保留しフェーズBに進めない
- **実装計画カバレッジ検証（必須、省略禁止）**:
  1. ワーカーの報告から `plan_steps_covered`（実装したステップ一覧）を確認する
  2. `batch-plan.json` の当該Issueの実装計画ステップ数と照合する
  3. **GitHub APIでの実照合（Issue #1133教訓）**:
     ```bash
     # Issueコメントから計画の全ステップを取得
     gh issue view <番号> --comments
     # PRの変更ファイル一覧を取得
     gh pr diff <PR番号> --name-only
     ```
     各ステップが変更ファイルに対応しているか確認する
  4. **全ステップがカバーされていない場合**: ワーカーに不足ステップを指摘し、追加実装を指示する（merge許可を保留。同一PR or 追加PR）
  5. **「PRマージ = 実装完了」と見なしてはならない**: PRの変更内容が計画の各ステップに対応しているかファイル単位で照合する
  6. 検証結果を状態ファイルに記録: `plan_coverage: "6/6"` or `"2/6 - 不足: Steps 1,4,5,6"`
  - Issue #1133教訓: ワーカーが6ステップ中2ステップしか実装せずPRマージされた。残り4ステップの実装が別PRで必要になった
  > **「PRマージ ≠ 実装完了」**: 計画が6ステップある場合、6ステップ全てがコードに反映されているか確認してから次フェーズに進む
- 状態ファイル更新: phase -> "A_completed", pr_number, changed_files を記録
- `worker_summary` <- ワーカー報告の1行要約（競合注意点・特記事項）
- `processed_events` に `"phaseA_complete"` を追加
- `context.next_action` を更新（例: "#{N} CodeRabbit確認 -> mergeゲート判定 -> 次Issue起動判定"）

## 7b-post. CodeRabbitレビュー確認（Phase A完了直後、必須）

- **冪等性チェック**: `processed_events` に `"coderabbit_checked"` が含まれていれば -> スキップ
- `gh pr checks <PR番号> --watch` でCodeRabbit check完了まで待機
- 完了後 `gh pr view <PR番号> --json comments,reviews` で指摘を収集
- CodeRabbitレビューは **soft gate**、ただし **セキュリティ/バグ指摘は hard block**

**指摘の3分類処理:**

| 分類 | 条件 | アクション | coderabbit_status |
|------|------|----------|-------------------|
| 即時修正（hard block） | セキュリティ、バグ、権限不備、データ破壊、回帰リスク | ワーカーに修正指示。未解消の間はmerge許可を出さない | `"FIXED"` |
| 技術的負債Issue化（soft gate） | リファクタ、保守性、パフォーマンス改善提案 | `gh issue create --label "tech-debt"` で起票 | `"TECH_DEBT"` |
| スキップ（soft gate） | 誤検知、スタイル差、既対応 | スキップ理由を状態ファイルに記録 | `"SKIPPED"` |

- 指摘なしの場合: `coderabbit_status: "PASS"`
- 状態ファイル更新:
  - `issues[N].coderabbit_status` を設定
  - `worker_summary` に CodeRabbit処理結果を追記
  - `processed_events` に `"coderabbit_checked"` を追加
- `coderabbit_status` 未確定のまま mergeゲート判定（7c）に進めてはならない

## 7b-post2. fortress-review 完了確認（Tier A のみ、Step 7b-post 直後）

- **条件**: 当該Issueの tier が "A" の場合のみ実行
- **冪等性チェック**: `processed_events` に `"fortress_review_checked"` が含まれていれば -> スキップ
- **確認内容**: ワーカーのフェーズA完了報告に `fortress_review_result` が含まれていること
- `fortress_review_result == "Go"` or `"条件付きGo"`: OK、mergeゲート判定に進む
- `fortress_review_result == "No-Go"`: merge許可を発行しない。ユーザーにNo-Go報告を提示し判断を仰ぐ
  - ユーザーがリスク受容 → merge許可を発行
  - ユーザーが中止 → 当該Issueを `planned` + `implementation-failed` に戻し、execution_orderから除外
- `fortress_review_result` がない（ワーカーが実行を忘れた場合）: merge許可を保留し、ワーカーにfortress-review実行を指示
- 状態ファイル更新: `issues[N].fortress_review_result` を記録、`processed_events` に `"fortress_review_checked"` を追加

## 7c. staging mergeゲート判定（原子的に実行）

- 前Issue[N-1]のE2Eが通過済み -> Issue[N]にmerge許可トークンを送信
- 前Issue[N-1]のE2Eが未完了 -> 許可保留

## 7d. 次Issue[N+1]のワーカー起動 + バッチコンテキスト更新

1. `tasks/batch-pipeline-state.json` から既変更ファイル一覧を読み取り
2. `tasks/batch-plan.json` から次Issue[N+1]の `conflict_notes`, `e2e_test_hints`, **`tier`, `tier_score`** を読み取り
3. **レビューレーン数決定**: tier に基づき review_lane_count を算出（C→2, B/A→5, null→5）
4. **fortress-review-required ラベル検知**: 次Issueのラベルを確認し、必要ならワーカープロンプトにfortress-review実行指示を含める
5. ワーカープロンプトにバッチコンテキスト（tier/tier_score/review_lane_count含む）として注入
6. E2E失敗でスキップされたIssueの変更ファイルは一覧から除外

→ ワーカープロンプトテンプレートは `references/worker-prompt-template.md` を参照

## 7e. E2E通過通知を受けたら

- **冪等性チェック**: `processed_events` に `"phaseB_e2e_pass"` / `"phaseB_e2e_fail"` が含まれていれば -> スキップ
- **E2E報告ゲート検証（B14ガードレール、8項目）**: → `references/e2e-report-schema.md` を参照
- 状態ファイル更新: phase -> "B_completed", e2e_result, e2e_test_items, **e2e_report（要約版）** を記録
- `worker_summary` を E2E結果で補完（例: "E2E PASS。ログイン->ダッシュボード正常"）
- `processed_events` に `"phaseB_e2e_pass"` / `"phaseB_e2e_fail"` を追加
- `context.error_patterns` に新発見パターンを追記（**上限5件、FIFOで古いものを押し出し**）
- `context.next_action` を更新（例: "#{N} implemented -> #{N+1} merge許可発行"）
- `context.consecutive_failures` を更新（PASS->0にリセット、FAIL->+1加算。ただしPRE-EXISTING/FLAKYは非カウント）
- Issue[N]に `implemented` ラベル付与 + Issueクローズ
- 待機中のIssue[N+1]があればmerge許可トークンを送信

### 7e-post. E2Eリレー出力（Stop Hook自信ゲート発火用、必須）

ワーカーのE2E報告はAgent tool内で完結するため、Stop Hook（confidence_gate_hook.ps1）はサブエージェントのstdoutを監視できない。
リーダーは7eのゲート検証完了後、以下のJSON形式サマリを**自身のassistant message**にプレーンテキストとして出力すること。

**出力テンプレート（そのまま使用、値のみ置換）:**

```
--- E2Eテスト結果リレー（Issue #{番号}） ---
{
  "e2e_result": "{PASS|FAIL}",
  "summary": { "passed": {n}, "failed": {n}, "skipped": {n} },
  "core_operation": { "tested": {true|false} },
  "deploy_verification": { "performed": {true|false} },
  "confidence_gate": {
    "C1": "worker_answered",
    "C2": "worker_answered",
    "C3": "worker_answered",
    "C4": "worker_answered",
    "C5": "worker_answered",
    "C6": "leader_pending"
  }
}
--- E2Eテスト結果リレー終了 ---
```

**スコアリング達成根拠（閾値5、実測13+）:**

| パターン | カテゴリ | スコア | マッチ箇所 |
|---------|---------|--------|-----------|
| `"e2e_result": "PASS"` | A2 | +3 | JSON key + value |
| `"confidence_gate": {` + `"C1"` | A3 | +3 | JSON構造 |
| `"summary": {` + `"passed": N` | A4 | +3 | JSON構造 |
| `"core_operation":` | B3 | +2 | JSON key |
| PASS/FAIL 2回以上 | Cw2 | +1 | e2e_result行 + summary |
| E2E 3回以上 | Cw3 | +1 | 開始行 + key + 終了行 |

**Anti-loop安全性:** JSON形式の `"C1": "worker_answered"` はHookのanti-loop正規表現 `^C([1-6])\s*[:]\s*\{?\s*answer` にマッチしない（行頭が空白+`"`）。`[CONFIDENCE GATE]` マーカーも含まない。

**省略禁止（ガードレールB20）:** このリレー出力がないと、Hookの自信ゲート（C1-C6強制注入）が発火せず、リーダー自身のE2E判定品質が機械的に担保されない。

## 7f. 進捗レポート更新

## 7g. Issue間クールダウン（60秒）

- 各IssueのPR作成後、次のPR作成を伴う処理まで最低60秒空ける（CodeRabbitレート制限回避）
- 差分待機方式: 直前のPR作成から60秒未満なら差分だけ待つ
- 待機中も状態ファイル更新・ログ出力は可。新規PR作成・CodeRabbit待機開始・ワーカー起動は保留

## 7g-post. Compaction検知時のコンテキストリセット推奨

各Issue完了のセーフポイント（7e〜7g 完了後）で以下を確認:

**検知条件**: パイプラインループ中にコンテキストのCompaction（自動圧縮）が発生した場合

**アクション**: 次のイテレーションに進む前に、以下のメッセージをユーザーに出力する:

---
⚠️ コンテキスト圧縮が検知されました。パイプラインの安定性のため、ここで `/clear` + resume を推奨します。

現在の進捗は状態ファイルに保存済みです（完了: {completed_count}/{total_target_count}件）。

👉 次の手順:
1. `/clear` を実行してコンテキストをリセット
2. `/autopilot-batch resume` で再開
---

※ Compactionが発生していない場合はこのメッセージを出さず、そのまま次イテレーションに進む。
※ ユーザーが `/clear` せずに続行を選択した場合はそのまま継続する（強制停止しない）。

## 7h. ワーカーidle検知と自動リカバリ

**idle通知3回ルール（教訓 #1743/#1744）:**
- ワーカーがidle通知（進捗なしメッセージ）を**3回以上連続**送信した場合、コンテキスト飽和と判断する
- 該当ワーカーを破棄し、**新規ワーカーを生成**して未完了フェーズを引き継ぐ
- Phase A idle → 新ワーカーでPhase A再実行（ブランチ/PR存在チェック後）
- Phase B idle → 新ワーカーでPhase B実行（Phase A summary読み込みから開始）

**長期未応答リカバリ:**

検知条件: ワーカーからのフェーズB完了報告が一定時間届かない、またはresume時にA_completed+e2e_result=nullを検出

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
