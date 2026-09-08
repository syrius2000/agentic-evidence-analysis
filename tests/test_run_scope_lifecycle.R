# tests/test_run_scope_lifecycle.R
# 共有共通基盤 (run_scope.R, finalize_run_stage.R) およびライフサイクル統合テスト

Sys.unsetenv("AGENTIC_MOCK_RENDER")
source(".agents/shared/run_scope.R")
# 単体fixtureでも実Pass 1と同じくmanifest保存後に状態・期待ハッシュを記録する。
write_manifest_impl <- write_results_manifest
write_results_manifest <- function(run_output_dir, skill, artifacts) {
  result <- write_manifest_impl(run_output_dir, skill, artifacts)
  path <- file.path(run_output_dir, "run_meta.json")
  if (file.exists(path)) {
    meta <- jsonlite::read_json(path)
    meta$results_manifest_sha256 <- result$manifest_sha256
    meta$pass_status$pass1 <- "completed"
    atomic_run_json(meta, path)
  }
  result
}

test_assert <- function(condition, msg) {
  if (!isTRUE(condition)) {
    stop("[TEST ASSERTION FAILED] ", msg)
  }
  cat("[PASS] ", msg, "\n")
}

test_expect_error <- function(expr, expected_pattern = NULL, msg = "Expected error") {
  err_caught <- FALSE
  actual_err <- ""
  tryCatch({
    expr
  }, error = function(e) {
    err_caught <<- TRUE
    actual_err <<- e$message
  })
  if (!err_caught) {
    stop("[TEST ASSERTION FAILED] ", msg, " (エラーが発生しませんでした)")
  }
  if (!is.null(expected_pattern) && !grepl(expected_pattern, actual_err, fixed = FALSE)) {
    stop("[TEST ASSERTION FAILED] ", msg, " (エラーメッセージ '", actual_err, "' がパターン '", expected_pattern, "' と一致しません)")
  }
  cat("[PASS] ", msg, " (捕捉: ", substr(actual_err, 1, 60), "...)\n")
}

# --- テスト実行 ---
cat("=== Phase 1: Shared Engine Lifecycle Tests ===\n")

temp_base <- normalizePath(tempfile("test_run_scope_"), winslash = "/", mustWork = FALSE)
dir.create(temp_base, recursive = TRUE)
temp_base <- normalizePath(temp_base, winslash = "/", mustWork = TRUE)
on.exit(unlink(temp_base, recursive = TRUE), add = TRUE)

# 1.1: assert_valid_out_root
cat("\n--- Test 1.1: assert_valid_out_root ---\n")
valid_root <- file.path(temp_base, "case_01", "vcd_bayesian")
test_assert(identical(assert_valid_out_root(valid_root), normalizePath(valid_root, winslash = "/", mustWork = FALSE)), "有効な親ディレクトリの受け入れ")

# run_* 形式の誤指定拒絶
test_expect_error(
  assert_valid_out_root(file.path(temp_base, "case_01", "run_20260908_120000")),
  expected_pattern = "既存または予約形式の run ディレクトリです",
  msg = "run_* 形式パスの拒絶"
)

# runs 階層の誤指定拒絶
test_expect_error(
  assert_valid_out_root(file.path(temp_base, "case_01", "runs")),
  expected_pattern = "既存または予約形式の run ディレクトリです",
  msg = "runs ディレクトリパスの拒絶"
)

# 成果物直下の誤指定拒絶
art_dir <- file.path(temp_base, "fake_run_dir")
dir.create(art_dir, recursive = TRUE)
writeLines("{}", file.path(art_dir, "run_meta.json"))
test_expect_error(
  assert_valid_out_root(art_dir),
  expected_pattern = "既存または予約形式の run ディレクトリです",
  msg = "run_meta.json 存在ディレクトリの拒絶"
)

# 1.2: reserve_run_output_dir 秒単位衝突解決
cat("\n--- Test 1.2: reserve_run_output_dir 秒単位衝突解決 ---\n")
fixed_out_root <- file.path(temp_base, "test_out_root")
dir.create(fixed_out_root, recursive = TRUE)
# 同一 run_id での連続予約
run_dir1 <- reserve_run_output_dir(fixed_out_root, "vcd-bayesian-evidence-analysis", run_id = "test_run_id_collision")
run_dir2 <- reserve_run_output_dir(fixed_out_root, "vcd-bayesian-evidence-analysis", run_id = "test_run_id_collision")
run_dir3 <- reserve_run_output_dir(fixed_out_root, "vcd-bayesian-evidence-analysis", run_id = "test_run_id_collision")

test_assert(dir.exists(run_dir1) && dir.exists(run_dir2) && dir.exists(run_dir3), "すべての予約ディレクトリが存在")
test_assert(grepl("_2$", basename(run_dir2)), "2回目の予約に _2 サフィックスが付与される")
test_assert(grepl("_3$", basename(run_dir3)), "3回目の予約に _3 サフィックスが付与される")
test_assert(length(unique(c(run_dir1, run_dir2, run_dir3))) == 3L, "すべての予約パスが相互に異なる")

# Questionnaire での runs/<id> 構造検証
q_run_dir <- reserve_run_output_dir(fixed_out_root, "questionnaire-batch-analysis", run_id = "q_test")
test_assert(identical(basename(dirname(q_run_dir)), "runs"), "Questionnaire の予約先親が runs")

# 1.3: assert_path_within_run_dir 厳格パストラバーサルガード
cat("\n--- Test 1.3: assert_path_within_run_dir 厳格パストラバーサルガード ---\n")
test_run <- file.path(temp_base, "sample_run")
dir.create(test_run, recursive = TRUE)

# 正常系
test_assert(identical(assert_path_within_run_dir("data.csv", test_run), normalizePath(file.path(test_run, "data.csv"), winslash = "/", mustWork = FALSE)), "run 直下ファイル")
test_assert(identical(assert_path_within_run_dir("sub/dir/fig.png", test_run), normalizePath(file.path(test_run, "sub/dir/fig.png"), winslash = "/", mustWork = FALSE)), "サブディレクトリ配下ファイル")

