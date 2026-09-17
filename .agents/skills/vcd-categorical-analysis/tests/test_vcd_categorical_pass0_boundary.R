# test_vcd_categorical_pass0_boundary.R — Pass 0 Provenance Integration Tests for v4.1
# Tests:
# 1. MISSING_REQUIRED_CONFIG: --config 未指定
# 2. PROVENANCE_SHA_MISMATCH: 入力 CSV の SHA-256 不一致
# 3. TARGET_SKILL_MISMATCH: 設定内の対象スキル名不一致

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

cat("============================================================\n")
cat("vcd-categorical-analysis v4.1 Pass 0 Provenance Boundary Tests\n")
cat("============================================================\n\n")

analysis_script <- file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "templates", "analysis.R")

# 一時作業ディレクトリ
tmp_dir <- tempfile("vcd_pass0_test_")
dir.create(tmp_dir, recursive = TRUE)
on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

# 1. テスト用 CSV 作成
test_csv <- file.path(tmp_dir, "test_input.csv")
write.csv(data.frame(
  Treatment = c("Drug", "Drug", "Placebo", "Placebo"),
  Response  = c("Yes", "No", "Yes", "No"),
  Freq      = c(50L, 30L, 20L, 60L),
  stringsAsFactors = FALSE
), test_csv, row.names = FALSE)
input_sha <- pass0_sha256_file(test_csv)

# 2. 検分成果物 inspection_results.json 作成
inspection_path <- file.path(tmp_dir, "inspection_results.json")
inspection_data <- list(
  contract_version = "1.0",
  inspection_status = "ready",
  input_sha256 = input_sha,
  candidate_variables = list("Treatment", "Response"),
  detected_freq = "Freq"
)
writeLines(jsonlite::toJSON(inspection_data, auto_unbox = TRUE, pretty = TRUE), inspection_path)
inspection_sha <- pass0_sha256_file(inspection_path)

# ============================================================
# Test 1: MISSING_REQUIRED_CONFIG (--config 未指定で実行)
# ============================================================
cat("[TEST 1] Pass 0 設定未指定 (MISSING_REQUIRED_CONFIG)\n")
cmd1 <- sprintf("Rscript %s --out %s", analysis_script, file.path(tmp_dir, "out1"))
out1 <- suppressWarnings(system(cmd1, intern = TRUE, ignore.stderr = FALSE))
status1 <- attr(out1, "status")
assert(!is.null(status1) && status1 != 0, "config 未指定時は非ゼロ終了する")
run_state1 <- file.path(tmp_dir, "out1", "run_state.json")
assert(file.exists(run_state1), "out ディレクトリに run_state.json が記録される")
if (file.exists(run_state1)) {
  s1 <- jsonlite::fromJSON(run_state1)
  assert(identical(s1$status, "failed"), "run_state status == 'failed'")
  assert(identical(s1$error_code, "MISSING_REQUIRED_CONFIG"), "error_code == 'MISSING_REQUIRED_CONFIG'")
}

# ============================================================
# Test 2: TARGET_SKILL_MISMATCH (スキル名が vcd-bayesian 等)
# ============================================================
cat("[TEST 2] 対象スキル名不一致 (TARGET_SKILL_MISMATCH)\n")
cfg2_path <- file.path(tmp_dir, "config_wrong_skill.json")
cfg2_data <- list(
  input = test_csv,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = inspection_path,
    inspection_results_sha256 = inspection_sha,
    input_sha256 = input_sha,
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-bayesian-evidence-analysis" # 不一致
  )
)
writeLines(jsonlite::toJSON(cfg2_data, auto_unbox = TRUE, pretty = TRUE), cfg2_path)

cmd2 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg2_path, file.path(tmp_dir, "out2"))
out2 <- suppressWarnings(system(cmd2, intern = TRUE, ignore.stderr = FALSE))
status2 <- attr(out2, "status")
assert(!is.null(status2) && status2 != 0, "スキル名不一致時は非ゼロ終了する")
run_state2 <- file.path(tmp_dir, "out2", "run_state.json")
if (file.exists(run_state2)) {
  s2 <- jsonlite::fromJSON(run_state2)
  assert(identical(s2$status, "failed"), "run_state status == 'failed'")
  assert(identical(s2$error_code, "TARGET_SKILL_MISMATCH"), "error_code == 'TARGET_SKILL_MISMATCH'")
}

