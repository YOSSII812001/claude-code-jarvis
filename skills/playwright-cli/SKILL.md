---
name: playwright-cli
description: |
  ブラウザ自動操作CLIツール。MCPプラグインよりトークン効率が高い。Webテスト、フォーム入力、スクリーンショット、データ抽出、セッション管理、ストレージ操作、ネットワークモック、トレース、動画記録に使用。
  トリガー: "playwright-cli", "CLIでブラウザ操作", "ブラウザCLI", "playwright cli"
  使用場面: (1) ブラウザ自動操作、(2) Webテスト、(3) フォーム入力、(4) スクリーンショット/PDF、(5) 認証状態の保存・復元、(6) ネットワークモック、(7) マルチセッション並列操作、(8) テストコード生成、(9) トレース・動画デバッグ
allowed-tools: Bash(playwright-cli:*)
---

# Playwright CLI ガイド

## 概要
`@playwright/cli` はブラウザ自動操作のCLIツール。MCPプラグインよりトークン効率が高く、コーディングエージェントに最適。
- **パッケージ**: `@playwright/cli` (`npm install -g @playwright/cli@latest`)
- **コマンド**: `playwright-cli <command> [args] [options]`
- **ヘルプ**: `playwright-cli --help` / `playwright-cli --help <command>`
- **要件**: Node.js 18+

## 事前チェック
1. バージョン確認: `playwright-cli --version`
2. 未インストール時: `npm install -g @playwright/cli@latest`
3. ブラウザインストール: `playwright-cli install-browser`

## 判断ルール
- **CLI優先**: 大量操作、並列テスト、状態管理、ネットワークモック、テストコード生成、トレース/動画
- **MCP優先** (`/playwright`): 単純な探索操作、インタラクティブなページ調査
- **重要**: ナビゲーションやDOM更新後は必ず `snapshot` を再実行してからref値を使用する（古いrefは無効になる）
- 名前付きセッション (`-s=<name>`) は複数ユーザー状態やサイトを扱う場合に使用

## MCPプラグイン（/playwright）との比較
| 項目 | playwright-cli (このスキル) | Playwright MCP (/playwright) |
|------|---------------------------|------------------------------|
| 方式 | Bash経由のCLI | MCPプラグイン関数 |
| トークン効率 | 高い（簡潔なコマンド） | 低い（スキーマが大きい） |
| セッション管理 | 複数セッション並列可 | 単一セッション |
| ストレージ操作 | Cookie/localStorage/sessionStorage完全制御 | 限定的 |
| ネットワークモック | route コマンドで簡単 | run-code必要 |
| テストコード生成 | 操作ごとに自動生成 | なし |
| トレース/動画 | 内蔵 | なし |
| 適した場面 | 大量操作、並列テスト、状態管理 | 単純な探索操作 |

## 標準ワークフロー
1. ブラウザ起動: `playwright-cli open <url>`
2. ref取得: `playwright-cli snapshot`
3. 操作: `click`, `fill`, `type`, `select`, `check`, `press`
4. DOM変更後は **必ず再snapshot**（refは毎回変わる）
5. 検証: `snapshot`, `screenshot`, `console`, `network`, `pdf`
6. 認証再利用が必要なら: `state-save`
7. 終了: `close` または `close-all`

## クイックスタート

```bash
playwright-cli open                       # ブラウザを開く
playwright-cli goto https://example.com   # ページへ移動
playwright-cli snapshot                   # ページ構造を取得（ref値を確認）
playwright-cli click e15                  # ref指定でクリック
playwright-cli type "search query"        # テキスト入力
playwright-cli press Enter                # キー押下
playwright-cli screenshot                 # スクリーンショット
playwright-cli close                      # ブラウザを閉じる
```

## コマンドリファレンス

### コア操作

