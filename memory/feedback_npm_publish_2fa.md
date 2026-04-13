---
name: npm publish 2FA バイパス手順
description: npm publish時の2FA (Windows Hello/パスキー) で OTP が使えない場合の解決手順。Granular Access Token + bypass 2FA で回避。
type: feedback
---

npm publish で OTP (ワンタイムパスワード) を求められるが、2FA が Windows Hello/パスキー設定の場合、CLIから OTP コードを生成できない。

**Why:** npm の `auth-and-writes` 2FA は publish 時に必ず OTP を要求するが、Windows Hello はブラウザ認証専用でCLI用 TOTP コードを生成しない。通常の Access Token でも OTP は回避できない。

**How to apply:**
1. npmjs.com → Settings → Security → 2FA レベルを「Require two-factor authentication **or** a granular access token with bypass 2fa enabled」に変更して **Save**
2. Access Tokens → Generate New Token → **Granular Access Token** を選択
3. 作成画面で **「Bypass two-factor authentication for API and publish」** チェックボックスを ON
4. Permissions: Read and write、Packages: @usacon/cli を設定
5. `npm publish --access public --//registry.npmjs.org/:_authToken=<granular-token>`

**注意:**
- 通常の Access Token（Classic Token）では 2FA バイパス不可
- 2FA レベル設定変更を **保存** しないと Granular Token でもバイパスできない
- トークンは `.npmrc` に保存せず、CI/CD の secrets に格納すること
