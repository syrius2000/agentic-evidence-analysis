#!/usr/bin/env Rscript
# =============================================================================
# vcd-bayesian-evidence-analysis: analysis.R
# 【正本解析スクリプト】
# Pass 1: 4軸セル診断 (Effect x Evidence x Influence x Stability)
#         + 9候補対数線形GLM + 明示式BIC + 多重基準セル診断 + 汎用Dirichlet事後推論
#
# ※ 既存の templates/three_way/ は過去互換性維持のための非正本経路です。
#    新規開発・正本実行・回帰検証はすべて本スクリプト（Antigravity主系）を唯一の正本とします。
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
    large_n_threshold = 2000,
    base_model = "M1",
    base_models = NULL,
    supersedes_run = NULL,
    supersede_reason = NULL,
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
      "--output-dir" = {
        i <- i + 1L
        result$output_dir <- args[i]
      },
      "--run-id" = {
        i <- i + 1L
        result$run_id <- args[i]
      },
      "--supersedes-run" = {
        i <- i + 1L
        result$supersedes_run <- args[i]
      },
      "--supersede-reason" = {
        i <- i + 1L
        result$supersede_reason <- args[i]
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
  cat("  --config <path>             Pass 0で確定したanalysis_config.json（必須）\n")
  cat("  --input <file>              設定作成時のみ使用。Pass 1では--configの値を使用\n")
  cat("  --output_dir <dir>          出力ディレクトリ（既定: ./skill_out/vcd_bayesian）\n")
  cat("  --run-id <slug>|auto        任意。指定時は <dir>/run_<slug先頭16文字>/ に隔離（auto=JST時刻）\n")
  cat("  --dataset_name <name>       データセット名（既定: dataset）\n")
  cat("  --vars <v1,v2,...>          分析変数（カンマ区切り、省略時: 全変数）\n")
  cat("  --freq <col>                度数列名（既定: Freq）\n")
  cat("  --response_var <col>        応答変数。Cramér's V算出および条件付き割合差で使用\n")
  cat("  --top_k <N>                 Top-K 表示件数（既定: 10）\n")
  cat("  --large_n_threshold <N>     大規模データモード閾値（既定: 2000）\n")
  cat("  --base_model <M1..M9>       局所診断の単一基準モデル指定（後方互換）\n")
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

if (is.null(cfg$config_path) || !nzchar(trimws(cfg$config_path))) {
  stop("[ERROR] Pass 1 には --config <Pass 0で確定したanalysis_config.json> が必要です。", call. = FALSE)
}
if (!file.exists(cfg$config_path)) {
  stop("[ERROR] 設定ファイルが見つかりません: ", cfg$config_path, call. = FALSE)
}

raw_config <- jsonlite::fromJSON(cfg$config_path, simplifyVector = TRUE)
repo_root <- find_agent_repo()
val_res <- validate_analysis_config(raw_config, config_path = cfg$config_path, repo_root = repo_root)
if (!is.null(val_res$input)) {
  raw_config$input <- val_res$input
}
for (key in names(raw_config)) {
  cfg[[key]] <- raw_config[[key]]
}

# 入力データロード
if (is.null(cfg$input)) {
  stop("[ERROR] input CSV の指定が必要です。", call. = FALSE)
}
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
  df <- df %>% dplyr::count(across(all_of(all_cols)), name = freq_col)
  freq_exists <- TRUE
}
cat_vars <- if (!is.null(cfg$vars)) {
  cfg$vars
} else {
  setdiff(colnames(df), freq_col)
}

df[[freq_col]] <- as.numeric(df[[freq_col]])
df <- df[!is.na(df[[freq_col]]) & df[[freq_col]] >= 0, , drop = FALSE]
n_total <- sum(df[[freq_col]])
log_n <- log(n_total)

# 出力先隔離ディレクトリの解決
rid <- if (is.null(cfg$run_id)) {
  resolve_run_id(input_path = cfg$input)
} else {
  list(run_id = sanitize_run_slug(cfg$run_id), method = "manual")
}
out_root <- cfg$output_dir
assert_valid_out_root(out_root)
artifact_dir <- reserve_run_output_dir(out_root, "vcd-bayesian-evidence-analysis", if (is.null(cfg$run_id)) NULL else rid$run_id)

# 設定スナップショット保存
cfg_snap <- save_config_snapshot(artifact_dir, cfg$config_path, config_origin = "pass0_file", config_source_path = cfg$config_path)

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

# --- [Step 3: 多重基準セル診断 (M1および選択モデル等)] ---
target_base_ids <- if (!is.null(cfg$base_models) && length(cfg$base_models) > 0L) {
  cfg$base_models
} else if (!is.null(cfg$base_model) && nzchar(cfg$base_model)) {
  c(cfg$base_model)
} else {
  c("M1", best_m_id)
}
if (isTRUE(cfg$conditional_rank_reproducibility$enabled) && !is.null(cfg$conditional_rank_reproducibility$target_baseline_model)) {
  target_base_ids <- c(target_base_ids, cfg$conditional_rank_reproducibility$target_baseline_model)
}
target_base_ids <- unique(target_base_ids)
message(paste("[INFO] 多重基準セル診断実行中 (基準モデル:", paste(target_base_ids, collapse = ", "), ")..."))

multi_diag_res <- compute_multi_baseline_diagnostics(
  df = df,
  vars = cat_vars,
  freq_col = freq_col,
  fitted_models = model_fits,
  base_model_ids = target_base_ids,
  large_n_threshold = cfg$large_n_threshold
)

# 代表基準モデル（初期表示用: M1または最初の指定モデル）
primary_base_id <- target_base_ids[1L]
primary_diag <- multi_diag_res[[primary_base_id]]
cell_data <- primary_diag$cell_table

