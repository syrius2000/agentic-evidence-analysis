# comparative-evidence-reporting-v3 — Final State Independent QA Review 2

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `b3de16fcd2d8d472f163aba32d396f3f4f09baac`
- Reviewed: `83e270e6ba4bec211b104e507ac1d38890218d3a`
- Diff: `b3de16f..83e270e`
- Scope: Remediation 17.R1 / H17-01 and 17.R2 / M17-01
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
H17-01a null-delta spec mismatch: CLOSED
H17-01b missing Tasks 14.10–14.14 formal requirements: CLOSED
M17-01 deferred Task 7.4 / Task 17.1 ledger mismatch: CLOSED

Residual M17-02: OPEN

Blocker 0
High    0
Medium  1

Overall: HOLD FOR ARCHIVE
```

Task 17.2 may remain checked because there are no open Blocker/High findings.
Task 17.4 should be reopened until M17-02 is corrected.
Task 17.6 remains intentionally open pending separate archive authorization.

## 1. Commit-range verification

The requested range is exact and minimal:

```text
baseline = b3de16fcd2d8d472f163aba32d396f3f4f09baac
reviewed = 83e270e6ba4bec211b104e507ac1d38890218d3a
ahead_by = 1
behind_by = 0
merge_base = baseline
```

Only two files changed:

1. `openspec/changes/comparative-evidence-reporting-v3/specs/comparative-evidence-reporting/spec.md`
2. `openspec/changes/comparative-evidence-reporting-v3/tasks.md`

Branch HEAD equals the reviewed SHA.
No commit-bound GitHub status or workflow run exists for the reviewed SHA.

## 2. H17-01a — CLOSED

The null-delta formal scenario now matches the accepted runtime:

```text
practical_region_support = null
resolution_grade.grade = "NONE"
resolution_grade.dominant_region = "none"
resolution_grade.max_region_probability = null
practical-region hue disabled / achromatic presentation
```

This agrees with `.agents/shared/comparative_contrasts.R` and the accepted practical-difference regression contract.

## 3. H17-01b — CLOSED as to requirement coverage

The delta specification now contains formal requirements/scenarios for:

- sortable comparative summary table;
- Excel-compatible canonical CSV export;
- accessible multi-select filtering;
- inferential-semantics-adaptive mathematical and usage guide.

The sortable, CSV, and filter requirements materially match the accepted implementation and tests.

## 4. M17-01 — CLOSED

Task 7.4 is now explicitly annotated:

```text
[DEFERRED / OUT-OF-SCOPE]
```

and Task 17.1 now explicitly limits its assertion to in-scope tasks while excluding Owner-adjudicated deferred Task 7.4.

This accurately describes the repository state: a prototype/versioned helper `get_departmental_delta_policy()` exists and is unit-tested, but a complete production departmental-policy mode remains deferred.

## 5. M17-02 — Mathematical-guide formal requirement describes the wrong DOM/content structure

Severity: MEDIUM

The newly added formal requirement currently says, in substance, that the guide is:

```text
rendered inside a native HTML <details>/<summary> accordion
(#metric-guide, default collapsed)
and structured into 4 foundational blocks:
Contrasts / Practical Difference / Precision / Diagnostics & Multiplicity
```

The accepted implementation and Plan 022 use a different structure:

```text
<section id="metric-guide">
  10 independent sibling <details class="guide-accordion"> items
  each with its own <summary>
  each default collapsed
</section>
```

Each accordion item is organized into four guidance subsections:

```text
Definition
Interpretation
Cautions & Invariants
When to Use
```

Plan 022 explicitly states that the ten guide topics are independent accordions and that each accordion uses the four-block guidance structure above.

`#metric-guide` itself is a `<section>`, not a `<details>` element and is not itself the collapsible accordion.

Also, MathML is used for formula-bearing metric items; the Diagnostics and Multiplicity items are explanatory text/list guidance rather than each being a separate mathematical formula.

This is a documentation/specification mismatch only; no runtime/dashboard defect is reopened.

### Required repair — 17.R3

Replace the mathematical-guide requirement wording with the actual accepted structure. Recommended contract:

```text
The system SHALL provide a self-contained mathematical and interpretation
guide in <section id="metric-guide"> containing 10 independent native
<details class="guide-accordion"> / <summary> items, each default collapsed.
Each item SHALL contain the guidance subsections Definition, Interpretation,
Cautions & Invariants, and When to Use. Formula-bearing metric items SHALL
use native MathML. The guide SHALL adapt posterior/bootstrap/mixed semantics
and maintain semantic alignment with the Markdown report.
```

Update the scenario consistently.

No runtime or test change should be necessary unless the spec edit reveals another mismatch.

After the spec-only correction, rerun at minimum:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Full R regression rerun is optional for a pure spec-text correction, though retaining the existing 158/158 and 50/50 evidence is appropriate if no code/test file changes.

## 6. Verification evidence assessment

Implementer evidence reports:

```text
OpenSpec strict validation    VALID / 0 issues
Dashboard QA                 158 / 158 PASS
Canonical regression suite    50 / 50 PASS
git diff --check              clean
```

These are treated as implementer execution evidence. The reviewed commit has no commit-bound CI/status.

## 7. Archive gate

```text
Blocker 0
High    0
Medium  1

17.1: CLOSED
17.2: CLOSED / may remain checked
17.3: CLOSED
17.4: REOPEN until M17-02 / 17.R3 closes
17.5: CLOSED / Owner approved
17.6: intentionally OPEN

comparative-evidence-reporting-v3:
HOLD FOR ARCHIVE
```

Expected after 17.R3:

```text
Blocker 0
High    0
Medium  0

comparative-evidence-reporting-v3:
PASS / ACCEPT / ARCHIVE-READY

17.6 remains open until separate explicit archive authorization.
```