# tests/test_comparative_schemas.R — Test suite for comparative schemas and contrast engine
# Tests Tasks 2.1 through 2.14 of OpenSpec comparative-evidence-reporting-v3

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

source(".agents/shared/comparative_contrasts.R")
source(".agents/shared/independent_beta_binomial.R")
source(".agents/shared/matched_pair_dirichlet.R")
source(".agents/shared/matched_set_inference.R")
source(".agents/shared/iptw_inference.R")
source(".agents/shared/person_time_rate.R")
source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")

validate_payload_against_schema <- function(payload, schema_name, schema_dir = "schemas") {
  schema_path <- file.path(schema_dir, schema_name)
  if (!file.exists(schema_path)) stop("Schema not found: ", schema_path)
  nonfinite_paths <- character()
  find_nonfinite <- function(x, path = "$") {
    if (is.numeric(x) && length(x) && any(!is.finite(x))) nonfinite_paths <<- c(nonfinite_paths, path)
    if (is.list(x)) {
      nms <- names(x)
      for (i in seq_along(x)) {
        child <- if (!is.null(nms) && nzchar(nms[[i]])) paste0(path, ".", nms[[i]]) else sprintf("%s[%d]", path, i)
        find_nonfinite(x[[i]], child)
      }
    }
  }
  find_nonfinite(payload)
  if (length(nonfinite_paths)) {
    return(list(valid = FALSE, errors = paste0(nonfinite_paths, ": non-finite numeric value")))
  }
  json_str <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA)
  data <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)

  schemas_cache <- list()
  load_schema <- function(name) {
    clean_name <- sub("#.*$", "", name)
    if (!is.null(schemas_cache[[clean_name]])) {
      return(schemas_cache[[clean_name]])
    }
    p <- file.path(schema_dir, clean_name)
    sc <- jsonlite::fromJSON(p, simplifyVector = FALSE)
    schemas_cache[[clean_name]] <<- sc
    sc
  }

  root_schema <- load_schema(schema_name)
  errors <- character()

  check_node <- function(val, sc, path) {
    if (!is.null(sc[["$ref"]])) {
      ref <- sc[["$ref"]]
      if (startsWith(ref, "#/")) {
        keys <- strsplit(sub("^#/", "", ref), "/", fixed = TRUE)[[1L]]
        ref_sc <- root_schema
        for (key in keys) ref_sc <- ref_sc[[key]]
        if (is.null(ref_sc)) stop("Unresolved local schema reference: ", ref)
      } else {
        ref_sc <- load_schema(ref)
      }
      check_node(val, ref_sc, path)
      return()
    }
    if (!is.null(sc[["if"]])) {
      saved_errors <- errors
      check_node(val, sc[["if"]], path)
      condition_met <- length(errors) == length(saved_errors)
      errors <<- saved_errors
      if (condition_met && !is.null(sc[["then"]])) check_node(val, sc[["then"]], path)
      if (!condition_met && !is.null(sc[["else"]])) check_node(val, sc[["else"]], path)
    }
    if (!is.null(sc[["not"]])) {
      not_sc <- sc[["not"]]
      if (!is.null(not_sc$required) && is.list(val)) {
        for (req in not_sc$required) {
          if (req %in% names(val)) {
            errors <<- c(errors, sprintf("%s: property prohibited by schema not constraint: %s", path, req))
          }
        }
      }
    }
    allowed_types <- sc[["type"]]
    if (!is.null(allowed_types)) {
      if (is.null(val)) {
        if (!"null" %in% allowed_types) {
          errors <<- c(errors, sprintf("%s: expected %s, got null", path, paste(allowed_types, collapse = "|")))
          return()
        }
        return()
      }
      matched <- FALSE
      for (at in allowed_types) {
        if (at == "object" && is.list(val) && (length(val) == 0 || !is.null(names(val)))) matched <- TRUE
        if (at == "array" && is.list(val) && (length(val) == 0 || is.null(names(val)))) matched <- TRUE
        if (at == "string" && is.character(val) && length(val) == 1) matched <- TRUE
        if (at == "number" && (is.numeric(val) || is.integer(val)) && length(val) == 1 && !is.na(val)) matched <- TRUE
        if (at == "integer" && is.numeric(val) && length(val) == 1 && !is.na(val) && val == floor(val)) matched <- TRUE
        if (at == "boolean" && is.logical(val) && length(val) == 1 && !is.na(val)) matched <- TRUE
      }
      if (!matched) {
        errors <<- c(errors, sprintf("%s: type mismatch (expected %s)", path, paste(allowed_types, collapse = "|")))
        return()
      }
    }
    if (!is.null(sc[["enum"]]) && !is.null(val)) {
      if (!(val %in% unlist(sc[["enum"]]))) {
        errors <<- c(errors, sprintf("%s: value not in enum: %s", path, val))
      }
    }
    if (!is.null(sc[["const"]]) && !identical(val, sc[["const"]])) {
      errors <<- c(errors, sprintf("%s: value does not match const", path))
    }
    if (!is.null(sc[["minLength"]]) && is.character(val) && length(val) == 1L && !is.na(val)) {
      if (nchar(val, type = "chars") < as.integer(sc[["minLength"]])) {
        errors <<- c(errors, sprintf("%s: string shorter than minLength %s", path, sc[["minLength"]]))
      }
    }
    if (!is.null(sc[["minimum"]]) && is.numeric(val)) {
      if (val < sc[["minimum"]]) errors <<- c(errors, sprintf("%s: value less than minimum: %s", path, val))
    }
    if (!is.null(sc[["maximum"]]) && is.numeric(val)) {
      if (val > sc[["maximum"]]) errors <<- c(errors, sprintf("%s: value greater than maximum: %s", path, val))
    }
    if (!is.null(sc[["exclusiveMinimum"]]) && is.numeric(val)) {
      if (val <= sc[["exclusiveMinimum"]]) errors <<- c(errors, sprintf("%s: value not greater than exclusiveMinimum: %s", path, val))
    }
    if (!is.null(sc[["exclusiveMaximum"]]) && is.numeric(val)) {
      if (val >= sc[["exclusiveMaximum"]]) errors <<- c(errors, sprintf("%s: value not less than exclusiveMaximum: %s", path, val))
    }
    if (is.list(val) && (length(val) == 0 || !is.null(names(val)))) {
      val_names <- names(val)
      if (!is.null(sc[["required"]])) {
        for (req in sc[["required"]]) {
          if (!req %in% val_names) errors <<- c(errors, sprintf("%s: missing required property: %s", path, req))
        }
      }
      props <- sc[["properties"]]
      if (!is.null(props)) {
        for (pname in intersect(names(props), val_names)) {
          check_node(val[[pname]], props[[pname]], paste0(path, ".", pname))
        }
      }
      if (!is.null(sc[["additionalProperties"]])) {
        ap <- sc[["additionalProperties"]]
        extra_keys <- setdiff(val_names, names(props))
        if (identical(ap, FALSE) && length(extra_keys) > 0) {
          errors <<- c(errors, sprintf("%s: additional properties not allowed: %s", path, paste(extra_keys, collapse = ", ")))
        } else if (is.list(ap)) {
          for (k in extra_keys) check_node(val[[k]], ap, paste0(path, ".", k))
        }
      }
    }
    if (is.list(val) && (length(val) == 0 || is.null(names(val)))) {
      if (isTRUE(sc[["uniqueItems"]]) && length(val) > 1L) {
        item_keys <- vapply(
          val,
          function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA)),
          character(1L)
        )
        if (anyDuplicated(item_keys) > 0L) {
          errors <<- c(errors, sprintf("%s: array items are not unique", path))
        }
      }
      if (!is.null(sc[["items"]])) {
        if (!is.null(sc[["minItems"]]) && length(val) < sc[["minItems"]]) {
          errors <<- c(errors, sprintf("%s: array has fewer than minItems", path))
        }
        item_sc <- sc[["items"]]
        for (idx in seq_along(val)) check_node(val[[idx]], item_sc, sprintf("%s[%d]", path, idx))
      }
    }
  }
  check_node(data, root_schema, "$")
  list(valid = length(errors) == 0L, errors = errors)
}

