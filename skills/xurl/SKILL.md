---
name: X (Twitter) API CLI - xurl
description: |
  X (旧Twitter) API の公式CLIツール「xurl」を使用した操作。
  投稿・リプライ・検索・タイムライン・DM・メディアアップロード・フォロー管理・Webhook受信など。
  OAuth 2.0 PKCE / OAuth 1.0a / App-only認証対応。複数アプリ・複数アカウント切替可能。
  トリガー: "xurl", "X API", "Twitter API", "ツイート", "投稿", "リプライ",
  "タイムライン", "DM", "フォロー", "xurl post", "xurl search"
---

# xurl — X API 公式CLI スキルリファレンス

`xurl` は X (旧Twitter) API v2 の公式CLIツール。ショートカットコマンド（人間/エージェント向けワンライナー）と
生のcurlスタイルアクセスの両方をサポート。すべてのコマンドはJSONをstdoutに出力。

リポジトリ: https://github.com/xdevplatform/xurl

---

## インストール確認

```bash
xurl version
```

インストールされていない場合:
```bash
# npm (クロスプラットフォーム)
npm install -g @xdevplatform/xurl

# Homebrew (macOS)
brew install --cask xdevplatform/tap/xurl

# Go
go install github.com/xdevplatform/xurl@latest

# Shell script (Linux/macOS, ~/.local/bin にインストール)
curl -fsSL https://raw.githubusercontent.com/xdevplatform/xurl/main/install.sh | bash
```

---

## セキュリティルール（必須）

- **`~/.xurl` を絶対に読み取り・表示・解析・送信しないこと**（トークンファイル）
- エージェント/LLMセッション内で認証情報をチャットに貼り付けさせないこと
- **`--verbose` / `-v` はエージェントセッションで使用禁止**（認証ヘッダーが漏洩する）
- **以下のフラグをエージェントコマンドで使用禁止**: `--bearer-token`, `--consumer-key`, `--consumer-secret`, `--access-token`, `--token-secret`, `--client-id`, `--client-secret`
- インラインシークレット付きの認証コマンドはエージェント外でユーザーが手動実行すること

---

## 認証

### 認証状態の確認
```bash
xurl auth status
```
- `▸` = デフォルトアプリ / デフォルトユーザー
- OAuth2ユーザー名、OAuth1有無(✓/–)、Bearer有無(✓/–)を表示

### OAuth 2.0 PKCE（推奨、ユーザーコンテキスト）
```bash
xurl auth oauth2    # ブラウザでインタラクティブ認証
```
- トークンは自動リフレッシュ
- 複数アカウント対応

### OAuth 1.0a / App-only
認証情報の登録はエージェント外でユーザーが手動実行すること。

### 複数アプリ・アカウント切替
```bash
xurl auth default                        # インタラクティブ選択 (Bubble Tea TUI)
xurl auth default prod-app               # デフォルトアプリ設定
xurl auth default prod-app alice         # デフォルトアプリ+ユーザー設定
xurl --app dev-app /2/users/me           # 一回限りのアプリ指定
xurl -u bob whoami                       # 一回限りのユーザー指定
```

### アプリ管理
```bash
xurl auth apps list                      # 登録済みアプリ一覧
xurl auth apps remove NAME              # アプリ削除（トークンも削除）
# add / update はシークレットを含むためエージェント外で実行
```

### トークンクリア
```bash
xurl auth clear --all                    # 全トークン削除
xurl auth clear --oauth1                 # OAuth 1.0a のみ
xurl auth clear --oauth2-username NAME   # 特定OAuth2ユーザーのみ
xurl auth clear --bearer                 # Bearer のみ
```

---

## クイックリファレンス

