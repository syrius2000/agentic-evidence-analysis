# .agents/skills/vcd-categorical-reporting/comparative_reporting.R
# Implements Section 4 of OpenSpec comparative-evidence-reporting-v3

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

local({
  frames <- sys.frames()
  files <- Filter(Negate(is.null), lapply(frames, function(f) f$ofile))
  own <- Filter(function(f) basename(f) == "comparative_reporting.R", files)
  dir <- if (length(own)) dirname(tail(own, 1)[[1]]) else file.path(getwd(), ".agents", "skills", "vcd-categorical-reporting")
  shared_dir <- file.path(dirname(dirname(dir)), "shared")
  engine_path <- file.path(shared_dir, "independent_beta_binomial.R")
  contrasts_path <- file.path(shared_dir, "comparative_contrasts.R")
  run_scope_path <- file.path(shared_dir, "run_scope.R")
  if (file.exists(engine_path)) source(engine_path, local = FALSE)
  if (file.exists(contrasts_path)) source(contrasts_path, local = FALSE)
  if (file.exists(run_scope_path)) source(run_scope_path, local = FALSE)
})

# Ingest multi-theme tabular data and extract pairs conforming to evidence-run-layout
generate_comparative_report <- function(
  df,
  target_arm = NULL,
  reference_arm = NULL,
  group_col = "arm",
  theme_col = "theme",
  events_col = "events",
  total_col = "total",
  contrast_mode = c("reference_vs_all", "all_pairs", "explicit"),
  primary_delta = NULL,
  level = 0.95,
  seed = 42L,
  out_root = "evidence_runs/vcd_categorical_reporting",
  output_dir = NULL,
  run_id = NULL,
  input_data_path = NULL,
  domain = "safety",
  include_frequentist_compat = TRUE
) {
  contrast_mode <- match.arg(contrast_mode)
  if (!is.null(output_dir)) {
    out_root <- output_dir
  }

  # 1. Determine contrast pairs
  all_groups <- sort(unique(df[[group_col]]))
  if (length(all_groups) < 2L) {
    stop("[ERROR] At least 2 comparison groups required.")
  }

  contrast_pairs <- list()
  if (contrast_mode == "explicit") {
    if (is.null(target_arm) || is.null(reference_arm)) {
      stop("[ERROR] Explicit contrast mode requires both target_arm and reference_arm.")
    }
    contrast_pairs[[1L]] <- list(target = target_arm, reference = reference_arm)
  } else if (contrast_mode == "reference_vs_all") {
    ref <- if (!is.null(reference_arm)) reference_arm else all_groups[[1L]]
    others <- setdiff(all_groups, ref)
    for (tgt in others) {
      contrast_pairs[[length(contrast_pairs) + 1L]] <- list(target = tgt, reference = ref)
    }
  } else if (contrast_mode == "all_pairs") {
    comb <- utils::combn(all_groups, 2L, simplify = FALSE)
    for (cb in comb) {
      contrast_pairs[[length(contrast_pairs) + 1L]] <- list(target = cb[[2L]], reference = cb[[1L]])
    }
  }

  # 2. Establish Canonical Run Scope & Directory Isolation
  run_output_dir <- if (exists("reserve_run_output_dir", mode = "function")) {
    reserve_run_output_dir(out_root = out_root, skill = "vcd-categorical-reporting", run_id = run_id)
  } else {
    target_dir <- file.path(out_root, if (!is.null(run_id)) paste0("run_", run_id) else "run_default")
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    target_dir
  }

  # 3. Iterate across themes and contrast pairs
  all_themes <- sort(unique(df[[theme_col]]))
  evidence_list <- list()
  summary_rows <- list()

  for (thm in all_themes) {
    thm_data <- df[df[[theme_col]] == thm, , drop = FALSE]

    for (cp in contrast_pairs) {
      t_grp <- cp$target
      r_grp <- cp$reference

      row_t <- thm_data[thm_data[[group_col]] == t_grp, , drop = FALSE]
      row_r <- thm_data[thm_data[[group_col]] == r_grp, , drop = FALSE]

      if (nrow(row_t) == 0L || nrow(row_r) == 0L) next

      x_T <- row_t[[events_col]][[1L]]
      n_T <- row_t[[total_col]][[1L]]
      x_R <- row_r[[events_col]][[1L]]
      n_R <- row_r[[total_col]][[1L]]

      pair_key <- sprintf("%s__%s_vs_%s", thm, t_grp, r_grp)

      # M4: Generate contrast-specific independent deterministic seed from master seed and pair_key
      sub_seed <- if (!is.null(seed)) {
        h <- digest::digest(paste0(seed, "_", pair_key), algo = "crc32")
        as.integer(strtoi(substr(h, 1, 7), 16L))
      } else NULL

      # Run Bayesian inference
      res <- run_independent_beta_binomial(
        target_events = x_T,
        target_total = n_T,
        reference_events = x_R,
        reference_total = n_R,
        primary_delta = primary_delta,
        seed = sub_seed,
        level = level,
        domain = domain
      )

      ev <- res$evidence
      ev$contrast_id <- pair_key
      ev$theme <- thm
      evidence_list[[pair_key]] <- ev

      # Optional frequentist Fisher exact test compatibility
      p_fisher <- NA_real_
      if (include_frequentist_compat) {
        tab2x2 <- matrix(c(x_T, n_T - x_T, x_R, n_R - x_R), nrow = 2L, byrow = TRUE)
        ft <- tryCatch(stats::fisher.test(tab2x2), error = function(e) NULL)
        if (!is.null(ft)) p_fisher <- ft$p.value
      }

      rd_est <- ev$risk_difference$estimate$value
      rd_low <- ev$risk_difference$interval$lower
      rd_upp <- ev$risk_difference$interval$upper
      rr_est <- ev$relative_risk$estimate$value
      rr_low <- ev$relative_risk$interval$lower
      rr_upp <- ev$relative_risk$interval$upper
      dir_sup <- ev$direction_support$support_value
      u_grd <- ev$resolution_grade$grade
      dom_reg <- ev$resolution_grade$dominant_region %||% "none"

      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        theme = thm,
        target_arm = t_grp,
        reference_arm = r_grp,
        target_events = x_T,
        target_total = n_T,
        target_prop = x_T / n_T,
        reference_events = x_R,
        reference_total = n_R,
        reference_prop = x_R / n_R,
        rd_posterior_median = rd_est,
        rd_eti_lower = rd_low,
        rd_eti_upper = rd_upp,
        rr_posterior_median = if (is.null(rr_est)) NA_real_ else rr_est,
        rr_eti_lower = if (is.null(rr_low)) NA_real_ else rr_low,
        rr_eti_upper = if (is.null(rr_upp)) NA_real_ else rr_upp,
        p_rd_gt_zero = dir_sup,
        u_grade = u_grd,
        dominant_region = dom_reg,
        fisher_p_value = p_fisher,
        badges = paste(ev$diagnostics$badges, collapse = ";"),
        stringsAsFactors = FALSE
      )
    }
  }

  summary_df <- do.call(rbind, summary_rows)

  # 4. Write Deliverable Files inside Run Directory
  # A. run_meta.json
  if (exists("write_run_meta", mode = "function")) {
    write_run_meta(
      out_root = out_root,
      run_output_dir = run_output_dir,
      skill = "vcd-categorical-reporting",
      run_id = if (!is.null(run_id)) run_id else basename(run_output_dir),
      input_data_path = input_data_path
    )
  }

  # B. comparative_evidence.json (conforms to comparative-evidence-batch-v1)
  json_path <- file.path(run_output_dir, "comparative_evidence.json")
  json_deliverable <- list(
    schema_version = "comparative-evidence-batch-v1",
    run_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    run_meta = list(
      run_output_dir = basename(run_output_dir),
      skill = "vcd-categorical-reporting",
      seed = seed
    ),
    domain = domain,
    primary_delta = primary_delta,
    contrasts = evidence_list
  )
  writeLines(jsonlite::toJSON(json_deliverable, auto_unbox = TRUE, pretty = TRUE), json_path)

  # C. comparative_summary.csv
  csv_path <- file.path(run_output_dir, "comparative_summary.csv")
  utils::write.csv(summary_df, csv_path, row.names = FALSE)

  # D. comparative_report.md
  md_path <- file.path(run_output_dir, "comparative_report.md")
  md_lines <- c(
    "# 比較エビデンス解析レポート (Comparative Evidence Report)",
    "",
    "## 1. 重要な解釈上の注意と免責事項",
    "",
    "> [!WARNING]",
    "> **同等性の誤認禁止**: 統計的信用区間が 0 を跨ぐこと（差が非有意であること）は、二群間の「同等性」や「差がないこと」を証明しません。",
    "> **因果的優越の禁止**: 事後確率 $P(RD > 0)$ が高い値であっても、観察研究や未調整交絡の存在下で治療の因果的優越性を単独で証明するものではありません。",
    "> **多重比較の探索的スクリーニング免責**: 複数テーマの一括スクリーニング解析では、家族ワイズ第1種過誤率（FWER）は制御されていません。本結果は仮説生成のための探索的スクリーニングとして解釈してください。",
    "",
    "## 2. 解析結果要約",
    "",
    "| テーマ | 比較 | 標本サイズ (T / R) | イベント数 (T / R) | RD 中央値 [95% ETI] | RR 中央値 [95% ETI] | P(RD > 0) | U-Grade | 領域 | 診断バッジ |",
    "|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|"
  )

  for (i in seq_len(nrow(summary_df))) {
    row <- summary_df[i, ]
    rr_str <- if (is.na(row$rr_posterior_median)) "N/A" else sprintf("%.2f [%.2f, %.2f]", row$rr_posterior_median, row$rr_eti_lower, row$rr_eti_upper)
    md_lines <- c(md_lines, sprintf(
      "| %s | %s vs %s | %d / %d | %d / %d | %.3f [%.3f, %.3f] | %s | %.3f | %s | %s | %s |",
      row$theme, row$target_arm, row$reference_arm,
      row$target_total, row$reference_total,
      row$target_events, row$reference_events,
      row$rd_posterior_median, row$rd_eti_lower, row$rd_eti_upper,
      rr_str, row$p_rd_gt_zero, row$u_grade, row$dominant_region, row$badges
    ))
  }

  writeLines(md_lines, md_path)

  # E. dashboard.html (Zero-External-Asset standalone HTML with Hue x Intensity palette)
  html_path <- file.path(run_output_dir, "dashboard.html")

  html_rows <- character(0)
  for (i in seq_len(nrow(summary_df))) {
    row <- summary_df[i, ]
    rr_str <- if (is.na(row$rr_posterior_median)) "N/A" else sprintf("%.2f [%.2f, %.2f]", row$rr_posterior_median, row$rr_eti_lower, row$rr_eti_upper)

    # H5: Visual encoding: Hue = dominant practical region, Intensity = U-grade resolution
    row_bg <- "transparent"
    if (!is.null(primary_delta) && !is.na(primary_delta) && row$u_grade != "NONE") {
      alpha_val <- switch(row$u_grade,
        "U0" = "0.20",
        "U1" = "0.14",
        "U2" = "0.08",
        "U3" = "0.04"
      )

      if (row$u_grade == "U3") {
        # U3: Muted desaturated grey regardless of dominant region
        row_bg <- "rgba(148, 163, 184, 0.12)"
      } else if (row$dominant_region == "target_excess") {
        # Hue: Red / Coral for target excess risk
        row_bg <- sprintf("rgba(239, 68, 68, %s)", alpha_val)
      } else if (row$dominant_region == "reference_excess") {
        # Hue: Blue / Indigo for reference excess risk
        row_bg <- sprintf("rgba(59, 130, 246, %s)", alpha_val)
      } else if (row$dominant_region == "practical_neutral") {
        # Hue: Emerald / Green for practical equivalence
        row_bg <- sprintf("rgba(16, 185, 129, %s)", alpha_val)
      }
    }

    badge_html <- if (nzchar(row$badges)) sprintf("<span class='badge'>%s</span>", row$badges) else ""

    html_rows <- c(html_rows, sprintf(
      "<tr style='background-color: %s;'><td>%s</td><td>%s vs %s</td><td>%d / %d</td><td>%d / %d</td><td><strong>%.3f</strong> [%.3f, %.3f]</td><td>%s</td><td>%.3f</td><td><span class='ugrade'>%s</span></td><td>%s</td><td>%s</td></tr>",
      row_bg, row$theme, row$target_arm, row$reference_arm,
      row$target_total, row$reference_total,
      row$target_events, row$reference_events,
      row$rd_posterior_median, row$rd_eti_lower, row$rd_eti_upper,
      rr_str, row$p_rd_gt_zero, row$u_grade, row$dominant_region, badge_html
    ))
  }

  html_content <- sprintf('<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>比較エビデンス解析ダッシュボード</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 24px; color: #1e293b; background: #f8fafc; }
    h1 { color: #0f172a; border-bottom: 2px solid #cbd5e1; padding-bottom: 8px; }
    .callout { background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 16px; margin: 16px 0; border-radius: 4px; font-size: 0.9em; }
    .callout strong { color: #b45309; }
    table { width: 100%%; border-collapse: collapse; margin-top: 16px; background: #ffffff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); border-radius: 6px; overflow: hidden; }
    th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #e2e8f0; font-size: 0.88em; }
    th { background: #0f172a; color: #ffffff; font-weight: 600; }
    tr:hover { background-color: #f1f5f9; }
    .badge { background: #fee2e2; color: #991b1b; padding: 2px 6px; border-radius: 4px; font-size: 0.8em; font-weight: bold; }
    .ugrade { font-weight: bold; padding: 2px 6px; border-radius: 3px; border: 1px solid #94a3b8; }
  </style>
</head>
<body>
  <h1>比較エビデンス解析ダッシュボード</h1>
  <div class="callout">
    <strong>【解釈上の厳格な契約・免責事項】</strong><br>
    ・<strong>同等性の誤認禁止</strong>: 信用区間が0を跨ぐことは「同等」を意味しません。<br>
    ・<strong>因果的優越の禁止</strong>: 方向確率単独で治療の因果的優越性を主張してはなりません。<br>
    ・<strong>多重比較スクリーニング免責</strong>: FWERは制御されておらず、本成果物は探索的スクリーニングに位置付けられます。
  </div>
  <table>
    <thead>
      <tr>
        <th>テーマ</th>
        <th>比較</th>
        <th>標本サイズ (T / R)</th>
        <th>イベント数 (T / R)</th>
        <th>RD 中央値 [95%% ETI]</th>
        <th>RR 中央値 [95%% ETI]</th>
        <th>P(RD &gt; 0)</th>
        <th>U-Grade</th>
        <th>実務領域</th>
        <th>診断バッジ</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>
</body>
</html>', paste(html_rows, collapse = "\n"))

  writeLines(html_content, html_path)

  list(
    run_output_dir = run_output_dir,
    json_path = json_path,
    csv_path = csv_path,
    md_path = md_path,
    html_path = html_path,
    summary_df = summary_df
  )
}
