# 多角的レビュー（クアドレビュー + /code-review）

## レーン構成

| Lane | レビュー種別 | 内容 |
|------|------------|------|
| Lane 0 | Codex diff | Codex CLIでdiff全体を分析、Critical/Normal指摘を抽出 |
| Lane 1 | sub-review: セキュリティ | 認証・認可・入力検証・秘密情報漏洩の観点 |
| Lane 2 | sub-review: パフォーマンス | N+1クエリ、不要再レンダリング、メモリリークの観点 |
| Lane 3 | sub-review: 保守性 | 命名規則、責務分離、テスタビリティの観点 |
| Lane 4 | sub-review: 仕様準拠 | Issue要件・受け入れ基準との整合性の観点 |
| Lane 5 | /code-review (soft gate) | CLAUDE.md/REVIEW.md準拠、git履歴、PR履歴コメント → GitHub PRコメント投稿 |

## Tier別レーン構成

Issueの Tier（リスクレベル）に応じてレビューレーン数を動的に決定する。

| Tier | Lane 0 (Codex) | Lane 1 (セキュリティ) | Lane 2 (パフォーマンス) | Lane 3 (保守性) | Lane 4 (仕様準拠) | Lane 5 (/code-review) | Phase 1 分母 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **C** (< 6) | o | - | - | - | o | soft gate | **2** |
| **B** (>= 6) | o | o | o | o | o | soft gate | **5** |
| **A** (>= 12) | o | o | o | o | o | soft gate | **5** |
| **不明** (null) | o | o | o | o | o | soft gate | **5** |

### Tier A 特記事項
- Tier A Issueには実装開始**前**に `/fortress-review --auto-gate` が実行される（ワーカー Step 0.5）
- fortress-review はレーンカウント（review_lanes_completed）には**含めない**
- fortress-review の結果は `issues[].fortress_review_result` に記録される

### Tier C 簡略化の根拠
- Lane 0（Codex diff）: 機械的なdiff分析はリスクレベルによらず必須
- Lane 4（仕様準拠）: Issue要件との整合性は最低限必要
- Lane 1-3（セキュリティ/パフォーマンス/保守性）: Tier C（スコア < 6）は認証・課金・DB migration等のセキュリティシグナルが非該当のためROIが低い
- Phase 2 soft gate（/code-review）: Tier C でも適用（CLAUDE.md/REVIEW.md 準拠確認）

## ゲート定義

### Phase 1: Hard Gate（Tier別分母 必須）
- 有効レーンが `review_lanes_completed={Tier別分母}/{Tier別分母}` を満たすこと
  - Tier C: `review_lanes_completed=2/2`
  - Tier B/A/不明: `review_lanes_completed=5/5`
- `critical_open=0`（Critical指摘が全て解消済み）であること
- **Phase 1 が未達の場合、merge許可を保留しフェーズBに進めない**

### Phase 2: Soft Gate（/code-review）
- Lane 5 の `/code-review` 結果を `phase2_code_review_status` で記録
- ステータス値: PASS | NO_FINDINGS | SKIPPED | FAILED
- **Phase 2 は soft gate**: FAILED/SKIPPED でもフェーズA完了を許可
- Normal指摘がある場合は修正推奨（ブロッキングではない）

## review_lanes_completed の定義

`review_lanes_completed` は Phase 1 の有効レーンのみをカウントする。

| Tier | 分母 | 対象レーン | Phase 2 |
|------|------|----------|---------|
| C | **2** | Lane 0 + Lane 4 | soft gate（変更なし） |
| B | **5** | Lane 0-4 | soft gate（変更なし） |
| A | **5** | Lane 0-4 | soft gate（変更なし） |
| 不明(null) | **5** | Lane 0-4 | soft gate（変更なし） |

> Tier情報が不明（tier=null、手動計画等）の場合、デフォルトで Tier B（5/5）を適用する。
> /code-review は Phase 2 soft gate。`review_lanes_completed` には含めない。`phase2_code_review_status` で別途記録。
> fortress-review は実装前の計画検証であり、Phase 1/2 どちらにも含めない。
