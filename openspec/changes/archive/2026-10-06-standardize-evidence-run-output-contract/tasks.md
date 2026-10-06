# Tasks

## 1. 確定インベントリと共通出力基盤

- [x] 1.1 `README.md`、`AGENTS.md`、`docs/Artifacts/README.md`、`openspec/specs/`、`.agents/skills/`、`.agents/shared/`、`schemas/`、`tests/`、`scripts/` を `evidence_runs/|skill_out/|output_dir|--out-dir|run_output_dir|reserve_run_output_dir|run_meta` で横断検索し、計画005の範囲に該当する全ファイルをこのtasksファイル内の対象一覧または該当実装タスクへ列挙する。Archive・fixture内生成例・旧Implementation Planは履歴として分類し、実改定対象に含めない。確認方法: 同じ検索を再実行し、結果の全パスに「改定タスク」または「変更不要/例外の根拠」が対応することを確認する。
- [x] 1.2 `comparative-design-analysis` から利用される全関数・wrapper・callerをrepo全体で追跡し、run/成果物を永続化するwriterの有無を確定する。確認方法: call graphと検索結果を記録し、writerがあればrootを指定するcallerを特定、なければ非永続in-memory契約を対象文書で明示する。

### Inventory result (task 1.1)

Search scope: the requested active paths only; `docs/Archives/`, fixture directories, and historical implementation plans were excluded. The seven search terms were rerun after implementation in task 5.2. Matched paths and their owning implementation/verification tasks:

- **Repository entry docs:** `AGENTS.md` (2.1), `README.md` (2.2). `docs/Artifacts/README.md` had no search-term hit; it remains an explicit review/update target under 2.3. No files under `scripts/` matched.
- **Current specs:** `openspec/specs/evidence-run-layout/spec.md`, `openspec/specs/sas-proc-freq/spec.md`, `openspec/specs/sas-proc-means/spec.md` (2.4).
- **Shared runtime:** `.agents/shared/run_scope.R` (1.3, 1.4, 4.5), `.agents/shared/finalize_run_stage.R` (1.4, 4.5), `.agents/shared/inspect_data.R` and `.agents/shared/finalize_pass0_config.R` (1.5, 4.5), `.agents/shared/evidence_feature_extract.R` (4.4, 4.5).
- **Skill docs and runtime/config files:** `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`, `references/analysis_config.schema.json`, `references/legacy_usage.md`, `templates/analysis.R`, `templates/config_example.json`, `templates/config_validation.R`, `templates/dashboard.Rmd`, `templates/pass2_stub.R`, `templates/render_dashboard.R` (3.1); `.agents/skills/vcd-categorical-analysis/SKILL.md`, `references/interface.md`, `references/report-template.md`, `references/workflow.md`, `templates/analysis.R`, `templates/dashboard.Rmd`, `templates/report.Rmd` (3.2); `.agents/skills/vcd-categorical-reporting/SKILL.md`, `comparative_reporting.R`, `references/interface.md`, `references/report-template.md`, `references/workflow.md` (3.3); `.agents/skills/questionnaire-batch-analysis/SKILL.md`, `templates/batch_runner.R`, `templates/dashboard.Rmd` (4.1); `.agents/skills/sas-proc-freq/SKILL.md`, `schemas/analysis_config.schema.json`, `templates/run_freq.R` (4.2); `.agents/skills/sas-proc-means/SKILL.md`, `schemas/analysis_config.schema.json`, `templates/run_means.R` (4.3); `.agents/skills/evidence-decision-review/SKILL.md` (4.4); `.agents/skills/vcd-pass0-consultation/SKILL.md` (1.5). Other questionnaire references/examples and the comparative-design skill doc had no literal search hit; they remain explicit checks in 4.1/4.4.
- **Top-level schema:** the final scan found no output-root field in `schemas/comparative-evidence-batch-v1.json`; it does not define an analysis output path and needs no change.
- **Tests matched for verification triage in 5.1:** `tests/test_comparative_dashboard_qa.R`, `tests/test_comparative_schemas.R`, `tests/test_conditional_rank_reproducibility.R`, `tests/test_config_validation_rules.R`, `tests/test_dashboard_theme_contract.R`, `tests/test_dependency_isolation_pass1.R`, `tests/test_evidence_feature_extract.R`, `tests/test_inspect_data_out_dir.R`, `tests/test_sas_proc_freq_numerical_parity.R`, `tests/test_sas_proc_means_numerical_parity.R`, `tests/test_skill_ownership_contract.py`, `tests/test_skill_run_isolation.R`, `tests/test_three_way_analysis_config_schema.R`, `tests/test_three_way_inspection_sha_contract.R`, `tests/test_vcd_bayesian_analysis_config_schema.R`, `tests/test_vcd_bayesian_arm_warning_cli_fail.R`, `tests/test_vcd_bayesian_arm_weighted.R`, `tests/test_vcd_bayesian_cramers_v.R`, `tests/test_vcd_bayesian_dashboard_multiselect_filters.R`, `tests/test_vcd_bayesian_dashboard_require_pass2.R`, `tests/test_vcd_bayesian_dashboard_v2.R`, `tests/test_vcd_bayesian_ebic_schema.R`, `tests/test_vcd_bayesian_insight.R`, `tests/test_vcd_bayesian_levels.R`, `tests/test_vcd_bayesian_run_id.R`, `tests/test_vcd_bayesian_threshold_large_viz.R`, `tests/test_vcd_bayesian_topk.R`, `tests/test_vcd_bayesian_vars_freq_fei.R`, `tests/test_vcd_categorical_dashboard_run_resolution.R`, `tests/test_vcd_categorical_dashboard_v4.R`, and `tests/test_vcd_categorical_reporting.R`. Task 5.1 will distinguish run-layout assertions to update from unrelated temporary report-output arguments that should remain unchanged.

