# Webhook 設定・検証詳細

ステータス: **Beta**

---

## Webhook登録手順

1. [freee開発者コンソール](https://app.secure.freee.co.jp/developers/applications) でアプリを選択
2. Webhook設定セクションで以下を設定:
   - **Webhook URL**: HTTPSエンドポイント（ファイアウォールで `egw.freee.co.jp` を許可）
   - **イベント種別**: 監視するリソースとアクションを選択
3. 設定保存時に**検証トークン**が表示される → 安全に保管
4. ユーザーがアプリを認可済みであることが前提

---

## 対応イベント

### 会計API Webhook

| リソース | resource値 | アクション |
|---------|-----------|----------|
| 経費精算 | `accounting:expense_application` | created, updated, destroyed |
| 各種申請 | `accounting:approval_request` | created, updated, destroyed |
| 支払依頼 | `accounting:payment_request` | created, updated, destroyed |

### updated時の詳細アクション（approval_action）

| アクション | 説明 |
|-----------|------|
| `draft` | 下書き保存 |
| `apply` | 申請 |
| `approve` | 承認 |
| `force_approve` | 強制承認 |
| `cancel` | 取消 |
| `reject` | 却下 |
| `feedback` | 差戻し |
| `force_feedback` | 強制差戻し |

### HR API Webhook

| リソース | resource値 | アクション |
|---------|-----------|----------|
| 従業員 | `hr:employee` | created, updated, destroyed |

**対象外（通知されない）**:
- Public API経由のCRUD操作
- 一括インポート
- 家族情報変更
- 管理者一括追加
- 退職処理

---

## ペイロード形式

### 共通プロパティ

```json
{
  "id": "notification_unique_id",       // 重複排除用の固有ID
  "application_id": 12345,              // アプリID
  "resource": "accounting:expense_application",  // "{ドメイン}:{リソース}"
  "action": "updated",                  // created / updated / destroyed
  "created_at": "2026-03-26T10:30:00+09:00"     // イベント発生時刻
}
```

### 会計Webhook追加プロパティ

```json
{
  "...共通プロパティ...",
  "expense_application": {
    "id": 67890,
    "company_id": 11111,
    "status": "approved",
    "approval_action": "approve"
  }
}
```

### HR Webhook追加プロパティ

```json
{
  "...共通プロパティ...",
  "employee": {
    "id": 67890,
    "company_id": 11111,
    "year": 2026,
    "month": 3
  }
}
```

---

## 検証実装

### リクエストヘッダー

Webhookリクエストには `x-freee-token` ヘッダーが含まれる。これをアプリの検証トークンと照合する。

### TypeScript実装

```typescript
// app/api/freee/webhook/route.ts
import { NextRequest, NextResponse } from 'next/server';

const FREEE_WEBHOOK_TOKEN = process.env.FREEE_WEBHOOK_TOKEN!;

export async function POST(req: NextRequest) {
  // 1. トークン検証
  const receivedToken = req.headers.get('x-freee-token');
  if (receivedToken !== FREEE_WEBHOOK_TOKEN) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // 2. ペイロード解析
  const payload = await req.json();
  const { id, resource, action, created_at } = payload;

  // 3. 冪等性チェック（重複排除）
  const alreadyProcessed = await checkProcessed(id);
  if (alreadyProcessed) {
    return NextResponse.json({ status: 'already_processed' });
  }

  // 4. イベントハンドリング
  switch (resource) {
    case 'accounting:expense_application':
      await handleExpenseApplication(payload, action);
      break;
    case 'accounting:approval_request':
      await handleApprovalRequest(payload, action);
      break;
    case 'accounting:payment_request':
      await handlePaymentRequest(payload, action);
      break;
    case 'hr:employee':
      await handleEmployee(payload, action);
      break;
    default:
      console.warn(`Unknown resource: ${resource}`);
  }

  // 5. 処理済みマーク
  await markProcessed(id);

  return NextResponse.json({ status: 'ok' });
}

async function handleExpenseApplication(
  payload: any,
  action: string
) {
  const { expense_application } = payload;
  const { id, company_id, status, approval_action } = expense_application;

  if (action === 'updated' && approval_action === 'approve') {
    // 承認された経費精算を処理
    console.log(`Expense #${id} approved for company ${company_id}`);
    // 例: 会計APIで自動仕訳作成、外部システム通知等
  }
}
```

---

## 環境変数

```env
# .env.local
FREEE_WEBHOOK_TOKEN=your_webhook_verification_token
```

---

## ネットワーク要件

| 要件 | 値 |
|------|-----|
| プロトコル | HTTPS必須 |
| 送信元ドメイン | `egw.freee.co.jp` |
| ファイアウォール | 上記ドメインの許可が必要 |

---

## 制限事項（Beta）

1. **エラーログ未提供** — Webhook配信失敗時のログは確認できない
2. **リトライポリシー未明文化** — 配信失敗時の再試行回数・間隔は非公開
3. **API経由のCRUD非対応** — Web画面からの操作のみが通知対象
4. **HR: 一部操作非対応** — 一括インポート、退職処理等は通知されない
5. **配信保証なし** — 必ず配信される保証はない。重要なデータは定期的なAPIポーリングと併用推奨

### 推奨パターン

```
Webhook（リアルタイム通知）+ 定期ポーリング（漏れ補完）
```

Webhookでイベントを受信しつつ、5-15分間隔のポーリングで漏れたイベントを補完する設計が堅牢。
