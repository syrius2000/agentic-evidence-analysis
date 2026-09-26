# tests/test_iptw_inference.R — IPTW Propensity Score Bootstrap Test Suite
# Implements Section 10 verification for OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/iptw_inference.R")
source(".agents/shared/independent_beta_binomial.R")

cat("=== 1. Input Validation and Structural Integrity ===\n")

# Synthetic baseline data
set.seed(42)
N <- 100L
x1 <- rnorm(N, mean = 50, sd = 10)
x2 <- rbinom(N, size = 1, prob = 0.4)
# True propensity model: logit(e) = -1.5 + 0.03 * x1 + 0.8 * x2
lp <- -1.5 + 0.03 * x1 + 0.8 * x2
ps_true <- 1 / (1 + exp(-lp))
treat <- rbinom(N, size = 1, prob = ps_true)
# Ensure at least 10 in each arm
while(sum(treat == 1L) < 15L || sum(treat == 0L) < 15L) {
  treat <- rbinom(N, size = 1, prob = ps_true)
}
# Outcome model
y_prob <- 0.1 + 0.2 * treat + 0.002 * x1
outcome <- rbinom(N, size = 1, prob = pmin(pmax(y_prob, 0.01), 0.99))

valid_iptw_df <- data.frame(
  patient_id = sprintf("PT_%03d", 1:N),
  treatment = treat,
  outcome = outcome,
  age = x1,
  comorbidity = x2,
  stringsAsFactors = FALSE
)

assert_true(validate_iptw_data(valid_iptw_df, covariates = c("age", "comorbidity")),
            "Valid observational dataset passes structural validation")
assert_true(validate_iptw_data(valid_iptw_df, covariates = "age", subject_id_col = "patient_id"),
            "Unique non-missing subject IDs pass validation")
dup_id <- valid_iptw_df; dup_id$patient_id[[2L]] <- dup_id$patient_id[[1L]]
assert_error_code(validate_iptw_data(dup_id, covariates = "age", subject_id_col = "patient_id"),
                  "REPEATED_SUBJECT_ROWS", "Rejects repeated subject rows")
na_id <- valid_iptw_df; na_id$patient_id[[2L]] <- NA_character_
assert_error_code(validate_iptw_data(na_id, covariates = "age", subject_id_col = "patient_id"),
                  "INVALID_SUBJECT_ID", "Rejects missing subject IDs")

# Rejects non-dataframe
assert_error_code(validate_iptw_data(as.matrix(valid_iptw_df), covariates = "age"), "INVALID_IPTW_DATA",
                  "Rejects non-dataframe input")

# Rejects missing columns
assert_error_code(validate_iptw_data(valid_iptw_df[, -2L], treatment_col = "treatment", covariates = "age"),
                  "MISSING_REQUIRED_COLUMNS", "Rejects missing treatment column")

# Rejects small sample size (< 10 rows)
assert_error_code(validate_iptw_data(valid_iptw_df[1:8, ], covariates = "age"),
                  "INSUFFICIENT_SAMPLE_SIZE", "Rejects sample size < 10")

# Rejects non-binary treatment
bad_treat <- valid_iptw_df
bad_treat$treatment[[1L]] <- 2L
assert_error_code(validate_iptw_data(bad_treat, covariates = "age"),
                  "INVALID_TREATMENT_VALUE", "Rejects non-binary treatment")

# Rejects non-binary outcome
bad_out <- valid_iptw_df
bad_out$outcome[[1L]] <- 2L
assert_error_code(validate_iptw_data(bad_out, covariates = "age"),
                  "INVALID_BINARY_OUTCOME", "Rejects non-binary outcome")

# Rejects missing covariates argument
assert_error_code(validate_iptw_data(valid_iptw_df, covariates = NULL),
                  "MISSING_COVARIATES", "Rejects missing covariates specification")

# Rejects non-numeric / non-finite covariate
bad_cov_chr <- valid_iptw_df
bad_cov_chr$age <- as.character(bad_cov_chr$age)
assert_error_code(validate_iptw_data(bad_cov_chr, covariates = c("age", "comorbidity")),
                  "INVALID_COVARIATE_TYPE", "Rejects non-numeric covariate")

