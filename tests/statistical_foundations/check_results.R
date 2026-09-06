#!/usr/bin/env Rscript
# tests/statistical_foundations/check_results.R
# 主計算（Poisson GLM）と独立参照計算の照合・入れ子比較・異常推定分離スクリプト

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

# 標準的な入れ子モデル比較ペア定義
# base_model が reduced（制約モデル）、target_model が full（拡張モデル）
NESTED_COMPARISON_PAIRS <- list(
  list(reduced = "M1", full = "M2", tested_term = "AB interaction"),
  list(reduced = "M1", full = "M3", tested_term = "AC interaction"),
  list(reduced = "M1", full = "M4", tested_term = "BC interaction"),
  list(reduced = "M2", full = "M5", tested_term = "AC interaction given AB"),
  list(reduced = "M2", full = "M6", tested_term = "BC interaction given AB"),
  list(reduced = "M3", full = "M5", tested_term = "AB interaction given AC"),
  list(reduced = "M3", full = "M7", tested_term = "BC interaction given AC"),
  list(reduced = "M4", full = "M6", tested_term = "AB interaction given BC"),
  list(reduced = "M4", full = "M7", tested_term = "AC interaction given BC"),
  list(reduced = "M5", full = "M8", tested_term = "BC interaction given AB+AC"),
  list(reduced = "M6", full = "M8", tested_term = "AC interaction given AB+BC"),
  list(reduced = "M7", full = "M8", tested_term = "AB interaction given AC+BC"),
  list(reduced = "M8", full = "M9", tested_term = "3-way ABC interaction")
)

check_model_against_reference <- function(glm_res, ref_res, tolerances = list()) {
  rel_tol <- if (!is.null(tolerances$glm_vs_loglin_fitted_rel_tol)) tolerances$glm_vs_loglin_fitted_rel_tol else 1e-05
  dev_tol <- if (!is.null(tolerances$glm_vs_loglin_deviance_abs_tol)) tolerances$glm_vs_loglin_deviance_abs_tol else 1e-04
  
  model_checks <- list()
  all_passed <- TRUE
  
  m_ids <- names(glm_res$models)
  for (m_id in m_ids) {
    g_m <- glm_res$models[[m_id]]
    r_m <- ref_res$models[[m_id]]
    
    # 適合値の最大相対誤差
    g_fitted <- g_m$fitted_values
    r_fitted <- r_m$loglin_fitted
    
    # ゼロ近傍の安全な分母処理
    denom <- pmax(r_fitted, 1e-6)
    max_rel_err_fitted <- max(abs(g_fitted - r_fitted) / denom)
    fitted_match <- (max_rel_err_fitted <= rel_tol)
    
    # 逸脱度の絶対誤差
    g_dev <- g_m$deviance
    r_dev <- r_m$loglin_deviance
    abs_err_dev <- abs(g_dev - r_dev)
    deviance_match <- (abs_err_dev <= dev_tol)
    
    # 自由度の一致
    df_match <- identical(as.integer(g_m$df_residual), as.integer(r_m$loglin_df))
    
    # 閉形式との一致確認（存在する場合）
    cf_match <- NA
    cf_rel_err <- NA_real_
    if (r_m$has_closed_form) {
      cf_fitted <- r_m$closed_form_fitted
      cf_rel_err <- max(abs(cf_fitted - r_fitted) / pmax(r_fitted, 1e-6))
      cf_match <- (cf_rel_err <= rel_tol)
    }
    
    # 総合合否判定: GLM適合値一致 && 逸脱度一致 && 自由度一致 && (閉形式解が存在する場合は閉形式解とも一致)
    is_ok <- fitted_match && deviance_match && df_match
    if (r_m$has_closed_form) {
      is_ok <- is_ok && isTRUE(cf_match)
    }
    if (!is_ok) all_passed <- FALSE
    
    model_checks[[m_id]] <- list(
      model_id = m_id,
      model_name = g_m$name,
      estimation_status = g_m$status,
      status_reasons = g_m$status_reasons,
      max_rel_err_fitted = max_rel_err_fitted,
      fitted_match = fitted_match,
      abs_err_deviance = abs_err_dev,
      deviance_match = deviance_match,
      df_match = df_match,
      closed_form_available = r_m$has_closed_form,
      closed_form_rel_err = cf_rel_err,
      closed_form_match = cf_match,
      check_passed = is_ok
    )
  }
  
  # 入れ子比較の計算
  nested_comparisons <- list()
  for (pair in NESTED_COMPARISON_PAIRS) {
    r_id <- pair$reduced
    f_id <- pair$full
    g_r <- glm_res$models[[r_id]]
    g_f <- glm_res$models[[f_id]]
    
    delta_dev <- g_r$deviance - g_f$deviance
    delta_df <- g_r$df_residual - g_f$df_residual
    
    # カイ二乗P値（上側確率および対数確率を直接算出して数値精度を保持）
    p_val <- NA_real_
    log_p_val <- NA_real_
    if (!is.na(delta_df) && delta_df > 0 && !is.na(delta_dev) && delta_dev >= 0) {
      p_val <- pchisq(delta_dev, df = delta_df, lower.tail = FALSE)
      log_p_val <- pchisq(delta_dev, df = delta_df, lower.tail = FALSE, log.p = TRUE)
    }
    
    nested_comparisons[[paste(r_id, "vs", f_id, sep = "_")]] <- list(
      reduced_model = r_id,
      full_model = f_id,
      tested_term = pair$tested_term,
      comparison_direction = "deviance(reduced) - deviance(full)",
      delta_deviance = delta_dev,
      delta_df = delta_df,
      p_value_chisq = p_val,
      log_p_value_chisq = log_p_val,
      interpretation_warning = "尤度比統計量のカイ二乗分布による評価は条件付き漸近近似である。大標本下では漸近的検出力の増大に伴い微小な効果でも統計的有意となりやすいため、効果量（Cramér's V、割合差、オッズ比）やBIC差と併読すること"
    )
  }
  
  # 異常推定（境界・収束不良・特異）の分離（タスク 3.4）
  regular_models <- character(0)
  quarantined_models <- list()
  
  for (m_id in m_ids) {
    m_info <- glm_res$models[[m_id]]
    if (m_info$status == "REGULAR") {
      regular_models <- c(regular_models, m_id)
    } else {
      quarantined_models[[m_id]] <- list(
        model_id = m_id,
        status = m_info$status,
        reasons = m_info$status_reasons,
        excluded_from_ranking = TRUE
      )
    }
  }
  
  list(
    all_reference_checks_passed = all_passed,
    tolerances_applied = list(
      rel_tol = rel_tol,
      dev_tol = dev_tol
    ),
    per_model_checks = model_checks,
    nested_comparisons = nested_comparisons,
    regular_models_pool = regular_models,
    quarantined_models = quarantined_models
  )
}
