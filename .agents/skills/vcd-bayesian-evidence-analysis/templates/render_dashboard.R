#!/usr/bin/env Rscript
# =============================================================================
# Pass 3: render_dashboard.R
# 【正本レポートレンダラー】
# Pass 2.5 主張ゲート (Claims Gate) の検証を経て、完全オフラインの
# 単一HTMLダッシュボード（dashboard.html / dashboard_preview.html）を生成
# =============================================================================

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
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("[ERROR] リポジトリルートを特定できません", call. = FALSE)
}

repo_root <- find_repo_root()

# 共有依存関係チェック
dep_check_path <- file.path(repo_root, ".agents", "shared", "dependency_check.R")
if (file.exists(dep_check_path)) {
  source(dep_check_path)
  check_r_dependencies(c("rmarkdown", "jsonlite"), "Pass 3 レポートレンダラー")
}

suppressPackageStartupMessages({
  library(rmarkdown)
  library(jsonlite)
})

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))
source(file.path(script_dir, "claims_gate.R"))

args <- commandArgs(trailingOnly = TRUE)

if (any(args %in% c("-h", "--help"))) {
  cat("Usage: Rscript render_dashboard.R --run-dir <run_dir> [OPTIONS]

Options:
  --run-dir <path>             対象の実 run ディレクトリ（必須）
  --output_dir <path>          旧互換
  --rmd <path>                 dashboard.Rmd（省略時は本スクリプトと同ディレクトリ）
  --preview                    プレビューモードで dashboard_preview.html を出力（未封印）
  --layout-variant <band|card> 最良モデル表示のレイアウト案選択（既定: band）
")
  quit(status = 0L)
}

is_preview <- ("--preview" %in% args)
run_dir_arg <- NULL
out_root_arg <- NULL
rmd_arg <- NULL
layout_variant <- "band"
output_file_arg <- NULL

i <- 1L
while (i <= length(args)) {
  if (identical(args[i], "--run-dir") && i < length(args)) {
    run_dir_arg <- args[i + 1L]
    i <- i + 2L
  } else if ((identical(args[i], "--output_dir") || identical(args[i], "--output-dir")) && i < length(args)) {
    out_root_arg <- args[i + 1L]
    i <- i + 2L
  } else if (identical(args[i], "--rmd") && i < length(args)) {
    rmd_arg <- args[i + 1L]
    i <- i + 2L
  } else if (identical(args[i], "--layout-variant") && i < length(args)) {
    layout_variant <- args[i + 1L]
    i <- i + 2L
  } else if (identical(args[i], "--output-file") && i < length(args)) {
    output_file_arg <- args[i + 1L]
    i <- i + 2L
  } else {
    i <- i + 1L
  }
}

run_dir <- if (!is.null(run_dir_arg) && nzchar(trimws(run_dir_arg))) {
  normalizePath(trimws(run_dir_arg), winslash = "/", mustWork = TRUE)
} else if (!is.null(out_root_arg) && nzchar(trimws(out_root_arg))) {
  rs <- resolve_pass3_run_dir(out_root_arg, "evidence_results.json")
  rs$run_dir
} else {
  stop("[ERROR] --run-dir <path> が指定されていません。", call. = FALSE)
}

results_json_path <- file.path(run_dir, "evidence_results.json")
if (!file.exists(results_json_path)) {
  stop(sprintf("[ERROR] evidence_results.json が見つかりません: %s", results_json_path), call. = FALSE)
}

# --- Pass 2.5 主張ゲート (Claims Gate) の実行 ---
if (!is_preview) {
  message("[INFO] Pass 2.5 主張ゲート (Claims Gate) を実行中...")
  summ_file <- file.path(run_dir, "executive_summary.md")
  qc_file <- file.path(run_dir, "quality_check.md")
  claims_file <- file.path(run_dir, "narrative_claims.json")

  missing_pass2 <- character(0)
  if (!file.exists(summ_file)) missing_pass2 <- c(missing_pass2, "executive_summary.md")
  if (!file.exists(qc_file)) missing_pass2 <- c(missing_pass2, "quality_check.md")
  if (!file.exists(claims_file)) missing_pass2 <- c(missing_pass2, "narrative_claims.json")

  if (length(missing_pass2) > 0L) {
    stop(sprintf(
      "[ERROR] 本番ダッシュボード生成に必要な Pass 2/2.5 成果物が不足しています: %s\nPass 2 を完了して narrative_claims.json を作成してください。",
      paste(missing_pass2, collapse = ", ")
    ), call. = FALSE)
  }

  # 数値照合ゲートの実行
  verify_narrative_claims(results_json_path, claims_file)
} else {
  message("[INFO] プレビューモード: 主張ゲートをスキップします。")
}

# --- Rmd レンダリング ---
rmd_path <- if (!is.null(rmd_arg)) {
  normalizePath(rmd_arg, winslash = "/", mustWork = TRUE)
} else {
  file.path(script_dir, "dashboard.Rmd")
}

output_file_name <- if (!is.null(output_file_arg) && nzchar(trimws(output_file_arg))) {
  basename(trimws(output_file_arg))
} else if (is_preview) {
  "dashboard_preview.html"
} else {
  "dashboard.html"
}
target_html_path <- file.path(run_dir, output_file_name)

message(sprintf("[INFO] レンダリング開始: %s -> %s", basename(rmd_path), target_html_path))

rmarkdown::render(
  input = rmd_path,
  output_file = output_file_name,
  output_dir = run_dir,
  params = list(
    run_dir = run_dir,
    preview_mode = is_preview,
    layout_variant = layout_variant
  ),
  quiet = TRUE
)

if (!file.exists(target_html_path)) {
  stop("[ERROR] HTMLの生成に失敗しました。", call. = FALSE)
}

# --- 完全オフライン性の検査 ---
html_content <- readLines(target_html_path, warn = FALSE, encoding = "UTF-8")
external_reqs <- grep("https?://(?!localhost|127\\.0\\.0\\.1)", html_content, perl = TRUE, value = TRUE)
# MathJax や外部フォント、外部スクリプトの混入を厳格にチェック
bad_external <- grep("<(script|link)[^>]+src=[\"']https?://|<(script|link)[^>]+href=[\"']https?://", html_content, perl = TRUE, value = TRUE)

if (length(bad_external) > 0L) {
  warning(sprintf("[WARN] 生成された HTML に外部リソース参照が含まれています:\n%s", paste(bad_external, collapse = "\n")))
} else {
  message("[INFO] 完全オフライン検証合格: 外部 script / css 要求は 0 件です。")
}

h_html <- digest::digest(file = target_html_path, algo = "sha256")
message(sprintf("[SUCCESS] ダッシュボード生成完了: %s (SHA-256: %s)", target_html_path, h_html))
