# issue-planner Lessons

## 2026-04-11 ローカルリポジトリ参照ミスによる誤判定

- **事象**: Issue #1798 で「追加クレジット機能が存在しない」と誤判定し、的外れな計画を投稿した
- **根本原因**: (1) ローカルリポジトリのパスマッピングが古いクローン（`Documents/GitHub/DX/`）を指していた (2) ワーカーが `git fetch` せずにローカルの古い状態で調査した
- **教訓**:
  1. ワーカー起動時は必ず `git fetch --all` を実行し、最新の origin/main と origin/staging を取得してから調査する
  2. Issue が「本番にある機能」に言及している場合、origin/main を基準に調査する（staging では未マージの場合がある）
  3. パスマッピングは `C:/Users/zooyo/OneDrive/ドキュメント/digital-management-consulting-app/` が正
- **対策**: SKILL.md と leader-workflow.md のパスマッピングを修正済み。ワーカープロンプトに `git fetch` ステップを追加すべき

## 2026-04-12 Grok補助分析統合

- Grok は長文統合と広い知見の整理に向くが、ファイルパス・行番号・型の実在性は保証しない
- Xポストやコミュニティ知見は便利だが、`verification_required=true` のまま本文へ入れると計画品質が落ちる
- Grok の timeout は 10 分を標準にしたほうが安全。短くすると長文Issueや外部知見の整理が途中で切れやすい
- 補助分析だけ失敗しても、`issue-planner` 全体は Codex 単独へ降格して継続できる設計にする
- レビュー段では、Grok の知見そのものより「未検証知見が混入していないか」を見るほうが効果が高い
