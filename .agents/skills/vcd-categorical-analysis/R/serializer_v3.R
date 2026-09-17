# serializer_v3.R — Interface 3.0 Serializer with Cross-Field Invariant & Extended Provenance

#' 成果物間の Cross-Field Invariant（スキーマ不変量）検証
#'
#' @param results_obj list categorical_results オブジェクト
#' @param profile_obj list evidence_profile オブジェクト
#' @return invisible(TRUE) 違反時は stop で即時 fail-fast
#' @export
validate_cross_artifact_invariants <- function(results_obj, profile_obj) {
  # 1. 確率総和の不変量 (sum(pi) == 1.0 +- 1e-4)
  post_cells <- results_obj$posterior$cell_posteriors
  if (!is.null(post_cells) && length(post_cells) > 0L) {
    prob_means <- vapply(post_cells, function(p) p$prob_mean, numeric(1))
    prob_sum <- sum(prob_means)
    if (abs(prob_sum - 1.0) > 1e-4) {
      stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] 事後平均結合確率の総和が1.0から乖離しています (実測値: %.6f)。", prob_sum), call. = FALSE)
    }

    # 2. 信用区間順序の不変量 (Q2.5 <= median <= Q97.5)
    for (k in seq_along(post_cells)) {
      p_item <- post_cells[[k]]
      q025 <- p_item$prob_q025
      q500 <- p_item$prob_q500
      q975 <- p_item$prob_q975
      if (!(q025 <= q500 && q500 <= q975)) {
        stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] セル (%s, %s) の信用区間順序が破綻しています (Q025: %.6f, Q500: %.6f, Q975: %.6f)。",
                     p_item$row_level, p_item$col_level, q025, q500, q975), call. = FALSE)
      }
    }
  }

  # 3. 成果物間 analysis_signature の一致
  sig_results <- results_obj$analysis_signature
  sig_profile <- profile_obj$analysis_signature
  if (is.null(sig_results) || is.null(sig_profile) || !identical(sig_results, sig_profile)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] analysis_signature が成果物間で不一致または未設定です (results: %s, profile: %s)。",
                 as.character(sig_results), as.character(sig_profile)), call. = FALSE)
  }

  # 4. 成果物間 run_id の一致
  run_results <- results_obj$provenance$run_id
  run_profile <- profile_obj$provenance$run_id
  if (is.null(run_results) || is.null(run_profile) || !identical(run_results, run_profile)) {
    stop(sprintf("[SCHEMA_INVARIANT_VIOLATION] run_id が成果物間で不一致または未設定です (results: %s, profile: %s)。",
                 as.character(run_results), as.character(run_profile)), call. = FALSE)
  }

  # 5. セル識別キー集合（row_level, col_level）の完全一致
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
#' @param analysis_signature character(1) Canonical Analysis Signature
#' @param input_sha256 character(1) 入力データのSHA-256
#' @param config_sha256 character(1) 設定ファイルのSHA-256
#' @return list 生成された完全な Interface 3.0 オブジェクト
#' @export
serialize_interface_v3 <- function(effect_result,
                                   posterior_result,
                                   out_dir,
                                   run_id = "default_run",
                                   analysis_signature = NULL,
                                   input_sha256 = NULL,
                                   config_sha256 = NULL) {
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  glob <- effect_result$global
  cells_list <- effect_result$cells
  post_cells <- posterior_result$cell_posteriors

  # ============================================================
  # 隔離セル総数と警告
  # ============================================================
  quarantined_count <- sum(vapply(cells_list, function(c) c$quarantine_status == "QUARANTINED", logical(1)))
  warnings_vec <- character(0)
  if (quarantined_count > 0L) {
    warnings_vec <- c(warnings_vec, sprintf("検出された %d 個の隔離セル（ゼロ度数/期待度数<5/高レバレッジ）を大標本Dual-Filter候補から除外しました。", quarantined_count))
  }
  if (is.null(glob$cramers_v_corrected_ci)) {
    warnings_vec <- c(warnings_vec, "有効次元数またはサンプルサイズ不足のため、bias-corrected Cramér's V 信頼区間は算出不能（nullフォールバック）となりました。")
  }
  if (isTRUE(posterior_result$sensitivity_analysis$is_sensitive)) {
    warnings_vec <- c(warnings_vec, "事前感度分析において主事前(alpha=1.0)と感度事前(alpha=0.5)の事後中央値差または平均差が0.05を超過しました。事前分布への感度に留意してください。")
  }
  if (!isTRUE(glob$expected_count_diagnostics$cochran_satisfied)) {
    warnings_vec <- c(warnings_vec, "Cochran条件が未充足です（期待度数 < 5 のセルが20%超過、または < 1 のセルが存在）。漸近近似の信頼性に留意してください。")
  }

  quality_block <- list(
    n_quarantined_cells = quarantined_count,
    n_candidates = effect_result$n_candidates,
    warnings = warnings_vec
  )

  # ============================================================
  # 拡張 Provenance 情報
  # ============================================================
  canonical_sig <- if (!is.null(analysis_signature)) {
    analysis_signature
  } else {
    digest::digest(list(glob, cells_list), algo = "sha256")
  }

  platform_str <- paste(R.version$platform, R.version$version.string, sep = " / ")
  provenance_block <- list(
    run_id = run_id,
    analysis_signature = canonical_sig,
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
    analysis_signature = canonical_sig,
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
    analysis_signature = canonical_sig,
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
  # テスト専用フック（通常運用時は不活性）
  test_inject <- Sys.getenv("VCD_TEST_INJECT_SCHEMA_INVARIANT_VIOLATION", unset = "")
  if (nzchar(test_inject)) {
    if (test_inject == "signature") {
      profile_v1$analysis_signature <- "tampered_signature_e2e"
    } else if (test_inject == "cells") {
      profile_v1$cells <- profile_v1$cells[-1]
    }
  }

  validate_cross_artifact_invariants(results_v3, profile_v1)

  # JSON 書き出し (categorical_results.json & evidence_profile.json)
  json_path <- file.path(out_dir, "categorical_results.json")
  json_text <- jsonlite::toJSON(results_v3, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  writeLines(json_text, json_path, useBytes = TRUE)

  profile_path <- file.path(out_dir, "evidence_profile.json")
  profile_text <- jsonlite::toJSON(profile_v1, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
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
