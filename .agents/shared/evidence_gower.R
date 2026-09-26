# .agents/shared/evidence_gower.R
# Gower distance with frozen reference ranges for evidence-decision-review (Section 13.4)
#
# Overflow policy (OpenSpec): contribution clipping only —
#   d_j = min(1, |x_i - x_j| / R_j)
# Observations are NOT clipped to [min,max] before differencing.
# Partial feature selection is supported only via explicit keys=; every selected
# key (or every shared clustering key when keys=NULL) MUST have a frozen-range entry.

DEFAULT_FROZEN_REFERENCE_RANGE_PATH <- file.path(
  "schemas", "fixtures", "frozen_reference_range_default_v1.json"
)

assert_frozen_reference_range <- function(range_obj) {
  if (!is.list(range_obj)) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] range must be a named list/object")
  }
  if (!identical(as.character(range_obj$schema_version), "frozen-reference-range-v1")) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] schema_version must be frozen-reference-range-v1")
  }
  if (!is.character(range_obj$range_version) || length(range_obj$range_version) != 1L ||
    !nzchar(range_obj$range_version)) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] range_version is required")
  }
  if (!is.character(range_obj$feature_schema_version) ||
    length(range_obj$feature_schema_version) != 1L ||
    !nzchar(range_obj$feature_schema_version)) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] feature_schema_version is required")
  }
  feats <- range_obj$features
  if (!is.list(feats) || length(feats) < 1L || is.null(names(feats)) || any(!nzchar(names(feats)))) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] features must be a non-empty named object")
  }
  for (nm in names(feats)) {
    spec <- feats[[nm]]
    typ <- as.character(spec$type)
    if (identical(typ, "numeric")) {
      if (!is.numeric(spec$min) || !is.numeric(spec$max) ||
        length(spec$min) != 1L || length(spec$max) != 1L ||
        is.na(spec$min) || is.na(spec$max)) {
        stop("[INVALID_FROZEN_REFERENCE_RANGE] numeric feature ", nm, " needs finite min/max")
      }
      if (!(spec$max > spec$min)) {
        stop("[ZERO_FROZEN_RANGE] numeric feature ", nm, " requires max > min")
      }
    } else if (identical(typ, "categorical")) {
      levels <- unlist(spec$levels, use.names = FALSE)
      if (length(levels) < 1L || anyDuplicated(as.character(levels))) {
        stop("[INVALID_FROZEN_REFERENCE_RANGE] categorical feature ", nm, " needs unique levels")
      }
    } else {
      stop("[INVALID_FROZEN_REFERENCE_RANGE] feature ", nm, " type must be numeric or categorical")
    }
  }
  invisible(TRUE)
}

load_frozen_reference_range <- function(path = DEFAULT_FROZEN_REFERENCE_RANGE_PATH) {
  if (!file.exists(path)) {
    stop("[INVALID_FROZEN_REFERENCE_RANGE] file not found: ", path)
  }
  range_obj <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  assert_frozen_reference_range(range_obj)
  range_obj
}

flatten_evidence_feature_values <- function(features) {
  if (!is.list(features)) {
    stop("[INVALID_EVIDENCE_FEATURE] features must be a list")
  }
  if (!identical(as.character(features$schema_version), "evidence-feature-v1")) {
    stop("[INVALID_EVIDENCE_FEATURE] schema_version must be evidence-feature-v1")
  }
  keys <- unlist(features$clustering_feature_keys, use.names = FALSE)
  if (!is.character(keys) || length(keys) < 1L) {
    stop("[INVALID_EVIDENCE_FEATURE] clustering_feature_keys required")
  }
  vals <- list()
  for (k in keys) {
    if (k %in% names(features$core)) {
      vals[[k]] <- features$core[[k]]
    } else if (k %in% names(features$delta_dependent)) {
      vals[[k]] <- features$delta_dependent[[k]]
    } else {
      stop("[UNKNOWN_CLUSTERING_FEATURE_KEYS] cannot flatten clustering key: ", k)
    }
  }
  list(
    feature_schema_version = as.character(features$feature_schema_version),
    keys = keys,
    values = vals
  )
}

