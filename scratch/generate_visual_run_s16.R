# scratch/generate_visual_run_s16.R
# Generate clean, self-contained visual QA run conforming to Task 14.10 / 14.10.R1 / 14.10.R2

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")
source(".agents/shared/run_scope.R")

# 1. Deterministic 6-theme fixture (same as Section 14)
df_visual <- data.frame(
  theme = c(
    "T1_TargetExcess", "T1_TargetExcess",
    "T2_RefExcess", "T2_RefExcess",
    "T3_Neutral", "T3_Neutral",
    "T4_U3_Uncertain", "T4_U3_Uncertain",
    "T5_TargetU2", "T5_TargetU2",
    "T6_ZeroRef", "T6_ZeroRef"
  ),
  arm = rep(c("Active", "Control"), 6L),
  events = c(
    45L, 5L,    # T1
    5L, 45L,    # T2
    50L, 50L,   # T3
    10L, 10L,   # T4 (delta=0.01 -> U3 target_excess)
    12L, 8L,    # T5
    10L, 0L     # T6 (ZERO_REFERENCE)
  ),
  total = c(
    100L, 100L,
    100L, 100L,
    1000L, 1000L,
    100L, 100L,
    100L, 100L,
    100L, 100L
  ),
  stringsAsFactors = FALSE
)

# 2. Execute report generation into evidence_runs/visual_qa_s14
out_root <- "evidence_runs/visual_qa_s14"
res <- generate_comparative_report(
  df = df_visual,
  target_arm = "Active",
  reference_arm = "Control",
  group_col = "arm",
  theme_col = "theme",
  events_col = "events",
  total_col = "total",
  contrast_mode = "explicit",
  primary_delta = 0.01,
  domain = "safety",
  output_dir = out_root
)

run_dir <- res$run_output_dir
cat(sprintf("Generated run directory: %s\n", run_dir))

# 3. Verify manifest
ver <- verify_results_manifest(run_dir)
if (!ver$valid) {
  stop("[ERROR] results_manifest verification failed!")
}
cat("[PASS] results_manifest is valid and hashes match.\n")

# 4. Check data-sort-value on all columns
html_content <- paste(readLines(res$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Count table rows and data-sort-value occurrences
tr_matches <- gregexpr("<tr><td class=", html_content)[[1L]]
num_rows <- length(tr_matches)
dsv_matches <- gregexpr("data-sort-value=", html_content)[[1L]]
num_dsv <- length(dsv_matches)

cat(sprintf("Number of data rows: %d\n", num_rows))
cat(sprintf("Total data-sort-value attributes: %d\n", num_dsv))
if (num_dsv != num_rows * 10L) {
  stop(sprintf("[ERROR] Expected %d data-sort-value attributes (10 per row * %d rows), found %d", num_rows * 10L, num_rows, num_dsv))
}
cat("[PASS] Exactly 10 data-sort-value attributes per row across all columns.\n")
