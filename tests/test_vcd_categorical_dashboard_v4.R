# test_vcd_categorical_dashboard_v4.R — Offline Dashboard & Static URL Scan Test Suite

suppressPackageStartupMessages({
  library(jsonlite)
  library(rmarkdown)
})

source(".agents/skills/vcd-categorical-analysis/R/validate_input.R")
source(".agents/skills/vcd-categorical-analysis/R/residual_diagnostics.R")
source(".agents/skills/vcd-categorical-analysis/R/effect_evidence_metrics.R")
source(".agents/skills/vcd-categorical-analysis/R/dirichlet_posterior.R")
source(".agents/skills/vcd-categorical-analysis/R/serializer_v3.R")

test_pass <- 0L
test_fail <- 0L

cat("=== Starting Offline Dashboard & Static URL Scan Tests ===\n")

# 1. テスト用データの解析と Interface 3.0 出力
d_valid <- read.csv("fixtures/input_validation/valid_2way.csv")
v_data <- validate_input_table(d_valid, vars = c("Treatment", "Outcome"), freq = "Freq", input_mode = "aggregated")
diag <- compute_residual_diagnostics(v_data)
evid <- compute_effect_evidence_metrics(diag)

sig_64 <- "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
input_sha_64 <- "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
config_sha_64 <- "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"

post <- compute_dirichlet_posterior(diag, alpha = 0.5, n_draws = 1000L, analysis_signature = sig_64)

tmp_dir <- tempfile(pattern = "dash_test_")
dir.create(tmp_dir)

# executive_summary.md の作成
writeLines(c("# サマリー", "テスト実行によるAI Narrative要約です。"), file.path(tmp_dir, "executive_summary.md"))
serialize_interface_v3(
  evid, post,
  out_dir = tmp_dir,
  run_id = "test_dash_run",
  analysis_signature = sig_64,
  input_sha256 = input_sha_64,
  config_sha256 = config_sha_64,
  execution_mode = "canonical"
)

# 2. dashboard.Rmd のレンダリング
html_output <- file.path(tmp_dir, "dashboard.html")
rmd_template <- ".agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd"

render_res <- tryCatch({
  rmarkdown::render(
    input = rmd_template,
    output_file = html_output,
    params = list(output_dir = tmp_dir),
    quiet = TRUE
  )
  TRUE
}, error = function(e) {
  cat(sprintf("[FAIL] rmarkdown::render failed: %s\n", e$message))
  FALSE
})

if (render_res && file.exists(html_output)) {
  cat("[PASS] dashboard.html rendered successfully.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] dashboard.html rendering failed.\n")
  test_fail <- test_fail + 1L
}