.resolve_gower_keys <- function(flat_list, frozen_range, keys = NULL) {
  if (is.null(keys)) {
    candidate <- flat_list[[1L]]$keys
    for (i in seq_along(flat_list)[-1L]) {
      candidate <- intersect(candidate, flat_list[[i]]$keys)
    }
  } else {
    candidate <- as.character(keys)
    if (length(candidate) < 1L || any(!nzchar(candidate))) {
      stop("[GOWER_NO_COMPARABLE_FEATURES] keys must be a non-empty character vector when supplied")
    }
  }
  range_names <- names(frozen_range$features)
  missing_range <- setdiff(candidate, range_names)
  if (length(missing_range) > 0L) {
    stop(
      "[FROZEN_RANGE_MISSING_FEATURE] clustering keys lack frozen-range entries: ",
      paste(missing_range, collapse = ", ")
    )
  }
  if (length(candidate) < 1L) {
    stop("[GOWER_NO_COMPARABLE_FEATURES] no shared keys present in frozen_reference_range")
  }
  candidate
}

.numeric_available <- function(x, min_v, max_v, warnings_acc) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return(list(value = NA_real_, warnings = warnings_acc, available = FALSE))
  }
  x <- as.numeric(x)
  if (length(x) != 1L || is.na(x)) {
    return(list(value = NA_real_, warnings = warnings_acc, available = FALSE))
  }
  if (x < min_v || x > max_v) {
    warnings_acc <- c(warnings_acc, "GOWER_REFERENCE_RANGE_EXCEEDED")
  }
  # Keep original observation; contribution clipping happens at d_j = min(1, |diff|/R).
  list(value = x, warnings = warnings_acc, available = TRUE)
}

.categorical_available <- function(x, levels, warnings_acc) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return(list(value = NA_character_, warnings = warnings_acc, available = FALSE))
  }
  # Preserve logicals as character "TRUE"/"FALSE" for stable compare with JSON booleans.
  if (is.logical(x) && length(x) == 1L) {
    x_chr <- if (isTRUE(x)) "TRUE" else "FALSE"
  } else {
    x_chr <- as.character(x)
  }
  level_chr <- vapply(levels, function(lv) {
    if (is.logical(lv) && length(lv) == 1L) {
      if (isTRUE(lv)) "TRUE" else "FALSE"
    } else {
      as.character(lv)
    }
  }, character(1))
  if (!(x_chr %in% level_chr)) {
    warnings_acc <- c(warnings_acc, "GOWER_REFERENCE_RANGE_EXCEEDED")
  }
  list(value = x_chr, warnings = warnings_acc, available = TRUE)
}

.scan_feature_range_warnings <- function(flat, frozen_range, keys) {
  warnings <- character()
  for (k in keys) {
    spec <- frozen_range$features[[k]]
    typ <- as.character(spec$type)
    v <- flat$values[[k]]
    if (identical(typ, "numeric")) {
      res <- .numeric_available(v, spec$min, spec$max, warnings)
      warnings <- res$warnings
    } else if (identical(typ, "categorical")) {
      res <- .categorical_available(v, spec$levels, warnings)
      warnings <- res$warnings
    }
  }
  unique(warnings)
}

