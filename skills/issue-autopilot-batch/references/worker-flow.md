<!-- 抽出元: SKILL.md「ワーカー内部フロー（フェーズA/B分離）」セクション（旧 行613-661）
     + 「パイプライン実行モデル」セクション（旧 行324-346）
     + 「ワーカープロンプトテンプレート」セクション（旧 行666-758）
     + 「フェーズA/B詳細」セクション（旧 行714-743） -->

# ワーカーフロー（Phase A/B）

## パイプライン実行モデル

### 核心: フェーズA/B分離

```
フェーズA（staging不要）: 実装 -> lint -> 【Codex final-check】 -> build -> PR作成 -> クアドレビュー（+ /code-review）
フェーズB（staging依存）: staging merge -> deploy -> E2E テスト -> Issueクローズ
```

**タイムライン例（3 Issue）:**
```
Issue A: [===フェーズA===] -> [=フェーズB: merge->deploy->E2E=] -> implemented
                              Issue B: [===フェーズA===] -> wait A -> [=フェーズB=] -> implemented
                                                           Issue C: [===フェーズA===] -> wait B -> [=B=] -> implemented
```

**パイプラインルール:**
- フェーズA（実装~レビュー）は前Issueの結果を待たずに開始可能
- フェーズB（staging merge）は前IssueのE2E通過後にのみ実行（mergeゲート）
- 同時にフェーズBを実行するIssueは最大1つ
- **フェーズA並列は最大1つ**（Issue[N]のE2E中にIssue[N+1]のフェーズAのみ許可）
- **mergeゲートの原子性**: リーダーは単一イベントループで許可を発行。1 Issue に対し1回限りのmerge許可トークンを発行し、消費後は再利用不可

---

## ワーカー内部フロー

### フェーズA（自律実行、staging不要）

0. **ラベル確認**
   - `gh issue view <番号> --json labels --jq '.labels[].name'` で `fortress-review-required` ラベルの有無を確認

0.5. **fortress-review 自動実行（`fortress-review-required` ラベル検知時のみ）**
   - `/fortress-review <Issue URL> --auto-gate` を実行
   - `--auto-gate` モード: Human Gate を自動判定（CRITICAL=0 → Go、CRITICAL>=1 → No-Go）
   - **Go の場合**: fortress_review_result = "Go" を記録し、Step 1 以降へ進む
   - **条件付き Go の場合**: fortress_review_result = "条件付きGo" を記録し、条件を実装計画に追記して Step 1 以降へ進む
   - **No-Go の場合**: fortress_review_result = "No-Go" を記録し、リーダーに以下を SendMessage で報告:
     ```
     Issue #{number}: fortress-review No-Go
     CRITICAL指摘: {件数}件
     概要: {指摘概要}
     推奨アクション: 実装計画の修正が必要
     ```
   - No-Go 時、ワーカーは実装を開始せずリーダーに報告して停止する（リーダーがユーザー判断を仰ぐ。リスク受容→merge許可発行、中止→planned+implementation-failedに戻す）
   - **タイムアウト（5分超）**: fortress-review をスキップし、fortress_review_result = "skipped" としてリーダーに報告（リーダーがユーザー判断を仰ぐ）

1. **Issue読み込み（本文 + 全コメント通読、必須）**
   - `gh issue view <番号>` でIssue本文を読む
   - `gh issue view <番号> --comments` で**全コメントを通読する**（本文のみ読んで止まらない）
   - 実装計画コメントがある場合、**全ステップをチェックリスト化する**（例: 6ステップあれば6項目）
   - **Tier情報の確認**: バッチコンテキストから `tier`, `tier_score` を確認し、Step 8 のクアドレビューレーン数を把握
   - Issue #1133教訓: コメント欄の6ステップ計画を読まず、2ステップのみ実装して完了報告した
2. コードベース調査
3. Codexプラン承認
4. 実装
5. Lint + 型チェック
5.5. **Codex final-check（非ブロッキング）**
   - codexスキルの「final-check」テンプレートをTaskツールで実行
   - ガードレール: 修正ファイル数≤10、修正行数≤50、関数シグネチャ変更なし
   - 修正あり → Lint/型チェック再確認 → PASSならStep 6へ
   - 修正なし → Step 6へ
   - タイムアウト(5分)/エラー → スキップしてStep 6へ（パイプライン非ブロッキング）