```bash
playwright-cli open                           # ブラウザを開く
playwright-cli open https://example.com       # URLを指定して開く
playwright-cli goto https://example.com       # ページ移動
playwright-cli type "入力テキスト"              # テキスト入力
playwright-cli click e3                       # クリック
playwright-cli dblclick e7                    # ダブルクリック
playwright-cli fill e5 "user@example.com"     # フィールドに値を入力
playwright-cli drag e2 e8                     # ドラッグ&ドロップ
playwright-cli hover e4                       # ホバー
playwright-cli select e9 "option-value"       # ドロップダウン選択
playwright-cli upload ./document.pdf          # ファイルアップロード
playwright-cli check e12                      # チェックボックスON
playwright-cli uncheck e12                    # チェックボックスOFF
playwright-cli snapshot                       # ページスナップショット（ref取得）
playwright-cli snapshot --filename=snap.yaml  # ファイルに保存
playwright-cli eval "document.title"          # JavaScript実行
playwright-cli eval "el => el.textContent" e5 # 要素に対してJS実行
playwright-cli dialog-accept                  # ダイアログ承認
playwright-cli dialog-accept "確認テキスト"     # prompt入力して承認
playwright-cli dialog-dismiss                 # ダイアログ拒否
playwright-cli resize 1920 1080               # ウィンドウリサイズ
playwright-cli close                          # ブラウザを閉じる
```

### ナビゲーション

```bash
playwright-cli go-back      # 戻る
playwright-cli go-forward   # 進む
playwright-cli reload        # リロード
```

### キーボード

```bash
playwright-cli press Enter       # キー押下
playwright-cli press ArrowDown   # 矢印キー
playwright-cli keydown Shift     # キーダウン
playwright-cli keyup Shift       # キーアップ
# 特殊キー: Enter, Tab, Escape, Backspace, Delete, ArrowUp/Down/Left/Right
```

### マウス

```bash
playwright-cli mousemove 150 300     # マウス移動
playwright-cli mousedown             # マウスボタン押下
playwright-cli mousedown right       # 右クリック押下
playwright-cli mouseup               # マウスボタン解放
playwright-cli mouseup right         # 右クリック解放
playwright-cli mousewheel 0 100      # スクロール
```

### スクリーンショット・PDF

```bash
playwright-cli screenshot                     # ページ全体
playwright-cli screenshot e5                  # 特定要素
playwright-cli screenshot --filename=page.png # ファイル名指定
playwright-cli pdf --filename=page.pdf        # PDF出力
```

### タブ管理

```bash
playwright-cli tab-list                       # タブ一覧
playwright-cli tab-new                        # 新規タブ
playwright-cli tab-new https://example.com    # URL指定で新規タブ
playwright-cli tab-close                      # 現在のタブを閉じる
playwright-cli tab-close 2                    # インデックス指定で閉じる
playwright-cli tab-select 0                   # タブ切り替え
```

### ストレージ操作

#### 状態の保存・復元
```bash
playwright-cli state-save                 # 自動ファイル名で保存
playwright-cli state-save auth.json       # ファイル名指定で保存
playwright-cli state-load auth.json       # 状態を復元
```

#### Cookie
```bash
playwright-cli cookie-list                                    # 全Cookie一覧
playwright-cli cookie-list --domain=example.com               # ドメインでフィルタ
playwright-cli cookie-list --path=/api                        # パスでフィルタ
playwright-cli cookie-get session_id                          # 特定Cookie取得
playwright-cli cookie-set session abc123                      # Cookie設定（基本）
playwright-cli cookie-set session abc123 --domain=example.com --httpOnly --secure --sameSite=Lax  # オプション付き
playwright-cli cookie-set remember_me token --expires=1735689600  # 有効期限付き
playwright-cli cookie-delete session_id                       # Cookie削除
playwright-cli cookie-clear                                   # 全Cookie削除
```

#### localStorage
```bash
playwright-cli localstorage-list          # 全項目一覧
playwright-cli localstorage-get theme     # 値取得
playwright-cli localstorage-set theme dark   # 値設定
playwright-cli localstorage-set user '{"name":"John"}'  # JSON値設定
playwright-cli localstorage-delete theme  # 削除
playwright-cli localstorage-clear         # 全削除
```

#### sessionStorage
```bash
playwright-cli sessionstorage-list        # 全項目一覧
playwright-cli sessionstorage-get step    # 値取得
playwright-cli sessionstorage-set step 3  # 値設定
playwright-cli sessionstorage-delete step # 削除
playwright-cli sessionstorage-clear       # 全削除
```

### ネットワークモック

```bash
# ステータスコード指定
playwright-cli route "**/*.jpg" --status=404

# JSONレスポンス
playwright-cli route "**/api/users" --body='[{"id":1,"name":"Alice"}]' --content-type=application/json

# カスタムヘッダー
playwright-cli route "**/api/data" --body='{"ok":true}' --header="X-Custom: value"

# リクエストヘッダー除去
playwright-cli route "**/*" --remove-header=cookie,authorization

# ルート管理
playwright-cli route-list            # アクティブなルート一覧
playwright-cli unroute "**/*.jpg"    # 特定ルート解除
playwright-cli unroute               # 全ルート解除
```

