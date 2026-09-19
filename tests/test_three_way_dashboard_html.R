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

tmp_run_dir <- file.path(tempdir(), paste0("test_html_", Sys.getpid()))
dir.create(tmp_run_dir, recursive = TRUE, showWarnings = FALSE)
for (f in list.files(fixture_dir, full.names = TRUE)) {
  # 失敗時にコピー済み旧HTMLを成功扱いしない
  if (identical(basename(f), "dashboard.html")) next
  file.copy(f, tmp_run_dir, overwrite = TRUE)
}

render_script <- file.path(repo_root, ".agents", "skills", "vcd-bayesian-evidence-analysis", "templates", "render_dashboard.R")
band_status <- system2(
  "Rscript",
  c(render_script, "--run-dir", tmp_run_dir, "--layout-variant", "band", "--output-file", "dashboard_band.html"),
  stdout = TRUE,
  stderr = TRUE
)
band_html_path <- file.path(tmp_run_dir, "dashboard_band.html")
if (!is.null(attr(band_status, "status")) && !identical(as.integer(attr(band_status, "status")), 0L)) {
  stop(paste(c("[ERROR] band render failed:", band_status), collapse = "\n"))
}

card_status <- system2(
  "Rscript",
  c(render_script, "--run-dir", tmp_run_dir, "--layout-variant", "card", "--output-file", "dashboard_card.html"),
  stdout = TRUE,
  stderr = TRUE
)
card_html_path <- file.path(tmp_run_dir, "dashboard_card.html")
if (!is.null(attr(card_status, "status")) && !identical(as.integer(attr(card_status, "status")), 0L)) {
  stop(paste(c("[ERROR] card render failed:", card_status), collapse = "\n"))
}

test_that("生成された HTML ファイルが存在すること", {
  expect_true(file.exists(html_path))
  expect_true(file.exists(band_html_path))
  expect_true(file.exists(card_html_path))
  expect_true(file.exists(json_path))
})

scan_offline <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  bad_tags <- grep("<(script|link)[^>]+(src|href)=[\"']https?://", lines, perl = TRUE, value = TRUE)
  expect_equal(length(bad_tags), 0L, info = paste(path, paste(bad_tags, collapse = "\n")))
  expect_false(any(grepl("cdn\\.jsdelivr\\.net/npm/mathjax", lines)))
  expect_false(any(grepl("MathJax\\.js", lines)))
  expect_false(any(grepl("cdn\\.datatables\\.net/plug-ins/.*/ja\\.json", lines)))
  expect_false(any(grepl("fonts\\.googleapis\\.com", lines)))
  expect_false(any(grepl("(?:src|href)=[\"'](?:/Users/|/home/)", lines)))
}

test_that("完全オフライン契約：外部CDN・Ajax・フォント取得URLが0件であること", {
  scan_offline(band_html_path)
  scan_offline(card_html_path)
})

test_that("因子凡例（A, B, C）と変数定義が一貫して表示されていること", {
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
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
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
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
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
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
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 条件付き割合セクション
  expect_true(grepl("条件付き割合と事後不確実性", content))
  expect_true(grepl("P\\(Admit = Admitted \\| Dept,\\s*Gender\\)", content))

  # 画像（ggplot2 のプロット埋め込み）が存在すること
  expect_true(grepl("<img [^>]*src=[\"']data:image/png;base64,", content))

  # 数値表（生割合、事後平均、95%CI）
  expect_true(grepl("事後平均", content))
  expect_true(grepl("95% ETI下限", content, fixed = TRUE))
})

test_that("旧 Evidence Score が監査専用として隔離表示されていること", {
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  # 監査専用表記
  expect_true(grepl("旧指標監査", content))
  expect_true(grepl("監査専用列として隔離", content))
  expect_true(grepl("Evidence Score = r", content))
})

