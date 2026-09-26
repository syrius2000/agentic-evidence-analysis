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
  if (!file.exists(run_scope_path)) stop("[SHARED_RUN_SCOPE_UNAVAILABLE] run_scope.R が見つかりません")
  source(run_scope_path, local = FALSE)
})

# HTML escape helper for Zero-External-Asset & markup injection prevention (14.R2)
html_escape <- function(text) {
  if (is.null(text) || length(text) == 0L) return("")
  s <- as.character(text)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  s <- gsub('"', "&quot;", s, fixed = TRUE)
  s <- gsub("'", "&#39;", s, fixed = TRUE)
  s
}

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
  delta_thresholds = c(0.01, 0.02, 0.05, 0.10),
  level = 0.95,
  seed = 42L,
  out_root = "evidence_runs/vcd_categorical_reporting",
  output_dir = NULL,
  run_id = NULL,
  input_data_path = NULL,
  domain = "safety",
  include_frequentist_compat = TRUE,
  evidence_overrides = NULL,
  include_design_aware_fisher = FALSE
) {
  contrast_mode <- match.arg(contrast_mode)
  required_run_functions <- c("reserve_run_output_dir", "write_results_manifest", "write_run_meta", "read_run_control", "verify_results_manifest")
  if (!all(vapply(required_run_functions, exists, logical(1L), mode = "function"))) {
    stop("[SHARED_RUN_SCOPE_UNAVAILABLE] 共有 run 制御関数を利用できません")
  }
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
  if (!all(c(group_col, theme_col, events_col, total_col) %in% names(df))) stop("[MISSING_COLUMNS] 必須列がありません")
  if (anyDuplicated(df[c(theme_col, group_col)])) stop("[DUPLICATE_THEME_GROUP] (theme, group) の重複行を拒絶します")
  if (!is.null(input_data_path) && !file.exists(input_data_path)) stop("[MISSING_INPUT_FILE] 入力ファイルが存在しません")

  # Preflight design-aware evidence provenance before reserving a run directory.
  if (!is.null(evidence_overrides)) {
    for (thm in sort(unique(df[[theme_col]]))) {
      thm_data <- df[df[[theme_col]] == thm, , drop = FALSE]
      for (cp in contrast_pairs) {
        pair_key <- sprintf("%s__%s_vs_%s", thm, cp$target, cp$reference)
        ev <- evidence_overrides[[pair_key]]
        if (is.null(ev)) next
        if (!identical(ev$inferential_semantics, "bootstrap") || is.null(ev$iptw$raw_patient_counts)) {
          stop("[INVALID_EVIDENCE_OVERRIDE] design-aware overrideにはIPTW bootstrap evidenceとraw_patient_countsが必要です")
        }
        row_t <- thm_data[thm_data[[group_col]] == cp$target, , drop = FALSE]
        row_r <- thm_data[thm_data[[group_col]] == cp$reference, , drop = FALSE]
        if (nrow(row_t) != 1L || nrow(row_r) != 1L) stop("[EVIDENCE_REPORT_PROVENANCE_MISMATCH] override対象のreport群が一意に定まりません")
        raw <- ev$iptw$raw_patient_counts
        supplied <- c(target = row_t[[total_col]][[1L]], reference = row_r[[total_col]][[1L]],
                      target_events = row_t[[events_col]][[1L]], reference_events = row_r[[events_col]][[1L]])
        expected <- c(target = raw$target, reference = raw$reference,
                      target_events = raw$target_events, reference_events = raw$reference_events)
        if (!isTRUE(all.equal(as.numeric(supplied), as.numeric(expected), tolerance = 0))) {
          stop(sprintf("[EVIDENCE_REPORT_PROVENANCE_MISMATCH] %s の集計countsがIPTW evidenceのraw_patient_countsと一致しません", pair_key))
        }
      }
    }
  }
  canonical_df <- list(column_names = names(df), column_types = vapply(df, typeof, character(1L)),
                       column_classes = lapply(df, class), values = unname(df), row_order = seq_len(nrow(df)))
  df_sha256 <- digest::digest(canonical_df, algo = "sha256", serialize = TRUE, serializeVersion = 2L)
  run_output_dir <- reserve_run_output_dir(out_root = out_root, skill = "vcd-categorical-reporting", run_id = run_id)

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

      # Use supplied design-aware evidence when available; otherwise run the Bayesian count model.
      design_aware_override <- !is.null(evidence_overrides) && !is.null(evidence_overrides[[pair_key]])
      if (design_aware_override) {
        ev <- evidence_overrides[[pair_key]]
        raw <- ev$iptw$raw_patient_counts
        ess <- ev$iptw$effective_sample_size
        x_T <- raw$target_events; n_T <- raw$target
        x_R <- raw$reference_events; n_R <- raw$reference
      } else {
        res <- run_independent_beta_binomial(
          target_events = x_T,
          target_total = n_T,
          reference_events = x_R,
          reference_total = n_R,
          primary_delta = primary_delta,
          delta_thresholds = delta_thresholds,
          seed = sub_seed,
          level = level,
          domain = domain
        )
        ev <- res$evidence
      }
      ev$contrast_id <- pair_key
      ev$theme <- thm
      evidence_list[[pair_key]] <- ev

      # Optional frequentist Fisher exact test compatibility
      p_fisher <- NA_real_
      design_aware_p_fisher <- NA_real_
      if (design_aware_override && isTRUE(include_design_aware_fisher)) {
        tab2x2 <- matrix(c(x_T, n_T - x_T, x_R, n_R - x_R), nrow = 2L, byrow = TRUE)
        ft <- tryCatch(stats::fisher.test(tab2x2), error = function(e) NULL)
        if (!is.null(ft)) design_aware_p_fisher <- ft$p.value
      } else if (!design_aware_override && include_frequentist_compat) {
        tab2x2 <- matrix(c(x_T, n_T - x_T, x_R, n_R - x_R), nrow = 2L, byrow = TRUE)
        ft <- tryCatch(stats::fisher.test(tab2x2), error = function(e) NULL)
        if (!is.null(ft)) p_fisher <- ft$p.value
      }

      # Risk Difference metrics (null-safe)
      rd_est <- ev$risk_difference$estimate$value
      rd_low <- ev$risk_difference$interval$lower
      rd_upp <- ev$risk_difference$interval$upper
      rd_low_num <- if (!is.null(rd_low) && !is.na(rd_low)) as.numeric(rd_low) else NA_real_
      rd_upp_num <- if (!is.null(rd_upp) && !is.na(rd_upp)) as.numeric(rd_upp) else NA_real_
      rd_est_num <- if (!is.null(rd_est) && !is.na(rd_est)) as.numeric(rd_est) else NA_real_

      # Absolute natural-unit and reciprocal-RD translation.
      # Fallback derivation supports governed legacy/design-aware evidence objects while
      # keeping all new engine outputs canonical and explicit.
      excess_per_100_num <- if (!is.null(ev$risk_difference$excess_per_100)) {
        as.numeric(ev$risk_difference$excess_per_100)
      } else if (!is.na(rd_est_num)) {
        100 * rd_est_num
      } else {
        NA_real_
      }
      reciprocal_raw <- ev$risk_difference$reciprocal_absolute_rd
      reciprocal_num <- if (!is.null(reciprocal_raw) && !is.na(reciprocal_raw)) {
        as.numeric(reciprocal_raw)
      } else if (!is.na(rd_est_num) && abs(rd_est_num) > sqrt(.Machine$double.eps)) {
        1 / abs(rd_est_num)
      } else {
        NA_real_
      }
      reciprocal_direction <- ev$risk_difference$reciprocal_direction %||% (
        if (is.na(rd_est_num) || abs(rd_est_num) <= sqrt(.Machine$double.eps)) {
          "none"
        } else if (rd_est_num > 0) {
          "target_excess"
        } else {
          "reference_excess"
        }
      )
      reciprocal_status <- ev$risk_difference$reciprocal_status %||% (
        if (is.na(rd_est_num) || is.na(rd_low_num) || is.na(rd_upp_num)) {
          "NOT_INTERPRETABLE"
        } else if (abs(rd_est_num) <= sqrt(.Machine$double.eps)) {
          "RD_NEAR_ZERO"
        } else if ((rd_est_num > 0 && rd_low_num > 0 && rd_upp_num > 0) ||
                   (rd_est_num < 0 && rd_low_num < 0 && rd_upp_num < 0)) {
          "STABLE_DIRECTION"
        } else if (rd_low_num <= 0 && rd_upp_num >= 0) {
          "SIGN_AMBIGUOUS"
        } else {
          "NOT_INTERPRETABLE"
        }
      )

      # Relative Risk null-safe extraction (H14-01 / 14.R1)
      rr_est_raw <- ev$relative_risk$estimate$value
      rr_est_avail <- !is.null(rr_est_raw) && !is.na(rr_est_raw)
      rr_est <- if (rr_est_avail) as.numeric(rr_est_raw) else NA_real_

      rr_interval <- ev$relative_risk$interval
      rr_int_avail <- !is.null(rr_interval) &&
                      !is.null(rr_interval$lower) && !is.null(rr_interval$upper) &&
                      !is.na(rr_interval$lower) && !is.na(rr_interval$upper)
      rr_low <- if (rr_int_avail) as.numeric(rr_interval$lower) else NA_real_
      rr_upp <- if (rr_int_avail) as.numeric(rr_interval$upper) else NA_real_

      dir_sup <- ev$direction_support$support_value
      semantics <- ev$inferential_semantics
      interval_method <- ev$risk_difference$interval$method
      support_label <- if (identical(semantics, "bootstrap")) "Bootstrap support fraction (RD > 0)" else "P(RD > 0)"
      interval_label <- if (identical(interval_method, "bootstrap_percentile")) "bootstrap percentile interval" else "ETI"
      u_grd <- ev$resolution_grade$grade
      dom_reg <- ev$resolution_grade$dominant_region %||% "none"

      # Precision metrics (preserve suppression; do not invent metrics if suppressed)
      rd_width <- ev$precision_metrics$rd_interval_width %||% (
        if (!is.na(rd_low_num) && !is.na(rd_upp_num)) rd_upp_num - rd_low_num else NA_real_
      )
      log_rr_width <- if (!is.null(ev$precision_metrics$log_rr_interval_width)) {
        as.numeric(ev$precision_metrics$log_rr_interval_width)
      } else if (rr_int_avail && !is.na(rr_low) && !is.na(rr_upp) && rr_low > 1e-10 && rr_upp > 1e-10) {
        log(rr_upp) - log(rr_low)
      } else {
        NA_real_
      }
      rr_fold <- if (!is.null(ev$precision_metrics$rr_interval_fold_range)) {
        as.numeric(ev$precision_metrics$rr_interval_fold_range)
      } else if (rr_int_avail && !is.na(rr_low) && !is.na(rr_upp) && rr_low > 1e-10) {
        rr_upp / rr_low
      } else {
        NA_real_
      }

      rr_finite <- if (!is.null(ev$relative_risk$mean_is_finite)) isTRUE(ev$relative_risk$mean_is_finite) else if (x_R == 0L) FALSE else TRUE
      rr_diag <- ev$relative_risk$diagnostic %||% ev$diagnostics$relative_risk %||% (if (x_R == 0L) "ZERO_REFERENCE" else NA_character_)

      # Bootstrap replicates provenance extraction (M14-02 / 14.R4)
      rr_boot_def <- if (!is.null(ev$relative_risk$rr_bootstrap_diagnostics$defined_replicates)) {
        as.integer(ev$relative_risk$rr_bootstrap_diagnostics$defined_replicates)
      } else if (!is.null(ev$iptw$bootstrap_diagnostics$defined_rr_replicates)) {
        as.integer(ev$iptw$bootstrap_diagnostics$defined_rr_replicates)
      } else if (!is.null(ev$relative_risk$bootstrap_defined_replicates)) {
        as.integer(ev$relative_risk$bootstrap_defined_replicates)
      } else if (!is.null(ev$diagnostics$bootstrap_defined_replicates)) {
        as.integer(ev$diagnostics$bootstrap_defined_replicates)
      } else {
        NA_integer_
      }

      rr_boot_undef <- if (!is.null(ev$relative_risk$rr_bootstrap_diagnostics$undefined_replicates)) {
        as.integer(ev$relative_risk$rr_bootstrap_diagnostics$undefined_replicates)
      } else if (!is.null(ev$iptw$bootstrap_diagnostics$undefined_rr_replicates)) {
        as.integer(ev$iptw$bootstrap_diagnostics$undefined_rr_replicates)
      } else if (!is.null(ev$relative_risk$bootstrap_undefined_replicates)) {
        as.integer(ev$relative_risk$bootstrap_undefined_replicates)
      } else if (!is.null(ev$diagnostics$bootstrap_undefined_replicates)) {
        as.integer(ev$diagnostics$bootstrap_undefined_replicates)
      } else {
        NA_integer_
      }

      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        theme = thm,
        target_arm = t_grp,
        reference_arm = r_grp,
        target_events = x_T,
        target_total = n_T,
        target_prop = x_T / n_T,
        target_ess = if (design_aware_override) ess$target else NA_real_,
        reference_events = x_R,
        reference_total = n_R,
        reference_prop = x_R / n_R,
        reference_ess = if (design_aware_override) ess$reference else NA_real_,
        counts_semantics = if (design_aware_override) "raw_descriptive_counts" else "raw_counts",
        inferential_semantics = semantics,
        interval_label = interval_label,
        support_label = support_label,
        rd_estimate = rd_est_num,
        rd_interval_lower = rd_low_num,
        rd_interval_upper = rd_upp_num,
        excess_per_100 = excess_per_100_num,
        reciprocal_absolute_rd = reciprocal_num,
        reciprocal_status = reciprocal_status,
        reciprocal_direction = reciprocal_direction,
        rr_estimate = rr_est,
        rr_interval_lower = rr_low,
        rr_interval_upper = rr_upp,
        direction_support = dir_sup,
        u_grade = u_grd,
        dominant_region = dom_reg,
        fisher_p_value = p_fisher,
        design_aware_fisher_p_value = design_aware_p_fisher,
        rd_interval_width = if (is.null(rd_width)) NA_real_ else rd_width,
        log_rr_interval_width = if (is.null(log_rr_width)) NA_real_ else log_rr_width,
        rr_interval_fold_range = if (is.null(rr_fold)) NA_real_ else rr_fold,
        rr_mean_is_finite = rr_finite,
        rr_diagnostic = if (is.null(rr_diag)) NA_character_ else rr_diag,
        rr_estimate_available = rr_est_avail,
        rr_interval_available = rr_int_avail,
        rr_bootstrap_defined_replicates = rr_boot_def,
        rr_bootstrap_undefined_replicates = rr_boot_undef,
        badges = paste(ev$diagnostics$badges, collapse = ";"),
        stringsAsFactors = FALSE
      )
    }
  }

  summary_df <- do.call(rbind, summary_rows)

  # 4. Write Deliverable Files inside Run Directory
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
    delta_thresholds = delta_thresholds,
    contrasts = evidence_list
  )
  writeLines(jsonlite::toJSON(json_deliverable, auto_unbox = TRUE, pretty = TRUE, null = "null"), json_path)

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
    "> **同等性の誤認禁止**: 不確実性区間が 0 を跨ぐこと（差が非有意であること）は、二群間の「同等性」や「差がないこと」を証明しません。",
    "> **因果的優越の禁止**: 方向支持指標は、観察研究や未調整交絡の存在下で治療の因果的優越性を単独で証明するものではありません。",
    "> **多重比較の探索的スクリーニング免責**: 複数テーマの一括スクリーニング解析では、家族ワイズ第1種過誤率（FWER）は制御されていません。本結果は仮説生成のための探索的スクリーニングとして解釈してください。",
    "",
    "## 2. 解析結果要約",
    "",
    "| テーマ | 比較 | 記述N (T / R) | 記述イベント数 (T / R) | RD 推定値 [区間] | 100人あたり差 (E100) | NNT・NNH-like | RR 推定値 [区間] | 方向支持指標 | 実務領域・U-Grade | 精度指標 (ESS / 区間幅) | 診断バッジ |",
    "|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|"
  )

  for (i in seq_len(nrow(summary_df))) {
    row <- summary_df[i, ]
    rd_str_md <- if (is.na(row$rd_estimate)) "N/A" else sprintf("%.3f [%.3f, %.3f]", row$rd_estimate, row$rd_interval_lower, row$rd_interval_upper)
    e100_md <- if (is.na(row$excess_per_100)) "N/A" else sprintf("%+.2f / 100人", row$excess_per_100)
    reciprocal_label_md <- if (row$reciprocal_status != "STABLE_DIRECTION" || is.na(row$reciprocal_absolute_rd)) {
      sprintf("— (%s)", row$reciprocal_status)
    } else if (identical(domain, "safety") && row$reciprocal_direction == "target_excess") {
      sprintf("NNH-like ≈ %.1f人", row$reciprocal_absolute_rd)
    } else if (identical(domain, "safety") && row$reciprocal_direction == "reference_excess") {
      sprintf("NNT-like ≈ %.1f人", row$reciprocal_absolute_rd)
    } else {
      # Pipe characters must be escaped in Markdown table cells only.
      sprintf("1/\\|RD\\| ≈ %.1f人", row$reciprocal_absolute_rd)
    }
    rr_str_md <- if (is.na(row$rr_estimate)) {
      "N/A"
    } else if (is.na(row$rr_interval_lower) || is.na(row$rr_interval_upper)) {
      sprintf("%.2f [N/A]", row$rr_estimate)
    } else {
      sprintf("%.2f [%.2f, %.2f]", row$rr_estimate, row$rr_interval_lower, row$rr_interval_upper)
    }
    ess_md <- if (is.na(row$target_ess)) "N/A" else sprintf("%.1f / %.1f", row$target_ess, row$reference_ess)
    rd_width_md <- if (is.na(row$rd_interval_width)) "N/A" else sprintf("幅: %.3f", row$rd_interval_width)
    precision_md <- sprintf("ESS: %s; %s", ess_md, rd_width_md)
    md_lines <- c(md_lines, sprintf(
      "| %s | %s vs %s | %d / %d | %d / %d | %s | %s | %s | %s | %.3f (%s) | %s / %s | %s | %s |",
      row$theme, row$target_arm, row$reference_arm,
      row$target_total, row$reference_total,
      row$target_events, row$reference_events,
      rd_str_md,
      e100_md,
      reciprocal_label_md,
      rr_str_md, row$direction_support, row$support_label,
      row$u_grade, row$dominant_region,
      precision_md,
      row$badges
    ))
  }

  # Compact Statistical Metric Guide synchronized with HTML dashboard (Task 14.13.R1)
  has_bayesian_sem <- any(summary_df$inferential_semantics == "posterior", na.rm = TRUE)
  has_bootstrap_sem <- any(summary_df$inferential_semantics == "bootstrap", na.rm = TRUE)

  risk_guide_desc <- if (has_bayesian_sem && !has_bootstrap_sem) {
    "- **推論的点推定値 (inferential point estimate)**: 独立 Jeffreys 事前分布 $\\text{Beta}(0.5, 0.5)$ に基づく事後中央値（posterior median, `estimate.source = posterior_median`）を使用。生の記述割合とは明確に区別されます。"
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    "- **推論的点推定値 (inferential point estimate)**: 標本観測推定量（observed sample estimate, `estimate.source = observed_sample_estimate`）を使用。区間推定および方向支持はブートストラップ再標本化分布に基づきます。生の記述割合とは明確に区別されます。"
  } else {
    "- **推論的点推定値 (inferential point estimate)**: ベイズ推論では事後中央値（posterior median, `estimate.source = posterior_median`）、ブートストラップ推論では標本観測推定量（observed sample estimate, `estimate.source = observed_sample_estimate`）を使用（各行の `inferential_semantics` に準拠）。生の記述割合とは明確に区別されます。"
  }

  interval_guide_desc <- if (has_bayesian_sem && !has_bootstrap_sem) {
    "- **Bayesian 95% ETI**: モデル・事前分布・観測データを条件として、パラメータの事後確率質量の 95% を含む等裾区間（下側 2.5% 点と上側 97.5% 点）。"
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    "- **Bootstrap 95% percentile interval**: ブートストラップ再標本化で得られた推定量の経験分布の 2.5% 点と 97.5% 点による区間。「パラメータが 95% の確率で区間内にある」とは解釈しません。"
  } else {
    c(
      "- **Bayesian 95% ETI**: モデル・事前分布・観測データを条件として、パラメータの事後確率質量の 95% を含む等裾区間。",
      "- **Bootstrap 95% percentile interval**: ブートストラップ再標本化で得られた推定量の経験分布の 2.5% 点と 97.5% 点による区間。「パラメータが 95% の確率で区間内にある」とは解釈しません。"
    )
  }

  direction_guide_desc <- if (has_bayesian_sem && !has_bootstrap_sem) {
    "- **定義**: $P(RD > 0 \\mid \\text{data})$（ベイズ事後方向支持確率）。"
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    "- **定義**: $\\hat{p}^* = \\frac{1}{B} \\sum I(RD^* > 0)$（ブートストラップ支持比率）。"
  } else {
    "- **定義**: $P(RD > 0 \\mid \\text{data})$（ベイズ）またはブートストラップ支持比率 $\\hat{p}^*$。"
  }

  rr_zero_desc <- if (has_bayesian_sem && !has_bootstrap_sem) {
    "- **ゼロセル挙動**: 対照群イベント数ゼロ ($x_R = 0$) の場合、独立 Jeffreys 事後分布では理論的期待値 $E(RR) = \\infty$ となり、平均値契約は `mean = null`, `mean_is_finite = false` となります（事後中央値および信用区間は有限値として算出可能）。主対比として RD を併用してください。"
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    "- **ゼロセル挙動**: 対照群イベント数ゼロ ($x_R = 0$) または定義不能レプリケート発生時、ブートストラップ推論では RR 推定量・区間が利用不能（`rr_estimate_available = false`）となるか、ブートストラップ診断（`rr_bootstrap_undefined_replicates`）に従います。主対比として RD を併用してください。"
  } else {
    "- **ゼロセル挙動**: 各行の `inferential_semantics` に応じ、独立ベイズ推論では理論的期待値 $E(RR) = \\infty$（`mean = null, mean_is_finite = false`、中央値・区間は有限）となり、ブートストラップ推論では RR 推定量・区間が利用不能（`rr_estimate_available = false`）またはブートストラップ診断に従います。主対比として RD を併用してください。"
  }

  md_lines <- c(
    md_lines,
    "",
    "## 3. 統計指標の解説と利用ガイド (Statistical Metric Guide)",
    "",
    "### 1. リスク・発症割合 (Risk / incidence proportion)",
    "- **生の記述割合 (raw descriptive proportion)**: $p_{T,\\text{raw}} = x_T / n_T$, $p_{R,\\text{raw}} = x_R / n_R$",
    risk_guide_desc,
    "",
    "### 2. リスク差 (Risk Difference: RD)",
    "- **一次対比 RD**: $RD = p_T - p_R$。絶対効果の primary estimand。",
    "- **自然単位 E100（preferred translation）**: $E100 = 100 \\times RD$。RD を置換せず、人間向け単位へ線形換算する（例: RD = 0.03 → +3.00 / 100人）。",
    "- **二次解釈 reciprocal RD**: $1/|RD|$ は canonical RD 点推定値の逆数。primary estimand ではない。",
    "- **Safety 方向ラベル契約**: `reciprocal_status = STABLE_DIRECTION` かつ有限値のときのみ、`target_excess → NNH-like`、`reference_excess → NNT-like`。非 Safety は `1/|RD|` のみ（NNT/NNH 断定禁止）。",
    "- **逆数の不確実性契約**: RD 区間が0を跨ぐ場合は SIGN_AMBIGUOUS として方向付き NNT/NNH-like を抑制する。0を跨ぐRD区間を単純反転した連続区間は表示しない。",
    "- **重要禁止解釈**: 区間が 0 を跨ぐことは二群間の「同等性」や「差がないこと」を証明しない。因果的 NNT を自動主張しない。",
    "",
    "### 3. 相対リスク (Relative Risk: RR)",
    "- **定義**: $RR = p_T / p_R$。対照群に対する相対的な発生リスクの対比を評価します。",
    rr_zero_desc,
    "",
    "### 4. 不確実性区間 (Uncertainty Interval)",
    interval_guide_desc,
    "",
    "### 5. 方向支持指標 (Direction Support)",
    direction_guide_desc,
    "- **重要禁止解釈**: 方向確率単独で治療の因果的優越性を主張してはなりません。",
    "",
    "### 6. 実務領域と一次対比閾値 (Practical Difference Regions & primary_delta)",
    "- **3 領域確率**: $q_T = P(RD > \\delta)$, $q_N = P(-\\delta \\le RD \\le \\delta)$, $q_R = P(RD < -\\delta)$ ($q_T + q_N + q_R = 1$)。",
    "- **無効化契約**: `primary_delta = null` の場合、実務領域分類は無効化（`none`）され、無彩色化されます。",
    "",
    "### 7. 実務領域解像度グレード (U-Grade)",
    "- **定義**: 最大領域確率 $C = \\max(q_T, q_N, q_R)$ に基づく解像度等級（U0 $\\ge$ 0.95, U1 $\\ge$ 0.80, U2 $\\ge$ 0.60, U3 < 0.60）。",
    "- **重要禁止解釈**: 不確実性分布の実務領域への収まり具合（解像度）であり、標本サイズ（精度）や有害事象の臨床的重症度を意味しません。",
    "",
    "### 8. 連続精度指標と有効標本サイズ (Precision Metrics & ESS)",
    "- **定義**: 区間幅 ($RD_{\\text{width}} = RD_{\\text{upper}} - RD_{\\text{lower}}$) および IPTW デザイン等の有効標本サイズ (ESS)。",
    "",
    "### 9. 診断バッジ (Diagnostic Badges)",
    "- **主なバッジ**: `ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`, `UNSTABLE_RR_INTERVAL`。比率指標の数値不安定性を警告し、RD の併用を促します。",
    "",
    "### 10. 多重比較・探索的スクリーニング指針 (Multiplicity & Exploratory Use)",
    "- **探索的位置付け**: 家族ワイズ第1種過誤率（FWER）は制御されておらず、シグナル検出・仮説生成のためのスクリーニングです。自動規制決定や薬事承認の決定的根拠としてはなりません。"
  )

  writeLines(md_lines, md_path)

  # E. dashboard.html (Zero-External-Asset standalone HTML with Section 14 Visual Separation Contract)
  html_path <- file.path(run_output_dir, "dashboard.html")

  # Detect numerical instability across contrasts for conditional warning callout
  has_rr_instability <- any(!summary_df$rr_estimate_available, na.rm = TRUE) ||
    any(!summary_df$rr_interval_available, na.rm = TRUE) ||
    any(!summary_df$rr_mean_is_finite, na.rm = TRUE) ||
    any(grepl("ZERO_REFERENCE", summary_df$badges, fixed = TRUE)) ||
    any(grepl("ZERO_BOTH", summary_df$badges, fixed = TRUE)) ||
    any(grepl("UNSTABLE_RR_INTERVAL", summary_df$badges, fixed = TRUE)) ||
    any(!is.na(summary_df$rr_diagnostic) & nzchar(summary_df$rr_diagnostic)) ||
    any(!is.na(summary_df$rr_bootstrap_undefined_replicates) & summary_df$rr_bootstrap_undefined_replicates > 0L)

  warning_callout_html <- if (has_rr_instability) {
    paste(
      '  <div id="numerical-instability-warning" class="callout warning" role="alert">',
      '    <strong>【数値的不安定性に関する警告】</strong><br>',
      '    参照群のイベント発生数がゼロ（ZERO_REFERENCE）または極めて疎であるため、相対リスク（RR）の期待値が理論的に発散、または不確実性区間が極めて広範になっています。<br>',
      '    ※ なお、リスク差（RD）や絶対指標は引き続き適切に推定されており有効です。RR の点推定値および区間幅の解釈には十分ご注意ください。',
      '  </div>',
      sep = "\n"
    )
  } else ""

  html_rows <- character(0)
  for (i in seq_len(nrow(summary_df))) {
    row <- summary_df[i, ]
    rd_str <- if (is.na(row$rd_estimate)) "N/A" else sprintf("<strong>%.3f</strong> [%.3f, %.3f]", row$rd_estimate, row$rd_interval_lower, row$rd_interval_upper)
    reciprocal_label_html <- if (row$reciprocal_status != "STABLE_DIRECTION" || is.na(row$reciprocal_absolute_rd)) {
      sprintf("<small>— (%s)</small>", html_escape(row$reciprocal_status))
    } else if (identical(domain, "safety") && row$reciprocal_direction == "target_excess") {
      sprintf("<strong>NNH-like ≈ %.1f人</strong>", row$reciprocal_absolute_rd)
    } else if (identical(domain, "safety") && row$reciprocal_direction == "reference_excess") {
      sprintf("<strong>NNT-like ≈ %.1f人</strong>", row$reciprocal_absolute_rd)
    } else {
      sprintf("<strong>1/|RD| ≈ %.1f人</strong>", row$reciprocal_absolute_rd)
    }
    excess100_html <- if (is.na(row$excess_per_100)) "N/A" else sprintf("%+.2f / 100人", row$excess_per_100)

    rr_str <- if (is.na(row$rr_estimate)) {
      "N/A"
    } else if (is.na(row$rr_interval_lower) || is.na(row$rr_interval_upper)) {
      sprintf("%.2f [N/A]", row$rr_estimate)
    } else {
      sprintf("%.2f [%.2f, %.2f]", row$rr_estimate, row$rr_interval_lower, row$rr_interval_upper)
    }

    # 14.2 & 14.3: Practical Difference cell ONLY visual encoding
    # Row tr remains uncolored to preserve semantic separation of Effect/Direction/Precision
    practical_bg <- "transparent"
    if (!is.null(primary_delta) && !is.na(primary_delta) && row$u_grade != "NONE") {
      if (row$u_grade == "U3") {
        # U3: Muted desaturated slate override regardless of dominant region
        practical_bg <- "rgba(148, 163, 184, 0.12)"
      } else {
        alpha_val <- switch(row$u_grade,
          "U0" = "0.20",
          "U1" = "0.14",
          "U2" = "0.08",
          "0.08"
        )
        if (row$dominant_region == "target_excess") {
          practical_bg <- sprintf("rgba(239, 68, 68, %s)", alpha_val)
        } else if (row$dominant_region == "reference_excess") {
          practical_bg <- sprintf("rgba(59, 130, 246, %s)", alpha_val)
        } else if (row$dominant_region == "practical_neutral") {
          practical_bg <- sprintf("rgba(100, 116, 139, %s)", alpha_val)
        }
      }
    }

    # 14.4: Dedicated Diagnostics column with discrete span.badge items (HTML-escaped)
    badge_elements <- character(0)
    if (nzchar(row$badges)) {
      raw_badges <- unlist(strsplit(row$badges, ";"))
      for (b in raw_badges) {
        b_trim <- trimws(b)
        if (nzchar(b_trim)) {
          badge_elements <- c(badge_elements, sprintf("<span class='badge'>%s</span>", html_escape(b_trim)))
        }
      }
    }
    badge_html <- paste(badge_elements, collapse = " ")

    # 14.1: Dedicated Precision cell (ESS and interval widths)
    ess_str <- if (is.na(row$target_ess)) "N/A" else sprintf("%.1f / %.1f", row$target_ess, row$reference_ess)
    rd_width_str <- if (is.na(row$rd_interval_width)) "N/A" else sprintf("幅: %.3f", row$rd_interval_width)
    precision_html <- sprintf("ESS: %s<br><small>%s</small>", ess_str, rd_width_str)

    # 14.R2: Allowlist enum-derived class fragments
    safe_ugrade <- switch(toupper(row$u_grade %||% "NONE"),
      "U0" = "u0",
      "U1" = "u1",
      "U2" = "u2",
      "U3" = "u3",
      "none"
    )
    safe_region <- switch(tolower(row$dominant_region %||% "none"),
      "target_excess" = "target-excess",
      "reference_excess" = "reference-excess",
      "practical_neutral" = "practical-neutral",
      "none"
    )
    practical_class <- sprintf("col-practical practical-%s practical-%s", safe_ugrade, safe_region)

    # 14.10: Explicit machine-readable sort keys
    u_ord <- switch(toupper(row$u_grade %||% "NONE"),
      "U0" = 0L,
      "U1" = 1L,
      "U2" = 2L,
      "U3" = 3L,
      4L
    )
    practical_sort_val <- sprintf("%d_%s", u_ord, tolower(row$dominant_region %||% "none"))
    rd_sort_val <- if (!is.na(row$rd_estimate)) sprintf("%.8f", row$rd_estimate) else ""
    e100_sort_val <- if (!is.na(row$excess_per_100)) sprintf("%.8f", row$excess_per_100) else ""
    reciprocal_sort_val <- if (identical(row$reciprocal_status, "STABLE_DIRECTION") &&
                                 !is.na(row$reciprocal_absolute_rd)) {
      sprintf("%.8f", row$reciprocal_absolute_rd)
    } else {
      ""
    }
    rr_sort_val <- if (!is.na(row$rr_estimate)) sprintf("%.8f", row$rr_estimate) else ""
    dir_sort_val <- if (!is.na(row$direction_support)) sprintf("%.8f", row$direction_support) else ""
    prec_sort_val <- if (!is.na(row$rd_interval_width)) sprintf("%.8f", row$rd_interval_width) else ""
    n_sort_val <- sprintf("%010d_%010d", as.integer(row$target_total %||% 0), as.integer(row$reference_total %||% 0))
    ev_sort_val <- sprintf("%010d_%010d", as.integer(row$target_events %||% 0), as.integer(row$reference_events %||% 0))
    diag_sort_val <- trimws(row$badges %||% "")

    # 14.12 & 14.11: Add canonical row-level metadata for robust filtering and export matching
    row_key <- sprintf("row_%06d", i)
    row_region <- tolower(row$dominant_region %||% "none")
    row_ugrade_val <- toupper(row$u_grade %||% "NONE")
    row_badges_val <- trimws(row$badges %||% "")

    html_rows <- c(html_rows, sprintf(
      paste0(
        "<tr data-row-key=\"%s\" data-theme=\"%s\" data-region=\"%s\" data-ugrade=\"%s\" data-badges=\"%s\">",
        "<td class='col-id' data-sort-value=\"%s\">%s</td>",
        "<td class='col-id' data-sort-value=\"%s\">%s vs %s</td>",
        "<td class='col-id' data-sort-value=\"%s\">%d / %d</td>",
        "<td class='col-id' data-sort-value=\"%s\">%d / %d</td>",
        "<td class='col-effect' data-sort-value=\"%s\">%s</td>",
        "<td class='col-effect col-e100' data-sort-value=\"%s\">%s</td>",
        "<td class='col-effect col-reciprocal' data-sort-value=\"%s\">%s</td>",
        "<td class='col-effect' data-sort-value=\"%s\">%s</td>",
        "<td class='col-direction' data-sort-value=\"%s\">%.3f<br><small>(%s)</small></td>",
        "<td class='%s' style='background-color: %s;' data-sort-value=\"%s\"><span class='ugrade'>%s</span><br><small>%s</small></td>",
        "<td class='col-precision' data-sort-value=\"%s\">%s</td>",
        "<td class='col-diagnostics' data-sort-value=\"%s\">%s</td>",
        "</tr>"
      ),
      row_key, html_escape(row$theme), html_escape(row_region), html_escape(row_ugrade_val), html_escape(row_badges_val),
      html_escape(row$theme), html_escape(row$theme),
      html_escape(sprintf("%s vs %s", row$target_arm, row$reference_arm)), html_escape(row$target_arm), html_escape(row$reference_arm),
      n_sort_val, row$target_total, row$reference_total,
      ev_sort_val, row$target_events, row$reference_events,
      rd_sort_val, rd_str,
      e100_sort_val, excess100_html,
      reciprocal_sort_val, reciprocal_label_html,
      rr_sort_val, rr_str,
      dir_sort_val, row$direction_support, html_escape(row$support_label),
      practical_class, practical_bg, practical_sort_val, html_escape(row$u_grade), html_escape(row$dominant_region),
      prec_sort_val, precision_html,
      html_escape(diag_sort_val), badge_html
    ))
  }

  # Prepare embedded canonical JSON for Task 14.11 (RFC 4180 export without recomputation)
  summary_export_df <- summary_df
  summary_export_df$row_key <- sprintf("row_%06d", seq_len(nrow(summary_export_df)))
  json_summary_data <- jsonlite::toJSON(summary_export_df, dataframe = "rows", na = "null", auto_unbox = TRUE)
  # Prevent </script> termination injection and satisfy hostile scanner by Unicode escaping HTML delimiters
  json_summary_data <- gsub("<", "\\\\u003c", json_summary_data, fixed = TRUE)
  json_summary_data <- gsub(">", "\\\\u003e", json_summary_data, fixed = TRUE)
  json_summary_data <- gsub("&", "\\\\u0026", json_summary_data, fixed = TRUE)

  # Unique themes and badges for filter UI (Task 14.12)
  unique_themes <- sort(unique(as.character(summary_df$theme)))
  raw_all_badges <- unlist(strsplit(as.character(summary_df$badges), ";"))
  unique_badges <- sort(unique(trimws(raw_all_badges[nzchar(trimws(raw_all_badges))])))
  all_possible_badges <- unique(c("ZERO_REFERENCE", "ZERO_BOTH", "SPARSE_EVENTS", "UNSTABLE_RR_INTERVAL", unique_badges))

  theme_checkbox_items <- vapply(unique_themes, function(thm) {
    sprintf("<label class=\"filter-item\"><input type=\"checkbox\" class=\"filter-theme\" value=\"%s\"> %s</label>",
            html_escape(thm), html_escape(thm))
  }, character(1L))

  badge_checkbox_items <- vapply(all_possible_badges, function(bdg) {
    sprintf("<label class=\"filter-item\"><input type=\"checkbox\" class=\"filter-badge-opt\" value=\"%s\"> %s</label>",
            html_escape(bdg), html_escape(bdg))
  }, character(1L))
  badge_checkbox_items <- c(badge_checkbox_items, "<label class=\"filter-item\"><input type=\"checkbox\" class=\"filter-badge-opt\" value=\"__NONE__\"> (診断なし)</label>")

  html_head <- '<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>比較エビデンス解析ダッシュボード</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 24px; color: #1e293b; background: #f8fafc; }
    h1 { color: #0f172a; border-bottom: 2px solid #cbd5e1; padding-bottom: 8px; }
    .callout { background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 16px; margin: 16px 0; border-radius: 4px; font-size: 0.9em; }
    .callout strong { color: #b45309; }
    .callout.warning { background: #fef2f2; border-left: 4px solid #ef4444; }
    .callout.warning strong { color: #991b1b; }
    .toolbar-container { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 14px 18px; margin: 16px 0; box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
    .toolbar-row { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
    .toolbar-row + .toolbar-row { margin-top: 12px; padding-top: 12px; border-top: 1px solid #f1f5f9; }
    .filter-dropdown { position: relative; display: inline-block; }
    .filter-summary { cursor: pointer; padding: 6px 12px; background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 0.88em; font-weight: 500; user-select: none; }
    .filter-summary:hover { background: #e2e8f0; }
    .filter-panel { position: absolute; z-index: 50; top: 100%; left: 0; margin-top: 4px; background: #ffffff; border: 1px solid #94a3b8; border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); padding: 10px; min-width: 240px; max-height: 280px; overflow-y: auto; }
    .filter-dual-panel { display: flex; gap: 16px; min-width: 320px; }
    .filter-subgroup { display: flex; flex-direction: column; gap: 4px; }
    .filter-subgroup-title { font-weight: bold; font-size: 0.82em; color: #475569; margin-bottom: 4px; border-bottom: 1px solid #e2e8f0; padding-bottom: 2px; }
    .filter-search { width: 100%; box-sizing: border-box; padding: 4px 8px; margin-bottom: 8px; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 0.85em; }
    .checkbox-list { display: flex; flex-direction: column; gap: 4px; }
    .filter-item { font-size: 0.85em; cursor: pointer; display: flex; align-items: center; gap: 6px; }
    .filter-badge-indicator { font-size: 0.78em; background: #e2e8f0; color: #334155; padding: 1px 6px; border-radius: 10px; margin-left: 4px; }
    .btn-action { padding: 6px 14px; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 0.88em; cursor: pointer; }
    .btn-action:hover { background: #f1f5f9; }
    .btn-export { padding: 6px 14px; background: #0284c7; color: #ffffff; border: none; border-radius: 4px; font-size: 0.88em; font-weight: 500; cursor: pointer; }
    .btn-export:hover { background: #0369a1; }
    .status-indicator { display: flex; align-items: center; gap: 10px; font-size: 0.9em; font-weight: 500; }
    .count-badge { background: #e0f2fe; color: #0369a1; padding: 2px 8px; border-radius: 4px; }
    .active-badge { color: #64748b; font-size: 0.85em; }
    .export-buttons { margin-left: auto; display: flex; gap: 8px; }
    .table-container { width: 100%; overflow-x: auto; margin-top: 16px; }
    caption { caption-side: top; text-align: left; font-weight: bold; margin-bottom: 8px; color: #475569; font-size: 1.05em; }
    table { width: 100%; border-collapse: collapse; background: #ffffff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); border-radius: 6px; overflow: hidden; }
    th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #e2e8f0; font-size: 0.88em; }
    th.col-e100, td.col-e100, th.col-reciprocal, td.col-reciprocal { font-size: 0.82em; white-space: nowrap; padding-left: 8px; padding-right: 8px; }
    th { background: #0f172a; color: #ffffff; font-weight: 600; }
    th.sortable { cursor: pointer; user-select: none; position: relative; padding-right: 24px; }
    th.sortable:hover { background: #1e293b; }
    th.sortable:focus-visible { outline: 2px solid #38bdf8; outline-offset: -2px; }
    th.sortable .sort-indicator { display: inline-block; margin-left: 6px; font-size: 0.8em; opacity: 0.4; }
    th.sortable[aria-sort="ascending"] .sort-indicator { opacity: 1; color: #38bdf8; }
    th.sortable[aria-sort="descending"] .sort-indicator { opacity: 1; color: #38bdf8; }
    tr:hover { background-color: #f8fafc; }
    .badge { background: #fee2e2; color: #991b1b; padding: 2px 6px; border-radius: 4px; font-size: 0.8em; font-weight: bold; display: inline-block; margin: 1px; }
    .ugrade { font-weight: bold; padding: 2px 6px; border-radius: 3px; border: 1px solid #94a3b8; }
    small { color: #64748b; }
    #metric-guide { margin-top: 36px; padding-top: 20px; border-top: 2px solid #e2e8f0; }
    #metric-guide h2 { font-size: 1.25em; color: #0f172a; margin-bottom: 12px; }
    .guide-accordion { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; margin-bottom: 8px; overflow: hidden; }
    .guide-summary { cursor: pointer; padding: 10px 14px; font-weight: 600; font-size: 0.95em; color: #1e293b; background: #f8fafc; user-select: none; }
    .guide-summary:hover { background: #f1f5f9; }
    .guide-content { padding: 14px 18px; font-size: 0.9em; line-height: 1.6; border-top: 1px solid #e2e8f0; }
    .guide-content h4 { margin: 10px 0 4px 0; color: #334155; font-size: 0.95em; }
    .guide-content p, .guide-content ul { margin: 4px 0 8px 0; }
    .guide-content ul { padding-left: 20px; }
    math { font-size: 1.1em; }
  </style>
</head>
<body>
  <h1 id="dashboard-title">比較エビデンス解析ダッシュボード</h1>
  <div id="guidance-callout" class="callout">
    <strong>【解釈上の厳格な契約・免責事項】</strong><br>
    ・<strong>同等性の誤認禁止</strong>: 不確実性区間が0を跨ぐことは「同等」を意味しません。<br>
    ・<strong>因果的優越の禁止</strong>: 方向確率単独で治療の因果的優越性を主張してはなりません。<br>
    ・<strong>多重比較スクリーニング免責</strong>: FWERは制御されておらず、本成果物は探索的スクリーニングに位置付けられます。
  </div>
'

  html_toolbar <- sprintf('  <div id="dashboard-toolbar" class="toolbar-container" role="region" aria-label="ダッシュボード操作パネル">
    <div class="toolbar-row filter-controls">
      <details id="filter-group-theme" class="filter-dropdown">
        <summary class="filter-summary">テーマ選択 <span id="theme-filter-count" class="filter-badge-indicator">すべて</span></summary>
        <div class="filter-panel">
          <input type="text" id="theme-search-input" placeholder="テーマを絞り込み..." class="filter-search" aria-label="テーマ絞り込み検索">
          <div id="theme-checkbox-list" class="checkbox-list">
            %s
          </div>
        </div>
      </details>
      <details id="filter-group-practical" class="filter-dropdown">
        <summary class="filter-summary">実務領域 / U-Grade <span id="practical-filter-count" class="filter-badge-indicator">すべて</span></summary>
        <div class="filter-panel filter-dual-panel">
          <div class="filter-subgroup">
            <div class="filter-subgroup-title">実務領域 (OR)</div>
            <label class="filter-item"><input type="checkbox" class="filter-region" value="target_excess"> target_excess</label>
            <label class="filter-item"><input type="checkbox" class="filter-region" value="practical_neutral"> practical_neutral</label>
            <label class="filter-item"><input type="checkbox" class="filter-region" value="reference_excess"> reference_excess</label>
            <label class="filter-item"><input type="checkbox" class="filter-region" value="none"> none</label>
          </div>
          <div class="filter-subgroup">
            <div class="filter-subgroup-title">U-Grade (OR)</div>
            <label class="filter-item"><input type="checkbox" class="filter-ugrade" value="U0"> U0</label>
            <label class="filter-item"><input type="checkbox" class="filter-ugrade" value="U1"> U1</label>
            <label class="filter-item"><input type="checkbox" class="filter-ugrade" value="U2"> U2</label>
            <label class="filter-item"><input type="checkbox" class="filter-ugrade" value="U3"> U3</label>
            <label class="filter-item"><input type="checkbox" class="filter-ugrade" value="NONE"> NONE</label>
          </div>
        </div>
      </details>
      <details id="filter-group-diagnostics" class="filter-dropdown">
        <summary class="filter-summary">診断バッジ <span id="diagnostics-filter-count" class="filter-badge-indicator">すべて</span></summary>
        <div class="filter-panel">
          <div id="diagnostics-checkbox-list" class="checkbox-list">
            %s
          </div>
        </div>
      </details>
      <button id="btn-reset-filters" type="button" class="btn-action">フィルタ解除</button>
    </div>
    <div class="toolbar-row export-controls">
      <div class="status-indicator">
        <span id="visible-row-count" aria-live="polite" class="count-badge">表示 %d / %d 件</span>
        <span id="active-filter-badge" class="active-badge">アクティブ: 0</span>
      </div>
      <div class="export-buttons">
        <button id="btn-export-all" type="button" class="btn-export">全件 CSV 出力</button>
        <button id="btn-export-filtered" type="button" class="btn-export">現在表示中 CSV 出力</button>
      </div>
    </div>
  </div>
', paste(theme_checkbox_items, collapse = "\n"), paste(badge_checkbox_items, collapse = "\n"), nrow(summary_df), nrow(summary_df))

  html_table <- sprintf('  %s
  <div class="table-container">
    <table id="comparative-evidence-table" aria-describedby="guidance-callout">
      <caption>比較エビデンス解析サマリー</caption>
      <thead>
        <tr>
          <th scope="col" class="col-id sortable" aria-sort="none" tabindex="0" role="columnheader">テーマ<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-id sortable" aria-sort="none" tabindex="0" role="columnheader">比較<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-id sortable" aria-sort="none" tabindex="0" role="columnheader">記述N (T / R)<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-id sortable" aria-sort="none" tabindex="0" role="columnheader">記述イベント数 (T / R)<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-effect sortable" aria-sort="none" tabindex="0" role="columnheader">RD 推定値 [区間]<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-effect col-e100 sortable" aria-sort="none" tabindex="0" role="columnheader">100人あたり差 (E100)<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-effect col-reciprocal sortable" aria-sort="none" tabindex="0" role="columnheader">NNT・NNH-like<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-effect sortable" aria-sort="none" tabindex="0" role="columnheader">RR 推定値 [区間]<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-direction sortable" aria-sort="none" tabindex="0" role="columnheader">方向支持指標<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-practical sortable" aria-sort="none" tabindex="0" role="columnheader">実務領域・U-Grade<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-precision sortable" aria-sort="none" tabindex="0" role="columnheader">精度指標 (ESS / 区間幅)<span class="sort-indicator" aria-hidden="true">↕</span></th>
          <th scope="col" class="col-diagnostics sortable" aria-sort="none" tabindex="0" role="columnheader">診断バッジ<span class="sort-indicator" aria-hidden="true">↕</span></th>
        </tr>
      </thead>
      <tbody>
        %s
      </tbody>
    </table>
  </div>
', warning_callout_html, paste(html_rows, collapse = "\n"))

  # Task 14.13: Inferential-semantics adaptive mathematical & usage guide using native details/summary and MathML
  has_bayesian_sem <- any(summary_df$inferential_semantics %in% c("posterior", "bayesian"), na.rm = TRUE)
  has_bootstrap_sem <- any(summary_df$inferential_semantics == "bootstrap", na.rm = TRUE)

  risk_accordion_html <- if (has_bayesian_sem && !has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-risk" class="guide-accordion">\n',
      '      <summary class="guide-summary">1. リスク・発症割合 (Risk / incidence proportion)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>生の記述発症割合（raw descriptive proportion）は標本イベント発生数と観察例数から算出されます：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <msub><mi>p</mi><mrow><mi>T</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>T</mi></msub><msub><mi>n</mi><mi>T</mi></msub></mfrac><mo>,</mo><mspace width="1em"/><msub><mi>p</mi><mrow><mi>R</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>R</mi></msub><msub><mi>n</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <p>独立 Jeffreys 事前分布 Beta(0.5, 0.5) に基づくベイズ推論モデルでは、各群の発症率は次の事後分布に従います：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <msub><mi>p</mi><mi>g</mi></msub><mo>∣</mo><msub><mi>x</mi><mi>g</mi></msub><mo>,</mo><msub><mi>n</mi><mi>g</mi></msub><mo>∼</mo><mi>Beta</mi><mrow><mo>(</mo><msub><mi>x</mi><mi>g</mi></msub><mo>+</mo><mfrac><mn>1</mn><mn>2</mn></mfrac><mo>,</mo><mspace width="0.2em"/><msub><mi>n</mi><mi>g</mi></msub><mo>−</mo><msub><mi>x</mi><mi>g</mi></msub><mo>+</mo><mfrac><mn>1</mn><mn>2</mn></mfrac><mo>)</mo></mrow>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>推論上の点推定値（inferential point estimate）には事後中央値（posterior median, estimate.source = posterior_median）を用い、不確実性は事後等裾信用区間（95% ETI）で評価します。これらは生の記述割合（target_prop / reference_prop）と峻別して解釈します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>イベント数ゼロであっても Jeffreys 事前分布により事後中央値および ETI は有限値として適切に定義されますが、極端な疎データでは事前分布の影響を受けやすくなります。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>各治療群・対照群の絶対的な発生水準を客観的に把握する基本指標として使用します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-risk" class="guide-accordion">\n',
      '      <summary class="guide-summary">1. リスク・発症割合 (Risk / incidence proportion)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>生の記述発症割合（raw descriptive proportion）は標本イベント発生数と観察例数から算出されます：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <msub><mi>p</mi><mrow><mi>T</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>T</mi></msub><msub><mi>n</mi><mi>T</mi></msub></mfrac><mo>,</mo><mspace width="1em"/><msub><mi>p</mi><mrow><mi>R</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>R</mi></msub><msub><mi>n</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <p>デザイン考慮型（IPTW / マッチドペア等）のブートストラップ推論では、生の記述割合とともに対象デザインの推論推定量が算出されます。</p>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>推論上の点推定値（inferential point estimate）には標本観測推定量（observed sample estimate, estimate.source = observed_sample_estimate）を用います。事後中央値や事前分布モデルは適用されず、不確実性はブートストラップパーセンタイル区間（Bootstrap 95% percentile interval）およびブートストラップ支持比率 p&#770;* で評価します。これらは生の記述割合と峻別して解釈します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>ブートストラップ推論では再標本化分布から区間や支持割合を算出するため、事後確率としての解釈を行ってはなりません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>各治療群・対照群の絶対的な発生水準を客観的に把握する基本指標として使用します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else {
    paste0(
      '    <details id="guide-item-risk" class="guide-accordion">\n',
      '      <summary class="guide-summary">1. リスク・発症割合 (Risk / incidence proportion)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>生の記述発症割合（raw descriptive proportion）は標本イベント発生数と観察例数から算出されます：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <msub><mi>p</mi><mrow><mi>T</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>T</mi></msub><msub><mi>n</mi><mi>T</mi></msub></mfrac><mo>,</mo><mspace width="1em"/><msub><mi>p</mi><mrow><mi>R</mi><mo>,</mo><mtext>raw</mtext></mrow></msub><mo>=</mo><mfrac><msub><mi>x</mi><mi>R</mi></msub><msub><mi>n</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <p>本レポートには複数の推論セマンティクス（inferential_semantics: bayesian / bootstrap）が混在しており、各行の属性に応じた推論モデルが適用されます：</p>\n',
      '        <ul>\n',
      '          <li><strong>ベイズ推論行 (bayesian)</strong>: 独立 Jeffreys 事前分布 Beta(0.5, 0.5) に基づく事後分布に従います。推論上の点推定値には事後中央値（posterior median, estimate.source = posterior_median）を用い、不確実性は 95% ETI で評価します。</li>\n',
      '          <li><strong>ブートストラップ推論行 (bootstrap)</strong>: 標本観測推定量（observed sample estimate, estimate.source = observed_sample_estimate）を点推定値とし、不確実性はブートストラップ 95% パーセンタイル区間で評価します（事後中央値や Jeffreys 事前分布は適用されません）。</li>\n',
      '        </ul>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>推論上の点推定値（事後中央値または標本観測推定量）は、各行の inferential_semantics 列を確認した上で生の記述割合と峻別して解釈します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>ベイズ推論行とブートストラップ推論行で点推定および区間推定の数理的性質が異なるため、同一の解釈体系として混同してはなりません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>各治療群・対照群の絶対的な発生水準を客観的に把握する基本指標として使用します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  }

  rd_accordion_html <- '    <details id="guide-item-rd" class="guide-accordion">
      <summary class="guide-summary">2. リスク差 (Risk Difference: RD)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>治療群と対照群の絶対的な発生割合の差（primary absolute contrast）です：</p>
        <math display="block">
          <mrow>
            <mi>RD</mi><mo>=</mo><msub><mi>p</mi><mi>T</mi></msub><mo>−</mo><msub><mi>p</mi><mi>R</mi></msub>
          </mrow>
        </math>
        <p>自然単位換算（preferred translation）は E100 = 100 × RD です。二次解釈として reciprocal absolute RD = 1/|RD| を用います。</p>
        <h4>どう読むか (Interpretation)</h4>
        <p>例えば RD = 0.03 は E100 = +3.00 / 100人 に対応します。reciprocal RD は 33.3 人です。Safety かつ STABLE_DIRECTION のときのみ、target_excess → NNH-like、reference_excess → NNT-like と表示します。非 Safety では 1/|RD| 表記のみを用い、NNT/NNH と断定しません。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>逆数RDは canonical RD 点推定値を変換した二次指標であり、primary estimand でも 1/|RD| の事後中央値でもありません。RD 区間が 0 を跨ぐ場合は SIGN_AMBIGUOUS とし、方向付き NNT/NNH-like と単純な逆数区間を抑制します。因果的 NNT を自動主張してはなりません。RD の区間が 0 を跨いでいることは、二群間の「同等性」や「差がないこと」を証明しません。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>公衆衛生や臨床実務において、絶対的な過剰負担や治療効果の規模を直接評価するための一次対比として用います。E100 は読みやすさのための自然単位、reciprocal RD は二次的な補助解釈です。</p>
      </div>
    </details>'

  rr_accordion_html <- if (has_bayesian_sem && !has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-rr" class="guide-accordion">\n',
      '      <summary class="guide-summary">3. 相対リスク (Relative Risk: RR)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>対照群に対する治療群のイベント発生率の比率です：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <mi>RR</mi><mo>=</mo><mfrac><msub><mi>p</mi><mi>T</mi></msub><msub><mi>p</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>RR = 1 は両群同率、RR &gt; 1 は治療群で高頻度、RR &lt; 1 は対照群で高頻度を意味します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>対照群のイベント発生数がゼロ（x_R = 0）の場合、独立 Jeffreys 事後分布では理論的期待値 E(RR) は無限大に発散するため、平均値契約は mean = null, mean_is_finite = false となります（事後中央値および信用区間は有限値として算出可能）。点推定値（中央値）や区間幅が極めて広大になるため、主対比として RD を併用する必要があります。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>病態発症の相対的脆弱性や、対照群に対する相対的な発生リスクの対比を評価する際に用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-rr" class="guide-accordion">\n',
      '      <summary class="guide-summary">3. 相対リスク (Relative Risk: RR)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>対照群に対する治療群のイベント発生率の比率です：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <mi>RR</mi><mo>=</mo><mfrac><msub><mi>p</mi><mi>T</mi></msub><msub><mi>p</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>RR = 1 は両群同率、RR &gt; 1 は治療群で高頻度、RR &lt; 1 は対照群で高頻度を意味します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>対照群のイベント発生数がゼロ（x_R = 0）または定義不能レプリケートが生じた場合、ブートストラップ推論では RR 推定量・区間は利用不能（rr_estimate_available = false）となるか、ブートストラップ診断（rr_bootstrap_undefined_replicates）に従い抑制されます。主対比として RD を併用する必要があります。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>病態発症の相対的脆弱性や、対照群に対する相対的な発生リスクの対比を評価する際に用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else {
    paste0(
      '    <details id="guide-item-rr" class="guide-accordion">\n',
      '      <summary class="guide-summary">3. 相対リスク (Relative Risk: RR)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>対照群に対する治療群のイベント発生率の比率です：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <mi>RR</mi><mo>=</mo><mfrac><msub><mi>p</mi><mi>T</mi></msub><msub><mi>p</mi><mi>R</mi></msub></mfrac>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>RR = 1 は両群同率、RR &gt; 1 は治療群で高頻度、RR &lt; 1 は対照群で高頻度を意味します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>対照群イベントゼロ（x_R = 0）時の挙動は各行の inferential_semantics に準拠します。独立ベイズ推論では理論的期待値 E(RR) が無限大（mean = null, mean_is_finite = false、中央値・信用区間は有限）となる一方、ブートストラップ推論では RR 推定量・区間が利用不能（rr_estimate_available = false）またはブートストラップ診断に従います。いずれの場合も主対比として RD を併用してください。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>病態発症の相対的脆弱性や、対照群に対する相対的な発生リスクの対比を評価する際に用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  }

  intervals_accordion_html <- if (has_bayesian_sem && !has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-intervals" class="guide-accordion">\n',
      '      <summary class="guide-summary">4. 不確実性区間 (Uncertainty Interval: 95% ETI)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>推定値の不確実性を表す 95% 区間です：</p>\n',
      '        <ul>\n',
      '          <li><strong>Bayesian 95% ETI (事後等裾信用区間)</strong>: モデル・事前分布・観測データを条件として、パラメータの事後確率質量の 95% を含む等裾区間（下側 2.5% 点と上側 97.5% 点）。</li>\n',
      '        </ul>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>ベイズ ETI はモデルと事前分布のもとでの事後確信度の範囲を示します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>区間が 0 を跨ぐことは「同等性（二群間に差がないこと）」を証明しません。また、頻回推論の信頼区間と混同してはなりません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>点推定値単独の過信を避け、推定の安定性と幅を考慮した客観的判断を行う際に参照します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-intervals" class="guide-accordion">\n',
      '      <summary class="guide-summary">4. 不確実性区間 (Uncertainty Interval: Bootstrap Percentile)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>推定値の不確実性を表す 95% 区間です：</p>\n',
      '        <ul>\n',
      '          <li><strong>Bootstrap 95% percentile interval (ブートストラップパーセンタイル区間)</strong>: ブートストラップ再標本化で得られた推定量の経験分布の 2.5% 点と 97.5% 点による区間。</li>\n',
      '        </ul>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>ブートストラップパーセンタイル区間は再標本化による推定量自体の標本変動の幅を示し、「パラメータが 95% の確率で区間内にある」とは解釈しません。事後信用区間（ETI）は本推論では使用されていません。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>区間が 0 を跨ぐことは「同等性（二群間に差がないこと）」を証明しません。また、ベイズ信用区間とブートストラップ再標本化区間を混同してはなりません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>点推定値単独の過信を避け、推定の安定性と幅を考慮した客観的判断を行う際に参照します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else {
    paste0(
      '    <details id="guide-item-intervals" class="guide-accordion">\n',
      '      <summary class="guide-summary">4. 不確実性区間 (Uncertainty Interval: ETI vs Bootstrap)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>推定値の不確実性を表す 95% 区間です。推論デザイン（inferential_semantics）に応じて明確に区別されます：</p>\n',
      '        <ul>\n',
      '          <li><strong>Bayesian 95% ETI (事後等裾信用区間)</strong>: ベイズ推論行に適用。モデル・事前分布・観測データを条件として、パラメータの事後確率質量の 95% を含む等裾区間（下側 2.5% 点と上側 97.5% 点）。</li>\n',
      '          <li><strong>Bootstrap 95% percentile interval (ブートストラップパーセンタイル区間)</strong>: ブートストラップ推論行に適用。ブートストラップ再標本化で得られた推定量の経験分布の 2.5% 点と 97.5% 点による区間。</li>\n',
      '        </ul>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>ベイズ ETI はモデルと事前分布のもとでの事後確信度の範囲を示します。一方、ブートストラップパーセンタイル区間は再標本化による推定量自体の標本変動の幅を示し、「パラメータが 95% の確率で区間内にある」とは解釈しません。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>区間が 0 を跨ぐことは「同等性（二群間に差がないこと）」を証明しません。また、ベイズ信用区間とブートストラップ再標本化区間、頻回推論の信頼区間を混同してはなりません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>点推定値単独の過信を避け、推定の安定性と幅を考慮した客観的判断を行う際に参照します。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  }

  direction_accordion_html <- if (has_bayesian_sem && !has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-direction" class="guide-accordion">\n',
      '      <summary class="guide-summary">5. 方向支持指標 (Direction Support: Posterior Probability)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>効果の方向が正（RD &gt; 0）であるベイズ事後確率です：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <mi>P</mi><mrow><mo>(</mo><mi>RD</mi><mo>&gt;</mo><mn>0</mn><mo>∣</mo><mi>data</mi><mo>)</mo></mrow>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>0.5 は方向が中立、1.0 に近いほど治療群での増加、0.0 に近いほど対照群での増加を強く支持します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>高い方向支持（例: 0.99）であっても、効果の大きさ（臨床的重要性）や治療の因果的優越性を単独で証明するものではありません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>効果の方向性に関する確信度をスクリーニングする際の補助指標として用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else if (!has_bayesian_sem && has_bootstrap_sem) {
    paste0(
      '    <details id="guide-item-direction" class="guide-accordion">\n',
      '      <summary class="guide-summary">5. 方向支持指標 (Direction Support: Bootstrap Fraction)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>効果の方向が正（RD &gt; 0）であるブートストラップ再標本化レプリケートの比率（支持比率）です：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <msup><mover><mi>p</mi><mo stretchy="false">^</mo></mover><mo>*</mo></msup><mo>=</mo><mfrac><mn>1</mn><mi>B</mi></mfrac><munderover><mo>∑</mo><mrow><mi>b</mi><mo>=</mo><mn>1</mn></mrow><mi>B</mi></munderover><mi>I</mi><mrow><mo>(</mo><msubsup><mi>RD</mi><mi>b</mi><mo>*</mo></msubsup><mo>&gt;</mo><mn>0</mn><mo>)</mo></mrow>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>0.5 は方向が中立、1.0 に近いほど治療群での増加、0.0 に近いほど対照群での増加を強く支持します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>高い支持比率であっても、効果の大きさ（臨床的重要性）や治療の因果的優越性を単独で証明するものではありません。事後確率としての解釈は行いません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>効果の方向性に関する確信度をスクリーニングする際の補助指標として用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  } else {
    paste0(
      '    <details id="guide-item-direction" class="guide-accordion">\n',
      '      <summary class="guide-summary">5. 方向支持指標 (Direction Support)</summary>\n',
      '      <div class="guide-content">\n',
      '        <h4>定義 (Definition)</h4>\n',
      '        <p>効果の方向が正（RD &gt; 0）である確率または割合です（inferential_semantics に準拠）：</p>\n',
      '        <math display="block">\n',
      '          <mrow>\n',
      '            <mi>P</mi><mrow><mo>(</mo><mi>RD</mi><mo>&gt;</mo><mn>0</mn><mo>∣</mo><mi>data</mi><mo>)</mo></mrow><mspace width="1em"/><mtext>(ベイズ)</mtext><mo>,</mo><mspace width="1em"/><msup><mover><mi>p</mi><mo stretchy="false">^</mo></mover><mo>*</mo></msup><mo>=</mo><mfrac><mn>1</mn><mi>B</mi></mfrac><munderover><mo>∑</mo><mrow><mi>b</mi><mo>=</mo><mn>1</mn></mrow><mi>B</mi></munderover><mi>I</mi><mrow><mo>(</mo><msubsup><mi>RD</mi><mi>b</mi><mo>*</mo></msubsup><mo>&gt;</mo><mn>0</mn><mo>)</mo></mrow><mspace width="1em"/><mtext>(ブートストラップ)</mtext>\n',
      '          </mrow>\n',
      '        </math>\n',
      '        <h4>どう読むか (Interpretation)</h4>\n',
      '        <p>0.5 は方向が中立、1.0 に近いほど治療群での増加、0.0 に近いほど対照群での増加を強く支持します。</p>\n',
      '        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>\n',
      '        <p>高い方向支持であっても、効果の大きさ（臨床的重要性）や治療の因果的優越性を単独で証明するものではありません。</p>\n',
      '        <h4>いつ使うか (When to Use)</h4>\n',
      '        <p>効果の方向性に関する確信度をスクリーニングする際の補助指標として用います。</p>\n',
      '      </div>\n',
      '    </details>'
    )
  }

  rd_accordion_html <- '    <details id="guide-item-rd" class="guide-accordion">
      <summary class="guide-summary">2. リスク差 (Risk Difference: RD)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>治療群と対照群の絶対的な発生割合の差（primary absolute contrast）です：</p>
        <math display="block">
          <mrow>
            <mi>RD</mi><mo>=</mo><msub><mi>p</mi><mi>T</mi></msub><mo>−</mo><msub><mi>p</mi><mi>R</mi></msub>
          </mrow>
        </math>
        <p>自然単位換算（preferred translation）は E100 = 100 × RD です。二次解釈として reciprocal absolute RD = 1/|RD| を用います。</p>
        <h4>どう読むか (Interpretation)</h4>
        <p>例えば RD = 0.03 は E100 = +3.00 / 100人 に対応します。reciprocal RD は 33.3 人です。Safety かつ STABLE_DIRECTION のときのみ、target_excess → NNH-like、reference_excess → NNT-like と表示します。非 Safety では 1/|RD| 表記のみを用い、NNT/NNH と断定しません。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>逆数RDは canonical RD 点推定値を変換した二次指標であり、primary estimand でも 1/|RD| の事後中央値でもありません。RD 区間が 0 を跨ぐ場合は SIGN_AMBIGUOUS とし、方向付き NNT/NNH-like と単純な逆数区間を抑制します。因果的 NNT を自動主張してはなりません。RD の区間が 0 を跨いでいることは、二群間の「同等性」や「差がないこと」を証明しません。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>公衆衛生や臨床実務において、絶対的な過剰負担や治療効果の規模を直接評価するための一次対比として用います。E100 は読みやすさのための自然単位、reciprocal RD は二次的な補助解釈です。</p>
      </div>
    </details>'

  practical_accordion_html <- '    <details id="guide-item-practical" class="guide-accordion">
      <summary class="guide-summary">6. 実務領域と一次対比閾値 (Practical Difference Regions &amp; primary_delta)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>承認された実務閾値 δ &gt; 0（primary_delta）に基づき、不確実性分布を3領域に分割します：</p>
        <math display="block">
          <mrow>
            <msub><mi>q</mi><mi>T</mi></msub><mo>=</mo><mi>P</mi><mrow><mo>(</mo><mi>RD</mi><mo>&gt;</mo><mi>δ</mi><mo>)</mo></mrow><mo>,</mo><mspace width="0.8em"/><msub><mi>q</mi><mi>N</mi></msub><mo>=</mo><mi>P</mi><mrow><mo>(</mo><mo>−</mo><mi>δ</mi><mo>≤</mo><mi>RD</mi><mo>≤</mo><mi>δ</mi><mo>)</mo></mrow><mo>,</mo><mspace width="0.8em"/><msub><mi>q</mi><mi>R</mi></msub><mo>=</mo><mi>P</mi><mrow><mo>(</mo><mi>RD</mi><mo>&lt;</mo><mo>−</mo><mi>δ</mi><mo>)</mo></mrow>
          </mrow>
        </math>
        <math display="block">
          <mrow>
            <msub><mi>q</mi><mi>T</mi></msub><mo>+</mo><msub><mi>q</mi><mi>N</mi></msub><mo>+</mo><msub><mi>q</mi><mi>R</mi></msub><mo>=</mo><mn>1</mn>
          </mrow>
        </math>
        <h4>どう読むか (Interpretation)</h4>
        <p>最大確率を占める領域を優勢領域（dominant_region: target_excess, practical_neutral, reference_excess）として識別します。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>primary_delta が未指定（null）の場合、実務領域分類は無効化（none）され、セルのハイライト配色は行われません。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>統計的有意性だけでなく、実務上意味のある差が存在するかを領域確率として評価する際に用います。</p>
      </div>
    </details>'

  ugrade_accordion_html <- '    <details id="guide-item-ugrade" class="guide-accordion">
      <summary class="guide-summary">7. 実務領域解像度グレード (Practical-Region Resolution Grade: U-Grade)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>最大領域確率 C = max(q_T, q_N, q_R) に基づき、優勢領域への収まり具合を等級化します：</p>
        <ul>
          <li><strong>U0 (高確信)</strong>: C ≥ 0.95</li>
          <li><strong>U1 (中高確信)</strong>: 0.80 ≤ C &lt; 0.95</li>
          <li><strong>U2 (中確信)</strong>: 0.60 ≤ C &lt; 0.80</li>
          <li><strong>U3 (未解像・不確実)</strong>: C &lt; 0.60</li>
          <li><strong>NONE</strong>: primary_delta が null の場合</li>
        </ul>
        <h4>どう読むか (Interpretation)</h4>
        <p>U0 や U1 は優勢領域への所属が明確であり、U3 はどの領域にも偏らず不確実性が高い状態を示します。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>U-Grade は「不確実性分布の実務領域への解像度」であり、サンプルの大きさ（精度）や有害事象の臨床的重症度を意味するものではありません。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>探索的スクリーニングにおいて、結果の確信度に基づく優先度付けや追加調査の要否を判断する際に用います。</p>
      </div>
    </details>'

  precision_accordion_html <- '    <details id="guide-item-precision" class="guide-accordion">
      <summary class="guide-summary">8. 連続精度指標と有効標本サイズ (Precision Metrics &amp; ESS)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>推定値の精度を連続尺度で評価します：</p>
        <math display="block">
          <mrow>
            <msub><mi>RD</mi><mtext>width</mtext></msub><mo>=</mo><msub><mi>RD</mi><mtext>upper</mtext></msub><mo>−</mo><msub><mi>RD</mi><mtext>lower</mtext></msub><mo>,</mo><mspace width="1em"/><msub><mi>RR</mi><mtext>fold</mtext></msub><mo>=</mo><mfrac><msub><mi>RR</mi><mtext>upper</mtext></msub><msub><mi>RR</mi><mtext>lower</mtext></msub></mfrac>
          </mrow>
        </math>
        <h4>どう読むか (Interpretation)</h4>
        <p>区間幅が狭いほど推定が高精度であることを示します。IPTW などの重み付けデザインでは、有効標本サイズ（ESS）が観察標本数 N より小さくなります。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>精度（区間幅の狭さ）と実務的確信度（U-Grade）は異なる次元です。高精度であっても閾値境界上にあれば U3 となることがあります。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>研究のデザイン品質やデータ規模の十分性を客観的に評価する際に用います。</p>
      </div>
    </details>'

  diagnostics_accordion_html <- '    <details id="guide-item-diagnostics" class="guide-accordion">
      <summary class="guide-summary">9. 診断バッジと数値安定性 (Diagnostic Badges &amp; Numerical Stability)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>数値計算の安定性や疎データに関する警告バッジです：</p>
        <ul>
          <li><strong>ZERO_REFERENCE</strong>: 対照群イベント数ゼロ (x_R = 0)</li>
          <li><strong>ZERO_BOTH</strong>: 両群ともにイベント数ゼロ (x_T = 0, x_R = 0)</li>
          <li><strong>SPARSE_EVENTS</strong>: イベント発生数が極めて疎 (&lt; 5)</li>
          <li><strong>UNSTABLE_RR_INTERVAL</strong>: RR 区間幅が過度に広大 (fold range &gt; 100)</li>
        </ul>
        <h4>どう読むか (Interpretation)</h4>
        <p>バッジが付与されている項目は、比率指標（RR）の解釈に注意が必要であり、絶対指標（RD）を重視すべきです。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>診断バッジはデータの信頼性を全否定するものではなく、どの指標を主として解釈すべきかを示すガイドです。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>多テーマ解析において数値的異常値や発散セルを素早く特定し、安全な解釈を行うために用います。</p>
      </div>
    </details>'

  multiplicity_accordion_html <- '    <details id="guide-item-multiplicity" class="guide-accordion">
      <summary class="guide-summary">10. 多重比較・探索的スクリーニング利用指針 (Multiplicity &amp; Exploratory Use Guidance)</summary>
      <div class="guide-content">
        <h4>定義 (Definition)</h4>
        <p>多数の有害事象（PT）や項目を一括スクリーニングする際の統計的指針です。</p>
        <h4>どう読むか (Interpretation)</h4>
        <p>本解析では家族ワイズ第1種過誤率（FWER）や偽発見率（FDR）の厳格な調整は行われておらず、各テーマの独立推論を並列表示しています。</p>
        <h4>注意点・禁止解釈 (Cautions &amp; Invariants)</h4>
        <p>探索的スクリーニングで得られた高支持度や低 P 値を、単独で薬事承認や規制判断の決定的根拠としてはなりません。</p>
        <h4>いつ使うか (When to Use)</h4>
        <p>シグナル検出、仮説生成、専門家による詳細評価の優先順位付けを行う際に活用します。</p>
      </div>
    </details>'

  html_guide <- paste0(
    '  <section id="metric-guide" aria-label="統計指標の数学的解説と利用ガイド">\n',
    '    <h2>統計指標の数学的解説と利用ガイド</h2>\n\n',
    risk_accordion_html, '\n\n',
    rd_accordion_html, '\n\n',
    rr_accordion_html, '\n\n',
    intervals_accordion_html, '\n\n',
    direction_accordion_html, '\n\n',
    practical_accordion_html, '\n\n',
    ugrade_accordion_html, '\n\n',
    precision_accordion_html, '\n\n',
    diagnostics_accordion_html, '\n\n',
    multiplicity_accordion_html, '\n',
    '  </section>\n'
  )

  # Task 14.11: Embedded canonical data JSON
  html_json <- sprintf('  <script id="comparative-summary-data" type="application/json">%s</script>
', json_summary_data)

  # Task 14.10, 14.11, 14.12: Combined sort, filter, and CSV export script
  html_script <- '  <script>
    document.addEventListener("DOMContentLoaded", function() {
      var table = document.getElementById("comparative-evidence-table");
      if (!table) return;
      var headers = table.querySelectorAll("thead th.sortable");
      var tbody = table.querySelector("tbody");
      if (!tbody) return;

      var rawSummaryScript = document.getElementById("comparative-summary-data");
      var summaryData = rawSummaryScript ? JSON.parse(rawSummaryScript.textContent) : [];
      var summaryMap = {};
      summaryData.forEach(function(row) {
        if (row.row_key) summaryMap[row.row_key] = row;
      });

      /* --- Filter State & Application (Task 14.12) --- */
      var themeCheckboxes = Array.from(document.querySelectorAll(".filter-theme"));
      var regionCheckboxes = Array.from(document.querySelectorAll(".filter-region"));
      var ugradeCheckboxes = Array.from(document.querySelectorAll(".filter-ugrade"));
      var badgeCheckboxes = Array.from(document.querySelectorAll(".filter-badge-opt"));
      var themeSearchInput = document.getElementById("theme-search-input");
      var btnReset = document.getElementById("btn-reset-filters");
      var visibleCountEl = document.getElementById("visible-row-count");
      var activeFilterEl = document.getElementById("active-filter-badge");
      var themeCountEl = document.getElementById("theme-filter-count");
      var practicalCountEl = document.getElementById("practical-filter-count");
      var diagCountEl = document.getElementById("diagnostics-filter-count");

      function applyFilters() {
        var selThemes = themeCheckboxes.filter(function(cb) { return cb.checked; }).map(function(cb) { return cb.value; });
        var selRegions = regionCheckboxes.filter(function(cb) { return cb.checked; }).map(function(cb) { return cb.value; });
        var selUgrades = ugradeCheckboxes.filter(function(cb) { return cb.checked; }).map(function(cb) { return cb.value; });
        var selBadges = badgeCheckboxes.filter(function(cb) { return cb.checked; }).map(function(cb) { return cb.value; });

        var activeCount = (selThemes.length > 0 ? 1 : 0) +
                          (selRegions.length > 0 ? 1 : 0) +
                          (selUgrades.length > 0 ? 1 : 0) +
                          (selBadges.length > 0 ? 1 : 0);

        if (activeFilterEl) {
          activeFilterEl.textContent = "アクティブ: " + activeCount;
        }
        if (themeCountEl) {
          themeCountEl.textContent = selThemes.length > 0 ? selThemes.length + " 件選択" : "すべて";
        }
        if (practicalCountEl) {
          var pCount = selRegions.length + selUgrades.length;
          practicalCountEl.textContent = pCount > 0 ? pCount + " 件選択" : "すべて";
        }
        if (diagCountEl) {
          diagCountEl.textContent = selBadges.length > 0 ? selBadges.length + " 件選択" : "すべて";
        }

        var rows = Array.from(tbody.querySelectorAll("tr"));
        var visibleRows = 0;

        rows.forEach(function(row) {
          var rowTheme = row.getAttribute("data-theme") || "";
          var rowRegion = row.getAttribute("data-region") || "";
          var rowUgrade = row.getAttribute("data-ugrade") || "";
          var rowBadgesStr = row.getAttribute("data-badges") || "";
          var rowBadges = rowBadgesStr ? rowBadgesStr.split(";").map(function(s) { return s.trim(); }) : [];

          var themeMatch = (selThemes.length === 0) || (selThemes.indexOf(rowTheme) !== -1);
          var regionMatch = (selRegions.length === 0) || (selRegions.indexOf(rowRegion) !== -1);
          var ugradeMatch = (selUgrades.length === 0) || (selUgrades.indexOf(rowUgrade) !== -1);

          var badgeMatch = true;
          if (selBadges.length > 0) {
            badgeMatch = selBadges.some(function(b) {
              if (b === "__NONE__") {
                return rowBadges.length === 0 || rowBadgesStr === "";
              }
              return rowBadges.indexOf(b) !== -1;
            });
          }

          var isVisible = themeMatch && (regionMatch && ugradeMatch) && badgeMatch;
          row.style.display = isVisible ? "" : "none";
          if (isVisible) visibleRows++;
        });

        if (visibleCountEl) {
          visibleCountEl.textContent = "表示 " + visibleRows + " / " + rows.length + " 件";
        }
      }

      /* Theme search text filtering inside panel */
      if (themeSearchInput) {
        themeSearchInput.addEventListener("input", function() {
          var query = themeSearchInput.value.trim().toLowerCase();
          var items = document.querySelectorAll("#theme-checkbox-list .filter-item");
          items.forEach(function(item) {
            var text = item.textContent.trim().toLowerCase();
            item.style.display = (query === "" || text.indexOf(query) !== -1) ? "" : "none";
          });
        });
      }

      var allFilterCheckboxes = themeCheckboxes.concat(regionCheckboxes, ugradeCheckboxes, badgeCheckboxes);
      allFilterCheckboxes.forEach(function(cb) {
        cb.addEventListener("change", applyFilters);
      });

      if (btnReset) {
        btnReset.addEventListener("click", function() {
          allFilterCheckboxes.forEach(function(cb) { cb.checked = false; });
          if (themeSearchInput) {
            themeSearchInput.value = "";
            var items = document.querySelectorAll("#theme-checkbox-list .filter-item");
            items.forEach(function(item) { item.style.display = ""; });
          }
          applyFilters();
        });
      }

      /* --- CSV Export (Task 14.11) --- */
      function escapeCsvCell(val) {
        if (val === null || val === undefined) return "";
        var str = String(val);
        if (str.indexOf(",") !== -1 || str.indexOf(\'"\') !== -1 || str.indexOf("\\n") !== -1 || str.indexOf("\\r") !== -1) {
          return \'"\' + str.replace(/"/g, \'""\') + \'"\';
        }
        return str;
      }

      function generateCsv(rowsData, filename) {
        if (!rowsData || rowsData.length === 0) return;
        var headers = Object.keys(rowsData[0]).filter(function(h) { return h !== "row_key"; });
        var csvLines = [];
        /* Header */
        csvLines.push(headers.map(escapeCsvCell).join(","));
        /* Rows */
        rowsData.forEach(function(row) {
          var line = headers.map(function(h) {
            return escapeCsvCell(row[h]);
          }).join(",");
          csvLines.push(line);
        });
        /* UTF-8 BOM + CRLF */
        var csvContent = "\\uFEFF" + csvLines.join("\\r\\n") + "\\r\\n";
        var blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }

      var btnExportAll = document.getElementById("btn-export-all");
      var btnExportFiltered = document.getElementById("btn-export-filtered");

      if (btnExportAll) {
        btnExportAll.addEventListener("click", function() {
          generateCsv(summaryData, "comparative_summary_all.csv");
        });
      }

      if (btnExportFiltered) {
        btnExportFiltered.addEventListener("click", function() {
          var rows = Array.from(tbody.querySelectorAll("tr"));
          var filteredData = [];
          rows.forEach(function(row) {
            if (row.style.display !== "none") {
              var rKey = row.getAttribute("data-row-key");
              if (rKey && summaryMap[rKey]) {
                filteredData.push(summaryMap[rKey]);
              }
            }
          });
          generateCsv(filteredData, "comparative_summary_filtered.csv");
        });
      }

      /* --- Sort Table Logic (Task 14.10) --- */
      headers.forEach(function(header, colIndex) {
        function sortTable() {
          var currentSort = header.getAttribute("aria-sort") || "none";
          var newSort = (currentSort === "ascending") ? "descending" : "ascending";

          headers.forEach(function(h) {
            h.setAttribute("aria-sort", "none");
            var ind = h.querySelector(".sort-indicator");
            if (ind) ind.textContent = "↕";
          });
          header.setAttribute("aria-sort", newSort);
          var activeIndicator = header.querySelector(".sort-indicator");
          if (activeIndicator) {
            activeIndicator.textContent = (newSort === "ascending") ? "▲" : "▼";
          }

          var isNumeric = header.classList.contains("col-effect") ||
                          header.classList.contains("col-direction") ||
                          header.classList.contains("col-precision");
          var isUgrade = header.classList.contains("col-practical");

          var rows = Array.from(tbody.querySelectorAll("tr"));
          /* Decorate with original index for stable sort */
          var decorated = rows.map(function(row, idx) {
            return { row: row, index: idx };
          });

          decorated.sort(function(a, b) {
            var cellA = a.row.children[colIndex];
            var cellB = b.row.children[colIndex];
            var valA = cellA.getAttribute("data-sort-value") !== null ? cellA.getAttribute("data-sort-value") : cellA.textContent.trim();
            var valB = cellB.getAttribute("data-sort-value") !== null ? cellB.getAttribute("data-sort-value") : cellB.textContent.trim();

            /* N/A or empty handling: always sort to bottom regardless of sort direction */
            var aEmpty = (valA === "" || valA === "N/A" || valA === "__NA__");
            var bEmpty = (valB === "" || valB === "N/A" || valB === "__NA__");
            if (aEmpty && bEmpty) return a.index - b.index;
            if (aEmpty) return 1;
            if (bEmpty) return -1;

            var cmp = 0;
            if (isNumeric) {
              var numA = parseFloat(valA);
              var numB = parseFloat(valB);
              if (!isNaN(numA) && !isNaN(numB)) {
                cmp = numA - numB;
              } else {
                cmp = valA.localeCompare(valB);
              }
            } else if (isUgrade) {
              /* U-Grade ordinal comparison by prefix integer */
              cmp = valA.localeCompare(valB);
            } else {
              cmp = valA.localeCompare(valB, undefined, { numeric: true, sensitivity: "base" });
            }

            if (cmp !== 0) {
              return (newSort === "ascending") ? cmp : -cmp;
            }
            return a.index - b.index; /* Stable tie-breaker */
          });

          decorated.forEach(function(item) {
            tbody.appendChild(item.row);
          });
        }

        header.addEventListener("click", sortTable);
        header.addEventListener("keydown", function(e) {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            sortTable();
          }
        });
      });
    });
  </script>
</body>
</html>'

  html_content <- paste0(html_head, html_toolbar, html_table, html_guide, html_json, html_script)

  writeLines(html_content, html_path)

  manifest <- write_results_manifest(run_output_dir, "vcd-categorical-reporting", list(
    list(path = "comparative_evidence.json", role = "primary_results"),
    list(path = "comparative_summary.csv", role = "summary_table"),
    list(path = "comparative_report.md", role = "summary_report"),
    list(path = "dashboard.html", role = "report_html")
  ))
  input_record <- if (is.null(input_data_path)) list(list(
    role = "data", source_kind = "builtin", source_path = "in_memory_data_frame",
    logical_label = "in_memory_data_frame", sha256 = df_sha256
  )) else NULL
  write_run_meta(
    out_root = out_root, run_output_dir = run_output_dir, skill = "vcd-categorical-reporting",
    run_id = if (!is.null(run_id)) run_id else basename(run_output_dir),
    input_data_path = input_data_path,
    extra = list(results_manifest_sha256 = manifest$manifest_sha256,
      inputs = input_record, config_origin = "api_arguments", data_frame_sha256 = df_sha256,
      data_frame_hash_contract = "R-serialize-v2: column names, types, classes, values, row order",
      delta_thresholds = delta_thresholds)
  )
  verify_results_manifest(run_output_dir, manifest$manifest_sha256)

  list(
    run_output_dir = run_output_dir,
    json_path = json_path,
    csv_path = csv_path,
    md_path = md_path,
    html_path = html_path,
    summary_df = summary_df
  )
}