### comparative-design-analysis persistence trace (task 1.2)

The four public inference functions are `run_matched_pair_dirichlet()` (`.agents/shared/matched_pair_dirichlet.R`), `run_matched_set_inference()` (`.agents/shared/matched_set_inference.R`), `run_iptw_inference()` (`.agents/shared/iptw_inference.R`), and `run_person_time_rate()` (`.agents/shared/person_time_rate.R`). Repository-wide caller search found only direct use from tests; `.agents/skills/comparative-design-analysis/SKILL.md` dispatches these functions. No production wrapper/caller serializes their result bundles to files. Their `persist_raw_draws=TRUE` option retains draws in the returned R object; it is not a disk writer. Therefore this Skill currently has an in-memory inference contract, not a persisted run-output contract. This boundary is recorded in the Skill documentation; any future persistence caller must own the output root and place files under the registered `evidence_runs/comparative_design/` run directory.

### Final output-path inventory triage (tasks 4.5, 5.2)

- A fresh scan over active guides, references, OpenSpecs, Skill trees, shared runtime, schemas, tests, and scripts produced 432 matching lines across 81 files. The runtime slug registry and normative spec are cross-checked against `AGENTS.md` and `README.md` by `scripts/test_doc_consistency.py`.
- The only active `skill_out/` literals are in the Reporting legacy template/interface; both label them historical and direct new outputs to `evidence_runs/vcd_categorical_reporting/run_<canonical_id>[_N]/`.
- `run_run_*` appears only in the normative prohibition and its regression assertion. No production writer creates that form.
- Remaining temporary output paths are non-writing dependency/error fixtures, UI render destinations, or namespace-contained. `tests/test_dependency_isolation_pass1.R`, SAS suites, reporting suites, and run isolation tests now use namespace-contained analysis output roots.
- Questionnaire `runs/<id>/` remains read-only. VCD categorical `templates/report.Rmd` is explicitly legacy v1.x and is not a canonical output entrypoint.
- [x] 1.3 `.agents/shared/run_scope.R` に安定slug対応とSkill root resolverを実装し、out_rootの実体パスを正規化して当該Skill namespace内か検証してからrun予約する。未登録skill、namespace外、traversal、symlink逸脱は書込み前に拒否し、既存のID正規化・原子的suffix・run metadata契約を維持する。確認方法: root resolverの正常/異常/境界テストを追加・更新し、`tests/test_skill_run_isolation.R` を実行する。
- [x] 1.4 `.agents/shared/finalize_run_stage.R` と各runnerの共通run基盤呼び出しをresolverへ接続し、`run_meta.json` の `out_root` と `run_output_dir` が実体パスに一致するよう整合する。確認方法: 各Skillの代表runでmetadataと実ディレクトリを比較するテストを通す。
- [x] 1.5 `.agents/shared/inspect_data.R`、`.agents/shared/finalize_pass0_config.R`、`.agents/skills/vcd-pass0-consultation/SKILL.md` の検分出力を分析root台帳と分離し、未指定時 `.` の互換と明示inspection rootの例外を一致させる。確認方法: `tests/test_inspect_data_out_dir.R` と `tests/test_three_way_inspection_sha_contract.R` を更新・実行する。

