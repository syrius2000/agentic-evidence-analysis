# 条件付きセル順位再現性評価の実装計画書

created: 2026-09-12 18:58 (JST)
update: 2026-09-12 19:10 (JST)
author: Antigravity / Codex (GPT-5)
change_name: add-conditional-rank-reproducibility

---

## 1. 背景・目的・基本合意事項

### 1.1 背景
現行の 3 次元カテゴリカルデータ分析パイプライン（`vcd-bayesian-evidence-analysis`）では、新 4 軸セル診断（Effect, Evidence, Influence, Stability）およびポアソン GLM（M1〜M9）により、各セルの局所対数効果比 $\log(O_i/E_i)$ や Rao スコア検定統計量 $T_i^{\rm score}$ を決定論的に計算し、大標本 Dual-Filter スクリーニングを実施しています。

しかし、有限標本における「セル順位（Rank）」は、推定値の微小なサンプリング揺らぎによって容易に順位逆転（Ranking Instability / Winner's Curse）を起こします。ハット行列対角成分 Leverage $h_{ii}$ はデータ点の影響度を示しますが、再標本化に対する「順位自体の再現性」を直接保証するものではありません。

### 1.2 目的とスコープ（Phase 1 の厳格な絞り込み）
本計画は、集計度数表が与えられた際に、指定モデル（M1 または M5）および局所対数効果比（`abs_log_oe`）に基づく **「観測度数条件付きセル順位再現性（Conditional Cell-Rank Reproducibility）」** を定量評価する機能を、正本計算エンジン（`pass1_compute.R`）に組み込むことを目的とします。

大学院・専門家レベルでの批判に耐えうる数理的厳密性と監査性を最優先とし、Phase 1 では以下のスコープに厳格に限定します：
- **対象基準モデル**: `"M1"` または `"M5"` のみ
- **対象指標**: `"abs_log_oe"`（$|\log(O/E)|$）のみ（※ `score_stat` は反復内 Leverage 再計算・非有限値処理の複雑化を避けるため Phase 1 では対象外）
- **対象セル母集合**: 元データにおいて当該基準モデルに対して `REGULAR` と判定された適格セル集合（$\mathcal{C}_{\mathrm{reg}}$）に固定
- **入力表**: `vars` が厳密に3変数であり、その水準直積をすべて1回ずつ含む完全な集計度数表のみ。度数は有限の非負整数、総度数 $N>0$ とする。欠損セルの暗黙ゼロと重複セルは明確なエラーで停止する。構造的ゼロがないことは Pass 0 で利用者が確認する前提であり、集計度数だけから自動検出できるとは主張しない。
- **除外スコープ**: HTML ダッシュボード表示、Pass 2 自動ナラティブ、Dirichlet 事後標本順位分布、個票クラスターブートストラップは後続フェーズに分離。

---

## 2. 統計数理契約（6つの基本原則とゼロセル処理）

### 原則 1: 再標本化モデルと標本抽出過程の前提（独立性仮定の明示）
- 集計度数表からの多項再標本化（$\boldsymbol{O}^{(b)} \sim \mathrm{Multinomial}(N, \hat{\boldsymbol{p}})$）は、「各セルへ分類された元の観測単位（individual observations）が独立かつ同一のカテゴリ確率ベクトルから抽出された」という強い仮定に基づきます。
- RWD や臨床データに存在する「同一患者の反復レコード」「施設・医師・地域クラスター」「時系列相関」は集計表からは復元できません。
- **契約**:
  - `resampling_unit`: `"individual observations classified into contingency-table cells"`
  - `required_assumption`: `"観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる"`
  - `cluster_dependence_represented: false` を出力に常時明記。
  - 警告文（`warning_ja`）: `"本指標はセルに分類された各観測単位を独立と扱った条件付き評価であり、患者・施設・時系列クラスタリングに対する頑健性を示しません。"` を必須出力とする。

