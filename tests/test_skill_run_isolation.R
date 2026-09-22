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

# =============================================================================
# End-to-End Runner Collision & run_meta Verification
# =============================================================================

# --- 8. Questionnaire batch runner double run collision avoidance & run_meta ---
q_runner <- file.path(root, ".agents", "skills", "questionnaire-batch-analysis", "templates", "batch_runner.R")
td_q <- tempfile("q_collision_")
dir.create(td_q)

q_data <- file.path(td_q, "data.csv")
write.csv(data.frame(x = c("A", "B", "A", "B"), y = c("1", "1", "2", "2")), q_data, row.names = FALSE)
q_cfg <- file.path(td_q, "qcfg.csv")
writeLines(c(
  "survey_id,question_id,analysis_type,var1,var2,var3,output_slug,question_label,subset_expr,na_policy,ordered_levels,reference_note",
  "s1,q1,nominal_2way,x,y,,q01,Q1 Label,,drop,,note"
), q_cfg)

st_q1 <- system2("Rscript", c(q_runner, "--data", q_data, "--question-config", q_cfg, "--out", td_q, "--run-id", "collision_check"))
st_q2 <- system2("Rscript", c(q_runner, "--data", q_data, "--question-config", q_cfg, "--out", td_q, "--run-id", "collision_check"))

check("questionnaire run 1 exit 0", identical(as.integer(st_q1), 0L))
check("questionnaire run 2 exit 0", identical(as.integer(st_q2), 0L))

q_run1 <- file.path(td_q, "run_collision_check")
q_run2 <- file.path(td_q, "run_collision_check_2")
check("questionnaire run_collision_check created", dir.exists(q_run1))
check("questionnaire run_collision_check_2 created (collision avoidance)", dir.exists(q_run2))

meta_q1_file <- file.path(q_run1, "run_meta.json")
meta_q2_file <- file.path(q_run2, "run_meta.json")
check("questionnaire run 1 has run_meta.json", file.exists(meta_q1_file))
check("questionnaire run 2 has run_meta.json", file.exists(meta_q2_file))

if (file.exists(meta_q1_file)) {
  m_q1 <- jsonlite::fromJSON(meta_q1_file)
  check("questionnaire meta 1 has logical_run_id", identical(m_q1$logical_run_id, "collision_check"))
  check("questionnaire meta 1 has path_schema_version 1.0", identical(m_q1$path_schema_version, "1.0"))
}
if (file.exists(meta_q2_file)) {
  m_q2 <- jsonlite::fromJSON(meta_q2_file)
  check("questionnaire meta 2 has logical_run_id", identical(m_q2$logical_run_id, "collision_check"))
  check("questionnaire meta 2 run_id is collision_check_2", grepl("collision_check_2", m_q2$run_id))
}

check("questionnaire run 1 has results_manifest.json", file.exists(file.path(q_run1, "results_manifest.json")))
check("questionnaire run 2 has results_manifest.json", file.exists(file.path(q_run2, "results_manifest.json")))

unlink(td_q, recursive = TRUE)

# --- 9. SAS PROC FREQ runner double run collision avoidance ---
freq_runner <- file.path(root, ".agents", "skills", "sas-proc-freq", "templates", "run_freq.R")
td_freq <- tempfile("freq_collision_")
dir.create(td_freq)

freq_data <- file.path(td_freq, "data.csv")
write.csv(data.frame(gender = c("M", "F", "M", "F"), outcome = c("Y", "N", "N", "Y")), freq_data, row.names = FALSE)
freq_cfg <- file.path(td_freq, "config.json")
jsonlite::write_json(list(
  schema_version = "sas-summary-config-v1",
  analysis_kind = "sas_proc_freq",
  run_id = "test_freq_run",
  input = freq_data,
  output_dir = td_freq,
  tables = list(list(
    table_id = "t1",
    row_var = "gender",
    col_var = "outcome",
    chisq = TRUE
  ))
), freq_cfg, auto_unbox = TRUE, pretty = TRUE)

st_f1 <- system2("Rscript", c(freq_runner, "--config", freq_cfg))
st_f2 <- system2("Rscript", c(freq_runner, "--config", freq_cfg))

check("sas-proc-freq run 1 exit 0", identical(as.integer(st_f1), 0L))
check("sas-proc-freq run 2 exit 0", identical(as.integer(st_f2), 0L))

f_run1 <- file.path(td_freq, "run_test_freq_run")
f_run2 <- file.path(td_freq, "run_test_freq_run_2")
check("sas-proc-freq run_test_freq_run created", dir.exists(f_run1))
check("sas-proc-freq run_test_freq_run_2 created (collision avoidance)", dir.exists(f_run2))

