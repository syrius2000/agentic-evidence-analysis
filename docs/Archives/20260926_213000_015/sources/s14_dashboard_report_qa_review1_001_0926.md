# Section 14 — Blind-First Independent QA Review 1

- Repository: syrius2000/agentic-evidence-analysis
- Branch: feat/comparative-evidence-reporting-v3
- Baseline: c3067917cff377371eabdd0e4a86d21efcfc86e1
- Reviewed commit: 3a2643aa34c4fec21aec1fdf9a0549fdf10bbb0c
- Scope: Section 14 only — Tasks 14.1–14.9
- Out of scope: Section 15–17; Section 13 (CLOSED)
- Plan: docs/Artifacts/implementation_plan_016_0925.md
- Execution record: docs/Artifacts/s14_dashboard_report_exec_001_0925.md
- Review mode: blind-first independent QA
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

Section 14: HOLD

Blocker: 0
High: 2
Medium: 2

Do not start Section 15 until the two High findings are closed.

## 1. Commit / Scope Verification

The requested range is exactly one commit. GitHub compare reports ahead_by=1, behind_by=0, total_commits=1, with merge-base equal to the supplied baseline.

Changed files are limited to comparative_reporting.R, the new Section 14 QA test, the regression registry, OpenSpec task tracking, and the execution record. No commit-bound GitHub status or workflow run is present for the reviewed SHA.

## 2. Positive Findings

- 14.1: HTML now separates identification/context, Effect Size, Direction, Practical Difference, Precision, and Diagnostics.
- 14.2/14.3: practical-region color is limited to the Practical Difference cell; U3 uses the muted slate override.
- 14.4: diagnostic badges are separated from RD/RR estimate cells.
- 14.8: dashboard/title/table IDs, caption, scope=col, and aria-describedby were added.

## 3. H14-01 — Suppressed RR interval can fail before warning rendering

Severity: HIGH

The revised plan explicitly requires a bootstrap RR interval-suppressed case. IPTW can intentionally set relative_risk.interval, log_rr_interval_width, and rr_interval_fold_range to NULL while setting a diagnostic such as PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES or ZERO_REFERENCE_RISK.

Section 14 currently reads rr_low/rr_upp from the possibly NULL interval, then uses the repository %||% operator to evaluate fallback expressions containing conditions such as !is.na(rr_low) && !is.na(rr_upp). When the canonical precision metric is NULL, the fallback is evaluated while rr_low/rr_upp are also NULL. This is not null-safe and occurs before the later rr_interval_available / instability-warning logic can protect the path.

The new Section 14 tests do not exercise a real design-aware override with relative_risk.interval=NULL.

Required repair 14.R1:

- normalize nullable RR interval and precision fields before arithmetic/if conditions;
- preserve governed suppression as NA/N/A rather than recomputing suppressed metrics;
- add IPTW partial-undefined and zero-reference override fixtures;
- require report generation to succeed, RD to remain visible, RR interval to be unavailable, and the warning callout to appear.

## 4. H14-02 — Unescaped input-derived HTML can violate Zero-External-Asset

Severity: HIGH

The renderer inserts theme, target_arm, reference_arm and other text directly into HTML via sprintf without an HTML escaping boundary.

A valid input label such as <img src="https://example.invalid/x"> or a script tag can therefore become active markup in dashboard.html. The current zero-external-asset tests use only benign labels, so they establish only that the hard-coded template has no external URLs; they do not establish the generated-artifact contract for arbitrary valid text labels.

Required repair 14.R2:

- add one audited HTML escaping helper for all data-derived visible text;
- allowlist enum-derived class fragments rather than inserting arbitrary class text;
- add hostile-but-valid label fixtures and verify no active external img/script/link/style reference is created;
- refine the external-resource audit so escaped visible URL text is not confused with an active dependency.

## 5. M14-01 — Task 14.9 browser visual verification was not actually completed

Severity: MEDIUM

OpenSpec requires browser visual verification using a subagent or manual render. The execution record states that browser rendering failed and then substitutes static DOM/CSS source inspection. Static inspection is not a browser/manual render and cannot establish wrapping, overlap, viewport overflow, or actual rendered hierarchy.

The execution record also claims max-width:1200px, margin:0 auto, and overflow-x:auto were used for horizontal scrolling control. Those rules are not present in the reviewed dashboard CSS.

The referenced visual artifact evidence_runs/visual_qa_s14/run_20260926_030803/dashboard.html is not included in the reviewed commit, so it cannot be independently inspected from GitHub.

A supplemental reviewer Chromium render of equivalent reviewed markup at 1280x800 did not show page-level overflow for one representative row, but that is not the exact generated artifact and does not satisfy Task 14.9 evidence.

Required repair 14.R3:

- render the exact generated artifact at 1280x800 using browser subagent, localhost Chromium, page-content automation, or documented manual rendering;
- record exact artifact identity/hash, viewport, scrollWidth vs innerWidth, callout visibility, badge placement, U3 appearance, and practical-cell-only hue;
- remove or correct execution-record CSS claims that are absent from the code.

## 6. M14-02 — Bootstrap RR provenance reads non-canonical paths

Severity: MEDIUM

The plan requires rr_bootstrap_defined_replicates and rr_bootstrap_undefined_replicates in summary provenance. The implementation reads direct fields under relative_risk or diagnostics that the repository producers do not emit.

Actual producer locations include:

- matched-set: relative_risk.rr_bootstrap_diagnostics.defined_replicates / undefined_replicates
- IPTW: iptw.bootstrap_diagnostics.defined_rr_replicates / undefined_rr_replicates

Because generate_comparative_report currently accepts IPTW design-aware overrides, the new summary columns remain NA for real IPTW bootstrap diagnostics. The warning may still trigger through rr_interval_available or rr_diagnostic, so this is Medium rather than High.

Required repair 14.R4:

- normalize from the actual canonical producer paths;
- assert provenance values, not merely column-name existence, in Section 14 tests.

## 7. Test Adequacy Notes

The U3 test contains an unconditional PASS fallback if its synthetic fixture stops producing U3. That should be changed so the test fails when the intended U3 state is not reached.

The new provenance tests check that column names exist, but they do not verify design-aware/bootstrap values. This is why the path mismatch above passes the current 45-test suite.

## 8. Implementer Evidence

Consulted only after the blind-first review:

- test_comparative_dashboard_qa.R: 45 PASS / 0 FAIL
- test_vcd_categorical_reporting.R: 35 PASS / 0 FAIL
- run_regression_suite.R: 50/50 PASS
- OpenSpec strict: valid
- git diff --check: clean

These remain implementer execution evidence. The reviewer runtime does not provide Rscript, and no commit-bound CI/status evidence exists for the reviewed SHA.

## 9. Final Gate

Current:

- Blocker 0
- High 2
- Medium 2
- Section 14: HOLD

Expected after 14.R1–14.R4 closure:

- Blocker 0
- High 0
- Medium 0
- Section 14: PASS / ACCEPT

Section 15 should remain gated until 14.R1 and 14.R2 are independently closed.
