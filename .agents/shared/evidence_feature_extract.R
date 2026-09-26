# .agents/shared/evidence_feature_extract.R
# Decision-label-free evidence feature extraction for evidence-decision-review (Section 13 Phase A)

EVIDENCE_FEATURE_SCHEMA_VERSION <- "1.0.0"

FORBIDDEN_DECISION_LABEL_KEYS <- c(
  "decision",
  "decision_code",
  "decision_label",
  "clinical_verdict",
  "regulatory_label",
  "regulatory_outcome",
  "regulatory_action",
  "prior_decision",
  "expert_decision",
  "human_verdict",
  "action_label",
  "label_modification",
  "approval_status",
  "reject_status"
)

# Canonical clustering key order: core first, then delta-dependent when present.
CORE_CLUSTERING_KEYS <- c(
  "rd_estimate",
  "rd_interval_width",
  "direction_support",
  "resolution_grade",
  "rr_mean_is_finite",
  "has_zero_reference",
  "target_n",
  "reference_n",
  "quarantine_flag_count"
)

DELTA_CLUSTERING_KEYS <- c(
  "primary_delta",
  "target_excess",
  "practical_neutral",
  "reference_excess"
)

ALLOWED_CLUSTERING_KEYS <- c(CORE_CLUSTERING_KEYS, DELTA_CLUSTERING_KEYS)

collect_named_keys <- function(x, acc = character()) {
  if (!is.list(x)) {
    return(acc)
  }
  nms <- names(x)
  if (!is.null(nms)) acc <- c(acc, nms[nzchar(nms)])
  for (el in x) acc <- collect_named_keys(el, acc)
  unique(acc)
}

assert_no_forbidden_decision_labels <- function(obj, context = "evidence_profile") {
  keys <- collect_named_keys(obj)
  hit <- intersect(tolower(keys), tolower(FORBIDDEN_DECISION_LABEL_KEYS))
  if (length(hit) > 0L) {
    stop(
      "[DECISION_LABEL_IN_FEATURE_SOURCE] ", context,
      " contains forbidden decision/regulatory keys: ",
      paste(sort(unique(hit)), collapse = ", ")
    )
  }
  invisible(TRUE)
}

assert_clustering_feature_keys <- function(keys, delta_present) {
  keys <- unlist(keys, use.names = FALSE)
  if (!is.character(keys) || length(keys) < 1L || anyNA(keys) || any(!nzchar(keys)) || anyDuplicated(keys)) {
    stop("[INVALID_CLUSTERING_FEATURE_KEYS] clustering_feature_keys must be a unique non-empty string array")
  }
  forbidden <- intersect(tolower(keys), tolower(FORBIDDEN_DECISION_LABEL_KEYS))
  if (length(forbidden) > 0L) {
    stop(
      "[DECISION_LABEL_IN_FEATURE_KEYS] clustering_feature_keys must not include decision labels: ",
      paste(forbidden, collapse = ", ")
    )
  }
  if (!isTRUE(delta_present) && length(intersect(keys, DELTA_CLUSTERING_KEYS)) > 0L) {
    stop("[DELTA_CLUSTERING_KEYS_WHEN_ABSENT] present=false prohibits delta clustering keys")
  }
  allowed <- if (isTRUE(delta_present)) ALLOWED_CLUSTERING_KEYS else CORE_CLUSTERING_KEYS
  unknown <- setdiff(keys, allowed)
  if (length(unknown) > 0L) {
    stop(
      "[UNKNOWN_CLUSTERING_FEATURE_KEYS] clustering_feature_keys contain non-canonical attributes: ",
      paste(unknown, collapse = ", ")
    )
  }
  if (isTRUE(delta_present)) {
    missing_delta <- setdiff(DELTA_CLUSTERING_KEYS, keys)
    if (length(missing_delta) > 0L) {
      stop(
        "[MISSING_DELTA_CLUSTERING_KEYS] present=true requires delta clustering keys: ",
        paste(missing_delta, collapse = ", ")
      )
    }
  }
  invisible(TRUE)
}

