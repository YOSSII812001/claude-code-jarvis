---
name: Obsidian CLI Operations
description: |
  Obsidian vaultのノート読み書き・検索・タスク管理にObsidian CLIを使用。デイリーノート、ナレッジグラフ分析、プロパティ操作など。
  トリガー: "obsidian", "ノート", "vault", "デイリーノート", "ナレッジグラフ"
triggers:
  - "obsidian"
  - "vault"
  - "デイリーノート"
  - "daily note"
  - "ノート検索"
  - "ナレッジグラフ"
  - "obsidian-cli"
  - "ノートに書いて"
  - "ノートを読んで"
  - "obsidianのタスク"
use_when:
  - Obsidian vaultのノートを読み書きする
  - vault内を検索する
  - デイリーノートを操作する
  - タスクの確認・更新を行う
  - ナレッジグラフを分析する
  - ノートのプロパティやタグを操作する
---

# Obsidian CLI ガイド

## 概要
Obsidian v1.12.4+ のCLI機能を使い、Claude CodeからObsidian vaultを直接操作する。
ノートの読み書き、全文検索、デイリーノート、タスク管理、ナレッジグラフ分析が可能。
Obsidianデスクトップアプリが起動中である必要がある。

## 事前準備

**毎セッション冒頭で以下を実行すること**（Bashツールはコマンドごとに独立シェルのため）:

```bash
# エイリアスと変数を設定
alias ob='"/c/Users/zooyo/Downloads/Obsidian/Obsidian.com"'
V="vault=ytakeshita"
```

> **重要**: `ob` と `$V` は毎回のBashコマンドで再定義が必要。
> 実用上は各コマンドで直接パスを書くか、以下のパターンを使う:

```bash
# 推奨: ワンライナーで変数定義とコマンドを結合
V="vault=ytakeshita" && "/c/Users/zooyo/Downloads/Obsidian/Obsidian.com" read file="ノート名" $V
```

接続確認:
```bash
"/c/Users/zooyo/Downloads/Obsidian/Obsidian.com" version
"/c/Users/zooyo/Downloads/Obsidian/Obsidian.com" vault $V
```

## 基本原則

| 原則 | 説明 |
|------|------|
| `file=` vs `path=` | `file=` はwikilink式の名前解決（拡張子不要）。`path=` はフォルダからの正確なパス |
| `vault=` | 全コマンドに `vault=ytakeshita` を付与すること |
| `format=` | 構造的にパースする場合は `format=json` を推奨。デフォルトは `text` or `tsv` |
| 改行・タブ | content内では `\n` で改行、`\t` でタブ |
| スペース含む値 | `name="My Note"` のようにクォートする |
| アクティブファイル | `file=`/`path=` 省略時はObsidianで開いているアクティブファイルが対象 |

以降のコマンド例では `OB` を以下の略記として使用する:
```
OB = "/c/Users/zooyo/Downloads/Obsidian/Obsidian.com"
V  = vault=ytakeshita
```

---

## Tier 1: コア操作（頻出）

### ノートの読み書き

```bash
# ノートを読む
$OB read file="ノート名" $V
$OB read path="フォルダ/ノート名.md" $V

# ノートを作成
$OB create name="新規ノート" content="# タイトル\n\n本文" $V
$OB create path="フォルダ/新規ノート.md" content="内容" $V
$OB create name="テンプレ使用" template="テンプレート名" $V

# 末尾に追記（最も頻繁に使う）
$OB append file="ノート名" content="\n## 追記セクション\n内容" $V

# 先頭に追記
$OB prepend file="ノート名" content="先頭に追加する内容" $V

# ファイル一覧
$OB files $V                           # 全ファイル
$OB files folder="Projects" $V         # フォルダ絞り込み
$OB files ext=md $V                    # 拡張子絞り込み
$OB files $V total                     # ファイル数のみ
```

### 検索

```bash
# テキスト検索
$OB search query="検索ワード" $V
$OB search query="検索ワード" path="Projects" $V    # フォルダ限定
$OB search query="検索ワード" $V limit=5             # 結果数制限
$OB search query="検索ワード" $V format=json          # JSON出力
$OB search query="検索ワード" $V total                # マッチ数のみ

# コンテキスト付き検索（マッチ行の前後を表示）
$OB search:context query="検索ワード" $V
$OB search:context query="検索ワード" $V format=json
```

