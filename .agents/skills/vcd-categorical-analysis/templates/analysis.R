# VCD Categorical Analysis Pipeline (v2.1)
# 2-pass mode: --profile (Pass 0) or --render --config <path> (Pass 1 compute)
# Outputs under ./skill_out/vcd_categorical/ or specified output_dir

# --- Packages ---
if (!base::requireNamespace("pacman", quietly = TRUE)) utils::install.packages("pacman", repos = "https://cloud.r-project.org")
pacman::p_load(vcd, gt, DT, htmlwidgets, ggplot2, jsonlite)

# run_scope.R の読み込み
find_agent_repo <- function() {
  d <- base::normalizePath(base::getwd(), winslash = "/", mustWork = FALSE)
  for (i in base::seq_len(20L)) {
    p <- base::file.path(d, ".agents", "shared", "run_scope.R")
    if (base::file.exists(p)) {
      return(d)
    }
    parent <- base::dirname(d)
    if (parent == d) break
    d <- parent
  }
  base::getwd()
}
base::source(base::file.path(find_agent_repo(), ".agents", "shared", "run_scope.R"))
base::source(base::file.path(find_agent_repo(), ".agents", "shared", "pass0_contract.R"))

args <- base::commandArgs(trailingOnly = TRUE)
mode <- if ("--profile" %in% args) "profile" else "render"

# Extract argument value helper
get_arg_val <- function(arg_name, default = NULL) {
  if (arg_name %in% args) {
    idx <- base::which(args == arg_name)
    idx <- idx[base::length(idx)]
    if (idx < base::length(args)) {
      return(args[idx + 1])
    }
  }
  return(default)
}

config_path <- get_arg_val("--config")

if (identical(mode, "render") && (base::is.null(config_path) || !base::nzchar(base::trimws(config_path)))) {
  base::stop("[ERROR] Pass 1 には --config <Pass 0で確定したanalysis_config.json> が必要です。")
}
if (identical(mode, "render") && !base::file.exists(config_path)) {
  base::stop("[ERROR] 設定ファイルが見つかりません: ", config_path)
}

# デフォルト値の設定
data_path <- NULL
vars_arg <- "Hair,Eye,Sex"
freq_col <- "Freq"
data_label <- "data"
output_dir <- "./skill_out/vcd_categorical"
run_id_raw <- get_arg_val("--run-id")
supersedes_run_arg <- get_arg_val("--supersedes-run")
supersede_reason_arg <- get_arg_val("--supersede-reason")

config_data <- NULL

# JSON 設定の読み込み (Pass 0 連携用)
if (!base::is.null(config_path) && base::file.exists(config_path)) {
  base::message("[INFO] 設定ファイルを読み込み中: ", config_path)
  config_data <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)

  if (identical(mode, "render")) {
    provenance_res <- validate_pass0_provenance(
      config_data,
      config_path,
      "vcd-categorical-analysis",
      find_agent_repo()
    )
    config_data$input <- provenance_res$input_path
  }

  # マッピング: JSONキー -> スクリプト内部変数/引数名
  if (!base::is.null(config_data$input)) data_path <- config_data$input
  if (!base::is.null(config_data$vars)) vars_arg <- base::paste(config_data$vars, collapse = ",")
  if (!base::is.null(config_data$freq)) freq_col <- config_data$freq
  if (!base::is.null(config_data$output_dir)) output_dir <- config_data$output_dir
  if (!base::is.null(config_data$run_id)) run_id_raw <- config_data$run_id
  if (!base::is.null(config_data$supersedes_run) && base::is.null(supersedes_run_arg)) {
    supersedes_run_arg <- config_data$supersedes_run
  }
  if (!base::is.null(config_data$supersede_reason) && base::is.null(supersede_reason_arg)) {
    supersede_reason_arg <- config_data$supersede_reason
  }
}

