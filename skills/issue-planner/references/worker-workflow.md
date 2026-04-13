<!-- 抽出元: SKILL.md「ワーカーワークフロー（7ステップ）」セクション（旧 行369-449）
     + 「ワーカープロンプトテンプレート」セクション（旧 行630-891） -->

# ワーカーワークフロー（Grok補助分析対応版）

## Step 1: タスク取得

```
TaskList -> 未着手タスクを確認
TaskGet(taskId) -> 詳細取得
TaskUpdate(taskId, status: "in_progress") -> 作業開始
```

## Step 2: Issue詳細取得

```bash
gh issue view {number} --repo owner/repo --json title,body,labels,comments
```

### Step 2.1: 既存計画・追加報告チェック（Issue #1560教訓）

**既存計画の検出**: Issue コメントに `## 実装計画` / `## Implementation Plan` が複数ある場合（別AIが先に計画を投稿済み）:
1. 最新の計画コメントを読み、自計画に欠けている観点を比較チェック
2. 特に「テスタビリティ（`__testables` export）」「単位契約JSDoc」「エッジケース防御」を確認
3. 優れた点は自計画に取り込み、レビュースコアセクションに「別AI計画から取り込み: {項目}」と明記

**追加報告の分離判定**: Issue コメントに本文と異なる再現手順や追加事例がある場合:
1. 原因経路がIssue本文と同一か確認（同じファイル・同じ変換ロジックか）
2. 異なる原因経路の場合は**別Issueとして起票**し、計画の「非対象」に記載
3. 起票コマンド: `gh issue create --repo {owner}/{repo} --title "Bug: {概要}" --label "bug" --body "{本文}"`

## Step 2.5: ブランチ検証（Issue #1808教訓 — コード調査前の必須チェック）

**目的**: コード調査（Step 3）の前に、ローカルリポジトリが正しいブランチにいることを確認する。
ローカルの default ブランチ（main）を読んで、staging に先行マージされた変更を「未実装」と誤判定することを防ぐ。

**事例**: Issue #1808 では Blob Client Upload 移行が staging に既にマージ済みだったが、
レビュアーが main ブランチのコードを参照し「Blob移行未完了」と誤判定。critical指摘2件が事実と異なった。

#### git fetch 必須（Issue #1798教訓）

ブランチ検証の前に、必ずリモートの最新状態を取得する:

```bash
git fetch --all
```

これを省略すると、ローカルに存在しないブランチやファイルに基づいて「機能が存在しない」と誤判定するリスクがある。

- Issue が「本番にある機能」に言及している場合: `origin/main` を基準に調査
- Issue が「開発中の機能」に言及している場合: `origin/staging` を基準に調査

### 手順

```bash
# 2.5a: Issue本文に参照PRがあるか確認
REFERENCED_PRS=$(echo "{issue_body}" | grep -oP '#\d+' | sort -u)
for pr_num in $REFERENCED_PRS; do
  gh pr view ${pr_num#\#} --repo {owner}/{repo} --json state,baseRefName,mergedAt \
    --jq '{number: .number, state: .state, base: .baseRefName, merged: .mergedAt}' 2>/dev/null
done

# 2.5b: 調査対象ブランチを決定
TARGET_BRANCH="staging"  # デフォルト

# 2.5c: ローカルリポジトリのブランチを切り替え
CURRENT_BRANCH=$(git -C "{project_dir}" branch --show-current)
if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  git -C "{project_dir}" stash --include-untracked 2>/dev/null
  git -C "{project_dir}" checkout "$TARGET_BRANCH" 2>/dev/null
  git -C "{project_dir}" pull --ff-only 2>/dev/null
fi
```

### 判定ルール

| 条件 | 調査対象ブランチ |
|------|----------------|
| Issue参照PRが staging にマージ済み | staging |
| Issue参照PRが main にマージ済み | main |
| PR参照なし | staging（デフォルト） |
| staging が存在しない | main にフォールバック |

### サブエージェントへの指示

Codex Scout や Explore に渡すプロンプトには以下を含めること:
```
調査対象のコードは **{TARGET_BRANCH} ブランチ** を基準にしてください。
```

### クリーンアップ

Issue処理完了後に元のブランチに戻す:
```bash
git -C "{project_dir}" checkout "$CURRENT_BRANCH" 2>/dev/null
git -C "{project_dir}" stash pop 2>/dev/null
```

## Step 3: 事前調査 + Grok補助分析 + Codex本調査

Step 3 は以下の3段構成に分ける。

1. **Step 3.0: Codex Scout** で軽い事前調査を行い、候補ファイルと Grok 起動要否を JSON 化する
2. **Step 3.1: Grok Context Synthesis** を条件付きで実行し、長文Issue・大量コメント・外部知見・X由来知見を整理する
3. **Step 3.2: Codex Main Analysis** で最終的な実装計画の材料を作る

### Step 3.0: Codex Scout（軽量事前調査）

**目的**: いきなり重い本調査を回さず、候補ファイル、複雑度、Grok起動条件を先に抽出する。  
**重要**: Scout は軽量運用とし、**Bash tool timeout: 240000ms（4分）** を上限にする。

```bash
# ステップ3.0a: Scoutプロンプトをtmpファイルに書き出す
cat > /tmp/issue_planner_scout_{number}.txt << 'SCOUT_EOF'
あなたは issue-planner の Codex Scout です。GitHub Issue の軽量な事前調査だけを行ってください。

[Issue]
- 番号: #{number}
- タイトル: {title}
- 本文: {body（1000文字以内に要約）}
- コメント数: {comment_count}

[タスク]
1. 分類を推定する（bug / feature / improvement / refactoring）
2. 関連しそうな候補ファイルを最大8件まで列挙する
3. 事前Tierスコアを推定する
4. 曖昧点を列挙する
5. 外部依存・コミュニティ知見・Xポスト横断収集が必要か判定する
6. Grok を起動すべきか `auto/on/off` 前提で recommendation を返す

[出力形式]
JSONのみ:
{
  "issue_number": {number},
  "classification": "bug|feature|improvement|refactoring",
  "candidate_files": ["path", "..."],
  "pre_tier_score": 0,
  "pre_tier_signals": ["signal", "..."],
  "ambiguity_flags": ["...", "..."],
  "community_evidence_needed": true,
  "grok_recommendation": {
    "should_run": true,
    "activation_signals": ["...", "..."]
  }
}
SCOUT_EOF

# ステップ3.0b: Codex Scout 実行
# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/issue_planner_scout_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="medium" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_scout_{number}_$$.txt
SCOUT_EXIT=${PIPESTATUS[0]}

# ステップ3.0c: 結果確認
if [ $SCOUT_EXIT -ne 0 ]; then
  echo "=== Codex Scout異常終了 (exit=$SCOUT_EXIT) ==="
  cat /tmp/codex_scout_{number}_$$.txt
fi

rm -f /tmp/issue_planner_scout_{number}.txt
```

