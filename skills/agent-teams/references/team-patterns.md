<!-- 抽出元: SKILL.md のセクション「チーム構造テンプレート（4パターン）」 -->

# Agent Teams チーム構造パターン

## パターン1: フロントエンド + バックエンド分離

```
適用条件: Web アプリケーション開発、API + UI が明確に分離できる場合
推奨人数: 2~3人
```

| ロール | 所有ファイル | 禁止ファイル |
|--------|-------------|-------------|
| **backend** | `src/api/**`, `src/lib/server/**`, `tests/api/**` | `src/ui/**`, `src/components/**` |
| **frontend** | `src/ui/**`, `src/components/**`, `tests/ui/**` | `src/api/**`, `src/lib/server/**` |
| **shared（→ backend担当）** | `types/**`, `src/lib/shared/**` | - |

```
失敗パターン:
  ✗ APIレスポンスの型を frontend が勝手に変更
  ✗ バリデーションロジックを両方が実装して不整合
  ✗ エントリーポイントを両方が編集

防止策:
  → 型定義は backend が先に確定、frontend は Read のみ
  → バリデーションは shared に置き、single_writer を指定
  → エントリーポイントは最後にリーダーが統合
```

---

## パターン2: 機能モジュール分離

```
適用条件: 複数の独立した機能を同時実装する場合
推奨人数: 2~4人
```

| ロール | 所有ファイル | 禁止ファイル |
|--------|-------------|-------------|
| **feature-auth** | `src/**/auth*`, `tests/**/auth*` | 他機能の `src/**` |
| **feature-payment** | `src/**/payment*`, `tests/**/payment*` | 他機能の `src/**` |
| **feature-notification** | `src/**/notification*`, `tests/**/notification*` | 他機能の `src/**` |

```
失敗パターン:
  ✗ 機能間で共有するユーティリティを複数人が同時作成
  ✗ ルーティングファイルを複数人が同時編集
  ✗ 共通コンポーネントに異なる変更を加える

防止策:
  → 共通ユーティリティは事前に作成するか、1人に委任
  → ルーティングの追加はリーダーが統合時に実施
  → 共通コンポーネントは変更禁止、必要なら専用コンポーネントを作成
```

---

## パターン3: 実装 + テスト分離

```
適用条件: 既存コードへの機能追加でテストカバレッジを維持したい場合
推奨人数: 2人
```

| ロール | 所有ファイル | 禁止ファイル |
|--------|-------------|-------------|
| **implementer** | `src/**`（テスト以外） | `tests/**`, `__tests__/**` |
| **tester** | `tests/**`, `__tests__/**`, `src/**/*.test.*` | `src/**`（テスト以外） |

```
テスト担当の先行作業（重要）:
  implementer がコードを書き始める前に、tester は以下を先行実装:
  1. モックファイル（tests/mocks/）の作成
  2. テストフィクスチャ（tests/fixtures/）の準備
  3. テストヘルパー関数の定義
  4. テストの骨格（describe/it ブロック）を TODO で配置

  → implementer の実装と同時並行でテストを肉付けしていく

失敗パターン:
  ✗ tester が実装待ちでアイドル状態が長い
  ✗ implementer がテストを書いてしまう（所有権違反）
  ✗ インターフェースが未確定のままテスト作成

防止策:
  → tester は先行作業で手が止まらないようにする
  → 型定義 / インターフェースを最初に確定させる
  → implementer は実装のみ、テストは tester に任せる
```

---

## パターン4: リファクタリング（ディレクトリ分離）

```
適用条件: 大規模リファクタリングでディレクトリ単位に分担できる場合
推奨人数: 2~3人
```

| ロール | 所有ファイル | 禁止ファイル |
|--------|-------------|-------------|
| **refactor-core** | `src/core/**`, `src/lib/**` | `src/features/**`, `src/pages/**` |
| **refactor-features** | `src/features/**` | `src/core/**`, `src/lib/**`, `src/pages/**` |
| **refactor-pages** | `src/pages/**`, `src/routes/**` | `src/core/**`, `src/features/**` |

```
失敗パターン:
  ✗ core の変更で features の import パスが壊れる
  ✗ リネーム対象が複数ディレクトリにまたがる
  ✗ 共有ユーティリティの移動先が競合

防止策:
  → core の変更を最初に完了、その後 features/pages が対応
  → 依存関係の方向: core ← features ← pages の順で統合
  → ユーティリティの移動は 1人が担当し、他は完了待ち
  → TaskCreate で blockedBy を設定して順序を制御
```
