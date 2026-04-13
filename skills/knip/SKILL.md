---
name: Knip - Dead Code Detection
description: |
  JS/TSプロジェクトの未使用コード（ファイル・エクスポート・依存関係）を検出するKnipの段階的使用ガイド。
  143個の組み込みプラグインでNext.js/Vite/ESLint等を自動検出。monorepo対応。
  段階的Safety Levels（診断→選択修正→包括修正）で安全にdead code除去を実行。
  トリガー: "knip", "dead code", "デッドコード", "未使用コード", "unused exports",
  "未使用ファイル", "未使用依存", "コードクリーンアップ"
  使用場面: (1) dead code検出・削除、(2) 未使用依存の整理、(3) monorepoのexport棚卸し
---

# Knip - Dead Code Detection ガイド

## 概要

Knip（クニップ）はJS/TSプロジェクトの未使用コードを静的解析で検出するCLIツール。
プロジェクト全体の依存グラフを構築し、未使用ファイル・エクスポート・依存関係を一括検出する。
143個の組み込みプラグイン（Next.js, Vite, Tailwind, ESLint等）が`package.json`から自動検出される。

### codebase-patrol との使い分け

| 用途 | ツール | 特徴 |
|------|--------|------|
| 日常の軽量スキャン | codebase-patrol P2 | gate keeper。定期パトロールで新規dead codeを早期検出 |
| 大規模クリーンアップ | **knip** | deep clean。依存グラフ全体を解析し、精密検出＋自動修正 |

推奨パイプライン: `codebase-patrol で検出 → knip で詳細分析・修正`

## インストール確認

```bash
npx knip --version
```

**要件**: Node.js 18.6+

インストール（プロジェクトへの追加を推奨）:
```bash
# devDependencies として追加（推奨）
npm install -D knip    # npm
pnpm add -D knip       # pnpm

# npx で都度実行も可能（設定ファイルを置く場合はdevDep推奨）
npx knip
```

## Safety Levels（段階的アプローチ）

**このスキルの核心。** 初回は必ずLevel 1から開始し、段階的にレベルを上げる。

| Level | 名称 | コマンド | 変更内容 | リスク |
|-------|------|---------|---------|--------|
| 1 | Scan & Report | `npx knip` | なし（診断のみ） | なし |
| 2a | Export Fix | `npx knip --fix --include exports` | 未使用export削除 | 低 |
| 2b | Type Fix | `npx knip --fix --include types` | 未使用型削除 | 低 |
| 2c | Dependency Fix | `npx knip --fix --include dependencies` | package.json依存除去 | **中** |
| 3 | Full Cleanup | `npx knip --fix --allow-remove-files` | ファイル削除含む全修正 | **高** |

### Level 1: Scan & Report（診断のみ）

```bash
# 標準出力（詳細）
npx knip

# コンパクト表示（初回概観に最適）
npx knip --reporter compact

# 本番コードのみ（テスト・devDeps除外）
npx knip --production

# 厳密モード（re-export含む、workspace隔離検証）
npx knip --strict
```

変更は一切行わない。出力を読んで現状を把握するだけ。
初回実行は大規模プロジェクトで数十秒〜数分かかる場合がある。

### Level 2a: Export Fix（低リスク）

```bash
git checkout -b chore/knip-export-cleanup
npx knip --fix --include exports
git diff --stat
npm test && npm run build
```

未使用`export`/`export default`キーワードのみ削除。ファイル自体は削除しない。

### Level 2b: Type Fix（低リスク）

```bash
npx knip --fix --include types
git diff --stat
npm test && npm run build
```

未使用の型定義（interface, type）を削除。

### Level 2c: Dependency Fix（中リスク — monorepo注意）

```bash
npx knip --fix --include dependencies
git diff --stat
npm test && npm run build
```

**monorepoでは特に注意**: パッケージAから依存を除去するとパッケージBが暗黙的に依存していた場合にビルドが壊れる。
実行前に必ずLevel 1で対象を確認し、不安な依存は`ignoreDependencies`に追加してから実行する。

### Level 3: Full Cleanup（高リスク）

```bash
git checkout -b chore/knip-full-cleanup
npx knip --fix --allow-remove-files
git diff --stat              # 削除ファイル一覧を目視確認
npm test && npm run build    # テスト + ビルド確認
```

ファイル削除を含む包括的修正。Level 2a〜2cを少なくとも1回成功させてから実行すること。

### 全Level共通: 実行前チェック（Level 2a以上で必須）

```bash
# 1. 作業ツリーがクリーンか確認
git status

# 2. 新ブランチ作成
git checkout -b chore/knip-cleanup

# 3. Level 1で対象を事前確認（dry-run相当）
npx knip --reporter compact
```

### ロールバック手順

