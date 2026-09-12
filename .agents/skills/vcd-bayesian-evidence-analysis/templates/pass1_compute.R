# =============================================================================
# vcd-bayesian-evidence-analysis: pass1_compute.R
# 【正本計算エンジン】新4軸統計基盤（Effect x Evidence x Influence x Stability）
# + 9階層対数線形モデル + 総度数N明示式BIC + 多重基準セル診断 + 汎用Dirichlet条件付き割合
#
# ※ 既存の templates/three_way/ は過去互換性維持のための非正本経路です。
#    新規開発・正本実行・回帰検証はすべて本スクリプト（Antigravity主系）を唯一の正本とします。
# =============================================================================

suppressPackageStartupMessages({
  library(stats)
  library(dplyr)
})

`%||%` <- function(x, y) if (is.null(x)) y else x
safe_num <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) NA_real_ else as.numeric(x)
safe_round <- function(x, digits = 4) ifelse(is.na(x), NA_real_, round(as.numeric(x), digits))

sanitize_run_slug <- function(x) {
  if (is.null(x)) return(NULL)
  if (length(x) < 1L) stop("[ERROR] 無効な --run-id です")
  x <- as.character(x)[1]
  if (is.na(x) || !nzchar(trimws(x))) stop("[ERROR] 無効な --run-id です")
  x <- trimws(x)
  if (tolower(x) == "auto") {
    return(format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo"))
  }
  x <- gsub("[/\\\\]", "_", x)
  x <- gsub("^\\.+|\\.+$", "", x)
  if (!nzchar(x)) stop("[ERROR] 無効な --run-id です")
  x
}

# --- [1. モデル仕様辞書と生成クラス（generators）正本定義] ---

MODEL_SPECS_3WAY <- list(
  M1 = list(id = "M1", model_key = "3way_M1", name = "mutual_independence", order = 1, generators = list(c("A"), c("B"), c("C"))),
  M2 = list(id = "M2", model_key = "3way_M2", name = "assoc_AB", order = 2, generators = list(c("A", "B"), c("C"))),
  M3 = list(id = "M3", model_key = "3way_M3", name = "assoc_AC", order = 2, generators = list(c("A", "C"), c("B"))),
  M4 = list(id = "M4", model_key = "3way_M4", name = "assoc_BC", order = 2, generators = list(c("B", "C"), c("A"))),
  M5 = list(id = "M5", model_key = "3way_M5", name = "cond_indep_BC_given_A", order = 2, generators = list(c("A", "B"), c("A", "C"))),
  M6 = list(id = "M6", model_key = "3way_M6", name = "cond_indep_AC_given_B", order = 2, generators = list(c("A", "B"), c("B", "C"))),
  M7 = list(id = "M7", model_key = "3way_M7", name = "cond_indep_AB_given_C", order = 2, generators = list(c("A", "C"), c("B", "C"))),
  M8 = list(id = "M8", model_key = "3way_M8", name = "homogeneous_association", order = 2, generators = list(c("A", "B"), c("A", "C"), c("B", "C"))),
  M9 = list(id = "M9", model_key = "3way_M9", name = "saturated", order = 3, generators = list(c("A", "B", "C")))
)

MODEL_SPECS_2WAY <- list(
  M1 = list(id = "M1", model_key = "2way_M1", name = "mutual_independence", order = 1, generators = list(c("A"), c("B"))),
  M2 = list(id = "M2", model_key = "2way_M2", name = "saturated", order = 2, generators = list(c("A", "B")))
)

build_bracket_notation <- function(generators) {
  gen_strs <- vapply(generators, function(gen) {
    sprintf("[%s]", paste(sort(as.character(gen)), collapse = ""))
  }, character(1))
  paste(gen_strs, collapse = "")
}

derive_independence_structure <- function(generators, factor_map = NULL) {
  norm_bracket <- build_bracket_notation(generators)

  if (norm_bracket == "[A][B]") {
    return(list(
      kind = "mutual_independence",
      statements = list(
        list(left = I(c("A")), right = I(c("B")), given = I(character(0)))
      ),
      base_description = "AとBは独立である"
    ))
  } else if (norm_bracket == "[AB]") {
    return(list(
      kind = "no_independence_constraint",
      statements = list(),
      base_description = "飽和モデル（2因子交互作用まで含む）"
    ))
  } else if (norm_bracket == "[A][B][C]") {
    return(list(
      kind = "mutual_independence",
      statements = list(
        list(left = I(c("A")), right = I(c("B")), given = I(character(0))),
        list(left = I(c("A", "B")), right = I(c("C")), given = I(character(0)))
      ),
      base_description = "3因子が相互に独立である"
    ))
  } else if (norm_bracket == "[AB][C]") {
    return(list(
      kind = "joint_independence",
      statements = list(
        list(left = I(c("A", "B")), right = I(c("C")), given = I(character(0)))
      ),
      base_description = "(A, B) と C は結合独立である"
    ))
  } else if (norm_bracket == "[AC][B]") {
    return(list(
      kind = "joint_independence",
      statements = list(
        list(left = I(c("A", "C")), right = I(c("B")), given = I(character(0)))
      ),
      base_description = "(A, C) と B は結合独立である"
    ))
  } else if (norm_bracket == "[BC][A]") {
    return(list(
      kind = "joint_independence",
      statements = list(
        list(left = I(c("B", "C")), right = I(c("A")), given = I(character(0)))
      ),
      base_description = "(B, C) と A は結合独立である"
    ))
  } else if (norm_bracket == "[AB][AC]") {
    return(list(
      kind = "conditional_independence",
      statements = list(
        list(left = I(c("B")), right = I(c("C")), given = I(c("A")))
      ),
      base_description = "Aで層別したとき、BとCは条件付き独立である"
    ))
  } else if (norm_bracket == "[AB][BC]") {
    return(list(
      kind = "conditional_independence",
      statements = list(
        list(left = I(c("A")), right = I(c("C")), given = I(c("B")))
      ),
      base_description = "Bで層別したとき、AとCは条件付き独立である"
    ))
  } else if (norm_bracket == "[AC][BC]") {
    return(list(
      kind = "conditional_independence",
      statements = list(
        list(left = I(c("A")), right = I(c("B")), given = I(c("C")))
      ),
      base_description = "Cで層別したとき、AとBは条件付き独立である"
    ))
  } else if (norm_bracket == "[AB][AC][BC]") {
    return(list(
      kind = "no_independence_constraint",
      statements = list(),
      base_description = "全2因子交互作用を含み、3因子交互作用を含まない（均一連関）"
    ))
  } else if (norm_bracket == "[ABC]") {
    return(list(
      kind = "no_independence_constraint",
      statements = list(),
      base_description = "飽和モデル（3因子交互作用まで含む）"
    ))
  } else {
    return(list(
      kind = "custom_generator",
      statements = list(),
      base_description = sprintf("カスタム生成クラスモデル（%s）", norm_bracket)
    ))
  }
}

derive_formula_metadata <- function(generators, factor_map = NULL) {
  norm_bracket <- build_bracket_notation(generators)

  if (norm_bracket == "[A][B]") {
    return(list(
      formula_latex = "\\log \\mu_{ij} = \\lambda + \\lambda_i^A + \\lambda_j^B",
      formula_description_ja = "主効果A, Bのみを含む独立モデル"
    ))
  } else if (norm_bracket == "[AB]") {
    return(list(
      formula_latex = "\\log \\mu_{ij} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_{ij}^{AB}",
      formula_description_ja = "2因子交互作用を含む飽和モデル（自由度0）"
    ))
  } else if (norm_bracket == "[A][B][C]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C",
      formula_description_ja = "主効果A, B, Cのみを含む相互独立モデル（交互作用を含まない）"
    ))
  } else if (norm_bracket == "[AB][C]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用ABを含む結合独立モデル"
    ))
  } else if (norm_bracket == "[AC][B]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ik}^{AC}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用ACを含む結合独立モデル"
    ))
  } else if (norm_bracket == "[BC][A]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{jk}^{BC}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用BCを含む結合独立モデル"
    ))
  } else if (norm_bracket == "[AB][AC]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB} + \\lambda_{ik}^{AC}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用AB, ACを含む条件付き独立モデル（BC交互作用を含まない）"
    ))
  } else if (norm_bracket == "[AB][BC]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB} + \\lambda_{jk}^{BC}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用AB, BCを含む条件付き独立モデル（AC交互作用を含まない）"
    ))
  } else if (norm_bracket == "[AC][BC]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ik}^{AC} + \\lambda_{jk}^{BC}",
      formula_description_ja = "主効果A, B, Cおよび2因子交互作用AC, BCを含む条件付き独立モデル（AB交互作用を含まない）"
    ))
  } else if (norm_bracket == "[AB][AC][BC]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB} + \\lambda_{ik}^{AC} + \\lambda_{jk}^{BC}",
      formula_description_ja = "全2因子交互作用を含み、3因子交互作用を含まない均一連関モデル"
    ))
  } else if (norm_bracket == "[ABC]") {
    return(list(
      formula_latex = "\\log \\mu_{ijk} = \\lambda + \\lambda_i^A + \\lambda_j^B + \\lambda_k^C + \\lambda_{ij}^{AB} + \\lambda_{ik}^{AC} + \\lambda_{jk}^{BC} + \\lambda_{ijk}^{ABC}",
      formula_description_ja = "3因子交互作用まで含む飽和モデル（自由度0）"
    ))
  } else {
    return(list(
      formula_latex = sprintf("\\log \\mu = \\text{generators(%s)}", norm_bracket),
      formula_description_ja = sprintf("生成クラス %s に対応するポアソン対数線形モデル", norm_bracket)
    ))
  }
}

