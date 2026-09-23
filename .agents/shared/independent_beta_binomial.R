# .agents/shared/independent_beta_binomial.R — Independent Jeffreys Beta-Binomial Inference Engine
# Implements Section 3 of OpenSpec comparative-evidence-reporting-v3

suppressPackageStartupMessages({
  library(jsonlite)
})

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "independent_beta_binomial.R", files)
  dir <- if (length(own)) dirname(tail(own, 1)[[1]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(dir, "comparative_contrasts.R")
  if (file.exists(contrasts_path)) source(contrasts_path, local = FALSE)
})

run_independent_beta_binomial <- function(
  target_events,
  target_total,
  reference_events,
  reference_total,
  num_draws = 4000L,
  seed = 42L,
  primary_delta = NULL,
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  prior_sensitivity_mode = c("zero_cell", "off", "explicit"),
  level = 0.95,
  domain = "safety",
  persist_raw_draws = FALSE
) {
  prior_sensitivity_mode <- match.arg(prior_sensitivity_mode)

  # 1. Assertions on counts and totals
  if (!is.numeric(target_events) || !is.numeric(target_total) ||
      !is.numeric(reference_events) || !is.numeric(reference_total)) {
    stop("[ERROR] [INVALID_INPUT] Event and total counts must be numeric integers.")
  }

  is_int <- function(x) abs(x - round(x)) < 1e-8
  if (!is_int(target_events) || !is_int(target_total) ||
      !is_int(reference_events) || !is_int(reference_total)) {
    stop("[ERROR] [NON_INTEGER_COUNT] Event and total counts must be exact non-negative integers.")
  }

  x_T <- as.integer(round(target_events))
  n_T <- as.integer(round(target_total))
  x_R <- as.integer(round(reference_events))
  n_R <- as.integer(round(reference_total))

  if (x_T < 0L || x_R < 0L) {
    stop("[ERROR] [NEGATIVE_COUNT] Event counts must be non-negative.")
  }
  if (n_T <= 0L || n_R <= 0L) {
    stop("[ERROR] [EMPTY_DENOMINATOR] Cohort total denominators must be strictly positive (n > 0).")
  }
  if (x_T > n_T || x_R > n_R) {
    stop("[ERROR] [BOUNDS_EXCEEDED] Event counts cannot exceed total group denominators (x <= n).")
  }

  # 2. Deterministic Sampling under Jeffreys Prior Beta(0.5, 0.5)
  if (!is.null(seed)) set.seed(seed)

  alpha_T_post <- x_T + 0.5
  beta_T_post <- (n_T - x_T) + 0.5

  alpha_R_post <- x_R + 0.5
  beta_R_post <- (n_R - x_R) + 0.5

  target_draws <- stats::rbeta(num_draws, alpha_T_post, beta_T_post)
  reference_draws <- stats::rbeta(num_draws, alpha_R_post, beta_R_post)

  # Logical runtime draws interface (comparative-draws-v1)
  draw_storage <- if (isTRUE(persist_raw_draws)) "persisted" else "ephemeral"
  runtime_draws <- list(
    schema_version = "comparative-draws-v1",
    inferential_semantics = "posterior",
    num_draws = num_draws,
    draw_storage = draw_storage,
    target_draws = if (isTRUE(persist_raw_draws)) target_draws else NULL,
    reference_draws = if (isTRUE(persist_raw_draws)) reference_draws else NULL,
    seed = seed,
    observed_sample_estimate = NULL
  )

  # 3. Compute Comparative Contrasts & Evidence Summary
  evidence <- compute_comparative_contrasts(
    target_draws = target_draws,
    reference_draws = reference_draws,
    target_events = x_T,
    target_total = n_T,
    reference_events = x_R,
    reference_total = n_R,
    inferential_semantics = "posterior",
    primary_delta = primary_delta,
    delta_thresholds = delta_thresholds,
    level = level,
    domain = domain
  )

  # 4. Continuous Instability Metrics for RR
  rr_lower <- evidence$relative_risk$interval$lower
  rr_upper <- evidence$relative_risk$interval$upper
  fold_range <- if (!is.null(rr_lower) && !is.null(rr_upper) && !is.na(rr_lower) && !is.na(rr_upper) && rr_lower > 1e-8) {
    rr_upper / rr_lower
  } else {
    NA_real_
  }
  evidence$precision_metrics$rr_interval_fold_range <- fold_range
  evidence$precision_metrics$monte_carlo_draws <- num_draws
  evidence$precision_metrics$effective_sample_size <- NULL

  # 5. Prior Sensitivity Analysis against Uniform Prior Beta(1.0, 1.0)
  trigger_sensitivity <- FALSE
  if (prior_sensitivity_mode == "explicit") {
    trigger_sensitivity <- TRUE
  } else if (prior_sensitivity_mode == "zero_cell") {
    trigger_sensitivity <- (x_T == 0L || x_R == 0L)
  }

  if (trigger_sensitivity) {
    if (!is.null(seed)) set.seed(seed + 1000L)
    t_sens_draws <- stats::rbeta(num_draws, x_T + 1.0, (n_T - x_T) + 1.0)
    r_sens_draws <- stats::rbeta(num_draws, x_R + 1.0, (n_R - x_R) + 1.0)

    sens_evidence <- compute_comparative_contrasts(
      target_draws = t_sens_draws,
      reference_draws = r_sens_draws,
      target_events = x_T,
      target_total = n_T,
      reference_events = x_R,
      reference_total = n_R,
      inferential_semantics = "posterior",
      primary_delta = primary_delta,
      delta_thresholds = delta_thresholds,
      level = level,
      domain = domain
    )

    rd_diff <- abs(evidence$risk_difference$estimate$value - sens_evidence$risk_difference$estimate$value)
    dir_diff <- abs(evidence$direction_support$support_value - sens_evidence$direction_support$support_value)
    grade_match <- identical(evidence$resolution_grade$grade, sens_evidence$resolution_grade$grade)

    # Standard sensitivity policy: qualitative robust flag recorded along with exact deltas
    robust <- (dir_diff < 0.20) && (grade_match || is.null(primary_delta))

    evidence$diagnostics$prior_sensitivity <- list(
      mode = prior_sensitivity_mode,
      evaluated = TRUE,
      robust = robust,
      comparison = list(
        primary_prior = "Beta(0.5, 0.5) Jeffreys",
        sensitivity_prior = "Beta(1.0, 1.0) Uniform",
        primary_rd_median = evidence$risk_difference$estimate$value,
        sensitivity_rd_median = sens_evidence$risk_difference$estimate$value,
        rd_median_delta = rd_diff,
        primary_direction_support = evidence$direction_support$support_value,
        sensitivity_direction_support = sens_evidence$direction_support$support_value,
        direction_support_delta = dir_diff,
        primary_u_grade = evidence$resolution_grade$grade,
        sensitivity_u_grade = sens_evidence$resolution_grade$grade,
        u_grade_changed = !grade_match
      )
    )
  } else {
    evidence$diagnostics$prior_sensitivity <- list(
      mode = prior_sensitivity_mode,
      evaluated = FALSE,
      robust = NULL,
      comparison = NULL
    )
  }

  list(
    evidence = evidence,
    draws = runtime_draws
  )
}