```bash
# 全変更を取り消し
git checkout -- .

# または特定ファイルのみ復元
git checkout -- path/to/file.ts
```

## 基本コマンド

### レポーター

| Reporter | 用途 | コマンド |
|----------|------|---------|
| symbols | デフォルト（詳細） | `npx knip` |
| compact | 概要把握（初回推奨） | `npx knip --reporter compact` |
| json | Claude分析用 | `npx knip --reporter json > knip-report.json` |
| markdown | PR/Issue用 | `npx knip --reporter markdown` |
| github-actions | PRアノテーション | `npx knip --reporter github-actions` |

### スコープ制御

```bash
# 本番コードのみ（テスト・devDeps除外）
npx knip --production

# 厳密モード
npx knip --strict

# 特定ワークスペースのみ（monorepo）
npx knip --workspace packages/my-lib

# 特定カテゴリのみ表示
npx knip --include exports
npx knip --include dependencies
npx knip --include files
```

### パフォーマンス

```bash
# キャッシュ有効化（10-40%高速化、2回目以降）
npx knip --cache

# ウォッチモード（開発中の継続監視）
npx knip --watch

# メモリ使用量表示
npx knip --memory
```

## 検出カテゴリ

| カテゴリ | 説明 | `--include`値 |
|---------|------|--------------|
| 未使用ファイル | どこからも参照されないファイル | `files` |
| 未使用依存 | package.jsonにあるが使われていない | `dependencies` |
| 未使用devDeps | devDependenciesで未使用 | `devDependencies` |
| 未リスト依存 | コードで使うがpackage.jsonにない | `unlisted` |
| 未使用export | exportされているがimportされていない | `exports` |
| 未使用型 | interface/typeが未使用 | `types` |
| 重複export | 同じものが複数回export | `duplicates` |

## False Positive管理

Knipで最も重要なセクション。誤検知を適切に管理しないと信頼性が損なわれる。

### knip.json での除外設定

```jsonc
{
  // 特定ファイルを除外
  "ignore": [
    "src/types/database.types.ts",  // 自動生成ファイル
    "**/*.generated.ts"
  ],
  // 特定依存を除外
  "ignoreDependencies": [
    "@types/*",                     // 型定義パッケージ
    "dotenv"                        // 起動時にのみ使用
  ],
  // 特定バイナリを除外
  "ignoreBinaries": ["docker"]
}
```

### よくある誤検知パターン

| パターン | 原因 | 対処 |
|---------|------|------|
| 動的import `import()` | 静的解析の限界 | `ignoreDependencies`に追加 |
| barrel files (index.tsからre-export) | re-exportチェーンの解析 | `--strict`を外す or workspace設定を確認 |
| 自動生成ファイル | Knipがエントリとして認識しない | `ignore`に追加 |
| 環境変数で切り替える依存 | 実行時のみ使用 | `ignoreDependencies`に追加 |
| テストユーティリティ | productionモードで除外される | `--production`を外す |

### ファイル内での除外

```typescript
// @knipignore - 動的に使用されるため除外
export function dynamicHandler() { ... }
```

## Monorepo対応

### workspace設定

Knipは`package.json`の`workspaces`または`pnpm-workspace.yaml`から自動検出する。
手動設定する場合は`knip.json`の`workspaces`に記載。

```bash
# 特定ワークスペースのみスキャン
npx knip --workspace packages/my-lib

# glob指定
npx knip --workspace 'packages/*'
```

### Usacon monorepo 固有の注意

**依存チェーン**: `app-core → api-client → usacon-cli`

- **app-core単体のスキャン注意**: app-coreのexportがapi-clientから参照されている場合でも、
  app-core単体でknipを実行すると「未使用export」と誤検知される可能性がある。
  必ずルートからworkspace全体をスキャンすること。
- **修正後のビルド順序**: `pnpm -r build` でapp-coreを先にビルドしないとDTS解決エラーが発生する。
  `npx knip --fix` 実行後は必ず `pnpm -r build` でビルド通過を確認する。

## knip.json テンプレート

### Monorepo用（Usacon対応）

```jsonc
{
  "$schema": "https://unpkg.com/knip@latest/schema.json",
  // シングルプロジェクトの場合: workspacesを削除し、entry/projectをルートに記載
  "workspaces": {
    ".": {
      "entry": ["scripts/*.{js,ts}"],
      "project": ["scripts/**/*.{js,ts}"]
    },
    "frontend": {
      "entry": ["src/main.tsx", "src/App.tsx"],
      "project": ["src/**/*.{ts,tsx}"],
      "ignore": ["src/types/database.types.ts"]
    },
    "api": {
      "entry": ["**/*.ts"],
      "project": ["**/*.ts"]
    },
    "packages/app-core": {
      "entry": ["src/index.ts"],
      "project": ["src/**/*.ts"]
    },
    "packages/api-client": {
      "entry": ["src/index.ts"],
      "project": ["src/**/*.ts"]
    },
    "packages/usacon-cli": {
      "entry": ["src/cli.ts", "src/index.ts"],
      "project": ["src/**/*.{ts,tsx}"]
    }
  },
  "ignoreDependencies": ["@types/*"],
  "ignore": ["**/*.generated.ts", "**/database.types.ts"]
}
```

