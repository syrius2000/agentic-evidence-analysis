# tests/test_evidence_ledger.R — Section 13.9

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
    if (!is.null(sc[["minLength"]]) && is.character(val) && length(val) == 1L &&
      nchar(val, type = "chars") < as.integer(sc[["minLength"]])) {
      errors <<- c(errors, sprintf("%s: minLength", path))
    }
    if (!is.null(sc[["maxLength"]]) && is.character(val) && length(val) == 1L &&
      nchar(val, type = "chars") > as.integer(sc[["maxLength"]])) {
      errors <<- c(errors, sprintf("%s: maxLength", path))
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
    }
  }

  check_node(data, root_schema, "$")
  list(valid = length(errors) == 0L, errors = errors)
}

source(".agents/shared/evidence_ledger.R")

fake_profile_sha <- digest::digest("evidence-profile-fixture-a", algo = "sha256", serialize = FALSE)
fake_profile_sha_b <- digest::digest("evidence-profile-fixture-b", algo = "sha256", serialize = FALSE)

cat("=== 13.9 Ledger record + chain ===\n")
ledger <- append_decision_ledger_record(
  list(),
  record_id = "R1",
  evidence_profile_sha256 = fake_profile_sha,
  decision_state = "monitor",
  reviewer_justification_md = "Initial review",
  actor_id = "reviewer.a",
  decided_at_jst = "2026-09-25 09:18:00 JST"
)
assert_true(length(ledger) == 1L, "Genesis append yields one record")
assert_true(is.null(ledger[[1L]]$previous_record_sha256), "Genesis previous_hash is null")
assert_true(
  grepl("^[a-f0-9]{64}$", ledger[[1L]]$record_sha256),
  "Genesis record_sha256 is 64 hex"
)
assert_true(
  validate_payload_against_schema(ledger[[1L]], "decision-ledger-record-v1.json")$valid,
  "Genesis record validates against Draft-07 schema"
)
assert_true(isTRUE(verify_decision_ledger(ledger)), "Single-record chain verifies")

ledger <- append_decision_ledger_record(
  ledger,
  record_id = "R2",
  evidence_profile_sha256 = fake_profile_sha_b,
  decision_state = "investigate",
  reviewer_justification_md = "Updated after new cut",
  actor_id = "reviewer.b",
  decided_at_jst = "2026-09-25 09:20:00 JST"
)
assert_true(length(ledger) == 2L, "Second append grows ledger")
assert_true(
  identical(ledger[[2L]]$previous_record_sha256, ledger[[1L]]$record_sha256),
  "Second record links to first record_sha256"
)
assert_true(isTRUE(verify_decision_ledger(ledger)), "Two-record chain verifies")
assert_true(
  validate_payload_against_schema(ledger[[2L]], "decision-ledger-record-v1.json")$valid,
  "Second record validates against Draft-07 schema"
)

# Tamper detection: mutate justification without rehash
broken <- ledger
broken[[2L]]$reviewer_justification_md <- "tampered"
assert_error_code(
  verify_decision_ledger(broken),
  "LEDGER_HASH_MISMATCH",
  "Payload tamper Fail-Fast"
)

# Broken chain link
broken_link <- ledger
broken_link[[2L]]$previous_record_sha256 <- paste(rep("a", 64), collapse = "")
broken_link[[2L]]$record_sha256 <- hash_decision_ledger_payload(broken_link[[2L]])
assert_error_code(
  verify_decision_ledger(broken_link),
  "INVALID_LEDGER_CHAIN",
  "Broken previous-hash link Fail-Fast"
)

assert_error_code(
  append_decision_ledger_record(
    ledger,
    record_id = "R1",
    evidence_profile_sha256 = fake_profile_sha,
    decision_state = "monitor",
    reviewer_justification_md = "dup",
    actor_id = "a",
    decided_at_jst = "2026-09-25 09:21:00 JST"
  ),
  "DUPLICATE_LEDGER_RECORD_ID",
  "Duplicate record_id Fail-Fast"
)

assert_error_code(
  make_decision_ledger_record(
    record_id = "bad",
    previous_record_sha256 = NULL,
    evidence_profile_sha256 = "not-a-hash",
    decision_state = "monitor",
    reviewer_justification_md = "x",
    actor_id = "a",
    decided_at_jst = "2026-09-25 09:18:00 JST"
  ),
  "INVALID_LEDGER_RECORD",
  "Rejects non-sha256 evidence_profile_sha256"
)

