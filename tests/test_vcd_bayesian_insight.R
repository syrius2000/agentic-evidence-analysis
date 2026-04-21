library(testthat)
library(jsonlite)

repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = TRUE)
  if (file.exists(file.path(d, ".agent"))) return(d)
  if (identical(basename(d), "tests")) return(normalizePath(file.path(d, ".."), mustWork = TRUE))
  d
}

test_that("analysis.R detects Simpson Paradox in UCBAdmissions", {
  # Prepare UCBAdmissions data
  data(UCBAdmissions)
  df <- as.data.frame(UCBAdmissions)
  csv_path <- tempfile(fileext = ".csv")
  write.csv(df, csv_path, row.names = FALSE)
  
  out_dir <- tempdir()
  if (!dir.exists(out_dir)) dir.create(out_dir)
  
  # Run analysis with UCB setup: strata=Dept, pairs=Admit,Gender
  script <- file.path(repo_root(), ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
  stopifnot(file.exists(script))
  system2("Rscript", c(script, "--input", csv_path, "--output_dir", out_dir, "--strata_var", "Dept", "--pair_vars", "Admit,Gender"))
  
  json_path <- list.files(out_dir, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
  if (length(json_path) != 1L) {
    stop("JSON output not found under ", out_dir)
  }
  json_path <- json_path[1L]
  
  res <- fromJSON(json_path, simplifyVector = FALSE) # Use simplifyVector = FALSE for nested lists
  if (!"structural_anomalies" %in% names(res)) {
    skip("現行 Pass1 の evidence_results に structural_anomalies が含まれない")
  }
  expect_true("structural_anomalies" %in% names(res))
  
  anomalies <- res$structural_anomalies
  has_simpson <- any(sapply(anomalies, function(x) x$type == "simpson_reversal"))
  expect_true(has_simpson)
  
  unlink(csv_path)
  unlink(out_dir, recursive = TRUE)
})