cat("=== 0. Offline JSON Schema validation (Pure R jsonlite) ===\n")
engine_ephemeral <- run_independent_beta_binomial(3, 100, 0, 100, seed = 12L)
engine_persisted <- run_independent_beta_binomial(3, 100, 0, 100,
  seed = 12L,
  persist_raw_draws = TRUE
)
assert_true(
  validate_payload_against_schema(engine_ephemeral$draws, "comparative-draws-v1.json")$valid,
  "Ephemeral draw object validates against Draft 7 schema (pure R)"
)
assert_true(
  validate_payload_against_schema(engine_persisted$draws, "comparative-draws-v1.json")$valid,
  "Persisted draw object validates against Draft 7 schema (pure R)"
)
matched_engine <- run_matched_pair_dirichlet(
  counts = c(n11 = 3L, n10 = 2L, n01 = 1L, n00 = 4L),
  num_draws = 20L, seed = 12L, persist_raw_draws = TRUE
)
assert_true(
  validate_payload_against_schema(matched_engine$draws, "comparative-draws-v1.json")$valid,
  "Matched-pair draw object validates against Draft 7 schema (pure R)"
)
assert_true(
  validate_payload_against_schema(matched_engine$evidence, "comparative-evidence-v1.json")$valid,
  "Matched-pair evidence validates against Draft 7 schema (pure R)"
)
bad_matched <- matched_engine$evidence
bad_matched$matched_pair$odds_ratio_definition <- "invalid_definition"
assert_true(
  !validate_payload_against_schema(bad_matched, "comparative-evidence-v1.json")$valid,
  "Schema rejects invalid matched-pair odds_ratio_definition (pure R)"
)
matched_set_sample <- data.frame(
  subject_id = sprintf("SUBJ_%02d", 1:6),
  set_id = c("S1", "S1", "S1", "S2", "S2", "S2"),
  treatment = c(1L, 0L, 0L, 1L, 0L, 0L),
  outcome = c(1L, 0L, 1L, 0L, 0L, 0L),
  age = c(50, 48, 52, 60, 59, 61),
  stringsAsFactors = FALSE
)
matched_set_engine <- run_matched_set_inference(matched_set_sample,
  covariates = "age",
  num_draws = 20L, seed = 12L, persist_raw_draws = TRUE
)
assert_true(
  validate_payload_against_schema(matched_set_engine$draws, "comparative-draws-v1.json")$valid,
  "Matched-set draw object validates against Draft 7 schema (pure R)"
)
assert_true(
  validate_payload_against_schema(matched_set_engine$evidence, "comparative-evidence-v1.json")$valid,
  "Matched-set evidence validates against Draft 7 schema (pure R)"
)

# H-03 Negative schema tests for matched_set evidence
bad_ms_no_raw_ref <- matched_set_engine$evidence
bad_ms_no_raw_ref$matched_set$raw_reference_counts <- NULL
assert_true(
  !validate_payload_against_schema(bad_ms_no_raw_ref, "comparative-evidence-v1.json")$valid,
  "Schema rejects matched_set evidence missing raw_reference_counts (H-03)"
)

bad_ms_no_raw_tgt <- matched_set_engine$evidence
bad_ms_no_raw_tgt$matched_set$raw_target_counts <- NULL
assert_true(
  !validate_payload_against_schema(bad_ms_no_raw_tgt, "comparative-evidence-v1.json")$valid,
  "Schema rejects matched_set evidence missing raw_target_counts (H-03)"
)

# H-03 Negative schema tests for matched_set draws
bad_draws_no_estimand <- matched_set_engine$draws
bad_draws_no_estimand$matched_set_metadata$estimand <- NULL
assert_true(
  !validate_payload_against_schema(bad_draws_no_estimand, "comparative-draws-v1.json")$valid,
  "Schema rejects matched_set draws missing estimand (H-03)"
)

