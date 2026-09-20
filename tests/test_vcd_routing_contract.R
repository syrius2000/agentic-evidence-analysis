# test_vcd_routing_contract.R — vcd 分析経路とcanonical入口の契約検査

test_pass <- 0L
test_fail <- 0L

read_utf8 <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
assert_contract <- function(ok, label) {
  if (isTRUE(ok)) {
    cat(sprintf("[PASS] %s\n", label))
    test_pass <<- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] %s\n", label))
    test_fail <<- test_fail + 1L
  }
}

skill <- read_utf8(".agents/skills/vcd-categorical-analysis/SKILL.md")
reference <- read_utf8(".agents/skills/vcd-categorical-analysis/Reference.md")
workflow <- read_utf8(".agents/skills/vcd-categorical-analysis/references/workflow.md")
legacy_report <- read_utf8(".agents/skills/vcd-categorical-analysis/templates/report.Rmd")
analysis_template <- read_utf8(".agents/skills/vcd-categorical-analysis/templates/analysis.R")

assert_contract(
  grepl("厳密に2", skill, fixed = TRUE) &&
    grepl("vcd-bayesian-evidence-analysis", skill, fixed = TRUE) &&
    grepl("INVALID_INPUT_ARITY", skill, fixed = TRUE),
  "2次元専用・3次元委譲・入力境界がSKILLに明記されている"
)

assert_contract(
  grepl("dashboard.Rmd", skill, fixed = TRUE) &&
    grepl("dashboard.Rmd", workflow, fixed = TRUE) &&
    grepl("レガシー", legacy_report, fixed = TRUE) &&
    grepl("現行canonical入口ではありません", legacy_report, fixed = TRUE),
  "dashboard.Rmdをcanonical入口、report.Rmdをレガシー入口として区別している"
)

assert_contract(
  grepl("調整標準化残差ヒートマップ", reference, fixed = TRUE) &&
    grepl("調整残差", reference, fixed = TRUE) &&
    grepl("局所診断", reference, fixed = TRUE),
  "2次元の主診断と確認すべき安定性情報がReferenceに記載されている"
)

assert_contract(
  !grepl("generate_plots", analysis_template, fixed = TRUE) &&
    !grepl("mosaic_", analysis_template, fixed = TRUE) &&
    !grepl("assoc_", analysis_template, fixed = TRUE),
  "canonical analysis.Rがモザイク・関連図PNGを生成しない"
)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0L) quit(status = 1L)
