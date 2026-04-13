# Claude Code メモリ

## ユーザー設定
- **Learning Output Style の TODO(human) 抑制**: 以下のスキル実行中は `TODO(human)` / 「Learn by Doing」リクエストを出さないこと（完全自律実行が前提のため）:
  - `issue-autopilot-batch` / `autopilot-batch`
  - `autopilot-issue`
  - `issue-flow`（autopilotモード時）
  - `codex-autopilot`
- **通知方法**: `settings.json` の `Stop` フックでJARVIS音声読み上げ（VOICEVOX経由）
  - スクリプト: `C:\Users\zooyo\.claude\speak_jarvis.ps1`（Hook + Worker 2モード構成）
  - VOICEVOXが未起動時はビープ音にフォールバック
  - 話者: 剣崎雌雄 ノーマル (ID: 21)、抑揚0.8/ピッチ0.06/速度1.0（加瀬康之JARVIS風、聞き取りやすさ重視）
  - FFmpegエフェクト: highpass=220Hz, lowpass=4000Hz, 3タップリバーブ(15/25/40ms), aphaser控えめ(decay=0.10), chorus最小(0.02), eq=1200Hz+2/3200Hz+1.5/5500Hz+0
  - 設計思想: 落ち着き・知的・低め安定・感情薄め（でも無機質すぎない）・語尾丁寧に落とす・ノイズ抑制重視・エコー広がり感
  - 母音短縮: 通常モーラ93%(閾値0.20超のみ)、最終モーラ80%、ポーズ88%（カタコト感防止）
  - VOICEVOX自動起動: Startupフォルダにショートカット配置済み（最小化起動）
  - Claudeが手動で鳴らす必要なし（フックが自動処理）

## 環境情報
- Windows環境
- PowerShell使用（`&&` ではなく `;` でコマンド連結）
- 日本語で応答

## プロジェクトパス（重要）
- **usacon (digital-management-consulting-app)**: `C:/Users/zooyo/Documents/GitHub/DX/digital-management-consulting-app/`
- **ryokan-forecast（温泉旅館需要予測）**: `C:/Users/zooyo/Documents/GitHub/DX/ryokan-forecast/`
- **誤ったパス（使用禁止）**: `~/Robbits/digital-management-consulting-app` — このパスは存在しない
- worktree: `~/.claude-worktrees/digital-management-consulting-app/` 配下に作成される

