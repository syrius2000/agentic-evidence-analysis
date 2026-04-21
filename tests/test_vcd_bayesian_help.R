# tests/test_vcd_bayesian_help.R
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

# --help テスト
out_help <- system2("Rscript", c(analysis, "--help"), stdout = TRUE, stderr = TRUE)
help_text <- paste(out_help, collapse = "\n")
stopifnot(grepl("--top_k", help_text, fixed = TRUE))
stopifnot(grepl("--threshold_k", help_text, fixed = TRUE))
stopifnot(grepl("--large_n_threshold", help_text, fixed = TRUE))
stopifnot(grepl("--help_stats", help_text, fixed = TRUE))

# --help_stats テスト
out_stats <- system2("Rscript", c(analysis, "--help_stats"), stdout = TRUE, stderr = TRUE)
stats_text <- paste(out_stats, collapse = "\n")
stopifnot(grepl("Evidence Score", stats_text, fixed = TRUE))
stopifnot(grepl("Cram", stats_text, fixed = TRUE))
stopifnot(grepl("BF", stats_text, fixed = TRUE))

message("OK: help and help_stats output")