build_factor_map <- function(vars) {
  factor_syms <- c("A", "B", "C")[seq_along(vars)]
  map <- list()
  for (i in seq_along(vars)) {
    sym <- factor_syms[i]
    map[[sym]] <- list(
      symbol = sym,
      variable = vars[i],
      label = vars[i]
    )
  }
  map
}

build_formula_from_generators <- function(generators, factor_map, freq_col) {
  sym_to_var <- vapply(factor_map, function(x) x$variable, character(1))

  gen_terms <- vapply(generators, function(gen) {
    real_vars <- sym_to_var[gen]
    if (length(real_vars) == 1L) {
      real_vars
    } else {
      paste(real_vars, collapse = " * ")
    }
  }, character(1))

  rhs <- paste(gen_terms, collapse = " + ")
  as.formula(sprintf("%s ~ %s", freq_col, rhs))
}

expand_generator_terms <- function(generators, factor_map) {
  sym_to_var <- vapply(factor_map, function(x) x$variable, character(1))
  terms_set <- character(0)

  for (gen in generators) {
    real_vars <- sym_to_var[gen]
    k <- length(real_vars)
    for (m in seq_len(k)) {
      combs <- utils::combn(real_vars, m, simplify = FALSE)
      for (comb in combs) {
        comb_sorted <- sort(comb)
        terms_set <- c(terms_set, paste(comb_sorted, collapse = ":"))
      }
    }
  }
  unique(terms_set)
}

