#!/usr/bin/env Rscript
# tests/statistical_foundations/calibrate_bayesian.R
# Dirichlet多項モデルによる事後推定・モンテカルロ校正・条件付き割合差・事後予測・厳密BF計算スクリプト

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

# 1. 解析的Dirichlet事後推定（平均・分散・周辺Beta 95%等裾区間）
compute_analytical_dirichlet_posterior <- function(y, total_alpha = 1.0) {
  K <- length(y)
  N <- sum(y)
  alpha_prior <- rep(total_alpha / K, K)
  alpha_post <- y + alpha_prior
  A_post <- N + total_alpha
  
  mean_post <- alpha_post / A_post
  var_post <- (alpha_post * (A_post - alpha_post)) / ((A_post^2) * (A_post + 1))
  sd_post <- sqrt(var_post)
  
  # 周辺Beta等裾区間 (2.5% - 97.5%)
  ci_lower <- qbeta(0.025, alpha_post, A_post - alpha_post)
  ci_upper <- qbeta(0.975, alpha_post, A_post - alpha_post)
  
  list(
    K = K,
    total_n = N,
    prior_total_alpha = total_alpha,
    prior_per_cell = total_alpha / K,
    posterior_alpha = as.numeric(alpha_post),
    posterior_total_alpha = A_post,
    mean = as.numeric(mean_post),
    sd = as.numeric(sd_post),
    ci_95_lower = as.numeric(ci_lower),
    ci_95_upper = as.numeric(ci_upper),
    ci_type = "marginal_beta_equal_tailed_95_percent",
    note = "点ごとの等裾区間であり、全セル同時の信用楕円領域ではない"
  )
}

# 2. モンテカルロ同時事後サンプリングと校正（MCSE基準および二項SE基準）
sample_and_calibrate_dirichlet <- function(y, total_alpha = 1.0, n_draws = 20000L, seed = 20260906L,
                                           tolerances = list()) {
  analytical <- compute_analytical_dirichlet_posterior(y, total_alpha)
  K <- analytical$K
  alpha_post <- analytical$posterior_alpha
  
  set.seed(seed)
  # ガンマ乱数による Dirichlet サンプリング
  # 行: ドロー (n_draws), 列: セル (K)
  gamma_draws <- matrix(rgamma(n_draws * K, shape = rep(alpha_post, each = n_draws), rate = 1),
                        nrow = n_draws, ncol = K)
  row_sums <- rowSums(gamma_draws)
  p_draws <- gamma_draws / row_sums
  
  # モンテカルロ統計量
  mc_mean <- colMeans(p_draws)
  mc_sd <- apply(p_draws, 2L, sd)
  mc_se <- mc_sd / sqrt(n_draws)
  
  # 解析区間のカバレッジ率確認
  mc_coverage <- numeric(K)
  for (k in seq_len(K)) {
    in_ci <- (p_draws[, k] >= analytical$ci_95_lower[k]) & (p_draws[, k] <= analytical$ci_95_upper[k])
    mc_coverage[k] <- mean(in_ci)
  }
  
  # 許容基準の検証（MCSE基準: 設計合意通り 3 * MCSE）
  mcse_factor <- if (!is.null(tolerances$mcse_factor)) tolerances$mcse_factor else 3.0
  mean_abs_diff <- abs(mc_mean - analytical$mean)
  mean_mcse_threshold <- mcse_factor * mc_se
  mean_calib_pass <- all(mean_abs_diff <= mean_mcse_threshold)
  
  # カバレッジ率の二項標本標準誤差基準: SE = sqrt(p*(1-p)/D)
  cov_se <- sqrt(0.95 * 0.05 / n_draws)
  cov_se_factor <- if (!is.null(tolerances$coverage_se_factor)) tolerances$coverage_se_factor else 3.0
  cov_threshold <- cov_se_factor * cov_se
  cov_calib_pass <- all(abs(mc_coverage - 0.95) <= cov_threshold)
  
  list(
    n_draws = n_draws,
    seed = seed,
    analytical = analytical,
    mc_mean = as.numeric(mc_mean),
    mc_sd = as.numeric(mc_sd),
    mc_se = as.numeric(mc_se),
    mc_coverage = as.numeric(mc_coverage),
    max_mean_abs_diff = max(mean_abs_diff),
    max_mc_se = max(mc_se),
    max_coverage_prob_diff = max(abs(mc_coverage - 0.95)),
    cov_threshold = cov_threshold,
    mean_calibration_passed = mean_calib_pass,
    coverage_calibration_passed = cov_calib_pass,
    calibration_passed = (mean_calib_pass && cov_calib_pass),
    p_draws_matrix = p_draws # 後段の条件付き割合・層間差計算用
  )
}

