# if (!require("pacman")) install.packages("pacman")
# pacman::p_load(dplyr, jsonlite, readr)
library(dplyr)
library(jsonlite)
library(readr)

args <- commandArgs(trailingOnly = TRUE)

# 出力先ディレクトリを指定できるようにする。run ごとに一意なディレクトリを
# 渡すことで、入力を変えて再実行しても過去の inspection_results.json を
# 上書きしない（既定はカレントディレクトリで後方互換）。
# 使い方: Rscript inspect_data.R <input.csv> [<out_dir>]
#         Rscript inspect_data.R <input.csv> --out-dir <out_dir>
out_dir <- "."
positional <- character(0)
i <- 1L
while (i <= length(args)) {
  a <- args[[i]]
  if (identical(a, "--out-dir")) {
    if (i == length(args)) stop("--out-dir requires a value")
    out_dir <- args[[i + 1L]]
    i <- i + 2L
  } else if (grepl("^--out-dir=", a)) {
    out_dir <- sub("^--out-dir=", "", a)
    i <- i + 1L
  } else {
    positional <- c(positional, a)
    i <- i + 1L
  }
}
input_file <- if (length(positional) >= 1L) positional[[1L]] else "examples/titanic.csv"
if (length(positional) >= 2L) out_dir <- positional[[2L]]
out_dir <- trimws(out_dir)
if (!nzchar(out_dir)) {
  stop("[ERROR] out-dir は空にできません")
}

if (!file.exists(input_file)) {
  stop(paste("File not found:", input_file))
}

input_abs <- normalizePath(input_file, winslash = "/", mustWork = TRUE)
repo_root <- tryCatch({
  x <- suppressWarnings(system2("git", c("-C", dirname(input_abs), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE))
  if (length(x) == 1L && nzchar(trimws(x))) normalizePath(trimws(x), winslash = "/", mustWork = TRUE) else NULL
}, error = function(e) NULL)
file_rel <- if (!is.null(repo_root) && (input_abs == repo_root || startsWith(input_abs, paste0(repo_root, "/")))) {
  substring(input_abs, nchar(repo_root) + 2L)
} else NULL
if (!requireNamespace("digest", quietly = TRUE)) {
  stop("[ERROR] 入力SHA-256の計算には digest パッケージが必要です。")
}
input_sha256 <- digest::digest(file = input_abs, algo = "sha256")
if (!is.character(input_sha256) || length(input_sha256) != 1L ||
    is.na(input_sha256) || !grepl("^[0-9a-f]{64}$", input_sha256)) {
  stop("[ERROR] 入力SHA-256を正しい形式で計算できませんでした。")
}

df <- read_csv(input_file, show_col_types = FALSE)

# readr は空の列名を ...N に補正する。空列名と「先頭だけ文字列・残りは数値」
# の組合せは、2段ヘッダーを1段ヘッダーCSVとして読んだ典型的な形である。
# この場合に数値列を推測して設定を自動確定すると、分析設計を誤るため停止可能な
# 診断として成果物へ残す。
is_numeric_like <- function(x) {
  values <- trimws(as.character(x))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) return(FALSE)
  all(grepl("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$", values, perl = TRUE))
}

generated_names <- grepl("^\\.\\.\\.[0-9]+$", names(df)) | !nzchar(names(df))
header_like_columns <- character(0)
if (nrow(df) >= 2L) {
  for (col_name in names(df)) {
    values <- as.character(df[[col_name]])
    first_value <- trimws(values[[1L]])
    remaining <- values[-1L]
    if (!is.na(first_value) && nzchar(first_value) && !is_numeric_like(first_value) && is_numeric_like(remaining)) {
      header_like_columns <- c(header_like_columns, col_name)
    }
  }
}

diagnostics <- list()
inspection_status <- "ready"
if (any(generated_names) && length(header_like_columns) > 0L) {
  inspection_status <- "needs_input_preparation"
  diagnostics[[length(diagnostics) + 1L]] <- list(
    code = "possible_multirow_header",
    message = "空列名と先頭行の見出しらしい文字列を検出しました。2段ヘッダーまたは整形前の集計表の可能性があるため、分析設定を自動確定できません。",
    generated_column_names = names(df)[generated_names],
    header_like_columns = header_like_columns
  )
}

# Categorical details
cat_vars <- df %>% select(where(is.character), where(is.factor))
cat_details <- list()

if (ncol(cat_vars) > 0) {
  for (col_name in names(cat_vars)) {
    col_data <- cat_vars[[col_name]]
    cat_details[[col_name]] <- list(
      levels = unique(col_data) %>% as.character() %>% sort(),
      n_levels = n_distinct(col_data),
      top_counts = table(col_data) %>% sort(decreasing = TRUE) %>% head(5) %>% as.list()
    )
  }
}

output <- list(
  inspection_contract_version = "2.0",
  inspection_status = inspection_status,
  diagnostics = diagnostics,
  file = file_rel,
  file_path_kind = if (!is.null(file_rel)) "repo_relative" else "external",
  input_sha256 = input_sha256,
  # inspection contract 1.0 の成果物を利用する呼び出し元との移行互換。
  # 新規の実装は input_sha256 を正本として参照する。
  file_sha256 = input_sha256,
  logical_label = if (is.null(file_rel)) basename(input_abs) else NULL,
  n_rows = nrow(df),
  n_cols = ncol(df),
  categorical_vars = cat_details,
  numeric_vars = df %>% select(where(is.numeric)) %>% names()
)

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}
out_path <- file.path(out_dir, "inspection_results.json")
writeLines(toJSON(output, auto_unbox = TRUE, pretty = TRUE), out_path)
message("[INFO] Inspection results saved: inspection_results.json")
if (!identical(inspection_status, "ready")) {
  message("[WARN] 入力構造の確認または整形が必要です。analysis_config.json を確定せず、Pass 0 の相談へ戻ってください。")
}
