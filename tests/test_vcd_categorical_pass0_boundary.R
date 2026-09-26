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
valid_canonical_config_sha <- compute_canonical_config_sha256(
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  prior_alpha = 0.5,
  practical_delta = NULL
)

inspection_path <- file.path(tmp_dir, "inspection_results.json")
inspection_data <- list(
  contract_version = "1.0",
  inspection_status = "ready",
  input_sha256 = input_sha,
  candidate_variables = list("Treatment", "Response"),
  detected_freq = "Freq",
  approved_config = list(
    canonical_config_sha256 = valid_canonical_config_sha
  )
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
  assert(is.null(s1$run_id) || is.na(s1$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s1$analysis_signature) || is.na(s1$analysis_signature), "早期失敗時は analysis_signature が null であること")
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
  assert(is.null(s2$run_id) || is.na(s2$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s2$analysis_signature) || is.na(s2$analysis_signature), "早期失敗時は analysis_signature が null であること")
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
  assert(is.null(s3$run_id) || is.na(s3$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s3$analysis_signature) || is.na(s3$analysis_signature), "早期失敗時は analysis_signature が null であること")
}

# ============================================================
# Test 4: 正常な Pass 0 設定での E2E パイプライン実行成功確認
# ============================================================
cat("[TEST 4] 正常設定での実行成功確認 (status: completed)\n")
valid_canonical_config_sha <- compute_canonical_config_sha256(
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  prior_alpha = 0.5,
  practical_delta = NULL
)

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
    canonical_config_sha256 = valid_canonical_config_sha,
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

# ============================================================
# Test 5: CANONICAL_CONFIG_OVERRIDE_FORBIDDEN (Task 1.1 & 1.2)
# 解析変更型引数および未知引数の完全ホワイトリスト拒否
# ============================================================
cat("[TEST 5] Canonical CLI ホワイトリスト拒否 (CANONICAL_CONFIG_OVERRIDE_FORBIDDEN)\n")
forbidden_args_list <- list(
  c("--data", test_csv),
  c("--vars", "Treatment,Response"),
  c("--freq", "Freq"),
  c("--input-mode", "aggregated"),
  c("--prior-alpha", "0.5"),
  c("--practical-delta", "0.1"),
  c("--unknown-flag", "value")
)

for (f_args in forbidden_args_list) {
  out5_dir <- file.path(tmp_dir, paste0("out5_", gsub("[^a-zA-Z0-9]", "_", f_args[1])))
  cmd5 <- sprintf("Rscript %s --config %s --out %s %s %s",
                  analysis_script, cfg4_path, out5_dir, f_args[1], f_args[2])
  out5 <- suppressWarnings(system(cmd5, intern = TRUE, ignore.stderr = FALSE))
  status5 <- attr(out5, "status")
  assert(!is.null(status5) && status5 != 0,
         sprintf("禁止引数 %s 指定時は非ゼロ終了する", f_args[1]))

  # 出力root直下の run_state.json を検証
  run_state5 <- file.path(out5_dir, "run_state.json")
  assert(file.exists(run_state5),
         sprintf("出力root直下に run_state.json が記録される (%s)", f_args[1]))
  if (file.exists(run_state5)) {
    s5 <- jsonlite::fromJSON(run_state5)
    assert(identical(s5$status, "failed"),
           sprintf("run_state status == 'failed' (%s)", f_args[1]))
    assert(identical(s5$error_code, "CANONICAL_CONFIG_OVERRIDE_FORBIDDEN"),
           sprintf("error_code == 'CANONICAL_CONFIG_OVERRIDE_FORBIDDEN' (%s)", f_args[1]))
    assert(is.null(s5$run_id) || is.na(s5$run_id),
           sprintf("早期失敗時は run_id が null であること (%s)", f_args[1]))
    assert(is.null(s5$analysis_signature) || is.na(s5$analysis_signature),
           sprintf("早期失敗時は analysis_signature が null であること (%s)", f_args[1]))
  }

  # run_<signature> ディレクトリや成果物が一切生成されていないことを検証 (Task 1.2)
  subdirs5 <- list.dirs(out5_dir, recursive = FALSE)
  run_dirs5 <- subdirs5[grepl("^run_", basename(subdirs5))]
  assert(length(run_dirs5) == 0L,
         sprintf("run_<signature> ディレクトリが一切作成されていないこと (%s)", f_args[1]))
  assert(!file.exists(file.path(out5_dir, "categorical_results.json")),
         sprintf("成果物 JSON が一切作成されていないこと (%s)", f_args[1]))
}

