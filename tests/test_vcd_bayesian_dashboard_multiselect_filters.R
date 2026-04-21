# dashboard.Rmd: 全セル表のカテゴリ列に複数水準フィルタ（select multiple）が含まれること
# Run from repo root: Rscript tests/test_vcd_bayesian_dashboard_multiselect_filters.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}

if (!requireNamespace("rmarkdown", quietly = TRUE) || !requireNamespace("knitr", quietly = TRUE)) {
  message("SKIP: rmarkdown or knitr not installed")
  quit(status = 0L)
}

rmd <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
stopifnot(file.exists(rmd))

fixd_src <- file.path(root, "tests/fixtures/vcd_bayesian_dashboard")
summ_src <- file.path(fixd_src, "executive_summary.md")
stopifnot(file.exists(summ_src))

fixd <- tempfile("vcd_dash_ms_")
dir.create(fixd)
on.exit(unlink(fixd, recursive = TRUE), add = TRUE)

analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))
system2("Rscript", c(analysis, "--output_dir", fixd))
jp <- list.files(fixd, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
run_dir <- dirname(jp[1L])
invisible(file.copy(summ_src, file.path(run_dir, "executive_summary.md"), overwrite = TRUE))

render_dash <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R")
stopifnot(file.exists(render_dash))
st <- system2("Rscript", c(render_dash, "--output_dir", fixd))
stopifnot(identical(as.integer(st), 0L))

outf <- file.path(run_dir, "dashboard.html")
stopifnot(file.exists(outf))
html <- paste(readLines(outf, warn = FALSE), collapse = "\n")

stopifnot(grepl("data-vcd-filter", html, fixed = TRUE))
stopifnot(grepl("<select[^>]+multiple", html, perl = TRUE, ignore.case = TRUE))

m <- gregexpr("data-vcd-filter", html, fixed = TRUE)[[1]]
stopifnot(m[[1]] != -1L)
stopifnot(grepl("Hair\\\",\\\"levels", html, fixed = TRUE))
stopifnot(grepl("Eye\\\",\\\"levels", html, fixed = TRUE))
stopifnot(grepl("Sex\\\",\\\"levels", html, fixed = TRUE))
stopifnot(!grepl("function(table) {\\nfunction(table)", html, fixed = TRUE))

unlink(outf)
message("OK: dashboard multiselect category filters present")