bad_cov_inf <- valid_iptw_df
bad_cov_inf$age[[1L]] <- Inf
assert_error_code(validate_iptw_data(bad_cov_inf, covariates = c("age", "comorbidity")),
                  "INVALID_COVARIATE_VALUE", "Rejects Inf covariate value")

cat("\n=== 2. Mathematical Exactness of IPTW Weights (ATE and ATT) ===\n")

# Hand-crafted small dataset for analytical verification
toy_df <- data.frame(
  treatment = c(1L, 1L, 0L, 0L),
  outcome = c(1L, 0L, 1L, 0L),
  x = c(1, 2, 3, 4)
)
toy_ps <- c(0.8, 0.6, 0.4, 0.2)
p_A1 <- 0.5
p_A0 <- 0.5

# Unstabilized ATE: w_i = 1/e (A=1), 1/(1-e) (A=0)
# T: 1/0.8 = 1.25, 1/0.6 = 1.666667
# C: 1/(1-0.4) = 1/0.6 = 1.666667, 1/(1-0.2) = 1/0.8 = 1.25
expected_w_ate_un <- c(1/0.8, 1/0.6, 1/0.6, 1/0.8)
w_ate_un <- compute_iptw_weights(toy_df$treatment, toy_ps, estimand = "ATE", stabilization = FALSE)
assert_true(isTRUE(all.equal(w_ate_un, expected_w_ate_un)), "Unstabilized ATE weights match exact analytical formulas")

# Stabilized ATE: sw_i = p(A=1)/e (A=1), p(A=0)/(1-e) (A=0)
expected_sw_ate <- c(0.5/0.8, 0.5/0.6, 0.5/0.6, 0.5/0.8)
sw_ate <- compute_iptw_weights(toy_df$treatment, toy_ps, estimand = "ATE", stabilization = TRUE)
assert_true(isTRUE(all.equal(sw_ate, expected_sw_ate)), "Stabilized ATE weights match exact analytical formulas")

# Unstabilized ATT: w_i = 1 (A=1), e/(1-e) (A=0)
# T: 1.0, 1.0
# C: 0.4 / 0.6 = 2/3, 0.2 / 0.8 = 0.25
expected_w_att_un <- c(1.0, 1.0, 0.4/0.6, 0.2/0.8)
w_att_un <- compute_iptw_weights(toy_df$treatment, toy_ps, estimand = "ATT", stabilization = FALSE)
assert_true(isTRUE(all.equal(w_att_un, expected_w_att_un)), "Unstabilized ATT weights match exact analytical formulas")

# Scaled ATT (marginal odds scaled): sw_i = 1 (A=1), (e/(1-e)) * (p_A1/p_A0)
# With p_A1/p_A0 = 1.0, equals unstabilized ATT
sw_att <- compute_iptw_weights(toy_df$treatment, toy_ps, estimand = "ATT", stabilization = TRUE, att_scaling_mode = "marginal_odds_scaled")
assert_true(isTRUE(all.equal(sw_att, expected_w_att_un)), "Marginal-odds scaled ATT weights match analytical formulas")

cat("\n=== 3. Mathematical Exactness of Kish ESS and Weighted Risks ===\n")

# For toy_df with w_ate_un:
# T: w = (1.25, 5/3), y = (1, 0)
# sum(w_T) = 1.25 + 5/3 = 15/12 + 20/12 = 35/12 ~ 2.916667
# sum(w_T * y_T) = 1.25 * 1 + (5/3) * 0 = 1.25
# p_target = 1.25 / (35/12) = (5/4) / (35/12) = 12/28 = 3/7 ~ 0.4285714
# C: w = (5/3, 1.25), y = (1, 0)
# sum(w_R) = 35/12
# sum(w_R * y_R) = (5/3) * 1 + 1.25 * 0 = 5/3
# p_reference = (5/3) / (35/12) = 20/35 = 4/7 ~ 0.5714286
# ESS_T: (35/12)^2 / (1.25^2 + (5/3)^2)
sum_w_T <- 35/12
sum_w2_T <- (5/4)^2 + (5/3)^2
expected_ess_T <- (sum_w_T^2) / sum_w2_T

