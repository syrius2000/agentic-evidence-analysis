# VCD Analysis ↔ Reporting インターフェース契約

`interface_version`: `"3.0"`  
`schema`: `"two-way-results-v2"`

本仕様は、完全な2次元名義分割表に対する局所診断、大標本Dual-Filter、ベイズDirichlet事後推論、および完全オフラインScientific Dashboardのデータ受け渡しを規定する。

---

## 1. 入力受入境界（Input Contract）

- **次元（Arity）**: 厳密に2（$I \ge 2, J \ge 2$）。3次元以上はフェイルファスト停止し、正本スキル `vcd-bayesian-evidence-analysis` へ委譲。
- **度数**: 有限非負整数（$N = \sum n_{ij} > 0$）。負値、非整数重み度数、無限大、NA/NaN は拒否。
- **構造的ゼロ（発生不能セル）**: 入力禁止（OutOfScope / `STRUCTURAL_ZERO_NOT_SUPPORTED`）。本エンジンは完全分割表のみを対象とし、観測度数0はすべて標本抽出上の偶然（サンプリングゼロ）として扱う。

---

## 2. 出力ディレクトリ規約

常に `<out>/run_<first16>[_N]/`。

- `first16`: 要求 run ID の先頭16文字
- `_N`: 既存 run との衝突回避サフィックス

---

## 3. 主要出力成果物

| ファイル名 | 形式 | 説明 |
| :--- | :--- | :--- |
| `run_meta.json` | JSON | run 識別子、`analysis_signature`、`run_state` |
| `data_profile.json` | JSON | Pass 1 プロファイリング結果 |
| `categorical_results.json` | JSON | **Interface 3.0 正本結果データ（スキーマ適合）** |
| `residuals_table.csv` | CSV | セル単位残差・診断・事後統計量一覧 |
| `quarantine_cells.csv` | CSV | 隔離セル（$O=0, E<5, h \ge 0.80$）一覧 |
| `dashboard.html` | HTML | **完全オフライン Scientific Dashboard（外部参照ゼロ）** |
| `executive_summary.md` | Markdown | Pass 2 AI Narrative 考察レポート（日本語） |

---

## 4. categorical_results.json (Interface 3.0) 構造仕様

スキーマ定義: [schemas/categorical_results_v3.json](../schemas/categorical_results_v3.json)

### 4.1 全体関連（`global`）

- `n_total`: 総サンプルサイズ $N$
- `n_rows`, `n_cols`, `df`: 行水準数 $I$、列水準数 $J$、自由度 $(I-1)(J-1)$
- `pearson_chisq`, `pearson_p_value`: Pearson $\chi^2$ 統計量および $p$ 値
- `deviance_gsq`, `deviance_p_value`: 尤度比 Deviance $G^2$ 統計量および $p$ 値
- `cramers_v`: 未補正 Cramér's $V$
- `cramers_v_ci`: Smithson/Steiger 非心 $\chi^2$ 反転求根による 95% 信頼区間 `[lower, upper]`
- `cramers_v_corrected`: Bergsma (2013) bias-corrected $\tilde{V}$
- `cramers_v_corrected_ci`: 補正後 $\tilde{V}$ の 95% 信頼区間 `[lower, upper]`（退化表時は `null`）

### 4.2 セル診断（`cells`）

- `row_level`, `col_level`: 水準名
- `observed`, `expected`: 観測度数 $O_{ij}$、独立モデル期待度数 $E_{ij}$
- `pearson_res`: Pearson 残差 $r^P_{ij} = (O-E)/\sqrt{E}$
- `deviance_res`: Deviance 残差 $r^D_{ij} = \text{sign}(O-E)\sqrt{2 [O \log(O/E) - (O-E)]}$
- `adj_res`: Haberman 調整残差 $r^{\rm adj}_{ij} = r^P_{ij} / \sqrt{1 - h_{ij}}$
- `leverage`: Hat 行列対角成分 $h_{ij} = (n_{i+} / N) + (n_{+j} / N) - (n_{i+} n_{+j} / N^2)$
- **非有限値安全契約**:
  - 観測度数 $O=0$ の場合:
    - `log_oe`: `null`（標準 JSON 適合）
    - `log_oe_state`: `"NEGATIVE_INFINITY"`
    - `is_finite`: `false`
  - $O > 0$ の場合:
    - `log_oe`: 数値 $\log(O/E)$
    - `log_oe_state`: `"FINITE"`
    - `is_finite`: `true`
