---
name: fortress-implement
description: |
  単一の実装タスクを絶対に失敗させずに完遂する、多重防御実装実行スキル。
  タスクをSlice（最小検証可能単位）に分解し、各Sliceで
  テスト先行→実装→クロスチェック→Safe Pointのループを回す。
  Codex×Grok×Qwen×Claudeの四者分析から導出した「Slice & Prove方式」を採用。
  トリガー: "fortress-implement", "要塞実装", "絶対失敗しない実装", "fail-proof implement",
  "安全実装", "fortress-exec", "ここぞの実装"
  使用場面: (1) DB migration + 認証が絡む重大実装、(2) 本番障害修正で再発が許されない場合、
  (3) アーキテクチャ変更の段階的実装、(4) 1つのタスクを確実に完遂したい場合
---

# fortress-implement — 絶対失敗しない実装実行スキル

> **Learning Style Override**: このスキル実行中は「Learn by Doing」（Your Task / TODO(human)）を**無効**とする。Slice実装ループの中断は品質保証パイプラインを破壊するため、人間への実装委譲は行わない。Insightの提供は各Phase完了時に限定する。

## 概要

単一の実装タスクを**Slice（最小検証可能単位）に分解**し、各Sliceで「テスト先行→実装→クロスチェック→Safe Point」のループを回す。失敗したら直近のSafe Pointに戻って再設計する。**速く作るスキルではなく、止まるべき時に止まり、戻るべき時に戻り、最後に証明して終えるスキル。**

```
  +-----------------------------------------------------+
  |  Phase 0: 要件凍結（曖昧さゼロをゲート条件）         |
  +------------------------+----------------------------+
                           |
                           v
  +-----------------------------------------------------+
  |  Phase 1: 設計検証 & Slice計画                       |
  |  （Tier判定 -> fortress-review[I2+] -> Slice分解）   |
  +------------------------+----------------------------+
                           |
                           v
  +-----------------------------------------------------+
  |  Phase 2: Slice実装ループ（コアフェーズ）             |
  |  LOOP(each Slice):                                  |
  |    A: テスト先行 -> B: 最小差分実装 -> C: クロスチェック|
  |    -> D: 全検証 -> E: Safe Point                    |
  |    Gate FAIL -> Self-Healing Loop                   |
  +------------------------+----------------------------+
                           |
                           v
  +-----------------------------------------------------+
  |  Phase 3: 統合検証（回帰テスト + E2E）               |
  +------------------------+----------------------------+
                           |
                           v
  +-----------------------------------------------------+
  |  Phase 4: 証跡パック & Go/No-Go 最終判定             |
  +-----------------------------------------------------+
```

### 設計根拠（四者分析の統合）

| 提案者 | 主要な主張 | 採用/却下 | 理由 |
|--------|----------|-----------|------|
| Codex (gpt-5.4) | Slice & Safe Point方式、7論理ロール、I0-I4の5段Tier | **主軸採用** | 実用性最高。「小さく進め、毎回検証、毎回戻せる」哲学が核心 |
| Grok 4.20 | 4フェーズ4ロール、Implementation Triangulation | **部分採用** | 4ロールに簡素化、3層防御の概念を統合検証に反映 |
| Qwen 3.6 plus | N-version programming、AST投票、トランザクショナルログ | **コンセプト採用** | N-ver投票はI2+のcriticalロジックのみ適用（コスト考慮） |
| Claude (最終判定) | 上記の実用的統合、SKILL.md形式での具体化 | **最終設計** | 過剰設計を排除し、Claude Code上で実際に動作する設計に |

### 核心原則（四者一致点）

1. **テスト先行は絶対** — bugは再現テスト、featは受入テストを先に書く
2. **1 Sliceは1つの関心事** — リファクタ・機能追加・依存更新を混ぜない
3. **クロスチェックは実装者以外** — 自己正当化を構造的に排除
4. **Safe Pointは省略不可** — 5点セット（スナップショット、合格テスト一覧、変更ファイル、ロールバック手順、前提メモ）
5. **完了 = 証明** — コードを書いたことではなく、証跡パックが揃ったこと

