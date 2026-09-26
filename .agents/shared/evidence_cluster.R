# .agents/shared/evidence_cluster.R
# Exploratory clustering for evidence-decision-review (Section 13.5–13.6)
#
# Primary: hierarchical agglomerative clustering over Gower distances (13.5).
# Secondary (optional): standardized K-means on continuous features only (13.6).
# Assignments are exploratory aids only — never regulatory decisions (13.14).

EVIDENCE_HCLUST_ALLOWED_LINKAGE <- c("average", "complete", "single")
EVIDENCE_KMEANS_DEFAULT_NSTART <- 10L
EVIDENCE_CLUSTER_WORDING <- paste(
  "Cluster assignments are exploratory grouping aids only;",
  "they are never regulatory decisions."
)
EVIDENCE_CLUSTER_FORBIDDEN_RESULT_KEYS <- c(
  "decision",
  "decision_code",
  "decision_label",
  "clinical_verdict",
  "regulatory_label",
  "regulatory_outcome",
  "regulatory_action",
  "prior_decision",
  "expert_decision",
  "human_verdict",
  "action_label",
  "label_modification",
  "approval_status",
  "reject_status"
)

.assert_symmetric_distance_matrix <- function(mat) {
  if (!is.matrix(mat) || !is.numeric(mat)) {
    stop("[INVALID_DISTANCE_MATRIX] distance_matrix must be a numeric matrix")
  }
  if (nrow(mat) != ncol(mat) || nrow(mat) < 1L) {
    stop("[INVALID_DISTANCE_MATRIX] distance_matrix must be square and non-empty")
  }
  if (any(!is.finite(mat))) {
    stop("[INVALID_DISTANCE_MATRIX] distance_matrix must be finite (no NA/NaN/Inf)")
  }
  if (any(mat < 0)) {
    stop("[INVALID_DISTANCE_MATRIX] distances must be non-negative")
  }
  if (!isTRUE(all.equal(mat, t(mat), tolerance = 1e-10))) {
    stop("[INVALID_DISTANCE_MATRIX] distance_matrix must be symmetric")
  }
  if (any(abs(diag(mat)) > 1e-10)) {
    stop("[INVALID_DISTANCE_MATRIX] diagonal must be zero")
  }
  invisible(TRUE)
}

.resolve_hclust_linkage <- function(linkage) {
  if (!is.character(linkage) || length(linkage) != 1L || !nzchar(linkage)) {
    stop("[INVALID_HCLUST_LINKAGE] linkage must be a non-empty string")
  }
  if (linkage %in% c("ward.D", "ward.D2", "ward", "centroid", "median", "mcquitty")) {
    stop(
      "[UNSUPPORTED_HCLUST_LINKAGE] Gower dissimilarities disallow linkage '",
      linkage, "'; use one of: ", paste(EVIDENCE_HCLUST_ALLOWED_LINKAGE, collapse = ", ")
    )
  }
  if (!(linkage %in% EVIDENCE_HCLUST_ALLOWED_LINKAGE)) {
    stop(
      "[INVALID_HCLUST_LINKAGE] linkage must be one of: ",
      paste(EVIDENCE_HCLUST_ALLOWED_LINKAGE, collapse = ", ")
    )
  }
  linkage
}

.resolve_fixed_k <- function(k, n) {
  if (is.null(k)) {
    stop("[MISSING_CLUSTER_K] fixed_k partition requires explicit integer k")
  }
  if (!is.numeric(k) || length(k) != 1L || is.na(k) || k != as.integer(k)) {
    stop("[INVALID_CLUSTER_K] k must be a single integer")
  }
  k <- as.integer(k)
  if (k < 2L || k > n) {
    stop("[INVALID_CLUSTER_K] k must satisfy 2 <= k <= n (n=", n, ", k=", k, ")")
  }
  k
}

