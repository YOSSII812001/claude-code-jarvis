---
name: google-sheets-api
description: Google Sheets API をgws CLI（@googleworkspace/cli）でネイティブ操作するスキル。Playwright UI操作（google-sheets-mcp）の代替として、APIベースの高速・安定なセル読み書きを提供する。
---

# Google Sheets API スキル（gws CLI）

## 1. 概要

gws CLI（`@googleworkspace/cli`）による Google Sheets API ネイティブ操作スキル。
Playwright UI操作（google-sheets-mcp）で発生するref揮発性・日本語入力問題・ログイン問題・Ctrl+A罠を根本的に解消する。

### Playwright操作との使い分け

| 操作対象 | 使用ツール |
|---------|-----------|
| スプレッドシート読み書き | **gws CLI（本スキル）** |
| アプリE2Eテスト | Playwright（従来通り） |

### 操作マッピング（Playwright → gws CLI）

| 操作 | Playwright（旧） | gws CLI（新） |
|------|-----------------|--------------|
| セル読み取り | snapshot→NameBox→screenshot→目視 | `+read` / `values get` |
| 行一括読み取り | 1セルずつNameBoxジャンプ | `+read --range 'Sheet!A{row}:G{row}'` |
| セル書き込み | F2→execCommand→Enter | `values update` |
| 絵文字書き込み | eval execCommand('insertText','✅') | `values update --json '{"values":[["✅"]]}'` |
| 複数セル一括 | 1セルずつEnter連鎖 | `values batchUpdate` |
| セクションマップ | スクロール→screenshot×N→目視 | `+read --range 'Sheet!B1:B200'` → 正規表現 |

---

## 2. 前提条件

### インストール

```bash
# バイナリは手動ダウンロード済み
# 場所: C:/Users/zooyo/.local/bin/gws.exe
# バージョン: 0.3.3
gws --version
```

### 認証セットアップ

gcloud CLI がないため、手動OAuth設定が必要:

1. [Google Cloud Console](https://console.cloud.google.com) でプロジェクト作成（または既存を使用）
2. **Google Sheets API** を有効化（APIs & Services → Enable APIs）
3. **OAuth 2.0 クライアントID**（デスクトップアプリ）を作成
4. `client_secret.json` をダウンロード
5. 配置: `%APPDATA%\gws\client_secret.json`（= `C:\Users\zooyo\AppData\Roaming\gws\client_secret.json`）
6. 認証実行:

```bash
gws auth login
# ブラウザが開き、Googleアカウントで認証
# 認証後、credentials が保存される
```

7. 確認:

```bash
gws auth status
# auth_method: "oauth2" であればOK
```

### 定数

```
SHEET_ID = "1h1MSOUuH2hx0-Q-FCFjp6ylisY9yc4Y6EAocToFXUFg"
SHEET_NAME = "アプリ"  # シート（タブ）名
```

---

## 3. セル値の読み取り

### 3.1 ヘルパーコマンド（推奨: シンプルな読み取り）

```bash
# 単一セル
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A5'

# 行データ一括
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A5:G5'

# 範囲一括（セクションマップ構築用）
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!B1:B200'

# テーブル形式で見やすく出力
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1:G10' --format table
```

### 3.2 values get（詳細オプションが必要な場合）

```bash
# 単一セル
gws sheets spreadsheets values get \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!A5"}'

# 複数範囲一括取得
gws sheets spreadsheets values batchGet \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","ranges":["アプリ!A5:G5","アプリ!A10:G10"]}'
```

### レスポンス形式（JSON）

```json
{
  "range": "アプリ!A5:G5",
  "majorDimension": "ROWS",
  "values": [
    ["⬜", "テスト項目名", "手順の説明", "", "", "", ""]
  ]
}
```

- `values` は2次元配列。空セルは空文字列 `""` または配列から省略される
- 絵文字（✅⬜）はそのままUnicode文字列として返る（Playwright目視と違いパース不要）

---

## 4. セル値の書き込み

### 4.1 単一セル / 小範囲の書き込み

```bash
# RAW: 値をそのまま書き込み（数式解釈なし）
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!A5","valueInputOption":"RAW"}' \
  --json '{"values":[["✅"]]}'

# USER_ENTERED: ユーザー入力と同じ解釈（数式・日付変換あり）
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!D5","valueInputOption":"USER_ENTERED"}' \
  --json '{"values":[["NG"]]}'
```

### 4.2 絵文字書き込み

APIなのでUnicode問題なし。Playwright execCommand方式のような回避策は不要。

```bash
# ⬜ → ✅ に変更
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!A5","valueInputOption":"RAW"}' \
  --json '{"values":[["✅"]]}'

# ✅ → ⬜ に戻す
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!A5","valueInputOption":"RAW"}' \
  --json '{"values":[["⬜"]]}'
```

### 4.3 複数セル一括書き込み（batchUpdate）

```bash
gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","valueInputOption":"RAW"}' \
  --json '{
    "data": [
      {"range": "アプリ!A5", "values": [["✅"]]},
      {"range": "アプリ!D5", "values": [["NG"]]},
      {"range": "アプリ!E5", "values": [["ログイン画面でエラー発生"]]},
      {"range": "アプリ!G5", "values": [["竹下"]]}
    ]
  }'
```

### 4.4 行の追加（末尾追記）

```bash
# シンプルな追記
gws sheets +append --spreadsheet "$SHEET_ID" --values '⬜,新テスト項目,手順説明,,,,未割当'

# JSON形式（複数行）
gws sheets +append --spreadsheet "$SHEET_ID" \
  --json-values '[["⬜","項目1","手順1","","","",""],["⬜","項目2","手順2","","","",""]]'
```

### 4.5 セルのクリア

```bash
# 単一セル
gws sheets spreadsheets values clear \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!D5"}'

# 複数範囲
gws sheets spreadsheets values batchClear \
  --params '{"spreadsheetId":"'"$SHEET_ID"'"}' \
  --json '{"ranges":["アプリ!D5","アプリ!E5"]}'
```

---

## 5. チェックリスト固有パターン

### 5.1 セクションマップ構築

B列を一括取得し、正規表現でセクション見出しの行番号をパースする。

```bash
# B列全体を取得
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!B1:B200' --format json

# レスポンスの values 配列のインデックス + 1 = 行番号
# セクション見出しは「■」「●」「▶」などの記号で始まる
```

パース例（Bashで処理する場合）:
```bash
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!B1:B200' --format json \
  | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
for i, row in enumerate(data.get('values', []), 1):
    if row and re.match(r'^[■●▶]', row[0]):
        print(f'Row {i}: {row[0]}')
"
```

### 5.2 テスト項目の読み取り（1行分）

```bash
ROW=5
gws sheets +read --spreadsheet "$SHEET_ID" --range "アプリ!A${ROW}:G${ROW}" --format json
```

列マッピング:
| 列 | 内容 | 値の例 |
|----|------|--------|
| A | チェック状態 | ⬜ / ✅ |
| B | テスト項目名 | ログイン機能 |
| C | テスト手順 | 1. メール入力 2. パスワード入力... |
| D | 結果 | OK / NG / (空) |
| E | NG原因・備考 | エラーメッセージ表示されず |
| F | スクリーンショット | (URL等) |
| G | 担当者 | 竹下 / 清水 |

### 5.3 テスト結果の記入（典型パターン）

```bash
ROW=5

# パターン1: テスト合格
gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","valueInputOption":"RAW"}' \
  --json '{
    "data": [
      {"range": "アプリ!A'"$ROW"'", "values": [["✅"]]},
      {"range": "アプリ!D'"$ROW"'", "values": [["OK"]]},
      {"range": "アプリ!G'"$ROW"'", "values": [["竹下"]]}
    ]
  }'

# パターン2: テスト不合格
gws sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","valueInputOption":"RAW"}' \
  --json '{
    "data": [
      {"range": "アプリ!A'"$ROW"'", "values": [["✅"]]},
      {"range": "アプリ!D'"$ROW"'", "values": [["NG"]]},
      {"range": "アプリ!E'"$ROW"'", "values": [["ログイン画面でエラーメッセージが表示されない"]]},
      {"range": "アプリ!G'"$ROW"'", "values": [["竹下"]]}
    ]
  }'
```

### 5.4 担当者ドロップダウン（G列）

API経由でデータ入力規則のあるセルに値を書き込む場合:

```bash
# データ入力規則の値をそのまま書き込めばOK
gws sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"アプリ!G5","valueInputOption":"RAW"}' \
  --json '{"values":[["竹下"]]}'
```

**注意**: APIはデータ入力規則のバリデーションを**バイパスしない**。規則が「拒否」モードの場合、選択肢に含まれない値は書き込みエラーになる可能性がある。選択肢に含まれる正確な文字列を使用すること。

---

## 6. エラーハンドリング

| エラー | 原因 | 対策 |
|--------|------|------|
| `401 Unauthorized` | 認証切れ | `gws auth login` で再認証 |
| `403 Forbidden` | スプレッドシートへのアクセス権なし | Google Cloud Console でAPI有効化を確認、共有設定確認 |
| `404 Not Found` | シートIDまたはシート名が不正 | SHEET_ID、シート名（タブ名）を確認 |
| `429 Too Many Requests` | APIクォータ超過 | 数秒待機後にリトライ（Google Sheets API: 60リクエスト/分/ユーザー） |
| `400 Bad Request` | range指定が不正 | シート名に特殊文字がある場合はシングルクォートで囲む: `'シート名'!A1` |

### リトライパターン

```bash
# 簡易リトライ（3回まで）
for i in 1 2 3; do
  result=$(gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1' 2>&1)
  if echo "$result" | grep -q '"values"'; then
    echo "$result"
    break
  fi
  echo "Retry $i..."
  sleep $((i * 2))
done
```

---

## 7. 出力フォーマット

```bash
# JSON（デフォルト、プログラム処理向き）
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1:G5' --format json

# テーブル（人間が読む用途）
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1:G5' --format table

# CSV（エクスポート用途）
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1:G5' --format csv

# YAML
gws sheets +read --spreadsheet "$SHEET_ID" --range 'アプリ!A1:G5' --format yaml
```

---

## 8. シェル変数テンプレート

スキル利用時にコピペで使えるテンプレート:

```bash
# 定数定義
SHEET_ID="1h1MSOUuH2hx0-Q-FCFjp6ylisY9yc4Y6EAocToFXUFg"
SHEET_NAME="アプリ"
GWS="C:/Users/zooyo/.local/bin/gws.exe"

# 読み取り
$GWS sheets +read --spreadsheet "$SHEET_ID" --range "${SHEET_NAME}!A${ROW}:G${ROW}"

# 書き込み（単一セル）
$GWS sheets spreadsheets values update \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","range":"'"${SHEET_NAME}"'!A'"${ROW}"'","valueInputOption":"RAW"}' \
  --json '{"values":[["✅"]]}'

# 書き込み（一括）
$GWS sheets spreadsheets values batchUpdate \
  --params '{"spreadsheetId":"'"$SHEET_ID"'","valueInputOption":"RAW"}' \
  --json '{"data":[{"range":"'"${SHEET_NAME}"'!A'"${ROW}"'","values":[["✅"]]},{"range":"'"${SHEET_NAME}"'!D'"${ROW}"'","values":[["OK"]]}]}'
```

---

## 関連スキル

| スキル | 関連 |
|--------|------|
| `google-sheets-mcp` | Playwright UI操作による旧方式（google-sheets-api で段階的に置き換え予定） |
| `playwright` | アプリE2Eテスト用（スプレッドシート操作には使わない） |
| `checklist` | チェックリスト実行ワークフロー（将来的に本スキルを統合予定） |

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-03-05 | 初版作成。gws CLI v0.3.3 の実機コマンド体系に基づく |