.assert_single_number <- function(x, field, min = NULL, max = NULL, allow_null = FALSE) {
  if (is.null(x)) {
    if (isTRUE(allow_null)) {
      return(invisible(TRUE))
    }
    stop("[INVALID_EVIDENCE_FEATURE] ", field, " is required")
  }
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
    stop("[INVALID_EVIDENCE_FEATURE] ", field, " must be a finite number")
  }
  if (!is.null(min) && x < min) stop("[INVALID_EVIDENCE_FEATURE] ", field, " below minimum ", min)
  if (!is.null(max) && x > max) stop("[INVALID_EVIDENCE_FEATURE] ", field, " above maximum ", max)
  invisible(TRUE)
}

.assert_nullable_single_string <- function(x, field) {
  if (is.null(x)) {
    return(invisible(TRUE))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop("[INVALID_EVIDENCE_FEATURE] ", field, " must be string or null")
  }
  invisible(TRUE)
}

#' Full canonical evidence-feature-v1 contract (parity with schemas/evidence-feature-v1.json).
assert_evidence_feature_v1 <- function(features, context = "evidence_feature") {
  if (!is.list(features) || is.null(names(features))) {
    stop("[INVALID_EVIDENCE_FEATURE] ", context, " must be a named list")
  }
  required_root <- c(
    "schema_version", "feature_schema_version", "source",
    "core", "delta_dependent", "clustering_feature_keys"
  )
  missing_root <- setdiff(required_root, names(features))
  if (length(missing_root) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] ", context, " missing required fields: ",
      paste(missing_root, collapse = ", ")
    )
  }
  extra_root <- setdiff(names(features), required_root)
  if (length(extra_root) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] ", context, " has additional properties: ",
      paste(extra_root, collapse = ", ")
    )
  }
  if (!identical(as.character(features$schema_version), "evidence-feature-v1")) {
    stop("[INVALID_EVIDENCE_FEATURE] schema_version must be evidence-feature-v1")
  }
  if (!is.character(features$feature_schema_version) || length(features$feature_schema_version) != 1L ||
    is.na(features$feature_schema_version) || !nzchar(trimws(features$feature_schema_version))) {
    stop("[INVALID_EVIDENCE_FEATURE] feature_schema_version must be a non-empty string")
  }

  assert_no_forbidden_decision_labels(features, context = context)

  src <- features$source
  if (!is.list(src)) stop("[INVALID_EVIDENCE_FEATURE] source must be an object")
  src_required <- c("evidence_schema_version", "inferential_semantics")
  missing_src <- setdiff(src_required, names(src))
  if (length(missing_src) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] source missing: ",
      paste(missing_src, collapse = ", ")
    )
  }
  if (!identical(as.character(src$evidence_schema_version), "comparative-evidence-v1")) {
    stop("[INVALID_EVIDENCE_FEATURE] source.evidence_schema_version must be comparative-evidence-v1")
  }
  if (!identical(as.character(src$inferential_semantics), "posterior") &&
    !identical(as.character(src$inferential_semantics), "bootstrap")) {
    stop("[INVALID_EVIDENCE_FEATURE] source.inferential_semantics must be posterior or bootstrap")
  }
  allowed_src <- c(src_required, "contrast_id", "theme")
  extra_src <- setdiff(names(src), allowed_src)
  if (length(extra_src) > 0L) {
    stop("[INVALID_EVIDENCE_FEATURE] source has additional properties: ", paste(extra_src, collapse = ", "))
  }
  .assert_nullable_single_string(src$contrast_id, "source.contrast_id")
  .assert_nullable_single_string(src$theme, "source.theme")

  core <- features$core
  if (!is.list(core)) stop("[INVALID_EVIDENCE_FEATURE] core must be an object")
  missing_core <- setdiff(CORE_CLUSTERING_KEYS, names(core))
  if (length(missing_core) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] core missing required attributes: ",
      paste(missing_core, collapse = ", ")
    )
  }
  extra_core <- setdiff(names(core), CORE_CLUSTERING_KEYS)
  if (length(extra_core) > 0L) {
    stop("[INVALID_EVIDENCE_FEATURE] core has additional properties: ", paste(extra_core, collapse = ", "))
  }
  .assert_single_number(core$rd_estimate, "core.rd_estimate")
  .assert_single_number(core$rd_interval_width, "core.rd_interval_width", min = 0)
  .assert_single_number(core$direction_support, "core.direction_support", min = 0, max = 1)
  if (!is.character(core$resolution_grade) || length(core$resolution_grade) != 1L ||
    !(core$resolution_grade %in% c("U0", "U1", "U2", "U3", "NONE"))) {
    stop("[INVALID_EVIDENCE_FEATURE] core.resolution_grade must be U0/U1/U2/U3/NONE")
  }
  if (!is.logical(core$rr_mean_is_finite) || length(core$rr_mean_is_finite) != 1L ||
    is.na(core$rr_mean_is_finite)) {
    stop("[INVALID_EVIDENCE_FEATURE] core.rr_mean_is_finite must be a boolean")
  }
  if (!is.logical(core$has_zero_reference) || length(core$has_zero_reference) != 1L ||
    is.na(core$has_zero_reference)) {
    stop("[INVALID_EVIDENCE_FEATURE] core.has_zero_reference must be a boolean")
  }
  .assert_single_number(core$target_n, "core.target_n", min = 0, allow_null = TRUE)
  .assert_single_number(core$reference_n, "core.reference_n", min = 0, allow_null = TRUE)
  if (!is.numeric(core$quarantine_flag_count) || length(core$quarantine_flag_count) != 1L ||
    is.na(core$quarantine_flag_count) || core$quarantine_flag_count != as.integer(core$quarantine_flag_count) ||
    core$quarantine_flag_count < 0) {
    stop("[INVALID_EVIDENCE_FEATURE] core.quarantine_flag_count must be a non-negative integer")
  }

  delta_fields <- c("present", "primary_delta", "target_excess", "practical_neutral", "reference_excess")
  delta <- features$delta_dependent
  if (!is.list(delta)) stop("[INVALID_EVIDENCE_FEATURE] delta_dependent must be an object")
  missing_delta <- setdiff(delta_fields, names(delta))
  if (length(missing_delta) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] delta_dependent missing required fields: ",
      paste(missing_delta, collapse = ", ")
    )
  }
  extra_delta <- setdiff(names(delta), delta_fields)
  if (length(extra_delta) > 0L) {
    stop(
      "[INVALID_EVIDENCE_FEATURE] delta_dependent has additional properties: ",
      paste(extra_delta, collapse = ", ")
    )
  }
  assert_delta_dependent_atomicity(delta)
  assert_clustering_feature_keys(features$clustering_feature_keys, delta$present)
  invisible(features)
}