# ============================================================
# Test 6: 実ファイル事後改ざんの署名前早期検知 (Task 1.3)
# ============================================================
cat("[TEST 6] 実入力ファイルの事後改ざん遮断 (PROVENANCE_SHA_MISMATCH)\n")
tampered_csv <- file.path(tmp_dir, "test_input_tampered.csv")
file.copy(test_csv, tampered_csv)
cfg6_path <- file.path(tmp_dir, "config_tampered.json")
cfg6_data <- cfg4_data
cfg6_data$input <- tampered_csv
# inspection成果物のSHAはオリジナルtest_csvのまま
writeLines(jsonlite::toJSON(cfg6_data, auto_unbox = TRUE, pretty = TRUE), cfg6_path)

# 検証前/直前にCSVデータを改ざん
write.csv(data.frame(
  Treatment = c("Drug", "Placebo"),
  Response  = c("Yes", "No"),
  Freq      = c(100L, 100L)
), tampered_csv, row.names = FALSE)

out6_dir <- file.path(tmp_dir, "out6")
cmd6 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg6_path, out6_dir)
out6 <- suppressWarnings(system(cmd6, intern = TRUE, ignore.stderr = FALSE))
status6 <- attr(out6, "status")
assert(!is.null(status6) && status6 != 0, "実ファイル改ざん時は非ゼロ終了する")

run_state6 <- file.path(out6_dir, "run_state.json")
assert(file.exists(run_state6), "出力root直下に run_state.json が記録される (改ざん)")
if (file.exists(run_state6)) {
  s6 <- jsonlite::fromJSON(run_state6)
  assert(identical(s6$status, "failed"), "run_state status == 'failed' (改ざん)")
  assert(identical(s6$error_code, "PROVENANCE_SHA_MISMATCH"), "error_code == 'PROVENANCE_SHA_MISMATCH'")
  assert(is.null(s6$run_id) || is.na(s6$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s6$analysis_signature) || is.na(s6$analysis_signature), "早期失敗時は analysis_signature が null であること")
}
subdirs6 <- list.dirs(out6_dir, recursive = FALSE)
run_dirs6 <- subdirs6[grepl("^run_", basename(subdirs6))]
assert(length(run_dirs6) == 0L, "署名・run予約前に停止し run_<sig> ディレクトリが未作成であること")

# ============================================================
# Test 7: Canonical Core 偽造 attestation フラグ遮断テスト (Task 2.3)
# ============================================================
cat("[TEST 7] Canonical Core 偽造フラグ遮断 (CANONICAL_CONFIG_VERIFICATION_REQUIRED)\n")
options(vcd_categorical.source_only = TRUE)
source(analysis_script)
options(vcd_categorical.source_only = FALSE)

# 偽造 attestation フラグを付与した設定
cfg7_tampered <- cfg4_data
cfg7_tampered$mock_verified <- TRUE

out7_dir <- file.path(tmp_dir, "out7")
res7 <- tryCatch(
  run_categorical_analysis_core(
    config_data = cfg7_tampered,
    config_path = NULL,
    out_root = out7_dir,
    data_label = "tampered_test",
    execution_mode = "canonical"
  ),
  error = function(e) e
)
assert(inherits(res7, "error"), "偽造 attestation フラグ付き設定でエラーが発生する")
assert(grepl("CANONICAL_CONFIG_VERIFICATION_REQUIRED", conditionMessage(res7)),
       "エラーコード CANONICAL_CONFIG_VERIFICATION_REQUIRED が返る")

