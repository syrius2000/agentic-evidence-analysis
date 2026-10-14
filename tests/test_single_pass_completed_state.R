#!/usr/bin/env Rscript
# tests/test_single_pass_completed_state.R
# Task 4.1: vcd-categorical-reporting and evidence-decision-review completed run_state test

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))
source(file.path(repo_root, ".agents", "shared", "iptw_inference.R"))
source(file.path(repo_root, ".agents", "shared", "independent_beta_binomial.R"))
source(file.path(repo_root, ".agents", "shared", "evidence_feature_extract.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-reporting", "comparative_reporting.R"))

test_dir_rep <- file.path(repo_root, "evidence_runs/vcd_categorical_reporting", paste0("test_state_", Sys.getpid()))
test_dir_edr <- file.path(repo_root, "evidence_runs/evidence_decision_review", paste0("test_state_", Sys.getpid()))

cleanup <- function() {
  if (dir.exists(test_dir_rep)) {
    unlink(test_dir_rep, recursive = TRUE, force = TRUE)
  }
  if (dir.exists(test_dir_edr)) {
    unlink(test_dir_edr, recursive = TRUE, force = TRUE)
  }
}

passed <- 0L
failed <- 0L

check <- function(label, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("[PASS] %s\n", label))
    passed <<- passed + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", label))
    failed <<- failed + 1L
  }
}

tryCatch({
  # 1. vcd-categorical-reporting の検証
  dir.create(test_dir_rep, recursive = TRUE, showWarnings = FALSE)
  batch_df <- data.frame(
    theme = c("T1", "T1"),
    arm = c("Drug", "Placebo"),
    events = c(10L, 5L),
    total = c(50L, 50L),
    stringsAsFactors = FALSE
  )
  res_rep <- generate_comparative_report(
    df = batch_df,
    reference_arm = "Placebo",
    contrast_mode = "reference_vs_all",
    output_dir = test_dir_rep
  )
  meta_rep <- read_run_control(res_rep$run_output_dir)
  check("vcd-categorical-reporting run_state is 'completed'", identical(meta_rep$run_state, "completed"))
  
  # 2. evidence-decision-review の検証
  dir.create(test_dir_edr, recursive = TRUE, showWarnings = FALSE)
  # generate comparative profile
  prof <- run_independent_beta_binomial(10, 50, 5, 50, primary_delta = 0.05, seed = 42L)
  feat <- extract_evidence_features(prof$evidence)
  res_edr <- complete_evidence_decision_feature_run(
    features = feat,
    out_root = test_dir_edr,
    run_id = "test_edr_completed"
  )
  meta_edr <- read_run_control(res_edr$run_dir)
  check("evidence-decision-review run_state is 'completed'", identical(meta_edr$run_state, "completed"))
  
}, finally = {
  cleanup()
})

cat(sprintf("\ntest_single_pass_completed_state: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
