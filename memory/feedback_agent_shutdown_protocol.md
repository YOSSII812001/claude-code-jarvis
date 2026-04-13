---
name: Agent Teamsシャットダウンプロトコルの制約
description: shutdown_requestはLLMソフトプロトコル。compaction後に応答不能になる。完了報告SendMessage義務化+3回失敗→TeamDelete
type: feedback
originSessionId: 0ac0548c-792e-4e0c-8ff6-85c378ef35e2
---
## ルール
Agent Teamsのサブエージェントがshutdown_requestに応答しない場合がある。完了報告SendMessageを義務化し、3回失敗したらTeamDeleteで強制終了する。

**Why:** shutdown_requestはLLMの指示遵守に依存するソフトプロトコル。サブエージェントがタスク完了後にSendMessageを送らずidle状態が長期化すると、コンテキスト圧縮(compaction)でshutdownプロトコル指示が喪失し、応答不能になる。worker-1758（成功）はSendMessage完了報告直後にshutdown受信でプロトコル活性状態だったが、changelog-updater（失敗）は未報告でidle→compaction→指示喪失。

**How to apply:**
1. **全サブエージェントのプロンプトに完了報告SendMessage義務を追加**: タスク完了→SendMessage完了報告→idle の順序を徹底
2. **shutdown_request送信時にプロトコル手順をメッセージ本文に埋め込む**: `{"type":"shutdown_request"}` だけでなく、テキストで「SendMessageで shutdown_response を返してください」と明示
3. **フォールバック**: shutdown_request 3回送信→応答なし→TeamDelete強制終了（唯一の確実な手段）
4. **shutdown送信タイミング**: 完了報告SendMessage受信直後が最適（コンテキスト鮮度が高い）
