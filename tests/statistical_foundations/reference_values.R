#!/usr/bin/env Rscript
# tests/statistical_foundations/reference_values.R
# 独立参照計算エンジン（閉形式解析解および stats::loglin 反復比例適合）
# 注: fit_models.R の GLM 計算には一切依存しない完全独立実装

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

# 3元分割表配列の作成
df_to_3way_array <- function(df, vars, freq_col = "Freq") {
  df_sorted <- df

  l1 <- sort(unique(df_sorted[[vars[1L]]]))
  l2 <- sort(unique(df_sorted[[vars[2L]]]))
  l3 <- sort(unique(df_sorted[[vars[3L]]]))

  arr <- array(0, dim = c(length(l1), length(l2), length(l3)),
               dimnames = list(l1, l2, l3))
  names(dimnames(arr)) <- vars

  for (i in seq_len(nrow(df_sorted))) {
    v1 <- as.character(df_sorted[[vars[1L]]][i])
    v2 <- as.character(df_sorted[[vars[2L]]][i])
    v3 <- as.character(df_sorted[[vars[3L]]][i])
    arr[v1, v2, v3] <- df_sorted[[freq_col]][i]
  }
  arr
}

# 閉形式による期待度数計算（M1〜M7, M9）
compute_closed_form_expectations <- function(arr) {
  N <- sum(arr)
  d <- dim(arr)

  # 1次元周辺和
  n_A <- apply(arr, 1L, sum)       # n_{i++}
  n_B <- apply(arr, 2L, sum)       # n_{+j+}
  n_C <- apply(arr, 3L, sum)       # n_{++k}

  # 2次元周辺和
  n_AB <- apply(arr, c(1L, 2L), sum) # n_{ij+}
  n_AC <- apply(arr, c(1L, 3L), sum) # n_{i+k}
  n_BC <- apply(arr, c(2L, 3L), sum) # n_{+jk}

  out <- list()

  # M1: mutual independence
  # mu_ijk = n_i++ * n_+j+ * n_++k / N^2
  m1 <- array(0, dim = d, dimnames = dimnames(arr))
  for (i in seq_len(d[1])) {
    for (j in seq_len(d[2])) {
      for (k in seq_len(d[3])) {
        m1[i, j, k] <- (n_A[i] * n_B[j] * n_C[k]) / (N^2)
      }
    }
  }
  out[["M1"]] <- m1

  # M2: assoc_AB (C independent)
  # mu_ijk = n_ij+ * n_++k / N
  m2 <- array(0, dim = d, dimnames = dimnames(arr))
  for (i in seq_len(d[1])) {
    for (j in seq_len(d[2])) {
      for (k in seq_len(d[3])) {
        m2[i, j, k] <- (n_AB[i, j] * n_C[k]) / N
      }
    }
  }
  out[["M2"]] <- m2

  # M3: assoc_AC (B independent)
  # mu_ijk = n_i+k * n_+j+ / N
  m3 <- array(0, dim = d, dimnames = dimnames(arr))
  for (i in seq_len(d[1])) {
    for (j in seq_len(d[2])) {
      for (k in seq_len(d[3])) {
        m3[i, j, k] <- (n_AC[i, k] * n_B[j]) / N
      }
    }
  }
  out[["M3"]] <- m3

  # M4: assoc_BC (A independent)
  # mu_ijk = n_+jk * n_i++ / N
  m4 <- array(0, dim = d, dimnames = dimnames(arr))
  for (i in seq_len(d[1])) {
    for (j in seq_len(d[2])) {
      for (k in seq_len(d[3])) {
        m4[i, j, k] <- (n_BC[j, k] * n_A[i]) / N
      }
    }
  }
  out[["M4"]] <- m4

  # M5: cond_indep_BC_given_A
  # mu_ijk = n_ij+ * n_i+k / n_i++
  m5 <- array(0, dim = d, dimnames = dimnames(arr))
  for (i in seq_len(d[1])) {
    denom <- n_A[i]
    for (j in seq_len(d[2])) {
      for (k in seq_len(d[3])) {
        m5[i, j, k] <- if (denom > 0) (n_AB[i, j] * n_AC[i, k]) / denom else 0
      }
    }
  }
  out[["M5"]] <- m5

  # M6: cond_indep_AC_given_B
  # mu_ijk = n_ij+ * n_+jk / n_+j+
  m6 <- array(0, dim = d, dimnames = dimnames(arr))
  for (j in seq_len(d[2])) {
    denom <- n_B[j]
    for (i in seq_len(d[1])) {
      for (k in seq_len(d[3])) {
        m6[i, j, k] <- if (denom > 0) (n_AB[i, j] * n_BC[j, k]) / denom else 0
      }
    }
  }
  out[["M6"]] <- m6

  # M7: cond_indep_AB_given_C
  # mu_ijk = n_i+k * n_+jk / n_++k
  m7 <- array(0, dim = d, dimnames = dimnames(arr))
  for (k in seq_len(d[3])) {
    denom <- n_C[k]
    for (i in seq_len(d[1])) {
      for (j in seq_len(d[2])) {
        m7[i, j, k] <- if (denom > 0) (n_AC[i, k] * n_BC[j, k]) / denom else 0
      }
    }
  }
  out[["M7"]] <- m7

  # M8: homogeneous_association -> 閉形式なし（反復比例適合のみ）
  out[["M8"]] <- NULL

  # M9: saturated
  # mu_ijk = n_ijk
  out[["M9"]] <- arr

  out
}

