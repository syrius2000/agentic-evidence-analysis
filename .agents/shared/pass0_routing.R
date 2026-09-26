# .agents/shared/pass0_routing.R — Pass 0 Inspection, Validation, and Deterministic Routing Gateway
# Conforming to OpenSpec comparative-evidence-reporting-v3 (pass0-analysis-routing capability)

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

# Explicit canonical routing table mapping designs to engines and inferential semantics
CANONICAL_ROUTING_TABLE <- list(
  independent_binary = list(
    target_engine_slug = "vcd-categorical-reporting",
    engine_module = ".agents/shared/independent_beta_binomial.R",
    inferential_semantics = "posterior"
  ),
  matched_pair = list(
    target_engine_slug = "comparative-design-analysis",
    engine_module = ".agents/shared/matched_pair_dirichlet.R",
    inferential_semantics = "posterior"
  ),
  matched_set = list(
    target_engine_slug = "comparative-design-analysis",
    engine_module = ".agents/shared/matched_set_inference.R",
    inferential_semantics = "bootstrap"
  ),
  iptw = list(
    target_engine_slug = "comparative-design-analysis",
    engine_module = ".agents/shared/iptw_inference.R",
    inferential_semantics = "bootstrap"
  ),
  person_time = list(
    target_engine_slug = "comparative-design-analysis",
    engine_module = ".agents/shared/person_time_rate.R",
    inferential_semantics = "posterior"
  )
)

REPEATED_ROWS_ALLOWED_KEYS <- c(
  "subject_id_col", "group_col", "outcome_col", "event_rule", "confirmed",
  "cluster_cols", "matched_cols", "no_other_subject_dependence_confirmed"
)

# Heuristic aliases for dependency columns. Declared cluster_cols/matched_cols are merged with these.
# Native R configs may pass a length-1 character vector; canonical JSON must serialize as a string array.
HEURISTIC_MATCHED_COL_ALIASES <- c(
  "matched_set", "matched_set_id", "set_id", "pair_id", "match_id", "stratum_id",
  "matched_group_id", "matched_pair_id", "matching_id", "match_group_id"
)

HEURISTIC_CLUSTER_COL_ALIASES <- c(
  "cluster", "cluster_id", "site_id", "center_id", "centre_id",
  "facility_id", "hospital_id", "clinic_id", "institution_id", "ward_id"
)

normalize_declared_cols <- function(value, field_name) {
  if (is.null(value)) {
    return(character())
  }
  if (is.list(value) && !is.data.frame(value)) {
    if (length(value) == 0L) {
      return(character())
    }
    value <- unlist(value, use.names = FALSE)
  }
  if (is.null(value) || length(value) == 0L) {
    return(character())
  }
  if (!is.character(value) ||
    anyNA(value) || any(!nzchar(trimws(value))) || anyDuplicated(value)) {
    stop(sprintf("[INVALID_REPEATED_ROWS_POLICY] %s は重複のない非空文字列配列で指定してください", field_name))
  }
  as.character(value)
}

validate_repeated_rows_config <- function(config) {
  policy <- config$repeated_rows
  if (is.null(policy)) {
    return(invisible(FALSE))
  }
  if (!is.list(policy) || is.data.frame(policy) ||
    !identical(config$design, "independent_binary") || !identical(config$analysis_unit, "subject")) {
    stop("[INVALID_REPEATED_ROWS_POLICY] 被験者単位の独立二群二値設計だけが反復行集約を利用できます")
  }
  unexpected <- setdiff(names(policy), REPEATED_ROWS_ALLOWED_KEYS)
  if (length(unexpected) > 0L) {
    stop(
      "[INVALID_REPEATED_ROWS_POLICY] repeated_rows に未定義キーがあります: ",
      paste(unexpected, collapse = ", ")
    )
  }
  fields <- c("subject_id_col", "group_col", "outcome_col")
  if (!all(fields %in% names(policy)) ||
    !all(vapply(policy[fields], function(x) {
      is.character(x) && length(x) == 1L &&
        !is.na(x) && nzchar(trimws(x))
    }, logical(1))) ||
    anyDuplicated(unlist(policy[fields])) || !identical(policy$event_rule, "any_event")) {
    stop("[INVALID_REPEATED_ROWS_POLICY] 被験者ID・群・二値結果列とany_event規則を明示してください")
  }
  if (!isTRUE(policy$confirmed)) {
    stop("[UNCONFIRMED_SUBJECT_COLLAPSE] 被験者単位のany_event集約には明示確認が必要です")
  }
  if (!isTRUE(policy$no_other_subject_dependence_confirmed)) {
    stop("[UNCONFIRMED_SUBJECT_DEPENDENCE] 被験者間の他依存が無いことの明示確認が必要です")
  }
  normalize_declared_cols(policy$cluster_cols, "cluster_cols")
  normalize_declared_cols(policy$matched_cols, "matched_cols")
  if (!is.character(config$target) || length(config$target) != 1L || is.na(config$target) ||
    !is.character(config$reference) || length(config$reference) != 1L || is.na(config$reference) ||
    !nzchar(config$target) || !nzchar(config$reference) || identical(config$target, config$reference)) {
    stop("[INVALID_REPEATED_ROWS_POLICY] targetとreferenceには異なる群名が必要です")
  }
  invisible(TRUE)
}

