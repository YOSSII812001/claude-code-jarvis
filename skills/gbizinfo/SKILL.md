---
name: gBizINFO API
description: |
  経済産業省のgBizINFO REST API。法人番号で企業の基本情報・届出認定・表彰・財務・特許・調達・補助金・職場情報を取得。企業調査・取引先分析・コンサルティングに使用。
  トリガー: "gbizinfo", "法人情報", "企業調査", "法人番号", "gBizINFO", "企業情報API"
---

# gBizINFO REST API ガイド

## 概要

経済産業省・デジタル庁が提供するgBizINFO（法人活動情報）のREST APIを使用して、約400万法人の企業情報を検索・取得する。

| 項目 | 値 |
|------|-----|
| ベースURL（v1） | `https://api.info.gbiz.go.jp/hojin` |
| 認証 | **APIトークン必須**（無料登録） |
| トークン申請 | https://info.gbiz.go.jp/hojin/api_registration/form |
| ポータル | https://info.gbiz.go.jp/ |
| Swagger UI | https://api.info.gbiz.go.jp/hojin/swagger-ui/index.html |
| OpenAPI v1 | https://api.info.gbiz.go.jp/hojin/v3/api-docs/v1 |
| OpenAPI v2 | https://api.info.gbiz.go.jp/hojin/v3/api-docs/v2 |
| METI概要 | https://www.meti.go.jp/policy/digital_transformation/gbizinfo/ |

> **v2移行情報**: 2026年1月26日にv2 APIが稼働開始。**v1 APIは2026年9月に廃止予定**。
> 新ポータル: https://content.info.gbiz.go.jp/api/index.html
> v1→v2変更点: https://info.gbiz.go.jp/html/v1->v2変更点一覧.pdf

---

## 認証

APIトークンを全リクエストのヘッダーに含める。

| ヘッダー名 | 値 |
|-----------|-----|
| `X-hojinInfo-api-token` | 登録で取得したトークン文字列 |
| `Accept` | `application/json` |

### トークン取得手順
1. https://info.gbiz.go.jp/hojin/api_registration/form にアクセス
2. 利用目的・連絡先等を入力して申請
3. メールでAPIトークンが発行される（無料）

### 環境変数に設定（推奨）
```bash
export GBIZINFO_TOKEN="your_token_here"
```

---

## 核心ルール

1. **検索には `name` または `corporate_number` のいずれか1つが必須**
2. **法人番号は13桁の数字**（国税庁法人番号公表サイトで確認可能）
3. **JSONキーにハイフン含み**: `hojin-infos` → ブラケット記法 `data["hojin-infos"]` 必須
4. **ページネーション上限**: `page` 最大10、`limit` 最大5000（最大50,000件）
5. **レート制限**: 10分間に約6,000リクエスト、超過で10分間ブロック
6. **v2移行推奨**: v1は2026年9月廃止予定。新規開発はv2を使用
7. **中小企業の財務情報**: 未登録の場合があるため null チェック必須
8. **トークン管理**: 環境変数 `$GBIZINFO_TOKEN` で管理、ハードコード禁止
9. **500エラー**: 認証エラーが500で返る場合あり（Swagger定義と異なる）
10. **型に注意**: 数値系パラメータも多くがString型としてOpenAPI上定義

---

## 主要エンドポイント（概要）

| 分類 | パス | 説明 |
|------|------|------|
| 法人検索 | `/v1/hojin` | 名前・条件で法人を検索 |
| 基本情報 | `/v1/hojin/{cn}` | 法人番号で基本情報取得 |
| 財務 | `/v1/hojin/{cn}/finance` | 財務情報 |
| 補助金 | `/v1/hojin/{cn}/subsidy` | 補助金情報 |
| 特許 | `/v1/hojin/{cn}/patent` | 特許情報 |
| 認定 | `/v1/hojin/{cn}/certification` | 届出・認定情報 |
| 表彰 | `/v1/hojin/{cn}/commendation` | 表彰情報 |
| 調達 | `/v1/hojin/{cn}/procurement` | 調達情報 |
| 職場 | `/v1/hojin/{cn}/workplace` | 職場情報 |
| 更新情報 | `/v1/hojin/updateInfo` | 期間指定の更新検索 |
| v2新規 | `/v2/hojin/{cn}/corporation` | 法人基本情報（v2拡張） |

---

## クイックスタート

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

