#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
inspect_script <- file.path(root, ".agents", "shared", "inspect_data.R")
stopifnot(file.exists(inspect_script))

td <- tempfile("inspect_out_dir_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

input_a <- file.path(td, "input_a.csv")
input_b <- file.path(td, "input_b.csv")
utils::write.csv(
  data.frame(group = c("a", "b"), value = c(1, 2)),
  input_a,
  row.names = FALSE
)
utils::write.csv(
  data.frame(group = c("a", "b", "c"), value = c(3, 4, 5)),
  input_b,
  row.names = FALSE
)

out_a <- file.path(td, "run_a")
out_b <- file.path(td, "run_b")

run_inspect <- function(script_args, work_dir = td) {
  previous_dir <- setwd(work_dir)
  on.exit(setwd(previous_dir), add = TRUE)
  output <- suppressWarnings(system2(
    "Rscript",
    c("--vanilla", inspect_script, script_args),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = output)
}

flag_result <- run_inspect(c(input_a, "--out-dir", out_a))
positional_result <- run_inspect(c(input_b, out_b))

stopifnot(identical(flag_result$status, 0L))
stopifnot(identical(positional_result$status, 0L))

result_a_path <- file.path(out_a, "inspection_results.json")
result_b_path <- file.path(out_b, "inspection_results.json")
stopifnot(file.exists(result_a_path))
stopifnot(file.exists(result_b_path))

result_a <- jsonlite::fromJSON(result_a_path)
result_b <- jsonlite::fromJSON(result_b_path)
stopifnot(identical(result_a$n_rows, 2L))
stopifnot(identical(result_b$n_rows, 3L))
stopifnot(!identical(normalizePath(result_a_path), normalizePath(result_b_path)))

equals_out <- file.path(td, "run_equals")
equals_result <- run_inspect(c(
  input_a,
  paste0("--out-dir=", equals_out)
))
stopifnot(identical(equals_result$status, 0L))
stopifnot(file.exists(file.path(equals_out, "inspection_results.json")))

default_cwd <- file.path(td, "default_cwd")
dir.create(default_cwd)
default_result <- run_inspect(c(input_b), work_dir = default_cwd)
stopifnot(identical(default_result$status, 0L))
default_result_path <- file.path(default_cwd, "inspection_results.json")
stopifnot(file.exists(default_result_path))
default_data <- jsonlite::fromJSON(default_result_path)
stopifnot(identical(default_data$n_rows, 3L))

invalid_cwd <- file.path(td, "invalid_cwd")
dir.create(invalid_cwd)
root_result_path <- file.path(.Platform$file.sep, "inspection_results.json")
root_result_existed <- file.exists(root_result_path)
empty_shell_arg <- shQuote("")

invalid_cases <- list(
  out_dir_equals_empty = c(input_a, "--out-dir="),
  out_dir_flag_empty = c(input_a, "--out-dir", empty_shell_arg),
  positional_out_dir_empty = c(input_a, empty_shell_arg)
)
for (case_name in names(invalid_cases)) {
  invalid_result <- run_inspect(
    invalid_cases[[case_name]],
    work_dir = invalid_cwd
  )
  stopifnot(invalid_result$status != 0L)
  stopifnot(any(grepl("out-dir.*空", invalid_result$output)))
  stopifnot(!file.exists(file.path(
    invalid_cwd,
    "inspection_results.json"
  )))
  stopifnot(identical(file.exists(root_result_path), root_result_existed))
}

message("OK: inspect_data validates default, positional, equals, and flag out-dir forms")
