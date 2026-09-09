# tests/test_vcd_bayesian_topk.R
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, ".agents")) && basename(root) == "tests") {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
source(file.path(root, "tests", "helpers", "pass0_test_helpers.R"))
stopifnot(file.exists(analysis))

# Top-K = 3 で実行
td <- tempfile("vcd_bay_topk_")
dir.create(td)
config <- make_pass0_test_config(
  "vcd-bayesian-evidence-analysis",
  file.path(root, "examples", "titanic.csv"),
  td,
  "topk_test",
  vars = c("Class", "Sex", "Survived"),
  freq = "Freq",
  response_var = "Survived",
  repo_root = root
)
config_data <- jsonlite::read_json(config, simplifyVector = FALSE)
config_data$top_k <- 3L
jsonlite::write_json(config_data, config, auto_unbox = TRUE, pretty = TRUE)
status <- system2("Rscript", c(analysis, "--config", config))
stopifnot(identical(as.integer(status), 0L))

jp <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
stopifnot(length(jp) == 1L)
run_dir <- dirname(jp[1L])
dt_fixed <- file.path(run_dir, "dt_table.html")
stopifnot(file.exists(dt_fixed))
stopifnot(identical(dirname(jp[1L]), dirname(dt_fixed)))
res <- jsonlite::fromJSON(jp[1L])

# top_k_data が 3 行
stopifnot(nrow(res$top_k_data) == 3)

# full_data は全セル（32行: HairEyeColor）
stopifnot(nrow(res$full_data) == 32)

# top_k 値が 3
stopifnot(res$top_k == 3)

# dt_table.html は JSON と同一 run ディレクトリ（非再帰で run_dir 直下に両方）
stopifnot(file.exists(file.path(run_dir, "evidence_results.json")))
stopifnot(file.exists(file.path(run_dir, "dt_table.html")))
dt <- list.files(run_dir, pattern = "^dt_table\\.html$", full.names = TRUE, recursive = FALSE)
stopifnot(length(dt) == 1L && file.exists(dt[1L]))

unlink(td, recursive = TRUE)
message("OK: top_k extraction works")