gower_pairwise_distance <- function(features_a, features_b, frozen_range,
                                    keys = NULL) {
  assert_frozen_reference_range(frozen_range)
  flat_a <- flatten_evidence_feature_values(features_a)
  flat_b <- flatten_evidence_feature_values(features_b)

  if (!identical(flat_a$feature_schema_version, frozen_range$feature_schema_version) ||
    !identical(flat_b$feature_schema_version, frozen_range$feature_schema_version)) {
    stop(
      "[FEATURE_SCHEMA_VERSION_MISMATCH] features/frozen range feature_schema_version differ: ",
      flat_a$feature_schema_version, " / ", flat_b$feature_schema_version, " / ",
      frozen_range$feature_schema_version
    )
  }

  keys <- .resolve_gower_keys(list(flat_a, flat_b), frozen_range, keys = keys)

  warnings <- character()
  contrib <- numeric()
  used_keys <- character()

  for (k in keys) {
    spec <- frozen_range$features[[k]]
    typ <- as.character(spec$type)
    va <- flat_a$values[[k]]
    vb <- flat_b$values[[k]]

    if (identical(typ, "numeric")) {
      ca <- .numeric_available(va, spec$min, spec$max, warnings)
      warnings <- ca$warnings
      cb <- .numeric_available(vb, spec$min, spec$max, warnings)
      warnings <- cb$warnings
      if (!isTRUE(ca$available) || !isTRUE(cb$available)) next
      Rj <- as.numeric(spec$max) - as.numeric(spec$min)
      dj <- min(1, abs(ca$value - cb$value) / Rj)
      contrib <- c(contrib, dj)
      used_keys <- c(used_keys, k)
    } else if (identical(typ, "categorical")) {
      ca <- .categorical_available(va, spec$levels, warnings)
      warnings <- ca$warnings
      cb <- .categorical_available(vb, spec$levels, warnings)
      warnings <- cb$warnings
      if (!isTRUE(ca$available) || !isTRUE(cb$available)) next
      dj <- if (identical(ca$value, cb$value)) 0 else 1
      contrib <- c(contrib, dj)
      used_keys <- c(used_keys, k)
    }
  }

  if (length(contrib) < 1L) {
    stop("[GOWER_NO_COMPARABLE_FEATURES] all candidate features were unavailable")
  }

  list(
    distance = sum(contrib) / length(contrib),
    n_features_used = length(contrib),
    keys_used = used_keys,
    contributions = stats::setNames(contrib, used_keys),
    warnings = unique(warnings),
    range_version = frozen_range$range_version,
    feature_schema_version = frozen_range$feature_schema_version
  )
}

gower_distance_matrix <- function(feature_list, frozen_range, keys = NULL) {
  if (!is.list(feature_list) || length(feature_list) < 1L) {
    stop("[INVALID_EVIDENCE_FEATURE] feature_list must be a non-empty list")
  }
  assert_frozen_reference_range(frozen_range)

  flats <- lapply(feature_list, flatten_evidence_feature_values)
  for (flat in flats) {
    if (!identical(flat$feature_schema_version, frozen_range$feature_schema_version)) {
      stop(
        "[FEATURE_SCHEMA_VERSION_MISMATCH] features/frozen range feature_schema_version differ: ",
        flat$feature_schema_version, " / ", frozen_range$feature_schema_version
      )
    }
  }
  resolved_keys <- .resolve_gower_keys(flats, frozen_range, keys = keys)

  n <- length(feature_list)
  mat <- matrix(0, nrow = n, ncol = n)
  warn_all <- character()

  # n=1 never enters the pairwise loop; still audit range overflow on the sole row.
  if (n == 1L) {
    warn_all <- .scan_feature_range_warnings(flats[[1L]], frozen_range, resolved_keys)
  }

  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (j < i) {
        mat[i, j] <- mat[j, i]
        next
      }
      if (i == j) {
        mat[i, j] <- 0
        next
      }
      res <- gower_pairwise_distance(
        feature_list[[i]], feature_list[[j]], frozen_range,
        keys = resolved_keys
      )
      mat[i, j] <- res$distance
      warn_all <- c(warn_all, res$warnings)
    }
  }
  list(
    matrix = mat,
    keys_used = as.character(resolved_keys),
    warnings = unique(warn_all),
    range_version = frozen_range$range_version,
    feature_schema_version = frozen_range$feature_schema_version
  )
}