# ============================================================
# Test 3: PROVENANCE_SHA_MISMATCH (CSV が検分後に改ざんされた場合)
# ============================================================
cat("[TEST 3] 入力 SHA-256 不一致 (PROVENANCE_SHA_MISMATCH)\n")
# ダミーの偽ハッシュ
cfg3_path <- file.path(tmp_dir, "config_wrong_sha.json")
cfg3_data <- list(
  input = test_csv,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = inspection_path,
    inspection_results_sha256 = inspection_sha,
    input_sha256 = "0000000000000000000000000000000000000000000000000000000000000000", # 改ざん
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-categorical-analysis"
  )
)
writeLines(jsonlite::toJSON(cfg3_data, auto_unbox = TRUE, pretty = TRUE), cfg3_path)

cmd3 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg3_path, file.path(tmp_dir, "out3"))
out3 <- suppressWarnings(system(cmd3, intern = TRUE, ignore.stderr = FALSE))
status3 <- attr(out3, "status")
assert(!is.null(status3) && status3 != 0, "SHA-256 不一致時は非ゼロ終了する")
run_state3 <- file.path(tmp_dir, "out3", "run_state.json")
if (file.exists(run_state3)) {
  s3 <- jsonlite::fromJSON(run_state3)
  assert(identical(s3$status, "failed"), "run_state status == 'failed'")
  assert(identical(s3$error_code, "PROVENANCE_SHA_MISMATCH"), "error_code == 'PROVENANCE_SHA_MISMATCH'")
}

# ============================================================
# Test 4: 正常な Pass 0 設定での E2E パイプライン実行成功確認
# ============================================================
cat("[TEST 4] 正常設定での実行成功確認 (status: completed)\n")
cfg4_path <- file.path(tmp_dir, "config_valid.json")
cfg4_data <- list(
  input = test_csv,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = inspection_path,
    inspection_results_sha256 = inspection_sha,
    input_sha256 = input_sha,
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-categorical-analysis"
  )
)
writeLines(jsonlite::toJSON(cfg4_data, auto_unbox = TRUE, pretty = TRUE), cfg4_path)

cmd4 <- sprintf("Rscript %s --config %s --out %s --label test_success", analysis_script, cfg4_path, file.path(tmp_dir, "out4"))
out4 <- suppressWarnings(system(cmd4, intern = TRUE, ignore.stderr = FALSE))
status4 <- attr(out4, "status")
assert(is.null(status4) || status4 == 0, "正常設定ではゼロ終了（成功）する")

# run_id ディレクトリの検索
out4_runs <- list.dirs(file.path(tmp_dir, "out4"), recursive = FALSE)
assert(length(out4_runs) >= 1L, "run_<first16> 出力ディレクトリが作成された")
if (length(out4_runs) >= 1L) {
  run_dir4 <- out4_runs[1]
  state4_file <- file.path(run_dir4, "run_state.json")
  assert(file.exists(state4_file), "run_state.json が生成された")
  if (file.exists(state4_file)) {
    s4 <- jsonlite::fromJSON(state4_file)
    assert(identical(s4$status, "completed"), "run_state status == 'completed'")
    assert(!is.null(s4$analysis_signature), "analysis_signature が記録されている")
  }
  json4_file <- file.path(run_dir4, "categorical_results.json")
  assert(file.exists(json4_file), "categorical_results.json が生成された")
  if (file.exists(json4_file)) {
    j4 <- jsonlite::fromJSON(json4_file)
    assert(identical(j4$interface_version, "3.0"), "interface_version == '3.0'")
    assert(!is.null(j4$provenance$input_sha256), "provenance$input_sha256 が記録されている")
    assert(!is.null(j4$provenance$config_sha256), "provenance$config_sha256 が記録されている")
    assert(identical(j4$provenance$input_sha256, input_sha), "provenance$input_sha256 が実測値と一致")
  }
}

cat("\n============================================================\n")
cat(sprintf("結果: %d PASS / %d FAIL\n", PASS, FAIL))
cat("============================================================\n")

if (FAIL > 0L) {
  stop(sprintf("[FAILED] %d 件のテストが失敗しました。", FAIL), call. = FALSE)
}
