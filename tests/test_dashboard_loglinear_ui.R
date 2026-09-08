# =============================================================================
# test_dashboard_loglinear_ui.R
# タスク 2.1〜2.5 の検証テスト: dashboard.Rmd の HTML レンダリングと UI 構造
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(rmarkdown)
  library(jsonlite)
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

test_that("タスク 2.1〜2.5: dashboard.Rmd が正常にレンダリングされ、凡例・6列表・アコーディオン・JSが含まれる", {
  test_out_dir <- file.path(repo_root, "output/test_dashboard_render")
  if (dir.exists(test_out_dir)) {
    unlink(test_out_dir, recursive = TRUE)
  }
  
  # 1. analysis.R でテスト用 run を生成
  cmd_analysis <- sprintf(
    "Rscript %s --input %s --vars Dept,Gender,Admit --freq Freq --response_var Admit --output_dir %s --run-id render_test",
    shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
    shQuote(file.path(repo_root, "examples/ucb_admissions.csv")),
    shQuote(test_out_dir)
  )
  system(cmd_analysis, intern = TRUE)
  
  run_dirs <- list.dirs(test_out_dir, full.names = TRUE, recursive = FALSE)
  expect_true(length(run_dirs) >= 1L)
  run_dir <- run_dirs[1]
  
  # 2. 仮の executive_summary.md を配置
  summ_file <- file.path(run_dir, "executive_summary.md")
  writeLines("# テスト用 AI エグゼクティブ・サマリー\n\nモデル評価の検証用ダッシュボードです。", summ_file)
  
  # 3. rmarkdown::render で dashboard.Rmd をレンダリング
  dashboard_rmd <- file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")
  html_out <- file.path(run_dir, "dashboard.html")
  
  rmarkdown::render(
    input = dashboard_rmd,
    output_file = "dashboard.html",
    output_dir = run_dir,
    params = list(output_dir = run_dir, require_pass2 = TRUE),
    quiet = TRUE
  )
  
  expect_true(file.exists(html_out), info = "dashboard.html が正常に出力されたこと")
  
  html_content <- paste(readLines(html_out, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  
  # タスク 2.1 検証: 変数凡例ボックスと水準名との違い注記
  expect_match(html_content, "factor-legend-box", info = "凡例ボックスクラスが存在すること")
  expect_match(html_content, "変数定義と因子記号の対応凡例", info = "凡例見出しが存在すること")
  expect_match(html_content, "Dept", info = "実変数 Dept が凡例に含まれること")
  expect_match(html_content, "Gender", info = "実変数 Gender が凡例に含まれること")
  expect_match(html_content, "Admit", info = "実変数 Admit が凡例に含まれること")
  expect_match(html_content, "カテゴリの水準名.*と.*因子記号.*は異なります", info = "水準名と記号の違い注記が存在すること")
  
  # タスク 2.2 検証: 主要指標カードでの構造仮定表示
  expect_match(html_content, "最良モデル \\(明示式BIC\\)", info = "主要指標カードが存在すること")
  expect_match(html_content, "Dept.*で層別したとき.*Gender.*と.*Admit.*は条件付き独立", info = "M5 の構造仮定がカードに明記されていること")
  
  # タスク 2.3 検証: ブラケット解説・BIC注記・6列DT表
  expect_match(html_content, "記法の見方とモデル選択基準", info = "ブラケット解説が存在すること")
  expect_match(html_content, "生成クラス（ブラケット記法）", info = "生成クラス解説が存在すること")
  expect_match(html_content, "明示式BIC", info = "明示式BIC解説が存在すること")
  expect_match(html_content, "相対評価の原則", info = "相対評価原則が存在すること")
  expect_match(html_content, "モデルと仮定", info = "6列表のヘッダー1が存在すること")
  expect_match(html_content, "生成クラス", info = "6列表のヘッダー2が存在すること")
  expect_match(html_content, "残差自由度", info = "6列表のヘッダー3が存在すること")
  expect_match(html_content, "逸脱度", info = "6列表のヘッダー4が存在すること")
  expect_match(html_content, "BIC", info = "6列表のヘッダー5が存在すること")
  expect_match(html_content, "ΔBIC", info = "6列表のヘッダー6が存在すること")
  
  # タスク 2.4 検証: DT 表直下の候補モデル詳細アコーディオン (<details>)
  expect_match(html_content, "model-detail-accordion", info = "アコーディオンが存在すること")
  expect_match(html_content, '<details id="model-detail-M5" class="model-detail-accordion" open>', info = "M5 のみ open 属性が付与されていること")
  expect_match(html_content, '<details id="model-detail-M1" class="model-detail-accordion">', info = "M1 は閉じていること")
  expect_match(html_content, "ポアソン対数線形回帰式", info = "LaTeX数式見出しが存在すること")
  
  # タスク 2.5 検証: openModelDetail の JavaScript
  expect_match(html_content, "function openModelDetail", info = "openModelDetail 関数が定義されていること")
  expect_match(html_content, "heading.focus()", info = "フォーカス移動処理が含まれていること")
  
  # クリーンアップ
  unlink(test_out_dir, recursive = TRUE)
})
