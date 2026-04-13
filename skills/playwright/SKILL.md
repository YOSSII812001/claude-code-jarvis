---
name: playwright
description: ブラウザ自動操作・E2EテストにPlaywright MCPプラグインを使用。ページナビゲーション、スナップショット取得、要素クリック、フォーム入力、スクリーンショット撮影など。CLIではなくプラグイン経由で操作。
---

# Playwright MCPプラグイン ガイド

## 概要
ブラウザ自動操作・E2EテストにはPlaywright MCPプラグインを使用。
CLIではなく、`mcp__plugin_playwright_playwright__*` 関数で操作する。

## 基本操作

### ページナビゲーション
```
mcp__plugin_playwright_playwright__browser_navigate
  url: https://example.com
```

### ページスナップショット（推奨）
スクリーンショットより軽量。要素の `ref` 属性を取得できる。
```
mcp__plugin_playwright_playwright__browser_snapshot
```

### スクリーンショット撮影
```
mcp__plugin_playwright_playwright__browser_take_screenshot
  filename: "screenshot.png"

# フルページ
mcp__plugin_playwright_playwright__browser_take_screenshot
  filename: "full-page.png"
  fullPage: true

# 特定要素のみ
mcp__plugin_playwright_playwright__browser_take_screenshot
  element: "ログインフォーム"
  ref: "e123"
  filename: "login-form.png"
```

## 要素操作

### クリック
`ref` はスナップショットから取得した要素参照。
```
mcp__plugin_playwright_playwright__browser_click
  element: "ログインボタン"
  ref: "e45"

# 右クリック
mcp__plugin_playwright_playwright__browser_click
  element: "コンテキストメニュー対象"
  ref: "e67"
  button: "right"

# ダブルクリック
mcp__plugin_playwright_playwright__browser_click
  element: "編集対象"
  ref: "e89"
  doubleClick: true
```

### ホバー
```
mcp__plugin_playwright_playwright__browser_hover
  element: "ドロップダウンメニュー"
  ref: "e12"
```

### テキスト入力
```
mcp__plugin_playwright_playwright__browser_type
  element: "メールアドレス入力欄"
  ref: "e34"
  text: "test@example.com"

# 入力後にEnterキーを押す
mcp__plugin_playwright_playwright__browser_type
  element: "検索ボックス"
  ref: "e56"
  text: "検索キーワード"
  submit: true
```

### フォーム一括入力
```
mcp__plugin_playwright_playwright__browser_fill_form
  fields: [
    {"name": "メールアドレス", "type": "textbox", "ref": "e10", "value": "test@example.com"},
    {"name": "パスワード", "type": "textbox", "ref": "e11", "value": "password123"},
    {"name": "利用規約同意", "type": "checkbox", "ref": "e12", "value": "true"}
  ]
```

### ドロップダウン選択
```
mcp__plugin_playwright_playwright__browser_select_option
  element: "都道府県選択"
  ref: "e78"
  values: ["福井県"]
```

### ドラッグ＆ドロップ
```
mcp__plugin_playwright_playwright__browser_drag
  startElement: "ドラッグ元"
  startRef: "e90"
  endElement: "ドロップ先"
  endRef: "e91"
```

## 待機・同期

### 時間待機
```
mcp__plugin_playwright_playwright__browser_wait_for
  time: 3
```

### テキスト出現待ち
```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "ログイン完了"
```

### テキスト消失待ち
```
mcp__plugin_playwright_playwright__browser_wait_for
  textGone: "読み込み中..."
```

## キーボード操作

### キー押下
```
mcp__plugin_playwright_playwright__browser_press_key
  key: "Enter"

# 特殊キー例
# ArrowUp, ArrowDown, ArrowLeft, ArrowRight
# Escape, Tab, Backspace, Delete
# Control+A, Control+C, Control+V
```

## タブ操作

### タブ一覧
```
mcp__plugin_playwright_playwright__browser_tabs
  action: "list"
```

### 新規タブ
```
mcp__plugin_playwright_playwright__browser_tabs
  action: "new"
```

