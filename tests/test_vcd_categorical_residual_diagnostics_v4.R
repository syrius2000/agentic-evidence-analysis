# test_vcd_categorical_residual_diagnostics_v4.R — Residual Diagnostics & Quarantine Test Suite

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")

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

cat("=== Starting Residual Diagnostics Tests ===\n")

# 1. 2x2 分割表での理論値・Haberman残差比較
d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq")
diag <- compute_residual_diagnostics(v_data)

# R標準の chisq.test
tab <- diag$table
std_chisq <- stats::chisq.test(tab, correct = FALSE)

# Pearson カイ二乗値の照合
assert_close("Total Pearson Chi-Square matches chisq.test", diag$global$pearson_chisq, as.numeric(std_chisq$statistic))

# 期待度数の照合
raw_expected <- as.vector(std_chisq$expected)
calc_expected <- sapply(diag$cells, function(c) c$expected_raw)
# 並び順を考慮して一致確認
assert_close("Sum of Expected counts matches total N", sum(calc_expected), sum(raw_expected))

# Haberman 調整残差と chisq.test$stdres の照合
stdres_vec <- as.vector(std_chisq$stdres)
adj_res_vec <- sapply(diag$cells, function(c) c$adj_res_raw)
assert_close("Adjusted residuals match Haberman standardized residuals", sort(abs(adj_res_vec)), sort(abs(stdres_vec)), tol = 1e-5)

# 2. ゼロ観測セル（Quarantine ZERO_OBSERVED）のテスト
zero_cell_data <- data.frame(
  Row = c("A", "A", "B", "B"),
  Col = c("X", "Y", "X", "Y"),
  Freq = c(30, 0, 20, 50)
)
v_zero <- validate_input_table(zero_cell_data, vars = c("Row", "Col"), freq = "Freq")
diag_zero <- compute_residual_diagnostics(v_zero)

# O=0 のセルを探す
zero_cells <- Filter(function(c) c$observed == 0, diag_zero$cells)
if (length(zero_cells) == 1) {
  zc <- zero_cells[[1]]
  if (zc$quarantine_status == "QUARANTINED" && "ZERO_OBSERVED" %in% zc$quarantine_reasons) {
    cat("[PASS] Zero cell is correctly QUARANTINED with reason 'ZERO_OBSERVED'.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] Zero cell quarantine status incorrect.\n")
    test_fail <- test_fail + 1L
  }
  # Deviance残差の確認: -sqrt(2E)
  expected_r_d <- -sqrt(2 * zc$expected_raw)
  assert_close("Zero cell Deviance residual equals -sqrt(2E)", zc$deviance_res, expected_r_d, tol = 1e-3)
} else {
  cat("[FAIL] Zero cell not found in diagnostics.\n")
  test_fail <- test_fail + 1L
}

# 3. 期待度数 < 5 の Quarantine (EXPECTED_LT_5) テスト
sparse_data <- data.frame(
  Row = c("A", "A", "B", "B"),
  Col = c("X", "Y", "X", "Y"),
  Freq = c(2, 50, 1, 50)
)
v_sparse <- validate_input_table(sparse_data, vars = c("Row", "Col"), freq = "Freq")
diag_sparse <- compute_residual_diagnostics(v_sparse)

sparse_cells <- Filter(function(c) c$expected_raw < 5.0, diag_sparse$cells)
if (length(sparse_cells) > 0 && all(sapply(sparse_cells, function(c) "EXPECTED_LT_5" %in% c$quarantine_reasons))) {
  cat("[PASS] Low expected count cells correctly flagged with 'EXPECTED_LT_5'.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Low expected count quarantine failed.\n")
  test_fail <- test_fail + 1L
}

# 4. 高 Leverage (h >= 0.80) の判定テスト
high_lev_data <- data.frame(
  Row = c("Dominant", "Dominant", "Minor", "Minor"),
  Col = c("Dominant", "Minor", "Dominant", "Minor"),
  Freq = c(950, 20, 25, 5)
)
v_hlev <- validate_input_table(high_lev_data, vars = c("Row", "Col"), freq = "Freq")
diag_hlev <- compute_residual_diagnostics(v_hlev)

hlev_cells <- Filter(function(c) c$leverage_raw >= 0.80, diag_hlev$cells)
if (length(hlev_cells) > 0 && all(sapply(hlev_cells, function(c) "HIGH_LEVERAGE" %in% c$quarantine_reasons))) {
  cat("[PASS] High leverage cells (h >= 0.80) correctly flagged with 'HIGH_LEVERAGE'.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] High leverage quarantine failed.\n")
  test_fail <- test_fail + 1L
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
