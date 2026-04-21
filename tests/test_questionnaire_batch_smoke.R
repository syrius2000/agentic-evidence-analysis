#!/usr/bin/env Rscript
# tests/test_questionnaire_batch_smoke.R
# questionnaire-batch-analysis スキルの smoke テスト
# 実行: Rscript tests/test_questionnaire_batch_smoke.R
#
# 前提: tests/sample_survey.csv, tests/question_config_test.csv が存在すること
# 出力先: tests/skill_out_smoke/ (テスト後も残すので手動削除可)

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
  pacman::p_load(optparse, rmarkdown)
})

# ---- パス解決 ----
ca   <- commandArgs(trailingOnly = FALSE)
fa   <- ca[grep("^--file=", ca)]
root <- if (length(fa) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", fa[1]))))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), winslash = "/", mustWork = TRUE)
}

data_path    <- file.path(root, "tests", "sample_survey.csv")
config_path  <- file.path(root, "tests", "question_config_test.csv")
runner_path  <- file.path(root, ".agent", "skills", "questionnaire-batch-analysis",
                          "templates", "batch_runner.R")
out_dir      <- file.path(root, "tests", "skill_out_smoke")

stopifnot(file.exists(data_path))
stopifnot(file.exists(config_path))
stopifnot(file.exists(runner_path))

cat("=== questionnaire-batch-analysis smoke test ===\n")
cat("data   :", data_path, "\n")
cat("config :", config_path, "\n")
cat("runner :", runner_path, "\n")
cat("out    :", out_dir, "\n\n")

# ---- バッチ実行 ----
cmd <- sprintf(
  'Rscript --vanilla "%s" --data "%s" --question-config "%s" --out "%s"',
  runner_path, data_path, config_path, out_dir
)
cat("Running:", cmd, "\n\n")
ret <- system(cmd)

# ---- 結果検証 ----
pass <- 0L
fail <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    cat("[PASS]", label, "\n")
    pass <<- pass + 1L
  } else {
    cat("[FAIL]", label, "\n")
    fail <<- fail + 1L
  }
}

check("batch_runner returned exit 0", ret == 0L)

summary_csv <- list.files(out_dir, pattern = "^summary\\.csv$", full.names = TRUE, recursive = TRUE)
check("summary.csv exists", length(summary_csv) == 1L && file.exists(summary_csv[1L]))
summary_csv <- summary_csv[1L]
run_root <- dirname(summary_csv)

if (file.exists(summary_csv)) {
  s <- read.csv(summary_csv, stringsAsFactors = FALSE, na.strings = "")

  expected_cols <- c(
    "run_id","survey_id","question_id","analysis_type","n_total","n_used","n_missing",
    "model_name","statistic_value","p_value","effect_value",
    "cramer_v_marginal","cramer_v_df_star","cramer_v_effect_label",
    "cramer_v_strata_json","cramer_v_strata_mean","cramer_v_strata_max",
    "cramer_v_strata_max_level","marginal_strata_signal","marginal_strata_note",
    "max_abs_pearson_res","max_residual_cell",
    "mosaic_rendered","assoc_rendered","skip_reason","residual_plot_mode",
    "report_path","status"
  )
  check("summary.csv has expected columns",
        all(expected_cols %in% names(s)))

  check("summary.csv has 3 rows (one per question)",
        nrow(s) == 3L)

  check("all rows status = success",
        all(s$status == "success", na.rm = TRUE))

  check("n_total is filled (not NA)",
        all(!is.na(s$n_total)))

  check("n_used is filled (not NA)",
        all(!is.na(s$n_used)))

  check("statistic_value is filled",
        all(!is.na(s$statistic_value)))

  check("p_value is filled",
        all(!is.na(s$p_value)))

  check("max_abs_pearson_res is filled",
        all(!is.na(s$max_abs_pearson_res)))

  check("max_residual_cell is filled",
        all(!is.na(s$max_residual_cell) & nzchar(s$max_residual_cell)))

  q_slugs <- c("q01_gender_dept", "q02_satisfaction_age", "q03_waiting_dept_time")
  for (slug in q_slugs) {
    rpath <- file.path(run_root, slug, "report.html")
    check(sprintf("report.html exists: %s", slug), file.exists(rpath))
    jpath <- file.path(run_root, slug, "questionnaire_results.json")
    if (file.exists(jpath)) {
      check(sprintf("questionnaire_results.json exists: %s", slug), TRUE)
    }
  }

  # 残差プロットの存在確認
  for (slug in q_slugs) {
    ppath <- file.path(run_root, slug, "figures", "residual_plot.png")
    check(sprintf("residual_plot.png exists: %s", slug), file.exists(ppath))
  }

  # summary 内容確認
  check("residual_plot_mode is filled",
        all(!is.na(s$residual_plot_mode) & nzchar(s$residual_plot_mode)))
  check("residual_plot_mode values are valid",
        all(s$residual_plot_mode %in% c("dotplot", "heatmap", "facet_heatmap")))

  cat("\n--- summary.csv preview ---\n")
  print(s[, c("question_id","n_total","n_used","p_value","max_abs_pearson_res","residual_plot_mode","status")])
}

cat("\n===============================\n")
cat(sprintf("Results: %d passed, %d failed\n", pass, fail))
if (fail > 0L) quit(status = 1L) else quit(status = 0L)
