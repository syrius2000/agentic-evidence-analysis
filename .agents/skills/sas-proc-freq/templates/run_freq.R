#!/usr/bin/env Rscript
# SAS PROC FREQ Compatible Categorical Analysis Engine in R
# Script: run_freq.R

suppressPackageStartupMessages({
  library(jsonlite)
})

# -----------------------------------------------------------------------------
# 1. RFC 3986 Percent-Encoding & Decoding Helpers
# -----------------------------------------------------------------------------

encode_rfc3986 <- function(str) {
  if (is.na(str) || is.null(str)) return("")
  raw_bytes <- as.integer(charToRaw(as.character(str)))
  out <- vapply(raw_bytes, function(ch) {
    # Unreserved characters: ALPHA / DIGIT / "-" / "." / "_" / "~"
    # A-Z: 65-90, a-z: 97-122, 0-9: 48-57, -: 45, .: 46, _: 95, ~: 126
    if ((ch >= 65 && ch <= 90) ||
        (ch >= 97 && ch <= 122) ||
        (ch >= 48 && ch <= 57) ||
        ch %in% c(45, 46, 95, 126)) {
      rawToChar(as.raw(ch))
    } else {
      sprintf("%%%02X", ch)
    }
  }, FUN.VALUE = character(1))
  paste0(out, collapse = "")
}

decode_rfc3986 <- function(str) {
  if (is.na(str) || is.null(str) || nchar(str) == 0) return("")
  utils::URLdecode(str)
}

build_strata_key <- function(strata_named_values) {
  if (length(strata_named_values) == 0) {
    return("ALL")
  }
  var_names <- sort(names(strata_named_values))
  pairs <- vapply(var_names, function(vn) {
    val <- as.character(strata_named_values[[vn]])
    paste0(encode_rfc3986(vn), "=", encode_rfc3986(val))
  }, FUN.VALUE = character(1))
  paste0(pairs, collapse = "|")
}

parse_strata_key <- function(strata_key) {
  if (is.null(strata_key) || strata_key == "ALL" || nchar(strata_key) == 0) {
    return(list())
  }
  pairs <- strsplit(strata_key, "\\|")[[1]]
  res <- list()
  for (pair in pairs) {
    kv <- strsplit(pair, "=")[[1]]
    if (length(kv) == 2) {
      k <- decode_rfc3986(kv[1])
      v <- decode_rfc3986(kv[2])
      res[[k]] <- v
    }
  }
  res
}

# -----------------------------------------------------------------------------
# 2. Config Parsing & Validation
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
  if (is.null(cfg$analysis_kind) || cfg$analysis_kind != "sas_proc_freq") {
    stop("Invalid analysis_kind: expected 'sas_proc_freq'")
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
  if (is.null(cfg$tables) || !is.list(cfg$tables) || length(cfg$tables) == 0) {
    stop("Missing or empty 'tables' in config.")
  }

  # Validate each table request and fill defaults
  validated_tables <- list()
  for (idx in seq_along(cfg$tables)) {
    t_cfg <- cfg$tables[[idx]]
    if (is.null(t_cfg$table_id) || nchar(t_cfg$table_id) == 0) {
      stop(sprintf("Table %d is missing 'table_id'.", idx))
    }
    if (is.null(t_cfg$row_var) || nchar(t_cfg$row_var) == 0) {
      stop(sprintf("Table '%s' is missing 'row_var'.", t_cfg$table_id))
    }
    if (!is.null(t_cfg$col_var) && nchar(t_cfg$col_var) == 0) {
      t_cfg$col_var <- NULL
    }
    if (is.null(t_cfg$strata_vars)) {
      t_cfg$strata_vars <- character(0)
    } else {
      t_cfg$strata_vars <- as.character(unlist(t_cfg$strata_vars))
    }
    if (is.null(t_cfg$missing_mode)) {
      t_cfg$missing_mode <- "exclude"
    }
    if (!t_cfg$missing_mode %in% c("exclude", "missprint", "include")) {
      stop(sprintf("Invalid missing_mode '%s' in table '%s'. Must be exclude, missprint, or include.",
                   t_cfg$missing_mode, t_cfg$table_id))
    }
    if (is.null(t_cfg$chisq)) t_cfg$chisq <- TRUE
    if (is.null(t_cfg$measures)) t_cfg$measures <- TRUE
    if (is.null(t_cfg$relrisk)) t_cfg$relrisk <- TRUE
    if (is.null(t_cfg$binomial)) t_cfg$binomial <- FALSE
    if (is.null(t_cfg$binomial_methods)) {
      t_cfg$binomial_methods <- c("wald", "clopper_pearson", "wilson")
    } else {
      t_cfg$binomial_methods <- as.character(unlist(t_cfg$binomial_methods))
    }
    if (is.null(t_cfg$alpha)) t_cfg$alpha <- 0.05
    if (t_cfg$alpha <= 0 || t_cfg$alpha >= 1) {
      stop(sprintf("alpha must be in (0, 1) in table '%s'.", t_cfg$table_id))
    }

    # Fisher configuration
    if (is.null(t_cfg$fisher)) {
      t_cfg$fisher <- list(method = "none")
    }
    if (is.null(t_cfg$fisher$method)) t_cfg$fisher$method <- "none"
    if (!t_cfg$fisher$method %in% c("none", "exact", "monte_carlo")) {
      stop(sprintf("Invalid fisher.method '%s' in table '%s'.", t_cfg$fisher$method, t_cfg$table_id))
    }
    if (is.null(t_cfg$fisher$limits)) t_cfg$fisher$limits <- list()
    if (is.null(t_cfg$fisher$limits$timeout_sec)) t_cfg$fisher$limits$timeout_sec <- 300
    if (is.null(t_cfg$fisher$limits$max_memory_mb)) t_cfg$fisher$limits$max_memory_mb <- 1024
    if (is.null(t_cfg$fisher$limits$workspace_bytes)) t_cfg$fisher$limits$workspace_bytes <- 33554432
    if (is.null(t_cfg$fisher$fallback_to_mc)) t_cfg$fisher$fallback_to_mc <- FALSE
    if (is.null(t_cfg$fisher$mc_sampling_algorithm)) t_cfg$fisher$mc_sampling_algorithm <- "patefield"
    if (!t_cfg$fisher$mc_sampling_algorithm %in% c("patefield", "awb")) {
      stop(sprintf("Invalid mc_sampling_algorithm '%s' in table '%s'.",
                   t_cfg$fisher$mc_sampling_algorithm, t_cfg$table_id))
    }
    # v1: AWB はスキーマ予約のみ。実行経路は patefield 固定。
    if (identical(t_cfg$fisher$mc_sampling_algorithm, "awb")) {
      stop(sprintf(
        "mc_sampling_algorithm 'awb' is not implemented in sas-proc-freq v1 (use 'patefield') in table '%s'.",
        t_cfg$table_id
      ))
    }
    if (is.null(t_cfg$fisher$mc_replications)) t_cfg$fisher$mc_replications <- 10000L
    if (is.null(t_cfg$fisher$mc_seed)) t_cfg$fisher$mc_seed <- 20260913L
    if (is.null(t_cfg$fisher$mc_alpha)) t_cfg$fisher$mc_alpha <- 0.01

    validated_tables[[length(validated_tables) + 1]] <- t_cfg
  }
  cfg$tables <- validated_tables

  cfg
}

