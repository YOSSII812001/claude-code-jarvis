---
name: detail-design-doc
description: |
  多様な入力ソースから200-500行の詳細設計書をMarkdownファイルとして生成する。
  トリガー: "/design-doc", "詳細設計", "設計書作成", "設計書", "詳細設計書", "design document"
  使用場面: 大規模機能開発、設計レビューが必要な場面、issue-planner前の設計フェーズ
---

# detail-design-doc スキル

## メタデータ
- **名前**: detail-design-doc（詳細設計書生成）
- **説明**: 多様な入力ソースから200-500行の詳細設計書をMarkdownファイルとして生成する
- **トリガー:** `/design-doc`, `詳細設計`, `設計書作成`, `設計書`, `詳細設計書`, `design document`
- **使用場面**: 大規模機能開発、設計レビューが必要な場面、issue-planner前の設計フェーズ

## 概要

issue-planner が GitHub Issue への「実装計画」（50-100行コメント）を自動生成するのに対し、
detail-design-doc は **単一の設計対象** に対して **200-500行の詳細設計書** を生成する。

### パイプライン上の位置づけ
```
detail-design-doc（詳細設計） → issue-planner（実装計画） → issue-autopilot-batch（自動実装）
```

### issue-planner との差別化

| 観点 | issue-planner | detail-design-doc |
|------|--------------|-------------------|
| 入力 | GitHub Issues URL（一括） | Issue / .md仕様書 / テキスト要件 |
| 対象 | 全オープンIssue一括 | 単一の設計対象 |
| 出力 | Issueコメント（50-100行） | Markdownファイル（200-500行） |
| セクション | 12項目（影響範囲中心） | 14項目（設計判断・ADR含む） |
| ADR | なし | 必須 |
| Agent Teams | 使用（並列ワーカー） | 不使用（単一パイプライン） |
| design-review-checklist | 非統合 | Phase 1-5 統合 |
| セキュリティ視点 | なし | Reviewer C に追加 |

---

## 入力形式（3種類）

| 入力種別 | 例 | Step 1 での処理 |
|---------|-----|----------------|
| GitHub Issue | `#123` or URL | `gh issue view` で取得 → 要件構造化 |
| .md仕様書 | `specs/feature-x.md` | Read で読み取り → 要件抽出・構造化 |
| テキスト要件 | 口頭/チャットでの要件記述 | そのまま要件として構造化 |

※ .md仕様書が最も情報量が多く、設計書の品質も高くなる傾向がある。

---

## プロジェクトディレクトリ推定

MEMORY.md の「プロジェクトパス」セクションから推定する。
明示的に指定された場合はそちらを優先。

---

## 核心ルール（5項目）

### 1. 推測禁止
既存コード調査を完了してから設計する。design-review-checklist Phase 1 を必ず実行。
「〜だろう」「〜のはず」で設計しない。Codex/Glob/Grep/Read で実際のコードを確認する。

### 2. ADR必須
設計判断には必ず代替案比較を Architecture Decision Records（セクション13）に記録する。
最低1件のADRを含むこと。自明な判断でも「既存パターン踏襲の判断」として記録する。

### 3. 3視点レビュー完了待ち必須
Reviewer A, B, C の全てが完了するまで最終版を作成しない。
1つでも実行中の場合は待機する。詳細は `references/design-review-perspectives.md` 参照。

### 4. N/Aセクション明示
該当しないセクションも理由付きで記載する。空にしない。
例: `## 4. DB設計\n> N/A: フロントエンドのみの変更のため、DB設計は対象外。`

### 5. コード貼りすぎ禁止
インターフェース定義と重要ロジックのみ掲載する。設計書の肥大化を防止。
1セクションあたりコードブロック最大3つ、1ブロック最大30行、全体コード比率30%以下。

---

## ワークフロー（6ステップ）

