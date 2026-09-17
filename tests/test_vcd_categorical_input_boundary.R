# test_vcd_categorical_input_boundary.R — Comprehensive Boundary & Statistical Tests for v4.1
# Tests all 7 major failure modes, arity rejection, structural zeros, dual-filter, and schema invariants.

find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  getwd()
}
repo_root <- find_agent_repo()

source(file.path(repo_root, ".agents", "shared", "dependency_check.R"))
source(file.path(repo_root, ".agents", "shared", "pass0_contract.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "validate_input.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "residual_diagnostics.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "effect_evidence_metrics.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "dirichlet_posterior.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "serializer_v3.R"))

PASS <- 0L
FAIL <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("  [PASS] %s\n", msg))
    PASS <<- PASS + 1L
  } else {
    cat(sprintf("  [FAIL] %s\n", msg))
    FAIL <<- FAIL + 1L
  }
}

expect_error_code <- function(expr, expected_code, msg) {
  err <- tryCatch(expr, error = function(e) e)
  if (inherits(err, "error")) {
    has_code <- grepl(paste0("\\[", expected_code, "\\]"), conditionMessage(err))
    assert(has_code, sprintf("%s (期待コード: [%s], 実測: %s)", msg, expected_code, conditionMessage(err)))
  } else {
    assert(FALSE, sprintf("%s (エラーが発生しませんでした)", msg))
  }
}

cat("============================================================\n")
cat("vcd-categorical-analysis v4.1 Input Boundary & Contract Tests\n")
cat("============================================================\n\n")

# 一時作業ディレクトリ
tmp_dir <- tempfile("vcd_test_")
dir.create(tmp_dir, recursive = TRUE)
on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

# 基準正常データ（2x2 分割表）
valid_agg_df <- data.frame(
  Treatment = c("Drug", "Drug", "Placebo", "Placebo"),
  Response  = c("Yes", "No", "Yes", "No"),
  Freq      = c(50L, 30L, 20L, 60L),
  stringsAsFactors = FALSE
)
valid_csv <- file.path(tmp_dir, "valid_data.csv")
write.csv(valid_agg_df, valid_csv, row.names = FALSE)

# ============================================================
# Test 1: input_mode 欠損・未知値の拒否 (INVALID_INPUT_MODE)
# ============================================================
cat("[TEST 1] input_mode 検証 (INVALID_INPUT_MODE)\n")
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response"), freq = "Freq", input_mode = "unknown_mode"),
  "INVALID_INPUT_MODE",
  "未知の input_mode は INVALID_INPUT_MODE で即時停止する"
)
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response"), freq = "Freq", input_mode = NULL),
  "INVALID_INPUT_MODE",
  "NULL input_mode は INVALID_INPUT_MODE で即時停止する"
)

# ============================================================
# Test 2: aggregated モードでの freq 列欠損・タイポ (MISSING_FREQUENCY_COLUMN)
# ============================================================
cat("[TEST 2] aggregated モードでの freq 欠損 (MISSING_FREQUENCY_COLUMN)\n")
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response"), freq = "Frequency", input_mode = "aggregated"),
  "MISSING_FREQUENCY_COLUMN",
  "存在しない freq 列名は MISSING_FREQUENCY_COLUMN で即時停止する（暗黙の Freq=1 は不可）"
)
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response"), freq = NULL, input_mode = "aggregated"),
  "MISSING_FREQUENCY_COLUMN",
  "freq 列未指定は MISSING_FREQUENCY_COLUMN で即時停止する"
)

# ============================================================
# Test 3: individual モードでの freq 列指定禁止 (FREQUENCY_COLUMN_NOT_PERMITTED)
# ============================================================
cat("[TEST 3] individual モードでの freq 指定禁止 (FREQUENCY_COLUMN_NOT_PERMITTED)\n")
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response"), freq = "Freq", input_mode = "individual"),
  "FREQUENCY_COLUMN_NOT_PERMITTED",
  "individual モードで freq 列が指定された場合は FREQUENCY_COLUMN_NOT_PERMITTED で即時停止する"
)

# individual モードで freq = NULL の場合は正常集計（行カウント = 1）
indiv_df <- data.frame(
  Treatment = c("Drug", "Drug", "Placebo"),
  Response  = c("Yes", "No", "Yes"),
  stringsAsFactors = FALSE
)
res_indiv <- validate_input_table(indiv_df, vars = c("Treatment", "Response"), freq = NULL, input_mode = "individual")
assert(attr(res_indiv, "n_total") == 3L, "individual モード正常時に全行 1 として集計される")

