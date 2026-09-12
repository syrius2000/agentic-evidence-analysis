# analysis_config.json validation for vcd-bayesian-evidence-analysis.

analysis_config_allowed_keys <- c(
  "input", "vars", "freq", "output_dir", "run_id", "dataset_name",
  "response_var", "top_k", "large_n_threshold", "base_models", "base_model",
  "conditional_rate_view", "pass0_provenance"
)

analysis_config_deprecated_keys <- c(
  "threshold_k", "ebic_gamma", "ebic_p",
  "level2_factor", "level3_factor",
  "arm_top_rules", "arm_min_support", "arm_min_confidence"
)

analysis_config_required_keys <- c("input", "vars", "freq", "output_dir", "run_id")

ALLOWED_BASE_MODELS <- paste0("M", 1:9)

resolve_analysis_config_path <- function(path, config_path = NULL, repo_root = NULL) {
  candidates <- path
  if (!is.null(repo_root) && nzchar(repo_root)) {
    candidates <- c(candidates, file.path(repo_root, path))
  }
  if (!is.null(config_path) && nzchar(config_path)) {
    candidates <- c(candidates, file.path(dirname(config_path), path))
  }
  for (candidate in unique(candidates)) {
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  path
}

is_nonempty_scalar_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
}

is_nonempty_string_vector <- function(value) {
  is.character(value) && length(value) >= 1L && all(!is.na(value)) && all(nzchar(value))
}

is_finite_number <- function(value) {
  is.numeric(value) && length(value) == 1L && is.finite(value)
}

is_positive_integerish <- function(value) {
  isTRUE(is_finite_number(value) && value >= 1 && floor(value) == value && value <= .Machine$integer.max)
}

