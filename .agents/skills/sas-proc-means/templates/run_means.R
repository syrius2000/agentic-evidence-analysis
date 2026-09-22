#!/usr/bin/env Rscript
# SAS PROC MEANS Compatible Descriptive Statistics Engine in R
# Script: run_means.R

suppressPackageStartupMessages({
  library(jsonlite)
})

find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  getwd()
}
repo_root <- find_agent_repo()
run_scope_path <- file.path(repo_root, ".agents", "shared", "run_scope.R")
if (file.exists(run_scope_path)) {
  source(run_scope_path)
}

# -----------------------------------------------------------------------------
# 1. Helper & Validation Functions
# -----------------------------------------------------------------------------

parse_args <- function(args) {
  config_path <- NULL
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--config" && i < length(args)) {
      config_path <- args[i + 1]
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  if (is.null(config_path)) {
    stop("Error: --config <path_to_analysis_config.json> is required.")
  }
  config_path
}

validate_config <- function(cfg) {
  if (is.null(cfg$schema_version) || cfg$schema_version != "sas-summary-config-v1") {
    stop("Invalid schema_version: expected 'sas-summary-config-v1'")
  }
  if (is.null(cfg$analysis_kind) || cfg$analysis_kind != "sas_proc_means") {
    stop("Invalid analysis_kind: expected 'sas_proc_means'")
  }
  if (is.null(cfg$input) || !is.character(cfg$input) || nchar(cfg$input) == 0) {
    stop("Missing or invalid 'input' path in config.")
  }
  if (!file.exists(cfg$input)) {
    stop(sprintf("Input file not found: %s", cfg$input))
  }
  if (is.null(cfg$output_dir) || !is.character(cfg$output_dir) || nchar(cfg$output_dir) == 0) {
    stop("Missing or invalid 'output_dir' in config.")
  }
  if (is.null(cfg$run_id) || !is.character(cfg$run_id) || nchar(cfg$run_id) == 0) {
    stop("Missing or invalid 'run_id' in config.")
  }
  cfg$analysis_variables <- as.character(unlist(cfg$analysis_variables))
  if (length(cfg$analysis_variables) == 0) {
    stop("analysis_variables must be a non-empty array of variable names.")
  }

  # Defaults
  if (is.null(cfg$class_variables)) {
    cfg$class_variables <- character(0)
  } else {
    cfg$class_variables <- as.character(unlist(cfg$class_variables))
  }
  if (is.null(cfg$vardef)) cfg$vardef <- "DF"
  if (!cfg$vardef %in% c("DF", "N", "WDF", "WEIGHT")) {
    stop(sprintf("Invalid vardef: %s (must be DF, N, WDF, or WEIGHT)", cfg$vardef))
  }
  if (is.null(cfg$qntldef)) cfg$qntldef <- 5L
  if (!cfg$qntldef %in% 1:5) {
    stop(sprintf("Invalid qntldef: %s (must be 1, 2, 3, 4, or 5)", cfg$qntldef))
  }
  if (is.null(cfg$exclnpwgt)) cfg$exclnpwgt <- FALSE
  if (is.null(cfg$class_missing)) cfg$class_missing <- FALSE
  if (is.null(cfg$alpha)) cfg$alpha <- 0.05
  if (cfg$alpha <= 0 || cfg$alpha >= 1) {
    stop("alpha must be in (0, 1).")
  }

  cfg
}

# -----------------------------------------------------------------------------
# 2. Quantile Calculations (QNTLDEF 1-5 & Weighted)
# -----------------------------------------------------------------------------

compute_quantile_unweighted <- function(x, p, qntldef) {
  # SAS QNTLDEF mapping to R stats::quantile types:
  # 1: Empirical distribution function with averaging (R type 4)
  # 2: Closest observation (R type 3)
  # 3: Empirical distribution function (R type 1)
  # 4: Linear interpolation with endpoints (R type 6)
  # 5: Weighted average at empirical distribution percentiles - default (R type 2)
  r_type <- switch(as.character(qntldef),
    "1" = 4L,
    "2" = 3L,
    "3" = 1L,
    "4" = 6L,
    "5" = 2L,
    2L
  )
  as.numeric(stats::quantile(x, probs = p, type = r_type, na.rm = TRUE, names = FALSE))
}

