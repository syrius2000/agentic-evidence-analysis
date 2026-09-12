# =============================================================================
# test_conditional_rank_reproducibility.R
# 条件付きセル順位再現性評価 (Conditional Rank Reproducibility) 受入・単体テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
})

script_dir <- file.path(getwd(), ".agents/skills/vcd-bayesian-evidence-analysis/templates")
source(file.path(getwd(), ".agents/shared/run_scope.R"))
source(file.path(script_dir, "pass1_compute.R"))
source(file.path(script_dir, "config_validation.R"))

ucb_path <- file.path(getwd(), "examples/ucb_admissions.csv")
ucb_df <- read.csv(ucb_path, stringsAsFactors = FALSE)
vars_3way <- c("Dept", "Gender", "Admit")
flo_ucb <- list(
  Dept = c("A", "B", "C", "D", "E", "F"),
  Gender = c("Male", "Female"),
  Admit = c("Admitted", "Rejected")
)

# -----------------------------------------------------------------------------
# TC-01: UCB Admissions におけるシード固定完全一致および M5 実測セル数検証 (F-CRR-001)
# -----------------------------------------------------------------------------
test_that("TC-01: UCB Admissions における M5 実測セル数 (eligible=13, quarantined=11) とシード固定完全一致、status=COMPUTED", {
  fits <- fit_all_poisson_models(ucb_df, vars_3way, "Freq")
  multi_diag <- compute_multi_baseline_diagnostics(ucb_df, vars_3way, "Freq", fits, c("M1", "M5"), large_n_threshold = 2000)

  m5_counts <- multi_diag$M5$counts
  expect_equal(m5_counts$regular_cells, 13L)
  expect_equal(m5_counts$quarantined_cells, 11L)
  expect_equal(m5_counts$total_cells, 24L)

  crr_cfg <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 5L,
    iterations = 500L,
    seed = 20260912L
  )

  res1 <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = multi_diag$M5$cell_table
  )

  # F-CRR-001: 正常通過時は仕様上 COMPUTED
  expect_identical(res1$status, "COMPUTED")
  expect_true(res1$quality_gate$passed)
  expect_equal(res1$quality_gate$valid_rate, 1.0)
  expect_equal(res1$estimand_conditioning$eligible_cell_count, 13L)
  expect_equal(res1$estimand_conditioning$quarantined_cell_count, 11L)
  expect_equal(length(res1$cells), 13L)

  # シード固定再現性（同一シードで再実行し全項目完全一致）
  res2 <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = multi_diag$M5$cell_table
  )

  expect_equal(res1, res2)

  # MCSEの妥当性確認 (0 <= MCSE <= 0.5 / sqrt(500))
  max_mcse <- 0.5 / sqrt(500)
  for (cell in res1$cells) {
    p_hat <- cell$top_k_selection_frequency_among_regular_cells$estimate
    mcse_val <- cell$top_k_selection_frequency_among_regular_cells$mcse
    expect_true(p_hat >= 0.0 && p_hat <= 1.0)
    expect_true(mcse_val >= 0.0 && mcse_val <= max_mcse + 1e-4)
  }
})

