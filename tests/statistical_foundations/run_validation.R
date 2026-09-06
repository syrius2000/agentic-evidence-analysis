#!/usr/bin/env Rscript
# tests/statistical_foundations/run_validation.R
# 3次元統計基盤検証のための単一実行エントリーポイント（Pass 0〜Pass 1〜監査〜校正の統合）

suppressPackageStartupMessages({
  library(jsonlite)
  library(readr)
  library(dplyr)
})

# スクリプトディレクトリの取得と各モジュールの読み込み
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(sub("^--file=", "", file_arg)))
  }
  return("tests/statistical_foundations")
}

script_dir <- get_script_dir()
source(file.path(script_dir, "validate_config.R"))
source(file.path(script_dir, "fit_models.R"))
source(file.path(script_dir, "reference_values.R"))
source(file.path(script_dir, "check_results.R"))
source(file.path(script_dir, "audit_information_criteria.R"))
source(file.path(script_dir, "calibrate_bayesian.R"))

compute_file_sha256 <- function(filepath) {
  if (!file.exists(filepath)) return(NA_character_)
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(file = filepath, algo = "sha256"))
  } else if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::sha256(file(filepath, "rb"))))
  } else {
    out <- system2("shasum", args = c("-a", "256", filepath), stdout = TRUE)
    return(strsplit(out, " ")[[1]][1])
  }
}

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- NULL
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (identical(arg, "--config")) {
      if (i == length(args)) stop("--config にはファイルパスの値が必要です")
      config_path <- args[[i + 1L]]
      i <- i + 2L
    } else if (grepl("^--config=", arg)) {
      config_path <- sub("^--config=", "", arg)
      i <- i + 1L
    } else {
      stop("未知の引数です: ", arg)
    }
  }
  if (is.null(config_path) || !nzchar(config_path)) {
    cat("Usage: Rscript run_validation.R --config <path_to_analysis_config.json>\n")
    quit(status = 1)
  }
  config_path
}

