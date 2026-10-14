#!/usr/bin/env Rscript
# tests/test_questionnaire_subset_expr_failure.R
# TDD RED: subset_expr の不正（構文エラー、未定義変数、非logical、長さ不一致）時に
# 当該設問が failed となり理由が記録され、他設問は成功し、全行 TRUE にフォールバックしないことを検証する。

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

temp_dir <- tempfile("test_subset_expr_")
dir.create(temp_dir, recursive = TRUE)

test_id <- paste0("sub_", format(Sys.time(), "%H%M%S"), "_", Sys.getpid())
out_root <- file.path(repo_root, "evidence_runs", "questionnaire", paste0(".test_sub_", Sys.getpid()))
out_dir <- file.path(out_root, paste0("run_", test_id))

cleanup <- function() {
  if (dir.exists(temp_dir)) {
    unlink(temp_dir, recursive = TRUE, force = TRUE)
  }
  if (dir.exists(out_root)) {
    unlink(out_root, recursive = TRUE, force = TRUE)
  }
}

tryCatch({
  # テスト用データ作成 (subset後も2x2を維持する)
  df_test <- data.frame(
    id = 1:20,
    grp = rep(c("A", "B"), each = 10),
    q1 = rep(c("Yes", "No", "No", "Yes"), 5),
    val = 1:20,
    stringsAsFactors = FALSE
  )
  data_csv <- file.path(temp_dir, "data.csv")
  write.csv(df_test, data_csv, row.names = FALSE)

  # テスト用 question_config 作成（正常設問と不正設問）
  cfg <- data.frame(
    survey_id = rep("SURVEY_01", 5),
    question_id = c("Q1_VALID", "Q2_SYNTAX_ERR", "Q3_UNKNOWN_VAR", "Q4_NON_LOGICAL", "Q5_LENGTH_MISMATCH"),
    question_label = c("Valid Question", "Syntax Error", "Unknown Var", "Non Logical", "Length Mismatch"),
    analysis_type = rep("nominal_2way", 5),
    var1 = rep("grp", 5),
    var2 = rep("q1", 5),
    var3 = rep(NA_character_, 5),
    subset_expr = c(
      "id %% 2 == 0",
      "grp == 'A' &&& (",
      "non_existent_var > 0",
      "val + 10",
      "c(TRUE, FALSE)"
    ),
    na_policy = rep("drop", 5),
    ordered_levels = rep(NA_character_, 5),
    reference_note = rep(NA_character_, 5),
    output_slug = c("q1_valid", "q2_syntax", "q3_unknown", "q4_non_logical", "q5_len_mismatch"),
    stringsAsFactors = FALSE
  )
  cfg_csv <- file.path(temp_dir, "question_config.csv")
  write.csv(cfg, cfg_csv, row.names = FALSE)

  runner_path <- file.path(repo_root, ".agents", "skills", "questionnaire-batch-analysis", "templates", "batch_runner.R")

  cmd <- sprintf('Rscript --vanilla "%s" --data "%s" --question-config "%s" --out "%s" --run-id "%s"',
                 runner_path, data_csv, cfg_csv, out_root, test_id)

  status <- system(cmd)

  summary_csv <- file.path(out_dir, "summary.csv")
  if (!file.exists(summary_csv)) {
    stop(sprintf("[FAIL] summary.csv was not generated at %s", summary_csv))
  }

  summary_df <- read.csv(summary_csv, stringsAsFactors = FALSE)

  # 1. Q1_VALID は成功していること
  q1_row <- summary_df[summary_df$question_id == "Q1_VALID", ]
  if (nrow(q1_row) != 1L || q1_row$status != "success") {
    stop(sprintf("[FAIL] Q1_VALID expected status 'success', got '%s'", q1_row$status))
  }

  # 2. 不正な subset_expr を持つ設問はすべて error (failed) であること
  failed_ids <- c("Q2_SYNTAX_ERR", "Q3_UNKNOWN_VAR", "Q4_NON_LOGICAL", "Q5_LENGTH_MISMATCH")
  for (qid in failed_ids) {
    q_row <- summary_df[summary_df$question_id == qid, ]
    if (nrow(q_row) != 1L) {
      stop(sprintf("[FAIL] Question %s missing from summary.csv", qid))
    }
    if (q_row$status != "error") {
      stop(sprintf("[FAIL] Question %s expected status 'error', got '%s'", qid, q_row$status))
    }
    if (is.na(q_row$error_message) || !nzchar(q_row$error_message)) {
      stop(sprintf("[FAIL] Question %s missing error_message", qid))
    }
  }

  cat("[PASS] test_questionnaire_subset_expr_failure.R: All subset_expr failure modes verified.\n")
}, finally = {
  cleanup()
})
