RUN_SCOPE_REPO_ROOT <- local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "run_scope.R", files)
  if (length(own)) normalizePath(file.path(dirname(tail(own, 1)[[1]]), "../..")) else normalizePath(getwd())
})
# run-scoped output helpers (skill-output-run-isolation / harden-run-path-handover)
# Source from project root: source(".agents/shared/run_scope.R")

RUN_META_INTERFACE_VERSION_V1 <- "1.0"
RUN_META_INTERFACE_VERSION_V2 <- "2.0"
RUN_META_INTERFACE_VERSION <- RUN_META_INTERFACE_VERSION_V2

run_scope_source_repo_root <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(20L)) {
    p <- file.path(d, ".agents", "shared", "run_scope.R")
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

# 永続化するパスは、実行環境に依存しない相対表現を基本とする。
RUN_SCOPE_PATH_SCHEMA_VERSION <- "1.0"
`%||%` <- function(x, y) if (is.null(x)) y else x

run_scope_is_absolute_path <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) &&
    (startsWith(chartr("\\", "/", path), "/") || grepl("^[A-Za-z]:/", chartr("\\", "/", path)))
}

run_scope_repo_root <- function(explicit = NULL, start = getwd()) {
  candidate <- explicit %||% NULL
  if (!is.null(candidate) && nzchar(trimws(as.character(candidate)))) {
    return(normalizePath(assert_no_symlink(as.character(candidate)), winslash = "/", mustWork = TRUE))
  }
  start <- normalizePath(start, winslash = "/", mustWork = FALSE)
  git_root <- tryCatch(
    suppressWarnings(system2("git", c("-C", start, "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  if (length(git_root) == 1L && nzchar(trimws(git_root))) {
    return(normalizePath(assert_no_symlink(trimws(git_root)), winslash = "/", mustWork = TRUE))
  }
  d <- start
  for (i in seq_len(20L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("[ERROR] リポジトリルートを一意に解決できません。--repo-root を指定してください。")
}

run_scope_relative_path <- function(path, root) {
  p <- normalizePath(path, winslash = "/", mustWork = FALSE)
  r <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!(identical(p, r) || startsWith(p, paste0(r, "/")))) return(NULL)
  rel <- substring(p, nchar(r) + 2L)
  if (!nzchar(rel)) "." else rel
}

run_scope_resolve_path <- function(path, path_kind, repo_root = NULL, run_dir = NULL,
                                   external_path = NULL, allow_legacy_absolute = FALSE) {
  if (is.null(path) || length(path) == 0L || is.na(path)) return(NULL)
  p <- chartr("\\", "/", as.character(path))
  kind <- if (is.null(path_kind) || !nzchar(as.character(path_kind))) NULL else as.character(path_kind)
  if (identical(kind, "repo_relative")) {
    if (is.null(repo_root)) stop("[ERROR] repo_relative パスの解決に repo_root が必要です")
    if (run_scope_is_absolute_path(p) || (p != "." && any(strsplit(p, "/", fixed = TRUE)[[1L]] %in% c("", ".", "..")))) {
      stop("[ERROR] repo_relative パスが不正です")
    }
    return(normalizePath(assert_no_symlink(file.path(repo_root, p)), winslash = "/", mustWork = FALSE))
  }
  if (identical(kind, "run_relative")) {
    if (is.null(run_dir)) stop("[ERROR] run_relative パスの解決に run_dir が必要です")
    return(assert_path_within_run_dir(p, run_dir))
  }
  if (identical(kind, "external")) {
    if (!is.null(external_path) && nzchar(as.character(external_path))) {
      return(normalizePath(assert_no_symlink(external_path), winslash = "/", mustWork = FALSE))
    }
    # 明示された supersede 元など、外部参照として保存された絶対パスは互換的に解決する。
    return(if (run_scope_is_absolute_path(p)) normalizePath(assert_no_symlink(p), winslash = "/", mustWork = FALSE) else NULL)
  }
  if (run_scope_is_absolute_path(p) && isTRUE(allow_legacy_absolute)) {
    return(normalizePath(assert_no_symlink(p), winslash = "/", mustWork = FALSE))
  }
  p
}

run_scope_portable_path <- function(path, repo_root, run_dir = NULL, prefer_run_relative = FALSE) {
  if (is.null(path) || length(path) == 0L || is.na(path) || !nzchar(as.character(path))) return(NULL)
  p <- normalizePath(as.character(path), winslash = "/", mustWork = FALSE)
  if (!isTRUE(prefer_run_relative) && !is.null(repo_root)) {
    rel <- run_scope_relative_path(p, repo_root)
    if (!is.null(rel)) return(list(path = rel, path_kind = "repo_relative"))
  }
  if (!is.null(run_dir)) {
    r <- normalizePath(run_dir, winslash = "/", mustWork = FALSE)
    rel <- run_scope_relative_path(p, r)
    if (!is.null(rel)) return(list(path = rel, path_kind = "run_relative"))
  }
  list(path = NULL, path_kind = "external")
}

# 計画書で公開した名称の互換エイリアス。
to_portable_repo_path <- run_scope_portable_path
from_portable_repo_path <- run_scope_resolve_path

run_scope_detect_repo_root <- function(run_dir) {
  d <- normalizePath(run_dir, winslash = "/", mustWork = FALSE)
  for (i in seq_len(20L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  NULL
}

resolve_run_meta_paths <- function(meta, run_dir, allow_legacy = FALSE) {
  norm_run <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  repo_root <- run_scope_detect_repo_root(norm_run)
  if (is.null(repo_root)) repo_root <- RUN_SCOPE_REPO_ROOT
  resolved <- meta
  if (!identical(meta$interface_version, RUN_META_INTERFACE_VERSION_V2)) return(meta)
  if (!is.null(meta$out_root)) {
    resolved$out_root <- run_scope_resolve_path(meta$out_root, meta$out_root_path_kind, repo_root, norm_run,
      allow_legacy_absolute = allow_legacy)
  }
  if (is.null(resolved$out_root) || !nzchar(resolved$out_root)) {
    parent <- dirname(norm_run)
    resolved$out_root <- if (identical(meta$skill, "questionnaire-batch-analysis") && identical(basename(parent), "runs")) dirname(parent) else parent
  }
  resolved$run_output_dir <- norm_run
  if (!is.null(meta$supersedes_run)) {
    resolved$supersedes_run <- run_scope_resolve_path(meta$supersedes_run, meta$supersedes_run_path_kind,
      repo_root, norm_run, allow_legacy_absolute = allow_legacy)
  }
  if (!is.null(meta$config_source_path)) {
    resolved$config_source_path <- run_scope_resolve_path(meta$config_source_path, meta$config_source_path_kind,
      repo_root, norm_run, allow_legacy_absolute = allow_legacy)
  }
  if (is.list(meta$inputs)) {
    resolved$inputs <- lapply(meta$inputs, function(item) {
      if (!is.null(item$source_path)) {
        item$source_path <- run_scope_resolve_path(item$source_path,
          item$source_path_kind %||% item$path_kind, repo_root, norm_run,
          allow_legacy_absolute = allow_legacy)
      }
      item
    })
  }
  resolved
}

portableize_run_meta <- function(meta, run_dir) {
  if (!identical(meta$interface_version, RUN_META_INTERFACE_VERSION_V2)) return(meta)
  norm_run <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  repo_root <- run_scope_detect_repo_root(norm_run)
  if (is.null(repo_root)) repo_root <- tryCatch(run_scope_repo_root(start = norm_run), error = function(e) NULL)
  m <- meta
  out_rec <- if (!is.null(m$out_root) && run_scope_is_absolute_path(m$out_root)) run_scope_portable_path(m$out_root, repo_root, norm_run) else NULL
  if (!is.null(out_rec) && !identical(out_rec$path_kind, "external")) {
    m$out_root <- out_rec$path
    m$out_root_path_kind <- out_rec$path_kind
  } else if (is.null(m$out_root)) {
    m$out_root_path_kind <- "external"
  }
  m$run_output_dir <- "."
  m$run_output_dir_path_kind <- "run_relative"
  if (!is.null(m$supersedes_run) && run_scope_is_absolute_path(m$supersedes_run)) {
    rec <- run_scope_portable_path(m$supersedes_run, repo_root, norm_run)
    m$supersedes_run <- if (!is.null(rec) && !identical(rec$path_kind, "external")) rec$path else normalizePath(m$supersedes_run, winslash = "/", mustWork = FALSE)
    m$supersedes_run_path_kind <- if (!is.null(rec)) rec$path_kind else "external"
  }
  if (!is.null(m$config_source_path) && run_scope_is_absolute_path(m$config_source_path)) {
    rec <- run_scope_portable_path(m$config_source_path, repo_root, norm_run)
    m$config_source_path <- if (!is.null(rec) && !identical(rec$path_kind, "external")) rec$path else NULL
    m$config_source_path_kind <- if (!is.null(rec)) rec$path_kind else "external"
  }
  if (is.list(m$inputs)) {
    m$inputs <- lapply(m$inputs, function(item) {
      if (!is.null(item$source_path) && run_scope_is_absolute_path(item$source_path)) {
        rec <- run_scope_portable_path(item$source_path, repo_root, norm_run)
        item$source_path <- if (!is.null(rec) && !identical(rec$path_kind, "external")) rec$path else NULL
        item$source_path_kind <- if (!is.null(rec)) rec$path_kind else "external"
      }
      item
    })
  }
  scrub <- function(x) {
    if (is.list(x)) return(lapply(x, scrub))
    if (is.character(x) && length(x) == 1L && run_scope_is_absolute_path(x)) return(NULL)
    x
  }
  explicit_supersede <- if (!is.null(m$supersedes_run) && run_scope_is_absolute_path(m$supersedes_run) && identical(m$supersedes_run_path_kind, "external")) m$supersedes_run else NULL
  m <- scrub(m)
  if (!is.null(explicit_supersede)) m$supersedes_run <- explicit_supersede
  m$path_schema_version <- RUN_SCOPE_PATH_SCHEMA_VERSION
  m
}

local({
  dep_path <- file.path(RUN_SCOPE_REPO_ROOT, ".agents", "shared", "dependency_check.R")
  if (file.exists(dep_path)) {
    source(dep_path, local = FALSE)
  }
})
if (exists("check_r_dependencies", mode = "function")) {
  check_r_dependencies(c("digest", "jsonlite"), "Run隔離管理")
} else {
  missing_core <- c("digest", "jsonlite")[!vapply(c("digest", "jsonlite"), requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing_core) > 0L) {
    stop(sprintf(
      "[ERROR] Run隔離管理に必要なRパッケージが不足しています: %s\n事前に次を実行してください:\n  install.packages(c(%s))\n",
      paste(missing_core, collapse = ", "),
      paste(sprintf('"%s"', missing_core), collapse = ", ")
    ), call. = FALSE)
  }
}

sha256_file <- function(path) {
  p <- normalizePath(path, winslash = "/", mustWork = TRUE)
  digest::digest(file = p, algo = "sha256")
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
      return(list(run_id = digest::digest(e, algo = "sha256"), source = "explicit", requested_id = e))
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
    return(list(run_id = tr$hash, source = "file", elapsed_sec = tr$elapsed_sec, requested_id = NULL))
  }
  if (!is.null(builtin_df)) {
    return(list(run_id = sha256_df(builtin_df), source = "builtin", requested_id = NULL))
  }
  stop(
    "[ERROR] run_id を決定できません。--run_id（または --run-id）で明示するか、",
    "入力ファイル（--input / --data 等）を指定してください。"
  )
}

run_id_short16 <- function(run_id) {
  substr(as.character(run_id), 1L, 16L)
}

# --- Task 1.1: 親ディレクトリ検証 ---
assert_valid_out_root <- function(out_root) {
  if (is.null(out_root) || !nzchar(trimws(out_root))) {
    stop("[ERROR] output_dir (out_root) が指定されていません。")
  }
  norm_root <- normalizePath(assert_no_symlink(trimws(out_root)), winslash = "/", mustWork = FALSE)
  bname <- basename(norm_root)

  # run_* または runs 階層の誤指定チェック
  is_run_slug <- grepl("^run_([0-9a-f]{16}|[0-9]{8}_[0-9]{6})(_[0-9]+)?$", bname)
  is_runs_dir <- (bname == "runs" || basename(dirname(norm_root)) == "runs")

  # 実 run 成果物の存在チェック
  candidate_meta <- file.path(norm_root, "run_meta.json")
  candidate_manifest <- file.path(norm_root, "results_manifest.json")
  has_run_artifacts <- file.exists(candidate_meta) || file.exists(candidate_manifest) ||
    file.exists(file.path(norm_root, "evidence_results.json")) ||
    file.exists(file.path(norm_root, "categorical_results.json")) ||
    file.exists(file.path(norm_root, "summary.csv"))

  if (is_run_slug || is_runs_dir || has_run_artifacts) {
    stop(
      "[ERROR] 指定された output_dir は既存または予約形式の run ディレクトリです: ", norm_root,
      "。Pass 1 の --output-dir には、新規 run を作成する親ディレクトリ（out_root）を指定してください（実 run の二重ネストや自動補正は禁止されています）。"
    )
  }
  invisible(norm_root)
}

# --- Task 1.3: 厳格パストラバーサルガード ---
canonicalize_logical_path <- function(p) {
  p_clean <- chartr("\\", "/", p)
  is_abs <- startsWith(p_clean, "/") || grepl("^[A-Za-z]:/", p_clean)
  prefix_drive <- if (grepl("^[A-Za-z]:/", p_clean)) substr(p_clean, 1L, 2L) else ""

  parts <- strsplit(p_clean, "/", fixed = TRUE)[[1L]]
  res <- character(0)
  for (part in parts) {
    if (part == "" || part == ".") next
    if (part == "..") {
      if (length(res) > 0L && res[length(res)] != "..") {
        res <- res[-length(res)]
      } else if (!is_abs) {
        res <- c(res, "..")
      }
    } else {
      res <- c(res, part)
    }
  }
  out <- paste(res, collapse = "/")
  if (nzchar(prefix_drive)) {
    paste0(prefix_drive, "/", out)
  } else if (is_abs) {
    paste0("/", out)
  } else {
    out
  }
}

# macOS のシステム別名だけを解決し、利用者が配置した symlink は拒絶する。
assert_no_symlink <- function(path) {
  p <- path.expand(path)
  if (!startsWith(p, "/")) p <- file.path(getwd(), p)
  p <- canonicalize_logical_path(p)
  for (alias in c("/var", "/tmp", "/etc")) {
    if (p == alias || startsWith(p, paste0(alias, "/"))) {
      physical <- normalizePath(alias, mustWork = TRUE)
      p <- paste0(physical, substring(p, nchar(alias) + 1L))
      break
    }
  }
  current <- "/"
  for (part in strsplit(sub("^/", "", p), "/", fixed = TRUE)[[1L]]) {
    current <- file.path(current, part)
    link <- Sys.readlink(current)
    if (!is.na(link) && nzchar(link)) stop("[ERROR] symlink は許可されません: ", current)
  }
  p
}

assert_path_within_run_dir <- function(path, run_dir) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) stop("[ERROR] 検証対象のパスが空です")
  root <- normalizePath(assert_no_symlink(run_dir), mustWork = TRUE)
  target <- if (startsWith(path, "/")) path else file.path(root, path)
  target <- assert_no_symlink(target)
  if (!(target == root || startsWith(target, paste0(root, "/")))) stop("[ERROR] パストラバーサル: run ディレクトリの外部です: ", path)
  # 未作成の出力も既存祖先から実パスを解決する。
  parent <- target
  while (!file.exists(parent) && !dir.exists(parent)) parent <- dirname(parent)
  real_parent <- normalizePath(parent, mustWork = TRUE)
  resolved <- paste0(real_parent, substring(target, nchar(parent) + 1L))
  if (!(resolved == root || startsWith(resolved, paste0(root, "/")))) stop("[ERROR] パストラバーサル: 実パスがrun外です")
  resolved
}

atomic_run_json <- function(value, path) {
  assert_no_symlink(path)
  tmp <- tempfile(paste0(".", basename(path), "."), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  jsonlite::write_json(value, tmp, pretty = TRUE, auto_unbox = TRUE, null = "null")
  if (!file.rename(tmp, path)) stop("[ERROR] JSON 原子的更新に失敗: ", path)
  invisible(path)
}

read_run_control <- function(run_dir, allow_legacy = FALSE) {
  path <- assert_path_within_run_dir("run_meta.json", run_dir)
  meta <- jsonlite::read_json(path, simplifyVector = FALSE)
  if (identical(meta$interface_version, "1.0") && allow_legacy) return(meta)
  if (!identical(meta$interface_version, "2.0")) stop("[ERROR] legacy / 不正メタデータ: v2.0 が必要です")
  if (!is.null(meta$path_schema_version) && !identical(as.character(meta$path_schema_version), RUN_SCOPE_PATH_SCHEMA_VERSION)) {
    stop("[ERROR] 未対応の path_schema_version: ", meta$path_schema_version)
  }
  if (!meta$skill %in% c("vcd-bayesian-evidence-analysis", "vcd-categorical-analysis", "questionnaire-batch-analysis")) stop("[ERROR] 不明なskill")
  if (!meta$run_state %in% c("active", "sealed")) stop("[ERROR] 不正なrun_state")
  if (is.null(meta$pass_status) || !meta$pass_status$pass1 %in% c("pending", "completed", "partial", "failed") ||
      !meta$pass_status$pass2 %in% c("pending", "stub_generated", "completed") ||
      !meta$pass_status$pass3 %in% c("pending", "completed")) stop("[ERROR] 不正なpass_status")
  resolve_run_meta_paths(meta, run_dir, allow_legacy = allow_legacy)
}

# --- Task 1.2: 秒単位 JST タイムスタンプ衝突の原子的解決 ---
reserve_run_output_dir <- function(out_root, skill, run_id = NULL, max_attempts = 100L) {
  assert_valid_out_root(out_root)
  norm_root <- normalizePath(out_root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(norm_root)) {
    dir.create(norm_root, recursive = TRUE, showWarnings = FALSE)
  }

  base_dir <- norm_root

  # JST 日時または run_id からスラッグ決定（run_ プレフィックス二重化を防止）
  slug <- if (!is.null(run_id) && nzchar(trimws(as.character(run_id)))) {
    clean_id <- sub("^run_", "", trimws(as.character(run_id)))
    if (nzchar(clean_id)) run_id_short16(clean_id) else format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
  } else {
    format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
  }

  if (!grepl("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", slug)) stop("[ERROR] 不正なrun_id")
  prefix_name <- paste0("run_", slug)

  for (attempt in seq_len(max_attempts)) {
    candidate_name <- if (attempt == 1L) prefix_name else paste0(prefix_name, "_", attempt)
    candidate_path <- file.path(base_dir, candidate_name)

    # recursive = FALSE による原子的ディレクトリ予約
    created <- suppressWarnings(dir.create(candidate_path, recursive = FALSE))
    if (isTRUE(created)) {
      return(normalizePath(candidate_path, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    "[ERROR] run ディレクトリの原子的予約に失敗しました (試行回数上限 ", max_attempts, " 回): ",
    file.path(base_dir, prefix_name)
  )
}

run_output_dir_from_root <- function(out_root, run_id) {
  file.path(normalizePath(out_root, winslash = "/", mustWork = FALSE), paste0("run_", run_id_short16(run_id)))
}

# --- Task 1.4: 設定スナップショット保存および推測なし外部データ保護 ---
save_config_snapshot <- function(run_output_dir, config_data, config_origin = "pass0_file", config_source_path = NULL, file_name = "analysis_config.json") {
  assert_path_within_run_dir(file_name, run_output_dir)
  dest_path <- file.path(run_output_dir, file_name)
  if (file.exists(dest_path)) stop("[ERROR] 設定snapshotの上書きを拒絶")

  repo_root <- run_scope_detect_repo_root(run_output_dir)
  sanitize_config <- function(x) {
    if (is.list(x)) return(lapply(x, sanitize_config))
    if (is.character(x) && length(x) == 1L && run_scope_is_absolute_path(x)) {
      rec <- run_scope_portable_path(x, repo_root, run_output_dir)
      return(if (!is.null(rec) && !identical(rec$path_kind, "external")) rec$path else NA_character_)
    }
    x
  }

  if (is.character(config_data) && length(config_data) == 1L && file.exists(config_data)) {
    # JSON にホスト固有パスが含まれる場合だけ可搬表現へ正規化し、それ以外は原文バイト列を保持する。
    parsed <- if (grepl("\\.json$", config_data, ignore.case = TRUE)) tryCatch(jsonlite::read_json(config_data, simplifyVector = FALSE), error = function(e) NULL) else NULL
    has_abs <- grepl("(/Users/|/home/|[A-Za-z]:[\\\\/])", paste(readLines(config_data, warn = FALSE), collapse = "\n"))
    if (!is.null(parsed) && has_abs) jsonlite::write_json(sanitize_config(parsed), dest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
    else if (!file.copy(config_data, dest_path, overwrite = FALSE)) stop("[ERROR] 設定snapshot保存失敗")
  } else if (is.list(config_data)) {
    jsonlite::write_json(sanitize_config(config_data), dest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  } else {
    stop("[ERROR] 有効な config_data (ファイルパスまたはリスト) を指定してください。")
  }

  sha256 <- sha256_file(dest_path)
  repo_root <- run_scope_detect_repo_root(run_output_dir)
  source_record <- if (!is.null(config_source_path)) run_scope_portable_path(config_source_path, repo_root, run_output_dir) else NULL
  list(
    config_origin = config_origin,
    config_source_path = if (!is.null(source_record)) source_record$path else NULL,
    config_source_path_kind = if (!is.null(source_record)) source_record$path_kind else NULL,
    config_snapshot = file_name,
    config_sha256 = sha256
  )
}

get_run_input_data <- function(run_meta) {
  if (!is.null(run_meta$inputs) && is.list(run_meta$inputs)) {
    for (item in run_meta$inputs) {
      if (identical(item$role, "data") && !is.null(item$source_path)) {
        return(item$source_path)
      }
    }
  }
  # 旧 v1.0 互換
  if (!is.null(run_meta$input_data)) {
    return(run_meta$input_data)
  }
  NULL
}

get_run_input_sha256 <- function(run_meta) {
  if (!is.null(run_meta$inputs) && is.list(run_meta$inputs)) {
    for (item in run_meta$inputs) {
      if (identical(item$role, "data") && !is.null(item$sha256)) {
        return(item$sha256)
      }
    }
  }
  # 旧 v1.0 互換
  if (!is.null(run_meta$input_sha256)) {
    return(run_meta$input_sha256)
  }
  NULL
}

# --- Task 1.5: 全スキル共通結果マニフェスト (results_manifest.json) ---
manifest_roles <- function(skill) {
  switch(skill,
    "vcd-bayesian-evidence-analysis" = c("primary_results", "report_html", "figure"),
    "vcd-categorical-analysis" = c("primary_results", "diagnostic", "intermediate", "summary_table", "figure", "report_html"),
    "questionnaire-batch-analysis" = c("summary_table", "question_result", "canonical_result", "figure", "report_html"),
    "sas-proc-freq" = c("primary_results", "summary_table", "summary_report", "config"),
    "sas-proc-means" = c("primary_results", "summary_table", "summary_report", "config"),
    stop("[ERROR] 不明なmanifest skill"))
}

validate_manifest_entries <- function(run_dir, skill, artifacts, writing = FALSE) {
  roles <- manifest_roles(skill)
  if (!is.list(artifacts) || !length(artifacts)) stop("[ERROR] artifacts 配列が空です")
  paths <- qids <- character()
  validated <- lapply(artifacts, function(art) {
    p <- art$path
    if (!is.character(p) || length(p) != 1L || is.na(p) || !nzchar(p) ||
        grepl("(^/|^[A-Za-z]:|\\\\|//|/$)", p) || any(strsplit(p, "/", fixed = TRUE)[[1]] %in% c(".", ".."))) stop("[ERROR] path は正規化された相対 POSIX パスが必要です")
    f <- assert_path_within_run_dir(p, run_dir)
    if (!file_test("-f", f)) stop("[ERROR] マニフェスト登録成果物が存在しません: ", p)
    if (p %in% paths) stop("[ERROR] path が重複しています")
    paths <<- c(paths, p)
    if (length(art$role) != 1L || !art$role %in% roles) stop("[ERROR] role がallowlist外です")
    if (identical(art$role, "question_result")) {
      q <- as.character(art$question_id)
      if (length(q) != 1L || is.na(q) || !nzchar(q)) stop("[ERROR] question_id が必須です")
      if (q %in% qids) stop("[ERROR] question_id が重複しています")
      qids <<- c(qids, q)
      if (basename(p) != "questionnaire_results.json") stop("[ERROR] question_resultのファイル名が不正")
      payload <- jsonlite::read_json(f)
      if (!identical(as.character(payload$question_id), q)) stop("[ERROR] 設問JSONとquestion_idが不一致")
    }
    h <- sha256_file(f)
    if (!is.null(art$sha256) && (length(art$sha256) != 1L || !grepl("^[0-9a-f]{64}$", art$sha256) || !identical(h, art$sha256))) stop("[ERROR] artifact ハッシュ不一致または不正")
    if (!writing && is.null(art$sha256)) stop("[ERROR] sha256が必須です")
    result <- list(path = p, role = art$role, sha256 = h)
    if (!is.null(art$question_id)) result$question_id <- as.character(art$question_id)
    result
  })
  primary <- switch(skill,
    "vcd-bayesian-evidence-analysis" = "evidence_results.json",
    "vcd-categorical-analysis" = "categorical_results.json",
    "sas-proc-freq" = "freq_results.json",
    "sas-proc-means" = "means_results.json",
    NULL
  )
  if (skill != "questionnaire-batch-analysis") {
    if (!is.null(primary)) {
      entries <- Filter(function(x) x$role == "primary_results", validated)
      if (length(entries) != 1L || entries[[1]]$path != primary) stop("[ERROR] 必須primary_resultsが不一致")
    }
  } else {
    entries <- Filter(function(x) x$role == "summary_table", validated)
    if (length(entries) != 1L || entries[[1]]$path != "summary.csv") stop("[ERROR] summary.csvが必須です")
    summary <- utils::read.csv(file.path(run_dir, "summary.csv"), stringsAsFactors = FALSE, colClasses = "character")
    if (!all(c("question_id", "status") %in% names(summary))) stop("[ERROR] summary.csvの設問・状態が不正")
    success <- summary$question_id[summary$status == "success"]
    if (anyDuplicated(success) || !setequal(qids, success)) stop("[ERROR] 成功設問とmanifestが一致しません")
  }
  validated
}

write_results_manifest <- function(run_output_dir, skill, artifacts) {
  path <- assert_path_within_run_dir("results_manifest.json", run_output_dir)
  if (file.exists(path)) stop("[ERROR] 確定manifestの上書きを拒絶")
  if (file.exists(file.path(run_output_dir, "run_meta.json")) && read_run_control(run_output_dir)$run_state == "sealed") stop("[ERROR] sealed run")
  entries <- validate_manifest_entries(run_output_dir, skill, artifacts, TRUE)
  key <- function(k) vapply(entries, function(x) if (is.null(x[[k]])) "" else x[[k]], character(1))
  entries <- entries[order(key("path"), key("role"), key("question_id"), method = "radix")]
  manifest <- list(interface_version = "1.0", skill = skill, artifacts = entries)
  atomic_run_json(manifest, path)
  list(manifest_path = path, manifest = manifest, manifest_sha256 = sha256_file(path))
}

verify_results_manifest <- function(run_output_dir, expected_sha256 = NULL) {
  path <- assert_path_within_run_dir("results_manifest.json", run_output_dir)
  if (!file.exists(path)) stop("[ERROR] results_manifest.json が存在しません")
  h <- sha256_file(path)
  meta_path <- file.path(run_output_dir, "run_meta.json")
  meta <- if (file.exists(meta_path)) read_run_control(run_output_dir) else NULL
  if (is.null(expected_sha256) && !is.null(meta)) expected_sha256 <- meta$results_manifest_sha256
  if (!is.null(expected_sha256) && !identical(h, expected_sha256)) stop("[ERROR] results_manifest_sha256 が期待値と一致しません")
  if (!is.null(meta)) {
    for (pair in list(c("config_snapshot", "config_sha256"), c("question_config_snapshot", "question_config_sha256"))) {
      rel <- if (pair[1] == "question_config_snapshot") "question_config.csv" else meta[[pair[1]]]
      h_expected <- meta[[pair[2]]]
      if (!is.null(h_expected) && (!is.character(rel) || !identical(sha256_file(assert_path_within_run_dir(rel, run_output_dir)), h_expected))) stop("[ERROR] 設定snapshotハッシュ不一致")
    }
  }
  manifest <- jsonlite::read_json(path)
  if (!identical(manifest$interface_version, "1.0") || (!is.null(meta) && !identical(manifest$skill, meta$skill))) stop("[ERROR] manifestのversion/skill不一致")
  validate_manifest_entries(run_output_dir, manifest$skill, manifest$artifacts)
  list(valid = TRUE, manifest = manifest, manifest_sha256 = h)
}

# --- Task 1.6: 信頼境界検証付き run 外専用排他ロック ---
verify_run_lock_trust_boundary <- function(run_dir, run_meta) {
  norm_run <- normalizePath(assert_no_symlink(run_dir), winslash = "/", mustWork = TRUE)
  assert_no_symlink(run_meta$run_output_dir)
  assert_no_symlink(run_meta$out_root)
  if (is.null(run_meta$run_output_dir) || !nzchar(run_meta$run_output_dir)) {
    stop("[ERROR] run_meta に run_output_dir が存在しません。")
  }
  meta_run <- normalizePath(run_meta$run_output_dir, winslash = "/", mustWork = FALSE)
  if (!identical(norm_run, meta_run)) {
    stop(
      "[ERROR] 信頼境界違反: CLI の run_dir (", norm_run, ") と run_meta の run_output_dir (", meta_run, ") が一致しません。"
    )
  }

  out_root <- normalizePath(run_meta$out_root, winslash = "/", mustWork = FALSE)
  skill <- run_meta$skill

  if (identical(skill, "questionnaire-batch-analysis")) {
    parent_dir <- dirname(norm_run)
    grandparent_dir <- dirname(parent_dir)
    # 新レイアウト: dirname(run_dir) == out_root
    # 旧レイアウト（後方互換）: basename(dirname(run_dir)) == "runs" かつ dirname(dirname(run_dir)) == out_root
    is_new_layout <- identical(normalizePath(parent_dir, winslash = "/", mustWork = FALSE), out_root)
    is_legacy_layout <- identical(basename(parent_dir), "runs") &&
      identical(normalizePath(grandparent_dir, winslash = "/", mustWork = FALSE), out_root)
    if (!is_new_layout && !is_legacy_layout) {
      stop(
        "[ERROR] 信頼境界違反: Questionnaire のディレクトリレイアウトが out_root/run_<id> または out_root/runs/<id> と一致しません。"
      )
    }
  } else {
    # Bayesian / Categorical / SAS: dirname(run_dir) == out_root
    parent_dir <- dirname(norm_run)
    if (!identical(normalizePath(parent_dir, winslash = "/", mustWork = FALSE), out_root)) {
      stop(
        "[ERROR] 信頼境界違反: スキルレイアウトが out_root/run_<id> と一致しません。"
      )
    }
  }

  # symlink 検査
  link_target <- suppressWarnings(Sys.readlink(norm_run))
  if (nzchar(link_target)) {
    stop("[ERROR] 信頼境界違反: run_dir がシンボリックリンクです。")
  }
  link_out <- suppressWarnings(Sys.readlink(out_root))
  if (nzchar(link_out)) {
    stop("[ERROR] 信頼境界違反: out_root がシンボリックリンクです。")
  }

  invisible(out_root)
}

run_control_dir <- function(run_dir) {
  meta <- read_run_control(run_dir)
  root <- verify_run_lock_trust_boundary(run_dir, meta)
  id <- digest::digest(normalizePath(run_dir), algo = "sha256", serialize = FALSE)
  path <- file.path(root, ".run_locks", id)
  assert_no_symlink(path)
  if (!dir.exists(path) && !dir.create(path, recursive = TRUE, showWarnings = FALSE)) stop("[ERROR] 制御領域を作成できません")
  path
}

acquire_stage_lock <- function(run_dir, stage, recover_stale = FALSE, stale_threshold_secs = 300L) {
  if (!stage %in% c("run", "pass2", "pass3", "preview")) stop("[ERROR] 不正なlock stage")
  control <- run_control_dir(run_dir)
  lock_path <- file.path(control, paste0(stage, ".lock"))
  if (!dir.create(lock_path, showWarnings = FALSE)) {
    if (!recover_stale) stop("[ERROR] 排他ロックが既に保持されています: ", lock_path)
    # 回復者同士を直列化。回復mutexの所有者不明時は自動回復しない。
    recovery <- file.path(control, "recovery.lock")
    assert_no_symlink(recovery)
    if (!dir.create(recovery, showWarnings = FALSE)) stop("[ERROR] 回復処理が進行中、または所有者不明です")
    on.exit(unlink(recovery, recursive = TRUE), add = TRUE)
    info_path <- file.path(lock_path, "lock_info.json")
    assert_no_symlink(info_path)
    info <- tryCatch(jsonlite::read_json(info_path), error = function(e) NULL)
    expected_run_hash <- digest::digest(normalizePath(run_dir, winslash = "/"), algo = "sha256", serialize = FALSE)
    run_match <- identical(info$run_dir_hash, expected_run_hash) ||
      identical(info$run_dir, normalizePath(run_dir, winslash = "/"))
    if (is.null(info) || is.null(info$token) || length(info$pid) != 1L || !is.numeric(info$pid) || info$pid <= 0 ||
        !identical(info$stage, stage) || !run_match) stop("[ERROR] lock_info が欠損・破損しています")
    if (!identical(info$hostname, unname(Sys.info()["nodename"]))) stop("[ERROR] 異なるホストのロックです")
    # psの成功と空結果だけをPID不在と扱い、照会失敗は回復しない。
    ps <- suppressWarnings(system2("ps", c("-p", as.character(info$pid), "-o", "pid="), stdout = TRUE, stderr = TRUE))
    status <- attr(ps, "status")
    if (is.null(status)) status <- 0L
    if (status == 0L && length(ps)) stop("[ERROR] ロック保持PIDが現在も生存しています")
    if (status != 1L || length(ps)) stop("[ERROR] PID生死を確認できません")
    age <- as.numeric(difftime(Sys.time(), as.POSIXct(info$acquired_at, format = "%Y-%m-%dT%H:%M:%S%z"), units = "secs"))
    if (is.na(age) || age < stale_threshold_secs) stop("[ERROR] stale 閾値を経過していません")
    # 回復判断中に所有者が変更されていないことを再確認する。
    if (!identical(info, jsonlite::read_json(info_path))) stop("[ERROR] ロック所有者が変更されました")
    audit <- file.path(control, "audit.jsonl")
    assert_no_symlink(audit)
    cat(jsonlite::toJSON(list(action = "recover_stale_lock", recovered = info,
        timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")), auto_unbox = TRUE), "\n", file = audit, append = TRUE)
    unlink(lock_path, recursive = TRUE)
    if (!dir.create(lock_path, showWarnings = FALSE)) stop("[ERROR] 回復後の再取得失敗")
  }
  token <- digest::digest(list(Sys.time(), Sys.getpid(), runif(1)), algo = "sha256")
  norm_run <- normalizePath(run_dir, winslash = "/")
  info <- list(pid = Sys.getpid(), hostname = unname(Sys.info()["nodename"]), stage = stage,
      run_dir = ".", run_dir_path_kind = "run_relative",
      run_dir_hash = digest::digest(norm_run, algo = "sha256", serialize = FALSE), token = token,
      process_start = paste(system2("ps", c("-p", Sys.getpid(), "-o", "lstart="), stdout = TRUE), collapse = " "),
      acquired_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
  atomic_run_json(info, file.path(lock_path, "lock_info.json"))
  list(lock_dir = lock_path, lock_id = basename(control), token = token, info = info, run_dir = norm_run)
}

release_stage_lock <- function(lock_obj) {
  if (is.null(lock_obj)) return(invisible(FALSE))
  assert_no_symlink(lock_obj$lock_dir)
  path <- file.path(lock_obj$lock_dir, "lock_info.json")
  current <- tryCatch(jsonlite::read_json(path), error = function(e) NULL)
  if (is.null(current) || !identical(current, lock_obj$info)) stop("[ERROR] ロック所有token/情報が一致しないため解放を拒絶")
  unlink(lock_obj$lock_dir, recursive = TRUE)
  invisible(TRUE)
}

# --- Task 1.7: run 内 staging 領域制御と promotion ---
get_run_staging_dir <- function(run_dir, check_sealed = TRUE) {
  norm_run <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  meta_path <- file.path(norm_run, "run_meta.json")
  if (file.exists(meta_path)) {
    meta <- tryCatch(jsonlite::fromJSON(meta_path, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.null(meta) && identical(meta$run_state, "sealed")) {
      stop("[ERROR] sealed 状態の run に対して staging を作成・変更することはできません: ", norm_run)
    }
  }
  staging <- assert_path_within_run_dir("staging", norm_run)
  if (!dir.exists(staging)) {
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  }
  staging
}

assert_staging_empty <- function(run_dir) {
  norm_run <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  staging <- assert_path_within_run_dir("staging", norm_run)
  if (dir.exists(staging)) {
    files <- list.files(staging, all.files = TRUE, no.. = TRUE)
    if (length(files) > 0L) {
      stop(
        "[ERROR] sealed 封印前に staging 領域が空ではありません。残存ファイル: ",
        paste(files, collapse = ", ")
      )
    }
    unlink(staging, recursive = TRUE)
  }
  invisible(TRUE)
}

assert_preview_can_generate <- function(run_dir, preview_filename) {
  meta <- read_run_control(run_dir, allow_legacy = TRUE)
  if (identical(meta$run_state, "sealed")) stop("[ERROR] sealed run へは書き込めません")
  target <- assert_path_within_run_dir(preview_filename, run_dir)
  if (file.exists(target)) stop("[ERROR] preview は既に生成済みです。上書きせず --supersedes-run を使用してください")
  invisible(target)
}

verify_narrative <- function(run_dir, meta, manifest_hash, expected = NULL) {
  if (!identical(meta$pass_status$pass2, "completed")) stop("[ERROR] Pass 2 が確定していません")
  art <- meta$artifacts$narrative
  name <- if (meta$skill == "questionnaire-batch-analysis") "cross_question_summary.md" else "executive_summary.md"
  if (is.null(art) || !identical(art$path, name) || !identical(art$based_on_results_manifest_sha256, manifest_hash)) stop("[ERROR] narrative由来が不一致")
  h <- sha256_file(assert_path_within_run_dir(name, run_dir))
  if (!identical(h, art$sha256) || (!is.null(expected) && !identical(h, expected))) stop("[ERROR] narrative_sha256 不一致")
  h
}

finalize_stage <- function(run_dir, stage, target_name, source_staging_path, expected_results_manifest_sha256,
                           expected_narrative_sha256 = NULL, recover_stale_lock = FALSE, common_lock = NULL) {
  run_dir <- normalizePath(assert_no_symlink(run_dir), mustWork = TRUE)
  if (is.null(common_lock)) {
    common <- acquire_stage_lock(run_dir, "run", recover_stale_lock)
    on.exit(release_stage_lock(common), add = TRUE, after = FALSE)
  } else {
    if (!identical(common_lock$run_dir, run_dir) || !identical(common_lock$info$stage, "run") ||
        !identical(jsonlite::read_json(file.path(common_lock$lock_dir, "lock_info.json")), common_lock$info)) stop("[ERROR] 共通ロック所有権が不一致")
  }
  lock <- acquire_stage_lock(run_dir, stage, recover_stale_lock)
  on.exit(release_stage_lock(lock), add = TRUE, after = FALSE)
  meta <- read_run_control(run_dir)
  if (meta$run_state == "sealed") stop("[ERROR] sealed run の確定を拒絶")
  if (meta$pass_status$pass1 != "completed") stop("[ERROR] partial / failed / pending run の本番確定を拒絶")
  if (meta$pass_status[[stage]] == "completed") stop("[ERROR] 確定済み成果物の再確定を拒絶")
  expected_name <- if (stage == "pass3") "dashboard.html" else if (meta$skill == "questionnaire-batch-analysis") "cross_question_summary.md" else "executive_summary.md"
  if (!identical(target_name, expected_name)) stop("[ERROR] target-name のallowlist不一致")
  if (is.null(expected_results_manifest_sha256) || !identical(meta$results_manifest_sha256, expected_results_manifest_sha256)) stop("[ERROR] 期待manifestハッシュが未指定または不一致")
  v <- verify_results_manifest(run_dir, expected_results_manifest_sha256)
  nh <- if (stage == "pass3") verify_narrative(run_dir, meta, v$manifest_sha256, expected_narrative_sha256) else NULL
  target <- assert_path_within_run_dir(target_name, run_dir)
  if (is.null(source_staging_path)) stop("[ERROR] source-artifact が必要です")
  staging <- file.path(run_dir, "staging")
  # 回復時はstaging自体が空でもsourceパスを検証できる。
  source <- assert_path_within_run_dir(source_staging_path, run_dir)
  if (!startsWith(source, paste0(staging, "/"))) stop("[ERROR] source はstaging配下でなければなりません")
  tx_path <- file.path(dirname(lock$lock_dir), paste0("transaction_", stage, ".json"))
  assert_no_symlink(tx_path)
  tx <- if (file.exists(tx_path)) jsonlite::read_json(tx_path) else NULL
  if (stage == "pass3" && dir.exists(staging)) {
    entries <- list.files(staging, all.files = TRUE, no.. = TRUE, recursive = TRUE, full.names = TRUE, include.dirs = TRUE)
    allowed <- source
    par <- dirname(source)
    while (par != staging) { allowed <- c(allowed, par); par <- dirname(par) }
    if (length(setdiff(entries, allowed))) stop("[ERROR] staging 領域が空ではありません（対象以外の残存）")
  }
  expected_tx <- list(run_dir = run_dir, stage = stage, source = source, target = target,
      expected_results_manifest_sha256 = v$manifest_sha256, expected_narrative_sha256 = nh)
  if (file.exists(target) || !is.null(tx)) {
    if (is.null(tx) || !all(vapply(names(expected_tx), function(k) identical(tx[[k]], expected_tx[[k]]), logical(1))) ||
        is.null(tx$sha256)) stop("[ERROR] 回復証跡が欠損または不一致")
    if (file.exists(target)) {
      if (!identical(sha256_file(target), tx$sha256) || file.exists(source)) stop("[ERROR] 回復target/sourceが不一致")
    } else {
      if (!file.exists(source) || !identical(sha256_file(source), tx$sha256)) stop("[ERROR] 回復sourceが不一致")
    }
  } else {
    if (!file_test("-f", source) || file.info(source)$size == 0) stop("[ERROR] source は空でない通常ファイルが必要です")
    tx <- c(expected_tx, list(sha256 = sha256_file(source)))
    atomic_run_json(tx, tx_path)
  }
  if (!file.exists(target)) {
    if (!file.rename(source, target)) stop("[ERROR] promotion の原子的rename失敗")
  }
  # 故障注入はR関数のoptionに限定し、通常CLIから有効化しない。
  hook <- getOption("run_scope.after_promotion")
  if (is.function(hook)) hook()
  verify_results_manifest(run_dir, expected_results_manifest_sha256)
  if (!identical(sha256_file(target), tx$sha256)) stop("[ERROR] promotion後ハッシュ不一致")
  if (stage == "pass3") {
    verify_narrative(run_dir, meta, v$manifest_sha256, nh)
    # 呼び出し専用の空ディレクトリを削除してから空検証。
    if (dir.exists(staging)) {
      dirs <- list.dirs(staging, recursive = TRUE, full.names = TRUE)
      for (d in rev(dirs)) if (d != staging && !length(list.files(d, all.files = TRUE, no.. = TRUE))) unlink(d, recursive = TRUE)
    }
    assert_staging_empty(run_dir)
    meta$run_state <- "sealed"
  }
  meta$pass_status[[stage]] <- "completed"
  art <- list(path = target_name, sha256 = tx$sha256, based_on_results_manifest_sha256 = v$manifest_sha256)
  if (stage == "pass3") art$based_on_narrative_sha256 <- nh
  meta$artifacts[[if (stage == "pass2") "narrative" else "dashboard"]] <- art
  meta$timestamps[[paste0(stage, "_completed")]] <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  if (stage == "pass3") meta$timestamps$sealed <- meta$timestamps$pass3_completed
  atomic_run_json(portableize_run_meta(meta, run_dir), file.path(run_dir, "run_meta.json"))
  list(run_dir = run_dir, target_name = target_name, sha256 = tx$sha256,
       results_manifest_sha256 = v$manifest_sha256, run_state = meta$run_state)
}

finalize_pass2 <- function(run_dir, target_name = "executive_summary.md", source_staging_path = NULL, expected_results_manifest_sha256 = NULL, recover_stale_lock = FALSE) {
  finalize_stage(run_dir, "pass2", target_name, source_staging_path, expected_results_manifest_sha256, recover_stale_lock = recover_stale_lock)
}
finalize_pass3 <- function(run_dir, target_name = "dashboard.html", source_staging_path = NULL, expected_results_manifest_sha256 = NULL, expected_narrative_sha256 = NULL, recover_stale_lock = FALSE) {
  finalize_stage(run_dir, "pass3", target_name, source_staging_path, expected_results_manifest_sha256, expected_narrative_sha256, recover_stale_lock)
}

# --- Task 1.13: supersede 元 run 検証 ---
verify_superseded_run <- function(source_run_dir, current_skill, current_run_dir = NULL) {
  norm_source <- normalizePath(source_run_dir, winslash = "/", mustWork = FALSE)
  if (!dir.exists(norm_source)) {
    stop("[ERROR] supersede 元 run ディレクトリが存在しません: ", source_run_dir)
  }

  # 自己参照拒絶
  if (!is.null(current_run_dir)) {
    norm_cur <- normalizePath(current_run_dir, winslash = "/", mustWork = FALSE)
    if (identical(norm_source, norm_cur)) {
      stop("[ERROR] 自己自身を supersede 元に指定することはできません: ", source_run_dir)
    }
  }

  meta_path <- file.path(norm_source, "run_meta.json")
  if (!file.exists(meta_path)) {
    stop("[ERROR] supersede 元 run に run_meta.json が存在しません: ", meta_path)
  }
  src_meta <- jsonlite::fromJSON(meta_path, simplifyVector = FALSE)

  # legacy run 拒絶 (Decision 7)
  if (identical(src_meta$interface_version, "1.0")) {
    stop("[ERROR] legacy run (v1.0) はマニフェストが存在しないため supersede 元として指定できません。")
  }

  # skill 一致検証
  if (!identical(src_meta$skill, current_skill)) {
    stop(
      "[ERROR] supersede 元 run の skill (", src_meta$skill, ") が現在の skill (", current_skill, ") と一致しません。"
    )
  }

  # pass1 failed 拒絶 (Decision 12)
  if (identical(src_meta$pass_status$pass1, "failed")) {
    stop("[ERROR] pass1 が failed の run を supersede 元に指定することはできません。")
  }

  # results_manifest 実ファイルバイト列ハッシュおよび成果物再計算・検証
  if (is.null(src_meta$results_manifest_sha256)) stop("[ERROR] 元runの期待manifestハッシュがありません")
  v_res <- verify_results_manifest(norm_source, src_meta$results_manifest_sha256)
  visited <- if (is.null(current_run_dir)) character() else normalizePath(current_run_dir, mustWork = FALSE)
  cursor <- norm_source
  repeat {
    if (cursor %in% visited) stop("[ERROR] supersede 循環参照を拒絶")
    visited <- c(visited, cursor)
    ancestor <- read_run_control(cursor)
    if (is.null(ancestor$supersedes_run) || !nzchar(ancestor$supersedes_run)) break
    cursor <- normalizePath(assert_no_symlink(ancestor$supersedes_run), mustWork = TRUE)
  }

  list(
    source_run_dir = norm_source,
    meta = src_meta,
    superseded_results_manifest_sha256 = v_res$manifest_sha256
  )
}

# --- Task 1.14: cwd 付き kind タグ付き機械可読ハンドオーバー ---
write_run_handover <- function(run_output_dir, skill, results_manifest_sha256, config_path = "analysis_config.json") {
  norm_run <- normalizePath(run_output_dir, winslash = "/", mustWork = TRUE)
  repo_root <- run_scope_detect_repo_root(norm_run)
  run_rec <- run_scope_portable_path(norm_run, repo_root, norm_run)
  run_arg <- if (!is.null(run_rec) && !identical(run_rec$path_kind, "external")) run_rec$path else "."

  narrative_file <- if (identical(skill, "questionnaire-batch-analysis")) "cross_question_summary.md" else "executive_summary.md"
  preview_narrative_file <- "executive_summary_preview.md"

  handover <- list(
    interface_version = "1.0",
    path_schema_version = RUN_SCOPE_PATH_SCHEMA_VERSION,
    run_output_dir = run_arg,
    run_output_dir_path_kind = if (!is.null(run_rec)) run_rec$path_kind else "run_relative",
    cwd = ".",
    cwd_kind = "repo_root_marker",
    repo_root_marker = ".",
    run_meta = "run_meta.json",
    results_manifest = "results_manifest.json",
    results_manifest_sha256 = results_manifest_sha256,
    config = config_path,
    next_actions = list(
      pass2_ai = list(
        kind = "agent_action",
        action = "narrative_generation",
        input_manifest = "results_manifest.json",
        expected_results_manifest_sha256 = results_manifest_sha256,
        output = narrative_file,
        staging_output = file.path("staging", narrative_file),
        instructions = "Pass 2 AI expert narrative generation. Write to staging_output first, then execute the finalize command.",
        finalize = list(
          kind = "command",
          argv = c(
            "Rscript",
            ".agents/shared/finalize_run_stage.R",
            "--stage", "pass2",
            "--run-dir", run_arg,
            "--source-artifact", file.path("staging", narrative_file),
            "--target-name", narrative_file,
            "--expected-results-manifest-sha256", results_manifest_sha256
          )
        )
      ),
      pass2_stub_preview = list(
        kind = "command",
        argv = c(
          "Rscript",
          switch(
            skill,
            "vcd-bayesian-evidence-analysis" = ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R",
            "vcd-categorical-analysis" = ".agents/skills/vcd-categorical-analysis/templates/analysis.R",
            "questionnaire-batch-analysis" = ".agents/skills/questionnaire-batch-analysis/templates/batch_runner.R"
          ),
          "--run-dir", run_arg
        ),
        output = preview_narrative_file,
        production_eligible = FALSE
      ),
      pass3_preview = list(
        kind = "command",
        argv = c(
          "Rscript",
          switch(
            skill,
            "vcd-bayesian-evidence-analysis" = ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
            "vcd-categorical-analysis" = ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
            "questionnaire-batch-analysis" = ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R"
          ),
          "--run-dir", run_arg,
          "--preview"
        ),
        output = "dashboard_preview.html",
        production_eligible = FALSE
      ),
      pass3 = list(
        kind = "command",
        argv = c(
          "Rscript",
          switch(
            skill,
            "vcd-bayesian-evidence-analysis" = ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
            "vcd-categorical-analysis" = ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
            "questionnaire-batch-analysis" = ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R"
          ),
          "--run-dir", run_arg
        ),
        output = "dashboard.html",
        requires = list("pass2_ai")
      )
    )
  )

  meta <- read_run_control(norm_run)
  if (skill != "vcd-bayesian-evidence-analysis") handover$next_actions$pass2_stub_preview <- NULL
  if (meta$pass_status$pass1 != "completed") {
    handover$next_actions <- list()
    handover$stop_reason <- paste0("Pass 1: ", meta$pass_status$pass1, "。本番後続処理を停止します")
  }
  handover_path <- assert_path_within_run_dir("run_handover.json", norm_run)
  if (meta$run_state == "sealed" || file.exists(handover_path)) stop("[ERROR] handover上書きを拒絶")
  jsonlite::write_json(handover, handover_path, pretty = TRUE, auto_unbox = TRUE)
  # 戻り値は同一プロセス内の後続処理向けに解決済み cwd を返すが、JSON は portable 表現を保持する。
  handover_runtime <- handover
  handover_runtime$cwd <- RUN_SCOPE_REPO_ROOT
  if (length(handover_runtime$next_actions)) {
    for (nm in names(handover_runtime$next_actions)) {
      action <- handover_runtime$next_actions[[nm]]
      if (is.list(action) && !is.null(action$argv)) {
        idx <- match("--run-dir", action$argv)
        if (!is.na(idx) && idx < length(action$argv)) action$argv[[idx + 1L]] <- norm_run
        idx2 <- match("--source-artifact", action$argv)
        if (!is.na(idx2) && idx2 < length(action$argv)) action$argv[[idx2 + 1L]] <- file.path(norm_run, "staging", narrative_file)
        handover_runtime$next_actions[[nm]] <- action
      }
    }
  }
  invisible(handover_runtime)
}

# --- Task 1.15: resolve_pass3_run_dir 改定 ---
resolve_pass3_run_dir <- function(root, required_filename, skill_label = "output", discover_single_run = FALSE, allow_legacy = FALSE) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(root)) {
    stop(
      "[ERROR] 出力ディレクトリが存在しません: ", root,
      "。Pass 1 で生成した out_root または run_output_dir を params$run_dir に指定してください。"
    )
  }

  # 直接指定の場合（直下に required_filename または run_meta.json がある）
  direct_file <- file.path(root, required_filename)
  direct_meta <- file.path(root, "run_meta.json")
  if (!discover_single_run && (file.exists(direct_file) || file.exists(direct_meta))) {
    meta <- tryCatch(jsonlite::fromJSON(direct_meta, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.null(meta) && identical(meta$interface_version, "1.0") && !isTRUE(allow_legacy)) {
      stop("[ERROR] legacy run (v1.0) を読み取るには --allow-legacy-run-meta が必要です: ", root)
    }
    return(list(run_dir = root, run_meta = meta, resolved_from = "direct"))
  }

  # 暗黙探索の廃止と --discover-single-run
  if (!isTRUE(discover_single_run)) {
    stop(
      "[ERROR] 実 run ディレクトリを --run-dir <path> で直接指定してください: ", root,
      " は親ディレクトリです（暗黙の mtime 自動選択は廃止されました）。探索を行う場合は明示的に --discover-single-run を指定してください。"
    )
  }

  # 親直下とサブディレクトリの合算候補走査
  candidates <- character(0)
  if (file.exists(direct_file)) {
    candidates <- c(candidates, root)
  }

  subdirs <- list.dirs(root, full.names = TRUE, recursive = FALSE)
  sub_runs <- subdirs[grepl("^(run_.*|runs)$", basename(subdirs))]
  # runs/ 配下も走査
  if (file.exists(file.path(root, "runs"))) {
    runs_children <- list.dirs(file.path(root, "runs"), full.names = TRUE, recursive = FALSE)
    sub_runs <- c(sub_runs[basename(sub_runs) != "runs"], runs_children)
  }

  for (s in sub_runs) {
    if (file.exists(file.path(s, required_filename))) {
      candidates <- c(candidates, s)
    }
  }
  candidates <- unique(candidates)

  if (length(candidates) == 0L) {
    stop(
      "[ERROR] ", required_filename, " を含む有効な run が見つかりません。探索先: ", root
    )
  }
  if (length(candidates) >= 2L) {
    stop(
      "[ERROR] 複数の run 候補が見つかりました (", length(candidates), " 件): ",
      paste(basename(candidates), collapse = ", "),
      "。--run-dir <path> で対象 run を一意に指定してください。"
    )
  }

  # ちょうど 1 件
  single_cand <- candidates[1L]
  meta <- tryCatch(jsonlite::fromJSON(file.path(single_cand, "run_meta.json"), simplifyVector = FALSE), error = function(e) NULL)
  if (!is.null(meta) && identical(meta$interface_version, "1.0") && !isTRUE(allow_legacy)) {
    stop("[ERROR] legacy run (v1.0) を採用するには --allow-legacy-run-meta が必要です: ", single_cand)
  }

  message("[WARN] --discover-single-run により唯一の候補を採用しました: ", single_cand)
  list(run_dir = single_cand, run_meta = meta, resolved_from = "discovered_single")
}

# --- メタデータ書き込み（v2.0 統合） ---
write_run_meta <- function(out_root, run_output_dir, skill, run_id, input_data_path = NULL, extra = NULL) {
  extra <- if (is.null(extra)) list() else extra
  original_inputs <- extra$inputs
  norm_root <- normalizePath(out_root, winslash = "/", mustWork = FALSE)
  norm_run <- normalizePath(assert_no_symlink(run_output_dir), winslash = "/", mustWork = FALSE)
  repo_root <- run_scope_detect_repo_root(norm_run)
  if (is.null(repo_root)) repo_root <- tryCatch(run_scope_repo_root(start = norm_run), error = function(e) NULL)
  prior <- NULL
  if (file.exists(file.path(norm_run, "run_meta.json"))) {
    prior <- read_run_control(norm_run)
    if (prior$run_state == "sealed" || prior$pass_status$pass1 == "completed") stop("[ERROR] 確定済みPass 1メタデータの再作成を拒絶")
  }

  inputs <- list()
  if (!is.null(input_data_path) && nzchar(trimws(input_data_path))) {
    norm_input <- normalizePath(input_data_path, winslash = "/", mustWork = FALSE)
    inputs[[1L]] <- list(role = "data", source_kind = "file", source_path = norm_input,
      snapshot = NULL, snapshot_policy = "hash_only",
      sha256 = if (file.exists(norm_input)) sha256_file(norm_input) else NULL)
  }
  if (!is.null(extra$inputs)) inputs <- extra$inputs
  inputs <- lapply(inputs, function(item) {
    item <- as.list(item)
    item$role <- as.character(item$role %||% "data")
    item$source_kind <- as.character(item$source_kind %||% "file")
    item$snapshot_policy <- "hash_only"
    if (identical(item$source_kind, "builtin")) {
      item$source_path_kind <- "builtin"
      item$source_path <- item$source_path %||% item$logical_label %||% "builtin"
    } else {
      raw_path <- item$source_path %||% item$input_data
      resolved_path <- if (!is.null(raw_path) && nzchar(as.character(raw_path))) normalizePath(as.character(raw_path), winslash = "/", mustWork = FALSE) else NULL
      if (!is.null(resolved_path) && file.exists(resolved_path) && is.null(item$sha256)) item$sha256 <- sha256_file(resolved_path)
      rec <- if (!is.null(resolved_path)) run_scope_portable_path(resolved_path, repo_root, norm_run) else NULL
      if (!is.null(rec) && !identical(rec$path_kind, "external")) {
        item$source_path <- rec$path
        item$source_path_kind <- rec$path_kind
      } else {
        item$source_path <- NA_character_
        item$source_path_kind <- "external"
        item$logical_label <- item$logical_label %||% if (!is.null(raw_path)) basename(as.character(raw_path)) else "external_input"
      }
    }
    item
  })
  for (item in inputs) {
    if (is.null(item$role) || !item$source_kind %in% c("file", "builtin") || is.null(item$sha256) || !grepl("^[0-9a-f]{64}$", item$sha256)) stop("[ERROR] inputsが不正")
    if (!is.null(item[["snapshot"]]) || (!is.null(item$snapshot_policy) && item$snapshot_policy != "hash_only")) stop("[ERROR] データはhash_onlyです")
  }
  cfg_path <- file.path(norm_run, "analysis_config.json")
  if (is.null(extra$config_sha256) && file.exists(cfg_path)) extra$config_sha256 <- sha256_file(cfg_path)
  if (!is.null(extra$supersedes_run)) {
    src <- verify_superseded_run(extra$supersedes_run, skill, norm_run)$meta
    signature <- function(xs) lapply(xs, function(x) list(role = x$role, source_kind = x$source_kind, sha256 = x$sha256))
    extra$inputs_changed <- !identical(signature(src$inputs), signature(inputs))
    qcfg <- file.path(norm_run, "question_config.csv")
    qhash <- if (file.exists(qcfg)) sha256_file(qcfg) else NULL
    extra$config_changed <- !identical(src$config_sha256, extra$config_sha256) || !identical(src$question_config_sha256, qhash)
  }
  out_rec <- run_scope_portable_path(norm_root, repo_root, norm_run)
  run_rec <- run_scope_portable_path(norm_run, repo_root, norm_run)
  if (is.null(run_rec) || identical(run_rec$path_kind, "external")) run_rec <- list(path = ".", path_kind = "run_relative")
  sup_rec <- if (!is.null(extra$supersedes_run)) run_scope_portable_path(extra$supersedes_run, repo_root, norm_run) else NULL
  # supersede は明示的な CLI 指定なので、リポジトリ外の元 run だけ外部絶対パスを許可する。
  if (!is.null(sup_rec) && identical(sup_rec$path_kind, "external")) sup_rec$path <- normalizePath(extra$supersedes_run, winslash = "/", mustWork = FALSE)
  cfg_rec <- if (!is.null(extra$config_source_path)) {
    if (!is.null(extra$config_source_path_kind)) list(path = extra$config_source_path, path_kind = extra$config_source_path_kind) else run_scope_portable_path(extra$config_source_path, repo_root, norm_run)
  } else NULL
  meta <- list(
    interface_version = RUN_META_INTERFACE_VERSION_V2,
    path_schema_version = RUN_SCOPE_PATH_SCHEMA_VERSION,
    skill = skill, run_id = as.character(run_id), run_id_short = run_id_short16(run_id),
    requested_run_id = extra$requested_run_id %||% NULL,
    logical_run_id = extra$logical_run_id %||% extra$requested_run_id %||% as.character(run_id),
    run_state = "active",
    supersedes_run = if (!is.null(sup_rec)) sup_rec$path else NA_character_,
    supersedes_run_path_kind = if (!is.null(sup_rec)) sup_rec$path_kind else NULL,
    superseded_results_manifest_sha256 = extra$superseded_results_manifest_sha256 %||% NULL,
    supersede_reason = extra$supersede_reason %||% NULL,
    inputs_changed = extra$inputs_changed %||% NULL, config_changed = extra$config_changed %||% NULL,
    out_root = if (!is.null(out_rec) && !identical(out_rec$path_kind, "external")) out_rec$path else NA_character_,
    out_root_path_kind = if (!is.null(out_rec)) out_rec$path_kind else "external",
    run_output_dir = run_rec$path, run_output_dir_path_kind = run_rec$path_kind,
    results_manifest = "results_manifest.json", results_manifest_sha256 = extra$results_manifest_sha256 %||% NULL,
    inputs = inputs, config_origin = extra$config_origin %||% "pass0_file",
    config_source_path = if (!is.null(cfg_rec)) cfg_rec$path else NA_character_,
    config_source_path_kind = if (!is.null(cfg_rec)) cfg_rec$path_kind else NULL,
    config_snapshot = extra$config_snapshot %||% "analysis_config.json", config_sha256 = extra$config_sha256 %||% NULL,
    question_config_sha256 = if (file.exists(file.path(norm_run, "question_config.csv"))) sha256_file(file.path(norm_run, "question_config.csv")) else NULL,
    artifacts = list(), partial_failures = extra$partial_failures %||% NULL,
    pass_status = list(pass0 = extra$pass_status$pass0 %||% "completed",
      pass1 = extra$pass_status$pass1 %||% if (!is.null(extra$results_manifest_sha256)) "completed" else "pending",
      pass2 = extra$pass_status$pass2 %||% "pending", pass3 = extra$pass_status$pass3 %||% "pending"),
    timestamps = list(created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), pass1_completed = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))
  )
  if (length(extra)) for (nm in names(extra)) if (!nm %in% c("pass_status", "timestamps", "inputs", "supersedes_run", "config_source_path", "config_source_path_kind", "out_root", "run_output_dir", "path_schema_version")) meta[[nm]] <- extra[[nm]]
  sanitize_paths <- function(x) {
    if (is.list(x)) return(lapply(x, sanitize_paths))
    if (is.character(x) && length(x) == 1L && run_scope_is_absolute_path(x)) {
      rec <- run_scope_portable_path(x, repo_root, norm_run)
      return(if (!is.null(rec) && !identical(rec$path_kind, "external")) rec$path else NULL)
    }
    x
  }
  explicit_supersede <- if (!is.null(meta$supersedes_run) && run_scope_is_absolute_path(meta$supersedes_run) && identical(meta$supersedes_run_path_kind, "external")) meta$supersedes_run else NULL
  meta <- sanitize_paths(meta)
  if (!is.null(explicit_supersede)) meta$supersedes_run <- explicit_supersede
  meta$path_schema_version <- RUN_SCOPE_PATH_SCHEMA_VERSION
  if (!is.null(prior)) meta$timestamps$created <- prior$timestamps$created
  if (meta$pass_status$pass1 != "completed") meta$timestamps$pass1_completed <- NULL
  atomic_run_json(meta, file.path(norm_run, "run_meta.json"))
  runtime_meta <- resolve_run_meta_paths(meta, norm_run, allow_legacy = TRUE)
  if (!is.null(input_data_path) && length(runtime_meta$inputs)) runtime_meta$inputs[[1L]]$source_path <- normalizePath(input_data_path, winslash = "/", mustWork = FALSE)
  if (!is.null(original_inputs)) runtime_meta$inputs <- original_inputs
  invisible(runtime_meta)
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


# preview と本番レンダラーが同じ状態ガードを使用する。
publish_run_preview <- function(run_dir, name, generate, allow_legacy = FALSE, preview_output_dir = NULL) {
  run_dir <- normalizePath(assert_no_symlink(run_dir), mustWork = TRUE)
  meta <- read_run_control(run_dir, allow_legacy)
  legacy <- identical(meta$interface_version, "1.0")
  if (legacy) {
    if (is.null(preview_output_dir)) stop("[ERROR] legacy preview は --preview-output-dir が必須です")
    output <- assert_no_symlink(preview_output_dir)
    if (output == run_dir || startsWith(output, paste0(run_dir, "/"))) stop("[ERROR] legacy previewの出力先は元run外にしてください")
    if (!dir.exists(output) && !dir.create(output, recursive = TRUE)) stop("[ERROR] preview出力先作成失敗")
    mutex <- file.path(output, paste0(".", name, ".lock"))
    assert_no_symlink(mutex)
    if (!dir.create(mutex, showWarnings = FALSE)) stop("[ERROR] preview公開が進行中です")
    on.exit(unlink(mutex, recursive = TRUE), add = TRUE)
    message("[WARN] legacy preview: manifest検証対象外。元runは変更しません")
  } else {
    lock <- acquire_stage_lock(run_dir, "run")
    on.exit(release_stage_lock(lock), add = TRUE, after = FALSE)
    meta <- read_run_control(run_dir)
    assert_preview_can_generate(run_dir, name)
    if (name == "executive_summary_preview.md" && meta$pass_status$pass2 == "completed") stop("[ERROR] 確定済みPass 2からstubへ戻せません")
    verify_results_manifest(run_dir, meta$results_manifest_sha256)
    output <- run_dir
  }
  target <- assert_path_within_run_dir(name, output)
  if (file.exists(target)) stop("[ERROR] previewは既に生成済みです。上書き拒絶")
  work_parent <- if (legacy) output else dirname(lock$lock_dir)
  work <- tempfile("preview_", tmpdir = work_parent)
  if (!dir.create(work)) stop("[ERROR] preview作業領域作成失敗")
  on.exit(unlink(work, recursive = TRUE), add = TRUE, after = FALSE)
  generated <- file.path(work, name)
  generate(generated)
  if (legacy && file.exists(generated)) {
    content <- readLines(generated, warn = FALSE, encoding = "UTF-8")
    warning <- "警告: legacy run のpreviewです。manifestの完全性は未検証で、本番確定には利用できません。"
    if (grepl("[.]html$", name)) {
      content <- sub("(<body[^>]*>)", paste0("\\1<div role='alert'>", warning, "</div>"), content, perl = TRUE)
    } else content <- c(paste0("> ", warning), "", content)
    writeLines(content, generated, useBytes = TRUE)
  }
  if (!file.exists(generated) || file.info(generated)$size == 0) stop("[ERROR] preview生成失敗")
  if (!legacy) verify_results_manifest(run_dir, meta$results_manifest_sha256)
  h <- sha256_file(generated)
  if (!file.rename(generated, target)) stop("[ERROR] preview公開rename失敗")
  if (!legacy) {
    key <- if (name == "executive_summary_preview.md") "narrative_preview" else "dashboard_preview"
    meta$artifacts[[key]] <- list(path = name, sha256 = h)
    if (key == "narrative_preview") meta$pass_status$pass2 <- "stub_generated"
    atomic_run_json(portableize_run_meta(meta, run_dir), file.path(run_dir, "run_meta.json"))
  }
  invisible(target)
}

render_run_dashboard <- function(run_dir, rmd_path, preview = FALSE, allow_legacy = FALSE,
                                  preview_output_dir = NULL, recover_stale = FALSE) {
  render <- function(target, is_preview) {
    work <- dirname(target)
    # Rmdも一時領域へ複製し、knitr中間生成物がテンプレートを汚さないようにする。
    local_rmd <- file.path(work, "dashboard_source.Rmd")
    if (!file.copy(rmd_path, local_rmd, overwrite = FALSE)) stop("[ERROR] Rmd作業コピー失敗")
    rmarkdown::render(local_rmd, output_file = basename(target), output_dir = work,
      intermediates_dir = work, knit_root_dir = RUN_SCOPE_REPO_ROOT,
      params = list(run_dir = run_dir, preview_mode = is_preview, require_pass2 = !is_preview,
                    repo_root = RUN_SCOPE_REPO_ROOT),
      envir = new.env(parent = globalenv()), quiet = TRUE)
    if (!file.exists(target)) stop("[ERROR] ダッシュボードが生成されません")
    # 自分の一時作業領域だけを掃除し、公開対象HTMLを残す。
    extra <- setdiff(list.files(work, all.files = TRUE, no.. = TRUE, full.names = TRUE), target)
    if (length(extra)) unlink(extra, recursive = TRUE)
  }
  if (preview) return(publish_run_preview(run_dir, "dashboard_preview.html", function(target) render(target, TRUE), allow_legacy, preview_output_dir))
  lock <- acquire_stage_lock(run_dir, "run", recover_stale)
  on.exit(release_stage_lock(lock), add = TRUE)
  meta <- read_run_control(run_dir)
  if (meta$run_state == "sealed" || meta$pass_status$pass1 != "completed") stop("[ERROR] sealed / partial / failed runの本番描画を拒絶")
  verify_results_manifest(run_dir, meta$results_manifest_sha256)
  nh <- verify_narrative(run_dir, meta, meta$results_manifest_sha256)
  staging <- get_run_staging_dir(run_dir)
  work <- tempfile("render_", tmpdir = staging)
  if (!dir.create(work)) stop("[ERROR] render作業領域作成失敗")
  target <- file.path(work, "dashboard.html")
  # promotion前の描画失敗だけは自分の作業領域を破棄できる。
  tryCatch(render(target, FALSE), error = function(e) { unlink(work, recursive = TRUE); stop(e) })
  finalize_stage(run_dir, "pass3", "dashboard.html", target, meta$results_manifest_sha256,
    nh, recover_stale, common_lock = lock)
}
