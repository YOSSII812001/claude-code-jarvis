# Windows環境でのClaude Code MCP制限

## 作成日: 2025-07-23

## 🔍 MCPツール設定の試行と結果

### 試行したアプローチ
1. **プロジェクトレベル設定**
   - `.mcp.json` ファイルをプロジェクトルートに配置
   - 正しいJSON形式で設定（playwright, Context7）

2. **Windows対応の修正**
   - Qiita記事の情報に基づき `cmd /c npx` 形式に変更
   - 全てのMCPサーバー設定を修正

3. **設定のリセットと再起動**
   - `claude mcp reset-project-choices` コマンド実行
   - Claude Code再起動を複数回実施

### 結果
- **MCPツール**: 認識されず
- **/mcp コマンド**: 「No MCP servers configured」と表示
- **利用可能ツール**: 標準ツールセットのみ（mcp__プレフィックスのツールなし）

## 📋 判明した制限事項

### Windows環境の制限
- Claude CodeのMCP機能は現時点でWindows環境で完全にサポートされていない
- WSL環境では動作する可能性があるが、ネイティブWindows環境では制限あり

### プロジェクトレベルMCPの問題
- `.mcp.json` ファイルの自動読み込みが機能しない
- プロジェクトごとのMCP設定が認識されない

### コマンドラインツールの制限
- `claude mcp add` コマンドがWindows環境で期待通り動作しない
- `npx` コマンドの実行に問題がある

## 🎯 推奨される代替手段

### 1. 標準ツールの活用
- **Bash**: コマンド実行とスクリプト
- **Read/Write/Edit**: ファイル操作
- **WebFetch**: Web内容の取得と分析
- **Task**: 複雑なタスクの並列実行

### 2. 既存のテストフレームワーク
```bash
# Vitestでのテスト実行
npm test

# 個別テストファイルの実行
npm test -- src/components/Dashboard.test.tsx
```

### 3. 手動E2Eテスト
- ブラウザでの手動操作確認
- 開発者ツールでのネットワーク監視
- コンソールログの確認

## 📌 今後の対応

### 短期的対応
1. 既存ツールでの開発継続
2. テストは従来のフレームワークを使用
3. E2Eテストは手動またはCIで実行

### 長期的対応
1. Claude CodeのWindows対応を待つ
2. WSL環境での開発を検討
3. 公式ドキュメントの更新を定期的に確認

## 🔗 関連情報

### 参考リンク
- [Qiita: Claude CodeのMCP Windows対応記事](https://qiita.com/from2001vr/items/e2f53414e58dd3c6a6ea)
- [Claude Code MCP公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code/mcp)

### 確認したファイル
- `C:\Users\zooyo\Documents\GitHub\DX\digital-management-consulting-app\.mcp.json`
- MCPサーバー設定（playwright, Context7, brave-search）

---

**作成者**: Claude Code Assistant  
**最終更新**: 2025-07-23 22:15  
**関連ドキュメント**: knowledge.md, task.md