# -----------------------------------------------------------------------------
# 3. Statistical Computation Functions
# -----------------------------------------------------------------------------

# Pearson, Likelihood Ratio, and Continuity-Adjusted Chi-Square
compute_chisq_stats <- function(tab) {
  # tab is an R x C integer count matrix
  R <- nrow(tab)
  C <- ncol(tab)
  N <- sum(tab)

  row_sums <- rowSums(tab)
  col_sums <- colSums(tab)

  # Check for degenerate table
  if (R < 2 || C < 2 || any(row_sums == 0) || any(col_sums == 0) || N == 0) {
    return(list(
      is_degenerate = TRUE,
      status_reason = "DEGENERATE_TABLE_ZERO_MARGINAL",
      pearson = list(statistic = NULL, df = NULL, p_value = NULL),
      likelihood_ratio = list(statistic = NULL, df = NULL, p_value = NULL),
      continuity_adj = list(statistic = NULL, df = NULL, p_value = NULL)
    ))
  }

  df <- (R - 1L) * (C - 1L)
  E <- outer(row_sums, col_sums) / N

  # 1. Pearson Chi-Square: sum (O - E)^2 / E
  pearson_stat <- sum((tab - E)^2 / E)
  pearson_p <- stats::pchisq(pearson_stat, df = df, lower.tail = FALSE)

  # 2. Likelihood Ratio Chi-Square (G^2): 2 * sum O * ln(O / E), with 0*ln(0) = 0
  pos_mask <- tab > 0
  lr_stat <- 2 * sum(tab[pos_mask] * log(tab[pos_mask] / E[pos_mask]))
  lr_p <- stats::pchisq(lr_stat, df = df, lower.tail = FALSE)

  # 3. Continuity-Adjusted Chi-Square (only for 2x2):
  # SAS formula: sum_i sum_j [max(0, |O_ij - E_ij| - 0.5)]^2 / E_ij, df = 1
  if (R == 2 && C == 2) {
    diffs <- abs(tab - E) - 0.5
    diffs[diffs < 0] <- 0
    cont_stat <- sum(diffs^2 / E)
    cont_p <- stats::pchisq(cont_stat, df = 1L, lower.tail = FALSE)
  } else {
    cont_stat <- NULL
    cont_p <- NULL
  }

  list(
    is_degenerate = FALSE,
    status_reason = NULL,
    pearson = list(statistic = pearson_stat, df = df, p_value = pearson_p),
    likelihood_ratio = list(statistic = lr_stat, df = df, p_value = lr_p),
    continuity_adj = if (R == 2 && C == 2) list(statistic = cont_stat, df = 1L, p_value = cont_p) else NULL
  )
}

# 2x2 Effect Sizes: Odds Ratio & Relative Risk (Cols 1 & 2)
compute_2x2_measures <- function(tab, alpha = 0.05) {
  # tab is 2x2 matrix:
  # row 1: exposure/group 1, row 2: control/group 2
  # col 1: event, col 2: non-event
  if (nrow(tab) != 2 || ncol(tab) != 2) return(NULL)

  a <- tab[1, 1]
  b <- tab[1, 2]
  c <- tab[2, 1]
  d <- tab[2, 2]

  n1 <- a + b
  n2 <- c + d
  n <- n1 + n2

  z <- stats::qnorm(1 - alpha / 2)

  # Check zero cell conditions for OR and RR
  # Odds Ratio: ad / bc
  if (b == 0 || c == 0 || a == 0 || d == 0) {
    or_res <- list(
      estimate = if (b > 0 && c > 0) (a * d) / (b * c) else NULL,
      lower_cl = NULL,
      upper_cl = NULL,
      status_reason = "ZERO_CELL_UNDEFINED"
    )
  } else {
    or_val <- (a * d) / (b * c)
    se_ln_or <- sqrt(1/a + 1/b + 1/c + 1/d)
    or_res <- list(
      estimate = or_val,
      lower_cl = exp(log(or_val) - z * se_ln_or),
      upper_cl = exp(log(or_val) + z * se_ln_or),
      status_reason = NULL
    )
  }

  # Relative Risk Column 1 (Event): (a/n1) / (c/n2)
  if (n1 == 0 || n2 == 0 || c == 0 || a == 0) {
    rr1_res <- list(
      estimate = if (n1 > 0 && n2 > 0 && c > 0) (a / n1) / (c / n2) else NULL,
      lower_cl = NULL,
      upper_cl = NULL,
      status_reason = "ZERO_CELL_UNDEFINED"
    )
  } else {
    p1 <- a / n1
    p2 <- c / n2
    rr1_val <- p1 / p2
    se_ln_rr1 <- sqrt(b / (a * n1) + d / (c * n2))
    rr1_res <- list(
      estimate = rr1_val,
      lower_cl = exp(log(rr1_val) - z * se_ln_rr1),
      upper_cl = exp(log(rr1_val) + z * se_ln_rr1),
      status_reason = NULL
    )
  }

  # Relative Risk Column 2 (Non-Event): (b/n1) / (d/n2)
  if (n1 == 0 || n2 == 0 || d == 0 || b == 0) {
    rr2_res <- list(
      estimate = if (n1 > 0 && n2 > 0 && d > 0) (b / n1) / (d / n2) else NULL,
      lower_cl = NULL,
      upper_cl = NULL,
      status_reason = "ZERO_CELL_UNDEFINED"
    )
  } else {
    q1 <- b / n1
    q2 <- d / n2
    rr2_val <- q1 / q2
    se_ln_rr2 <- sqrt(a / (b * n1) + c / (d * n2))
    rr2_res <- list(
      estimate = rr2_val,
      lower_cl = exp(log(rr2_val) - z * se_ln_rr2),
      upper_cl = exp(log(rr2_val) + z * se_ln_rr2),
      status_reason = NULL
    )
  }

  list(
    odds_ratio = or_res,
    relative_risk_col1 = rr1_res,
    relative_risk_col2 = rr2_res
  )
}

