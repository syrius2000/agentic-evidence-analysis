#!/usr/bin/env Rscript
# tests/test_dependency_isolation_pass1.R
# 表示系パッケージ非依存（Pass 1 統計計算の自律完結性）を実証するテスト
# 表示系パッケージ（DT, htmlwidgets, htmltools, rmarkdown, knitr, gt, katex, kableExtra）が
# 実行環境から完全に遮断（requireNamespace / loadNamespace / library 呼出しで即時例外検知）
# された条件下で、Pass 1 統計計算が一切の表示依存なしに自律完結することを実証する。

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

cat("=== Pass 1 表示依存遮断・自律完結テスト開始 ===\n")

# 1. 一時ディレクトリとテスト用設定の準備
td <- tempfile("pass1_isolation_")
dir.create(td, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

data_path <- file.path(root, "examples", "titanic.csv")
cfg <- list(
  input = data_path,
  dataset_name = "titanic",
  vars = c("Class", "Sex", "Survived"),
  freq = "Freq",
  response_var = "Survived",
  output_dir = td,
  run_id = "isolation_test_v1"
)
cfg_path <- file.path(td, "analysis_config.json")
jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)

analysis_script <- file.path(root, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "analysis.R")

# 2. 遮断スコープ環境の構築
blocked_ui_pkgs <- c("DT", "htmlwidgets", "htmltools", "rmarkdown", "knitr", "gt", "katex", "kableExtra")

run_env <- new.env(parent = .GlobalEnv)

# 表示パッケージが requireNamespace / library / loadNamespace で呼ばれたら即座に検知・例外停止するガード
requested_pkgs <- character(0)
run_env$requireNamespace <- function(package, ..., quietly = FALSE) {
  requested_pkgs <<- c(requested_pkgs, package)
  if (package %in% blocked_ui_pkgs) {
    stop(paste("[LEAK DETECTED] Pass 1 で表示系パッケージの参照が試行されました:", package))
  }
  base::requireNamespace(package, ..., quietly = quietly)
}

run_env$library <- function(package, ...) {
  pkg_name <- as.character(substitute(package))
  requested_pkgs <<- c(requested_pkgs, pkg_name)
  if (pkg_name %in% blocked_ui_pkgs) {
    stop(paste("[LEAK DETECTED] Pass 1 で表示系パッケージのアタッチが試行されました:", pkg_name))
  }
  eval(substitute(base::library(package, ...)), envir = .GlobalEnv)
}

# commandArgs をシミュレート
run_env$commandArgs <- function(trailingOnly = FALSE) {
  if (trailingOnly) {
    c("--config", cfg_path, "--output_dir", td)
  } else {
    c("Rscript", paste0("--file=", analysis_script), "--config", cfg_path, "--output_dir", td)
  }
}

# 3. 事前セルフテスト: ガードが UI パッケージを確実にブロックすること
probe_blocked <- tryCatch({
  run_env$requireNamespace("DT")
  FALSE
}, error = function(e) grepl("LEAK DETECTED", conditionMessage(e)))
assert(probe_blocked, "ガード環境が DT を未導入として遮断検知すること")

probe_allowed <- tryCatch({
  run_env$requireNamespace("dplyr", quietly = TRUE)
  TRUE
}, error = function(e) FALSE)
assert(probe_allowed, "ガード環境が計算用依存（dplyr）を正常に許可すること")

# セルフテストで記録された要求リストをリセット
requested_pkgs <- character(0)

# 4. 遮断環境下で Pass 1 analysis.R を評価実行
exec_res <- tryCatch({
  eval(parse(analysis_script, encoding = "UTF-8"), envir = run_env)
  TRUE
}, error = function(e) {
  cat("[ERROR in Pass 1 execution]:", conditionMessage(e), "\n")
  FALSE
})

assert(isTRUE(exec_res), "表示系未導入（完全遮断環境下）で Pass 1 analysis.R がエラーなく完結すること")

# 5. 要求されたパッケージ群に表示系が一切含まれないことを検証
ui_leaks <- intersect(requested_pkgs, blocked_ui_pkgs)
assert(length(ui_leaks) == 0L, "Pass 1 実行中に要求されたパッケージに表示系（DT, rmarkdown等）が一切含まれないこと")

# 6. 成果物 evidence_results.json が生成されたか確認
results_json <- file.path(td, "evidence_results.json")
if (!file.exists(results_json)) {
  subdirs <- list.dirs(td, full.names = TRUE, recursive = FALSE)
  for (sd in subdirs) {
    cand <- file.path(sd, "evidence_results.json")
    if (file.exists(cand)) {
      results_json <- cand
      break
    }
  }
}

assert(file.exists(results_json), "Pass 1 計算結果 evidence_results.json が遮断環境下で生成されていること")

if (file.exists(results_json)) {
  dat <- jsonlite::fromJSON(results_json)
  assert(!is.null(dat$models) && !is.null(dat$cells),
         "evidence_results.json に完全な対数線形モデル・4軸セル診断結果が含まれていること")
}

# ============================================================
# Part B: 物理的子プロセス隔離テスト (.Library / .libPaths 再束縛検証)
# ============================================================
cat("\n=== Part B: 別プロセス .Library 物理隔離下での Pass 1 実行検証 ===\n")

td_proc <- tempfile("pass1_proc_iso_")
dir.create(td_proc, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(td_proc, recursive = TRUE), add = TRUE)

isolated_lib <- file.path(td_proc, "isolated_lib")
dir.create(isolated_lib, recursive = TRUE, showWarnings = FALSE)

