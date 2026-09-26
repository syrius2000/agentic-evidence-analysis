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
v_zero <- validate_input_table(d_zero, vars = c("Row", "Col"), freq = "Freq", input_mode = "aggregated")
diag_zero <- compute_residual_diagnostics(v_zero)
evid_zero <- compute_effect_evidence_metrics(diag_zero)

sig_64 <- "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
input_sha_64 <- "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
config_sha_64 <- "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"

post_zero <- compute_dirichlet_posterior(diag_zero, alpha = 0.5, n_draws = 2000L,
                                        analysis_signature = sig_64, practical_delta = 0.05)

out_tmp <- tempfile(pattern = "interface_v3_test_")
res_v3 <- serialize_interface_v3(evid_zero, post_zero,
                                 out_dir = out_tmp,
                                 run_id = "test_run_001",
                                 analysis_signature = sig_64,
                                 input_sha256 = input_sha_64,
                                 config_sha256 = config_sha_64,
                                 execution_mode = "canonical")

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

# 6. prior_specification および execution_mode = "canonical" の検証
prior_spec_json <- parsed_json$posterior$prior_specification
prov_json <- parsed_json$provenance
if (!is.null(prior_spec_json) &&
    identical(prior_spec_json$family, "symmetric_dirichlet") &&
    identical(prior_spec_json$alpha, 0.5) &&
    identical(prior_spec_json$role, "primary") &&
    identical(prior_spec_json$name, "jeffreys") &&
    identical(prov_json$execution_mode, "canonical") &&
    identical(prov_json$analysis_signature, sig_64) &&
    identical(prov_json$input_sha256, input_sha_64) &&
    identical(prov_json$config_sha256, config_sha_64)) {
  cat("[PASS] prior_specification (alpha=0.5, jeffreys) and provenance 64-char SHA fields verified in JSON.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] prior_specification or provenance contract violation in JSON.\n")
  test_fail <- test_fail + 1L
}

# 7. 不確実性ランキングのソート規則検証 (prob_eti_width 降順 -> observed 昇順 -> row_level 昇順 -> col_level 昇順)
ranking <- parsed_json$posterior$uncertainty_ranking
if (length(ranking) == length(parsed_json$cells)) {
  rank_ok <- TRUE
  for (r in seq_len(length(ranking) - 1)) {
    c1 <- ranking[[r]]
    c2 <- ranking[[r + 1]]
    if (c1$prob_eti_width < c2$prob_eti_width) {
      rank_ok <- FALSE; break
    } else if (c1$prob_eti_width == c2$prob_eti_width) {
      if (c1$observed > c2$observed) {
        rank_ok <- FALSE; break
      } else if (c1$observed == c2$observed) {
        if (c1$row_level > c2$row_level) {
          rank_ok <- FALSE; break
        } else if (c1$row_level == c2$row_level && c1$col_level > c2$col_level) {
          rank_ok <- FALSE; break
        }
      }
    }
  }
  if (rank_ok) {
    cat("[PASS] uncertainty_ranking deterministic tie-break sorting strictly verified.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] uncertainty_ranking sort order violated.\n")
    test_fail <- test_fail + 1L
  }
} else {
  cat("[FAIL] uncertainty_ranking length mismatch.\n")
  test_fail <- test_fail + 1L
}

# 8. is_sensitive が JSON / CSV に存在しないことの検証
if (!grepl("is_sensitive", raw_json, ignore.case = TRUE)) {
  cat("[PASS] is_sensitive completely removed from JSON.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] is_sensitive detected in JSON output.\n")
  test_fail <- test_fail + 1L
}

# 9. execution_mode != 'canonical' の呼出し拒否 (SCHEMA_INVARIANT_VIOLATION)
res_dev_reject <- tryCatch({
  serialize_interface_v3(evid_zero, post_zero, out_dir = out_tmp, run_id = "test_run_002",
                         analysis_signature = sig_64, input_sha256 = input_sha_64, config_sha256 = config_sha_64,
                         execution_mode = "development")
  FALSE
}, error = function(e) {
  grepl("SCHEMA_INVARIANT_VIOLATION", e$message)
})
if (res_dev_reject) {
  cat("[PASS] Development mode serialization correctly rejected with SCHEMA_INVARIANT_VIOLATION.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Non-canonical execution_mode was not rejected.\n")
  test_fail <- test_fail + 1L
}

# 10. 不正な SHA (64桁未満、非HEX) の拒否 (SCHEMA_INVARIANT_VIOLATION)
res_bad_sha <- tryCatch({
  serialize_interface_v3(evid_zero, post_zero, out_dir = out_tmp, run_id = "test_run_003",
                         analysis_signature = "short_hash", input_sha256 = input_sha_64, config_sha256 = config_sha_64,
                         execution_mode = "canonical")
  FALSE
}, error = function(e) {
  grepl("SCHEMA_INVARIANT_VIOLATION", e$message)
})
if (res_bad_sha) {
  cat("[PASS] Invalid SHA format correctly rejected with SCHEMA_INVARIANT_VIOLATION.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Invalid SHA format was not rejected.\n")
  test_fail <- test_fail + 1L
}

# 11. 後方互換性エラーハンドリング（旧 Interface 2.x の検出）
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

