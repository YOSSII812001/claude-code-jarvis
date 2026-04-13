# 人事労務API（HR API）詳細リファレンス

ベースURL: `https://api.freee.co.jp/hr/api/v1/`
APIバージョン: `2022-02-01`
OpenAPIスキーマ: `hr/open-api-3/api-schema.json`

---

## APIバージョンヘッダー

HR APIはバージョン管理されている。公式リファレンスで要求されている場合、以下ヘッダーを含める:

```
api-version: 2022-02-01
```

> **注意**: このヘッダーの必須/任意は公式ドキュメントの最新情報を確認すること。OpenAPIスキーマ上はバージョンヘッダーが定義されているが、実際の挙動は変更される可能性がある。

---

## レート制限

| 制限 | 値 |
|------|-----|
| 最大リクエスト数 | 10,000 req/hour |
| 過度のアクセス時 | HTTP 403 + 10分間クールダウン |

### レスポンスヘッダー

```
X-RateLimit-Limit: 10000       # 最大リクエスト数
X-RateLimit-Remaining: 9500    # 残りリクエスト数
X-RateLimit-Reset: 1700000000  # リセット時刻（Unix timestamp）
```

`X-RateLimit-Remaining` を監視し、残り少なくなったら待機する。

---

## 認可レベル

| レベル | アクセス範囲 |
|--------|------------|
| `company_admin` | 全従業員データ |
| `self_only` | 本人の情報のみ |

従業員データのCRUD操作には `company_admin` 権限が必要。

---

## 全エンドポイント一覧

### ユーザー情報

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/users/me` | ログインユーザー情報（company_id, employee_id取得） |

> **最初のステップ**: `/users/me` で `company_id` と自分の `employee_id` を取得する。

### 従業員（Employees）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/companies/{company_id}/employees` | 全従業員一覧 |
| GET | `/employees` | 従業員一覧（年月指定フィルタ） |
| POST | `/employees` | 従業員作成 |
| GET | `/employees/{id}` | 従業員詳細 |
| PUT | `/employees/{id}` | 従業員更新 |
| DELETE | `/employees/{id}` | 従業員削除 |

### 個人プロフィール

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/profile_rule` | プロフィール取得 |
| PUT | `/employees/{id}/profile_rule` | プロフィール更新 |

### 健康保険

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/health_insurance_rule` | 健康保険情報取得 |
| PUT | `/employees/{id}/health_insurance_rule` | 健康保険情報更新 |

### 厚生年金保険

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/welfare_pension_insurance_rule` | 厚生年金情報取得 |
| PUT | `/employees/{id}/welfare_pension_insurance_rule` | 厚生年金情報更新 |

### 扶養家族

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/dependent_rules` | 扶養家族情報取得 |
| PUT | `/employees/{id}/dependent_rules/bulk_update` | 扶養家族一括更新 |

### 銀行口座

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/bank_account_rule` | 口座情報取得 |
| PUT | `/employees/{id}/bank_account_rule` | 口座情報更新 |

### 基本給

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/basic_pay_rule` | 基本給取得 |
| PUT | `/employees/{id}/basic_pay_rule` | 基本給更新 |

### カスタム項目

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/profile_custom_fields` | カスタムフィールド取得 |

---

## 勤怠管理

### 日次勤怠レコード

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/work_records/{date}` | 日次勤怠取得 |
| PUT | `/employees/{id}/work_records/{date}` | 日次勤怠更新 |
| DELETE | `/employees/{id}/work_records/{date}` | 日次勤怠削除 |

`{date}` は `YYYY-MM-DD` 形式。

### 月次勤怠サマリー

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/work_record_summaries/{year}/{month}` | 月次勤怠集計取得 |
| PUT | `/employees/{id}/work_record_summaries/{year}/{month}` | 月次勤怠集計更新 |

### 打刻（Time Clocks）

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/employees/{id}/time_clocks` | 打刻一覧 |
| POST | `/employees/{id}/time_clocks` | 打刻登録 |
| GET | `/employees/{id}/time_clocks/{clock_id}` | 打刻詳細 |
| GET | `/employees/{id}/time_clocks/available_types` | 利用可能な打刻種別 |

**打刻種別（type）**:
- `clock_in` — 出勤
- `clock_out` — 退勤
- `break_begin` — 休憩開始
- `break_end` — 休憩終了

```bash
# 出勤打刻
curl -X POST "https://api.freee.co.jp/hr/api/v1/employees/${EMP_ID}/time_clocks" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "api-version: 2022-02-01" \
  -d '{"company_id": '"${COMPANY_ID}"', "type": "clock_in"}'
```

---

### その他のエンドポイント（主要なもの）

HR APIには上記以外にも以下のカテゴリが存在する。OpenAPIスキーマ（`hr/open-api-3/api-schema.json`）で最新の全エンドポイントを確認すること。

| カテゴリ | 概要 |
|---------|------|
| 給与明細 | 月次給与明細の取得 |
| 賞与明細 | 賞与明細の取得 |
| 勤怠タグ | 勤怠に付与するタグ管理 |
| 有給休暇 | 有給休暇の申請・残日数 |
| 年末調整 | 年末調整関連データ |
| 組織図 | 組織構造の取得 |

> **注意**: 上記はHR APIの一部。完全なエンドポイント一覧はOpenAPIスキーマまたは公式リファレンスを参照。

## よく使うパターン

### 全従業員の今月の勤怠サマリー取得

```bash
# 1. 全従業員ID取得
EMPLOYEES=$(curl -s "https://api.freee.co.jp/hr/api/v1/companies/${COMPANY_ID}/employees" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "api-version: 2022-02-01")

# 2. 各従業員の月次サマリー取得（逐次実行推奨、レート制限注意）
curl -s "https://api.freee.co.jp/hr/api/v1/employees/${EMP_ID}/work_record_summaries/2026/3" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "api-version: 2022-02-01"
```

### 従業員マスタの一元管理

外部人事システム → freee人事労務への同期パターン:
1. `GET /companies/{cid}/employees` で既存従業員を取得
2. 外部システムの従業員と照合（社員番号等でマッチング）
3. 新規: `POST /employees` で作成
4. 更新: `PUT /employees/{id}` で更新
5. 退職: Web画面から退職処理（API未対応）