risks_calc <- compute_iptw_weighted_risks(toy_df$outcome, toy_df$treatment, w_ate_un)
assert_true(isTRUE(all.equal(risks_calc$p_target, 3/7)), "Calculated p_target matches exact weighted expectation (3/7)")
assert_true(isTRUE(all.equal(risks_calc$p_reference, 4/7)), "Calculated p_reference matches exact weighted expectation (4/7)")
assert_true(isTRUE(all.equal(risks_calc$rd, 3/7 - 4/7)), "Calculated RD matches exact weighted RD (-1/7)")
assert_true(isTRUE(all.equal(risks_calc$target_ess, expected_ess_T)), "Calculated Kish ESS matches exact formula")

cat("\n=== 4. Weight Truncation (Arm-Specific Percentiles) ===\n")

t_flag <- c(rep(1L, 5), rep(0L, 5))
# Known arm-specific raw ATE weights: T=(1,2,10,20,40), R=(1,2,10,20,40).
known_ps <- c(1, 0.5, 0.1, 0.05, 0.025, 0, 0.5, 0.9, 0.95, 0.975)
w_trunc <- compute_iptw_weights(
  treatment = t_flag,
  ps = known_ps,
  truncation = c(0.10, 0.90)
)
expected_arm_truncated <- pmin(pmax(c(1, 2, 10, 20, 40), 1.4), 32)
assert_true(isTRUE(all.equal(w_trunc[t_flag == 1L], expected_arm_truncated)), "Treatment arm truncation matches exact 10th/90th percentile values")
assert_true(isTRUE(all.equal(w_trunc[t_flag == 0L], expected_arm_truncated)), "Reference arm truncation matches exact 10th/90th percentile values")
assert_true(isTRUE(all.equal(compute_iptw_weights(t_flag, known_ps, truncation = NULL), c(1, 2, 10, 20, 40, 1, 2, 10, 20, 40))), "Disabled truncation preserves exact raw weights")

cat("\n=== 5. In-Replicate PS Refitting Bootstrap and Convergence Monitoring ===\n")

res_ate <- run_iptw_inference(
  data = valid_iptw_df,
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = c("age", "comorbidity"),
  estimand = "ATE",
  stabilization = TRUE,
  num_draws = 500L,
  seed = 42L
)

assert_true(identical(res_ate$evidence$schema_version, "comparative-evidence-v1"), "Evidence schema version is comparative-evidence-v1")
assert_true(identical(res_ate$evidence$inferential_semantics, "bootstrap"), "Inferential semantics is bootstrap")
assert_true(identical(res_ate$evidence$risk_difference$estimate$source, "observed_sample_estimate"),
            "Estimate source is observed_sample_estimate")
assert_true(identical(res_ate$evidence$risk_difference$interval$method, "bootstrap_percentile"),
            "Interval method is bootstrap_percentile")
