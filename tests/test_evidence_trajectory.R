# tests/test_evidence_trajectory.R — Section 13.12

test_pass <- 0L
test_fail <- 0L

assert_true <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("[PASS] %s\n", msg))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", msg))
    test_fail <<- test_fail + 1L
  }
}

assert_error_code <- function(expr, expected_code, msg) {
  err <- tryCatch(
    {
      expr
      NULL
    },
    error = function(e) e$message
  )
  if (!is.null(err) && grepl(expected_code, err, fixed = TRUE)) {
    cat(sprintf("[PASS] %s (intercepted %s)\n", msg, expected_code))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s (expected %s, got: %s)\n", msg, expected_code, as.character(err)))
    test_fail <<- test_fail + 1L
  }
}

validate_payload_against_schema <- function(payload, schema_name, schema_dir = "schemas") {
  schema_path <- file.path(schema_dir, schema_name)
  if (!file.exists(schema_path)) stop("Schema not found: ", schema_path)
  json_str <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA)
  data <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)
  root_schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
  errors <- character()

  check_node <- function(val, sc, path) {
    if (!is.null(sc[["allOf"]])) {
      for (sub in sc[["allOf"]]) check_node(val, sub, path)
    }
    allowed_types <- sc[["type"]]
    if (!is.null(allowed_types)) {
      if (is.null(val)) {
        if (!"null" %in% allowed_types) errors <<- c(errors, sprintf("%s: unexpected null", path))
        return()
      }
      matched <- FALSE
      for (at in allowed_types) {
        if (at == "object" && is.list(val) && (length(val) == 0 || !is.null(names(val)))) matched <- TRUE
        if (at == "array" && is.list(val) && (length(val) == 0 || is.null(names(val)))) matched <- TRUE
        if (at == "string" && is.character(val) && length(val) == 1) matched <- TRUE
        if (at == "integer" && is.numeric(val) && length(val) == 1 && !is.na(val) && val == as.integer(val)) matched <- TRUE
        if (at == "number" && is.numeric(val) && length(val) == 1 && !is.na(val)) matched <- TRUE
        if (at == "boolean" && is.logical(val) && length(val) == 1 && !is.na(val)) matched <- TRUE
      }
      if (!matched) {
        errors <<- c(errors, sprintf("%s: type mismatch", path))
        return()
      }
    }
    if (!is.null(sc[["const"]]) && !identical(val, sc[["const"]])) {
      errors <<- c(errors, sprintf("%s: const mismatch", path))
    }
    if (!is.null(sc[["pattern"]]) && is.character(val) && length(val) == 1L &&
      !grepl(sc[["pattern"]], val)) {
      errors <<- c(errors, sprintf("%s: pattern", path))
    }
    if (is.list(val) && (length(val) == 0 || !is.null(names(val)))) {
      if (!is.null(sc[["required"]])) {
        for (req in sc[["required"]]) {
          if (!req %in% names(val)) errors <<- c(errors, sprintf("%s: missing %s", path, req))
        }
      }
      props <- sc[["properties"]]
      if (!is.null(props)) {
        for (pname in intersect(names(props), names(val))) {
          check_node(val[[pname]], props[[pname]], paste0(path, ".", pname))
        }
      }
      if (identical(sc[["additionalProperties"]], FALSE)) {
        extra <- setdiff(names(val), names(props))
        if (length(extra)) errors <<- c(errors, sprintf("%s: additional %s", path, paste(extra, collapse = ",")))
      }
    } else if (is.list(val) && is.null(names(val))) {
      items <- sc[["items"]]
      if (!is.null(items)) {
        for (i in seq_along(val)) check_node(val[[i]], items, paste0(path, "[", i, "]"))
      }
    }
  }

  check_node(data, root_schema, "$")
  list(valid = length(errors) == 0L, errors = errors)
}

source(".agents/shared/evidence_ledger.R")
source(".agents/shared/evidence_trajectory.R")

sha <- function(x) digest::digest(x, algo = "sha256", serialize = FALSE)

cat("=== 13.12 build_decision_trajectory ===\n")
events <- list(
  list(
    case_id = "CASE-1",
    decision_state = "HOLD",
    decided_at_jst = "2026-01-10 10:00:00 JST",
    study_phase = "interim",
    data_cutoff = "2025-12-31",
    record_id = "r2",
    actor_id = "revA"
  ),
  list(
    case_id = "CASE-1",
    decision_state = "ACCEPT",
    decided_at_jst = "2026-01-01 09:00:00 JST",
    study_phase = "screening",
    data_cutoff = "2025-11-30",
    record_id = "r1",
    actor_id = "revA"
  ),
  list(
    case_id = "CASE-1",
    decision_state = "ACCEPT",
    decided_at_jst = "2026-02-01 11:00:00 JST",
    study_phase = "final",
    data_cutoff = "2026-01-31",
    record_id = "r3",
    actor_id = "revB"
  )
)

