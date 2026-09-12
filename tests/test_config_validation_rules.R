# =============================================================================
# test_config_validation_rules.R
# タスク 2.3 & 2.4: base_models と conditional_rate_view の検証ルールテスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

script_dir <- file.path(getwd(), ".agents/skills/vcd-bayesian-evidence-analysis/templates")
source(file.path(script_dir, "config_validation.R"))

test_that("2.3 正常系: UCB 標準 analysis_config.json が検証を通過する", {
  cfg_path <- file.path(getwd(), "tests/fixtures/dashboard_ui/ucb_admissions_three_way_v1/analysis_config.json")
  expect_true(file.exists(cfg_path))
  cfg <- fromJSON(cfg_path, simplifyVector = TRUE)
  res <- validate_analysis_config(cfg, config_path = cfg_path, repo_root = getwd())
  expect_equal(res$base_models, c("M1", "M5"))
})

test_that("2.3 異常系: 未知の base_models は暗黙 fallback せずエラーになる", {
  cfg <- list(
    input = "examples/ucb_admissions.csv",
    vars = c("Dept", "Gender", "Admit"),
    freq = "Freq",
    output_dir = "output/test",
    run_id = "test_run",
    base_models = c("M1", "M99")
  )
  expect_error(
    validate_analysis_config(cfg, repo_root = getwd()),
    "base_models に無効なモデルIDが含まれています: M99"
  )
})

test_that("2.3 異常系: base_models の重複はエラーになる", {
  cfg <- list(
    input = "examples/ucb_admissions.csv",
    vars = c("Dept", "Gender", "Admit"),
    freq = "Freq",
    output_dir = "output/test",
    run_id = "test_run",
    base_models = c("M1", "M1")
  )
  expect_error(
    validate_analysis_config(cfg, repo_root = getwd()),
    "base_models に重複したモデルIDがあります"
  )
})

test_that("2.3 異常系: conditional_rate_view の役割変数が重複しているとエラーになる", {
  cfg <- list(
    input = "examples/ucb_admissions.csv",
    vars = c("Dept", "Gender", "Admit"),
    freq = "Freq",
    output_dir = "output/test",
    run_id = "test_run",
    conditional_rate_view = list(
      response_var = "Admit",
      numerator_levels = c("Admitted"),
      denominator_levels = c("Admitted", "Rejected"),
      compare_by = "Admit", # 重複
      stratify_by = "Dept"
    )
  )
  expect_error(
    validate_analysis_config(cfg, repo_root = getwd()),
    "response_var, compare_by, stratify_by は互いに異なる変数である必要があります"
  )
})

test_that("2.3 異常系: numerator_levels が denominator_levels の部分集合でないとエラーになる", {
  cfg <- list(
    input = "examples/ucb_admissions.csv",
    vars = c("Dept", "Gender", "Admit"),
    freq = "Freq",
    output_dir = "output/test",
    run_id = "test_run",
    conditional_rate_view = list(
      response_var = "Admit",
      numerator_levels = c("UnknownLevel"),
      denominator_levels = c("Admitted", "Rejected"),
      compare_by = "Gender",
      stratify_by = "Dept"
    )
  )
  expect_error(
    validate_analysis_config(cfg, repo_root = getwd()),
    "numerator_levels は denominator_levels の部分集合である必要があります"
  )
})

test_that("2.4 部分HOLD: データに存在しない水準指定時は全体停止せず HOLD 理由を返す", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  crv_bad_level <- list(
    response_var = "Admit",
    numerator_levels = c("NonExistent"),
    denominator_levels = c("NonExistent", "Rejected"),
    compare_by = "Gender",
    stratify_by = "Dept"
  )
  res <- validate_conditional_rate_view_data(crv_bad_level, df, vars = c("Dept", "Gender", "Admit"), freq_col = "Freq")
  expect_identical(res$status, "HOLD")
  expect_true(grepl("NonExistent", res$hold_reason))
})

test_that("2.4 部分HOLD: conditional_rate_view 未指定時は HOLD 理由を返す", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  res <- validate_conditional_rate_view_data(NULL, df, vars = c("Dept", "Gender", "Admit"), freq_col = "Freq")
  expect_identical(res$status, "HOLD")
  expect_true(grepl("設定されていません", res$hold_reason))
})

cat("[SUCCESS] test_config_validation_rules.R passed all tests.\n")
