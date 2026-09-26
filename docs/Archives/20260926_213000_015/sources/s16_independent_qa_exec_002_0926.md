# Section 16 独立QAおよび回帰検証ゲート実行記録 2 (Execution Record 2: Tasks 14.11–14.14)

- **文書ID:** `s16_independent_qa_exec_002_0926`
- **日付:** 2026-09-26
- **ブランチ:** `feat/comparative-evidence-reporting-v3`
- **実行フェーズ:** Section 14 拡張実装 (Tasks 14.11–14.14 / 14.11.R1–14.14.R1) および Section 16 回帰検証ゲート
- **関連計画書:** [implementation_plan_022_0926.md](implementation_plan_022_0926.md)
- **関連QAレビュー:** [s16_independent_qa_review3_001_0926.md](s16_independent_qa_review3_001_0926.md)
- **OpenSpec Change:** `comparative-evidence-reporting-v3`

---

## 1. エグゼクティブサマリー

OpenSpec Change `comparative-evidence-reporting-v3` において、`implementation_plan_022_0926.md` および独立 QA レビュー指摘（H14.13-01, M14.11-01, M14.14-01）に基づき、以下の機能実装、修復、およびオフライン決定論的検証を完了した。

1. **Task 14.11 & 14.11.R1**: Excel 互換ダッシュボード CSV エクスポート。全件出力および表示中／ソート順準拠出力。内部管理キー `row_key` を CSV エクスポートから除外（canonical 36 列のみを出力）。UTF-8 BOM (`\uFEFF`)、CRLF 改行、RFC 4180 引用符エスケープ、再計算ゼロ契約を厳格遵守。
2. **Task 14.12**: アクセシブルな複数選択フィルタ（Theme 検索／選択、実務領域／U-Grade 複合選択、診断バッジ選択、群内 OR ／ 群間 AND、`aria-live="polite"` による件数動的通知、全フィルタ解除、ソートとの合成保証、日本語・特殊文字のエスケープ耐性）。
3. **Task 14.13, 14.13.R1 & 14.13.R2**: デフォルト折りたたみ式・数理アコーディオンガイドの完全推論セマンティクス適応（H14.13-02 修復）。
   - **HTML 数学解説の推論セマンティクス適応 (Adaptive Semantics)**:
     - **Bayesian-only**: 独立 Jeffreys 事前分布 $\text{Beta}(0.5, 0.5)$、事後中央値（`posterior_median`）、Bayesian 95% ETI、参照群ゼロ時の理論的期待値発散 $E(RR) = \infty$（`mean = null, mean_is_finite = false`、中央値・区間は有限）。
     - **Bootstrap-only**: 標本観測推定量（`observed_sample_estimate`）、Bootstrap 95% percentile interval、支持比率 $\hat{p}^*$。事後中央値や Jeffreys 事前分布への言及を排除。参照群ゼロ／定義不能レプリケート時の RR 利用不能契約（`rr_estimate_available = false`）および診断契約を解説。
     - **Mixed**: 行ごとに `inferential_semantics`（`bayesian` / `bootstrap`）に従うことを明記し、両体系の推論契約を明確に区分して説明。
   - **Markdown レポート同期**: `comparative_report.md` 内のブートストラップ点推定値説明文を `observed_sample_estimate` セマンティクスに適正化。
   - 外部 CDN 排除・完全自己完結型 Native MathML (`<math display="block">`)、10 項目、4 ブロック構成。
4. **Task 14.14 & 14.14.R1**: 統合ブラウザ／CSV／アクセシビリティ QA。
   - 新規 Visual QA Run (`evidence_runs/visual_qa_s14/run_20260926_174946/`) による manifest ハッシュ整合検証（全ファイル完全一致、`valid: TRUE`）。
   - Headless Chrome 1280x800 デスクトップスクリーンショット取得（`dashboard_1280x800.png`）。
   - 検証証拠区分の明確化（Node.js による静的 HTML/DOM・操作論理監査、Chrome レンダリング、R 単体・統合回帰テスト、および User/Owner による視覚受入 PASS エビデンス）。

```text
================================================================================
Section 14 (Tasks 14.11-14.14) & Section 16 回帰検証 総合判定: ALL PASS
================================================================================
- R ダッシュボード統合テスト (tests/test_comparative_dashboard_qa.R) : 158 / 158 PASS
- R レポーティング契約テスト (tests/test_vcd_categorical_reporting.R): 35 / 35 PASS
- R 正規回帰テストスイート (tests/run_regression_suite.R)           : 50 / 50 PASS
- Python ガバナンス契約テスト (tests/test_skill_ownership_contract.py): 10 / 10 PASS
- Python アーカイブ整合性テスト (tests/test_archive_manifest_integrity.py): 5 / 5 PASS
- OpenSpec Strict Validation (comparative-evidence-reporting-v3)       : Valid = true, Issues = 0
- Git 差分チェック / ホワイトスペース (git diff --check)               : Clean (0 errors)
- DOM / 操作性・整合性監査 (scratch/verify_extended_dashboard_qa.js)  : 11 / 11 PASS
- 新規 Visual QA Run (evidence_runs/visual_qa_s14/run_20260926_174946/): Valid = true (完全一致)
- Owner 視覚受入判定 (User Dashboard Visual Acceptance)                 : PASS (human validated)
================================================================================
```

