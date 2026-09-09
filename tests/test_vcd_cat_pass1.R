# tests/test_vcd_cat_pass1.R
root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(root, ".agents/skills/vcd-categorical-analysis/templates/analysis.R")
inspect <- file.path(root, ".agents/shared/inspect_data.R")
finalize_pass0 <- file.path(root, ".agents/shared/finalize_pass0_config.R")
td <- tempfile("vcd_cat_")
dir.create(td)

input <- file.path(root, "examples", "titanic.csv")
inspection_dir <- file.path(td, "pass0")
config <- file.path(td, "analysis_config.json")
stopifnot(system2("Rscript", c(inspect, input, "--out-dir", inspection_dir)) == 0L)
stopifnot(system2("Rscript", c(
  finalize_pass0,
  "--inspection-results", file.path(inspection_dir, "inspection_results.json"),
  "--scope", file.path(root, "docs", "Artifacts", "implementation_plan_008_0909.md"),
  "--config-out", config,
  "--skill", "vcd-categorical-analysis",
  "--input", input,
  "--vars", "Class,Sex",
  "--freq", "Freq",
  "--output-dir", td,
  "--run-id", "vcd_cat_pass1"
)) == 0L)

status <- system2("Rscript", c(analysis, "--render", "--config", config))
stopifnot(identical(as.integer(status), 0L))

json_path <- list.files(td, pattern = "^categorical_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(json_path) == 1L)
json_path <- json_path[1L]
stopifnot(file.exists(json_path))

res <- jsonlite::fromJSON(json_path)
stopifnot("n_total" %in% names(res))
stopifnot("cramers_v" %in% names(res))

unlink(td, recursive = TRUE)
message("OK: vcd_categorical pass 1 generates JSON")