bad_draws_no_scope <- matched_set_engine$draws
bad_draws_no_scope$matched_set_metadata$bootstrap_scope <- NULL
assert_true(
  !validate_payload_against_schema(bad_draws_no_scope, "comparative-draws-v1.json")$valid,
  "Schema rejects matched_set draws missing bootstrap_scope (H-03)"
)

bad_draws_bad_scope <- matched_set_engine$draws
bad_draws_bad_scope$matched_set_metadata$bootstrap_scope$type <- "unconditional"
assert_true(
  !validate_payload_against_schema(bad_draws_bad_scope, "comparative-draws-v1.json")$valid,
  "Schema rejects invalid bootstrap_scope.type enum (H-03)"
)

bad_draws_min_draws <- matched_set_engine$draws
bad_draws_min_draws$num_draws <- 9L
assert_true(
  !validate_payload_against_schema(bad_draws_min_draws, "comparative-draws-v1.json")$valid,
  "Schema rejects num_draws < 10 (H-01/H-03)"
)

bad_matched_set <- matched_set_engine$evidence
bad_matched_set$matched_set$matching_ratio$type <- "invalid_ratio_type"
assert_true(
  !validate_payload_against_schema(bad_matched_set, "comparative-evidence-v1.json")$valid,
  "Schema rejects invalid matched-set matching_ratio type (pure R)"
)

# IPTW Schema validation tests
iptw_sample_df <- data.frame(
  treatment = c(rep(1L, 10), rep(0L, 10)),
  outcome = c(rep(1L, 4), rep(0L, 6), rep(1L, 2), rep(0L, 8)),
  age = c(
    50, 52, 54, 56, 58, 60, 62, 64, 66, 68,
    48, 50, 52, 54, 56, 58, 60, 62, 64, 66
  )
)
iptw_engine <- run_iptw_inference(iptw_sample_df, covariates = "age", num_draws = 20L, seed = 12L, persist_raw_draws = TRUE)
assert_true(
  validate_payload_against_schema(iptw_engine$draws, "comparative-draws-v1.json")$valid,
  "IPTW draw object validates against Draft 7 schema (pure R)"
)
assert_true(
  validate_payload_against_schema(iptw_engine$evidence, "comparative-evidence-v1.json")$valid,
  "IPTW evidence validates against Draft 7 schema (pure R)"
)

# Post-acceptance IPTW schema contract: raw/effective PS provenance and strict boundary.
for (field in c("raw_target_ps", "raw_reference_ps")) {
  bad_evidence <- iptw_engine$evidence
  bad_evidence$iptw$positivity[[field]] <- NULL
  assert_true(
    !validate_payload_against_schema(bad_evidence, "comparative-evidence-v1.json")$valid,
    sprintf("Evidence schema rejects missing positivity %s", field)
  )
}
bad_iptw_empty_ps <- iptw_engine$evidence
bad_iptw_empty_ps$iptw$positivity$target_ps <- list()
assert_true(
  !validate_payload_against_schema(bad_iptw_empty_ps, "comparative-evidence-v1.json")$valid,
  "Evidence schema rejects an empty PS summary"
)
bad_iptw_no_effective_overlap <- iptw_engine$evidence
bad_iptw_no_effective_overlap$iptw$positivity$common_support$effective_has_overlap <- NULL
assert_true(
  !validate_payload_against_schema(bad_iptw_no_effective_overlap, "comparative-evidence-v1.json")$valid,
  "Evidence schema requires effective common-support overlap status"
)
for (field in c("target_ps", "reference_ps", "raw_target_ps", "raw_reference_ps")) {
  bad_evidence <- iptw_engine$evidence
  bad_evidence$iptw$positivity[[field]]$mean <- 1.1
  assert_true(
    !validate_payload_against_schema(bad_evidence, "comparative-evidence-v1.json")$valid,
    sprintf("Evidence schema rejects %s mean above one", field)
  )
}
for (field in c("min", "max", "effective_min", "effective_max")) {
  bad_evidence <- iptw_engine$evidence
  bad_evidence$iptw$positivity$common_support[[field]] <- 1.1
  assert_true(
    !validate_payload_against_schema(bad_evidence, "comparative-evidence-v1.json")$valid,
    sprintf("Evidence schema rejects common-support %s above one", field)
  )
}
bad_iptw_upper_equal_one <- iptw_engine$evidence
bad_iptw_upper_equal_one$iptw$propensity_score_boundary_policy$upper <- 1
assert_true(
  !validate_payload_against_schema(bad_iptw_upper_equal_one, "comparative-evidence-v1.json")$valid,
  "Evidence schema rejects PS upper boundary equal to one"
)
bad_draws_upper_equal_one <- iptw_engine$draws
bad_draws_upper_equal_one$iptw_metadata$propensity_score_boundary_policy$upper <- 1
assert_true(
  !validate_payload_against_schema(bad_draws_upper_equal_one, "comparative-draws-v1.json")$valid,
  "Draws schema rejects PS upper boundary equal to one"
)
assert_true(
  is.null(iptw_engine$evidence$target_cohort$events) && is.null(iptw_engine$evidence$target_cohort$total),
  "IPTW cohort output does not expose raw count numerator/denominator"
)
iptw_fields <- c("iptw_mode", "truncation", "att_scaling_mode", "propensity_model", "propensity_score_boundary_policy", "bootstrap_clipping_diagnostics", "max_failure_rate")
assert_true(
  all(iptw_fields %in% names(iptw_engine$evidence$iptw)) && all(iptw_fields %in% names(iptw_engine$draws$iptw_metadata)),
  "IPTW evidence and draw metadata expose the same provenance field contract"
)
evidence_schema_obj <- jsonlite::fromJSON("schemas/comparative-evidence-v1.json", simplifyVector = FALSE)
draws_schema_obj <- jsonlite::fromJSON("schemas/comparative-draws-v1.json", simplifyVector = FALSE)
assert_true(
  all(iptw_fields %in% evidence_schema_obj$properties$iptw$required) && all(iptw_fields %in% draws_schema_obj$properties$iptw_metadata$required),
  "Evidence and draws schemas require the same IPTW provenance fields"
)

