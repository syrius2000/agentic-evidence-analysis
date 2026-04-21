# --run-id isolates output under runs/<slug>/
# Run from repo root: Rscript tests/test_vcd_bayesian_run_id.R

root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_runid_")
dir.create(td)
base_out <- file.path(td, "bay_out")
dir.create(base_out)
slug <- "unit_test_slug_xyz"

out <- system2(
  "Rscript",
  c(analysis, "--output_dir", base_out, "--run-id", slug),
  stdout = TRUE,
  stderr = TRUE
)
ex <- attr(out, "status")
if (!is.null(ex) && !identical(ex, 0L)) {
  stop("analysis.R failed (exit ", ex, "): ", paste(out, collapse = "\n"))
}

# 実装は run_scope.R の run_output_dir_from_root: <out_root>/run_<substr(run_id,1,16)>/
run_sub <- paste0("run_", substr(slug, 1L, 16L))
json_path <- file.path(base_out, run_sub, "evidence_results.json")
stopifnot(file.exists(json_path))
res <- jsonlite::fromJSON(json_path)
stopifnot(identical(as.character(res$run_id), slug))

message("OK: --run-id output isolation and JSON run_id")
