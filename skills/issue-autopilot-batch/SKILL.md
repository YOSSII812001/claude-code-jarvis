---
name: issue-autopilot-batch
description: |
  planned ラベル付きIssueを順次自律実装するバッチパイプライン。
  issue-plannerの出力を入力として、各Issueをissue-flowの品質基準で
  順次実装し、stagingの安定性を保ちながらバッチ処理する。
  トリガー: "issue-autopilot-batch", "バッチ実装", "一括実装", "全issue実装",
  "planned issues実装", "バッチオートパイロット", "一括オートパイロット"
  使用場面: (1) planned済みIssueの順次自律実装、(2) スプリントバックログの一括消化、
  (3) マイルストーン内Issueの集中処理、(4) issue-plannerの後続パイプライン
---

# Issue Autopilot Batch スキル

## 概要

`planned` ラベル付きIssueを**パイプライン逐次実行**で自律実装するバッチスキル。
issue-planner（計画） -> **issue-autopilot-batch（一括実装）** -> staging安定 -> main PR の流れ。

```
planned Issue群 -> 順序決定 -> [フェーズA: 実装~レビュー | フェーズB: staging~E2E] -> 回帰テスト -> main PR
                              パイプライン: E2E待ち時間に次Issueの実装を開始
```

### パフォーマンス参考値

| 指標 | 実績値 | 備考 |
|------|--------|------|
| バッチスループット | 5 Issue/hour | fix 4件 + feat 1件で約66分 |
| 個別Issue平均 | 約13分/Issue | PR作成〜stagingマージ |
| ボトルネック | E2Eテスト・デプロイ待ち | パイプライン並列で吸収 |

**Tier別処理時間の差異:**

| Tier | レビューレーン数 | 個別Issue平均 | 備考 |
|------|----------------|-------------|------|
| C (< 6) | 2レーン | 約9分/Issue | 低リスク: Codex + 仕様準拠のみ |
| B (>= 6) | 5レーン | 約13分/Issue | 現行基準（変更なし） |
| A (>= 12) | 5レーン + fortress-review | 約18分/Issue | 実装前にfortress-review（約5分追加） |

**Issue種別による品質検証差異（教訓 #4）:**

| 種別 | 実装時間 | E2E深度 | 理由 |
|------|---------|---------|------|
| fix（バグ修正） | ~13分 | 標準（修正対象操作の直接テスト） | 影響範囲が限定的 |
| feat（新機能） | ~13分（実装は同等） | **深度強化**（既存機能との統合テスト追加） | 影響範囲が広く、リグレッションリスクが高い |

- featはfixと同等時間で実装完了するが、**E2Eテストでは既存機能への影響を追加確認**すること
- Step 5の推定所要時間 = `Issue数 × 13分 + feat件数 × 5分（追加検証）+ 統合回帰テスト15分`

## トリガー条件

- `/autopilot-batch` コマンド
- 「バッチ実装」「一括実装」「全issue実装」等のキーワード
- issue-planner 完了後の後続パイプラインとして

## 入力形式

| 形式 | 例 | 説明 |
|------|-----|------|
| Issue番号リスト | `/autopilot-batch #10 #11 #12` | 指定Issueのみ実装 |
| planned全件 | `/autopilot-batch all-planned` | planned全件を自動取得 |
| マイルストーン | `/autopilot-batch milestone:v2.0` | 特定マイルストーン内のplanned |
| 中断再開 | `/autopilot-batch resume` | 状態ファイルから再開 |

**バッチサイズ制限: 1バッチ最大5 Issue**（コンテキスト飽和防止）。超える場合はバッチを分割。

### resume再開テンプレート

パイプラインが中断した場合（Step 6完了後）、以下の定型コマンドで再開する:

```text
/autopilot-batch resume
```

**再開時に自動実行される手順:**
1. `tasks/batch-pipeline-state.json` を読み込み、最後のセーフポイントを特定
2. GitHub実状態（PR・Issue・ラベル）との照合で状態ファイルを補正
3. `context.next_action` に基づき、該当Stepから再開

**中断時の記録ルール:**
- 中断可能なワークフローでは、状態ファイルの `context.next_action` に「次に打つコマンド」を定型文で残すこと
- 例: `"next_action": "PHASE_B_E2E for #1234"` / `"next_action": "MERGE_GATE_CHECK for #1235"`
- resume時はこのフィールドのみで復元判断が可能な粒度で記録する

## プロジェクトディレクトリの推定

