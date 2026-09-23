# .agents/shared/safety_adapter.R — Clinical Safety Adverse Event Data Adapter
# Implements Section 5 of OpenSpec comparative-evidence-reporting-v3

suppressPackageStartupMessages({
  library(jsonlite)
})

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "safety_adapter.R", files)
  dir <- if (length(own)) dirname(tail(own, 1)[[1]]) else file.path(getwd(), ".agents", "shared")
  engine_path <- file.path(dir, "independent_beta_binomial.R")
  if (file.exists(engine_path)) source(engine_path, local = FALSE)
})

# Calculate reciprocal RD (NNH / NNT) status and interpretation
compute_reciprocal_rd <- function(rd_point, rd_lower, rd_upper) {
  if (is.null(rd_point) || is.na(rd_point)) {
    return(list(status = "NOT_INTERPRETABLE", value = NULL, interval = NULL))
  }

  if (abs(rd_point) < 1e-4) {
    return(list(
      status = "RD_NEAR_ZERO",
      value = NULL,
      interval = NULL,
      message = "Risk difference is near zero; reciprocal NNH/NNT is not mathematically stable."
    ))
  }

  # M5 fix: Check if confidence/credible interval touches or crosses zero (<= 0 and >= 0)
  if (!is.null(rd_lower) && !is.null(rd_upper) && !is.na(rd_lower) && !is.na(rd_upper)) {
    crosses_or_touches_zero <- (rd_lower <= 0 && rd_upper >= 0)
    if (crosses_or_touches_zero) {
      return(list(
        status = "SIGN_AMBIGUOUS",
        value = 1.0 / rd_point,
        interval = NULL, # Suppress naive discontinuous interval
        message = "Uncertainty interval for risk difference touches or crosses zero. Naive reciprocal interval suppressed."
      ))
    }
  }

  # Stable direction
  recip_val <- 1.0 / rd_point
  recip_lower <- if (!is.null(rd_upper) && !is.na(rd_upper) && rd_upper != 0) 1.0 / rd_upper else NULL
  recip_upper <- if (!is.null(rd_lower) && !is.null(rd_lower) && rd_lower != 0) 1.0 / rd_lower else NULL

  # Sort bounds
  int_bounds <- if (!is.null(recip_lower) && !is.null(recip_upper)) sort(c(recip_lower, recip_upper)) else NULL

  list(
    status = "STABLE_DIRECTION",
    value = recip_val,
    interval = int_bounds,
    message = "Stable direction reciprocal RD calculated."
  )
}

