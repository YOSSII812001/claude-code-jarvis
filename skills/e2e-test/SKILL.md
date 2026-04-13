---
name: e2e-test
description: |
  E2Eテストの計画・実行・検証プロセス。JSONテスト計画とゲートチェックで品質を機械的に保証。
  トリガー: "E2Eテスト", "e2e test", "ブラウザテスト", "動作確認", "テスト実行",
  "修正確認", "画面テスト", "SP確認", "レスポンシブ確認",
  "CLIテスト", "パッケージテスト", "APIテスト", "npm pack確認", "コマンド実行確認"
  使用場面: (1) コード修正後の動作確認、(2) 複数画面にまたがる変更のテスト、
  (3) レスポンシブ対応の確認、(4) リリース前の最終確認、
  (5) CLIパッケージの動作検証、(6) APIエンドポイントの結合テスト
---

# E2Eテスト計画・実行スキル

> テスト計画→実行→ゲート検証の3フェーズ。ルール追加ではなく構造で品質を機械的に保証する。

### E2Eテストの定義（Issue #1588教訓）
**E2Eテストとは、Playwrightで実際のUI操作を行い、修正対象の機能を直接操作すること。** コード検証（Lint/型チェック/ビルド/コードレビュー）のみではE2Eと呼ばない。コード検証はE2Eの前提条件であり、E2E自体ではない。

---

## テストモード

テスト対象の種類に応じてモードを選択する。Phase 0 / Phase 2 の手順がモードにより分岐する。

| モード | 対象 | Phase 2 の実行手段 |
|--------|------|-------------------|
| `browser` | Webアプリ画面 | Playwright MCP（browser_navigate, browser_click等） |
| `cli` | CLIパッケージ | `npm pack` → `npm install -g` → コマンド実行 → 出力検証 |
| `api` | APIエンドポイント | `curl` / `fetch` → レスポンス検証 |

---

## 絶対ルール（5項目）

| # | ルール | 機械的検証 |
|---|--------|-----------|
| R1 | テスト計画JSONの全itemにPASS/FAIL/SKIPが記録されるまで完了としない。SKIPにはskip_reason必須 | `items.every(i => i.result !== null)` |
| R2 | Issue起点の場合、Issue本文のユーザー操作をL2深度で再現する。表示確認(L1)のみで完了としない | `issue_ref && items.some(i => i.depth === "L2")` |
| R3 | テスト実行前にJSONテスト計画を作成し、Issue本文を埋め込み、目的を復唱する | `plan.purpose !== "" && plan.issue_body !== null` |
| R4 | 全テスト完了後、「ユーザーとしてこの成果物を渡されて目的を達成できるか？」を自問し回答を記録する | `plan.user_perspective_check !== null` |
| R5 | テスト実行順序は「L2核心テスト → L1概要テスト」の順。L1を先に実施してはならない（完了感バイアス防止、5回再発教訓: #986/#1000/#1056/#1071/#1084） | `items.findIndex(i => i.depth === "L2") < items.findIndex(i => i.depth === "L1")` |

---

## JSONテスト計画スキーマ（e2e-test-plan-v2）

```json
{
  "$schema": "e2e-test-plan-v2",
  "mode": "browser | cli | api",
  "issue_ref": "#1074 | null",
  "issue_body": "gh issue view で取得した本文 | null",
  "purpose": "このテストで検証したいこと（1文）",
  "pass_criteria": "合格基準（測定可能な形で記述）",
  "critical_point": "最重要検証ポイント",
  "smoke_test_passed": false,
  "user_perspective_check": null,
  "confidence_gate": null,
  "items": [
    {
      "id": 1,
      "screen": "画面/コンポーネント/コマンド名",
      "changed_files": ["path/to/file.tsx"],
      "depth": "L1 | L2",
      "operation_flow": "開始条件 → 手順(2+アクション) → 期待結果",
      "method": "direct | scenario | mock | trigger | shell | curl",
      "priority": "high | medium",
      "acceptance_criteria": "対応する受け入れ条件（例: AC-1, AC-2）| null",
      "expected_errors": "想定されるエラーパターン（例: タイムアウト、認証切れ）| null",
      "result": null,
      "evidence": null,
      "skip_reason": null,
      "defect_class": null
    }
  ]
}
```

