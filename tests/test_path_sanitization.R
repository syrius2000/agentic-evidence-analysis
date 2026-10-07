# tests/test_path_sanitization.R — Path and link sanitization contract test
# Detects real absolute paths / real Markdown navigation links repository-wide.
# Explanatory literals (placeholders, scheme-only backticks) are allowed;
# concrete absolute paths are rejected even inside Markdown code spans.

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

# Keep code-span contents for scanning; do not delete them (QA-PATH-M01).
unwrap_backticks <- function(line) {
  gsub("`([^`]*)`", " \\1 ", line, perl = TRUE)
}

# Markdown navigation destinations: ](file:///...), ](C:\...), ](\\server\...)
is_md_file_nav <- function(line) {
  grepl("]\\(file:///", line, perl = TRUE)
}

is_md_win_nav <- function(line) {
  grepl("]\\([A-Za-z]:\\\\", line, perl = TRUE) ||
    grepl("]\\(\\\\\\\\", line, perl = TRUE)
}

# Real POSIX absolute paths with a concrete first segment (not placeholders / ellipsis).
# Includes concrete /tmp/<name> (QA-PATH-H01); bare `/tmp/` discussion literals are allowed.
posix_abs_re <- paste0(
  "(^|[^A-Za-z0-9_])",
  "(",
  "/Users/[A-Za-z0-9][A-Za-z0-9_-]*/",
  "|/home/[A-Za-z0-9][A-Za-z0-9_-]*/",
  "|/private/var/[A-Za-z0-9._-]+/",
  "|/tmp/[A-Za-z0-9][A-Za-z0-9._-]*(/|\\.|\"|'|\\s|$)",
  ")"
)

is_real_posix_abs <- function(line) {
  grepl(posix_abs_re, line, perl = TRUE)
}

# Windows absolute paths: drive-root with ≥2 path segments (D:\Projects\repo\...).
# Two-segment rule avoids R/JS false positives like "Options:\n" / minified "s:\n".
is_real_win_abs <- function(line) {
  grepl("[A-Za-z]:\\\\[A-Za-z0-9._-]+\\\\[A-Za-z0-9._-]+", line, perl = TRUE) ||
    grepl("(^|[^A-Za-z0-9_])[A-Za-z]:/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+", line, perl = TRUE) ||
    grepl("(^|[^A-Za-z0-9_])\\\\\\\\[A-Za-z0-9][A-Za-z0-9._-]*\\\\[A-Za-z0-9][A-Za-z0-9._-]*\\\\", line, perl = TRUE)
}

git_files <- system2("git", c("ls-files"), stdout = TRUE, stderr = FALSE)
test_script_rel <- "tests/test_path_sanitization.R"
fixture_prefix <- "tests/fixtures/path_sanitization/"
qa_cycles_prefix <- "docs/Artifacts/qa_cycles/"
archives_prefix <- "docs/Archives/"
scan_files <- setdiff(git_files, test_script_rel)
scan_files <- scan_files[!startsWith(scan_files, fixture_prefix)]
# QA cycle artifacts may cite adversarial path examples as findings evidence.
scan_files <- scan_files[!startsWith(scan_files, qa_cycles_prefix)]
# Frozen archive trees keep historical path examples; not product runtime surface.
scan_files <- scan_files[!startsWith(scan_files, archives_prefix)]

target_user <- intToUtf8(c(109L, 121L, 97L, 109L, 97L, 103L, 117L, 99L, 104L, 105L))

user_hits <- character(0)
posix_hits <- character(0)
md_link_hits <- character(0)
win_hits <- character(0)

for (f in scan_files) {
  if (!file.exists(f) || isTRUE(file.info(f)$isdir)) next
  ext <- tolower(tools::file_ext(f))
  if (ext %in% c("png", "jpg", "jpeg", "gif", "ico", "gz", "tar", "zip", "pdf", "rda", "rds")) next

  lines <- tryCatch(readLines(f, encoding = "UTF-8", warn = FALSE), error = function(e) NULL)
  if (is.null(lines) || length(lines) == 0L) next

  for (ln in lines) {
    plain <- unwrap_backticks(ln)
    if (grepl(target_user, plain, ignore.case = TRUE)) {
      user_hits <- c(user_hits, f)
    }
    if (is_real_posix_abs(plain)) {
      posix_hits <- c(posix_hits, f)
    }
    if (ext == "md") {
      if (is_md_file_nav(plain)) md_link_hits <- c(md_link_hits, f)
      if (is_md_win_nav(plain)) win_hits <- c(win_hits, f)
    }
    if (is_real_win_abs(plain)) {
      win_hits <- c(win_hits, f)
    }
  }
}

user_hits <- unique(user_hits)
posix_hits <- unique(posix_hits)
md_link_hits <- unique(md_link_hits)
win_hits <- unique(win_hits)

cat("=== 1. Specific username absolute path ===\n")
if (length(user_hits) > 0) {
  cat(sprintf("[DETAIL] Matches found in: %s\n", paste(user_hits, collapse = ", ")))
}
assert_true(length(user_hits) == 0L, "No occurrences of specific username path in repository files")

