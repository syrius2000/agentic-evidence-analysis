# effect_evidence_metrics.R — Effect Sizes, Local Rao Score, Dual-Filter & Cramér's V CI

# cramers_v_ci.R の安全なパス解決
find_shared_cramer <- function() {
  candidates <- c(
    file.path(".agents", "shared", "categorical", "cramers_v_ci.R"),
    file.path(getwd(), ".agents", "shared", "categorical", "cramers_v_ci.R")
  )
  for (c in candidates) {
    if (file.exists(c)) return(normalizePath(c, winslash = "/", mustWork = TRUE))
  }
  # 親ディレクトリ探索
  d <- getwd()
  for (i in seq_len(10L)) {
    p <- file.path(d, ".agents", "shared", "categorical", "cramers_v_ci.R")
    if (file.exists(p)) return(normalizePath(p, winslash = "/", mustWork = TRUE))
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  stop("[ERROR] cramers_v_ci.R が見つかりません。")
}
source(find_shared_cramer())

#' 局所効果・統計的証拠・大標本Dual-Filter判定および全体効果量の算出
#'
#' @param diagnostics_result list compute_residual_diagnostics の出力
#' @return list(global, cells, cells_df, n_candidates)
#' @export
compute_effect_evidence_metrics <- function(diagnostics_result) {
  glob <- diagnostics_result$global
  cells_raw <- diagnostics_result$cells
  N <- glob$n_total
  I <- glob$n_rows
  J <- glob$n_cols

  # 1. 全体効果量と信頼区間の算出 (未補正 & bias-corrected)
  v_bundle <- compute_cramers_v_bundle(glob$pearson_chisq, N, I, J, conf_level = 0.95)

  glob$cramers_v <- round(v_bundle$cramers_v, 4)
  glob$cramers_v_ci <- round(v_bundle$cramers_v_ci, 4)
  glob$cramers_v_corrected <- round(v_bundle$cramers_v_corrected, 4)
  glob$cramers_v_corrected_ci <- if (!is.null(v_bundle$cramers_v_corrected_ci)) {
    round(v_bundle$cramers_v_corrected_ci, 4)
  } else {
    NULL
  }

  # 2. セル単位メトリクス（Raoスコア、log(O/E)、割合差、p値）
  n_cells <- length(cells_raw)
  rao_scores <- numeric(n_cells)
  p_unadj_vec <- numeric(n_cells)

  for (k in seq_len(n_cells)) {
    c_item <- cells_raw[[k]]
    # T^score = (r^P)^2 / (1 - h) = (r^adj)^2
    r_adj <- c_item$adj_res_raw
    t_score <- r_adj^2
    rao_scores[k] <- t_score
    p_unadj_vec[k] <- stats::pchisq(t_score, df = 1, lower.tail = FALSE)
  }

  p_bh_vec <- stats::p.adjust(p_unadj_vec, method = "BH")

  processed_cells <- vector("list", n_cells)
  n_candidates <- 0L

  for (k in seq_len(n_cells)) {
    c_item <- cells_raw[[k]]
    O <- c_item$observed
    E <- c_item$expected_raw
    t_score <- rao_scores[k]
    p_unadj <- p_unadj_vec[k]
    p_bh <- p_bh_vec[k]

    # 局所対数効果比 log(O/E) の安全契約
    if (O > 0) {
      log_oe_val <- log(O / E)
      log_oe_out <- round(log_oe_val, 4)
      log_oe_state <- "FINITE"
      is_finite <- TRUE
    } else {
      log_oe_val <- -Inf
      log_oe_out <- NULL
      log_oe_state <- "NEGATIVE_INFINITY"
      is_finite <- FALSE
    }

    # 符号付き割合差 (O - E) / N
    signed_diff <- (O - E) / N

    # 大標本 Dual-Filter 判定:
    # 大標本（N >= 2000）かつ 非隔離（ACTIVE）かつ 有限対数効果比（O > 0）のセルのみ候補判定
    # 小標本（N < 2000）では常に FALSE
    is_candidate <- FALSE
    if (N >= 2000L && is_finite && identical(c_item$quarantine_status, "ACTIVE")) {
      if (abs(log_oe_val) >= 0.50 && t_score >= 3.8415) {
        is_candidate <- TRUE
      }
    }
    if (is_candidate) {
      n_candidates <- n_candidates + 1L
    }

    cell_rec <- list(
      row_level = c_item$row_level,
      col_level = c_item$col_level,
      observed = O,
      expected = c_item$expected,
      pearson_res = c_item$pearson_res,
      deviance_res = c_item$deviance_res,
      adj_res = c_item$adj_res,
      leverage = c_item$leverage,
      log_oe = log_oe_out,
      log_oe_state = log_oe_state,
      is_finite = is_finite,
      signed_diff_ratio = round(signed_diff, 4),
      rao_score = round(t_score, 4),
      p_value_unadj = round(p_unadj, 6),
      p_value_bh = round(p_bh, 6),
      quarantine_status = c_item$quarantine_status,
      quarantine_reasons = c_item$quarantine_reasons,
      dual_filter_candidate = is_candidate
    )
    processed_cells[[k]] <- cell_rec
  }

  cells_df <- do.call(rbind, lapply(processed_cells, function(item) {
    df_item <- item
    df_item$quarantine_reasons <- paste(item$quarantine_reasons, collapse = ";")
    if (is.null(df_item$log_oe)) {
      df_item$log_oe <- NA_real_
    }
    as.data.frame(df_item, stringsAsFactors = FALSE)
  }))

  return(list(
    global = glob,
    cells = processed_cells,
    cells_df = cells_df,
    n_candidates = n_candidates
  ))
}
