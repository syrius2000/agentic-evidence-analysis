# dirichlet_posterior.R — Multinomial Dirichlet Posterior Engine & Generated Quantities

#' 多項 Dirichlet 共役事後推論・モンテカルロサンプリング・事後生成量の算出
#'
#' @param diagnostics_result list compute_residual_diagnostics の出力
#' @param alpha numeric(1) 対称事前分布パラメータ（主事前 既定 1.0）
#' @param n_draws integer(1) サンプリング回数（既定 10,000）
#' @param analysis_signature character(1) 決定論的シード生成用ハッシュ
#' @param practical_delta numeric(1) 実務的乖離閾値（既定 NULL: 指定時のみ計算）
#' @return list
#' @export
compute_dirichlet_posterior <- function(diagnostics_result,
                                        alpha = 1.0,
                                        n_draws = 10000L,
                                        analysis_signature = "deterministic_default",
                                        practical_delta = NULL) {
  cells_raw <- diagnostics_result$cells
  n_cells <- length(cells_raw)
  N <- diagnostics_result$global$n_total
  I <- diagnostics_result$global$n_rows
  J <- diagnostics_result$global$n_cols

  # 決定論的シード生成 (analysis_signature から 32-bit 整数)
  seed_int <- abs(as.integer(paste0("0x", substr(digest::digest(analysis_signature, algo = "crc32"), 1, 7))))
  if (is.na(seed_int) || seed_int == 0L) {
    seed_int <- 20260417L
  }
  set.seed(seed_int)

  # 1. 事後パラメータ alpha* = alpha_0 + O
  obs_counts <- vapply(cells_raw, function(c) c$observed, integer(1))
  alpha_post <- alpha + obs_counts
  alpha_0_post <- sum(alpha_post)

  # 解析的平均と分散
  analytic_mean <- alpha_post / alpha_0_post
  analytic_var <- (alpha_post * (alpha_0_post - alpha_post)) / ((alpha_0_post^2) * (alpha_0_post + 1))
  analytic_sd <- sqrt(analytic_var)

  # 2. 事後モンテカルロサンプリング (Gamma 乱数からの正規化)
  gamma_draws <- matrix(0.0, nrow = n_cells, ncol = n_draws)
  for (k in seq_len(n_cells)) {
    gamma_draws[k, ] <- stats::rgamma(n_draws, shape = alpha_post[k], rate = 1)
  }
  col_sums <- colSums(gamma_draws)
  pi_draws <- sweep(gamma_draws, 2, col_sums, FUN = "/")
  rm(gamma_draws)

  # 行・列インデックスのマッピング
  row_lvls <- vapply(cells_raw, function(c) c$row_level, character(1))
  col_lvls <- vapply(cells_raw, function(c) c$col_level, character(1))
  u_rows <- unique(row_lvls)
  u_cols <- unique(col_lvls)

  # 行和 pi_i+, 列和 pi_+j のドロー
  row_sums_draws <- matrix(0.0, nrow = I, ncol = n_draws)
  for (i_idx in seq_along(u_rows)) {
    r_name <- u_rows[i_idx]
    k_matches <- which(row_lvls == r_name)
    if (length(k_matches) == 1L) {
      row_sums_draws[i_idx, ] <- pi_draws[k_matches, ]
    } else {
      row_sums_draws[i_idx, ] <- colSums(pi_draws[k_matches, , drop = FALSE])
    }
  }

  col_sums_draws <- matrix(0.0, nrow = J, ncol = n_draws)
  for (j_idx in seq_along(u_cols)) {
    c_name <- u_cols[j_idx]
    k_matches <- which(col_lvls == c_name)
    if (length(k_matches) == 1L) {
      col_sums_draws[j_idx, ] <- pi_draws[k_matches, ]
    } else {
      col_sums_draws[j_idx, ] <- colSums(pi_draws[k_matches, , drop = FALSE])
    }
  }

  # 3. セル別要約と生成量の抽出
  cell_posteriors <- vector("list", n_cells)

  for (k in seq_len(n_cells)) {
    r_name <- row_lvls[k]
    c_name <- col_lvls[k]
    i_idx <- match(r_name, u_rows)
    j_idx <- match(c_name, u_cols)

    k_pi <- pi_draws[k, ]
    k_pi_row <- row_sums_draws[i_idx, ]
    k_pi_col <- col_sums_draws[j_idx, ]

    # 条件付き確率
    cond_row <- k_pi / k_pi_row
    cond_col <- k_pi / k_pi_col

    # 独立性からの局所事後対数乖離 D = log(pi_ij / (pi_i+ * pi_+j))
    log_div <- log(k_pi) - log(k_pi_row) - log(k_pi_col)

    # クオンタイル (95% ETI)
    q_pi <- stats::quantile(k_pi, probs = c(0.025, 0.25, 0.50, 0.75, 0.975), names = FALSE)
    q_log_div <- stats::quantile(log_div, probs = c(0.025, 0.50, 0.975), names = FALSE)

    # practical delta (指定時のみ計算)
    prob_prac_delta <- if (!is.null(practical_delta) && is.numeric(practical_delta) && practical_delta > 0) {
      delta_diff <- k_pi - (k_pi_row * k_pi_col)
      round(mean(abs(delta_diff) > practical_delta), 4)
    } else {
      NULL
    }

    cell_posteriors[[k]] <- list(
      row_level = r_name,
      col_level = c_name,
      prob_analytic_mean = round(analytic_mean[k], 6),
      prob_analytic_sd = round(analytic_sd[k], 6),
      prob_mean = round(mean(k_pi), 6),
      prob_sd = round(stats::sd(k_pi), 6),
      prob_q025 = round(q_pi[1], 6),
      prob_q250 = round(q_pi[2], 6),
      prob_q500 = round(q_pi[3], 6),
      prob_q750 = round(q_pi[4], 6),
      prob_q975 = round(q_pi[5], 6),
      prob_eti_width = round(q_pi[5] - q_pi[1], 6),
      cond_row_prob_mean = round(mean(cond_row), 6),
      cond_row_prob_sd = round(stats::sd(cond_row), 6),
      cond_col_prob_mean = round(mean(cond_col), 6),
      cond_col_prob_sd = round(stats::sd(cond_col), 6),
      log_divergence_mean = round(mean(log_div), 4),
      log_divergence_q025 = round(q_log_div[1], 4),
      log_divergence_median = round(q_log_div[2], 4),
      log_divergence_q975 = round(q_log_div[3], 4),
      log_divergence_eti_width = round(q_log_div[3] - q_log_div[1], 4),
      prob_dir_positive = round(mean(log_div > 0), 4),
      prob_practical_delta = prob_prac_delta
    )
  }

  rm(pi_draws, row_sums_draws, col_sums_draws)

  # 4. 事前感度分析 (alpha = 0.5 Jeffreys型事前分布との比較)
  alpha_sens <- 0.5
  alpha_sens_post <- alpha_sens + obs_counts
  gamma_sens <- matrix(0.0, nrow = n_cells, ncol = n_draws)
  for (k in seq_len(n_cells)) {
    gamma_sens[k, ] <- stats::rgamma(n_draws, shape = alpha_sens_post[k], rate = 1)
  }
  col_sums_sens <- colSums(gamma_sens)
  pi_sens_draws <- sweep(gamma_sens, 2, col_sums_sens, FUN = "/")
  rm(gamma_sens)

  sens_cell_summaries <- vector("list", n_cells)
  max_median_shift <- 0.0
  max_width_diff <- 0.0

  for (k in seq_len(n_cells)) {
    k_pi_sens <- pi_sens_draws[k, ]
    q_sens <- stats::quantile(k_pi_sens, probs = c(0.025, 0.50, 0.975), names = FALSE)
    primary_med <- cell_posteriors[[k]]$prob_q500
    primary_width <- cell_posteriors[[k]]$prob_eti_width

    med_shift <- abs(q_sens[2] - primary_med)
    width_diff <- abs((q_sens[3] - q_sens[1]) - primary_width)

    if (med_shift > max_median_shift) max_median_shift <- med_shift
    if (width_diff > max_width_diff) max_width_diff <- width_diff

    sens_cell_summaries[[k]] <- list(
      row_level = row_lvls[k],
      col_level = col_lvls[k],
      prob_sens_q025 = round(q_sens[1], 6),
      prob_sens_median = round(q_sens[2], 6),
      prob_sens_q975 = round(q_sens[3], 6),
      prob_sens_eti_width = round(q_sens[3] - q_sens[1], 6),
      median_shift = round(med_shift, 6)
    )
  }
  rm(pi_sens_draws)

  analytic_mean_sens <- alpha_sens_post / sum(alpha_sens_post)
  max_prior_diff <- max(abs(analytic_mean - analytic_mean_sens))

  sensitivity_summary <- list(
    primary_alpha = alpha,
    sensitivity_alpha = alpha_sens,
    max_absolute_mean_diff = round(max_prior_diff, 6),
    max_median_shift = round(max_median_shift, 6),
    max_eti_width_diff = round(max_width_diff, 6),
    is_sensitive = (max_prior_diff >= 0.05 || max_median_shift >= 0.05),
    cell_comparisons = sens_cell_summaries
  )

  return(list(
    prior_specification = list(alpha = alpha),
    n_draws = n_draws,
    deterministic_seed = seed_int,
    practical_delta = practical_delta,
    cell_posteriors = cell_posteriors,
    sensitivity_analysis = sensitivity_summary
  ))
}
