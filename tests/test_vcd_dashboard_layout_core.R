# Test: vcd-dashboard-layout-fix Core
# 目的: ダッシュボードの主要セクションが 1 カラムに固定され、順序が正しいことを検証する

suppressPackageStartupMessages({
  library(testthat)
})

repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = TRUE)
  if (file.exists(file.path(d, ".agent"))) return(d)
  if (identical(basename(d), "tests")) return(normalizePath(file.path(d, ".."), mustWork = TRUE))
  d
}

test_rmd_path <- file.path(repo_root(), ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")

test_that("主要セクションの Flex が解除され 1 カラムに固定されている", {
  if (!file.exists(test_rmd_path)) skip("Rmd file not found")
  rmd_content <- paste(readLines(test_rmd_path, encoding = "UTF-8"), collapse = "\n")
  
  # 2.1 Flex 解除の検証
  # .exec-topk-layout が display: block になっているか
  expect_true(grepl("\\.exec-topk-layout\\s*\\{[^}]*display:\\s*block", rmd_content), 
              info = ".exec-topk-layout に display: block が設定されていません")
  
  # .exec-summary-panel と .topk-panel から flex 指定が削除されているか
  # (既存の flex: 1 1 ... が残っていないか)
  expect_false(grepl("\\.exec-summary-panel\\s*\\{[^}]*flex:", rmd_content), 
               info = ".exec-summary-panel に flex 指定が残っています")
  expect_false(grepl("\\.topk-panel\\s*\\{[^}]*flex:", rmd_content), 
               info = ".topk-panel に flex 指定が残っています")
})

test_that("要素の表示順序が AIサマリー > Top-K の順になっている", {
  if (!file.exists(test_rmd_path)) skip("Rmd file not found")
  rmd_content <- paste(readLines(test_rmd_path, encoding = "UTF-8"), collapse = "\n")
  
  # 2.2 順序の検証
  summary_pos <- regexpr("exec-summary-panel", rmd_content)
  topk_pos <- regexpr("topk-panel", rmd_content)
  
  expect_true(summary_pos < topk_pos, 
              info = "AI サマリーパネルが Top-K パネルよりも後に配置されています")
})
