# リーダーワークフロー: Step 8-12（完了フェーズ）

## Step 8: 全Issue完了サマリ

## Step 8.5: バッチ統合回帰テスト（main PR作成前、必須）

**目的**: 全Issueの変更が統合された状態でのリグレッション検出。

**実行条件**: 完了Issue数が2件以上の場合に必須。1件のみはスキップ可。

**テスト範囲:**
1. 全完了Issueの主要E2Eテスト項目を統合（状態ファイルの `e2e_test_items` から収集）
2. プロジェクトのスモークテスト（ログイン->ダッシュボード->主要機能の動作確認）
3. コンソールエラー0件確認

**回帰テスト品質基準（教訓 #10 + #4）:**
- 統合回帰テストは個別E2Eの代替ではない
- 状態ファイルの `e2e_test_items` を全件テストする
- 「表示確認のみ」は回帰テストの最低ライン。各Issueの修正対象操作を最低1つ実際に操作で再現する
- サブエージェント並列実行を活用してスループットを上げる
- **feat Issue は回帰テストで重点対象とする（教訓 #4）**: feat は影響範囲が広いため、個別E2Eで通過していても統合時にリグレッションが発生しやすい。feat の変更ファイルと共通ファイルを持つ他Issueの機能を優先的にテストする
- UI表示修正のテストでは必ずスクリーンショットで視覚確認する（snapshotテキストのみ不可）

**PRE-EXISTING発見時のバッチ包含判断（教訓 2026-03-13）:**
E2Eテスト中にPRE-EXISTINGバグ（バッチの変更とは無関係の既存バグ）を発見した場合:
- **30分以内に修正可能**: 追加PRをstagingにマージし、Release PRに含める（効率的）
- **30分超の修正**: 別Issueとして起票し、PASS扱いで続行
- 判断はリーダーが行い、ユーザーに確認して決定する

**失敗時:**
- 失敗箇所の原因Issueを特定（状態ファイルの changed_files と照合）
- 当該IssueのPRをrevert -> staging安定化 -> 再テスト
- staging->main PR作成は回帰テスト通過後にのみ実行

**Step 8.7: CodeRabbitレビュー最終確認（漏れチェック、回帰テスト通過後）**

> **注意**: メインのCodeRabbit処理は Step 7b-post で完了済み。ここでは個別PRで処理済みの指摘（`coderabbit_status` 記録済み）を除外し、未処理のコメントのみを棚卸しする。

未処理コメントの収集手順:
1. 各PRの `coderabbit_status` を状態ファイルから確認
2. `coderabbit_status` が記録済みのPRは処理済みとしてスキップ
3. 未処理コメントのみを以下の3分類で処理:
   - **即時修正**: バグ・セキュリティ指摘 -> その場で修正コミット
   - **技術的負債Issue**: リファクタ・パフォーマンス改善提案 -> `gh issue create --label "tech-debt"` で起票
   - **無視**: 誤検知・スタイル好みの差異 -> スキップ（理由を状態ファイルに記録）
4. **未処理のセキュリティ/バグ指摘が1件でも残る場合、Step 9 には進まない**

**Step 8.8: changelog.ts 更新（Release PR作成前、必須）**

> **教訓（autopilot-batch-20260307）**: changelog更新をRelease PR作成後やマージ後に行うと、PRに含まれずmainに追加コミットが発生する。Release PR作成前にstagingで更新・コミットすること。

1. サブエージェントにchangelog更新を委任
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

→ ASSERT_NEXT連鎖の詳細は `references/leader-core-invariants.md` を参照

**10a. ユーザーに承認依頼（詳細メッセージ必須）:**
```
Release PR #XX のマージ承認をお願いします。
- 含まれるIssue: #A, #B, #C（全件E2E PASS）
- 統合回帰テスト: PASS
- CodeRabbit最終確認: 完了（個別PR処理済み。未処理指摘なし。技術的負債Issue N件起票済み）
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

#### ブランチ復帰（教訓: バッチ終了後のブランチ未整理）

バッチ完了後、HEADをstagingに復帰させる:
```bash
# stagingブランチに復帰（featureブランチに留まる問題を防止）
git checkout staging
git pull origin staging

# バッチで作成したマージ済みブランチを削除
git branch --merged staging | grep -E "feat/issue-" | xargs -r git branch -d
```

> **注意**: バッチ完了後にfeatureブランチに留まったまま次の作業を開始すると、意図しないブランチで作業する事故が起きる。次回作業開始時にfeatureブランチ上で誤って作業を開始するリスクを防止するため、stagingへの復帰は必須。
