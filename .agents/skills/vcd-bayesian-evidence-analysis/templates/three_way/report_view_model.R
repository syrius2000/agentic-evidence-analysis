# Convert three-way-results-v1 into display-only values. No statistical decisions live here.
report_fmt <- function(x) {
  if (is.null(x) || !length(x)) "保留／未算出"
  else if (is.numeric(x)) format(signif(x, 5), trim = TRUE)
  else as.character(x)
}

build_report_view_model <- function(result) {
  symbols <- c("A", "B", "C")
  variables <- unlist(result$input_summary$variables, use.names = FALSE)
  levels <- result$input_summary$levels
  factor_rows <- lapply(seq_along(variables), function(i) list(
    symbol = symbols[[i]], name = variables[[i]], levels = unlist(levels[[variables[[i]]]], use.names = FALSE)
  ))
  model_rows <- lapply(result$models, function(model) list(
    id = model$id, anchor = paste0("model-", tolower(model$id)), structure = model$structure,
    formula = model$formula, status = model$status, status_reasons = model$status_reasons,
    warnings = model$warnings, deviance = model$deviance, df = model$df_residual,
    bic = model$bic_multinomial_n, inference = model$inference
  ))
  eligible <- Filter(function(model) identical(model$status, "REGULAR") &&
                       is.numeric(model$bic) && is.finite(model$bic), model_rows)
  lowest_bic_id <- if (length(eligible)) eligible[[which.min(vapply(eligible, `[[`, numeric(1), "bic"))]]$id else NULL
  holds <- sum(vapply(model_rows, function(model) !identical(model$status, "REGULAR"), logical(1)))
  list(
    status = result$status,
    status_class = if (identical(result$status, "COMPUTED")) "computed" else "hold",
    variables = variables, factors = factor_rows, models = model_rows,
    lowest_bic_id = lowest_bic_id, model_hold_count = holds,
    total_n = result$input_summary$total_n, n_cells = result$input_summary$n_cells,
    comparisons = result$comparisons, cells = result$cells, posterior = result$posterior,
    decisions = result$decisions, provenance = result$provenance
  )
}