# CLI 引数による上書き（CLI 優先）
data_path <- get_arg_val("--data", data_path)
vars_arg <- get_arg_val("--vars", vars_arg)
freq_col <- get_arg_val("--freq", freq_col)
data_label <- get_arg_val("--label", data_label)
output_dir <- get_arg_val("--out", output_dir)
run_id_raw <- get_arg_val("--run-id", run_id_raw)
vars <- base::trimws(base::unlist(base::strsplit(vars_arg, ",")))

if (!base::is.null(data_path) && !base::file.exists(data_path)) {
  data_source <- if ("--data" %in% args) "--data" else "config input"
  base::stop(
    "[ERROR] ", data_source, " で指定した入力ファイルが存在しません: ",
    data_path
  )
}

# ============================================================
# validate_config
# ============================================================
validate_config <- function(raw) {
  cfg <- base::list(
    collapse_below_n = 0L,
    max_levels_per_var = 999L,
    strata_to_render = base::character(0),
    gt_matrix_vars = c(1L, 2L),
    plot_mode = "auto"
  )
  if (base::is.null(raw) || base::length(raw) == 0) {
    return(cfg)
  }

  if (!base::is.null(raw$collapse_below_n) && base::is.numeric(raw$collapse_below_n)) {
    cfg$collapse_below_n <- base::as.integer(raw$collapse_below_n)
  }
  if (!base::is.null(raw$max_levels_per_var) && base::is.numeric(raw$max_levels_per_var)) {
    cfg$max_levels_per_var <- base::as.integer(raw$max_levels_per_var)
  }
  if (!base::is.null(raw$strata_to_render) && base::is.vector(raw$strata_to_render)) {
    cfg$strata_to_render <- base::as.character(raw$strata_to_render)
  }
  if (!base::is.null(raw$gt_matrix_vars) && base::length(raw$gt_matrix_vars) >= 2) {
    cfg$gt_matrix_vars <- base::as.integer(raw$gt_matrix_vars[1:2])
  }
  if (!base::is.null(raw$plot_mode) && raw$plot_mode %in% c("auto", "always", "residual_only")) {
    cfg$plot_mode <- raw$plot_mode
  }

  return(cfg)
}

