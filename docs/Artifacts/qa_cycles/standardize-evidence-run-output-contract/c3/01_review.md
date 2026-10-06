# 独立QAレビュー

created: 2026-10-06 18:09 (JST)
update: 2026-10-06 18:09 (JST)
author: Codex (GPT-6.1-sol)

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `codex/standardize-evidence-run-output-contract`
- Baseline: `3b8e32ab7b835286db082b598460bd5dbf9ec85c`
- Reviewed: `03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- Cycle: `3`
- Audience: `local`
- Remote visibility: `local-only`
- Focus packs: `openspec-coherence`, `path-sanitization`, `provenance-plans`
- Gate: `HOLD`

## 結論

- QA-TEST-H01: 出力root resolverの回帰検査がmacOS上で9件失敗しており、Task 5.1の完了根拠を満たせない。

## Findings

### QA-TEST-H01: macOS実体パスの期待値不整合によりrun isolation回帰が失敗する

- Severity: High
- Status: OPEN
- Evidence: `tests/test_skill_run_isolation.R:101-110` は期待値を`normalizePath(..., mustWork = FALSE)`で比較するが、`run_scope.R:49-53`は`assert_no_symlink()`を経由し、`run_scope.R:454-473`で`/var`を実体の`/private/var`へ正規化する。
- 実測: `Rscript tests/test_skill_run_isolation.R` は77件PASS、9件FAIL。8 Skillのstable slug rootとnamespace内custom rootの比較が全て失敗した。再現確認ではactualが`/private/var/...`、expectedが`/var/...`となり`identical()`がFALSEだった。
- Expected: `tests/test_skill_run_isolation.R`は、macOSのシステム別名を含む環境でもstable slug root・namespace内custom rootの契約を正しく検査し、Task 5.1の確認コマンドとして終了コード0になる。resolverのsymlink拒否と実体パス検証は維持する。
- repair_surface: code

## 検証記録

- SHA: BaselineとReviewedはローカルに存在し、BaselineはReviewedの祖先であることを確認した。
- 静的確認: `git diff --check 3b8e32ab7b835286db082b598460bd5dbf9ec85c 03081d6fe278b83c349ff65d4ea23f92b7328a7e` は成功した。
- OpenSpec: `openspec validate standardize-evidence-run-output-contract --type change --strict` は成功した。
- 文書: `python3 scripts/test_doc_consistency.py` は `PASS（R registry 50件）`。
- 実行: `tests/test_questionnaire_symlink_escape.R`、`tests/test_sas_proc_freq_numerical_parity.R`、`tests/test_sas_proc_means_numerical_parity.R`、`tests/test_vcd_bayesian_run_id.R`、`tests/test_vcd_categorical_run_isolation.R`、`tests/test_vcd_categorical_dashboard_run_resolution.R`、`tests/test_vcd_categorical_reporting.R` は成功した。
- 未検証: `tests/test_inspect_data_out_dir.R`、`tests/test_three_way_inspection_sha_contract.R`、およびQA-TEST-H01修復後の全対象回帰は未実行。
- Path sanitization: Reviewed treeを検索した結果、差分外の`docs/Artifacts/antigravity_deceptive_behavior_and_systemic_redesign_feedback_001_0926.md:54`に`/Users/.../.gemini/config`という省略済みプレースホルダーを確認した。具体的なユーザー名または実在ローカル絶対パスの根拠はないため、Findingには含めない。

## Re-QA

- 推奨Baseline: `03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- 再確認対象: `QA-TEST-H01`
