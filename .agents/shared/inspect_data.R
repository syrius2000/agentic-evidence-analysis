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

df <- read_csv(input_file, show_col_types = FALSE)

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
  file = normalizePath(input_file),
  input_sha256 = strsplit(system2("shasum", c("-a", "256", shQuote(input_file)), stdout = TRUE)[1], " ")[[1]][1],
  missing_counts = lapply(df, function(x) sum(is.na(x))),
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
message("[INFO] Inspection results saved to ", normalizePath(out_path, mustWork = FALSE))
