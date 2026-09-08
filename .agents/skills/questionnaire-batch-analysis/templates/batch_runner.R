#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
  pacman::p_load(optparse, jsonlite, ggplot2)
})

# run_scope.R の読み込み
find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    p <- file.path(d, ".agents", "shared", "run_scope.R")
    if (file.exists(p)) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  getwd()
}
source(file.path(find_agent_repo(), ".agents", "shared", "run_scope.R"))

runner_file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_dir <- if (length(runner_file_arg) > 0L) {
  dirname(normalizePath(sub("^--file=", "", runner_file_arg[1L]), mustWork = TRUE))
} else {
  getwd()
}
source(file.path(runner_dir, "marginal_strata_contract.R"))

option_list <- list(
  optparse::make_option("--data", type = "character"),
  optparse::make_option("--config", type = "character", help = "Path to analysis_config.json (Pass 0)"),
  optparse::make_option("--question-config", type = "character", help = "Path to question config CSV"),
  optparse::make_option("--out", type = "character", default = "./skill_out/questionnaire"),
  optparse::make_option("--run-id", type = "character", default = NULL),
  optparse::make_option("--supersedes-run", type = "character", help = "Path to superseded run directory"),
  optparse::make_option("--supersede-reason", type = "character", help = "Reason for superseding previous run")
)
opt <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

cfg_json <- NULL
# JSON 設定の読み込み (Pass 0 連携用)
if (!is.null(opt$config) && file.exists(opt$config)) {
  message("[INFO] 共通設定ファイルを読み込み中: ", opt$config)
  cfg_json <- jsonlite::fromJSON(opt$config, simplifyVector = FALSE)
  if (!is.null(cfg_json$input)) opt$data <- cfg_json$input
  if (!is.null(cfg_json$question_config)) opt$`question-config` <- cfg_json$question_config
  if (!is.null(cfg_json$output_dir)) opt$out <- cfg_json$output_dir
  if (!is.null(cfg_json$run_id) && is.null(opt$`run-id`)) opt$`run-id` <- cfg_json$run_id
  if (!is.null(cfg_json$supersedes_run) && is.null(opt$`supersedes-run`)) opt$`supersedes-run` <- cfg_json$supersedes_run
  if (!is.null(cfg_json$supersede_reason) && is.null(opt$`supersede-reason`)) opt$`supersede-reason` <- cfg_json$supersede_reason
}

stopifnot(!is.null(opt$data), file.exists(opt$data))
stopifnot(!is.null(opt$`question-config`), file.exists(opt$`question-config`))

df <- utils::read.csv(opt$data, stringsAsFactors = FALSE, na.strings = c("", "NA"))
cfg <- utils::read.csv(
  opt$`question-config`,
  stringsAsFactors = FALSE,
  colClasses = "character",
  na.strings = "",
  check.names = FALSE
)

sanitize_cfg_var <- function(x) {
  if (length(x) != 1L) {
    return("")
  }
  if (is.na(x)) {
    return("")
  }
  s <- trimws(as.character(x))
  if (!nzchar(s)) {
    return("")
  }
  s
}

required_cols <- c("survey_id", "question_id", "analysis_type", "var1", "var2", "var3", "output_slug", "question_label", "subset_expr", "na_policy", "ordered_levels", "reference_note")
stopifnot(all(required_cols %in% names(cfg)))

non_slug_cols <- setdiff(names(cfg), "output_slug")
cfg[non_slug_cols] <- lapply(cfg[non_slug_cols], function(values) {
  na_sentinel <- !is.na(values) & values == "NA"
  values[na_sentinel] <- NA_character_
  values
})

normalize_slug_alias_key <- function(slug) {
  slash_slug <- gsub("\\", "/", slug, fixed = TRUE)
  parts <- strsplit(slash_slug, "/", fixed = TRUE)[[1L]]
  parts <- parts[nzchar(parts) & parts != "."]
  tolower(paste(parts, collapse = "/"))
}

