---
name: Jグランツ API
description: デジタル庁の補助金検索API。認証不要で補助金情報を検索・取得。DX、設備投資、IT導入等の補助金検索に使用。
---

# Jグランツ API ガイド

## 概要
デジタル庁が提供するJグランツ（補助金電子申請システム）の公開APIを使用して補助金情報を検索・取得する。

| 項目 | 値 |
|------|-----|
| ベースURL | `https://api.jgrants-portal.go.jp/exp/v1/public` |
| 認証 | **不要**（公開API） |
| ドキュメント | https://developers.digital.go.jp/documents/jgrants/api/ |
| ポータル | https://www.jgrants-portal.go.jp/ |
| MCP Server | https://github.com/digital-go-jp/jgrants-mcp-server |

---

## エンドポイント

| エンドポイント | メソッド | 説明 |
|----------------|----------|------|
| `/subsidies` | GET | 補助金一覧検索 |
| `/subsidies/id/{subsidy_id}` | GET | 個別補助金詳細取得 |

---

## 基本コマンド

### 補助金検索（受付中）
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=created_date&order=DESC&acceptance=1&limit=10" \
  -H "Accept: application/json"
```

### 補助金検索（締切が近い順）
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=acceptance_end_datetime&order=ASC&acceptance=1&limit=10" \
  -H "Accept: application/json"
```

### 条件付き検索
```bash
# 製造業・東京都・締切が近い順
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=設備投資&sort=acceptance_end_datetime&order=ASC&acceptance=1&industry=製造業&target_area_search=東京都&limit=20" \
  -H "Accept: application/json"

# IT導入・中小企業向け
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=IT導入&sort=created_date&order=DESC&acceptance=1&target_number_of_employees=50名以下&limit=10" \
  -H "Accept: application/json"

# 複数業種・複数地域
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=創業&sort=created_date&order=DESC&acceptance=1&industry=情報通信業%20%2F%20製造業&target_area_search=東京都%20%2F%20大阪府&limit=10" \
  -H "Accept: application/json"
```

### 補助金詳細取得
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies/id/{補助金ID}" \
  -H "Accept: application/json"

# 例
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies/id/a0WJ200000CDX7NMAX" \
  -H "Accept: application/json"