**Scout 出力要件**:
- `candidate_files` は最大8件
- `pre_tier_score` は 0 以上の整数
- `community_evidence_needed=true` の場合は Step 3.1 で `mode=extended_knowledge` を検討する

### Step 3.1: Grok Context Synthesis（条件付き）

**目的**: 長文Issue、大量コメント、外部依存、Xポスト由来知見が必要な場合だけ、Grok に文脈整理をさせる。  
**重要**: **Grok timeout は既定で 600000ms（10分）** を使う。短い値に落とさない。

**起動条件（`--grok auto`）**:
- 外部依存シグナルあり
- Issue本文 + コメントが6000字以上
- コメント6件以上
- `candidate_files` が8件以上
- `pre_tier_score >= 6`
- `community_evidence_needed=true`

**モード判定**:
- `mode=repo_context_only`: 通常の補助分析
- `mode=extended_knowledge`: X / Twitter / community feedback / ユーザー報告多数 / 業界動向 / 外部サービスの実運用知見が必要

**成果物**: `tasks/issue-planner/grok/issue-{number}.json`

```bash
# ステップ3.1a: Grok出力先ディレクトリ作成
mkdir -p "{project_dir}/tasks/issue-planner/grok"

# ステップ3.1b: Grokプロンプト作成
cat > /tmp/grok_issue_{number}.txt << 'GROK_EOF'
あなたは issue-planner の補助分析担当です。
コードを書かず、長いIssue・大量コメント・外部知見を整理してください。

[Issue]
- 番号: #{number}
- タイトル: {title}
- 本文: {body}
- コメント: {comments_summary}

[Codex Scout]
{codex_scout_json}

[出力形式]
JSONのみ:
{
  "issue_number": {number},
  "model": "x-ai/grok-4.20-multi-agent",
  "mode": "repo_context_only|extended_knowledge",
  "status": "success|partial_timeout|timeout|skipped_auth|skipped_parse_error",
  "timeout_ms": 600000,
  "activation_signals": ["...", "..."],
  "problem_frame": "...",
  "repo_focus": ["...", "..."],
  "external_knowledge": [
    {
      "claim": "...",
      "source_type": "docs|community|x_post|general_knowledge",
      "confidence": "high|medium|low",
      "verification_required": true
    }
  ],
  "x_signal_summary": [
    {
      "claim": "...",
      "source_type": "x_post",
      "confidence": "high|medium|low",
      "verification_required": true
    }
  ],
  "risk_hypotheses": ["...", "..."],
  "questions_for_codex": ["...", "..."],
  "non_goals": ["...", "..."]
}
GROK_EOF

# ステップ3.1c: Grok 実行（OpenRouter経由の例）
# *** Bash tool timeout: 600000 を必ず指定すること ***
if [ -z "$OPENROUTER_API_KEY" ]; then
  echo '{"issue_number": {number}, "model": "x-ai/grok-4.20-multi-agent", "status": "skipped_auth", "timeout_ms": 600000}' \
    > "{project_dir}/tasks/issue-planner/grok/issue-{number}.json"
else
  RESPONSE=$(curl -s -w "\n%{http_code}" https://openrouter.ai/api/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -d "$(jq -n --arg model "x-ai/grok-4.20-multi-agent" --rawfile prompt /tmp/grok_issue_{number}.txt \
      '{model: $model, max_tokens: 4000, messages: [{role: "user", content: $prompt}]}')" )

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    echo "$BODY" | jq -r '.choices[0].message.content // ""' > "{project_dir}/tasks/issue-planner/grok/issue-{number}.json"
  else
    echo "{\"issue_number\": {number}, \"model\": \"x-ai/grok-4.20-multi-agent\", \"status\": \"timeout\", \"timeout_ms\": 600000, \"http_code\": \"$HTTP_CODE\"}" \
      > "{project_dir}/tasks/issue-planner/grok/issue-{number}.json"
  fi
fi

rm -f /tmp/grok_issue_{number}.txt
```

**Grok のフォールバック**:

| 状況 | 対応 | リトライ |
|------|------|---------|
| `OPENROUTER_API_KEY` 未設定 | `skipped_auth` を保存し Codex 単独へ降格 | 0回 |
| HTTP 402 / 429 | 1回だけ再試行、それでも失敗なら `timeout` | 1回 |
| JSONパース失敗 | `skipped_parse_error` を保存し Codex 単独へ降格 | 1回 |
| 10分タイムアウト | 部分出力があれば `partial_timeout` として保存し Codex へ補助情報として渡す | 1回 |

#### Grok知見の信頼境界フィルタリング（教訓: 2026-04-12）

Grokからの応答を計画に組み込む際は、以下のフィルタを適用する:

| カテゴリ | 扱い | 計画への組み込み |
|---------|------|----------------|
| ファイルパス・行番号 | **未検証** | ローカルで `ls` / `grep` で実在確認してから記載 |
| API仕様・ライブラリバージョン | **未検証** | Context7 or 公式ドキュメントで照合 |
| Xポスト・コミュニティ知見 | **未検証** | `verification_required: true` タグ付きで補足セクションに記載。計画本文には入れない |
| 長文Issue・コメントの要約 | **検証済み** | 原文がIssue内に存在するため信頼可能 |

