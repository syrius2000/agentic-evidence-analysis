# serializer_v3.R — Interface 3.0 Serializer (categorical_results.json & CSVs)

#' Interface 3.0 準拠の categorical_results.json および CSV エクスポート
#'
#' @param effect_result list compute_effect_evidence_metrics の出力
#' @param posterior_result list compute_dirichlet_posterior の出力
#' @param out_dir character(1) 出力先ディレクトリ
#' @param run_id character(1) run識別子
#' @return list 生成された完全な Interface 3.0 オブジェクト
#' @export
serialize_interface_v3 <- function(effect_result,
                                   posterior_result,
                                   out_dir,
                                   run_id = "default_run") {
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  glob <- effect_result$global
  cells_list <- effect_result$cells
  post_cells <- posterior_result$cell_posteriors

  # 1. 隔離セル総数と警告
  quarantined_count <- sum(sapply(cells_list, function(c) c$quarantine_status == "QUARANTINED"))
  warnings_vec <- character(0)
  if (quarantined_count > 0) {
    warnings_vec <- c(warnings_vec, sprintf("検出された %d 個の隔離セル（ゼロ度数/期待度数<5/高レバレッジ）を大標本Dual-Filter候補から除外しました。", quarantined_count))
  }
  if (is.null(glob$cramers_v_corrected_ci)) {
    warnings_vec <- c(warnings_vec, "有効次元数またはサンプルサイズ不足のため、bias-corrected Cramér's V 信頼区間は算出不能（nullフォールバック）となりました。")
  }
  if (isTRUE(posterior_result$sensitivity$is_sensitive)) {
    warnings_vec <- c(warnings_vec, "事前感度分析において主事前(alpha=1.0)と感度事前(alpha=0.5)の事後平均差が0.05を超過しました。事前分布への感度に留意してください。")
  }

  quality_block <- list(
    n_quarantined_cells = quarantined_count,
    n_candidates = effect_result$n_candidates,
    warnings = warnings_vec
  )

  # 2. プロビナンス情報
  platform_str <- paste(R.version$platform, R.version$version.string, sep = " / ")
  provenance_block <- list(
    run_id = run_id,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00"),
    r_version = R.version.string,
    platform = platform_str
  )

  # 3. 完全な結果オブジェクト
  results_v3 <- list(
    interface_version = "3.0",
    schema = "two-way-results-v2",
    analysis_signature = digest::digest(list(glob, cells_list), algo = "sha256"),
    `global` = glob,
    cells = cells_list,
    posterior = posterior_result,
    quality = quality_block,
    provenance = provenance_block
  )

  # JSON 書き出し
  json_path <- file.path(out_dir, "categorical_results.json")
  json_text <- jsonlite::toJSON(results_v3, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
  writeLines(json_text, json_path, useBytes = TRUE)

  # CSV 書き出し (residuals_table.csv)
  res_df <- effect_result$cells_df
  # 事後統計量とのマージ
  post_df <- do.call(rbind, lapply(post_cells, function(p) {
    as.data.frame(p, stringsAsFactors = FALSE)
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