```

---

## 検索パラメータ

### 必須パラメータ
| パラメータ | 型 | 説明 | 制約 | デフォルト |
|-----------|-----|------|------|----------|
| `keyword` | string | 検索キーワード | 2〜255文字、空白不可 | なし（必須） |
| `sort` | string | ソート項目 | 下記参照 | `acceptance_end_datetime` |
| `order` | string | 並び順 | `ASC`, `DESC` | `ASC` |
| `acceptance` | string | 受付状況 | **`1`のみ有効**（後述） | `1` |

### オプションパラメータ
| パラメータ | 型 | 説明 | 例 |
|-----------|-----|------|-----|
| `limit` | number | 取得件数（デフォルト20、上限なし※） | `10`, `50`, `100` |
| `offset` | number | オフセット（ページング用） | `0`, `50`, `100` |
| `industry` | string | 業種（複数は ` / ` 区切り） | `製造業`, `情報通信業 / 建設業` |
| `target_area_search` | string | 対象地域 | `東京都`, `全国`, `関東・甲信越地方` |
| `target_number_of_employees` | string | 従業員数区分 | `50名以下`, `300名以下` |
| `use_purpose` | string | 利用目的（複数は ` / ` 区切り） | `設備整備・IT導入をしたい` |
| `subsidy_max_limit_from` | number | 補助金上限（下限）※ | `1000000` |
| `subsidy_max_limit_to` | number | 補助金上限（上限）※ | `5000000` |

> **※ 金額フィルタの注意**: `subsidy_max_limit_from/to`は正確にフィルタリングされない場合があります。重要な場合はクライアント側で再フィルタリングを推奨。

---

## ソート項目（sort）

| 値 | 説明 | 用途 |
|----|------|------|
| `created_date` | 作成日時 | 新着順で表示 |
| `acceptance_start_datetime` | 募集開始日時 | 開始が近い順 |
| `acceptance_end_datetime` | 募集終了日時 | 締切が近い順（推奨） |

---

## 業種（industry）完全リスト

```
農業、林業
漁業
鉱業、採石業、砂利採取業
建設業
製造業
電気・ガス・熱供給・水道業
情報通信業
運輸業、郵便業
卸売業、小売業
金融業、保険業
不動産業、物品賃貸業
学術研究、専門・技術サービス業
宿泊業、飲食サービス業
生活関連サービス業、娯楽業
教育、学習支援業
医療、福祉
複合サービス事業
サービス業（他に分類されないもの）
公務（他に分類されるものを除く）
分類不能の産業
```

**複数指定例**: `製造業 / 情報通信業 / 建設業`

---

## 利用目的（use_purpose）完全リスト

```
新たな事業を行いたい
販路拡大・海外展開をしたい
イベント・事業運営支援がほしい
事業を引き継ぎたい
研究開発・実証事業を行いたい
人材育成を行いたい
資金繰りを改善したい
設備整備・IT導入をしたい
雇用・職場環境を改善したい
エコ・SDGs活動支援がほしい
災害（自然災害、感染症等）支援がほしい
教育・子育て・少子化支援がほしい
スポーツ・文化支援がほしい
安全・防災対策支援がほしい
まちづくり・地域振興支援がほしい
```

**複数指定例**: `設備整備・IT導入をしたい / 人材育成を行いたい`

---

## 従業員数区分（target_number_of_employees）

| 従業員数 | パラメータ値 |
|----------|-------------|
| 制限なし | `従業員数の制約なし` |
| 1〜5名 | `5名以下` |
| 6〜20名 | `20名以下` |
| 21〜50名 | `50名以下` |
| 51〜100名 | `100名以下` |
| 101〜300名 | `300名以下` |
| 301〜900名 | `900名以下` |
| 901名以上 | `901名以上` |

---

## 対象地域（target_area_search）

### 広域
```
全国
北海道地方
東北地方
関東・甲信越地方
東海・北陸地方
近畿地方
中国地方
四国地方
九州・沖縄地方
```

### 都道府県（47都道府県すべて対応）
```
北海道, 青森県, 岩手県, 宮城県, 秋田県, 山形県, 福島県,
茨城県, 栃木県, 群馬県, 埼玉県, 千葉県, 東京都, 神奈川県,
新潟県, 富山県, 石川県, 福井県, 山梨県, 長野県, 岐阜県,
静岡県, 愛知県, 三重県, 滋賀県, 京都府, 大阪府, 兵庫県,
奈良県, 和歌山県, 鳥取県, 島根県, 岡山県, 広島県, 山口県,
徳島県, 香川県, 愛媛県, 高知県, 福岡県, 佐賀県, 長崎県,
熊本県, 大分県, 宮崎県, 鹿児島県, 沖縄県
```

**複数指定例**: `東京都 / 神奈川県 / 埼玉県`

> **注意**: 広域名（○○地方）での検索は、該当する補助金が少ない場合があります。都道府県名での検索を推奨。

---

## レスポンス構造

### 一覧レスポンス
```json
{
  "metadata": {
    "type": "https://developers.digital.go.jp/documents/jgrants/api/",
    "resultset": {
      "count": 150
    }
  },
  "result": [
    {
      "id": "a0WJ200000CDX7NMAX",
      "name": "S-00007877",
      "title": "令和7年度○○補助金",
      "subsidy_max_limit": 5000000,
      "acceptance_start_datetime": "2025-04-01T00:00:00.000Z",
      "acceptance_end_datetime": "2026-06-30T23:59:59.000Z",
      "target_area_search": "東京都 / 神奈川県",
      "target_number_of_employees": "50名以下"
    }
  ]
}
```

### 詳細レスポンス（全フィールド）

#### 基本情報
| フィールド | 説明 |
|-----------|------|
| `id` | 補助金ID（詳細取得に使用） |
| `name` | 補助金番号（S-XXXXXXXX形式） |
| `title` | 補助金タイトル |
| `subsidy_catch_phrase` | キャッチフレーズ（短い説明文） |
| `detail` | 詳細説明（HTML含む場合あり） |
| `outline_of_grant` | 補助金概要（ファイル配列） |

#### 金額・補助率
| フィールド | 説明 |
|-----------|------|
| `subsidy_max_limit` | 補助上限額（円、0は上限なし） |
| `subsidy_rate` | 補助率（例: `2/3`, `1/2`） |

#### 期間
| フィールド | 説明 |
|-----------|------|
| `acceptance_start_datetime` | 受付開始日時（ISO 8601） |
| `acceptance_end_datetime` | 受付終了日時（ISO 8601） |
| `project_end_deadline` | 事業終了期限 |

#### 対象条件
| フィールド | 説明 |
|-----------|------|
| `industry` | 対象業種 |
| `target_area_search` | 対象地域（検索用） |
| `target_area_detail` | 対象地域詳細 |
| `target_number_of_employees` | 対象従業員数 |
| `use_purpose` | 利用目的 |
| `application_target` | 申請対象（法人/個人等） |

#### 申請関連
| フィールド | 説明 |
|-----------|------|
| `application_form` | 申請書類（ファイル配列） |
| `application_guidelines` | 申請ガイドライン（ファイル配列） |
| `is_enable_multiple_request` | 複数申請可否 |
| `request_reception_presence` | 受付状況 |

#### リンク
| フィールド | 説明 |
|-----------|------|
| `front_subsidy_detail_page_url` | ポータルサイトURL |
| `inquiry_url` | 問い合わせURL |

> **ファイル配列**: `[{"name": "ファイル名", "data": "BASE64エンコードデータ"}]` 形式

---

## ページネーション

> **※ limit上限について**: テストではlimit=500でも動作確認済み。ただし大量取得はサーバー負荷になるため、100件程度を推奨。

### 大量データの分割取得
```bash
# 1ページ目（1-100件）
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=補助金&sort=created_date&order=DESC&acceptance=1&limit=100&offset=0" \
  -H "Accept: application/json"

