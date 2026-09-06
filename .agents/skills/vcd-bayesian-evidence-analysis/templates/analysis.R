#!/usr/bin/env Rscript
# =============================================================================
# vcd-bayesian-evidence-analysis: analysis.R
# Pass 1: 4軸セル診断 (Effect x Evidence x Influence x Stability)
#         + 9候補対数線形GLM + 明示式BIC + ベイズDirichlet事後推論
# =============================================================================

suppressPackageStartupMessages({
  if (!base::requireNamespace("pacman", quietly = TRUE)) {
    utils::install.packages("pacman", repos = "https://cloud.r-project.org")
  }
  pacman::p_load(dplyr, tidyr, jsonlite, DT, htmlwidgets, htmltools, effectsize)
})

script_file_arg <- grep("^--file=", commandArgs(), value = TRUE)[1]
script_dir <- dirname(sub("^--file=", "", script_file_arg))
source(file.path(script_dir, "pass1_compute.R"))
source(file.path(script_dir, "config_validation.R"))

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

parse_args <- function(args) {
  result <- list(
    input = NULL,
    output_dir = "./skill_out/vcd_bayesian",
    run_id = NULL,
    dataset_name = "dataset",
    vars = NULL,
    freq = "Freq",
    response_var = NULL,
    top_k = 10L,
    large_n_threshold = 1000,
    base_model = "M1",
    show_help = FALSE,
    show_help_stats = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    switch(args[i],
      "--input" = {
        i <- i + 1L
        result$input <- args[i]
      },
      "--output_dir" = {
        i <- i + 1L
        result$output_dir <- args[i]
      },
      "--run-id" = {
        i <- i + 1L
        result$run_id <- args[i]
      },
      "--dataset_name" = {
        i <- i + 1L
        result$dataset_name <- args[i]
      },
      "--config" = {
        i <- i + 1L
        result$config_path <- args[i]
      },
      "--vars" = {
        i <- i + 1L
        parsed_vars <- strsplit(args[i], ",")[[1]]
        parsed_vars <- trimws(parsed_vars)
        result$vars <- parsed_vars[nzchar(parsed_vars)]
      },
      "--freq" = {
        i <- i + 1L
        result$freq <- args[i]
      },
      "--response_var" = {
        i <- i + 1L
        result$response_var <- args[i]
      },
      "--response-var" = {
        i <- i + 1L
        result$response_var <- args[i]
      },
      "--top_k" = {
        i <- i + 1L
        result$top_k <- as.integer(args[i])
      },
      "--large_n_threshold" = {
        i <- i + 1L
        result$large_n_threshold <- as.numeric(args[i])
      },
      "--base_model" = {
        i <- i + 1L
        result$base_model <- args[i]
      },
      "--help" = {
        result$show_help <- TRUE
      },
      "-h" = {
        result$show_help <- TRUE
      },
      "--help_stats" = {
        result$show_help_stats <- TRUE
      },
      {
        if (is.null(result$input) && !grepl("^--", args[i])) {
          result$input <- args[i]
        }
      }
    )
    i <- i + 1L
  }
  result
}

cfg <- parse_args(commandArgs(trailingOnly = TRUE))

if (cfg$show_help) {
  cat("\nUsage: Rscript analysis.R [OPTIONS]\n\n")
  cat("Options:\n")
  cat("  --input <file>              入力CSVファイル（省略時: HairEyeColor）\n")
  cat("  --output_dir <dir>          出力ディレクトリ（既定: ./skill_out/vcd_bayesian）\n")
  cat("  --run-id <slug>|auto        任意。指定時は <dir>/run_<slug先頭16文字>/ に隔離（auto=JST時刻）\n")
  cat("  --dataset_name <name>       データセット名（既定: dataset）\n")
  cat("  --vars <v1,v2,...>          分析変数（カンマ区切り、省略時: 全変数）\n")
  cat("  --freq <col>                度数列名（既定: Freq）\n")
  cat("  --response_var <col>        応答変数。Cramér's V算出および条件付き割合差で使用\n")
  cat("  --top_k <N>                 Top-K 表示件数（既定: 10）\n")
  cat("  --large_n_threshold <N>     大規模データモード閾値（既定: 1000）\n")
  cat("  --base_model <M1|M8>        局所診断の基準モデル（既定: M1相互独立）\n")
  cat("  --help                      このヘルプを表示\n")
  cat("  --help_stats                統計指標ガイドを表示\n\n")
  quit(save = "no", status = 0)
}