unlink(td_freq, recursive = TRUE)

# --- 10. SAS PROC MEANS runner double run collision avoidance ---
means_runner <- file.path(root, ".agents", "skills", "sas-proc-means", "templates", "run_means.R")
td_means <- tempfile("means_collision_")
dir.create(td_means)

means_data <- file.path(td_means, "data.csv")
write.csv(data.frame(group = c("A", "B", "A", "B"), val = c(10, 20, 30, 40)), means_data, row.names = FALSE)
means_cfg <- file.path(td_means, "config.json")
jsonlite::write_json(list(
  schema_version = "sas-summary-config-v1",
  analysis_kind = "sas_proc_means",
  run_id = "test_means_run",
  input = means_data,
  output_dir = td_means,
  analysis_variables = list("val"),
  statistics = list("N", "MEAN", "STD")
), means_cfg, auto_unbox = TRUE, pretty = TRUE)

st_m1 <- system2("Rscript", c(means_runner, "--config", means_cfg))
st_m2 <- system2("Rscript", c(means_runner, "--config", means_cfg))

check("sas-proc-means run 1 exit 0", identical(as.integer(st_m1), 0L))
check("sas-proc-means run 2 exit 0", identical(as.integer(st_m2), 0L))

m_run1 <- file.path(td_means, "run_test_means_run")
m_run2 <- file.path(td_means, "run_test_means_run_2")
check("sas-proc-means run_test_means_run created", dir.exists(m_run1))
check("sas-proc-means run_test_means_run_2 created (collision avoidance)", dir.exists(m_run2))

unlink(td_means, recursive = TRUE)

# --- 11. VCD Categorical Analysis double run collision avoidance ---
cat_runner <- file.path(root, ".agents", "skills", "vcd-categorical-analysis", "templates", "analysis.R")
td_cat <- tempfile("cat_collision_")
dir.create(td_cat)

source(file.path(root, ".agents", "shared", "pass0_contract.R"))
cat_data <- file.path(td_cat, "data.csv")
write.csv(data.frame(Treatment = c("T", "P", "T", "P"), Outcome = c("Good", "Good", "Poor", "Poor"), Count = c(10, 5, 2, 12)), cat_data, row.names = FALSE)
data_sha <- digest::digest(cat_data, file = TRUE, algo = "sha256")

canonical_sha <- compute_canonical_config_sha256(
  vars = list("Treatment", "Outcome"),
  freq = "Count",
  input_mode = "aggregated",
  prior_alpha = 0.5
)

cat_insp <- file.path(td_cat, "inspection_results.json")
jsonlite::write_json(list(
  inspection_contract_version = "2.0",
  inspection_status = "ready",
  input_sha256 = data_sha,
  approved_config = list(canonical_config_sha256 = canonical_sha)
), cat_insp, auto_unbox = TRUE, pretty = TRUE)
insp_sha <- digest::digest(cat_insp, file = TRUE, algo = "sha256")

cat_cfg <- file.path(td_cat, "analysis_config.json")
jsonlite::write_json(list(
  input = cat_data,
  vars = list("Treatment", "Outcome"),
  freq = "Count",
  input_mode = "aggregated",
  pass0_provenance = list(
    contract_version = "1.0",
    target_skill = "vcd-categorical-analysis",
    finalized_at_jst = "2026-09-22T12:00:00+09:00",
    inspection_results = cat_insp,
    inspection_results_sha256 = insp_sha,
    input_sha256 = data_sha,
    canonical_config_sha256 = canonical_sha
  )
), cat_cfg, auto_unbox = TRUE, pretty = TRUE)

st_c1 <- system2("Rscript", c(cat_runner, "--config", cat_cfg, "--out", td_cat))
st_c2 <- system2("Rscript", c(cat_runner, "--config", cat_cfg, "--out", td_cat))

check("vcd-categorical run 1 exit 0", identical(as.integer(st_c1), 0L))
check("vcd-categorical run 2 exit 0", identical(as.integer(st_c2), 0L))

cat_runs <- list.dirs(td_cat, recursive = FALSE, full.names = TRUE)
cat_runs <- cat_runs[grepl("/run_[0-9a-f]{16}(_[0-9]+)?$", cat_runs)]
check("vcd-categorical created 2 distinct run directories", length(cat_runs) == 2L)
if (length(cat_runs) == 2L) {
  check("vcd-categorical second run has collision suffix _2", any(grepl("_2$", cat_runs)))
}

unlink(td_cat, recursive = TRUE)

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  quit(status = 1L)
} else {
  quit(status = 0L)
}
