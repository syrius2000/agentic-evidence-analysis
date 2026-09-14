#!/usr/bin/env Rscript
# tests/test_dependency_check.R
# 共有依存検査モジュール (.agents/shared/dependency_check.R) の単体回帰テスト

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

dep_check_path <- file.path(root, ".agents", "shared", "dependency_check.R")
if (!file.exists(dep_check_path)) {
  stop("dependency_check.R が見つかりません: ", dep_check_path)
}

source(dep_check_path)

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

cat("=== dependency_check.R 単体テスト開始 ===\n")

# 1. 正常系: 組み込みパッケージ
res_base <- tryCatch({
  check_r_dependencies(c("base", "stats"), context = "テスト環境")
  TRUE
}, error = function(e) FALSE)
assert(res_base, "base, stats 依存検査が正常にパスすること")

# 2. 空ベクトル
res_empty <- tryCatch({
  check_r_dependencies(character(0), context = "空依存テスト")
  TRUE
}, error = function(e) FALSE)
assert(res_empty, "空ベクトル指定で正常終了すること")

# 3. 異常系 (Fail-Fast): 存在しないパッケージ
err_msg <- NULL
res_missing <- tryCatch({
  check_r_dependencies(c("non_existent_pkg_xyz_123"), context = "異常系テスト")
  FALSE
}, error = function(e) {
  err_msg <<- e$message
  TRUE
})
assert(res_missing, "存在しないパッケージ指定で stop() が発生すること")
assert(!is.null(err_msg) && grepl("non_existent_pkg_xyz_123", err_msg),
       "エラーメッセージに対象パッケージ名が含まれること")
assert(!is.null(err_msg) && grepl("install\\.packages", err_msg),
       "エラーメッセージに install.packages 案内が含まれること")
assert(!is.null(err_msg) && grepl("異常系テスト", err_msg),
       "エラーメッセージに指定した context が含まれること")

cat(sprintf("\n結果: PASS=%d, FAIL=%d\n", PASS, FAIL))
if (FAIL > 0) {
  stop("回帰テストに失敗しました")
}
cat("=== 全テスト合格 ===\n")
