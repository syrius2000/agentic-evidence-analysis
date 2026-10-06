#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
source(file.path(root, ".agents", "shared", "run_scope.R"))
source(file.path(root, ".agents", "shared", "pass0_contract.R"))

analysis <- file.path(
  root,
  ".agents",
  "skills",
  "vcd-categorical-analysis",
  "templates",
  "analysis.R"
)
dashboard_rmd <- file.path(
  root,
  ".agents",
  "skills",
  "vcd-categorical-analysis",
  "templates",
  "dashboard.Rmd"
)
stopifnot(file.exists(analysis), file.exists(dashboard_rmd))

td <- tempfile("vcd_categorical_dashboard_resolution_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

write_resolver_fixture <- function(parent, run_name, run_id) {
  run_dir <- file.path(parent, run_name)
  dir.create(run_dir, recursive = TRUE)
  jsonlite::write_json(
    list(interface_version = "1.0"),
    file.path(run_dir, "categorical_results.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    list(
      interface_version = "1.0",
      skill = "vcd-categorical-analysis",
      run_id = run_id,
      run_output_dir = normalizePath(run_dir, mustWork = TRUE)
    ),
    file.path(run_dir, "run_meta.json"),
    auto_unbox = TRUE
  )
  run_dir
}

resolver_cases <- list(
  c("run_20260724_123456", "20260724_123456"),
  c("run_named_project", "named_project"),
  c("run_named_project_2", "named_project_2")
)
for (case in resolver_cases) {
  parent <- file.path(td, paste0("resolver_", case[[2L]]))
  dir.create(parent)
  expected <- write_resolver_fixture(parent, case[[1L]], case[[2L]])
  resolved <- resolve_pass3_run_dir(
    parent,
    "categorical_results.json",
    "vcd-categorical-analysis",
    discover_single_run = TRUE,
    allow_legacy = TRUE
  )
  stopifnot(identical(
    normalizePath(resolved$run_dir, mustWork = TRUE),
    normalizePath(expected, mustWork = TRUE)
  ))
}

analysis_root <- file.path(root, "evidence_runs/vcd_categorical", basename(td), "analysis_output")
on.exit(unlink(file.path(root, "evidence_runs/vcd_categorical", basename(td)), recursive = TRUE), add = TRUE)
input_csv <- file.path(td, "dashboard_input.csv")
utils::write.csv(data.frame(
  Treatment = c("Drug", "Drug", "Placebo", "Placebo"),
  Response = c("Yes", "No", "Yes", "No"),
  Freq = c(60L, 20L, 25L, 55L)
), input_csv, row.names = FALSE)
input_sha <- pass0_sha256_file(input_csv)
config_sha <- compute_canonical_config_sha256(
  vars = c("Treatment", "Response"), freq = "Freq", input_mode = "aggregated",
  prior_alpha = 0.5, practical_delta = NULL
)
inspection_file <- file.path(td, "inspection.json")
jsonlite::write_json(list(
  contract_version = "1.0", inspection_status = "ready", input_sha256 = input_sha,
  candidate_variables = list("Treatment", "Response"), detected_freq = "Freq",
  approved_config = list(canonical_config_sha256 = config_sha)
), inspection_file, auto_unbox = TRUE, pretty = TRUE)
inspection_sha <- pass0_sha256_file(inspection_file)
config_file <- file.path(td, "analysis_config.json")
jsonlite::write_json(list(
  input = input_csv, vars = c("Treatment", "Response"), freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0", inspection_results = inspection_file,
    inspection_results_sha256 = inspection_sha, input_sha256 = input_sha,
    canonical_config_sha256 = config_sha, finalized_at_jst = "2026-10-06 12:00",
    target_skill = "vcd-categorical-analysis"
  )
), config_file, auto_unbox = TRUE, pretty = TRUE)

output <- suppressWarnings(system2(
  "Rscript", c("--vanilla", analysis, "--config", config_file,
               "--out", analysis_root, "--label", "dashboard_case"),
  stdout = TRUE, stderr = TRUE
))
status <- attr(output, "status")
if (!is.null(status) && !identical(as.integer(status), 0L)) stop(paste(output, collapse = "\n"))

dashboard_html <- rmarkdown::render(
  dashboard_rmd,
  output_file = "categorical_dashboard.html",
  output_dir = td,
  params = list(output_dir = analysis_root, discover_single_run = TRUE),
  knit_root_dir = root,
  envir = new.env(parent = globalenv()),
  quiet = TRUE
)
stopifnot(file.exists(dashboard_html))
html <- paste(readLines(dashboard_html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

message("OK: categorical Step 3 resolves JST, named, and collision-suffixed run directories")
