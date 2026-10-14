#!/usr/bin/env Rscript
# tests/test_run_scope_index.R
# Task 2.1: append_run_index(), read_run_index(), write_latest() のユニットテスト

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

test_dir <- tempfile("test_index_")
dir.create(test_dir, recursive = TRUE)

cleanup <- function() {
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
  out_root <- test_dir
  index_file <- file.path(out_root, "runs_index.jsonl")
  latest_file <- file.path(out_root, "latest.json")
  
  # 1. runs_index.jsonl への追記テスト（1行1確定事象）
  event1 <- list(
    run_id = "run_001",
    logical_run_id = "task_001",
    run_dir = "run_001",
    timestamp_jst = "2026-10-14T00:00:00+0900",
    run_state = "active",
    manifest_sha256 = "1111111111111111111111111111111111111111111111111111111111111111",
    skill = "vcd-bayesian-evidence-analysis"
  )
  append_run_index(out_root, event1)
  
  check("runs_index.jsonl created on disk", file.exists(index_file))
  lines1 <- readLines(index_file, warn = FALSE)
  check("runs_index.jsonl has 1 line", length(lines1) == 1L)
  
  # 2. 同一 run_id の複数確定事象追記（例: Pass 1 active -> Pass 3 sealed）
  event2 <- list(
    run_id = "run_001",
    logical_run_id = "task_001",
    run_dir = "run_001",
    timestamp_jst = "2026-10-14T00:05:00+0900",
    run_state = "sealed",
    manifest_sha256 = "1111111111111111111111111111111111111111111111111111111111111111",
    skill = "vcd-bayesian-evidence-analysis"
  )
  append_run_index(out_root, event2)
  
  lines2 <- readLines(index_file, warn = FALSE)
  check("runs_index.jsonl has 2 lines", length(lines2) == 2L)
  
  # 別 run_id の追記
  event3 <- list(
    run_id = "run_002",
    logical_run_id = "task_002",
    run_dir = "run_002",
    timestamp_jst = "2026-10-14T00:10:00+0900",
    run_state = "completed",
    manifest_sha256 = "2222222222222222222222222222222222222222222222222222222222222222",
    skill = "vcd-bayesian-evidence-analysis"
  )
  append_run_index(out_root, event3)
  
  # 3. read_run_index() の集約検証: run_id ごとの最終行が採用されること
  idx_df <- read_run_index(out_root)
  check("read_run_index returns 2 records", nrow(idx_df) == 2L)
  check("read_run_index contains run_dir column", "run_dir" %in% names(idx_df))
  run1_rec <- idx_df[idx_df$run_id == "run_001", ]
  check("run_001 latest state is sealed", identical(run1_rec$run_state, "sealed"))
  check("run_001 latest timestamp is 00:05:00", identical(run1_rec$timestamp_jst, "2026-10-14T00:05:00+0900"))
  check("run_001 run_dir is run_001", identical(run1_rec$run_dir, "run_001"))
  
  # 4. write_latest() の検証
  # run_001 のディレクトリを作成
  dir_run1 <- file.path(out_root, "run_001")
  dir.create(dir_run1, recursive = TRUE)
  
  # event2 with run_dir
  event2$run_dir <- "run_001"
  write_latest(out_root, "run_001", run_meta = event2)
  check("latest.json created on disk", file.exists(latest_file))
  check("latest.json is regular file (not symlink)", !Sys.readlink(latest_file) != "")
  
  latest_data <- jsonlite::read_json(latest_file)
  check("latest.json has run_id run_001", identical(latest_data$run_id, "run_001"))
  check("latest.json has relative path run_001", identical(latest_data$path, "run_001"))
  check("latest.json has run_state sealed", identical(latest_data$run_state, "sealed"))
  
  # 5. failed run では latest.json を更新しない
  failed_event <- list(
    run_id = "run_003_failed",
    logical_run_id = "task_003",
    timestamp_jst = "2026-10-14T00:15:00+0900",
    run_state = "failed",
    manifest_sha256 = NULL,
    skill = "vcd-bayesian-evidence-analysis"
  )
  append_run_index(out_root, failed_event)
  # write_latest に failed を渡しても更新されない
  write_latest(out_root, "run_003_failed", run_meta = failed_event)
  
  latest_after_fail <- jsonlite::read_json(latest_file)
  check("latest.json not updated on failed run", identical(latest_after_fail$run_id, "run_001"))
  
  # 6. .run_locks の除外と run_* 走査規約の検証
  lock_dir <- file.path(out_root, ".run_locks")
  dir.create(lock_dir, recursive = TRUE)
  
  child_runs <- list.files(out_root, pattern = "^run_", full.names = FALSE)
  check("child_runs filters out .run_locks", !(".run_locks" %in% child_runs))
  check("child_runs contains run_001", "run_001" %in% child_runs)
  
}, finally = {
  cleanup()
})

cat(sprintf("\ntest_run_scope_index: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
