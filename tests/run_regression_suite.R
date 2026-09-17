#!/usr/bin/env Rscript
# tests/run_regression_suite.R
# 本リポジトリの正規回帰テストスイート一括実行スクリプト
# 実行時の外部ネットワーク接続なしで、決定論的に全テストが通過することを検証する。

ca   <- commandArgs(trailingOnly = FALSE)
fa   <- ca[grep("^--file=", ca)]
root <- if (length(fa) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", fa[1]))))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, ".agents")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), winslash = "/", mustWork = TRUE)
}

# 正規回帰テスト対象リスト
official_tests <- c(
  "tests/test_dependency_check.R",
  "tests/test_dependency_isolation_pass1.R",
  "tests/test_inspect_data_out_dir.R",
  "tests/test_vcd_categorical_modular_logic.R",
  "tests/test_vcd_categorical_input_boundary.R",
  "tests/test_vcd_categorical_smoke.R",
  "tests/test_questionnaire_batch_smoke.R",
  "tests/test_questionnaire_batch_ucbadmissions.R",
  "tests/test_questionnaire_backup_recovery.R",
  "tests/test_summary_csv_new_columns.R",
  "tests/test_questionnaire_duplicate_output_slug.R",
  "tests/test_questionnaire_marginal_strata_contract.R",
  "tests/test_questionnaire_symlink_escape.R",
  "tests/test_security_skill_references.R",
  "tests/test_three_way_computation_engine.R",
  "tests/test_three_way_inspection_sha_contract.R",
  "tests/test_sas_proc_means_numerical_parity.R",
  "tests/test_vcd_interpretation_guide.R",
  "tests/test_vcd_residual_plot_order.R",
  "tests/test_vcd_categorical_template_assoc_shade.R",
  "tests/test_vcd_categorical_template_residual_layout.R",
  "tests/test_vcd_dashboard_layout_integration.R",
  "tests/test_vcd_bayesian_dashboard_html_asis.R",
  "tests/test_vcd_bayesian_dt_filter_factor.R",
  "tests/test_vcd_bayesian_pass2_stub.R"
)

cat("========================================================\n")
cat("正規回帰テストスイート実行開始 (オフライン決定論的検証)\n")
cat(sprintf("対象テスト数: %d 本\n", length(official_tests)))
cat("========================================================\n\n")

results <- data.frame(
  test_file = official_tests,
  status = "UNKNOWN",
  elapsed_sec = 0.0,
  stringsAsFactors = FALSE
)

total_start <- Sys.time()

for (i in seq_along(official_tests)) {
  tf <- official_tests[i]
  full_path <- file.path(root, tf)
  if (!file.exists(full_path)) {
    results$status[i] <- "NOT_FOUND"
    cat(sprintf("[%2d/%2d] %-55s ... NOT FOUND\n", i, length(official_tests), tf))
    next
  }

  t0 <- Sys.time()
  res <- suppressWarnings(system2("Rscript", c(full_path), stdout = TRUE, stderr = TRUE))
  status <- attr(res, "status")
  if (is.null(status)) status <- 0L
  t1 <- Sys.time()
  results$elapsed_sec[i] <- round(as.numeric(difftime(t1, t0, units = "secs")), 2)

  if (identical(as.integer(status), 0L)) {
    results$status[i] <- "PASS"
    cat(sprintf("[%2d/%2d] %-55s ... PASS (%.2fs)\n", i, length(official_tests), tf, results$elapsed_sec[i]))
  } else {
    results$status[i] <- "FAIL"
    cat(sprintf("[%2d/%2d] %-55s ... FAIL (exit %d, %.2fs)\n", i, length(official_tests), tf, status, results$elapsed_sec[i]))
    # エラー行を少し表示
    err_lines <- grep("Error", res, value = TRUE)
    if (length(err_lines) > 0) {
      cat(sprintf("       -> %s\n", tail(err_lines, 1)))
    }
  }
}

total_elapsed <- round(as.numeric(difftime(Sys.time(), total_start, units = "secs")), 2)

cat("\n========================================================\n")
cat("実行サマリー:\n")
cat(sprintf("  総テスト数: %d\n", nrow(results)))
cat(sprintf("  成功 (PASS): %d\n", sum(results$status == "PASS")))
cat(sprintf("  失敗 (FAIL): %d\n", sum(results$status == "FAIL")))
cat(sprintf("  未検出 (NOT_FOUND): %d\n", sum(results$status == "NOT_FOUND")))
cat(sprintf("  総所要時間: %.2f 秒\n", total_elapsed))
cat("========================================================\n")

if (any(results$status != "PASS")) {
  stop("正規回帰テストスイートに失敗項目があります")
} else {
  cat("\n全正規回帰テストが正常に通過しました（オフライン決定論的動作を確認）。\n")
}
