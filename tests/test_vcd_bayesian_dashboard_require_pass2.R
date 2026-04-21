# Pass3: require_pass2=TRUE で executive_summary 必須、FALSE でプレースホルダー許可
# リポジトリルートで: Rscript tests/test_vcd_bayesian_dashboard_require_pass2.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}

if (!requireNamespace("rmarkdown", quietly = TRUE) || !requireNamespace("knitr", quietly = TRUE)) {
  message("SKIP: rmarkdown or knitr not installed")
  quit(status = 0L)
}

analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
render_dash <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R")
stopifnot(file.exists(analysis), file.exists(render_dash))

td <- tempfile("vcd_req_p2_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

st <- system2("Rscript", c(analysis, "--output_dir", td))
stopifnot(identical(as.integer(st), 0L))
jp <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
run_dir <- dirname(jp[1L])
stopifnot(!file.exists(file.path(run_dir, "executive_summary.md")))

st_strict <- system2("Rscript", c(render_dash, "--output_dir", td))
stopifnot(!identical(as.integer(st_strict), 0L))

st_draft <- system2("Rscript", c(render_dash, "--output_dir", td, "--no-require-pass2"))
stopifnot(identical(as.integer(st_draft), 0L))

dash <- file.path(run_dir, "dashboard.html")
stopifnot(file.exists(dash))
html <- paste(readLines(dash, warn = FALSE), collapse = "\n")
stopifnot(grepl("Pass 2 未実行", html, fixed = TRUE))

unlink(dash)
message("OK: require_pass2 strict + draft render")