# prefix 衝突攻撃の拒絶 (run_abc vs run_abc_external)
external_run <- file.path(temp_base, paste0(basename(test_run), "_external"))
dir.create(external_run, recursive = TRUE)
test_expect_error(
  assert_path_within_run_dir(file.path(external_run, "file.txt"), test_run),
  expected_pattern = "パストラバーサル",
  msg = "prefix 衝突攻撃の拒絶"
)

# ../ による親への逸脱
test_expect_error(
  assert_path_within_run_dir("../../secret.txt", test_run),
  expected_pattern = "パストラバーサル",
  msg = "相対パストラバーサルの拒絶"
)

# 1.4: 設定スナップショット保存と推測なし外部データ保護
cat("\n--- Test 1.4: save_config_snapshot と inputs ---\n")
cfg_file <- file.path(temp_base, "dummy_config.json")
writeLines('{"alpha": 0.05, "model": "independence"}', cfg_file)
cfg_snap <- save_config_snapshot(test_run, cfg_file, config_origin = "pass0_file", config_source_path = cfg_file)

test_assert(file.exists(file.path(test_run, "analysis_config.json")), "analysis_config.json が保存される")
test_assert(identical(cfg_snap$config_sha256, sha256_file(cfg_file)), "config_sha256 が一致")

# inputs 配列と読み取りアダプター
meta_init <- write_run_meta(
  out_root = temp_base,
  run_output_dir = test_run,
  skill = "vcd-bayesian-evidence-analysis",
  run_id = "test_run_id_001",
  input_data_path = cfg_file,
  extra = list(
    config_snapshot = cfg_snap$config_snapshot,
    config_sha256 = cfg_snap$config_sha256
  )
)
test_assert(identical(get_run_input_data(meta_init), normalizePath(cfg_file, winslash = "/", mustWork = TRUE)), "get_run_input_data で source_path を取得")
test_assert(identical(get_run_input_sha256(meta_init), sha256_file(cfg_file)), "get_run_input_sha256 で sha256 を取得")
test_assert(identical(meta_init$inputs[[1L]]$snapshot_policy, "hash_only"), "外部データの snapshot_policy が hash_only")

# 1.5: write_results_manifest と verify_results_manifest
cat("\n--- Test 1.5: results_manifest 出力・検証 ---\n")
# 成果物作成
writeLines('{"res": 1}', file.path(test_run, "evidence_results.json"))
h_ev <- sha256_file(file.path(test_run, "evidence_results.json"))

artifacts <- list(
  list(path = "evidence_results.json", role = "primary_results", sha256 = h_ev)
)

m_out <- write_results_manifest(test_run, "vcd-bayesian-evidence-analysis", artifacts)
test_assert(file.exists(m_out$manifest_path), "results_manifest.json が出力される")
test_assert(nzchar(m_out$manifest_sha256), "実ファイルバイト列 sha256 が計算される")

# 検証関数
v_ok <- verify_results_manifest(test_run, expected_sha256 = m_out$manifest_sha256)
test_assert(isTRUE(v_ok$valid), "マニフェスト検証成功")

# 不正な role の拒絶
test_expect_error(
  validate_manifest_entries(test_run, "vcd-bayesian-evidence-analysis", list(
    list(path = "evidence_results.json", role = "invalid_role", sha256 = h_ev)
  )),
  expected_pattern = "allowlist外です",
  msg = "不正な role の拒絶"
)

# 重複 path の拒絶
test_expect_error(
  validate_manifest_entries(test_run, "vcd-bayesian-evidence-analysis", list(
    list(path = "evidence_results.json", role = "primary_results", sha256 = h_ev),
    list(path = "evidence_results.json", role = "canonical_result", sha256 = h_ev)
  )),
  expected_pattern = "path が重複しています",
  msg = "重複 path の拒絶"
)

# 1.6: 信頼境界検証付き run 外排他ロック
cat("\n--- Test 1.6: 信頼境界検証付き run 外排他ロック ---\n")
# 正常ロック取得・解放
lock1 <- acquire_stage_lock(test_run, "pass2")
test_assert(dir.exists(lock1$lock_dir), "ロックディレクトリが作成される")
test_assert(!grepl(normalizePath(test_run, winslash = "/"), lock1$lock_dir, fixed = TRUE), "ロックは run ディレクトリの外に配置される")

# 同時取得の拒絶
test_expect_error(
  acquire_stage_lock(test_run, "pass2"),
  expected_pattern = "排他ロックが既に保持されています",
  msg = "同 stage ロックの二重取得拒絶"
)

# ロック解放
release_stage_lock(lock1)
test_assert(!dir.exists(lock1$lock_dir), "ロック解放後にロックディレクトリが削除される")

# 改ざん out_root による外部ディレクトリ作成阻止テスト
tampered_run <- file.path(temp_base, "tampered_run")
dir.create(tampered_run, recursive = TRUE)
tampered_meta <- list(
  interface_version = "2.0",
  skill = "vcd-bayesian-evidence-analysis",
  run_output_dir = normalizePath(tampered_run, winslash = "/"),
  run_state = "active", pass_status = list(pass1 = "completed", pass2 = "pending", pass3 = "pending"),
  out_root = "/tmp/unrelated_malicious_directory"
)
jsonlite::write_json(tampered_meta, file.path(tampered_run, "run_meta.json"), auto_unbox = TRUE)

test_expect_error(
  acquire_stage_lock(tampered_run, "pass2"),
  expected_pattern = "信頼境界違反",
  msg = "改ざん out_root による外部ロック作成の阻止"
)
test_assert(!dir.exists("/tmp/unrelated_malicious_directory/.run_locks"), "改ざん先外部ディレクトリは作成されない")

# 1.7 & 1.9: staging promotion と finalize_pass2
cat("\n--- Test 1.7 & 1.9: staging promotion と finalize_pass2 ---\n")
# staging 領域作成とドラフト配置
stg_dir <- get_run_staging_dir(test_run)
writeLines("# Expert Narrative Draft", file.path(stg_dir, "executive_summary.md"))

# finalize_pass2 実行
fin2 <- finalize_pass2(
  run_dir = test_run,
  target_name = "executive_summary.md",
  source_staging_path = file.path(stg_dir, "executive_summary.md"),
  expected_results_manifest_sha256 = m_out$manifest_sha256
)
test_assert(file.exists(file.path(test_run, "executive_summary.md")), "executive_summary.md が run 直下に promotion される")
test_assert(!file.exists(file.path(stg_dir, "executive_summary.md")), "promotion 後に staging 内の元ファイルが削除される")