assert_delta_dependent_atomicity <- function(delta) {
  if (!is.list(delta) || is.null(delta$present) ||
    !is.logical(delta$present) || length(delta$present) != 1L || is.na(delta$present)) {
    stop("[INVALID_DELTA_DEPENDENT] delta_dependent.present must be a boolean")
  }
  fields <- c("primary_delta", "target_excess", "practical_neutral", "reference_excess")
  if (isTRUE(delta$present)) {
    for (nm in fields) {
      val <- delta[[nm]]
      if (is.null(val) || length(val) != 1L || is.na(val) || !is.numeric(val)) {
        stop("[INVALID_DELTA_DEPENDENT] present=true requires numeric ", nm)
      }
    }
    if (!(delta$primary_delta > 0)) {
      stop("[INVALID_DELTA_DEPENDENT] present=true requires primary_delta > 0")
    }
    for (nm in c("target_excess", "practical_neutral", "reference_excess")) {
      if (delta[[nm]] < 0 || delta[[nm]] > 1) {
        stop("[INVALID_DELTA_DEPENDENT] ", nm, " must be in [0, 1]")
      }
    }
    region_sum <- delta$target_excess + delta$practical_neutral + delta$reference_excess
    if (abs(region_sum - 1) > 1e-8) {
      stop("[INVALID_DELTA_DEPENDENT] practical region probabilities must sum to 1")
    }
  } else {
    for (nm in fields) {
      if (!is.null(delta[[nm]])) {
        stop("[INVALID_DELTA_DEPENDENT] present=false requires ", nm, " = null")
      }
    }
  }
  invisible(TRUE)
}

