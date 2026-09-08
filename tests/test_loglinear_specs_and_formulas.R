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

test_that("タスク 1.2: MODEL_SPECS_3WAY と MODEL_SPECS_2WAY の辞書構造および derive_model_metadata による完全メタデータ導出", {
  # 3元表: M1〜M9 の9モデル
  expect_equal(length(MODEL_SPECS_3WAY), 9L)
  expect_equal(names(MODEL_SPECS_3WAY), paste0("M", 1:9))
  
  dict_keys <- c("id", "model_key", "name", "order", "generators")
  vars_3way <- c("Dept", "Gender", "Admit")
  f_map_3way <- build_factor_map(vars_3way)
  
  for (m_id in names(MODEL_SPECS_3WAY)) {
    spec <- MODEL_SPECS_3WAY[[m_id]]
    for (k in dict_keys) {
      expect_true(k %in% names(spec), info = sprintf("3way %s に正本キー %s が存在すること", m_id, k))
    }
    expect_true(is.list(spec$generators), info = sprintf("%s の generators は list", m_id))
    expect_true(length(spec$generators) >= 1L, info = sprintf("%s の generators は 1 以上", m_id))
    
    # derive_model_metadata による一元導出メタデータの検証
    meta <- derive_model_metadata(spec, f_map_3way)
    expected_derived_keys <- c("model_id", "model_key", "generators", "bracket_notation",
                               "bracket_expanded", "independence", "formula_latex", "formula_description_ja")
    for (k in expected_derived_keys) {
      expect_true(k %in% names(meta), info = sprintf("3way %s の導出メタデータに %s が存在すること", m_id, k))
    }
    expect_true(is.list(meta$independence), info = sprintf("%s の independence は list", m_id))
    expect_true(meta$independence$kind %in% c("mutual_independence", "joint_independence",
                                              "conditional_independence", "no_independence_constraint"))
  }
  
  # 2元表: M1, M2 の2モデル
  expect_equal(length(MODEL_SPECS_2WAY), 2L)
  expect_equal(names(MODEL_SPECS_2WAY), c("M1", "M2"))
  vars_2way <- c("Gender", "Admit")
  f_map_2way <- build_factor_map(vars_2way)
  for (m_id in names(MODEL_SPECS_2WAY)) {
    spec <- MODEL_SPECS_2WAY[[m_id]]
    for (k in dict_keys) {
      expect_true(k %in% names(spec), info = sprintf("2way %s に正本キー %s が存在すること", m_id, k))
    }
    meta <- derive_model_metadata(spec, f_map_2way)
    expect_true(meta$independence$kind %in% c("mutual_independence", "no_independence_constraint"))
  }
})

test_that("CRITICAL 1 検証: generators を変更した場合に全メタデータ（記号・実変数・式・独立性）が完全に自動追従する", {
  vars_3way <- c("Dept", "Gender", "Admit")
  f_map_3way <- build_factor_map(vars_3way)
  
  # 意図的に M5 の generators を相互独立 [A][B][C] に差し替えた場合
  mutated_spec <- list(
    id = "M5",
    model_key = "3way_M5",
    name = "cond_indep_BC_given_A",
    order = 2,
    generators = list(c("A"), c("B"), c("C"))
  )
  
  meta_mutated <- derive_model_metadata(mutated_spec, f_map_3way)
  
  # 記号表記と実変数展開が両方とも [A][B][C] / [Dept][Gender][Admit] に追従すること
  expect_equal(meta_mutated$bracket_notation, "[A][B][C]")
  expect_equal(meta_mutated$bracket_expanded, "[Dept][Gender][Admit]")
  
  # 独立性構造が conditional_independence ではなく mutual_independence に自動追従すること
  expect_equal(meta_mutated$independence$kind, "mutual_independence")
  expect_match(meta_mutated$independence$description_ja, "3因子が相互に独立")
  
  # LaTeX 数式が相互独立モデルの式に追従すること
  expect_match(meta_mutated$formula_latex, "\\\\lambda_i\\^A \\+ \\\\lambda_j\\^B \\+ \\\\lambda_k\\^C")
  expect_false(grepl("\\\\lambda_\\{ij\\}", meta_mutated$formula_latex))
})

test_that("CRITICAL 2 検証: is_definition_consistent_with_formula が項レベルで不整合を正確に検知する", {
  vars_3way <- c("Dept", "Gender", "Admit")
  f_map_3way <- build_factor_map(vars_3way)
  
  # M5 ([AB][AC]) の定義
  def_m5 <- derive_model_metadata(MODEL_SPECS_3WAY$M5, f_map_3way)
  
  # 正常な M5 適合式
  correct_fmla <- "Freq ~ Dept * Gender + Dept * Admit"
  expect_true(is_definition_consistent_with_formula(def_m5, correct_fmla, f_map_3way))
  
  # 不整合な適合式（M8 均一連関の式を与えた場合）
  mismatched_fmla <- "Freq ~ Dept * Gender + Dept * Admit + Gender * Admit"
  expect_false(is_definition_consistent_with_formula(def_m5, mismatched_fmla, f_map_3way))
  
  # 欠落した式（主効果のみ）
  missing_fmla <- "Freq ~ Dept + Gender + Admit"
  expect_false(is_definition_consistent_with_formula(def_m5, missing_fmla, f_map_3way))
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
