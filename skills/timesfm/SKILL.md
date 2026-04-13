---
name: timesfm
description: Google TimesFM 時系列予測基盤モデルの開発ガイド。PyTorch/JAX対応、ゼロショット予測、共変量、ファインチューニング、モデル設定を含む。
---

# TimesFM — Google 時系列予測基盤モデル

## 概要

TimesFMはGoogle Researchが開発した、事前学習済みのデコーダのみ（decoder-only）の時系列予測基盤モデル。大規模な時系列コーパスで事前学習されており、ゼロショット（追加学習なし）で高精度な予測が可能。単変量予測と共変量（外部変数）サポートの両方に対応する。

公式リポジトリ: https://github.com/google-research/timesfm

**トリガー:** `timesfm`, `TimesFM`, `時系列予測`, `demand forecast`, `需要予測AI`

## モデル一覧

### v2.5（最新、推奨）
| モデル名 | パラメータ | HuggingFace repo ID | バックエンド |
|---------|-----------|---------------------|------------|
| TimesFM 2.5 200M PyTorch | 200M | `google/timesfm-2.5-200m-pytorch` | PyTorch |
| TimesFM 2.5 200M Flax | 200M | `google/timesfm-2.5-200m-flax` | JAX/Flax |

### v2.0
| モデル名 | パラメータ | HuggingFace repo ID | バックエンド |
|---------|-----------|---------------------|------------|
| TimesFM 2.0 500M JAX | 500M | `google/timesfm-2.0-500m-jax` | JAX |
| TimesFM 2.0 500M PyTorch | 500M | `google/timesfm-2.0-500m-pytorch` | PyTorch |

### v1.0
| モデル名 | パラメータ | HuggingFace repo ID | バックエンド |
|---------|-----------|---------------------|------------|
| TimesFM 1.0 200M | 200M | `google/timesfm-1.0-200m` | JAX |
| TimesFM 1.0 200M PyTorch | 200M | `google/timesfm-1.0-200m-pytorch` | PyTorch |

## インストール

### Python版要件
- **PyTorch版**: Python 3.11 推奨
- **JAX/PAX版**: Python 3.10 推奨

### PyTorch版（推奨）

**PyPIからインストール:**
```shell
pip install timesfm[torch]
```

**GitHubからインストール（v2.5 200Mモデルを使う場合に必要）:**
```shell
git clone https://github.com/google-research/timesfm.git
cd timesfm
pip install -e ".[torch]"
```

**Poetry使用時:**
```shell
pyenv local 3.11.10
poetry env use 3.11.10
poetry lock
poetry install -E torch
```

### JAX/PAX版
```shell
pip install timesfm[pax]
```

Apple Silicon (M1/M2/M3) の場合:
```shell
arch -x86_64 pip install timesfm[pax]
```

### 重要: PyPI版 vs GitHub版の違い

PyPI版 `timesfm` (1.3.0等) には `TimesFM_2p5_200M_torch` クラスが含まれていない場合がある。v2.5の新しいAPI（`from_pretrained` + `compile` + `ForecastConfig`）を使用するには、**GitHubメイン版からのインストールが必要**:

```shell
pip install "timesfm[torch] @ git+https://github.com/google-research/timesfm.git"
```

### 共変量機能を使う場合の追加依存

PyTorch版で `forecast_with_covariates` を使用するには、JAXの追加インストールが必要:
```shell
pip install jax jaxlib
```

## 基本的な使い方

### v2.5 API（推奨）: from_pretrained + compile + forecast

```python
import torch
import numpy as np
import timesfm

torch.set_float32_matmul_precision("high")

# モデルロード（初回はHugging Faceからダウンロード、以降はキャッシュ）
model = timesfm.TimesFM_2p5_200M_torch.from_pretrained(
    "google/timesfm-2.5-200m-pytorch"
)

# ローカルディレクトリからロードも可能
# model = timesfm.TimesFM_2p5_200M_torch.from_pretrained("/path/to/local/checkpoint")

# コンパイル（推論設定）
model.compile(
    timesfm.ForecastConfig(
        max_context=1024,
        max_horizon=256,
        normalize_inputs=True,
        use_continuous_quantile_head=True,
        force_flip_invariance=True,
        infer_is_positive=True,
        fix_quantile_crossing=True,
    )
)

# 予測実行
point_forecast, quantile_forecast = model.forecast(
    horizon=12,
    inputs=[
        np.linspace(0, 1, 100),
        np.sin(np.linspace(0, 20, 67)),
    ],
)

point_forecast.shape      # (2, 12)
quantile_forecast.shape   # (2, 12, 11): mean + 10th-90th percentiles
```

### v2.0/v1.0 API（レガシー）: TimesFm + TimesFmHparams

