---
name: 多段レビューと実装安全性検証の教訓
description: 設計レビューと実装レビューは異なる視点。両方やることでBug-freeに到達できる。Issue #1515→#1534の多段レビュー（557,894トークン）で得た教訓。
type: feedback
---

## 多段レビューは設計レビューと実装レビューの2段構えで行う

リリース済みプロジェクトの実装計画をレビューする際、「設計レビュー」と「実装安全性レビュー」は**異なる視点**であり、片方だけでは不十分。

**Why:** Issue #1515（Anthropic Prompt Caching導入）で、6エージェント並列の設計レビュー（412,818トークン）ではSDK互換性・公式ドキュメント差異・設計漏れ（kokoro/knowledge欠落）を検出できたが、Codex実装安全性レビュー（145,076トークン）で初めて「実際にコードを変えたとき何が壊れるか」（fileStreamHandlerの文字列前提結合、空配列truthy問題）が浮上した。

**How to apply:**
- 設計レビュー: コード構造・仕様整合性・リスク定量化 → 6エージェント並列が有効
- 実装レビュー: 「この変更を入れたら他のどこが壊れるか」→ Codex（全呼び出し元を走査）が有効
- 2段階とも実施して初めてA+判定に到達できる

## 計画は必ずコードベースの実態と照合する

**Why:** Issue #1515の計画はsystem promptを3ブロック分離と記載していたが、実際のitcPromptBuilder.jsは5要素構成だった。計画だけ読んでOKを出すと漏れが発生する。

**How to apply:**
- 計画に記載されたファイルを必ず実際に読む
- 関数の全呼び出し箇所をgrep（今回は54箇所）
- 計画の前提（「既存のoptions.messagesを使う」等）がコードの実態と一致するか確認

## レビュー対象は直接変更するファイルだけでなく、影響を受ける全ファイル

**Why:** Phase 1の計画は3ファイル（claudeService, assistant, itcPromptBuilder）の変更だったが、Codexレビューで2つの追加ファイル（fileStreamHandler, assistantActionOrchestrator）がsystemPromptを文字列前提で扱っていることが判明。最終的に6ファイルの変更が必要だった。

**How to apply:**
- 変更する引数/戻り値の型が変わる場合、その値を使う全ファイルを網羅的に確認
- 特にJavaScript（型チェックなし）のプロジェクトでは、grepで全使用箇所を走査必須

## 「安全だと思うエッジケース」こそ危険

**Why:** `systemBlocks || systemPrompt` は一見正しそうだが、空配列`[]`はJavaScriptでtruthyなので文字列にフォールバックしない。この種のバグはコードを書いた本人が見落としやすい。

**How to apply:**
- JavaScriptの || 短絡評価で配列を扱う場合、空配列のtruthyを常に意識する
- ヘルパー関数（resolveSystemInput等）でガードし、呼び出し側で直接 || を使わない
