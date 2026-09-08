#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(
  root,
  ".agents",
  "skills",
  "vcd-categorical-analysis",
  "templates",
  "analysis.R"
)
stopifnot(file.exists(analysis))

source(file.path(root, ".agents", "shared", "run_scope.R"))

td <- tempfile("vcd_categorical_runs_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

run_analysis <- function(mode, extra_args = character(0), expect_success = TRUE) {
  mode_arg <- if (identical(mode, "profile")) "--profile" else "--render"
  output <- suppressWarnings(system2(
    "Rscript",
    c("--vanilla", analysis, mode_arg, "--out", td, extra_args),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (expect_success && !identical(as.integer(status), 0L)) {
    cat("FAILED with output:\n", paste(output, collapse = "\n"), "\n")
    stop(paste(output, collapse = "\n"))
  }
  invisible(list(status = as.integer(status), output = output))
}

run_profile <- function(extra_args = character(0), expect_success = TRUE) {
  run_analysis("profile", extra_args, expect_success = expect_success)
}

run_render <- function(extra_args = character(0), expect_success = TRUE) {
  run_analysis("render", extra_args, expect_success = expect_success)
}

# --- 1. 入力ファイル欠損エラーのテスト ---
missing_data_out <- file.path(td, "missing_data_out")
missing_data_path <- file.path(td, "does_not_exist.csv")
res_missing_data <- run_profile(c(
  "--out", missing_data_out,
  "--run-id", "missing_data",
  "--data", missing_data_path
), expect_success = FALSE)
stopifnot(res_missing_data$status != 0L)
stopifnot(any(grepl("--data.*存在しません", res_missing_data$output)))
stopifnot(!dir.exists(missing_data_out))

# --- 2. Pass 0 Profile Mode: 正式 run を作成しないことの検証 ---
prof_dir <- file.path(td, "profile_workspace")
dir.create(prof_dir, recursive = TRUE)
res_prof <- run_profile(c("--out", prof_dir))
stopifnot(res_prof$status == 0L)
stopifnot(file.exists(file.path(prof_dir, "data_profile.json")))
# 正式 run ディレクトリ (run_*) や run_meta.json が作成されていないこと
prof_subdirs <- list.dirs(prof_dir, recursive = FALSE, full.names = FALSE)
stopifnot(length(grep("^run_", prof_subdirs)) == 0L)
stopifnot(!file.exists(file.path(prof_dir, "run_meta.json")))
stopifnot(!file.exists(file.path(prof_dir, "results_manifest.json")))

# --- 3. Pass 1 Render Mode: 正式 run の原子的予約・作成 ---
res_render1 <- run_render(c("--run-id", "cat_case1"))
stopifnot(res_render1$status == 0L)

run1_dir <- file.path(td, "run_cat_case1")
stopifnot(dir.exists(run1_dir))
stopifnot(file.exists(file.path(run1_dir, "categorical_results.json")))
stopifnot(file.exists(file.path(run1_dir, "data_profile_post.json")))
stopifnot(file.exists(file.path(run1_dir, "results_manifest.json")))
stopifnot(file.exists(file.path(run1_dir, "run_handover.json")))
stopifnot(file.exists(file.path(run1_dir, "analysis_config.json")))

meta1 <- jsonlite::fromJSON(file.path(run1_dir, "run_meta.json"), simplifyVector = FALSE)
stopifnot(identical(meta1$interface_version, "2.0"))
stopifnot(identical(meta1$run_state, "active"))
stopifnot(identical(meta1$pass_status$pass1, "completed"))
stopifnot(identical(meta1$pass_status$pass2, "pending"))
stopifnot(identical(meta1$pass_status$pass3, "pending"))
stopifnot(identical(meta1$run_id, "cat_case1"))

# マニフェスト完全性検証
v_man1 <- verify_results_manifest(run1_dir)
stopifnot(isTRUE(v_man1$valid))

# --- 4. 秒単位 / run_id 衝突回避の検証 (新規 run 隔離) ---
res_render2 <- run_render(c("--run-id", "cat_case1"))
stopifnot(res_render2$status == 0L)

run2_dir <- file.path(td, "run_cat_case1_2")
stopifnot(dir.exists(run2_dir))
stopifnot(file.exists(file.path(run2_dir, "categorical_results.json")))
meta2 <- jsonlite::fromJSON(file.path(run2_dir, "run_meta.json"), simplifyVector = FALSE)
stopifnot(identical(meta2$run_id, "cat_case1_2"))
stopifnot(identical(meta2$requested_run_id, "cat_case1"))

# 前の run1_dir が一切変更されていないこと
v_man1_after <- verify_results_manifest(run1_dir)
stopifnot(isTRUE(v_man1_after$valid))
stopifnot(identical(meta1$updated_at, jsonlite::fromJSON(file.path(run1_dir, "run_meta.json"))$updated_at))

# --- 5. 親ディレクトリ誤指定 (run ディレクトリ直下指定) の FAIL-FAST 停止 ---
res_invalid_out <- suppressWarnings(system2(
  "Rscript",
  c("--vanilla", analysis, "--render", "--out", run1_dir, "--run-id", "nested"),
  stdout = TRUE,
  stderr = TRUE
))
status_inv <- attr(res_invalid_out, "status")
stopifnot(!is.null(status_inv) && status_inv != 0L)
stopifnot(any(grepl("output_dir は既存または予約形式の run ディレクトリです", res_invalid_out)))

# --- 6. --supersedes-run の検証 ---
res_sup <- run_render(c(
  "--run-id", "cat_case_sup",
  "--supersedes-run", run1_dir,
  "--supersede-reason", "Refined_categorization"
))
stopifnot(res_sup$status == 0L)
run_sup_dir <- file.path(td, "run_cat_case_sup")
stopifnot(dir.exists(run_sup_dir))
meta_sup <- jsonlite::fromJSON(file.path(run_sup_dir, "run_meta.json"), simplifyVector = FALSE)
stopifnot(identical(normalizePath(meta_sup$supersedes_run, winslash = "/"), normalizePath(run1_dir, winslash = "/")))
stopifnot(identical(meta_sup$superseded_results_manifest_sha256, v_man1$manifest_sha256))
stopifnot(identical(meta_sup$supersede_reason, "Refined_categorization"))

# --- 7. Unix 並列実行での原子的一意予約の検証 ---
if (identical(.Platform$OS.type, "unix")) {
  atomic_jobs <- lapply(seq_len(4L), function(i) {
    parallel::mcparallel(
      suppressWarnings(system2(
        "Rscript",
        c(
          "--vanilla",
          analysis,
          "--render",
          "--out", td,
          "--run-id", "atomic_cat"
        ),
        stdout = TRUE,
        stderr = TRUE
      )),
      silent = TRUE,
      mc.set.seed = FALSE
    )
  })
  atomic_outputs <- parallel::mccollect(atomic_jobs)
  atomic_statuses <- vapply(atomic_outputs, function(output) {
    if (inherits(output, "try-error")) return(1L)
    status <- attr(output, "status")
    if (is.null(status)) 0L else as.integer(status)
  }, integer(1))
  stopifnot(all(atomic_statuses == 0L))

  atomic_dirs <- list.dirs(td, recursive = FALSE, full.names = TRUE)
  atomic_dirs <- atomic_dirs[grepl(
    "^run_atomic_cat(_[0-9]+)?$",
    basename(atomic_dirs)
  )]
  stopifnot(length(atomic_dirs) == 4L)
  atomic_meta <- lapply(
    file.path(atomic_dirs, "run_meta.json"),
    jsonlite::fromJSON
  )
  atomic_run_ids <- vapply(atomic_meta, `[[`, character(1), "run_id")
  atomic_states <- vapply(atomic_meta, `[[`, character(1), "run_state")
  stopifnot(length(unique(atomic_run_ids)) == 4L)
  stopifnot(all(atomic_states == "active"))
}

message("OK: all categorical run isolation tests passed successfully under v2.0 lifecycle contract")
