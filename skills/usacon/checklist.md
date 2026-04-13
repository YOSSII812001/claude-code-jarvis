# ウサコン チェックリスト（親スキル）

## 概要

Google スプレッドシートのチェックシートを正の情報源として、テスト項目を1行ずつ検査するスキル。
機能を2つの子スキルに分離し、引数に応じてルーティングする。

### スキル構成

| スキル | 責務 |
|--------|------|
| **本ファイル**（checklist.md） | 共通定義 + コマンド分岐 + Phase 1/3 + GitHub Issue作成 |
| [references/checklist-code.md](references/checklist-code.md) | コードチェック専用（A列✅操作、Codexエスカレーション） |
| [references/checklist-e2e.md](references/checklist-e2e.md) | E2Eテスト専用（D列結果 + G列担当者、ブラウザ操作） |
| [references/app-knowledge.md](references/app-knowledge.md) | アプリUI構造・操作ガイド（E2Eスキルから参照） |

### コマンド体系

| 入力 | mode | 動作 |
|------|------|------|
| `/checklist code 7` | code | コードチェックのみ |
| `/checklist e2e 7` | e2e | E2Eテストのみ |
| `/checklist 7` | both | 両方順次実行（後方互換） |

---

## 対象環境

| 項目 | 値 |
|------|-----|
| **テスト先** | https://preview.usacon-ai.com |
| **スプレッドシート** | https://docs.google.com/spreadsheets/d/1h1MSOUuH2hx0-Q-FCFjp6ylisY9yc4Y6EAocToFXUFg/edit |
| **対象シート** | 「アプリ」シートのみ（「管理画面」シートは対象外） |
| **リポジトリ** | C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app |
| **GitHub** | Robbits-CO-LTD/digital-management-consulting-app |

### テストアカウント（プラン別）

テスト項目が対象とするプランに応じてアカウントを使い分ける。チェックシートのF列（備考）やC列（テスト方法）にプラン指定がある場合はそれに従う。指定がなければプロフェッショナルプランを使用する。

| プラン | メールアドレス | パスワード | 備考 |
|--------|--------------|-----------|------|
| **無料（free）** | takeshitaseigyo@gmail.com | Password12345 | 無料プラン制限のテストに使用 |
| **スタンダード（standard）** | robbits.develop@gmail.com | Robbits2025! | DB直接変更でスタンダードプラン設定済み |
| **プロフェッショナル（professional）** | ytakeshita@robbits.co.jp | password123 | デフォルトのテストアカウント |

### Supabaseでのプラン変更手順

テストアカウントのプランをDB直接変更する場合の手順。REST API経由で実行（Docker不要）。

**DB構造**: profiles → memberships → organizations → billing.customers → billing.subscriptions

**更新対象テーブル（3つ）:**
1. `billing.subscriptions` — `plan_code`, `monthly_credit_quota`
2. `billing.credit_balances` — `credits_remaining`
3. `organizations` — `plan`

**注意**: DB直接変更のため、Stripe側のサブスクリプションは変更されない。Stripe連携テストにはこのアカウントを使わないこと。ブラウザ側の `accountMenuData` キャッシュ（localStorage、5分TTL）をクリアしないとUI反映が遅延する。

---

## スプレッドシート列定義

| 列 | ヘッダー | 用途 |
|----|---------|------|
| A | コードチェック | 絵文字で管理。⬜=未チェック、✅=チェック済み。**コードチェックがOKだった時点で✅に書き換え**（E2Eテストの完了を待たない） |
| B | 内容 | テスト項目名 |
| C | テスト方法 | 具体的なテスト操作手順 |
| D | 結果 | 失敗時に「NG」を記入 |
| E | 原因 | 失敗時に簡潔な原因を記入 |
| F | 備考 | 前提条件や補足情報 |
| G | 担当者 | データ入力規則ドロップダウン（選択肢: 清水, 藤田, 竹下, 田端）。**E2Eテストを実施・完了した行のみ**担当者を選択。コードチェックのみの行（E2E不要）はG列を空のままにする |

**セクション行の見分け方**: B列にセクション番号とタイトルが水色背景で表示される行（例: 「1 認証機能」「6 企業管理」）。これらの行はテスト項目ではなくヘッダー。