### 東京都の株式会社を検索（資本金1億円以上）
```bash
curl -s "https://api.info.gbiz.go.jp/hojin/v1/hojin?name=テクノロジー&corporate_type=301&prefecture=13&capital_stock_from=100000000&page=1&limit=20" \
  -H "Accept: application/json" \
  -H "X-hojinInfo-api-token: $GBIZINFO_TOKEN"
```

---

## 詳細リファレンス

references/api-reference.md
- エンドポイント一覧（v1/v2全件）
- 検索パラメータ全35項目
- 期間指定パラメータ
- レスポンス構造（HojinInfoResponse、エラー形式）
- 基本情報フィールド一覧（HojinInfo）
- ページネーション詳細
- v1/v2 対応表・v2追加パラメータ
- レート制限・エラーハンドリング

references/code-tables.md
- 法人種別コード（corporate_type: 101〜499）
- 都道府県コード（JIS X 0401: 01〜47）
- コード区分一覧（平均年齢、勤務年数、残業時間、女性割合）
- 出典元コード（source: 1〜6）
- 外部コードリスト（PDF）へのリンク

references/search-patterns.md
- 基本コマンド集（名前検索、番号取得、並列取得）
- よく使う検索パターン（財務フィルタ、大株主、補助金・特許）
- 取引先調査パターン（補助金実績、財務状況、認定・資格、特許）
- jqでの整形・抽出（一覧、ソート、CSV出力）
- Usacon統合パターン（顧問先情報収集、Jグランツ連携）
- チェックリスト（API呼び出し前 / レスポンス処理）
- トラブルシューティング（500エラー、0件、ページネーション、レート制限）

---

## 注意事項

1. **トークン管理**: APIトークンは環境変数で管理し、コードにハードコードしない
2. **ハイフン付きキー**: JSONレスポンスの`hojin-infos`はハイフン含み。ブラケット記法必須
3. **データ網羅性**: 全法人の全データが揃っているわけではない。特に中小企業は財務情報が未登録の場合がある
4. **v2移行**: v1は2026年9月廃止予定。新規開発はv2を推奨
5. **page上限**: 検索の`page`は最大10。それ以上の結果は検索条件を絞り込んで対応
6. **型に注意**: 数値系パラメータも多くがString型（数字パターン）としてOpenAPI上定義されている

---

## 関連スキル

- **jgrants** -- 補助金検索API（企業の補助金受給状況）。gBizINFOで取得した企業情報と、Jグランツの受付中補助金情報を組み合わせてコンサルティングに活用
- **usacon** -- 企業調査データのコンサルティング活用。DXコンサルティングにおける顧客企業の財務・認定・補助金情報の分析に利用
- **mba-strategy-consultant** -- 経営戦略フレームワーク。企業の財務データやポジショニング分析にgBizINFO情報を活用

---

## 関連リソース

- [gBizINFO ポータル](https://info.gbiz.go.jp/)
- [API利用ガイド](https://info.gbiz.go.jp/hojin/APIManual)
- [Swagger UI](https://api.info.gbiz.go.jp/hojin/swagger-ui/index.html)
- [新ポータル（v2）](https://content.info.gbiz.go.jp/api/index.html)
- [APIポリシー（PDF）](https://info.gbiz.go.jp/api-spec/document/policy.pdf)
- [コードリスト（PDF）](https://info.gbiz.go.jp/codelist/document/codelist.pdf)
- [担当府省コードリスト（PDF）](https://info.gbiz.go.jp/common/data/setcodelist.pdf)
- [METI gBizINFO概要](https://www.meti.go.jp/policy/digital_transformation/gbizinfo/)
- [国税庁法人番号公表サイト](https://www.houjin-bangou.nta.go.jp/)
- [Jグランツ API（補助金検索）](/jgrants) - 補助金の検索はJグランツが適切

---

## 改訂履歴

| 日付 | 版 | 変更内容 |
|------|-----|----------|
| 2025-10-01 | v1.0 | 初版作成。エンドポイント一覧、検索パラメータ（35項目）、レスポンス構造、コード区分、Usacon統合パターンを収録 |
| 2026-02-28 | v1.1 | v2 API情報を追加（2026年1月26日稼働開始）。v1廃止予定（2026年9月）を注記 |
| 2026-03-04 | v1.2 | frontmatterにトリガーを追加。チェックリスト、トラブルシューティング、関連スキル、改訂履歴を追加 |
| 2026-03-05 | v2.0 | references/に分割リファクタリング。SKILL.mdをエントリーポイント化 |