---

## Phase 0: 要件凍結（Intake Freeze）

以下のいずれかを入力として受け付ける:

| 入力形式 | 例 | 取得方法 |
|----------|-----|---------|
| Issue URL | `https://github.com/org/repo/issues/123` | `gh issue view 123 --json body,title,labels,comments` |
| 計画テキスト | 直接テキスト or ファイルパス | Read ツール |
| PR修正依頼 | `https://github.com/org/repo/pull/456` | `gh pr view 456 --json body,title,files,comments` |
| `$ARGUMENTS` なし | （現在のブランチの最新Issue） | `gh issue list --assignee @me -l planned --json number -q '.[0].number'` |

### 凍結チェックリスト

```
- [ ] 実装対象（何を作る/直すか）が1文で記述できる
- [ ] 受入条件が具体的に定義されている（「○○のとき△△になる」形式）
- [ ] 非対象（やらないこと）が明示されている
- [ ] 前提条件（依存するAPI、DB状態、環境）が列挙されている
- [ ] 成功の定義がテスト可能な形で記述されている
```

**ゲート条件**: 全項目にチェック。曖昧な項目が残る場合はユーザーに確認を求めて停止。

**出力: Mission Brief** — 対象(1文)、受入条件(箇条書き)、非対象、前提条件、成功の定義を凍結文書化。

---

## Phase 1: 設計検証 & Slice計画

### 1.1 Tier判定（実装複雑度スコアリング）

| カテゴリ | シグナル | 重み | 判定基準 |
|---------|---------|------|---------|
| **仕様不確実性** | 要件に複数解釈の余地 | 3 | 受入条件の具体性を評価 |
| **仕様不確実性** | 未定義のエッジケースが多い | 2 | 境界値・異常系の言及有無 |
| **影響半径** | 変更予定ファイル6個以上 | 2 | 事前調査 or 類似タスク実績 |
| **影響半径** | 複数モジュール横断（3層以上） | 3 | api/ + ui/ + db/ 等 |
| **不可逆性** | DB migration | 5 | ALTER/CREATE TABLE |
| **不可逆性** | 外部API契約変更 | 4 | 公開エンドポイントの型変更 |
| **データ/セキュリティ** | 認証/認可ロジック変更 | 5 | auth middleware, RLS |
| **データ/セキュリティ** | 課金ロジック変更 | 5 | Stripe, クレジット消費 |
| **外部依存** | 新規外部パッケージ導入 | 2 | package.json 変更 |
| **外部依存** | 外部API呼び出しの追加/変更 | 3 | 非決定的な外部依存 |
| **テスト容易性** | 既存テストカバレッジが低い | 3 | 対象領域のテスト有無 |
| **テスト容易性** | E2Eテスト困難（ブラウザ外操作等） | 2 | 自動テスト可能性 |

### Tier閾値

| Tier | スコア | Slice粒度 | レビュー強度 | テスト要件 |
|------|--------|----------|------------|----------|
| **I0: 標準** | 0-7 | 2-3 Slice | 1系統 | lint + type + unit |
| **I1: 重要** | 8-14 | 3-5 Slice | 2系統（Claude+Codex） | + integration |
| **I2: 要塞** | 15-21 | 5-8 Slice | 2系統 + fortress-review | + E2E |
| **I3: 絶対防御** | 22+ | 8+ Slice or 分割 | 3系統 + fortress-review + N-ver | + E2E + rollback rehearsal |

**スコア0**: fortress-implementは過剰。通常の実装フローを推奨して終了。

### 1.2 Slice分解

Sliceは「独立に検証・ロールバック可能な最小実装単位」。

**Slice分解の原則:**
1. 1 Sliceは1つの関心事のみ扱う
2. migration、設定変更、権限変更は専用Sliceに隔離
3. 各Sliceに明確な受入テストを定義
4. Slice間の依存順序を明示