slugs <- as.character(cfg$output_slug)
slug_alias_keys <- vapply(trimws(slugs), normalize_slug_alias_key, character(1))
dup_slugs <- unique(slug_alias_keys[duplicated(slug_alias_keys)])
if (length(dup_slugs) > 0L) {
  stop(
    "output_slug が重複または同一実パスを表しています（成果物が上書きされます）: ",
    paste(dup_slugs, collapse = ", "),
    "。各設問に一意な output_slug を設定してください。"
  )
}

ascii_slug_pattern <- "^[A-Za-z0-9]([A-Za-z0-9._-]{0,98}[A-Za-z0-9_-])?$"
slug_length <- nchar(slugs, type = "chars", allowNA = TRUE)
valid_ascii_slug <- !is.na(slugs) &
  slug_length >= 1L &
  slug_length <= 100L &
  grepl(ascii_slug_pattern, slugs, perl = TRUE)
invalid_slug <- !valid_ascii_slug
if (any(invalid_slug)) {
  stop(
    "output_slug は1〜100文字の安全な単一ASCII slug成分である必要があります: ",
    paste(unique(slugs[invalid_slug]), collapse = ", "),
    "。先頭は英数字、使用可能文字は英数字・.・_・-、末尾は英数字・_・-です。"
  )
}

windows_name_base <- toupper(sub("\\..*$", "", slugs))
windows_reserved <- grepl(
  "^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$",
  windows_name_base
)
if (any(windows_reserved)) {
  stop(
    "output_slug にWindows予約名は使用できません（拡張子付きも禁止）: ",
    paste(unique(slugs[windows_reserved]), collapse = ", ")
  )
}
cfg$output_slug <- slugs

base_out <- opt$out
# 親ディレクトリ検証 (FAIL-FAST)
assert_valid_out_root(base_out)

if (dir.exists(base_out)) {
  base_out_real <- normalizePath(base_out, mustWork = TRUE)
  base_out_prefix <- paste0(base_out_real, .Platform$file.sep)
  for (slug in slugs) {
    slug_path <- file.path(base_out, slug)
    if (file.exists(slug_path) || dir.exists(slug_path)) {
      slug_path_real <- normalizePath(slug_path, mustWork = TRUE)
      if (!startsWith(slug_path_real, base_out_prefix)) {
        stop("output_slug の既存パスが出力root外を指しています: ", slug)
      }
    }
  }
}

rid <- if (!is.null(opt$`run-id`) && nzchar(trimws(opt$`run-id`))) trimws(as.character(opt$`run-id`)) else NULL
if (!is.null(rid)) {
  if (tolower(rid) == "auto") {
    rid <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
  } else {
    rid <- gsub("[/\\\\]", "_", rid)
    rid <- gsub("^\\.+|\\.+$", "", rid)
  }
}

# 原子的な run ディレクトリの予約・作成 (親直下出力廃止、runs/<id> 強制隔離)
out_dir <- reserve_run_output_dir(base_out, "questionnaire-batch-analysis", rid)
resolved_run_id <- basename(out_dir)
message("[INFO] run 出力先: ", out_dir)

# supersede 元の検証 (指定時)
supersedes_run <- opt$`supersedes-run`
superseded_results_manifest_sha256 <- NULL
supersede_info <- NULL
if (!is.null(supersedes_run) && nzchar(trimws(supersedes_run))) {
  supersede_info <- verify_superseded_run(supersedes_run, "questionnaire-batch-analysis", current_run_dir = out_dir)
  superseded_results_manifest_sha256 <- supersede_info$superseded_results_manifest_sha256
  message("[INFO] supersede 元 run 検証合格: ", supersedes_run)
}

# 設定スナップショットの保存
if (is.null(cfg_json)) {
  cfg_json <- list(
    input = opt$data,
    question_config = opt$`question-config`,
    output_dir = base_out,
    run_id = resolved_run_id
  )
}
cfg_snap <- save_config_snapshot(out_dir, if (!is.null(opt$config)) opt$config else cfg_json, config_origin = if (!is.null(opt$config)) "pass0_file" else "resolved_cli", config_source_path = opt$config)

save_config_snapshot(out_dir, opt$`question-config`, file_name = "question_config.csv")

