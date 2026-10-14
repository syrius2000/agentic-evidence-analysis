#!/usr/bin/env Rscript
# tests/test_latest_pointer_real_path.R
# Task 2.4 (H1 Review Fix): Integration test verifying latest.json "path" and runs_index.jsonl "run_dir" point to existing directories

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grep("^--file=", args)]
repo_root <- if (length(file_arg) > 0) {
  dirname(dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")))
} else {
  normalizePath(getwd(), winslash = "/")
}

q_out <- file.path(repo_root, "evidence_runs/questionnaire", paste0(".test_latest_probe_", Sys.getpid()))
freq_out <- file.path(repo_root, "evidence_runs/sas_proc_freq", paste0(".test_latest_probe_", Sys.getpid()))
tmp_scratch <- tempfile("latest_scratch_")
dir.create(tmp_scratch, recursive = TRUE)

cleanup <- function() {
  if (dir.exists(q_out)) unlink(q_out, recursive = TRUE, force = TRUE)
  if (dir.exists(freq_out)) unlink(freq_out, recursive = TRUE, force = TRUE)
  if (dir.exists(tmp_scratch)) unlink(tmp_scratch, recursive = TRUE, force = TRUE)
}

passed <- 0L
failed <- 0L

check <- function(label, condition) {
  if (isTRUE(condition)) {
    cat(sprintf("[PASS] %s\n", label))
    passed <<- passed + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", label))
    failed <<- failed + 1L
  }
}

tryCatch({
  # 1. Questionnaire Batch Run
  dir.create(q_out, recursive = TRUE)
  q_script <- file.path(repo_root, ".agents/skills/questionnaire-batch-analysis/templates/batch_runner.R")
  csv_data <- file.path(repo_root, "tests/sample_survey.csv")
  q_cfg_data <- file.path(tmp_scratch, "test_q_config.csv")
  writeLines(c(
    "survey_id,question_id,analysis_type,var1,var2,var3,output_slug,question_label,subset_expr,na_policy,ordered_levels,reference_note",
    "SURVEY1,Q1,nominal_2way,gender,department,,dept_gender,Dept by Gender,,exclude,,"
  ), q_cfg_data)
  
  cmd_q <- sprintf(
    "Rscript --vanilla %s --data %s --question-config %s --out %s --run-id qa_probe_q",
    q_script, csv_data, q_cfg_data, q_out
  )
  res_q <- system(cmd_q, ignore.stdout = TRUE, ignore.stderr = TRUE)
  check("questionnaire batch ran with exit code 0", res_q == 0)
  
  latest_file_q <- file.path(q_out, "latest.json")
  check("questionnaire latest.json exists", file.exists(latest_file_q))
  if (file.exists(latest_file_q)) {
    latest_q <- jsonlite::read_json(latest_file_q)
    check("questionnaire latest.json path is NOT just run_id qa_probe_q", latest_q$path != "qa_probe_q")
    check("questionnaire latest.json path points to existing directory", dir.exists(file.path(q_out, latest_q$path)))
  }
  
  index_file_q <- file.path(q_out, "runs_index.jsonl")
  check("questionnaire runs_index.jsonl exists", file.exists(index_file_q))
  if (file.exists(index_file_q)) {
    lines <- readLines(index_file_q, warn = FALSE)
    last_rec <- jsonlite::fromJSON(lines[length(lines)])
    check("questionnaire runs_index run_dir exists", !is.null(last_rec$run_dir))
    check("questionnaire runs_index run_dir points to existing directory", dir.exists(file.path(q_out, last_rec$run_dir)))
  }
  
  # 2. SAS PROC FREQ Run
  dir.create(freq_out, recursive = TRUE)
  freq_script <- file.path(repo_root, ".agents/skills/sas-proc-freq/templates/run_freq.R")
  freq_cfg_file <- file.path(tmp_scratch, "freq_cfg.json")
  freq_cfg <- list(
    schema_version = "sas-summary-config-v1",
    analysis_kind = "sas_proc_freq",
    input = csv_data,
    output_dir = freq_out,
    run_id = "qa_probe_freq",
    tables = list(list(table_id = "t1", row_var = "gender", col_var = "department"))
  )
  jsonlite::write_json(freq_cfg, freq_cfg_file, auto_unbox = TRUE)
  
  cmd_freq <- sprintf("Rscript --vanilla %s --config %s", freq_script, freq_cfg_file)
  res_freq <- system(cmd_freq, ignore.stdout = TRUE, ignore.stderr = TRUE)
  check("sas-proc-freq ran with exit code 0", res_freq == 0)
  
  latest_file_freq <- file.path(freq_out, "latest.json")
  check("sas-proc-freq latest.json exists", file.exists(latest_file_freq))
  if (file.exists(latest_file_freq)) {
    latest_freq <- jsonlite::read_json(latest_file_freq)
    check("sas-proc-freq latest.json path points to existing directory", dir.exists(file.path(freq_out, latest_freq$path)))
  }
  
  index_file_freq <- file.path(freq_out, "runs_index.jsonl")
  check("sas-proc-freq runs_index.jsonl exists", file.exists(index_file_freq))
  if (file.exists(index_file_freq)) {
    lines <- readLines(index_file_freq, warn = FALSE)
    last_rec <- jsonlite::fromJSON(lines[length(lines)])
    check("sas-proc-freq runs_index run_dir points to existing directory", dir.exists(file.path(freq_out, last_rec$run_dir)))
  }
  
  # Check environment block in run_meta.json for both runs
  q_meta_file <- file.path(q_out, latest_q$path, "run_meta.json")
  check("questionnaire run_meta.json exists", file.exists(q_meta_file))
  if (file.exists(q_meta_file)) {
    q_meta <- jsonlite::read_json(q_meta_file)
    check("questionnaire environment.platform is R.version$platform", identical(q_meta$environment$platform, R.version$platform))
    check("questionnaire environment.seed is null (no RNG)", is.null(q_meta$environment$seed))
  }
  
  freq_meta_file <- file.path(freq_out, latest_freq$path, "run_meta.json")
  check("sas-proc-freq run_meta.json exists", file.exists(freq_meta_file))
  if (file.exists(freq_meta_file)) {
    freq_meta <- jsonlite::read_json(freq_meta_file)
    check("sas-proc-freq environment.platform is R.version$platform", identical(freq_meta$environment$platform, R.version$platform))
    check("sas-proc-freq environment.seed is null (no MC)", is.null(freq_meta$environment$seed))
  }
  
  # 3. vcd-categorical-reporting run (with seed = 42L)
  rep_out <- file.path(repo_root, "evidence_runs/vcd_categorical_reporting", paste0(".test_latest_probe_", Sys.getpid()))
  dir.create(rep_out, recursive = TRUE)
  rep_script <- file.path(repo_root, ".agents/skills/vcd-categorical-reporting/comparative_reporting.R")
  
  # Invoke comparative_reporting API
  source(file.path(repo_root, ".agents/shared/run_scope.R"))
  source(rep_script)
  
  rep_df <- data.frame(
    arm = c("Drug", "Drug", "Control", "Control"),
    theme = c("SOC1", "SOC2", "SOC1", "SOC2"),
    events = c(5, 10, 2, 4),
    total = c(100, 100, 100, 100),
    stringsAsFactors = FALSE
  )
  rep_csv <- file.path(tmp_scratch, "rep_data.csv")
  write.csv(rep_df, rep_csv, row.names = FALSE)
  
  res_rep <- generate_comparative_report(
    df = rep_df,
    out_root = rep_out,
    seed = 42L,
    primary_delta = 0.05
  )
  check("generate_comparative_report executed successfully", !is.null(res_rep$run_output_dir))
  
  rep_latest_file <- file.path(rep_out, "latest.json")
  check("comparative_reporting latest.json exists", file.exists(rep_latest_file))
  if (file.exists(rep_latest_file)) {
    rep_latest <- jsonlite::read_json(rep_latest_file)
    check("comparative_reporting latest.json path points to existing directory", dir.exists(file.path(rep_out, rep_latest$path)))
  }
  
  rep_meta_file <- file.path(res_rep$run_output_dir, "run_meta.json")
  check("comparative_reporting run_meta.json exists", file.exists(rep_meta_file))
  if (file.exists(rep_meta_file)) {
    rep_meta <- jsonlite::read_json(rep_meta_file)
    check("comparative_reporting environment.seed is 42", identical(as.integer(rep_meta$environment$seed), 42L))
    check("comparative_reporting environment.platform is R.version$platform", identical(rep_meta$environment$platform, R.version$platform))
  }
  if (dir.exists(rep_out)) unlink(rep_out, recursive = TRUE, force = TRUE)

}, finally = {
  cleanup()
})

cat(sprintf("\ntest_latest_pointer_real_path: %d PASS / %d FAIL\n", passed, failed))
if (failed > 0L) {
  stop(sprintf("[FAILED] %d 件のテストに失敗しました", failed))
}
