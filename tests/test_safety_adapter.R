# tests/test_safety_adapter.R — Clinical Safety Adverse Event Adapter Test Suite
# Tests Tasks 5.1 through 5.12 of OpenSpec comparative-evidence-reporting-v3

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

assert_error_code <- function(expr, expected_code, msg) {
  err <- tryCatch({
    expr
    NULL
  }, error = function(e) e$message)

  if (!is.null(err) && grepl(expected_code, err, fixed = TRUE)) {
    cat(sprintf("[PASS] %s (intercepted %s)\n", msg, expected_code))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s (expected %s, got: %s)\n", msg, expected_code, as.character(err)))
    test_fail <<- test_fail + 1L
  }
}

source(".agents/shared/safety_adapter.R")

cat("=== 1. Test MedDRA Metadata Provenance Requirement (Version + Release) ===\n")
dummy_ae <- data.frame(
  subject_id = "SUBJ_1",
  primary_soc = "Infections",
  pt = "Pneumonia",
  arm = "Drug_A",
  stringsAsFactors = FALSE
)
denoms <- c("Drug_A" = 100, "Placebo" = 100)

assert_error_code(
  aggregate_safety_data(dummy_ae, denoms, "Drug_A", "Placebo", meddra_metadata = list()),
  "MISSING_MEDDRA_METADATA",
  "Fails fast when MedDRA version is missing"
)
assert_error_code(
  aggregate_safety_data(dummy_ae, denoms, "Drug_A", "Placebo", meddra_metadata = list(version = "26.1")),
  "MISSING_MEDDRA_METADATA",
  "Fails fast when MedDRA release metadata is missing"
)

valid_meddra <- list(version = "26.1", release_date = "2023-09-01")

cat("\n=== 2. Test Subject Deduplication within PT and SOC ===\n")
ae_fixture <- data.frame(
  subject_id = c("SUBJ_1", "SUBJ_1", "SUBJ_1", "SUBJ_2"),
  primary_soc = c("Infections", "Infections", "Infections", "Nervous"),
  pt = c("Pneumonia", "Pneumonia", "Bronchitis", "Headache"),
  arm = c("Drug_A", "Drug_A", "Drug_A", "Drug_A"),
  stringsAsFactors = FALSE
)

agg <- aggregate_safety_data(ae_fixture, denoms, "Drug_A", "Placebo", meddra_metadata = valid_meddra)
inf_soc <- agg$hierarchy$Infections

assert_true(inf_soc$pts$Pneumonia$target_events == 1L, "SUBJ_1 counted exactly once for Pneumonia despite 2 events")
assert_true(inf_soc$pts$Bronchitis$target_events == 1L, "SUBJ_1 counted exactly once for Bronchitis")
assert_true(inf_soc$target_events == 1L, "SUBJ_1 counted exactly once for SOC Infections despite experiencing 2 distinct PTs")
assert_true(inf_soc$sum_child_pt_target_events == 2L, "Sum of child PTs is 2, while SOC count is 1")
assert_true(inf_soc$target_events != inf_soc$sum_child_pt_target_events, "Invariant holds: SOC count != sum of child PT counts")

cat("\n=== 3. Test Study-Specific Stratification and Descriptive Pooling (Task 5.8) ===\n")
ae_multi_study <- data.frame(
  study_id = c("STUDY_101", "STUDY_101", "STUDY_102", "STUDY_102"),
  subject_id = c("S1", "S2", "S3", "S4"),
  primary_soc = c("Infections", "Infections", "Infections", "Infections"),
  pt = c("Pneumonia", "Pneumonia", "Pneumonia", "Pneumonia"),
  arm = c("Drug_A", "Placebo", "Drug_A", "Placebo"),
  stringsAsFactors = FALSE
)

agg_multi <- aggregate_safety_data(
  ae_df = ae_multi_study,
  cohort_denominators = c("Drug_A" = 100, "Placebo" = 100),
  target_arm = "Drug_A",
  reference_arm = "Placebo",
  study_col = "study_id",
  meddra_metadata = valid_meddra
)

assert_true(agg_multi$aggregation_mode == "descriptive_pooled", "Multi-study aggregation marked as descriptive_pooled")
assert_true(!is.null(agg_multi$study_stratified), "Study-stratified hierarchy is present")
assert_true("STUDY_101" %in% names(agg_multi$study_stratified), "STUDY_101 is stratified")
assert_true("STUDY_102" %in% names(agg_multi$study_stratified), "STUDY_102 is stratified")

cat("\n=== 4. Test Reciprocal RD (NNH / NNT) Management & Boundary 0 Touching ===\n")
# Case A: Crossing zero -> SIGN_AMBIGUOUS (naive interval suppressed)
recip_cross <- compute_reciprocal_rd(rd_point = 0.02, rd_lower = -0.01, rd_upper = 0.05)
assert_true(recip_cross$status == "SIGN_AMBIGUOUS", "Status is SIGN_AMBIGUOUS when CI crosses zero")
assert_true(is.null(recip_cross$interval), "Naive interval is suppressed when crossing zero")

# Case A2: Touching zero boundary (rd_lower == 0)
recip_touch <- compute_reciprocal_rd(rd_point = 0.03, rd_lower = 0.00, rd_upper = 0.06)
assert_true(recip_touch$status == "SIGN_AMBIGUOUS", "Status is SIGN_AMBIGUOUS when CI touches zero boundary")

# Case B: RD near zero
recip_zero <- compute_reciprocal_rd(rd_point = 0.00001, rd_lower = -0.005, rd_upper = 0.005)
assert_true(recip_zero$status == "RD_NEAR_ZERO", "Status is RD_NEAR_ZERO when estimate < 1e-4")

# Case C: Stable positive direction
recip_stable <- compute_reciprocal_rd(rd_point = 0.05, rd_lower = 0.02, rd_upper = 0.10)
assert_true(recip_stable$status == "STABLE_DIRECTION", "Status is STABLE_DIRECTION when CI is bounded away from zero")
assert_true(abs(recip_stable$value - 20.0) < 1e-6, "NNH point estimate is 1 / 0.05 = 20")
assert_true(!is.null(recip_stable$interval), "Interval is present for stable direction")
assert_true(abs(recip_stable$interval[[1L]] - 10.0) < 1e-6, "Lower bound of NNH is 1 / 0.10 = 10")
assert_true(abs(recip_stable$interval[[2L]] - 50.0) < 1e-6, "Upper bound of NNH is 1 / 0.02 = 50")

cat("\n=== 5. Test Zero-Cell Adverse Event Handling ===\n")
ae_zero <- data.frame(
  subject_id = "SUBJ_1",
  primary_soc = "Neoplasms",
  pt = "Rare_Tumor",
  arm = "Drug_A",
  stringsAsFactors = FALSE
)
agg_zero <- aggregate_safety_data(ae_zero, denoms, "Drug_A", "Placebo", meddra_metadata = valid_meddra)
res_zero <- run_independent_beta_binomial(
  target_events = agg_zero$hierarchy$Neoplasms$pts$Rare_Tumor$target_events,
  target_total = agg_zero$hierarchy$Neoplasms$pts$Rare_Tumor$target_total,
  reference_events = agg_zero$hierarchy$Neoplasms$pts$Rare_Tumor$reference_events,
  reference_total = agg_zero$hierarchy$Neoplasms$pts$Rare_Tumor$reference_total
)
assert_true("ZERO_REFERENCE" %in% res_zero$evidence$diagnostics$badges, "Zero reference adverse event handled safely with badge")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
