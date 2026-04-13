<!-- 抽出元: SKILL.md「Step 4.5: 多角的レビュー」セクション（旧 行455-554）
     + ワーカープロンプト内の「4.5. 多角的レビュー」セクション（旧 行750-854） -->

# 多角的レビュー（Tier別動的レビュアー: 2-4体）

## 概要

計画草案に対して3視点から並列レビューを実施し、品質を向上させる。
Grok の成果物は参照してよいが、**権威ソースではない**。レビューでは必ずローカルコードと計画本文を正とし、
Grok 由来のファイルパス、行番号、外部知見は実在性と裏取りの有無を確認する。

## 4.5a: Tier別レビュアー並列起動

### Tier別起動構成

| Tier | レビュアー | Agent tool | Bash tool | 合計 |
|------|----------|-----------|-----------|------|
| C (< 6) | A + C | x1 | x1 | 2体 |
| B (≥ 6) | A + B + C | x2 | x1 | 3体 |
| A (≥ 12) | A + B + C + D | x3 | x1 | 4体 |

Step 3.6 のTier判定結果に基づき、上記の構成でレビュアーを並列起動する。
Tier Cの場合、Reviewer B（アーキテクチャ適合性）は省略する。

以下の3つを **1ターン内で同時起動** する（Agent tool x2 + Bash tool x1 を並列呼び出し）。

**全レビュアー完了待ち（必須・違反禁止）:**
- Tier別の並列呼び出しが**全て完了（成功またはタイムアウト）するまで**、レビュー結果統合（4.5b）に進んではならない
- Reviewer C（Bash tool）には `timeout: 240000`（240秒）を指定すること（Codex起動オーバーヘッド含む）
- Reviewer Cがタイムアウトした場合: プロンプトを短縮（チェック項目を2つに削減、reasoning_effort="low"）して**1回リトライ**してからフォールバック判定すること

---

### Reviewer A: 技術的正確性（Claude サブエージェント, subagent_type: general-purpose）

チェック項目:
1. ファイルパス実在確認: 計画に記載された全ファイルパスが実在するか Glob/Read で検証
2. Before/After整合性: Before コードが実際のファイル内容と一致するか確認
3. 影響範囲網羅性: 変更ファイルから import/参照されているファイルが影響範囲に含まれているか
4. 型整合性: 変更後のインターフェースが呼び出し元と整合するか
5. コード鮮度検証: 変更対象ファイルが直近2週間で他Issueにより変更されていないか（`git log -5 -- <file>`）、計画のBefore/Afterが最新コードと一致しているか
6. Grok由来情報の実在性: Grok メモに引っ張られた非実在パスや未検証の外部知見が計画本文に混入していないか

出力形式: `{"reviewer":"A","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"file_path|before_after|impact_scope|type_safety|code_freshness|grok_verification","description":"...","fix":"..."}]}`

---

### Reviewer B: アーキテクチャ適合性（Claude サブエージェント, subagent_type: general-purpose）

チェック項目:
1. 命名規則整合: 既存コードの命名パターンと整合するか
2. YAGNI違反検出: 不必要な抽象化や過剰設計がないか
3. 既存util見落とし: 同等機能の既存ユーティリティがあるのに新規作成していないか
4. 代替アプローチ提案: よりシンプルまたは既存パターンに沿った代替案がないか
5. 既存util適用可否: 「似た関数がある」だけでなく、入力型（文字列 vs 数値）と操作（フォーマット変換 vs 単位変換）が一致するかを検証。不適用の場合は行番号で根拠を明記
6. Grok由来知見の扱い: 外部知見や Xポスト由来知見が、過剰設計や不要な抽象化の根拠になっていないか

出力形式: `{"reviewer":"B","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"naming|yagni|existing_util|alternative|grok_scope","description":"...","fix":"..."}]}`

---

### Reviewer C: Devil's Advocate（Codex CLI, read-only, stdin）

チェック項目:
1. 弱点・見落とし: 計画が考慮していないエッジケースや障害シナリオ
2. 工数妥当性: 見積もりが楽観的すぎないか、隠れた作業がないか
3. ロールバック可能性: 変更を安全に元に戻せるか、破壊的変更がないか。DBスキーマ変更の有無、影響レコードの特定方法、git revert の可否
4. エッジケース: 並行処理、null値、空配列、タイムゾーン等の考慮漏れ
5. 既存変更との重複: 他のクローズ済みIssue/マージ済みPRで既に同様の変更が実装されていないか
6. NaN/Infinity ガード: 数値変換（Number(), parseInt(), parseFloat()）の後に Number.isFinite() チェックがあるか
7. キー重複: オブジェクトスプレッド後に camelCase/snake_case の同名キーが同居しないか
8. 未検証知見の混入: `verification_required=true` の Grok知見が、検証なしで計画へ混入していないか

