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
ambiguous_numeric <- data.frame(arm = c("A", "B"), age = c(40, 50), score = c(1.2, 2.3))
assert_error_code(inspect_tabular_input(ambiguous_numeric, valid_config), "COUNT_COLUMNS_REQUIRED",
                  "Ambiguous numeric columns require explicit count mappings")
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

cat("\n=== 8. Test Confirmed Repeated-Row Subject Collapse and Routing ===\n")
repeated_config <- valid_config
repeated_config$repeated_rows <- list(
  subject_id_col = "subject_id", group_col = "arm", outcome_col = "outcome",
  event_rule = "any_event", confirmed = TRUE,
  no_other_subject_dependence_confirmed = TRUE
)
repeated_data <- data.frame(
  subject_id = c("T1", "T1", "T2", "R1", "R1", "R2"),
  arm = c("Drug_A", "Drug_A", "Drug_A", "Placebo", "Placebo", "Placebo"),
  outcome = c(0L, 1L, 0L, 0L, 1L, 0L),
  stringsAsFactors = FALSE
)
tmp_repeated_csv <- tempfile(fileext = ".csv")
write.csv(repeated_data, tmp_repeated_csv, row.names = FALSE)
original_repeated_bytes <- readBin(tmp_repeated_csv, "raw", n = file.info(tmp_repeated_csv)$size)
repeated_decision <- generate_routing_decision(tmp_repeated_csv, repeated_config)
assert_true(identical(repeated_decision$target_engine_slug, "vcd-categorical-reporting") &&
              identical(repeated_decision$engine_module, ".agents/shared/independent_beta_binomial.R"),
            "Confirmed subject-level binary data route to independent Beta-Binomial engine")
assert_true(identical(repeated_decision$subject_level_counts$target, list(events = 1L, total = 2L)) &&
              identical(repeated_decision$subject_level_counts$reference, list(events = 1L, total = 2L)),
            "Any-event rule produces correct subject-level arm counts")
assert_true(identical(repeated_decision$engine_input, list(
                contract = "independent_binary_counts_v1",
                target_events = 1L, target_total = 2L,
                reference_events = 1L, reference_total = 2L,
                source = "repeated_rows_any_event_collapse"
              )),
            "Routing artifact emits canonical engine_input handoff block")
assert_true(identical(repeated_decision$diagnostics$repeated_rows$repeated_rows, 2L) &&
              identical(repeated_decision$input_sha256, digest::digest(file = tmp_repeated_csv, algo = "sha256")),
            "Decision records repeated-row count and original input hash")
assert_true(identical(readBin(tmp_repeated_csv, "raw", n = file.info(tmp_repeated_csv)$size), original_repeated_bytes),
            "Pass 0 does not modify repeated-row input")

source(".agents/shared/independent_beta_binomial.R")
engine_from_handoff <- run_independent_beta_binomial(
  target_events = repeated_decision$engine_input$target_events,
  target_total = repeated_decision$engine_input$target_total,
  reference_events = repeated_decision$engine_input$reference_events,
  reference_total = repeated_decision$engine_input$reference_total,
  seed = 7L, num_draws = 50L
)
assert_true(identical(engine_from_handoff$draws$inferential_semantics, "posterior") &&
              is.list(engine_from_handoff$evidence),
            "Canonical engine_input values execute run_independent_beta_binomial()")

unconfirmed_config <- repeated_config
unconfirmed_config$repeated_rows$confirmed <- FALSE
assert_error_code(generate_routing_decision(tmp_repeated_csv, unconfirmed_config), "UNCONFIRMED_SUBJECT_COLLAPSE",
                  "Unconfirmed collapse is rejected")
no_dep_confirm <- repeated_config
no_dep_confirm$repeated_rows$no_other_subject_dependence_confirmed <- FALSE
assert_error_code(generate_routing_decision(tmp_repeated_csv, no_dep_confirm), "UNCONFIRMED_SUBJECT_DEPENDENCE",
                  "Missing no-other-dependence confirmation is rejected")
wrong_design_config <- repeated_config
wrong_design_config$design <- "iptw"
assert_error_code(generate_routing_decision(tmp_repeated_csv, wrong_design_config), "INVALID_REPEATED_ROWS_POLICY",
                  "Repeated-row collapse cannot silently route through IPTW")
bad_group <- repeated_data
bad_group$arm[[2L]] <- "Placebo"
assert_error_code(assess_repeated_subject_rows(bad_group, repeated_config), "INCONSISTENT_SUBJECT_GROUP",
                  "Same subject cannot change treatment arm")
