---
name: ワーカーPhase B未開始問題
description: autopilot-batchのワーカーがmerge許可受信後にPhase Bを開始せず複数回idleになる問題と対策
type: feedback
---

autopilot-batchワーカーにmerge許可をSendMessageで送信した後、ワーカーがPhase Bを開始せず複数回idle通知を繰り返す。

**Why:** ワーカーのコンテキストがPhase A完了報告で一区切りつき、merge許可メッセージを受信しても「次に何をすべきか」の判断に失敗している。Phase A/B分離ルール（「merge許可を待機。待機中は何もしない」）が強すぎて、許可受信後の自動継続が機能しない可能性がある。

**How to apply:**
1. merge許可メッセージに具体的な手順（rebase→merge→vercel-watch→E2E→報告）を明示的に含める
2. 1回目のidle後、60秒以内に応答がなければ即座に手順付き再送する（複数回idle待ちしない）
3. 2回目の再送でも応答がない場合、ワーカーのコンテキスト飽和を疑い、リーダー自身がPhase Bを直接実行するか新ワーカーを起動する
4. 将来的にはワーカープロンプトの「待機中は何もしない」の記述を「merge許可メッセージ受信後は即座にPhase B手順を実行する」に明確化する
