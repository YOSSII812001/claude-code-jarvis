---
name: ryokan-forecast
description: 温泉旅館向けTimesFM需要予測システムの開発・運用ガイド。Next.js 16 + shadcn/ui v4 + Supabase + ローカルPythonワーカー構成。デザインはLovable風温かみスタイル。
---

# ryokan-forecast — 温泉旅館 需要予測システム

## 概要
温泉旅館オーナーが過去の予約・稼働データ（CSV）をアップロードし、TimesFM（Google OSS時系列基盤モデル）で30〜90日先の稼働率・宿泊客数・売上を予測するシステム。予測結果に基づく人員配置・価格設定・食材発注のインサイトも自動生成する。

**トリガー:** `ryokan-forecast`, `旅館予測`, `需要予測`, `TimesFM`, `温泉旅館`

## プロジェクト情報

| 項目 | 値 |
|------|-----|
| **ローカルリポジトリ** | `C:\Users\zooyo\Documents\GitHub\DX\ryokan-forecast` |
| **フレームワーク** | Next.js 16.2.2 (App Router, Turbopack) |
| **UI** | shadcn/ui v4 (@base-ui/react) + Tailwind CSS v4 |
| **DB** | Supabase (PostgreSQL + Auth + Realtime) |
| **推論** | ローカルPython Worker (TimesFM 2.5 200M) |
| **デプロイ** | Vercel |
| **テナント** | MVPシングルテナント（user_idベース） |
| **デザイン** | Lovable DESIGN.md準拠（和紙クリーム+銅色テーマ） |

## アーキテクチャ

```
┌─────────────────────────────────┐
│   Vercel (Next.js App Router)   │
│   - ダッシュボード（チャート表示） │
│   - データアップロードUI          │
│   - API Routes (BFF)            │
│   - 認証 (Supabase Auth)        │
└──────────┬──────────────────────┘
           │ Supabase JS Client
           ▼
┌─────────────────────────────────┐
│   Supabase (PostgreSQL + Auth)  │
│   - 時系列データ保存             │
│   - 予測ジョブキュー（Realtime） │
│   - 予測結果・インサイト保存     │
└──────────┬──────────────────────┘
           │ Supabase Python Client (ポーリング)
           ▼
┌─────────────────────────────────┐
│   Local Python Worker           │
│   (ユーザーのPC上で実行)         │
│   - TimesFM 2.5 200M 推論      │
│   - ジョブ監視 → 推論 → 結果書戻│
└─────────────────────────────────┘
```

**通信フロー（Supabaseがメッセージブローカー）:**
1. Web UIで予測リクエスト → `forecast_jobs` に `queued` レコード作成
2. Pythonワーカーがポーリングでジョブ検知 → `running` に更新
3. TimesFM推論実行 → `forecast_results` に結果書き込み → `completed`
4. フロントエンドがSupabase Realtimeで完了検知 → チャート表示

## ディレクトリ構造