cat("\n=== 2. Generic POSIX absolute paths (/Users|/home|/private/var|/tmp) ===\n")
if (length(posix_hits) > 0) {
  cat(sprintf("[DETAIL] Matches found in: %s\n", paste(posix_hits, collapse = ", ")))
}
assert_true(
  length(posix_hits) == 0L,
  "No real POSIX absolute paths (/Users/<user>/, /home/<user>/, /private/var/, /tmp/<name>)"
)

cat("\n=== 3. Markdown file:/// navigation links ===\n")
if (length(md_link_hits) > 0) {
  cat(sprintf("[DETAIL] Links found in: %s\n", paste(md_link_hits, collapse = ", ")))
}
assert_true(length(md_link_hits) == 0L, "No markdown navigation links using ](file:///)")

cat("\n=== 4. Windows drive / UNC real paths ===\n")
if (length(win_hits) > 0) {
  cat(sprintf("[DETAIL] Matches found in: %s\n", paste(win_hits, collapse = ", ")))
}
assert_true(length(win_hits) == 0L, "No Windows drive or UNC absolute paths (nav or literal)")

cat("\n=== 5. Adversarial fixtures (explanatory literals must be allowed) ===\n")
fixture_dir <- "tests/fixtures/path_sanitization"
assert_true(dir.exists(fixture_dir), "Adversarial fixture directory exists")

literal_md <- file.path(fixture_dir, "allowed_literals.md")
assert_true(file.exists(literal_md), "allowed_literals.md exists")
lit_lines <- readLines(literal_md, encoding = "UTF-8", warn = FALSE)
lit_plain <- vapply(lit_lines, unwrap_backticks, character(1L), USE.NAMES = FALSE)
assert_true(
  any(grepl("file:///", lit_lines, fixed = TRUE)) &&
    !any(vapply(lit_plain, is_md_file_nav, logical(1L))),
  "Fixture documents file:/// only as explanatory literal (not ](file:///))"
)
assert_true(
  any(grepl("/Users/<user>/", lit_lines, fixed = TRUE)) &&
    !any(vapply(lit_plain, is_real_posix_abs, logical(1L))),
  "Fixture /Users/<user>/ placeholder is not treated as real POSIX abs path"
)

# Positive-control lines (ephemeral; never rely on a tracked reject fixture)
demo_user <- paste0("user", "demo")
reject_lines <- c(
  paste0("- Real Markdown navigation: [bad](file://", "/Users/", demo_user, "/secret.R)"),
  paste0("- Real POSIX abs: notes under ", "/Users/", demo_user, "/Programing/demo/"),
  paste0("- Backticked concrete POSIX: `", "/Users/", demo_user, "/project/file.R`"),
  paste0("- Windows nav: [win](C:\\Users\\", demo_user, "\\demo.R)"),
  "- Generic Windows drive: notes under D:\\Projects\\repo\\file.R",
  "- Concrete tmp path: write to /tmp/example/file"
)
reject_plain <- vapply(reject_lines, unwrap_backticks, character(1L), USE.NAMES = FALSE)
assert_true(
  any(vapply(reject_plain, is_md_file_nav, logical(1L))),
  "Reject samples contain ](file:///) navigation (detector positive control)"
)
assert_true(
  any(vapply(reject_plain, is_real_posix_abs, logical(1L))),
  "Reject samples contain concrete /Users/<user>/... style path (detector positive control)"
)
assert_true(
  isTRUE(is_real_posix_abs(reject_plain[[3L]])),
  "Backticked concrete /Users/<user>/... style path is rejected after unwrap (QA-PATH-M01)"
)
assert_true(
  any(vapply(reject_plain, is_md_win_nav, logical(1L))),
  "Reject samples contain Windows Markdown navigation (detector positive control)"
)
assert_true(
  isTRUE(is_real_win_abs(reject_plain[[5L]])),
  "Generic Windows drive absolute path D:\\\\Projects\\\\... is rejected (QA-PATH-M01)"
)
assert_true(
  isTRUE(is_real_posix_abs(reject_plain[[6L]])),
  "Concrete /tmp/example/file is rejected (QA-PATH-H01)"
)

# Negative controls: placeholders / scheme literals remain allowed
allow_lines <- c(
  "Document placeholder `/Users/<user>/` in backticks.",
  "Document scheme only as `file:///`.",
  "Tilde form `~/...` is documentation only.",
  "Bare scheme discussion mentions /tmp/ without a concrete leaf.",
  "Placeholder `/tmp/<name>/` is documentation only."
)
allow_plain <- vapply(allow_lines, unwrap_backticks, character(1L), USE.NAMES = FALSE)
assert_true(
  !any(vapply(allow_plain, is_real_posix_abs, logical(1L))) &&
    !any(vapply(allow_plain, is_md_file_nav, logical(1L))) &&
    !any(vapply(allow_plain, is_real_win_abs, logical(1L))),
  "Placeholder /Users/<user>/, ~/..., /tmp/<name>/, bare /tmp/, and file:/// literals are allowed"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) {
  stop(sprintf("[FAIL] %d path sanitization assertions failed.", test_fail))
}
