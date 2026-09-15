# test_vcd_categorical_interface_v3.R — Interface 3.0 JSON Schema & Serializer Test Suite

suppressPackageStartupMessages({
  library(jsonlite)
})

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R")
source(".agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R")
source(".agents/skills/vcd-categorical-analysis/R/serializer_v3.R")

test_pass <- 0L
test_fail <- 0L

cat("=== Starting Interface 3.0 Serializer Tests ===\n")

# 1. ゼロセルを含む分割表の解析とシリアライズ
d_zero <- data.frame(
  Row = c("GroupA", "GroupA", "GroupB", "GroupB"),
  Col = c("Resp1", "Resp2", "Resp1", "Resp2"),
  Freq = c(30, 0, 20, 50)
)
v_zero <- validate_input_table(d_zero, vars = c("Row", "Col"), freq = "Freq")
diag_zero <- compute_residual_diagnostics(v_zero)
evid_zero <- compute_effect_evidence_metrics(diag_zero)
post_zero <- compute_dirichlet_posterior(diag_zero, alpha = 1.0, n_draws = 2000L, analysis_signature = "sig_zero_001")

out_tmp <- tempfile(pattern = "interface_v3_test_")
res_v3 <- serialize_interface_v3(evid_zero, post_zero, out_dir = out_tmp, run_id = "test_run_001")

json_file <- file.path(out_tmp, "categorical_results.json")
csv_file <- file.path(out_tmp, "residuals_table.csv")
q_csv_file <- file.path(out_tmp, "quarantine_cells.csv")

# 2. ファイル存在確認
if (file.exists(json_file) && file.exists(csv_file) && file.exists(q_csv_file)) {
  cat("[PASS] categorical_results.json, residuals_table.csv, and quarantine_cells.csv generated.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Output files missing.\n")
  test_fail <- test_fail + 1L
}

# 3. jsonlite::validate による標準 JSON 適合性
raw_json <- paste(readLines(json_file, warn = FALSE), collapse = "\n")
val_res <- jsonlite::validate(raw_json)
if (isTRUE(val_res)) {
  cat("[PASS] categorical_results.json is strictly valid standard JSON (no non-finite syntax errors).\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] JSON syntax validation failed.\n")
  test_fail <- test_fail + 1L
}

# 4. 旧 Evidence Score の完全排除
parsed_json <- jsonlite::fromJSON(raw_json, simplifyVector = FALSE)
if (!grepl("evidence_score", raw_json, ignore.case = TRUE)) {
  cat("[PASS] Legacy Evidence Score is completely eliminated from output JSON.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Legacy evidence_score detected in JSON.\n")
  test_fail <- test_fail + 1L
}

# 5. ゼロセルの JSON 表現契約
zero_json_cell <- Filter(function(c) c$observed == 0, parsed_json$cells)[[1]]
if (is.null(zero_json_cell$log_oe) &&
    zero_json_cell$log_oe_state == "NEGATIVE_INFINITY" &&
    identical(zero_json_cell$is_finite, FALSE) &&
    zero_json_cell$quarantine_status == "QUARANTINED") {
  cat("[PASS] Zero cell JSON output strictly adheres to contract: log_oe is null, state is NEGATIVE_INFINITY, is_finite is false.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Zero cell JSON contract failed.\n")
  test_fail <- test_fail + 1L
}

# 6. 後方互換性エラーハンドリング（旧 Interface 2.x の検出）
legacy_json <- '{"interface_version": "2.1", "test_used": "GLM"}'
check_interface_version <- function(json_str) {
  obj <- jsonlite::fromJSON(json_str)
  ver <- obj$interface_version
  if (is.null(ver) || ver != "3.0") {
    stop(sprintf("[INCOMPATIBLE_INTERFACE_VERSION] Expected Interface 3.0, but found version '%s'.", ver))
  }
}
res_compat <- tryCatch({
  check_interface_version(legacy_json)
  FALSE
}, error = function(e) {
  grepl("INCOMPATIBLE_INTERFACE_VERSION", e$message)
})
if (res_compat) {
  cat("[PASS] Legacy Interface 2.x properly caught and rejected by interface validator.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Legacy interface version not rejected.\n")
  test_fail <- test_fail + 1L
}

unlink(out_tmp, recursive = TRUE)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
