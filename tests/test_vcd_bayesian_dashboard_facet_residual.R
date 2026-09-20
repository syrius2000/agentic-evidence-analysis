#!/usr/bin/env Rscript
# 3次元DashboardのFacet残差・estimand・交互作用解釈境界を検証

ca <- commandArgs(trailingOnly = FALSE)
f <- sub("^--file=", "", ca[startsWith(ca, "--file=")][1L])
repo <- if (is.na(f) || !nzchar(f)) {
  normalizePath(".", winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(dirname(f), ".."), winslash = "/", mustWork = TRUE)
}

p <- file.path(repo, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
stopifnot(file.exists(p))
lines <- readLines(p, warn = FALSE)
required <- c(
  "stratified-residual-matrix",
  "層別残差マトリクス（Pearson残差、Facet）",
  "title = \"層別残差マトリクス（Pearson残差）\"",
  "交互作用候補の探索",
  "モデル比較、逸脱度、BIC",
  "conditional-rate-plot",
  "ETI",
  "RD・RR・ORは別のestimand",
  "結果JSONに明示的な効果量契約がない限り"
)
missing <- required[!vapply(required, function(x) any(grepl(x, lines, fixed = TRUE)), logical(1))]
if (length(missing) > 0L) {
  stop("3次元Dashboardの可視化契約が不足しています: ", paste(missing, collapse = ", "))
}
message("OK: 3次元Facet残差・条件付きestimand・交互作用解釈境界が存在します。")