# -----------------------------------------------------------------------------
# TC-02: 閉形式モデル再推定と GLM 最尤解の同値性、0.5 補正、丸め前倍精度による元順位不変性 (F-CRR-002)
# -----------------------------------------------------------------------------
test_that("TC-02: M1/M5 閉形式再推定と stats::glm の同値性、0.5 補正、丸め前倍精度による順位不変性", {
  I <- length(flo_ucb$Dept)
  J <- length(flo_ucb$Gender)
  K_dim <- length(flo_ucb$Admit)

  grid <- expand.grid(Dept = flo_ucb$Dept, Gender = flo_ucb$Gender, Admit = flo_ucb$Admit, stringsAsFactors = FALSE)
  grid$id <- seq_len(nrow(grid))
  merged <- merge(grid, ucb_df, by = c("Dept", "Gender", "Admit"), sort = FALSE)
  merged <- merged[order(merged$id), ]
  y_obs <- merged$Freq
  total_n <- sum(y_obs)
  counts_arr <- array(y_obs, dim = c(I, J, K_dim))

  # M1 閉形式 vs GLM
  mu_m1_closed <- refit_m1_closed_form(counts_arr, I, J, K_dim, total_n)
  glm_m1 <- glm(Freq ~ Dept + Gender + Admit, data = merged, family = poisson)
  mu_m1_glm <- unname(fitted(glm_m1))
  expect_equal(mu_m1_closed, mu_m1_glm, tolerance = 1e-6)

  # M5 閉形式 vs GLM
  mu_m5_closed <- refit_m5_closed_form(counts_arr, I, J, K_dim)
  glm_m5 <- glm(Freq ~ Dept:Gender + Dept:Admit, data = merged, family = poisson)
  mu_m5_glm <- unname(fitted(glm_m5))
  expect_equal(mu_m5_closed, mu_m5_glm, tolerance = 1e-6)

  # ゼロ観測度数に対する 0.5 連続性補正の有限性検証
  y_zero <- y_obs
  y_zero[1] <- 0
  mu_sample <- mu_m5_closed
  metric_zero <- ifelse(y_zero > 0, abs(log(y_zero / mu_sample)), abs(log(0.5 / mu_sample)))
  expect_true(is.finite(metric_zero[1]))
  expect_equal(metric_zero[1], abs(log(0.5 / mu_sample[1])))
  expect_true(metric_zero[1] > 0)

  # F-CRR-002 検証: 表示用丸め済み Expected の改変に対して CRR 基準順位が不変であること
  fits <- fit_all_poisson_models(ucb_df, vars_3way, "Freq")
  multi_diag <- compute_multi_baseline_diagnostics(ucb_df, vars_3way, "Freq", fits, "M5", large_n_threshold = 2000)
  orig_diag_table <- multi_diag$M5$cell_table

  # 表示用 Expected を極端に粗く丸めた（整数への丸め）テーブルを作成
  corrupted_diag_table <- orig_diag_table
  corrupted_diag_table$Expected <- round(corrupted_diag_table$Expected, 0)

  crr_cfg <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 5L,
    iterations = 50L,
    seed = 20260912L
  )

  res_from_orig <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = orig_diag_table
  )

  res_from_corrupted <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = corrupted_diag_table
  )

  # 表示用 Expected の改変に関わらず、CRR は丸め前倍精度 fitted values から計算するため完全一致する
  expect_equal(res_from_orig$cells, res_from_corrupted$cells)

  # F-CRR-002: 閉形式解が失敗するケース（M1/M5 以外のモデル指定等）でフォールバックせず安全に HOLD されること
  crr_cfg_fail <- crr_cfg
  crr_cfg_fail$target_baseline_model <- "M9" # M9 は閉形式解の対象外
  res_refit_failed <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg_fail,
    baseline_diagnostics = orig_diag_table
  )
  expect_identical(res_refit_failed$status, "MODEL_REFIT_FAILED")
  expect_true(grepl("閉形式再推定が失敗.*したため", res_refit_failed$hold_reason))
  expect_null(res_refit_failed$cells)
  expect_false(res_refit_failed$quality_gate$passed)
})