# 2ページ目（101-200件）
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=補助金&sort=created_date&order=DESC&acceptance=1&limit=100&offset=100" \
  -H "Accept: application/json"

# 3ページ目（201-300件）
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=補助金&sort=created_date&order=DESC&acceptance=1&limit=100&offset=200" \
  -H "Accept: application/json"
```

### 総件数の確認
```bash
curl -s "..." | jq '.metadata.resultset.count'
# または
curl -s "..." | grep -o '"count" : [0-9]*'
```

---

## よく使う検索パターン

### DX・デジタル化関連
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=acceptance_end_datetime&order=ASC&acceptance=1&use_purpose=設備整備・IT導入をしたい&limit=20" -H "Accept: application/json"
```

### IT導入補助金
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=IT導入&sort=created_date&order=DESC&acceptance=1&limit=10" -H "Accept: application/json"
```

### ものづくり補助金
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=ものづくり&sort=created_date&order=DESC&acceptance=1&industry=製造業&limit=10" -H "Accept: application/json"
```

### 創業支援
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=創業&sort=acceptance_end_datetime&order=ASC&acceptance=1&use_purpose=新たな事業を行いたい&limit=10" -H "Accept: application/json"
```

### 特定地域の補助金
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=支援&sort=created_date&order=DESC&acceptance=1&target_area_search=福井県&limit=10" -H "Accept: application/json"
```

### 小規模事業者向け
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=小規模&sort=acceptance_end_datetime&order=ASC&acceptance=1&target_number_of_employees=20名以下&limit=10" -H "Accept: application/json"
```

---

## jqでの整形・抽出

### タイトルと締切だけ抽出
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=acceptance_end_datetime&order=ASC&acceptance=1&limit=5" \
  -H "Accept: application/json" | jq '.result[] | {title, deadline: .acceptance_end_datetime, max_amount: .subsidy_max_limit}'
```

### 件数確認
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=created_date&order=DESC&acceptance=1&limit=1" \
  -H "Accept: application/json" | jq '.metadata.resultset.count'
```

### 補助金上限額でフィルタ（100万円以上）
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=created_date&order=DESC&acceptance=1&limit=50" \
  -H "Accept: application/json" | jq '[.result[] | select(.subsidy_max_limit >= 1000000)]'
```

