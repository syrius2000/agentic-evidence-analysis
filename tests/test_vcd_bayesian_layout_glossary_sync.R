# vcd-dashboard-layout-fix: 用語解説 Markdown / agent–cursor ミラー同期

suppressPackageStartupMessages({
  library(testthat)
})

root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && basename(root) == "tests") {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
agent_dash <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
cursor_dash <- file.path(root, ".cursor/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
agent_r <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
cursor_r <- file.path(root, ".cursor/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
agent_rd <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R")
cursor_rd <- file.path(root, ".cursor/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R")
agent_skill <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/SKILL.md")
cursor_skill <- file.path(root, ".cursor/skills/vcd-bayesian-evidence-analysis/SKILL.md")

test_that("glossary ブロック引用の継続行が > で始まる（欠落すると赤）", {
  skip_if_not(file.exists(agent_dash))
  lines <- readLines(agent_dash, encoding = "UTF-8", warn = FALSE)
  expect_false(any(grepl("^  \"\\*\\*独立 Poisson", lines)),
    info = "ブロック引用の継続行に > が無い形式が残っています"
  )
  expect_true(any(grepl("^  \"> \\*\\*独立 Poisson", lines)),
    info = "用語解説の独立 Poisson 行に blockquote 接頭辞がありません"
  )
})

test_that("用語解説断片を HTML にしても h1 が出ず blockquote が成立する", {
  skip_if_not_installed("commonmark")
  md <- paste0(
    "### BIC ペナルティの直観（抜粋）\n\n",
    "> **このレポートの推論本体**は、上段の **Evidence Score** と、\n",
    "> **独立 Poisson モデル対 飽和 Poisson モデル**に基づく **BF** です。\n\n",
    "### Evidence Score\n\n",
    "$$x = 1$$\n\n"
  )
  html <- commonmark::markdown_html(md)
  expect_false(grepl("<h1\\b", html, ignore.case = TRUE))
  expect_true(grepl("<blockquote", html))
})

test_that("agent と .cursor の templates / SKILL が一致する", {
  skip_if_not(file.exists(agent_dash) && file.exists(cursor_dash))
  skip_if_not(file.exists(agent_r) && file.exists(cursor_r))
  skip_if_not(file.exists(agent_rd) && file.exists(cursor_rd))
  skip_if_not(file.exists(agent_skill) && file.exists(cursor_skill))
  expect_identical(tools::md5sum(agent_dash)[[1L]], tools::md5sum(cursor_dash)[[1L]])
  expect_identical(tools::md5sum(agent_r)[[1L]], tools::md5sum(cursor_r)[[1L]])
  expect_identical(tools::md5sum(agent_rd)[[1L]], tools::md5sum(cursor_rd)[[1L]])
  expect_identical(tools::md5sum(agent_skill)[[1L]], tools::md5sum(cursor_skill)[[1L]])
})