## 2. 共通文書とroot運用の改定

- [x] 2.1 `AGENTS.md` をエージェント横断契約として保ち、OpenSpec・AGENTS・Skillの正本階層、8 Skillの安定slugによるroot、run隔離、inspection例外、Artifacts置き場規約を簡潔に同期する。確認方法: root/slug/Pass 0の記載をspec台帳と照合し、文書整合性checkを通す。
- [x] 2.2 `README.md` の利用者向けSkill案内・例を全件照合し、8 Skillのroot、比較デザインの永続化境界、SAS設定、inspection例外を更新する。確認方法: 全root例をspec台帳と自動または手動比較し、Skill entrypointへのリンクを確認する。
- [x] 2.3 `docs/Artifacts/README.md` と出力契約を記載する現行reference文書を確認し、Artifact配置規約と本Changeへの導線を整える。確認方法: Markdownリンク検査とroot語彙の横断検索で現行契約の矛盾がないことを確認する。
- [x] 2.4 `openspec/specs/evidence-run-layout/spec.md`、`openspec/specs/sas-proc-freq/spec.md`、`openspec/specs/sas-proc-means/spec.md` へこのChangeのdeltaを適用し、main specsと実装の規範が一致することを確認する。確認方法: `openspec validate standardize-evidence-run-output-contract --type change --strict` を実行し、終了コード0とstrict validation成功を記録したうえでspec全文レビューを行う。

## 3. VCD解析Skillの出力契約改定

- [x] 3.1 `vcd-bayesian-evidence-analysis` の `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`、`references/analysis_config.schema.json`、`references/dependencies.md`、`references/legacy_usage.md`、`templates/analysis.R`、`templates/config_example.json`、`templates/config_validation.R`、`templates/dashboard.Rmd`、`templates/pass2_stub.R`、`templates/render_dashboard.R` をroot/run契約に照合して改定する。確認方法: `tests/test_vcd_bayesian_analysis_config_schema.R`、`tests/test_vcd_bayesian_run_id.R`、`tests/test_skill_run_isolation.R` を実行する。
- [x] 3.2 `vcd-categorical-analysis` の `.agents/skills/vcd-categorical-analysis/SKILL.md`、`references/dependencies.md`、`references/interface.md`、`references/report-template.md`、`references/workflow.md`、`templates/analysis.R`、`templates/dashboard.Rmd`、`templates/report.Rmd` をroot/run契約に照合して改定する。確認方法: `tests/test_vcd_categorical_run_isolation.R`、`tests/test_vcd_categorical_dashboard_run_resolution.R`、`tests/test_vcd_categorical_interface_v3.R` を実行する。
- [x] 3.3 `vcd-categorical-reporting` の `.agents/skills/vcd-categorical-reporting/SKILL.md`、`comparative_reporting.R`、`references/interface.md`、`references/report-template.md`、`references/workflow.md` をroot/run契約に照合して改定する。Interface 2.1の旧root例と`skill_out/` workflowは現行/legacyの区別を明示し、legacy template本文は保持する。確認方法: `tests/test_vcd_categorical_reporting.R` を実行し、全現行root例を台帳と照合する。

## 4. その他解析Skill・SAS設定・共有成果物の改定

