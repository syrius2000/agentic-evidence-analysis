#!/usr/bin/env Rscript
# tests/test_vcd_interpretation_guide.R
# dashboard.Rmd に残差解釈ガイド（閾値・解釈）が存在することを検証（vcd 不要）
# Run: Rscript tests/test_vcd_interpretation_guide.R

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}

# --- 対象: vcd-categorical-analysis dashboard.Rmd ---
vcd_paths <- c(
  file.path(repo, ".cursor/skills/vcd-categorical-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agent/skills/vcd-categorical-analysis/templates/dashboard.Rmd")
)

# --- 対象: questionnaire-batch-analysis dashboard.Rmd ---
qba_paths <- c(
  file.path(repo, ".cursor/skills/questionnaire-batch-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agent/skills/questionnaire-batch-analysis/templates/dashboard.Rmd")
)

pass <- 0L
fail <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    cat("[PASS]", label, "\n")
    pass <<- pass + 1L
  } else {
    cat("[FAIL]", label, "\n")
    fail <<- fail + 1L
  }
}

for (p in vcd_paths) {
  check(paste("file exists:", basename(dirname(dirname(p)))), file.exists(p))
  if (!file.exists(p)) next
  lines <- readLines(p, warn = FALSE)

  # ±1.96 の閾値説明が含まれる
  check(
    paste("±1.96 threshold explanation:", p),
    any(grepl("1\\.96", lines))
  )

  # ±2.58 の閾値説明が含まれる
  check(
    paste("±2.58 threshold explanation:", p),
    any(grepl("2\\.58", lines))
  )

  # 正残差・負残差の解釈が含まれる
  check(
    paste("positive/negative residual interpretation:", p),
    any(grepl("(正の残差|positive residual|期待より多)", lines, ignore.case = TRUE))
  )

  # 効果量の解釈基準
  check(
    paste("effect size interpretation guide:", p),
    any(grepl("(Cramer|効果量|effect size)", lines, ignore.case = TRUE))
  )
}

for (p in qba_paths) {
  check(paste("file exists:", basename(dirname(dirname(p)))), file.exists(p))
  if (!file.exists(p)) next
  lines <- readLines(p, warn = FALSE)

  check(
    paste("±1.96 threshold explanation:", p),
    any(grepl("1\\.96", lines))
  )
  check(
    paste("±2.58 threshold explanation:", p),
    any(grepl("2\\.58", lines))
  )
}

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) stop("Some interpretation guide tests failed.")
message("OK: interpretation guide tests passed.")
