<!-- 抽出元: SKILL.md のセクション「エンドポイント一覧」「検索パラメータ（/v1/hojin）」「期間指定パラメータ」「レスポンス構造」「基本情報フィールド（HojinInfo）」「ページネーション」「v1/v2 対応表」「レート制限」「エラーハンドリング」 -->

# gBizINFO API リファレンス

## エンドポイント一覧

### A. 法人検索

| エンドポイント | メソッド | 説明 |
|----------------|----------|------|
| `/v1/hojin` | GET | 法人情報の検索 |

### B. 法人番号指定取得

| エンドポイント | メソッド | 説明 |
|----------------|----------|------|
| `/v1/hojin/{corporate_number}` | GET | 基本情報 |
| `/v1/hojin/{corporate_number}/certification` | GET | 届出・認定情報 |
| `/v1/hojin/{corporate_number}/commendation` | GET | 表彰情報 |
| `/v1/hojin/{corporate_number}/finance` | GET | 財務情報 |
| `/v1/hojin/{corporate_number}/patent` | GET | 特許情報 |
| `/v1/hojin/{corporate_number}/procurement` | GET | 調達情報 |
| `/v1/hojin/{corporate_number}/subsidy` | GET | 補助金情報 |
| `/v1/hojin/{corporate_number}/workplace` | GET | 職場情報 |

### C. 期間指定更新情報検索

| エンドポイント | メソッド | 説明 |
|----------------|----------|------|
| `/v1/hojin/updateInfo` | GET | 全分野の更新情報 |
| `/v1/hojin/updateInfo/certification` | GET | 届出・認定の更新 |
| `/v1/hojin/updateInfo/commendation` | GET | 表彰の更新 |
| `/v1/hojin/updateInfo/finance` | GET | 財務の更新 |
| `/v1/hojin/updateInfo/patent` | GET | 特許の更新 |
| `/v1/hojin/updateInfo/procurement` | GET | 調達の更新 |
| `/v1/hojin/updateInfo/subsidy` | GET | 補助金の更新 |
| `/v1/hojin/updateInfo/workplace` | GET | 職場の更新 |

### D. v2 追加エンドポイント

| エンドポイント | メソッド | 説明 |
|----------------|----------|------|
| `/v2/hojin/{corporate_number}/corporation` | GET | 法人基本情報（v2拡張） |
| `/v2/hojin/updateInfo/corporation` | GET | 法人基本情報の更新 |

> v2では全v1エンドポイントが `/v2/hojin/...` パスで利用可能。加えて上記2つが新規追加。

---

## 検索パラメータ（`/v1/hojin`）

> 公式OpenAPI仕様（v1、2026-02-28確認）に基づく全35パラメータ。

### 基本検索

| パラメータ | 型 | 必須 | 説明 | 例 |
|-----------|-----|------|------|-----|
| `name` | String | △ | 法人名（部分一致） | `トヨタ` |
| `corporate_number` | String | △ | 法人番号（完全一致） | `1010401089234` |
| `exist_flg` | String | × | 法人活動情報の有無（`true`/`false`） | `true` |
| `corporate_type` | String | × | 法人種別コード（カンマ区切り） | `301,305` |
| `prefecture` | String | × | 都道府県コード（JIS X 0401、2桁） | `13` |
| `city` | String | × | 市区町村コード（JIS X 0402、3桁、`prefecture`必須） | `101` |
| `founded_year` | String | × | 創業年・設立年（カンマ区切りで複数可） | `2020,2021` |

> **△**: `name`または`corporate_number`のいずれか1つは必須。

### 財務規模フィルタ

| パラメータ | 型 | 説明 | 例 |
|-----------|-----|------|-----|
| `capital_stock_from` | String | 資本金下限（0以上の整数） | `10000000` |
| `capital_stock_to` | String | 資本金上限 | `100000000` |
| `employee_number_from` | String | 従業員数下限 | `50` |
| `employee_number_to` | String | 従業員数上限 | `500` |
| `net_sales_summary_of_business_results_from` | String | 売上高下限 | `100000000` |
| `net_sales_summary_of_business_results_to` | String | 売上高上限 | `1000000000` |
| `net_income_loss_summary_of_business_results_from` | String | 当期純利益下限 | `10000000` |
| `net_income_loss_summary_of_business_results_to` | String | 当期純利益上限 | `100000000` |
| `total_assets_summary_of_business_results_from` | String | 総資産額下限 | `500000000` |
| `total_assets_summary_of_business_results_to` | String | 総資産額上限 | `5000000000` |

### 労務・職場フィルタ

