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

bayes <- file.path(root, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "analysis.R")
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

# --- run_scope.R direct unit contracts ---
source(file.path(root, ".agents", "shared", "run_scope.R"))

td_scope <- tempfile("scope_test_")
dir.create(td_scope)

# 1. ID normalization: run_001 -> run_001 (no run_run_001)
dir1 <- reserve_run_output_dir(td_scope, "vcd-bayesian-evidence-analysis", "run_001")
check("run_001 normalizes to run_001", basename(dir1) == "run_001")
check("no run_run_001 generated", !grepl("run_run_", basename(dir1)))

# 2. prefix addition: abc -> run_abc
dir2 <- reserve_run_output_dir(td_scope, "vcd-bayesian-evidence-analysis", "abc")
check("abc prefix adds to run_abc", basename(dir2) == "run_abc")

# 3. collision avoidance: identical ID creates _2
dir3 <- reserve_run_output_dir(td_scope, "vcd-bayesian-evidence-analysis", "abc")
check("collision avoidance creates run_abc_2", basename(dir3) == "run_abc_2")

# 4. questionnaire unified layout: no runs/ intermediate directory for new runs
dir_q <- reserve_run_output_dir(td_scope, "questionnaire-batch-analysis", "batch_01")
check("questionnaire new layout is run_batch_01", basename(dir_q) == "run_batch_01")
check("questionnaire parent is td_scope directly", dirname(dir_q) == normalizePath(td_scope, winslash = "/"))

# 5. trust boundary: accepts new layout
meta_new <- list(
  skill = "questionnaire-batch-analysis",
  out_root = normalizePath(td_scope, winslash = "/"),
  run_output_dir = dir_q
)
tb_ok_new <- tryCatch({
  verify_run_lock_trust_boundary(dir_q, meta_new)
  TRUE
}, error = function(e) FALSE)
check("trust boundary accepts new questionnaire run_<id> layout", isTRUE(tb_ok_new))

# 6. trust boundary: accepts legacy runs/<id> layout
legacy_runs_dir <- file.path(td_scope, "runs")
dir.create(legacy_runs_dir, showWarnings = FALSE)
legacy_run <- file.path(legacy_runs_dir, "legacy_01")
dir.create(legacy_run, showWarnings = FALSE)
meta_legacy <- list(
  skill = "questionnaire-batch-analysis",
  out_root = normalizePath(td_scope, winslash = "/"),
  run_output_dir = normalizePath(legacy_run, winslash = "/")
)
tb_ok_legacy <- tryCatch({
  verify_run_lock_trust_boundary(legacy_run, meta_legacy)
  TRUE
}, error = function(e) FALSE)
check("trust boundary accepts legacy questionnaire runs/<id> layout", isTRUE(tb_ok_legacy))

# 7. resolve_pass3_run_dir: discover single run from legacy runs/<id>
writeLines("test,csv", file.path(legacy_run, "summary.csv"))
res_disc <- resolve_pass3_run_dir(td_scope, "summary.csv", discover_single_run = TRUE)
check("legacy run discovered by resolve_pass3_run_dir", normalizePath(res_disc$run_dir, winslash = "/") == normalizePath(legacy_run, winslash = "/"))

unlink(td_scope, recursive = TRUE)
unlink(td, recursive = TRUE)
unlink(c(a1, a2))

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  quit(status = 1L)
} else {
  quit(status = 0L)
}
