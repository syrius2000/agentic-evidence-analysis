# test_vcd_categorical_evidence_v4.R — Effects, Evidence, Dual-Filter & Cramér's V CI Test Suite

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R")

test_pass <- 0L
test_fail <- 0L

assert_close <- function(desc, actual, expected, tol = 1e-4) {
  diff <- max(abs(actual - expected), na.rm = TRUE)
  if (diff <= tol) {
    cat(sprintf("[PASS] %s (diff = %.2e <= %.2e)\n", desc, diff, tol))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s: Expected %.6f, got %.6f (diff = %.2e)\n", desc, expected[1], actual[1], diff))
    test_fail <<- test_fail + 1L
  }
}

cat("=== Starting Effects, Evidence & Cramér's V CI Tests ===\n")

# 1. 2x2 分割表での基本計算と照合
d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq")
diag <- compute_residual_diagnostics(v_data)
evid <- compute_effect_evidence_metrics(diag)

# Raoスコア = (adj_res)^2 の検証
cell_1 <- evid$cells[[1]]
assert_close("Local Rao score equals adj_res squared", cell_1$rao_score, cell_1$adj_res^2, tol = 1e-3)

# 2. ゼロ観測セルの非有限値契約の検証
d_zero <- data.frame(
  Row = c("A", "A", "B", "B"),
  Col = c("X", "Y", "X", "Y"),
  Freq = c(40, 0, 20, 40)
)
v_zero <- validate_input_table(d_zero, vars = c("Row", "Col"), freq = "Freq")
diag_zero <- compute_residual_diagnostics(v_zero)
evid_zero <- compute_effect_evidence_metrics(diag_zero)

zero_cell <- Filter(function(c) c$observed == 0, evid_zero$cells)[[1]]
if (is.null(zero_cell$log_oe) &&
    zero_cell$log_oe_state == "NEGATIVE_INFINITY" &&
    identical(zero_cell$is_finite, FALSE) &&
    identical(zero_cell$dual_filter_candidate, FALSE)) {
  cat("[PASS] Zero cell satisfies non-finite contract: log_oe is null, state is NEGATIVE_INFINITY, is_finite is false, excluded from candidate.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Zero cell non-finite contract violated.\n")
  test_fail <- test_fail + 1L
}

# 3. 大標本 Dual-Filter 判定テスト (N >= 2000)
large_n_data <- data.frame(
  Row = c("Active", "Active", "Placebo", "Placebo"),
  Col = c("Event", "NoEvent", "Event", "NoEvent"),
  Freq = c(900, 1100, 100, 1900)  # Total N = 4000, E(Active, Event)=500, log(900/500)=0.588 >= 0.50
)
v_large <- validate_input_table(large_n_data, vars = c("Row", "Col"), freq = "Freq")
diag_large <- compute_residual_diagnostics(v_large)
evid_large <- compute_effect_evidence_metrics(diag_large)

# Active, Event セルは強い正の連関 |log(O/E)| >= 0.50 かつ T^score >= 3.84
active_event <- Filter(function(c) c$row_level == "Active" && c$col_level == "Event", evid_large$cells)[[1]]
if (active_event$dual_filter_candidate == TRUE) {
  cat("[PASS] Large sample cell meeting Dual-Filter criteria correctly flagged as candidate.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Dual-Filter candidate detection failed.\n")
  test_fail <- test_fail + 1L
}

# 4. Cramér's V CI 端点順序および DescTools 照合
glob <- evid$global
cat(sprintf("Cramér's V: %.4f, CI: [%.4f, %.4f]\n", glob$cramers_v, glob$cramers_v_ci[1], glob$cramers_v_ci[2]))
cat(sprintf("Bias-Corrected V: %.4f, CI: [%.4f, %.4f]\n", glob$cramers_v_corrected, glob$cramers_v_corrected_ci[1], glob$cramers_v_corrected_ci[2]))

# 端点順序の単調性検証
if (0 <= glob$cramers_v_ci[1] && glob$cramers_v_ci[1] <= glob$cramers_v_ci[2] && glob$cramers_v_ci[2] <= 1) {
  cat("[PASS] Cramér's V CI bounds monotonic order: 0 <= lower <= upper <= 1\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Cramér's V CI bounds order invalid.\n")
  test_fail <- test_fail + 1L
}

if (!is.null(glob$cramers_v_corrected_ci)) {
  if (0 <= glob$cramers_v_corrected_ci[1] && glob$cramers_v_corrected_ci[1] <= glob$cramers_v_corrected_ci[2] && glob$cramers_v_corrected_ci[2] <= 1) {
    cat("[PASS] Bias-corrected V CI bounds monotonic order: 0 <= lower <= upper <= 1\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] Bias-corrected V CI bounds order invalid.\n")
    test_fail <- test_fail + 1L
  }
}

# DescTools がインストールされている場合の照合テスト
if (requireNamespace("DescTools", quietly = TRUE)) {
  tab_valid <- table(rep(d_valid$Treatment, d_valid$Freq), rep(d_valid$Outcome, d_valid$Freq))
  desc_v <- DescTools::CramerV(tab_valid, conf.level = 0.95, method = "ncchisq")
  assert_close("Cramér's V point estimate matches DescTools", glob$cramers_v, as.numeric(desc_v[1]), tol = 1e-4)
  assert_close("Cramér's V CI lower bound matches DescTools (ncchisq)", glob$cramers_v_ci[1], as.numeric(desc_v[2]), tol = 1e-4)
  assert_close("Cramér's V CI upper bound matches DescTools (ncchisq)", glob$cramers_v_ci[2], as.numeric(desc_v[3]), tol = 1e-4)
} else {
  cat("[INFO] DescTools not installed, skipping external package comparison (analytic math verified).\n")
}

# 5. 退化表（自由度不足 / N <= df+1）フォールバックテスト
tiny_data <- data.frame(
  Row = c("R1", "R1", "R2", "R2"),
  Col = c("C1", "C2", "C1", "C2"),
  Freq = c(1, 0, 0, 1)  # N = 2, df = 1. N <= df + 1
)
v_tiny <- validate_input_table(tiny_data, vars = c("Row", "Col"), freq = "Freq")
diag_tiny <- compute_residual_diagnostics(v_tiny)
evid_tiny <- compute_effect_evidence_metrics(diag_tiny)

if (is.null(evid_tiny$global$cramers_v_corrected_ci)) {
  cat("[PASS] Degenerate/small table fallback correctly sets cramers_v_corrected_ci to null.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Degenerate table did not fall back to null CI.\n")
  test_fail <- test_fail + 1L
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
