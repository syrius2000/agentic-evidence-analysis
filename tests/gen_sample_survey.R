#!/usr/bin/env Rscript
# tests/gen_sample_survey.R — sample_survey.csv を生成するスクリプト

set.seed(42)
n <- 300

gender       <- sample(c("men", "women"), n, replace = TRUE, prob = c(.48, .52))
department   <- sample(c("naika", "geka", "shonika", "seikei"), n, replace = TRUE,
                       prob = c(.4, .2, .2, .2))
age_group    <- sample(c("20s", "30s", "40s", "50s", "60plus"), n, replace = TRUE,
                       prob = c(.15, .2, .25, .2, .2))
visit_type   <- sample(c("outpatient", "inpatient"), n, replace = TRUE, prob = c(.7, .3))
time_band    <- sample(c("morning", "afternoon"), n, replace = TRUE, prob = c(.55, .45))
response_status <- sample(c("complete", "incomplete"), n, replace = TRUE, prob = c(.9, .1))
sat_levels   <- c("very_unsatisfied", "unsatisfied", "neutral", "satisfied", "very_satisfied")
satisfaction <- sample(sat_levels, n, replace = TRUE, prob = c(.05, .1, .35, .35, .15))
wait_levels  <- c("short", "normal", "long")
waiting_eval <- sample(wait_levels, n, replace = TRUE, prob = c(.25, .45, .3))

df <- data.frame(
  gender, department, age_group, visit_type, time_band,
  response_status, satisfaction, waiting_eval,
  stringsAsFactors = FALSE
)

ca <- commandArgs(trailingOnly = FALSE)
file_arg <- ca[grep("^--file=", ca)]
if (length(file_arg) > 0) {
  out_path <- file.path(dirname(normalizePath(sub("^--file=", "", file_arg[1]))),
                        "sample_survey.csv")
} else {
  out_path <- "tests/sample_survey.csv"
}

write.csv(df, out_path, row.names = FALSE)
cat("Written:", out_path, "(rows:", nrow(df), "cols:", ncol(df), ")\n")
print(head(df, 3))