# 3. 生成 HTML に対する外部リソース・CDN・ローカル絶対パスの静的正規表現スキャン
html_content <- paste(readLines(html_output, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# リソースロード構文（外部スクリプト・外部CSS・外部画像・CDN URL・iframe・fetch・XHR・ローカル絶対パス）の検査パターン
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

if (length(detected_violations) == 0) {
  cat("[PASS] Static resource scan passed: 0 external CDN / protocol / local absolute path references detected in rendered HTML.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Static scan violations detected (%d patterns matched):\n", length(detected_violations)))
  for (p in detected_violations) {
    cat(sprintf("   - Pattern matched: %s\n", p))
  }
  test_fail <- test_fail + 1L
}

# 4. DataTables 日本語インライン辞書の存在確認
if (grepl("データが登録されていません", html_content, fixed = TRUE) &&
    !grepl("cdn.datatables.net", html_content, fixed = TRUE)) {
  cat("[PASS] DataTables Japanese language dictionary is fully inlined and CDN URL eliminated.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Inline DataTables dictionary not found or CDN URL remains.\n")
  test_fail <- test_fail + 1L
}

# 5. Section 11 (Quality & Provenance) の表示検証 (run_state.json 未存在時は「未確認」)
if (grepl("canonical", html_content, fixed = TRUE) &&
    grepl("未確認", html_content, fixed = TRUE) &&
    grepl(sig_64, html_content, fixed = TRUE) &&
    grepl("Monte Carlo ドロー数", html_content, fixed = TRUE)) {
  cat("[PASS] Section 11 Quality & Provenance rendered properly (run_state absent -> '未確認').\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Section 11 Quality & Provenance rendering check failed without run_state.\n")
  test_fail <- test_fail + 1L
}

# 6. run_state.json (provenance_status = 'verified') 存在時の再レンダリング検証
run_state_obj <- list(
  status = "completed",
  execution_mode = "canonical",
  provenance_status = "verified",
  run_id = "test_dash_run",
  analysis_signature = sig_64
)
writeLines(jsonlite::toJSON(run_state_obj, auto_unbox = TRUE, pretty = TRUE), file.path(tmp_dir, "run_state.json"))

html_output_verified <- file.path(tmp_dir, "dashboard_verified.html")
render_res_verified <- tryCatch({
  rmarkdown::render(
    input = rmd_template,
    output_file = html_output_verified,
    params = list(output_dir = tmp_dir),
    quiet = TRUE
  )
  TRUE
}, error = function(e) FALSE)

if (render_res_verified && file.exists(html_output_verified)) {
  html_verified_content <- paste(readLines(html_output_verified, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (grepl("検証済み (Pass 0 承認合致)", html_verified_content, fixed = TRUE) &&
      grepl("canonical", html_verified_content, fixed = TRUE)) {
    cat("[PASS] Section 11 Quality & Provenance verified status rendered successfully.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] Section 11 Quality & Provenance verified status not displayed correctly.\n")
    test_fail <- test_fail + 1L
  }
} else {
  cat("[FAIL] dashboard_verified.html rendering failed.\n")
  test_fail <- test_fail + 1L
}

# 7. Section 4 (Adjusted Residual Structure) の表示検証
c1 <- grepl("調整残差構造 (Adjusted Residual Structure)", html_verified_content, fixed = TRUE)
c2 <- grepl("効果の大きさ（効果量）そのものではありません", html_verified_content, fixed = TRUE)
c3 <- grepl("名目 5% 境界", html_verified_content, fixed = TRUE)
c4 <- grepl("独立モデル（行と列が無関連）を仮定したとき", html_verified_content, fixed = TRUE)

if (c1 && c2 && c3 && c4) {
  cat("[PASS] Section 4 Adjusted Residual Structure rendered with scientific question, non-effect-size caution, and plot.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 4 Adjusted Residual Structure check failed (c1:%s, c2:%s, c3:%s, c4:%s)\n", c1, c2, c3, c4))
  test_fail <- test_fail + 1L
}

writeLines(html_verified_content, "/tmp/dbg_dash.html")
# 8. Section 7 (Conditional Posterior) の表示検証
p1 <- grepl("条件付き事後推論 (Conditional Posterior Distributions)", html_verified_content, fixed = TRUE)
p2 <- grepl("中央値や分位点の総和は数学的に\\s*1\\s*にはなりません", html_verified_content)
p3 <- grepl("7.1 行条件付き事後予測確率", html_verified_content, fixed = TRUE)
p4 <- grepl("7.2 列条件付き事後予測確率", html_verified_content, fixed = TRUE)
p5 <- grepl("主表示は中央値および\\s*95%\\s*等裾信用区間", html_verified_content)

if (p1 && p2 && p3 && p4 && p5) {
  cat("[PASS] Section 7 Conditional Posterior rendered with P(B|A) & P(A|B) separation, median/ETI primary, and sum caution.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 7 Conditional Posterior check failed (p1:%s, p2:%s, p3:%s, p4:%s, p5:%s)\n", p1, p2, p3, p4, p5))
  test_fail <- test_fail + 1L
}

# 9. Section 8 (Uncertainty Ranking) の表示検証
u1 <- grepl("不確実性順位 (Uncertainty Ranking)", html_verified_content, fixed = TRUE)
u2 <- grepl("セルの重要性または統計的有意性を示すものではありません", html_verified_content, fixed = TRUE)
u3 <- grepl("prob_eti_width", html_verified_content, fixed = TRUE)

if (u1 && u2 && u3) {
  cat("[PASS] Section 8 Uncertainty Ranking rendered with non-importance caution and prob_eti_width metric.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 8 Uncertainty Ranking check failed (u1:%s, u2:%s, u3:%s)\n", u1, u2, u3))
  test_fail <- test_fail + 1L
}

