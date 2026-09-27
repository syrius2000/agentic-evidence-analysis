# tests/test_math_documentation_contracts.R — Automated contract linting for math documentation
# Verifies Task R10 of independent QA review 001

test_pass <- 0L
test_fail <- 0L

assert_true <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("[PASS] %s\n", msg))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", msg))
    test_fail <<- test_fail + 1L
  }
}

cat("=== 1. Test comparative_evidence_math.md Contracts ===\n")
comp_math_path <- "docs/reference/comparative_evidence_math.md"
assert_true(file.exists(comp_math_path), "comparative_evidence_math.md exists")
comp_lines <- readLines(comp_math_path, encoding = "UTF-8", warn = FALSE)
comp_text <- paste(comp_lines, collapse = "\n")

# Check exact 12-column table header items
expected_12_headers <- c(
  "テーマ",
  "比較",
  "記述N (T / R)",
  "記述イベント数 (T / R)",
  "RD 推定値 [区間]",
  "100人あたり差 (E100)",
  "NNT・NNH-like",
  "RR 推定値 [区間]",
  "方向支持指標",
  "実務領域・U-Grade",
  "精度指標 (ESS / 区間幅)",
  "診断バッジ"
)

for (i in seq_along(expected_12_headers)) {
  hdr <- expected_12_headers[i]
  pattern <- sprintf("| %d | **%s** |", i, hdr)
  assert_true(grepl(pattern, comp_text, fixed = TRUE), sprintf("Column %d is exactly '%s'", i, hdr))
}

# Exact summary_df field names for the 12-column presentation contract
required_summary_fields <- c(
  "`theme`",
  "`target_arm`", "`reference_arm`",
  "`target_total`", "`reference_total`",
  "`target_events`", "`reference_events`",
  "`rd_estimate`", "`rd_interval_lower`", "`rd_interval_upper`",
  "`excess_per_100`",
  "`reciprocal_absolute_rd`", "`reciprocal_status`", "`reciprocal_direction`",
  "`rr_estimate`", "`rr_interval_lower`", "`rr_interval_upper`",
  "`direction_support`",
  "`dominant_region`", "`u_grade`",
  "`target_ess`", "`reference_ess`", "`rd_interval_width`",
  "`badges`"
)
for (fld in required_summary_fields) {
  assert_true(grepl(fld, comp_text, fixed = TRUE), sprintf("Documents real summary_df field %s", fld))
}

forbidden_pseudo_fields <- c(
  "`contrast`",
  "`descriptive_n`",
  "`descriptive_events`",
  "`rd_lower`",
  "`rd_upper`",
  "`rr_lower`",
  "`rr_upper`",
  "`practical_regions_ugrade`",
  "`precision_metrics`",
  "`diagnostic_badges`"
)
for (fld in forbidden_pseudo_fields) {
  assert_true(
    !grepl(fld, comp_text, fixed = TRUE),
    sprintf("Does NOT claim pseudo summary_df field %s", fld)
  )
}

# reciprocal status vs value separation (NOT_INTERPRETABLE may retain finite reciprocal)
assert_true(grepl("NOT_INTERPRETABLE", comp_text, fixed = TRUE), "Documents NOT_INTERPRETABLE")
assert_true(
  grepl("保持し得る", comp_text, fixed = TRUE) || grepl("保持", comp_text, fixed = TRUE),
  "Documents that pathological NOT_INTERPRETABLE may retain reciprocal point"
)

# Check independent zero-reference diagnostic contract
assert_true(grepl("`ZERO_REFERENCE`", comp_text, fixed = TRUE), "Independent zero-ref documents ZERO_REFERENCE badge")
assert_true(grepl("ZERO_REFERENCE_RISK", comp_text, fixed = TRUE), "Documents ZERO_REFERENCE_RISK for Matched Set/IPTW")
assert_true(grepl("ZERO_REFERENCE_EVENTS", comp_text, fixed = TRUE), "Documents ZERO_REFERENCE_EVENTS for person-time")
assert_true(
  grepl("diagnostics.badges", comp_text, fixed = TRUE) || grepl("diagnostics\\.badges", comp_text),
  "Documents diagnostics.badges field location for ZERO_REFERENCE"
)
assert_true(
  !grepl("rr_diagnostic = \"ZERO_REFERENCE_RISK\"", comp_text, fixed = TRUE),
  "Independent zero-ref does NOT claim rr_diagnostic = ZERO_REFERENCE_RISK"
)

