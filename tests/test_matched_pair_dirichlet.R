# tests/test_matched_pair_dirichlet.R — 1:1 matched-pair Dirichlet engine

test_pass <- 0L
test_fail <- 0L
assert_true <- function(condition, message) {
  if (isTRUE(condition)) {
    cat(sprintf("[PASS] %s\n", message))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", message))
    test_fail <<- test_fail + 1L
  }
}
assert_error_code <- function(expr, code, message) {
  error_message <- tryCatch({ expr; NULL }, error = function(e) conditionMessage(e))
  assert_true(!is.null(error_message) && grepl(code, error_message, fixed = TRUE), message)
}

source(".agents/shared/matched_pair_dirichlet.R")

pair_data <- data.frame(
  pair_id = sprintf("P%02d", 1:10),
  target_outcome = c(rep(1L, 5L), rep(0L, 5L)),
  reference_outcome = c(rep(1L, 3L), 0L, 0L, 1L, rep(0L, 4L)),
  stringsAsFactors = FALSE
)

cat("=== 1. Four-cell extraction and input validation ===\n")
counts <- extract_matched_pair_counts(pair_data)
assert_true(identical(unname(counts), c(3L, 2L, 1L, 4L)), "Extracts n11=3, n10=2, n01=1, n00=4")
assert_error_code(extract_matched_pair_counts(rbind(pair_data, pair_data[1L, ])), "INVALID_PAIR_ID", "Rejects duplicate pair identifiers")
bad_outcome <- pair_data
bad_outcome$target_outcome[[1L]] <- 2L
assert_error_code(extract_matched_pair_counts(bad_outcome), "INVALID_BINARY_OUTCOME", "Rejects non-binary outcomes")

cat("=== 2. Dirichlet sampling and posterior identities ===\n")
samples <- sample_matched_pair_dirichlet(counts, num_draws = 2000L, seed = 101L)
assert_true(max(abs(rowSums(samples$cell_probabilities) - 1)) < 1e-12, "Every Dirichlet draw sums to one")
assert_true(max(abs(samples$risk_difference_draws -
  (samples$cell_probabilities[, "n10"] - samples$cell_probabilities[, "n01"]))) < 1e-12,
  "RD draw equals p10 - p01")
assert_true(max(abs(samples$target_draws - (samples$cell_probabilities[, "n11"] + samples$cell_probabilities[, "n10"]))) < 1e-12,
  "Target marginal risk equals p11 + p10")
assert_true(max(abs(samples$reference_draws - (samples$cell_probabilities[, "n11"] + samples$cell_probabilities[, "n01"]))) < 1e-12,
  "Reference marginal risk equals p11 + p01")
assert_true(abs(mean(samples$risk_difference_draws) - (2.5 - 1.5) / 12) < 0.015,
  "RD posterior mean agrees with the analytical Dirichlet expectation")

cat("=== 3. Standardized output and reproducibility ===\n")
run_one <- run_matched_pair_dirichlet(data = pair_data, num_draws = 2000L, seed = 202L, primary_delta = 0.05)
run_two <- run_matched_pair_dirichlet(counts = counts, num_draws = 2000L, seed = 202L, primary_delta = 0.05)
assert_true(identical(run_one$evidence$risk_difference$estimate$value,
  run_two$evidence$risk_difference$estimate$value), "Fixed seed yields identical posterior median")
assert_true(identical(run_one$draws$inferential_semantics, "posterior") &&
  identical(run_one$evidence$risk_difference$estimate$source, "posterior_median") &&
  identical(run_one$evidence$risk_difference$interval$method, "posterior_eti"),
  "Output preserves posterior, median, and ETI semantics")
assert_true(identical(run_one$evidence$matched_pair$cell_counts$n11, 3L) &&
  identical(run_one$evidence$matched_pair$pair_count, 10L) &&
  identical(run_one$evidence$matched_pair$concordant_pair_count, 7L) &&
  identical(run_one$evidence$matched_pair$discordant_pair_count, 3L),
  "Metadata records total, concordant, discordant, and cell counts")
metadata_json <- jsonlite::fromJSON(jsonlite::toJSON(run_one$evidence, auto_unbox = TRUE, null = "null"),
  simplifyVector = FALSE)
assert_true(identical(metadata_json$matched_pair$pair_count, 10L) &&
  identical(metadata_json$matched_pair$discordant_pair_count, 3L),
  "JSON round trip preserves matched-pair sample metadata")
assert_true(!is.null(run_one$evidence$matched_pair$odds_ratio$estimate$value) &&
  !is.null(run_one$evidence$matched_pair$intra_pair_association_or$estimate$value),
  "Discordant-pair matched OR and intra-pair association OR summaries are available")
assert_true(identical(run_one$evidence$matched_pair$odds_ratio_definition, "discordant_pair_p10_over_p01"),
  "odds_ratio_definition metadata is recorded as discordant_pair_p10_over_p01")
