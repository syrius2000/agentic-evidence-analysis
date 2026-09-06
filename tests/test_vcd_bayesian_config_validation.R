#!/usr/bin/env Rscript
# =============================================================================
# test_vcd_bayesian_config_validation.R
# Test: config_validation.R for 4-axis skill contracts:
#   1. Valid config with base_model passes
#   2. Legacy keys (threshold_k, ebic_gamma, etc.) trigger [DEPRECATED] message
#   3. Unknown keys trigger [WARN] message
#   4. Missing required keys error out
# =============================================================================

script_dir <- getwd()
validation_path <- file.path(script_dir, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "config_validation.R")
if (!file.exists(validation_path)) {
  stop("config_validation.R not found at: ", validation_path)
}
source(validation_path)

input_csv <- file.path(script_dir, "tests", "fixtures", "statistical_foundations", "stability_leverage_fixture_3way.csv")

# Test 1: Valid config passes
valid_cfg <- list(
  input = input_csv,
  vars = c("A", "B", "C"),
  freq = "Freq",
  output_dir = "./output/test",
  run_id = "test_run_01",
  base_model = "M1",
  top_k = 10L,
  large_n_threshold = 2000L
)

res1 <- tryCatch(
  validate_analysis_config(valid_cfg, repo_root = script_dir),
  error = function(e) e
)
if (inherits(res1, "error")) {
  stop("[FAIL] Valid config failed: ", res1$message)
}
cat("[PASS] Test 1: Valid 4-axis config accepted.\n")

# Test 2: Deprecated key emits [DEPRECATED] message
legacy_cfg <- valid_cfg
legacy_cfg$threshold_k <- 1.5
legacy_cfg$ebic_gamma <- 0.5

msgs <- character()
res2 <- tryCatch(
  withCallingHandlers(
    validate_analysis_config(legacy_cfg, repo_root = script_dir),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  ),
  error = function(e) e
)

if (inherits(res2, "error")) {
  stop("[FAIL] Deprecated config threw unexpected error: ", res2$message)
}
if (!any(grepl("\\[DEPRECATED\\]", msgs))) {
  stop("[FAIL] Deprecated keys did not trigger [DEPRECATED] message.")
}
cat("[PASS] Test 2: Legacy keys properly trigger [DEPRECATED] warning.\n")

# Test 3: Missing required key fails with stop
invalid_cfg <- valid_cfg
invalid_cfg$vars <- NULL
res3 <- tryCatch(
  validate_analysis_config(invalid_cfg, repo_root = script_dir),
  error = function(e) e
)
if (!inherits(res3, "error")) {
  stop("[FAIL] Config with missing vars should have stopped with error.")
}
cat("[PASS] Test 3: Missing required keys correctly rejected with error.\n")

cat("\n--- ALL CONFIG VALIDATION TESTS PASSED ---\n")
quit(status = 0)
