#!/usr/bin/env Rscript
# tests/test_vcd_categorical_run_isolation.R — Run Isolation & Signature Contract Tests for v4.1
# Verifies:
# 1. Deterministic run isolation: Different inputs/configs produce distinct run_<signature> directories.
# 2. Complete artifact isolation: Output root has no leaking analysis artifacts.
# 3. run_state.json verification: execution_mode == "canonical", provenance_status == "verified", correct SHAs.
# 4. Deterministic idempotency: Identical config reproduces the identical run_<signature>.
# 5. Concurrent execution safety: Parallel runs for different configs do not collide or corrupt files.

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

check_r_dependencies(
  c("vcd", "gt", "DT", "htmlwidgets", "ggplot2", "jsonlite", "digest"),
  context = "test_vcd_categorical_run_isolation.R"
)

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
cat("vcd-categorical-analysis v4.1 Run Isolation & Contract Tests\n")
cat("============================================================\n\n")

analysis_script <- file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "templates", "analysis.R")
stopifnot(file.exists(analysis_script))

td <- tempfile("vcd_cat_run_iso_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

# ------------------------------------------------------------
# 1. 2組の異なるテストデータと Pass 0 Fixture の作成
# ------------------------------------------------------------
# Dataset A: Treatment x Response
csv_a <- file.path(td, "data_a.csv")
write.csv(data.frame(
  Treatment = c("Drug", "Drug", "Placebo", "Placebo"),
  Response  = c("Yes", "No", "Yes", "No"),
  Freq      = c(60L, 20L, 25L, 55L),
  stringsAsFactors = FALSE
), csv_a, row.names = FALSE)
sha_a <- pass0_sha256_file(csv_a)

sha_a_config <- compute_canonical_config_sha256(
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  prior_alpha = 0.5,
  practical_delta = NULL
)

insp_a_path <- file.path(td, "inspection_a.json")
writeLines(jsonlite::toJSON(list(
  contract_version = "1.0",
  inspection_status = "ready",
  input_sha256 = sha_a,
  candidate_variables = list("Treatment", "Response"),
  detected_freq = "Freq",
  approved_config = list(
    canonical_config_sha256 = sha_a_config
  )
), auto_unbox = TRUE, pretty = TRUE), insp_a_path)
insp_a_sha <- pass0_sha256_file(insp_a_path)

cfg_a_path <- file.path(td, "config_a.json")
writeLines(jsonlite::toJSON(list(
  input = csv_a,
  vars = c("Treatment", "Response"),
  freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = insp_a_path,
    inspection_results_sha256 = insp_a_sha,
    input_sha256 = sha_a,
    canonical_config_sha256 = sha_a_config,
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-categorical-analysis"
  )
), auto_unbox = TRUE, pretty = TRUE), cfg_a_path)

# Dataset B: Gender x Preference (異なる変数名・度数)
csv_b <- file.path(td, "data_b.csv")
write.csv(data.frame(
  Gender     = c("Male", "Male", "Female", "Female"),
  Preference = c("Tea", "Coffee", "Tea", "Coffee"),
  Freq       = c(35L, 45L, 50L, 30L),
  stringsAsFactors = FALSE
), csv_b, row.names = FALSE)
sha_b <- pass0_sha256_file(csv_b)

sha_b_config <- compute_canonical_config_sha256(
  vars = c("Gender", "Preference"),
  freq = "Freq",
  input_mode = "aggregated",
  prior_alpha = 0.5,
  practical_delta = NULL
)

insp_b_path <- file.path(td, "inspection_b.json")
writeLines(jsonlite::toJSON(list(
  contract_version = "1.0",
  inspection_status = "ready",
  input_sha256 = sha_b,
  candidate_variables = list("Gender", "Preference"),
  detected_freq = "Freq",
  approved_config = list(
    canonical_config_sha256 = sha_b_config
  )
), auto_unbox = TRUE, pretty = TRUE), insp_b_path)
insp_b_sha <- pass0_sha256_file(insp_b_path)

cfg_b_path <- file.path(td, "config_b.json")
writeLines(jsonlite::toJSON(list(
  input = csv_b,
  vars = c("Gender", "Preference"),
  freq = "Freq",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    inspection_results = insp_b_path,
    inspection_results_sha256 = insp_b_sha,
    input_sha256 = sha_b,
    canonical_config_sha256 = sha_b_config,
    finalized_at_jst = "2026-09-17 12:00",
    target_skill = "vcd-categorical-analysis"
  )
), auto_unbox = TRUE, pretty = TRUE), cfg_b_path)

