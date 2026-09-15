# test_vcd_categorical_dashboard_v4.R — Offline Dashboard & Static URL Scan Test Suite

suppressPackageStartupMessages({
  library(jsonlite)
  library(rmarkdown)
})

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R")
source(".agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R")
source(".agents/skills/vcd-categorical-analysis/R/serializer_v3.R")

test_pass <- 0L
test_fail <- 0L

cat("=== Starting Offline Dashboard & Static URL Scan Tests ===\n")

# 1. テスト用データの解析と Interface 3.0 出力
d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq")
diag <- compute_residual_diagnostics(v_data)
evid <- compute_effect_evidence_metrics(diag)
post <- compute_dirichlet_posterior(diag, alpha = 1.0, n_draws = 1000L, analysis_signature = "sig_dash_test")

tmp_dir <- tempfile(pattern = "dash_test_")
dir.create(tmp_dir)

# executive_summary.md の作成
writeLines(c("# サマリー", "テスト実行によるAI Narrative要約です。"), file.path(tmp_dir, "executive_summary.md"))
serialize_interface_v3(evid, post, out_dir = tmp_dir, run_id = "test_dash_run")

# 2. dashboard.Rmd のレンダリング
html_output <- file.path(tmp_dir, "dashboard.html")
rmd_template <- ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd"

render_res <- tryCatch({
  rmarkdown::render(
    input = rmd_template,
    output_file = html_output,
    params = list(output_dir = tmp_dir),
    quiet = TRUE
  )
  TRUE
}, error = function(e) {
  cat(sprintf("[FAIL] rmarkdown::render failed: %s\n", e$message))
  FALSE
})

if (render_res && file.exists(html_output)) {
  cat("[PASS] dashboard.html rendered successfully.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] dashboard.html rendering failed.\n")
  test_fail <- test_fail + 1L
}

# 3. 生成 HTML に対する外部リソース・CDN の静的正規表現スキャン
html_content <- paste(readLines(html_output, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# リソースロード構文（外部スクリプト・外部CSS・外部画像・CDN URL）の検査パターン
resource_load_patterns <- c(
  "<script[^>]+src=[\"'](https?:|//)",
  "<link[^>]+href=[\"'](https?:|//)",
  "<img[^>]+src=[\"'](https?:|//)",
  "@import\\s+[\"']?(https?:|//)",
  "url\\([\"']?(https?:|//)",
  "language\\s*:\\s*\\{\\s*url",
  "cdn\\.datatables\\.net",
  "fonts\\.googleapis\\.com",
  "cdnjs\\.cloudflare\\.com",
  "cdn\\.jsdelivr\\.net",
  "mathjax"
)

detected_violations <- character(0)
for (pat in resource_load_patterns) {
  if (grepl(pat, html_content, ignore.case = TRUE)) {
    detected_violations <- c(detected_violations, pat)
  }
}

if (length(detected_violations) == 0) {
  cat("[PASS] Static resource scan passed: 0 external CDN / resource loading references detected in rendered HTML.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] External resource loading references detected (%d patterns matched):\n", length(detected_violations)))
  for (p in detected_violations) {
    cat(sprintf("   - Pattern matched: %s\n", p))
  }
  test_fail <- test_fail + 1L
}

# 4. DataTables 日本語インライン辞書の存在確認
if (grepl("データが登録されていません", html_content, fixed = TRUE) &&
    !grepl("cdn.datatables.net", html_content, fixed = TRUE)) {
  cat("[PASS] DataTables Japanese language dictionary is fully inlined and CDN URL eliminated.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Inline DataTables dictionary not found or CDN URL remains.\n")
  test_fail <- test_fail + 1L
}

unlink(tmp_dir, recursive = TRUE)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
