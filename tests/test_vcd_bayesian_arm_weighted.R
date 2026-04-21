# ARM: 行データ + Freq重み の検証
# Run from repo root: Rscript tests/test_vcd_bayesian_arm_weighted.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_arm_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

csv_path <- file.path(td, "arm_input.csv")
df <- data.frame(
  Segment = c("A", "A", "A", "B"),
  Product = c("X", "X", "Y", "Y"),
  Region = c("East", "East", "West", "West"),
  Freq = c(10, 2, 3, 8),
  stringsAsFactors = FALSE
)
write.csv(df, csv_path, row.names = FALSE, fileEncoding = "UTF-8")

status <- system2("Rscript", c(
  analysis,
  "--input", csv_path,
  "--output_dir", td,
  "--arm_min_support", "0.05",
  "--arm_min_confidence", "0.2",
  "--arm_top_rules", "5"
))
stopifnot(identical(as.integer(status), 0L))

jp <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
res <- jsonlite::fromJSON(jp[1L])
stopifnot("extensions" %in% names(res))
stopifnot("arm" %in% names(res$extensions))
stopifnot(isTRUE(res$extensions$arm$eligible))
stopifnot(nrow(res$extensions$arm$top_rules) > 0)
stopifnot(all(c("lhs", "rhs", "support", "confidence", "lift") %in%
  names(res$extensions$arm$top_rules)))

message("OK: ARM重み付きルール抽出")