# ============================================================
# Test 1: 異なる解析設定における決定論的 Run Isolation
# ============================================================
cat("[TEST 1] 異なる設定での実行分離と決定論的シグネチャ検証\n")
out1_dir <- file.path(td, "out1_runs")

cmd_a <- sprintf("Rscript %s --config %s --out %s --label analysis_a", analysis_script, cfg_a_path, out1_dir)
cmd_b <- sprintf("Rscript %s --config %s --out %s --label analysis_b", analysis_script, cfg_b_path, out1_dir)

out_a <- suppressWarnings(system(cmd_a, intern = TRUE, ignore.stderr = FALSE))
status_a <- attr(out_a, "status")
assert(is.null(status_a) || status_a == 0, "Dataset A の Canonical 解析が正常終了する")

out_b <- suppressWarnings(system(cmd_b, intern = TRUE, ignore.stderr = FALSE))
status_b <- attr(out_b, "status")
assert(is.null(status_b) || status_b == 0, "Dataset B の Canonical 解析が正常終了する")

# run_<first16> ディレクトリの確認
run_dirs <- list.dirs(out1_dir, recursive = FALSE)
run_dirs <- run_dirs[grepl("^run_[0-9a-f]{16}$", basename(run_dirs))]
assert(length(run_dirs) == 2L, "2つの独立した run_<first16> ディレクトリが生成される")

# 出力ルート直下に成果物が漏洩していないこと
root_json <- list.files(out1_dir, pattern = "\\.json$", recursive = FALSE)
assert(length(root_json) == 0L, "出力root直下に JSON 成果物が漏洩していないこと")
root_csv <- list.files(out1_dir, pattern = "\\.csv$", recursive = FALSE)
assert(length(root_csv) == 0L, "出力root直下に CSV 成果物が漏洩していないこと")
root_html <- list.files(out1_dir, pattern = "\\.html$", recursive = FALSE)
assert(length(root_html) == 0L, "出力root直下に HTML 成果物が漏洩していないこと")

# ============================================================
# Test 2: run_state.json 契約および成果物整合性 (Task 3.1)
# ============================================================
cat("[TEST 2] 各 run ディレクトリの run_state.json 契約検証\n")
for (r_dir in run_dirs) {
  state_p <- file.path(r_dir, "run_state.json")
  assert(file.exists(state_p), sprintf("run_state.json が存在する: %s", basename(r_dir)))
  if (file.exists(state_p)) {
    rs <- jsonlite::fromJSON(state_p)
    assert(identical(rs$status, "completed"), "status == 'completed'")
    assert(identical(rs$execution_mode, "canonical"), "execution_mode == 'canonical'")
    assert(identical(rs$provenance_status, "verified"), "provenance_status == 'verified'")
    assert(!is.null(rs$analysis_signature) && nchar(rs$analysis_signature) == 64L,
           "有効な SHA-256 analysis_signature が記録されている")
    assert(!is.null(rs$canonical_config_sha256), "canonical_config_sha256 が記録されている")
    assert(!is.null(rs$config_file_sha256), "config_file_sha256 が記録されている")
    assert(identical(paste0("run_", substr(rs$analysis_signature, 1L, 16L)), basename(r_dir)),
           "run ディレクトリ名が analysis_signature の先頭16文字と完全一致する")
    assert(length(rs$artifacts) >= 6L, "現行の全成果物が artifacts 配列にリストされている")
    assert(!any(grepl("^(mosaic|assoc)_", rs$artifacts)), "モザイク・association PNGをcanonical成果物に含めない")
  }

  res_p <- file.path(r_dir, "categorical_results.json")
  assert(file.exists(res_p), sprintf("categorical_results.json が存在する: %s", basename(r_dir)))
  if (file.exists(res_p)) {
    cr <- jsonlite::fromJSON(res_p)
    assert(identical(cr$interface_version, "3.0"), "interface_version == '3.0'")
    assert(!is.null(cr$provenance$input_sha256), "成果物 JSON provenance$input_sha256 が記録されている")
  }
}

# ============================================================
# Test 3: 決定論的冪等性（同一設定での再実行による同一シグネチャ導出）
# ============================================================
cat("[TEST 3] 同一設定での決定論的再現性（冪等性）検証\n")
cmd_a_repeat <- sprintf("Rscript %s --config %s --out %s --label analysis_a", analysis_script, cfg_a_path, out1_dir)
out_a_rep <- suppressWarnings(system(cmd_a_repeat, intern = TRUE, ignore.stderr = FALSE))
status_a_rep <- attr(out_a_rep, "status")
assert(is.null(status_a_rep) || status_a_rep == 0, "再実行が正常終了する")

