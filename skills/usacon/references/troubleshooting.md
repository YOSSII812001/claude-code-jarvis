# トラブルシューティング

## mainブランチへの誤コミット防止（重要）

**問題:** `git checkout -b <branch>` 後のBash呼び出しで、シェル状態がリセットされローカルmainに戻るケースがある。結果、Edit→commitがmainに直接入る。

**原因:** Claude Codeのbashツールはコマンド間でシェル状態が保持されない。`cd` + `git checkout -b` を実行しても、次のBash呼び出しではcwdがリセットされる。

**再発防止策（必須手順）:**

1. **ブランチ作成とコミットは必ず同一コマンドチェーンで実行するか、コミット前にブランチを再確認する**
```bash
cd "<project_dir>" && git branch --show-current
# 期待するブランチ名が表示されることを確認してからコミット
```

2. **コミット直前に必ずブランチ名を確認する**
```bash
cd "<project_dir>" && git branch --show-current && git add <files> && git commit -m "message"
```

3. **万一mainにコミットしてしまった場合のリカバリ**
```bash
# origin/mainはまだ安全であることを確認
git log --oneline origin/main -3
# ローカルmainをリセット
git reset --hard origin/main
# 誤ってプッシュしていた場合はリモートブランチを削除
git push origin --delete <branch-name>
# ローカルブランチも削除
git branch -D <branch-name>
# staging から正しくブランチを再作成
git checkout staging && git pull origin staging
git checkout -b <branch-name>
# 修正を再適用してコミット
```

4. **コミット結果のブランチ名を確認する**
```
# git commit の出力に [main xxxxx] と表示されたら即座にリカバリ
# 正しくは [fix/branch-name xxxxx] と表示されるべき
```

## Supabase CLI で Docker エラー
**問題:** `failed to inspect docker image` エラー
**解決:** REST APIを使用するか、`supabase inspect db` 系コマンドを使用

## Vercel CLI で確認要求
**問題:** `Command requires confirmation`
**解決:** `--yes` オプションを追加

## APIキー取得
```bash
npx supabase projects api-keys --project-ref bpcpgettbblglikcoqux
```

## Stripe Webhook エラー

**問題1:** `Webhook Error: The "key" argument must be... Received undefined`
**原因:** `STRIPE_WEBHOOK_SECRET`環境変数が設定されていない
**解決:** Vercelで環境変数を追加
```bash
# 環境変数一覧確認
npx vercel env ls preview

# 環境変数追加（printfで改行なし）
printf 'whsec_xxxxx' | npx vercel env add STRIPE_WEBHOOK_SECRET preview

# 新しいデプロイを作成（環境変数反映に必要）
npx vercel --yes

# エイリアス設定
npx vercel alias <deployment-url> preview.usacon-ai.com
```

**問題2:** `No signatures found matching the expected signature... signing secret contains whitespace`
**原因:** 環境変数に余分な空白や改行が含まれている
**解決:** 環境変数を削除して`printf`で再設定
```bash
npx vercel env rm STRIPE_WEBHOOK_SECRET preview --yes
printf 'whsec_xxxxx' | npx vercel env add STRIPE_WEBHOOK_SECRET preview
```

**重要:** Vercelの環境変数変更後は**新規デプロイが必須**。`vercel alias`だけでは反映されない。

## Playwright MCP でブラウザセッション競合エラー

**問題:** Playwright MCPでブラウザを起動しようとすると「別のブラウザセッションで開いています」エラーが発生する。

**原因:** Chromeが既に起動している状態でPlaywright MCPが新しいブラウザインスタンスを起動できない。

**解決策（自動リカバリ）:**
このエラーが発生した場合、**ユーザーに聞かずに自動でChromeを終了して再試行する**。

```bash
# 1. Chromeプロセスを強制終了
taskkill /F /IM chrome.exe 2>/dev/null; echo "Chrome closed"

# 2. 再試行（Playwright MCPが自動で新しいインスタンスを起動する）
# mcp__plugin_playwright_playwright__browser_navigate url: <対象URL>
```

**自動対応ルール:**
- このエラーが発生した場合、**`taskkill /F /IM chrome.exe`で自動終了し、即座に再試行する**
- ユーザーへの確認は不要（Chromeの強制終了は安全な操作）
- 手動でのブラウザ操作は不要（Playwright MCPが自動で新しいインスタンスを起動する）

## Vercel Preview環境のAlias設定
```bash
# デプロイ後にaliasを設定
npx vercel alias <deployment-url> preview.usacon-ai.com
```
