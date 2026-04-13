---
name: google-sheets-mcp
description: Google Sheets を playwright-cli で操作するための専用スキル。セルナビゲーション、値の読み取り、編集、シートタブ切替など、refベースの信頼性の高い操作パターンを提供する。
---

# Google Sheets 操作スキル（playwright-cli）

## 1. 概要と制約

Google Sheets を `playwright-cli`（Bash経由のCLIツール）で操作するためのスキル。
すべての操作は `Bash` ツールで `playwright-cli <command>` を実行する。

### 制約事項

| 制約 | 理由 | 代替手段 |
|------|------|---------|
| refは毎回変わる | DOMが動的に再構築される | **操作前に必ず `snapshot` で最新refを取得** |
| 座標ベースのクリックは非推奨 | ウィンドウサイズ・スクロールで座標がずれる | refベースで操作 |
| ナビゲーション・DOM更新後はrefが無効化 | Playwrightの仕様 | **操作後は必ず `snapshot` を再実行** |

### タブ管理

複数タブ（スプレッドシート＋アプリ等）を使う場合は、タブを切り替えてから操作する。

```bash
playwright-cli tab-list           # タブ一覧取得（インデックス確認）
playwright-cli tab-select 0       # タブ切替（インデックス指定）
playwright-cli tab-new <url>      # 新規タブ作成
playwright-cli tab-close [index]  # タブを閉じる
```

---

## 2. 要素の特定方法

### `snapshot` で取得できる主要要素

| 要素 | 識別方法 |
|------|---------|
| **Name Box** | `textbox` で値がセル参照形式のもの（例: "A7", "B12", "C1"） |
| **数式バー** | Name Box直後の名前なし `textbox` |
| **シートタブ** | 下部のボタン群。シート名テキストを含む |

### ref特定の手順

```bash
playwright-cli snapshot    # ページ構造を取得 → ref値（e1, e2, ...）が表示される
```

1. **Name Box**: snapshot結果のtextbox一覧から、値が `[A-Z]+[0-9]+` パターンのものを探す
2. **数式バー**: Name Boxの直後に出現するtextbox
3. **シートタブ**: snapshot結果の下部にあるbutton群からシート名テキストを含むものを特定

---

## 3. セルナビゲーション

Name Boxにセル参照を入力してジャンプする方法。最も確実。

```bash
# 手順:
# 1. snapshot でName Boxのrefを特定
playwright-cli snapshot

# 2. Name Boxをクリック（例: Name Boxが e56 の場合）
playwright-cli click e56

# 3. Name Boxにセル参照を入力
playwright-cli fill e56 "B6"
#    ※ fill は ref を指定してフィールドに直接入力する。type より確実。

# 4. Enterで確定・ジャンプ
playwright-cli press Enter

# 5. スクリーンショットで正しいセルが選択されたことを確認
playwright-cli screenshot
```

**重要: `fill` を使い、ref を指定する。** `click` でName Boxをクリック後に `type` でref無しで入力すると、フォーカスが別の要素に移る可能性がある。`fill e{ref} "セル参照"` なら確実にName Boxに入力される。

---

## 4. セル値の読み取り

### 方法A（推奨）: JavaScript

セルを選択した状態で、数式バーの内容をJavaScriptで読み取る。

```bash
playwright-cli eval "(() => { const fb = document.querySelector('.cell-input'); const text = fb.textContent; const codes = [...text].map(c => 'U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')); return JSON.stringify({ text, codes }); })()"
```

- `text`: セルの表示テキスト
- `codes`: 各文字のUnicodeコードポイント（絵文字の判別に有用）

### 方法B: screenshot

対象行エリアをスクリーンショットで撮影して目視読み取り。複数列を一度に読みたい場合に有効。

```bash
# 1. セルナビゲーション（セクション3）で対象行に移動
# 2. スクリーンショットで行全体を撮影
playwright-cli screenshot
```

---

## 5. セル編集（書き込み）

### 方法A（推奨）: JavaScript execCommand

**`type` は日本語・絵文字・Unicode文字の入力に失敗することがある。** Google SheetsのIME処理との相性問題により、`type` で入力しても空セルになるケースが頻発する。**JavaScript の `execCommand('insertText')` を使うのが最も確実。**

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セルを選択
# 2. F2で編集モードに入る
playwright-cli press F2