# 3. 条件付き割合および層間差の事後推定（同時事後標本を利用）
compute_conditional_posterior_differences <- function(df, vars, response_var, p_draws, target_response_level = NULL) {
  stopifnot(response_var %in% vars)
  stopifnot(nrow(df) == ncol(p_draws))
  
  df_sorted <- df %>% arrange(across(all_of(vars)))
  predictor_vars <- setdiff(vars, response_var)
  
  resp_levels <- sort(unique(df_sorted[[response_var]]))
  target_resp <- if (!is.null(target_response_level)) target_response_level else resp_levels[length(resp_levels)]
  
  # 層（predictor_vars の組み合わせ）ごとにセルインデックスをグループ化
  # 例: Class × Sex の各水準の行番号
  df_sorted$row_id <- seq_len(nrow(df_sorted))
  strata_split <- split(df_sorted, df_sorted[predictor_vars], drop = TRUE)
  
  strata_names <- names(strata_split)
  n_draws <- nrow(p_draws)
  
  # 各ドローにおける各層の条件付き割合: P(Y = target | Strata = s)
  cond_prob_draws <- matrix(0, nrow = n_draws, ncol = length(strata_names))
  colnames(cond_prob_draws) <- strata_names
  
  for (s_idx in seq_along(strata_names)) {
    sub_df <- strata_split[[s_idx]]
    all_rows <- sub_df$row_id
    target_rows <- sub_df$row_id[sub_df[[response_var]] == target_resp]
    
    sum_all <- rowSums(p_draws[, all_rows, drop = FALSE])
    sum_target <- rowSums(p_draws[, target_rows, drop = FALSE])
    
    cond_prob_draws[, s_idx] <- ifelse(sum_all > 0, sum_target / sum_all, 0)
  }
  
  # 各層の条件付き割合の事後要約
  strata_summary <- list()
  for (s_name in strata_names) {
    draws_s <- cond_prob_draws[, s_name]
    strata_summary[[s_name]] <- list(
      stratum = s_name,
      target_level = as.character(target_resp),
      posterior_mean = mean(draws_s),
      posterior_sd = sd(draws_s),
      ci_95_lower = as.numeric(quantile(draws_s, 0.025)),
      ci_95_upper = as.numeric(quantile(draws_s, 0.975)),
      note = "単一変量ごとの周辺95%等裾区間"
    )
  }
  
  # 主な層間差（ペア比較）の事後分布
  # 例: 最初の層 vs 他の層、または代表的な層間差
  strata_differences <- list()
  if (length(strata_names) >= 2L) {
    for (i in 1:(length(strata_names) - 1L)) {
      for (j in (i + 1L):length(strata_names)) {
        s1 <- strata_names[i]
        s2 <- strata_names[j]
        diff_draws <- cond_prob_draws[, s1] - cond_prob_draws[, s2]
        
        pair_key <- paste(s1, "minus", s2, sep = "_vs_")
        strata_differences[[pair_key]] <- list(
          stratum_1 = s1,
          stratum_2 = s2,
          difference_mean = mean(diff_draws),
          difference_sd = sd(diff_draws),
          ci_95_lower = as.numeric(quantile(diff_draws, 0.025)),
          ci_95_upper = as.numeric(quantile(diff_draws, 0.975)),
          prob_greater_than_zero = mean(diff_draws > 0),
          method = "同一の同時事後標本に基づく差の分布（相関構造を完全維持）"
        )
      }
    }
  }
  
  list(
    response_var = response_var,
    target_response_level = as.character(target_resp),
    predictor_vars = predictor_vars,
    strata_count = length(strata_names),
    strata_conditional_rates = strata_summary,
    pairwise_rate_differences = strata_differences[1:min(15L, length(strata_differences))], # 代表ペア抜粋
    method_note = "多項事後分布のDirichletサンプリングから導出された条件付き割合・層間差"
  )
}

# 4. 事後予測チェック (PPC)
posterior_predictive_check <- function(y, total_alpha = 1.0, n_draws = 20000L, seed = 20260906L) {
  N <- sum(y)
  K <- length(y)
  alpha_post <- y + (total_alpha / K)
  
  set.seed(seed)
  gamma_draws <- matrix(rgamma(n_draws * K, shape = rep(alpha_post, each = n_draws), rate = 1),
                        nrow = n_draws, ncol = K)
  p_draws <- gamma_draws / rowSums(gamma_draws)
  
  # 各ドローで多項乱数生成
  t_obs <- numeric(n_draws)
  t_rep <- numeric(n_draws)
  
  for (d in seq_len(n_draws)) {
    p_d <- p_draws[d, ]
    y_rep <- as.numeric(rmultinom(1L, size = N, prob = p_d))
    
    exp_d <- N * p_d
    # Freeman-Tukey 統計量: sum((sqrt(y) - sqrt(exp))^2)
    t_obs[d] <- sum((sqrt(y) - sqrt(exp_d))^2)
    t_rep[d] <- sum((sqrt(y_rep) - sqrt(exp_d))^2)
  }
  
  ppp_value <- mean(t_rep >= t_obs)
  
  list(
    metric = "Freeman-Tukey discrepancy",
    formula = "sum((sqrt(count) - sqrt(expected))^2)",
    n_draws = n_draws,
    mean_t_obs = mean(t_obs),
    mean_t_rep = mean(t_rep),
    posterior_predictive_p_value = ppp_value,
    interpretation = "飽和多項モデルによる事後予測再現度。これは構造対数線形モデルの適合性保証ではない"
  )
}