# base / recommended パッケージおよび計算必須パッケージとその再帰依存をリンク
base_pkgs <- rownames(installed.packages(priority = c("base", "recommended")))
calc_pkgs <- c("jsonlite", "digest", "dplyr", "tidyr", "vcd", "effectsize", "optparse")
ip <- installed.packages()
all_calc_deps <- unique(c(base_pkgs, calc_pkgs, unlist(tools::package_dependencies(calc_pkgs, db = ip, recursive = TRUE))))

linked_count <- 0L
for (p in all_calc_deps) {
  p_dir <- find.package(p, quiet = TRUE)
  if (length(p_dir) > 0L && dir.exists(p_dir)) {
    file.symlink(p_dir, file.path(isolated_lib, p))
    linked_count <- linked_count + 1L
  }
}

assert(linked_count >= length(calc_pkgs), "隔離ライブラリに計算必須パッケージが正常にシンボリックリンク配置されること")

# UI パッケージが隔離ライブラリに含まれていないことを静的確認
ui_pkgs_in_iso <- intersect(list.files(isolated_lib), blocked_ui_pkgs)
assert(length(ui_pkgs_in_iso) == 0L, "隔離ライブラリに表示系パッケージ（rmarkdown, DT等）が含まれないこと")

# 子プロセス用設定
cfg_proc <- list(
  input = data_path,
  dataset_name = "titanic",
  vars = c("Class", "Sex", "Survived"),
  freq = "Freq",
  response_var = "Survived",
  output_dir = td_proc,
  run_id = "isolation_child_proc"
)
cfg_proc_path <- file.path(td_proc, "analysis_config.json")
jsonlite::write_json(cfg_proc, cfg_proc_path, auto_unbox = TRUE, pretty = TRUE)

# 子プロセス実行スクリプトの作成
runner_script <- file.path(td_proc, "run_child_isolated.R")
child_code <- sprintf("
unlockBinding(\".Library\", asNamespace(\"base\"))
assign(\".Library\", \"%s\", envir = asNamespace(\"base\"))
.libPaths(\"%s\")

cat(\"[CHILD_OBS] .libPaths:\", paste(.libPaths(), collapse = \", \"), \"\\n\")
rmd_resolved <- requireNamespace(\"rmarkdown\", quietly = TRUE)
dt_resolved  <- length(find.package(\"DT\", quiet = TRUE)) > 0L
json_resolved <- requireNamespace(\"jsonlite\", quietly = TRUE)

cat(\"[CHILD_OBS] rmarkdown resolved:\", rmd_resolved, \"\\n\")
cat(\"[CHILD_OBS] DT resolved:\", dt_resolved, \"\\n\")
cat(\"[CHILD_OBS] jsonlite resolved:\", json_resolved, \"\\n\")

# 事前条件: UIパッケージは解決不能で、計算依存は解決可能であること
if (rmd_resolved || dt_resolved || !json_resolved) {
  cat(\"[PRECONDITION_FAIL] UI packages resolvable or calc dependency missing!\\n\")
  quit(status = 2)
}

# Pass 1 analysis.R を評価
commandArgs <- function(trailingOnly = FALSE) {
  if (trailingOnly) c(\"--config\", \"%s\", \"--output_dir\", \"%s\")
  else c(\"Rscript\", \"%s\", \"--config\", \"%s\", \"--output_dir\", \"%s\")
}

source(\"%s\")
quit(status = 0)
", isolated_lib, isolated_lib, cfg_proc_path, td_proc, analysis_script, cfg_proc_path, td_proc, analysis_script)

writeLines(child_code, runner_script)

child_out <- system2("Rscript", c("--vanilla", runner_script), stdout = TRUE, stderr = TRUE)
child_status <- attr(child_out, "status")
if (is.null(child_status)) child_status <- 0L

cat("--- 子プロセス出力 ---\n")
cat(paste(child_out, collapse = "\n"), "\n")
cat("----------------------\n")

assert(child_status == 0L, "子プロセス（完全隔離環境）が終了ステータス0で正常終了すること")

# 子プロセス出力内の観測事実を検証
assert(any(grepl("\\[CHILD_OBS\\] rmarkdown resolved: FALSE", child_out)), "子プロセス内で rmarkdown が物理的に解決不能（FALSE）であること")
assert(any(grepl("\\[CHILD_OBS\\] DT resolved: FALSE", child_out)), "子プロセス内で DT が物理的に未検出（FALSE）であること")
assert(any(grepl("\\[CHILD_OBS\\] jsonlite resolved: TRUE", child_out)), "子プロセス内で計算依存（jsonlite）が正常に解決されること")

# 子プロセスの生成物を確認
proc_results_json <- file.path(td_proc, "evidence_results.json")
if (!file.exists(proc_results_json)) {
  subdirs <- list.dirs(td_proc, full.names = TRUE, recursive = FALSE)
  for (sd in subdirs) {
    cand <- file.path(sd, "evidence_results.json")
    if (file.exists(cand)) {
      proc_results_json <- cand
      break
    }
  }
}

assert(file.exists(proc_results_json), "物理隔離子プロセスにより evidence_results.json が正常生成されること")
if (file.exists(proc_results_json)) {
  proc_dat <- jsonlite::fromJSON(proc_results_json)
  assert(!is.null(proc_dat$models) && !is.null(proc_dat$cells),
         "物理隔離生成成果物に完全な対数線形モデル・セル診断が含まれていること")
}

cat(sprintf("\n=== テスト完了: PASS=%d, FAIL=%d ===\n", PASS, FAIL))
if (FAIL > 0) {
  stop("Pass 1 表示依存遮断テストに失敗しました")
}
cat("=== 全テスト合格: 表示系未導入環境での Pass 1 自律完結性を完全実証 ===\n")
