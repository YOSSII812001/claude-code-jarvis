# Style-Bert-VITS2 CLIコマンドリファレンス

このドキュメントはSKILL.mdの補助ファイルです。Style-Bert-VITS2のCLIコマンドリファレンス。

## 環境情報

| 項目 | 値 |
|------|-----|
| Python実行パス | `C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe` |
| 作業ディレクトリ | `C:\Users\zooyo\Style-Bert-VITS2` |
| バージョン | 2.7.0 |
| 対応言語 | JP（日本語）, EN（英語）, ZH（中国語） |
| 設定ファイル | `config.yml` |

---

## 1. 概要（CLIでできること）

Style-Bert-VITS2のCLIは以下のワークフローをカバーする:

1. **初期化**: BERTモデル・事前学習済みモデルのダウンロード、パス設定
2. **データ準備**: 音声ファイルの分割（スライス）、文字起こし（トランスクリプション）
3. **前処理**: 学習データの前処理（正規化、BERT特徴量生成、スタイルベクトル生成）
4. **学習**: モデルの学習（通常版 / JP-Extra版）
5. **APIサーバー**: 推論用FastAPIサーバーの起動（音声合成API）

---

## 2. 初期化・モデルダウンロード（initialize.py）

BERTモデル、事前学習済みモデル、デフォルトTTSモデルのダウンロードとパス設定を行う。

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\initialize.py [オプション]
```

### オプション

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--skip_default_models` | デフォルト音声モデルのダウンロードをスキップ（自前モデルのみ使う場合） | なし |
| `--only_infer` | 推論用モデルのみダウンロード（SLM・事前学習済みモデルをスキップ） | なし |
| `--dataset_root <path>` | 学習データセットのルートディレクトリ | `Data` |
| `--assets_root <path>` | モデルアセットのルートディレクトリ（推論用） | `model_assets` |

### ダウンロードされるもの

- **BERTモデル**: 日本語（deberta-v2-large-japanese-char-wwm）、英語（deberta-v3-large）、中国語（chinese-roberta-wwm-ext-large）
- **SLMモデル**: wavlm-base-plus（`--only_infer` 指定時はスキップ）
- **事前学習済みモデル**: 通常版（G_0, D_0, DUR_0）、JP-Extra版（G_0, D_0, WD_0）（`--only_infer` 指定時はスキップ）
- **デフォルトTTSモデル**: jvnv-F1-jp, jvnv-F2-jp, jvnv-M1-jp, jvnv-M2-jp, koharune-ami（`--skip_default_models` 指定時はスキップ）

### 使用例

```powershell
# フルインストール（全モデルダウンロード）
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\initialize.py

# 推論のみ（学習用モデルをスキップ）
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\initialize.py --only_infer

# デフォルトモデルをスキップ（自前モデルのみ使う場合）
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\initialize.py --skip_default_models

# データセットとアセットのパスをカスタマイズ
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\initialize.py --dataset_root "D:\TTS_Data" --assets_root "D:\TTS_Models"
```

---

## 3. APIサーバー起動コマンド（server_fastapi.py）

音声合成APIサーバーを起動する。FastAPI + Uvicornベースで、`http://127.0.0.1:5000` でリッスンする。

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\server_fastapi.py [オプション]
```

### コマンドラインオプション

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--cpu` | GPUの代わりにCPUを使用 | なし（GPU自動検出） |
| `--dir`, `-d` | モデルディレクトリのパス | `config.yml` の `assets_root` |
| `--preload_onnx_bert` | ONNX版BERTモデルを事前ロード（VRAM消費増） | なし |

### config.yml サーバー設定

`config.yml` の `server` セクションでサーバーの動作を制御する:

```yaml
server:
  port: 5000        # リッスンポート
  device: "cuda"    # デバイス ("cuda" or "cpu")
  language: "JP"    # デフォルト言語
  limit: 300        # 1リクエストあたりの最大文字数 (-1 で無制限)
  origins:          # CORS許可オリジン
    - "*"
```

### APIエンドポイント一覧

| メソッド | パス | 説明 |
|---------|------|------|
| GET/POST | `/voice` | テキストから音声合成（メインAPI） |
| POST | `/g2p` | テキストからカタカナ・アクセント変換 |
| GET | `/models/info` | ロード済みモデル情報の取得 |
| POST | `/models/refresh` | モデルの再読み込み |
| GET | `/status` | サーバーステータス（CPU/GPU/メモリ情報） |
| GET | `/tools/get_audio` | ローカルWAVファイルの取得 |
| GET | `/docs` | Swagger UI（API仕様書） |

