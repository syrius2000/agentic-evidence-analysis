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
source(".agents/shared/iptw_inference.R")

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
assert_true("rd_estimate" %in% names(res$summary_df) && !("rd_posterior_median" %in% names(res$summary_df)),
            "Summary uses inference-neutral estimate field names")
meta <- read_run_control(res$run_output_dir)
assert_true(identical(meta$skill, "vcd-categorical-reporting"), "Run control recognizes reporting skill")
assert_true(identical(meta$pass_status$pass1, "completed"), "Pass 1 is completed after artifacts exist")
assert_true(identical(meta$inputs[[1L]]$sha256, meta$data_frame_sha256), "In-memory input SHA-256 is recorded")
assert_true(identical(meta$data_frame_hash_contract,
  "R-serialize-v2: column names, types, classes, values, row order"), "Hash contract records input order and type")
assert_true(isTRUE(verify_results_manifest(res$run_output_dir)$valid), "Results manifest verifies registered artifacts")

out_dir_grid <- tempfile("comp_rep_grid_")
res_grid <- generate_comparative_report(batch_df[batch_df$theme == "AE_Infection", ],
  reference_arm = "Placebo", output_dir = out_dir_grid, delta_thresholds = c(0.02, 0.04))
meta_grid <- read_run_control(res_grid$run_output_dir)
payload_grid <- jsonlite::read_json(res_grid$json_path, simplifyVector = TRUE)
assert_true(identical(unlist(meta_grid$delta_thresholds), c(0.02, 0.04)), "Delta grid is retained in run metadata")
assert_true(identical(unlist(payload_grid$delta_thresholds), c(0.02, 0.04)), "Delta grid is retained in batch evidence")

duplicate_input <- rbind(batch_df, batch_df[1L, , drop = FALSE])
duplicate_error <- tryCatch({generate_comparative_report(duplicate_input, output_dir = tempfile("duplicate_")); NULL},
  error = function(e) conditionMessage(e))
assert_true(!is.null(duplicate_error) && grepl("DUPLICATE_THEME_GROUP", duplicate_error, fixed = TRUE),
            "Duplicate theme-group rows fail before a run is reserved")

res_changed <- generate_comparative_report(transform(batch_df[batch_df$theme == "AE_Infection", ],
  events = events + 1L), reference_arm = "Placebo", output_dir = tempfile("changed_input_"))
assert_true(!identical(read_run_control(res_changed$run_output_dir)$data_frame_sha256,
                       read_run_control(res_grid$run_output_dir)$data_frame_sha256),
            "Input hash changes when event values change")

input_csv <- tempfile(fileext = ".csv")
utils::write.csv(batch_df[batch_df$theme == "AE_Infection", ], input_csv, row.names = FALSE)
res_file <- generate_comparative_report(utils::read.csv(input_csv, stringsAsFactors = FALSE),
  reference_arm = "Placebo", input_data_path = input_csv, output_dir = tempfile("file_provenance_"))
meta_file <- read_run_control(res_file$run_output_dir)
assert_true(identical(meta_file$inputs[[1L]]$sha256, sha256_file(input_csv)),
            "File input SHA-256 is retained in run metadata")

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
assert_true(grepl("ETI", md_text, fixed = TRUE) && grepl("P(RD > 0)", md_text, fixed = TRUE), "Bayesian report retains posterior interval and direction terminology")

assert_true(grepl("同等性の誤認禁止", html_text, fixed = TRUE), "HTML dashboard contains '同等性の誤認禁止' guard")
assert_true(grepl("因果的優越の禁止", html_text, fixed = TRUE), "HTML dashboard contains '因果的優越の禁止' guard")
assert_true(grepl("多重比較スクリーニング免責", html_text, fixed = TRUE), "HTML dashboard contains '多重比較スクリーニング免責' disclaimer")

set.seed(73L)
iptw_input <- data.frame(treatment = rep(c(1L, 0L), each = 60L), outcome = rbinom(120L, 1L, 0.2), age = rnorm(120L))
iptw_ev <- run_iptw_inference(iptw_input, covariates = "age", num_draws = 100L, seed = 73L)$evidence
iptw_report_df <- data.frame(
  theme = "synthetic",
  arm = c("Target", "Reference"),
  events = c(sum(iptw_input$outcome[iptw_input$treatment == 1L]), sum(iptw_input$outcome[iptw_input$treatment == 0L])),
  total = c(sum(iptw_input$treatment == 1L), sum(iptw_input$treatment == 0L))
)
iptw_key <- "synthetic__Target_vs_Reference"
iptw_report <- generate_comparative_report(iptw_report_df, target_arm = "Target", reference_arm = "Reference", contrast_mode = "explicit",
  evidence_overrides = setNames(list(iptw_ev), iptw_key), output_dir = tempfile("iptw_report_"))
iptw_md <- paste(readLines(iptw_report$md_path, warn = FALSE), collapse = "\n")
iptw_row <- iptw_report$summary_df[iptw_report$summary_df$inferential_semantics == "bootstrap", , drop = FALSE]
assert_true(nrow(iptw_row) == 1L && iptw_row$interval_label == "bootstrap percentile interval", "IPTW override is rendered with bootstrap percentile interval semantics")
assert_true(grepl("Bootstrap support fraction (RD > 0)", iptw_md, fixed = TRUE), "IPTW report labels direction support as a bootstrap support fraction")
assert_true(iptw_row$target_events == iptw_ev$iptw$raw_patient_counts$target_events && iptw_row$target_total == iptw_ev$iptw$raw_patient_counts$target,
            "Report raw descriptive counts match the same-source IPTW evidence")
assert_true(isTRUE(all.equal(iptw_row$target_ess, iptw_ev$iptw$effective_sample_size$target)) && grepl("有効標本サイズ ESS (T / R)", iptw_md, fixed = TRUE),
            "Report displays effective sample size separately from raw sample size")
assert_true(is.na(iptw_row$fisher_p_value) && is.na(iptw_row$design_aware_fisher_p_value), "Fisher compatibility output is absent for design-aware evidence by default")
assert_true(!grepl("ETI", iptw_md, fixed = TRUE) && !grepl("posterior median", tolower(iptw_md), fixed = TRUE) && !grepl("P(RD > 0)", iptw_md, fixed = TRUE) && !grepl("信用区間", iptw_md, fixed = TRUE),
            "IPTW report contains no Bayesian posterior or ETI terminology")
bad_source_counts <- iptw_report_df
bad_source_counts$events[[1L]] <- bad_source_counts$events[[1L]] + 1L
provenance_error <- tryCatch(generate_comparative_report(bad_source_counts, target_arm = "Target", reference_arm = "Reference",
  contrast_mode = "explicit", evidence_overrides = setNames(list(iptw_ev), iptw_key), output_dir = tempfile("iptw_mismatch_")),
  error = function(e) conditionMessage(e))
assert_true(!is.null(provenance_error) && grepl("EVIDENCE_REPORT_PROVENANCE_MISMATCH", provenance_error, fixed = TRUE),
            "Mismatched report counts fail with governed provenance error")

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
neutral_report <- generate_comparative_report(data.frame(theme = c("neutral", "neutral"),
  arm = c("A", "B"), events = c(10L, 10L), total = c(100L, 100L)),
  primary_delta = 0.10, output_dir = tempfile("neutral_palette_"))
neutral_html <- paste(readLines(neutral_report$html_path, warn = FALSE), collapse = "\n")
assert_true(grepl("rgba(100, 116, 139", neutral_html, fixed = TRUE),
            "Practical-neutral region uses neutral gray")

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
