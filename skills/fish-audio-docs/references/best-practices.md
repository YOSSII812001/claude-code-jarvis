# Best Practices — Fish Audio

## レート制限回避

### プランごとの同時実行制限

| プラン | 同時リクエスト数 |
|---|---|
| Free | 5 |
| Pro | 15 |
| Enterprise | 50 |

### 指数バックオフ

429（Too Many Requests）が返された場合のリトライ戦略:

```python
import time

def with_backoff(func, max_retries=5):
    for attempt in range(max_retries):
        try:
            return func()
        except RateLimitError:
            delay = (2 ** attempt) + random.uniform(0, 1)
            time.sleep(delay)
    raise Exception("Max retries exceeded")
```

### バッチ処理

大量のテキストを処理する場合:

- 同時実行数をプランの制限以下に抑える
- 各リクエスト間に最低100msの間隔
- キューイングシステム（Redis Queue等）の活用を検討

## コスト最適化

### 料金体系

| サービス | 料金 |
|---|---|
| TTS | $15 / 百万 UTF-8 バイト |
| STT | $4.8 / 時間 |
| Voice Clone | モデル作成無料、使用はTTS料金 |

### テキスト最適化

- 不要な空白・改行を除去（UTF-8バイト数に影響）
- 長いテキストは適切なチャンクに分割（200文字推奨）
- 同じテキスト+ボイスの組み合わせはキャッシュ

## 音声品質向上

### テキスト準備

- **適切な句読点**: ピリオド、カンマで自然なポーズを挿入
- **略語展開**: "Dr." → "Doctor"、"etc." → "et cetera"
- **数字の記述**: コンテキストに応じて文字に変換
- **特殊文字回避**: 音声化できない記号は除去

### パラメータ調整

| 目的 | temperature | top_p | 備考 |
|---|---|---|---|
| 安定した出力 | 0.3-0.5 | 0.7 | ナレーション向き |
| 自然な表現 | 0.6-0.8 | 0.8 | 会話向き |
| 多様な表現 | 0.8-1.0 | 0.9 | クリエイティブ用途 |

### 感情マーカー活用

- 文頭に `[emotion]` を配置して表現力を向上
- 1文に1感情で制御性を維持
- 感情の段階的遷移で自然さを保つ

### Prosody 調整

- `speed`: 0.9-1.1 の範囲が最も自然
- `volume`: 大きな変更は歪みの原因。+-5 以内推奨

## エラーリトライ戦略

| ステータスコード | リトライ | 対処 |
|---|---|---|
| 429 (Rate Limit) | 可 | 指数バックオフで再試行 |
| 500 (Server Error) | 可 | 1-2回のみ再試行 |
| 401 (Unauthorized) | 不可 | APIキーを確認 |
| 422 (Validation) | 不可 | リクエストパラメータを修正 |
| 413 (Payload Too Large) | 不可 | テキストを分割 |

## キャッシュ戦略

同一テキスト+ボイスの組み合わせは同じ音声を返すため、キャッシュが有効:

```python
import hashlib

def cache_key(text: str, voice_id: str, format: str) -> str:
    content = f"{text}:{voice_id}:{format}"
    return hashlib.sha256(content.encode()).hexdigest()

# Redis / ファイルシステム / CDN でキャッシュ
```

### キャッシュ推奨箇所

- **フロントエンド**: ブラウザの Cache API / IndexedDB
- **バックエンド**: Redis / Memcached
- **CDN**: 静的音声ファイルとしてCDN配信

## セキュリティ

### APIキー管理

- **環境変数**で管理（`.env` ファイル）
- バージョン管理（Git）に**含めない**
- `.gitignore` に `.env` を追加
- サーバーサイドからのみ使用（フロントエンドに露出させない）

```bash
# .env
FISH_API_KEY=your-api-key-here
```

```gitignore
# .gitignore
.env
.env.local
.env.production
```

### フロントエンド対策

- APIキーをフロントエンドに埋め込まない
- バックエンドのプロキシAPI経由でリクエスト
- CORS 設定で許可するオリジンを制限

## Voice Cloning 権利管理

### 必須事項

- **自身の声**: 自由に使用可能
- **他者の声**: 書面による明示的な同意を取得
- **公人の声**: 無断での複製・使用は禁止
- **商用利用**: 権利関係を事前に確認

### 記録の保持

- 同意書のコピーを保管
- 音声サンプルの出典を記録
- 使用目的と範囲を明文化
