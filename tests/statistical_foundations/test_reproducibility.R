#!/usr/bin/env Rscript
# tests/statistical_foundations/test_reproducibility.R
# 再現性と出力隔離の検証テスト

suppressPackageStartupMessages({
  library(jsonlite)
})

td <- tempfile("test_repro_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

cfg_src <- "tests/fixtures/statistical_foundations/configs/cfg_syn_independent.json"
cfg <- fromJSON(cfg_src, simplifyVector = FALSE)

# Run 1
cfg1 <- cfg
cfg1$output_dir <- td
cfg1$run_id <- "repro_run_01"
p1 <- file.path(td, "cfg1.json")
write_json(cfg1, p1, auto_unbox = TRUE, pretty = TRUE)

st1 <- system(sprintf("Rscript tests/statistical_foundations/run_validation.R --config %s", p1))
stopifnot(st1 == 0)

# Run 2 (同じ設定・乱数シード、別run_id)
cfg2 <- cfg
cfg2$output_dir <- td
cfg2$run_id <- "repro_run_02"
p2 <- file.path(td, "cfg2.json")
write_json(cfg2, p2, auto_unbox = TRUE, pretty = TRUE)

st2 <- system(sprintf("Rscript tests/statistical_foundations/run_validation.R --config %s", p2))
stopifnot(st2 == 0)

# 2つの結果JSONを比較
res1 <- fromJSON(file.path(td, "run_repro_run_01", "validation_results.json"))
res2 <- fromJSON(file.path(td, "run_repro_run_02", "validation_results.json"))

# 決定論的値の一致
stopifnot(identical(res1$models$M1$deviance, res2$models$M1$deviance))
stopifnot(identical(res1$models$M1$loglik, res2$models$M1$loglik))
stopifnot(identical(res1$models$M1$bic_sample_size_n, res2$models$M1$bic_sample_size_n))

# 厳密BFの一致
stopifnot(identical(res1$posterior$exact_marginal_likelihood_and_bf$log_bf_exact_sat_vs_ind,
                    res2$posterior$exact_marginal_likelihood_and_bf$log_bf_exact_sat_vs_ind))

# 確率的推定（seed固定MC平均・カバレッジ）の一致
stopifnot(identical(res1$posterior$monte_carlo_calibration$max_mean_abs_diff,
                    res2$posterior$monte_carlo_calibration$max_mean_abs_diff))
stopifnot(identical(res1$posterior$monte_carlo_calibration$max_coverage_prob_diff,
                    res2$posterior$monte_carlo_calibration$max_coverage_prob_diff))

message("[PASS] 再実行において決定論的値および乱数推定値が完全一致")
message("[PASS] 異なるrun_idで互いに干渉せず出力隔離が成立")
message("=== 再現性・隔離性テスト合格 ===")