# -----------------------------------------------------------------------------
# TC-03: 一次・二次入力境界の厳格な検証および quality_gate_minimum_valid_rate の事前拒否 (F-CRR-003)
# -----------------------------------------------------------------------------
test_that("TC-03: 入力境界エラーの検知、および quality_gate_minimum_valid_rate の事前拒否契約", {
  crr_base <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 5L,
    iterations = 100L,
    seed = 20260912L
  )

  # 1. 2変数指定での拒否
  err_2way <- validate_conditional_rank_reproducibility_data(
    crr = crr_base,
    df = ucb_df,
    vars = c("Dept", "Gender"),
    freq_col = "Freq",
    factor_levels_order = flo_ucb
  )
  expect_true(any(grepl("3変数", err_2way)))

  # 2. 不完全格子（1行削除して23行）
  ucb_incomplete <- ucb_df[-1L, ]
  err_incomp <- validate_conditional_rank_reproducibility_data(
    crr = crr_base,
    df = ucb_incomplete,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb
  )
  expect_true(any(grepl("完全セル格子ではありません", err_incomp)))

  # 3. 重複セル
  ucb_dup <- rbind(ucb_df, ucb_df[1L, ])
  err_dup <- validate_conditional_rank_reproducibility_data(
    crr = crr_base,
    df = ucb_dup,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb
  )
  expect_true(any(grepl("完全セル格子ではありません|重複したセル", err_dup)))

  # 4. 非整数度数
  ucb_float <- ucb_df
  ucb_float$Freq[1] <- 10.5
  err_float <- validate_conditional_rank_reproducibility_data(
    crr = crr_base,
    df = ucb_float,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb
  )
  expect_true(any(grepl("有限非負整数", err_float)))

  # 5. factor_levels_order 水準不整合
  flo_mismatch <- flo_ucb
  flo_mismatch$Dept <- c("A", "B", "C", "D", "E") # Fが欠損
  err_flo <- validate_conditional_rank_reproducibility_data(
    crr = crr_base,
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_mismatch
  )
  expect_true(any(grepl("完全一致しません", err_flo)))

  # 6. 二段階検証: K > eligible_cell_count の実行エラー
  fits <- fit_all_poisson_models(ucb_df, vars_3way, "Freq")
  multi_diag <- compute_multi_baseline_diagnostics(ucb_df, vars_3way, "Freq", fits, "M5", large_n_threshold = 2000)

  crr_k_over <- crr_base
  crr_k_over$top_k <- 14L # eligible is 13

  expect_error(
    compute_conditional_rank_reproducibility(
      df = ucb_df,
      vars = vars_3way,
      freq_col = "Freq",
      factor_levels_order = flo_ucb,
      crr_config = crr_k_over,
      baseline_diagnostics = multi_diag$M5$cell_table
    ),
    "top_k \\(14\\) が適格セル数 \\(13\\) を超過しています"
  )

  # 7. F-CRR-003: quality_gate_minimum_valid_rate の事前バリデーション拒否テスト (0 < x <= 1.0)
  base_cfg_obj <- list(
    input = ucb_path,
    vars = vars_3way,
    freq = "Freq",
    output_dir = tempdir(),
    run_id = "test_qg_validation",
    factor_levels_order = flo_ucb,
    conditional_rank_reproducibility = crr_base
  )

  # (a) 値 0.0 (拒否)
  cfg_a <- base_cfg_obj
  cfg_a$conditional_rank_reproducibility$quality_gate_minimum_valid_rate <- 0.0
  expect_error(validate_analysis_config(cfg_a), "0 < x <= 1.0 の実数である必要があります")

  # (b) 負値 -0.1 (拒否)
  cfg_b <- base_cfg_obj
  cfg_b$conditional_rank_reproducibility$quality_gate_minimum_valid_rate <- -0.1
  expect_error(validate_analysis_config(cfg_b), "0 < x <= 1.0 の実数である必要があります")

  # (c) 1超 1.05 (拒否)
  cfg_c <- base_cfg_obj
  cfg_c$conditional_rank_reproducibility$quality_gate_minimum_valid_rate <- 1.05
  expect_error(validate_analysis_config(cfg_c), "0 < x <= 1.0 の実数である必要があります")

  # (d) 非数値 "invalid" (拒否)
  cfg_d <- base_cfg_obj
  cfg_d$conditional_rank_reproducibility$quality_gate_minimum_valid_rate <- "invalid"
  expect_error(validate_analysis_config(cfg_d), "0 < x <= 1.0 の実数である必要があります")

  # (e) 有効値 0.90 (通過)
  cfg_e <- base_cfg_obj
  cfg_e$conditional_rank_reproducibility$quality_gate_minimum_valid_rate <- 0.90
  expect_silent(validate_analysis_config(cfg_e))
})