bad_iptw_estimand <- iptw_engine$evidence
bad_iptw_estimand$iptw$estimand <- "INVALID_ESTIMAND"
assert_true(
  !validate_payload_against_schema(bad_iptw_estimand, "comparative-evidence-v1.json")$valid,
  "Schema rejects invalid IPTW estimand (pure R)"
)

bad_iptw_no_ess <- iptw_engine$evidence
bad_iptw_no_ess$iptw$effective_sample_size <- NULL
assert_true(
  !validate_payload_against_schema(bad_iptw_no_ess, "comparative-evidence-v1.json")$valid,
  "Schema rejects IPTW evidence missing effective_sample_size (pure R)"
)
for (field in iptw_fields) {
  bad_evidence <- iptw_engine$evidence
  bad_evidence$iptw[[field]] <- NULL
  assert_true(
    !validate_payload_against_schema(bad_evidence, "comparative-evidence-v1.json")$valid,
    sprintf("Evidence schema rejects missing IPTW provenance field %s", field)
  )
}
bad_iptw_mode <- iptw_engine$evidence
bad_iptw_mode$iptw$iptw_mode <- "fixed_ps"
assert_true(!validate_payload_against_schema(bad_iptw_mode, "comparative-evidence-v1.json")$valid, "Evidence schema rejects invalid IPTW mode enum")
bad_iptw_lower <- iptw_engine$evidence
bad_iptw_lower$iptw$propensity_score_boundary_policy$lower <- 0
assert_true(!validate_payload_against_schema(bad_iptw_lower, "comparative-evidence-v1.json")$valid, "Evidence schema rejects zero PS lower boundary")
bad_iptw_upper <- iptw_engine$evidence
bad_iptw_upper$iptw$propensity_score_boundary_policy$upper <- 1.1
assert_true(!validate_payload_against_schema(bad_iptw_upper, "comparative-evidence-v1.json")$valid, "Evidence schema rejects PS upper boundary above one")
bad_iptw_threshold <- iptw_engine$evidence
bad_iptw_threshold$iptw$max_failure_rate <- 1
assert_true(!validate_payload_against_schema(bad_iptw_threshold, "comparative-evidence-v1.json")$valid, "Evidence schema rejects convergence threshold equal to one")
bad_iptw_infinite <- iptw_engine$evidence
bad_iptw_infinite$iptw$max_failure_rate <- Inf
assert_true(!validate_payload_against_schema(bad_iptw_infinite, "comparative-evidence-v1.json")$valid, "Validator rejects non-finite numeric values before JSON serialization")

bad_draws_upper <- iptw_engine$draws
bad_draws_upper$iptw_metadata$max_failure_rate <- 1
assert_true(!validate_payload_against_schema(bad_draws_upper, "comparative-draws-v1.json")$valid, "Validator enforces exclusiveMaximum on draw provenance")
bad_draws_lower <- iptw_engine$draws
bad_draws_lower$iptw_metadata$propensity_score_boundary_policy$lower <- 0
assert_true(!validate_payload_against_schema(bad_draws_lower, "comparative-draws-v1.json")$valid, "Validator enforces exclusiveMinimum on PS boundary")

bad_iptw_clip_fraction <- iptw_engine$evidence
bad_iptw_clip_fraction$iptw$bootstrap_clipping_diagnostics$max_clipped_fraction <- 1.1
assert_true(!validate_payload_against_schema(bad_iptw_clip_fraction, "comparative-evidence-v1.json")$valid, "Validator enforces maximum on clipping fraction")
bad_iptw_no_threshold <- iptw_engine$draws
bad_iptw_no_threshold$iptw_metadata$max_failure_rate <- NULL
assert_true(
  !validate_payload_against_schema(bad_iptw_no_threshold, "comparative-draws-v1.json")$valid,
  "Schema rejects IPTW draws missing the configured convergence threshold"
)
bad_iptw_no_refit <- iptw_engine$draws
bad_iptw_no_refit$iptw_metadata$iptw_mode <- NULL
assert_true(
  !validate_payload_against_schema(bad_iptw_no_refit, "comparative-draws-v1.json")$valid,
  "Schema rejects IPTW draws missing PS refit provenance"
)
assert_true(
  validate_payload_against_schema(engine_ephemeral$evidence, "comparative-evidence-v1.json")$valid,
  "Single evidence object validates against Draft 7 schema (pure R)"
)
legacy_robust <- engine_ephemeral$evidence
legacy_robust$diagnostics$prior_sensitivity$robust <- TRUE
assert_true(
  !validate_payload_against_schema(legacy_robust, "comparative-evidence-v1.json")$valid,
  "Schema rejects legacy binary robust flag (pure R)"
)
schema_batch <- generate_comparative_report(data.frame(
  theme = c("X", "X"), arm = c("A", "B"),
  events = c(3L, 0L), total = c(100L, 100L)
), output_dir = tempfile("schema_batch_"))
batch_payload <- jsonlite::read_json(schema_batch$json_path, simplifyVector = FALSE)
assert_true(
  validate_payload_against_schema(batch_payload, "comparative-evidence-batch-v1.json")$valid,
  "Written batch evidence validates against Draft 7 schema (pure R)"
)