> **原則**: `verification_required: true` の知見を計画本文（実装ステップ）に直接含めない。必ず「Grok補助分析メモ」セクションに分離する。

### Step 3.2: Codex Main Analysis

**重要**: stdin経由でプロンプトを渡し、API 400エラーを回避する。  
**重要**: Bash tool timeout: 300000ms（5分）を必ず指定すること。  
**重要**: Grok の内容は補助情報であり、ファイルパス・行番号・型・API可否は Codex 自身が再検証する。

```bash
# ステップ3.2a: プロンプトをtmpファイルに書き出す
cat > /tmp/issue_planner_prompt_{number}.txt << 'CODEX_PROMPT_EOF'
あなたはシニアフルスタックエンジニアです。以下のGitHub Issueを分析し、実装計画を作成してください。

[Issue]
- 番号: #{number}
- タイトル: {title}
- 本文: {body（500文字以内に要約。2000文字超は冒頭500文字のみ）}

[Codex Scout]
{codex_scout_json}

[Grok Context]
{grok_context_json_or_status}

[重要な制約]
- Grok の内容は補助情報です
- ファイルパス、行番号、型、API可否、既存実装の有無は必ず自分で確認してください
- `verification_required=true` の知見は、裏取りできた場合のみ採用してください

[分析タスク]
1. 関連するソースコードファイルを特定（ファイルパスと行番号）
2. 根本原因を分析（バグの場合）/ 実装箇所を特定（機能の場合）
3. 影響範囲を洗い出す（変更が波及するファイル）
4. 具体的な変更提案（Before/Afterコード付き）
5. テスト計画を作成
6. リスクを評価
7. 工数を見積もる（S: ~2h / M: 2-8h / L: 8-24h / XL: 24h+）
8. E2E受け入れ条件を定義する（画面・URL・操作フロー・期待結果）

[出力形式]
以下のセクションに分けて日本語で出力してください:
- 分類: bug / feature / improvement / refactoring
- 工数見積: S/M/L/XL
- 優先度: P0(即時) / P1(今スプリント) / P2(次スプリント) / P3(バックログ)
- 影響度: 高/中/低
- 原因分析: {根本原因の説明}
- 影響範囲: ファイルパス:行番号 のリスト（変更種別: 新規/修正/削除）
- 依存関係: 前提Issue / 外部依存
- 実装ステップ: 番号付きリスト（対象ファイル + 具体的変更内容 + Before/Afterコード）
- リスク: リスク内容 + 確率(高/中/低) + 対策
- テスト計画: テスト項目のリスト
- 検証手順: 手動確認手順
- E2E受け入れ条件: 以下の形式で記述
  - 合格基準: 測定可能な1文
  - テスト項目（各項目に: 画面名, URL, 操作フロー「開始条件→操作1→操作2」, 期待結果, 深度L1/L2, 優先度high/medium）
  - bugの場合: 再現手順→修正後の正常動作確認を含めること
  - featureの場合: 主要ユースケースの操作フローを含めること
  - 前提条件: テスト実行に必要な状態（ログイン、テストデータ等）
- スコープ外: この Issueでは対象外とする事項

確認や質問は不要です。必ず上記のすべてのセクションを含む完全な分析結果を出力してください。
CODEX_PROMPT_EOF

# ステップ3.2b: Codex Main Analysis 実行
# *** Bash tool timeout: 300000 を必ず指定すること ***
cat /tmp/issue_planner_prompt_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="high" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_output_{number}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}

# ステップ3.2c: 異常終了時の部分結果回収
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Codex Main Analysis異常終了 (exit=$CODEX_EXIT) ==="
  echo "=== 部分結果回収 ==="
  cat /tmp/codex_output_{number}_$$.txt
fi

rm -f /tmp/issue_planner_prompt_{number}.txt
```

**Bash tool timeout**:
- Codex Scout: `240000ms`
- Grok Context Synthesis: `600000ms`
- Codex Main Analysis: `300000ms`

### Codexエラー時のフォールバック（5段階）

| 試行 | 対策 | 変更点 | Bash timeout |
|:---:|------|--------|:---:|
| 0回目 | 部分出力回収 | /tmp/codex_output_{number}_$$.txt から回収。分析セクションが十分なら採用 | — |
| 1回目 | プロンプト短縮 | 本文を200文字に圧縮、分析タスクを3項目に削減 | 300000ms |
| 2回目 | reasoning_effort引下げ | `model_reasoning_effort="medium"` | 240000ms |
| 3回目 | Git除外 | `--skip-git-repo-check` 追加 | 240000ms |
| 最終 | スキップ | リーダーに報告して次のIssueへ | — |

**クリーンアップ**: 成功・スキップ問わず、Issue処理完了時に `rm -f /tmp/codex_scout_{number}_$$.txt /tmp/codex_output_{number}_$$.txt` を実行する。Grok 成果物は `tasks/issue-planner/grok/issue-{number}.json` に残す。

## Step 3.2b: bug原因の重点チェック

bug分類のIssueでは、通常の関連ファイル特定に加えて以下を**必ず**確認する。

### 3.2a 時間/状態ゲートの失効チェック

`cooldown` / `debounce` / `rate limit` / `threshold count` / `retry` / `reset` が共存する場合、
「条件達成した仕事がブロック時に失われないか」を見る。

チェック項目:
- カウンタ更新箇所
- 閾値判定箇所
- 時間ゲートで `return` する箇所
- 保留状態 (`pending`, `last_processed_count` 等) の有無
- リセット時に保留状態まで消しているか

### 3.2b 表示ソースの整合チェック

同じ概念を複数UIで表示している場合、各表示がどのデータソースを参照しているかを分解する。

例:
- 最新表示: `current.md` 内メタデータ
- 履歴表示: Storage / DB の `created_at`
- バッジ表示: `user_settings.meta`

→ 同一イベントを別ソースから描いている場合、表示不整合の可能性を原因分析に明記する。

### 3.2c LLM/外部生成メタデータの信頼境界