---

## 2. タスク別実装内容および受入証拠

### Task 14.11 & 14.11.R1: Excel 互換ダッシュボード CSV エクスポート

- **実装ファイル**: `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- **データ契約（Data Provenance）**:
  - `render_comparative_dashboard_html()` 内で、`summary_df` を canonical JSON として `<script id="comparative-summary-data" type="application/json">` にシリアライズ。
  - XSS 静的スキャナ耐性のため、JSON 内の `<` は `\u003c`、`>` は `\u003e`、`&` は `\u0026` に Unicode エスケープ（JS 側 `JSON.parse` で自動復元）。
  - 各行の数値・区間・バッジの再計算・再フォーマットを一切排除し、中間データ構造の値を忠実に保持。
- **14.11.R1 修復（内部キー除外）**:
  - DOM 照合用の内部キー `row_key` は embedded JSON（37 列）に保持しつつ、CSV 生成関数 `generateCsv()` において `Object.keys(rowsData[0]).filter(function(h) { return h !== "row_key"; })` により明示的に除外。
  - エクスポートされる CSV は canonical な **36 列**（`comparative_summary.csv` と列名・順序・個数が完全一致）のみを出力。
- **Excel 互換性**:
  - 先頭に UTF-8 BOM (`\uFEFF`) を付与。
  - 改行コードは `\r\n` (CRLF)。
  - RFC 4180 に準拠したフィールド引用（カンマ、改行、二重引用符を含む場合は `""` でエスケープ）。
- **出力モード**:
  - **全件出力 (`#btn-export-all`)**: フィルタ・非表示状態に関わらず、全 6 行の canonical データをエクスポート。
  - **表示中出力 (`#btn-export-filtered`)**: 現在フィルタで表示されている行のみを、現在のテーブルのソート順序に従ってエクスポート。

### Task 14.12: アクセシブルな複数選択フィルタ

- **構成**:
  - `#filter-group-theme`: Theme 検索 input (`#theme-search-input`) およびチェックボックス一覧。
  - `#filter-group-practical`: 実務領域（3 区分）および U-Grade（U0〜U3, NONE）のチェックボックス。
  - `#filter-group-diagnostics`: 診断バッジ（`ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`, `UNSTABLE_RR_INTERVAL`）チェックボックス。
- **フィルタ論理**:
  - 同一グループ内: OR 結合（例: U0 または U2 を選択した場合、いずれかに合致する行を表示）。
  - 異なるグループ間: AND 結合（例: Region="target_excess" かつ U-Grade="U0" の行のみ表示）。
  - 実務領域と U-Grade: 領域選択と U-Grade 選択の両方が指定された場合は積集合（AND）として判定。
- **アクセシビリティと状態通知**:
  - `<span id="visible-row-count" aria-live="polite">`: 表示件数を動的に通知（例: `表示 3 / 6 件`）。
  - `#btn-reset-filters`: 全チェックボックスおよび検索入力をリセットし、初期状態（全 6 件表示）に復元。
  - 行データ属性: 各 `<tr>` に `data-row-key`, `data-theme`, `data-region`, `data-ugrade`, `data-badges` を付与し、DOM 表示文字列の曖昧パースを排除。
  - ソートとの合成: フィルタ適用中に行をソートしても非表示行が漏出せず、ソート後にフィルタを切り替えてもソート順序が保持される。

### Task 14.13 & 14.13.R1: デフォルト折りたたみ式・数理アコーディオンガイド

- **配置**: `<section id="metric-guide">`
- **アーキテクチャ**:
  - ネイティブ HTML `<details>` / `<summary>` を使用し、全項目デフォルトで折りたたみ状態（`open` 属性なし）。JavaScript が無効でも閲覧可能なプログレッシブ・エンハンスメント設計。
  - 外部 JS/CSS/フォント（MathJax 等）への依存を完全に排除した **Native MathML (`<math display="block">`)** を採用。
- **14.13.R1 数理定義・表現の適正化**:
  - **発症割合 (Risk)**: 推論上の点推定値（inferential point estimate）には事後中央値（posterior median）を用い、生の記述発症割合（raw descriptive proportion: $x_g / n_g$）と峻別。
  - **不確実性区間 (Uncertainty Interval)**: Bayesian 95% ETI（事後確率質量 95% を含む等裾区間）と Bootstrap 95% percentile interval（リサンプリング経験分布の 2.5% 点と 97.5% 点）を別個に定義。「パラメータが 95% の確率で区間内にある」という解釈はベイズのみに適用し、ブートストラップでは禁止。
  - **相対リスク (RR)**: 「曝露効果の強度」を排除し、「相対的な発生リスクの対比」に表現を統一。参照群ゼロ発生時（$x_R = 0$）の期待値発散 $E(RR) = \infty$（`mean = null, mean_is_finite = false`）と RD 併用の重要性を明記。