**v1→v2 変更点**: `mode`, `smoke_test_passed`, `user_perspective_check` をトップレベルに追加。items に `defect_class` を追加。`method` に `shell`（CLI実行）, `curl`（API呼び出し）を追加。

**evidenceフィールドの記載指針:**
- スクリーンショットだけでなく、**操作ログ**（何をクリック/入力/確認したか）を含めること
- 形式例: `"evidence": "ダッシュボード→設定アイコンクリック→スライダー50→80に変更→保存→リロード→80表示確認 + screenshot-1.png"`
- 「PASS」だけで操作詳細が不明な報告は、リーダーが再テストを要求する根拠になる

---

## ゲートチェック（10項目 — Phase 3 で実行）

```
GATE_CHECK(plan):
  1. plan.purpose が空文字 → BLOCK("目的未記述")
  2. plan.issue_ref が非null かつ plan.issue_body が null → BLOCK("Issue本文未取得")
  3. items のうち result が null → BLOCK("未実行項目あり: {ids}")
  4. items のうち result="SKIP" かつ skip_reason が null → BLOCK("SKIP理由なし: {ids}")
  5. priority="high" かつ depth="L1" → BLOCK("高優先度にL2テストなし: {ids}")
  6. issue_ref が非null かつ items に depth="L2" が0件 → BLOCK("Issue起点なのにL2なし")
  7. items のうち result="FAIL" かつ defect_class が null → BLOCK("FAIL分類なし: {ids}")
  8. plan.user_perspective_check が null → BLOCK("ユーザー視点チェック未実施")
  9. plan.confidence_gate が null → BLOCK("自信ゲート未実施")
  9b. confidence_gate のいずれかの evidence_ref が null/空 → BLOCK("証跡未添付: {keys}")
  10. items のうち acceptance_criteria が非null の数が 0 かつ issue_ref が非null → BLOCK("受け入れ条件マッピングなし")
  ALL PASS → COMPLETE
```

---

## 欠陥分類（FAIL時に必須）

テスト項目がFAILとなった場合、`defect_class` に以下のいずれかを記録する。

| 種別 | 判定方法 | 対応 |
|------|---------|------|
| **REQUIREMENT** | 修正対象が未修正 | 自動修正 → 再テスト |
| **REGRESSION** | git diffと失敗画面が関連 | revert検討 + 新規Issue起票 |
| **PRE-EXISTING** | git diffと失敗画面が無関連 | 新規Issue起票 → PASS扱いで続行 |
| **FLAKY-INFRA** | デプロイ失敗、タイムアウト | 60秒待機 → リトライ |

**重要**: PRE-EXISTINGは「バッチの変更とは無関係」だが「テストのブロッカー」になり得る。発見即Issue起票。

---

## テスト深度レベル

| レベル | 名称 | 内容 | 合格基準 |
|--------|------|------|---------|
| L1 | 概要テスト | ページ表示確認・コンソールエラー0件・基本ナビゲーション | **必要だが不十分** |
| L2 | 深度テスト | 修正対象の実操作・データ生成/保存/表示フロー・状態変更の往復確認 | **合格に必須** |

**深度判定**: UI表示のみ(CSS/文言)→L1+L2、フォーム/入力系→L2必須、バックエンド処理→L2必須、状態管理→L2必須（往復テスト）

---

## Phase 0: スモークテスト（Phase 1 の前に必須実行）

テスト対象が「そもそも起動・応答するか」を確認する。スモークテストFAILの場合、Phase 1以降に進まない。

| モード | スモークテスト手順 | 合格基準 |
|--------|------------------|---------|
| `browser` | デプロイURLにアクセスし、ページが表示される | HTTP 200 + コンテンツ表示 |
| `cli` | `command --help` を実行し、正常な出力が返る | ヘルプテキストが標準出力に表示 |
| `api` | ヘルスチェックエンドポイントにリクエスト | HTTP 200 + 期待レスポンス |

- [ ] スモークテスト実行
- [ ] `smoke_test_passed` を `true` に更新

**CLIスモークテストの完全手順:**
```bash
# 1. パッケージ作成
npm pack

# 2. グローバルインストール
npm install -g ./package-name-1.0.0.tgz

# 3. コマンド実行
command-name --help    # ヘルプが表示されること
command-name --version # バージョンが表示されること
```