| パラメータ | 型 | 説明 | コード |
|-----------|-----|------|--------|
| `average_age` | String | 従業員の平均年齢 | A:~30歳 B:31~45歳 C:46~60歳 D:61歳~ |
| `average_continuous_service_years` | String | 平均継続勤務年数 | A:~5年 B:6~10年 C:11~20年 D:21年~ |
| `month_average_predetermined_overtime_hours` | String | 月平均所定外労働時間 | A:20h未満 B:40h未満 C:40h以上 |
| `female_workers_proportion` | String | 女性労働者割合 | A:~20% B:21~40% C:41~60% D:61%~ |

### 資格・品目フィルタ

| パラメータ | 型 | 説明 | 例 |
|-----------|-----|------|-----|
| `unified_qualification` | String | 全省庁統一資格の資格等級（従来型、A/B/C/D） | `A,B` |
| `unified_qualification_sub01` | String | 資格等級（物品の製造） | `A` |
| `unified_qualification_sub02` | String | 資格等級（物品の販売） | `B` |
| `unified_qualification_sub03` | String | 資格等級（役務の提供等） | `A,B` |
| `unified_qualification_sub04` | String | 資格等級（物品の買受け） | `C` |
| `business_item` | String | 営業品目コード（カンマ区切り） | コード表参照 |
| `sales_area` | String | 営業エリアコード（カンマ区切り） | コード表参照 |
| `name_major_shareholders` | String | 大株主名（部分一致） | `トヨタ` |

> コード表: https://info.gbiz.go.jp/codelist/document/codelist.pdf

### データソース・行政フィルタ

| パラメータ | 型 | 説明 | 例 |
|-----------|-----|------|-----|
| `source` | String | 出典元（カンマ区切り） | `1,4` |
| `year` | String | 年度（カンマ区切りで複数可） | `2025` |
| `ministry` | String | 担当府省コード（カンマ区切り） | コード表参照 |

**出典元コード（source）:**

| コード | 出典 |
|--------|------|
| `1` | 調達 |
| `2` | 表彰 |
| `3` | 届出認定 |
| `4` | 補助金 |
| `5` | 特許 |
| `6` | 財務 |

> 担当府省コード: https://info.gbiz.go.jp/common/data/setcodelist.pdf

### ページネーション

| パラメータ | 型 | 説明 | デフォルト |
|-----------|-----|------|----------|
| `page` | String | ページ番号（下限1、**上限10**） | `1` |
| `limit` | String | 1ページあたりの件数（**上限5000**） | `1000` |

---

## 期間指定パラメータ（`/v1/hojin/updateInfo/...`）

| パラメータ | 型 | 必須 | 説明 | 例 |
|-----------|-----|------|------|-----|
| `from` | String | ○ | 開始日（YYYYMMDD、8桁数字） | `20260101` |
| `to` | String | ○ | 終了日（YYYYMMDD、8桁数字） | `20260301` |
| `page` | String | × | ページ番号（デフォルト: 1） | `1` |

### 期間指定検索の例
```bash
# 2026年1~3月に更新された補助金情報
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/updateInfo/subsidy?from=20260101&to=20260301&page=1" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"

# 直近1ヶ月の全分野更新情報
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/updateInfo?from=20260201&to=20260301&page=1" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

---

## レスポンス構造

### 法人検索・法人番号指定取得（HojinInfoResponse）
```json
{
  "id": null,
  "errors": null,
  "message": "200 - OK.",
  "hojin-infos": [ ... ]
}
```

### 期間指定更新情報（HojinInfoUpdateInfoResponse）
```json
{
  "id": null,
  "errors": null,
  "message": "200 - OK.",
  "hojin-infos": [ ... ],
  "pageNumber": "1",
  "totalCount": "350",
  "totalPage": "4"
}
```

> **注意**: JSONキーにハイフンが含まれる（`hojin-infos`）。JavaScriptではブラケット記法 `data["hojin-infos"]` を使用。

### エラーレスポンス（ApiError）
```json
{
  "id": null,
  "errors": [
    { "item": "name", "message": "パラメータが不正です" }
  ],
  "message": "400 - Bad Request.",
  "hojin-infos": null
}
```

---

### 基本情報フィールド（HojinInfo）

#### 法人識別
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `corporate_number` | String | 法人番号（13桁） |
| `name` | String | 法人名 |
| `kana` | String | 法人名フリガナ |
| `name_en` | String | 法人名英語 |
| `status` | String | ステータス |

#### 所在地・連絡先
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `postal_code` | String | 郵便番号 |
| `location` | String | 本社所在地 |
| `company_url` | String | 企業ホームページ |

#### 代表者
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `representative_name` | String | 法人代表者名 |
| `representative_position` | String | 法人代表者役職 |

#### 規模・財務
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `capital_stock` | Integer | 資本金 |
| `employee_number` | Integer | 従業員数 |
| `company_size_male` | Integer | 企業規模詳細（男） |
| `company_size_female` | Integer | 企業規模詳細（女） |
| `date_of_establishment` | String | 設立年月日 |
| `founding_year` | Integer | 創業年 |

#### 事業内容
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `business_summary` | String | 事業概要 |
| `business_items` | Array<String> | 全省庁統一資格の営業品目 |
| `qualification_grade` | String | 資格等級（物品製造/販売/役務/買受け） |

#### ネスト情報（各サブエンドポイントで取得）
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `certification` | Array | 届出・認定情報 |
| `commendation` | Array | 表彰情報 |
| `finance` | Object | 財務情報 |
| `patent` | Array | 特許情報 |
| `procurement` | Array | 調達情報 |
| `subsidy` | Array | 補助金情報 |
| `workplace_info` | Object | 職場情報 |

#### 管理
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `update_date` | String | 最終更新日 |
| `close_date` | String | 登記記録の閉鎖等年月日 |
| `close_cause` | String | 登記記録の閉鎖等の事由 |
| `number_of_activity` | String | 法人活動情報件数 |

---

## ページネーション

> **制約**: `page`の上限は10。最大取得件数 = 10ページ x 5000件 = 50,000件。

```bash
# 1ページ目
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=コンサルティング&page=1&limit=50" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"

