#!/usr/bin/env Rscript

# Pass 0 の合意済みスコープを、検証可能な analysis_config.json として確定する。
suppressPackageStartupMessages(library(jsonlite))

script_arg <- grep("^--file=", commandArgs(), value = TRUE)[1L]
script_dir <- dirname(sub("^--file=", "", script_arg))
source(file.path(script_dir, "run_scope.R"))
source(file.path(script_dir, "pass0_contract.R"))

args <- commandArgs(trailingOnly = TRUE)
read_opt <- function(name, required = FALSE, default = NULL) {
  index <- match(name, args)
  value <- if (!is.na(index) && index < length(args)) args[[index + 1L]] else default
  if (required && (is.null(value) || !nzchar(trimws(value)))) {
    stop("[ERROR] ", name, " が必要です。", call. = FALSE)
  }
  value
}

repo_root <- run_scope_detect_repo_root(getwd())
inspection_path <- read_opt("--inspection-results", required = TRUE)
scope_path <- read_opt("--scope", required = TRUE)
config_out <- read_opt("--config-out", required = TRUE)
skill <- read_opt("--skill", required = TRUE)
input_path <- read_opt("--input", required = TRUE)
out_root <- read_opt("--output-dir", required = TRUE)
run_id <- read_opt("--run-id", required = TRUE)
vars_raw <- read_opt("--vars")
freq <- read_opt("--freq")
input_mode <- read_opt("--input-mode", default = "aggregated")
practical_delta <- read_opt("--practical-delta")
response_var <- read_opt("--response-var")
question_config <- read_opt("--question-config")

supported_skills <- c("vcd-bayesian-evidence-analysis", "vcd-categorical-analysis", "questionnaire-batch-analysis")
if (!(skill %in% supported_skills)) {
  stop("[ERROR] --skill は次のいずれかである必要があります: ", paste(supported_skills, collapse = ", "), call. = FALSE)
}
if (!file.exists(scope_path)) {
  stop("[ERROR] Pass 0 スコープ文書が見つかりません: ", scope_path, call. = FALSE)
}
if (skill != "questionnaire-batch-analysis" && (is.null(vars_raw) || is.null(freq))) {
  stop("[ERROR] Bayesian/Categorical の設定には --vars と --freq が必要です。", call. = FALSE)
}
if (skill == "questionnaire-batch-analysis" && (is.null(question_config) || !file.exists(question_config))) {
  stop("[ERROR] Questionnaire の設定には存在する --question-config が必要です。", call. = FALSE)
}

repo_relative <- function(path) {
  absolute <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  if (startsWith(absolute, paste0(root, "/"))) substring(absolute, nchar(root) + 2L) else absolute
}

repo_relative_maybe <- function(path) {
  absolute <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  if (startsWith(absolute, paste0(root, "/"))) substring(absolute, nchar(root) + 2L) else absolute
}

vars_parsed <- if (!is.null(vars_raw)) trimws(strsplit(vars_raw, ",", fixed = TRUE)[[1L]]) else NULL
practical_delta_val <- if (!is.null(practical_delta)) as.numeric(practical_delta) else NULL

canonical_config_sha <- if (skill == "vcd-categorical-analysis") {
  compute_canonical_config_sha256(
    vars = vars_parsed,
    freq = freq,
    input_mode = input_mode,
    prior_alpha = 1.0,
    practical_delta = practical_delta_val
  )
} else NULL

if (!is.null(canonical_config_sha) && file.exists(inspection_path)) {
  insp_obj <- jsonlite::read_json(inspection_path, simplifyVector = FALSE)
  insp_obj$approved_config <- list(canonical_config_sha256 = canonical_config_sha)
  jsonlite::write_json(insp_obj, inspection_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

config <- list(
  input = repo_relative(input_path),
  output_dir = repo_relative_maybe(out_root),
  run_id = run_id,
  pass0_provenance = build_pass0_provenance(
    inspection_path,
    input_path,
    skill,
    scope_path = scope_path,
    canonical_config_sha256 = canonical_config_sha,
    repo_root = repo_root
  )
)

if (!is.null(vars_parsed)) config$vars <- vars_parsed
if (!is.null(freq)) config$freq <- freq
if (skill == "vcd-categorical-analysis") config$input_mode <- input_mode
if (!is.null(practical_delta_val)) config$practical_delta <- practical_delta_val
if (!is.null(response_var)) config$response_var <- response_var
if (!is.null(question_config)) config$question_config <- repo_relative(question_config)

out_parent <- dirname(config_out)
if (!dir.exists(out_parent)) dir.create(out_parent, recursive = TRUE, showWarnings = FALSE)
if (file.exists(config_out)) stop("[ERROR] 既存の analysis_config.json を上書きしません: ", config_out, call. = FALSE)
write_json(config, config_out, auto_unbox = TRUE, pretty = TRUE, null = "null")
message("[DONE] Pass 0 設定を確定しました: ", config_out)
