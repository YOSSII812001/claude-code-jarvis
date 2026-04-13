# 3視点レビュー（設計書向け調整版）

> issue-planner の multi-perspective-review.md をベースに、設計書レビュー向けに調整。
> セキュリティ視点の追加、DB/API設計の妥当性チェック強化が主な差分。

---

## レビュー概要

| Reviewer | 視点 | 実行方式 | タイムアウト |
|----------|------|---------|------------|
| A | 設計の技術的実現可能性 | Claude サブエージェント | なし |
| B | アーキテクチャ適合性 + YAGNI | Claude サブエージェント | なし |
| C | Devil's Advocate + セキュリティ | Codex CLI (read-only, stdin) | 240秒 |

**全レビュアー完了待ち必須**（核心ルール#3）。1つでも未完了のまま最終版を作成してはならない。

---

## Reviewer A: 設計の技術的実現可能性

**実行方式**: Claude サブエージェント（Agent ツール、一般目的）
**ツール使用**: Glob, Grep, Read（コードベース検証用）

### チェック項目

1. **ファイルパス実在確認**
   - 設計書で言及された全ファイルパスを `Glob` で検証
   - 存在しないパスがある場合: critical

2. **既存コードとの整合性**
   - 設計で前提とした構造が実際のコードと一致するか `Read` で確認
   - 前提と実態に乖離がある場合: critical

3. **型整合性**
   - 新規インターフェース/型定義と既存型の矛盾を検証
   - TypeScript の型エラーを引き起こす設計がないか
   - 矛盾がある場合: major

4. **DB設計の妥当性**
   - テーブル定義が既存スキーマと整合するか
   - RLSポリシーが既存パターンと一貫しているか
   - マイグレーションの安全性（DROP操作の影響）
   - TIMESTAMPTZ の使用確認
   - 問題がある場合: critical（データ損失リスク）/ major（不整合）

5. **API設計の妥当性**
   - ルーティングパターンが既存と整合するか
   - リクエスト/レスポンス型が既存パターンと一致するか
   - 問題がある場合: major

### プロンプトテンプレート

```
あなたは設計書の技術的実現可能性をレビューするレビュアーです。

以下の設計書ドラフトを読み、技術的な正確性を検証してください。
特に以下の点に注目してください:
1. ファイルパスの実在確認（Globで検証）
2. 既存コードとの整合性（Readで確認）
3. 型定義の矛盾
4. DB設計の妥当性（既存スキーマとの整合）
5. API設計の妥当性（既存パターンとの整合）

プロジェクトディレクトリ: {project_dir}

【設計書ドラフト】
{draft_content}

以下のJSON形式で結果を出力してください:
{
  "grade": "A|B|C|D",
  "findings": [
    {
      "severity": "critical|major|minor|suggestion",
      "category": "file_path|code_consistency|type_safety|db_design|api_design",
      "description": "指摘内容",
      "evidence": "根拠（実際のコードやファイルパス）",
      "recommendation": "修正案"
    }
  ],
  "summary": "レビュー総評"
}
```

---

## Reviewer B: アーキテクチャ適合性 + YAGNI

**実行方式**: Claude サブエージェント（Agent ツール、一般目的）
**ツール使用**: Glob, Grep, Read（パターン検証用）

### チェック項目

1. **命名規則整合**
   - ファイル名、関数名、変数名、テーブル名がプロジェクトの既存規則に従っているか
   - 不整合がある場合: minor

2. **YAGNI違反検出**
   - 要件に含まれない機能が設計に含まれていないか
   - 過度な抽象化、未使用の拡張ポイントがないか
   - 違反がある場合: major

3. **既存util見落とし**
   - 設計で新規作成しようとしているものが、既存のユーティリティで実現可能でないか
   - 見落としがある場合: major

4. **設計の完全性（要件カバー率）**
   - 要件定義（FR/NFR）の全項目が設計でカバーされているか
   - 未カバーの要件がある場合: critical

5. **実装ステップの妥当性**
   - Phase分けが論理的か（依存関係の順序）
   - 各ステップの粒度が適切か
   - 問題がある場合: minor

### プロンプトテンプレート

```
あなたは設計書のアーキテクチャ適合性をレビューするレビュアーです。

以下の設計書ドラフトを読み、プロジェクトのアーキテクチャとの適合性を検証してください。
特に以下の点に注目してください:
1. 命名規則の整合性
2. YAGNI違反（不要な機能・過度な抽象化）
3. 既存ユーティリティの見落とし
4. 要件カバー率（全FR/NFRがカバーされているか）
5. 実装ステップの妥当性

プロジェクトディレクトリ: {project_dir}

【設計書ドラフト】
{draft_content}

以下のJSON形式で結果を出力してください:
{
  "grade": "A|B|C|D",
  "findings": [
    {
      "severity": "critical|major|minor|suggestion",
      "category": "naming|yagni|existing_util|completeness|step_validity",
      "description": "指摘内容",
      "evidence": "根拠",
      "recommendation": "修正案"
    }
  ],
  "summary": "レビュー総評"
}
```

