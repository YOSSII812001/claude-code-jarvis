# 会計API（Accounting API）詳細リファレンス

ベースURL: `https://api.freee.co.jp/api/1/`
OpenAPIスキーマ: `v2020_06_15/open-api-3/api-schema.json`

---

## 全エンドポイント一覧

### 事業所（Companies）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/companies` | 事業所一覧（company_id取得の起点） |
| GET | `/companies/{id}` | 事業所詳細（`?details=true` でマスタデータ一括取得） |

> **最初のステップ**: 全APIで `company_id` が必須。まず `/companies` で事業所一覧を取得する。

### 取引（Deals）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/deals` | 取引一覧（type: income/expense） |
| POST | `/deals` | 取引作成 |
| GET | `/deals/{id}` | 取引詳細 |
| PUT | `/deals/{id}` | 取引更新 |
| DELETE | `/deals/{id}` | 取引削除 |

**パラメータ（POST/PUT）**:
```json
{
  "company_id": 12345,
  "issue_date": "2026-03-26",
  "type": "expense",          // "income" or "expense"
  "due_date": "2026-04-30",   // 支払期日（任意）
  "partner_id": 67890,        // 取引先ID（任意）
  "ref_number": "INV-001",    // 管理番号（任意）
  "details": [{
    "account_item_id": 101,   // 勘定科目ID（必須）
    "tax_code": 2,            // 税区分コード（必須）
    "amount": 10000,          // 金額（必須）
    "item_id": null,          // 品目ID
    "section_id": null,       // 部門ID
    "tag_ids": [],            // メモタグID配列
    "description": "備考"     // 摘要
  }],
  "payments": [{              // 支払い情報（任意）
    "date": "2026-03-26",
    "from_walletable_type": "bank_account",
    "from_walletable_id": 111,
    "amount": 10000
  }]
}
```

### 決済（Payments）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/deals/{id}/payments` | 取引の決済一覧 |
| POST | `/deals/{id}/payments` | 決済追加 |

### 更新（Renews）

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/deals/{id}/renews` | 取引の更新行追加 |
| PUT | `/deals/{id}/renews/{renew_id}` | 更新行修正 |
| DELETE | `/deals/{id}/renews/{renew_id}` | 更新行削除 |

### 取引先（Partners）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/partners` | 取引先一覧（offset/limit対応） |
| POST | `/partners` | 取引先作成 |
| GET | `/partners/{id}` | 取引先詳細 |
| PUT | `/partners/{id}` | 取引先更新 |
| DELETE | `/partners/{id}` | 取引先削除 |
| PUT | `/partners/code/{code}` | コード指定で更新 |
| PUT | `/partners/upsert_by_code` | コードベースupsert（存在すれば更新、なければ作成） |

**インボイス制度対応フィールド**:
- `qualified_invoice_issuer`: 適格請求書発行事業者かどうか
- `invoice_registration_number`: 登録番号（T+13桁）

### 勘定科目（Account Items）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/account_items` | 勘定科目一覧 |
| POST | `/account_items` | 勘定科目作成 |
| GET | `/account_items/{id}` | 勘定科目詳細 |
| PUT | `/account_items/{id}` | 勘定科目更新 |
| DELETE | `/account_items/{id}` | 勘定科目削除 |
| PUT | `/account_items/code/upsert` | コードベースupsert |

> **注意**: 勘定科目IDは事業所ごとに異なる。事業所Aの「旅費交通費」IDが事業所Bと同じとは限らない。

### 部門（Sections）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/sections` | 部門一覧 |
| POST | `/sections` | 部門作成 |
| GET | `/sections/{id}` | 部門詳細 |
| PUT | `/sections/{id}` | 部門更新 |
| DELETE | `/sections/{id}` | 部門削除 |
| PUT | `/sections/code/upsert` | コードベースupsert |

階層深度はプランにより異なる（1-5段階）。

### 品目（Items）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/items` | 品目一覧 |
| POST | `/items` | 品目作成 |
| GET | `/items/{id}` | 品目詳細 |
| PUT | `/items/{id}` | 品目更新 |
| DELETE | `/items/{id}` | 品目削除 |

### メモタグ（Tags）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/tags` | メモタグ一覧 |
| POST | `/tags` | メモタグ作成 |
| GET | `/tags/{id}` | メモタグ詳細 |
| PUT | `/tags/{id}` | メモタグ更新 |
| DELETE | `/tags/{id}` | メモタグ削除 |

1取引に複数タグ付加可能。

### セグメントタグ（Segment Tags）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/segment_tags` | セグメントタグ一覧 |
| POST | `/segment_tags` | セグメントタグ作成 |
| GET | `/segment_tags/{id}` | セグメントタグ詳細 |
| PUT | `/segment_tags/{id}` | セグメントタグ更新 |

### 税区分（Taxes）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/taxes/companies/{company_id}` | 税区分一覧 |

インボイス制度対応で48の税コードが追加（2023年10月）。

### 振替伝票（Manual Journals）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/manual_journals` | 振替伝票一覧 |
| POST | `/manual_journals` | 振替伝票作成 |
| GET | `/manual_journals/{id}` | 振替伝票詳細 |
| PUT | `/manual_journals/{id}` | 振替伝票更新 |

### 口座振替（Transfers）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/transfers` | 口座振替一覧 |
| POST | `/transfers` | 口座振替作成 |
| GET | `/transfers/{id}` | 口座振替詳細 |
| PUT | `/transfers/{id}` | 口座振替更新 |
| DELETE | `/transfers/{id}` | 口座振替削除 |

