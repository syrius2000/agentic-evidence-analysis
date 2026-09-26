# cramers_v_ci.R — Non-central Chi-square Inversion CI for Cramér's V & Bias-Corrected V

#' Smithson / Steiger 非心カイ二乗累積分布の数値反転による非心度 95% 信頼区間
#'
#' @param chisq_val numeric(1) 観測カイ二乗値 X^2 >= 0
#' @param df integer(1) 自由度 >= 1
#' @param conf_level numeric(1) 信頼水準（既定 0.95）
#' @return list(lambda_lower, lambda_upper)
#' @export
compute_ncp_ci <- function(chisq_val, df, conf_level = 0.95) {
  if (chisq_val <= 0 || is.na(chisq_val)) {
    return(list(lambda_lower = 0.0, lambda_upper = 0.0))
  }

  alpha <- 1 - conf_level
  p_lower <- 1 - alpha / 2  # 0.975 (下側限界用: F(x; df, lambda_L) = 0.975)
  p_upper <- alpha / 2      # 0.025 (上側限界用: F(x; df, lambda_U) = 0.025)

  # 下側限界 lambda_L
  # chisq_val <= qchisq(1 - alpha/2, df) の場合、lambda_L は 0
  crit_val <- stats::qchisq(p_lower, df = df)
  if (chisq_val <= crit_val) {
    lambda_L <- 0.0
  } else {
    target_fun_L <- function(lam) {
      stats::pchisq(chisq_val, df = df, ncp = lam) - p_lower
    }
    # 探索区間: [0, chisq_val]
    # lam = 0 のとき pchisq(chisq_val, df, 0) > p_lower なので差は正
    # lam が十分大きいとき pchisq は 0 に近づくので差は負
    upper_bracket <- max(10, chisq_val * 3)
    while (target_fun_L(upper_bracket) > 0 && upper_bracket < 1e7) {
      upper_bracket <- upper_bracket * 2
    }
    root_L <- tryCatch({
      stats::uniroot(target_fun_L, interval = c(0, upper_bracket), tol = 1e-8)$root
    }, error = function(e) {
      0.0
    })
    lambda_L <- max(0.0, root_L)
  }

  # 上側限界 lambda_U
  target_fun_U <- function(lam) {
    stats::pchisq(chisq_val, df = df, ncp = lam) - p_upper
  }
  lower_bracket <- max(0.0, chisq_val - df)
  upper_bracket <- max(20, chisq_val + 5 * sqrt(2 * chisq_val + df) + 50)
  while (target_fun_U(upper_bracket) > 0 && upper_bracket < 1e7) {
    upper_bracket <- upper_bracket * 2
  }
  # lower_bracket で target_fun_U が負になる場合は 0 から探索
  if (target_fun_U(lower_bracket) < 0) {
    lower_bracket <- 0.0
  }
  root_U <- tryCatch({
    stats::uniroot(target_fun_U, interval = c(lower_bracket, upper_bracket), tol = 1e-8)$root
  }, error = function(e) {
    stats::uniroot(target_fun_U, interval = c(0, max(100, upper_bracket * 2)), tol = 1e-8)$root
  })
  lambda_U <- max(lambda_L, root_U)

  return(list(lambda_lower = lambda_L, lambda_upper = lambda_U))
}

#' Cramér's V および Bergsma (2013) Bias-Corrected V とその 95% 信頼区間
#'
#' @param chisq_val numeric(1)
#' @param N integer(1)
#' @param I integer(1) 行水準数
#' @param J integer(1) 列水準数
#' @param conf_level numeric(1)
#' @return list
#' @export
compute_cramers_v_bundle <- function(chisq_val, N, I, J, conf_level = 0.95) {
  k_min <- min(I, J)
  m <- k_min - 1
  df <- (I - 1) * (J - 1)

  # 1. 未補正 Cramér's V
  v_raw <- sqrt(max(0, chisq_val / (N * m)))
  v_raw <- min(1.0, max(0.0, v_raw))

  # 非心カイ二乗反転による非心度 CI
  ncp <- compute_ncp_ci(chisq_val, df, conf_level)
  v_ci_lower <- sqrt(max(0, ncp$lambda_lower / (N * m)))
  v_ci_upper <- sqrt(max(0, ncp$lambda_upper / (N * m)))
  v_ci <- c(min(1.0, max(0.0, v_ci_lower)), min(1.0, max(0.0, v_ci_upper)))

  # 2. Bergsma (2013) bias-corrected Cramér's V
  phi_sq_corr <- max(0.0, (chisq_val / N) - as.numeric(df) / (N - 1))
  k_tilde_row <- I - ((I - 1)^2) / (N - 1)
  k_tilde_col <- J - ((J - 1)^2) / (N - 1)
  k_tilde <- min(k_tilde_row, k_tilde_col)
  denom_corr <- k_tilde - 1.0

  if (denom_corr > 1e-7 && N > (df + 1)) {
    v_corr <- sqrt(max(0.0, phi_sq_corr / denom_corr))
    v_corr <- min(1.0, max(0.0, v_corr))

    # Bias-corrected CI
    phi_sq_L <- max(0.0, ncp$lambda_lower / N)
    phi_sq_U <- max(0.0, ncp$lambda_upper / N)
    v_corr_L <- min(1.0, max(0.0, sqrt(phi_sq_L / denom_corr)))
    v_corr_U <- min(1.0, max(0.0, sqrt(phi_sq_U / denom_corr)))
    v_corr_ci <- c(v_corr_L, v_corr_U)
  } else {
    v_corr <- 0.0
    v_corr_ci <- NULL
  }

  return(list(
    cramers_v = v_raw,
    cramers_v_ci = v_ci,
    cramers_v_corrected = v_corr,
    cramers_v_corrected_ci = v_corr_ci,
    ncp = ncp,
    k_tilde = k_tilde
  ))
}