# run_meta 更新確認
m_updated <- jsonlite::fromJSON(file.path(test_run, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(m_updated$pass_status$pass2, "completed"), "pass2 が completed に更新される")
test_assert(identical(m_updated$artifacts$narrative$based_on_results_manifest_sha256, m_out$manifest_sha256), "マニフェストハッシュが記録される")

# 1.8: preview 一回限り生成制御
cat("\n--- Test 1.8: preview 一回限り生成制御 ---\n")
assert_preview_can_generate(test_run, "executive_summary_preview.md")
writeLines("preview content", file.path(test_run, "executive_summary_preview.md"))
test_expect_error(
  assert_preview_can_generate(test_run, "executive_summary_preview.md"),
  expected_pattern = "既に生成済みです",
  msg = "同一 preview の上書き拒絶"
)

# 1.10: finalize_pass3 と sealed 封印
cat("\n--- Test 1.10: finalize_pass3 と sealed 封印 ---\n")
stg_dir <- get_run_staging_dir(test_run)
writeLines("<html>Dashboard</html>", file.path(stg_dir, "dashboard.html"))

# staging に未処理の余計なファイルがある場合の sealed 前空検証
writeLines("garbage", file.path(stg_dir, "unrelated_junk.txt"))
test_expect_error(
  finalize_pass3(
    run_dir = test_run,
    target_name = "dashboard.html",
    source_staging_path = file.path(stg_dir, "dashboard.html"),
    expected_results_manifest_sha256 = m_out$manifest_sha256
  ),
  expected_pattern = "staging 領域が空ではありません",
  msg = "staging にゴミが残っている場合の封印拒絶"
)
unlink(file.path(stg_dir, "unrelated_junk.txt"))

# 正常 finalize_pass3
fin3 <- finalize_pass3(
  run_dir = test_run,
  target_name = "dashboard.html",
  source_staging_path = file.path(stg_dir, "dashboard.html"),
  expected_results_manifest_sha256 = m_out$manifest_sha256
)
test_assert(identical(fin3$run_state, "sealed"), "run_state が sealed になる")

m_sealed <- jsonlite::fromJSON(file.path(test_run, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(m_sealed$run_state, "sealed"), "run_meta の run_state が sealed")
test_assert(identical(m_sealed$pass_status$pass3, "completed"), "pass3 が completed")

# sealed 後の変更・再確定・staging 作成拒絶
test_expect_error(
  get_run_staging_dir(test_run),
  expected_pattern = "sealed 状態の run に対して staging を作成・変更することはできません",
  msg = "sealed 後 staging 作成拒絶"
)
test_expect_error(
  finalize_pass2(test_run),
  expected_pattern = "sealed",
  msg = "sealed 後 Pass 2 確定拒絶"
)

# 1.11: finalize_run_stage.R CLI ラッパー
cat("\n--- Test 1.11: finalize_run_stage.R CLI ラッパー ---\n")
# 新しい未確定 run を作成
test_run_cli <- file.path(temp_base, "run_cli_test")
dir.create(test_run_cli, recursive = TRUE)
write_run_meta(temp_base, test_run_cli, "vcd-bayesian-evidence-analysis", "cli_test_id")
writeLines('{"res": 1}', file.path(test_run_cli, "evidence_results.json"))
m_cli <- write_results_manifest(test_run_cli, "vcd-bayesian-evidence-analysis", list(
  list(path = "evidence_results.json", role = "primary_results", sha256 = sha256_file(file.path(test_run_cli, "evidence_results.json")))
))

stg_cli <- get_run_staging_dir(test_run_cli)
writeLines("Narrative CLI", file.path(stg_cli, "executive_summary.md"))

# allowlist 違反テスト: target-name に不正なパス
res_bad_target <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", test_run_cli,
  "--source-artifact", file.path(stg_cli, "executive_summary.md"),
  "--target-name", "evil_summary.md",
  "--expected-results-manifest-sha256", m_cli$manifest_sha256
), stdout = FALSE, stderr = FALSE)
test_assert(res_bad_target != 0L, "allowlist 外 target-name の CLI エラー終了")

# allowlist 違反テスト: staging 外のファイルを source に指定
external_source <- file.path(temp_base, "external_draft.md")
writeLines("External draft", external_source)
res_bad_src <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", test_run_cli,
  "--source-artifact", external_source,
  "--target-name", "executive_summary.md",
  "--expected-results-manifest-sha256", m_cli$manifest_sha256
), stdout = FALSE, stderr = FALSE)
test_assert(res_bad_src != 0L, "staging 外 source-artifact の CLI エラー終了")

# 正常確定
res_ok <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", test_run_cli,
  "--source-artifact", file.path(stg_cli, "executive_summary.md"),
  "--target-name", "executive_summary.md",
  "--expected-results-manifest-sha256", m_cli$manifest_sha256
), stdout = FALSE, stderr = FALSE)
test_assert(res_ok == 0L, "CLI ラッパーでの正常 Pass 2 確定 (終了コード 0)")

# 1.12: legacy run (v1.0) 読み取り限定と本番確定拒絶
cat("\n--- Test 1.12: legacy run (v1.0) 読み取り限定 ---\n")
legacy_run <- file.path(temp_base, "run_legacy_v1")
dir.create(legacy_run, recursive = TRUE)
writeLines('{"interface_version": "1.0", "skill": "vcd-bayesian-evidence-analysis"}', file.path(legacy_run, "run_meta.json"))

# legacy run 本番確定拒絶
test_expect_error(
  finalize_pass2(legacy_run),
  expected_pattern = "legacy",
  msg = "legacy run の本番 Pass 2 確定拒絶"
)
test_expect_error(
  finalize_pass3(legacy_run),
  expected_pattern = "legacy",
  msg = "legacy run の本番 Pass 3 確定拒絶"
)

# 1.13: verify_superseded_run
cat("\n--- Test 1.13: verify_superseded_run ---\n")
# 自己参照拒絶
test_expect_error(
  verify_superseded_run(test_run, "vcd-bayesian-evidence-analysis", current_run_dir = test_run),
  expected_pattern = "自己自身を supersede 元に指定することはできません",
  msg = "自己参照 supersede の拒絶"
)