### 仕訳帳（Journals）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/journals` | 仕訳帳ダウンロード（CSV形式） |

> **プラン制限**: フリープランでは利用不可。

### 試算表（Trial Balance）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/reports/trial_bs` | 貸借対照表 |
| GET | `/reports/trial_pl` | 損益計算書 |

フィルタ: 取引先、品目、部門。年度比較対応。レート制限: 10 req/sec。

### 総勘定元帳（General Ledgers）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/reports/general_ledgers` | 総勘定元帳 |

### 口座明細（Wallet Transactions）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/wallet_txns` | 口座明細一覧（仕訳前の明細データ） |

### 口座（Walletables）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/walletables` | 口座一覧 |

### 連携サービス（Banks）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/banks` | 連携可能な金融機関一覧 |

### 経費精算（Expense Applications）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/expense_applications` | 経費精算一覧 |
| POST | `/expense_applications` | 経費精算作成 |
| GET | `/expense_applications/{id}` | 経費精算詳細 |
| PUT | `/expense_applications/{id}` | 経費精算更新 |
| POST | `/expense_applications/{id}/actions` | 承認アクション実行 |

**承認アクション**: `approve`, `reject`, `feedback`, `cancel`, `force_approve`, `force_feedback`

**プラン制限**: 法人ベーシック以上で利用可。申請経路指定はプロフェッショナル以上。

### 経費科目テンプレート（Expense Application Line Templates）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/expense_application_line_templates` | 経費科目一覧 |

### 支払依頼（Payment Requests）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/payment_requests` | 支払依頼一覧 |
| POST | `/payment_requests` | 支払依頼作成 |
| GET | `/payment_requests/{id}` | 支払依頼詳細 |
| PUT | `/payment_requests/{id}` | 支払依頼更新 |
| POST | `/payment_requests/{id}/actions` | 承認アクション実行 |

### 各種申請（Approval Requests）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/approval_requests` | 各種申請一覧 |
| POST | `/approval_requests` | 各種申請作成 |
| GET | `/approval_requests/{id}` | 各種申請詳細 |
| PUT | `/approval_requests/{id}` | 各種申請更新 |
| POST | `/approval_requests/{id}/actions` | 承認アクション実行 |

### 申請経路（Approval Flow Routes）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/approval_flow_routes` | 申請経路一覧 |

### ファイルボックス（Receipts）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/receipts` | 証憑一覧 |
| POST | `/receipts` | 証憑アップロード（multipart/form-data） |
| GET | `/receipts/{id}` | 証憑詳細 |
| DELETE | `/receipts/{id}` | 証憑削除 |
| GET | `/receipts/{id}/download` | 証憑ダウンロード |

**レート制限**: アップロード 300 req/min、ダウンロード 3 req/sec（事業所単位）。

### 請求書・見積書（移行済み）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/invoices` | 請求書一覧 |
| GET | `/quotations` | 見積書一覧 |

> **注意**: 新規開発ではfreee請求書API（`/reference/iv`）を使用すること。会計API側は参照のみ。

### 固定資産（Fixed Assets）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/fixed_assets` | 固定資産一覧 |
| POST | `/fixed_assets` | 固定資産登録 |
| GET | `/fixed_assets/{id}` | 固定資産詳細 |
| PUT | `/fixed_assets/{id}` | 固定資産更新 |

### 決算書表示名（Account Groups）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/account_groups` | 決算書表示名グループ一覧 |

### フォーム選択項目（Selectables）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/forms/selectables` | フォーム用の選択肢データ一括取得 |

### ユーザー（Users）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/users/me` | 認証ユーザー情報と所属事業所一覧 |

---

## マスタデータ同期パターン

freee APIを使う前に、以下の順序でマスタを同期する:

```
1. GET /companies → company_id 取得
2. GET /partners?company_id={id} → 取引先マスタ
3. GET /account_items?company_id={id} → 勘定科目マスタ
4. GET /taxes/companies/{id} → 税区分マスタ
5. GET /walletables?company_id={id} → 口座マスタ
6. GET /sections?company_id={id} → 部門マスタ
7. GET /items?company_id={id} → 品目マスタ
8. GET /tags?company_id={id} → メモタグマスタ
```

マスタIDは他APIのパラメータとして使用（例: deals作成時の `partner_id`, `account_item_id`, `tax_code`）。

> **ガイドライン詳細**: https://developer.freee.co.jp/guideline/master-guideline

---

## 経費精算ワークフロー

```
申請者: POST /expense_applications (status: draft)
   ↓ actions: apply
承認者: POST /expense_applications/{id}/actions (approve)
   ↓
完了（status: approved）

差戻し: actions: feedback / force_feedback
却下: actions: reject
取消: actions: cancel（申請者のみ）
強制承認: actions: force_approve（管理者のみ）
```

実装前にWeb画面で申請経路・レコードを作成して構造を確認すること。

---

## プラン別制限の注意

| 機能 | フリー | ベーシック | プロフェッショナル | エンタープライズ |
|------|--------|-----------|------------------|----------------|
| 仕訳帳API | x | o | o | o |
| 経費精算API | x | o | o | o |
| 申請経路指定 | x | x | o | o |
| 部門階層(5段階) | x | x | o | o |

エラー時は `freee_plan_limit` コードで通知される。
