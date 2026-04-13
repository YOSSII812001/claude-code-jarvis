---
name: codex-autopilot
description: |
  Codex CLIをユーザーの代理として使用し、Claude Codeの質問にCodexが回答する自動運転モード。
  トリガー: "codex autopilot", "autopilot", "自動運転", "codexに任せて",
  "codex代理", "codexが答えて", "オートパイロット"
  使用場面: (1) 長時間の自動実装、(2) ユーザー不在時の開発継続、
  (3) AI同士の協調開発
---

# Codex Autopilot スキル

## 概要
Claude Codeが実装中にユーザーへの質問（設計判断、実装選択、方針確認等）が必要になった場面で、
**ユーザーの代わりにCodex CLI（OpenAI）に質問し、その回答をもとに実装を自律的に継続する。**

通常のCodexスキルが「Claude CodeからCodexに相談する」のに対し、
このスキルは「ユーザーの代理としてCodexが意思決定する」という点が異なる。

## 動作ルール

### 1. 質問の発生 → Codexへ委任
Claude Codeが通常ならユーザーに質問する場面（AskUserQuestion等）で、
代わりに以下の手順でCodexに委任する：

1. 質問内容を明確に言語化する
2. Taskツール（Bashサブエージェント）でCodexに送信する
3. Codexの回答を受け取り、ユーザーに簡潔に報告する
4. その回答に基づいて実装を継続する

### 2. Codexへの質問テンプレート

**重要: API 400エラー防止のため、プロンプトはファイル経由（stdin）で渡す。シェル引数として直接渡さない。**

```
Task tool:
  subagent_type: "Bash"
  description: "Codex Autopilot: [質問の要約]"
  prompt: |
    以下の手順でCodexに質問してください。

    ステップ1: プロンプトをtmpファイルに書き出す
    ---
    cat > /tmp/codex_autopilot_prompt.txt << 'CODEX_PROMPT_EOF'
    あなたはシニアフルスタックエンジニアであり、プロジェクトオーナーの代理として意思決定します。

    [プロジェクト]
    Usacon - DX推進支援SaaS（Next.js + Supabase + Stripe + Vercel, TypeScript）

    [状況]
    <現在の実装状況の説明>

    [質問]
    <Claude Codeがユーザーに聞きたかった質問>

    [選択肢（あれば）]
    <選択肢の一覧>

    以下の形式で回答してください：
    選択: <選んだ選択肢、または自分の提案>
    理由: <2-3文で簡潔に>
    注意点: <実装時に気をつけること>

    確認や質問は不要です。必ず1つの明確な回答を返してください。
    CODEX_PROMPT_EOF
    ---

    ステップ2: Codex execをstdin経由で実行する（MCP無効化・reasoning_effort抑制・teeで出力永続化）
    --- *** Bash tool timeout: 600000 を必ず指定すること ***
    cat /tmp/codex_autopilot_prompt.txt | codex exec \
      --full-auto \
      --sandbox read-only \
      --cd "<project_directory>" \
      -c model_reasoning_effort="high" \
      -c features.rmcp_client=false \
      - \
      2>&1 | tee /tmp/codex_autopilot_output.txt
    CODEX_EXIT=${PIPESTATUS[0]}
    if [ $CODEX_EXIT -ne 0 ]; then
      echo "=== Codex異常終了 (exit=$CODEX_EXIT) ==="
      cat /tmp/codex_autopilot_output.txt
    fi
    ---

    ステップ3: プロンプトtmpファイルを削除する（出力ファイルはフォールバック判定後に削除）
    ---
    rm -f /tmp/codex_autopilot_prompt.txt
    ---

    ステップ4: フォールバック不要確定後にoutputファイルを削除する
    ---
    rm -f /tmp/codex_autopilot_output.txt
    ---

    Bash tool timeout: 600000ms（2.5分）— 必ず指定すること
```

### 2a. テンプレート設計の理由（API 400エラー対策）

| 対策 | 解決する問題 |
|------|-------------|
| **ファイル経由（stdin）でプロンプト渡し** | シェルエスケープ破損を完全回避。日本語・特殊文字・改行が安全に渡る |
| **`-c model_reasoning_effort="high"`** | config.tomlの`xhigh`を上書きし、トークン消費を抑制。コンテキストオーバーフロー防止 |
| **`-c features.rmcp_client=false`** | MCP 5サーバー分のコンテキストを除外。autopilotの質問にMCPは不要 |
| **【】→ []に変更** | 全角括弧のエンコーディング問題を回避 |
| **ヒアドキュメント（`<< 'EOF'`）** | シングルクォートEOFで変数展開を防止し、プロンプト内容をそのまま保持 |

### 3. ユーザーへの報告フォーマット

Codexに委任するたびに、以下の形式でユーザーに報告する（透明性確保）：

```
🤖 Codex判断: [質問の要約]
→ 選択: [Codexの選択]
→ 理由: [1行の理由]
（続行します。異議があれば「ストップ」とお知らせください）
```

### 4. エスカレーションポリシー

**基本方針: すべてCodexに委任する。人間は画面を監視しており、問題があれば「ストップ」で介入する。**

Claude Codeが通常ユーザーに判断を仰ぐすべての場面で、AskUserQuestionを使わず、
代わりにCodexに質問して回答を得て、そのまま実装を継続すること。

