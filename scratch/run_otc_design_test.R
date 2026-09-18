# run_otc_design_test.R
# OTC_Q05_tidy.csv (10 Brand x 20 Symptom = 200 cells) のデザインテストと処理時間計測

suppressPackageStartupMessages({
  library(jsonlite)
  library(rmarkdown)
  library(digest)
})

find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:20) {
    p <- file.path(d, ".agents", "shared", "run_scope.R")
    if (file.exists(p)) return(d)
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  getwd()
}
repo_root <- find_agent_repo()

source(file.path(repo_root, ".agents", "shared", "dependency_check.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "validate_input.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "residual_diagnostics.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "effect_evidence_metrics.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "dirichlet_posterior.R"))
source(file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "R", "serializer_v3.R"))

check_r_dependencies(
  c("vcd", "gt", "DT", "htmlwidgets", "ggplot2", "jsonlite", "digest", "rmarkdown"),
  context = "OTC Design Benchmark"
)

out_dir <- file.path(repo_root, "skill_out", "vcd_categorical", "run_otc_q05_design_test")
if (dir.exists(out_dir)) {
  unlink(out_dir, recursive = TRUE)
}
dir.create(out_dir, recursive = TRUE)

cat("================================================================\n")
cat("OTC_Q05_tidy.csv デザインテスト & ベンチマーク実行開始\n")
cat("================================================================\n\n")

total_start <- proc.time()

# 1. データ読み込み
t0 <- proc.time()
csv_path <- file.path(repo_root, "examples", "OTC_Q05_tidy.csv")
raw_df <- read.csv(csv_path, stringsAsFactors = FALSE)
time_read <- (proc.time() - t0)["elapsed"]
cat(sprintf("[1/6] データ読み込み完了: %d 行 (所要時間: %.3f 秒)\n", nrow(raw_df), time_read))

# 2. 入力検証 & 集計
t0 <- proc.time()
v_data <- validate_input_table(
  data = raw_df,
  vars = c("Brand", "Symptom"),
  freq = "Freq",
  input_mode = "aggregated"
)
time_val <- (proc.time() - t0)["elapsed"]
cat(sprintf("[2/6] 入力検証完了: %d 水準 x %d 水準 = %d セル (所要時間: %.3f 秒)\n",
    length(unique(v_data$Brand)), length(unique(v_data$Symptom)), nrow(v_data), time_val))

# 3. 局所残差診断 & 効果量計算
t0 <- proc.time()
diag_res <- compute_residual_diagnostics(v_data)
evid_res <- compute_effect_evidence_metrics(diag_res)
time_stat <- (proc.time() - t0)["elapsed"]
cat(sprintf("[3/6] 残差診断・効果量計算完了 (所要時間: %.3f 秒)\n", time_stat))
cat(sprintf("      - Pearson Chi2: %.2f (p = %.3e, df = %d)\n", evid_res$chi_square, evid_res$p_value, evid_res$df))
cat(sprintf("      - Bias-corrected Cramer's V: %.4f (95%% CI: [%.4f, %.4f])\n",
    evid_res$cramers_v_corrected, evid_res$cramers_v_ci[1], evid_res$cramers_v_ci[2]))
cat(sprintf("      - 隔離セル数: %d / %d (%.1f%%)\n",
    sum(evid_res$cells_df$quarantine_status == "QUARANTINED"), nrow(evid_res$cells_df),
    100 * sum(evid_res$cells_df$quarantine_status == "QUARANTINED") / nrow(evid_res$cells_df)))

# 4. 多項 Dirichlet 事後推論 (主事前 alpha=0.5, 感度事前 alpha=1.0, 10,000 draws)
t0 <- proc.time()
input_sha <- digest::digest(file = csv_path, algo = "sha256")
sig <- digest::digest(paste0("otc_test_", input_sha), algo = "sha256")
post_res <- compute_dirichlet_posterior(
  diag_res,
  alpha = 0.5,
  n_draws = 10000L,
  analysis_signature = sig
)
time_bayes <- (proc.time() - t0)["elapsed"]
cat(sprintf("[4/6] ベイズ推論 (Dirichlet 10,000 draws + 感度分析) 完了 (所要時間: %.3f 秒)\n", time_bayes))

# 5. Interface 3.0 シリアライズ & 要約作成
t0 <- proc.time()
summary_text <- c(
  "# OTC_Q05 銘柄別頭痛症状の連関分析 (デザインテスト)",
  "",
  "## 全体連関構造",
  sprintf("- 自由度 %d における Pearson カイ二乗値は %.2f (p = %.2e) であり、銘柄と症状の間に極めて強い統計的連関が認められます。", evid_res$df, evid_res$chi_square, evid_res$p_value),
  sprintf("- バイアス補正済み Cramér's V は %.4f (95%% CI: [%.4f, %.4f]) であり、中程度の効果量を示します。",
          evid_res$cramers_v_corrected, evid_res$cramers_v_ci[1], evid_res$cramers_v_ci[2]),
  "",
  "## 局所セル診断と大標本 Dual-Filter",
  sprintf("- 全 %d セル中、%d セルが低期待度数またはゼロ度数により隔離セル (QUARANTINED) に指定されました。",
          nrow(evid_res$cells_df), sum(evid_res$cells_df$quarantine_status == "QUARANTINED")),
  "- 隔離セルを除外した上で、Rao スコア検定統計量と局所対数効果比に基づく Dual-Filter により、統計的証拠と実質的効果を併せ持つ特異な銘柄-症状組み合わせが特定されます。"
)
writeLines(summary_text, file.path(out_dir, "executive_summary.md"))