validate_formula_terms <- function(fmla, generators, factor_map) {
  expected_terms <- expand_generator_terms(generators, factor_map)
  f_terms <- attr(stats::terms(fmla), "term.labels")

  f_terms_norm <- vapply(strsplit(f_terms, ":"), function(parts) {
    paste(sort(parts), collapse = ":")
  }, character(1))

  if (!setequal(expected_terms, f_terms_norm)) {
    stop(sprintf(
      "[ERROR] formula の展開項と生成クラスが一致しません。\n期待項: %s\n実展開項: %s",
      paste(sort(expected_terms), collapse = ", "),
      paste(sort(f_terms_norm), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

derive_model_metadata <- function(spec, factor_map, fit = NULL) {
  sym_to_var <- vapply(factor_map, function(x) x$variable, character(1))
  sym_to_label <- vapply(factor_map, function(x) x$label, character(1))

  generators <- spec$generators
  bracket_notation <- build_bracket_notation(generators)

  gen_expanded <- vapply(generators, function(gen) {
    real_vars <- sym_to_var[gen]
    sprintf("[%s]", paste(real_vars, collapse = ", "))
  }, character(1))
  bracket_expanded <- paste(gen_expanded, collapse = "")

  indep_raw <- derive_independence_structure(generators, factor_map)

  desc_ja <- indep_raw$base_description
  for (sym in names(factor_map)) {
    var_name <- sym_to_var[[sym]]
    label <- sym_to_label[[sym]]
    target_text <- if (!is.null(label) && nzchar(label) && var_name != label) sprintf("%s（%s）", label, var_name) else var_name
    pat <- sprintf("(?<![A-Za-z])%s(?![A-Za-z])", sym)
    desc_ja <- gsub(pat, target_text, desc_ja, perl = TRUE)
  }

  fitted_fmla_str <- if (!is.null(fit)) {
    paste(deparse(formula(fit)), collapse = " ")
  } else {
    NULL
  }

  fmla_meta <- derive_formula_metadata(generators, factor_map)

  indep_clean <- list(
    kind = indep_raw$kind,
    statements = lapply(indep_raw$statements, function(st) {
      list(
        left = I(as.character(st$left)),
        right = I(as.character(st$right)),
        given = I(as.character(st$given))
      )
    }),
    description_ja = desc_ja
  )

  list(
    model_id = spec$id,
    model_key = spec$model_key,
    generators = lapply(generators, function(g) I(as.character(g))),
    bracket_notation = bracket_notation,
    bracket_expanded = bracket_expanded,
    independence = indep_clean,
    fitted_formula = fitted_fmla_str,
    formula_latex = fmla_meta$formula_latex,
    formula_description_ja = fmla_meta$formula_description_ja
  )
}

# --- [2. モデル適合と総度数N基準の明示式BIC算出] ---
fit_all_poisson_models <- function(df, vars, freq_col) {
  total_n <- sum(df[[freq_col]])
  n_vars <- length(vars)

  if (n_vars < 2L || n_vars > 3L) {
    stop(sprintf("[ERROR] vcd-bayesian-evidence-analysis は 2元表または 3元表のみをサポートしています（指定変数数: %d）。", n_vars))
  }

  factor_map <- build_factor_map(vars)
  specs <- if (n_vars == 3L) MODEL_SPECS_3WAY else MODEL_SPECS_2WAY

  fits <- list()
  summary_table <- list()
  definitions <- list()

  for (m_id in names(specs)) {
    spec <- specs[[m_id]]
    fmla <- build_formula_from_generators(spec$generators, factor_map, freq_col)
    validate_formula_terms(fmla, spec$generators, factor_map)

    fit <- tryCatch({
      glm(fmla, data = df, family = poisson(), x = TRUE)
    }, error = function(e) NULL)

    meta <- derive_model_metadata(spec, factor_map, fit)
    definitions[[m_id]] <- meta

    if (!is.null(fit)) {
      ll <- as.numeric(stats::logLik(fit))
      k_param <- attr(stats::logLik(fit), "df")
      dev <- fit$deviance
      df_res <- fit$df.residual
      # 【鉄則】総度数 N 基準のポアソン明示式 BIC = -2*logLik + p*log(N)
      # stats::BIC や Deviance置換式は一切使用しない
      bic_explicit <- -2 * ll + k_param * log(total_n)
      leverage <- tryCatch(stats::hatvalues(fit), error = function(e) rep(0, nrow(df)))

      fits[[m_id]] <- list(
        id = m_id,
        name = spec$name,
        formula = deparse(fmla),
        fit = fit,
        loglik = ll,
        rank = fit$rank,
        df_residual = df_res,
        deviance = dev,
        bic = bic_explicit,
        fitted_values = fitted(fit),
        residuals_pearson = residuals(fit, type = "pearson"),
        residuals_deviance = residuals(fit, type = "deviance"),
        leverage = leverage
      )

      summary_table[[m_id]] <- data.frame(
        model_id = m_id,
        model_name = spec$name,
        df_residual = df_res,
        deviance = round(dev, 4),
        bic = round(bic_explicit, 4),
        stringsAsFactors = FALSE
      )
    }
  }

  df_summary <- dplyr::bind_rows(summary_table) %>% dplyr::arrange(bic)
  df_summary$delta_bic <- round(df_summary$bic - df_summary$bic[1L], 4)
  best_id <- df_summary$model_id[1L]

  list(
    notation_version = "1.0.0",
    dimension = n_vars,
    factor_map = factor_map,
    definitions = definitions,
    models = fits,
    summary_df = df_summary,
    best_model_id = best_id
  )
}

# --- [3. 4軸セル診断体系 (Effect, Evidence, Influence, Stability)] ---
compute_4axis_cell_diagnostics <- function(df, vars, freq_col, fitted_models, base_model_id = "M1", large_n_threshold = 2000) {
  base_m <- fitted_models$models[[base_model_id]]
  if (is.null(base_m)) {
    stop(sprintf("[ERROR] 指定された基準モデル '%s' の適合結果が存在しません。", base_model_id), call. = FALSE)
  }

  total_n <- sum(df[[freq_col]])
  total_cells <- nrow(df)

  y <- df[[freq_col]]
  exp_val <- base_m$fitted_values
  res_p <- base_m$residuals_pearson
  lev <- base_m$leverage

  # 1. Effect (標本数不変)
  obs_exp_ratio <- ifelse(exp_val > 0, y / exp_val, NA_real_)
  log_oe_ratio <- ifelse(y > 0 & exp_val > 0, log(y / exp_val),
                         ifelse(y == 0 & exp_val > 0, log(0.5 / exp_val), NA_real_))
  rate_diff <- (y - exp_val) / total_n
  scaled_diff <- ifelse(exp_val > 0, (y - exp_val) / sqrt(exp_val * total_n), NA_real_)

  # 2. Evidence (検定統計量・標本数比例)
  # Rao (1948) スコア検定統計量: T_i^{score} = r_{P,i}^2 / (1 - h_{ii})
  h_denom <- pmax(1 - lev, 1e-4)
  score_stat <- (res_p^2) / h_denom
  p_val <- pchisq(score_stat, df = 1, lower.tail = FALSE)
  log_p <- pchisq(score_stat, df = 1, lower.tail = FALSE, log.p = TRUE)

  # 3. Influence (梃子力)
  leverage <- lev

  # 4. Stability (数値的安定性 3条件論理和)
  is_zero <- y == 0
  is_sparse <- exp_val < 5.0
  is_high_lev <- lev >= 0.80
  is_quarantined <- is_zero | is_sparse | is_high_lev
  stability_status <- ifelse(is_quarantined, "QUARANTINED", "REGULAR")

  # 大標本 Dual-Filter (N > large_n_threshold): |log(O/E)| >= 0.50 かつ T_score >= 3.84 かつ REGULAR
  is_candidate_dual_filter <- (abs(log_oe_ratio) >= 0.50) & (score_stat >= 3.84) & (stability_status == "REGULAR")

  # 旧 Evidence Score (監査専用列: r^2 - ln(N))
  evidence_score_legacy <- (res_p^2) - log(total_n)

  diag_df <- df
  diag_df$Observed <- y
  diag_df$Expected <- round(exp_val, 4)
  diag_df$Residual <- round(res_p, 4)
  diag_df$log_oe_ratio <- round(log_oe_ratio, 4)
  diag_df$scaled_diff <- round(scaled_diff, 4)
  diag_df$rate_diff <- round(rate_diff, 6)
  diag_df$score_stat <- round(score_stat, 4)
  diag_df$p_value <- signif(p_val, 4)
  diag_df$log_p <- round(log_p, 2)
  diag_df$leverage <- round(leverage, 4)
  diag_df$stability_status <- stability_status
  diag_df$is_candidate_dual_filter <- is_candidate_dual_filter
  diag_df$evidence_score_legacy <- round(evidence_score_legacy, 4)

  # 探索順序: |log(O/E)| 降順
  diag_df <- diag_df %>% dplyr::arrange(dplyr::desc(abs(log_oe_ratio)))

  # 問いの導出
  def <- fitted_models$definitions[[base_model_id]]
  question_text <- if (!is.null(def$independence$description_ja)) {
    sprintf("「%s」という仮説（%s）からの局所的乖離の評価", def$independence$description_ja, base_model_id)
  } else {
    sprintf("基準モデル %s からの局所的乖離の評価", base_model_id)
  }

  regular_n <- sum(stability_status == "REGULAR")
  quarantined_n <- sum(stability_status == "QUARANTINED")
  candidate_n <- sum(is_candidate_dual_filter)
  legacy_pos_n <- sum(evidence_score_legacy > 0)

  list(
    base_model_id = base_m$id,
    base_model_name = base_m$name,
    question_ja = question_text,
    counts = list(
      total_cells = total_cells,
      regular_cells = regular_n,
      regular_rate = round(regular_n / total_cells, 4),
      quarantined_cells = quarantined_n,
      quarantined_rate = round(quarantined_n / total_cells, 4),
      candidate_cells = candidate_n,
      candidate_rate = round(candidate_n / total_cells, 4),
      legacy_positive_cells = legacy_pos_n,
      legacy_positive_rate = round(legacy_pos_n / total_cells, 4)
    ),
    cell_table = diag_df
  )
}

# --- [4. 多重基準セル診断の統合実行] ---
compute_multi_baseline_diagnostics <- function(df, vars, freq_col, fitted_models, base_model_ids = c("M1", "M5"), large_n_threshold = 2000) {
  # 重複排除
  base_model_ids <- unique(base_model_ids)
  res <- list()
  for (mid in base_model_ids) {
    res[[mid]] <- compute_4axis_cell_diagnostics(
      df = df,
      vars = vars,
      freq_col = freq_col,
      fitted_models = fitted_models,
      base_model_id = mid,
      large_n_threshold = large_n_threshold
    )
  }
  res
}

# --- [5. 汎用 Dirichlet 事後推論と条件付き割合ビュー (conditional_rate_view)] ---
compute_conditional_rate_view <- function(df, vars, freq_col, crv_spec, draws = 20000, seed = 20260906) {
  if (is.null(crv_spec) || !is.list(crv_spec)) {
    return(list(
      status = "HOLD",
      hold_reason = "conditional_rate_view が設定されていません。Pass 0 で条件付き割合の表示設定を合意してください。",
      rate_data = NULL
    ))
  }

  resp_var <- crv_spec$response_var
  comp_var <- crv_spec$compare_by
  strat_var <- crv_spec$stratify_by
  num_levels <- crv_spec$numerator_levels
  denom_levels <- crv_spec$denominator_levels
  ref_level <- crv_spec$reference_level
  interval_lvl <- crv_spec$interval_level %||% 0.95

  # 入力検証
  for (v in c(resp_var, comp_var, strat_var, freq_col)) {
    if (!(v %in% names(df))) {
      return(list(
        status = "HOLD",
        hold_reason = sprintf("列 '%s' がデータに存在しません。", v),
        rate_data = NULL
      ))
    }
  }

  actual_resp <- unique(as.character(df[[resp_var]]))
  actual_comp <- unique(as.character(df[[comp_var]]))
  actual_strat <- unique(as.character(df[[strat_var]]))

  missing_num <- setdiff(num_levels, actual_resp)
  if (length(missing_num) > 0L) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("分子水準 '%s' が実水準に存在しません。", paste(missing_num, collapse = ", ")),
      rate_data = NULL
    ))
  }

  missing_denom <- setdiff(denom_levels, actual_resp)
  if (length(missing_denom) > 0L) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("分母水準 '%s' が実水準に存在しません。", paste(missing_denom, collapse = ", ")),
      rate_data = NULL
    ))
  }

  if (!is.null(ref_level) && nzchar(ref_level) && !(ref_level %in% actual_comp)) {
    return(list(
      status = "HOLD",
      hold_reason = sprintf("参照水準 '%s' が比較変数 '%s' の実水準に存在しません。", ref_level, comp_var),
      rate_data = NULL
    ))
  }

  # Dirichlet事後サンプリング
  set.seed(seed)
  y <- df[[freq_col]]
  K <- length(y)
  alpha_post <- y + 1.0 # 共役Dirichlet事後分布 (一様事前分布 a_0 = 1.0)

  gamma_draws <- matrix(rgamma(K * draws, shape = rep(alpha_post, each = draws), rate = 1),
                        nrow = draws, ncol = K)
  sum_gamma <- rowSums(gamma_draws)
  pi_draws <- gamma_draws / sum_gamma # [draws x K]

  # クレド区間の分位点計算用確率
  alpha_ci <- 1.0 - interval_lvl
  probs_eti <- c(alpha_ci / 2.0, 1.0 - alpha_ci / 2.0)

  # 各層・比較グループごとの条件付き割合集計
  rate_records <- list()
  slice_draws_map <- list()
  has_zero_denom <- FALSE

  for (s in actual_strat) {
    for (c in actual_comp) {
      idx_denom <- which(df[[strat_var]] == s & df[[comp_var]] == c & df[[resp_var]] %in% denom_levels)
      idx_num <- which(df[[strat_var]] == s & df[[comp_var]] == c & df[[resp_var]] %in% num_levels)

      obs_denom <- sum(y[idx_denom])
      obs_num <- sum(y[idx_num])

      slice_key <- sprintf("%s__%s", s, c)

      if (obs_denom == 0) {
        has_zero_denom <- TRUE
        rate_records[[slice_key]] <- list(
          strat_var = strat_var,
          strat_level = s,
          comp_var = comp_var,
          comp_level = c,
          resp_var = resp_var,
          num_levels = num_levels,
          denom_levels = denom_levels,
          obs_numerator = 0,
          obs_denominator = 0,
          raw_rate = NA_real_,
          post_mean = NA_real_,
          ci_lower = NA_real_,
          ci_upper = NA_real_,
          status = "HOLD_ZERO_DENOMINATOR",
          hold_reason = "該当スライスの分母度数が0です。"
        )
      } else {
        raw_rate <- obs_num / obs_denom

        # Dirichlet事後ドローによる条件付き割合
        if (length(idx_denom) == 1L) {
          denom_d <- pi_draws[, idx_denom]
        } else {
          denom_d <- rowSums(pi_draws[, idx_denom, drop = FALSE])
        }
        if (length(idx_num) == 1L) {
          num_d <- pi_draws[, idx_num]
        } else {
          num_d <- rowSums(pi_draws[, idx_num, drop = FALSE])
        }

        cond_d <- num_d / pmax(denom_d, 1e-12)
        slice_draws_map[[slice_key]] <- cond_d

        p_mean <- mean(cond_d)
        ci_vals <- quantile(cond_d, probs = probs_eti)

        rate_records[[slice_key]] <- list(
          strat_var = strat_var,
          strat_level = s,
          comp_var = comp_var,
          comp_level = c,
          resp_var = resp_var,
          num_levels = num_levels,
          denom_levels = denom_levels,
          obs_numerator = obs_num,
          obs_denominator = obs_denom,
          raw_rate = safe_round(raw_rate, 4),
          post_mean = safe_round(p_mean, 4),
          ci_lower = safe_round(ci_vals[1L], 4),
          ci_upper = safe_round(ci_vals[2L], 4),
          status = "VALID",
          hold_reason = NULL
        )
      }
    }
  }

  # 参照水準との割合差（各層内）
  differences_list <- list()
  if (!is.null(ref_level) && nzchar(ref_level) && (ref_level %in% actual_comp)) {
    for (s in actual_strat) {
      ref_key <- sprintf("%s__%s", s, ref_level)
      if (!is.null(slice_draws_map[[ref_key]])) {
        ref_draws <- slice_draws_map[[ref_key]]
        comp_targets <- setdiff(actual_comp, ref_level)
        for (ct in comp_targets) {
          target_key <- sprintf("%s__%s", s, ct)
          if (!is.null(slice_draws_map[[target_key]])) {
            diff_d <- slice_draws_map[[target_key]] - ref_draws
            diff_ci <- quantile(diff_d, probs = probs_eti)
            diff_key <- sprintf("%s__%s_minus_%s", s, ct, ref_level)
            differences_list[[diff_key]] <- list(
              strat_level = s,
              target_level = ct,
              reference_level = ref_level,
              difference_mean = safe_round(mean(diff_d), 4),
              ci_lower = safe_round(diff_ci[1L], 4),
              ci_upper = safe_round(diff_ci[2L], 4),
              prob_positive = safe_round(mean(diff_d > 0), 4)
            )
          }
        }
      }
    }
  }

  overall_status <- if (has_zero_denom) "PARTIAL_HOLD" else "VALID"

  list(
    status = overall_status,
    hold_reason = if (has_zero_denom) "一部のスライスの分母度数がゼロのため部分HOLDとなっています。" else NULL,
    config_echo = list(
      response_var = resp_var,
      compare_by = comp_var,
      stratify_by = strat_var,
      numerator_levels = num_levels,
      denominator_levels = denom_levels,
      reference_level = ref_level,
      interval_level = interval_lvl
    ),
    rates = rate_records,
    differences = differences_list
  )
}