if (cfg$show_help_stats) {
  cat("\n=================================================================\n")
  cat(" 4軸セル診断体系 (Effect x Evidence x Influence x Stability) ガイド\n")
  cat("=================================================================\n")
  cat(" 1. Effect（実質的効果量: 標本数Nに不変）\n")
  cat("    - log(O/E): 期待値に対する実質的過剰(>0)・過少(<0)の対数比\n")
  cat("    - 標準化差 e_i = (y_i - mu_i) / sqrt(mu_i * N)\n")
  cat("    - Cramér's V: 分割表全体の大域的効果量（Cohen基準: >0.1小, >0.3中, >0.5大）\n\n")
  cat(" 2. Evidence（証拠強度: 標本数Nに正比例）\n")
  cat("    - Leverage補正Score統計量 T_score = r_P^2 / (1 - h_ii)（自由度1のカイ二乗値）\n")
  cat("    - 局所対数P値 ln(p): アンダーフローを防止した正確な統計的有意性\n\n")
  cat(" 3. Influence（構造影響度: 標本数Nに不変）\n")
  cat("    - Leverage h_ii: モデル適合に対するセルの梃子力（0〜1）\n\n")
  cat(" 4. Stability（数値的安定性）\n")
  cat("    - REGULAR / QUARANTINED: ゼロセル、小期待度数(<5)、過大レバレッジを隔離\n")
  cat("=================================================================\n\n")
  quit(save = "no", status = 0)
}

if (!is.null(cfg$config_path)) {
  cfg <- merge_config_file(cfg$config_path, cfg)
}

# 入力データロード
if (is.null(cfg$input)) {
  message("[INFO] --input 未指定のため HairEyeColor を使用します。")
  data("HairEyeColor", package = "datasets")
  df <- as.data.frame(HairEyeColor)
  colnames(df)[colnames(df) == "Freq"] <- "Freq"
  cat_vars <- c("Hair", "Eye", "Sex")
  freq_col <- "Freq"
} else {
  if (!file.exists(cfg$input)) {
    stop(paste("[ERROR] 入力ファイルが見つかりません:", cfg$input))
  }
  df <- read.csv(cfg$input, stringsAsFactors = FALSE, check.names = FALSE)
  message(paste("[INFO] データ読み込み完了:", nrow(df), "行,", ncol(df), "列"))
  freq_col <- cfg$freq
  freq_exists <- freq_col %in% colnames(df)
  if (!freq_exists) {
    message(paste("[INFO] 度数列", freq_col, "が存在しないため、1行=1件として集計します。"))
    all_cols <- if (!is.null(cfg$vars)) cfg$vars else colnames(df)
    df <- df %>%
      dplyr::count(across(all_of(all_cols)), name = freq_col)
    freq_exists <- TRUE
  }
  cat_vars <- if (!is.null(cfg$vars)) {
    cfg$vars
  } else {
    setdiff(colnames(df), freq_col)
  }
}

df[[freq_col]] <- as.numeric(df[[freq_col]])
df <- df[!is.na(df[[freq_col]]) & df[[freq_col]] >= 0, , drop = FALSE]
n_total <- sum(df[[freq_col]])
log_n <- log(n_total)

# 出力先隔離ディレクトリの解決
rid <- if (is.null(cfg$run_id)) {
  if (is.null(cfg$input)) resolve_run_id(builtin_df = df) else resolve_run_id(input_path = cfg$input)
} else {
  list(run_id = sanitize_run_slug(cfg$run_id), method = "manual")
}
out_root <- cfg$output_dir
artifact_dir <- run_output_dir_from_root(out_root, rid$run_id)
if (!dir.exists(artifact_dir)) {
  dir.create(artifact_dir, recursive = TRUE)
}

# run_meta.json 出力
write_run_meta(out_root, artifact_dir, "vcd-bayesian-evidence-analysis", rid$run_id, cfg$input)

message(paste("[INFO] run_id:", rid$run_id, "(", rid$method %||% "hash", ")"))
message(paste("[INFO] 出力ディレクトリ:", artifact_dir))
message(paste("[INFO] 分析変数:", paste(cat_vars, collapse = ", ")))
response_var <- cfg$response_var
if (!is.null(response_var)) {
  message(paste("[INFO] 応答変数 response_var:", response_var))
}
message(paste("[INFO] 総度数 N =", n_total, "/ log(N) =", round(log_n, 4)))