# Section 11: person-time draw interface and rate-specific evidence schema.
rate_engine <- run_person_time_rate(3, 100, 1, 120, num_draws = 100L, seed = 12L)
rate_persisted <- run_person_time_rate(3, 100, 1, 120,
  num_draws = 100L, seed = 12L,
  persist_raw_draws = TRUE
)
assert_true(
  validate_payload_against_schema(rate_engine$draws, "comparative-draws-v1.json")$valid,
  "Ephemeral person-time draws validate against shared draw schema"
)
assert_true(
  validate_payload_against_schema(rate_persisted$draws, "comparative-draws-v1.json")$valid,
  "Persisted person-time draws validate against shared draw schema"
)
assert_true(
  validate_payload_against_schema(rate_engine$evidence, "comparative-rate-evidence-v1.json")$valid,
  "Person-time evidence validates against rate-specific schema"
)
bad_rate_draws <- rate_engine$draws
bad_rate_draws$person_time_metadata <- NULL
assert_true(
  !validate_payload_against_schema(bad_rate_draws, "comparative-draws-v1.json")$valid,
  "Draw schema requires person-time metadata for person-time design"
)
bad_rate_unit <- rate_engine$draws
bad_rate_unit$person_time_metadata$exposure_unit <- "days"
assert_true(
  !validate_payload_against_schema(bad_rate_unit, "comparative-draws-v1.json")$valid,
  "Draw schema rejects unsupported exposure units"
)
bad_rate_denom <- rate_engine$draws
bad_rate_denom$person_time_metadata$target_exposure <- 0
assert_true(
  !validate_payload_against_schema(bad_rate_denom, "comparative-draws-v1.json")$valid,
  "Draw schema rejects zero person-time denominator"
)
bad_rate_shape <- rate_engine$draws
bad_rate_shape$person_time_metadata$target_shape <- NULL
assert_true(
  !validate_payload_against_schema(bad_rate_shape, "comparative-draws-v1.json")$valid,
  "Draw schema requires Gamma posterior shape metadata"
)
bad_rate_evidence <- rate_engine$evidence
bad_rate_evidence$person_time$reference_exposure <- NULL
assert_true(
  !validate_payload_against_schema(bad_rate_evidence, "comparative-rate-evidence-v1.json")$valid,
  "Rate evidence schema requires reference exposure denominator"
)
bad_rate_assumptions <- rate_engine$evidence
bad_rate_assumptions$person_time$assumptions$limitations <- list()
assert_true(
  !validate_payload_against_schema(bad_rate_assumptions, "comparative-rate-evidence-v1.json")$valid,
  "Rate evidence schema requires stated model limitations"
)
bad_rate_semantics <- rate_engine$evidence
bad_rate_semantics$incidence_rate_difference$estimate$source <- "observed_sample_estimate"
assert_true(
  !validate_payload_against_schema(bad_rate_semantics, "comparative-rate-evidence-v1.json")$valid,
  "Rate evidence schema rejects bootstrap point-estimate semantics"
)
bad_rate_risk_name <- rate_engine$evidence
bad_rate_risk_name$risk_difference <- list()
assert_true(
  !validate_payload_against_schema(bad_rate_risk_name, "comparative-rate-evidence-v1.json")$valid,
  "Rate evidence schema rejects risk-difference field leakage"
)

# Section 11 post-acceptance schema hardening.
month_rate <- run_person_time_rate(3, 1200, 1, 1440,
  exposure_unit = "person_months",
  num_draws = 100L, seed = 12L
)
assert_true(
  validate_payload_against_schema(month_rate$draws, "comparative-draws-v1.json")$valid &&
    validate_payload_against_schema(month_rate$evidence, "comparative-rate-evidence-v1.json")$valid,
  "Person-month draw and evidence unit pair validates"
)
bad_rate_semantics_draw <- rate_engine$draws
bad_rate_semantics_draw$inferential_semantics <- "bootstrap"
assert_true(
  !validate_payload_against_schema(bad_rate_semantics_draw, "comparative-draws-v1.json")$valid,
  "Person-time draws cannot claim bootstrap semantics"
)
for (unit_case in list(
  list(exposure = "person_years", wrong_rate = "events_per_person_month"),
  list(exposure = "person_months", wrong_rate = "events_per_person_year")
)) {
  base <- if (unit_case$exposure == "person_years") rate_engine else month_rate
  bad_draw <- base$draws
  bad_draw$person_time_metadata$rate_unit <- unit_case$wrong_rate
  bad_evidence <- base$evidence
  bad_evidence$person_time$rate_unit <- unit_case$wrong_rate
  assert_true(
    !validate_payload_against_schema(bad_draw, "comparative-draws-v1.json")$valid &&
      !validate_payload_against_schema(bad_evidence, "comparative-rate-evidence-v1.json")$valid,
    sprintf("Both schemas reject mismatched %s rate unit", unit_case$exposure)
  )
}
zero_rate <- run_person_time_rate(2, 100, 0, 120, num_draws = 100L, seed = 12L)
assert_true(
  validate_payload_against_schema(zero_rate$evidence, "comparative-rate-evidence-v1.json")$valid,
  "Zero-reference runtime evidence validates its atomic IRR state"
)
bad_zero_mean <- zero_rate$evidence
bad_zero_mean$incidence_rate_ratio$mean <- 2.4
assert_true(
  !validate_payload_against_schema(bad_zero_mean, "comparative-rate-evidence-v1.json")$valid,
  "Zero-reference schema rejects finite IRR mean"
)
bad_zero_finite <- zero_rate$evidence
bad_zero_finite$incidence_rate_ratio$mean_is_finite <- TRUE
assert_true(
  !validate_payload_against_schema(bad_zero_finite, "comparative-rate-evidence-v1.json")$valid,
  "Zero-reference schema rejects true IRR mean flag"
)
bad_zero_diagnostic <- zero_rate$evidence
bad_zero_diagnostic$incidence_rate_ratio$diagnostic <- NULL
assert_true(
  !validate_payload_against_schema(bad_zero_diagnostic, "comparative-rate-evidence-v1.json")$valid,
  "Zero-reference schema requires divergence diagnostic"
)
bad_positive_mean <- rate_engine$evidence
bad_positive_mean["incidence_rate_ratio"][[1L]]["mean"] <- list(NULL)
assert_true(
  !validate_payload_against_schema(bad_positive_mean, "comparative-rate-evidence-v1.json")$valid,
  "Positive-reference schema requires numeric IRR mean"
)
bad_persisted_missing <- rate_persisted$draws
bad_persisted_missing$target_draws <- NULL
assert_true(
  !validate_payload_against_schema(bad_persisted_missing, "comparative-draws-v1.json")$valid,
  "Persisted person-time draw arrays cannot be absent"
)
bad_persisted_null <- rate_persisted$draws
bad_persisted_null["target_draws"] <- list(NULL)
assert_true(
  !validate_payload_against_schema(bad_persisted_null, "comparative-draws-v1.json")$valid,
  "Persisted person-time draw arrays cannot be null"
)
bad_persisted_short <- rate_persisted$draws
bad_persisted_short$target_draws <- bad_persisted_short$target_draws[1:9]
assert_true(
  !validate_payload_against_schema(bad_persisted_short, "comparative-draws-v1.json")$valid,
  "Persisted person-time draw arrays require at least 10 values"
)
bad_persisted_zero <- rate_persisted$draws
bad_persisted_zero$reference_draws[[1L]] <- 0
assert_true(
  !validate_payload_against_schema(bad_persisted_zero, "comparative-draws-v1.json")$valid,
  "Persisted person-time draws must be strictly positive"
)
bad_ephemeral_array <- rate_engine$draws
bad_ephemeral_array$target_draws <- rate_persisted$draws$target_draws
assert_true(
  !validate_payload_against_schema(bad_ephemeral_array, "comparative-draws-v1.json")$valid,
  "Ephemeral person-time draw arrays must be null"
)
bad_ephemeral_missing <- rate_engine$draws
bad_ephemeral_missing$reference_draws <- NULL
assert_true(
  !validate_payload_against_schema(bad_ephemeral_missing, "comparative-draws-v1.json")$valid,
  "Ephemeral person-time draw arrays follow the explicit null policy"
)

