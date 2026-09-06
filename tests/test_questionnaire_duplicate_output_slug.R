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

td <- tempfile("questionnaire_duplicate_slug_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

data_path <- file.path(td, "survey.csv")
utils::write.csv(
  data.frame(
    response = c("yes", "no", "yes", "no"),
    group = c("a", "a", "b", "b")
  ),
  data_path,
  row.names = FALSE
)

make_config <- function(slugs) {
  n <- length(slugs)
  data.frame(
    survey_id = rep("survey", n),
    question_id = sprintf("q%02d", seq_len(n)),
    analysis_type = rep("nominal_2way", n),
    var1 = rep("response", n),
    var2 = rep("group", n),
    var3 = rep("", n),
    output_slug = slugs,
    question_label = sprintf("Question %d", seq_len(n)),
    subset_expr = rep("", n),
    na_policy = rep("drop", n),
    ordered_levels = rep("", n),
    reference_note = rep("", n),
    stringsAsFactors = FALSE
  )
}

assert_no_artifacts <- function(path) {
  stopifnot(!dir.exists(path))
  stopifnot(!file.exists(file.path(path, "summary.csv")))
  stopifnot(!file.exists(file.path(path, "report.html")))
  stopifnot(!file.exists(file.path(path, "questionnaire_results.json")))
  stopifnot(!dir.exists(file.path(path, "figures")))
}

run_invalid_case <- function(case_name, slugs, message_pattern, outside_paths = character(0)) {
  config_path <- file.path(td, paste0(case_name, "_questions.csv"))
  output_root <- file.path(td, paste0(case_name, "_output"))
  utils::write.csv(make_config(slugs), config_path, row.names = FALSE, na = "")

  output <- suppressWarnings(
    system2(
      "Rscript",
      c(
        "--vanilla",
        runner,
        "--data",
        data_path,
        "--question-config",
        config_path,
        "--out",
        output_root
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L

  stopifnot(as.integer(status) != 0L)
  stopifnot(any(grepl(message_pattern, output)))
  assert_no_artifacts(output_root)
  for (outside_path in outside_paths) {
    assert_no_artifacts(outside_path)
  }
}

run_valid_case <- function(case_name, slugs, config = make_config(slugs)) {
  config_path <- file.path(td, paste0(case_name, "_questions.csv"))
  output_root <- file.path(td, paste0(case_name, "_output"))
  utils::write.csv(config, config_path, row.names = FALSE, na = "")

  output <- suppressWarnings(
    system2(
      "Rscript",
      c(
        "--vanilla",
        runner,
        "--data",
        data_path,
        "--question-config",
        config_path,
        "--out",
        output_root
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L

  if (!identical(as.integer(status), 0L)) {
    stop(paste(output, collapse = "\n"))
  }
  stopifnot(file.exists(file.path(output_root, "summary.csv")))
  for (slug in slugs) {
    stopifnot(file.exists(file.path(output_root, slug, "report.html")))
    stopifnot(file.exists(file.path(
      output_root,
      slug,
      "questionnaire_results.json"
    )))
  }
  invisible(output_root)
}

run_invalid_case(
  "exact_duplicate",
  c("duplicated_slug", "duplicated_slug"),
  "output_slug.*重複"
)
run_invalid_case(
  "same_real_path",
  c("same_slug", "same_slug/."),
  "output_slug.*重複"
)
run_invalid_case(
  "case_insensitive_duplicate",
  c("Question1", "question1"),
  "output_slug.*重複"
)
run_invalid_case(
  "trailing_dot",
  c("q01."),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_colon",
  c("q:01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_asterisk",
  c("q*01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_question_mark",
  c("q?01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_quote",
  c("q\"01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_less_than",
  c("q<01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_greater_than",
  c("q>01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "forbidden_pipe",
  c("q|01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "non_ascii_japanese",
  c("質問01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "non_ascii_accent",
  c("qé"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "invalid_leading_underscore",
  c("_q01"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "invalid_leading_hyphen",
  c("-q02"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "invalid_leading_dot",
  c(".q03"),
  "output_slug.*ASCII"
)
run_invalid_case(
  "too_long",
  c(strrep("a", 101L)),
  "output_slug.*100"
)
run_invalid_case(
  "trailing_space",
  c("q01 "),
  "output_slug.*ASCII"
)
run_invalid_case(
  "windows_reserved_con",
  c("CON"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_prn_casefold",
  c("prn"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_aux_extension",
  c("AUX.txt"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_nul_extension",
  c("nul.json"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_com1_extension",
  c("COM1.csv"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_com9_casefold",
  c("com9"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_lpt1_extension",
  c("LPT1.log"),
  "output_slug.*予約名"
)
run_invalid_case(
  "windows_reserved_lpt9_casefold",
  c("lpt9"),
  "output_slug.*予約名"
)

traversal_target <- file.path(td, "outside_traversal")
run_invalid_case(
  "parent_traversal",
  c("../outside_traversal"),
  "output_slug.*安全な単一",
  traversal_target
)

absolute_target <- file.path(td, "outside_absolute")
run_invalid_case(
  "absolute_path",
  c(absolute_target),
  "output_slug.*安全な単一",
  absolute_target
)
run_invalid_case(
  "forward_separator",
  c("nested/slug"),
  "output_slug.*安全な単一"
)
run_invalid_case(
  "backslash_separator",
  c("nested\\slug"),
  "output_slug.*安全な単一"
)
run_valid_case(
  "valid_ascii_boundaries",
  c(
    "q01",
    "Q02.section_1-final",
    paste0("a", strrep("b", 98L), "_")
  )
)
run_valid_case(
  "leading_zero_slugs",
  c("001", "002")
)
run_valid_case(
  "numeric_text_distinct",
  c("1", "01")
)
run_valid_case(
  "literal_na_slug",
  c("NA")
)
non_slug_na_config <- make_config("NA")
non_slug_na_config$var3 <- "NA"
non_slug_na_config$subset_expr <- "NA"
non_slug_na_config$ordered_levels <- "NA"
non_slug_na_config$reference_note <- "NA"
non_slug_na_output <- run_valid_case(
  "non_slug_na_sentinels",
  c("NA"),
  config = non_slug_na_config
)
non_slug_na_summary <- utils::read.csv(
  file.path(non_slug_na_output, "summary.csv"),
  stringsAsFactors = FALSE
)
stopifnot(identical(non_slug_na_summary$status, "success"))
stopifnot(identical(non_slug_na_summary$n_total, 4L))
stopifnot(identical(non_slug_na_summary$n_used, 4L))

message("OK: unsafe or duplicate output_slug values stop before any artifacts are generated")
