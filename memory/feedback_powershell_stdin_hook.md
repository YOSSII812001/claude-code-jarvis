---
name: PowerShell Hook stdin読み取りの教訓
description: Claude Code Stop Hookでのstdin読み取り方式。$inputとConsole.Inのストリーム共有問題、BOM必須、共有ファイル方式の解決策
type: feedback
---

Claude Code Stop HookでPowerShellスクリプトにstdinをパイプする際の注意点。

## 問題1: BOMなしUTF-8でパース失敗
PowerShell 5.1はBOMなしUTF-8を日本語環境でShift-JISとして解釈する。日本語コメントのマルチバイト文字で括弧カウントが狂い、構文エラーになる。
**Why:** Edit/WriteツールはデフォルトでBOMなしUTF-8で保存する。
**How to apply:** PowerShellスクリプトを編集した後は必ずBOM確認・再付与すること。

## 問題2: $inputとConsole.Inのストリーム共有
`$input`自動変数と`[Console]::In`は同じstdinストリームを共有。`$input`を先に消費すると`Console.In.ReadToEnd()`は0文字を返す。
**Why:** PowerShellの`$input`はスクリプト開始時にstdinをデフォルトエンコーディング(CP932)で読む。UTF-8設定より前に消費される。
**How to apply:** 複数Hookでstdinを共有する場合、最初のHook(JARVIS)がConsole.InでUTF-8読み取り→共有ファイルに保存、後続Hook(ずんだもん)はファイルから読む方式にする。

## 解決アーキテクチャ
1. JARVIS(先行Hook): `[Console]::InputEncoding = UTF8` → `Console.In.ReadToEnd()` → `claude_hook_stdin.json`に保存 → ずんだもんフラグあれば早期終了
2. ずんだもん(後続Hook): `[System.IO.File]::ReadAllText()`で共有ファイルから読み取り

## SBV2辞書置換
SBV2にはVOICEVOXのようなユーザー辞書APIがない。代わりにテキスト前処理で`sbv2_dict.tsv`(surface→カタカナ読み)による正規表現置換を行う。長いsurfaceから順に置換（部分一致誤置換防止）。
