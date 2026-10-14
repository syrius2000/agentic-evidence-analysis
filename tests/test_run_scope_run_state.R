#!/usr/bin/env Rscript
# tests/test_run_scope_run_state.R
# read_run_control の run_state 受理・拒絶テスト

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

test_dir <- tempfile("test_run_state_")
dir.create(test_dir, recursive = TRUE)

cleanup <- function() {
  if (dir.exists(test_dir)) {
    unlink(test_dir, recursive = TRUE, force = TRUE)
  }
}

make_dummy_run <- function(run_state_val) {
  sub_run <- file.path(test_dir, paste0("run_", digest::digest(run_state_val, algo = "crc32")))
  dir.create(sub_run, recursive = TRUE, showWarnings = FALSE)
  meta <- list(
    interface_version = "2.0",
    path_schema_version = RUN_SCOPE_PATH_SCHEMA_VERSION,
    skill = "vcd-categorical-analysis",
    run_state = run_state_val,
    pass_status = list(
      pass1 = "completed",
      pass2 = "pending",
      pass3 = "pending"
    )
  )
  jsonlite::write_json(meta, file.path(sub_run, "run_meta.json"), auto_unbox = TRUE, pretty = TRUE)
  sub_run
}

passed <- 0L
failed <- 0L

assert_accept <- function(state_name) {
  run_path <- make_dummy_run(state_name)
  res <- tryCatch({
    read_run_control(run_path)
    TRUE
  }, error = function(e) {
    cat(sprintf("[FAIL] 受理されるべき run_state='%s' が拒絶されました: %s\n", state_name, conditionMessage(e)))
    FALSE
  })
  if (res) {
    passed <<- passed + 1L
  } else {
    failed <<- failed + 1L
  }
}

assert_reject <- function(state_name, label) {
  run_path <- make_dummy_run(state_name)
  res <- tryCatch({
    read_run_control(run_path)
    cat(sprintf("[FAIL] 拒絶されるべき %s (run_state='%s') が受理されました\n", label, as.character(state_name)))
    FALSE
  }, error = function(e) {
    if (grepl("不正なrun_state", conditionMessage(e))) {
      TRUE
    } else {
      cat(sprintf("[FAIL] %s で想定外のエラー: %s\n", label, conditionMessage(e)))
      FALSE
    }
  })
  if (res) {
    passed <<- passed + 1L
  } else {
    failed <<- failed + 1L
  }
}

tryCatch({
  # 正常系: 4つの正規状態が受理されること
  assert_accept("active")
  assert_accept("completed")
  assert_accept("failed")
  assert_accept("sealed")

  # 異常系: 不正値・欠損値が拒絶されること
  assert_reject("bogus", "不正値")
  assert_reject("running", "非正規値")
  assert_reject(NULL, "NULL値")
  assert_reject(NA_character_, "NA値")
}, finally = {
  cleanup()
})

cat(sprintf("test_run_scope_run_state: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