compute_quantile_weighted <- function(x, w, p, qntldef = 5L) {
  # Weighted quantile calculation based on cumulative weight
  ord <- order(x)
  x_sorted <- x[ord]
  w_sorted <- w[ord]
  total_w <- sum(w_sorted)
  if (total_w <= 0) return(rep(NA_real_, length(p)))

  cum_w <- cumsum(w_sorted)
  res <- numeric(length(p))

  for (k in seq_along(p)) {
    target_w <- p[k] * total_w
    # Step-function percentile based on SAS WEIGHT quantile logic
    idx <- which(cum_w >= target_w - 1e-12)[1]
    if (is.na(idx)) idx <- length(x_sorted)

    if (abs(cum_w[idx] - target_w) < 1e-12 && idx < length(x_sorted) && qntldef == 5L) {
      # Average adjacent if exactly on boundary in definition 5
      res[k] <- (x_sorted[idx] + x_sorted[idx + 1]) / 2
    } else {
      res[k] <- x_sorted[idx]
    }
  }
  res
}

# -----------------------------------------------------------------------------
# 3. Core Statistics Calculation for a Variable
# -----------------------------------------------------------------------------

compute_var_stats <- function(x_raw, freq_raw, weight_raw, vardef, qntldef, alpha, exclnpwgt, has_weight) {
  total_n_miss <- sum(freq_raw[is.na(x_raw)])

  # Filter to non-missing x
  valid_mask <- !is.na(x_raw)
  x <- x_raw[valid_mask]
  freq <- freq_raw[valid_mask]
  weight <- weight_raw[valid_mask]

  n_obs <- sum(freq)

  if (n_obs == 0L) {
    return(list(
      N = 0L,
      NMISS = total_n_miss,
      SUMWGT = 0,
      MEAN = NULL,
      SUM = NULL,
      MIN = NULL,
      MAX = NULL,
      RANGE = NULL,
      CSS = NULL,
      USS = NULL,
      VAR = NULL,
      STD = NULL,
      CV = NULL,
      STDERR = NULL,
      LCLM = NULL,
      UCLM = NULL,
      SKEWNESS = NULL,
      KURTOSIS = NULL,
      MEDIAN = NULL,
      Q1 = NULL,
      Q3 = NULL,
      QRANGE = NULL,
      P1 = NULL,
      P5 = NULL,
      P10 = NULL,
      P90 = NULL,
      P95 = NULL,
      P99 = NULL,
      status_reasons = list(MEAN = "no_valid_observations")
    ))
  }

  status_reasons <- list()

  # Effective weight per row: f_i * w_i
  w_eff <- freq * weight
  sum_w <- sum(w_eff)
  sum_x <- sum(w_eff * x)
  mean_x <- if (sum_w > 0) sum_x / sum_w else NA_real_

  min_x <- min(x)
  max_x <- max(x)
  range_x <- max_x - min_x

  uss <- sum(w_eff * (x^2))
  css <- sum(w_eff * ((x - mean_x)^2))

  # VARDEF divisor
  d <- switch(vardef,
    "DF" = n_obs - 1,
    "N" = n_obs,
    "WDF" = sum_w - 1,
    "WEIGHT" = sum_w,
    n_obs - 1
  )

  var_x <- if (!is.na(d) && d > 0) css / d else NULL
  std_x <- if (!is.null(var_x) && var_x >= 0) sqrt(var_x) else NULL

  cv_x <- if (!is.null(std_x) && !is.na(mean_x) && abs(mean_x) > 1e-15) {
    100 * (std_x / mean_x)
  } else if (!is.null(std_x) && !is.na(mean_x) && abs(mean_x) <= 1e-15) {
    status_reasons$CV <- "mean_is_zero"
    NULL
  } else {
    NULL
  }

  # STDERR, LCLM, UCLM (only valid for VARDEF=DF)
  if (vardef == "DF") {
    if (!is.null(std_x) && sum_w > 0 && n_obs > 1) {
      stderr_x <- std_x / sqrt(sum_w)
      df_t <- n_obs - 1
      t_crit <- stats::qt(1 - alpha / 2, df_t)
      lclm_x <- mean_x - t_crit * stderr_x
      uclm_x <- mean_x + t_crit * stderr_x
    } else {
      stderr_x <- NULL
      lclm_x <- NULL
      uclm_x <- NULL
      status_reasons$STDERR <- "insufficient_degrees_of_freedom"
      status_reasons$LCLM <- "insufficient_degrees_of_freedom"
      status_reasons$UCLM <- "insufficient_degrees_of_freedom"
    }
  } else {
    stderr_x <- NULL
    lclm_x <- NULL
    uclm_x <- NULL
    status_reasons$STDERR <- "undefined_for_vardef"
    status_reasons$LCLM <- "undefined_for_vardef"
    status_reasons$UCLM <- "undefined_for_vardef"
  }

  # SKEWNESS & KURTOSIS
  if (has_weight) {
    skew_x <- NULL
    kurt_x <- NULL
    status_reasons$SKEWNESS <- "not_available_with_weight"
    status_reasons$KURTOSIS <- "not_available_with_weight"
  } else {
    # Unweighted skewness and excess kurtosis
    # Expand by frequency if needed for moment calculations
    x_expanded <- rep(x, freq)
    n_exp <- length(x_expanded)

    if (vardef == "DF") {
      if (n_exp >= 3) {
        s <- sqrt(sum((x_expanded - mean_x)^2) / (n_exp - 1))
        if (s > 1e-15) {
          m3 <- sum((x_expanded - mean_x)^3)
          skew_x <- (n_exp / ((n_exp - 1) * (n_exp - 2))) * (m3 / (s^3))
        } else {
          skew_x <- 0.0
        }
      } else {
        skew_x <- NULL
        status_reasons$SKEWNESS <- "insufficient_sample_size"
      }

      if (n_exp >= 4) {
        s <- sqrt(sum((x_expanded - mean_x)^2) / (n_exp - 1))
        if (s > 1e-15) {
          m4 <- sum((x_expanded - mean_x)^4)
          kurt_x <- ((n_exp * (n_exp + 1)) / ((n_exp - 1) * (n_exp - 2) * (n_exp - 3))) * (m4 / (s^4)) -
            ((3 * (n_exp - 1)^2) / ((n_exp - 2) * (n_exp - 3)))
        } else {
          kurt_x <- 0.0
        }
      } else {
        kurt_x <- NULL
        status_reasons$KURTOSIS <- "insufficient_sample_size"
      }
    } else if (vardef == "N") {
      if (n_exp >= 1) {
        m2 <- sum((x_expanded - mean_x)^2) / n_exp
        m3 <- sum((x_expanded - mean_x)^3) / n_exp
        m4 <- sum((x_expanded - mean_x)^4) / n_exp
        s_pop <- sqrt(m2)
        skew_x <- if (s_pop > 1e-15) m3 / (s_pop^3) else 0.0
        kurt_x <- if (s_pop > 1e-15) (m4 / (s_pop^4)) - 3.0 else 0.0
      } else {
        skew_x <- NULL
        kurt_x <- NULL
      }
    } else {
      skew_x <- NULL
      kurt_x <- NULL
      status_reasons$SKEWNESS <- "undefined_for_vardef"
      status_reasons$KURTOSIS <- "undefined_for_vardef"
    }
  }

  # Quantiles: MEDIAN, Q1, Q3, P1, P5, P10, P90, P95, P99
  probs <- c(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99)
  if (has_weight) {
    q_vals <- compute_quantile_weighted(x, w_eff, probs, qntldef)
  } else {
    x_expanded <- rep(x, freq)
    q_vals <- compute_quantile_unweighted(x_expanded, probs, qntldef)
  }

  p1_x <- q_vals[1]
  p5_x <- q_vals[2]
  p10_x <- q_vals[3]
  q1_x <- q_vals[4]
  median_x <- q_vals[5]
  q3_x <- q_vals[6]
  p90_x <- q_vals[7]
  p95_x <- q_vals[8]
  p99_x <- q_vals[9]
  qrange_x <- q3_x - q1_x

  list(
    N = as.integer(n_obs),
    NMISS = as.integer(total_n_miss),
    SUMWGT = sum_w,
    MEAN = mean_x,
    SUM = sum_x,
    MIN = min_x,
    MAX = max_x,
    RANGE = range_x,
    CSS = css,
    USS = uss,
    VAR = var_x,
    STD = std_x,
    CV = cv_x,
    STDERR = stderr_x,
    LCLM = lclm_x,
    UCLM = uclm_x,
    SKEWNESS = skew_x,
    KURTOSIS = kurt_x,
    MEDIAN = median_x,
    Q1 = q1_x,
    Q3 = q3_x,
    QRANGE = qrange_x,
    P1 = p1_x,
    P5 = p5_x,
    P10 = p10_x,
    P90 = p90_x,
    P95 = p95_x,
    P99 = p99_x,
    status_reasons = status_reasons
  )
}