assert_error_code(
  verify_decision_ledger(list()),
  "EMPTY_LEDGER",
  "Empty ledger Fail-Fast"
)

# Append-only: original tip unchanged after append
tip_before <- ledger[[1L]]$record_sha256
ledger3 <- append_decision_ledger_record(
  ledger,
  record_id = "R3",
  evidence_profile_sha256 = fake_profile_sha,
  decision_state = "monitor",
  reviewer_justification_md = "third",
  actor_id = "reviewer.a",
  decided_at_jst = "2026-09-25 09:22:00 JST"
)
assert_true(
  identical(ledger[[1L]]$record_sha256, tip_before) &&
    identical(ledger3[[1L]]$record_sha256, tip_before) &&
    length(ledger) == 2L && length(ledger3) == 3L,
  "Append does not rewrite prior records"
)

cat("=== 13.9.R1 Exact field set ===\n")
extra_field <- ledger[[1L]]
extra_field$override_note <- "modified after approval"
assert_error_code(
  assert_decision_ledger_record(extra_field, expect_genesis = TRUE),
  "INVALID_LEDGER_RECORD",
  "Runtime rejects unknown extra field"
)
assert_true(
  !validate_payload_against_schema(extra_field, "decision-ledger-record-v1.json")$valid,
  "Draft-07 rejects unknown extra field"
)
assert_error_code(
  verify_decision_ledger(list(extra_field)),
  "INVALID_LEDGER_RECORD",
  "Extra-field mutation cannot pass chain verification"
)

missing_field <- ledger[[1L]]
missing_field$actor_id <- NULL
# remove name entirely
missing_field <- missing_field[names(missing_field) != "actor_id"]
assert_error_code(
  assert_decision_ledger_record(missing_field, expect_genesis = TRUE),
  "INVALID_LEDGER_RECORD",
  "Runtime rejects missing canonical field"
)

dup_names <- ledger[[1L]]
dup_names <- c(dup_names, list(decision_state = "escalate"))
assert_error_code(
  assert_decision_ledger_record(dup_names, expect_genesis = TRUE),
  "INVALID_LEDGER_RECORD",
  "Runtime rejects duplicate field names"
)

unnamed <- ledger[[1L]]
names(unnamed)[1L] <- ""
assert_error_code(
  assert_decision_ledger_record(unnamed, expect_genesis = TRUE),
  "INVALID_LEDGER_RECORD",
  "Runtime rejects unnamed fields"
)

cat("=== 13.9.R2 Canonical JST timestamp ===\n")
assert_true(
  identical(
    assert_decided_at_jst("2026-09-25 09:18:00 JST"),
    "2026-09-25 09:18:00 JST"
  ),
  "Canonical JST timestamp accepted"
)

assert_error_code(
  make_decision_ledger_record(
    record_id = "ts1",
    previous_record_sha256 = NULL,
    evidence_profile_sha256 = fake_profile_sha,
    decision_state = "monitor",
    reviewer_justification_md = "x",
    actor_id = "a",
    decided_at_jst = "2026-09-25 00:20:00 UTC"
  ),
  "INVALID_LEDGER_RECORD",
  "Rejects UTC suffix"
)

assert_error_code(
  make_decision_ledger_record(
    record_id = "ts2",
    previous_record_sha256 = NULL,
    evidence_profile_sha256 = fake_profile_sha,
    decision_state = "monitor",
    reviewer_justification_md = "x",
    actor_id = "a",
    decided_at_jst = "2026-09-25 09:18:00"
  ),
  "INVALID_LEDGER_RECORD",
  "Rejects missing JST suffix"
)

assert_error_code(
  make_decision_ledger_record(
    record_id = "ts3",
    previous_record_sha256 = NULL,
    evidence_profile_sha256 = fake_profile_sha,
    decision_state = "monitor",
    reviewer_justification_md = "x",
    actor_id = "a",
    decided_at_jst = "2026-13-40 99:99:99 JST"
  ),
  "INVALID_LEDGER_RECORD",
  "Rejects malformed calendar datetime"
)

bad_ts_schema <- ledger[[1L]]
bad_ts_schema$decided_at_jst <- "banana"
bad_ts_schema$record_sha256 <- hash_decision_ledger_payload(bad_ts_schema)
assert_true(
  !validate_payload_against_schema(bad_ts_schema, "decision-ledger-record-v1.json")$valid,
  "Draft-07 rejects non-JST decided_at_jst"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
