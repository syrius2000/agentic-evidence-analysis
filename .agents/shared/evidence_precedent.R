# .agents/shared/evidence_precedent.R
# Historical precedent version binding (13.7) and nearest retrieval (13.8)
#
# Decision labels live only in decision_context. Gower distance uses
# decision-label-free evidence_feature + frozen_reference_range.

HISTORICAL_PRECEDENT_SCHEMA_VERSION <- "historical-precedent-case-v1"
PRECEDENT_VERSION_KEYS <- c(
  "dictionary_release_version",
  "delta_policy_version",
  "feature_schema_version"
)

.require_nonempty_string <- function(x, field) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("[INVALID_PRECEDENT_CASE] ", field, " must be a non-empty string")
  }
  trimws(x)
}

#' Validate and normalize precedent version binding metadata (13.7).
assert_precedent_versions <- function(versions, context = "versions") {
  if (!is.list(versions) || is.null(names(versions))) {
    stop("[INVALID_PRECEDENT_VERSIONS] ", context, " must be a named list")
  }
  missing <- setdiff(PRECEDENT_VERSION_KEYS, names(versions))
  if (length(missing) > 0L) {
    stop(
      "[MISSING_PRECEDENT_VERSIONS] required version keys missing: ",
      paste(missing, collapse = ", ")
    )
  }
  out <- list()
  for (k in PRECEDENT_VERSION_KEYS) {
    out[[k]] <- .require_nonempty_string(versions[[k]], paste0(context, ".", k))
  }
  if (!is.null(versions$range_version)) {
    out$range_version <- .require_nonempty_string(
      versions$range_version, paste0(context, ".range_version")
    )
  }
  out
}

#' Compare query vs historical version bindings; never silently ignore mismatches.
compare_precedent_versions <- function(query_versions, case_versions) {
  q <- assert_precedent_versions(query_versions, "query_versions")
  c <- assert_precedent_versions(case_versions, "case_versions")
  mismatches <- character()
  for (k in PRECEDENT_VERSION_KEYS) {
    if (!identical(q[[k]], c[[k]])) {
      mismatches <- c(mismatches, sprintf("%s: query=%s case=%s", k, q[[k]], c[[k]]))
    }
  }
  list(
    version_compatible = length(mismatches) == 0L,
    version_mismatches = mismatches,
    query_versions = q,
    case_versions = c
  )
}

#' Feature-schema distance scorability is independent of dictionary/delta policy match.
is_precedent_distance_scorable <- function(query_versions, case_versions, frozen_range) {
  q <- assert_precedent_versions(query_versions, "query_versions")
  c <- assert_precedent_versions(case_versions, "case_versions")
  if (is.null(frozen_range$feature_schema_version)) {
    stop("[INVALID_FROZEN_RANGE] frozen_range.feature_schema_version is required")
  }
  range_ver <- as.character(frozen_range$feature_schema_version)
  identical(q$feature_schema_version, c$feature_schema_version) &&
    identical(q$feature_schema_version, range_ver) &&
    identical(c$feature_schema_version, range_ver)
}

assert_decision_context <- function(ctx) {
  if (!is.list(ctx)) {
    stop("[INVALID_DECISION_CONTEXT] decision_context must be a list")
  }
  list(
    decision_state = .require_nonempty_string(ctx$decision_state, "decision_state"),
    reviewer_justification_md = if (is.null(ctx$reviewer_justification_md)) {
      ""
    } else if (is.character(ctx$reviewer_justification_md) && length(ctx$reviewer_justification_md) == 1L &&
      !is.na(ctx$reviewer_justification_md)) {
      as.character(ctx$reviewer_justification_md)
    } else {
      stop("[INVALID_DECISION_CONTEXT] reviewer_justification_md must be a string")
    },
    actor_id = .require_nonempty_string(ctx$actor_id, "actor_id"),
    decided_at_jst = .require_nonempty_string(ctx$decided_at_jst, "decided_at_jst"),
    notes = if (is.null(ctx$notes)) NULL else as.character(ctx$notes)
  )
}

