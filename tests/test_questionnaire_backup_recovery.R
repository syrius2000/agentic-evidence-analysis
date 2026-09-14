#!/usr/bin/env Rscript
# tests/test_questionnaire_backup_recovery.R
# questionnaire-batch-analysis 成果物保護（退避・復元・失敗注入）回帰テスト
# 実行: Rscript tests/test_questionnaire_backup_recovery.R

ca   <- commandArgs(trailingOnly = FALSE)
fa   <- ca[grep("^--file=", ca)]
root <- if (length(fa) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", fa[1]))))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}
if (!file.exists(file.path(root, ".agents")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), winslash = "/", mustWork = TRUE)
}

source(file.path(root, ".agents", "shared", "dependency_check.R"))
check_r_dependencies(c("digest"), context = "テスト: test_questionnaire_backup_recovery.R")

pass <- 0L
fail <- 0L

assert <- function(label, cond) {
  if (isTRUE(cond)) {
    cat(sprintf("  [PASS] %s\n", label))
    pass <<- pass + 1L
  } else {
    cat(sprintf("  [FAIL] %s\n", label))
    fail <<- fail + 1L
  }
}

# --- 共有ヘルパーのロード（test_questionnaire_batch_ucbadmissions.R と同一の正本実装） ---
source(file.path(root, ".agents", "skills", "questionnaire-batch-analysis", "tests", "helpers_backup_recovery.R"))

# --- テスト用一時サンドボックス作成 ---
sandbox_root <- file.path(tempdir(), paste0("test_backup_recovery_", format(Sys.time(), "%Y%m%d_%H%M%S")))
dir.create(sandbox_root, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(sandbox_root, recursive = TRUE, force = TRUE), add = TRUE)

create_sample_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  writeLines("header\nrow1,10\nrow2,20", file.path(path, "summary.csv"))
  sub_dir <- file.path(path, "q01")
  dir.create(sub_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines('{"status": "ok", "n": 30}', file.path(sub_dir, "results.json"))
  fig_dir <- file.path(sub_dir, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)), file.path(fig_dir, "plot.png"))
}

cat("=== questionnaire 成果物保護・失敗注入テスト開始 ===\n")

# [TEST 1] 通常経路の退避・復元 (file.rename)
cat("\n[TEST 1] 通常退避・復元 (file.rename 成功時)\n")
t1_src <- file.path(sandbox_root, "t1_data")
create_sample_dir(t1_src)
m_orig <- get_dir_manifest(t1_src)

b1 <- safe_backup_dir(t1_src)
assert("退避後に元ディレクトリが移動されている", !dir.exists(t1_src))
assert("退避先にディレクトリが存在する", dir.exists(b1$target))

# テスト実行を模擬して同名ディレクトリを生成
dir.create(t1_src)
writeLines("corrupted", file.path(t1_src, "corrupted.txt"))

ok_r1 <- safe_restore_dir(b1, t1_src)
assert("復元が成功する", ok_r1)
assert("退避親ホルダーが削除されている", !dir.exists(b1$parent))
assert("復元後マニフェストが完全一致する", identical(m_orig, get_dir_manifest(t1_src)))

# [TEST 2] 退避 file.rename 失敗注入 (file.copy フォールバック)
cat("\n[TEST 2] 退避 file.rename 失敗注入 (file.copy フォールバック)\n")
t2_src <- file.path(sandbox_root, "t2_data")
create_sample_dir(t2_src)
m_orig2 <- get_dir_manifest(t2_src)

b2 <- safe_backup_dir(t2_src, inject_rename_fail = TRUE)
assert("file.rename失敗時もfile.copyで退避成功する", !is.null(b2))
assert("退避後に元ディレクトリが削除されている", !dir.exists(t2_src))
assert("退避先マニフェストが元データと完全一致する", identical(m_orig2, get_dir_manifest(b2$target)))

ok_r2 <- safe_restore_dir(b2, t2_src)
assert("復元が成功する", ok_r2)
assert("復元後マニフェストが完全一致する", identical(m_orig2, get_dir_manifest(t2_src)))

# [TEST 3] 退避 file.copy 失敗注入 (元データ完全保護 & 即時停止)
cat("\n[TEST 3] 退避 file.copy 失敗注入 (元データ完全保護)\n")
t3_src <- file.path(sandbox_root, "t3_data")
create_sample_dir(t3_src)
m_orig3 <- get_dir_manifest(t3_src)

err3 <- tryCatch({
  safe_backup_dir(t3_src, inject_rename_fail = TRUE, inject_copy_fail = TRUE)
  NULL
}, error = function(e) e$message)

assert("退避失敗時に即座にstop()する", !is.null(err3))
assert("退避失敗時に元ディレクトリが100%残存している", dir.exists(t3_src))
assert("退避失敗時も元データのマニフェストが一切変更されていない", identical(m_orig3, get_dir_manifest(t3_src)))

# [TEST 4] 復元コピー方式 (コピー検証・SHA-256一致時のみバックアップ削除)
cat("\n[TEST 4] 復元コピー方式 (コピー検証・SHA-256一致時のみバックアップ削除)\n")
t4_src <- file.path(sandbox_root, "t4_data")
create_sample_dir(t4_src)
m_orig4 <- get_dir_manifest(t4_src)
b4 <- safe_backup_dir(t4_src)

