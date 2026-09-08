# =============================================================================
# test_loglinear_specs_and_formulas.R
# タスク 1.2, 1.3, 1.4 の検証テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(stats)
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

test_that("タスク 1.2: MODEL_SPECS_3WAY と MODEL_SPECS_2WAY の全キーと構造が正しく定義されている", {
  # 3元表: M1〜M9 の9モデル
  expect_equal(length(MODEL_SPECS_3WAY), 9L)
  expect_equal(names(MODEL_SPECS_3WAY), paste0("M", 1:9))
  
  required_keys <- c("id", "model_key", "name", "order", "generators", "bracket_notation",
                     "independence", "formula_latex", "formula_description_ja")
  
  for (m_id in names(MODEL_SPECS_3WAY)) {
    spec <- MODEL_SPECS_3WAY[[m_id]]
    for (k in required_keys) {
      expect_true(k %in% names(spec), info = sprintf("3way %s にキー %s が存在すること", m_id, k))
    }
    expect_true(is.list(spec$generators), info = sprintf("%s の generators は list", m_id))
    expect_true(length(spec$generators) >= 1L, info = sprintf("%s の generators は 1 以上", m_id))
    expect_true(is.list(spec$independence), info = sprintf("%s の independence は list", m_id))
    expect_true(spec$independence$kind %in% c("mutual_independence", "joint_independence",
                                              "conditional_independence", "no_independence_constraint"))
  }
  
  # 2元表: M1, M2 の2モデル
  expect_equal(length(MODEL_SPECS_2WAY), 2L)
  expect_equal(names(MODEL_SPECS_2WAY), c("M1", "M2"))
  for (m_id in names(MODEL_SPECS_2WAY)) {
    spec <- MODEL_SPECS_2WAY[[m_id]]
    for (k in required_keys) {
      expect_true(k %in% names(spec), info = sprintf("2way %s にキー %s が存在すること", m_id, k))
    }
  }
})

test_that("タスク 1.3: build_formula_from_generators と validate_formula_terms が全モデルで展開項一致を保証する", {
  vars_3way <- c("Dept", "Gender", "Admit")
  f_map_3way <- build_factor_map(vars_3way)
  freq_col <- "Freq"
  
  for (m_id in names(MODEL_SPECS_3WAY)) {
    spec <- MODEL_SPECS_3WAY[[m_id]]
    fmla <- build_formula_from_generators(spec$generators, f_map_3way, freq_col)
    expect_s3_class(fmla, "formula")
    
    # validate_formula_terms がエラーなく通過（完全一致）すること
    expect_silent(validate_formula_terms(fmla, spec$generators, f_map_3way))
  }
  
  # 2元表でも同様に検証
  vars_2way <- c("Gender", "Admit")
  f_map_2way <- build_factor_map(vars_2way)
  for (m_id in names(MODEL_SPECS_2WAY)) {
    spec <- MODEL_SPECS_2WAY[[m_id]]
    fmla <- build_formula_from_generators(spec$generators, f_map_2way, freq_col)
    expect_silent(validate_formula_terms(fmla, spec$generators, f_map_2way))
  }
  
  # 意図的に項を改ざんした場合に validate_formula_terms がエラーを投げることの確認
  bad_fmla <- as.formula("Freq ~ Dept + Gender") # Admit が抜けている
  expect_error(validate_formula_terms(bad_fmla, MODEL_SPECS_3WAY$M1$generators, f_map_3way),
               "formula の展開項と生成クラスが一致しません")
})

test_that("タスク 1.4: 構造化独立性情報と実変数展開メタデータが正しく導出され、M8/M9は交互作用制約として記録される", {
  vars_3way <- c("Dept", "Gender", "Admit")
  f_map_3way <- build_factor_map(vars_3way)
  
  # M5 (条件付き独立: B \perp C | A)
  meta_m5 <- derive_model_metadata(MODEL_SPECS_3WAY$M5, f_map_3way)
  expect_equal(meta_m5$bracket_notation, "[AB][AC]")
  expect_equal(meta_m5$bracket_expanded, "[Dept, Gender][Dept, Admit]")
  expect_equal(meta_m5$independence$kind, "conditional_independence")
  expect_equal(meta_m5$independence$statements[[1]]$left, I(c("B")))
  expect_equal(meta_m5$independence$statements[[1]]$right, I(c("C")))
  expect_equal(meta_m5$independence$statements[[1]]$given, I(c("A")))
  expect_match(meta_m5$independence$description_ja, "Dept.*で層別したとき.*Gender.*と.*Admit.*は条件付き独立")
  
  # M8 (均一連関)
  meta_m8 <- derive_model_metadata(MODEL_SPECS_3WAY$M8, f_map_3way)
  expect_equal(meta_m8$bracket_notation, "[AB][AC][BC]")
  expect_equal(meta_m8$bracket_expanded, "[Dept, Gender][Dept, Admit][Gender, Admit]")
  expect_equal(meta_m8$independence$kind, "no_independence_constraint")
  expect_equal(length(meta_m8$independence$statements), 0L)
  expect_match(meta_m8$independence$description_ja, "全2因子交互作用を含み.*3因子交互作用を含まない")
  
  # M9 (飽和)
  meta_m9 <- derive_model_metadata(MODEL_SPECS_3WAY$M9, f_map_3way)
  expect_equal(meta_m9$bracket_notation, "[ABC]")
  expect_equal(meta_m9$bracket_expanded, "[Dept, Gender, Admit]")
  expect_equal(meta_m9$independence$kind, "no_independence_constraint")
  expect_equal(length(meta_m9$independence$statements), 0L)
  expect_match(meta_m9$independence$description_ja, "飽和モデル")
})
