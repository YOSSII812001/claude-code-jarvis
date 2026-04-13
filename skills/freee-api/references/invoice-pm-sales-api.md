# 請求書・工数管理・販売API 詳細リファレンス

---

## 請求書API（Invoice API）

ベースURL: `https://api.freee.co.jp/iv`

概要ページ: https://developer.freee.co.jp/reference/iv
OpenAPIスキーマ: `iv/open-api-3/api-schema.json`

> **注意**: 会計APIの `/invoices` `/quotations` は参照のみ。新規開発ではこちらの請求書APIを使用すること。

### 全エンドポイント一覧

#### 請求書（Invoices）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/invoices` | 請求書一覧 |
| POST | `/invoices` | 請求書作成 |
| GET | `/invoices/{id}` | 請求書詳細 |
| PUT | `/invoices/{id}` | 請求書更新 |
| GET | `/invoices/templates` | 請求書テンプレート一覧 |

#### 見積書（Quotations）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/quotations` | 見積書一覧 |
| POST | `/quotations` | 見積書作成 |
| GET | `/quotations/{id}` | 見積書詳細 |
| PUT | `/quotations/{id}` | 見積書更新 |
| GET | `/quotations/templates` | 見積書テンプレート一覧 |

#### 納品書（Delivery Slips）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/delivery_slips` | 納品書一覧 |
| POST | `/delivery_slips` | 納品書作成 |
| GET | `/delivery_slips/{id}` | 納品書詳細 |
| PUT | `/delivery_slips/{id}` | 納品書更新 |
| GET | `/delivery_slips/templates` | 納品書テンプレート一覧 |

### 共通パラメータ

- `company_id` — 必須
- テンプレートIDは `GET /*/templates` で取得して指定

### インボイス制度対応

- 適格請求書の要件を満たすフォーマット
- 登録番号（T+13桁）の出力
- 税率ごとの消費税額の明記

---

## 工数管理API（Project Management API）

ベースURL: `https://api.freee.co.jp/pm`
レート制限: 5,000 req/hour

概要ページ: https://developer.freee.co.jp/reference/pm

### 全エンドポイント一覧

#### ユーザー

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/users/me` | ログインユーザー情報 |

#### チーム（Teams）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/teams` | チーム一覧 |

#### 工数（Workloads）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/workloads` | 工数一覧 |
| POST | `/workloads` | 工数登録 |

**パラメータ（POST）**:
```json
{
  "company_id": 12345,
  "project_id": 100,
  "date": "2026-03-26",
  "minutes": 120,
  "description": "API設計作業"
}
```

#### 工数集計（Workload Summaries）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/workload_summaries` | 工数集計（プロジェクト別・メンバー別） |

#### プロジェクト（Projects）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/projects` | プロジェクト一覧 |
| POST | `/projects` | プロジェクト作成 |
| GET | `/projects/{id}` | プロジェクト詳細（収支情報含む） |

#### 取引先（Partners）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/partners` | 取引先一覧 |

#### メンバー（People）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/people` | メンバー一覧 |

#### 単価マスタ（Unit Costs）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/unit_costs` | 単価マスタ一覧 |

### プロジェクト収支

`GET /projects/{id}` のレスポンスにはプロジェクト収支情報が含まれる:
- 予算（budget）
- 実績工数（actual_workload）
- コスト（cost）
- 利益率（profit_rate）

---

## 販売API（Sales Management API）

ベースURL: `https://api.freee.co.jp/sm`
レート制限: 30 req/min、1,500 req/hour

> **プラン制限**: 販売APIはスタンダードプラン以上で利用可能。

概要ページ: https://developer.freee.co.jp/reference/sm
OpenAPIスキーマ: `sm/open-api-3/api-schema.json`

> **2026年2月**: 納品・売上の8エンドポイントが新規追加。

### 全エンドポイント一覧

#### 案件（Businesses）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/businesses` | 案件一覧 |
| POST | `/businesses` | 案件作成 |
| GET | `/businesses/{id}` | 案件詳細 |
| PATCH | `/businesses/{id}` | 案件更新 |

#### 受注（Sales Orders）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/sales_orders` | 受注一覧 |
| POST | `/sales_orders` | 受注作成 |
| GET | `/sales_orders/{id}` | 受注詳細 |
| PATCH | `/sales_orders/{id}` | 受注更新 |

#### 納品（Deliveries）— 2026年2月追加

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/deliveries` | 納品一覧 |
| POST | `/deliveries` | 納品作成 |
| GET | `/deliveries/{id}` | 納品詳細 |
| PATCH | `/deliveries/{id}` | 納品更新 |

#### 売上（Sales）— 2026年2月追加

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/sales` | 売上一覧 |
| POST | `/sales` | 売上作成 |
| GET | `/sales/{id}` | 売上詳細 |
| PATCH | `/sales/{id}` | 売上更新 |

#### マスタ（Masters）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/master/business_phases` | 案件フェーズマスタ |
| GET | `/master/sales_progressions` | 営業進捗マスタ |
| GET | `/master/items` | 商品マスタ |
| GET | `/master/deal_line_types` | 取引明細種別マスタ |
| GET | `/master/employees` | 従業員マスタ |
| GET | `/master/custom_fields/business/definitions` | 案件カスタムフィールド定義 |

### 販売フロー

```
案件(Business) → 受注(Sales Order) → 納品(Delivery) → 売上(Sales)
```

各ステージは独立して作成可能だが、通常はこの順序で進行する。

### 注意点

- 販売APIは `PUT` ではなく `PATCH` を使用（部分更新）
- マスタデータ（フェーズ、進捗、商品）は先に取得してIDを確認
- 案件カスタムフィールドの定義は `/master/custom_fields/business/definitions` で取得

---

## 連携パターン

### SFA/CRM → freee販売API

```
1. SFAの商談データを取得
2. POST /businesses で案件作成
3. 受注確定時に POST /sales_orders
4. 納品完了時に POST /deliveries
5. 売上計上時に POST /sales
6. freee会計APIで自動仕訳（売上計上 → 取引作成）
```

### EC → freee会計API

```
1. 日次の売上確定値を集計（リアルタイム同期は非推奨）
2. POST /deals (type: income) で収入取引を作成
3. 取引先・勘定科目・税区分のマスタIDを事前同期
4. 支払い情報(payments)を含めて決済も記録
```

### POS → freee会計API

```
1. 日次閉め処理後の確定売上を取得（営業中は送信しない）
2. POST /deals (type: income) で日次売上を1取引として作成
3. 現金/カード等の支払い方法別に payments を分ける
```

> **ガイドライン**: https://developer.freee.co.jp/guideline