```
ryokan-forecast/
├── src/
│   ├── app/                          # Next.js App Router
│   │   ├── layout.tsx                # Root layout (Noto Sans JP, QueryProvider, TooltipProvider)
│   │   ├── page.tsx                  # LP（ヒーロー + 特徴カード）
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx        # ログイン (Supabase Auth)
│   │   │   └── signup/page.tsx       # サインアップ
│   │   └── (dashboard)/
│   │       ├── layout.tsx            # サイドバー付きレイアウト (SidebarProvider)
│   │       └── dashboard/
│   │           ├── page.tsx          # メインダッシュボード（サマリーカード）
│   │           ├── upload/page.tsx   # CSVアップロード + データプレビュー
│   │           ├── forecast/page.tsx # 予測実行 + Realtimeジョブ監視 + チャート
│   │           ├── insights/page.tsx # インサイト一覧（カテゴリ別カード）
│   │           └── settings/page.tsx # 旅館情報CRUD (React Hook Form + Zod)
│   ├── components/
│   │   ├── ui/                       # shadcn/ui v4 コンポーネント（17個）
│   │   ├── charts/
│   │   │   └── forecast-chart.tsx    # Recharts: ComposedChart (Area+Line, 信頼区間)
│   │   ├── layout/
│   │   │   ├── app-sidebar.tsx       # サイドバーナビゲーション
│   │   │   └── dashboard-header.tsx  # ヘッダー + ログアウト
│   │   └── providers/
│   │       └── query-provider.tsx    # TanStack Query Provider
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts            # ブラウザ用 (createBrowserClient)
│   │   │   ├── server.ts            # Server Component用 (createServerClient)
│   │   │   ├── admin.ts             # Service Role (API Routes用, RLSバイパス)
│   │   │   └── middleware.ts         # Proxy用セッション更新ロジック
│   │   ├── types/
│   │   │   └── database.ts          # 全テーブル型定義 + メトリクス/カテゴリラベル
│   │   └── utils/
│   │       └── csv-parser.ts         # Papa Parse CSV解析 + メトリクス列自動検出
│   ├── hooks/
│   │   └── use-mobile.ts            # shadcn/ui モバイル検出
│   └── proxy.ts                      # Next.js 16 Proxy (旧middleware.ts)
├── worker/                           # ローカルPythonワーカー
│   ├── worker.py                     # メインループ（ジョブ監視 + 処理 + 結果保存）
│   ├── forecast_engine.py            # TimesFMモデルロード + 推論ラッパー
│   ├── config.py                     # 環境変数・設定
│   ├── requirements.txt              # torch, timesfm, supabase-py, etc.
│   └── README.md                     # セットアップ手順
├── supabase/migrations/
│   ├── 00001_create_base_schema.sql  # profiles, ryokans, トリガー, RLS
│   └── 00002_create_forecast_tables.sql # data_sources, time_series_data,
│                                       # forecast_jobs, forecast_results,
│                                       # insights, Realtime有効化
├── next.config.ts                    # turbopack.root設定
├── vercel.json                       # セキュリティヘッダー
├── .env.local.example                # 環境変数テンプレート
├── CLAUDE.md                         # プロジェクト固有Claude Code設定
└── package.json
```

## 技術スタック

### フロントエンド (Vercel)
| パッケージ | バージョン | 用途 |
|-----------|-----------|------|
| next | 16.2.2 | App Router + Turbopack |
| react | 19.2.4 | UI |
| shadcn (v4) | 4.1.2 | UIコンポーネント (@base-ui/react ベース) |
| tailwindcss | v4 | スタイリング |
| recharts | 3.8.0 | チャート描画 |
| @tanstack/react-query | 5.x | サーバー状態管理 |
| react-hook-form | 7.x | フォーム |
| zod | 4.x | バリデーション（`from "zod"` でimport） |
| papaparse | 5.x | CSV解析 |
| @supabase/ssr | 0.10.x | Next.js Supabase Auth |
| date-fns | 4.x | 日付操作 |
| lucide-react | 1.x | アイコン |

### Pythonワーカー
| パッケージ | 用途 |
|-----------|------|
| torch | PyTorch (CPU/GPU) |
| timesfm | Google TimesFM 2.5 200M |
| supabase | Supabase Python Client |
| python-dotenv | 環境変数 |
| numpy, pandas | データ処理 |

## データベーステーブル（7テーブル）

```
profiles (auth.users連携、自動作成トリガー)
ryokans (user_id FK → 旅館情報)
  ├── data_sources (CSVアップロード管理)
  ├── time_series_data (正規化済み時系列データ、UNIQUE(ryokan_id, date, metric_type))
  ├── forecast_jobs (予測ジョブキュー、status: queued→running→completed/failed)
  ├── forecast_results (点推定 + 10%/90%分位)
  └── insights (カテゴリ: staffing/pricing/inventory/marketing)
```

**RLS**: 全テーブルRLS有効。`ryokans.user_id = auth.uid()` ベース。
**Realtime**: `forecast_jobs` テーブルのみ有効（ステータス変更をフロントで検知）。

### メトリクスタイプ
| キー | 日本語 |
|------|--------|
| `occupancy_rate` | 稼働率 |
| `guest_count` | 宿泊客数 |
| `revenue` | 売上 |
| `bookings` | 予約件数 |

### CSVフォーマット（対応列名）
```csv
date,occupancy_rate,guest_count,revenue,bookings
2025-10-01,72,43,1280000,12
```
日本語列名も対応: `日付`, `稼働率`, `宿泊客数`, `売上`, `予約件数`

## Next.js 16 固有の注意点（重要）

### proxy.ts（旧middleware.ts）
- ファイル名: `src/proxy.ts`（`middleware.ts`は非推奨）
- エクスポート関数名: `proxy`（`middleware`ではない）
- `cookies()`, `headers()`, `params`, `searchParams` はすべて **async**（`await`必須）

