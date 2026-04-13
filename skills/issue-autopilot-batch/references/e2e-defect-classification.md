<!-- 抽出元: SKILL.md「E2Eテスト中の不具合分類と対応」セクション（旧 行762-808）
     + 「E2E失敗時のパイプライン制御」セクション（旧 行812-835） -->

# E2E欠陥分類

## 不具合深刻度

| 深刻度 | 定義 | 例 | E2E判定 |
|--------|------|-----|---------|
| Blocker | アプリ使用不能、データ損失 | クラッシュ、ログイン不能 | FAIL（即停止） |
| Critical | 主要機能が動作しない | 保存不能、API 500 | FAIL |
| Major | 機能は動作するが品質不足 | 重度の表示崩れ、計算不正 | FAIL |
| Minor | 軽微なUI/UX問題 | 余白ズレ、文言誤り | PASS（Issue起票） |
| Trivial | 改善要望レベル | アニメーション欠如 | PASS（備考記録） |

## 不具合種別と対応フロー

| 種別 | 判定方法 | 対応 | 連続失敗カウント |
|------|---------|------|----------------|
| **REQUIREMENT**: 修正対象が未修正 | 当該Issueの修正箇所でFAIL | 自動修正->再テスト（3回） | 加算する |
| **REGRESSION**: 当該Issue起因の回帰 | git diffと失敗画面が関連 | revert検討 + 新規Issue起票 | 加算する |
| **PRE-EXISTING**: 無関係の既存バグ | git diffと失敗画面が無関連 | 判断フロー参照 -> PASS扱い | 加算しない |
| **FLAKY-INFRA**: 環境/デプロイ問題 | デプロイ失敗、タイムアウト | 60秒待機->リトライ | 加算しない |

## PRE-EXISTING発見時のバッチ包含判断（教訓 2026-03-13）

E2Eテスト中にPRE-EXISTINGバグを発見した場合の対応フロー:

```
PRE-EXISTING発見
  ├── 修正見積もり ≤ 30分 → ユーザーに確認 → 承認あり → 追加PRをstagingにマージ → Release PRに含める
  │                                          └── 承認なし → 別Issue起票 → PASS扱い
  └── 修正見積もり > 30分 → 別Issue起票 → PASS扱いで続行
```

**判断基準**: 修正が30分以内に完了する見込みなら、バッチに含めた方が効率的。ただし修正範囲が大きい場合は別Issue化が適切。

## 新規Issue自動起票テンプレート

```bash
# リグレッション起票
gh issue create --repo owner/repo \
  --title "[Regression] {画面名}: {症状}" \
  --label "bug,regression" \
  --body "## 発見経緯
Issue #{current} のE2Eテスト中に発見（バッチ: {batch_id}）

## 再現手順
{手順}

## 原因の推定
Issue #{current} の変更（{changed_files}）に起因する可能性"

# 既存バグ起票
gh issue create --repo owner/repo \
  --title "[Existing Bug] {画面名}: {症状}" \
  --label "bug,found-during-e2e" \
  --body "## 発見経緯
Issue #{current} のE2Eテスト中に発見。当該Issueの変更とは無関連。

## 再現手順
{手順}"
```

---

## E2E失敗時のパイプライン制御

```
Issue A: E2E失敗
  +-- Issue A ワーカー: 不具合種別を判定
  |   +-- REQUIREMENT: 自動修正 -> staging再マージ -> 再テスト（最大3回、4回目なし）
  |   +-- REGRESSION: revert -> 新規Issue起票 -> リーダーに報告
  |   +-- PRE-EXISTING: 新規Issue起票 -> PASS扱いで続行
  |   +-- FLAKY-INFRA: 60秒待機 -> リトライ
  +-- Issue B ワーカー: フェーズA実行中 -> 影響なし
  +-- Issue B の staging merge:
      +-- Issue A 最終PASS -> Issue B にmerge許可
      +-- Issue A スキップ -> staging安定化（下記revert手順） -> Issue B にmerge許可
```

**revert手順（squashマージ済みコミットの取り消し）:**
```bash
git log --oneline origin/staging -5  # revert対象のcommit hashを特定
git revert {commit_hash} --no-edit
git push origin staging
# staging安定性検証
cd "{project_dir}" ; npm run lint ; cd frontend ; npm run type-check ; npx vite build
```
