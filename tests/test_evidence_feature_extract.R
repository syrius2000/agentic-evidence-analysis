# tests/test_evidence_feature_extract.R — Section 13 Phase A + QA repair 13.A.R1-R4

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
  err <- tryCatch({
    expr
    NULL
  }, error = function(e) e$message)
  if (!is.null(err) && grepl(expected_code, err, fixed = TRUE)) {
    cat(sprintf("[PASS] %s (intercepted %s)\n", msg, expected_code))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s (expected %s, got: %s)\n", msg, expected_code, as.character(err)))
    test_fail <<- test_fail + 1L
  }
}

source(".agents/shared/run_scope.R")
source(".agents/shared/independent_beta_binomial.R")
source(".agents/shared/evidence_feature_extract.R")

validate_payload_against_schema <- function(payload, schema_name, schema_dir = "schemas") {
  schema_path <- file.path(schema_dir, schema_name)
  if (!file.exists(schema_path)) stop("Schema not found: ", schema_path)
  json_str <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA)
  data <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)
  root_schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
  errors <- character()

  check_node <- function(val, sc, path) {
    if (!is.null(sc[["$ref"]])) {
      keys <- strsplit(sub("^#/", "", sc[["$ref"]]), "/", fixed = TRUE)[[1L]]
      ref_sc <- root_schema
      for (key in keys) ref_sc <- ref_sc[[key]]
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
      if (!is.null(not_sc$required) && is.list(val)) {
        for (req in not_sc$required) {
          if (req %in% names(val)) errors <<- c(errors, sprintf("%s: prohibited %s", path, req))
        }
      }
      if (!is.null(not_sc$anyOf) && is.list(val)) {
        for (clause in not_sc$anyOf) {
          if (!is.null(clause$required)) {
            for (req in clause$required) {
              if (req %in% names(val)) {
                errors <<- c(errors, sprintf("%s: prohibited via not.anyOf: %s", path, req))
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
      if (isTRUE(sc[["uniqueItems"]]) && length(val) > 1L) {
        keys <- vapply(val, function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE)), character(1))
        if (anyDuplicated(keys) > 0L) errors <<- c(errors, sprintf("%s: not unique", path))
      }
      if (!is.null(sc[["minItems"]]) && length(val) < sc[["minItems"]]) {
        errors <<- c(errors, sprintf("%s: minItems", path))
      }
      if (!is.null(sc[["contains"]])) {
        matched_any <- FALSE
        for (i in seq_along(val)) {
          saved <- errors
          check_node(val[[i]], sc[["contains"]], sprintf("%s[%d]", path, i))
          if (length(errors) == length(saved)) {
            matched_any <- TRUE
            errors <<- saved
            break
          }
          errors <<- saved
        }
        if (!matched_any) {
          errors <<- c(errors, sprintf("%s: array does not contain required item", path))
        }
      }
      if (!is.null(sc[["items"]])) {
        for (i in seq_along(val)) check_node(val[[i]], sc[["items"]], sprintf("%s[%d]", path, i))
      }
    }
  }
  check_node(data, root_schema, "$")
  list(valid = length(errors) == 0L, errors = errors)
}

cat("=== 13.1 / 13.A.R1 Skill layout and complete run lifecycle ===\n")
assert_true(file.exists(".agents/skills/evidence-decision-review/SKILL.md"),
            "evidence-decision-review SKILL.md exists")
assert_true("evidence-decision-review" %in% RUN_SCOPE_SUPPORTED_SKILLS,
            "evidence-decision-review is in RUN_SCOPE_SUPPORTED_SKILLS")

tmp_root <- file.path(tempdir(), "edr_out_r1")
unlink(tmp_root, recursive = TRUE)
dir.create(tmp_root, recursive = TRUE)
engine <- run_independent_beta_binomial(12, 100, 4, 100, seed = 21L, primary_delta = 0.05)
features <- extract_evidence_features(engine$evidence)
run1 <- complete_evidence_decision_feature_run(features, out_root = tmp_root, run_id = "phaseA_demo")
assert_true(dir.exists(run1$run_dir) && grepl("/run_phaseA_demo$", run1$run_dir),
            "complete lifecycle reserves run_phaseA_demo")
assert_true(file.exists(file.path(run1$run_dir, "evidence_feature.json")),
            "evidence_feature.json written")
assert_true(file.exists(file.path(run1$run_dir, "results_manifest.json")),
            "results_manifest.json written")
assert_true(file.exists(file.path(run1$run_dir, "run_meta.json")),
            "run_meta.json written")

meta <- read_run_control(run1$run_dir)
assert_true(identical(meta$skill, "evidence-decision-review"),
            "read_run_control accepts evidence-decision-review")
assert_true(identical(as.character(meta$path_schema_version), RUN_SCOPE_PATH_SCHEMA_VERSION),
            "path_schema_version is canonical")
assert_true(!is.null(meta$results_manifest_sha256) &&
              identical(meta$results_manifest_sha256, run1$manifest$manifest_sha256),
            "results_manifest_sha256 bound into run_meta")
assert_true(identical(as.character(meta$logical_run_id), "phaseA_demo"),
            "logical_run_id preserved")
v_manifest <- verify_results_manifest(run1$run_dir, meta$results_manifest_sha256)
assert_true(identical(v_manifest$manifest_sha256, meta$results_manifest_sha256),
            "verify_results_manifest succeeds against bound hash")
assert_true(identical(basename(dirname(run1$run_dir)), basename(tmp_root)),
            "No root leakage: run nested under skill out_root")

run2 <- complete_evidence_decision_feature_run(features, out_root = tmp_root, run_id = "phaseA_demo")
assert_true(grepl("/run_phaseA_demo_2$", run2$run_dir),
            "Same run_id collision creates _2 suffix without overwrite")
assert_true(dir.exists(run1$run_dir) && file.exists(file.path(run1$run_dir, "run_meta.json")),
            "Original run directory remains intact after collision")

cat("\n=== 13.2 / 13.A.R2-R3 Feature schema contracts ===\n")
assert_true(validate_payload_against_schema(features, "evidence-feature-v1.json")$valid,
            "Canonical delta-enabled extractor output validates")
engine_none <- run_independent_beta_binomial(12, 100, 4, 100, seed = 21L, primary_delta = NULL)
features_none <- extract_evidence_features(engine_none$evidence)
assert_true(!isTRUE(features_none$delta_dependent$present),
            "Null-delta extractor sets present=false")
assert_true(validate_payload_against_schema(features_none, "evidence-feature-v1.json")$valid,
            "Canonical null-delta extractor output validates")
assert_true(
  identical(unlist(features_none$clustering_feature_keys, use.names = FALSE), CORE_CLUSTERING_KEYS),
  "Null-delta clustering keys are core-only in canonical order"
)
assert_true(
  identical(
    unlist(features$clustering_feature_keys, use.names = FALSE),
    c(CORE_CLUSTERING_KEYS, DELTA_CLUSTERING_KEYS)
  ),
  "Delta-enabled clustering keys append delta keys after core in canonical order"
)

bad_decision_key <- features
bad_decision_key$clustering_feature_keys <- list("decision_code")
assert_true(!validate_payload_against_schema(bad_decision_key, "evidence-feature-v1.json")$valid,
            "Schema rejects decision_code in clustering_feature_keys")
assert_error_code(
  assert_clustering_feature_keys(list("decision_code"), TRUE),
  "DECISION_LABEL_IN_FEATURE_KEYS",
  "Runtime rejects decision_code clustering key"
)

bad_reg_key <- features
bad_reg_key$clustering_feature_keys <- list("regulatory_label")
assert_true(!validate_payload_against_schema(bad_reg_key, "evidence-feature-v1.json")$valid,
            "Schema rejects regulatory_label in clustering_feature_keys")

bad_unknown <- features
bad_unknown$clustering_feature_keys <- list("arbitrary_unknown_feature")
assert_true(!validate_payload_against_schema(bad_unknown, "evidence-feature-v1.json")$valid,
            "Schema rejects arbitrary unknown clustering feature")
assert_error_code(
  assert_clustering_feature_keys(list("arbitrary_unknown_feature"), FALSE),
  "UNKNOWN_CLUSTERING_FEATURE_KEYS",
  "Runtime rejects unknown clustering feature"
)

present_true_nulls <- features
present_true_nulls$delta_dependent <- list(
  present = TRUE, primary_delta = NULL, target_excess = NULL,
  practical_neutral = NULL, reference_excess = NULL
)
assert_true(!validate_payload_against_schema(present_true_nulls, "evidence-feature-v1.json")$valid,
            "Schema rejects present=true with null delta values")
assert_error_code(
  assert_delta_dependent_atomicity(present_true_nulls$delta_dependent),
  "INVALID_DELTA_DEPENDENT",
  "Runtime rejects present=true with null delta values"
)

present_false_nums <- features_none
present_false_nums$delta_dependent <- list(
  present = FALSE, primary_delta = 0.05, target_excess = 0.8,
  practical_neutral = 0.1, reference_excess = 0.1
)
assert_true(!validate_payload_against_schema(present_false_nums, "evidence-feature-v1.json")$valid,
            "Schema rejects present=false with numeric delta values")
assert_error_code(
  assert_delta_dependent_atomicity(present_false_nums$delta_dependent),
  "INVALID_DELTA_DEPENDENT",
  "Runtime rejects present=false with numeric delta values"
)

present_false_delta_keys <- features_none
present_false_delta_keys$clustering_feature_keys <- as.list(c(CORE_CLUSTERING_KEYS, "primary_delta"))
assert_true(!validate_payload_against_schema(present_false_delta_keys, "evidence-feature-v1.json")$valid,
            "Schema rejects delta clustering keys when present=false")
assert_error_code(
  assert_clustering_feature_keys(present_false_delta_keys$clustering_feature_keys, FALSE),
  "DELTA_CLUSTERING_KEYS_WHEN_ABSENT",
  "Runtime rejects delta clustering keys when present=false"
)

missing_primary_delta_key <- features
missing_primary_delta_key$clustering_feature_keys <- as.list(c(
  CORE_CLUSTERING_KEYS, "target_excess", "practical_neutral", "reference_excess"
))
assert_true(
  !validate_payload_against_schema(missing_primary_delta_key, "evidence-feature-v1.json")$valid,
  "Schema rejects present=true missing primary_delta clustering key"
)
assert_error_code(
  assert_clustering_feature_keys(missing_primary_delta_key$clustering_feature_keys, TRUE),
  "MISSING_DELTA_CLUSTERING_KEYS",
  "Runtime rejects present=true missing primary_delta clustering key"
)

missing_region_key <- features
missing_region_key$clustering_feature_keys <- as.list(c(
  CORE_CLUSTERING_KEYS, "primary_delta", "target_excess", "practical_neutral"
))
assert_true(
  !validate_payload_against_schema(missing_region_key, "evidence-feature-v1.json")$valid,
  "Schema rejects present=true missing reference_excess clustering key"
)
assert_error_code(
  assert_clustering_feature_keys(missing_region_key$clustering_feature_keys, TRUE),
  "MISSING_DELTA_CLUSTERING_KEYS",
  "Runtime rejects present=true missing reference_excess clustering key"
)

bad_primary_delta <- features
bad_primary_delta$delta_dependent$primary_delta <- 0
assert_true(!validate_payload_against_schema(bad_primary_delta, "evidence-feature-v1.json")$valid,
            "Schema rejects primary_delta <= 0 when present=true")
assert_error_code(
  assert_delta_dependent_atomicity(bad_primary_delta$delta_dependent),
  "INVALID_DELTA_DEPENDENT",
  "Runtime rejects primary_delta <= 0 when present=true"
)

cat("\n=== 13.3 Decision/regulatory labels excluded from features ===\n")
poisoned <- engine$evidence
poisoned$decision_code <- "APPROVE_LABEL_CHANGE"
assert_error_code(
  extract_evidence_features(poisoned),
  "DECISION_LABEL_IN_FEATURE_SOURCE",
  "Embedded decision_code is rejected before feature construction"
)
poisoned2 <- engine$evidence
poisoned2$diagnostics$regulatory_label <- "BOXED_WARNING"
assert_error_code(
  extract_evidence_features(poisoned2),
  "DECISION_LABEL_IN_FEATURE_SOURCE",
  "Nested regulatory_label is rejected"
)
feature_with_decision <- features
feature_with_decision$decision <- "approve"
assert_true(
  !validate_payload_against_schema(feature_with_decision, "evidence-feature-v1.json")$valid,
  "Schema rejects feature payloads that carry a decision field"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
