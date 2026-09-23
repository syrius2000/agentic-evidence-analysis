# tests/test_comparative_schemas.R — Test suite for comparative schemas and contrast engine
# Tests Tasks 2.1 through 2.14 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/comparative_contrasts.R")

cat("=== 1. Test Bayesian Posterior Semantics & Point Estimates ===\n")
set.seed(42)
S <- 2000L
t_draws <- rbeta(S, 15 + 0.5, 85 + 0.5)
r_draws <- rbeta(S, 5 + 0.5, 95 + 0.5)

bayes_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = 0.05
)

assert_true(bayes_res$schema_version == "comparative-evidence-v1", "Schema version is comparative-evidence-v1")
assert_true(bayes_res$inferential_semantics == "posterior", "Inferential semantics is posterior")
assert_true(bayes_res$risk_difference$estimate$source == "posterior_median", "RD estimate source is posterior_median")
assert_true(bayes_res$risk_difference$interval$method == "posterior_eti", "RD interval method is posterior_eti")
assert_true(bayes_res$direction_support$label == "P(RD > 0)", "Direction support label is P(RD > 0)")
assert_true(bayes_res$relative_risk$estimate$source == "posterior_median", "RR estimate source is posterior_median")
assert_true(bayes_res$relative_risk$interval$method == "posterior_eti", "RR interval method is posterior_eti")
assert_true(bayes_res$relative_risk$mean_is_finite == TRUE, "RR mean is finite when reference events > 0")

cat("\n=== 2. Test Bootstrap Semantics & Point Estimates ===\n")
boot_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "bootstrap",
  observed_estimates = list(rd = 0.10, rr = 3.0),
  primary_delta = 0.05
)

assert_true(boot_res$inferential_semantics == "bootstrap", "Inferential semantics is bootstrap")
assert_true(boot_res$risk_difference$estimate$source == "observed_sample_estimate", "RD estimate source is observed_sample_estimate")
assert_true(boot_res$risk_difference$estimate$value == 0.10, "RD estimate value matches observed estimate (0.10)")
assert_true(boot_res$risk_difference$interval$method == "bootstrap_percentile", "RD interval method is bootstrap_percentile")
assert_true(boot_res$direction_support$metric_name == "bootstrap_support_fraction_rd_gt_zero", "Metric name is bootstrap_support_fraction_rd_gt_zero")

cat("\n=== 3. Test Practical Region Invariant (q_T + q_N + q_R == 1.0) & U-Grade ===\n")
prs <- bayes_res$practical_region_support
assert_true(!is.null(prs), "Practical region support exists when primary_delta is set")
sum_q <- prs$target_excess + prs$practical_neutral + prs$reference_excess
assert_true(abs(sum_q - 1.0) < 1e-6, sprintf("Invariant holds: sum(q) = %.6f == 1.0", sum_q))
assert_true(bayes_res$resolution_grade$grade %in% c("U0", "U1", "U2", "U3"), "U-grade is within U0-U3")

cat("\n=== 4. Test primary_delta = NULL (mode: 'none') Disables Classification ===\n")
none_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = NULL
)
assert_true(is.null(none_res$practical_region_support), "practical_region_support is NULL when primary_delta=NULL")
assert_true(none_res$resolution_grade$grade == "NONE", "resolution_grade is NONE when primary_delta=NULL")

cat("\n=== 5. Test Zero-Reference Mathematical Integrity (mean = NULL, finite = FALSE) ===\n")
r_zero_draws <- rbeta(S, 0 + 0.5, 100 + 0.5)
zero_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_zero_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 0L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = 0.05
)

assert_true(is.null(zero_res$relative_risk$mean), "RR mean is NULL for zero-reference")
assert_true(zero_res$relative_risk$mean_is_finite == FALSE, "RR mean_is_finite is FALSE for zero-reference")
assert_true(!is.null(zero_res$relative_risk$estimate$value), "RR median exists and is non-null for zero-reference")
assert_true(!is.null(zero_res$relative_risk$interval$lower), "RR lower interval bound exists for zero-reference")
assert_true(!is.null(zero_res$relative_risk$interval$upper), "RR upper interval bound exists for zero-reference")
assert_true("ZERO_REFERENCE" %in% zero_res$diagnostics$badges, "'ZERO_REFERENCE' badge present")

cat("\n=== 6. Test Delta-Profile Monotonicity ===\n")
# As delta increases, neutral region [-delta, delta] probability must be monotonically non-decreasing
dp <- bayes_res$delta_profile
assert_true(length(dp) >= 3, "Delta profile has >= 3 thresholds")
neu_probs <- vapply(dp, function(x) x$p_neutral, numeric(1L))
is_monotone <- all(diff(neu_probs) >= -1e-6)
assert_true(is_monotone, "p_neutral is monotonically non-decreasing as delta increases")

cat("\n=== 7. Test Terminology Separation & Lint Guard ===\n")
bayes_json <- jsonlite::toJSON(bayes_res, auto_unbox = TRUE)
boot_json <- jsonlite::toJSON(boot_res, auto_unbox = TRUE)

assert_true(!grepl("bootstrap_percentile", bayes_json), "Bayesian output contains NO 'bootstrap_percentile'")
assert_true(!grepl("bootstrap_support_fraction", bayes_json), "Bayesian output contains NO 'bootstrap_support_fraction'")
assert_true(!grepl("posterior_eti", boot_json), "Bootstrap output contains NO 'posterior_eti'")
assert_true(!grepl("posterior_median", boot_json), "Bootstrap output contains NO 'posterior_median'")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
