#!/usr/bin/env Rscript
# =============================================================================
# tests/test_three_way_dashboard_html.R
# 3次元ダッシュボード HTML の静的構造・完全オフライン性・契約整合性テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(xml2)
})

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
fixture_dir <- file.path(repo_root, "tests", "fixtures", "dashboard_ui", "ucb_admissions_three_way_v1")
html_path <- file.path(fixture_dir, "dashboard.html")
json_path <- file.path(fixture_dir, "evidence_results.json")

# 動的レイアウト分岐検証用の tempdir
tmp_run_dir <- file.path(tempdir(), paste0("test_html_", Sys.getpid()))
dir.create(tmp_run_dir, recursive = TRUE, showWarnings = FALSE)
for (f in list.files(fixture_dir, full.names = TRUE)) {
  file.copy(f, tmp_run_dir, overwrite = TRUE)
}

render_script <- file.path(repo_root, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "render_dashboard.R")
system2("Rscript", c(render_script, "--run-dir", tmp_run_dir, "--layout-variant", "band"), stdout = FALSE, stderr = FALSE)
band_html_path <- file.path(tmp_run_dir, "dashboard_band.html")
file.copy(file.path(tmp_run_dir, "dashboard.html"), band_html_path, overwrite = TRUE)

system2("Rscript", c(render_script, "--run-dir", tmp_run_dir, "--layout-variant", "card"), stdout = FALSE, stderr = FALSE)
card_html_path <- file.path(tmp_run_dir, "dashboard_card.html")
file.rename(file.path(tmp_run_dir, "dashboard.html"), card_html_path)

test_that("生成された HTML ファイルが存在すること", {
  expect_true(file.exists(html_path))
  expect_true(file.exists(band_html_path))
  expect_true(file.exists(card_html_path))
  expect_true(file.exists(json_path))
})

test_that("完全オフライン契約：外部CDN・Ajax・フォント取得URLが0件であること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")

  # script タグおよび link タグでの外部 http(s) URL
  bad_tags <- grep("<(script|link)[^>]+(src|href)=[\"']https?://", lines, perl = TRUE, value = TRUE)
  expect_equal(length(bad_tags), 0L, info = paste(bad_tags, collapse = "\n"))

  # MathJax CDN 参照が一切ないこと
  expect_false(any(grepl("cdn\\.jsdelivr\\.net/npm/mathjax", lines)))
  expect_false(any(grepl("MathJax\\.js", lines)))

  # DataTables 外部 ja.json CDN 参照がないこと
  expect_false(any(grepl("cdn\\.datatables\\.net/plug-ins/.*/ja\\.json", lines)))

  # 外部 Google Fonts 参照がないこと
  expect_false(any(grepl("fonts\\.googleapis\\.com", lines)))
})

test_that("因子凡例（A, B, C）と変数定義が一貫して表示されていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 因子記号と変数名
  expect_true(grepl("factor-symbol-badge.*>A<", content))
  expect_true(grepl("factor-symbol-badge.*>B<", content))
  expect_true(grepl("factor-symbol-badge.*>C<", content))
  expect_true(grepl("Dept", content))
  expect_true(grepl("Gender", content))
  expect_true(grepl("Admit", content))
  expect_true(grepl("応答変数", content))
})

test_that("最良モデル表示：案A (band) と 案B (card) の分岐表示が正しいこと", {
  band_lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
  band_content <- paste(band_lines, collapse = "\n")
  expect_true(grepl('class="best-model-band"', band_content))
  expect_false(grepl('class="best-model-card"', band_content))
  expect_true(grepl("M5", band_content))
  expect_true(grepl("332\\.31", band_content))
  expect_true(grepl("相対評価の原則", band_content))

  card_lines <- readLines(card_html_path, warn = FALSE, encoding = "UTF-8")
  card_content <- paste(card_lines, collapse = "\n")
  expect_true(grepl('class="best-model-card"', card_content))
  expect_false(grepl('class="best-model-band"', card_content))
  expect_true(grepl("M5", card_content))
  expect_true(grepl("332\\.31", card_content))
  expect_true(grepl("相対評価の原則", card_content))
})

test_that("対数線形モデル比較表が BIC 昇順初期ソートおよび列ソート可能に設定されていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # DataTables の ordering オプションが有効であること
  expect_true(grepl("\"ordering\":true", content) || grepl("\"order\":\\[\\[4,\"asc\"\\]\\]", content))

  # M5 と M8 の明示式 BIC 数値が含まれていること
  expect_true(grepl("332\\.31", content))
  expect_true(grepl("339\\.20", content) || grepl("339\\.19", content) || grepl("339\\.1982", content))

  # ポアソン明示式 BIC の数式解説が含まれていること
  expect_true(grepl("BIC = -2", content) || grepl("ln L", content) || grepl("log L", content) || grepl("katex", content))
})

test_that("セル診断が基準モデル別タブ（M1 vs M5）で分離され、分母付き件数が表示されていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # タブ切り替えボタン
  expect_true(grepl("btn-tab-M1", content))
  expect_true(grepl("btn-tab-M5", content))
  expect_true(grepl("pane-tab-M1", content))
  expect_true(grepl("pane-tab-M5", content))

  # M1基準の分母付き件数
  expect_true(grepl("M1基準", content))
  expect_true(grepl("24 / 24", content)) # 評価対象

  # M5基準の分母付き件数（REGULAR=13, QUARANTINED=11, candidate=1）
  expect_true(grepl("M5基準", content))
  expect_true(grepl("13 / 24", content)) # 安定セル
  expect_true(grepl("11 / 24", content)) # 隔離セル
  expect_true(grepl("1 / 24", content))  # 探索候補セル

  # 合算エビデンス率の禁止注記
  expect_true(grepl("合算した単一のエビデンス率は定義されません", content))
})

test_that("条件付き割合（conditional_rate_view）が点・区間図と数値表で表示されていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 条件付き割合セクション
  expect_true(grepl("条件付き割合と事後不確実性", content))
  expect_true(grepl("P\\(Admit = Admitted \\| Dept,\\s*Gender\\)", content))

  # 画像（ggplot2 のプロット埋め込み）が存在すること
  expect_true(grepl("<img [^>]*src=[\"']data:image/png;base64,", content))

  # 数値表（生割合、事後平均、95%CI）
  expect_true(grepl("事後平均", content))
  expect_true(grepl("95%CI", content))
})

test_that("旧 Evidence Score が監査専用として隔離表示されていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 監査専用表記
  expect_true(grepl("旧指標監査", content))
  expect_true(grepl("監査専用列として隔離", content))
  expect_true(grepl("Evidence Score = r", content))
})

test_that("統計指標解説セクションの数式（Score統計量など）がKaTeX静的HTMLとしてレンダリングされていること", {
  lines <- readLines(html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 生の未レンダリング TeX 表記（$$ や raw math display）が残っていないこと
  expect_false(grepl("\\$\\$T_i", content))
  expect_false(grepl("<span class=\"math display\">", content))

  # KaTeX レンダリング結果が含まれていること
  expect_true(grepl("Leverage補正Score統計量", content))
  expect_true(grepl("katex-display", content))
})

cat("\n==================================================\n")
cat("すべての HTML 契約テストが定義されました。実行を開始します。\n")
cat("==================================================\n\n")

# 一時ディレクトリのクリーンアップ
unlink(tmp_run_dir, recursive = TRUE)