extract_evidence_features <- function(evidence) {
  if (!is.list(evidence) || is.null(evidence$schema_version)) {
    stop("[INVALID_EVIDENCE_PROFILE] comparative-evidence-v1 object is required")
  }
  if (!identical(evidence$schema_version, "comparative-evidence-v1")) {
    stop(
      "[INVALID_EVIDENCE_PROFILE] unsupported evidence schema_version: ",
      as.character(evidence$schema_version)
    )
  }
  assert_no_forbidden_decision_labels(evidence)

  rd <- evidence$risk_difference
  if (is.null(rd$estimate$value) || is.null(rd$interval$lower) || is.null(rd$interval$upper)) {
    stop("[INVALID_EVIDENCE_PROFILE] risk_difference estimate/interval are required")
  }
  direction <- evidence$direction_support$support_value
  if (is.null(direction) || !is.numeric(direction) || length(direction) != 1L ||
    is.na(direction) || direction < 0 || direction > 1) {
    stop("[INVALID_EVIDENCE_PROFILE] direction_support.support_value must be in [0, 1]")
  }
  grade <- evidence$resolution_grade$grade
  if (is.null(grade) || !grade %in% c("U0", "U1", "U2", "U3", "NONE")) {
    stop("[INVALID_EVIDENCE_PROFILE] resolution_grade.grade is missing or invalid")
  }

  badges <- evidence$diagnostics$badges
  if (is.null(badges)) {
    badges <- character()
  } else {
    badges <- unlist(badges, use.names = FALSE)
  }
  quarantine_flags <- evidence$diagnostics$quarantine_flags
  quarantine_count <- if (is.null(quarantine_flags)) 0L else length(quarantine_flags)

  prs <- evidence$practical_region_support
  delta_present <- !is.null(prs) && !is.null(prs$primary_delta) && !is.na(prs$primary_delta)
  delta_block <- if (isTRUE(delta_present)) {
    list(
      present = TRUE,
      primary_delta = as.numeric(prs$primary_delta),
      target_excess = if (is.null(prs$target_excess)) NULL else as.numeric(prs$target_excess),
      practical_neutral = if (is.null(prs$practical_neutral)) NULL else as.numeric(prs$practical_neutral),
      reference_excess = if (is.null(prs$reference_excess)) NULL else as.numeric(prs$reference_excess)
    )
  } else {
    list(
      present = FALSE,
      primary_delta = NULL,
      target_excess = NULL,
      practical_neutral = NULL,
      reference_excess = NULL
    )
  }
  assert_delta_dependent_atomicity(delta_block)

  clustering_keys <- CORE_CLUSTERING_KEYS
  if (isTRUE(delta_block$present)) {
    clustering_keys <- c(clustering_keys, DELTA_CLUSTERING_KEYS)
  }
  assert_clustering_feature_keys(clustering_keys, delta_block$present)

  features <- list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION,
    source = list(
      evidence_schema_version = "comparative-evidence-v1",
      inferential_semantics = evidence$inferential_semantics,
      contrast_id = if (is.null(evidence$contrast_id)) NULL else as.character(evidence$contrast_id),
      theme = if (is.null(evidence$theme)) NULL else as.character(evidence$theme)
    ),
    core = list(
      rd_estimate = as.numeric(rd$estimate$value),
      rd_interval_width = as.numeric(rd$interval$upper - rd$interval$lower),
      direction_support = as.numeric(direction),
      resolution_grade = as.character(grade),
      rr_mean_is_finite = isTRUE(evidence$relative_risk$mean_is_finite),
      has_zero_reference = isTRUE("ZERO_REFERENCE" %in% badges) ||
        identical(evidence$relative_risk$diagnostic, "ZERO_REFERENCE_EVENTS") ||
        identical(evidence$relative_risk$diagnostic, "ZERO_REFERENCE"),
      target_n = if (is.null(evidence$target_cohort$total)) NULL else as.numeric(evidence$target_cohort$total),
      reference_n = if (is.null(evidence$reference_cohort$total)) NULL else as.numeric(evidence$reference_cohort$total),
      quarantine_flag_count = as.integer(quarantine_count)
    ),
    delta_dependent = delta_block,
    clustering_feature_keys = as.list(clustering_keys)
  )

  assert_evidence_feature_v1(features, context = "evidence_feature_vector")
  features
}