**出力形式（ユーザーに提示して承認を得る）:**

```
【Slice計画】
Tier: {I0/I1/I2/I3}（スコア: {N}点）
推定所要時間: Slice数 x Tier別平均

| # | Slice名 | 目的 | 受入テスト | 依存 | 推定規模 |
|---|---------|------|----------|------|---------|
| 1 | DB schema追加 | 新テーブル作成 | migration適用確認 | なし | S |
| 2 | API実装 | CRUDエンドポイント | 単体テスト全PASS | Slice 1 | M |
```

### 1.3 fortress-review連携（Tier I2+のみ）

Tier I2以上: Slice計画を `fortress-review --auto-gate` に投入。
- CRITICAL=0 → Phase 2に進行
- CRITICAL>=1 → Slice計画の修正が必要。ユーザー判断を仰ぐ

---

## Phase 2: Slice実装ループ（コアフェーズ）

### 2.1 ループ構造

各Sliceに対し5ステップを順次実行:

| Step | 内容 | Gate条件 |
|------|------|---------|
| **A: テスト先行** | bug→再現テスト(RED確認)、feat→受入テスト(期待FAIL確認) | テストが定義され、期待通りFAILする |
| **B: 最小差分実装** | テストがGREENになる最小限のコード | テストがGREEN |
| **C: クロスチェック** | 実装者以外のTier別並列レビュー | CRITICAL/HIGH指摘が0 |
| **D: 全検証** | lint→type→test + 想定外差分チェック | 全PASS + 想定外差分0 |
| **E: Safe Point** | git commit + 5点セット記録 | 記録完了 |

**詳細手順**: `references/slice-execution-loop.md` を Phase 2 開始時にRead

### 2.2 エージェント構成（Tier別）

| エージェント | 記号 | I0 | I1 | I2 | I3 |
|-------------|------|-----|-----|-----|-----|
| Implementer (Claude) | IM | o | o | o | o |
| Reviewer-1 ロジック (Claude) | R1 | o | o | o | o |
| Reviewer-2 影響範囲 (Codex) | R2 | - | o | o | o |
| Tester テスト強化 (Codex) | TS | - | o | o | o |
| Reviewer-3 障害シナリオ (Claude) | R3 | - | - | o | o |
| N-ver Implementer (Codex) | NV | - | - | - | o |
| **Slice単位の合計** | | **2** | **4** | **5** | **7** |

**エージェントプロンプト**: `references/agent-prompts.md` をエージェント起動時にRead

### 2.3 Safe Point（5点セット）

| # | 項目 | 内容 | 用途 |
|---|------|------|------|
| 1 | スナップショット | git commit hash | ロールバック基点 |
| 2 | 合格テスト一覧 | PASS/FAILテスト名 | 回帰検知 |
| 3 | 変更ファイル一覧 | git diff --stat | 影響範囲確認 |
| 4 | ロールバック手順 | `git reset --soft {hash}` | 即時復元 |
| 5 | 前提メモ | このSliceが依存する前提 | 前提崩壊検知 |

状態ファイル: `tasks/fortress-implement-state.json`

### 2.4 Self-Healing Loop（失敗回復）

Gate FAILが発生した場合、以下の判定ロジックで回復戦略を決定する:

```javascript
function decideRecoveryAction(failure, history) {
  // failure = { slice_id, attempt, error_type, error_pattern, severity }
  // history = 同一Sliceの過去failure配列
  // 返り値: "RETRY_SAME" | "RETRY_DIFFERENT" | "ROLLBACK" | "ESCALATE"

  // Layer 1: 即時判定（severity + attempt上限）
  if (failure.severity === "CRITICAL")               return "ROLLBACK";
  if (failure.attempt >= 3)                           return "ESCALATE";

  // Layer 2: パターン再発検知（同じ根本原因の繰り返しを断つ）
  const samePattern = history.filter(h => h.error_pattern === failure.error_pattern);
  if (samePattern.length >= 1)                        return "RETRY_DIFFERENT";

  // Layer 3: error_type別の最適戦略（機械的修正 vs 設計判断）
  switch (failure.error_type) {
    case "LINT":                                      return "RETRY_SAME";
    case "TYPE":                                      return "RETRY_SAME";
    case "TEST":
      return failure.attempt <= 1 ?                   "RETRY_SAME" : "RETRY_DIFFERENT";
    case "REVIEW":
      return failure.severity === "HIGH" ?            "ROLLBACK" : "RETRY_DIFFERENT";
    case "UNEXPECTED":                                return "ROLLBACK";
    default:                                          return "ESCALATE";
  }
}
```