### `/voice` エンドポイント パラメータ

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `text` | string | **必須** | 合成するテキスト |
| `encoding` | string | なし | テキストのURLデコード文字コード（例: `utf-8`） |
| `model_name` | string | なし | モデル名（model_idより優先） |
| `model_id` | int | 0 | モデルID |
| `speaker_name` | string | なし | 話者名（speaker_idより優先） |
| `speaker_id` | int | 0 | 話者ID |
| `sdp_ratio` | float | 0.2 | SDP/DP混合比（高いほどトーンのばらつき大） |
| `noise` | float | 0.6 | サンプルノイズ割合（高いほどランダム性大） |
| `noisew` | float | 0.8 | SDPノイズ（高いほど発音間隔のばらつき大） |
| `length` | float | 1.0 | 話速（1.0基準、大きいほど遅い） |
| `language` | string | "JP" | テキストの言語（JP/EN/ZH） |
| `auto_split` | bool | true | 改行で分割して生成 |
| `split_interval` | float | 0.5 | 分割時に挟む無音の長さ（秒） |
| `assist_text` | string | なし | 参照テキスト（似た声音・感情になる） |
| `assist_text_weight` | float | 1.0 | assist_textの強さ |
| `style` | string | "Neutral" | スタイル名 |
| `style_weight` | float | 1.0 | スタイルの強さ |
| `reference_audio_path` | string | なし | スタイル参照用音声ファイルパス |

---

## 4. データ準備コマンド

### 4.1. 音声ファイル分割（slice.py）

長い音声ファイルを学習に適した長さに分割する。

対応フォーマット: `.wav`, `.flac`, `.mp3`, `.ogg`, `.opus`, `.m4a`

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\slice.py --model_name <モデル名> [オプション]
```

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--model_name` | **必須**。話者名（学習モデルの名前として使用） | - |
| `-i`, `--input_dir` | 分割対象の音声ファイルがあるディレクトリ | `inputs` |
| `-m`, `--min_sec` | 分割後の最小秒数 | 2 |
| `-M`, `--max_sec` | 分割後の最大秒数 | 12 |
| `--time_suffix` | ファイル名末尾に開始-終了時刻（ms）を付与 | なし |

### 4.2. 文字起こし（transcribe.py）

Whisperを使用して音声ファイルのテキスト注釈を生成する。

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\transcribe.py --model_name <モデル名> [オプション]
```

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--model_name` | **必須**。話者名 | - |
| `--initial_prompt` | 文字起こしの初期プロンプト | 日本語用デフォルト |
| `--device` | 使用デバイス | `cuda` |
| `--language` | 言語（`jp`, `en`, `zh`） | `jp` |
| `--model` | Whisperモデル | `large-v3` |
| `--compute_type` | 計算精度（faster-whisper使用時のみ） | `bfloat16` |
| `--use_hf_whisper` | HuggingFace版Whisperを使用（高速だがVRAM多） | なし |
| `--batch_size` | バッチサイズ（HF Whisper使用時のみ） | 16 |
| `--num_beams` | ビームサイズ | 1 |
| `--no_repeat_ngram_size` | リピート防止N-gramサイズ | 10 |

---

## 5. モデル学習関連コマンド

### 5.1. 前処理（preprocess_all.py）

学習データの前処理を一括実行する（リサンプリング、テキスト前処理、BERT特徴量生成、スタイルベクトル生成）。

```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\preprocess_all.py -m <モデル名> [オプション]
```

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `-m`, `--model_name` | **必須**。話者名 | - |
| `-b`, `--batch_size` | バッチサイズ | 2 |
| `-e`, `--epochs` | エポック数 | 100 |
| `-s`, `--save_every_steps` | 保存間隔（ステップ数） | 1000 |
| `--num_processes` | 並列プロセス数 | CPUコア数の半分 |
| `--normalize` | ラウドネス正規化を適用 | なし |
| `--trim` | 無音トリミング | なし |
| `--freeze_EN_bert` | 英語BERTをフリーズ | なし |
| `--freeze_JP_bert` | 日本語BERTをフリーズ | なし |
| `--freeze_ZH_bert` | 中国語BERTをフリーズ | なし |
| `--freeze_style` | スタイルベクトルをフリーズ | なし |
| `--freeze_decoder` | デコーダをフリーズ | なし |
| `--use_jp_extra` | JP-Extraモデルを使用 | なし |
| `--val_per_lang` | 言語あたりの検証データ数 | 0 |
| `--log_interval` | ログ出力間隔 | 200 |
| `--yomi_error` | 読みエラーの処理方法（`raise`/`skip`/`use`） | `raise` |

`--yomi_error` の選択肢:
- `raise`: 全テキスト前処理後にエラーを発生させる
- `skip`: エラーのあるテキストをスキップ
- `use`: 不明な文字を無視してそのまま使用

