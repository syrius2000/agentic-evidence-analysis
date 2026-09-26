# tests/test_matched_set_inference.R — 1:k matched-set cluster bootstrap test suite
# Implements Section 9 verification for OpenSpec comparative-evidence-reporting-v3

test_pass <- 0L
test_fail <- 0L
assert_true <- function(condition, message) {
  if (isTRUE(condition)) {
    cat(sprintf("[PASS] %s\n", message))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", message))
    test_fail <<- test_fail + 1L
  }
}
assert_error_code <- function(expr, code, message) {
  error_message <- tryCatch({ expr; NULL }, error = function(e) conditionMessage(e))
  assert_true(!is.null(error_message) && grepl(code, error_message, fixed = TRUE), message)
}

source(".agents/shared/matched_set_inference.R")

cat("=== 1. Input Validation and Structural Integrity ===\n")

# Valid 1:2 dataset
valid_1to2 <- data.frame(
  subject_id = sprintf("SUBJ_%02d", 1:6),
  set_id = c("S1", "S1", "S1", "S2", "S2", "S2"),
  treatment = c(1L, 0L, 0L, 1L, 0L, 0L),
  outcome = c(1L, 0L, 1L, 0L, 0L, 0L),
  age = c(50, 48, 52, 60, 59, 61),
  stringsAsFactors = FALSE
)

assert_true(validate_matched_set_data(valid_1to2, covariates = "age"),
            "Valid 1:2 dataset passes structural validation")

# Rejects non-dataframe
assert_error_code(validate_matched_set_data(as.matrix(valid_1to2)), "INVALID_MATCHED_SET_DATA",
                  "Rejects non-dataframe input")

# Rejects missing subject_id_col
assert_error_code(validate_matched_set_data(valid_1to2[, -1L]), "MISSING_REQUIRED_COLUMNS",
                  "Rejects missing subject_id column")

# Rejects missing set_id column
assert_error_code(validate_matched_set_data(valid_1to2[, -2L]), "MISSING_REQUIRED_COLUMNS",
                  "Rejects missing set_id column")

# Rejects NA in subject_id, set_id or outcomes
na_data <- valid_1to2
na_data$outcome[[1L]] <- NA_integer_
assert_error_code(validate_matched_set_data(na_data), "INVALID_MATCHED_SET_DATA",
                  "Rejects NA in outcome column")

na_subj <- valid_1to2
na_subj$subject_id[[1L]] <- NA_character_
assert_error_code(validate_matched_set_data(na_subj), "INVALID_MATCHED_SET_DATA",
                  "Rejects NA in subject_id column")

# Rejects duplicate subject ID (T7: non-replacement enforcement)
dup_subj <- valid_1to2
dup_subj$subject_id[[4L]] <- dup_subj$subject_id[[1L]] # control in S1 reused as treated in S2
assert_error_code(validate_matched_set_data(dup_subj), "DUPLICATE_SUBJECT_ID",
                  "Rejects duplicate subject ID across sets (T7: non-replacement enforcement)")

# Rejects non-binary outcome
bad_outcome <- valid_1to2
bad_outcome$outcome[[1L]] <- 2L
assert_error_code(validate_matched_set_data(bad_outcome), "INVALID_BINARY_OUTCOME",
                  "Rejects non-binary outcome values")

# Rejects non-binary treatment
bad_treat <- valid_1to2
bad_treat$treatment[[1L]] <- -1L
assert_error_code(validate_matched_set_data(bad_treat), "INVALID_TREATMENT_VALUE",
                  "Rejects non-binary treatment values")

# Rejects multiple treated subjects in a single set
bad_set_target <- valid_1to2
bad_set_target$treatment[[2L]] <- 1L
assert_error_code(validate_matched_set_data(bad_set_target), "INVALID_MATCHED_SET_STRUCTURE",
                  "Rejects multiple treated subjects per matched set")

# Rejects zero control subjects in a set
bad_set_control <- valid_1to2[valid_1to2$set_id == "S1" | valid_1to2$treatment == 1L, ]
assert_error_code(validate_matched_set_data(bad_set_control), "INVALID_MATCHED_SET_STRUCTURE",
                  "Rejects set with zero control subjects")

# Rejects non-numeric covariate
bad_cov <- valid_1to2
bad_cov$age <- as.character(bad_cov$age)
assert_error_code(validate_matched_set_data(bad_cov, covariates = "age"), "INVALID_COVARIATE_TYPE",
                  "Rejects non-numeric covariate column")

