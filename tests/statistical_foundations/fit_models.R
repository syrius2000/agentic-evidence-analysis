#!/usr/bin/env Rscript
# tests/statistical_foundations/fit_models.R
# 3次元分割表に対する 9 候補の Poisson GLM 適合とセル診断スクリプト

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

# 9候補モデルの定義（変数 A, B, C のシンボル）
# 目的変数の有無にかかわらずモデル集合・式は不変（設計契約）
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

build_formula <- function(model_id, vars, freq_col) {
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

fit_single_poisson_glm <- function(model_id, df, vars, freq_col) {
  fmla <- build_formula(model_id, vars, freq_col)
  
  # GLM適合（警告や収束状況をキャッチ）
  warn_msgs <- character(0)
  err_msg <- NULL
  fit <- NULL
  
  withCallingHandlers(
    tryCatch({
      fit <- glm(fmla, data = df, family = poisson(), x = TRUE, y = TRUE)
    }, error = function(e) {
      err_msg <<- e$message
    }),
    warning = function(w) {
      warn_msgs <<- c(warn_msgs, w$message)
      invokeRestart("muffleWarning")
    }
  )
  
  if (!is.null(err_msg)) {
    return(list(
      id = model_id,
      name = MODEL_SPECS_3WAY[[model_id]]$name,
      formula = deparse(fmla),
      status = "ERROR",
      error_message = err_msg,
      converged = FALSE,
      fitted_values = NULL,
      deviance = NA_real_,
      df_residual = NA_integer_,
      rank = NA_integer_,
      loglik = NA_real_
    ))
  }
  
  # 収束・境界・階数判定
  converged <- isTRUE(fit$converged)
  boundary <- isTRUE(fit$boundary)
  
  # デザイン行列の階数
  X <- model.matrix(fit)
  design_rank <- qr(X)$rank
  n_cols <- ncol(X)
  is_full_rank <- (design_rank == n_cols)
  
  # ゼロセル・境界適合の確認
  y <- fit$y
  has_zero_cells <- any(y == 0)
  has_small_fitted <- any(fit$fitted.values < 1e-6)
  
  estimation_status <- "REGULAR"
  status_reasons <- character(0)
  
  if (!converged) {
    estimation_status <- "NON_CONVERGED"
    status_reasons <- c(status_reasons, "GLMが最大反復回数内に収束しませんでした")
  }
  if (boundary || has_small_fitted) {
    if (estimation_status == "REGULAR") estimation_status <- "BOUNDARY"
    status_reasons <- c(status_reasons, "適合値がパラメータ空間の境界に達しています（0セル極限推定）")
  }
  if (!is_full_rank) {
    if (estimation_status == "REGULAR") estimation_status <- "RANK_DEFICIENT"
    status_reasons <- c(status_reasons, sprintf("デザイン行列の階数が不足しています (rank=%d, cols=%d)", design_rank, n_cols))
  }
  
  # 適合値・残差・対数尤度
  mu_hat <- fit$fitted.values
  dev <- fit$deviance
  df_res <- fit$df.residual
  ll <- as.numeric(logLik(fit))
  
  # Pearson残差と逸脱度残差
  # y=0 の場合 0*log(0/mu) = 0
  pearson_res <- (y - mu_hat) / sqrt(pmax(mu_hat, 1e-12))
  dev_contrib <- ifelse(y == 0, 2 * mu_hat, 2 * (y * log(pmax(y, 1e-12) / pmax(mu_hat, 1e-12)) - (y - mu_hat)))
  deviance_res <- sign(y - mu_hat) * sqrt(pmax(dev_contrib, 0))
  
  list(
    id = model_id,
    name = MODEL_SPECS_3WAY[[model_id]]$name,
    formula = deparse(fmla),
    status = estimation_status,
    status_reasons = status_reasons,
    converged = converged,
    boundary = boundary,
    rank = design_rank,
    n_params = n_cols,
    df_residual = df_res,
    deviance = dev,
    loglik = ll,
    aic = fit$aic,
    bic_stats = BIC(fit), # stats::BIC 監査用
    fitted_values = as.numeric(mu_hat),
    observed_values = as.numeric(y),
    leverage = as.numeric(stats::hatvalues(fit)),
    pearson_residuals = as.numeric(pearson_res),
    deviance_residuals = as.numeric(deviance_res),
    obs_fitted_ratio = as.numeric(ifelse(mu_hat > 0, y / mu_hat, NA_real_))
  )
}

fit_all_9_models <- function(df, vars, freq_col = "Freq", response_var = NULL) {
  stopifnot(length(vars) == 3L)
  stopifnot(freq_col %in% names(df))
  stopifnot(all(vars %in% names(df)))
  
  # データを行順序でソート固定
  df_sorted <- df %>% arrange(across(all_of(vars)))
  
  results <- list()
  for (m_id in names(MODEL_SPECS_3WAY)) {
    results[[m_id]] <- fit_single_poisson_glm(m_id, df_sorted, vars, freq_col)
  }
  
  list(
    vars = vars,
    freq_col = freq_col,
    response_var = response_var,
    n_cells = nrow(df_sorted),
    total_n = sum(df_sorted[[freq_col]]),
    models = results
  )
}
