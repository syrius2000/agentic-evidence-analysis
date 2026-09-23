# .agents/shared/pass0_routing.R — Pass 0 Inspection, Validation, and Deterministic Routing Gateway
# Conforming to OpenSpec comparative-evidence-reporting-v3 (pass0-analysis-routing capability)

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

# Inspect tabular input data for integrity, non-integer counts, design columns, and subject duplicates
inspect_tabular_input <- function(df, config = list()) {
  issues <- list()
  diagnostics <- list()
  detected_columns <- list()

  col_names_lower <- tolower(names(df))

  # 1. Detect optional design columns
  weight_cols <- names(df)[col_names_lower %in% c("weight", "weights", "iptw", "ps_weight", "sampling_weight", "survey_weight")]
  survey_cols <- names(df)[col_names_lower %in% c("survey_weight", "sampling_weight", "strata_weight", "cluster_weight", "svy_weight")]
  matched_cols <- names(df)[col_names_lower %in% c("matched_set", "matched_set_id", "pair_id", "match_id", "stratum_id")]
  cluster_cols <- names(df)[col_names_lower %in% c("cluster", "cluster_id", "site_id", "center_id")]
  person_time_cols <- names(df)[col_names_lower %in% c("person_time", "py", "exposure_time", "follow_up_days", "follow_up_years")]
  soc_cols <- names(df)[col_names_lower %in% c("soc", "primary_soc", "soc_name", "soc_code")]
  pt_cols <- names(df)[col_names_lower %in% c("pt", "preferred_term", "pt_name", "pt_code")]
  study_cols <- names(df)[col_names_lower %in% c("study", "study_id", "protocol", "trial_id")]
  subject_cols <- names(df)[col_names_lower %in% c("subject_id", "usubjid", "patient_id", "subjid", "id")]

  detected_columns <- list(
    weight_columns = weight_cols,
    survey_columns = survey_cols,
    matched_set_columns = matched_cols,
    cluster_columns = cluster_cols,
    person_time_columns = person_time_cols,
    soc_columns = soc_cols,
    pt_columns = pt_cols,
    study_columns = study_cols,
    subject_columns = subject_cols
  )

  # 2. Survey weight fail-fast check
  if (length(survey_cols) > 0L || isTRUE(config$is_complex_survey)) {
    stop("[ERROR] [UNSUPPORTED_SURVEY_DESIGN] Complex survey sampling weights detected (columns: ",
         paste(survey_cols, collapse = ", "),
         "). Complex survey designs are currently not supported in comparative evidence engines.")
  }

  # 3. Check count columns for non-integer or negative values
  count_cols <- names(df)[vapply(df, is.numeric, logical(1L))]
  # Exclude id and weight columns from integer count check
  non_count_candidates <- c(weight_cols, survey_cols, matched_cols, cluster_cols, subject_cols, person_time_cols)
  count_cols <- setdiff(count_cols, non_count_candidates)

  non_integer_detected <- FALSE
  non_integer_details <- list()

  for (col in count_cols) {
    vals <- df[[col]]
    vals_clean <- vals[!is.na(vals)]
    if (length(vals_clean) > 0L) {
      if (any(vals_clean < 0)) {
        stop(sprintf("[ERROR] [INVALID_NEGATIVE_COUNT] Column '%s' contains negative values.", col))
      }
      is_float <- any(abs(vals_clean - round(vals_clean)) > 1e-8)
      if (is_float) {
        non_integer_detected <- TRUE
        non_integer_details[[col]] <- list(
          has_floats = TRUE,
          sample_values = head(vals_clean[abs(vals_clean - round(vals_clean)) > 1e-8], 3)
        )
      }
    }
  }

  diagnostics$non_integer_counts <- list(
    detected = non_integer_detected,
    details = non_integer_details
  )

  # 4. Duplicate subject diagnostics within PT and SOC
  duplicate_diagnostics <- list(
    assessed = FALSE,
    pt_duplicates = 0L,
    soc_duplicates = 0L,
    proposed_counting_rule = NULL
  )

  if (length(subject_cols) > 0L && (length(pt_cols) > 0L || length(soc_cols) > 0L)) {
    sub_col <- subject_cols[[1L]]
    duplicate_diagnostics$assessed <- TRUE

    if (length(pt_cols) > 0L) {
      pt_col <- pt_cols[[1L]]
      # duplicates within same subject + PT
      pt_dups <- sum(duplicated(df[c(sub_col, pt_col)]))
      duplicate_diagnostics$pt_duplicates <- pt_dups
    }

    if (length(soc_cols) > 0L) {
      soc_col <- soc_cols[[1L]]
      # duplicates within same subject + SOC
      soc_dups <- sum(duplicated(df[c(sub_col, soc_col)]))
      duplicate_diagnostics$soc_duplicates <- soc_dups
    }

    if (duplicate_diagnostics$pt_duplicates > 0L || duplicate_diagnostics$soc_duplicates > 0L) {
      duplicate_diagnostics$proposed_counting_rule <- paste(
        "Standard deduplication: count unique subjects per PT (one occurrence per patient),",
        "and count unique subjects per SOC (one occurrence per patient across any child PTs).",
        "Do not sum PT counts to compute SOC counts."
      )
    }
  }

  diagnostics$duplicate_subjects <- duplicate_diagnostics
  diagnostics$detected_columns <- detected_columns

  list(
    valid = TRUE,
    diagnostics = diagnostics
  )
}

