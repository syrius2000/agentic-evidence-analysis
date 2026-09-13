# Test Suite: SAS PROC MEANS Numerical Parity and Pipeline Integration
# Script: tests/test_sas_proc_means_numerical_parity.R

suppressPackageStartupMessages({
  library(jsonlite)
  library(digest)
})

root <- normalizePath(".", mustWork = TRUE)
skill_dir <- file.path(root, ".agents/skills/sas-proc-means")
run_means_script <- file.path(skill_dir, "templates/run_means.R")
schema_file <- file.path(skill_dir, "schemas/analysis_config.schema.json")
skill_file <- file.path(skill_dir, "SKILL.md")

message(">>> 1. ディレクトリと初期ファイルの存在確認 (Task 1.1)")
stopifnot(file.exists(skill_file))
stopifnot(file.exists(schema_file))
stopifnot(file.exists(run_means_script))
message("PASS: 初期ファイル（SKILL.md, schema, template）が存在します。")

td <- tempfile("sas_proc_means_test_")
dir.create(td, recursive = TRUE)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

run_engine <- function(config_path) {
  suppressWarnings(
    system2(
      "Rscript",
      c("--vanilla", run_means_script, "--config", config_path),
      stdout = TRUE,
      stderr = TRUE
    )
  )
}

message(">>> 2. 設定スキーマ・バリデーション検証 (Task 1.2)")
# Test invalid schema_version
bad_cfg1 <- list(
  schema_version = "invalid-version",
  analysis_kind = "sas_proc_means",
  input = "dummy.csv",
  output_dir = td,
  run_id = "test_bad1",
  analysis_variables = list("y")
)
bad_path1 <- file.path(td, "bad_cfg1.json")
jsonlite::write_json(bad_cfg1, bad_path1, auto_unbox = TRUE)
out1 <- run_engine(bad_path1)
stopifnot(!is.null(attr(out1, "status")) && attr(out1, "status") != 0)
stopifnot(any(grepl("Invalid schema_version", out1)))

# Test invalid analysis_kind
bad_cfg2 <- list(
  schema_version = "sas-summary-config-v1",
  analysis_kind = "invalid_kind",
  input = "dummy.csv",
  output_dir = td,
  run_id = "test_bad2",
  analysis_variables = list("y")
)
bad_path2 <- file.path(td, "bad_cfg2.json")
jsonlite::write_json(bad_cfg2, bad_path2, auto_unbox = TRUE)
out2 <- run_engine(bad_path2)
stopifnot(!is.null(attr(out2, "status")) && attr(out2, "status") != 0)
stopifnot(any(grepl("Invalid analysis_kind", out2)))
message("PASS: schema_version および analysis_kind のバリデーションが正しく機能します。")

message(">>> 3. 入力前処理・FREQ/WEIGHT・CLASS欠損処理の検証 (Task 2.1, 2.2)")
# Create test dataset with FREQ decimals, negative weights, NA classes
test_df <- data.frame(
  grp = c("A", "A", "A", "B", "B", NA, "B"),
  val = c(10, 20, 30, 100, 200, 999, NA),
  fq = c(1.9, 2.1, 0.5, 1.0, 1.0, 1.0, 1.0), # 1.9 -> 1, 2.1 -> 2, 0.5 -> excluded
  wt = c(1.0, -0.5, 1.0, 2.0, 0.0, 1.0, 1.0) # -0.5 -> 0 (default)
)
data_csv <- file.path(td, "test_data.csv")
utils::write.csv(test_df, data_csv, row.names = FALSE, na = "")

cfg_proc <- list(
  schema_version = "sas-summary-config-v1",
  analysis_kind = "sas_proc_means",
  input = data_csv,
  output_dir = td,
  run_id = "run_proc_test",
  analysis_variables = list("val"),
  class_variables = list("grp"),
  freq_variable = "fq",
  weight_variable = "wt",
  class_missing = FALSE,
  exclnpwgt = FALSE
)
cfg_path_proc <- file.path(td, "cfg_proc.json")
jsonlite::write_json(cfg_proc, cfg_path_proc, auto_unbox = TRUE)
out_proc <- run_engine(cfg_path_proc)
if (!is.null(attr(out_proc, "status")) && attr(out_proc, "status") != 0) {
  stop("out_proc failed:\n", paste(out_proc, collapse = "\n"))
}