### 原則 2: Estimand の厳格な限定（「観測度数条件付き順位選択頻度」）
- 本機能が評価する Estimand は、母集団での真の効果量や因果的・臨床的重要性ではなく、**「観測された経験分布の下で、指定モデル・指定指標に基づく Top-$K$ 順位がどの程度選択されるか（モンテカルロ選択頻度）」** に限定します。
- **数理定義**:
  $$\widehat{\pi}_i^{(K)} = \frac{1}{B_{\mathrm{valid}}} \sum_{b=1}^{B_{\mathrm{valid}}} \mathbb{I}\left\{ R_i^{(b)} \le K \right\}$$
- **契約**:
  - 機械可読フィールド名: `top_k_selection_frequency_among_regular_cells`
  - 人間向け表示名: 「観測度数条件付き順位再現性」
  - 推定値 `estimate` とともに、モンテカルロ標準誤差 $\mathrm{MCSE} = \sqrt{\frac{\hat{\pi}(1-\hat{\pi})}{B_{\mathrm{valid}}}}$ を常に対として出力。

### 原則 3: 反復ごとのモデル再適合と期待度数再推定
- 元データの期待度数 $E_i^{(0)}$ を固定して $O_i^{(b)}/E_i^{(0)}$ を計算する誤り（モデル推定値の変動無視）を完全に排除します。
- **数理手順**:
  各反復 $b \in \{1, \dots, B\}$ において：
  $$\boldsymbol{O}^{(b)} \xrightarrow{\quad \text{Fit Model } M \quad} \widehat{\boldsymbol{E}}^{(b)} \xrightarrow{\quad} S_i^{(b)} = \left|\log\left(\frac{\widetilde{O}_i^{(b)}}{\widehat{E}_i^{(b)}}\right)\right| \xrightarrow{\quad} R_i^{(b)}$$
- **M1 / M5 の期待度数閉形式**:
  反復計算の決定論的安定性と高速化のため、GLM 適合と機械精度で一致する積表現を活用：
  - **M1（相互独立）**:
    $$\widehat{\mu}_{ijk}^{(b)} = \frac{n_{i++}^{(b)} n_{+j+}^{(b)} n_{++k}^{(b)}}{N^2}$$
  - **M5（第1変数を記号 A としたときの B と C の条件付き独立 $[AB][AC]$）**:
    $$\widehat{\mu}_{ijk}^{(b)} = \frac{n_{ij+}^{(b)} n_{i+k}^{(b)}}{n_{i++}^{(b)}}$$
  ※ 周辺度数（M5 における $n_{i++}^{(b)}$ 等）が 0 になる場合は、モデル推定不能（特異反復）として無効反復にカウントします。

### 原則 4: 元データ由来の適格セル（`REGULAR`）集合への条件付けと反復中観測ゼロの連続性補正
- **適格セル集合への条件付け（Estimand の明確化）**:
  「REGULAR 固定」は選択バイアスを排除するものではなく、**「元データにおいて当該基準モデルに対し安定評価可能と判定された適格セル集合（$\mathcal{C}_{\mathrm{reg}} = \{i \mid \text{stability\_status}_i^{(0)} == \text{"REGULAR"}\}$）に条件付けた順位付け」** を行う契約です。全セルに対する無条件の順位付けとは Estimand が異なることをメタデータに明記します。
- **反復中観測ゼロ ($O_i^{(b)} = 0$) の連続性補正（現行実装契約との整合）**:
  反復 $b$ において適格セル $i \in \mathcal{C}_{\mathrm{reg}}$ の度数が $O_i^{(b)} = 0$ となった場合、現行の 4 軸セル診断契約（`pass1_compute.R:441`）と完全に整合させ、**0.5 連続性補正 $\log(0.5 / \widehat{E}_i^{(b)})$** を明示的に採用して有限値を保ち、順位計算を続行します：
  $$S_i^{(b)} = \left| \log\left( \frac{\max(O_i^{(b)}, 0.5)}{\widehat{E}_i^{(b)}} \right) \right| = \begin{cases} \left| \log\left( \frac{O_i^{(b)}}{\widehat{E}_i^{(b)}} \right) \right| & (O_i^{(b)} > 0) \\ \left| \log\left( \frac{0.5}{\widehat{E}_i^{(b)}} \right) \right| & (O_i^{(b)} = 0) \end{cases}$$
  反復中に適格セルが局所的にゼロとなったこと自体を理由に反復全体を無効化せず、$\mathcal{C}_{\mathrm{reg}}$ 内での決定論的順位付けを維持します。

