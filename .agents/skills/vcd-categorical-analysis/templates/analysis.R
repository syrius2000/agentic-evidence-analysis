# analysis.R — Complete 2-Way Categorical Analysis Pipeline (v4.1 Repair & Contract Hardening)
# Strict 2-Way Nominal Contingency Table Engine with Fail-Fast Gateway, Pass 0 Provenance & Interface 3.0

find_agent_repo <- function() {
  d <- base::normalizePath(base::getwd(), winslash = "/", mustWork = FALSE)
  for (i in base::seq_len(20L)) {
    p <- base::file.path(d, ".agents", "shared", "run_scope.R")
    if (base::file.exists(p)) {
      return(d)
    }
    parent <- base::dirname(d)
    if (parent == d) break
    d <- parent
  }
  base::getwd()
}
repo_root <- find_agent_repo()

# 共有モジュールおよび内部モジュールの読み込み
base::source(base::file.path(repo_root, ".agents", "shared", "dependency_check.R"))
base::source(base::file.path(repo_root, ".agents", "shared", "run_scope.R"))
base::source(base::file.path(repo_root, ".agents", "shared", "pass0_contract.R"))
base::source(base::file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "validate_input.R"))
base::source(base::file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "residual_diagnostics.R"))
base::source(base::file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "effect_evidence_metrics.R"))
base::source(base::file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "dirichlet_posterior.R"))
base::source(base::file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "serializer_v3.R"))

source_only <- isTRUE(base::getOption("vcd_categorical.source_only", FALSE))

if (!source_only) {
  check_r_dependencies(
    c("vcd", "gt", "DT", "htmlwidgets", "ggplot2", "jsonlite", "digest"),
    context = "vcd-categorical-analysis v4.1"
  )
} else {
  check_r_dependencies(c("jsonlite", "digest"), context = "vcd-categorical-analysis source_only ロジック読込")
}

# 引数取得ヘルパー
get_arg_val <- function(args_vec, arg_name, default = NULL) {
  if (arg_name %in% args_vec) {
    idx <- base::which(args_vec == arg_name)
    if (idx < base::length(args_vec)) {
      return(args_vec[idx + 1L])
    }
  }
  return(default)
}

record_run_failure <- function(run_dir, error_code, message) {
  if (!is.null(run_dir)) {
    if (!dir.exists(run_dir)) {
      tryCatch(dir.create(run_dir, recursive = TRUE, showWarnings = FALSE), error = function(e) {})
    }
    if (dir.exists(run_dir)) {
      state_file <- file.path(run_dir, "run_state.json")
      payload <- list(
        status = "failed",
        error_code = error_code,
        message = message,
        timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
      )
      tryCatch(writeLines(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE), state_file), error = function(e) {})
    }
  }
  stop(sprintf("[%s] %s", error_code, message), call. = FALSE)
}

# ============================================================
# 可視化・テーブル生成ヘルパー (2-way 専用)
# ============================================================
generate_gt_matrix <- function(cells_df, vars, freq_col, output_dir, data_label) {
  v1 <- vars[1]
  v2 <- vars[2]
  sub_df <- cells_df[!is.na(cells_df$observed), , drop = FALSE]
  if (nrow(sub_df) == 0L) return()

  u1 <- sort(unique(sub_df$row_level))
  u2 <- sort(unique(sub_df$col_level))
  mat <- matrix("", nrow = length(u1), ncol = length(u2), dimnames = list(u1, u2))

  for (k in seq_len(nrow(sub_df))) {
    r <- sub_df$row_level[k]
    c <- sub_df$col_level[k]
    o_val <- sub_df$observed[k]
    res_val <- sub_df$pearson_res[k]
    q_mark <- if (sub_df$quarantine_status[k] == "QUARANTINED") " [Q]" else ""
    mat[r, c] <- sprintf("%d (r=%.2f)%s", o_val, res_val, q_mark)
  }

  mat_df <- as.data.frame(mat, stringsAsFactors = FALSE)
  mat_df <- cbind(setNames(data.frame(u1, stringsAsFactors = FALSE), v1), mat_df)

  gt_tbl <- gt::gt(mat_df) |>
    gt::tab_header(
      title = paste("Contingency Matrix (Observed & Pearson Residuals):", data_label),
      subtitle = paste(v1, "x", v2)
    )

  fname <- paste0("gt_residuals_", data_label, ".html")
  gt::gtsave(gt_tbl, file.path(output_dir, fname))
  message("[GT] ", fname)
}

