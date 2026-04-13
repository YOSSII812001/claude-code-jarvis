---
name: MarkItDown
description: |
  Microsoft MarkItDown を使用したファイル→Markdown変換。PDF, DOCX, PPTX, XLSX, 画像, 音声, HTML, Jupyter等19+形式対応。
  CLI・Python API・MCPサーバー・プラグインシステムを網羅。LLM連携OCR・Azure Document Intelligence対応。
  トリガー: "markitdown", "markdown変換", "ファイル変換", "PDFをMarkdownに", "ドキュメント変換",
  "DOCX変換", "PPTX変換", "Excel変換", "画像テキスト抽出", "OCR", "markitdown-mcp"
---

# MarkItDown スキル

## 概要
Microsoft MarkItDown は、様々なファイル形式を **構造を保持したMarkdown** に変換する Python ユーティリティ。
LLM・テキスト分析パイプラインでの前処理に最適。見出し・リスト・テーブル・リンクなどの文書構造を維持する。

- **リポジトリ**: https://github.com/microsoft/markitdown
- **ライセンス**: MIT
- **Python**: 3.10+
- **パッケージ**: PyPI `markitdown`

## インストール

```bash
# 全機能（推奨）
pip install 'markitdown[all]'

# 必要な機能のみ
pip install 'markitdown[pdf]'          # PDF
pip install 'markitdown[docx]'         # Word
pip install 'markitdown[pptx]'         # PowerPoint
pip install 'markitdown[xlsx]'         # Excel (.xlsx)
pip install 'markitdown[xls]'          # Excel (.xls旧形式)
pip install 'markitdown[pdf,docx,pptx]' # 複数指定可
pip install 'markitdown[outlook]'      # Outlook .msg
pip install 'markitdown[audio-transcription]'    # 音声文字起こし
pip install 'markitdown[youtube-transcription]'  # YouTube字幕
pip install 'markitdown[az-doc-intel]'           # Azure Document Intelligence

# MCP サーバー
pip install markitdown-mcp

# OCR プラグイン（LLM Vision使用）
pip install markitdown-ocr

# Docker
docker build -t markitdown:latest .
docker run --rm -i markitdown:latest < ~/your-file.pdf > output.md
```

## 対応ファイル形式（19+種）