# =============================================================================
# [10. 条件付きセル順位再現性評価 (Conditional Rank Reproducibility)]
# =============================================================================

refit_m1_closed_form <- function(counts_array, I, J, K_dim, total_n) {
  # M1: [A][B][C]
  # mu_ijk = (n_i++ * n_+j+ * n_++k) / N^2
  margin_A <- apply(counts_array, 1L, sum)
  margin_B <- apply(counts_array, 2L, sum)
  margin_C <- apply(counts_array, 3L, sum)

  if (any(margin_A == 0) || any(margin_B == 0) || any(margin_C == 0)) {
    return(NULL) # rank deficient / boundary
  }

  outer_AB <- outer(margin_A, margin_B, "*")
  mu_arr <- outer(outer_AB, margin_C, "*") / (total_n^2)
  as.vector(mu_arr)
}

refit_m5_closed_form <- function(counts_array, I, J, K_dim) {
  # M5: [AB][AC] (B perp C | A)
  # mu_ijk = (n_ij+ * n_i+k) / n_i++
  margin_A <- apply(counts_array, 1L, sum)
  if (any(margin_A == 0)) {
    return(NULL) # rank deficient (zero stratum count)
  }

  margin_AB <- apply(counts_array, c(1L, 2L), sum)
  margin_AC <- apply(counts_array, c(1L, 3L), sum)

  mu_arr <- array(0, dim = c(I, J, K_dim))
  for (i in seq_len(I)) {
    denom <- margin_A[i]
    num_bc <- outer(margin_AB[i, ], margin_AC[i, ], "*")
    mu_arr[i, , ] <- num_bc / denom
  }
  as.vector(mu_arr)
}

