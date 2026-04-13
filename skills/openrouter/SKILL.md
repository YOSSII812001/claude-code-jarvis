---
name: openrouter
description: |
  OpenRouter API経由で複数のLLMモデル（Grok 4.20, GLM5.1, Qwen3-Coder, Qwen3.6-plus等）にクエリを送信。
  単一モデルへの質問と、複数モデルの並列比較の両方に対応。
  トリガー: "openrouter", "OpenRouter", "/openrouter", "openrouter compare"
---

# OpenRouter API スキル

OpenRouter API（OpenAI互換）を使用して、複数LLMプロバイダーのモデルにClaude Code内からクエリを送信する。

| 項目 | 値 |
|------|-----|
| エンドポイント | `https://openrouter.ai/api/v1/chat/completions` |
| モデル一覧 | `https://openrouter.ai/api/v1/models` |
| 認証 | `Authorization: Bearer $OPENROUTER_API_KEY` |
| クレジット確認 | https://openrouter.ai/settings/credits |

---

## セキュリティルール（必須）

1. `$OPENROUTER_API_KEY` をコマンド出力・チャット・ログに **絶対に表示しない**
2. curlの `-H "Authorization: ..."` 部分は変数参照のまま実行（展開後の値を表示しない）
3. APIキーをファイルにハードコードしない

---

## 前提条件

### APIキー

`OPENROUTER_API_KEY` はWindowsユーザー環境変数として永続設定済み。
claude-code-router（ccr）の config.json からも `$OPENROUTER_API_KEY` で参照される。

APIキーの確認:
```bash
if [ -n "$OPENROUTER_API_KEY" ]; then echo "OK: OPENROUTER_API_KEY is set"; else echo "ERROR: OPENROUTER_API_KEY is not set"; fi
```

APIキー未設定の場合:
1. https://openrouter.ai/settings/keys でAPIキーを取得
2. Windowsユーザー環境変数に設定:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "sk-or-v1-...", "User")
   ```
3. 新しいターミナルを開いて反映を確認

---

## モデルエイリアス表

| エイリアス | 完全モデルID | 備考 |
|-----------|-------------|------|
| `grok-4.20` | `x-ai/grok-4.20-multi-agent` | xAI, 2Mコンテキスト, マルチエージェント |
| `glm-5.1` | `z-ai/glm-5.1` | ZhipuAI最新 |
| `qwen3-coder` | `qwen/qwen3-coder-next` | Alibaba コーディング特化 |
| `qwen3.6-plus` | `qwen/qwen3.6-plus` | Alibaba汎用 |

**エイリアス解決ルール:**
- 上記テーブルに該当 → 完全モデルIDに変換
- 該当しない場合 → `provider/model` 形式としてそのまま使用（例: `openai/gpt-4.1`, `deepseek/deepseek-r1`）

---

## 使い方（$ARGUMENTS 解析）

### モード1: 単一モデルクエリ

```
/openrouter <model> "<prompt>"
/openrouter <model> <prompt>
```

例:
- `/openrouter glm-5.1 "この関数をレビューして"`
- `/openrouter qwen3-coder "このアルゴリズムを最適化して"`
- `/openrouter openai/gpt-4.1 "このエラーの原因は？"` ← エイリアス外はフルID

モデルは**必ず明示**する。省略しないこと。

### モード2: マルチモデル比較

```
/openrouter compare "<prompt>"
/openrouter compare "<prompt>" models=<model1>,<model2>,<model3>
```

例:
- `/openrouter compare "この設計どう思う？" models=grok-4.20,qwen3-coder,glm-5.1`
- `/openrouter compare "SQLを最適化して" models=grok-4.20,qwen3-coder,glm-5.1`

### モード3: モデル一覧

```
/openrouter models
/openrouter models <検索キーワード>
```

### $ARGUMENTS 解析順序

1. 第1トークンが `compare` → 比較モード
2. 第1トークンが `models` → モデル一覧モード
3. それ以外 → 単一クエリモード（第1トークンを必須のモデル指定として扱う）

---

## 実行テンプレート

### 単一モデルクエリ

プロンプトに特殊文字（改行・引用符等）が含まれる場合は `jq -n --arg` でJSON安全化する。

```bash
if [ -z "$OPENROUTER_API_KEY" ]; then echo "ERROR: APIキーが見つかりません"; exit 1; fi

