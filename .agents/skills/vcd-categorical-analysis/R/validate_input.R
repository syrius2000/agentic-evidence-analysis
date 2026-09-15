# validate_input.R — Input Validation & Fail-Fast Gateway for vcd-categorical-analysis v4.0

#' 2次元名義分割表の厳格な入力境界検証
#'
#' @param data data.frame 入力データ
#' @param vars character(2) 解析対象の2変数名
#' @param freq character(1) 度数列名（NULLの場合は各行を度数1として集計）
#' @param run_dir character(1) run成果物出力先（指定時はfailed状態を記録）
#' @return 検証済み集計data.frame (var1, var2, Freq)
#' @export
validate_input_table <- function(data, vars, freq = "Freq", run_dir = NULL) {
  record_failure <- function(error_code, message) {
    if (!is.null(run_dir) && dir.exists(run_dir)) {
      state_file <- file.path(run_dir, "run_state.json")
      state_payload <- list(
        status = "failed",
        error_code = error_code,
        message = message,
        timestamp_jst = format(Sys.time(), "%Y-%m-%dT%H:%M:%S+09:00")
      )
      tryCatch({
        writeLines(jsonlite::toJSON(state_payload, auto_unbox = TRUE, pretty = TRUE), state_file)
      }, error = function(e) {})
    }
    stop(sprintf("[%s] %s", error_code, message), call. = FALSE)
  }

  # 1. 次元（Arity）の検証
  if (is.null(vars) || length(vars) != 2) {
    if (!is.null(vars) && length(vars) >= 3) {
      record_failure(
        "INVALID_INPUT_ARITY",
        sprintf("vcd-categorical-analysis v4.0 は厳密に2次元専用です (指定次元数: %d)。3次元以上の解析は正本スキル 'vcd-bayesian-evidence-analysis' を使用してください。", length(vars))
      )
    } else {
      record_failure(
        "INSUFFICIENT_DIMENSIONS",
        sprintf("vars は2変数である必要があります (指定次元数: %d)", length(vars))
      )
    }
  }

  for (v in vars) {
    if (!v %in% names(data)) {
      record_failure("VARIABLE_NOT_FOUND", sprintf("指定された変数 '%s' がデータに見つかりません。", v))
    }
  }

  # 2. 構造的ゼロの検出（入力禁止）
  sz_cols <- c("is_structural_zero", "structural_zero", "is_structural", "structural")
  detected_sz <- intersect(sz_cols, names(data))
  if (length(detected_sz) > 0) {
    for (col in detected_sz) {
      vals <- data[[col]]
      if (any(vals == TRUE | vals == 1 | tolower(as.character(vals)) == "true", na.rm = TRUE)) {
        record_failure(
          "STRUCTURAL_ZERO_NOT_SUPPORTED",
          "構造的ゼロ（発生不能セル）が検出されました。本エンジンは完全な2次元名義分割表専用（サンプリングゼロのみ許容）です。不完全分割表または準独立モデルの解析は専用手法をご利用ください。"
        )
      }
    }
  }

  # 3. 度数列（freq）の検証と集計
  df <- data[, vars, drop = FALSE]
  if (!is.null(freq) && freq %in% names(data)) {
    f_vals <- data[[freq]]
    if (any(is.na(f_vals)) || any(is.nan(f_vals)) || any(is.infinite(f_vals))) {
      record_failure("NON_FINITE_COUNTS", "度数列にNA/NaN/Infが含まれています。")
    }
    if (any(f_vals < 0)) {
      record_failure("NEGATIVE_COUNT_DETECTED", "度数列に負の値が含まれています。")
    }
    # 整数性判定（許容誤差 1e-7）
    if (any(abs(f_vals - round(f_vals)) > 1e-7)) {
      record_failure("NON_INTEGER_COUNTS", "度数列に非整数の値（重み等）が含まれています。整数の度数データのみ許容されます。")
    }
    df$Freq <- as.integer(round(f_vals))
  } else {
    df$Freq <- 1L
  }

  # 集計
  agg <- stats::aggregate(Freq ~ ., data = df, FUN = sum)

  # 4. 水準数の検証（各次元 I >= 2, J >= 2）
  u1 <- unique(agg[[vars[1]]])
  u2 <- unique(agg[[vars[2]]])
  if (length(u1) < 2 || length(u2) < 2) {
    record_failure(
      "INSUFFICIENT_LEVELS",
      sprintf("各変数の水準数は2以上必要です (%s: %d, %s: %d)。", vars[1], length(u1), vars[2], length(u2))
    )
  }

  # 5. 総度数（N > 0）の検証
  n_total <- sum(agg$Freq)
  if (n_total <= 0) {
    record_failure("ZERO_TOTAL_COUNT", "総度数 N が 0 以下です。")
  }

  attr(agg, "vars") <- vars
  attr(agg, "n_total") <- n_total
  return(agg)
}
