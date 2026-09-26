# test_logic.R - VCD categorical analysis logic tests (v4.1)
# Run from project root: Rscript .agents/skills/vcd-categorical-analysis/tests/test_logic.R

find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agents", "shared", "run_scope.R"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  getwd()
}
repo_root <- find_agent_repo()
source(file.path(repo_root, ".agents", "shared", "dependency_check.R"))

check_r_dependencies(c("jsonlite", "digest"), context = "vcd-categorical ロジックテスト (test_logic.R)")
suppressPackageStartupMessages(library(jsonlite))

PASS <- 0L
FAIL <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("  [PASS] %s\n", msg))
    PASS <<- PASS + 1L
  } else {
    cat(sprintf("  [FAIL] %s\n", msg))
    FAIL <<- FAIL + 1L
  }
}

script_dir <- file.path(repo_root, ".agents", "skills", "vcd-categorical-analysis")
analysis_path <- file.path(script_dir, "templates", "analysis.R")

if (!file.exists(analysis_path)) {
  stop("[ERROR] analysis.R not found at: ", analysis_path)
}

source(file.path(script_dir, "R", "validate_input.R"))
source(file.path(script_dir, "R", "residual_diagnostics.R"))
source(file.path(script_dir, "R", "effect_evidence_metrics.R"))
source(file.path(script_dir, "R", "dirichlet_posterior.R"))
source(file.path(script_dir, "R", "serializer_v3.R"))

cat("============================================================\n")
cat("vcd-categorical-analysis v4.1 Modular Logic Tests\n")
cat("============================================================\n\n")

# 2x2 テストデータ
df_2x2 <- data.frame(
  Eye = c("Brown", "Brown", "Blue", "Blue"),
  Hair = c("Black", "Blond", "Black", "Blond"),
  Freq = c(68L, 7L, 20L, 94L),
  stringsAsFactors = FALSE
)

# Test 1: validate_input_table 正常動作
cat("[TEST 1] validate_input_table 正常動作\n")
v_agg <- validate_input_table(df_2x2, vars = c("Eye", "Hair"), freq = "Freq", input_mode = "aggregated")
assert(attr(v_agg, "n_total") == 189L, "総度数が 189 に一致")
assert(identical(attr(v_agg, "vars"), c("Eye", "Hair")), "属性 vars が一致")

# Test 2: compute_residual_diagnostics 正常動作
cat("[TEST 2] compute_residual_diagnostics 残差・レバレッジ・Cochran診断\n")
diag_res <- compute_residual_diagnostics(v_agg)
assert(diag_res$global$df == 1L, "2x2 分割表の自由度は 1")
assert(diag_res$global$pearson_chisq > 0, "Pearson カイ二乗統計量が正値")
assert(diag_res$global$expected_count_diagnostics$cochran_satisfied == TRUE, "期待度数が十分で Cochran 条件充足")
assert(length(diag_res$cells) == 4L, "セル数が 4")

# Test 3: compute_effect_evidence_metrics 正常動作
cat("[TEST 3] compute_effect_evidence_metrics Cramér's V & Dual-Filter\n")
evid_res <- compute_effect_evidence_metrics(diag_res)
assert(evid_res$global$cramers_v > 0, "Cramér's V が算出されている")
assert(!is.null(evid_res$global$cramers_v_ci), "Cramér's V 信頼区間が算出されている")
assert(evid_res$n_candidates == 0L, "小標本 (N=189 < 2000) では candidate = 0")

# Test 4: compute_dirichlet_posterior 正常動作 (主解析 alpha = 0.5)
cat("[TEST 4] compute_dirichlet_posterior モンテカルロ事後推論\n")
sig_64 <- "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
input_sha_64 <- "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
config_sha_64 <- "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"

post_res <- compute_dirichlet_posterior(diag_res, alpha = 0.5, n_draws = 2000L, analysis_signature = sig_64)
assert(length(post_res$cell_posteriors) == 4L, "事後推論セル数が 4")
assert(is.null(post_res$practical_delta), "practical_delta は既定で NULL")
assert(is.numeric(post_res$sensitivity_analysis$max_absolute_mean_diff), "事前感度分析の平均差が数値")
assert(post_res$sensitivity_analysis$primary_alpha == 0.5, "主事前 alpha は 0.5")
assert(post_res$sensitivity_analysis$sensitivity_alpha == 1.0, "感度事前 alpha は 1.0")
assert(is.null(post_res$sensitivity_analysis$is_sensitive), "is_sensitive は廃止済みで NULL")

# Test 5: serialize_interface_v3 正常動作 (canonical 実行モード)
cat("[TEST 5] serialize_interface_v3 シリアライザ & Schema不変量\n")
tmp_out <- tempfile("test_ser_")
dir.create(tmp_out, recursive = TRUE)
on.exit(unlink(tmp_out, recursive = TRUE), add = TRUE)

res_v3 <- serialize_interface_v3(
  effect_result = evid_res,
  posterior_result = post_res,
  out_dir = tmp_out,
  run_id = "test_run_001",
  analysis_signature = sig_64,
  input_sha256 = input_sha_64,
  config_sha256 = config_sha_64,
  execution_mode = "canonical"
)
assert(identical(res_v3$interface_version, "3.0"), "interface_version == '3.0'")
assert(file.exists(file.path(tmp_out, "categorical_results.json")), "categorical_results.json が出力された")
assert(file.exists(file.path(tmp_out, "residuals_table.csv")), "residuals_table.csv が出力された")

cat(sprintf("\n==== Test Summary: %d passed, %d failed ====\n", PASS, FAIL))
if (FAIL > 0) quit(status = 1) else quit(status = 0)
