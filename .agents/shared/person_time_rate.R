# Section 11: Jeffreys Gamma-Poisson person-time incidence rate inference.

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "person_time_rate.R", files)
  script_dir <- if (length(own)) dirname(tail(own, 1L)[[1L]]) else file.path(getwd(), ".agents", "shared")
  contrasts_path <- file.path(script_dir, "comparative_contrasts.R")
  if (!file.exists(contrasts_path)) stop("[MISSING_COMPARATIVE_CONTRASTS] comparative_contrasts.R が見つかりません")
  source(contrasts_path, local = FALSE)
})

run_person_time_rate <- function(
  target_events,
  target_exposure,
  reference_events,
  reference_exposure,
  exposure_unit = "person_years",
  num_draws = 4000L,
  seed = 42L,
  level = 0.95,
  persist_raw_draws = FALSE
) {
  valid_events <- function(x) {
    is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 &&
      x == floor(x) && x <= .Machine$integer.max
  }
  valid_exposure <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0
  if (!valid_events(target_events) || !valid_events(reference_events)) {
    stop("[INVALID_EVENT_COUNT] イベント数は非負の有限整数で指定してください")
  }
  if (!valid_exposure(target_exposure) || !valid_exposure(reference_exposure)) {
    stop("[INVALID_EXPOSURE] 曝露人時は有限の正値で指定してください")
  }
  if (!is.character(exposure_unit) || length(exposure_unit) != 1L || is.na(exposure_unit) ||
      !exposure_unit %in% c("person_years", "person_months")) {
    stop("[INVALID_EXPOSURE_UNIT] 単位はperson_yearsまたはperson_monthsを指定してください")
  }
  if (!is.numeric(num_draws) || length(num_draws) != 1L || !is.finite(num_draws) ||
      num_draws < 10 || num_draws != floor(num_draws) || num_draws > .Machine$integer.max) {
    stop("[INVALID_NUM_DRAWS] draw数は10以上の有限整数で指定してください")
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      seed != floor(seed) || seed < 0 || seed > .Machine$integer.max)) {
    stop("[INVALID_SEED] seedは非負の有限整数かNULLで指定してください")
  }
  if (!is.logical(persist_raw_draws) || length(persist_raw_draws) != 1L || is.na(persist_raw_draws)) {
    stop("[INVALID_DRAW_STORAGE] persist_raw_drawsはTRUEまたはFALSEで指定してください")
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    stop("[INVALID_INTERVAL_LEVEL] 信用区間水準は0と1の間で指定してください")
  }

  target_events <- as.integer(target_events)
  reference_events <- as.integer(reference_events)
  num_draws <- as.integer(num_draws)
  if (!is.null(seed)) {
    seed <- as.integer(seed)
    set.seed(seed)
  }
  target_shape <- target_events + 0.5
  reference_shape <- reference_events + 0.5
  target_draws <- stats::rgamma(num_draws, shape = target_shape, rate = target_exposure)
  reference_draws <- stats::rgamma(num_draws, shape = reference_shape, rate = reference_exposure)
  if (any(!is.finite(target_draws)) || any(!is.finite(reference_draws)) ||
      any(target_draws <= 0) || any(reference_draws <= 0)) {
    stop("[NUMERICAL_RATE_DRAW_FAILURE] 有限・正値のGamma率drawを生成できませんでした")
  }

  evidence <- compute_rate_contrasts(
    target_draws = target_draws,
    reference_draws = reference_draws,
    target_events = target_events,
    target_exposure = target_exposure,
    reference_events = reference_events,
    reference_exposure = reference_exposure,
    exposure_unit = exposure_unit,
    level = level
  )
  metadata <- list(
    exposure_unit = exposure_unit,
    rate_unit = evidence$person_time$rate_unit,
    gamma_parameterization = "shape_rate",
    target_events = target_events,
    reference_events = reference_events,
    target_exposure = target_exposure,
    reference_exposure = reference_exposure,
    target_shape = target_shape,
    reference_shape = reference_shape
  )
  draws <- list(
    schema_version = "comparative-draws-v1",
    design = "person_time",
    inferential_semantics = "posterior",
    num_draws = num_draws,
    draw_storage = if (persist_raw_draws) "persisted" else "ephemeral",
    target_draws = if (persist_raw_draws) target_draws else NULL,
    reference_draws = if (persist_raw_draws) reference_draws else NULL,
    seed = seed,
    person_time_metadata = metadata
  )
  list(draws = draws, evidence = evidence)
}