detect_jp_font <- function() {
  os <- Sys.info()[["sysname"]]
  candidates <- switch(os,
    "Darwin"  = c("Hiragino Sans", "HiraginoSans-W3", "Hiragino Kaku Gothic Pro"),
    "Windows" = c("Yu Gothic", "Meiryo", "MS Gothic"),
    "Linux"   = c("Noto Sans CJK JP", "IPAexGothic", "IPAGothic"),
    character(0)
  )
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    avail <- unique(systemfonts::system_fonts()$family)
    for (f in candidates) {
      if (f %in% avail) {
        return(f)
      }
    }
  }
  if (length(candidates) > 0L) {
    return(candidates[1L])
  }
  ""
}

cramer_v_2way <- function(tab) {
  tab <- as.matrix(tab)
  if (length(dim(tab)) != 2L) {
    return(NA_real_)
  }
  n <- sum(tab)
  if (!is.finite(n) || n <= 0) {
    return(NA_real_)
  }
  suppressWarnings({
    ct <- chisq.test(tab, correct = FALSE)
  })
  chi2 <- as.numeric(ct$statistic)
  r <- nrow(tab)
  c <- ncol(tab)
  df_star <- min(r - 1L, c - 1L)
  if (df_star <= 0) {
    return(NA_real_)
  }
  v <- sqrt(chi2 / (n * df_star))
  v
}

effect_label <- function(v) {
  if (!is.finite(v)) {
    return(NA_character_)
  }
  if (v < 0.1) {
    return("small")
  }
  if (v < 0.3) {
    return("medium")
  }
  if (v < 0.5) {
    return("large")
  }
  "very_large"
}

max_residual_cell <- function(tab, dimnames_list) {
  suppressWarnings({
    ct <- chisq.test(tab, correct = FALSE)
  })
  r <- ct$residuals
  idx <- which(abs(r) == max(abs(r), na.rm = TRUE), arr.ind = TRUE)[1L, ]
  dn <- dimnames(tab)
  row_name <- if (!is.null(dn[[1L]])) dn[[1L]][idx[1L]] else as.character(idx[1L])
  col_name <- if (!is.null(dn[[2L]])) dn[[2L]][idx[2L]] else as.character(idx[2L])
  paste0(row_name, ":", col_name)
}

make_residual_plot <- function(res, out_png, jp_font = "") {
  df_plot <- data.frame(
    idx = seq_along(res),
    residual = res
  )
  p <- ggplot(df_plot, aes(x = idx, y = residual)) +
    geom_hline(yintercept = c(-1.96, 0, 1.96), linetype = c("dashed", "solid", "dashed"), color = "gray50") +
    geom_point(color = "royalblue", size = 2) +
    labs(x = "Index (cell order)", y = "Pearson residuals vs index") +
    theme_minimal(base_size = 13, base_family = jp_font)
  ggsave(out_png, p, width = 6, height = 4, dpi = 150)
}



out_dir_real <- normalizePath(out_dir, mustWork = TRUE)
out_dir_prefix <- paste0(out_dir_real, .Platform$file.sep)
for (slug in slugs) {
  slug_path <- file.path(out_dir, slug)
  if (file.exists(slug_path) || dir.exists(slug_path)) {
    slug_path_real <- normalizePath(slug_path, mustWork = TRUE)
    if (!startsWith(slug_path_real, out_dir_prefix)) {
      stop("output_slug の既存パスが出力root外を指しています: ", slug)
    }
  }
}

jp_font <- detect_jp_font()
if (!nzchar(jp_font)) jp_font <- ""

rows <- list()
manifest_artifacts <- list()

