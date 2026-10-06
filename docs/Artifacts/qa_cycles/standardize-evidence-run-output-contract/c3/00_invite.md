# 独立 QA レビュー依頼: standardize-evidence-run-output-contract 実装検証

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `codex/standardize-evidence-run-output-contract`
- **Baseline commit:** `3b8e32ab7b835286db082b598460bd5dbf9ec85c`
- **Reviewed commit:** `03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- **Reviewed subject:** `Yip: standardize evidence run output contract`
- **Diff:** `git diff 3b8e32ab7b835286db082b598460bd5dbf9ec85c 03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- **Focus packs:** `openspec-coherence`, `path-sanitization`, `provenance-plans`
- **Output dir:** `docs/Artifacts/qa_cycles/standardize-evidence-run-output-contract/c3/`
- **Cycle:** `3`
- **Audience:** `local`
- **Remote visibility:** `local-only`
- **Baseline subject:** `Yip: QA review standardize-evidence-run-output-contract c2`
- **Changed paths:**
  - `.agents/shared/evidence_feature_extract.R`
  - `.agents/shared/finalize_pass0_config.R`
  - `.agents/shared/inspect_data.R`
  - `.agents/shared/run_scope.R`
  - `.agents/skills/comparative-design-analysis/SKILL.md`
  - `.agents/skills/questionnaire-batch-analysis/SKILL.md`
  - `.agents/skills/questionnaire-batch-analysis/templates/batch_runner.R`
  - `.agents/skills/sas-proc-freq/SKILL.md`
  - `.agents/skills/sas-proc-freq/schemas/analysis_config.schema.json`
  - `.agents/skills/sas-proc-freq/templates/run_freq.R`
  - `.agents/skills/sas-proc-means/SKILL.md`
  - `.agents/skills/sas-proc-means/schemas/analysis_config.schema.json`
  - `.agents/skills/sas-proc-means/templates/run_means.R`
  - `.agents/skills/vcd-bayesian-evidence-analysis/SKILL.md`
  - `.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`
  - `.agents/skills/vcd-bayesian-evidence-analysis/references/legacy_usage.md`
  - `.agents/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
  - `.agents/skills/vcd-categorical-analysis/SKILL.md`
  - `.agents/skills/vcd-categorical-analysis/references/interface.md`
  - `.agents/skills/vcd-categorical-analysis/references/report-template.md`
  - `.agents/skills/vcd-categorical-analysis/references/workflow.md`
  - `.agents/skills/vcd-categorical-analysis/templates/analysis.R`
  - `.agents/skills/vcd-categorical-analysis/templates/dashboard.Rmd`
  - `.agents/skills/vcd-categorical-analysis/templates/report.Rmd`
  - `.agents/skills/vcd-categorical-reporting/SKILL.md`
  - `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
  - `.agents/skills/vcd-categorical-reporting/references/interface.md`
  - `.agents/skills/vcd-categorical-reporting/references/report-template.md`
  - `.agents/skills/vcd-categorical-reporting/references/workflow.md`
  - `.agents/skills/vcd-pass0-consultation/SKILL.md`
  - `AGENTS.md`
  - `README.md`
  - `docs/Artifacts/README.md`
  - `docs/reference/skill_responsibilities.md`
  - `openspec/changes/standardize-evidence-run-output-contract/specs/evidence-run-layout/spec.md`
  - `openspec/changes/standardize-evidence-run-output-contract/tasks.md`
  - `openspec/specs/evidence-run-layout/spec.md`
  - `openspec/specs/sas-proc-freq/spec.md`
  - `openspec/specs/sas-proc-means/spec.md`
  - `scripts/test_doc_consistency.py`
  - `tests/test_comparative_dashboard_qa.R`
  - `tests/test_comparative_schemas.R`
  - `tests/test_dependency_isolation_pass1.R`
  - `tests/test_evidence_feature_extract.R`
  - `tests/test_questionnaire_duplicate_output_slug.R`
  - `tests/test_questionnaire_symlink_escape.R`
  - `tests/test_sas_proc_freq_numerical_parity.R`
  - `tests/test_sas_proc_means_numerical_parity.R`
  - `tests/test_skill_ownership_contract.py`
  - `tests/test_skill_run_isolation.R`
  - `tests/test_vcd_bayesian_analysis_config_schema.R`
  - `tests/test_vcd_bayesian_run_id.R`
  - `tests/test_vcd_categorical_dashboard_run_resolution.R`
  - `tests/test_vcd_categorical_reporting.R`
  - `tests/test_vcd_categorical_run_isolation.R`
- **Diff summary:** `55 files changed, 574 insertions(+), 271 deletions(-)`
- **Requester notes:**
  - 本依頼は OpenSpec Change `standardize-evidence-run-output-contract` の全実装完了コミット `03081d6fe278b83c349ff65d4ea23f92b7328a7e` に対する独立QAレビュー依頼です。
  - Baseline は直前の c2 レビュー完了コミット `3b8e32ab7b835286db082b598460bd5dbf9ec85c`（c2 PASS 判定後）を採用しており、差分は実装タスクに対応するコード、テスト、OpenSpec同期、およびガバナンス文書の変更です。
  - レビュー対象の主な論点：
    1. 各分析スキルの出力先規約（`evidence_runs/<skill_slug>/run_<canonical_id>[_N]/`）および `output_dir` 解決制約（各スキル名前空間配下に限定、`..` や symlink 逸脱拒否）が、共有基盤（`run_scope.R`）と各スキルのテンプレート/スクリプト/スキーマで一貫して実装されているか。
    2. Pass 0 例外（`inspect_data.R`）、`comparative-design-analysis` の in-memory 契約および将来の永続化責務の記述が矛盾なく反映されているか。
    3. ガバナンス文書（`AGENTS.md`、`README.md`、`docs/Artifacts/README.md`、`docs/reference/skill_responsibilities.md`）および各スキル `SKILL.md` の記載が相互に整合し、古い規約（フラットな `evidence_runs/` 直下への保存や旧 slug 名など）の残骸がないか。
    4. 環境依存パス（`/Users/...` など）や Markdown 内 `file:///` リンクがコードおよびドキュメントに混入していないか（focus pack: `path-sanitization`）。
  - 修復・コード修正・Owner 判断（ACCEPT/ARCHIVE）は行わず、差分と一次情報に基づいた独立評価を実施してください。

