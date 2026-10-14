#!/usr/bin/env Rscript
# tests/test_run_scope_lock.R
# T2.6 / R3: lock_info.json の原子的書込、書込失敗時のロックディレクトリ残存防止、
# 排他ロック取得・解放の整合性、および署名ロック（acquire_signature_lock）を検証する。

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

# テスト用正規出力ルート
test_out_root <- file.path(repo_root, "evidence_runs", "vcd_categorical", paste0(".test_lock_", Sys.getpid()))
dir.create(test_out_root, recursive = TRUE, showWarnings = FALSE)

cleanup <- function() {
  if (dir.exists(test_out_root)) {
    unlink(test_out_root, recursive = TRUE, force = TRUE)
  }
}

make_valid_run <- function(run_name = "run_test_01") {
  r_dir <- file.path(test_out_root, run_name)
  dir.create(r_dir, recursive = TRUE, showWarnings = FALSE)
  meta <- list(
    interface_version = "2.0",
    path_schema_version = RUN_SCOPE_PATH_SCHEMA_VERSION,
    skill = "vcd-categorical-analysis",
    run_state = "active",
    out_root = test_out_root,
    run_output_dir = r_dir,
    pass_status = list(
      pass1 = "completed",
      pass2 = "pending",
      pass3 = "pending"
    )
  )
  jsonlite::write_json(meta, file.path(r_dir, "run_meta.json"), auto_unbox = TRUE, pretty = TRUE)
  r_dir
}

passed <- 0L
failed <- 0L

check <- function(desc, cond) {
  if (isTRUE(cond)) {
    passed <<- passed + 1L
  } else {
    failed <<- failed + 1L
    cat(sprintf("[FAIL] %s\n", desc))
  }
}

