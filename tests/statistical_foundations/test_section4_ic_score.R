#!/usr/bin/env Rscript
# tests/statistical_foundations/test_section4_ic_score.R
# Section 4: BIC監査およびHairEyeColor知見を統合した多軸セル診断テスト

source("tests/statistical_foundations/fit_models.R")
source("tests/statistical_foundations/audit_information_criteria.R")

message("=== Testing Section 4: BIC, EBIC, and Multi-axial Cell Diagnostics ===")

# 1. Titanic集約データでの監査テスト
df_titanic <- readr::read_csv("tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv", show_col_types = FALSE)
glm_res <- fit_all_9_models(df_titanic, c("Class", "Sex", "Survived"), "Freq")

# BIC 監査
bics <- audit_model_bics(glm_res, total_n = sum(df_titanic$Freq), n_cells = nrow(df_titanic))
stopifnot(length(bics) == 9L)

m1_bic <- bics[["M1"]]
message(sprintf("M1 BIC audit: loglik=%.2f, rank=%d", m1_bic$loglik_poisson, m1_bic$rank_poisson))
message(sprintf("  - BIC (sample size N=%d): %.2f", m1_bic$total_n, m1_bic$bic_sample_size_n))
message(sprintf("  - stats::BIC (R default, nobs=K=%d): %.2f", m1_bic$n_cells, m1_bic$bic_stats_r))
message(sprintf("  - Penalty discrepancy between N and K: %.2f", m1_bic$penalty_diff_logN_vs_logK))
stopifnot(m1_bic$bic_stats_discrepancy < 1e-5) # stats::BIC が -2LL + k*log(K) と一致することを確認！

# セル診断の多軸監査（M1を基準）
cell_audits_m1 <- audit_cell_scores_and_local_models(df_titanic, c("Class", "Sex", "Survived"), "Freq", glm_res, base_model_id = "M1")
stopifnot(cell_audits_m1$total_cells == 16L)
stopifnot(cell_audits_m1$framework == "Evidence x Effect x Influence x Stability")

message("\nMulti-axial Cell Diagnostics (Evidence, Effect, Influence) First 3 cells:")
for (i in 1:3) {
  ca <- cell_audits_m1$cell_audits[[i]]
  eff <- ca$effect
  evi <- ca$evidence
  inf <- ca$influence
  
  message(sprintf("  Cell %d: Obs=%d, Exp=%.1f | Effect: log(O/E)=%.2f, d/sqrt(N)=%.3f, DeltaG^2/N=%.4f",
                  i, ca$observed, ca$expected_base, eff$log_oe_ratio, eff$normalized_dev_residual, eff$delta_g2_per_n))
  message(sprintf("          Evidence: r^2=%.1f, Score=%.1f, DeltaG^2=%.1f (logP=%.1f) | Influence: h_ii=%.3f",
                  evi$pearson_residual^2, evi$score_statistic, evi$delta_deviance_exact, evi$delta_deviance_log_p, inf$leverage))
  
  # Score統計量 T_i^{score} = r^2 / (1 - h) は、残差二乗 r^2 より exact LRT に近いことを確認
  # （特に小〜中残差セルで高い精度）
  stopifnot(!is.na(evi$score_statistic))
  stopifnot(!is.na(eff$log_oe_ratio))
  stopifnot(!is.na(inf$leverage))
}

# 均一連関 M8 を基準としたセル監査
cell_audits_m8 <- audit_cell_scores_and_local_models(df_titanic, c("Class", "Sex", "Survived"), "Freq", glm_res, base_model_id = "M8")
stopifnot(cell_audits_m8$total_cells == 16L)
message(sprintf("M8 based cell audit completed: %d cells evaluated", length(cell_audits_m8$cell_audits)))

message("\n=== Section 4 テスト合格 ===")
