# .agents/shared/matched_set_inference.R — 1:k matched-set cluster bootstrap inference
# Implements Section 9 of OpenSpec comparative-evidence-reporting-v3.

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "matched_set_inference.R", files)
  script_dir <- if (length(own)) dirname(tail(own, 1L)[[1L]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(script_dir, "comparative_contrasts.R")
  if (!file.exists(contrasts_path)) stop("[MISSING_COMPARATIVE_CONTRASTS] comparative_contrasts.R が見つかりません")
  source(contrasts_path, local = FALSE)
})

validate_matched_set_data <- function(
  data,
  subject_id_col = "subject_id",
  set_col = "set_id",
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = NULL
) {
  if (!is.data.frame(data)) {
    stop("[INVALID_MATCHED_SET_DATA] 入力データは data.frame である必要があります")
  }

  if (is.null(subject_id_col) || !is.character(subject_id_col) || length(subject_id_col) != 1L || !nzchar(subject_id_col)) {
    stop("[MISSING_SUBJECT_ID_COL] subject_id_col は単一の文字列である必要があります")
  }

  required_cols <- c(subject_id_col, set_col, treatment_col, outcome_col)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("[MISSING_REQUIRED_COLUMNS] 必須列が見つかりません: %s", paste(missing_cols, collapse = ", ")))
  }

  if (nrow(data) == 0L) {
    stop("[EMPTY_MATCHED_SET_DATA] データが空です")
  }

  # Check missing values
  if (anyNA(data[[subject_id_col]]) || anyNA(data[[set_col]]) || anyNA(data[[treatment_col]]) || anyNA(data[[outcome_col]])) {
    stop("[INVALID_MATCHED_SET_DATA] subject_id, set_id, treatment, outcome に NA は許可されません")
  }

  # Validate non-replacement matching: no duplicate subject_id across entire cohort
  sub_ids <- data[[subject_id_col]]
  if (anyDuplicated(sub_ids)) {
    dup_ids <- unique(sub_ids[duplicated(sub_ids)])
    stop(sprintf("[DUPLICATE_SUBJECT_ID] 同一被験者が複数セットまたは同一セット内に重複して存在します (非復元抽出違反: %s)",
                 paste(head(dup_ids, 3L), collapse = ", ")))
  }

  treatments <- data[[treatment_col]]
  if (!all(treatments %in% c(0L, 1L))) {
    stop("[INVALID_TREATMENT_VALUE] treatment は 0 または 1 の二値である必要があります")
  }

  outcomes <- data[[outcome_col]]
  if (!all(outcomes %in% c(0L, 1L))) {
    stop("[INVALID_BINARY_OUTCOME] outcome は 0 または 1 の二値である必要があります")
  }

  # Check covariates if provided
  if (!is.null(covariates) && length(covariates) > 0L) {
    missing_covs <- setdiff(covariates, names(data))
    if (length(missing_covs) > 0L) {
      stop(sprintf("[MISSING_COVARIATE_COLUMNS] 指定された共変量列が見つかりません: %s", paste(missing_covs, collapse = ", ")))
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
  }

  # Validate 1:k matched set structure
  sets <- split(data, data[[set_col]])
  if (length(sets) == 0L) {
    stop("[EMPTY_MATCHED_SET_DATA] 有効なマッチドセットが存在しません")
  }

  target_counts <- vapply(sets, function(df) sum(df[[treatment_col]] == 1L), integer(1L))
  if (any(target_counts != 1L)) {
    bad_sets <- names(sets)[target_counts != 1L]
    stop(sprintf("[INVALID_MATCHED_SET_STRUCTURE] 各セットには処置群 (treatment=1) が厳密に 1 名必要です (不正セット: %s)",
                 paste(head(bad_sets, 3L), collapse = ", ")))
  }

  control_counts <- vapply(sets, function(df) sum(df[[treatment_col]] == 0L), integer(1L))
  if (any(control_counts < 1L)) {
    bad_sets <- names(sets)[control_counts < 1L]
    stop(sprintf("[INVALID_MATCHED_SET_STRUCTURE] 各セットには対照群 (treatment=0) が 1 名以上必要です (不正セット: %s)",
                 paste(head(bad_sets, 3L), collapse = ", ")))
  }

  invisible(TRUE)
}

