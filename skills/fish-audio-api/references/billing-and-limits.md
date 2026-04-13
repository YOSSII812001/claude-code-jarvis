# 料金体系 & レート制限

## 料金

| サービス | 単価 | 備考 |
|---------|------|------|
| TTS | $15.00 / 百万 UTF-8 バイト | 約18万英単語 ≈ 約12時間音声 |
| STT | $0.36 / 秒 | 秒単位で丸め |

### コスト計算例

```
# TTS
テキスト: "Hello, world!" (13 UTF-8 bytes)
コスト: 13 / 1,000,000 * $15.00 = $0.000195

# TTS（日本語）
テキスト: "こんにちは" (15 UTF-8 bytes, 各文字3バイト)
コスト: 15 / 1,000,000 * $15.00 = $0.000225

# STT
音声長: 30秒
コスト: 30 * $0.36 = $10.80
```

## 同時実行リミット

| ティア | 先払い累計額 | 同時実行数 |
|--------|------------|-----------|
| Starter | < $100 | 5 |
| Elevated | ≥ $100 | 15 |
| High Volume | ≥ $1,000 | 50 |
| Enterprise | カスタム | カスタム |

- ティアは **先払い累計額に到達した時点で即アンロック**される（残高は不要）
- 同時実行数を超えると `429 Too Many Requests` が返される
- Enterprise プランの問い合わせ: support@fish.audio

## API Credit エンドポイント

### `GET /wallet/{user_id}/api-credit`

APIクレジット残高を取得する。

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| user_id | string（パス） | — | `"self"` で認証ユーザー |
| check_free_credit | boolean（クエリ） | `false` | 無料クレジットの確認 |

#### レスポンス (200)

```json
{
  "credit": 45.50,
  "has_free_credit": false
}
```

#### コード例

```bash
# cURL
curl "https://api.fish.audio/wallet/self/api-credit" \
  -H "Authorization: Bearer $FISH_API_KEY"

# 無料クレジット確認付き
curl "https://api.fish.audio/wallet/self/api-credit?check_free_credit=true" \
  -H "Authorization: Bearer $FISH_API_KEY"
```

```python
# Python
credit = session.get_api_credit(user_id="self")
print(f"残高: ${credit.credit:.2f}")
```

```javascript
// JavaScript
const credit = await client.getApiCredit({ userId: "self" });
console.log(`残高: $${credit.credit.toFixed(2)}`);
```

## Package エンドポイント

### `GET /wallet/{user_id}/package`

契約パッケージ情報を取得する。

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| user_id | string（パス） | `"self"` で認証ユーザー |

#### レスポンス (200)

```json
{
  "type": "elevated",
  "total": 100.00,
  "balance": 45.50,
  "finished_at": "2025-12-31T23:59:59Z"
}
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| type | string | パッケージティア |
| total | float | 総額 |
| balance | float | 残高 |
| finished_at | string | 有効期限（ISO 8601） |

#### コード例

```bash
# cURL
curl "https://api.fish.audio/wallet/self/package" \
  -H "Authorization: Bearer $FISH_API_KEY"
```

```python
# Python
package = session.get_package(user_id="self")
print(f"ティア: {package.type}, 残高: ${package.balance:.2f}")
```

```javascript
// JavaScript
const pkg = await client.getPackage({ userId: "self" });
console.log(`ティア: ${pkg.type}, 残高: $${pkg.balance.toFixed(2)}`);
```
