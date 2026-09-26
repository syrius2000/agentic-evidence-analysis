# tests/test_comparative_dashboard_qa.R — Dashboard and Self-Contained Report QA
# Comprehensive automated test suite for Section 14 (Tasks 14.1 - 14.9, 14.R1 - 14.R4)
# Complies with OpenSpec comparative-evidence-reporting-v3 and implementation_plan_017_0926.md

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

cat("=== 1. Test 14.1: Dedicated Concept Group Columns & Provenance ===\n")
df_standard <- data.frame(
  theme = c("Cardio", "Cardio"),
  arm = c("Active", "Control"),
  events = c(25L, 10L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)

out_dir_std <- tempfile("qa_14_std_")
res_std <- generate_comparative_report(
  df = df_standard,
  reference_arm = "Control",
  primary_delta = 0.05,
  output_dir = out_dir_std
)

html_std <- paste(readLines(res_std$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Check required header classes exist (with sortable extension for 14.10)
assert_true(grepl("th scope=\"col\" class=\"col-id sortable\"", html_std, fixed = TRUE), "Header contains col-id")
assert_true(grepl("th scope=\"col\" class=\"col-effect sortable\"", html_std, fixed = TRUE), "Header contains col-effect")
assert_true(
  grepl("100人あたり差 (E100)", html_std, fixed = TRUE),
  "E100 header is a dedicated column"
)
assert_true(
  grepl(">NNT・NNH-like<", html_std, fixed = TRUE),
  "NNT/NNH-like header is a dedicated column"
)
assert_true(
  !grepl("100人あたり差 / NNT・NNH-like", html_std, fixed = TRUE),
  "Combined absolute-translation header is removed"
)
assert_true(grepl("th scope=\"col\" class=\"col-direction sortable\"", html_std, fixed = TRUE), "Header contains col-direction")
assert_true(grepl("th scope=\"col\" class=\"col-practical sortable\"", html_std, fixed = TRUE), "Header contains col-practical")
assert_true(grepl("th scope=\"col\" class=\"col-precision sortable\"", html_std, fixed = TRUE), "Header contains col-precision")
assert_true(grepl("th scope=\"col\" class=\"col-diagnostics sortable\"", html_std, fixed = TRUE), "Header contains col-diagnostics")

# Check provenance columns present in summary_df
required_prov <- c(
  "excess_per_100", "reciprocal_absolute_rd", "reciprocal_status", "reciprocal_direction",
  "rd_interval_width", "log_rr_interval_width", "rr_interval_fold_range",
  "rr_mean_is_finite", "rr_diagnostic", "rr_estimate_available",
  "rr_interval_available", "rr_bootstrap_defined_replicates",
  "rr_bootstrap_undefined_replicates", "badges"
)
for (p in required_prov) {
  assert_true(p %in% names(res_std$summary_df), sprintf("summary_df carries provenance metric: %s", p))
}

cat("\n=== 2. Test 14.2 & 14.3: Practical-Cell-Only Palette & U3 Muted Override ===\n")
# Test target_excess with U0/U1/U2
df_target_exc <- data.frame(
  theme = c("T1", "T1"),
  arm = c("Active", "Control"),
  events = c(45L, 5L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_te <- generate_comparative_report(df_target_exc, reference_arm = "Control", primary_delta = 0.05, output_dir = tempfile("qa_te_"))
html_te <- paste(readLines(res_te$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(grepl("background-color: rgba(239, 68, 68", html_te, fixed = TRUE), "target_excess practical cell uses coral/red hue")
assert_true(!grepl("<tr style='background-color:", html_te, fixed = TRUE), "Row-wide tr background-color is absent (cell-only styling)")

# Test reference_excess
df_ref_exc <- data.frame(
  theme = c("T2", "T2"),
  arm = c("Active", "Control"),
  events = c(5L, 45L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_re <- generate_comparative_report(df_ref_exc, reference_arm = "Control", primary_delta = 0.05, output_dir = tempfile("qa_re_"))
html_re <- paste(readLines(res_re$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(grepl("background-color: rgba(59, 130, 246", html_re, fixed = TRUE), "reference_excess practical cell uses indigo/blue hue")

# Test practical_neutral
df_neut <- data.frame(
  theme = c("T3", "T3"),
  arm = c("Active", "Control"),
  events = c(20L, 20L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_neut <- generate_comparative_report(df_neut, reference_arm = "Control", primary_delta = 0.10, output_dir = tempfile("qa_neut_"))
html_neut <- paste(readLines(res_neut$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(grepl("background-color: rgba(100, 116, 139", html_neut, fixed = TRUE), "practical_neutral practical cell uses neutral slate hue")

# Test primary_delta = NULL -> all practical cells transparent
res_null_delta <- generate_comparative_report(df_target_exc, reference_arm = "Control", primary_delta = NULL, output_dir = tempfile("qa_nd_"))
html_nd <- paste(readLines(res_null_delta$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(!grepl("background-color: rgba(", html_nd, fixed = TRUE), "When primary_delta is NULL, all cells have transparent background")

# Test U3 muted desaturated override: rgba(148, 163, 184, 0.12)
# Strictly deterministic U3 condition: x_T = 10, n_T = 100, x_R = 10, n_R = 100 with delta = 0.01
df_u3 <- data.frame(
  theme = c("T_U3", "T_U3"),
  arm = c("Active", "Control"),
  events = c(10L, 10L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_u3 <- generate_comparative_report(df_u3, reference_arm = "Control", primary_delta = 0.01, output_dir = tempfile("qa_u3_"))
html_u3 <- paste(readLines(res_u3$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
# Strict test adequacy: must be U3 without unconditional pass fallback
assert_true(any(res_u3$summary_df$u_grade == "U3"), "U3 state produced deterministically for test")
assert_true(grepl("rgba(148, 163, 184, 0.12)", html_u3, fixed = TRUE), "U3 practical cell renders with muted desaturated slate override")
assert_true(!grepl("rgba(239, 68, 68", html_u3, fixed = TRUE), "U3 practical cell does NOT contain alarmist red/coral hue")

cat("\n=== 3. Test 14.4: Canonical Diagnostic Badges in Dedicated Column ===\n")
# Zero reference events triggers ZERO_REFERENCE and possibly SPARSE_EVENTS
df_zero_ref <- data.frame(
  theme = c("T_Zero", "T_Zero"),
  arm = c("Active", "Control"),
  events = c(5L, 0L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_zr <- generate_comparative_report(df_zero_ref, reference_arm = "Control", output_dir = tempfile("qa_zr_"))
html_zr <- paste(readLines(res_zr$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Badges must appear in col-diagnostics as discrete <span class='badge'>...</span>
assert_true(
  grepl("class='col-diagnostics'", html_zr, fixed = TRUE) &&
    grepl("<span class='badge'>ZERO_REFERENCE</span>", html_zr, fixed = TRUE),
  "ZERO_REFERENCE badge rendered in col-diagnostics cell"
)
# Estimates column must NOT contain badge HTML
effect_cells <- regmatches(html_zr, gregexpr("<td class='col-effect'>.*?</td>", html_zr))[[1L]]
badge_in_effect <- any(grepl("class='badge'", effect_cells))
assert_true(!badge_in_effect, "col-effect cells do not contain badge spans")

cat("\n=== 4. Test 14.5: Conditional RR Instability Warning Callout ===\n")
# In zero reference case, relative risk expectation diverges -> instability warning must be present
assert_true(
  grepl("<div id=\"numerical-instability-warning\" class=\"callout warning\" role=\"alert\">", html_zr, fixed = TRUE),
  "Numerical instability warning callout is displayed when x_R = 0 (ZERO_REFERENCE)"
)

# In completely stable case (events > 15, N = 200), warning callout must NOT be present
df_stable <- data.frame(
  theme = c("T_Stable", "T_Stable"),
  arm = c("Active", "Control"),
  events = c(30L, 25L),
  total = c(200L, 200L),
  stringsAsFactors = FALSE
)
res_stable <- generate_comparative_report(df_stable, reference_arm = "Control", output_dir = tempfile("qa_stable_"))
html_stable <- paste(readLines(res_stable$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(
  !grepl("numerical-instability-warning", html_stable, fixed = TRUE),
  "Numerical instability warning callout is absent for stable evidence"
)
assert_true(
  all(c("excess_per_100", "reciprocal_absolute_rd", "reciprocal_status", "reciprocal_direction") %in%
    names(res_stable$summary_df)),
  "Dashboard summary carries natural-unit and reciprocal-RD fields"
)
assert_true(
  grepl("/ 100人", html_std, fixed = TRUE) &&
    grepl("NNH-like", html_std, fixed = TRUE),
  "Safety dashboard renders E100 and direction-aware NNH-like translation"
)

cat("\n=== 5. Test 14.6: Zero External Asset Scan ===\n")
# Strict Zero-External-Asset scanner: detect any active external resource loading
scan_active_external_assets <- function(html_str) {
  list(
    active_media_src = grepl("<(img|script|iframe|audio|video|source|embed)[^>]+src=[\"'](https?:|//)", html_str, ignore.case = TRUE),
    active_stylesheet = grepl("<link[^>]+href=[\"'](https?:|//)", html_str, ignore.case = TRUE),
    active_css_import = grepl("@import\\s+(url\\()?[\"']?(https?:|//)", html_str, ignore.case = TRUE),
    active_css_url = grepl("style=[\"'][^\"']*url\\((https?:|//)", html_str, ignore.case = TRUE)
  )
}

scan_std <- scan_active_external_assets(html_std)
assert_true(!scan_std$active_media_src, "HTML contains 0 active external media src attributes")
assert_true(!scan_std$active_stylesheet, "HTML contains 0 active external stylesheets")
assert_true(!scan_std$active_css_import, "HTML contains 0 active @import external rules")
assert_true(!scan_std$active_css_url, "HTML contains 0 active inline style url() links")

cat("\n=== 6. Test 14.7: Zero Local Absolute Path Scan ===\n")
# Scan for macOS (/Users/), Linux (/home/, /tmp/), Windows (C:\, D:\), UNC (\\server), file://
has_users <- grepl("/Users/", html_std, fixed = TRUE)
has_home <- grepl("/home/", html_std, fixed = TRUE)
has_tmp <- grepl("/tmp/", html_std, fixed = TRUE)
has_file_proto <- grepl("file://", html_std, fixed = TRUE)
has_windows_drive <- grepl("[A-Za-z]:\\\\", html_std)
has_unc <- grepl("\\\\\\[A-Za-z0-9]", html_std)

assert_true(!has_users, "HTML contains 0 /Users/ local paths")
assert_true(!has_home, "HTML contains 0 /home/ local paths")
assert_true(!has_tmp, "HTML contains 0 /tmp/ local paths")
assert_true(!has_file_proto, "HTML contains 0 file:// protocols")
assert_true(!has_windows_drive, "HTML contains 0 Windows drive paths")
assert_true(!has_unc, "HTML contains 0 UNC paths")

cat("\n=== 7. Test 14.8: DOM Structure, Accessibility & ID Uniqueness ===\n")
required_ids <- c("dashboard-title", "guidance-callout", "comparative-evidence-table")
for (id in required_ids) {
  matches <- gregexpr(sprintf("id=\"%s\"", id), html_std, fixed = TRUE)[[1L]]
  count <- if (matches[[1L]] == -1L) 0L else length(matches)
  assert_true(count == 1L, sprintf("DOM ID '#%s' appears exactly once (found %d)", id, count))
}

# Accessibility attributes
assert_true(
  grepl("aria-describedby=\"guidance-callout\"", html_std, fixed = TRUE),
  "Table includes aria-describedby referring to guidance callout"
)
assert_true(
  grepl("<caption>比較エビデンス解析サマリー</caption>", html_std, fixed = TRUE),
  "Table includes descriptive <caption> element"
)
assert_true(
  grepl("<th scope=\"col\"", html_std, fixed = TRUE),
  "Table headers include scope='col' accessibility attribute"
)
assert_true(
  grepl("class=\"table-container\"", html_std, fixed = TRUE),
  "Table is wrapped in responsive .table-container for overflow-x control"
)

cat("\n=== 8. Test 14.R1 & 14.R4: Suppressed RR Interval and Canonical Bootstrap Provenance ===\n")
# Fixture 1: IPTW with partial-undefined bootstrap replicates (relative_risk$interval is NULL)
iptw_override_partial <- list(
  theme = "IPTW_Partial",
  contrast_id = "IPTW_Partial_Active_vs_Control",
  inferential_semantics = "bootstrap",
  iptw = list(
    raw_patient_counts = list(target = 200L, target_events = 20L, reference = 200L, reference_events = 15L),
    effective_sample_size = list(target = 150.0, reference = 140.0),
    bootstrap_diagnostics = list(defined_rr_replicates = 950L, undefined_rr_replicates = 50L)
  ),
  risk_difference = list(
    estimate = list(value = 0.025, source = "iptw_weighted"),
    interval = list(lower = -0.010, upper = 0.060, method = "bootstrap_percentile")
  ),
  relative_risk = list(
    estimate = list(value = 1.33, source = "iptw_weighted"),
    interval = NULL, # GOVERNED SUPPRESSION
    mean_is_finite = FALSE,
    diagnostic = "PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"
  ),
  direction_support = list(support_value = 0.85),
  resolution_grade = list(grade = "U2", dominant_region = "target_excess"),
  precision_metrics = list(
    rd_interval_width = 0.070,
    log_rr_interval_width = NULL,
    rr_interval_fold_range = NULL
  ),
  diagnostics = list(badges = c("PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES"))
)

df_iptw <- data.frame(
  theme = c("IPTW_Partial", "IPTW_Partial"),
  arm = c("Active", "Control"),
  events = c(20L, 15L),
  total = c(200L, 200L),
  stringsAsFactors = FALSE
)

res_iptw_partial <- generate_comparative_report(
  df = df_iptw,
  reference_arm = "Control",
  evidence_overrides = list("IPTW_Partial__Active_vs_Control" = iptw_override_partial),
  output_dir = tempfile("qa_iptw_part_")
)

html_iptw_part <- paste(readLines(res_iptw_partial$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# H14-01 check: Report generation succeeded without error, RD is visible, RR interval is unavailable
assert_true(res_iptw_partial$summary_df$rd_estimate == 0.025, "RD estimate is preserved and visible")
assert_true(is.na(res_iptw_partial$summary_df$rr_interval_lower), "Suppressed RR lower interval is NA in summary")
assert_true(is.na(res_iptw_partial$summary_df$log_rr_interval_width), "Suppressed log_rr_interval_width is NA in summary (not invented)")
assert_true(!res_iptw_partial$summary_df$rr_interval_available, "rr_interval_available is FALSE")
assert_true(grepl("1.33 [N/A]", html_iptw_part, fixed = TRUE), "RR interval rendered as 1.33 [N/A] in HTML")
assert_true(
  grepl("id=\"numerical-instability-warning\"", html_iptw_part, fixed = TRUE),
  "Instability warning callout triggered by partial undefined replicates"
)

# 14.R5 check: Markdown report consistency
md_iptw_part <- paste(readLines(res_iptw_partial$md_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(grepl("1.33 [N/A]", md_iptw_part, fixed = TRUE), "14.R5: Markdown contains '1.33 [N/A]' for suppressed interval")
assert_true(!grepl("[NA, NA]", md_iptw_part, fixed = TRUE), "14.R5: Markdown does NOT contain '[NA, NA]'")

# M14-02 check: Canonical bootstrap replicates provenance matches actual numbers
assert_true(
  identical(res_iptw_partial$summary_df$rr_bootstrap_defined_replicates, 950L),
  "rr_bootstrap_defined_replicates correctly extracted from iptw$bootstrap_diagnostics (950L)"
)
assert_true(
  identical(res_iptw_partial$summary_df$rr_bootstrap_undefined_replicates, 50L),
  "rr_bootstrap_undefined_replicates correctly extracted from iptw$bootstrap_diagnostics (50L)"
)

# Fixture 2: IPTW with zero reference risk (relative_risk point estimate and interval are NULL)
iptw_override_zero <- list(
  theme = "IPTW_Zero",
  contrast_id = "IPTW_Zero_Active_vs_Control",
  inferential_semantics = "bootstrap",
  iptw = list(
    raw_patient_counts = list(target = 200L, target_events = 20L, reference = 200L, reference_events = 0L),
    effective_sample_size = list(target = 150.0, reference = 140.0),
    bootstrap_diagnostics = list(defined_rr_replicates = 0L, undefined_rr_replicates = 1000L)
  ),
  risk_difference = list(
    estimate = list(value = 0.100, source = "iptw_weighted"),
    interval = list(lower = 0.050, upper = 0.150, method = "bootstrap_percentile")
  ),
  relative_risk = list(
    estimate = NULL, # COMPLETELY NULL
    interval = NULL,
    mean_is_finite = FALSE,
    diagnostic = "ZERO_REFERENCE_RISK"
  ),
  direction_support = list(support_value = 0.999),
  resolution_grade = list(grade = "U1", dominant_region = "target_excess"),
  precision_metrics = list(
    rd_interval_width = 0.100,
    log_rr_interval_width = NULL,
    rr_interval_fold_range = NULL
  ),
  diagnostics = list(badges = c("ZERO_REFERENCE_RISK"))
)

df_iptw_zero <- data.frame(
  theme = c("IPTW_Zero", "IPTW_Zero"),
  arm = c("Active", "Control"),
  events = c(20L, 0L),
  total = c(200L, 200L),
  stringsAsFactors = FALSE
)

res_iptw_zero <- generate_comparative_report(
  df = df_iptw_zero,
  reference_arm = "Control",
  evidence_overrides = list("IPTW_Zero__Active_vs_Control" = iptw_override_zero),
  output_dir = tempfile("qa_iptw_zero_")
)

html_iptw_zero <- paste(readLines(res_iptw_zero$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
md_iptw_zero <- paste(readLines(res_iptw_zero$md_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(is.na(res_iptw_zero$summary_df$rr_estimate), "Completely suppressed RR estimate is NA in summary")
assert_true(!res_iptw_zero$summary_df$rr_estimate_available, "rr_estimate_available is FALSE")
assert_true(
  grepl("id=\"numerical-instability-warning\"", html_iptw_zero, fixed = TRUE),
  "Instability warning callout triggered by zero reference risk"
)
assert_true(!grepl("[NA, NA]", md_iptw_zero, fixed = TRUE), "14.R5: Zero reference Markdown does NOT contain '[NA, NA]'")

cat("\n=== 9. Test 14.R2: HTML Escaping of Hostile-but-Valid Labels & Active Asset Scan ===\n")
df_hostile <- data.frame(
  theme = c('<img src="https://evil.invalid/tracker.png" onerror="alert(1)">', '<img src="https://evil.invalid/tracker.png" onerror="alert(1)">'),
  arm = c('Active<script>fetch("https://evil.invalid/leak")</script>', 'Control & "Safe"'),
  events = c(20L, 10L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)

res_hostile <- generate_comparative_report(
  df = df_hostile,
  reference_arm = 'Control & "Safe"',
  primary_delta = 0.05,
  output_dir = tempfile("qa_hostile_")
)

html_hostile <- paste(readLines(res_hostile$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Assert that raw unescaped tags do NOT exist in table content
assert_true(!grepl("<img src=", html_hostile, fixed = TRUE), "Raw <img src= is not present in HTML")
assert_true(!grepl("<script>fetch", html_hostile, fixed = TRUE), "Hostile <script>fetch is not present unescaped in HTML")
tbody_hostile <- regmatches(html_hostile, regexec("<tbody>(.*?)</tbody>", html_hostile))[[1L]][2L]
assert_true(!grepl("<script", tbody_hostile, fixed = TRUE), "Raw <script> is not present in table body")

# Assert that properly entity-escaped strings DO exist
assert_true(
  grepl("&lt;img src=&quot;https://evil.invalid/tracker.png&quot;", html_hostile, fixed = TRUE),
  "Theme label is safely HTML-entity encoded"
)
assert_true(
  grepl("&lt;script&gt;", html_hostile, fixed = TRUE),
  "Script tag in arm label is safely HTML-entity encoded"
)
assert_true(
  grepl("Control &amp; &quot;Safe&quot;", html_hostile, fixed = TRUE),
  "Special characters (& and quotes) in reference arm are safely encoded"
)

# Verify that refined Zero-External-Asset scanner passes on hostile-label HTML
scan_hostile <- scan_active_external_assets(html_hostile)
assert_true(!scan_hostile$active_media_src, "Hostile-label HTML has 0 active media sources")
assert_true(!scan_hostile$active_stylesheet, "Hostile-label HTML has 0 active stylesheets")
assert_true(!scan_hostile$active_css_import, "Hostile-label HTML has 0 active CSS imports")
assert_true(!scan_hostile$active_css_url, "Hostile-label HTML has 0 active CSS urls")

cat("\n=== 10. Test 14.10: Sortable Comparative Evidence Summary Contract & Accessibility ===\n")
# 1. Verify sortable headers and accessibility attributes
assert_true(
  grepl("th scope=\"col\" class=\"col-id sortable\" aria-sort=\"none\" tabindex=\"0\" role=\"columnheader\"", html_std, fixed = TRUE),
  "14.10: Theme header has sortable class, aria-sort='none', tabindex='0', role='columnheader'"
)
assert_true(
  grepl("th scope=\"col\" class=\"col-effect sortable\" aria-sort=\"none\" tabindex=\"0\" role=\"columnheader\"", html_std, fixed = TRUE),
  "14.10: RD header has sortable class and aria-sort='none'"
)
assert_true(
  grepl("th scope=\"col\" class=\"col-practical sortable\" aria-sort=\"none\" tabindex=\"0\" role=\"columnheader\"", html_std, fixed = TRUE),
  "14.10: Practical/U-Grade header has sortable class and aria-sort='none'"
)

# 2. Verify sort indicators inside headers
assert_true(
  grepl("<span class=\"sort-indicator\" aria-hidden=\"true\">↕</span>", html_std, fixed = TRUE),
  "14.10: Headers contain visual sort indicators with aria-hidden='true'"
)

# 3. Verify data-sort-value attributes on cells
assert_true(
  grepl("data-sort-value=\"0.397", html_std, fixed = TRUE) || grepl("data-sort-value=\"0.", html_std, fixed = TRUE),
  "14.10: RD cells contain explicit machine-readable data-sort-value"
)
assert_true(
  grepl("data-sort-value=\"0_target_excess\"", html_std, fixed = TRUE),
  "14.10: U0 practical cell contains ordinal prefix '0_' in data-sort-value"
)
assert_true(
  grepl("data-sort-value=\"3_", html_u3, fixed = TRUE),
  "14.10: U3 practical cell contains ordinal prefix '3_' in data-sort-value"
)
assert_true(
  grepl("td class='col-diagnostics' data-sort-value=", html_std, fixed = TRUE),
  "14.10: Diagnostics cell contains explicit data-sort-value attribute (14.10.R2)"
)

# Verify exactly 12 data-sort-value attributes per data row in standard output
std_data_rows <- length(gregexpr("<tr data-row-key=", html_std, fixed = TRUE)[[1L]])
std_dsv <- length(gregexpr("data-sort-value=", html_std, fixed = TRUE)[[1L]])
# subtract header sort keys (12 sortable th) if present in count — data-sort-value is td-only
assert_true(
  std_dsv == std_data_rows * 12L,
  sprintf("14.10: Exactly 12 sort keys per row across all columns (%d / %d)", std_dsv, std_data_rows * 12L)
)

# 4. Verify inline sort script presence and contract
assert_true(
  grepl("document.addEventListener(\"DOMContentLoaded\", function()", html_std, fixed = TRUE),
  "14.10: Self-contained inline sorting script is present"
)
assert_true(
  grepl("header.setAttribute(\"aria-sort\", newSort);", html_std, fixed = TRUE),
  "14.10: Script manages aria-sort attribute dynamically"
)
assert_true(
  grepl("return a.index - b.index;", html_std, fixed = TRUE),
  "14.10: Script implements stable sort tie-breaking"
)
assert_true(
  grepl("aEmpty", html_std, fixed = TRUE) && grepl("bEmpty", html_std, fixed = TRUE),
  "14.10: Script places empty/NA values after finite values"
)

cat("\n=== 11. Test 14.11: Embedded Canonical Data & Excel-Compatible CSV Export ===\n")
# 1. Embedded JSON data script presence and integrity
assert_true(
  grepl("<script id=\"comparative-summary-data\" type=\"application/json\">", html_std, fixed = TRUE),
  "14.11: Embedded canonical summary data script is present"
)

# Extract and validate embedded JSON
json_match <- regmatches(html_std, regexec("<script id=\"comparative-summary-data\" type=\"application/json\">(.*?)</script>", html_std))[[1L]]
assert_true(length(json_match) >= 2L, "14.11: Successfully matched embedded summary JSON content")
embedded_json_str <- json_match[[2L]]
embedded_data <- jsonlite::fromJSON(embedded_json_str)
assert_true(is.data.frame(embedded_data), "14.11: Embedded data parses as data.frame")
assert_true(
  nrow(embedded_data) == nrow(res_std$summary_df),
  sprintf("14.11: Embedded JSON row count (%d) matches canonical summary_df (%d)", nrow(embedded_data), nrow(res_std$summary_df))
)
assert_true(
  all(names(res_std$summary_df) %in% names(embedded_data)),
  "14.11: Embedded JSON contains all canonical columns from summary_df"
)
assert_true("row_key" %in% names(embedded_data), "14.11: Embedded JSON includes stable row_key")

# 2. Export button presence
assert_true(grepl("id=\"btn-export-all\"", html_std, fixed = TRUE), "14.11: Full export button (btn-export-all) is present")
assert_true(grepl("id=\"btn-export-filtered\"", html_std, fixed = TRUE), "14.11: Filtered export button (btn-export-filtered) is present")

# 3. CSV formatting and RFC 4180 / BOM script presence
assert_true(grepl("\\uFEFF", html_std, fixed = TRUE), "14.11: Script specifies UTF-8 BOM for Excel compatibility")
assert_true(grepl("escapeCsvCell", html_std, fixed = TRUE), "14.11: Script implements RFC 4180 CSV cell escaping")
assert_true(grepl("\\r\\n", html_std, fixed = TRUE), "14.11: Script uses standard CRLF newlines for CSV lines")
assert_true(
  grepl("h !== \"row_key\"", html_std, fixed = TRUE),
  "14.11.R1: Script explicitly filters out internal row_key from CSV export headers"
)
export_headers <- names(embedded_data)[names(embedded_data) != "row_key"]
assert_true(
  identical(export_headers, names(res_std$summary_df)),
  "14.11.R1: Exported CSV headers identically match canonical summary_df columns"
)

cat("\n=== 12. Test 14.12: Accessible Multi-Select Filters & Toolbar Contract ===\n")
# 1. Toolbar and filter container
assert_true(grepl("id=\"dashboard-toolbar\"", html_std, fixed = TRUE), "14.12: Toolbar container is present")
assert_true(
  grepl("role=\"region\" aria-label=\"ダッシュボード操作パネル\"", html_std, fixed = TRUE),
  "14.12: Toolbar has accessible region role and label"
)

# 2. Filter dropdowns and controls
assert_true(grepl("id=\"filter-group-theme\"", html_std, fixed = TRUE), "14.12: Theme filter dropdown is present")
assert_true(grepl("id=\"theme-search-input\"", html_std, fixed = TRUE), "14.12: Theme search input is present")
assert_true(grepl("id=\"filter-group-practical\"", html_std, fixed = TRUE), "14.12: Practical/U-Grade filter dropdown is present")
assert_true(grepl("class=\"filter-region\"", html_std, fixed = TRUE), "14.12: Region filter checkboxes are present")
assert_true(grepl("class=\"filter-ugrade\"", html_std, fixed = TRUE), "14.12: U-Grade filter checkboxes are present")
assert_true(grepl("id=\"filter-group-diagnostics\"", html_std, fixed = TRUE), "14.12: Diagnostics filter dropdown is present")
assert_true(grepl("class=\"filter-badge-opt\"", html_std, fixed = TRUE), "14.12: Diagnostic badge filter checkboxes are present")

# 3. Row status indicator and reset control
assert_true(
  grepl("id=\"visible-row-count\" aria-live=\"polite\"", html_std, fixed = TRUE),
  "14.12: Visible row count indicator with aria-live='polite' is present"
)
assert_true(grepl("id=\"btn-reset-filters\"", html_std, fixed = TRUE), "14.12: Filter reset button is present")

# 4. Table row filter metadata attributes
assert_true(grepl("data-row-key=\"row_000001\"", html_std, fixed = TRUE), "14.12: Rows contain data-row-key attribute")
assert_true(grepl("data-theme=\"Cardio\"", html_std, fixed = TRUE), "14.12: Rows contain data-theme attribute")
assert_true(grepl("data-region=", html_std, fixed = TRUE), "14.12: Rows contain data-region attribute")
assert_true(grepl("data-ugrade=", html_std, fixed = TRUE), "14.12: Rows contain data-ugrade attribute")
assert_true(grepl("data-badges=", html_std, fixed = TRUE), "14.12: Rows contain data-badges attribute")

# 5. Hostile label safety in filter controls and row attributes
assert_true(
  !grepl("<img src=https://evil.invalid", html_hostile, fixed = TRUE),
  "14.12: Hostile img tag not unescaped in toolbar or row attributes"
)
assert_true(
  !grepl("<script>fetch", html_hostile, fixed = TRUE),
  "14.12: Hostile script tag not unescaped in toolbar or row attributes"
)

cat("\n=== 13. Test 14.13: Mathematical & Usage Guide Accordions (Native MathML) ===\n")
# 1. Guide section presence and heading
assert_true(
  grepl("<section id=\"metric-guide\" aria-label=\"統計指標の数学的解説と利用ガイド\">", html_std, fixed = TRUE),
  "14.13: Guide section is present with accessible label"
)

# 2. Exactly 10 default-collapsed accordion items
guide_accordions <- c(
  "guide-item-risk", "guide-item-rd", "guide-item-rr", "guide-item-intervals",
  "guide-item-direction", "guide-item-practical", "guide-item-ugrade",
  "guide-item-precision", "guide-item-diagnostics", "guide-item-multiplicity"
)
for (gid in guide_accordions) {
  assert_true(
    grepl(sprintf("<details id=\"%s\" class=\"guide-accordion\">", gid), html_std, fixed = TRUE),
    sprintf("14.13: Accordion item '%s' is present and default-collapsed (no open attribute)", gid)
  )
}

# 3. 4-block structure inside accordions
assert_true(grepl("<h4>定義 (Definition)</h4>", html_std, fixed = TRUE), "14.13: Guide contains '定義 (Definition)' headings")
assert_true(grepl("<h4>どう読むか (Interpretation)</h4>", html_std, fixed = TRUE), "14.13: Guide contains 'どう読むか' headings")
assert_true(grepl("<h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>", html_std, fixed = TRUE), "14.13: Guide contains '注意点・禁止解釈' headings")
assert_true(grepl("<h4>いつ使うか (When to Use)</h4>", html_std, fixed = TRUE), "14.13: Guide contains 'いつ使うか' headings")

# 4. Native MathML tags without external dependencies
assert_true(grepl("<math display=\"block\">", html_std, fixed = TRUE), "14.13: Native MathML tags are present")
assert_true(!grepl("mathjax", tolower(html_std), fixed = TRUE), "14.13: Zero external MathJax references")
assert_true(!grepl("katex", tolower(html_std), fixed = TRUE), "14.13: Zero external KaTeX references")

# 5. Guard phrases in guide content
assert_true(
  grepl("同等性", html_std, fixed = TRUE) && grepl("証明しません", html_std, fixed = TRUE),
  "14.13: Guide includes caution that crossing zero does not prove equivalence"
)
assert_true(
  grepl("因果的優越性を単独で証明するものではありません", html_std, fixed = TRUE),
  "14.13: Guide includes caution on direction support vs causal superiority"
)
assert_true(
  grepl("サンプルの大きさ（精度）や有害事象の臨床的重症度を意味するものではありません", html_std, fixed = TRUE),
  "14.13: Guide includes caution that U-Grade is not sample size or clinical severity"
)
assert_true(
  grepl("薬事承認や規制判断の決定的根拠としてはなりません", html_std, fixed = TRUE),
  "14.13: Guide includes caution against automated regulatory decisions"
)

# 6. Canonical mathematical terminology & inferential-semantics adaptation (Task 14.13.R2 / H14.13-02)
# 6.1 Bayesian-only HTML contract (html_std)
assert_true(
  grepl("推論上の点推定値（inferential point estimate）には事後中央値（posterior median", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide uses posterior median for inferential point estimate"
)
assert_true(
  grepl("生の記述発症割合（raw descriptive proportion）", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide separates raw descriptive proportion from posterior median"
)
assert_true(
  grepl("Beta(0.5, 0.5)", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide describes Jeffreys Beta(0.5, 0.5) prior"
)
assert_true(
  grepl("Bayesian 95% ETI (事後等裾信用区間)", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide defines Bayesian 95% ETI explicitly"
)
assert_true(
  !grepl("Bootstrap 95% percentile interval", html_std, fixed = TRUE),
  "14.13.R2: Bayesian-only HTML does not include Bootstrap percentile interval"
)
assert_true(
  grepl("相対的な発生リスクの対比", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide frames RR as relative risk comparison"
)
assert_true(
  grepl("理論的期待値 E(RR) は無限大に発散", html_std, fixed = TRUE),
  "14.13.R2: Bayesian HTML guide explains theoretical RR mean divergence at zero reference"
)

# 6.2 Bootstrap-only HTML contract (html_iptw_part)
assert_true(
  !grepl("posterior median", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap-only HTML does not claim posterior median as active point estimate"
)
assert_true(
  !grepl("Jeffreys", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap-only HTML does not claim Jeffreys prior as active model"
)
assert_true(
  grepl("observed_sample_estimate", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap HTML labels observed_sample_estimate semantics"
)
assert_true(
  grepl("Bootstrap 95% percentile interval", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap HTML guide defines Bootstrap percentile interval"
)
assert_true(
  grepl("パラメータが 95% の確率で区間内にある」とは解釈しません", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap HTML guards against Bayesian probability interpretation"
)
assert_true(
  grepl("rr_bootstrap_undefined_replicates", html_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap HTML explains RR suppression governed by bootstrap diagnostics"
)

# 6.3 Mixed semantics HTML contract
df_mixed <- data.frame(
  theme = c("Cardio", "Cardio", "IPTW_Theme", "IPTW_Theme"),
  arm = c("Active", "Control", "Active", "Control"),
  events = c(20L, 10L, 25L, 15L),
  total = c(200L, 200L, 200L, 200L),
  stringsAsFactors = FALSE
)
iptw_override_mixed <- list(
  theme = "IPTW_Theme",
  contrast_id = "IPTW_Theme_Active_vs_Control",
  inferential_semantics = "bootstrap",
  iptw = list(
    raw_patient_counts = list(target = 200L, target_events = 25L, reference = 200L, reference_events = 15L),
    effective_sample_size = list(target = 180.0, reference = 170.0),
    bootstrap_diagnostics = list(defined_rr_replicates = 1000L, undefined_rr_replicates = 0L)
  ),
  risk_difference = list(
    estimate = list(value = 0.05, source = "observed_sample_estimate"),
    interval = list(lower = 0.01, upper = 0.09, method = "bootstrap_percentile")
  ),
  relative_risk = list(
    estimate = list(value = 1.67, source = "observed_sample_estimate"),
    interval = list(lower = 1.05, upper = 2.65, method = "bootstrap_percentile"),
    mean_is_finite = TRUE,
    diagnostic = "WELL_BEHAVED"
  ),
  direction_support = list(support_value = 0.98),
  resolution_grade = list(grade = "U1", dominant_region = "target_excess"),
  precision_metrics = list(
    rd_interval_width = 0.08,
    log_rr_interval_width = 0.92,
    rr_interval_fold_range = 2.52
  ),
  diagnostics = list(badges = character(0))
)
res_mixed <- generate_comparative_report(
  df = df_mixed,
  reference_arm = "Control",
  evidence_overrides = list("IPTW_Theme__Active_vs_Control" = iptw_override_mixed),
  output_dir = tempfile("qa_mixed_")
)
html_mixed <- paste(readLines(res_mixed$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

assert_true(
  grepl("本レポートには複数の推論セマンティクス", html_mixed, fixed = TRUE),
  "14.13.R2: Mixed semantics HTML explicitly notes multiple inferential semantics"
)
assert_true(
  grepl("ベイズ推論行 (bayesian)", html_mixed, fixed = TRUE),
  "14.13.R2: Mixed HTML distinguishes bayesian rows"
)
assert_true(
  grepl("ブートストラップ推論行 (bootstrap)", html_mixed, fixed = TRUE),
  "14.13.R2: Mixed HTML distinguishes bootstrap rows"
)
assert_true(
  grepl("Bayesian 95% ETI", html_mixed, fixed = TRUE) && grepl("Bootstrap 95% percentile interval", html_mixed, fixed = TRUE),
  "14.13.R2: Mixed HTML describes both Bayesian ETI and Bootstrap percentile intervals"
)

# 7. Markdown report synchronization (Task 14.13.R2)
md_std <- readLines(file.path(res_std$run_output_dir, "comparative_report.md"), encoding = "UTF-8")
md_std_text <- paste(md_std, collapse = "\n")
assert_true(
  grepl("## 3. 統計指標の解説と利用ガイド (Statistical Metric Guide)", md_std_text, fixed = TRUE),
  "14.13.R2: Markdown report contains synchronized Statistical Metric Guide section"
)
assert_true(
  grepl("Bayesian 95% ETI", md_std_text, fixed = TRUE),
  "14.13.R2: Bayesian Markdown report defines Bayesian 95% ETI"
)
assert_true(
  grepl("posterior median", md_std_text, fixed = TRUE),
  "14.13.R2: Bayesian Markdown report specifies posterior median"
)
assert_true(
  grepl("相対的な発生リスクの対比", md_std_text, fixed = TRUE),
  "14.13.R2: Markdown report uses relative risk comparison wording"
)
assert_true(
  grepl("Bootstrap 95% percentile interval", md_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap Markdown report defines Bootstrap percentile interval"
)
assert_true(
  grepl("observed_sample_estimate", md_iptw_part, fixed = TRUE),
  "14.13.R2: Bootstrap Markdown report specifies observed_sample_estimate"
)

cat("\n=== Plan 024 Metric Hierarchy QA (Q1–Q24) ===\n")

canonical_headers <- c(
  "テーマ",
  "比較",
  "記述N (T / R)",
  "記述イベント数 (T / R)",
  "RD 推定値 [区間]",
  "100人あたり差 (E100)",
  "NNT・NNH-like",
  "RR 推定値 [区間]",
  "方向支持指標",
  "実務領域・U-Grade",
  "精度指標 (ESS / 区間幅)",
  "診断バッジ"
)

# Q1 / Q2: twelve-column HTML order and cell count
header_block <- regmatches(html_std, regexpr("<thead>.*?</thead>", html_std))
assert_true(nzchar(header_block), "Q1: thead block exists")
header_positions <- vapply(canonical_headers, function(h) {
  regexpr(h, header_block, fixed = TRUE)[1L]
}, integer(1L))
assert_true(
  all(header_positions > 0L) && identical(order(header_positions), seq_along(canonical_headers)),
  "Q1: HTML headers match canonical 12-column order"
)
row_matches <- gregexpr("<tr data-row-key=\"[^\"]+\"[^>]*>.*?</tr>", html_std, perl = TRUE)[[1L]]
assert_true(row_matches[1L] > 0L, "Q2: data rows exist")
# Multi-row fixture to assert every generated row has 12 cells
df_q2 <- data.frame(
  theme = c("Q2a", "Q2a", "Q2b", "Q2b"),
  arm = c("Active", "Control", "Active", "Control"),
  events = c(25L, 10L, 5L, 20L),
  total = c(100L, 100L, 100L, 100L),
  stringsAsFactors = FALSE
)
res_q2 <- generate_comparative_report(df_q2, reference_arm = "Control", primary_delta = 0.05, output_dir = tempfile("qa_q2_"))
html_q2 <- paste(readLines(res_q2$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
row_matches_q2 <- gregexpr("<tr data-row-key=\"[^\"]+\"[^>]*>.*?</tr>", html_q2, perl = TRUE)[[1L]]
assert_true(length(row_matches_q2) >= 2L && row_matches_q2[1L] > 0L, "Q2: multi-row fixture produced >=2 data rows")
row_td_counts <- vapply(seq_along(row_matches_q2), function(i) {
  row_html <- substr(html_q2, row_matches_q2[i], row_matches_q2[i] + attr(row_matches_q2, "match.length")[i] - 1L)
  length(gregexpr("<td ", row_html, fixed = TRUE)[[1L]])
}, integer(1L))
assert_true(
  all(row_td_counts == 12L),
  sprintf(
    "Q2: every data row has 12 cells (min=%d max=%d n=%d)",
    min(row_td_counts), max(row_td_counts), length(row_td_counts)
  )
)

# Q3: Markdown header parity
md_header_line <- md_std[grepl("^\\| テーマ \\|", md_std)][1L]
assert_true(!is.na(md_header_line) && nzchar(md_header_line), "Q3: Markdown summary header exists")
md_header_ok <- all(vapply(canonical_headers, function(h) grepl(h, md_header_line, fixed = TRUE), logical(1L)))
assert_true(
  md_header_ok && grepl("100人あたり差 \\(E100\\)", md_header_line) &&
    grepl("NNT・NNH-like", md_header_line, fixed = TRUE) &&
    !grepl("100人あたり差 / NNT・NNH-like", md_header_line, fixed = TRUE),
  "Q3: Markdown headers follow same semantic split/order as HTML"
)

# Q4: Safety + target_excess → NNH-like
assert_true(
  identical(res_std$summary_df$reciprocal_direction[[1L]], "target_excess") ||
    any(res_std$summary_df$reciprocal_direction == "target_excess"),
  "Q4 setup: standard Safety fixture includes target_excess direction"
)
assert_true(
  grepl("NNH-like ≈", html_std, fixed = TRUE) && !grepl("NNT-like ≈", html_std, fixed = TRUE),
  "Q4: Safety target_excess renders NNH-like and not NNT-like"
)

# Q5: Safety + reference_excess → NNT-like
assert_true(
  grepl("NNT-like ≈", html_re, fixed = TRUE) && !grepl("NNH-like ≈", html_re, fixed = TRUE),
  "Q5: Safety reference_excess renders NNT-like and not NNH-like"
)

# Q6: SIGN_AMBIGUOUS suppression (near-equal arms with non-null interval likely crossing 0)
df_amb <- data.frame(
  theme = c("Amb", "Amb"),
  arm = c("Active", "Control"),
  events = c(20L, 19L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_amb <- generate_comparative_report(df_amb, reference_arm = "Control", primary_delta = 0.05, output_dir = tempfile("qa_amb_"))
html_amb <- paste(readLines(res_amb$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(
  any(res_amb$summary_df$reciprocal_status == "SIGN_AMBIGUOUS"),
  "Q6 setup: ambiguous fixture yields SIGN_AMBIGUOUS"
)
assert_true(
  grepl("— (SIGN_AMBIGUOUS)", html_amb, fixed = TRUE) &&
    !grepl("NNH-like ≈", html_amb, fixed = TRUE) &&
    !grepl("NNT-like ≈", html_amb, fixed = TRUE),
  "Q6: SIGN_AMBIGUOUS suppresses directional NNT/NNH-like labels"
)

# Q7: RD near zero → RD_NEAR_ZERO / reciprocal null (presentation override fixture)
near0_override <- list(
  theme = "Near0",
  contrast_id = "Near0_Active_vs_Control",
  inferential_semantics = "bootstrap",
  iptw = list(
    raw_patient_counts = list(target = 100L, target_events = 10L, reference = 100L, reference_events = 10L),
    effective_sample_size = list(target = 100.0, reference = 100.0),
    bootstrap_diagnostics = list(defined_rr_replicates = 1000L, undefined_rr_replicates = 0L)
  ),
  risk_difference = list(
    estimate = list(value = 0, source = "observed_sample_estimate"),
    interval = list(lower = -0.02, upper = 0.02, method = "bootstrap_percentile"),
    excess_per_100 = 0,
    reciprocal_absolute_rd = NULL,
    reciprocal_status = "RD_NEAR_ZERO",
    reciprocal_direction = "none"
  ),
  relative_risk = list(
    estimate = list(value = 1.0, source = "observed_sample_estimate"),
    interval = list(lower = 0.8, upper = 1.2, method = "bootstrap_percentile"),
    mean_is_finite = TRUE,
    diagnostic = "WELL_BEHAVED"
  ),
  direction_support = list(support_value = 0.5),
  resolution_grade = list(grade = "NONE", dominant_region = "none"),
  precision_metrics = list(rd_interval_width = 0.04, log_rr_interval_width = 0.4, rr_interval_fold_range = 1.5),
  diagnostics = list(badges = character(0))
)
df_near0 <- data.frame(
  theme = c("Near0", "Near0"),
  arm = c("Active", "Control"),
  events = c(10L, 10L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_near0 <- generate_comparative_report(
  df_near0,
  reference_arm = "Control",
  evidence_overrides = list("Near0__Active_vs_Control" = near0_override),
  output_dir = tempfile("qa_near0_")
)
html_near0 <- paste(readLines(res_near0$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(
  any(res_near0$summary_df$reciprocal_status == "RD_NEAR_ZERO") &&
    any(is.na(res_near0$summary_df$reciprocal_absolute_rd)),
  "Q7: RD near zero yields RD_NEAR_ZERO with null reciprocal"
)
assert_true(
  grepl("— (RD_NEAR_ZERO)", html_near0, fixed = TRUE),
  "Q7: RD_NEAR_ZERO suppression status is displayed"
)

# Q7b: NOT_INTERPRETABLE suppression (presentation override fixture)
ni_override <- list(
  theme = "NotInterp",
  contrast_id = "NotInterp_Active_vs_Control",
  inferential_semantics = "bootstrap",
  iptw = list(
    raw_patient_counts = list(target = 100L, target_events = 20L, reference = 100L, reference_events = 10L),
    effective_sample_size = list(target = 100.0, reference = 100.0),
    bootstrap_diagnostics = list(defined_rr_replicates = 1000L, undefined_rr_replicates = 0L)
  ),
  risk_difference = list(
    estimate = list(value = 0.10, source = "observed_sample_estimate"),
    interval = list(lower = -0.05, upper = 0.20, method = "bootstrap_percentile"),
    excess_per_100 = 10,
    reciprocal_absolute_rd = NULL,
    reciprocal_status = "NOT_INTERPRETABLE",
    reciprocal_direction = "none"
  ),
  relative_risk = list(
    estimate = list(value = 2.0, source = "observed_sample_estimate"),
    interval = list(lower = 1.1, upper = 3.5, method = "bootstrap_percentile"),
    mean_is_finite = TRUE,
    diagnostic = "WELL_BEHAVED"
  ),
  direction_support = list(support_value = 0.9),
  resolution_grade = list(grade = "U2", dominant_region = "target_excess"),
  precision_metrics = list(rd_interval_width = 0.25, log_rr_interval_width = 1.1, rr_interval_fold_range = 3.2),
  diagnostics = list(badges = character(0))
)
df_ni <- data.frame(
  theme = c("NotInterp", "NotInterp"),
  arm = c("Active", "Control"),
  events = c(20L, 10L),
  total = c(100L, 100L),
  stringsAsFactors = FALSE
)
res_ni <- generate_comparative_report(
  df_ni,
  reference_arm = "Control",
  primary_delta = 0.05,
  evidence_overrides = list("NotInterp__Active_vs_Control" = ni_override),
  output_dir = tempfile("qa_ni_")
)
html_ni <- paste(readLines(res_ni$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_true(
  identical(res_ni$summary_df$reciprocal_status[[1L]], "NOT_INTERPRETABLE") &&
    identical(res_ni$summary_df$reciprocal_direction[[1L]], "none"),
  "Q7b setup: NOT_INTERPRETABLE override applied"
)
assert_true(
  grepl("— (NOT_INTERPRETABLE)", html_ni, fixed = TRUE) &&
    !grepl("NNH-like ≈", html_ni, fixed = TRUE) &&
    !grepl("NNT-like ≈", html_ni, fixed = TRUE),
  "Q7b: NOT_INTERPRETABLE suppresses directional NNT/NNH-like labels"
)
ni_row_matches <- gregexpr("<tr data-row-key=\"[^\"]+\"[^>]*>.*?</tr>", html_ni, perl = TRUE)[[1L]]
ni_row_html <- substr(html_ni, ni_row_matches[1L], ni_row_matches[1L] + attr(ni_row_matches, "match.length")[1L] - 1L)
ni_reciprocal_td <- regmatches(ni_row_html, regexpr("<td class='col-effect col-reciprocal' data-sort-value=\"[^\"]*\">", ni_row_html))
assert_true(
  length(ni_reciprocal_td) == 1L && grepl('data-sort-value=\"\"', ni_reciprocal_td, fixed = TRUE),
  "Q7b: NOT_INTERPRETABLE reciprocal sort key is empty/missing"
)

# Q8: non-Safety domain → 1/|RD| only (HTML unescaped; Markdown pipe-escaped)
res_rwd <- generate_comparative_report(
  df_standard,
  reference_arm = "Control",
  primary_delta = 0.05,
  domain = "rwd",
  output_dir = tempfile("qa_rwd_")
)
html_rwd <- paste(readLines(res_rwd$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
md_rwd_lines <- readLines(res_rwd$md_path, warn = FALSE, encoding = "UTF-8")
md_rwd <- paste(md_rwd_lines, collapse = "\n")
assert_true(
  grepl("1/|RD| ≈", html_rwd, fixed = TRUE) &&
    !grepl("NNH-like ≈", html_rwd, fixed = TRUE) &&
    !grepl("NNT-like ≈", html_rwd, fixed = TRUE),
  "Q8: non-Safety HTML stable reciprocal uses 1/|RD| only"
)
assert_true(
  grepl("1/\\|RD\\| ≈", md_rwd, fixed = TRUE) &&
    !grepl("NNH-like ≈", md_rwd, fixed = TRUE) &&
    !grepl("NNT-like ≈", md_rwd, fixed = TRUE),
  "Q8: non-Safety Markdown reciprocal uses escaped 1/\\|RD\\| only"
)
count_md_table_cells <- function(line) {
  neutralized <- gsub("\\|", "\uFFF0", line, fixed = TRUE)
  parts <- strsplit(neutralized, "|", fixed = TRUE)[[1L]]
  if (length(parts) && identical(parts[[1L]], "")) {
    parts <- parts[-1L]
  }
  if (length(parts) && identical(parts[[length(parts)]], "")) {
    parts <- parts[-length(parts)]
  }
  length(parts)
}
md_data_rows <- md_rwd_lines[
  grepl("^\\| ", md_rwd_lines) &
    !grepl("^\\|[-:| ]+$", md_rwd_lines) &
    !grepl("^\\| テーマ \\|", md_rwd_lines)
]
md_cell_counts <- vapply(md_data_rows, count_md_table_cells, integer(1L))
assert_true(
  length(md_data_rows) >= 1L && all(md_cell_counts == 12L),
  sprintf(
    "Q8: non-Safety Markdown data rows retain exactly 12 cells (counts=%s)",
    paste(md_cell_counts, collapse = ",")
  )
)

# Q9 / Q10: provenance — displayed E100 / reciprocal match summary_df
std_row <- res_std$summary_df[1L, ]
e100_disp <- sprintf("%+.2f / 100人", std_row$excess_per_100)
assert_true(
  grepl(e100_disp, html_std, fixed = TRUE),
  "Q9: E100 display matches summary_df$excess_per_100"
)
if (identical(std_row$reciprocal_status, "STABLE_DIRECTION") && !is.na(std_row$reciprocal_absolute_rd)) {
  recip_disp <- sprintf("NNH-like ≈ %.1f人", std_row$reciprocal_absolute_rd)
  assert_true(
    grepl(recip_disp, html_std, fixed = TRUE),
    "Q10: reciprocal display matches summary_df$reciprocal_absolute_rd"
  )
} else {
  assert_true(FALSE, "Q10 setup: expected STABLE_DIRECTION reciprocal on standard fixture")
}

# Q11–Q13: U-Grade retention / muted U3 / null delta
assert_true(
  grepl("実務領域・U-Grade", html_std, fixed = TRUE),
  "Q11: Practical Region / U-Grade column retained"
)
assert_true(
  any(res_u3$summary_df$u_grade == "U3") &&
    grepl("rgba(148, 163, 184, 0.12)", html_u3, fixed = TRUE),
  "Q12: U3 muted/achromatic contract retained"
)
assert_true(
  all(res_null_delta$summary_df$u_grade == "NONE") &&
    all(res_null_delta$summary_df$dominant_region == "none") &&
    !grepl("background-color: rgba(", html_nd, fixed = TRUE),
  "Q13: primary_delta=null → NONE / none / no practical-region hue"
)

# Q14 / Q15: dedicated sort keys
assert_true(
  grepl("col-e100", html_std, fixed = TRUE) &&
    grepl(sprintf('data-sort-value=\"%.8f\"', std_row$excess_per_100), html_std, fixed = TRUE),
  "Q14: E100 uses machine-readable excess_per_100 sort key"
)
assert_true(
  grepl("col-reciprocal", html_std, fixed = TRUE) &&
    grepl(sprintf('data-sort-value=\"%.8f\"', std_row$reciprocal_absolute_rd), html_std, fixed = TRUE),
  "Q15: stable reciprocal uses numeric reciprocal_absolute_rd sort key"
)
amb_row_matches <- gregexpr("<tr data-row-key=\"[^\"]+\"[^>]*>.*?</tr>", html_amb, perl = TRUE)[[1L]]
assert_true(amb_row_matches[1L] > 0L, "Q15 setup: ambiguous data row exists")
amb_row_html <- substr(html_amb, amb_row_matches[1L], amb_row_matches[1L] + attr(amb_row_matches, "match.length")[1L] - 1L)
reciprocal_td <- regmatches(amb_row_html, regexpr("<td class='col-effect col-reciprocal' data-sort-value=\"[^\"]*\">", amb_row_html))
assert_true(
  length(reciprocal_td) == 1L && grepl('data-sort-value=\"\"', reciprocal_td, fixed = TRUE),
  "Q15: suppressed reciprocal uses empty (missing) sort key"
)

# Q16–Q19: keyboard/aria-sort, CSV 40 fields, filtered export, Zero-External-Asset
assert_true(
  grepl("keydown", html_std, fixed = TRUE) && grepl("aria-sort", html_std, fixed = TRUE),
  "Q16: keyboard sorting and aria-sort remain present"
)
assert_true(
  ncol(res_std$summary_df) == 40L,
  sprintf("Q17: summary_df remains exactly 40 canonical fields (got %d)", ncol(res_std$summary_df))
)
assert_true(
  grepl("btn-export-filtered", html_std, fixed = TRUE) &&
    grepl("style.display !== \"none\"", html_std, fixed = TRUE) &&
    grepl("data-row-key", html_std, fixed = TRUE),
  "Q18: filtered export walks currently visible DOM row order"
)
scan_q19 <- scan_active_external_assets(html_std)
assert_true(
  !any(unlist(scan_q19)),
  "Q19: Zero-External-Asset scan remains clean"
)

# Q20: RR instability warning with RD/E100 still usable
assert_true(
  grepl("numerical-instability-warning", html_zr, fixed = TRUE) &&
    grepl("/ 100人", html_zr, fixed = TRUE) &&
    !is.na(res_zr$summary_df$rd_estimate[[1L]]) &&
    !is.na(res_zr$summary_df$excess_per_100[[1L]]),
  "Q20: RR instability warning coexists with usable RD/E100"
)

# Q21–Q23: guide semantics retained (reusing existing fixtures)
assert_true(
  grepl("posterior median", html_std, fixed = TRUE) || grepl("posterior_median", html_std, fixed = TRUE),
  "Q21: Bayesian guide semantics retained"
)
assert_true(
  grepl("observed_sample_estimate", html_iptw_part, fixed = TRUE) &&
    grepl("Bootstrap 95% percentile interval", html_iptw_part, fixed = TRUE),
  "Q22: Bootstrap guide semantics retained"
)
assert_true(
  grepl("本レポートには複数の推論セマンティクス", html_mixed, fixed = TRUE),
  "Q23: mixed guide semantics retained"
)

# Q24: Gower feature keys exclude E100/reciprocal fields
source(".agents/shared/evidence_feature_extract.R")
forbidden_geom <- c("excess_per_100", "reciprocal_absolute_rd", "reciprocal_status", "reciprocal_direction")
assert_true(
  !any(forbidden_geom %in% CORE_CLUSTERING_KEYS) &&
    !any(forbidden_geom %in% DELTA_CLUSTERING_KEYS) &&
    !any(forbidden_geom %in% ALLOWED_CLUSTERING_KEYS),
  "Q24: E100/reciprocal fields excluded from Gower clustering keys"
)

# Guide hierarchy copy
assert_true(
  grepl("target_excess → NNH-like", html_std, fixed = TRUE) &&
    grepl("reference_excess → NNT-like", html_std, fixed = TRUE),
  "Guide: Safety direction mapping is explicit"
)
assert_true(
  grepl("guide-item-ugrade", html_std, fixed = TRUE) &&
    grepl("primary_delta が null の場合", html_std, fixed = TRUE),
  "Guide: U-Grade item retained with null-delta NONE contract"
)

cat(sprintf("\nSection 14 QA Test Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
