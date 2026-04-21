#!/usr/bin/env Rscript
# test_security_skill_references.R
# security-vulnerability-check スキルのリファレンスファイル存在・内容検証
# TDD RED: 新規 r_cpp_security.md の存在と主要キーワードを検証

Sys.setlocale("LC_ALL", "ja_JP.UTF-8")

args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_path) == 0L) script_path <- "tests/test_security_skill_references.R"
ws <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

# 本リポジトリは README の「管理スキル一覧」のみ同梱。security-vulnerability-check は別管理のため未同梱のときスキップする。
sec_agent <- file.path(ws, ".agent", "skills", "security-vulnerability-check")
if (!dir.exists(sec_agent)) {
  message("SKIP: security-vulnerability-check not in .agent/skills (see README.md).")
  quit(status = 0L)
}

pass <- 0L
fail <- 0L

check <- function(cond, msg) {
  if (cond) {
    cat(sprintf("[PASS] %s\n", msg))
    pass <<- pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", msg))
    fail <<- fail + 1L
  }
}

# --- 両ディレクトリのベースパス ---
dirs <- c(
  file.path(ws, ".agent", "skills", "security-vulnerability-check"),
  file.path(ws, ".cursor", "skills", "security-vulnerability-check")
)

if (!any(dir.exists(dirs))) {
  cat("[SKIP] security-vulnerability-check skill not found under .agent/.cursor; skipping reference checks.\n")
  quit(status = 0)
}

for (d in dirs) {
  label <- basename(dirname(dirname(d))) # .agent or .cursor

  if (!dir.exists(d)) {
    cat(sprintf("[SKIP] %s: directory not found (%s)\n", label, d))
    next
  }

  # 1. 既存ファイル存在確認
  check(
    file.exists(file.path(d, "SKILL.md")),
    sprintf("%s: SKILL.md exists", label)
  )
  check(
    file.exists(file.path(d, "references", "vulnerability_checklist.md")),
    sprintf("%s: vulnerability_checklist.md exists", label)
  )
  check(
    file.exists(file.path(d, "references", "python_sql_security.md")),
    sprintf("%s: python_sql_security.md exists", label)
  )
  check(
    file.exists(file.path(d, "scripts", "run_static_analysis.py")),
    sprintf("%s: run_static_analysis.py exists", label)
  )

  # 2. 新規 r_cpp_security.md 存在確認
  r_cpp_path <- file.path(d, "references", "r_cpp_security.md")
  check(
    file.exists(r_cpp_path),
    sprintf("%s: r_cpp_security.md exists", label)
  )

  if (file.exists(r_cpp_path)) {
    txt <- paste(readLines(r_cpp_path, warn = FALSE), collapse = "\n")
    # R セキュリティキーワード
    check(grepl("system\\(", txt), sprintf("%s: R system() mentioned", label))
    check(
      grepl("eval.*parse", txt, ignore.case = TRUE),
      sprintf("%s: R eval(parse()) mentioned", label)
    )
    # C++ セキュリティキーワード
    check(
      grepl("buffer.?overflow", txt, ignore.case = TRUE),
      sprintf("%s: C++ buffer overflow mentioned", label)
    )
    check(
      grepl("format.?string", txt, ignore.case = TRUE),
      sprintf("%s: C++ format string mentioned", label)
    )
  }

  # 3. セキュリティレポートテンプレート存在確認
  rmd_path <- file.path(d, "templates", "security_report.Rmd")
  check(
    file.exists(rmd_path),
    sprintf("%s: security_report.Rmd exists", label)
  )

  if (file.exists(rmd_path)) {
    rmd_txt <- paste(readLines(rmd_path, warn = FALSE), collapse = "\n")
    check(
      grepl("severity", rmd_txt, ignore.case = TRUE),
      sprintf("%s: Rmd mentions severity", label)
    )
    check(
      grepl("summary", rmd_txt, ignore.case = TRUE),
      sprintf("%s: Rmd mentions summary", label)
    )
    check(
      grepl("ggplot2|ggplot", rmd_txt),
      sprintf("%s: Rmd uses ggplot2", label)
    )
  }

  # 4. SKILL.md が r_cpp_security.md を参照しているか
  skill_txt <- paste(readLines(file.path(d, "SKILL.md"), warn = FALSE), collapse = "\n")
  check(
    grepl("r_cpp_security", skill_txt),
    sprintf("%s: SKILL.md references r_cpp_security", label)
  )
  check(
    grepl("security_report", skill_txt, ignore.case = TRUE),
    sprintf("%s: SKILL.md references security_report", label)
  )
}

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  cat("FAIL: some security reference tests failed.\n")
  quit(status = 1)
} else {
  cat("OK: security reference tests passed.\n")
}