# Validate configuration against Pass 0 contract
validate_pass0_config <- function(config) {
  required_fields <- c("domain", "estimand", "analysis_unit", "target", "reference", "design", "practical_difference", "reporting_purpose")
  missing <- setdiff(required_fields, names(config))
  if (length(missing) > 0L) {
    stop(sprintf("[ERROR] [INVALID_CONFIG] Missing required Pass 0 configuration fields: %s", paste(missing, collapse = ", ")))
  }

  # Validate practical difference mode and delta
  pd <- config$practical_difference
  if (!is.list(pd) || is.null(pd$mode)) {
    stop("[ERROR] [INVALID_CONFIG] practical_difference must be an object with 'mode'.")
  }
  if (pd$mode == "none") {
    # Valid non-blocking state, primary_delta may be null
    if (!is.null(pd$primary_delta) && !is.na(pd$primary_delta)) {
      warning("[WARNING] practical_difference.mode is 'none' but primary_delta is set. Ignoring primary_delta.")
    }
  } else if (pd$mode == "fixed_delta") {
    if (is.null(pd$primary_delta) || is.na(pd$primary_delta)) {
      stop("[ERROR] [INVALID_CONFIG] practical_difference.mode is 'fixed_delta' but primary_delta is null or missing.")
    }
  }

  # Validate causal estimand confirmation
  if (config$estimand %in% c("ATE", "ATT") && isTRUE(config$requires_estimand_confirmation)) {
    if (is.null(config$estimand_confirmed) || !isTRUE(config$estimand_confirmed)) {
      stop("[ERROR] [UNCONFIRMED_CAUSAL_ESTIMAND] Causal estimand (", config$estimand,
           ") requires explicit confirmation regarding target population weighting.")
    }
  }

  TRUE
}

# Determine execution routing and generate routing_decision.json
generate_routing_decision <- function(input_path, config, out_file = NULL) {
  if (!file.exists(input_path)) {
    stop("[ERROR] Input file does not exist: ", input_path)
  }

  input_abs <- normalizePath(input_path, winslash = "/", mustWork = TRUE)
  input_sha256 <- digest::digest(file = input_abs, algo = "sha256")
  config_sha256 <- digest::digest(config, algo = "sha256")

  df <- read.csv(input_abs, stringsAsFactors = FALSE, check.names = FALSE)
  inspection <- inspect_tabular_input(df, config)
  validate_pass0_config(config)

  design <- config$design
  has_floats <- isTRUE(inspection$diagnostics$non_integer_counts$detected)
  has_weights <- length(inspection$diagnostics$detected_columns$weight_columns) > 0L

  # Fail-fast guards for independent Beta-Binomial engine
  if (design == "independent_binary") {
    if (has_weights || has_floats) {
      stop("[ERROR] [UNSUPPORTED_WEIGHTED_INPUT] Weighted pseudo-counts or non-integer counts cannot enter ",
           "the unweighted independent Beta-Binomial engine. Observational weighted cohorts must be routed to 'comparative-design-analysis'.")
    }
    target_engine_slug <- "vcd-categorical-reporting"
    engine_module <- ".agents/shared/independent_beta_binomial.R"
    inferential_semantics <- "posterior"
  } else if (design %in% c("matched_pair", "matched_set", "iptw", "person_time")) {
    target_engine_slug <- "comparative-design-analysis"
    engine_module <- sprintf(".agents/shared/%s_engine.R", design)
    inferential_semantics <- "bootstrap"
  } else {
    stop("[ERROR] [UNKNOWN_DESIGN] Unknown study design: ", design)
  }

  routing_decision <- list(
    schema_version = "pass0-routing-v1",
    input_file = input_abs,
    input_sha256 = input_sha256,
    config_sha256 = config_sha256,
    target_engine_slug = target_engine_slug,
    engine_module = engine_module,
    inferential_semantics = inferential_semantics,
    design = design,
    estimand = config$estimand,
    practical_difference_mode = config$practical_difference$mode,
    primary_delta = config$practical_difference$primary_delta,
    diagnostics = inspection$diagnostics,
    decision_review_required = isTRUE(config$decision_review_flag),
    routing_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )

  if (!is.null(out_file) && nzchar(out_file)) {
    dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(jsonlite::toJSON(routing_decision, auto_unbox = TRUE, pretty = TRUE), out_file)
  }

  routing_decision
}
