# Tasks

## 1. Pass 1 lifecycle and handoff

- [x] 1.1 Add a focused lifecycle regression test that asserts Pass 1 remains `active`, registers only canonical computed outputs, and hands off to AI Pass 2 and Dashboard Pass 3; verify it fails against current behavior.
- [x] 1.2 Refactor comparative report generation to preserve canonical result contracts, defer final `dashboard.html`, write a stable Pass 1 manifest, record Pass 1 as complete while keeping the run active, and emit the staged handoff; run the lifecycle test and verify it passes.

## 2. Summary-bound Dashboard finalization

- [x] 2.1 Add renderer regression tests for complete summary inclusion, skill ID display, missing/empty/stale-summary rejection, and hostile markup escaping; verify new renderer behaviors fail against the original code and record that the shared empty-file guard already passes.
- [x] 2.2 Implement the Pass 3 renderer and shared finalization integration, embedding the escaped full summary and metadata skill ID before the table; run the focused renderer tests and verify artifact hashes, provenance links, and sealed state.

## 3. Skill and quality-contract alignment

- [x] 3.1 Update `vcd-categorical-reporting/SKILL.md` and `analysis_quality_contract.md` to include this skill in Pass 2/3, define the required Pass 1 → summary → Dashboard sequence, and describe incomplete-run behavior; verify their artifact names and gates match the handoff and renderer.
- [x] 3.2 Update run metadata, results-manifest, and Dashboard documentation where needed; run `openspec validate embed-executive-summary-in-dashboard` and confirm both capability deltas validate without altering canonical result schemas.

## 4. End-to-end verification

- [x] 4.1 Add an end-to-end regression case that runs a small reporting fixture through Pass 1, summary finalization, and Pass 3; verify the Dashboard contains the exact summary and skill ID, is offline and safe, and the sealed run passes manifest and provenance checks.
- [x] 4.2 Run the focused lifecycle, renderer, and end-to-end tests; record results and any remaining visual or compatibility limits in the run report.

## 5. Executive-summary presentation revision

- [x] 5.1 Use a disposable TDD fixture to demonstrate the old ordering and raw Markdown fail the required accordion, HTML structure, and safety checks; implement safe Markdown rendering after the unchanged guidance callout.
- [x] 5.2 Update the existing tracked renderer and end-to-end tests for the new HTML contract, run the focused and comparative regressions, and remove only this task's disposable test runs.
- [x] 5.3 Regenerate the safety-data Dashboard in a new run, compare all contrasts and CSV to the prior run, and verify summary content, ordering, provenance, and OpenSpec consistency.
