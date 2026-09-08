# =============================================================================
# test_dashboard_fallbacks.R
# タスク 3.1〜3.4 の検証テスト: 旧JSON、内部不整合、適合失敗、MathJaxフォールバック
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
dashboard_rmd <- file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/dashboard.Rmd")

# 基準となるベース JSON を analysis.R で生成して読み込む（definitions, factor_map 完備）
temp_base_dir <- file.path(repo_root, "output/test_fallbacks/base_gen")
if (dir.exists(temp_base_dir)) unlink(temp_base_dir, recursive = TRUE)
cmd_analysis <- sprintf(
  "Rscript %s --input %s --vars Dept,Gender,Admit --freq Freq --response_var Admit --output_dir %s --run-id base_fallback",
  shQuote(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R")),
  shQuote(file.path(repo_root, "examples/ucb_admissions.csv")),
  shQuote(temp_base_dir)
)
system(cmd_analysis, intern = TRUE)

gen_run_dirs <- list.dirs(temp_base_dir, full.names = TRUE, recursive = FALSE)
stopifnot(length(gen_run_dirs) >= 1L)
baseline_json_path <- file.path(gen_run_dirs[1], "evidence_results.json")
stopifnot(file.exists(baseline_json_path))
base_data <- fromJSON(baseline_json_path, simplifyVector = FALSE)

# 補助関数: 指定した変形データでダッシュボードをレンダリングし HTML 文字列を返す
render_test_fixture <- function(fixture_data, test_id) {
  fixture_dir <- file.path(repo_root, "output/test_fallbacks", test_id)
  if (dir.exists(fixture_dir)) {
    unlink(fixture_dir, recursive = TRUE)
  }
  dir.create(fixture_dir, recursive = TRUE)
  fixture_dir <- normalizePath(fixture_dir, winslash = "/", mustWork = TRUE)
  
  json_file <- file.path(fixture_dir, "evidence_results.json")
  writeLines(toJSON(fixture_data, auto_unbox = TRUE, pretty = TRUE), json_file)
  
  summ_file <- file.path(fixture_dir, "executive_summary.md")
  writeLines("# テスト用サマリー\n\nフォールバック検証用です。", summ_file)
  
  html_out <- file.path(fixture_dir, "dashboard.html")
  rmarkdown::render(
    input = dashboard_rmd,
    output_file = "dashboard.html",
    output_dir = fixture_dir,
    params = list(output_dir = fixture_dir, require_pass2 = TRUE),
    quiet = TRUE
  )
  
  expect_true(file.exists(html_out))
  paste(readLines(html_out, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

# -----------------------------------------------------------------------------
# タスク 3.1: 旧 JSON 入力に対するフォールバック
# -----------------------------------------------------------------------------
test_that("タスク 3.1: 旧 JSON (definitions未収録) 入力時にクラッシュせず、導出凡例と未収録表示が行われる", {
  d_legacy <- base_data
  # definitions, factor_map, notation_version を削除して旧仕様化
  d_legacy$models$definitions <- NULL
  d_legacy$models$factor_map <- NULL
  d_legacy$models$notation_version <- NULL
  
  html_str <- render_test_fixture(d_legacy, "legacy_json")
  
  # 1. 変数凡例が変数順序から導出され、注記が表示される
  expect_match(html_str, "本データは旧JSON仕様のため、変数順序より導出しています", info = "旧JSON導出注記が表示されること")
  expect_match(html_str, "Dept", info = "導出された凡例に実変数が含まれること")
  
  # 2. 主要指標カードで「数学的定義未収録（仮定推測なし）」と表示される
  expect_match(html_str, "数学的定義未収録（仮定推測なし）", info = "主要カードで未保存定義を推測補完しないこと")
  
  # 3. 詳細アコーディオン内部で「数学的定義未収録」と表示される
  expect_match(html_str, "数学的定義未収録</strong>:\\s*本モデルの数理定義", info = "アコーディオン内部で未収録表示されること")
})

# -----------------------------------------------------------------------------
# タスク 3.2: 適合結果未収録 & 内部不整合ハンドリング
# -----------------------------------------------------------------------------
test_that("タスク 3.2: 適合結果未収録モデルに対し「適合結果未収録」が表示される", {
  d_missing_fit <- base_data
  # models$summary から M3 を除去（定義はあるが適合結果が未収録）
  d_missing_fit$models$summary <- Filter(function(m) m$model_id != "M3", d_missing_fit$models$summary)
  
  html_str <- render_test_fixture(d_missing_fit, "missing_fit")
  
  expect_match(html_str, '<details id="model-detail-M3"', info = "M3 のアコーディオンは定義に基づき生成されること")
  expect_match(html_str, "適合結果未収録", info = "M3 のステータスバッジに適合結果未収録が表示されること")
  expect_match(html_str, "適合数値: 未収録", info = "M3 の詳細内部に適合数値未収録が表示されること")
})

test_that("タスク 3.2: 内部不整合データ（次元不一致、参照不正、式不一致）に対し警告が表示され仮定が保留される", {
  # 1. 次元と変数の不一致
  d_dim_mismatch <- base_data
  d_dim_mismatch$models$dimension <- 2L  # 入力変数は3つ
  html_dim <- render_test_fixture(d_dim_mismatch, "dim_mismatch")
  expect_match(html_dim, "数理定義・入力整合性の警告", info = "不整合警告ボックスが表示されること")
  expect_match(html_dim, "モデル次元 \\(2\\) と入力変数数 \\(3\\) が一致しません", info = "次元不一致理由が表示されること")
  expect_match(html_dim, "内部不整合（仮定保留）", info = "主要指標カードで仮定が保留されること")
  expect_false(grepl('class="model-detail-accordion" open', html_dim), info = "不整合時は初期自動展開されないこと")
  
  # 2. best_model_id の参照不正
  d_bad_best <- base_data
  d_bad_best$models$best_model_id <- "M99"
  html_bad_best <- render_test_fixture(d_bad_best, "bad_best_model")
  expect_match(html_bad_best, "最良モデル M99 がモデル比較サマリー表に存在しません", info = "参照不正警告が表示されること")
  expect_match(html_bad_best, "内部不整合（仮定保留）", info = "主要カードで仮定保留されること")
  
  # 3. 2元表データに因子記号 C が混入
  d_c_in_2way <- base_data
  d_c_in_2way$models$dimension <- 2L
  d_c_in_2way$input_summary$variables <- c("Gender", "Admit")
  d_c_in_2way$models$factor_map$C <- list(symbol = "C", variable = "Extra", label = "Extra")
  html_c_in_2way <- render_test_fixture(d_c_in_2way, "c_in_2way")
  expect_match(html_c_in_2way, "2元表データですが因子記号Cが定義に含まれています", info = "2元表C混入警告が表示されること")
  
  # 4. 実適合式と定義適合式の不一致
  d_formula_mismatch <- base_data
  # models$summary に formula 列を追加して不一致を発生させる
  d_formula_mismatch$models$summary <- lapply(d_formula_mismatch$models$summary, function(m) {
    if (m$model_id == "M1") {
      m$formula <- "Freq ~ Dept + Gender + Admit + Dept:Gender:Admit"  # 飽和モデルの式を故意に設定
    }
    m
  })
  html_formula_mismatch <- render_test_fixture(d_formula_mismatch, "formula_mismatch")
  expect_match(html_formula_mismatch, "モデル M1 の記録適合式.*と数理定義の適合式.*が一致しません", info = "適合式不一致警告が表示されること")
})

# -----------------------------------------------------------------------------
# タスク 3.3: 記録済み適合失敗 & 未知バージョンのハンドリング
# -----------------------------------------------------------------------------
test_that("タスク 3.3: 記録済み適合失敗データに対し保存された理由が表示され通常順位付けと分離される", {
  d_failed <- base_data
  # M2 を適合失敗として記録
  d_failed$models$summary <- lapply(d_failed$models$summary, function(m) {
    if (m$model_id == "M2") {
      m$status <- "FAILED"
      m$error_message <- "収束不良: Fisher Scoringが反復上限に到達"
      m$deviance <- NA_real_
      m$bic <- NA_real_
    } else {
      m$status <- "SUCCESS"
      m$error_message <- ""
    }
    m
  })
  
  html_failed <- render_test_fixture(d_failed, "failed_fit")
  
  expect_match(html_failed, "適合失敗:\\s*収束不良: Fisher Scoringが反復上限に到達", info = "アコーディオンタイトルに失敗理由が表示されること")
  expect_match(html_failed, "適合状態:\\s*評価失敗.*理由:\\s*収束不良.*通常のモデル順位付けから除外されています", info = "詳細内部に除外警告が表示されること")
})

test_that("タスク 3.3: 未知の notation_version (2.0.0) に対し警告が表示され安全に処理される", {
  d_unknown_ver <- base_data
  d_unknown_ver$models$notation_version <- "2.0.0"
  
  html_unknown_ver <- render_test_fixture(d_unknown_ver, "unknown_ver")
  
  expect_match(html_unknown_ver, "未知の notation_version です: 2.0.0", info = "未知バージョン警告が表示されること")
  expect_match(html_unknown_ver, "内部不整合（仮定保留）", info = "安全のため仮定保留されること")
})

# -----------------------------------------------------------------------------
# タスク 3.4: MathJaxフォールバック・スクリプト連携・狭小画面対応
# -----------------------------------------------------------------------------
test_that("タスク 3.4: MathJax非依存の判読性、JSのtypesetPromise連携、レスポンシブスタイルが存在する", {
  html_base <- render_test_fixture(base_data, "mathjax_fallback")
  
  # 1. MathJax が無効でも判読可能な等幅ブラケット表記と日本語解説
  expect_match(html_base, "<code>\\[AB\\]\\[AC\\]</code>", info = "静的HTMLに等幅ブラケット表記が含まれること")
  expect_match(html_base, "条件付き独立", info = "静的HTMLに日本語構造説明が含まれること")
  
  # 2. JavaScript でアコーディオン展開時に MathJax.typesetPromise が呼ばれる連携コード
  expect_match(html_base, "window.MathJax.typesetPromise", info = "typesetPromise 連携コードが含まれていること")
  
  # 3. 狭小画面向けのレスポンシブスタイル
  expect_match(html_base, "@media \\(max-width: 768px\\)", info = "768px レスポンシブメディアクエリが含まれること")
  expect_match(html_base, "\\.factor-legend-list \\{\\s*flex-direction: column;", info = "凡例の縦並びスタイルが含まれること")
})

# 一時出力ディレクトリのクリーンアップ
if (dir.exists(file.path(repo_root, "output/test_fallbacks"))) {
  unlink(file.path(repo_root, "output/test_fallbacks"), recursive = TRUE)
}