# ============================================================
# Test 4: ゼロマージン表の拒否 (ZERO_MARGIN_DETECTED)
# ============================================================
cat("[TEST 4] ゼロマージン表の検証 (ZERO_MARGIN_DETECTED)\n")
zero_margin_df <- data.frame(
  Treatment = c("Drug", "Drug", "Placebo", "Placebo"),
  Response  = c("Yes", "No", "Yes", "No"),
  Freq      = c(50L, 0L, 20L, 0L), # No が全て 0 (列和 = 0)
  stringsAsFactors = FALSE
)
expect_error_code(
  validate_input_table(zero_margin_df, vars = c("Treatment", "Response"), freq = "Freq", input_mode = "aggregated"),
  "ZERO_MARGIN_DETECTED",
  "列和または行和が0の空カテゴリは ZERO_MARGIN_DETECTED で即時停止する"
)

# ============================================================
# Test 5: 3次元以上の入力に対する拒否 (INVALID_INPUT_ARITY)
# ============================================================
cat("[TEST 5] 3次元以上の入力拒否 (INVALID_INPUT_ARITY)\n")
expect_error_code(
  validate_input_table(valid_agg_df, vars = c("Treatment", "Response", "Extra"), freq = "Freq", input_mode = "aggregated"),
  "INVALID_INPUT_ARITY",
  "3次元以上の入力は INVALID_INPUT_ARITY で即時停止する"
)

# ============================================================
# Test 6: 構造的ゼロ指定の拒否 (STRUCTURAL_ZERO_NOT_SUPPORTED)
# ============================================================
cat("[TEST 6] 構造的ゼロ指定の拒否 (STRUCTURAL_ZERO_NOT_SUPPORTED)\n")
sz_df <- valid_agg_df
sz_df$is_structural_zero <- c(FALSE, FALSE, TRUE, FALSE)
expect_error_code(
  validate_input_table(sz_df, vars = c("Treatment", "Response"), freq = "Freq", input_mode = "aggregated"),
  "STRUCTURAL_ZERO_NOT_SUPPORTED",
  "構造的ゼロ列の指定は STRUCTURAL_ZERO_NOT_SUPPORTED で即時停止する"
)

# ============================================================
# Test 7: 大標本 Dual-Filter の標本サイズ境界 (N < 2000 では常に candidate = FALSE)
# ============================================================
cat("[TEST 7] 大標本 Dual-Filter 判定 (N < 2000 vs N >= 2000)\n")
# N = 160 の小標本表 (効果大・高スコアでも candidate になってはならない)
diag_small <- compute_residual_diagnostics(valid_agg_df)
evid_small <- compute_effect_evidence_metrics(diag_small)
small_candidates <- any(vapply(evid_small$cells, function(c) c$dual_filter_candidate, logical(1)))
assert(!small_candidates, "N < 2000 では効果量・スコアが高くても dual_filter_candidate は常に FALSE")

# N = 3000 の大標本表を作成
large_agg_df <- valid_agg_df
large_agg_df$Freq <- large_agg_df$Freq * 20L # N = 3200
diag_large <- compute_residual_diagnostics(large_agg_df)
evid_large <- compute_effect_evidence_metrics(diag_large)
large_candidates <- any(vapply(evid_large$cells, function(c) c$dual_filter_candidate, logical(1)))
assert(large_candidates, "N >= 2000 かつ閾値超過セルでは dual_filter_candidate が TRUE になる")

# ============================================================
# Test 8: 期待度数診断 (Expected-Count Diagnostics / Cochran 条件)
# ============================================================
cat("[TEST 8] 期待度数診断 (Cochran 条件)\n")
assert(!is.null(diag_small$global$expected_count_diagnostics), "expected_count_diagnostics が算出されている")
assert(is.numeric(diag_small$global$expected_count_diagnostics$min_expected), "min_expected が数値である")
assert(is.logical(diag_small$global$expected_count_diagnostics$cochran_satisfied), "cochran_satisfied が真偽値である")