# ============================================================
# load_input_data & automatically aggregate if raw
# ============================================================
load_input_data <- function() {
  if (!base::is.null(data_path) && base::file.exists(data_path)) {
    df <- utils::read.csv(data_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
    base::names(df) <- base::trimws(base::names(df))

    missing_vars <- base::setdiff(vars, base::names(df))
    if (base::length(missing_vars) > 0) {
      base::stop("Variables not found in data: ", base::paste(missing_vars, collapse = ", "))
    }

    for (v in vars) {
      if (base::is.character(df[[v]])) {
        df[[v]] <- base::trimws(df[[v]])
      }
    }

    if (!(freq_col %in% base::names(df))) {
      base::message("[INFO] Frequency column '", freq_col, "' not found. Automatically aggregating raw data...")
      tab <- base::table(df[, vars, drop = FALSE])
      df <- base::as.data.frame(tab)
      freq_col <<- "Freq"
      for (v in vars) df[[v]] <- base::as.character(df[[v]])
    } else {
      if (!base::is.numeric(df[[freq_col]])) {
        base::message("[WARNING] Frequency column is not numeric. Attempting conversion.")
        df[[freq_col]] <- base::as.numeric(base::as.character(df[[freq_col]]))
      }
    }
  } else {
    base::message("[INFO] No data provided or file not found. Using built-in HairEyeColor.")
    utils::data("HairEyeColor", package = "datasets")
    df <- base::as.data.frame(HairEyeColor)
    vars <<- c("Hair", "Eye", "Sex")
    freq_col <<- "Freq"
    data_label <<- "haireye"
  }

  for (v in vars) {
    df[[v]] <- base::droplevels(base::factor(df[[v]]))
  }

  return(df)
}

# ============================================================
# apply_aggregation
# ============================================================
apply_aggregation <- function(df, vars, freq_col, config) {
  if (base::is.null(config)) {
    return(df)
  }

  # 1. Low frequency category collapse
  if (config$collapse_below_n > 0) {
    for (v in vars) {
      marginal <- base::tapply(df[[freq_col]], df[[v]], base::sum, na.rm = TRUE)
      rare_levels <- base::names(marginal)[marginal < config$collapse_below_n]
      if (base::length(rare_levels) > 0) {
        levels(df[[v]])[levels(df[[v]]) %in% rare_levels] <- "Other"
        base::message("[COLLAPSE] Collapsed ", base::length(rare_levels), " rare level(s) into 'Other' for: ", v)
      }
    }
  }

  # 2. Maximum category truncation (Top-N + Other)
  if (config$max_levels_per_var < 999L) {
    for (v in vars) {
      if (base::nlevels(df[[v]]) > config$max_levels_per_var) {
        marginal <- base::tapply(df[[freq_col]], df[[v]], base::sum, na.rm = TRUE)
        top_levels <- base::names(base::sort(marginal, decreasing = TRUE))[1:(config$max_levels_per_var - 1L)]
        other_levels <- base::setdiff(levels(df[[v]]), top_levels)
        levels(df[[v]])[levels(df[[v]]) %in% other_levels] <- "Other"
        base::message("[TRUNCATE] Kept top ", config$max_levels_per_var - 1L, " levels and grouped others for: ", v)
      }
    }
  }

  # 3. Stratification filter
  if (base::length(config$strata_to_render) > 0 && base::length(vars) >= 3) {
    layer_var <- vars[3]
    df <- df[df[[layer_var]] %in% config$strata_to_render, , drop = FALSE]
    df[[layer_var]] <- base::droplevels(df[[layer_var]])
    base::message("[STRATA] Filtered to strata: ", base::paste(config$strata_to_render, collapse = ", "))
  }

  # Re-aggregate table structure after level manipulation
  fml <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " + ")))
  agg_df <- stats::aggregate(fml, data = df, FUN = base::sum, na.rm = TRUE)
  return(agg_df)
}

