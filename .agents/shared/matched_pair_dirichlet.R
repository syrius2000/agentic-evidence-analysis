# .agents/shared/matched_pair_dirichlet.R — 1:1 matched-pair Dirichlet inference
# Implements Section 8 of OpenSpec comparative-evidence-reporting-v3.

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "matched_pair_dirichlet.R", files)
  script_dir <- if (length(own)) dirname(tail(own, 1L)[[1L]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(script_dir, "comparative_contrasts.R")
  if (!file.exists(contrasts_path)) stop("[MISSING_COMPARATIVE_CONTRASTS] comparative_contrasts.R が見つかりません")
  source(contrasts_path, local = FALSE)
})

validate_matched_pair_counts <- function(counts) {
  required <- c("n11", "n10", "n01", "n00")
  if (!is.numeric(counts) || is.null(names(counts)) || !setequal(names(counts), required)) {
    stop("[INVALID_MATCHED_PAIR_COUNTS] n11, n10, n01, n00 を名前付き数値で指定してください")
  }
  counts <- counts[required]
  if (anyNA(counts) || any(!is.finite(counts)) || any(counts < 0) || any(counts != floor(counts))) {
    stop("[INVALID_MATCHED_PAIR_COUNTS] 各セルは有限の非負整数である必要があります")
  }
  if (sum(counts) == 0L) stop("[EMPTY_MATCHED_PAIR_DATA] 少なくとも 1 組のマッチドペアが必要です")
  stats::setNames(as.integer(counts), names(counts))
}

extract_matched_pair_counts <- function(
  data,
  pair_id_col = "pair_id",
  target_outcome_col = "target_outcome",
  reference_outcome_col = "reference_outcome"
) {
  if (!is.data.frame(data)) stop("[INVALID_MATCHED_PAIR_DATA] data.frame が必要です")
  required <- c(pair_id_col, target_outcome_col, reference_outcome_col)
  if (!all(required %in% names(data))) {
    stop("[MISSING_MATCHED_PAIR_COLUMNS] 必須列がありません: ", paste(setdiff(required, names(data)), collapse = ", "))
  }
  if (nrow(data) == 0L) stop("[EMPTY_MATCHED_PAIR_DATA] 少なくとも 1 組のマッチドペアが必要です")
  pair_id <- data[[pair_id_col]]
  if (anyNA(pair_id) || any(!nzchar(as.character(pair_id))) || anyDuplicated(pair_id)) {
    stop("[INVALID_PAIR_ID] pair_id は欠損・空文字・重複のない識別子である必要があります")
  }
  validate_binary <- function(x, label) {
    if (is.logical(x)) x <- as.integer(x)
    if (!is.numeric(x) || anyNA(x) || any(!is.finite(x)) || any(!x %in% c(0, 1))) {
      stop("[INVALID_BINARY_OUTCOME] ", label, " は欠損のない 0/1 である必要があります")
    }
    as.integer(x)
  }
  target <- validate_binary(data[[target_outcome_col]], target_outcome_col)
  reference <- validate_binary(data[[reference_outcome_col]], reference_outcome_col)
  validate_matched_pair_counts(c(
    n11 = sum(target == 1L & reference == 1L),
    n10 = sum(target == 1L & reference == 0L),
    n01 = sum(target == 0L & reference == 1L),
    n00 = sum(target == 0L & reference == 0L)
  ))
}

sample_matched_pair_dirichlet <- function(counts, num_draws = 4000L, seed = 42L) {
  counts <- validate_matched_pair_counts(counts)
  if (!is.numeric(num_draws) || length(num_draws) != 1L || is.na(num_draws) ||
      num_draws < 10L || num_draws != floor(num_draws)) {
    stop("[INVALID_NUM_DRAWS] num_draws は 10 以上の整数である必要があります")
  }
  if (!is.null(seed)) set.seed(seed)
  alpha <- as.numeric(counts) + 0.5
  gamma_draws <- vapply(alpha, function(shape) stats::rgamma(as.integer(num_draws), shape = shape, rate = 1), numeric(as.integer(num_draws)))
  probabilities <- gamma_draws / rowSums(gamma_draws)
  colnames(probabilities) <- names(counts)
  list(
    cell_probabilities = probabilities,
    target_draws = probabilities[, "n11"] + probabilities[, "n10"],
    reference_draws = probabilities[, "n11"] + probabilities[, "n01"],
    risk_difference_draws = probabilities[, "n10"] - probabilities[, "n01"]
  )
}