### 原則 5: 無効反復の監査と運用上の計算品質ゲート
- 反復標本において周辺度数消失や特異性が発生した場合、隠蔽せずに内訳を記録します。
- **品質ゲート（Operational Computation Quality Gate）**:
  - 有効反復率 $\text{valid\_rate} = B_{\mathrm{valid}} / B_{\mathrm{requested}}$ を算出。
  - 運用基準として $\text{valid\_rate} < 0.95$ の場合は通常結果としての解釈を禁止し、`status = "INSUFFICIENT_VALID_REPLICATES"`、`quality_gate.passed = false`、`cells = null` として個別の順位再現率を出力しません。
  - これは普遍的統計閾値ではなく「計算品質ゲート」であることをメタデータに明記します。

### 原則 6: 正準セル同定子・順位母集合・丸めの分離
- **水準順序の Single Source of Truth**: 入力の完全セル格子から正準順序を導出するにあたり、Pass 0 の `analysis_config.json` に明示保存された `factor_levels_order`（各因子の水準順序ベクトル）を唯一の正準順序とする。CSV の出現順や環境依存の文字列ソートには依存しない。
- 入力の完全セル格子から、因子の `vars` 順および `factor_levels_order` の直積順（Row-Major）に `canonical_cell_index`（1から始まる連番）と一意な `cell_id` を一度だけ生成する。この正準順序は元データ診断、適格セル抽出、全反復のタイブレーク、JSON 出力で共通に用いる。
- **衝突のない `cell_id` 形式**: 水準名に `:` や `_` や空白が含まれる場合でも曖昧化しないよう、内部照合には `canonical_cell_index` および構造化 `factor_levels` を正とし、文字列 `cell_id` は `Dept=A/Gender=Female/Admit=Admitted` のキー付き構造化形式とする。
- `compute_4axis_cell_diagnostics()` が探索表示のために `abs(log_oe_ratio)` 降順へ並べ替えた表は、順位計算の入力順として使用しない。
- `original_metric_value`、期待度数、順位、タイ判定には丸め前の倍精度値を使用し、表示用 JSON のみを丸める。
- `ties.method = "first"` の「first」は `canonical_cell_index` の昇順を意味する。これにより、入力行の並びや出力表の表示順がタイ順位を変えない。

---

## 3. 入出力仕様とスキーマ契約

### 3.1 入力設定 (`analysis_config.json`) の拡張仕様
正本スキーマ [`.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`](.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json) および R 側検証 [`.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R`](.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R) に以下を追加：

```json
{
  "vars": ["Dept", "Gender", "Admit"],
  "factor_levels_order": {
    "Dept": ["A", "B", "C", "D", "E", "F"],
    "Gender": ["Male", "Female"],
    "Admit": ["Admitted", "Rejected"]
  },
  "conditional_rank_reproducibility": {
    "enabled": true,
    "target_baseline_model": "M5",
    "target_metric": "abs_log_oe",
    "top_k": 5,
    "iterations": 1000,
    "seed": 20260912,
    "quality_gate_minimum_valid_rate": 0.95
  }
}
```

- `factor_levels_order`: `vars` の各変数をキーとし、完全セル格子に含まれる全水準を一意に過不足なく列挙した配列の辞書オブジェクト（`conditional_rank_reproducibility.enabled: true` のとき必須）。
- `target_baseline_model`: `"M1"` または `"M5"`（enum 制約）
- `target_metric`: `"abs_log_oe"` のみ（enum 制約）
- `top_k`: 正の整数。設定読込時には上限を検証せず、元データ診断後に $\text{top\_k} \le \text{eligible\_cell\_count}$ を検証する。
- `iterations`: 整数（$\ge 2$、既定 1000）
- `seed`: 整数（必須）
- `quality_gate_minimum_valid_rate`: 数値（$0 < x \le 1.0$、既定 0.95）

