# =============================================================================
# freeze_baseline_3956f22.R
# タスク 1.1: 変更前比較基準（コミット 3956f22）の固定・記録スクリプト
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(stats)
  library(digest)
})

repo_root <- getwd()
input_csv <- file.path(repo_root, "examples/ucb_admissions.csv")
config_json <- file.path(repo_root, "output/ucb_admissions/run_admit_bias/analysis_config.json")
existing_results_json <- file.path(repo_root, "output/ucb_admissions/run_admit_bias/evidence_results.json")
out_dir <- file.path(repo_root, "tests/fixtures/baseline_3956f22")

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

message("[INFO] 変更前ベースライン固定処理を開始します...")

# 1. ファイルハッシュ (SHA-256) 記録
sha_input <- digest::digest(input_csv, file = TRUE, algo = "sha256")
sha_config <- digest::digest(config_json, file = TRUE, algo = "sha256")
sha_results <- digest::digest(existing_results_json, file = TRUE, algo = "sha256")

message(paste("[INFO] Input CSV SHA256:     ", sha_input))
message(paste("[INFO] Config JSON SHA256:   ", sha_config))
message(paste("[INFO] Results JSON SHA256:  ", sha_results))

# 2. 既存の成果物をベースラインとして複製退避
file.copy(config_json, file.path(out_dir, "analysis_config_baseline.json"), overwrite = TRUE)
file.copy(existing_results_json, file.path(out_dir, "evidence_results_baseline.json"), overwrite = TRUE)

# 3. 変更前エンジン（現行 pass1_compute.R）をロードして参照計算
source(file.path(repo_root, ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass1_compute.R"))

cfg <- jsonlite::fromJSON(config_json)
df <- read.csv(input_csv, stringsAsFactors = FALSE)
cat_vars <- cfg$vars
freq_col <- cfg$freq

model_fits <- fit_all_poisson_models(df, cat_vars, freq_col)

# 4. 全モデルの詳細適合値（logLik, fitted_values, coefficients, 丸め前bic/deviance）を抽出
reference_fits <- list()
for (m_id in names(model_fits$models)) {
  m <- model_fits$models[[m_id]]
  fit_obj <- m$fit
  
  reference_fits[[m_id]] <- list(
    model_id = m_id,
    model_name = m$name,
    df_residual = m$df_residual,
    deviance = m$deviance,
    loglik = m$loglik,
    bic_explicit = m$bic,
    rank = m$rank,
    coefficients = as.list(coef(fit_obj)),
    fitted_values = as.numeric(m$fitted_values),
    residuals_pearson = as.numeric(m$residuals_pearson),
    residuals_deviance = as.numeric(m$residuals_deviance),
    leverage = as.numeric(m$leverage)
  )
}

ref_fits_path <- file.path(out_dir, "baseline_reference_fits.json")
write_json(reference_fits, ref_fits_path, pretty = TRUE, auto_unbox = TRUE, digits = 12)
sha_ref_fits <- digest::digest(ref_fits_path, file = TRUE, algo = "sha256")

# 5. ベースラインマニフェストの生成
manifest <- list(
  baseline_commit = "3956f22",
  frozen_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  input_csv = list(
    path = "examples/ucb_admissions.csv",
    sha256 = sha_input,
    nrow = nrow(df),
    total_freq = sum(df[[freq_col]])
  ),
  config = list(
    path = "output/ucb_admissions/run_admit_bias/analysis_config.json",
    sha256 = sha_config
  ),
  existing_results = list(
    path = "output/ucb_admissions/run_admit_bias/evidence_results.json",
    sha256 = sha_results
  ),
  reference_fits = list(
    path = "tests/fixtures/baseline_3956f22/baseline_reference_fits.json",
    sha256 = sha_ref_fits,
    model_ids = names(reference_fits),
    best_model_id = model_fits$best_model_id
  )
)

manifest_path <- file.path(out_dir, "baseline_manifest.json")
write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)

message(paste("[SUCCESS] ベースライン固定完了:", manifest_path))