assert_true(isTRUE(all.equal(run_one$evidence$matched_pair$odds_ratio$mean, 5.0)),
  "Exact Dirichlet posterior expectation for conditional OR matches analytical solution (5.0)")
assert_true(isTRUE(all.equal(run_one$evidence$matched_pair$intra_pair_association_or$mean, 21.0)),
  "Exact Dirichlet posterior expectation for association OR matches analytical solution (21.0)")
assert_true(is.null(run_one$draws$target_draws) && is.null(run_one$draws$cell_probability_draws),
  "Raw draws are ephemeral by default")
run_persisted <- run_matched_pair_dirichlet(counts = counts, num_draws = 20L, seed = 3L, persist_raw_draws = TRUE)
assert_true(length(run_persisted$draws$target_draws) == 20L &&
  nrow(run_persisted$draws$cell_probability_draws) == 20L, "Explicit persistence returns all draw types")
persisted_cells <- run_persisted$draws$cell_probability_draws
expected_conditional_or <- exp(stats::median(log(persisted_cells[, "n10"]) - log(persisted_cells[, "n01"])))
expected_association_or <- exp(stats::median(log(persisted_cells[, "n11"]) + log(persisted_cells[, "n00"]) -
  log(persisted_cells[, "n10"]) - log(persisted_cells[, "n01"])))
assert_true(isTRUE(all.equal(run_persisted$evidence$matched_pair$odds_ratio$estimate$value,
  expected_conditional_or, tolerance = 1e-12)),
  "Primary odds_ratio is the discordant-pair matched OR p10/p01")
assert_true(isTRUE(all.equal(run_persisted$evidence$matched_pair$intra_pair_association_or$estimate$value,
  expected_association_or, tolerance = 1e-12)),
  "intra_pair_association_or preserves p11*p00/(p10*p01)")

golden <- sample_matched_pair_dirichlet(counts, num_draws = 4000L, seed = 42L)
golden_quantiles <- stats::quantile(golden$risk_difference_draws, probs = c(0.025, 0.5, 0.975))
assert_true(all(abs(unname(golden_quantiles) - c(-0.23866021, 0.07815699, 0.40388076)) < 1e-4),
  "Fixed-seed RD quantiles match the matched-pair golden reference")

cat("=== 4. Odds-ratio zero-cell diagnostics ===\n")
# Case A: n10 > 0, n01 == 0 -> conditional OR mean undefined, association OR mean undefined
zero_reference_discordant <- run_matched_pair_dirichlet(counts = c(n11 = 4L, n10 = 2L, n01 = 0L, n00 = 4L),
  num_draws = 2000L, seed = 9L)
assert_true(identical(zero_reference_discordant$evidence$matched_pair$odds_ratio$mean_is_finite, FALSE) &&
  is.null(zero_reference_discordant$evidence$matched_pair$odds_ratio$mean),
  "Conditional OR theoretical mean is suppressed when n01 is zero")
assert_true(identical(zero_reference_discordant$evidence$matched_pair$intra_pair_association_or$mean_is_finite, FALSE) &&
  is.null(zero_reference_discordant$evidence$matched_pair$intra_pair_association_or$mean),
  "Association OR theoretical mean is also suppressed when n01 is zero")

# Case B: n10 == 0, n01 > 0 -> conditional OR mean is finite, association OR mean undefined
zero_target_discordant <- run_matched_pair_dirichlet(counts = c(n11 = 4L, n10 = 0L, n01 = 2L, n00 = 4L),
  num_draws = 2000L, seed = 9L)
assert_true(identical(zero_target_discordant$evidence$matched_pair$odds_ratio$mean_is_finite, TRUE) &&
  is.finite(zero_target_discordant$evidence$matched_pair$odds_ratio$mean) &&
  identical(zero_target_discordant$evidence$matched_pair$intra_pair_association_or$mean_is_finite, FALSE) &&
  is.null(zero_target_discordant$evidence$matched_pair$intra_pair_association_or$mean),
  "Conditional OR mean is finite when n10=0 and n01>0 while association OR mean is suppressed")
assert_true(isTRUE(all.equal(zero_target_discordant$evidence$matched_pair$odds_ratio$mean, (0 + 0.5) / (2 - 0.5))),
  "Exact conditional OR mean equals (0 + 0.5) / (2 - 0.5) when n10=0")

# Case C: n10 == 0, n01 == 0 -> both non-finite
zero_both_discordant <- run_matched_pair_dirichlet(counts = c(n11 = 4L, n10 = 0L, n01 = 0L, n00 = 4L),
  num_draws = 2000L, seed = 9L)
assert_true(identical(zero_both_discordant$evidence$matched_pair$odds_ratio$mean_is_finite, FALSE) &&
  is.null(zero_both_discordant$evidence$matched_pair$odds_ratio$mean) &&
  identical(zero_both_discordant$evidence$matched_pair$intra_pair_association_or$mean_is_finite, FALSE) &&
  is.null(zero_both_discordant$evidence$matched_pair$intra_pair_association_or$mean),
  "Both OR means are suppressed when both discordant counts are zero")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