#' Validate a historical precedent case object (13.7).
assert_historical_precedent_case <- function(case) {
  if (!is.list(case)) {
    stop("[INVALID_PRECEDENT_CASE] case must be a list")
  }
  if (!identical(as.character(case$schema_version), HISTORICAL_PRECEDENT_SCHEMA_VERSION)) {
    stop(
      "[INVALID_PRECEDENT_CASE] schema_version must be ",
      HISTORICAL_PRECEDENT_SCHEMA_VERSION
    )
  }
  case_id <- .require_nonempty_string(case$case_id, "case_id")
  versions <- assert_precedent_versions(case$versions)
  if (!is.list(case$evidence_feature)) {
    stop("[INVALID_PRECEDENT_CASE] evidence_feature is required")
  }
  feat <- assert_evidence_feature_v1(case$evidence_feature, context = "precedent.evidence_feature")
  if (!identical(as.character(feat$feature_schema_version), versions$feature_schema_version)) {
    stop(
      "[PRECEDENT_FEATURE_SCHEMA_MISMATCH] versions.feature_schema_version=",
      versions$feature_schema_version, " != evidence_feature.feature_schema_version=",
      feat$feature_schema_version
    )
  }
  decision_context <- assert_decision_context(case$decision_context)
  list(
    schema_version = HISTORICAL_PRECEDENT_SCHEMA_VERSION,
    case_id = case_id,
    versions = versions,
    evidence_feature = feat,
    decision_context = decision_context
  )
}

#' Construct a validated historical precedent case.
make_historical_precedent_case <- function(case_id, versions, evidence_feature,
                                           decision_context) {
  assert_historical_precedent_case(list(
    schema_version = HISTORICAL_PRECEDENT_SCHEMA_VERSION,
    case_id = case_id,
    versions = versions,
    evidence_feature = evidence_feature,
    decision_context = decision_context
  ))
}

