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

record_run_failure <- function(target_dir, error_code, message, is_root = FALSE, execution_mode = "canonical") {
  if (!is.null(target_dir)) {
    if (!dir.exists(target_dir)) {
      tryCatch(dir.create(target_dir, recursive = TRUE, showWarnings = FALSE), error = function(e) {})
    }
    if (dir.exists(target_dir)) {
      state_file <- file.path(target_dir, "run_state.json")
      payload <- list(
        status = "failed",
        error_code = error_code,
        message = message,
        execution_mode = execution_mode,
        provenance_status = "failed",
        phase = if (is_root) "gateway" else "execution",
        run_id = if (is_root) NULL else basename(target_dir),
        analysis_signature = NULL,
        timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
      )
      tryCatch(
        writeLines(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, null = "null"), state_file),
        error = function(e) {}
      )
    }
  }
  stop(sprintf("[%s] %s", error_code, message), call. = FALSE)
}

# Canonical CLI ホワイトリスト
CANONICAL_CLI_WHITELIST <- c("--config", "--out", "--label", "--help", "-h")

validate_canonical_cli_args <- function(args_vec, out_root) {
  arg_names <- args_vec[grepl("^-", args_vec)]
  unknown_or_forbidden <- setdiff(arg_names, CANONICAL_CLI_WHITELIST)
  if (length(unknown_or_forbidden) > 0L) {
    err_msg <- sprintf(
      "Canonical実行ではPass 0確定設定のCLI上書きおよび未知引数は禁止されています（完全ホワイトリスト方式）。検出された禁止引数: %s",
      paste(unknown_or_forbidden, collapse = ", ")
    )
    record_run_failure(out_root, "CANONICAL_CONFIG_OVERRIDE_FORBIDDEN", err_msg, is_root = TRUE)
  }
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

# ============================================================
# Core Execution Engine (2層分離: run_categorical_analysis_core)
# ============================================================
run_categorical_analysis_core <- function(
  config_data,
  config_path = NULL,
  out_root = "./evidence_runs/vcd_categorical",
  data_label = "two_way_analysis",
  execution_mode = "canonical"
) {
  if (!execution_mode %in% c("canonical", "development")) {
    stop(sprintf("[INVALID_EXECUTION_MODE] execution_mode は 'canonical' または 'development' である必要があります (指定値: %s)", execution_mode), call. = FALSE)
  }

  # ------------------------------------------------------------
  # DEVELOPMENT モード: インメモリ専用（成果物・run_<sig> 未作成）
  # ------------------------------------------------------------
  if (identical(execution_mode, "development")) {
    vars <- if (!is.null(config_data$vars)) unlist(config_data$vars) else NULL
    freq_col <- if (!is.null(config_data$freq)) as.character(config_data$freq) else NULL
    input_mode <- if (!is.null(config_data$input_mode)) as.character(config_data$input_mode) else NULL
    practical_delta <- if (!is.null(config_data$practical_delta)) as.numeric(config_data$practical_delta) else NULL

    raw_df <- if (is.data.frame(config_data$input)) {
      config_data$input
    } else if (is.character(config_data$input) && file.exists(config_data$input)) {
      utils::read.csv(config_data$input, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
      stop("[DEV_INPUT_ERROR] 有効なデータフレームまたはCSVパスを指定してください", call. = FALSE)
    }

    agg_df <- validate_input_table(
      data = raw_df,
      vars = vars,
      freq = freq_col,
      input_mode = input_mode,
      run_dir = NULL
    )
    diag_res <- compute_residual_diagnostics(agg_df)
    evid_res <- compute_effect_evidence_metrics(diag_res)
    post_res <- compute_dirichlet_posterior(
      diag_res,
      alpha = 0.5,
      n_draws = 10000L,
      analysis_signature = "development_in_memory_only",
      practical_delta = practical_delta
    )
    return(list(
      execution_mode = "development",
      agg_df = agg_df,
      diag_res = diag_res,
      evid_res = evid_res,
      post_res = post_res
    ))
  }

  # ------------------------------------------------------------
  # CANONICAL モード: Core 内部での独立三者 SHA 再検証
  # ------------------------------------------------------------
  # 呼び出し元フラグを盲信せず偽造 attestation を遮断
  if (isTRUE(config_data$mock_verified) || isTRUE(config_data$bypass_provenance)) {
    record_run_failure(
      out_root,
      "CANONICAL_CONFIG_VERIFICATION_REQUIRED",
      "偽造 attestation フラグまたは無検証バイパスフラグが検出されました。Canonical Core は独立再検証を強制します。",
      is_root = TRUE
    )
  }

  if (is.null(config_data$pass0_provenance)) {
    record_run_failure(
      out_root,
      "MISSING_PASS0_PROVENANCE",
      "analysis_config.json に pass0_provenance ブロックが存在しません。Pass 0 を完了してください。",
      is_root = TRUE
    )
  }

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
      record_run_failure(out_root, code, err_msg, is_root = TRUE)
    }
  )

  data_path <- provenance_check$input_path
  vars <- if (!is.null(config_data$vars)) unlist(config_data$vars) else NULL
  freq_col <- if (!is.null(config_data$freq)) as.character(config_data$freq) else NULL
  input_mode <- if (!is.null(config_data$input_mode)) as.character(config_data$input_mode) else NULL
  practical_delta <- if (!is.null(config_data$practical_delta)) as.numeric(config_data$practical_delta) else NULL

  # input_mode の厳格な即時検証（署名・ディレクトリ作成の前！）
  if (is.null(input_mode) || is.na(input_mode) || !nzchar(trimws(input_mode)) ||
      !input_mode %in% c("aggregated", "individual")) {
    record_run_failure(
      out_root,
      "INVALID_INPUT_MODE",
      sprintf("input_mode は 'aggregated' または 'individual' である必要があります (指定値: %s)。暗黙の既定値投入は禁止されています。",
              if (is.null(input_mode)) "NULL (未指定)" else as.character(input_mode)),
      is_root = TRUE
    )
  }

  # input_mode に応じた freq 列指定の厳格検証
  if (identical(input_mode, "aggregated")) {
    if (is.null(freq_col) || is.na(freq_col) || !nzchar(trimws(freq_col))) {
      record_run_failure(
        out_root,
        "MISSING_FREQUENCY_COLUMN",
        "input_mode が 'aggregated' の場合、頻度列（freq）の指定が必須です。",
        is_root = TRUE
      )
    }
  } else if (identical(input_mode, "individual")) {
    if (!is.null(freq_col) && nzchar(trimws(freq_col))) {
      record_run_failure(
        out_root,
        "FREQUENCY_COLUMN_NOT_PERMITTED",
        sprintf("input_mode が 'individual' の場合、頻度列（freq）の指定は禁止されています（指定値: %s）。", freq_col),
        is_root = TRUE
      )
    }
  }

  # 2変数分割表専用の厳格な検証
  if (is.null(vars) || length(vars) != 2L) {
    record_run_failure(
      out_root,
      "INVALID_INPUT_ARITY",
      sprintf("vcd-categorical-analysis は2変数分割表専用です（指定変数数: %d）。3次元以上の解析は正本スキル vcd-bayesian-evidence-analysis を使用してください。",
              if (is.null(vars)) 0L else length(vars)),
      is_root = TRUE
    )
  }

  # 設定の正規化ダイジェスト（canonical_config_sha256）の計算と封緘照合（Config Provenance Binding）
  canonical_config_sha256 <- compute_canonical_config_sha256(
    vars = vars,
    freq = freq_col,
    input_mode = input_mode,
    prior_alpha = 0.5,
    practical_delta = practical_delta
  )

  # 1. analysis_config.json 内部の自己記録値との照合
  provenance_canonical_sha <- config_data$pass0_provenance$canonical_config_sha256
  if (is.null(provenance_canonical_sha) || !identical(as.character(provenance_canonical_sha), canonical_config_sha256)) {
    err_msg <- if (is.null(provenance_canonical_sha)) {
      "pass0_provenance に canonical_config_sha256 が記録されていません（未束縛設定）。Pass 0 を再実行して設定を確定してください。"
    } else {
      sprintf(
        "設定ファイル内の解析パラメータ（vars, freq, input_mode, practical_delta 等）が Pass 0 確定時の封緘ハッシュと一致しません。事後改ざんが検出されました。(期待値: %s, 実測値: %s)",
        provenance_canonical_sha, canonical_config_sha256
      )
    }
    record_run_failure(out_root, "PROVENANCE_CONFIG_MISMATCH", err_msg, is_root = TRUE)
  }

  # 2. 改ざん防止された Pass 0 検分成果物 (inspection_results.json) 内の承認値との外部アンカー照合
  approved_canonical_sha <- provenance_check$inspection$approved_config$canonical_config_sha256
  if (is.null(approved_canonical_sha) || !identical(as.character(approved_canonical_sha), canonical_config_sha256)) {
    err_msg <- if (is.null(approved_canonical_sha)) {
      "Pass 0 検分成果物 (inspection_results.json) に approved_config$canonical_config_sha256 が記録されていません。Pass 0 を再実行して設定を確定してください。"
    } else {
      sprintf(
        "設定ファイル内の解析パラメータが Pass 0 検分成果物の承認ダイジェストと一致しません。事後改ざんが検出されました。(Pass0承認値: %s, 実設定計算値: %s)",
        approved_canonical_sha, canonical_config_sha256
      )
    }
    record_run_failure(out_root, "PROVENANCE_CONFIG_MISMATCH", err_msg, is_root = TRUE)
  }

  if (!file.exists(data_path)) {
    record_run_failure(out_root, "MISSING_INPUT_FILE", sprintf("入力データファイルが見つかりません: %s", data_path), is_root = TRUE)
  }

  input_sha <- pass0_sha256_file(data_path)
  if (!identical(input_sha, config_data$pass0_provenance$input_sha256)) {
    record_run_failure(out_root, "PROVENANCE_SHA_MISMATCH",
                       "実入力ファイルのSHA-256がPass 0記録と一致しません。", is_root = TRUE)
  }

  config_file_sha256 <- if (!is.null(config_path) && file.exists(config_path)) {
    pass0_sha256_file(config_path)
  } else {
    digest::digest(config_data, algo = "sha256")
  }

  # 単一決定論的解析署名（Canonical Analysis Signature）の算出
  # 成果物名に反映される data_label を算入して同一設定・異なるlabelのディレクトリ完全分離を保証
  sig_payload <- list(
    engine_version = "4.1",
    input_sha256 = input_sha,
    config_sha256 = canonical_config_sha256,
    vars = unname(as.character(vars)),
    freq = if (is.null(freq_col)) "" else as.character(freq_col),
    input_mode = as.character(input_mode),
    prior_alpha = 0.5,
    data_label = as.character(data_label)
  )
  analysis_signature <- digest::digest(sig_payload, algo = "sha256")
  prefix16 <- substr(analysis_signature, 1L, 16L)
  run_output_dir <- reserve_run_output_dir(out_root, "vcd-categorical-analysis", prefix16)
  run_id <- basename(run_output_dir)

  # 同一署名・同一出力 root の原子的排他ロック (Atomic Lock)
  lock_dir <- file.path(run_output_dir, ".run_lock")
  acquired_lock <- dir.create(lock_dir, showWarnings = FALSE)
  if (!acquired_lock) {
    record_run_failure(
      out_root,
      "CONCURRENT_RUN_IN_PROGRESS",
      sprintf("同一解析署名 (%s) の実行が既に進行中です。並行競合および成果物破壊を防ぐため即時停止します。", analysis_signature),
      is_root = TRUE
    )
  }
  base::on.exit({
    if (dir.exists(lock_dir)) {
      unlink(lock_dir, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)


  state_file <- file.path(run_output_dir, "run_state.json")
  run_state_payload <- list(
    status = "running",
    run_id = run_id,
    analysis_signature = analysis_signature,
    execution_mode = "canonical",
    provenance_status = "verified",
    input_sha256 = input_sha,
    config_file_sha256 = config_file_sha256,
    canonical_config_sha256 = canonical_config_sha256,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
  )
  writeLines(jsonlite::toJSON(run_state_payload, auto_unbox = TRUE, pretty = TRUE), state_file)

  raw_df <- tryCatch(
    utils::read.csv(data_path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      record_run_failure(run_output_dir, "CANNOT_READ_INPUT_CSV", conditionMessage(e))
    }
  )

  agg_df <- tryCatch(
    validate_input_table(
      data = raw_df,
      vars = vars,
      freq = freq_col,
      input_mode = input_mode,
      run_dir = run_output_dir
    ),
    error = function(e) {
      stop(e)
    }
  )

  message("[INFO] 入力検証完了: 総度数 N = ", attr(agg_df, "n_total"), " (", vars[1], " x ", vars[2], ")")

  diag_res <- compute_residual_diagnostics(agg_df)
  evid_res <- compute_effect_evidence_metrics(diag_res)
  post_res <- compute_dirichlet_posterior(
    diag_res,
    alpha = 0.5,
    n_draws = 10000L,
    analysis_signature = analysis_signature,
    practical_delta = practical_delta
  )

  results_v3 <- tryCatch(
    serialize_interface_v3(
      effect_result = evid_res,
      posterior_result = post_res,
      out_dir = run_output_dir,
      run_id = run_id,
      analysis_signature = analysis_signature,
      input_sha256 = input_sha,
      config_sha256 = canonical_config_sha256,
      execution_mode = "canonical"
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

  generate_gt_matrix(evid_res$cells_df, vars, freq_col, run_output_dir, data_label)
  generate_dt_table(evid_res$cells_df, vars, run_output_dir, data_label)

  artifacts_list <- c(
    "categorical_results.json",
    "evidence_profile.json",
    "residuals_table.csv",
    "quarantine_cells.csv",
    paste0("gt_residuals_", data_label, ".html"),
    paste0("dt_residuals_", data_label, ".html")
  )
  completed_state <- list(
    status = "completed",
    run_id = run_id,
    analysis_signature = analysis_signature,
    execution_mode = "canonical",
    provenance_status = "verified",
    input_sha256 = input_sha,
    config_file_sha256 = config_file_sha256,
    canonical_config_sha256 = canonical_config_sha256,
    artifacts = artifacts_list,
    timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
  )
  writeLines(jsonlite::toJSON(completed_state, auto_unbox = TRUE, pretty = TRUE), state_file)
  message("[SUCCESS] vcd-categorical-analysis v4.1 完了: ", run_output_dir)
  invisible(results_v3)
}

# ============================================================
# Main Execution Gateway (run_analysis)
# ============================================================
run_analysis <- function(args_vec = commandArgs(trailingOnly = TRUE)) {
  out_root <- get_arg_val(args_vec, "--out", "./evidence_runs/vcd_categorical")
  data_label <- get_arg_val(args_vec, "--label", "two_way_analysis")

  # 1. Canonical CLI ホワイトリスト検証
  validate_canonical_cli_args(args_vec, out_root)

  if ("--help" %in% args_vec || "-h" %in% args_vec) {
    cat("Usage: Rscript analysis.R --config <analysis_config.json> [--out <dir>] [--label <name>]\n")
    return(invisible(NULL))
  }

  config_path <- get_arg_val(args_vec, "--config")
  if (is.null(config_path) || !file.exists(config_path)) {
    record_run_failure(
      out_root,
      "MISSING_REQUIRED_CONFIG",
      "vcd-categorical-analysis v4.1 では analysis_config.json の指定（--config <path>）が必須です。Pass 0 (vcd-pass0-consultation) を完了して設定を作成してください。",
      is_root = TRUE
    )
  }

  config_data <- tryCatch(
    jsonlite::read_json(config_path, simplifyVector = FALSE),
    error = function(e) {
      record_run_failure(out_root, "INVALID_CONFIG_JSON", paste0("analysis_config.json の読み込みに失敗しました: ", conditionMessage(e)), is_root = TRUE)
    }
  )

  run_categorical_analysis_core(
    config_data = config_data,
    config_path = config_path,
    out_root = out_root,
    data_label = data_label,
    execution_mode = "canonical"
  )
}

if (!source_only) {
  run_analysis()
}
