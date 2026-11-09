source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")
fixture <- data.frame(theme = c("事象", "事象"), arm = c("Drug", "Placebo"),
                      events = c(4L, 1L), total = c(20L, 20L))
root <- tempfile("tdd_e2e_", tmpdir = Sys.getenv("REPORTING_TEST_OUTPUT", unset = "evidence_runs/vcd_categorical_reporting"))
run <- generate_comparative_report(fixture, target_arm = "Drug", reference_arm = "Placebo",
                                   contrast_mode = "explicit", output_dir = root)$run_output_dir
handover <- jsonlite::read_json(file.path(run, "run_handover.json"), simplifyVector = FALSE)
staging <- get_run_staging_dir(run)
summary <- c("# 要約", "Drug群とPlacebo群の比較。", "<script>alert('x')</script>")
writeLines(summary, file.path(staging, "executive_summary.md"), useBytes = TRUE)
invoke <- function(argv) {
  argv <- unlist(argv, use.names = FALSE)
  out <- system2(argv[[1L]], vapply(argv[-1L], shQuote, character(1L)), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) stop(paste(out, collapse = "\n"))
}
invoke(handover$next_actions$pass2_ai$finalize$argv)
invoke(handover$next_actions$pass3$argv)
meta <- read_run_control(run)
html <- paste(readLines(file.path(run, "dashboard.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
doc <- xml2::read_html(html)
accordion <- xml2::xml_find_first(doc, "//details[@id='executive-summary']")
checks <- c(
  sealed = identical(meta$run_state, "sealed"),
  summary = grepl("Drug群とPlacebo群の比較。", html, fixed = TRUE),
  summary_complete = all(vapply(c("要約", "Drug群とPlacebo群の比較。", "<script>alert('x')</script>"), grepl, logical(1), x = xml2::xml_text(accordion), fixed = TRUE)),
  summary_heading = length(xml2::xml_find_all(accordion, ".//h3[.='要約']")) == 1L,
  safe = grepl("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;", html, fixed = TRUE) && !grepl("<script>alert('x')</script>", html, fixed = TRUE),
  skill = grepl(meta$skill, html, fixed = TRUE),
  no_preview_notice = !grepl('id="reporting-preview-notice"', html, fixed = TRUE),
  narrative_hash = identical(meta$artifacts$narrative$sha256, sha256_file(file.path(run, "executive_summary.md"))),
  dashboard_hash = identical(meta$artifacts$dashboard$sha256, sha256_file(file.path(run, "dashboard.html"))),
  linked = identical(meta$artifacts$dashboard$based_on_narrative_sha256, meta$artifacts$narrative$sha256),
  manifest = isTRUE(verify_results_manifest(run)$valid),
  offline = !grepl("https?://", html),
  latest = identical(jsonlite::read_json(file.path(root, "latest.json"))$run_state, "sealed")
)
print(checks)
if (!all(checks)) stop("Reporting end-to-end contract failed")
