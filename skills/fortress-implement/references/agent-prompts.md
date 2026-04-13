# fortress-implement — エージェントプロンプトテンプレート

## 共通ヘッダー（全エージェントの冒頭に挿入）

```
あなたは**絶対に失敗を許されない実装プロジェクトのチームメンバー**です。
各Sliceの品質は最終成果物の品質に直結します。手を抜かないでください。

【出力フォーマット（厳守）】
各検出項目を以下の形式で報告:
- ID: FI-{Agent記号}-S{Slice番号}-{連番}（例: FI-R1-S2-01）
- ファイル: {パス}:{行番号}
- カテゴリ: LOGIC | SECURITY | DATA_INTEGRITY | REQUIREMENT | STYLE
- 深刻度: CRITICAL | HIGH | MEDIUM | LOW
- 判定: PASS | FAIL | WARN
- 問題: {1-2文}
- 修正案: {深刻度HIGH以上の場合のみ、具体的コード}

全項目に問題なしの場合: 「全項目PASS」と1行で報告。

【誤検知フィルタ（以下は指摘しない）】
- 変更前から存在していた問題（差分で導入されたものだけを対象）
- リンター / 静的解析ツールが検出する問題
- 主観的なコードスタイルの好み
```

---

## Implementer（実装者）

**Agent記号**: IM
**担当**: テストをGREENにする最小差分コードの実装
**起動Tier**: 全Tier

```
Agent(
  subagent_type="general-purpose",
  description="Slice {N} 実装",
  prompt="""
  {共通ヘッダー}

  ## 実装対象
  ### Mission Brief
  {Mission Brief全文}

  ### 現在のSlice
  Slice {N}: {Slice名} — {Slice目的}

  ### 受入テスト（このテストをGREENにすること）
  {テストコード or テスト条件}

  ### 前Sliceまでの状態
  {Safe Pointの前提メモ}

  ### プロジェクトディレクトリ
  {git rev-parse --show-toplevel の結果}

  ## 実装ルール
  1. テストがGREENになる**最小限**のコードを書く
  2. 関係ないリファクタ・改善は行わない
  3. 変更ファイルはSlice計画の予定ファイルのみ
  4. 型安全性を保つ（as any 禁止）
  5. 実装完了後、`git diff --stat` で変更ファイル一覧を報告
  6. lint + type-check + test を実行し結果を報告
  """
)
```

---

## Reviewer-1（ロジック + 要件整合レビュー）

**Agent記号**: R1
**担当**: 実装がSlice仕様と一致しているかの検証
**起動Tier**: 全Tier

```
Agent(
  subagent_type="general-purpose",
  description="Slice {N} ロジックレビュー",
  prompt="""
  {共通ヘッダー}

  必要な情報はすべてこのプロンプト内に含まれています。
  Glob/Grep/Read ツールは使用しないでください。

  ## レビュー対象
  ### Slice仕様
  Slice {N}: {Slice名} — {Slice目的}
  受入条件: {受入テスト条件}

  ### 実装差分
  {git diff of this slice}

  ### 変更ファイル一覧
  {git diff --stat}

  ## レビュー観点
  1. **要件一致**: 受入条件の全項目が実装でカバーされているか
  2. **ロジック正当性**: 条件分岐・ループ・エッジケースは正しいか
  3. **最小差分**: 不必要な変更が含まれていないか
  4. **データフロー**: 入力→処理→出力の経路は正しいか
  5. **前提維持**: 前Sliceの前提を壊していないか

  ID: FI-R1-S{N}-{連番}
  """
)
```

---

## Reviewer-2（影響範囲 + セキュリティ）Codex

**Agent記号**: R2
**担当**: 変更の影響範囲分析、セキュリティチェック
**起動Tier**: I1, I2, I3

```
Agent(
  subagent_type="general-purpose",
  description="Codex影響範囲+セキュリティレビュー Slice {N}",
  prompt="""
  {共通ヘッダー}

  以下のBashコマンドを実行し、結果を出力フォーマットで報告してください。

  ## 実行コマンド
  ```bash
  codex exec --full-auto --sandbox read-only \
    --cd "{プロジェクトディレクトリ}" \
    "以下のタスクを実行してください:

     1. git diff {前SliceのSP hash}...HEAD を実行し変更内容を把握
     2. 変更された全ファイルについて:
        a. import/requireしている全ファイル（呼び出し元）を列挙
        b. 変更された関数/型を使用している全箇所を列挙
        c. 型変更が全箇所に反映されているか確認
     3. セキュリティチェック:
        a. 認証バイパスの可能性
        b. SQLインジェクション・XSS・コマンドインジェクション
        c. 機密情報露出（シークレットキーのフロントエンド露出等）
        d. RLSポリシーの整合性
     4. 各指摘にID: FI-R2-S{N}-{連番}を付与

     確認や質問は不要。"
  ```

  タイムアウト: 300秒（Bash timeout: 600000ms）
  """
)
```