# skill 不一致拒絶
test_expect_error(
  verify_superseded_run(test_run, "questionnaire-batch-analysis"),
  expected_pattern = "skill .* が現在の skill .* と一致しません",
  msg = "skill 不一致 supersede の拒絶"
)

# 正常検証
sup_ok <- verify_superseded_run(test_run, "vcd-bayesian-evidence-analysis")
test_assert(identical(sup_ok$superseded_results_manifest_sha256, m_out$manifest_sha256), "supersede 元のマニフェストハッシュ取得")

# 1.14: write_run_handover
cat("\n--- Test 1.14: write_run_handover ---\n")
ho <- write_run_handover(test_run_cli, "vcd-bayesian-evidence-analysis", m_cli$manifest_sha256)
ho_file <- file.path(test_run_cli, "run_handover.json")
test_assert(file.exists(ho_file), "run_handover.json が出力される")
test_assert(!is.null(ho$next_actions$pass2_ai$finalize$argv), "next_actions に finalize コマンドが含まれる")

# 1.15: resolve_pass3_run_dir 改定
cat("\n--- Test 1.15: resolve_pass3_run_dir 改定 ---\n")
# 暗黙探索の廃止 (親を直接渡した場合エラー)
test_expect_error(
  resolve_pass3_run_dir(temp_base, "evidence_results.json"),
  expected_pattern = "暗黙の mtime 自動選択は廃止されました",
  msg = "暗黙 mtime 探索の廃止エラー"
)

# 直接指定
res_dir <- resolve_pass3_run_dir(test_run, "evidence_results.json")
test_assert(identical(res_dir$resolved_from, "direct"), "直接指定による解決")

cat("\n=== ALL Phase 1 Tests PASSED successfully! ===\n")

# =============================================================================
# === Phase 2: Bayesian Evidence Pipeline Tests ===
# =============================================================================
cat("\n=== Phase 2: Bayesian Evidence Pipeline Tests ===\n")

b_out_root <- file.path(temp_base, "bayesian_pipeline_test")
dir.create(b_out_root, recursive = TRUE)

# 2.1: analysis.R (Pass 1) の実行
cat("\n--- Test 2.1: analysis.R (Pass 1) 実行と成果物検証 ---\n")
res_pass1 <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R",
  "--output-dir", b_out_root,
  "--run-id", "b_test_01"
), stdout = FALSE, stderr = FALSE)
test_assert(res_pass1 == 0L, "analysis.R (Pass 1) 正常終了")

b_run_dir <- file.path(b_out_root, "run_b_test_01")
test_assert(dir.exists(b_run_dir), "run ディレクトリが存在")
test_assert(file.exists(file.path(b_run_dir, "evidence_results.json")), "evidence_results.json が存在")
test_assert(file.exists(file.path(b_run_dir, "results_manifest.json")), "results_manifest.json が存在")
test_assert(file.exists(file.path(b_run_dir, "run_handover.json")), "run_handover.json が存在")
test_assert(file.exists(file.path(b_run_dir, "analysis_config.json")), "analysis_config.json スナップショットが存在")

# マニフェスト検証
v_b_man <- verify_results_manifest(b_run_dir)
test_assert(isTRUE(v_b_man$valid), "Pass 1 生成 results_manifest.json の完全性検証合格")

# supersedes-run オプションのテスト
res_sup <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R",
  "--output-dir", b_out_root,
  "--run-id", "b_test_02",
  "--supersedes-run", b_run_dir,
  "--supersede-reason", "Re-computation_test"
), stdout = FALSE, stderr = FALSE)
test_assert(res_sup == 0L, "analysis.R with --supersedes-run 正常終了")
b_run_dir2 <- file.path(b_out_root, "run_b_test_02")
meta2 <- jsonlite::fromJSON(file.path(b_run_dir2, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(normalizePath(meta2$supersedes_run, winslash = "/"), normalizePath(b_run_dir, winslash = "/")), "supersedes_run が記録される")

# 2.2: pass2_stub.R (Pass 2 スタブプレビュー)
cat("\n--- Test 2.2: pass2_stub.R 実行とプレビュー上書き防止 ---\n")
res_stub <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R",
  "--run-dir", b_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_stub == 0L, "pass2_stub.R 正常終了")
test_assert(file.exists(file.path(b_run_dir, "executive_summary_preview.md")), "executive_summary_preview.md が生成される")

meta_stub <- jsonlite::fromJSON(file.path(b_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_stub$pass_status$pass2, "stub_generated"), "pass2 が stub_generated に更新される")

# 同一 preview の上書き拒絶
res_stub_repeat <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/pass2_stub.R",
  "--run-dir", b_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_stub_repeat != 0L, "同一 run での pass2_stub 再実行（上書き）は拒絶される")

# 2.3 & 2.4: render_dashboard.R --preview
cat("\n--- Test 2.3 & 2.4: render_dashboard.R --preview ---\n")
res_preview_dash <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
  "--run-dir", b_run_dir,
  "--preview"
), stdout = FALSE, stderr = FALSE)
test_assert(res_preview_dash == 0L, "render_dashboard.R --preview 正常終了")
preview_html <- file.path(b_run_dir, "dashboard_preview.html")
test_assert(file.exists(preview_html), "dashboard_preview.html が生成される")

# 未封印の確認
meta_prev <- jsonlite::fromJSON(file.path(b_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_prev$run_state, "active"), "プレビュー後も run_state は active (未封印) を維持")

# プレビュー再実行（上書き）拒絶
res_prev_repeat <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
  "--run-dir", b_run_dir,
  "--preview"
), stdout = FALSE, stderr = FALSE)
test_assert(res_prev_repeat != 0L, "同一 run での dashboard_preview 再実行（上書き）は拒絶される")

# 本番モードでの stub_generated 拒絶テスト
cat("\n--- Test: 本番モードでの stub_generated 拒絶 ---\n")
res_prod_fail <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
  "--run-dir", b_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_prod_fail != 0L, "Pass 2 が stub_generated の状態での本番 dashboard.html 生成は拒絶される")

