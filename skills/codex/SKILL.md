---
name: codex
description: |
  Codex CLI（OpenAI）を使用してコードや文言について相談・レビューを行う。
  Codexプラグイン（codex:rescue/review/status等）と共存し、用途で使い分ける。
  トリガー: "codex", "codexと相談", "codexに聞いて", "コードレビュー", "レビューして",
  "codexで分析", "codexに修正させて"
  使用場面: (1) 文言・メッセージの検討、(2) コードレビュー、(3) 設計の相談、
  (4) バグ調査、(5) 解消困難な問題の調査、(6) セカンドオピニオン
---

# Codex CLI スキル

## 概要
Codex CLI（OpenAI）を非対話モード（`codex exec`）で実行し、コード分析・レビュー・相談を行う。
Claude Codeとは異なるLLMの視点でセカンドオピニオンを得られる。

## 前提条件
- Codex CLIがインストール済みであること（`/codex:setup` で確認可能）
- OpenAI APIキーが設定済みであること

## プラグインとの役割分担

Codexプラグイン（`codex@openai-codex`）と本スキルは**共存**する。用途で使い分ける。

| 用途 | 使用先 | 理由 |
|------|--------|------|
| コードレビュー（構造化出力） | **プラグイン** `/codex:review` | P1/P2+ファイル:行番号のスキーマ出力 |
| 敵対的レビュー | **プラグイン** `/codex:adversarial-review` | 攻撃面分析に特化 |
| タスク委任（調査・修正） | **プラグイン** `/codex:rescue` | ジョブ管理+resume対応 |
| 環境確認 | **プラグイン** `/codex:setup` | JSON構造化チェック |
| ジョブ状態確認 | **プラグイン** `/codex:status`, `/codex:result` | バックグラウンドジョブ管理 |
| **PR前final-check（ガードレール付き）** | **本スキル** | ファイル数/行数制限、Lint再確認はプラグインにない |
| **依存スキル向けexecパターン** | **本スキル** | issue-planner等9スキルがcodex exec形式に依存 |
| **autopilot（自律意思決定）** | **codex-autopilot** スキル | プラグインに対応機能なし |

## 実行方法の選択

### 方法1: プラグイン経由（推奨 — 調査・レビュー・修正委任）

```
/codex:rescue <依頼内容>          # タスク委任（調査・修正）
/codex:review                     # コードレビュー（構造化出力）
/codex:adversarial-review         # 敵対的レビュー
/codex:status                     # ジョブ状態確認
/codex:result [job-id]            # 結果取得
```

プラグインはgpt-5-4-prompting（XMLブロック構造）でプロンプトを最適化し、ジョブ管理（resume/cancel）も提供する。

### 方法2: codex exec 直接実行（依存スキル向け・final-check・特殊用途）

**Codexの出力は非常に長大（数百〜数千行）になるため、メインコンテキストを保護するために必ずサブエージェント経由で実行すること。**

#### プロンプト設計（gpt-5-4-prompting準拠）

依存スキルからcodex execを呼ぶ際は、以下のXMLブロック構造でプロンプトを構成する：

```xml
<task>具体的なジョブ、対象リポジトリ/ファイル、期待する最終状態を記述</task>
<structured_output_contract>出力形式を指定（省略可）</structured_output_contract>
<default_follow_through_policy>
Default to the most reasonable low-risk interpretation and keep going.
Only stop to ask questions when a missing detail changes correctness, safety, or an irreversible action.
</default_follow_through_policy>
<verification_loop>結果を検証してから出力を確定する（デバッグ・実装時）</verification_loop>
<grounding_rules>推測ではなくツール出力やコードに基づく（レビュー・調査時）</grounding_rules>
```

#### read-only（分析・レビュー・相談）テンプレート

```
Agent tool (subagent_type: general-purpose):
  description: "Codexで[依頼内容の要約]"
  prompt: |
    以下のコマンドを実行し、Codexの出力結果を日本語で要約してください。

    コマンド（Bash tool timeout: 600000 を必ず指定すること）:
    codex exec --full-auto --sandbox read-only --cd "<project_directory>" "<request>。確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。" \
      2>&1 | tee /tmp/codex_output_general.txt

    タイムアウト: Bash tool timeoutは600000ms（10分）。

    異常終了時は /tmp/codex_output_general.txt から部分結果を回収すること。

    実行後、以下の形式で結果を要約してください：
    1. Codexが分析した内容の概要
    2. 主要な発見・提案（箇条書き）
    3. 具体的なコード例（重要なもののみ抜粋）
    4. 推奨アクション

    クリーンアップ: rm -f /tmp/codex_output_general.txt
```