# --- [Step 1: 全体効果量 Cramér's V 算出] ---
effect_status <- "not_computed"
effect_reason <- "未算出"
effect_scope <- "none"
effect_table_dimensions <- cat_vars
cramers_v_val <- NA_real_
cramers_v_ci_low <- NA_real_
cramers_v_ci_high <- NA_real_
cv_input <- NULL

if (length(cat_vars) == 2L) {
  cv_input <- xtabs(as.formula(paste(freq_col, "~", paste(cat_vars, collapse = "+"))), data = df)
  effect_scope <- "two_way_table"
  effect_reason <- "2次元分割表からCramér's Vを算出しました。"
} else if (length(cat_vars) > 2L && !is.null(response_var)) {
  pred_vars <- setdiff(cat_vars, response_var)
  effect_df <- df
  effect_df$.pred_prof <- interaction(effect_df[pred_vars], drop = TRUE, sep = " | ")
  cv_input <- xtabs(as.formula(paste(freq_col, "~ .pred_prof +", response_var)), data = effect_df)
  effect_scope <- "predictor_profile_by_response"
  effect_reason <- paste0("3次元以上の表を response_var=", response_var, " に対し畳み込んでCramér's Vを算出しました。")
}

if (!is.null(cv_input)) {
  cv_res <- tryCatch(effectsize::cramers_v(cv_input, ci = 0.95), error = function(e) NULL)
  if (!is.null(cv_res)) {
    cramers_v_val <- as.numeric(cv_res[[1L]])
    cramers_v_ci_low <- safe_num(cv_res$CI_low)
    cramers_v_ci_high <- safe_num(cv_res$CI_high)
    effect_status <- "computed"
  } else {
    effect_status <- "failed"
    effect_reason <- "Cramér's V 算出エラー"
  }
}

large_sample_mode <- n_total > cfg$large_n_threshold
if (large_sample_mode) {
  message(paste("[INFO] 大規模データモード: N =", n_total, ">", cfg$large_n_threshold))
  message("[INFO] → 効果量を優先して解釈します (Dual-Filter)。")
}

# --- [Step 2: 対数線形モデル適合と明示式BIC算出] ---
message("[INFO] 対数線形モデル適合中...")
model_fits <- fit_all_poisson_models(df, cat_vars, freq_col)
best_m_id <- model_fits$best_model_id
message(paste("[INFO] 最良モデル (明示式BIC基準):", best_m_id, "(", model_fits$models[[best_m_id]]$name, ")"))

# --- [Step 3: 4軸セル診断体系 (Effect, Evidence, Influence, Stability)] ---
message("[INFO] 4軸セル診断を算出中...")
base_id <- if (cfg$base_model %in% names(model_fits$models)) cfg$base_model else "M1"
diag_res <- compute_4axis_cell_diagnostics(df, cat_vars, freq_col, model_fits, base_model_id = base_id)
cell_data <- diag_res$cell_table

# --- [Step 4: ベイズDirichlet事後推論・条件付き割合差] ---
message("[INFO] ベイズDirichlet事後推論中 (20,000 ドロー)...")
post_res <- compute_dirichlet_posterior(df, cat_vars, freq_col, response_var = response_var)

# --- [Step 5: 結果の構造化と JSON 出力] ---
output_results <- list(
  provenance = list(
    script = "analysis.R (vcd-bayesian-evidence-analysis 4-axis)",
    run_id = rid$run_id,
    executed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    input_file = cfg$input %||% "HairEyeColor",
    r_version = R.version.string
  ),
  input_summary = list(
    variables = cat_vars,
    response_var = response_var,
    total_n = n_total,
    n_cells = nrow(df),
    log_n = round(log_n, 4),
    large_sample_mode = large_sample_mode
  ),
  models = list(
    summary = model_fits$summary_df,
    best_model_id = best_m_id,
    base_model_id = base_id,
    criterion = "Explicit BIC based on sample size N"
  ),
  effects = list(
    primary_metric = "cramers_v",
    cramers_v = safe_round(cramers_v_val, 4),
    cramers_v_ci = c(safe_round(cramers_v_ci_low, 4), safe_round(cramers_v_ci_high, 4)),
    effect_status = effect_status,
    effect_reason = effect_reason
  ),
  cells = list(
    framework = "Effect x Evidence x Influence x Stability",
    base_model_id = diag_res$base_model_id,
    base_model_name = diag_res$base_model_name,
    regular_count = diag_res$regular_count,
    quarantined_count = diag_res$quarantined_count,
    top_k_data = head(cell_data, cfg$top_k),
    full_data = cell_data
  ),
  posterior = list(
    analytical = post_res$analytical,
    conditional_differences = post_res$conditional_differences
  ),
  # 後方互換性フィールド
  core = list(
    dimensions = cat_vars,
    n_total = n_total,
    log_n = round(log_n, 4),
    large_sample_mode = large_sample_mode,
    n_cells = nrow(df),
    top_k = cfg$top_k,
    top_k_data = head(cell_data, cfg$top_k),
    full_data = cell_data
  ),
  model_selection = list(
    method = "Explicit BIC (Total N)",
    best_model = best_m_id,
    summary = model_fits$summary_df
  )
)

