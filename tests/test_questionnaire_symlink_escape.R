#!/usr/bin/env Rscript

root <- normalizePath(".", mustWork = TRUE)
runner <- file.path(
  root,
  ".agents",
  "skills",
  "questionnaire-batch-analysis",
  "templates",
  "batch_runner.R"
)
stopifnot(file.exists(runner))

td <- tempfile("questionnaire_symlink_escape_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

data_path <- file.path(td, "survey.csv")
config_path <- file.path(td, "questions.csv")
output_root <- file.path(td, "output")
outside_target <- file.path(td, "outside_target")
slug <- "symlink_escape"

utils::write.csv(
  data.frame(
    response = c("yes", "no", "yes", "no"),
    group = c("a", "a", "b", "b")
  ),
  data_path,
  row.names = FALSE
)
utils::write.csv(
  data.frame(
    survey_id = "survey",
    question_id = "q01",
    analysis_type = "nominal_2way",
    var1 = "response",
    var2 = "group",
    var3 = "",
    output_slug = slug,
    question_label = "Question 1",
    subset_expr = "",
    na_policy = "drop",
    ordered_levels = "",
    reference_note = "",
    stringsAsFactors = FALSE
  ),
  config_path,
  row.names = FALSE,
  na = ""
)

dir.create(output_root)
dir.create(outside_target)
link_path <- file.path(output_root, slug)
symlink_created <- suppressWarnings(file.symlink(outside_target, link_path))
if (!isTRUE(symlink_created)) {
  message("SKIP: filesystem does not support creating a directory symlink")
  quit(status = 0L)
}

output <- suppressWarnings(system2(
  "Rscript",
  c(
    "--vanilla",
    runner,
    "--data", data_path,
    "--question-config", config_path,
    "--out", output_root
  ),
  stdout = TRUE,
  stderr = TRUE
))
status <- attr(output, "status")
if (is.null(status)) status <- 0L

stopifnot(as.integer(status) != 0L)
stopifnot(any(grepl("出力root外", output)))
stopifnot(!file.exists(file.path(output_root, "summary.csv")))
stopifnot(!file.exists(file.path(outside_target, "report.html")))
stopifnot(!file.exists(file.path(
  outside_target,
  "questionnaire_results.json"
)))
stopifnot(!dir.exists(file.path(outside_target, "figures")))

message("OK: questionnaire rejects a slug symlink that escapes the output root")