# 3. eval で execCommand を実行
playwright-cli eval "(() => { const editor = document.querySelector('.cell-input'); editor.focus(); document.execCommand('selectAll', false, null); document.execCommand('insertText', false, '新しい内容'); return 'done'; })()"

# 4. Enterで確定
playwright-cli press Enter

# 5. 同じセルに再ジャンプして検証（Enter後カーソルが下に移動するため）
playwright-cli click e56
playwright-cli fill e56 "A84"
playwright-cli press Enter

# 6. 値が正しく入ったことを検証
playwright-cli eval "document.querySelector('.cell-input').textContent"
```

**重要**: `execCommand('insertText')` は `type` と異なり、Google Sheetsの内部エディタ（contentEditable DIV）に直接テキストを挿入する。IMEの問題を回避でき、日本語・絵文字・特殊文字も確実に入力できる。

### 方法B: type（ASCII文字のみ推奨）

半角英数字や記号（例: "NG", "OK", "#123"）の入力には `type` も使用可能。

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セルを選択
# 2. F2で編集モードに入る
playwright-cli press F2

# 3. Ctrl+Aで既存内容を全選択
playwright-cli press Control+a

# 4. テキスト入力（現在フォーカスされている要素に入力）
playwright-cli type "NG"

# 5. Enterで確定
playwright-cli press Enter

# 6. スクリーンショットで入力結果を確認
playwright-cli screenshot
```

**注意**:
- **日本語・絵文字・Unicode文字には方法Aを使うこと**（`type` は失敗する可能性が高い）
- 編集中にEscを押すとキャンセルされる。必ずEnterで確定すること
- 編集中に別セルをクリックすると意図しない場所に入力されることがある

### 隣接セルへの連続入力

D列→E列のように隣接セルに連続で書き込む場合のパターン。

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で D{行番号} を選択
# 2. F2で編集モード
playwright-cli press F2

# 3. Ctrl+Aで全選択
playwright-cli press Control+a

# 4. テキスト入力
playwright-cli type "NG"

# 5. Tabで確定して右のE列へ移動
playwright-cli press Tab

# 6. テキスト入力
playwright-cli type "原因テキスト"

# 7. Enterで確定
playwright-cli press Enter
```

**注意**: TabキーはEnterと同様にセルを確定するが、移動方向が右（次の列）になる。

### セルのクリア（内容削除）

既存のセル内容を空にする場合。

```bash
# 1. セルナビゲーション（セクション3）で対象セルを選択
# 2. Deleteで内容をクリア（編集モードに入る必要なし）
playwright-cli press Delete
```

---

## 6. 絵文字チェックボックス操作

絵文字でチェック状態を管理しているセルの書き換えパターン。標準チェックボックス（TRUE/FALSE）とは異なる。

| 状態 | 絵文字例 | Unicode例 |
|------|---------|----------|
| 未チェック | ⬜ | U+2B1C (White Large Square) |
| チェック済み | ✅ | U+2705 (White Heavy Check Mark) |

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セルにジャンプ
# 2. F2で編集モードに入る
playwright-cli press F2

# 3. eval で絵文字を入力（セクション5 方法A参照）
playwright-cli eval "(() => { const editor = document.querySelector('.cell-input'); editor.focus(); document.execCommand('selectAll', false, null); document.execCommand('insertText', false, '✅'); return 'done'; })()"

# 4. Enterで確定
playwright-cli press Enter

# 5. 同じセルに再ジャンプして検証（Enter確定後カーソルが1行下に移動するため）
# 6. eval で値が期待通りになったことを検証
```

**重要**: 絵文字（✅、⬜等）の入力には **必ず eval + execCommand方式を使うこと**。`type` では絵文字が正しく入力されないことがある。

検証用JavaScript:
```bash
playwright-cli eval "(() => { const fb = document.querySelector('.cell-input'); const text = fb.textContent; const codes = [...text].map(c => 'U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')); return JSON.stringify({ text, codes, isChecked: codes.includes('U+2705') }); })()"
```

---

## 7. シートタブ切替

```bash
# 手順:
# 1. snapshot で下部ボタン群を確認
playwright-cli snapshot

# 2. 目的のシート名（例: "アプリ", "管理画面"）を含むボタンのrefを特定
# 3. クリック
playwright-cli click e{sheetTabRef}

# 4. スクリーンショットでシートが切り替わったことを確認
playwright-cli screenshot
```

**ヒント**: シートタブはページ下部に横並びで表示される。通常は `snapshot` の結果の後方にリストされる。

