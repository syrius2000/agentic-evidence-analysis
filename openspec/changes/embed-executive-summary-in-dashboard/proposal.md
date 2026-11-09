# Proposal

## Why

The comparative reporting workflow currently creates `dashboard.html` directly from statistical summary data and does not load the separately authored `executive_summary.md`. This makes a run appear complete while its reviewed interpretation is absent from the primary report surface, contrary to the expected single-dashboard workflow.

## What Changes

- Make the finalized comparative dashboard include the complete run-specific executive summary and identify the analysis skill used.
- **BREAKING**: Change the one-call reporting API to a staged lifecycle; its `html_path` is a preview until the summary is finalized and Pass 3 renders the final Dashboard.
- Treat a missing, stale, or mismatched summary as a finalization failure; do not present the run as complete.
- Align the reporting skill, shared quality contract, run handoff, dashboard rendering, and run-state lifecycle around this requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `comparative-evidence-reporting`: require the finalized dashboard to embed the run's executive summary and selected skill identity, with provenance checks and a fail-closed finalization flow.
- `evidence-run-layout`: recognize comparative reporting as a staged run that remains active until the summary and final Dashboard are sealed.

## Impact

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R` and reporting lifecycle/finalization helpers.
- `.agents/skills/vcd-categorical-reporting/SKILL.md` and `.agents/shared/analysis_quality_contract.md`.
- Comparative reporting tests and run artifact metadata/manifest integration.
- Existing canonical evidence JSON and 40-field summary CSV contracts remain unchanged.
