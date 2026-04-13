# Architecture Pitfalls & Incident Lessons

実際のインシデントから導出した教訓集。新機能実装・バグ修正時に該当パターンがないか確認すること。

> **フォーマット**: 各教訓は「症状 / 原因 / 再発防止 / テスト観点」の4点セット（+ 必要に応じて「修正内容」）で記載。

---

## Pitfall #1: Supabase TIMESTAMP vs TIMESTAMPTZ（2026-02-27, PR #977）

### 症状
504リカバリポーリングがDBに存在するドキュメントを検出できない。
日本（JST, UTC+9）環境でのみ発生し、UTC+0環境では再現しない。

### 原因
`digital_strategy_documents` テーブルの `created_at` が `TIMESTAMP`（タイムゾーンなし）で定義されていた。
他テーブル（companies, analysis_runs等）はすべて `TIMESTAMP WITH TIME ZONE` を使用。

```
バックエンド: new Date().toISOString() → '2026-02-27T10:13:18.000Z'
PostgreSQL TIMESTAMP: 'Z'を無視 → '2026-02-27 10:13:18' として格納
Supabase REST API: '2026-02-27T10:13:18'（TZなし）を返す
ブラウザ(JST): new Date('2026-02-27T10:13:18') → JST解釈 → 01:13:18 UTC（9時間前）
リカバリ判定: 01:13 UTC < 09:45 UTC（生成開始-15分） → 候補から除外
```

### 再発防止
- **新テーブル作成時は必ず `TIMESTAMPTZ` を使用する**
- マイグレーションファイルのレビューで `TIMESTAMP` と `TIMESTAMPTZ` の混在をチェック
- フロントエンドでSupabase REST APIのレスポンスを `new Date()` でパースする箇所は、TZなし文字列を考慮

### テスト観点
- テストで `new Date()` オブジェクトのみ使用していると、REST APIが返す**文字列形式**との乖離を検知できない
- **TZなし文字列（`'2026-02-08T12:00:03'`）を直接テストデータとして使用する**テストケースを必ず含める
- UTC+0以外のタイムゾーンで結果が変わるロジックがないか確認

---

## Pitfall #2: アニメーション進捗のモジュロループ（2026-02-27, PR #978）

### 症状
デジタル戦略生成中の進捗バーが95%に達した後、74%に戻ってループする。
ステッパーも9→7に逆戻りする。

### 原因
`useCityAnimation.ts` のフォールバック進捗計算で `elapsed % stepDuration`（モジュロ演算）を使用。
`currentStep` が上限(3)に達した後、`elapsed` がさらに増加すると `elapsed % stepDuration` がゼロに戻り、
進捗値が 95% → 75% にループする。

```typescript
// NG: モジュロは周期関数 → プログレスバーの単調増加と矛盾
const stepProgress = (elapsed % stepDuration) / stepDuration

// OK: 差分計算 + キャップ → 単調増加を保証
const elapsedInStep = elapsed - (currentStep * stepDuration)
const stepProgress = Math.min(elapsedInStep / stepDuration, 1)
```

### 再発防止
- **プログレスバー（単調増加）にモジュロ演算（周期関数）を使わない**
- アニメーションの `estimatedDuration` が実際の処理時間と大きく乖離していないか確認
- `completedSteps` 等の実進捗データが渡されないフォールバック分岐の挙動を確認

### テスト観点
- `estimatedDuration` の2倍以上の時間が経過した場合のテストケース
- 進捗値が単調増加であること（前回値 <= 今回値）のアサーション

---

## Pitfall #3: Vercel 504/502のエラー分類（2026-02-27, PR #975）

### 症状
Vercel maxDuration超過で504 Gateway Timeoutが発生しても、リカバリ機構がトリガーされない。
エラーが汎用ハンドラに落ち、「不明なエラー」として処理される。

### 原因
`isNetworkDisconnectError()` は `error.response` が存在する場合 `false` を返す設計。
504/502は**HTTPレスポンスが存在する**（ゲートウェイがエラーレスポンスを返す）ため、
ネットワーク断と判定されない。

