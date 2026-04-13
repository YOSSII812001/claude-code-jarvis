# PR作成・マージフロー

> 元のSKILL.mdの「PR作成〜マージフロー」「PRマージ前のコンテキスト確認」「staging マージ後のE2Eテスト手順」「PR作成前後の実行順序」「CodeRabbitレビュー対応ルール」「PRマージ後のデプロイ待機」「テスト前のデプロイ要件」セクションから抽出

## PR作成〜マージフロー（重要：staging経由必須）

> **必ずstagingブランチ経由でE2Eテストを実施してからmainにマージすること**

```
【正しいフロー】
feat/xxx → PR作成 → CodeRabbit → staging → E2Eテスト → main

【間違ったフロー】
feat/xxx → PR作成 → CodeRabbit → main（直接マージ）
```

### PRマージ前のコンテキスト確認（無関係なPRマージ時のみ）— Issue #925教訓

> **Issue #925作業中に、無関係なIssue #729のPR（#733, #734, #735）をコンテキスト確認なしにマージし、ビルドエラー（isPrintMode重複宣言）が発生した教訓に基づく。**
> **注: 自動継続パイプライン内で自分が作成したPRをstagingにマージする場合、このルールは適用されない（承認不要）。**

**ルール1: PRの所属Issueと現在の作業コンテキストの関連性を確認する（無関係なPRマージ時のみ）**
- **自分が作成したPR → stagingマージは自動継続パイプラインの一部として自動実行する（承認不要）**
- 他人が作成したPR、または無関係なIssueのPRをマージする場合のみ、以下の確認が必要:
- 無関係なPRの場合、ユーザーに以下のように確認する:
  ```
  「このPR #XXX はIssue #YYY（タイトル）のPRですが、現在作業中のIssue #ZZZ とは別件です。マージしてよいですか？」
  ```
- **CodeRabbitの「指摘なし」はマージ可否の判断材料の一つであり、マージの承認ではない**
- 「CodeRabbitレビューが通った」→「マージして」の流れで、所属Issue確認を省略してはならない

**ルール2: 異なるIssueに属するPRの一括マージ禁止**
- 異なるIssueに属するPRを一括でマージしない
- 各PRは独自のE2Eテストサイクルを経てからマージすべき
- 複数PRをマージする場合は、1つずつマージ→ビルド確認→次のPRの順で進める

### 完全なPRフロー

```bash
# 1. featureブランチで開発・コミット・プッシュ
git checkout -b feat/feature-name
git add <files> && git commit -m "message" && git push origin feat/feature-name

# 2. PR作成（ベースブランチ: staging）
gh pr create --base staging --title "タイトル" --body "説明"

# 3. CodeRabbitレビュー待機
gh pr checks <PR番号> --watch

# 4. レビュー指摘修正後、stagingにマージ
gh pr merge <PR番号> --squash

# 5. デプロイ完了を待機（非ブロッキング方式）
# Bashツール run_in_background: true, timeout: 360000 で実行:
#   sleep 180 ; echo 'デプロイ待機完了'

# 6. プレビュー環境でE2Eテスト（Playwright MCP）
# mcp__plugin_playwright_playwright__browser_navigate url: https://preview.usacon-ai.com
# → 機能の動作確認を実施

# 6.5. E2Eテスト成功後、関連する全Issueをクローズ（Issue #1020閉じ忘れ教訓）
# メインIssueだけでなく、子Issue・派生Issue・残作業Issueも必ずスキャンして閉じる
# 手順:
#   a. メインIssueのクローズ
#      gh issue close <issue番号> --comment "E2Eテスト完了。preview環境で動作確認済み。PR #<PR番号>"
#   b. 関連Issueの網羅的スキャン（以下の全パターンで検索）
#      gh issue list --state open --search "<機能名キーワード>"
#      gh issue list --state open --search "<Issue番号>"  # 本文に親Issue番号を含む子Issue
#   c. 見つかった関連Issueを全て閉じる（各Issueに解決方法をコメント）
#      gh issue close <関連issue番号> --comment "PR #<PR番号> で実装済み。E2Eテスト完了。"
#   d. 最終確認: 0件になるまでスキャンを繰り返す

# 7. E2Eテスト成功後、stagingからmainへPR作成・マージ
# 必ず staging-to-main-merge.md のチェックリストを実施すること
# 特に: ローカルビルド確認、重複ファイルチェック、マージ方式の選択
git checkout staging && git pull origin staging
gh pr create --base main --head staging --title "Release: 機能名" --body "E2Eテスト完了"
gh pr checks <PR番号> --watch
gh pr merge --merge  # staging→mainは --merge を推奨（squashは重複リスクあり）

# 8. 本番デプロイ完了を待機（非ブロッキング方式）
# Bashツール run_in_background: true, timeout: 360000 で実行:
#   sleep 300 ; echo 'デプロイ待機完了（本番）'
# → 完了後に mcp__plugin_playwright_playwright__browser_navigate url: https://usacon-ai.com
```