#### workspace-write（修正適用）テンプレート

ユーザーが「codexに修正させて」「codexで直して」「codexに実装させて」等の書き込み意図を示した場合：

```
Agent tool (subagent_type: general-purpose):
  description: "Codexで修正適用"
  prompt: |
    以下のコマンドを実行してください。

    コマンド（Bash tool timeout: 600000 を必ず指定すること）:
    codex exec --full-auto --sandbox workspace-write --cd "<project_directory>" "<request>。確認や質問は不要です。具体的な修正を直接ファイルに適用してください。" \
      2>&1 | tee /tmp/codex_output_write.txt

    タイムアウト: Bash tool timeoutは600000ms（10分）。

    異常終了時は /tmp/codex_output_write.txt から部分結果を回収すること。

    実行後:
    1. Codexの出力を日本語で要約
    2. `git diff --stat` を実行して変更されたファイル一覧を取得
    3. 変更内容の概要を報告
    4. クリーンアップ: rm -f /tmp/codex_output_write.txt
```

## final-check（PR作成前の自動修正）

### 概要
- **用途**: PR作成前に軽微な見落とし・抜け・漏れをCodexが自動修正
- **モード**: `workspace-write`（ファイル直接修正）
- **性質**: **非ブロッキング**（失敗/タイムアウト時はスキップして続行）

### チェック項目（L2: Lint/型チェックで拾えない意味的軽微ミス）

| # | 項目 | アクション |
|---|------|----------|
| 1 | console.log / console.debug / debugger 残存 | 削除 |
| 2 | 空のcatchブロック | エラーログ追加 or コメント追記 |
| 3 | TODO / FIXME / HACK コメント残存 | 解決済みなら削除、未解決なら報告のみ |
| 4 | コピペ残り（コンポーネント名・変数名が元ファイルのまま） | 正しい名前に修正 |
| 5 | 不適切なフォールバック値（"不明な○○"等でDB保存） | エラーthrowまたは適切な処理に変更 |
| 6 | 未使用import文（Lint漏れ補完） | 削除 |
| 7 | 不必要な `as any` 型アサーション | 正しい型に修正 |
| 8 | ハードコードURL/ポート/マジックナンバー | 定数化（明らかなもの） |
| 9 | コメントとコードの乖離 | コメント更新 |

### 実行テンプレート（Taskツール経由）