.resolve_cluster_labels <- function(labels, n) {
  if (is.null(labels)) {
    return(paste0("Case_", seq_len(n)))
  }
  labels <- as.character(labels)
  # nzchar(NA) is TRUE under keepNA=FALSE; reject missing/blank explicitly (13.5.R1)
  if (
    length(labels) != n ||
      anyNA(labels) ||
      anyDuplicated(labels) ||
      any(!nzchar(trimws(labels)))
  ) {
    stop("[INVALID_CLUSTER_LABELS] labels must be unique non-empty strings of length n (NA/blank rejected)")
  }
  labels
}

.cluster_governance_fields <- function() {
  list(
    exploratory_only = TRUE,
    decision_rule = FALSE,
    stability_status = "NOT_ASSESSED",
    stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE",
    wording = EVIDENCE_CLUSTER_WORDING
  )
}

#' Assert cluster result cannot be treated as a regulatory action (13.14).
assert_cluster_assignment_non_regulatory <- function(cluster_result) {
  if (!is.list(cluster_result)) {
    stop("[INVALID_CLUSTER_RESULT] cluster_result must be a list")
  }
  if (!isTRUE(cluster_result$exploratory_only)) {
    stop("[CLUSTER_ASSIGNMENT_NOT_REGULATORY] exploratory_only must be TRUE")
  }
  if (!isFALSE(cluster_result$decision_rule)) {
    stop("[CLUSTER_ASSIGNMENT_NOT_REGULATORY] decision_rule must be FALSE")
  }
  nms <- names(cluster_result)
  hit <- intersect(tolower(nms), tolower(EVIDENCE_CLUSTER_FORBIDDEN_RESULT_KEYS))
  if (length(hit) > 0L) {
    stop(
      "[CLUSTER_ASSIGNMENT_NOT_REGULATORY] result must not contain regulatory keys: ",
      paste(sort(unique(hit)), collapse = ", ")
    )
  }
  if (
    !is.character(cluster_result$wording) || length(cluster_result$wording) != 1L ||
      !grepl("exploratory", cluster_result$wording, ignore.case = TRUE) ||
      !grepl("never regulatory", cluster_result$wording, ignore.case = TRUE)
  ) {
    stop("[CLUSTER_ASSIGNMENT_NOT_REGULATORY] wording must deny regulatory decision use")
  }
  invisible(TRUE)
}

#' Refuse any attempt to promote cluster assignments to regulatory actions (13.14).
promote_cluster_to_regulatory_action <- function(cluster_result, ...) {
  stop(
    "[CLUSTER_ASSIGNMENT_NOT_REGULATORY] cluster assignments cannot trigger ",
    "regulatory actions or label modifications"
  )
}

#' Hierarchical agglomerative clustering on a precomputed distance matrix.
#'
#' Accepts any finite non-negative symmetric dissimilarity (diagonal 0).
#' Section 13.5 product path supplies Gower distances via
#' \code{cluster_evidence_features()}; values outside [0, 1] are allowed on
#' this generic matrix API.
#'
#' @param distance_matrix square symmetric distance matrix
#' @param labels optional case ids (length n); default Case_1..Case_n
#' @param linkage one of average|complete|single (default average)
#' @param k required integer for fixed_k partition (2..n)
#' @return list with tree summary, assignments, provenance, stability stub
evidence_hclust <- function(distance_matrix, labels = NULL,
                            linkage = "average", k) {
  .assert_symmetric_distance_matrix(distance_matrix)
  n <- nrow(distance_matrix)
  if (n < 2L) {
    stop("[INSUFFICIENT_CASES_FOR_CLUSTERING] hierarchical clustering requires n >= 2")
  }

  linkage <- .resolve_hclust_linkage(linkage)
  k <- .resolve_fixed_k(k, n)
  labels <- .resolve_cluster_labels(labels, n)

  d <- stats::as.dist(distance_matrix)
  hc <- stats::hclust(d, method = linkage)
  assignments <- stats::cutree(hc, k = k)
  names(assignments) <- labels

  res <- c(
    list(
      method = "hierarchical_agglomerative",
      linkage = linkage,
      partition_mode = "fixed_k",
      k = k,
      n_cases = n,
      labels = labels,
      merge = hc$merge,
      height = as.numeric(hc$height),
      order = as.integer(hc$order),
      assignments = as.integer(assignments),
      assignment_labels = stats::setNames(as.integer(assignments), labels)
    ),
    .cluster_governance_fields()
  )
  assert_cluster_assignment_non_regulatory(res)
  res
}

