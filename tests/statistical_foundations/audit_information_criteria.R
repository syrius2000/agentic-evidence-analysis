#!/usr/bin/env Rscript
# tests/statistical_foundations/audit_information_criteria.R
# 情報量規準（BIC / stats::BIC / EBIC）とセル診断の多軸体系（Evidence, Effect, Influence, Stability）スクリプト

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

# 1. BIC と stats::BIC の監査比較
# 注記: 「RのBICが誤り」ではなく、多項標本としての固定総度数 N と、
# Poisson GLM の対数尤度計算において観測行数として参照されるセル数 K の定義が異なることによる。
audit_model_bics <- function(glm_res, total_n, n_cells, ebic_gamma = 0.5) {
  model_bic_audit <- list()
  sample_models <- names(glm_res$models)
  
  for (m_id in sample_models) {
    m <- glm_res$models[[m_id]]
    if (m$status != "REGULAR") {
      model_bic_audit[[m_id]] <- list(
        model_id = m_id,
        status = m$status,
        note = "非正則推定のため通常のBIC比較から除外"
      )
      next
    }
    
    k_pois <- m$rank       # 切片を含む階数
    k_mult <- k_pois - 1L  # 多項モデルの自由パラメータ数
    ll_pois <- m$loglik
    
    # 明示式BIC (標本サイズ N = 総度数)
    bic_n_pois <- -2 * ll_pois + k_pois * log(total_n)
    bic_n_mult <- -2 * ll_pois + k_mult * log(total_n) # 切片除く多項パラメータ基準
    
    # stats::BIC (標本サイズ nobs = セル数 K)
    # stats::BIC は内部で nobs = length(residuals) = n_cells を使用
    bic_stats <- m$bic_stats
    bic_expected_stats <- -2 * ll_pois + k_pois * log(n_cells)
    
    # EBIC の監査計算
    P_total <- n_cells - 1L
    ebic_comb_penalty <- if (P_total >= k_mult && k_mult > 0) {
      2 * ebic_gamma * lchoose(P_total, k_mult)
    } else {
      0
    }
    ebic_explicit <- bic_n_pois + ebic_comb_penalty
    
    model_bic_audit[[m_id]] <- list(
      model_id = m_id,
      model_name = m$name,
      loglik_poisson = ll_pois,
      rank_poisson = k_pois,
      free_params_mult = k_mult,
      total_n = total_n,
      n_cells = n_cells,
      # 標本サイズ N 基準のBIC
      bic_sample_size_n = bic_n_pois,
      bic_multinomial_params_n = bic_n_mult,
      # セル数 K 基準の stats::BIC
      bic_stats_r = bic_stats,
      bic_stats_discrepancy = abs(bic_stats - bic_expected_stats),
      penalty_diff_logN_vs_logK = k_pois * (log(total_n) - log(n_cells)),
      definition_note = "多項標本としての総度数NとGLMが観測数として扱うセル数Kの相違",
      # EBIC
      ebic_gamma = ebic_gamma,
      ebic_penalty = ebic_comb_penalty,
      ebic_value = ebic_explicit,
      ebic_applicable_note = "9候補の固定階層探索空間における組合せ罰則の必要性は限定的"
    )
  }
  
  model_bic_audit
}

