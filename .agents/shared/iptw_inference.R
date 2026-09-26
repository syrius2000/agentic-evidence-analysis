# .agents/shared/iptw_inference.R — IPTW Propensity Score Bootstrap Inference Engine
# Implements Section 10 of OpenSpec comparative-evidence-reporting-v3.

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "iptw_inference.R", files)
  script_dir <- if (length(own)) dirname(tail(own, 1L)[[1L]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(script_dir, "comparative_contrasts.R")
  if (!file.exists(contrasts_path)) stop("[MISSING_COMPARATIVE_CONTRASTS] comparative_contrasts.R が見つかりません")
  source(contrasts_path, local = FALSE)
})

validate_iptw_data <- function(
  data,
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = NULL,
  subject_id_col = NULL
) {
  if (!is.data.frame(data)) {
    stop("[INVALID_IPTW_DATA] 入力データは data.frame である必要があります")
  }

  required_cols <- c(treatment_col, outcome_col)
  if (!is.null(subject_id_col)) required_cols <- c(subject_id_col, required_cols)
  if (!is.null(covariates)) required_cols <- c(required_cols, covariates)

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("[MISSING_REQUIRED_COLUMNS] 必須列が見つかりません: %s", paste(missing_cols, collapse = ", ")))
  }

  if (nrow(data) < 10L) {
    stop("[INSUFFICIENT_SAMPLE_SIZE] IPTW 解析には最低 10 行のデータが必要です")
  }

  if (anyNA(data[[treatment_col]]) || anyNA(data[[outcome_col]])) {
    stop("[INVALID_IPTW_DATA] treatment または outcome に NA は許可されません")
  }

  if (!is.null(subject_id_col)) {
    subject_ids <- data[[subject_id_col]]
    if (anyNA(subject_ids)) stop("[INVALID_SUBJECT_ID] subject ID に NA は許可されません")
    if (anyDuplicated(subject_ids)) stop("[REPEATED_SUBJECT_ROWS] 1 subject 1 row の IPTW 入力で subject ID の重複を検出しました")
  }

  treatments <- data[[treatment_col]]
  if (!all(treatments %in% c(0L, 1L))) {
    stop("[INVALID_TREATMENT_VALUE] treatment は 0 または 1 の二値である必要があります")
  }
  if (sum(treatments == 1L) < 2L || sum(treatments == 0L) < 2L) {
    stop("[INSUFFICIENT_ARM_SIZE] 処置群・対照群の双方が最低 2 名必要です")
  }

  outcomes <- data[[outcome_col]]
  if (!all(outcomes %in% c(0L, 1L))) {
    stop("[INVALID_BINARY_OUTCOME] outcome は 0 または 1 の二値である必要があります")
  }

  if (is.null(covariates) || length(covariates) == 0L) {
    stop("[MISSING_COVARIATES] プロペンシティスコア推定用の共変量を 1 つ以上指定してください")
  }

  for (cov in covariates) {
    if (!is.numeric(data[[cov]])) {
      stop(sprintf("[INVALID_COVARIATE_TYPE] 共変量 '%s' は数値型である必要があります", cov))
    }
    if (anyNA(data[[cov]])) {
      stop(sprintf("[INVALID_COVARIATE_VALUE] 共変量 '%s' に NA は許可されません", cov))
    }
    if (any(!is.finite(data[[cov]]))) {
      stop(sprintf("[INVALID_COVARIATE_VALUE] 共変量 '%s' に非有限値 (Inf, -Inf, NaN) は許可されません", cov))
    }
  }

  invisible(TRUE)
}