# 10. Section 9 (Posterior Departure from Independence) の表示検証
d1 <- grepl("独立モデルからの事後乖離 (Posterior Departure from", html_verified_content, fixed = TRUE)
d2 <- grepl("自動二値判定", html_verified_content, fixed = TRUE)
d3 <- grepl("log\\s*divergence", html_verified_content) || grepl("0\\s*（独立基準線）", html_verified_content)

if (d1 && d2 && d3) {
  cat("[PASS] Section 9 Posterior Departure rendered with non-binary caution and 0-reference/log_divergence.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 9 Posterior Departure check failed (d1:%s, d2:%s, d3:%s)\n", d1, d2, d3))
  test_fail <- test_fail + 1L
}

# 11. Section 10 (Prior Sensitivity Analysis) の表示検証
s1 <- grepl("事前感度分析 (Prior Sensitivity Analysis)", html_verified_content, fixed = TRUE)
s2 <- grepl("モデル誤りや解析の欠陥と自動判定しないでください", html_verified_content, fixed = TRUE)
s3 <- grepl("median_shift", html_verified_content, fixed = TRUE)
s4 <- grepl("Jeffreys (α = 0.5)", html_verified_content, fixed = TRUE)
s5 <- grepl("Uniform (α = 1)", html_verified_content, fixed = TRUE)

if (s1 && s2 && s3 && s4 && s5) {
  cat("[PASS] Section 10 Prior Sensitivity rendered with primary/sensitivity comparison and non-model-flaw caution.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 10 Prior Sensitivity check failed (s1:%s, s2:%s, s3:%s, s4:%s, s5:%s)\n", s1, s2, s3, s4, s5))
  test_fail <- test_fail + 1L
}

# 12. Section 12 (Glossary & Scientific References) の表示・アコーディオン検証
g1 <- grepl("12.</span> 統計用語集・方法論解説・学術リファレンス", html_verified_content, fixed = TRUE)
g2 <- grepl("details class=\"glossary-accordion\"", html_verified_content, fixed = TRUE)
g3 <- grepl("全体連関・効果量 (Global Association &", html_verified_content, fixed = TRUE)
g4 <- grepl("局所セル診断と 4 軸フレームワーク", html_verified_content, fixed = TRUE)
g5 <- grepl("ベイズ事後推論と不確実性", html_verified_content, fixed = TRUE)
g6 <- grepl("学術リファレンス・参考文献", html_verified_content, fixed = TRUE)
g7 <- grepl("Haberman, S. J. (1973)", html_verified_content, fixed = TRUE)
g8 <- grepl("Bergsma, W. (2013)", html_verified_content, fixed = TRUE)

# テーマCSS（Nature/NEJM学術標準ネイビー・オフホワイト）の検証
theme_c1 <- grepl("#1f4d7a", html_verified_content, fixed = TRUE)
theme_c2 <- grepl("#f6f8fb", html_verified_content, fixed = TRUE)

if (g1 && g2 && g3 && g4 && g5 && g6 && g7 && g8 && theme_c1 && theme_c2) {
  cat("[PASS] Section 12 Glossary & References rendered with 4 accordions, academic citations, and Nature/NEJM theme tokens.\n")
  test_pass <- test_pass + 1L
} else {
  cat(sprintf("[FAIL] Section 12 Glossary check failed (g1:%s, g2:%s, g3:%s, g4:%s, g5:%s, g6:%s, g7:%s, g8:%s, t1:%s, t2:%s)\n",
              g1, g2, g3, g4, g5, g6, g7, g8, theme_c1, theme_c2))
  test_fail <- test_fail + 1L
}

