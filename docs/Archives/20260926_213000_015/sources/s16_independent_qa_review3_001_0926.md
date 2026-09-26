# Section 16 — Final Independent Re-QA Review 3

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Supplied baseline: `96924ae6587c699fa84a30e87b7a6ddc4974f260` (not resolvable on GitHub remote at review time)
- Actual reviewed commit parent: `fcae9c0ceb594497d69b90099b21f79f11c7e0a9`
- Reviewed commit: `897b829c215bba7a4b5558f1552bf7088f2b2bc9`
- Scope: Section 16 final verification (16.1–16.13) + Task 14.10 sortable summary
- Plan: `docs/Artifacts/implementation_plan_021_0926.md`
- Execution record: `docs/Artifacts/s16_independent_qa_exec_001_0926.md`
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
Prior H16-01 / 16.R1: CLOSED
Prior M16-01 / 16.R2 / 16.13: CLOSED

New H14.10-01: OPEN
New M14.10-02: OPEN

Blocker 0
High    1
Medium  1

Section 16: HOLD
Task 14.10: HOLD
```

Section 17 remains gated.

---

## 1. Review-range provenance

The supplied baseline `96924ae...` cannot be resolved on the GitHub remote. GitHub returns no commit for that SHA.

The reviewed commit is valid and is branch HEAD. Its actual parent is:

```text
fcae9c0ceb594497d69b90099b21f79f11c7e0a9
    ↓
897b829c215bba7a4b5558f1552bf7088f2b2bc9
```

The actual parent-to-reviewed compare is exactly one commit, with merge-base equal to `fcae9c0...`.

This review therefore evaluates the concrete one-commit implementation delta from the actual parent, while recording the supplied-baseline mismatch as a non-blocking review-metadata correction.

No commit-bound GitHub status or workflow run exists for the reviewed SHA.

---

## 2. Prior finding closure

### H16-01 / 16.R1 — CLOSED

The canonical reconciliation remains correct: posterior zero-reference behavior, `primary_delta=NULL`, ledger genesis null hash, discordance advisory fields, U3 color, deferred Task 7.4, and selected archive-integrity coverage are accurately reconciled in the current plan/execution record.

### M16-01 / 16.R2 / Task 16.13 — CLOSED

The reviewed execution record now marks the four Owner-adjudication conditions as accepted, and the current Owner review request explicitly states that Task 16.R2 / Task 16.13 Owner adjudication has been recorded and accepted.

OpenSpec Task 16.13 is therefore eligible to remain checked complete.

---

## 3. Task 14.10 implementation — positive findings

The reviewed runtime implements a self-contained sortable summary table with:

- ten sortable headers;
- click interaction;
- Enter / Space keyboard activation;
- `aria-sort` state mutation;
- inline vanilla JavaScript only;
- explicit sort values for Theme, Comparison, N, Events, RD, RR, Direction, Practical/U-Grade, and Precision;
- finite-before-empty behavior for numeric unavailable values;
- stable comparator tie-break using the decorated row index;
- U-Grade ordinal prefixing;
- preservation of existing cell markup because rows are re-appended rather than rebuilt.

Independent comparator inspection confirms the implemented numeric logic orders negative/positive RD values numerically and keeps empty values at the bottom in both ascending and descending directions.

The Owner also reports the current dashboard appearance as acceptable.

---

## 4. H14.10-01 — Visual QA run was mutated in place; manifest and screenshot are stale

Severity: HIGH

Task 14.10 and Plan 021 require actual browser interaction QA at 1280x800, including RD and U-Grade sorting, keyboard activation, `aria-sort` updates, layout preservation, and a tracked browser QA artifact/screenshot/viewport record.

The reviewed commit instead modifies this pre-existing visual-run artifact in place:

`evidence_runs/visual_qa_s14/run_20260926_041047/dashboard.html`

while leaving the associated run evidence unchanged.

Git blob comparison from actual parent to reviewed commit:

```text
dashboard.html          CHANGED
dashboard_1280x800.png UNCHANGED
results_manifest.json  UNCHANGED
run_meta.json          UNCHANGED
```

The tracked screenshot visibly represents the prior dashboard state and does not contain the new sort indicators. It also contains prior row/U-Grade content that differs from the reviewed `dashboard.html`.

More importantly, `results_manifest.json` still records the old dashboard hash:

```text
manifest dashboard SHA-256:
f4bba2665f08da77c356c66725705e964dafabb88f01660b1365bee7bfa7d41b

