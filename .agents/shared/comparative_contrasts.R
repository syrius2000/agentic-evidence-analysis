# .agents/shared/comparative_contrasts.R — Shared Contrast Transformation and Evidence Engine
# Implements Sections 2 & 7 of OpenSpec comparative-evidence-reporting-v3

compute_comparative_contrasts <- function(
  target_draws,
  reference_draws,
  target_events,
  target_total,
  reference_events,
  reference_total,
  inferential_semantics = c("posterior", "bootstrap"),
  observed_estimates = NULL, # list(rd=..., rr=...) for bootstrap
  primary_delta = NULL,      # e.g., 0.05 (proportion). If NULL, practical classification is disabled
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  level = 0.95,
  domain = "safety"
) {
  inferential_semantics <- match.arg(inferential_semantics)

  S <- length(target_draws)
  if (S != length(reference_draws) || S < 10L) {
    stop("[ERROR] target_draws and reference_draws must be non-empty vectors of equal length.")
  }

  alpha <- (1 - level) / 2
  prob_bounds <- c(alpha, 0.5, 1 - alpha)

  # 1. Primary Point Estimate Source & Interval Method
  if (inferential_semantics == "posterior") {
    est_source <- "posterior_median"
    int_method <- "posterior_eti"
  } else {
    est_source <- "observed_sample_estimate"
    int_method <- "bootstrap_percentile"
  }

  # 2. Risk Difference (RD)
  rd_draws <- target_draws - reference_draws
  rd_quantiles <- stats::quantile(rd_draws, probs = prob_bounds, na.rm = TRUE)

  if (inferential_semantics == "posterior") {
    rd_point <- unname(rd_quantiles[[2L]])
  } else {
    rd_point <- if (!is.null(observed_estimates$rd)) observed_estimates$rd else (target_events / target_total) - (reference_events / reference_total)
  }

  rd_lower <- unname(rd_quantiles[[1L]])
  rd_upper <- unname(rd_quantiles[[3L]])
  rd_width <- rd_upper - rd_lower

  # 3. Relative Risk (RR)
  # Theoretical mean diverges when reference events == 0 under Beta(0.5, n+0.5) prior
  zero_reference <- (reference_events == 0L)
  zero_both <- (target_events == 0L && reference_events == 0L)
  sparse_events <- ((target_events + reference_events) < 5L)

  rr_draws <- target_draws / pmax(reference_draws, 1e-15)
  rr_quantiles <- stats::quantile(rr_draws, probs = prob_bounds, na.rm = TRUE)

  if (inferential_semantics == "posterior") {
    rr_point <- unname(rr_quantiles[[2L]])
    if (zero_reference) {
      rr_mean <- NULL
      rr_mean_finite <- FALSE
    } else {
      rr_mean <- mean(rr_draws, na.rm = TRUE)
      rr_mean_finite <- is.finite(rr_mean)
    }
  } else {
    rr_point <- if (!is.null(observed_estimates$rr)) observed_estimates$rr else {
      if (reference_events == 0L) NA_real_ else (target_events / target_total) / (reference_events / reference_total)
    }
    rr_mean <- mean(rr_draws, na.rm = TRUE)
    rr_mean_finite <- is.finite(rr_mean)
  }

  rr_lower <- unname(rr_quantiles[[1L]])
  rr_upper <- unname(rr_quantiles[[3L]])

  log_rr_width <- if (!is.na(rr_lower) && !is.na(rr_upper) && rr_lower > 1e-10 && rr_upper > 1e-10) {
    log(rr_upper) - log(rr_lower)
  } else {
    NA_real_
  }

  # 4. Cohort Specific Summaries
  t_quant <- stats::quantile(target_draws, probs = prob_bounds, na.rm = TRUE)
  r_quant <- stats::quantile(reference_draws, probs = prob_bounds, na.rm = TRUE)

  target_cohort_summary <- list(
    label = "Target",
    events = target_events,
    total = target_total,
    incidence_proportion = target_events / target_total,
    estimate = list(
      value = if (inferential_semantics == "posterior") unname(t_quant[[2L]]) else target_events / target_total,
      source = est_source
    ),
    interval = list(
      lower = unname(t_quant[[1L]]),
      upper = unname(t_quant[[3L]]),
      level = level,
      method = int_method
    )
  )

  reference_cohort_summary <- list(
    label = "Reference",
    events = reference_events,
    total = reference_total,
    incidence_proportion = reference_events / reference_total,
    estimate = list(
      value = if (inferential_semantics == "posterior") unname(r_quant[[2L]]) else reference_events / reference_total,
      source = est_source
    ),
    interval = list(
      lower = unname(r_quant[[1L]]),
      upper = unname(r_quant[[3L]]),
      level = level,
      method = int_method
    )
  )

  # 5. Natural Unit Conversions
  excess_per_100 <- rd_point * 100
  additional_subjects_per_100 <- excess_per_100

  # 6. Direction Support Metric
  rd_gt_zero <- mean(rd_draws > 0, na.rm = TRUE)
  if (inferential_semantics == "posterior") {
    direction_support <- list(
      metric_name = "p_direction_target_gt_reference",
      support_value = rd_gt_zero,
      label = "P(RD > 0)"
    )
  } else {
    direction_support <- list(
      metric_name = "bootstrap_support_fraction_rd_gt_zero",
      support_value = rd_gt_zero,
      label = "Bootstrap Support Fraction (RD > 0)"
    )
  }

  # 7. Practical Region Support and U-Grade
  if (!is.null(primary_delta) && !is.na(primary_delta) && primary_delta > 0) {
    q_T <- mean(rd_draws > primary_delta, na.rm = TRUE)
    q_R <- mean(rd_draws < -primary_delta, na.rm = TRUE)
    q_N <- mean(rd_draws >= -primary_delta & rd_draws <= primary_delta, na.rm = TRUE)

    # Invariant enforcement: q_T + q_N + q_R == 1.0 within tolerance
    sum_q <- q_T + q_N + q_R
    if (abs(sum_q - 1.0) > 1e-6) {
      q_T <- q_T / sum_q
      q_N <- q_N / sum_q
      q_R <- q_R / sum_q
    }

    practical_region_support <- list(
      inferential_semantics = inferential_semantics,
      target_excess = q_T,
      practical_neutral = q_N,
      reference_excess = q_R,
      primary_delta = primary_delta
    )

    C <- max(q_T, q_N, q_R)
    if (q_T == C) {
      dominant_region <- "target_excess"
    } else if (q_R == C) {
      dominant_region <- "reference_excess"
    } else {
      dominant_region <- "practical_neutral"
    }

    if (C >= 0.95) {
      u_grade <- "U0"
      u_label <- "Very High Resolution (>= 95% in single region)"
    } else if (C >= 0.80) {
      u_grade <- "U1"
      u_label <- "High Resolution (80% - 95% in single region)"
    } else if (C >= 0.60) {
      u_grade <- "U2"
      u_label <- "Moderate Resolution (60% - 80% in single region)"
    } else {
      u_grade <- "U3"
      u_label <- "Low / Indeterminate Resolution (< 60% in single region)"
    }

    resolution_grade <- list(
      grade = u_grade,
      label = u_label,
      dominant_region = dominant_region,
      max_region_probability = C
    )
  } else {
    practical_region_support <- NULL
    resolution_grade <- list(
      grade = "NONE",
      label = "Practical difference evaluation disabled (primary_delta is null)",
      dominant_region = "none",
      max_region_probability = NULL
    )
  }

  # 8. Delta Profile Matrix
  delta_profile <- list()
  if (length(delta_thresholds) > 0L) {
    sorted_deltas <- sort(unique(delta_thresholds))
    for (d in sorted_deltas) {
      p_gt <- mean(rd_draws > d, na.rm = TRUE)
      p_lt <- mean(rd_draws < -d, na.rm = TRUE)
      p_neu <- mean(rd_draws >= -d & rd_draws <= d, na.rm = TRUE)
      delta_profile[[length(delta_profile) + 1L]] <- list(
        delta = d,
        p_rd_gt_delta = p_gt,
        p_rd_lt_minus_delta = p_lt,
        p_neutral = p_neu
      )
    }
  }

  # 9. Badges and Diagnostics
  badges <- character(0)
  if (zero_reference) badges <- c(badges, "ZERO_REFERENCE")
  if (zero_both) badges <- c(badges, "ZERO_BOTH")
  if (sparse_events) badges <- c(badges, "SPARSE_EVENTS")
  if (!is.na(log_rr_width) && log_rr_width > 3.0) badges <- c(badges, "UNSTABLE_RR_INTERVAL")

  diagnostics <- list(
    badges = as.list(badges)
  )

  # 10. Assemble canonical ComparativeEvidenceV1 output
  evidence_obj <- list(
    schema_version = "comparative-evidence-v1",
    inferential_semantics = inferential_semantics,
    target_cohort = target_cohort_summary,
    reference_cohort = reference_cohort_summary,
    risk_difference = list(
      estimate = list(
        value = rd_point,
        source = est_source
      ),
      interval = list(
        lower = rd_lower,
        upper = rd_upper,
        level = level,
        method = int_method
      ),
      excess_per_100 = excess_per_100,
      additional_subjects_per_100_treated = additional_subjects_per_100
    ),
    relative_risk = list(
      estimate = list(
        value = if (is.null(rr_point) || is.na(rr_point)) NULL else rr_point,
        source = est_source
      ),
      interval = list(
        lower = if (is.null(rr_lower) || is.na(rr_lower)) NULL else rr_lower,
        upper = if (is.null(rr_upper) || is.na(rr_upper)) NULL else rr_upper,
        level = level,
        method = int_method
      ),
      mean = rr_mean,
      mean_is_finite = rr_mean_finite
    ),
    direction_support = direction_support,
    practical_region_support = practical_region_support,
    resolution_grade = resolution_grade,
    delta_profile = delta_profile,
    precision_metrics = list(
      rd_interval_width = rd_width,
      log_rr_interval_width = if (is.null(log_rr_width) || is.na(log_rr_width)) NULL else log_rr_width,
      rr_interval_fold_range = NULL,
      monte_carlo_draws = S,
      effective_sample_size = NULL
    ),
    diagnostics = diagnostics
  )

  evidence_obj
}

