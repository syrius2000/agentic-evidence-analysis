#!/usr/bin/env Rscript
# tests/statistical_foundations/test_validate_config.R

source("tests/statistical_foundations/validate_config.R")

test_dir <- tempfile("test_val_cfg_")
dir.create(test_dir, recursive = TRUE)
on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

# 基本の有効設定
base_valid <- list(
  schema_version = "3way-foundation-v1",
  input = "tests/fixtures/statistical_foundations/titanic_aggregated_3way.csv",
  vars = c("Class", "Sex", "Survived"),
  freq = "Freq",
  response_var = "Survived",
  output_dir = "output/statistical_foundations",
  run_id = "test_run_valid_01",
  sampling = list(
    unit = "乗客",
    total_n_meaning = "タイタニック号総乗客数",
    independence_assumption = "assumed_independent",
    is_scaled = FALSE
  )
)

write_cfg <- function(obj, name = "cfg.json") {
  p <- file.path(test_dir, name)
  write_json(obj, p, auto_unbox = TRUE, pretty = TRUE)
  p
}

message("--- Test 1: 正常な設定 ---")
p1 <- write_cfg(base_valid, "1_valid.json")
r1 <- validate_config_file(p1, silent = TRUE)
stopifnot(r1$status == "PASS", r1$valid == TRUE)
message("  -> PASS OK")

message("--- Test 2: 未知キーの拒否 ---")
cfg2 <- base_valid
cfg2$unknown_custom_key <- "malicious"
p2 <- write_cfg(cfg2, "2_unknown.json")
r2 <- validate_config_file(p2, silent = TRUE)
stopifnot(r2$status == "ERROR", any(grepl("未知のトップレベルキー", r2$errors)))
message("  -> 未知キー拒否 OK")

message("--- Test 3: 変数数不正（2変数） ---")
cfg3 <- base_valid
cfg3$vars <- c("Class", "Sex")
p3 <- write_cfg(cfg3, "3_two_vars.json")
r3 <- validate_config_file(p3, silent = TRUE)
stopifnot(r3$status == "ERROR", any(grepl("ちょうど3つの異なるカテゴリ変数", r3$errors)))
message("  -> 変数数不正拒否 OK")

message("--- Test 4: response_var が vars 外 ---")
cfg4 <- base_valid
cfg4$response_var <- "Age" # vars にはない
p4 <- write_cfg(cfg4, "4_resp_out.json")
r4 <- validate_config_file(p4, silent = TRUE)
stopifnot(r4$status == "ERROR", any(grepl("response_var 'Age' が vars", r4$errors)))
message("  -> response_var所属チェック OK")

message("--- Test 5: 独立性未解決による HOLD ---")
cfg5 <- base_valid
cfg5$sampling$independence_assumption <- "unverified"
p5 <- write_cfg(cfg5, "5_unverified.json")
r5 <- validate_config_file(p5, silent = TRUE)
stopifnot(r5$status == "HOLD", any(grepl("独立性が未解決", r5$holds)))
message("  -> 独立性未解決HOLD OK")

message("--- Test 6: 構造ゼロ指定による HOLD ---")
cfg6 <- base_valid
cfg6$structural_zeros <- list(list(Class = "Crew", Age = "Child"))
p6 <- write_cfg(cfg6, "6_struct_zero.json")
r6 <- validate_config_file(p6, silent = TRUE)
stopifnot(r6$status == "HOLD", any(grepl("構造的ゼロ", r6$holds)))
message("  -> 構造ゼロ保留 OK")

message("--- Test 7: フィルタで未知演算子（式文字列・不正演算子）拒否 ---")
cfg7 <- base_valid
cfg7$filters <- list(list(column = "Class", op = ">", value = "1st"))
p7 <- write_cfg(cfg7, "7_invalid_op.json")
r7 <- validate_config_file(p7, silent = TRUE)
stopifnot(r7$status == "ERROR", any(grepl("無効です", r7$errors)))
message("  -> 不正演算子拒否 OK")

message("--- Test 8: フィルタで未知列拒否 ---")
cfg8 <- base_valid
cfg8$filters <- list(list(column = "NonExistentCol", op = "==", value = "foo"))
p8 <- write_cfg(cfg8, "8_unknown_col.json")
r8 <- validate_config_file(p8, silent = TRUE)
stopifnot(r8$status == "ERROR", any(grepl("未知列拒否", r8$errors)))
message("  -> 未知列拒否 OK")

message("--- Test 9: フィルタ結果0件で全件切替を拒否 ---")
cfg9 <- base_valid
cfg9$filters <- list(list(column = "Class", op = "==", value = "AlienClass"))
p9 <- write_cfg(cfg9, "9_zero_rows.json")
r9 <- validate_config_file(p9, silent = TRUE)
stopifnot(r9$status == "ERROR", any(grepl("抽出行数が0件です", r9$errors)))
message("  -> フィルタ0件拒否 OK")

message("=== 全テスト成功 ===")