5.9. ビルド確認
6. ブランチ作成 + コミット + プッシュ
7. PR作成（base: staging）
8. **クアドレビュー（Tier別レーン構成）**
   - **Tier C** (tier_score < 6): 2並列（Lane 0: Codex diff + Lane 4: 仕様準拠） + /code-review[soft gate]
   - **Tier B** (tier_score >= 6): 5並列（Lane 0-4: 現行フル構成） + /code-review[soft gate]
   - **Tier A** (tier_score >= 12): 5並列（Lane 0-4: 現行フル構成） + /code-review[soft gate]
   - **Tier不明** (tier=null): Tier B 扱い（5並列）
   - Tier別レーン構成の詳細: references/multi-perspective-review.md
9. レビュー結果の修正適用
10. **フェーズA完了報告** -> 状態サマリをローカルファイルに退避 -> merge許可待機

```
# tasks/issue-{number}-phase-a-summary.md に書き出す（コンテキスト劣化対策）
PR番号: #{pr_number}
ブランチ: {branch_name}
変更ファイル: [一覧]
E2Eテスト計画: [確認すべきポイント]
```

### フェーズB（リーダーからmerge許可受信後）

> **Phase B専用ワーカー原則（教訓 #1743/#1744）:**
> Phase A/B間の**同一ワーカー再利用は原則禁止**。リーダーはPhase B開始時に**新規ワーカーをspawn**する。
> 理由: Phase A完了時点でワーカーのコンテキストが飽和し、Phase B指示を正しく処理できない（idle連発）事例が発生。
> Phase A summaryファイルがあるため、新ワーカーでもPhase Bを即座に開始できる。

11. **状態サマリ再読み込み**（`tasks/issue-{number}-phase-a-summary.md`）
12. staging最新rebase + **post-rebase品質ゲート**（lint + type-check + build 必須）
13. staging squashマージ
14. vercel-watch（Preview deploy完了待ち）
15. E2Eテスト実行（不具合分類テーブルに従い判定）
16. **E2E結果報告**（PASS/FAIL + 発見不具合があれば分類付きで報告）
17. Issueクローズ + ラベル更新（自信ゲート付きコメント必須） + 関連Issueスキャン
    - `gh issue edit <番号> --remove-label "implementing" --add-label "implemented"`（ワーカーの責務）
    ※ staging->main PRはバッチ全完了後にリーダーが作成（スキップ）
    ※ クローズコメントにconfidence_gateの5項目チェック結果を含めること（下記フォーマット参照）

**ワーカーのSendMessage報告は2回のみ（コンテキスト節約）:**

| 報告 | 内容 | リーダーの判断 |
|------|------|--------------|
| 報告1: フェーズA完了 | PR番号、変更ファイル一覧、**実装計画カバレッジ**（例: "6/6ステップ完了"） | 次Issueワーカー起動 + mergeゲート判定 + **カバレッジ検証** |
| 報告2: フェーズB E2E結果 | **JSON構造化E2E報告（下記スキーマ必須）** | implementedラベル + 次Issue許可 + **ゲート検証** |

