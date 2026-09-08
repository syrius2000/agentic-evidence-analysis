# =============================================================================
# test_ucb_numerical_invariance.R
# タスク 4.2 & 4.3 の検証テスト:
# - 4.2: 既存 UCB Admissions 結果 (run_admit_bias) との数値完全一致
# - 4.3: 変更前固定参照実行 (3956f22 / baseline_reference_fits.json) との数値不変性
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

find_repo_root <- function() {
  curr <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(curr, ".agents"))) return(curr)
    curr <- dirname(curr)
  }
  getwd()
}
repo_root <- find_repo_root()
source(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R"))

# 1. 既存の比較元（保護対象）の確認
existing_json_path <- file.path(repo_root, "output/ucb_admissions/run_admit_bias/evidence_results.json")
stopifnot(file.exists(existing_json_path))
existing_res <- fromJSON(existing_json_path)

# 2. 固定参照実行（コミット 3956f22）フィクスチャの確認
ref_fits_path <- file.path(repo_root, "tests/fixtures/baseline_3956f22/baseline_reference_fits.json")
stopifnot(file.exists(ref_fits_path))
ref_fits <- fromJSON(ref_fits_path)

# 3. 新規 run の実行（既存 run とは別の一時ディレクトリに出力）
test_run_dir <- file.path(repo_root, "output/test_invariance_run")
if (dir.exists(test_run_dir)) unlink(test_run_dir, recursive = TRUE)

cmd_analysis <- sprintf(
  "Rscript %s --input %s --vars Dept,Gender,Admit --freq Freq --response_var Admit --output_dir %s --run-id inv_test",
  shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
  shQuote(file.path(repo_root, "examples/ucb_admissions.csv")),
  shQuote(test_run_dir)
)
system(cmd_analysis, intern = TRUE)

run_subdirs <- list.dirs(test_run_dir, full.names = TRUE, recursive = FALSE)
stopifnot(length(run_subdirs) >= 1L)
new_run_dir <- run_subdirs[1]
new_json_path <- file.path(new_run_dir, "evidence_results.json")
stopifnot(file.exists(new_json_path))
new_res <- fromJSON(new_json_path)

# =============================================================================
# タスク 4.2: 既存 UCB Admissions 出力との完全一致・結合比較テスト
# =============================================================================
test_that("タスク 4.2: 新規 run と既存 run (run_admit_bias) のモデルサマリーが数値一致する", {
  # 最良モデルの一致
  expect_identical(new_res$models$best_model_id, existing_res$models$best_model_id)
  expect_identical(new_res$models$best_model_id, "M5")
  
  # 全体効果量 Cramér's V の一致
  expect_equal(new_res$effects$cramers_v, existing_res$effects$cramers_v, tolerance = 1e-6)
  
  # モデルサマリー表の結合比較
  df_exist <- as.data.frame(existing_res$models$summary)
  df_new <- as.data.frame(new_res$models$summary)
  
  expect_equal(nrow(df_new), nrow(df_exist))
  expect_equal(df_new$model_id, df_exist$model_id)
  
  for (mid in df_exist$model_id) {
    row_e <- df_exist[df_exist$model_id == mid, ]
    row_n <- df_new[df_new$model_id == mid, ]
    
    # 残差自由度の完全一致
    expect_identical(row_n$df_residual, row_e$df_residual, info = sprintf("%s df_residual", mid))
    # 逸脱度の一致 (< 10^-6)
    expect_equal(row_n$deviance, row_e$deviance, tolerance = 1e-6, info = sprintf("%s deviance", mid))
    # 明示式BICの一致 (< 10^-6)
    expect_equal(row_n$bic, row_e$bic, tolerance = 1e-6, info = sprintf("%s bic", mid))
  }
})

test_that("タスク 4.2: 新規 run と既存 run の全セル診断テーブルがキー結合で完全一致する", {
  cells_exist <- as.data.frame(existing_res$cells$full_data)
  cells_new <- as.data.frame(new_res$cells$full_data)
  
  expect_equal(nrow(cells_new), 24L)
  expect_equal(nrow(cells_exist), 24L)
  
  # セル水準（Dept, Gender, Admit）を複合キーとしてソート・結合
  cells_exist$key <- paste(cells_exist$Dept, cells_exist$Gender, cells_exist$Admit, sep = "_")
  cells_new$key <- paste(cells_new$Dept, cells_new$Gender, cells_new$Admit, sep = "_")
  
  cells_exist <- cells_exist[order(cells_exist$key), ]
  cells_new <- cells_new[order(cells_new$key), ]
  
  expect_identical(cells_new$key, cells_exist$key)
  
  # 観測度数・期待値・ピアソン残差・Score統計量・P値・Leverage・診断状態の一致検証
  expect_identical(cells_new$Observed, cells_exist$Observed)
  expect_equal(cells_new$Expected, cells_exist$Expected, tolerance = 1e-6)
  expect_equal(cells_new$Residual, cells_exist$Residual, tolerance = 1e-6)
  expect_equal(cells_new$log_oe_ratio, cells_exist$log_oe_ratio, tolerance = 1e-6)
  expect_equal(cells_new$score_stat, cells_exist$score_stat, tolerance = 1e-6)
  expect_equal(cells_new$p_value, cells_exist$p_value, tolerance = 1e-6)
  expect_equal(cells_new$leverage, cells_exist$leverage, tolerance = 1e-6)
  expect_identical(cells_new$stability_status, cells_exist$stability_status)
})

# =============================================================================
# タスク 4.3: 変更前エンジン固定参照実行 (3956f22) との数値不変性テスト
# =============================================================================
test_that("タスク 4.3: 固定参照実行 (3956f22) と全モデルの内部対数尤度・未保存適合値が一致する", {
  # UCB データを読み込んで直接 fit_all_poisson_models を実行し内部 GLM 適合結果を取得
  ucb_df <- read.csv(file.path(repo_root, "examples/ucb_admissions.csv"))
  vars <- c("Dept", "Gender", "Admit")
  
  fit_result <- fit_all_poisson_models(ucb_df, vars, "Freq")
  
  expect_identical(names(fit_result$models), paste0("M", 1:9))
  
  for (mid in paste0("M", 1:9)) {
    act_m <- fit_result$models[[mid]]
    exp_ref <- ref_fits[[mid]]
    
    expect_false(is.null(act_m), info = sprintf("モデル %s の適合結果が存在すること", mid))
    
    # 1. 残差自由度: 完全一致
    expect_identical(act_m$df_residual, as.integer(exp_ref$df_residual), info = sprintf("%s df_residual", mid))
    
    # 2. 逸脱度 (deviance): 許容誤差 < 10^-6
    expect_equal(act_m$deviance, exp_ref$deviance, tolerance = 1e-6, info = sprintf("%s deviance", mid))
    
    # 3. ポアソン対数尤度 (loglik): 許容誤差 < 10^-6
    expect_equal(act_m$loglik, exp_ref$loglik, tolerance = 1e-6, info = sprintf("%s loglik", mid))
    
    # 4. 総度数 N 基準の明示式BIC: 許容誤差 < 10^-6
    expect_equal(act_m$bic, exp_ref$bic_explicit, tolerance = 1e-6, info = sprintf("%s bic", mid))
    
    # 5. 未保存の全24セル適合値 (fitted_values): 許容誤差 < 10^-6
    expect_equal(as.numeric(act_m$fitted_values), unlist(exp_ref$fitted_values), tolerance = 1e-6, info = sprintf("%s fitted_values", mid))
    
    # 6. ピアソン残差 (residuals_pearson): 許容誤差 < 10^-6
    expect_equal(as.numeric(act_m$residuals_pearson), unlist(exp_ref$residuals_pearson), tolerance = 1e-6, info = sprintf("%s residuals_pearson", mid))
    
    # 7. Leverage (hatvalues): 許容誤差 < 10^-6
    expect_equal(as.numeric(act_m$leverage), unlist(exp_ref$leverage), tolerance = 1e-6, info = sprintf("%s leverage", mid))
  }
})

# 一時出力のクリーンアップ
if (dir.exists(test_run_dir)) {
  unlink(test_run_dir, recursive = TRUE)
}