compute_conditional_rank_reproducibility <- function(
  df,
  vars,
  freq_col,
  factor_levels_order,
  crr_config,
  baseline_diagnostics
) {
  if (is.null(crr_config) || !isTRUE(crr_config$enabled)) {
    return(NULL)
  }

  target_model <- crr_config$target_baseline_model
  target_metric <- crr_config$target_metric
  top_k <- as.integer(crr_config$top_k)
  iterations <- as.integer(crr_config$iterations)
  seed <- as.integer(crr_config$seed)

  v1 <- vars[1L]
  v2 <- vars[2L]
  v3 <- vars[3L]
  lev1 <- as.character(factor_levels_order[[v1]])
  lev2 <- as.character(factor_levels_order[[v2]])
  lev3 <- as.character(factor_levels_order[[v3]])
  I <- length(lev1)
  J <- length(lev2)
  K_dim <- length(lev3)
  total_cells <- I * J * K_dim

  # 正準格子の構築 (expand.grid順: v1最速, 次にv2, 次にv3)
  canonical_grid <- expand.grid(
    lev1 = lev1,
    lev2 = lev2,
    lev3 = lev3,
    stringsAsFactors = FALSE
  )
  colnames(canonical_grid) <- c(v1, v2, v3)
  canonical_grid$canonical_cell_index <- seq_len(total_cells)
  # RFC 3986 準拠の構造化 URI キーバリュー方式 (vars-ordered-uri-kv)
  # key, val ともに utils::URLencode(reserved = TRUE) で符号化し、'/' で連結
  enc_v1 <- utils::URLencode(v1, reserved = TRUE)
  enc_v2 <- utils::URLencode(v2, reserved = TRUE)
  enc_v3 <- utils::URLencode(v3, reserved = TRUE)
  c_ids <- character(total_cells)
  for (c_i in seq_len(total_cells)) {
    val1 <- utils::URLencode(as.character(canonical_grid[[v1]][c_i]), reserved = TRUE)
    val2 <- utils::URLencode(as.character(canonical_grid[[v2]][c_i]), reserved = TRUE)
    val3 <- utils::URLencode(as.character(canonical_grid[[v3]][c_i]), reserved = TRUE)
    c_ids[c_i] <- sprintf("%s=%s/%s=%s/%s=%s", enc_v1, val1, enc_v2, val2, enc_v3, val3)
  }
  canonical_grid$cell_id <- c_ids

  # quality_gate_minimum_valid_rate の取得（未指定時は既定 0.95）
  qg_min_rate <- if (!is.null(crr_config$quality_gate_minimum_valid_rate) &&
                     is.numeric(crr_config$quality_gate_minimum_valid_rate) &&
                     length(crr_config$quality_gate_minimum_valid_rate) == 1L &&
                     is.finite(crr_config$quality_gate_minimum_valid_rate) &&
                     crr_config$quality_gate_minimum_valid_rate > 0.0 &&
                     crr_config$quality_gate_minimum_valid_rate <= 1.0) {
    as.numeric(crr_config$quality_gate_minimum_valid_rate)
  } else {
    0.95
  }

  # baseline_diagnostics から必要な列を取り出して正準格子と結合
  diag_df <- if (is.data.frame(baseline_diagnostics)) {
    baseline_diagnostics
  } else if (is.list(baseline_diagnostics) && !is.null(baseline_diagnostics$cell_table)) {
    baseline_diagnostics$cell_table
  } else if (is.list(baseline_diagnostics)) {
    do.call(rbind, lapply(baseline_diagnostics, function(item) {
      if (is.list(item$factors)) {
        row_d <- as.data.frame(item$factors, stringsAsFactors = FALSE)
        row_d$Observed <- item$Observed
        row_d$Expected <- item$Expected
        row_d$stability_status <- item$stability_status
        row_d
      } else {
        as.data.frame(item, stringsAsFactors = FALSE)
      }
    }))
  } else {
    stop("[ERROR] baseline_diagnostics の形式が無効です。")
  }

  cols_to_pull <- intersect(c(vars, freq_col, "Observed", "Expected", "stability_status"), colnames(diag_df))
  merged_df <- merge(canonical_grid, diag_df[, cols_to_pull, drop = FALSE], by = vars, all.x = TRUE, sort = FALSE)
  merged_df <- merged_df[order(merged_df$canonical_cell_index), ]

  obs_canon <- if (freq_col %in% colnames(merged_df)) {
    as.numeric(merged_df[[freq_col]])
  } else {
    as.numeric(merged_df$Observed)
  }
  total_n <- sum(obs_canon)

  stability_statuses <- as.character(merged_df$stability_status)
  stability_statuses[is.na(stability_statuses)] <- "QUARANTINED"
  baseline_obs <- as.numeric(merged_df$Observed)

  # 元データにおける丸め前倍精度の期待度数を算出 (F-CRR-002)
  counts_orig_arr <- array(obs_canon, dim = c(I, J, K_dim))
  baseline_exp_raw <- if (target_model == "M1") {
    refit_m1_closed_form(counts_orig_arr, I, J, K_dim, total_n)
  } else if (target_model == "M5") {
    refit_m5_closed_form(counts_orig_arr, I, J, K_dim)
  } else {
    NULL
  }
  if (is.null(baseline_exp_raw) || any(is.na(baseline_exp_raw))) {
    return(list(
      status = "MODEL_REFIT_FAILED",
      hold_reason = sprintf("元データに対する基準モデル（%s）の閉形式再推定が失敗（NULLまたはNA）したため、表示用丸め値へのフォールバックを行わず順位再現性評価を安全に保留します。", target_model),
      audit_metadata = list(
        feature_version = "1.0.0",
        target_baseline_model = target_model,
        target_metric = target_metric,
        top_k = top_k,
        iterations_requested = iterations,
        iterations_valid = 0L,
        valid_rate = 0.0,
        seed = seed,
        resampling_model = "Multinomial(N, p_hat)",
        resampling_unit = "individual observations classified into contingency-table cells",
        required_assumption = "観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる",
        zero_cell_handling = "continuity_correction_0.5_on_replicate_zero_observed",
        model_refitting = "closed_form_mle_per_replicate",
        tie_breaking_rule = "canonical_cell_index_ascending",
        factor_levels_order = factor_levels_order
      ),
      estimand_conditioning = list(
        target_universe = "regular_cells_under_baseline_model",
        conditioning_statement = "元データで対象基準モデルにおいて REGULAR 判定された適格セル集合、かつモデル再推定が数値的・理論的に有効な反復のみに条件付けられた選択頻度",
        eligible_cell_count = 0L,
        quarantined_cell_count = total_cells,
        total_grid_cells = total_cells
      ),
      quality_gate = list(
        passed = FALSE,
        threshold = qg_min_rate,
        valid_rate = 0.0,
        invalid_breakdown = list(
          zero_denominator = 0L,
          rank_deficient = 0L,
          non_convergence = 0L,
          numerical_instability = 0L
        )
      ),
      cells = NULL
    ))
  }
  baseline_exp <- baseline_exp_raw

  is_regular <- stability_statuses == "REGULAR"
  eligible_cell_count <- sum(is_regular)
  quarantined_cell_count <- total_cells - eligible_cell_count

  # 第2段階バリデーション: 適格セル数チェック
  if (eligible_cell_count == 0L) {
    return(list(
      status = "NO_ELIGIBLE_CELLS",
      hold_reason = "元データ診断において REGULAR な適格セルが 0 件のため、順位再現性評価を保留します。",
      audit_metadata = list(
        feature_version = "1.0.0",
        target_baseline_model = target_model,
        target_metric = target_metric,
        top_k = top_k,
        iterations_requested = iterations,
        iterations_valid = 0L,
        valid_rate = 0.0,
        seed = seed,
        resampling_model = "Multinomial(N, p_hat)",
        resampling_unit = "individual observations classified into contingency-table cells",
        required_assumption = "観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる",
        zero_cell_handling = "continuity_correction_0.5_on_replicate_zero_observed",
        model_refitting = "closed_form_mle_per_replicate",
        tie_breaking_rule = "canonical_cell_index_ascending",
        factor_levels_order = factor_levels_order
      ),
      estimand_conditioning = list(
        target_universe = "regular_cells_under_baseline_model",
        conditioning_statement = "元データで対象基準モデルにおいて REGULAR 判定された適格セル集合、かつモデル再推定が数値的・理論的に有効な反復のみに条件付けられた選択頻度",
        eligible_cell_count = 0L,
        quarantined_cell_count = quarantined_cell_count,
        total_grid_cells = total_cells
      ),
      quality_gate = list(
        passed = FALSE,
        threshold = qg_min_rate,
        valid_rate = 0.0,
        invalid_breakdown = list(
          zero_denominator = 0L,
          rank_deficient = 0L,
          non_convergence = 0L,
          numerical_instability = 0L
        )
      ),
      cells = NULL
    ))
  }

  if (top_k > eligible_cell_count) {
    stop(sprintf("[ERROR] top_k (%d) が適格セル数 (%d) を超過しています。top_k <= eligible_cell_count を満たす必要があります。",
                 top_k, eligible_cell_count), call. = FALSE)
  }

  # 元データにおける abs_log_oe と元順位の計算
  baseline_abs_log_oe <- numeric(total_cells)
  for (idx in seq_len(total_cells)) {
    o_val <- baseline_obs[idx]
    e_val <- baseline_exp[idx]
    if (!is.na(e_val) && e_val > 0) {
      if (o_val > 0) {
        baseline_abs_log_oe[idx] <- abs(log(o_val / e_val))
      } else {
        baseline_abs_log_oe[idx] <- abs(log(0.5 / e_val))
      }
    } else {
      baseline_abs_log_oe[idx] <- NA_real_
    }
  }

  reg_indices <- which(is_regular)
  base_reg_metrics <- baseline_abs_log_oe[reg_indices]
  base_reg_can_idx <- canonical_grid$canonical_cell_index[reg_indices]

  # 決定論的タイブレーク: -metric 昇順, canonical_cell_index 昇順
  base_ord <- order(-base_reg_metrics, base_reg_can_idx)
  base_ranks_among_reg <- integer(eligible_cell_count)
  base_ranks_among_reg[base_ord] <- seq_len(eligible_cell_count)

  baseline_ranks_full <- rep(NA_integer_, total_cells)
  baseline_ranks_full[reg_indices] <- base_ranks_among_reg
  baseline_selected_top_k_full <- rep(FALSE, total_cells)
  baseline_selected_top_k_full[reg_indices] <- base_ranks_among_reg <= top_k

  # 多項乱数生成
  hat_p <- obs_canon / total_n
  set.seed(seed)
  resamples <- rmultinom(n = iterations, size = total_n, prob = hat_p)

  invalid_breakdown <- list(
    zero_denominator = 0L,
    rank_deficient = 0L,
    non_convergence = 0L,
    numerical_instability = 0L
  )

  valid_ranks_matrix <- matrix(NA_integer_, nrow = iterations, ncol = eligible_cell_count)
  n_valid <- 0L

  for (b in seq_len(iterations)) {
    y_b <- resamples[, b]
    counts_arr <- array(y_b, dim = c(I, J, K_dim))

    mu_b <- if (target_model == "M1") {
      refit_m1_closed_form(counts_arr, I, J, K_dim, total_n)
    } else if (target_model == "M5") {
      refit_m5_closed_form(counts_arr, I, J, K_dim)
    } else {
      NULL
    }

    if (is.null(mu_b) || any(is.na(mu_b)) || any(mu_b <= 0)) {
      invalid_breakdown$rank_deficient <- invalid_breakdown$rank_deficient + 1L
      next
    }

    # 各セルの abs_log_oe 計算（y_b == 0 のときは 0.5 補正）
    # y_b > 0: abs(log(y_b / mu_b))
    # y_b == 0: abs(log(0.5 / mu_b))
    metric_b <- ifelse(y_b > 0, abs(log(y_b / mu_b)), abs(log(0.5 / mu_b)))

    # 適格セルのみ抽出
    reg_metric_b <- metric_b[reg_indices]

    # タイブレーク順位付け
    ord_b <- order(-reg_metric_b, base_reg_can_idx)
    ranks_b <- integer(eligible_cell_count)
    ranks_b[ord_b] <- seq_len(eligible_cell_count)

    n_valid <- n_valid + 1L
    valid_ranks_matrix[n_valid, ] <- ranks_b
  }

  valid_rate <- if (iterations > 0L) n_valid / iterations else 0.0
  gate_passed <- valid_rate >= qg_min_rate

  if (!gate_passed) {
    return(list(
      status = "INSUFFICIENT_VALID_REPLICATES",
      hold_reason = sprintf("有効反復率 (%.2f%%) が運用品質基準 (%.2f%%) 未満のため、評価を保留します。", valid_rate * 100, qg_min_rate * 100),
      audit_metadata = list(
        feature_version = "1.0.0",
        target_baseline_model = target_model,
        target_metric = target_metric,
        top_k = top_k,
        iterations_requested = iterations,
        iterations_valid = n_valid,
        valid_rate = safe_round(valid_rate, 4),
        seed = seed,
        resampling_model = "Multinomial(N, p_hat)",
        resampling_unit = "individual observations classified into contingency-table cells",
        required_assumption = "観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる",
        zero_cell_handling = "continuity_correction_0.5_on_replicate_zero_observed",
        model_refitting = "closed_form_mle_per_replicate",
        tie_breaking_rule = "canonical_cell_index_ascending",
        factor_levels_order = factor_levels_order
      ),
      estimand_conditioning = list(
        target_universe = "regular_cells_under_baseline_model",
        conditioning_statement = "元データで対象基準モデルにおいて REGULAR 判定された適格セル集合、かつモデル再推定が数値的・理論的に有効な反復のみに条件付けられた選択頻度",
        eligible_cell_count = eligible_cell_count,
        quarantined_cell_count = quarantined_cell_count,
        total_grid_cells = total_cells
      ),
      quality_gate = list(
        passed = FALSE,
        threshold = qg_min_rate,
        valid_rate = safe_round(valid_rate, 4),
        invalid_breakdown = invalid_breakdown
      ),
      cells = NULL
    ))
  }

  valid_ranks <- valid_ranks_matrix[seq_len(n_valid), , drop = FALSE]

  # 各適格セルの要約統計量
  cells_output <- vector("list", eligible_cell_count)
  for (k_idx in seq_len(eligible_cell_count)) {
    orig_cell_idx <- reg_indices[k_idx]
    c_ranks <- valid_ranks[, k_idx]

    sel_top_k <- c_ranks <= top_k
    p_hat <- mean(sel_top_k)
    mcse_val <- sqrt(p_hat * (1.0 - p_hat) / n_valid)

    mean_r <- mean(c_ranks)
    sd_r <- if (n_valid > 1L) sd(c_ranks) else 0.0
    med_r <- as.numeric(median(c_ranks))
    q_r <- quantile(c_ranks, probs = c(0.25, 0.75))
    iqr_r <- as.numeric(q_r[2L] - q_r[1L])
    min_r <- as.integer(min(c_ranks))
    max_r <- as.integer(max(c_ranks))

    base_r <- base_ranks_among_reg[k_idx]
    mean_shift <- mean_r - base_r
    median_shift <- med_r - base_r

    factors_list <- list()
    factors_list[[v1]] <- canonical_grid[[v1]][orig_cell_idx]
    factors_list[[v2]] <- canonical_grid[[v2]][orig_cell_idx]
    factors_list[[v3]] <- canonical_grid[[v3]][orig_cell_idx]

    cells_output[[k_idx]] <- list(
      canonical_cell_index = canonical_grid$canonical_cell_index[orig_cell_idx],
      cell_id = canonical_grid$cell_id[orig_cell_idx],
      factors = factors_list,
      baseline_stability = "REGULAR",
      baseline_abs_log_oe = safe_round(baseline_abs_log_oe[orig_cell_idx], 4),
      baseline_rank_among_regular = as.integer(base_r),
      baseline_selected_top_k = as.logical(base_r <= top_k),
      top_k_selection_frequency_among_regular_cells = list(
        estimate = safe_round(p_hat, 4),
        mcse = safe_round(mcse_val, 4)
      ),
      rank_summary_among_regular_cells = list(
        mean_rank = safe_round(mean_r, 2),
        sd_rank = safe_round(sd_r, 2),
        median_rank = safe_round(med_r, 1),
        iqr_rank = safe_round(iqr_r, 1),
        min_rank = min_r,
        max_rank = max_r
      ),
      rank_shifts = list(
        mean_shift = safe_round(mean_shift, 2),
        median_shift = safe_round(median_shift, 1)
      )
    )
  }

  list(
    status = "COMPUTED",
    audit_metadata = list(
      feature_version = "1.0.0",
      target_baseline_model = target_model,
      target_metric = target_metric,
      top_k = top_k,
      iterations_requested = iterations,
      iterations_valid = n_valid,
      valid_rate = safe_round(valid_rate, 4),
      seed = seed,
      resampling_model = "Multinomial(N, p_hat)",
      resampling_unit = "individual observations classified into contingency-table cells",
      required_assumption = "観測単位は独立で、同一のカテゴリ確率ベクトルから抽出されたとみなせる",
      zero_cell_handling = "continuity_correction_0.5_on_replicate_zero_observed",
      model_refitting = "closed_form_mle_per_replicate",
      tie_breaking_rule = "canonical_cell_index_ascending",
      factor_levels_order = factor_levels_order
    ),
    estimand_conditioning = list(
      target_universe = "regular_cells_under_baseline_model",
      conditioning_statement = "元データで対象基準モデルにおいて REGULAR 判定された適格セル集合、かつモデル再推定が数値的・理論的に有効な反復のみに条件付けられた選択頻度",
      eligible_cell_count = eligible_cell_count,
      quarantined_cell_count = quarantined_cell_count,
      total_grid_cells = total_cells
    ),
    quality_gate = list(
      passed = TRUE,
      threshold = qg_min_rate,
      valid_rate = safe_round(valid_rate, 4),
      invalid_breakdown = invalid_breakdown
    ),
    cells = cells_output
  )
}