> **教訓**: ビルド成功 + ユニットテストPASS ≠ ユーザーが使える。`--help` で何も出ない CLI は出荷不可。

---

## Phase 1: テスト計画

### 1.1 Issue再読 + 実装計画のE2E受け入れ条件取得（Issue起点の場合、必須）

```bash
# Issue本文を取得
gh issue view <番号> --json title,body

# 実装計画コメントからE2E受け入れ条件を取得（planned ラベル付きIssueの場合）
gh issue view <番号> --json comments --jq '.comments[].body' | grep -A 50 '### E2E受け入れ条件'
```
- [ ] Issueの再現手順・要望を再確認
- [ ] 「本番ユーザーが実際に行う操作フロー」を抽出
- [ ] 「表示確認のみ」でE2E完了としない — データ生成・状態変更・保存を伴う操作を含めること
- **実装計画にE2E受け入れ条件がある場合**: テーブルの各行をJSON計画 `items` に直接マッピング
- **E2E受け入れ条件がない場合**: Issue本文とgit diffから独自にテスト計画を生成

### 1.2 影響範囲マッピング

- [ ] `git diff` で変更ファイル一覧を取得
- [ ] 各変更ファイルが影響する画面/コマンド/エンドポイントを特定
- [ ] インポート元（親コンポーネント）も含めて影響範囲を確認

### 1.2.5 Playwright MCP制約の事前確認（browserモード必須）

テスト手順設計前に、Playwright MCPで操作可能な範囲を確認する。制約に抵触する操作がある場合、代替手段を計画に含める。

| 制約領域 | 制約内容 | 代替手段 | E2E報告義務 |
|----------|---------|---------|------------|
| 新タブ/ポップアップ | `openInNewTab: true` のリンクは元タブのURLも変わる場合がある | `browser_evaluate` でhrefを取得し、同一タブで `browser_navigate` | — |
| ダイアログ | `window.confirm` / `window.alert` はMCPから直接操作困難 | `browser_handle_dialog` で事前にハンドラ設定 | — |
| ファイルダウンロード | `blob URL + <a download> + link.click()` のファイルOS保存はMCP検証不能（ブラウザ外操作） | **MCP**: `browser_evaluate` + `browser_network_requests` でBlob URL生成・Content-Type・Content-Disposition・HTTP 200を検証。**APIレベル（推奨）**: `browser_evaluate` 内で `fetch(apiUrl)` → ステータスコード・Content-Type・レスポンスサイズを直接検証（SKIPせず必ず実施）。**CLI（より確実）**: `playwright-cli run-code` で `waitForEvent('download')` + `saveAs()` | `test_items[].browser_boundary` に制約を記載**必須** |
| iframe | 異なるオリジンのiframe内操作は制限あり | `browser_evaluate` でiframe contentDocumentにアクセス | — |

- [ ] テスト計画の各operation_flowにPlaywright MCPで操作不可能な手順がないか確認した
- [ ] 制約に抵触する場合、代替手段をoperation_flowに反映した
- [ ] 核心テスト（priority: high）の手順は特に注意深く検証した

> **教訓（Issue #1084）**: 新タブ遷移を含む核心テストで、Playwright MCPが新タブ制御に失敗し、テストが検証不能のままPASS扱いになった。

> **教訓（Issue #1596）**: Playwright MCPでBlobダウンロードのネットワークレスポンス（200 OK, Content-Disposition）を確認してPASS判定したが、ファイルOS保存は検証できていなかった。制約に抵触するテストでPASS判定する場合、`test_items[].browser_boundary` に検証範囲の限界を明記する義務がある。

### 1.2.7 変更箇所×テスト対応マッピング検証（必須）

git diffの各変更ファイルに対応するテスト項目が存在するかを検証する。

- [ ] `git diff --name-only` で変更ファイル一覧を取得
- [ ] 各ファイルを以下に分類:
  - **要テスト（user_facing）**: ユーザー操作・データフロー・API応答に影響する変更 → テスト項目必須
  - **テスト免除（observability_only）**: ログ/監視/型/コメントのみの変更 → テスト項目不要（ユーザー影響が1つでもあれば user_facing）