# -----------------------------------------------------------------------------
# 4. Main Processing Routine
# -----------------------------------------------------------------------------

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- parse_args(args)
  cfg_raw <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
  cfg <- validate_config(cfg_raw)

  # Read Data
  df <- utils::read.csv(cfg$input, stringsAsFactors = FALSE, check.names = FALSE)

  # Check variables exist
  for (v in cfg$analysis_variables) {
    if (!v %in% names(df)) {
      stop(sprintf("Analysis variable not found in data: %s", v))
    }
  }
  for (cv in cfg$class_variables) {
    if (!cv %in% names(df)) {
      stop(sprintf("CLASS variable not found in data: %s", cv))
    }
  }

  has_freq <- !is.null(cfg$freq_variable) && nchar(cfg$freq_variable) > 0
  if (has_freq && !cfg$freq_variable %in% names(df)) {
    stop(sprintf("FREQ variable not found in data: %s", cfg$freq_variable))
  }

  has_weight <- !is.null(cfg$weight_variable) && nchar(cfg$weight_variable) > 0
  if (has_weight && !cfg$weight_variable %in% names(df)) {
    stop(sprintf("WEIGHT variable not found in data: %s", cfg$weight_variable))
  }

  # Setup FREQ column
  if (has_freq) {
    f_vec <- df[[cfg$freq_variable]]
    # SAS FREQ rules: floor truncation, exclude if NA or < 1
    f_vec <- floor(as.numeric(f_vec))
    f_valid <- !is.na(f_vec) & f_vec >= 1
  } else {
    f_vec <- rep(1L, nrow(df))
    f_valid <- rep(TRUE, nrow(df))
  }

  # Setup WEIGHT column
  if (has_weight) {
    w_vec <- as.numeric(df[[cfg$weight_variable]])
    # Exclude missing weights
    w_nonmiss <- !is.na(w_vec)
    if (cfg$exclnpwgt) {
      w_valid <- w_nonmiss & (w_vec > 0)
    } else {
      w_valid <- w_nonmiss
      # Non-negative correction: negative weights become 0
      w_vec[!is.na(w_vec) & w_vec < 0] <- 0
    }
  } else {
    w_vec <- rep(1.0, nrow(df))
    w_valid <- rep(TRUE, nrow(df))
  }

  # CLASS Missingness Filter
  if (length(cfg$class_variables) > 0) {
    is_class_na <- function(col) {
      is.na(col) | trimws(as.character(col)) == ""
    }
    if (cfg$class_missing) {
      # Replace NA/blank in class variables with string "(Missing)"
      for (cv in cfg$class_variables) {
        na_mask <- is_class_na(df[[cv]])
        df[[cv]][na_mask] <- "(Missing)"
      }
      class_valid <- rep(TRUE, nrow(df))
    } else {
      # Exclude rows where any CLASS variable is NA/blank
      class_na_mat <- sapply(df[cfg$class_variables], is_class_na)
      if (is.matrix(class_na_mat)) {
        class_valid <- !apply(class_na_mat, 1, any)
      } else {
        class_valid <- !class_na_mat
      }
    }
  } else {
    class_valid <- rep(TRUE, nrow(df))
  }

  # Master row inclusion mask
  include_mask <- f_valid & w_valid & class_valid
  df_sub <- df[include_mask, , drop = FALSE]
  f_sub <- f_vec[include_mask]
  w_sub <- w_vec[include_mask]

  # Run Isolation Output Directory
  prefix16 <- substr(cfg$run_id, 1, min(16, nchar(cfg$run_id)))
  run_dir <- if (exists("reserve_run_output_dir", mode = "function")) {
    reserve_run_output_dir(cfg$output_dir, "sas-proc-means", prefix16)
  } else {
    d <- file.path(cfg$output_dir, paste0("run_", prefix16))
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
    d
  }

  # Grouping Logic
  if (length(cfg$class_variables) > 0) {
    group_keys <- df_sub[cfg$class_variables]
    interaction_factor <- interaction(group_keys, drop = TRUE, sep = " | ")
    group_levels <- levels(interaction_factor)
  } else {
    interaction_factor <- factor(rep("ALL", nrow(df_sub)))
    group_levels <- "ALL"
  }

  results_by_group <- list()
  csv_rows <- list()

  for (grp in group_levels) {
    grp_mask <- interaction_factor == grp
    df_grp <- df_sub[grp_mask, , drop = FALSE]
    f_grp <- f_sub[grp_mask]
    w_grp <- w_sub[grp_mask]

    grp_result <- list(
      class_group = grp,
      variables = list()
    )

    for (v in cfg$analysis_variables) {
      x_raw <- as.numeric(df_grp[[v]])
      v_stats <- compute_var_stats(
        x_raw = x_raw,
        freq_raw = f_grp,
        weight_raw = w_grp,
        vardef = cfg$vardef,
        qntldef = cfg$qntldef,
        alpha = cfg$alpha,
        exclnpwgt = cfg$exclnpwgt,
        has_weight = has_weight
      )
      grp_result$variables[[v]] <- v_stats

      # CSV row representation (ODS Summary style)
      csv_row <- list(
        class_group = grp,
        variable = v,
        `_TYPE_` = length(cfg$class_variables),
        `_FREQ_` = v_stats$N + v_stats$NMISS,
        N = v_stats$N,
        NMISS = v_stats$NMISS,
        SUMWGT = v_stats$SUMWGT,
        MEAN = if (is.null(v_stats$MEAN)) NA else v_stats$MEAN,
        STD = if (is.null(v_stats$STD)) NA else v_stats$STD,
        MIN = if (is.null(v_stats$MIN)) NA else v_stats$MIN,
        MAX = if (is.null(v_stats$MAX)) NA else v_stats$MAX,
        RANGE = if (is.null(v_stats$RANGE)) NA else v_stats$RANGE,
        SUM = if (is.null(v_stats$SUM)) NA else v_stats$SUM,
        VAR = if (is.null(v_stats$VAR)) NA else v_stats$VAR,
        CV = if (is.null(v_stats$CV)) NA else v_stats$CV,
        STDERR = if (is.null(v_stats$STDERR)) NA else v_stats$STDERR,
        LCLM = if (is.null(v_stats$LCLM)) NA else v_stats$LCLM,
        UCLM = if (is.null(v_stats$UCLM)) NA else v_stats$UCLM,
        SKEWNESS = if (is.null(v_stats$SKEWNESS)) NA else v_stats$SKEWNESS,
        KURTOSIS = if (is.null(v_stats$KURTOSIS)) NA else v_stats$KURTOSIS,
        MEDIAN = if (is.null(v_stats$MEDIAN)) NA else v_stats$MEDIAN,
        Q1 = if (is.null(v_stats$Q1)) NA else v_stats$Q1,
        Q3 = if (is.null(v_stats$Q3)) NA else v_stats$Q3,
        QRANGE = if (is.null(v_stats$QRANGE)) NA else v_stats$QRANGE
      )
      csv_rows[[length(csv_rows) + 1]] <- csv_row
    }
    results_by_group[[grp]] <- grp_result
  }

  # Build Final JSON Output
  jst_now <- format(as.POSIXct(Sys.time(), tz = "Asia/Tokyo"), "%Y-%m-%d %H:%M:%S JST")
  input_sha256 <- digest::digest(cfg$input, file = TRUE, algo = "sha256")

  means_results <- list(
    schema_version = "sas-summary-results-v1",
    analysis_kind = "sas_proc_means",
    metadata = list(
      run_id = cfg$run_id,
      timestamp_jst = jst_now,
      input_path = cfg$input,
      input_sha256 = input_sha256,
      vardef = cfg$vardef,
      qntldef = cfg$qntldef,
      alpha = cfg$alpha,
      class_missing = cfg$class_missing,
      exclnpwgt = cfg$exclnpwgt,
      sas_parity = "unverified"
    ),
    groups = results_by_group
  )

  # Output 1: means_results.json
  json_path <- file.path(run_dir, "means_results.json")
  jsonlite::write_json(means_results, json_path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = 12)

  # Output 2: summary.csv
  csv_df <- do.call(rbind, lapply(csv_rows, function(r) as.data.frame(r, check.names = FALSE, stringsAsFactors = FALSE)))
  csv_path <- file.path(run_dir, "summary.csv")
  utils::write.csv(csv_df, csv_path, row.names = FALSE, na = "")

  # Output 3: summary_report.md (Japanese Markdown Report)
  md_path <- file.path(run_dir, "summary_report.md")
  md_con <- file(md_path, open = "w", encoding = "UTF-8")
  writeLines(c(
    "# SAS PROC MEANS 記述統計解析レポート",
    "",
    "## 実行メタデータ",
    "",
    sprintf("- **Run ID**: `%s`", cfg$run_id),
    sprintf("- **実行日時 (JST)**: %s", jst_now),
    sprintf("- **入力データ**: `%s`", cfg$input),
    sprintf("- **入力データ SHA-256**: `%s`", input_sha256),
    sprintf("- **分散定義 (VARDEF)**: `%s`", cfg$vardef),
    sprintf("- **分位数定義 (QNTLDEF)**: `%d`", cfg$qntldef),
    sprintf("- **信頼水準**: %.1f%% (alpha = %s)", (1 - cfg$alpha) * 100, cfg$alpha),
    sprintf("- **非正重み除外 (exclnpwgt)**: %s", if (cfg$exclnpwgt) "有効 (除外)" else "無効 (0扱い)"),
    sprintf("- **CLASS欠損保持 (class_missing)**: %s", if (cfg$class_missing) "有効 (群保持)" else "無効 (除外)"),
    sprintf("- **SAS Parity 状態**: `%s`", "unverified"),
    "",
    "## 適用された制約・境界条件 (Constraints & Non-Claims)",
    "",
    "- **ビット単位一致の非保証**: 浮動小数点演算順序や実行環境差による最下位ビットの差異は許容されます。",
    "- **全SAS構文再現の対象外**: QMETHOD=P2、FORMAT群化等は対象外の限定互換です。",
    "- **規制提出適格性の非主張**: 探索的解析目的であり規制当局申請適格性を主張するものではありません。",
    "- **重み指定時の歪度・尖度**: SAS仕様に基づき、WEIGHT指定時は重み付き歪度・尖度を未定義（null）としています。",
    if (cfg$vardef != "DF") sprintf("- **STDERR / 信頼区間**: VARDEF=%s のため、SAS仕様に基づき未定義（null）としています。", cfg$vardef) else NULL,
    "",
    "## 群別要約統計量テーブル",
    ""
  ), md_con)

  # Write summary table per group
  for (grp in names(results_by_group)) {
    writeLines(sprintf("### 群: %s\n", grp), md_con)
    writeLines("| 変数 | N | NMISS | 平均 (MEAN) | 標準偏差 (STD) | 最小値 (MIN) | 中央値 (MEDIAN) | 最大値 (MAX) | 範囲 (RANGE) |", md_con)
    writeLines("| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |", md_con)

    grp_vars <- results_by_group[[grp]]$variables
    for (v in names(grp_vars)) {
      st <- grp_vars[[v]]
      fmt_num <- function(val) if (is.null(val) || is.na(val)) "-" else sprintf("%.4f", val)
      writeLines(sprintf(
        "| %s | %d | %d | %s | %s | %s | %s | %s | %s |",
        v, st$N, st$NMISS, fmt_num(st$MEAN), fmt_num(st$STD), fmt_num(st$MIN),
        fmt_num(st$MEDIAN), fmt_num(st$MAX), fmt_num(st$RANGE)
      ), md_con)
    }
    writeLines("", md_con)
  }
  close(md_con)

  # Output 4: analysis_config.json (copy of configuration)
  cfg_copy_path <- file.path(run_dir, "analysis_config.json")
  jsonlite::write_json(cfg, cfg_copy_path, auto_unbox = TRUE, pretty = TRUE)

  # Output 5: manifest.json (integrity metadata)
  manifest <- list(
    manifest_version = "1.0",
    run_id = cfg$run_id,
    timestamp_jst = jst_now,
    input_file = list(
      path = cfg$input,
      sha256 = input_sha256
    ),
    artifacts = list(
      means_results_json = list(
        path = "means_results.json",
        sha256 = digest::digest(json_path, file = TRUE, algo = "sha256")
      ),
      summary_csv = list(
        path = "summary.csv",
        sha256 = digest::digest(csv_path, file = TRUE, algo = "sha256")
      ),
      summary_report_md = list(
        path = "summary_report.md",
        sha256 = digest::digest(md_path, file = TRUE, algo = "sha256")
      ),
      analysis_config_json = list(
        path = "analysis_config.json",
        sha256 = digest::digest(cfg_copy_path, file = TRUE, algo = "sha256")
      )
    ),
    r_environment = list(
      version = R.version.string,
      platform = R.version$platform
    )
  )
  manifest_path <- file.path(run_dir, "manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)

  message(sprintf("Analysis successfully completed. Run isolated in: %s", run_dir))
}

if (!interactive()) {
  main()
}
