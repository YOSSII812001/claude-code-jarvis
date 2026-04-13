# Autopilot Batch実装: $ARGUMENTS

## ゴール
planned ラベル付きIssueを逐次自律実装する。

## 実行手順
1. SKILL.md を読む: ~/.claude/skills/issue-autopilot-batch/SKILL.md
2. SKILL.md のリーダーワークフロー（11ステップ）に従って実行
3. 入力: $ARGUMENTS（Issue番号リスト / all-planned / milestone:XX / resume）

## 入力形式の例
- `/autopilot-batch #10 #11 #12` — 指定Issueのみ
- `/autopilot-batch all-planned` — planned全件
- `/autopilot-batch milestone:v2.0` — マイルストーン内のplanned
- `/autopilot-batch resume` — 中断再開（implementing状態のIssueから）
