#!/usr/bin/env Rscript
# Pass 3: render_dashboard.R (vcd-categorical-analysis)
# --run-dir による実 run 直接受け入れ、プレビュー生成（dashboard_preview.html）および本番封印確定（dashboard.html / finalize_pass3）

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) {
    utils::install.packages("pacman", repos = "https://cloud.r-project.org")
  }
  pacman::p_load(rmarkdown, jsonlite)
})

caf <- grep("^--file=", commandArgs(), value = TRUE)
if (length(caf)) {
  sp <- sub("^--file=", "", caf[[length(caf)]])
  script_dir <- normalizePath(dirname(sp), winslash = "/", mustWork = TRUE)
} else {
  script_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

find_repo_root <- function() {
  d <- script_dir
  for (k in seq_len(24L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) {
      return(normalizePath(d, winslash = "/", mustWork = TRUE))
    }
    if (identical(basename(d), ".agents") && file.exists(file.path(d, "shared", "run_scope.R"))) {
      return(normalizePath(dirname(d), winslash = "/", mustWork = TRUE))
    }
    parent <- dirname(d)
    if (identical(parent, d)) {
      break
    }
    d <- parent
  }
  stop("リポジトリルートを特定できません（.agents/shared/run_scope.R が見つかりません）", call. = FALSE)
}

repo_root <- find_repo_root()
source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

args <- commandArgs(trailingOnly = TRUE)

if (any(args %in% c("-h", "--help"))) {
  cat("Usage: Rscript render_dashboard.R --run-dir <run_dir> [OPTIONS]

Options:
  --run-dir <path>             対象の実 run ディレクトリ（推奨）
  --output_dir <path>          旧互換: Pass 1 で指定した out_root または run_dir
  --rmd <path>                 dashboard.Rmd（省略時は本スクリプトと同ディレクトリ）
  --preview-output-dir <path>  legacy preview専用の元run外出力先
  --preview                    プレビューモードで dashboard_preview.html を出力（未封印）
  --recover-stale-lock         stale ロックの回復を許可
  --allow-legacy-run-meta      legacy run (v1.0) のプレビューを許可
  --discover-single-run        親ディレクトリ指定時に単一候補を警告付き自動採用
")
  quit(status = 0L)
}

is_preview <- ("--preview" %in% args)
recover_stale <- ("--recover-stale-lock" %in% args)
allow_legacy <- ("--allow-legacy-run-meta" %in% args)
discover_single <- ("--discover-single-run" %in% args)

run_dir_arg <- NULL
out_root_arg <- NULL
rmd_arg <- NULL

i <- 1L
while (i <= length(args)) {
  if (identical(args[i], "--run-dir") && i < length(args)) {
    run_dir_arg <- args[i + 1L]
    i <- i + 2L
  } else if ((identical(args[i], "--output_dir") || identical(args[i], "--output-dir") || identical(args[i], "--out")) && i < length(args)) {
    out_root_arg <- args[i + 1L]
    i <- i + 2L
  } else if (identical(args[i], "--rmd") && i < length(args)) {
    rmd_arg <- args[i + 1L]
    i <- i + 2L
  } else {
    i <- i + 1L
  }
}

# run_dir の解決
run_dir <- if (!is.null(run_dir_arg) && nzchar(trimws(run_dir_arg))) {
  normalizePath(assert_no_symlink(trimws(run_dir_arg)), winslash = "/", mustWork = TRUE)
} else if (!is.null(out_root_arg) && nzchar(trimws(out_root_arg))) {
  rs <- resolve_pass3_run_dir(
    out_root_arg,
    "categorical_results.json",
    discover_single_run = discover_single,
    allow_legacy = allow_legacy
  )
  rs$run_dir
} else {
  stop("[ERROR] --run-dir <path> が指定されていません。", call. = FALSE)
}

# run_meta.json の検証
meta_file <- file.path(run_dir, "run_meta.json")
if (!file.exists(meta_file)) {
  stop("[ERROR] run_meta.json が見つかりません: ", meta_file, call. = FALSE)
}
run_meta <- jsonlite::fromJSON(meta_file, simplifyVector = FALSE)

if (identical(run_meta$run_state, "sealed")) {
  stop("[ERROR] sealed 状態の run に対してダッシュボードの生成・再確定はできません: ", run_dir, call. = FALSE)
}

if (identical(run_meta$interface_version, "1.0")) {
  if (!is_preview || !isTRUE(allow_legacy)) {
    stop("[ERROR] legacy run (v1.0) に対する本番確定は拒絶されます。プレビューのみ --allow-legacy-run-meta で可能です。", call. = FALSE)
  }
}

rmd_path <- if (!is.null(rmd_arg) && nzchar(rmd_arg)) {
  normalizePath(rmd_arg, winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(script_dir, "dashboard.Rmd"), winslash = "/", mustWork = TRUE)
}
if (!file.exists(rmd_path)) {
  stop("dashboard.Rmd が見つかりません: ", rmd_path, call. = FALSE)
}

preview_output <- NULL
idx <- match("--preview-output-dir", args)
if (!is.na(idx) && idx < length(args)) preview_output <- args[idx + 1L]
render_run_dashboard(run_dir, rmd_path, is_preview, allow_legacy, preview_output, recover_stale)
