#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(jsonlite))

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  out <- list(json = NULL, output = "executive_summary.md")
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--json" && i < length(args)) {
      i <- i + 1
      out$json <- args[i]
    } else if (args[i] == "--output" && i < length(args)) {
      i <- i + 1
      out$output <- args[i]
    }
    i <- i + 1
  }
  if (is.null(out$json)) stop("Usage: Rscript vcd_bayesian_gen_executive_summary.R --json evidence_results.json --output executive_summary.md")
  out
}

interpret_bf <- function(bf) {
  if (is.null(bf) || (length(bf) == 1 && is.na(bf))) return("（BF 解釈不能）")
  if (is.character(bf)) {
    if (identical(toupper(trimws(bf)), "INF")) return("決定的エビデンス (decisive)")
    bf <- suppressWarnings(as.numeric(bf))
  }
  if (length(bf) != 1 || is.na(bf)) return("（BF 解釈不能）")
  if (is.infinite(bf) || bf > 100) return("決定的エビデンス (decisive)")
  if (bf > 30) return("非常に強いエビデンス (very strong)")
  if (bf > 10) return("強いエビデンス (strong)")
  if (bf > 3) return("中程度のエビデンス (moderate)")
  if (bf > 1) return("弱いエビデンス (anecdotal)")
  "関連なし / 独立仮説を支持"
}

cfg <- parse_args()
res <- fromJSON(cfg$json, simplifyVector = TRUE)
dims <- res$dimensions
n_total <- res$n_total
bf_raw <- res$bf_independence
log_n <- as.numeric(res$log_n)
threshold <- as.numeric(res$threshold)

bf_num <- if (is.character(bf_raw) && toupper(trimws(bf_raw)) == "INF") {
  Inf
} else {
  suppressWarnings(as.numeric(bf_raw))
}
bf_disp <- if (is.finite(bf_num)) format(bf_num, scientific = TRUE, digits = 4) else "Inf"

fd <- as.data.frame(res$full_data)
for (col in c("Freq", "Expected", "Residual", "Evidence_Score")) {
  if (col %in% names(fd)) fd[[col]] <- as.numeric(fd[[col]])
}
n_cells <- nrow(fd)
n_pos <- sum(fd$Evidence_Score > 0, na.rm = TRUE)
pct <- round(n_pos / n_cells * 100, 1)

ord <- order(-fd$Evidence_Score)
top5 <- fd[head(ord, 5), , drop = FALSE]
neg_ord <- order(fd$Evidence_Score)
bot3 <- fd[head(neg_ord, 3), , drop = FALSE]

fmt_cell <- function(row) {
  parts <- sapply(dims, function(d) paste0(d, "=", row[[d]]))
  paste(parts, collapse = ", ")
}

th_note <- if (isTRUE(all.equal(as.numeric(threshold), as.numeric(log_n), tolerance = 1e-4))) {
  "（JSON の threshold と一致: 正本スキル想定）"
} else {
  "（JSON の threshold は log(N) と異なる実装の補助値の可能性あり）"
}

lines <- c(
  "### エグゼクティブ・サマリー（決定論生成・tests 用）",
  "",
  paste0("**分析次元**: ", paste(dims, collapse = " × "), " ／ **N** = ", format(n_total, big.mark = ","), " ／ **セル数** = ", n_cells),
  "",
  "#### 1. 全体的な関連性（ベイズファクター）",
  paste0("- **BF10** = ", bf_disp, "（", interpret_bf(bf_num), "）"),
  "",
  "#### 2. Evidence Score と閾値",
  paste0("- **Evidence Score** = r² − log(N)（r: 独立 Poisson GLM のピアソン標準化残差）"),
  paste0("- **log(N)** = ", round(log_n, 4), "（Score > 0 の境界は r² > log(N)）"),
  paste0("- **JSON threshold** = ", round(as.numeric(threshold), 4), " ", th_note),
  paste0("- **正の Score を持つセル**: ", n_pos, " / ", n_cells, "（", pct, "%）"),
  "",
  "#### 3. セル（参考: 上位5 / 下位3）",
  "**Evidence Score 上位5**",
  vapply(seq_len(min(5, nrow(top5))), function(i) {
    r <- top5[i, , drop = FALSE]
    paste0("- ", i, ". ", fmt_cell(r), " — Score=", round(r$Evidence_Score, 4), ", r=", round(r$Residual, 4))
  }, character(1)),
  "",
  "**Evidence Score 下位3（最も負）**",
  vapply(seq_len(min(3, nrow(bot3))), function(i) {
    r <- bot3[i, , drop = FALSE]
    paste0("- ", i, ". ", fmt_cell(r), " — Score=", round(r$Evidence_Score, 4), ", r=", round(r$Residual, 4))
  }, character(1)),
  "",
  "#### 4. 結論（機械生成）",
  paste0("大標本（N=", format(n_total, big.mark = ","), "）でも Evidence Score により、実質的に議論すべきセルを数値で絞り込める。詳細はテーブルで確認。"),
  ""
)

writeLines(enc2utf8(lines), cfg$output, useBytes = FALSE)
message("Wrote: ", cfg$output)
