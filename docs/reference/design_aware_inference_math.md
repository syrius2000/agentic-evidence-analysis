# デザイン考慮型比較推論の統計数理（Design-Aware Comparative Inference Math）

created: 2026-09-27 09:20 (JST)
update: 2026-09-27 09:20 (JST)
author: Antigravity (Pair Programming Agent)
依拠仕様: `openspec/specs/comparative-design-inference`
主スキル: `comparative-design-analysis`

本文書は、観察研究やリアルワールドデータ（RWD）において観測の非独立性や交絡が存在する場合に適用される**デザイン考慮型比較推論（1:1 マッチドペア、1:k マッチドセット、IPTW、人年発症率）の統計数理解説**である。

---

## 1. 1:1 Matched Pairs（マッチドペア多項 Dirichlet 推論）

### 1.1 観測構造と 4 セル分割表

1 対 1 の傾向スコアマッチングや被験者ペア（$j = 1, \dots, J$）において、各ペア内の処置群転帰 $Y_{Tj} \in \{0, 1\}$ および対照群転帰 $Y_{Rj} \in \{0, 1\}$ を観測する。データは以下の $2 \times 2$ 分割表の度数 $(n_{11}, n_{10}, n_{01}, n_{00})$ に集約される：

| 処置群（Target） \ 対照群（Reference） | $Y_R = 1$ (Event) | $Y_R = 0$ (No Event) | 合計 |
| :---: | :---: | :---: | :---: |
| **$Y_T = 1$ (Event)** | $n_{11}$ | $n_{10}$ | $n_{1\cdot}$ |
| **$Y_T = 0$ (No Event)** | $n_{01}$ | $n_{00}$ | $n_{0\cdot}$ |
| **合計** | $n_{\cdot 1}$ | $n_{\cdot 0}$ | $J$ |

### 1.2 多項 Dirichlet 事後分布

4 セルの同時生起確率を $\mathbf{\pi} = (\pi_{11}, \pi_{10}, \pi_{01}, \pi_{00})$ とし、多項尤度を設定する。事前分布には Jeffreys 型客観事前分布 $\mathrm{Dirichlet}(0.5, 0.5, 0.5, 0.5)$ を採用する。共役性により事後分布は以下となる：
$$\mathbf{\pi} \mid \mathbf{n} \sim \mathrm{Dirichlet}\left(n_{11} + \frac{1}{2}, \; n_{10} + \frac{1}{2}, \; n_{01} + \frac{1}{2}, \; n_{00} + \frac{1}{2}\right)$$

### 1.3 対比の導出と McNemar オッズ比

各事後ドロー $\mathbf{\pi}^{(s)}$ において、以下の指標が算出される：

- **周辺リスク**: $p_T^{(s)} = \pi_{11}^{(s)} + \pi_{10}^{(s)}, \quad p_R^{(s)} = \pi_{11}^{(s)} + \pi_{01}^{(s)}$
- **リスク差 (RD)**:
  $$\mathrm{RD}^{(s)} = p_T^{(s)} - p_R^{(s)} = \pi_{10}^{(s)} - \pi_{01}^{(s)}$$
  ※ 一致ペア（$n_{11}, n_{00}$）は相殺され、不一致ペア（Discordant Pairs）のみがリスク差に寄与する。

- **主たるオッズ比 (McNemar オッズ比)**:
  $$\mathrm{OR}_{\mathrm{discordant}}^{(s)} = \frac{\pi_{10}^{(s)}}{\pi_{01}^{(s)}}$$
- **Dirichlet 解析的厳密期待値（Analytic Exact Mean）**:
  モンテカルロ平均の代わりに、以下の閉形式期待値を用いる：
  $$E\left[\mathrm{OR}_{\mathrm{discordant}} \mid \mathbf{n}\right] = \frac{n_{10} + 0.5}{n_{01} - 0.5} \quad (n_{01} \ge 1 \text{ のとき有限})$$
  $n_{01} = 0$ のときは期待値発散のため `mean = null, mean_is_finite = false` を確定する。
