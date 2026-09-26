# comparative-evidence-reporting-v3 — Final State Independent QA Review 1

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Reviewed branch HEAD: `0f8ad85ae76a9824ab5048b2af4d039f3bd3479c`
- Review type: full-state archive-readiness QA
- Review date: 2026-09-26 JST
- Owner Task 17.5 sign-off: accepted
- Reviewer: GPT-5.6 Sol

## Decision

```text
Sections 0–16 implementation / regression state:
PASS (materially verified)

Section 17 archive-readiness:
HOLD

Blocker 0
High    1
Medium  1

Task 17.5:
CLOSED / Owner approved

Task 17.6:
INTENTIONALLY OPEN — separate archive authorization not yet given
```

No new statistical-engine, dashboard-rendering, CSV/filter, or visual-artifact defect was identified.

The remaining issues are formal specification / task-ledger consistency issues that should be corrected before archive.

## 1. Current State

Current branch HEAD:

```text
0f8ad85ae76a9824ab5048b2af4d039f3bd3479c
Yip: record Owner sign-off on operational risks (Task 17.5)
```

No commit-bound GitHub status or workflow run exists for the reviewed SHA.

Current OpenSpec task counts:

```text
checked   = 235
unchecked = 2
```

Unchecked:

```text
7.4  Implement versioned departmental policy mode for delta boundaries
17.6 Require explicit, separate authorization before /opsx-archive
```

Task 17.6 is correctly open and is not a defect.

## 2. Prior QA Closure

All previously open implementation findings are materially closed.

Section 14 / Dashboard:

- Task 14.10 sortable-table remediation: CLOSED.
- M14.11-01 CSV internal row_key leakage: CLOSED.
- M14.14-01 execution-evidence mismatch: CLOSED.
- H14.13-01 / H14.13-02 mathematical-guide semantics: CLOSED.

The current guide explicitly branches across posterior-only, bootstrap-only, and mixed inferential semantics.

The current dashboard regression test explicitly verifies:

```text
posterior -> posterior_median + posterior_eti
bootstrap -> observed_sample_estimate + bootstrap_percentile
mixed     -> explicit row-level inferential_semantics distinction
```

Section 15 findings remain closed.

Section 16 H16-01 and M16-01 / Task 16.13 remain closed.

## 3. Current Regression / Artifact Evidence

Implementer evidence records:

```text
tests/test_comparative_dashboard_qa.R : 158 / 158 PASS
tests/test_vcd_categorical_reporting.R: 35 / 35 PASS
tests/run_regression_suite.R          : 50 / 50 PASS
Python ownership contract             : 10 / 10 PASS
Python archive integrity              : 5 / 5 suites PASS
DOM/static interaction audit          : 11 / 11 PASS
OpenSpec strict validation            : valid / 0 issues
git diff --check                      : clean
Owner dashboard visual inspection     : PASS
```

The canonical regression registry includes comparative schema, practical-difference, reporting, and dashboard QA suites.

The latest coherent visual QA run is:

`evidence_runs/visual_qa_s14/run_20260926_174946/`

The reviewer independently recomputed its dashboard SHA-256:

```text
manifest:
be29491637b44e255991868393a2bb9aac5fe652d0311338ad38d974b1703156

recomputed:
be29491637b44e255991868393a2bb9aac5fe652d0311338ad38d974b1703156

MATCH = TRUE
```

No visual-run provenance finding is reopened.

## 4. H17-01 — Archived OpenSpec Delta Specification Does Not Match the Accepted Final Implementation

Severity: HIGH
Impacts: 17.2 / 17.4 / archive readiness

Task 17.4 is currently checked as confirming full alignment between code implementation, tests, and OpenSpec delta specifications. That statement is not yet true.

### H17-01a — primary_delta = null contract contradicts runtime

Current formal delta spec `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-evidence-reporting/spec.md` states that when primary_delta is null, practical region support and U-grade are null.

The accepted runtime and tests instead implement:

```text
practical_region_support = NULL

resolution_grade = {
  grade = "NONE",
  dominant_region = "none",
  max_region_probability = NULL
}
```

This is intentional and already accepted through Section 14/16 QA.

The formal spec must be updated to the accepted runtime contract; the runtime should not be changed back to make the stale spec true.

### H17-01b — Tasks 14.10–14.14 are absent from the formal delta specification

The final product includes accepted behavior for:

