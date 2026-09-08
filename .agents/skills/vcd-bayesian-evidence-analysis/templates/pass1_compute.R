# =============================================================================
# vcd-bayesian-evidence-analysis: pass1_compute.R
# 新4軸統計基盤（Effect x Evidence x Influence x Stability）コア計算モジュール
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

# --- [1. モデル仕様辞書と生成クラス（generators）正本定義] ---

# 辞書本体は最小限の構成メタデータ（id, model_key, name, order, generators）のみを定義する。
# ブラケット表記、独立性構造、LaTeX数式、展開項、日本語説明はすべて generators から一元的に自動導出する。

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

# generators からブラケット記法（例: [AB][AC]）を一元導出
build_bracket_notation <- function(generators) {
  gen_strs <- vapply(generators, function(gen) {
    sprintf("[%s]", paste(sort(as.character(gen)), collapse = ""))
  }, character(1))
  paste(gen_strs, collapse = "")
}

# generators から独立性構造を一元導出
derive_independence_structure <- function(generators, factor_map = NULL) {
  # 正規化ブラケット表記をキーとして構造判定
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

# generators から LaTeX 数式および日本語説明を一元導出
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

# 因子記号と実変数の対応マップ構築
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

# generators から R formula の右辺項を生成
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

# 階層原理に基づき generators から期待される全展開項の正規化集合を導出
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

# R formula の展開項と generators の期待項集合が完全一致（setequal）することを検証
validate_formula_terms <- function(fmla, generators, factor_map) {
  expected_terms <- expand_generator_terms(generators, factor_map)
  f_terms <- attr(stats::terms(fmla), "term.labels")
  
  # formula 側の各項ラベル（A:B等）をソートして正規化
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

# モデル仕様から実変数を反映したメタデータ（bracket_notation, bracket_expanded, independence, formula_latex 等）を一元導出
derive_model_metadata <- function(spec, factor_map, fit = NULL) {
  sym_to_var <- vapply(factor_map, function(x) x$variable, character(1))
  sym_to_label <- vapply(factor_map, function(x) x$label, character(1))
  
  generators <- spec$generators
  bracket_notation <- build_bracket_notation(generators)
  
  # bracket_expanded (例: [Dept, Gender][Dept, Admit])
  gen_expanded <- vapply(generators, function(gen) {
    real_vars <- sym_to_var[gen]
    sprintf("[%s]", paste(real_vars, collapse = ", "))
  }, character(1))
  bracket_expanded <- paste(gen_expanded, collapse = "")
  
  # 独立性構造の一元導出
  indep_raw <- derive_independence_structure(generators, factor_map)
  
  # 日本語説明の生成（変数名を埋め込む）
  desc_ja <- indep_raw$base_description
  for (sym in names(factor_map)) {
    var_name <- sym_to_var[[sym]]
    label <- sym_to_label[[sym]]
    target_text <- if (!is.null(label) && nzchar(label) && var_name != label) sprintf("%s（%s）", label, var_name) else var_name
    # 記号 A, B, C を実変数表記に置換（マルチバイト文字列に対応したアルファベット境界）
    pat <- sprintf("(?<![A-Za-z])%s(?![A-Za-z])", sym)
    desc_ja <- gsub(pat, target_text, desc_ja, perl = TRUE)
  }
  
  fitted_fmla_str <- if (!is.null(fit)) {
    paste(deparse(formula(fit)), collapse = " ")
  } else {
    NULL
  }
  
  # 数式メタデータの一元導出
  fmla_meta <- derive_formula_metadata(generators, factor_map)
  
  # independence statements の left, right, given に AsIs を保持
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

# モデル定義と実適合式の項レベル整合性検証関数
is_definition_consistent_with_formula <- function(definition, fitted_formula_str, factor_map) {
  if (is.null(definition) || is.null(fitted_formula_str) || !nzchar(trimws(fitted_formula_str))) {
    return(FALSE)
  }
  expected_terms <- expand_generator_terms(definition$generators, factor_map)
  fmla <- tryCatch(as.formula(fitted_formula_str), error = function(e) NULL)
  if (is.null(fmla)) return(FALSE)
  
  f_terms <- tryCatch(attr(stats::terms(fmla), "term.labels"), error = function(e) NULL)
  if (is.null(f_terms)) return(FALSE)
  
  f_terms_norm <- vapply(strsplit(f_terms, ":"), function(parts) {
    paste(sort(parts), collapse = ":")
  }, character(1))
  
  setequal(expected_terms, f_terms_norm)
}


# --- [2. モデル適合と総度数N基準の明示式BIC算出] ---
fit_all_poisson_models <- function(df, vars, freq_col) {
  total_n <- sum(df[[freq_col]])
  n_vars <- length(vars)
  
  if (n_vars < 2L || n_vars > 3L) {
    stop(sprintf("[ERROR] vcd-bayesian-evidence-analysis は 2元表または 3元表（2変数または3変数）のみをサポートしています（指定変数数: %d）。4変数以上の場合は Pass 0 にて次元削減・層別化・3変数への絞り込みを行ってください。", n_vars))
  }
  
  factor_map <- build_factor_map(vars)
  specs <- if (n_vars == 3L) MODEL_SPECS_3WAY else MODEL_SPECS_2WAY
  
  fits <- list()
  summary_table <- list()
  definitions <- list()
  
  for (m_id in names(specs)) {
    spec <- specs[[m_id]]
    fmla <- build_formula_from_generators(spec$generators, factor_map, freq_col)
    
    # 階層原理に基づく展開項の完全一致（setequal）検証
    validate_formula_terms(fmla, spec$generators, factor_map)
    
    fit <- tryCatch({
      glm(fmla, data = df, family = poisson(), x = TRUE)
    }, error = function(e) NULL)
    
    # 数理メタデータの導出（実変数展開、独立性説明、式文字列）
    meta <- derive_model_metadata(spec, factor_map, fit)
    definitions[[m_id]] <- meta
    
    if (!is.null(fit)) {
      ll <- as.numeric(stats::logLik(fit))
      k_param <- attr(stats::logLik(fit), "df")
      dev <- fit$deviance
      df_res <- fit$df.residual
      # 総度数 N 基準の明示式 BIC (Poisson尤度ベース)
      # BIC = -2*logLik + k_param * log(N)
      # 切片を含む対数線形モデルではモデル間差は多項BICと完全一致
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
compute_4axis_cell_diagnostics <- function(df, vars, freq_col, fitted_models, base_model_id = "M1") {
  base_m <- fitted_models$models[[base_model_id]] %||% fitted_models$models[[1L]]
  total_n <- sum(df[[freq_col]])
  n_rows <- nrow(df)
  
  y <- df[[freq_col]]
  exp_val <- base_m$fitted_values
  res_p <- base_m$residuals_pearson
  res_d <- base_m$residuals_deviance
  lev <- base_m$leverage
  
  # 4軸指標の算出
  # 1. Effect (標本数不変)
  obs_exp_ratio <- ifelse(exp_val > 0, y / exp_val, NA_real_)
  log_oe_ratio <- ifelse(y > 0 & exp_val > 0, log(y / exp_val),
                         ifelse(y == 0 & exp_val > 0, log(0.5 / exp_val), NA_real_))
  rate_diff <- (y - exp_val) / total_n
  scaled_diff <- ifelse(exp_val > 0, (y - exp_val) / sqrt(exp_val * total_n), NA_real_) # e_i = d_i / sqrt(N)
  
  # 2. Evidence (検定統計量・標本数比例)
  # Rao スコア検定統計量: T_i^{score} = r_{P,i}^2 / (1 - h_{ii})
  h_denom <- pmax(1 - lev, 1e-4)
  score_stat <- (res_p^2) / h_denom
  p_val <- pchisq(score_stat, df = 1, lower.tail = FALSE)
  log_p <- pchisq(score_stat, df = 1, lower.tail = FALSE, log.p = TRUE)
  
  # 3. Influence (梃子力)
  leverage <- lev
  
  # 4. Stability (数値的安定性)
  is_zero <- y == 0
  is_sparse <- exp_val < 5.0
  is_high_lev <- lev >= 0.80
  is_quarantined <- is_zero | is_sparse | is_high_lev
  stability_status <- ifelse(is_quarantined, "QUARANTINED", "REGULAR")
  
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
  
  # 優先度順ソート（局所効果比の絶対値降順、またはScore降順）
  diag_df <- diag_df %>% dplyr::arrange(dplyr::desc(abs(log_oe_ratio)))
  
  list(
    base_model_id = base_m$id,
    base_model_name = base_m$name,
    cell_table = diag_df,
    regular_count = sum(stability_status == "REGULAR"),
    quarantined_count = sum(stability_status == "QUARANTINED")
  )
}

# --- [4. ベイズDirichlet事後推論と条件付き割合差] ---
compute_dirichlet_posterior <- function(df, vars, freq_col, response_var = NULL, draws = 20000, seed = 20260906) {
  set.seed(seed)
  y <- df[[freq_col]]
  K <- length(y)
  total_n <- sum(y)
  
  # 一様事前分布 a_0 = 1.0 (各セル α_i = y_i + 1)
  alpha_post <- y + 1.0
  alpha_0 <- sum(alpha_post)
  
  # 解析的事後平均・周辺95%信用区間 (Beta周辺分布)
  post_mean <- alpha_post / alpha_0
  ci_lower <- qbeta(0.025, alpha_post, alpha_0 - alpha_post)
  ci_upper <- qbeta(0.975, alpha_post, alpha_0 - alpha_post)
  
  # モンテカルロサンプリング (Gamma分布から生成)
  gamma_draws <- matrix(rgamma(K * draws, shape = rep(alpha_post, each = draws), rate = 1),
                        nrow = draws, ncol = K)
  sum_gamma <- rowSums(gamma_draws)
  pi_draws <- gamma_draws / sum_gamma # [draws x K]
  
  conditional_diffs <- list()
  
  # 応答変数がある場合、条件付き確率と層間差を計算
  if (!is.null(response_var) && response_var %in% vars && length(vars) >= 2L) {
    strata_vars <- setdiff(vars, response_var)
    resp_levels <- levels(factor(df[[response_var]]))
    target_level <- resp_levels[length(resp_levels)] # 通常 "Yes" または最後の水準
    
    # 層の定義
    strata_factor <- interaction(df[strata_vars], drop = TRUE, sep = ".")
    unique_strata <- levels(strata_factor)
    
    strata_rates <- list()
    for (st in unique_strata) {
      idx_denom <- which(strata_factor == st)
      idx_num <- which(strata_factor == st & df[[response_var]] == target_level)
      if (length(idx_denom) > 0 && length(idx_num) > 0) {
        # 各ドローでの条件付き割合: sum(pi_num) / sum(pi_denom)
        if (length(idx_denom) == 1L) {
          denom_draws <- pi_draws[, idx_denom]
        } else {
          denom_draws <- rowSums(pi_draws[, idx_denom, drop = FALSE])
        }
        if (length(idx_num) == 1L) {
          num_draws <- pi_draws[, idx_num]
        } else {
          num_draws <- rowSums(pi_draws[, idx_num, drop = FALSE])
        }
        cond_draws <- num_draws / pmax(denom_draws, 1e-12)
        strata_rates[[st]] <- cond_draws
      }
    }
    
    # 代表的な層間ペア差を算出
    strata_names <- names(strata_rates)
    if (length(strata_names) >= 2L) {
      for (i in 1:(length(strata_names) - 1L)) {
        for (j in (i + 1L):length(strata_names)) {
          s1 <- strata_names[i]
          s2 <- strata_names[j]
          diff_draws <- strata_rates[[s1]] - strata_rates[[s2]]
          pair_key <- paste0(s1, "_vs_", s2)
          conditional_diffs[[pair_key]] <- list(
            stratum_1 = s1,
            stratum_2 = s2,
            target_response = target_level,
            difference_mean = safe_round(mean(diff_draws), 4),
            ci_95 = safe_round(quantile(diff_draws, probs = c(0.025, 0.975)), 4),
            prob_positive = safe_round(mean(diff_draws > 0), 4)
          )
        }
      }
    }
  }
  
  list(
    analytical = list(
      posterior_mean = round(post_mean, 6),
      ci_95_lower = round(ci_lower, 6),
      ci_95_upper = round(ci_upper, 6)
    ),
    conditional_differences = conditional_diffs
  )
}