- **ペア内転帰一致連関の完全分離**:
  ペア内の相関度合いを表すオッズ比 $\mathrm{OR}_{\mathrm{assoc}} = \frac{\pi_{11} \pi_{00}}{\pi_{10} \pi_{01}}$ は、治療効果とは直交する副次指標（`intra_pair_association_or`）として完全に分離して出力する。

---

## 2. 1:k Matched Sets（マッチドセット・原子クラスタブートストラップ）

### 2.1 データ契約と ATT エスティマンド

1 処置例（$Y_{Tj}$）に対して $k_j \ge 1$ 例の対照例（$Y_{Rj\ell}, \; \ell = 1, \dots, k_j$）が割り当てられたマッチドセット（$j = 1, \dots, J$）を対象とする。

- **標的推定量**: 処置群における平均処置効果（Average Treatment Effect on the Treated: **ATT**）
- **観測標本点推定値 (`estimate.source = "observed_sample_estimate"`)**:
  $$\hat{p}_{T, \mathrm{obs}} = \frac{1}{J} \sum_{j=1}^J Y_{Tj}, \quad \hat{p}_{R, \mathrm{obs}} = \frac{1}{J} \sum_{j=1}^J \bar{Y}_{Rj} \quad \left( \text{where } \bar{Y}_{Rj} = \frac{1}{k_j} \sum_{\ell=1}^{k_j} Y_{Rj\ell} \right)$$
  $$\widehat{\mathrm{RD}}_{\mathrm{obs}} = \hat{p}_{T, \mathrm{obs}} - \hat{p}_{R, \mathrm{obs}}$$

### 2.2 固定条件付き原子クラスタブートストラップ（Atomic Cluster Bootstrap）

- **ブートストラップのスコープ**:
  各マッチドセット $j$ を崩さない単一の単位（Atom）として扱い、セット単位で $J$ 個を有復元抽出する（既定: `num_draws = 4000L` 反復、設定可能）。
- **Abadie & Imbens (2008) の留意点**:
  最近傍マッチング推定量に対して通常の被験者リサンプリング・ブートストラップは漸近妥当性を持たないことが示されている。したがって本推論器は、「形成されたマッチドセット構造を固定条件とした標本変動評価（`conditional_on_fixed_matched_sets`）」として明確にスコープを限定する。
- **推論セマンティクス**: `inferential_semantics = "bootstrap"`、`interval.method = "bootstrap_percentile"`。

### 2.3 ゼロ除算 RR 保守ポリシー

ブートストラップ推論において対照群リスクがゼロとなる場合、以下の 2 分岐で保守的に確定する（runtime: `.agents/shared/matched_set_inference.R`）。いずれの分岐でも RR 由来の精度指標 `precision_metrics.log_rr_interval_width` および `precision_metrics.rr_interval_fold_range` を `null` に抑制する。

1. **完全抑制（観測対照リスク 0: $\hat{p}_{R, \mathrm{obs}} \le 0$）**:
   - 点推定値: `null`
   - 区間: `null`
   - 平均: `null`（`mean_is_finite = false`）
   - 診断コード: `relative_risk.diagnostic = "ZERO_REFERENCE_RISK"`
   - 精度抑制: `log_rr_interval_width = null`, `rr_interval_fold_range = null`
2. **保守的区間抑制（再抽出反復内ゼロ発生: `undefined_replicates > 0L`）**:
   - 点推定値: 観測推定値 $\hat{\mathrm{RR}}_{\mathrm{obs}}$ を保持
   - 区間: `null`（無理なパーセンタイル算出を行わない）
   - 平均: `null`（`mean_is_finite = false`）
   - 診断コード: `relative_risk.diagnostic = "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"`
   - 精度抑制: `log_rr_interval_width = null`, `rr_interval_fold_range = null`
   - `rr_bootstrap_diagnostics`（`defined_fraction` 等）を記録

### 2.4 標準化平均差（SMD: Standardized Mean Difference）

ATT 重み（$w_{Tj} = 1, \; w_{Rj\ell} = 1 / k_j$）に基づく共変量 $X$ のバランス評価：
$$\mathrm{SMD} = \frac{\bar{X}_T - \bar{X}_{R, \mathrm{weighted}}}{\sqrt{\frac{s_T^2 + s_{R, \mathrm{weighted}}^2}{2}}}$$