`version` / `updated_at` / `status` / `count` などのメタデータを
LLMや外部APIが返す本文に含めている場合は、
「サーバー側で再計算・再付与しているか」を確認する。

チェック項目:
- 保存前にメタデータを正規化しているか
- バリデーションが本文だけでなくメタデータ整合性も見ているか
- サーバー所有値なのに外部生成値をそのまま信じていないか

## Step 3.5: コード現状検証（Issue #1232教訓）

**Codex Main Analysis 後、計画組み立て前に、変更対象ファイルの現在の状態を検証する。**
計画が最新コードと乖離していると、実装時に「計画の前提が崩れている」問題が発生する。

```bash
# 3.5a: Codexが特定した変更対象ファイルの最新コミットを確認
for file in {Codexが特定したファイルパス一覧}; do
  echo "=== $file ==="
  git -C "{project_dir}" log --oneline -5 -- "$file"
done

# 3.5b: 関連する最近のマージ済みIssueを確認（直近2週間）
gh pr list --repo {owner}/{repo} --state merged --limit 20 --json title,mergedAt,files \
  --jq '.[] | select(.files | any(. == "{対象ファイル}")) | "\(.mergedAt) \(.title)"'
```

**検証チェックリスト:**

| チェック項目 | 確認方法 | 乖離発見時の対応 |
|------------|---------|----------------|
| 対象ファイルが他Issueで最近変更されていないか | `git log -5 -- <file>` | 計画の前提（Before コード）を更新 |
| 計画で「移行が必要」としたパターンが既に移行済みでないか | ファイルの該当行を Read で確認 | 該当ファイルを計画から除外 |
| 新しいユーティリティやヘルパーが追加されていないか | Grep で関連パターンを検索 | 既存ユーティリティを活用するよう計画を修正 |

**複雑度分類（対象ファイルごと）:**

| データフェッチパターン | 複雑度 | 工数目安 |
|---------------------|--------|---------|
| 単純useQuery / 単一テーブル | 低 | 小（5行程度） |
| 複数テーブル並列fetch / Promise.allSettled | 中〜高 | 中〜大（ロジック移動が必要） |
| 依存チェーン（パラメータ依存） | 中 | 中（ファクトリ関数設計が必要） |
| カスタムフック内の複合ロジック | 高 | 大（分離設計が必要） |

→ この分類結果は計画テンプレートの「影響範囲」テーブルの「複雑度」列に反映する。

### Step 3.5b: 外部依存の実現可能性検証（条件付き — Issue #1577教訓）

**トリガー条件**: Issue本文またはCodex出力に以下のシグナルが含まれる場合のみ実行する。
シグナルがなければこのサブステップをスキップし、Step 4に進む。

**シグナル検出（Issueタイトル+本文+Codex出力から判定）:**

| シグナル | 例 | 検証が必要な理由 |
|---------|-----|----------------|
| 外部ライブラリ/サービスの新規導入 | "MCP", "freee-mcp", "@ai-sdk/mcp" | 存在・互換性・環境制約が未確認 |
| 外部APIとの新規連携 | "OAuth", "REST API", "webhook" | 認証フロー・レート制限・データ形式が未確認 |
| 実行環境の制約に関わる技術選択 | "stdio", "子プロセス", "常駐サーバー" | サーバーレス環境での制約が未検証 |
| 複数の実装方式が提案されている | "方式A vs 方式B", "REST vs MCP" | どちらが妥当か技術的根拠が必要 |

**検証手順（シグナル検出時のみ）:**

```
1. 外部依存の実在確認
   - npm/GitHub/公式ドキュメントの存在確認（WebSearch）
   - バージョン・メンテナンス状況・Stars数
   - ライセンス互換性

2. 環境制約の検証
   - Vercel Functions（サーバーレス）での動作可否
   - Transport方式（stdio/HTTP/SSE）の確認
   - 追加インフラの要否

3. 既存コードとの統合可能性
   - 現在のSDK/ライブラリバージョンとの互換性
   - 既存パターン（gbizinfoService等）での代替可否
   - AI SDK vs Anthropic SDK直接利用の判断

4. 方式比較（複数案がある場合）
   - 各方式の工数・運用コスト・拡張性を表形式で比較
   - 推奨方式とその根拠を明記
```

**出力**: 計画テンプレートの「設計判断」テーブルに「方式」行として反映。
棄却した方式がある場合は「非対象」セクションに棄却理由を記載。

**所要時間**: 5-10分（WebSearch + Grep/Read）。
全Issueの10-15%程度でのみ発動するため、バッチ全体のスループットへの影響は軽微。

## Step 3.6: Tier判定（動的レビュアー数決定 — fortress-review方式）

Step 3.0（Codex Scout）+ Step 3.1（Grok Context Synthesis）+ Step 3.2（Codex Main Analysis）+ Step 3.5（コード現状検証）+ Step 3.5b（該当時）の結果から、15シグナルをスキャンしスコアでTierを判定する。

### シグナルテーブル

| カテゴリ | シグナル | 重み | 検出パターン |
|---------|---------|------|------------|
| データ層 | DB migration | 5 | Codex出力に ALTER TABLE/CREATE TABLE/migrationファイル |
| データ層 | データモデル・型定義変更 | 3 | interface/type変更、*.d.ts、types.ts |
| データ層 | キャッシュ戦略変更 | 3 | cache/TTL/invalidate/revalidate |
| 認証・課金 | 認証/認可ロジック変更 | 5 | auth/middleware/JWT/RLS/getUserId |
| 認証・課金 | 課金・サブスク変更 | 5 | stripe/billing/credit/subscription |
| 認証・課金 | RLSポリシー変更 | 4 | CREATE POLICY/ALTER POLICY/service_role |
| アーキテクチャ | 公開API契約変更 | 4 | route.ts/api/新規エンドポイント |
| アーキテクチャ | 新規外部依存の導入 | 2 | Step 3.5bトリガー条件=true |
| アーキテクチャ | アーキテクチャパターン変更 | 4 | SSE/WebSocket/middleware/新規レイヤー |
| 影響範囲 | 変更ファイル6個以上 | 2 | 影響範囲テーブルのファイル数>=6 |
| 影響範囲 | 複数モジュール横断 | 3 | api/+ui/+db/等3ディレクトリ以上 |
| 影響範囲 | データ経路3本以上 | 3 | SSE/REST/polling等3本以上 |
| 運用リスク | ロールバック困難 | 5 | 破壊的migration/外部API契約変更 |
| 運用リスク | 過去障害領域 | 3 | git logにfix/hotfixコミット直近3ヶ月内 |
| 運用リスク | フィーチャーフラグなし | 2 | 段階的ロールアウト機構の言及なし |

