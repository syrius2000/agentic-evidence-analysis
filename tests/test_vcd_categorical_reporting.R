# tests/test_vcd_categorical_reporting.R — Comparative Reporting Skill Test Suite
# Tests Tasks 4.1 through 4.13 of OpenSpec comparative-evidence-reporting-v3

test_pass <- 0L
test_fail <- 0L

assert_true <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("[PASS] %s\n", msg))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", msg))
    test_fail <<- test_fail + 1L
  }
}

source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")

cat("=== 1. Test Multi-Theme Tabular Ingestion & Reference-vs-All Contrasts ===\n")
# Multi-theme synthetic dataset: 2 themes, 3 arms
batch_df <- data.frame(
  theme = c("AE_Infection", "AE_Infection", "AE_Infection", "AE_Nervous", "AE_Nervous", "AE_Nervous"),
  arm = c("Drug_A", "Drug_B", "Placebo", "Drug_A", "Drug_B", "Placebo"),
  events = c(15L, 8L, 4L, 25L, 18L, 20L),
  total = c(100L, 100L, 100L, 100L, 100L, 100L),
  stringsAsFactors = FALSE
)

out_dir <- tempfile("comp_rep_test_")
res <- generate_comparative_report(
  df = batch_df,
  reference_arm = "Placebo",
  contrast_mode = "reference_vs_all",
  primary_delta = 0.05,
  output_dir = out_dir
)

assert_true(file.exists(res$json_path), "comparative_evidence.json exists")
assert_true(file.exists(res$csv_path), "comparative_summary.csv exists")
assert_true(file.exists(res$md_path), "comparative_report.md exists")
assert_true(file.exists(res$html_path), "dashboard.html exists")

# 2 themes x 2 comparisons (Drug_A vs Placebo, Drug_B vs Placebo) = 4 rows
assert_true(nrow(res$summary_df) == 4L, "Summary CSV has exactly 4 comparison rows")

cat("\n=== 2. Test All-Pairs Contrast Mode ===\n")
out_dir_all <- tempfile("comp_rep_all_")
res_all <- generate_comparative_report(
  df = batch_df[batch_df$theme == "AE_Infection", ],
  contrast_mode = "all_pairs",
  output_dir = out_dir_all
)
# 3 choose 2 = 3 pairs for 1 theme
assert_true(nrow(res_all$summary_df) == 3L, "All-pairs generated exactly 3 pairwise combinations")

cat("\n=== 3. Audit Zero-External-Asset & Zero Absolute Path Rule in HTML ===\n")
html_text <- paste(readLines(res$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Check for external network calls (http://, https://, //)
has_http <- grepl("http://", html_text, fixed = TRUE)
has_https <- grepl("https://", html_text, fixed = TRUE)
has_protocol_relative <- grepl("//", html_text, fixed = TRUE)
assert_true(!has_http && !has_https && !has_protocol_relative, "HTML contains zero external HTTP/HTTPS network dependencies")

# Check for local absolute OS paths
has_local_user <- grepl("/Users/", html_text, fixed = TRUE)
has_local_home <- grepl("/home/", html_text, fixed = TRUE)
assert_true(!has_local_user && !has_local_home, "HTML contains zero local OS absolute paths")

cat("\n=== 4. Test Narrative Guards & Disclaimers in Reports ===\n")
md_text <- paste(readLines(res$md_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

assert_true(grepl("同等性の誤認禁止", md_text, fixed = TRUE), "Markdown report contains '同等性の誤認禁止' guard")
assert_true(grepl("因果的優越の禁止", md_text, fixed = TRUE), "Markdown report contains '因果的優越の禁止' guard")
assert_true(grepl("探索的スクリーニング免責", md_text, fixed = TRUE), "Markdown report contains '探索的スクリーニング免責' disclaimer")

assert_true(grepl("同等性の誤認禁止", html_text, fixed = TRUE), "HTML dashboard contains '同等性の誤認禁止' guard")
assert_true(grepl("因果的優越の禁止", html_text, fixed = TRUE), "HTML dashboard contains '因果的優越の禁止' guard")
assert_true(grepl("多重比較スクリーニング免責", html_text, fixed = TRUE), "HTML dashboard contains '多重比較スクリーニング免責' disclaimer")

cat("\n=== 5. Test Visual Encoding Guard (Hue not determined by P(RD > 0) alone) ===\n")
# When primary_delta is NULL, all row backgrounds must be transparent
out_dir_none <- tempfile("comp_rep_none_")
res_none <- generate_comparative_report(
  df = batch_df[batch_df$theme == "AE_Infection", ],
  reference_arm = "Placebo",
  primary_delta = NULL,
  output_dir = out_dir_none
)
html_none <- paste(readLines(res_none$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(!grepl("background-color: rgba(", html_none, fixed = TRUE), "Row background color is disabled when primary_delta is NULL")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