MEMORY.md の「プロジェクトパス」セクションからリポジトリに対応するローカルディレクトリを特定する。

---

## 核心ルール（18項目）

### 1. フェーズA/B分離（パイプラインの要）
- **フェーズA**（staging不要）: 実装 -> lint -> build -> PR作成 -> クアドレビュー
- **フェーズB**（staging依存）: staging merge -> deploy -> E2E -> Issueクローズ
- フェーズA並列は最大1つ。フェーズBは同時に1つのみ

### 2. ラベル状態機械
- `planned` -> `implementing` -> `implemented`（状態ラベルは常に1つのみ）
- 失敗/中断時は `planned` + `implementation-failed` に戻す
- 詳細: references/pipeline-state-schema.md

### 3. 状態ファイル = 唯一の真実源
- `tasks/batch-pipeline-state.json` がSingle Source of Truth
- 各セーフポイントで必ず更新。resumeはこのファイルのみで復元
- ※ ワーカー未応答時はGitHub実状態との照合で状態ファイルを補正（B11ガードレール）
- 詳細: references/pipeline-state-schema.md

### 4. コンテキスト復元ガード（B11ガードレール）
- パイプラインループ各イテレーション冒頭で `batch-pipeline-state.json` を必ずRead
- `context.next_action` で次のアクションを把握
- A_completed かつ e2e_result=null のIssueに対しGitHub実状態を照合し、ワーカー未応答時は自動補正
- Compaction発生有無に関わらず同一手順

### 5. mergeゲートの原子性
- 前IssueのE2E通過後にのみ次Issueのstaging mergeを許可
- 1 Issue に対し1回限りのmerge許可トークン（再利用不可）

### 6. 実装計画カバレッジ検証（必須）
- ワーカーのフェーズA完了報告で `plan_steps_covered` を確認
- 全ステップがカバーされていない場合、追加実装を指示（merge許可保留）
- 「PRマージ = 実装完了」と見なしてはならない

### 7. 冪等性保証（B13ガードレール）
- `processed_events` で処理済みイベントを記録
- ワーカー報告処理前に必ず確認し、二重処理を防止

### 8. E2E不具合分類
- REQUIREMENT / REGRESSION / PRE-EXISTING / FLAKY-INFRA の4種別で判定
- PRE-EXISTING/FLAKYは連続失敗カウントに加算しない
- 詳細: references/e2e-defect-classification.md

### 9. Batch Planning Agentへの委任
- リーダーはIssue詳細/実装計画を直接読まない（コンテキスト汚染防止）
- サブエージェントに委任し、`tasks/batch-plan.json` 経由で受け取る
- 詳細: references/batch-planning-agent.md

### 10. バッチ完了定義
- 本番E2E確認PASSをもってバッチ完了
- Release PR承認依頼で止まらず、mainマージ -> デプロイ監視 -> 本番E2E -> 完了報告まで一気通貫

### 11. E2E報告構造化必須
- ワーカーのフェーズB E2E報告はJSON構造化スキーマ必須（自由テキスト禁止）
- リーダーはE2E報告ゲート検証（8項目）をクリアしない限りimplement完了としない
- **リーダーはワーカーE2E報告受領時に「このIssueのコアオペレーション（修正/追加した機能そのもの）を直接テストしたか？」を必ず自問する**（回帰テスト+デプロイ確認だけでPASS判定していないか？ #1679, #1682教訓）
- 実行困難なシナリオ（300秒超タイムアウト、外部サービス障害等）では**コードパス整合性検証**を代替テストとして認める（直接テスト不可の理由を明示した上で適用。#1679教訓）
- **リーダーE2Eリレー出力義務**: ワーカーE2E報告受領・ゲート検証後に、リーダー自身のstdoutにE2Eサマリ（JSON形式）を出力する（Stop Hookの自信ゲート発火用。Step 7e-post参照）
- 詳細: references/e2e-report-schema.md

### 12. ASSERT_NEXT（自動継続アサーション）
- ASSERT_NEXT句のあるStepは完了後に即時次Stepを実行する義務がある
- 途中停止は**ガードレールB15違反 + アンチパターン#20違反**
- 最重要区間: Step 10a承認受信 → 10b(merge) → 10b(vercel-watch) → 10c(本番E2E) → 11(完了報告)
- 詳細: references/leader-core-invariants.md「ASSERT_NEXT」