```typescript
// isNetworkDisconnectError: error.responseがあるとfalseを返す
if (!axios.isAxiosError(error) || error.response) {
  return false  // 504/502はここでfalse → リカバリ未トリガー
}

// 必要だった別関数:
export const isGatewayTimeoutError = (error: unknown): boolean => {
  if (!axios.isAxiosError(error) || !error.response) return false
  const status = error.response.status
  return status === 502 || status === 504
}
```

### 再発防止
- **HTTPエラーの分類は「レスポンスの有無」と「ステータスコード」の2軸で整理する**
- ネットワーク断（`ERR_NETWORK`, レスポンスなし）とゲートウェイエラー（502/504, レスポンスあり）は別物
- 新しいリカバリ条件追加時は `isRecoverable` の判定式を確認

### テスト観点
- `error.response` が存在するエラー（502/504）でリカバリがトリガーされるテスト
- `error.response` が存在しないエラー（ERR_NETWORK）でリカバリがトリガーされるテスト
- 両方のエラータイプをテストして分類漏れを防ぐ

---

## Pitfall #4: 状態遷移の順序依存（2026-02-27, PR #975）

### 症状
504エラー後にリカバリが成功してドキュメントを発見しても、`markRunSucceeded()` が失敗する。
分析ステータスが `failed` のまま更新されない。

### 原因
catchブロックで `markRunFailed()` をリカバリ試行**前**に呼んでいた。
バックエンドの `VALID_TRANSITIONS` は `succeeded` への遷移を `['queued', 'running']` からのみ許可。
`failed → succeeded` は無効な遷移のため、リカバリ成功後の `markRunSucceeded()` がサイレントに失敗。

```
// NG: 先にfailedにすると、succeededに戻れない
markRunFailed()  →  status: failed
recovery()       →  ドキュメント発見!
markRunSucceeded()  →  VALID_TRANSITIONS拒否（failed→succeeded不可）

// OK: リカバリ試行後にfailed/succeededを決定
recovery()       →  ドキュメント発見?
  → Yes: markRunSucceeded()  →  status: succeeded
  → No:  markRunFailed()     →  status: failed
```

### 再発防止
- **状態遷移を伴う操作は、すべてのリカバリパスの後に配置する**
- `VALID_TRANSITIONS` のマッピングを確認し、意図しない順序で遷移を呼ばないこと
- catchブロック内で複数のパス（キャンセル / リカバリ可能 / 汎用エラー）がある場合、各パスの終端に適切な状態遷移を配置

### テスト観点
- リカバリ成功時に `markRunSucceeded()` が呼ばれることのテスト
- リカバリ失敗時に `markRunFailed()` が呼ばれることのテスト
- `markRunFailed()` → `markRunSucceeded()` の順序で呼んだ場合にエラーになることのテスト

---

## Pitfall #5: Blob URLダウンロードのファイル名消失（2026-03-06, PR #1205）

### 症状
AI生成ファイル（PPTX等）をダウンロードすると、正しいファイル名ではなくBlob URLのUUID部分（例: `77c276d1-13d4-4fae-897f-5e38fb3d4b4b`）がファイル名になる。

### 原因（二重）

**原因1: Blob URL revoke競合**
`a.click()` 直後に同期的に `URL.revokeObjectURL()` を呼んでいたため、ブラウザがダウンロードを開始する前にBlob URLが無効化され、ファイル名がUUIDにフォールバック。

```typescript
// NG: click直後の同期revoke → ブラウザがBlob読み込み前にURL無効化
a.click()
URL.revokeObjectURL(url)  // ダウンロード開始前に無効化される

// OK: 遅延revoke → ブラウザにBlob読み込みの猶予を与える
a.click()
setTimeout(() => URL.revokeObjectURL(url), 200)
```

**原因2: MIMEタイプ許可リスト不足**
バックエンドの `ALLOWED_DOWNLOAD_MIME_TYPES` にPPTX/DOCX等のOffice MIMEタイプが未登録。`application/octet-stream` にフォールバックし、ブラウザのダウンロード挙動が不安定に。

