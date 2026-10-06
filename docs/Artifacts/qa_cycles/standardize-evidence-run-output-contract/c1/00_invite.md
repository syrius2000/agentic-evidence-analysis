# 独立 QA レビュー依頼: Skill 出力契約とエージェント文書の全体整合

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `codex/standardize-evidence-run-output-contract`
- **Baseline commit:** `17670c0516c4885c64c86731a413108a28f8cb8a`
- **Reviewed commit:** `936fa41ae57e4bde4b84a230427951ade70903cc`
- **Reviewed subject:** `Yip: WIP QA review standardize-evidence-run-output-contract`
- **Diff:** `git diff 17670c0516c4885c64c86731a413108a28f8cb8a 936fa41ae57e4bde4b84a230427951ade70903cc`
- **Focus pack:** `openspec-coherence`, `provenance-plans`, `path-sanitization`
- **Output dir:** `docs/Artifacts/qa_cycles/standardize-evidence-run-output-contract/c1/`
- **Cycle:** `1`
- **Audience:** `cloud`
- **Remote visibility:** `pushed`
- **Baseline subject:** `Yip: WIP QA checkpoint standardize-evidence-run-output-contract`
- **Changed paths:**
  - `docs/Artifacts/plans/implementation_plan_005_1006.md`
  - `openspec/changes/standardize-evidence-run-output-contract/.openspec.yaml`
  - `openspec/changes/standardize-evidence-run-output-contract/design.md`
  - `openspec/changes/standardize-evidence-run-output-contract/proposal.md`
  - `openspec/changes/standardize-evidence-run-output-contract/specs/evidence-run-layout/spec.md`
  - `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-freq/spec.md`
  - `openspec/changes/standardize-evidence-run-output-contract/specs/sas-proc-means/spec.md`
  - `openspec/changes/standardize-evidence-run-output-contract/tasks.md`
- **Diff summary:** `8 files changed, 420 insertions(+)`
- **Requester notes:**
  - Review whether plan 005 and all four OpenSpec artifact types form a coherent, implementable whole.
  - Check the new canonical roots for all eight analysis skills, `comparative-design-analysis` persistence ownership, the SAS `output_dir` constraint, Pass 0 exception, and questionnaire legacy-read boundary against current specs and repository evidence.
  - The proposed restriction of explicit output roots to each skill namespace is intentionally a breaking change; assess whether the spec, migration notes, implementation tasks, and acceptance checks express it consistently.
  - Do not implement, repair, approve implementation, or make Owner decisions.

## 重点監査観点

### openspec-coherence

1. Compare each delta against the full existing capability spec, runtime behavior, schemas, and related documentation. Flag any change to existing output, metadata, compatibility, or skill-interface contracts that is not explicit in this Change.
2. Check exact capability paths, complete MODIFIED requirement blocks/scenarios, testable requirements, and consistency among proposal, specs, design, tasks, and plan 005.
3. Run `openspec validate standardize-evidence-run-output-contract --type change --strict` when available; report the actual result.

### provenance-plans

1. Confirm `implementation_plan_005_1006.md` uses an available plan ID, does not overwrite another plan, and names source paths that exist in the reviewed tree.
2. Confirm the file inventory and task groups cover the promised full-scope audit and implementation without silently shrinking to selected documentation only.
3. Check that artifact placement follows `docs/Artifacts/README.md` and that any exclusions or preserved legacy files are explicit.

### path-sanitization

1. Check added/changed content for real machine-specific absolute paths, personal identifiers, `file:///` links, Windows drive paths, and UNC paths.
2. Treat literal forbidden-path examples used as rules/tests as examples, not findings. Review the changed tree content, not historical git metadata.

## Reviewer contract

- Write ONLY these files under Output dir: `01_review.md`, `02_tasks.md`, `03_machine.json`, `STATUS.md`. Do not modify `00_invite.md` or any product, plan, or OpenSpec paths outside Output dir.
- Create all four files. Use the templates and completeness rules below; report in Japanese and retain code identifiers in English.
- Inspect the real diff `git diff <Baseline> <Reviewed>` and verify findings against source/spec evidence. Requester notes are navigation only, not evidence.
- Findings must be actionable mismatches or risks grounded in evidence. Do not list aligned items, dump formulas, or provide Owner `ACCEPT`/`ARCHIVE` decisions.
- Every actionable finding must have a task; every High finding must have a task. Each finding must cite `path:line`, expected behavior, and `repair_surface` (`docs`, `code`, `spec`, or `plan`).
- Do not change Baseline/Reviewed SHAs, merge to main, force-push, edit product code, or decide whether implementation may proceed.
- After the four files are complete, stage only those four files, commit `Yip: QA review standardize-evidence-run-output-contract c1` with trailer `Blind-QA-Review-Artifacts: standardize-evidence-run-output-contract`, then push only the current topic branch using `git push -u origin HEAD`. If the cloud checkout cannot write/push, return the four file bodies for requester `ingest`; do not claim persistence.

### Required output templates

`01_review.md`:

```markdown
# 独立QAレビュー

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `codex/standardize-evidence-run-output-contract`
- Baseline: `17670c0516c4885c64c86731a413108a28f8cb8a`
- Reviewed: `936fa41ae57e4bde4b84a230427951ade70903cc`
- Cycle: `1`
- Audience: `cloud`
- Remote visibility: `pushed`
- Focus packs: `openspec-coherence`, `provenance-plans`, `path-sanitization`
- Gate: `PASS | HOLD | FAIL | INCONCLUSIVE`

## 結論
<!-- Blocking items only -->

## Findings
### QA-AREA-H01: <title>
- Severity: High | Medium | Low
- Status: OPEN | CLOSED
- Evidence: `path/to/file:line`
- Expected: <contract>
- Finding: <verified mismatch>
- repair_surface: docs | code | spec | plan

## Re-QA
- 推奨Baseline: `936fa41ae57e4bde4b84a230427951ade70903cc`
- 再確認対象: <finding IDs or none>
```

`02_tasks.md`:

```markdown
# 修復タスク

- [ ] T-01 (closes: QA-AREA-H01) severity=High; path=`path/to/file`; action=<具体的な修正>; done_when=<観察可能な完了条件>; verify=<確認手順と期待結果>
```

`03_machine.json`:

```json
{
  "schema": "blind-qa-cycle-v1",
  "topic": "standardize-evidence-run-output-contract",
  "cycle": 1,
  "baseline": "17670c0516c4885c64c86731a413108a28f8cb8a",
  "reviewed": "936fa41ae57e4bde4b84a230427951ade70903cc",
  "audience": "cloud",
  "remote_visibility": "pushed",
  "gate": "HOLD",
  "focus_packs": ["openspec-coherence", "provenance-plans", "path-sanitization"],
  "findings": [
    {"id": "QA-AREA-H01", "severity": "High", "status": "OPEN", "title": "short title", "repair_surface": "docs"}
  ],
  "tasks": [
    {"id": "T-01", "closes": "QA-AREA-H01", "done": false, "verify": "how to verify"}
  ]
}
```

`findings` and `tasks` may be empty when no actionable findings exist. If findings exist, task `closes` values must match finding IDs; allowed gates are `PASS`, `HOLD`, `FAIL`, `INCONCLUSIVE`; allowed severities are `High`, `Medium`, `Low`, `PASS`; allowed repair surfaces are `docs`, `code`, `spec`, `plan`.

`STATUS.md` must contain exactly one gate token: `PASS`, `HOLD`, `FAIL`, or `INCONCLUSIVE`, matching `03_machine.json`.