## Usacon自律駆動化プロジェクト
- [自律駆動化](project_usacon_autonomous.md) — Heartbeat基盤。Fortress Review完了→9 Issue(#1775-#1783)起票済み。issue-planner待ち

## ryokan-forecast プロジェクト
- [ryokan-forecast](project_ryokan_forecast.md) — Next.js 16 + shadcn/ui v4 + Supabase + TimesFMローカルワーカー。Lovable風デザイン。MVP完了(2026-04-07)

## サブエージェント設定
- **モデル指定しない** — haiku等への変更はNG、親エージェントのモデルを継承させる
- **差分埋め込み方式** — サブエージェントにファイル探索させず、git diffをプロンプトに直接含める

## 設計品質の教訓（Issue #723）
- 設計計画を書く前に **必ず既存コードを読む**（推測で設計しない）
- **全データ更新経路**（SSE・ポーリング・REST同期・確認必須）を網羅する
- 指摘を受けたら **構造的問題を特定** してから修正（表面修正を避ける）
- 詳細: `~/.claude/skills/design-review-checklist/SKILL.md`

## Supabase TIMESTAMP vs TIMESTAMPTZ の教訓
- `digital_strategy_documents` テーブルが `TIMESTAMP`（TZなし）で作成されていた
- 他テーブルは `TIMESTAMP WITH TIME ZONE` を使用 → 型の不整合
- Supabase REST APIが返すTZなし文字列をブラウザが**ローカル時刻として誤解釈**
- JST環境では9時間のズレ → リカバリポーリングが失敗する原因に
- **新テーブル作成時は必ず `TIMESTAMPTZ` を使用すること**
- 修正: PR #977 (toTimestamp UTC正規化) + マイグレーション (TIMESTAMP→TIMESTAMPTZ)

## Vercel本番デプロイの2段階構造
- mainマージ後、YOSSII812001アカウントが先にデプロイ → 次にrobbits0802（本アカウント）が再デプロイ
- **usacon-ai.com に反映されるのはrobbits0802のデプロイのみ**
- vercel-watch で1回目のReady検知で終了しないよう注意
- 本番E2Eテスト前に `vercel ls` でrobbits0802のProductionデプロイがReadyか確認

## PowerShell Where-Object `.Count` の罠
- `Where-Object` が単一結果を返す場合、配列ではなくスカラーが返る
- `.Count` がスカラーで正しく動かない → 必ず `@()` で配列に強制変換: `@($x | Where-Object {...}).Count`

## Issue自動化パイプライン（スキル連携）
- `issue-planner` → `issue-autopilot-batch` → staging安定 → main PR
- `/autopilot-batch` コマンドで起動（all-planned / #N #M / milestone:XX / resume）
- ラベル状態機械: `planned` → `implementing` → `implemented`
- パイプライン方式: E2E待ち中に次Issueの実装を並行開始（フェーズA/B分離）
- **ワーカー未応答時のリカバリ**: GitHub状態（PR merged + Issue closed）を照合し、完了済みなら状態ファイルを手動補正してパイプライン再開
- 詳細: `~/.claude/skills/issue-autopilot-batch/SKILL.md`

## バッチ実装スループット実績
- 5 Issue/hour が現実的な目安（fix 4件 + feat 1件で約66分）
- 個別Issue平均: 約13分/issue（PR作成〜stagingマージ）
- バッチ完了後は `git checkout staging` で復帰すること（featureブランチに留まる問題あり）
- Release PR（staging→main）のマージ承認依頼を忘れない

## UsaconCLI バッチ実装進捗（2026-03-13更新）
- **全体**: 12件のplanned Issue (#1267-#1278) を3バッチに分割 → **全バッチ完了**
- **バッチ1** (#1267-#1271): **main完了**
- **バッチ2** (#1272-#1276): **main完了**
- **バッチ3** (#1277-#1278): **main完了**（Release PR #1374→main）
- **追加バッチ** (#1377-#1379): **main完了**（Release PR #1384→main, v1.32.0）
  - #1377 CLI Phase 2: chat history, settings, batch dry-run（PR #1380）
  - #1378 CLI Phase 3: company new, corporate strategy（PR #1381）
  - #1379 CLI Phase 4: insights, threads, report PPTX（PR #1383）
  - Codex検証: 3件とも全受け入れ基準PASS
- **Issue #1329**: CLI Phase 0+1（subsidy show, export csv/xlsx）→ **main完了**
- **Issue #1331**: CLIチャット演出追加 → **main完了**
- **技術的負債**: Issue #1294（httpClient.ts CodeRabbit指摘）、Issue #1334（kokoroService org_id / claudeService pause_turn空テキスト）
- **パッケージ構造**: app-core → api-client → usacon-cli（依存順）
- **ビルド注意**: worktreeワーカー後はapp-coreを先に再ビルドすること（DTS解決エラー防止）
- **テスト合計**: 374件（usacon-cli、1 pre-existing失敗: gap-analysis Commander v13互換）
- **最新changelog**: v1.32.0（CLI Phase 2-4 + テスター課金モード）

## Stripe Portal Configuration & Proration の教訓
- [project_stripe_portal_proration.md](project_stripe_portal_proration.md) — Portal APIのproration_behaviorデフォルト罠、next_reset_at計算注意点、セットアップスクリプト実行手順

## スキル改善ワークフロー
- [feedback_skill_improvement_review.md](feedback_skill_improvement_review.md) — 編集後にCodexレビュー必須。パス表記・テーブル構文・クロスリファレンス整合性の見落とし防止

## CodeRabbit レートリミット
- [project_coderabbit_rate_limit.md](project_coderabbit_rate_limit.md) — バッチ実装時のCodeRabbitレートリミット問題と回避策検討

## VOICEVOX辞書管理スキル
- [VOICEVOX辞書スキル](project_voicevox_dict_skill.md) — GET /user_dict エンコーディング制約、BOM変換手順、スターター辞書66語

## テスト用URL
- **Robbits自社URL**: `https://robbits.co.jp/` — E2Eテストの企業URL入力に使用

## 多段レビューの教訓（Issue #1515→#1534）
- [feedback_multistage_review.md](feedback_multistage_review.md) — 設計レビューと実装レビューは異なる視点。両方やることでBug-freeに到達。空配列truthy・文字列前提結合などの実装バグは設計レビューだけでは検出不可
- [feedback_review_agent_strategy.md](feedback_review_agent_strategy.md) — 6+1エージェント並列レビュー構成。557,894トークンで12件検出の実績パターン

## npm publish 2FA バイパス
- [feedback_npm_publish_2fa.md](feedback_npm_publish_2fa.md) — Windows Hello/パスキー環境での npm publish。Granular Access Token + bypass 2FA で OTP 不要化

## HTTPエラーハンドリングの2層構造（Issue #1459再発）
- [feedback_error_handling_two_layers.md](feedback_error_handling_two_layers.md) — トランスポート層（接続断）とアプリケーション層（5xx応答）の2パス。リカバリは両方カバー必須

## PowerShellスクリプトの罠（BOM / param / winmm / char code / GUID一時ファイル）
- [feedback_powershell_encoding.md](feedback_powershell_encoding.md) — BOM必須、param()先頭、winmm.dll、日本語char code化、固定一時ファイル→GUID化、voiceEnabled誤診断防止

## Codexプラグイン共存設計
- [Codexプラグインv1.0.1テスト結果](project_codex_plugin_test.md) — Windows ENOENTバグ修正、カスタムスキル共存方針、9依存スキル影響分析
- [プラグイン×カスタムスキル共存の教訓](feedback_plugin_skill_coexistence.md) — 置き換えではなくレイヤー分離。依存チェーン保護の原則

## LLM脆弱性テストスキル
- [project_llm_vulnerability_test.md](project_llm_vulnerability_test.md) — OWASP LLM Top 10 + LLMSVS + NIST AI RMF準拠の動的セキュリティテストスキル。初回テスト: 14 PASS / 1 FAIL(LVT-11 #1580) / 3 SKIP

## E2Eカバレッジ評価の教訓（Issue #1534）
- [feedback_e2e_coverage_mapping.md](feedback_e2e_coverage_mapping.md) — テスト通過数ではなく変更箇所×テスト対応マッピングで評価。feat種別ではCodexにカバレッジ十分性評価を必ず依頼

## PowerShell Hook stdin読み取りの教訓
- [feedback_powershell_stdin_hook.md](feedback_powershell_stdin_hook.md) — $inputとConsole.Inのストリーム共有問題、BOM必須、共有ファイル方式でのHook間stdin受け渡し

## ずんだもんTTS完成状態
- **SBV2サーバー**: `C:\Users\zooyo\Style-Bert-VITS2` (venv, port 5000, jvnv-F1-jp)
- **Hook順序**: JARVIS先(stdin保存)→ずんだもん後(共有ファイル読み取り)
- **辞書**: `~/.claude/sbv2_dict.tsv` (477件、VOICEVOX辞書から変換+追加分)
- **FFmpegエフェクト**: 軽量(volume+apad)、JARVIS風の重いフィルターは不使用
- **トグル**: `%TEMP%\zundamon_tts_active.txt` の有無で切替

## ワーカーPhase B未開始問題（autopilot-batch）
- [feedback_worker_phase_b_idle.md](feedback_worker_phase_b_idle.md) — merge許可送信後にワーカーがidle連打。手順明示再送→60秒応答なしならリーダー直接実行or新ワーカー

## Playwright MCPファイルDL/UL制約
- [feedback_playwright_file_attachment.md](feedback_playwright_file_attachment.md) — Playwright MCPではファイル添付・DL不可。fetch()代替・playwright-cli run-codeで回避（#1641, #1669教訓）

## fortress-review スキル（動的多角レビュー）
- Grok×Codex×Claude三者分析から「動的N方式」を導出
- Tier判定（A≥12/B≥6/C<6）→ エージェント数を動的に配置（A:5体/B:3体/C:2体）
- `/fortress-review #123` で起動、`--tier A` `--dry-run` `--no-codex` `--auto-gate` 等のオプション
- **autopilot-batch統合完了(2026-04-07)**: issue-planner-meta → batch-plan.json → pipeline-state.json → ワーカーStep 0.5
- Tier A: ワーカーが `--auto-gate` で自動実行（CRITICAL=0→Go, ≥1→No-Go）、リーダーStep 7b-post2で確認
- Tier B: 現行5レーンレビュー維持、Tier C: 2レーン（Codex+仕様準拠）に簡略化（13分→9分）
- パイプライン内位置: issue-planner → **fortress-review(Tier A)** → issue-autopilot-batch → sub-review

## スキル棚卸し実施日
- **最終実施**: 2026-04-09（教訓C/D/G未反映3件→issue-autopilot-batch SKILL.md+leader-pipeline-loop.md+worker-flow.md反映。核心ルール17追加、Step 7h/7-pre新設）

## E2E自信ゲートHook
- [E2E自信ゲートHook](project_confidence_gate_hook.md) — Stop Hookで重み付きスコアリング(≥5)によりE2E報告を検出、C1-C6ゲートをstdout注入で強制。Anti-loop二重安全策

## PayPay決済導入方針
- [PayPay決済方針](project_paypay_payment.md) — Stripe PayPayで実装（PAY.JP見送り）。サブスクは非対応、ワンタイムのみ。stripe-paypayサブスキル参照

## useCityAnimation.ts 進捗計算の注意
- フォールバック進捗は `elapsed % stepDuration`（モジュロ）を使っていた → ループ発生
- 修正: `elapsed - (currentStep * stepDuration)` + `Math.min` でキャップ（PR #978）
- `DigitalStrategy.tsx` は `completedSteps` を渡さず、`activeStep` も未更新のまま
- バックエンドはSSEなし（単一POST）→ フロントに進捗フィードバックなし

## Agent Teamsシャットダウンプロトコルの制約
- [シャットダウンプロトコル教訓](feedback_agent_shutdown_protocol.md) — shutdown_requestはLLMソフトプロトコル。compaction後に応答不能。完了報告SendMessage義務化+3回失敗→TeamDelete

## パイプライン完了・E2Eテーマ確認
- [パイプライン完了の定義](feedback_pipeline_completion.md) — mainマージ後も本番E2E確認まで自動継続。途中停止禁止
- [E2E両テーマ確認](feedback_e2e_both_themes.md) — UI/テーマ変更時はNordLight+Cyberpunk両方でE2E必須

## 日本語UIデザイン基準（Usacon必須）
- [デザイン基準必須適用](feedback_design_jp_mandatory.md) — 全フロントエンドUI変更時にawesome-design-md-jpスキル参照必須。SmartHR/freee/Sansan/サイボウズ/LINE 5社基準（#1764教訓）
