# Test: vcd-dashboard-layout-fix Foundation
# 目的: ダッシュボードに共通コンテナと最大幅制約が導入されていることを検証する

suppressPackageStartupMessages({
  library(testthat)
  library(rmarkdown)
})

repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = TRUE)
  if (file.exists(file.path(d, ".agent"))) return(d)
  if (identical(basename(d), "tests")) return(normalizePath(file.path(d, ".."), mustWork = TRUE))
  d
}

test_rmd_path <- file.path(repo_root(), ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")

test_that("ダッシュボードにメインコンテナと最大幅制約が導入されている", {
  if (!file.exists(test_rmd_path)) skip("Rmd file not found")
  
  # Rmd の内容を読み込む
  rmd_content <- paste(readLines(test_rmd_path, encoding = "UTF-8"), collapse = "\n")
  
  # 1. .dashboard-main-content クラスが定義されているか
  expect_true(grepl("\\.dashboard-main-content", rmd_content), 
              info = ".dashboard-main-content CSS クラスが定義されていません")
  
  # 2. max-width: 1000px が定義されているか
  expect_true(grepl("max-width:\\s*1000px", rmd_content), 
              info = "max-width: 1000px の制約が定義されていません")
  
  # 3. margin: auto (または 0 auto) が定義されているか
  expect_true(grepl("margin:\\s*(0\\s+)?auto", rmd_content), 
              info = "margin: auto による中央寄せが定義されていません")
})