# stats::loglin による反復比例適合（全9モデル）
compute_loglin_reference <- function(arr) {
  # stats::loglin のマージン定義 (1=A, 2=B, 3=C)
  margin_defs <- list(
    M1 = list(1L, 2L, 3L),
    M2 = list(c(1L, 2L), 3L),
    M3 = list(c(1L, 3L), 2L),
    M4 = list(c(2L, 3L), 1L),
    M5 = list(c(1L, 2L), c(1L, 3L)),
    M6 = list(c(1L, 2L), c(2L, 3L)),
    M7 = list(c(1L, 3L), c(2L, 3L)),
    M8 = list(c(1L, 2L), c(1L, 3L), c(2L, 3L)),
    M9 = list(c(1L, 2L, 3L))
  )

  results <- list()
  for (m_id in names(margin_defs)) {
    margs <- margin_defs[[m_id]]
    # loglin 実行
    ll_res <- stats::loglin(arr, margin = margs, fit = TRUE, eps = 1e-10, iter = 2000, print = FALSE)

    results[[m_id]] <- list(
      id = m_id,
      margins = margs,
      fitted_array = ll_res$fit,
      deviance = as.numeric(ll_res$lrt),
      pearson_x2 = as.numeric(ll_res$pearson),
      df = as.integer(ll_res$df)
    )
  }
  results
}

# データフレーム順のベクトルとして参照値を取り出す
extract_reference_values <- function(df, vars, freq_col = "Freq") {
  df_sorted <- df
  arr <- df_to_3way_array(df_sorted, vars, freq_col)

  closed_forms <- compute_closed_form_expectations(arr)
  loglin_refs <- compute_loglin_reference(arr)

  # 各セルに対応するインデックス順序でベクトル化
  # df_sorted の行順と一致させる
  ref_by_model <- list()

  for (m_id in c("M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9")) {
    ll <- loglin_refs[[m_id]]
    cf_arr <- closed_forms[[m_id]]

    ll_vec <- numeric(nrow(df_sorted))
    cf_vec <- if (!is.null(cf_arr)) numeric(nrow(df_sorted)) else NULL

    for (r in seq_len(nrow(df_sorted))) {
      v1 <- as.character(df_sorted[[vars[1L]]][r])
      v2 <- as.character(df_sorted[[vars[2L]]][r])
      v3 <- as.character(df_sorted[[vars[3L]]][r])

      ll_vec[r] <- ll$fitted_array[v1, v2, v3]
      if (!is.null(cf_arr)) {
        cf_vec[r] <- cf_arr[v1, v2, v3]
      }
    }

    ref_by_model[[m_id]] <- list(
      id = m_id,
      loglin_fitted = ll_vec,
      loglin_deviance = ll$deviance,
      loglin_df = ll$df,
      closed_form_fitted = cf_vec,
      has_closed_form = !is.null(cf_vec)
    )
  }

  list(
    observed = df_sorted[[freq_col]],
    total_n = sum(df_sorted[[freq_col]]),
    models = ref_by_model
  )
}
