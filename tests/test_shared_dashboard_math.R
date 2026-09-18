#!/usr/bin/env Rscript
# Shared dashboard math contracts: leverage, BIC, Dirichlet α, offline asset resolution.

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, ".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R"))
source(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R"))
source(file.path(repo_root, ".agents/shared/dashboard_glossary.R"))
source(file.path(repo_root, ".agents/shared/dashboard_dt_ja.R"))

test_that("2次元独立モデルのレバレッジ閉形式は積項係数 -1 で GLM hatvalues と一致する", {
  y <- c(40, 20, 10, 30)
  df <- data.frame(
    A = factor(rep(c("a1", "a2"), each = 2)),
    B = factor(rep(c("b1", "b2"), 2)),
    Freq = y
  )
  fit <- glm(Freq ~ A + B, family = poisson(), data = df, control = glm.control(epsilon = 1e-15, maxit = 100))
  p_i <- c(a1 = 60, a2 = 40) / 100
  p_j <- c(b1 = 50, b2 = 50) / 100
  h_closed <- unname(p_i[as.character(df$A)] + p_j[as.character(df$B)] - p_i[as.character(df$A)] * p_j[as.character(df$B)])
  h_wrong <- unname(p_i[as.character(df$A)] + p_j[as.character(df$B)] - 2 * p_i[as.character(df$A)] * p_j[as.character(df$B)])
  expect_lt(max(abs(h_closed - hatvalues(fit))), 1e-8)
  expect_gt(max(abs(h_wrong - hatvalues(fit))), 1e-3)
})

test_that("ポアソン完全尤度 BIC と G2-df log N はモデル共通定数だけ異なる", {
  df <- read.csv(file.path(repo_root, "examples/ucb_admissions.csv"))
  fits <- fit_all_poisson_models(df, c("Dept", "Gender", "Admit"), "Freq")
  N <- sum(df$Freq)
  delta <- vapply(c("M5", "M8"), function(mid) {
    m <- fits$models[[mid]]
    bic_full <- -2 * as.numeric(logLik(m$fit)) + attr(logLik(m$fit), "df") * log(N)
    bic_dev <- m$fit$deviance - m$fit$df.residual * log(N)
    expect_equal(m$bic, bic_full, tolerance = 1e-6)
    bic_full - bic_dev
  }, numeric(1))
  expect_equal(unname(delta[["M5"]]), unname(delta[["M8"]]), tolerance = 1e-6)
  expect_gt(abs(delta[["M5"]]), 1)
})

test_that("2カテゴリ連続分布では中央値は補数になり得る", {
  med_a <- qbeta(0.5, 2, 3)
  med_b <- qbeta(0.5, 3, 2)
  expect_equal(med_a + med_b, 1, tolerance = 1e-12)
})

test_that("同一入力で α=1.0 の条件付き平均は旧実装と一致し、α=0.5 は意図して異なる", {
  df <- read.csv(file.path(repo_root, "examples/ucb_admissions.csv"))
  crv_spec <- list(
    response_var = "Admit",
    numerator_levels = c("Admitted"),
    denominator_levels = c("Admitted", "Rejected"),
    compare_by = "Gender",
    stratify_by = "Dept",
    interval_level = 0.95,
    reference_level = "Female"
  )
  old <- compute_conditional_rate_view(df, c("Dept", "Gender", "Admit"), "Freq", crv_spec,
    draws = 5000, seed = 42, primary_alpha = 1.0, sensitivity_alpha = 1.0
  )
  newp <- compute_conditional_rate_view(df, c("Dept", "Gender", "Admit"), "Freq", crv_spec,
    draws = 5000, seed = 42, primary_alpha = 0.5, sensitivity_alpha = 1.0
  )
  fixture <- jsonlite::fromJSON(
    file.path(repo_root, "tests/fixtures/dashboard_ui/ucb_admissions_three_way_v1/evidence_results.json"),
    simplifyVector = FALSE
  )
  expect_equal(old$prior_specification$alpha, 1.0)
  expect_equal(newp$prior_specification$alpha, 0.5)
  expect_equal(newp$sensitivity_prior$alpha, 1.0)
  expect_equal(newp$support$K, 24L)
  expect_true(is.null(fixture$conditional_rate_view$prior_specification))
  expect_equal(old$rates[["A__Male"]]$raw_rate, newp$rates[["A__Male"]]$raw_rate)
  expect_gt(abs(old$rates[["A__Male"]]$post_mean - newp$rates[["A__Male"]]$post_mean), 0)
  expect_equal(old$rates[["A__Male"]]$obs_numerator, 512)
})

test_that("集約率の Beta 解析平均は MC 要約と一致し、セルα=0.5を Beta(0.5,0.5) と同一視しない", {
  y_num <- 2
  y_den <- 20
  m <- 2
  d <- 5
  alpha <- 0.5
  a_post <- y_num + m * alpha
  b_post <- (y_den - y_num) + (d - m) * alpha
  analytic_mean <- a_post / (a_post + b_post)
  set.seed(1)
  draws <- rbeta(20000, a_post, b_post)
  expect_lt(abs(mean(draws) - analytic_mean), 0.01)
  beta_half_mean <- (y_num + 0.5) / (y_den + 1)
  expect_gt(abs(analytic_mean - beta_half_mean), 0.01)
})

test_that("層内全ゼロは HOLD を維持し、Poisson 局所診断候補式は N 閾値を使わない", {
  df <- data.frame(
    Dept = factor(c("A", "A", "B", "B")),
    Gender = factor(c("F", "F", "F", "F")),
    Admit = factor(c("Admitted", "Rejected", "Admitted", "Rejected")),
    Freq = c(0, 0, 5, 5)
  )
  crv_spec <- list(
    response_var = "Admit",
    numerator_levels = "Admitted",
    denominator_levels = c("Admitted", "Rejected"),
    compare_by = "Gender",
    stratify_by = "Dept",
    interval_level = 0.95,
    reference_level = NULL
  )
  crv <- compute_conditional_rate_view(df, c("Dept", "Gender", "Admit"), "Freq", crv_spec,
    draws = 200, seed = 1, primary_alpha = 0.5, sensitivity_alpha = 1.0
  )
  expect_identical(crv$rates[["A__F"]]$status, "HOLD_ZERO_DENOMINATOR")
  expect_true(crv$status %in% c("PARTIAL_HOLD", "HOLD"))

  assign_line <- grep("is_candidate_dual_filter <-", readLines(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R"), warn = FALSE, encoding = "UTF-8"), value = TRUE)
  expect_true(any(grepl("score_stat >= 3.84", assign_line)))
  expect_false(any(grepl("large_n_threshold", assign_line)))
})

test_that("共有資産欠落とリポジトリ外cwdでは明示停止し、確認済みrootなら解決する", {
  outside <- tempfile("outside_cwd_")
  dir.create(outside)
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(outside)
  found <- FALSE
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(8L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) found <- TRUE
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  expect_false(found)
  missing_css <- file.path(outside, ".agents", "shared", "dashboard_theme.css")
  expect_false(file.exists(missing_css))
  expect_error(
    {
      root <- repo_root
      needed <- c("dashboard_theme.css", "dashboard_dt_ja.R", "dashboard_glossary.R")
      stopifnot(all(file.exists(file.path(root, ".agents", "shared", needed))))
    },
    NA
  )
  rmd2 <- readLines(file.path(repo_root, ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd"), warn = FALSE)
  start <- grep("find_agent_repo <- function", rmd2)[1]
  end <- grep("^shared_root <- resolve_shared_dashboard_root", rmd2)[1] - 1L
  eval(parse(text = paste(rmd2[start:end], collapse = "\n")), envir = environment())
  expect_error(resolve_shared_dashboard_root(outside), "欠落")
  expect_identical(
    normalizePath(resolve_shared_dashboard_root(repo_root), winslash = "/"),
    normalizePath(repo_root, winslash = "/")
  )
  rmd3 <- paste(readLines(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd"), warn = FALSE), collapse = "\n")
  expect_true(grepl("共有ダッシュボード資産が欠落しています", rmd3, fixed = TRUE))

  lang <- get_dt_ja_lang()
  expect_identical(lang$emptyTable, "データが登録されていません")
  html <- render_dashboard_glossary(list(
    dimension = 2L,
    prior = list(family = "symmetric_dirichlet", alpha = 0.5, role = "primary", name = "jeffreys"),
    sensitivity_prior = list(family = "symmetric_dirichlet", alpha = 1.0, role = "sensitivity", name = "uniform"),
    interval_level = 0.95,
    zero_cell_convention = "nonfinite",
    candidate_rule = "N ≥ 2000",
    support_k = 4
  ))
  expect_true(grepl("h<sub>ij</sub> = p<sub>i+</sub> + p<sub>+j</sub>", html, fixed = TRUE))
  expect_false(grepl("− 2 p", html, fixed = TRUE))
  expect_false(grepl("- 2 p", html, fixed = TRUE))
  expect_false(grepl("数学的に 1 にはなりません", html, fixed = TRUE))
  expect_true(grepl("一般には1に制約されません", html, fixed = TRUE) || grepl("一般には 1 に制約されません", html, fixed = TRUE))
})