resolve_dependency_structure_cols <- function(df, config) {
  col_names_lower <- tolower(names(df))
  heuristic_matched <- names(df)[col_names_lower %in% HEURISTIC_MATCHED_COL_ALIASES]
  heuristic_cluster <- names(df)[col_names_lower %in% HEURISTIC_CLUSTER_COL_ALIASES]
  declared_matched <- character()
  declared_cluster <- character()
  if (!is.null(config$repeated_rows)) {
    declared_matched <- normalize_declared_cols(config$repeated_rows$matched_cols, "matched_cols")
    declared_cluster <- normalize_declared_cols(config$repeated_rows$cluster_cols, "cluster_cols")
    missing_declared <- setdiff(c(declared_matched, declared_cluster), names(df))
    if (length(missing_declared) > 0L) {
      stop(
        "[MISSING_DEPENDENCY_STRUCTURE_COLUMNS] 明示された依存構造列が入力にありません: ",
        paste(missing_declared, collapse = ", ")
      )
    }
  }
  list(
    matched_cols = unique(c(heuristic_matched, declared_matched)),
    cluster_cols = unique(c(heuristic_cluster, declared_cluster)),
    heuristic_matched_cols = heuristic_matched,
    heuristic_cluster_cols = heuristic_cluster,
    declared_matched_cols = declared_matched,
    declared_cluster_cols = declared_cluster
  )
}

assess_repeated_subject_rows <- function(df, config, cluster_cols = character(), matched_cols = character()) {
  validate_repeated_rows_config(config)
  policy <- config$repeated_rows
  required_cols <- unlist(policy[c("subject_id_col", "group_col", "outcome_col")], use.names = FALSE)
  if (!is.data.frame(df) || nrow(df) == 0L || !all(required_cols %in% names(df))) {
    stop("[MISSING_REPEATED_ROWS_COLUMNS] 反復行集約の入力列またはデータ行がありません")
  }
  if (length(matched_cols) > 0L) {
    stop("[MATCHED_STRUCTURE_NOT_COLLAPSIBLE] マッチング構造を独立二群として集約できません")
  }
  ids <- as.character(df[[policy$subject_id_col]])
  groups <- as.character(df[[policy$group_col]])
  outcomes <- df[[policy$outcome_col]]
  if (anyNA(ids) || any(!nzchar(trimws(ids))) || anyNA(groups) || any(!groups %in% c(config$target, config$reference))) {
    stop("[INVALID_REPEATED_ROWS] 被験者IDまたは群に欠測・未定義値があります")
  }
  if (!is.numeric(outcomes) || anyNA(outcomes) || any(!is.finite(outcomes)) ||
    any(!outcomes %in% c(0L, 1L))) {
    stop("[INVALID_BINARY_OUTCOME] 反復行の結果は欠測のない0/1値で指定してください")
  }
  subject_ids <- unique(ids)
  subject_index <- match(ids, subject_ids)
  subject_groups <- groups[match(subject_ids, ids)]
  if (any(groups != subject_groups[subject_index])) {
    stop("[INCONSISTENT_SUBJECT_GROUP] 同一被験者の群が観測行間で異なります")
  }
  for (column in cluster_cols) {
    cluster_ids <- as.character(df[[column]])
    if (anyNA(cluster_ids) || any(!nzchar(trimws(cluster_ids))) ||
      any(vapply(split(ids, cluster_ids), function(x) length(unique(x)) > 1L, logical(1))) ||
      any(vapply(split(cluster_ids, ids), function(x) length(unique(x)) > 1L, logical(1)))) {
      stop("[HIERARCHICAL_CLUSTER_NOT_SUPPORTED] 被験者より上位または変動するクラスタは別設計が必要です")
    }
  }
  subject_events <- as.integer(vapply(
    split(outcomes, factor(subject_index, levels = seq_along(subject_ids))),
    function(x) any(x == 1L), logical(1)
  ))
  target_members <- subject_groups == config$target
  reference_members <- subject_groups == config$reference
  if (!any(target_members) || !any(reference_members)) {
    stop("[EMPTY_SUBJECT_ARM] 対象群・参照群の双方に被験者が必要です")
  }
  counts <- list(
    target = list(events = as.integer(sum(subject_events[target_members])), total = as.integer(sum(target_members))),
    reference = list(events = as.integer(sum(subject_events[reference_members])), total = as.integer(sum(reference_members)))
  )
  list(
    diagnostics = list(
      assessed = TRUE, collapsible = TRUE, event_rule = "any_event",
      subject_id_col = policy$subject_id_col, group_col = policy$group_col,
      outcome_col = policy$outcome_col, confirmed = TRUE,
      original_rows = nrow(df), subject_count = length(subject_ids),
      repeated_rows = nrow(df) - length(subject_ids)
    ),
    counts = counts
  )
}