### 13. クアドレビュー数値ゲート（必須、Tier別分母）
- `review_lanes_completed={Tier別分母}/{Tier別分母}` かつ `critical_open=0` をフェーズA完了の前提条件とする（Phase 1 hard gate）
- Tier別分母: **Tier C = 2/2**（Lane 0 + Lane 4）、**Tier B/A = 5/5**（Lane 0-4）
- Tier情報が不明（tier=null、手動計画等）の場合、Tier B（5/5）をデフォルトとする
- `phase2_code_review_status`: PASS | NO_FINDINGS | SKIPPED | FAILED を記録（Phase 2 soft gate）
- Phase 2 は soft gate: FAILED/SKIPPED でもフェーズA完了を許可。Normal指摘がある場合は修正推奨
- 「クアドレビュー実施」という定性的確認ではなく、数値ゲートによる定量的検証を必須とする
- ワーカーのフェーズA完了報告に `review_lanes_completed`、`critical_open`、`phase2_code_review_status` フィールドを含めること
- Phase 1 が未達の場合、merge許可を保留しフェーズBに進めない

### 14. Issueクローズ完了監査（必須）
- `state=CLOSED` の前提条件として、Issueコメントに以下2セクションが存在することを監査する:
  - `## E2E結果`: テスト項目・結果・自信ゲート回答を含む構造化レポート
  - `## クローズ根拠`: PR番号・E2E PASS確認・staging/本番環境での動作確認サマリ
- これらのセクションが欠けている場合、`gh issue close` を実行してはならない
- ワーカーがPhase B完了報告時に、上記2セクションをIssueコメントとして投稿する責務を負う

### 15. CodeRabbitレビュー確認（Phase A完了後必須）
- リーダーはワーカーのPhase A完了報告受信後、`gh pr checks <PR番号> --watch` でCodeRabbit完了まで待機する
- CodeRabbitレビューは soft gate とする
- ただし、セキュリティ/バグ指摘は hard block とし、解消前にstaging mergeしてはならない
- 指摘は3分類で処理する: 即時修正 / 技術的負債Issue / スキップ
- `issues[].coderabbit_status` に `PASS` | `FIXED` | `TECH_DEBT` | `SKIPPED` を記録する
- `coderabbit_status` 未確定のまま mergeゲート判定に進めてはならない

### 16. Tier判定統合（fortress-review / fortress-implement連携）
- Batch Planning Agentが各Issueの計画コメントから `issue-planner-meta` をパースし、`tier`, `tier_score`, `tier_breakdown` を `batch-plan.json` に含める
- ワーカーはIssueの `fortress-review-required` ラベルを検知した場合、実装開始前に `/fortress-review --auto-gate` を自動実行する
  - CRITICAL=0 → 自動Go（実装開始）
  - CRITICAL>=1 → 自動No-Go（ワーカー停止、リーダーがユーザー判断を仰ぐ）
- **fortress-implement連携（Tier A / 実装複雑度I2+）**: ワーカーが `fortress-implement-required` ラベルを検知した場合、通常の実装フローの代わりに `/fortress-implement --auto` でSlice & Prove方式の多重防御実装を実行する
  - 対象: 実装複雑度スコアI2+（fortress-implementのTier判定で15点以上）のIssue
  - ラベル付与: Batch Planning Agentが `tier_score` と `tier_breakdown` から自動判定し、`fortress-implement-required` ラベルを付与
  - fortress-implementのPhase 1でfortress-reviewも自動実行されるため、両ラベルが付いている場合はfortress-implementに一元化する（二重実行を防止）
- クアドレビューのレーン数はTier別に動的化される（核心ルール13参照）
- 詳細: references/worker-flow.md（Step 0.5）、references/multi-perspective-review.md（Tier別レーン構成）

### 17. Phase B専用ワーカー原則（教訓 #1743/#1744）
- Phase A完了後、**同一ワーカーをPhase Bに再利用しない**。リーダーがPhase B用に新規ワーカーをspawnする
- 理由: Phase Aでコンテキストが飽和したワーカーはPhase B指示を正しく処理できず、idle通知を連発する事例が発生
- Phase A summaryファイル（`tasks/issue-{number}-phase-a-summary.md`）により、新ワーカーでも即座にPhase Bを開始可能
- 詳細: references/worker-flow.md（フェーズBセクション冒頭）

