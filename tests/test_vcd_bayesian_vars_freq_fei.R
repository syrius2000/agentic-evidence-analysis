# --vars / --freq の非既定列 + 1-way Fei の検証
# Run from repo root: Rscript tests/test_vcd_bayesian_vars_freq_fei.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

# Case 1: 1-way + 非既定 freq 列で Fei が主効果になる
td1 <- tempfile("vcd_bay_fei_")
dir.create(td1)
on.exit(unlink(td1, recursive = TRUE), add = TRUE)

csv1 <- file.path(td1, "one_way.csv")
write.csv(
  data.frame(Category = c("A", "B", "C"), Count = c(30, 20, 10), stringsAsFactors = FALSE),
  csv1,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

st1 <- system2("Rscript", c(
  analysis,
  "--input", csv1,
  "--output_dir", td1,
  "--vars", "Category",
  "--freq", "Count"
))
stopifnot(identical(as.integer(st1), 0L))

jp1 <- list.files(td1, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp1) == 1L)
res1 <- jsonlite::fromJSON(jp1[1L])
stopifnot(identical(res1$effects$primary, "fei"))
stopifnot(is.finite(res1$effects$fei))
stopifnot(res1$core$n_total == 60)
stopifnot(identical(res1$core$dimensions, "Category"))

# Case 2: --vars は空白入り CSV 指定でも列解決できる
td2 <- tempfile("vcd_bay_vars_")
dir.create(td2)
on.exit(unlink(td2, recursive = TRUE), add = TRUE)

csv2 <- file.path(td2, "two_way.csv")
write.csv(
  data.frame(
    Sex = c("F", "F", "M", "M"),
    Event = c("Y", "N", "Y", "N"),
    Weight = c(10, 20, 30, 40),
    stringsAsFactors = FALSE
  ),
  csv2,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

st2 <- system2("Rscript", c(
  analysis,
  "--input", csv2,
  "--output_dir", td2,
  "--vars", shQuote("Sex, Event"),
  "--freq", "Weight"
))
stopifnot(identical(as.integer(st2), 0L))

jp2 <- list.files(td2, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp2) == 1L)
res2 <- jsonlite::fromJSON(jp2[1L])
stopifnot(identical(res2$core$dimensions, c("Sex", "Event")))
stopifnot(res2$core$n_total == 100)

message("OK: vars/freq + fei")
