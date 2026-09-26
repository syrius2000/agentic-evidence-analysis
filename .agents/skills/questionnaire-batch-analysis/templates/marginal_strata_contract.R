MARGINAL_STRATA_DELTA <- 0.05

classify_marginal_strata <- function(
  cramer_v_marginal,
  strata_v,
  threshold = MARGINAL_STRATA_DELTA
) {
  if (length(threshold) != 1L || !is.finite(threshold) || threshold < 0) {
    stop("threshold must be one finite non-negative number")
  }

  finite_strata <- as.numeric(strata_v[is.finite(strata_v)])
  if (!is.finite(cramer_v_marginal) || length(finite_strata) == 0L) {
    return(list(
      signal = "none",
      note = "insufficient_strata_or_na",
      delta = NA_real_,
      strata_mean = NA_real_
    ))
  }

  strata_mean <- mean(finite_strata)
  delta <- abs(as.numeric(cramer_v_marginal) - strata_mean)
  if (!is.finite(delta)) {
    return(list(
      signal = "none",
      note = "insufficient_strata_or_na",
      delta = NA_real_,
      strata_mean = strata_mean
    ))
  }

  if (delta >= threshold) {
    return(list(
      signal = "review_stratified",
      note = sprintf(
        "|V_marginal - mean(V_strata)|=%.4f >= %.2f",
        delta,
        threshold
      ),
      delta = delta,
      strata_mean = strata_mean
    ))
  }

  list(
    signal = "none",
    note = "within_threshold",
    delta = delta,
    strata_mean = strata_mean
  )
}