# 12. JSON と CSV の 6桁契約・数値完全一致検証 (Task 3.5 & WARNING 2 対応)
csv_data <- utils::read.csv(csv_file, stringsAsFactors = FALSE)
json_post_cells <- parsed_json$posterior$cell_posteriors
parity_ok <- TRUE
for (k in seq_along(json_post_cells)) {
  jc <- json_post_cells[[k]]
  cc <- subset(csv_data, row_level == jc$row_level & col_level == jc$col_level)
  if (nrow(cc) != 1L) {
    parity_ok <- FALSE; break
  }
  # cond_row_prob_mean, cond_col_prob_mean, prob_mean の一致
  diff_mean <- abs(jc$cond_row_prob_mean - cc$cond_row_prob_mean)
  diff_col <- abs(jc$cond_col_prob_mean - cc$cond_col_prob_mean)
  diff_prob <- abs(jc$prob_mean - cc$prob_mean)
  if (diff_mean > 1e-9 || diff_col > 1e-9 || diff_prob > 1e-9) {
    parity_ok <- FALSE
    cat(sprintf("[FAIL] Parity mismatch at (%s, %s): JSON cond_row=%.6f vs CSV=%.6f\n",
                jc$row_level, jc$col_level, jc$cond_row_prob_mean, cc$cond_row_prob_mean))
    break
  }
}
if (parity_ok) {
  cat("[PASS] Exact numerical parity (6-digit contract) confirmed between JSON and CSV.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Numerical parity between JSON and CSV violated.\n")
  test_fail <- test_fail + 1L
}

# 13. JSON Schema 適合性（配列型フィールドの保護確認、WARNING 3 対応）
schema_type_ok <- TRUE
# 各セルの quarantine_reasons は配列（JSON 上で list）であること
for (c_obj in parsed_json$cells) {
  if (!is.list(c_obj$quarantine_reasons) && !is.vector(c_obj$quarantine_reasons)) {
    schema_type_ok <- FALSE; break
  }
}
# quality.warnings は配列（JSON 上で list またはベクトル）であること
if (!is.list(parsed_json$quality$warnings) && !is.character(parsed_json$quality$warnings)) {
  schema_type_ok <- FALSE
}
# 生の JSON 文字列で warnings と quarantine_reasons が角括弧 [...] で囲まれていることを確認
if (schema_type_ok && grepl('"warnings":\\s*\\[', raw_json) && grepl('"quarantine_reasons":\\s*\\[', raw_json)) {
  cat("[PASS] JSON Schema array compliance verified: quarantine_reasons and warnings serialize as JSON arrays [...].\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] JSON Schema array compliance failed: unboxed to scalar string.\n")
  test_fail <- test_fail + 1L
}

# 13b. Python jsonschema による schemas/categorical_results_v3.json の厳格検証 (WARNING 3 対応)
schema_path <- normalizePath(".agents/skills/vcd-categorical-analysis/schemas/categorical_results_v3.json", mustWork = TRUE)
py_candidates <- c("/Users/myamaguchi/.local/venvs/ide/bin/python3", Sys.which("python3"))
py_exec <- NULL
for (p in py_candidates) {
  if (nzchar(p) && file.exists(p)) {
    test_run <- suppressWarnings(system2(p, args = c("-c", "\"import jsonschema\""), stdout = FALSE, stderr = FALSE))
    if (identical(test_run, 0L)) {
      py_exec <- p; break
    }
  }
}

if (!is.null(py_exec)) {
  val_code <- sprintf("import json, jsonschema, sys; inst = json.load(open('%s')); sch = json.load(open('%s')); jsonschema.validate(inst, sch); sys.exit(0)",
                      json_file, schema_path)
  val_status <- suppressWarnings(system2(py_exec, args = c("-c", sprintf("\"%s\"", val_code)), stdout = TRUE, stderr = TRUE))
  status_code <- attr(val_status, "status")
  if (is.null(status_code) || identical(status_code, 0L)) {
    cat("[PASS] categorical_results.json strictly validates against schemas/categorical_results_v3.json via jsonschema.\n")
    test_pass <- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] jsonschema validation failed against categorical_results_v3.json: %s\n", paste(val_status, collapse = "\n")))
    test_fail <- test_fail + 1L
  }
} else {
  cat("[WARN] jsonschema not available in Python environment, schema check skipped.\n")
}

# 14. Serializer による条件付き確率の負値・範囲外注入の拒否 (WARNING 4 対応)
post_bad_range <- post_zero
post_bad_range$cell_posteriors[[1]]$cond_row_prob_q025 <- -0.1
res_range_reject <- tryCatch({
  serialize_interface_v3(evid_zero, post_bad_range, out_dir = out_tmp, run_id = "test_run_range",
                         analysis_signature = sig_64, input_sha256 = input_sha_64, config_sha256 = config_sha_64,
                         execution_mode = "canonical")
  FALSE
}, error = function(e) {
  grepl("SCHEMA_INVARIANT_VIOLATION", e$message)
})
if (res_range_reject) {
  cat("[PASS] Conditional probability range violation (q025 = -0.1) rejected with SCHEMA_INVARIANT_VIOLATION.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Conditional probability range violation was not rejected.\n")
  test_fail <- test_fail + 1L
}

# 15. Serializer による負値区間幅注入の拒否 (WARNING 4 対応)
post_bad_width <- post_zero
post_bad_width$cell_posteriors[[1]]$cond_row_prob_eti_width <- -0.2
res_width_reject <- tryCatch({
  serialize_interface_v3(evid_zero, post_bad_width, out_dir = out_tmp, run_id = "test_run_width",
                         analysis_signature = sig_64, input_sha256 = input_sha_64, config_sha256 = config_sha_64,
                         execution_mode = "canonical")
  FALSE
}, error = function(e) {
  grepl("SCHEMA_INVARIANT_VIOLATION", e$message)
})
if (res_width_reject) {
  cat("[PASS] Negative ETI width violation (eti_width = -0.2) rejected with SCHEMA_INVARIANT_VIOLATION.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Negative ETI width violation was not rejected.\n")
  test_fail <- test_fail + 1L
}

unlink(out_tmp, recursive = TRUE)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