## staging マージ後のE2Eテスト手順（パイプライン 8-9）

> **stagingマージ後は `vercel-watch` でデプロイ完了を検知してからpreview環境でE2Eテストを実施すること。**
> これは自動継続パイプラインのステップ8（vercel-watch）→9（E2Eテスト）に対応する。

**手順:**
```bash
# 1. PRをstagingにマージ（パイプライン7で実行済み）
gh pr merge <PR番号> --squash

# 2. デプロイ完了を監視（パイプライン8、run_in_background: true, timeout: 360000）
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Environment Preview -Interval 10
# → Building → Ready検知でビープ通知

# 3. Issue起点の場合: Issueを再読して「本番操作フロー」を特定（必須）
#    gh issue view <番号> --json title,body
#    → Issueの再現手順・要望から「ユーザーが本番で実際に行う操作」を抽出
#    → 操作フロー例: ログイン→画面遷移→ボタンクリック→データ入力→保存→結果確認
#    → 「表示確認」だけでは不十分。データ生成・状態変更・保存を伴う操作を含めること
#
# 4. テスト計画を作成（操作フロー含む、e2e-test SKILL.md Phase 1準拠）
#    → テスト対象マトリクスに「操作フロー」列を追加:
#      | # | 画面 | テスト方法 | 操作フロー | 優先度 |
#      | 1 | XX画面 | UI操作 | ボタンA→入力→保存→結果確認 | 高 |
#    → 「表示確認のみ」のテスト項目は補助扱い。操作フローが最低1つ必須
#
# 5. テスト計画をユーザーに提示し承認を得る（独断スキップ禁止）
# 6. preview環境でE2Eテスト実行（下記「E2Eテスト品質基準」に従う）
#    → 操作フローを実際にPlaywright MCPで再現する（表示確認だけで完了しない）
# 7. テスト結果をユーザーに報告
# 8. FAIL時: 修正→staging向け修正PR作成（gh pr create --base staging）→squashマージ→vercel-watch→再テスト（リトライ上限2回）
```

## PR作成前後の実行順序（必須）

> **`gh pr create` の直後は、先にCodex差分レビュー+/sub-reviewを起動し、その後に `--watch` を実行すること。**
> ユーザーに確認を求めず、自動的に実行する。

```
# 実行順序（自動継続パイプラインのステップ1〜11に準拠）
1. ステップ1: npm run lint && cd frontend && npm run type-check && npx vite build
2. ステップ2-3: コミット + プッシュ + gh pr create --base staging
3. ステップ4: Task tool x 5（Codex差分レビュー 1 + /sub-review 4エージェント並列起動）
4. ステップ5: gh pr checks <PR番号> --watch（バックグラウンド）
5. ステップ6-8: レビュー統合 → stagingマージ → vercel-watch
6. ステップ9: E2Eテスト（テスト計画→ユーザー確認→実行→結果報告）
7. ステップ10: Issueクローズ + 関連Issueスキャン（Issue起点の場合）
8. ステップ11: staging→mainマージPR作成（マージはユーザー承認待ち）
```

**理由:**
- `--watch` を先に実行するとブロックされ、レビュー起動がユーザーの手動指示待ちになる
- Codex差分レビュー+/sub-reviewを先に起動すれば、`--watch` の待ち時間中にレビューが並行完了する
- CodeRabbitレビューとVercelデプロイの完了も `--watch` で確実に待てる

## `--auto` マージの注意事項（PR #1205教訓）

> **`gh pr merge --squash --auto` は、CIチェック通過時点で自動マージされる。CodeRabbitのレビューがCIより後に完了した場合、レビュー指摘を反映する機会を逃す。**

