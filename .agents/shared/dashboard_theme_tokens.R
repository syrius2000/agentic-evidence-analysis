# .agents/shared/dashboard_theme_tokens.R
# Canonical academic (NEJM / Nature Medical) color tokens for Dashboard HTML / ggplot.
# Keep hex values synchronized with dashboard_theme.css where classes encode the same meaning.

THEME_TOKENS <- list(
  bg_page = "#FFFFFF",
  bg_card = "#F6F8FB",
  bg_subtle = "#F1F5F9",
  text_primary = "#152238",
  text_secondary = "#64748B",
  text_muted = "#94A3B8",
  border_light = "#E2E8F0",
  border_accent = "#1F4D7A",
  ref_line = "#CBD5E1",
  row_level_1 = "#1F4D7A",
  row_level_2 = "#9B2945",
  row_levels_multi = c(
    "#1F4D7A",
    "#9B2945",
    "#2E7D7A",
    "#D97706",
    "#5B21B6",
    "#475569",
    "#BE185D",
    "#047857"
  ),
  residual_pos = "#0F766E",
  residual_neg = "#B45309",
  dual_filter = "#6D28D9",
  quarantined = "#A16207",

  # Comparative practical-region cell backgrounds (semantic rules unchanged; palette only)
  practical_t = "#9B2945",
  practical_n = "#1F4D7A",
  practical_r = "#64748B",
  practical_u3 = "#64748B"
)

theme_hex_to_rgba <- function(hex, alpha) {
  h <- gsub("^#", "", as.character(hex)[[1L]])
  if (nchar(h) != 6L) {
    stop(sprintf("[ERROR] Invalid theme hex: %s", hex), call. = FALSE)
  }
  r <- strtoi(substr(h, 1L, 2L), 16L)
  g <- strtoi(substr(h, 3L, 4L), 16L)
  b <- strtoi(substr(h, 5L, 6L), 16L)
  sprintf("rgba(%d, %d, %d, %s)", r, g, b, as.character(alpha)[[1L]])
}

get_row_palette <- function(row_levels) {
  unique_rows <- unique(as.character(row_levels))
  k <- length(unique_rows)
  if (k == 1L) {
    pal <- setNames(THEME_TOKENS$row_level_1, unique_rows)
  } else if (k == 2L) {
    pal <- setNames(c(THEME_TOKENS$row_level_1, THEME_TOKENS$row_level_2), unique_rows)
  } else if (k <= length(THEME_TOKENS$row_levels_multi)) {
    pal <- setNames(THEME_TOKENS$row_levels_multi[seq_len(k)], unique_rows)
  } else {
    hues <- seq(15, 375, length.out = k + 1L)[seq_len(k)]
    fallback_colors <- grDevices::hcl(h = hues, c = 55, l = 45)
    pal <- setNames(fallback_colors, unique_rows)
  }
  pal
}

load_shared_dashboard_theme_css <- function(repo_root) {
  path <- file.path(repo_root, ".agents", "shared", "dashboard_theme.css")
  if (!file.exists(path)) {
    stop(sprintf("[ERROR] dashboard_theme.css が見つかりません: %s", path), call. = FALSE)
  }
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

require_shared_dashboard_assets <- function(repo_root, extra = character(0)) {
  needed <- c(
    "dashboard_theme.css",
    "dashboard_theme_tokens.R",
    "dashboard_dt_ja.R",
    "dashboard_glossary.R",
    extra
  )
  needed <- unique(needed)
  paths <- file.path(repo_root, ".agents", "shared", needed)
  missing <- needed[!file.exists(paths)]
  if (length(missing) > 0L) {
    stop(
      sprintf(
        "[ERROR] 共有ダッシュボード資産が欠落しています: %s (root=%s)",
        paste(missing, collapse = ", "),
        repo_root
      ),
      call. = FALSE
    )
  }
  invisible(normalizePath(repo_root, winslash = "/", mustWork = TRUE))
}