| Step | 内容 | 実行方式 |
|------|------|---------|
| 1 | 入力解析 + 要件整理 | 直接実行 |
| 2 | コードベース調査（Codex + design-review-checklist） | 直接実行 |
| 3 | 設計書ドラフト作成（テンプレートに構造化） | 直接実行 |
| 4 | 3視点並列レビュー | 並列サブエージェント |
| 5 | レビュー反映 + 最終版作成 | 直接実行 |
| 6 | 保存 + 報告 | 直接実行 |

※ 単一設計対象のため Agent Teams (TeamCreate/TaskCreate) は不使用。
  レビューの並列サブエージェントのみ使用。

---

## Step 1: 入力解析 + 要件整理

### GitHub Issue 入力
```bash
gh issue view {number} --repo {owner/repo} --json title,body,labels,milestone
```
- Issue本文から要件を抽出・構造化
- ラベルから分類（bug/feature/improvement等）を判定
- 不明確な要件は「要確認」マーク

### .md仕様書入力
- `Read` で仕様書を読み取り
- 要件・ユースケース・制約セクションを抽出
- FR-XX / NFR-XX のID体系に整理

### テキスト要件入力
- ユーザーの記述をそのまま要件として構造化
- 曖昧な記述は具体化を試みる
- 抜けている非機能要件を補完

### 出力
要件の構造化リスト（FR-XX / NFR-XX形式）

---

## Step 2: コードベース調査

詳細は `references/investigation-workflow.md` を参照。

1. **Step 2a**: Codex CLI 調査（8項目分析）
   - stdin経由、read-only、MCP無効化、タイムアウト180秒
   - フォールバック4段階
2. **Step 2b**: design-review-checklist 統合
   - 設計内容に応じて Phase 1.1〜1.5, Phase 4, Phase 5 を選択実行
3. **Step 2c**: コード現状検証
   - git log -5 で変更対象ファイルの最新状態確認
   - 複雑度分類（低/中/高）

---

## Step 3: 設計書ドラフト作成

`references/design-template.md` のテンプレートに沿って設計書を構造化する。

- Step 1 の要件をセクション2に配置
- Step 2 の調査結果を各セクションに反映
- N/Aセクションは理由を明記（核心ルール#4）
- ADRは最低1件記録（核心ルール#2）
- コード量を制限（核心ルール#5）

各セクションの記述ガイドは `references/section-guide.md` を参照。

---

## Step 4: 3視点並列レビュー

詳細は `references/design-review-perspectives.md` を参照。

3つのレビューを **並列に** 実行:

```
# Reviewer A（技術的実現可能性）と B（アーキテクチャ適合性）を Agent で並列起動
Agent(name="design-reviewer-a", prompt=..., subagent_type="general-purpose")
Agent(name="design-reviewer-b", prompt=..., subagent_type="general-purpose")

# Reviewer C（Devil's Advocate + セキュリティ）を Codex CLI で実行
Bash(codex exec --mode read-only ...)
```

**全レビュアー完了待ち必須**（核心ルール#3）。

---

## Step 5: レビュー反映 + 最終版作成

### Severity別対応
| Severity | 対応 |
|----------|------|
| critical | 必須修正 |
| major | 修正推奨（修正しない場合はADRに根拠を記録） |
| minor | テスト戦略/リスクセクションに追記 |
| suggestion | 反映しない（付録Cに記録のみ） |

### 品質スコア算出
```
グレード換算: A=4, B=3, C=2, D=1
composite_score = (gradeA + gradeB + gradeC) / 3
composite_grade: 3.5-4.0=A, 2.5-3.4=B, 1.5-2.4=C, 1.0-1.4=D
```

### 最終版作成
- critical/major の指摘を反映
- レビュー痕跡を除去
- 付録Cにレビュー履歴を記録
- ヘッダーに品質スコアを記載

---

## Step 6: 保存 + 報告

### 出力先
```
{project_dir}/tasks/designs/design-{identifier}-{YYYYMMDD}.md
```