estimate_propensity_scores <- function(
  data,
  treatment_col = "treatment",
  covariates = NULL,
  ps_boundary = c(1e-6, 1 - 1e-6)
) {
  formula_str <- paste(treatment_col, "~", paste(covariates, collapse = " + "))
  ps_formula <- stats::as.formula(formula_str)

  fit <- tryCatch({
    stats::glm(ps_formula, data = data, family = stats::binomial())
  }, error = function(e) {
    NULL
  })

  if (is.null(fit) || !isTRUE(fit$converged)) {
    return(list(ps = NULL, ps_raw = NULL, clipping = NULL, model = NULL, converged = FALSE))
  }

  ps_raw <- stats::predict(fit, type = "response")
  ps <- pmin(pmax(ps_raw, ps_boundary[[1L]]), ps_boundary[[2L]])

  list(ps = ps, ps_raw = ps_raw, clipping = list(
    mode = "clamp", lower = ps_boundary[[1L]], upper = ps_boundary[[2L]],
    clipped_low_count = as.integer(sum(ps_raw < ps_boundary[[1L]])),
    clipped_high_count = as.integer(sum(ps_raw > ps_boundary[[2L]])),
    raw_min = min(ps_raw), raw_max = max(ps_raw)
  ), model = fit, converged = TRUE)
}

compute_iptw_weights <- function(
  treatment,
  ps,
  estimand = c("ATE", "ATT"),
  stabilization = FALSE,
  truncation = NULL,
  att_scaling_mode = c("conventional", "marginal_odds_scaled")
) {
  estimand <- match.arg(estimand)
  att_scaling_mode <- match.arg(att_scaling_mode)

  p_A1 <- mean(treatment == 1L)
  p_A0 <- 1.0 - p_A1

  if (estimand == "ATE") {
    if (isTRUE(stabilization)) {
      weights <- ifelse(treatment == 1L, p_A1 / ps, p_A0 / (1.0 - ps))
    } else {
      weights <- ifelse(treatment == 1L, 1.0 / ps, 1.0 / (1.0 - ps))
    }
  } else { # ATT
    if (isTRUE(stabilization) && att_scaling_mode != "marginal_odds_scaled") {
      stop("[INVALID_ATT_STABILIZATION] ATT の stabilization=TRUE には marginal_odds_scaled を指定してください")
    }
    if (isTRUE(stabilization) && att_scaling_mode == "marginal_odds_scaled") {
      weights <- ifelse(treatment == 1L, 1.0, (ps / (1.0 - ps)) * (p_A1 / p_A0))
    } else {
      weights <- ifelse(treatment == 1L, 1.0, ps / (1.0 - ps))
    }
  }

  # Apply percentile truncation if requested
  if (!is.null(truncation) && length(truncation) == 2L) {
    low_p <- truncation[[1L]]
    high_p <- truncation[[2L]]
    if (is.numeric(low_p) && is.numeric(high_p) && low_p >= 0 && high_p <= 1 && low_p < high_p) {
      for (arm in c(1L, 0L)) {
        mask <- treatment == arm
        arm_w <- weights[mask]
        q_low <- stats::quantile(arm_w, probs = low_p, na.rm = TRUE)
        q_high <- stats::quantile(arm_w, probs = high_p, na.rm = TRUE)
        weights[mask] <- pmin(pmax(arm_w, q_low), q_high)
      }
    }
  }

  weights
}

compute_iptw_weighted_risks <- function(
  outcome,
  treatment,
  weights
) {
  w_T <- weights[treatment == 1L]
  y_T <- outcome[treatment == 1L]
  w_R <- weights[treatment == 0L]
  y_R <- outcome[treatment == 0L]

  sum_w_T <- sum(w_T)
  sum_w_R <- sum(w_R)

  p_target <- if (sum_w_T > 0) sum(w_T * y_T) / sum_w_T else 0.0
  p_reference <- if (sum_w_R > 0) sum(w_R * y_R) / sum_w_R else 0.0

  rd <- p_target - p_reference
  rr <- if (p_reference > 0) p_target / p_reference else NA_real_

  # Kish's Effective Sample Size: (sum(w))^2 / sum(w^2)
  ess_T <- (sum_w_T^2) / sum(w_T^2)
  ess_R <- (sum_w_R^2) / sum(w_R^2)

  list(
    p_target = p_target,
    p_reference = p_reference,
    rd = rd,
    rr = rr,
    target_ess = ess_T,
    reference_ess = ess_R
  )
}

