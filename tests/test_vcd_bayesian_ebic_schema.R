# EBIC主計算 + 新スキーマ（core/model_selection/effects/...）の検証
# Run from repo root: Rscript tests/test_vcd_bayesian_ebic_schema.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_ebic_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

status <- system2("Rscript", c(
  analysis,
  "--output_dir", td,
  "--ebic_gamma", "0.5"
))
stopifnot(identical(as.integer(status), 0L))

jp <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
res <- jsonlite::fromJSON(jp[1L])

for (k in c("core", "model_selection", "effects", "thresholds", "warnings", "extensions")) {
  stopifnot(k %in% names(res))
}

stopifnot(identical(res$model_selection$method, "EBIC"))
stopifnot(is.character(res$model_selection$bf10))
stopifnot("bf10_bic" %in% names(res$model_selection))
stopifnot(is.numeric(res$thresholds$level1))
stopifnot(is.numeric(res$thresholds$level2))
stopifnot(is.numeric(res$thresholds$level3))
stopifnot(res$thresholds$level3 >= res$thresholds$level2)
stopifnot("Intensity_Level" %in% names(res$core$full_data))

message("OK: EBIC主計算 + 新スキーマ")