```python
import timesfm

tfm = timesfm.TimesFm(
    hparams=timesfm.TimesFmHparams(
        backend="gpu",           # "cpu", "gpu", "tpu"
        per_core_batch_size=32,
        horizon_len=128,
        num_layers=50,
        use_positional_embedding=False,  # v2.0はFalse、v1.0はTrue
        context_len=2048,
    ),
    checkpoint=timesfm.TimesFmCheckpoint(
        huggingface_repo_id="google/timesfm-2.0-500m-pytorch"
    ),
)

# numpy配列で予測
forecast_input = [
    np.sin(np.linspace(0, 20, 100)),
    np.sin(np.linspace(0, 20, 200)),
]
frequency_input = [0, 1]  # 0: high, 1: medium, 2: low

point_forecast, quantile_forecast = tfm.forecast(
    forecast_input,
    freq=frequency_input,
)

# DataFrameで予測
forecast_df = tfm.forecast_on_df(
    inputs=input_df,        # unique_id, ds, y カラム
    freq="M",               # "M": monthly, "D": daily, "H": hourly, etc.
    value_name="y",
    num_jobs=-1,
)
```

### ForecastConfig パラメータ一覧（v2.5）

| パラメータ | 型 | デフォルト | 説明 |
|-----------|------|-----------|------|
| `max_context` | int | - | 最大入力コンテキスト長（最大4096）。32の倍数推奨 |
| `max_horizon` | int | - | 最大予測ホライズン（continuous quantile headで最大1024） |
| `normalize_inputs` | bool | - | 入力正規化（スケールの異なるデータで数値安定性向上） |
| `use_continuous_quantile_head` | bool | - | 連続分位点ヘッド使用（より正確な分位推定） |
| `force_flip_invariance` | bool | - | アフィン不変性を負のスケールにも拡張（負値処理改善） |
| `infer_is_positive` | bool | - | 入力が正値のみなら予測も非負に制約（需要・売上等に有効） |
| `fix_quantile_crossing` | bool | - | 分位点の順序違反を修正（q10 > q50 等を防止） |
| `return_backcast` | bool | False | 過去期間の予測も返すか |
| `per_core_batch_size` | int | 1 | デバイスあたりのバッチサイズ |

### 出力形式

`model.forecast()` は `(point_forecast, quantile_forecast)` のタプルを返す。

**point_forecast**: `np.ndarray`, shape `(num_series, horizon)`
- 中央値（median）予測

**quantile_forecast**: `np.ndarray`, shape `(num_series, horizon, 11)`
- インデックスと分位点の対応:

| インデックス | 分位点 |
|------------|--------|
| 0 | mean（平均） |
| 1 | 10th percentile |
| 2 | 20th percentile |
| 3 | 30th percentile |
| 4 | 40th percentile |
| 5 | 50th percentile（median） |
| 6 | 60th percentile |
| 7 | 70th percentile |
| 8 | 80th percentile |
| 9 | 90th percentile |
| 10 | (状況による: v2.5で11番目) |

**予測区間の取り出し例:**
```python
# 80%予測区間 (10th - 90th)
q10 = quantile_forecast[0, :, 1]   # 下限
q90 = quantile_forecast[0, :, 9]   # 上限
median = quantile_forecast[0, :, 5] # 中央値

# 7日間の予測を表示
for day in range(7):
    print(f"Day {day+1}: {median[day]:.1f} "
          f"(80% PI: [{q10[day]:.1f}, {q90[day]:.1f}])")
```

### 頻度パラメータ（freq）

レガシーAPIでは `freq` を整数またはDataFrame形式の文字列で指定:

| 整数値 | 意味 | 文字列例 |
|--------|------|---------|
| 0 | 高頻度 | 分単位、時間単位 |
| 1 | 中頻度 | 日次 |
| 2 | 低頻度 | 週次、月次 |

v2.5 APIの `model.forecast()` では `freq` パラメータは不要（モデルが自動判定）。

### 可変長時系列の自動処理

TimesFMは異なる長さの時系列を自動的に処理する:
- **短い系列** (`< max_context`): 自動パディング
- **長い系列** (`> max_context`): 最新データを使って自動切り詰め

```python
short_series = np.random.randn(50)
long_series = np.random.randn(800)

point_forecast, quantile_forecast = model.forecast(
    horizon=48,
    inputs=[short_series, long_series]  # 長さが異なってもOK
)
```

## 共変量（外部変数）

`forecast_with_covariates` で祝日フラグ、天気予報、曜日などの外部変数を組み込める。**JAXの追加インストールが必要。**

```shell
pip install jax jaxlib
```

### 共変量の種類

