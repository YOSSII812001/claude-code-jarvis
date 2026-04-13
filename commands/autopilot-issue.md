# Autopilot Issue実装: $ARGUMENTS

## ゴール
指定されたIssueを**Agent Teamsのワーカーエージェント**で自律実装する。
ワーカーは各フェーズの完了時にSendMessageで進捗を報告し、
リーダー（メインコンテキスト）経由でユーザーにリアルタイム表示される。

## 実行手順

Issue番号: $ARGUMENTS

### Step 1: チーム作成

```
TeamCreate:
  team_name: "autopilot-issue-<番号>"
  description: "Issue #<番号> の自律実装"
```

### Step 2: タスク作成（進捗の可視化用）

以下のタスクをTaskCreateで作成する：

1. **Issue読み込みとプラン確認**
   - subject: "Issue #<番号> を読み込みプランを確認"
   - activeForm: "Issue読み込み中"

2. **コードベース調査**
   - subject: "コードベースを調査し実装計画を策定"
   - activeForm: "コードベース調査中"

3. **Codexによるプラン承認**
   - subject: "Codexにプランをレビュー・承認させる"
   - activeForm: "Codexレビュー中"

4. **実装**
   - subject: "コードを実装"
   - activeForm: "コード実装中"

5. **Lint + 型チェック + ビルド確認**
   - subject: "Lint・型チェック・ビルドを実行"
   - activeForm: "Lint・ビルド確認中"

6. **PR作成 + クアドレビュー**
   - subject: "PR作成とクアドレビュー実施"
   - activeForm: "PR作成・クアドレビュー中"

7. **レビュー結果統合 + stagingマージ**
   - subject: "レビュー結果を統合しstagingにマージ"
   - activeForm: "レビュー統合・マージ中"

8. **staging E2Eテスト実行**
   - subject: "staging環境でE2Eテストを実行"
   - activeForm: "E2Eテスト実行中"

9. **Issueクローズ + 関連Issueスキャン**
   - subject: "Issueクローズと関連Issueの網羅スキャン"
   - activeForm: "Issueクローズ処理中"

10. **staging→mainマージPR作成**
    - subject: "staging→mainマージのPR作成"
    - activeForm: "mainマージPR作成中"

### Step 3: ワーカー起動（バックグラウンド）

**以下のTaskツールでワーカーを起動すること。run_in_backgroundをtrueにする。**

