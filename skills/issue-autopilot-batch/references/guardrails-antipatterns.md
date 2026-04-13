<!-- 抽出元: SKILL.md「安全ガードレール（21項目）」セクション（旧 行838-866）
     + 「ガードレール（厳守）」セクション（旧 行744-754）
     + 「アンチパターン（18項目）」セクション（旧 行929-951） -->

# ガードレール + アンチパターン

## ワーカーガードレール（厳守）

1. クアドレビュー必須（5並列 + /code-review[soft gate]）、なしマージ禁止
2. Lint + 型チェック + ビルド全パス必須
3. 信頼度>=80の指摘は必ず対応
4. E2Eテスト実施必須、E2E成功前のIssueクローズ禁止
5. テストスキップはCodex承認必須
6. merge許可なしのstaging merge禁止
7. 報告は2回のみ（フェーズA完了、フェーズB完了）
8. E2Eテストでは修正対象の操作を直接テスト必須（Issue #1071教訓: キャンセルボタン修正なのにボタンクリックをテストしなかった）
9. E2Eテスト開始前にデプロイ反映検証必須: browser_evaluateで修正対象のDOM属性（disabled, className等）がコード変更を反映しているか確認。不一致の場合はデプロイ問題として報告
10. 難問調査のCodexエスカレーション: E2Eで発見したバグの原因が3回のブラウザ検査（evaluate/snapshot）で特定できない場合、`codex-autopilot` スキルでCodexにソースコード全体の分析を委任する（Issue #1071教訓: 10回以上のブラウザ検査で時間浪費。Codexはビルド最適化・コンポーネント解決・importチェーン等のランタイムでは見えない原因を特定できる）
11. ブラウザ外操作（ファイルDL・印刷・クリップボード等）を含むE2Eテストでは、`test_items[].browser_boundary` に検証範囲の制約を明記必須（Issue #1596教訓: MCP制約下でPASS判定したが検証範囲の限界が報告されていなかった）

---

## 安全ガードレール（30項目）

**issue-flowから継承（8項目）:**

- [ ] クアドレビュー必須（Tier別: Tier C→2並列、Tier B/A→5並列 + /code-review[soft gate]）
- [ ] クアドレビューなしマージ禁止（Phase 1: Tier別分母必須、Phase 2: soft gate）
- [ ] Lint + 型チェック + ビルド全パス必須
- [ ] 信頼度>=80の指摘は必ず対応
- [ ] E2Eテスト実施必須
- [ ] E2E成功前のIssueクローズ禁止
- [ ] テストスキップはCodex承認必須
- [ ] 自動継続パイプライン（Issue内では途中停止禁止）

**バッチ固有（22項目）:**