# Binomial Proportion Confidence Intervals (Wald, Clopper-Pearson, Wilson)
compute_binomial_ci <- function(x, n, alpha = 0.05, methods = c("wald", "clopper_pearson", "wilson")) {
  if (n <= 0) {
    return(list(
      proportion = NULL,
      status_reason = "INDETERMINATE_FRACTION_ZERO_DENOMINATOR"
    ))
  }
  p_hat <- x / n
  z <- stats::qnorm(1 - alpha / 2)
  res <- list(proportion = p_hat)

  if ("wald" %in% methods) {
    se_wald <- sqrt(p_hat * (1 - p_hat) / n)
    res$wald <- list(
      lower_cl = max(0, p_hat - z * se_wald),
      upper_cl = min(1, p_hat + z * se_wald)
    )
  }

  if ("clopper_pearson" %in% methods) {
    lower_cp <- if (x == 0) 0 else stats::qbeta(alpha / 2, x, n - x + 1)
    upper_cp <- if (x == n) 1 else stats::qbeta(1 - alpha / 2, x + 1, n - x)
    res$clopper_pearson <- list(
      lower_cl = lower_cp,
      upper_cl = upper_cp
    )
  }

  if ("wilson" %in% methods) {
    denom <- 1 + z^2 / n
    center <- (p_hat + z^2 / (2 * n)) / denom
    half_w <- (z * sqrt(p_hat * (1 - p_hat) / n + z^2 / (4 * n^2))) / denom
    res$wilson <- list(
      lower_cl = max(0, center - half_w),
      upper_cl = min(1, center + half_w)
    )
  }

  res
}

# SAS Monte Carlo Summary for Fisher Exact Test
compute_sas_mc_summary <- function(tab,
                                   B = 10000L,
                                   seed = 20260913L,
                                   alpha_mc = 0.01,
                                   mc_sampling_algorithm = "patefield") {
  if (!identical(mc_sampling_algorithm, "patefield")) {
    stop(sprintf(
      "Unsupported mc_sampling_algorithm '%s' (v1 supports 'patefield' only).",
      mc_sampling_algorithm
    ))
  }

  row_sums <- rowSums(tab)
  col_sums <- colSums(tab)

  # Extreme tables: P(T) <= P(T_obs) <=> sum lgamma(T_ij+1) >= sum lgamma(T_obs_ij+1)
  obs_lgamma_sum <- sum(lgamma(tab + 1))

  set.seed(seed, kind = "Mersenne-Twister")
  tables <- stats::r2dtable(B, row_sums, col_sums)

  m_count <- 0L
  for (t_sim in tables) {
    sim_lgamma_sum <- sum(lgamma(t_sim + 1))
    if (sim_lgamma_sum >= obs_lgamma_sum - 1e-9) {
      m_count <- m_count + 1L
    }
  }

  p_hat <- m_count / B
  p_plus_one <- (m_count + 1) / (B + 1)

  se <- if (B > 1) sqrt(p_hat * (1 - p_hat) / (B - 1)) else 0
  z <- stats::qnorm(1 - alpha_mc / 2)

  if (m_count == 0L) {
    lower_cl <- 0.0
    upper_cl <- 1.0 - (alpha_mc)^(1.0 / B)
  } else if (m_count == B) {
    lower_cl <- (alpha_mc)^(1.0 / B)
    upper_cl <- 1.0
  } else {
    lower_cl <- max(0.0, p_hat - z * se)
    upper_cl <- min(1.0, p_hat + z * se)
  }

  list(
    method = "monte_carlo",
    mc_sampling_algorithm = mc_sampling_algorithm,
    replications = B,
    seed = seed,
    extreme_count = m_count,
    p_value = p_hat,
    p_mc_plus_one = p_plus_one,
    std_err = se,
    lower_cl = lower_cl,
    upper_cl = upper_cl,
    confidence_level = 1 - alpha_mc
  )
}

# ---- Child-process resource monitoring (unix) ----

.get_rss_kb <- function(pid) {
  # macOS/Linux: ps RSS is kilobytes
  out <- suppressWarnings(
    system2("ps", c("-o", "rss=", "-p", as.character(pid)), stdout = TRUE, stderr = FALSE)
  )
  if (length(out) < 1 || !nzchar(trimws(out[1]))) return(NA_real_)
  suppressWarnings(as.numeric(trimws(out[1])))
}

.pid_alive <- function(pid) {
  # kill -0: existence check (exit 0 = alive)
  system2("kill", c("-0", as.character(pid)), stdout = FALSE, stderr = FALSE) == 0
}

.force_stop_pid <- function(pid) {
  system2("kill", c("-TERM", as.character(pid)), stdout = FALSE, stderr = FALSE)
  Sys.sleep(0.2)
  if (.pid_alive(pid)) {
    system2("kill", c("-KILL", as.character(pid)), stdout = FALSE, stderr = FALSE)
  }
}