---

## Reviewer C: Devil's Advocate + セキュリティ

**実行方式**: Codex CLI（read-only, stdin経由）
**タイムアウト**: 240秒
**失敗時リトライ**: プロンプト短縮で1回

### チェック項目

1. **エッジケース見落とし**
   - 並行処理、null/undefined、空配列、タイムゾーン、大量データ
   - 見落としがある場合: major

2. **工数妥当性**
   - 実装ステップの工数が過小/過大でないか
   - 隠れた作業（マイグレーション、テスト、ドキュメント）が含まれているか
   - 問題がある場合: minor

3. **セキュリティ脆弱性**
   - SQLインジェクション: 動的クエリ構築の有無
   - XSS: ユーザー入力のサニタイズ
   - CSRF: トークン検証
   - 認証バイパス: RLSの抜け穴
   - 脆弱性がある場合: critical

4. **データ整合性**
   - レースコンディション: 並行更新時のデータ整合性
   - トランザクション境界: 複数テーブル操作時のatomicity
   - 問題がある場合: critical

5. **代替案の見落とし**
   - ADRに記載されていない有力な代替案がないか
   - 既存の解決策やライブラリで代替可能でないか
   - 見落としがある場合: suggestion

### Codex プロンプト

```
あなたはDevil's Advocateとして設計書をレビューします。
設計の弱点、見落とし、セキュリティリスクを徹底的に洗い出してください。

【設計書ドラフト】
{draft_content_shortened}

以下の5点を厳しくチェックしてください:
1. エッジケース見落とし（並行処理、null、空配列、タイムゾーン、大量データ）
2. 工数妥当性（隠れた作業の有無）
3. セキュリティ脆弱性（SQLi, XSS, CSRF, 認証バイパス）
4. データ整合性（レースコンディション、トランザクション境界）
5. 代替案の見落とし

JSON形式で出力:
{"grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"edge_case|effort|security|data_integrity|alternative","description":"","recommendation":""}],"summary":""}
```

### フォールバック
- タイムアウト(240秒): プロンプトを短縮して1回リトライ
- リトライも失敗: Reviewer C の結果なしで統合（2視点で評価）

---

## レビュー結果統合

### Severity別対応（issue-planner踏襲）

| Severity | 対応 | 設計書への反映 |
|----------|------|--------------|
| critical | 必須修正 | 該当セクションを修正、修正理由を記載 |
| major | 修正推奨 | 可能な限り反映、判断理由をADRに記録 |
| minor | テスト追加 or 注記 | テスト戦略セクションに追加、またはリスクに記載 |
| suggestion | 反映しない | レビュー履歴（付録C）に記録のみ |

### 品質スコア算出（issue-planner踏襲）

```
グレード換算: A=4, B=3, C=2, D=1
composite_score = (gradeA + gradeB + gradeC) / 3
  ※ Reviewer C 失敗時: (gradeA + gradeB) / 2

composite_grade:
  3.5 - 4.0 → A
  2.5 - 3.4 → B
  1.5 - 2.4 → C
  1.0 - 1.4 → D
```

### エラーハンドリング

| 状況 | 対応 |
|------|------|
| 1レビュアー失敗 | 残り2つの結果で統合 |
| 2レビュアー失敗 | 残り1つの結果で統合（品質スコアは単独グレード） |
| 全レビュアー失敗 | 設計書ドラフトをそのまま最終版として保存（品質スコア: N/A） |

### 修正適用手順

1. critical の指摘を全て修正
2. major の指摘を判断の上で修正（修正しない場合はADRに根拠を記録）
3. minor の指摘をテスト戦略/リスクセクションに反映
4. レビュー痕跡（修正メモ等）は最終版から除去
5. 付録Cにレビュー履歴を記録

---

## 並列実行の実装

3つのレビューは **並列に** 実行する:

```
# Reviewer A と B は Agent ツールで並列起動
Agent(name="reviewer-a", prompt=reviewer_a_prompt)
Agent(name="reviewer-b", prompt=reviewer_b_prompt)

# Reviewer C は Bash ツールで Codex CLI 実行
Bash(command=codex_reviewer_c_command)

# 全完了を待って統合
```

Reviewer A, B, C の全てが完了してから統合フェーズに進む。
1つでも実行中の場合は待機する。