independently recomputed reviewed dashboard SHA-256:
bfac411091fbd237bd63f535370e14d4cf832e76bb12255b95f8f7e9d385cade

MATCH = FALSE
```

This breaks the visual-run provenance contract and makes the tracked screenshot/manifest unsuitable as evidence for Task 14.10.

In addition, the reported `86/86 PASS` Section 10 test extension is static-contract testing: it greps for script/header strings but does not execute browser sorting or assert resulting DOM row order after click/keyboard events.

### Required repair — 14.10.R1

Do not patch an already accepted visual run in place.

Generate a new visual QA run with a new run ID and track, as one coherent artifact set:

- regenerated `dashboard.html`;
- regenerated screenshot(s);
- regenerated `results_manifest.json` with matching dashboard SHA-256;
- regenerated `run_meta.json` / provenance;
- browser interaction evidence at 1280x800.

Browser evidence must verify at minimum:

1. RD ascending row order;
2. RD descending row order;
3. U-Grade ascending ordinal order;
4. U-Grade descending ordinal order;
5. Enter or Space keyboard activation;
6. active header `aria-sort` update and non-active headers reset to `none`;
7. finite RR values sort before N/A in both directions;
8. no horizontal-overflow regression;
9. warning, badges, U3 muted styling, and practical-cell-only coloring remain intact.

Prefer an executable browser test or a documented manual/browser-subagent session that records exact run path, viewport, pre/post row order, and ARIA state.

---

## 5. M14.10-02 — Diagnostics column does not use its explicit machine-readable sort key

Severity: MEDIUM

Plan 021 states that rendered strings should not be parsed for sorting and that each sortable data cell should carry an explicit machine-readable sort key.

The runtime computes:

```r
diag_sort_val <- trimws(row$badges %||% "")
```

but does not use it.

The generated Diagnostics cell is:

```html
<td class='col-diagnostics'>...</td>
```

with no `data-sort-value`.

Independent audit of the tracked reviewed HTML finds 10 cells per row but only 9 `data-sort-value` attributes per row; the missing key is Diagnostics in every row.

The JavaScript therefore falls back to:

```text
cell.textContent.trim()
```

for Diagnostics, which contradicts the explicit machine-readable-key contract and the execution-record claim that each data cell has `data-sort-value`.

### Required repair — 14.10.R2

Render Diagnostics as, for example:

```html
<td class='col-diagnostics' data-sort-value="NORMALIZED_BADGE_TEXT">...</td>
```

using the already computed `diag_sort_val`, HTML-escaped for attribute context.

Add a regression assertion that every sortable column has an explicit sort key in every data row.

---

## 6. Test evidence assessment

Implementer evidence reports:

```text
R regression suite              50/50 PASS
Python ownership + manifest     15/15 PASS
OpenSpec strict validation      VALID
Dashboard QA                    86/86 PASS
Working tree                    clean
```

These are treated as implementer execution evidence.

The Section 10 sortable additions are useful static guards, but they do not currently execute the interaction contract required by Plan 021 / Task 14.10.

No commit-bound CI/status evidence exists for the reviewed SHA.

---

## 7. Final gate

```text
H16-01: CLOSED
M16-01: CLOSED

H14.10-01: OPEN — stale/mutated visual-run evidence; manifest hash mismatch; no valid tracked interaction QA
M14.10-02: OPEN — Diagnostics lacks explicit data-sort-value

Blocker 0
High    1
Medium  1

Section 16: HOLD
Task 14.10: HOLD
Section 17: GATED
```

Expected after 14.10.R1 + 14.10.R2:

```text
Blocker 0
High    0
Medium  0

Task 14.10: PASS / ACCEPT
Section 16: PASS / ACCEPT
```

After those two focused repairs, the final gate should be small and straightforward.