| 種類 | パラメータ名 | 例 |
|------|------------|-----|
| 動的数値共変量 | `dynamic_numerical_covariates` | 気温予報、電力需要予測 |
| 動的カテゴリ共変量 | `dynamic_categorical_covariates` | 曜日、祝日フラグ |
| 静的数値共変量 | `static_numerical_covariates` | 施設の部屋数 |
| 静的カテゴリ共変量 | `static_categorical_covariates` | 国、地域 |

**重要**: 動的共変量は `context_len + horizon_len` 分のデータが必要（過去と未来の両方）。

### 使用例

```python
cov_forecast, ols_forecast = model.forecast_with_covariates(
    inputs=example["inputs"],
    dynamic_numerical_covariates={
        "gen_forecast": example["gen_forecast"],   # 既知の将来値
    },
    dynamic_categorical_covariates={
        "week_day": example["week_day"],           # 曜日 (0-6)
    },
    static_numerical_covariates={},
    static_categorical_covariates={
        "country": example["country"],             # 国コード
    },
    freq=[0] * len(example["inputs"]),
    xreg_mode="xreg + timesfm",    # "xreg + timesfm"（デフォルト）or "xreg"
    ridge=0.0,
    force_on_cpu=False,
    normalize_xreg_target_per_input=True,
)
```

**xreg_mode の選択肢:**
- `"xreg + timesfm"`: TimesFMの予測 + 共変量の線形回帰を組み合わせ（推奨）
- `"xreg"`: 共変量のみの線形回帰

**戻り値:**
- `cov_forecast`: 共変量を加味した最終予測
- `ols_forecast`: 共変量のみの線形回帰予測

## ファインチューニング

### PyTorch版（TimesFMFinetuner）

```python
from timesfm.models import TimesFMFinetuner, FinetuningConfig
from timesfm import TimesFm, TimesFmCheckpoint, TimesFmHparams
from timesfm.pytorch_patched_decoder import PatchedTimeSeriesDecoder

# モデル取得
device = "cuda" if torch.cuda.is_available() else "cpu"
repo_id = "google/timesfm-2.0-500m-pytorch"
hparams = TimesFmHparams(
    backend=device,
    per_core_batch_size=32,
    horizon_len=128,
    num_layers=50,
    use_positional_embedding=False,
    context_len=192,   # 最大2048、32の倍数
)
tfm = TimesFm(hparams=hparams,
              checkpoint=TimesFmCheckpoint(huggingface_repo_id=repo_id))
model = PatchedTimeSeriesDecoder(tfm._model_config)

# 重み読み込み
from huggingface_hub import snapshot_download
from os import path
checkpoint_path = path.join(snapshot_download(repo_id), "torch_model.ckpt")
loaded_checkpoint = torch.load(checkpoint_path, weights_only=True)
model.load_state_dict(loaded_checkpoint)

# ファインチューニング設定
config = FinetuningConfig(
    batch_size=256,
    num_epochs=5,
    learning_rate=1e-4,
    use_wandb=True,            # W&Bログ
    freq_type=1,               # 0: high, 1: medium, 2: low
    log_every_n_steps=10,
    val_check_interval=0.5,
    use_quantile_loss=True,    # 分位損失を使用
)

# データ準備（TimeSeriesDataset）
train_dataset, val_dataset = prepare_datasets(
    series=time_series_data,
    context_length=128,
    horizon_length=128,
    freq_type=config.freq_type,
    train_split=0.8,
)

# ファインチューニング実行
finetuner = TimesFMFinetuner(model, config)
results = finetuner.finetune(
    train_dataset=train_dataset,
    val_dataset=val_dataset,
)
```

### FinetuningConfig パラメータ

| パラメータ | 型 | 説明 |
|-----------|------|------|
| `batch_size` | int | バッチサイズ |
| `num_epochs` | int | エポック数 |
| `learning_rate` | float | 学習率 |
| `use_wandb` | bool | Weights & Biases ログ |
| `freq_type` | int | 頻度タイプ (0/1/2) |
| `log_every_n_steps` | int | ログ間隔 |
| `val_check_interval` | float | 検証間隔 (0.5 = 半エポック毎) |
| `use_quantile_loss` | bool | 分位損失の使用 |

### TimeSeriesDataset（PyTorch）

スライディングウィンドウでコンテキストとホライズンのペアを生成:

```python
from torch.utils.data import Dataset

class TimeSeriesDataset(Dataset):
    def __init__(self, series, context_length, horizon_length, freq_type=0):
        # freq_type: 0, 1, 2 のいずれか
        # スライディングウィンドウでサンプル生成
        ...

    def __getitem__(self, index):
        # (x_context, input_padding, freq, x_future) を返す
        ...
```

