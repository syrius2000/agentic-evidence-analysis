#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
contract <- file.path(
  root,
  ".agents",
  "skills",
  "questionnaire-batch-analysis",
  "templates",
  "marginal_strata_contract.R"
)
stopifnot(file.exists(contract))
source(contract)

stopifnot(identical(MARGINAL_STRATA_DELTA, 0.05))

below <- classify_marginal_strata(
  cramer_v_marginal = 0.0499,
  strata_v = c(a = 0, b = NA_real_)
)
stopifnot(identical(below$signal, "none"))
stopifnot(identical(below$note, "within_threshold"))
stopifnot(isTRUE(all.equal(below$delta, 0.0499)))

boundary <- classify_marginal_strata(
  cramer_v_marginal = 0.05,
  strata_v = c(a = 0, b = NA_real_)
)
stopifnot(identical(boundary$signal, "review_stratified"))
stopifnot(grepl(">= 0.05", boundary$note, fixed = TRUE))
stopifnot(isTRUE(all.equal(boundary$delta, 0.05)))

uncomputable_marginal <- classify_marginal_strata(
  cramer_v_marginal = NA_real_,
  strata_v = c(a = 0.1, b = 0.2)
)
stopifnot(identical(uncomputable_marginal$signal, "none"))
stopifnot(identical(uncomputable_marginal$note, "insufficient_strata_or_na"))
stopifnot(is.na(uncomputable_marginal$delta))

uncomputable_strata <- classify_marginal_strata(
  cramer_v_marginal = 0.2,
  strata_v = c(a = NA_real_, b = Inf)
)
stopifnot(identical(uncomputable_strata$signal, "none"))
stopifnot(identical(uncomputable_strata$note, "insufficient_strata_or_na"))
stopifnot(is.na(uncomputable_strata$strata_mean))

message("OK: marginal/strata classification fixes the >= 0.05 boundary contract")