| コンバータ | 対象形式 | 優先度 | 依存グループ |
|---|---|---|---|
| `PdfConverter` | PDF (.pdf) | 0.0 | `[pdf]` |
| `DocxConverter` | Word (.docx) | 0.0 | `[docx]` |
| `PptxConverter` | PowerPoint (.pptx) | 0.0 | `[pptx]` |
| `XlsxConverter` | Excel (.xlsx) | 0.0 | `[xlsx]` |
| `XlsConverter` | Excel (.xls) | 0.0 | `[xls]` |
| `ImageConverter` | 画像 (.jpg, .png等) | 0.0 | EXIF+LLM |
| `AudioConverter` | 音声 (.wav, .mp3, .m4a) | 0.0 | `[audio-transcription]` |
| `EpubConverter` | 電子書籍 (.epub) | 0.0 | 組み込み |
| `OutlookMsgConverter` | Outlook (.msg) | 0.0 | `[outlook]` |
| `CsvConverter` | CSV (.csv) | 0.0 | 組み込み |
| `IpynbConverter` | Jupyter (.ipynb) | 0.0 | 組み込み |
| `YouTubeConverter` | YouTube URL | 0.0 | `[youtube-transcription]` |
| `WikipediaConverter` | Wikipedia URL | 0.0 | 組み込み |
| `RssConverter` | RSS/Atom (.xml) | 0.0 | 組み込み |
| `BingSerpConverter` | Bing検索結果 | 0.0 | 組み込み |
| `DocumentIntelligenceConverter` | Azure AI全形式 | 0.0 | `[az-doc-intel]` |
| `HtmlConverter` | HTML (.html, .htm) | 10.0 | 組み込み |
| `ZipConverter` | ZIP (.zip) | 10.0 | 組み込み（再帰変換） |
| `PlainTextConverter` | テキスト (text/*) | 10.0 | 組み込み |

**優先度**: 0.0（専用コンバータ）が先に試行 → 10.0（汎用）がフォールバック

## CLI 使用方法

### 基本

```bash
markitdown test.pdf                     # stdout出力
markitdown test.pdf -o output.md        # ファイル出力
markitdown test.pdf > output.md         # リダイレクト
cat test.pdf | markitdown               # パイプ入力
markitdown < test.pdf                   # stdin入力
```

### 全オプション

| オプション | 短縮 | 説明 |
|---|---|---|
| `--version` | `-v` | バージョン表示 |
| `--output FILE` | `-o` | 出力ファイル指定 |
| `--extension EXT` | `-x` | 拡張子ヒント（stdin時に有用） |
| `--mime-type TYPE` | `-m` | MIMEタイプヒント |
| `--charset CHARSET` | `-c` | 文字コードヒント |
| `--use-docintel` | `-d` | Azure Document Intelligence使用 |
| `--endpoint URL` | `-e` | Doc Intelエンドポイント（`-d`時必須） |
| `--use-plugins` | `-p` | プラグイン有効化 |
| `--list-plugins` | | プラグイン一覧表示 |
| `--keep-data-uris` | | base64画像等のdata URIを保持 |

### 実用例

```bash
# PDF → Markdown
markitdown report.pdf -o report.md

# stdin + 拡張子ヒント
cat document | markitdown -x .docx > out.md

# Azure Document Intelligence（スキャンPDF等に有効）
markitdown scanned.pdf -o doc.md -d -e "https://your-instance.cognitiveservices.azure.com"

# プラグイン付き
markitdown scanned.pdf -p -o doc.md

# インストール済みプラグイン確認
markitdown --list-plugins
```

## Python API

### 基本

```python
from markitdown import MarkItDown

md = MarkItDown()
result = md.convert("test.xlsx")
print(result.markdown)    # 変換されたMarkdown
print(result.title)       # ドキュメントタイトル（あれば）
```

### MarkItDown コンストラクタ

```python
MarkItDown(
    *,
    enable_builtins=None,       # bool: 組み込みコンバータ（デフォルトTrue）
    enable_plugins=None,        # bool: プラグイン（デフォルトFalse）
    llm_client=None,            # OpenAI互換クライアント（画像説明・OCR用）
    llm_model=None,             # str: モデル名（例: "gpt-4o"）
    llm_prompt=None,            # str: カスタムプロンプト
    exiftool_path=None,         # str: exiftoolパス
    style_map=None,             # str: mammoth style_map（DOCX用）
    requests_session=None,      # requests.Session: カスタムHTTPセッション
    docintel_endpoint=None,     # str: Azure Doc Intelエンドポイント
    docintel_credential=None,   # Azure Doc Intel認証情報
    docintel_file_types=None,   # Doc Intel対象ファイルタイプ
    docintel_api_version=None,  # str: Doc Intel APIバージョン
)
```

### convert() メソッド

```python
# ローカルファイル
result = md.convert("path/to/file.pdf")

# URL
result = md.convert("https://example.com/document.pdf")

# Wikipedia
result = md.convert("https://en.wikipedia.org/wiki/Python_(programming_language)")

# pathlib.Path
from pathlib import Path
result = md.convert(Path("file.docx"))

# requests.Response
import requests
resp = requests.get("https://example.com/file.pdf")
result = md.convert(resp)

# バイナリストリーム（※TextIOは不可、BinaryIOのみ）
from markitdown import StreamInfo
with open("file.pdf", "rb") as f:
    result = md.convert_stream(f, stream_info=StreamInfo(extension=".pdf"))
```

### 戻り値: DocumentConverterResult

```python
result.markdown       # str: 変換されたMarkdown
result.title          # str | None: ドキュメントタイトル
result.text_content   # str: markdown のソフト非推奨エイリアス
str(result)           # markdown と同じ
```

### StreamInfo（ヒント情報）

```python
from markitdown import StreamInfo

info = StreamInfo(
    mimetype="application/pdf",   # MIMEタイプ
    extension=".pdf",             # 拡張子
    charset="utf-8",              # 文字コード
    filename="report.pdf",        # ファイル名
    local_path="/path/to/file",   # ローカルパス
    url="https://...",            # URL
)
```

### LLM連携（画像説明・OCR）

```python
from markitdown import MarkItDown
from openai import OpenAI

client = OpenAI()
md = MarkItDown(
    llm_client=client,
    llm_model="gpt-4o",
    llm_prompt="Describe this image in detail.",  # オプション
)
result = md.convert("photo.jpg")
```

### OCRプラグイン（スキャンPDF対応）

```python
from markitdown import MarkItDown
from openai import OpenAI

md = MarkItDown(
    enable_plugins=True,
    llm_client=OpenAI(),
    llm_model="gpt-4o",
)
result = md.convert("scanned_document.pdf")
# スキャンPDFのテキスト無しページを自動検出 → 300DPIレンダリング → LLM OCR
# 出力: *[Image OCR] ... [End OCR]*
```

### Azure Document Intelligence

```python
from markitdown import MarkItDown

md = MarkItDown(docintel_endpoint="https://your-instance.cognitiveservices.azure.com")
result = md.convert("complex_table.pdf")
```

## カスタムコンバータ作成

```python
from markitdown import (
    MarkItDown,
    DocumentConverter,
    DocumentConverterResult,
    StreamInfo,
    PRIORITY_SPECIFIC_FILE_FORMAT,  # == 0.0
    PRIORITY_GENERIC_FILE_FORMAT,   # == 10.0
)

class MyFormatConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info, **kwargs):
        """処理可能か判定（stream位置をリセットすること）"""
        return (stream_info.extension or "").lower() == ".myext"
    
    def convert(self, file_stream, stream_info, **kwargs):
        """Markdownに変換"""
        data = file_stream.read().decode("utf-8")
        return DocumentConverterResult(
            markdown=f"# Converted\n\n{data}",
            title="My Document",
        )

md = MarkItDown()
md.register_converter(MyFormatConverter(), priority=PRIORITY_SPECIFIC_FILE_FORMAT)
result = md.convert("data.myext")
```

## プラグインシステム

### プラグインの作り方

1. `DocumentConverter` を継承してコンバータ実装
2. `register_converters(markitdown, **kwargs)` 関数をエクスポート
3. `__plugin_interface_version__ = 1` を設定
4. `pyproject.toml` にentry_points登録:

```toml
[project.entry-points."markitdown.plugin"]
my_plugin = "my_package_name"
```

### プラグイン例（register_converters）

```python
# my_plugin/__init__.py
__plugin_interface_version__ = 1

def register_converters(markitdown, **kwargs):
    markitdown.register_converter(
        MyConverter(**kwargs),
        priority=-1.0,  # 組み込みより先に試行
    )
```

### 公式プラグイン
- `markitdown-sample-plugin`: RTFファイル変換サンプル
- `markitdown-ocr`: PDF/DOCX/PPTX/XLSX内画像のLLM Vision OCR

### プラグイン検索
GitHubで `#markitdown-plugin` ハッシュタグ検索

## MCP サーバー (markitdown-mcp)

### インストール・起動

```bash
pip install markitdown-mcp

# STDIO モード（Claude Desktop等）
markitdown-mcp

# HTTP モード
markitdown-mcp --http --host 127.0.0.1 --port 3001
# HTTP: /mcp, SSE: /sse
```

### 提供ツール

`convert_to_markdown(uri: str) -> str`
- `http:`, `https:`, `file:`, `data:` URI対応

### Claude Desktop 設定

```json
{
  "mcpServers": {
    "markitdown": {
      "command": "markitdown-mcp"
    }
  }
}
```

Docker + ローカルファイルアクセス:
```json
{
  "mcpServers": {
    "markitdown": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "-v", "/home/user/data:/workdir", "markitdown-mcp:latest"]
    }
  }
}
```

### 環境変数
- `MARKITDOWN_ENABLE_PLUGINS=true`: MCPサーバーでプラグイン有効化
- `EXIFTOOL_PATH`: exiftoolパス指定

### セキュリティ
- 認証なし、ユーザー権限で実行
- localhost以外へのバインド非推奨
- ローカル利用専用設計

## 例外クラス

| 例外 | 用途 |
|---|---|
| `MarkItDownException` | 基底例外 |
| `MissingDependencyException` | オプション依存未インストール |
| `UnsupportedFormatException` | 対応コンバータなし |
| `FileConversionException` | 変換失敗 |
| `FailedConversionAttempt` | 個別試行の失敗情報（例外ではない） |

## 実践パターン

### バッチ変換

```python
from markitdown import MarkItDown, UnsupportedFormatException
from pathlib import Path

md = MarkItDown()
for file in Path("docs/").glob("**/*"):
    if file.is_file():
        try:
            result = md.convert(file)
            output = file.with_suffix(".md")
            output.write_text(result.markdown, encoding="utf-8")
            print(f"OK: {file}")
        except UnsupportedFormatException:
            print(f"SKIP: {file} (未対応形式)")
        except Exception as e:
            print(f"FAIL: {file} ({e})")
```

### LLMパイプライン前処理

```python
from markitdown import MarkItDown

md = MarkItDown()
result = md.convert("quarterly_report.pdf")

# LLMに渡す
messages = [
    {"role": "system", "content": "以下のドキュメントを分析してください。"},
    {"role": "user", "content": result.markdown},
]
```

### URL → Markdown（Webページ取得）

```python
md = MarkItDown()
# Cloudflare等のMarkdown for Agents対応サーバーからMD優先取得
# Accept: text/markdown, text/html;q=0.9, text/plain;q=0.8, */*;q=0.1
result = md.convert("https://example.com/article")
```

## 破壊的変更メモ（0.0.x → 0.1.x）

1. 依存がオプショングループに分離 → `pip install 'markitdown[all]'` で旧互換
2. `convert_stream()` は **BinaryIO必須**（`io.StringIO` 不可）
3. `DocumentConverter` がストリームベースに変更（一時ファイル不要）
4. `register_page_converter()` 非推奨 → `register_converter()` 使用
5. `text_content` ソフト非推奨 → `markdown` プロパティ使用

## Claude Codeでの活用パターン

### ファイル内容読み取り（Read不可時の代替）
```bash
# PDFやDOCXなどバイナリファイルの内容確認
markitdown document.pdf
markitdown presentation.pptx -o /tmp/content.md
```

### コードベースドキュメント変換
```bash
# Jupyter Notebookの内容確認
markitdown analysis.ipynb

# Excel仕様書のMarkdown化
markitdown spec.xlsx -o spec.md
```

### Webページ内容取得
```python
from markitdown import MarkItDown
md = MarkItDown()
result = md.convert("https://docs.example.com/api-reference")
print(result.markdown)
```