# ============================================================
# generate_profile
# ============================================================
generate_profile <- function(df, vars, freq_col, output_dir, config = NULL, out_filename = "data_profile.json") {
  var_info <- base::lapply(vars, function(v) {
    base::list(
      name = v,
      n_levels = base::nlevels(df[[v]]),
      levels = base::levels(df[[v]])
    )
  })
  base::names(var_info) <- vars

  tab <- stats::xtabs(stats::as.formula(
    base::paste(freq_col, "~", base::paste(vars, collapse = " + "))
  ), data = df)

  total_cells <- base::prod(base::dim(tab))
  n_nonzero <- base::sum(base::as.vector(tab) > 0)

  marginal_cells <- if (base::length(vars) >= 2) {
    base::prod(base::dim(tab)[1:2])
  } else {
    total_cells
  }

  warning_msg <- if (n_nonzero < total_cells) {
    "Data contains zero-frequency cells."
  } else {
    NULL
  }

  profile <- base::list(
    n_dimensions = base::length(vars),
    variables = var_info,
    total_cells = total_cells,
    total_cells_2way_marginal = marginal_cells,
    n_nonzero_cells = n_nonzero,
    sparsity_ratio = base::round(n_nonzero / total_cells, 3),
    warning = warning_msg
  )

  if (!base::dir.exists(output_dir)) {
    base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  jsonlite::write_json(profile, base::file.path(output_dir, out_filename),
    auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  base::message("[PROFILE] ", out_filename, " written to ", output_dir)
  return(base::invisible(profile))
}

# ============================================================
# generate_data
# ============================================================
generate_data <- function(df, vars, freq_col, output_dir, config, data_label) {
  df <- apply_aggregation(df, vars, freq_col, config)

  fml_main <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " + ")))
  fml_2way <- stats::as.formula(base::paste(freq_col, "~ (", base::paste(vars, collapse = " + "), ")^2"))
  fml_sat <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " * ")))

  fit_main <- base::tryCatch(stats::glm(fml_main, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_main: ", base::conditionMessage(e))
      NULL
    }
  )
  fit_2way <- base::tryCatch(stats::glm(fml_2way, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_2way: ", base::conditionMessage(e))
      NULL
    }
  )
  fit_sat <- base::tryCatch(stats::glm(fml_sat, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_sat: ", base::conditionMessage(e))
      NULL
    }
  )

  anova_res <- base::tryCatch(stats::anova(fit_main, fit_2way, fit_sat, test = "Chisq"),
    error = function(e) {
      base::message("[WARNING] anova: ", base::conditionMessage(e))
      NULL
    }
  )

  collect_res <- function(fit, label) {
    if (base::is.null(fit)) {
      return(NULL)
    }
    res_df <- df
    res_df$model_type <- label
    res_df$pearson_res <- stats::residuals(fit, type = "pearson")
    res_df$abs_pearson_res <- base::abs(res_df$pearson_res)
    res_df$cell_label <- base::apply(res_df[, vars, drop = FALSE], 1, base::paste, collapse = ":")
    return(res_df)
  }

  res_main <- collect_res(fit_main, "Main Effects (A+B[+C])")
  res_2way <- collect_res(fit_2way, "2-way ((A+B[+C])^2)")
  res_combined <- base::rbind(res_main, res_2way)
  utils::write.csv(res_combined, base::file.path(
    output_dir,
    base::paste0("residuals_", data_label, ".csv")
  ), row.names = FALSE)

  top_n <- 20
  sig_compact <- base::rbind(
    if (!base::is.null(res_main)) utils::head(res_main[base::order(-res_main$abs_pearson_res), ], top_n) else NULL,
    if (!base::is.null(res_2way)) utils::head(res_2way[base::order(-res_2way$abs_pearson_res), ], top_n) else NULL
  )
  if (!base::is.null(sig_compact) && base::nrow(sig_compact) > 0) {
    sig_compact <- sig_compact[!base::duplicated(
      base::paste(sig_compact$model_type, sig_compact$cell_label)
    ), ]
    utils::write.csv(sig_compact, base::file.path(
      output_dir,
      base::paste0("significant_cells_", data_label, ".csv")
    ), row.names = FALSE)
  }

  tab <- stats::xtabs(stats::as.formula(
    base::paste(freq_col, "~", base::paste(vars, collapse = " + "))
  ), data = df)

  return(base::list(
    res_combined = res_combined,
    tab = tab,
    anova = anova_res
  ))
}