```
Task tool:
  subagent_type: general-purpose
  mode: bypassPermissions
  run_in_background: true
  team_name: "autopilot-issue-<番号>"
  name: "implementer"
  description: "Issue #<番号> を自律実装"
  prompt: |
    あなたはUsaconプロジェクトの自律実装エージェントです。
    Issue #<番号> を自律的に実装してください。

    ## 重要: チーム内の進捗報告ルール

    あなたはAgent Teamsのワーカーです。
    **各フェーズの完了時に、必ずSendMessageで "leader" に進捗を報告してください。**
    これによりユーザーにリアルタイムで進捗が表示されます。

    SendMessageの使い方：
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: "報告内容"
      summary: "5-10語の要約"
    ```

    ## フェーズ1: Issue読み込み

    ### Step 0: スキルファイルの読み込み
    以下のファイルを読んで、プロジェクトルールと実装フローを把握してください：
    1. C:\Users\zooyo\.claude\skills\issue-flow\SKILL.md（実装フロー手順）
    2. C:\Users\zooyo\.claude\skills\usacon\SKILL.md（プロジェクトルール）
    3. C:\Users\zooyo\.claude\skills\codex-autopilot\SKILL.md（Codex自動運転ルール）

    ### Step 1: Issueの実装プランを読み込む
    ```bash
    cd "C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app"
    gh issue view <番号> --json title,body,labels,assignees,milestone
    ```

    **画像がある場合**: Issue本文に `user-attachments/assets` のURLが含まれていたら、
    `github-cli` スキルの「Issue内の画像取得」手順に従って画像をダウンロード・確認すること。
    スタイル崩れやUI修正のIssueでは画像確認が必須。

    **読み込み完了後、TaskUpdateでタスク1を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        📋 **フェーズ1完了: Issue読み込み**
        - タイトル: [Issueタイトル]
        - プランの有無: [あり/なし]
        - 概要: [Issue内容の要約]
      summary: "Issue読み込み完了"
    ```

    ## フェーズ2: コードベース調査

    Issueの内容に基づきコードベースを調査し、実装計画を策定する。

    **Issueに実装プランが含まれている場合:**
    - そのプランを実装の基本方針として採用する
    - コードベースを調査してプランの妥当性を検証する
    - プランに不足や矛盾があればCodexに判断を委任して補完する

    **Issueに実装プランが含まれていない場合:**
    - issue-flowのステップ②に従い、コードベース調査→実装計画を自分で作成する

    **調査完了後、TaskUpdateでタスク2を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🔍 **フェーズ2完了: コードベース調査**
        - 影響範囲: [変更予定ファイル一覧]
        - 実装方針: [方針の要約]
        - 注意点: [あれば]
      summary: "コードベース調査完了"
    ```

    ## フェーズ3: Codexによるプラン承認

    issue-flowのステップ④「ユーザー承認」では、ユーザーに聞かず、
    代わりにCodex CLI（codex exec）に実装プランを送って判断させる。

    ```bash
    codex exec --full-auto --sandbox read-only \
      --cd "C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app" \
      "あなたはシニアフルスタックエンジニアであり、プロジェクトオーナーの代理として意思決定します。
      以下の実装プランをレビューし、承認または修正指示を出してください。
      <プラン内容>
      確認や質問は不要です。承認の場合は「承認」、修正が必要なら具体的な修正内容を回答してください。"
    ```
    タイムアウト: 300秒

    **承認完了後、TaskUpdateでタスク3を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        ✅ **フェーズ3完了: Codex承認**
        - 結果: [承認 / 修正指示あり]
        - Codexコメント: [要約]
        - 修正した点: [あれば]
      summary: "Codexプラン承認完了"
    ```

    ## フェーズ4: 実装

    issue-flowに従ってコードを実装する。
    実装中に判断が必要な場面では、すべてCodexに質問する（ユーザーには質問しない）。

    **大きなファイル変更ごとにSendMessageで中間報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🔨 **実装進捗**
        - 完了: [完了したファイル/機能]
        - 次: [次に取り組む内容]
      summary: "実装進捗報告"
    ```

    **実装完了後、TaskUpdateでタスク4を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🔨 **フェーズ4完了: 実装**
        - 変更ファイル数: [N]
        - 主な変更: [概要]
      summary: "コード実装完了"
    ```

    ## フェーズ5: 自動継続パイプライン（Lint → PR → クアドレビュー → stagingマージ）

    実装完了後、usaconの自動継続パイプラインを**この順番で一気に実行する。途中停止禁止。**

    ### ステップ5-1: Lint + 型チェック + ビルド確認
    ```bash
    cd "C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app"
    npm run lint
    cd frontend && npm run type-check && npx vite build
    cd ..
    ```
    エラーがあれば自動修正。全パスするまで次に進まない。

    **全パス後、TaskUpdateでタスク5を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        ✅ **ステップ5-1完了: Lint + 型チェック + ビルド確認**
        - Lint: パス
        - 型チェック: パス
        - ビルド: パス
      summary: "Lint・ビルド全パス"
    ```

    ### ステップ5-2: ブランチ作成 + コミット + プッシュ
    - コミット前に `git rev-parse --abbrev-ref HEAD` でブランチ名を確認（mainへの直接コミット防止）
    - changelog.ts の更新もこのステップで実施

    ### ステップ5-3: PR作成（base: staging）
    ```bash
    gh pr create --base staging --title "タイトル" --body "$(cat <<'EOF'
    Base branch: staging
    Reason: Preview環境での動作確認が必要
    Sync required: no

    ## Summary
    - 変更内容

    ## Test plan
    - [ ] テスト項目

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    EOF
    )"
    ```

    ### ステップ5-4: クアドレビュー（最重要 - 省略禁止）

    PR作成直後に **6つのTaskツールを並列起動**（run_in_background: true）:

    **Agent 1: Codex差分レビュー**
    ```bash
    codex exec --full-auto --sandbox read-only \
      --cd "C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app" \
      "以下のgit diffをレビューしてください。バグ、セキュリティ問題、パフォーマンス問題、設計上の懸念を指摘し、各指摘に信頼度スコア（0-100）を付けてください。
    $(git diff staging...HEAD)
    回答フォーマット: - [信頼度:XX] カテゴリ: 説明（ファイル名:行番号）"
    ```

    **Agent 2-5: /sub-review 4エージェント並列**
    - Agent 2: セキュリティ分析
    - Agent 3: ロジック整合性
    - Agent 4: パフォーマンス分析
    - Agent 5: 回帰リスク分析

    各エージェントにgit diffを直接埋め込み、信頼度スコア付きで返却させる。

    **Agent 6: /code-review（GitHub統合レビュー — soft gate）**
    Skillツールで `code-review` を起動。結果はGitHub PRコメントとして自動投稿。
    失敗/スキップ時はAgent 1-5の結果のみで続行（ブロッカーにしない）。

    > ⚠️ **クアドレビューなしでのstagingマージは禁止。**

    **PR作成+クアドレビュー起動後、TaskUpdateでタスク6を完了にし、SendMessageで報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🔍 **ステップ5-3〜5-4完了: PR作成 + クアドレビュー起動**
        - PR: #YY
        - クアドレビュー: 6エージェント並列起動済み（/code-review含む）
      summary: "PR作成・クアドレビュー起動完了"
    ```

    ### ステップ5-5: gh pr checks --watch（バックグラウンド）
    ```bash
    gh pr checks <PR番号> --watch
    ```

    ### ステップ5-6: レビュー結果の統合と修正
    - 信頼度≥80の指摘のみ採用
    - 修正があれば再コミット・再プッシュ
    - CodeRabbitのPRコメントも必ず読む（`gh api repos/.../pulls/<PR>/comments`）

    ### ステップ5-7: stagingにsquashマージ
    ```bash
    gh pr merge <PR番号> --squash
    ```

    ### ステップ5-8: vercel-watchでデプロイ完了を監視
    ```bash
    powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Environment Preview -Interval 10
    ```

    **ステップ5-6〜5-8完了後、TaskUpdateでタスク7を完了にし、SendMessageで中間報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        📦 **ステップ5-8完了: stagingマージ + デプロイ完了**

        **PR:** #YY → staging squashマージ済み
        **Vercel Preview:** Ready検知済み
        **クアドレビュー結果:**
        - 信頼度≥80の指摘数: [N]件
        - 対応済み: [N]件

        → ステップ5-9（E2Eテスト）に進みます
      summary: "stagingマージ・デプロイ完了、E2Eテストへ"
    ```

    ### ステップ5-9: staging E2Eテスト実行

    vercel-watchのReady検知直後に自動実行。**テスト未実施での完了報告は禁止。**

    #### 5-9a: Issue再読 + テスト計画の自動生成
    > **注**: e2e-test SKILL.md Phase 1.3の「ユーザー確認必須」は、autopilotモードではCodex承認で代替する。
    > ただし、テストスキップの独断は禁止（Codex承認必須）。Codexが修正指示を出した場合は計画を修正して再送する。

    **Step 0: Issue再読（Issue起点の場合、必須）**
    ```bash
    gh issue view <番号> --json title,body
    ```
    - Issueの再現手順・要望から「本番ユーザーが実際に行う操作フロー」を抽出する
    - 操作フロー例: ログイン→画面遷移→ボタンクリック→データ入力→保存→結果表示確認
    - **「表示確認のみ」でE2E完了としてはならない。** データ生成・状態変更・保存を伴う操作を必ず含めること

    **Step 1: テスト計画作成**
    - フェーズ2の調査結果 + `git diff staging...HEAD` から影響画面を特定
    - Issue起点の場合、**元のバグ報告の再現手順を最優先テスト項目に設定**（Issue #986教訓）
    - テスト対象マトリクスに**操作フロー列を追加**（画面/テスト方法/操作フロー/優先度）— e2e-test SKILL.md Phase 1準拠
    - 「表示確認のみ」のテスト項目は補助扱い。**操作フローが最低1つ必須**
    - Codexにテスト計画を送信して承認（テストスキップの独断禁止、承認まで修正→再送ループ）
    ```bash
    codex exec --full-auto --sandbox read-only \
      --cd "C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app" \
      "以下のE2Eテスト計画をレビューしてください。テスト対象の漏れがないか、優先順位は適切か確認してください。
    <テスト計画>
    承認の場合は「承認」、修正が必要なら具体的な修正内容を回答してください。"
    ```
    タイムアウト: 120秒

    #### 5-9b: テスト実行（Playwright MCP）
    ```
    # 1. ブラウザを開く
    browser_navigate → https://preview.usacon-ai.com

    # 2. ビューポート設定（修正内容に応じて）
    browser_resize → SP: 375x667 / PC: 1280x720

    # 3. ログイン → UI操作で画面遷移（URL直打ち禁止）
    #    テストアカウント: usacon SKILL.md のテストアカウント参照

    # 4. 操作フロー実行（5-9aのテスト計画に従う、表示確認だけでは不十分）:
    #    - テスト対象マトリクスの「操作フロー」列に記載された操作を順に実行
    #    - 各操作ステップで browser_click / browser_type / browser_fill_form 等を使用
    #    - 操作結果の状態変化（画面遷移、データ反映、トースト表示等）を確認
    #    - Issue起点の場合: 元のバグ再現手順を最初に実行し、修正されていることを確認
    #    ⚠️ 操作フロー完了の4要素: 開始条件確認 → 手順実行(2アクション以上) → 状態変化確認 → 証跡記録

    # 5. 表示確認（操作フロー実行の補助として）:
    #    - browser_snapshot（アクセシビリティツリーで内容検証）
    #    - browser_take_screenshot（視覚的証跡）
    #    - 期待するコンテンツが存在することを確認

    # 6. コンソールエラーチェック
    browser_console_messages level: "error" → 0件確認

    # 7. ブラウザを閉じる
    browser_close
    ```

    #### 5-9c: テスト結果の判定
    - **全PASS** → TaskUpdateでタスク8を完了 → ステップ5-10へ
    - **FAIL（リトライ上限: 2回まで）**:
      1. 失敗原因を分析・修正
      2. staging向けに修正PR作成（`gh pr create --base staging`）またはhotfix直接push
      3. `gh pr merge --squash` でstagingに再マージ
      4. `vercel-watch -Environment Preview` でデプロイ完了待機
      5. ステップ5-9b（テスト実行）を再実行
      ※ タスク8はin_progressのまま維持
    - **2回リトライ後もFAIL（合計3回テスト失敗）**:
      1. Codexに失敗内容と修正案を送信（codex exec）
      2. Codexが解決策を提示 → 最終修正 → staging再マージ → 最終テスト実行
      3. それでもFAIL → SendMessageでリーダーに報告し判断を仰ぐ

    **E2Eテスト失敗時のSendMessage報告（各FAIL時）：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        ⚠️ **E2Eテスト失敗（N回目/最大3回）**
        - 失敗画面: [画面名]
        - 失敗原因: [原因]
        - 修正内容: [修正の要約]
        → 修正後にstagingに再マージし再テストを実行します
      summary: "E2Eテスト失敗・再テスト中"
    ```

    **タスク8完了のSendMessage報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        ✅ **ステップ5-9完了: E2Eテスト全PASS**

        **テスト結果マトリクス:**
        | # | 画面 | テスト方法 | 結果 |
        |---|------|-----------|------|
        | 1 | [画面名] | [方法] | PASS |
        | 2 | [画面名] | [方法] | PASS |

        **コンソールエラー:** 0件
        **スクリーンショット:** [N]枚撮影

        → ステップ5-10（Issueクローズ）に進みます
      summary: "E2Eテスト全PASS"
    ```

    ### ステップ5-10: Issueクローズ + 関連Issueスキャン

    **E2E成功後にのみ実行（E2E成功前のクローズ禁止）。**

    ```bash
    # 1. メインIssueのクローズ
    gh issue close <番号> --comment "✅ E2Eテスト完了。preview環境で動作確認済み。PR #<PR番号>"

    # 2. 関連Issueの網羅的スキャン（Issue #1020閉じ忘れ教訓）
    gh issue list --state open --search "<機能名キーワード>" --limit 20
    gh issue list --state open --search "<Issue番号>" --limit 20

    # 3. 関連性の判定（誤クローズ防止）
    #    - Issue本文に親Issue番号を明示的に参照しているもの → 関連
    #    - 同一機能ラベルを持つもの → 関連
    #    - キーワード一致だけで無関係なもの → スキップ
    #    → 判断に迷う場合はCodexに確認

    # 4. 確認済みの関連Issueのみ閉じる
    gh issue close <関連issue番号> --comment "PR #<PR番号> で実装済み。E2Eテスト完了。"

    # 5. 最終確認: 関連Issue 0件になるまでスキャンを繰り返す
    ```

    **タスク9完了のSendMessage報告：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🔒 **ステップ5-10完了: Issueクローズ**

        - Issue #<番号>: クローズ済み
        - 関連Issue: [N]件スキャン → [M]件追加クローズ
          - #XX: [タイトル]
          - #YY: [タイトル]

        → ステップ5-11（staging→mainマージPR作成）に進みます
      summary: "Issueクローズ完了"
    ```

    ### ステップ5-11: staging→mainマージPR作成

    PR作成は自動実行するが、**マージ自体はユーザー承認待ち**（usaconルール準拠）。

    ```bash
    # 1. staging-to-main-merge.md チェックリスト自動実行
    #    - 重複修正ファイル確認
    #    - 関連Issueクローズ確認（ステップ5-10で完了済み）
    git diff origin/main..origin/staging --name-only

    # 2. staging→main PR作成
    gh pr create --base main --head staging \
      --title "Release: <機能名>" \
      --body "$(cat <<'EOF'
    ## Summary
    - Issue #<番号>: <タイトル>
    - E2Eテスト完了（preview環境で動作確認済み）
    - 関連Issue全件クローズ済み

    ## Test plan
    - [x] staging E2Eテスト完了
    - [x] コンソールエラー0件確認
    - [ ] 本番デプロイ後の動作確認

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    EOF
    )"

    # 3. PR checksをバックグラウンドで監視
    gh pr checks <PR番号> --watch
    ```

    **タスク10完了 + 最終報告のSendMessage：**
    ```
    SendMessage:
      type: "message"
      recipient: "leader"
      content: |
        🎉 **Issue #<番号> パイプライン全完了**

        **📋 実装サマリ:**
        - 概要: [実装した内容を1-2文で]
        - 変更ファイル数: [N]
        - ブランチ: feat/issue-XX-description

        **🔍 品質チェック結果:**
        - Lint + 型チェック + ビルド: 全PASS
        - クアドレビュー: 信頼度≥80の指摘 [N]件 → 全対応済み
        - E2Eテスト: 全PASS（[N]画面）
        - コンソールエラー: 0件

        **📌 ステータス:**
        - staging PR: #YY → squashマージ済み
        - Issueクローズ: #<番号> + 関連[M]件
        - **mainマージPR: #ZZ → ユーザー承認待ち**

        **Codex判断ログ:**
        - [判断1の要約]
        - [判断2の要約]

        ⚠️ **mainマージPR #ZZ のマージ承認をお願いします。**
      summary: "パイプライン全完了・mainマージPR承認待ち"
    ```

    ## 絶対に守るべきルール（ガードレール）

    1. **PRをstagingにマージする前に、必ずクアドレビュー（Codex差分 + /sub-review 4エージェント + /code-review = 計6 Task並列）を実施すること**
    2. **クアドレビューなしのマージは禁止**
    3. **Lint + 型チェック + ビルドが全パスしない状態でPRを作成しない**
    4. **自動継続パイプラインの途中で停止しない**
    5. **信頼度≥80の指摘は必ず対応してからマージすること**
    6. **vercel-watch Ready検知後、E2Eテスト実施せず完了報告してはならない**
    7. **E2Eテスト成功前にIssueをクローズしてはならない**
    8. **テスト対象のスキップはCodex承認必須（独断スキップ禁止）**
    9. **staging→mainマージPR作成は自動、マージ自体はユーザー承認必要**

    ### プロジェクトディレクトリ
    C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app
```