# 5. 厳密周辺尤度と Bayes Factor (独立 vs 飽和)
compute_exact_marginal_likelihoods_and_bf <- function(df, vars, freq_col, total_alpha = 1.0) {
  df_sorted <- df %>% arrange(across(all_of(vars)))
  y <- df_sorted[[freq_col]]
  N <- sum(y)
  K <- length(y)
  
  # 水準数
  I <- length(unique(df_sorted[[vars[1L]]]))
  J <- length(unique(df_sorted[[vars[2L]]]))
  K_dim <- length(unique(df_sorted[[vars[3L]]]))
  stopifnot(I * J * K_dim == K)
  
  # 周辺和
  arr <- array(0, dim = c(I, J, K_dim),
               dimnames = list(sort(unique(df_sorted[[vars[1L]]])),
                               sort(unique(df_sorted[[vars[2L]]])),
                               sort(unique(df_sorted[[vars[3L]]]))))
  for (r in seq_len(nrow(df_sorted))) {
    arr[as.character(df_sorted[[vars[1L]]][r]),
        as.character(df_sorted[[vars[2L]]][r]),
        as.character(df_sorted[[vars[3L]]][r])] <- y[r]
  }
  
  n_A <- apply(arr, 1L, sum)
  n_B <- apply(arr, 2L, sum)
  n_C <- apply(arr, 3L, sum)
  
  # 共通多項係数対数: log(N!) - sum(log(y!)) = lgamma(N + 1) - sum(lgamma(y + 1))
  log_mult_coef <- lgamma(N + 1) - sum(lgamma(y + 1))
  
  # 1. 飽和モデル M_sat の対数周辺尤度
  # log p(y | M_sat) = log_mult_coef + log(Gamma(a)) - K*log(Gamma(a/K)) + sum(log(Gamma(y + a/K))) - log(Gamma(N + a))
  log_marg_sat <- log_mult_coef + lgamma(total_alpha) - K * lgamma(total_alpha / K) +
    sum(lgamma(y + total_alpha / K)) - lgamma(N + total_alpha)
  
  # 2. 完全独立モデル M_ind の対数周辺尤度
  # 各周辺変数に Dirichlet(a/I), Dirichlet(a/J), Dirichlet(a/K_dim)
  log_int_A <- lgamma(total_alpha) - I * lgamma(total_alpha / I) + sum(lgamma(n_A + total_alpha / I)) - lgamma(N + total_alpha)
  log_int_B <- lgamma(total_alpha) - J * lgamma(total_alpha / J) + sum(lgamma(n_B + total_alpha / J)) - lgamma(N + total_alpha)
  log_int_C <- lgamma(total_alpha) - K_dim * lgamma(total_alpha / K_dim) + sum(lgamma(n_C + total_alpha / K_dim)) - lgamma(N + total_alpha)
  
  log_marg_ind <- log_mult_coef + log_int_A + log_int_B + log_int_C
  
  # 厳密 log BF (M_ind vs M_sat)
  log_bf_exact_ind_vs_sat <- log_marg_ind - log_marg_sat
  
  # 比較方向: M_sat vs M_ind (飽和がどれだけ支持されるか)
  log_bf_exact_sat_vs_ind <- log_marg_sat - log_marg_ind
  
  list(
    total_alpha = total_alpha,
    log_marginal_likelihood_saturated = log_marg_sat,
    log_marginal_likelihood_independent = log_marg_ind,
    log_bf_exact_ind_vs_sat = log_bf_exact_ind_vs_sat,
    log_bf_exact_sat_vs_ind = log_bf_exact_sat_vs_ind,
    bf_exact_sat_vs_ind = if (log_bf_exact_sat_vs_ind < 700) exp(log_bf_exact_sat_vs_ind) else Inf,
    comparison_note = "独立モデルと飽和モデルの明示Dirichlet事前下での厳密解析値。他7モデルの厳密BFは計算対象外（BIC近似を使用）"
  )
}