| シナリオ | 推奨マージ方法 | 理由 |
|---------|---------------|------|
| 通常のfeature PR | `--auto` 可 | CodeRabbitのnitpickは後続コミットで対応可能 |
| 重要な修正・セキュリティ関連 | 手動マージ（`--auto` 不使用） | レビュー指摘を確実に反映してからマージしたい |
| staging→main Release PR | 手動マージ（ユーザー承認待ち） | そもそもユーザー承認が必要 |

**`--auto` マージ後にCodeRabbit指摘が来た場合:**
1. 指摘が妥当であれば、追加コミットをstagingに直接プッシュして対応
2. 軽微なnitpickは次回PRでまとめて対応しても可

---

## セッション再開時のPR状態確認（PR #1204教訓）

> **セッション再開時や長時間経過後は、PRやIssueの状態を `gh` コマンドで確認してからアクション実行する。**

コンテキスト圧縮やセッション切り替えにより、PRの最終状態が不明確になることがある。既にマージ済みのPRに再マージコマンドを実行しても害はないが、無駄な操作を避けるため事前確認を推奨。

```bash
# セッション再開時の状態確認チェックリスト
gh pr view <PR番号> --json state,mergedAt --jq '{state: .state, mergedAt: .mergedAt}'
gh issue view <Issue番号> --json state --jq '.state'

# Release PRが既にマージ済みの場合 → 「already merged」は正常系として処理
# Open状態の場合 → 通常フローを継続
```

**ルール:**
- `already merged` エラーは異常ではなく、期待状態の確認として扱う
- PRの状態が不明な場合は、操作前に必ず `gh pr view` で確認する

---

## CodeRabbitレビュー対応ルール

> **`gh pr checks` の `pass` だけで判断しない。必ずPRコメントを読んでレビュー内容を確認すること。**
> CodeRabbitは `pass` を返しても、PRコメントに改善提案や確認推奨項目を記載していることが多い。

**確認手順（省略不可）:**
```bash
# 1. --watch で pass を確認
gh pr checks <PR番号> --watch

# 2. 必ずPRコメントを取得して内容を読む
gh api repos/<owner>/<repo>/pulls/<PR番号>/comments --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body'
```

| 指摘タイプ | 対応 |
|-----------|------|
| **エラー/警告** | 必ず修正してコミット |
| **確認推奨項目（堅牢性、エッジケース等）** | 内容を確認し、妥当であれば修正 |
| **Nitpick（軽微な提案）** | 妥当であれば修正、そうでなければスキップ可 |
| **ドキュメント整合性** | PR番号や日付の追記など、指摘があれば修正 |

**修正後の再プッシュ:**
```bash
git add <修正ファイル> && git commit -m "fix: CodeRabbitレビュー対応" && git push
```

## テスト前のデプロイ要件（重要）

**Playwright MCPでUIテストを行う前に、必ずコードをデプロイすること。**

| テスト対象環境 | 必要な手順 |
|---------------|----------|
| **本番環境** (`usacon-ai.com`) | `main`ブランチにマージ → 5分待機 → テスト |
| **プレビュー環境** (`preview.usacon-ai.com`) | `staging`ブランチにマージ → 3分待機 → テスト |
| **ローカル環境** (`localhost:3000`) | `npm run dev` 起動中ならそのままテスト可能 |

**よくある間違い:**
- NG: ローカルでコード変更後、すぐに本番URLでPlaywrightテスト → **古いコードがテストされる**
- OK: コード変更 → コミット → PR → マージ → 5分待機 → Playwrightテスト

**フロー例（本番環境でテストする場合）:**
```bash
# 1. ブランチ作成・コミット・プッシュ
git checkout -b feat/feature-name
git add <files> && git commit -m "message" && git push origin feat/feature-name

# 2. PR作成・レビュー・マージ
gh pr create --title "タイトル" --body "説明"
gh pr checks <PR番号> --watch
gh pr merge --squash

# 3. デプロイ完了を待機（非ブロッキング方式）
# Bashツール run_in_background: true, timeout: 360000 で実行:
#   sleep 300 ; echo 'デプロイ待機完了（本番）'

# 4. Playwright MCPでテスト
# mcp__plugin_playwright_playwright__browser_navigate url: https://usacon-ai.com
```