URLパターン:
- `**/api/users` - パス完全一致
- `**/api/*/details` - ワイルドカード
- `**/*.{png,jpg,jpeg}` - 拡張子マッチ
- `**/search?q=*` - クエリパラメータ

### DevTools

```bash
playwright-cli console                # コンソールログ取得
playwright-cli console warning        # warning以上のみ
playwright-cli network                # ネットワークリクエスト一覧
playwright-cli tracing-start          # トレース開始
playwright-cli tracing-stop           # トレース停止
playwright-cli video-start            # 動画記録開始
playwright-cli video-stop demo.webm   # 動画記録停止・保存
```

### ブラウザ設定

```bash
# ブラウザ選択
playwright-cli open --browser=chrome
playwright-cli open --browser=firefox
playwright-cli open --browser=webkit
playwright-cli open --browser=msedge

# 表示モード
playwright-cli open --headed                  # ヘッド付き（GUIあり）

# プロファイル
playwright-cli open --persistent              # 永続プロファイル
playwright-cli open --profile=/path/to/dir    # カスタムプロファイル

# 設定ファイル
playwright-cli open --config=my-config.json

# ブラウザ拡張モード
playwright-cli open --extension

# データ削除
playwright-cli delete-data
```

### インストール

```bash
playwright-cli install --skills       # スキルファイルをインストール
playwright-cli install-browser        # ブラウザをインストール
```

## セッション管理（並列操作）

名前付きセッションで複数ブラウザを独立して並列操作可能。

```bash
# セッション作成と操作
playwright-cli -s=auth open https://app.example.com/login
playwright-cli -s=public open https://example.com
playwright-cli -s=auth fill e1 "user@example.com"
playwright-cli -s=public snapshot

# セッション管理
playwright-cli list                       # 全セッション一覧
playwright-cli -s=mysession close         # 特定セッションを閉じる
playwright-cli close-all                  # 全セッションを閉じる
playwright-cli kill-all                   # 全プロセスを強制終了
playwright-cli -s=mysession delete-data   # セッションデータ削除

# 環境変数でデフォルトセッション指定
export PLAYWRIGHT_CLI_SESSION="mysession"
```

セッション毎に独立:
- Cookie / localStorage / sessionStorage / IndexedDB
- キャッシュ / 閲覧履歴 / 開いているタブ

## run-code（高度な操作）

CLIコマンドでカバーできない高度な操作に使用。

```bash
# ジオロケーション設定
playwright-cli run-code "async page => {
  await page.context().grantPermissions(['geolocation']);
  await page.context().setGeolocation({ latitude: 35.6762, longitude: 139.6503 });
}"

# ダークモードエミュレーション
playwright-cli run-code "async page => {
  await page.emulateMedia({ colorScheme: 'dark' });
}"

# ネットワークアイドル待ち
playwright-cli run-code "async page => {
  await page.waitForLoadState('networkidle');
}"

# 要素出現待ち
playwright-cli run-code "async page => {
  await page.waitForSelector('.loading', { state: 'hidden' });
}"

# iframe操作
playwright-cli run-code "async page => {
  const frame = page.locator('iframe#my-iframe').contentFrame();
  await frame.locator('button').click();
}"

# ファイルダウンロード
playwright-cli run-code "async page => {
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.click('a.download-link')
  ]);
  await download.saveAs('./downloaded-file.pdf');
}"

# ネットワーク障害シミュレーション
playwright-cli run-code "async page => {
  await page.route('**/api/offline', route => route.abort('internetdisconnected'));
}"
# abort options: connectionrefused, timedout, connectionreset, internetdisconnected

# 遅延レスポンス
playwright-cli run-code "async page => {
  await page.route('**/api/slow', async route => {
    await new Promise(r => setTimeout(r, 3000));
    route.fulfill({ body: JSON.stringify({ data: 'loaded' }) });
  });
}"

# 条件付きモックレスポンス
playwright-cli run-code "async page => {
  await page.route('**/api/login', route => {
    const body = route.request().postDataJSON();
    if (body.username === 'admin') {
      route.fulfill({ body: JSON.stringify({ token: 'mock-token' }) });
    } else {
      route.fulfill({ status: 401, body: JSON.stringify({ error: 'Invalid' }) });
    }
  });
}"

# 複数Cookie一括設定
playwright-cli run-code "async page => {
  await page.context().addCookies([
    { name: 'session_id', value: 'abc', domain: 'example.com', path: '/', httpOnly: true },
    { name: 'prefs', value: '{\"theme\":\"dark\"}', domain: 'example.com', path: '/' }
  ]);
}"
```