json_path <- file.path(artifact_dir, "evidence_results.json")
write_json(output_results, json_path, pretty = TRUE, auto_unbox = TRUE)
message(paste("[INFO] JSON出力:", json_path))

# --- [Step 6: DTテーブル (dt_table.html) の出力] ---
dt_display <- cell_data
col_rename <- c(
  "Observed" = "度数(O)",
  "Expected" = "期待値(E)",
  "log_oe_ratio" = "効果比:log(O/E)",
  "scaled_diff" = "標準化差",
  "score_stat" = "Score統計量(T)",
  "p_value" = "P値",
  "log_p" = "対数P値",
  "leverage" = "Leverage(h)",
  "stability_status" = "診断状態"
)
for (orig in names(col_rename)) {
  if (orig %in% names(dt_display)) {
    names(dt_display)[names(dt_display) == orig] <- col_rename[[orig]]
  }
}

dt_widget <- datatable(
  dt_display,
  filter = "top",
  rownames = FALSE,
  caption = htmltools::tags$caption(
    style = "caption-side: top; text-align: left; font-size: 14px; font-weight: bold;",
    paste0(
      "4軸セル診断テーブル: ", paste(cat_vars, collapse = " × "),
      " (N = ", format(n_total, big.mark = ","), ")",
      " | 最良モデル: ", best_m_id,
      " | Cramér's V = ", safe_round(cramers_v_val, 4)
    )
  ),
  options = list(
    pageLength = 20,
    scrollX = TRUE,
    language = list(url = "https://cdn.datatables.net/plug-ins/1.13.6/i18n/ja.json")
  )
) |>
  formatStyle(
    "効果比:log(O/E)",
    backgroundColor = styleInterval(0, c("#ffebee", "#e3f2fd")),
    fontWeight = "bold"
  ) |>
  formatStyle(
    "診断状態",
    backgroundColor = styleEqual(c("REGULAR", "QUARANTINED"), c("#e8f5e9", "#fff3e0")),
    color = styleEqual(c("REGULAR", "QUARANTINED"), c("#2e7d32", "#e65100")),
    fontWeight = "bold"
  )

dt_path <- file.path(artifact_dir, "dt_table.html")
saveWidget(dt_widget, dt_path, selfcontained = TRUE, libdir = NULL)
message(paste("[INFO] DTテーブル出力:", dt_path))

# --- [Step 7: 完了サマリー出力] ---
cat("\n=================================================================\n")
cat(" vcd-bayesian-evidence-analysis: Pass 1 完了 (4軸セル診断体系)\n")
cat("=================================================================\n")
cat(paste0(" 分析変数           : ", paste(cat_vars, collapse = " × "), "\n"))
cat(paste0(" 総度数 N           : ", format(n_total, big.mark = ","), "\n"))
cat(paste0(" セル数             : ", nrow(df), "\n"))
cat(paste0(" 最良モデル (BIC)   : ", best_m_id, " (", model_fits$models[[best_m_id]]$name, ")\n"))
if (!is.na(cramers_v_val)) {
  cat(paste0(
    " Cramér's V         : ", safe_round(cramers_v_val, 4),
    " [", safe_round(cramers_v_ci_low, 4), ", ", safe_round(cramers_v_ci_high, 4), "]\n"
  ))
}
cat(paste0(" 診断基準モデル     : ", diag_res$base_model_id, " (", diag_res$base_model_name, ")\n"))
cat(paste0(" 安定セル率         : ", diag_res$regular_count, " / ", nrow(df),
           " (", round(diag_res$regular_count / nrow(df) * 100, 1), "% REGULAR)\n"))
if (large_sample_mode) {
  cat(" ** 大規模データモード: 標本数不変の Effect 軸を優先して解釈してください **\n")
}
cat("\n [出力ファイル]\n")
cat(paste0("  - ", json_path, "\n"))
cat(paste0("  - ", dt_path, "\n"))
cat("=================================================================\n")