compute_matched_set_att_estimates <- function(
  data,
  set_col = "set_id",
  treatment_col = "treatment",
  outcome_col = "outcome"
) {
  sets <- split(data, data[[set_col]])
  J <- length(sets)

  y_T <- vapply(sets, function(df) {
    df[[outcome_col]][df[[treatment_col]] == 1L][[1L]]
  }, integer(1L), USE.NAMES = FALSE)

  y_R_bar <- vapply(sets, function(df) {
    controls <- df[[outcome_col]][df[[treatment_col]] == 0L]
    mean(controls)
  }, numeric(1L), USE.NAMES = FALSE)

  k_j <- vapply(sets, function(df) {
    sum(df[[treatment_col]] == 0L)
  }, integer(1L), USE.NAMES = FALSE)

  p_target <- mean(y_T)
  p_reference <- mean(y_R_bar)
  rd <- p_target - p_reference
  rr <- if (p_reference > 0) p_target / p_reference else NA_real_

  list(
    J = J,
    k_j = k_j,
    y_T = y_T,
    y_R_bar = y_R_bar,
    p_target = p_target,
    p_reference = p_reference,
    rd = rd,
    rr = rr
  )
}

compute_covariate_balance <- function(
  data,
  set_col = "set_id",
  treatment_col = "treatment",
  covariates = NULL
) {
  if (is.null(covariates) || length(covariates) == 0L) {
    return(NULL)
  }

  sets <- split(data, data[[set_col]])
  J <- length(sets)

  results <- vector("list", length(covariates))

  for (i in seq_along(covariates)) {
    cov <- covariates[[i]]

    x_T <- vapply(sets, function(df) {
      df[[cov]][df[[treatment_col]] == 1L][[1L]]
    }, numeric(1L), USE.NAMES = FALSE)

    x_R_bar <- vapply(sets, function(df) {
      mean(df[[cov]][df[[treatment_col]] == 0L])
    }, numeric(1L), USE.NAMES = FALSE)

    mean_T <- mean(x_T)
    mean_R_weighted <- mean(x_R_bar)

    # ATT-weighted second central moments normalized by total analysis weight J
    # Treated weight w_{Tj} = 1 (sum = J)
    # Control weight w_{Rj,ell} = 1 / k_j (sum across set = 1, sum total = J)
    var_T <- sum((x_T - mean_T)^2) / J

    var_R_terms <- vapply(sets, function(df) {
      ctrls <- df[[cov]][df[[treatment_col]] == 0L]
      k <- length(ctrls)
      sum((ctrls - mean_R_weighted)^2) / k
    }, numeric(1L), USE.NAMES = FALSE)
    var_R <- sum(var_R_terms) / J

    s_pooled <- sqrt((var_T + var_R) / 2)
    mean_diff <- mean_T - mean_R_weighted

    if (s_pooled == 0) {
      if (mean_diff == 0) {
        smd_matched <- 0.0
        status <- "ZERO_VARIANCE_ZERO_DIFFERENCE"
      } else {
        smd_matched <- NULL
        status <- "ZERO_VARIANCE_NONZERO_DIFFERENCE"
      }
    } else {
      smd_matched <- mean_diff / s_pooled
      status <- "OK"
    }

    results[[i]] <- list(
      covariate = cov,
      target_mean = mean_T,
      reference_weighted_mean = mean_R_weighted,
      smd_matched = smd_matched,
      status = status
    )
  }

  results
}

