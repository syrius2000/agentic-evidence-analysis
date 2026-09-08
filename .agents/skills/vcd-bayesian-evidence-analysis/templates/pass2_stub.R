#!/usr/bin/env Rscript
# pass2_stub.R - LLM未使用でexecutive_summary.mdの骨子（スタブ）を生成する
suppressPackageStartupMessages(library(jsonlite))

args <- commandArgs(trailingOnly = TRUE)
json_path <- "evidence_results.json"
out_path <- NULL
run_dir <- NULL

i <- 1
while (i <= length(args)) {
  if (args[i] == "--json" && i < length(args)) {
    json_path <- args[i + 1]
    i <- i + 2
  } else if (args[i] == "--output" && i < length(args)) {
    out_path <- args[i + 1]
    i <- i + 2
  } else if (args[i] == "--run-dir" && i < length(args)) {
    run_dir <- args[i + 1]
    i <- i + 2
  } else {
    i <- i + 1
  }
}

if (!is.null(run_dir) && !file.exists(json_path)) {
  json_path <- file.path(run_dir, "evidence_results.json")
}

if (!file.exists(json_path)) {
  stop("Error: JSON file not found: ", json_path, " (Pass1 の run_output_dir か --run-dir を確認してください)")
}

if (is.null(out_path) || !nzchar(out_path)) {
  out_path <- file.path(dirname(normalizePath(json_path, winslash = "/", mustWork = TRUE)), "executive_summary.md")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

res <- jsonlite::fromJSON(json_path)
dims <- res$input_summary$variables %||% res$dimensions %||% res$core$dimensions %||% character(0)
total_n <- res$input_summary$total_n %||% res$n_total %||% res$core$n_total
ds_name <- res$provenance$input_file %||% res$dataset_name %||% "Unknown"

md_lines <- c(
  "### エグゼクティブ・サマリー（スタブ生成：LLM未使用）",
  "",
  "> **注意**: 本レポートはCIまたはローカルテスト用のスタブ（プレースホルダー）です。LLMによる考察は含まれていません。",
  "",
  "#### 1. データ概要",
  sprintf("- **データセット名**: %s", ds_name),
  sprintf("- **分析次元**: %s", if (length(dims) > 0) paste(dims, collapse = " × ") else "未設定"),
  sprintf("- **総度数 (N)**: %s", if (!is.null(total_n)) format(total_n, big.mark = ",") else "N/A"),
  ""
)

# 最良モデル
best_model <- res$models$best_model_id %||% res$model_selection$best_model
definitions <- res$models$definitions
best_def <- if (!is.null(definitions) && !is.null(best_model) && best_model %in% names(definitions)) {
  definitions[[best_model]]
} else {
  NULL
}

if (!is.null(best_model)) {
  model_lines <- c(
    "#### 2. 最良モデル（対数線形・明示式BIC）",
    sprintf("- **最良モデルID**: %s", best_model)
  )
  if (!is.null(best_def)) {
    model_lines <- c(
      model_lines,
      sprintf("- **生成クラス（ブラケット記法）**: `%s`", best_def$bracket_notation %||% "N/A"),
      if (!is.null(best_def$bracket_expanded)) sprintf("- **実変数展開**: `%s`", best_def$bracket_expanded) else NULL,
      sprintf("- **構造仮定**: %s", best_def$independence$description_ja %||% "N/A"),
      if (!is.null(best_def$fitted_formula)) sprintf("- **適合式 (R)**: `%s`", best_def$fitted_formula) else NULL
    )
  }
  model_lines <- c(
    model_lines,
    "- **解釈上の重要注意（相対採択の原則）**: 本モデルの採択は候補モデル群における明示式BICに基づく相対的優位性を支持するものであり、モデルの絶対的適合や差別の不存在を証明するものではありません。",
    ""
  )
  md_lines <- c(md_lines, model_lines)
}

cv_val <- res$effects$cramers_v %||% res$cramers_v
if (!is.null(cv_val)) {
  effect_status <- res$effects$effect_status %||% res$effect_status %||% "computed"
  effect_reason <- res$effects$effect_reason %||% res$effect_reason %||% ""
  if (!is.na(cv_val)) {
    cram_str <- sprintf("- **Cramér's V（全体効果量）**: %.4f", as.numeric(cv_val))
    ci <- res$effects$cramers_v_ci %||% c(res$cramers_v_ci_low, res$cramers_v_ci_high)
    if (!is.null(ci) && length(ci) == 2L && !is.na(ci[1])) {
      cram_str <- paste0(cram_str, sprintf(" (95%% CI: %.4f - %.4f)", as.numeric(ci[1]), as.numeric(ci[2])))
    }
  } else {
    cram_str <- sprintf("- **Cramér's V（全体効果量）**: 未算出（%s: %s）", effect_status, effect_reason)
  }
  md_lines <- c(md_lines,
    "#### 3. 効果量 (Dual-Filter)",
    cram_str,
    "- **注**: Cramér's V はセル単位ではなく表全体の効果量です。セル単位の偏りは局所効果比 log(O/E) および Score統計量で確認します。",
    ""
  )
}

if (!is.null(res$warnings) && length(res$warnings) > 0) {
  md_lines <- c(md_lines,
    "**警告事項**:",
    paste("-", res$warnings),
    ""
  )
}

top_df <- res$cells$top_k_data %||% res$top_k_data
if (!is.null(top_df) && is.data.frame(top_df) && nrow(top_df) > 0) {
  md_lines <- c(md_lines,
    "#### 4. 主要な偏りセル (Top-K: 4軸診断)",
    "以下のセルが強い実質的効果量または高い検定統計量を示しました："
  )
  for (i in seq_len(nrow(top_df))) {
    row <- top_df[i, ]
    cell_desc <- if (length(dims) > 0) {
      paste(sapply(dims, function(d) paste0(d, "=", row[[d]])), collapse = ", ")
    } else {
      paste0("Cell ", i)
    }
    score_val <- if (!is.null(row$score_stat)) row$score_stat else row$Residual^2
    log_oe <- if (!is.null(row$log_oe_ratio)) row$log_oe_ratio else NA_real_
    md_lines <- c(md_lines, sprintf("- %d. %s (log(O/E): %.2f, Score統計量: %.2f, 残差: %.2f)", i, cell_desc, log_oe, score_val, row$Residual))
  }
  md_lines <- c(md_lines, "")
}

writeLines(enc2utf8(md_lines), out_path, useBytes = FALSE)
cat(sprintf("Stub summary written to %s\n", out_path))
