if (!exists("finalize_stage", mode = "function")) source(".agents/shared/run_scope.R")

render_reporting_dashboard <- function(run_dir) {
  run_dir <- normalizePath(assert_no_symlink(run_dir), winslash = "/", mustWork = TRUE)
  lock <- acquire_stage_lock(run_dir, "run")
  on.exit(release_stage_lock(lock), add = TRUE)
  meta <- read_run_control(run_dir)
  if (!identical(meta$skill, "vcd-categorical-reporting")) stop("[ERROR] reporting skill mismatch")
  if (!identical(meta$run_state, "active") || !identical(meta$pass_status$pass1, "completed")) stop("[ERROR] run is not active after Pass 1")
  verify_results_manifest(run_dir, meta$results_manifest_sha256)
  narrative_hash <- verify_narrative(run_dir, meta, meta$results_manifest_sha256)
  summary_path <- assert_path_within_run_dir("executive_summary.md", run_dir)
  summary <- paste(readLines(summary_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!nzchar(trimws(summary))) stop("[ERROR] 要約が空です")
  preview_path <- assert_path_within_run_dir("dashboard_preview.html", run_dir)
  if (is.null(meta$dashboard_preview_sha256) || !identical(sha256_file(preview_path), meta$dashboard_preview_sha256)) stop("[ERROR] Dashboard preview SHA256 不一致")
  html <- paste(readLines(preview_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  preview_notice <- '<aside id="reporting-preview-notice" class="callout" role="status">暫定プレビュー：AI要約とDashboardの確定は未完了です。</aside>'
  notice_pos <- gregexpr(preview_notice, html, fixed = TRUE)[[1L]]
  if (length(notice_pos) != 1L || notice_pos[1L] < 0L) stop("[ERROR] Dashboard preview notice 不正")
  html <- sub(preview_notice, "", html, fixed = TRUE)
  marker <- "<body>"
  pos <- gregexpr(marker, html, fixed = TRUE)[[1L]]
  if (length(pos) != 1L || pos[1L] < 0L) stop("[ERROR] Dashboard body marker 不正")
  escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    gsub("'", "&#39;", x, fixed = TRUE)
  }
  section <- paste0('\n<section id="executive-summary" aria-label="解析要約"><h2>解析要約</h2><p>分析スキル: ',
                    escape(meta$skill), '</p><pre style="white-space:pre-wrap;overflow-wrap:anywhere;font-family:inherit">',
                    escape(summary), '</pre></section>\n')
  end <- pos[1L] + nchar(marker) - 1L
  html <- paste0(substr(html, 1L, end), section, substr(html, end + 1L, nchar(html)))
  staging <- get_run_staging_dir(run_dir)
  work <- tempfile("reporting_", tmpdir = staging)
  if (!dir.create(work)) stop("[ERROR] staging 作成失敗")
  target <- file.path(work, "dashboard.html")
  writeLines(html, target, useBytes = TRUE)
  finalize_stage(run_dir, "pass3", "dashboard.html", target, meta$results_manifest_sha256,
                 narrative_hash, common_lock = lock)
  invisible(NULL)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || args[1L] != "--run-dir") stop("Usage: Rscript render_dashboard.R --run-dir <run>")
  render_reporting_dashboard(args[2L])
}
