#!/usr/bin/env Rscript

source(".agents/shared/pass0_contract.R")

sha_a <- paste(rep("a", 64L), collapse = "")
sha_b <- paste(rep("b", 64L), collapse = "")

expect_error <- function(expr, pattern) {
  error <- tryCatch({
    force(expr)
    NULL
  }, error = identity)
  stopifnot(inherits(error, "error"))
  stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
}

# 共有 Pass 0 契約: 正式キー、旧キー、および同値の二重出力を受理する。
stopifnot(identical(pass0_inspection_input_sha256(list(input_sha256 = sha_a)), sha_a))
stopifnot(identical(pass0_inspection_input_sha256(list(file_sha256 = sha_a)), sha_a))
stopifnot(identical(pass0_inspection_input_sha256(list(
  input_sha256 = sha_a,
  file_sha256 = sha_a
)), sha_a))

# 不在、形式不正、二重キー矛盾は fail-closed とする。
expect_error(pass0_inspection_input_sha256(list()), "入力SHA-256がありません")
expect_error(pass0_inspection_input_sha256(list(input_sha256 = "bad")), "input_sha256形式が不正")
expect_error(pass0_inspection_input_sha256(list(file_sha256 = "BAD")), "file_sha256形式が不正")
expect_error(pass0_inspection_input_sha256(list(
  input_sha256 = sha_a,
  file_sha256 = sha_b
)), "SHA-256キーが矛盾")

# 実際のPass 0成果物が正本解析スクリプトのvalidate-onlyへ接続できることを確認する。
temp_root <- tempfile("three_way_sha_contract_")
dir.create(temp_root, recursive = TRUE)
on.exit(unlink(temp_root, recursive = TRUE), add = TRUE)
inspection_dir <- file.path(temp_root, "inspection")
input_path <- "examples/ucb_admissions.csv"
inspect_output <- suppressWarnings(system2(
  "Rscript",
  c("--vanilla", ".agents/shared/inspect_data.R", input_path, "--out-dir", inspection_dir),
  stdout = TRUE,
  stderr = TRUE
))
stopifnot(is.null(attr(inspect_output, "status")))
inspection_path <- file.path(inspection_dir, "inspection_results.json")
inspection <- jsonlite::read_json(inspection_path, simplifyVector = FALSE)
stopifnot(identical(inspection$inspection_contract_version, "2.0"))

config <- list(
  input = input_path,
  vars = c("Admit", "Gender", "Dept"),
  freq = "Freq",
  response_var = "Admit",
  output_dir = file.path(temp_root, "analysis"),
  run_id = "sha_contract",
  pass0_provenance = list(
    inspection_file = inspection_path,
    input_sha256 = inspection$input_sha256
  )
)
config_path <- file.path(temp_root, "analysis_config.json")
jsonlite::write_json(config, config_path, auto_unbox = TRUE, pretty = TRUE)
validate_output <- suppressWarnings(system2(
  "Rscript",
  c(
    "--vanilla",
    ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R",
    "--config",
    config_path,
    "--validate-only"
  ),
  stdout = TRUE,
  stderr = TRUE
))
stopifnot(is.null(attr(validate_output, "status")))
stopifnot(any(grepl("VALID", validate_output, fixed = TRUE)))

message("OK: inspection SHA-256 canonical and legacy contracts")