#' Cluster evidence-feature vectors via Gower distance then HAC.
#'
#' @inheritParams gower_distance_matrix
#' @param labels optional case ids
#' @param linkage HAC linkage (default average)
#' @param k fixed_k partition size
cluster_evidence_features <- function(feature_list, frozen_range, keys = NULL,
                                      labels = NULL, linkage = "average", k) {
  if (!is.list(feature_list) || length(feature_list) < 2L) {
    stop("[INSUFFICIENT_CASES_FOR_CLUSTERING] cluster_evidence_features requires length(feature_list) >= 2")
  }
  gower <- gower_distance_matrix(feature_list, frozen_range, keys = keys)
  res <- evidence_hclust(
    gower$matrix,
    labels = labels,
    linkage = linkage,
    k = k
  )
  res$distance_metric <- "gower"
  res$gower_feature_keys <- as.character(gower$keys_used)
  res$gower_warnings <- gower$warnings
  res$range_version <- gower$range_version
  res$feature_schema_version <- gower$feature_schema_version
  res$distance_matrix <- gower$matrix
  assert_cluster_assignment_non_regulatory(res)
  res
}

.resolve_kmeans_continuous_keys <- function(feature_list, frozen_range, keys = NULL) {
  assert_frozen_reference_range(frozen_range)
  flat_list <- lapply(feature_list, flatten_evidence_feature_values)
  schema_vers <- vapply(flat_list, function(f) f$feature_schema_version, character(1))
  if (length(unique(schema_vers)) != 1L) {
    stop("[FEATURE_SCHEMA_VERSION_MISMATCH] all cases must share feature_schema_version")
  }
  if (!identical(schema_vers[[1L]], as.character(frozen_range$feature_schema_version))) {
    stop(
      "[FEATURE_SCHEMA_VERSION_MISMATCH] feature_schema_version ", schema_vers[[1L]],
      " != frozen range ", frozen_range$feature_schema_version
    )
  }

  candidate <- .resolve_gower_keys(flat_list, frozen_range, keys = keys)
  feats <- frozen_range$features
  types <- vapply(candidate, function(nm) as.character(feats[[nm]]$type), character(1))
  non_cont <- candidate[types != "numeric"]
  cont <- candidate[types == "numeric"]

  if (!is.null(keys) && length(non_cont) > 0L) {
    stop(
      "[KMEANS_NON_CONTINUOUS_FEATURE] K-means rejects non-continuous keys: ",
      paste(non_cont, collapse = ", ")
    )
  }
  if (length(cont) < 1L) {
    stop("[KMEANS_NO_CONTINUOUS_FEATURES] K-means requires at least one numeric feature")
  }
  list(keys = cont, flat_list = flat_list)
}

