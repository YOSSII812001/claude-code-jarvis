---
name: codebase-patrol
description: |
  コードベースの定期パトロール。セキュリティ脆弱性、エラーハンドリング欠陥、
  文字化け、冗長コード、デッドコード、パフォーマンス問題、型安全性ギャップを
  サブエージェント並列スキャン + Codex深層意味解析で検出。
  トリガー: "codebase-patrol", "コードパトロール", "コード品質チェック",
  "patrol", "パトロール", "code quality scan", "コード巡回"
  使用場面: (1) 定期的なコード品質監視、(2) リリース前の品質確認、
  (3) 技術的負債の可視化、(4) セキュリティリスクの早期発見
---

# Codebase Patrol

コードベースを定期的にパトロールし、セキュリティ脆弱性・エラーハンドリング欠陥・
文字化け・冗長コード等を検出するスキル。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                     Codebase Patrol                             │
│                                                                 │
│  Step 1        Step 2            Step 3       Step 4     Step 5 │
│ ┌───────┐   ┌──────────────┐  ┌────────┐  ┌───────┐  ┌──────┐ │
│ │Pre-   │   │ サブエージェント│  │Merge & │  │Issue  │  │Report│ │
│ │flight │──▶│ 並列スキャン  │─▶│Dedup   │─▶│Auto-  │─▶│&     │ │
│ │Check  │   │              │  │        │  │Create │  │Track │ │
│ └───────┘   └──────────────┘  └────────┘  └───────┘  └──────┘ │
│              W1: Static(Grep)  - 重複排除   - P0/P1    - 統計  │
│              W2: Quality(Read) - 信頼度付与  - 上限5件  - 履歴  │
│              W3: Semantic      - 抑制適用    - ラベル   - 比較  │
│                  (Codex)                                       │
└─────────────────────────────────────────────────────────────────┘
```

## パトロールカテゴリ

| 優先度 | カテゴリ | ルール数 | ワーカー |
|--------|---------|---------|---------|
| **P0** | Security（秘密情報、認証漏れ、RLS、SQLi） | 6 | W1 + W3 |
| **P1** | Error Handling（Supabase error未チェック、silent failure） | 6 | W1 + W2 |
| **P1** | Encoding（BOM、文字化け、混在エンコーディング） | 4 | W1 |
| **P1** | Dependencies（npm audit、Stripe署名、TIMESTAMPTZ） | 3 | W2 |
| **P2** | Redundant/Dead Code（二重クエリ、未使用export） | 4 | W3 |
| **P2** | Architecture（api/backend二系統重複） | 1 | W3 |
| **P3** | Performance（N+1、.single()欠落） | 2 | W3 + W1 |
| **P3** | Type Safety（as any、暗黙any、.ts.bak残存） | 3 | W1 |

詳細なルール定義: [references/patrol-rules.md](references/patrol-rules.md)

## 実行モード

| モード | コマンド | ワーカー | カテゴリ | 所要時間 |
|--------|---------|---------|---------|---------|
| **quick**（デフォルト） | `/codebase-patrol` | W1+W2 | P0+P1 | ~5-8分 |
| **full** | `/codebase-patrol full` | W1+W2+W3 | P0-P3全て | ~15-20分 |
| **focused** | `/codebase-patrol focused security` | 1-2 | 指定カテゴリ | ~5-10分 |
| **diff** | `/codebase-patrol diff` | W1+W2 | 全て（変更ファイルのみ） | ~3-5分 |

**ドライランモード**: 全モードに `--dry-run` を付与可能。Issue作成をスキップしレポートのみ出力。
初回導入時は **必ずドライラン** でノイズレベルを確認すること。

```
/codebase-patrol quick --dry-run
```

**focused カテゴリ一覧**: `security`, `error-handling`, `encoding`, `duplicates`, `dead-code`, `performance`, `type-safety`

## 実行フロー

### Step 1: Pre-flight Check

```
1. 引数を解析しモード判定（full/quick/focused/diff + --dry-run）
2. プロジェクトディレクトリを特定（CLAUDE.md / git root）
3. tasks/patrol-history.json から前回パトロールコミット取得
4. diff モード: git diff --name-only <last-commit>..HEAD
   → 変更なし: "No changes since last patrol" で終了