- [x] 4.1 `questionnaire-batch-analysis` の `.agents/skills/questionnaire-batch-analysis/SKILL.md`、`.agents/skills/questionnaire-batch-analysis/Reference.md`、`references/config-schema.md`、`references/dependencies.md`、`references/workflow.md`、`templates/batch_runner.R`、`templates/dashboard.Rmd`、`templates/report.Rmd`、`examples/question_config_example.csv` を照合し、新規runをquestionnaire rootへ統一しつつ旧 `runs/<id>/` をread-onlyで維持する。確認方法: `tests/test_questionnaire_duplicate_output_slug.R`、`tests/test_questionnaire_symlink_escape.R`、`tests/test_skill_run_isolation.R` を実行する。
- [x] 4.2 SAS PROC FREQの `.agents/skills/sas-proc-freq/SKILL.md`、`schemas/analysis_config.schema.json`、`templates/run_freq.R` を `evidence_runs/sas_proc_freq/` と共通run隔離へ更新し、設定JSONの `output_dir` 必須性・namespace制約・設定例を同期する。確認方法: `tests/test_sas_proc_freq_numerical_parity.R` とrun isolation検査を実行する。
- [x] 4.3 SAS PROC MEANSの `.agents/skills/sas-proc-means/SKILL.md`、`schemas/analysis_config.schema.json`、`templates/run_means.R` を `evidence_runs/sas_proc_means/` と共通run隔離へ更新し、設定JSONの `output_dir` 必須性・namespace制約・設定例を同期する。確認方法: `tests/test_sas_proc_means_numerical_parity.R` とrun isolation検査を実行する。
- [x] 4.4 `comparative-design-analysis` の `.agents/skills/comparative-design-analysis/SKILL.md`、`evidence-decision-review` の `.agents/skills/evidence-decision-review/SKILL.md`、`.agents/shared/evidence_feature_extract.R` と、1.2で特定したwriter/callerを照合・改定する。既存writerは各Skillのcanonical rootへ接続し、writerがない推論器はin-memoryであることと永続化owner境界のみ記す。確認方法: design-awareの対象ファイル全件検索と `tests/test_comparative_schemas.R`、`tests/test_skill_ownership_contract.py` を実行する。
- [x] 4.5 `.agents/shared/`、トップレベル `schemas/`、設定schema、manifest/run metadata、static consistency scriptのインベントリを1.1に照合し、root・slug・run pathを定義または検証するファイルをすべて更新する。対象候補: `.agents/shared/run_scope.R`、`finalize_run_stage.R`、`finalize_pass0_config.R`、`inspect_data.R`、`evidence_feature_extract.R`、`schemas/` のpathを保持する該当schema、`scripts/test_doc_consistency.py`。確認方法: inventoryにある各ファイルの契約記述または変更不要根拠を示す。

## 5. 横断回帰と完了確認

- [x] 5.1 出力契約関連テスト・fixturesのインベントリを検索し、全Skillのdefault root、明示rootのnamespace制限、run隔離、suffix衝突、metadata、inspection例外、questionnaire legacy読取、未登録slug拒否を網羅するよう更新する。確認方法: `tests/test_skill_run_isolation.R`、`tests/test_inspect_data_out_dir.R`、Skill別schema/run tests、`scripts/test_doc_consistency.py` を実行し結果を記録する。
- [x] 5.2 repository全体を `evidence_runs/|skill_out/|output_dir|run_<` で再検索し、現行資料・実装・schema・fixturesの期待値に矛盾が残らないことを確認する。Archive、明示legacy資料、fixture自体の歴史的成果物は対象外理由を記録する。
- [x] 5.3 全関連spec、schema、Markdownリンク、OpenSpec Change、`git diff --check` を検証し、ファイルinventoryの全行が「改定済み」または根拠付き「改定不要/履歴例外」であることを確認する。未完了項目を残さず、未実施検証は報告で未検証とする。

## Workflow follow-up

- 実装・レビューの承認と完了後、プロジェクトのOpenSpec運用に従ってChangeをarchiveし、archive結果を確認する。