### JAX/PAX版ファインチューニング

JAX版はPAXML (Praxis) ライブラリを使用。Linear probing（Transformer層を固定し、出力層のみ学習）が推奨:

```python
# bprop_variable_exclusion で Transformer 層を凍結
optimizer = optimizers.Adam(
    learning_rate=1e-2,
    lr_schedule=schedules.Cosine(
        initial_value=1e-3,
        final_value=1e-4,
        total_steps=40000,
    ),
)
# Linear probing: Transformer層を固定
bprop_variable_exclusion=['.*/stacked_transformer_layer/.*']
```

## モデルアーキテクチャ

### 基本設計
- **アーキテクチャ**: デコーダのみ（decoder-only）Transformer
- **入力**: パッチ化された時系列（patch_len=32）
- **出力**: 各パッチの次の128ステップを予測
- **自己回帰デコーディング**: ホライズンが128を超える場合、128ステップずつ予測→フィードバック→再予測

### モデルサイズと設定

| モデル | パラメータ | num_layers | model_dims | context_len |
|--------|-----------|------------|-----------|-------------|
| v2.5 200M | 200M | - | - | 最大4096 |
| v2.0 500M | 500M | 50 | - | 最大2048 |
| v1.0 200M | 200M | 20 | 1280 | 最大512 |

### v2.0/v2.5での変更点
- `use_positional_embedding=False`（v1.0では `True`）
- コンテキスト長の拡張（512 → 2048 → 4096）
- 連続分位点ヘッド（continuous quantile head）の追加
- アフィン不変性（flip invariance）の強化

### パッチサイズ
- `input_patch_len=32`: 入力パッチ長
- `output_patch_len=128`: 出力パッチ長（1回の推論で128ステップ予測）

## トラブルシューティング

### PyPI版 vs GitHub版のstate_dict不整合

PyPI版のTimesFMとGitHubメイン版では、内部のstate_dictキー名が異なる場合がある:
- PyPI版: `stacked_xf` キーを使用する可能性
- GitHub版: `stacked_transformer` キーを使用

**解決策**: v2.5 APIの `from_pretrained()` を使用すれば自動でキーが解決される。手動でチェックポイントをロードする場合は、`state_dict` のキー名を確認すること。

### `ModuleNotFoundError: No module named 'xreg_lib'`

共変量機能にはJAXが必要:
```shell
pip install jax jaxlib
```

### コンテキスト長エラー

- v1.0: `context_len` は最大512
- v2.0: `context_len` は最大2048（32の倍数で指定）
- v2.5: `max_context` は最大4096

### GPU推論の指定

```python
# v2.0/v1.0 API
model = TimesFM(backend="gpu")

# v2.5 API: 自動検出（CUDA利用可能なら自動でGPU使用）
```

### Windows環境の注意点

- **cp932 Unicode問題**: Pythonスクリプトの先頭に `# -*- coding: utf-8 -*-` を記述。`PYTHONIOENCODING=utf-8` 環境変数を設定
- **stdout バッファリング問題**: `PYTHONUNBUFFERED=1` を設定するか、`print(..., flush=True)` を使用
- **safetensors → torch_model.ckpt**: `from_pretrained()` を使用すれば自動変換される。手動の場合は `safetensors` パッケージでロードし `torch.save()` で変換

### Apple Silicon (ARM)

`lingvo` 依存で失敗する場合:
```shell
# Rosetta 2 経由
arch -x86_64 pip install timesfm[pax]

# または PyTorch 版を使用（推奨）
pip install timesfm[torch]
```

## ryokan-forecastプロジェクトでの使用

ryokan-forecastプロジェクトでの実際の設定:

- **モデル**: `google/timesfm-2.5-200m-pytorch`（v2.5 200M PyTorch版）
- **API**: v2.5 API（`TimesFM_2p5_200M_torch.from_pretrained()` + `ForecastConfig`）
- **推論環境**: CPU（GPUなし環境）
- **ForecastConfig設定**:
  - `max_context=512`
  - `max_horizon=128`
  - `normalize_inputs=True`
  - `use_continuous_quantile_head=True`
  - `infer_is_positive=True`（需要・売上データは非負）
  - `per_core_batch_size=1`
- **インストール**: `pip install "timesfm[torch] @ git+https://github.com/google-research/timesfm.git"`（PyPI版にはv2.5 APIが未収録のため）
- **参照**: `~/.claude/skills/ryokan-forecast/SKILL.md`
- **ソースコード**: `C:\Users\zooyo\Documents\GitHub\DX\ryokan-forecast\worker\forecast_engine.py`

## 改訂履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-07 | 初版作成: Context7公式ドキュメントから全セクション構築 |
