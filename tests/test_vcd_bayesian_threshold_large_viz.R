# large_sample_mode / threshold_k(level倍率) / viz_thresholds の契約検証
# Run from repo root: Rscript tests/test_vcd_bayesian_threshold_large_viz.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_thresholds_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

csv <- file.path(td, "input.csv")
write.csv(
  data.frame(
    Sex = c("F", "F", "M", "M"),
    Event = c("Y", "N", "Y", "N"),
    Weight = c(10, 20, 30, 40),
    stringsAsFactors = FALSE
  ),
  csv,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Case 1: high threshold => large_sample_mode = FALSE
out1 <- file.path(td, "case1")
dir.create(out1)
st1 <- system2("Rscript", c(
  analysis,
  "--input", csv,
  "--output_dir", out1,
  "--vars", "Sex,Event",
  "--freq", "Weight",
  "--threshold_k", "1.5",
  "--level2_factor", "2.5",
  "--level3_factor", "4",
  "--large_n_threshold", "200"
))
stopifnot(identical(as.integer(st1), 0L))
jp1 <- list.files(out1, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp1) == 1L)
res1 <- jsonlite::fromJSON(jp1[1L])

expected_level1 <- round(1.5 * log(100), 4)
expected_level2 <- round(2.5 * expected_level1, 4)
expected_level3 <- round(4 * expected_level1, 4)
stopifnot(identical(res1$core$large_sample_mode, FALSE))
stopifnot(abs(res1$thresholds$level1 - expected_level1) < 1e-8)
stopifnot(abs(res1$thresholds$level2 - expected_level2) < 1e-8)
stopifnot(abs(res1$thresholds$level3 - expected_level3) < 1e-8)

vt <- res1$extensions$viz_thresholds
stopifnot(all(c(
  "residual_abs_p90", "residual_abs_p95", "residual_abs_p99",
  "score_abs_p90", "score_abs_p95", "score_abs_p99"
) %in% names(vt)))
stopifnot(all(is.finite(unlist(vt))))

# Case 2: low threshold => large_sample_mode = TRUE
out2 <- file.path(td, "case2")
dir.create(out2)
st2 <- system2("Rscript", c(
  analysis,
  "--input", csv,
  "--output_dir", out2,
  "--vars", "Sex,Event",
  "--freq", "Weight",
  "--large_n_threshold", "80"
))
stopifnot(identical(as.integer(st2), 0L))
jp2 <- list.files(out2, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp2) == 1L)
res2 <- jsonlite::fromJSON(jp2[1L])
stopifnot(identical(res2$core$large_sample_mode, TRUE))

message("OK: threshold/large_sample/viz contracts")