### 18. Grok research lane は補助用途限定
- `openrouter` 経由の **Grok 4.20 multi-agent** (`x-ai/grok-4.20-multi-agent`) は planning / review / risk synthesis の**補助レーン**に限定する
- merge、E2E、Issue close などの**実行系には使わない**
- `OPENROUTER_API_KEY` が見えない場合は自動スキップ（エラーにしない）
- 起動フェーズ: Batch Planning (Step 2, Tier B/A), クアドレビュー (Phase A, Tier B/A), 統合回帰リスク評価 (Step 8, feat≥2)
- Grok出力のファイルパス・行番号は必ずローカル検証（信頼境界ルール）
- Grokレーン失敗はバッチ停止理由にならない（常にClaude単独で継続可能）
- 詳細: `references/grok-research-lane.md`

---

## リーダーワークフロー概要（13ステップ）

| Step | 内容 | 詳細 |
|------|------|------|
| 0 | **ゲートキーパー（早期終了判定）** | planned Issue 0件 or 全件implementing/implemented済みなら即終了。`gh issue list -l planned --json number -q 'length'` で判定。**Batch Planning Agent を起動せずコスト0で終了** |
| 1 | 入力解析 + resumeチェック | resume時はStep 7直行 |
| 2 | Batch Planning Agent 起動 | サブエージェントに委任 |
| 3 | batch-plan.json 読み取り + バリデーション | 必須フィールド検証 |
| 4 | （欠番） | Step 3に統合 |
| 5 | ユーザーに実行計画を提示 | |
| 6 | チーム作成 + 状態ファイル初期化 | |
| 7 | パイプライン実行ループ | 7a-7h（復元ガード+未応答リカバリ+**E2Eリレー出力(7e-post)**+Compaction時 `/clear` 推奨+ `context.next_action` 起点でresume） |
| 8 | 全Issue完了サマリ + 統合回帰テスト | Step 8.5: 回帰テスト、8.7: CodeRabbit最終確認（漏れチェック） |
| 9 | staging->main PR作成 | |
| 10 | mainマージ承認 -> 自動継続 | vercel-watch -> 本番E2E |
| 11 | 完了報告 + TeamDelete | Issueクローズ前に `## E2E結果` / `## クローズ根拠` の監査必須 |
| 12 | クリーンアップ | アーカイブ + ブランチ整理 |

詳細: 上記「オンデマンドRead指示」テーブルの leader-steps-1-6 / leader-pipeline-loop / leader-steps-8-12 を参照

## ワーカーフロー概要（Phase A/B）

- **Phase A**（Step 0-10）: ラベル確認 -> fortress-review(Tier A) -> Issue読込 -> 実装 -> PR -> クアドレビュー(Tier別) -> 完了報告
- **Phase A完了報告の直後**: リーダーが `gh pr checks <PR番号> --watch` でCodeRabbit確認を行い、`coderabbit_status` 確定後にmergeゲート判定へ進む
- **Phase B**（Step 11-17）: merge許可待ち -> rebase -> staging merge -> E2E -> クローズ
- 報告は2回のみ: Phase A完了時（`review_lanes_completed` / `critical_open` 必須）+ Phase B E2E結果（**JSON構造化必須**）
- Phase B完了時は Issueコメントに `## E2E結果` と `## クローズ根拠` を投稿してからクローズ判定に進む
- Issue全コメント通読必須（実装計画の全ステップをチェックリスト化）

詳細: references/worker-flow.md

---

## ガードレール概要（30項目）

**継承8項目**: クアドレビュー必須、Lint/型/ビルド全パス、E2E必須、等
**バッチ固有22項目**: B1(mergeゲート)、B2(post-rebase品質)、B3(ラベル状態機械)、
B4(連続失敗制限)、B5(セーフポイント)、B6(APIレート防御)、B7(途中mainマージ禁止)、
B8(リーダー専念)、B9(並列制限)、B10(統合回帰テスト)、B11(復元ガード)、
B12(error_patterns上限)、B13(冪等性)、**B14(E2E報告ゲート検証)**、**B15(ASSERT_NEXT停止禁止)**、
**B16(自信ゲート)**: ワーカーPhase B E2E報告前に5問の自信ゲート全回答必須（C1:直接操作、C2:ユーザー視点、C3:全項目消化、C4:実動作確認、C5:修正前→後検証）、
**B17(変更箇所カバレッジ)**: 全IssueのE2E報告にchange_coverage_map必須（feat種別はCodex評価追加）、
**B18(ブラウザ外操作制約)**: ブラウザ外操作のE2Eテストで `browser_boundary` 必須、
**B19(CodeRabbit確認ゲート)**: CodeRabbit未確認、またはセキュリティ/バグ指摘未解消のままstaging mergeしてはならない
**B20(E2Eリレー出力)**: ワーカーE2E報告受領後にリーダーがE2Eサマリ（JSON形式）をstdoutリレー出力すること（Stop Hook自信ゲート発火に必須。Step 7e-post参照）
**B21(fortress-review必須ゲート)**: Tier A Issue（`fortress-review-required` ラベル付き）のfortress-review省略禁止
**B22(過剰品質ゲート禁止)**: Tier C IssueにTier B/Aのレビュー深度（5レーン）を強制しない