# 2ページ目
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=コンサルティング&page=2&limit=50" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### updateInfo系のページ情報を確認
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/updateInfo/subsidy?from=20260101&to=20260301&page=1" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" \
  | jq '{pageNumber, totalPage, totalCount, items: (.["hojin-infos"] | length)}'
```

---

## v1/v2 対応表

| 分類 | v1 | v2 |
|------|----|----|
| 法人検索 | `/v1/hojin` | `/v2/hojin` |
| 基本情報 | `/v1/hojin/{cn}` | `/v2/hojin/{cn}` |
| 届出・認定 | `/v1/hojin/{cn}/certification` | `/v2/hojin/{cn}/certification` |
| 表彰 | `/v1/hojin/{cn}/commendation` | `/v2/hojin/{cn}/commendation` |
| 財務 | `/v1/hojin/{cn}/finance` | `/v2/hojin/{cn}/finance` |
| 特許 | `/v1/hojin/{cn}/patent` | `/v2/hojin/{cn}/patent` |
| 調達 | `/v1/hojin/{cn}/procurement` | `/v2/hojin/{cn}/procurement` |
| 補助金 | `/v1/hojin/{cn}/subsidy` | `/v2/hojin/{cn}/subsidy` |
| 職場 | `/v1/hojin/{cn}/workplace` | `/v2/hojin/{cn}/workplace` |
| **法人基本（新規）** | -- | `/v2/hojin/{cn}/corporation` |
| updateInfo全分野 | `/v1/hojin/updateInfo` | `/v2/hojin/updateInfo` |
| **updateInfo法人基本（新規）** | -- | `/v2/hojin/updateInfo/corporation` |

### v2で追加された検索パラメータ

| パラメータ | 説明 |
|-----------|------|
| `patent` | 特許の有無 |
| `procurement` | 調達の有無 |
| `procurement_amount_from/to` | 調達金額範囲 |
| `subsidy` | 補助金の有無 |
| `subsidy_amount_from/to` | 補助金金額範囲 |
| `certification` | 認定の有無 |
| `metadata_flg` | メタデータフラグ |

> v2では v1の `sales_area`, `business_item`, `unified_qualification*`, `name_major_shareholders`, `net_income_loss_*`, `year` が廃止。代わりに上記のフィルタが追加。

---

## レート制限

| 項目 | 値 |
|------|-----|
| ソフトリミット | 10分間に約6,000リクエスト |
| 超過時 | 10分間のアクセスブロック |
| 推奨 | 5,000リクエストごとに10分の間隔 |
| 日次/月次制限 | 明示なし |

---

## エラーハンドリング

> OpenAPI仕様上は200レスポンスのみ定義。以下は運用観測値（2026-02-28時点）。

| HTTPステータス | 原因 | 対処 |
|---------------|------|------|
| 200 | 成功 | `message` フィールドで確認 |
| 404 | 法人番号が存在しない | 法人番号を確認 |
| 500 | 認証エラー（トークン不正/期限切れ） | トークンを再確認・再取得 |

> **注意**: Swagger上は認証エラーが401として定義されることがあるが、実際には500を返す場合がある。

### レスポンスのエラー確認
```bash
curl -s "..." | jq '{message, errors}'
```