# ============================================================
# Test 9: practical delta の既定無効化 (既定 null)
# ============================================================
cat("[TEST 9] practical delta の既定無効化\n")
post_def <- compute_dirichlet_posterior(diag_small, alpha = 1.0, n_draws = 1000L)
assert(is.null(post_def$practical_delta), "既定では practical_delta は NULL である")
assert(is.null(post_def$cell_posteriors[[1]]$prob_practical_delta), "既定では各セルの prob_practical_delta は NULL である")

# 明示指定時は計算される
post_delta <- compute_dirichlet_posterior(diag_small, alpha = 1.0, n_draws = 1000L, practical_delta = 0.05)
assert(!is.null(post_delta$cell_posteriors[[1]]$prob_practical_delta), "practical_delta 指定時は実務差確率が計算される")

# ============================================================
# Test 10: 事前感度分析（alpha = 0.5 との比較要約）
# ============================================================
cat("[TEST 10] 事前感度分析の比較要約\n")
sens <- post_def$sensitivity_analysis
assert(!is.null(sens), "sensitivity_analysis が生成されている")
assert(!is.null(sens$cell_comparisons), "cell_comparisons が保持されている")
assert(is.numeric(sens$max_median_shift), "max_median_shift が数値として算出されている")

# ============================================================
# Test 11: 成果物シリアライザの Cross-Field Invariant 検証
# ============================================================
cat("[TEST 11] Cross-Field Invariant 検証\n")
out_test_dir <- file.path(tmp_dir, "serializer_out")
res_v3 <- serialize_interface_v3(
  effect_result = evid_small,
  posterior_result = post_def,
  out_dir = out_test_dir,
  run_id = "test_run_001",
  analysis_signature = "sig1234567890abcdef"
)
assert(file.exists(file.path(out_test_dir, "categorical_results.json")), "categorical_results.json が生成された")
assert(file.exists(file.path(out_test_dir, "evidence_profile.json")), "evidence_profile.json が生成された")
assert(file.exists(file.path(out_test_dir, "residuals_table.csv")), "residuals_table.csv が生成された")
assert(identical(res_v3$interface_version, "3.0"), "interface_version == '3.0'")
assert(!is.null(res_v3$provenance$analysis_signature), "provenance に analysis_signature が記録されている")

# ============================================================
# Test 12: evidence_profile.json と categorical_results.json のキー整合性照合
# ============================================================
cat("[TEST 12] evidence_profile.json キー整合性検証\n")
prof_v1 <- jsonlite::read_json(file.path(out_test_dir, "evidence_profile.json"), simplifyVector = FALSE)
cat_v3 <- jsonlite::read_json(file.path(out_test_dir, "categorical_results.json"), simplifyVector = FALSE)

assert(identical(prof_v1$analysis_signature, cat_v3$analysis_signature), "成果物間で analysis_signature が完全一致する")
assert(identical(prof_v1$provenance$run_id, cat_v3$provenance$run_id), "成果物間で run_id が完全一致する")
prof_keys <- sort(vapply(prof_v1$cells, function(c) paste(c$row_level, c$col_level, sep = ":::"), character(1)))
cat_keys <- sort(vapply(cat_v3$cells, function(c) paste(c$row_level, c$col_level, sep = ":::"), character(1)))
assert(identical(prof_keys, cat_keys), "成果物間で全セル識別キー集合（row_level, col_level）が完全一致する")

# ============================================================
# Test 13: 不変量破綻注入時のフェイルファスト検証 (SCHEMA_INVARIANT_VIOLATION 破壊テスト)
# ============================================================
cat("[TEST 13] SCHEMA_INVARIANT_VIOLATION 破壊的テスト\n")
# 13.1 署名不一致
prof_bad_sig <- prof_v1
prof_bad_sig$analysis_signature <- "tampered_signature_999"
expect_error_code(
  validate_cross_artifact_invariants(cat_v3, prof_bad_sig),
  "SCHEMA_INVARIANT_VIOLATION",
  "analysis_signature 不一致時は SCHEMA_INVARIANT_VIOLATION で停止する"
)

# 13.2 セルキー欠落・不一致
prof_bad_cells <- prof_v1
prof_bad_cells$cells <- prof_bad_cells$cells[-1] # セルを1つ欠落
expect_error_code(
  validate_cross_artifact_invariants(cat_v3, prof_bad_cells),
  "SCHEMA_INVARIANT_VIOLATION",
  "セル数・キー不一致時は SCHEMA_INVARIANT_VIOLATION で停止する"
)

