# 敵対的E2E監査（パイプライン ステップ9.5）

> テスト実施者（メインエージェント）とは**別のサブエージェント**がE2E証跡を検証する。
> 「テスト実施者が自分で評価する」構造的矛盾を解消し、PASS/BLOCKを機械的に判定する。

## 背景

過去5回以上、E2Eテスト後に「自信を持ってテストした」と自己申告したが、
ユーザーの追加質問でテスト漏れが発覚するパターンが再発した（#1071, #1084, #1133, #1305-7, #1322）。
根本原因は confidence_gate の自己採点構造。本監査で第三者検証を導入する。

---

## 監査サブエージェントへの入力

メインエージェントは以下の4点を監査サブエージェントに渡す:

| # | 入力データ | 取得方法 |
|---|-----------|---------|
| I1 | Issue本文（修正の目的・要件） | `gh issue view <番号> --json title,body` |
| I2 | git diff（staging vs mainの全変更） | `git diff origin/main...origin/staging` |
| I3 | テスト計画JSON（e2e-test-plan-v2 完成版） | Phase 3.5の最終JSON出力 |
| I4 | CodeRabbit PRコメント（全件） | `gh api repos/<owner>/<repo>/pulls/<PR番号>/comments --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body'` |

---

## 監査の4つの問い

監査サブエージェントは以下の4問を順に検証する。

### Q1: 証跡確認（Evidence Verification）

> 「テスト計画の各PASS項目に、**操作ログまたはスクリーンショットの証跡**が添付されているか?」

| チェック | 判定 |
|---------|------|
| result="PASS" の全itemに evidence が非null かつ操作詳細を含む | OK |
| evidence が「PASS」のみ（操作詳細なし） | BLOCK |
| evidence が null または空文字 | BLOCK |

### Q2: 計画完了確認（Plan Completion Verification）

> 「テスト計画の**全項目**にresultが記入され、SKIPには妥当な理由があるか?」

| チェック | 判定 |
|---------|------|
| 全itemの result が非null | OK |
| priority="high" の item に SKIP がある | BLOCK（高優先度のスキップ不可） |
| SKIP の skip_reason が「コスト」「時間」「たぶん大丈夫」等の曖昧な理由 | BLOCK |

### Q3: ギャップ分析（Gap Analysis）

> 「git diffの変更箇所が、テスト計画で**全てカバー**されているか?」

| チェック | 判定 |
|---------|------|
| git diff の user_facing ファイル（.tsx, .ts のUI/API）が items[].changed_files に全て含まれる | OK |
| カバーされていない user_facing 変更がある | BLOCK（カバレッジギャップ） |
| Issue本文の要件に対応するL2テスト項目がない | BLOCK |

### Q4: CodeRabbitコメント最終確認

> 「feature→staging PRのCodeRabbitコメントに、**未対応の指摘**が残っていないか?」

| チェック | 判定 |
|---------|------|
| エラー/警告レベルの指摘が全て対応済み | OK |
| 確認推奨項目が検討済み（対応 or 妥当な理由でスキップ） | OK |
| 未対応のエラー/警告が残っている | BLOCK |
| CodeRabbitコメントを取得していない（I4が空） | BLOCK |

---

## PASS/BLOCK判定

```
Q1=OK AND Q2=OK AND Q3=OK AND Q4=OK → PASS（ステップ10へ進む）
いずれかBLOCK → BLOCK（理由を報告、追加テスト→再監査）
```

## BLOCK時のフロー

1. 監査サブエージェントがBLOCK理由を具体的に報告（どのitemが不備か、何が不足か）
2. メインエージェントが不備箇所の追加テストを実施
3. テスト計画JSONを更新（evidence追加、未カバー項目追加等）
4. **再度監査サブエージェントを起動**（同じ4問で再検証）
5. PASS するまでループ（最大3回。3回BLOCKでユーザーにエスカレーション）

---

## サブエージェント起動テンプレート

```
Agent(
  description="敵対的E2E監査",
  subagent_type="general-purpose",
  prompt="""
あなたはE2E監査官です。テスト実施者とは独立した立場で、テスト証跡の品質を検証します。
テスト実施者の「自信がある」「問題ない」という主張は無視してください。
証跡（evidence）のみを根拠に判定してください。

## 入力
### I1: Issue本文
{issue_body}

### I2: git diff（変更ファイル一覧）
{git_diff_stat}

### I3: テスト計画JSON
{test_plan_json}

### I4: CodeRabbit PRコメント
{coderabbit_comments}

## 検証手順
1. Q1（証跡確認）: 各PASS項目のevidenceに具体的な操作ログが含まれるか検証
2. Q2（計画完了）: 全項目にresultがあるか、SKIPの理由は妥当か検証
3. Q3（ギャップ分析）: git diffの変更ファイルとテスト計画のchanged_filesを突合し、
   カバーされていないuser_facingファイルを特定。Issue本文の要件に対するL2テスト項目を確認
4. Q4（CodeRabbit）: 未対応のエラー/警告レベル指摘がないか確認

## 出力形式
Q1: OK/BLOCK — （理由）
Q2: OK/BLOCK — （理由）
Q3: OK/BLOCK — （理由）
Q4: OK/BLOCK — （理由）
総合判定: PASS/BLOCK
BLOCK時の具体的な修正指示: （何をすればPASSになるか）

厳格に判定してください。曖昧な証跡はBLOCKとしてください。
"""
)
```

---

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-04 | 初版作成（Q1-Q3 + Q4 CodeRabbit確認） | E2E自己採点の構造的矛盾解消（5回以上再発の根本対策） |
