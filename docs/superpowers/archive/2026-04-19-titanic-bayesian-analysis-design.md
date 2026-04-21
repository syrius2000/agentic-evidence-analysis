# Titanic データのベイズ的証拠分析 デザインドキュメント

## 概要 (Overview)
`examples/titanic.csv` を使用して、`vcd-bayesian-evidence-analysis` スキルの 3-Pass ワークフローを実行し、生存率に寄与する多次元的な「実質的関連」を抽出・解釈する。

## 目標 (Goals)
1. **統計的確実性**: 巨大な $N$ においても「P値の罠」に陥らず、EBIC近似ベイズファクターと Evidence Score で真の交互作用を特定する。
2. **実務的解釈**: 特定された「生存/死亡に強く寄与した属性組み合わせ（セル）」を AI が抽出し、社会学的背景を含めた考察を日本語で提供する。
3. **可視化の完結**: 通計数値、AI 考察、全セル一覧を統合したインタラクティブ・ダッシュボード (`dashboard.html`) を生成する。

## 推論アプローチ (Approaches)

### 選択したアプローチ: 3-Pass ワークフロー（推奨）
本スキルの標準的な実行パイプラインであり、最も信頼性が高い。
- **Pass 1**: R Engine による Poisson GLM 計算（Evidence Score 算出）。
- **Pass 2**: AI による `evidence_results.json` の分析とエグゼクティブ・サマリー執筆。
- **Pass 3**: R Markdown による最終ダッシュボードのレンダリング。

## 詳細設計 (Detailed Design)

### 1. Pass 1: R 統計計算
- **スクリプト**: `.agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
- **入力**: `examples/titanic.csv`
- **主要パラメータ**:
  - `--freq Freq`: 度数集計データとして処理
  - `--run-id titanic_v1`: `output/titanic_analysis/run_titanic_v1/` に成果物を隔離（`run_<prefix>/` は `.agent/shared/run_scope.R` の `run_output_dir_from_root`：`run_id` 文字列の先頭16文字。`runs/<slug>/` ではない）
- **期待成果物**: `evidence_results.json`, `dt_table.html`

### 2. Pass 2: AI 日本語考察
- **手法**: `evidence_results.json` の `top_k_data` と `model_selection` を読み込み、`executive_summary.md` を生成。
- **構成**:
  - H4 節1: 全体評価（BF10, 効果量）
  - H4 節2: Evidence Score 定義と強度解説
  - H4 節3: 上位セル分析（表形式）
  - H4 節4: 結論

### 3. Pass 3: ダッシュボード生成
- **スクリプト**: `.agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R`
- **入力**: `output/titanic_analysis/` (Pass 1 & 2 の成果物)
- **期待成果物**: `dashboard.html`

## エラーハンドリング
- Pass 1 失敗時: R パッケージの依存関係を確認（`pacman` 利用）。
- Pass 3 失敗時: `executive_summary.md` の存在を確認（`require_pass2 = TRUE` がデフォルト）。

## 検証計画 (Verification Plan)
- `dashboard.html` が生成され、ブラウザで正常に閲覧できること。
- AI 考察内の統計数値が `evidence_results.json` と一致していること。