# Check inferential semantics and point estimate contract
assert_true(grepl("posterior_median", comp_text, fixed = TRUE), "Documents posterior_median point estimate source")
assert_true(grepl("posterior_eti", comp_text, fixed = TRUE), "Documents posterior_eti interval method")
assert_true(grepl("NON_INTEGER_COUNT", comp_text, fixed = TRUE), "Documents NON_INTEGER_COUNT strict rejection")

cat("\n=== 2. Test design_aware_inference_math.md Contracts ===\n")
design_math_path <- "docs/reference/design_aware_inference_math.md"
assert_true(file.exists(design_math_path), "design_aware_inference_math.md exists")
design_lines <- readLines(design_math_path, encoding = "UTF-8", warn = FALSE)
design_text <- paste(design_lines, collapse = "\n")

# Check design-aware diagnostics
assert_true(grepl("ZERO_REFERENCE_RISK", design_text, fixed = TRUE), "Documents ZERO_REFERENCE_RISK for design-aware")
assert_true(
  grepl("PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES", design_text, fixed = TRUE),
  "Documents PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES for partial undefined replicates"
)
assert_true(
  grepl("log_rr_interval_width", design_text, fixed = TRUE),
  "Documents log_rr_interval_width suppression for matched-set RR policy"
)
assert_true(
  grepl("rr_interval_fold_range", design_text, fixed = TRUE),
  "Documents rr_interval_fold_range suppression for matched-set RR policy"
)
assert_true(
  grepl("ZERO_VARIANCE_NONZERO_DIFFERENCE", design_text, fixed = TRUE),
  "Documents ZERO_VARIANCE_NONZERO_DIFFERENCE SMD boundary"
)
assert_true(
  grepl("ZERO_VARIANCE_ZERO_DIFFERENCE", design_text, fixed = TRUE),
  "Documents ZERO_VARIANCE_ZERO_DIFFERENCE SMD boundary"
)

# IPTW positivity / clipping / failure provenance
assert_true(grepl("max_failure_rate", design_text, fixed = TRUE), "Documents IPTW max_failure_rate")
assert_true(grepl("0.05", design_text, fixed = TRUE), "Documents default max_failure_rate 0.05")
assert_true(
  grepl("bootstrap_clipping_diagnostics", design_text, fixed = TRUE) ||
    grepl("clipping", design_text, fixed = TRUE),
  "Documents IPTW clipping diagnostics"
)
assert_true(
  grepl("positivity", design_text, ignore.case = TRUE) ||
    grepl("common_support", design_text, fixed = TRUE),
  "Documents IPTW positivity / common_support"
)
assert_true(
  grepl("raw_target_ps", design_text, fixed = TRUE) ||
    grepl("raw-score", design_text, fixed = TRUE) ||
    grepl("raw / effective", design_text, fixed = TRUE),
  "Documents raw/effective PS summaries"
)

# Check bootstrap default and semantics
assert_true(grepl("num_draws = 4000L", design_text, fixed = TRUE), "Documents matched-set num_draws = 4000L default")
assert_true(grepl("observed_sample_estimate", design_text, fixed = TRUE), "Documents observed_sample_estimate")
assert_true(grepl("bootstrap_percentile", design_text, fixed = TRUE), "Documents bootstrap_percentile")

# Check Gamma-Poisson parameterization: shape_rate, NOT scale=0
assert_true(
  grepl("shape_rate", design_text, fixed = TRUE) || grepl("shape\\_rate", design_text, fixed = TRUE),
  "Documents Gamma parameterization = shape_rate"
)
assert_true(!grepl("尺度母数.*0", design_text), "Does NOT contain erroneous 'scale parameter = 0'")
assert_true(!grepl("scale\\s*=\\s*0", design_text, ignore.case = TRUE), "Does NOT contain erroneous 'scale = 0'")

cat("\n=== 3. Test root README.md Portal Synchronization ===\n")
readme_path <- "README.md"
assert_true(file.exists(readme_path), "README.md exists")
readme_text <- paste(readLines(readme_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")

assert_true(grepl("comparative_evidence_math.md", readme_text, fixed = TRUE), "README links to comparative_evidence_math.md")
assert_true(grepl("design_aware_inference_math.md", readme_text, fixed = TRUE), "README links to design_aware_inference_math.md")
assert_true(grepl("専用数理正本を充足", readme_text, fixed = TRUE), "README states dedicated math docs are satisfied (P0)")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) {
  stop(sprintf("[FAIL] %d documentation contract assertions failed.", test_fail))
}
