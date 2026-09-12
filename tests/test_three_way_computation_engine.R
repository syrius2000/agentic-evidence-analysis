# =============================================================================
# test_three_way_computation_engine.R
# タスク 3.1 〜 3.7: 三次元計算エンジンと結果JSONの包括的回帰テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

script_dir <- file.path(getwd(), ".agents/skills/vcd-bayesian-evidence-analysis/templates")
source(file.path(script_dir, "pass1_compute.R"))
source(file.path(script_dir, "config_validation.R"))

test_that("3.1: 9階層モデル辞書・式・生成クラスの完全整合性", {
  expect_equal(length(MODEL_SPECS_3WAY), 9L)
  expect_identical(names(MODEL_SPECS_3WAY), paste0("M", 1:9))

  factor_map <- build_factor_map(c("Dept", "Gender", "Admit"))
  for (m_id in names(MODEL_SPECS_3WAY)) {
    spec <- MODEL_SPECS_3WAY[[m_id]]
    fmla <- build_formula_from_generators(spec$generators, factor_map, "Freq")
    # 階層原理の展開項完全一致（validate_formula_terms がエラーを投げない）
    expect_true(validate_formula_terms(fmla, spec$generators, factor_map))
  }
})

test_that("3.2 & 3.3: ポアソン対数尤度による明示式BICの算出とUCB固定値不変性", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  fits <- fit_all_poisson_models(df, c("Dept", "Gender", "Admit"), "Freq")

  expect_identical(fits$best_model_id, "M5")

  # 手動明示式 BIC 検証: -2 * logLik + p * log(N)
  total_n <- sum(df$Freq)
  m5_fit <- fits$models$M5$fit
  ll_m5 <- as.numeric(logLik(m5_fit))
  p_m5 <- attr(logLik(m5_fit), "df")
  expected_bic_m5 <- -2 * ll_m5 + p_m5 * log(total_n)

  expect_equal(fits$models$M5$bic, expected_bic_m5, tolerance = 1e-6)
  expect_equal(round(fits$models$M5$bic, 4), 332.3119, tolerance = 1e-4)

  m8_fit <- fits$models$M8$fit
  ll_m8 <- as.numeric(logLik(m8_fit))
  p_m8 <- attr(logLik(m8_fit), "df")
  expected_bic_m8 <- -2 * ll_m8 + p_m8 * log(total_n)
  expect_equal(fits$models$M8$bic, expected_bic_m8, tolerance = 1e-6)
  expect_equal(round(fits$models$M8$bic, 4), 339.1982, tolerance = 1e-4)

  # R既定 BIC (stats::BIC は行数 24 基準) と明示式 BIC が異なることを証明
  stats_bic_m5 <- stats::BIC(m5_fit)
  expect_false(isTRUE(all.equal(fits$models$M5$bic, stats_bic_m5)))
})

test_that("3.4: M1とM5の多重基準セル診断が別々のグループに出力され4軸指標を持つ", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  fits <- fit_all_poisson_models(df, c("Dept", "Gender", "Admit"), "Freq")
  multi_diag <- compute_multi_baseline_diagnostics(df, c("Dept", "Gender", "Admit"), "Freq", fits, c("M1", "M5"), large_n_threshold = 2000)

  expect_true("M1" %in% names(multi_diag))
  expect_true("M5" %in% names(multi_diag))

  for (mid in c("M1", "M5")) {
    diag <- multi_diag[[mid]]
    expect_identical(diag$base_model_id, mid)
    expect_true(nzchar(diag$question_ja))
    # counts フィールドの検証
    expect_equal(diag$counts$total_cells, 24L)
    expect_true(is.numeric(diag$counts$regular_cells))
    expect_true(is.numeric(diag$counts$quarantined_cells))
    expect_true(is.numeric(diag$counts$candidate_cells))
    expect_true(is.numeric(diag$counts$legacy_positive_cells))

    # 4軸列の存在検証
    tbl <- diag$cell_table
    expect_true(all(c("Observed", "Expected", "log_oe_ratio", "scaled_diff", "rate_diff",
                      "score_stat", "p_value", "log_p", "leverage", "stability_status",
                      "is_candidate_dual_filter", "evidence_score_legacy") %in% names(tbl)))
  }
})

test_that("3.5: 大標本Dual-Filterロジックの検証", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  fits <- fit_all_poisson_models(df, c("Dept", "Gender", "Admit"), "Freq")
  diag_m1 <- compute_4axis_cell_diagnostics(df, c("Dept", "Gender", "Admit"), "Freq", fits, "M1", large_n_threshold = 2000)
  tbl <- diag_m1$cell_table

  # Dual-Filter 条件: |log(O/E)| >= 0.50 & score_stat >= 3.84 & stability == REGULAR
  manual_filter <- (abs(tbl$log_oe_ratio) >= 0.50) & (tbl$score_stat >= 3.84) & (tbl$stability_status == "REGULAR")
  expect_identical(tbl$is_candidate_dual_filter, manual_filter)
  expect_equal(sum(tbl$is_candidate_dual_filter), 12L)
})

test_that("3.6: 旧Evidence Scoreの監査列化と独立性", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  fits <- fit_all_poisson_models(df, c("Dept", "Gender", "Admit"), "Freq")
  diag_m1 <- compute_4axis_cell_diagnostics(df, c("Dept", "Gender", "Admit"), "Freq", fits, "M1", large_n_threshold = 2000)
  tbl <- diag_m1$cell_table

  # legacy score が正の件数は 19 件だが、Dual-Filter 候補は 12 件であり、旧値が判断ロジックに使われていない
  expect_equal(sum(tbl$evidence_score_legacy > 0), 19L)
  expect_equal(diag_m1$counts$candidate_cells, 12L)
  expect_false(identical(tbl$is_candidate_dual_filter, tbl$evidence_score_legacy > 0))
})

test_that("3.7: 汎用 conditional_rate_view の Dirichlet 事後割合および層別比較差の算出", {
  df <- read.csv(file.path(getwd(), "examples/ucb_admissions.csv"))
  crv_spec <- list(
    response_var = "Admit",
    numerator_levels = c("Admitted"),
    denominator_levels = c("Admitted", "Rejected"),
    compare_by = "Gender",
    stratify_by = "Dept",
    interval_level = 0.95,
    reference_level = "Female"
  )
  crv_res <- compute_conditional_rate_view(df, c("Dept", "Gender", "Admit"), "Freq", crv_spec, draws = 5000, seed = 42)
  expect_identical(crv_res$status, "VALID")
  expect_equal(length(crv_res$rates), 12L) # 6 Depts x 2 Genders = 12 slices

  # Dept A の Male / Female の生割合と事後平均
  rate_a_male <- crv_res$rates[["A__Male"]]
  expect_equal(rate_a_male$obs_numerator, 512L)
  expect_equal(rate_a_male$obs_denominator, 825L)
  expect_equal(rate_a_male$raw_rate, round(512/825, 4))
  expect_true(rate_a_male$ci_lower < rate_a_male$post_mean && rate_a_male$post_mean < rate_a_male$ci_upper)

  # 割合差（Male - Female）
  diff_a <- crv_res$differences[["A__Male_minus_Female"]]
  expect_identical(diff_a$reference_level, "Female")
  expect_true(is.numeric(diff_a$difference_mean))
  expect_true(diff_a$ci_lower < diff_a$difference_mean && diff_a$difference_mean < diff_a$ci_upper)
})

cat("[SUCCESS] test_three_way_computation_engine.R passed all tests.\n")