プール標準偏差 $s_{\mathrm{pooled}} = 0$ の境界は 2 分岐する：

| 条件 | `smd_matched` | `status` |
| :--- | :--- | :--- |
| $s_{\mathrm{pooled}} = 0$ かつ平均差 $= 0$ | `0.0` | `ZERO_VARIANCE_ZERO_DIFFERENCE` |
| $s_{\mathrm{pooled}} = 0$ かつ平均差 $\ne 0$ | `null` | `ZERO_VARIANCE_NONZERO_DIFFERENCE` |
| $s_{\mathrm{pooled}} > 0$ | 上式の有限値 | `OK` |

---

## 3. IPTW（逆確率重み付け・PS 再適合ブートストラップ）

### 3.1 傾向スコアと重み付け定義

処置変数 $A_i \in \{0, 1\}$、共変量ベクトル $\mathbf{X}_i$ に対し、傾向スコア（Propensity Score: PS）をロジスティック回帰で推定する：
$$e_i = P(A_i = 1 \mid \mathbf{X}_i) = \frac{1}{1 + \exp(-\mathbf{X}_i^T \mathbf{\beta})}$$

境界保護のため、PS は事前にクランプ（Clamp）される：$e_i^* = \min(\max(e_i, \epsilon), 1 - \epsilon)$（既定: $\epsilon = 10^{-6}$）。

| エスティマンド | 非安定化重み（Unstabilized） | 安定化重み（Stabilized） |
| :--- | :--- | :--- |
| **ATE** | $w_i = \frac{A_i}{e_i} + \frac{1 - A_i}{1 - e_i}$ | $sw_i = A_i \frac{\bar{A}}{e_i} + (1 - A_i)\frac{1 - \bar{A}}{1 - e_i}$ |
| **ATT** | $w_i = A_i + (1 - A_i)\frac{e_i}{1 - e_i}$ | $sw_i = A_i + (1 - A_i)\frac{e_i}{1 - e_i}\frac{\bar{A}}{1 - \bar{A}}$ (Marginal Odds Scaled) |

### 3.2 Kish の有効標本サイズ（Effective Sample Size: ESS）

重み付けによる推定精度の低下度合いを Kish の近似式で監視する：
$$\mathrm{ESS}_g = \frac{\left( \sum_{i \in g} w_i \right)^2}{\sum_{i \in g} w_i^2}, \quad g \in \{0, 1\}$$

### 3.3 PS モデル再適合患者ブートストラップ（Refit Bootstrap）

PS 自体の推定誤差（不確実性）を適切に信頼区間に反映させるため、ブートストラップ反復ごとに以下の手順を再実行する：

1. 患者単位で有復元リサンプリング。
2. リサンプリング標本上でロジスティック回帰 PS モデルを再適合（`iptw_mode = "refit_ps"`）。
3. 重みの再計算および上下パーセンタイル刈り込み（既定: 1%〜99% Truncation）。
4. 加重リスク差および相対リスクの算出。

### 3.4 Positivity / Overlap・Clipping・Failure Provenance

runtime（`.agents/shared/iptw_inference.R`）および OpenSpec `comparative-design-inference` と一致する診断契約：

1. **PS 境界（clamp）**: `ps_boundary` 既定 `c(1e-6, 1 - 1e-6)`。出力は raw / effective PS と clipping 件数を保持する（`propensity_score_boundary_policy`）。
2. **Positivity / Overlap（`positivity`）**:
   - `raw_target_ps` / `raw_reference_ps` および `target_ps` / `reference_ps`（effective）の要約（min / q25 / median / mean / q75 / max）
   - `common_support`: raw 由来の `min` / `max` / `has_overlap`、および effective 由来の `effective_min` / `effective_max` / `effective_has_overlap`
   - overlap 判定の主根拠は **raw-score 分布**（OpenSpec: raw-score distributions SHALL drive positivity overlap diagnostics）