# Pass 2 本番確定 (finalize_run_stage.R 経由)
cat("\n--- Test: Pass 2 本番 AI 考察の確定 ---\n")
stg_b <- get_run_staging_dir(b_run_dir)
writeLines("# Expert Final Narrative\nDetailed statistical evidence.", file.path(stg_b, "executive_summary.md"))

res_fin_p2 <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", b_run_dir,
  "--source-artifact", file.path(stg_b, "executive_summary.md"),
  "--target-name", "executive_summary.md",
  "--expected-results-manifest-sha256", meta_prev$results_manifest_sha256
), stdout = FALSE, stderr = FALSE)
test_assert(res_fin_p2 == 0L, "Pass 2 本番確定 正常終了")
test_assert(file.exists(file.path(b_run_dir, "executive_summary.md")), "executive_summary.md が確定配置される")

# 本番 Pass 3 レンダリングと sealed 封印
cat("\n--- Test: 本番 Pass 3 レンダリングと sealed 封印 ---\n")
res_prod_dash <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
  "--run-dir", b_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_prod_dash == 0L, "本番 render_dashboard.R 正常終了")

prod_html <- file.path(b_run_dir, "dashboard.html")
test_assert(file.exists(prod_html), "dashboard.html が生成される")

meta_final <- jsonlite::fromJSON(file.path(b_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_final$run_state, "sealed"), "本番ダッシュボード確定後に run_state が sealed に封印される")
test_assert(identical(meta_final$pass_status$pass3, "completed"), "pass3 が completed になる")

# sealed 後の変更・再実行拒絶
res_sealed_reject <- system2("Rscript", c(
  ".agents/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R",
  "--run-dir", b_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_sealed_reject != 0L, "sealed 後のダッシュボード再レンダリングは拒絶される")

cat("\n=== ALL Phase 2 Tests PASSED successfully! ===\n")

# =============================================================================
# === Phase 3: Categorical Analysis Pipeline Tests ===
# =============================================================================
cat("\n=== Phase 3: Categorical Analysis Pipeline Tests ===\n")

c_out_root <- file.path(temp_base, "categorical_pipeline_test")
dir.create(c_out_root, recursive = TRUE)

# 3.1: Pass 0 Profile Mode (正式 run 非作成)
cat("\n--- Test 3.1: Pass 0 Profile Mode (正式 run 非作成) ---\n")
c_prof_dir <- file.path(c_out_root, "profile_workspace")
dir.create(c_prof_dir, recursive = TRUE)
res_c_prof <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/analysis.R",
  "--profile",
  "--out", c_prof_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_prof == 0L, "Categorical Pass 0 profile 正常終了")
test_assert(file.exists(file.path(c_prof_dir, "data_profile.json")), "data_profile.json が生成される")
test_assert(length(grep("^run_", list.dirs(c_prof_dir, recursive = FALSE, full.names = FALSE))) == 0L, "正式 run は作成されない")

# 3.2: Pass 1 Render Mode (正式 run 予約・作成と成果物検証)
cat("\n--- Test 3.2: Pass 1 Render Mode (成果物とマニフェスト検証) ---\n")
res_c_pass1 <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/analysis.R",
  "--render",
  "--out", c_out_root,
  "--run-id", "cat_test_01"
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_pass1 == 0L, "Categorical analysis.R (Pass 1) 正常終了")

c_run_dir <- file.path(c_out_root, "run_cat_test_01")
test_assert(dir.exists(c_run_dir), "Categorical run ディレクトリが存在")
test_assert(file.exists(file.path(c_run_dir, "categorical_results.json")), "categorical_results.json が存在")
test_assert(file.exists(file.path(c_run_dir, "data_profile_post.json")), "data_profile_post.json が存在")
test_assert(file.exists(file.path(c_run_dir, "results_manifest.json")), "results_manifest.json が存在")
test_assert(file.exists(file.path(c_run_dir, "run_handover.json")), "run_handover.json が存在")
test_assert(file.exists(file.path(c_run_dir, "analysis_config.json")), "analysis_config.json が存在")

v_c_man <- verify_results_manifest(c_run_dir)
test_assert(isTRUE(v_c_man$valid), "Categorical results_manifest.json 完全性検証合格")

# 3.3: render_dashboard.R --preview (プレビューと未封印確認)
cat("\n--- Test 3.3: render_dashboard.R --preview (プレビュー検証) ---\n")
res_c_preview <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
  "--run-dir", c_run_dir,
  "--preview"
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_preview == 0L, "Categorical render_dashboard.R --preview 正常終了")
test_assert(file.exists(file.path(c_run_dir, "dashboard_preview.html")), "dashboard_preview.html が生成される")

meta_c_prev <- jsonlite::fromJSON(file.path(c_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_c_prev$run_state, "active"), "プレビュー後も run_state は active (未封印) を維持")

# プレビューの上書き拒絶
res_c_prev_dup <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
  "--run-dir", c_run_dir,
  "--preview"
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_prev_dup != 0L, "同一 run での dashboard_preview 再実行（上書き）は拒絶される")

# Pass 2 未確定での本番生成拒絶
cat("\n--- Test: Pass 2 未確定での本番ダッシュボード生成拒絶 ---\n")
res_c_prod_reject <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
  "--run-dir", c_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_prod_reject != 0L, "Pass 2 未確定での本番 dashboard.html 生成は拒絶される")

# Pass 2 本番 AI 考察確定
cat("\n--- Test: Categorical Pass 2 本番確定 ---\n")
stg_c <- get_run_staging_dir(c_run_dir)
writeLines("# Categorical Executive Summary\n\nAI findings confirmed.", file.path(stg_c, "executive_summary.md"))

res_c_fin_p2 <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", c_run_dir,
  "--source-artifact", file.path(stg_c, "executive_summary.md"),
  "--target-name", "executive_summary.md",
  "--expected-results-manifest-sha256", meta_c_prev$results_manifest_sha256
), stdout = TRUE, stderr = TRUE)
status_p2 <- attr(res_c_fin_p2, "status")
if (is.null(status_p2)) status_p2 <- 0L
if (status_p2 != 0L) {
  cat("Categorical Pass 2 finalize failed with output:\n", paste(res_c_fin_p2, collapse = "\n"), "\n")
}
test_assert(status_p2 == 0L, "Categorical Pass 2 本番確定 正常終了")
test_assert(file.exists(file.path(c_run_dir, "executive_summary.md")), "executive_summary.md が確定配置される")