# Inspect tabular input data for integrity, non-integer counts, design columns, and subject duplicates
inspect_tabular_input <- function(df, config = list()) {
  diagnostics <- list()
  detected_columns <- list()

  col_names_lower <- tolower(names(df))

  # 1. Detect optional design columns
  weight_cols <- names(df)[col_names_lower %in% c("weight", "weights", "iptw", "ps_weight", "sampling_weight", "survey_weight")]
  survey_cols <- names(df)[col_names_lower %in% c("survey_weight", "sampling_weight", "strata_weight", "cluster_weight", "svy_weight")]
  dependency_cols <- resolve_dependency_structure_cols(df, config)
  matched_cols <- dependency_cols$matched_cols
  cluster_cols <- dependency_cols$cluster_cols
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
    subject_columns = subject_cols,
    declared_matched_columns = dependency_cols$declared_matched_cols,
    declared_cluster_columns = dependency_cols$declared_cluster_cols,
    heuristic_matched_columns = dependency_cols$heuristic_matched_cols,
    heuristic_cluster_columns = dependency_cols$heuristic_cluster_cols
  )

  # 2. Survey weight fail-fast check
  if (length(survey_cols) > 0L || isTRUE(config$is_complex_survey)) {
    stop(
      "[ERROR] [UNSUPPORTED_SURVEY_DESIGN] Complex survey sampling weights detected (columns: ",
      paste(survey_cols, collapse = ", "),
      "). Complex survey designs are currently not supported in comparative evidence engines."
    )
  }

  repeated_assessment <- if (!is.null(config$repeated_rows)) {
    assess_repeated_subject_rows(df, config, cluster_cols, matched_cols)
  } else {
    NULL
  }

  # 3. Target count columns check (H2 fix: avoid treating age, BMI, lab, etc. as count columns)
  if (is.null(repeated_assessment)) {
    # If config explicitly declares count columns, restrict to those
    declared_count_cols <- if (!is.null(config$count_columns)) config$count_columns else config$events_col
    if (!is.null(declared_count_cols)) {
      if (!all(declared_count_cols %in% names(df))) {
        stop("[ERROR] [MISSING_COUNT_COLUMNS] Explicit count columns are absent from input.")
      }
      target_count_cols <- declared_count_cols
    } else {
      # Otherwise check numeric columns that are likely count columns
      likely_counts <- names(df)[col_names_lower %in% c("events", "event", "total", "count", "counts", "n", "freq", "cases", "y")]
      if (length(likely_counts) > 0L) {
        target_count_cols <- likely_counts
      } else {
        stop("[ERROR] [COUNT_COLUMNS_REQUIRED] Specify event and denominator count columns explicitly.")
      }
    }

    non_integer_detected <- FALSE
    non_integer_details <- list()

    for (col in target_count_cols) {
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
      target_count_columns_inspected = target_count_cols,
      details = non_integer_details
    )
  } else {
    diagnostics$non_integer_counts <- list(detected = FALSE, target_count_columns_inspected = character(), details = list())
  }

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
      pt_dups <- sum(duplicated(df[c(sub_col, pt_col)]))
      duplicate_diagnostics$pt_duplicates <- pt_dups
    }

    if (length(soc_cols) > 0L) {
      soc_col <- soc_cols[[1L]]
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
  if (!is.null(repeated_assessment)) diagnostics$repeated_rows <- repeated_assessment$diagnostics

  list(
    valid = TRUE,
    diagnostics = diagnostics,
    subject_level_counts = if (is.null(repeated_assessment)) NULL else repeated_assessment$counts
  )
}