```text
14.10 sortable accessible comparative summary
14.11 Excel-compatible full / filtered-sorted CSV export
14.12 Theme / Region+U-Grade / Diagnostic multi-select filters
14.13 inferential-semantics-adaptive MathML / Markdown metric guide
14.14 integrated self-contained/browser/accessibility QA contract
```

These exist in tasks, plans, runtime, tests, and visual QA evidence, but `comparative-evidence-reporting/spec.md` contains no formal requirement/scenario for sortable behavior, CSV export, filtering, accordion guidance, or MathML.

If archived now, the archived delta spec will not describe a material part of the shipped capability.

### Required repair — 17.R1

Update `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-evidence-reporting/spec.md`.

At minimum:

1. Correct the null-delta scenario to practical_region_support=null plus resolution_grade NONE/none/null and disabled practical-region hue.
2. Add a formal self-contained interactive-dashboard requirement covering stable sort, keyboard/aria-sort, machine-readable sort keys, and zero external assets.
3. Add CSV export requirements for all rows and current filtered/sorted rows, exact canonical columns, internal row_key exclusion, and UTF-8 BOM/RFC4180-safe output.
4. Add filter requirements for Theme, Practical Region/U-Grade, and Diagnostic badges with OR-within / AND-across semantics and filter+sort composition.
5. Add mathematical-guide requirements for default-collapsed native accordion, self-contained math rendering, posterior/bootstrap/mixed semantic adaptation, and Markdown meaning synchronization.
6. Re-run OpenSpec strict validation, dashboard QA, full regression, and git diff check.
7. Reopen Task 17.4 until this is complete.

Because H17-01 is now an open High finding, Task 17.2 should also be temporarily reopened until this repair is independently closed.

## 5. M17-01 — Task 17.1 Is Inconsistent with Deferred Task 7.4

Severity: MEDIUM
Impact: archive task-ledger consistency

Task 17.1 is checked and literally states that all tasks 0.1 through 16.13 have verified executable evidence, while Task 7.4 remains unchecked.

Section 16 documentation records Task 7.4 as Owner-approved deferred / out-of-scope.

There is a partial helper implementation:

`get_departmental_delta_policy(policy_version = "v1", domain = ...)`

with unit coverage in `tests/test_practical_difference.R`.

However the helper is not wired as an active departmental-policy analysis/configuration mode in the production routing/reporting path. The current state is therefore best described as:

```text
policy helper / prototype exists
full departmental policy mode is deferred
Task 7.4 remains incomplete by design
```

That is compatible with Owner adjudication, but not with the literal wording of 17.1.

### Required repair — 17.R2

Do not mark 7.4 complete merely to satisfy 17.1.

Instead make the task ledger explicit, for example:

```text
17.1 Verify all in-scope tasks 0.1–16.13 have executable evidence,
excluding Owner-adjudicated deferred Task 7.4.
```

and annotate Task 7.4 itself as deferred/out-of-scope for this change, or move it to a named future change.

After that wording/state reconciliation, 17.1 may remain complete.

## 6. Section 17.3 — Schema Freeze

No finding.

The core schemas remain explicitly version-bound as `comparative-draws-v1` and `comparative-evidence-v1`, and the commits after the readiness gate alter task/sign-off state rather than those schemas.

## 7. Task 17.5 — CLOSED

The Owner has explicitly approved the remaining documented operational risks.

Task 17.5 is complete.

## 8. Task 17.6 — Correctly Open

Task 17.6 requires separate explicit authorization before invoking `/opsx-archive`.

The current request asks for overall QA, not archive execution authorization.

Therefore Task 17.6 must remain unchecked.

## 9. Overall Final Gate

```text
Implementation / statistical engines      PASS
Design-aware inference                    PASS
Evidence-decision review                  PASS
Dashboard / CSV / filtering / guide       PASS
Documentation ecosystem                   PASS
Section 16 regression/Owner adjudication  PASS
Schema freeze                             PASS
Owner operational-risk sign-off           PASS

Formal OpenSpec final-spec alignment       HOLD — H17-01
Task-ledger deferred-scope consistency     HOLD — M17-01

Blocker 0
High    1
Medium  1

Overall comparative-evidence-reporting-v3:
HOLD FOR ARCHIVE
```

Expected after 17.R1 + 17.R2:

```text
Blocker 0
High    0
Medium  0

comparative-evidence-reporting-v3:
PASS / ACCEPT / ARCHIVE-READY

17.6 remains [ ] until separate explicit archive authorization.
```

Plan 023 / comparative-evidence-exploration-v1 is intentionally outside this final QA scope and should remain a separate post-archive change.