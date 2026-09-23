# tests/test_pass0_routing.R — Pass 0 Inspection and Routing Comprehensive Test Suite
# Tests Tasks 1.1 through 1.8 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/pass0_routing.R")

cat("=== 1. Test Pass 0 Schema Structure & Valid Config ===\n")
valid_config <- list(
  domain = "safety",
  estimand = "RD",
  analysis_unit = "subject",
  target = "Drug_A",
  reference = "Placebo",
  design = "independent_binary",
  practical_difference = list(
    mode = "none",
    primary_delta = NULL,
    unit = "per_100"
  ),
  reporting_purpose = "internal_safety_review",
  decision_review_flag = TRUE
)

ok_schema <- validate_pass0_config(valid_config)
assert_true(ok_schema, "Valid Pass 0 config passes validation")

cat("\n=== 2. Test Practical Difference mode='none' with null delta ===\n")
config_none <- valid_config
config_none$practical_difference$mode <- "none"
config_none$practical_difference$primary_delta <- NULL
assert_true(validate_pass0_config(config_none), "mode='none' with primary_delta=null is accepted as non-blocking")

cat("\n=== 3. Test Column Pattern Detection and Duplicate Subject Diagnostics ===\n")
# Create synthetic AE dataset with duplicates
tmp_ae_csv <- tempfile(fileext = ".csv")
ae_data <- data.frame(
  subject_id = c("SUBJ_01", "SUBJ_01", "SUBJ_01", "SUBJ_02", "SUBJ_03", "SUBJ_03"),
  soc = c("Infections", "Infections", "Infections", "Cardiac", "Nervous", "Nervous"),
  pt = c("Pneumonia", "Pneumonia", "Bronchitis", "Arrhythmia", "Headache", "Headache"),
  arm = c("Drug_A", "Drug_A", "Drug_A", "Drug_A", "Placebo", "Placebo"),
  events = c(1, 1, 1, 1, 1, 1),
  stringsAsFactors = FALSE
)
write.csv(ae_data, tmp_ae_csv, row.names = FALSE)

inspection_ae <- inspect_tabular_input(ae_data, valid_config)
assert_true(length(inspection_ae$diagnostics$detected_columns$subject_columns) > 0, "subject_id column detected")
assert_true(length(inspection_ae$diagnostics$detected_columns$soc_columns) > 0, "soc column detected")
assert_true(length(inspection_ae$diagnostics$detected_columns$pt_columns) > 0, "pt column detected")
assert_true(inspection_ae$diagnostics$duplicate_subjects$pt_duplicates == 2, "PT duplicate count is exactly 2")
assert_true(inspection_ae$diagnostics$duplicate_subjects$soc_duplicates == 3, "SOC duplicate count is exactly 3")
assert_true(!is.null(inspection_ae$diagnostics$duplicate_subjects$proposed_counting_rule), "Standard deduplication counting rule proposed")

cat("\n=== 4. Test Deterministic Routing for Independent Binary ===\n")
# Clean cohort counts
tmp_cohort_csv <- tempfile(fileext = ".csv")
cohort_data <- data.frame(
  arm = c("Drug_A", "Placebo"),
  events = c(12L, 4L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
write.csv(cohort_data, tmp_cohort_csv, row.names = FALSE)

tmp_out_json <- tempfile(fileext = ".json")
decision <- generate_routing_decision(tmp_cohort_csv, valid_config, out_file = tmp_out_json)

assert_true(decision$target_engine_slug == "vcd-categorical-reporting", "Target engine is vcd-categorical-reporting")
assert_true(decision$engine_module == ".agents/shared/independent_beta_binomial.R", "Module is independent_beta_binomial.R")
assert_true(decision$inferential_semantics == "posterior", "Inferential semantics is posterior")
assert_true(file.exists(tmp_out_json), "routing_decision.json file successfully generated")

cat("\n=== 5. Test Non-Integer Count / Weighted Pseudo-Count Interception ===\n")
tmp_float_csv <- tempfile(fileext = ".csv")
float_data <- data.frame(
  arm = c("Drug_A", "Placebo"),
  events = c(12.45, 4.12),
  total = c(98.3, 101.2),
  stringsAsFactors = FALSE
)
write.csv(float_data, tmp_float_csv, row.names = FALSE)

assert_error_code(
  generate_routing_decision(tmp_float_csv, valid_config),
  "UNSUPPORTED_WEIGHTED_INPUT",
  "Float counts rejected with UNSUPPORTED_WEIGHTED_INPUT"
)

cat("\n=== 6. Test Complex Survey Weight Rejection ===\n")
tmp_survey_csv <- tempfile(fileext = ".csv")
survey_data <- data.frame(
  arm = c("Drug_A", "Placebo"),
  events = c(12L, 4L),
  total = c(100L, 100L),
  survey_weight = c(1.2, 0.8),
  stringsAsFactors = FALSE
)
write.csv(survey_data, tmp_survey_csv, row.names = FALSE)

assert_error_code(
  generate_routing_decision(tmp_survey_csv, valid_config),
  "UNSUPPORTED_SURVEY_DESIGN",
  "Survey weights rejected with UNSUPPORTED_SURVEY_DESIGN"
)

cat("\n=== 7. Test Routing to Observational Design Engine (IPTW/Matched) ===\n")
iptw_config <- valid_config
iptw_config$design <- "iptw"
iptw_config$estimand <- "ATE"
iptw_config$requires_estimand_confirmation <- FALSE

tmp_iptw_csv <- tempfile(fileext = ".csv")
iptw_data <- data.frame(
  arm = c("Drug_A", "Placebo"),
  events = c(12.5, 4.2),
  weight = c(1.1, 0.9),
  stringsAsFactors = FALSE
)
write.csv(iptw_data, tmp_iptw_csv, row.names = FALSE)

decision_iptw <- generate_routing_decision(tmp_iptw_csv, iptw_config)
assert_true(decision_iptw$target_engine_slug == "comparative-design-analysis", "IPTW routes to comparative-design-analysis")
assert_true(decision_iptw$inferential_semantics == "bootstrap", "IPTW semantics is bootstrap")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
