# tests/test_evidence_discordance.R — Section 13.10 / 13.11

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
    if (!is.null(sc[["oneOf"]])) {
      ok_any <- FALSE
      for (sub in sc[["oneOf"]]) {
        before <- length(errors)
        check_node(val, sub, path)
        if (length(errors) == before) {
          ok_any <- TRUE
          break
        }
        errors <<- errors[seq_len(before)]
      }
      if (!ok_any) errors <<- c(errors, sprintf("%s: oneOf mismatch", path))
      return()
    }
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
    if (!is.null(sc[["enum"]]) && !any(vapply(sc[["enum"]], function(e) identical(val, e), logical(1)))) {
      errors <<- c(errors, sprintf("%s: enum mismatch", path))
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

source(".agents/shared/evidence_discordance.R")

hit <- function(id, dist, state) {
  list(
    case_id = id,
    gower_distance = dist,
    decision_context = list(decision_state = state)
  )
}

nb <- list(
  hit("c1", 0.10, "ACCEPT"),
  hit("c2", 0.20, "ACCEPT"),
  hit("c3", 0.30, "ACCEPT"),
  hit("c4", 0.40, "HOLD"),
  hit("c5", 0.50, "HOLD")
)

cat("=== 13.10 k_neighbors discordance ===\n")
adv <- evaluate_discordance_advisory(
  "HOLD", nb,
  policy = "k_neighbors", k = 3L
)
assert_true(isTRUE(adv$is_qa_review_candidate), "HOLD vs ACCEPT majority => candidate")
assert_true(identical(adv$advisory_flag, "QA Review Candidate"), "Flag is QA Review Candidate")
assert_true(identical(adv$severity, "advisory"), "Severity is advisory")
assert_true(isFALSE(adv$halts_workflow), "Does not halt workflow")
assert_true(identical(adv$dominant_state, "ACCEPT"), "Dominant state ACCEPT")
assert_true(identical(adv$n_neighborhood, 3L), "k=3 neighborhood size")

ok <- evaluate_discordance_advisory(
  "ACCEPT", nb,
  policy = "k_neighbors", k = 3L
)
assert_true(isFALSE(ok$is_qa_review_candidate), "Concordant provisional is not candidate")
assert_true(is.null(ok$advisory_flag) && is.null(ok$severity), "No flag/severity when concordant")

cat("=== 13.10 distance_radius policy ===\n")
rad <- evaluate_discordance_advisory(
  "HOLD", nb,
  policy = "distance_radius", radius = 0.25
)
assert_true(identical(rad$n_neighborhood, 2L), "radius 0.25 keeps two hits")
assert_true(isTRUE(rad$is_qa_review_candidate), "Radius policy flags discordance")

assert_error_code(
  evaluate_discordance_advisory("HOLD", nb, policy = "distance_radius", radius = 0.05),
  "EMPTY_DISCORDANCE_NEIGHBORHOOD",
  "Empty radius neighborhood fails fast"
)

cat("=== 13.10 tie => no advisory ===\n")
tie_nb <- list(
  hit("a", 0.1, "ACCEPT"),
  hit("b", 0.2, "HOLD")
)
tie <- evaluate_discordance_advisory("ACCEPT", tie_nb, policy = "k_neighbors", k = 2L)
assert_true(isTRUE(tie$tie), "Tie detected")
assert_true(isFALSE(tie$is_qa_review_candidate), "Tie does not raise candidate")
assert_true(is.null(tie$dominant_state), "Tie clears dominant_state")

cat("=== 13.10 policy validation ===\n")
assert_error_code(
  evaluate_discordance_advisory("A", nb, policy = "k_neighbors", k = 3L, radius = 0.1),
  "INVALID_DISCORDANCE_POLICY",
  "Reject radius with k_neighbors"
)
assert_error_code(
  evaluate_discordance_advisory("A", nb, policy = "distance_radius", k = 2L, radius = 0.1),
  "INVALID_DISCORDANCE_POLICY",
  "Reject k with distance_radius"
)
assert_error_code(
  evaluate_discordance_advisory("A", nb, policy = "magic", k = 2L),
  "INVALID_DISCORDANCE_POLICY",
  "Reject unknown policy"
)

cat("=== 13.11 wording contract / string audit ===\n")
assert_true(
  grepl("QA Review Candidate", adv$wording, fixed = TRUE),
  "Wording names QA Review Candidate"
)
assert_error_code(
  assert_discordance_wording_contract(list(
    wording = "QA Review Candidate but this is a fatal system error",
    is_qa_review_candidate = FALSE,
    halts_workflow = FALSE
  )),
  "DISCORDANCE_WORDING_VIOLATION",
  "Forbidden fatal/error wording rejected"
)
assert_error_code(
  assert_discordance_wording_contract(list(
    wording = "QA Review Candidate",
    is_qa_review_candidate = TRUE,
    advisory_flag = "QA Review Candidate",
    severity = "error",
    halts_workflow = FALSE
  )),
  "DISCORDANCE_WORDING_VIOLATION",
  "severity=error rejected"
)

cat("=== 13.10.R1 / 13.11.R1 decision labels not scanned ===\n")
rej_nb <- list(
  hit("c1", 0.10, "ACCEPT"),
  hit("c2", 0.20, "ACCEPT"),
  hit("c3", 0.30, "ACCEPT")
)
rej_adv <- evaluate_discordance_advisory(
  "REJECT", rej_nb,
  policy = "k_neighbors", k = 3L
)
assert_true(isTRUE(rej_adv$is_qa_review_candidate), "REJECT vs ACCEPT => candidate")
assert_true(identical(rej_adv$advisory_flag, "QA Review Candidate"), "REJECT provisional keeps advisory flag")

rej_dom <- list(
  hit("c1", 0.10, "REJECTED"),
  hit("c2", 0.20, "REJECTED"),
  hit("c3", 0.30, "REJECTED")
)
rej_dom_adv <- evaluate_discordance_advisory(
  "ACCEPT", rej_dom,
  policy = "k_neighbors", k = 3L
)
assert_true(isTRUE(rej_dom_adv$is_qa_review_candidate), "ACCEPT vs REJECTED => candidate")
assert_true(identical(rej_dom_adv$dominant_state, "REJECTED"), "REJECTED dominant preserved")

schema_ok <- validate_payload_against_schema(adv, "discordance-advisory-v1.json")
assert_true(isTRUE(schema_ok$valid), paste("Schema valid candidate:", paste(schema_ok$errors, collapse = "; ")))
schema_ok2 <- validate_payload_against_schema(ok, "discordance-advisory-v1.json")
assert_true(isTRUE(schema_ok2$valid), paste("Schema valid concordant:", paste(schema_ok2$errors, collapse = "; ")))
schema_rej <- validate_payload_against_schema(rej_adv, "discordance-advisory-v1.json")
assert_true(isTRUE(schema_rej$valid), paste("Schema valid REJECT provisional:", paste(schema_rej$errors, collapse = "; ")))

# Divergence must not throw
threw <- tryCatch(
  {
    evaluate_discordance_advisory("HOLD", nb, policy = "k_neighbors", k = 3L)
    FALSE
  },
  error = function(e) TRUE
)
assert_true(isFALSE(threw), "Discordance does not throw on divergence")

cat(sprintf("\nSummary: %d PASS / %d FAIL\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