## AI連携ワークフロー（Knip + Claude分析）

### Step 1: JSONレポート生成

```bash
# 全体レポート
npx knip --reporter json > knip-report.json

# 大規模プロジェクトではカテゴリ絞り込み推奨（JSON出力が巨大になるため）
npx knip --reporter json --include exports > knip-exports.json
npx knip --reporter json --include dependencies > knip-deps.json
```

### Step 2: Claude分析

knip-report.jsonを読み込み、各検出項目を分類:
- **安全に削除可能**: テストもなく、grep検索でも参照なし
- **要確認**: 動的importの可能性、barrel fileからのre-export
- **保持推奨**: 公開APIとして意図的に残している

### Step 3: 段階的修正

Level 2a→2b→2cの順で、Claude分析結果を踏まえて実行。
各Level実行後に `npm test && npm run build` で検証。

## ベストプラクティス

1. **初回は必ずLevel 1から** — いきなり`--fix`しない
2. **`--production`で本番影響を先に確認** — テストコードのdead codeは後回し
3. **`--fix`前に必ず新ブランチを作成** — ロールバック可能にする
4. **自動生成ファイルをignoreに追加** — database.types.ts, *.generated.ts等
5. **monorepoではルートからスキャン** — 単一パッケージスキャンは誤検知リスク
6. **`--cache`を常用** — 2回目以降10-40%高速化
7. **Level 2cは慎重に** — 依存除去はmonorepoで最も危険な操作

## チェックリスト

### Level 1 実行前
- [ ] `npx knip --version` でKnipが利用可能か
- [ ] Node.js 18.6+ か

### Level 2a〜2c 実行前（必須）
- [ ] `git status` で作業ツリーがクリーンか
- [ ] 新ブランチを作成したか
- [ ] Level 1で対象を事前確認したか
- [ ] knip.jsonのignore設定が適切か（false positive除外済み）

### Level 2a〜2c 実行後（必須）
- [ ] `git diff --stat` で変更ファイル一覧を確認したか
- [ ] `npm test` が通るか
- [ ] `npm run build` が通るか（monorepoでは`pnpm -r build`）
- [ ] 意図しない変更がないか

### Level 3 実行前（最重要）
- [ ] Level 2a〜2cを少なくとも1回成功させたか
- [ ] `--allow-remove-files` の意味を理解しているか（ファイル自体が削除される）

### Level 3 実行後（最重要）
- [ ] 削除ファイル一覧を1つずつ目視確認したか
- [ ] 削除ファイルが動的importで使われていないかgrep確認したか
- [ ] `npm test` + `npm run build` が通るか
- [ ] E2Eテストが通るか（推奨）

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| 大量の誤検知が出る | entry/project設定不足 | knip.jsonで正しいエントリポイントを指定。プラグインの設定ファイルパスが非標準なら明示的に指定 |
| monorepoで一部workspaceが無視される | workspaces設定漏れ | knip.jsonのworkspacesに全パッケージを追加。`pnpm-workspace.yaml`との整合性を確認 |
| 動的importが未使用と判定される | 静的解析の限界 | `ignoreDependencies`で除外。`import()`で読み込むモジュールはknipの検出対象外 |
| OOM（メモリ不足）で落ちる | 大規模プロジェクト | `NODE_OPTIONS=--max-old-space-size=8192 npx knip`。または`--workspace`で範囲を絞る |

## 関連スキル

| スキル | 連携ポイント |
|--------|-------------|
| **codebase-patrol** | P2 Dead Codeルール（DEAD-01/02/03）との補完。patrol=軽量監視、knip=精密分析 |
| **usacon** | Usacon monorepoでのknip導入・運用 |

## 参考

- 公式サイト: https://knip.dev
- GitHub: https://github.com/webpro-nl/knip
- CLIリファレンス: https://knip.dev/reference/cli
- 設定リファレンス: https://knip.dev/reference/configuration
- プラグイン一覧: https://knip.dev/reference/plugins
- Monorepo対応: https://knip.dev/features/monorepos-and-workspaces
- Auto-fix: https://knip.dev/features/auto-fix

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-10 | 初版作成 | JS/TS dead code検出ツールの段階的導入スキル。Codexレビュー反映済み |
