# 引き継ぎ書: ウサコンチェックリスト

## 現在の状態

セクション5（ダッシュボード）とセクション6（企業管理）のチェックが**完了**。スキルファイルも実運用で発見した問題点を反映済み。次はセクション7以降のチェックに進む。

## 完了済みセクション

| セクション | 行範囲 | 項目数 | コードチェック | E2E | NG | 状態 |
|-----------|--------|--------|-------------|-----|-----|------|
| 5 ダッシュボード | 53-56 | 4 | 全OK | 実施済み | 0 | **完了** |
| 6 企業管理 | 67-78 | 12 | 全OK | 5行実施・全PASS | 0 | **完了** |

### セクション6 詳細

| 行 | 項目 | コード | E2E | G列 |
|----|------|--------|-----|-----|
| 67 | 企業登録ステップ形式 | OK | PASS | 竹下 |
| 68 | 企業登録AIインタラクティブ | OK | PASS | 竹下 |
| 69 | AIチャットアシスタント | OK | — | — |
| 70 | テンプレート選択 | OK | PASS | 竹下 |
| 71 | 自動保存機能 | OK | — | — |
| 72 | 企業詳細表示 | OK | PASS | 竹下 |
| 73 | 企業情報編集 | OK | PASS | 竹下 |
| 74 | 企業削除 | OK | — | — |
| 75-78 | 企業登録上限（4項目） | 全OK | — | — |

## 完成したファイル一覧

| ファイル | 役割 |
|---------|------|
| `~/.claude/skills/usacon-checklist/SKILL.md` | メインスキル: アプリUI構造・ワークフロー・ワーカープロンプト・Codex連携・Issue作成 |
| `~/.claude/skills/google-sheets-mcp/SKILL.md` | スプレッドシート操作スキル: refベースのセルナビゲーション・読み取り・編集パターン |
| `~/.claude/commands/checklist.md` | `/checklist` コマンド: マネージャー主導のチェックフロー定義 |

## 今回のセッションで更新したスキル（3件）

### 1. google-sheets-mcp — セル編集の信頼性向上

| セクション | 変更内容 |
|-----------|---------|
| 5. セル編集 | `type`→ JS `execCommand('insertText')` を方法A（推奨）に昇格。`type`は方法B（ASCII文字のみ）に降格 |
| 6. 絵文字チェックボックス | `type(text: "✅")` → `execCommand` に変更 |
| 8. ドロップダウン操作 | 方法B（JS execCommand）を新設し推奨に。コピペ禁止の警告追加 |
| 10. よくある問題 | 3件追加:「日本語入力不可」「コピペ規則違反」「絵文字入力不可」 |

**根本原因**: Claude in Chromeの`type`アクションはGoogle SheetsのIME処理と相性が悪く、日本語・絵文字の入力に失敗する。`document.execCommand('insertText')` はIMEを介さず直接テキストを注入するため確実。

### 2. usacon-checklist — A列・G列の条件明確化

| 箇所 | 変更内容 |
|------|---------|
| 列定義（A列） | 「テスト通過時」→「**コードチェックがOKだった時点で✅**（E2Eを待たない）」 |
| 列定義（G列） | 「チェック完了時」→「**E2Eテストを実施・完了した行のみ**担当者を選択」 |
| Phase 2 ③ OK/NG | G列設定を削除（「この時点では設定しない」に変更） |
| Phase 2 ④ E2E | E2E完了後にG列「竹下」を設定するルール追加 |

### 判定条件サマリー

| 列 | 条件 | タイミング |
|----|------|-----------|
| **A列** ✅ | コードチェック OK | Phase 2 ③（コードチェック完了直後） |
| **G列** 竹下 | E2Eテスト完了 | Phase 2 ④（E2E実施後のみ。コードチェックのみの行は空） |

## Google Sheets操作の信頼性パターン（重要）

### 日本語・絵文字の入力（最も確実な方法）

```
1. Name Boxでセルにジャンプ（click ref → type ref → Enter）
2. F2（編集モード）
3. JavaScript:
   const editor = document.querySelector('.cell-input');
   editor.focus();
   document.execCommand('selectAll', false, null);
   document.execCommand('insertText', false, '入力テキスト');
4. Enter（確定）
5. 同じセルに再ジャンプして検証（JS: document.querySelector('.cell-input').textContent）
```

### やってはいけないこと

- `type` アクションで日本語・絵文字を入力（失敗する）
- Ctrl+C / Ctrl+V でデータ入力規則セルにペースト（書式情報で規則違反エラー）

## アーキテクチャ概要

```
マネージャー（自分）
  │  スプレッドシート操作 + E2Eテスト + Issue作成
  │
  ├─ Taskツール → checker（general-purpose）: コードチェック判定（OK/NG/UNSURE）
  │
  └─ Taskツール → Bash: Codex CLI セカンドオピニオン（UNSURE時のみ）
```

## テスト実行方法

```
/checklist 7    ← セクション7のみチェック
/checklist      ← 未チェック項目を先頭から順にチェック
```

## テスト環境

| 項目 | 値 |
|------|-----|
| スプレッドシート | https://docs.google.com/spreadsheets/d/1h1MSOUuH2hx0-Q-FCFjp6ylisY9yc4Y6EAocToFXUFg/edit |
| プレビューサイト | https://preview.usacon-ai.com |
| 対象シート | 「アプリ」シートのみ（「管理画面」は対象外） |
| リポジトリ | C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app |
| GitHub | Robbits-CO-LTD/digital-management-consulting-app（Issue作成先） |

### テストアカウント（プラン別）

| プラン | メールアドレス | パスワード | 備考 |
|--------|--------------|-----------|------|
| 無料（free） | takeshitaseigyo@gmail.com | Password12345 | |
| スタンダード（standard） | zooyork812001@gmail.com | password123 | 初回Supabaseでプラン変更要 |
| プロフェッショナル（professional） | ytakeshita@robbits.co.jp | password123 | デフォルト |

## 既知のリスク

- **Codex CLI (`codex exec`)** が未インストールまたは認証切れの場合 → マネージャー独自判定にフォールバック
- **gh CLI** の認証切れ → F列に「Issue未作成」記録
- **Google Sheets** のセッション切れ → ページリロードでリカバリ
- **Claude in Chrome `type`** の日本語入力 → JS execCommand方式で回避済み（スキルに反映済み）