generate_dt_table <- function(cells_df, vars, output_dir, data_label) {
  dt_df <- cells_df
  dt_df$abs_pearson_res <- abs(dt_df$pearson_res)
  mx <- max(dt_df$abs_pearson_res, na.rm = TRUE)
  if (!is.finite(mx) || mx < 1e-12) mx <- 1.0

  brks <- seq(-mx, mx, length.out = 100)
  clrs <- grDevices::colorRampPalette(c("#D73027", "#FFFFFF", "#4575B4"))(100)

  widget <- DT::datatable(dt_df,
    filter = "top",
    options = list(
      pageLength = 25,
      order = list(list(which(names(dt_df) == "abs_pearson_res") - 1L, "desc")),
      dom = "lftipr"
    ),
    caption = paste("Cell Residual Diagnostics:", data_label)
  ) |>
    DT::formatRound(columns = c("pearson_res", "abs_pearson_res", "rao_score"), digits = 3) |>
    DT::formatStyle("pearson_res", backgroundColor = DT::styleInterval(brks[-1], clrs))

  fname <- paste0("dt_residuals_", data_label, ".html")
  htmlwidgets::saveWidget(widget, file.path(normalizePath(output_dir), fname), selfcontained = TRUE)
  message("[DT] ", fname)
}

generate_plots <- function(agg_df, vars, output_dir, data_label) {
  v1 <- vars[1]
  v2 <- vars[2]
  tab <- stats::xtabs(Freq ~ ., data = agg_df[, c(v1, v2, "Freq")])

  png_mosaic <- file.path(output_dir, paste0("mosaic_", data_label, ".png"))
  grDevices::png(png_mosaic, width = 1000, height = 800)
  vcd::mosaic(tab, shade = TRUE, main = paste("Mosaic Plot:", v1, "x", v2))
  grDevices::dev.off()

  png_assoc <- file.path(output_dir, paste0("assoc_", data_label, ".png"))
  grDevices::png(png_assoc, width = 1000, height = 800)
  vcd::assoc(tab, residuals_type = "Pearson", shade = TRUE, main = paste("Association Plot:", v1, "x", v2))
  grDevices::dev.off()

  message("[PLOTS] PNG files written: ", png_mosaic, ", ", png_assoc)
}