for (i in seq_len(nrow(cfg))) {
  row <- cfg[i, , drop = FALSE]
  survey_id <- as.character(row$survey_id)
  question_id <- as.character(row$question_id)
  analysis_type <- as.character(row$analysis_type)
  var1 <- sanitize_cfg_var(row$var1)
  var2 <- sanitize_cfg_var(row$var2)
  var3 <- sanitize_cfg_var(row$var3)
  output_slug <- as.character(row$output_slug)
  subset_expr <- as.character(row$subset_expr)
  na_policy <- as.character(row$na_policy)
  ordered_levels <- as.character(row$ordered_levels)
  reference_note <- as.character(row$reference_note)

  q_out <- file.path(out_dir, output_slug)
  fig_dir <- file.path(q_out, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  plot_path <- file.path(fig_dir, "residual_plot.png")
  report_path <- file.path(q_out, "report.html")
  res_json_path <- file.path(q_out, "questionnaire_results.json")

  n_total <- nrow(df)
  n_used <- 0L
  n_missing <- 0L
  statistic_value <- NA_real_
  p_value <- NA_real_
  effect_value <- NA_real_
  cramer_v_marginal <- NA_real_
  cramer_v_df_star <- NA_integer_
  cramer_v_effect_label <- NA_character_
  cramer_v_strata_json <- NA_character_
  cramer_v_strata_mean <- NA_real_
  cramer_v_strata_max <- NA_real_
  cramer_v_strata_max_level <- NA_character_
  marginal_strata_signal <- "none"
  marginal_strata_note <- NA_character_
  max_abs_pearson_res <- NA_real_
  max_residual_cell_val <- NA_character_
  mosaic_rendered <- FALSE
  assoc_rendered <- FALSE
  skip_reason <- ""
  residual_plot_mode <- if (identical(analysis_type, "nominal_3way")) "facet_heatmap" else "dotplot"
  status <- "unknown"
  error_message <- ""

  res_q <- tryCatch(
    {
      sub_df <- df
      if (!is.na(subset_expr) && nzchar(subset_expr)) {
        sub_df <- subset(sub_df, eval(parse(text = subset_expr)))
      }

      vars_needed <- c(var1, var2, var3)
      vars_needed <- vars_needed[nzchar(vars_needed)]

      for (v in vars_needed) {
        if (!v %in% names(sub_df)) {
          stop(paste("Column not found in data:", v))
        }
      }

      use_df <- sub_df[, vars_needed, drop = FALSE]
      if (identical(na_policy, "exclude")) {
        use_df <- na.omit(use_df)
      }

      n_used <<- nrow(use_df)
      n_missing <<- n_total - n_used

      if (n_used == 0L) {
        stop("No observations available (N = 0)")
      }

      if (identical(analysis_type, "nominal_2way") || identical(analysis_type, "likert_2way")) {
        tab <- table(use_df[[var1]], use_df[[var2]])
        ct <- suppressWarnings(chisq.test(tab, correct = FALSE))
        statistic_value <<- as.numeric(ct$statistic)
        p_value <<- as.numeric(ct$p.value)

        cv <- cramer_v_2way(tab)
        effect_value <<- cv
        cramer_v_marginal <<- cv
        cramer_v_effect_label <<- effect_label(cv)
        cramer_v_df_star <<- as.integer(min(nrow(tab) - 1L, ncol(tab) - 1L))

        max_abs_pearson_res <<- max(abs(ct$residuals), na.rm = TRUE)
        max_residual_cell_val <<- max_residual_cell(tab)

        n_cells <- prod(dim(tab))
        mosaic_rendered <<- isTRUE(n_cells <= 36L)
        assoc_rendered <<- isTRUE(n_cells <= 36L)

        make_residual_plot(as.numeric(ct$residuals), plot_path, jp_font)
      } else if (identical(analysis_type, "nominal_3way")) {
        tab3 <- table(use_df[[var1]], use_df[[var2]], use_df[[var3]])
        tab_m <- margin.table(tab3, c(1, 2))
        ct <- suppressWarnings(chisq.test(tab_m, correct = FALSE))
        statistic_value <<- as.numeric(ct$statistic)
        p_value <<- as.numeric(ct$p.value)

        cramer_v_marginal <<- cramer_v_2way(tab_m)
        effect_value <<- cramer_v_marginal
        cramer_v_effect_label <<- effect_label(cramer_v_marginal)
        cramer_v_df_star <<- as.integer(min(nrow(tab_m) - 1L, ncol(tab_m) - 1L))

        max_abs_pearson_res <<- max(abs(ct$residuals), na.rm = TRUE)
        max_residual_cell_val <<- max_residual_cell(tab_m)

        strata_levels <- dimnames(tab3)[[3]]
        strata_v <- setNames(rep(NA_real_, length(strata_levels)), strata_levels)
        for (lv in strata_levels) {
          tab_s <- tab3[, , lv, drop = TRUE]
          strata_v[[lv]] <- cramer_v_2way(tab_s)
        }
        cramer_v_strata_json <<- jsonlite::toJSON(as.list(strata_v), auto_unbox = TRUE)
        finite_strata_v <- strata_v[is.finite(strata_v)]
        if (length(finite_strata_v) > 0L) {
          cramer_v_strata_max <<- max(finite_strata_v)
          cramer_v_strata_max_level <<- names(which.max(strata_v))[1L]
        }

        marginal_strata <- classify_marginal_strata(cramer_v_marginal, strata_v)
        cramer_v_strata_mean <<- marginal_strata$strata_mean
        marginal_strata_signal <<- marginal_strata$signal
        marginal_strata_note <<- marginal_strata$note

        n_cells <- prod(dim(tab3))
        mosaic_rendered <<- isTRUE(n_cells <= 36L)
        assoc_rendered <<- isTRUE(n_cells <= 36L)

        make_residual_plot(as.numeric(ct$residuals), plot_path, jp_font)
      } else {
        stop("Unsupported analysis_type: ", analysis_type)
      }

      # 統計結果の JSON 保存
      results_json <- list(
        survey_id = survey_id,
        question_id = question_id,
        analysis_type = analysis_type,
        n_total = n_total,
        n_used = n_used,
        statistic = list(
          method = "chisq",
          value = statistic_value,
          p_value = p_value
        ),
        residuals = list(
          max_abs = max_abs_pearson_res,
          max_cell = max_residual_cell_val
        ),
        plots = list(
          mosaic_rendered = mosaic_rendered,
          assoc_rendered = assoc_rendered
        )
      )
      jsonlite::write_json(results_json, res_json_path, auto_unbox = TRUE, pretty = TRUE)

      html <- c(
        "<!doctype html>",
        "<html><head><meta charset=\"utf-8\"><title>Report</title></head><body>",
        sprintf("<h1>%s</h1>", ifelse(is.na(row$question_label), "Report", row$question_label)),
        "<h2>Residual plot</h2>",
        "<p>Pearson residuals vs index</p>",
        "<img src=\"figures/residual_plot.png\" alt=\"residual plot\">",
        "</body></html>"
      )
      writeLines(html, report_path, useBytes = TRUE)

      items <- list(
        list(
          path = file.path(output_slug, "questionnaire_results.json"),
          role = "question_result",
          question_id = question_id
        ),
        list(
          path = file.path(output_slug, "report.html"),
          role = "canonical_result",
          question_id = question_id
        )
      )
      if (file.exists(plot_path)) {
        items[[length(items) + 1L]] <- list(
          path = file.path(output_slug, "figures", "residual_plot.png"),
          role = "figure",
          question_id = question_id
        )
      }

      list(status = "success", error_message = "", skip_reason = "", manifest_items = items)
    },
    error = function(e) {
      err_msg <- conditionMessage(e)
      list(status = "error", error_message = err_msg, skip_reason = err_msg, manifest_items = list())
    }
  )

  status <- res_q$status
  error_message <- res_q$error_message
  skip_reason <- res_q$skip_reason
  if (identical(status, "success")) {
    for (m_item in res_q$manifest_items) {
      manifest_artifacts[[length(manifest_artifacts) + 1L]] <- m_item
    }
  }

  rows[[length(rows) + 1L]] <- data.frame(
    run_id = resolved_run_id,
    survey_id = survey_id,
    question_id = question_id,
    analysis_type = analysis_type,
    n_total = n_total,
    n_used = n_used,
    n_missing = n_missing,
    model_name = "chisq",
    statistic_value = statistic_value,
    p_value = p_value,
    effect_value = effect_value,
    cramer_v_marginal = cramer_v_marginal,
    cramer_v_df_star = cramer_v_df_star,
    cramer_v_effect_label = cramer_v_effect_label,
    cramer_v_strata_json = cramer_v_strata_json,
    cramer_v_strata_mean = cramer_v_strata_mean,
    cramer_v_strata_max = cramer_v_strata_max,
    cramer_v_strata_max_level = cramer_v_strata_max_level,
    marginal_strata_signal = marginal_strata_signal,
    marginal_strata_note = marginal_strata_note,
    max_abs_pearson_res = max_abs_pearson_res,
    max_residual_cell = max_residual_cell_val,
    mosaic_rendered = mosaic_rendered,
    assoc_rendered = assoc_rendered,
    skip_reason = skip_reason,
    residual_plot_mode = residual_plot_mode,
    report_path = report_path,
    status = ifelse(status == "success", "success", "error"),
    error_message = ifelse(status == "success", "", error_message),
    stringsAsFactors = FALSE
  )
}

summary_df <- do.call(rbind, rows)
summary_path <- file.path(out_dir, "summary.csv")
utils::write.csv(summary_df, summary_path, row.names = FALSE, na = "")

# 3区分状態判定 (completed, partial, failed)
total_q <- nrow(cfg)
success_q <- sum(summary_df$status == "success")
error_q <- sum(summary_df$status != "success")

pass1_status <- if (total_q == 0L || success_q == 0L) {
  "failed"
} else if (success_q == total_q) {
  "completed"
} else {
  "partial"
}

run_state <- "active"

partial_failures <- list()
if (error_q > 0L) {
  err_rows <- summary_df[summary_df$status != "success", , drop = FALSE]
  for (r_idx in seq_len(nrow(err_rows))) {
    partial_failures[[length(partial_failures) + 1L]] <- list(
      question_id = err_rows$question_id[r_idx],
      error = err_rows$error_message[r_idx]
    )
  }
}

# マニフェストに summary.csv を登録
manifest_artifacts <- c(
  list(list(path = "summary.csv", role = "summary_table", question_id = NULL)),
  manifest_artifacts
)

m_res <- write_results_manifest(out_dir, "questionnaire-batch-analysis", manifest_artifacts)
message("[INFO] results_manifest.json 出力完了 (sha256: ", m_res$manifest_sha256, ")")

# run_meta.json 出力
extra_meta <- list(
  requested_run_id = rid,
  run_state = run_state,
  partial_failures = if (length(partial_failures) > 0L) partial_failures else NULL,
  results_manifest_sha256 = m_res$manifest_sha256,
  supersedes_run = if (!is.null(supersede_info)) supersede_info$source_run_dir else NULL,
  superseded_results_manifest_sha256 = superseded_results_manifest_sha256,
  supersede_reason = opt$`supersede-reason`
)

write_run_meta(
  out_root = base_out,
  run_output_dir = out_dir,
  skill = "questionnaire-batch-analysis",
  run_id = resolved_run_id,
  input_data_path = opt$data,
  extra = extra_meta
)

# pass_status$pass1 および run_state を更新
meta_path <- file.path(out_dir, "run_meta.json")
meta <- jsonlite::fromJSON(meta_path, simplifyVector = FALSE)
meta$run_state <- run_state
meta$pass_status$pass1 <- pass1_status
jsonlite::write_json(meta, meta_path, auto_unbox = TRUE, pretty = TRUE, null = "null")

# ハンドオーバー出力 (run_handover.json)
write_run_handover(out_dir, "questionnaire-batch-analysis", m_res$manifest_sha256, config_path = "analysis_config.json")
message("[INFO] run_handover.json 出力完了 (state: ", run_state, ", pass1: ", pass1_status, ")")

if (pass1_status != "completed") {
  message("[ERROR] 設問処理に失敗があり、本番後続処理を停止します (status: ", pass1_status, ")")
  quit(status = 1L)
}

message("[DONE] Questionnaire batch compute completed with pass1: ", pass1_status)
quit(status = 0L)
