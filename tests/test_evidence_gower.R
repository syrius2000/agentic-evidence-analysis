# tests/test_evidence_gower.R — Section 13 Phase B task 13.4 (+ QA R1–R3)

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

source(".agents/shared/independent_beta_binomial.R")
source(".agents/shared/evidence_feature_extract.R")
source(".agents/shared/evidence_gower.R")

approx_eq <- function(a, b, tol = 1e-10) isTRUE(abs(as.numeric(a) - as.numeric(b)) <= tol)

# Minimal evidence-feature fixture for deterministic numeric Gower tests (no Bayesian engine).
minimal_feat <- function(rd_estimate, schema_ver = EVIDENCE_FEATURE_SCHEMA_VERSION,
                         keys = c("rd_estimate", "resolution_grade"),
                         resolution_grade = "U0") {
  list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = schema_ver,
    core = list(
      rd_estimate = rd_estimate,
      resolution_grade = resolution_grade
    ),
    delta_dependent = list(present = FALSE),
    clustering_feature_keys = as.list(keys)
  )
}

tiny_range <- function(features = list(
                         rd_estimate = list(type = "numeric", min = -1.0, max = 1.0),
                         resolution_grade = list(type = "categorical", levels = list("U0", "U1", "U2", "U3", "NONE"))
                       )) {
  list(
    schema_version = "frozen-reference-range-v1",
    range_version = "test-1.0.0",
    feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION,
    features = features
  )
}

cat("=== 13.4 Frozen reference range load ===\n")
fr <- load_frozen_reference_range()
assert_true(
  identical(fr$schema_version, "frozen-reference-range-v1"),
  "Default frozen range loads"
)
assert_true(identical(fr$range_version, "1.0.0"), "Default range_version is 1.0.0")
assert_true(
  identical(fr$feature_schema_version, EVIDENCE_FEATURE_SCHEMA_VERSION),
  "Frozen range binds feature_schema_version"
)

assert_error_code(
  assert_frozen_reference_range(list(
    schema_version = "frozen-reference-range-v1",
    range_version = "x",
    feature_schema_version = "1.0.0",
    features = list(rd_estimate = list(type = "numeric", min = 0, max = 0))
  )),
  "ZERO_FROZEN_RANGE",
  "Rejects zero-width numeric frozen range"
)

cat("=== 13.4 Exact OpenSpec numeric overflow formula ===\n")
tr <- tiny_range()
# range [-1,1], R=2
cases <- list(
  list(a = 0.2, b = 0.0, d = 0.1, warn = FALSE, label = "0.2 vs 0.0 -> 0.1"),
  list(a = 5.0, b = 0.0, d = 1.0, warn = TRUE, label = "5.0 vs 0.0 -> 1.0 + warning"),
  list(a = 5.0, b = 3.0, d = 1.0, warn = TRUE, label = "5.0 vs 3.0 -> 1.0 + warning (no collapse)"),
  list(a = 5.0, b = 5.0, d = 0.0, warn = TRUE, label = "5.0 vs 5.0 -> 0.0 + warning"),
  list(a = -5.0, b = 5.0, d = 1.0, warn = TRUE, label = "-5.0 vs 5.0 -> 1.0 + warning")
)
for (cs in cases) {
  res <- gower_pairwise_distance(
    minimal_feat(cs$a), minimal_feat(cs$b), tr,
    keys = "rd_estimate"
  )
  assert_true(approx_eq(res$distance, cs$d), paste0("Exact distance: ", cs$label))
  has_warn <- "GOWER_REFERENCE_RANGE_EXCEEDED" %in% res$warnings
  assert_true(
    identical(has_warn, cs$warn),
    paste0("Warning contract: ", cs$label)
  )
}

cat("=== 13.4 Pairwise Gower contracts ===\n")
engine_a <- run_independent_beta_binomial(12, 100, 4, 100, seed = 21L, primary_delta = 0.05)
engine_b <- run_independent_beta_binomial(20, 100, 4, 100, seed = 22L, primary_delta = 0.05)
feat_a <- extract_evidence_features(engine_a$evidence)
feat_b <- extract_evidence_features(engine_b$evidence)

self <- gower_pairwise_distance(feat_a, feat_a, fr)
assert_true(approx_eq(self$distance, 0), "Self-distance is 0")
assert_true(length(self$warnings) == 0L, "Self-distance emits no overflow warnings")

cross <- gower_pairwise_distance(feat_a, feat_b, fr)
assert_true(
  cross$distance > 0 && cross$distance <= 1,
  "Cross-distance is in (0, 1]"
)
assert_true(cross$n_features_used >= 9L, "Uses shared clustering features")
assert_true(
  identical(cross$range_version, fr$range_version),
  "Pairwise result exposes range_version"
)

only_width <- gower_pairwise_distance(
  feat_a, feat_b, fr,
  keys = "rd_interval_width"
)
assert_true(only_width$n_features_used == 1L, "Key filter isolates one feature")
assert_true(only_width$distance <= 1, "Numeric contribution never exceeds 1")

feat_mismatch <- feat_a
feat_mismatch$core$resolution_grade <- if (identical(feat_a$core$resolution_grade, "U0")) "U3" else "U0"
cat_only <- gower_pairwise_distance(
  feat_a, feat_mismatch, fr,
  keys = "resolution_grade"
)
assert_true(approx_eq(cat_only$distance, 1), "Categorical mismatch contributes 1")

