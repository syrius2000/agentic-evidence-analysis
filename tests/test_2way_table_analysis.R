# =============================================================================
# test_2way_table_analysis.R
# タスク 4.4 の検証テスト: 2元表データセットでの評価検証
# 不要な第3因子記号 C や 3元表定義が混入せず、M1/M2 のみが評価・表示されること
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(rmarkdown)
})

find_repo_root <- function() {
  curr <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(curr, ".agents"))) return(curr)
    curr <- dirname(curr)
  }
  getwd()
}
repo_root <- find_repo_root()
source(file.path(repo_root, "tests", "helpers", "pass0_test_helpers.R"))

test_that("タスク 4.4: 2元表データで M1/M2 のみが評価され、第3因子記号 C や 3元表定義が一切混入しない", {
  test_dir <- file.path(repo_root, "output/test_2way")
  if (dir.exists(test_dir)) unlink(test_dir, recursive = TRUE)
  dir.create(test_dir, recursive = TRUE)
  
  # 1. 2元表のテストデータ作成 (Gender × Admit: 4セル)
  ucb_raw <- read.csv(file.path(repo_root, "examples/ucb_admissions.csv"))
  df_2way <- aggregate(Freq ~ Gender + Admit, data = ucb_raw, FUN = sum)
  csv_path <- file.path(test_dir, "ucb_2way.csv")
  write.csv(df_2way, csv_path, row.names = FALSE)
  
  config_path <- make_pass0_test_config(
    "vcd-bayesian-evidence-analysis",
    csv_path,
    test_dir,
    "run_2way",
    vars = c("Gender", "Admit"),
    freq = "Freq",
    response_var = "Admit",
    repo_root = repo_root
  )

  # 2. analysis.R で 2元表分析を実行
  cmd_analysis <- sprintf(
    "Rscript %s --config %s",
    shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
    shQuote(config_path)
  )
  system(cmd_analysis, intern = TRUE)
  
  run_dirs <- list.dirs(test_dir, full.names = TRUE, recursive = FALSE)
  expect_true(length(run_dirs) >= 1L)
  run_dir <- run_dirs[1]
  json_path <- file.path(run_dir, "evidence_results.json")
  expect_true(file.exists(json_path))
  
  res_2way <- fromJSON(json_path)
  
  # 3. JSON 構造の検証
  # (a) 次元と因子マップ: 2次元、A, B のみ（C の混入なし）
  expect_identical(res_2way$models$dimension, 2L)
  expect_identical(names(res_2way$models$factor_map), c("A", "B"))
  expect_false("C" %in% names(res_2way$models$factor_map), info = "因子記号 C が存在しないこと")
  expect_identical(res_2way$models$factor_map$A$variable, "Gender")
  expect_identical(res_2way$models$factor_map$B$variable, "Admit")
  
  # (b) 定義辞書: M1, M2 のみ（M3〜M9 の混入なし）
  expect_identical(names(res_2way$models$definitions), c("M1", "M2"))
  expect_false(any(paste0("M", 3:9) %in% names(res_2way$models$definitions)), info = "M3〜M9 が混入しないこと")
  
  # (c) M1 / M2 の数理定義内容
  m1_def <- res_2way$models$definitions$M1
  expect_identical(m1_def$bracket_notation, "[A][B]")
  expect_identical(m1_def$bracket_expanded, "[Gender][Admit]")
  expect_identical(m1_def$fitted_formula, "Freq ~ Gender + Admit")
  expect_match(m1_def$independence$description_ja, "Gender.*と.*Admit.*は.*独立")
  
  m2_def <- res_2way$models$definitions$M2
  expect_identical(m2_def$bracket_notation, "[AB]")
  expect_identical(m2_def$bracket_expanded, "[Gender, Admit]")
  expect_identical(m2_def$fitted_formula, "Freq ~ Gender * Admit")
  expect_match(m2_def$independence$description_ja, "飽和モデル")
  
  # 3元表特有の表現が一切含まれないこと
  all_json_str <- toJSON(res_2way$models)
  expect_false(grepl("\\[AB\\]\\[C\\]", all_json_str))
  expect_false(grepl("\\[AB\\]\\[AC\\]", all_json_str))
  expect_false(grepl("\\[ABC\\]", all_json_str))
  
  # (d) モデルサマリー: 2行のみ（M1, M2 の集合）
  sum_df <- as.data.frame(res_2way$models$summary)
  expect_equal(nrow(sum_df), 2L)
  expect_true(setequal(sum_df$model_id, c("M1", "M2")))
  
  # 4. ダッシュボードの HTML レンダリング検証
  writeLines("# 2元表サマリー\n\n2元表テストです。", file.path(run_dir, "executive_summary.md"))
  dashboard_rmd <- file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
  
  rmarkdown::render(
    input = dashboard_rmd,
    output_file = "dashboard.html",
    output_dir = run_dir,
    params = list(output_dir = run_dir, require_pass2 = TRUE),
    quiet = TRUE
  )
  
  html_path <- file.path(run_dir, "dashboard.html")
  expect_true(file.exists(html_path))
  html_str <- paste(readLines(html_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  
  # 凡例に C が含まれないこと
  expect_match(html_str, "<strong>Gender</strong>")
  expect_match(html_str, "<strong>Admit</strong>")
  expect_false(grepl('<span class="factor-symbol-badge">C</span>', html_str), info = "HTML凡例にCが含まれないこと")
  
  # アコーディオンに M1, M2 のみ存在し M3〜M9 が存在しないこと
  expect_match(html_str, '<details id="model-detail-M1"', info = "M1 アコーディオンが存在すること")
  expect_match(html_str, '<details id="model-detail-M2"', info = "M2 アコーディオンが存在すること")
  expect_false(grepl('<details id="model-detail-M3"', html_str), info = "M3 アコーディオンが存在しないこと")
  
  # 不整合警告が出ていないこと
  expect_false(grepl("数理定義・入力整合性の警告", html_str), info = "不整合警告が表示されないこと")
  
  # クリーンアップ
  unlink(test_dir, recursive = TRUE)
})