### shadcn/ui v4（@base-ui/react）
- **`asChild` は使えない** → `render` プロップを使用
- 例: `<Button render={<Link href="/foo" />}>テキスト</Button>`
- `<SidebarMenuButton render={<Link href="/bar" />}>` も同様
- Tooltipは `<TooltipProvider>` でラップ必須（root layout）

### Zod v4
- `from "zod"` でimport（`from "zod/v4"` ではない。`@hookform/resolvers`との互換性）
- `z.coerce.number()` は型推論で `unknown` になる場合がある → `z.number()` を使い手動変換

### Turbopack
- `next.config.ts` で `turbopack.root: path.resolve(__dirname)` を設定済み
- 複数lockfile警告を回避

## デザイントークン（Lovable風温泉旅館テーマ）

| トークン | 値 | 用途 |
|---------|-----|------|
| `--background` | `#f7f4ed` | ページ背景（和紙クリーム） |
| `--foreground` | `#1c1c1c` | テキスト（温かいチャコール） |
| `--primary` | `#b87333` | CTA・アクセント（銅色） |
| `--border` | `#eceae4` | ボーダー（和紙色） |
| `--radius` | `0.75rem` | 角丸（大きめ） |
| `--chart-1〜5` | 銅・苔・栗・藍・薄銅 | チャートカラー（自然テーマ） |

Tailwindユーティリティクラス: `bg-cream`, `text-copper`, `border-washi`

フォント: **Noto Sans JP**（400, 500, 600, 700）

## ローカルSupabase（ポートオフセット +100）

usaconと同時起動するため、全ポートを+100オフセットしている。

| サービス | ポート | URL |
|---------|--------|-----|
| **API** | 54421 | http://127.0.0.1:54421 |
| **DB** | 54422 | postgresql://postgres:postgres@127.0.0.1:54422/postgres |
| **Studio** | 54423 | http://127.0.0.1:54423 |
| **Mail** | 54424 | http://127.0.0.1:54424 |
| **Analytics** | 54427 | — |

## 一括起動/停止（バッチファイル）

```
start-dev.bat    # Supabase + Next.js + Pythonワーカーを一括起動（3ウィンドウ）
stop-dev.bat     # Supabase停止（Dockerメモリ解放）
```

`start-dev.bat` の動作:
1. Docker起動確認
2. `npx supabase start`（同一ウィンドウ）
3. `npm run dev`（別ウィンドウ: "ryokan-forecast: Next.js"）
4. `worker/.venv + python worker.py`（別ウィンドウ: "ryokan-forecast: Worker"）
5. URL・テストアカウント情報を表示

## よく使うコマンド

```bash
# 一括起動（推奨）
start-dev.bat

# 個別起動
npx supabase start             # ローカルSupabase（Docker必須）
npm run dev                    # Next.js (port 3000)
cd worker && .venv\Scripts\activate && python worker.py  # ワーカー

# 停止
stop-dev.bat                   # Supabase停止（Dockerメモリ2GB解放）
npx supabase stop              # 同上（手動）

# ビルド・品質チェック
npm run build                  # TypeScript + ビルド確認
npm run lint                   # ESLint

# Pythonワーカー初回セットアップ
cd worker
py -3.11 -m venv .venv
.venv\Scripts\activate
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install "timesfm[torch] @ git+https://github.com/google-research/timesfm.git"
pip install supabase python-dotenv numpy pandas safetensors
```

## ネットワーク要件

- **インターネット接続**: 天気データ取得に必要（Open-Meteo API 3エンドポイント）
  - `archive-api.open-meteo.com` — 過去の気象データ
  - `api.open-meteo.com` — 天気予報（16日先）
  - `geocoding-api.open-meteo.com` — 所在地→座標変換
- **オフライン時**: 天気取得をスキップし、祝日・曜日・季節の8共変量のみで予測（エラーにならない）
- **TimesFMモデル**: 初回のみHugging Faceからダウンロード（約800MB）、2回目以降はローカルキャッシュ
- **Supabase/Next.js**: ローカル動作のため接続不要

## テスト用アカウント

**ローカル開発時（http://localhost:3000/signup で登録）:**
```
メール: test@ryokan.jp
パスワード: password123
名前: テスト旅館オーナー
```

ローカルSupabaseはメール確認不要。サインアップ即ログイン可能。
Studio（http://127.0.0.1:54423）でAuth > Usersからユーザー確認可能。

## 環境変数