# Pass 3 本番レンダリングと sealed 封印
cat("\n--- Test: Categorical Pass 3 本番レンダリングと sealed 封印 ---\n")
res_c_prod_dash <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
  "--run-dir", c_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_prod_dash == 0L, "Categorical 本番 render_dashboard.R 正常終了")

prod_c_html <- file.path(c_run_dir, "dashboard.html")
test_assert(file.exists(prod_c_html), "dashboard.html が生成される")

meta_c_final <- jsonlite::fromJSON(file.path(c_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_c_final$run_state, "sealed"), "Categorical 本番確定後に run_state が sealed に封印される")
test_assert(identical(meta_c_final$pass_status$pass3, "completed"), "pass3 が completed になる")

# sealed 後の再実行拒絶
res_c_sealed_reject <- system2("Rscript", c(
  ".agents/skills/vcd-categorical-analysis/templates/render_dashboard.R",
  "--run-dir", c_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_c_sealed_reject != 0L, "sealed 後のダッシュボード再レンダリングは拒絶される")

cat("\n=== ALL Phase 3 Tests PASSED successfully! ===\n")

# =============================================================================
# === Phase 4: Questionnaire Batch Analysis Pipeline Tests ===
# =============================================================================
cat("\n=== Phase 4: Questionnaire Batch Analysis Pipeline Tests ===\n")

q_out_root <- file.path(temp_base, "questionnaire_pipeline_test")
dir.create(q_out_root, recursive = TRUE)

survey_data <- "tests/sample_survey.csv"
q_cfg_test <- "tests/question_config_test.csv"

# 4.1: 全成功時の completed 遷移と成果物検証
cat("\n--- Test 4.1: Questionnaire batch 全成功 (completed) ---\n")
res_q_pass1 <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/batch_runner.R",
  "--data", survey_data,
  "--question-config", q_cfg_test,
  "--out", q_out_root,
  "--run-id", "q_test_01"
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_pass1 == 0L, "batch_runner.R 全成功実行 正常終了")

q_run_dir <- file.path(q_out_root, "runs", "q_test_01")
test_assert(dir.exists(q_run_dir), "runs/q_test_01 に隔離作成される")
test_assert(file.exists(file.path(q_run_dir, "summary.csv")), "summary.csv が存在")
test_assert(file.exists(file.path(q_run_dir, "results_manifest.json")), "results_manifest.json が存在")
test_assert(file.exists(file.path(q_run_dir, "run_handover.json")), "run_handover.json が存在")
test_assert(file.exists(file.path(q_run_dir, "analysis_config.json")), "analysis_config.json が存在")

v_q_man <- verify_results_manifest(q_run_dir)
test_assert(isTRUE(v_q_man$valid), "results_manifest.json 完全性検証合格")

meta_q1 <- jsonlite::fromJSON(file.path(q_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_q1$run_state, "active"), "run_state は active")
test_assert(identical(meta_q1$pass_status$pass1, "completed"), "pass1 は completed")

# 4.2: 一部失敗時の partial 遷移と診断成果物保持
cat("\n--- Test 4.2: Questionnaire batch 一部失敗 (partial) ---\n")
# 1設問だけ不正なカラム名を持つ config を作成
cfg_part_df <- utils::read.csv(q_cfg_test, stringsAsFactors = FALSE)
cfg_part_df$var2[2] <- "non_existent_column_for_failure"
q_cfg_part <- file.path(temp_base, "q_config_partial.csv")
utils::write.csv(cfg_part_df, q_cfg_part, row.names = FALSE)

res_q_part <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/batch_runner.R",
  "--data", survey_data,
  "--question-config", q_cfg_part,
  "--out", q_out_root,
  "--run-id", "q_test_partial"
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_part != 0L, "一部失敗は診断成果物を出力して非ゼロ終了")

q_part_dir <- file.path(q_out_root, "runs", "q_test_partial")
test_assert(dir.exists(q_part_dir), "partial run ディレクトリが存在")
meta_q_part <- jsonlite::fromJSON(file.path(q_part_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_q_part$pass_status$pass1, "partial"), "pass1 は partial")
test_assert(!is.null(meta_q_part$partial_failures) && length(meta_q_part$partial_failures) == 1L, "partial_failures に失敗設問が記録される")

v_q_part_man <- verify_results_manifest(q_part_dir)
test_assert(isTRUE(v_q_part_man$valid), "partial run でも成功設問のマニフェスト検証は合格")

# 4.3: partial run に対する --preview 許可と本番レンダリング遮断
cat("\n--- Test 4.3: partial run に対する preview 許可と本番遮断 ---\n")
res_q_part_prev <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R",
  "--run-dir", q_part_dir,
  "--preview"
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_part_prev == 0L, "partial run に対する preview は生成可能")
test_assert(file.exists(file.path(q_part_dir, "dashboard_preview.html")), "dashboard_preview.html が生成される")

res_q_part_prod <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R",
  "--run-dir", q_part_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_part_prod != 0L, "partial run に対する本番 dashboard.html 生成は遮断される")

# 4.4: 全失敗時の failed 遷移
cat("\n--- Test 4.4: Questionnaire batch 全失敗 (failed) ---\n")
cfg_fail_df <- cfg_part_df
cfg_fail_df$var1 <- "bad_col_all"
q_cfg_fail <- file.path(temp_base, "q_config_fail.csv")
utils::write.csv(cfg_fail_df, q_cfg_fail, row.names = FALSE)

res_q_fail <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/batch_runner.R",
  "--data", survey_data,
  "--question-config", q_cfg_fail,
  "--out", q_out_root,
  "--run-id", "q_test_fail"
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_fail != 0L, "全失敗時は batch_runner.R は非ゼロ終了")

q_fail_dir <- file.path(q_out_root, "runs", "q_test_fail")
meta_q_fail <- jsonlite::fromJSON(file.path(q_fail_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_q_fail$pass_status$pass1, "failed"), "pass1 は failed")
test_assert(identical(meta_q_fail$run_state, "active"), "run_stateはactive、pass_statusで失敗を示す")