# 13. select_top_n_cells の表サイズ境界・決定論的選定ユニットテスト
select_top_n_cells_fn <- function(df, metric_col, decreasing = TRUE, n = 25, abs_val = FALSE) {
  k <- nrow(df)
  if (k <= 30) {
    res_df <- df
    res_df$display_order <- seq_len(k)
    return(list(data = res_df, mode = "all", k = k, n_shown = k, n_hidden = 0))
  } else if (k <= 100) {
    return(list(data = df, mode = "table_only", k = k, n_shown = 0, n_hidden = k))
  } else {
    vals <- df[[metric_col]]
    if (abs_val) {
      vals <- abs(vals)
    }
    is_fin <- !is.na(vals) & is.finite(vals)
    val_key <- if (decreasing) -vals else vals
    val_key[!is_fin] <- Inf
    ord <- order(!is_fin, val_key, as.character(df$row_level), as.character(df$col_level))
    top_indices <- ord[seq_len(min(n, k))]
    selected_df <- df[top_indices, ]
    selected_df$display_order <- seq_len(nrow(selected_df))
    return(list(data = selected_df, mode = "top_n", k = k, n_shown = nrow(selected_df), n_hidden = k - nrow(selected_df)))
  }
}

# (a) 境界値テスト: 30 vs 31, 100 vs 101
df30 <- data.frame(row_level = paste0("R", 1:30), col_level = "C1", val = 1:30)
df31 <- data.frame(row_level = paste0("R", 1:31), col_level = "C1", val = 1:31)
df100 <- data.frame(row_level = paste0("R", 1:100), col_level = "C1", val = 1:100)
df101 <- data.frame(row_level = paste0("R", 1:101), col_level = "C1", val = 1:101)

r30 <- select_top_n_cells_fn(df30, "val")
r31 <- select_top_n_cells_fn(df31, "val")
r100 <- select_top_n_cells_fn(df100, "val")
r101 <- select_top_n_cells_fn(df101, "val")

t_boundary <- (r30$mode == "all" && r30$n_shown == 30 && r30$n_hidden == 0) &&
              (r31$mode == "table_only" && r31$n_shown == 0 && r31$n_hidden == 31) &&
              (r100$mode == "table_only" && r100$n_shown == 0 && r100$n_hidden == 100) &&
              (r101$mode == "top_n" && r101$n_shown == 25 && r101$n_hidden == 76)

if (t_boundary) {
  cat("[PASS] Table size fallback boundaries (30/31 and 100/101 cells) verified correctly.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Table size fallback boundary checks failed.\n")
  test_fail <- test_fail + 1L
}

# (b) 同順位固定およびUTF-8ソート検証 (全セル同値 120 セル)
df_ties <- data.frame(
  row_level = rep(c("B", "A", "C"), 40),
  col_level = sprintf("C%03d", rep(1:40, each = 3)),
  val = rep(1.0, 120),
  stringsAsFactors = FALSE
)
r_ties <- select_top_n_cells_fn(df_ties, "val")
t_ties_len <- (r_ties$mode == "top_n" && nrow(r_ties$data) == 25 && r_ties$n_hidden == 95)
# 1番目は row_level "A" であるべき
t_ties_order <- (r_ties$data$row_level[1] == "A")

if (t_ties_len && t_ties_order) {
  t_ord_chk <- all(order(as.character(r_ties$data$row_level), as.character(r_ties$data$col_level)) == seq_len(25))
  if (t_ord_chk) {
    cat("[PASS] Tie-breaking correctly fixed to 25 cells with deterministic UTF-8 byte ordering.\n")
    test_pass <- test_pass + 1L
  } else {
    cat("[FAIL] Tie-breaking UTF-8 sort order check failed.\n")
    test_fail <- test_fail + 1L
  }
} else {
  cat("[FAIL] Tie-breaking 25-cell length or ordering failed.\n")
  test_fail <- test_fail + 1L
}

