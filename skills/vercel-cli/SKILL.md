---
name: Vercel CLI Operations
description: |
  Vercelプロジェクトのデプロイ・管理にVercel CLIを使用。プレビュー、本番デプロイ、環境変数、ドメイン管理など。
  トリガー: "vercel", "デプロイ", "プレビュー", "本番デプロイ", "環境変数", "ドメイン"
---

# Vercel CLI ガイド

## 概要
Vercelプロジェクトのデプロイ・管理にはVercel CLIを使用してください。

## インストール確認
```bash
vercel --version
```

インストールされていない場合：
```bash
npm install -g vercel
```

## 基本コマンド

### 認証・初期化
```bash
# ログイン
vercel login

# プロジェクトリンク
vercel link

# プロジェクト情報確認
vercel project ls
```

### デプロイ
```bash
# プレビューデプロイ（開発確認用）
vercel

# 本番デプロイ
vercel --prod

# 特定ブランチからデプロイ
vercel --prod --force
```

### 環境変数
```bash
# 環境変数一覧
vercel env ls

# 環境変数追加
vercel env add <name>

# 環境変数削除
vercel env rm <name>

# .envファイルから取得
vercel env pull .env.local
```

### ドメイン管理
```bash
# ドメイン一覧
vercel domains ls

# ドメイン追加
vercel domains add <domain>

# DNS設定確認
vercel dns ls
```

### ログ・モニタリング
```bash
# デプロイログ確認
vercel logs <deployment-url>

# リアルタイムログ
vercel logs --follow

# デプロイ一覧
vercel ls
```

### ローカル開発
```bash
# Vercel環境をローカルで再現
vercel dev

# 環境変数をローカルに取得
vercel env pull
```

## デプロイフロー推奨
1. `vercel` でプレビューデプロイ
2. プレビューURLで動作確認
3. 問題なければ `vercel --prod` で本番デプロイ

## 設定ファイル (vercel.json)
```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "framework": "vite",
  "regions": ["hnd1"],
  "functions": {
    "api/**/*.ts": {
      "memory": 1024,
      "maxDuration": 10
    }
  }
}
```

## ベストプラクティス
1. 本番デプロイ前に必ずプレビューで確認
2. 環境変数は `vercel env` で管理（.envをコミットしない）
3. リージョンは `hnd1`（東京）を指定して低レイテンシ化

---

## 実践Tips（トラブルシューティング）

### ダッシュボードでRedeployがロックされている場合

Vercelダッシュボードの「Redeploy」ボタンに鍵マークが表示され、クリックできない場合がある。

**原因:**
- 最新のコミットと同じ内容のため再デプロイ不要と判断されている
- 環境変数のみ変更した場合など

**解決策: CLIで強制デプロイ**
```bash
# 環境変数変更後の再デプロイ
npx vercel --prod --yes

# --yes オプションで確認プロンプトをスキップ
```

### デプロイ状況の確認
```bash
# デプロイ詳細を確認
npx vercel inspect <deployment-url>

# 例
npx vercel inspect https://my-app-abc123.vercel.app

# 出力例:
# id: dpl_xxxxx
# status: ● Ready
# url: https://...
# Aliases: (割り当てられたドメイン一覧)
```

### カスタムドメインの追加

**CLI経由:**
```bash
# ドメイン追加
vercel domains add usacon-ai.com

# プロジェクトにドメイン割り当て
vercel alias set <deployment-url> usacon-ai.com
```

**ダッシュボード経由（推奨）:**
1. Project → Settings → Domains
2. 「Add Existing」をクリック（購入済みドメイン用）
3. ドメイン名を入力（サジェストから選択可能）
4. リダイレクト設定を選択:
   - `example.com` → `www.example.com` (Recommended)
5. 環境を選択: Production
6. 「Save」をクリック

**ドメイン設定の確認:**
```bash
# ドメイン詳細
vercel domains inspect usacon-ai.com

# DNS設定確認
vercel dns ls usacon-ai.com
```

### 環境変数の環境別設定

Vercelでは同じ変数名で環境ごとに異なる値を設定可能：

| 環境 | 用途 | 例 |
|------|------|-----|
| **Production** | 本番環境 | `sk_live_...` |
| **Preview** | PRプレビュー | `sk_test_...` |
| **Development** | ローカル連携 | `sk_test_...` |

**CLI経由:**
```bash
# 本番環境のみに追加
vercel env add STRIPE_SECRET_KEY production

# プレビュー環境のみに追加
vercel env add STRIPE_SECRET_KEY preview

# 複数環境に追加
vercel env add API_KEY production preview
```

**ダッシュボード経由:**
1. Project → Settings → Environment Variables
2. 変数を追加/編集
3. 「Environments」で適用環境を選択:
   - ✅ Production
   - ✅ Preview
   - ✅ Development
4. 同じ変数名で環境ごとに異なる値を設定可能

### よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `unknown or unexpected option: --yes` | 一部コマンドで `--yes` 非対応 | オプションを外して実行 |
| Redeploy locked | コード変更なし | `vercel --prod` でCLIデプロイ |
| Domain not in aliases | ドメイン未割り当て | Settings → Domains で追加 |
| 環境変数が反映されない | キャッシュ使用 | `--force` オプションで再ビルド |

```bash
# キャッシュを無視して再デプロイ
vercel --prod --force
```

---

## チェックリスト

- [ ] 本番デプロイ前にプレビューで動作確認したか
- [ ] 環境変数が正しい環境（Production/Preview/Development）に設定されているか
- [ ] リージョンが `hnd1`（東京）に設定されているか
- [ ] `.env` ファイルがコミットされていないか

## 関連スキル

- **usacon** — Vercelデプロイの実プロジェクト
- **vercel-watch** — デプロイ監視（PRマージ後のReady検知）
- **github-cli** — PRマージによるデプロイトリガー

## 参考
- 公式ドキュメント: https://vercel.com/docs/cli

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-04 | 横断テンプレート適用（トリガー、チェックリスト、関連スキル、改訂履歴追加） | スキル品質改善計画 |
| 2026-02-20 | 実践Tips（トラブルシューティング、ドメイン、環境変数）追加 | 実運用で発見された問題の知見化 |
| 2026-02-10 | 初版作成 | Vercel CLI操作の標準化 |