### Step 4: メインコンテキストでの対応

ワーカーを起動したら、ユーザーに以下を伝える：
「ワーカーを起動しました。進捗はリアルタイムで表示されます。」

ワーカーからSendMessageで進捗報告が届くたびに：
1. 報告内容をそのままユーザーに見せる（自動表示される）
2. 必要に応じてコメントを添える
3. ユーザーが介入を希望した場合、ワーカーにSendMessageで指示を送る

### Step 5: 完了処理

ワーカーから最終報告（タスク10完了）を受け取ったら：
1. ユーザーに「mainマージPR #ZZ のマージ承認をお願いします」と表示
2. ユーザー承認 → ワーカーにSendMessageでマージ指示を送信
   ```
   SendMessage:
     type: "message"
     recipient: "implementer"
     content: "mainマージPR #ZZ のマージを承認します。gh pr merge --merge を実行し、vercel-watch Productionで本番デプロイ完了を監視してください。"
     summary: "mainマージ承認"
   ```
3. ワーカーが以下を実行:
   - `gh pr merge <PR番号> --merge`（staging→mainは--merge推奨）
   - `powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Environment Production -Interval 10`
   - 本番デプロイ完了をSendMessageで報告:
   ```
   SendMessage:
     type: "message"
     recipient: "leader"
     content: |
       ✅ **本番デプロイ完了**
       - mainマージPR: #ZZ → mergeマージ済み
       - Vercel Production: Ready検知済み
       - 本番URL: https://usacon-ai.com
     summary: "本番デプロイ完了"
   ```