### タブ切り替え
```
mcp__plugin_playwright_playwright__browser_tabs
  action: "select"
  index: 1
```

### タブを閉じる
```
mcp__plugin_playwright_playwright__browser_tabs
  action: "close"
  index: 0
```

## デバッグ・確認

### コンソールメッセージ取得
```
mcp__plugin_playwright_playwright__browser_console_messages
  level: "error"  # error, warning, info, debug
```

### ネットワークリクエスト確認
```
mcp__plugin_playwright_playwright__browser_network_requests
  includeStatic: false  # 静的リソースを除外
```

### JavaScript実行
```
mcp__plugin_playwright_playwright__browser_evaluate
  function: "() => document.title"

# 要素に対して実行
mcp__plugin_playwright_playwright__browser_evaluate
  element: "入力フィールド"
  ref: "e45"
  function: "(element) => element.value"
```

## ダイアログ操作

### ダイアログ処理（alert, confirm, prompt）
```
# 承認
mcp__plugin_playwright_playwright__browser_handle_dialog
  accept: true

# 拒否
mcp__plugin_playwright_playwright__browser_handle_dialog
  accept: false

# promptに入力
mcp__plugin_playwright_playwright__browser_handle_dialog
  accept: true
  promptText: "入力テキスト"
```

## ファイルアップロード

```
mcp__plugin_playwright_playwright__browser_file_upload
  paths: ["/path/to/file.pdf"]
```

## ブラウザ制御

### ブラウザを閉じる
```
mcp__plugin_playwright_playwright__browser_close
```

### ウィンドウリサイズ
```
mcp__plugin_playwright_playwright__browser_resize
  width: 1920
  height: 1080
```

### 戻る
```
mcp__plugin_playwright_playwright__browser_navigate_back
```

### ブラウザインストール（エラー時）
```
mcp__plugin_playwright_playwright__browser_install
```

## トラブルシューティング: Playwrightバージョン差でブラウザが起動できない

### 症状
`browser_navigate` 等で以下のようなエラーが出てブラウザが起動できない。

```
Failed to initialize browser: browserType.launch: Executable doesn't exist at ...\ms-playwright\chromium-1200\...\chrome.exe
Please run: npx playwright install
```

### 原因（重要）
Playwright は **「Playwrightのバージョンごとに決まった browser revision」** を要求する。
そのため、以下がズレると **ms-playwright 配下に必要な revision の実体が無く** 起動に失敗する。

- **Claude Code の Playwright プラグイン**（`/plugin` でインストールしたもの）
- **プロジェクトの Playwright**（`node_modules/playwright` / `@playwright/test`）
- **グローバルの @playwright/mcp**（`npm -g` で入っているPlaywright）

※ エラーメッセージに出る `chromium-1200` などの数字が「必要な revision」。

### 切り分け手順（Windows）
- **[1] 要求されているrevisionを確認**
  - エラーメッセージのパス（例: `...\ms-playwright\chromium-1200\...`）が最優先。