詳細: references/guardrails-antipatterns.md

## アンチパターン概要（34項目）

主要なもの:
- 複数Issueの同時staging merge禁止
- implementingラベルなしの実装開始禁止
- リーダーの直接実装介入禁止
- PRマージ=実装完了と見なすことの禁止
- Issueコメント未読での実装開始禁止
- **#20: ASSERT_NEXT句で停止してユーザー報告のみ行う**
- **#21: E2E結果を自由テキストで報告する**
- **#22: core_operation未テストでPASS判定**
- **#23: test_itemsにL2深度なし**
- **#24: 自信ゲート未回答でE2E報告する**（C1〜C5の5問に全回答必須）
- **#28: E2Eテスト通過数のみでカバレッジ判定する**（Issue #1534教訓）
- **#29: ブラウザ外操作の制約を報告に記載せずPASS判定する**（Issue #1596教訓）
- **#30: CodeRabbitレビュー未完了でstaging mergeを実行する**
- **#31: ワーカーE2E結果を受領してもリーダーstdoutにリレー出力しない**
- **#32: fortress-review-required ラベル付きIssueをfortress-reviewなしで実装開始する**
- **#33: Tier C IssueにTier B/Aのレビュー深度を適用する（トークン浪費）**
- **#34: ワーカーがissue-flowの自動継続でmerge許可前にstaging mergeする**

詳細: references/guardrails-antipatterns.md

---

## オンデマンドRead指示（@展開しない — 必要Stepに到達したらReadする）

| Step | Read対象 | タイミング |
|------|---------|-----------|
| 1 (resume) | references/pipeline-state-schema.md | resumeモード時に復元手順を確認 |
| 2 | references/batch-planning-agent.md | サブエージェントプロンプトに含める |
| 3-6 | references/leader-steps-1-6.md | 状態初期化の具体的仕様を確認する時（※SKILL.md概要で十分な場合はスキップ可） |
| 6, 10 | references/leader-core-invariants.md | ASSERT_NEXT連鎖 + 状態初期化の具体的仕様（横断的参照） |
| 7開始 | references/leader-pipeline-loop.md | パイプライン開始時に1回Read（必須） |
| 7a/7d | references/worker-prompt-template.md | ワーカープロンプト組み立て時 |
| 7e | references/e2e-report-schema.md + references/e2e-defect-classification.md | E2E報告ゲート検証時（必須） |
| 8-12 | references/leader-steps-8-12.md | パイプライン完了後にRead |
| 8-12 (resume) | references/leader-pipeline-loop.md + references/pipeline-state-schema.md | resume時はパイプライン手順も復元 |
| planning / review / risk | references/grok-research-lane.md | Grok補助レーンの発火条件と出力形式を確認したい時 |
| エラー時 | references/troubleshooting.md | エラー遭遇時のみ |
| 全ステップ | references/guardrails-antipatterns.md | ガードレール・アンチパターンの詳細確認が必要な時のみ |
| スキル改善時 | ~/.claude/skills/codex/SKILL.md（トラブルシューティング） | `.claude/skills/` へのCodex workspace-write不可。Edit tool直接使用 |

---

## クイックスタート

1. `planned` ラベル付きIssueを準備（issue-plannerで作成 or 手動）
2. `/autopilot-batch all-planned` でバッチ起動
3. **ゲートキーパー**: planned Issue 0件なら即終了（Batch Planning Agent を起動しない）
4. Batch Planning Agent が分析・計画策定 -> batch-plan.json 生成
5. ユーザーが実行計画を確認
6. パイプライン実行ループ（自動）
7. 全Issue完了 -> 統合回帰テスト -> staging->main PR作成
8. ユーザーがRelease PR承認
9. mainマージ -> 本番デプロイ監視 -> 本番E2E確認 -> 完了報告

## 関連スキル