serialize_interface_v3(
  effect_result = evid_res,
  posterior_result = post_res,
  out_dir = out_dir,
  run_id = "run_otc_q05_design_test",
  analysis_signature = sig,
  input_sha256 = input_sha,
  config_sha256 = digest::digest("design_test_config", algo = "sha256"),
  execution_mode = "canonical"
)
time_serial <- (proc.time() - t0)["elapsed"]
cat(sprintf("[5/6] Interface 3.0 シリアライズ完了 (所要時間: %.3f 秒)\n", time_serial))

# 6. dashboard.Rmd の HTML レンダリング
t0 <- proc.time()
rmd_path <- file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis", "templates", "dashboard.Rmd")
html_path <- file.path(out_dir, "dashboard.html")

rmarkdown::render(
  input = rmd_path,
  output_file = html_path,
  params = list(output_dir = out_dir),
  quiet = TRUE
)
time_render <- (proc.time() - t0)["elapsed"]
cat(sprintf("[6/6] dashboard.html レンダリング完了 (所要時間: %.3f 秒)\n", time_render))

total_time <- (proc.time() - total_start)["elapsed"]

cat("\n================================================================\n")
cat("【処理時間サマリー】\n")
cat(sprintf("  1. CSV 読み込み:             %6.3f 秒 (%4.1f%%)\n", time_read, 100 * time_read / total_time))
cat(sprintf("  2. 入力検証 & 集計:          %6.3f 秒 (%4.1f%%)\n", time_val, 100 * time_val / total_time))
cat(sprintf("  3. 残差診断・効果量計算:     %6.3f 秒 (%4.1f%%)\n", time_stat, 100 * time_stat / total_time))
cat(sprintf("  4. ベイズ事後推論 (10,000回):%6.3f 秒 (%4.1f%%)\n", time_bayes, 100 * time_bayes / total_time))
cat(sprintf("  5. JSON/CSV シリアライズ:    %6.3f 秒 (%4.1f%%)\n", time_serial, 100 * time_serial / total_time))
cat(sprintf("  6. HTML ダッシュボード描画:  %6.3f 秒 (%4.1f%%)\n", time_render, 100 * time_render / total_time))
cat("  --------------------------------------------------------------\n")
cat(sprintf("  合計処理時間:                %6.3f 秒 (約 %.1f 秒)\n", total_time, total_time))
cat("================================================================\n\n")

# 生成物の検証チェック
html_content <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
file_size_kb <- file.info(html_path)$size / 1024

cat("【生成成果物の検証】\n")
cat(sprintf("  - ファイルパス: %s\n", html_path))
cat(sprintf("  - ファイルサイズ: %.1f KB\n", file_size_kb))

# 静的スキャン (正本契約 resource_load_patterns による外部通信・CDN・絶対パスの検査)
resource_load_patterns <- c(
  "<script[^>]+src=[\"'](https?:|//)",
  "<link[^>]+href=[\"'](https?:|//)",
  "<img[^>]+src=[\"'](https?:|//)",
  "<iframe[^>]+src=[\"'](https?:|//)",
  "@import\\s+[\"']?(https?:|//)",
  "url\\([\"']?(https?:|//)",
  "fetch\\s*\\([\"'](https?:|//)",
  "new\\s+XMLHttpRequest\\s*\\(",
  "language\\s*:\\s*\\{\\s*url",
  "cdn\\.datatables\\.net",
  "fonts\\.googleapis\\.com",
  "cdnjs\\.cloudflare\\.com",
  "cdn\\.jsdelivr\\.net",
  "mathjax",
  "(?:src|href)=[\"'](?:/Users/|/home/|/private/var/|[A-Za-z]:[\\/])",
  "url\\([\"']?(?:/Users/|/home/|/private/var/|[A-Za-z]:[\\/])"
)

detected_violations <- character(0)
for (pat in resource_load_patterns) {
  if (grepl(pat, html_content, ignore.case = TRUE)) {
    detected_violations <- c(detected_violations, pat)
  }
}

cat(sprintf("  - 外部アセット・通信ロード違反: %d 件 (%s)\n",
    length(detected_violations),
    if(length(detected_violations) == 0) "合格 (完全オフライン / Zero-External-Asset 達成)" else paste(detected_violations, collapse = ", ")))

# 各セクション・表示フォールバックの確認
has_sec12 <- grepl("glossary-accordion", html_content)
has_top25 <- grepl("上位 25 セルのみ表示", html_content) || grepl("上位 25 セル", html_content)
has_nature_theme <- grepl("#1F4D7A", html_content, ignore.case = TRUE)

cat(sprintf("  - NEJM/Nature Medical テーマ色 (#1F4D7A): %s\n", if(has_nature_theme) "検出 (適用済)" else "未検出"))
cat(sprintf("  - Section 12 用語集アコーディオン: %s\n", if(has_sec12) "検出 (設置済)" else "未検出"))
cat(sprintf("  - 大規模表 (K=200 > 100) Top-25 縮退ルール: %s\n", if(has_top25) "発動 (正常)" else "未発動"))

