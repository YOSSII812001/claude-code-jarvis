---
name: security-settings
description: |
  Claude Codeのセキュリティ初期設定ガイド。新プロジェクト・新環境セットアップ時のdenyルール、機密ファイル保護、パーミッション棚卸し方針。
  トリガー: "セキュリティ設定", "security settings", "deny設定", "パーミッション設定",
  "初期設定", "安全設定", "権限設定", "セキュリティ見直し"
  使用場面: (1) 新プロジェクトの初期セキュリティ設定、(2) パーミッション棚卸し、
  (3) settings.local.json の見直し、(4) チームメンバーへのセキュリティ設定共有
---

# Claude Code セキュリティ設定ガイド

## 方針

- **Windows環境**: サンドボックス（sandbox）はWindows未対応のためスキップ。パーミッション層で防御する
- **運用スタイル**: 普段は `bypassPermissions` で全開運用。denyルールが常時ガードレールとして機能
- **deny最優先の原則**: パーミッション評価は deny → ask → allow の順。denyは bypass mode でも貫通する

## 必須denyルール

```json
"deny": [
  "Bash(rm -rf *)",
  "Bash(git push --force *)",
  "Bash(git push -f *)",
  "Bash(git push origin --delete *)",
  "Bash(git reset --hard *)",
  "Bash(git branch -D *)",
  "Bash(git clean -f *)",
  "Bash(git checkout -- .)",
  "Bash(git restore .)",
  "Bash(curl *)",
  "Bash(wget *)",
  "Bash(chmod 777 *)",
  "Bash(Remove-Item -Recurse -Force *)",
  "Bash(rd /s /q *)",
  "Read(./.env)",
  "Read(./.env.*)",
  "Read(**/*.pem)",
  "Read(**/*.key)",
  "Read(**/*credentials*)"
]
```

## allowルール（現在の設定）

```json
"allow": [
  "Bash(Select-Object Name, Length, LastWriteTime)",
  "Bash(npm start)",
  "mcp__supabase__list_tables",
  "WebFetch(domain:claudia.so)",
  "WebFetch(domain:github.com)",
  "Bash(git checkout:*)",
  "Bash(git pull:*)",
  "Bash(npm run type-check:*)",
  "Bash(git add:*)",
  "Bash(git commit:*)",
  "Bash(git push:*)",
  "Bash(gh pr create:*)",
  "mcp__plugin_playwright_playwright__browser_navigate",
  "Bash(taskkill:*)",
  "WebFetch(domain:x.com)",
  "WebFetch(domain:anthropic.com)",
  "WebFetch(domain:docs.anthropic.com)",
  "Bash(ls \"C:/Users/zooyo/.claude/settings\"*)",
  "Bash(claude config:*)"
]
```

### allowルールの方針

- `Bash(rm:*)` のような広範な削除許可は **入れない**（都度確認）
- `Bash(git push:*)` は allow に入れてよい（`--force` は deny で止まる）
- `Bash(taskkill:*)` は許可（dev server再起動等で頻繁に使うため）
- WebFetch は必要なドメインのみ明示的に allow（ホワイトリスト方式）
- プロジェクト固有のドメインは都度追加する

## 不要と判断した設定

| 設定 | 理由 |
|------|------|
| sandbox.enabled | Windows未対応。将来対応時に再検討 |
| sandbox.network（ホワイトリスト） | sandbox依存。curl/wget deny + WebFetch allowで代替 |
| PreToolUseフック（安全チェック） | denyルールで十分カバー |
| skipDangerousModePermissionPrompt: false | denyが bypass でも効くため現状維持 |

## 棚卸しチェックリスト（月1回推奨）

1. `/permissions` で現在の権限一覧を確認
2. allow に不要な広範ルール（`*` 付き）が溜まっていないか
3. deny ルールが意図通り設定されているか
4. WebFetch の許可ドメインに不要なものがないか
5. 新たに追加すべき deny パターンがないか

## 設定ファイルの配置先

| 設定種別 | ファイル | 理由 |
|---------|---------|------|
| deny / allow ルール | `~/.claude/settings.local.json` | 個人設定、gitignore対象 |
| hooks, env, plugins | `~/.claude/settings.json` | グローバル共通設定 |
| プロジェクト固有 | `.claude/settings.json` | チーム共有 |

## 参考

- 元記事: @SuguruKun_ai のClaude Codeセキュリティ7設定（2026-03）
- Anthropic公式: "Claude Code only has the permissions you grant it. You're responsible for reviewing proposed code and commands for safety before approval."
