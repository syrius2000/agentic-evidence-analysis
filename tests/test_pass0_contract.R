#!/usr/bin/env Rscript

# Pass 0検分、由来ハッシュ、および公開Pass 1ゲートの契約試験。
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
inspect_script <- file.path(root, ".agents", "shared", "inspect_data.R")
contract_script <- file.path(root, ".agents", "shared", "pass0_contract.R")
finalize_script <- file.path(root, ".agents", "shared", "finalize_pass0_config.R")
bayes_script <- file.path(root, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "analysis.R")
categorical_script <- file.path(root, ".agents", "skills", "vcd-categorical-analysis", "templates", "analysis.R")
questionnaire_script <- file.path(root, ".agents", "skills", "questionnaire-batch-analysis", "templates", "batch_runner.R")

stopifnot(file.exists(inspect_script), file.exists(contract_script), file.exists(finalize_script), file.exists(bayes_script), file.exists(categorical_script), file.exists(questionnaire_script))
source(file.path(root, ".agents", "shared", "run_scope.R"))
source(contract_script)

td <- tempfile("pass0_contract_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

input_path <- file.path(td, "table.csv")
utils::write.csv(
  data.frame(A = c("a", "a", "b", "b"), B = c("x", "y", "x", "y"), Freq = c(10, 20, 30, 40)),
  input_path,
  row.names = FALSE
)
inspection_dir <- file.path(td, "pass0")
status <- system2("Rscript", c("--vanilla", inspect_script, input_path, "--out-dir", inspection_dir))
stopifnot(identical(as.integer(status), 0L))
inspection_path <- file.path(inspection_dir, "inspection_results.json")
inspection <- jsonlite::read_json(inspection_path, simplifyVector = FALSE)
stopifnot(identical(inspection$inspection_status, "ready"))

config_path <- file.path(td, "analysis_config.json")
config_status <- system2(
  "Rscript",
  c(
    "--vanilla", finalize_script,
    "--inspection-results", inspection_path,
    "--scope", file.path(root, "docs", "Artifacts", "implementation_plan_008_0909.md"),
    "--config-out", config_path,
    "--skill", "vcd-bayesian-evidence-analysis",
    "--input", input_path,
    "--vars", "A,B",
    "--freq", "Freq",
    "--output-dir", file.path(td, "out"),
    "--run-id", "pass0_contract"
  )
)
stopifnot(identical(as.integer(config_status), 0L), file.exists(config_path))
config <- jsonlite::read_json(config_path, simplifyVector = FALSE)

validated <- validate_pass0_provenance(config, config_path, "vcd-bayesian-evidence-analysis", root)
stopifnot(identical(validated$input_path, normalizePath(input_path, winslash = "/")))

valid_status <- system2(
  "Rscript",
  c("--vanilla", bayes_script, "--config", config_path),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(identical(as.integer(valid_status), 0L))
stopifnot(length(list.files(file.path(td, "out"), pattern = "evidence_results\\.json$", recursive = TRUE)) == 1L)

bad_skill <- tryCatch({
  validate_pass0_provenance(config, config_path, "vcd-categorical-analysis", root)
  FALSE
}, error = function(e) TRUE)
stopifnot(bad_skill)

utils::write.csv(
  data.frame(A = c("a", "a", "b", "b"), B = c("x", "y", "x", "y"), Freq = c(11, 20, 30, 40)),
  input_path,
  row.names = FALSE
)
tampered_input <- tryCatch({
  validate_pass0_provenance(config, config_path, "vcd-bayesian-evidence-analysis", root)
  FALSE
}, error = function(e) TRUE)
stopifnot(tampered_input)

raw_out <- file.path(td, "raw_cli_out")
raw_status <- system2(
  "Rscript",
  c("--vanilla", bayes_script, "--input", input_path, "--vars", "A,B", "--freq", "Freq", "--output_dir", raw_out),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(as.integer(raw_status) != 0L, !dir.exists(raw_out))

categorical_raw_out <- file.path(td, "categorical_raw_cli_out")
categorical_raw_status <- system2(
  "Rscript",
  c("--vanilla", categorical_script, "--render", "--data", input_path, "--vars", "A,B", "--freq", "Freq", "--out", categorical_raw_out),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(as.integer(categorical_raw_status) != 0L, !dir.exists(categorical_raw_out))

questionnaire_raw_out <- file.path(td, "questionnaire_raw_cli_out")
questionnaire_raw_status <- system2(
  "Rscript",
  c(
    "--vanilla", questionnaire_script,
    "--data", file.path(root, "tests", "sample_survey.csv"),
    "--question-config", file.path(root, "tests", "question_config_test.csv"),
    "--out", questionnaire_raw_out
  ),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(as.integer(questionnaire_raw_status) != 0L, !dir.exists(questionnaire_raw_out))

otc_dir <- file.path(td, "otc")
otc_status <- system2(
  "Rscript",
  c("--vanilla", inspect_script, file.path(root, "examples", "OTC_Q02a.csv"), "--out-dir", otc_dir)
)
stopifnot(identical(as.integer(otc_status), 0L))
otc_inspection <- jsonlite::read_json(file.path(otc_dir, "inspection_results.json"), simplifyVector = FALSE)
stopifnot(identical(otc_inspection$inspection_status, "needs_input_preparation"))

message("OK: Pass 0 provenance, input tamper rejection, raw CLI rejection, and multi-row header diagnosis")