# -----------------------------------------------------------------------------
# TC-04: 運用品質ゲート（有効反復率と設定可能閾値による動的制御）(F-CRR-003)
# -----------------------------------------------------------------------------
test_that("TC-04: 固定疎 fixture による運用品質ゲート発動と閾値制御", {
  sparse_path <- file.path(getwd(), "tests/fixtures/sparse_rank_gate_test.csv")
  sparse_df <- read.csv(sparse_path, stringsAsFactors = FALSE)
  sparse_vars <- c("Layer", "Group", "Outcome")
  sparse_flo <- list(
    Layer = c("L1", "L2"),
    Group = c("G1", "G2"),
    Outcome = c("O1", "O2")
  )

  sparse_fits <- fit_all_poisson_models(sparse_df, sparse_vars, "Freq")
  sparse_diag <- compute_multi_baseline_diagnostics(sparse_df, sparse_vars, "Freq", sparse_fits, "M5", large_n_threshold = 2000)

  # (1) 完全疎 fixture (sparse_rank_gate_test.csv): valid_rate = 0.0 < 0.95 のため HOLD
  crr_sparse <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 1L,
    iterations = 500L,
    seed = 20260912L
  )

  res_sparse <- compute_conditional_rank_reproducibility(
    df = sparse_df,
    vars = sparse_vars,
    freq_col = "Freq",
    factor_levels_order = sparse_flo,
    crr_config = crr_sparse,
    baseline_diagnostics = sparse_diag$M5$cell_table
  )

  expect_identical(res_sparse$status, "INSUFFICIENT_VALID_REPLICATES")
  expect_false(res_sparse$quality_gate$passed)
  expect_equal(res_sparse$quality_gate$threshold, 0.95)
  expect_equal(res_sparse$quality_gate$valid_rate, 0.0)
  expect_equal(res_sparse$quality_gate$invalid_breakdown$rank_deficient, 500L)
  expect_null(res_sparse$cells)
  expect_true(grepl("有効反復率 .* 未満のため", res_sparse$hold_reason))

  # (2) 中程度の疎性 fixture: 有効反復率が約 85% となるデータセット
  # 既定 0.95 だと HOLD、カスタム 0.80 だと COMPUTED に切り替わることを検証
  partial_df <- data.frame(
    A = rep(c("A1", "A2"), each = 4),
    B = rep(rep(c("B1", "B2"), each = 2), 2),
    C = rep(c("C1", "C2"), 4),
    Freq = c(1, 1, 20, 20, 20, 20, 20, 20)
  )
  partial_flo <- list(A = c("A1", "A2"), B = c("B1", "B2"), C = c("C1", "C2"))
  partial_fits <- fit_all_poisson_models(partial_df, c("A", "B", "C"), "Freq")
  partial_diag <- compute_multi_baseline_diagnostics(partial_df, c("A", "B", "C"), "Freq", partial_fits, "M5", large_n_threshold = 100)

  # (2a) 未指定 / 0.95: 有効反復率 (約86%) < 0.95 のため HOLD
  crr_partial_def <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 2L,
    iterations = 500L,
    seed = 42L
  )
  res_p_def <- compute_conditional_rank_reproducibility(
    df = partial_df,
    vars = c("A", "B", "C"),
    freq_col = "Freq",
    factor_levels_order = partial_flo,
    crr_config = crr_partial_def,
    baseline_diagnostics = partial_diag$M5$cell_table
  )
  expect_identical(res_p_def$status, "INSUFFICIENT_VALID_REPLICATES")
  expect_false(res_p_def$quality_gate$passed)
  expect_equal(res_p_def$quality_gate$threshold, 0.95)
  expect_true(res_p_def$quality_gate$valid_rate > 0.80 && res_p_def$quality_gate$valid_rate < 0.95)

  # (2b) カスタム閾値 0.80 を設定: 有効反復率 (約86%) >= 0.80 のため COMPUTED で通過
  crr_partial_custom <- crr_partial_def
  crr_partial_custom$quality_gate_minimum_valid_rate <- 0.80

  res_p_cust <- compute_conditional_rank_reproducibility(
    df = partial_df,
    vars = c("A", "B", "C"),
    freq_col = "Freq",
    factor_levels_order = partial_flo,
    crr_config = crr_partial_custom,
    baseline_diagnostics = partial_diag$M5$cell_table
  )
  expect_identical(res_p_cust$status, "COMPUTED")
  expect_true(res_p_cust$quality_gate$passed)
  expect_equal(res_p_cust$quality_gate$threshold, 0.80)
  expect_true(length(res_p_cust$cells) > 0L)
})

