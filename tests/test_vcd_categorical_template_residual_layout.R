#!/usr/bin/env Rscript
# dashboard.Rmd の residual plot + table レイアウトを検証
# Run: Rscript tests/test_vcd_categorical_template_residual_layout.R

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}

paths <- c(
  file.path(repo, ".cursor/skills/vcd-categorical-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agent/skills/vcd-categorical-analysis/templates/dashboard.Rmd")
)

for (p in paths) {
  stopifnot(file.exists(p))
  lines <- readLines(p, warn = FALSE)

  chunk_names <- c(
    "setup",
    "header-banner",
    "stats-cards",
    "ai-summary",
    "residual-plot",
    "dt-table",
    "mosaic-plot"
  )
  chunk_pos <- vapply(
    chunk_names,
    function(name) {
      idx <- grep(sprintf("^```\\{r %s([,}])", name), lines)
      if (length(idx) != 1L) stop("Chunk not found exactly once: ", name, " in ", p)
      idx
    },
    integer(1)
  )

  if (!all(diff(chunk_pos) > 0)) {
    stop("Residual layout chunk order is invalid in: ", p)
  }

  if (!any(grepl("残差プロット|Residual plot", lines))) {
    stop("Residual plot heading is missing in: ", p)
  }

  if (!any(grepl("order\\s*=.*abs_pearson_res", lines))) {
    stop("DT table sort by abs_pearson_res is missing in: ", p)
  }

  if (!any(grepl("theme_minimal\\(.*base_family", lines))) {
    stop("theme_minimal base_family is missing in: ", p)
  }
}

message("OK: residual plot + table layout present in both vcd dashboard templates.")