iptw_extreme_weight_badge <- function(weights) {
  w_quant <- stats::quantile(weights, probs = c(0, 0.25, 0.5, 0.75, 1.0))
  if (w_quant[[5L]] > 20.0 || (w_quant[[5L]] / w_quant[[3L]]) > 10.0) "EXTREME_WEIGHTS_WARNING" else NULL
}

compute_iptw_covariate_balance <- function(
  data,
  treatment_col = "treatment",
  covariates = NULL,
  weights = NULL
) {
  if (is.null(covariates) || length(covariates) == 0L) return(NULL)

  treatment <- data[[treatment_col]]
  N <- nrow(data)
  if (is.null(weights)) weights <- rep(1.0, N)

  results <- vector("list", length(covariates))

  for (i in seq_along(covariates)) {
    cov <- covariates[[i]]
    x <- data[[cov]]

    x_T <- x[treatment == 1L]
    x_R <- x[treatment == 0L]
    w_T <- weights[treatment == 1L]
    w_R <- weights[treatment == 0L]

    # 1. Unweighted balance
    mean_T_unw <- mean(x_T)
    mean_R_unw <- mean(x_R)
    var_T_unw <- stats::var(x_T)
    var_R_unw <- stats::var(x_R)
    s_pool_unw <- sqrt((var_T_unw + var_R_unw) / 2)
    diff_unw <- mean_T_unw - mean_R_unw

    if (s_pool_unw == 0) {
      smd_unweighted <- if (diff_unw == 0) 0.0 else NULL
      status_unw <- if (diff_unw == 0) "ZERO_VARIANCE_ZERO_DIFFERENCE" else "ZERO_VARIANCE_NONZERO_DIFFERENCE"
    } else {
      smd_unweighted <- diff_unw / s_pool_unw
      status_unw <- "OK"
    }

    # 2. Weighted balance
    sum_w_T <- sum(w_T)
    sum_w_R <- sum(w_R)
    mean_T_w <- sum(w_T * x_T) / sum_w_T
    mean_R_w <- sum(w_R * x_R) / sum_w_R

    # Weighted second central moment
    var_T_w <- sum(w_T * (x_T - mean_T_w)^2) / sum_w_T
    var_R_w <- sum(w_R * (x_R - mean_R_w)^2) / sum_w_R
    s_pool_w <- sqrt((var_T_w + var_R_w) / 2)
    diff_w <- mean_T_w - mean_R_w

    if (s_pool_w == 0) {
      smd_weighted <- if (diff_w == 0) 0.0 else NULL
      status_w <- if (diff_w == 0) "ZERO_VARIANCE_ZERO_DIFFERENCE" else "ZERO_VARIANCE_NONZERO_DIFFERENCE"
    } else {
      smd_weighted <- diff_w / s_pool_w
      status_w <- "OK"
    }

    results[[i]] <- list(
      covariate = cov,
      unweighted = list(
        target_mean = mean_T_unw,
        reference_mean = mean_R_unw,
        smd = smd_unweighted,
        status = status_unw
      ),
      weighted = list(
        target_mean = mean_T_w,
        reference_mean = mean_R_w,
        smd = smd_weighted,
        status = status_w
      )
    )
  }

  results
}

compute_ps_positivity_diagnostics <- function(
  treatment,
  ps,
  ps_raw = ps
) {
  ps_T <- ps[treatment == 1L]
  ps_R <- ps[treatment == 0L]
  raw_T <- ps_raw[treatment == 1L]
  raw_R <- ps_raw[treatment == 0L]

  summarize_vec <- function(v) {
    q <- stats::quantile(v, probs = c(0, 0.25, 0.5, 0.75, 1.0), na.rm = TRUE)
    list(
      min = unname(q[[1L]]),
      q25 = unname(q[[2L]]),
      median = unname(q[[3L]]),
      mean = mean(v),
      q75 = unname(q[[4L]]),
      max = unname(q[[5L]])
    )
  }

  common_support_min <- max(min(ps_T), min(ps_R))
  common_support_max <- min(max(ps_T), max(ps_R))
  has_overlap <- common_support_min <= common_support_max

  list(
    target_ps = summarize_vec(ps_T),
    reference_ps = summarize_vec(ps_R),
    raw_target_ps = summarize_vec(raw_T),
    raw_reference_ps = summarize_vec(raw_R),
    common_support = list(
      min = max(min(raw_T), min(raw_R)),
      max = min(max(raw_T), max(raw_R)),
      has_overlap = max(min(raw_T), min(raw_R)) <= min(max(raw_T), max(raw_R)),
      effective_min = common_support_min,
      effective_max = common_support_max,
      effective_has_overlap = has_overlap
    )
  )
}