### Tier閾値

| Tier | スコア | レビュアー数 | completion_rate閾値 |
|------|--------|------------|-------------------|
| A: 要塞 | >= 12 | 4体 (A+B+C+D) | >= 75% (3/4) |
| B: 重要 | >= 6 | 3体 (A+B+C) | >= 67% (2/3) |
| C: 標準 | < 6 | 2体 (A+C) | >= 50% (1/2) |

### 内部変数（Step 4.5で使用）

判定結果を以下の変数として保持する:
- `tier`: A / B / C
- `tier_score`: 合計スコア
- `tier_breakdown`: data={N},auth={N},arch={N},scope={N},ops={N}
- `tier_reviewer_count`: 2 / 3 / 4
- `tier_completion_threshold`: 50% / 67% / 75%

## Step 4: 計画組み立て

Codex Main Analysis の出力 + Step 3.2b の bug重点チェック + Step 3.5 + Step 3.5b（該当時）の検証結果を統合し、実装計画テンプレートに構造化する。
Grok の出力は「補助情報」として参照できるが、未検証の外部知識や Xポスト由来知見をそのまま本文へ転記してはならない。
Codex出力に不足がある場合は、Grep/Readで補足調査を行う。

### Step 4 補足: 既存ユーティリティの適用可否判定（Issue #1560教訓）

Codex出力や計画で「新規ヘルパー関数」を提案する場合、以下の判定を行う:

| チェック | 判定方法 | 不適用時の記載 |
|---------|---------|--------------|
| 同名・類似名の関数が既にあるか | `grep -rn "function.*{類似名}" {project_dir}/` | 「{関数名}(L{行})は{理由}のため不適用」 |
| 入力型が一致するか | 既存関数の引数型（文字列 vs 数値 vs オブジェクト）を確認 | 「入力は数値型だが{関数名}はL{行}で数値をそのまま返す」 |
| 操作が一致するか | フォーマット変換 vs 単位変換 vs バリデーション を区別 | 「{関数名}はフォーマット変換であり、単位変換(x10000)は行わない」 |

**Aスコアのポイント**: 「不要です」ではなく「{関数名}のL{行}で{入力型}は{動作}のため、本件の{操作}には適用できない」と**行番号で反証**する。

## Step 4.2: 計画前提の実在性検証（Issue #1638教訓）

計画草案に含まれる前提を実コードと照合し、仮定の正当性を検証する。
（詳細は `design-review-checklist` Phase 8 を参照）

**必須チェック（全Issue対象）:**

| チェック | 検証方法 | Issue #1638での失敗例 |
|---------|---------|---------------------|
| 再利用関数のexport確認 | `grep -n "module.exports\|export " {ファイル}` | SSEヘルパー・collectSubsidyFilesがローカル関数だった |
| プロパティ名の正確性 | `grep -n "{プロパティ名}" {ファイル}` | selectedCompanyId → 実際はselectedCompany?.id |
| API/ライブラリの入力形式 | 公式ドキュメント確認 | Claude Vision APIはExcel非対応（PDF/画像のみ） |
| 本番環境設定の網羅性 | config.toml等のスコープ確認 | StorageバケットがローカルのみでCritical漏れ |

**条件付きチェック（XL工数 or feat種別のみ）:**

| チェック | トリガー | 検証方法 |
|---------|---------|---------|
| MVPスコープの実データ妥当性 | 新機能（feat） | ターゲットドメインの実データ形式を調査 |
| データパイプライン完全性 | 3関数以上のチェーン | 主要関数の前後パイプラインをトレース |
| HTTP/クライアントパターン整合 | 新規API追加 | GET/POST、axios/fetch/fetchEventSourceの使い分けを明記 |

**出力**: 未検証の前提が見つかった場合、計画を修正してから Step 4.3 に進む。

## Step 4.3: Issue突き合わせ（計画 vs Issue要件 — Issue #1638教訓）

計画草案完成後、**Issueの全セクション（タイトル・本文・コメント・添付）を再読**し、要件カバレッジを照合する。
（詳細は `design-review-checklist` Phase 9 Gate A を参照）

**手順:**
1. Issue本文の要件（箇条書き・チェックリスト）を1つずつ抽出
2. 各要件を計画ステップにマッピング
3. 未カバーの要件があれば計画に追加するか、除外理由を「Phase N スコープ制約」に明記
4. Issueコメントの追加要件・方針変更が計画に反映されているか確認

**出力（計画テンプレートの末尾に追記）:**

```markdown
### Issue要件カバレッジ
| Issue要件 | 計画ステップ | カバー |
|----------|-----------|-------|
| (Issue本文から抽出) | Step X-Y | ✅/❌ |
```

未カバー率が20%を超える場合は計画を修正してからレビューに進む。

## Step 4.5: 多角的レビュー（+ 完了率ゲート）

計画草案に対してTier別の視点から並列レビューを実施し、品質を向上させる。
（Tier C: 2体、Tier B: 3体、Tier A: 4体 — Step 3.6のTier判定結果に基づく）
（詳細は references/multi-perspective-review.md を参照）

**完了率ゲート判定**: レビュー統合後、以下を算出して投稿可否を確認:
- `review_completion_rate` >= `tier_completion_threshold`（Tier A: 75%, B: 67%, C: 50%）
- `critical_open` == 0（未解消critical指摘なし）
- 条件未達の場合は計画修正 or スキップ

## Step 4.7: Codex final-check（条件付き — レビュー修正後の実装安全性検証）

