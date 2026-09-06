#!/usr/bin/env Rscript
# tests/statistical_foundations/test_section5_bayesian.R
# Section 5: ベイズDirichlet事後推定・MCSE校正・条件付き割合差・PPC・厳密BF検証テスト

source("tests/statistical_foundations/calibrate_bayesian.R")

message("=== Testing Section 5: Bayesian Dirichlet Calibration, Conditional Rates & Exact BF ===")

df_titanic <- readr::read_csv("tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv", show_col_types = FALSE)
y <- df_titanic$Freq
N <- sum(y)
K <- length(y)

# 1. 解析的Dirichlet事後推定 (a = 1.0, 0.1, 10.0)
message("--- Step 1: Dirichlet Posterior Analysis (a = 1.0, 0.1, 10.0) ---")
post_1 <- compute_analytical_dirichlet_posterior(y, total_alpha = 1.0)
post_01 <- compute_analytical_dirichlet_posterior(y, total_alpha = 0.1)
post_10 <- compute_analytical_dirichlet_posterior(y, total_alpha = 10.0)

stopifnot(length(post_1$mean) == 16L)
stopifnot(all(post_1$ci_95_lower < post_1$mean & post_1$mean < post_1$ci_95_upper))
message(sprintf("  Cell 1 (y=%d): a=1.0 mean=%.4f (95%% CI: [%.4f, %.4f])",
                y[1], post_1$mean[1], post_1$ci_95_lower[1], post_1$ci_95_upper[1]))

# 2. 20,000回 モンテカルロ校正（MCSE基準 & 二項SE基準）
message("--- Step 2: 20,000 MC Draws Calibration (MCSE & Binomial SE Criteria) ---")
tol <- list(mcse_factor = 3.0, coverage_se_factor = 3.0)
mc_calib <- sample_and_calibrate_dirichlet(y, total_alpha = 1.0, n_draws = 20000L, seed = 20260906L, tolerances = tol)

message(sprintf("  MC Max Mean Abs Diff: %.6f (Max MCSE: %.6f, Threshold: %.6f)",
                mc_calib$max_mean_abs_diff, mc_calib$max_mc_se, 3.0 * mc_calib$max_mc_se))
message(sprintf("  MC Max Coverage Prob Diff: %.4f (Threshold: %.4f)",
                mc_calib$max_coverage_prob_diff, mc_calib$cov_threshold))
message(sprintf("  Mean Calibration Passed (MCSE 3-sigma): %s", mc_calib$mean_calibration_passed))
message(sprintf("  Coverage Calibration Passed (Binomial SE 3-sigma): %s", mc_calib$coverage_calibration_passed))
stopifnot(mc_calib$calibration_passed == TRUE)
stopifnot(mc_calib$mean_calibration_passed == TRUE)
stopifnot(mc_calib$coverage_calibration_passed == TRUE)

# 3. 条件付き割合および層間差の事後推定
message("--- Step 3: Conditional Rates & Pairwise Differences (Survived | Class, Sex) ---")
cond_diffs <- compute_conditional_posterior_differences(
  df_titanic, c("Class", "Sex", "Survived"), "Survived", mc_calib$p_draws_matrix, target_response_level = "Yes"
)

stopifnot(cond_diffs$strata_count == 8L) # 4 Class x 2 Sex = 8 strata
message(sprintf("  Evaluated %d strata conditional survival rates", cond_diffs$strata_count))

# 1st Female vs 3rd Female の生存率差の確認
pair_1f_3f <- cond_diffs$pairwise_rate_differences[["1st.Female_vs_minus_vs_3rd.Female"]]
if (!is.null(pair_1f_3f)) {
  message(sprintf("  1st Female vs 3rd Female Survival Rate Diff: Mean=%.3f, 95%% CI=[%.3f, %.3f], P(Diff > 0)=%.4f",
                  pair_1f_3f$difference_mean, pair_1f_3f$ci_95_lower, pair_1f_3f$ci_95_upper, pair_1f_3f$prob_greater_than_zero))
  # 1等女性の生存率は3等女性より高いことが圧倒的事後確率で支持されるはず
  stopifnot(pair_1f_3f$difference_mean > 0.3)
  stopifnot(pair_1f_3f$prob_greater_than_zero > 0.999)
}

# 4. 事後予測チェック (PPC)
message("--- Step 4: Posterior Predictive Check (Freeman-Tukey) ---")
ppc <- posterior_predictive_check(y, total_alpha = 1.0, n_draws = 2000L, seed = 20260906L)
message(sprintf("  Mean T_obs: %.2f, Mean T_rep: %.2f, PPP-value: %.3f",
                ppc$mean_t_obs, ppc$mean_t_rep, ppc$posterior_predictive_p_value))
stopifnot(ppc$posterior_predictive_p_value > 0.1 && ppc$posterior_predictive_p_value < 0.9)

# 5. 厳密周辺尤度と Bayes Factor (独立 vs 飽和) の独立アサーション
message("--- Step 5: Exact Marginal Likelihood and Bayes Factor Validations ---")
# 5.1 Titanic (強い関連・交互作用あり -> 飽和モデルが圧倒的支持)
bf_titanic <- compute_exact_marginal_likelihoods_and_bf(df_titanic, c("Class", "Sex", "Survived"), "Freq", total_alpha = 1.0)
message(sprintf("  Titanic Log Marginal (Sat): %.2f, (Ind): %.2f, Log BF (Sat vs Ind): %.2f",
                bf_titanic$log_marginal_likelihood_saturated,
                bf_titanic$log_marginal_likelihood_independent,
                bf_titanic$log_bf_exact_sat_vs_ind))
stopifnot(bf_titanic$log_bf_exact_sat_vs_ind > 400) # 飽和モデルが極めて強く支持される

# 5.2 人工独立表 (syn_independent: 真に独立 -> 独立モデルが支持される)
df_syn_ind <- readr::read_csv("tests/fixtures/statistical_foundations/syn_independent.csv", show_col_types = FALSE)
bf_syn_ind <- compute_exact_marginal_likelihoods_and_bf(df_syn_ind, c("A", "B", "C"), "Freq", total_alpha = 1.0)
message(sprintf("  syn_independent Log Marginal (Sat): %.2f, (Ind): %.2f, Log BF (Sat vs Ind): %.2f",
                bf_syn_ind$log_marginal_likelihood_saturated,
                bf_syn_ind$log_marginal_likelihood_independent,
                bf_syn_ind$log_bf_exact_sat_vs_ind))
# 独立表では、独立モデルが飽和モデルより支持されるため、Log BF (Sat vs Ind) < 0 となる！
stopifnot(bf_syn_ind$log_bf_exact_sat_vs_ind < 0)
stopifnot(bf_syn_ind$log_bf_exact_ind_vs_sat > 0)
message("  -> [PASS] 人工独立表で独立モデルの厳密支持 (Log BF_ind_vs_sat > 0) を確認")

message("\n=== Section 5 テスト 全件合格 ===")
