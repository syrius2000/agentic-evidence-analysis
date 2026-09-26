# .agents/shared/evidence_ledger.R
# Append-only tamper-evident decision ledger (Section 13.9)

DECISION_LEDGER_RECORD_SCHEMA_VERSION <- "decision-ledger-record-v1"

LEDGER_HASH_FIELDS <- c(
  "schema_version",
  "record_id",
  "previous_record_sha256",
  "evidence_profile_sha256",
  "decision_state",
  "reviewer_justification_md",
  "actor_id",
  "decided_at_jst"
)

LEDGER_RECORD_FIELDS <- c(LEDGER_HASH_FIELDS, "record_sha256")

# Canonical: YYYY-MM-DD HH:MM:SS JST
DECISION_LEDGER_JST_PATTERN <- "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} JST$"

.is_sha256_hex <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) &&
    grepl("^[a-f0-9]{64}$", x)
}

.require_nonempty_string <- function(x, field) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop("[INVALID_LEDGER_RECORD] ", field, " must be a non-empty string")
  }
  trimws(x)
}

#' Validate and normalize decided_at_jst to YYYY-MM-DD HH:MM:SS JST.
assert_decided_at_jst <- function(x) {
  s <- .require_nonempty_string(x, "decided_at_jst")
  if (!grepl(DECISION_LEDGER_JST_PATTERN, s)) {
    stop(
      "[INVALID_LEDGER_RECORD] decided_at_jst must match ",
      "'YYYY-MM-DD HH:MM:SS JST'"
    )
  }
  core <- sub(" JST$", "", s)
  parsed <- as.POSIXct(core, format = "%Y-%m-%d %H:%M:%S", tz = "Asia/Tokyo")
  if (length(parsed) != 1L || is.na(parsed)) {
    stop("[INVALID_LEDGER_RECORD] decided_at_jst is not a valid calendar datetime")
  }
  roundtrip <- format(parsed, "%Y-%m-%d %H:%M:%S JST", tz = "Asia/Tokyo")
  if (!identical(roundtrip, s)) {
    stop("[INVALID_LEDGER_RECORD] decided_at_jst failed JST round-trip normalization")
  }
  s
}

#' Reject missing/extra/unnamed/duplicate field names (13.9.R1).
assert_ledger_record_shape <- function(record) {
  if (!is.list(record)) {
    stop("[INVALID_LEDGER_RECORD] record must be a named list")
  }
  nms <- names(record)
  if (is.null(nms) || any(!nzchar(nms)) || anyNA(nms)) {
    stop("[INVALID_LEDGER_RECORD] record fields must be fully named")
  }
  if (anyDuplicated(nms)) {
    stop(
      "[INVALID_LEDGER_RECORD] duplicate field names: ",
      paste(unique(nms[duplicated(nms)]), collapse = ", ")
    )
  }
  missing <- setdiff(LEDGER_RECORD_FIELDS, nms)
  extra <- setdiff(nms, LEDGER_RECORD_FIELDS)
  if (length(missing) > 0L || length(extra) > 0L) {
    stop(
      "[INVALID_LEDGER_RECORD] exact field set required; missing=[",
      paste(missing, collapse = ", "), "] extra=[",
      paste(extra, collapse = ", "), "]"
    )
  }
  invisible(TRUE)
}

#' Canonical SHA-256 over ledger payload fields (excludes record_sha256).
hash_decision_ledger_payload <- function(payload) {
  ordered <- list()
  for (nm in LEDGER_HASH_FIELDS) {
    ordered[[nm]] <- payload[[nm]]
  }
  digest::digest(
    jsonlite::toJSON(ordered, auto_unbox = TRUE, null = "null", digits = NA),
    algo = "sha256",
    serialize = FALSE
  )
}

