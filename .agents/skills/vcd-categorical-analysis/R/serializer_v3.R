# serializer_v3.R — Interface 3.0 Serializer with Cross-Field Invariant & Extended Provenance

#' 成果物間の Cross-Field Invariant（スキーマ不変量）検証
#'
#' @param results_obj list categorical_results オブジェクト
#' @param profile_obj list evidence_profile オブジェクト
#' @return invisible(TRUE) 違反時は stop で即時 fail-fast
#' @export
validate_cross_artifact_invariants <- function(results_obj, profile_obj) {
  post_cells <- results_obj$posterior$cell_posteriors
  glob <- results_obj$global
  n_cells <- length(post_cells)
  n_rows <- glob$n_rows
  n_cols <- glob$n_cols

  if (!is.null(post_cells) && n_cells > 0L) {
    # 1. 結合確率平均総和の不変量 (水準数 * 1e-6 許容差)
    prob_means <- vapply(post_cells, function(p) p$prob_mean, numeric(1))
    prob_sum <- sum(prob_means)
    tol_joint <- n_cells * 1e-6
    if (abs(prob_sum - 1.0) > tol_joint) {
      stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] 事後平均結合確率の総和が1.0から乖離しています (実測値: %.6f, 許容差: %.2e)。",
                   prob_sum, tol_joint), call. = FALSE)
    }

    # 2. 条件付き事後平均の行和・列和の検証 (水準数 * 1e-6 許容差)
    row_lvls <- vapply(post_cells, function(p) p$row_level, character(1))
    col_lvls <- vapply(post_cells, function(p) p$col_level, character(1))
    cond_row_means <- vapply(post_cells, function(p) p$cond_row_prob_mean, numeric(1))
    cond_col_means <- vapply(post_cells, function(p) p$cond_col_prob_mean, numeric(1))

    u_rows <- unique(row_lvls)
    u_cols <- unique(col_lvls)
    tol_row <- n_cols * 1e-6
    tol_col <- n_rows * 1e-6

    for (r_name in u_rows) {
      r_idx <- which(row_lvls == r_name)
      r_sum <- sum(cond_row_means[r_idx])
      if (abs(r_sum - 1.0) > tol_row) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] 丸め後行条件付き事後平均の和が1.0から乖離しています (行: %s, 実測値: %.6f, 許容差: %.2e)。",
                     r_name, r_sum, tol_row), call. = FALSE)
      }
    }

    for (c_name in u_cols) {
      c_idx <- which(col_lvls == c_name)
      c_sum <- sum(cond_col_means[c_idx])
      if (abs(c_sum - 1.0) > tol_col) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] 丸め後列条件付き事後平均の和が1.0から乖離しています (列: %s, 実測値: %.6f, 許容差: %.2e)。",
                     c_name, c_sum, tol_col), call. = FALSE)
      }
    }

    # 3. 確率範囲・区間幅非負・信用区間順序の不変量
    check_prob_val <- function(val, name, r_lvl, c_lvl) {
      if (!is.numeric(val) || is.na(val) || val < 0.0 || val > 1.0) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の %s が [0, 1] の確率範囲外です (実測値: %s)。",
                     r_lvl, c_lvl, name, as.character(val)), call. = FALSE)
      }
    }
    check_width_val <- function(val, name, r_lvl, c_lvl) {
      if (!is.numeric(val) || is.na(val) || val < 0.0) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の %s が負値です (実測値: %s)。",
                     r_lvl, c_lvl, name, as.character(val)), call. = FALSE)
      }
    }

    for (k in seq_along(post_cells)) {
      p_item <- post_cells[[k]]
      r_l <- p_item$row_level
      c_l <- p_item$col_level

      # 結合確率: 範囲および順序
      check_prob_val(p_item$prob_mean, "prob_mean", r_l, c_l)
      check_prob_val(p_item$prob_q025, "prob_q025", r_l, c_l)
      check_prob_val(p_item$prob_q500, "prob_q500", r_l, c_l)
      check_prob_val(p_item$prob_q975, "prob_q975", r_l, c_l)
      check_width_val(p_item$prob_eti_width, "prob_eti_width", r_l, c_l)

      if (!(p_item$prob_q025 <= p_item$prob_q500 && p_item$prob_q500 <= p_item$prob_q975)) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の結合確率信用区間順序が破綻しています (Q025: %.6f, Q500: %.6f, Q975: %.6f)。",
                     r_l, c_l, p_item$prob_q025, p_item$prob_q500, p_item$prob_q975), call. = FALSE)
      }

      # 行条件付き確率: 範囲および順序
      check_prob_val(p_item$cond_row_prob_mean, "cond_row_prob_mean", r_l, c_l)
      check_prob_val(p_item$cond_row_prob_q025, "cond_row_prob_q025", r_l, c_l)
      check_prob_val(p_item$cond_row_prob_median, "cond_row_prob_median", r_l, c_l)
      check_prob_val(p_item$cond_row_prob_q975, "cond_row_prob_q975", r_l, c_l)
      check_width_val(p_item$cond_row_prob_eti_width, "cond_row_prob_eti_width", r_l, c_l)

      if (!(p_item$cond_row_prob_q025 <= p_item$cond_row_prob_median && p_item$cond_row_prob_median <= p_item$cond_row_prob_q975)) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の行条件付き確率信用区間順序が破綻しています (Q025: %.6f, Median: %.6f, Q975: %.6f)。",
                     r_l, c_l, p_item$cond_row_prob_q025, p_item$cond_row_prob_median, p_item$cond_row_prob_q975), call. = FALSE)
      }

      # 列条件付き確率: 範囲および順序
      check_prob_val(p_item$cond_col_prob_mean, "cond_col_prob_mean", r_l, c_l)
      check_prob_val(p_item$cond_col_prob_q025, "cond_col_prob_q025", r_l, c_l)
      check_prob_val(p_item$cond_col_prob_median, "cond_col_prob_median", r_l, c_l)
      check_prob_val(p_item$cond_col_prob_q975, "cond_col_prob_q975", r_l, c_l)
      check_width_val(p_item$cond_col_prob_eti_width, "cond_col_prob_eti_width", r_l, c_l)

      if (!(p_item$cond_col_prob_q025 <= p_item$cond_col_prob_median && p_item$cond_col_prob_median <= p_item$cond_col_prob_q975)) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の列条件付き確率信用区間順序が破綻しています (Q025: %.6f, Median: %.6f, Q975: %.6f)。",
                     r_l, c_l, p_item$cond_col_prob_q025, p_item$cond_col_prob_median, p_item$cond_col_prob_q975), call. = FALSE)
      }
    }
  }

  # 4. 成果物間 analysis_signature の一致
  sig_results <- results_obj$analysis_signature
  sig_profile <- profile_obj$analysis_signature
  if (is.null(sig_results) || is.null(sig_profile) || !identical(sig_results, sig_profile)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] analysis_signature が成果物間で不一致または未設定です (results: %s, profile: %s)。",
                 as.character(sig_results), as.character(sig_profile)), call. = FALSE)
  }

  # 5. 成果物間 run_id の一致
  run_results <- results_obj$provenance$run_id
  run_profile <- profile_obj$provenance$run_id
  if (is.null(run_results) || is.null(run_profile) || !identical(run_results, run_profile)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] run_id が成果物間で不一致または未設定です (results: %s, profile: %s)。",
                 as.character(run_results), as.character(run_profile)), call. = FALSE)
  }

  # 6. execution_mode の canonical 不変量
  if (!identical(results_obj$provenance$execution_mode, "canonical") ||
      !identical(profile_obj$provenance$execution_mode, "canonical")) {
    stop("[SCHEMA_INVARIANT_VIOLATION] provenance の execution_mode は 'canonical' でなければなりません。", call. = FALSE)
  }

  # 7. セル識別キー集合（row_level, col_level）の完全一致
  cells_results <- results_obj$cells
  cells_profile <- profile_obj$cells
  if (length(cells_results) != length(cells_profile)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル数が成果物間で不一致です (results: %d, profile: %d)。",
                 length(cells_results), length(cells_profile)), call. = FALSE)
  }

  keys_results <- sort(vapply(cells_results, function(c) paste(c$row_level, c$col_level, sep = ":::"), character(1)))
  keys_profile <- sort(vapply(cells_profile, function(c) paste(c$row_level, c$col_level, sep = ":::"), character(1)))
  if (!identical(keys_results, keys_profile)) {
    stop("[SCHEMA_INVARIANT_VIOLATION] セル識別キー集合（row_level, col_level）が成果物間で一致しません。", call. = FALSE)
  }

  invisible(TRUE)
}