run_dirs_after <- list.dirs(out1_dir, recursive = FALSE)
run_dirs_after <- run_dirs_after[grepl("^run_[0-9a-f]{16}$", basename(run_dirs_after))]
assert(length(run_dirs_after) == 2L, "同一設定の再実行で新規ディレクトリが増加せず、同一 run_<first16> に決定論的に収束する")

# ============================================================
# Test 4: 並行実行時の隔離性（Concurrency Safety）
# ============================================================
if (identical(.Platform$OS.type, "unix")) {
  cat("[TEST 4] 並行実行時のファイル隔離性検証 (parallel execution)\n")
  out4_dir <- file.path(td, "out4_parallel")
  dir.create(out4_dir, recursive = TRUE)

  job_a <- parallel::mcparallel({
    system2("Rscript", c(analysis_script, "--config", cfg_a_path, "--out", out4_dir, "--label", "par_a"))
  }, silent = TRUE)
  job_b <- parallel::mcparallel({
    system2("Rscript", c(analysis_script, "--config", cfg_b_path, "--out", out4_dir, "--label", "par_b"))
  }, silent = TRUE)

  res_par <- parallel::mccollect(list(job_a, job_b))
  assert(!inherits(res_par[[1]], "try-error") && identical(as.integer(res_par[[1]]), 0L),
         "並行実行 Job A が正常終了する")
  assert(!inherits(res_par[[2]], "try-error") && identical(as.integer(res_par[[2]]), 0L),
         "並行実行 Job B が正常終了する")

  par_dirs <- list.dirs(out4_dir, recursive = FALSE)
  par_dirs <- par_dirs[grepl("^run_[0-9a-f]{16}$", basename(par_dirs))]
  assert(length(par_dirs) == 2L, "並行実行後も2つの独立した run_<first16> が安全に分離生成される")
} else {
  cat("[TEST 4] SKIP: Windows環境のため並行mcparallelテストをスキップ\n")
}

# ============================================================
# Test 5: 同一設定で異なる --label 指定時の Run 分離 (Task 2.7)
# ============================================================
cat("[TEST 5] 同一設定・異なる --label 指定時の署名分離と独立実行検証 (Task 2.7)\n")
out5_dir <- file.path(td, "out5_labels")
dir.create(out5_dir, recursive = TRUE)

cmd_label1 <- sprintf("Rscript %s --config %s --out %s --label label_alpha", analysis_script, cfg_a_path, out5_dir)
cmd_label2 <- sprintf("Rscript %s --config %s --out %s --label label_beta", analysis_script, cfg_a_path, out5_dir)

out_l1 <- suppressWarnings(system(cmd_label1, intern = TRUE, ignore.stderr = FALSE))
status_l1 <- attr(out_l1, "status")
assert(is.null(status_l1) || status_l1 == 0, "--label label_alpha の実行が正常終了する")

out_l2 <- suppressWarnings(system(cmd_label2, intern = TRUE, ignore.stderr = FALSE))
status_l2 <- attr(out_l2, "status")
assert(is.null(status_l2) || status_l2 == 0, "--label label_beta の実行が正常終了する")

run_dirs5 <- list.dirs(out5_dir, recursive = FALSE)
run_dirs5 <- run_dirs5[grepl("^run_[0-9a-f]{16}$", basename(run_dirs5))]
assert(length(run_dirs5) == 2L, "同一設定・異なる --label で2つの独立した run_<first16> が生成される")

if (length(run_dirs5) == 2L) {
  # 各ディレクトリの成果物名を確認
  dir_files_1 <- list.files(run_dirs5[1])
  dir_files_2 <- list.files(run_dirs5[2])

  has_alpha_1 <- any(grepl("label_alpha", dir_files_1))
  has_beta_1  <- any(grepl("label_beta", dir_files_1))
  has_alpha_2 <- any(grepl("label_alpha", dir_files_2))
  has_beta_2  <- any(grepl("label_beta", dir_files_2))

  assert((has_alpha_1 && !has_beta_1 && !has_alpha_2 && has_beta_2) ||
         (!has_alpha_1 && has_beta_1 && has_alpha_2 && !has_beta_2),
         "成果物ファイル名（gt/dt/plots）が各ディレクトリで混在・衝突せず完全分離されている")

  s1 <- jsonlite::fromJSON(file.path(run_dirs5[1], "run_state.json"))
  s2 <- jsonlite::fromJSON(file.path(run_dirs5[2], "run_state.json"))
  assert(!identical(s1$analysis_signature, s2$analysis_signature),
         "異なる --label で異なる analysis_signature が算出されている")
}