### 5.2. 学習（train_ms.py / train_ms_jp_extra.py）

学習設定は前処理（preprocess_all.py）の結果から自動的に読み込まれる。

**通常モデル（JP-Extra以外）:**
```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\train_ms.py [オプション]
```

**JP-Extraモデル:**
```powershell
C:\Users\zooyo\Style-Bert-VITS2\venv\Scripts\python.exe C:\Users\zooyo\Style-Bert-VITS2\train_ms_jp_extra.py [オプション]
```

| オプション | 説明 | デフォルト |
|------------|------|-----------|
| `--repo_id` | HuggingFaceリポジトリID（学習済みモデルのアップロード先） | なし |
| `--skip_default_style` | デフォルトスタイルベクトル生成をスキップ（学習再開時に使用） | なし（JP-Extraのみ） |

> `--repo_id` を使用するには事前に `huggingface-cli login` でログインが必要。

---

## 6. よく使うコマンド集（クイックリファレンス）

### APIサーバー起動（日常使い）

```powershell
# 標準起動（GPU使用）
Set-Location C:\Users\zooyo\Style-Bert-VITS2
.\venv\Scripts\python.exe server_fastapi.py

# CPU強制（GPU不使用）
.\venv\Scripts\python.exe server_fastapi.py --cpu

# カスタムモデルディレクトリ指定
.\venv\Scripts\python.exe server_fastapi.py -d "D:\MyModels"
```

### APIサーバー動作確認

```powershell
# サーバーステータス確認
Invoke-RestMethod -Uri "http://127.0.0.1:5000/status" | ConvertTo-Json

# ロード済みモデル一覧
Invoke-RestMethod -Uri "http://127.0.0.1:5000/models/info" | ConvertTo-Json

# 音声合成テスト（ずんだもん）
$params = @{
    text = "こんにちは、ずんだもんなのだ"
    speaker_name = "zundamon"
    language = "JP"
    sdp_ratio = 0.2
    length = 1.0
}
$queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join "&"
Invoke-WebRequest -Uri "http://127.0.0.1:5000/voice?$queryString" -Method Post -OutFile "$env:TEMP\test.wav"
Start-Process "$env:TEMP\test.wav"
```

### モデル学習フロー（一連の実行）

```powershell
Set-Location C:\Users\zooyo\Style-Bert-VITS2

# 1. 音声ファイルを inputs/ に配置した後、スライス
.\venv\Scripts\python.exe slice.py --model_name zundamon

# 2. 文字起こし
.\venv\Scripts\python.exe transcribe.py --model_name zundamon --language jp

# 3. 前処理（JP-Extraモデル使用、100エポック）
.\venv\Scripts\python.exe preprocess_all.py -m zundamon --use_jp_extra -e 100 -b 2

# 4. 学習開始（JP-Extra）
.\venv\Scripts\python.exe train_ms_jp_extra.py
```

### 初期セットアップ

```powershell
Set-Location C:\Users\zooyo\Style-Bert-VITS2

# Python仮想環境の有効化
.\venv\Scripts\Activate.ps1

# 全モデルダウンロード（初回）
.\venv\Scripts\python.exe initialize.py

# 推論のみ使う場合（学習用モデルをスキップ）
.\venv\Scripts\python.exe initialize.py --only_infer
```

---

## 補足: ディレクトリ構造

```
C:\Users\zooyo\Style-Bert-VITS2\
  ├── model_assets/          # 推論用モデル（assets_root）
  │   ├── zundamon/          # ずんだもんモデル
  │   │   ├── config.json
  │   │   ├── *.safetensors
  │   │   └── style_vectors.npy
  │   ├── jvnv-F1-jp/       # デフォルトモデル
  │   └── ...
  ├── Data/                  # 学習データセット（dataset_root）
  │   └── <model_name>/
  ├── bert/                  # BERTモデル
  ├── pretrained/            # 事前学習済みモデル（通常版）
  ├── pretrained_jp_extra/   # 事前学習済みモデル（JP-Extra版）
  ├── configs/
  │   ├── paths.yml          # パス設定
  │   └── default_paths.yml
  ├── config.yml             # メイン設定ファイル
  ├── server_fastapi.py      # APIサーバー
  ├── initialize.py          # 初期化スクリプト
  ├── slice.py               # 音声スライス
  ├── transcribe.py          # 文字起こし
  ├── preprocess_all.py      # 前処理
  ├── train_ms.py            # 学習（通常版）
  └── train_ms_jp_extra.py   # 学習（JP-Extra版）
```

---

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-01 | 初版作成。GitHub CLI.md + ソースコード解析に基づくCLIリファレンス |
