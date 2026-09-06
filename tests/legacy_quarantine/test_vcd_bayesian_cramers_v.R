# tests/test_vcd_bayesian_cramers_v.R
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agents")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_cv_")
dir.create(td)

run_analysis <- function(out_dir, extra_args = character(0)) {
  status <- system2(
    "Rscript",
    c(analysis, "--output_dir", out_dir, extra_args)
  )
  stopifnot(identical(as.integer(status), 0L))

  json_path <- list.files(
    out_dir,
    pattern = "^evidence_results\\.json$",
    full.names = TRUE,
    recursive = TRUE
  )
  stopifnot(length(json_path) == 1L)
  jsonlite::fromJSON(json_path[1L])
}

res_with_response <- run_analysis(
  file.path(td, "with_response"),
  c("--response_var", "Sex")
)
stopifnot(identical(res_with_response$response_var, "Sex"))
stopifnot(identical(res_with_response$effect_status, "computed"))
stopifnot(identical(
  res_with_response$effects$effect_scope,
  "predictor_profile_by_response"
))
stopifnot(is.numeric(res_with_response$cramers_v))
stopifnot(
  res_with_response$cramers_v >= 0 &&
    res_with_response$cramers_v <= 1
)
stopifnot(is.numeric(res_with_response$cramers_v_ci_low))
stopifnot(is.numeric(res_with_response$cramers_v_ci_high))

res_without_response <- run_analysis(file.path(td, "without_response"))
stopifnot(identical(res_without_response$effect_status, "not_applicable"))
stopifnot(identical(res_without_response$effects$effect_scope, "none"))

for (res in list(res_with_response, res_without_response)) {
  stopifnot("large_sample_mode" %in% names(res))
  stopifnot(is.logical(res$large_sample_mode))
  stopifnot("top_k" %in% names(res))
  stopifnot("top_k_data" %in% names(res))
  stopifnot("threshold_k" %in% names(res))
}

unlink(td, recursive = TRUE)
message("OK: response_var controls 3-way Cramér's V applicability")