```
Task tool (subagent_type: Bash):
  description: "Codex final-check"
  prompt: |
    以下の手順を順次実行してください。

    ステップ1: baseline固定（実装差分をstageし、Codex修正分だけをunstagedで観測）
      cd <project_directory>
      git add -A
      git diff --cached > /tmp/finalcheck_target_diff.txt

    ステップ2: チェック項目を含むプロンプトをtmpファイルに書き出し
      cat > /tmp/codex_finalcheck_prompt.txt << 'PROMPT'
      以下のgit diffで示された変更箇所のみを対象に、次のチェック項目を確認し、該当する問題があれば修正してください。
      確認や質問は不要です。問題があれば直接ファイルを修正してください。

      チェック項目:
      1. console.log / console.debug / debugger の残存 → 削除
      2. 空のcatchブロック → エラーログ追加 or コメント追記
      3. TODO / FIXME / HACK コメント → 解決済みなら削除
      4. コピペ残り（コンポーネント名・変数名が元ファイルのまま） → 正しい名前に修正
      5. 不適切なフォールバック値（"不明な○○"等でDB保存） → エラーthrowまたは適切な処理に変更
      6. 未使用import文 → 削除
      7. 不必要な as any 型アサーション → 正しい型に修正
      8. ハードコードURL/ポート/マジックナンバー → 定数化（明らかなもの）
      9. コメントとコードの乖離 → コメント更新

      ルール:
      - 変更差分に含まれるファイルのみを対象とする（他のファイルは触らない）
      - 関数シグネチャは変更しない
      - 問題がなければ何も修正しない

      --- 変更差分 ---
      PROMPT
      cat /tmp/finalcheck_target_diff.txt >> /tmp/codex_finalcheck_prompt.txt

    ステップ3: Codex実行（Bash tool timeout: 300000ms）
      cat /tmp/codex_finalcheck_prompt.txt | codex exec \
        --full-auto --sandbox workspace-write --cd <project_directory> \
        -c model_reasoning_effort="high" -c features.rmcp_client=false - \
        2>&1 | tee /tmp/codex_finalcheck_output.txt
      CODEX_EXIT=${PIPESTATUS[0]}

    ステップ4: Codex修正分のみ計測（unstagedのみ = Codexが変更した分）
      CHANGED_FILES=$(git diff --name-only | sed '/^$/d' | wc -l)
      TOTAL_LINES=$(git diff --numstat | awk '{sum+=$1+$2} END {print sum+0}')
      echo "修正ファイル数: $CHANGED_FILES"
      echo "修正行数: $TOTAL_LINES"
      echo "修正差分: $(git diff --stat)"

    ステップ5: ガードレール判定（revertはCodex修正分のみ = git restore --worktree）
      REVERT_CMD="git diff --name-only | xargs -r git restore --worktree --"
      # 修正ファイル数 > 10 → revert
      if [ "$CHANGED_FILES" -gt 10 ]; then
        echo "⚠️ ガードレール発動: 修正ファイル数 > 10 → Codex修正分をrevert"
        eval "$REVERT_CMD"
        exit 0
      fi
      # 修正行数 > 50 → revert
      if [ "$TOTAL_LINES" -gt 50 ]; then
        echo "⚠️ ガードレール発動: 修正行数 > 50 → Codex修正分をrevert"
        eval "$REVERT_CMD"
        exit 0
      fi
      # 関数シグネチャ変更チェック（grep -qE で終了コードを正しく判定）
      if git diff --unified=0 | grep -qE '^\+.*(function\s+\w+\(|=>\s*\(|export\s+(default\s+)?function)'; then
        echo "⚠️ ガードレール発動: 関数シグネチャ変更の可能性 → Codex修正分をrevert"
        eval "$REVERT_CMD"
        exit 0
      fi

    ステップ6: Lint + 型チェック再確認
      npm run lint && (cd frontend && npm run type-check)
      if [ $? -ne 0 ]; then
        echo "⚠️ Lint/型チェック失敗 → Codex修正分をrevert"
        cd <project_directory>
        eval "$REVERT_CMD"
        exit 0
      fi

    ステップ7: Codex修正分を再stageして結果報告
      echo "=== Codex final-check 完了 ==="
      if [ "$CHANGED_FILES" -eq 0 ]; then
        echo "修正なし（問題は検出されませんでした）"
      else
        echo "修正あり: $CHANGED_FILES ファイル, $TOTAL_LINES 行"
        git diff --stat
        git add -u
      fi

    クリーンアップ: rm -f /tmp/codex_finalcheck_*.txt /tmp/finalcheck_target_diff.txt
    Bash tool timeout: 300000ms（5分）
```

### ガードレール（安全弁）

| 条件 | アクション |
|------|----------|
| 修正ファイル数 > 10 | 全revert（過剰修正判定） |
| 修正行数 > 50 | 全revert |
| Lint/型チェック FAIL | 全revert |
| 関数シグネチャ変更あり | 全revert |
| タイムアウト(5分) | スキップして続行 |
| Codex 400エラー | スキップして続行 |

## 実行ルール

### 必須事項
1. **必ずTaskツール（Bashサブエージェント）で実行**: メインコンテキストの消費を防ぐため、直接Bashツールで実行しない
2. **プロンプト末尾への指示追加**: すべてのリクエスト末尾に「確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。」を必ず追加する
3. **プロジェクトディレクトリの特定**: ユーザーの作業コンテキストから対象プロジェクトのディレクトリを特定し、`--cd` で指定する
4. **サンドボックスモードの判断**:
   - デフォルト: `--sandbox read-only`（分析・レビュー・相談）
   - 書き込み意図がある場合のみ: `--sandbox workspace-write`（修正・実装の直接適用）
5. **結果の報告**: サブエージェントが返した要約をユーザーに報告する

### workspace-write使用時の追加ルール
- 実行前にユーザーに確認を取る
- 実行後にgit diffで変更内容を確認する（サブエージェント内で実行）
- 意図しない変更があれば報告する

## Codex設定変更前チェック

Codexの設定（features、config）を変更する前に、必ず以下の手順を踏むこと：

