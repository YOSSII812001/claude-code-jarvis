# issue-planner TODO

## 計画

- [x] `SKILL.md` に Grok補助分析の目的、役割分担、起動条件、オプションを追加する
- [x] `references/worker-workflow.md` に `Codex Scout -> Grok Context Synthesis -> Codex Main Analysis` を追加する
- [x] `references/multi-perspective-review.md` に Grok成果物の信頼境界を追加する
- [x] `references/plan-template.md` に `grok_*` メタデータを追加する
- [x] `references/error-handling-antipatterns.md` に Grok の失敗モードとアンチパターンを追加する
- [x] `references/leader-workflow.md` に Grok利用サマリを追加する
- [x] `tasks/lessons.md` を作成する

## レビュー観点

- [x] Grok は補助分析に限定し、最終的なコード根拠は Codex とローカル検証に固定したか
- [x] Grok の標準タイムアウトを `600000ms` と明記したか
- [x] `verification_required=true` の知見を未検証のまま計画本文へ入れないルールを入れたか
- [x] 投稿順序 `コメント -> 成功確認 -> planned` を維持したか
- [x] 既存の `issue-scanner-agent.md` を不要に変更していないか

## 結果

- [x] 対象ドキュメント一式を更新した
- [x] `tasks` ディレクトリを追加した
- [x] 差分確認を実施した