# 13.3 確率総和の乖離
cat_bad_prob <- cat_v3
cat_bad_prob$posterior$cell_posteriors[[1]]$prob_mean <- 0.99
expect_error_code(
  validate_cross_artifact_invariants(cat_bad_prob, prof_v1),
  "SCHEMA_INVARIANT_VIOLATION",
  "確率総和乖離時は SCHEMA_INVARIANT_VIOLATION で停止する"
)

# 13.4 信用区間順序の逆転
cat_bad_ci <- cat_v3
cat_bad_ci$posterior$cell_posteriors[[1]]$prob_q025 <- 0.8
cat_bad_ci$posterior$cell_posteriors[[1]]$prob_q500 <- 0.5
expect_error_code(
  validate_cross_artifact_invariants(cat_bad_ci, prof_v1),
  "SCHEMA_INVARIANT_VIOLATION",
  "信用区間順序逆転時は SCHEMA_INVARIANT_VIOLATION で停止する"
)

# ============================================================
# Test 14: analysis.R 実起動による E2E 遮断テスト (input_mode 欠損)
# ============================================================
cat("[TEST 14] analysis.R E2E 遮断検証: input_mode 欠損 (INVALID_INPUT_MODE)\n")
analysis_script <- file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "templates", "analysis.R")

# 有効な Pass 0 検分成果物 inspection_results.json を作成
e2e_data_csv <- file.path(tmp_dir, "e2e_data.csv")
write.csv(valid_agg_df, e2e_data_csv, row.names = FALSE)
e2e_data_sha <- pass0_sha256_file(e2e_data_csv)

inspection_path_e2e <- file.path(tmp_dir, "inspection_results_e2e.json")
inspection_data_e2e <- list(
  contract_version = "1.0",
  inspection_status = "ready",
  input_sha256 = e2e_data_sha,
  candidate_variables = list("Treatment", "Response"),
  detected_freq = "Freq"
)
writeLines(jsonlite::toJSON(inspection_data_e2e, auto_unbox = TRUE, pretty = TRUE), inspection_path_e2e)
inspection_sha_e2e <- pass0_sha256_file(inspection_path_e2e)

# Pass 0 来歴は有効だが input_mode のみを欠損させた設定
config_no_mode <- list(
  input = e2e_data_csv,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  # input_mode は意図的に欠損
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = inspection_path_e2e,
    inspection_results_sha256 = inspection_sha_e2e,
    input_sha256 = e2e_data_sha,
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-categorical-analysis"
  )
)
config_no_mode_path <- file.path(tmp_dir, "config_no_mode.json")
writeLines(jsonlite::toJSON(config_no_mode, auto_unbox = TRUE, pretty = TRUE), config_no_mode_path)

e2e_out_1 <- file.path(tmp_dir, "e2e_out_no_mode")
cmd_no_mode <- sprintf('Rscript "%s" --config "%s" --out "%s"', analysis_script, config_no_mode_path, e2e_out_1)
status_no_mode <- suppressWarnings(system(cmd_no_mode, ignore.stdout = TRUE, ignore.stderr = TRUE))

assert(status_no_mode != 0L, "input_mode 欠損設定で analysis.R は非ゼロ終了する")

# run ディレクトリの run_state.json を探索
run_subdirs_1 <- list.dirs(e2e_out_1, recursive = FALSE)
assert(length(run_subdirs_1) >= 1L, "E2E 実行ディレクトリが作成された")
if (length(run_subdirs_1) >= 1L) {
  run_state_file <- file.path(run_subdirs_1[1], "run_state.json")
  assert(file.exists(run_state_file), "run_state.json が生成されている")
  if (file.exists(run_state_file)) {
    rs <- jsonlite::read_json(run_state_file)
    assert(identical(rs$status, "failed"), "run_state.json の status == 'failed'")
    assert(identical(rs$error_code, "INVALID_INPUT_MODE"), "run_state.json の error_code == 'INVALID_INPUT_MODE'")
  }
  assert(!file.exists(file.path(run_subdirs_1[1], "categorical_results.json")), "解析成果物 categorical_results.json は未生成である")
  assert(!file.exists(file.path(run_subdirs_1[1], "evidence_profile.json")), "解析成果物 evidence_profile.json は未生成である")
}