---

## 8. データ入力規則ドロップダウン操作

データ入力規則（Data Validation）で設定されたドロップダウンセルの値を選択する方法。

### 方法A（推奨）: ドロップダウンUIから選択

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セル（例: G{行番号}）にジャンプ
# 2. セル右端のドロップダウン矢印（▼）をクリック
#    ※ 矢印はセル選択時に出現する。セル右端の座標をクリック
# 3. ドロップダウンリストが表示される
# 4. 目的の選択肢（例: "竹下"）をクリック
# 5. Escape でドロップダウンを閉じる（自動で閉じない場合）
playwright-cli press Escape
# 6. スクリーンショットで値が入ったことを確認
playwright-cli screenshot
```

### 方法B（推奨）: JavaScript execCommand で直接入力

データ入力規則のセルに値を入力する最も確実な方法。`type` の日本語入力問題を回避できる。

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セルにジャンプ
# 2. F2で編集モードに入る
playwright-cli press F2

# 3. eval で値を入力
playwright-cli eval "(() => { const editor = document.querySelector('.cell-input'); editor.focus(); document.execCommand('selectAll', false, null); document.execCommand('insertText', false, '竹下'); return 'done'; })()"

# 4. Enterで確定
playwright-cli press Enter

# 5. 同じセルに再ジャンプして検証
# 6. eval で値が正しく入ったことを検証
playwright-cli eval "document.querySelector('.cell-input').textContent"
```

**注意**: データ入力規則が「拒否」モードでも、選択肢に含まれる正確な値であれば入力が受け入れられる。

### 方法C: type（ASCII文字のみ）

データ入力規則の選択肢が半角英数字のみの場合に使用可能。

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で対象セルにジャンプ
# 2. F2で編集モード
playwright-cli press F2
# 3. Ctrl+Aで全選択
playwright-cli press Control+a
# 4. テキスト入力
playwright-cli type "OK"
# 5. Enterで確定
playwright-cli press Enter
```

**注意**: 日本語の選択肢（例: 「竹下」「清水」）には方法Bを使うこと。`type` では入力に失敗する。

### コピー＆ペーストは使用禁止

**データ入力規則のあるセルに Ctrl+C / Ctrl+V でコピペすると、書式情報が含まれてデータ入力規則違反エラーになる。** テキスト値が選択肢と一致していてもエラーになるため、必ず方法A（ドロップダウンUI）または方法B（JavaScript）で入力すること。

---

## 9. 行データの一括読み取り（テストループ用）

テスト実行時に1行分のデータ（B〜F列）をまとめて読み取るパターン。

```bash
# 手順:
# 1. セルナビゲーション（セクション3）で A{行番号} にジャンプ
# 2. スクリーンショットで行全体を撮影
playwright-cli screenshot