# 出力root直下の run_state.json 検証
run_state7 <- file.path(out7_dir, "run_state.json")
assert(file.exists(run_state7), "出力root直下に run_state.json が記録される (偽造遮断)")
if (file.exists(run_state7)) {
  s7 <- jsonlite::fromJSON(run_state7)
  assert(identical(s7$error_code, "CANONICAL_CONFIG_VERIFICATION_REQUIRED"),
         "run_state error_code == 'CANONICAL_CONFIG_VERIFICATION_REQUIRED'")
  assert(is.null(s7$run_id) || is.na(s7$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s7$analysis_signature) || is.na(s7$analysis_signature), "早期失敗時は analysis_signature が null であること")
}
subdirs7 <- list.dirs(out7_dir, recursive = FALSE)
run_dirs7 <- subdirs7[grepl("^run_", basename(subdirs7))]
assert(length(run_dirs7) == 0L, "偽造遮断時に run_<sig> ディレクトリが未作成であること")

# ============================================================
# Test 8: development 実行モードのインメモリ専用性検証 (Task 2.3)
# ============================================================
cat("[TEST 8] development 実行モードのインメモリ専用性検証 (Task 2.3)\n")
out8_dir <- file.path(tmp_dir, "out8_dev_empty")
dir.create(out8_dir, recursive = TRUE)

dev_config <- list(
  input = test_csv,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated"
)

res8 <- run_categorical_analysis_core(
  config_data = dev_config,
  config_path = NULL,
  out_root = out8_dir,
  data_label = "dev_test",
  execution_mode = "development"
)

assert(is.list(res8), "development モードは結果リストを返す")
assert(identical(res8$execution_mode, "development"), "res$execution_mode == 'development'")
assert(!is.null(res8$diag_res), "res に diag_res が含まれる")
assert(!is.null(res8$evid_res), "res に evid_res が含まれる")
assert(!is.null(res8$post_res), "res に post_res が含まれる")

# out8_dir にファイルやサブディレクトリが一切生成されていないこと
files_in_out8 <- list.files(out8_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE)
assert(length(files_in_out8) == 0L, "development モード実行でディスク上に成果物・ディレクトリが一切作成されない")

# ============================================================
# Test 9: Pass 0 確定後の設定改ざん検知 (Task 1.5 & 2.6)
# ============================================================
cat("[TEST 9] 設定パラメータ事後改ざん遮断 (PROVENANCE_CONFIG_MISMATCH)\n")
cfg9_tampered <- cfg4_data
# vars を事後的に改ざん（Pass 0 封緘と不一致にする）
cfg9_tampered$vars <- c("Treatment", "OtherVar")
cfg9_path <- file.path(tmp_dir, "config_tampered_vars.json")
writeLines(jsonlite::toJSON(cfg9_tampered, auto_unbox = TRUE, pretty = TRUE), cfg9_path)

out9_dir <- file.path(tmp_dir, "out9")
cmd9 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg9_path, out9_dir)
out9 <- suppressWarnings(system(cmd9, intern = TRUE, ignore.stderr = FALSE))
status9 <- attr(out9, "status")
assert(!is.null(status9) && status9 != 0, "設定改ざん時は非ゼロ終了する")

run_state9 <- file.path(out9_dir, "run_state.json")
assert(file.exists(run_state9), "出力root直下に run_state.json が記録される (設定改ざん)")
if (file.exists(run_state9)) {
  s9 <- jsonlite::fromJSON(run_state9)
  assert(identical(s9$status, "failed"), "run_state status == 'failed' (設定改ざん)")
  assert(identical(s9$error_code, "PROVENANCE_CONFIG_MISMATCH"), "error_code == 'PROVENANCE_CONFIG_MISMATCH'")
  assert(is.null(s9$run_id) || is.na(s9$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s9$analysis_signature) || is.na(s9$analysis_signature), "早期失敗時は analysis_signature が null であること")
}
subdirs9 <- list.dirs(out9_dir, recursive = FALSE)
run_dirs9 <- subdirs9[grepl("^run_", basename(subdirs9))]
assert(length(run_dirs9) == 0L, "設定改ざん時に run_<sig> ディレクトリが未作成であること")