# Aggregate safety adverse event records by Primary SOC and PT with proper deduplication
aggregate_safety_data <- function(
  ae_df,
  cohort_denominators, # named numeric vector or list per study: c("Drug_A" = 100, "Placebo" = 100)
  target_arm,
  reference_arm,
  subject_col = "subject_id",
  soc_col = "primary_soc",
  pt_col = "pt",
  arm_col = "arm",
  study_col = NULL,
  meddra_metadata = list()
) {
  # 1. H4 fix: Require MedDRA version and release metadata
  if (is.null(meddra_metadata$version) || !nzchar(trimws(as.character(meddra_metadata$version)))) {
    stop("[ERROR] [MISSING_MEDDRA_METADATA] MedDRA dictionary version provenance is required for Safety analysis.")
  }
  rel_meta <- meddra_metadata$release_date %||% meddra_metadata$release %||% meddra_metadata$build %||% NULL
  if (is.null(rel_meta) || !nzchar(trimws(as.character(rel_meta)))) {
    stop("[ERROR] [MISSING_MEDDRA_METADATA] MedDRA dictionary release metadata (release_date/release/build) is required.")
  }

  # Validate columns
  needed_cols <- c(subject_col, soc_col, pt_col, arm_col)
  if (!is.null(study_col)) needed_cols <- c(needed_cols, study_col)

  missing_cols <- setdiff(needed_cols, names(ae_df))
  if (length(missing_cols) > 0L) {
    stop(sprintf("[ERROR] [MISSING_COLUMNS] Missing required Safety columns: %s", paste(missing_cols, collapse = ", ")))
  }

  # Filter to target and reference arms
  ae_clean <- ae_df[ae_df[[arm_col]] %in% c(target_arm, reference_arm), , drop = FALSE]

  # Helper for single dataset aggregation
  aggregate_single_cohort <- function(sub_ae, n_T, n_R) {
    # Deduplicate at PT level
    pt_unique <- unique(sub_ae[c(arm_col, soc_col, pt_col, subject_col)])
    pt_counts <- as.data.frame(table(
      arm = pt_unique[[arm_col]],
      soc = pt_unique[[soc_col]],
      pt = pt_unique[[pt_col]]
    ), stringsAsFactors = FALSE)
    pt_counts <- pt_counts[pt_counts$Freq >= 0, ]

    # Deduplicate at SOC level
    soc_unique <- unique(sub_ae[c(arm_col, soc_col, subject_col)])
    soc_counts <- as.data.frame(table(
      arm = soc_unique[[arm_col]],
      soc = soc_unique[[soc_col]]
    ), stringsAsFactors = FALSE)

    # Check denominator bounds
    for (i in seq_len(nrow(soc_counts))) {
      cur_arm <- soc_counts$arm[[i]]
      cur_freq <- soc_counts$Freq[[i]]
      den <- if (cur_arm == target_arm) n_T else n_R
      if (cur_freq > den) {
        stop(sprintf("[ERROR] [DENOMINATOR_EXCEEDED] Unique subject count for SOC '%s' in arm '%s' (%d) exceeds denominator (%d).",
                     soc_counts$soc[[i]], cur_arm, cur_freq, den))
      }
    }

    all_socs <- sort(unique(sub_ae[[soc_col]]))
    hierarchy_results <- list()

    for (s in all_socs) {
      x_T_soc <- soc_counts$Freq[soc_counts$soc == s & soc_counts$arm == target_arm]
      x_R_soc <- soc_counts$Freq[soc_counts$soc == s & soc_counts$arm == reference_arm]
      x_T_soc <- if (length(x_T_soc)) x_T_soc[[1L]] else 0L
      x_R_soc <- if (length(x_R_soc)) x_R_soc[[1L]] else 0L

      pts_in_soc <- sort(unique(sub_ae[[pt_col]][sub_ae[[soc_col]] == s]))
      pt_summaries <- list()
      sum_pt_T <- 0L
      sum_pt_R <- 0L

      for (p in pts_in_soc) {
        x_T_pt <- pt_counts$Freq[pt_counts$soc == s & pt_counts$pt == p & pt_counts$arm == target_arm]
        x_R_pt <- pt_counts$Freq[pt_counts$soc == s & pt_counts$pt == p & pt_counts$arm == reference_arm]
        x_T_pt <- if (length(x_T_pt)) x_T_pt[[1L]] else 0L
        x_R_pt <- if (length(x_R_pt)) x_R_pt[[1L]] else 0L

        sum_pt_T <- sum_pt_T + x_T_pt
        sum_pt_R <- sum_pt_R + x_R_pt

        pt_summaries[[p]] <- list(
          pt = p,
          target_events = x_T_pt,
          target_total = n_T,
          reference_events = x_R_pt,
          reference_total = n_R
        )
      }

      hierarchy_results[[s]] <- list(
        soc = s,
        target_events = x_T_soc,
        target_total = n_T,
        reference_events = x_R_soc,
        reference_total = n_R,
        sum_child_pt_target_events = sum_pt_T,
        sum_child_pt_reference_events = sum_pt_R,
        pts = pt_summaries
      )
    }

    hierarchy_results
  }

  # H3 fix: Support study-specific stratification vs descriptive_pooled
  study_stratified <- list()
  if (!is.null(study_col) && length(unique(ae_clean[[study_col]])) > 1L) {
    all_studies <- sort(unique(ae_clean[[study_col]]))
    for (st in all_studies) {
      sub_study <- ae_clean[ae_clean[[study_col]] == st, , drop = FALSE]
      st_denoms <- if (is.list(cohort_denominators) && !is.null(cohort_denominators[[st]])) {
        cohort_denominators[[st]]
      } else cohort_denominators
      n_T_st <- unname(st_denoms[[target_arm]])
      n_R_st <- unname(st_denoms[[reference_arm]])

      study_stratified[[st]] <- list(
        study_id = st,
        target_denominator = n_T_st,
        reference_denominator = n_R_st,
        hierarchy = aggregate_single_cohort(sub_study, n_T_st, n_R_st)
      )
    }
    aggregation_mode <- "descriptive_pooled"
  } else {
    aggregation_mode <- "single_study"
  }

  n_T_total <- unname(if (is.list(cohort_denominators) && !is.null(cohort_denominators$total)) cohort_denominators$total[[target_arm]] else cohort_denominators[[target_arm]])
  n_R_total <- unname(if (is.list(cohort_denominators) && !is.null(cohort_denominators$total)) cohort_denominators$total[[reference_arm]] else cohort_denominators[[reference_arm]])

  pooled_hierarchy <- aggregate_single_cohort(ae_clean, n_T_total, n_R_total)

  list(
    meddra_metadata = meddra_metadata,
    aggregation_mode = aggregation_mode,
    target_arm = target_arm,
    reference_arm = reference_arm,
    target_denominator = n_T_total,
    reference_denominator = n_R_total,
    hierarchy = pooled_hierarchy,
    study_stratified = if (length(study_stratified) > 0L) study_stratified else NULL
  )
}
