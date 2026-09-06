#!/usr/bin/env Rscript
# =============================================================================
# test_vcd_bayesian_stability_leverage.R
# Test: 4-Axis Stability quarantine rules against a fixture crossing h >= 0.80
# Validates:
#   1. Zero cells (O == 0) -> QUARANTINED
#   2. Sparse expected counts (E < 5.0) -> QUARANTINED
#   3. High leverage (h >= 0.80) -> QUARANTINED (even when O > 0 and E >= 5.0)
#   4. Regular cells (O > 0 & E >= 5.0 & h < 0.80) -> REGULAR
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

script_dir <- getwd()
pass1_path <- file.path(script_dir, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "pass1_compute.R")
if (!file.exists(pass1_path)) {
  stop("pass1_compute.R not found at: ", pass1_path)
}
source(pass1_path)

fixture_path <- file.path(script_dir, "tests", "fixtures", "statistical_foundations", "stability_leverage_fixture_3way.csv")
if (!file.exists(fixture_path)) {
  stop("Fixture not found at: ", fixture_path)
}

df <- read.csv(fixture_path, stringsAsFactors = FALSE)
vars <- c("A", "B", "C")
freq_col <- "Freq"

# Fit models
models_res <- fit_all_poisson_models(df, vars, freq_col)
m1 <- models_res$models[["M1"]]
if (is.null(m1)) {
  stop("Failed to fit M1 base model.")
}

# Compute 4-axis cell diagnostics
diag_res <- compute_4axis_cell_diagnostics(df, vars, freq_col, models_res, base_model_id = "M1")
ct <- diag_res$cell_table

cat("--- Stability Diagnostics Cell Table Inspection ---\n")
print(ct %>% select(A, B, C, Observed, Expected, leverage, stability_status))

# Assertion 1: High leverage cells crossing h >= 0.80 exist
high_lev_cells <- ct %>% filter(leverage >= 0.80)
if (nrow(high_lev_cells) == 0) {
  stop("[FAIL] No cells with leverage >= 0.80 found in fixture.")
}
cat(sprintf("[PASS] Found %d cells with leverage >= 0.80 (max h = %.4f)\n", nrow(high_lev_cells), max(high_lev_cells$leverage)))

# Assertion 2: Pure high leverage cells (h >= 0.80 & Observed > 0 & Expected >= 5.0) are QUARANTINED
pure_high_lev <- ct %>% filter(leverage >= 0.80 & Observed > 0 & Expected >= 5.0)
if (nrow(pure_high_lev) == 0) {
  stop("[FAIL] No pure high leverage cells (without zero or sparse) found.")
}
if (!all(pure_high_lev$stability_status == "QUARANTINED")) {
  stop("[FAIL] Pure high leverage cells were not marked QUARANTINED!")
}
cat(sprintf("[PASS] %d pure high leverage cells (E >= 5, O > 0, h >= 0.80) are all QUARANTINED.\n", nrow(pure_high_lev)))

# Assertion 3: Zero cells (Observed == 0) are QUARANTINED
zero_cells <- ct %>% filter(Observed == 0)
if (nrow(zero_cells) == 0) {
  stop("[FAIL] No zero cells found in fixture.")
}
if (!all(zero_cells$stability_status == "QUARANTINED")) {
  stop("[FAIL] Zero cells were not marked QUARANTINED!")
}
cat(sprintf("[PASS] %d zero cells (Observed == 0) are all QUARANTINED.\n", nrow(zero_cells)))

# Assertion 4: Sparse expected cells (Expected < 5.0 & Observed > 0) are QUARANTINED
sparse_cells <- ct %>% filter(Expected < 5.0 & Observed > 0)
if (nrow(sparse_cells) == 0) {
  stop("[FAIL] No sparse expected cells found in fixture.")
}
if (!all(sparse_cells$stability_status == "QUARANTINED")) {
  stop("[FAIL] Sparse expected cells were not marked QUARANTINED!")
}
cat(sprintf("[PASS] %d sparse cells (Expected < 5.0) are all QUARANTINED.\n", nrow(sparse_cells)))

# Assertion 5: Regular cells (Observed > 0 & Expected >= 5.0 & leverage < 0.80) are REGULAR
reg_cells <- ct %>% filter(Observed > 0 & Expected >= 5.0 & leverage < 0.80)
if (nrow(reg_cells) == 0) {
  stop("[FAIL] No regular cells found in fixture.")
}
if (!all(reg_cells$stability_status == "REGULAR")) {
  stop("[FAIL] Regular cells were incorrectly marked QUARANTINED!")
}
cat(sprintf("[PASS] %d regular cells (O > 0, E >= 5.0, h < 0.80) are all REGULAR.\n", nrow(reg_cells)))

# Assertion 6: Exact boolean definition matches stability_status across all cells
computed_status <- ifelse(ct$Observed == 0 | ct$Expected < 5.0 | ct$leverage >= 0.80, "QUARANTINED", "REGULAR")
if (!all(computed_status == ct$stability_status)) {
  stop("[FAIL] Exact 3-condition rule does not match ct$stability_status!")
}
cat("[PASS] Exact 3-condition rule (O == 0 | E < 5.0 | h >= 0.80) verified across all cells.\n")

cat("\n--- ALL STABILITY & LEVERAGE TESTS PASSED ---\n")
quit(status = 0)
