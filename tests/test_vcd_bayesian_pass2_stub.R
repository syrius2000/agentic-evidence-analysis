#!/usr/bin/env Rscript
# tests/test_vcd_bayesian_pass2_stub.R
# TDD RED: pass2_stub.R が存在し、JSONからexecutive_summary.mdを生成できることを確認
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
stub_script <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R")

pass <- 0L; fail <- 0L

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    cat(sprintf("[PASS] %s\n", label))
    pass <<- pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", label))
    fail <<- fail + 1L
  }
}

check("pass2_stub.R exists", file.exists(stub_script))

# JSONを準備
tmp <- tempfile("pass2_stub_test_")
dir.create(tmp)
json_path <- file.path(tmp, "evidence_results.json")
out_path <- file.path(tmp, "executive_summary.md")

json_content <- '{
  "dataset_name": "test",
  "dimensions": ["A", "B"],
  "n_total": 1000,
  "bf_independence": "1.5e10",
  "log_n": 6.9077,
  "threshold": 6.9077,
  "cramers_v": 0.25,
  "top_k_data": [
    {"A": "a1", "B": "b1", "Freq": 50, "Expected": 10, "Residual": 4.0, "Evidence_Score": 10.0}
  ],
  "warnings": ["Cramér\'s V is Small (0.25 < 0.3)"]
}'
writeLines(json_content, json_path)

if (file.exists(stub_script)) {
  status <- system2("Rscript", c(stub_script, "--json", json_path, "--output", out_path))
  check("pass2_stub.R executes successfully", status == 0L)
  check("executive_summary.md created", file.exists(out_path))
  if (file.exists(out_path)) {
    md <- readLines(out_path)
    md_text <- paste(md, collapse = "\n")
    check("Contains stub warning", grepl("スタブ生成", md_text) || grepl("LLM未使用", md_text))
    check("Contains Cramér's V", grepl("0.25", md_text))
    check("Contains Top-K cell", grepl("a1", md_text))
  }
}

unlink(tmp, recursive = TRUE)

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  quit(status = 1L)
} else {
  quit(status = 0L)
}