3. **Bootstrap clipping diagnostics**（`bootstrap_clipping_diagnostics`）: 成功した refit 反復について、clipping が発生した反復数・low/high clipped 合計・最大 clipped 割合を記録する。
4. **Failure provenance**: 設定可能な `max_failure_rate`（既定 `0.05`、区間 `[0, 1)`）。bootstrap がこの閾値を満たせない場合は fail-fast。draw / evidence metadata に `max_failure_rate` を搬送する。
5. **観測対照加重リスク 0**: Matched Set と同様に `relative_risk.diagnostic = "ZERO_REFERENCE_RISK"`、および `log_rr_interval_width` / `rr_interval_fold_range` を `null` 抑制。

> [!CAUTION]
> **擬似度数の独立推論器への投入禁止（`NON_INTEGER_COUNT`）**:
> IPTW で算出される加重イベント数 $\sum w_i Y_i$ は非整数（pseudo-counts）である。これを独立群用 Beta-Binomial や分割表推論器に入力してはならない。

---

## 4. 人年発症率（Person-Time Incidence Rates: Gamma-Poisson 推論）

### 4.1 観測モデルと共役尤度

各群 $g \in \{T, R\}$ において、観察期間の合計人時 $T_g$（人年または人月）とイベント発現数 $x_g$ を観測する。イベント発生は定常ポアソン過程に従うと仮定する：
$$x_g \mid \lambda_g \sim \mathrm{Poisson}(\lambda_g T_g)$$

尤度は以下で表される：
$$L(\lambda_g \mid x_g, T_g) \propto \lambda_g^{x_g} \exp(-\lambda_g T_g)$$

### 4.2 Jeffreys 非正格事前分布と事後分布

ポアソン強度の Jeffreys 事前分布は以下である：
$$p(\lambda_g) \propto \sqrt{I(\lambda_g)} = \frac{1}{\sqrt{\lambda_g}} = \lambda_g^{1/2 - 1} \exp(0)$$
これは shape-rate パラメータ表現（$\text{gamma\_parameterization} = \text{"shape\_rate"}$）における $\mathrm{shape} = 0.5, \; \mathrm{rate} = 0$ の広義 Gamma 核（Jeffreys 非正格事前分布 $\pi(\lambda) \propto \lambda^{-1/2}$）である。

共役性により、事後分布は閉形式の Gamma 分布となる：
$$\lambda_g \mid x_g, T_g \sim \mathrm{Gamma}\left(\text{shape} = x_g + \frac{1}{2}, \; \text{rate} = T_g\right)$$

### 4.3 率対比（Rate Contrasts）

事後ドロー $\lambda_T^{(s)}, \lambda_R^{(s)}$ から以下の指標を導出する：

- **発症率差（Incidence Rate Difference: IRD）**:
  $$\mathrm{IRD}^{(s)} = \lambda_T^{(s)} - \lambda_R^{(s)}$$
- **発症率比（Incidence Rate Ratio: IRR）**:
  $$\mathrm{IRR}^{(s)} = \frac{\lambda_T^{(s)}}{\lambda_R^{(s)}}$$
- **参照群ゼロ発生時（$x_R = 0$）の契約**:
  $x_R = 0$ のとき $\lambda_R \sim \mathrm{Gamma}(0.5, T_R)$ であり、$E[\lambda_R^{-1}] = \infty$ となるため、IRR の事後期待値は発散する。この場合、事後中央値と ETI を報告しつつ、`mean = null, mean_is_finite = false`、`incidence_rate_ratio$diagnostic = "ZERO_REFERENCE_EVENTS"` を確定する。

---

## 5. 一次文献（Primary References）

1. **Agresti, A. (2013)**. *Categorical Data Analysis* (3rd ed.). John Wiley & Sons. (Chapter 10: Matched Pairs).
2. **Abadie, A., & Imbens, G. W. (2008)**. "On the failure of the bootstrap for matching estimators." *Econometrica*, 76(6), 1537–1557.
3. **Austin, P. C. (2011)**. "An introduction to propensity score methods for reducing the effects of confounding in observational studies." *Multivariate Behavioral Research*, 46(3), 399–424.
4. **Kish, L. (1965)**. *Survey Sampling*. John Wiley & Sons. (Effective Sample Size).
5. **Cole, S. R., & Hernán, M. A. (2008)**. "Constructing inverse probability weights for marginal structural models." *American Journal of Epidemiology*, 168(6), 656–664.