- [ ] B1: staging mergeゲート必須（原子的merge許可トークンで制御）
- [ ] B2: post-rebase品質ゲート（フェーズB開始時にlint+type+build再確認）
- [ ] B3: ラベル状態機械の厳守（状態ラベルは常に1つのみ）
- [ ] B4: 最大連続失敗数制限（2Issue連続E2E失敗でバッチ停止、ただしPRE-EXISTING/FLAKYは非カウント）
- [ ] B5: 中断セーフポイント（各完了時に状態ファイル更新）
- [ ] B6: GitHub APIレートリミット防御（Issue間30秒クールダウン）
- [ ] B7: バッチ途中のmainマージ禁止（全完了後にのみ1つのPR作成）
- [ ] B8: リーダーは監視・パイプライン制御に専念
- [ ] B9: フェーズA並列は最大1つ
- [ ] B10: バッチ統合回帰テスト必須（2件以上完了時、main PR作成前）
- [ ] B11: パイプラインループ冒頭で pipeline-state.json Read を必須化（コンテキスト復元ガード。スキップ禁止。A_completed+e2e_result=null検出時はGitHub実状態照合で自動補正）
- [ ] B12: context.error_patterns の上限5件（チェックポイント肥大化防止。古いものはFIFOで押し出し）
- [ ] B13: ワーカー報告処理前の processed_events 確認を必須化（冪等性保証。二重処理防止）
- [ ] B14: E2E報告ゲート検証必須（8項目チェック。不合格は差し戻し。e2e-report-schema.md参照）
- [ ] B15: ASSERT_NEXT句のあるStepで途中停止禁止（leader-workflow.md「ASSERT_NEXT」参照）
- [ ] B16: ワーカーPhase B E2E報告前に5問の自信ゲート全回答必須（C1:直接操作、C2:ユーザー視点、C3:全項目消化、C4:実動作確認、C5:修正前→後検証）
- [ ] B17: 全IssueのE2E報告に `change_coverage_map` 必須（`user_facing` ファイルの `tested_by` 空配列は差し戻し。feat種別ではCodexカバレッジ評価も追加）
- [ ] B18: ブラウザ外操作を含むE2Eテストで `test_items[].browser_boundary` 必須（ファイルDL・印刷等のMCP検証範囲の制約をE2E報告に明記。Issue #1596教訓）
- [ ] B19: CodeRabbit確認ゲート必須（Phase A完了後、`gh pr checks --watch` でCodeRabbit完了待ち。セキュリティ/バグ指摘はhard block。`coderabbit_status` 未確定のままmergeゲート判定禁止。Step 7b-post参照）
- [ ] B20: E2Eリレー出力必須（ワーカーE2E報告受領後、リーダーがE2Eサマリ（JSON形式）をassistant messageにリレー出力。Stop Hook自信ゲート発火に必須。省略するとHookがメインエージェントのE2E報告を検知できずC1-C6強制注入が行われない。Step 7e-post参照）
- [ ] B21: fortress-review必須ゲート（Tier A Issue の `fortress-review-required` ラベル検知時、ワーカーが `/fortress-review --auto-gate` を実行せず実装を開始してはならない。`fortress_review_result` が null のまま Phase A 完了報告を出してはならない。Step 7b-post2 参照）
- [ ] B22: 過剰品質ゲート禁止（Tier C Issue に 5 レーンのフルクアドレビューを強制してはならない。Tier C は Lane 0 + Lane 4 の 2 レーンで十分。過剰レビューはトークン浪費かつパイプライン遅延の原因。references/multi-perspective-review.md 参照）

---

## アンチパターン（33項目）