# ============================================================
# Test 6: 同一署名・同一出力 root の並行実行排他ロック (Task 2.8, Task 2.9)
# ============================================================
if (identical(.Platform$OS.type, "unix")) {
  cat("[TEST 6] 同一署名・同一出力 root の並行実行排他ロック検証 (.run_lock)\n")
  out6_dir <- file.path(td, "out6_lock")
  dir.create(out6_dir, recursive = TRUE)

  # 同一の cfg_a_path と同一の --label lock_test を同時に起動
  job1 <- parallel::mcparallel({
    system2("Rscript", c(analysis_script, "--config", cfg_a_path, "--out", out6_dir, "--label", "lock_test"))
  }, silent = TRUE)
  job2 <- parallel::mcparallel({
    system2("Rscript", c(analysis_script, "--config", cfg_a_path, "--out", out6_dir, "--label", "lock_test"))
  }, silent = TRUE)

  res_lock <- parallel::mccollect(list(job1, job2))
  st1 <- if (inherits(res_lock[[1]], "try-error")) 1L else as.integer(res_lock[[1]])
  st2 <- if (inherits(res_lock[[2]], "try-error")) 1L else as.integer(res_lock[[2]])

  statuses <- c(st1, st2)
  cat(sprintf("  並行プロセス exit statuses: %d, %d\n", st1, st2))

  assert(any(statuses == 0L), "少なくとも1つのプロセスが正常完了 (status == 0) する")

  run_dirs6 <- list.dirs(out6_dir, recursive = FALSE)
  run_dirs6 <- run_dirs6[grepl("^run_[0-9a-f]{16}$", basename(run_dirs6))]
  assert(length(run_dirs6) == 1L, "同一署名のため生成された run ディレクトリは1つのみ")

  if (length(run_dirs6) == 1L) {
    assert(!dir.exists(file.path(run_dirs6[1], ".run_lock")), ".run_lock が終了後に確実に解除・削除されている")
    res_f <- file.path(run_dirs6[1], "categorical_results.json")
    assert(file.exists(res_f), "正常完了プロセスの成果物 categorical_results.json が破損なく存在する")
  }

  if (any(statuses != 0L)) {
    root_state_p <- file.path(out6_dir, "run_state.json")
    assert(file.exists(root_state_p), "排他遮断時に出力root直下に run_state.json が記録される")
    if (file.exists(root_state_p)) {
      rst <- jsonlite::fromJSON(root_state_p)
      assert(identical(rst$status, "failed"), "排他遮断プロセスの status == 'failed'")
      assert(identical(rst$error_code, "CONCURRENT_RUN_IN_PROGRESS"), "error_code == 'CONCURRENT_RUN_IN_PROGRESS'")
    }
  }

  # 先行ロック存在時の確実な遮断検証
  if (length(run_dirs6) == 1L) {
    dir.create(file.path(run_dirs6[1], ".run_lock"))
    cmd_lock_blocked <- sprintf("Rscript %s --config %s --out %s --label lock_test", analysis_script, cfg_a_path, out6_dir)
    out_blocked <- suppressWarnings(system(cmd_lock_blocked, intern = TRUE, ignore.stderr = FALSE))
    st_blocked <- attr(out_blocked, "status")
    assert(!is.null(st_blocked) && st_blocked != 0, "先行ロック存在時に実行が非ゼロで終了する")

    root_state_blocked <- file.path(out6_dir, "run_state.json")
    assert(file.exists(root_state_blocked), "ロック失敗時に root run_state.json が記録される")
    if (file.exists(root_state_blocked)) {
      rst_b <- jsonlite::fromJSON(root_state_blocked)
      assert(identical(rst_b$error_code, "CONCURRENT_RUN_IN_PROGRESS"),
             "先行ロック存在時に error_code == 'CONCURRENT_RUN_IN_PROGRESS' で即時遮断される")
    }
    unlink(file.path(run_dirs6[1], ".run_lock"), recursive = TRUE)
  }
} else {
  cat("[TEST 6] SKIP: Windows環境のため並行ロックテストをスキップ\n")
}

cat("\n============================================================\n")
cat(sprintf("結果: %d PASS / %d FAIL\n", PASS, FAIL))
cat("============================================================\n")

if (FAIL > 0L) {
  stop(sprintf("[FAILED] %d 件のテストが失敗しました。", FAIL), call. = FALSE)
}
