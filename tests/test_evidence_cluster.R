# tests/test_evidence_cluster.R — Section 13 Phase B tasks 13.5 / 13.6 / 13.14

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
source(".agents/shared/evidence_cluster.R")

approx_eq <- function(a, b, tol = 1e-10) isTRUE(abs(as.numeric(a) - as.numeric(b)) <= tol)

minimal_feat <- function(rd_estimate, schema_ver = EVIDENCE_FEATURE_SCHEMA_VERSION,
                         resolution_grade = "U0") {
  list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = schema_ver,
    core = list(
      rd_estimate = rd_estimate,
      resolution_grade = resolution_grade
    ),
    delta_dependent = list(present = FALSE),
    clustering_feature_keys = list("rd_estimate", "resolution_grade")
  )
}

# Canonical full evidence-feature-v1 for 13.13 refit callback (13.13.R3)
canonical_feat <- function(rd_estimate, schema_ver = EVIDENCE_FEATURE_SCHEMA_VERSION,
                           resolution_grade = "U0") {
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
    delta_dependent = list(
      present = FALSE,
      primary_delta = NULL,
      target_excess = NULL,
      practical_neutral = NULL,
      reference_excess = NULL
    ),
    clustering_feature_keys = as.list(CORE_CLUSTERING_KEYS)
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

cat("=== 13.5 Deterministic HAC on known distance matrix ===\n")
# Three points on a line: A--1--B--1--C  => average linkage merges A-B then with C
mat <- matrix(c(
  0, 1, 2,
  1, 0, 1,
  2, 1, 0
), nrow = 3, byrow = TRUE)
hc <- evidence_hclust(mat, labels = c("A", "B", "C"), linkage = "average", k = 2L)
assert_true(identical(hc$linkage, "average"), "Default/explicit linkage is average")
assert_true(identical(hc$partition_mode, "fixed_k"), "Partition mode is fixed_k")
assert_true(identical(hc$k, 2L), "k is recorded")
assert_true(identical(hc$method, "hierarchical_agglomerative"), "Method tag set")
assert_true(isTRUE(hc$exploratory_only) && isFALSE(hc$decision_rule), "Exploratory-only contract")
assert_true(
  identical(hc$stability_status, "NOT_ASSESSED") &&
    identical(hc$stability_reason, "CROSS_THEME_DEPENDENCE_UNAVAILABLE"),
  "Stability stub is NOT_ASSESSED"
)
assert_true(
  grepl("exploratory", hc$wording, ignore.case = TRUE) &&
    grepl("never regulatory", hc$wording, ignore.case = TRUE),
  "Wording denies regulatory decision use"
)
assert_true(length(hc$assignments) == 3L, "Assignments length equals n")
assert_true(
  length(unique(hc$assignments)) == 2L,
  "cutree(k=2) yields exactly 2 clusters"
)
# A and B are closest; they should share a cluster when k=2
assert_true(
  identical(hc$assignment_labels[["A"]], hc$assignment_labels[["B"]]) &&
    !identical(hc$assignment_labels[["A"]], hc$assignment_labels[["C"]]),
  "A-B merge before attaching C at k=2"
)

cat("=== 13.5 Fail-Fast contracts ===\n")
assert_error_code(
  evidence_hclust(matrix(0, 1, 1), k = 1L),
  "INSUFFICIENT_CASES_FOR_CLUSTERING",
  "n=1 rejected"
)
assert_error_code(
  evidence_hclust(mat, linkage = "average", k = NULL),
  "MISSING_CLUSTER_K",
  "Missing k rejected"
)
assert_error_code(
  evidence_hclust(mat, linkage = "average", k = 1L),
  "INVALID_CLUSTER_K",
  "k=1 rejected"
)
assert_error_code(
  evidence_hclust(mat, linkage = "average", k = 4L),
  "INVALID_CLUSTER_K",
  "k > n rejected"
)
assert_error_code(
  evidence_hclust(mat, linkage = "ward.D2", k = 2L),
  "UNSUPPORTED_HCLUST_LINKAGE",
  "Ward linkage rejected for Gower path"
)
assert_error_code(
  evidence_hclust(mat, linkage = "foo", k = 2L),
  "INVALID_HCLUST_LINKAGE",
  "Unknown linkage rejected"
)
bad <- mat
bad[1, 2] <- 9
assert_error_code(
  evidence_hclust(bad, k = 2L),
  "INVALID_DISTANCE_MATRIX",
  "Asymmetric matrix rejected"
)

cat("=== 13.5.R1 Strict cluster label validation ===\n")
assert_error_code(
  evidence_hclust(mat, labels = c("A", NA_character_, "C"), k = 2L),
  "INVALID_CLUSTER_LABELS",
  "NA label rejected"
)
assert_error_code(
  evidence_hclust(mat, labels = c("A", "", "C"), k = 2L),
  "INVALID_CLUSTER_LABELS",
  "Empty string label rejected"
)
assert_error_code(
  evidence_hclust(mat, labels = c("A", "   ", "C"), k = 2L),
  "INVALID_CLUSTER_LABELS",
  "Whitespace-only label rejected"
)
assert_error_code(
  evidence_hclust(mat, labels = c("A", "A", "C"), k = 2L),
  "INVALID_CLUSTER_LABELS",
  "Duplicate label rejected"
)

cat("=== 13.5 Gower + HAC integration ===\n")
feats <- list(
  minimal_feat(0.0),
  minimal_feat(0.05),
  minimal_feat(0.9),
  minimal_feat(0.95)
)
cl <- cluster_evidence_features(
  feats, tiny_range,
  keys = "rd_estimate",
  labels = c("near1", "near2", "far1", "far2"),
  linkage = "average",
  k = 2L
)
assert_true(identical(cl$range_version, tiny_range$range_version), "Propagates range_version")
assert_true(identical(cl$n_cases, 4L) && identical(cl$k, 2L), "n and k recorded")
assert_true(identical(cl$distance_metric, "gower"), "Distance metric recorded as gower")
assert_true(
  identical(cl$gower_feature_keys, "rd_estimate"),
  "13.5.R2 explicit keys subset persisted in clustering provenance"
)
assert_true(
  identical(cl$assignment_labels[["near1"]], cl$assignment_labels[["near2"]]) &&
    identical(cl$assignment_labels[["far1"]], cl$assignment_labels[["far2"]]) &&
    !identical(cl$assignment_labels[["near1"]], cl$assignment_labels[["far1"]]),
  "Near pair and far pair form two clusters"
)

cat("=== 13.5.R2 Default resolved Gower keys in provenance ===\n")
cl_default <- cluster_evidence_features(
  feats, tiny_range,
  keys = NULL,
  labels = c("near1", "near2", "far1", "far2"),
  k = 2L
)
assert_true(
  identical(sort(cl_default$gower_feature_keys), sort(c("rd_estimate", "resolution_grade"))),
  "keys=NULL records resolved shared clustering feature keys"
)
gower_only <- gower_distance_matrix(feats, tiny_range, keys = NULL)
assert_true(
  identical(sort(gower_only$keys_used), sort(c("rd_estimate", "resolution_grade"))),
  "gower_distance_matrix exposes keys_used"
)

# Engine-backed smoke (default frozen range)
fr <- load_frozen_reference_range()
ea <- extract_evidence_features(
  run_independent_beta_binomial(12, 100, 4, 100, seed = 31L, primary_delta = 0.05)$evidence
)
eb <- extract_evidence_features(
  run_independent_beta_binomial(40, 100, 4, 100, seed = 32L, primary_delta = 0.05)$evidence
)
ec <- extract_evidence_features(
  run_independent_beta_binomial(13, 100, 5, 100, seed = 33L, primary_delta = 0.05)$evidence
)
cl2 <- cluster_evidence_features(list(ea, eb, ec), fr, k = 2L)
assert_true(
  length(unique(cl2$assignments)) == 2L && isTRUE(cl2$exploratory_only),
  "Engine-backed 3-case HAC with k=2 succeeds"
)

assert_error_code(
  cluster_evidence_features(list(ea), fr, k = 2L),
  "INSUFFICIENT_CASES_FOR_CLUSTERING",
  "Wrapper rejects single feature list"
)

cat("=== 13.6 Standardized K-means (continuous only) ===\n")
km_feats <- list(
  minimal_feat(0.0),
  minimal_feat(0.05),
  minimal_feat(0.90),
  minimal_feat(0.95)
)
km <- evidence_kmeans(
  km_feats, tiny_range,
  keys = "rd_estimate",
  labels = c("near1", "near2", "far1", "far2"),
  k = 2L,
  seed = 42L
)
assert_true(identical(km$method, "kmeans_standardized"), "K-means method tag set")
assert_true(identical(km$partition_mode, "fixed_k"), "K-means partition mode is fixed_k")
assert_true(isTRUE(km$scaled), "K-means records scaled=TRUE")
assert_true(identical(km$feature_keys, "rd_estimate"), "K-means uses continuous key only")
assert_true(identical(km$nstart, EVIDENCE_KMEANS_DEFAULT_NSTART), "Default nstart recorded")
assert_true(identical(km$seed, 42L), "Seed recorded in provenance")
assert_true(
  length(unique(km$assignments)) == 2L &&
    identical(km$assignment_labels[["near1"]], km$assignment_labels[["near2"]]) &&
    identical(km$assignment_labels[["far1"]], km$assignment_labels[["far2"]]) &&
    !identical(km$assignment_labels[["near1"]], km$assignment_labels[["far1"]]),
  "K-means separates near and far pairs at k=2"
)
assert_true(
  is.finite(km$scale_center[["rd_estimate"]]) &&
    is.finite(km$scale_scale[["rd_estimate"]]) &&
    km$scale_scale[["rd_estimate"]] > 0,
  "Scale center/scale provenance present and positive"
)

km_auto <- evidence_kmeans(
  km_feats, tiny_range,
  keys = NULL,
  labels = c("near1", "near2", "far1", "far2"),
  k = 2L,
  seed = 7L
)
assert_true(
  identical(km_auto$feature_keys, "rd_estimate"),
  "keys=NULL auto-filters to numeric features (drops categorical)"
)

cat("=== 13.6 Fail-Fast contracts ===\n")
assert_error_code(
  evidence_kmeans(km_feats, tiny_range, keys = c("rd_estimate", "resolution_grade"), k = 2L),
  "KMEANS_NON_CONTINUOUS_FEATURE",
  "Explicit categorical key rejected"
)
assert_error_code(
  evidence_kmeans(list(minimal_feat(0.1)), tiny_range, keys = "rd_estimate", k = 2L),
  "INSUFFICIENT_CASES_FOR_CLUSTERING",
  "K-means rejects n=1"
)
assert_error_code(
  evidence_kmeans(km_feats, tiny_range, keys = "rd_estimate", k = NULL),
  "MISSING_CLUSTER_K",
  "K-means missing k rejected"
)
assert_error_code(
  evidence_kmeans(km_feats, tiny_range, keys = "rd_estimate", k = 1L),
  "INVALID_CLUSTER_K",
  "K-means k=1 rejected"
)
zero_var_feats <- list(
  minimal_feat(0.25),
  minimal_feat(0.25),
  minimal_feat(0.25),
  minimal_feat(0.25)
)
assert_error_code(
  evidence_kmeans(zero_var_feats, tiny_range, keys = "rd_estimate", k = 2L),
  "KMEANS_ZERO_VARIANCE_FEATURE",
  "Zero-variance feature rejected before scaling"
)

cat("=== 13.6.R1 Distinct standardized case count ===\n")
dup_feats <- list(
  minimal_feat(0.0),
  minimal_feat(0.0),
  minimal_feat(1.0),
  minimal_feat(1.0)
)
km_dup_ok <- evidence_kmeans(
  dup_feats, tiny_range,
  keys = "rd_estimate",
  labels = c("a1", "a2", "b1", "b2"),
  k = 2L,
  seed = 11L
)
assert_true(
  identical(km_dup_ok$n_distinct_cases, 2L) && length(unique(km_dup_ok$assignments)) == 2L,
  "[0,0,1,1] k=2 accepted; n_distinct_cases=2"
)
assert_error_code(
  evidence_kmeans(
    dup_feats, tiny_range,
    keys = "rd_estimate",
    labels = c("a1", "a2", "b1", "b2"),
    k = 3L
  ),
  "KMEANS_INSUFFICIENT_DISTINCT_CASES",
  "[0,0,1,1] k=3 project Fail-Fast (not base-R leak)"
)

# Engine-backed continuous-only smoke (default frozen range)
km2 <- evidence_kmeans(list(ea, eb, ec), fr, k = 2L, seed = 99L)
assert_true(
  length(unique(km2$assignments)) == 2L &&
    isTRUE(km2$exploratory_only) &&
    !("resolution_grade" %in% km2$feature_keys),
  "Engine-backed K-means uses continuous keys only"
)

cat("=== 13.14 Governance: assignment never triggers regulatory action ===\n")
assert_true(
  isTRUE(tryCatch(
    {
      assert_cluster_assignment_non_regulatory(hc)
      TRUE
    },
    error = function(e) FALSE
  )),
  "HAC result passes non-regulatory assertion"
)
assert_true(
  isTRUE(tryCatch(
    {
      assert_cluster_assignment_non_regulatory(km)
      TRUE
    },
    error = function(e) FALSE
  )),
  "K-means result passes non-regulatory assertion"
)
assert_true(
  isTRUE(hc$exploratory_only) && isFALSE(hc$decision_rule) &&
    isTRUE(km$exploratory_only) && isFALSE(km$decision_rule),
  "Both methods expose exploratory_only=TRUE and decision_rule=FALSE"
)
forbidden_hit_hc <- intersect(tolower(names(hc)), tolower(EVIDENCE_CLUSTER_FORBIDDEN_RESULT_KEYS))
forbidden_hit_km <- intersect(tolower(names(km)), tolower(EVIDENCE_CLUSTER_FORBIDDEN_RESULT_KEYS))
assert_true(
  length(forbidden_hit_hc) == 0L && length(forbidden_hit_km) == 0L,
  "Neither result contains forbidden regulatory keys"
)
assert_error_code(
  promote_cluster_to_regulatory_action(km),
  "CLUSTER_ASSIGNMENT_NOT_REGULATORY",
  "Promotion API always refuses regulatory action"
)
assert_error_code(
  promote_cluster_to_regulatory_action(hc, decision = "approve"),
  "CLUSTER_ASSIGNMENT_NOT_REGULATORY",
  "Promotion API refuses even with decision argument"
)

cat("=== 13.13 Cluster stability NOT_ASSESSED / patient bootstrap ===\n")
stab_na <- assess_cluster_stability(patient_rows = NULL)
assert_true(
  identical(stab_na$stability_status, "NOT_ASSESSED") &&
    identical(stab_na$stability_reason, "CROSS_THEME_DEPENDENCE_UNAVAILABLE"),
  "NULL patient_rows => NOT_ASSESSED"
)
assert_true(is.null(stab_na$mean_co_clustering), "NOT_ASSESSED has no mean co-clustering")

# patient_rows without refit_features must not claim ASSESSED (13.13.R1)
stab_no_refit <- assess_cluster_stability(
  patient_rows = data.frame(
    subject_id = c("S1", "S2"),
    unit_id = c("A", "B"),
    stringsAsFactors = FALSE
  ),
  refit_features = NULL,
  frozen_range = tiny_range
)
assert_true(
  identical(stab_no_refit$stability_status, "NOT_ASSESSED"),
  "patient_rows without refit_features => NOT_ASSESSED"
)

# Cross-theme patient rows: same subject appears in multiple units
patient_meas <- data.frame(
  subject_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
  unit_id = c("A", "B", "A", "C", "B", "C"),
  rd = c(0.05, 0.06, 0.08, 0.55, 0.07, 0.60),
  stringsAsFactors = FALSE
)
refit_calls <- 0L
last_sampled <- NULL
refit_features <- function(sampled_subject_ids) {
  refit_calls <<- refit_calls + 1L
  last_sampled <<- sampled_subject_ids
  # Preserve multiplicity: expand all rows for each draw
  rows <- do.call(rbind, lapply(sampled_subject_ids, function(s) {
    patient_meas[patient_meas$subject_id == s, , drop = FALSE]
  }))
  out <- list()
  for (u in c("A", "B", "C")) {
    sub <- rows[rows$unit_id == u, , drop = FALSE]
    if (nrow(sub) < 1L) next
    out[[u]] <- canonical_feat(mean(sub$rd))
  }
  out
}

gower_keys_13_13 <- c("rd_estimate", "resolution_grade")

stab <- assess_cluster_stability(
  patient_rows = patient_meas[, c("subject_id", "unit_id")],
  refit_features = refit_features,
  frozen_range = tiny_range,
  labels = c("A", "B", "C"),
  linkage = "average",
  k = 2L,
  n_bootstrap = 15L,
  seed = 42L,
  keys = gower_keys_13_13
)
assert_true(identical(stab$stability_status, "ASSESSED"), "Full patient refit => ASSESSED")
assert_true(refit_calls >= 1L, "refit_features invoked at least once")
assert_true(
  !is.null(last_sampled) && length(last_sampled) == length(unique(patient_meas$subject_id)),
  "Bootstrap samples subject IDs (with replacement length = n_subjects)"
)
assert_true(
  is.numeric(stab$mean_co_clustering) && is.finite(stab$mean_co_clustering) &&
    stab$mean_co_clustering >= 0 && stab$mean_co_clustering <= 1,
  "mean_co_clustering in [0,1]"
)
assert_true(
  is.matrix(stab$pair_co_clustering) &&
    identical(dim(stab$pair_co_clustering), c(3L, 3L)),
  "pair_co_clustering is n x n"
)
assert_true(
  identical(as.integer(stab$n_bootstrap_usable) + as.integer(stab$n_bootstrap_failed), 15L),
  "usable + failed equals requested bootstrap"
)
assert_true(identical(stab$unit_ids, c("A", "B", "C")), "unit_ids provenance recorded")

hc_base <- evidence_hclust(mat, labels = c("A", "B", "C"), linkage = "average", k = 2L)
hc2 <- attach_cluster_stability(hc_base, stab)
assert_true(identical(hc2$stability_status, "ASSESSED"), "attach_cluster_stability updates status")
assert_true(
  is.numeric(hc2$stability_mean_co_clustering) &&
    identical(hc2$stability_method, "patient_bootstrap_co_clustering"),
  "attach exposes stability summary fields"
)
assert_true(
  isTRUE(tryCatch(
    {
      assert_cluster_assignment_non_regulatory(hc2)
      TRUE
    },
    error = function(e) FALSE
  )),
  "ASSESSED cluster result remains non-regulatory"
)

hc3 <- attach_cluster_stability(hc_base, stab_na)
assert_true(
  identical(hc3$stability_status, "NOT_ASSESSED") &&
    identical(hc3$stability_reason, "CROSS_THEME_DEPENDENCE_UNAVAILABLE"),
  "Can re-attach NOT_ASSESSED"
)

cat("=== 13.13.R2 attach provenance compatibility ===\n")
assert_error_code(
  attach_cluster_stability(hc_base, within(stab, {
    k <- 3L
  })),
  "STABILITY_ATTACH_INCOMPATIBLE",
  "mismatched k rejected"
)
assert_error_code(
  attach_cluster_stability(hc_base, within(stab, {
    n_units <- 99L
  })),
  "STABILITY_ATTACH_INCOMPATIBLE",
  "mismatched n rejected"
)
assert_error_code(
  attach_cluster_stability(hc_base, within(stab, {
    linkage <- "complete"
  })),
  "STABILITY_ATTACH_INCOMPATIBLE",
  "mismatched linkage rejected"
)
bad_labels <- stab
bad_labels$unit_ids <- c("X", "Y", "Z")
bad_labels$pair_co_clustering <- {
  m <- stab$pair_co_clustering
  dimnames(m) <- list(c("X", "Y", "Z"), c("X", "Y", "Z"))
  m
}
assert_error_code(
  attach_cluster_stability(hc_base, bad_labels),
  "STABILITY_ATTACH_INCOMPATIBLE",
  "mismatched labels rejected"
)
assert_error_code(
  attach_cluster_stability(km, stab),
  "STABILITY_ATTACH_INCOMPATIBLE",
  "ASSESSED stability cannot attach to kmeans result"
)

assert_error_code(
  assess_cluster_stability(
    patient_rows = patient_meas[, c("subject_id", "unit_id")],
    refit_features = refit_features,
    frozen_range = tiny_range,
    labels = c("A", "B", "C"),
    k = 2L,
    n_bootstrap = 0L,
    keys = gower_keys_13_13
  ),
  "INVALID_STABILITY_BOOTSTRAP",
  "n_bootstrap < 1 rejected"
)

cat("=== 13.13.R3 canonical refit feature enforcement ===\n")
assert_true(
  isTRUE(tryCatch(
    {
      assert_evidence_feature_v1(canonical_feat(0.1))
      TRUE
    },
    error = function(e) FALSE
  )),
  "canonical_feat passes assert_evidence_feature_v1"
)
assert_error_code(
  assert_evidence_feature_v1(minimal_feat(0.1)),
  "INVALID_EVIDENCE_FEATURE",
  "minimal_feat is non-canonical"
)

bad_refit_minimal <- function(sampled_subject_ids) {
  list(
    A = minimal_feat(0.05),
    B = minimal_feat(0.06),
    C = minimal_feat(0.55)
  )
}
assert_error_code(
  assess_cluster_stability(
    patient_rows = patient_meas[, c("subject_id", "unit_id")],
    refit_features = bad_refit_minimal,
    frozen_range = tiny_range,
    labels = c("A", "B", "C"),
    k = 2L,
    n_bootstrap = 5L,
    seed = 1L,
    keys = gower_keys_13_13
  ),
  "STABILITY_BOOTSTRAP_FAILED",
  "Non-canonical minimal_feat callback never reaches ASSESSED"
)

bad_refit_no_source <- function(sampled_subject_ids) {
  feat <- canonical_feat(0.1)
  feat$source <- NULL
  list(A = feat, B = feat, C = feat)
}
assert_error_code(
  assess_cluster_stability(
    patient_rows = patient_meas[, c("subject_id", "unit_id")],
    refit_features = bad_refit_no_source,
    frozen_range = tiny_range,
    labels = c("A", "B", "C"),
    k = 2L,
    n_bootstrap = 5L,
    seed = 1L,
    keys = gower_keys_13_13
  ),
  "STABILITY_BOOTSTRAP_FAILED",
  "Callback missing source never reaches ASSESSED"
)

bad_refit_delta <- function(sampled_subject_ids) {
  feat <- canonical_feat(0.1)
  feat$delta_dependent$present <- TRUE
  feat$delta_dependent$primary_delta <- NULL
  list(A = feat, B = feat, C = feat)
}
assert_error_code(
  assess_cluster_stability(
    patient_rows = patient_meas[, c("subject_id", "unit_id")],
    refit_features = bad_refit_delta,
    frozen_range = tiny_range,
    labels = c("A", "B", "C"),
    k = 2L,
    n_bootstrap = 5L,
    seed = 1L,
    keys = gower_keys_13_13
  ),
  "STABILITY_BOOTSTRAP_FAILED",
  "Invalid delta atomicity never reaches ASSESSED"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