`enabled: true` のときの二段階検証契約は次のとおりとする。

1. **設定・入力表検証**: モデルID、指標、`top_k >= 1`、`iterations >= 2`、seed、厳密に3変数であること、`factor_levels_order` のキーと `vars` の完全一致、各水準と入力表水準の完全一致、完全セル格子、非負整数度数、$N>0$ を検証する。
2. **元データ診断後の実行可能性検証**: `eligible_cell_count == 0` なら `status = "NO_ELIGIBLE_CELLS"`、`cells = null` として HOLD する。`top_k > eligible_cell_count` なら設定と Estimand が両立しないため、明確な実行エラーで停止する。要求された Top-$K$ を `min()` により黙って変更してはならない。

### 3.2 出力結果 (`evidence_results.json`) のスキーマ契約
`evidence_results.json` 内に `conditional_rank_reproducibility` オブジェクトを新設：
*(※ UCB Admissions の実測値: 全24セル中、M5基準では REGULAR=13、QUARANTINED=11)*

```json
{
  "conditional_rank_reproducibility": {
    "status": "COMPUTED",
    "target_baseline_model": "M5",
    "target_metric": "abs_log_oe",
    "top_k": 5,
    "estimand_conditioning": {
      "conditioning_statement_ja": "観測経験分布、元データREGULAR適格セル集合、およびモデル再推定が正則に成功した有効反復に条件付けたTop-K順位選択頻度",
      "eligible_cells_fixed_from_original_data": true,
      "valid_replicates_only": true,
      "invalid_replicates_excluded_from_denominator": true,
      "resampling_model": "Multinomial(N, p_hat)",
      "resampling_unit": "individual observations classified into contingency-table cells",
      "required_assumption": "観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる",
      "cluster_dependence_represented": false,
      "warning_ja": "本指標はセルに分類された各観測単位を独立と扱った条件付き評価であり、患者・施設・時系列クラスタリングに対する頑健性を示しません。"
    },
    "input_contract": {
      "dimension_count": 3,
      "complete_cartesian_cell_grid": true,
      "canonical_order_source": "analysis_config_factor_levels_order",
      "canonical_order": "vars_order_then_factor_levels_order",
      "structural_zeros_assumed_absent": true
    },
    "eligible_scope": {
      "scope_definition": "元データにおいて当該基準モデルに対して REGULAR と判定されたセル集合に限定",
      "eligible_cell_count": 13,
      "quarantined_cell_count": 11
    },
    "zero_handling": {
      "method": "continuity_correction_0.5",
      "formula": "|log(ifelse(y == 0, 0.5, y) / exp_val)|",
      "description_ja": "反復中に適格セルが観測ゼロとなった場合は既存4軸診断と整合する0.5連続性補正を適用して有限値を保ち順位計算を続行"
    },
    "replication_audit": {
      "iterations_requested": 1000,
      "iterations_valid": 1000,
      "valid_rate": 1.0,
      "invalid_breakdown": {
        "non_converged": 0,
        "rank_deficient": 0,
        "non_finite": 0
      },
      "quality_gate": {
        "gate_type": "operational_computation_quality_gate",
        "minimum_valid_rate": 0.95,
        "passed": true
      }
    },
    "cells": [
      {
        "canonical_cell_index": 2,
        "cell_id": "Dept=A/Gender=Female/Admit=Admitted",
        "factor_levels": {
          "Dept": "A",
          "Gender": "Female",
          "Admit": "Admitted"
        },
        "original_rank": 1,
        "original_metric_value": 0.9845,
        "top_k_selection_frequency_among_regular_cells": {
          "estimate": 0.942,
          "mcse": 0.0074
        },
        "rank_distribution": {
          "median": 1.0,
          "q025": 1,
          "q975": 3,
          "mean": 1.25
        }
      }
    ],
    "tie_audit": {
      "tie_break_method": "deterministic_canonical_cell_index_order",
      "replications_with_ties": 0,
      "tie_rate": 0.0
    }
  }
}
```

---

## 4. OpenSpec 変更仕様 (`openspec-ff-change` 向け詳細)