# ============================================================
# Test 10: canonical_config_sha256 未束縛設定の拒否 (Task 1.5 & 2.6)
# ============================================================
cat("[TEST 10] 未束縛設定の拒否 (PROVENANCE_CONFIG_MISMATCH)\n")
cfg10_unbound <- cfg4_data
cfg10_unbound$pass0_provenance$canonical_config_sha256 <- NULL
cfg10_path <- file.path(tmp_dir, "config_unbound.json")
writeLines(jsonlite::toJSON(cfg10_unbound, auto_unbox = TRUE, pretty = TRUE), cfg10_path)

out10_dir <- file.path(tmp_dir, "out10")
cmd10 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg10_path, out10_dir)
out10 <- suppressWarnings(system(cmd10, intern = TRUE, ignore.stderr = FALSE))
status10 <- attr(out10, "status")
assert(!is.null(status10) && status10 != 0, "未束縛設定時は非ゼロ終了する")

run_state10 <- file.path(out10_dir, "run_state.json")
assert(file.exists(run_state10), "出力root直下に run_state.json が記録される (未束縛)")
if (file.exists(run_state10)) {
  s10 <- jsonlite::fromJSON(run_state10)
  assert(identical(s10$status, "failed"), "run_state status == 'failed' (未束縛)")
  assert(identical(s10$error_code, "PROVENANCE_CONFIG_MISMATCH"), "error_code == 'PROVENANCE_CONFIG_MISMATCH'")
  assert(is.null(s10$run_id) || is.na(s10$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s10$analysis_signature) || is.na(s10$analysis_signature), "早期失敗時は analysis_signature が null であること")
}

# ============================================================
# Test 11: input_mode: aggregated で freq 未指定の拒否
# ============================================================
cat("[TEST 11] aggregated モードで freq 列未指定の拒否 (MISSING_FREQUENCY_COLUMN)\n")
cfg11_nofreq <- cfg4_data
cfg11_nofreq$freq <- NULL
cfg11_nofreq$pass0_provenance$canonical_config_sha256 <- compute_canonical_config_sha256(
  vars = cfg11_nofreq$vars, freq = "", input_mode = "aggregated", prior_alpha = 0.5, practical_delta = NULL
)
cfg11_path <- file.path(tmp_dir, "config_nofreq.json")
writeLines(jsonlite::toJSON(cfg11_nofreq, auto_unbox = TRUE, pretty = TRUE), cfg11_path)

out11_dir <- file.path(tmp_dir, "out11")
cmd11 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg11_path, out11_dir)
out11 <- suppressWarnings(system(cmd11, intern = TRUE, ignore.stderr = FALSE))
status11 <- attr(out11, "status")
assert(!is.null(status11) && status11 != 0, "freq 未指定時は非ゼロ終了する")

run_state11 <- file.path(out11_dir, "run_state.json")
assert(file.exists(run_state11), "出力root直下に run_state.json が記録される (freq欠損)")
if (file.exists(run_state11)) {
  s11 <- jsonlite::fromJSON(run_state11)
  assert(identical(s11$status, "failed"), "run_state status == 'failed' (freq欠損)")
  assert(identical(s11$error_code, "MISSING_FREQUENCY_COLUMN"), "error_code == 'MISSING_FREQUENCY_COLUMN'")
  assert(is.null(s11$run_id) || is.na(s11$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s11$analysis_signature) || is.na(s11$analysis_signature), "早期失敗時は analysis_signature が null であること")
}

