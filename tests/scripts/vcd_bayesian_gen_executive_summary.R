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

cfg <- parse_args()
res <- fromJSON(cfg$json, simplifyVector = TRUE)

`%||%` <- function(x, y) if (is.null(x)) y else x

dims <- res$input_summary$variables %||% res$dimensions %||% res$core$dimensions %||% character(0)
n_total <- res$input_summary$total_n %||% res$n_total %||% res$core$n_total %||% 0
best_model <- res$models$best_model_id %||% res$model_selection$best_model %||% "N/A"
cv_val <- res$effects$cramers_v %||% res$cramers_v
cv_disp <- if (!is.null(cv_val) && !is.na(cv_val)) sprintf("%.4f", as.numeric(cv_val)) else "未算出"

fd <- as.data.frame(res$cells$full_data %||% res$full_data %||% res$core$full_data)
n_cells <- nrow(fd)
regular_count <- res$cells$regular_count %||% sum(fd$stability_status == "REGULAR", na.rm = TRUE)

top5 <- head(fd, 5)

fmt_cell <- function(row) {
  parts <- sapply(dims, function(d) paste0(d, "=", row[[d]]))
  paste(parts, collapse = ", ")
}

lines <- c(
  "### エグゼクティブ・サマリー（決定論生成・4軸セル診断体系）",
  "",
  paste0("**分析次元**: ", paste(dims, collapse = " × "), " ／ **N** = ", format(n_total, big.mark = ","), " ／ **セル数** = ", n_cells),
  "",
  "#### 1. 全体的な関連性（対数線形モデル・効果量）",
  paste0("- **最良モデル (明示式BIC)**: ", best_model),
  paste0("- **全体効果量 (Cramér's V)**: ", cv_disp),
  "",
  "#### 2. 4軸セル診断体系（Effect × Evidence × Influence × Stability）",
  paste0("- **効果比**: log(O/E)（標本数不変の実質的乖離尺度）"),
  paste0("- **Evidence**: Raoの局所スコア検定統計量 T = r² / (1 - h)"),
  paste0("- **安定セル数 (REGULAR)**: ", regular_count, " / ", n_cells, "（", round(regular_count / n_cells * 100, 1), "%）"),
  "",
  "#### 3. 主要特異セル（Top 5）",
  vapply(seq_len(min(5, nrow(top5))), function(i) {
    r <- top5[i, , drop = FALSE]
    log_oe <- if ("log_oe_ratio" %in% names(r)) round(r$log_oe_ratio, 4) else NA_real_
    t_score <- if ("score_stat" %in% names(r)) round(r$score_stat, 4) else NA_real_
    lev <- if ("leverage" %in% names(r)) round(r$leverage, 4) else NA_real_
    status <- if ("stability_status" %in% names(r)) r$stability_status else "REGULAR"
    paste0("- ", i, ". ", fmt_cell(r), " — log(O/E)=", log_oe, ", T=", t_score, ", h=", lev, " [", status, "]")
  }, character(1)),
  "",
  "#### 4. 結論（機械生成）",
  paste0("大標本（N=", format(n_total, big.mark = ","), "）においても、4軸セル診断により、標本抽出誤差と実質的効果を明確に分離して評価できる。詳細はダッシュボードで確認。"),
  ""
)

writeLines(enc2utf8(lines), cfg$output, useBytes = FALSE)
message("Wrote: ", cfg$output)