### 再発防止
- **`URL.revokeObjectURL()` は `a.click()` の直後に同期呼び出ししない**: ブラウザがBlob URLからデータ読み込みを開始するまでのタイムラグが存在する。最低100-200msの遅延が必要
- **MIMEタイプ許可リストは新ファイル形式追加時に必ずレビューする**: `application/octet-stream` へのフォールバックはXSS防止には有効だが、ダウンロード挙動を不安定にする副作用がある
- **「以前から頻発している問題」はログ分析より先にコードパスを確認する**: ユーザーが「以前から」と言った場合、一時的な問題ではなく構造的なバグの可能性が高い

### テスト観点
- ダウンロードされたファイル名が元のファイル名と一致するか
- Content-Typeヘッダーが正しいMIMEタイプを返すか（`application/octet-stream` にフォールバックしていないか）
- `URL.revokeObjectURL()` がダウンロード完了後（遅延付き）に呼ばれているか
- 新しいファイル形式を追加した際に `ALLOWED_DOWNLOAD_MIME_TYPES` に登録されているか

---

## Pitfall #6: Vercel Serverlessのインメモリ状態はインスタンス間で共有されない（2026-03-06, PR #1206）

### 症状
分析キャンセルボタンを押しても実行中の分析が停止しない。キャンセル後もバナー「再分析がキューに入っています」が残留し、リロード後も消えない。

### 原因
`analysisManager.js`がインメモリ`Map`でキャンセルフラグを管理していた。ローカル開発（単一プロセス）では正常に動作するが、Vercel Serverlessでは各HTTPリクエストが異なるインスタンス（Lambda）で実行される。分析実行リクエストとキャンセルリクエストが別インスタンスに到達するため、キャンセルシグナルが到達しない。

```
ローカル（単一プロセス）:
  分析実行 → Map.set('cancel', true) ← キャンセルAPI → Map.get('cancel') === true ✅

Vercel Serverless（別インスタンス）:
  インスタンスA: 分析実行 → Map.get('cancel') === undefined（キャンセル検知不可）
  インスタンスB: キャンセルAPI → Map.set('cancel', true)（Aには届かない）❌
```

### 再発防止
- **Serverless環境でプロセス間の状態共有にインメモリデータ構造（Map, Set, グローバル変数）を使わない**
- 状態共有が必要な場合はDB（`analysis_runs.status`）を使用する
- キャンセルAPIはインメモリキャンセルを試行しつつ、失敗時はDB更新（`.in('status', ['queued', 'running'])`）でフォールバックする設計にする
- フロントエンドも`onCancelSuccess`でDB上の残留レコードをバックアップ更新する

### テスト観点
- **ローカルでの動作確認だけでは不十分** — Serverless環境（preview/production）で実際にキャンセルフローをテストする
- キャンセル後に`analysis_runs`テーブルのステータスが`failed`に更新されているか確認
- ページリロード後にバナーが再表示されないこと（DBレベルで状態がクリーンであること）

---

## Pitfall #7: try/catch内のconst変数スコープとリカバリ処理（2026-03-06, PR #1206）

### 症状
分析キャンセル時に`handleCancellationError`が呼ばれるが、`analysisRunId`が`undefined`のためDB更新がスキップされる。結果、`analysis_runs`が`queued`/`running`のまま残留。

### 原因
`analysisRunId`がネストされた`else`ブロック内で`const`宣言されており、外側の`catch`ブロックからアクセスできなかった。

```javascript
// NG: constのブロックスコープにより、catchからアクセス不可
try {
  if (existing) {
    // existing.id を使用
  } else {
    const result = await supabaseAdmin.from('analysis_runs').insert(...);
    const analysisRunId = result.data[0].id;  // elseブロック内に閉じ込められる
  }
} catch (error) {
  handleCancellationError(error, analysisRunId);  // undefined!
}

// OK: letで外側スコープに宣言
let analysisRunId;
try {
  if (existing) { analysisRunId = existing.id; }
  else {
    const result = await supabaseAdmin.from('analysis_runs').insert(...);
    analysisRunId = result.data[0].id;
  }
} catch (error) {
  handleCancellationError(error, analysisRunId);  // アクセス可能
}
```