# ============================================================
# generate_gt_matrix
# ============================================================
generate_gt_matrix <- function(res_df, vars, freq_col, output_dir, config, data_label) {
  if (base::is.null(res_df) || base::nrow(res_df) == 0) {
    return()
  }

  v_row <- vars[config$gt_matrix_vars[1]]
  v_col <- vars[config$gt_matrix_vars[2]]

  models <- base::unique(res_df$model_type)

  for (m in models) {
    sub_df <- res_df[res_df$model_type == m, ]

    if (base::length(vars) >= 3) {
      strata_var <- vars[3]
      strata_levels <- base::unique(sub_df[[strata_var]])
      for (s in strata_levels) {
        strata_df <- sub_df[sub_df[[strata_var]] == s, ]
        fml_strata <- stats::as.formula(base::paste("pearson_res ~", v_row, "+", v_col))
        mat <- stats::xtabs(fml_strata, data = strata_df)
        mat_df <- base::as.data.frame.matrix(mat)
        mat_df <- base::cbind(Row_Variable = base::rownames(mat_df), mat_df)

        gt_tbl <- gt::gt(mat_df) |>
          gt::tab_header(
            title = base::paste("Pearson Residuals Matrix:", m),
            subtitle = base::paste("Stratum [", strata_var, "=", s, "] | Row:", v_row, "x Col:", v_col)
          ) |>
          gt::fmt_number(columns = -Row_Variable, decimals = 3) |>
          gt::data_color(
            columns = -Row_Variable,
            palette = c("#D73027", "#FFFFFF", "#4575B4"),
            domain = c(-3.0, 3.0)
          )

        safe_s <- base::gsub("[^A-Za-z0-9_]", "_", s)
        safe_m <- base::gsub("[^A-Za-z0-9_]", "_", m)
        fname <- base::paste0("gt_matrix_", safe_m, "_", safe_s, "_", data_label, ".html")
        gt::gtsave(gt_tbl, base::file.path(output_dir, fname))
        base::message("[GT] ", fname)
      }
    } else {
      fml_2way <- stats::as.formula(base::paste("pearson_res ~", v_row, "+", v_col))
      mat <- stats::xtabs(fml_2way, data = sub_df)
      mat_df <- base::as.data.frame.matrix(mat)
      mat_df <- base::cbind(Row_Variable = base::rownames(mat_df), mat_df)

      gt_tbl <- gt::gt(mat_df) |>
        gt::tab_header(
          title = base::paste("Pearson Residuals Matrix:", m),
          subtitle = base::paste("Row:", v_row, "x Col:", v_col)
        ) |>
        gt::fmt_number(columns = -Row_Variable, decimals = 3) |>
        gt::data_color(
          columns = -Row_Variable,
          palette = c("#D73027", "#FFFFFF", "#4575B4"),
          domain = c(-3.0, 3.0)
        )

      safe_m <- base::gsub("[^A-Za-z0-9_]", "_", m)
      fname <- base::paste0("gt_matrix_", safe_m, "_", data_label, ".html")
      gt::gtsave(gt_tbl, base::file.path(output_dir, fname))
      base::message("[GT] ", fname)
    }
  }
}

# ============================================================
# generate_dt_table
# ============================================================
generate_dt_table <- function(res_df, vars, output_dir, config, data_label) {
  if (base::is.null(res_df) || base::nrow(res_df) == 0) {
    return()
  }

  display_cols <- base::intersect(c(vars, freq_col, "pearson_res", "abs_pearson_res", "model_type"), base::names(res_df))
  dt_df <- res_df[, display_cols, drop = FALSE]
  dt_df <- dt_df[base::order(-dt_df$abs_pearson_res), ]

  for (v in vars) {
    if (v %in% base::names(dt_df)) {
      dt_df[[v]] <- base::factor(dt_df[[v]], levels = base::sort(base::unique(base::as.character(dt_df[[v]]))))
    }
  }
  if ("model_type" %in% base::names(dt_df)) {
    dt_df[["model_type"]] <- base::factor(
      dt_df[["model_type"]],
      levels = base::sort(base::unique(base::as.character(dt_df[["model_type"]])))
    )
  }

  mx <- base::max(dt_df$abs_pearson_res, na.rm = TRUE)
  if (!base::is.finite(mx) || mx < 1e-12) mx <- 1

  brks <- base::seq(-mx, mx, length.out = 100)
  clrs <- grDevices::colorRampPalette(c("#D73027", "#FFFFFF", "#4575B4"))(100)

  widget <- DT::datatable(dt_df,
    filter = "top",
    options = base::list(
      pageLength = 50,
      order = base::list(base::list(base::which(base::names(dt_df) == "abs_pearson_res") - 1, "desc")),
      dom = "lftipr"
    ),
    caption = base::paste("Pearson Residuals:", data_label)
  ) |>
    DT::formatRound(columns = c("pearson_res", "abs_pearson_res"), digits = 3) |>
    DT::formatStyle("pearson_res", backgroundColor = DT::styleInterval(brks[-1], clrs))

  fname <- base::paste0("dt_residuals_", data_label, ".html")
  out_html_path <- base::file.path(base::normalizePath(output_dir), fname)
  base::tryCatch({
    htmlwidgets::saveWidget(widget, out_html_path, selfcontained = TRUE)
    base::message("[DT] ", fname)
  }, error = function(e) {
    base::tryCatch({
      htmlwidgets::saveWidget(widget, out_html_path, selfcontained = FALSE, libdir = base::file.path(base::normalizePath(output_dir), "dt_libs"))
      base::message("[DT] ", fname, " (selfcontained=FALSE fallback)")
    }, error = function(e2) {
      base::warning("[WARN] DTテーブルの保存をスキップしました: ", e2$message)
    })
  })
}