# 4.5: --supersedes-run の動作 (partial 許可、failed 拒絶)
cat("\n--- Test 4.5: supersedes-run (partial 許可、failed 拒絶) ---\n")
# failed run の supersede 拒絶
test_expect_error(
  verify_superseded_run(q_fail_dir, "questionnaire-batch-analysis"),
  expected_pattern = "pass1 が failed の run を supersede 元に指定することはできません",
  msg = "failed run の supersede 拒絶"
)

# partial run の supersede 許可
sup_part_info <- verify_superseded_run(q_part_dir, "questionnaire-batch-analysis")
test_assert(!is.null(sup_part_info$superseded_results_manifest_sha256), "partial run の supersede 検証合格")

# 4.6: cross_question_summary.md の確定と本番ダッシュボード sealed 封印
cat("\n--- Test 4.6: cross_question_summary 確定と本番 sealed 封印 ---\n")
stg_q <- get_run_staging_dir(q_run_dir)
writeLines("# Questionnaire Cross-Question Summary\n\nAll questions analyzed.", file.path(stg_q, "cross_question_summary.md"))

res_q_fin_p2 <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", q_run_dir,
  "--source-artifact", file.path(stg_q, "cross_question_summary.md"),
  "--target-name", "cross_question_summary.md",
  "--expected-results-manifest-sha256", meta_q1$results_manifest_sha256
), stdout = TRUE, stderr = TRUE)
status_q_p2 <- attr(res_q_fin_p2, "status")
if (is.null(status_q_p2)) status_q_p2 <- 0L
if (status_q_p2 != 0L) {
  cat("Questionnaire Pass 2 finalize failed:\n", paste(res_q_fin_p2, collapse = "\n"), "\n")
}
test_assert(status_q_p2 == 0L, "Questionnaire Pass 2 確定 正常終了")
test_assert(file.exists(file.path(q_run_dir, "cross_question_summary.md")), "cross_question_summary.md が確定配置される")

# 本番 render_dashboard.R 実行
res_q_prod_dash <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R",
  "--run-dir", q_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_prod_dash == 0L, "Questionnaire 本番 render_dashboard.R 正常終了")

prod_q_html <- file.path(q_run_dir, "dashboard.html")
test_assert(file.exists(prod_q_html), "dashboard.html が生成される")

meta_q_final <- jsonlite::fromJSON(file.path(q_run_dir, "run_meta.json"), simplifyVector = FALSE)
test_assert(identical(meta_q_final$run_state, "sealed"), "Questionnaire 本番確定後に run_state が sealed に封印される")
test_assert(identical(meta_q_final$pass_status$pass3, "completed"), "pass3 が completed になる")

# sealed 後の再レンダリング拒絶
res_q_sealed_reject <- system2("Rscript", c(
  ".agents/skills/questionnaire-batch-analysis/templates/render_dashboard.R",
  "--run-dir", q_run_dir
), stdout = FALSE, stderr = FALSE)
test_assert(res_q_sealed_reject != 0L, "sealed 後のダッシュボード再レンダリングは拒絶される")

cat("\n=== ALL Phase 4 Tests PASSED successfully! ===\n")

cat("\n=== Phase 5: Additional Edge-Case & Boundary Tests ===\n")

# 5.1a: stale ロック回復・PID 生存拒絶・ホスト不一致拒絶・監査ログ
cat("\n--- Test 5.1a: stale ロック回復検証 ---\n")
stale_test_run <- file.path(temp_base, "run_stale_test")
dir.create(stale_test_run, recursive = TRUE)
write_run_meta(temp_base, stale_test_run, "vcd-bayesian-evidence-analysis", "stale_test_id")

run_lock_id_stale <- digest::digest(normalizePath(stale_test_run, winslash = "/", mustWork = TRUE), algo = "sha256", serialize = FALSE)
locks_root <- file.path(temp_base, ".run_locks", run_lock_id_stale)
dir.create(locks_root, recursive = TRUE)
pass2_lock_dir <- file.path(locks_root, "pass2.lock")
dir.create(pass2_lock_dir, recursive = FALSE)

# 1) 死滅 PID、古いタイムスタンプ、同一ホスト -> recover_stale = FALSE では拒絶
dead_pid <- 99998L
while (length(suppressWarnings(system2("ps", c("-p", dead_pid, "-o", "pid="), stdout=TRUE, stderr=FALSE)))) dead_pid <- dead_pid - 1L
old_time <- format(Sys.time() - 600, "%Y-%m-%dT%H:%M:%S%z")
my_host <- as.character(Sys.info()[["nodename"]])
fake_lock_info <- list(
  stage = "pass2",
  run_dir = normalizePath(stale_test_run, winslash = "/"),
  pid = dead_pid,
  hostname = my_host,
  acquired_at = old_time,
  token = "fake_token_123"
)
jsonlite::write_json(fake_lock_info, file.path(pass2_lock_dir, "lock_info.json"), auto_unbox = TRUE)

test_expect_error(
  acquire_stage_lock(stale_test_run, "pass2", recover_stale = FALSE),
  expected_pattern = "排他ロックが既に保持されています",
  msg = "stale ロック存在下で recover_stale=FALSE 時の拒絶"
)

# 2) 同条件で recover_stale = TRUE -> 正常回復、監査ログ記録
rec_lock <- acquire_stage_lock(stale_test_run, "pass2", recover_stale = TRUE, stale_threshold_secs = 300L)
test_assert(dir.exists(rec_lock$lock_dir), "stale ロック回復後にロックが再取得される")

audit_file <- file.path(locks_root, "audit.jsonl")
test_assert(file.exists(audit_file), "stale ロック回復時に audit.jsonl が作成される")
audit_lines <- readLines(audit_file)
test_assert(any(grepl("recover_stale_lock", audit_lines)), "audit.jsonl に recover_stale_lock が記録されている")
release_stage_lock(rec_lock)

# 3) 生存 PID (自プロセス PID) -> recover_stale = TRUE でも拒絶
dir.create(pass2_lock_dir, recursive = FALSE)
alive_lock_info <- list(
  stage = "pass2",
  run_dir = normalizePath(stale_test_run, winslash = "/"),
  pid = Sys.getpid(),
  hostname = my_host,
  acquired_at = old_time,
  token = "alive_token_456"
)
jsonlite::write_json(alive_lock_info, file.path(pass2_lock_dir, "lock_info.json"), auto_unbox = TRUE)
test_expect_error(
  acquire_stage_lock(stale_test_run, "pass2", recover_stale = TRUE, stale_threshold_secs = 300L),
  expected_pattern = "現在も生存しています",
  msg = "生存 PID ロックに対する recover_stale の拒絶"
)
unlink(pass2_lock_dir, recursive = TRUE)