# Validate configuration against Pass 0 contract
validate_pass0_config <- function(config) {
  required_fields <- c("domain", "estimand", "analysis_unit", "target", "reference", "design", "practical_difference", "reporting_purpose")
  missing <- setdiff(required_fields, names(config))
  if (length(missing) > 0L) {
    stop(sprintf("[ERROR] [INVALID_CONFIG] Missing required Pass 0 configuration fields: %s", paste(missing, collapse = ", ")))
  }
  validate_repeated_rows_config(config)

  # Validate practical difference mode and delta
  pd <- config$practical_difference
  if (!is.list(pd) || is.null(pd$mode)) {
    stop("[ERROR] [INVALID_CONFIG] practical_difference must be an object with 'mode'.")
  }
  if (pd$mode == "none") {
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
      stop(
        "[ERROR] [UNCONFIRMED_CAUSAL_ESTIMAND] Causal estimand (", config$estimand,
        ") requires explicit confirmation regarding target population weighting."
      )
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
  validate_pass0_config(config)
  inspection <- inspect_tabular_input(df, config)

  design <- config$design
  if (identical(design, "independent_binary") && identical(config$analysis_unit, "subject") &&
    is.null(config$repeated_rows) && length(inspection$diagnostics$detected_columns$subject_columns) > 0L) {
    subject_col <- inspection$diagnostics$detected_columns$subject_columns[[1L]]
    if (anyDuplicated(df[[subject_col]])) {
      stop("[REPEATED_ROWS_REQUIRE_COLLAPSE_POLICY] 同一被験者の反復行には確認済みの集約方針が必要です")
    }
  }
  if (!design %in% names(CANONICAL_ROUTING_TABLE)) {
    stop("[ERROR] [UNKNOWN_DESIGN] Unknown study design: ", design)
  }

  route <- CANONICAL_ROUTING_TABLE[[design]]
  target_engine_slug <- route$target_engine_slug
  engine_module <- route$engine_module
  inferential_semantics <- route$inferential_semantics

  has_floats <- isTRUE(inspection$diagnostics$non_integer_counts$detected)
  has_weights <- length(inspection$diagnostics$detected_columns$weight_columns) > 0L

  # Fail-fast guard for unweighted independent Beta-Binomial engine
  if (design == "independent_binary" && (has_weights || has_floats)) {
    stop(
      "[ERROR] [UNSUPPORTED_WEIGHTED_INPUT] Weighted pseudo-counts or non-integer counts cannot enter ",
      "the unweighted independent Beta-Binomial engine. Observational weighted cohorts must be routed to 'comparative-design-analysis'."
    )
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
  if (!is.null(inspection$subject_level_counts)) {
    counts <- inspection$subject_level_counts
    routing_decision$subject_level_counts <- counts
    routing_decision$engine_input <- list(
      contract = "independent_binary_counts_v1",
      target_events = as.integer(counts$target$events),
      target_total = as.integer(counts$target$total),
      reference_events = as.integer(counts$reference$events),
      reference_total = as.integer(counts$reference$total),
      source = "repeated_rows_any_event_collapse"
    )
  }

  if (!is.null(out_file) && nzchar(out_file)) {
    dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(jsonlite::toJSON(routing_decision, auto_unbox = TRUE, pretty = TRUE), out_file)
  }

  routing_decision
}
