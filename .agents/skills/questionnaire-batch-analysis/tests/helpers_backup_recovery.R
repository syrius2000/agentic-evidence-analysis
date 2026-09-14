# helpers_backup_recovery.R
# questionnaire-batch-analysis テスト用 成果物保護（退避・復元）共有ヘルパー

# 成果物マニフェスト取得関数（相対パス・サイズ・SHA-256）
get_dir_manifest <- function(dir_path) {
  if (!dir.exists(dir_path)) return(NULL)
  files <- list.files(dir_path, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  if (length(files) == 0L) return(list(rel_path = character(0), size = numeric(0), sha256 = character(0)))
  is_reg_file <- !dir.exists(files)
  files <- files[is_reg_file]
  if (length(files) == 0L) return(list(rel_path = character(0), size = numeric(0), sha256 = character(0)))
  prefix <- paste0(normalizePath(dir_path, winslash = "/", mustWork = TRUE), "/")
  norm_files <- normalizePath(files, winslash = "/", mustWork = TRUE)
  rel_paths <- substring(norm_files, nchar(prefix) + 1L)
  hashes <- sapply(files, function(f) digest::digest(f, file = TRUE), USE.NAMES = FALSE)
  sizes <- file.info(files)$size
  ord <- order(rel_paths)
  list(rel_path = rel_paths[ord], size = sizes[ord], sha256 = hashes[ord])
}

# 既存成果物の安全な保護（退避・復元メカニズム）
# inject_* はテスト時の失敗注入専用フック（既定 FALSE）
safe_backup_dir <- function(src_dir,
                            inject_rename_fail = FALSE,
                            inject_copy_fail = FALSE,
                            inject_manifest_mismatch = FALSE) {
  if (!dir.exists(src_dir)) return(NULL)
  src_manifest <- get_dir_manifest(src_dir)
  parent_backup <- tempfile(pattern = ".backup_q_holder_", tmpdir = dirname(src_dir))
  if (file.exists(parent_backup) || dir.exists(parent_backup)) {
    stop(sprintf("[CRITICAL] バックアップホルダーが既に存在します: %s", parent_backup))
  }
  dir.create(parent_backup, recursive = FALSE, showWarnings = FALSE)
  if (!dir.exists(parent_backup)) {
    stop(sprintf("[CRITICAL] バックアップ親ディレクトリの作成に失敗: %s", parent_backup))
  }
  target_backup <- file.path(parent_backup, basename(src_dir))

  # 1. file.rename() によるアトミック移動試行
  renamed <- if (inject_rename_fail) FALSE else tryCatch(file.rename(src_dir, target_backup), error = function(e) FALSE)
  if (renamed && dir.exists(target_backup) && !dir.exists(src_dir)) {
    target_manifest <- get_dir_manifest(target_backup)
    if (!inject_manifest_mismatch && identical(src_manifest, target_manifest)) {
      return(list(parent = parent_backup, target = target_backup, manifest = src_manifest))
    }
    # 重要: rename成功後にマニフェスト不一致が発生した場合、元データは target_backup にのみ存在する。
    # parent_backup を絶対に削除せず保持したまま stop する。
    stop(sprintf(
      "[CRITICAL] 退避後のマニフェスト不一致。元データを保護するためバックアップを保持して停止します: %s",
      target_backup
    ))
  }

  # 2. file.rename() 失敗時の file.copy() フォールバック試行（src_dir は無傷で残存）
  copied <- if (inject_copy_fail) FALSE else tryCatch(file.copy(src_dir, parent_backup, recursive = TRUE), error = function(e) FALSE)
  if (isTRUE(copied) && dir.exists(target_backup)) {
    target_manifest <- get_dir_manifest(target_backup)
    if (!inject_manifest_mismatch && identical(src_manifest, target_manifest)) {
      unlink(src_dir, recursive = TRUE, force = TRUE)
      return(list(parent = parent_backup, target = target_backup, manifest = src_manifest))
    }
  }

  # コピー失敗またはコピー先マニフェスト不一致時:
  # src_dir は変更されておらず完全に無傷。失敗した作業ホルダー parent_backup のみ清掃して停止。
  unlink(parent_backup, recursive = TRUE, force = TRUE)
  stop(sprintf("[CRITICAL] 既存成果物の安全な退避に失敗しました: %s。元データを保護するためテストを中止します。", src_dir))
}

# 成果物復元関数（方法A: 常にコピー方式を採用し、完全一致が確認されるまで元バックアップを削除しない）
safe_restore_dir <- function(backup_info,
                             dest_dir,
                             inject_copy_fail = FALSE,
                             inject_manifest_mismatch = FALSE) {
  if (is.null(backup_info)) {
    if (dir.exists(dest_dir)) unlink(dest_dir, recursive = TRUE, force = TRUE)
    return(TRUE)
  }
  target_backup <- backup_info$target
  parent_backup <- backup_info$parent
  orig_manifest <- backup_info$manifest
  if (!dir.exists(target_backup)) {
    warning(sprintf("[CRITICAL] バックアップディレクトリが見つかりません: %s", target_backup))
    return(FALSE)
  }

  # テスト成果物が dest_dir に残っている場合は事前削除
  if (dir.exists(dest_dir)) {
    unlink(dest_dir, recursive = TRUE, force = TRUE)
  }

  # 方法A: target_backup を変更せず file.copy() で dest_dir の親ディレクトリへ復元
  copied <- if (inject_copy_fail) FALSE else tryCatch(file.copy(target_backup, dirname(dest_dir), recursive = TRUE), error = function(e) FALSE)
  if (isTRUE(copied) && dir.exists(dest_dir)) {
    dest_manifest <- get_dir_manifest(dest_dir)
    if (!inject_manifest_mismatch && identical(orig_manifest, dest_manifest)) {
      # 復元先の完全一致が確認された場合のみ、バックアップホルダーを削除
      unlink(parent_backup, recursive = TRUE, force = TRUE)
      return(TRUE)
    }
  }

  # コピー失敗またはマニフェスト不一致時:
  # target_backup は一切削除せず保持する。
  warning(sprintf(
    "[CRITICAL] 成果物の復元またはSHA-256マニフェスト照合に失敗しました。\n元データはバックアップとして保護保持されています: %s\n手動で %s へ移動してください。",
    target_backup, dest_dir
  ))
  return(FALSE)
}
