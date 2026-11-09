source(".agents/skills/vcd-categorical-reporting/comparative_reporting.R")

fixture <- data.frame(theme = c("事象", "事象"), arm = c("Drug", "Placebo"),
                      events = c(4L, 1L), total = c(20L, 20L))
root <- tempfile("tdd_lifecycle_", tmpdir = "evidence_runs/vcd_categorical_reporting")
result <- generate_comparative_report(fixture, target_arm = "Drug", reference_arm = "Placebo",
                                      contrast_mode = "explicit", output_dir = root)
run <- result$run_output_dir
meta <- jsonlite::read_json(file.path(run, "run_meta.json"), simplifyVector = FALSE)
manifest <- jsonlite::read_json(file.path(run, "results_manifest.json"), simplifyVector = FALSE)
handover_path <- file.path(run, "run_handover.json")
checks <- c(
  active = identical(meta$run_state, "active"),
  pass1_completed = identical(meta$pass_status$pass1, "completed"),
  no_final_dashboard = !file.exists(file.path(run, "dashboard.html")),
  preview_labeled = any(grepl('id="reporting-preview-notice"', readLines(file.path(run, "dashboard_preview.html"), warn = FALSE), fixed = TRUE)),
  manifest_excludes_dashboard = !any(vapply(manifest$artifacts, function(x) identical(x$path, "dashboard.html"), logical(1))),
  handover_exists = file.exists(handover_path)
)
if (file.exists(handover_path)) {
  handover <- jsonlite::read_json(handover_path, simplifyVector = FALSE)
  checks <- c(checks, pass2_handover = !is.null(handover$next_actions$pass2_ai),
              pass3_handover = !is.null(handover$next_actions$pass3))
}
print(checks)
if (!all(checks)) stop("Pass 1 lifecycle contract failed")
