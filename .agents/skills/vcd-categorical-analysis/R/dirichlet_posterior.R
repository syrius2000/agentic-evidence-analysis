# dirichlet_posterior.R — Multinomial Dirichlet Posterior Engine & Generated Quantities

#' 多項 Dirichlet 共役事後推論・モンテカルロサンプリング・事後生成量の算出
#'
#' @param diagnostics_result list compute_residual_diagnostics の出力
#' @param alpha numeric(1) 対称事前分布パラメータ（既定 1.0）
#' @param n_draws integer(1) サンプリング回数（既定 10,000）
#' @param analysis_signature character(1) 決定論的シード生成用ハッシュ
#' @param delta numeric(1) 実務的乖離閾値（既定 0.05）
#' @return list
#' @export
compute_dirichlet_posterior <- function(diagnostics_result,
                                        alpha = 1.0,
                                        n_draws = 10000L,
                                        analysis_signature = "deterministic_default",
                                        delta = 0.05) {
  cells_raw <- diagnostics_result$cells
  n_cells <- length(cells_raw)
  N <- diagnostics_result$global$n_total
  I <- diagnostics_result$global$n_rows
  J <- diagnostics_result$global$n_cols

  # 決定論的シード生成 (analysis_signature から 32-bit 整数)
  seed_int <- abs(as.integer(paste0("0x", substr(digest::digest(analysis_signature, algo = "crc32"), 1, 7))))
  if (is.na(seed_int) || seed_int == 0) {
    seed_int <- 20260417L
  }
  set.seed(seed_int)

  # 1. 事後パラメータ alpha* = alpha_0 + O
  obs_counts <- sapply(cells_raw, function(c) c$observed)
  alpha_post <- alpha + obs_counts
  alpha_0_post <- sum(alpha_post)

  # 解析的平均と分散
  analytic_mean <- alpha_post / alpha_0_post
  analytic_var <- (alpha_post * (alpha_0_post - alpha_post)) / ((alpha_0_post^2) * (alpha_0_post + 1))
  analytic_sd <- sqrt(analytic_var)

  # 2. 事後モンテカルロサンプリング (Gamma 乱数からの正規化)
  # メモリ効率: n_cells x n_draws 行列
  gamma_draws <- matrix(0.0, nrow = n_cells, ncol = n_draws)
  for (k in seq_len(n_cells)) {
    gamma_draws[k, ] <- stats::rgamma(n_draws, shape = alpha_post[k], rate = 1)
  }
  col_sums <- colSums(gamma_draws)
  # 各ドローでの結合確率 pi_k,s
  pi_draws <- sweep(gamma_draws, 2, col_sums, FUN = "/")
  rm(gamma_draws)  # 即時破棄

  # 行・列インデックスのマッピング
  row_lvls <- sapply(cells_raw, function(c) c$row_level)
  col_lvls <- sapply(cells_raw, function(c) c$col_level)
  u_rows <- unique(row_lvls)
  u_cols <- unique(col_lvls)

  # 行和 pi_i+, 列和 pi_+j のドロー
  row_sums_draws <- matrix(0.0, nrow = I, ncol = n_draws)
  for (i_idx in seq_along(u_rows)) {
    r_name <- u_rows[i_idx]
    k_matches <- which(row_lvls == r_name)
    if (length(k_matches) == 1) {
      row_sums_draws[i_idx, ] <- pi_draws[k_matches, ]
    } else {
      row_sums_draws[i_idx, ] <- colSums(pi_draws[k_matches, , drop = FALSE])
    }
  }

  col_sums_draws <- matrix(0.0, nrow = J, ncol = n_draws)
  for (j_idx in seq_along(u_cols)) {
    c_name <- u_cols[j_idx]
    k_matches <- which(col_lvls == c_name)
    if (length(k_matches) == 1) {
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

    # 実務的乖離 Delta = pi_ij - pi_i+ * pi_+j
    delta_diff <- k_pi - (k_pi_row * k_pi_col)

    # クオンタイル
    q_pi <- stats::quantile(k_pi, probs = c(0.025, 0.25, 0.50, 0.75, 0.975), names = FALSE)

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
      prob_dir_positive = round(mean(log_div > 0), 4),
      prob_practical_delta = round(mean(abs(delta_diff) > delta), 4)
    )
  }

  # 生ドロー破棄 (メモリポリシー遵守)
  rm(pi_draws, row_sums_draws, col_sums_draws)

  # 4. 事前感度分析 (alpha = 0.5 Jeffreys型事前分布との比較)
  alpha_sens <- 0.5
  alpha_sens_post <- alpha_sens + obs_counts
  analytic_mean_sens <- alpha_sens_post / sum(alpha_sens_post)
  max_prior_diff <- max(abs(analytic_mean - analytic_mean_sens))

  sensitivity_summary <- list(
    primary_alpha = alpha,
    sensitivity_alpha = alpha_sens,
    max_absolute_mean_diff = round(max_prior_diff, 6),
    is_sensitive = (max_prior_diff >= 0.05)
  )

  return(list(
    prior_specification = list(alpha = alpha),
    n_draws = n_draws,
    deterministic_seed = seed_int,
    cell_posteriors = cell_posteriors,
    sensitivity = sensitivity_summary
  ))
}
