# 公開Pass 1 CLI試験で、実運用と同じPass 0由来設定を生成する補助関数。

pass0_test_repo_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  for (i in seq_len(10L)) {
    if (file.exists(file.path(current, ".agents", "shared", "finalize_pass0_config.R"))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }
  stop("テスト用Pass 0補助関数: リポジトリルートを解決できません。")
}

make_pass0_test_config <- function(skill, input_path, output_dir, run_id, vars = NULL, freq = NULL, response_var = NULL, question_config = NULL, repo_root = pass0_test_repo_root()) {
  work_dir <- tempfile(paste0("pass0_", gsub("[^A-Za-z0-9_]", "_", run_id), "_"))
  dir.create(work_dir, recursive = TRUE)
  inspection_dir <- file.path(work_dir, "inspection")
  config_path <- file.path(work_dir, "analysis_config.json")
  inspect_script <- file.path(repo_root, ".agents", "shared", "inspect_data.R")
  finalize_script <- file.path(repo_root, ".agents", "shared", "finalize_pass0_config.R")

  stopifnot(system2("Rscript", c(inspect_script, input_path, "--out-dir", inspection_dir), stdout = FALSE, stderr = FALSE) == 0L)
  cli <- c(
    finalize_script,
    "--inspection-results", file.path(inspection_dir, "inspection_results.json"),
    "--scope", file.path(repo_root, "docs", "Artifacts", "implementation_plan_008_0909.md"),
    "--config-out", config_path,
    "--skill", skill,
    "--input", input_path,
    "--output-dir", output_dir,
    "--run-id", run_id
  )
  if (!is.null(vars)) cli <- c(cli, "--vars", paste(vars, collapse = ","))
  if (!is.null(freq)) cli <- c(cli, "--freq", freq)
  if (!is.null(response_var)) cli <- c(cli, "--response-var", response_var)
  if (!is.null(question_config)) cli <- c(cli, "--question-config", question_config)
  stopifnot(system2("Rscript", cli, stdout = FALSE, stderr = FALSE) == 0L)
  config_path
}