- **Markdown レポートへの同期**:
  - `comparative_report.md` の末尾に `## 3. 統計指標の解説と利用ガイド (Statistical Metric Guide)` を追加。
  - 推論セマンティクス適応型設計（adaptive semantics）を採用し、ベイズ推論のみの解析ではベイズ用語、IPTW（ブートストラップ推論のみ）の解析ではブートストラップ用語のみを出力することで、Task 10.13 の契約（IPTW レポートへのベイズ用語漏出禁止）と完全整合。

### Task 14.14 & 14.14.R1: 統合ブラウザ／CSV／アクセシビリティ QA

- **新規 Visual QA Run 生成**:
  - ディレクトリ: `evidence_runs/visual_qa_s14/run_20260926_174946/`
  - フィクスチャ構成: **6 テーマ (6 行)**
  - 成果物: `dashboard.html`, `comparative_evidence.json`, `comparative_report.md`, `comparative_summary.csv` (36 列), `results_manifest.json`, `run_meta.json`
  - Manifest ハッシュ検証: `valid: TRUE`（全 SHA-256 完全一致）
    - `dashboard.html` SHA-256: `be29491637b44e255991868393a2bb9aac5fe652d0311338ad38d974b1703156` (Manifest と完全一致)
    - `results_manifest.json` SHA-256: `42acfce0d0863cad7c8043ae9a30362395e608a38c8b870d97123e964454edca`
  - スクリーンショット取得: `dashboard_1280x800.png` (1280x800, 201KB)
- **検証証拠区分 (Evidence Breakdown)**:
  1. **静的 DOM / 操作論理監査 (`scratch/verify_extended_dashboard_qa.js`)**:
     - Check 1: 埋め込み JSON のパース整合性（6 行、37 列）... PASS
     - Check 2: カラム網羅性（canonical カラムすべて存在）... PASS
     - Check 3: 全件 CSV エクスポートの BOM/CRLF/行数確認（6 データ行 + 1 ヘッダ行、row_key 除外の 36 列）... PASS
     - Check 4: フィルタ初期状態（6/6 行表示）... PASS
     - Check 5: Theme OR フィルタ（T1 + T2 -> 2/6 行合致）... PASS
     - Check 6: Region + U-Grade 複合フィルタ（target_excess & [U0, U2] -> 3/6 行合致）... PASS
     - Check 7: 診断バッジフィルタ（`ZERO_REFERENCE` -> 1/6 行合致: T6_ZeroRef）... PASS
     - Check 8: フィルタ＋ソート合成（RD 昇順ソート後に表示中 CSV 出力 -> ソート順で 3 行出力）... PASS
     - Check 9: 10 個の独立アコーディオン存在確認... PASS
     - Check 10: 各アコーディオンの 4 ブロック見出しおよび MathML 存在確認... PASS
     - Check 11: 外部通信（`http:`, `https:` 等）およびローカル絶対パスの静的スキャン（完全排除確認）... PASS
  2. **Chrome レンダリング証拠**: Headless Chrome 1280x800 によるスクリーンショット取得（レイアウト破綻なし）。
  3. **ユーザー視覚受入証拠 (Owner Visual Inspection)**: 人の目による視覚受入 PASS エビデンスを確認済み。

---

## 3. 回帰テストおよび品質ゲート実行ログ

### 3.1 R ダッシュボード統合テスト (`tests/test_comparative_dashboard_qa.R`)

```text
Section 14 QA Test Summary: 158 Passed, 0 Failed
```

（Section 1〜10 既存テスト 86 件 + Section 11〜13 新規テスト 72 件 = 計 158 件 PASS）

### 3.2 R レポーティング契約テスト (`tests/test_vcd_categorical_reporting.R`)

```text
Test Summary: 35 Passed, 0 Failed
```

### 3.3 Python ガバナンス契約 & アーカイブ整合性テスト

```text
All archive manifest integrity tests passed!
All 10 tests passed!
```

### 3.4 OpenSpec Strict Validation

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
Valid = true, Issues = 0
```

### 3.5 Git 差分およびフォーマット検証

```text
git diff --check
(Clean - 0 errors, no whitespace issues)
```

---

## 4. 独立 QA Reviewer への提示事項

- **実装範囲**: Tasks 14.11–14.14 および 14.11.R1–14.14.R1, 14.13.R2 (H14.13-02 修復)
- **対象コミット**: 作業ブランチ `feat/comparative-evidence-reporting-v3` 上の最新 `Yip:` コミット
- **検証済み Run**: `evidence_runs/visual_qa_s14/run_20260926_174946/`
- **成果物 HTML**: `evidence_runs/visual_qa_s14/run_20260926_174946/dashboard.html`
- **スクリーンショット**: `evidence_runs/visual_qa_s14/run_20260926_174946/dashboard_1280x800.png`
- **検証スクリプト**: `tests/test_comparative_dashboard_qa.R`, `scratch/verify_extended_dashboard_qa.js`