ok_r4 <- safe_restore_dir(b4, t4_src)
assert("復元が成功する", ok_r4)
assert("復元後マニフェストが完全一致する", identical(m_orig4, get_dir_manifest(t4_src)))
assert("完全一致確認後に退避親ホルダーが削除されている", !dir.exists(b4$parent))

# [TEST 5] 復元コピー失敗注入 (バックアップの非削除・安全保持)
cat("\n[TEST 5] 復元コピー失敗注入 (バックアップの非削除・安全保持)\n")
t5_src <- file.path(sandbox_root, "t5_data")
create_sample_dir(t5_src)
m_orig5 <- get_dir_manifest(t5_src)
b5 <- safe_backup_dir(t5_src)

suppressWarnings({
  ok_r5 <- safe_restore_dir(b5, t5_src, inject_copy_fail = TRUE)
})
assert("復元失敗時にFALSEが返る", !ok_r5)
assert("復元失敗時にバックアップディレクトリが削除されず保持される", dir.exists(b5$target))
assert("保持されたバックアップのマニフェストが元データと完全一致する", identical(m_orig5, get_dir_manifest(b5$target)))
# テスト検証後の安全な後始末
unlink(b5$parent, recursive = TRUE, force = TRUE)

# [TEST 6] run_test() 内での stop() 発生時における on.exit() 自動復元検証
cat("\n[TEST 6] run_test() 中断時の on.exit() 自動復元検証\n")
t6_src <- file.path(sandbox_root, "t6_data")
create_sample_dir(t6_src)
m_orig6 <- get_dir_manifest(t6_src)

simulated_runner <- function(target_dir) {
  b_info <- safe_backup_dir(target_dir)
  on.exit({
    safe_restore_dir(b_info, target_dir)
  }, add = TRUE)

  # テスト生成物の中間配置
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines("interrupted", file.path(target_dir, "junk.txt"))

  # 意図的な中断
  stop("Failure Injection: simulation abort")
}

err6 <- tryCatch(simulated_runner(t6_src), error = function(e) e$message)
assert("エラーが正常に発生した", grepl("Failure Injection", err6))
assert("中断後も元ディレクトリが復元されている", dir.exists(t6_src))
assert("中断時に中間ファイル(junk.txt)が消去されている", !file.exists(file.path(t6_src, "junk.txt")))
assert("中断後の復元マニフェストが事前データと完全一致する", identical(m_orig6, get_dir_manifest(t6_src)))

# [TEST 7] 退避後のマニフェスト不一致注入 (元データ保持 & バックアップ非削除で停止)
cat("\n[TEST 7] 退避後マニフェスト不一致注入 (元データ保持・バックアップ非削除)\n")
t7_src <- file.path(sandbox_root, "t7_data")
create_sample_dir(t7_src)
m_orig7 <- get_dir_manifest(t7_src)

err7 <- tryCatch({
  safe_backup_dir(t7_src, inject_manifest_mismatch = TRUE)
  NULL
}, error = function(e) e$message)

assert("退避後マニフェスト不一致時に即座にstop()する", !is.null(err7))
assert("エラーメッセージに元データ保持パスが含まれる", grepl("元データを保護するためバックアップを保持", err7))
backup_dirs7 <- list.files(sandbox_root, pattern = "^\\.backup_q_holder_", full.names = TRUE, all.files = TRUE)
assert("バックアップホルダーが削除されずに保護保持されている", length(backup_dirs7) > 0L)
preserved_path7 <- file.path(backup_dirs7[1], basename(t7_src))
assert("保護保持されたデータのマニフェストが元データと完全一致する", identical(m_orig7, get_dir_manifest(preserved_path7)))
# 検証完了後にクリーンアップ
unlink(backup_dirs7, recursive = TRUE, force = TRUE)

# [TEST 8] 復元後のマニフェスト不一致注入 (バックアップ非削除・安全保持)
cat("\n[TEST 8] 復元後マニフェスト不一致注入 (バックアップ非削除・安全保持)\n")
t8_src <- file.path(sandbox_root, "t8_data")
create_sample_dir(t8_src)
m_orig8 <- get_dir_manifest(t8_src)
b8 <- safe_backup_dir(t8_src)

suppressWarnings({
  ok_r8 <- safe_restore_dir(b8, t8_src, inject_manifest_mismatch = TRUE)
})
assert("復元後マニフェスト不一致時にFALSEが返る", !ok_r8)
assert("復元先が不一致でもバックアップディレクトリが削除されず保持される", dir.exists(b8$target))
assert("保持されたバックアップのマニフェストが元データと完全一致する", identical(m_orig8, get_dir_manifest(b8$target)))
assert("バックアップ親ホルダーが残存している", dir.exists(b8$parent))
# 検証完了後にクリーンアップ
unlink(b8$parent, recursive = TRUE, force = TRUE)

# ホルダー残留ゼロ確認
holder_remains <- list.files(sandbox_root, pattern = "^\\.backup_q_holder_", full.names = TRUE, all.files = TRUE)
assert("テスト終了時にバックアップホルダーが一切残留していない", length(holder_remains) == 0L)

cat("\n========================================================\n")
cat(sprintf("結果: %d passed, %d failed\n", pass, fail))
cat("========================================================\n")

if (fail > 0L) quit(status = 1L) else quit(status = 0L)