#' Retrieve nearest historical precedents by Gower distance (13.8).
#'
#' @param query_feature evidence-feature-v1 for the active case
#' @param query_versions version binding for the active case (13.7 keys)
#' @param historical_cases list of historical-precedent-case-v1 objects
#' @param frozen_range frozen-reference-range-v1
#' @param n_neighbors positive integer (default 5)
#' @param keys optional Gower feature key subset
#' @param require_version_match if TRUE, drop version-incompatible cases
#' @return ranked neighborhood with distances and full decision_context
retrieve_nearest_precedents <- function(query_feature, query_versions,
                                        historical_cases, frozen_range,
                                        n_neighbors = 5L, keys = NULL,
                                        require_version_match = FALSE) {
  if (!is.list(query_feature)) {
    stop("[INVALID_QUERY_FEATURE] query_feature must be an evidence-feature list")
  }
  q_versions <- assert_precedent_versions(query_versions, "query_versions")
  query_feature <- assert_evidence_feature_v1(query_feature, context = "query_feature")

  if (!identical(
    as.character(query_feature$feature_schema_version),
    q_versions$feature_schema_version
  )) {
    stop(
      "[PRECEDENT_FEATURE_SCHEMA_MISMATCH] query versions.feature_schema_version=",
      q_versions$feature_schema_version, " != query_feature.feature_schema_version=",
      query_feature$feature_schema_version
    )
  }

  if (!is.list(historical_cases) || length(historical_cases) < 1L) {
    stop("[EMPTY_PRECEDENT_LIBRARY] historical_cases must be a non-empty list")
  }
  if (!is.numeric(n_neighbors) || length(n_neighbors) != 1L || is.na(n_neighbors) ||
    !is.finite(n_neighbors) || n_neighbors != as.integer(n_neighbors) ||
    as.integer(n_neighbors) < 1L) {
    stop("[INVALID_N_NEIGHBORS] n_neighbors must be a positive finite integer")
  }
  n_neighbors <- as.integer(n_neighbors)
  if (!is.logical(require_version_match) || length(require_version_match) != 1L ||
    is.na(require_version_match)) {
    stop("[INVALID_REQUIRE_VERSION_MATCH] require_version_match must be a single logical")
  }

  validated <- lapply(historical_cases, assert_historical_precedent_case)
  case_ids <- vapply(validated, function(c) c$case_id, character(1))
  if (anyDuplicated(case_ids)) {
    stop("[DUPLICATE_PRECEDENT_CASE_ID] case_id values must be unique")
  }

  hits <- list()
  unscorable <- list()
  excluded <- list()

  for (i in seq_along(validated)) {
    case <- validated[[i]]
    ver <- compare_precedent_versions(q_versions, case$versions)
    scorable <- is_precedent_distance_scorable(q_versions, case$versions, frozen_range)

    if (isTRUE(require_version_match) && !isTRUE(ver$version_compatible)) {
      excluded[[length(excluded) + 1L]] <- list(
        case_id = case$case_id,
        reason = "version_incompatible",
        version_compatible = FALSE,
        version_mismatches = ver$version_mismatches,
        distance_scorable = scorable,
        distance_status = "EXCLUDED"
      )
      next
    }

    if (!isTRUE(scorable)) {
      unscorable[[length(unscorable) + 1L]] <- list(
        case_id = case$case_id,
        reason = "feature_schema_not_comparable",
        version_compatible = ver$version_compatible,
        version_mismatches = ver$version_mismatches,
        distance_scorable = FALSE,
        distance_status = "NOT_COMPARABLE",
        gower_distance = NULL,
        versions = case$versions,
        decision_context = case$decision_context
      )
      next
    }

    gp <- gower_pairwise_distance(
      query_feature,
      case$evidence_feature,
      frozen_range,
      keys = keys
    )
    hits[[length(hits) + 1L]] <- list(
      case_id = case$case_id,
      gower_distance = as.numeric(gp$distance),
      gower_keys_used = as.character(gp$keys_used),
      gower_warnings = gp$warnings,
      version_compatible = ver$version_compatible,
      version_mismatches = ver$version_mismatches,
      distance_scorable = TRUE,
      distance_status = "COMPARABLE",
      versions = case$versions,
      decision_context = case$decision_context,
      evidence_feature = case$evidence_feature
    )
  }

  if (length(hits) < 1L) {
    stop(
      "[PRECEDENT_NO_SCORABLE_CASES] no historical cases remain distance-scorable ",
      "(require_version_match=", require_version_match,
      ", n_unscorable=", length(unscorable),
      ", n_excluded=", length(excluded), ")"
    )
  }

  dists <- vapply(hits, function(h) h$gower_distance, numeric(1))
  hit_ids <- vapply(hits, function(h) h$case_id, character(1))
  ord <- order(dists, hit_ids)
  hits <- hits[ord]
  n_take <- min(n_neighbors, length(hits))
  neighborhood <- hits[seq_len(n_take)]

  decision_states <- vapply(
    neighborhood,
    function(h) h$decision_context$decision_state,
    character(1)
  )
  decision_tab <- as.list(table(factor(decision_states, levels = unique(decision_states))))

  list(
    method = "gower_nearest_precedents",
    n_library = length(validated),
    n_candidates = length(hits),
    n_returned = n_take,
    n_neighbors_requested = n_neighbors,
    n_unscorable = length(unscorable),
    n_excluded = length(excluded),
    require_version_match = require_version_match,
    query_versions = q_versions,
    range_version = as.character(frozen_range$range_version),
    feature_schema_version = as.character(frozen_range$feature_schema_version),
    neighborhood = neighborhood,
    unscorable_cases = unscorable,
    excluded_cases = excluded,
    decision_state_counts = decision_tab,
    wording = paste(
      "Retrieved precedents are exploratory context only;",
      "they do not prescribe a regulatory decision."
    ),
    exploratory_only = TRUE,
    decision_rule = FALSE
  )
}