# 3. 必要に応じて eval で A列の値（⬜/✅）を確認
playwright-cli eval "(() => { const fb = document.querySelector('.cell-input'); const text = fb.textContent; const codes = [...text].map(c => 'U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')); return JSON.stringify({ text, isChecked: codes.includes('U+2705'), isUnchecked: codes.includes('U+2B1C') }); })()"
```

---

## 10. よくある問題と対策

| 問題 | 原因 | 対策 |
|------|------|------|
| Name Box座標ズレ | ウィンドウサイズ変動 | refベースで操作（セクション3） |
| A列全体選択 | 列ヘッダー「A」をクリックしてしまった | snapshot で Name Box の ref を確認してから操作 |
| 数式バーが空 | 別セル選択中、またはセル未選択 | Name Boxナビ後にJSで確認 |
| refが無効（stale） | DOM変更後に古いrefを使用 | **操作後は必ず `snapshot` を再実行してrefを更新** |
| 編集が反映されない | Escで確定せずにキャンセル | 必ずEnterで確定 |
| シートタブの特定失敗 | refが動的に変わる | 毎回 snapshot で再取得 |
| 入力した文字が違うセルに入る | 編集モード中に別セルをクリック | Enter確定後に次の操作へ |
| Name Boxに入力したのに別セルに飛ぶ | `type` でフォーカスが移動 | **`fill e{ref} "セル参照"` を使用する** |
| `type` で日本語が入力できない | Google SheetsのIME処理と `type` の相性問題 | **`eval` + `execCommand('insertText')` を使う**（セクション5 方法A） |
| コピペでデータ入力規則エラー | Ctrl+C/Vは書式情報を含み、データ入力規則と衝突 | **コピペ禁止。JavaScript方式で入力する**（セクション8 方法B） |
| 絵文字（✅等）が入力できない | `type` のUnicode処理制限 | **`eval` + `execCommand('insertText')` を使う**（セクション6） |
| **同一列の連続入力で別セルに入力される** | Enter確定後カーソルは次行の同列に移動済みなのに、Name Boxで再ジャンプしようとしてフォーカスが外れる | **同一列の連続入力にはName Boxを使わない。Enter確定→そのままF2→入力→Enterの繰り返し**（セクション12参照） |
| **ログイン後に意図しないボタンをクリック** | ログイン前後でrefが全変更される | **ログイン後は必ずsnapshot/screenshotを再取得してrefを更新**（セクション14.2参照） |
| **Ctrl+Aでシート全体が上書きされる** | セルが編集モードでない時にCtrl+Aを押すとシート全体が選択される | **Ctrl+Aの前に必ずF2で編集モードに入る。より安全にはDelete→F2→execCommandの手順を使う**（セクション14.3, 14.4参照） |
| **Playwright MCPで編集できない（閲覧のみ）** | MCPプラグインは新規セッションで起動し、Googleにログインしていない | **スプレッドシートを開いた後にGoogleアカウントでログインする**（セクション14.1参照） |

---

## 11. キーボードショートカット一覧

| ショートカット | 動作 | playwright-cli コマンド |
|--------------|------|----------------------|
| F2 | セル編集モード | `press F2` |
| Escape | 編集キャンセル | `press Escape` |
| Enter | 確定して下へ移動 | `press Enter` |
| Tab | 確定して右へ移動 | `press Tab` |
| Ctrl+A | 全選択（編集モード内） | `press Control+a` |
| Ctrl+Z | 元に戻す | `press Control+z` |
| Delete | セル内容削除 | `press Delete` |

---

## 12. 同一列の連続入力パターン（重要）

同じ列の複数行に同じ値を入力する場合（例: G84〜G86に「竹下」）、**Name Boxでの行ごとのジャンプは使わない**。

### 問題: Enter確定後に不要なName Boxジャンプで誤入力

```
❌ 危険なパターン:
G84にジャンプ → F2 → 入力 → Enter確定
→ カーソルはG85に自動移動している
→ Name Boxで「G85」にジャンプしようとする ← 不要！
→ Name Boxのフォーカスが外れ、A列に文字列が入力される
```

### 正しいパターン: Enter連鎖

```bash
# ✅ 安全なパターン:

# 1. Name Boxで最初のセル（G84）にジャンプ
playwright-cli click e{nameBoxRef}
playwright-cli fill e{nameBoxRef} "G84"
playwright-cli press Enter

# 2. F2 → execCommand → Enter → カーソルがG85に自動移動
playwright-cli press F2
playwright-cli eval "(() => { const e=document.querySelector('.cell-input');e.focus();document.execCommand('selectAll',false,null);document.execCommand('insertText',false,'竹下');return 'done'; })()"
playwright-cli press Enter

# 3. そのまま F2 → execCommand → Enter → カーソルがG86に自動移動
playwright-cli press F2
playwright-cli eval "(() => { const e=document.querySelector('.cell-input');e.focus();document.execCommand('selectAll',false,null);document.execCommand('insertText',false,'竹下');return 'done'; })()"
playwright-cli press Enter

# 4. そのまま F2 → execCommand → Enter
playwright-cli press F2
playwright-cli eval "(() => { const e=document.querySelector('.cell-input');e.focus();document.execCommand('selectAll',false,null);document.execCommand('insertText',false,'竹下');return 'done'; })()"
playwright-cli press Enter

# 5. 最初のセル（G84）に戻って検証
playwright-cli click e{nameBoxRef}
playwright-cli fill e{nameBoxRef} "G84"
playwright-cli press Enter
playwright-cli eval "document.querySelector('.cell-input').textContent"
```

**ルール**:
- **Name Boxを使うのは最初の1回だけ**。以降はEnter確定の自動移動を活用する
- Enter確定後は**必ず同じ列の次行**にカーソルが移動する（A列→A列+1行、G列→G列+1行）
- 列をまたぐ操作（A列→G列）ではName Boxジャンプが必要
- 連続入力完了後、最初のセルに戻って検証すること

---

## 13. Claude-in-Chrome (javascript_tool) によるセル編集

Claude-in-Chrome MCP の `javascript_tool` を使ったセル編集パターン。Playwright MCP が使えない場合（ユーザーがGoogleにログイン済みのChromeブラウザを使う必要がある場合）に使用する。

### 基本パターン（1セル編集）

```
# 1. Name Box (ref_101) をクリックしてセルアドレス入力
left_click ref_101
form_input ref_101 "A10"
key "Enter F2"   ← ナビゲート＋編集モード