出力形式: `{"reviewer":"C","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"weakness|effort|rollback|edge_case|duplication","description":"...","fix":"..."}]}`

各レビュアーの制限: 出力は1500トークン以内。180秒以内に完了すること。

---

### Reviewer D: Security Reviewer（Claude サブエージェント, subagent_type: general-purpose — Tier Aのみ）

チェック項目:
1. 認証バイパスリスク: 計画の変更がgetUserIdFromRequest()等の認証経路をバイパスする可能性
2. 認可漏れ: org_idフィルタの欠如、テナント分離の崩壊リスク
3. RLSポリシー整合性: Supabase RLSの変更が既存ポリシーと矛盾しないか
4. 課金ロジック安全性: クレジット消費のアトミシティ、Stripe連携の冪等性
5. 機密情報露出: 環境変数・APIキーのフロントエンド露出リスク

出力形式: `{"reviewer":"D","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"auth_bypass|authz_leak|rls_policy|billing_safety|secret_exposure","description":"...","fix":"..."}]}`

---

### Reviewer C の Codex 実行テンプレート

```bash
cat > /tmp/review_prompt_{number}.txt << 'REVIEW_EOF'
あなたはDevil's Advocate（悪魔の代弁者）です。実装計画の弱点を指摘してください。

チェック項目:
1. 弱点・見落とし: エッジケースや障害シナリオの考慮漏れ
2. 工数妥当性: 見積もりが楽観的すぎないか
3. ロールバック可能性: 変更を安全に元に戻せるか
4. エッジケース: 並行処理、null値、空配列、タイムゾーン等
5. 既存変更との重複: 他のクローズ済みIssue/マージ済みPRで同様の変更が実装済みでないか

出力形式（JSON）:
{"reviewer":"C","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"weakness|effort|rollback|edge_case|duplication","description":"...","fix":"..."}]}

計画内容:
{計画草案のMarkdown全文}
REVIEW_EOF

# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/review_prompt_{number}.txt | codex exec \
  --full-auto \
  --sandbox read-only \
  --cd "{project_dir}" \
  -c model_reasoning_effort="medium" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_review_{number}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Reviewer C異常終了 (exit=$CODEX_EXIT) ==="
  cat /tmp/codex_review_{number}_$$.txt
fi

rm -f /tmp/review_prompt_{number}.txt
```

### Reviewer Cタイムアウト時のリトライ（1回のみ）

タイムアウトした場合、以下の短縮プロンプトで1回リトライする:
```bash
cat > /tmp/review_retry_{number}.txt << 'RETRY_EOF'
実装計画の弱点を2点指摘してください。
チェック: (1)エッジケース見落とし (2)工数の楽観性
JSON出力: {"reviewer":"C","grade":"A|B|C|D","findings":[...]}

計画内容:
{計画草案のMarkdown全文（1000文字以内に圧縮）}
RETRY_EOF

# *** Bash tool timeout: 240000 を必ず指定すること ***
cat /tmp/review_retry_{number}.txt | codex exec \
  --full-auto --sandbox read-only --cd "{project_dir}" \
  -c model_reasoning_effort="low" -c features.rmcp_client=false - \
  2>&1 | tee /tmp/codex_review_{number}_$$.txt
CODEX_EXIT=${PIPESTATUS[0]}
if [ $CODEX_EXIT -ne 0 ]; then
  echo "=== Reviewer Cリトライ異常終了 (exit=$CODEX_EXIT) ==="
  cat /tmp/codex_review_{number}_$$.txt
fi

rm -f /tmp/review_retry_{number}.txt
# クリーンアップ: レビュー完了後に rm -f /tmp/codex_review_{number}_$$.txt
```

---

## 4.5b: レビュー結果統合 + 完了率ゲート

各レビュアーの出力をJSONとしてパースし、severity別に分類する。

**統合ルール:**

| severity | 対応 | 修正先セクション |
|----------|------|-----------------|
| critical | 必須修正 | 実装ステップ（パス修正、コード修正） |
| major | 修正推奨 | 影響範囲テーブル追加、リスク評価追加 |
| minor | 情報追加 | テスト計画に項目追加 |
| suggestion | 反映しない | -- |

**品質スコア算出:**
```
grade: A=4, B=3, C=2, D=1, N/A=除外
composite_score = 成功レビュアーの平均
composite_grade: 3.5-4.0=A, 2.5-3.4=B, 1.5-2.4=C, 1.0-1.4=D
```

**レビュー完了率ゲート（定量判定 — 教訓から追加）:**

統合前に以下の数値を算出し、投稿可否を機械的に判定する:

