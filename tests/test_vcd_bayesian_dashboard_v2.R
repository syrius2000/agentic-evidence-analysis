# tests/test_vcd_bayesian_dashboard_v2.R
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}

if (!requireNamespace("rmarkdown", quietly = TRUE) || !requireNamespace("knitr", quietly = TRUE)) {
  message("SKIP: rmarkdown or knitr not installed")
  quit(status = 0L)
}

# まず最新の fixture を生成
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
fixd <- file.path(root, "tests/fixtures/vcd_bayesian_dashboard")
system2("Rscript", c(analysis, "--output_dir", fixd))

rmd <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
stopifnot(file.exists(rmd)) # 参照用（レンダーは render_dashboard.R 経由）
jp <- list.files(fixd, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
jp <- jp[grepl("/run_[0-9a-f]{16}/evidence_results", jp)]
if (length(jp) == 0L) {
  jp <- list.files(fixd, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
}
stopifnot(length(jp) >= 1L)
if (length(jp) > 1L) {
  info <- file.info(jp)
  jp <- jp[which.max(info$mtime)]
} else {
  jp <- jp[1L]
}
fixd_run <- dirname(jp)

summ_src <- file.path(fixd, "executive_summary.md")
stopifnot(file.exists(summ_src))
invisible(file.copy(summ_src, file.path(fixd_run, "executive_summary.md"), overwrite = TRUE))

render_dash <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R")
stopifnot(file.exists(render_dash))
st <- system2("Rscript", c(render_dash, "--output_dir", fixd))
stopifnot(identical(as.integer(st), 0L))

outf <- file.path(fixd_run, "dashboard.html")
stopifnot(file.exists(outf))
stopifnot(identical(dirname(outf), dirname(jp[1L])))
html <- paste(readLines(outf, warn = FALSE), collapse = "\n")

# Cramér's V カードが存在
stopifnot(grepl("Cram", html, fixed = TRUE))

# 用語解説セクション（<details>タグ）
stopifnot(grepl("<details", html, fixed = TRUE))
stopifnot(grepl("Evidence Score", html, fixed = TRUE))

# Top-K セクション
stopifnot(grepl("Top-", html, fixed = FALSE))

# 折りたたみ全テーブル
stopifnot(grepl("all-cells-detail", html, fixed = TRUE))

# 色分け（青/赤）
stopifnot(grepl("#2980b9", html, fixed = TRUE) || grepl("#3498db", html, fixed = TRUE))

unlink(outf) # フィクスチャ run 配下に成果物を残さない
message("OK: dashboard v2 features verified")