run_validation_pipeline <- function(config_path) {
  message("[INFO] 設定ファイルを検証中: ", config_path)
  val_res <- validate_config_file(config_path, silent = FALSE)
  
  if (val_res$status == "ERROR") {
    message("[FATAL] 設定または入力データの検証に失敗したため、実行を中断します。")
    return(list(status = "ERROR", validation = val_res))
  } else if (val_res$status == "HOLD") {
    message("[HOLD] 推論の前提条件が未解決のため、モデル適合を行わず保留します。")
    return(list(status = "HOLD", validation = val_res))
  }
  
  cfg <- fromJSON(config_path, simplifyVector = FALSE)
  
  # 出力隔離ディレクトリの決定 (run_<first16>)
  run_slug <- substr(as.character(cfg$run_id), 1L, 16L)
  if (!nzchar(run_slug)) stop("run_id が空です")
  out_root <- cfg$output_dir
  target_run_dir <- file.path(out_root, paste0("run_", run_slug))
  
  message("[INFO] 出力先ディレクトリ: ", target_run_dir)
  if (dir.exists(target_run_dir)) {
    message(sprintf("[ERROR] 出力ディレクトリが既に存在します: %s\n既存結果の上書きは禁止されています。新しい run_id を指定してください。", target_run_dir))
    return(list(status = "COLLISION_ERROR", dir = target_run_dir))
  }
  
  dir.create(target_run_dir, recursive = TRUE)
  file.copy(config_path, file.path(target_run_dir, "analysis_config.json"), overwrite = FALSE)
  
  # データ読み込みと準備
  input_path <- cfg$input
  vars <- unlist(cfg$vars)
  freq_col <- cfg$freq
  df <- read_csv(input_path, show_col_types = FALSE)
  
  # フィルタ適用（validate_config で検証済み）
  if (!is.null(cfg$filters) && length(cfg$filters) > 0) {
    for (flt in cfg$filters) {
      if (flt$op == "==") df <- df[df[[flt$column]] == flt$value, , drop = FALSE]
      else if (flt$op == "in") df <- df[df[[flt$column]] %in% unlist(flt$value), , drop = FALSE]
    }
  }
  df_sorted <- df %>% arrange(across(all_of(vars)))
  total_n <- sum(df_sorted[[freq_col]])
  n_cells <- nrow(df_sorted)
  
  tolerances <- if (!is.null(cfg$reference_tolerance)) cfg$reference_tolerance else list()
  seed <- if (!is.null(cfg$seed)) as.integer(cfg$seed) else 20260906L
  
  # 1. モデル適合 (Pass 1)
  message("  [Pipeline 1/5] 9候補の Poisson GLM 適合中...")
  glm_res <- fit_all_9_models(df_sorted, vars, freq_col, cfg$response_var)
  
  # 2. 独立参照計算 (Reference)
  message("  [Pipeline 2/5] 独立参照計算（閉形式 & loglin IPF）中...")
  ref_res <- extract_reference_values(df_sorted, vars, freq_col)
  
  # 3. 照合と入れ子比較 (Check)
  message("  [Pipeline 3/5] 主計算と参照計算の照合中...")
  chk_res <- check_model_against_reference(glm_res, ref_res, tolerances)
  
  # 4. 情報量規準・セルScore監査 (Audit: HairEyeColor知見統合)
  message("  [Pipeline 4/5] BIC / stats::BIC / EBIC およびセルScore多軸診断監査中...")
  bic_audits <- audit_model_bics(glm_res, total_n, n_cells)
  cell_audits_m1 <- audit_cell_scores_and_local_models(df_sorted, vars, freq_col, glm_res, base_model_id = "M1")
  cell_audits_m8 <- audit_cell_scores_and_local_models(df_sorted, vars, freq_col, glm_res, base_model_id = "M8")
  
  # 5. ベイズ校正計算 (Bayesian Dirichlet & Exact BF & Conditional Rates)
  message("  [Pipeline 5/5] ベイズDirichlet事後推定・モンテカルロ校正・厳密BF計算中...")
  y_counts <- df_sorted[[freq_col]]
  
  # Dirichlet事後（感度分析 a = 1.0, 0.1, 10.0）
  post_1 <- compute_analytical_dirichlet_posterior(y_counts, total_alpha = 1.0)
  post_01 <- compute_analytical_dirichlet_posterior(y_counts, total_alpha = 0.1)
  post_10 <- compute_analytical_dirichlet_posterior(y_counts, total_alpha = 10.0)
  
  # 20,000回 モンテカルロ校正（MCSE基準 & 二項SE基準）
  mc_calib <- sample_and_calibrate_dirichlet(y_counts, total_alpha = 1.0, n_draws = 20000L, seed = seed, tolerances = tolerances)
  
  # 条件付き割合・層間差の事後推定
  target_resp_var <- if (!is.null(cfg$response_var) && length(cfg$response_var) > 0 && nzchar(as.character(cfg$response_var))) {
    as.character(cfg$response_var)
  } else {
    vars[3L]
  }
  cond_diffs <- compute_conditional_posterior_differences(df_sorted, vars, target_resp_var, mc_calib$p_draws_matrix)
  
  # 事後予測チェック (PPC)
  ppc_res <- posterior_predictive_check(y_counts, total_alpha = 1.0, n_draws = 20000L, seed = seed)
  
  # 厳密周辺尤度とBF (独立 vs 飽和)
  bf_exact <- compute_exact_marginal_likelihoods_and_bf(df_sorted, vars, freq_col, total_alpha = 1.0)
  
  # 総合合否判定: 参照照合合格 && MCSE校正合格
  eval_status <- if (isTRUE(chk_res$all_reference_checks_passed) && isTRUE(mc_calib$calibration_passed)) {
    "VERIFIED"
  } else {
    "CHECK_FAILED"
  }
  
  # 統合結果オブジェクトの作成
  full_results <- list(
    provenance = list(
      script = "run_validation.R",
      run_id = cfg$run_id,
      run_slug = run_slug,
      executed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
      input_file = input_path,
      input_sha256 = compute_file_sha256(input_path),
      r_version = R.version.string,
      platform = R.version$platform
    ),
    input_summary = list(
      variables = vars,
      response_var = cfg$response_var,
      total_n = total_n,
      n_cells = n_cells,
      levels = lapply(vars, function(v) sort(unique(df_sorted[[v]]))),
      sampling = cfg$sampling
    ),
    models = lapply(glm_res$models, function(m) {
      m_id <- m$id
      b_info <- bic_audits[[m_id]]
      list(
        id = m$id,
        name = m$name,
        formula = m$formula,
        status = m$status,
        status_reasons = m$status_reasons,
        loglik = m$loglik,
        rank = m$rank,
        df_residual = m$df_residual,
        deviance = m$deviance,
        aic = m$aic,
        bic_sample_size_n = if (!is.null(b_info)) b_info$bic_sample_size_n else NA_real_,
        bic_stats_r = m$bic_stats,
        ebic_value = if (!is.null(b_info)) b_info$ebic_value else NA_real_,
        fitted_values = m$fitted_values
      )
    }),
    comparisons = chk_res$nested_comparisons,
    cells = list(
      base_m1_mutual_independence = cell_audits_m1,
      base_m8_homogeneous_association = cell_audits_m8
    ),
    posterior = list(
      dirichlet_analytical = list(
        alpha_1_0 = post_1,
        alpha_0_1 = post_01,
        alpha_10_0 = post_10
      ),
      monte_carlo_calibration = list(
        n_draws = mc_calib$n_draws,
        seed = mc_calib$seed,
        calibration_passed = mc_calib$calibration_passed,
        mean_calibration_passed = mc_calib$mean_calibration_passed,
        coverage_calibration_passed = mc_calib$coverage_calibration_passed,
        max_mean_abs_diff = mc_calib$max_mean_abs_diff,
        max_mc_se = mc_calib$max_mc_se,
        max_coverage_prob_diff = mc_calib$max_coverage_prob_diff,
        cov_threshold = mc_calib$cov_threshold,
        criterion = "MCSE 3-sigma (mean) & Binomial 3-sigma (coverage)"
      ),
      conditional_differences = cond_diffs,
      posterior_predictive_check = ppc_res,
      exact_marginal_likelihood_and_bf = bf_exact
    ),
    checks = list(
      all_reference_checks_passed = chk_res$all_reference_checks_passed,
      per_model_checks = chk_res$per_model_checks,
      regular_models_pool = chk_res$regular_models_pool,
      quarantined_models = chk_res$quarantined_models
    ),
    decisions = list(
      evaluation_status = eval_status,
      primary_model_recommendation_held = TRUE,
      recommendation_held_reason = "大標本下の微小効果有意化・EBIC根拠・局所残差Scoreと尤度比の乖離につき採否報告で判断する"
    )
  )
  
  # JSON出力
  out_json_path <- file.path(target_run_dir, "validation_results.json")
  writeLines(toJSON(full_results, auto_unbox = TRUE, pretty = TRUE, digits = 8), out_json_path)
  
  # パイプラインステータスの確定（検証失敗時はCHECK_FAILEDを返し、mainで非ゼロ終了）
  pipeline_status <- if (eval_status == "VERIFIED") "SUCCESS" else "CHECK_FAILED"
  
  if (pipeline_status == "SUCCESS") {
    message(sprintf("[SUCCESS] 統合検証結果を保存しました (VERIFIED): %s", out_json_path))
  } else {
    message(sprintf("[FAILURE] 検証基準を満たしませんでした (CHECK_FAILED): %s", out_json_path))
  }
  
  return(list(status = pipeline_status, evaluation_status = eval_status, dir = target_run_dir, results = full_results))
}

main <- function() {
  config_path <- parse_args()
  res <- run_validation_pipeline(config_path)
  
  if (res$status == "SUCCESS") {
    quit(status = 0)
  } else if (res$status == "HOLD") {
    quit(status = 2)
  } else {
    message(sprintf("[FATAL] 検証に失敗したため異常終了します (status=%s)", res$status))
    quit(status = 1)
  }
}

if (sys.nframe() == 0L) {
  main()
}
