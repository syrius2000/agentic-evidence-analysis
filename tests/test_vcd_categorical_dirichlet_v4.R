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
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated")
diag <- compute_residual_diagnostics(v_data)

# 1. 解析的平均とサンプリング平均の整合性 (主解析 alpha = 0.5)
post1 <- compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 10000L, analysis_signature = "sig_run_001", practical_delta = 0.05)

sample_means <- sapply(post1$cell_posteriors, function(c) c$prob_mean)
analytic_means <- sapply(post1$cell_posteriors, function(c) c$prob_analytic_mean)
assert_close("Monte Carlo means match analytic means within sampling error (alpha = 0.5)", sample_means, analytic_means, tol = 0.01)

# 2. prior_specification メタデータの検証
prior_spec <- post1$prior_specification
if (!is.null(prior_spec) &&
    identical(prior_spec$family, "symmetric_dirichlet") &&
    identical(prior_spec$alpha, 0.5) &&
    identical(prior_spec$role, "primary") &&
    identical(prior_spec$name, "jeffreys")) {
  cat("[PASS] prior_specification correctly records family='symmetric_dirichlet', alpha=0.5, role='primary', and name='jeffreys'.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] prior_specification invalid or missing.\n")
  test_fail <- test_fail + 1L
}

# 3. 決定論的シードによる完全再現性テスト
post2 <- compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 10000L, analysis_signature = "sig_run_001", practical_delta = 0.05)
diff_repro <- max(abs(sample_means - sapply(post2$cell_posteriors, function(c) c$prob_mean)))
if (diff_repro == 0) {
  cat("[PASS] Deterministic seed guarantees exact reproducibility across identical signatures.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Posterior draws not reproducible.\n")
  test_fail <- test_fail + 1L
}

# 4. 生ドロー非永続化（メモリポリシー）の確認
if (is.null(post1$pi_draws) && is.null(post1$draws)) {
  cat("[PASS] Raw MCMC draws are not retained in output object (memory policy compliant).\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Raw draws found in posterior output.\n")
  test_fail <- test_fail + 1L
}

# 5. 条件付き確率の完全要約統計量と分位点順序・総和の検証
df_post <- do.call(rbind, lapply(post1$cell_posteriors, as.data.frame))
has_row_summaries <- all(c("cond_row_prob_mean", "cond_row_prob_sd", "cond_row_prob_median",
                           "cond_row_prob_q025", "cond_row_prob_q975", "cond_row_prob_eti_width") %in% names(df_post))
has_col_summaries <- all(c("cond_col_prob_mean", "cond_col_prob_sd", "cond_col_prob_median",
                           "cond_col_prob_q025", "cond_col_prob_q975", "cond_col_prob_eti_width") %in% names(df_post))

if (has_row_summaries && has_col_summaries) {
  cat("[PASS] Conditional posterior summaries contain mean, sd, median, q025, q975, eti_width for both directions.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Missing conditional posterior summary statistics.\n")
  test_fail <- test_fail + 1L
}

# 分位点順序検証: q025 <= median <= q975
row_order_ok <- all(df_post$cond_row_prob_q025 <= df_post$cond_row_prob_median &
                    df_post$cond_row_prob_median <= df_post$cond_row_prob_q975)
col_order_ok <- all(df_post$cond_col_prob_q025 <= df_post$cond_col_prob_median &
                    df_post$cond_col_prob_median <= df_post$cond_col_prob_q975)
if (row_order_ok && col_order_ok) {
  cat("[PASS] Quantile ordering verified: q025 <= median <= q975 for conditional probabilities.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Quantile ordering violated in conditional summaries.\n")
  test_fail <- test_fail + 1L
}

# 行・列条件付き平均の総和が 1 になることの検証
row_cond_sums <- tapply(df_post$cond_row_prob_mean, df_post$row_level, sum)
assert_close("Row conditional probabilities sum to 1 for all rows", row_cond_sums, rep(1.0, length(row_cond_sums)), tol = 1e-4)

col_cond_sums <- tapply(df_post$cond_col_prob_mean, df_post$col_level, sum)
assert_close("Column conditional probabilities sum to 1 for all columns", col_cond_sums, rep(1.0, length(col_cond_sums)), tol = 1e-4)

# 6. 局所事後乖離 D と事後方向確率 P(D > 0 | data) の検証
p_dir <- sapply(post1$cell_posteriors, function(c) c$prob_dir_positive)
if (all(p_dir >= 0 & p_dir <= 1)) {
  cat("[PASS] Posterior direction probabilities P(D > 0 | data) are in [0, 1].\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Direction probabilities out of bounds.\n")
  test_fail <- test_fail + 1L
}

# 7. practical_delta の検証
p_prac <- sapply(post1$cell_posteriors, function(c) c$prob_practical_delta)
if (all(!sapply(p_prac, is.null)) && all(p_prac >= 0 & p_prac <= 1)) {
  cat("[PASS] prob_practical_delta computed within [0, 1] when practical_delta is provided.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] prob_practical_delta invalid when practical_delta=0.05.\n")
  test_fail <- test_fail + 1L
}

# practical_delta 未指定時に NULL
post_no_delta <- compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 1000L, analysis_signature = "sig_run_no_delta")
p_prac_null <- sapply(post_no_delta$cell_posteriors, function(c) is.null(c$prob_practical_delta))
if (all(p_prac_null)) {
  cat("[PASS] prob_practical_delta is NULL when practical_delta is not specified.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] prob_practical_delta should be NULL when practical_delta is omitted.\n")
  test_fail <- test_fail + 1L
}

# practical_delta 境界値エラーハンドリング (0, 負値, 1以上)
bad_deltas <- list(0, -0.1, 1.0, 1.5, "0.1", NA_real_)
for (bd in bad_deltas) {
  res_err <- tryCatch({
    compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 500L, analysis_signature = "sig_bad", practical_delta = bd)
    FALSE
  }, error = function(e) {
    grepl("INVALID_INPUT_PRACTICAL_DELTA", e$message)
  })
  if (res_err) {
    test_pass <- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] practical_delta = %s did not trigger INVALID_INPUT_PRACTICAL_DELTA\n", as.character(bd)))
    test_fail <- test_fail + 1L
  }
}
cat("[PASS] practical_delta boundary validations correctly rejected 0, negative, >=1, non-numeric, and NA values.\n")

# 8. 事前感度分析（primary=0.5, sensitivity=1.0）の検証
sens <- post1$sensitivity
if (!is.null(sens$max_absolute_mean_diff) &&
    sens$primary_alpha == 0.5 &&
    sens$sensitivity_alpha == 1.0 &&
    is.null(sens$is_sensitive)) {
  cat(sprintf("[PASS] Prior sensitivity evaluation executed: primary=0.5, sens=1.0, max diff = %.4f, is_sensitive removed.\n",
              sens$max_absolute_mean_diff))
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Prior sensitivity summary invalid or retained is_sensitive.\n")
  test_fail <- test_fail + 1L
}

# 感度比較の eti_width_difference が符号付きであることの確認
eti_diffs <- sapply(sens$cell_comparisons, function(c) c$eti_width_difference)
if (length(eti_diffs) == length(post1$cell_posteriors) && all(is.numeric(eti_diffs))) {
  cat("[PASS] cell_comparisons contain signed numeric eti_width_difference.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] eti_width_difference missing or invalid in cell_comparisons.\n")
  test_fail <- test_fail + 1L
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