# ============================================================
# Test 12: input_mode: individual で freq 指定存在の拒否
# ============================================================
cat("[TEST 12] individual モードで freq 列指定の禁止 (FREQUENCY_COLUMN_NOT_PERMITTED)\n")
cfg12_indiv_freq <- cfg4_data
cfg12_indiv_freq$input_mode <- "individual"
cfg12_indiv_freq$freq <- "Freq"
cfg12_indiv_freq$pass0_provenance$canonical_config_sha256 <- compute_canonical_config_sha256(
  vars = cfg12_indiv_freq$vars, freq = "Freq", input_mode = "individual", prior_alpha = 0.5, practical_delta = NULL
)
cfg12_path <- file.path(tmp_dir, "config_indiv_freq.json")
writeLines(jsonlite::toJSON(cfg12_indiv_freq, auto_unbox = TRUE, pretty = TRUE), cfg12_path)

out12_dir <- file.path(tmp_dir, "out12")
cmd12 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg12_path, out12_dir)
out12 <- suppressWarnings(system(cmd12, intern = TRUE, ignore.stderr = FALSE))
status12 <- attr(out12, "status")
assert(!is.null(status12) && status12 != 0, "individual で freq 指定時は非ゼロ終了する")

run_state12 <- file.path(out12_dir, "run_state.json")
assert(file.exists(run_state12), "出力root直下に run_state.json が記録される (individual freq指定)")
if (file.exists(run_state12)) {
  s12 <- jsonlite::fromJSON(run_state12)
  assert(identical(s12$status, "failed"), "run_state status == 'failed' (individual freq指定)")
  assert(identical(s12$error_code, "FREQUENCY_COLUMN_NOT_PERMITTED"), "error_code == 'FREQUENCY_COLUMN_NOT_PERMITTED'")
  assert(is.null(s12$run_id) || is.na(s12$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s12$analysis_signature) || is.na(s12$analysis_signature), "早期失敗時は analysis_signature が null であること")
}

# ============================================================
# Test 13: 2変数分割表専用（次元不一致 INVALID_INPUT_ARITY）の拒否
# ============================================================
cat("[TEST 13] 2変数分割表専用の次元検証 (INVALID_INPUT_ARITY)\n")
cfg13_arity <- cfg4_data
cfg13_arity$vars <- c("Treatment") # 1変数のみ
cfg13_arity$pass0_provenance$canonical_config_sha256 <- compute_canonical_config_sha256(
  vars = cfg13_arity$vars, freq = "Freq", input_mode = "aggregated", prior_alpha = 0.5, practical_delta = NULL
)
cfg13_path <- file.path(tmp_dir, "config_arity.json")
writeLines(jsonlite::toJSON(cfg13_arity, auto_unbox = TRUE, pretty = TRUE), cfg13_path)

out13_dir <- file.path(tmp_dir, "out13")
cmd13 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg13_path, out13_dir)
out13 <- suppressWarnings(system(cmd13, intern = TRUE, ignore.stderr = FALSE))
status13 <- attr(out13, "status")
assert(!is.null(status13) && status13 != 0, "1変数指定時は非ゼロ終了する")

run_state13 <- file.path(out13_dir, "run_state.json")
assert(file.exists(run_state13), "出力root直下に run_state.json が記録される (arity不正)")
if (file.exists(run_state13)) {
  s13 <- jsonlite::fromJSON(run_state13)
  assert(identical(s13$status, "failed"), "run_state status == 'failed' (arity不正)")
  assert(identical(s13$error_code, "INVALID_INPUT_ARITY"), "error_code == 'INVALID_INPUT_ARITY'")
  assert(is.null(s13$run_id) || is.na(s13$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s13$analysis_signature) || is.na(s13$analysis_signature), "早期失敗時は analysis_signature が null であること")
}