# 4) 異なるホスト -> recover_stale = TRUE でも拒絶
dir.create(pass2_lock_dir, recursive = FALSE)
diff_host_info <- list(
  stage = "pass2",
  run_dir = normalizePath(stale_test_run, winslash = "/"),
  pid = dead_pid,
  hostname = "different_remote_host_999",
  acquired_at = old_time,
  token = "diff_host_token_789"
)
jsonlite::write_json(diff_host_info, file.path(pass2_lock_dir, "lock_info.json"), auto_unbox = TRUE)
test_expect_error(
  acquire_stage_lock(stale_test_run, "pass2", recover_stale = TRUE, stale_threshold_secs = 300L),
  expected_pattern = "異なるホストのロックです",
  msg = "異なるホストのロックに対する recover_stale の拒絶"
)
unlink(pass2_lock_dir, recursive = TRUE)

# 5) finalize_run_stage.R CLI からの --recover-stale-lock 実行
writeLines('{"res": 1}', file.path(stale_test_run, "evidence_results.json"))
m_stale <- write_results_manifest(stale_test_run, "vcd-bayesian-evidence-analysis", list(
  list(path = "evidence_results.json", role = "primary_results", sha256 = sha256_file(file.path(stale_test_run, "evidence_results.json")))
))
dir.create(pass2_lock_dir, recursive = FALSE)
jsonlite::write_json(fake_lock_info, file.path(pass2_lock_dir, "lock_info.json"), auto_unbox = TRUE)

stg_stale <- get_run_staging_dir(stale_test_run)
writeLines("Recovered Narrative", file.path(stg_stale, "executive_summary.md"))

res_cli_rec <- system2("Rscript", c(
  ".agents/shared/finalize_run_stage.R",
  "--stage", "pass2",
  "--run-dir", stale_test_run,
  "--source-artifact", file.path(stg_stale, "executive_summary.md"),
  "--target-name", "executive_summary.md",
  "--expected-results-manifest-sha256", m_stale$manifest_sha256,
  "--recover-stale-lock"
), stdout = FALSE, stderr = FALSE)
test_assert(res_cli_rec == 0L, "finalize_run_stage.R --recover-stale-lock で正常確定")
test_assert(file.exists(file.path(stale_test_run, "executive_summary.md")), "executive_summary.md が確定配置される")

# 5.1b: 考察 Markdown 改ざん後の Pass 3 確定拒絶 (由来ハッシュ不一致検知)
cat("\n--- Test 5.1b: 考察 Markdown 改ざん後の Pass 3 確定拒絶 ---\\n")
orig_narrative_hash <- sha256_file(file.path(stale_test_run, "executive_summary.md"))
# Markdown を不正に改ざん
writeLines("Tampered Narrative Content!", file.path(stale_test_run, "executive_summary.md"))

stg_stale_p3 <- get_run_staging_dir(stale_test_run)
writeLines("<html>tampered preview</html>", file.path(stg_stale_p3, "dashboard.html"))

test_expect_error(
  finalize_pass3(stale_test_run, "dashboard.html", file.path(stg_stale_p3, "dashboard.html"),
                 expected_results_manifest_sha256 = m_stale$manifest_sha256,
                 expected_narrative_sha256 = orig_narrative_hash),
  expected_pattern = "narrative_sha256 不一致",
  msg = "考察 Markdown 改ざん時の Pass 3 確定拒絶"
)

# 5.1c: staging cleanup / sealed 前空検証 (残存ファイルがある場合の封印拒絶)
cat("\n--- Test 5.1c: staging cleanup / sealed 前空検証 ---\\n")
# 正しい内容に戻す
writeLines("Recovered Narrative", file.path(stale_test_run, "executive_summary.md"))
# staging に余分な未管理ファイルを配置
writeLines("temporary garbage", file.path(stg_stale_p3, "unmanaged_leftover.tmp"))

test_expect_error(
  finalize_pass3(stale_test_run, "dashboard.html", file.path(stg_stale_p3, "dashboard.html"),
                 expected_results_manifest_sha256 = m_stale$manifest_sha256,
                 expected_narrative_sha256 = orig_narrative_hash),
  expected_pattern = "staging 領域が空ではありません",
  msg = "staging 残存ファイル存在時の封印拒絶"
)

# 余分なファイルを削除して正常確定
unlink(file.path(stg_stale_p3, "unmanaged_leftover.tmp"))
fin3_res <- finalize_pass3(stale_test_run, "dashboard.html", file.path(stg_stale_p3, "dashboard.html"),
                           expected_results_manifest_sha256 = m_stale$manifest_sha256,
                           expected_narrative_sha256 = orig_narrative_hash)
test_assert(identical(fin3_res$run_state, "sealed"), "staging 空検証後に正常封印される")
test_assert(!dir.exists(stg_stale_p3), "封印後に staging ディレクトリがクリーンアップされる")

cat("\n=== ALL Phase 5 Lifecycle Tests PASSED successfully! ===\n")

# 実描画されたHTMLのローカル補助アセット参照を検査する。
for (html_path in c(prod_html, prod_c_html, prod_q_html)) {
  html <- paste(readLines(html_path, warn=FALSE),collapse="\n")
  refs <- regmatches(html,gregexpr("(?:src|href)=[\"'][^\"']+[\"']",html,perl=TRUE))[[1]]
  urls <- sub("^[^=]+=[\"']", "", sub("[\"']$", "", refs))
  local <- urls[!grepl("^(https?:|data:|//|#|mailto:|javascript:)",urls,ignore.case=TRUE)]
  assets <- local[grepl("\\.(js|css|png|jpe?g|gif|svg|woff2?)([?#].*)?$",local,ignore.case=TRUE)]
  test_assert(length(assets)==0L,paste("公開HTMLがローカル補助アセットに依存しない:",basename(dirname(html_path))))
}
