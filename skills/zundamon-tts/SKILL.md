---
name: zundamon-tts
description: |
  Style-Bert-VITS2を使用した「ずんだもん」音声でClaudeの全テキスト出力を読み上げるスキル。
  有効化/無効化のトグル機能付き。有効時はJARVIS音声を自動停止。
  トリガー: "ずんだもん", "zundamon", "zundamon-tts", "ずんだもん読み上げ",
  "ずんだもんTTS", "zundamon tts", "読み上げずんだもん"
---

# ずんだもんTTS読み上げスキル

Style-Bert-VITS2 APIを使用して、Claudeの全テキスト出力を「ずんだもん」ボイスで読み上げる。
有効時はJARVIS音声（VOICEVOX）を自動停止し、無効化するとJARVISに戻る。

## クイックリファレンス

| 項目 | 値 |
|------|-----|
| TTSエンジン | Style-Bert-VITS2 |
| APIサーバー | `http://127.0.0.1:5000` |
| 話者 | ずんだもん (`zundamon`) |
| フラグファイル | `%TEMP%\zundamon_tts_active.txt` |
| スクリプト | `~/.claude/speak_zundamon.ps1` |
| FFmpegエフェクト | JARVIS風フルフィルター適用 |

## 有効化/無効化

### 有効化（`/zundamon-tts` または `/zundamon-tts on`）

以下のPowerShellコマンドを実行してフラグファイルを作成:

```powershell
"active" | Set-Content -Path (Join-Path $env:TEMP "zundamon_tts_active.txt") -Encoding ascii
```

実行後、ユーザーに以下を通知:
- ずんだもんTTSが有効になりました
- JARVIS音声は自動停止します
- Style-Bert-VITS2 APIサーバー（port 5000）が起動している必要があります
- 無効化: `/zundamon-tts off`

### 無効化（`/zundamon-tts off`）

以下のPowerShellコマンドを実行してフラグファイルを削除:

```powershell
Remove-Item -Path (Join-Path $env:TEMP "zundamon_tts_active.txt") -Force -ErrorAction SilentlyContinue
```

実行後、ユーザーに以下を通知:
- ずんだもんTTSが無効になりました
- JARVIS音声が再開されます

### 状態確認

```powershell
if (Test-Path (Join-Path $env:TEMP "zundamon_tts_active.txt")) { "ずんだもんTTS: 有効" } else { "ずんだもんTTS: 無効（JARVIS有効）" }
```

## セットアップ手順（初回のみ）

> **詳細な導入手順は [`SETUP_GUIDE.md`](./SETUP_GUIDE.md) を参照。**
> **CLIコマンドリファレンスは [`SBV2_CLI.md`](./SBV2_CLI.md) を参照。**
> 以下はクイックスタート要約。

### 1. Style-Bert-VITS2 インストール

```powershell
git clone https://github.com/litagin02/Style-Bert-VITS2.git C:\Users\zooyo\Style-Bert-VITS2
py -3.11 -m venv C:\Users\zooyo\Style-Bert-VITS2\venv
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe install torch==2.3.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\pip.exe install -r C:\Users\zooyo\Style-Bert-VITS2\requirements.txt
```

### 2. ずんだもんモデルの準備

ずんだもんの学習済みモデルを `model_assets/zundamon/` に配置する。
必要ファイル:
- `config.json` — モデル設定
- `*.safetensors` または `*.pth` — モデルウェイト
- `style_vectors.npy` — スタイルベクトル

入手先:
- Hugging Face で「Style-Bert-VITS2 zundamon」を検索
- または自前で学習（東北ずん子プロジェクトの音声データ使用）

### 3. APIサーバー設定

`config.yml` の `server` セクションを編集:

```yaml
server:
  port: 5000
  device: "cuda"  # GPU使用。CPUのみの場合は "cpu"
  limit: 300       # 1リクエストあたりの最大文字数（デフォルト100→300に拡張推奨）
```

### 4. APIサーバー起動

```powershell
Set-Location C:\Users\zooyo\Style-Bert-VITS2
.\venv\Scripts\python.exe server_fastapi.py
```

起動確認: ブラウザで `http://127.0.0.1:5000/docs` を開き、Swagger UIが表示されればOK。

### 5. 動作テスト

```powershell
# モデル情報確認
Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info" | ConvertTo-Json

# 音声合成テスト
$params = @{
    text = "こんにちは、ずんだもんなのだ"
    speaker_name = "zundamon"
    language = "JP"
    sdp_ratio = 0.2
    length = 1.0
}
$queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join "&"
Invoke-WebRequest -Uri "http://127.0.0.1:5000/voice?$queryString" -Method Post -OutFile "$env:TEMP\zundamon_test.wav"
Start-Process "$env:TEMP\zundamon_test.wav"
```

## トラブルシューティング

### APIサーバーに接続できない
- Style-Bert-VITS2が起動しているか確認: `Invoke-RestMethod http://127.0.0.1:5000/status`
- ポート5000が他のアプリに使われていないか確認
- ファイアウォール設定を確認

### 音声が生成されない
- ずんだもんモデルが `model_assets/` に正しく配置されているか確認
- `speaker_name` が正しいか確認: `/models/info` エンドポイントで利用可能な話者一覧を取得
- `config.yml` の `limit` が十分か確認（デフォルト100文字）

### 音声が遅い
- GPU（CUDA）を使用しているか確認（`config.yml` の `device: "cuda"`）
- CPU動作は大幅に遅延する（1文あたり数秒〜数十秒）

### JARVISに戻らない
- フラグファイルを手動削除: `Remove-Item "$env:TEMP\zundamon_tts_active.txt" -Force`

## 関連スキル
- `voicevox-dict` — VOICEVOX辞書管理（JARVISモード時）

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-04-01 | 初版作成 | ずんだもんTTS読み上げスキル新規作成 |
