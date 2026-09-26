# .agents/shared/evidence_trajectory.R
# Longitudinal decision trajectory across study phases / data cutoffs (Section 13.12)

DECISION_TRAJECTORY_SCHEMA_VERSION <- "decision-trajectory-v1"
DECISION_TRAJECTORY_JST_PATTERN <- "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} JST$"

.require_nonempty_string_traj <- function(x, field) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("[INVALID_TRAJECTORY_EVENT] ", field, " must be a non-empty string")
  }
  trimws(x)
}

.assert_traj_decided_at_jst <- function(x) {
  s <- .require_nonempty_string_traj(x, "decided_at_jst")
  if (!grepl(DECISION_TRAJECTORY_JST_PATTERN, s)) {
    stop(
      "[INVALID_TRAJECTORY_EVENT] decided_at_jst must match ",
      "'YYYY-MM-DD HH:MM:SS JST'"
    )
  }
  core <- sub(" JST$", "", s)
  parsed <- as.POSIXct(core, format = "%Y-%m-%d %H:%M:%S", tz = "Asia/Tokyo")
  if (length(parsed) != 1L || is.na(parsed)) {
    stop("[INVALID_TRAJECTORY_EVENT] decided_at_jst is not a valid calendar datetime")
  }
  list(text = s, posix = parsed)
}

.normalize_trajectory_event <- function(event) {
  if (!is.list(event)) {
    stop("[INVALID_TRAJECTORY_EVENT] event must be a named list")
  }
  case_id <- .require_nonempty_string_traj(event$case_id, "case_id")
  decision_state <- .require_nonempty_string_traj(event$decision_state, "decision_state")
  ts <- .assert_traj_decided_at_jst(event$decided_at_jst)
  study_phase <- event$study_phase
  if (!is.null(study_phase)) {
    study_phase <- .require_nonempty_string_traj(study_phase, "study_phase")
  }
  data_cutoff <- event$data_cutoff
  if (!is.null(data_cutoff)) {
    data_cutoff <- .require_nonempty_string_traj(data_cutoff, "data_cutoff")
  }
  record_id <- event$record_id
  if (!is.null(record_id)) {
    record_id <- .require_nonempty_string_traj(record_id, "record_id")
  }
  actor_id <- event$actor_id
  if (!is.null(actor_id)) {
    actor_id <- .require_nonempty_string_traj(actor_id, "actor_id")
  }
  list(
    case_id = case_id,
    decision_state = decision_state,
    decided_at_jst = ts$text,
    decided_at_posix = ts$posix,
    study_phase = study_phase,
    data_cutoff = data_cutoff,
    record_id = record_id,
    actor_id = actor_id
  )
}

#' Build a longitudinal decision trajectory for one case (13.12).
#'
#' @param events list of events sharing the same case_id; each requires
#'   case_id, decision_state, decided_at_jst; optional study_phase, data_cutoff,
#'   record_id (ledger link), actor_id
#' @return decision-trajectory-v1 list sorted by decided_at_jst then record_id
build_decision_trajectory <- function(events) {
  if (!is.list(events) || length(events) < 1L) {
    stop("[EMPTY_TRAJECTORY] events must be a non-empty list")
  }
  norm <- lapply(events, .normalize_trajectory_event)
  case_ids <- unique(vapply(norm, function(e) e$case_id, character(1)))
  if (length(case_ids) != 1L) {
    stop(
      "[TRAJECTORY_CASE_MISMATCH] all events must share one case_id; found: ",
      paste(case_ids, collapse = ", ")
    )
  }

  ts <- vapply(norm, function(e) as.numeric(e$decided_at_posix), numeric(1))
  rid <- vapply(norm, function(e) {
    if (is.null(e$record_id)) "" else e$record_id
  }, character(1))
  ord <- order(ts, rid)
  norm <- norm[ord]

  states <- vapply(norm, function(e) e$decision_state, character(1))
  n_changes <- if (length(states) <= 1L) {
    0L
  } else {
    as.integer(sum(states[-1L] != states[-length(states)]))
  }

  phases <- unique(na.omit(vapply(norm, function(e) {
    if (is.null(e$study_phase)) NA_character_ else e$study_phase
  }, character(1))))
  cutoffs <- unique(na.omit(vapply(norm, function(e) {
    if (is.null(e$data_cutoff)) NA_character_ else e$data_cutoff
  }, character(1))))

  event_out <- lapply(norm, function(e) {
    list(
      case_id = e$case_id,
      decision_state = e$decision_state,
      decided_at_jst = e$decided_at_jst,
      study_phase = e$study_phase,
      data_cutoff = e$data_cutoff,
      record_id = e$record_id,
      actor_id = e$actor_id
    )
  })

  list(
    schema_version = DECISION_TRAJECTORY_SCHEMA_VERSION,
    case_id = case_ids[[1L]],
    n_events = length(event_out),
    n_changes = n_changes,
    trajectory = as.character(states),
    study_phases = as.character(phases),
    data_cutoffs = as.character(cutoffs),
    events = event_out,
    exploratory_only = TRUE,
    decision_rule = FALSE,
    wording = paste(
      "Trajectory records longitudinal decision changes across study phases",
      "or data cutoffs; it does not prescribe a regulatory decision."
    )
  )
}

#' Derive trajectory events from ledger records plus case/phase metadata (13.12).
#'
#' @param ledger list of decision-ledger-record-v1 objects
#' @param case_id case identifier shared by all derived events
#' @param study_phases optional character vector length = length(ledger)
#' @param data_cutoffs optional character vector length = length(ledger)
#' @return decision-trajectory-v1 via build_decision_trajectory()
trajectory_from_ledger <- function(ledger,
                                   case_id,
                                   study_phases = NULL,
                                   data_cutoffs = NULL) {
  if (!is.list(ledger) || length(ledger) < 1L) {
    stop("[EMPTY_TRAJECTORY] ledger must contain at least one record")
  }
  if (!exists("verify_decision_ledger", mode = "function")) {
    stop(
      "[MISSING_LEDGER_VERIFIER] source .agents/shared/evidence_ledger.R ",
      "before trajectory_from_ledger()"
    )
  }
  verify_decision_ledger(ledger)
  n <- length(ledger)
  if (!is.null(study_phases) && length(study_phases) != n) {
    stop("[INVALID_TRAJECTORY_EVENT] study_phases length must equal ledger length")
  }
  if (!is.null(data_cutoffs) && length(data_cutoffs) != n) {
    stop("[INVALID_TRAJECTORY_EVENT] data_cutoffs length must equal ledger length")
  }
  events <- vector("list", n)
  for (i in seq_len(n)) {
    rec <- ledger[[i]]
    events[[i]] <- list(
      case_id = case_id,
      decision_state = rec$decision_state,
      decided_at_jst = rec$decided_at_jst,
      study_phase = if (is.null(study_phases)) NULL else study_phases[[i]],
      data_cutoff = if (is.null(data_cutoffs)) NULL else data_cutoffs[[i]],
      record_id = rec$record_id,
      actor_id = rec$actor_id
    )
  }
  build_decision_trajectory(events)
}
