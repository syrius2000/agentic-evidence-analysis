# dashboard.Rmd のモザイク描画が shade = TRUE になっていることを検証（vcd 不要）
# Run: Rscript tests/test_vcd_categorical_template_assoc_shade.R

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}
paths <- c(
  file.path(repo, ".cursor/skills/vcd-categorical-analysis/templates/dashboard.Rmd"),
  file.path(repo, ".agent/skills/vcd-categorical-analysis/templates/dashboard.Rmd")
)
for (p in paths) {
  stopifnot(file.exists(p))
  lines <- readLines(p, warn = FALSE)
  mosaic_lines <- grep("^[[:space:]]*.*mosaic\\(", lines, value = TRUE)
  stopifnot(length(mosaic_lines) >= 1L)
  if (!any(grepl("shade\\s*=\\s*TRUE", mosaic_lines))) {
    stop("mosaic() must use shade = TRUE in: ", p)
  }
}
message("OK: mosaic shade = TRUE present in both dashboard.Rmd templates.")
