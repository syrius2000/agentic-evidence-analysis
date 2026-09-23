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

cat("\n=== 3. Golden Regression Cases (7 Benchmarks) ===\n")
golden_cases <- list(
  list(name = "Case 1: 3/100 vs 0/100 (zero-ref)", xT = 3, nT = 100, xR = 0, nR = 100, expect_zero_ref = TRUE),
  list(name = "Case 2: 0/100 vs 0/100 (both-zero)", xT = 0, nT = 100, xR = 0, nR = 100, expect_both_zero = TRUE),
  list(name = "Case 3: 30/100 vs 20/100 (balanced)", xT = 30, nT = 100, xR = 20, nR = 100, expect_zero_ref = FALSE),
  list(name = "Case 4: 3/30 vs 30/300 (equal prop 10%)", xT = 3, nT = 30, xR = 30, nR = 300, expect_zero_ref = FALSE),
  list(name = "Case 5: 1/200 vs 0/1000 (rare zero-ref)", xT = 1, nT = 200, xR = 0, nR = 1000, expect_zero_ref = TRUE),
  list(name = "Case 6: 1/200 vs 2/1000 (rare unbalanced)", xT = 1, nT = 200, xR = 2, nR = 1000, expect_zero_ref = FALSE),
  list(name = "Case 7: 0/200 vs 2/1000 (target zero)", xT = 0, nT = 200, xR = 2, nR = 1000, expect_zero_ref = FALSE)
)

for (gc in golden_cases) {
  res <- run_independent_beta_binomial(gc$xT, gc$nT, gc$xR, gc$nR, seed = 42L, primary_delta = 0.05)
  ev <- res$evidence

  # Assert finite RD estimates
  assert_true(is.numeric(ev$risk_difference$estimate$value) && is.finite(ev$risk_difference$estimate$value),
              sprintf("%s: RD median is finite", gc$name))

  # Assert Zero-Ref behavior
  if (isTRUE(gc$expect_zero_ref)) {
    assert_true(is.null(ev$relative_risk$mean), sprintf("%s: RR mean is NULL", gc$name))
    assert_true(ev$relative_risk$mean_is_finite == FALSE, sprintf("%s: RR mean_is_finite is FALSE", gc$name))
    assert_true("ZERO_REFERENCE" %in% ev$diagnostics$badges, sprintf("%s: ZERO_REFERENCE badge present", gc$name))
  }

  # Assert Both-Zero behavior
  if (isTRUE(gc$expect_both_zero)) {
    assert_true("ZERO_BOTH" %in% ev$diagnostics$badges, sprintf("%s: ZERO_BOTH badge present", gc$name))
  }
}

cat("\n=== 4. Test Prior Sensitivity Trigger Modes ===\n")
# Case with zero events: zero_cell mode should evaluate
sens_res_zero <- run_independent_beta_binomial(3, 100, 0, 100, prior_sensitivity_mode = "zero_cell")
assert_true(sens_res_zero$evidence$diagnostics$prior_sensitivity$evaluated == TRUE,
            "zero_cell mode evaluates sensitivity when zero reference count is present")

# Case with non-zero events: zero_cell mode should NOT evaluate
sens_res_nonzero <- run_independent_beta_binomial(15, 100, 5, 100, prior_sensitivity_mode = "zero_cell")
assert_true(sens_res_nonzero$evidence$diagnostics$prior_sensitivity$evaluated == FALSE,
            "zero_cell mode does not evaluate sensitivity when all counts > 0")

# explicit mode should always evaluate
sens_res_explicit <- run_independent_beta_binomial(15, 100, 5, 100, prior_sensitivity_mode = "explicit")
assert_true(sens_res_explicit$evidence$diagnostics$prior_sensitivity$evaluated == TRUE,
            "explicit mode evaluates sensitivity regardless of counts")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
