if (!exists("finalize_stage", mode = "function")) source(".agents/shared/run_scope.R")

reporting_html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}

# Render only a fixed set of CommonMark nodes. Raw HTML and destinations
# are text; no input can introduce executable tags, attributes or assets.
reporting_markdown_html <- function(markdown) {
  check_r_dependencies(c("commonmark", "xml2"), "比較Dashboard要約描画")
  tree <- xml2::read_xml(commonmark::markdown_xml(markdown, extensions = TRUE), options = "NONET")
  render <- function(node, header = FALSE) {
    type <- xml2::xml_name(node)
    children <- xml2::xml_children(node)
    inner <- function(header = FALSE) paste(vapply(children, render, character(1), header = header), collapse = "")
    wrap <- function(tag, content = inner()) paste0("<", tag, ">", content, "</", tag, ">")
    if (type %in% c("text", "html_inline", "html_block")) return(reporting_html_escape(xml2::xml_text(node)))
    if (type == "document") return(inner())
    if (type == "paragraph") return(wrap("p"))
    if (type == "heading") {
      level <- suppressWarnings(as.integer(xml2::xml_attr(node, "level")))
      if (is.na(level)) stop("[ERROR] Markdown見出し水準が不正です")
      return(wrap(paste0("h", min(6L, level + 2L))))
    }
    if (type == "strong") return(wrap("strong"))
    if (type == "emph") return(wrap("em"))
    if (type == "strikethrough") return(wrap("del"))
    if (type == "code") return(wrap("code", reporting_html_escape(xml2::xml_text(node))))
    if (type == "code_block") return(wrap("pre", wrap("code", reporting_html_escape(xml2::xml_text(node)))))
    if (type %in% c("softbreak", "linebreak")) return("<br>")
    if (type == "thematic_break") return("<hr>")
    if (type == "block_quote") return(wrap("blockquote"))
    if (type == "list") {
      if (!identical(xml2::xml_attr(node, "type"), "ordered")) return(wrap("ul"))
      start <- xml2::xml_attr(node, "start")
      if (is.na(start) || !grepl("^[0-9]+$", start)) stop("[ERROR] Markdown番号付きリストの開始値が不正です")
      return(paste0('<ol start="', start, '">', inner(), '</ol>'))
    }
    if (type == "item") return(wrap("li"))
    if (type == "table") return(wrap("table"))
    if (type == "table_header") return(paste0("<thead><tr>", inner(TRUE), "</tr></thead>"))
    if (type == "table_row") return(wrap("tr"))
    if (type == "table_cell") return(wrap(if (header) "th" else "td"))
    if (type %in% c("link", "image")) {
      destination <- xml2::xml_attr(node, "destination")
      suffix <- if (is.na(destination) || !nzchar(destination)) "" else paste0(" (", gsub(":", "&#58;", reporting_html_escape(destination), fixed = TRUE), ")")
      return(paste0(if (type == "image") "画像: " else "", inner(), suffix))
    }
    if (length(children)) return(inner())
    reporting_html_escape(xml2::xml_text(node))
  }
  render(xml2::xml_root(tree))
}

render_reporting_dashboard <- function(run_dir) {
  check_r_dependencies(c("commonmark", "xml2"), "比較Dashboard要約描画")
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
  marker <- '<div id="guidance-callout" class="callout">'
  pos <- gregexpr(marker, html, fixed = TRUE)[[1L]]
  if (length(pos) != 1L || pos[1L] < 0L) stop("[ERROR] Dashboard免責事項 marker 不正")
  tail <- substr(html, pos[1L] + nchar(marker), nchar(html))
  closing <- regexpr("</div>", tail, fixed = TRUE)[1L]
  if (closing < 0L || grepl("<div", substr(tail, 1L, closing - 1L), fixed = TRUE)) stop("[ERROR] Dashboard免責事項構造が不正です")
  end <- pos[1L] + nchar(marker) + closing - 1L + nchar("</div>") - 1L
  section <- paste0('\n<details id="executive-summary" class="guide-accordion" open><summary class="guide-summary"><h2 style="display:inline;font-size:1em;margin:0">エクゼクティブサマリー</h2></summary><div class="guide-content"><p>分析スキル: ',
                    reporting_html_escape(meta$skill), '</p>', reporting_markdown_html(summary), '</div></details>\n')
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
