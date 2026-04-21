# tests/test_vcd_cat_pass1.R
root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(root, ".agent/skills/vcd-categorical-analysis/templates/analysis.R")
td <- tempfile("vcd_cat_")
dir.create(td)

status <- system2("Rscript", c(analysis, "--out", td))
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
