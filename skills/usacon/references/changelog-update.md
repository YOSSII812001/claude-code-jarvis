# 更新履歴・バージョン自動更新（staging プッシュ時）

> 元のSKILL.mdの「更新履歴・バージョン自動更新（staging プッシュ時）」セクションから抽出

> **stagingにプッシュする際、サブエージェントで更新履歴とバージョン情報を自動更新すること。**

## 対象ファイル

| ファイル | 更新内容 |
|---------|---------|
| `frontend/src/data/changelog.ts` | 新しい `ChangelogEntry` を配列の**先頭**に追加 |

## サブエージェントによる自動更新手順

staging へのPRマージ前に、以下をサブエージェント（Taskツール, subagent_type: general-purpose）で実行する。

**1. 変更内容の把握:**
```bash
# staging に含まれる差分を確認
git diff staging...HEAD --stat
git log staging..HEAD --oneline
```

**2. バージョン番号の決定:**

| 変更タイプ | バージョンアップ | 例 |
|-----------|-----------------|-----|
| 新機能追加 | マイナー（x.Y.0） | 1.3.0 → 1.4.0 |
| 改善・UI変更 | パッチ（x.y.Z） | 1.3.0 → 1.3.1 |
| バグ修正 | パッチ（x.y.Z） | 1.3.0 → 1.3.1 |
| 破壊的変更 | メジャー（X.0.0） | 1.3.0 → 2.0.0 |

**3. `changelog.ts` にエントリ追加:**
```typescript
// 配列の先頭に追加
{
  version: '1.4.0',          // 新バージョン
  date: '2026-02-13',        // 当日の日付（YYYY-MM-DD）
  title: '○○機能を追加',     // 端的な1行タイトル
  category: 'feature',       // 'feature' | 'improvement' | 'fix'
  items: [                   // 変更内容を箇条書き（2〜5項目）
    '主な変更点1',
    '主な変更点2',
  ],
},
```

> **注**: Issue #666 対応済み — `AccountMenu.tsx` は `getLatestVersion()` で `changelog.ts` から動的取得するため、`changelog.ts` のみの更新で自動同期される。

## 記載ルール

- **タイトル**: ユーザー視点で端的に記述（「〜を追加」「〜を改善」「〜を修正」）
- **items**: 技術的すぎない表現で2〜5項目。ユーザーに伝わる粒度
- **category**: 変更の性質に応じて `feature` / `improvement` / `fix` を選択
- **日付**: staging にプッシュする当日の日付

## サブエージェント実行例

```
Taskツール（subagent_type: general-purpose）に以下を依頼:

「以下のgit diffの内容をもとに、frontend/src/data/changelog.ts に新しいエントリを
配列の先頭に追加してください。AccountMenu.tsx は getLatestVersion() で自動同期
されるため更新不要です。

バージョン番号は [現在の最新バージョン] からセマンティックバージョニングに従って
決定してください。タイトルとitemsはユーザー視点で端的に記載してください。

[git diff の内容]」
```

## フロー図

```
実装完了
  ↓
/sub-review（構造化コードレビュー）
  ↓
サブエージェントで changelog.ts を更新（AccountMenu.tsx は自動同期）
  ↓
コミット（例: "chore: update changelog v1.4.0"）
  ↓
staging にPR作成・マージ
  ↓
preview.usacon-ai.com でE2Eテスト
  ↓
main にマージ → 本番リリース
```