.build_scaled_continuous_matrix <- function(feature_list, frozen_range, keys = NULL) {
  resolved <- .resolve_kmeans_continuous_keys(feature_list, frozen_range, keys = keys)
  keys_used <- resolved$keys
  flat_list <- resolved$flat_list
  n <- length(flat_list)
  p <- length(keys_used)
  mat <- matrix(NA_real_, nrow = n, ncol = p, dimnames = list(NULL, keys_used))
  for (i in seq_len(n)) {
    vals <- flat_list[[i]]$values
    for (j in seq_len(p)) {
      key <- keys_used[[j]]
      v <- vals[[key]]
      if (is.null(v) || length(v) != 1L || is.na(v) || !is.numeric(v) || !is.finite(v)) {
        stop(
          "[KMEANS_NON_FINITE_FEATURE] case ", i, " feature '", key,
          "' must be a finite numeric scalar"
        )
      }
      mat[i, j] <- as.numeric(v)
    }
  }

  col_var <- apply(mat, 2L, stats::var)
  zero_var <- names(col_var)[!is.finite(col_var) | col_var <= 0]
  if (length(zero_var) > 0L) {
    if (!is.null(keys)) {
      stop(
        "[KMEANS_ZERO_VARIANCE_FEATURE] cannot standardize zero-variance features: ",
        paste(zero_var, collapse = ", ")
      )
    }
    # keys=NULL: drop constant numeric columns (mirrors categorical auto-filter)
    keep <- setdiff(keys_used, zero_var)
    if (length(keep) < 1L) {
      stop(
        "[KMEANS_ZERO_VARIANCE_FEATURE] all candidate numeric features have zero variance: ",
        paste(zero_var, collapse = ", ")
      )
    }
    mat <- mat[, keep, drop = FALSE]
    keys_used <- keep
  }

  scaled <- scale(mat, center = TRUE, scale = TRUE)
  if (any(!is.finite(scaled))) {
    stop("[KMEANS_SCALE_FAILED] standardized matrix contains non-finite values")
  }

  list(
    matrix_raw = mat,
    matrix_scaled = scaled,
    keys_used = keys_used,
    scale_center = as.numeric(attr(scaled, "scaled:center")),
    scale_scale = as.numeric(attr(scaled, "scaled:scale")),
    scaled = TRUE,
    range_version = as.character(frozen_range$range_version),
    feature_schema_version = as.character(frozen_range$feature_schema_version)
  )
}

#' Optional standardized K-means on continuous evidence features (13.6).
#'
#' Strictly rejects categorical / non-numeric keys when supplied explicitly.
#' When \code{keys=NULL}, shared keys are resolved then filtered to numeric only.
#'
#' @param feature_list list of evidence-feature-v1 objects (length >= 2)
#' @param frozen_range frozen-reference-range-v1 object
#' @param keys optional explicit feature keys (all must be numeric)
#' @param labels optional case ids
#' @param k fixed_k partition size
#' @param nstart \code{stats::kmeans} nstart (default 10)
#' @param seed optional RNG seed for reproducible center initialization
#' @return list with assignments and provenance (exploratory only)
evidence_kmeans <- function(feature_list, frozen_range, keys = NULL,
                            labels = NULL, k,
                            nstart = EVIDENCE_KMEANS_DEFAULT_NSTART,
                            seed = NULL) {
  if (!is.list(feature_list) || length(feature_list) < 2L) {
    stop("[INSUFFICIENT_CASES_FOR_CLUSTERING] evidence_kmeans requires length(feature_list) >= 2")
  }
  if (!is.numeric(nstart) || length(nstart) != 1L || is.na(nstart) ||
    !is.finite(nstart) || nstart != as.integer(nstart) || as.integer(nstart) < 1L) {
    stop("[INVALID_KMEANS_NSTART] nstart must be a positive finite integer")
  }
  nstart <- as.integer(nstart)

  built <- .build_scaled_continuous_matrix(feature_list, frozen_range, keys = keys)
  n <- nrow(built$matrix_scaled)
  k <- .resolve_fixed_k(k, n)
  labels <- .resolve_cluster_labels(labels, n)

  # 13.6.R1: stats::kmeans requires >= k distinct rows for numeric centers=
  n_distinct <- nrow(unique(as.data.frame(built$matrix_scaled, stringsAsFactors = FALSE)))
  if (k > n_distinct) {
    stop(
      "[KMEANS_INSUFFICIENT_DISTINCT_CASES] k=", k,
      " exceeds distinct standardized case vectors=", n_distinct,
      " (n=", n, ")"
    )
  }

  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) ||
      !is.finite(seed) || seed != as.integer(seed)) {
      stop("[INVALID_KMEANS_SEED] seed must be a single finite integer when supplied")
    }
    set.seed(as.integer(seed))
  }

  km <- stats::kmeans(
    built$matrix_scaled,
    centers = k,
    nstart = nstart,
    iter.max = 10L,
    algorithm = "Hartigan-Wong"
  )
  assignments <- as.integer(km$cluster)
  names(assignments) <- labels

  res <- c(
    list(
      method = "kmeans_standardized",
      partition_mode = "fixed_k",
      k = k,
      n_cases = n,
      n_distinct_cases = as.integer(n_distinct),
      n_features = length(built$keys_used),
      labels = labels,
      feature_keys = as.character(built$keys_used),
      scaled = TRUE,
      scale_center = stats::setNames(built$scale_center, built$keys_used),
      scale_scale = stats::setNames(built$scale_scale, built$keys_used),
      nstart = nstart,
      iter.max = 10L,
      algorithm = "Hartigan-Wong",
      seed = if (is.null(seed)) NULL else as.integer(seed),
      totss = as.numeric(km$totss),
      withinss = as.numeric(km$withinss),
      tot.withinss = as.numeric(km$tot.withinss),
      betweenss = as.numeric(km$betweenss),
      size = as.integer(km$size),
      assignments = assignments,
      assignment_labels = stats::setNames(assignments, labels),
      range_version = built$range_version,
      feature_schema_version = built$feature_schema_version
    ),
    .cluster_governance_fields()
  )
  assert_cluster_assignment_non_regulatory(res)
  res
}