sample_iptw_bootstrap <- function(
  data,
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = NULL,
  estimand = "ATE",
  stabilization = FALSE,
  truncation = NULL,
  att_scaling_mode = "conventional",
  ps_boundary = c(1e-6, 1 - 1e-6),
  num_draws = 4000L,
  seed = 42L,
  max_failure_rate = 0.05
) {
  N <- nrow(data)
  B <- as.integer(num_draws)

  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }

  target_draws <- numeric(B)
  reference_draws <- numeric(B)
  rd_draws <- numeric(B)
  rr_draws <- rep(NA_real_, B)

  failed_replicates <- 0L
  success_idx <- 0L
  attempt <- 0L
  clipping_replicates <- 0L
  total_clipped_low <- 0L
  total_clipped_high <- 0L
  max_clipped_fraction <- 0.0
  max_attempts <- B + ceiling(B * max_failure_rate * 2)

  while (success_idx < B && attempt < max_attempts) {
    attempt <- attempt + 1L
    boot_indices <- sample.int(N, size = N, replace = TRUE)
    boot_df <- data[boot_indices, , drop = FALSE]

    treat_b <- boot_df[[treatment_col]]
    if (length(unique(treat_b)) < 2L) {
      failed_replicates <- failed_replicates + 1L
      next
    }

    # In-replicate propensity score model refitting (iptw_mode = "refit_ps")
    ps_res <- estimate_propensity_scores(boot_df, treatment_col = treatment_col, covariates = covariates, ps_boundary = ps_boundary)
    if (!isTRUE(ps_res$converged)) {
      failed_replicates <- failed_replicates + 1L
      next
    }
    clipped_n <- ps_res$clipping$clipped_low_count + ps_res$clipping$clipped_high_count
    if (clipped_n > 0L) clipping_replicates <- clipping_replicates + 1L
    total_clipped_low <- total_clipped_low + ps_res$clipping$clipped_low_count
    total_clipped_high <- total_clipped_high + ps_res$clipping$clipped_high_count
    max_clipped_fraction <- max(max_clipped_fraction, clipped_n / N)

    weights_b <- compute_iptw_weights(
      treatment = treat_b,
      ps = ps_res$ps,
      estimand = estimand,
      stabilization = stabilization,
      truncation = truncation,
      att_scaling_mode = att_scaling_mode
    )

    risks_b <- compute_iptw_weighted_risks(
      outcome = boot_df[[outcome_col]],
      treatment = treat_b,
      weights = weights_b
    )

    success_idx <- success_idx + 1L
    target_draws[[success_idx]] <- risks_b$p_target
    reference_draws[[success_idx]] <- risks_b$p_reference
    rd_draws[[success_idx]] <- risks_b$rd
    if (risks_b$p_reference > 0) {
      rr_draws[[success_idx]] <- risks_b$p_target / risks_b$p_reference
    }
  }

  failure_rate <- failed_replicates / attempt
  if (success_idx < B || failure_rate > max_failure_rate) {
    stop(sprintf("[IPTW_CONVERGENCE_FAILURE] ブートストラップ反復内モデル再推定の失敗率 (%.2f%%) が許容閾値 (%.2f%%) を超過しました",
                 failure_rate * 100, max_failure_rate * 100))
  }

  undefined_rr <- sum(is.na(rr_draws))
  defined_rr <- B - undefined_rr

  list(
    target_draws = target_draws,
    reference_draws = reference_draws,
    rd_draws = rd_draws,
    rr_draws = rr_draws,
    bootstrap_diagnostics = list(
      num_draws = B,
      failed_replicates = as.integer(failed_replicates),
      failure_rate = as.numeric(failure_rate),
      max_failure_rate = as.numeric(max_failure_rate),
      defined_rr_replicates = as.integer(defined_rr),
      undefined_rr_replicates = as.integer(undefined_rr)
    ),
    bootstrap_clipping_diagnostics = list(
      replicates_with_any_clipping = as.integer(clipping_replicates),
      total_clipped_low = as.integer(total_clipped_low),
      total_clipped_high = as.integer(total_clipped_high),
      max_clipped_fraction = as.numeric(max_clipped_fraction)
    )
  )
}

