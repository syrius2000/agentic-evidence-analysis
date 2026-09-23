# tests/test_independent_beta_binomial.R — Independent Beta-Binomial Engine Test Suite
# Tests Tasks 3.1 through 3.14 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/independent_beta_binomial.R")

cat("=== 1. Test Input Guard Assertions ===\n")
assert_error_code(
  run_independent_beta_binomial(-1, 100, 5, 100),
  "NEGATIVE_COUNT",
  "Rejects negative event count"
)
assert_error_code(
  run_independent_beta_binomial(5, 0, 5, 100),
  "EMPTY_DENOMINATOR",
  "Rejects zero denominator"
)
assert_error_code(
  run_independent_beta_binomial(105, 100, 5, 100),
  "BOUNDS_EXCEEDED",
  "Rejects event count exceeding total"
)
assert_error_code(
  run_independent_beta_binomial(5.5, 100, 5, 100),
  "NON_INTEGER_COUNT",
  "Rejects non-integer count"
)

cat("\n=== 2. Test Deterministic Reproducibility with Seed ===\n")
run1 <- run_independent_beta_binomial(15, 100, 5, 100, seed = 12345L, primary_delta = 0.05)
run2 <- run_independent_beta_binomial(15, 100, 5, 100, seed = 12345L, primary_delta = 0.05)
assert_true(
  identical(run1$evidence$risk_difference$estimate$value, run2$evidence$risk_difference$estimate$value),
  "Exact point estimate equality across identical seeds"
)
assert_true(
  identical(run1$evidence$risk_difference$interval$lower, run2$evidence$risk_difference$interval$lower),
  "Exact lower interval bound equality across identical seeds"
)

cat("\n=== 3. Golden Regression Cases (7 Benchmarks with Numerical Tolerances) ===\n")
# Case 1: 3/100 vs 0/100 (zero-ref)
c1 <- run_independent_beta_binomial(3, 100, 0, 100, seed = 42L, primary_delta = 0.02)
ev1 <- c1$evidence
assert_true(is.null(ev1$relative_risk$mean), "Case 1: RR mean is NULL for zero-ref")
assert_true(ev1$relative_risk$mean_is_finite == FALSE, "Case 1: RR mean_is_finite is FALSE")
assert_true("ZERO_REFERENCE" %in% ev1$diagnostics$badges, "Case 1: ZERO_REFERENCE badge present")
assert_true(abs(ev1$risk_difference$estimate$value - 0.029) < 0.008, "Case 1: RD median ~ 0.029 within tolerance")
assert_true(ev1$direction_support$support_value > 0.95, "Case 1: P(RD > 0) > 0.95")
assert_true(ev1$relative_risk$estimate$value > 5.0, "Case 1: RR median > 5.0")

# Case 2: 0/100 vs 0/100 (both-zero)
c2 <- run_independent_beta_binomial(0, 100, 0, 100, seed = 42L, primary_delta = 0.02)
ev2 <- c2$evidence
assert_true("ZERO_BOTH" %in% ev2$diagnostics$badges, "Case 2: ZERO_BOTH badge present")
assert_true(abs(ev2$risk_difference$estimate$value) < 0.005, "Case 2: RD median ~ 0.000 within tolerance")
assert_true(abs(ev2$direction_support$support_value - 0.50) < 0.05, "Case 2: P(RD > 0) ~ 0.50 within tolerance")

# Case 3: 30/100 vs 20/100 (balanced)
c3 <- run_independent_beta_binomial(30, 100, 20, 100, seed = 42L, primary_delta = 0.05)
ev3 <- c3$evidence
assert_true(abs(ev3$risk_difference$estimate$value - 0.10) < 0.015, "Case 3: RD median ~ 0.10 within tolerance")
assert_true(abs(ev3$relative_risk$estimate$value - 1.48) < 0.15, "Case 3: RR median ~ 1.48 within tolerance")
assert_true(ev3$direction_support$support_value > 0.90, "Case 3: P(RD > 0) > 0.90")

# Case 4: 3/30 vs 30/300 (equal prop 10%)
c4 <- run_independent_beta_binomial(3, 30, 30, 300, seed = 42L, primary_delta = 0.05)
ev4 <- c4$evidence
assert_true(abs(ev4$risk_difference$estimate$value - 0.005) < 0.020, "Case 4: RD median ~ 0.005 within tolerance")
assert_true(abs(ev4$relative_risk$estimate$value - 1.05) < 0.20, "Case 4: RR median ~ 1.05 within tolerance")

# Case 5: 1/200 vs 0/1000 (rare zero-ref)
c5 <- run_independent_beta_binomial(1, 200, 0, 1000, seed = 42L, primary_delta = 0.005)
ev5 <- c5$evidence
assert_true("ZERO_REFERENCE" %in% ev5$diagnostics$badges, "Case 5: ZERO_REFERENCE badge present")
assert_true(abs(ev5$risk_difference$estimate$value - 0.006) < 0.004, "Case 5: RD median ~ 0.006 within tolerance")
assert_true(ev5$direction_support$support_value > 0.93, "Case 5: P(RD > 0) > 0.93")

# Case 6: 1/200 vs 2/1000 (rare unbalanced: 0.5% vs 0.2%)
c6 <- run_independent_beta_binomial(1, 200, 2, 1000, seed = 42L, primary_delta = 0.005)
ev6 <- c6$evidence
assert_true(abs(ev6$risk_difference$estimate$value - 0.005) < 0.005, "Case 6: RD median ~ 0.005 within tolerance")
assert_true(ev6$relative_risk$estimate$value > 1.5, "Case 6: RR median > 1.5")

# Case 7: 0/200 vs 2/1000 (target zero)
c7 <- run_independent_beta_binomial(0, 200, 2, 1000, seed = 42L, primary_delta = 0.005)
ev7 <- c7$evidence
assert_true(ev7$risk_difference$estimate$value < 0.0, "Case 7: RD median is negative")
assert_true(abs(ev7$direction_support$support_value - 0.367) < 0.02, "Case 7: P(RD > 0) ~ 0.367 within tolerance")

cat("\n=== 4. Test Prior Sensitivity Trigger Modes & Continuous Delta Metrics ===\n")
# Case with zero events: zero_cell mode should evaluate
sens_res_zero <- run_independent_beta_binomial(3, 100, 0, 100, prior_sensitivity_mode = "zero_cell")
assert_true(sens_res_zero$evidence$diagnostics$prior_sensitivity$evaluated == TRUE,
            "zero_cell mode evaluates sensitivity when zero reference count is present")
assert_true(!is.null(sens_res_zero$evidence$diagnostics$prior_sensitivity$comparison$rd_median_delta),
            "prior_sensitivity records continuous rd_median_delta")
assert_true(!is.null(sens_res_zero$evidence$diagnostics$prior_sensitivity$comparison$direction_support_delta),
            "prior_sensitivity records continuous direction_support_delta")

# Case with non-zero events: zero_cell mode should NOT evaluate
sens_res_nonzero <- run_independent_beta_binomial(15, 100, 5, 100, prior_sensitivity_mode = "zero_cell")
assert_true(sens_res_nonzero$evidence$diagnostics$prior_sensitivity$evaluated == FALSE,
            "zero_cell mode does not evaluate sensitivity when all counts > 0")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