# 2. javascript_tool で値を挿入
javascript_tool:
  (() => {
    const e = document.querySelector('.cell-input');
    e.focus();
    document.execCommand('selectAll', false, null);
    document.execCommand('insertText', false, '✅');
    return 'done';
  })()

# 3. 確定
key "Enter"
```

### 連続行の編集（セクション12のルールと同じ）

Name Boxナビゲートは最初の1回だけ。以降はEnter確定の自動下移動を活用する。

```
# 最初の行: Name Boxでナビゲート
left_click ref_101
form_input ref_101 "A10"
key "Enter F2"
javascript_tool: (✅挿入)

# 2行目以降: Enter + F2 の連続キー
key "Enter F2"     ← 確定＋次セル編集モード
javascript_tool: (✅挿入)
key "Enter F2"     ← 繰り返し
javascript_tool: (✅挿入)

# 最終行
javascript_tool: (✅挿入)
key "Enter"        ← 確定のみ（次グループはName Boxで移動）
```

### グループ間の移動

非連続行（ギャップがある場合）は、グループの最後でEnter確定後、再度Name Boxでナビゲートする。

```
# グループ1完了後 → グループ2へ
key "Enter"                    ← 最終行確定
left_click ref_101             ← Name Box
form_input ref_101 "A88"       ← 次グループの先頭行
key "Enter F2"                 ← ナビゲート＋編集モード
javascript_tool: (✅挿入)      ← 編集開始
```

### 注意事項

- `document.execCommand` は Google Sheets の内部入力フィールド (`.cell-input`) に対して使う
- `selectAll` で既存値を全選択してから `insertText` で上書きする
- 非同期バッチ処理（async/await + setTimeout）は Chrome 拡張との接続切断を引き起こすため使用禁止
- 1セルにつき1回の javascript_tool 呼び出しが安定動作する

---

## 14. Playwright MCPプラグイン固有のパターン（重要）

`playwright-cli`（Bash CLI）ではなく、Playwright MCPプラグイン（`mcp__plugin_playwright_playwright__*`ツール）を使う場合の注意点。APIが異なるため、CLI前提の手順をそのまま適用できない。

### 14.1 ログインと編集権限

**Playwright MCPプラグインは毎回新しいブラウザセッションで起動するため、Googleにログインしていない。**

| 状態 | 操作可能範囲 |
|------|------------|
| **未ログイン** | 閲覧のみ（「閲覧のみ」モード）。セル編集不可 |
| **ログイン済** | 完全編集可能 |

**対策**:
1. スプレッドシートを開いた後、「ログイン」リンクをクリックしてGoogleアカウントでログイン
2. または、ユーザーにPlaywrightブラウザ上で手動ログインを依頼する

### 14.2 ログイン後のref全変更（致命的な罠）

**ログイン前後でDOMが完全に再構築され、全refが変わる。**

```
ログイン前: Name Box = e105, 印刷ボタン = e69
ログイン後: Name Box = e283, 印刷ボタン = e823  ← 全く別の番号
```

**対策**: ログイン後は**必ずsnapshot（またはスクリーンショット）を再取得**し、新しいrefを確認してから操作する。古いrefを使うと**意図しない要素（印刷ボタン等）をクリックする事故が発生する。**

### 14.3 Ctrl+Aの危険性（シート全体選択の罠）

**Google Sheetsでは、Ctrl+Aの動作がコンテキストによって異なる：**

| 状態 | Ctrl+Aの動作 | 結果 |
|------|------------|------|
| **セル選択状態（非編集）** | **シート全体を選択** | 全セルが選択され、次の入力で全セルが上書きされる **← 致命的** |
| **セル編集モード（F2後）** | セル内テキストを全選択 | 安全。セル内容のみが選択される |

**事故パターン**:
```
❌ 危険: セル選択 → Ctrl+A → execCommand('insertText', '✅')
   → シート全体が選択され、全セルに ✅ が入力される（元に戻すのにCtrl+Z連打が必要）

