<!-- 抽出元: SKILL.md「エラーハンドリング」セクション（旧 行869-898）
     + 「トラブルシューティング」セクション（旧 行968-981）
     + 「Codex統合ポイント」セクション（旧 行918-926）
     + 「検証チェックリスト」セクション（旧 行984-995）
     + 「関連スキル」セクション（旧 行952-965）
     + 「改訂履歴」セクション（旧 行998-1027） -->

# エラーハンドリング、トラブルシューティング、Codex統合

## エラーハンドリング

| 失敗フェーズ | 対応 | バッチ継続？ |
|------------|------|------------|
| Lint/ビルド失敗 | 自動修正->リトライ（3回） | 3回失敗->スキップ->継続 |
| E2E失敗(REQUIREMENT) | 修正->staging再マージ->再テスト（3回） | 3回失敗->スキップ(revert) |
| E2E失敗(REGRESSION) | revert->新規Issue起票->スキップ | 継続 |
| E2E失敗(PRE-EXISTING) | 新規Issue起票->PASS扱い | 継続 |
| Codexタイムアウト | 段階的フォールバック | 継続 |
| GitHub APIレートリミット | 60秒待機->リトライ | 継続 |
| ワーカークラッシュ | 冪等リカバリ: PR/ブランチ存在確認->未完了ステップのみ再実行 | 継続（1回） |
| staging不安定化 | revert->staging安定化->残りIssue継続 | 条件付き継続 |

**失敗Issueの処理:**
```bash
gh issue edit {number} --repo owner/repo --remove-label "implementing" --add-label "planned,implementation-failed"
gh issue comment {number} --body "## 自動実装失敗レポート
- バッチID: {batch_id}
- 失敗フェーズ: {phase}
- 失敗種別: {failure_type}
- 試行回数: {retry_count}
- エラー詳細: {error_summary}"
```

**ワーカークラッシュの冪等リカバリ:**
新ワーカー起動時に以下を検査し、既完了ステップをスキップ:
1. ブランチ存在 -> コミット済みなら実装スキップ
2. PR存在 -> 作成済みならPR作成スキップ
3. PR merged -> squashマージ済みならフェーズBのStep 13以降から再開

---

## Codex統合ポイント

| タイミング | Codex呼び出し | 目的 |
|----------|-------------|------|
| バッチ開始時 | Pre-flight Analysis（1回） | 実行順序 + ファイル競合検出 |
| 各Issue実装前 | Plan Approval（変更ファイル一覧のみ注入） | バッチコンテキスト付きプラン承認 |
| 各Issue実装中 | codex-autopilot（随時） | 設計判断の自動委任 |
| 失敗時 | Error Recovery（失敗毎1回） | retry/skip/pause/abort + 不具合種別判定 |

---

## トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| ワーカーがmerge許可を受信しない | SendMessageのrecipientミス | recipient は常に "leader" |
| staging mergeが競合する | 前Issueの変更と重複 | rebase後にコンフリクト解消（Codex委任） |
| E2Eテストでログインできない | テストアカウント情報が古い | usacon SKILL.md のテストアカウント参照 |
| Codex Pre-flightがタイムアウト | プロンプトが大きすぎる | 6件以上は影響ファイル上位3件のみ送信 |
| 2Issue連続E2E失敗でバッチ停止 | B4ガードレール発動 | staging状態確認->手動安定化->resume |
| ラベルが不整合 | ラベル操作の順序ミス | `--remove-label` と `--add-label` を同一コマンドで |
| APIレートリミットで403 | クールダウン不足 | 60秒待機、Issue間は30秒以上空ける |
| resume時に状態が復元できない | 状態ファイルが破損/欠損 | ラベルとPR一覧から手動復元 |
| E2Eで無関係バグを発見 | 既存バグ | PRE-EXISTING分類->Issue起票->PASS扱い |
| ワーカーがPhase B完了したが報告が届かない | SendMessage未到達（Compaction/クラッシュ） | Step 7-pre のGitHub実状態照合で自動補正。`gh pr view` + `gh issue view` で確認 |
| パイプラインがA_completedで停滞 | ワーカー未応答でmerge許可が発行されない | Step 7h のワーカー未応答リカバリ手順を適用。3分岐パターンで判定 |
| **Codex分析がkillされて出力全消失** | Bash toolデフォルトtimeout(120秒) < Codex推論時間 | Bash tool timeoutを600000ms（10分）に明示指定。全codex execに `2>&1 \| tee /tmp/codex_output_{id}.txt` を付加し、kill時も部分結果を回収可能にする |
| Codex部分出力が不十分 | kill時の出力が途中で切れている | /tmp/codex_output_{id}.txt を確認。分析セクションが読み取れれば採用、不十分ならプロンプト短縮版で再実行 |

---

## 検証チェックリスト

- [ ] ドライラン: 2-3件のplanned Issueでバッチ実行
- [ ] ラベル遷移確認: planned -> implementing -> implemented
- [ ] 状態ファイル確認: 各セーフポイントで更新されていること
- [ ] E2Eゲート確認: 各Issue完了後にE2Eが実行されること
- [ ] 不具合分類確認: リグレッション/既存バグの起票フロー動作
- [ ] 回帰テスト確認: バッチ全完了後に統合回帰テスト実行
- [ ] 中断・再開テスト: バッチ途中でキャンセル -> resume で再開
- [ ] 失敗シナリオ: ビルド失敗Issue -> スキップ -> 残りIssue継続
- [ ] staging->main PR: 回帰テスト通過後に1つのPRが作成されること

---

**関連スキル**: issue-planner（上流）、issue-flow（個別実装）、codex-autopilot、agent-teams、e2e-test、vercel-watch、usacon
