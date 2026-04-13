# Patrol Rules カタログ

全検出ルールの詳細定義。各ルールにRule ID、優先度、検出パターン、Grepクエリ/Codexプロンプトを記載。

---

## P0: Security

### SEC-01: ハードコードされた秘密情報
- **検出方法**: Grep
- **パターン**: ソースコード内のAPIキー、パスワード、トークンリテラル
- **Grepクエリ**:
  ```
  pattern: (sk-[a-zA-Z0-9]{20,}|password\s*=\s*['"][^'"]+['"]|SUPABASE_SERVICE_ROLE_KEY|api_key\s*=\s*['"])
  glob: "*.{js,ts,jsx,tsx,mjs}"
  除外: *.test.*, *.spec.*, .env.example
  ```
- **信頼度**: HIGH
- **誤検知対策**: `.env.example`、テストフィクスチャ、コメント内は除外

### SEC-02: SQLインジェクションリスク
- **検出方法**: Grep
- **パターン**: テンプレートリテラルや文字列連結を含む`.rpc()`や生SQLクエリ
- **Grepクエリ**:
  ```
  pattern: \.(rpc|sql)\s*\(\s*`[^`]*\$\{
  glob: "*.{js,ts}"
  ```
- **信頼度**: HIGH

### SEC-03: 認証チェック漏れ
- **検出方法**: Codex（W3）
- **プロンプト要旨**: ルートハンドラ（`api/_lib/routes/`）で`ensureUserOrg`や`x-user-id`ヘッダーチェックがないエンドポイントを検出。`backend/src/routes/`では`auth.js`ミドルウェアの適用を確認。
- **信頼度**: MEDIUM
- **二系統注意**:
  - `api/_lib/routes/` → `ensureUserOrg` パターン
  - `backend/src/routes/` → `auth.js` ミドルウェア適用

### SEC-04: RLSバイパスリスク
- **検出方法**: Grep
- **パターン**: バックエンド（api/, backend/）で anon key の`supabase`クライアントを使用
- **Grepクエリ**:
  ```
  pattern: (?<!supabaseAdmin|Admin)\bsupabase\b(?!Admin)\.from\(
  path: api/, backend/
  除外: frontend/, node_modules/
  ```
- **信頼度**: MEDIUM（意図的な使用の可能性あり）

### SEC-05: org_id 欠落
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `.insert()`や`.upsert()`呼び出しで`org_id`フィールドが含まれていないケースを検出。マルチテナント設計の漏れ。
- **信頼度**: MEDIUM

### SEC-06: .env ファイルの git 追跡
- **検出方法**: Bash
- **コマンド**: `git ls-files .env .env.local .env.production .env.staging`
- **判定**: 出力があればP0
- **信頼度**: HIGH

---

## P1: Error Handling

### ERR-01: Supabase `{data}` without `{error}`
- **検出方法**: Grep（W1）
- **パターン**: Supabaseクエリの破壊的分割で`error`を取得していない
- **Grepクエリ**:
  ```
  pattern: const\s*\{\s*data[^}]*\}\s*=\s*await\s+supabase
  glob: "*.{js,ts}"
  除外: *.test.*, *.spec.*
  ```
- **補足検証**: マッチした行で`error`が同じ破壊的分割に含まれているかチェック。含まれていなければFinding。
- **信頼度**: HIGH
- **背景**: Supabaseは`throw`しない。`{ data: null, error: {...} }`を返す。try/catchだけでは検出不可能。

### ERR-02: try/catch のみに依存（Supabase非throw設計）
- **検出方法**: Codex（W3）
- **プロンプト要旨**: Supabaseクエリをtry/catch内で実行し、`error`フィールドを確認していないコードを検出。
- **信頼度**: HIGH
- **Issue #1678 実例**: `shareholderHelper.js:23` — `catch`だけで失敗検知、`{data, error}`の`error`未チェック

### ERR-03: 未チェック Promise
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `await`呼び出しの戻り値を検証せずにそのまま使用しているケースを検出。
- **信頼度**: LOW

### ERR-04: サイレント失敗
- **検出方法**: Read + パターンマッチ（W2）
- **パターン**: catch ブロック内で `[]`、`null`、`undefined` を返して失敗を隠蔽
- **Grepクエリ**:
  ```
  pattern: catch\s*\([^)]*\)\s*\{[^}]*return\s+(null|\[\]|\{\})
  multiline: true
  glob: "*.{js,ts}"
  ```
- **信頼度**: MEDIUM

### ERR-05: エラー伝播欠如
- **検出方法**: Read + パターンマッチ（W2）
- **パターン**: `console.warn`/`console.error` + フォールバック値の返却のみで、エラーを上位に伝播していない
- **信頼度**: LOW

### ERR-06: Stripe Webhook 署名検証漏れ
- **検出方法**: Grep（W2）
- **パターン**: Webhook受信エンドポイントで`stripe.webhooks.constructEvent`が呼ばれていない
- **Grepクエリ**:
  ```
  Step 1: webhookルートファイルを特定
    pattern: webhook
    path: api/_lib/routes/
    output_mode: files_with_matches

  Step 2: 各ファイルで署名検証の有無を確認
    pattern: constructEvent
    path: <Step1の各ファイル>
    → マッチなし = Finding
  ```
- **信頼度**: HIGH

---

## P1: Encoding (文字化け)

### ENC-01: BOM 検出
- **検出方法**: PowerShell（Windows互換）
- **コマンド**:
  ```powershell
  Get-ChildItem -Recurse -Include "*.js","*.ts","*.jsx","*.tsx" |
    Where-Object { $_.FullName -notmatch 'node_modules|\.git' } |
    ForEach-Object {
      $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
      if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Output "BOM detected: $($_.FullName)"
      }
    }
  ```
- **信頼度**: HIGH

### ENC-02: 混在エンコーディング
- **検出方法**: PowerShell
- **コマンド**: ファイルバイト列をスキャンし、UTF-8として無効なバイトシーケンスを検出
- **信頼度**: MEDIUM

### ENC-03: 文字化け文字列
- **検出方法**: Grep（W2）
- **パターン**: 典型的なShift-JIS→UTF-8文字化けパターン（`\x83`, `\x82`系列）や、表示できない制御文字
- **Grepクエリ**:
  ```
  pattern: [\x80-\x9F]
  glob: "*.{js,ts,jsx,tsx,json}"
  除外: node_modules/
  ```
- **信頼度**: MEDIUM

### ENC-04: エンコーディング不一致
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `Buffer.from()`でencoding指定なし、`fs.readFile`でencoding未指定等
- **信頼度**: LOW

---

## P1: Dependencies & Migration

### DEP-01: 依存パッケージの脆弱性
- **検出方法**: Bash（W2）
- **コマンド**: `npm audit --json 2>/dev/null | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical" or .value.severity == "high") | {name: .key, severity: .value.severity}'`
- **信頼度**: HIGH

### MIGR-01: TIMESTAMP vs TIMESTAMPTZ 混在
- **検出方法**: Grep（W1）
- **パターン**: マイグレーションファイルで`TIMESTAMP`が`WITH TIME ZONE`なしで使用
- **Grepクエリ**:
  ```
  pattern: \bTIMESTAMP\b(?!\s+WITH\s+TIME\s+ZONE)
  path: supabase/migrations/
  glob: "*.sql"
  ```
- **信頼度**: HIGH
- **背景**: MEMORY.md教訓 — TZなしTIMESTAMPはブラウザがローカル時刻として誤解釈し9時間ズレる

---

## P2: Redundant / Dead Code

### DUP-01: 二重クエリ
- **検出方法**: Codex（W3）
- **プロンプト要旨**: 同一リクエストパス内で同じテーブルに対するSupabaseクエリが2回以上実行されるケースを検出。
- **信頼度**: MEDIUM
- **Issue #1678 実例**: `assistant.js` — `fetchCompanyData()`(L671) + `attachShareholders()`(L1976) で `company_shareholders` を二重取得

### DUP-02: コピペ関数
- **検出方法**: Codex（W3）
- **プロンプト要旨**: 関数本体が80%以上類似している2つ以上の関数を検出。
- **信頼度**: LOW

### DEAD-01: 未使用エクスポート
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `module.exports`や`export`されているがプロジェクト内のどこからも`import`/`require`されていない関数・変数。
- **信頼度**: LOW

### DEAD-02: 到達不能ブランチ
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `if (false)`、`if (true)`、常に同じ値を返す条件分岐。
- **信頼度**: LOW

---

## P2: Architecture

### API-01: api/ vs backend/ エンドポイント重複
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `api/_lib/routes/`（41ファイル）と`backend/src/routes/`（7ファイル）で同一エンドポイントが重複定義されていないか確認。
- **信頼度**: MEDIUM

---

## P3: Performance

### PERF-01: N+1 クエリ
- **検出方法**: Codex（W3）
- **プロンプト要旨**: `for`/`for...of`/`forEach`ループ内で`await supabase`や`await supabaseAdmin`のDBクエリが実行されるパターンを検出。
- **信頼度**: MEDIUM

### PERF-02: `.single()` 欠落
- **検出方法**: Grep（W1）
- **Grepクエリ**:
  ```
  pattern: \.select\([^)]*\)(?!.*\.(single|maybeSingle|limit)\()
  glob: "*.{js,ts}"
  ```
- **信頼度**: LOW
- **許可パターン**: `.limit(1)` を使用している場合は除外

---

## P3: Type Safety

### TYPE-01: `as any` キャスト
- **検出方法**: Grep（W1）
- **Grepクエリ**:
  ```
  pattern: \bas\s+any\b
  glob: "*.{ts,tsx}"
  除外: *.ts.bak, *.test.*, *.spec.*
  ```
- **信頼度**: HIGH

### TYPE-03: 暗黙の any
- **検出方法**: Grep（W1）
- **Grepクエリ**:
  ```
  pattern: function\s+\w+\s*\([^:)]+\)
  glob: "*.ts"
  除外: *.d.ts
  ```
- **信頼度**: LOW（JSファイルでは正常）

### LINT-01: `.ts.bak` ファイルの残存
- **検出方法**: Glob（W1）
- **パターン**: `**/*.ts.bak`
- **信頼度**: HIGH
- **背景**: TypeScript→JS移行の残骸。ビルド対象外だが混乱の元。
