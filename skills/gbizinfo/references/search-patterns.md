<!-- 抽出元: SKILL.md のセクション「基本コマンド」「よく使う検索パターン」「jqでの整形・抽出」「Usacon統合パターン」「トラブルシューティング」「チェックリスト」 -->

# gBizINFO 検索パターン集

## 基本コマンド

### 法人名で検索
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=トヨタ&page=1&limit=10" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 法人番号で基本情報を取得
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1010401089234" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 特定法人の補助金情報
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1010401089234/subsidy" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 特定法人の財務情報
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1010401089234/finance" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 特定法人の全情報を一括取得（並列）
```bash
CN="1010401089234"
BASE="https://api.info.gbiz.go.jp/hojin/v1/hojin/$CN"

for ep in "" "/certification" "/commendation" "/finance" "/patent" "/procurement" "/subsidy" "/workplace"; do
  curl -s "${BASE}${ep}" \
    -H "Accept: application/json" \
    -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" &
done
wait
```

---

## よく使う検索パターン

### 企業名で検索（基本）
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=ソニー&page=1&limit=10" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 東京都の株式会社を検索（資本金1億円以上）
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=テクノロジー&corporate_type=301&prefecture=13&capital_stock_from=100000000&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 若い企業を検索（平均年齢31~45歳 + 活動情報あり）
```bash
curl -sG "https://api.info.gbiz.go.jp/hojin/v1/hojin" \
  --data-urlencode "name=テクノロジー" \
  --data-urlencode "average_age=B" \
  --data-urlencode "exist_flg=true" \
  --data-urlencode "page=1" \
  --data-urlencode "limit=100" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 売上高10億円以上の企業を検索
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=製造&net_sales_summary_of_business_results_from=1000000000&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 大株主名で検索
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=ホールディングス&name_major_shareholders=トヨタ&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 補助金・特許を持つ企業に絞り込み
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=バイオ&source=4,5&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 取引先の補助金受給実績を確認
```bash
# 1. まず法人番号を検索
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=株式会社サンプル&page=1&limit=5" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][] | {name, corporate_number}'

# 2. 法人番号で補助金情報を取得
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1234567890123/subsidy" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

### 取引先の財務状況を確認
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1234567890123/finance" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][0].finance'
```

### 取引先の認定・資格を確認
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1234567890123/certification" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][0].certification'
```

### 特許情報から技術力を評価
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1234567890123/patent" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][0].patent | length'
```

### v2: corporationエンドポイント（v2新規）
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v2/hojin/1010401089234/corporation" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

---

## jqでの整形・抽出

### 法人名と法人番号の一覧
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=AI&corporate_type=301&prefecture=13&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][] | {name, corporate_number, capital_stock, employee_number}'
```

### 資本金でソート（降順）
```bash
curl -s "..." | jq '[.["hojin-infos"][] | {name, capital_stock: (.capital_stock // 0)}] | sort_by(-.capital_stock)'
```

### CSVライクな出力
```bash
curl -s "..." | jq -r '.["hojin-infos"][] | [.corporate_number, .name, .location, .capital_stock, .employee_number] | @csv'
```

---

## Usacon統合パターン

### 顧問先企業の情報収集
```bash
# 法人番号がわかっている場合、基本情報+財務+補助金を一括取得
CN="1234567890123"

# 基本情報
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/$CN" \
  -H "Accept: application/json" -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" > /tmp/gbiz_basic.json

# 財務情報
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/$CN/finance" \
  -H "Accept: application/json" -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" > /tmp/gbiz_finance.json

# 補助金情報
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/$CN/subsidy" \
  -H "Accept: application/json" -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" > /tmp/gbiz_subsidy.json

# 統合レポート出力
jq -s '{
  basic: .[0]["hojin-infos"][0] | {name, location, capital_stock, employee_number, business_summary},
  finance: .[1]["hojin-infos"][0].finance,
  subsidies: .[2]["hojin-infos"][0].subsidy
}' /tmp/gbiz_basic.json /tmp/gbiz_finance.json /tmp/gbiz_subsidy.json

# クリーンアップ
rm -f /tmp/gbiz_basic.json /tmp/gbiz_finance.json /tmp/gbiz_subsidy.json
```

### Jグランツ連携: 補助金検索 → 企業調査
```bash
# 1. Jグランツで受付中の補助金を検索
curl -s "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies?keyword=DX&sort=acceptance_end_datetime&order=ASC&acceptance=1&limit=5" \
  -H "Accept: application/json" | jq '.result[] | {title, deadline: .acceptance_end_datetime}'

# 2. gBizINFOで顧問先の補助金受給実績を確認（適格性の参考に）
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin/1234567890123/subsidy" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN" | jq '.["hojin-infos"][0].subsidy'
```

---

## チェックリスト

### API呼び出し前
- [ ] 法人番号が13桁の正しい形式か確認したか
- [ ] APIトークンが環境変数（`$GBIZINFO_TOKEN`）に設定されているか
- [ ] `name` または `corporate_number` のいずれかを必須パラメータとして指定しているか
- [ ] 都道府県コードがJIS X 0401準拠の2桁数字か確認したか

### レスポンス処理
- [ ] APIレスポンスのページネーションを考慮したか（`page` 上限10、`limit` 上限5000）
- [ ] JSONキーにハイフンが含まれる `hojin-infos` にブラケット記法でアクセスしているか
- [ ] 中小企業の場合、財務情報が未登録の可能性を考慮したか
- [ ] v1 API廃止（2026年9月予定）に備えてv2への移行を検討したか

---

## トラブルシューティング

### Q: 500エラーが返る
**A:** 多くの場合、APIトークンの不正または期限切れが原因です。Swagger UIでは401と定義されていますが、実際には500を返す場合があります。トークンを再確認し、必要であれば再取得してください。

### Q: 検索結果が0件になる
**A:** (1) `name` パラメータの文字列が正式名称と異なる場合があります（「(株)」vs「株式会社」等）。部分一致ですが、より短いキーワードで試してください。(2) `exist_flg=true` を指定すると活動情報がある法人のみに絞り込まれるため、条件を緩めてみてください。

### Q: ページネーションで全件取得できない
**A:** `page` の上限は10です。最大取得件数は 10ページ x 5000件 = 50,000件です。それ以上の結果が必要な場合は、検索条件（都道府県、資本金範囲等）を絞り込んで複数回に分けて検索してください。

### Q: レート制限に引っかかった
**A:** 10分間に約6,000リクエストのソフトリミットがあります。超過すると10分間ブロックされます。5,000リクエストごとに10分の間隔を空けることを推奨します。
