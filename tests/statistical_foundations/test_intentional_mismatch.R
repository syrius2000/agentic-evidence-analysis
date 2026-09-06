#!/usr/bin/env Rscript
# tests/statistical_foundations/test_intentional_mismatch.R
# 陰性対照テスト（意図的誤差・閉形式不一致・検証失敗時の非ゼロ終了を正しく検出するか）

suppressPackageStartupMessages({
  library(jsonlite)
})

source("tests/statistical_foundations/fit_models.R")
source("tests/statistical_foundations/reference_values.R")
source("tests/statistical_foundations/check_results.R")

df <- readr::read_csv("tests/fixtures/statistical_foundations/syn_independent.csv", show_col_types = FALSE)
glm_res <- fit_all_9_models(df, c("A", "B", "C"), "Freq")
ref_res <- extract_reference_values(df, c("A", "B", "C"), "Freq")

# 1. 正常時確認
normal_chk <- check_model_against_reference(glm_res, ref_res, list(glm_vs_loglin_fitted_rel_tol = 1e-5))
stopifnot(normal_chk$all_reference_checks_passed == TRUE)
message("[PASS] 正常時は全照合パス")

# 2. 意図的改変 A: M1のIPF参照適合値に誤差混入
corrupted_ref_ipf <- ref_res
corrupted_ref_ipf$models$M1$loglin_fitted <- corrupted_ref_ipf$models$M1$loglin_fitted * 1.5

chk_ipf <- check_model_against_reference(glm_res, corrupted_ref_ipf, list(glm_vs_loglin_fitted_rel_tol = 1e-5))
stopifnot(chk_ipf$all_reference_checks_passed == FALSE)
stopifnot(chk_ipf$per_model_checks$M1$fitted_match == FALSE)
stopifnot(chk_ipf$per_model_checks$M1$check_passed == FALSE)
message("[PASS] IPF参照値の意図的不一致を正しく検出し不合格を報告")

# 3. 意図的改変 B: M1の閉形式解 (closed_form_fitted) にのみ誤差混入
# （IPF解とGLM解は一致しているが閉形式解だけずれている場合）
corrupted_ref_cf <- ref_res
corrupted_ref_cf$models$M1$closed_form_fitted <- corrupted_ref_cf$models$M1$closed_form_fitted * 1.2

chk_cf <- check_model_against_reference(glm_res, corrupted_ref_cf, list(glm_vs_loglin_fitted_rel_tol = 1e-5))
stopifnot(chk_cf$all_reference_checks_passed == FALSE) # 閉形式不一致により全体不合格になること！
stopifnot(chk_cf$per_model_checks$M1$closed_form_match == FALSE)
stopifnot(chk_cf$per_model_checks$M1$check_passed == FALSE)
message("[PASS] 閉形式解の意図的不一致を正しく総合不合格として検出 (cf_match総合組み込み確認)")

# 4. run_validation.R の検証失敗時における非ゼロ終了（exit 1）の検証
td <- tempfile("test_fail_exit_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

fail_cfg <- list(
  schema_version = "3way-foundation-v1",
  input = "tests/fixtures/statistical_foundations/syn_independent.csv",
  vars = c("A", "B", "C"),
  freq = "Freq",
  response_var = NULL,
  output_dir = td,
  run_id = "test_fail_exit",
  sampling = list(
    unit = "人工観測単位",
    total_n_meaning = "意図的検証失敗テスト用",
    independence_assumption = "assumed_independent",
    is_scaled = FALSE
  ),
  # 達成不能な極小許容誤差を設定して意図的にCHECK_FAILEDを引き起こす
  reference_tolerance = list(
    glm_vs_loglin_fitted_rel_tol = 1e-20,
    glm_vs_loglin_deviance_abs_tol = 1e-20
  )
)
fail_cfg_path <- file.path(td, "fail_cfg.json")
write_json(fail_cfg, fail_cfg_path, auto_unbox = TRUE, pretty = TRUE)

st_fail <- system(sprintf("Rscript tests/statistical_foundations/run_validation.R --config %s", fail_cfg_path))
# 終了コードが 1（非ゼロ）でなければならない！
stopifnot(st_fail == 1)
message("[PASS] run_validation.R は検証失敗時に確実に非ゼロ終了コード (status=1) で exit することを確認")

message("\n=== 陰性対照テスト 全件合格 ===")
