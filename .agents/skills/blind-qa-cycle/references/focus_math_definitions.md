# Focus pack: math-definitions

Use when the invite lists `math-definitions`.

## 重点監査観点（Audit Criteria）

特に【数学的定義の整合性】の観点から厳格に検証してください：

1. **比較エビデンス推論の数理整合性 (`docs/reference/comparative_evidence_math.md`)**:
   - 独立 Jeffreys Beta-Binomial 事後分布（$\mathrm{Beta}(x_g+0.5, n_g-x_g+0.5)$）の定式化と非整数カウント拒絶契約（`NON_INTEGER_COUNT`）の妥当性。
   - 6大対比（RD, RR, E100, reciprocal RD, 方向支持, ETI）の定義、およびベイズ事後中央値（`posterior_median`）とリサンプリング推定量（`observed_sample_estimate`）の点推定ソース契約。
   - reciprocal RD（$1/|\mathrm{RD}|$）の決定論的状態機械（`STABLE_DIRECTION`, `SIGN_AMBIGUOUS`, `RD_NEAR_ZERO`、NNH/NNT 表記）の数学的安定性。
   - 参照群ゼロイベント（$x_R = 0$）時の理論的無限大期待値（$E(RR) = \infty$）契約（`mean = null, mean_is_finite = false`）の正確さ。
   - 実務領域（$q_T, q_N, q_R$）と不確実性解像度 U-Grade（U0〜U3）の数理的定義が、臨床的重症度や標本サイズと直交・分離されているか。
   - 12 列ダッシュボード提示階層のデータ契約。

2. **デザイン考慮型比較推論の数理整合性 (`docs/reference/design_aware_inference_math.md`)**:
   - 1:1 Matched Pairs: 4セル多項 Jeffreys Dirichlet 事後推論、McNemar オッズ比 $\mathrm{OR}_{\mathrm{discordant}}$、Dirichlet 解析的厳密期待値 $E[\mathrm{OR}_{\mathrm{discordant}}] = (n_{10}+0.5)/(n_{01}-0.5)$、およびペア内一致連関 $\mathrm{OR}_{\mathrm{assoc}}$ の分離。
   - 1:k Matched Sets: ATT エスティマンド、固定条件付き原子クラスタブートストラップ（Abadie & Imbens 2008 の留意点）、ゼロ除算 RR 保守ポリシー、加重 SMD。
   - IPTW: ATE / ATT（非安定化・安定化 marginal odds scaled）、Kish 有効標本サイズ（ESS）、PS モデル再適合患者ブートストラップ、Positivity / Overlap 診断と PS クランプ、非整数度数拒絶原則。
   - 人年発症率: 共役 Gamma-Poisson 率モデル（Jeffreys 非正格事前分布 $p(\lambda) \propto \lambda^{-1/2} \implies \mathrm{Gamma}(x_g+0.5, T_g)$）、IRD / IRR、ゼロイベント契約。

3. **コードベース実装との一次情報完全照合**:
   - `.agents/shared/independent_beta_binomial.R`, `comparative_contrasts.R`, `matched_pair_dirichlet.R`, `matched_set_inference.R`, `iptw_inference.R`, `person_time_rate.R` の実装コードと、数理文書の式・定数名・エラーコードが 100% 一致しているか。

## Reviewer notes

- Prefer OpenSpec + runtime as source of truth when docs diverge; report doc drift as Findings.
- Do not dump long catalogs of formulas that already match; Findings-only in `01_review.md`.