5. スコープ計算:
   - full/quick: api/_lib/ + backend/src/ + frontend/src/ + packages/
   - diff: 変更ファイルのみ
   - focused: カテゴリ関連ディレクトリのみ
6. ユーザーに報告: "Patrolling N files across M directories (mode: quick)"
```

### Step 2: サブエージェント並列スキャン

**3ワーカーをAgent tool（サブエージェント）で並列起動する。Agent Teamsは使わない。**

全ワーカーはread-only。結果はサブエージェントの戻り値テキストとして親に返却する。

#### ワーカー起動パターン

```
Agent tool を 2-3 並列で起動（1メッセージに複数tool call）:

W1 (Claude subagent): Static Pattern Scanner
  - subagent_type: general-purpose
  - Grep/Glob/Read ツールでパターンマッチ
  - 担当: SEC-01/02/04/06, ERR-01, ENC-01/02, TYPE-01/03, PERF-02, LINT-01, MIGR-01
  - タイムアウト: 自動（サブエージェントのデフォルト）

W2 (Claude subagent): Quality Pattern Scanner
  - subagent_type: general-purpose
  - Read + コードパターン分析 + npm audit
  - 担当: ERR-04/05/06, DUP-03, DEAD-03, ENC-03, API-01, DEP-01
  - タイムアウト: 自動

W3 (Claude subagent → Codex exec): Semantic Analyzer  ※ full モードのみ
  - subagent_type: general-purpose
  - 内部で codex exec --full-auto --sandbox read-only を実行
  - stdin プロンプト配信 + tee /tmp/codex_patrol_output_$$.txt
  - 担当: ERR-02/03, DUP-01/02, DEAD-01/02, PERF-01/03, SEC-03/05, API-01
  - Bash timeout: 600000ms（10分）
```

ワーカープロンプトテンプレート: [references/worker-prompts.md](references/worker-prompts.md)

**スコープの二系統注意**:
- `api/_lib/routes/`（41ルート）: 認証 = `ensureUserOrg`
- `backend/src/routes/`（7ルート）: 認証 = `auth.js` ミドルウェア

### Step 3: Findings Merge & Dedup

```
1. 各ワーカーの結果テキストを構造化パース
2. 重複排除: 同一 file + line + rule → マージ（最高 severity 採用）
3. 誤検知抑制:
   a. PATROL-IGNORE インラインコメント確認
   b. false-positive-suppression.md の許可パターン適用
   c. テストファイル → ERR-01 を LOW に降格
   d. .ts.bak → TYPE-01 を除外
4. 信頼度付与:
   - HIGH: grep 確認済みパターンマッチ
   - MEDIUM: Codex 検出 + コード証拠あり
   - LOW: 推論のみ（Codex 推定）
5. ソート: P0 > P1 > P2 > P3、同優先度内は HIGH > MEDIUM > LOW
```

誤検知抑制ルール: [references/false-positive-suppression.md](references/false-positive-suppression.md)

### Step 4: GitHub Issue 自動作成

**条件**: P0/P1 かつ HIGH/MEDIUM 信頼度 かつ `--dry-run` でないこと

```bash
# 重複チェック
gh issue list --repo <owner/repo> --label patrol-finding --search "<rule-id> <filepath>" --json number

# Issue 作成（最大5件/回）
gh issue create \
  --repo <owner/repo> \
  --title "[Patrol] <RULE-ID>: <短い説明>" \
  --label "patrol-finding" \
  --label "<security|tech-debt>" \
  --body "$(cat <<'EOF'
## Patrol Finding

**Rule**: <RULE-ID> - <ルール名>
**Severity**: <P0/P1> | **Confidence**: <HIGH/MEDIUM>
**File**: `<filepath>:<line>`

### Description
<問題の詳細説明>

### Current Code
\`\`\`javascript
<問題のあるコード>
\`\`\`

### Suggested Fix
\`\`\`javascript
<修正案>
\`\`\`

### Context
- Detection: Codebase Patrol (<mode> mode)
- Method: <grep/codex/npm-audit>

---
*Auto-generated by Codebase Patrol*
EOF
)"
```

**ガードレール**:
- [ ] 1回のパトロールで最大5件まで
- [ ] 既存の同一Issue（同rule-id + 同filepath）がopenならスキップ
- [ ] P0 → `security` ラベル、P1 → `tech-debt` ラベル
- [ ] 全自動Issue → `patrol-finding` ラベル