# --- [Step 4: 汎用条件付き割合ビュー (conditional_rate_view)] ---
message("[INFO] 条件付き割合ビュー (conditional_rate_view) を算出中...")
crv_res <- compute_conditional_rate_view(
  df = df,
  vars = cat_vars,
  freq_col = freq_col,
  crv_spec = cfg$conditional_rate_view,
  draws = 20000,
  seed = 20260906
)

# --- [Step 4b: 条件付きセル順位再現性評価 (conditional_rank_reproducibility)] ---
crr_res <- NULL
if (isTRUE(cfg$conditional_rank_reproducibility$enabled)) {
  message("[INFO] 条件付きセル順位再現性 (conditional_rank_reproducibility) を算出中...")
  target_model <- cfg$conditional_rank_reproducibility$target_baseline_model
  target_diag <- multi_diag_res[[target_model]]
  if (is.null(target_diag)) {
    stop(sprintf("[ERROR] 対象基準モデル '%s' の診断結果が見つかりません。", target_model), call. = FALSE)
  }
  crr_res <- compute_conditional_rank_reproducibility(
    df = df,
    vars = cat_vars,
    freq_col = freq_col,
    factor_levels_order = cfg$factor_levels_order,
    crr_config = cfg$conditional_rank_reproducibility,
    baseline_diagnostics = target_diag$cell_table
  )
}

# --- [Step 5: 結果の構造化と JSON 出力] ---
input_ref <- run_scope_portable_path(cfg$input, run_scope_detect_repo_root(artifact_dir) %||% RUN_SCOPE_REPO_ROOT, artifact_dir)
executed_at_env <- Sys.getenv("ANALYSIS_EXEC_TIMESTAMP", "")
if (!nzchar(executed_at_env)) {
  sde <- Sys.getenv("SOURCE_DATE_EPOCH", "")
  if (nzchar(sde)) {
    epoch_num <- suppressWarnings(as.numeric(sde))
    if (!is.na(epoch_num)) {
      executed_at_env <- format(as.POSIXct(epoch_num, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%S%z")
    }
  }
}
executed_at_final <- if (nzchar(executed_at_env)) executed_at_env else format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

output_results <- list(
  provenance = list(
    script = "analysis.R (canonical 4-axis multi-baseline)",
    run_id = rid$run_id,
    executed_at = executed_at_final,
    input_file = input_ref$path,
    input_file_path_kind = input_ref$path_kind,
    input_file_sha256 = sha256_file(cfg$input),
    r_version = R.version.string
  ),
  input_summary = list(
    variables = I(as.character(cat_vars)),
    response_var = response_var,
    total_n = n_total,
    n_cells = nrow(df),
    log_n = round(log_n, 4),
    large_sample_mode = large_sample_mode
  ),
  models = list(
    notation_version = model_fits$notation_version %||% "1.0.0",
    dimension = model_fits$dimension %||% length(cat_vars),
    factor_map = model_fits$factor_map,
    definitions = model_fits$definitions,
    summary = model_fits$summary_df,
    best_model_id = best_m_id,
    criterion = "Explicit Poisson BIC based on sample size N: -2*logL + p*log(N)"
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
    base_models = target_base_ids,
    primary_base_model = primary_base_id,
    by_base_model = lapply(multi_diag_res, function(d) {
      list(
        base_model_id = d$base_model_id,
        base_model_name = d$base_model_name,
        question_ja = d$question_ja,
        counts = d$counts,
        top_k_data = head(d$cell_table, cfg$top_k),
        full_data = d$cell_table
      )
    }),
    # 後方互換性
    base_model_id = primary_diag$base_model_id,
    base_model_name = primary_diag$base_model_name,
    regular_count = primary_diag$counts$regular_cells,
    quarantined_count = primary_diag$counts$quarantined_cells,
    top_k_data = head(cell_data, cfg$top_k),
    full_data = cell_data
  ),
  conditional_rate_view = crv_res,
  run_id = rid$run_id
)

if (!is.null(crr_res)) {
  output_results$conditional_rank_reproducibility <- crr_res
}

json_path <- file.path(artifact_dir, "evidence_results.json")
write_json(output_results, json_path, pretty = TRUE, auto_unbox = TRUE)
message(paste("[INFO] JSON出力:", json_path))

# マニフェスト出力 (results_manifest.json)
h_ev <- sha256_file(json_path)
manifest_artifacts <- list(
  list(path = "evidence_results.json", role = "primary_results", sha256 = h_ev)
)
manifest_res <- write_results_manifest(artifact_dir, "vcd-bayesian-evidence-analysis", manifest_artifacts)
message(paste("[INFO] マニフェスト出力:", manifest_res$manifest_path))

# run_meta.json (v2.0) 出力
extra_meta <- list(
  requested_run_id = cfg$run_id,
  results_manifest_sha256 = manifest_res$manifest_sha256,
  config_origin = cfg_snap$config_origin,
  config_source_path = cfg_snap$config_source_path,
  config_snapshot = cfg_snap$config_snapshot,
  config_sha256 = cfg_snap$config_sha256
)
write_run_meta(out_root, artifact_dir, "vcd-bayesian-evidence-analysis", rid$run_id, cfg$input, extra = extra_meta)

# 機械可読ハンドオーバー出力 (run_handover.json)
write_run_handover(artifact_dir, "vcd-bayesian-evidence-analysis", manifest_res$manifest_sha256, config_path = cfg_snap$config_snapshot)
message(paste("[INFO] ハンドオーバー出力:", file.path(artifact_dir, "run_handover.json")))

message("[SUCCESS] Pass 1 分析計算が完了しました。")