## テストコード自動生成

操作するたびにPlaywright TypeScriptコードが自動生成される。

```bash
playwright-cli fill e1 "user@example.com"
# 出力: await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

playwright-cli click e3
# 出力: await page.getByRole('button', { name: 'Sign In' }).click();
```

生成コードをテストファイルにまとめる:
```typescript
import { test, expect } from '@playwright/test';
test('login flow', async ({ page }) => {
  await page.goto('https://example.com/login');
  await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');
  await page.getByRole('button', { name: 'Sign In' }).click();
  await expect(page).toHaveURL(/.*dashboard/);
});
```

## 典型的なワークフロー

### フォーム送信
```bash
playwright-cli open https://example.com/form
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3
playwright-cli snapshot
playwright-cli close
```

### 認証状態の保存・再利用
```bash
# ログインして状態保存
playwright-cli open https://app.example.com/login
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3
playwright-cli state-save auth.json

# 後から状態を復元（ログインスキップ）
playwright-cli state-load auth.json
playwright-cli open https://app.example.com/dashboard
```

### マルチタブ操作
```bash
playwright-cli open https://example.com
playwright-cli tab-new https://example.com/other
playwright-cli tab-list
playwright-cli tab-select 0
playwright-cli snapshot
playwright-cli close
```

### デバッグ（トレース付き）
```bash
playwright-cli open https://example.com
playwright-cli tracing-start
playwright-cli click e4
playwright-cli fill e7 "test"
playwright-cli console
playwright-cli network
playwright-cli tracing-stop
playwright-cli close
```

### 並列スクレイピング
```bash
playwright-cli -s=site1 open https://site1.com &
playwright-cli -s=site2 open https://site2.com &
wait
playwright-cli -s=site1 snapshot
playwright-cli -s=site2 snapshot
playwright-cli close-all
```

## 設定ファイル (playwright-cli.json)

```json
{
  "browser": "chromium",
  "launchOptions": { "headless": true },
  "contextOptions": { "viewport": { "width": 1280, "height": 720 } },
  "timeout": 30000,
  "outputDir": "./output"
}
```

環境変数 `PLAYWRIGHT_MCP_` プレフィックスで設定を上書き可能。

## PowerShell 環境での注意
Windows PowerShell使用時:
```powershell
# JSON引数はシングルクォートを使用
playwright-cli route '**/api/users' --body '[{"id":1}]' --content-type application/json

# デフォルトセッション設定
$env:PLAYWRIGHT_CLI_SESSION='auth'

# デフォルトセッション解除
Remove-Item Env:PLAYWRIGHT_CLI_SESSION
```

## セキュリティ注意事項
- 認証トークンを含むストレージ状態ファイルをコミットしない
- `*.auth-state.json` を `.gitignore` に追加
- 自動化完了後にステートファイルを削除
- テスト用認証情報を使用し、本番認証情報は使わない
- 機密データには環境変数を使用

## チェックリスト

- [ ] 操作前に `snapshot` でref値を取得したか
- [ ] DOM変更後に `snapshot` を再実行したか（古いrefは無効）
- [ ] 認証状態ファイル（`.auth-state.json`）が `.gitignore` に含まれているか
- [ ] テスト完了後に `close` / `close-all` でブラウザを閉じたか

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| ブラウザが起動しない | ブラウザ未インストール | `playwright-cli install-browser` |
| ゾンビプロセスが残る | closeせず終了した | `playwright-cli kill-all` |
| ref値が無効 | DOM変更後にsnapshot未実行 | `playwright-cli snapshot` を再実行 |
| 古いセッションデータ | 前回のセッションが残存 | `playwright-cli -s=oldsession delete-data` |
| コマンドのフラグが不明 | ヘルプ未確認 | `playwright-cli --help <command>` |

## 関連スキル

- **e2e-test** — E2Eテストプロセス定義（テスト計画・実行・検証の全体フロー）
- **playwright** — Playwright MCPプラグイン（単純な探索操作向け、別スキル）

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（チェックリスト、トラブルシューティングテーブル化、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-25 | 初版作成 | Playwright CLI操作の標準化 |