#' Validate a single decision ledger record (structure + self-hash).
assert_decision_ledger_record <- function(record, expect_genesis = NULL) {
  assert_ledger_record_shape(record)
  if (!identical(as.character(record$schema_version), DECISION_LEDGER_RECORD_SCHEMA_VERSION)) {
    stop(
      "[INVALID_LEDGER_RECORD] schema_version must be ",
      DECISION_LEDGER_RECORD_SCHEMA_VERSION
    )
  }
  record_id <- .require_nonempty_string(record$record_id, "record_id")
  prev <- record$previous_record_sha256
  if (!is.null(prev) && !.is_sha256_hex(prev)) {
    stop("[INVALID_LEDGER_RECORD] previous_record_sha256 must be null or 64 lowercase hex")
  }
  if (isTRUE(expect_genesis) && !is.null(prev)) {
    stop("[INVALID_LEDGER_CHAIN] genesis record requires previous_record_sha256 = null")
  }
  if (isFALSE(expect_genesis) && is.null(prev)) {
    stop("[INVALID_LEDGER_CHAIN] non-genesis record requires previous_record_sha256")
  }
  evidence_profile_sha256 <- record$evidence_profile_sha256
  if (!.is_sha256_hex(evidence_profile_sha256)) {
    stop("[INVALID_LEDGER_RECORD] evidence_profile_sha256 must be 64 lowercase hex")
  }
  decision_state <- .require_nonempty_string(record$decision_state, "decision_state")
  if (is.null(record$reviewer_justification_md) ||
    !is.character(record$reviewer_justification_md) ||
    length(record$reviewer_justification_md) != 1L ||
    is.na(record$reviewer_justification_md)) {
    stop("[INVALID_LEDGER_RECORD] reviewer_justification_md must be a string")
  }
  actor_id <- .require_nonempty_string(record$actor_id, "actor_id")
  decided_at_jst <- assert_decided_at_jst(record$decided_at_jst)
  if (!.is_sha256_hex(record$record_sha256)) {
    stop("[INVALID_LEDGER_RECORD] record_sha256 must be 64 lowercase hex")
  }

  normalized <- list(
    schema_version = DECISION_LEDGER_RECORD_SCHEMA_VERSION,
    record_id = record_id,
    previous_record_sha256 = prev,
    evidence_profile_sha256 = evidence_profile_sha256,
    decision_state = decision_state,
    reviewer_justification_md = as.character(record$reviewer_justification_md),
    actor_id = actor_id,
    decided_at_jst = decided_at_jst,
    record_sha256 = as.character(record$record_sha256)
  )
  expected <- hash_decision_ledger_payload(normalized)
  if (!identical(normalized$record_sha256, expected)) {
    stop(
      "[LEDGER_HASH_MISMATCH] record_sha256 does not match payload: ",
      normalized$record_id
    )
  }
  normalized
}

#' Construct a validated ledger record (computes record_sha256).
make_decision_ledger_record <- function(record_id,
                                        previous_record_sha256,
                                        evidence_profile_sha256,
                                        decision_state,
                                        reviewer_justification_md,
                                        actor_id,
                                        decided_at_jst = format(
                                          Sys.time(), "%Y-%m-%d %H:%M:%S JST",
                                          tz = "Asia/Tokyo"
                                        )) {
  payload <- list(
    schema_version = DECISION_LEDGER_RECORD_SCHEMA_VERSION,
    record_id = record_id,
    previous_record_sha256 = previous_record_sha256,
    evidence_profile_sha256 = evidence_profile_sha256,
    decision_state = decision_state,
    reviewer_justification_md = reviewer_justification_md,
    actor_id = actor_id,
    decided_at_jst = decided_at_jst
  )
  payload$record_sha256 <- hash_decision_ledger_payload(payload)
  assert_decision_ledger_record(
    payload,
    expect_genesis = is.null(previous_record_sha256)
  )
}

#' Append a new decision record to an existing ledger (append-only).
append_decision_ledger_record <- function(ledger = list(),
                                          record_id,
                                          evidence_profile_sha256,
                                          decision_state,
                                          reviewer_justification_md,
                                          actor_id,
                                          decided_at_jst = format(
                                            Sys.time(), "%Y-%m-%d %H:%M:%S JST",
                                            tz = "Asia/Tokyo"
                                          )) {
  if (!is.list(ledger)) {
    stop("[INVALID_LEDGER] ledger must be a list of records")
  }
  if (length(ledger) > 0L) {
    verify_decision_ledger(ledger)
    tip <- ledger[[length(ledger)]]
    prev_hash <- tip$record_sha256
  } else {
    prev_hash <- NULL
  }
  if (length(ledger) > 0L) {
    existing_ids <- vapply(ledger, function(r) r$record_id, character(1))
    if (record_id %in% existing_ids) {
      stop("[DUPLICATE_LEDGER_RECORD_ID] record_id already present: ", record_id)
    }
  }
  new_rec <- make_decision_ledger_record(
    record_id = record_id,
    previous_record_sha256 = prev_hash,
    evidence_profile_sha256 = evidence_profile_sha256,
    decision_state = decision_state,
    reviewer_justification_md = reviewer_justification_md,
    actor_id = actor_id,
    decided_at_jst = decided_at_jst
  )
  c(ledger, list(new_rec))
}

#' Verify append-only chain integrity for a ledger.
verify_decision_ledger <- function(ledger) {
  if (!is.list(ledger) || length(ledger) < 1L) {
    stop("[EMPTY_LEDGER] ledger must contain at least one record")
  }
  ids <- character(length(ledger))
  for (i in seq_along(ledger)) {
    rec <- assert_decision_ledger_record(ledger[[i]], expect_genesis = (i == 1L))
    ids[[i]] <- rec$record_id
    if (i > 1L) {
      prev <- ledger[[i - 1L]]
      if (!identical(rec$previous_record_sha256, prev$record_sha256)) {
        stop(
          "[INVALID_LEDGER_CHAIN] previous_record_sha256 mismatch at record_id=",
          rec$record_id
        )
      }
    }
  }
  if (anyDuplicated(ids)) {
    stop("[DUPLICATE_LEDGER_RECORD_ID] record_id values must be unique in ledger")
  }
  invisible(TRUE)
}
