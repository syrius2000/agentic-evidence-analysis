# =============================================================================
# test_loglinear_json_output.R
# タスク 1.5 の検証テスト: JSON保存・再読込・型契約検証
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

test_that("タスク 1.5: analysis.R が出力する evidence_results.json が型契約と数理構造を満たす", {
  test_out_dir <- file.path(repo_root, "output/test_json_schema")
  if (dir.exists(test_out_dir)) {
    unlink(test_out_dir, recursive = TRUE)
  }
  
  # analysis.R をテスト用 run_id で実行
  cmd <- sprintf("Rscript %s --input %s --vars Dept,Gender,Admit --freq Freq --response_var Admit --output_dir %s --run-id test_schema",
                 shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
                 shQuote(file.path(repo_root, "examples/ucb_admissions.csv")),
                 shQuote(test_out_dir))
  
  ret <- system(cmd, intern = TRUE)
  
  # 出力先ディレクトリを run_scope に従って解決
  # run_test_schema ディレクトリを探す
  run_dirs <- list.dirs(test_out_dir, full.names = TRUE, recursive = FALSE)
  expect_true(length(run_dirs) >= 1L, info = "出力runディレクトリが作成されていること")
  
  json_file <- file.path(run_dirs[1], "evidence_results.json")
  expect_true(file.exists(json_file), info = "evidence_results.json が作成されていること")
  
  # 再読込して検証
  raw_json_str <- readLines(json_file, warn = FALSE)
  res <- jsonlite::fromJSON(paste(raw_json_str, collapse = "\n"), simplifyVector = FALSE)
  
  expect_equal(res$models$notation_version, "1.0.0")
  expect_equal(res$models$dimension, 3L)
  
  # factor_map の検証
  expect_named(res$models$factor_map, c("A", "B", "C"))
  expect_equal(res$models$factor_map$A$variable, "Dept")
  expect_equal(res$models$factor_map$B$variable, "Gender")
  expect_equal(res$models$factor_map$C$variable, "Admit")
  
  # definitions の検証 (オブジェクト形式で M1〜M9)
  expect_named(res$models$definitions, paste0("M", 1:9))
  
  # 単一要素配列の型崩れ（スカラー化）がないことを確認
  # M1 の generators: [["A"], ["B"], ["C"]]
  expect_true(is.list(res$models$definitions$M1$generators))
  expect_equal(length(res$models$definitions$M1$generators), 3L)
  expect_true(is.list(res$models$definitions$M1$generators[[1]]))
  expect_equal(res$models$definitions$M1$generators[[1]][[1]], "A")
  
  # M5 の statements: left=["B"], right=["C"], given=["A"]
  m5_st <- res$models$definitions$M5$independence$statements[[1]]
  expect_true(is.list(m5_st$left))
  expect_equal(m5_st$left[[1]], "B")
  expect_true(is.list(m5_st$given))
  expect_equal(m5_st$given[[1]], "A")
  
  # summary の検証 (データフレーム/配列で各モデルの数値が保存されていること)
  expect_true(length(res$models$summary) == 9L)
  first_sum <- res$models$summary[[1]]
  expect_true(all(c("model_id", "model_name", "df_residual", "deviance", "bic") %in% names(first_sum)))
  
  # クリーンアップ
  unlink(test_out_dir, recursive = TRUE)
})
