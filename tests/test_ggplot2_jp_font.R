# TDD tests: ggplot2 Japanese font support
# Run: Rscript tests/test_ggplot2_jp_font.R

stopifnot(getRversion() >= "4.0.0")

repo_root <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(d, ".agent")) && identical(basename(d), "tests")) {
    return(normalizePath(file.path(d, ".."), winslash = "/", mustWork = TRUE))
  }
  d
}
root <- repo_root()

# --- 1. detect_jp_font() returns non-empty string on current OS ---
detect_jp_font <- function() {
  os <- Sys.info()[["sysname"]]
  candidates <- switch(os,
    "Darwin"  = c("Hiragino Sans", "HiraginoSans-W3", "Hiragino Kaku Gothic Pro"),
    "Windows" = c("Yu Gothic", "Meiryo", "MS Gothic"),
    "Linux"   = c("Noto Sans CJK JP", "IPAexGothic", "IPAGothic"),
    character(0)
  )
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    avail <- unique(systemfonts::system_fonts()$family)
    for (f in candidates) {
      if (f %in% avail) return(f)
    }
  }
  if (length(candidates) > 0L) return(candidates[1L])
  ""
}

jp <- detect_jp_font()
stopifnot(nzchar(jp))
message("  [PASS] detect_jp_font() returned: ", jp)

# --- 2. OS candidate coverage ---
os <- Sys.info()[["sysname"]]
stopifnot(os %in% c("Darwin", "Windows", "Linux"))
message("  [PASS] OS '", os, "' is a supported platform")

# --- 3. Template files contain base_family in theme_minimal ---
# NOTE: current templates are dashboard.Rmd (not report.Rmd)
vcd_rmd <- file.path(root, ".agent", "skills", "vcd-categorical-analysis", "templates", "dashboard.Rmd")
quest_rmd <- file.path(root, ".agent", "skills", "questionnaire-batch-analysis", "templates", "dashboard.Rmd")

check_template_font <- function(path) {
  stopifnot(file.exists(path))
  src <- readLines(path, warn = FALSE)
  has_detect <- any(grepl("detect_jp_font", src, fixed = TRUE))
  has_base_family <- any(grepl("base_family", src, fixed = TRUE))
  list(detect = has_detect, base_family = has_base_family)
}

res_vcd <- check_template_font(vcd_rmd)
stopifnot(res_vcd$detect)
stopifnot(res_vcd$base_family)
message("  [PASS] vcd report.Rmd has detect_jp_font and base_family")

res_quest <- check_template_font(quest_rmd)
stopifnot(res_quest$detect)
stopifnot(res_quest$base_family)
message("  [PASS] questionnaire report.Rmd has detect_jp_font and base_family")

# --- 4. Mirror consistency ---
vcd_agent <- readLines(vcd_rmd, warn = FALSE)
vcd_cursor <- readLines(
  file.path(root, ".cursor", "skills", "vcd-categorical-analysis", "templates", "dashboard.Rmd"),
  warn = FALSE
)
stopifnot(identical(vcd_agent, vcd_cursor))
message("  [PASS] vcd template: .agent == .cursor mirror")

quest_agent <- readLines(quest_rmd, warn = FALSE)
quest_cursor <- readLines(
  file.path(root, ".cursor", "skills", "questionnaire-batch-analysis", "templates", "dashboard.Rmd"),
  warn = FALSE
)
stopifnot(identical(quest_agent, quest_cursor))
message("  [PASS] questionnaire template: .agent == .cursor mirror")

# --- 5. ggplot2 renders Japanese legend without error ---
if (requireNamespace("ggplot2", quietly = TRUE)) {
  jp_font <- detect_jp_font()
  tmp <- tempfile(fileext = ".png")
  df <- data.frame(
    x = 1:3,
    y = c(10, 20, 15),
    grp = c("\u60aa\u5bd2", "\u982d\u75db", "\u767a\u71b1")
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x, y, color = grp)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::theme_minimal(base_size = 13, base_family = jp_font)
  ggplot2::ggsave(tmp, plot = p, width = 6, height = 4, dpi = 72)
  stopifnot(file.exists(tmp))
  stopifnot(file.size(tmp) > 0L)
  unlink(tmp)
  message("  [PASS] ggplot2 with Japanese legend rendered successfully")
} else {
  message("  [SKIP] ggplot2 not available, skipping render test")
}

message("\nOK: all ggplot2 Japanese font tests passed.")
