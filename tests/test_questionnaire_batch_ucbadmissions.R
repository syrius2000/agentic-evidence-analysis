#!/usr/bin/env Rscript
# tests/test_questionnaire_batch_ucbadmissions.R
# UCBAdmissions を questionnaire-batch-analysis に流したときの最小再現テスト
# 実行: Rscript tests/test_questionnaire_batch_ucbadmissions.R

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
  pacman::p_load(datasets)
})

ca <- commandArgs(trailingOnly = FALSE)
fa <- ca[grep("^--file=", ca)]
root <- if (length(fa) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", fa[1]))))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), winslash = "/", mustWork = TRUE)
}

runner_path <- file.path(
  root,
  ".agent",
  "skills",
  "questionnaire-batch-analysis",
  "templates",
  "batch_runner.R"
)
default_out_dir <- file.path(root, "skill_out", "questionnaire")
tmp_dir <- file.path(tempdir(), "questionnaire_ucbadmissions")
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

data_path <- file.path(tmp_dir, "ucbadmissions_expanded.csv")
config_path <- file.path(tmp_dir, "question_config_ucb.csv")

ucb <- as.data.frame(UCBAdmissions)
expanded <- ucb[rep(seq_len(nrow(ucb)), ucb$Freq), c("Admit", "Gender", "Dept")]
utils::write.csv(expanded, data_path, row.names = FALSE, quote = TRUE)

config_lines <- c(
  "survey_id,question_id,analysis_type,var1,var2,var3,output_slug,question_label,subset_expr,na_policy,ordered_levels,reference_note",
  "ucbadmissions,q01_admit_gender,nominal_2way,Admit,Gender,,q01_admit_gender,UCBAdmissions Admit x Gender,,drop,,2-way check",
  "ucbadmissions,q02_admit_gender_dept,nominal_3way,Admit,Gender,Dept,q02_admit_gender_dept,UCBAdmissions Admit x Gender x Dept,,drop,,3-way check"
)
writeLines(config_lines, config_path, useBytes = TRUE)

if (dir.exists(default_out_dir)) {
  unlink(default_out_dir, recursive = TRUE, force = TRUE)
}

cmd <- sprintf(
  'cd "%s" && Rscript --vanilla "%s" --data "%s" --question-config "%s"',
  root,
  runner_path,
  data_path,
  config_path
)

cat("=== questionnaire-batch-analysis UCBAdmissions regression test ===\n")
cat("runner :", runner_path, "\n")
cat("data   :", data_path, "\n")
cat("config :", config_path, "\n")
cat("out    :", default_out_dir, "\n\n")
cat("Running:", cmd, "\n\n")

ret <- system(cmd)

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
check("default output directory created", dir.exists(default_out_dir))

summary_csv <- list.files(default_out_dir, pattern = "^summary\\.csv$", full.names = TRUE, recursive = TRUE)
check("summary.csv exists in default output directory", length(summary_csv) == 1L && file.exists(summary_csv[1L]))
summary_csv <- summary_csv[1L]
run_root <- dirname(summary_csv)

if (file.exists(summary_csv)) {
  s <- read.csv(summary_csv, stringsAsFactors = FALSE, na.strings = "")

  check("summary.csv has 2 rows", nrow(s) == 2L)
  check("all rows status = success", all(s$status == "success", na.rm = TRUE))
  check("n_total is filled", all(!is.na(s$n_total)))
  check("n_used is filled", all(!is.na(s$n_used)))
  check("statistic_value is filled", all(!is.na(s$statistic_value)))
  check("p_value is filled", all(!is.na(s$p_value)))
  check("max_abs_pearson_res is filled", all(!is.na(s$max_abs_pearson_res)))

  # mosaic_rendered: UCBAdmissions q01 = 2x2 (4 cells <= 16) → TRUE
  #                  UCBAdmissions q02 = 2x2x6 (24 cells <= 36) → TRUE
  check("mosaic_rendered column exists", "mosaic_rendered" %in% names(s))
  check("assoc_rendered column exists", "assoc_rendered" %in% names(s))
  check("skip_reason column exists", "skip_reason" %in% names(s))
  if ("mosaic_rendered" %in% names(s)) {
    check("q01 2x2 mosaic_rendered = TRUE (4 cells <= 16)", isTRUE(s$mosaic_rendered[s$question_id == "q01_admit_gender"]))
    check("q02 2x2x6 mosaic_rendered = TRUE (24 cells <= 36)", isTRUE(s$mosaic_rendered[s$question_id == "q02_admit_gender_dept"]))
  }

  q_slugs <- c("q01_admit_gender", "q02_admit_gender_dept")
  for (slug in q_slugs) {
    check(
      sprintf("questionnaire_results.json exists in default dir: %s", slug),
      file.exists(file.path(run_root, slug, "questionnaire_results.json"))
    )
  }

  for (slug in q_slugs) {
    check(
      sprintf("residual_plot.png exists in default dir: %s", slug),
      file.exists(file.path(run_root, slug, "figures", "residual_plot.png"))
    )
  }

  cat("\n--- summary.csv preview ---\n")
  print(s[, c("question_id", "status", "error_message", "report_path")])
}

cat("\n===============================\n")
cat(sprintf("Results: %d passed, %d failed\n", pass, fail))
if (fail > 0L) quit(status = 1L) else quit(status = 0L)