| # | 手順 | コマンド | 目的 |
|---|------|---------|------|
| 1 | 現行キー一覧確認 | `codex features list` | 存在しないキーへの設定を防止 |
| 2 | キー存在確認 | 上記一覧で対象キーが存在するか確認 | タイポ・廃止キーを排除 |
| 3 | 設定変更実行 | `codex config set <key> <value>` | 確認済みキーのみ変更 |

**アンチパターン**: キー名を推測して直接 `codex config set` を実行する → 存在しないキーが黙って設定され、後で混乱の原因になる

## 実行フロー

```
1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトディレクトリを特定する
3. サンドボックスモードを判断する（read-only or workspace-write）
4. プロンプトを作成し、末尾に必須指示を追加する
5. Taskツール（Bashサブエージェント）でcodex execを実行する
6. サブエージェントが返した要約をユーザーに報告する
```

## モデル指定（オプション）
特定のモデルを使いたい場合は `-m` オプションで指定可能：
```bash
codex exec --full-auto --sandbox read-only -m o3 --cd "<project_directory>" "<request>"
```

## ⚠️ よくある間違い（再発防止）

以下のコマンドは**すべて間違い**です。絶対に使用しないこと。

```bash
# ❌ 間違い1: exec サブコマンドがない
codex -a full-auto "リクエスト"

# ❌ 間違い2: --full-context は存在しないオプション
codex --full-context -a auto-edit "リクエスト"

# ❌ 間違い3: パイプでファイル内容を渡す（--cd を使う）
cat file.tsx | codex "リクエスト"

# ❌ 間違い4: -a auto-edit は exec モードでは不要
codex exec -a auto-edit "リクエスト"
```

**正しいコマンド形式（これ以外を使わないこと）:**
```bash
# ✅ 読み取り専用（分析・レビュー）
codex exec --full-auto --sandbox read-only --cd "<project_directory>" "<request>"

# ✅ 書き込み（修正適用）
codex exec --full-auto --sandbox workspace-write --cd "<project_directory>" "<request>"

# ✅ モデル指定あり
codex exec --full-auto --sandbox read-only -m <model> --cd "<project_directory>" "<request>"
```

**必須チェック:**
- `exec` サブコマンドが含まれているか？
- `--full-auto` オプションが含まれているか？
- `--sandbox read-only` or `--sandbox workspace-write` が含まれているか？
- `--cd` でプロジェクトディレクトリが指定されているか？

## エスカレーション基準

ブラウザ検査（browser_evaluate / browser_snapshot）を**3回**試みても原因が特定できない場合、Codexにソースコード全体の分析を委任すること。

| 調査回数 | アクション |
|---------|----------|
| 1-3回 | ブラウザ検査を続行 |
| 3回超 | Codex CLIに委任（`codex "原因を特定して: [症状]"`） |

Codexが得意な原因:
- ビルド時の最適化・tree shaking
- コンポーネント解決順序（re-export、barrel file）
- Props/State の伝播チェーン
- CSS specificity 競合

## 注意事項
- Codexはサブスクリプションで利用しているため、追加のAPI費用は発生しない
- read-onlyモードではファイルの変更は行われない（安全）
- workspace-writeモードではCodexがファイルを直接変更するため、実行前の確認を推奨
- Windows環境のため、パスにはバックスラッシュを使用する
- **Codexの出力は1000行以上になることがあるため、絶対にメインのBashツールで直接実行しない**

## タイムアウト設計ガイドライン（全スキル共通）

Bash toolのデフォルトタイムアウトは120秒だが、Codex推論は120〜600秒かかる。
**原則: Bash timeout = 600000ms (10分) を標準とする**。timeout未指定ではプロセスがkillされ出力が全消失する。

| スキル | 用途 | Bash timeout | 備考 |
|--------|------|:---:|:---:|
| codex | 一般相談/レビュー | 600000ms (10分) | 標準 |
| issue-planner | Codex調査 | 600000ms (10分) | 標準 |
| issue-planner | 多角的レビュー | 600000ms (10分) | 標準 |
| codex-autopilot | 質問委任 | 600000ms (10分) | 標準 |
| codex (final-check) | PR前最終チェック | 600000ms (10分) | 標準 |
| batch-planning | Pre-flight分析 | 600000ms (10分) | 標準 |

