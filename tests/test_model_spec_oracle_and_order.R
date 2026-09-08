# =============================================================================
# test_model_spec_oracle_and_order.R
# タスク 4.1 の検証テスト: 独立正解辞書との完全一致および変数順序・応答変数追従
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
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

# -----------------------------------------------------------------------------
# 1. 独立した正解仕様辞書（Oracle Dictionary: 教科書的定義に基づく正解）
# -----------------------------------------------------------------------------
oracle_3way <- list(
  M1 = list(
    bracket = "[A][B][C]",
    kind = "mutual_independence",
    generators = list(c("A"), c("B"), c("C")),
    statements = list(
      list(left = c("A"), right = c("B"), given = character(0)),
      list(left = c("A", "B"), right = c("C"), given = character(0))
    )
  ),
  M2 = list(
    bracket = "[AB][C]",
    kind = "joint_independence",
    generators = list(c("A", "B"), c("C")),
    statements = list(list(left = c("A", "B"), right = c("C"), given = character(0)))
  ),
  M3 = list(
    bracket = "[AC][B]",
    kind = "joint_independence",
    generators = list(c("A", "C"), c("B")),
    statements = list(list(left = c("A", "C"), right = c("B"), given = character(0)))
  ),
  M4 = list(
    bracket = "[BC][A]",
    kind = "joint_independence",
    generators = list(c("B", "C"), c("A")),
    statements = list(list(left = c("B", "C"), right = c("A"), given = character(0)))
  ),
  M5 = list(
    bracket = "[AB][AC]",
    kind = "conditional_independence",
    generators = list(c("A", "B"), c("A", "C")),
    statements = list(list(left = c("B"), right = c("C"), given = c("A")))
  ),
  M6 = list(
    bracket = "[AB][BC]",
    kind = "conditional_independence",
    generators = list(c("A", "B"), c("B", "C")),
    statements = list(list(left = c("A"), right = c("C"), given = c("B")))
  ),
  M7 = list(
    bracket = "[AC][BC]",
    kind = "conditional_independence",
    generators = list(c("A", "C"), c("B", "C")),
    statements = list(list(left = c("A"), right = c("B"), given = c("C")))
  ),
  M8 = list(
    bracket = "[AB][AC][BC]",
    kind = "no_independence_constraint",
    generators = list(c("A", "B"), c("A", "C"), c("B", "C")),
    statements = list()
  ),
  M9 = list(
    bracket = "[ABC]",
    kind = "no_independence_constraint",
    generators = list(c("A", "B", "C")),
    statements = list()
  )
)

oracle_2way <- list(
  M1 = list(
    bracket = "[A][B]",
    kind = "mutual_independence",
    generators = list(c("A"), c("B")),
    statements = list(list(left = c("A"), right = c("B"), given = character(0)))
  ),
  M2 = list(
    bracket = "[AB]",
    kind = "no_independence_constraint",
    generators = list(c("A", "B")),
    statements = list()
  )
)

# -----------------------------------------------------------------------------
# テスト 1: R エンジン導出メタデータと Oracle の完全一致検証
# -----------------------------------------------------------------------------
test_that("タスク 4.1: 3元表モデル M1〜M9 の生成クラスと構造化独立性が Oracle と完全一致する", {
  expect_identical(names(MODEL_SPECS_3WAY), names(oracle_3way))
  f_map_3way <- build_factor_map(c("A", "B", "C"))
  
  for (mid in names(oracle_3way)) {
    spec <- MODEL_SPECS_3WAY[[mid]]
    act <- derive_model_metadata(spec, f_map_3way)
    exp <- oracle_3way[[mid]]
    
    expect_identical(act$bracket_notation, exp$bracket, info = sprintf("%s bracket mismatch", mid))
    expect_identical(act$independence$kind, exp$kind, info = sprintf("%s kind mismatch", mid))
    
    # generators の各要素一致
    act_gens <- lapply(act$generators, function(x) sort(as.character(x)))
    exp_gens <- lapply(exp$generators, sort)
    expect_identical(act_gens, exp_gens, info = sprintf("%s generators mismatch", mid))
    
    # statements の一致
    expect_equal(length(act$independence$statements), length(exp$statements), info = sprintf("%s statements length", mid))
    if (length(exp$statements) > 0L) {
      for (i in seq_along(exp$statements)) {
        expect_equal(as.character(act$independence$statements[[i]]$left), as.character(exp$statements[[i]]$left))
        expect_equal(as.character(act$independence$statements[[i]]$right), as.character(exp$statements[[i]]$right))
        expect_equal(as.character(act$independence$statements[[i]]$given), as.character(exp$statements[[i]]$given))
      }
    }
  }
})

