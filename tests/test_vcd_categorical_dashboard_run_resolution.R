#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
source(file.path(root, ".agents", "shared", "run_scope.R"))

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
    "vcd-categorical-analysis"
  )
  stopifnot(identical(
    normalizePath(resolved$run_dir, mustWork = TRUE),
    normalizePath(expected, mustWork = TRUE)
  ))
}

analysis_root <- file.path(td, "analysis_output")
run_analysis <- function() {
  output <- suppressWarnings(system2(
    "Rscript",
    c(
      "--vanilla",
      analysis,
      "--render",
      "--out",
      analysis_root,
      "--run-id",
      "dashboard_case"
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(output, collapse = "\n"))
  }
}

run_analysis()
Sys.sleep(0.1)
run_analysis()
stopifnot(dir.exists(file.path(analysis_root, "run_dashboard_case")))
stopifnot(dir.exists(file.path(analysis_root, "run_dashboard_case_2")))

dashboard_html <- rmarkdown::render(
  dashboard_rmd,
  output_file = "categorical_dashboard.html",
  output_dir = td,
  params = list(output_dir = analysis_root),
  knit_root_dir = root,
  envir = new.env(parent = globalenv()),
  quiet = TRUE
)
stopifnot(file.exists(dashboard_html))
html <- paste(readLines(dashboard_html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
stopifnot(grepl("dashboard_case_2", html, fixed = TRUE))

message("OK: categorical Step 3 resolves JST, named, and collision-suffixed run directories")