# 2. セル診断の多軸体系（Effect, Evidence, Influence, Stability）
# HairEyeColor 文書の知見を統合:
#   - Leverage補正 Score統計量: T_i^{score} = r_{P,i}^2 / (1 - h_{ii})
#   - Exact 局所LRT: \Delta G_i^2
#   - N不変効果量: \log(O/E), d_i/\sqrt{N}, \Delta G_i^2/N
audit_cell_scores_and_local_models <- function(df, vars, freq_col, glm_res, base_model_id = "M1", k_penalty = 1.0) {
  stopifnot(base_model_id %in% names(glm_res$models))
  base_m <- glm_res$models[[base_model_id]]
  
  df_sorted <- df %>% arrange(across(all_of(vars)))
  n_rows <- nrow(df_sorted)
  y <- df_sorted[[freq_col]]
  total_n <- sum(y)
  
  mu_0 <- base_m$fitted_values
  ll_0 <- base_m$loglik
  dev_0 <- base_m$deviance
  rank_0 <- base_m$rank
  leverage_0 <- if (!is.null(base_m$leverage)) base_m$leverage else rep(0, n_rows)
  
  # 基本式
  fmla_base <- build_formula(base_model_id, vars, freq_col)
  
  cell_audits <- list()
  
  for (i in seq_len(n_rows)) {
    obs_i <- y[i]
    exp_i <- mu_0[i]
    h_ii <- leverage_0[i]
    
    # --- [1. 残差と記述指標] ---
    obs_exp_ratio <- if (exp_i > 0) obs_i / exp_i else NA_real_
    log_oe_ratio <- if (obs_i > 0 && exp_i > 0) log(obs_i / exp_i) else if (obs_i == 0 && exp_i > 0) log(0.5 / exp_i) else NA_real_
    pearson_res <- if (exp_i > 0) (obs_i - exp_i) / sqrt(exp_i) else NA_real_
    dev_contrib <- if (obs_i == 0) 2 * exp_i else 2 * (obs_i * log(max(obs_i, 1e-12) / max(exp_i, 1e-12)) - (obs_i - exp_i))
    deviance_res <- sign(obs_i - exp_i) * sqrt(max(dev_contrib, 0))
    
    # --- [2. N不変効果量 (Effect)] ---
    rate_diff <- (obs_i - exp_i) / total_n
    normalized_dev_res <- deviance_res / sqrt(total_n) # e_i = d_i / sqrt(N)
    dev_contrib_per_n <- (deviance_res^2) / total_n     # d_i^2 / N
    
    # --- [3. Leverage補正 Score統計量 (Efficient Score Test)] ---
    # T_i^{score} = r_{P,i}^2 / (1 - h_{ii})
    h_denom <- max(1 - h_ii, 1e-6)
    score_stat <- if (!is.na(pearson_res)) (pearson_res^2) / h_denom else NA_real_
    score_p_val <- if (!is.na(score_stat)) pchisq(score_stat, df = 1, lower.tail = FALSE) else NA_real_
    
    # --- [4. 旧Scoreの再現値] ---
    legacy_score <- if (!is.na(pearson_res)) {
      (pearson_res^2) - k_penalty * log(total_n)
    } else {
      NA_real_
    }
    
    # --- [5. 局所ダミー再適合 (Exact Local LRT)] ---
    df_with_dummy <- df_sorted
    df_with_dummy$dummy_cell <- as.numeric(seq_len(n_rows) == i)
    
    rhs_base <- strsplit(deparse(fmla_base), "~")[[1L]][2L]
    fmla_dummy <- as.formula(sprintf("%s ~ %s + dummy_cell", freq_col, rhs_base))
    
    dummy_fit <- tryCatch({
      glm(fmla_dummy, data = df_with_dummy, family = poisson(), x = TRUE)
    }, error = function(e) NULL)
    
    if (is.null(dummy_fit) || !isTRUE(dummy_fit$converged)) {
      cell_audits[[i]] <- list(
        cell_index = i,
        cell_vars = as.list(df_sorted[i, vars, drop = FALSE]),
        observed = obs_i,
        expected_base = exp_i,
        # 4軸構造
        effect = list(
          obs_expected_ratio = obs_exp_ratio,
          log_oe_ratio = log_oe_ratio,
          rate_difference = rate_diff,
          normalized_dev_residual = normalized_dev_res,
          dev_contrib_per_n = dev_contrib_per_n,
          delta_g2_per_n = NA_real_
        ),
        evidence = list(
          pearson_residual = pearson_res,
          deviance_residual = deviance_res,
          score_statistic = score_stat,
          score_p_value = score_p_val,
          delta_deviance_exact = NA_real_,
          delta_deviance_p_value = NA_real_,
          delta_deviance_log_p = NA_real_,
          local_delta_bic = NA_real_,
          legacy_score = legacy_score
        ),
        influence = list(
          leverage = h_ii
        ),
        stability = list(
          quarantined = TRUE,
          status = "FAILED_OR_NON_CONVERGED",
          reason = "ダミーモデルの適合失敗または収束不良"
        )
      )
      next
    }
    
    rank_dummy <- qr(model.matrix(dummy_fit))$rank
    delta_rank <- rank_dummy - rank_0
    
    # デザイン行列に列従属（ランクが増加しない）場合
    if (delta_rank < 1L) {
      cell_audits[[i]] <- list(
        cell_index = i,
        cell_vars = as.list(df_sorted[i, vars, drop = FALSE]),
        observed = obs_i,
        expected_base = exp_i,
        effect = list(
          obs_expected_ratio = obs_exp_ratio,
          log_oe_ratio = log_oe_ratio,
          rate_difference = rate_diff,
          normalized_dev_residual = normalized_dev_res,
          dev_contrib_per_n = dev_contrib_per_n,
          delta_g2_per_n = 0
        ),
        evidence = list(
          pearson_residual = pearson_res,
          deviance_residual = deviance_res,
          score_statistic = score_stat,
          score_p_value = score_p_val,
          delta_deviance_exact = 0,
          delta_deviance_p_value = NA_real_,
          delta_deviance_log_p = NA_real_,
          local_delta_bic = -k_penalty * log(total_n),
          legacy_score = legacy_score
        ),
        influence = list(
          leverage = h_ii
        ),
        stability = list(
          quarantined = TRUE,
          status = "RANK_DEFICIENT_COLLINEAR",
          reason = "セルダミーが基準モデルの列空間に従属（自由度0）"
        )
      )
      next
    }
    
    dev_dummy <- dummy_fit$deviance
    delta_dev <- dev_0 - dev_dummy
    delta_g2_per_n <- delta_dev / total_n
    
    # 局所LRTの漸近P値
    lrt_p_val <- pchisq(delta_dev, df = 1, lower.tail = FALSE)
    lrt_log_p <- pchisq(delta_dev, df = 1, lower.tail = FALSE, log.p = TRUE)
    
    # 局所明示BIC差: \Delta G_i^2 - 1 * log(N)
    local_bic_score <- delta_dev - k_penalty * log(total_n)
    
    # 残差二乗 vs Score検定 vs LRT の誤差監査
    diff_r2_lrt <- if (!is.na(pearson_res)) abs((pearson_res^2) - delta_dev) else NA_real_
    diff_score_lrt <- if (!is.na(score_stat)) abs(score_stat - delta_dev) else NA_real_
    
    cell_audits[[i]] <- list(
      cell_index = i,
      cell_vars = as.list(df_sorted[i, vars, drop = FALSE]),
      observed = obs_i,
      expected_base = exp_i,
      # 4軸構造
      effect = list(
        obs_expected_ratio = obs_exp_ratio,
        log_oe_ratio = log_oe_ratio,
        rate_difference = rate_diff,
        normalized_dev_residual = normalized_dev_res,
        dev_contrib_per_n = dev_contrib_per_n,
        delta_g2_per_n = delta_g2_per_n
      ),
      evidence = list(
        pearson_residual = pearson_res,
        deviance_residual = deviance_res,
        score_statistic = score_stat,
        score_p_value = score_p_val,
        delta_deviance_exact = delta_dev,
        delta_deviance_p_value = lrt_p_val,
        delta_deviance_log_p = lrt_log_p,
        local_delta_bic = local_bic_score,
        legacy_score = legacy_score,
        diff_r2_vs_exact_lrt = diff_r2_lrt,
        diff_score_vs_exact_lrt = diff_score_lrt
      ),
      influence = list(
        leverage = h_ii
      ),
      stability = list(
        quarantined = FALSE,
        status = "REGULAR",
        reason = NULL
      )
    )
  }
  
  list(
    base_model_id = base_model_id,
    base_model_name = base_m$name,
    k_penalty = k_penalty,
    total_cells = n_rows,
    framework = "Evidence x Effect x Influence x Stability",
    cell_audits = cell_audits
  )
}