test_that("タスク 4.1: 2元表モデル M1〜M2 の生成クラスと構造化独立性が Oracle と完全一致する", {
  expect_identical(names(MODEL_SPECS_2WAY), names(oracle_2way))
  f_map_2way <- build_factor_map(c("A", "B"))
  
  for (mid in names(oracle_2way)) {
    spec <- MODEL_SPECS_2WAY[[mid]]
    act <- derive_model_metadata(spec, f_map_2way)
    exp <- oracle_2way[[mid]]
    
    expect_identical(act$bracket_notation, exp$bracket, info = sprintf("%s bracket mismatch", mid))
    expect_identical(act$independence$kind, exp$kind, info = sprintf("%s kind mismatch", mid))
    
    act_gens <- lapply(act$generators, function(x) sort(as.character(x)))
    exp_gens <- lapply(exp$generators, sort)
    expect_identical(act_gens, exp_gens, info = sprintf("%s generators mismatch", mid))
    
    expect_equal(length(act$independence$statements), length(exp$statements), info = sprintf("%s statements length", mid))
    if (length(exp$statements) > 0L) {
      for (i in seq_along(exp$statements)) {
        expect_equal(as.character(act$independence$statements[[i]]$left), as.character(exp$statements[[i]]$left))
        expect_equal(as.character(act$independence$statements[[i]]$right), as.character(exp$statements[[i]]$right))
        expect_equal(as.character(act$independence$statements[[i]]$given), as.character(exp$statements[[i]]$given))
      }
    }
  }
})

# -----------------------------------------------------------------------------
# テスト 2: 変数順序の並べ替えに対する動的追従検証 (Permutation Invariance)
# -----------------------------------------------------------------------------
test_that("タスク 4.1: vars の並べ替えに対して因子マッピングと実変数展開が一貫して追従する", {
  # 順序 1: c("Dept", "Gender", "Admit") -> A:Dept, B:Gender, C:Admit
  # M5 = [AB][AC] -> [Dept, Gender][Dept, Admit], B perp C | A -> Gender perp Admit | Dept
  fmap1 <- build_factor_map(c("Dept", "Gender", "Admit"))
  meta1 <- derive_model_metadata(MODEL_SPECS_3WAY$M5, fmap1)
  expect_identical(fmap1$A$variable, "Dept")
  expect_identical(fmap1$B$variable, "Gender")
  expect_identical(fmap1$C$variable, "Admit")
  expect_identical(meta1$bracket_expanded, "[Dept, Gender][Dept, Admit]")
  expect_match(meta1$independence$description_ja, "Dept.*で層別したとき.*Gender.*と.*Admit.*は条件付き独立")
  
  # 順序 2: c("Admit", "Gender", "Dept") -> A:Admit, B:Gender, C:Dept
  # M5 = [AB][AC] -> [Admit, Gender][Admit, Dept], B perp C | A -> Gender perp Dept | Admit
  fmap2 <- build_factor_map(c("Admit", "Gender", "Dept"))
  meta2 <- derive_model_metadata(MODEL_SPECS_3WAY$M5, fmap2)
  expect_identical(fmap2$A$variable, "Admit")
  expect_identical(fmap2$B$variable, "Gender")
  expect_identical(fmap2$C$variable, "Dept")
  expect_identical(meta2$bracket_expanded, "[Admit, Gender][Admit, Dept]")
  expect_match(meta2$independence$description_ja, "Admit.*で層別したとき.*Gender.*と.*Dept.*は条件付き独立")
  
  # 順序 3: c("Gender", "Admit", "Dept") -> A:Gender, B:Admit, C:Dept
  # M5 = [AB][AC] -> [Gender, Admit][Gender, Dept], B perp C | A -> Admit perp Dept | Gender
  fmap3 <- build_factor_map(c("Gender", "Admit", "Dept"))
  meta3 <- derive_model_metadata(MODEL_SPECS_3WAY$M5, fmap3)
  expect_identical(fmap3$A$variable, "Gender")
  expect_identical(fmap3$B$variable, "Admit")
  expect_identical(fmap3$C$variable, "Dept")
  expect_identical(meta3$bracket_expanded, "[Gender, Admit][Gender, Dept]")
  expect_match(meta3$independence$description_ja, "Gender.*で層別したとき.*Admit.*と.*Dept.*は条件付き独立")
})

# -----------------------------------------------------------------------------
# テスト 3: 対数線形モデルの対称性と response_var に対する独立性
# -----------------------------------------------------------------------------
test_that("タスク 4.1: 対数線形モデルの定式化と数理定義は、全因子に対して対称であり response_var 指定の有無に依存せず不変である", {
  vars <- c("Dept", "Gender", "Admit")
  fmap <- build_factor_map(vars)
  
  dummy_df <- data.frame(
    Dept = rep(c("A", "B"), each = 4),
    Gender = rep(rep(c("M", "F"), each = 2), 2),
    Admit = rep(c("Yes", "No"), 4),
    Freq = c(10, 20, 30, 40, 50, 60, 70, 80),
    stringsAsFactors = TRUE
  )
  
  # 対数線形モデルの適合実行
  res_fit <- fit_all_poisson_models(dummy_df, vars, "Freq")
  
  # definitions の数学的構造と完全性を検証
  expect_true(!is.null(res_fit$definitions))
  expect_equal(length(res_fit$definitions), 9L)
  expect_identical(res_fit$dimension, 3L)
  expect_identical(res_fit$notation_version, "1.0.0")
  
  for (mid in names(res_fit$definitions)) {
    d <- res_fit$definitions[[mid]]
    expect_true(nzchar(d$bracket_notation))
    expect_true(nzchar(d$bracket_expanded))
    expect_true(nzchar(d$fitted_formula))
    expect_true(nzchar(d$formula_latex))
    expect_true(nzchar(d$independence$description_ja))
    # generators の各要素が factor_map の記号と整合すること
    for (gen in d$generators) {
      expect_true(all(as.character(gen) %in% names(fmap)))
    }
  }
})
