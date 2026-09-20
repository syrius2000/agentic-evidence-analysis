## Context

本リポジトリの 3 次元分析正本経路（`pass1_compute.R`）では、9 階層対数線形モデル（M1〜M9）と新 4 軸セル診断（Effect, Evidence, Influence, Stability）を決定論的に計算しています（詳細は `proposal.md` 参照）。

現行のセル診断関数 `compute_4axis_cell_diagnostics()` は、探索表示用として `abs(log_oe_ratio)` 降順への並べ替えを行っており、また観測ゼロに対しては `log(ifelse(y == 0, 0.5, y) / exp_val)` の 0.5 連続性補正を採用しています。本設計は、これらの既存契約と厳密に整合させながら、再標本化による順位再現性評価を組み込みます。

## Goals / Non-Goals

**Goals:**

- 各反復における M1/M5 のモデル再推定（期待度数 $\widehat{\boldsymbol{E}}^{(b)}$ の再計算）を、GLM 適合と機械精度で同値な閉形式により高速かつ決定論的に実行。
- 元データで `REGULAR` と判定された適格セル集合 $\mathcal{C}_{\mathrm{reg}}$ に限定した条件付き順位選択頻度 $\widehat{\pi}_i^{(K)}$ と MCSE の算出。
- 反復中の観測ゼロに対する 0.5 連続性補正の統一適用。
- Pass 0 の `analysis_config.json` に明示保存された `factor_levels_order` を正準水準順の Single Source of Truth として採用し、正準インデックス（`canonical_cell_index`）によるタイブレークの入力行順・表示順不変性を担保。
- 水準名の特殊文字に影響されないキー付き構造化 `cell_id`（`Key=Value/...`）の生成。
- 「有効反復条件付き（`valid_replicates_only: true`）」を含む `estimand_conditioning` メタデータの完全開示。
- 特異反復の分類記録と $\text{valid\_rate} < 0.95$ による運用品質ゲート。
- `analysis_config.json` における一次検証（3変数・完全格子・水準順序整合）と元データ診断後の二段階検証（$K \le \text{eligible}$）。

**Non-Goals:**

- HTML ダッシュボードへの可視化プロットや列追加（Phase 2 へ分離）。
- `score_stat`（Rao スコア統計量）や Dirichlet 事後標本順位分布の対応（Phase 2 へ分離）。
- 個票データに基づくクラスター・ブートストラップ（集計度数表からの多項再標本化に限定）。

## Decisions

### Decision 1: 閉形式積表現によるモデル再適合

- **選択**: M1 および M5 の反復推定において、GLM 最尤推定と同値な積表現（M1: $\frac{n_{i++} n_{+j+} n_{++k}}{N^2}$、M5: $\frac{n_{ij+} n_{i+k}}{n_{i++}}$）を採用する。
- **理由**: 反復数 $B=1000$ において `stats::glm.fit` を 1000 回呼び出すオーバーヘッドを大幅に削減しつつ、GLM 最尤推定量と機械精度内で完全一致するため。
- **代替案**: `glm.fit` の直接呼出し → 単体テストで閉形式と `glm()` の fitted values が許容誤差内で一致することを検証した上で、計算効率の高い閉形式を採用。

### Decision 2: 反復中観測ゼロへの 0.5 連続性補正

- **選択**: 適格セルが反復中に $O_i^{(b)} = 0$ となった場合、局所効果比を $|\log(0.5 / \widehat{E}_i^{(b)})|$ として有限値を計算し、順位付けを継続する。
- **理由**: 既存の `compute_4axis_cell_diagnostics()` の実装（`pass1_compute.R:441`）と完全に整合させ、ゼロ出現を理由とする反復無効化を防ぐため。
- **代替案**: ゼロ出現反復をすべて無効とする → 疎セルを含むデータで有効反復率が急落し、実用不能となるため却下。

### Decision 3: Pass 0 の `factor_levels_order` を Single Source of Truth とする正準順序

- **選択**: 因子の水準順序を OS ロケールや CSV 出現順に頼らず、Pass 0 の `analysis_config.json` に `factor_levels_order` として明示保存し、これを唯一の正準順序（Row-Major 直積）として `canonical_cell_index`（1から始まる連番）を生成する。
- **理由**: カテゴリカルデータの水準順序は分析意図そのものであり、環境依存の文字列ソートを排除して 100% の決定論的再現性を担保するため。

### Decision 4: 衝突のないキー付き構造化 `cell_id`

- **選択**: 内部照合の主キーは `canonical_cell_index` および `factor_levels` とし、文字列表現は `Dept=A/Gender=Female/Admit=Admitted` のキー付き構造化形式とする。
- **理由**: 水準名に `:` や `_` や空白が含まれる場合でも、区切り文字との衝突や曖昧化を完全に防ぐため。

### Decision 5: 二段階検証（Two-Stage Validation）

- **選択**: 設定読込時の一次検証では $K \ge 1$ および水準順序整合のみを検証し、元データ診断完了後に $K \le \text{eligible\_cell\_count}$ を検証して違反時は明確な実行エラーとする。$K$ を `min()` で暗黙に縮小しない。
- **理由**: 診断前に適格セル数を事前予測することは不可能であり、かつ要求された Top-$K$ を勝手に変更することは分析者の意図した Estimand を歪めるため。

## Risks / Trade-offs

- **[Risk: 標本抽出仮定の乖離]** 集計表の背後にある患者・施設クラスタリングを反映できない。
  → **Mitigation**: `cluster_dependence_represented: false` および警告文（`warning_ja`）を出力 JSON に常時含め、解釈上の制限を明文化。
- **[Risk: 有効反復条件付き Estimand の誤解]** 無効反復を除外したことによる潜在的選択効果を認識しない。
  → **Mitigation**: `estimand_conditioning` ブロックを出力し、`valid_replicates_only: true` および `invalid_replicates_excluded_from_denominator: true` を明記。
- **[Risk: 周辺度数ゼロによる閉形式の未定義]** 極端に疎な反復で M5 の分母 $n_{i++}^{(b)} = 0$ となり NaN/Inf が発生する。
  → **Mitigation**: 分母ゼロを検知して `invalid_breakdown$rank_deficient` にカウントし、安全に反復をスキップ。有効率が 95% を下回れば品質ゲートを発火させて結果を保留。
- **[Risk: 丸め誤差によるタイの誤判定]** 表示用 JSON の丸め値で順位を比較すると不当なタイが発生する。
  → **Mitigation**: 順位計算・タイ判定には丸め前の倍精度実数（`double`）を一貫して使用。
