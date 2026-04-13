---
description: >
  ターミナルウィンドウ（Windows Terminal / PowerShell / cmd）を画面にタイル配置する。
  ブラウザやElectronアプリは除外。Win11不可視ボーダー補正付き。
  トリガー: "tile-terminals", "ターミナル整列", "ターミナル配置", "ウィンドウ整列",
  "タイル配置", "画面整理", "ターミナル並べて"
user_invocable: true
---

# Tile Terminals Skill

ターミナルウィンドウを自動検出し、画面のワーキングエリアにグリッド配置する。

## Script Location

`C:\Users\zooyo\scripts\tile-terminals.ps1`

## Usage

### Basic (auto layout)

```bash
powershell -ExecutionPolicy Bypass -File "$HOME/scripts/tile-terminals.ps1"
```

### Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Columns` | 0 (auto) | 列数指定。0で自動計算 |
| `-Gap` | 0 | ウィンドウ間のギャップ（px） |
| `-BorderCompensation` | 6 | Win11不可視ボーダー補正値（px） |
| `-DryRun` | false | プレビューのみ、移動しない |

### Examples

```bash
# 自動レイアウト（推奨）
powershell -ExecutionPolicy Bypass -File "$HOME/scripts/tile-terminals.ps1"

# 2列固定
powershell -ExecutionPolicy Bypass -File "$HOME/scripts/tile-terminals.ps1" -Columns 2

# プレビュー
powershell -ExecutionPolicy Bypass -File "$HOME/scripts/tile-terminals.ps1" -DryRun
```

## Behavior

1. Win32 API `EnumWindows` で全ウィンドウを列挙
2. クラス名（`CASCADIA_HOSTING_WINDOW_CLASS` 等）でターミナルを検出
3. ブラウザ/Electron（`Chrome_WidgetWin_1` 等）は除外
4. 画面ワーキングエリアにグリッド配置
5. Win11の不可視ボーダー（ドロップシャドウ）を `BorderCompensation` で補正

## When User Asks

ユーザーが「ターミナル整列して」「ウィンドウ並べて」等と言った場合:

1. 引数指定がなければそのまま実行
2. 列数やレイアウトの指定があれば `-Columns` で対応
3. 結果を報告（検出数、レイアウト）