### 4.1 Proposal (`proposal.md`)
- **Title**: Add Conditional Cell-Rank Reproducibility Evaluation
- **Why**: 局所セル効果量の点推定に基づく順位付けは、サンプリング揺らぎによる順位逆転リスク（Winner's Curse）を伴う。集計度数表において、モデル再適合を伴う多項再標本化により、観測度数条件付きの順位選択頻度を定量化する。
- **What**:
  - `analysis_config.json` に `conditional_rank_reproducibility` オプションを追加。
  - `pass1_compute.R` に多項再標本化・反復モデル再推定・適格セル条件付き順位評価・無効反復監査エンジンを実装。
  - 監査メタデータおよび品質ゲート付きで `evidence_results.json` に構造化出力。

### 4.2 Delta Specs (`specs/conditional-rank-reproducibility/spec.md`)
- **Requirement 1: モデル再適合を伴う多項再標本化**
  - **Scenario 1-1 (Normal M5 evaluation)**:
    - *Given*: 観測総度数 $N$, 経験割合 $\hat{\boldsymbol{p}}$, 基準モデル M5, $B=1000$。
    - *When*: 各反復 $b$ で $\boldsymbol{O}^{(b)} \sim \mathrm{Multinomial}(N, \hat{\boldsymbol{p}})$ を抽出し、M5 を再適合して期待度数 $\widehat{\boldsymbol{E}}^{(b)}$ を再計算する。
    - *Then*: 元データの $E^{(0)}$ ではなく、反復ごとの $\widehat{\boldsymbol{E}}^{(b)}$ を用いて評価指標 $S_i^{(b)} = |\log(\tilde{O}_i^{(b)}/\widehat{E}_i^{(b)})|$ を算出すること。
- **Requirement 1-2: Phase 1 入力表契約**:
  - **Scenario 1-2 (Complete 3-way table)**:
    - *Given*: `conditional_rank_reproducibility.enabled: true`。
    - *When*: 入力を検証する。
    - *Then*: `vars` は3変数であり、全水準直積のセルが一意に存在し、度数が有限の非負整数かつ $N>0$ でなければ、計算開始前に明確なエラーで停止すること。構造的ゼロがないことは Pass 0 の確認済み前提であること。
- **Requirement 2: 元データ `REGULAR` セル限定の条件付き順位付けと 0.5 補正**
  - **Scenario 2-1 (Eligible cells ranking with zero handling)**:
    - *Given*: 元データで `REGULAR` と判定されたセル集合 $\mathcal{C}_{\mathrm{reg}}$。
    - *When*: 反復 $b$ において $O_i^{(b)}=0$ が発生した場合に 0.5 連続性補正を適用し、$\mathcal{C}_{\mathrm{reg}}$ に属するセル間のみで降順順位 $R_i^{(b)} \in \{1, \dots, |\mathcal{C}_{\mathrm{reg}}|\}$ を決定論的タイブレーク（セルインデックス順）を用いて付与する。
    - *Then*: `top_k_selection_frequency_among_regular_cells` の `estimate` と `mcse` を出力すること。
- **Requirement 2-2: 正準セル順序の固定**:
  - **Scenario 2-2 (Tie invariance to presentation order)**:
    - *Given*: 同じ完全セル格子を異なる入力行順で与え、同じ乱数シードを指定する。
    - *When*: 正準セルIDと `canonical_cell_index` を生成し順位を計算する。
    - *Then*: 出力表示順にかかわらず、セルIDごとの元順位・選択頻度・順位要約が完全に一致すること。
- **Requirement 3: 無効反復の監査と運用品質ゲート**
  - **Scenario 3-1 (High validity)**:
    - *Given*: $B=1000$ のうち有効反復が 950 以上（$\text{valid\_rate} \ge 0.95$）。
    - *Then*: `status: "COMPUTED"`, `quality_gate.passed: true` としてセル再現率一覧を出力。
  - **Scenario 3-2 (Low validity gate trip)**:
    - *Given*: 疎セルや周辺度数消失により有効反復が 950 未満（$\text{valid\_rate} < 0.95$）。
    - *Then*: `status: "INSUFFICIENT_VALID_REPLICATES"`, `quality_gate.passed: false`, `cells: null` を記録し、個別セルの選択頻度を保留（HOLD）すること。