| スキル | 関連 |
|--------|------|
| `issue-planner` | 上流: 実装計画の作成（planned ラベル + コメント） |
| `issue-flow` | 個別Issue実装フロー（ワーカーが参照） |
| `codex-autopilot` | Codex意思決定パターン（stdin経由、フォールバック階層） |
| `agent-teams` | TeamCreate/TaskCreate/SendMessage パターン |
| `e2e-test` | E2Eテスト計画・実行（Phase 1-2） |
| `vercel-watch` | デプロイ完了検知 |
| `openrouter` | Grok 4.20 multi-agent などの外部補助レーン |
| `fortress-implement` | Tier A(実装複雑度I2+)のIssueで多重防御実装を実行するワーカーモード |
| `usacon` | プロジェクト固有ルール |

---

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-17 | オンデマンドRead指示にworkspace-write制約の参照行を追加 | ~/.claude/skills/ はgitリポ外のためworkspace-write不可。教訓の棚卸しで検出 |
| 2026-03-27 | CodeRabbitレビュー確認ステップ追加（核心ルール15、ガードレールB19、アンチパターン#30） | Step 7でCodeRabbit待機なし→staging merge前にセキュリティ/バグ指摘を検出できない問題の修正（Codex分析に基づく） |
| 2026-03-27 | ガードレール・アンチパターン番号整合性修正（B18→B19、#29→#30）、項目数修正（27項目/30項目） | skill-improve整合性チェックでguardrails-antipatterns.mdとの番号衝突を検出・解消 |
| 2026-04-01 | Step 0「ゲートキーパー（早期終了判定）」追加。planned Issue 0件時にBatch Planning Agent起動前に即終了 | トークンコスト最適化: 空振り時の数十万トークン消費を防止 |
| 2026-04-03 | 核心ルール11にコアオペレーション直接テスト自問・コードパス整合性検証を追加 | 2026-04-01バッチ教訓(#1679,#1682): 回帰テスト+デプロイ確認逃げ防止、テスト困難シナリオの代替手段認定 |
| 2026-04-06 | E2Eリレー出力ステップ追加（核心ルール11拡張、Step 7e-post新設、ガードレールB20、アンチパターン#31）。B14ゲート検証を6項目→8項目に修正 | Stop Hookがサブエージェント内E2E報告を検知できない問題の解決。リーダーがJSON形式E2EサマリをstdoutリレーしHook自信ゲート発火を保証（Codexレビュー反映: テンプレートをJSON形式に変更、200文字閾値・A2/A3/A4加点キー対応） |
| 2026-04-07 | fortress-review Tier判定統合（核心ルール16追加、ルール13改訂、ガードレールB21-B22、アンチパターン#32-#33、Tier別処理時間テーブル追加、ワーカーStep 0/0.5新設、Step 7b-post2新設、batch-plan.json/pipeline-state.jsonスキーマ拡張） | fortress-review「動的N方式」のバッチパイプライン統合。Tier C: レビュー時間30%削減（13分→9分）、Tier A: fortress-review自動実行で品質強化、バッチ全体トークン25-30%削減 |
| 2026-04-09 | 教訓棚卸し反映: 核心ルール17（Phase B専用ワーカー原則）追加、Step 7h idle3回ルール追加、Step 7-pre サブエージェント遅延時並行調査追加 | 教訓#1743/#1744/#1745（4/7）のスキル未反映3件を解消。ワーカー制御系の再発防止 |
| 2026-04-11 | Grok research lane 統合: 核心ルール18追加、`references/grok-research-lane.md` 新規作成、関連スキルに `openrouter` 追加、オンデマンドReadテーブル更新、ルール数16→18に修正 | Codex版ルール#18を Claude Code 環境向けに移植。OpenRouter経由のGrok 4.20をplanning/review/risk synthesisの補助レーンとして活用 |
| 2026-04-11 | fortress-implement連携追加: 核心ルール16拡張（`fortress-implement-required`ラベル・Tier判定・二重実行防止）、関連スキルに `fortress-implement` 追加 | fortress-implement「Slice & Prove方式」のバッチパイプライン統合。実装複雑度I2+のIssueで多重防御実装を自動適用 |
| 2026-04-13 | 教訓ベース4箇所改善: (1) 7-pre GitHub実状態照合の補正テーブル追加(#1163教訓), (2) worker-flow Phase B報告順序ルール追加(#1163教訓), (3) 7b 実装計画カバレッジ検証にGitHub APIコマンド追加(#1133教訓), (4) Step 12 ブランチ復帰をstagingに統一 | ワーカー完了報告欠落・実装不完全・ブランチ未整理の再発防止 |