## 重点監査観点

### openspec-coherence

1. Diffed docs/specs must not redefine presentation or statistical contracts that already passed Planning/Implementation QA unless the Change explicitly MODIFIES them.
2. Cross-check in order: `openspec/specs/<capability>/spec.md` → runtime modules → any new `docs/reference/*.md`.
3. Flag renamed diagnostic codes, column orders, default draws (`num_draws`), and parameterization (e.g. Gamma shape-rate vs scale) that disagree across layers.
4. `openspec validate` relevant capabilities when the environment allows; if not run, mark `未検証` in the finding or summary (do not invent PASS).

### path-sanitization

1. **環境依存パスおよび個人情報の完全無害化**:
   - リポジトリ全体で特定個人名や OS ローカル絶対パス（`/Users/...` 等）、および Markdown 内 `file:///` リンクが完全に排除されているか。
2. Reviewer notes:
   - Scope default: **reviewed commit tree content** (not full git history rewrite).
   - Distinguish real absolute paths / `file:///` navigation links (Findings) from literal forbid-patterns inside rules/tests/docs (PASS caveat).

### provenance-plans

1. **Plan ID immutability:** `implementation_plan_NNN_*.md` must not be overwritten by a different case. New work uses NNN = max existing + 1 under `docs/Artifacts/plans/` (legacy flat plans remain readable).
2. **Source-of-truth file lists** in plans must name modules that exist in the reviewed tree (no hallucinated paths).
3. Portal docs (`AGENTS.md`, root `README.md`, `docs/reference/README.md`) must not contradict newly added “P0 satisfied / missing” status within the same reviewed commit.
4. Repair surface for provenance breaks is usually `plan` or `docs`, not silent history rewrite.

## Reviewer contract

- Write ONLY under Output dir: `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md`. Do **not** modify `00_invite.md` or any product/code paths outside that Output dir.
- Create all four files in the specified Output dir in the QA checkout. Follow the exact templates and completeness checks in `references/cloud_output_contract.md`.
- Create the Output dir if it is absent; never overwrite a frozen prior cycle.
- Findings only in `01_review.md` (no long Aligned formula dumps); write the report in Japanese, preserving code identifiers in English.
- Every actionable finding must have a task; every High finding must have one. Each task identifies the finding ID, path, concrete completion condition, and verification/expected result.
- Chat final reply ≤5 bullets (Gate / Output dir / Blocking count / Task count / Next action / Artifacts git SHA or ingest-needed).
- **Do not** edit product code, change Baseline/Reviewed SHAs, merge to main, force-push, or Owner-decide (no ACCEPT/ARCHIVE).
- **Audience=`local`:** Writing into the shared clone is enough; do not push unless the user separately asks.
- If Baseline or Reviewed SHA is missing in this clone: do NOT review another tip; Gate HOLD with High provenance finding; still write the four artifacts.

### Required output: `01_review.md`

```markdown
# 独立QAレビュー

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `codex/standardize-evidence-run-output-contract`
- Baseline: `3b8e32ab7b835286db082b598460bd5dbf9ec85c`
- Reviewed: `03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- Cycle: `3`
- Audience: `local`
- Remote visibility: `local-only`
- Focus packs: `openspec-coherence`, `path-sanitization`, `provenance-plans`
- Gate: `PASS | HOLD | FAIL | INCONCLUSIVE`

## 結論
<!-- Blocking項目だけを簡潔に記載 -->

## Findings
<!-- 各指摘: ID (QA-<AREA>-<H|M|L|P><nn>), Severity, Status, Evidence (path:line), Expected, repair_surface (docs|code|spec|plan) -->

## Re-QA
- 推奨Baseline: `03081d6fe278b83c349ff65d4ea23f92b7328a7e`
- 再確認対象: `<finding IDs>`
```

### Required output: `02_tasks.md`

```markdown
# 修復タスク

- [ ] T-01 (closes: QA-AREA-H01) severity=High; path=`path/to/file`; action=<具体的な修正内容>; done_when=<観察可能な完了条件>; verify=<確認手順と期待結果>
```

### Required output: `03_machine.json`

```json
{
  "schema_version": "blind-qa-cycle-v1",
  "topic": "standardize-evidence-run-output-contract",
  "cycle": 3,
  "audience": "local",
  "remote_visibility": "local-only",
  "baseline_commit": "3b8e32ab7b835286db082b598460bd5dbf9ec85c",
  "reviewed_commit": "03081d6fe278b83c349ff65d4ea23f92b7328a7e",
  "gate": "PASS | HOLD | FAIL | INCONCLUSIVE",
  "findings": [],
  "tasks": []
}
```

### Required output: `STATUS.md`

単一語のみ（改行を含む）：
```text
PASS
```
（または `HOLD` / `FAIL` / `INCONCLUSIVE`）