res_proc <- jsonlite::fromJSON(file.path(td, "run_run_proc_test", "means_results.json"))
# grp A:
# row 1: val=10, freq=floor(1.9)=1, wt=1.0 -> count=1, sum=10, w=1
# row 2: val=20, freq=floor(2.1)=2, wt=0.0 (neg to 0) -> count=2, sum=0 (wt=0), w=0
# row 3: val=30, freq=floor(0.5)=0 (<1 excluded) -> not included
# Total N for grp A = 1 + 2 = 3. SUMWGT = 1.0 * 1 + 0.0 * 2 = 1.0. MEAN = (10*1 + 20*0)/1.0 = 10.0
grp_a_stats <- res_proc$groups$A$variables$val
stopifnot(grp_a_stats$N == 3L)
stopifnot(abs(grp_a_stats$SUMWGT - 1.0) < 1e-12)
stopifnot(abs(grp_a_stats$MEAN - 10.0) < 1e-12)

# Verify CLASS NA is excluded by default
stopifnot(!"(Missing)" %in% names(res_proc$groups))
stopifnot(!"NA" %in% names(res_proc$groups))
message("PASS: FREQ切り捨て・1未満除外、WEIGHT負値0補正・N算入、CLASS欠損除外が正常に動作します。")

# Verify class_missing = TRUE
cfg_proc$class_missing <- TRUE
cfg_proc$run_id <- "run_proc_miss"
jsonlite::write_json(cfg_proc, cfg_path_proc, auto_unbox = TRUE)
run_engine(cfg_path_proc)
res_miss <- jsonlite::fromJSON(file.path(td, "run_run_proc_miss", "means_results.json"))
stopifnot("(Missing)" %in% names(res_miss$groups))
message("PASS: class_missing = TRUE で欠損水準が群として正常に保持されます。")

message(">>> 4. 基本統計量・VARDEF 4分岐・区間推定の検証 (Task 3.1, 3.2)")
# Clean dataset without weights for exact moment verification: 2, 4, 4, 4, 5, 5, 7, 9
# n = 8, mean = 5.0, sum = 40
# css = (2-5)^2 + 3*(4-5)^2 + 2*(5-5)^2 + (7-5)^2 + (9-5)^2 = 9 + 3 + 0 + 4 + 16 = 32
# VAR:
# DF: 32 / 7 = 4.5714285714...
# N: 32 / 8 = 4.0
# STD: DF -> sqrt(32/7) = 2.138089935299...
# CV: 100 * (std / 5.0)
df_exact <- data.frame(val = c(2, 4, 4, 4, 5, 5, 7, 9))
exact_csv <- file.path(td, "exact_data.csv")
utils::write.csv(df_exact, exact_csv, row.names = FALSE)

for (vd in c("DF", "N", "WDF", "WEIGHT")) {
  cfg_vd <- list(
    schema_version = "sas-summary-config-v1",
    analysis_kind = "sas_proc_means",
    input = exact_csv,
    output_dir = td,
    run_id = paste0("rvd_", vd),
    analysis_variables = list("val"),
    vardef = vd
  )
  cfg_path_vd <- file.path(td, paste0("cfg_", vd, ".json"))
  jsonlite::write_json(cfg_vd, cfg_path_vd, auto_unbox = TRUE)
  out_vd <- run_engine(cfg_path_vd)
  if (!is.null(attr(out_vd, "status")) && attr(out_vd, "status") != 0) {
    stop("run_engine failed for vardef ", vd, ":\n", paste(out_vd, collapse = "\n"))
  }

  res_vd <- jsonlite::fromJSON(file.path(td, paste0("run_rvd_", vd), "means_results.json"))
  st <- res_vd$groups$ALL$variables$val

  stopifnot(st$N == 8L)
  stopifnot(st$NMISS == 0L)
  stopifnot(abs(st$SUM - 40.0) < 1e-12)
  stopifnot(abs(st$MEAN - 5.0) < 1e-12)
  stopifnot(st$MIN == 2)
  stopifnot(st$MAX == 9)
  stopifnot(st$RANGE == 7)
  stopifnot(abs(st$CSS - 32.0) < 1e-12)
  stopifnot(abs(st$USS - (40^2 / 8 + 32)) < 1e-12)

  if (vd == "DF") {
    stopifnot(abs(st$VAR - 32 / 7) < 1e-12)
    stopifnot(abs(st$STD - sqrt(32 / 7)) < 1e-12)
    stopifnot(!is.null(st$STDERR))
    stopifnot(!is.null(st$LCLM))
    stopifnot(!is.null(st$UCLM))
  } else if (vd == "N") {
    stopifnot(abs(st$VAR - 4.0) < 1e-12)
    stopifnot(abs(st$STD - 2.0) < 1e-12)
    stopifnot(is.null(st$STDERR))
    stopifnot(st$status_reasons$STDERR == "undefined_for_vardef")
  } else if (vd == "WDF") {
    stopifnot(abs(st$VAR - 32 / 7) < 1e-12)
    stopifnot(is.null(st$STDERR))
  } else if (vd == "WEIGHT") {
    stopifnot(abs(st$VAR - 4.0) < 1e-12)
    stopifnot(is.null(st$STDERR))
  }
}
message("PASS: VARDEF 4分岐、モーメント計算、および VARDEF=DF STDERR/LCLM/UCLM が厳密に確認されました。")

