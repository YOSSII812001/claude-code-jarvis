# fortress-implement — Slice実行ループ詳細手順

> Phase 2 開始時に必ずReadすること。

## Step A: テスト先行

### bugfixの場合

1. バグの再現条件を特定（Issue本文 or 報告内容から）
2. 再現テストを作成
3. テスト実行 → **RED（失敗）を確認**
4. 「このテストがGREENになれば修正完了」をユーザーと合意

### featureの場合

1. Sliceの受入条件をテストに変換
2. 受入テストを作成
3. テスト実行 → **期待FAIL（未実装）を確認**
4. テストが実装完了後にGREENになることを受入基準とする

### テスト先行が困難な場合

| 状況 | 代替手段 |
|------|---------|
| UI操作系 | 受入条件を自然言語で記述。Phase 3のE2Eで検証 |
| 外部API依存 | モック付き統合テスト or コードパス整合性検証 |
| 環境依存（CI/CD等） | 設定ファイルの差分検証 + ドライラン |

> 「テストが書けない」はSlice分解の失敗を示唆する。Slice再分解を検討すること。

---

## Step B: 最小差分実装

### 実行ルール

1. Step Aのテストが **GREEN** になる最小限のコードを書く
2. 以下を **しない**:
   - 関係ないリファクタリング
   - 「ついでに」の改善
   - 別Sliceの先取り実装
   - コメント・ドキュメントの大規模更新
3. 実装完了後:
   ```bash
   git diff --stat  # 変更ファイルがSlice計画と一致するか確認
   npm run lint && npm run type-check && npm test  # 基本検証
   ```

### 想定外差分の扱い

Slice計画の予定ファイル以外に変更がある場合:
- **自動生成ファイル**（型定義、ロックファイル等）: 許容。記録に残す
- **意図的な追加変更**: Slice計画を更新し、理由を記録
- **意図しない変更**: 即時revert。原因を調査

---

## Step C: クロスチェック

### Tier別起動パターン

**Tier I0（最小構成: 2エージェント）:**
1. R1（ロジック+要件）のみ起動
2. R1の結果を確認 → CRITICAL/HIGH=0ならStep Dへ

**Tier I1（標準構成: 4エージェント）:**
1. R1 + R2(Codex) + TS(Codex) を**1メッセージで並列起動**
2. 全結果を収集
3. CRITICAL/HIGH指摘があれば修正後に再レビュー（対象エージェントのみ再起動）

**Tier I2（強化構成: 5エージェント）:**
1. R1 + R2 + R3 + TS を**1メッセージで並列起動**
2. 全結果を収集
3. CRITICAL/HIGH指摘は全解決必須

**Tier I3（最大構成: 7エージェント）:**
1. IM(Claude) + NV(Codex) が独立に実装（Step Bで並列実行）
2. 2実装のdiffを比較
3. R1 + R2 + R3 + TS を並列起動
4. diff不一致箇所 + CRITICAL/HIGH指摘を全解決

### クロスチェック結果の統合手順

1. 全エージェントの出力から指摘を抽出
2. 同一指摘の統合（複数エージェントが検出 → **クロスバリデーション済み**マーク）
3. 深刻度でソート（CRITICAL → HIGH → MEDIUM → LOW）
4. 統合結果をユーザーに提示:

```
## Slice {N} クロスチェック結果

| # | ID | カテゴリ | ファイル | 深刻度 | クロス検証 | 問題概要 |
|---|-----|---------|---------|--------|-----------|---------|

CRITICAL: {N}件 / HIGH: {N}件 / MEDIUM: {N}件
→ {CRITICAL+HIGH=0: Step Dへ | CRITICAL+HIGH>0: 修正後再レビュー}
```

---

## Step D: 全検証

以下を順次実行:

```bash
# 1. Lint
npm run lint
# 結果: 0 error 必須

# 2. 型チェック
npm run type-check  # or: cd frontend && npm run type-check
# 結果: 0 error 必須

# 3. テスト（Step Aで追加したテスト含む）
npm test
# 結果: 全PASS必須。flakyは2回実行で判定

# 4. 想定外差分チェック
git diff --name-only  # Slice計画の予定ファイル以外がないか
```

**全検証PASS条件:**
- lint: 0 error
- type-check: 0 error
- test: 全PASS（flakyは分類して隔離）
- 想定外差分: 0（または明示的に承認済み）

**いずれか1つでもFAIL → Self-Healing Loop へ**

---

## Step E: Safe Point作成

```bash
# 1. 変更をステージ
git add -A

# 2. Safe Point commit
git commit -m "fortress-implement: Slice {N} - {Slice名} [SP-{N}]"

# 3. commit hashを記録
SP_HASH=$(git rev-parse HEAD)
```

### 状態ファイル更新（tasks/fortress-implement-state.json）

Sliceエントリを更新:
```json
{
  "id": "S{N}",
  "name": "{Slice名}",
  "status": "COMPLETED",
  "safe_point": {
    "commit_hash": "{SP_HASH}",
    "tests_passed": ["{テスト名1}", "{テスト名2}"],
    "files_changed": ["{ファイル1}", "{ファイル2}"],
    "rollback_cmd": "git reset --soft {前SPのhash}",
    "premises": "{このSliceが依存する前提条件}"
  },
  "attempts": {N},
  "review_summary": {
    "critical": 0,
    "high": 0,
    "medium": {N},
    "cross_validated": ["{FI-R1-S{N}-01 と FI-R2-S{N}-01 が同一指摘}"]
  }
}
```

---

## Self-Healing Loop 詳細フロー

```
Gate FAIL検知
  |
  v
エラー分類（LINT / TYPE / TEST / REVIEW / UNEXPECTED）
  |
  v
decideRecoveryAction() で判定  <-- SKILL.md の TODO(human) で定義
  |
  +-- RETRY_SAME ------> 同じアプローチで修正 -> Step D再実行
  |
  +-- RETRY_DIFFERENT --> Implementerに別アプローチを指示 -> Step B再実行
  |
  +-- ROLLBACK ---------> git reset --soft {前SP hash} -> Slice再設計
  |
  +-- ESCALATE ---------> ユーザーに問題を報告して停止
```

### リトライ記録

```json
{
  "slice_id": "S{N}",
  "attempt": 2,
  "previous_error": {
    "type": "TEST",
    "pattern": "Property 'foo' does not exist on type 'Bar'",
    "severity": "HIGH"
  },
  "recovery_action": "RETRY_SAME",
  "fix_description": "型定義にfooプロパティを追加"
}
```

---

## 状態ファイルスキーマ全体

`tasks/fortress-implement-state.json`:

```json
{
  "mission_brief": "{1行要約}",
  "tier": "I1",
  "tier_score": 10,
  "total_slices": 4,
  "current_slice": 2,
  "phase": "PHASE_2",
  "next_action": "STEP_B for S2",
  "slices": [
    {
      "id": "S1",
      "name": "DB schema追加",
      "status": "COMPLETED",
      "safe_point": { "commit_hash": "abc1234", "..." : "..." },
      "attempts": 1,
      "review_summary": { "critical": 0, "high": 0, "medium": 1 }
    },
    {
      "id": "S2",
      "name": "API実装",
      "status": "IN_PROGRESS",
      "safe_point": null,
      "attempts": 1,
      "review_summary": null
    }
  ],
  "self_healing_log": [],
  "started_at": "2026-04-11T10:00:00Z",
  "fortress_review_result": null
}
```

### resume再開手順

1. `tasks/fortress-implement-state.json` を読み込み
2. `next_action` フィールドで再開ポイントを特定
3. `current_slice` のステータスに基づき、該当Stepから再開
4. Safe Pointの `commit_hash` で git 状態を検証
