# Self-Hosting ガイド — Fish Audio

## 概要

[fish-speech](https://github.com/fishaudio/fish-speech) はオープンソースの音声合成モデル。
ローカル環境やプライベートサーバーでFish Audio相当のTTSを実行可能。

## システム要件

| 項目 | 最小 | 推奨 |
|---|---|---|
| GPU VRAM | 8 GB | 12 GB以上 |
| RAM | 16 GB | 32 GB |
| OS | Linux / WSL2 | Ubuntu 22.04+ |
| ストレージ | 20 GB | 50 GB |
| Python | 3.10+ | 3.11 |

**注意**: Windows ネイティブは非推奨。WSL2 を使用すること。

## インストール方法

### Conda（推奨）

```bash
# リポジトリクローン
git clone https://github.com/fishaudio/fish-speech.git
cd fish-speech

# Conda環境作成
conda create -n fish-speech python=3.11
conda activate fish-speech

# PyTorch（CUDA対応）
conda install pytorch torchvision torchaudio pytorch-cuda=12.6 -c pytorch -c nvidia

# 依存パッケージ
pip install -e .
```

### UV

```bash
git clone https://github.com/fishaudio/fish-speech.git
cd fish-speech

uv venv --python 3.11
source .venv/bin/activate

# CUDA対応 PyTorch
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

uv pip install -e .
```

## CUDA バージョン選択

| CUDA | PyTorch Index URL |
|---|---|
| cu126 | `https://download.pytorch.org/whl/cu126` |
| cu128 | `https://download.pytorch.org/whl/cu128` |
| cu129 | `https://download.pytorch.org/whl/cu129` |

`nvidia-smi` で搭載GPUのCUDAバージョンを確認し、対応するバージョンを選択。

## 起動

```bash
# APIサーバー起動
python -m fish_speech.serve --listen 0.0.0.0:8080

# WebUI 起動（オプション）
python -m fish_speech.webui
```

## パフォーマンス目安

| GPU | リアルタイム比率 | 備考 |
|---|---|---|
| RTX 3060 (12GB) | ~1:15 | エントリーレベル |
| RTX 4090 (24GB) | ~1:7 | ハイエンドコンシューマー |
| A100 (80GB) | ~1:5 | データセンター |

**リアルタイム比率**: 1秒の音声を生成するのに要する時間。1:7 = 1秒の音声を約0.14秒で生成。

## Docker 構成

```yaml
# docker-compose.yml
services:
  fish-speech:
    image: fishaudio/fish-speech:latest
    ports:
      - "8080:8080"
    volumes:
      - ./models:/app/models
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    environment:
      - CUDA_VISIBLE_DEVICES=0
```

```bash
docker compose up -d
```

## トラブルシューティング

| 問題 | 原因 | 解決策 |
|---|---|---|
| CUDA out of memory | VRAM不足 | バッチサイズ削減、`--half` オプション |
| `torch.cuda.is_available()` が False | CUDAドライバ未インストール | `nvidia-smi` 確認、ドライバ更新 |
| 依存パッケージの衝突 | Python/PyTorch バージョン不一致 | 新しいConda環境を作成 |
| モデルダウンロード失敗 | ネットワーク問題 | `HF_ENDPOINT` 環境変数でミラー指定 |
| WSL2でGPU認識しない | WSL GPUドライバ未設定 | Windows側のNVIDIA GPUドライバを最新に更新 |