### Step 5: Report & Track

#### レポート出力

```markdown
## Codebase Patrol Report

| 項目 | 値 |
|------|-----|
| Mode | quick / full / focused / diff |
| Files scanned | N |
| Duration | M min |
| Findings | X total (P0: a, P1: b, P2: c, P3: d) |
| Issues created | Y |

### P0 Findings (Security)
| # | Rule | File | Description | Confidence |
|---|------|------|-------------|------------|

### P1 Findings (Error Handling / Encoding)
| # | Rule | File | Description | Confidence |
|---|------|------|-------------|------------|

### P2/P3 Findings (Manual Review)
| # | Rule | File | Description | Confidence |
|---|------|------|-------------|------------|
```

#### 履歴記録

`tasks/patrol-history.json` に追記:
```json
{
  "patrols": [{
    "date": "2026-04-01T09:23:00Z",
    "mode": "quick",
    "commit": "abc1234",
    "files_scanned": 48,
    "findings": { "P0": 0, "P1": 3, "P2": 1, "P3": 2 },
    "issues_created": ["#1680", "#1681"],
    "dismissed": []
  }]
}
```

## 定期スケジューリング

### 方式1: 手動起動（推奨・初期段階）
```
/codebase-patrol              → quick モード
/codebase-patrol full          → full モード
/codebase-patrol diff          → diff モード（PR前チェック）
```

### 方式2: CronCreate（セッション内定期実行）
```
/codebase-patrol schedule daily   → CronCreate "23 9 * * 1-5" durable:true
/codebase-patrol schedule weekly  → CronCreate "23 9 * * 1" durable:true
/codebase-patrol schedule off     → CronDelete
/codebase-patrol schedule status  → CronList
```

> **注意**: CronCreate は 7日で自動失効。Step 5 で次回 CronCreate を自動再発行する
> 自己再スケジュールパターンを使用するが、セッション跨ぎは保証されない。

### 方式3: GitHub Actions CI（将来拡張）
- `.github/workflows/codebase-patrol.yml` で週次 cron 実行
- 初期リリースでは方式1+2のみ

## 誤検知抑制

### インラインコメント
```javascript
// PATROL-IGNORE: ERR-01 エラーは呼び出し元で処理
const { data } = await supabaseAdmin.from('table').select('*');
```

### 許可パターン（false-positive-suppression.md）
- `.env.example` → SEC-01 除外
- `.ts.bak` → TYPE-01 除外
- テストファイル → ERR-01 を LOW 信頼度に降格
- `.limit(1)` パターン → PERF-02 除外
- `console.info`/`console.warn`（api/_lib/ 設計上の使用）→ 除外

### 履歴抑制
- 以前却下された同一指摘は再報告しない（patrol-history.json の dismissed 配列）

## トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| W3(Codex) タイムアウト | 大規模リポジトリで 6分超過 | focused モードでスコープを絞る |
| 誤検知が多すぎる | 許可パターン未調整 | `--dry-run` で確認後 suppression.md を調整 |
| Issue 重複作成 | `patrol-finding` ラベルの検索ミス | `gh issue list --label patrol-finding` で手動確認 |
| npm audit 失敗 | node_modules 未インストール | `npm ci` を先に実行 |
| ENC-01 BOM検出エラー | Windows PowerShell 互換問題 | Git Bash ではなく PowerShell で実行 |
| 定期実行が止まった | CronCreate 7日失効 | `/codebase-patrol schedule daily` で再登録 |

## 関連スキル

| スキル | 連携ポイント |
|--------|-------------|
| `codex` | W3 の Codex exec パターン（stdin配信、tee永続化） |
| `security-adversarial` | SEC-* ルールの深掘りを Red Team に委任 |
| `issue-flow` | 自動作成 Issue の実装フロー |
| `issue-planner` | 複数 findings の一括実装計画 |
| `issue-autopilot-batch` | パトロール Issue の自動実装パイプライン |
| `sub-review` | PR レビューパイプラインからの起動 |
| `design-review-checklist` | ERR-* ルールとのオーバーラップ |

## 改訂履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-04-01 | v1.0.0 | 初版作成。26ルール、4モード、3ワーカー構成 |