sample_matched_set_bootstrap <- function(
  y_T,
  y_R_bar,
  num_draws = 4000L,
  seed = 42L
) {
  J <- length(y_T)
  B <- as.integer(num_draws)

  if (!is.null(seed)) {
    set.seed(as.integer(seed))
  }

  # Fast matrix-based atomic cluster resampling
  # Resample entire matched sets (cluster level) with replacement
  idx_matrix <- matrix(sample.int(J, size = J * B, replace = TRUE), nrow = J, ncol = B)

  target_draws <- colMeans(matrix(y_T[idx_matrix], nrow = J, ncol = B))
  reference_draws <- colMeans(matrix(y_R_bar[idx_matrix], nrow = J, ncol = B))
  rd_draws <- target_draws - reference_draws

  # Governed zero-denominator policy: do not artificially clamp with 1e-15
  zero_ref <- reference_draws <= 0
  undefined_replicates <- sum(zero_ref)
  defined_replicates <- B - undefined_replicates
  defined_fraction <- defined_replicates / B

  rr_draws <- rep(NA_real_, B)
  if (defined_replicates > 0L) {
    rr_draws[!zero_ref] <- target_draws[!zero_ref] / reference_draws[!zero_ref]
  }

  list(
    target_draws = target_draws,
    reference_draws = reference_draws,
    rd_draws = rd_draws,
    rr_draws = rr_draws,
    rr_diagnostics = list(
      defined_replicates = as.integer(defined_replicates),
      undefined_replicates = as.integer(undefined_replicates),
      defined_fraction = as.numeric(defined_fraction)
    )
  )
}