**出力永続化テンプレート（全codex exec共通）:**
```bash
# teeでリアルタイム保存（kill時も部分結果が残る）
cat /tmp/prompt.txt | codex exec \
  --full-auto --sandbox read-only --cd "{dir}" \
  -c model_reasoning_effort="high" -c features.rmcp_client=false - \
  2>&1 | tee /tmp/codex_output_{id}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Codex異常終了 (exit=$CODEX_EXIT) ==="
  cat /tmp/codex_output_{id}_$$.txt  # 部分結果回収
fi
```

## トラブルシューティング

| ステップ | よくある問題 | 解決方法 |
|---------|-------------|---------|
| Codex実行 | `codex exec` がハングする | タイムアウト300秒を設定し、超過時はプロンプトを短縮して再試行 |
| Codex実行 | **Bash timeoutでkillされて出力全消失** | Bash tool timeoutを上記ガイドライン表に従い明示指定。`2>&1 \| tee`で出力永続化し、kill時も部分結果を回収可能にする |
| Codex実行 | API 400エラー | stdin経由でプロンプトを渡す（codex-autopilotスキル参照） |
| 結果取得 | 出力が空 | `--cd` のパスが正しいか確認。プロジェクトディレクトリが存在するか確認 |
| 結果取得 | コンテキスト圧迫 | 必ずTaskツール（サブエージェント）経由で実行。メインBashで直接実行しない |
| スキル改善 | workspace-write で ~/.claude/skills/ の修正が失敗 | skills/ はgitリポジトリ外のため workspace-write 対象外。Edit tool で直接修正すること |

## MCP/OAuth エラー切り分け

Supabase MCP等でOAuthエラーが発生した場合の初動手順：

| # | 手順 | コマンド | 判定 |
|---|------|---------|------|
| 1 | 再認証（第1手順） | `codex mcp logout && codex mcp login` | 解決 → 設定は触らない |
| 2 | MCP状態確認 | `codex mcp list` | サーバー一覧で状態確認 |
| 3 | 設定変更（最終手段） | 設定ファイルの編集 | 再認証で解決しない場合のみ |

**重要**: 設定変更より先に再認証を試すこと。OAuth トークンの期限切れが最も多い原因。

## 関連スキル

| スキル | 関連 |
|--------|------|
| `codex-autopilot` | Codex自動運転モード（ユーザー代理の意思決定） |
| `codex:rescue` | **プラグイン**: タスク委任（ジョブ管理+resume対応） |
| `codex:review` | **プラグイン**: 構造化コードレビュー（P1/P2+ファイル:行番号） |
| `codex:gpt-5-4-prompting` | **プラグイン内部**: XMLブロック構造のプロンプト設計ガイド |
| `usacon` | 実プロジェクトでのCodex活用 |
| `design-review-checklist` | 設計レビューの相談相手としてCodexを活用 |

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2025-08 | 初版作成 | Codex CLIスキルの標準化 |
| 2026-03-04 | エスカレーション基準・トラブルシューティング・関連スキル・改訂履歴を追加 | 教訓#8統合（ブラウザ検査3回で原因不明→Codex委任）+ スキル品質改善 |
| 2026-03-16 | タイムアウト設計ガイドライン（全スキル共通表）新設、Bash timeout 360000ms明示化、tee出力永続化テンプレート追加、トラブルシューティングに「Bash timeoutでkill」パターン追加 | Codex分析がBash toolデフォルトtimeoutでkillされる問題の体系的対策 |
| 2026-03-17 | final-check（PR作成前の自動修正）セクション新設 | 実装後の軽微な見落とし防止。workspace-writeでCodexが自動修正 |
| 2026-03-17 | Codex設定変更前チェック・MCP/OAuthエラー切り分けセクション新設 | 教訓#2(features list事前確認), #3(MCP OAuth再認証優先)の反映 |
| 2026-03-17 | トラブルシューティングにworkspace-write制約を追加 | ~/.claude/skills/ はgitリポ外のためworkspace-write不可。教訓の棚卸しで検出 |
| 2026-03-31 | プラグイン連携セクション追加、役割分担表、gpt-5-4-prompting XMLブロック構造統合、実行方法をプラグイン優先+exec直接の2段構成に再編 | Codexプラグイン(v1.0.1)テスト完了。Windows ENOENTバグ修正後、review/rescue/statusが全動作確認済み。共存方針確定 |