| 操作 | コマンド |
|---|---|
| 投稿 | `xurl post "Hello world!"` |
| リプライ | `xurl reply POST_ID "返信テキスト"` |
| 引用 | `xurl quote POST_ID "引用コメント"` |
| 削除 | `xurl delete POST_ID` |
| 読み取り | `xurl read POST_ID` |
| 検索 | `xurl search "QUERY" -n 10` |
| 自分の情報 | `xurl whoami` |
| ユーザー検索 | `xurl user @handle` |
| タイムライン | `xurl timeline -n 20` |
| メンション | `xurl mentions -n 10` |
| いいね | `xurl like POST_ID` |
| いいね解除 | `xurl unlike POST_ID` |
| リポスト | `xurl repost POST_ID` |
| リポスト解除 | `xurl unrepost POST_ID` |
| ブックマーク | `xurl bookmark POST_ID` |
| ブックマーク解除 | `xurl unbookmark POST_ID` |
| ブックマーク一覧 | `xurl bookmarks -n 10` |
| いいね一覧 | `xurl likes -n 10` |
| フォロー | `xurl follow @handle` |
| フォロー解除 | `xurl unfollow @handle` |
| フォロー中一覧 | `xurl following -n 20` |
| フォロワー一覧 | `xurl followers -n 20` |
| ブロック | `xurl block @handle` |
| ブロック解除 | `xurl unblock @handle` |
| ミュート | `xurl mute @handle` |
| ミュート解除 | `xurl unmute @handle` |
| DM送信 | `xurl dm @handle "メッセージ"` |
| DM一覧 | `xurl dms -n 10` |
| メディアアップロード | `xurl media upload path/to/file.mp4` |
| メディアステータス | `xurl media status MEDIA_ID` |

> **POST_ID vs URL**: `POST_ID` の箇所には `https://x.com/user/status/1234567890` のような完全URLも使用可能。xurlが自動でIDを抽出する。

> **ユーザー名**: 先頭の `@` は省略可能。`@elonmusk` と `elonmusk` のどちらでも動作する。

---

## コマンド詳細

### 投稿

```bash
# シンプル投稿
xurl post "Hello world!"

# メディア付き投稿（先にアップロード→メディアID取得→添付）
xurl media upload photo.jpg
xurl post "Check this out" --media-id MEDIA_ID

# 複数メディア
xurl post "Thread pics" --media-id 111 --media-id 222

# リプライ（IDまたはURL）
xurl reply 1234567890 "Great point!"
xurl reply https://x.com/user/status/1234567890 "Agreed!"

# リプライ + メディア
xurl reply 1234567890 "Look at this" --media-id MEDIA_ID

# 引用
xurl quote 1234567890 "Adding my thoughts"

# 自分の投稿を削除
xurl delete 1234567890
```

### 読み取り・検索

```bash
# 単一投稿を読む（著者、テキスト、メトリクス、エンティティ付き）
xurl read 1234567890
xurl read https://x.com/user/status/1234567890

# 最近の投稿を検索（デフォルト10件、最大100件）
xurl search "golang"
xurl search "from:elonmusk" -n 20
xurl search "#buildinpublic lang:en" -n 15
```

### ユーザー情報

```bash
xurl whoami                  # 自分のプロフィール
xurl user elonmusk           # 任意のユーザー
xurl user @XDevelopers       # @付きも可
```

### タイムライン・メンション

```bash
xurl timeline                # ホームタイムライン（時系列逆順）
xurl timeline -n 25          # 件数指定（1-100）

xurl mentions                # 自分へのメンション
xurl mentions -n 20          # 件数指定（5-100）
```

### エンゲージメント

```bash
xurl like POST_ID            # いいね
xurl unlike POST_ID          # いいね解除
xurl repost POST_ID          # リポスト
xurl unrepost POST_ID        # リポスト解除
xurl bookmark POST_ID        # ブックマーク
xurl unbookmark POST_ID      # ブックマーク解除
xurl bookmarks -n 20         # ブックマーク一覧（1-100）
xurl likes -n 20             # いいね一覧（1-100）
```

### ソーシャルグラフ

```bash
xurl follow @XDevelopers     # フォロー
xurl unfollow @XDevelopers   # フォロー解除

xurl following -n 50         # 自分のフォロー中（1-1000）
xurl followers -n 50         # 自分のフォロワー（1-1000）

# 他ユーザーのフォロー/フォロワー
xurl following --of elonmusk -n 20
xurl followers --of elonmusk -n 20

xurl block @spammer          # ブロック
xurl unblock @spammer        # ブロック解除
xurl mute @annoying          # ミュート
xurl unmute @annoying        # ミュート解除
```

### ダイレクトメッセージ

```bash
xurl dm @someuser "Hey!"     # DM送信
xurl dms                     # DM一覧
xurl dms -n 25               # 件数指定（1-100）
```

### メディアアップロード