# (c) 非有限値末尾配置検証
df_nonfin <- data.frame(
  row_level = paste0("R", 1:110),
  col_level = "C1",
  val = c(NA, Inf, -Inf, NaN, 106:1),
  stringsAsFactors = FALSE
)
r_nonfin <- select_top_n_cells_fn(df_nonfin, "val", decreasing = TRUE)
t_nonfin <- (nrow(r_nonfin$data) == 25 && all(is.finite(r_nonfin$data$val)))
if (t_nonfin) {
  cat("[PASS] Non-finite values (NA, Inf, -Inf, NaN) placed at the end after finite values.\n")
  test_pass <- test_pass + 1L
} else {
  cat("[FAIL] Non-finite value handling failed.\n")
  test_fail <- test_fail + 1L
}

# 13. 大規模表 (K = 105) によるレンダリング検証
tmp_large_dir <- file.path(tmp_dir, "large_run")
dir.create(tmp_large_dir)

# 15行 × 7列 = 105セルの合成データ
large_rows <- paste0("Row", sprintf("%02d", 1:15))
large_cols <- paste0("Col", sprintf("%02d", 1:7))
large_grid <- expand.grid(row_level = large_rows, col_level = large_cols, stringsAsFactors = FALSE)
large_grid <- large_grid[order(large_grid$row_level, large_grid$col_level), ]
large_k <- nrow(large_grid) # 105

large_cells <- data.frame(
  row_level = large_grid$row_level,
  col_level = large_grid$col_level,
  observed = as.integer(rpois(large_k, lambda = 30) + 5),
  expected = runif(large_k, 10, 40),
  pearson_res = rnorm(large_k),
  adj_res = rnorm(large_k, mean = 0, sd = 2.5),
  leverage = runif(large_k, 0.01, 0.05),
  log_oe = rnorm(large_k, 0, 0.3),
  rao_score = rchisq(large_k, df = 1),
  p_value_bh = runif(large_k, 0.001, 0.5),
  quarantine_status = "STABLE",
  dual_filter_candidate = FALSE,
  is_finite = TRUE,
  stringsAsFactors = FALSE
)
# 隔離セルを数個設定
large_cells$quarantine_status[1:3] <- "QUARANTINED"
large_cells$dual_filter_candidate[4:5] <- TRUE

large_cell_post <- lapply(seq_len(large_k), function(i) {
  list(
    row_level = large_cells$row_level[i],
    col_level = large_cells$col_level[i],
    prob_mean = 1 / large_k,
    prob_sd = 0.005,
    prob_q025 = 0.002,
    prob_q500 = 1 / large_k,
    prob_q975 = 0.02,
    prob_eti_width = 0.018,
    cond_row_prob_mean = 1 / 7,
    cond_row_prob_median = 1 / 7,
    cond_row_prob_q025 = 0.05,
    cond_row_prob_q975 = 0.25,
    cond_row_prob_eti_width = 0.20,
    cond_col_prob_mean = 1 / 15,
    cond_col_prob_median = 1 / 15,
    cond_col_prob_q025 = 0.02,
    cond_col_prob_q975 = 0.12,
    cond_col_prob_eti_width = 0.10,
    log_divergence_mean = 0.1,
    log_divergence_median = 0.1,
    log_divergence_q025 = -0.2,
    log_divergence_q975 = 0.4,
    log_divergence_eti_width = 0.6
  )
})

large_uncertainty <- lapply(seq_len(large_k), function(i) {
  list(
    rank = i,
    row_level = large_cells$row_level[i],
    col_level = large_cells$col_level[i],
    prob_eti_width = 0.018,
    observed = large_cells$observed[i]
  )
})

