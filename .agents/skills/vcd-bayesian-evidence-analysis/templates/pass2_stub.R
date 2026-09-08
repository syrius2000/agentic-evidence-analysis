#!/usr/bin/env Rscript
# pass2_stub.R - LLM未使用でexecutive_summary_preview.mdの骨子（スタブ）を生成する
suppressPackageStartupMessages({
  library(jsonlite)
})

# run_scope.R の読み込み
find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) {
      break
    }
    d <- parent
  }
  getwd()
}
source(file.path(find_agent_repo(), ".agents", "shared", "run_scope.R"))

args <- commandArgs(trailingOnly = TRUE)
json_path <- NULL
out_path <- NULL
run_dir <- NULL
allow_legacy <- FALSE

i <- 1L
while (i <= length(args)) {
  if (args[i] == "--json" && i < length(args)) {
    json_path <- args[i + 1L]
    i <- i + 2L
  } else if (args[i] == "--output" && i < length(args)) {
    out_path <- args[i + 1L]
    i <- i + 2L
  } else if (args[i] == "--run-dir" && i < length(args)) {
    run_dir <- args[i + 1L]
    i <- i + 2L
  } else if (args[i] == "--allow-legacy-run-meta") {
    allow_legacy <- TRUE
    i <- i + 1L
  } else {
    i <- i + 1L
  }
}

if (!is.null(run_dir) && nzchar(trimws(run_dir))) {
  norm_run_dir <- normalizePath(assert_no_symlink(trimws(run_dir)), winslash = "/", mustWork = TRUE)
  # --run-dir 指定時はカレントディレクトリのファイルを優先せず、必ず run_dir 直下を読み込む
  json_path <- file.path(norm_run_dir, "evidence_results.json")
  if (is.null(out_path) || !nzchar(out_path)) {
    out_path <- file.path(norm_run_dir, "executive_summary_preview.md")
  }
  # プレビュー上書き防止チェック
  # 公開時の共通ガードでlegacy出力先・封印・上書きを検証する。
} else {
  if (is.null(json_path)) json_path <- "evidence_results.json"
  if (is.null(out_path) || !nzchar(out_path)) {
    out_path <- file.path(dirname(normalizePath(json_path, winslash = "/", mustWork = FALSE)), "executive_summary_preview.md")
  }
}

if (!file.exists(json_path)) {
  stop("Error: JSON file not found: ", json_path, " (Pass 1 の run_output_dir または --run-dir を確認してください)")
}

# run_meta.json の検証（存在する場合）
meta_path <- if (!is.null(run_dir)) file.path(norm_run_dir, "run_meta.json") else file.path(dirname(normalizePath(json_path, winslash = "/", mustWork = TRUE)), "run_meta.json")
run_meta <- if (file.exists(meta_path)) tryCatch(jsonlite::fromJSON(meta_path, simplifyVector = FALSE), error = function(e) NULL) else NULL

