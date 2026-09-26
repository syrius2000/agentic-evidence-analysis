# .agents/shared/practical_difference_policy.R — Practical Difference and U-Grade Policy Module
# Implements Section 7 of OpenSpec comparative-evidence-reporting-v3

suppressPackageStartupMessages({
  library(jsonlite)
})

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "practical_difference_policy.R", files)
  dir <- if (length(own)) dirname(tail(own, 1)[[1]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(dir, "comparative_contrasts.R")
  if (file.exists(contrasts_path)) source(contrasts_path, local = FALSE)
})

# Normalize delta value from specified natural unit to absolute proportion
normalize_delta_value <- function(value, unit = c("proportion", "per_100", "per_1000")) {
  if (is.null(value) || is.na(value)) return(NULL)
  unit <- match.arg(unit)
  val <- as.numeric(value)
  if (val < 0) stop("[ERROR] [INVALID_DELTA] Delta value must be non-negative.")

  if (unit == "proportion") {
    if (val > 1.0) stop("[ERROR] [INVALID_DELTA] Proportion delta cannot exceed 1.0.")
    return(val)
  } else if (unit == "per_100") {
    if (val > 100.0) stop("[ERROR] [INVALID_DELTA] per_100 delta cannot exceed 100.")
    return(val / 100.0)
  } else if (unit == "per_1000") {
    if (val > 1000.0) stop("[ERROR] [INVALID_DELTA] per_1000 delta cannot exceed 1000.")
    return(val / 1000.0)
  }
}

# Versioned departmental policy loader for standard clinical difference thresholds
get_departmental_delta_policy <- function(policy_version = "v1", domain = "safety") {
  # Default non-normative guideline vector
  if (policy_version == "v1") {
    if (domain == "safety") {
      list(
        policy_version = "v1",
        domain = "safety",
        default_mode = "none",
        recommended_deltas = list(
          mild = list(value = 1.0, unit = "per_100", prop = 0.01),
          moderate = list(value = 2.0, unit = "per_100", prop = 0.02),
          substantial = list(value = 5.0, unit = "per_100", prop = 0.05)
        ),
        u_grade_cutoffs = list(
          U0 = 0.95,
          U1 = 0.80,
          U2 = 0.60
        ),
        u_grade_semantics = paste(
          "U-grade reflects the region classification decisiveness of the active uncertainty distribution",
          "relative to the prespecified practical delta threshold [-delta, +delta].",
          "It does NOT indicate sample size adequacy, generic sampling precision, or clinical severity."
        )
      )
    } else {
      list(
        policy_version = "v1",
        domain = domain,
        default_mode = "none",
        recommended_deltas = list(
          small = list(value = 0.01, unit = "proportion", prop = 0.01),
          medium = list(value = 0.05, unit = "proportion", prop = 0.05)
        ),
        u_grade_cutoffs = list(U0 = 0.95, U1 = 0.80, U2 = 0.60),
        u_grade_semantics = "Classification decisiveness of active uncertainty distribution."
      )
    }
  } else {
    stop("[ERROR] Unknown policy version: ", policy_version)
  }
}

# Simulation utility to evaluate U-grade distribution across varying sample sizes and true RDs
simulate_u_grade_operating_characteristics <- function(
  n_cohort = c(50, 200, 1000),
  base_rate_reference = 0.05,
  true_risk_differences = c(0.0, 0.02, 0.06),
  primary_delta = 0.02,
  num_simulations = 50L,
  num_draws = 1000L,
  seed = 42L
) {
  set.seed(seed)
  results <- list()

  for (n in n_cohort) {
    for (trd in true_risk_differences) {
      p_R_true <- base_rate_reference
      p_T_true <- min(max(p_R_true + trd, 0.001), 0.999)

      u_grades <- character(num_simulations)

      for (sim in seq_len(num_simulations)) {
        x_T <- rbinom(1, n, p_T_true)
        x_R <- rbinom(1, n, p_R_true)

        # posterior draws
        t_d <- rbeta(num_draws, x_T + 0.5, (n - x_T) + 0.5)
        r_d <- rbeta(num_draws, x_R + 0.5, (n - x_R) + 0.5)

        contr <- compute_comparative_contrasts(
          target_draws = t_d,
          reference_draws = r_d,
          target_events = x_T,
          target_total = n,
          reference_events = x_R,
          reference_total = n,
          inferential_semantics = "posterior",
          primary_delta = primary_delta
        )

        u_grades[[sim]] <- contr$resolution_grade$grade
      }

      tab <- table(factor(u_grades, levels = c("U0", "U1", "U2", "U3")))
      props <- as.list(tab / num_simulations)

      results[[length(results) + 1L]] <- list(
        cohort_n = n,
        true_rd = trd,
        primary_delta = primary_delta,
        grade_proportions = props
      )
    }
  }

  results
}
