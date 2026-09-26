#!/usr/bin/env Rscript
# tests/test_three_way_analysis_config_schema.R
# 3次元解析設定スキーマ (analysis_config.schema.json) および固定事前契約 (T01, T02) の検証

ca   <- commandArgs(trailingOnly = FALSE)
fa   <- ca[grep("^--file=", ca)]
root <- if (length(fa) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", fa[1]))))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, ".agents")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), winslash = "/", mustWork = TRUE)
}

# 1. T01 — JSON Schema syntax gate
schema_path <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json")
if (!file.exists(schema_path)) {
  stop("[FAIL] schema file not found: ", schema_path)
}

schema_raw <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
stopifnot(is.list(schema_raw))
stopifnot(identical(schema_raw$type, "object"))
stopifnot(!is.null(schema_raw$properties$dirichlet_prior))
stopifnot(!is.null(schema_raw$properties$arm_min_confidence))
stopifnot(identical(schema_raw$properties$dirichlet_prior$properties$primary_alpha$const, 0.5))
stopifnot(identical(schema_raw$properties$dirichlet_prior$properties$sensitivity_alpha$const, 1.0))
cat("[PASS] T01: analysis_config.schema.json parsed successfully with fixed prior constants.\n")

# 2. T02 — Prior fixed contract validation
source(file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/config_validation.R"))

base_cfg <- list(
  input = "examples/ucb_admissions.csv",
  vars = c("Dept", "Gender", "Admit"),
  freq = "Freq",
  response_var = "Admit",
  output_dir = "output/test_schema",
  run_id = "test_run",
  pass0_provenance = list(
    inspection_file = "dummy_inspection.json",
    input_sha256 = "dummy_sha"
  )
)

# Helper for catching error message
get_val_err <- function(cfg) {
  tryCatch({
    validate_analysis_config(cfg, repo_root = root)
    ""
  }, error = function(e) {
    conditionMessage(e)
  })
}

# Case 1: omitted / omitted -> PASS
cfg1 <- base_cfg
err_msg1 <- get_val_err(cfg1)
stopifnot(!grepl("dirichlet_prior", err_msg1))
cat("[PASS] T02 Case 1: omitted dirichlet_prior accepted.\n")

# Case 2: 0.5 / 1.0 -> PASS
cfg2 <- base_cfg
cfg2$dirichlet_prior <- list(primary_alpha = 0.5, sensitivity_alpha = 1.0)
err_msg2 <- get_val_err(cfg2)
stopifnot(!grepl("dirichlet_prior", err_msg2))
cat("[PASS] T02 Case 2: primary=0.5, sensitivity=1.0 accepted.\n")

# Case 3: 0.25 / 1.0 -> REJECT
cfg3 <- base_cfg
cfg3$dirichlet_prior <- list(primary_alpha = 0.25, sensitivity_alpha = 1.0)
err_msg3 <- get_val_err(cfg3)
stopifnot(grepl("primary_alpha.*0.5", err_msg3))
cat("[PASS] T02 Case 3: primary=0.25 rejected.\n")

# Case 4: 0.5 / 2.0 -> REJECT
cfg4 <- base_cfg
cfg4$dirichlet_prior <- list(primary_alpha = 0.5, sensitivity_alpha = 2.0)
err_msg4 <- get_val_err(cfg4)
stopifnot(grepl("sensitivity_alpha.*1.0", err_msg4))
cat("[PASS] T02 Case 4: sensitivity=2.0 rejected.\n")

# Case 5: 1.0 / 0.5 -> REJECT
cfg5 <- base_cfg
cfg5$dirichlet_prior <- list(primary_alpha = 1.0, sensitivity_alpha = 0.5)
err_msg5 <- get_val_err(cfg5)
stopifnot(grepl("primary_alpha.*0.5", err_msg5) && grepl("sensitivity_alpha.*1.0", err_msg5))
cat("[PASS] T02 Case 5: primary=1.0, sensitivity=0.5 rejected.\n")

# Case 6: -0.5 / 1.0 -> REJECT
cfg6 <- base_cfg
cfg6$dirichlet_prior <- list(primary_alpha = -0.5, sensitivity_alpha = 1.0)
err_msg6 <- get_val_err(cfg6)
stopifnot(grepl("primary_alpha.*0.5", err_msg6))
cat("[PASS] T02 Case 6: primary=-0.5 rejected.\n")

cat("[ALL PASS] test_three_way_analysis_config_schema.R passed 100%.\n")
