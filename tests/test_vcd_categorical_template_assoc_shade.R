# 現行2次元DashboardのEffect×Evidenceと調整残差の描画契約を検証（vcd 不要）
# Run: Rscript tests/test_vcd_categorical_template_assoc_shade.R

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}
paths <- c(
  file.path(repo, ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd")
)
for (p in paths) {
  stopifnot(file.exists(p))
  lines <- readLines(p, warn = FALSE)
  if (!any(grepl("```\\{r effect-evidence-plot[,}]", lines))) {
    stop("effect-evidence-plot chunk is missing in: ", p)
  }
  if (!any(grepl("```\\{r adjusted-residual-plot[,}]", lines))) {
    stop("adjusted-residual-plot chunk is missing in: ", p)
  }
  if (!any(grepl("scale_color_manual\\(values = master_row_palette", lines, fixed = FALSE))) {
    stop("row-category master palette is missing in: ", p)
  }
}
message("OK: current Effect×Evidence and adjusted-residual plot contracts are present.")