cat("=== 1. Test Bayesian Posterior Semantics & Point Estimates ===\n")
set.seed(42)
S <- 2000L
t_draws <- rbeta(S, 15 + 0.5, 85 + 0.5)
r_draws <- rbeta(S, 5 + 0.5, 95 + 0.5)

bayes_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = 0.05
)

assert_true(bayes_res$schema_version == "comparative-evidence-v1", "Schema version is comparative-evidence-v1")
assert_true(bayes_res$inferential_semantics == "posterior", "Inferential semantics is posterior")
assert_true(bayes_res$risk_difference$estimate$source == "posterior_median", "RD estimate source is posterior_median")
assert_true(bayes_res$risk_difference$interval$method == "posterior_eti", "RD interval method is posterior_eti")
assert_true(bayes_res$direction_support$label == "P(RD > 0)", "Direction support label is P(RD > 0)")
assert_true(bayes_res$relative_risk$estimate$source == "posterior_median", "RR estimate source is posterior_median")
assert_true(bayes_res$relative_risk$interval$method == "posterior_eti", "RR interval method is posterior_eti")
assert_true(bayes_res$relative_risk$mean_is_finite == TRUE, "RR mean is finite when reference events > 0")

cat("\n=== 2. Test Bootstrap Semantics & Point Estimates ===\n")
boot_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "bootstrap",
  observed_estimates = list(rd = 0.10, rr = 3.0),
  primary_delta = 0.05
)

assert_true(boot_res$inferential_semantics == "bootstrap", "Inferential semantics is bootstrap")
assert_true(boot_res$risk_difference$estimate$source == "observed_sample_estimate", "RD estimate source is observed_sample_estimate")
assert_true(boot_res$risk_difference$estimate$value == 0.10, "RD estimate value matches observed estimate (0.10)")
assert_true(boot_res$risk_difference$interval$method == "bootstrap_percentile", "RD interval method is bootstrap_percentile")
assert_true(boot_res$direction_support$metric_name == "bootstrap_support_fraction_rd_gt_zero", "Metric name is bootstrap_support_fraction_rd_gt_zero")

cat("\n=== 3. Test Practical Region Invariant (q_T + q_N + q_R == 1.0) & U-Grade ===\n")
prs <- bayes_res$practical_region_support
assert_true(!is.null(prs), "Practical region support exists when primary_delta is set")
sum_q <- prs$target_excess + prs$practical_neutral + prs$reference_excess
assert_true(abs(sum_q - 1.0) < 1e-6, sprintf("Invariant holds: sum(q) = %.6f == 1.0", sum_q))
assert_true(bayes_res$resolution_grade$grade %in% c("U0", "U1", "U2", "U3"), "U-grade is within U0-U3")

cat("\n=== 4. Test primary_delta = NULL (mode: 'none') Disables Classification ===\n")
none_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 5L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = NULL
)
assert_true(is.null(none_res$practical_region_support), "practical_region_support is NULL when primary_delta=NULL")
assert_true(none_res$resolution_grade$grade == "NONE", "resolution_grade is NONE when primary_delta=NULL")

cat("\n=== 5. Test Zero-Reference Mathematical Integrity (mean = NULL, finite = FALSE) ===\n")
r_zero_draws <- rbeta(S, 0 + 0.5, 100 + 0.5)
zero_res <- compute_comparative_contrasts(
  target_draws = t_draws,
  reference_draws = r_zero_draws,
  target_events = 15L,
  target_total = 100L,
  reference_events = 0L,
  reference_total = 100L,
  inferential_semantics = "posterior",
  primary_delta = 0.05
)

assert_true(is.null(zero_res$relative_risk$mean), "RR mean is NULL for zero-reference")
assert_true(zero_res$relative_risk$mean_is_finite == FALSE, "RR mean_is_finite is FALSE for zero-reference")
assert_true(!is.null(zero_res$relative_risk$estimate$value), "RR median exists and is non-null for zero-reference")
assert_true(!is.null(zero_res$relative_risk$interval$lower), "RR lower interval bound exists for zero-reference")
assert_true(!is.null(zero_res$relative_risk$interval$upper), "RR upper interval bound exists for zero-reference")
assert_true("ZERO_REFERENCE" %in% zero_res$diagnostics$badges, "'ZERO_REFERENCE' badge present")