# -----------------------------------------------------------------------------
# TC-05: 入力行順不変性と RFC 3986 構造化正準セルID・衝突回避・可逆性 (F-CRR-004)
# -----------------------------------------------------------------------------
test_that("TC-05: 入力行シャッフル不変性と RFC 3986 準拠 cell_id の一意性・衝突不能性・可逆性", {
  fits <- fit_all_poisson_models(ucb_df, vars_3way, "Freq")
  multi_diag <- compute_multi_baseline_diagnostics(ucb_df, vars_3way, "Freq", fits, "M5", large_n_threshold = 2000)

  crr_cfg <- list(
    enabled = TRUE,
    target_baseline_model = "M5",
    target_metric = "abs_log_oe",
    top_k = 5L,
    iterations = 200L,
    seed = 20260912L
  )

  res_orig <- compute_conditional_rank_reproducibility(
    df = ucb_df,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = multi_diag$M5$cell_table
  )

  # 行順をランダムにシャッフル
  set.seed(42)
  shuffled_idx <- sample(nrow(ucb_df))
  ucb_shuffled <- ucb_df[shuffled_idx, ]
  diag_shuffled <- multi_diag$M5$cell_table[shuffled_idx, ]

  res_shuffled <- compute_conditional_rank_reproducibility(
    df = ucb_shuffled,
    vars = vars_3way,
    freq_col = "Freq",
    factor_levels_order = flo_ucb,
    crr_config = crr_cfg,
    baseline_diagnostics = diag_shuffled
  )

  expect_equal(res_orig, res_shuffled)

  # cell_id の構造確認 (RFC 3986 準拠)
  for (cell in res_orig$cells) {
    expect_match(cell$cell_id, "^Dept=[A-F]/Gender=(Male|Female)/Admit=(Admitted|Rejected)$")
  }

  # 特殊文字（=, /, ,, %, 空白）を含む因子水準での衝突不能性と可逆性の検証 (F-CRR-004)
  special_vars <- c("FactorA", "FactorB", "FactorC")
  special_flo <- list(
    FactorA = c("D=1", "D"),
    FactorB = c("G/2", "1/G=2"),
    FactorC = c("A,1", "B 2")
  )

  # 完全格子の作成 (2 * 2 * 2 = 8 セル)
  special_df <- expand.grid(
    FactorA = special_flo$FactorA,
    FactorB = special_flo$FactorB,
    FactorC = special_flo$FactorC,
    stringsAsFactors = FALSE
  )
  special_df$Freq <- rep(50L, nrow(special_df))

  special_fits <- fit_all_poisson_models(special_df, special_vars, "Freq")
  special_diag <- compute_multi_baseline_diagnostics(special_df, special_vars, "Freq", special_fits, "M1", large_n_threshold = 100)

  crr_special <- list(
    enabled = TRUE,
    target_baseline_model = "M1",
    target_metric = "abs_log_oe",
    top_k = 2L,
    iterations = 50L,
    seed = 20260912L
  )

  res_special <- compute_conditional_rank_reproducibility(
    df = special_df,
    vars = special_vars,
    freq_col = "Freq",
    factor_levels_order = special_flo,
    crr_config = crr_special,
    baseline_diagnostics = special_diag$M1$cell_table
  )

  all_ids <- vapply(res_special$cells, function(x) x$cell_id, character(1L))
  # 全 cell_id が完全一意
  expect_equal(length(all_ids), length(unique(all_ids)))

  # 具体的衝突ペアの検証:
  # ペア1: FactorA="D=1", FactorB="G/2" -> 期待: FactorA=D%3D1/FactorB=G%2F2/...
  # ペア2: FactorA="D", FactorB="1/G=2" -> 期待: FactorA=D/FactorB=1%2FG%3D2/...
  id_pair1 <- all_ids[grepl("FactorA=D%3D1/FactorB=G%2F2", all_ids)]
  id_pair2 <- all_ids[grepl("FactorA=D/FactorB=1%2FG%3D2", all_ids)]
  expect_true(length(id_pair1) > 0L)
  expect_true(length(id_pair2) > 0L)
  expect_true(all(id_pair1 != id_pair2))

  # 可逆性の検証: cell_id を / 分割 -> 最初の = 分割 -> URLdecode で元水準値が完全復元されること
  for (cell in res_special$cells) {
    tokens <- strsplit(cell$cell_id, "/", fixed = TRUE)[[1L]]
    expect_equal(length(tokens), 3L)
    for (t_idx in seq_along(tokens)) {
      eq_pos <- regexpr("=", tokens[t_idx], fixed = TRUE)
      expect_true(eq_pos > 1)
      raw_k <- utils::URLdecode(substr(tokens[t_idx], 1, eq_pos - 1))
      raw_v <- utils::URLdecode(substr(tokens[t_idx], eq_pos + 1, nchar(tokens[t_idx])))
      expect_equal(raw_k, special_vars[t_idx])
      expect_equal(raw_v, cell$factors[[special_vars[t_idx]]])
    }
  }
})

