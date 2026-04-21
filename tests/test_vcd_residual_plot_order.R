#!/usr/bin/env Rscript
# tests/test_vcd_residual_plot_order.R
# ggplot2 残差プロットが factor level 順（abs_res ソートでない）であることを検証
# Run: Rscript tests/test_vcd_residual_plot_order.R

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}

# 対象テンプレート: vcd と questionnaire 両方
paths <- c(
  file.path(repo, ".cursor/skills/vcd-categorical-analysis/templates/report.Rmd"),
  file.path(repo, ".agent/skills/vcd-categorical-analysis/templates/report.Rmd"),
  file.path(repo, ".cursor/skills/questionnaire-batch-analysis/templates/report.Rmd"),
  file.path(repo, ".agent/skills/questionnaire-batch-analysis/templates/report.Rmd")
)

pass <- 0L
fail <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    cat("[PASS]", label, "\n")
    pass <<- pass + 1L
  } else {
    cat("[FAIL]", label, "\n")
    fail <<- fail + 1L
  }
}

for (p in paths) {
  if (!file.exists(p)) next
  lines <- readLines(p, warn = FALSE)
  tag <- basename(dirname(dirname(dirname(p))))

  # residual-plot チャンクを抽出
  chunk_start <- grep("^```\\{r residual-plot[,}]", lines)
  if (length(chunk_start) == 0L) {
    # questionnaire の場合は plots チャンクに実装がある
    chunk_start <- grep("^```\\{r plots[,}]", lines)
  }
  if (length(chunk_start) == 0L) next

  chunk_end <- grep("^```$", lines)
  chunk_end <- chunk_end[chunk_end > chunk_start[1L]][1L]
  chunk <- paste(lines[(chunk_start[1L] + 1L):(chunk_end - 1L)], collapse = "\n")

  # セル順序が factor level 順であること:
  # plot_df は abs_res 降順ソートではなく、seq_along による元順序を使うべき
  # 「reorder(cell_label_wrap, seq_len(nrow(」のようなソートベースの x 軸は NG
  # 代わりに factor() で level 順を保持するコードがあるべき

  # NG パターン: reorder(..., seq_len(...)) — ソート済みdfの行順に再配置
  has_reorder_seqlen <- grepl("reorder\\(.*seq_len", chunk)

  check(
    paste("no reorder(seq_len) in residual plot:", tag),
    !has_reorder_seqlen
  )

  # OK パターン: factor() で level 順を保持、または cell_label を factor として設定
  has_factor_levels <- grepl("factor\\(", chunk) || grepl("levels\\s*=", chunk)

  check(
    paste("factor levels preserved in residual plot:", tag),
    has_factor_levels
  )
}

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) stop("Some residual plot order tests failed.")
message("OK: residual plot order tests passed.")