| メトリクス | 算出方法 | 投稿条件 |
|-----------|---------|---------|
| `review_completion_rate` | 成功レビュアー数 / tier_reviewer_count（JSONパース成功 = 成功） | **>= 67%**（2/3以上） |
| `critical_open` | 全レビュアーのcritical findings合計 - 修正適用済み数 | **== 0** |

**投稿判定マトリクス:**

| completion_rate | critical_open | 判定 | アクション |
|:---:|:---:|:---:|------|
| 100% (3/3) | 0 | **投稿可** | Step 4.7（final-check）へ進む |
| 67% (2/3) | 0 | **投稿可** | Step 4.7（final-check）へ進む |
| 67%+ | > 0 | **投稿不可** | critical修正を適用して再統合 |
| 33% (1/3) | 0 | **条件付き投稿** | composite_grade B以上なら投稿可、C以下なら計画見直し |
| 0% (0/3) | — | **フォールバック** | 計画草案をそのまま投稿（レビューなし明記） |

**Tier別completion_rate閾値:**
- Tier C (2体): >= 50% (1/2以上)
- Tier B (3体): >= 67% (2/3以上)
- Tier A (4体): >= 75% (3/4以上)

**品質ゲート（Issue #1560教訓）:**
- composite_grade が **D** の場合: 投稿禁止。計画を根本的に見直すこと
- composite_grade が **C** の場合: critical 指摘を全て解消してから再レビュー推奨
- 「既存util不適用」の指摘があった場合: **行番号付きの反証**を計画に明記すること（反証なしの「不要です」では B 止まり）
- **Aスコアの要件**: 全 critical 解消 + 全 major に対応/根拠明記 + エッジケース防御（NaN/キー正規化）+ ロールバック戦略記載
- **Grok利用時の追加要件**: `verification_required=true` の知見は本文に残さない。残す場合は根拠ファイルまたは検証手順を併記する

**エラーハンドリング:**

| 状況 | 対応 | completion_rate |
|------|------|:---:|
| 1レビュアー失敗（リトライ後） | 残り2つで統合（品質十分） | 67% |
| 2レビュアー失敗（リトライ後） | 残り1つで修正（最低限品質） | 33% |
| 全レビュアー失敗 | 計画草案をそのまま投稿（フォールバック、レビューなし明記） | 0% |
| JSON パース失敗 | そのレビュアーはスキップ扱い（失敗カウント） | 算出時に除外 |
| Reviewer Cタイムアウト | プロンプト短縮で1回リトライ -> 再失敗で失敗判定 | 失敗カウント |

## 4.5c: 修正適用

critical/major の指摘を計画草案に反映し、最終版を作成する。
**レビュー痕跡は最終版に含めない**（Issueコメントはクリーンな計画のみ）。

---

## Reviewer A/B のプロンプトテンプレート（ワーカー内使用）

**Reviewer A**（Agent tool, subagent_type: general-purpose）:
```
あなたは実装計画のレビュアーA（技術的正確性）です。
プロジェクトディレクトリ: {project_dir}

## チェック項目
1. ファイルパス実在確認: Glob/Read で全パスを検証
2. Before/After整合性: Before コードが実ファイルと一致するか
3. 影響範囲網羅性: import/参照先が影響範囲に含まれているか
4. 型整合性: 変更後のインターフェースが呼び出し元と整合するか
5. コード鮮度検証: 変更対象ファイルが直近2週間で他Issueにより変更されていないか、Before/Afterが最新コードと一致しているか
6. Grok由来情報の実在性: 非実在パスや未検証知見が混入していないか

## 出力（JSON、1500トークン以内）
{"reviewer":"A","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"file_path|before_after|impact_scope|type_safety|code_freshness|grok_verification","description":"...","fix":"..."}]}

## 計画内容
{計画草案のMarkdown全文}
```

**Reviewer B**（Agent tool, subagent_type: general-purpose）:
```
あなたは実装計画のレビュアーB（アーキテクチャ適合性）です。
プロジェクトディレクトリ: {project_dir}

## チェック項目
1. 命名規則整合: 既存コードの命名パターンと整合するか
2. YAGNI違反検出: 不必要な抽象化や過剰設計がないか
3. 既存util見落とし: 同等機能の既存ユーティリティの有無
4. 代替アプローチ: よりシンプルな代替案の提案
5. Grok由来知見の扱い: 外部知見が過剰設計の根拠になっていないか

## 出力（JSON、1500トークン以内）
{"reviewer":"B","grade":"A|B|C|D","findings":[{"severity":"critical|major|minor|suggestion","category":"naming|yagni|existing_util|alternative|grok_scope","description":"...","fix":"..."}]}

## 計画内容
{計画草案のMarkdown全文}
```
