#!/usr/bin/env Rscript
# tests/test_run_scope_timestamp_jst.R
# Task 1.3: JST タイムスタンプ固定の検証（TZ 環境変数偽装下での +0900 固定保証）

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

test_dir <- tempfile("test_tz_")
dir.create(test_dir, recursive = TRUE)

orig_tz <- Sys.getenv("TZ", unset = NA)

cleanup <- function() {
  if (is.na(orig_tz)) {
    Sys.unsetenv("TZ")
  } else {
    Sys.setenv(TZ = orig_tz)
  }
  if (dir.exists(test_dir)) {
    unlink(test_dir, recursive = TRUE, force = TRUE)
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
  fake_tzs <- c("UTC", "America/New_York", "Europe/London")
  
  for (tz_name in fake_tzs) {
    Sys.setenv(TZ = tz_name)
    
    # 1. write_run_meta() による created と pass1_completed の JST 固定検証
    run_dir <- file.path(test_dir, paste0("run_tz_", gsub("/", "_", tz_name)))
    dir.create(run_dir, recursive = TRUE)
    
    # primary results と manifest を作成
    cat('{"status": "ok"}\n', file = file.path(run_dir, "categorical_results.json"))
    m_res <- write_results_manifest(run_dir, "vcd-categorical-analysis", list(
      list(path = "categorical_results.json", role = "primary_results")
    ))
    
    meta_res <- write_run_meta(
      out_root = test_dir,
      run_output_dir = run_dir,
      skill = "vcd-categorical-analysis",
      run_id = basename(run_dir),
      extra = list(results_manifest_sha256 = m_res$manifest_sha256)
    )
    
    saved_meta <- jsonlite::read_json(file.path(run_dir, "run_meta.json"))
    ts <- saved_meta$timestamps
    
    check(sprintf("[%s] created ends with +0900", tz_name), grepl("\\+0900$", ts$created))
    check(sprintf("[%s] pass1_completed ends with +0900", tz_name), grepl("\\+0900$", ts$pass1_completed))
    
    # 2. finalize_stage() による pass2_completed, pass3_completed, sealed の JST 固定検証
    # vcd-bayesian の run を模擬
    bayes_dir <- file.path(test_dir, paste0("run_bayes_", gsub("/", "_", tz_name)))
    dir.create(bayes_dir, recursive = TRUE)
    cat('{"evidence": 1}\n', file = file.path(bayes_dir, "evidence_results.json"))
    b_man <- write_results_manifest(bayes_dir, "vcd-bayesian-evidence-analysis", list(
      list(path = "evidence_results.json", role = "primary_results")
    ))
    write_run_meta(
      out_root = test_dir,
      run_output_dir = bayes_dir,
      skill = "vcd-bayesian-evidence-analysis",
      run_id = basename(bayes_dir),
      extra = list(results_manifest_sha256 = b_man$manifest_sha256)
    )
    
    # pass2 promotion
    staging_dir <- file.path(bayes_dir, "staging")
    dir.create(staging_dir, recursive = TRUE)
    exec_src <- file.path(staging_dir, "exec_source.md")
    writeLines(c("# Summary", "Pass 2 narrative content"), exec_src)
    
    fin2 <- finalize_stage(
      run_dir = bayes_dir,
      stage = "pass2",
      target_name = "executive_summary.md",
      source_staging_path = exec_src,
      expected_results_manifest_sha256 = b_man$manifest_sha256
    )
    
    meta_p2 <- jsonlite::read_json(file.path(bayes_dir, "run_meta.json"))
    check(sprintf("[%s] pass2_completed ends with +0900", tz_name), grepl("\\+0900$", meta_p2$timestamps$pass2_completed))
    
    # pass3 promotion
    dash_src <- file.path(staging_dir, "dash_source.html")
    writeLines(c("<html><body>Dashboard</body></html>"), dash_src)
    
    # verify_narrative requires executive_summary.md sha256
    nh <- sha256_file(file.path(bayes_dir, "executive_summary.md"))
    
    fin3 <- finalize_stage(
      run_dir = bayes_dir,
      stage = "pass3",
      target_name = "dashboard.html",
      source_staging_path = dash_src,
      expected_results_manifest_sha256 = b_man$manifest_sha256,
      expected_narrative_sha256 = nh
    )
    
    meta_p3 <- jsonlite::read_json(file.path(bayes_dir, "run_meta.json"))
    check(sprintf("[%s] pass3_completed ends with +0900", tz_name), grepl("\\+0900$", meta_p3$timestamps$pass3_completed))
    check(sprintf("[%s] sealed ends with +0900", tz_name), grepl("\\+0900$", meta_p3$timestamps$sealed))
  }
}, finally = {
  cleanup()
})

cat(sprintf("\ntest_run_scope_timestamp_jst: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
