# OAuth 2.0 認証フロー詳細

## 認可URLの構築

```bash
AUTH_URL="https://accounts.secure.freee.co.jp/public_api/authorize"
CLIENT_ID="your_client_id"
REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"  # ローカルテスト用
STATE=$(openssl rand -hex 16)

echo "${AUTH_URL}?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&prompt=select_company&state=${STATE}"
```

### 認可URLパラメータ一覧

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `response_type` | Yes | `code` 固定 |
| `client_id` | Yes | アプリのClient ID |
| `redirect_uri` | Yes | 登録済みコールバックURL（URLエンコード必要） |
| `state` | Yes | CSRF対策用ランダム文字列（コールバック時に検証必須） |
| `prompt` | 推奨 | `select_company` で事業所選択画面を表示 |

### 事業所選択（prompt=select_company）

- freee側がUI提供。ユーザーは1事業所のみ選択
- トークンレスポンスに `company_id` が含まれる
- **未使用（非推奨・廃止予定）**: 開発者が選択UIを自前実装する必要あり
- 新規開発では必ず `prompt=select_company` を使用すること

---

## トークン取得

### 認可コード → トークン交換

```bash
curl -X POST "https://accounts.secure.freee.co.jp/public_api/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}"
```

### トークンレスポンス

```json
{
  "access_token": "xxx",
  "token_type": "bearer",
  "expires_in": 21600,
  "refresh_token": "yyy",
  "scope": "read write default_read",
  "created_at": 1700000000,
  "company_id": "123456",
  "external_cid": "abc123"
}
```

| フィールド | 説明 |
|-----------|------|
| `access_token` | API呼び出しに使用するBearer トークン |
| `expires_in` | 有効期限（秒）。常に 21600（6時間） |
| `refresh_token` | トークン更新用。**1回使い切り、90日有効** |
| `company_id` | 選択された事業所ID。API呼び出し時に使用 |
| `external_cid` | 外部識別子 |
| `created_at` | トークン作成時刻（Unix timestamp） |

---

## トークンリフレッシュ

### リフレッシュリクエスト

```bash
curl -X POST "https://accounts.secure.freee.co.jp/public_api/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}"
```

### 重要な制約

1. **リフレッシュトークンは1回限り使用可能** — 使用後は即座に無効化される
2. リフレッシュレスポンスに新しい `access_token` + `refresh_token` のペアが含まれる
3. **新しい `refresh_token` を必ずDB/ストレージに保存すること**
4. 並行リクエストで同一トークンを複数回使用すると `invalid_grant` エラー → 排他制御が必要

---

## トークン失効（Revoke）

```bash
curl -X POST "https://accounts.secure.freee.co.jp/public_api/revoke" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "token=${ACCESS_TOKEN}"
```

ログアウト時やユーザー連携解除時に使用する。

---

## ローカルテスト（OOBフロー）

開発時にリダイレクト先のサーバーがない場合:

1. `redirect_uri` に `urn:ietf:wg:oauth:2.0:oob` を設定
2. 認可URLにブラウザでアクセス → freeeにログイン → 事業所選択 → 承認
3. 認可コードがブラウザ画面に表示される
4. 表示されたコードをコピーしてトークン取得リクエストに使用

---

## Next.js API Route 実装パターン

### コールバックハンドラ

```typescript
// app/api/freee/callback/route.ts
import { NextRequest, NextResponse } from 'next/server';

const TOKEN_URL = 'https://accounts.secure.freee.co.jp/public_api/token';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const code = searchParams.get('code');
  const state = searchParams.get('state');

  // CSRF検証
  const savedState = req.cookies.get('freee_oauth_state')?.value;
  if (!state || state !== savedState) {
    return NextResponse.json({ error: 'Invalid state' }, { status: 400 });
  }

  // トークン交換
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: process.env.FREEE_CLIENT_ID!,
    client_secret: process.env.FREEE_CLIENT_SECRET!,
    code: code!,
    redirect_uri: process.env.FREEE_REDIRECT_URI!,
  });

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const err = await res.json();
    return NextResponse.json({ error: err }, { status: res.status });
  }

  const token = await res.json();

  // トークン保存（DB推奨、ここではcookieの例）
  // 本番ではDBに暗号化保存すること
  await saveTokenToDb(token);

  return NextResponse.redirect(new URL('/dashboard', req.url));
}
```

### トークンリフレッシュ（排他制御付き）

```typescript
// lib/freee-auth.ts
interface FreeeTokenSet {
  access_token: string;
  refresh_token: string;
  expires_at: number;  // Unix timestamp
  company_id: string;
}

// ユーザー単位の排他制御（グローバル1本だとマルチユーザーで競合）
const refreshLocks = new Map<string, Promise<FreeeTokenSet>>();

export async function getValidToken(userId: string): Promise<FreeeTokenSet> {
  const token = await loadTokenFromDb(userId);

  if (Date.now() / 1000 <= token.expires_at - 300) return token;

  let lock = refreshLocks.get(userId);
  if (!lock) {
    lock = refreshFreeeToken(userId, token).finally(() => {
      refreshLocks.delete(userId);
    });
    refreshLocks.set(userId, lock);
  }
  return await lock;
}

async function refreshFreeeToken(userId: string, token: FreeeTokenSet): Promise<FreeeTokenSet> {
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: process.env.FREEE_CLIENT_ID!,
    client_secret: process.env.FREEE_CLIENT_SECRET!,
    refresh_token: token.refresh_token,
  });

  const res = await fetch('https://accounts.secure.freee.co.jp/public_api/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const err = await res.json();
    throw new Error(`Token refresh failed: ${JSON.stringify(err)}`);
  }

  const data = await res.json();
  const newToken: FreeeTokenSet = {
    access_token: data.access_token,
    refresh_token: data.refresh_token,  // 新しいrefresh_tokenを必ず保存!
    expires_at: data.created_at + data.expires_in,
    company_id: data.company_id || token.company_id,
  };

  await saveTokenToDb(newToken);
  return newToken;
}
```

### API呼び出しラッパー

```typescript
// lib/freee-client.ts
const FREEE_API_BASE = 'https://api.freee.co.jp';

export async function freeeApi<T>(
  path: string,
  userId: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getValidToken(userId);

  const res = await fetch(`${FREEE_API_BASE}${path}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${token.access_token}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...options.headers,
    },
  });

  if (res.status === 401) {
    const body = await res.json();
    if (body.errors?.[0]?.codes?.includes('expired_access_token')) {
      // リフレッシュ後にリトライ
      const newToken = await refreshFreeeToken(userId, token);
      const retryRes = await fetch(`${FREEE_API_BASE}${path}`, {
        ...options,
        headers: {
          'Authorization': `Bearer ${newToken.access_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...options.headers,
        },
      });
      if (retryRes.status === 204) return undefined as T;
      if (!retryRes.ok) throw new FreeeApiError(await retryRes.json());
      return retryRes.json() as Promise<T>;
    }
    throw new FreeeApiError(body);
  }

  if (!res.ok) {
    throw new FreeeApiError(await res.json());
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

// 使用例
const partners = await freeeApi<{ partners: Partner[] }>(
  `/api/1/partners?company_id=${companyId}`,
  userId
);
```

---

## 環境変数

```env
# .env.local
FREEE_CLIENT_ID=your_client_id
FREEE_CLIENT_SECRET=your_client_secret
FREEE_REDIRECT_URI=http://localhost:3000/api/freee/callback
```

**本番環境**: `FREEE_REDIRECT_URI` を本番ドメインに変更。freee開発者コンソールのリダイレクトURI設定も更新すること。
