#!/usr/bin/env Rscript
# tests/statistical_foundations/prepare_cases.R
# 3次元統計基盤検証のためのケース準備・検分補足・3元集約・人工表生成スクリプト

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(readr)
})

compute_sha256 <- function(filepath) {
  if (!file.exists(filepath)) return(NA_character_)
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(file = filepath, algo = "sha256"))
  } else if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::sha256(file(filepath, "rb"))))
  } else {
    out <- system2("shasum", args = c("-a", "256", filepath), stdout = TRUE)
    return(strsplit(out, " ")[[1]][1])
  }
}

inspect_supplement <- function(df, cat_vars, freq_var = "Freq") {
  # 完全な水準格子（フルファクトリアル）の確認
  grid_levels <- lapply(cat_vars, function(v) sort(unique(df[[v]])))
  names(grid_levels) <- cat_vars
  expected_grid <- expand.grid(grid_levels, stringsAsFactors = FALSE)
  expected_n_cells <- nrow(expected_grid)
  
  actual_n_cells <- nrow(df)
  total_n <- sum(df[[freq_var]], na.rm = TRUE)
  zero_cells <- sum(df[[freq_var]] == 0, na.rm = TRUE)
  na_freq <- sum(is.na(df[[freq_var]]))
  min_freq <- min(df[[freq_var]], na.rm = TRUE)
  max_freq <- max(df[[freq_var]], na.rm = TRUE)
  
  # 欠測セルの有無
  merged <- merge(expected_grid, df, by = cat_vars, all.x = TRUE)
  missing_cells_count <- sum(is.na(merged[[freq_var]]))
  
  list(
    cat_vars = cat_vars,
    expected_cells = expected_n_cells,
    actual_cells = actual_n_cells,
    is_full_grid = (actual_n_cells == expected_n_cells && missing_cells_count == 0),
    missing_cells_count = missing_cells_count,
    total_n = total_n,
    zero_cells = zero_cells,
    na_freq_count = na_freq,
    min_freq = min_freq,
    max_freq = max_freq
  )
}