run_matched_pair_dirichlet <- function(
  data = NULL,
  counts = NULL,
  pair_id_col = "pair_id",
  target_outcome_col = "target_outcome",
  reference_outcome_col = "reference_outcome",
  num_draws = 4000L,
  seed = 42L,
  primary_delta = NULL,
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  level = 0.95,
  persist_raw_draws = FALSE
) {
  if (xor(is.null(data), is.null(counts))) {
    cell_counts <- if (!is.null(data)) {
      extract_matched_pair_counts(data, pair_id_col, target_outcome_col, reference_outcome_col)
    } else {
      validate_matched_pair_counts(counts)
    }
  } else {
    stop("[MATCHED_PAIR_INPUT_AMBIGUOUS] data または counts の一方だけを指定してください")
  }
  samples <- sample_matched_pair_dirichlet(cell_counts, num_draws = num_draws, seed = seed)
  total_pairs <- sum(cell_counts)
  target_events <- cell_counts[["n11"]] + cell_counts[["n10"]]
  reference_events <- cell_counts[["n11"]] + cell_counts[["n01"]]
  evidence <- compute_comparative_contrasts(
    target_draws = samples$target_draws,
    reference_draws = samples$reference_draws,
    target_events = target_events,
    target_total = total_pairs,
    reference_events = reference_events,
    reference_total = total_pairs,
    inferential_semantics = "posterior",
    primary_delta = primary_delta,
    delta_thresholds = delta_thresholds,
    level = level,
    domain = "matched_pair"
  )
  alpha <- (1 - level) / 2
  summarize_odds_ratio <- function(log_or_draws, analytic_mean, mean_is_finite) {
    quantiles <- exp(stats::quantile(log_or_draws, probs = c(alpha, 0.5, 1 - alpha), na.rm = TRUE))
    list(
      estimate = list(value = unname(quantiles[[2L]]), source = "posterior_median"),
      interval = list(lower = unname(quantiles[[1L]]), upper = unname(quantiles[[3L]]),
        level = level, method = "posterior_eti"),
      mean = if (mean_is_finite) analytic_mean else NULL,
      mean_is_finite = mean_is_finite
    )
  }
  log_conditional_or_draws <- log(samples$cell_probabilities[, "n10"]) -
    log(samples$cell_probabilities[, "n01"])
  log_association_or_draws <- log(samples$cell_probabilities[, "n11"]) +
    log(samples$cell_probabilities[, "n00"]) -
    log(samples$cell_probabilities[, "n10"]) -
    log(samples$cell_probabilities[, "n01"])

  # Exact Dirichlet posterior expectations:
  # alpha_jk = n_jk + 0.5
  # E[p10 / p01] = alpha_10 / (alpha_01 - 1) = (n10 + 0.5) / (n01 - 0.5) for n01 >= 1
  conditional_or_mean_finite <- cell_counts[["n01"]] > 0L
  conditional_or_analytic_mean <- if (conditional_or_mean_finite) {
    (cell_counts[["n10"]] + 0.5) / (cell_counts[["n01"]] - 0.5)
  } else NULL

  # E[(p11*p00) / (p10*p01)] = (alpha_11 * alpha_00) / ((alpha_10 - 1) * (alpha_01 - 1))
  #                          = ((n11 + 0.5) * (n00 + 0.5)) / ((n10 - 0.5) * (n01 - 0.5))
  # for n10 >= 1 and n01 >= 1
  association_or_mean_finite <- cell_counts[["n10"]] > 0L && cell_counts[["n01"]] > 0L
  association_or_analytic_mean <- if (association_or_mean_finite) {
    ((cell_counts[["n11"]] + 0.5) * (cell_counts[["n00"]] + 0.5)) /
      ((cell_counts[["n10"]] - 0.5) * (cell_counts[["n01"]] - 0.5))
  } else NULL

  evidence$matched_pair <- list(
    pair_count = total_pairs,
    concordant_pair_count = cell_counts[["n11"]] + cell_counts[["n00"]],
    discordant_pair_count = cell_counts[["n10"]] + cell_counts[["n01"]],
    cell_counts = as.list(cell_counts),
    odds_ratio_definition = "discordant_pair_p10_over_p01",
    odds_ratio = summarize_odds_ratio(log_conditional_or_draws, conditional_or_analytic_mean, conditional_or_mean_finite),
    intra_pair_association_or = summarize_odds_ratio(log_association_or_draws, association_or_analytic_mean, association_or_mean_finite)
  )
  draw_storage <- if (isTRUE(persist_raw_draws)) "persisted" else "ephemeral"
  draws <- list(
    schema_version = "comparative-draws-v1",
    inferential_semantics = "posterior",
    num_draws = as.integer(num_draws),
    draw_storage = draw_storage,
    target_draws = if (isTRUE(persist_raw_draws)) samples$target_draws else NULL,
    reference_draws = if (isTRUE(persist_raw_draws)) samples$reference_draws else NULL,
    seed = seed,
    observed_sample_estimate = NULL,
    matched_pair_counts = as.list(cell_counts),
    cell_probability_draws = if (isTRUE(persist_raw_draws)) samples$cell_probabilities else NULL
  )
  list(evidence = evidence, draws = draws)
}
