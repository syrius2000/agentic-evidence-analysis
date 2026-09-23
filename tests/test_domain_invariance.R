# tests/test_domain_invariance.R — Domain Invariance and Context Decorators Test Suite
# Tests Tasks 6.1 through 6.5 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/safety_adapter.R")
source(".agents/shared/rwd_adapters.R")

cat("=== 1. Test Generic Hierarchical Aggregation & Deduplication ===\n")
df_generic <- data.frame(
  subject_id = c("P1", "P1", "P2", "P3"),
  parent_theme = c("Cardio", "Cardio", "Cardio", "Neuro"),
  item_theme = c("MI", "MI", "Stroke", "Seizure"),
  arm = c("Target", "Target", "Target", "Reference"),
  stringsAsFactors = FALSE
)
denoms <- c("Target" = 50, "Reference" = 50)

agg_gen <- aggregate_hierarchical_data(df_generic, denoms, "Target", "Reference")
cardio <- agg_gen$hierarchy$Cardio

assert_true(cardio$target_events == 2L, "Cardio has 2 unique patients (P1 and P2)")
assert_true(cardio$items$MI$target_events == 1L, "MI has 1 unique patient (P1 counted once)")

cat("\n=== 2. Test Domain Decorators ===\n")
raw_engine_res <- run_independent_beta_binomial(
  target_events = 20, target_total = 200,
  reference_events = 8, reference_total = 200,
  seed = 42L, primary_delta = 0.05
)

dec_safety <- decorate_comparative_evidence(raw_engine_res$evidence, "safety")
dec_rwd <- decorate_comparative_evidence(raw_engine_res$evidence, "rwd")
dec_rx <- decorate_comparative_evidence(raw_engine_res$evidence, "prescription")

assert_true(dec_safety$presentation$primary_unit_label == "additional_subjects_per_100_treated", "Safety primary unit label matches")
assert_true(dec_rwd$presentation$primary_unit_label == "additional_patients_per_100_cohort", "RWD primary unit label matches")
assert_true(dec_rx$presentation$primary_unit_label == "additional_patients_per_100_prescribed", "Rx primary unit label matches")

# Assert underlying statistical numbers untouched
assert_true(identical(raw_engine_res$evidence$risk_difference, dec_safety$risk_difference), "Safety decorator preserves RD numbers")
assert_true(identical(raw_engine_res$evidence$relative_risk, dec_rwd$relative_risk), "RWD decorator preserves RR numbers")
assert_true(identical(raw_engine_res$evidence$resolution_grade, dec_rx$resolution_grade), "Rx decorator preserves U-grade numbers")

cat("\n=== 3. Statistical Invariance Test Across Safety, RWD, and Rx Adapters ===\n")
# Construct three synthetic datasets with identical underlying counts:
# Target: 20 unique subjects out of 200
# Reference: 8 unique subjects out of 200

# Safety Data
safety_df <- data.frame(
  subject_id = c(paste0("T_", seq_len(20)), paste0("R_", seq_len(8))),
  primary_soc = "Neoplasms",
  pt = "Malignancy",
  arm = c(rep("Treated", 20), rep("Control", 8)),
  stringsAsFactors = FALSE
)
meddra_meta <- list(version = "26.1", release_date = "2023-09-01")
safety_denoms <- c("Treated" = 200, "Control" = 200)
safety_agg <- aggregate_safety_data(safety_df, safety_denoms, "Treated", "Control", meddra_metadata = meddra_meta)
safety_pt <- safety_agg$hierarchy$Neoplasms$pts$Malignancy
safety_stat <- run_independent_beta_binomial(
  safety_pt$target_events, safety_pt$target_total,
  safety_pt$reference_events, safety_pt$reference_total,
  seed = 999L, primary_delta = 0.05
)

# RWD Data
rwd_df <- data.frame(
  patient_id = c(paste0("T_", seq_len(20)), paste0("R_", seq_len(8))),
  icd_chapter = "Neoplasms_C00_D48",
  diagnosis_code = "C50_Malignant_Breast",
  cohort = c(rep("Treated", 20), rep("Control", 8)),
  stringsAsFactors = FALSE
)
rwd_agg <- adapt_rwd_diagnosis_procedure(rwd_df, safety_denoms, "Treated", "Control")
rwd_item <- rwd_agg$hierarchy$Neoplasms_C00_D48$items$C50_Malignant_Breast
rwd_stat <- run_independent_beta_binomial(
  rwd_item$target_events, rwd_item$target_total,
  rwd_item$reference_events, rwd_item$reference_total,
  seed = 999L, primary_delta = 0.05
)

# Prescription Data
rx_df <- data.frame(
  patient_id = c(paste0("T_", seq_len(20)), paste0("R_", seq_len(8))),
  therapeutic_class = "Antineoplastic_L01",
  active_ingredient = "Trastuzumab",
  cohort = c(rep("Treated", 20), rep("Control", 8)),
  stringsAsFactors = FALSE
)
rx_agg <- adapt_prescription_formulary(rx_df, safety_denoms, "Treated", "Control")
rx_item <- rx_agg$hierarchy$Antineoplastic_L01$items$Trastuzumab
rx_stat <- run_independent_beta_binomial(
  rx_item$target_events, rx_item$target_total,
  rx_item$reference_events, rx_item$reference_total,
  seed = 999L, primary_delta = 0.05
)

# Invariance assertions:
assert_true(
  identical(safety_stat$evidence$risk_difference$estimate$value, rwd_stat$evidence$risk_difference$estimate$value) &&
  identical(rwd_stat$evidence$risk_difference$estimate$value, rx_stat$evidence$risk_difference$estimate$value),
  "Domain Invariance: RD median is identical across Safety, RWD, and Rx"
)

assert_true(
  identical(safety_stat$evidence$risk_difference$interval, rwd_stat$evidence$risk_difference$interval) &&
  identical(rwd_stat$evidence$risk_difference$interval, rx_stat$evidence$risk_difference$interval),
  "Domain Invariance: RD credible interval is identical across Safety, RWD, and Rx"
)

assert_true(
  identical(safety_stat$evidence$relative_risk$estimate$value, rwd_stat$evidence$relative_risk$estimate$value) &&
  identical(rwd_stat$evidence$relative_risk$estimate$value, rx_stat$evidence$relative_risk$estimate$value),
  "Domain Invariance: RR median is identical across Safety, RWD, and Rx"
)

assert_true(
  identical(safety_stat$evidence$resolution_grade$grade, rwd_stat$evidence$resolution_grade$grade) &&
  identical(rwd_stat$evidence$resolution_grade$grade, rx_stat$evidence$resolution_grade$grade),
  "Domain Invariance: U-grade is identical across Safety, RWD, and Rx"
)

assert_true(
  identical(safety_stat$evidence$direction_support$support_value, rwd_stat$evidence$direction_support$support_value) &&
  identical(rwd_stat$evidence$direction_support$support_value, rx_stat$evidence$direction_support$support_value),
  "Domain Invariance: Direction support is identical across Safety, RWD, and Rx"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