- **[2] ms-playwright に実体があるか確認**
  - 既定パス: `C:\Users\<User>\AppData\Local\ms-playwright\`
  - `chromium-1200` / `webkit-2227` / `firefox-1497` のようなフォルダが存在するか。

- **[3] どのPlaywrightが使われているか確認**
  - プロジェクト側:
    - `node -e "console.log(require('playwright/package.json').version)"`
    - `node -e "console.log(require('playwright-core/package.json').version)"`
  - グローバル側（例: @playwright/mcp）:
    - `npm root -g` で場所を出し、その配下の `@playwright/mcp/node_modules/playwright*/package.json` を確認。
  - **注意**: `playwright` と `playwright-core` がズレると、CLIが参照する `browsers.json` が古くなり、インストールされるrevisionが意図とズレる。

### 解決策（推奨順）
- **[A] そのPlaywrightに対応した CLI で install する**
  - プロジェクトのPlaywrightを入れたい場合:
    - `npx playwright install`（ただしnpxの解決が怪しい時は下記）
    - `node node_modules/playwright/cli.js install chromium`
    - `node node_modules/@playwright/test/cli.js install chromium`
  - グローバル `@playwright/mcp` 側を入れたい場合:
    - `node "<npm -g root>\@playwright\mcp\node_modules\playwright\cli.js" install chromium`

- **[B] 手動で browser revision を入れる（最終手段）**
  - Claude Code の Playwright プラグインが特定revision（例: `chromium-1200`）を要求し、
    かつ通常の `playwright install` で入らない/入れられない場合。
  - Chromium(win64)の例:
    - ダウンロードURL:
      - `https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/<REVISION>/chromium-win64.zip`
    - 展開先:
      - `C:\Users\<User>\AppData\Local\ms-playwright\chromium-<REVISION>\`
  - ポイント:
    - **エラーに出ているパスと同じフォルダ構造**になるように解凍する。
    - `chrome.exe` の場所まで一致しないと起動できない。

### 判断基準（どれを入れるべき？）
- **Claude Code の MCP操作で落ちている**なら、まずは **エラーメッセージが要求する revision を ms-playwright に用意**する（プラグイン側の要求が最優先）。
- **プロジェクトのPlaywrightテストが落ちている**なら、プロジェクト側の `playwright install` を優先。

### 再発防止
- Playwrightを更新したら、同じ環境で必ず `playwright install` を実行してブラウザ実体を揃える。
- 複数のPlaywrightが共存している場合（Claude Codeプラグイン/グローバル/プロジェクト）、
  **「どのPlaywrightが要求するrevisionか」→「そのCLIでinstall」** の順で対処する。

## 既知の制約事項（E2Eテスト時の注意）

| 操作 | 制約 | 代替手段 |
|------|------|---------|
| `input[type="file"]` | MCP経由ではファイル添付操作不可（#1641教訓） | ユーザー手動確認に委任 |
| ファイルダウンロード | Blob URL + `<a download>` のOS保存はMCP検証不能 | `browser_evaluate` 内で `fetch(apiUrl)` → ステータス・Content-Type・サイズ検証。または `playwright-cli run-code` で `waitForEvent('download')` |
| ファイルアップロード | `browser_file_upload` は一部環境で不安定 | `playwright-cli upload` を使用 |

> **教訓（#1669）**: ファイルDL系E2Eで「不可」としてSKIPし続けた結果、Excelエクスポートバグが本番まで検出されなかった。`browser_evaluate` + `fetch()` でAPIレベルのテストを必ず実施すること。

## 典型的なテストフロー

```
1. browser_navigate でページにアクセス
      ↓
2. browser_wait_for で読み込み待ち（または time: 2-3秒）
      ↓
3. browser_snapshot でページ構造取得（ref値を確認）
      ↓
4. browser_click / browser_type で操作
      ↓
5. browser_snapshot で結果確認
      ↓
6. browser_take_screenshot で証跡保存（必要に応じて）
```

## Tips

- **snapshot vs screenshot**: 操作には `snapshot` を使用（ref取得のため）。視覚的証跡には `screenshot`
- **ref の取得**: `snapshot` の YAML出力から `[ref=e123]` 形式で確認
- **待機の重要性**: SPAでは画面遷移後に `wait_for` で要素出現を待つ
- **エラー時**: `browser_install` でブラウザを再インストール
- **Playwright更新後に起動できない**: `Executable doesn't exist at ...ms-playwright\\chromium-XXXX...` は revision 不一致の典型。まずエラーの `chromium-XXXX` を ms-playwright に揃える。

## 関連スキル

- `e2e-test` - E2Eテストの計画・実行・検証プロセス（テスト設計のメタスキル）
- `usacon` - Usaconプロジェクト固有のE2Eテスト実務（テストアカウント、URL等）

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2025-12 (推定) | 初版作成 |
| 2026-02 (推定) | Playwrightバージョン差トラブルシューティング追加 |
| 2026-03-04 | 関連スキル・改訂履歴セクション追加 |
| 2026-04-03 | 既知の制約事項セクション追加（ファイルDL/UL不可、fetch()代替パターン） |

## 参考
- Playwright公式: https://playwright.dev/