assert_true(identical(res_ate$evidence$iptw$estimand, "ATE"), "Recorded estimand is ATE")
assert_true(isTRUE(res_ate$evidence$iptw$stabilization), "Recorded stabilization is TRUE")
assert_true(res_ate$evidence$iptw$effective_sample_size$target > 0, "Target ESS > 0")
assert_true(res_ate$evidence$iptw$effective_sample_size$reference > 0, "Reference ESS > 0")
assert_true(res_ate$evidence$iptw$bootstrap_diagnostics$failed_replicates >= 0L, "Bootstrap failure count recorded")
assert_true(res_ate$evidence$iptw$bootstrap_diagnostics$failure_rate <= 0.05, "Failure rate within 5% tolerance")
assert_true(identical(res_ate$evidence$iptw$bootstrap_diagnostics$max_failure_rate, 0.05), "Configured bootstrap failure threshold is recorded")
assert_true(is.null(res_ate$evidence$target_cohort$events) && is.null(res_ate$evidence$target_cohort$total), "Weighted cohort omits raw count numerator and denominator")
assert_true(res_ate$evidence$iptw$raw_patient_counts$target_events == sum(treat == 1L & outcome == 1L), "Raw patient event count is preserved under iptw.raw_patient_counts")
assert_true(isTRUE(all.equal(res_ate$evidence$target_cohort$estimate$value, res_ate$draws$observed_sample_estimate$p_target)), "Target cohort estimate is the weighted marginal risk")
assert_true(!isTRUE(all.equal(res_ate$evidence$target_cohort$estimate$value, res_ate$evidence$iptw$raw_patient_counts$target_events / res_ate$evidence$iptw$raw_patient_counts$target)), "Weighted risk is distinguishable from raw event proportion")
assert_true(identical(res_ate$draws$iptw_metadata$iptw_mode, "refit_ps") && !is.null(res_ate$draws$iptw_metadata$propensity_model), "Draw metadata records PS refit mode and model")
assert_true(res_ate$draws$iptw_metadata$propensity_score_boundary_policy$clipped_low_count >= 0L, "Draw metadata records PS boundary clipping provenance")
assert_true(res_ate$evidence$iptw$positivity$raw_target_ps$min <= res_ate$evidence$iptw$positivity$target_ps$min, "Positivity output retains raw PS summaries alongside effective PS")
assert_true(identical(iptw_extreme_weight_badge(c(1, 1, 1, 1, 25)), "EXTREME_WEIGHTS_WARNING"), "Extreme weights emit the governed warning badge")

cat("\n=== 6. Covariate Balance (SMD) Scale Invariance and Diagnostics ===\n")

cov_bal <- res_ate$evidence$iptw$covariate_balance
assert_true(length(cov_bal) == 2L, "Covariate balance evaluated for both covariates")
assert_true(cov_bal[[1L]]$covariate == "age", "Covariate 1 is age")
assert_true(!is.null(cov_bal[[1L]]$unweighted$smd), "Unweighted SMD exists")
assert_true(!is.null(cov_bal[[1L]]$weighted$smd), "Weighted SMD exists")

# Scale invariance of weighted SMD
scales <- c(1e-12, 1.0, 1e12)
smd_scales <- vapply(scales, function(c_scale) {
  df_scaled <- valid_iptw_df
  df_scaled$age <- df_scaled$age * c_scale
  b_scaled <- compute_iptw_covariate_balance(
    data = df_scaled,
    treatment_col = "treatment",
    covariates = "age",
    weights = rep(1.0, nrow(df_scaled))
  )[[1L]]
  b_scaled$weighted$smd
}, numeric(1L))
assert_true(all(vapply(smd_scales, function(s) isTRUE(all.equal(s, smd_scales[[2L]], tolerance = 1e-10)), logical(1L))),
            "Weighted SMD is strictly scale-invariant across c = 1e-12 to 1e12")

cat("\n=== 7. ATT Estimand Execution ===\n")

res_att <- run_iptw_inference(
  data = valid_iptw_df,
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = c("age", "comorbidity"),
  estimand = "ATT",
  stabilization = TRUE,
  att_scaling_mode = "marginal_odds_scaled",
  num_draws = 500L,
  seed = 42L
)
assert_true(identical(res_att$evidence$iptw$estimand, "ATT"), "ATT estimand recorded in output")
assert_true(identical(res_att$evidence$iptw$att_scaling_mode, "marginal_odds_scaled"), "ATT scaling mode recorded")
assert_error_code(compute_iptw_weights(toy_df$treatment, toy_ps, estimand = "ATT", stabilization = TRUE, att_scaling_mode = "conventional"),
                  "INVALID_ATT_STABILIZATION", "Rejects ambiguous conventional ATT stabilization")

cat("\n=== 8. Task 10.12 Boundary Verification: Rejection of Non-Integer Pseudo-Counts ===\n")

# Verify that the independent Beta-Binomial engine strictly rejects non-integer weighted event counts
assert_error_code(
  run_independent_beta_binomial(
    target_events = 15.35, # non-integer pseudo count
    target_total = 100L,
    reference_events = 5L,
    reference_total = 100L
  ),
  "NON_INTEGER_COUNT",
  "Task 10.12: Independent Beta-Binomial engine rejects non-integer weighted event counts"
)

