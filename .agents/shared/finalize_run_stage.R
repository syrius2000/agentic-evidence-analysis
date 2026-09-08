#!/usr/bin/env Rscript
# .agents/shared/finalize_run_stage.R
# 共通確定 CLI ラッパー: stage (pass2 / pass3) の成果物確定処理と allowlist 検証

suppressPackageStartupMessages({
  # run_scope.R の読み込み
  script_dir <- tryCatch({
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0L) {
      dirname(normalizePath(sub("^--file=", "", file_arg[1L]), winslash = "/", mustWork = FALSE))
    } else {
      getwd()
    }
  }, error = function(e) getwd())

  run_scope_path <- file.path(script_dir, "run_scope.R")
  if (!file.exists(run_scope_path)) {
    run_scope_path <- file.path(getwd(), ".agents", "shared", "run_scope.R")
  }
  if (!file.exists(run_scope_path)) {
    stop("[ERROR] run_scope.R が見つかりません: ", run_scope_path)
  }
  source(run_scope_path)
})

parse_args <- function(args) {
  params <- list(
    stage = NULL,
    run_dir = NULL,
    source_artifact = NULL,
    target_name = NULL,
    expected_results_manifest_sha256 = NULL,
    expected_narrative_sha256 = NULL,
    recover_stale_lock = FALSE
  )

  i <- 1L
  n <- length(args)
  while (i <= n) {
    arg <- args[i]
    if (arg == "--stage") {
      i <- i + 1L
      if (i <= n) params$stage <- args[i]
    } else if (arg == "--run-dir") {
      i <- i + 1L
      if (i <= n) params$run_dir <- args[i]
    } else if (arg == "--source-artifact") {
      i <- i + 1L
      if (i <= n) params$source_artifact <- args[i]
    } else if (arg == "--target-name") {
      i <- i + 1L
      if (i <= n) params$target_name <- args[i]
    } else if (arg == "--expected-results-manifest-sha256") {
      i <- i + 1L
      if (i <= n) params$expected_results_manifest_sha256 <- args[i]
    } else if (arg == "--expected-narrative-sha256") {
      i <- i + 1L
      if (i <= n) params$expected_narrative_sha256 <- args[i]
    } else if (arg == "--recover-stale-lock") {
      params$recover_stale_lock <- TRUE
    } else {
      stop("[ERROR] 不明な引数です: ", arg)
    }
    i <- i + 1L
  }
  params
}

main <- function() {
  raw_args <- commandArgs(trailingOnly = TRUE)
  params <- parse_args(raw_args)

  # 必須引数チェック
  if (is.null(params$stage) || !params$stage %in% c("pass2", "pass3")) {
    stop("[ERROR] --stage には 'pass2' または 'pass3' を指定してください。")
  }
  if (is.null(params$run_dir) || !nzchar(trimws(params$run_dir))) {
    stop("[ERROR] --run-dir が指定されていません。")
  }
  if (is.null(params$source_artifact) || !nzchar(trimws(params$source_artifact))) {
    stop("[ERROR] --source-artifact が指定されていません。")
  }
  if (is.null(params$target_name) || !nzchar(trimws(params$target_name))) {
    stop("[ERROR] --target-name が指定されていません。")
  }
  if (is.null(params$expected_results_manifest_sha256) || !nzchar(trimws(params$expected_results_manifest_sha256))) {
    stop("[ERROR] --expected-results-manifest-sha256 が指定されていません。")
  }

  norm_run <- normalizePath(assert_no_symlink(trimws(params$run_dir)), winslash = "/", mustWork = TRUE)
  meta_file <- file.path(norm_run, "run_meta.json")
  if (!file.exists(meta_file)) {
    stop("[ERROR] 指定された run_dir に run_meta.json が存在しません: ", norm_run)
  }
  run_meta <- jsonlite::fromJSON(meta_file, simplifyVector = FALSE)
  skill <- run_meta$skill
  stage <- params$stage
  target_name <- params$target_name
  source_art <- params$source_artifact

  # Allowlist 検証: target_name は basename のみ
  if (basename(target_name) != target_name || grepl("(/|\\\\)", target_name) || target_name %in% c(".", "..")) {
    stop("[ERROR] target_name は単純なファイル名 (basename) でなければなりません: ", target_name)
  }

  # Allowlist 検証: skill と stage からの導出一致
  expected_target <- if (stage == "pass2") {
    if (identical(skill, "questionnaire-batch-analysis")) "cross_question_summary.md" else "executive_summary.md"
  } else {
    "dashboard.html"
  }

  if (!identical(target_name, expected_target)) {
    stop(
      "[ERROR] target_name が skill (", skill, ") と stage (", stage, ") の allowlist と一致しません (期待値: ",
      expected_target, ", 指定値: ", target_name, ")"
    )
  }

  norm_source <- assert_path_within_run_dir(source_art, norm_run)

  # 確定実行
  res <- if (stage == "pass2") {
    finalize_pass2(
      run_dir = norm_run,
      target_name = target_name,
      source_staging_path = norm_source,
      expected_results_manifest_sha256 = params$expected_results_manifest_sha256,
      recover_stale_lock = params$recover_stale_lock
    )
  } else {
    finalize_pass3(
      run_dir = norm_run,
      target_name = target_name,
      source_staging_path = norm_source,
      expected_results_manifest_sha256 = params$expected_results_manifest_sha256,
      expected_narrative_sha256 = params$expected_narrative_sha256,
      recover_stale_lock = params$recover_stale_lock
    )
  }

  cat(jsonlite::toJSON(res, pretty = TRUE, auto_unbox = TRUE), "\n")
  invisible(0L)
}

if (!interactive()) {
  main()
}