if (!is.null(run_meta) && identical(run_meta$interface_version, "1.0")) {
  if (!isTRUE(allow_legacy)) {
    stop("[ERROR] legacy run (v1.0) のプレビューを生成するには --allow-legacy-run-meta が必要です: ", meta_path)
  }
  message("[WARN] --allow-legacy-run-meta により legacy run (v1.0) のプレビュー生成を継続します。")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

res <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
dims_raw <- res$input_summary$variables %||% res$dimensions %||% res$core$dimensions
dims <- if (!is.null(dims_raw)) unlist(dims_raw) else character(0)
total_n <- as.numeric(res$input_summary$total_n %||% res$n_total %||% res$core$n_total %||% 0)
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
raw_factor_map <- res$models$factor_map
factor_map <- if (!is.null(raw_factor_map)) {
  raw_factor_map
} else {
  syms <- c("A", "B", "C")[seq_along(dims)]
  map <- list()
  for (i in seq_along(dims)) {
    map[[syms[i]]] <- list(symbol = syms[i], variable = dims[i], label = dims[i])
  }
  map
}

best_def <- if (!is.null(definitions) && !is.null(best_model) && best_model %in% names(definitions)) {
  definitions[[best_model]]
} else {
  NULL
}

# 整合性判定
is_best_def_consistent <- TRUE
notation_version <- as.character(res$models$notation_version %||% "legacy")
dimension <- as.integer(res$models$dimension %||% length(dims))

if (notation_version != "legacy" && !startsWith(notation_version, "1.")) {
  is_best_def_consistent <- FALSE
}
if (!is.null(res$models$dimension) && dimension != length(dims)) {
  is_best_def_consistent <- FALSE
}
if (dimension == 2L && "C" %in% names(factor_map)) {
  is_best_def_consistent <- FALSE
}

if (!is.null(best_def) && !is.null(best_def$fitted_formula) && nzchar(trimws(best_def$fitted_formula)) && !is.null(best_def$generators)) {
  sym_to_var <- vapply(factor_map, function(x) as.character(x$variable), character(1))
  exp_terms <- character(0)
  for (gen in best_def$generators) {
    rv <- sym_to_var[unlist(gen)]
    for (m in seq_along(rv)) {
      combs <- utils::combn(rv, m, simplify = FALSE)
      for (cb in combs) exp_terms <- c(exp_terms, paste(sort(cb), collapse = ":"))
    }
  }
  exp_terms <- unique(exp_terms)
  f_obj <- tryCatch(as.formula(best_def$fitted_formula), error = function(e) NULL)
  if (is.null(f_obj)) {
    is_best_def_consistent <- FALSE
  } else {
    act_terms <- tryCatch(attr(stats::terms(f_obj), "term.labels"), error = function(e) NULL)
    if (is.null(act_terms)) {
      is_best_def_consistent <- FALSE
    } else {
      act_terms_norm <- vapply(strsplit(act_terms, ":"), function(p) paste(sort(p), collapse = ":"), character(1))
      if (!setequal(exp_terms, act_terms_norm)) {
        is_best_def_consistent <- FALSE
      }
    }
  }
}

# 最良モデル適合失敗判定
best_model_is_failed <- FALSE
if (!is.null(best_model) && !is.null(res$models$summary)) {
  m_sum <- res$models$summary
  for (m_item in m_sum) {
    if (identical(as.character(m_item$model_id), as.character(best_model))) {
      st <- as.character(m_item$status %||% "")
      err <- as.character(m_item$error_message %||% "")
      bic_v <- as.numeric(m_item$bic %||% NA_real_)
      if (identical(st, "FAILED") || nzchar(err) || is.na(bic_v) || is.infinite(bic_v)) {
        best_model_is_failed <- TRUE
      }
    }
  }
}

if (!is.null(best_model)) {
  model_lines <- c(
    "#### 2. 最良モデル（対数線形・明示式BIC）",
    sprintf("- **最良モデルID**: %s%s", best_model, if (best_model_is_failed) " (適合失敗)" else "")
  )
  if (best_model_is_failed) {
    model_lines <- c(
      model_lines,
      "- **数学的構造定義**: [適合失敗モデルのため判定保留]"
    )
  } else if (!is_best_def_consistent) {
    model_lines <- c(
      model_lines,
      "- **数学的構造定義**: [数学的定義保留: 適合式と生成クラスの不整合検知]"
    )
  } else if (!is.null(best_def)) {
    indep_text <- best_def$independence$description_ja %||% best_def$independence_ja %||% best_def$description_ja %||% best_def$independence$base_description %||% "N/A"
    model_lines <- c(
      model_lines,
      sprintf("- **生成クラス（ブラケット記法）**: `%s`", best_def$bracket_notation %||% "N/A"),
      if (!is.null(best_def$bracket_expanded)) sprintf("- **実変数展開**: `%s`", best_def$bracket_expanded) else NULL,
      sprintf("- **構造仮定**: %s", indep_text),
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
    ci <- res$effects$cramers_v_ci %||% c(res$effects$cramers_v_ci_low %||% res$cramers_v_ci_low, res$effects$cramers_v_ci_high %||% res$cramers_v_ci_high)
    if (!is.null(ci) && length(ci) == 2L && !is.na(ci[[1]])) {
      cram_str <- paste0(cram_str, sprintf(" (95%% CI: %.4f - %.4f)", as.numeric(ci[[1]]), as.numeric(ci[[2]])))
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

top_raw <- res$cells$top_k_data %||% res$top_k_data
top_df <- if (is.data.frame(top_raw)) {
  top_raw
} else if (is.list(top_raw) && length(top_raw) > 0) {
  dplyr::bind_rows(top_raw)
} else {
  data.frame()
}
if (!is.null(top_df) && nrow(top_df) > 0) {
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

if (is.null(run_dir)) stop("[ERROR] --run-dir で実runを指定してください")
preview_output <- NULL
idx <- match("--preview-output-dir", args)
if (!is.na(idx) && idx < length(args)) preview_output <- args[idx + 1L]
if (basename(out_path) != "executive_summary_preview.md") stop("[ERROR] stubの出力名はexecutive_summary_preview.md固定です")
publish_run_preview(norm_run_dir, "executive_summary_preview.md",
  function(target) writeLines(enc2utf8(md_lines), target), allow_legacy, preview_output)