### 再発防止
- **catchブロックでリカバリ処理に使う変数は、tryブロックの外側で`let`宣言する**
- 特にDB IDのような「エラー時のクリーンアップに必要な値」は、tryの外で宣言すること
- コードレビューで「catchブロック内で参照される変数のスコープ」を確認する

### テスト観点
- キャンセルエラー発生時に`handleCancellationError`に正しい`analysisRunId`が渡されることを確認
- `analysisRunId`が`undefined`の場合にDB更新がスキップされないガードを確認
- try/catch構造が複雑な場合、各分岐パスで変数が正しくスコープされているかレビュー

---

## Pitfall #8: API snake_case vs CLI/フロントエンド camelCase の不一致（2026-03-11）

### 症状
CLIコマンド（`usacon credits`, `usacon company list`）が正常にAPIレスポンスを受信するが、プロパティアクセスで `undefined` になりサイレント失敗する。テーブル表示で空欄やクラッシュが発生。

### 原因
Usaconバックエンド（Express + Supabase）はDBカラム名をそのまま返すため、APIレスポンスは `snake_case`（`credits_remaining`, `plan_code`）。一方、CLIのTypeScript型定義（app-core）は `camelCase`（`creditsRemaining`, `planCode`）で定義。CLIのhttpClientは `as T` キャストでJSONをパースするため、型チェックが効かず、プロパティ名の不一致がコンパイル時に検出されない。

```typescript
// NG: APIは snake_case で返すが、型は camelCase
const res = await httpClient.get<CreditBalance>('/api/credits/me');
console.log(res.creditsRemaining);  // undefined（実際は res.credits_remaining）

// OK: 変換レイヤーを挟む or snake_case のままアクセス
const raw = await httpClient.get<Record<string, unknown>>('/api/credits/me');
const credits = transformKeys(raw, 'camelCase');  // 明示的変換
```

### 再発防止
- **新CLIコマンド追加時、APIレスポンスのフィールド名を実際のcurlで確認する**（型定義を信用しない）
- **httpClient層でsnake_case→camelCase変換を行うか、snake_caseのままアクセスするか方針を統一する**
- **`as T` キャストの代わりに、Zodスキーマ等でランタイムバリデーション+変換を検討する**

### テスト観点
- CLIの `--json` 出力だけでなく、ヒューマンリーダブル表示（非JSON）も確認する（JSON出力は生データスルーで問題が隠れる）
- APIレスポンスのフィールド名と型定義のフィールド名が一致するかチェックする単体テストを追加する
- `undefined` のサイレント失敗を防ぐため、テーブル表示時にフィールドの値が非undefined/非nullであることをアサートする

---

## Pitfall #9: Supabase Storage `upsert` はキャッシュを無効化しない（2026-03-13, PR #1405）

### 症状
ロールバック機能で以前のバージョンに戻しても、`download()` で取得すると更新前の（古い）内容が返される。

### 原因
`rollbackKokoro()` が `saveKokoro()`（内部で `upload({ upsert: true })` を使用）を経由していた。Supabase Storage は `upsert` 後の `download()` でキャッシュされた古い内容を返す場合がある。

```javascript
// NG: upsert — キャッシュが残る可能性
await storage.from(BUCKET).upload(path, content, { upsert: true });

// OK: delete + upload — キャッシュを確実にクリア
await storage.from(BUCKET).remove([path]);
await storage.from(BUCKET).upload(path, content, { upsert: false });
```

### 再発防止
- **ファイルを確実に置換する必要がある場合は `remove()` + `upload()` パターンを使用する**
- 単純な新規保存や更新頻度が低い場合は `upsert: true` で問題ない
- ロールバック・バージョン管理など「最新の内容を確実に読み取る必要がある」機能では `upsert` を避ける

### テスト観点
- `upload({ upsert: true })` 後に `download()` して内容が一致するか確認（キャッシュ影響を検出）
- ロールバック操作後にダウンロードして、ロールバック先の内容と一致するか確認

---

## Pitfall #10: LLM出力のコードフェンス除去は入出力境界で行う（2026-03-13, PR #1405）