run_iptw_inference <- function(
  data,
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = NULL,
  subject_id_col = NULL,
  estimand = c("ATE", "ATT"),
  stabilization = FALSE,
  truncation = c(0.01, 0.99),
  att_scaling_mode = c("conventional", "marginal_odds_scaled"),
  ps_boundary = c(1e-6, 1 - 1e-6),
  max_failure_rate = 0.05,
  num_draws = 4000L,
  seed = 42L,
  primary_delta = NULL,
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  level = 0.95,
  persist_raw_draws = FALSE
) {
  estimand <- match.arg(estimand)
  att_scaling_mode <- match.arg(att_scaling_mode)

  # Parameter validation
  if (!is.numeric(num_draws) || length(num_draws) != 1L || !is.finite(num_draws) || num_draws < 10L || num_draws != floor(num_draws)) {
    stop("[INVALID_ARGUMENT] num_draws は 10 以上の単一有限整数である必要があります")
  }
  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) || seed != floor(seed)) {
      stop("[INVALID_ARGUMENT] seed は単一有限整数である必要があります")
    }
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    stop("[INVALID_ARGUMENT] level は 0 と 1 の間の単一有限数値である必要があります")
  }
  if (!is.null(truncation)) {
    if (!is.numeric(truncation) || length(truncation) != 2L || any(!is.finite(truncation)) ||
        truncation[[1L]] < 0 || truncation[[2L]] > 1 || truncation[[1L]] >= truncation[[2L]]) {
      stop("[INVALID_ARGUMENT] truncation は 0 以上 1 以下の昇順数値ペア (c(lower, upper)) である必要があります")
    }
  }
  if (!is.numeric(ps_boundary) || length(ps_boundary) != 2L || any(!is.finite(ps_boundary)) ||
      ps_boundary[[1L]] <= 0 || ps_boundary[[2L]] >= 1 || ps_boundary[[1L]] >= ps_boundary[[2L]]) {
    stop("[INVALID_ARGUMENT] ps_boundary は 0 < lower < upper < 1 の有限数値ペアである必要があります")
  }
  if (!is.numeric(max_failure_rate) || length(max_failure_rate) != 1L || !is.finite(max_failure_rate) || max_failure_rate < 0 || max_failure_rate >= 1) {
    stop("[INVALID_ARGUMENT] max_failure_rate は 0 以上 1 未満の単一有限数値である必要があります")
  }
  if (estimand == "ATT" && isTRUE(stabilization) && att_scaling_mode != "marginal_odds_scaled") {
    stop("[INVALID_ATT_STABILIZATION] ATT の stabilization=TRUE には marginal_odds_scaled を指定してください")
  }

  # 1. Input Validation
  validate_iptw_data(
    data = data,
    treatment_col = treatment_col,
    outcome_col = outcome_col,
    covariates = covariates,
    subject_id_col = subject_id_col
  )

  # 2. Observed Propensity Score Estimation & Weight Calculation
  ps_res <- estimate_propensity_scores(data, treatment_col = treatment_col, covariates = covariates, ps_boundary = ps_boundary)
  if (!isTRUE(ps_res$converged)) {
    stop("[IPTW_MODEL_CONVERGENCE_ERROR] 観測標本におけるプロペンシティスコアモデルの推定が収束しませんでした")
  }

  treatment <- data[[treatment_col]]
  outcome <- data[[outcome_col]]

  weights <- compute_iptw_weights(
    treatment = treatment,
    ps = ps_res$ps,
    estimand = estimand,
    stabilization = stabilization,
    truncation = truncation,
    att_scaling_mode = att_scaling_mode
  )

  # 3. Observed Sample Weighted Estimates
  obs_risks <- compute_iptw_weighted_risks(
    outcome = outcome,
    treatment = treatment,
    weights = weights
  )

  # 4. Covariate Balance & Positivity Diagnostics
  cov_balance <- compute_iptw_covariate_balance(
    data = data,
    treatment_col = treatment_col,
    covariates = covariates,
    weights = weights
  )

  positivity_diag <- compute_ps_positivity_diagnostics(
    treatment = treatment,
    ps = ps_res$ps,
    ps_raw = ps_res$ps_raw
  )

  # 5. In-Replicate Model Refitting Bootstrap
  boot <- sample_iptw_bootstrap(
    data = data,
    treatment_col = treatment_col,
    outcome_col = outcome_col,
    covariates = covariates,
    estimand = estimand,
    stabilization = stabilization,
    truncation = truncation,
    att_scaling_mode = att_scaling_mode,
    ps_boundary = ps_boundary,
    num_draws = num_draws,
    seed = seed,
    max_failure_rate = max_failure_rate
  )

  # 6. Comparative Contrasts Assembly
  target_raw_events <- as.integer(sum(outcome[treatment == 1L]))
  target_raw_total <- as.integer(sum(treatment == 1L))
  reference_raw_events <- as.integer(sum(outcome[treatment == 0L]))
  reference_raw_total <- as.integer(sum(treatment == 0L))

  observed_rr <- if (obs_risks$p_reference > 0) obs_risks$p_target / obs_risks$p_reference else NULL

  contrasts <- compute_comparative_contrasts(
    target_draws = boot$target_draws,
    reference_draws = boot$reference_draws,
    target_events = target_raw_events,
    target_total = target_raw_total,
    reference_events = reference_raw_events,
    reference_total = reference_raw_total,
    inferential_semantics = "bootstrap",
    observed_estimates = list(rd = obs_risks$rd, rr = observed_rr),
    primary_delta = primary_delta,
    delta_thresholds = delta_thresholds,
    level = level,
    domain = "iptw"
  )

  # Override cohort summaries with weighted risks and ESS
  contrasts$target_cohort$estimate_semantics <- "iptw_weighted_risk"
  contrasts$target_cohort$incidence_proportion <- obs_risks$p_target
  contrasts$target_cohort$estimate$value <- obs_risks$p_target
  contrasts$target_cohort$effective_sample_size <- obs_risks$target_ess
  contrasts$target_cohort["events"] <- list(NULL)
  contrasts$target_cohort["total"] <- list(NULL)

  contrasts$reference_cohort$estimate_semantics <- "iptw_weighted_risk"
  contrasts$reference_cohort$incidence_proportion <- obs_risks$p_reference
  contrasts$reference_cohort$estimate$value <- obs_risks$p_reference
  contrasts$reference_cohort$effective_sample_size <- obs_risks$reference_ess
  contrasts$reference_cohort["events"] <- list(NULL)
  contrasts$reference_cohort["total"] <- list(NULL)

  evidence <- contrasts

  # Check extreme weights warning
  w_quant <- stats::quantile(weights, probs = c(0, 0.25, 0.5, 0.75, 1.0))
  extreme_badge <- iptw_extreme_weight_badge(weights)
  if (!is.null(extreme_badge)) evidence$diagnostics$badges <- unique(c(evidence$diagnostics$badges, extreme_badge))

  # Governed zero-denominator and partial-undefined bootstrap replicate RR policy
  if (obs_risks$p_reference <= 0) {
    evidence$relative_risk$estimate["value"] <- list(NULL)
    evidence$relative_risk["interval"] <- list(NULL)
    evidence$relative_risk["mean"] <- list(NULL)
    evidence$relative_risk$mean_is_finite <- FALSE
    evidence$relative_risk$diagnostic <- "ZERO_REFERENCE_RISK"
    evidence$precision_metrics["log_rr_interval_width"] <- list(NULL)
    evidence$precision_metrics["rr_interval_fold_range"] <- list(NULL)
  } else if (boot$bootstrap_diagnostics$undefined_rr_replicates > 0L) {
    evidence$relative_risk["interval"] <- list(NULL)
    evidence$relative_risk["mean"] <- list(NULL)
    evidence$relative_risk$mean_is_finite <- FALSE
    evidence$relative_risk$diagnostic <- "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"
    evidence$precision_metrics["log_rr_interval_width"] <- list(NULL)
    evidence$precision_metrics["rr_interval_fold_range"] <- list(NULL)
  }

  # 7. IPTW Deliverable Payload
  evidence$iptw <- list(
    estimand = estimand,
    stabilization = isTRUE(stabilization),
    att_scaling_mode = if (estimand == "ATT") att_scaling_mode else NULL,
    iptw_mode = "refit_ps",
    propensity_model = list(family = "binomial", link = "logit", covariates = as.list(covariates)),
    propensity_score_boundary_policy = ps_res$clipping,
    bootstrap_clipping_diagnostics = boot$bootstrap_clipping_diagnostics,
    max_failure_rate = max_failure_rate,
    truncation = if (!is.null(truncation)) list(lower = truncation[[1L]], upper = truncation[[2L]]) else NULL,
    effective_sample_size = list(
      target = obs_risks$target_ess,
      reference = obs_risks$reference_ess
    ),
    raw_patient_counts = list(
      target = target_raw_total,
      reference = reference_raw_total,
      target_events = target_raw_events,
      reference_events = reference_raw_events
    ),
    weight_summary = list(
      min = unname(w_quant[[1L]]),
      q25 = unname(w_quant[[2L]]),
      median = unname(w_quant[[3L]]),
      mean = mean(weights),
      q75 = unname(w_quant[[4L]]),
      max = unname(w_quant[[5L]])
    ),
    covariate_balance = cov_balance,
    positivity = positivity_diag,
    bootstrap_diagnostics = boot$bootstrap_diagnostics
  )

  # 8. Uncertainty Draws Payload (comparative-draws-v1)
  draw_storage <- if (isTRUE(persist_raw_draws)) "persisted" else "ephemeral"
  draws <- list(
    schema_version = "comparative-draws-v1",
    inferential_semantics = "bootstrap",
    num_draws = as.integer(num_draws),
    draw_storage = draw_storage,
    target_draws = if (isTRUE(persist_raw_draws)) as.numeric(boot$target_draws) else NULL,
    reference_draws = if (isTRUE(persist_raw_draws)) as.numeric(boot$reference_draws) else NULL,
    seed = if (!is.null(seed)) as.integer(seed) else NULL,
    observed_sample_estimate = list(
      rd = obs_risks$rd,
      rr = observed_rr,
      p_target = obs_risks$p_target,
      p_reference = obs_risks$p_reference
    ),
    iptw_metadata = list(
      estimand = estimand,
      stabilization = isTRUE(stabilization),
      iptw_mode = "refit_ps",
      truncation = if (!is.null(truncation)) list(lower = truncation[[1L]], upper = truncation[[2L]]) else NULL,
      att_scaling_mode = if (estimand == "ATT") att_scaling_mode else NULL,
      propensity_model = list(family = "binomial", link = "logit", covariates = as.list(covariates)),
      propensity_score_boundary_policy = ps_res$clipping,
      bootstrap_clipping_diagnostics = boot$bootstrap_clipping_diagnostics,
      max_failure_rate = max_failure_rate,
      effective_sample_size = list(
        target = obs_risks$target_ess,
        reference = obs_risks$reference_ess
      ),
      bootstrap_diagnostics = boot$bootstrap_diagnostics
    )
  )

  list(evidence = evidence, draws = draws)
}
