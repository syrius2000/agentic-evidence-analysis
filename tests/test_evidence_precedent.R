# tests/test_evidence_precedent.R — Section 13.7 / 13.8 (+ 13.7.R1 / 13.8.R1)

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
  load_schema <- function(name) jsonlite::fromJSON(file.path(schema_dir, name), simplifyVector = FALSE)
  root_schema <- load_schema(schema_name)
  errors <- character()

  check_node <- function(val, sc, path) {
    if (!is.null(sc[["$ref"]])) {
      ref <- sc[["$ref"]]
      if (startsWith(ref, "#/")) {
        keys <- strsplit(sub("^#/", "", ref), "/", fixed = TRUE)[[1L]]
        ref_sc <- root_schema
        for (key in keys) ref_sc <- ref_sc[[key]]
      } else {
        ref_sc <- load_schema(ref)
      }
      check_node(val, ref_sc, path)
      return()
    }
    if (!is.null(sc[["allOf"]])) {
      for (sub in sc[["allOf"]]) check_node(val, sub, path)
    }
    if (!is.null(sc[["if"]])) {
      saved <- errors
      check_node(val, sc[["if"]], path)
      ok <- length(errors) == length(saved)
      errors <<- saved
      if (ok && !is.null(sc[["then"]])) check_node(val, sc[["then"]], path)
      if (!ok && !is.null(sc[["else"]])) check_node(val, sc[["else"]], path)
    }
    if (!is.null(sc[["not"]])) {
      not_sc <- sc[["not"]]
      if (!is.null(not_sc$anyOf) && is.list(val)) {
        for (clause in not_sc$anyOf) {
          if (!is.null(clause$required)) {
            for (req in clause$required) {
              if (req %in% names(val)) {
                errors <<- c(errors, sprintf("%s: prohibited %s", path, req))
              }
            }
          }
        }
      }
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
        if (at == "integer" && is.numeric(val) && length(val) == 1 && !is.na(val) && val == floor(val)) matched <- TRUE
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
    if (!is.null(sc[["enum"]]) && !(val %in% unlist(sc[["enum"]]))) {
      errors <<- c(errors, sprintf("%s: enum mismatch", path))
    }
    if (!is.null(sc[["minimum"]]) && is.numeric(val) && val < sc[["minimum"]]) {
      errors <<- c(errors, sprintf("%s: below minimum", path))
    }
    if (!is.null(sc[["maximum"]]) && is.numeric(val) && val > sc[["maximum"]]) {
      errors <<- c(errors, sprintf("%s: above maximum", path))
    }
    if (!is.null(sc[["exclusiveMinimum"]]) && is.numeric(val) && val <= sc[["exclusiveMinimum"]]) {
      errors <<- c(errors, sprintf("%s: not > exclusiveMinimum", path))
    }
    if (!is.null(sc[["minLength"]]) && is.character(val) && length(val) == 1L &&
      nchar(val, type = "chars") < as.integer(sc[["minLength"]])) {
      errors <<- c(errors, sprintf("%s: minLength", path))
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
    if (is.list(val) && (length(val) == 0 || is.null(names(val)))) {
      if (!is.null(sc[["minItems"]]) && length(val) < as.integer(sc[["minItems"]])) {
        errors <<- c(errors, sprintf("%s: minItems", path))
      }
      if (isTRUE(sc[["uniqueItems"]]) && anyDuplicated(unlist(val, use.names = FALSE))) {
        errors <<- c(errors, sprintf("%s: uniqueItems", path))
      }
      if (!is.null(sc[["items"]])) {
        for (i in seq_along(val)) check_node(val[[i]], sc[["items"]], paste0(path, "[", i, "]"))
      }
      if (!is.null(sc[["contains"]])) {
        saved <- errors
        found <- FALSE
        for (el in val) {
          errors <<- saved
          check_node(el, sc[["contains"]], paste0(path, ".contains"))
          if (length(errors) == length(saved)) {
            found <- TRUE
            break
          }
        }
        errors <<- saved
        if (!found) errors <<- c(errors, sprintf("%s: contains not satisfied", path))
      }
    }
  }

  check_node(data, root_schema, "$")
  list(valid = length(errors) == 0L, errors = errors)
}

source(".agents/shared/independent_beta_binomial.R")
source(".agents/shared/evidence_feature_extract.R")
source(".agents/shared/evidence_gower.R")
source(".agents/shared/evidence_precedent.R")

canonical_feat <- function(rd_estimate, schema_ver = EVIDENCE_FEATURE_SCHEMA_VERSION,
                           resolution_grade = "U0", delta_present = FALSE) {
  delta <- if (isTRUE(delta_present)) {
    list(
      present = TRUE,
      primary_delta = 0.05,
      target_excess = 0.2,
      practical_neutral = 0.5,
      reference_excess = 0.3
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
  keys <- if (isTRUE(delta_present)) {
    as.list(c(CORE_CLUSTERING_KEYS, DELTA_CLUSTERING_KEYS))
  } else {
    as.list(CORE_CLUSTERING_KEYS)
  }
  list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = schema_ver,
    source = list(
      evidence_schema_version = "comparative-evidence-v1",
      inferential_semantics = "posterior",
      contrast_id = NULL,
      theme = NULL
    ),
    core = list(
      rd_estimate = rd_estimate,
      rd_interval_width = 0.10,
      direction_support = 0.80,
      resolution_grade = resolution_grade,
      rr_mean_is_finite = TRUE,
      has_zero_reference = FALSE,
      target_n = 100,
      reference_n = 100,
      quarantine_flag_count = 0L
    ),
    delta_dependent = delta,
    clustering_feature_keys = keys
  )
}

tiny_range <- list(
  schema_version = "frozen-reference-range-v1",
  range_version = "test-1.0.0",
  feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION,
  features = list(
    rd_estimate = list(type = "numeric", min = -1.0, max = 1.0),
    resolution_grade = list(type = "categorical", levels = list("U0", "U1", "U2", "U3", "NONE"))
  )
)

base_versions <- list(
  dictionary_release_version = "MedDRA 26.1",
  delta_policy_version = "v1",
  feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION
)

make_case <- function(id, rd, decision, versions = base_versions, grade = "U0",
                      schema_ver = NULL) {
  feat_ver <- if (is.null(schema_ver)) versions$feature_schema_version else schema_ver
  make_historical_precedent_case(
    case_id = id,
    versions = versions,
    evidence_feature = canonical_feat(rd, schema_ver = feat_ver, resolution_grade = grade),
    decision_context = list(
      decision_state = decision,
      reviewer_justification_md = paste("rationale for", id),
      actor_id = "reviewer.a",
      decided_at_jst = "2026-09-25 08:00:00 JST"
    )
  )
}

cat("=== 13.7.R1 Canonical feature contract ===\n")
ok_feat <- canonical_feat(0.1)
assert_true(
  identical(assert_evidence_feature_v1(ok_feat)$schema_version, "evidence-feature-v1"),
  "assert_evidence_feature_v1 accepts canonical fixture"
)
assert_true(
  validate_payload_against_schema(ok_feat, "evidence-feature-v1.json")$valid,
  "Draft-07 accepts canonical fixture"
)

partial <- list(
  schema_version = "evidence-feature-v1",
  feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION,
  core = list(rd_estimate = 0.1, resolution_grade = "U0"),
  delta_dependent = list(present = FALSE),
  clustering_feature_keys = list("rd_estimate", "resolution_grade")
)
assert_error_code(
  assert_evidence_feature_v1(partial), "INVALID_EVIDENCE_FEATURE",
  "Rejects missing source / incomplete core"
)

missing_source <- ok_feat
missing_source$source <- NULL
assert_error_code(
  assert_evidence_feature_v1(missing_source), "INVALID_EVIDENCE_FEATURE",
  "Rejects missing source"
)

missing_core_attr <- ok_feat
missing_core_attr$core$rd_interval_width <- NULL
names(missing_core_attr$core) <- setdiff(names(missing_core_attr$core), "rd_interval_width")
assert_error_code(
  assert_evidence_feature_v1(missing_core_attr), "INVALID_EVIDENCE_FEATURE",
  "Rejects missing mandatory core attribute"
)

present_false_missing_nulls <- ok_feat
present_false_missing_nulls$delta_dependent <- list(present = FALSE)
assert_error_code(
  assert_evidence_feature_v1(present_false_missing_nulls), "INVALID_EVIDENCE_FEATURE",
  "Rejects present=false missing required null delta fields"
)

present_true_incomplete <- ok_feat
present_true_incomplete$delta_dependent <- list(
  present = TRUE, primary_delta = 0.05, target_excess = 0.2,
  practical_neutral = 0.5, reference_excess = 0.3
)
present_true_incomplete$clustering_feature_keys <- as.list(CORE_CLUSTERING_KEYS)
assert_error_code(
  assert_evidence_feature_v1(present_true_incomplete), "MISSING_DELTA_CLUSTERING_KEYS",
  "Rejects present=true incomplete delta clustering keys"
)

unknown_key <- ok_feat
unknown_key$clustering_feature_keys <- c(as.list(CORE_CLUSTERING_KEYS), list("not_a_key"))
assert_error_code(
  assert_evidence_feature_v1(unknown_key), "UNKNOWN_CLUSTERING_FEATURE_KEYS",
  "Rejects unknown clustering key"
)

forbidden_key <- ok_feat
forbidden_key$clustering_feature_keys <- list("decision_code")
assert_error_code(
  assert_evidence_feature_v1(forbidden_key), "DECISION_LABEL_IN_FEATURE_KEYS",
  "Rejects forbidden decision/regulatory clustering key"
)

cat("=== 13.7.R1b Runtime/Draft-07 parity (M13.7-02) ===\n")
present_numeric_zero <- ok_feat
present_numeric_zero$delta_dependent$present <- 0
assert_error_code(
  assert_evidence_feature_v1(present_numeric_zero), "INVALID_DELTA_DEPENDENT",
  "Runtime rejects delta.present=0"
)
assert_true(
  !validate_payload_against_schema(present_numeric_zero, "evidence-feature-v1.json")$valid,
  "Draft-07 rejects delta.present=0"
)

present_string_false <- ok_feat
present_string_false$delta_dependent$present <- "false"
assert_error_code(
  assert_evidence_feature_v1(present_string_false), "INVALID_DELTA_DEPENDENT",
  "Runtime rejects delta.present=\"false\""
)
assert_true(
  !validate_payload_against_schema(present_string_false, "evidence-feature-v1.json")$valid,
  "Draft-07 rejects delta.present=\"false\""
)

bad_contrast_id <- ok_feat
bad_contrast_id$source$contrast_id <- 123
assert_error_code(
  assert_evidence_feature_v1(bad_contrast_id), "INVALID_EVIDENCE_FEATURE",
  "Runtime rejects source.contrast_id=123"
)
assert_true(
  !validate_payload_against_schema(bad_contrast_id, "evidence-feature-v1.json")$valid,
  "Draft-07 rejects source.contrast_id=123"
)

bad_theme <- ok_feat
bad_theme$source$theme <- list("nested")
assert_error_code(
  assert_evidence_feature_v1(bad_theme), "INVALID_EVIDENCE_FEATURE",
  "Runtime rejects source.theme=list"
)
assert_true(
  !validate_payload_against_schema(bad_theme, "evidence-feature-v1.json")$valid,
  "Draft-07 rejects source.theme=list"
)

cat("=== 13.7 Version binding ===\n")
ok_case <- make_case("C1", 0.1, "monitor")
assert_true(identical(ok_case$versions$dictionary_release_version, "MedDRA 26.1"), "Dictionary release bound")
assert_true(identical(ok_case$versions$delta_policy_version, "v1"), "Delta policy version bound")
assert_true(
  identical(ok_case$versions$feature_schema_version, EVIDENCE_FEATURE_SCHEMA_VERSION),
  "Feature schema version bound"
)
assert_true(
  validate_payload_against_schema(ok_case, "historical-precedent-case-v1.json")$valid,
  "Historical precedent schema validates nested evidence-feature via $ref"
)

cmp_ok <- compare_precedent_versions(base_versions, ok_case$versions)
assert_true(isTRUE(cmp_ok$version_compatible) && length(cmp_ok$version_mismatches) == 0L, "Matching versions compatible")

other_pol <- base_versions
other_pol$delta_policy_version <- "v2"
cmp_bad <- compare_precedent_versions(base_versions, other_pol)
assert_true(
  isFALSE(cmp_bad$version_compatible) &&
    any(grepl("delta_policy_version", cmp_bad$version_mismatches, fixed = TRUE)),
  "Delta policy mismatch exposed (not silent)"
)

assert_error_code(
  assert_precedent_versions(list(dictionary_release_version = "MedDRA 26.1")),
  "MISSING_PRECEDENT_VERSIONS",
  "Missing version keys Fail-Fast"
)

bad_feat_ver <- base_versions
bad_feat_ver$feature_schema_version <- "9.9.9"
assert_error_code(
  make_historical_precedent_case(
    "X",
    bad_feat_ver,
    canonical_feat(0.2),
    list(
      decision_state = "monitor",
      reviewer_justification_md = "x",
      actor_id = "a",
      decided_at_jst = "2026-09-25 08:00:00 JST"
    )
  ),
  "PRECEDENT_FEATURE_SCHEMA_MISMATCH",
  "Case versions must match evidence_feature schema version"
)

assert_error_code(
  make_historical_precedent_case(
    "bad_partial",
    base_versions,
    partial,
    list(
      decision_state = "monitor",
      reviewer_justification_md = "x",
      actor_id = "a",
      decided_at_jst = "2026-09-25 08:00:00 JST"
    )
  ),
  "INVALID_EVIDENCE_FEATURE",
  "Historical case rejects non-canonical nested feature"
)

neg_nested <- ok_case
neg_nested$evidence_feature <- partial
assert_true(
  !validate_payload_against_schema(neg_nested, "historical-precedent-case-v1.json")$valid,
  "Draft-07 historical schema rejects nested non-canonical feature"
)

cat("=== 13.8 Nearest precedent retrieval ===\n")
library_cases <- list(
  make_case("near", 0.05, "monitor"),
  make_case("mid", 0.40, "investigate"),
  make_case("far", 0.95, "escalate")
)
query <- canonical_feat(0.06)
res <- retrieve_nearest_precedents(
  query, base_versions, library_cases, tiny_range,
  n_neighbors = 2L, keys = "rd_estimate"
)
assert_true(identical(res$method, "gower_nearest_precedents"), "Retrieval method tag")
assert_true(identical(res$n_returned, 2L), "Returns n_neighbors")
assert_true(identical(res$neighborhood[[1L]]$case_id, "near"), "Nearest case is near")
assert_true(
  res$neighborhood[[1L]]$gower_distance <= res$neighborhood[[2L]]$gower_distance,
  "Neighborhood sorted by ascending Gower distance"
)
assert_true(
  identical(res$neighborhood[[1L]]$decision_context$decision_state, "monitor") &&
    grepl("rationale", res$neighborhood[[1L]]$decision_context$reviewer_justification_md),
  "Full decision context returned"
)
assert_true(
  isTRUE(res$exploratory_only) && isFALSE(res$decision_rule),
  "Retrieval is exploratory only (no prescribed decision)"
)
assert_true(
  !is.null(res$decision_state_counts[["monitor"]]) &&
    as.integer(res$decision_state_counts[["monitor"]]) >= 1L,
  "Decision state distribution present"
)
assert_true(
  identical(res$neighborhood[[1L]]$distance_status, "COMPARABLE") &&
    isTRUE(res$neighborhood[[1L]]$distance_scorable),
  "Scorable hits marked COMPARABLE"
)

# Dictionary mismatch still scorabe when feature schema matches
mismatched_lib <- list(
  make_case("compat", 0.05, "monitor"),
  make_case(
    "old_dict",
    0.05,
    "escalate",
    versions = list(
      dictionary_release_version = "MedDRA 25.0",
      delta_policy_version = "v1",
      feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION
    )
  )
)
res2 <- retrieve_nearest_precedents(
  query, base_versions, mismatched_lib, tiny_range,
  n_neighbors = 2L, keys = "rd_estimate", require_version_match = FALSE
)
ids <- vapply(res2$neighborhood, function(h) h$case_id, character(1))
assert_true("old_dict" %in% ids, "Incompatible dict case still returned when require_version_match=FALSE")
old_hit <- res2$neighborhood[[which(ids == "old_dict")]]
assert_true(
  isFALSE(old_hit$version_compatible) &&
    any(grepl("dictionary_release_version", old_hit$version_mismatches, fixed = TRUE)) &&
    isTRUE(old_hit$distance_scorable),
  "Dictionary mismatch flagged but still distance-scorable"
)

res3 <- retrieve_nearest_precedents(
  query, base_versions, mismatched_lib, tiny_range,
  n_neighbors = 2L, keys = "rd_estimate", require_version_match = TRUE
)
assert_true(
  identical(res3$n_returned, 1L) && identical(res3$neighborhood[[1L]]$case_id, "compat") &&
    identical(res3$n_excluded, 1L),
  "require_version_match drops incompatible cases"
)

only_bad <- list(mismatched_lib[[2L]])
assert_error_code(
  retrieve_nearest_precedents(
    query, base_versions, only_bad, tiny_range,
    n_neighbors = 1L, require_version_match = TRUE
  ),
  "PRECEDENT_NO_SCORABLE_CASES",
  "Empty compatible library Fail-Fast"
)

cat("=== 13.8.R1 Mixed feature-schema library ===\n")
mixed_lib <- list(
  make_case("A", 0.05, "monitor"),
  make_case(
    "B",
    0.06,
    "investigate",
    versions = list(
      dictionary_release_version = "MedDRA 25.0",
      delta_policy_version = "v1",
      feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION
    )
  ),
  make_case(
    "C",
    0.07,
    "escalate",
    versions = list(
      dictionary_release_version = "MedDRA 26.1",
      delta_policy_version = "v1",
      feature_schema_version = "2.0.0"
    ),
    schema_ver = "2.0.0"
  )
)

res_mixed <- retrieve_nearest_precedents(
  query, base_versions, mixed_lib, tiny_range,
  n_neighbors = 3L, keys = "rd_estimate", require_version_match = FALSE
)
mixed_ids <- vapply(res_mixed$neighborhood, function(h) h$case_id, character(1))
assert_true(
  all(c("A", "B") %in% mixed_ids) && !("C" %in% mixed_ids),
  "require_version_match=FALSE ranks A and B"
)
assert_true(
  identical(res_mixed$n_unscorable, 1L) &&
    identical(res_mixed$unscorable_cases[[1L]]$case_id, "C") &&
    identical(res_mixed$unscorable_cases[[1L]]$distance_status, "NOT_COMPARABLE") &&
    is.null(res_mixed$unscorable_cases[[1L]]$gower_distance),
  "Feature-schema mismatch case C reported non-scorable without crash"
)
b_hit <- res_mixed$neighborhood[[which(mixed_ids == "B")]]
assert_true(
  isFALSE(b_hit$version_compatible) && isTRUE(b_hit$distance_scorable),
  "Dictionary-only mismatch B ranked with mismatch flag"
)

res_mixed_strict <- retrieve_nearest_precedents(
  query, base_versions, mixed_lib, tiny_range,
  n_neighbors = 3L, keys = "rd_estimate", require_version_match = TRUE
)
assert_true(
  identical(res_mixed_strict$n_returned, 1L) &&
    identical(res_mixed_strict$neighborhood[[1L]]$case_id, "A") &&
    res_mixed_strict$n_excluded >= 1L,
  "require_version_match=TRUE returns only fully compatible A"
)

# Engine-backed smoke
fr <- load_frozen_reference_range()
ea <- extract_evidence_features(
  run_independent_beta_binomial(12, 100, 4, 100, seed = 41L, primary_delta = 0.05)$evidence
)
eb <- extract_evidence_features(
  run_independent_beta_binomial(40, 100, 4, 100, seed = 42L, primary_delta = 0.05)$evidence
)
ec <- extract_evidence_features(
  run_independent_beta_binomial(13, 100, 5, 100, seed = 43L, primary_delta = 0.05)$evidence
)
v_eng <- list(
  dictionary_release_version = "MedDRA 26.1",
  delta_policy_version = "v1",
  feature_schema_version = as.character(ea$feature_schema_version)
)
eng_lib <- list(
  make_historical_precedent_case(
    "E1", v_eng, ea,
    list(
      decision_state = "monitor",
      reviewer_justification_md = "engine-a",
      actor_id = "qa",
      decided_at_jst = "2026-09-25 08:00:00 JST"
    )
  ),
  make_historical_precedent_case(
    "E2", v_eng, eb,
    list(
      decision_state = "investigate",
      reviewer_justification_md = "engine-b",
      actor_id = "qa",
      decided_at_jst = "2026-09-25 08:00:00 JST"
    )
  )
)
eng_res <- retrieve_nearest_precedents(ec, v_eng, eng_lib, fr, n_neighbors = 1L)
assert_true(
  eng_res$n_returned == 1L && is.finite(eng_res$neighborhood[[1L]]$gower_distance),
  "Engine-backed nearest precedent retrieval succeeds"
)
assert_true(
  validate_payload_against_schema(eng_lib[[1L]], "historical-precedent-case-v1.json")$valid,
  "Engine-backed historical case passes Draft-07 nested schema"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
