# Implementation QA Review 001: comparative-dashboard-metric-hierarchy-v1

- **Change ID**: `comparative-dashboard-metric-hierarchy-v1`
- **Branch**: `codex/Gower-PCoA`
- **Reviewed commit**: `a4ea2b6b62273a5019c806aa7f24ed5f08987998`
- **Baseline**: `4fe5aa430d777b2e1235fee68f14d44286f05bbd`
- **Plan baseline**: `07ab0853fe8499509822a323e9b521c3c8399fc3`
- **QA date**: 2026-09-27 JST
- **Gate**: **HOLD**
- **Reason**: non-Safety Markdown table can break because reciprocal label contains unescaped pipe characters.

## 1. Summary

The implementation is broadly aligned with Plan 024 and the approved OpenSpec delta.

Confirmed PASS items include:

- HTML 12-column canonical order.
- E100 and reciprocal RD split into independent cells.
- Safety mapping:
  - `target_excess -> NNH-like`
  - `reference_excess -> NNT-like`
- non-Safety HTML rendering uses `1/|RD|`.
- `SIGN_AMBIGUOUS` and `RD_NEAR_ZERO` suppression.
- U-Grade retained with cell-local practical-region color.
- `primary_delta = null -> NONE / none / achromatic`.
- independent E100 / reciprocal machine sort keys.
- canonical `summary_df` remains exactly 40 fields.
- Gower feature keys do not include E100 / reciprocal fields.
- keyboard sorting / `aria-sort` logic retained.
- Zero-External-Asset tests remain present.
- reviewed commit changes only:
  - `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
  - `tests/test_comparative_dashboard_qa.R`
  - `openspec/changes/comparative-dashboard-metric-hierarchy-v1/tasks.md`
- requested schema / contrast / geometry paths are unchanged.
- `tasks.md` contains 18/18 checked tasks.

Implementer-reported validation:

```text
Rscript tests/test_comparative_dashboard_qa.R
201 Passed, 0 Failed

openspec validate comparative-dashboard-metric-hierarchy-v1 --strict
valid (0 errors)
```

These are accepted as implementer-reported evidence; no GitHub Actions/status record was available for independent execution confirmation.

---

## 2. Findings

### QA024-IMP-H01 — non-Safety Markdown reciprocal label breaks table structure

**Severity**: High  
**Status**: OPEN  
**Gate impact**: Must fix before implementation PASS

Current Markdown rendering uses:

```r
sprintf("1/|RD| ≈ %.1f人", row$reciprocal_absolute_rd)
```

Inside a Markdown table, the `|` characters are column delimiters. Therefore a row such as:

```text
| ... | 1/|RD| ≈ 20.0人 | ... |
```

is parsed as extra columns and no longer preserves the required 12-column semantic structure.

HTML rendering is not affected.

#### Required fix

Escape pipe characters for Markdown only, e.g.:

```r
sprintf("1/\\|RD\\| ≈ %.1f人", row$reciprocal_absolute_rd)
```

Do not change the HTML representation.

#### Required regression test

Generate a non-Safety Markdown report and verify:

- reciprocal cell renders escaped `1/\|RD\|`
- every Markdown data row remains exactly 12 semantic cells
- HTML still renders `1/|RD|`
- no NNT-like / NNH-like wording appears for non-Safety

---

### QA024-IMP-M01 — NOT_INTERPRETABLE suppression lacks direct regression coverage

**Severity**: Medium  
**Status**: OPEN  
**Gate impact**: Recommended fix in same repair

Runtime logic suppresses all non-`STABLE_DIRECTION` reciprocal states, so the implementation appears correct.

However, the test file directly covers:

- `SIGN_AMBIGUOUS`
- `RD_NEAR_ZERO`

but does not directly exercise `NOT_INTERPRETABLE`.

#### Required test

Add a fixture that produces or overrides:

```text
reciprocal_status = NOT_INTERPRETABLE
reciprocal_direction = none
reciprocal_absolute_rd = null
```

Verify:

- display contains `— (NOT_INTERPRETABLE)`
- no NNT-like label
- no NNH-like label
- reciprocal `data-sort-value` is empty / missing

---

### QA024-IMP-L01 — Q2 verifies only the first HTML data row

**Severity**: Low  
**Status**: OPEN  
**Gate impact**: Test-strengthening recommendation

The implementation task requires every data row to emit exactly 12 `<td>` cells.

Current Q2 assertion checks only the first data row.

Because all rows use the same renderer template, runtime risk is low, but the test does not fully match the acceptance wording.

#### Required test strengthening

Iterate over all `<tr data-row-key=...>` rows and assert:

```text
td_count == 12
```

for every row.

---

## 3. Repair Task List

### Required

- [ ] **R1** Fix Markdown-only reciprocal rendering so `1/|RD|` is emitted as escaped Markdown `1/\|RD\|`.
- [ ] **R2** Add non-Safety Markdown regression test proving the generated Markdown table retains exactly 12 semantic columns.
- [ ] **R3** Re-run `Rscript tests/test_comparative_dashboard_qa.R` and obtain 0 failures.
- [ ] **R4** Re-run `openspec validate comparative-dashboard-metric-hierarchy-v1 --strict` and obtain 0 errors.
- [ ] **R5** Confirm schema / contrast / geometry paths remain unchanged.

### Recommended in same repair

- [ ] **R6** Add explicit `NOT_INTERPRETABLE` suppression fixture and assertions.
- [ ] **R7** Strengthen Q2 from first-row-only to all generated HTML data rows.

---

## 4. Re-QA Acceptance Conditions

A differential QA is sufficient after repair.

Expected evidence:

```text
Reviewed commit: <NEW_SHA>
Baseline: a4ea2b6b62273a5019c806aa7f24ed5f08987998

Repair targets:
- QA024-IMP-H01
- QA024-IMP-M01
- QA024-IMP-L01

Validation:
- Rscript tests/test_comparative_dashboard_qa.R: <PASS COUNT>, 0 Failed
- openspec validate comparative-dashboard-metric-hierarchy-v1 --strict: valid (0 errors)
- git diff --check: clean
- schema/contrast/geometry diff: empty
```

Minimum gate requirement is closure of **QA024-IMP-H01**.  
Closing M01 and L01 in the same repair is strongly preferred because both are small test-only hardening changes.

## 5. Gate Position

**Implementation Gate remains HOLD until QA024-IMP-H01 is repaired.**

No redesign is required. The defect is localized to Markdown escaping plus regression coverage.
