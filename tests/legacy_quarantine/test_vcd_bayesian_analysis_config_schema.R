# analysis_config.json validation for vcd-bayesian-evidence-analysis
# Run from repo root: Rscript tests/test_vcd_bayesian_analysis_config_schema.R

root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
schema <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json")
stopifnot(file.exists(analysis))
stopifnot(file.exists(schema))

make_config <- function(dir, values) {
  path <- file.path(dir, paste0("analysis_config_", sample.int(999999L, 1L), ".json"))
  jsonlite::write_json(values, path, auto_unbox = TRUE, pretty = TRUE)
  path
}

run_analysis <- function(config_path) {
  suppressWarnings(
    system2(
      "Rscript",
      c("--vanilla", analysis, "--config", config_path),
      stdout = TRUE,
      stderr = TRUE
    )
  )
}

run_analysis_args <- function(args) {
  suppressWarnings(
    system2(
      "Rscript",
      c("--vanilla", analysis, args),
      stdout = TRUE,
      stderr = TRUE
    )
  )
}

expect_failure_mentions <- function(label, config_path, pattern) {
  out <- run_analysis(config_path)
  status <- attr(out, "status")
  if (is.null(status) || identical(as.integer(status), 0L)) {
    stop(label, " unexpectedly passed:\n", paste(out, collapse = "\n"))
  }
  text <- paste(out, collapse = "\n")
  if (!grepl(pattern, text, fixed = TRUE)) {
    stop(label, " did not mention '", pattern, "':\n", text)
  }
}

td <- tempfile("vcd_bay_config_schema_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

base_config <- list(
  input = "examples/titanic.csv",
  vars = c("Class", "Sex", "Age", "Survived"),
  freq = "Freq",
  response_var = "Survived",
  output_dir = file.path(td, "valid_out"),
  run_id = "schema_valid_v1",
  threshold_k = 1.25,
  top_k = 8L
)

valid_config <- make_config(td, base_config)
valid_out <- run_analysis(valid_config)
valid_status <- attr(valid_out, "status")
if (!is.null(valid_status) && !identical(as.integer(valid_status), 0L)) {
  stop("valid config failed:\n", paste(valid_out, collapse = "\n"))
}
json_path <- file.path(td, "valid_out", "run_schema_valid_v1", "evidence_results.json")
stopifnot(file.exists(json_path))
res <- jsonlite::fromJSON(json_path)
stopifnot(identical(res$core$dimensions, base_config$vars))
stopifnot(identical(as.character(res$run_id), base_config$run_id))
stopifnot(identical(as.character(res$effects$response_var), base_config$response_var))
stopifnot(identical(as.character(res$effects$effect_status), "computed"))
stopifnot(!is.na(as.numeric(res$effects$cramers_v)))
stopifnot(!is.na(as.numeric(res$cramers_v)))

missing_vars <- base_config
missing_vars$vars <- NULL
expect_failure_mentions("missing vars", make_config(td, missing_vars), "vars")

bad_var <- base_config
bad_var$output_dir <- file.path(td, "bad_var_out")
bad_var$vars <- c("Class", "MissingColumn")
expect_failure_mentions("bad vars column", make_config(td, bad_var), "MissingColumn")

bad_freq <- base_config
bad_freq$output_dir <- file.path(td, "bad_freq_out")
bad_freq$freq <- "MissingFreq"
expect_failure_mentions("bad freq column", make_config(td, bad_freq), "MissingFreq")

bad_response <- base_config
bad_response$output_dir <- file.path(td, "bad_response_out")
bad_response$response_var <- "MissingResponse"
expect_failure_mentions("bad response_var column", make_config(td, bad_response), "MissingResponse")

bad_numeric <- base_config
bad_numeric$output_dir <- file.path(td, "bad_numeric_out")
bad_numeric$threshold_k <- "not-a-number"
expect_failure_mentions("bad numeric threshold_k", make_config(td, bad_numeric), "threshold_k")

missing_config_path <- file.path(td, "missing_analysis_config.json")
expect_failure_mentions("missing config file", missing_config_path, "設定ファイルが見つかりません")

missing_config_value <- run_analysis_args("--config")
missing_config_status <- attr(missing_config_value, "status")
if (is.null(missing_config_status) || identical(as.integer(missing_config_status), 0L)) {
  stop("missing --config value unexpectedly passed:\n", paste(missing_config_value, collapse = "\n"))
}
if (!grepl("--config", paste(missing_config_value, collapse = "\n"), fixed = TRUE)) {
  stop("missing --config value did not mention --config:\n", paste(missing_config_value, collapse = "\n"))
}

relative_dir <- file.path(td, "relative_config")
dir.create(relative_dir)
relative_csv <- file.path(relative_dir, "local_titanic.csv")
invisible(file.copy(file.path(root, "examples/titanic.csv"), relative_csv))
relative_config <- base_config
relative_config$input <- "local_titanic.csv"
relative_config$output_dir <- file.path(td, "relative_out")
relative_config$run_id <- "relative_input_v1"
relative_config_path <- make_config(relative_dir, relative_config)
relative_out <- run_analysis(relative_config_path)
relative_status <- attr(relative_out, "status")
if (!is.null(relative_status) && !identical(as.integer(relative_status), 0L)) {
  stop("config-relative input failed:\n", paste(relative_out, collapse = "\n"))
}
relative_run_dir <- paste0("run_", substr(relative_config$run_id, 1L, 16L))
stopifnot(file.exists(file.path(td, "relative_out", relative_run_dir, "evidence_results.json")))

huge_integer <- base_config
huge_integer$output_dir <- file.path(td, "huge_integer_out")
huge_integer$top_k <- 1e20
expect_failure_mentions("huge integer top_k", make_config(td, huge_integer), "top_k")

message("OK: analysis_config.json schema validation")