- `signed_diff_ratio`: 符号付き割合差 $(O-E)/N$
- `rao_score`: 局所 Rao スコア検定統計量 $T^{\rm score}_{ij} = (r^P_{ij})^2 / (1 - h_{ij})$
- `p_value_unadj`, `p_value_bh`: 未調整局所 $p$ 値および Benjamini-Hochberg 調整 $p$ 値
- `quarantine_status`: `"ACTIVE"` または `"QUARANTINED"`
- `quarantine_reasons`: `["ZERO_OBSERVED", "EXPECTED_LT_5", "HIGH_LEVERAGE"]`
- `dual_filter_candidate`: $N \ge 2000$ かつ $|\log(O/E)| \ge 0.50$ かつ $T^{\rm score} \ge 3.84$ かつ非隔離（`is_finite=true` かつ非 Quarantine）

### 4.3 ベイズ事後推論（`posterior`）

- `prior_specification`: `{ "family": "symmetric_dirichlet", "alpha": 0.5, "role": "primary", "name": "jeffreys" }`
  - **直接比較禁止境界**: 主解析事前分布が異なる過去成果物（$\alpha = 1.0$ 主解析）と本成果物（$\alpha = 0.5$ 主解析）は、事後平均・中央値・信用区間の意味論が異なるため、直接の数値比較・突合を禁止する。
- `n_draws`: 10,000（事後モンテカルロサンプリング）
- `deterministic_seed`: `analysis_signature` から決定論的に生成された 32-bit 整数シード
- `practical_delta`: 実務的乖離閾値（未指定時は `null`）
- `cell_posteriors`:
  - 結合確率要約（6桁）: `prob_analytic_mean`, `prob_analytic_sd`, `prob_mean`, `prob_sd`, `prob_q025`, `prob_q250`, `prob_q500`, `prob_q750`, `prob_q975`, `prob_eti_width`
  - 行条件付き確率 $P(B_j \mid A_i)$ 要約（6桁）: `cond_row_prob_mean`, `cond_row_prob_sd`, `cond_row_prob_median`, `cond_row_prob_q025`, `cond_row_prob_q975`, `cond_row_prob_eti_width`
  - 列条件付き確率 $P(A_i \mid B_j)$ 要約（6桁）: `cond_col_prob_mean`, `cond_col_prob_sd`, `cond_col_prob_median`, `cond_col_prob_q025`, `cond_col_prob_q975`, `cond_col_prob_eti_width`
  - 局所対数乖離要約（4桁）: `log_divergence_mean`, `log_divergence_median`, `log_divergence_q025`, `log_divergence_q975`, `log_divergence_eti_width`, `prob_dir_positive`, `prob_practical_delta`
- `uncertainty_ranking`:
  - 決定論的ソート規則: `prob_eti_width` 降順 $\to$ `observed` 昇順 $\to$ `row_level` 昇順 $\to$ `col_level` 昇順
  - 各要素: `{ rank, row_level, col_level, prob_eti_width, observed }`
- `sensitivity_analysis`:
  - 主解析（$\alpha = 0.5$）と感度分析（$\alpha = 1.0$）の数値比較要約。
  - `primary_alpha: 0.5`, `sensitivity_alpha: 1.0`, `max_absolute_mean_diff`, `max_median_shift`, `max_eti_width_diff`
  - 各セル比較: `primary_median`, `sensitivity_median`, `median_shift`（絶対値差）, `primary_eti_width`, `sensitivity_eti_width`, `eti_width_difference`（符号付き: `sensitivity - primary`）
  - ※ 恣意的な二値フラグ `is_sensitive` および `0.05` 閾値警告は完全廃止。

### 4.4 品質とプロビナンス（`quality`, `provenance`）

- `n_quarantined_cells`: 隔離セル総数
- `n_candidates`: Dual-Filter 候補セル数
- `warnings`: 品質警告メッセージ配列
- `provenance`:
  - `run_id`: 要求 run 識別子
  - `execution_mode`: `"canonical"`（Serializer は Canonical 専用）
  - `analysis_signature`: 64桁 SHA-256
  - `input_sha256`: 64桁 SHA-256
  - `config_sha256`: 64桁 SHA-256（Canonical Core で再検証済みの `canonical_config_sha256`）
  - `timestamp_jst`, `r_version`, `platform`

### 4.5 丸め規則と許容差契約

| 対象フィールド | 出力桁数 | 丸め前許容差（Engine） | 丸め後許容差（Serializer） |
| :--- | :---: | :---: | :---: |
| 結合確率・条件付き確率要約 | **6桁** | $10^{-12}$ | 水準数 $\times 10^{-6}$ |
| 局所対数乖離要約 | **4桁** | $10^{-12}$ | 順序・有限値のみ |
| 方向確率・実務差確率 | **4桁** | $10^{-12}$ | $[0, 1]$ 範囲のみ |
| 事前感度比較要約 | **6桁** | — | 符号付き保持 |
