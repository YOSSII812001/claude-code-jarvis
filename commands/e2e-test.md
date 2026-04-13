# E2Eテスト実行コマンド

## 概要
PlaywrightMCPを使用してE2Eテストを実行します。

## ログイン情報
- アカウント：ytakeshita@robbits.co.jp
- パスワード：password123

## 実行手順

### 1. ブラウザを起動
```bash
# Chromiumで起動
mcp1_playwright_navigate --url "[ターゲットURL]" --browserType "chromium"

# または他のブラウザで起動
# mcp1_playwright_navigate --url "[ターゲットURL]" --browserType "firefox"
# mcp1_playwright_navigate --url "[ターゲットURL]" --browserType "webkit"
```

### 1.5. ウィンドウを最大化（ディスプレイサイズに自動適応）
```bash
# JavaScriptでウィンドウを最大化
mcp1_playwright_evaluate --script "window.moveTo(0, 0); window.resizeTo(screen.availWidth, screen.availHeight);"
```

### 2. ログイン処理
```bash
# メール入力
mcp1_playwright_fill --selector "input[type='email']" --value "ytakeshita@robbits.co.jp"

# パスワード入力
mcp1_playwright_fill --selector "input[type='password']" --value "password123"

# ログインボタンクリック
mcp1_playwright_click --selector "button[type='submit']"
```

### 3. ログイン確認
```bash
# ログイン後の画面確認
mcp1_playwright_get_visible_text
```

### 4. テストシナリオ実行
必要に応じて追加のテスト手順を実行します：
- ナビゲーションメニューのテスト
- 各ページ遷移のテスト
- 機能操作のテスト

### 5. ブラウザを閉じる
```bash
mcp1_playwright_close
```

## 注意事項
- テスト実行前にアプリケーションサーバーが起動していることを確認してください
- [ターゲットURL] はテスト対象環境のURLに置き換えてください
- 画面サイズはディスプレイに合わせて自動的に最大化されます（4K/2K対応）
