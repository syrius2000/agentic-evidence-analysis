#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
analysis <- file.path(
  root,
  ".agents",
  "skills",
  "vcd-categorical-analysis",
  "templates",
  "analysis.R"
)
stopifnot(file.exists(analysis))

td <- tempfile("vcd_categorical_runs_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

run_analysis <- function(mode, extra_args = character(0)) {
  mode_arg <- if (identical(mode, "profile")) "--profile" else "--render"
  output <- suppressWarnings(system2(
    "Rscript",
    c("--vanilla", analysis, mode_arg, "--out", td, extra_args),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(output, collapse = "\n"))
  }
  invisible(output)
}

run_profile <- function(extra_args = character(0)) {
  run_analysis("profile", extra_args)
}

run_render <- function(extra_args = character(0)) {
  run_analysis("render", extra_args)
}

missing_data_out <- file.path(td, "missing_data_out")
missing_data_path <- file.path(td, "does_not_exist.csv")
missing_data_output <- suppressWarnings(system2(
  "Rscript",
  c(
    "--vanilla",
    analysis,
    "--profile",
    "--out", missing_data_out,
    "--run-id", "missing_data",
    "--data", missing_data_path
  ),
  stdout = TRUE,
  stderr = TRUE
))
missing_data_status <- attr(missing_data_output, "status")
if (is.null(missing_data_status)) missing_data_status <- 0L
stopifnot(as.integer(missing_data_status) != 0L)
stopifnot(any(grepl("--data.*存在しません", missing_data_output)))
stopifnot(!dir.exists(missing_data_out))

missing_config_out <- file.path(td, "missing_config_out")
missing_config_input <- file.path(td, "config_input_does_not_exist.csv")
missing_config_path <- file.path(td, "missing_input_config.json")
jsonlite::write_json(
  list(
    input = missing_config_input,
    output_dir = missing_config_out,
    run_id = "missing_config_input"
  ),
  missing_config_path,
  auto_unbox = TRUE,
  pretty = TRUE
)
missing_config_output <- suppressWarnings(system2(
  "Rscript",
  c(
    "--vanilla",
    analysis,
    "--profile",
    "--config", missing_config_path
  ),
  stdout = TRUE,
  stderr = TRUE
))
missing_config_status <- attr(missing_config_output, "status")
if (is.null(missing_config_status)) missing_config_status <- 0L
stopifnot(as.integer(missing_config_status) != 0L)
stopifnot(any(grepl("config input.*存在しません", missing_config_output)))
stopifnot(!dir.exists(missing_config_out))

run_profile()

auto_runs <- list.dirs(td, recursive = FALSE, full.names = FALSE)
auto_runs <- auto_runs[grepl("^run_[0-9]{8}_[0-9]{6}$", auto_runs)]
stopifnot(length(auto_runs) == 1L)
auto_meta <- jsonlite::fromJSON(file.path(td, auto_runs, "run_meta.json"))
stopifnot(grepl("^[0-9]{8}_[0-9]{6}$", auto_meta$run_id))
stopifnot(identical(auto_meta$run_state, "profile_complete"))

run_profile(c("--run-id", "collision_case"))
run_profile(c("--run-id", "collision_case"))

stopifnot(dir.exists(file.path(td, "run_collision_case")))
stopifnot(dir.exists(file.path(td, "run_collision_case_2")))
stopifnot(file.exists(file.path(td, "run_collision_case", "data_profile.json")))
stopifnot(file.exists(file.path(td, "run_collision_case_2", "data_profile.json")))

meta_1 <- jsonlite::fromJSON(
  file.path(td, "run_collision_case", "run_meta.json")
)
meta_2 <- jsonlite::fromJSON(
  file.path(td, "run_collision_case_2", "run_meta.json")
)
stopifnot(identical(meta_1$run_id, "collision_case"))
stopifnot(identical(meta_2$run_id, "collision_case_2"))
stopifnot(identical(meta_1$requested_run_id, "collision_case"))
stopifnot(identical(meta_2$requested_run_id, "collision_case"))
stopifnot(grepl("^[0-9a-f]{64}$", meta_1$analysis_signature))
stopifnot(identical(meta_1$analysis_signature, meta_2$analysis_signature))

if (identical(.Platform$OS.type, "unix")) {
  atomic_jobs <- lapply(seq_len(4L), function(i) {
    parallel::mcparallel(
      suppressWarnings(system2(
        "Rscript",
        c(
          "--vanilla",
          analysis,
          "--profile",
          "--out", td,
          "--run-id", "atomic_case"
        ),
        stdout = TRUE,
        stderr = TRUE
      )),
      silent = TRUE,
      mc.set.seed = FALSE
    )
  })
  atomic_outputs <- parallel::mccollect(atomic_jobs)
  atomic_statuses <- vapply(atomic_outputs, function(output) {
    if (inherits(output, "try-error")) return(1L)
    status <- attr(output, "status")
    if (is.null(status)) 0L else as.integer(status)
  }, integer(1))
  stopifnot(all(atomic_statuses == 0L))

  atomic_dirs <- list.dirs(td, recursive = FALSE, full.names = TRUE)
  atomic_dirs <- atomic_dirs[grepl(
    "^run_atomic_case(_[0-9]+)?$",
    basename(atomic_dirs)
  )]
  stopifnot(length(atomic_dirs) == 4L)
  atomic_meta <- lapply(
    file.path(atomic_dirs, "run_meta.json"),
    jsonlite::fromJSON
  )
  atomic_run_ids <- vapply(atomic_meta, `[[`, character(1), "run_id")
  atomic_states <- vapply(atomic_meta, `[[`, character(1), "run_state")
  stopifnot(length(unique(atomic_run_ids)) == 4L)
  stopifnot(all(atomic_states == "profile_complete"))
} else {
  message("SKIP: atomic run reservation concurrency test requires Unix fork support")
}

if (identical(.Platform$OS.type, "unix")) {
  concurrent_run_id <- "exclusive_render"
  run_profile(c("--run-id", concurrent_run_id))
  concurrent_profile_dir <- file.path(td, "run_exclusive_render")
  concurrent_profile_meta <- jsonlite::fromJSON(file.path(
    concurrent_profile_dir,
    "run_meta.json"
  ))

  residual_config <- file.path(td, "render_residual_only.json")
  always_config <- file.path(td, "render_always.json")
  jsonlite::write_json(
    list(plot_mode = "residual_only"),
    residual_config,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  jsonlite::write_json(
    list(plot_mode = "always"),
    always_config,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  launch_render <- function(config_path, tag) {
    parallel::mcparallel({
      output <- suppressWarnings(system2(
        "Rscript",
        c(
          "--vanilla",
          analysis,
          "--render",
          "--config", config_path,
          "--out", td,
          "--run-id", concurrent_run_id
        ),
        stdout = TRUE,
        stderr = TRUE
      ))
      status <- attr(output, "status")
      if (is.null(status)) status <- 0L
      list(tag = tag, status = as.integer(status), output = output)
    }, silent = TRUE, mc.set.seed = FALSE)
  }

  render_jobs <- list(
    launch_render(residual_config, "residual_only"),
    launch_render(always_config, "always")
  )
  render_results <- parallel::mccollect(render_jobs)
  stopifnot(all(vapply(render_results, function(result) {
    !inherits(result, "try-error") && identical(result$status, 0L)
  }, logical(1))))

  render_paths <- vapply(render_results, function(result) {
    run_line <- grep(
      "^\\[INFO\\] run 出力先: ",
      result$output,
      value = TRUE
    )
    stopifnot(length(run_line) == 1L)
    sub("^\\[INFO\\] run 出力先: ", "", run_line)
  }, character(1))
  render_tags <- vapply(render_results, `[[`, character(1), "tag")
  render_path_by_tag <- stats::setNames(render_paths, render_tags)

  stopifnot(length(unique(render_paths)) == 2L)
  stopifnot(identical(
    sort(basename(render_paths)),
    c("run_exclusive_render", "run_exclusive_render_2")
  ))
  stopifnot(file.exists(file.path(
    concurrent_profile_dir,
    "data_profile.json"
  )))
  stopifnot(!file.exists(file.path(
    td,
    "run_exclusive_render_2",
    "data_profile.json"
  )))

  for (render_path in render_paths) {
    stopifnot(file.exists(file.path(
      render_path,
      "data_profile_post.json"
    )))
    stopifnot(file.exists(file.path(
      render_path,
      "categorical_results.json"
    )))
    render_meta <- jsonlite::fromJSON(file.path(
      render_path,
      "run_meta.json"
    ))
    stopifnot(identical(render_meta$run_state, "render_complete"))
    stopifnot(identical(
      render_meta$requested_run_id,
      concurrent_run_id
    ))
    stopifnot(identical(
      render_meta$analysis_signature,
      concurrent_profile_meta$analysis_signature
    ))
    stopifnot(identical(
      normalizePath(render_meta$run_output_dir, mustWork = TRUE),
      normalizePath(render_path, mustWork = TRUE)
    ))
  }

  stopifnot(length(list.files(
    render_path_by_tag[["residual_only"]],
    pattern = "\\.png$"
  )) == 0L)
  stopifnot(length(list.files(
    render_path_by_tag[["always"]],
    pattern = "\\.png$"
  )) > 0L)
} else {
  message("SKIP: exclusive render claim concurrency test requires Unix fork support")
}

run_profile(c("--run-id", "stale_claim"))
stale_claim_profile_dir <- file.path(td, "run_stale_claim")
stale_claim_meta_path <- file.path(
  stale_claim_profile_dir,
  "run_meta.json"
)
stale_claim_meta_before <- jsonlite::fromJSON(stale_claim_meta_path)
stale_claim_dir <- file.path(stale_claim_profile_dir, ".render_claim")
stopifnot(dir.create(stale_claim_dir, recursive = FALSE))

run_render(c("--run-id", "stale_claim"))

stale_claim_meta_after <- jsonlite::fromJSON(stale_claim_meta_path)
stopifnot(identical(
  stale_claim_meta_after$run_state,
  "profile_complete"
))
stopifnot(identical(
  stale_claim_meta_after$updated_at,
  stale_claim_meta_before$updated_at
))
stopifnot(dir.exists(stale_claim_dir))
stopifnot(!file.exists(file.path(
  stale_claim_profile_dir,
  "categorical_results.json"
)))
stale_claim_render_dir <- file.path(td, "run_stale_claim_2")
stopifnot(file.exists(file.path(
  stale_claim_render_dir,
  "categorical_results.json"
)))
stale_claim_render_meta <- jsonlite::fromJSON(file.path(
  stale_claim_render_dir,
  "run_meta.json"
))
stopifnot(identical(
  stale_claim_render_meta$run_state,
  "render_complete"
))

run_profile(c("--run-id", "requested_case"))
run_profile(c("--run-id", "requested_case"))
ambiguous_profile_dir <- file.path(td, "run_requested_case_2")
ambiguous_profile_meta <- jsonlite::fromJSON(
  file.path(ambiguous_profile_dir, "run_meta.json")
)
stopifnot(identical(ambiguous_profile_meta$run_id, "requested_case_2"))
stopifnot(identical(ambiguous_profile_meta$requested_run_id, "requested_case"))

run_render(c("--run-id", "requested_case_2"))
stopifnot(!file.exists(file.path(ambiguous_profile_dir, "categorical_results.json")))
distinct_requested_dir <- file.path(td, "run_requested_case_2_2")
stopifnot(file.exists(file.path(distinct_requested_dir, "categorical_results.json")))
distinct_requested_meta <- jsonlite::fromJSON(
  file.path(distinct_requested_dir, "run_meta.json")
)
stopifnot(identical(distinct_requested_meta$run_id, "requested_case_2_2"))
stopifnot(identical(distinct_requested_meta$requested_run_id, "requested_case_2"))

data_a <- file.path(td, "identity_a.csv")
data_b <- file.path(td, "identity_b.csv")
utils::write.csv(
  data.frame(
    row = c("a", "a", "b", "b"),
    col = c("x", "y", "x", "y"),
    Freq = c(10, 20, 30, 40),
    Count = c(40, 30, 20, 10)
  ),
  data_a,
  row.names = FALSE
)
utils::write.csv(
  data.frame(
    row = c("a", "a", "b", "b"),
    col = c("x", "y", "x", "y"),
    Freq = c(11, 20, 30, 40),
    Count = c(40, 30, 20, 10)
  ),
  data_b,
  row.names = FALSE
)

run_profile(c(
  "--run-id", "input_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Freq"
))
input_profile_dir <- file.path(td, "run_input_identity")
input_profile_meta <- jsonlite::fromJSON(file.path(input_profile_dir, "run_meta.json"))
run_render(c(
  "--run-id", "input_identity",
  "--data", data_b,
  "--vars", "row,col",
  "--freq", "Freq"
))
stopifnot(!file.exists(file.path(input_profile_dir, "categorical_results.json")))
input_render_dir <- file.path(td, "run_input_identity_2")
stopifnot(file.exists(file.path(input_render_dir, "categorical_results.json")))
input_render_meta <- jsonlite::fromJSON(file.path(input_render_dir, "run_meta.json"))
stopifnot(!identical(
  input_profile_meta$analysis_signature,
  input_render_meta$analysis_signature
))

run_profile(c(
  "--run-id", "vars_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Freq"
))
vars_profile_dir <- file.path(td, "run_vars_identity")
vars_profile_meta <- jsonlite::fromJSON(file.path(vars_profile_dir, "run_meta.json"))
run_render(c(
  "--run-id", "vars_identity",
  "--data", data_a,
  "--vars", "col,row",
  "--freq", "Freq"
))
stopifnot(!file.exists(file.path(vars_profile_dir, "categorical_results.json")))
vars_render_dir <- file.path(td, "run_vars_identity_2")
stopifnot(file.exists(file.path(vars_render_dir, "categorical_results.json")))
vars_render_meta <- jsonlite::fromJSON(file.path(vars_render_dir, "run_meta.json"))
stopifnot(!identical(
  vars_profile_meta$analysis_signature,
  vars_render_meta$analysis_signature
))

run_profile(c(
  "--run-id", "freq_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Freq"
))
freq_profile_dir <- file.path(td, "run_freq_identity")
freq_profile_meta <- jsonlite::fromJSON(file.path(freq_profile_dir, "run_meta.json"))
run_render(c(
  "--run-id", "freq_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Count"
))
stopifnot(!file.exists(file.path(freq_profile_dir, "categorical_results.json")))
freq_render_dir <- file.path(td, "run_freq_identity_2")
stopifnot(file.exists(file.path(freq_render_dir, "categorical_results.json")))
freq_render_meta <- jsonlite::fromJSON(file.path(freq_render_dir, "run_meta.json"))
stopifnot(!identical(
  freq_profile_meta$analysis_signature,
  freq_render_meta$analysis_signature
))

run_profile(c(
  "--run-id", "legacy_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Freq"
))
legacy_profile_dir <- file.path(td, "run_legacy_identity")
legacy_meta_path <- file.path(legacy_profile_dir, "run_meta.json")
legacy_meta <- jsonlite::fromJSON(legacy_meta_path)
legacy_meta$requested_run_id <- NULL
legacy_meta$analysis_signature <- NULL
jsonlite::write_json(
  legacy_meta,
  legacy_meta_path,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)
run_render(c(
  "--run-id", "legacy_identity",
  "--data", data_a,
  "--vars", "row,col",
  "--freq", "Freq"
))
stopifnot(!file.exists(file.path(legacy_profile_dir, "categorical_results.json")))
stopifnot(file.exists(file.path(
  td,
  "run_legacy_identity_2",
  "categorical_results.json"
)))

run_profile(c("--run-id", "missing_state"))
missing_state_dir <- file.path(td, "run_missing_state")
missing_state_meta_path <- file.path(missing_state_dir, "run_meta.json")
missing_state_meta <- jsonlite::fromJSON(missing_state_meta_path)
missing_state_meta$run_state <- NULL
jsonlite::write_json(
  missing_state_meta,
  missing_state_meta_path,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)
run_render(c("--run-id", "missing_state"))
stopifnot(!file.exists(file.path(
  missing_state_dir,
  "categorical_results.json"
)))
missing_state_render_dir <- file.path(td, "run_missing_state_2")
stopifnot(file.exists(file.path(
  missing_state_render_dir,
  "categorical_results.json"
)))
missing_state_render_meta <- jsonlite::fromJSON(
  file.path(missing_state_render_dir, "run_meta.json")
)
stopifnot(identical(
  missing_state_render_meta$run_state,
  "render_complete"
))

run_profile(c("--run-id", "unknown_state"))
unknown_state_dir <- file.path(td, "run_unknown_state")
unknown_state_meta_path <- file.path(unknown_state_dir, "run_meta.json")
unknown_state_meta <- jsonlite::fromJSON(unknown_state_meta_path)
unknown_state_meta$run_state <- "unexpected_state"
jsonlite::write_json(
  unknown_state_meta,
  unknown_state_meta_path,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)
run_render(c("--run-id", "unknown_state"))
stopifnot(!file.exists(file.path(
  unknown_state_dir,
  "categorical_results.json"
)))
unknown_state_render_dir <- file.path(td, "run_unknown_state_2")
stopifnot(file.exists(file.path(
  unknown_state_render_dir,
  "categorical_results.json"
)))

run_profile(c("--run-id", "partial_render"))
interrupted_dir <- file.path(td, "run_partial_render")
interrupted_meta_path <- file.path(interrupted_dir, "run_meta.json")
interrupted_meta <- jsonlite::fromJSON(interrupted_meta_path)
interrupted_meta$run_state <- "render_in_progress"
jsonlite::write_json(
  interrupted_meta,
  interrupted_meta_path,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)
partial_marker <- "partial output from interrupted render"
writeLines(
  partial_marker,
  file.path(interrupted_dir, "data_profile_post.json")
)
changed_render_config <- file.path(td, "changed_render_config.json")
jsonlite::write_json(
  list(plot_mode = "residual_only"),
  changed_render_config,
  auto_unbox = TRUE,
  pretty = TRUE
)
run_render(c(
  "--run-id", "partial_render",
  "--config", changed_render_config
))
stopifnot(identical(
  readLines(file.path(interrupted_dir, "data_profile_post.json")),
  partial_marker
))
stopifnot(!file.exists(file.path(
  interrupted_dir,
  "categorical_results.json"
)))
interrupted_retry_dir <- file.path(td, "run_partial_render_2")
stopifnot(file.exists(file.path(
  interrupted_retry_dir,
  "categorical_results.json"
)))
interrupted_retry_meta <- jsonlite::fromJSON(
  file.path(interrupted_retry_dir, "run_meta.json")
)
stopifnot(identical(
  interrupted_retry_meta$run_state,
  "render_complete"
))

run_profile(c("--run-id", "two_pass_case"))
continuation_dir <- file.path(td, "run_two_pass_case")
stopifnot(file.exists(file.path(continuation_dir, "data_profile.json")))
continuation_profile_meta <- jsonlite::fromJSON(
  file.path(continuation_dir, "run_meta.json")
)
stopifnot(identical(
  continuation_profile_meta$run_state,
  "profile_complete"
))

run_render(c("--run-id", "two_pass_case"))

continuation_runs <- list.dirs(td, recursive = FALSE, full.names = FALSE)
continuation_runs <- continuation_runs[grepl("^run_two_pass_case(_[0-9]+)?$", continuation_runs)]
stopifnot(identical(continuation_runs, "run_two_pass_case"))
stopifnot(file.exists(file.path(continuation_dir, "data_profile.json")))
stopifnot(file.exists(file.path(continuation_dir, "data_profile_post.json")))
stopifnot(file.exists(file.path(continuation_dir, "categorical_results.json")))
continuation_meta <- jsonlite::fromJSON(file.path(continuation_dir, "run_meta.json"))
stopifnot(identical(continuation_meta$run_id, "two_pass_case"))
stopifnot(identical(continuation_meta$run_state, "render_complete"))
stopifnot(identical(
  normalizePath(continuation_meta$run_output_dir, mustWork = TRUE),
  normalizePath(continuation_dir, mustWork = TRUE)
))

run_render(c("--run-id", "two_pass_case"))
rerun_dir <- file.path(td, "run_two_pass_case_2")
stopifnot(dir.exists(rerun_dir))
stopifnot(file.exists(file.path(rerun_dir, "categorical_results.json")))
rerun_meta <- jsonlite::fromJSON(file.path(rerun_dir, "run_meta.json"))
stopifnot(identical(rerun_meta$run_id, "two_pass_case_2"))
stopifnot(identical(rerun_meta$run_state, "render_complete"))

message("OK: categorical runs preserve profile-to-render continuity and collision isolation")
