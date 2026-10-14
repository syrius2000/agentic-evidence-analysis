#!/usr/bin/env Rscript
# tests/test_run_scope_environment.R
# Task 1.1: collect_run_environment(), manifest_roles(), session_info.txt, and write_run_meta() environment block test

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

source(file.path(repo_root, ".agents", "shared", "run_scope.R"))

test_dir <- tempfile("test_env_")
dir.create(test_dir, recursive = TRUE)

cleanup <- function() {
  if (dir.exists(test_dir)) {
    unlink(test_dir, recursive = TRUE, force = TRUE)
  }
}

passed <- 0L
failed <- 0L

check <- function(label, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("[PASS] %s\n", label))
    passed <<- passed + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", label))
    failed <<- failed + 1L
  }
}

tryCatch({
  # 1. collect_run_environment() の単体検証
  env_info <- collect_run_environment(seed = 12345L)
  check("collect_run_environment returns list", is.list(env_info))
  check("required key r_version exists", !is.null(env_info$r_version) && is.character(env_info$r_version))
  check("required key platform exists", !is.null(env_info$platform) && is.character(env_info$platform))
  check("platform equals R.version$platform", identical(env_info$platform, R.version$platform))
  check("required key packages exists and is list", is.list(env_info$packages) && length(env_info$packages) > 0L)
  
  # packages内の要素検証
  pkg1 <- env_info$packages[[1]]
  check("package element has name and version", !is.null(pkg1$name) && !is.null(pkg1$version))
  
  check("required key seed exists and matches", identical(env_info$seed, 12345L))
  check("required key session_info_path exists", identical(env_info$session_info_path, "session_info.txt"))
  
  # 2. manifest_roles() への "environment_info" 追加検証
  all_skills <- c(
    "vcd-bayesian-evidence-analysis",
    "vcd-categorical-analysis",
    "vcd-categorical-reporting",
    "questionnaire-batch-analysis",
    "sas-proc-freq",
    "sas-proc-means",
    "evidence-decision-review"
  )
  for (sk in all_skills) {
    roles <- manifest_roles(sk)
    check(sprintf("manifest_roles contains environment_info for %s", sk), "environment_info" %in% roles)
  }
  
  # 3. write_results_manifest() による session_info.txt 自動登録と書込順・パス置換検証
  run_dir <- file.path(test_dir, "run_env_test")
  dir.create(run_dir, recursive = TRUE)
  # primary results を作成
  cat('{"status": "ok"}\n', file = file.path(run_dir, "categorical_results.json"))
  
  # session_info.txt は事前作成していなくても write_results_manifest 内で生成・自動追加されること
  art_in <- list(
    list(path = "categorical_results.json", role = "primary_results")
  )
  m_res <- write_results_manifest(run_dir, "vcd-categorical-analysis", art_in)
  
  sess_txt_path <- file.path(run_dir, "session_info.txt")
  check("session_info.txt created on disk", file.exists(sess_txt_path))
  check("session_info.txt is registered in results_manifest.json", any(vapply(m_res$manifest$artifacts, function(a) a$path == "session_info.txt", logical(1))))
  
  # session_info.txt の内容検証 (M1)
  sess_lines <- readLines(sess_txt_path, warn = FALSE)
  sess_full <- paste(sess_lines, collapse = "\n")
  check("session_info.txt contains R version", grepl("R version", sess_full))
  # 絶対パスが残っていないことの検証（BLAS, LAPACK行に /Library や /usr や /home や C: 等の複数階層絶対パスがないこと）
  blas_lapack_lines <- sess_lines[grepl("^(BLAS|LAPACK):", trimws(sess_lines))]
  has_abs_path <- any(grepl("(?:/[^ \t\r\n;,/]+)+/[^ \t\r\n;,]+|[A-Za-z]:[/\\\\]", blas_lapack_lines, perl = TRUE))
  check("session_info.txt BLAS/LAPACK lines contain no absolute paths", !has_abs_path)
  
  # 4. write_run_meta() による environment ブロックの記録
  meta_res <- write_run_meta(
    out_root = test_dir,
    run_output_dir = run_dir,
    skill = "vcd-categorical-analysis",
    run_id = "run_env_test",
    extra = list(results_manifest_sha256 = m_res$manifest_sha256, seed = 12345L)
  )
  
  meta_loaded <- jsonlite::read_json(file.path(run_dir, "run_meta.json"))
  check("run_meta.json contains environment block", !is.null(meta_loaded$environment))
  check("run_meta.json environment has r_version", !is.null(meta_loaded$environment$r_version))
  check("run_meta.json environment has packages", length(meta_loaded$environment$packages) > 0L)
  check("run_meta.json environment has seed", identical(as.integer(meta_loaded$environment$seed), 12345L))
  check("run_meta.json environment has session_info_path", identical(meta_loaded$environment$session_info_path, "session_info.txt"))
  
  # 5. read_run_control() の寛容性検証（旧run_metaにenvironmentがなくても読み込めること）
  legacy_run_dir <- file.path(test_dir, "run_legacy")
  dir.create(legacy_run_dir, recursive = TRUE)
  legacy_meta <- meta_loaded
  legacy_meta$environment <- NULL
  jsonlite::write_json(legacy_meta, file.path(legacy_run_dir, "run_meta.json"), auto_unbox = TRUE)
  read_legacy <- read_run_control(legacy_run_dir)
  check("read_run_control tolerates missing environment block with NULL", is.null(read_legacy$environment))
  
}, finally = {
  cleanup()
})

cat(sprintf("\ntest_run_scope_environment: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