# ============================================================
# Test 14: 設定ファイル単体の vars 改ざん＋ハッシュ偽造の遮断 (Task 1.6 & 2.8)
# ============================================================
cat("[TEST 14] 設定ファイル単体の偽造書き換え遮断 (PROVENANCE_CONFIG_MISMATCH)\n")
# 攻撃者が vars を書き換え、かつ config 内の canonical_config_sha256 も再計算して差し替えたケース
hacked_vars <- c("Treatment", "HackedResponse")
hacked_sha <- compute_canonical_config_sha256(
  vars = hacked_vars, freq = "Freq", input_mode = "aggregated", prior_alpha = 0.5, practical_delta = NULL
)
cfg14_hacked <- cfg4_data
cfg14_hacked$vars <- hacked_vars
cfg14_hacked$pass0_provenance$canonical_config_sha256 <- hacked_sha
cfg14_path <- file.path(tmp_dir, "config_hacked_vars.json")
writeLines(jsonlite::toJSON(cfg14_hacked, auto_unbox = TRUE, pretty = TRUE), cfg14_path)

out14_dir <- file.path(tmp_dir, "out14")
cmd14 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg14_path, out14_dir)
out14 <- suppressWarnings(system(cmd14, intern = TRUE, ignore.stderr = FALSE))
status14 <- attr(out14, "status")
assert(!is.null(status14) && status14 != 0, "偽造ハッシュ付き設定改ざん時は非ゼロ終了する")

run_state14 <- file.path(out14_dir, "run_state.json")
assert(file.exists(run_state14), "出力root直下に run_state.json が記録される (偽造改ざん)")
if (file.exists(run_state14)) {
  s14 <- jsonlite::fromJSON(run_state14)
  assert(identical(s14$status, "failed"), "run_state status == 'failed' (偽造改ざん)")
  assert(identical(s14$error_code, "PROVENANCE_CONFIG_MISMATCH"), "error_code == 'PROVENANCE_CONFIG_MISMATCH'")
  assert(is.null(s14$run_id) || is.na(s14$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s14$analysis_signature) || is.na(s14$analysis_signature), "早期失敗時は analysis_signature が null であること")
}
subdirs14 <- list.dirs(out14_dir, recursive = FALSE)
run_dirs14 <- subdirs14[grepl("^run_", basename(subdirs14))]
assert(length(run_dirs14) == 0L, "偽造改ざん時に run_<sig> ディレクトリが未作成であること")

# ============================================================
# Test 15: 旧 alpha = 1.0 で封緘された設定の遮断 (Task 4.8)
# ============================================================
cat("[TEST 15] 旧 alpha = 1.0 封緘設定の遮断 (PROVENANCE_CONFIG_MISMATCH)\n")
legacy_alpha_sha <- compute_canonical_config_sha256(
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  prior_alpha = 1.0, # 旧仕様
  practical_delta = NULL
)
cfg15_legacy <- cfg4_data
cfg15_legacy$pass0_provenance$canonical_config_sha256 <- legacy_alpha_sha
cfg15_path <- file.path(tmp_dir, "config_legacy_alpha.json")
writeLines(jsonlite::toJSON(cfg15_legacy, auto_unbox = TRUE, pretty = TRUE), cfg15_path)

out15_dir <- file.path(tmp_dir, "out15")
cmd15 <- sprintf("Rscript %s --config %s --out %s", analysis_script, cfg15_path, out15_dir)
out15 <- suppressWarnings(system(cmd15, intern = TRUE, ignore.stderr = FALSE))
status15 <- attr(out15, "status")
assert(!is.null(status15) && status15 != 0, "旧 alpha=1.0 封緘時は非ゼロ終了する")

run_state15 <- file.path(out15_dir, "run_state.json")
assert(file.exists(run_state15), "出力root直下に run_state.json が記録される (旧alpha封緘)")
if (file.exists(run_state15)) {
  s15 <- jsonlite::fromJSON(run_state15)
  assert(identical(s15$status, "failed"), "run_state status == 'failed' (旧alpha封緘)")
  assert(identical(s15$error_code, "PROVENANCE_CONFIG_MISMATCH"), "error_code == 'PROVENANCE_CONFIG_MISMATCH'")
  assert(is.null(s15$run_id) || is.na(s15$run_id), "早期失敗時は run_id が null であること")
  assert(is.null(s15$analysis_signature) || is.na(s15$analysis_signature), "早期失敗時は analysis_signature が null であること")
}
subdirs15 <- list.dirs(out15_dir, recursive = FALSE)
run_dirs15 <- subdirs15[grepl("^run_", basename(subdirs15))]
assert(length(run_dirs15) == 0L, "旧alpha封緘時に run_<sig> ディレクトリが未作成であること")