cat("\n=== 2. Mathematical Exactness of ATT Estimator on Observed Sample ===\n")

synth_1to2 <- data.frame(
  subject_id = sprintf("SUBJ_%02d", 1:12),
  set_id = rep(sprintf("S%02d", 1:4), each = 3),
  treatment = rep(c(1L, 0L, 0L), times = 4),
  outcome = c(1L, 1L, 1L,   # S1: T=1, R_bar=1.0
              1L, 1L, 0L,   # S2: T=1, R_bar=0.5
              0L, 0L, 0L,   # S3: T=0, R_bar=0.0
              0L, 1L, 0L),  # S4: T=0, R_bar=0.5
  stringsAsFactors = FALSE
)

att_1to2 <- compute_matched_set_att_estimates(synth_1to2)
assert_true(isTRUE(all.equal(att_1to2$p_target, 0.5)), "Analytical p_target equals (1+1+0+0)/4 = 0.5")
assert_true(isTRUE(all.equal(att_1to2$p_reference, 0.5)), "Analytical p_reference equals (1.0+0.5+0.0+0.5)/4 = 0.5")
assert_true(isTRUE(all.equal(att_1to2$rd, 0.0)), "Analytical RD equals 0.0")
assert_true(isTRUE(all.equal(att_1to2$rr, 1.0)), "Analytical RR equals 1.0")

# Variable ratio dataset (1:1, 1:2, 1:3)
synth_variable <- data.frame(
  subject_id = sprintf("SUBJ_V%02d", 1:9),
  set_id = c("S1", "S1", "S2", "S2", "S2", "S3", "S3", "S3", "S3"),
  treatment = c(1L, 0L, 1L, 0L, 0L, 1L, 0L, 0L, 0L),
  outcome = c(1L, 1L, 0L, 1L, 0L, 1L, 0L, 0L, 0L),
  stringsAsFactors = FALSE
)

att_var <- compute_matched_set_att_estimates(synth_variable)
assert_true(isTRUE(all.equal(att_var$p_target, 2/3)), "Variable-ratio analytical p_target equals 2/3")
assert_true(isTRUE(all.equal(att_var$p_reference, 0.5)), "Variable-ratio analytical p_reference equals 1.5/3 = 0.5")
assert_true(isTRUE(all.equal(att_var$rd, 2/3 - 0.5)), "Variable-ratio analytical RD equals 1/6")
assert_true(isTRUE(all.equal(att_var$rr, (2/3) / 0.5)), "Variable-ratio analytical RR equals 4/3")

cat("\n=== 3. Consistency with 1:1 Matched Pairs when k=1 ===\n")

p11_data <- do.call(rbind, lapply(1:3, function(i) {
  data.frame(subject_id = sprintf("P11_%d_%s", i, c("T", "C")),
             set_id = sprintf("P11_%d", i), treatment = c(1L, 0L), outcome = c(1L, 1L), stringsAsFactors = FALSE)
}))
p10_data <- do.call(rbind, lapply(1:2, function(i) {
  data.frame(subject_id = sprintf("P10_%d_%s", i, c("T", "C")),
             set_id = sprintf("P10_%d", i), treatment = c(1L, 0L), outcome = c(1L, 0L), stringsAsFactors = FALSE)
}))
p01_data <- do.call(rbind, lapply(1:1, function(i) {
  data.frame(subject_id = sprintf("P01_%d_%s", i, c("T", "C")),
             set_id = sprintf("P01_%d", i), treatment = c(1L, 0L), outcome = c(0L, 1L), stringsAsFactors = FALSE)
}))
p00_data <- do.call(rbind, lapply(1:4, function(i) {
  data.frame(subject_id = sprintf("P00_%d_%s", i, c("T", "C")),
             set_id = sprintf("P00_%d", i), treatment = c(1L, 0L), outcome = c(0L, 0L), stringsAsFactors = FALSE)
}))
pair_1to1_df <- rbind(p11_data, p10_data, p01_data, p00_data)

att_1to1 <- compute_matched_set_att_estimates(pair_1to1_df)
assert_true(isTRUE(all.equal(att_1to1$p_target, 0.5)), "When k=1, p_target matches 1:1 matched pairs (0.5)")
assert_true(isTRUE(all.equal(att_1to1$p_reference, 0.4)), "When k=1, p_reference matches 1:1 matched pairs (0.4)")
assert_true(isTRUE(all.equal(att_1to1$rd, 0.1)), "When k=1, RD matches 1:1 matched pairs (0.1)")

