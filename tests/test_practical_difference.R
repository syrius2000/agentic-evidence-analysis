# tests/test_practical_difference.R — Practical Difference and U-Grade Policy Test Suite
# Tests Tasks 7.1 through 7.8 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/practical_difference_policy.R")

cat("=== 1. Test Natural Unit Conversions ===\n")
assert_true(abs(normalize_delta_value(2.5, "per_100") - 0.025) < 1e-8, "2.5 per 100 converts to 0.025")
assert_true(abs(normalize_delta_value(15, "per_1000") - 0.015) < 1e-8, "15 per 1000 converts to 0.015")
assert_true(abs(normalize_delta_value(0.04, "proportion") - 0.04) < 1e-8, "0.04 proportion remains 0.04")
assert_true(is.null(normalize_delta_value(NULL)), "NULL returns NULL")

cat("\n=== 2. Test Departmental Policy Loader ===\n")
pol <- get_departmental_delta_policy("v1", "safety")
assert_true(pol$policy_version == "v1", "Policy version is v1")
assert_true(pol$default_mode == "none", "Default mode is none")
assert_true(pol$recommended_deltas$mild$prop == 0.01, "Mild delta recommendation is 0.01")
assert_true(grepl("decisiveness", pol$u_grade_semantics, fixed = TRUE), "U-grade semantics clarifies region decisiveness")
assert_true(grepl("NOT indicate sample size", pol$u_grade_semantics, fixed = TRUE), "Explicitly disclaims sample size adequacy")

cat("\n=== 3. Test Delta Profile Persistence When primary_delta is NULL ===\n")
set.seed(42)
t_draws <- rbeta(500, 10 + 0.5, 90 + 0.5)
r_draws <- rbeta(500, 5 + 0.5, 95 + 0.5)

res_none <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 10,
  target_total = 100,
  reference_events = 5,
  reference_total = 100,
  primary_delta = NULL,
  delta_thresholds = c(0.01, 0.02, 0.05)
)

assert_true(is.null(res_none$practical_region_support), "practical_region_support is NULL")
assert_true(res_none$resolution_grade$grade == "NONE", "resolution_grade is NONE")
assert_true(length(res_none$delta_profile) == 3, "delta_profile is computed and preserved with 3 thresholds")

cat("\n=== 4. Test U-Grade Operating Characteristics Simulation Utility ===\n")
sim_out <- simulate_u_grade_operating_characteristics(
  n_cohort = c(50, 200),
  base_rate_reference = 0.05,
  true_risk_differences = c(0.0, 0.05),
  primary_delta = 0.02,
  num_simulations = 10L,
  num_draws = 200L,
  seed = 42L
)
assert_true(length(sim_out) == 4, "Simulation returned 4 parameter conditions")
assert_true(all(c("U0", "U1", "U2", "U3") %in% names(sim_out[[1L]]$grade_proportions)), "All U-grades present in distribution")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
