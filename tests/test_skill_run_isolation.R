#!/usr/bin/env Rscript
# tests/test_skill_run_isolation.R — run スコープ出力の回帰（上書き防止・run_meta）
root <- normalizePath(".", mustWork = TRUE)

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

bayes <- file.path(root, ".agent", "skills", "vcd-bayesian-evidence-analysis", "templates", "analysis.R")
stopifnot(file.exists(bayes))

td <- tempfile("run_iso_")
dir.create(td)

a1 <- tempfile("bayes_a_", fileext = ".csv")
a2 <- tempfile("bayes_b_", fileext = ".csv")
write.csv(data.frame(A = c("x", "y"), B = c("p", "q"), Freq = c(10, 20)), a1, row.names = FALSE)
write.csv(data.frame(A = c("x", "y"), B = c("p", "q"), Freq = c(11, 19)), a2, row.names = FALSE)

st1 <- system2("Rscript", c(bayes, "--input", a1, "--output_dir", td))
st2 <- system2("Rscript", c(bayes, "--input", a2, "--output_dir", td))
check("bayesian two runs exit 0", identical(as.integer(st1), 0L) && identical(as.integer(st2), 0L))

runs <- list.dirs(td, recursive = FALSE, full.names = TRUE)
runs <- runs[grepl("/run_[0-9a-f]{16}$", runs)]
check("two run_* directories exist", length(runs) == 2L)

meta_paths <- list.files(td, pattern = "^run_meta\\.json$", full.names = TRUE, recursive = TRUE)
check("two run_meta.json", length(meta_paths) == 2L)

if (length(meta_paths) == 2L) {
  m1 <- jsonlite::fromJSON(meta_paths[1L])
  m2 <- jsonlite::fromJSON(meta_paths[2L])
  check("run_ids differ", m1$run_id != m2$run_id)
}

root_files <- list.files(td, pattern = "evidence_results\\.json$", full.names = TRUE, recursive = FALSE)
check("no evidence_results.json at skill root", length(root_files) == 0L)

unlink(td, recursive = TRUE)
unlink(c(a1, a2))

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  quit(status = 1L)
} else {
  quit(status = 0L)
}