✅ 安全: セル選択 → F2（編集モード） → Ctrl+A → execCommand
   → セル内テキストのみが選択・置換される
```

### 14.4 MCPプラグインでの安全なセル編集手順

**推奨手順（Delete → F2 → execCommand → Enter）:**

```
1. Name Boxでセルに移動
   browser_click(ref=名前ボックスref)
   browser_type(ref=名前ボックスref, text="A136", submit=true)

2. Deleteでセル内容をクリア（セル選択状態のまま安全に実行可能）
   browser_press_key(key="Delete")

3. F2で編集モードに入る
   browser_press_key(key="F2")

4. execCommandで値を挿入（Ctrl+Aは不要！Delete済みなのでセルは空）
   browser_evaluate(function="() => { document.execCommand('insertText', false, '✅'); }")

5. Enterで確定（カーソルが次行に自動移動）
   browser_press_key(key="Enter")

6. 連続行は手順2-5を繰り返す（Name Boxは最初の1回だけ）
```

**この手順のポイント**:
- `Delete` でセル内容を先にクリアするため、`Ctrl+A`（全選択）が不要
- `F2` で確実に編集モードに入ってから `execCommand` を実行
- `.cell-input` セレクタの指定は不要（`F2`後はアクティブ要素が編集フィールドなので `document.execCommand` だけで動く）

### 14.5 MCPプラグインでのName Box操作

```
# Name Boxのクリックとセルジャンプ
browser_click(element="名前ボックス", ref={nameBoxRef})
browser_type(ref={nameBoxRef}, text="A136", submit=true)

# ⚠️ 注意: browser_type の ref に Name Box の ref を指定すると、
#    Playwright は fill + Enter を実行する。
#    セル内容を入力したい場合は Name Box の ref を使わないこと！
```

### 14.6 MCPプラグインでのツール対応表

| playwright-cli コマンド | MCPプラグイン ツール |
|----------------------|-------------------|
| `playwright-cli snapshot` | `browser_snapshot` |
| `playwright-cli screenshot` | `browser_take_screenshot` |
| `playwright-cli click e{ref}` | `browser_click(ref=e{ref})` |
| `playwright-cli fill e{ref} "text"` | `browser_type(ref=e{ref}, text="text")` |
| `playwright-cli press Enter` | `browser_press_key(key="Enter")` |
| `playwright-cli press F2` | `browser_press_key(key="F2")` |
| `playwright-cli eval "js"` | `browser_evaluate(function="js")` |
| `playwright-cli tab-list` | `browser_tabs` |
| `playwright-cli navigate <url>` | `browser_navigate(url="<url>")` |

## 関連スキル

| スキル | 関連 |
|--------|------|
| `playwright` | ブラウザ自動操作基盤（MCPプラグイン） |
| `claude-for-chrome` | Chrome拡張経由でのブラウザ操作（javascript_tool使用時） |

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2025-11 | 初版作成 | Google Sheets操作パターンの標準化 |
| 2026-01 | セクション12（同一列連続入力パターン）追加 | Enter確定後のName Box誤操作事故防止 |
| 2026-02 | セクション13（Claude-in-Chrome javascript_tool）追加 | Chrome拡張経由の操作パターン追加 |
| 2026-02 | セクション14（Playwright MCPプラグイン固有パターン）追加 | MCPプラグインのAPI差異・ログイン・Ctrl+A罠の文書化 |
| 2026-03-04 | 関連スキル・改訂履歴を追加 | スキル品質改善 |
| 2026-03-18 | トリガーワード・トラブルシューティング見出し・チェックリスト追加 | skill-improve audit対応 |

**トリガー:** `google-sheets-mcp`, `Google Sheets`, `スプレッドシート操作`, `シート編集`, `playwright-cli sheets`

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| セルが選択できない | Name Boxへのクリック→座標入力→Enter で確実にナビゲーション |
| 値の入力が反映されない | Enter確定後にセルを再読み取りして値を検証 |
| シートタブが切り替わらない | タブ名が正確か確認。URLのgid値で直接アクセスも可 |
| Googleログインが必要 | `playwright-cli storage load` で保存済みセッションを復元 |

## 操作チェックリスト

- [ ] 操作前にスプレッドシートURLとシート名を確認したか
- [ ] セル参照（A1形式）が正しいか
- [ ] 値入力後にEnter確定したか
- [ ] 操作結果をスナップショットで検証したか