# Person-time rates have event/exposure denominators and must not reuse risk fields.
compute_rate_contrasts <- function(
  target_draws,
  reference_draws,
  target_events,
  target_exposure,
  reference_events,
  reference_exposure,
  exposure_unit = c("person_years", "person_months"),
  level = 0.95
) {
  exposure_unit <- match.arg(exposure_unit)
  if (!is.numeric(target_draws) || !is.numeric(reference_draws) ||
      length(target_draws) != length(reference_draws) || length(target_draws) < 10L ||
      any(!is.finite(target_draws)) || any(!is.finite(reference_draws)) ||
      any(target_draws <= 0) || any(reference_draws <= 0)) {
    stop("[INVALID_RATE_DRAWS] 両群の率drawは同数かつ10件以上の有限・正値である必要があります")
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    stop("[INVALID_INTERVAL_LEVEL] 信用区間水準は0と1の間で指定してください")
  }

  probs <- c((1 - level) / 2, 0.5, 1 - (1 - level) / 2)
  quantiles <- function(x) unname(stats::quantile(x, probs = probs))
  interval <- function(q) list(lower = q[[1L]], upper = q[[3L]], level = level, method = "posterior_eti")
  estimate <- function(q) list(value = q[[2L]], source = "posterior_median")
  t_q <- quantiles(target_draws)
  r_q <- quantiles(reference_draws)
  ird_draws <- target_draws - reference_draws
  irr_draws <- target_draws / reference_draws
  if (any(!is.finite(irr_draws))) stop("[NONFINITE_RATE_RATIO] 率比drawが有限値ではありません")
  ird_q <- quantiles(ird_draws)
  irr_q <- quantiles(irr_draws)

  # E[lambda_T/lambda_R] exists only when the reference Gamma shape exceeds 1.
  target_shape <- target_events + 0.5
  reference_shape <- reference_events + 0.5
  irr_mean_finite <- reference_shape > 1
  irr_mean <- if (irr_mean_finite) {
    (target_shape / target_exposure) * (reference_exposure / (reference_shape - 1))
  } else NULL
  events_per_100_person_years <- ird_q[[2L]] * if (exposure_unit == "person_months") 1200 else 100
  if ((irr_mean_finite && !is.finite(irr_mean)) || !is.finite(events_per_100_person_years)) {
    stop("[NONFINITE_RATE_SUMMARY] 率要約を有限値で表せません")
  }

  list(
    schema_version = "comparative-rate-evidence-v1",
    inferential_semantics = "posterior",
    target_cohort = list(
      label = "Target", events = target_events, exposure = target_exposure,
      incidence_rate = list(estimate = estimate(t_q), interval = interval(t_q))
    ),
    reference_cohort = list(
      label = "Reference", events = reference_events, exposure = reference_exposure,
      incidence_rate = list(estimate = estimate(r_q), interval = interval(r_q))
    ),
    incidence_rate_difference = list(
      estimate = estimate(ird_q), interval = interval(ird_q),
      additional_events_per_100_person_years = events_per_100_person_years
    ),
    incidence_rate_ratio = list(
      estimate = estimate(irr_q), interval = interval(irr_q),
      mean = irr_mean, mean_is_finite = irr_mean_finite,
      diagnostic = if (irr_mean_finite) NULL else "ZERO_REFERENCE_EVENTS"
    ),
    direction_support = list(
      metric_name = "p_ird_gt_zero", value = mean(ird_draws > 0), label = "P(IRD > 0)"
    ),
    person_time = list(
      exposure_unit = exposure_unit,
      rate_unit = if (exposure_unit == "person_months") "events_per_person_month" else "events_per_person_year",
      gamma_parameterization = "shape_rate",
      target_exposure = target_exposure,
      reference_exposure = reference_exposure,
      assumptions = list(
        constant_hazard_assumed = TRUE,
        within_subject_recurrent_event_clustering = "not_modeled",
        limitations = list(
          "一定の発生率を仮定する。時間変化するハザードは扱わない。",
          "同一被験者内の反復イベントのクラスタリングは扱わない。"
        )
      )
    )
  )
}
