# Grok Research Lane（補助分析レーン）

## 概要

OpenRouter経由の **Grok 4.20 multi-agent** (`x-ai/grok-4.20-multi-agent`) を
バッチパイプラインの **planning / review / risk synthesis** フェーズで補助レーンとして活用する。

**原則: Grok は補助用途限定。実行系（merge、E2E、Issue close）には使わない。**

## 起動条件

### 前提条件（全フェーズ共通）

1. `OPENROUTER_API_KEY` が環境変数として設定済みであること
2. APIキー未設定時は**自動スキップ**（エラーにしない）

```bash
if [ -z "$OPENROUTER_API_KEY" ]; then
  echo '{"grok_lane_status":"skipped","reason":"OPENROUTER_API_KEY not set"}'
  exit 0
fi
```

### フェーズ別起動条件

| フェーズ | Step | 起動条件 | 用途 |
|---------|------|---------|------|
| Batch Planning | Step 2 | Tier B/A Issue が1件以上 | 複雑Issueの技術リスク・外部知見の補助分析 |
| クアドレビュー | Phase A (Step 7) | Tier B/A Issue のみ | 追加レビュー視点（技術的判断の裏取り） |
| 統合回帰テスト | Step 8 | feat Issue が2件以上 | クロスカット影響のリスク評価 |

**Tier C Issue では起動しない**（トークンコスト最適化）。

---

## 実行方法

### API呼び出しテンプレート

`openrouter` スキルの curl テンプレートを使用する。バッチのスループット維持のため **timeout は 120秒**。

```bash
GROK_RESPONSE=$(curl -s -w "\n%{http_code}" \
  --max-time 120 \
  https://openrouter.ai/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -d "$(jq -n \
    --arg model "x-ai/grok-4.20-multi-agent" \
    --arg content "$GROK_PROMPT" \
    '{model: $model, max_tokens: 4000, messages: [{role: "system", content: "You are a technical research assistant. Provide structured analysis in JSON format. Focus on risks, external knowledge, and cross-cutting concerns. Always include confidence levels."}, {role: "user", content: $content}]}')")

HTTP_CODE=$(echo "$GROK_RESPONSE" | tail -1)
BODY=$(echo "$GROK_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "{\"grok_lane_status\":\"error\",\"http_code\":$HTTP_CODE}"
  exit 0  # エラーでもパイプラインは継続
fi

echo "$BODY" | jq -r '.choices[0].message.content'
```

### サブエージェント実行パターン

メインコンテキスト汚染を防ぐため、Grokレーンは**サブエージェント内で実行**する。

```
Agent({
  description: "Grok research lane for Issue #<number>",
  prompt: "<フェーズ別プロンプト>",
  model: "sonnet"  // サブエージェント自体は軽量モデル、Grokはcurl経由
})
```

---

## フェーズ別プロンプトガイド

### 1. Batch Planning 補助（Step 2）

リーダーが Batch Planning Agent を起動する際、Tier B/A Issue が含まれていれば
Grok レーンを並行起動する。

**入力**: Issue タイトル・本文サマリ・候補ファイルリスト
**出力**: 技術リスク評価・外部知見・推奨実装順序

```json
{
  "grok_lane_status": "completed",
  "phase": "batch_planning",
  "issues_analyzed": ["#123", "#456"],
  "risk_assessment": {
    "cross_cutting_risks": ["..."],
    "external_dependencies": ["..."],
    "recommended_order": ["#456", "#123"],
    "confidence": 0.8
  },
  "external_knowledge": [
    {
      "topic": "...",
      "insight": "...",
      "confidence": 0.7,
      "verification_required": true
    }
  ]
}
```

### 2. クアドレビュー補助（Phase A）

Tier B/A Issue のクアドレビュー時に、追加の技術視点として起動する。
既存の Lane 0-4 とは独立したレーンとして扱い、レーン完了数には加算しない。

**入力**: PR diff サマリ・実装計画・Issue要件
**出力**: 技術的懸念・代替アプローチ・見落としリスク

```json
{
  "grok_lane_status": "completed",
  "phase": "quad_review",
  "issue_number": "#123",
  "findings": [
    {
      "severity": "major|minor|suggestion",
      "category": "security|performance|correctness|maintainability",
      "description": "...",
      "confidence": 0.85
    }
  ],
  "alternative_approaches": ["..."]
}
```

### 3. 統合回帰リスク評価（Step 8）

feat Issue が2件以上のバッチで、クロスカット影響を評価する。

**入力**: 全Issue の変更サマリ・影響ファイルリスト
**出力**: Issue間の干渉リスク・重点テスト対象

```json
{
  "grok_lane_status": "completed",
  "phase": "regression_risk",
  "batch_size": 5,
  "feat_count": 2,
  "interference_risks": [
    {
      "issues": ["#123", "#456"],
      "shared_files": ["src/lib/auth.ts"],
      "risk_level": "high|medium|low",
      "recommended_test_focus": "..."
    }
  ]
}
```

---

## 信頼境界ルール

Grok 出力は**補助情報**として扱う。最終判断は Claude + ローカル検証で行う。

| 項目 | ルール |
|------|--------|
| ファイルパス・行番号 | Grok出力をそのまま採用しない。`grep` / `Read` で必ずローカル検証 |
| 外部知見 | `verification_required=true` の項目は裏取りなしで計画に書かない |
| confidence | 0.7 未満の項目は「未検証補助情報」としてのみ扱う |
| 実装提案 | Grok の具体的コード提案は参考程度。実装は Claude が行う |

---

## フォールバック

| エラー | 対応 |
|--------|------|
| `OPENROUTER_API_KEY` 未設定 | 自動スキップ（`skipped`） |
| HTTP 401（認証エラー） | `skipped_auth` として Claude 単独で継続 |
| HTTP 402（クレジット不足） | `skipped_credits` として Claude 単独で継続 |
| HTTP 429（レート制限） | 30秒待機して1回リトライ → 失敗なら `skipped_rate_limit` |
| タイムアウト（120秒） | `timeout` として Claude 単独で継続 |
| JSONパース失敗 | `skipped_parse_error` として Claude 単独で継続 |

**重要: Grok レーンの失敗はバッチパイプラインの停止理由にならない。**
常にフォールバックとして Claude 単独での継続を保証する。

---

## 状態記録

`tasks/batch-pipeline-state.json` の各Issue/バッチレベルに以下を記録する:

```json
{
  "grok_lane": {
    "status": "completed|skipped|timeout|error",
    "phase": "batch_planning|quad_review|regression_risk",
    "duration_ms": 45000,
    "findings_count": 3,
    "high_confidence_count": 2
  }
}
```

リーダーの完了報告（Step 11）に Grok レーン利用状況のサマリを含める:
- `grok_invocations`: 起動回数
- `grok_completed`: 正常完了回数
- `grok_skipped`: スキップ回数（理由別内訳）
- `grok_high_value_findings`: confidence >= 0.7 の知見数