tr <- build_decision_trajectory(events)
assert_true(identical(tr$case_id, "CASE-1"), "case_id preserved")
assert_true(identical(tr$n_events, 3L), "n_events = 3")
assert_true(
  identical(tr$trajectory, c("ACCEPT", "HOLD", "ACCEPT")),
  "Sorted by decided_at_jst"
)
assert_true(identical(tr$n_changes, 2L), "n_changes counts state transitions")
assert_true(
  identical(sort(tr$study_phases), c("final", "interim", "screening")),
  "study_phases collected"
)
assert_true(length(tr$data_cutoffs) == 3L, "data_cutoffs collected")
assert_true(isTRUE(tr$exploratory_only) && isFALSE(tr$decision_rule), "Governance flags")

schema_tr <- validate_payload_against_schema(tr, "decision-trajectory-v1.json")
assert_true(isTRUE(schema_tr$valid), paste("Schema:", paste(schema_tr$errors, collapse = "; ")))

cat("=== 13.12 Fail-Fast ===\n")
assert_error_code(
  build_decision_trajectory(list()),
  "EMPTY_TRAJECTORY",
  "Empty events rejected"
)
assert_error_code(
  build_decision_trajectory(list(
    list(case_id = "A", decision_state = "X", decided_at_jst = "2026-01-01 00:00:00 JST"),
    list(case_id = "B", decision_state = "Y", decided_at_jst = "2026-01-02 00:00:00 JST")
  )),
  "TRAJECTORY_CASE_MISMATCH",
  "Mixed case_id rejected"
)
assert_error_code(
  build_decision_trajectory(list(
    list(case_id = "A", decision_state = "X", decided_at_jst = "not-a-date")
  )),
  "INVALID_TRAJECTORY_EVENT",
  "Bad timestamp rejected"
)

cat("=== 13.12 trajectory_from_ledger ===\n")
ev_hash <- sha("evidence-profile-1")
led <- list()
led <- append_decision_ledger_record(
  led, "L1", ev_hash, "HOLD", "first look", "revA",
  decided_at_jst = "2026-03-01 09:00:00 JST"
)
led <- append_decision_ledger_record(
  led, "L2", ev_hash, "ACCEPT", "updated", "revA",
  decided_at_jst = "2026-04-01 09:00:00 JST"
)
tr2 <- trajectory_from_ledger(
  led,
  case_id = "CASE-LEDGER",
  study_phases = c("phase1", "phase2"),
  data_cutoffs = c("2026-02-28", "2026-03-31")
)
assert_true(identical(tr2$trajectory, c("HOLD", "ACCEPT")), "Ledger-derived trajectory")
assert_true(identical(tr2$n_changes, 1L), "One change from ledger")
assert_true(identical(tr2$events[[1]]$record_id, "L1"), "Ledger record_id linked")

schema_tr2 <- validate_payload_against_schema(tr2, "decision-trajectory-v1.json")
assert_true(isTRUE(schema_tr2$valid), paste("Ledger trajectory schema:", paste(schema_tr2$errors, collapse = "; ")))

cat("=== 13.12.R1 ledger verify before trajectory ===\n")
tampered <- led
tampered[[2]]$decision_state <- "TAMPERED"
assert_error_code(
  trajectory_from_ledger(tampered, case_id = "CASE-LEDGER"),
  "LEDGER_HASH_MISMATCH",
  "Tampered decision_state rejected"
)
broken2 <- led
broken2[[2]]$previous_record_sha256 <- paste(rep("b", 64), collapse = "")
assert_error_code(
  trajectory_from_ledger(broken2, case_id = "CASE-LEDGER"),
  "LEDGER_HASH_MISMATCH",
  "Broken previous hash (stale self-hash) rejected"
)
dup <- led
dup[[2]]$record_id <- "L1"
assert_error_code(
  trajectory_from_ledger(dup, case_id = "CASE-LEDGER"),
  "LEDGER_HASH_MISMATCH",
  "Mutated duplicate-id ledger rejected via verifier"
)

cat(sprintf("\nSummary: %d PASS / %d FAIL\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