.not_assessed_stability <- function() {
  list(
    method = "cluster_stability",
    stability_status = "NOT_ASSESSED",
    stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE",
    n_bootstrap = NULL,
    n_bootstrap_requested = NULL,
    n_bootstrap_usable = NULL,
    n_bootstrap_failed = NULL,
    mean_co_clustering = NULL,
    pair_co_clustering = NULL,
    n_units = NULL,
    k = NULL,
    linkage = NULL,
    unit_ids = NULL,
    exploratory_only = TRUE,
    decision_rule = FALSE,
    wording = paste(
      "Cluster stability was not assessed because cross-theme patient-level",
      "dependence is unavailable (term summaries only)."
    )
  )
}

.normalize_stability_patient_rows <- function(patient_rows) {
  if (is.data.frame(patient_rows)) {
    df <- patient_rows
  } else if (is.list(patient_rows) && !is.null(patient_rows$subject_id) &&
    !is.null(patient_rows$unit_id)) {
    df <- data.frame(
      subject_id = as.character(patient_rows$subject_id),
      unit_id = as.character(patient_rows$unit_id),
      stringsAsFactors = FALSE
    )
  } else {
    stop(
      "[INVALID_PATIENT_ROWS] patient_rows must be a data.frame or list ",
      "with subject_id and unit_id"
    )
  }
  if (!all(c("subject_id", "unit_id") %in% names(df))) {
    stop("[INVALID_PATIENT_ROWS] patient_rows must contain subject_id and unit_id")
  }
  if (nrow(df) < 1L) {
    stop("[INVALID_PATIENT_ROWS] patient_rows must be non-empty")
  }
  sid <- as.character(df$subject_id)
  uid <- as.character(df$unit_id)
  if (anyNA(sid) || any(!nzchar(trimws(sid))) ||
    anyNA(uid) || any(!nzchar(trimws(uid)))) {
    stop("[INVALID_PATIENT_ROWS] subject_id and unit_id must be non-empty strings")
  }
  data.frame(subject_id = sid, unit_id = uid, stringsAsFactors = FALSE)
}

