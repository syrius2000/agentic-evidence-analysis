# ARMスキップ経路 / practical_significance_low / CLI失敗系の検証
# Run from repo root: Rscript tests/test_vcd_bayesian_arm_warning_cli_fail.R

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

td <- tempfile("vcd_bay_warn_cli_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

# Case 1: Freq付き集計表 => ARMスキップ & practical_significance_low が true
csv <- file.path(td, "agg.csv")
write.csv(
  data.frame(
    Sex = c("F", "F", "M", "M"),
    Event = c("Y", "N", "Y", "N"),
    Freq = c(10, 20, 30, 40),
    stringsAsFactors = FALSE
  ),
  csv,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

out_ok <- file.path(td, "ok")
dir.create(out_ok)
st_ok <- system2("Rscript", c(
  analysis,
  "--input", csv,
  "--output_dir", out_ok,
  "--vars", "Sex,Event",
  "--freq", "Freq"
))
stopifnot(identical(as.integer(st_ok), 0L))

jp <- list.files(out_ok, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
res <- jsonlite::fromJSON(jp[1L])
stopifnot(isFALSE(res$extensions$arm$eligible))
stopifnot(grepl("スキップ", res$extensions$arm$reason))
stopifnot(isTRUE(res$warnings$practical_significance_low))

# Case 2: 存在しない --input は非ゼロ exit
st_missing <- suppressWarnings(system2(
  "Rscript",
  c(analysis, "--input", file.path(td, "missing.csv"), "--output_dir", file.path(td, "missing_out"))
))
stopifnot(!identical(as.integer(st_missing), 0L))

# Case 3: 明示的な空 --run-id は非ゼロ exit + 明示エラーメッセージ
out_empty_runid <- suppressWarnings(system2(
  "Rscript",
  c(
    analysis,
    "--input", csv,
    "--output_dir", file.path(td, "empty_runid"),
    "--run-id", ""
  ),
  stdout = TRUE,
  stderr = TRUE
))
st_empty_runid <- attr(out_empty_runid, "status")
if (is.null(st_empty_runid)) st_empty_runid <- 0L
stopifnot(!identical(as.integer(st_empty_runid), 0L))
stopifnot(grepl("無効な --run-id", paste(out_empty_runid, collapse = "\n"), fixed = TRUE))

message("OK: ARM skip + warning + CLI failure contracts")
