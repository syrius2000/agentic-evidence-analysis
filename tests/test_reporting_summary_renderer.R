source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")
renderer <- ".agents/skills/vcd-categorical-reporting/render_dashboard.R"
if (file.exists(renderer)) source(renderer)

fixture <- data.frame(theme = c("事象", "事象"), arm = c("Drug", "Placebo"),
                      events = c(4L, 1L), total = c(20L, 20L))
make_run <- function() {
  root <- tempfile("tdd_renderer_", tmpdir = Sys.getenv("REPORTING_TEST_OUTPUT", unset = "evidence_runs/vcd_categorical_reporting"))
  generate_comparative_report(fixture, target_arm = "Drug", reference_arm = "Placebo",
                              contrast_mode = "explicit", output_dir = root)$run_output_dir
}
put_summary <- function(run, value) {
  meta <- read_run_control(run)
  dir.create(file.path(run, "staging"), showWarnings = FALSE)
  path <- file.path(run, "staging", "executive_summary.md")
  writeLines(value, path, useBytes = TRUE)
  finalize_pass2(run, source_staging_path = path,
                 expected_results_manifest_sha256 = meta$results_manifest_sha256)
}
attempt <- function(run) tryCatch({render_reporting_dashboard(run); "OK"}, error = function(e) conditionMessage(e))

missing <- make_run()
missing_result <- attempt(missing)
empty <- make_run()
empty_result <- tryCatch({put_summary(empty, character()); "OK"}, error = function(e) conditionMessage(e))
whitespace <- make_run()
whitespace_result <- tryCatch({put_summary(whitespace, "   \t  "); "OK"}, error = function(e) conditionMessage(e))
stale <- make_run()
put_summary(stale, "元の要約")
writeLines("改変された要約", file.path(stale, "executive_summary.md"), useBytes = TRUE)
stale_result <- attempt(stale)
valid <- make_run()
summary <- c("# 解析要約", "", "日本語の **結論** & 注意", "", "- 一", "- 二", "", "5. 五", "6. 六", "", "| 列 | 値 |", "|---|---|", "| 一 | 1 |", "", "<script>alert(1)</script>", "<img src=x onerror=alert(1)>", "[危険](javascript:alert(1))", "![外部画像](https://example.com/a.png)")
put_summary(valid, summary)
valid_result <- attempt(valid)
html_path <- file.path(valid, "dashboard.html")
html <- if (file.exists(html_path)) paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else ""
meta <- read_run_control(valid)
latest <- jsonlite::read_json(file.path(meta$out_root, "latest.json"), simplifyVector = FALSE)
doc <- xml2::read_html(html)
preview_doc <- xml2::read_html(file.path(valid, "dashboard_preview.html"))
ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id='dashboard-title' or @id='guidance-callout' or @id='executive-summary']"), "id")
accordion <- xml2::xml_find_first(doc, "//details[@id='executive-summary']")
checks <- c(
  missing_rejected = grepl("Pass 2|narrative|要約", missing_result, ignore.case = TRUE),
  empty_rejected = grepl("空|empty", empty_result, ignore.case = TRUE),
  whitespace_rejected = grepl("空|empty", whitespace_result, ignore.case = TRUE),
  stale_rejected = grepl("sha256|不一致", stale_result, ignore.case = TRUE),
  rejected_without_dashboard = !any(file.exists(file.path(c(missing, empty, whitespace, stale), "dashboard.html"))),
  rendered = identical(valid_result, "OK"),
  content = grepl("日本語の <strong>結論</strong> &amp; 注意", html, fixed = TRUE),
  display_order = identical(ids, c("dashboard-title", "guidance-callout", "executive-summary")),
  accordion_open = !inherits(accordion, "xml_missing") && !is.na(xml2::xml_attr(accordion, "open")),
  heading = length(xml2::xml_find_all(accordion, "./summary/h2[contains(.,'エクゼクティブサマリー')]")) == 1L,
  markdown = length(xml2::xml_find_all(accordion, ".//h3|.//strong|.//ul/li|.//table")) >= 5L,
  ordered_start = length(xml2::xml_find_all(accordion, ".//ol[@start='5']")) == 1L,
  guidance_unchanged = identical(as.character(xml2::xml_find_first(doc, "//*[@id='guidance-callout']")), as.character(xml2::xml_find_first(preview_doc, "//*[@id='guidance-callout']"))),
  no_active_content = length(xml2::xml_find_all(accordion, ".//script|.//img|.//a[@href]|.//*[@onclick or @onerror]")) == 0L,
  skill = grepl("vcd-categorical-reporting", html, fixed = TRUE),
  escaped = grepl("&lt;script&gt;alert(1)&lt;/script&gt;", html, fixed = TRUE) && !grepl("<script>alert(1)</script>", html, fixed = TRUE),
  sealed = identical(meta$run_state, "sealed"),
  latest_sealed = identical(latest$run_state, "sealed") && identical(latest$path, basename(valid)),
  provenance = !is.null(meta$artifacts$dashboard$based_on_narrative_sha256),
  manifest = isTRUE(verify_results_manifest(valid)$valid)
)
print(checks)
if (!all(checks)) stop("Reporting summary renderer contract failed")
