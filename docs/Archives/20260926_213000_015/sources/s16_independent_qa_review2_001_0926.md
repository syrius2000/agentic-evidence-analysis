# Section 16 — Independent Re-QA Review 2

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `3423e8f8cc09812172bbb1b1035c107247e3f08c`
- Reviewed commit: `2e64a3958f7238aa907a98fc1240e1661c8471b2`
- Scope: Section 16 remediation for H16-01 (16.R1) and M16-01 (16.R2)
- Review mode: independent Re-QA
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol
- Owner visual feedback: dashboard appearance reported OK
- New Owner request: sortable rows in the Comparative Evidence Summary table

## Decision

```text
H16-01 / 16.R1: CLOSED
M16-01 / 16.R2: OPEN

Blocker 0
High    0
Medium  1

Section 16:
HOLD
```

No new Blocker/High implementation defect was found.

The newly requested sortable table is recorded separately as E16-01 (Enhancement / scope addition) and is not counted as a defect severity.

---

## 1. Commit / Scope Verification

The requested range is exactly one remediation commit:

```text
3423e8f8cc09812172bbb1b1035c107247e3f08c
    ↓
2e64a3958f7238aa907a98fc1240e1661c8471b2
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 3423e8f...
```

Changed files:

```text
docs/Artifacts/implementation_plan_021_0926.md
docs/Artifacts/s16_independent_qa_exec_001_0926.md
openspec/changes/comparative-evidence-reporting-v3/tasks.md
```

Branch HEAD equals the reviewed commit at review time.

No commit-bound GitHub status or workflow run exists for the reviewed SHA.

---

## 2. H16-01 / 16.R1 — CLOSED

The remediation adds an explicit Canonical Contract Reconciliation section to Plan 021 and corrects the execution record to the accepted runtime/schema/test contracts.

Correctly reconciled items:

- posterior zero-reference: `relative_risk.mean = null`, `mean_is_finite = false`, `diagnostics.badges` includes `ZERO_REFERENCE`;
- `ZERO_REFERENCE_RISK` limited to design-aware/bootstrap RR-suppression paths;
- `primary_delta = null` -> `practical_region_support = NULL`, `resolution_grade.grade = "NONE"`, `dominant_region = "none"`, transparent practical cell;
- decision-ledger genesis -> `previous_record_sha256 = null`;
- discordance advisory -> `is_qa_review_candidate`, `advisory_flag = "QA Review Candidate"`, `severity = "advisory"`, `halts_workflow = false`, `exploratory_only = true`, `decision_rule = false`;
- U3 color -> `rgba(148, 163, 184, 0.12)`;
- zero-reference presentation -> `N/A` or finite median with `[N/A]`, warning callout, and badges;
- nonexistent `departmental_policy.json` correctly marked deferred Task 7.4;
- archive-integrity claim narrowed to selected manifest-bound SHA-256 checks.

The original plan draft still retains pre-reconciliation statements, but the appended reconciliation section explicitly supersedes them. This preserves audit history and is acceptable, consistent with the Section 15 reconciliation pattern.

**H16-01: CLOSED.**

---

## 3. M16-01 / 16.R2 — OPEN

Task 16.13 requires both recording residual risks and obtaining explicit Owner adjudication.

The remediation correctly restores:

```text
[ ] 16.13
```

and no longer claims 13/13 completion.

Current recorded Owner status:

```text
Pandoc / dynamic-library environment dependency: confirming
Exploratory multiplicity interpretation:          confirming
Gower scalability:                                accepted
Task 7.4 departmental policy deferral:            confirming
```

The Owner statement that the visual appearance is OK is valid presentation feedback, but it is not explicit adjudication of the remaining operational/scope conditions.

Therefore M16-01 remains OPEN.

A sufficient Owner adjudication would explicitly accept, reject, or condition:

1. the Pandoc/runtime-environment dependency;
2. the exploratory-only multiplicity limitation;
3. keeping Task 7.4 deferred/out-of-scope.

The Gower scalability item is already accepted.

---

## 4. E16-01 — Sortable Comparative Evidence Summary

Type: Owner-requested enhancement
Severity: none
Status: NEW / not implemented

The current dashboard uses a static table and contains no `aria-sort`, sort event handler, `addEventListener` sorter, or inline sorting script.

Recommended contract:

```text
click header:
  first click  -> ascending
  second click -> descending

keyboard:
  header control remains keyboard operable

accessibility:
  aria-sort = none | ascending | descending

sorting:
  stable
  N/A/unavailable values after real values
  existing cell HTML, badges, practical-region colors preserved
```

Recommended type-aware sort keys:

```text
Theme             -> text
Comparison        -> text
Descriptive N     -> target N, reference N tie-break
Event counts      -> target events, reference events tie-break
RD                -> rd_estimate
RR                -> rr_estimate; unavailable last
Direction support -> direction_support
Practical/U-Grade -> U0, U1, U2, U3, NONE ordinal
Precision         -> rd_interval_width
Diagnostics       -> badge text
```

For composite presentation cells, use explicit machine-readable attributes such as `data-sort-value` rather than parsing rendered strings.

Implementation should remain self-contained: inline vanilla JavaScript only, with no DataTables/CDN/external assets.

Required regression checks if included in this release:

```text
sortable headers present
aria-sort contract
numeric ascending/descending
text ascending/descending
N/A ordering
U-grade ordinal sorting
stable ties
badge/color markup preserved after reorder
zero external assets still holds
DOM/accessibility contract still passes
browser check for RD and U-Grade sorting
```

E16-01 is not a defect in the reviewed implementation. It is a late Owner scope addition.

If it is intended for comparative-evidence-reporting-v3 before archive, implement it before Section 17 and rerun dashboard/regression/OpenSpec/diff/browser QA, then repeat the Section 16 acceptance check on the new SHA.

---

## 5. Final Gate

```text
H16-01: CLOSED
M16-01: OPEN

E16-01: NEW OWNER ENHANCEMENT — sortable Comparative Evidence Summary

Blocker 0
High    0
Medium  1

Section 16:
HOLD
```

Section 16 can reach PASS / ACCEPT after explicit Owner adjudication closes 16.13.

If E16-01 is intended for the current v3 release, Section 17 should remain gated until the sorting enhancement is implemented and the affected dashboard/regression gates are rerun.