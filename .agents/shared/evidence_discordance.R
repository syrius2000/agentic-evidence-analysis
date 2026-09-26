# .agents/shared/evidence_discordance.R
# Configurable discordance advisory (Section 13.10) and wording contract (13.11)

DISCORDANCE_ADVISORY_SCHEMA_VERSION <- "discordance-advisory-v1"
DISCORDANCE_ADVISORY_FLAG <- "QA Review Candidate"
DISCORDANCE_SEVERITY <- "advisory"

DISCORDANCE_POLICIES <- c("k_neighbors", "distance_radius")

DISCORDANCE_WORDING <- paste(
  "Divergence is flagged as a QA Review Candidate for expert rationale documentation;",
  "it is an informational advisory only and does not halt workflow progression."
)

# Applied to severity/flag/status fields and free-text that claim a hard failure.
# Canonical DISCORDANCE_WORDING must remain free of these tokens.
DISCORDANCE_FORBIDDEN_WORDING_PATTERNS <- c(
  "\\bfatal\\b",
  "\\berror\\b",
  "\\bdefect\\b",
  "\\binvalid\\b",
  "\\breject(ed|ion)?\\b",
  "自動却下",
  "システムエラー",
  "致命的"
)

.require_nonempty_string_disc <- function(x, field) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("[INVALID_DISCORDANCE_INPUT] ", field, " must be a non-empty string")
  }
  trimws(x)
}

.resolve_discordance_policy <- function(policy, k, radius) {
  if (!is.character(policy) || length(policy) != 1L || is.na(policy)) {
    stop("[INVALID_DISCORDANCE_POLICY] policy must be a single string")
  }
  if (!(policy %in% DISCORDANCE_POLICIES)) {
    stop(
      "[INVALID_DISCORDANCE_POLICY] policy must be one of: ",
      paste(DISCORDANCE_POLICIES, collapse = ", ")
    )
  }
  if (identical(policy, "k_neighbors")) {
    if (!is.null(radius)) {
      stop("[INVALID_DISCORDANCE_POLICY] radius must be NULL when policy=k_neighbors")
    }
    if (is.null(k) || !is.numeric(k) || length(k) != 1L || is.na(k) ||
      !is.finite(k) || k != as.integer(k) || as.integer(k) < 1L) {
      stop("[INVALID_DISCORDANCE_K] k must be a positive finite integer")
    }
    return(list(policy = policy, k = as.integer(k), radius = NULL))
  }
  if (!is.null(k)) {
    stop("[INVALID_DISCORDANCE_POLICY] k must be NULL when policy=distance_radius")
  }
  if (is.null(radius) || !is.numeric(radius) || length(radius) != 1L || is.na(radius) ||
    !is.finite(radius) || radius < 0 || radius > 1) {
    stop("[INVALID_DISCORDANCE_RADIUS] radius must be a finite number in [0, 1]")
  }
  list(policy = policy, k = NULL, radius = as.numeric(radius))
}

.extract_neighborhood_hits <- function(precedent_or_neighborhood) {
  if (!is.list(precedent_or_neighborhood)) {
    stop("[INVALID_DISCORDANCE_INPUT] neighborhood must be a list")
  }
  if (!is.null(precedent_or_neighborhood$neighborhood)) {
    hits <- precedent_or_neighborhood$neighborhood
  } else {
    hits <- precedent_or_neighborhood
  }
  if (!is.list(hits) || length(hits) < 1L) {
    stop("[EMPTY_DISCORDANCE_NEIGHBORHOOD] neighborhood must be a non-empty list")
  }
  hits
}

.select_policy_neighborhood <- function(hits, resolved) {
  dists <- vapply(hits, function(h) {
    d <- h$gower_distance
    if (is.null(d) || length(d) != 1L || is.na(d) || !is.finite(d) || d < 0) {
      stop("[INVALID_DISCORDANCE_INPUT] each hit requires finite non-negative gower_distance")
    }
    as.numeric(d)
  }, numeric(1))
  ids <- vapply(hits, function(h) {
    if (is.null(h$case_id)) {
      return("")
    }
    as.character(h$case_id)
  }, character(1))
  ord <- order(dists, ids)
  hits <- hits[ord]
  dists <- dists[ord]

  if (identical(resolved$policy, "k_neighbors")) {
    n_take <- min(resolved$k, length(hits))
    return(list(hits = hits[seq_len(n_take)], distances = dists[seq_len(n_take)]))
  }
  keep <- dists <= resolved$radius
  if (!any(keep)) {
    stop(
      "[EMPTY_DISCORDANCE_NEIGHBORHOOD] no precedents within radius=",
      resolved$radius
    )
  }
  list(hits = hits[keep], distances = dists[keep])
}

.decision_states_from_hits <- function(hits) {
  vapply(hits, function(h) {
    st <- NULL
    if (!is.null(h$decision_context) && !is.null(h$decision_context$decision_state)) {
      st <- h$decision_context$decision_state
    } else if (!is.null(h$decision_state)) {
      st <- h$decision_state
    }
    .require_nonempty_string_disc(st, "decision_state")
  }, character(1))
}