cat("\n=== 4. Covariate Balance (SMD): Zero-Variance and ATT-Weighted Variance ===\n")

# T1: Constant equal covariate across all subjects
t1_data <- data.frame(
  subject_id = sprintf("T1_%02d", 1:6),
  set_id = c("S1", "S1", "S1", "S2", "S2", "S2"),
  treatment = c(1L, 0L, 0L, 1L, 0L, 0L),
  outcome = c(0L, 0L, 0L, 0L, 0L, 0L),
  cov_const = c(1, 1, 1, 1, 1, 1),
  stringsAsFactors = FALSE
)
b_t1 <- compute_covariate_balance(t1_data, covariates = "cov_const")[[1L]]
assert_true(identical(b_t1$smd_matched, 0.0), "T1: Constant equal covariate produces smd = 0.0")
assert_true(identical(b_t1$status, "ZERO_VARIANCE_ZERO_DIFFERENCE"),
            "T1: Constant equal covariate classified as ZERO_VARIANCE_ZERO_DIFFERENCE")

# T2: Complete separation (all treated=1, all controls=0)
t2_data <- data.frame(
  subject_id = sprintf("T2_%02d", 1:6),
  set_id = c("S1", "S1", "S1", "S2", "S2", "S2"),
  treatment = c(1L, 0L, 0L, 1L, 0L, 0L),
  outcome = c(0L, 0L, 0L, 0L, 0L, 0L),
  cov_sep = c(1, 0, 0, 1, 0, 0),
  stringsAsFactors = FALSE
)
b_t2 <- compute_covariate_balance(t2_data, covariates = "cov_sep")[[1L]]
assert_true(is.null(b_t2$smd_matched), "T2: Complete separation produces smd = NULL")
assert_true(identical(b_t2$status, "ZERO_VARIANCE_NONZERO_DIFFERENCE"),
            "T2: Complete separation classified as ZERO_VARIANCE_NONZERO_DIFFERENCE")

# T3: Variable-ratio weighted variance verification
# J = 3 sets: S1 (1:1), S2 (1:2), S3 (1:4)
# S1: T=10, R=(10) -> X_T1=10, X_R1_bar=10
# S2: T=20, R=(18, 22) -> X_T2=20, X_R2_bar=20
# S3: T=30, R=(26, 28, 32, 34) -> X_T3=30, X_R3_bar=30
t3_data <- data.frame(
  subject_id = sprintf("T3_%02d", 1:10),
  set_id = c("S1", "S1", "S2", "S2", "S2", "S3", "S3", "S3", "S3", "S3"),
  treatment = c(1L, 0L, 1L, 0L, 0L, 1L, 0L, 0L, 0L, 0L),
  outcome = rep(0L, 10),
  x = c(10, 10,  20, 18, 22,  30, 26, 28, 32, 34),
  stringsAsFactors = FALSE
)
# Hand calculations:
# x_T = c(10, 20, 30), mean_T = 20
# s_T^2 = ((10-20)^2 + (20-20)^2 + (30-20)^2) / 3 = (100 + 0 + 100) / 3 = 200/3
# mean_R_weighted = (10 + 20 + 30) / 3 = 20
# For controls:
# S1: k=1, ctrl=10: (10-20)^2 / 1 = 100
# S2: k=2, ctrls=(18, 22): ((18-20)^2 + (22-20)^2) / 2 = (4 + 4) / 2 = 4
# S3: k=4, ctrls=(26, 28, 32, 34): ((26-20)^2 + (28-20)^2 + (32-20)^2 + (34-20)^2) / 4 = (36 + 16 + 16 + 36) / 4 = 104 / 4 = 26
# s_R^2 = (100 + 4 + 26) / 3 = 130 / 3
# s_pooled = sqrt((200/3 + 130/3) / 2) = sqrt(330 / 6) = sqrt(55)
# mean_diff = 20 - 20 = 0 -> smd = 0.0, status = "OK" (variance is positive)
b_t3 <- compute_covariate_balance(t3_data, covariates = "x")[[1L]]
assert_true(identical(b_t3$status, "OK"), "T3: Variable ratio balance classified as OK")
assert_true(isTRUE(all.equal(b_t3$smd_matched, 0.0)), "T3: Perfectly balanced means yield smd = 0.0 with positive pooled SD")

