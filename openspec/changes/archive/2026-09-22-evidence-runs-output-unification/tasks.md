## 1. 共有基盤改修 (Phase 1)

- [x] 1.1 `tests/test_skill_run_isolation.R` または関連テストに、ID正規化（`run_001` → `run_001`）、衝突回避、および旧形式探索のテストケースを追加し検証する
- [x] 1.2 `.agents/shared/run_scope.R` の `reserve_run_output_dir` を改修し、Questionnaire特例を解消して全スキル共通で `run_<id>[_N]` 隔離ディレクトリおよびID正規化を実装・検証する
- [x] 1.3 `.agents/shared/run_scope.R` の探索ロジックを改修し、旧 `runs/<id>/` の読取り専用探索互換を実装・検証する
- [x] 1.4 `.agents/shared/inspect_data.R` および `.agents/shared/finalize_pass0_config.R` の出力先パス例・既定値を `evidence_runs/inspections` に整合させる

## 2. スキル別設定・ランナー・ドキュメント更新 (Phase 2)

- [x] 2.1 `questionnaire-batch-analysis`: `templates/batch_runner.R` の既定値（`./evidence_runs/questionnaire`）更新、JST時刻論理ID生成、`SKILL.md`, `Reference.md` を更新し検証する
- [x] 2.2 `vcd-bayesian-evidence-analysis`: `templates/analysis.R`, `templates/dashboard.Rmd`, `config_example.json`, `SKILL.md` の既定値を `evidence_runs/vcd_bayesian` に更新し検証する
- [x] 2.3 `vcd-categorical-analysis`: `templates/analysis.R`, `templates/dashboard.Rmd`, `templates/report.Rmd`, `SKILL.md` の既定値を `evidence_runs/vcd_categorical` に更新し検証する
- [x] 2.4 `sas-proc-freq` / `sas-proc-means`: `schemas/analysis_config.schema.json`, `SKILL.md` の記述・例を `evidence_runs/sas_proc_freq`, `evidence_runs/sas_proc_means` に更新し検証する
- [x] 2.5 `AGENTS.md`（鉄則3）、`README.md`、`.gitignore` の除外設定を `evidence_runs/` に更新する

## 3. テストと全体検証 (Phase 3)

- [x] 3.1 `tests/test_questionnaire_batch_ucbadmissions.R` 等のテストコードの期待値を更新し、単体実行で検証する
- [x] 3.2 正規回帰テストスイート（`Rscript tests/run_regression_suite.R`）およびPython所有権テスト（`python3 tests/test_skill_ownership_contract.py`）を実行し全件PASSを確認する
- [x] 3.3 各スキルの最小実演を実行し、`evidence_runs/` 配下の生成ファイル、`run_meta.json`、およびZero-External-Asset/絶対パス漏洩スキャンを検証する
- [x] 3.4 OpenSpecの厳格構造検証（`openspec validate --strict`）を実行し、適合を確認する
