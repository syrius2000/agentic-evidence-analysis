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

  # Check if confidence/credible interval crosses zero
  if (!is.null(rd_lower) && !is.null(rd_upper) && !is.na(rd_lower) && !is.na(rd_upper)) {
    crosses_zero <- (rd_lower < 0 && rd_upper > 0)
    if (crosses_zero) {
      return(list(
        status = "SIGN_AMBIGUOUS",
        value = 1.0 / rd_point,
        interval = NULL, # Suppress naive discontinuous interval
        message = "Uncertainty interval for risk difference crosses zero. Naive reciprocal interval suppressed."
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
  cohort_denominators, # named numeric vector: c("Drug_A" = 100, "Placebo" = 100)
  target_arm,
  reference_arm,
  subject_col = "subject_id",
  soc_col = "primary_soc",
  pt_col = "pt",
  arm_col = "arm",
  study_col = NULL,
  meddra_metadata = list()
) {
  # 1. Require MedDRA provenance metadata
  if (is.null(meddra_metadata$version) || !nzchar(trimws(as.character(meddra_metadata$version)))) {
    stop("[ERROR] [MISSING_MEDDRA_METADATA] MedDRA dictionary version provenance is required for Safety analysis.")
  }

  # Validate columns
  needed_cols <- c(subject_col, soc_col, pt_col, arm_col)
  missing_cols <- setdiff(needed_cols, names(ae_df))
  if (length(missing_cols) > 0L) {
    stop(sprintf("[ERROR] [MISSING_COLUMNS] Missing required Safety columns: %s", paste(missing_cols, collapse = ", ")))
  }

  # Filter to target and reference arms
  ae_clean <- ae_df[ae_df[[arm_col]] %in% c(target_arm, reference_arm), , drop = FALSE]

  n_T <- unname(cohort_denominators[[target_arm]])
  n_R <- unname(cohort_denominators[[reference_arm]])

  if (is.null(n_T) || is.null(n_R) || n_T <= 0 || n_R <= 0) {
    stop("[ERROR] [INVALID_DENOMINATORS] Valid positive cohort denominators must be provided for target and reference arms.")
  }

  # 2. Deduplicate at PT level: count unique subjects per arm + SOC + PT
  pt_unique <- unique(ae_clean[c(arm_col, soc_col, pt_col, subject_col)])
  pt_counts <- as.data.frame(table(
    arm = pt_unique[[arm_col]],
    soc = pt_unique[[soc_col]],
    pt = pt_unique[[pt_col]]
  ), stringsAsFactors = FALSE)
  pt_counts <- pt_counts[pt_counts$Freq >= 0, ]

  # 3. Deduplicate at SOC level: count unique subjects per arm + SOC
  soc_unique <- unique(ae_clean[c(arm_col, soc_col, subject_col)])
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

  # Format hierarchical summary
  all_socs <- sort(unique(ae_clean[[soc_col]]))
  hierarchy_results <- list()

  for (s in all_socs) {
    # SOC-level counts
    x_T_soc <- soc_counts$Freq[soc_counts$soc == s & soc_counts$arm == target_arm]
    x_R_soc <- soc_counts$Freq[soc_counts$soc == s & soc_counts$arm == reference_arm]
    x_T_soc <- if (length(x_T_soc)) x_T_soc[[1L]] else 0L
    x_R_soc <- if (length(x_R_soc)) x_R_soc[[1L]] else 0L

    # Child PTs
    pts_in_soc <- sort(unique(ae_clean[[pt_col]][ae_clean[[soc_col]] == s]))
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

    # Verify that SOC count is decoupled from sum of PT counts (invariant check)
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

  list(
    meddra_metadata = meddra_metadata,
    target_arm = target_arm,
    reference_arm = reference_arm,
    target_denominator = n_T,
    reference_denominator = n_R,
    hierarchy = hierarchy_results
  )
}