- [ ] 要テスト分類のファイルに対応する `items[].changed_files` が1つ以上存在することを確認
- [ ] **未カバーのファイルが存在する場合、テスト項目を追加してからPhase 1.3へ進む**

> **教訓（Issue #1534）**: 7/7 PASSだが変更6ファイル中3箇所（ファイル添付・非ストリーミング経路・Web検索）が未テスト。「テスト通過数」ではなく「変更箇所×テスト対応マッピング」で評価すべき。

### 1.3 JSON計画作成

上記スキーマ（e2e-test-plan-v2）に従いテスト計画JSONを作成する。

- [ ] `mode` を設定（browser / cli / api）
- [ ] 高優先度の項目は `depth: "L2"` 必須
- [ ] Issue起点の場合、再現手順に基づくoperation_flowは必須
- [ ] 各operation_flowの3要素: **開始条件** → **手順(2+アクション)** → **期待結果**
- [ ] 各itemの `acceptance_criteria` にE2E受け入れ条件の対応行（AC-1等）をマッピング
- [ ] 各itemの `expected_errors` に想定されるエラーパターンを記入（タイムアウト、認証切れ、ネットワークエラー等）

**methodの選択:**
| モード | 利用可能なmethod |
|--------|----------------|
| browser | direct, scenario, mock, trigger |
| cli | shell |
| api | curl |

### 1.4 目的復唱（必須）

- [ ] purpose, pass_criteria, critical_point を出力し整合性確認

```markdown
### E2Eテスト目的の確認
- **目的**: {purpose}
- **合格基準**: {pass_criteria}
- **最重要検証ポイント**: {critical_point}
```

### 1.5 ユーザー確認

- [ ] テスト計画をユーザーに提示し承認を得る
**重要: ユーザーの明示的な承認なしにテスト実行を開始してはならない。**

---

## Phase 2: テスト実行

### 2.1 デプロイ反映検証（browser/apiモード、E2Eテスト開始前必須）

- [ ] テスト対象にアクセスし、修正が反映されていることを確認
- [ ] 不一致の場合: 60秒待機→再確認。2回不一致ならデプロイ反映問題として報告

**browserモード:**
```javascript
// browser_evaluate で修正対象要素のDOM属性を直接取得
(element) => ({
  disabled: element.disabled,
  className: element.className,
  textContent: element.textContent?.trim()
})
```

### 2.1.5: 実行順序の強制（完了感バイアス防止）

**実行順序**: L2（核心テスト）→ L1（概要テスト）の順で実施する。

| 順序 | 対象 | 理由 |
|------|------|------|
| 1st | L2: 修正対象操作の直接テスト | 最も重要。先に実施しないと「もう十分」バイアスで省略される |
| 2nd | L2: データ保存・状態変更の往復検証 | 表示だけでなくDB反映を確認 |
| 3rd | L1: ページ表示・エラー0件確認 | 最も簡単だが最も価値が低い。最後に実施 |

> **自問チェック**: 「今からやろうとしているテストは、修正対象を直接操作するL2か？ まだL2を全て完了していないのにL1に逃げていないか？」

### 2.2 テスト実行（JSON計画に従う）

**核心テスト優先実行**: 修正の核心に関わるL2テスト項目を最初に実行する。

#### browserモード
- [ ] UI操作で画面にアクセス（URL直打ち禁止、初回ログインのみ許可）
- [ ] operation_flowに従い操作を実行
- [ ] 入力欄テスト（該当する場合、下記サブセクション参照）
- [ ] スクリーンショットで証跡を記録
- [ ] コンソールエラー確認: `browser_console_messages(level: "error")`

#### 入力欄テスト（browserモード、UI入力欄を含む場合は必須）

- [ ] `Shift+Enter` での改行可否を確認（テキストエリアの場合）
- [ ] 2行目以降の左端揃え（インデント崩れがないか）
- [ ] IME（日本語入力）確定時の挙動（二重入力・未確定文字の消失がないか）
- [ ] 長文入力時のスクロール・レイアウト維持

#### cliモード
- [ ] コマンドを実行し、終了コードと出力を記録
- [ ] エラー出力（stderr）がないことを確認
- [ ] 期待する出力が含まれていることを検証
- [ ] 異常入力時のエラーハンドリングを確認

