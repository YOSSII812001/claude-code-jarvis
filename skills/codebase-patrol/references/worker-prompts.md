# Worker Prompts テンプレート

各ワーカーのサブエージェントプロンプトとCodex execプロンプトの定義。

---

## W1: Static Pattern Scanner（Claude サブエージェント）

### 起動パターン

```
Agent tool:
  description: "Patrol W1: Static pattern scan"
  subagent_type: general-purpose
  prompt: <下記テンプレート>
```

### プロンプトテンプレート

```
あなたはコードベースパトロールのW1（静的パターンスキャナー）です。
以下のルールに従い、プロジェクトディレクトリ内をスキャンしてください。

■ プロジェクトディレクトリ: <PROJECT_DIR>
■ スキャン対象: <SCOPE_FILES or "全ファイル">
■ 担当ルール: SEC-01, SEC-02, SEC-04, SEC-06, ERR-01, ENC-01, ENC-02,
              TYPE-01, TYPE-03, PERF-02, LINT-01, MIGR-01

■ 各ルールの検出手順:

【SEC-01】ハードコード秘密情報
  Grep pattern: (sk-[a-zA-Z0-9]{20,}|password\s*=\s*['"][^'"]+['"])
  対象: *.{js,ts,jsx,tsx}  除外: *.test.*, .env.example

【SEC-02】SQLインジェクション
  Grep pattern: \.(rpc|sql)\s*\(\s*`[^`]*\$\{
  対象: *.{js,ts}

【SEC-04】RLSバイパス
  Grep: バックエンド(api/, backend/)で supabase.from( を検索
  supabaseAdmin ではなく anon supabase を使用している箇所を特定

【SEC-06】.envのgit追跡
  Bash: git ls-files .env .env.local .env.production .env.staging
  出力があればFinding

【ERR-01】Supabase {data} without {error}
  Step 1: Grep pattern: const\s*\{\s*data  で Supabase クエリ行を検出
  Step 2: 各マッチ行を Read で確認し、同じ destructuring に error が含まれるか検証
  Step 3: error がなければ Finding (P1/HIGH)

【ENC-01】BOM検出（PowerShell互換）
  Bash で以下を実行:
  powershell.exe -Command "Get-ChildItem -Recurse -Include '*.js','*.ts','*.jsx','*.tsx' -Path '<PROJECT_DIR>' | Where-Object { \$_.FullName -notmatch 'node_modules|\\.git' } | ForEach-Object { \$bytes = [System.IO.File]::ReadAllBytes(\$_.FullName); if (\$bytes.Length -ge 3 -and \$bytes[0] -eq 0xEF -and \$bytes[1] -eq 0xBB -and \$bytes[2] -eq 0xBF) { Write-Output \"BOM: \$(\$_.FullName)\" } }"

【ENC-02】混在エンコーディング
  非UTF-8バイト検出は ENC-01 の延長で実施

【TYPE-01】as any キャスト
  Grep pattern: \bas\s+any\b
  対象: *.{ts,tsx}  除外: *.ts.bak, *.test.*

【TYPE-03】暗黙の any
  Grep pattern: function\s+\w+\s*\([^:)]+\)
  対象: *.ts  除外: *.d.ts

【PERF-02】.single() 欠落
  Grep pattern: \.select\(  で .single() や .limit(1) が後続しないケースを検出
  .limit(1) パターンは許可（除外）

【LINT-01】.ts.bak 残存
  Glob pattern: **/*.ts.bak

【MIGR-01】TIMESTAMP vs TIMESTAMPTZ
  Grep pattern: \bTIMESTAMP\b(?!\s+WITH\s+TIME\s+ZONE)
  対象: supabase/migrations/*.sql

■ 出力形式:
各Findingを以下の形式で報告してください（テキスト、JSON不要）:

FINDING: <RULE-ID> | <P0/P1/P2/P3> | <HIGH/MEDIUM/LOW> | <filepath>:<line> | <説明>

Findingがない場合は "W1: No findings" と報告してください。
PATROL-IGNORE コメントがある行は除外してください。
```

---

## W2: Quality Pattern Scanner（Claude サブエージェント）

### 起動パターン

```
Agent tool:
  description: "Patrol W2: Quality pattern scan"
  subagent_type: general-purpose
  prompt: <下記テンプレート>
```

### プロンプトテンプレート

```
あなたはコードベースパトロールのW2（品質パターンスキャナー）です。
以下のルールに従い、コードの品質問題を検出してください。

■ プロジェクトディレクトリ: <PROJECT_DIR>
■ スキャン対象: <SCOPE_FILES or "全ファイル">
■ 担当ルール: ERR-04, ERR-05, ERR-06, DUP-03, DEAD-03, ENC-03, API-01, DEP-01

■ 各ルールの検出手順:

【ERR-04】サイレント失敗
  catch ブロック内で [] / null / {} を返して失敗を隠蔽しているパターンを検出。
  api/_lib/ と backend/src/ の両方をスキャン。
  Grep multiline: catch\s*\([^)]*\)\s*\{[^}]*return\s+(null|\[\]|\{\})

【ERR-05】エラー伝播欠如
  console.warn/console.error + フォールバック値のみでエラーを上位に伝播していないケースを検出。
  ただし api/_lib/ 内の設計上の console.info/console.warn は除外。

【ERR-06】Stripe Webhook 署名検証漏れ
  Step 1: api/_lib/routes/ と backend/src/routes/ で "webhook" を含むファイルを特定
  Step 2: 各ファイルで constructEvent が呼ばれているか確認
  Step 3: 呼ばれていなければ Finding (P1/HIGH)

【DUP-03】未使用import
  明らかに使用されていない import/require を検出。
  ただし型のみの import (import type) は除外。

【DEAD-03】ステール feature flag
  Grep: FEATURE_FLAG, ENABLE_, DISABLE_, isEnabled 等のパターンで
  フラグが定義されているが参照箇所が1箇所のみ（定義のみ）のケースを検出。

【ENC-03】文字化け文字列
  ソースコード内の制御文字や典型的な文字化けパターンを検出。
  JSON ファイル内の Unicode エスケープ（\uXXXX）は正常として除外。

【API-01】api/ vs backend/ エンドポイント重複
  api/_lib/routes/ と backend/src/routes/ のルートファイル名を比較し、
  同名または類似のエンドポイントが両方に存在する場合は報告。

【DEP-01】依存パッケージの脆弱性
  Bash: npm audit --json 2>/dev/null を実行
  critical / high の脆弱性があれば報告。
  node_modules が存在しない場合は SKIP。

■ 出力形式:
FINDING: <RULE-ID> | <P0/P1/P2/P3> | <HIGH/MEDIUM/LOW> | <filepath>:<line> | <説明>

Findingがない場合は "W2: No findings" と報告してください。
PATROL-IGNORE コメントがある行は除外してください。
```

---

## W3: Semantic Analyzer（Codex exec）

### 起動パターン

W3はCodex CLIをサブエージェント経由で実行する。

```
Agent tool:
  description: "Patrol W3: Codex semantic analysis"
  subagent_type: general-purpose
  prompt: <下記テンプレート>
```

### プロンプトテンプレート（サブエージェント向け）

```
Codex CLI を使って深い意味的コード分析を実行してください。

■ プロジェクトディレクトリ: <PROJECT_DIR>

Step 1: Codex プロンプトを一時ファイルに書き出す

TMPFILE=$(mktemp /tmp/patrol_codex_XXXXXX.txt)
trap "rm -f $TMPFILE" EXIT

cat > "$TMPFILE" << 'PATROL_EOF'
あなたはシニアコード品質監査員です。以下の観点でコードベースを分析してください。

1. SUPABASE ERROR PATTERN (ERR-02):
   Supabase JS クライアントは throw しません。{ data: null, error: {...} } を返します。
   try/catch のみでエラーハンドリングし、error フィールドを確認していない箇所を検出してください。
   特に api/_lib/ と backend/src/ を重点的に確認。

2. DOUBLE QUERIES (DUP-01):
   同一リクエストパス内で同じテーブルに対して2回以上クエリが実行されるケースを検出。
   例: fetchCompanyData() が company_shareholders を取得済みなのに、
   attachShareholders() が再度取得するパターン。

3. N+1 QUERIES (PERF-01):
   for/for...of/forEach ループ内で await supabase クエリを実行するパターン。

4. DEAD EXPORTS (DEAD-01):
   module.exports や export で公開されているが、プロジェクト内のどこからも
   import/require されていない関数・変数。

5. UNREACHABLE BRANCHES (DEAD-02):
   if (false), if (true), 常に同値の条件分岐。

6. AUTH GAPS (SEC-03):
   api/_lib/routes/ で ensureUserOrg なし、
   backend/src/routes/ で auth ミドルウェアなしのルートハンドラ。

7. ORG_ID MISSING (SEC-05):
   .insert() / .upsert() で org_id フィールドが含まれていないケース。

8. ROUTE DUPLICATION (API-01):
   api/_lib/routes/ と backend/src/routes/ で同一エンドポイントの重複。

9. COPY-PASTE FUNCTIONS (DUP-02):
   関数本体が80%以上類似している2つ以上の関数。

10. UNCHECKED PROMISES (ERR-03):
    await の戻り値を検証せずに使用しているケース。

各Findingを以下の形式で出力してください:
FINDING: <RULE-ID> | <P0/P1/P2/P3> | <HIGH/MEDIUM/LOW> | <filepath>:<line> | <説明>
PATROL_EOF

Step 2: Codex を実行（read-only サンドボックス）

cat "$TMPFILE" | codex exec \
  --full-auto --sandbox read-only \
  --cd "<PROJECT_DIR>" \
  -c model_reasoning_effort="high" \
  -c features.rmcp_client=false \
  - \
  2>&1 | tee /tmp/codex_patrol_output_$$.txt

Bash timeout: 600000ms（10分）

Step 3: Codex 出力から FINDING: 行を抽出して報告

タイムアウトした場合は /tmp/codex_patrol_output_$$.txt から部分結果を回収。
```

---

## 出力形式の統一

全ワーカーは以下の形式で Finding を報告する:

```
FINDING: <RULE-ID> | <SEVERITY> | <CONFIDENCE> | <FILE>:<LINE> | <DESCRIPTION>
```

例:
```
FINDING: ERR-01 | P1 | HIGH | api/_lib/utils/shareholderHelper.js:25 | Supabase query destructures {data} without {error}. Silent failure risk.
FINDING: DUP-01 | P2 | MEDIUM | api/_lib/routes/assistant.js:1976 | company_shareholders already fetched at L671 by fetchCompanyData(). Redundant query in attachShareholders().
FINDING: SEC-06 | P0 | HIGH | .env.local | .env.local is tracked by git. Should be in .gitignore.
```

リーダー（親エージェント）はこのテキスト形式をパースして Step 3 のマージ処理に入る。
