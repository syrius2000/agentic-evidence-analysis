# vcd-dashboard-layout-fix: BF10 / Evidence 閾値の表示書式（dashboard.Rmd と整合）

suppressPackageStartupMessages({
  library(testthat)
})

repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = TRUE)
  if (file.exists(file.path(d, ".agent"))) {
    return(d)
  }
  if (identical(basename(d), "tests")) {
    return(normalizePath(file.path(d, ".."), mustWork = TRUE))
  }
  d
}

fmt_bf10 <- function(raw) {
  x <- suppressWarnings(as.numeric(raw))
  if (length(x) != 1L || is.na(x) || !is.finite(x)) {
    enc <- htmltools::htmlEscape(as.character(raw)[1] %||% "", attribute = FALSE)
    if (nchar(enc) > 32L) {
      enc <- paste0(substr(enc, 1L, 29L), "...")
    }
    return(enc)
  }
  ax <- abs(x)
  if (ax >= 1e-2 && ax < 1e4) {
    sprintf("%.2f", x)
  } else {
    sprintf("%.2e", x)
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x

fmt_threshold <- function(threshold) {
  thr_num <- suppressWarnings(as.numeric(threshold))
  if (length(thr_num) == 1L && is.finite(thr_num)) {
    sprintf("%.2f", thr_num)
  } else {
    "N/A"
  }
}

test_that("BF10 display: normal range uses two fixed decimals", {
  skip_if_not_installed("htmltools")
  expect_equal(fmt_bf10(1.5), "1.50")
  expect_equal(fmt_bf10(100), "100.00")
  expect_equal(fmt_bf10(-2.3), "-2.30")
})

test_that("BF10 display: outside range uses scientific notation", {
  skip_if_not_installed("htmltools")
  expect_match(fmt_bf10(1e10), "e\\+")
  expect_match(fmt_bf10(1e-4), "e")
})

test_that("Evidence threshold display is two decimals", {
  expect_equal(fmt_threshold(3.14159), "3.14")
  expect_equal(fmt_threshold("2.5"), "2.50")
  expect_equal(fmt_threshold(NA_real_), "N/A")
})

test_that("dashboard.Rmd avoids legacy four-decimal threshold formatting", {
  p <- file.path(repo_root(), ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
  skip_if_not(file.exists(p))
  txt <- paste(readLines(p, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(
    grepl("sprintf\\(\"%\\.4f\",\\s*as\\.numeric\\(threshold\\)\\)", txt),
    info = "閾値に %.4f(as.numeric(threshold)) が残っています"
  )
  expect_false(
    grepl("round\\(\\s*as\\.numeric\\(\\s*threshold\\s*\\)\\s*,\\s*4\\s*\\)", txt),
    info = "round(as.numeric(threshold), 4) が残っています"
  )
  expect_false(
    grepl("round\\(\\s*threshold\\s*,\\s*4\\s*\\)", txt),
    info = "round(threshold, 4) が残っています"
  )
  expect_true(grepl("threshold_display", txt), info = "threshold_display が未定義です")
  expect_true(grepl("bf10_display", txt), info = "bf10_display が未定義です")
})