- **Requirement 4: 完全な後方互換性**
  - **Scenario 4-1 (Opt-in backward compatibility)**:
    - *Given*: `analysis_config.json` に `conditional_rank_reproducibility` が指定されていない、または `enabled: false`。
    - *When*: Pass 1 を実行する。
    - *Then*: `evidence_results.json` に新フィールドは追加されず、既存の全テスト・既存 fixture が完全に一致すること。
- **Requirement 5: 実行可能性の二段階判定**
  - **Scenario 5-1 (No eligible cells)**:
    - *Given*: 元データ診断後の `eligible_cell_count == 0`。
    - *Then*: `status: "NO_ELIGIBLE_CELLS"`, `cells: null` とし、順位選択頻度を出力しないこと。
  - **Scenario 5-2 (Requested K exceeds eligible cells)**:
    - *Given*: 元データ診断後に `top_k > eligible_cell_count`。
    - *Then*: `top_k` を暗黙に縮小せず、設定不整合を示す明確な実行エラーで停止すること。

### 4.3 Design (`design.md`)
- **計算サブルーチン**:
  `pass1_compute.R` に `compute_conditional_rank_reproducibility(df, vars, freq_col, fitted_models, base_model_id, config)` を新設。
- **アルゴリズム詳細**:
  1. 設定・入力表の一次検証を行い、完全セル格子の因子・水準順から `cell_id` と `canonical_cell_index` を生成する。
  2. 元データの診断結果を正準セルIDで結合して $\mathcal{C}_{\mathrm{reg}}$ を抽出し、適格セル数 $C_{\mathrm{reg}} = |\mathcal{C}_{\mathrm{reg}}|$ を記録する。$C_{\mathrm{reg}} == 0$ は `NO_ELIGIBLE_CELLS` HOLD、`top_k > C_{\mathrm{reg}}$ は実行エラーとする。
  3. M1/M5 の閉形式を用いて、各反復 $b$ の $\widehat{\boldsymbol{E}}^{(b)}$ を再推定する。閉形式は GLM と数値的に同値であることを単体試験で検証する。
  4. いずれかの周辺度数が0で分母ゼロ（NaN/Inf）が発生した場合は `invalid_breakdown$rank_deficient` をインクリメントしてスキップする。
  5. 各適格セル $i \in \mathcal{C}_{\mathrm{reg}}$ について、丸め前の $S_i^{(b)} = |\log(\text{ifelse}(O_i^{(b)} == 0, 0.5, O_i^{(b)}) / \widehat{E}_i^{(b)})|$ を算出する。
  6. `canonical_cell_index` 昇順へ整列した上で `ties.method = "first"` により降順順位を付与し、タイ発生を `replications_with_ties` に記録する。表示用ソートはこの後に限る。
  7. $B_{\mathrm{valid}} / B < 0.95$ なら `cells <- NULL` として返却する。

### 4.4 Tasks (`tasks.md`)
1. **Task 1: スキーマ定義とバリデーション実装**
   - `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` に `conditional_rank_reproducibility` 定義を追加。
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R` に一次入力境界チェック（モデルID, metric, top_k, iterations, seed, 3変数, 完全セル格子, 度数）を追加し、元データ診断後の `top_k` 上限検証は計算サブルーチンへ分離。
2. **Task 2: コア計算サブルーチンの実装**
   - `.agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R` に正準セルID生成、M1/M5 モデル再適合、0.5補正、適格セル限定順位付け、無効反復監査、品質ゲート処理を実装。
   - `analysis.R` に設定の受け渡しと結果 JSON への統合を配管。