```env
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# worker/.env（同じ値）
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

## 主要ページURL

| ページ | パス | 機能 |
|--------|------|------|
| ランディング | `/` | ヒーロー + 特徴紹介 + CTA |
| ログイン | `/login` | Supabase Auth Email/Password |
| サインアップ | `/signup` | アカウント作成 |
| ダッシュボード | `/dashboard` | サマリーカード（稼働率・客数・売上・次回更新） |
| データ管理 | `/dashboard/upload` | CSV drag&drop + データプレビュー + バッチ保存 |
| 需要予測 | `/dashboard/forecast` | メトリクス選択 → ジョブ作成 → Realtimeステータス → チャート |
| インサイト | `/dashboard/insights` | カテゴリ別アクション提案カード |
| 設定 | `/dashboard/settings` | 旅館情報CRUD (名前・所在地・客室数・客室タイプJSON) |

## 改造・拡張ガイド

### 新しいメトリクスタイプの追加
1. `src/lib/types/database.ts` の `MetricType` に追加
2. `METRIC_LABELS` に日本語ラベル追加
3. `src/lib/utils/csv-parser.ts` の `HEADER_MAPPING` にCSV列名マッピング追加
4. `worker/worker.py` の `generate_insights()` にルール追加（任意）

### マルチテナント化
1. `organizations` + `memberships` テーブル追加（usaconパターン参照）
2. RLSを `user_id` → `org_id` 経由に変更
3. `ryokans` テーブルに `org_id` カラム追加

### Cloud Run移行（ワーカー）
1. `worker/` に `Dockerfile` 追加（Python 3.11 + torch CPU + timesfm）
2. `worker/main.py` にFastAPIエンドポイント追加
3. Vercel API Routeから直接Cloud RunのHTTPSエンドポイントを呼ぶ方式に変更
4. `forecast_jobs` のポーリング → HTTP同期呼び出しに変更

### チャート追加
- `src/components/charts/` に新コンポーネントを配置
- Rechartsベース: `ComposedChart`, `AreaChart`, `BarChart` 等
- shadcn/ui の `chart.tsx` (ChartContainer) は未使用（直接Rechartsを使用）

## 参照すべき既存パターン（usaconプロジェクト）

| パターン | 参照元 |
|---------|--------|
| Supabase dual client | `digital-management-consulting-app/api/_lib/config/database.js` |
| org_id マルチテナント | `digital-management-consulting-app/supabase/migrations/20251007000001_*.sql` |
| Vercel vercel.json | `digital-management-consulting-app/vercel.json` |
| Lovable DESIGN.md | `~/.claude/skills/awesome-design-md/repo/design-md/lovable/DESIGN.md` |

## 別PCへの移行手順

1. プロジェクトフォルダをコピー（node_modules, .venv, .next, .git は除外）
2. 移行先で以下を実行:

```bash
# Node.js依存
npm install

# Docker起動 → ローカルSupabase
npx supabase start

# .env.local 作成（npx supabase status の出力から）
# NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

# Python環境
cd worker
py -3.11 -m venv .venv
.venv\Scripts\activate
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install "timesfm[torch] @ git+https://github.com/google-research/timesfm.git"
pip install supabase python-dotenv numpy pandas safetensors jax jaxlib openmeteo-requests requests-cache

# worker/.env も作成（NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY）

# 一括起動
start-dev.bat
```

3. http://localhost:3000 で動作確認
4. TimesFMモデルは初回起動時にHugging Faceから自動DL（約800MB）

## 初回セットアップ手順（ゼロから）

1. `npx create-next-app@latest` でプロジェクト作成（既に完了済み）
2. `npx supabase init` → `npx supabase start`
3. `.env.local` に接続情報記入
4. `npm run dev` でフロントエンド起動確認
5. Pythonワーカーセットアップ（上記の移行手順と同じ）
6. テストCSVアップロード → 予測実行 → 結果確認

## 共有フォルダ

`G:\マイドライブ\Google ドライブ\◎仕事共有\よろず支援拠点\ryokan-forecast\` にバックアップコピーあり

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-07 | 初版作成: MVP全体構造、技術スタック、DB、デザイン、改造ガイド |
| 2026-04-07 | TimesFMフル活用（共変量API修正、天気データ、ジオコーディング）|
| 2026-04-07 | Lovable DESIGN.md完全適用、分析手法ページ、信頼度バッジ |
| 2026-04-07 | 別PC移行手順追加、README.md整備 |