**判定の設計根拠:**

| Layer | 判定基準 | 設計思想 |
|-------|---------|---------|
| **Layer 1** | severity=CRITICAL → 即ROLLBACK / attempt>=3 → ESCALATE | **安全弁**: 危険な状態と無限ループを最優先で断つ |
| **Layer 2** | 同一error_pattern再発 → RETRY_DIFFERENT | **学習**: 同じ修正を繰り返しても同じ結果。別アプローチを強制 |
| **Layer 3** | error_type別の分岐 | **効率**: LINT/TYPEは機械的修正可能、REVIEWは設計判断が必要、UNEXPECTEDは未知領域なので安全側に倒す |

**制約（ガードレール）:**
- 最大リトライ: Slice単位で3回まで
- 同一エラーパターン2回: RETRY_DIFFERENT を強制
- CRITICAL severity: 即時 ROLLBACK（リトライなし）
- 3回失敗: ROLLBACK + ESCALATE（ユーザーに報告）

---

## Phase 3: 統合検証（Integration Fortress）

全Slice完了後、以下を順次実行:

1. `lint` — 全PASS確認
2. `type-check` — 全PASS確認
3. `test` — 全テストPASS確認（Slice単位テスト含む）
4. `build` — ビルド成功確認
5. 回帰テスト — 変更前に通っていたテストが引き続きPASS

**Tier I2+**: e2e-testスキルでE2E検証を追加実施。コアオペレーションの直接テスト必須。

**Tier I3**: N-version検証 — 重要ロジック部分をCodexに独立実装させ、2つの実装diffを比較。不一致箇所はレビューエージェントが裁定。

---

## Phase 4: 証跡パック & 最終判定

### Go/No-Go基準

| 判定 | 条件 | 次のアクション |
|------|------|---------------|
| **Go** | 全Slice PASS + 統合テスト全PASS + E2E PASS(I2+) | 完了。PRマージ可 |
| **条件付きGo** | MEDIUM以下の未解決指摘あり | 指摘を技術負債Issueに記録して進行 |
| **No-Go** | CRITICAL/HIGH未解決 or テスト未PASS | 再設計が必要 |

### 証跡パック出力

```
## fortress-implement 証跡パック

### 基本情報
- 対象: {Mission Briefの1行要約}
- Tier: {I0/I1/I2/I3}（スコア: {N}点）
- Slice数: {N} / 完了: {N} / 失敗: {N}

### 判定: {Go / 条件付きGo / No-Go}

### Slice実行結果
| # | Slice名 | 試行回数 | 結果 | Safe Point |
|---|---------|---------|------|-----------|

### テスト結果サマリ
- lint: PASS / type-check: PASS / unit: N/N / integration: N/N / E2E: PASS|SKIP

### 残存リスク・Self-Healing統計
```

---

## オプション引数

| 引数 | 説明 | 例 |
|------|------|-----|
| `--tier I2` | Tier を手動指定 | `/fortress-implement #123 --tier I2` |
| `--no-codex` | Codex依存エージェント(R2/TS/NV)をClaude SubAgent（探索許可）で代替 | `/fortress-implement #123 --no-codex` |
| `--dry-run` | Tier判定 + Slice計画のみ | `/fortress-implement #123 --dry-run` |
| `--skip-e2e` | E2E検証をスキップ | `/fortress-implement #123 --skip-e2e` |
| `--max-slices N` | Slice数上限 | `/fortress-implement #123 --max-slices 5` |
| `--resume` | 状態ファイルから再開 | `/fortress-implement resume` |

