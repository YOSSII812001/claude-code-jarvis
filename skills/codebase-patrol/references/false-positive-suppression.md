# False Positive Suppression（誤検知抑制）

パトロールの信号対ノイズ比を維持するための抑制ルール定義。

---

## 1. インラインコメント抑制（PATROL-IGNORE）

ソースコード内に以下のコメントを記述することで、特定のルールを行単位で抑制する。

### 構文

```javascript
// PATROL-IGNORE: <RULE-ID> <理由>
const { data } = await supabaseAdmin.from('table').select('*');
```

### ルール
- `PATROL-IGNORE` は対象行の**直前行**または**同一行の末尾**に記述
- 理由（`<理由>`）は必須。理由なしの `PATROL-IGNORE` は無効
- 複数ルール抑制: `// PATROL-IGNORE: ERR-01,SEC-04 理由`
- ワーカーは Grep/Read 時に `PATROL-IGNORE` を含む行を検出したらスキップ

### 使用例

```javascript
// PATROL-IGNORE: ERR-01 エラーは呼び出し元の fetchWithRetry() で一括処理
const { data: items } = await supabaseAdmin.from('items').select('*');

const result = data as any; // PATROL-IGNORE: TYPE-01 外部API型定義が未提供
```

---

## 2. ファイルパターン除外

以下のファイルパターンは特定のルールから自動的に除外される。

### 除外マッピング

| ファイルパターン | 除外ルール | 理由 |
|-----------------|-----------|------|
| `*.test.*`, `*.spec.*` | ERR-01 → LOW信頼度に降格 | テストでは意図的にerrorチェックを省略することがある |
| `*.test.*`, `*.spec.*` | SEC-01 除外 | テストフィクスチャのダミー値 |
| `.env.example` | SEC-01 除外 | プレースホルダー値（実際の秘密情報ではない） |
| `*.ts.bak` | TYPE-01, TYPE-03 除外 | 移行残骸（ビルド対象外） |
| `*.d.ts` | TYPE-03 除外 | 型定義ファイル（パラメータ型注釈不要） |
| `node_modules/` | 全ルール除外 | 外部依存 |
| `.git/` | 全ルール除外 | バージョン管理 |
| `dist/`, `build/`, `.next/` | 全ルール除外 | ビルド成果物 |

### パターンマッチ除外

| 検出パターン | 除外条件 | 適用ルール |
|-------------|---------|-----------|
| `.limit(1)` が後続 | 除外 | PERF-02 |
| `supabaseAdmin` を使用 | 除外 | SEC-04 |
| `import type` 構文 | 除外 | DUP-03 |
| `console.info` (api/_lib/) | 除外 | ERR-05（設計上の使用） |
| `console.warn` (api/_lib/) | 除外 | ERR-05（設計上の使用） |
| `.env.example`, `.env.sample` | 除外 | SEC-01 |

---

## 3. 信頼度による自動フィルタリング

| 信頼度 | Issue自動作成 | レポート表示 | 説明 |
|--------|-------------|-------------|------|
| **HIGH** | P0/P1 のみ | 全優先度 | Grep確認済みのパターンマッチ |
| **MEDIUM** | P0/P1 のみ | 全優先度 | Codex検出 + コード証拠あり |
| **LOW** | なし | P2/P3セクションのみ | 推論のみ（Codex推定、確証なし） |

### 信頼度の決定基準

```
HIGH:
  - Grep パターンマッチで直接検出（ERR-01, SEC-01, TYPE-01, MIGR-01, SEC-06, LINT-01）
  - Bash コマンドの出力で確認（ENC-01, DEP-01）

MEDIUM:
  - Codex が具体的なファイル名と行番号を提示（ERR-02, DUP-01, SEC-03, SEC-05）
  - W2 の Read + パターンマッチで検出（ERR-04, ERR-06）

LOW:
  - Codex の推論のみ（DUP-02, DEAD-01, DEAD-02, ERR-03, PERF-01）
  - パターンマッチだが誤検知率が高い（TYPE-03, PERF-02）
```

---

## 4. 履歴抑制（Dismissed Findings）

`tasks/patrol-history.json` の `dismissed` 配列に記録された Finding は、
コードが変更されない限り再報告しない。

### Dismiss の仕組み

```json
{
  "dismissed": [
    {
      "rule": "ERR-01",
      "file": "api/_lib/utils/legacyHelper.js",
      "line": 42,
      "reason": "意図的な設計。呼び出し元で一括エラー処理。",
      "dismissed_at": "2026-04-01",
      "dismissed_by": "user"
    }
  ]
}
```

### 再活性化条件

Dismissed Finding は以下の場合に再報告される:
- 対象ファイルが `git diff` で変更されている
- 対象行番号が変更によりシフトしている
- 対象ファイルが削除されている（Finding自体を dismissed から除去）

---

## 5. 誤検知が多い場合の調整手順

1. `--dry-run` でパトロールを実行
2. レポートの Finding を確認し、誤検知をリストアップ
3. 誤検知の種類に応じて対処:
   - **パターン自体が不適切** → `patrol-rules.md` の Grep パターンを修正
   - **特定ファイルだけ除外したい** → このファイルの「ファイルパターン除外」に追加
   - **特定行だけ除外したい** → ソースコードに `PATROL-IGNORE` コメントを追加
   - **ルール自体が不要** → SKILL.md のワーカー担当ルールから除去
4. 再度 `--dry-run` で確認し、ノイズが許容範囲になるまで繰り返す
