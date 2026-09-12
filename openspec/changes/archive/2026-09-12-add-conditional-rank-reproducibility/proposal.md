## Why

有限標本におけるカテゴリカルデータ分析では、局所対数効果比 $\log(O/E)$ やスコア統計量の点推定値に基づくセルの順位付け（Top-$K$ 抽出）は、サンプリング揺らぎによって容易に順位逆転を起こすリスク（Winner's Curse / Ranking Instability）を伴います。現行のハット行列対角成分 Leverage $h_{ii}$ はデータ点の影響度を示しますが、再標本化に対する順位の再現性を直接保証するものではありません。

本変更では、集計度数表が与えられた際に、指定モデル（M1 または M5）の再適合を伴う多項再標本化により、元データ由来の適格セル集合（`REGULAR`）に条件付けたセル順位選択頻度（`top_k_selection_frequency_among_regular_cells`）を厳密に定量評価する能力を提供します。

## What Changes

- **設定契約の拡張 (`analysis_config.json`)**: `factor_levels_order`（Pass 0 による各変数の正準水準順序の明示保存）および `conditional_rank_reproducibility` オプション（M1/M5, `abs_log_oe`, `top_k`, `iterations`, `seed`, `quality_gate_minimum_valid_rate`）を追加し、完全セル格子・3変数・非負整数度数の一次検証と元データ診断後の二段階検証（$K \le \text{eligible}$）を導入。
- **正本計算エンジン (`pass1_compute.R`) の拡張**:
  - 各反復 $b$ における $\boldsymbol{O}^{(b)} \sim \mathrm{Multinomial}(N, \hat{\boldsymbol{p}})$ からの M1/M5 モデル再適合と期待度数再推定。
  - 元データで `REGULAR` と判定された適格セル集合 $\mathcal{C}_{\mathrm{reg}}$ に限定した条件付き順位付け。
  - 反復中観測ゼロ ($O_i^{(b)}=0$) に対する 0.5 連続性補正（$\log(0.5 / \widehat{E}_i^{(b)})$）の適用。
  - `factor_levels_order` に基づく正準セル順序（`canonical_cell_index`）およびキー付き `cell_id`（`Key=Value/...`）の決定論的生成とタイブレーク。
- **無効反復監査と運用品質ゲート**:
  - 特異反復・周辺度数消失・非収束の内訳（`invalid_breakdown`）を記録。
  - $\text{valid\_rate} < 0.95$ の場合に `status = "INSUFFICIENT_VALID_REPLICATES"`, `cells = null` とする計算品質ゲートの実装。
- **出力契約 (`evidence_results.json`)**:
  - `estimand_conditioning`（有効反復条件付きの明示）、`resampling_unit`, `cluster_dependence_represented: false`, 警告文 `warning_ja` を常時出力。
  - 各適格セルの選択頻度 `estimate` と `mcse` の対、および順位分布要約（中央値、95%区間）を出力。
- **完全な後方互換性**: 未指定または `enabled: false` の場合、既存出力・fixture に一切影響を与えない。

## Capabilities

### New Capabilities
- `conditional-rank-reproducibility`: 指定モデル（M1/M5）および局所効果比（`abs_log_oe`）に基づき、元データ由来の適格セル集合内で観測度数条件付きのセル順位選択頻度を再適合多項再標本化により評価・監査する能力。

### Modified Capabilities
（なし）

## Impact

- **対象コード**:
  - `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R`
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R`
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
- **新規テスト**:
  - `tests/test_conditional_rank_reproducibility.R`
  - `tests/fixtures/sparse_rank_gate_test.csv`
- **非互換性**:
  - なし（オプトイン機能であり、未指定時は既存出力に差分を生じない）。
