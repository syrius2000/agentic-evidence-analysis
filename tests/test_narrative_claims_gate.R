# =============================================================================
# test_narrative_claims_gate.R
# タスク 4.2 & 4.3: narrative_claims 主張ゲートの正常系・失敗系テスト
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(jsonlite)
  library(digest)
})

script_dir <- file.path(getwd(), ".agents/skills/vcd-bayesian-evidence-analysis/templates")
source(file.path(script_dir, "claims_gate.R"))

# テスト用一時ファイル準備
temp_dir <- tempfile("claims_gate_test_")
dir.create(temp_dir, recursive = TRUE)
on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

mock_results <- list(
  schema_version = "three-way-results-v1",
  input_summary = list(
    total_n = 4526,
    n_cells = 24
  ),
  models = list(
    best_model_id = "M5",
    summary = data.frame(
      model_id = c("M5", "M8"),
      bic = c(332.3119, 339.1982),
      stringsAsFactors = FALSE
    )
  ),
  conditional_rate_view = list(
    status = "VALID",
    rates = list(
      A__Male = list(
        raw_rate = 0.6206,
        post_mean = 0.6204
      ),
      slice_hold = list(
        raw_rate = "HOLD"
      )
    )
  )
)

results_file <- file.path(temp_dir, "evidence_results.json")
write_json(mock_results, results_file, pretty = TRUE, auto_unbox = TRUE)
actual_hash <- digest(file = results_file, algo = "sha256")

test_that("4.2 正常系: 正しいハッシュ・pointer・数値の claims は検証に合格する", {
  valid_claims <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(
      list(pointer = "/input_summary/total_n", value = 4526),
      list(pointer = "/input_summary/n_cells", value = 24),
      list(pointer = "/models/summary/0/bic", value = 332.3119),
      list(pointer = "/models/summary/1/bic", value = 339.1982)
    )
  )
  claims_file <- file.path(temp_dir, "claims_valid.json")
  write_json(valid_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_true(verify_narrative_claims(results_file, claims_file))
})

test_that("4.3 失敗系: 改変ハッシュは拒否される", {
  bad_hash_claims <- list(
    status = "REVIEWED",
    result_sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
    claims = list(list(pointer = "/input_summary/total_n", value = 4526))
  )
  claims_file <- file.path(temp_dir, "claims_bad_hash.json")
  write_json(bad_hash_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_error(verify_narrative_claims(results_file, claims_file), "記録ハッシュと結果JSON実ハッシュが一致しません")
})

test_that("4.3 失敗系: 存在しない pointer は拒否される", {
  bad_pointer_claims <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(list(pointer = "/non_existent/path", value = 123))
  )
  claims_file <- file.path(temp_dir, "claims_bad_pointer.json")
  write_json(bad_pointer_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_error(verify_narrative_claims(results_file, claims_file), "JSON Pointer キーが存在しません")
})

test_that("4.3 失敗系: 数値の不一致（丸め誤差含む乖離）は拒否される", {
  bad_val_claims <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(list(pointer = "/models/summary/0/bic", value = 335.0)) # 332.3119 と不一致
  )
  claims_file <- file.path(temp_dir, "claims_bad_val.json")
  write_json(bad_val_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_error(verify_narrative_claims(results_file, claims_file), "数値が一致しません")
})

test_that("4.3 失敗系: HOLD 対象を参照する主張は拒否される", {
  hold_claims <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(list(pointer = "/conditional_rate_view/rates/slice_hold/raw_rate", value = 0.5))
  )
  claims_file <- file.path(temp_dir, "claims_hold.json")
  write_json(hold_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_error(verify_narrative_claims(results_file, claims_file), "HOLD 状態の値を参照しています")
})

test_that("4.3 失敗系: status が REVIEWED でない場合は拒否される", {
  unreviewed_claims <- list(
    status = "DRAFT",
    result_sha256 = actual_hash,
    claims = list(list(pointer = "/input_summary/total_n", value = 4526))
  )
  claims_file <- file.path(temp_dir, "claims_unreviewed.json")
  write_json(unreviewed_claims, claims_file, pretty = TRUE, auto_unbox = TRUE)

  expect_error(verify_narrative_claims(results_file, claims_file), "レビュー状態が 'REVIEWED' ではありません")
})

test_that("4.4 F-001回帰検証: 生割合(raw_rate)と事後平均(post_mean)のポインタと数値の混同を厳密に検知・拒否する", {
  # 正常系: raw_rate と post_mean の両方が正しく照合される
  valid_rate_claims <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(
      list(pointer = "/conditional_rate_view/rates/A__Male/raw_rate", value = 0.6206),
      list(pointer = "/conditional_rate_view/rates/A__Male/post_mean", value = 0.6204)
    )
  )
  claims_file_valid <- file.path(temp_dir, "claims_rate_valid.json")
  write_json(valid_rate_claims, claims_file_valid, pretty = TRUE, auto_unbox = TRUE)
  expect_true(verify_narrative_claims(results_file, claims_file_valid))

  # 異常系: raw_rate のポインタに post_mean の値(0.6204)を指定した場合は拒否される
  confused_claims_1 <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(
      list(pointer = "/conditional_rate_view/rates/A__Male/raw_rate", value = 0.6204)
    )
  )
  claims_file_confused_1 <- file.path(temp_dir, "claims_rate_confused_1.json")
  write_json(confused_claims_1, claims_file_confused_1, pretty = TRUE, auto_unbox = TRUE)
  expect_error(verify_narrative_claims(results_file, claims_file_confused_1), "数値が一致しません")

  # 異常系: post_mean のポインタに raw_rate の値(0.6206)を指定した場合は拒否される
  confused_claims_2 <- list(
    status = "REVIEWED",
    result_sha256 = actual_hash,
    claims = list(
      list(pointer = "/conditional_rate_view/rates/A__Male/post_mean", value = 0.6206)
    )
  )
  claims_file_confused_2 <- file.path(temp_dir, "claims_rate_confused_2.json")
  write_json(confused_claims_2, claims_file_confused_2, pretty = TRUE, auto_unbox = TRUE)
  expect_error(verify_narrative_claims(results_file, claims_file_confused_2), "数値が一致しません")
})

cat("[SUCCESS] test_narrative_claims_gate.R passed all tests.\n")