| # | やってはいけないこと | 理由 |
|---|-------------------|------|
| 1 | 複数Issueを並列でstaging同時マージ | staging競合確実 |
| 2 | 前IssueのE2E通過前に次Issueのstaging merge実行 | 未検証コード上に積み上げ |
| 3 | implementingラベルなしで実装開始 | 二重実装リスク |
| 4 | ビルド壊れた状態でバッチ続行 | 全Issue全滅 |
| 5 | 失敗Issueを無限リトライ | 1つのIssueで無限ループ |
| 6 | Issue間依存関係を無視した実行順序 | 前提なし実装 |
| 7 | バッチ途中でmainマージ | 中間状態が本番に流入 |
| 8 | 全Issueを1つのPRにまとめる | レビュー不能、revert不能 |
| 9 | リーダーが直接実装に介入 | コンテキスト汚染 |
| 10 | planned ラベルなしIssueをバッチ含める | 計画なし実装 |
| 11 | レートリミット無視で連続API呼び出し | GitHubブロック |
| 12 | 状態ファイルなしで実行 | 中断時に全進捗喪失 |
| 13 | E2Eで見つけた無関係バグを無視 | バグが記録されず消失 |
| 14 | 回帰テストなしでmain PR作成 | 統合後のリグレッション見逃し |
| 15 | リーダーがIssue詳細/実装計画を直接読む | コンテキスト汚染（~5,000トークン占有）-> Batch Planning Agentに委任 |
| 16 | PRマージ＝実装完了と見なす | PRマージはコードの統合のみ。実装計画の全ステップがカバーされているか検証が必要（Issue #1133教訓: 6ステップ中2ステップのみ実装でPRマージ） |
| 17 | Issueコメントを読まず本文のみで実装開始 | 実装計画はIssueコメントに投稿される。本文のみでは計画を見落とし、部分実装になる（Issue #1133教訓: 6ステップの計画がコメントにあったが本文のみ読んで2ステップで完了報告） |
| 18 | 影響ファイル検索を上位N件に制限 | 実装計画に書かれたファイルのみでは不十分。grep網羅検索で関連ファイルを全て特定しないと、変更漏れ・競合検出漏れが発生する |
| 19 | ワーカー未応答時に状態ファイルのみで判断しGitHub実状態を照合しない | ワーカーがPhase B全完了してもSendMessage報告が届かない場合、状態ファイルはA_completed/e2e_result=nullのまま。後続Issueのmerge許可が発行されずパイプライン全体がブロックされる |
| 20 | ASSERT_NEXT句のあるStepで停止してユーザー報告のみ行う | 完了感バイアスで区切りの良い操作（承認受信、マージ完了等）の後に停止してしまう。ASSERT_NEXTは即時継続を義務付ける |
| 21 | E2E結果を自由テキストで報告する | 構造化されていない報告はゲート検証が不可能。JSON構造化E2E報告スキーマ必須 |
| 22 | core_operation.tested=falseのままPASS判定 | 修正対象の操作を実際にテストしていないのにPASSとする虚偽報告。ゲートチェックで検出 |
| 23 | test_itemsにL2深度が1つもない | 概要テスト(L1)のみで完了とする問題。ゲートチェック#6で検出 |
| 24 | 自信ゲート未回答のままE2E報告を送信する | confidence_gateのC1〜C5の5問に全回答必須。未回答はゲートチェックで検出 |
| 25 | **timeout未指定でcodex exec実行** | Bash toolデフォルト120秒でCodex推論がkillされ出力全消失。Bash tool timeoutを必ず600000ms（10分）に明示指定 |
| 26 | **stdout依存（teeなし）でcodex exec実行** | kill時に出力が全消失しフォールバック判定不能。全codex execに `2>&1 \| tee /tmp/codex_output_{id}.txt` を付加 |
| 27 | **kill後にCodexの従来フォールバックを期待** | killは正常終了ではないため従来分岐に入らない。teeで永続化した部分出力を先に確認し、十分なら採用 |
| 28 | **E2Eテスト通過数のみでカバレッジ判定する** | 7/7 PASSでも変更6ファイル中3箇所が未テストだったケースあり（Issue #1534）。テスト通過数ではなく「変更箇所×テスト項目マッピング」で評価すること。change_coverage_mapでuser_facingファイルのtested_byが空なら不合格 |
| 29 | **ブラウザ外操作の制約を報告に記載せずPASS判定する** | MCP制約でファイルDL・印刷・クリップボード等を検証できていないのにPASS判定し、`browser_boundary`に制約を明記しない。ネットワークレスポンス確認のみでファイル保存を検証したことにしてはならない（Issue #1596教訓） |
| 30 | **CodeRabbitレビュー未完了でstaging mergeを実行する** | CodeRabbitがセキュリティ/バグ指摘を出す前にstagingにマージすると、staging上でセキュリティ脆弱性やバグが本番に近づく。Step 7b-postでCodeRabbit完了を確認し、hard block指摘を解消してからmergeゲート判定に進むこと |
| 31 | **ワーカーE2E結果を受領してもリーダーstdoutにリレー出力しない** | Stop Hookはメインエージェント（リーダー）のstdoutのみ監視。ワーカーは独立プロセスでHook対象外。リレー出力（JSON形式、200文字超）がなければ自信ゲート（C1-C6）が発火せず、リーダーのE2E判定品質が機械的に担保されない。Step 7e-post参照 |
| 32 | **fortress-review-required ラベル付きIssueをfortress-reviewなしで実装開始する** | Tier A Issue は高リスク（スコア>=12）であり、fortress-review なしの実装は本番障害リスクが高い。ワーカー Step 0.5 で自動実行が義務、リーダー Step 7b-post2 で実行確認が義務 |
| 33 | **Tier C IssueにTier B/Aのレビュー深度を適用する（トークン浪費）** | 低リスク変更に5レーンのフルレビューをかけてもROIが低い。Tier Cは2レーン（Codex diff + 仕様準拠）で十分。パイプライン時間13分→9分短縮、トークン25-30%削減の効果を阻害する |
| 34 | **ワーカーがissue-flowの自動継続パイプラインに従いmerge許可前にstaging mergeする** | issue-flowのステップ7は「stagingにsquashマージ（ユーザー承認不要）」だが、バッチモードではmergeゲート（核心ルール5）が最優先。ワーカーがissue-flowに従い許可前にマージすると、複数PRが同時にstagingに入りE2E順序保証が崩壊する（教訓: #1743, #1744でPR #1747, #1749が許可前にMERGED） |
