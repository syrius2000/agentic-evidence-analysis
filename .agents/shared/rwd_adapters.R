# .agents/shared/rwd_adapters.R — Generic Hierarchical, RWD, and Prescription Adapters
# Implements Section 6 of OpenSpec comparative-evidence-reporting-v3

suppressPackageStartupMessages({
  library(jsonlite)
})

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "rwd_adapters.R", files)
  dir <- if (length(own)) dirname(tail(own, 1)[[1]]) else file.path(getwd(), ".agents", "shared")
  engine_path <- file.path(dir, "independent_beta_binomial.R")
  if (file.exists(engine_path)) source(engine_path, local = FALSE)
})

# 1. Generic Hierarchical Aggregator: parent_theme -> item_theme
aggregate_hierarchical_data <- function(
  df,
  cohort_denominators,
  target_arm,
  reference_arm,
  subject_col = "subject_id",
  parent_col = "parent_theme",
  item_col = "item_theme",
  arm_col = "arm"
) {
  needed_cols <- c(subject_col, parent_col, item_col, arm_col)
  missing_cols <- setdiff(needed_cols, names(df))
  if (length(missing_cols) > 0L) {
    stop(sprintf("[ERROR] [MISSING_COLUMNS] Missing required columns: %s", paste(missing_cols, collapse = ", ")))
  }

  df_clean <- df[df[[arm_col]] %in% c(target_arm, reference_arm), , drop = FALSE]

  n_T <- unname(cohort_denominators[[target_arm]])
  n_R <- unname(cohort_denominators[[reference_arm]])

  if (is.null(n_T) || is.null(n_R) || n_T <= 0 || n_R <= 0) {
    stop("[ERROR] [INVALID_DENOMINATORS] Valid positive denominators required.")
  }

  # Deduplicate items
  item_unique <- unique(df_clean[c(arm_col, parent_col, item_col, subject_col)])
  item_counts <- as.data.frame(table(
    arm = item_unique[[arm_col]],
    parent = item_unique[[parent_col]],
    item = item_unique[[item_col]]
  ), stringsAsFactors = FALSE)

  # Deduplicate parents
  parent_unique <- unique(df_clean[c(arm_col, parent_col, subject_col)])
  parent_counts <- as.data.frame(table(
    arm = parent_unique[[arm_col]],
    parent = parent_unique[[parent_col]]
  ), stringsAsFactors = FALSE)

  all_parents <- sort(unique(df_clean[[parent_col]]))
  res <- list()

  for (p in all_parents) {
    x_T_p <- parent_counts$Freq[parent_counts$parent == p & parent_counts$arm == target_arm]
    x_R_p <- parent_counts$Freq[parent_counts$parent == p & parent_counts$arm == reference_arm]
    x_T_p <- if (length(x_T_p)) x_T_p[[1L]] else 0L
    x_R_p <- if (length(x_R_p)) x_R_p[[1L]] else 0L

    items_in_p <- sort(unique(df_clean[[item_col]][df_clean[[parent_col]] == p]))
    item_list <- list()

    for (it in items_in_p) {
      x_T_it <- item_counts$Freq[item_counts$parent == p & item_counts$item == it & item_counts$arm == target_arm]
      x_R_it <- item_counts$Freq[item_counts$parent == p & item_counts$item == it & item_counts$arm == reference_arm]
      x_T_it <- if (length(x_T_it)) x_T_it[[1L]] else 0L
      x_R_it <- if (length(x_R_it)) x_R_it[[1L]] else 0L

      item_list[[it]] <- list(
        item = it,
        target_events = x_T_it,
        target_total = n_T,
        reference_events = x_R_it,
        reference_total = n_R
      )
    }

    res[[p]] <- list(
      parent = p,
      target_events = x_T_p,
      target_total = n_T,
      reference_events = x_R_p,
      reference_total = n_R,
      items = item_list
    )
  }

  list(
    target_arm = target_arm,
    reference_arm = reference_arm,
    hierarchy = res
  )
}

# 2. RWD Diagnosis / Procedure Adapter
adapt_rwd_diagnosis_procedure <- function(
  rwd_df,
  cohort_denominators,
  target_arm,
  reference_arm,
  subject_col = "patient_id",
  chapter_col = "icd_chapter",
  code_col = "diagnosis_code",
  arm_col = "cohort"
) {
  agg <- aggregate_hierarchical_data(
    df = rwd_df,
    cohort_denominators = cohort_denominators,
    target_arm = target_arm,
    reference_arm = reference_arm,
    subject_col = subject_col,
    parent_col = chapter_col,
    item_col = code_col,
    arm_col = arm_col
  )

  # Attach domain metadata decorator
  agg$domain <- "rwd"
  agg$domain_labels <- list(
    parent_name = "ICD Chapter / Procedure Domain",
    item_name = "Diagnosis Code (ICD-10) / Procedure Code",
    unit_label = "additional_patients_per_100_cohort"
  )
  agg
}

# 3. Prescription / Formulary Adapter
adapt_prescription_formulary <- function(
  rx_df,
  cohort_denominators,
  target_arm,
  reference_arm,
  subject_col = "patient_id",
  class_col = "therapeutic_class",
  ingredient_col = "active_ingredient",
  arm_col = "cohort"
) {
  agg <- aggregate_hierarchical_data(
    df = rx_df,
    cohort_denominators = cohort_denominators,
    target_arm = target_arm,
    reference_arm = reference_arm,
    subject_col = subject_col,
    parent_col = class_col,
    item_col = ingredient_col,
    arm_col = arm_col
  )

  # Attach domain metadata decorator
  agg$domain <- "prescription"
  agg$domain_labels <- list(
    parent_name = "Therapeutic Class / ATC Level",
    item_name = "Active Ingredient / Generic Name",
    unit_label = "additional_patients_per_100_prescribed"
  )
  agg
}

# 4. Domain Presentation Decorator (Preserves Canonical Statistical Output Intact)
decorate_comparative_evidence <- function(evidence_obj, domain = c("safety", "rwd", "prescription", "general")) {
  domain <- match.arg(domain)

  # Deep clone or wrap
  decorated <- evidence_obj
  decorated$presentation <- list(
    domain = domain
  )

  if (domain == "safety") {
    decorated$presentation$primary_unit_label <- "additional_subjects_per_100_treated"
    decorated$presentation$parent_label <- "Primary System Organ Class (SOC)"
    decorated$presentation$item_label <- "Preferred Term (PT)"
  } else if (domain == "rwd") {
    decorated$presentation$primary_unit_label <- "additional_patients_per_100_cohort"
    decorated$presentation$parent_label <- "Diagnosis Chapter / Category"
    decorated$presentation$item_label <- "Specific Diagnosis / Procedure"
  } else if (domain == "prescription") {
    decorated$presentation$primary_unit_label <- "additional_patients_per_100_prescribed"
    decorated$presentation$parent_label <- "Therapeutic Class"
    decorated$presentation$item_label <- "Active Ingredient"
  } else {
    decorated$presentation$primary_unit_label <- "excess_per_100"
    decorated$presentation$parent_label <- "Parent Theme"
    decorated$presentation$item_label <- "Item Theme"
  }

  decorated
}