cat("\n=== 6. Test Delta-Profile Monotonicity ===\n")
# As delta increases, neutral region [-delta, delta] probability must be monotonically non-decreasing
dp <- bayes_res$delta_profile
assert_true(length(dp) >= 3, "Delta profile has >= 3 thresholds")
neu_probs <- vapply(dp, function(x) x$p_neutral, numeric(1L))
is_monotone <- all(diff(neu_probs) >= -1e-6)
assert_true(is_monotone, "p_neutral is monotonically non-decreasing as delta increases")

cat("\n=== 7. Test Terminology Separation & Lint Guard ===\n")
bayes_json <- jsonlite::toJSON(bayes_res, auto_unbox = TRUE)
boot_json <- jsonlite::toJSON(boot_res, auto_unbox = TRUE)

assert_true(!grepl("bootstrap_percentile", bayes_json), "Bayesian output contains NO 'bootstrap_percentile'")
assert_true(!grepl("bootstrap_support_fraction", bayes_json), "Bayesian output contains NO 'bootstrap_support_fraction'")
assert_true(!grepl("posterior_eti", boot_json), "Bootstrap output contains NO 'posterior_eti'")
assert_true(!grepl("posterior_median", boot_json), "Bootstrap output contains NO 'posterior_median'")

cat("\n=== 8. Pass 0 config/runtime parity and routing schema (QA-0001) ===\n")
# Runtime-only invariants (not expressible cleanly in Draft-07 alone):
# - subject_id_col, group_col, outcome_col must be pairwise distinct
# - target and reference labels must differ
# - declared cluster_cols / matched_cols must exist in the input data frame
source(".agents/shared/pass0_routing.R")

pass0_base <- list(
  domain = "safety",
  estimand = "RD",
  analysis_unit = "subject",
  target = "Drug_A",
  reference = "Placebo",
  design = "independent_binary",
  practical_difference = list(mode = "none", primary_delta = NULL, unit = "per_100"),
  reporting_purpose = "internal_safety_review",
  decision_review_flag = FALSE
)
pass0_valid_repeated <- pass0_base
pass0_valid_repeated$repeated_rows <- list(
  subject_id_col = "subject_id",
  group_col = "arm",
  outcome_col = "outcome",
  event_rule = "any_event",
  confirmed = TRUE,
  no_other_subject_dependence_confirmed = TRUE,
  cluster_cols = list("facility_id"),
  matched_cols = list()
)
assert_true(
  isTRUE(validate_pass0_config(pass0_valid_repeated)),
  "Valid repeated_rows config accepted by runtime validator"
)
assert_true(
  validate_payload_against_schema(pass0_valid_repeated, "pass0-config-v1.json")$valid,
  "Valid repeated_rows config accepted by Draft-07 schema"
)

pass0_invalid_extra <- pass0_valid_repeated
pass0_invalid_extra$repeated_rows$unknown_flag <- TRUE
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_invalid_extra), error = function(e) e), "error"),
  "Unexpected repeated_rows key rejected by runtime"
)
assert_true(
  !validate_payload_against_schema(pass0_invalid_extra, "pass0-config-v1.json")$valid,
  "Unexpected repeated_rows key rejected by Draft-07 schema"
)

pass0_invalid_dep_flag <- pass0_valid_repeated
pass0_invalid_dep_flag$repeated_rows$no_other_subject_dependence_confirmed <- FALSE
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_invalid_dep_flag), error = function(e) e), "error"),
  "False dependence confirmation rejected by runtime"
)
assert_true(
  !validate_payload_against_schema(pass0_invalid_dep_flag, "pass0-config-v1.json")$valid,
  "False dependence confirmation rejected by Draft-07 schema"
)

pass0_runtime_only_dup_cols <- pass0_valid_repeated
pass0_runtime_only_dup_cols$repeated_rows$group_col <- "subject_id"
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_runtime_only_dup_cols), error = function(e) e), "error"),
  "Runtime rejects non-distinct subject/group/outcome columns"
)
assert_true(
  validate_payload_against_schema(pass0_runtime_only_dup_cols, "pass0-config-v1.json")$valid,
  "Draft-07 intentionally allows duplicate column names (runtime-only invariant)"
)

tmp_route_csv <- tempfile(fileext = ".csv")
write.csv(data.frame(
  subject_id = c("T1", "T1", "T2", "R1", "R2"),
  arm = c("Drug_A", "Drug_A", "Drug_A", "Placebo", "Placebo"),
  outcome = c(0L, 1L, 0L, 1L, 0L),
  stringsAsFactors = FALSE
), tmp_route_csv, row.names = FALSE)
pass0_route_config <- pass0_valid_repeated
pass0_route_config$repeated_rows$cluster_cols <- NULL
pass0_route_config$repeated_rows$matched_cols <- NULL
route_payload <- generate_routing_decision(tmp_route_csv, pass0_route_config)
assert_true(
  validate_payload_against_schema(route_payload, "pass0-routing-v1.json")$valid,
  "Repeated-row routing artifact validates against pass0-routing-v1"
)
assert_true(
  !is.null(route_payload$engine_input) &&
    identical(route_payload$engine_input$contract, "independent_binary_counts_v1"),
  "Routing artifact includes canonical engine_input"
)

route_missing_engine <- route_payload
route_missing_engine$engine_input <- NULL
assert_true(
  !validate_payload_against_schema(route_missing_engine, "pass0-routing-v1.json")$valid,
  "Schema rejects repeated-row routing without engine_input"
)

cat("\n=== 9. QA0001.R6/R7 Draft-07 fidelity and R representation normalization ===\n")
# R7 contract: length-1 R character is an accepted native form for dependency column lists;
# canonical serialized JSON MUST remain a JSON array (never a bare string).

