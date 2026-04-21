# VCD Pass 0: Interactive Consultation デザインドキュメント

## 概要 (Overview)
`vcd-bayesian-evidence-analysis` の前段として、データの統計的性質を検分し、分析のスコープ（次元の選択、層別の要否）をユーザーとの対話を通じて確定させる「Pass 0」工程を定義する。

## 目標 (Goals)
1. **データの自動検分**: R スクリプトを用いて、変数の型、水準数、欠損値、度数分布を自動的に把握する。
2. **対話型意思決定**: AI が「次元削減」や「層別解析」を提案し、分析の解釈性と精度を高める。
3. **シームレスな連携**: Pass 1 (`analysis.R`) が直接読み込める `analysis_config.json` を生成し、次の一手を明示的にガイドする。

## 推論アプローチ (Approaches)

### 選択したアプローチ: 2-Step 検分 & ガイド
1. **Step 1: 物理的検分**: `.agent/shared/inspect_data.R` を実行し、客観的な統計量を得る。
2. **Step 2: 論理的対話**: 統計量を元に AI が分析プランを提示。ユーザーの合意を得て `data_analysis_scope.md` と `analysis_config.json` を生成。

## 詳細設計 (Detailed Design)

### 1. データ検分スクリプト (`.agent/shared/inspect_data.R`)
- `pacman::p_load` を使用し、`skimr`, `dplyr`, `jsonlite` をロード。
- カテゴリカル変数の水準数、度数の偏り（Sparseness）、欠損値を JSON 形式で出力。

### 2. 分析のスコープ定義
- **`data_analysis_scope.md`**:
  - 選択した変数とその理由。
  - 除外した変数のリスト。
  - 分析の主な問い（Research Question）。
- **`analysis_config.json`**:
  - `input`, `vars`, `freq`, `threshold_k`, `run_id` 等、Pass 1 に必要な全引数。

### 3. スキルの拡張 (`analysis.R`)
- `--config <path>` オプションを実装。
- JSON ファイルが存在する場合、CLI 引数よりも JSON 内の設定を優先する。

### 4. ガイド機能 (The Guidance)
- 成果物生成後、次に実行すべきコマンドと、利用すべきスキル（`vcd-bayesian-evidence-analysis`）を明示的に出力する。

## 検証計画 (Verification Plan)
- `inspect_data.R` が正しく JSON を出力すること。
- `analysis.R --config` が設定を正しく反映すること。
- スキル実行後、ユーザーが「次の一手」を迷わずに実行できること。