# Now add shift to S3 treated: T=36
t3_shifted <- t3_data
t3_shifted$x[t3_shifted$set_id == "S3" & t3_shifted$treatment == 1L] <- 36
# mean_T = (10 + 20 + 36) / 3 = 66 / 3 = 22
# s_T^2 = ((10-22)^2 + (20-22)^2 + (36-22)^2) / 3 = (144 + 4 + 196) / 3 = 344 / 3
# mean_R_weighted = 20
# s_R^2:
# S1: k=1, ctrl=10: (10-20)^2 / 1 = 100
# S2: k=2, ctrls=(18, 22): ((18-20)^2 + (22-20)^2) / 2 = 8 / 2 = 4
# S3: k=4, ctrls=(26, 28, 32, 34): ((26-20)^2 + (28-20)^2 + (32-20)^2 + (34-20)^2) / 4
#     = (36 + 64 + 144 + 196) / 4 = 440 / 4 = 110
# s_R^2 = (100 + 4 + 110) / 3 = 214 / 3
# s_pooled = sqrt((344/3 + 214/3) / 2) = sqrt(558 / 6) = sqrt(93)
# mean_diff = 22 - 20 = 2
# expected_smd = 2 / sqrt(93)
b_t3_shift <- compute_covariate_balance(t3_shifted, covariates = "x")[[1L]]
assert_true(isTRUE(all.equal(b_t3_shift$smd_matched, 2 / sqrt(93))),
            "T3: Shifted variable ratio matches analytical ATT-weighted SMD formula")

cat("\n=== 5. Raw Counts vs ATT Risk Separation (T4) ===\n")

# S1: T=1, R=(1, 1) -> target event=1, ctrl events=2, total ctrls=2
# S2: T=0, R=(0, 0, 0) -> target event=0, ctrl events=0, total ctrls=3
# Total controls = 5, total events = 2
# Raw controls: 2/5 = 0.4
# Set-weighted controls: (1.0 + 0.0) / 2 = 0.5
t4_data <- data.frame(
  subject_id = sprintf("T4_%02d", 1:7),
  set_id = c("S1", "S1", "S1", "S2", "S2", "S2", "S2"),
  treatment = c(1L, 0L, 0L, 1L, 0L, 0L, 0L),
  outcome = c(1L, 1L, 1L, 0L, 0L, 0L, 0L),
  stringsAsFactors = FALSE
)
res_t4 <- run_matched_set_inference(t4_data, num_draws = 500L, seed = 42L)
assert_true(identical(res_t4$evidence$matched_set$raw_target_counts$events, 1L), "T4: raw_target_counts events = 1")
assert_true(identical(res_t4$evidence$matched_set$raw_target_counts$total, 2L), "T4: raw_target_counts total = 2")
assert_true(identical(res_t4$evidence$matched_set$raw_reference_counts$events, 2L), "T4: raw_reference_counts events = 2")
assert_true(identical(res_t4$evidence$matched_set$raw_reference_counts$total, 5L), "T4: raw_reference_counts total = 5")
assert_true(identical(res_t4$evidence$reference_cohort$estimate_semantics, "att_set_weighted_risk"),
            "T4: reference_cohort semantics is att_set_weighted_risk")
assert_true(is.null(res_t4$evidence$reference_cohort$events), "T4: reference_cohort events is NULL")
assert_true(is.null(res_t4$evidence$reference_cohort$total), "T4: reference_cohort total is NULL")
assert_true(isTRUE(all.equal(res_t4$evidence$reference_cohort$incidence_proportion, 0.5)),
            "T4: reference_cohort incidence_proportion is ATT-weighted risk (0.5), not raw risk (2/5)")

cat("\n=== 6. Governed Zero-Reference RR Policy (T5 & T6) ===\n")

# T5: Observed zero reference events
t5_data <- data.frame(
  subject_id = sprintf("T5_%02d", 1:4),
  set_id = c("S1", "S1", "S2", "S2"),
  treatment = c(1L, 0L, 1L, 0L),
  outcome = c(1L, 0L, 1L, 0L),
  stringsAsFactors = FALSE
)
res_t5 <- run_matched_set_inference(t5_data, num_draws = 500L, seed = 42L)
assert_true(is.null(res_t5$evidence$relative_risk$estimate$value), "T5: Observed RR estimate is NULL when reference risk = 0")
assert_true(is.null(res_t5$evidence$relative_risk$interval), "T5: RR interval is NULL when reference risk = 0")
assert_true(is.null(res_t5$evidence$relative_risk[["mean"]]), "T5: RR mean is NULL when reference risk = 0")
assert_true(identical(res_t5$evidence$relative_risk$mean_is_finite, FALSE), "T5: RR mean_is_finite is FALSE")
assert_true(identical(res_t5$evidence$relative_risk$diagnostic, "ZERO_REFERENCE_RISK"),
            "T5: RR diagnostic records ZERO_REFERENCE_RISK")