# Returns list(status_reason=NULL|TIMEOUT|OUT_OF_MEMORY|..., out_msg=character, exit_status=)
run_child_rscript_monitored <- function(script_path,
                                        timeout_sec,
                                        max_memory_mb,
                                        poll_sec = 0.1) {
  if (.Platform$OS.type != "unix") {
    stop("Child-process resource monitoring requires a unix platform.")
  }

  log_path <- tempfile("fisher_child_", fileext = ".log")
  on.exit({
    if (file.exists(log_path)) unlink(log_path)
  }, add = TRUE)

  # Background launch; print PID
  launch_cmd <- sprintf(
    "Rscript %s >%s 2>&1 & echo $!",
    shQuote(script_path),
    shQuote(log_path)
  )
  pid_out <- system2("/bin/sh", c("-c", shQuote(launch_cmd)), stdout = TRUE, stderr = TRUE)
  pid <- suppressWarnings(as.integer(trimws(pid_out[length(pid_out)])))
  if (is.na(pid) || pid <= 0) {
    return(list(
      status_reason = "SUBPROCESS_FAILURE",
      out_msg = paste(pid_out, collapse = "\n"),
      exit_status = NA_integer_
    ))
  }

  deadline <- Sys.time() + as.numeric(timeout_sec)
  stop_reason <- NULL

  while (.pid_alive(pid)) {
    now <- Sys.time()
    if (now >= deadline) {
      .force_stop_pid(pid)
      stop_reason <- "TIMEOUT"
      break
    }
    rss_kb <- .get_rss_kb(pid)
    if (!is.na(rss_kb) && (rss_kb / 1024) > as.numeric(max_memory_mb)) {
      .force_stop_pid(pid)
      stop_reason <- "OUT_OF_MEMORY"
      break
    }
    Sys.sleep(poll_sec)
  }

  # Reap exit status if still waitable (best-effort)
  exit_status <- NA_integer_
  wait_out <- suppressWarnings(
    system2("/bin/sh", c("-c", shQuote(sprintf("wait %d; echo $?", pid))), stdout = TRUE, stderr = FALSE)
  )
  if (length(wait_out) >= 1) {
    exit_status <- suppressWarnings(as.integer(trimws(wait_out[length(wait_out)])))
  }

  out_msg <- if (file.exists(log_path)) {
    paste(readLines(log_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else {
    ""
  }

  list(
    status_reason = stop_reason,
    out_msg = out_msg,
    exit_status = exit_status,
    pid = pid
  )
}

.fisher_resource_result <- function(tab, fisher_cfg, R, C, err_code, err_text = NULL) {
  if (isTRUE(fisher_cfg$fallback_to_mc)) {
    mc_res <- compute_sas_mc_summary(
      tab = tab,
      B = fisher_cfg$mc_replications,
      seed = fisher_cfg$mc_seed,
      alpha_mc = fisher_cfg$mc_alpha,
      mc_sampling_algorithm = fisher_cfg$mc_sampling_algorithm
    )
    mc_res$requested_method <- "exact"
    mc_res$executed_method <- "monte_carlo"
    mc_res$fallback_reason <- "RESOURCE_LIMIT_EXCEEDED"
    mc_res$status_reason <- err_code
    return(mc_res)
  }
  list(
    method = "exact",
    dimension = sprintf("%dx%d", R, C),
    p_value = NULL,
    status_reason = err_code,
    error_message = if (is.null(err_text)) err_code else err_text
  )
}

# Fisher Exact Test with Resource Limits & Child Process Protection
execute_fisher_test <- function(tab, fisher_cfg) {
  R <- nrow(tab)
  C <- ncol(tab)

  if (R < 2 || C < 2 || any(rowSums(tab) == 0) || any(colSums(tab) == 0)) {
    return(list(
      method = fisher_cfg$method,
      p_value = NULL,
      status_reason = "DEGENERATE_TABLE_ZERO_MARGINAL"
    ))
  }

  if (fisher_cfg$method == "none") {
    return(NULL)
  }

  if (fisher_cfg$method == "monte_carlo") {
    return(compute_sas_mc_summary(
      tab = tab,
      B = fisher_cfg$mc_replications,
      seed = fisher_cfg$mc_seed,
      alpha_mc = fisher_cfg$mc_alpha,
      mc_sampling_algorithm = fisher_cfg$mc_sampling_algorithm
    ))
  }

  # 2x2: hypergeometric path; workspace unused
  if (R == 2 && C == 2) {
    f_res <- stats::fisher.test(tab, alternative = "two.sided")
    return(list(
      method = "exact",
      dimension = "2x2",
      p_value = f_res$p.value,
      status_reason = NULL
    ))
  }

  # General R x C: workspace_bytes -> 4-byte units
  ws_bytes <- as.numeric(fisher_cfg$limits$workspace_bytes)
  ws_units <- if (ws_bytes / 4 >= .Machine$integer.max) {
    .Machine$integer.max
  } else {
    max(1L, as.integer(floor(ws_bytes / 4)))
  }

  tf_in <- tempfile("fisher_tab_", fileext = ".rds")
  tf_out <- tempfile("fisher_out_", fileext = ".rds")
  tf_script <- tempfile("fisher_child_", fileext = ".R")
  saveRDS(tab, tf_in)
  on.exit({
    if (file.exists(tf_in)) unlink(tf_in)
    if (file.exists(tf_out)) unlink(tf_out)
    if (file.exists(tf_script)) unlink(tf_script)
  }, add = TRUE)

  writeLines(c(
    sprintf('tab <- readRDS(%s)', deparse(tf_in)),
    sprintf(
      'res <- tryCatch(stats::fisher.test(tab, workspace = %dL, alternative = "two.sided"), error = function(e) e)',
      ws_units
    ),
    sprintf('saveRDS(res, %s)', deparse(tf_out))
  ), tf_script, useBytes = TRUE)

  timeout_sec <- as.numeric(fisher_cfg$limits$timeout_sec)
  max_memory_mb <- as.numeric(fisher_cfg$limits$max_memory_mb)

  child <- run_child_rscript_monitored(
    script_path = tf_script,
    timeout_sec = timeout_sec,
    max_memory_mb = max_memory_mb
  )

  if (!is.null(child$status_reason)) {
    return(.fisher_resource_result(
      tab, fisher_cfg, R, C,
      err_code = child$status_reason,
      err_text = paste0(child$status_reason, ": ", child$out_msg)
    ))
  }

  if (file.exists(tf_out)) {
    child_res <- readRDS(tf_out)
    if (inherits(child_res, "error")) {
      err_text <- child_res$message
      if (grepl("FEXACT error 40|Out of workspace|workspace", err_text, ignore.case = TRUE)) {
        err_code <- "WORKSPACE_EXCEEDED"
      } else if (grepl("cannot allocate vector|memory|bad_alloc", err_text, ignore.case = TRUE)) {
        err_code <- "OUT_OF_MEMORY"
      } else {
        err_code <- "EXACT_COMPUTATION_ERROR"
      }
      return(.fisher_resource_result(tab, fisher_cfg, R, C, err_code, err_text))
    }
    return(list(
      method = "exact",
      dimension = sprintf("%dx%d", R, C),
      workspace_units = ws_units,
      p_value = child_res$p.value,
      status_reason = NULL
    ))
  }

  out_msg <- child$out_msg
  if (grepl("cannot allocate vector|out of memory|bad_alloc", out_msg, ignore.case = TRUE)) {
    err_code <- "OUT_OF_MEMORY"
  } else if (grepl("FEXACT error 40|workspace", out_msg, ignore.case = TRUE)) {
    err_code <- "WORKSPACE_EXCEEDED"
  } else if (!is.na(child$exit_status) && child$exit_status %in% c(137L, 9L)) {
    # 137 = 128 + 9 (SIGKILL / OS OOM Killer 等による強制終了の推定)
    err_code <- "OUT_OF_MEMORY"
  } else {
    err_code <- "SUBPROCESS_FAILURE"
  }
  .fisher_resource_result(tab, fisher_cfg, R, C, err_code, out_msg)
}

# -----------------------------------------------------------------------------
# 4. Main Processing Engine
# -----------------------------------------------------------------------------

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- parse_args(args)
  cfg_raw <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
  cfg <- validate_config(cfg_raw)

  # Output Isolation: <output_dir>/run_<first 16 chars of run_id>/
  run_slug <- substr(cfg$run_id, 1, 16)
  run_dir <- file.path(cfg$output_dir, sprintf("run_%s", run_slug))
  if (!dir.exists(run_dir)) {
    dir.create(run_dir, recursive = TRUE)
  }

  # Read Input Data
  df_raw <- utils::read.csv(cfg$input, stringsAsFactors = FALSE, check.names = FALSE)

  results_by_table <- list()
  csv_all_rows <- list()

  for (t_cfg in cfg$tables) {
    t_id <- t_cfg$table_id
    row_v <- t_cfg$row_var
    col_v <- t_cfg$col_var
    count_v <- t_cfg$count_var
    strata_vs <- t_cfg$strata_vars
    miss_mode <- t_cfg$missing_mode

    # Validate variables exist in input dataframe
    needed_vars <- c(row_v, col_v, strata_vs, count_v)
    needed_vars <- needed_vars[!vapply(needed_vars, is.null, logical(1))]
    for (nv in needed_vars) {
      if (!nv %in% names(df_raw)) {
        stop(sprintf("Variable '%s' required by table '%s' not found in input data.", nv, t_id))
      }
    }

    # Extract Counts and validate Task 2.1 (non-negative integer)
    if (!is.null(count_v)) {
      raw_counts <- df_raw[[count_v]]
      # Stop immediately if negative, decimal, NA, NaN, Inf
      if (any(is.na(raw_counts)) || any(!is.finite(raw_counts)) ||
          any(raw_counts < 0) || any(abs(raw_counts - round(raw_counts)) > 1e-9)) {
        stop(sprintf("INVALID_COUNT_DATA: count variable '%s' in table '%s' must contain non-negative integers only.",
                     count_v, t_id))
      }
      counts_vec <- as.integer(round(raw_counts))
    } else {
      counts_vec <- rep(1L, nrow(df_raw))
    }

    # Check for structural zeros
    if (!is.null(t_cfg$structural_zeros) && length(t_cfg$structural_zeros) > 0) {
      stop(sprintf("STRUCTURAL_ZERO_PRESENT: structural zeros specified for table '%s'.", t_id))
    }

    # SAS ZEROS non-support: exclude count == 0 rows from generating cells
    keep_non_zero <- counts_vec > 0
    df_active <- df_raw[keep_non_zero, , drop = FALSE]
    counts_active <- counts_vec[keep_non_zero]

    # Handle Missing Values per table request
    # Detect rows with NA in active table variables
    check_vars <- c(row_v, col_v, strata_vs)
    check_vars <- check_vars[!vapply(check_vars, is.null, logical(1))]

    is_missing_row <- rep(FALSE, nrow(df_active))
    for (cv in check_vars) {
      val_col <- df_active[[cv]]
      is_missing_row <- is_missing_row | is.na(val_col) | (is.character(val_col) & val_col == "")
    }

    excluded_missing_count <- 0L
    if (miss_mode == "exclude") {
      excluded_missing_count <- sum(counts_active[is_missing_row])
      df_valid <- df_active[!is_missing_row, , drop = FALSE]
      counts_valid <- counts_active[!is_missing_row]
    } else if (miss_mode == "missprint") {
      # Keep for display, but will flag missing cells
      df_valid <- df_active
      counts_valid <- counts_active
      for (cv in check_vars) {
        val_col <- df_valid[[cv]]
        val_col[is.na(val_col) | (is.character(val_col) & val_col == "")] <- "<MISSING>"
        df_valid[[cv]] <- val_col
      }
    } else if (miss_mode == "include") {
      # Treat as valid level
      df_valid <- df_active
      counts_valid <- counts_active
      for (cv in check_vars) {
        val_col <- df_valid[[cv]]
        val_col[is.na(val_col) | (is.character(val_col) & val_col == "")] <- "<MISSING>"
        df_valid[[cv]] <- val_col
      }
    }

    # Level Ordering Resolution
    resolve_levels <- function(var_name, data_vec) {
      if (!is.null(t_cfg$levels_order) && !is.null(t_cfg$levels_order[[var_name]])) {
        spec_levels <- as.character(unlist(t_cfg$levels_order[[var_name]]))
        # Include any remaining values not explicitly in spec_levels
        observed <- unique(as.character(data_vec))
        rem <- setdiff(observed, spec_levels)
        c(spec_levels, rem)
      } else {
        # Data order of appearance
        unique(as.character(data_vec))
      }
    }

    row_levels <- resolve_levels(row_v, df_valid[[row_v]])
    col_levels <- if (!is.null(col_v)) resolve_levels(col_v, df_valid[[col_v]]) else NULL

    # 2x2 Orientation Adjustment:
    # If event_level is specified, put it first in col_levels
    if (!is.null(col_levels) && length(col_levels) == 2 && !is.null(t_cfg$event_level)) {
      if (t_cfg$event_level %in% col_levels) {
        other_col <- setdiff(col_levels, t_cfg$event_level)
        col_levels <- c(t_cfg$event_level, other_col)
      }
    }
    # If comparison_direction is specified (e.g. "Trt_vs_Pbo"), order rows accordingly
    if (length(row_levels) == 2 && !is.null(t_cfg$comparison_direction)) {
      parts <- strsplit(t_cfg$comparison_direction, "_vs_")[[1]]
      if (length(parts) == 2 && all(parts %in% row_levels)) {
        row_levels <- parts
      }
    }

    # Build Strata Interactions
    if (length(strata_vs) > 0) {
      # Grouping interactions
      strata_dfs <- df_valid[strata_vs]
      # Unique strata combinations
      strata_combos <- unique(strata_dfs)
      strata_keys_list <- list()
      for (s_idx in seq_len(nrow(strata_combos))) {
        s_row <- as.list(strata_combos[s_idx, , drop = FALSE])
        s_key <- build_strata_key(s_row)
        strata_keys_list[[length(strata_keys_list) + 1]] <- list(row = s_row, key = s_key)
      }
    } else {
      strata_keys_list <- list(list(row = list(), key = "ALL"))
    }

    table_results_strata <- list()

    for (s_info in strata_keys_list) {
      s_key <- s_info$key
      s_row <- s_info$row

      # Filter rows for this stratum
      if (length(strata_vs) > 0) {
        mask <- rep(TRUE, nrow(df_valid))
        for (sv in strata_vs) {
          mask <- mask & (as.character(df_valid[[sv]]) == as.character(s_row[[sv]]))
        }
        df_stratum <- df_valid[mask, , drop = FALSE]
        counts_stratum <- counts_valid[mask]
      } else {
        df_stratum <- df_valid
        counts_stratum <- counts_valid
      }

      # -----------------------------------------------------------------------
      # A. One-Way Frequency Table
      # -----------------------------------------------------------------------
      if (is.null(col_v)) {
        # Tabulate 1-way
        f_row <- factor(df_stratum[[row_v]], levels = row_levels)
        counts_by_level <- stats::xtabs(counts_stratum ~ f_row)

        N_valid <- sum(counts_by_level)
        cum_freq <- cumsum(as.numeric(counts_by_level))

        cell_results <- list()
        for (l_idx in seq_along(row_levels)) {
          lvl <- row_levels[l_idx]
          cnt <- as.numeric(counts_by_level[l_idx])
          pct <- if (N_valid > 0) (cnt / N_valid) * 100 else NULL
          cum_cnt <- cum_freq[l_idx]
          cum_pct <- if (N_valid > 0) (cum_cnt / N_valid) * 100 else NULL

          cell_results[[lvl]] <- list(
            level = lvl,
            frequency = cnt,
            percent = pct,
            cumulative_frequency = cum_cnt,
            cumulative_percent = cum_pct
          )

          # CSV Row
          csv_row <- c(
            list(
              table_id = t_id,
              strata_key = s_key
            ),
            s_row,
            list(
              row_level = lvl,
              col_level = NA_character_,
              frequency = cnt,
              percent = if (is.null(pct)) NA_real_ else pct,
              row_percent = 100.0,
              col_percent = if (is.null(pct)) NA_real_ else pct,
              cumulative_frequency = as.numeric(cum_cnt),
              cumulative_percent = if (is.null(cum_pct)) NA_real_ else cum_pct
            )
          )
          csv_all_rows[[length(csv_all_rows) + 1]] <- csv_row
        }

        # Binomial CI for 1-way if requested
        binom_res <- NULL
        if (t_cfg$binomial) {
          target_lvl <- if (!is.null(t_cfg$binomial_level)) t_cfg$binomial_level else row_levels[1]
          x_target <- as.numeric(counts_by_level[target_lvl])
          binom_res <- compute_binomial_ci(
            x = x_target,
            n = N_valid,
            alpha = t_cfg$alpha,
            methods = t_cfg$binomial_methods
          )
          binom_res$level <- target_lvl
        }

        table_results_strata[[s_key]] <- list(
          strata_key = s_key,
          strata_values = s_row,
          type = "one_way",
          total_frequency = N_valid,
          excluded_missing_count = excluded_missing_count,
          frequencies = cell_results,
          binomial = binom_res
        )

      } else {
        # ---------------------------------------------------------------------
        # B. Two-Way Crosstabulation Table
        # ---------------------------------------------------------------------
        # For missprint mode, exclude '<MISSING>' from inferential tests and proportions
        if (miss_mode == "missprint") {
          non_miss_mask <- df_stratum[[row_v]] != "<MISSING>" & df_stratum[[col_v]] != "<MISSING>"
          df_infer <- df_stratum[non_miss_mask, , drop = FALSE]
          counts_infer <- counts_stratum[non_miss_mask]
        } else {
          df_infer <- df_stratum
          counts_infer <- counts_stratum
        }

        f_row <- factor(df_infer[[row_v]], levels = row_levels)
        f_col <- factor(df_infer[[col_v]], levels = col_levels)
        tab_matrix <- as.matrix(stats::xtabs(counts_infer ~ f_row + f_col))

        N_table <- sum(tab_matrix)
        row_totals <- rowSums(tab_matrix)
        col_totals <- colSums(tab_matrix)

        # Build Cell Dictionaries & CSV rows
        cells_dict <- list()
        for (r_name in row_levels) {
          cells_dict[[r_name]] <- list()
          for (c_name in col_levels) {
            cnt <- tab_matrix[r_name, c_name]
            r_tot <- row_totals[r_name]
            c_tot <- col_totals[c_name]

            pct <- if (N_table > 0) (cnt / N_table) * 100 else NULL
            row_pct <- if (r_tot > 0) (cnt / r_tot) * 100 else NULL
            col_pct <- if (c_tot > 0) (cnt / c_tot) * 100 else NULL

            cells_dict[[r_name]][[c_name]] <- list(
              frequency = cnt,
              percent = pct,
              row_percent = row_pct,
              col_percent = col_pct
            )

            # Add to CSV rows
            csv_row <- c(
              list(
                table_id = t_id,
                strata_key = s_key
              ),
              s_row,
              list(
                row_level = r_name,
                col_level = c_name,
                frequency = cnt,
                percent = if (is.null(pct)) NA_real_ else pct,
                row_percent = if (is.null(row_pct)) NA_real_ else row_pct,
                col_percent = if (is.null(col_pct)) NA_real_ else col_pct,
                cumulative_frequency = NA_real_,
                cumulative_percent = NA_real_
              )
            )
            csv_all_rows[[length(csv_all_rows) + 1]] <- csv_row
          }
        }

        # 1. Chi-Square tests
        chisq_results <- if (t_cfg$chisq) compute_chisq_stats(tab_matrix) else NULL

        # 2. 2x2 Measures (OR, RR)
        measures_results <- NULL
        if (nrow(tab_matrix) == 2 && ncol(tab_matrix) == 2 && (t_cfg$measures || t_cfg$relrisk)) {
          measures_results <- compute_2x2_measures(tab_matrix, alpha = t_cfg$alpha)
        }

        # 3. Binomial Proportion CI
        binom_res <- NULL
        if (t_cfg$binomial) {
          target_col <- if (!is.null(t_cfg$binomial_level)) {
            t_cfg$binomial_level
          } else if (!is.null(t_cfg$event_level)) {
            t_cfg$event_level
          } else {
            col_levels[1]
          }
          x_target <- sum(tab_matrix[, target_col])
          binom_res <- compute_binomial_ci(
            x = x_target,
            n = N_table,
            alpha = t_cfg$alpha,
            methods = t_cfg$binomial_methods
          )
          binom_res$level = target_col
        }

        # 4. Fisher Exact / Monte Carlo Test
        fisher_results <- if (t_cfg$fisher$method != "none") {
          execute_fisher_test(tab_matrix, t_cfg$fisher)
        } else {
          NULL
        }

        table_results_strata[[s_key]] <- list(
          strata_key = s_key,
          strata_values = s_row,
          type = "two_way",
          total_frequency = N_table,
          excluded_missing_count = excluded_missing_count,
          row_variable = row_v,
          col_variable = col_v,
          row_levels = row_levels,
          col_levels = col_levels,
          table_orientation = list(
            row_order = row_levels,
            col_order = col_levels,
            event_level = t_cfg$event_level,
            comparison_direction = t_cfg$comparison_direction
          ),
          frequencies = cells_dict,
          row_totals = as.list(row_totals),
          col_totals = as.list(col_totals),
          chisq = chisq_results,
          measures = measures_results,
          binomial = binom_res,
          fisher = fisher_results
        )
      }
    }

    results_by_table[[t_id]] <- list(
      table_id = t_id,
      row_var = row_v,
      col_var = col_v,
      strata_vars = strata_vs,
      missing_mode = miss_mode,
      strata = table_results_strata
    )
  }

  # Build Final JSON Output
  jst_now <- format(as.POSIXct(Sys.time(), tz = "Asia/Tokyo"), "%Y-%m-%d %H:%M:%S JST")
  input_sha256 <- digest::digest(cfg$input, file = TRUE, algo = "sha256")

  freq_results <- list(
    schema_version = "sas-summary-results-v1",
    analysis_kind = "sas_proc_freq",
    metadata = list(
      run_id = cfg$run_id,
      timestamp_jst = jst_now,
      input_path = cfg$input,
      input_sha256 = input_sha256,
      sas_parity = "unverified",
      parity_basis = "formula_and_hand_calculation"
    ),
    tables = results_by_table
  )

  # Output 1: freq_results.json
  json_path <- file.path(run_dir, "freq_results.json")
  jsonlite::write_json(freq_results, json_path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = 12)

  # Output 2: summary.csv
  # Ensure all column names match specification
  csv_df <- do.call(rbind, lapply(csv_all_rows, function(r) as.data.frame(r, check.names = FALSE, stringsAsFactors = FALSE)))
  csv_path <- file.path(run_dir, "summary.csv")
  utils::write.csv(csv_df, csv_path, row.names = FALSE, na = "")

  # Output 3: summary_report.md (Japanese Markdown Report)
  md_path <- file.path(run_dir, "summary_report.md")
  md_con <- file(md_path, open = "w", encoding = "UTF-8")

  writeLines(c(
    "# SAS PROC FREQ カテゴリカル解析レポート",
    "",
    "## 実行メタデータ",
    "",
    sprintf("- **Run ID**: `%s`", cfg$run_id),
    sprintf("- **実行日時 (JST)**: %s", jst_now),
    sprintf("- **入力データ**: `%s`", cfg$input),
    sprintf("- **入力データ SHA-256**: `%s`", input_sha256),
    sprintf("- **SAS Parity 状態**: `%s` (根拠: `%s`)", "unverified", "formula_and_hand_calculation"),
    "",
    "## 適用された制約・境界条件 (Constraints & Non-Claims)",
    "",
    "- **ビット単位一致の非保証**: 浮動小数点演算順序やプラットフォーム差による最下位ビットの差異を許容します。",
    "- **全SAS構文再現の対象外**: SAS WEIGHT の ZEROS オプション、特殊欠損値等は対象外の限定互換です。",
    "- **規制提出適格性の非主張**: 本出力は探索的データ解析を目的とするものであり、規制当局申請適格性を主張するものではありません。",
    "- **ゼロセル未定義原則**: 2×2効果量（OR/RR）算出において度数0による未定義は 0.5 加算を行わず null（ZERO_CELL_UNDEFINED）としています。",
    "- **Monte Carlo 標本化**: アルゴリズムは Patefield (1981) 周辺固定法に固定され、結果の再現性を確保しています。",
    "",
    "## 解析結果テーブル一覧",
    ""
  ), md_con)

  for (t_id in names(results_by_table)) {
    t_res <- results_by_table[[t_id]]
    writeLines(sprintf("### 表要求 ID: %s (行: %s, 列: %s)\n", t_id, t_res$row_var, if (is.null(t_res$col_var)) "(なし)" else t_res$col_var), md_con)

    for (s_key in names(t_res$strata)) {
      s_data <- t_res$strata[[s_key]]
      writeLines(sprintf("#### 層別キー: `%s` (総度数: %d, 除外欠損度数: %d)\n", s_key, s_data$total_frequency, s_data$excluded_missing_count), md_con)

      if (s_data$type == "one_way") {
        writeLines("| 水準 | 度数 (Frequency) | 割合 (Percent) | 累積度数 | 累積割合 |", md_con)
        writeLines("| :--- | :---: | :---: | :---: | :---: |", md_con)
        for (lvl in names(s_data$frequencies)) {
          c_info <- s_data$frequencies[[lvl]]
          pct_str <- if (is.null(c_info$percent)) "-" else sprintf("%.2f%%", c_info$percent)
          cpct_str <- if (is.null(c_info$cumulative_percent)) "-" else sprintf("%.2f%%", c_info$cumulative_percent)
          writeLines(sprintf("| %s | %d | %s | %d | %s |", lvl, c_info$frequency, pct_str, c_info$cumulative_frequency, cpct_str), md_con)
        }
        writeLines("", md_con)
      } else {
        # 2-way table display
        col_lvls <- s_data$col_levels
        header_row <- paste0("| ", s_data$row_variable, " \\ ", s_data$col_variable, " | ", paste(col_lvls, collapse = " | "), " | 合計 |")
        align_row <- paste0("| :--- | ", paste(rep(":---:", length(col_lvls)), collapse = " | "), " | :---: |")
        writeLines(header_row, md_con)
        writeLines(align_row, md_con)

        for (r_lvl in s_data$row_levels) {
          row_cells <- vapply(col_lvls, function(cl) {
            cf <- s_data$frequencies[[r_lvl]][[cl]]
            pct_s <- if (is.null(cf$percent)) "-" else sprintf("%.1f%%", cf$percent)
            sprintf("%d (%s)", cf$frequency, pct_s)
          }, character(1))
          r_tot <- s_data$row_totals[[r_lvl]]
          writeLines(sprintf("| %s | %s | %d |", r_lvl, paste(row_cells, collapse = " | "), r_tot), md_con)
        }
        col_tot_cells <- vapply(col_lvls, function(cl) as.character(s_data$col_totals[[cl]]), character(1))
        writeLines(sprintf("| **合計** | %s | **%d** |", paste(col_tot_cells, collapse = " | "), s_data$total_frequency), md_con)
        writeLines("", md_con)

        # Independence tests summary
        if (!is.null(s_data$chisq)) {
          writeLines("##### 独立性検定 (Chi-Square Tests)", md_con)
          writeLines("| 検定法 | 統計量 | 自由度 (df) | P 値 (Pr > ChiSq) |", md_con)
          writeLines("| :--- | :---: | :---: | :---: |", md_con)
          fmt_stat <- function(x) if (is.null(x) || is.na(x)) "-" else sprintf("%.4f", x)
          fmt_df <- function(x) if (is.null(x) || is.na(x)) "-" else as.character(x)
          fmt_p <- function(x) if (is.null(x) || is.na(x)) "-" else sprintf("%.6f", x)

          p_st <- s_data$chisq$pearson
          lr_st <- s_data$chisq$likelihood_ratio
          ca_st <- s_data$chisq$continuity_adj

          writeLines(sprintf("| Pearson カイ二乗 | %s | %s | %s |", fmt_stat(p_st$statistic), fmt_df(p_st$df), fmt_p(p_st$p_value)), md_con)
          writeLines(sprintf("| 尤度比カイ二乗 (G^2) | %s | %s | %s |", fmt_stat(lr_st$statistic), fmt_df(lr_st$df), fmt_p(lr_st$p_value)), md_con)
          if (!is.null(ca_st)) {
            writeLines(sprintf("| 2×2 連続性補正カイ二乗 | %s | %s | %s |", fmt_stat(ca_st$statistic), fmt_df(ca_st$df), fmt_p(ca_st$p_value)), md_con)
          }
          writeLines("", md_con)
        }

        # 2x2 Measures summary
        if (!is.null(s_data$measures)) {
          writeLines("##### 2×2 効果量と信頼区間 (Measures & Relative Risks)", md_con)
          writeLines("| 効果量指標 | 点推定値 | 95% 信頼区間 (Wald) | 状態・備考 |", md_con)
          writeLines("| :--- | :---: | :---: | :--- |", md_con)
          fmt_ci <- function(est, lo, hi) {
            if (is.null(est) || is.na(est)) return("-")
            sprintf("%.4f (%.4f, %.4f)", est, lo, hi)
          }
          or <- s_data$measures$odds_ratio
          rr1 <- s_data$measures$relative_risk_col1
          rr2 <- s_data$measures$relative_risk_col2

          writeLines(sprintf("| オッズ比 (OR) | %s | %s | %s |",
                             fmt_stat(or$estimate), fmt_ci(or$estimate, or$lower_cl, or$upper_cl),
                             if (!is.null(or$status_reason)) or$status_reason else "正常"), md_con)
          writeLines(sprintf("| 相対リスク (列1: %s) | %s | %s | %s |",
                             col_lvls[1], fmt_stat(rr1$estimate), fmt_ci(rr1$estimate, rr1$lower_cl, rr1$upper_cl),
                             if (!is.null(rr1$status_reason)) rr1$status_reason else "正常"), md_con)
          writeLines(sprintf("| 相対リスク (列2: %s) | %s | %s | %s |",
                             col_lvls[2], fmt_stat(rr2$estimate), fmt_ci(rr2$estimate, rr2$lower_cl, rr2$upper_cl),
                             if (!is.null(rr2$status_reason)) rr2$status_reason else "正常"), md_con)
          writeLines("", md_con)
        }

        # Fisher Exact / Monte Carlo summary
        if (!is.null(s_data$fisher)) {
          f_res <- s_data$fisher
          writeLines("##### Fisher 正確検定 / Monte Carlo 推定", md_con)
          if (!is.null(f_res$status_reason) && is.null(f_res$p_value)) {
            writeLines(sprintf("- **状態コード**: `%s`", f_res$status_reason), md_con)
            if (!is.null(f_res$error_message)) writeLines(sprintf("- **メッセージ**: %s", f_res$error_message), md_con)
          } else {
            writeLines(sprintf("- **手法**: `%s`", f_res$method), md_con)
            writeLines(sprintf("- **両側 P 値**: %.6f", f_res$p_value), md_con)
            if (f_res$method == "monte_carlo") {
              writeLines(sprintf("- **Monte Carlo アルゴリズム**: `%s`", f_res$mc_sampling_algorithm), md_con)
              writeLines(sprintf("- **反復回数 (B)**: %d, **極端表数 (M)**: %d", f_res$replications, f_res$extreme_count), md_con)
              writeLines(sprintf("- **標準誤差 (SE)**: %.6f", f_res$std_err), md_con)
              writeLines(sprintf("- **%.1f%% 信頼区間**: (%.6f, %.6f)", f_res$confidence_level * 100, f_res$lower_cl, f_res$upper_cl), md_con)
              if (!is.null(f_res$fallback_reason)) {
                writeLines(sprintf("- **フォールバック理由**: `%s` (初期要求: `%s`, 発生事象: `%s`)",
                                   f_res$fallback_reason, f_res$requested_method, f_res$status_reason), md_con)
              }
            }
          }
          writeLines("", md_con)
        }
      }
    }
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
      freq_results_json = list(
        path = "freq_results.json",
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

if (!interactive() && sys.nframe() == 0) {
  main()
}