pass0_empty_cluster <- pass0_valid_repeated
pass0_empty_cluster$repeated_rows$cluster_cols <- list("")
assert_true(
  !validate_payload_against_schema(pass0_empty_cluster, "pass0-config-v1.json")$valid,
  "Local Draft-07 rejects empty dependency-column name (minLength)"
)
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_empty_cluster), error = function(e) e), "error"),
  "Runtime rejects empty dependency-column name"
)

pass0_dup_cluster <- pass0_valid_repeated
pass0_dup_cluster$repeated_rows$cluster_cols <- list("facility_id", "facility_id")
assert_true(
  !validate_payload_against_schema(pass0_dup_cluster, "pass0-config-v1.json")$valid,
  "Local Draft-07 rejects duplicate cluster_cols (uniqueItems)"
)
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_dup_cluster), error = function(e) e), "error"),
  "Runtime rejects duplicate cluster_cols"
)

pass0_dup_matched <- pass0_valid_repeated
pass0_dup_matched$repeated_rows$cluster_cols <- NULL
pass0_dup_matched$repeated_rows$matched_cols <- list("pair_id", "pair_id")
assert_true(
  !validate_payload_against_schema(pass0_dup_matched, "pass0-config-v1.json")$valid,
  "Local Draft-07 rejects duplicate matched_cols (uniqueItems)"
)
assert_true(
  inherits(tryCatch(validate_pass0_config(pass0_dup_matched), error = function(e) e), "error"),
  "Runtime rejects duplicate matched_cols"
)

native_one <- "custom_site"
normalized_one <- normalize_declared_cols(native_one, "cluster_cols")
assert_true(
  identical(normalized_one, "custom_site"),
  "Length-1 R character is accepted as native dependency-column representation"
)
canonical_array_json <- as.character(jsonlite::toJSON(as.list(normalized_one), auto_unbox = TRUE))
assert_true(
  identical(canonical_array_json, '["custom_site"]'),
  "Canonical serialization of one dependency column is a JSON array"
)
roundtrip_cfg <- pass0_valid_repeated
roundtrip_cfg$repeated_rows$cluster_cols <- as.list(normalized_one)
roundtrip_cfg$repeated_rows$matched_cols <- NULL
assert_true(
  validate_payload_against_schema(roundtrip_cfg, "pass0-config-v1.json")$valid,
  "Round-trip array serialization validates against pass0-config-v1"
)
unboxed_string_json <- as.character(jsonlite::toJSON(normalized_one, auto_unbox = TRUE))
assert_true(
  identical(unboxed_string_json, '"custom_site"'),
  "Bare auto_unbox string form is distinguishable from canonical array form"
)

validate_with_python_draft7 <- function(payload, schema_path, python_bin, vendor_dir = NULL) {
  payload_file <- tempfile(fileext = ".json")
  script_file <- tempfile(fileext = ".py")
  writeLines(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", pretty = TRUE), payload_file)
  vendor_insert <- if (!is.null(vendor_dir) && dir.exists(vendor_dir)) {
    sprintf("import sys\nsys.path.insert(0, %s)", jsonlite::toJSON(normalizePath(vendor_dir), auto_unbox = TRUE))
  } else {
    "pass"
  }
  writeLines(c(
    vendor_insert,
    "import json, sys",
    "from jsonschema import Draft7Validator",
    "from pathlib import Path",
    sprintf("schema = json.loads(Path(%s).read_text())", jsonlite::toJSON(normalizePath(schema_path), auto_unbox = TRUE)),
    sprintf("payload = json.loads(Path(%s).read_text())", jsonlite::toJSON(normalizePath(payload_file), auto_unbox = TRUE)),
    "errors = list(Draft7Validator(schema).iter_errors(payload))",
    "sys.exit(0 if not errors else 1)"
  ), script_file)
  status <- system2(python_bin, script_file, stdout = FALSE, stderr = FALSE)
  list(
    valid = identical(as.integer(status), 0L),
    detail = sprintf("exit_status=%s", as.character(status))
  )
}

schema_cfg_path <- "schemas/pass0-config-v1.json"
py_bin <- Sys.which("python3")
local_vendor <- file.path(getwd(), ".tmp_jsonschema")
probe_script <- tempfile(fileext = ".py")
if (dir.exists(local_vendor)) {
  writeLines(c(
    sprintf("import sys; sys.path.insert(0, %s)", jsonlite::toJSON(normalizePath(local_vendor), auto_unbox = TRUE)),
    "import jsonschema"
  ), probe_script)
} else {
  writeLines("import jsonschema", probe_script)
}
py_probe <- if (nzchar(py_bin)) {
  system2(py_bin, probe_script, stdout = FALSE, stderr = FALSE)
} else {
  1L
}
py_available <- nzchar(py_bin) && identical(as.integer(py_probe), 0L)
py_cases <- list(
  list(name = "empty_cluster", payload = pass0_empty_cluster, expect_valid = FALSE),
  list(name = "dup_cluster", payload = pass0_dup_cluster, expect_valid = FALSE),
  list(name = "dup_matched", payload = pass0_dup_matched, expect_valid = FALSE),
  list(name = "roundtrip_array", payload = roundtrip_cfg, expect_valid = TRUE)
)
if (!py_available) {
  cat("[WARN] Real Draft-07 (Python jsonschema) unavailable; local-only negative fixtures recorded.\n")
  assert_true(TRUE, "Real Draft-07 cross-check skipped with explicit WARN (environment limitation)")
} else {
  cat("[INFO] Real Draft-07 (Python jsonschema) available; cross-checking fixtures.\n")
  for (case in py_cases) {
    local_valid <- validate_payload_against_schema(case$payload, "pass0-config-v1.json")$valid
    py <- validate_with_python_draft7(
      case$payload, schema_cfg_path, py_bin,
      vendor_dir = if (dir.exists(local_vendor)) local_vendor else NULL
    )
    assert_true(
      identical(local_valid, case$expect_valid) && identical(py$valid, case$expect_valid),
      sprintf(
        "Local and Python Draft-07 agree on %s (expect_valid=%s)",
        case$name, case$expect_valid
      )
    )
  }
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