#' Assess cluster stability via patient-level bootstrap co-clustering (13.13).
#'
#' ASSESSED requires \code{patient_rows} (\code{subject_id}+\code{unit_id}),
#' \code{refit_features(sampled_subject_ids) -> named evidence-feature list},
#' and \code{frozen_range}. Otherwise returns
#' \code{NOT_ASSESSED} / \code{CROSS_THEME_DEPENDENCE_UNAVAILABLE}.
#' Fixed distance-matrix row resampling is intentionally not supported (13.13.R1).
#'
#' @param patient_rows NULL or rows with subject_id and unit_id (duplicates allowed)
#' @param refit_features callback: sampled subject IDs (with replacement) ->
#'   named list of evidence-feature-v1 keyed by unit_id
#' @param frozen_range frozen-reference-range-v1
#' @param labels optional original unit ids (default unique unit_id order)
#' @param linkage HAC linkage
#' @param k fixed_k partition size
#' @param n_bootstrap bootstrap replicates
#' @param seed optional RNG seed
#' @param keys optional Gower feature keys
#' @return stability assessment list
assess_cluster_stability <- function(patient_rows = NULL,
                                     refit_features = NULL,
                                     frozen_range = NULL,
                                     labels = NULL,
                                     linkage = "average",
                                     k = NULL,
                                     n_bootstrap = 50L,
                                     seed = NULL,
                                     keys = NULL) {
  if (is.null(patient_rows) || is.null(refit_features) || is.null(frozen_range)) {
    return(.not_assessed_stability())
  }
  if (!is.function(refit_features)) {
    stop("[INVALID_STABILITY_REFIT] refit_features must be a function")
  }
  if (!exists("gower_distance_matrix", mode = "function")) {
    stop(
      "[MISSING_GOWER] source .agents/shared/evidence_gower.R ",
      "before assess_cluster_stability()"
    )
  }
  if (!exists("assert_evidence_feature_v1", mode = "function")) {
    stop(
      "[MISSING_EVIDENCE_FEATURE_ASSERT] source .agents/shared/evidence_feature_extract.R ",
      "before assess_cluster_stability()"
    )
  }

  pr <- .normalize_stability_patient_rows(patient_rows)
  unit_levels <- unique(pr$unit_id)
  n <- length(unit_levels)
  if (n < 2L) {
    stop("[INSUFFICIENT_CASES_FOR_CLUSTERING] stability requires at least 2 units")
  }
  if (is.null(labels)) {
    labels <- unit_levels
  }
  labels <- .resolve_cluster_labels(labels, n)
  if (!identical(sort(labels), sort(unit_levels))) {
    stop("[INVALID_CLUSTER_LABELS] labels must match unique patient_rows$unit_id")
  }
  # Preserve caller label order as canonical unit order
  unit_ids <- labels
  linkage <- .resolve_hclust_linkage(linkage)
  k <- .resolve_fixed_k(k, n)

  subjects <- unique(pr$subject_id)
  n_subj <- length(subjects)
  if (n_subj < 1L) {
    stop("[INVALID_PATIENT_ROWS] no subjects available for bootstrap")
  }

  if (!is.numeric(n_bootstrap) || length(n_bootstrap) != 1L || is.na(n_bootstrap) ||
    !is.finite(n_bootstrap) || n_bootstrap != as.integer(n_bootstrap) ||
    as.integer(n_bootstrap) < 1L) {
    stop("[INVALID_STABILITY_BOOTSTRAP] n_bootstrap must be a positive finite integer")
  }
  n_bootstrap <- as.integer(n_bootstrap)

  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) ||
      !is.finite(seed) || seed != as.integer(seed)) {
      stop("[INVALID_STABILITY_SEED] seed must be a single finite integer when supplied")
    }
    set.seed(as.integer(seed))
  }

  co_sum <- matrix(0, nrow = n, ncol = n)
  co_den <- matrix(0L, nrow = n, ncol = n)
  diag(co_den) <- as.integer(n_bootstrap)
  diag(co_sum) <- as.numeric(n_bootstrap)
  n_usable <- 0L
  n_failed <- 0L

  for (b in seq_len(n_bootstrap)) {
    sampled <- subjects[sample.int(n_subj, size = n_subj, replace = TRUE)]
    feat_res <- tryCatch(
      refit_features(sampled),
      error = function(e) e
    )
    if (inherits(feat_res, "error") || !is.list(feat_res) || length(feat_res) < 1L) {
      n_failed <- n_failed + 1L
      next
    }
    feat_names <- names(feat_res)
    if (is.null(feat_names) || any(!nzchar(feat_names)) || anyDuplicated(feat_names)) {
      n_failed <- n_failed + 1L
      next
    }
    present_units <- intersect(unit_ids, feat_names)
    if (length(present_units) < k) {
      n_failed <- n_failed + 1L
      next
    }
    # 13.13.R3: enforce canonical evidence-feature-v1 before Gower
    feat_list <- tryCatch(
      {
        out <- list()
        for (nm in present_units) {
          out[[nm]] <- assert_evidence_feature_v1(
            feat_res[[nm]],
            context = paste0("stability.refit_features.", nm)
          )
        }
        out
      },
      error = function(e) e
    )
    if (inherits(feat_list, "error")) {
      n_failed <- n_failed + 1L
      next
    }
    gower_res <- tryCatch(
      gower_distance_matrix(feat_list, frozen_range, keys = keys),
      error = function(e) e
    )
    if (inherits(gower_res, "error")) {
      n_failed <- n_failed + 1L
      next
    }
    sub_mat <- gower_res$matrix
    diag(sub_mat) <- 0
    hc <- tryCatch(
      stats::hclust(stats::as.dist(sub_mat), method = linkage),
      error = function(e) e
    )
    if (inherits(hc, "error")) {
      n_failed <- n_failed + 1L
      next
    }
    cl <- stats::cutree(hc, k = k)
    names(cl) <- present_units
    n_usable <- n_usable + 1L
    m <- length(present_units)
    for (i in seq_len(m)) {
      for (j in seq_len(m)) {
        if (i == j) next
        oi <- match(present_units[[i]], unit_ids)
        oj <- match(present_units[[j]], unit_ids)
        co_den[oi, oj] <- co_den[oi, oj] + 1L
        if (identical(as.integer(cl[[i]]), as.integer(cl[[j]]))) {
          co_sum[oi, oj] <- co_sum[oi, oj] + 1
        }
      }
    }
  }

  if (n_usable < 1L) {
    stop("[STABILITY_BOOTSTRAP_FAILED] no usable patient-level bootstrap replicates")
  }

  pair_co <- matrix(NA_real_, nrow = n, ncol = n)
  dimnames(pair_co) <- list(unit_ids, unit_ids)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (co_den[i, j] > 0L) {
        pair_co[i, j] <- co_sum[i, j] / co_den[i, j]
      }
    }
  }
  upper <- upper.tri(pair_co, diag = FALSE)
  mean_co <- mean(pair_co[upper], na.rm = TRUE)
  if (!is.finite(mean_co)) {
    stop("[STABILITY_BOOTSTRAP_FAILED] insufficient co-clustering observations")
  }

  list(
    method = "patient_bootstrap_co_clustering",
    stability_status = "ASSESSED",
    stability_reason = NULL,
    n_bootstrap = n_bootstrap,
    n_bootstrap_requested = n_bootstrap,
    n_bootstrap_usable = as.integer(n_usable),
    n_bootstrap_failed = as.integer(n_failed),
    n_units = n,
    k = k,
    linkage = linkage,
    seed = if (is.null(seed)) NULL else as.integer(seed),
    mean_co_clustering = as.numeric(mean_co),
    pair_co_clustering = pair_co,
    unit_ids = as.character(unit_ids),
    n_subjects = as.integer(n_subj),
    exploratory_only = TRUE,
    decision_rule = FALSE,
    wording = paste(
      "Patient-level bootstrap co-clustering is an exploratory stability summary;",
      "it is never a regulatory decision rule."
    )
  )
}