# T10 (B-01): Precision metrics log_rr_interval_width and fold range must be NULL when RR is suppressed
assert_true(is.null(res_t5$evidence$precision_metrics$log_rr_interval_width),
            "T10 (B-01): log_rr_interval_width is NULL when reference risk = 0")
assert_true(is.null(res_t5$evidence$precision_metrics$rr_interval_fold_range),
            "T10 (B-01): rr_interval_fold_range is NULL when reference risk = 0")

# T6: Observed reference risk > 0, but sparse (some bootstrap replicates have p_R* = 0)
# 4 sets, only 1 set has a reference event
t6_data <- data.frame(
  subject_id = sprintf("T6_%02d", 1:8),
  set_id = rep(sprintf("S%d", 1:4), each = 2),
  treatment = rep(c(1L, 0L), times = 4),
  outcome = c(1L, 1L,  1L, 0L,  0L, 0L,  0L, 0L),
  stringsAsFactors = FALSE
)
res_t6 <- run_matched_set_inference(t6_data, num_draws = 1000L, seed = 42L)
# p_R = 1/4 = 0.25 > 0, but with 4 sets resampled, prob(S1 not picked) = (3/4)^4 = 81/256 ~ 31.6%
diag_t6 <- res_t6$evidence$relative_risk$rr_bootstrap_diagnostics
assert_true(!is.null(diag_t6), "T6: rr_bootstrap_diagnostics is populated")
assert_true(diag_t6$undefined_replicates > 0L, "T6: Some bootstrap replicates have zero reference denominator")
assert_true(diag_t6$defined_replicates + diag_t6$undefined_replicates == 1000L, "T6: Replicate counts sum to 1000")
assert_true(is.null(res_t6$evidence$relative_risk$interval), "T6: Conservative policy suppresses RR interval (NULL)")
assert_true(identical(res_t6$evidence$relative_risk$diagnostic, "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"),
            "T6: Diagnostic records PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES")
assert_true(is.null(res_t6$evidence$precision_metrics$log_rr_interval_width),
            "T10 (B-01): log_rr_interval_width is NULL under partial undefined bootstrap replicates")
assert_true(is.null(res_t6$evidence$precision_metrics$rr_interval_fold_range),
            "T10 (B-01): rr_interval_fold_range is NULL under partial undefined bootstrap replicates")

cat("\n=== 7. Metadata, Bootstrap Scope, and Draw Invariants (T8) ===\n")

res_t8 <- run_matched_set_inference(synth_variable, num_draws = 1000L, seed = 42L, persist_raw_draws = TRUE)
assert_true(identical(res_t8$evidence$matched_set$estimand, "ATT"), "T8: Evidence records estimand = ATT")
assert_true(identical(res_t8$draws$matched_set_metadata$estimand, "ATT"), "T8: Draws records estimand = ATT")
assert_true(identical(res_t8$evidence$matched_set$bootstrap_scope$type, "conditional_on_fixed_matched_sets"),
            "T8: Evidence bootstrap_scope is conditional_on_fixed_matched_sets")
assert_true(identical(res_t8$draws$matched_set_metadata$bootstrap_scope$type, "conditional_on_fixed_matched_sets"),
            "T8: Draws bootstrap_scope is conditional_on_fixed_matched_sets")
assert_true(identical(res_t8$evidence$matched_set$bootstrap_scope$rematching_within_replicate, FALSE),
            "T8: rematching_within_replicate is FALSE")

cat("\n=== 8. Runtime Argument Validation (T9 & T12) ===\n")

assert_error_code(run_matched_set_inference(synth_variable, caliper = -0.1), "INVALID_ARGUMENT",
                  "T9: Rejects negative caliper")
