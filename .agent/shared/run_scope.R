# run-scoped output helpers (skill-output-run-isolation)
# Source from project root: source(".agent/shared/run_scope.R")

RUN_META_INTERFACE_VERSION <- "1.0"

run_scope_source_repo_root <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(20L)) {
    p <- file.path(d, ".agent", "shared", "run_scope.R")
    if (file.exists(p)) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) {
      break
    }
    d <- parent
  }
  getwd()
}

if (!requireNamespace("digest", quietly = TRUE)) {
  utils::install.packages("digest", repos = "https://cloud.r-project.org")
}

sha256_file <- function(path) {
  digest::digest(file = normalizePath(path, winslash = "/", mustWork = TRUE), algo = "sha256")
}

sha256_df <- function(df) {
  digest::digest(df, algo = "sha256")
}

timed_sha256_file <- function(path, warn_bytes = 10485760L, warn_secs = 5) {
  info <- suppressWarnings(file.info(path))
  sz <- if (is.na(info$size)) 0 else as.numeric(info$size)
  if (sz > warn_bytes) {
    message(sprintf(
      "[INFO] 入力ファイルが大きいです (%s bytes)。run_id 算出のためファイル全体をハッシュします。",
      format(round(sz), scientific = FALSE)
    ))
  }
  t0 <- proc.time()[[3L]]
  h <- sha256_file(path)
  elapsed <- proc.time()[[3L]] - t0
  message(sprintf("[INFO] run_id 計算（入力ファイル SHA-256）所要時間: %.3f 秒", elapsed))
  if (elapsed > warn_secs) {
    message(
      "[WARN] run_id 計算が閾値を超えました。前処理済みの小さなファイルを --input / --data で渡すか、",
      "サブサンプルした入力を用意してください（非決定的な run_id へのフォールバックは行いません）。"
    )
  }
  list(hash = h, elapsed_sec = elapsed, size_bytes = sz)
}

resolve_run_id <- function(explicit = NULL, input_path = NULL, builtin_df = NULL) {
  if (!is.null(explicit)) {
    e <- trimws(as.character(explicit))
    if (nzchar(e)) {
      return(list(run_id = digest::digest(e, algo = "sha256"), source = "explicit"))
    }
  }
  if (!is.null(input_path) && nzchar(trimws(input_path))) {
    p <- normalizePath(trimws(input_path), winslash = "/", mustWork = FALSE)
    if (!isTRUE(file.exists(p))) {
      stop(
        "[ERROR] 入力ファイルが存在しないため run_id を決定できません: ",
        input_path,
        "。パスを確認してください。"
      )
    }
    tr <- timed_sha256_file(p)
    return(list(run_id = tr$hash, source = "file", elapsed_sec = tr$elapsed_sec))
  }
  if (!is.null(builtin_df)) {
    return(list(run_id = sha256_df(builtin_df), source = "builtin"))
  }
  stop(
    "[ERROR] run_id を決定できません。--run_id（または --run-id）で明示するか、",
    "入力ファイル（--input / --data 等）を指定してください。"
  )
}

run_id_short16 <- function(run_id) {
  substr(as.character(run_id), 1L, 16L)
}

run_output_dir_from_root <- function(out_root, run_id) {
  file.path(normalizePath(out_root, winslash = "/", mustWork = FALSE), paste0("run_", run_id_short16(run_id)))
}

write_run_meta <- function(out_root, run_output_dir, skill, run_id, input_data_path, extra = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    utils::install.packages("jsonlite", repos = "https://cloud.r-project.org")
  }
  meta <- list(
    interface_version = RUN_META_INTERFACE_VERSION,
    skill = skill,
    run_id = run_id,
    run_id_short = run_id_short16(run_id),
    out_root = normalizePath(out_root, winslash = "/", mustWork = FALSE),
    run_output_dir = normalizePath(run_output_dir, winslash = "/", mustWork = FALSE),
    input_data = if (!is.null(input_data_path) && nzchar(input_data_path)) {
      tryCatch(
        normalizePath(input_data_path, winslash = "/", mustWork = TRUE),
        error = function(e) input_data_path
      )
    } else {
      NULL
    },
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  if (is.list(extra) && length(extra) > 0L) {
    meta <- utils::modifyList(meta, extra)
  }
  jsonlite::write_json(
    meta,
    file.path(run_output_dir, "run_meta.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  invisible(meta)
}

resolve_pass3_run_dir <- function(root, required_filename, skill_label = "output") {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(root)) {
    stop(
      "[ERROR] 出力ディレクトリが存在しません: ",
      root,
      "。Pass 1 で生成した out_root または run_output_dir を params$output_dir に指定してください。"
    )
  }
  direct <- file.path(root, required_filename)
  if (isTRUE(file.exists(direct))) {
    meta <- tryCatch(
      jsonlite::fromJSON(file.path(root, "run_meta.json")),
      error = function(e) NULL
    )
    return(list(run_dir = root, run_meta = meta, resolved_from = "direct"))
  }
  run_dirs <- list.dirs(root, full.names = TRUE, recursive = FALSE)
  run_dirs <- run_dirs[grepl("/run_[0-9a-f]{16}$", run_dirs, ignore.case = TRUE)]
  if (length(run_dirs) == 0L) {
    stop(
      "[ERROR] ", required_filename, " が見つかりません。期待ディレクトリ: ", root,
      "（直下）または ", root, "/run_<run_id_short>/ 。Pass 1 を実行した run_output_dir を渡してください。"
    )
  }
  info <- file.info(run_dirs)
  pick <- rownames(info)[which.max(info$mtime)]
  cand <- file.path(pick, required_filename)
  if (!isTRUE(file.exists(cand))) {
    stop(
      "[ERROR] ", required_filename, " が見つかりません: ", cand,
      "。選択された run ディレクトリ: ", pick
    )
  }
  meta <- tryCatch(
    jsonlite::fromJSON(file.path(pick, "run_meta.json")),
    error = function(e) NULL
  )
  list(run_dir = pick, run_meta = meta, resolved_from = "run_subdir")
}

find_questionnaire_json_under_run <- function(run_dir) {
  direct <- file.path(run_dir, "questionnaire_results.json")
  if (isTRUE(file.exists(direct))) {
    return(direct)
  }
  hits <- list.files(run_dir, pattern = "^questionnaire_results\\.json$",
    full.names = TRUE, recursive = TRUE
  )
  if (length(hits) == 0L) {
    stop(
      "[ERROR] questionnaire_results.json が見つかりません。期待ディレクトリ: ", run_dir,
      " 配下（再帰探索済み）。"
    )
  }
  info <- file.info(hits)
  hits[which.max(info$mtime)]
}