main <- function() {
  base_dir <- getwd()
  manifest_path <- file.path(base_dir, "tests/fixtures/statistical_foundations/case_manifest.json")
  if (!file.exists(manifest_path)) {
    stop("case_manifest.json が見つかりません: ", manifest_path)
  }
  manifest <- fromJSON(manifest_path, simplifyVector = FALSE)
  
  fixtures_dir <- file.path(base_dir, "tests/fixtures/statistical_foundations")
  if (!dir.exists(fixtures_dir)) {
    dir.create(fixtures_dir, recursive = TRUE)
  }
  
  message("=== [Step 1] 元データ (examples/titanic.csv) の検分と3元集約 ===")
  titanic_src <- file.path(base_dir, manifest$titanic_cases$source_file)
  if (!file.exists(titanic_src)) {
    stop("元CSVが見つかりません: ", titanic_src)
  }
  
  src_sha256 <- compute_sha256(titanic_src)
  df_titanic_raw <- read_csv(titanic_src, show_col_types = FALSE)
  
  # 既存 inspect_data.R を使って検分を実行
  inspect_script <- file.path(base_dir, ".agents/shared/inspect_data.R")
  inspect_raw_dir <- file.path(fixtures_dir, "inspection_raw_titanic")
  if (!dir.exists(inspect_raw_dir)) dir.create(inspect_raw_dir, recursive = TRUE)
  system2("Rscript", args = c(inspect_script, titanic_src, "--out-dir", inspect_raw_dir))
  
  # 3元集約 (Class × Sex × Survived, Age を合算)
  target_vars <- unlist(manifest$titanic_cases$variables)
  df_titanic_3way <- df_titanic_raw %>%
    group_by(across(all_of(target_vars))) %>%
    summarise(Freq = sum(Freq), .groups = "drop") %>%
    arrange(across(all_of(target_vars)))
  
  supp_3way <- inspect_supplement(df_titanic_3way, target_vars, "Freq")
  if (supp_3way$actual_cells != 16 || supp_3way$total_n != 2201) {
    stop(sprintf("集約結果が期待値と不一致: セル数=%d (期待16), 総度数=%d (期待2201)", 
                 supp_3way$actual_cells, supp_3way$total_n))
  }
  
  path_titanic_3way <- file.path(fixtures_dir, "titanic_aggregated_3way.csv")
  write_csv(df_titanic_3way, path_titanic_3way)
  sha_3way <- compute_sha256(path_titanic_3way)
  message(sprintf("  -> 3元集約完了: 16セル, 総度数 %d, SHA-256: %s", supp_3way$total_n, sha_3way))
  
  message("=== [Step 2] 100倍表の生成 ===")
  df_titanic_100x <- df_titanic_3way %>%
    mutate(Freq = Freq * 100L)
  
  supp_100x <- inspect_supplement(df_titanic_100x, target_vars, "Freq")
  if (supp_100x$actual_cells != 16 || supp_100x$total_n != 220100) {
    stop(sprintf("100倍表が期待値と不一致: セル数=%d (期待16), 総度数=%d (期待220100)", 
                 supp_100x$actual_cells, supp_100x$total_n))
  }
  
  # 構成比の一致確認
  prop_orig <- df_titanic_3way$Freq / sum(df_titanic_3way$Freq)
  prop_100x <- df_titanic_100x$Freq / sum(df_titanic_100x$Freq)
  if (!isTRUE(all.equal(prop_orig, prop_100x))) {
    stop("100倍表の構成比が集約表と一致しません")
  }
  
  path_titanic_100x <- file.path(fixtures_dir, "titanic_scaled_100x_3way.csv")
  write_csv(df_titanic_100x, path_titanic_100x)
  sha_100x <- compute_sha256(path_titanic_100x)
  message(sprintf("  -> 100倍表完了: 16セル, 総度数 %d, 構成比完全一致, SHA-256: %s", supp_100x$total_n, sha_100x))
  
  message("=== [Step 3] 人工3表の生成 ===")
  syn_cases <- manifest$synthetic_tables
  syn_results <- list()
  
  # 3.1 syn_independent
  # n_ijk = 800 * p_A(i) * p_B(j) * p_C(k)
  # p_A = [0.4, 0.6], p_B = [0.3, 0.7], p_C = [0.5, 0.5]
  syn_ind_df <- expand.grid(A = c("A1", "A2"), B = c("B1", "B2"), C = c("C1", "C2"), stringsAsFactors = FALSE) %>%
    mutate(
      p_A = ifelse(A == "A1", 0.4, 0.6),
      p_B = ifelse(B == "B1", 0.3, 0.7),
      p_C = 0.5,
      Freq = as.integer(round(800 * p_A * p_B * p_C))
    ) %>%
    select(A, B, C, Freq) %>%
    arrange(A, B, C)
  
  path_syn_ind <- file.path(fixtures_dir, "syn_independent.csv")
  write_csv(syn_ind_df, path_syn_ind)
  supp_syn_ind <- inspect_supplement(syn_ind_df, c("A", "B", "C"), "Freq")
  syn_results[["syn_independent"]] <- list(
    path = path_syn_ind,
    sha256 = compute_sha256(path_syn_ind),
    supplement = supp_syn_ind
  )
  message(sprintf("  -> syn_independent: 8セル, 総度数 %d, SHA-256: %s", supp_syn_ind$total_n, syn_results[["syn_independent"]]$sha256))
  
  # 3.2 syn_ab_associated
  # n_ijk = 800 * p_AB(i, j) * p_C(k)
  # p_AB: A1B1=0.35, A1B2=0.05, A2B1=0.15, A2B2=0.45
  # p_C: 0.5
  p_AB_map <- c("A1:B1" = 0.35, "A1:B2" = 0.05, "A2:B1" = 0.15, "A2:B2" = 0.45)
  syn_ab_df <- expand.grid(A = c("A1", "A2"), B = c("B1", "B2"), C = c("C1", "C2"), stringsAsFactors = FALSE) %>%
    mutate(
      key = paste(A, B, sep = ":"),
      p_AB = p_AB_map[key],
      p_C = 0.5,
      Freq = as.integer(round(800 * p_AB * p_C))
    ) %>%
    select(A, B, C, Freq) %>%
    arrange(A, B, C)
  
  path_syn_ab <- file.path(fixtures_dir, "syn_ab_associated.csv")
  write_csv(syn_ab_df, path_syn_ab)
  supp_syn_ab <- inspect_supplement(syn_ab_df, c("A", "B", "C"), "Freq")
  syn_results[["syn_ab_associated"]] <- list(
    path = path_syn_ab,
    sha256 = compute_sha256(path_syn_ab),
    supplement = supp_syn_ab
  )
  message(sprintf("  -> syn_ab_associated: 8セル, 総度数 %d, SHA-256: %s", supp_syn_ab$total_n, syn_results[["syn_ab_associated"]]$sha256))
  
  # 3.3 syn_interaction_shifted
  # C=C1: A1B1=0.20, A1B2=0.05, A2B1=0.05, A2B2=0.20
  # C=C2: A1B1=0.05, A1B2=0.20, A2B1=0.20, A2B2=0.05
  p_ABC_map <- c(
    "A1:B1:C1" = 0.20, "A1:B2:C1" = 0.05, "A2:B1:C1" = 0.05, "A2:B2:C1" = 0.20,
    "A1:B1:C2" = 0.05, "A1:B2:C2" = 0.20, "A2:B1:C2" = 0.20, "A2:B2:C2" = 0.05
  )
  syn_int_df <- expand.grid(A = c("A1", "A2"), B = c("B1", "B2"), C = c("C1", "C2"), stringsAsFactors = FALSE) %>%
    mutate(
      key = paste(A, B, C, sep = ":"),
      p_ABC = p_ABC_map[key],
      Freq = as.integer(round(800 * p_ABC))
    ) %>%
    select(A, B, C, Freq) %>%
    arrange(A, B, C)
  
  path_syn_int <- file.path(fixtures_dir, "syn_interaction_shifted.csv")
  write_csv(syn_int_df, path_syn_int)
  supp_syn_int <- inspect_supplement(syn_int_df, c("A", "B", "C"), "Freq")
  syn_results[["syn_interaction_shifted"]] <- list(
    path = path_syn_int,
    sha256 = compute_sha256(path_syn_int),
    supplement = supp_syn_int
  )
  message(sprintf("  -> syn_interaction_shifted: 8セル, 総度数 %d, SHA-256: %s", supp_syn_int$total_n, syn_results[["syn_interaction_shifted"]]$sha256))
  
  message("=== [Step 4] 全ケースの検分サマリーと来歴の保存 ===")
  inspection_summary <- list(
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    source_titanic = list(
      file = manifest$titanic_cases$source_file,
      sha256 = src_sha256,
      n_rows = nrow(df_titanic_raw),
      n_cols = ncol(df_titanic_raw),
      total_n = sum(df_titanic_raw$Freq)
    ),
    cases = list(
      titanic_aggregated_3way = list(
        file = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv",
        sha256 = sha_3way,
        derived_from = manifest$titanic_cases$source_file,
        transformation = "Class x Sex x Survived への Age 合算集約",
        supplement = supp_3way
      ),
      titanic_scaled_100x_3way = list(
        file = "tests/fixtures/statistical_foundations/titanic_scaled_100x_3way.csv",
        sha256 = sha_100x,
        derived_from = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv",
        transformation = "度数を100倍（構成比完全一致）",
        supplement = supp_100x
      ),
      syn_independent = syn_results[["syn_independent"]],
      syn_ab_associated = syn_results[["syn_ab_associated"]],
      syn_interaction_shifted = syn_results[["syn_interaction_shifted"]]
    )
  )
  
  summary_path <- file.path(fixtures_dir, "cases_inspection.json")
  writeLines(toJSON(inspection_summary, auto_unbox = TRUE, pretty = TRUE), summary_path)
  message("[SUCCESS] ケース準備・検分補足・来歴保存が完了しました: ", summary_path)
  
  message("=== [Step 5] 試作用 analysis_config.json の作成（合意設定の固定） ===")
  configs_dir <- file.path(fixtures_dir, "configs")
  if (!dir.exists(configs_dir)) dir.create(configs_dir, recursive = TRUE)
  
  common_prior <- list(total_alpha = 1.0, distribution = "dirichlet")
  common_tol <- manifest$tolerances
  seed <- manifest$simulation_and_mcmc$random_seed
  
  # 1. Titanic Standard Exploratory
  cfg_t_std_exp <- list(
    schema_version = "3way-foundation-v1",
    input = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv",
    vars = c("Class", "Sex", "Survived"),
    freq = "Freq",
    response_var = NULL,
    output_dir = "output/statistical_foundations",
    run_id = "titanic_std_exp",
    sampling = list(
      unit = "乗客",
      total_n_meaning = "タイタニック号の総乗客数 (N=2201)",
      independence_assumption = "assumed_independent",
      is_scaled = FALSE
    ),
    prior = common_prior,
    reference_tolerance = common_tol,
    seed = seed
  )
  write_json(cfg_t_std_exp, file.path(configs_dir, "cfg_titanic_standard_exploratory.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 2. Titanic Standard Directed
  cfg_t_std_dir <- cfg_t_std_exp
  cfg_t_std_dir$response_var <- "Survived"
  cfg_t_std_dir$run_id <- "titanic_std_dir"
  write_json(cfg_t_std_dir, file.path(configs_dir, "cfg_titanic_standard_directed.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 3. Titanic Scaled 100x Exploratory
  cfg_t_100x_exp <- list(
    schema_version = "3way-foundation-v1",
    input = "tests/fixtures/statistical_foundations/titanic_scaled_100x_3way.csv",
    vars = c("Class", "Sex", "Survived"),
    freq = "Freq",
    response_var = NULL,
    output_dir = "output/statistical_foundations",
    run_id = "titanic_100x_exp",
    sampling = list(
      unit = "乗客",
      total_n_meaning = "タイタニック号の度数を100倍拡大 (N=220100)",
      independence_assumption = "assumed_independent",
      is_scaled = TRUE,
      scaling_factor = 100,
      lineage = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv の Freq を100倍"
    ),
    prior = common_prior,
    reference_tolerance = common_tol,
    seed = seed
  )
  write_json(cfg_t_100x_exp, file.path(configs_dir, "cfg_titanic_scaled_100x_exploratory.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 4. Titanic Scaled 100x Directed
  cfg_t_100x_dir <- cfg_t_100x_exp
  cfg_t_100x_dir$response_var <- "Survived"
  cfg_t_100x_dir$run_id <- "titanic_100x_dir"
  write_json(cfg_t_100x_dir, file.path(configs_dir, "cfg_titanic_scaled_100x_directed.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 5. syn_independent
  cfg_syn_ind <- list(
    schema_version = "3way-foundation-v1",
    input = "tests/fixtures/statistical_foundations/syn_independent.csv",
    vars = c("A", "B", "C"),
    freq = "Freq",
    response_var = NULL,
    output_dir = "output/statistical_foundations",
    run_id = "syn_independent",
    sampling = list(
      unit = "人工観測単位",
      total_n_meaning = "完全に相互独立な人工表 (N=800)",
      independence_assumption = "assumed_independent",
      is_scaled = FALSE
    ),
    prior = common_prior,
    reference_tolerance = common_tol,
    seed = seed
  )
  write_json(cfg_syn_ind, file.path(configs_dir, "cfg_syn_independent.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 6. syn_ab_associated
  cfg_syn_ab <- list(
    schema_version = "3way-foundation-v1",
    input = "tests/fixtures/statistical_foundations/syn_ab_associated.csv",
    vars = c("A", "B", "C"),
    freq = "Freq",
    response_var = NULL,
    output_dir = "output/statistical_foundations",
    run_id = "syn_ab_assoc",
    sampling = list(
      unit = "人工観測単位",
      total_n_meaning = "AB間関連・C独立な人工表 (N=800)",
      independence_assumption = "assumed_independent",
      is_scaled = FALSE
    ),
    prior = common_prior,
    reference_tolerance = common_tol,
    seed = seed
  )
  write_json(cfg_syn_ab, file.path(configs_dir, "cfg_syn_ab_associated.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 7. syn_interaction_shifted
  cfg_syn_int <- list(
    schema_version = "3way-foundation-v1",
    input = "tests/fixtures/statistical_foundations/syn_interaction_shifted.csv",
    vars = c("A", "B", "C"),
    freq = "Freq",
    response_var = NULL,
    output_dir = "output/statistical_foundations",
    run_id = "syn_int_shifted",
    sampling = list(
      unit = "人工観測単位",
      total_n_meaning = "C層別でAB関連が逆転する3次交互作用人工表 (N=800)",
      independence_assumption = "assumed_independent",
      is_scaled = FALSE
    ),
    prior = common_prior,
    reference_tolerance = common_tol,
    seed = seed
  )
  write_json(cfg_syn_int, file.path(configs_dir, "cfg_syn_interaction_shifted.json"), auto_unbox = TRUE, pretty = TRUE)
  
  message("[SUCCESS] 全7検証ケースの設定JSONを作成しました: ", configs_dir)
}

if (sys.nframe() == 0L) {
  main()
}