---

## コマンド分岐ロジック

引数を解析し、適切な子スキルを実行する。

### 引数解析

```
入力: /checklist [mode] [section]

パターン:
  /checklist code 7    → mode=code,  section=7
  /checklist e2e 7     → mode=e2e,   section=7
  /checklist 7         → mode=both,  section=7
  /checklist code      → mode=code,  section=全セクション
  /checklist e2e       → mode=e2e,   section=全セクション
  /checklist           → mode=both,  section=全セクション
```

### 実行フロー

```
1. 引数を解析して mode と section を決定

2. Phase 1: 共通環境準備を実行（下記参照）

3. mode に応じた子スキルを実行:
   - mode=code → references/checklist-code.md の Phase 2 を実行
   - mode=e2e  → references/checklist-e2e.md の Phase 2 を実行
   - mode=both → まず references/checklist-code.md の Phase 2 を実行
                  → 次に references/checklist-e2e.md の Phase 2 を実行

4. Phase 3: 完了報告を実行
```

---

## Phase 1: 共通環境準備

全モード共通のスプレッドシート準備。子スキルの Phase 1 はこの共通Phase 1 を前提としている。

```
1. playwright-cli でブラウザを起動しスプレッドシートを開く
   playwright-cli open https://docs.google.com/spreadsheets/d/1h1MSOUuH2hx0-Q-FCFjp6ylisY9yc4Y6EAocToFXUFg/edit
   ※ 既にブラウザが起動済みなら tab-list で確認
2. 「アプリ」シートタブが選択されていることを確認（snapshot で確認）
3. セクションマップ構築（引数でセクション番号が指定されている場合）:
   a. A1にジャンプしてスクリーンショット撮影
   b. 水色背景のセクションヘッダー行を上からスキャン
      ※ セクションヘッダー行: B列に「{番号} {セクション名}」が水色背景で表示
   c. 各セクションの開始行と次のセクションヘッダー行の手前までを行範囲として記録
      例: セクション5のヘッダーが行20、セクション6のヘッダーが行25 → 対象範囲は行21〜24
   d. 指定セクション番号の行範囲を特定
   e. 行範囲が特定できない場合はエラー報告して停止
```

E2Eモードの場合は追加で:
```
4. usaconプレビューサイト用の新タブを作成
   playwright-cli tab-new https://preview.usacon-ai.com
5. ログイン操作を実行（references/app-knowledge.md「共通操作パターン > ログイン操作」参照）
6. ダッシュボード表示を確認
7. tab-list でタブのインデックスを記録（スプレッドシート: 0, usacon: 1 等）
```

---

## Phase 3: 完了報告

チェック完了後、以下を報告：
- 総チェック数 / 成功(OK/PASS)数 / 失敗(NG)数 / スキップ数
- 失敗した項目のリスト（行番号・テスト項目名・原因）
- 作成したGitHub Issueのリスト（Issue番号・タイトル・URL）

---

## スプレッドシート操作

Google Sheetsの操作手順は **google-sheets-mcp** スキルを参照。
特にセルナビゲーション・値読み取り・絵文字チェック操作の手順に従うこと。
すべての操作は `playwright-cli` コマンド（Bash経由）で実行する。

**重要**: 座標ベースではなく、refベースの操作パターンを使用すること。`playwright-cli snapshot` でref取得後に操作。

---

## 不備時のGitHub Issue作成

コードチェックまたはE2Eテストで不備が見つかった場合、GitHub Issueを自動作成して修正タスクをトラッキングする。

**リポジトリ**: `Robbits-CO-LTD/digital-management-consulting-app`

```bash
gh issue create \
  --repo Robbits-CO-LTD/digital-management-consulting-app \
  --title "[チェックリスト] {B列の内容}" \
  --label "bug" \
  --body "$(cat <<'EOF'
## チェックリスト不備報告

| 項目 | 内容 |
|------|------|
| **行番号** | {行番号} |
| **セクション** | {セクション名} |
| **チェック項目** | {B列の内容} |
| **テスト方法** | {C列のテスト方法} |
| **不備内容** | {E列の原因} |

## 再現手順
{C列の手順をベースにした具体的な再現手順}

## 期待される動作
{正しく動作した場合の期待結果}

## 実際の動作
{不備の具体的な症状}

---
📋 チェックリストの自動チェックにより作成されたIssueです。
EOF
)"
```