3. **Task 3: 決定論的再現性と単体・境界値テスト**
   - `tests/test_conditional_rank_reproducibility.R` を新規作成。
   - テスト 1: UCB Admissions におけるシード固定完全一致テスト。
   - テスト 2: 後方互換性テスト（`enabled: false` 時の fixture 不変性）。
   - テスト 3: 完全セル格子・3変数・重複セル・非整数度数を含む不正入力のエラー検知テスト。構造的ゼロがないことは Pass 0 の確認前提として文書化する。
   - テスト 4: `top_k > eligible_cell_count` と `eligible_cell_count == 0` の二段階判定テスト。
   - テスト 5: 閉形式と GLM の期待度数同値性、および直接入力による0.5補正テスト。
   - テスト 6: 入力行順と表示順に不変な決定論的タイブレーク試験。
   - テスト 7: 人工極小疎テーブルによる品質ゲート発火テスト（下記 TC-04）。
4. **Task 4: 全体回帰テスト実行**
   - `python3 tests/test_analysis_quality_contract_docs.py`
   - `Rscript tests/test_three_way_computation_engine.R`

---

## 5. 検証・受入計画（テスト仕様の具体化）

| テストケース | 対象データ・設定 | 検証観点 | 期待される結果（合格条件） |
|---|---|---|---|
| **TC-01: 決定論的再現性** | `examples/ucb_admissions.csv`<br>`model: "M5"`, `top_k: 5`<br>`B: 1000`, `seed: 20260912` | 同一シードでの再実行 | 2 回の実行で `estimate`, `mcse`, `median`, `q025`, `q975` が 1 bit の狂いもなく完全一致。`eligible_cell_count: 13`, `quarantined_cell_count: 11`。 |
| **TC-02: 閉形式・GLM同値性と0.5補正** | 完全な3変数固定 fixture。M1/M5 各1例、ならびに直接の `y=0, E>0` 入力 | 推定値再計算とゼロ処理 | M1/M5 の閉形式期待度数と `glm()` の fitted values が指定許容誤差内で一致する。補正値が厳密に $|\log(0.5/E)|$ であり有限となる。再標本化本体には「ゼロが必ず出る」ことを要求しない。 |
| **TC-03: 入力表・二段階実行可能性検証** | 2変数表、不完全格子、重複セル、非整数度数、`top_k > eligible_cell_count`、適格セル0 の各 fixture | 入力表契約と Estimand の固定 | 入力表違反は計算開始前に明確なエラー。`top_k > eligible_cell_count` は診断後に明確な実行エラー。適格セル0は `status: "NO_ELIGIBLE_CELLS"`, `cells: null`。要求Kを暗黙変更しない。構造的ゼロがないことは Pass 0 の確認前提として記録する。 |
| **TC-04: 運用品質ゲートの確定発火** | 固定疎 fixture `tests/fixtures/sparse_rank_gate_test.csv`<br>(3変数 $2 \times 2 \times 2$, $N=8$, 層1合計=1, 層2合計=7)<br>`model: "M5"`, `B: 500`, `seed: 123` | 周辺度数ゼロ多発による特異性 | 多項リサンプルで層1合計が0となる反復が約 $34\%$ 発生（理論値 $(7/8)^8 \approx 0.344$）。`valid_rate < 0.95` を検知し、`status: "INSUFFICIENT_VALID_REPLICATES"`, `cells: null` となること。 |
| **TC-05: 正準順序・タイ不変性** | 同一完全セル格子を異なる入力行順で与える。意図的な同値指標を含む固定 fixture | 正準IDと決定論的タイブレーク | 同一シードでセルIDごとの `original_rank`、選択頻度、順位要約が完全一致し、表示表のソートが順位へ影響しない。 |
| **TC-06: 後方互換性** | `conditional_rank_reproducibility` 未指定 | 既存機能への影響ゼロ | `tests/fixtures/dashboard_ui/ucb_admissions_three_way_v1/evidence_results.json` との差分がなく、既存出力が完全に保全されること。 |

---

## 6. 次のアクション

本改訂計画書（`docs/Artifacts/implementation_plan_014_0912.md`）に対するユーザーの明示的承認後、以下のコマンドで OpenSpec change を一括起票します。計画書の更新だけでは、OpenSpec 起票・コード変更・Pass 1 実行を開始しません。

```bash
/opsx-ff add-conditional-rank-reproducibility
```