tryCatch({
  valid_run <- make_valid_run("run_stage_01")

  # 1. 正常な stage ロック取得と解放
  lock1 <- acquire_stage_lock(valid_run, "run")
  check("ロック1が取得でき、lock_dirが存在する", !is.null(lock1) && dir.exists(lock1$lock_dir))
  info_file <- file.path(lock1$lock_dir, "lock_info.json")
  check("lock_info.json が存在する", file.exists(info_file))

  # 保持中の再取得は拒絶されること
  re_lock <- tryCatch({
    acquire_stage_lock(valid_run, "run")
    "ACQUIRED"
  }, error = function(e) "REFUSED")
  check("保持中の同一stage排他ロック再取得が拒絶される", identical(re_lock, "REFUSED"))

  # ロック解放
  rel_ok <- release_stage_lock(lock1)
  check("ロック解放が成功する", isTRUE(rel_ok))
  check("ロック解放後にロックディレクトリが残存しない", !dir.exists(lock1$lock_dir))

  # 2. 改ざんされたtokenでの解放拒絶
  lock2 <- acquire_stage_lock(valid_run, "run")
  fake_lock <- lock2
  fake_lock$info$token <- "tampered_token"
  refused <- tryCatch({
    release_stage_lock(fake_lock)
    FALSE
  }, error = function(e) TRUE)
  check("改ざんされたtokenでのロック解放が拒絶される", isTRUE(refused))
  release_stage_lock(lock2)

  # 3. [R3 コア検証]: lock_info.json 書込失敗時にロックディレクトリが残らないこと
  # atomic_run_json を一時的にエラーを投げる関数に差し替えて検証
  orig_atomic_run_json <- atomic_run_json
  atomic_run_json <- function(...) {
    stop("模擬的なディスク書き込みエラー")
  }

  write_fail_occurred <- FALSE
  tryCatch({
    acquire_stage_lock(valid_run, "run")
  }, error = function(e) {
    if (grepl("lock_info.json の原子的書込に失敗", conditionMessage(e))) {
      write_fail_occurred <<- TRUE
    }
  })

  # 関数を元に戻す
  atomic_run_json <- orig_atomic_run_json

  control_dir <- run_control_dir(valid_run)
  stage_lock_path <- file.path(control_dir, "run.lock")
  check("書き込み失敗時に例外が発生した", isTRUE(write_fail_occurred))
  check("書き込み失敗時にロックディレクトリが残留せずクリーンアップされている", !dir.exists(stage_lock_path))

  # 4. acquire_signature_lock の検証
  sig_val <- "test_sig_1234567890abcdef"
  sig_lock <- acquire_signature_lock(test_out_root, "vcd-categorical-analysis", sig_val)
  check("署名ロックが取得できる", isTRUE(sig_lock$acquired))
  check("署名ロックディレクトリが存在する", dir.exists(sig_lock$lock_dir))

  # 同一署名の重複取得は拒絶されること
  sig_lock_re <- acquire_signature_lock(test_out_root, "vcd-categorical-analysis", sig_val)
  check("同一署名の重複ロック取得が拒絶される", !isTRUE(sig_lock_re$acquired))
  check("重複拒絶エラーコードが CONCURRENT_RUN_IN_PROGRESS", identical(sig_lock_re$error_code, "CONCURRENT_RUN_IN_PROGRESS"))

  # 署名ロック解放
  rel_sig_ok <- release_signature_lock(sig_lock)
  check("署名ロック解放が成功する", isTRUE(rel_sig_ok))
  check("署名ロック解放後にロックディレクトリが残存しない", !dir.exists(sig_lock$lock_dir))

  # 5. [R7-4 追加検証]: acquire_signature_lock の lock_info.json 書込失敗時にロックディレクトリが残らないこと
  atomic_run_json <- function(...) {
    stop("署名ロック lock_info.json 書き込み模擬エラー")
  }
  sig_write_fail <- FALSE
  tryCatch({
    acquire_signature_lock(test_out_root, "vcd-categorical-analysis", "fail_sig_123456789")
  }, error = function(e) {
    if (grepl("lock_info.json の原子的書込に失敗", conditionMessage(e))) {
      sig_write_fail <<- TRUE
    }
  })
  atomic_run_json <- orig_atomic_run_json
  sig_lock_path <- file.path(test_out_root, ".run_locks", "fail_sig_12345678.lock")
  check("署名ロック書込失敗時に例外が発生した", isTRUE(sig_write_fail))
  check("署名ロック書込失敗時にロックディレクトリが残留せずクリーンアップされている", !dir.exists(sig_lock_path))

  # 6. [R7-4 追加検証]: 署名ロックの token 改ざん時の挙動（warning 発出かつ解放拒絶）
  sig_lock_tamper <- acquire_signature_lock(test_out_root, "vcd-categorical-analysis", "tamper_sig_123456")
  fake_sig_lock <- sig_lock_tamper
  fake_sig_lock$token <- "tampered_signature_token"
  warn_caught <- FALSE
  res_tamper <- withCallingHandlers({
    release_signature_lock(fake_sig_lock)
  }, warning = function(w) {
    if (grepl("ロック所有tokenが一致しない", conditionMessage(w))) {
      warn_caught <<- TRUE
    }
    invokeRestart("muffleWarning")
  })
  check("token 改ざん時に warning が発出される", isTRUE(warn_caught))
  check("token 改ざん時の release_signature_lock が FALSE を返す", identical(res_tamper, FALSE))
  check("改ざん解放拒絶後にロックディレクトリが保護・残存している", dir.exists(sig_lock_tamper$lock_dir))
  # 正しい token で解放
  release_signature_lock(sig_lock_tamper)
  check("正規トークンで解放できる", !dir.exists(sig_lock_tamper$lock_dir))

  # 7. [追加作業]: 実際の lock_info.json (pid と acquired_at を持つ) を置いたロックに対する競合で、
  # 失敗情報に pid と acquired_at が含まれることの検証
  sig_holder_test <- "holder_sig_123456"
  sig_holder_dir <- file.path(test_out_root, ".run_locks", paste0(substr(sig_holder_test, 1L, 16L), ".lock"))
  dir.create(sig_holder_dir, recursive = TRUE, showWarnings = FALSE)
  dummy_lock_info <- list(
    pid = 99999L,
    hostname = "test-node",
    stage = "run",
    skill = "vcd-categorical-analysis",
    signature = sig_holder_test,
    token = "test_token_holder",
    acquired_at = "2026-10-13T21:00:00+0900"
  )
  jsonlite::write_json(dummy_lock_info, file.path(sig_holder_dir, "lock_info.json"), auto_unbox = TRUE)
  sig_conflict_res <- acquire_signature_lock(test_out_root, "vcd-categorical-analysis", sig_holder_test)
  check("既存ロック競合時に acquired == FALSE", !isTRUE(sig_conflict_res$acquired))
  check("既存ロック競合時に error_code == CONCURRENT_RUN_IN_PROGRESS", identical(sig_conflict_res$error_code, "CONCURRENT_RUN_IN_PROGRESS"))
  check("既存ロック競合時に pid が取得される", identical(as.integer(sig_conflict_res$pid), 99999L))
  check("既存ロック競合時に acquired_at が取得される", identical(as.character(sig_conflict_res$acquired_at), "2026-10-13T21:00:00+0900"))
  unlink(sig_holder_dir, recursive = TRUE, force = TRUE)

  # 8. [追加作業]: ロック領域に書込権限がない場合、CONCURRENT_RUN_IN_PROGRESS ではなく CANNOT_CREATE_LOCK_DIR になることの検証
  is_root_user <- tryCatch(identical(system("id -u", intern = TRUE), "0"), error = function(e) FALSE)
  if (is_root_user) {
    cat("  [SKIP] root 権限で実行中のため書込権限拒否テストをスキップ\n")
  } else {
    ro_root <- file.path(test_out_root, "readonly_test_area")
    dir.create(file.path(ro_root, ".run_locks"), recursive = TRUE, showWarnings = FALSE)
    # .run_locks ディレクトリを読取専用 (0555) に変更して配下ディレクトリ作成を阻害
    Sys.chmod(file.path(ro_root, ".run_locks"), mode = "0555")
    ro_res <- acquire_signature_lock(ro_root, "vcd-categorical-analysis", "ro_test_sig_12345")
    check("権限不足時に acquired == FALSE", !isTRUE(ro_res$acquired))
    check("権限不足時の error_code == CANNOT_CREATE_LOCK_DIR", identical(ro_res$error_code, "CANNOT_CREATE_LOCK_DIR"))
    check("権限不足時の error_message に権限不足理由が含まれる", grepl("ロックディレクトリを作成できません", ro_res$error_message))
    # 後始末: 権限を戻してから削除
    Sys.chmod(file.path(ro_root, ".run_locks"), mode = "0755")
    unlink(ro_root, recursive = TRUE, force = TRUE)
  }

}, finally = {
  cleanup()
})

cat(sprintf("test_run_scope_lock: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
