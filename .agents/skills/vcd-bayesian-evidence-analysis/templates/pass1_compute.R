# =============================================================================
# vcd-bayesian-evidence-analysis: pass1_compute.R
# 新4軸統計基盤（Effect x Evidence x Influence x Stability）コア計算モジュール
# =============================================================================

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

`%||%` <- function(x, y) if (is.null(x)) y else x
safe_num <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) NA_real_ else as.numeric(x)
safe_round <- function(x, digits = 4) ifelse(is.na(x), NA_real_, round(as.numeric(x), digits))

sanitize_run_slug <- function(x) {
  if (is.null(x)) return(NULL)
  if (length(x) < 1L) stop("[ERROR] 無効な --run-id です")
  x <- as.character(x)[1]
  if (is.na(x) || !nzchar(trimws(x))) stop("[ERROR] 無効な --run-id です")
  x <- trimws(x)
  if (tolower(x) == "auto") {
    return(format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo"))
  }
  x <- gsub("[/\\\\]", "_", x)
  x <- gsub("^\\.+|\\.+$", "", x)
  if (!nzchar(x)) stop("[ERROR] 無効な --run-id です")
  x
}

# --- [1. 3元表の9候補モデル定義] ---
MODEL_SPECS_3WAY <- list(
  M1 = list(id = "M1", name = "mutual_independence", formula_str = "~ %s + %s + %s", order = 1),
  M2 = list(id = "M2", name = "assoc_AB", formula_str = "~ %s*%s + %s", order = 2),
  M3 = list(id = "M3", name = "assoc_AC", formula_str = "~ %s*%s + %s", order = 2),
  M4 = list(id = "M4", name = "assoc_BC", formula_str = "~ %s*%s + %s", order = 2),
  M5 = list(id = "M5", name = "cond_indep_BC_given_A", formula_str = "~ %s*%s + %s*%s", order = 2),
  M6 = list(id = "M6", name = "cond_indep_AC_given_B", formula_str = "~ %s*%s + %s*%s", order = 2),
  M7 = list(id = "M7", name = "cond_indep_AB_given_C", formula_str = "~ %s*%s + %s*%s", order = 2),
  M8 = list(id = "M8", name = "homogeneous_association", formula_str = "~ %s*%s + %s*%s + %s*%s", order = 2),
  M9 = list(id = "M9", name = "saturated", formula_str = "~ %s*%s*%s", order = 3)
)

build_formula_3way <- function(model_id, vars, freq_col) {
  A <- vars[1L]; B <- vars[2L]; C <- vars[3L]
  rhs <- switch(
    model_id,
    M1 = sprintf("%s + %s + %s", A, B, C),
    M2 = sprintf("%s*%s + %s", A, B, C),
    M3 = sprintf("%s*%s + %s", A, C, B),
    M4 = sprintf("%s*%s + %s", B, C, A),
    M5 = sprintf("%s*%s + %s*%s", A, B, A, C),
    M6 = sprintf("%s*%s + %s*%s", A, B, B, C),
    M7 = sprintf("%s*%s + %s*%s", A, C, B, C),
    M8 = sprintf("%s*%s + %s*%s + %s*%s", A, B, A, C, B, C),
    M9 = sprintf("%s*%s*%s", A, B, C),
    stop("未知のモデルID: ", model_id)
  )
  as.formula(sprintf("%s ~ %s", freq_col, rhs))
}

# --- [2. モデル適合と総度数N基準の明示式BIC算出] ---
fit_all_poisson_models <- function(df, vars, freq_col) {
  total_n <- sum(df[[freq_col]])
  n_vars <- length(vars)
  
  fits <- list()
  summary_table <- list()
  
  if (n_vars == 3L) {
    for (m_id in names(MODEL_SPECS_3WAY)) {
      spec <- MODEL_SPECS_3WAY[[m_id]]
      fmla <- build_formula_3way(m_id, vars, freq_col)
      
      fit <- tryCatch({
        glm(fmla, data = df, family = poisson(), x = TRUE)
      }, error = function(e) NULL)
      
      if (!is.null(fit)) {
        ll <- as.numeric(stats::logLik(fit))
        k_param <- attr(stats::logLik(fit), "df")
        dev <- fit$deviance
        df_res <- fit$df.residual
        # 総度数 N 基準の明示式 BIC (Poisson尤度ベース)
        # BIC = -2*logLik + k_param * log(N)
        # 切片を含む対数線形モデルではモデル間差は多項BICと完全一致
        bic_explicit <- -2 * ll + k_param * log(total_n)
        leverage <- tryCatch(stats::hatvalues(fit), error = function(e) rep(0, nrow(df)))
        
        fits[[m_id]] <- list(
          id = m_id,
          name = spec$name,
          formula = deparse(fmla),
          fit = fit,
          loglik = ll,
          rank = fit$rank,
          df_residual = df_res,
          deviance = dev,
          bic = bic_explicit,
          fitted_values = fitted(fit),
          residuals_pearson = residuals(fit, type = "pearson"),
          residuals_deviance = residuals(fit, type = "deviance"),
          leverage = leverage
        )
        
        summary_table[[m_id]] <- data.frame(
          model_id = m_id,
          model_name = spec$name,
          df_residual = df_res,
          deviance = round(dev, 4),
          bic = round(bic_explicit, 4),
          stringsAsFactors = FALSE
        )
      }
    }
  } else if (n_vars == 2L) {
    # 2元表: M1(相互独立) と M2(飽和)
    f_indep <- as.formula(sprintf("%s ~ %s + %s", freq_col, vars[1L], vars[2L]))
    f_satur <- as.formula(sprintf("%s ~ %s * %s", freq_col, vars[1L], vars[2L]))
    
    fit_ind <- glm(f_indep, data = df, family = poisson(), x = TRUE)
    fit_sat <- glm(f_satur, data = df, family = poisson(), x = TRUE)
    
    for (m_info in list(list(id="M1", name="mutual_independence", fit=fit_ind),
                        list(id="M2", name="saturated", fit=fit_sat))) {
      m_id <- m_info$id
      f_obj <- m_info$fit
      ll <- as.numeric(stats::logLik(f_obj))
      k_param <- attr(stats::logLik(f_obj), "df")
      dev <- f_obj$deviance
      df_res <- f_obj$df.residual
      bic_explicit <- -2 * ll + k_param * log(total_n)
      leverage <- tryCatch(stats::hatvalues(f_obj), error = function(e) rep(0, nrow(df)))
      
      fits[[m_id]] <- list(
        id = m_id,
        name = m_info$name,
        fit = f_obj,
        loglik = ll,
        rank = f_obj$rank,
        df_residual = df_res,
        deviance = dev,
        bic = bic_explicit,
        fitted_values = fitted(f_obj),
        residuals_pearson = residuals(f_obj, type = "pearson"),
        residuals_deviance = residuals(f_obj, type = "deviance"),
        leverage = leverage
      )
      summary_table[[m_id]] <- data.frame(
        model_id = m_id,
        model_name = m_info$name,
        df_residual = df_res,
        deviance = round(dev, 4),
        bic = round(bic_explicit, 4),
        stringsAsFactors = FALSE
      )
    }
  }
  
  df_summary <- dplyr::bind_rows(summary_table) %>% dplyr::arrange(bic)
  best_id <- df_summary$model_id[1L]
  
  list(models = fits, summary_df = df_summary, best_model_id = best_id)
}

# --- [3. 4軸セル診断体系 (Effect, Evidence, Influence, Stability)] ---
compute_4axis_cell_diagnostics <- function(df, vars, freq_col, fitted_models, base_model_id = "M1") {
  base_m <- fitted_models$models[[base_model_id]] %||% fitted_models$models[[1L]]
  total_n <- sum(df[[freq_col]])
  n_rows <- nrow(df)
  
  y <- df[[freq_col]]
  exp_val <- base_m$fitted_values
  res_p <- base_m$residuals_pearson
  res_d <- base_m$residuals_deviance
  lev <- base_m$leverage
  
  # 4軸指標の算出
  # 1. Effect (標本数不変)
  obs_exp_ratio <- ifelse(exp_val > 0, y / exp_val, NA_real_)
  log_oe_ratio <- ifelse(y > 0 & exp_val > 0, log(y / exp_val),
                         ifelse(y == 0 & exp_val > 0, log(0.5 / exp_val), NA_real_))
  rate_diff <- (y - exp_val) / total_n
  scaled_diff <- ifelse(exp_val > 0, (y - exp_val) / sqrt(exp_val * total_n), NA_real_) # e_i = d_i / sqrt(N)
  
  # 2. Evidence (検定統計量・標本数比例)
  # Rao スコア検定統計量: T_i^{score} = r_{P,i}^2 / (1 - h_{ii})
  h_denom <- pmax(1 - lev, 1e-4)
  score_stat <- (res_p^2) / h_denom
  p_val <- pchisq(score_stat, df = 1, lower.tail = FALSE)
  log_p <- pchisq(score_stat, df = 1, lower.tail = FALSE, log.p = TRUE)
  
  # 3. Influence (梃子力)
  leverage <- lev
  
  # 4. Stability (数値的安定性)
  is_zero <- y == 0
  is_sparse <- exp_val < 5
  is_high_lev <- lev > 0.95
  is_quarantined <- is_zero | is_sparse | is_high_lev
  stability_status <- ifelse(is_quarantined, "QUARANTINED", "REGULAR")
  
  diag_df <- df
  diag_df$Observed <- y
  diag_df$Expected <- round(exp_val, 4)
  diag_df$Residual <- round(res_p, 4)
  diag_df$log_oe_ratio <- round(log_oe_ratio, 4)
  diag_df$scaled_diff <- round(scaled_diff, 4)
  diag_df$rate_diff <- round(rate_diff, 6)
  diag_df$score_stat <- round(score_stat, 4)
  diag_df$p_value <- signif(p_val, 4)
  diag_df$log_p <- round(log_p, 2)
  diag_df$leverage <- round(leverage, 4)
  diag_df$stability_status <- stability_status
  
  # 優先度順ソート（局所効果比の絶対値降順、またはScore降順）
  diag_df <- diag_df %>% dplyr::arrange(dplyr::desc(abs(log_oe_ratio)))
  
  list(
    base_model_id = base_m$id,
    base_model_name = base_m$name,
    cell_table = diag_df,
    regular_count = sum(stability_status == "REGULAR"),
    quarantined_count = sum(stability_status == "QUARANTINED")
  )
}

# --- [4. ベイズDirichlet事後推論と条件付き割合差] ---
compute_dirichlet_posterior <- function(df, vars, freq_col, response_var = NULL, draws = 20000, seed = 20260906) {
  set.seed(seed)
  y <- df[[freq_col]]
  K <- length(y)
  total_n <- sum(y)
  
  # 一様事前分布 a_0 = 1.0 (各セル α_i = y_i + 1)
  alpha_post <- y + 1.0
  alpha_0 <- sum(alpha_post)
  
  # 解析的事後平均・周辺95%信用区間 (Beta周辺分布)
  post_mean <- alpha_post / alpha_0
  ci_lower <- qbeta(0.025, alpha_post, alpha_0 - alpha_post)
  ci_upper <- qbeta(0.975, alpha_post, alpha_0 - alpha_post)
  
  # モンテカルロサンプリング (Gamma分布から生成)
  gamma_draws <- matrix(rgamma(K * draws, shape = rep(alpha_post, each = draws), rate = 1),
                        nrow = draws, ncol = K)
  sum_gamma <- rowSums(gamma_draws)
  pi_draws <- gamma_draws / sum_gamma # [draws x K]
  
  conditional_diffs <- list()
  
  # 応答変数がある場合、条件付き確率と層間差を計算
  if (!is.null(response_var) && response_var %in% vars && length(vars) >= 2L) {
    strata_vars <- setdiff(vars, response_var)
    resp_levels <- levels(factor(df[[response_var]]))
    target_level <- resp_levels[length(resp_levels)] # 通常 "Yes" または最後の水準
    
    # 層の定義
    strata_factor <- interaction(df[strata_vars], drop = TRUE, sep = ".")
    unique_strata <- levels(strata_factor)
    
    strata_rates <- list()
    for (st in unique_strata) {
      idx_denom <- which(strata_factor == st)
      idx_num <- which(strata_factor == st & df[[response_var]] == target_level)
      if (length(idx_denom) > 0 && length(idx_num) > 0) {
        # 各ドローでの条件付き割合: sum(pi_num) / sum(pi_denom)
        if (length(idx_denom) == 1L) {
          denom_draws <- pi_draws[, idx_denom]
        } else {
          denom_draws <- rowSums(pi_draws[, idx_denom, drop = FALSE])
        }
        if (length(idx_num) == 1L) {
          num_draws <- pi_draws[, idx_num]
        } else {
          num_draws <- rowSums(pi_draws[, idx_num, drop = FALSE])
        }
        cond_draws <- num_draws / pmax(denom_draws, 1e-12)
        strata_rates[[st]] <- cond_draws
      }
    }
    
    # 代表的な層間ペア差を算出
    strata_names <- names(strata_rates)
    if (length(strata_names) >= 2L) {
      for (i in 1:(length(strata_names) - 1L)) {
        for (j in (i + 1L):length(strata_names)) {
          s1 <- strata_names[i]
          s2 <- strata_names[j]
          diff_draws <- strata_rates[[s1]] - strata_rates[[s2]]
          pair_key <- paste0(s1, "_vs_", s2)
          conditional_diffs[[pair_key]] <- list(
            stratum_1 = s1,
            stratum_2 = s2,
            target_response = target_level,
            difference_mean = safe_round(mean(diff_draws), 4),
            ci_95 = safe_round(quantile(diff_draws, probs = c(0.025, 0.975)), 4),
            prob_positive = safe_round(mean(diff_draws > 0), 4)
          )
        }
      }
    }
  }
  
  list(
    analytical = list(
      posterior_mean = round(post_mean, 6),
      ci_95_lower = round(ci_lower, 6),
      ci_95_upper = round(ci_upper, 6)
    ),
    conditional_differences = conditional_diffs
  )
}