### デイリーノート

```bash
# 今日のデイリーノートのパスを取得
$OB daily:path $V

# デイリーノートを読む
$OB daily:read $V

# デイリーノートに追記（末尾）
$OB daily:append content="\n## メモ\n- 追記内容" $V

# デイリーノートに追記（先頭）
$OB daily:prepend content="## 朝のメモ\n- 内容" $V
```

### タスク管理

```bash
# 未完了タスク一覧
$OB tasks $V todo

# 完了タスク一覧
$OB tasks $V done

# タスク総数
$OB tasks $V total
$OB tasks $V todo total

# 特定ファイルのタスク
$OB tasks file="プロジェクト計画" $V todo

# デイリーノートのタスク
$OB tasks $V daily todo

# 詳細表示（ファイル別・行番号付き）
$OB tasks $V todo verbose

# JSON出力
$OB tasks $V todo format=json

# タスクの状態変更
$OB task file="ノート名" line=15 done $V      # 完了にする
$OB task file="ノート名" line=15 todo $V      # 未完了に戻す
$OB task file="ノート名" line=15 toggle $V    # トグル
$OB task ref="フォルダ/ノート.md:15" done $V  # ref形式
$OB task daily line=3 done $V                  # デイリーノートのタスク
```

### JavaScript実行（eval）

```bash
# vault内で任意のJavaScriptを実行
$OB eval code="app.vault.getFiles().length" $V
$OB eval code="app.workspace.getActiveFile()?.path" $V
```

---

## Tier 2: ナレッジグラフ・管理

### リンク分析

```bash
# バックリンク（このノートを参照しているノート）
$OB backlinks file="ノート名" $V
$OB backlinks file="ノート名" $V counts           # リンク数付き
$OB backlinks file="ノート名" $V format=json

# アウトゴーイングリンク（このノートが参照しているノート）
$OB links file="ノート名" $V
$OB links file="ノート名" $V total

# 孤立ノート（被リンクなし）
$OB orphans $V
$OB orphans $V total

# 未解決リンク（リンク先が存在しない）
$OB unresolved $V
$OB unresolved $V verbose                         # ソースファイル付き

# デッドエンド（発リンクなし）
$OB deadends $V
$OB deadends $V total
```

### プロパティ・タグ

```bash
# vault全体のタグ一覧
$OB tags $V
$OB tags $V counts sort=count                     # 使用回数順
$OB tags file="ノート名" $V                       # 特定ファイルのタグ

# 特定タグの詳細
$OB tag name="タグ名" $V verbose                  # ファイル一覧付き

# プロパティ一覧
$OB properties $V
$OB properties file="ノート名" $V format=json

# プロパティの読み取り・設定・削除
$OB property:read name="status" file="ノート名" $V
$OB property:set name="status" value="done" file="ノート名" $V
$OB property:set name="priority" value=1 type=number file="ノート名" $V
$OB property:remove name="obsolete" file="ノート名" $V
```

### ファイル・フォルダ管理

```bash
# ファイル情報
$OB file file="ノート名" $V

# フォルダ一覧・情報
$OB folders $V
$OB folder path="Projects" $V

# 移動（取消不可 - 注意）
$OB move file="ノート名" to="Archive/" $V

# リネーム（取消不可 - 注意）
$OB rename file="ノート名" name="新しい名前" $V

# 削除（ゴミ箱へ移動）
$OB delete file="ノート名" $V

# ファイルを開く
$OB open file="ノート名" $V
$OB open file="ノート名" $V newtab

# ワードカウント
$OB wordcount file="ノート名" $V
$OB wordcount file="ノート名" $V words             # 語数のみ
```

### ブックマーク・アウトライン

```bash
# ブックマーク一覧
$OB bookmarks $V
$OB bookmarks $V verbose format=json

# ブックマーク追加
$OB bookmark file="フォルダ/ノート.md" $V
$OB bookmark file="ノート.md" subpath="#見出し" title="お気に入り" $V

# 見出し構造（アウトライン）
$OB outline file="ノート名" $V
$OB outline file="ノート名" $V format=json
```