```bash
# CLI テスト実行パターン
command-name subcommand --option value  # 正常系
command-name invalid-input 2>&1         # 異常系（エラーメッセージ確認）
echo $?                                 # 終了コード確認
```

#### apiモード
- [ ] エンドポイントにリクエストを送信
- [ ] ステータスコードとレスポンスボディを検証
- [ ] エラーケースのレスポンスを確認

**コードパス整合性検証（直接テスト困難なシナリオの代替手段）:**
長時間タイムアウト（300秒超）、外部サービス障害、レート制限等、staging環境で直接再現が困難なシナリオでは、`browser_evaluate` でビルド済みバンドルを検査し、コードパスの整合性を検証できる。ただし、直接テストが不可能な理由を明示した上で適用すること。

```javascript
// browser_evaluate でバンドル検査の例（#1679 タイムアウトテスト）
() => {
  const scripts = Array.from(document.querySelectorAll('script[src]'));
  // 1. 対象関数の存在確認（isStreamTimeoutError 等）
  // 2. エラーコード判定ロジックの存在（HTTP 408 + STREAM_TIMEOUT）
  // 3. エラーメッセージ文字列の存在
  // 4. バックエンド↔フロントエンドのインターフェース整合性
}
```

> **教訓（#1679）**: 直接テスト不可→SKIPではなく、コードパス整合性検証で代替。最初から選ぶのではなく、直接テスト不可の理由を明示してから適用する。

**状態変更テストの往復検証（全モード共通）:**
変更→確認→元に戻す→確認の往復テスト。3状態でエビデンス記録。

**snapshot vs screenshot 使い分け（browserモード）:**
- 大量DOM要素の画面 → `browser_take_screenshot`（snapshotが50K〜82K文字に達する）
- DOM要素が少ない画面 → `browser_snapshot` が効率的

| 画面例 | 推奨手法 | 理由 |
|--------|---------|------|
| チャットドロワー | `browser_take_screenshot` | メッセージDOMが50K〜82K文字に達しコンテキスト圧迫 |
| ダッシュボード | `browser_snapshot` | DOM要素が少なく効率的 |
| 設定画面 | `browser_snapshot` | フォーム要素中心で軽量 |

### 2.3 FAIL/SKIPの記録

- [ ] FAIL → `defect_class` を必ず記録（REQUIREMENT / REGRESSION / PRE-EXISTING / FLAKY-INFRA）
- [ ] SKIP → `skip_reason` を記録（具体的理由必須）
- **コスト削減・時間短縮・「たぶん大丈夫」はスキップ理由として不可**

---

## Phase 3: ゲート検証

### 3.1 ゲートチェック実行

- [ ] 上記10項目のゲートチェックを全項目実行
- [ ] BLOCKがあれば対処してから再チェック

### 3.2 BLOCK対処

| BLOCK | 対処 |
|-------|------|
| 目的未記述 | purpose を記入 |
| Issue本文未取得 | `gh issue view` で取得して埋め込み |
| 未実行項目あり | 該当itemを実行、またはSKIP+理由を記入 |
| SKIP理由なし | skip_reason を記入 |
| 高優先度にL2テストなし | L2テストを追加実行 |
| Issue起点なのにL2なし | Issue操作フローのL2テストを追加 |
| FAIL分類なし | defect_class を記入 |
| ユーザー視点チェック未実施 | user_perspective_check に回答を記録 |
| 自信ゲート未実施 | confidence_gate の6問に全回答を記録 |
| 証跡未添付 | confidence_gate の該当Cにevidence_refを記入（テスト項目のevidenceを参照） |

### 3.3 ユーザー視点チェック（R4）

- [ ] 「この成果物をユーザーに渡して、目的を達成できるか？」を自問
- [ ] 回答を `user_perspective_check` に記録（自由記述）

### 3.4 Evidence Gate（証跡ベース自己検証 — 省略不可）

テスト結果を報告する**前に**、以下6問に回答し、**各項目にevidence_ref（証跡参照）を添付する**。
1つでも「いいえ」→ 該当テストを追加実行。evidence_refが空 → 証跡をitemsのevidenceに追記してから再回答する。