RESPONSE=$(curl -s -w "\n%{http_code}" https://openrouter.ai/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -d "$(jq -n --arg model "<MODEL_ID>" --arg content "<PROMPT>" \
    '{model: $model, max_tokens: 4000, messages: [{role: "user", content: $content}]}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

case $HTTP_CODE in
  200)
    echo "$BODY" | jq -r '.choices[0].message.content // "No content"'
    echo ""
    echo "--- Model: <MODEL_ID> | Tokens: $(echo "$BODY" | jq -r '(.usage.prompt_tokens // 0 | tostring) + " in / " + (.usage.completion_tokens // 0 | tostring) + " out"') ---"
    ;;
  401) echo "ERROR: 認証失敗。OPENROUTER_API_KEY を確認してください" ;;
  402) echo "ERROR: クレジット不足。https://openrouter.ai/settings/credits でチャージしてください" ;;
  429) echo "ERROR: レート制限。30秒後に再試行してください" ;;
  *)   echo "ERROR: HTTP $HTTP_CODE"; echo "$BODY" | jq -r '.error.message // .' ;;
esac
```

**実行場所:** メインBashツールで直接実行（timeout: 120000）。
推論系モデルは時間がかかる場合があるのでtimeout: 300000を検討。

### マルチモデル比較（並列実行）

compareモードでは並列curlでAPIを叩き、結果を比較表示する。

```bash
if [ -z "$OPENROUTER_API_KEY" ]; then echo "ERROR: APIキーが見つかりません"; exit 1; fi

# 一時ファイルはPIDで分離（並行実行衝突防止）
TMPDIR="/tmp/openrouter_$$"
mkdir -p "$TMPDIR"

# 並列実行
for i in 1 2 3; do
  MODEL_VAR="MODEL_$i"
  MODEL="${!MODEL_VAR}"
  curl -s https://openrouter.ai/api/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -d "$(jq -n --arg model "$MODEL" --arg content "<PROMPT>" \
      '{model: $model, max_tokens: 4000, messages: [{role: "user", content: $content}]}')" \
    > "$TMPDIR/model_$i.json" &
done
wait

# 結果表示
for i in 1 2 3; do
  MODEL_VAR="MODEL_$i"
  MODEL="${!MODEL_VAR}"
  echo "=== $MODEL ==="
  RESULT=$(jq -r '.choices[0].message.content // .error.message // "Error"' "$TMPDIR/model_$i.json")
  TOKENS=$(jq -r '(.usage.prompt_tokens // 0 | tostring) + " in / " + (.usage.completion_tokens // 0 | tostring) + " out"' "$TMPDIR/model_$i.json")
  echo "$RESULT"
  echo "--- Tokens: $TOKENS ---"
  echo ""
done

# クリーンアップ
rm -rf "$TMPDIR"
```

**実行場所:** サブエージェント（Agent tool）経由で実行。出力が長大になるため。
サブエージェントには以下を指示:
- 上記curlを実行
- 結果を以下の形式で整理して報告:

```
## モデル比較結果
| 項目 | Model 1 | Model 2 | Model 3 |
|------|---------|---------|---------|
| トークン | in/out | in/out | in/out |

### Model 1: <name>
（回答全文）

### Model 2: <name>
（回答全文）

### Model 3: <name>
（回答全文）

### 総合評価
（どのモデルの回答が最も適切か、1-2文で）
```

### モデル一覧取得

```bash
# APIキー読み込み（セッション未設定の場合Obsidian Vaultから取得）
if [ -z "$OPENROUTER_API_KEY" ]; then
  OPENROUTER_API_KEY=$(grep -oP 'sk-or-v1-[a-f0-9]+' "/c/Users/zooyo/Documents/Obsidian Vault/OpenRouter/API key.md" 2>/dev/null)
fi
if [ -z "$OPENROUTER_API_KEY" ]; then echo "ERROR: APIキーが見つかりません"; exit 1; fi

curl -s https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  | jq -r '.data | sort_by(.id) | .[] | "\(.id)\t\(.pricing.prompt)/\(.pricing.completion)\t\(.context_length)"' \
  | grep -i "<KEYWORD>" \
  | head -30
```

キーワード省略時は `head -50` で上位50件表示。

---

## エラーハンドリング

| コード | 意味 | 対処 |
|--------|------|------|
| 200 | 成功 | 正常処理 |
| 400 | リクエスト不正 | JSONフォーマット・モデルID確認 |
| 401 | 認証エラー | `$OPENROUTER_API_KEY` が正しいか確認 |
| 402 | クレジット不足 | https://openrouter.ai/settings/credits でチャージ |
| 429 | レート制限 | 30秒待って再試行 |
| 502/503 | サーバーエラー | 30秒待って再試行（最大2回） |

---

## 注意事項

1. **コスト**: compareモードはコストが3倍。推論系モデルは特に高額
2. **レスポンス時間**: 推論系モデルは30秒〜2分。Bash timeout を適切に設定
3. **コンテキスト長**: プロンプトにファイル内容を含める場合、モデルのコンテキスト長上限に注意
4. **non-streaming**: レスポンス全体を待ってから表示（ストリーミング非対応）

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-10 | 初版作成 |
| 2026-04-10 | 環境設定（APIキー取得戦略・Bashセッション制約・curl許可ルール・永続化手順）追加。全テンプレートにAPIキー自動読み込みスニペット追加 |