run_matched_set_inference <- function(
  data,
  subject_id_col = "subject_id",
  set_col = "set_id",
  treatment_col = "treatment",
  outcome_col = "outcome",
  covariates = NULL,
  caliper = NULL,
  discarded_target = 0L,
  discarded_reference = 0L,
  num_draws = 4000L,
  seed = 42L,
  primary_delta = NULL,
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  level = 0.95,
  persist_raw_draws = FALSE
) {
  # Parameter validation
  if (!is.null(caliper)) {
    if (!is.numeric(caliper) || length(caliper) != 1L || !is.finite(caliper) || caliper < 0) {
      stop("[INVALID_ARGUMENT] caliper は非負の単一有限数値である必要があります")
    }
  }
  if (!is.numeric(discarded_target) || length(discarded_target) != 1L || !is.finite(discarded_target) || discarded_target < 0 || discarded_target != floor(discarded_target)) {
    stop("[INVALID_ARGUMENT] discarded_target は非負の単一有限整数である必要があります")
  }
  if (!is.numeric(discarded_reference) || length(discarded_reference) != 1L || !is.finite(discarded_reference) || discarded_reference < 0 || discarded_reference != floor(discarded_reference)) {
    stop("[INVALID_ARGUMENT] discarded_reference は非負の単一有限整数である必要があります")
  }
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

  # 1. Input Validation
  validate_matched_set_data(
    data = data,
    subject_id_col = subject_id_col,
    set_col = set_col,
    treatment_col = treatment_col,
    outcome_col = outcome_col,
    covariates = covariates
  )

  # 2. Compute Observed Sample ATT Point Estimates
  att <- compute_matched_set_att_estimates(
    data = data,
    set_col = set_col,
    treatment_col = treatment_col,
    outcome_col = outcome_col
  )

  # 3. Compute Covariate Balance (SMD)
  cov_balance <- compute_covariate_balance(
    data = data,
    set_col = set_col,
    treatment_col = treatment_col,
    covariates = covariates
  )

  # 4. Atomic Cluster Bootstrap Resampling
  boot <- sample_matched_set_bootstrap(
    y_T = att$y_T,
    y_R_bar = att$y_R_bar,
    num_draws = num_draws,
    seed = seed
  )

  # 5. Raw descriptive counts vs ATT risk separation
  target_events_sum <- as.integer(sum(att$y_T))
  reference_events_sum <- as.integer(sum(data[[outcome_col]][data[[treatment_col]] == 0L]))
  target_total_sum <- as.integer(att$J)
  reference_total_sum <- as.integer(sum(att$k_j))

  observed_rr <- if (att$p_reference > 0) att$p_target / att$p_reference else NULL

  contrasts <- compute_comparative_contrasts(
    target_draws = boot$target_draws,
    reference_draws = boot$reference_draws,
    target_events = target_events_sum,
    target_total = target_total_sum,
    reference_events = reference_events_sum,
    reference_total = reference_total_sum,
    inferential_semantics = "bootstrap",
    observed_estimates = list(rd = att$rd, rr = observed_rr),
    primary_delta = primary_delta,
    delta_thresholds = delta_thresholds,
    level = level,
    domain = "matched_set"
  )

  # Override cohort-specific observed proportions with exact ATT marginal expectations
  contrasts$target_cohort$estimate_semantics <- "unweighted_risk"
  contrasts$target_cohort$events <- target_events_sum
  contrasts$target_cohort$total <- target_total_sum
  contrasts$target_cohort$incidence_proportion <- att$p_target
  contrasts$target_cohort$estimate$value <- att$p_target

  contrasts$reference_cohort$estimate_semantics <- "att_set_weighted_risk"
  contrasts$reference_cohort["events"] <- list(NULL)
  contrasts$reference_cohort["total"] <- list(NULL)
  contrasts$reference_cohort$incidence_proportion <- att$p_reference
  contrasts$reference_cohort$estimate$value <- att$p_reference

  evidence <- contrasts

  # Governed zero-denominator and partial-undefined bootstrap replicate RR policy
  evidence$relative_risk$rr_bootstrap_diagnostics <- boot$rr_diagnostics

  if (att$p_reference <= 0) {
    # Complete suppression when observed reference risk is 0
    evidence$relative_risk$estimate["value"] <- list(NULL)
    evidence$relative_risk["interval"] <- list(NULL)
    evidence$relative_risk["mean"] <- list(NULL)
    evidence$relative_risk$mean_is_finite <- FALSE
    evidence$relative_risk$diagnostic <- "ZERO_REFERENCE_RISK"
    evidence$precision_metrics["log_rr_interval_width"] <- list(NULL)
    evidence$precision_metrics["rr_interval_fold_range"] <- list(NULL)
  } else if (boot$rr_diagnostics$undefined_replicates > 0L) {
    # Conservative policy: suppress RR interval if any replicate has p_R* = 0
    evidence$relative_risk["interval"] <- list(NULL)
    evidence$relative_risk["mean"] <- list(NULL)
    evidence$relative_risk$mean_is_finite <- FALSE
    evidence$relative_risk$diagnostic <- "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"
    evidence$precision_metrics["log_rr_interval_width"] <- list(NULL)
    evidence$precision_metrics["rr_interval_fold_range"] <- list(NULL)
  } else {
    evidence$relative_risk["diagnostic"] <- list(NULL)
  }

  # 6. Matched Set Metadata Structure
  is_fixed <- all(att$k_j == att$k_j[1L])
  matching_ratio_type <- if (is_fixed) "fixed" else "variable"

  evidence$matched_set <- list(
    set_count = as.integer(att$J),
    estimand = "ATT",
    bootstrap_scope = list(
      type = "conditional_on_fixed_matched_sets",
      rematching_within_replicate = FALSE,
      propensity_model_refit = FALSE
    ),
    raw_target_counts = list(
      events = target_events_sum,
      total = target_total_sum
    ),
    raw_reference_counts = list(
      events = reference_events_sum,
      total = reference_total_sum
    ),
    matching_ratio = list(
      type = matching_ratio_type,
      min_controls = as.integer(min(att$k_j)),
      max_controls = as.integer(max(att$k_j)),
      mean_controls = as.numeric(mean(att$k_j))
    ),
    caliper = if (!is.null(caliper)) as.numeric(caliper) else NULL,
    replacement = FALSE,
    patient_counts = list(
      target_matched = as.integer(att$J),
      reference_matched = as.integer(sum(att$k_j)),
      target_discarded = as.integer(discarded_target),
      reference_discarded = as.integer(discarded_reference)
    ),
    covariate_balance = cov_balance
  )

  # 7. Uncertainty Draws Object (conforming to comparative-draws-v1)
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
      rd = att$rd,
      rr = observed_rr,
      p_target = att$p_target,
      p_reference = att$p_reference
    ),
    matched_set_metadata = list(
      set_count = as.integer(att$J),
      matching_ratio_type = matching_ratio_type,
      estimand = "ATT",
      bootstrap_scope = list(
        type = "conditional_on_fixed_matched_sets",
        rematching_within_replicate = FALSE,
        propensity_model_refit = FALSE
      ),
      rr_bootstrap_diagnostics = boot$rr_diagnostics
    )
  )

  list(evidence = evidence, draws = draws)
}
