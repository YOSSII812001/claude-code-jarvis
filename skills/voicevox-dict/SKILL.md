---
name: voicevox-dict
description: |
  VOICEVOX ユーザー辞書の管理スキル。単語登録・一括登録・バックアップ・リストアを提供。
  技術用語の発音修正をClaude Codeが自律的に実行できる。
  トリガー: "voicevox辞書", "辞書登録", "発音修正", "読み方登録",
  "pronunciation", "user dict", "VOICEVOX dictionary", "voicevox-dict"
  使用場面: (1) 技術用語の発音が不自然な時の即時修正、
  (2) 新プロジェクト開始時の一括辞書登録、(3) 辞書のバックアップ・復元
---

# VOICEVOX 辞書管理ガイド

## 概要

VOICEVOX Engine (`http://127.0.0.1:50021`) のユーザー辞書APIを通じて、speak_jarvis.ps1 の音声品質を向上させる。
ヘルパースクリプト: `~/.claude/skills/voicevox-dict/voicevox-dict-helper.ps1`

## クイックリファレンス

| 操作 | コマンド |
|------|---------|
| 一覧表示 | `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1" -Action List` |
| 単語登録 | `... -Action Register -Surface "Vercel" -Pronunciation "バーセル" -AccentType 1` |
| 一括登録 | `... -Action BulkRegister` |
| 一括更新 | `... -Action BulkRegister -Force` |
| 単語削除 | `... -Action Delete -Surface "Vercel"` |
| 単語検索 | `... -Action Search -Surface "Git"` |
| バックアップ | `... -Action Backup` |
| リストア | `... -Action Restore -BackupFile "path\to\backup.json"` |
| 発音テスト | `... -Action Test -Surface "Supabase"` |

**注意**: `...` は `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1"` の省略

## accent_type ガイド

日本語のアクセント核（ピッチが下がる位置）を指定する整数値。

| 値 | 型 | 説明 | 例 |
|----|-----|------|-----|
| 0 | 平板型 | ピッチが下がらない | 自然で無難 |
| 1 | 頭高型 | 1拍目で下降 | 2-3モーラ外来語に多い |
| 3 | 中高型 | 3拍目にアクセント核 | 4モーラ以上の外来語に多い |
| N | N拍目 | N拍目にアクセント核 | モーラ数に応じて決定 |

**実用ルール**:
- 迷ったら `accent_type=0`（平板型）が最も無難
- pronunciation のモーラ数を超えた値を指定するとAPIエラー
- 登録後は `-Action Test` で実際の発音を確認

## ワークフロー

### 1. クイック登録（1語）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1" -Action Register -Surface "NewTerm" -Pronunciation "ニュータームノヨミ" -AccentType 3 -WordType PROPER_NOUN -Priority 5
```

### 2. 一括登録（初回セットアップ）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1" -Action BulkRegister
```

- スクリプト内蔵のIT用語スターター辞書（~65語）を一括登録
- 既存エントリは自動スキップ（冪等）
- `-Force` で既存エントリも上書き更新

### 3. バックアップ

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\voicevox-dict\voicevox-dict-helper.ps1" -Action Backup
```

保存先: `~/.claude/skills/voicevox-dict/backups/voicevox_dict_YYYYMMDD_HHmmss.json`

## IT用語スターター辞書

### プログラミング言語・フレームワーク

| surface | pronunciation | accent_type |
|---------|--------------|-------------|
| TypeScript | タイプスクリプト | 5 |
| JavaScript | ジャバスクリプト | 5 |
| Python | パイソン | 1 |
| React | リアクト | 3 |
| Next.js | ネクストジェーエス | 5 |
| Node.js | ノードジェーエス | 5 |
| Vue | ビュー | 1 |
| Svelte | スベルト | 1 |
| Tailwind | テイルウインド | 3 |
| Vite | ヴィート | 1 |
| Prisma | プリズマ | 1 |

### プラットフォーム・サービス

| surface | pronunciation | accent_type |
|---------|--------------|-------------|
| GitHub | ギットハブ | 3 |
| Vercel | バーセル | 1 |
| Supabase | スーパベース | 4 |
| Docker | ドッカー | 1 |
| Kubernetes | クーバネティス | 5 |
| Redis | レディス | 1 |
| PostgreSQL | ポストグレスキューエル | 7 |
| Stripe | ストライプ | 3 |
| OAuth | オーオース | 3 |
| GraphQL | グラフキューエル | 5 |
| Turborepo | ターボレポ | 3 |

### アクロニム・略語

| surface | pronunciation | accent_type |
|---------|--------------|-------------|
| API | エーピーアイ | 5 |
| CLI | シーエルアイ | 5 |
| CI | シーアイ | 3 |
| PR | ピーアール | 3 |
| SSE | エスエスイー | 5 |
| JWT | ジェーダブリューティー | 7 |
| npm | エヌピーエム | 5 |
| LLM | エルエルエム | 5 |

### AI・プロジェクト固有

| surface | pronunciation | accent_type |
|---------|--------------|-------------|
| Claude | クロード | 1 |
| Anthropic | アンスロピック | 5 |
| VOICEVOX | ボイスボックス | 5 |
| JARVIS | ジャービス | 1 |
| Usacon | ウサコン | 1 |
| Robbits | ロビッツ | 1 |
| gBizINFO | ジービズインフォ | 5 |

## プロアクティブ登録ガイドライン

Claude Codeが自律的に辞書登録を行う判断基準:

1. **英語固有名詞**: サービス名、ライブラリ名（例: Turborepo, shadcn）
2. **3文字以上のアクロニム**: SSE, JWT, ORM 等
3. **ユーザーから「発音がおかしい」と指摘された時**: 即座にこのスキルで辞書登録を実行
4. **新プロジェクト設定時**: プロジェクト固有の用語を一括登録

## トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| VOICEVOX未起動エラー | VOICEVOXを起動してからリトライ |
| accent_type エラー | pronunciation のモーラ数以下の値にする |
| 登録後も発音が変わらない | 次の audio_query から反映される（再起動不要） |
| 一括登録で一部失敗 | `-Action List` で既存確認、`-Force` で上書き |
| 文字化け | スクリプトがBOM付きUTF-8か確認 |
| Restoreでエラー | `-Force` フラグで既存辞書との競合を上書き |

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-03-26 | 初版作成（スターター辞書65語、8 Action対応） |