cat("=== 13.4 Overflow contribution clipping + warning ===\n")
feat_over <- feat_a
feat_over$core$rd_estimate <- 5.0 # outside [-1, 1]
over <- gower_pairwise_distance(feat_over, feat_a, fr, keys = "rd_estimate")
assert_true(
  "GOWER_REFERENCE_RANGE_EXCEEDED" %in% over$warnings,
  "Overflow emits GOWER_REFERENCE_RANGE_EXCEEDED"
)
# OpenSpec: min(1, |5 - rd_a|/2) == 1 for typical in-range rd_a
assert_true(approx_eq(over$distance, 1), "Overflow vs in-range yields contribution 1")

feat_bad_grade <- feat_a
feat_bad_grade$core$resolution_grade <- "NOT_A_GRADE"
bad_grade <- gower_pairwise_distance(feat_bad_grade, feat_a, fr, keys = "resolution_grade")
assert_true(
  "GOWER_REFERENCE_RANGE_EXCEEDED" %in% bad_grade$warnings,
  "Unknown categorical level emits GOWER_REFERENCE_RANGE_EXCEEDED"
)
assert_true(
  approx_eq(bad_grade$distance, 1),
  "Unknown categorical level mismatches known level"
)

cat("=== 13.4 Frozen-range coverage Fail-Fast ===\n")
# Implicit keys=NULL: shared clustering keys must all have range entries
fr_gap <- fr
fr_gap$features$direction_support <- NULL
assert_error_code(
  gower_pairwise_distance(feat_a, feat_b, fr_gap),
  "FROZEN_RANGE_MISSING_FEATURE",
  "keys=NULL rejects when a shared clustering key lacks frozen range"
)

assert_error_code(
  gower_pairwise_distance(
    feat_a, feat_b, fr,
    keys = c("rd_estimate", "not_in_range")
  ),
  "FROZEN_RANGE_MISSING_FEATURE",
  "Explicit keys reject when any requested key lacks frozen range"
)

# Explicit valid subset with all range entries present → accept
subset_ok <- gower_pairwise_distance(
  feat_a, feat_b, fr,
  keys = c("rd_estimate", "resolution_grade")
)
assert_true(
  subset_ok$n_features_used == 2L &&
    identical(sort(subset_ok$keys_used), c("rd_estimate", "resolution_grade")),
  "Explicit valid subset is accepted"
)

assert_error_code(
  gower_pairwise_distance(feat_a, feat_b, fr, keys = "not_a_key"),
  "FROZEN_RANGE_MISSING_FEATURE",
  "Unknown explicit key Fail-Fast (missing range)"
)

cat("=== 13.4 Matrix + pre-loop validation ===\n")
mat_res <- gower_distance_matrix(list(feat_a, feat_b, feat_a), fr)
assert_true(
  nrow(mat_res$matrix) == 3L && ncol(mat_res$matrix) == 3L,
  "Distance matrix is square"
)
assert_true(
  approx_eq(mat_res$matrix[1, 1], 0) && approx_eq(mat_res$matrix[1, 3], 0),
  "Matrix diagonal and identical rows are 0"
)
assert_true(
  approx_eq(mat_res$matrix[1, 2], mat_res$matrix[2, 1]),
  "Matrix is symmetric"
)

# Single-item: valid → 1x1 zero after validation
single_ok <- gower_distance_matrix(list(minimal_feat(0.1)), tr, keys = "rd_estimate")
assert_true(
  nrow(single_ok$matrix) == 1L && approx_eq(single_ok$matrix[1, 1], 0) &&
    length(single_ok$warnings) == 0L,
  "n=1 valid feature returns 1x1 zero matrix"
)

feat_ver <- minimal_feat(0.1, schema_ver = "9.9.9")
assert_error_code(
  gower_distance_matrix(list(feat_ver), tr, keys = "rd_estimate"),
  "FEATURE_SCHEMA_VERSION_MISMATCH",
  "n=1 wrong feature_schema_version Fail-Fast"
)

assert_error_code(
  gower_distance_matrix(
    list(minimal_feat(0.1)),
    list(
      schema_version = "frozen-reference-range-v1",
      range_version = "x",
      feature_schema_version = EVIDENCE_FEATURE_SCHEMA_VERSION,
      features = list(rd_estimate = list(type = "numeric", min = 0, max = 0))
    ),
    keys = "rd_estimate"
  ),
  "ZERO_FROZEN_RANGE",
  "n=1 malformed frozen range Fail-Fast"
)

single_over <- gower_distance_matrix(list(minimal_feat(5.0)), tr, keys = "rd_estimate")
assert_true(
  approx_eq(single_over$matrix[1, 1], 0) &&
    "GOWER_REFERENCE_RANGE_EXCEEDED" %in% single_over$warnings,
  "n=1 out-of-range emits GOWER_REFERENCE_RANGE_EXCEEDED with zero diagonal"
)

feat_ver_pair <- feat_a
feat_ver_pair$feature_schema_version <- "9.9.9"
assert_error_code(
  gower_pairwise_distance(feat_ver_pair, feat_b, fr),
  "FEATURE_SCHEMA_VERSION_MISMATCH",
  "feature_schema_version mismatch Fail-Fast"
)

# Null numeric feature skipped (Gower availability)
feat_null_n <- feat_a
feat_null_n$core["target_n"] <- list(NULL)
feat_null_n2 <- feat_b
feat_null_n2$core["target_n"] <- list(NULL)
skip_n <- gower_pairwise_distance(feat_null_n, feat_null_n2, fr, keys = c("target_n", "rd_estimate"))
assert_true(
  identical(skip_n$keys_used, "rd_estimate"),
  "Null numeric features are skipped; remaining keys used"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