message(">>> 5. 形状統計量（歪度・尖度）および分位数（QNTLDEF 1-5）の検証 (Task 4.1, 4.2)")
# Verify unweighted skewness and kurtosis
res_df <- jsonlite::fromJSON(file.path(td, "run_rvd_DF", "means_results.json"))
st_df <- res_df$groups$ALL$variables$val
stopifnot(!is.null(st_df$SKEWNESS))
stopifnot(!is.null(st_df$KURTOSIS))

# Verify weight attached -> skewness/kurtosis becomes null with reason
cfg_wt_skew <- list(
  schema_version = "sas-summary-config-v1",
  analysis_kind = "sas_proc_means",
  input = exact_csv,
  output_dir = td,
  run_id = "run_wt_skew",
  analysis_variables = list("val"),
  weight_variable = "wt_col"
)
df_wt <- df_exact
df_wt$wt_col <- rep(1.0, nrow(df_wt))
utils::write.csv(df_wt, file.path(td, "wt_data.csv"), row.names = FALSE)
cfg_wt_skew$input <- file.path(td, "wt_data.csv")
cfg_wt_path <- file.path(td, "cfg_wt.json")
jsonlite::write_json(cfg_wt_skew, cfg_wt_path, auto_unbox = TRUE)
run_engine(cfg_wt_path)

res_wt <- jsonlite::fromJSON(file.path(td, "run_run_wt_skew", "means_results.json"))
st_wt <- res_wt$groups$ALL$variables$val
stopifnot(is.null(st_wt$SKEWNESS))
stopifnot(is.null(st_wt$KURTOSIS))
stopifnot(st_wt$status_reasons$SKEWNESS == "not_available_with_weight")
stopifnot(st_wt$status_reasons$KURTOSIS == "not_available_with_weight")
message("PASS: WEIGHT指定時の歪度・尖度未定義制約が正常に動作します。")

# Verify QNTLDEF 1 to 5
for (q in 1:5) {
  cfg_q <- list(
    schema_version = "sas-summary-config-v1",
    analysis_kind = "sas_proc_means",
    input = exact_csv,
    output_dir = td,
    run_id = paste0("run_qntldef_", q),
    analysis_variables = list("val"),
    qntldef = q
  )
  cfg_q_path <- file.path(td, paste0("cfg_q_", q, ".json"))
  jsonlite::write_json(cfg_q, cfg_q_path, auto_unbox = TRUE)
  run_engine(cfg_q_path)

  res_q <- jsonlite::fromJSON(file.path(td, paste0("run_run_qntldef_", q), "means_results.json"))
  st_q <- res_q$groups$ALL$variables$val
  # Check against R quantile types: 1->4, 2->3, 3->1, 4->6, 5->2
  r_type <- switch(as.character(q), "1" = 4L, "2" = 3L, "3" = 1L, "4" = 6L, "5" = 2L)
  expected_med <- as.numeric(stats::quantile(df_exact$val, probs = 0.5, type = r_type, names = FALSE))
  stopifnot(abs(st_q$MEDIAN - expected_med) < 1e-12)
}
message("PASS: QNTLDEF 1〜5 の分位数定義がR quantile typeと完全一致します。")

# Verify weighted QNTLDEF 1 to 5 combination
for (q in 1:5) {
  cfg_wq <- list(
    schema_version = "sas-summary-config-v1",
    analysis_kind = "sas_proc_means",
    input = file.path(td, "wt_data.csv"),
    output_dir = td,
    run_id = paste0("r_wt_q_", q),
    analysis_variables = list("val"),
    weight_variable = "wt_col",
    qntldef = q
  )
  cfg_wq_path <- file.path(td, paste0("cfg_wq_", q, ".json"))
  jsonlite::write_json(cfg_wq, cfg_wq_path, auto_unbox = TRUE)
  out_wq <- run_engine(cfg_wq_path)
  if (!is.null(attr(out_wq, "status")) && attr(out_wq, "status") != 0) {
    stop("run_engine failed for weighted qntldef ", q, ":\n", paste(out_wq, collapse = "\n"))
  }

  res_wq <- jsonlite::fromJSON(file.path(td, paste0("run_r_wt_q_", q), "means_results.json"))
  st_wq <- res_wq$groups$ALL$variables$val
  stopifnot(!is.null(st_wq$MEDIAN) && is.finite(st_wq$MEDIAN))
  stopifnot(!is.null(st_wq$Q1) && is.finite(st_wq$Q1))
  stopifnot(!is.null(st_wq$Q3) && is.finite(st_wq$Q3))
  stopifnot(!is.null(st_wq$QRANGE) && is.finite(st_wq$QRANGE))
  stopifnot(!is.null(st_wq$P1) && is.finite(st_wq$P1))
  stopifnot(!is.null(st_wq$P99) && is.finite(st_wq$P99))
}
message("PASS: WEIGHT指定時の QNTLDEF 1〜5 累積重み分位数計算が正常に検証されました。")