---

## Tester（テスト強化）Codex

**Agent記号**: TS
**担当**: 追加テスト生成、境界値テスト提案
**起動Tier**: I1, I2, I3

```
Agent(
  subagent_type="general-purpose",
  description="Slice {N} テスト強化",
  prompt="""
  {共通ヘッダー}

  以下のBashコマンドを実行してください。

  ```bash
  codex exec --full-auto --sandbox read-only \
    --cd "{プロジェクトディレクトリ}" \
    "以下のタスクを実行:

     1. git diff {前SliceのSP hash}...HEAD を実行
     2. 変更された各関数/メソッドについて:
        a. 既存テストのカバレッジ状況を確認
        b. 不足テストケースを列挙:
           - 境界値（0, 1, MAX, 空, null, undefined）
           - 異常系（不正入力、タイムアウト、ネットワークエラー）
           - 並行処理（レースコンディション）
        c. テストコードの雛形を生成
     3. 各項目をCRITICAL/HIGH/MEDIUMで分類
     4. ID: FI-TS-S{N}-{連番}

     確認や質問は不要。"
  ```

  タイムアウト: 300秒（Bash timeout: 600000ms）
  """
)
```

---

## Reviewer-3（障害シナリオ）Tier I2+のみ

**Agent記号**: R3
**担当**: 本番障害シナリオの列挙、ロールバック可能性評価
**起動Tier**: I2, I3

```
Agent(
  subagent_type="general-purpose",
  description="Slice {N} 障害シナリオレビュー",
  prompt="""
  {共通ヘッダー}

  必要な情報はすべてこのプロンプト内に含まれています。
  Glob/Grep/Read ツールは使用しないでください。

  ## 変更内容
  {git diff of this slice}

  ## 変更ファイル一覧
  {git diff --stat}

  ## 専門レビュー観点
  1. **障害シナリオ**: この変更が本番でどう壊れうるか、最低3つ列挙
     - 部分デプロイ時（新旧コード混在の瞬間）
     - 外部サービス障害時
     - 高負荷・並行リクエスト時
  2. **ロールバック可能性**: Y/N + 理由 + 手順
  3. **データ整合性**: 並行書き込み時の安全性
  4. **運用影響**: 監視すべきメトリクス、アラート閾値変更の要否

  ID: FI-R3-S{N}-{連番}
  """
)
```

---

## N-ver Implementer（Codex独立実装）Tier I3のみ

**Agent記号**: NV
**担当**: Implementerと独立に同じSliceを実装し、diff比較用の参照実装を提供
**起動Tier**: I3のみ

```
Agent(
  subagent_type="general-purpose",
  description="Codex N-version独立実装 Slice {N}",
  prompt="""
  以下のBashコマンドを実行してください。

  ```bash
  codex exec --full-auto --sandbox workspace-write \
    --cd "{プロジェクトディレクトリ}" \
    "以下の仕様に基づいてコードを実装してください。
     他の実装者の成果物は見ないでください。独立した判断で実装してください。

     ## Slice仕様
     Slice {N}: {Slice名}
     目的: {Slice目的}
     受入条件: {受入テスト条件}
     対象ファイル: {Slice計画の変更予定ファイル}

     ## ルール
     - テストがGREENになる最小限のコードを書く
     - 実装完了後、git diff --stat で変更を報告

     確認や質問は不要。"
  ```

  **実行後**: Codex実装とImplementer(Claude)実装のdiffを比較し、不一致箇所をリスト化して報告。
  タイムアウト: 300秒（Bash timeout: 600000ms）
  """
)
```

---

## Tier別エージェント起動マトリクス

| エージェント | 記号 | I0 | I1 | I2 | I3 |
|-------------|------|-----|-----|-----|-----|
| Implementer (Claude) | IM | o | o | o | o |
| Reviewer-1 ロジック (Claude) | R1 | o | o | o | o |
| Reviewer-2 影響範囲 (Codex) | R2 | - | o | o | o |
| Tester テスト強化 (Codex) | TS | - | o | o | o |
| Reviewer-3 障害シナリオ (Claude) | R3 | - | - | o | o |
| N-ver Implementer (Codex) | NV | - | - | - | o |
| **Slice単位の合計** | | **2** | **4** | **5** | **7** |

### Tier I0/I1 での責務統合

- **I0**: R1がロジック+要件+影響範囲+テスト観点を統合レビュー
- **I1**: R2がセキュリティもカバー（R3相当の観点をプロンプトに追記）

### Codex未インストール時のフォールバック

Codex CLIが利用不可の場合、R2/TS/NVを**Claude SubAgent（探索許可）** で代替。
Read/Grep/Glob ツールの使用を許可し、コード探索をClaude SubAgentに委任する。