```bash
# アップロード（画像/動画を自動検出）
xurl media upload photo.jpg
xurl media upload video.mp4

# タイプ・カテゴリを明示
xurl media upload --media-type image/jpeg --category tweet_image photo.jpg

# 処理ステータス確認（動画はサーバー側処理が必要）
xurl media status MEDIA_ID
xurl media status --wait MEDIA_ID    # 完了までポーリング

# ワークフロー: アップロード → 投稿
xurl media upload meme.png           # レスポンスの media_id を取得
xurl post "lol" --media-id MEDIA_ID
```

---

## グローバルフラグ

すべてのコマンドで使用可能:

| フラグ | 短縮 | 説明 |
|---|---|---|
| `--app` | | 特定の登録済みアプリを使用（デフォルトを一時上書き） |
| `--auth` | | 認証タイプ強制: `oauth1`, `oauth2`, `app` |
| `--username` | `-u` | 使用するOAuth2アカウントを指定（複数アカウント時） |
| `--trace` | `-t` | `X-B3-Flags: 1` トレースヘッダーを追加 |
| `--stream` | `-s` | 任意のエンドポイントでストリーミングモードを強制 |
| `--verbose` | `-v` | **エージェントセッションでは使用禁止** |

---

## Raw APIアクセス

ショートカットでカバーされていないエンドポイントにはcurlスタイルでアクセス:

```bash
# GET（デフォルト）
xurl /2/users/me

# POST + JSONボディ
xurl -X POST /2/tweets -d '{"text":"Hello world!"}'

# DELETE
xurl -X DELETE /2/tweets/1234567890

# カスタムヘッダー
xurl -H "Content-Type: application/json" /2/some/endpoint

# フルURLも可
xurl https://api.x.com/2/users/me

# ストリーミング強制
xurl -s /2/tweets/search/stream
```

### 自動ストリーミングエンドポイント
以下は自動的にストリーミングモードで実行:
- `/2/tweets/search/stream`
- `/2/tweets/sample/stream`
- `/2/tweets/sample10/stream`
- `/2/tweets/firehose/stream` (+ 言語別: `/lang/en`, `/lang/ja`, `/lang/ko`, `/lang/pt`)

---

## Webhook受信

```bash
xurl webhook start                       # デフォルト: port 8080
xurl webhook start -p 3000              # ポート指定
xurl webhook start -o events.json       # イベントをファイルに追記
xurl webhook start -q                   # Quiet（ボディ非表示）
xurl webhook start -P                   # Pretty-print JSON
```
- OAuth 1.0a の consumer secret が必要（CRCハンドシェイク用）
- ngrok authtoken の入力を求められる（`NGROK_AUTHTOKEN` 環境変数でも可）

---

## 出力形式

すべてのコマンドはJSON（シンタックスハイライト付きpretty-print）をstdoutに出力。

成功時:
```json
{
  "data": {
    "id": "1234567890",
    "text": "Hello world!"
  }
}
```

エラー時（非ゼロ終了コード）:
```json
{
  "errors": [
    {
      "message": "Not authorized",
      "code": 403
    }
  ]
}
```

---

## よくあるワークフロー

### 画像付き投稿
```bash
xurl media upload photo.jpg              # → media_id を取得
xurl post "Check this out!" --media-id MEDIA_ID
```

### 会話に返信
```bash
xurl read https://x.com/user/status/123  # コンテキスト確認
xurl reply 123 "Here are my thoughts..."
```

### 検索してエンゲージ
```bash
xurl search "topic" -n 10               # 投稿検索
xurl like POST_ID                        # いいね
xurl reply POST_ID "Great point!"        # 返信
```

### アクティビティ確認
```bash
xurl whoami                              # 自分の情報
xurl mentions -n 20                      # メンション確認
xurl timeline -n 20                      # タイムライン確認
```

---

## 注意事項

- **レート制限**: X API はエンドポイントごとにレート制限あり。429エラー時は待機してリトライ。書き込み系（post, like, repost）は読み取り系より厳しい
- **スコープ**: OAuth 2.0 で 403 エラーが出た場合、トークンのスコープ不足の可能性あり。`xurl auth oauth2` で再認証
- **トークンリフレッシュ**: OAuth 2.0 トークンは期限切れ時に自動リフレッシュ
- **トークン保存**: `~/.xurl` (YAML形式)。エージェントから読み取り禁止
- **`-n` 制限値**: search (10-100), timeline (1-100), mentions (5-100), bookmarks/likes (1-100), following/followers (1-1000), dms (1-100)
