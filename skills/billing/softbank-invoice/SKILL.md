---
name: softbank-invoice
description: |
  ソフトバンク携帯（社用）の請求書/領収書をMySoftBankからClaude for Chrome経由でダウンロードする。
  毎月の経理業務を半自動化。SMS 2FA（3桁セキュリティ番号）はユーザー確認が必要。
  トリガー: "ソフトバンク請求書", "softbank invoice", "SB請求書", "携帯請求書",
  "ソフトバンク領収書", "SB領収書", "softbank receipt"
triggers:
  - "ソフトバンク請求書"
  - "softbank invoice"
  - "SB請求書"
  - "携帯請求書"
  - "ソフトバンク領収書"
  - "SB領収書"
  - "softbank receipt"
  - "softbank-invoice"
use_when:
  - ソフトバンク携帯の請求書・領収書をダウンロードする
  - 毎月の携帯料金の明細を取得する
  - 経理用の携帯請求書PDFを取得する
allowed-tools: Read, AskUserQuestion
---

# ソフトバンク請求書ダウンロードスキル

## 概要
MySoftBank（https://www.softbank.jp/mysoftbank/）にログインし、
請求明細PDFをダウンロードする半自動化スキル。

- **実行方法**: Claude for Chrome（ブラウザ拡張機能）
- **認証方式**: SoftBank ID + パスワード + SMS 2FA（3桁セキュリティ番号）
- **認証情報ソース**: Obsidian Vault（ノートから読み取り）
- **出力先**: Chromeの標準ダウンロードフォルダ → ユーザーが経理フォルダへ移動

## なぜClaude for Chromeか
- ユーザーの実ブラウザ上で動作し、操作内容を目視確認できる
- 2FA（SMS）をユーザーが直接入力でき、認証フローが自然
- Playwrightと違い、認証情報がプログラム経由で渡されない（セキュリティ面で安全）
- 月次スケジュールタスクで定期実行も可能

## 認証情報

認証情報は以下のObsidianノートに記載:
```
C:/Users/zooyo/Documents/Obsidian Vault/株式会社Robbits/経理/ソフトバンク（社長携帯）請求書.md
```
**スキルファイルやログに認証情報をハードコードしない。**

## 実行手順

### Step 1: Claude Codeでの準備
1. Obsidianノートから認証情報（SoftBank ID、パスワード）を読み取る
2. 対象月を確定する（引数 or デフォルト=前月）
3. Claude for Chrome用のプロンプトを生成してユーザーに提示

### Step 2: ユーザーがClaude for Chromeで実行
ユーザーがChromeのサイドパネルで以下のプロンプトを実行する。

### Step 3: ダウンロード完了確認
ダウンロードされたPDFの確認とリネーム（必要に応じて）。

## Claude for Chrome プロンプトテンプレート

以下をClaude for Chromeのサイドパネルに貼り付けて実行:

```
MySoftBankから請求書PDFをダウンロードしてください。

【手順】
1. https://www.softbank.jp/mysoftbank/ にアクセス
2. ログイン画面で以下を入力:
   - SoftBank ID: {{SOFTBANK_ID}}
   - パスワード: {{PASSWORD}}
3. ログイン後、上部タブの「料金・支払い管理」をクリック
4. 下の方にある「請求明細の印刷（ダウンロード）」をクリック
5. 「請求明細を確認する」をクリック
6. 「書面発行（請求書/内訳明細書）」を選択
7. 「自分で印刷する（無料）」をクリック
8. 携帯にセキュリティ番号（3桁）が届くので、私が入力します。入力を待ってください
9. セキュリティ番号入力後、以下の各月の請求書PDFをダウンロード:
   {{TARGET_MONTHS}}
   - 「照会月変更」で月を切り替えてそれぞれダウンロード

注意: 各ステップでページの読み込みを待ってから次に進んでください。
```

## プロンプト生成ルール
- `{{SOFTBANK_ID}}` → Obsidianノートから読み取ったSoftBank ID
- `{{PASSWORD}}` → Obsidianノートから読み取ったパスワード
- `{{TARGET_MONTHS}}` → 引数から生成（例: "- 2026年1月分\n- 2026年2月分\n- 2026年3月分"）

## 保存先（推奨リネーム）
ダウンロード後、以下にリネーム・移動を推奨:
```
C:/Users/zooyo/Documents/Obsidian Vault/株式会社Robbits/経理/請求書/ソフトバンク/
  ソフトバンク_請求書_2026年01月.pdf
  ソフトバンク_請求書_2026年02月.pdf
  ...
```

## 月次スケジュール設定（オプション）
Claude for Chromeの「スケジュールタスク」機能で月次自動実行が可能:
1. Chrome拡張パネル右上の時計アイコン
2. 頻度: 月次（毎月5日頃 = 請求書確定後）
3. プロンプト: 上記テンプレートの先月分を自動指定

## 引数
- **月指定**: `$ARGUMENTS` で対象月を指定（例: "2026年1月" "2026年1月〜3月" "先月"）
- 指定なしの場合は前月分をデフォルトとする

## 注意事項
- MySoftBankのUI変更でナビゲーションが変わる可能性あり（その場合はスキル更新）
- セキュリティ番号は発行から一定時間で無効になる。速やかに入力すること
- セッションタイムアウト（約10分）に注意
- Claude for Chromeの「Ask before acting」モードを推奨（機密情報入力時に確認が入る）