# ============================================================
# Main Execution Pipeline
# ============================================================
run_analysis <- function(args_vec = commandArgs(trailingOnly = TRUE)) {
  config_path <- get_arg_val(args_vec, "--config")
  out_root <- get_arg_val(args_vec, "--out", "./skill_out/vcd_categorical")
  data_label <- get_arg_val(args_vec, "--label", "two_way_analysis")

  # 1. Pass 0 設定ファイル（analysis_config.json）必須契約
  if (is.null(config_path) || !file.exists(config_path)) {
    record_run_failure(
      out_root,
      "MISSING_REQUIRED_CONFIG",
      "vcd-categorical-analysis v4.1 では analysis_config.json の指定（--config <path>）が必須です。Pass 0 (vcd-pass0-consultation) を完了して設定を作成してください。"
    )
  }

  config_data <- tryCatch(
    jsonlite::read_json(config_path, simplifyVector = FALSE),
    error = function(e) {
      record_run_failure(out_root, "INVALID_CONFIG_JSON", paste0("analysis_config.json の読み込みに失敗しました: ", conditionMessage(e)))
    }
  )

  # 2. Pass 0 由来の先行検証 (pass0_contract.R)
  provenance_check <- tryCatch(
    validate_pass0_provenance(config_data, config_path, expected_skill = "vcd-categorical-analysis", repo_root = repo_root),
    error = function(e) {
      err_msg <- conditionMessage(e)
      code <- if (grepl("対象スキルが一致しません", err_msg)) {
        "TARGET_SKILL_MISMATCH"
      } else if (grepl("SHA-256|変更されています", err_msg)) {
        "PROVENANCE_SHA_MISMATCH"
      } else {
        "PASS0_VALIDATION_FAILED"
      }
      record_run_failure(out_root, code, err_msg)
    }
  )

  # 設定の抽出
  data_path <- provenance_check$input_path
  vars <- if (!is.null(config_data$vars)) unlist(config_data$vars) else NULL
  freq_col <- if (!is.null(config_data$freq)) as.character(config_data$freq) else NULL
  input_mode <- if (!is.null(config_data$input_mode)) as.character(config_data$input_mode) else NULL
  practical_delta <- if (!is.null(config_data$practical_delta)) as.numeric(config_data$practical_delta) else NULL

  # CLI による上書きの反映（存在する場合）
  data_path_cli <- get_arg_val(args_vec, "--data")
  if (!is.null(data_path_cli)) data_path <- data_path_cli
  vars_cli <- get_arg_val(args_vec, "--vars")
  if (!is.null(vars_cli)) vars <- trimws(unlist(strsplit(vars_cli, ",")))
  freq_cli <- get_arg_val(args_vec, "--freq")
  if (!is.null(freq_cli)) freq_col <- freq_cli
  mode_cli <- get_arg_val(args_vec, "--input-mode")
  if (!is.null(mode_cli)) input_mode <- mode_cli

  input_sha <- pass0_sha256_file(data_path)
  config_sha <- pass0_sha256_file(config_path)

  # 3. 単一決定論的解析署名（Canonical Analysis Signature）の算出
  sig_payload <- list(
    engine_version = "4.1",
    input_sha256 = input_sha,
    config_sha256 = config_sha,
    vars = unname(as.character(vars)),
    freq = if (is.null(freq_col)) "" else as.character(freq_col),
    input_mode = if (is.null(input_mode)) "" else as.character(input_mode),
    prior_alpha = 1.0
  )
  analysis_signature <- digest::digest(sig_payload, algo = "sha256")
  prefix16 <- substr(analysis_signature, 1L, 16L)
  run_id <- paste0("run_", prefix16)
  run_output_dir <- file.path(out_root, run_id)

  if (!dir.exists(run_output_dir)) {
    dir.create(run_output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # run_state.json 開始記録
  state_file <- file.path(run_output_dir, "run_state.json")
  run_state_payload <- list(
    status = "running",
    run_id = run_id,
    analysis_signature = analysis_signature,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
  )
  writeLines(jsonlite::toJSON(run_state_payload, auto_unbox = TRUE, pretty = TRUE), state_file)

  # input_mode の厳格な即時検証（集約・生データ読み込み・モデリング前）
  if (is.null(input_mode) || is.na(input_mode) || !nzchar(trimws(input_mode)) ||
      !input_mode %in% c("aggregated", "individual")) {
    record_run_failure(
      run_output_dir,
      "INVALID_INPUT_MODE",
      sprintf("input_mode は 'aggregated' または 'individual' である必要があります (指定値: %s)。暗黙の既定値投入は禁止されています。",
              if (is.null(input_mode)) "NULL (未指定)" else as.character(input_mode))
    )
  }

  # 4. データの生読み込み
  raw_df <- tryCatch(
    utils::read.csv(data_path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      record_run_failure(run_output_dir, "CANNOT_READ_INPUT_CSV", conditionMessage(e))
    }
  )

  # 5. データ集約・モデリングに先行する入力境界検証（Fail-Fast）
  agg_df <- tryCatch(
    validate_input_table(
      data = raw_df,
      vars = vars,
      freq = freq_col,
      input_mode = input_mode,
      run_dir = run_output_dir
    ),
    error = function(e) {
      # validate_input_table 内部ですでに run_state.json を記録している
      stop(e)
    }
  )

  message("[INFO] 入力検証完了: 総度数 N = ", attr(agg_df, "n_total"), " (", vars[1], " x ", vars[2], ")")

  # 6. 2-way 専任統計パイプライン実行
  # (1) 残差診断 & Quarantine 判定 & 期待度数診断
  diag_res <- compute_residual_diagnostics(agg_df)

  # (2) 効果量 & 局所証拠 & 大標本 Dual-Filter
  evid_res <- compute_effect_evidence_metrics(diag_res)

  # (3) 多項 Dirichlet 事後推論 (10,000 draws, 決定論的シード)
  post_res <- compute_dirichlet_posterior(
    diag_res,
    alpha = 1.0,
    n_draws = 10000L,
    analysis_signature = analysis_signature,
    practical_delta = practical_delta
  )

  # (4) 成果物 JSON (Interface 3.0) & CSV シリアライズ (Cross-Field Invariant 検証付き)
  results_v3 <- tryCatch(
    serialize_interface_v3(
      effect_result = evid_res,
      posterior_result = post_res,
      out_dir = run_output_dir,
      run_id = run_id,
      analysis_signature = analysis_signature,
      input_sha256 = input_sha,
      config_sha256 = config_sha
    ),
    error = function(e) {
      err_msg <- conditionMessage(e)
      code <- if (grepl("SCHEMA_INVARIANT_VIOLATION", err_msg)) {
        "SCHEMA_INVARIANT_VIOLATION"
      } else {
        "SERIALIZATION_FAILED"
      }
      record_run_failure(run_output_dir, code, err_msg)
    }
  )

  # (5) GTマトリクス & DTテーブル & Mosaic/Assoc プロット出力
  generate_gt_matrix(evid_res$cells_df, vars, freq_col, run_output_dir, data_label)
  generate_dt_table(evid_res$cells_df, vars, run_output_dir, data_label)
  generate_plots(agg_df, vars, run_output_dir, data_label)

  # 7. run_state.json 正常完了記録
  artifacts_list <- c(
    "categorical_results.json",
    "evidence_profile.json",
    "residuals_table.csv",
    "quarantine_cells.csv",
    paste0("gt_residuals_", data_label, ".html"),
    paste0("dt_residuals_", data_label, ".html"),
    paste0("mosaic_", data_label, ".png"),
    paste0("assoc_", data_label, ".png")
  )
  completed_state <- list(
    status = "completed",
    run_id = run_id,
    analysis_signature = analysis_signature,
    artifacts = artifacts_list,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
  )
  writeLines(jsonlite::toJSON(completed_state, auto_unbox = TRUE, pretty = TRUE), state_file)
  message("[SUCCESS] vcd-categorical-analysis v4.1 完了: ", run_output_dir)
  invisible(results_v3)
}

if (!source_only) {
  run_analysis()
}