# ============================================================
# generate_plots
# ============================================================
generate_plots <- function(tab, vars, output_dir, config, data_label) {
  if (config$plot_mode == "residual_only") {
    base::message("[PLOTS] plot_mode is 'residual_only'. Skipping PNG generation.")
    return()
  }

  if (config$plot_mode == "auto") {
    total_cells <- base::prod(base::dim(tab))
    threshold <- if (base::length(vars) >= 3) 36 else 16
    max_label_len <- base::max(base::nchar(base::unlist(base::dimnames(tab))))

    if (total_cells > threshold || max_label_len > 24) {
      base::message(
        "[PLOTS] plot_mode 'auto' threshold exceeded (cells=", total_cells,
        ", max_label_len=", max_label_len, "). Skipping PNG generation."
      )
      return()
    }
  }

  grDevices::png(base::file.path(output_dir, base::paste0("mosaic_", data_label, ".png")), width = 1000, height = 800)
  vcd::mosaic(tab, shade = TRUE, main = base::paste("Mosaic:", base::paste(vars, collapse = " x ")))
  grDevices::dev.off()

  if (base::length(vars) == 2) {
    grDevices::png(base::file.path(output_dir, base::paste0("assoc_", data_label, ".png")), width = 1000, height = 800)
    vcd::assoc(tab, residuals_type = "Pearson", shade = TRUE, main = base::paste("Association:", base::paste(vars, collapse = " x ")))
    grDevices::dev.off()
  }

  if (base::length(vars) >= 3) {
    grDevices::png(base::file.path(output_dir, base::paste0("cotab_", data_label, ".png")), width = 1000, height = 800)
    vcd::cotabplot(tab, panel = vcd::cotab_mosaic, shade = TRUE)
    grDevices::dev.off()
  }
  base::message("[PLOTS] PNG files written for: ", data_label)
}

# ============================================================
# generate_categorical_results_json (for Pass 3 Dashboard)
# ============================================================
generate_categorical_results_json <- function(df, vars, freq_col, output_dir, res_combined, data_label) {
  output <- list(
    interface_version = "1.0",
    dataset_name = data_label,
    dimensions = vars,
    n_total = sum(df[[freq_col]], na.rm = TRUE),
    cramers_v = tryCatch(as.numeric(vcd::assocstats(xtabs(as.formula(paste(freq_col, "~", paste(vars[1:2], collapse = " + "))), data = df))$cramer), error = function(e) NA_real_),
    full_data = res_combined
  )

  jsonlite::write_json(output, file.path(output_dir, "categorical_results.json"), auto_unbox = TRUE, pretty = TRUE)
  base::message("[JSON] categorical_results.json written for dashboard integration")
}

# ============================================================
# Main dispatcher
# ============================================================

# 1. Load data and auto-aggregate if needed
df <- load_input_data()

if (mode == "profile") {
  # --- Pass 0 Profile Mode ---
  # 正式な run ディレクトリは作成せず、指定またはカレントディレクトリ直下に data_profile.json を出力
  profile_out_dir <- if (!base::is.null(output_dir) && base::nzchar(output_dir)) output_dir else "."
  if (!base::dir.exists(profile_out_dir)) {
    base::dir.create(profile_out_dir, recursive = TRUE, showWarnings = FALSE)
  }
  generate_profile(df, vars, freq_col, profile_out_dir, config = NULL, out_filename = "data_profile.json")
  base::message("[DONE] Pass 0 profile generated at: ", profile_out_dir)
  quit(status = 0L)
}

