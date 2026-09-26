#!/usr/bin/env Rscript
# =============================================================================
# tests/test_dashboard_fixture_invariance.R
# UI Fixture 不変性および数値契約回帰テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(digest)
})

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
fixtures_dir <- file.path(repo_root, "tests", "fixtures", "dashboard_ui")

test_that("Antigravity OTC_Q05 Fixture のハッシュ不変性が保たれていること", {
  otc_dir <- file.path(fixtures_dir, "antigravity_otc_q05_v1")
  expect_true(file.exists(file.path(otc_dir, "manifest.json")))

  man <- jsonlite::fromJSON(file.path(otc_dir, "manifest.json"))
  for (art in names(man$artifacts)) {
    fpath <- file.path(otc_dir, art)
    expect_true(file.exists(fpath), info = paste("Missing fixture file:", fpath))
    h <- digest::digest(file = fpath, algo = "sha256")
    expect_equal(h, man$artifacts[[art]]$sha256, info = paste("Hash mismatch for:", art))
  }
})

test_that("新 UCB Admissions 3-Way Fixture のハッシュ不変性が保たれていること", {
  ucb_dir <- file.path(fixtures_dir, "ucb_admissions_three_way_v1")
  expect_true(file.exists(file.path(ucb_dir, "manifest.json")))

  man <- jsonlite::fromJSON(file.path(ucb_dir, "manifest.json"))
  for (art in names(man$artifacts)) {
    fpath <- file.path(ucb_dir, art)
    expect_true(file.exists(fpath), info = paste("Missing fixture file:", fpath))
    h <- digest::digest(file = fpath, algo = "sha256")
    expect_equal(h, man$artifacts[[art]]$sha256, info = paste("Hash mismatch for:", art))
  }
})

test_that("UCB Fixture の数値契約が正確に維持されていること", {
  ucb_dir <- file.path(fixtures_dir, "ucb_admissions_three_way_v1")
  res <- jsonlite::fromJSON(file.path(ucb_dir, "evidence_results.json"))

  # 総度数とセル数
  expect_equal(res$input_summary$total_n, 4526)
  expect_equal(res$input_summary$n_cells, 24)

  # 最良モデル M5 と次点 M8 の明示式 BIC
  summary_df <- as.data.frame(res$models$summary)
  m5_row <- summary_df[summary_df$model_id == "M5", ]
  m8_row <- summary_df[summary_df$model_id == "M8", ]
  expect_equal(nrow(m5_row), 1L)
  expect_equal(nrow(m8_row), 1L)
  expect_equal(round(as.numeric(m5_row$bic), 4), 332.3119)
  expect_equal(round(as.numeric(m8_row$bic), 4), 339.1982)
  expect_equal(res$models$best_model_id, "M5")

  # M1 / M5 基準別セル診断件数
  m1_counts <- res$cells$by_base_model$M1$counts
  m5_counts <- res$cells$by_base_model$M5$counts
  expect_equal(m1_counts$candidate_cells, 12L)
  expect_equal(m1_counts$regular_cells, 24L)
  expect_equal(m1_counts$quarantined_cells, 0L)

  expect_equal(m5_counts$candidate_cells, 1L)
  expect_equal(m5_counts$regular_cells, 13L)
  expect_equal(m5_counts$quarantined_cells, 11L)

  # 条件付き割合の整合性
  crv <- res$conditional_rate_view
  expect_equal(crv$status, "VALID")
  expect_equal(crv$rates$A__Male$obs_numerator, 512L)
  expect_equal(crv$rates$A__Male$obs_denominator, 825L)
  expect_equal(round(crv$rates$A__Male$post_mean, 4), 0.6204)
  expect_equal(round(crv$differences$A__Male_minus_Female$difference_mean, 4), -0.1976)
})

test_that("UCB Fixture HTML が完全オフラインで外部URL参照を一切持たないこと", {
  ucb_dir <- file.path(fixtures_dir, "ucb_admissions_three_way_v1")
  html_lines <- readLines(file.path(ucb_dir, "dashboard.html"), warn = FALSE, encoding = "UTF-8")
  bad_tags <- grep("<(script|link)[^>]+(src|href)=[\"']https?://", html_lines, perl = TRUE, value = TRUE)
  expect_equal(length(bad_tags), 0L)
  expect_false(any(grepl("MathJax", html_lines)))
  expect_false(any(grepl("ja\\.json", html_lines)))
})

cat("\n==================================================\n")
cat("すべての Fixture 不変性テストがパスしました。\n")
cat("==================================================\n\n")