| # | 自問 | 検出する漏れパターン |
|---|------|---------------------|
| C1 | 修正対象の機能を**直接操作**したか？（回帰テスト+デプロイ確認だけで逃げていないか？） | 表示確認だけで済ませた（#1071, #1322）、回帰テスト+デプロイ確認のみでPASS判定（#1679, #1682） |
| C2 | ユーザーとしてこのアプリ/CLIを渡されて**使えるか**？ | ビルド成功≠動作する（#1305-#1307） |
| C3 | テスト計画の**全項目**にPASS/FAIL/SKIPが記入されているか？ | 未消化項目の放置（#1084） |
| C4 | 「ビルド成功」「ユニットテスト通過」だけで判断していないか？**Playwright MCP制約で未検証の操作がないか？** | 実動作未確認（#14）、MCP制約無視のPASS判定（#1596） |
| C5 | 修正前に**壊れていた操作**が修正後に**正しく動く**ことを確認したか？ | リグレッション未検証（#1133） |
| C6 | 受け入れ条件の**全項目**にテスト結果が紐付いているか？ | 受け入れ条件のカバレッジ漏れ |

回答は `confidence_gate` に記録。**各項目にevidence_ref（テスト項目のevidenceへの参照）を必須添付する**:

```json
"confidence_gate": {
  "C1": { "answer": "はい", "evidence_ref": "T2のevidence参照 — ボタンクリック→状態変化確認" },
  "C2": { "answer": "はい", "evidence_ref": "T1-T5の操作ログ — login→操作→結果確認フロー" },
  "C3": { "answer": "はい", "evidence_ref": "T1〜T5全てにPASS+evidence記入済み" },
  "C4": { "answer": "はい", "evidence_ref": "T1のevidence参照 — Playwright MCP制約なし" },
  "C5": { "answer": "はい", "evidence_ref": "T3のevidence参照 — 修正前バグが再現しないことを確認" },
  "C6": { "answer": "はい", "evidence_ref": "AC-1→T1, AC-2→T3 紐付け済み" }
}
```

> **背景**: 過去5回のE2E品質不足（#1071, #1084, #1133, #1305-7, #1322）は全てC1で検出可能だったが、
> 自己申告の「はい」だけでは形骸化が不可避だった。evidence_refの必須化により証跡なき合格を構造的に排除する。
> Usacon環境では、E2E完了後に敵対的E2E監査（別サブエージェント）がこの証跡を第三者検証する。

### 3.5 最終JSON出力

全ゲートPASS後、完成したテスト計画JSONを最終結果として出力。

---

## トラブルシューティング

| 症状 | モード | 対処 |
|------|--------|------|
| デプロイ後もDOM属性が古い | browser | 60秒待機→再確認。2回失敗でデプロイ反映問題として報告 |
| モックAPIが効かない | browser | ワイルドカード `**` 確認。Network タブで実URL確認 |
| スクリーンショットが真っ白 | browser | `browser_wait_for` でコンテンツ表示を待つ |
| ログインセッション切れ | browser | 再ログインしてからテスト続行 |
| snapshot で要素が見つからない | browser | `browser_wait_for` で出現を待つ。SPA はルート遷移後に再度 snapshot |
| browser_evaluate でエラー | browser | snapshot を再取得して最新の ref を使用 |
| レスポンシブテストで表示崩れ | browser | `browser_resize` 後にリロードしてから確認 |
| `--help` で何も出力されない | cli | エントリポイント確認: `index.ts`で`run()`がモジュールレベルで呼ばれているか |
| `npm install -g` 後にコマンド未登録 | cli | `package.json` の `bin` フィールドとビルド出力パスの整合を確認 |
| 認証エラーでCLI操作不能 | cli | 環境変数（API Key等）の設定確認。PRE-EXISTING問題の可能性を疑う |
| APIレスポンスが空 | api | リクエストヘッダー（Content-Type, Authorization）を確認 |

---

## 関連スキル

- `playwright` - Playwright MCPプラグインによるブラウザ操作
- `usacon` - Usacon固有のE2E品質基準は `usacon/references/e2e-quality.md` 参照
- `issue-autopilot-batch` - 欠陥分類（4種別）の詳細定義は `references/e2e-defect-classification.md` 参照