**目的**: レビュー統合（4.5b）で修正を適用した最終計画が、実装時に矛盾を起こさないか検証する。
設計レビュー（Step 4.5）とは異なり、**「修正後の計画を実装したとき何が壊れるか」**を検証する。

**スキップ条件**: composite_grade が **A** かつ `critical_open == 0` の場合のみ省略可。
（理由: 修正適用がないか軽微のため、矛盾リスクが低い）

**検証観点:**
1. **修正後のBefore/After整合**: レビュー修正で変更されたBefore/Afterコードが実ファイルと一致するか
2. **実装ステップ間の矛盾**: critical修正で追加した変更が他のステップの前提を壊していないか
3. **影響範囲の漏れ**: レビュー修正で新たに追加されたファイルの呼び出し元が影響範囲に含まれているか
4. **型の波及**: 修正でインターフェースや戻り値の型が変わった場合、全呼び出し元が対応しているか

**Codex final-check 実行テンプレート:**

```bash
cat > /tmp/final_check_{number}.txt << 'FINALCHECK_EOF'
あなたは実装安全性の検証者です。以下の実装計画（レビュー修正適用済み）を検証してください。

## 検証タスク
1. Before/Afterコードが実ファイルの最新状態と一致するか確認
2. 実装ステップ間で矛盾がないか確認（ステップAの出力がステップBの入力と整合するか）
3. 影響範囲テーブルに漏れがないか確認（変更ファイルのimport元/参照元）
4. 型変更がある場合、全呼び出し元への波及を確認

## 出力形式（JSON）
{"final_check":"pass|fail","issues":[{"severity":"critical|major","description":"...","fix":"..."}]}

issuesが空なら "pass"、criticalが1件でもあれば "fail"。

## 計画内容（レビュー修正適用済み最終版）
{最終計画のMarkdown全文}
FINALCHECK_EOF

# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/final_check_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="medium" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/final_check_result_{number}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Final-check異常終了 (exit=$CODEX_EXIT) ==="
  cat /tmp/final_check_result_{number}_$$.txt
fi

rm -f /tmp/final_check_{number}.txt
```

**結果ハンドリング:**

| 結果 | アクション |
|------|----------|
| `pass` | Step 5（投稿）へ進む |
| `fail` + critical issues | 指摘箇所を修正し、final-checkを1回再実行 |
| `fail` + major のみ | 指摘を計画に注記として追加し、Step 5 へ進む |
| タイムアウト/異常終了 | final-checkスキップ扱いで Step 5 へ進む（計画に「final-check未完了」を注記） |

**クリーンアップ**: `rm -f /tmp/final_check_result_{number}_$$.txt`（Issue処理完了時）

## Step 5: 投稿

**順序厳守: コメント投稿 -> 成功確認 -> ラベル追加**

```bash
# ステップ5a: 実装計画をコメントとして投稿
gh issue comment {number} --repo owner/repo --body "$(cat << 'PLAN_EOF'
{組み立てた実装計画Markdown}
PLAN_EOF
)"

# ステップ5b: コメント投稿が成功した場合のみラベルを追加
gh issue edit {number} --repo owner/repo --add-label "planned"
```

**重要**: ラベル追加はコメント投稿の**成功後**に行う。逆順だと計画なしでラベルだけ付く。
**必ず `gh issue edit <番号> --add-label planned` を実行すること。**ラベル適用を忘れると、次回のissue-planner実行時に同じIssueが再度計画対象になる（教訓#6）。

**Tier Aの場合の追加ラベル:**
Tier Aの場合、`planned` に加えて `fortress-review-required` ラベルも付与する:
```bash
gh issue edit {number} --repo {owner}/{repo} --add-label "planned,fortress-review-required"
```

## Step 6: 完了報告

```
TaskUpdate(taskId, status: "completed")
SendMessage -> リーダーに結果報告:
  「Issue #{number} '{title}' の実装計画を投稿しました。
   分類: {分類}, 工数: {工数}, 優先度: {優先度},
   tier: {A/B/C}, tier_score: {N}, reviewer_count: {N},
   レビュースコア: {grade}({N}/{tier_reviewer_count}完了),
   grok_used: {true/false}, grok_status: {status}, grok_mode: {mode}, grok_timeout_ms: {N}」

TaskList -> 次の未着手タスクがあれば Step 1 に戻る
```

---

## ワーカープロンプトテンプレート

ワーカーをスポーンする際に使用するプロンプト:

```
あなたは issue-planner チームのワーカーです。
GitHub Issueの実装計画を作成し、Issueコメントとして投稿する作業を担当します。

## 環境情報
- リポジトリ: {owner}/{repo}
- プロジェクトディレクトリ: {project_dir}
- Windows環境、Bash使用

## 作業手順（厳守）

### 1. タスク取得
TaskList で未着手(pending)かつオーナー未設定のタスクを確認してください。
**planner-1はID昇順、planner-2はID降順で取得すること（反対端方式）。**
TaskGet で詳細を取得してから、
TaskUpdate(taskId, status: "in_progress", owner: "{自分の名前}") で作業開始。
オーナーが既に設定されているタスクはスキップすること。

### 2. Issue詳細取得
gh issue view {number} --repo {owner}/{repo} --json title,body,labels
で Issue の詳細を取得してください。

### 3. 事前調査 + Grok補助分析 + Codex本調査
以下の順で実行してください。

1. **Codex Scout**: 軽量調査で `classification`, `candidate_files`, `pre_tier_score`, `pre_tier_signals`, `ambiguity_flags`, `community_evidence_needed`, `grok_recommendation` を JSON で出力
2. **Grok Context Synthesis**: `--grok auto|on|off` に従い条件付きで実行し、`tasks/issue-planner/grok/issue-{number}.json` に保存
3. **Codex Main Analysis**: Scout JSON と Grok JSON を補助情報として参照しつつ、最終的な原因分析・影響範囲・Before/After・E2E受け入れ条件を作成

**Grok auto の起動条件**:
- 外部依存シグナルあり
- Issue本文 + コメントが6000字以上
- コメント6件以上
- `candidate_files` が8件以上
- `pre_tier_score >= 6`
- `community_evidence_needed=true`

**重要: API 400エラー防止のため、プロンプトはファイル経由（stdin）で渡す。**
**重要: timeout は Scout=240000ms, Grok=600000ms, Main Analysis=300000ms を使うこと。**

```bash
# まず Codex Scout を実行して JSON を得る
cat > /tmp/issue_planner_scout_{number}.txt << 'SCOUT_EOF'
あなたは issue-planner の Codex Scout です。軽量事前調査だけを行い、JSON を返してください。
SCOUT_EOF

# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/issue_planner_scout_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="medium" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_scout_{number}_$$.txt

# 条件一致時のみ Grok を実行する
# *** Bash tool timeout: 600000 を必ず指定すること ***
# 出力先: {project_dir}/tasks/issue-planner/grok/issue-{number}.json

# 最後に Codex Main Analysis を実行する
cat > /tmp/issue_planner_prompt_{number}.txt << 'CODEX_PROMPT_EOF'
あなたはシニアフルスタックエンジニアです。以下のGitHub Issueを分析してください。

[Issue]
- 番号: #{number}
- タイトル: {title}
- 本文: {body}

[Codex Scout]
{codex_scout_json}

[Grok Context]
{grok_context_json_or_status}

[重要な制約]
- Grok は補助情報です
- ファイルパス、行番号、型、API可否、既存実装の有無は自分で確認してください
- `verification_required=true` の知見は裏取りできた場合だけ採用してください

[分析タスク]
1. 関連ファイル特定（パス+行番号）
2. 根本原因分析 / 実装箇所特定
3. 影響範囲の洗い出し
4. 変更提案（Before/Afterコード付き）
5. テスト計画
6. リスク評価
7. 工数見積（S/M/L/XL）
8. E2E受け入れ条件の定義（画面名・URL・操作フロー・期待結果・深度L1/L2・優先度）

分類・工数・優先度・影響度・原因分析・影響範囲・依存関係・実装ステップ・リスク・テスト計画・検証手順・E2E受け入れ条件・スコープ外の全セクションを日本語で出力してください。
確認や質問は不要です。
CODEX_PROMPT_EOF

# Codex Main Analysis 実行（stdin経由、teeで出力永続化）
# *** Bash tool timeout: 300000 を必ず指定すること ***
cat /tmp/issue_planner_prompt_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="high" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_output_{number}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}

# 異常終了時の部分結果回収
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Codex異常終了 (exit=$CODEX_EXIT) ==="
  echo "=== 部分結果回収 ==="
  cat /tmp/codex_output_{number}_$$.txt
fi

# プロンプトtmpファイル削除（出力ファイルはフォールバック判定後に削除）
rm -f /tmp/issue_planner_scout_{number}.txt /tmp/issue_planner_prompt_{number}.txt
```

**Bash tool timeout**:
- Codex Scout: `240000ms`
- Grok Context Synthesis: `600000ms`
- Codex Main Analysis: `300000ms`

Codexがタイムアウト/kill/400エラーの場合のフォールバック（5段階）:
0. **/tmp/codex_output_{number}_$$.txt から部分結果を回収** → 分析セクションが十分なら採用
1. プロンプト短縮して再実行（本文200文字、分析3項目）— Bash timeout: 300000ms
2. reasoning_effort を medium に下げて再実行 — Bash timeout: 240000ms
3. --skip-git-repo-check 追加して再実行 — Bash timeout: 240000ms
4. 上記すべて失敗 -> リーダーに報告してスキップ

Grok のフォールバック:
1. `OPENROUTER_API_KEY` が無ければ `skipped_auth`
2. HTTP 402/429 は1回だけ再試行
3. JSON不正は `skipped_parse_error`
4. 10分タイムアウト時は `partial_timeout` または `timeout`

**クリーンアップ**: Issue処理完了時に `rm -f /tmp/codex_scout_{number}_$$.txt /tmp/codex_output_{number}_$$.txt` を必ず実行する。Grok 成果物は `tasks/issue-planner/grok/issue-{number}.json` に残す。

### 3.2. bug原因の重点チェック（必須）

bug分類では、以下を Codex結果から必ず確認してください。

1. **時間/状態ゲート**
   - `cooldown`, `debounce`, `threshold`, `retry`, `reset` が同居している場合、
     閾値到達後に `return` して仕事が失効していないか
   - `pending` や `last_processed_count` のような保留状態があるか
2. **表示ソース**
   - 同じ概念を複数画面・複数UIが表示している場合、
     各表示がどのファイル/DB/Storage/メタデータを見ているか
3. **メタデータ境界**
   - `version`, `updated_at`, `status`, `count` などを LLM/外部APIが返している場合、
     サーバー側で再計算・再付与しているか

→ これらの結果は計画の原因分析または補足テーブルに必ず反映してください。

### 3.5. コード現状検証（必須 — Issue #1232教訓）

**Codex調査後、計画を組み立てる前に、変更対象ファイルの現在の状態を必ず検証すること。**

```bash
# 変更対象ファイルの最新コミットを確認
for file in {Codexが特定したファイルパス}; do
  echo "=== $file ==="
  git -C "{project_dir}" log --oneline -5 -- "$file"
