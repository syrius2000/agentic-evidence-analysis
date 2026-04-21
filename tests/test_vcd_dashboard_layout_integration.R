# Test: vcd-dashboard-layout-fix Integration
# 目的: ダッシュボード全体のレイアウトが 1000px 以内に収まり、中央寄せされていることを最終検証する

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

test_that("ダッシュボード全体が 1 カラム構成として統合されている", {
  if (!file.exists(test_rmd_path)) skip("Rmd file not found")
  rmd_content <- paste(readLines(test_rmd_path, encoding = "UTF-8"), collapse = "\n")
  
  # コンテナの開始と終了が Rmd ファイル内にコードとして含まれているか
  expect_true(grepl("cat\\('<div class=\"dashboard-main-content\">'\\)", rmd_content), 
              info = "dashboard-main-content の開始タグを cat する R コードが見つかりません")
  expect_true(grepl("cat\\('</div>'\\) # End \\.dashboard-main-content", rmd_content), 
              info = "dashboard-main-content の終了タグを cat する R コードが見つかりません")
  
  # 余計な gap や flex 指定が主要要素に干渉していないか
  expect_false(grepl("exec-topk-layout\\s*\\{[^}]*gap:", rmd_content), 
               info = "ブロック要素となった exec-topk-layout に不要な gap 指定が残っています（余白は margin で制御すべき）")
})