### E2E報告JSONスキーマ（報告2で必須）

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
      "evidence": "screenshot-1.png"
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
  }
}
```

> **報告2のルール:**
> - 自由テキストでのE2E報告は禁止（アンチパターン#21）
> - `core_operation.tested` が false のままPASS判定は禁止（アンチパターン#22）
> - `test_items` に `depth_level: "L2"` が1つもない場合は禁止（アンチパターン#23）
> - ファイルダウンロード等のブラウザ外操作を含むテストでは `test_items[].browser_boundary` への制約記載が必須（アンチパターン#29、Issue #1596教訓）
> - e2e-test SKILL.md のゲートチェック7項目をクリアしてから報告すること

---

## フェーズA: 実装 ~ レビュー（issue-flow準拠、中間SendMessageは省略）

Step 1-9 は issue-flow.md のステップ①〜⑤に対応。フェーズAでは Step 5.5（Codex final-check）と Step 5.9（ビルド確認）を追加。
ただし以下が異なる:
- 中間SendMessage報告は全て省略（フェーズA完了時の1回のみ）
- WIPコミット推奨（クラッシュ時のコード喪失防止）
- **Issue全コメント通読必須**（上記「Issue読み込みの必須手順」に従う）
- **実装計画の全ステップをチェックリスト化し、全ステップがコードに反映されていることを確認してから完了報告する**
- **⚠️ issue-flowのステップ7（stagingマージ）は実行禁止**: issue-flowの自動継続パイプラインはフェーズAの範囲ではPR作成（ステップ3）までで停止すること。staging squash-mergeはリーダーからのmerge許可メッセージ受信後にのみ実行する（教訓: #1743, #1744でワーカーがissue-flowに従い許可前にマージした）

Step 10: フェーズA完了報告:
  - tasks/issue-{number}-phase-a-summary.md に状態退避
  - SendMessage: PR番号、変更ファイル一覧、クアドレビュー結果要約（+ phase2_code_review_status）、**実装計画カバレッジ（例: "6/6ステップ完了"）**、**Tier情報（例: "Tier B, score=8"）**、**review_lanes_completed（例: "5/5" or "2/2"）**
  - fortress-review実行済みの場合: `fortress_review_result` も含める
  - merge許可待機（何もしない）

## フェーズB: staging merge ~ E2E（merge許可受信後）

Step 11: 状態サマリ再読み込み（tasks/issue-{number}-phase-a-summary.md）
Step 12: staging最新rebase + post-rebase品質ゲート（lint+type+build）
  -> 品質ゲート失敗時はmerge禁止、自動修正->再確認
Step 13: staging squashマージ
Step 14: vercel-watch（Preview deploy完了待ち）
  -> バックグラウンド実行時は必ず `-WaitForReady` を使用。Continuousモード（`-WaitForReady` なし）はReady後もプロセスが終了せずTaskOutput通知が届かない
Step 14.5: デプロイ反映検証（E2Eテスト開始前、必須）
  -> browser_evaluateで修正対象のDOM属性（disabled, className, variant等）がコード変更を反映しているか確認
  -> 不一致の場合: デプロイが古い可能性 -> 追加待機またはデプロイ問題として報告
Step 15: E2Eテスト実行（e2e-test SKILL.md準拠、テスト計画はCodex承認）
  -> 不具合発見時は「E2Eテスト中の不具合分類テーブル」に従い分類・対応
  -> **feat Issue の場合（教訓 #4）**: 修正対象操作の直接テストに加え、変更が影響する既存機能の動作確認を1-2項目追加する（影響範囲が広いためリグレッションリスクが高い）
  -> fix Issue の場合: 修正対象操作の直接テストで十分（影響範囲が限定的）
Step 15.5: **変更箇所カバレッジ検証（feat/fix問わず必須）**
  -> git diffの変更ファイル一覧に対し、E2Eテスト項目のchanged_filesマッピングが網羅されているか検証
  -> `category: "observability_only"`（モニタリング/ログ/メトリクスのみの変更）はE2Eテスト免除
  -> `category: "user_facing"` の未カバーファイルが存在する場合、テスト項目を追加してから実行
  -> **feat種別の場合（追加）**: Codexにgit diffを渡し「E2Eカバレッジは十分か？」の評価を取得（codex exec、timeout: 150000ms）
  -> Codexが「NO（不十分）」と判定した場合、指摘箇所のテスト項目を追加してから再実行
  -> **分類ルール**: ユーザー影響が1つでもあれば `user_facing`。ログ/監視/型/コメントのみなら `observability_only`

**snapshot vs screenshot 使い分け（batch-20260307教訓）:**
- チャットドロワー等の大量DOM要素を含む画面では `browser_take_screenshot` を使用する（snapshotが50K〜82K文字に達しコンテキスト圧迫）
- DOM要素が少ない画面（ダッシュボード、設定等）では `browser_snapshot` が効率的
- 本番E2Eではページ遷移後にUsaconNavigator auto-dismissを挟む
Step 16: E2E結果報告（JSON構造化E2E報告。上記「E2E報告JSONスキーマ」に従う）
  -> e2e-test SKILL.md のゲートチェック8項目をクリアしてからJSON報告を生成
  -> JSON報告をSendMessageでリーダーに送信
Step 17: Issueクローズ + ラベル更新（自信ゲート付きコメント必須） + 関連Issueスキャン（staging->main PRはスキップ）

#### Phase B 報告順序ルール（Issue #1163教訓）

**報告→後処理の順序を厳守する。** ワーカーがクラッシュ/タイムアウトしても情報が失われないようにする。

| 順序 | アクション | 理由 |
|------|-----------|------|
| 1st | リーダーへSendMessage（E2E結果 + PR番号） | 最重要。これがないとパイプラインがブロックされる |
| 2nd | ラベル更新（implementing → implemented） | 報告後なら欠落してもリーダーが補正可能 |
| 3rd | Issueクローズ | 報告後なら欠落してもリーダーが補正可能 |

> **禁止**: ラベル更新やIssueクローズを先に行い、SendMessageを後にする。ワーカーがクラッシュした場合、リーダーに完了報告が届かずパイプラインがブロックされる。

**ラベル遷移（implementing → implemented）— ワーカーの責務:**
```bash
gh issue edit <番号> --remove-label "implementing" --add-label "implemented"
```

**Issueクローズコメントフォーマット:**
```bash
gh issue close <番号> --comment "$(cat <<'EOF'
✅ E2Eテスト完了。preview環境（staging）で動作確認済み。PR #<PR番号>

