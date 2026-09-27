# tests/test_dashboard_theme_contract.R
# Shared academic dashboard theme contract for HTML-producing skills.

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

find_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agents", "shared", "dashboard_theme.css"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  stop("[ERROR] repository root not found", call. = FALSE)
}

has_external_asset <- function(html) {
  resource_load_patterns <- c(
    "<script[^>]+src=[\"'](https?:|//)",
    "<link[^>]+href=[\"'](https?:|//)",
    "<img[^>]+src=[\"'](https?:|//)",
    "<iframe[^>]+src=[\"'](https?:|//)",
    "@import\\s+[\"']?(https?:|//)",
    "url\\([\"']?(https?:|//)",
    "fetch\\s*\\([\"'](https?:|//)",
    "cdn\\.datatables\\.net",
    "fonts\\.googleapis\\.com",
    "cdnjs\\.cloudflare\\.com",
    "cdn\\.jsdelivr\\.net",
    "(?:src|href)=[\"'](?:/Users/|/home/|/private/var/|[A-Za-z]:[\\\\/])",
    "url\\([\"']?(?:/Users/|/home/|/private/var/|[A-Za-z]:[\\\\/])"
  )
  any(vapply(resource_load_patterns, function(pat) grepl(pat, html, ignore.case = TRUE, perl = TRUE), logical(1)))
}

