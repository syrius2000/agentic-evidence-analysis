# test_vcd_categorical_input_validation.R — Boundary & Fail-Fast Validation Test Suite

suppressPackageStartupMessages({
  library(jsonlite)
})

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")

test_pass <- 0L
test_fail <- 0L

assert_error_code <- function(desc, expr, expected_code) {
  res <- tryCatch({
    expr
    list(success = TRUE, err = NULL)
  }, error = function(e) {
    list(success = FALSE, err = e$message)
  })
  if (res$success) {
    cat(sprintf("[FAIL] %s: Expected error '%s', but succeeded.\n", desc, expected_code))
    test_fail <<- test_fail + 1L
  } else {
    if (grepl(expected_code, res$err, fixed = TRUE)) {
      cat(sprintf("[PASS] %s (caught %s)\n", desc, expected_code))
      test_pass <<- test_pass + 1L
    } else {
      cat(sprintf("[FAIL] %s: Expected error '%s', got '%s'\n", desc, expected_code, res$err))
      test_fail <<- test_fail + 1L
    }
  }
}

cat("=== Starting Input Validation Tests ===\n")

# 1. 正常系: 2-way
d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
res_valid <- tryCatch({
  validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq")
}, error = function(e) e)
if (is.data.frame(res_valid) && nrow(res_valid) == 4 && sum(res_valid$Freq) == 100) {
  cat("[PASS] Valid 2-way contingency table accepted.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Valid 2-way failed.\n")
  test_fail <- test_fail + 1L
}

# 2. 異常系: 3-way (Arity = 3)
d_3way <- read.csv("fixtures/input_validation/invalid_3way.csv")
assert_error_code(
  "3-way input rejection with delegation guidance",
  validate_input_table(d_3way, vars = c("Treatment", "Outcome", "Subgroup"), freq = "Freq"),
  "INVALID_INPUT_ARITY"
)

# 3. 異常系: 単一水準
d_single <- read.csv("fixtures/input_validation/invalid_single_level.csv")
assert_error_code(
  "Single level input rejection",
  validate_input_table(d_single, vars = c("Treatment", "Outcome"), freq = "Freq"),
  "INSUFFICIENT_LEVELS"
)

# 4. 異常系: 総度数 0
d_zero <- read.csv("fixtures/input_validation/invalid_zero_total.csv")
assert_error_code(
  "Zero total count input rejection",
  validate_input_table(d_zero, vars = c("Treatment", "Outcome"), freq = "Freq"),
  "ZERO_TOTAL_COUNT"
)

# 5. 異常系: 負の度数
d_neg <- read.csv("fixtures/input_validation/invalid_negative_count.csv")
assert_error_code(
  "Negative count input rejection",
  validate_input_table(d_neg, vars = c("Treatment", "Outcome"), freq = "Freq"),
  "NEGATIVE_COUNT_DETECTED"
)

# 6. 異常系: 非整数度数
d_nonint <- read.csv("fixtures/input_validation/invalid_non_integer_count.csv")
assert_error_code(
  "Non-integer count input rejection",
  validate_input_table(d_nonint, vars = c("Treatment", "Outcome"), freq = "Freq"),
  "NON_INTEGER_COUNTS"
)

# 7. 異常系: 構造的ゼロ入力
d_sz <- read.csv("fixtures/input_validation/invalid_structural_zero.csv")
assert_error_code(
  "Structural zero input rejection",
  validate_input_table(d_sz, vars = c("Treatment", "Outcome"), freq = "Freq"),
  "STRUCTURAL_ZERO_NOT_SUPPORTED"
)

# 8. run_state.json への failure 記録検証
temp_run <- tempfile(pattern = "run_test_")
dir.create(temp_run)
tryCatch({
  validate_input_table(d_sz, vars = c("Treatment", "Outcome"), freq = "Freq", run_dir = temp_run)
}, error = function(e) {})
state_file <- file.path(temp_run, "run_state.json")
if (file.exists(state_file)) {
  st <- jsonlite::fromJSON(state_file)
  if (st$status == "failed" && st$error_code == "STRUCTURAL_ZERO_NOT_SUPPORTED") {
    cat("[PASS] run_state.json correctly recorded failure status and error_code.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] run_state.json contents incorrect.\n")
    test_fail <- test_fail + 1L
  }
} else {
  cat("[FAIL] run_state.json not created on failure.\n")
  test_fail <- test_fail + 1L
}
unlink(temp_run, recursive = TRUE)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