#' Interface 3.0 準拠の categorical_results.json / evidence_profile.json および CSV エクスポート
#'
#' @param effect_result list compute_effect_evidence_metrics の出力
#' @param posterior_result list compute_dirichlet_posterior の出力
#' @param out_dir character(1) 出力先ディレクトリ
#' @param run_id character(1) run識別子
#' @param analysis_signature character(1) Canonical Analysis Signature (64桁 SHA-256)
#' @param input_sha256 character(1) 入力データのSHA-256 (64桁 SHA-256)
#' @param config_sha256 character(1) 設定ファイルのSHA-256 (64桁 SHA-256)
#' @param execution_mode character(1) 実行モード (既定 "canonical")
#' @return list 生成された完全な Interface 3.0 オブジェクト
#' @export
serialize_interface_v3 <- function(effect_result,
                                   posterior_result,
                                   out_dir,
                                   run_id = "default_run",
                                   analysis_signature = NULL,
                                   input_sha256 = NULL,
                                   config_sha256 = NULL,
                                   execution_mode = "canonical") {
  # 1. 実行モード境界の検証 (Canonical 専用)
  if (!identical(execution_mode, "canonical")) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] serialize_interface_v3 は canonical 実行専用です (指定値: %s)。",
                 as.character(execution_mode)), call. = FALSE)
  }

  # 2. 64桁 SHA-256 ハッシュの厳格検証 (フォールバック代替生成の禁止)
  sha_pattern <- "^[a-f0-9]{64}$"
  if (is.null(analysis_signature) || !grepl(sha_pattern, analysis_signature)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] analysis_signature は 64 桁の有効な SHA-256 文字列である必要があります (指定値: %s)。",
                 as.character(analysis_signature)), call. = FALSE)
  }
  if (is.null(input_sha256) || !grepl(sha_pattern, input_sha256)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] input_sha256 は 64 桁の有効な SHA-256 文字列である必要があります (指定値: %s)。",
                 as.character(input_sha256)), call. = FALSE)
  }
  if (is.null(config_sha256) || !grepl(sha_pattern, config_sha256)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] config_sha256 は 64 桁の有効な SHA-256 文字列である必要があります (指定値: %s)。",
                 as.character(config_sha256)), call. = FALSE)
  }

  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  glob <- effect_result$global
  cells_list <- effect_result$cells
  post_cells <- posterior_result$cell_posteriors

  # ============================================================
  # 不確実性ランキング (Uncertainty Ranking) の決定論的構築
  # 順序: prob_eti_width 降順 -> observed 昇順 -> row_level 昇順 -> col_level 昇順
  # ============================================================
  obs_map <- setNames(vapply(cells_list, function(c) c$observed, integer(1)),
                      vapply(cells_list, function(c) paste(c$row_level, c$col_level, sep = ":::"), character(1)))

  ranking_df <- do.call(rbind, lapply(post_cells, function(p) {
    key <- paste(p$row_level, p$col_level, sep = ":::")
    data.frame(
      row_level = p$row_level,
      col_level = p$col_level,
      prob_eti_width = p$prob_eti_width,
      observed = obs_map[[key]],
      stringsAsFactors = FALSE
    )
  }))

  ord <- order(-ranking_df$prob_eti_width,
               ranking_df$observed,
               ranking_df$row_level,
               ranking_df$col_level)
  ranking_df <- ranking_df[ord, , drop = FALSE]
  ranking_df$rank <- seq_len(nrow(ranking_df))

  uncertainty_ranking <- lapply(seq_len(nrow(ranking_df)), function(i) {
    list(
      rank = as.integer(ranking_df$rank[i]),
      row_level = ranking_df$row_level[i],
      col_level = ranking_df$col_level[i],
      prob_eti_width = ranking_df$prob_eti_width[i],
      observed = as.integer(ranking_df$observed[i])
    )
  })
  posterior_result$uncertainty_ranking <- uncertainty_ranking

  # ============================================================
  # 隔離セル総数と警告 (is_sensitive / 0.05 警告は完全廃止)
  # JSON Schema 適合のため、配列フィールドを AsIs (I()) で保護
  # ============================================================
  cells_list <- lapply(cells_list, function(c) {
    c$quarantine_reasons <- I(as.character(c$quarantine_reasons))
    c
  })

  quarantined_count <- sum(vapply(cells_list, function(c) c$quarantine_status == "QUARANTINED", logical(1)))
  warnings_vec <- character(0)
  if (quarantined_count > 0L) {
    warnings_vec <- c(warnings_vec, sprintf("検出された %d 個の隔離セル（ゼロ度数/期待度数<5/高レバレッジ）を大標本Dual-Filter候補から除外しました。", quarantined_count))
  }
  if (is.null(glob$cramers_v_corrected_ci)) {
    warnings_vec <- c(warnings_vec, "有効次元数またはサンプルサイズ不足のため、bias-corrected Cramér's V 信頼区間は算出不能（nullフォールバック）となりました。")
  }
  if (!isTRUE(glob$expected_count_diagnostics$cochran_satisfied)) {
    warnings_vec <- c(warnings_vec, "Cochran条件が未充足です（期待度数 < 5 のセルが20%超過、または < 1 のセルが存在）。漸近近似の信頼性に留意してください。")
  }

  quality_block <- list(
    n_quarantined_cells = quarantined_count,
    n_candidates = effect_result$n_candidates,
    warnings = I(as.character(warnings_vec))
  )

  # ============================================================
  # 拡張 Provenance 情報 (execution_mode: "canonical")
  # ============================================================
  platform_str <- paste(R.version$platform, R.version$version.string, sep = " / ")
  provenance_block <- list(
    run_id = run_id,
    execution_mode = execution_mode,
    analysis_signature = analysis_signature,
    input_sha256 = input_sha256,
    config_sha256 = config_sha256,
    deterministic_seed = posterior_result$deterministic_seed,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00"),
    r_version = R.version.string,
    platform = platform_str
  )

  # ============================================================
  # 完全な結果オブジェクト (categorical_results.json)
  # ============================================================
  results_v3 <- list(
    interface_version = "3.0",
    schema = "two-way-results-v2",
    analysis_signature = analysis_signature,
    `global` = glob,
    cells = cells_list,
    posterior = posterior_result,
    quality = quality_block,
    provenance = provenance_block
  )

  # ============================================================
  # 証拠プロファイル成果物 (evidence_profile.json)
  # ============================================================
  profile_cells <- lapply(cells_list, function(c) {
    list(
      row_level = c$row_level,
      col_level = c$col_level,
      observed = c$observed,
      expected = c$expected,
      pearson_res = c$pearson_res,
      log_oe = c$log_oe,
      score = c$score,
      phi_signed = c$phi_signed,
      quarantine_status = c$quarantine_status,
      dual_filter_candidate = c$dual_filter_candidate
    )
  })
  candidates_list <- cells_list[vapply(cells_list, function(c) isTRUE(c$dual_filter_candidate), logical(1))]

  profile_v1 <- list(
    interface_version = "3.0",
    schema = "evidence-profile-v1",
    analysis_signature = analysis_signature,
    provenance = provenance_block,
    summary = list(
      n_total = glob$sample_size,
      cramers_v = glob$cramers_v,
      cramers_v_corrected = glob$cramers_v_corrected,
      chi_square_stat = glob$chi_square_stat,
      p_value = glob$p_value,
      n_quarantined = quarantined_count,
      n_candidates = effect_result$n_candidates
    ),
    cells = profile_cells,
    candidates = candidates_list
  )

  # ============================================================
  # Cross-Field Invariant 検証（出力直前・fail-fast）
  # ============================================================
  test_inject <- Sys.getenv("VCD_TEST_INJECT_SCHEMA_INVARIANT_VIOLATION", unset = "")
  if (nzchar(test_inject)) {
    if (test_inject == "signature") {
      profile_v1$analysis_signature <- "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0"
    } else if (test_inject == "cells") {
      profile_v1$cells <- profile_v1$cells[-1]
    }
  }

  validate_cross_artifact_invariants(results_v3, profile_v1)

  # JSON 書き出し (categorical_results.json & evidence_profile.json)
  # digits = 8 で Engine 確定の 6桁/4桁の再丸め損失を完全に防止
  json_path <- file.path(out_dir, "categorical_results.json")
  json_text <- jsonlite::toJSON(results_v3, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = 8)
  writeLines(json_text, json_path, useBytes = TRUE)

  profile_path <- file.path(out_dir, "evidence_profile.json")
  profile_text <- jsonlite::toJSON(profile_v1, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = 8)
  writeLines(profile_text, profile_path, useBytes = TRUE)

  # CSV 書き出し (residuals_table.csv)
  res_df <- effect_result$cells_df
  post_df <- do.call(rbind, lapply(post_cells, function(p) {
    p_copy <- p
    if (is.null(p_copy$prob_practical_delta)) p_copy$prob_practical_delta <- NA_real_
    as.data.frame(p_copy, stringsAsFactors = FALSE)
  }))
  merged_csv <- merge(res_df, post_df, by = c("row_level", "col_level"), all.x = TRUE)
  csv_path <- file.path(out_dir, "residuals_table.csv")
  utils::write.csv(merged_csv, csv_path, row.names = FALSE, fileEncoding = "UTF-8")

  # 隔離セル CSV (quarantine_cells.csv)
  q_df <- merged_csv[merged_csv$quarantine_status == "QUARANTINED", , drop = FALSE]
  q_csv_path <- file.path(out_dir, "quarantine_cells.csv")
  utils::write.csv(q_df, q_csv_path, row.names = FALSE, fileEncoding = "UTF-8")

  return(results_v3)
}