---

## オンデマンドRead指示

| Phase | Read対象 | タイミング |
|-------|---------|-----------|
| Phase 1 (I2+) | fortress-review SKILL.md | fortress-review連携時 |
| Phase 2 開始 | references/slice-execution-loop.md | Slice実行ループ開始時（必須） |
| Phase 2 | references/agent-prompts.md | エージェント起動時 |
| エラー時 | references/guardrails-antipatterns.md | ガードレール詳細確認 |

---

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| Codexタイムアウト | R2/TS/NVをClaude SubAgent（探索許可、Read/Grep/Glob使用可）で代替 |
| Slice粒度が大きすぎる | Sliceをさらに分割。1 Slice = 1ファイル変更を目安に |
| Self-Healing 3回失敗 | 自動ロールバック後、ユーザーに報告。Slice計画の見直しを提案 |
| 統合テスト失敗（全Slice完了後） | 最後のSliceからロールバック。統合テストを各Slice後に追加 |
| テスト先行困難（UI等） | 受入条件を自然言語で記述、Phase 3のE2Eで検証 |
| 状態ファイル破損 | git logからSafe Point（commit hash）を復元。`--resume` で再開 |
| Windows 8191文字制限 | Codexは `--cd` 方式。Claude SubAgentは差分埋め込み（500行超はファイル分割） |

---

## 既存スキルとの連携

```
issue-planner（計画作成）
     |
     v
fortress-implement（確実な実装実行）  <-- THIS
     |-- fortress-review（Phase 1 設計検証、Tier I2+）
     |-- codex（クロスチェック + テスト生成）
     +-- e2e-test（Phase 3 E2E検証）
     |
     v
sub-review（最終diffレビュー）
```

| 連携先 | タイミング | 連携方法 |
|--------|----------|---------|
| `fortress-review` | Phase 1（I2+） | Slice計画を `--auto-gate` で投入。カテゴリ変換: FR側ARCHITECTURE→FI側LOGIC、OPERATIONAL→REQUIREMENT |
| `issue-autopilot-batch` | バッチの1件ワーカー | `fortress-review-required` ラベルで自動起動 |
| `codex` | Phase 2 Step C | Codex exec read-only でクロスチェック |
| `e2e-test` | Phase 3（I2+） | E2Eシナリオ設計・実行 |
| `design-review-checklist` | Phase 1 | Slice計画のPhase 1-9チェック |

---

## 関連スキル

| スキル | 関連 |
|--------|------|
| `fortress-review` | 設計段階の多角レビュー。Phase 1で前段として使用 |
| `issue-autopilot-batch` | バッチ実装パイプライン。1件ワーカーとしてfortress-implementを呼ぶ |
| `issue-planner` | 上流: 実装計画の自動生成 |
| `codex` | クロスチェック + テスト生成のセカンドオピニオン |
| `e2e-test` | Phase 3のE2Eテスト実行 |
| `sub-review` | fortress-implement後の最終diffレビュー |
| `security-adversarial` | 認証・課金Sliceでの追加セキュリティレーン |
| `skill-improve` | fortress-implement自体の品質管理 |

---

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-11 | 初版作成 | Codex(gpt-5.4) x Grok(4.20) x Qwen(3.6-plus) x Claude(Opus 4.6) 四者分析から「Slice & Prove方式」を導出 |
| 2026-04-11 | 整合性修正（3件） | `--no-codex`フォールバック仕様明確化(R2/TS/NV→Claude SubAgent)、Codexタイムアウト時の代替エージェント明記、fortress-reviewカテゴリ変換ルール追加 |
| 2026-04-13 | Learning Style Override追加 | スキル実行中はLearn by Doing（Your Task/TODO(human)）を無効化。Slice実装ループの中断防止 |