---

## Tier 3: クイックリファレンス

| コマンド | 説明 | 主なオプション |
|----------|------|----------------|
| `aliases` | エイリアス一覧 | `file=`, `total`, `verbose` |
| `base:create` | Base項目作成 | `file=`, `view=`, `name=`, `content=` |
| `base:query` | Baseクエリ | `file=`, `view=`, `format=json\|csv\|md` |
| `bases` | Base一覧 | - |
| `command` | Obsidianコマンド実行 | `id=<command-id>` |
| `commands` | コマンドID一覧 | `filter=<prefix>` |
| `daily` | デイリーノートを開く | `paneType=tab\|split` |
| `diff` | ローカル/Sync版差分 | `file=`, `from=`, `to=` |
| `history` | ファイル履歴一覧 | `file=` |
| `history:read` | 履歴バージョン読み取り | `file=`, `version=` |
| `history:restore` | 履歴復元 | `file=`, `version=` |
| `hotkeys` | ホットキー一覧 | `total`, `format=json` |
| `plugins` | プラグイン一覧 | `filter=core\|community`, `versions` |
| `random:read` | ランダムノート読み取り | `folder=` |
| `recents` | 最近開いたファイル | `total` |
| `reload` | vault再読み込み | - |
| `search:open` | 検索ビューを開く | `query=` |
| `snippets` | CSSスニペット一覧 | - |
| `sync:status` | Sync状態確認 | - |
| `tabs` | 開いているタブ一覧 | `ids` |
| `templates` | テンプレート一覧 | `total` |
| `template:read` | テンプレート内容読み取り | `name=`, `resolve` |
| `theme` | テーマ情報 | `name=` |
| `vault` | vault情報 | `info=name\|path\|files` |
| `vaults` | vault一覧 | `verbose` |
| `version` | Obsidianバージョン | - |
| `workspace` | ワークスペースツリー | `ids` |

---

## ユースケース集

### 1. 調査結果をノートに記録
```bash
# 既存ノートに調査メモを追記
$OB append file="調査ログ" content="\n## $(date +%Y-%m-%d) 調査結果\n\n- 発見事項1\n- 発見事項2" $V
```

### 2. プロジェクトのタスク進捗確認
```bash
# 未完了タスクを確認して報告
$OB tasks file="プロジェクト計画" $V todo verbose format=json
```

### 3. ナレッジベース分析
```bash
# 孤立ノートと未解決リンクを洗い出し
$OB orphans $V total
$OB unresolved $V verbose
```

### 4. デイリーレビュー
```bash
# 今日のデイリーノートを読み、未完了タスクを確認
$OB daily:read $V
$OB tasks $V daily todo
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `connect ECONNREFUSED` | Obsidianが起動していない | Obsidianデスクトップアプリを起動する |
| `Vault not found` | vault名が間違っている | `$OB vaults verbose` でvault名を確認 |
| `File not found` | file=の名前解決失敗 | `path=` で正確なパスを指定する |
| コマンドが見つからない | CLIバイナリのパスが違う | パス `"/c/Users/zooyo/Downloads/Obsidian/Obsidian.com"` を確認 |
| 日本語が文字化けする | エンコーディング問題 | `format=json` で出力し、別途パースする |

## 安全上の注意
- `delete` はデフォルトでゴミ箱移動（`permanent` オプションは使用しないこと）
- `move` / `rename` は取り消し不可。実行前にユーザーに確認すること
- `property:remove` は復元不可。実行前にユーザーに確認すること

## チェックリスト

- [ ] vault パスが正しいか確認したか
- [ ] プロパティのフォーマットがYAML準拠か

## 関連スキル

- **skill-improve** — スキル品質管理のナレッジベースとして活用

## 参考
- Obsidian CLI ドキュメント: Obsidian v1.12.4+ に同梱
- vault パス: `C:\Users\zooyo\Documents\Obsidian\ytakeshita`
- バイナリ: `C:\Users\zooyo\Downloads\Obsidian\Obsidian.com`
- ヘルプ: `$OB help` / `$OB help <command>`

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（トリガー追記、チェックリスト、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-20 | 初版作成 | Obsidian CLI操作の標準化 |