### CSVライクな出力
```bash
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=acceptance_end_datetime&order=ASC&acceptance=1&limit=10" \
  -H "Accept: application/json" | jq -r '.result[] | [.title, .acceptance_end_datetime, .subsidy_max_limit] | @csv'
```

---

## 注意事項

### パラメータ制約
1. **キーワード制約**: 2〜255文字、空白を含めない
2. **複数値の区切り**: ` / `（半角スペース＋スラッシュ＋半角スペース）
3. **URLエンコード**: 日本語パラメータはURLエンコード必須（curlは自動変換）

### acceptance パラメータの制限
> ⚠️ **重要**: 公開APIは`acceptance=1`（受付中）のみサポート。
> `acceptance=0`や省略は**400 Bad Request**を返す。

受付終了の補助金を取得するには：
- `acceptance=1`で取得後、`acceptance_end_datetime`が過去のものをアプリ側でフィルタリング
- または、デジタル庁のMCPサーバーを使用

### エラーハンドリング
| HTTPステータス | 原因 | 対処 |
|---------------|------|------|
| 400 | パラメータ不正 | keyword長さ、acceptance値を確認 |
| 500 | サーバーエラー | リトライ推奨 |
| 詳細APIでJSONパースエラー | 一部IDで不正なJSON | try/catchで保護 |

### レート制限
- 明示的な制限なし
- 過度なリクエストは避ける（1秒間隔推奨）

---

## 関連リソース

- [Jグランツ APIドキュメント](https://developers.digital.go.jp/documents/jgrants/api/)
- [デジタル庁 Jグランツ MCP Server](https://github.com/digital-go-jp/jgrants-mcp-server)
- [Jグランツポータル](https://www.jgrants-portal.go.jp/)
- [デジタル庁開発者ポータル](https://developers.digital.go.jp/)

---

## チェックリスト

### API呼び出し前
- [ ] キーワードが2〜255文字の範囲に収まっているか
- [ ] `acceptance=1` を指定しているか（省略すると400エラー）
- [ ] 複数値の区切りが ` / `（半角スペース＋スラッシュ＋半角スペース）になっているか

### レスポンス処理
- [ ] `metadata.resultset.count` で総件数を確認したか
- [ ] ページネーションが必要な場合、offset を使って全件取得しているか
- [ ] 金額フィルタ（`subsidy_max_limit_from/to`）の結果をクライアント側で再検証したか
- [ ] 受付終了日時（`acceptance_end_datetime`）が未来かどうか確認したか

---

## トラブルシューティング

### Q: 400 Bad Request が返る
**A:** 主に以下の原因が考えられます。(1) `acceptance` パラメータが `1` 以外になっている（省略もNG）、(2) `keyword` が2文字未満または255文字超、(3) キーワードに空白が含まれている。パラメータを一つずつ確認してください。

### Q: 検索結果が期待より少ない
**A:** 地域を広域名（「関東・甲信越地方」等）で指定すると該当件数が少ない場合があります。都道府県名での検索を推奨します。また、キーワードを短く一般的な語（「DX」「支援」等）にすると件数が増えます。

### Q: 補助金の詳細取得でJSONパースエラーが発生する
**A:** 一部の補助金IDで不正なJSONが返される既知の問題があります。`try/catch` で保護し、エラー発生時はポータルサイトURL（`front_subsidy_detail_page_url`）からブラウザで確認する方法にフォールバックしてください。

---

## 関連スキル

- **gbizinfo** -- 法人情報API（企業調査の補完）。補助金申請を検討する企業の基本情報・財務情報・過去の補助金受給実績をgBizINFOで確認
- **usacon** -- 補助金情報のコンサルティング活用。DXコンサルティングにおいて顧客企業への補助金提案に利用
- **mba-strategy-consultant** -- 経営戦略フレームワーク。補助金活用を含む成長戦略立案の一環として連携

---

## 改訂履歴

| 日付 | 版 | 変更内容 |
|------|-----|----------|
| 2025-09-01 | v1.0 | 初版作成。エンドポイント、検索パラメータ、レスポンス構造、ページネーション、よく使う検索パターンを収録 |
| 2026-03-04 | v1.1 | チェックリスト、トラブルシューティング、関連スキル、改訂履歴を追加 |