.dominant_decision_state <- function(states) {
  tab <- table(states)
  max_n <- max(as.integer(tab))
  winners <- names(tab)[as.integer(tab) == max_n]
  if (length(winners) > 1L) {
    return(list(dominant_state = NULL, tie = TRUE, counts = as.list(tab)))
  }
  list(dominant_state = winners[[1L]], tie = FALSE, counts = as.list(tab))
}

#' Enforce discordance wording contract (13.11): advisory only, never error language.
#'
#' Forbidden-language scan is limited to system-controlled advisory fields
#' (13.10.R1 / 13.11.R1). Domain decision labels such as REJECT / REJECTED
#' in provisional_decision_state / dominant_state are never scanned.
assert_discordance_wording_contract <- function(obj) {
  if (!is.list(obj)) {
    stop("[DISCORDANCE_WORDING_VIOLATION] advisory object must be a list")
  }
  system_fields <- c("wording", "severity", "advisory_flag")
  texts <- character()
  for (nm in system_fields) {
    v <- obj[[nm]]
    if (is.character(v)) {
      texts <- c(texts, v[!is.na(v)])
    }
  }
  blob <- paste(texts, collapse = "\n")
  for (pat in DISCORDANCE_FORBIDDEN_WORDING_PATTERNS) {
    if (nzchar(blob) && grepl(pat, blob, ignore.case = TRUE, perl = TRUE)) {
      stop(
        "[DISCORDANCE_WORDING_VIOLATION] forbidden wording matched pattern: ",
        pat
      )
    }
  }
  # Canonical system wording must name the designation.
  if (
    !is.character(obj$wording) || length(obj$wording) != 1L || is.na(obj$wording) ||
      !grepl("QA Review Candidate", obj$wording, fixed = TRUE)
  ) {
    stop("[DISCORDANCE_WORDING_VIOLATION] missing QA Review Candidate designation")
  }
  if (!isFALSE(obj$halts_workflow)) {
    stop("[DISCORDANCE_WORDING_VIOLATION] halts_workflow must be FALSE")
  }
  if (isTRUE(obj$is_qa_review_candidate)) {
    if (!identical(obj$advisory_flag, DISCORDANCE_ADVISORY_FLAG)) {
      stop("[DISCORDANCE_WORDING_VIOLATION] advisory_flag must be 'QA Review Candidate'")
    }
    if (!identical(as.character(obj$severity), DISCORDANCE_SEVERITY)) {
      stop("[DISCORDANCE_WORDING_VIOLATION] severity must be 'advisory'")
    }
  } else if (!is.null(obj$severity) || !is.null(obj$advisory_flag)) {
    stop("[DISCORDANCE_WORDING_VIOLATION] non-candidate must not set severity/advisory_flag")
  }
  invisible(TRUE)
}

#' Evaluate discordance of a provisional decision vs precedent neighborhood (13.10).
#'
#' @param provisional_decision_state active reviewer provisional state
#' @param precedent_or_neighborhood retrieve_nearest_precedents() result or hit list
#' @param policy "k_neighbors" or "distance_radius"
#' @param k neighborhood size when policy=k_neighbors
#' @param radius Gower radius in [0,1] when policy=distance_radius
#' @return discordance-advisory-v1 list (never throws on divergence)
evaluate_discordance_advisory <- function(provisional_decision_state,
                                          precedent_or_neighborhood,
                                          policy = "k_neighbors",
                                          k = NULL,
                                          radius = NULL) {
  provisional <- .require_nonempty_string_disc(
    provisional_decision_state,
    "provisional_decision_state"
  )
  resolved <- .resolve_discordance_policy(policy, k, radius)
  hits_all <- .extract_neighborhood_hits(precedent_or_neighborhood)
  selected <- .select_policy_neighborhood(hits_all, resolved)
  states <- .decision_states_from_hits(selected$hits)
  dom <- .dominant_decision_state(states)

  is_candidate <- FALSE
  if (!isTRUE(dom$tie) && !identical(provisional, dom$dominant_state)) {
    is_candidate <- TRUE
  }

  out <- list(
    schema_version = DISCORDANCE_ADVISORY_SCHEMA_VERSION,
    policy = resolved$policy,
    k = resolved$k,
    radius = resolved$radius,
    n_neighborhood = length(selected$hits),
    provisional_decision_state = provisional,
    dominant_state = dom$dominant_state,
    tie = isTRUE(dom$tie),
    decision_state_counts = dom$counts,
    is_qa_review_candidate = is_candidate,
    advisory_flag = if (is_candidate) DISCORDANCE_ADVISORY_FLAG else NULL,
    severity = if (is_candidate) DISCORDANCE_SEVERITY else NULL,
    halts_workflow = FALSE,
    exploratory_only = TRUE,
    decision_rule = FALSE,
    wording = DISCORDANCE_WORDING,
    neighborhood_case_ids = vapply(selected$hits, function(h) {
      if (is.null(h$case_id)) NA_character_ else as.character(h$case_id)
    }, character(1)),
    neighborhood_distances = as.numeric(selected$distances)
  )
  assert_discordance_wording_contract(out)
  out
}