# ============================================================
# Test 16: finalize_pass0_config.R 実生成からの Canonical 解析成功 (CRITICAL 1 対応)
# ============================================================
cat("[TEST 16] finalize_pass0_config.R 実生成設定での E2E パイプライン実行成功確認\n")

# スコープ文書ダミー作成
scope_doc <- file.path(tmp_dir, "scope_doc.md")
writeLines(c("# Pass 0 Scope", "テスト用スコープ確定文書"), scope_doc)

cfg16_out <- file.path(tmp_dir, "config_pass0_finalized.json")
finalize_script <- file.path(repo_root, ".agents", "shared", "finalize_pass0_config.R")
out16_dir <- file.path(tmp_dir, "out16")

cmd_finalize <- sprintf(
  'Rscript "%s" --inspection-results "%s" --scope "%s" --config-out "%s" --skill "vcd-categorical-analysis" --input "%s" --output-dir "%s" --run-id "run_e2e_pass0" --vars "Treatment,Response" --freq "Freq" --input-mode "aggregated"',
  finalize_script, inspection_path, scope_doc, cfg16_out, test_csv, out16_dir
)
out_fin <- suppressWarnings(system(cmd_finalize, intern = TRUE, ignore.stderr = FALSE))
status_fin <- attr(out_fin, "status")
assert(is.null(status_fin) || status_fin == 0, "finalize_pass0_config.R はゼロ終了（成功）する")
assert(file.exists(cfg16_out), "finalize_pass0_config.R により設定ファイルが生成された")

# 生成された設定ファイルを解析スクリプトに渡して E2E 実行
cmd16 <- sprintf('Rscript "%s" --config "%s" --out "%s" --label e2e_pass0_success', analysis_script, cfg16_out, out16_dir)
out16 <- suppressWarnings(system(cmd16, intern = TRUE, ignore.stderr = FALSE))
status16 <- attr(out16, "status")
assert(is.null(status16) || status16 == 0, "finalize_pass0_config.R 生成設定で解析が正常ゼロ終了（成功）する")

out16_runs <- list.dirs(out16_dir, recursive = FALSE)
run_dirs16 <- out16_runs[grepl("^run_", basename(out16_runs))]
assert(length(run_dirs16) >= 1L, "finalize_pass0_config.R 設定から run_<first16> が生成された")
if (length(run_dirs16) >= 1L) {
  state16_file <- file.path(run_dirs16[1], "run_state.json")
  assert(file.exists(state16_file), "run_state.json が生成された (実生成設定)")
  if (file.exists(state16_file)) {
    s16 <- jsonlite::fromJSON(state16_file)
    assert(identical(s16$status, "completed"), "run_state status == 'completed' (実生成設定)")
    assert(!is.null(s16$analysis_signature), "analysis_signature が記録されている (実生成設定)")
  }
  json16_file <- file.path(run_dirs16[1], "categorical_results.json")
  assert(file.exists(json16_file), "categorical_results.json が生成された (実生成設定)")
  if (file.exists(json16_file)) {
    j16 <- jsonlite::fromJSON(json16_file)
    assert(identical(j16$posterior$prior_specification$alpha, 0.5), "成果物 JSON の prior alpha が 0.5 である")
  }
}

cat("\n============================================================\n")
cat(sprintf("結果: %d PASS / %d FAIL\n", PASS, FAIL))
cat("============================================================\n")

if (FAIL > 0L) {
  stop(sprintf("[FAILED] %d 件のテストが失敗しました。", FAIL), call. = FALSE)
}
