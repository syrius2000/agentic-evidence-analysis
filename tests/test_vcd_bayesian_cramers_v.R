# tests/test_vcd_bayesian_cramers_v.R
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_cv_")
dir.create(td)
status <- system2("Rscript", c(analysis, "--output_dir", td))
stopifnot(identical(as.integer(status), 0L))

json_path <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(json_path) == 1L)
json_path <- json_path[1L]

res <- jsonlite::fromJSON(json_path)

# Cramér's V が存在し、0〜1の範囲
stopifnot("cramers_v" %in% names(res))
stopifnot(is.numeric(res$cramers_v))
stopifnot(res$cramers_v >= 0 && res$cramers_v <= 1)

# CI が存在
stopifnot("cramers_v_ci_low" %in% names(res))
stopifnot("cramers_v_ci_high" %in% names(res))

# 大規模モードフラグ
stopifnot("large_sample_mode" %in% names(res))
stopifnot(is.logical(res$large_sample_mode))

# Top-K フィールド
stopifnot("top_k" %in% names(res))
stopifnot("top_k_data" %in% names(res))

# threshold_k フィールド
stopifnot("threshold_k" %in% names(res))

unlink(td, recursive = TRUE)
message("OK: cramers_v, large_sample_mode, top_k in JSON")