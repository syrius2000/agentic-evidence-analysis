#!/usr/bin/env Rscript
# tests/test_pass2_stub_no_legacy_score.R
# pass2_stub.R の出力 executive_summary.md に「Evidence Score」による偏り記述が無く、
# 現行のセル診断用語（Residual / 局所セル診断）が使用されていることを検証する。

root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agents")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
stub_script <- file.path(root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R")

tmp <- tempfile("pass2_stub_legacy_score_test_")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

json_path <- file.path(tmp, "evidence_results.json")
out_path <- file.path(tmp, "executive_summary.md")

json_content <- '{
  "dataset_name": "test_legacy_check",
  "dimensions": ["A", "B"],
  "n_total": 1000,
  "bf_independence": "1.5e10",
  "log_n": 6.9077,
  "threshold": 6.9077,
  "cramers_v": 0.25,
  "top_k_data": [
    {"A": "a1", "B": "b1", "Freq": 50, "Expected": 10, "Residual": 4.0, "Evidence_Score": 10.0}
  ],
  "warnings": []
}'
writeLines(json_content, json_path)

status <- system2("Rscript", c(stub_script, "--json", json_path, "--output", out_path))
if (status != 0L) {
  stop("[FAIL] pass2_stub.R failed to execute")
}

if (!file.exists(out_path)) {
  stop("[FAIL] executive_summary.md not created")
}

md <- readLines(out_path, encoding = "UTF-8")
md_text <- paste(md, collapse = "\n")

# 「Evidence Score」または「Evidence Score > 0」の文言が残存していないこと
if (grepl("Evidence Score", md_text, ignore.case = FALSE)) {
  stop(sprintf("[FAIL] Output markdown still contains legacy 'Evidence Score':\n%s", md_text))
}

# 「Residual」の文言・指標が含まれていること
if (!grepl("Residual", md_text, ignore.case = FALSE)) {
  stop(sprintf("[FAIL] Output markdown missing 'Residual' phrasing:\n%s", md_text))
}

cat("[PASS] test_pass2_stub_no_legacy_score.R: No legacy 'Evidence Score' phrasing found and 'Residual' confirmed in stub output.\n")