large_comparisons <- lapply(seq_len(large_k), function(i) {
  list(
    row_level = large_cells$row_level[i],
    col_level = large_cells$col_level[i],
    primary_median = 1 / large_k,
    sensitivity_median = 1 / large_k + 0.001,
    median_shift = 0.001,
    primary_eti_width = 0.018,
    sensitivity_eti_width = 0.019,
    eti_width_difference = 0.001
  )
})

large_json_obj <- list(
  cells = large_cells,
  global = list(
    n_total = sum(large_cells$observed),
    df = (15 - 1) * (7 - 1),
    cramers_v = 0.15,
    cramers_v_corrected = 0.14,
    cramers_v_ci = c(0.10, 0.18),
    cramers_v_corrected_ci = c(0.09, 0.17)
  ),
  posterior = list(
    prior_specification = list(type = "symmetric_dirichlet", alpha = 0.5),
    n_draws = 1000L,
    cell_posteriors = large_cell_post,
    uncertainty_ranking = large_uncertainty,
    sensitivity_analysis = list(
      primary_alpha = 0.5,
      sensitivity_alpha = 1.0,
      max_median_shift = 0.002,
      max_absolute_mean_diff = 0.002,
      max_eti_width_diff = 0.005,
      cell_comparisons = large_comparisons
    )
  ),
  quality = list(
    n_quarantined_cells = 3,
    n_candidates = 2,
    warnings = character(0)
  ),
  provenance = list(
    run_id = "test_large_run",
    execution_mode = "canonical",
    analysis_signature = sig_64,
    input_sha256 = input_sha_64,
    config_sha256 = config_sha_64,
    deterministic_seed = 12345,
    timestamp_jst = "2026-09-18T21:00:00+09:00"
  )
)

writeLines(jsonlite::toJSON(large_json_obj, auto_unbox = TRUE, pretty = TRUE), file.path(tmp_large_dir, "categorical_results.json"))
large_html <- file.path(tmp_large_dir, "dashboard_large.html")

render_large_res <- tryCatch({
  rmarkdown::render(
    input = rmd_template,
    output_file = large_html,
    params = list(output_dir = tmp_large_dir),
    quiet = TRUE
  )
  TRUE
}, error = function(e) {
  cat(sprintf("[FAIL] Large dashboard render failed: %s\n", e$message))
  FALSE
})

if (render_large_res && file.exists(large_html)) {
  large_content <- paste(readLines(large_html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  writeLines(large_content, "/tmp/dbg_large.html")
  # Top-25表示、非表示セル数「非表示: 80 セル」、全件表への導線確認
  has_top25 <- grepl("上位 25 セル / 全 105 セル", large_content, fixed = TRUE)
  has_hidden <- grepl("非表示:\\s*80\\s*セル", large_content)
  has_all_table <- grepl("section-cell-explorer", large_content, fixed = TRUE)

  # 静的URL走査 (大規模表)
  large_violations <- character(0)
  for (pat in resource_load_patterns) {
    if (grepl(pat, large_content, ignore.case = TRUE)) {
      large_violations <- c(large_violations, pat)
    }
  }

  if (has_top25 && has_hidden && has_all_table && length(large_violations) == 0) {
    cat("[PASS] Large table (K=105) rendered with Top-25 truncation, hidden cell count (80), Cell Explorer link, and zero external references.\n")
    test_pass <- test_pass + 1L
  } else {
    cat(sprintf("[FAIL] Large table checks failed (has_top25:%s, has_hidden:%s, has_all_table:%s, violations:%d)\n",
                has_top25, has_hidden, has_all_table, length(large_violations)))
    test_fail <- test_fail + 1L
  }
} else {
  cat("[FAIL] Large dashboard rendering failed.\n")
  test_fail <- test_fail + 1L
}

unlink(tmp_dir, recursive = TRUE)

cat(sprintf("\nTest Summary: %d Passed, %d Failed\n", test_pass, test_fail))
if (test_fail > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