done
```

以下を確認:
1. **対象ファイルが他Issueで最近変更されていないか** → 変更済みなら計画のBefore/Afterを更新
2. **「移行が必要」としたパターンが既に移行済みでないか** → 移行済みならそのファイルを除外
3. **対象ファイルのデータフェッチパターンの複雑度** → 単純(小)/並列fetch(中〜大)/依存チェーン(中) で分類

→ 検証結果は計画の「影響範囲」テーブルに複雑度列として反映する

### 3.5b. 外部依存の実現可能性検証（条件付き — Issue #1577教訓）

**トリガー**: Issue本文またはCodex出力に以下のシグナルがある場合のみ実行。なければスキップ。
- 外部ライブラリ/サービスの新規導入（npm/GitHub未確認）
- 外部APIとの新規連携（OAuth、webhook等）
- 実行環境の制約に関わる技術選択（stdio、子プロセス、常駐サーバー等）
- 複数の実装方式が提案されている（方式A vs 方式B）

**検証手順**:
1. 外部依存の実在確認（npm/GitHub/ドキュメント、バージョン、メンテナンス状況）
2. 環境制約の検証（Vercel Functionsでの動作可否、追加インフラ要否）
3. 既存コードとの統合可能性（SDK互換性、既存パターンでの代替可否）
4. 方式比較（複数案がある場合、工数・運用コスト・拡張性を表形式で比較）

→ 結果は計画の「設計判断」テーブルに反映。棄却方式は「非対象」に記載。

### 4. 計画組み立て
Codex Main Analysis の出力 + Step 3.2 + Step 3.5 + Step 3.5b（該当時）の検証結果を統合して実装計画テンプレートに構造化してください。
Grok の知見は補助情報として参照してよいですが、`verification_required=true` の内容を未検証のまま計画本文へ書かないでください。
不足情報があれば Grep/Read で補足調査してください。
（テンプレートは references/plan-template.md を参照）

### 4.2. 計画前提の実在性検証（Issue #1638教訓）
計画で「再利用する」「呼び出す」「渡す」と書いた全箇所について:
1. 再利用関数が `module.exports` / `export` に含まれるか grep で確認
2. プロパティ名がフック戻り値/型定義と一致するか確認
3. API/ライブラリの入力形式制約を確認（「存在する」≠「この入力を処理できる」）
4. config.toml 等のローカル設定が本番に自動反映されるか確認

未検証の前提を発見した場合は計画を修正してから 4.3 へ進む。
（詳細は design-review-checklist Phase 8 を参照）

### 4.3. Issue突き合わせ（計画 vs Issue要件）
計画完成後、Issueの全セクション（タイトル・本文・コメント・添付）を再読し、
各要件を計画ステップにマッピングする。計画末尾に「Issue要件カバレッジ」テーブルを追記:
```
| Issue要件 | 計画ステップ | カバー |
|----------|-----------|-------|
| (Issue本文から抽出) | Step X-Y | ✅/❌ |
```
未カバー率20%超なら計画修正。
（詳細は design-review-checklist Phase 9 Gate A を参照）

### 4.5. 多角的レビュー（3視点並列 + 完了率ゲート）
（詳細は references/multi-perspective-review.md を参照）

**レビュー統合後、以下を算出して投稿可否を判定:**
- `review_completion_rate` = 成功レビュアー数 / 3（例: 2/3 = 67%）
- `critical_open` = 未解消critical指摘数
- **投稿可**: `completion_rate >= tier_completion_threshold` かつ `critical_open == 0`
- **投稿不可**: 条件未達 → 計画修正 or スキップ

### 4.7. Codex final-check（条件付き — レビュー修正後の実装安全性検証）

**スキップ条件**: composite_grade が **A** かつ `critical_open == 0` の場合のみ省略可。

レビュー修正適用後の最終計画に対して、Codex read-only で実装安全性を検証する。
（詳細テンプレート・結果ハンドリングは references/worker-workflow.md の Step 4.7 セクションを参照）

検証観点:
1. 修正後のBefore/After整合（実ファイルとの一致）
2. 実装ステップ間の矛盾
3. 影響範囲の漏れ
4. 型変更の波及

結果: `pass` → Step 5へ、`fail` + critical → 修正後1回再実行、タイムアウト → スキップ扱い

### 5. 投稿（順序厳守: コメント -> ラベル）

```bash
# まずコメントを投稿
gh issue comment {number} --repo {owner}/{repo} --body "$(cat << 'PLAN_EOF'
{組み立てた実装計画}
PLAN_EOF
)"

# コメント投稿が成功した場合のみラベル追加（必須）
gh issue edit {number} --repo {owner}/{repo} --add-label "planned"
```

**絶対にラベルを先に追加しないこと。**
**必ず `gh issue edit <番号> --add-label planned` を実行すること。**ラベル適用を忘れると、次回のissue-planner実行時に同じIssueが再度計画対象になる（教訓#6）。

### 6. 完了報告（review metrics 必須）
TaskUpdate で status を "completed" に変更し、
SendMessage でリーダーに結果を報告してください:
「Issue #{number} '{title}' の実装計画を投稿しました。
分類: X, 工数: X, 優先度: X,
tier: {A/B/C}, tier_score: {N}, reviewer_count: {N},
review_completion_rate: {N}/{tier_reviewer_count}, critical_open: {N}, final_check: pass/skip/fail, composite_grade: {grade},
grok_used: {true/false}, grok_status: {status}, grok_mode: {mode}, grok_timeout_ms: {N}」

**必須メトリクス**（省略禁止）:
- `tier`: A / B / C（Step 3.6のTier判定結果）
- `tier_score`: 合計スコア
- `reviewer_count`: 2 / 3 / 4（Tier別レビュアー数）
- `review_completion_rate`: 成功レビュアー数/{tier_reviewer_count}（例: 3/4）
- `critical_open`: 未解消critical指摘数（0であること）
- `final_check`: pass / skip（A+critical_open==0の場合）/ fail
- `composite_grade`: A/B/C/D
- `grok_used`: true / false
- `grok_status`: success / partial_timeout / timeout / skipped_auth / skipped_parse_error / skipped
- `grok_mode`: repo_context_only / extended_knowledge / none
- `grok_timeout_ms`: 600000 などの実値

その後 TaskList で次の未着手タスクがあれば Step 1 に戻ってください。
全タスク完了なら作業終了してください。

## 注意事項
- ユーザーに直接質問しないこと（問題があればリーダーにSendMessage）
- gh コマンドには必ず --repo {owner}/{repo} を付けること
- Codexの出力が空または不十分な場合、Grep/Readで独自に調査して補完すること

## 停止条件（厳守）
- **TaskListで未着手(pending)かつオーナー未設定のタスクが0件になったら作業終了**
- リーダーが作成したタスク以外は絶対に自分で作成しないこと
- スキップ対象Issueを独自判断で処理しないこと
- リーダーからshutdown_requestを受けたら即座にshutdown_responseで承認すること
```