# -----------------------------------------------------------------------------
# TC-06: 未指定時の後方互換性と 1 ビット不変性テスト (F-CRR-005)
# -----------------------------------------------------------------------------
test_that("TC-06: conditional_rank_reproducibility 未指定時の後方互換性と再現性", {
  temp_dir <- tempfile("crr_test_")
  dir.create(temp_dir, recursive = TRUE)
  out_dir1 <- file.path(temp_dir, "output1")
  out_dir2 <- file.path(temp_dir, "output2")
  dir.create(out_dir1)
  dir.create(out_dir2)

  config_data1 <- list(
    input = ucb_path,
    vars = vars_3way,
    freq = "Freq",
    output_dir = out_dir1,
    run_id = "test_backward_compat_run1",
    base_models = c("M1", "M5"),
    seed = 42L
  )
  cfg_file1 <- file.path(temp_dir, "analysis_config1.json")
  write_json(config_data1, cfg_file1, auto_unbox = TRUE)

  # analysis.R 実行 1
  cmd1 <- sprintf("Rscript %s --config %s", file.path(script_dir, "analysis.R"), cfg_file1)
  exit_code1 <- system(cmd1)
  expect_equal(exit_code1, 0L)

  run_dirs1 <- list.dirs(out_dir1, full.names = TRUE, recursive = FALSE)
  expect_true(length(run_dirs1) >= 1L)
  ev_file1 <- file.path(run_dirs1[1L], "evidence_results.json")
  expect_true(file.exists(ev_file1))

  res_json1 <- fromJSON(ev_file1, simplifyVector = FALSE)
  # 新オブジェクト不在
  expect_null(res_json1$conditional_rank_reproducibility)
  expect_true(!("conditional_rank_reproducibility" %in% names(res_json1)))

  # 既存ゴールデン fixture との比較 (ucb_admissions_three_way_v1)
  golden_path <- file.path(getwd(), "tests/fixtures/dashboard_ui/ucb_admissions_three_way_v1/evidence_results.json")
  if (file.exists(golden_path)) {
    golden_json <- fromJSON(golden_path, simplifyVector = FALSE)
    # モデル比較結果 (M1〜M9 の deviance, df, bic) がゴールデンと完全一致
    expect_equal(res_json1$model_comparison, golden_json$model_comparison)
    # 多重基準セル診断 (M1, M5) の構造・キーが完全一致
    expect_equal(names(res_json1$cell_diagnostics), names(golden_json$cell_diagnostics))
    expect_equal(res_json1$cell_diagnostics$M5$counts, golden_json$cell_diagnostics$M5$counts)
  }

  # 同一条件・固定タイムスタンプ無依存な統計セクションの完全同一性
  config_data2 <- config_data1
  config_data2$output_dir <- out_dir2
  config_data2$run_id <- "test_backward_compat_run1" # 同一run_id
  cfg_file2 <- file.path(temp_dir, "analysis_config2.json")
  write_json(config_data2, cfg_file2, auto_unbox = TRUE)

  cmd2 <- sprintf("Rscript %s --config %s", file.path(script_dir, "analysis.R"), cfg_file2)
  exit_code2 <- system(cmd2)
  expect_equal(exit_code2, 0L)

  run_dirs2 <- list.dirs(out_dir2, full.names = TRUE, recursive = FALSE)
  ev_file2 <- file.path(run_dirs2[1L], "evidence_results.json")
  res_json2 <- fromJSON(ev_file2, simplifyVector = FALSE)

  # provenance 内の executed_at 以外を完全比較
  res_json1_clean <- res_json1
  res_json2_clean <- res_json2
  res_json1_clean$provenance$executed_at <- NULL
  res_json2_clean$provenance$executed_at <- NULL
  expect_equal(res_json1_clean, res_json2_clean)

  # F-CRR-005: 決定論的タイムスタンプ注入による 1ビット後方互換性（SHA-256完全一致）検証
  golden_cfg_path <- file.path(getwd(), "tests/fixtures/dashboard_ui/ucb_admissions_three_way_v1/analysis_config.json")
  if (file.exists(golden_cfg_path) && file.exists(golden_path)) {
    out_dir_golden <- file.path(temp_dir, "output_golden")
    dir.create(out_dir_golden)
    golden_cfg_data <- fromJSON(golden_cfg_path, simplifyVector = FALSE)
    golden_cfg_data$output_dir <- out_dir_golden
    golden_test_cfg <- file.path(temp_dir, "golden_test_config.json")
    write_json(golden_cfg_data, golden_test_cfg, auto_unbox = TRUE)

    # ゴールデン fixture のタイムスタンプ "2026-09-12T08:37:06+0900" を環境変数で注入
    cmd_golden <- sprintf("ANALYSIS_EXEC_TIMESTAMP=\"2026-09-12T08:37:06+0900\" Rscript %s --config %s",
                          file.path(script_dir, "analysis.R"), golden_test_cfg)
    exit_golden <- system(cmd_golden)
    expect_equal(exit_golden, 0L)

    golden_run_dirs <- list.dirs(out_dir_golden, full.names = TRUE, recursive = FALSE)
    expect_true(length(golden_run_dirs) >= 1L)
    gen_ev_file <- file.path(golden_run_dirs[1L], "evidence_results.json")
    expect_true(file.exists(gen_ev_file))

    # SHA-256 ハッシュおよび生バイト単位の完全一致（1ビット不変性）アサーション
    golden_sha256 <- sha256_file(golden_path)
    gen_sha256 <- sha256_file(gen_ev_file)
    expect_identical(gen_sha256, golden_sha256)

    golden_bytes <- readBin(golden_path, "raw", file.info(golden_path)$size)
    gen_bytes <- readBin(gen_ev_file, "raw", file.info(gen_ev_file)$size)
    expect_identical(gen_bytes, golden_bytes)
  }
})
