# Spec Delta

## ADDED Requirements

### Requirement: Final Dashboard Displays the Run Summary and Skill Identity

Every finalized comparative reporting Dashboard SHALL display the complete run-specific `executive_summary.md` and identify the analysis skill from that run's metadata. The embedded content SHALL remain readable, safely encoded, and self-contained offline.

#### Scenario: Finalizing a dashboard with a reviewed summary

- **WHEN** Pass 3 finalizes a comparative reporting run with a non-empty `executive_summary.md` bound to that run's canonical evidence
- **THEN** `dashboard.html` MUST visibly include the complete summary content and the skill identifier from `run_meta.json`

#### Scenario: Summary is missing or does not match the run

- **WHEN** Pass 3 is requested and the summary is missing, empty, or its recorded evidence digest differs from the run's canonical results
- **THEN** finalization MUST fail, MUST NOT emit a completed Dashboard or mark the run completed, and MUST report the specific summary validation failure

#### Scenario: Summary contains markup-like or hostile text

- **WHEN** summary text is rendered into the standalone Dashboard
- **THEN** it MUST be displayed as readable summary content without executing embedded scripts or loading external assets

### Requirement: Dashboard Finalization Verifies Summary Provenance

Pass 3 SHALL verify that the non-empty run summary is bound to the canonical results manifest before producing the final Dashboard. Run metadata SHALL record hashes linking the summary and Dashboard to the canonical results manifest and to each other. A missing, empty, or mismatched summary SHALL leave the run incomplete.

#### Scenario: Finalizing a dashboard with a verified summary

- **WHEN** Pass 3 finalizes a comparative reporting run with a non-empty `executive_summary.md` bound to that run's canonical evidence
- **THEN** `run_meta.json` MUST record the summary and Dashboard hashes and their provenance links, and the run MUST be sealed only after finalization succeeds

#### Scenario: Summary is missing or does not match the run

- **WHEN** Pass 3 is requested and the summary is missing, empty, or its recorded evidence digest differs from the run's canonical results
- **THEN** finalization MUST fail, MUST NOT emit a completed Dashboard or mark the run completed, and MUST report the specific summary validation failure
