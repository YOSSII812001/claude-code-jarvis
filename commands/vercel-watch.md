# Vercel デプロイ状況リアルタイム監視

> 詳細は `~/.claude/skills/vercel-watch/SKILL.md` を参照

## 引数: $ARGUMENTS

引数に応じてスクリプトを実行:
- `/vercel-watch` → 一回チェック（`-Once`）
- `/vercel-watch Production` → `-Environment Production -Once`
- `/vercel-watch Preview` → `-Environment Preview -Once`
- `/vercel-watch monitor` → 継続監視（10秒間隔）
- `/vercel-watch monitor Production` → 本番のみ継続監視
- `/vercel-watch 5` → `-Interval 5` で継続監視

## 実行コマンド

```bash
# 一回チェック
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Once

# 継続監視（run_in_background: true, timeout: 360000 推奨）
powershell -File "C:\Users\zooyo\.claude\scripts\vercel-watch.ps1" -Environment <env> -Interval 10
```

## usaconフロー連携

PRマージ後のデプロイ待機として自動使用される。
従来の `sleep 180` / `sleep 300` 固定待機の代替。
