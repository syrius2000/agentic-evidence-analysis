# test_vcd_categorical_dirichlet_v4.R — Dirichlet Posterior & Generated Quantities Test Suite

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R")

test_pass <- 0L
test_fail <- 0L

assert_close <- function(desc, actual, expected, tol = 1e-4) {
  diff <- max(abs(actual - expected), na.rm = TRUE)
  if (diff <= tol) {
    cat(sprintf("[PASS] %s (diff = %.2e <= %.2e)\n", desc, diff, tol))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s: Expected %.6f, got %.6f (diff = %.2e)\n", desc, expected[1], actual[1], diff))
    test_fail <<- test_fail + 1L
  }
}

cat("=== Starting Dirichlet Posterior Tests ===\n")

d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq")
diag <- compute_residual_diagnostics(v_data)

# 1. 解析的平均とサンプリング平均の整合性
post1 <- compute_dirichlet_posterior(diag, alpha = 1.0, n_draws = 10000L, analysis_signature = "sig_run_001")

sample_means <- sapply(post1$cell_posteriors, function(c) c$prob_mean)
analytic_means <- sapply(post1$cell_posteriors, function(c) c$prob_analytic_mean)
assert_close("Monte Carlo means match analytic means within sampling error", sample_means, analytic_means, tol = 0.01)

# 2. 決定論的シードによる完全再現性テスト
post2 <- compute_dirichlet_posterior(diag, alpha = 1.0, n_draws = 10000L, analysis_signature = "sig_run_001")
diff_repro <- max(abs(sample_means - sapply(post2$cell_posteriors, function(c) c$prob_mean)))
if (diff_repro == 0) {
  cat("[PASS] Deterministic seed guarantees exact reproducibility across identical signatures.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Posterior draws not reproducible.\n")
  test_fail <- test_fail + 1L
}

# 3. 生ドロー非永続化（メモリポリシー）の確認
if (is.null(post1$pi_draws) && is.null(post1$draws)) {
  cat("[PASS] Raw MCMC draws are not retained in output object (memory policy compliant).\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Raw draws found in posterior output.\n")
  test_fail <- test_fail + 1L
}

# 4. 条件付き確率の総和が 1 になることの検証
# 行ごとに cond_row_prob_mean の和をチェック
df_post <- do.call(rbind, lapply(post1$cell_posteriors, as.data.frame))
row_cond_sums <- tapply(df_post$cond_row_prob_mean, df_post$row_level, sum)
assert_close("Row conditional probabilities sum to 1 for all rows", row_cond_sums, rep(1.0, length(row_cond_sums)), tol = 1e-4)

col_cond_sums <- tapply(df_post$cond_col_prob_mean, df_post$col_level, sum)
assert_close("Column conditional probabilities sum to 1 for all columns", col_cond_sums, rep(1.0, length(col_cond_sums)), tol = 1e-4)

# 5. 局所事後乖離 D と事後方向確率 P(D > 0 | data) の検証
p_dir <- sapply(post1$cell_posteriors, function(c) c$prob_dir_positive)
if (all(p_dir >= 0 & p_dir <= 1)) {
  cat("[PASS] Posterior direction probabilities P(D > 0 | data) are in [0, 1].\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Direction probabilities out of bounds.\n")
  test_fail <- test_fail + 1L
}

# 6. 事前感度分析（alpha=0.5）の検証
sens <- post1$sensitivity
if (!is.null(sens$max_absolute_mean_diff) && sens$primary_alpha == 1.0 && sens$sensitivity_alpha == 0.5) {
  cat(sprintf("[PASS] Prior sensitivity evaluation executed: max diff = %.4f, is_sensitive = %s\n",
              sens$max_absolute_mean_diff, sens$is_sensitive))
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Prior sensitivity summary invalid.\n")
  test_fail <- test_fail + 1L
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