bad_outcome <- repeated_data
bad_outcome$outcome[[1L]] <- 2L
assert_error_code(assess_repeated_subject_rows(bad_outcome, repeated_config), "INVALID_BINARY_OUTCOME",
                  "Non-binary repeated outcome is rejected")
missing_id <- repeated_data
missing_id$subject_id[[1L]] <- NA_character_
assert_error_code(assess_repeated_subject_rows(missing_id, repeated_config), "INVALID_REPEATED_ROWS",
                  "Missing subject ID is rejected")
missing_column <- repeated_data[, -3L]
assert_error_code(assess_repeated_subject_rows(missing_column, repeated_config), "MISSING_REPEATED_ROWS_COLUMNS",
                  "Missing outcome column is rejected")
hierarchical_data <- repeated_data
hierarchical_data$site_id <- c("S1", "S1", "S1", "S2", "S2", "S2")
assert_error_code(inspect_tabular_input(hierarchical_data, repeated_config), "HIERARCHICAL_CLUSTER_NOT_SUPPORTED",
                  "Shared site clusters cannot be treated as independent subjects")
facility_data <- repeated_data
facility_data$facility_id <- c("F01", "F01", "F01", "F02", "F02", "F02")
assert_error_code(inspect_tabular_input(facility_data, repeated_config), "HIERARCHICAL_CLUSTER_NOT_SUPPORTED",
                  "Noncanonical facility_id cannot evade the cluster guard")
hospital_data <- repeated_data
hospital_data$hospital_id <- c("H1", "H1", "H1", "H2", "H2", "H2")
assert_error_code(inspect_tabular_input(hospital_data, repeated_config), "HIERARCHICAL_CLUSTER_NOT_SUPPORTED",
                  "Noncanonical hospital_id cannot evade the cluster guard")
configured_cluster_data <- repeated_data
configured_cluster_data$custom_site <- c("C1", "C1", "C1", "C2", "C2", "C2")
configured_cluster_config <- repeated_config
configured_cluster_config$repeated_rows$cluster_cols <- "custom_site"
assert_error_code(inspect_tabular_input(configured_cluster_data, configured_cluster_config),
                  "HIERARCHICAL_CLUSTER_NOT_SUPPORTED",
                  "Configured noncanonical cluster column is merged into the guard")
matched_data <- repeated_data
matched_data$pair_id <- c("P1", "P1", "P2", "P1", "P1", "P2")
assert_error_code(inspect_tabular_input(matched_data, repeated_config), "MATCHED_STRUCTURE_NOT_COLLAPSIBLE",
                  "Matched structure cannot be discarded by subject collapse")
matched_set_data <- repeated_data
matched_set_data$set_id <- c("S1", "S1", "S2", "S1", "S1", "S2")
assert_error_code(inspect_tabular_input(matched_set_data, repeated_config), "MATCHED_STRUCTURE_NOT_COLLAPSIBLE",
                  "Canonical set_id cannot be discarded by subject collapse")
matched_group_data <- repeated_data
matched_group_data$matched_group_id <- c("G1", "G1", "G2", "G1", "G1", "G2")
assert_error_code(inspect_tabular_input(matched_group_data, repeated_config), "MATCHED_STRUCTURE_NOT_COLLAPSIBLE",
                  "Noncanonical matched_group_id cannot evade the matched-structure guard")
configured_matched_data <- repeated_data
configured_matched_data$custom_match <- c("M1", "M1", "M2", "M1", "M1", "M2")
configured_matched_config <- repeated_config
configured_matched_config$repeated_rows$matched_cols <- "custom_match"
assert_error_code(inspect_tabular_input(configured_matched_data, configured_matched_config),
                  "MATCHED_STRUCTURE_NOT_COLLAPSIBLE",
                  "Configured noncanonical matched column is merged into the guard")
unexpected_key_config <- repeated_config
unexpected_key_config$repeated_rows$unknown_flag <- TRUE
assert_error_code(validate_pass0_config(unexpected_key_config), "INVALID_REPEATED_ROWS_POLICY",
                  "Unexpected repeated_rows keys are rejected at runtime")
unapproved_repeated_data <- repeated_data
unapproved_repeated_data$events <- unapproved_repeated_data$outcome
tmp_unapproved_csv <- tempfile(fileext = ".csv")
write.csv(unapproved_repeated_data, tmp_unapproved_csv, row.names = FALSE)
assert_error_code(generate_routing_decision(tmp_unapproved_csv, valid_config), "REPEATED_ROWS_REQUIRE_COLLAPSE_POLICY",
                  "Duplicated subject rows cannot silently reach the binary engine")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