assert_error_code(run_matched_set_inference(synth_variable, caliper = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf caliper")
assert_error_code(run_matched_set_inference(synth_variable, discarded_target = -1L), "INVALID_ARGUMENT",
                  "T9: Rejects negative discarded_target")
assert_error_code(run_matched_set_inference(synth_variable, discarded_target = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf discarded_target")
assert_error_code(run_matched_set_inference(synth_variable, discarded_reference = 1.5), "INVALID_ARGUMENT",
                  "T9: Rejects non-integer discarded_reference")
assert_error_code(run_matched_set_inference(synth_variable, discarded_reference = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf discarded_reference")
assert_error_code(run_matched_set_inference(synth_variable, num_draws = 0L), "INVALID_ARGUMENT",
                  "T9: Rejects num_draws = 0")
assert_error_code(run_matched_set_inference(synth_variable, num_draws = 9L), "INVALID_ARGUMENT",
                  "T12: Rejects num_draws = 9 (minimum is 10)")
assert_error_code(run_matched_set_inference(synth_variable, num_draws = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf num_draws")
assert_error_code(run_matched_set_inference(synth_variable, seed = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf seed")
assert_error_code(run_matched_set_inference(synth_variable, level = 1.5), "INVALID_ARGUMENT",
                  "T9: Rejects level outside (0, 1)")
assert_error_code(run_matched_set_inference(synth_variable, level = Inf), "INVALID_ARGUMENT",
                  "T12: Rejects Inf level")

# Non-finite covariate check
bad_cov_inf <- valid_1to2
bad_cov_inf$age[[1L]] <- Inf
assert_error_code(validate_matched_set_data(bad_cov_inf, covariates = "age"), "INVALID_COVARIATE_VALUE",
                  "T12: Rejects non-finite (Inf) covariate value")

# seed = NULL serializes as JSON null
res_null_seed <- run_matched_set_inference(synth_variable, seed = NULL, num_draws = 100L)
assert_true(is.null(res_null_seed$draws$seed), "T9: seed = NULL produces NULL seed in draws")

cat("\n=== 9. SMD Scale Invariance (T11 / H-02) ===\n")

# Verify that multiplying covariate by scale constant c produces identical SMD
scales <- c(1e-13, 1e-6, 1.0, 1e6, 1e13)
smd_by_scale <- vapply(scales, function(c_scale) {
  df_c <- t3_shifted
  df_c$x <- df_c$x * c_scale
  b_c <- compute_covariate_balance(df_c, covariates = "x")[[1L]]
  b_c$smd_matched
}, numeric(1L))

expected_smd <- 2 / sqrt(93)
assert_true(all(vapply(smd_by_scale, function(s) isTRUE(all.equal(s, expected_smd, tolerance = 1e-10)), logical(1L))),
            "T11: SMD is strictly scale-invariant across c = 1e-13 to 1e13 (H-02)")

# Verify sub-1e-12 tiny scale does not falsely collapse to ZERO_VARIANCE_ZERO_DIFFERENCE
tiny_data <- data.frame(
  subject_id = sprintf("TINY_%02d", 1:4),
  set_id = c("S1", "S1", "S2", "S2"),
  treatment = c(1L, 0L, 1L, 0L),
  outcome = c(0L, 0L, 0L, 0L),
  cov_tiny = c(2e-13, 1e-13, 4e-13, 3e-13), # X_T = (2e-13, 4e-13), X_R = (1e-13, 3e-13)
  stringsAsFactors = FALSE
)
b_tiny <- compute_covariate_balance(tiny_data, covariates = "cov_tiny")[[1L]]
assert_true(identical(b_tiny$status, "OK"), "T11: Tiny scale variance correctly classified as OK, not ZERO_VARIANCE")
assert_true(isTRUE(all.equal(b_tiny$smd_matched, 1.0, tolerance = 1e-10)),
            "T11: Tiny scale produces mathematically exact SMD = 1.0")

cat("\n=== 10. Seed Reproducibility Restoration (T13 / M-01) ===\n")

res_seed1 <- run_matched_set_inference(synth_variable, num_draws = 1000L, seed = 12345L, persist_raw_draws = TRUE)
res_seed2 <- run_matched_set_inference(synth_variable, num_draws = 1000L, seed = 12345L, persist_raw_draws = TRUE)

assert_true(identical(res_seed1$draws$target_draws, res_seed2$draws$target_draws),
            "T13 (M-01): Same seed produces identical target_draws")
assert_true(identical(res_seed1$draws$reference_draws, res_seed2$draws$reference_draws),
            "T13 (M-01): Same seed produces identical reference_draws")
assert_true(identical(res_seed1$evidence$risk_difference$interval, res_seed2$evidence$risk_difference$interval),
            "T13 (M-01): Same seed produces identical risk difference interval")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