| カテゴリ | 委任先 | 備考 |
|---------|--------|------|
| コンポーネント設計・構造 | codex | |
| API設計（エンドポイント、レスポンス形式） | codex | |
| データベーススキーマ変更（マイグレーション） | codex | |
| 命名規則（変数名、関数名、ファイル名） | codex | |
| エラーハンドリング方針 | codex | |
| UI/UXの選択（レイアウト、表示形式） | codex | |
| ライブラリ・パッケージの選定 | codex | |
| Stripe決済関連の変更 | codex | |
| 認証・認可（RLS、セキュリティ） | codex | |
| テスト戦略（何をテストするか） | codex | |
| PR作成・マージ・デプロイ | codex | |
| 環境変数・シークレットの変更 | codex | |
| データ削除・破壊的マイグレーション | codex | |
| パフォーマンス最適化のアプローチ | codex | |
| ビジネスロジックの判断 | codex | |
| その他すべての判断 | codex | デフォルト |

## フォールバック

以下の場合は自動的にユーザーにフォールバックする：
- Codexがタイムアウトした場合（150秒）
- Codexの回答が曖昧または「わからない」の場合
- ネットワークエラー等でCodexが応答しない場合
- エスカレーションポリシーで「human」に分類された判断の場合

### タイムアウト/400エラー時のフォールバック手順

タイムアウトまたは400エラーが発生した場合、以下を順番に試行する：

0. **部分出力回収**: /tmp/codex_autopilot_output.txt から回収。回答として十分なら採用
1. **プロンプトを短縮して再試行**: 状況説明を3行以内に圧縮（Bash timeout: 600000ms）
2. **`-c model_reasoning_effort="medium"`に下げて再試行**: reasoningトークンをさらに抑制（Bash timeout: 600000ms）
3. **`--skip-git-repo-check`を追加して再試行**: Git関連のコンテキスト読み込みを省略（Bash timeout: 600000ms）
4. **上記すべて失敗**: ユーザーにフォールバック（AskUserQuestionに切り替え）。`rm -f /tmp/codex_autopilot_output.txt`

## Usaconプロジェクトとの連携

このスキルはUsaconスキルと併用することを前提としている。
Codexに質問する際は、以下のプロジェクト情報を自動的に含める：

- プロジェクトディレクトリ: `C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app`
- 技術スタック: Next.js + Supabase + Stripe + Vercel
- 言語: TypeScript
- Codexの `--cd` に上記ディレクトリを指定することで、Codexがコードベースを参照できる

## 注意事項

- Codex APIの利用料金が発生する（質問のたびに1回のAPIコール）
- Codexの判断が不適切だった場合、ユーザーはいつでも「ストップ」で介入可能
- ビープ音通知はStopフックが自動処理する（スキル内で手動呼び出ししないこと）
- 既存のCodexスキル（`/codex`）とは独立して動作する

## 起動方法

ユーザーが以下のいずれかを発言したとき、このスキルがロードされる：
- 「codex autopilot」「autopilot」「自動運転」
- 「codexに任せて」「codex代理」「codexが答えて」
- 「オートパイロット」

起動後、ユーザーがタスクを指示すれば、Claude Codeは質問をCodexに委任しながら自律的に実装を進める。

## エスカレーション基準への連携

Autopilotモード中にブラウザ検査（browser_evaluate / browser_snapshot）を**3回**試みても原因が特定できない場合は、Codexスキルの「エスカレーション基準」に従い、Codex CLIにソースコード全体の分析を委任すること。詳細は `codex` スキルの「エスカレーション基準」セクション参照。

## チェックリスト

- [ ] Codexの応答がタスクの文脈に適合しているか確認したか
- [ ] Codexが生成したコードをレビューしたか
- [ ] Codexの判断結果をユーザーに報告したか（透明性確保）
- [ ] フォールバック条件（タイムアウト・曖昧回答）を確認したか

## 関連スキル

- `/autopilot-issue <Issue番号>` - **Issue単位の自律実装**（サブエージェントでコンテキスト分離）
- `issue-flow` - 通常のIssue実装フロー（ユーザー承認あり）
- `codex` - Codex単体での相談・レビュー（エスカレーション基準セクションあり）
- `codex:rescue` - **プラグイン**: タスク委任（ジョブ管理+resume対応。本スキルの「質問委任」とは用途が異なる）
- `codex:review` - **プラグイン**: 構造化コードレビュー（autopilotモード中のレビューにも使用可能）
- `usacon` - Usaconプロジェクトルール

## プラグインとの使い分け

本スキル（codex-autopilot）の核心機能「**全質問→Codex委任**」はプラグインに対応機能がない。
プラグインの `/codex:rescue` はタスク委任であり、autopilotの「ユーザー代理の意思決定」とは異なる。

ただし、autopilotモード中でもプラグイン機能は併用可能:
- コードレビューが必要な場面 → `/codex:review` を使用
- ジョブの進捗確認 → `/codex:status` を使用

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2025-09 | 初版作成 | Codex Autopilotスキルの標準化 |
| 2026-01 | API 400エラー対策（stdin経由・MCP無効化）を追加 | Codex APIエラー多発への対策 |
| 2026-03-04 | エスカレーション基準連携・チェックリスト・改訂履歴を追加、「関連コマンド・スキル」を「関連スキル」に変更 | 教訓#8統合 + スキル品質改善 |
| 2026-03-16 | Codexタイムアウト防止: Bash timeout 600000ms明示化、tee出力永続化、部分出力回収フォールバック追加 | Bash toolデフォルト120秒でCodex推論がkillされる問題 |
| 2026-03-31 | プラグイン連携セクション追加（関連スキル+使い分けガイド） | Codexプラグイン(v1.0.1)との共存方針確定。autopilotの「質問委任」はプラグインに対応なし |
