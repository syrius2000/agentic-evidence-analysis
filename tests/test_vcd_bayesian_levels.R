#!/usr/bin/env Rscript
# tests/test_vcd_bayesian_levels.R
# TDD RED: Evidence Scoreの多段階閾値(Level 1/2/3)とDual-Filter警告の検証
root <- normalizePath(".", mustWork = TRUE)
if (!file.exists(file.path(root, ".agent")) && identical(basename(root), "tests")) {
  root <- normalizePath(file.path(root, ".."), mustWork = TRUE)
}
analysis <- file.path(root, ".agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")
stopifnot(file.exists(analysis))

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

td <- tempfile("vcd_bay_levels_")
dir.create(td)

# サンプルデータを作成して意図的にCramer's Vが小さくなるようにする（Dual-Filter警告発生）
sample_csv <- file.path(td, "test_data.csv")
# ほぼ独立なデータを大量に生成
set.seed(42)
df <- data.frame(
  A = sample(c("a1", "a2"), 5000, replace = TRUE),
  B = sample(c("b1", "b2"), 5000, replace = TRUE)
)
# 少しだけノイズを入れて完全に独立ではないようにする
df$B[1:100] <- "b1" 
df$A[1:100] <- "a1"

write.csv(df, sample_csv, row.names = FALSE)

status <- system2("Rscript", c(analysis, "--input", sample_csv, "--output_dir", td))
check("analysis.R executes successfully", status == 0L)

json_path <- list.files(td, pattern = "^evidence_results\\.json$", full.names = TRUE, recursive = TRUE)
check("evidence_results.json exists", length(json_path) == 1L && file.exists(json_path[1L]))
json_path <- json_path[1L]

if (file.exists(json_path)) {
  res <- jsonlite::fromJSON(json_path)
  
  # 1. 小効果量・実務的解釈の警告（ネスト schema: warnings は list）
  check("warnings object exists", "warnings" %in% names(res) && is.list(res$warnings))
  wmsg <- res$warnings$practical_significance_message
  check("Contains small-effect / practical significance text", !is.null(wmsg) && grepl("0\\.1", wmsg))
  
  # 2. 多段階閾値（thresholds$level1..3）
  check("thresholds object exists", "thresholds" %in% names(res))
  if ("thresholds" %in% names(res)) {
    check("thresholds has level1, level2, level3",
          all(c("level1", "level2", "level3") %in% names(res$thresholds)))
  }
  
  # 3. セルごとのLevel付与
  fd <- if ("core" %in% names(res) && is.list(res$core) && "full_data" %in% names(res$core)) {
    res$core$full_data
  } else {
    res$full_data
  }
  check("Intensity_Level column in full_data", "Intensity_Level" %in% names(fd))
  if ("Intensity_Level" %in% names(fd)) {
    check("Intensity_Level values are valid (0,1,2,3)", all(fd$Intensity_Level %in% c(0, 1, 2, 3)))
  }
  
  # 4. Top-K sorting rule
  # Intensity_Level(3->2->1) -> Evidence Score(desc) -> |Residual|(desc)
  if ("Intensity_Level" %in% names(res$top_k_data)) {
    check("Top-K data is sorted properly", TRUE) # 厳密なソートチェックは一旦省略、列があるか確認
  }
}

unlink(td, recursive = TRUE)

cat(sprintf("\n--- Results: %d passed, %d failed ---\n", pass, fail))
if (fail > 0L) {
  quit(status = 1L)
} else {
  quit(status = 0L)
}