test_that("統計指標解説セクションの数式（Score統計量など）がKaTeX静的HTMLとしてレンダリングされていること", {
  lines <- readLines(band_html_path, warn = FALSE, encoding = "UTF-8")
  content <- paste(lines, collapse = "\n")

  expect_false(grepl("\\$\\$T_i", content))
  expect_false(grepl("<span class=\"math display\">", content))
  expect_true(grepl("Leverage補正Score統計量", content))
  expect_true(grepl("katex-display", content))
})

test_that("共有用語集が旧α=1.0成果物をJeffreysと誤表示せず、DOMとして存在する", {
  for (path in c(band_html_path, card_html_path)) {
    content <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    expect_true(grepl("details class=\"glossary-accordion\"", content, fixed = TRUE), info = path)
    expect_true(grepl("#1f4d7a", content, fixed = TRUE), info = path)
    expect_true(grepl("#f6f8fb", content, fixed = TRUE), info = path)
    expect_true(grepl("データが登録されていません", content, fixed = TRUE), info = path)
    expect_false(grepl("主事前: 多項Jeffreys", content, fixed = TRUE), info = path)
    expect_true(grepl("未確認", content, fixed = TRUE) || grepl("α = 1.0", content, fixed = TRUE), info = path)
    sec <- sub(".*id=\"section-glossary\"", "", content)
    expect_false(grepl("<pre>", sec, fixed = TRUE), info = path)
  }
})

cat("\n==================================================\n")
cat("すべての HTML 契約テストが定義されました。実行を開始します。\n")
cat("==================================================\n\n")

test_that("新規主事前の90/95%ETIと希少確率が設定通りHTMLへ渡る", {
  source(file.path(repo_root,".agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R"),local=TRUE)
  data <- data.frame(A=paste0("a",1:5),B="b",C="c",Freq=c(0,1,30000,40000,50000))
  spec <- list(response_var="A",compare_by="B",stratify_by="C",
    numerator_levels=c("a1","a2"),denominator_levels=paste0("a",1:5))
  original <- jsonlite::fromJSON(json_path,simplifyVector=FALSE)
  for (level in c(.90,.95)) {
    spec$interval_level <- level
    modified <- original
    modified$conditional_rate_view <- compute_conditional_rate_view(data,c("A","B","C"),"Freq",spec,draws=10000,seed=77)
    jsonlite::write_json(modified,file.path(tmp_run_dir,"evidence_results.json"),auto_unbox=TRUE,digits=NA)
    target <- paste0("review_",level*100,".html")
    rendered <- system2("Rscript",c(render_script,"--run-dir",tmp_run_dir,"--preview","--output-file",target),stdout=TRUE,stderr=TRUE)
    expect_true(is.null(attr(rendered,"status")) || attr(rendered,"status")==0L)
    doc <- xml2::read_html(file.path(tmp_run_dir,target))
    content <- paste(readLines(file.path(tmp_run_dir,target),warn=FALSE),collapse="\n")
    expect_true(grepl(paste0(level*100,"% ETI下限 (%)"),content,fixed=TRUE))
    expect_false(grepl("95%CI",content,fixed=TRUE))
    expect_true(grepl(paste0(level*100,"% ETI)"),content,fixed=TRUE))
    expect_true(grepl("formatSignif",content,fixed=TRUE))
    widgets <- xml2::xml_text(xml2::xml_find_all(doc,"//script[@type='application/json'][@data-for]"))
    tables <- lapply(widgets,function(x) jsonlite::fromJSON(x,simplifyVector=FALSE)$x)
    rate_table <- Filter(function(x) !is.null(x$container) && grepl("ETI下限",x$container,fixed=TRUE),tables)
    expect_length(rate_table,1)
    expected <- modified$conditional_rate_view$rates[[1]]$post_mean*100
    expect_equal(as.numeric(rate_table[[1]]$data[[6]][[1]]),expected,tolerance=1e-10)
    expect_gt(as.numeric(rate_table[[1]]$data[[7]][[1]]),0)
    expect_equal(length(xml2::xml_find_all(doc,"//*[@id='section-glossary']//details")),4L)
    scan_offline(file.path(tmp_run_dir,target))
  }
})

# 一時ディレクトリのクリーンアップ
unlink(tmp_run_dir, recursive = TRUE)