### 症状
LLMが生成したMarkdownコンテンツがフロントエンドで ` ```markdown ` 付きのコードフェンスとして生表示される。プロンプトで「Markdownのみ返して」と指示しているが守られない。

### 原因
LLMのプロンプト指示は100%遵守されるとは限らない。特にコードフェンス（` ``` `）やHTMLコメント（`<!-- -->`）の混入は高頻度で発生する。

```javascript
// バックエンド（予防）: LLM応答受信直後にサニタイズ
function stripCodeFences(text) {
  return text.replace(/^```(?:markdown)?\n?/gm, '').replace(/\n?```$/gm, '');
}

// フロントエンド（防御）: 表示前にもサニタイズ
function sanitizeLLMOutput(text) {
  return text
    .replace(/^```(?:markdown)?\n?/gm, '')
    .replace(/\n?```$/gm, '')
    .replace(/<!--[\s\S]*?-->/g, '');
}
```

### 再発防止
- **LLM出力を保存・表示する全経路で、入出力境界に防御的サニタイズを配置する**
- 「プロンプトで指示したから大丈夫」を信頼しない — 防御的プログラミングを適用
- バックエンド（保存前）とフロントエンド（表示前）の2層で防御

### テスト観点
- テストデータに ` ```markdown\n内容\n``` ` 形式を含めて、サニタイズが機能するか確認
- HTMLコメント（`<!-- TODO -->`）が除去されるか確認

---

## Pitfall #11: Reactコンテキスト変更検知の複合シグネチャ（2026-03-13, PR #1398）

### 症状
アンケート回答でクレジットが増加しても、ヘッダーの残高表示が更新されない。ページリロードすると正しい値が表示される。

### 原因
`SubscriptionContext` の `subscriptionChange` イベントが `planCode` の変更時のみ発火する設計だった。アンケート回答はクレジットを増やすがプランコードは変えないため、イベントが発火せず表示が更新されなかった。

```typescript
// NG: planCodeのみで変更検知 → クレジット変更を見落とす
const signature = planCode;

// OK: UI表示に関わる全値で複合シグネチャを構成
const signature = `${planCode}|${status}|${creditsRemaining}|${monthlyQuota}|${nextResetAt}|${isUnlimited}`;
```

### 再発防止
- **Reactのコンテキスト変更検知では、ユーザーに見えるすべての値をシグネチャに含める**
- 「このフィールドは変わらないだろう」という仮定を避ける
- 新しいUI表示項目を追加した場合、シグネチャにも追加する

### テスト観点
- `planCode` が同じでも `creditsRemaining` が変わった場合にイベントが発火するか
- シグネチャの全フィールドを個別に変更してイベント発火を確認

---

## Pitfall #12: 日本語検索の多段階正規化（2026-03-13, PR #1404）

### 症状
「ウェルビーイング」で検索しても該当ナレッジがヒットしない。実際にはウェルビーイング関連のコンテンツが存在する。

### 原因
(1) キーワード抽出が単一パスで完結しており、同義語展開がない。(2) ドキュメント内では「ウサコンの心」「kokoro」等の別名で記載されており、「ウェルビーイング」との紐づけがない。(3) 複合語のサフィックス（「機能」「について」等）が除去されず、完全一致検索で失敗する。

```javascript
// 多段階検索パイプライン
function searchKnowledge(query) {
  // Stage 1: サフィックス除去（「機能」「について」「とは」等）
  const normalized = removeSuffixes(query);

  // Stage 2: エイリアス展開（同義語辞書）
  const aliases = expandAliases(normalized);
  // 例: ウェルビーイング → [ウサコンの心, kokoro, wellbeing]

  // Stage 3: 部分一致フォールバック（2-gram分割）
  if (noResults) {
    const ngrams = generateNgrams(normalized, 2);
  }
}
```

### 再発防止
- **検索機能は単一のキーワード抽出で完結させない**
- 正規化（サフィックス除去）→ 同義語展開 → 部分一致フォールバックの段階的アプローチ
- 日本語のような膠着語では特に重要
- エイリアス辞書はドメイン固有の知識を反映させること

### テスト観点
- 同義語（ウェルビーイング / ウサコンの心 / kokoro）でそれぞれ検索して同じ結果が返るか
- サフィックス付き（「〜機能」「〜について」）でも検索がヒットするか

---

## Pitfall #13: Stripe Customer Portal Configuration の proration_behavior デフォルト値の罠（2026-03-16, Issue #1434）

### 症状
Customer Portal 経由でプランをアップグレードしても日割り計算が適用されない。Standard（¥70,000/月）→ Professional（¥200,000/月）への月途中アップグレードで、最大¥130,000/月の請求漏れが発生。

### 原因
Stripe の `proration_behavior` パラメータは **APIレイヤーによってデフォルト値が異なる**。

| APIレイヤー | パラメータ | デフォルト値 | 挙動 |
|------------|-----------|-------------|------|
| Subscription API (`stripe.subscriptions.update`) | `proration_behavior` | `create_prorations` | 日割り計算あり（安全） |
| Customer Portal Configuration (`billing_portal.configurations`) | `proration_behavior` | `none` | **日割り計算なし（危険）** |

Customer Portal Configuration を Stripe Dashboard または API で作成する際、`proration_behavior` を明示的に設定しないと `none`（日割りなし）が適用される。Subscription API のデフォルト（`create_prorations`）と同じだと思い込み、明示的な設定を省略したことが根本原因。

```javascript
// NG: proration_behavior を省略 → デフォルト 'none'（日割りなし）
const config = await stripe.billingPortal.configurations.create({
  features: {
    subscription_update: {
      enabled: true,
      default_allowed_updates: ['price'],
      products: [/* ... */],
      // proration_behavior 未指定 → 'none' が適用される
    },
  },
});

// OK: proration_behavior を明示的に設定
const config = await stripe.billingPortal.configurations.create({
  features: {
    subscription_update: {
      enabled: true,
      proration_behavior: 'create_prorations', // ← 必ず明示
      default_allowed_updates: ['price'],
      products: [/* ... */],
    },
  },
});
```

### 修正内容
- `scripts/setup-stripe-portal-configs.js` で `proration_behavior: 'create_prorations'` を明示的に設定
- テスト環境・本番環境両方の Portal Configuration を再作成

### 再発防止
- **Stripe の課金パラメータは暗黙のデフォルトに依存せず、必ず明示的に設定する**
- 同じパラメータ名でも API レイヤーによってデフォルト値が異なることを前提に設計する
- Customer Portal Configuration の変更は `scripts/setup-stripe-portal-configs.js` でコード管理し、Stripe Dashboard の手動操作に依存しない
- 課金設定変更後は、テスト環境でプランアップグレード・ダウングレードの請求金額を確認する

### テスト観点
- Portal 経由のプランアップグレードで日割り請求が生成されるか確認（Stripe Dashboard > Invoices）
- `stripe billing_portal configurations retrieve bpc_xxx` で `proration_behavior` が `create_prorations` であることを確認
- 年額プラン間のアップグレードで日割り金額が正しいか確認（金額が大きいため影響大）

---

## Pitfall #14: AIアシスタント経路と通常UI経路のデータ完全性の乖離（2026-03-05, Issue #1090, #1092）

### 症状
AIアシスタント経由で作成したデータが不完全。レポート一覧では1テーブルのみ表示、お気に入り登録では「不明な補助金」としてDB保存される。

### 原因
通常UI経路とAIアシスタント経路で参照するテーブル数・データ取得フローが乖離していた。

| 側面 | 通常UI経路 | AIアシスタント経路（不足していた点） |
|------|-----------|-----------------------------------|
| データ取得 | 4テーブルから並列取得 | 1テーブルのみクエリ |
| データ保持 | フロントエンドで詳細データを保持 | IDのみ渡し、バックエンドで補完試行 |
| 失敗時の振る舞い | ユーザーにエラー表示 | フォールバック値で静かに劣化 |

### 再発防止
- **AIアシスタント用サービス関数の新規作成時、通常UIの同等機能を「参照実装」としてデータフローを照合する**
- **フォールバック値（「不明な○○」）でDB保存する設計は原則避ける** — API失敗時はエラー返却/リトライ/ユーザー通知が適切
- 実装計画のリスク評価で「確率: 高」と判定したリスクはスコープ外にせず対処する

### テスト観点
- AIアシスタント経由で作成したデータと通常UI経由で作成したデータが同じフィールドを持つか
- API失敗時にフォールバック値ではなくエラーが返されるか

### 影響範囲チェックリスト（AIアシスタントアクション新規作成時）

```
[ ] 通常UIの同等機能のデータフローを確認したか
[ ] 通常UIが参照するテーブルを全て網羅しているか
[ ] 通常UIがフロントエンドで保持するデータをAI経路でも取得できるか
[ ] NOT NULL制約のあるカラムに対して、フォールバック値ではなく実データを保存しているか
[ ] API呼び出し失敗時の振る舞いが「静かな劣化」ではなく「明示的なエラー」になっているか
```

---

## Pitfall #15: Content-Disposition ヘッダーの日本語ファイル名（2026-03-31, #1669）

### 症状
`res.setHeader('Content-Disposition', \`attachment; filename="${日本語名}"\`)` でNode.jsが `ERR_INVALID_CHAR` を投げる。

### 原因
HTTP `filename=` パラメータはASCIIのみ許可（RFC 6266）。日本語ファイル名は `filename*=UTF-8''...` にのみ使用可能。

```javascript
// NG: filename に日本語を直接指定
res.setHeader('Content-Disposition', `attachment; filename="${日本語名}"`);

// OK: filename= はASCIIフォールバック、filename*= で日本語
res.setHeader('Content-Disposition',
  `attachment; filename="report.xlsx"; filename*=UTF-8''${encodeURIComponent(日本語名)}`
);
```

### 再発防止
- **バイナリダウンロードAPIでは常に `filename=` をASCIIのみにする**

### テスト観点
- 日本語ファイル名でダウンロードAPIを呼び出し、ERR_INVALID_CHAR が発生しないこと

---

## Pitfall #16: Express res.json() は既存 Content-Type を上書きしない（2026-03-31, #1670）

### 症状
バイナリレスポンスのルートでcatchブロックが `res.status(500).json(...)` を呼んでも、Content-TypeがExcel MIMEのまま返される。

### 原因
Express の `res.json()` は既にContent-Typeが設定されている場合スキップする。

```javascript
// NG: catchブロックでContent-Typeがリセットされない
} catch (error) {
  res.status(500).json({ error: 'Export failed' }); // Content-TypeはExcelのまま!
}

// OK: catchブロック冒頭でContent-Typeを明示的にリセット
} catch (error) {
  res.setHeader('Content-Type', 'application/json');
  res.status(500).json({ error: 'Export failed' });
}
```

### 再発防止
- **バイナリレスポンスルートのcatchブロック冒頭で `Content-Type` を `application/json` にリセット**

### テスト観点
- バイナリDLエラー時のレスポンスがJSON Content-Typeで返ること

---

## Pitfall #17: CSS詳細度戦争を避ける — セレクタ不一致で回避（2026-03-31, #1669）

### 症状
`[data-theme] .MuiTypography-root { color: !important }` に対して `sx` propの `!important` でも色が勝てない。

### 原因
両方 `!important` の場合、セレクタ詳細度 `(0,2,0)` > `(0,1,0)` でテーマ側が勝つ。

```tsx
// NG: 詳細度で戦う
<Typography sx={{ color: 'error.main !important' }}>必須</Typography>

// OK: セレクタから外す
<Box component="span" sx={{ color: 'error.main' }}>必須</Box>
```

### 再発防止
- **グローバル `!important` との戦いでは、詳細度を上げるよりセレクタの対象から外す**
- `Typography` → `Box component="span"` に変更し、`.MuiTypography-root` セレクタにマッチしないようにする

### テスト観点
- テーマ切替後に例外色が正しく表示されること

---

## Pitfall #18: カタログデータの answer_mode 設定ミスによるUI機能消失（2026-04-03, #1699）

### 症状
ダッシュボードの「今日の経営者の問い」で選択肢ボタンが表示されない。`priority: 3`（最高値）のため高頻度で発生し、ユーザー影響大。

### 原因
success_story タイプの質問3件のうち2件が `answer_mode: 'text'` / `options: NULL` で登録されていた。同タイプの既存データは `answer_mode: 'mixed'` で選択肢付き。成功体験カウントに text-only が必要と誤解していたが、実際には `question_type === 'success_story'` で判定されるため `answer_mode` は無関係だった。

### 再発防止
- **カタログデータ追加時、同一 `question_type` の既存データと `answer_mode` / `options` パターンを必ず比較する**（3件中1件だけ異なる設定はレッドフラグ）
- **`answer_mode` 変更前に判定ロジック（`isSuccessStory` 等）が何に依存しているかをコードで確認する**（推測で設計しない）
- **priority 最高値のデータは出現頻度が極めて高い**（`pickCatalogQuestion` は priority 降順 → 上位5件からランダム）。品質影響が大きい
- **マイグレーション作成時は `supabase/seeds/` の対応データも同時更新**（`db reset` での乖離防止）

### テスト観点
- 新規カタログデータ追加後、同一typeの既存データとUI表示が一貫しているか確認
- priority最高値のデータで「選択肢ボタン」が表示されるか確認

---

## 横断チェックリスト（新機能実装時に確認）

```
[ ] DBマイグレーションで TIMESTAMP を使っていないか？（TIMESTAMPTZ を使用すること）
[ ] フロントエンドで new Date(string) を使う箇所でTZなし文字列を考慮しているか？
[ ] プログレスバー/アニメーションでモジュロ演算を使っていないか？
[ ] エラーハンドリングで502/504をネットワーク断と別に分類しているか？
[ ] catchブロック内でリカバリ前に状態遷移を呼んでいないか？
[ ] テストデータにDate型だけでなくAPI応答形式（文字列）を含めているか？
[ ] Blob URLダウンロードで revokeObjectURL を click 直後に同期呼び出ししていないか？（遅延必須）
[ ] 新ファイル形式追加時に ALLOWED_DOWNLOAD_MIME_TYPES に登録したか？
[ ] Serverless環境でインメモリ状態（Map/Set/グローバル変数）をプロセス間通信に使っていないか？（DB使用）
[ ] catchブロックで参照する変数がtryの外側スコープで宣言されているか？
[ ] APIレスポンスのフィールド名（snake_case）とTypeScript型定義（camelCase）が一致しているか？変換レイヤーはあるか？
[ ] `as T` キャストでAPIレスポンスをパースしている箇所で、フィールド名の不一致がサイレント失敗しないか？
[ ] Supabase Storageでファイル置換時に upsert ではなく delete+upload を使用しているか？（キャッシュ対策）
[ ] LLM出力を保存・表示する経路で、コードフェンス/HTMLコメントのサニタイズが入出力境界に配置されているか？
[ ] Reactコンテキストの変更検知シグネチャに、UIに表示される全フィールドが含まれているか？
[ ] 日本語検索でサフィックス除去・同義語展開・部分一致フォールバックの多段階処理が実装されているか？
[ ] Stripe の課金パラメータ（proration_behavior 等）を明示的に設定しているか？（APIレイヤー別にデフォルト値が異なる）
[ ] Customer Portal Configuration をコード管理（setup-stripe-portal-configs.js）しているか？Dashboard手動操作に依存していないか？
[ ] AIアシスタントアクション新規作成時、通常UIの同等機能とデータフローを照合したか？（Pitfall #14）
[ ] NOT NULL制約カラムにフォールバック値（「不明な○○」）を保存していないか？エラー返却/リトライが適切か確認。
[ ] Content-Disposition の filename= にASCII以外の文字を含めていないか？日本語は filename*=UTF-8'' で指定（Pitfall #15）
[ ] バイナリレスポンスルートのcatchブロックで Content-Type を application/json にリセットしているか？（Pitfall #16）
[ ] グローバルCSS !important との競合をセレクタ詳細度の上乗せではなく、セレクタ不一致（Box化等）で回避しているか？（Pitfall #17）
[ ] カタログデータ追加時、同一question_typeの既存データとanswer_mode/optionsパターンが一貫しているか？priority最高値データの品質は特に重要（Pitfall #18）
```