#### ファイル名規則
| 入力種別 | ファイル名例 |
|---------|------------|
| Issue入力 | `design-issue-123-20260309.md` |
| 仕様書入力 | `design-{仕様書名slug}-20260309.md` |
| テキスト入力 | `design-{タイトルslug}-20260309.md` |

### オプション: Issueコメント投稿
Issue入力かつユーザーが指定した場合のみ、サマリ版をIssueコメントに投稿。

サマリ版の構成:
```markdown
## 詳細設計書サマリ
> 完全版: tasks/designs/design-issue-{number}-{date}.md

### 概要
{セクション1の要約}

### 主要設計判断
{ADRの要約}

### 影響範囲
{セクション14のファイルテーブル}

### 品質スコア: {grade}
```

### 報告
保存完了後、以下を報告:
- 保存先ファイルパス
- 品質スコア
- レビュー指摘の要約（critical/major件数）
- 次のステップ推奨（issue-planner / 直接実装）

---

## エラーハンドリング

### Codex CLI 失敗時
フォールバック4段階（`references/investigation-workflow.md` 参照）:
1. プロンプト短縮（200文字）
2. `--reasoning-effort medium`
3. `--skip-git-repo-check`
4. Glob/Grep/Read による手動調査

### レビュー失敗時
- 1レビュアー失敗 → 残り2つで統合
- 2レビュアー失敗 → 残り1つで統合
- 全レビュアー失敗 → ドラフトをそのまま保存（品質スコア: N/A）

### Issue取得失敗時
- `gh` コマンドの認証確認
- レポジトリURL/番号の確認を促す

---

## アンチパターン（6項目）

1. **コード調査なしの設計**: 既存コードを見ずにアーキテクチャを決定してはならない
2. **ADR省略**: 「自明だから」と判断記録を省略してはならない
3. **レビュー途中での最終版作成**: 全レビュアー完了前に保存してはならない
4. **N/Aセクションの空欄**: 理由なしにセクションを空にしてはならない
5. **コードの全文貼り付け**: 設計書に実装コードの全文を貼り付けてはならない
6. **推測ベースの設計**: 「おそらく〜」で設計を進めてはならない。実コードで検証する

---

## 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| `references/design-template.md` | 14セクション設計書Markdownテンプレート |
| `references/investigation-workflow.md` | Codex + design-review-checklist 統合調査ワークフロー |
| `references/design-review-perspectives.md` | 3視点レビュー（設計書向け調整版） |
| `references/section-guide.md` | 各セクション記述ガイド + ADRテンプレート |

---

## クイックスタート

### Issue入力
```
/design-doc #123
```

### .md仕様書入力
```
/design-doc specs/feature-x.md
```

### テキスト要件入力
```
/design-doc ユーザーダッシュボードに通知機能を追加。リアルタイム通知とバッジ表示が必要。
```

---

## 関連スキル

| スキル | 関係 |
|--------|------|
| `design-review-checklist` | Phase 1-5 を Step 2b で統合 |
| `issue-planner` | パイプラインの下流。設計書の実装計画への分解 |
| `issue-autopilot-batch` | パイプラインのさらに下流。計画済みIssueの自動実装 |
| `codex` | Codex CLI の汎用利用スキル |

## 設計書品質チェックリスト

- [ ] 入力ソース（Issue/要件/口頭説明）を明示的に記載したか
- [ ] DB変更がある場合、マイグレーションSQLを含めたか
- [ ] API変更がある場合、エンドポイント仕様を含めたか
- [ ] 既存コードとの統合ポイントを明記したか
- [ ] エラーハンドリング方針を記載したか

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-01 | 初版作成 | 詳細設計書生成スキルの体系化 |
| 2026-03-18 | YAML frontmatter追加、改訂履歴見出し化、チェックリスト追加 | skill-improve audit対応 |