## 改訂履歴

| 日付 | 変更内容 | 変更理由 |
|------|---------|---------|
| 2026-03-03 | 初版作成 | Issue #1074 |
| 2026-03-04〜09 | 絶対ルール追加、テスト深度レベル追加、アンチパターン追加 | 運用フィードバック |
| 2026-03-09 | **v2.0 全面書き換え** — 絶対ルール8→3に圧縮、JSONテスト計画スキーマ導入、6項目ゲートチェック | 構造で品質を保証する方式に転換 |
| 2026-03-11 | **v2.1 テストモード・欠陥分類・スモークテスト追加** — テストモード概念（browser/cli/api）導入、Phase 0（スモークテスト）新設、欠陥分類4種別統合、R4（ユーザー視点チェック）追加、ゲートチェック6→8項目 | CLI改善バッチ #1305-#1307 の教訓反映（ビルド成功≠使える、PRE-EXISTING分類、ユーザー視点自問） |
| 2026-03-11 | **v2.2 自信ゲート追加** — ゲートチェック9番目に `confidence_gate`（5問の自己検証）を追加。Phase 3.4に詳細手順・回答例・背景を記載 | 過去5回のE2E品質不足（#1071, #1084, #1133, #1305-7, #1322）がユーザーの「自信ある？」で初めて発覚するパターンを構造的に解消 |
| 2026-03-17 | **v2.3 受け入れ条件・入力欄テスト・自信ゲート強化** — JSONスキーマにacceptance_criteria/expected_errorsフィールド追加、入力欄テスト必須項目追加（Shift+Enter・IME・長文）、自信ゲートC6追加（受け入れ条件カバレッジ）、ゲートチェック10項目化 | skill-improve バッチ改善（テスト品質の構造的強化） |
| 2026-03-23 | **v2.4 教訓棚卸し** — Phase 1にPlaywright MCP制約事前確認(1.2.5)追加、evidence操作ログ指針追加、snapshot/screenshot具体例テーブル追加 | lesson-to-skill棚卸し（Issue #1084 Playwright制約、ワーカー報告操作詳細不足、チャットドロワーsnapshot問題） |
| 2026-03-25 | **v2.5 変更箇所カバレッジマッピング追加** — Phase 1.2.7「変更箇所×テスト対応マッピング検証」追加。モニタリング/ログ変更のobservability_only免除分類導入 | Issue #1534教訓: 7/7 PASSだが変更6ファイル中3箇所が未テスト |
| 2026-03-26 | **v2.6 E2Eテスト定義の明確化** — 冒頭に「E2Eテストの定義」セクション追加。コード検証のみではE2Eと呼ばないことを明文化 | Issue #1588教訓: コード検証完了をE2E完了と混同 |
| 2026-03-27 | **v2.7 ブラウザ外操作の制約明示化** — 制約テーブルにE2E報告義務列追加、ファイルDL制約拡充（CLI代替追加）、C4にMCP制約チェック統合、Issue #1596教訓追加 | Issue #1596教訓: MCP制約下のPASS判定で検証範囲の限界が報告されていなかった |
| 2026-04-03 | **v2.8 教訓棚卸し3件反映** — ファイルDLにAPIレベルfetch()代替を推奨追加、C1に「回帰テスト逃げ」バイアス明示（#1679,#1682）、コードパス整合性検証セクション新設（直接テスト困難なシナリオの代替手段） | 2026-03-31〜04-01バッチ教訓: fetch()代替、コアオペレーション逃げパターン、コードパス整合性検証 |
| 2026-04-04 | **v2.9 Evidence Gate導入** — confidence_gate C1-C6にevidence_ref必須化、ゲートチェック9b追加、BLOCK対処に証跡未添付追加。敵対的E2E監査（usacon references/e2e-audit.md）と連動 | E2E自己採点の構造的矛盾解消（自己申告→証跡ベースへ転換。5回以上再発の根本対策） |
| 2026-04-13 | **v3.0 R5「核心テスト最優先実行」追加、Phase 2に実行順序強制** | 5回再発した「概要レベルで止まる」バイアスの構造的対策（#986/#1000/#1056/#1071/#1084） |