**フロー**:
1. D列に「NG」、E列に原因を記入（スプレッドシート記録が先）
2. 上記コマンドでGitHub Issue作成（Bashツールで実行）
3. Issue作成後、Issue番号をF列（備考）に**追記**（例: 既存備考がある場合は `既存テキスト / #123`、空の場合は `#123`）
4. G列に担当者を選択（E2Eテスト実行時のみ）

**注意**:
- Issue作成は `gh` CLIで実行（github-cliスキル参照）
- ラベル `bug` が存在しない場合は `--label` を省略
- 同じ項目で既にIssueが存在する場合（F列にIssue番号がある場合）は重複作成しない

---

## テスト結果チェックリスト記載ルール

> テスト実施後は `docs/checklist/usacon_checklist.md` に結果を記録すること

### チェックリストファイル
- **パス**: `docs/checklist/usacon_checklist.md`
- **目的**: 機能テストの履歴管理、品質保証

### 記載項目（テーブル形式）

**標準8列フォーマット**（すべてのチェックリストテーブルで統一）：

```markdown
| チェック | 内容 | テスト方法 | 結果 | チェック日 | チェック者 | 備考 | 承認 |
|:---:|------|----------|------|----------|----------|------|:---:|
```

| カラム | 内容 | 例 |
|--------|------|-----|
| チェック | ✅（完了）/ ⬜（未実施） | ✅ |
| 内容 | テスト対象の機能名・項目名 | チャット：テーブル表示（GFM対応） |
| テスト方法 | 具体的なテスト手順 | AIが表形式で回答した際にHTMLテーブルとして表示されるか確認 |
| 結果 | テスト結果ステータス | ✅ 正常動作 |
| チェック日 | YYYY-MM-DD形式 | 2026-01-30 |
| チェック者 | テスト実施者 | Claude / 竹下 |
| 備考 | PR番号、影響先、追加情報 | PR #404: remark-gfm導入。影響先：〇〇 |
| 承認 | 最終承認（空欄のまま） | |

### 記載例

**機能テスト:**
```markdown
| ✅ | チャット：テーブル表示（GFM対応） | AIが表形式で回答した際にHTMLテーブルとして表示されるか確認 | ✅ 正常動作 | 2026-01-30 | Claude | PR #404: remark-gfm導入 | |
```

**企業情報項目テスト（影響先を備考に記載）:**
```markdown
| ⬜ | `industry` 業界（製造業→情報通信業に変更） | 業界変更後にP1-1-2再実行。競合企業が業界に応じて変わるか | | | | 影響先：P1-1-2競合分析、P1-1-3技術推奨 | |
```

### 詳細テスト履歴セクション

大規模なテストや複数項目のテストは「テスト履歴（詳細）」セクションに記録：

```markdown
### 第N回テスト（YYYY-MM-DD 時間帯）- テスト概要タイトル

**実装内容:**
- PR #XXX: 実装の説明

**修正対象ファイル:**
- `path/to/file.tsx`

**テスト方法:**
- Playwright MCPプラグインで本番環境をテスト

**テスト結果:**

| チェック項目 | 結果 | 詳細 |
|-------------|------|------|
| 項目1 | ✅ 成功 | 詳細説明 |
| 項目2 | ✅ 成功 | 詳細説明 |

**修正ポイント:**
- 修正した技術的なポイントを箇条書き
```

### 更新必須箇所

1. **概要セクション**: `最終更新` 日付を更新
2. **該当機能セクション**: テーブルに行を追加
3. **変更履歴**: 日付・変更者・変更内容を追加
4. **テスト履歴（詳細）**: 大規模テストの場合は詳細セクションを追加

---

## 検証方法

- `/checklist code 5` でコードチェックのみ動作確認
- `/checklist e2e 5` でE2Eテストのみ動作確認
- `/checklist 5` で両方の順次実行確認