init_evidence_decision_run <- function(out_root = "evidence_runs/evidence_decision_review",
                                       run_id = NULL) {
  if (!exists("reserve_run_output_dir", mode = "function")) {
    shared <- file.path(".", ".agents", "shared", "run_scope.R")
    if (!file.exists(shared)) stop("[MISSING_RUN_SCOPE] run_scope.R is required")
    source(shared, local = FALSE)
  }
  assert_run_scope_supported_skill("evidence-decision-review")
  reserve_run_output_dir(out_root = out_root, skill = "evidence-decision-review", run_id = run_id)
}

# Complete evidence-run-layout lifecycle for a feature artifact:
# reserve → evidence_feature.json → results_manifest.json → run_meta.json
complete_evidence_decision_feature_run <- function(features,
                                                   out_root = "evidence_runs/evidence_decision_review",
                                                   run_id = NULL,
                                                   input_label = "comparative_evidence_profile") {
  if (!exists("write_run_meta", mode = "function") || !exists("write_results_manifest", mode = "function")) {
    shared <- file.path(".", ".agents", "shared", "run_scope.R")
    if (!file.exists(shared)) stop("[MISSING_RUN_SCOPE] run_scope.R is required")
    source(shared, local = FALSE)
  }
  assert_evidence_feature_v1(features, context = "complete_evidence_decision_feature_run")

  logical_id <- if (!is.null(run_id) && nzchar(trimws(as.character(run_id)))) {
    sub("^run_", "", trimws(as.character(run_id)))
  } else {
    format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
  }
  run_dir <- init_evidence_decision_run(out_root = out_root, run_id = logical_id)
  feature_path <- file.path(run_dir, "evidence_feature.json")
  writeLines(
    jsonlite::toJSON(features, auto_unbox = TRUE, null = "null", pretty = TRUE, digits = NA),
    feature_path
  )
  manifest <- write_results_manifest(
    run_dir,
    skill = "evidence-decision-review",
    artifacts = list(list(path = "evidence_feature.json", role = "primary_results"))
  )
  profile_sha <- digest::digest(
    jsonlite::toJSON(features, auto_unbox = TRUE, null = "null", digits = NA),
    algo = "sha256",
    serialize = FALSE
  )
  meta <- write_run_meta(
    out_root = out_root,
    run_output_dir = run_dir,
    skill = "evidence-decision-review",
    run_id = basename(run_dir),
    extra = list(
      requested_run_id = logical_id,
      logical_run_id = logical_id,
      results_manifest_sha256 = manifest$manifest_sha256,
      config_origin = "derived_feature_extract",
      inputs = list(list(
        role = "evidence_profile",
        source_kind = "builtin",
        source_path = as.character(input_label),
        sha256 = profile_sha
      )),
      pass_status = list(
        pass0 = "bypassed",
        pass1 = "completed",
        pass2 = "pending",
        pass3 = "pending"
      )
    )
  )
  list(
    run_dir = run_dir,
    features_path = feature_path,
    manifest = manifest,
    meta = meta
  )
}