# --- Pass 1 Render (Compute) Mode ---
# 唯一の正式 run 作成主体

# 親ディレクトリ検証 (FAIL-FAST)
out_root <- if (!base::is.null(output_dir) && base::nzchar(output_dir)) output_dir else "./skill_out/vcd_categorical"
assert_valid_out_root(out_root)

# run_id のサニタイズ・決定
sanitize_run_slug <- function(x) {
  if (base::is.null(x) || !base::nzchar(base::trimws(base::as.character(x)[1]))) {
    return(NULL)
  }
  x <- base::trimws(base::as.character(x)[1])
  if (base::tolower(x) == "auto") {
    return(base::format(base::Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo"))
  }
  x <- base::gsub("[/\\\\]", "_", x)
  x <- base::gsub("^\\.+|\\.+$", "", x)
  if (!base::nzchar(x)) {
    base::stop("無効な --run-id です")
  }
  x
}

run_slug <- sanitize_run_slug(run_id_raw)
if (base::is.null(run_slug)) {
  run_slug <- base::format(base::Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
}
prefix16 <- run_id_short16(run_slug)

# 原子的な run ディレクトリの予約・作成
run_dir <- reserve_run_output_dir(out_root, "vcd-categorical-analysis", run_slug)
resolved_run_id <- base::sub("^run_", "", base::basename(run_dir))
base::message("[INFO] run 出力先: ", run_dir)

# supersede 元の検証 (指定時)
supersedes_run <- supersedes_run_arg
superseded_manifest_sha256 <- NULL
if (!base::is.null(supersedes_run) && base::nzchar(supersedes_run)) {
  sup_info <- verify_superseded_run(supersedes_run, "vcd-categorical-analysis", current_run_dir = run_dir)
  superseded_manifest_sha256 <- sup_info$superseded_results_manifest_sha256
  base::message("[INFO] supersede 元 run 検証合格: ", supersedes_run)
}

# 設定スナップショットの保存
if (base::is.null(config_data)) {
  config_data <- base::list(
    input = data_path,
    vars = vars,
    freq = freq_col,
    output_dir = out_root,
    run_id = run_slug
  )
}
save_config_snapshot(run_dir, if (!base::is.null(config_path)) config_path else config_data, config_origin = if (!base::is.null(config_path)) "pass0_file" else "resolved_cli", config_source_path = config_path)

# メタデータ (run_meta.json) の作成
has_input_file <- !base::is.null(data_path) && base::file.exists(data_path)
if (has_input_file) {
  signature_input <- base::list(
    kind = "file",
    sha256 = sha256_file(data_path)
  )
  signature_vars <- vars
  signature_freq <- freq_col
} else {
  builtin_df_for_signature <- base::as.data.frame(datasets::HairEyeColor)
  signature_input <- base::list(
    kind = "builtin:datasets::HairEyeColor",
    sha256 = sha256_df(builtin_df_for_signature)
  )
  signature_vars <- c("Hair", "Eye", "Sex")
  signature_freq <- "Freq"
}
analysis_signature <- digest::digest(
  base::list(
    interface_version = "1.0",
    input = signature_input,
    vars = base::unname(base::as.character(signature_vars)),
    freq = base::as.character(signature_freq)
  ),
  algo = "sha256"
)

extra_meta <- base::list(
  requested_run_id = run_slug,
  inputs = if (!has_input_file) base::list(base::list(role = "data", source_kind = "builtin", source_path = "datasets::HairEyeColor", snapshot_policy = "hash_only", sha256 = signature_input$sha256)) else NULL,
  analysis_signature = analysis_signature
)
if (!base::is.null(supersedes_run) && base::nzchar(supersedes_run)) {
  extra_meta$supersedes_run <- base::normalizePath(supersedes_run, winslash = "/")
  extra_meta$superseded_results_manifest_sha256 <- superseded_manifest_sha256
  if (!base::is.null(supersede_reason_arg) && base::nzchar(supersede_reason_arg)) {
    extra_meta$supersede_reason <- supersede_reason_arg
  }
}

write_run_meta(
  out_root = out_root,
  run_output_dir = run_dir,
  skill = "vcd-categorical-analysis",
  run_id = resolved_run_id,
  input_data_path = data_path,
  extra = extra_meta
)

# 実行
raw_config <- if (!base::is.null(config_path) && base::file.exists(config_path)) {
  jsonlite::read_json(config_path)
} else {
  base::list()
}
config <- validate_config(raw_config)

# Pass 1 compute: Apply aggregation first, then generate post-profile from aggregated data
df_agg <- apply_aggregation(df, vars, freq_col, config)
generate_profile(df_agg, vars, freq_col, run_dir, config = NULL, out_filename = "data_profile_post.json")

# Generate data, tables, plots
res <- generate_data(df, vars, freq_col, run_dir, config, data_label)
generate_gt_matrix(res$res_combined, vars, freq_col, run_dir, config, data_label)
generate_dt_table(res$res_combined, vars, run_dir, config, data_label)
generate_plots(res$tab, vars, run_dir, config, data_label)

# ダッシュボード連携用 JSON
generate_categorical_results_json(df_agg, vars, freq_col, run_dir, res$res_combined, data_label)

# マニフェスト (results_manifest.json) 出力
# 成果物リストの収集
manifest_artifacts <- base::list(
  base::list(
    path = "categorical_results.json",
    role = "primary_results",
    question_id = NULL
  ),
  base::list(
    path = "data_profile_post.json",
    role = "diagnostic",
    question_id = NULL
  ),
  base::list(
    path = base::paste0("residuals_", data_label, ".csv"),
    role = "intermediate",
    question_id = NULL
  )
)

sig_cells_path <- base::paste0("significant_cells_", data_label, ".csv")
if (base::file.exists(base::file.path(run_dir, sig_cells_path))) {
  manifest_artifacts <- base::c(manifest_artifacts, base::list(base::list(
    path = sig_cells_path,
    role = "intermediate",
    question_id = NULL
  )))
}

# GT / DT HTML ファイル
all_run_files <- base::list.files(run_dir)
for (f in all_run_files) {
  if (base::grepl("^gt_matrix_.*\\.html$", f) || base::grepl("^dt_residuals_.*\\.html$", f)) {
    manifest_artifacts <- base::c(manifest_artifacts, base::list(base::list(
      path = f,
      role = "summary_table",
      question_id = NULL
    )))
  } else if (base::grepl("^(mosaic|assoc|cotab)_.*\\.png$", f)) {
    manifest_artifacts <- base::c(manifest_artifacts, base::list(base::list(
      path = f,
      role = "figure",
      question_id = NULL
    )))
  }
}

manifest_res <- write_results_manifest(run_dir, "vcd-categorical-analysis", manifest_artifacts)
base::message("[INFO] results_manifest.json 出力完了 (sha256: ", manifest_res$manifest_sha256, ")")

# run_meta.json を更新 (results_manifest_sha256 を反映)
extra_meta$results_manifest_sha256 <- manifest_res$manifest_sha256
write_run_meta(
  out_root = out_root,
  run_output_dir = run_dir,
  skill = "vcd-categorical-analysis",
  run_id = resolved_run_id,
  input_data_path = data_path,
  extra = extra_meta
)

# ハンドオーバー出力 (run_handover.json)
write_run_handover(run_dir, "vcd-categorical-analysis", manifest_res$manifest_sha256)
base::message("[INFO] run_handover.json 出力完了")

base::message("[DONE] Pass 1 compute completed for: ", data_label)