repo <- find_repo()
source(file.path(repo, ".agents", "shared", "dashboard_theme_tokens.R"), local = TRUE)
shared_css <- paste(
  readLines(file.path(repo, ".agents", "shared", "dashboard_theme.css"), warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)

cat("=== 1. Shared assets exist ===\n")
assert_true(file.exists(file.path(repo, ".agents", "shared", "dashboard_theme.css")), "dashboard_theme.css exists")
assert_true(file.exists(file.path(repo, ".agents", "shared", "dashboard_theme_tokens.R")), "dashboard_theme_tokens.R exists")
assert_true(identical(THEME_TOKENS$text_primary, "#152238"), "THEME_TOKENS$text_primary is academic navy text")
assert_true(identical(THEME_TOKENS$border_accent, "#1F4D7A"), "THEME_TOKENS$border_accent is academic accent")
assert_true(
  identical(theme_hex_to_rgba("#9B2945", "0.20"), "rgba(155, 41, 69, 0.20)"),
  "theme_hex_to_rgba maps burgundy correctly"
)

skill_files <- c(
  file.path(repo, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agents/skills/vcd-categorical-reporting/comparative_reporting.R"),
  file.path(repo, ".agents/skills/questionnaire-batch-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agents/skills/questionnaire-batch-analysis/templates/report.Rmd")
)

cat("\n=== 2. Skills reference shared theme ===\n")
for (f in skill_files) {
  txt <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  assert_true(file.exists(f), sprintf("exists: %s", basename(dirname(f))))
  assert_true(
    grepl("dashboard_theme.css", txt, fixed = TRUE) || grepl("load_shared_dashboard_theme_css", txt, fixed = TRUE),
    sprintf("shared CSS reference: %s", sub(paste0("^", repo, "/"), "", f))
  )
}

cat("\n=== 3. Forbidden page-chrome accents / flatly in product templates ===\n")
forbidden <- c("#0284c7", "#0f172a", "#1a3a5c", "#2d6a9f", "#8e44ad")
for (f in skill_files) {
  txt <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  assert_true(!grepl("theme:\\s*flatly", txt, perl = TRUE), sprintf("no flatly: %s", basename(f)))
  for (hex in forbidden) {
    assert_true(
      !grepl(hex, txt, fixed = TRUE),
      sprintf("no %s in %s", hex, basename(f))
    )
  }
}

cat("\n=== 4. Questionnaire must not override shared header chrome ===\n")
q_dash <- paste(
  readLines(
    file.path(repo, ".agents/skills/questionnaire-batch-analysis/templates/dashboard.Rmd"),
    warn = FALSE,
    encoding = "UTF-8"
  ),
  collapse = "\n"
)
# Isolate the local css chunk after shared theme embed.
css_chunk <- sub("(?s).*```\\{css, echo=FALSE\\}\\s*", "", q_dash, perl = TRUE)
css_chunk <- sub("(?s)```.*", "", css_chunk, perl = TRUE)
assert_true(
  !grepl("\\.header-banner\\s*\\{[^}]*background\\s*:", css_chunk, perl = TRUE),
  "questionnaire local CSS has no .header-banner background override"
)
assert_true(
  !grepl("\\.header-banner\\s*\\{[^}]*\\bcolor\\s*:", css_chunk, perl = TRUE),
  "questionnaire local CSS has no .header-banner color override"
)
assert_true(
  !grepl("\\.header-banner\\s+h2\\s*\\{[^}]*\\bcolor\\s*:", css_chunk, perl = TRUE),
  "questionnaire local CSS has no .header-banner h2 color override"
)
assert_true(
  grepl("\\.header-banner\\s*\\{\\s*background:\\s*#1f4d7a", shared_css, perl = TRUE),
  "shared CSS keeps navy .header-banner background"
)

assert_html_theme <- function(html, label) {
  theme_embedded <- grepl("Shared NEJM / Nature Medical", html, fixed = TRUE) ||
    grepl("background-color:\\s*#f6f8fb", html, ignore.case = TRUE, perl = TRUE)
  assert_true(theme_embedded, sprintf("%s embeds shared theme tokens", label))
  assert_true(grepl("\\.header-banner\\s*\\{\\s*background:\\s*#1f4d7a", html, perl = TRUE), sprintf("%s keeps shared header navy", label))
  assert_true(!grepl("#0284c7", html, fixed = TRUE), sprintf("%s has no cyan CTA", label))
  assert_true(!grepl("#0f172a", html, fixed = TRUE), sprintf("%s has no slate-900 header", label))
  assert_true(!has_external_asset(html), sprintf("%s has no external asset / absolute OS path", label))
}

fixture_root <- file.path(repo, "tests", "fixtures", "dashboard_theme")
dir.create(fixture_root, recursive = TRUE, showWarnings = FALSE)

cat("\n=== 5. Live render: reporting ===\n")
source(file.path(repo, ".agents/skills/vcd-categorical-reporting/comparative_reporting.R"), local = TRUE)
df <- data.frame(
  theme = c("AE_Demo", "AE_Demo"),
  arm = c("Target", "Control"),
  events = c(40L, 10L),
  total = c(200L, 200L),
  stringsAsFactors = FALSE
)
out_rep <- tempfile("theme_contract_rep_")
res_rep <- generate_comparative_report(
  df,
  reference_arm = "Control",
  primary_delta = 0.05,
  output_dir = out_rep,
  run_id = "theme_demo"
)
html_rep <- paste(readLines(res_rep$html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_html_theme(html_rep, "reporting live")
assert_true(grepl("background-color: rgba\\(155, 41, 69", html_rep, perl = TRUE), "reporting uses mapped T burgundy")
assert_true(grepl("<th[^>]*>実務領域</th>|<th>実務領域</th>", html_rep, perl = TRUE) || grepl("実務領域", html_rep, fixed = TRUE), "reporting retains practical-region column")

rep_fix <- file.path(fixture_root, "reporting_demo")
dir.create(rep_fix, recursive = TRUE, showWarnings = FALSE)
file.copy(res_rep$html_path, file.path(rep_fix, "dashboard.html"), overwrite = TRUE)

cat("\n=== 6. Live render: categorical ===\n")
suppressPackageStartupMessages({
  library(jsonlite)
  library(rmarkdown)
})
old_wd <- getwd()
setwd(repo)
on.exit(setwd(old_wd), add = TRUE)
source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R")
source(".agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R")
source(".agents/skills/vcd-categorical-analysis/R/serializer_v3.R")

d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated")
diag <- compute_residual_diagnostics(v_data)
evid <- compute_effect_evidence_metrics(diag)
sig_64 <- "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
input_sha_64 <- "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
config_sha_64 <- "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"
post <- compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 200L, analysis_signature = sig_64)
tmp_cat <- tempfile(pattern = "theme_cat_")
dir.create(tmp_cat)
writeLines(c(
  "# エグゼクティブ・サマリー: theme fixture",
  "",
  "## 1. 全体関連構造（Global Association）",
  "theme contract fixture",
  "",
  "## 2. 効果の大きさ（Effect Size）",
  "theme contract fixture",
  "",
  "## 3. 局所診断と安定性（Quarantine Diagnostics）",
  "theme contract fixture"
), file.path(tmp_cat, "executive_summary.md"))
serialize_interface_v3(
  evid, post,
  out_dir = tmp_cat,
  run_id = "theme_cat_demo",
  analysis_signature = sig_64,
  input_sha256 = input_sha_64,
  config_sha256 = config_sha_64,
  execution_mode = "canonical"
)
html_cat_path <- file.path(tmp_cat, "dashboard.html")
render_ok <- tryCatch(
  {
    rmarkdown::render(
      input = ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd",
      output_file = html_cat_path,
      params = list(output_dir = tmp_cat),
      quiet = TRUE
    )
    TRUE
  },
  error = function(e) {
    cat(sprintf("[FAIL] categorical render: %s\n", e$message))
    FALSE
  }
)
assert_true(isTRUE(render_ok) && file.exists(html_cat_path), "categorical dashboard rendered")
if (file.exists(html_cat_path)) {
  html_cat <- paste(readLines(html_cat_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  assert_html_theme(html_cat, "categorical live")
  cat_fix <- file.path(fixture_root, "categorical_demo")
  dir.create(cat_fix, recursive = TRUE, showWarnings = FALSE)
  file.copy(html_cat_path, file.path(cat_fix, "dashboard.html"), overwrite = TRUE)
}

cat("\n=== 7. Live render: questionnaire dashboard ===\n")
tmp_q <- tempfile(pattern = "theme_q_")
dir.create(tmp_q)
writeLines(
  "question_id,status,n_total,n_used\nq01_theme,success,100,100\n",
  file.path(tmp_q, "summary.csv")
)
jsonlite::write_json(
  list(
    survey_id = "theme_demo",
    question_id = "q01_theme",
    question_label = "Theme Demo",
    n_used = 100L,
    cramers_v = 0.21,
    max_abs_pearson_res = 1.4,
    p_value = 0.012
  ),
  file.path(tmp_q, "questionnaire_results.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)
writeLines(
  c("# executive summary", "", "## 1. Overview", "theme fixture"),
  file.path(tmp_q, "executive_summary.md")
)
html_q_path <- file.path(tmp_q, "dashboard.html")
render_q_ok <- tryCatch(
  {
    rmarkdown::render(
      input = ".agents/skills/questionnaire-batch-analysis/templates/dashboard.Rmd",
      output_file = html_q_path,
      params = list(output_dir = tmp_q),
      quiet = TRUE
    )
    TRUE
  },
  error = function(e) {
    cat(sprintf("[FAIL] questionnaire render: %s\n", e$message))
    FALSE
  }
)
assert_true(isTRUE(render_q_ok) && file.exists(html_q_path), "questionnaire dashboard rendered")
if (file.exists(html_q_path)) {
  html_q <- paste(readLines(html_q_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  assert_html_theme(html_q, "questionnaire live")
  # Final cascade: shared navy must appear; white header override must not win as last rule.
  assert_true(
    !grepl("\\.header-banner\\s*\\{\\s*background:\\s*#ffffff", html_q, perl = TRUE),
    "questionnaire HTML has no white .header-banner override"
  )
  assert_true(
    !grepl("\\.header-banner\\s+h2\\s*\\{\\s*[^}]*color:\\s*#152238", html_q, perl = TRUE),
    "questionnaire HTML has no navy-text h2 override on header"
  )
  q_fix <- file.path(fixture_root, "questionnaire_demo")
  dir.create(q_fix, recursive = TRUE, showWarnings = FALSE)
  file.copy(html_q_path, file.path(q_fix, "dashboard.html"), overwrite = TRUE)
}

cat("\n=== 8. Tracked fixture HTML evidence present ===\n")
for (rel in c(
  "reporting_demo/dashboard.html",
  "categorical_demo/dashboard.html",
  "questionnaire_demo/dashboard.html"
)) {
  p <- file.path(fixture_root, rel)
  assert_true(file.exists(p), sprintf("fixture exists: %s", rel))
  if (file.exists(p)) {
    h <- paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    assert_html_theme(h, sprintf("fixture %s", rel))
  }
}

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) {
  stop(sprintf("[FAIL] %d dashboard theme contract assertions failed.", test_fail))
}
