#!/usr/bin/env Rscript
# tests/statistical_foundations/test_section3_models.R
# Section 3: 3元表モデル適合と参照計算照合の単体・統合テスト

source("tests/statistical_foundations/fit_models.R")
source("tests/statistical_foundations/reference_values.R")
source("tests/statistical_foundations/check_results.R")

test_cases <- list(
  list(name = "syn_independent", path = "tests/fixtures/statistical_foundations/syn_independent.csv", vars = c("A", "B", "C")),
  list(name = "syn_ab_associated", path = "tests/fixtures/statistical_foundations/syn_ab_associated.csv", vars = c("A", "B", "C")),
  list(name = "syn_interaction_shifted", path = "tests/fixtures/statistical_foundations/syn_interaction_shifted.csv", vars = c("A", "B", "C")),
  list(name = "titanic_aggregated_3way", path = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv", vars = c("Class", "Sex", "Survived"))
)

tolerances <- list(
  glm_vs_loglin_fitted_rel_tol = 1e-05,
  glm_vs_loglin_deviance_abs_tol = 1e-04
)

for (tc in test_cases) {
  message("=== Testing Case: ", tc$name, " ===")
  df <- readr::read_csv(tc$path, show_col_types = FALSE)
  
  # 1. GLM適合
  glm_res <- fit_all_9_models(df, tc$vars, "Freq")
  stopifnot(length(glm_res$models) == 9L)
  
  # 2. 独立参照計算
  ref_res <- extract_reference_values(df, tc$vars, "Freq")
  stopifnot(length(ref_res$models) == 9L)
  
  # 3. 照合
  chk <- check_model_against_reference(glm_res, ref_res, tolerances)
  
  message("  - All reference checks passed: ", chk$all_reference_checks_passed)
  if (!chk$all_reference_checks_passed) {
    for (m_id in names(chk$per_model_checks)) {
      mc <- chk$per_model_checks[[m_id]]
      if (!mc$check_passed) {
        message(sprintf("    [FAIL] %s: rel_err_fitted=%.3e, abs_err_dev=%.3e, df_match=%s",
                        m_id, mc$max_rel_err_fitted, mc$abs_err_deviance, mc$df_match))
      }
    }
    stop("照合テストに失敗しました: ", tc$name)
  }
  
  message("  - Regular models pool count: ", length(chk$regular_models_pool))
  message("  - Quarantined models count: ", length(chk$quarantined_models))
  message("  - Nested comparisons count: ", length(chk$nested_comparisons))
  message("  -> [PASS] ", tc$name)
}

message("\n=== Section 3 テスト 全件合格 ===")