### 自信ゲート（テスト品質チェック）
| # | チェック項目 | 結果 | 詳細 |
|---|------------|------|------|
| C1 | 修正対象の機能を直接操作したか？ | ✅/❌ | （具体的な操作内容） |
| C2 | ユーザーとしてこのアプリを渡されて使えるか？ | ✅/❌ | （確認した操作フロー） |
| C3 | テスト計画の全項目にPASS/FAIL/SKIPが記入されているか？ | ✅/❌ | （例: T1〜T5全てPASS） |
| C4 | 「ビルド成功」「テスト通過」だけで判断していないか？ | ✅/❌ | （実動作で確認した内容） |
| C5 | 修正前に壊れていた操作が修正後に正しく動くことを確認したか？ | ✅/❌ | （修正前→後の差分） |
EOF
)"
```
> **重要:** C1〜C5に1つでも❌がある場合、追加テストを実施してからクローズすること。

---

## ワーカープロンプトテンプレート

```
あなたは issue-autopilot-batch チームのワーカーです。
Issue #{number} を自律的に実装してください。

## 重要: バッチモードの特別ルール

1. **フェーズA/B分離**: フェーズA完了後、リーダーからの「merge許可」を待機。待機中は何もしない。
2. **staging->main PRスキップ**: バッチ全完了後にリーダーが作成
3. **報告は2回のみ**: フェーズA完了時 + フェーズB完了時（中間報告は送信しない）
4. **フェーズA完了時**: tasks/issue-{number}-phase-a-summary.md に状態を書き出す
5. **フェーズB開始時**: (a) 状態サマリ再読み込み (b) staging最新rebase (c) lint+type+build再確認
6. **E2E中の不具合分類**: E2Eテスト中の不具合分類テーブルに従い判定・報告・起票

## バッチコンテキスト
- 完了済みIssue: {completed_issues}
- 既変更ファイル（パスのみ）: {changed_files}
- ファイル競合注意: {conflict_notes}（Pre-flightで検出された同一ファイル変更の概要）
  -> 上記ファイルを触る場合、staging最新取り込み後に変更すること
  -> rebase時のコンフリクト発生時はCodexに解消を委任
- **Tier**: {tier}（スコア: {tier_score}）
- **レビューレーン数**: {review_lane_count}（Tier C: 2, Tier B/A: 5, 不明: 5）

## スキルファイルの読み込み（必須）
1. C:\Users\zooyo\.claude\skills\issue-flow\SKILL.md（実装フロー手順）
2. C:\Users\zooyo\.claude\skills\usacon\SKILL.md（プロジェクトルール）
3. C:\Users\zooyo\.claude\skills\codex-autopilot\SKILL.md（Codex自動運転ルール）

## E2E報告はJSON構造化必須（フェーズB Step 16）
フェーズB完了時のE2E報告は以下のJSON構造で送信すること（自由テキスト禁止）:
```json
{
  "e2e_result": "PASS | FAIL",
  "test_items": [{ "id": 1, "screen": "画面名", "depth_level": "L1|L2", "operation_flow": "操作→結果", "result": "PASS|FAIL|SKIP", "skip_reason": null, "evidence": "screenshot.png" }],
  "summary": { "total": 0, "passed": 0, "failed": 0, "skipped": 0 },
  "core_operation": { "tested": true, "description": "操作の説明" },
  "deploy_verification": { "performed": true, "dom_matched": true },
  "issue_reproduction": { "tested": true, "resolved": true },
  "console_errors": 0,
  "confidence_gate": {
    "C1": "はい/いいえ — 具体的操作内容",
    "C2": "はい/いいえ — 確認した操作フロー",
    "C3": "はい/いいえ — 全項目消化状況",
    "C4": "はい/いいえ — 実動作確認内容",
    "C5": "はい/いいえ — 修正前→後の差分確認"
  }
}
```
test_itemsにdepth_level="L2"が1件以上必須。core_operation.tested=true必須。confidence_gate全5問回答必須。

## Issue読み込みの必須手順（省略禁止）

**Issue着手前に以下を必ず実行すること:**

```bash
# 1. Issue本文の取得
gh issue view {number} --json title,body

# 2. 全コメントの通読（必須 -- 本文のみで止まらない）
gh issue view {number} --comments
```

**コメント通読で確認すべき項目:**
- 実装計画コメントの有無 -> ある場合は**全ステップをチェックリスト化**
- ユーザーからの追加要件・再現手順・エラーログ
- 他PRとの関連情報（「PR #XXX で一部修正済み」等）

**Issue #1133教訓**: コメント欄に6ステップの実装計画があったが、ワーカーが本文のみ読んで2ステップしか実装しなかった。残り4ステップは別PRで補完が必要になった。

## プロジェクトディレクトリ
{project_dir}
```