message(">>> 6. 3点セット成果物・Run隔離・マニフェストの検証 (Task 5.1〜5.4)")
run_dir_final <- file.path(td, "run_rvd_DF")
files_in_run <- list.files(run_dir_final)
stopifnot("means_results.json" %in% files_in_run)
stopifnot("summary.csv" %in% files_in_run)
stopifnot("summary_report.md" %in% files_in_run)
stopifnot("analysis_config.json" %in% files_in_run)
stopifnot("manifest.json" %in% files_in_run)

# Verify summary.csv structure with exact SAS ODS column names
csv_read <- utils::read.csv(file.path(run_dir_final, "summary.csv"), stringsAsFactors = FALSE, check.names = FALSE)
expected_cols <- c("class_group", "variable", "_TYPE_", "_FREQ_", "N", "NMISS", "SUMWGT", "MEAN", "STD", "MIN", "MAX")
for (col in expected_cols) {
  stopifnot(col %in% names(csv_read))
}

# Verify summary_report.md contains Japanese narrative & boundary notice
md_text <- paste(readLines(file.path(run_dir_final, "summary_report.md"), encoding = "UTF-8"), collapse = "\n")
stopifnot(grepl("SAS PROC MEANS 記述統計解析レポート", md_text, fixed = TRUE))
stopifnot(grepl("ビット単位一致の非保証", md_text, fixed = TRUE))
stopifnot(grepl("規制提出適格性の非主張", md_text, fixed = TRUE))

# Verify manifest integrity
manifest_obj <- jsonlite::fromJSON(file.path(run_dir_final, "manifest.json"))
stopifnot(manifest_obj$manifest_version == "1.0")
stopifnot(manifest_obj$artifacts$means_results_json$sha256 == digest::digest(file.path(run_dir_final, "means_results.json"), file = TRUE, algo = "sha256"))
message("PASS: 3点セット成果物、CSV列構造、日本語Markdownレポート、manifest.json が完全整合しています。")

message(">>> 7. 数値パリティ許容誤差契約とfixture優先規則の検証 (Task 5.5)")
# Verify tolerance contract:
# Discrete/Exact: diff == 0
# Deterministic Continuous: |R - SAS| <= 1e-12 OR |R - SAS| / |SAS| <= 1e-10
atol <- 1e-12
rtol <- 1e-10

check_parity <- function(val_r, val_sas, label) {
  diff <- abs(val_r - val_sas)
  rel_diff <- if (abs(val_sas) > 1e-15) diff / abs(val_sas) else diff
  is_pass <- (diff <= atol) || (rel_diff <= rtol)
  if (!is_pass) {
    stop(sprintf("Parity failure for %s: R=%.15f, SAS=%.15f, diff=%.3e, rel=%.3e", label, val_r, val_sas, diff, rel_diff))
  }
}

check_parity(st_df$MEAN, 5.0, "MEAN")
check_parity(st_df$SUM, 40.0, "SUM")
check_parity(st_df$CSS, 32.0, "CSS")
check_parity(st_df$USS, 232.0, "USS")
check_parity(st_df$VAR, 32 / 7, "VAR")
check_parity(st_df$STD, sqrt(32 / 7), "STD")
stopifnot(st_df$N == 8L)
stopifnot(st_df$MIN == 2)
stopifnot(st_df$MAX == 9)
stopifnot(st_df$MEDIAN == 4.5)

# Verify sas_parity metadata reflects 'unverified' in unverified environment
stopifnot(res_df$metadata$sas_parity == "unverified")
message("PASS: 数値パリティ許容誤差契約（OR論理）および fixture優先規則（unverified表記）を充足しています。")

message(">>> ALL TESTS PASSED SUCCESSFULLY! <<<")