# ============================================================
# Test 15: analysis.R 実起動による E2E 遮断テスト (未知の input_mode: 'invalid_mode')
# ============================================================
cat("[TEST 15] analysis.R E2E 遮断検証: 未知 input_mode (INVALID_INPUT_MODE)\n")
config_bad_mode <- config_no_mode
config_bad_mode$input_mode <- "invalid_foo_mode"
config_bad_mode_path <- file.path(tmp_dir, "config_bad_mode.json")
writeLines(jsonlite::toJSON(config_bad_mode, auto_unbox = TRUE, pretty = TRUE), config_bad_mode_path)

e2e_out_2 <- file.path(tmp_dir, "e2e_out_bad_mode")
cmd_bad_mode <- sprintf('Rscript "%s" --config "%s" --out "%s"', analysis_script, config_bad_mode_path, e2e_out_2)
status_bad_mode <- suppressWarnings(system(cmd_bad_mode, ignore.stdout = TRUE, ignore.stderr = TRUE))

assert(status_bad_mode != 0L, "未知 input_mode 設定で analysis.R は非ゼロ終了する")
run_subdirs_2 <- list.dirs(e2e_out_2, recursive = FALSE)
assert(length(run_subdirs_2) >= 1L, "未知 input_mode 実行ディレクトリが作成された")
if (length(run_subdirs_2) >= 1L) {
  rs_file2 <- file.path(run_subdirs_2[1], "run_state.json")
  if (file.exists(rs_file2)) {
    rs2 <- jsonlite::read_json(rs_file2)
    assert(identical(rs2$status, "failed"), "未知 input_mode 時の run_state.json status == 'failed'")
    assert(identical(rs2$error_code, "INVALID_INPUT_MODE"), "未知 input_mode 時の run_state.json error_code == 'INVALID_INPUT_MODE'")
  }
}

# ============================================================
# Test 16: analysis.R 実起動による E2E 遮断テスト (SCHEMA_INVARIANT_VIOLATION)
# ============================================================
cat("[TEST 16] analysis.R E2E 遮断検証: 不変量違反注入 (SCHEMA_INVARIANT_VIOLATION)\n")
config_valid <- config_no_mode
config_valid$input_mode <- "aggregated"
config_valid_path <- file.path(tmp_dir, "config_valid_for_invariant_test.json")
writeLines(jsonlite::toJSON(config_valid, auto_unbox = TRUE, pretty = TRUE), config_valid_path)

e2e_out_3 <- file.path(tmp_dir, "e2e_out_schema_violation")
# 環境変数 VCD_TEST_INJECT_SCHEMA_INVARIANT_VIOLATION="signature" を付与して実プロセス実行
cmd_schema_violation <- sprintf('VCD_TEST_INJECT_SCHEMA_INVARIANT_VIOLATION="signature" Rscript "%s" --config "%s" --out "%s"', analysis_script, config_valid_path, e2e_out_3)
status_schema_violation <- suppressWarnings(system(cmd_schema_violation, ignore.stdout = TRUE, ignore.stderr = TRUE))

assert(status_schema_violation != 0L, "Schema不変量違反注入で analysis.R は非ゼロ終了する")
run_subdirs_3 <- list.dirs(e2e_out_3, recursive = FALSE)
assert(length(run_subdirs_3) >= 1L, "不変量違反注入時の実行ディレクトリが作成された")
if (length(run_subdirs_3) >= 1L) {
  rs_file3 <- file.path(run_subdirs_3[1], "run_state.json")
  assert(file.exists(rs_file3), "run_state.json が生成されている")
  if (file.exists(rs_file3)) {
    rs3 <- jsonlite::read_json(rs_file3)
    assert(identical(rs3$status, "failed"), "run_state.json の status == 'failed'")
    assert(identical(rs3$error_code, "SCHEMA_INVARIANT_VIOLATION"), "run_state.json の error_code == 'SCHEMA_INVARIANT_VIOLATION'")
  }
  assert(!file.exists(file.path(run_subdirs_3[1], "categorical_results.json")), "解析成果物 categorical_results.json は未生成である")
  assert(!file.exists(file.path(run_subdirs_3[1], "evidence_profile.json")), "解析成果物 evidence_profile.json は未生成である")
}

cat("\n============================================================\n")
cat(sprintf("結果: %d PASS / %d FAIL\n", PASS, FAIL))
cat("============================================================\n")

if (FAIL > 0L) {
  stop(sprintf("[FAILED] %d 件のテストが失敗しました。", FAIL), call. = FALSE)
}

