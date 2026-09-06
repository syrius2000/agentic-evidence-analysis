#!/usr/bin/env Rscript
# tests/statistical_foundations/validate_config.R
# 3次元統計基盤検証のための設定・入力契約検証スクリプト

suppressPackageStartupMessages({
  library(jsonlite)
  library(readr)
  library(dplyr)
})

# 定義されている許可キー一覧（未知キー検出用）
ALLOWED_TOP_KEYS <- c(
  "schema_version", "input", "vars", "freq", "response_var",
  "output_dir", "run_id", "sampling", "levels", "missing_policy",
  "absent_cell_policy", "structural_zeros", "filters", "model_ids",
  "prior", "reference_tolerance", "seed"
)

ALLOWED_SAMPLING_KEYS <- c(
  "unit", "total_n_meaning", "independence_assumption", "is_scaled",
  "scaling_factor", "lineage"
)

ALLOWED_FILTER_OPS <- c("==", "in")

validate_config_file <- function(config_path, silent = FALSE) {
  errors <- character(0)
  holds <- character(0)
  warnings <- character(0)
  
  if (!file.exists(config_path)) {
    return(list(valid = FALSE, status = "ERROR", errors = paste("設定ファイルが存在しません:", config_path)))
  }
  
  # 1. JSONパース
  cfg <- tryCatch({
    fromJSON(config_path, simplifyVector = FALSE)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(cfg)) {
    return(list(valid = FALSE, status = "ERROR", errors = "JSONの解析に失敗しました（構文不正）"))
  }
  
  # 2. 未知キーの検査（additionalProperties: false）
  top_keys <- names(cfg)
  unknown_top <- setdiff(top_keys, ALLOWED_TOP_KEYS)
  if (length(unknown_top) > 0) {
    errors <- c(errors, sprintf("未知のトップレベルキーを拒否しました: %s", paste(unknown_top, collapse = ", ")))
  }
  
  # 3. 必須キー検査
  req_keys <- c("schema_version", "input", "vars", "freq", "output_dir", "run_id", "sampling")
  missing_req <- setdiff(req_keys, top_keys)
  if (length(missing_req) > 0) {
    errors <- c(errors, sprintf("必須キーが不足しています: %s", paste(missing_req, collapse = ", ")))
  }
  
  # schema_version
  if (!identical(cfg$schema_version, "3way-foundation-v1")) {
    errors <- c(errors, sprintf("無効なschema_version: %s (期待値: '3way-foundation-v1')", as.character(cfg$schema_version)))
  }
  
  # 4. 変数チェック
  vars <- unlist(cfg$vars)
  if (length(vars) != 3L) {
    errors <- c(errors, sprintf("vars はちょうど3つの異なるカテゴリ変数である必要があります (指定数: %d)", length(vars)))
  } else if (length(unique(vars)) != 3L) {
    errors <- c(errors, "vars に重複した変数名が含まれています")
  }
  
  response_var <- cfg$response_var
  if (!is.null(response_var) && length(response_var) > 0L) {
    val <- response_var[[1L]]
    if (!is.na(val) && nzchar(as.character(val))) {
      resp_str <- as.character(val)
      if (!resp_str %in% vars) {
        errors <- c(errors, sprintf("response_var '%s' が vars (%s) に含まれていません", 
                                     resp_str, paste(vars, collapse = ", ")))
      }
    }
  }
  
  # 5. sampling チェック
  if ("sampling" %in% top_keys && is.list(cfg$sampling)) {
    sampling_keys <- names(cfg$sampling)
    unknown_samp <- setdiff(sampling_keys, ALLOWED_SAMPLING_KEYS)
    if (length(unknown_samp) > 0) {
      errors <- c(errors, sprintf("sampling 内の未知キーを拒否しました: %s", paste(unknown_samp, collapse = ", ")))
    }
    
    req_samp <- c("unit", "total_n_meaning", "independence_assumption", "is_scaled")
    missing_samp <- setdiff(req_samp, sampling_keys)
    if (length(missing_samp) > 0) {
      errors <- c(errors, sprintf("sampling 内の必須キーが不足しています: %s", paste(missing_samp, collapse = ", ")))
    } else {
      indep <- cfg$sampling$independence_assumption
      if (identical(indep, "unverified")) {
        holds <- c(holds, "標本単位間の独立性が未解決・未確認です (independence_assumption='unverified')")
      } else if (identical(indep, "dependent_blocked")) {
        holds <- c(holds, "標本単位間に明示的な依存・クラスタ構造が存在するためモデル適合を保留します (independence_assumption='dependent_blocked')")
      } else if (!identical(indep, "assumed_independent")) {
        errors <- c(errors, sprintf("無効な independence_assumption: %s", as.character(indep)))
      }
    }
  }
  
  # 6. 構造的ゼロのチェック (タスク 2.4 要件: 初回試作は構造ゼロを理由付き保留)
  if (!is.null(cfg$structural_zeros) && length(cfg$structural_zeros) > 0) {
    holds <- c(holds, sprintf("構造的ゼロ (%d件) が指定されているため推論を保留します（初回試作の対象外）", length(cfg$structural_zeros)))
  }
  
  # 7. CSVデータと度数・セルの検証
  input_path <- cfg$input
  df <- NULL
  if (!is.null(input_path)) {
    if (!file.exists(input_path)) {
      errors <- c(errors, sprintf("入力データファイルが存在しません: %s", input_path))
    } else {
      df <- tryCatch({
        read_csv(input_path, show_col_types = FALSE)
      }, error = function(e) {
        errors <<- c(errors, paste("CSV読み込み失敗:", e$message))
        NULL
      })
    }
  }
  
  if (!is.null(df) && length(vars) == 3L) {
    df_cols <- names(df)
    missing_cols <- setdiff(c(vars, cfg$freq), df_cols)
    if (length(missing_cols) > 0) {
      errors <- c(errors, sprintf("CSVに必要な列が存在しません: %s", paste(missing_cols, collapse = ", ")))
    } else {
      freq_col <- cfg$freq
      
      # 8. フィルタ処理の検証（タスク 2.5: 等値・集合包含のみ、任意R式禁止、未知列・未知演算子拒否）
      if (!is.null(cfg$filters) && length(cfg$filters) > 0) {
        filtered_df <- df
        for (idx in seq_along(cfg$filters)) {
          flt <- cfg$filters[[idx]]
          if (!is.list(flt)) {
            errors <- c(errors, sprintf("filter[%d] がオブジェクトではありません", idx))
            next
          }
          f_col <- flt$column
          f_op <- flt$op
          f_val <- flt$value
          
          if (is.null(f_col) || !f_col %in% df_cols) {
            errors <- c(errors, sprintf("filter[%d] の column '%s' がCSV列に存在しません（未知列拒否）", idx, as.character(f_col)))
            next
          }
          if (is.null(f_op) || !f_op %in% ALLOWED_FILTER_OPS) {
            errors <- c(errors, sprintf("filter[%d] の演算子 '%s' は無効です（'==' または 'in' のみ許可、任意式禁止）", idx, as.character(f_op)))
            next
          }
          
          if (f_op == "==") {
            filtered_df <- filtered_df[filtered_df[[f_col]] == f_val, , drop = FALSE]
          } else if (f_op == "in") {
            filtered_df <- filtered_df[filtered_df[[f_col]] %in% unlist(f_val), , drop = FALSE]
          }
        }
        
        if (nrow(filtered_df) == 0) {
          errors <- c(errors, "フィルタ適用後の抽出行数が0件です（エラー時に全件解析への自動切替は禁止）")
        } else {
          df <- filtered_df
        }
      }
      
      # 9. 度数列（freq）の検証
      freq_vec <- df[[freq_col]]
      missing_policy <- if (!is.null(cfg$missing_policy)) cfg$missing_policy else "reject"
      
      if (any(is.na(freq_vec))) {
        na_count <- sum(is.na(freq_vec))
        if (missing_policy == "reject") {
          errors <- c(errors, sprintf("度数列 '%s' に %d 件の NA 欠測が含まれています (missing_policy='reject')", freq_col, na_count))
        } else if (missing_policy == "hold_inference") {
          holds <- c(holds, sprintf("度数列 '%s' に %d 件の NA 欠測が含まれているため推論を保留します", freq_col, na_count))
        }
      }
      
      if (!is.numeric(freq_vec)) {
        errors <- c(errors, sprintf("度数列 '%s' が数値型ではありません", freq_col))
      } else {
        valid_freq <- freq_vec[!is.na(freq_vec)]
        if (any(!is.finite(valid_freq))) {
          errors <- c(errors, sprintf("度数列 '%s' に非有限値 (Inf, -Inf, NaN) が含まれています", freq_col))
        }
        if (any(valid_freq < 0)) {
          errors <- c(errors, sprintf("度数列 '%s' に負の度数が含まれています", freq_col))
        }
        if (any(abs(valid_freq - round(valid_freq)) > 1e-7)) {
          errors <- c(errors, sprintf("度数列 '%s' に非整数値が含まれています", freq_col))
        }
        if (sum(valid_freq) <= 0) {
          errors <- c(errors, sprintf("度数列 '%s' の総和が0以下です (sum=%g)", freq_col, sum(valid_freq)))
        }
      }
      
      # 10. セル網羅性の検証
      absent_cell_policy <- if (!is.null(cfg$absent_cell_policy)) cfg$absent_cell_policy else "treat_as_sample_zero"
      var_levels <- lapply(vars, function(v) unique(df[[v]]))
      names(var_levels) <- vars
      full_grid <- expand.grid(var_levels, stringsAsFactors = FALSE)
      expected_cell_count <- nrow(full_grid)
      
      # 集約して重複セルがないか確認
      actual_cells <- nrow(df)
      if (actual_cells < expected_cell_count) {
        diff_count <- expected_cell_count - actual_cells
        if (absent_cell_policy == "reject") {
          errors <- c(errors, sprintf("水準格子に対して %d 個のセルが未記載です (absent_cell_policy='reject')", diff_count))
        } else if (absent_cell_policy == "hold_inference") {
          holds <- c(holds, sprintf("水準格子に対して %d 個のセルが未記載のため推論を保留します", diff_count))
        }
      }
    }
  }
  
  # 判定決定
  if (length(errors) > 0) {
    status <- "ERROR"
    valid <- FALSE
  } else if (length(holds) > 0) {
    status <- "HOLD"
    valid <- FALSE
  } else {
    status <- "PASS"
    valid <- TRUE
  }
  
  result <- list(
    valid = valid,
    status = status,
    errors = errors,
    holds = holds,
    warnings = warnings
  )
  
  if (!silent) {
    if (status == "PASS") {
      message("[PASS] 設定および入力データの検証に成功しました: ", config_path)
    } else if (status == "HOLD") {
      message("[HOLD] 前提未解決のため推論を保留します: ", config_path)
      for (h in holds) message("  - [REASON] ", h)
    } else {
      message("[ERROR] 設定検証で不合格となりました: ", config_path)
      for (e in errors) message("  - [VIOLATION] ", e)
    }
  }
  
  invisible(result)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1L) {
    cat("Usage: Rscript validate_config.R <path_to_config.json>\n")
    quit(status = 1)
  }
  
  config_path <- args[[1L]]
  res <- validate_config_file(config_path, silent = FALSE)
  
  if (res$status == "ERROR") {
    quit(status = 1)
  } else if (res$status == "HOLD") {
    quit(status = 2) # HOLD は終了コード 2
  } else {
    quit(status = 0)
  }
}

if (sys.nframe() == 0L) {
  main()
}