#' Attach a stability assessment onto an existing cluster result (13.13 / 13.13.R2).
attach_cluster_stability <- function(cluster_result, stability) {
  if (!is.list(cluster_result)) {
    stop("[INVALID_CLUSTER_RESULT] cluster_result must be a list")
  }
  if (!is.list(stability) || is.null(stability$stability_status)) {
    stop("[INVALID_STABILITY_RESULT] stability must contain stability_status")
  }
  allowed <- c("NOT_ASSESSED", "ASSESSED")
  if (!(stability$stability_status %in% allowed)) {
    stop(
      "[INVALID_STABILITY_RESULT] stability_status must be one of: ",
      paste(allowed, collapse = ", ")
    )
  }

  if (identical(stability$stability_status, "ASSESSED")) {
    if (!identical(cluster_result$method, "hierarchical_agglomerative")) {
      stop(
        "[STABILITY_ATTACH_INCOMPATIBLE] ASSESSED stability requires ",
        "hierarchical_agglomerative cluster result"
      )
    }
    if (is.null(stability$n_units) ||
      !identical(as.integer(cluster_result$n_cases), as.integer(stability$n_units))) {
      stop("[STABILITY_ATTACH_INCOMPATIBLE] n_cases must equal stability n_units")
    }
    if (is.null(stability$k) ||
      !identical(as.integer(cluster_result$k), as.integer(stability$k))) {
      stop("[STABILITY_ATTACH_INCOMPATIBLE] k mismatch")
    }
    if (is.null(stability$linkage) ||
      !identical(as.character(cluster_result$linkage), as.character(stability$linkage))) {
      stop("[STABILITY_ATTACH_INCOMPATIBLE] linkage mismatch")
    }
    stab_units <- stability$unit_ids
    if (is.null(stab_units)) {
      stop("[STABILITY_ATTACH_INCOMPATIBLE] stability unit_ids required")
    }
    if (!identical(as.character(cluster_result$labels), as.character(stab_units))) {
      stop("[STABILITY_ATTACH_INCOMPATIBLE] labels / unit_ids mismatch")
    }
    if (!is.null(stability$pair_co_clustering)) {
      pc <- stability$pair_co_clustering
      if (!is.matrix(pc) || !identical(dim(pc), c(length(stab_units), length(stab_units)))) {
        stop("[STABILITY_ATTACH_INCOMPATIBLE] pair_co_clustering dimensions mismatch")
      }
      dn <- dimnames(pc)
      if (
        is.null(dn) ||
          !identical(as.character(dn[[1L]]), as.character(stab_units)) ||
          !identical(as.character(dn[[2L]]), as.character(stab_units))
      ) {
        stop("[STABILITY_ATTACH_INCOMPATIBLE] pair_co_clustering dimnames mismatch")
      }
    }
  }

  out <- cluster_result
  out$stability_status <- stability$stability_status
  out$stability_reason <- stability$stability_reason
  out$stability_method <- stability$method
  out$stability_n_bootstrap <- stability$n_bootstrap
  out$stability_n_bootstrap_usable <- stability$n_bootstrap_usable
  out$stability_n_bootstrap_failed <- stability$n_bootstrap_failed
  out$stability_mean_co_clustering <- stability$mean_co_clustering
  out$stability_k <- stability$k
  out$stability_linkage <- stability$linkage
  out$stability_unit_ids <- stability$unit_ids
  if (!is.null(stability$pair_co_clustering)) {
    out$stability_pair_co_clustering <- stability$pair_co_clustering
  }
  if (!is.null(stability$wording)) {
    out$stability_wording <- stability$wording
  }
  assert_cluster_assignment_non_regulatory(out)
  out
}