validate_analysis_config <- function(config_data, config_path = NULL, repo_root = NULL) {
  errors <- character()

  if (!is.list(config_data) || is.data.frame(config_data)) {
    stop("[ERROR] analysis_config.json は JSON object である必要があります。", call. = FALSE)
  }

  missing_keys <- setdiff(analysis_config_required_keys, names(config_data))
  if (length(missing_keys) > 0L) {
    errors <- c(errors, paste0("必須キーがありません: ", paste(missing_keys, collapse = ", ")))
  }

  deprecated_found <- intersect(names(config_data), analysis_config_deprecated_keys)
  if (length(deprecated_found) > 0L) {
    message("[DEPRECATED] analysis_config.json のキー '", paste(deprecated_found, collapse = ", "),
            "' は旧仕様のため廃止されました。4軸セル診断エンジンでは無視されます。")
  }

  unknown_keys <- setdiff(names(config_data), c(analysis_config_allowed_keys, analysis_config_deprecated_keys))
  if (length(unknown_keys) > 0L) {
    message("[WARN] analysis_config.json の未知キーを無視せず読み込みます: ", paste(unknown_keys, collapse = ", "))
  }

  scalar_string_keys <- c("input", "freq", "output_dir", "run_id", "dataset_name", "response_var")
  for (key in intersect(scalar_string_keys, names(config_data))) {
    if (!is_nonempty_scalar_string(config_data[[key]])) {
      errors <- c(errors, paste0(key, " は空でない文字列である必要があります。"))
    }
  }

  if ("vars" %in% names(config_data) && !is_nonempty_string_vector(config_data$vars)) {
    errors <- c(errors, "vars は空でない文字列配列である必要があります。")
  }

  integer_keys <- c("top_k", "large_n_threshold")
  for (key in intersect(integer_keys, names(config_data))) {
    if (!is_positive_integerish(config_data[[key]])) {
      errors <- c(errors, paste0(key, " は正の整数である必要があります。"))
    }
  }

  # --- base_models / base_model の厳格なバリデーション ---
  target_base_models <- NULL
  if ("base_models" %in% names(config_data)) {
    bm <- config_data$base_models
    if (is.character(bm)) {
      if (length(bm) == 0L) {
        errors <- c(errors, "base_models は空にできません。1つ以上のモデルID（M1〜M9）を指定してください。")
      } else if (any(duplicated(bm))) {
        errors <- c(errors, paste0("base_models に重複したモデルIDがあります: ", paste(bm[duplicated(bm)], collapse = ", ")))
      } else {
        invalid_bm <- setdiff(bm, ALLOWED_BASE_MODELS)
        if (length(invalid_bm) > 0L) {
          errors <- c(errors, paste0("base_models に無効なモデルIDが含まれています: ", paste(invalid_bm, collapse = ", "), "。許容されるIDは M1〜M9 です。"))
        } else {
          target_base_models <- bm
        }
      }
    } else {
      errors <- c(errors, "base_models は文字列配列である必要があります。")
    }
  } else if ("base_model" %in% names(config_data)) {
    bm <- config_data$base_model
    if (is_nonempty_scalar_string(bm)) {
      if (!(bm %in% ALLOWED_BASE_MODELS)) {
        errors <- c(errors, paste0("base_model に無効なモデルIDが指定されています: ", bm, "。許容されるIDは M1〜M9 です。"))
      } else {
        target_base_models <- c(bm)
      }
    } else {
      errors <- c(errors, "base_model は空でない文字列である必要があります。")
    }
  }

  # --- conditional_rate_view のスキーマ検証 ---
  if ("conditional_rate_view" %in% names(config_data)) {
    crv <- config_data$conditional_rate_view
    if (!is.list(crv) || is.data.frame(crv)) {
      errors <- c(errors, "conditional_rate_view は JSON object である必要があります。")
    } else {
      crv_req <- c("response_var", "numerator_levels", "denominator_levels", "compare_by", "stratify_by")
      missing_crv_req <- setdiff(crv_req, names(crv))
      if (length(missing_crv_req) > 0L) {
        errors <- c(errors, paste0("conditional_rate_view に必須キーがありません: ", paste(missing_crv_req, collapse = ", ")))
      } else {
        # 役割変数の文字列検査
        for (rk in c("response_var", "compare_by", "stratify_by")) {
          if (!is_nonempty_scalar_string(crv[[rk]])) {
            errors <- c(errors, paste0("conditional_rate_view$", rk, " は空でない文字列である必要があります。"))
          }
        }
        # 役割変数の重複検査
        role_vars <- c(crv$response_var, crv$compare_by, crv$stratify_by)
        if (length(role_vars) == 3L && any(duplicated(role_vars))) {
          errors <- c(errors, "conditional_rate_view の response_var, compare_by, stratify_by は互いに異なる変数である必要があります。")
        }
        # 水準配列の検査
        if (!is_nonempty_string_vector(crv$numerator_levels)) {
          errors <- c(errors, "conditional_rate_view$numerator_levels は1つ以上の空でない文字列配列である必要があります。")
        }
        if (!is_nonempty_string_vector(crv$denominator_levels)) {
          errors <- c(errors, "conditional_rate_view$denominator_levels は1つ以上の空でない文字列配列である必要があります。")
        }
        if (is_nonempty_string_vector(crv$numerator_levels) && is_nonempty_string_vector(crv$denominator_levels)) {
          diff_levels <- setdiff(crv$numerator_levels, crv$denominator_levels)
          if (length(diff_levels) > 0L) {
            errors <- c(errors, paste0("conditional_rate_view$numerator_levels は denominator_levels の部分集合である必要があります（未包含: ", paste(diff_levels, collapse = ", "), "）。"))
          }
        }
        # interval_level の検査
        if ("interval_level" %in% names(crv)) {
          il <- crv$interval_level
          if (!is_finite_number(il) || il <= 0 || il >= 1) {
            errors <- c(errors, "conditional_rate_view$interval_level は 0 超 1 未満の数値である必要があります。")
          }
        }
        # reference_level の検査
        if ("reference_level" %in% names(crv) && !is.null(crv$reference_level)) {
          if (!is_nonempty_scalar_string(crv$reference_level)) {
            errors <- c(errors, "conditional_rate_view$reference_level は空でない文字列である必要があります。")
          }
        }
      }
    }
  }

  resolved_input <- NULL
  if ("input" %in% names(config_data) && is_nonempty_scalar_string(config_data$input)) {
    resolved_input <- resolve_analysis_config_path(config_data$input, config_path, repo_root)
    if (!file.exists(resolved_input)) {
      errors <- c(errors, paste0("input が見つかりません: ", config_data$input))
    }
  }

  if (!is.null(resolved_input) && file.exists(resolved_input)) {
    header <- tryCatch(
      names(utils::read.csv(resolved_input, nrows = 0L, stringsAsFactors = FALSE, fileEncoding = "UTF-8")),
      error = function(e) {
        errors <<- c(errors, paste0("input CSV を読めません: ", e$message))
        NULL
      }
    )
    if (!is.null(header)) {
      if ("vars" %in% names(config_data) && is_nonempty_string_vector(config_data$vars)) {
        missing_vars <- setdiff(config_data$vars, header)
        if (length(missing_vars) > 0L) {
          errors <- c(errors, paste0("vars に input CSV に存在しない列があります: ", paste(missing_vars, collapse = ", ")))
        }
      }
      if ("freq" %in% names(config_data) && is_nonempty_scalar_string(config_data$freq) && !(config_data$freq %in% header)) {
        errors <- c(errors, paste0("freq が input CSV に存在しません: ", config_data$freq))
      }
      if ("response_var" %in% names(config_data) && is_nonempty_scalar_string(config_data$response_var)) {
        if (!(config_data$response_var %in% header)) {
          errors <- c(errors, paste0("response_var が input CSV に存在しません: ", config_data$response_var))
        }
        if ("vars" %in% names(config_data) && is_nonempty_string_vector(config_data$vars) &&
          !(config_data$response_var %in% config_data$vars)) {
          errors <- c(errors, paste0("response_var は vars に含める必要があります: ", config_data$response_var))
        }
      }
      if ("conditional_rate_view" %in% names(config_data) && is.list(config_data$conditional_rate_view)) {
        crv <- config_data$conditional_rate_view
        for (rk in c("response_var", "compare_by", "stratify_by")) {
          if (is_nonempty_scalar_string(crv[[rk]])) {
            if (!(crv[[rk]] %in% header)) {
              errors <- c(errors, paste0("conditional_rate_view$", rk, " ('", crv[[rk]], "') が input CSV に存在しません。"))
            }
            if ("vars" %in% names(config_data) && is_nonempty_string_vector(config_data$vars) && !(crv[[rk]] %in% config_data$vars)) {
              errors <- c(errors, paste0("conditional_rate_view$", rk, " ('", crv[[rk]], "') は vars に含める必要があります。"))
            }
          }
        }
      }
    }
  }

  if (length(errors) > 0L) {
    stop(
      paste(c("[ERROR] analysis_config.json の検証に失敗しました。", paste0("- ", errors)), collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(list(input = resolved_input, base_models = target_base_models))
}

# --- 実データと照合して conditional_rate_view の HOLD 状態を判定するヘルパー ---
validate_conditional_rate_view_data <- function(crv, df, vars, freq_col) {
  if (is.null(crv) || !is.list(crv)) {
    return(list(
      status = "HOLD",
      hold_reason = "conditional_rate_view が設定されていません。Pass 0 で条件付き割合の表示設定を合意してください。",
      rate_data = NULL
    ))
  }

  resp_var <- crv$response_var
  comp_var <- crv$compare_by
  strat_var <- crv$stratify_by
  num_levels <- crv$numerator_levels
  denom_levels <- crv$denominator_levels
  ref_level <- crv$reference_level

  # 列存在検査
  for (v in c(resp_var, comp_var, strat_var, freq_col)) {
    if (!(v %in% names(df))) {
      return(list(
        status = "HOLD",
        hold_reason = sprintf("必要な列 '%s' がデータに存在しません。", v),
        rate_data = NULL
      ))
    }
  }

  actual_resp_levels <- unique(as.character(df[[resp_var]]))
  actual_comp_levels <- unique(as.character(df[[comp_var]]))
  actual_strat_levels <- unique(as.character(df[[strat_var]]))

  # 水準存在検査
  missing_num <- setdiff(num_levels, actual_resp_levels)
  if (length(missing_num) > 0L) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("分子水準 '%s' が応答変数 '%s' の実水準に存在しません。", paste(missing_num, collapse = ", "), resp_var),
      rate_data = NULL
    ))
  }

  missing_denom <- setdiff(denom_levels, actual_resp_levels)
  if (length(missing_denom) > 0L) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("分母水準 '%s' が応答変数 '%s' の実水準に存在しません。", paste(missing_denom, collapse = ", "), resp_var),
      rate_data = NULL
    ))
  }

  if (!is.null(ref_level) && nzchar(ref_level) && !(ref_level %in% actual_comp_levels)) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("参照水準 '%s' が比較変数 '%s' の実水準に存在しません。", ref_level, comp_var),
      rate_data = NULL
    ))
  }

  list(
    status = "VALID",
    hold_reason = NULL,
    config = crv,
    levels = list(
      response = actual_resp_levels,
      compare = actual_comp_levels,
      stratify = actual_strat_levels
    )
  )
}