assert_error_code(
  run_independent_beta_binomial(
    target_events = 15L,
    target_total = 99.8, # non-integer pseudo total
    reference_events = 5L,
    reference_total = 100L
  ),
  "NON_INTEGER_COUNT",
  "Task 10.12: Independent Beta-Binomial engine rejects non-integer weighted total counts"
)

cat("\n=== 9. Seed Reproducibility and Invariant Verification ===\n")

res1 <- run_iptw_inference(valid_iptw_df, covariates = c("age", "comorbidity"), num_draws = 300L, seed = 999L, persist_raw_draws = TRUE)
res2 <- run_iptw_inference(valid_iptw_df, covariates = c("age", "comorbidity"), num_draws = 300L, seed = 999L, persist_raw_draws = TRUE)

assert_true(identical(res1$draws$target_draws, res2$draws$target_draws), "Identical seed produces identical target draws")
assert_true(identical(res1$draws$reference_draws, res2$draws$reference_draws), "Identical seed produces identical reference draws")
assert_true(identical(res1$evidence$risk_difference$interval, res2$evidence$risk_difference$interval),
            "Identical seed produces identical RD interval")

# Negative runtime argument checks
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", num_draws = 9L), "INVALID_ARGUMENT",
                  "Rejects num_draws < 10")
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", num_draws = Inf), "INVALID_ARGUMENT",
                  "Rejects Inf num_draws")
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", seed = Inf), "INVALID_ARGUMENT",
                  "Rejects Inf seed")
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", truncation = c(0.9, 0.1)), "INVALID_ARGUMENT",
                  "Rejects non-ascending truncation percentiles")
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", max_failure_rate = 1), "INVALID_ARGUMENT", "Rejects max_failure_rate >= 1")
assert_error_code(run_iptw_inference(valid_iptw_df, covariates = "age", ps_boundary = c(0, 0.99)), "INVALID_ARGUMENT", "Rejects PS boundary including zero")

sep_df <- data.frame(treatment = c(rep(0L, 10), rep(1L, 10)), x = c(rep(-1, 10), rep(1, 10)))
sep_ps <- estimate_propensity_scores(sep_df, covariates = "x")
assert_true(sep_ps$clipping$clipped_low_count + sep_ps$clipping$clipped_high_count > 0L, "Separation fixture exercises governed PS clipping")
assert_true(sep_ps$clipping$mode == "clamp" && sep_ps$clipping$lower == 1e-6, "PS clipping policy and boundary are explicit")
assert_true(sep_ps$clipping$clipped_low_count == sum(sep_ps$ps_raw < 1e-6) && sep_ps$clipping$clipped_high_count == sum(sep_ps$ps_raw > 1 - 1e-6), "Clipping metadata counts exactly match raw PS outside the boundaries")
assert_true(compute_ps_positivity_diagnostics(sep_df$treatment, sep_ps$ps, sep_ps$ps_raw)$common_support$has_overlap == FALSE,
            "No-overlap fixture reports raw propensity score non-overlap")
boot_clip <- sample_iptw_bootstrap(valid_iptw_df, covariates = c("age", "comorbidity"), ps_boundary = c(0.49, 0.51),
  num_draws = 40L, seed = 19L, max_failure_rate = 0.5)
clip_diag <- boot_clip$bootstrap_clipping_diagnostics
assert_true(clip_diag$replicates_with_any_clipping > 0L, "Bootstrap PS refits record replicates with clipping")
assert_true(clip_diag$total_clipped_low + clip_diag$total_clipped_high > 0L, "Bootstrap PS clipping totals are nonzero under near-boundary policy")
assert_true(clip_diag$max_clipped_fraction <= 1 && clip_diag$max_clipped_fraction > 0, "Bootstrap maximum clipped fraction is bounded and exercised")
rare_arm_df <- data.frame(treatment = c(rep(1L, 8L), rep(0L, 2L)), outcome = c(rep(0L, 10L)), x = seq_len(10L))
assert_error_code(sample_iptw_bootstrap(rare_arm_df, covariates = "x", num_draws = 10L, seed = 62L, max_failure_rate = 0),
                  "IPTW_CONVERGENCE_FAILURE", "Custom zero failure threshold fails fast when a bootstrap replicate loses an arm")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