4. ワーカーをシャットダウン（SendMessage type: "shutdown_request"）
5. TeamDeleteでチームを削除

**ユーザーがmainマージを承認しない場合:**
- **修正要求**: リーダー → ワーカーにSendMessageで修正指示 → ワーカーがステップ5-1〜5-9を再実行 → 新しいstaging→main PRを作成
- **却下**: リーダー → ワーカーにshutdown_request → TeamDelete（PRは残す）

## 複数Issue対応

複数のIssue番号が渡された場合（例: `#10 #11 #12`）：
1. Codexに優先順位を判断させる（Bashで`codex exec`）
2. 1つのチーム内で優先度順に1つずつワーカーを起動する
3. 各Issueの完了報告がリアルタイムで表示される

## ユーザー介入ポイント

Agent Teams方式では、ワーカーの進捗報告時にユーザーが介入できる：
- **方向修正**: リーダー経由でワーカーにSendMessageで指示を送信
- **中断**: ワーカーにshutdown_requestを送信
- **質問**: ワーカーにSendMessageで質問→ワーカーが回答を返す

## 注意事項

- ワーカーはrun_in_background: trueで起動すること（リアルタイム報告のため）
- ワーカーのSendMessageのrecipientは必ず "leader" とする
- Issue1つあたり1つのワーカー（コンテキスト分離）
- ワーカー内でCodexを呼ぶ際はBashツールで直接実行してよい
