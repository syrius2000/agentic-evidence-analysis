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
  validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated")
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
  validate_input_table(d_3way, vars = c("Treatment", "Outcome", "Subgroup"), freq = "Freq", input_mode = "aggregated"),
  "INVALID_INPUT_ARITY"
)

# 3. 異常系: 単一水準
d_single <- read.csv("fixtures/input_validation/invalid_single_level.csv")
assert_error_code(
  "Single level input rejection",
  validate_input_table(d_single, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated"),
  "INSUFFICIENT_LEVELS"
)

# 4. 異常系: 総度数 0
d_zero <- read.csv("fixtures/input_validation/invalid_zero_total.csv")
assert_error_code(
  "Zero total count input rejection",
  validate_input_table(d_zero, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated"),
  "ZERO_TOTAL_COUNT"
)

# 5. 異常系: 負の度数
d_neg <- read.csv("fixtures/input_validation/invalid_negative_count.csv")
assert_error_code(
  "Negative count input rejection",
  validate_input_table(d_neg, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated"),
  "NEGATIVE_COUNT_DETECTED"
)

# 6. 異常系: 非整数度数
d_nonint <- read.csv("fixtures/input_validation/invalid_non_integer_count.csv")
assert_error_code(
  "Non-integer count input rejection",
  validate_input_table(d_nonint, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated"),
  "NON_INTEGER_COUNTS"
)

# 7. 異常系: 構造的ゼロ入力
d_sz <- read.csv("fixtures/input_validation/invalid_structural_zero.csv")
assert_error_code(
  "Structural zero input rejection",
  validate_input_table(d_sz, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated"),
  "STRUCTURAL_ZERO_NOT_SUPPORTED"
)

# 8. 入力検証失敗時の run_meta.json 記録および run_state.json 廃止検証 (Phase 3B-2 レビュー対応)
repo_root <- normalizePath(".", mustWork = TRUE)
source(".agents/shared/pass0_contract.R")
tmp_base <- file.path(repo_root, "evidence_runs", "vcd_categorical", paste0(".val_test_", Sys.getpid()))
dir.create(tmp_base, recursive = TRUE, showWarnings = FALSE)
tryCatch({
  # Pass 0 検証済み設定を作成し、データ側を構造的ゼロ含有CSVに差し替えて実行
  data_sz_path <- file.path(tmp_base, "data_sz.csv")
  write.csv(d_sz, data_sz_path, row.names = FALSE)
  data_sz_sha <- pass0_sha256_file(data_sz_path)

  canonical_sha <- compute_canonical_config_sha256(
    vars = c("Treatment", "Outcome"),
    freq = "Freq",
    input_mode = "aggregated",
    prior_alpha = 0.5,
    practical_delta = NULL
  )

  insp_path <- file.path(tmp_base, "inspection_results.json")
  insp_data <- list(
    contract_version = "1.0",
    inspection_status = "ready",
    input_sha256 = data_sz_sha,
    candidate_variables = list("Treatment", "Outcome"),
    detected_freq = "Freq",
    approved_config = list(
      canonical_config_sha256 = canonical_sha
    )
  )
  writeLines(jsonlite::toJSON(insp_data, auto_unbox = TRUE, pretty = TRUE), insp_path)
  insp_sha <- pass0_sha256_file(insp_path)

  cfg_base <- list(
    input = data_sz_path,
    vars = c("Treatment", "Outcome"),
    freq = "Freq",
    input_mode = "aggregated",
    pass0_provenance = list(
      contract_version = "1.0",
      inspection_results = insp_path,
      inspection_results_sha256 = insp_sha,
      input_sha256 = data_sz_sha,
      finalized_at_jst = "2026-09-17 12:00",
      target_skill = "vcd-categorical-analysis",
      canonical_config_sha256 = canonical_sha
    )
  )

  cfg_path <- file.path(tmp_base, "analysis_config.json")
  writeLines(jsonlite::toJSON(cfg_base, auto_unbox = TRUE, pretty = TRUE), cfg_path)

  out_dir <- file.path(tmp_base, "out_run")
  cmd <- sprintf('Rscript .agents/skills/vcd-categorical-analysis/templates/analysis.R --config "%s" --out "%s"',
                 cfg_path, out_dir)
  exit_status <- suppressWarnings(system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE))

  if (exit_status != 0L) {
    cat("[PASS] Input validation failure leads to non-zero exit status.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] Input validation failure did not cause non-zero exit status.\n")
    test_fail <- test_fail + 1L
  }

  run_subdirs <- list.dirs(out_dir, recursive = FALSE)
  run_dirs <- run_subdirs[grepl("^run_", basename(run_subdirs))]
  if (length(run_dirs) >= 1L) {
    run_target <- run_dirs[1L]
    state_in_run <- file.path(run_target, "run_state.json")
    meta_in_run <- file.path(run_target, "run_meta.json")

    # run ディレクトリ内に run_state.json は存在しないこと
    if (!file.exists(state_in_run)) {
      cat("[PASS] run_state.json is NOT present in run directory (consolidated into run_meta.json).\n")
      test_pass <- test_pass + 1L
    } else {
      cat("[FAIL] run_state.json is still present in run directory.\n")
      test_fail <- test_fail + 1L
    }

    # run_meta.json が存在し、run_state == 'failed', error_code == 'STRUCTURAL_ZERO_NOT_SUPPORTED'
    if (file.exists(meta_in_run)) {
      m <- jsonlite::read_json(meta_in_run)
      if (identical(m$run_state, "failed") && identical(m$error_code, "STRUCTURAL_ZERO_NOT_SUPPORTED")) {
        cat("[PASS] run_meta.json correctly recorded run_state == 'failed' and error_code == 'STRUCTURAL_ZERO_NOT_SUPPORTED'.\n")
        test_pass <- test_pass + 1L
      } else {
        cat(sprintf("[FAIL] run_meta.json contents incorrect: run_state=%s, error_code=%s\n", m$run_state, m$error_code))
        test_fail <- test_fail + 1L
      }
      if (!is.null(m$config_file_sha256)) {
        cat("[PASS] run_meta.json contains config_file_sha256 on failure.\n")
        test_pass <- test_pass + 1L
      } else {
        cat("[FAIL] run_meta.json missing config_file_sha256 on failure.\n")
        test_fail <- test_fail + 1L
      }
      if (!is.null(m$canonical_config_sha256) && identical(m$canonical_config_sha256, canonical_sha)) {
        cat("[PASS] run_meta.json contains matching canonical_config_sha256 on failure.\n")
        test_pass <- test_pass + 1L
      } else {
        cat(sprintf("[FAIL] run_meta.json missing or mismatched canonical_config_sha256 on failure (expected: %s, actual: %s).\n",
                    canonical_sha, if (is.null(m$canonical_config_sha256)) "NULL" else m$canonical_config_sha256))
        test_fail <- test_fail + 1L
      }
    } else {
      cat("[FAIL] run_meta.json not created in run directory on validation failure.\n")
      test_fail <- test_fail + 1L
    }
  } else {
    cat("[FAIL] run directory not created.\n")
    test_fail <- test_fail + 1L
  }
}, finally = {
  unlink(tmp_base, recursive = TRUE)
})

# 9. [CODE] 形式を含まない非構造化例外の INPUT_VALIDATION_FAILED フォールバック検証
cat("\n9. Testing unstructured exception fallback to INPUT_VALIDATION_FAILED...\n")
extract_error_code <- function(err_msg) {
  m <- regexec("^\\[([A-Z0-9_]+)\\]\\s*(.*)$", err_msg)
  reg_matches <- regmatches(err_msg, m)[[1]]
  code <- if (length(reg_matches) >= 3L) reg_matches[2] else "INPUT_VALIDATION_FAILED"
  clean_msg <- if (length(reg_matches) >= 3L) reg_matches[3] else err_msg
  list(code = code, message = clean_msg)
}

res_fallback <- extract_error_code("Unexpected internal error without code brackets")
if (identical(res_fallback$code, "INPUT_VALIDATION_FAILED") &&
    identical(res_fallback$message, "Unexpected internal error without code brackets")) {
  cat("[PASS] Non-[CODE] exception correctly falls back to INPUT_VALIDATION_FAILED with preserved message.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Fallback failed: code=%s, message=%s\n", res_fallback$code, res_fallback$message))
  test_fail <- test_fail + 1L
}

res_structured <- extract_error_code("[STRUCTURAL_ZERO_NOT_SUPPORTED] Cannot process structural zero")
if (identical(res_structured$code, "STRUCTURAL_ZERO_NOT_SUPPORTED") &&
    identical(res_structured$message, "Cannot process structural zero")) {
  cat("[PASS] Structured [CODE] exception correctly extracts code and clean message.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Structured extraction failed: code=%s, message=%s\n", res_structured$code, res_structured$message))
  test_fail <- test_fail + 1L
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
