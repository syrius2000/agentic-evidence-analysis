# residual_diagnostics.R — Poisson GLM Independence, Residuals, Leverage & Quarantine

#' 2次元分割表に対する Poisson 独立モデル適合・残差診断・Quarantine 判定
#'
#' @param agg_data data.frame (var1, var2, Freq)
#' @return list(global, cells, cells_df, table)
#' @export
compute_residual_diagnostics <- function(agg_data) {
  vars <- attr(agg_data, "vars")
  if (is.null(vars) || length(vars) != 2L) {
    vars <- names(agg_data)[1:2]
  }
  v1 <- vars[1]
  v2 <- vars[2]

  # 行・列水準
  levels1 <- levels(factor(agg_data[[v1]]))
  levels2 <- levels(factor(agg_data[[v2]]))
  I <- length(levels1)
  J <- length(levels2)
  df <- (I - 1L) * (J - 1L)

  # 完全なグリッドを作成し、観測度数をマージ（欠測セルは0埋め）
  grid <- expand.grid(
    row_level = levels1,
    col_level = levels2,
    stringsAsFactors = FALSE
  )
  names(grid) <- c(v1, v2)
  merged <- merge(grid, agg_data, by = c(v1, v2), all.x = TRUE)
  merged$Freq[is.na(merged$Freq)] <- 0L

  # 分割表行列
  tab <- tapply(merged$Freq, list(merged[[v1]], merged[[v2]]), sum)
  tab[is.na(tab)] <- 0L

  N <- sum(tab)
  row_totals <- rowSums(tab)
  col_totals <- colSums(tab)

  # 行割合・列割合
  p_row <- row_totals / N
  p_col <- col_totals / N

  cells_list <- vector("list", nrow(merged))

  total_pearson_chisq <- 0.0
  total_deviance_gsq <- 0.0

  for (k in seq_len(nrow(merged))) {
    r_lvl <- as.character(merged[[v1]][k])
    c_lvl <- as.character(merged[[v2]][k])
    O <- as.integer(merged$Freq[k])

    i_idx <- match(r_lvl, levels1)
    j_idx <- match(c_lvl, levels2)

    p_i <- p_row[i_idx]
    p_j <- p_col[j_idx]

    E <- N * p_i * p_j

    # 1. Pearson 残差
    r_p <- (O - E) / sqrt(E)
    total_pearson_chisq <- total_pearson_chisq + (r_p^2)

    # 2. Deviance 残差
    if (O > 0) {
      log_oe_val <- log(O / E)
      d_comp <- 2 * (O * log_oe_val - (O - E))
      r_d <- sign(O - E) * sqrt(max(0, d_comp))
      total_deviance_gsq <- total_deviance_gsq + (2 * O * log_oe_val)
    } else {
      # O = 0 の極限: 2 * (0 - (0 - E)) = 2E
      r_d <- -sqrt(2 * E)
    }

    # 3. Leverage (Hat行列対角成分)
    h_ij <- p_i + p_j - (p_i * p_j)

    # 4. Haberman 調整残差
    denom_adj <- sqrt(1 - h_ij)
    if (denom_adj > 1e-10) {
      r_adj <- r_p / denom_adj
    } else {
      r_adj <- 0.0
    }

    # 5. Quarantine 判定
    q_reasons <- character(0)
    if (O == 0) {
      q_reasons <- c(q_reasons, "ZERO_OBSERVED")
    }
    if (E < 5.0) {
      q_reasons <- c(q_reasons, "EXPECTED_LT_5")
    }
    if (h_ij >= 0.80) {
      q_reasons <- c(q_reasons, "HIGH_LEVERAGE")
    }

    q_status <- if (length(q_reasons) > 0L) "QUARANTINED" else "ACTIVE"
    q_reasons_str <- if (length(q_reasons) > 0L) paste(q_reasons, collapse = ";") else ""

    cells_list[[k]] <- list(
      row_level = r_lvl,
      col_level = c_lvl,
      observed = O,
      expected = as.numeric(round(E, 4)),
      expected_raw = E,
      pearson_res = as.numeric(round(r_p, 4)),
      pearson_res_raw = r_p,
      deviance_res = as.numeric(round(r_d, 4)),
      adj_res = as.numeric(round(r_adj, 4)),
      adj_res_raw = r_adj,
      leverage = as.numeric(round(h_ij, 4)),
      leverage_raw = h_ij,
      quarantine_status = q_status,
      quarantine_reasons = q_reasons,
      quarantine_reasons_str = q_reasons_str
    )
  }

  cells_df <- do.call(rbind, lapply(cells_list, function(item) {
    df_item <- item
    df_item$quarantine_reasons <- NULL
    as.data.frame(df_item, stringsAsFactors = FALSE)
  }))

  # 期待度数診断 (Cochran 条件)
  expected_vec <- vapply(cells_list, function(c) c$expected_raw, numeric(1))
  min_exp <- min(expected_vec)
  prop_lt_5 <- mean(expected_vec < 5.0)
  cochran_ok <- (min_exp >= 1.0) && (prop_lt_5 <= 0.20)

  expected_count_diag <- list(
    min_expected = as.numeric(round(min_exp, 4)),
    prop_lt_5 = as.numeric(round(prop_lt_5, 4)),
    cochran_satisfied = cochran_ok
  )

  # 全体カイ二乗統計量とp値
  pearson_p <- stats::pchisq(total_pearson_chisq, df = df, lower.tail = FALSE)
  deviance_p <- stats::pchisq(total_deviance_gsq, df = df, lower.tail = FALSE)

  global_info <- list(
    n_total = N,
    n_rows = I,
    n_cols = J,
    df = df,
    pearson_chisq = total_pearson_chisq,
    pearson_p_value = pearson_p,
    deviance_gsq = total_deviance_gsq,
    deviance_p_value = deviance_p,
    expected_count_diagnostics = expected_count_diag
  )

  return(list(
    global = global_info,
    cells = cells_list,
    cells_df = cells_df,
    table = tab
  ))
}
