# Phase 2 Section 10 IPTW — QA Review 4 / Post-Acceptance Hardening Plan

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Baseline:** `cee26ff9f0324eba2030372d9d8f22324bdfdbf7`  
**Reviewed commit:** `4829cb0b64adb7f1a5130fe6018ce295a0b1767b`  
**Review date:** 2026-09-24 JST  
**QA Gate:** **PASS / ACCEPT**  
**Residual findings:** Blocker 0 / High 0 / Medium 2  
**Policy:** residual tasks are post-acceptance hardening and SHALL NOT reopen Section 10 unless a new High/Blocker is discovered.

---

## 1. Acceptance Summary

Repair #2 closes the prior acceptance-blocking findings.

Confirmed by independent code/schema inspection:

- report-side raw-count provenance mismatch is fail-fast with `EVIDENCE_REPORT_PROVENANCE_MISMATCH`;
- IPTW raw descriptive N/events and ESS are separated in report output;
- Fisher exact compatibility is suppressed by default for design-aware IPTW overrides;
- same-source IPTW report integration fixture replaces the prior mismatched-source fixture;
- evidence and draw schemas now require the main IPTW provenance fields:
  - `iptw_mode`
  - `truncation`
  - `att_scaling_mode`
  - `propensity_model`
  - `propensity_score_boundary_policy`
  - `bootstrap_clipping_diagnostics`
  - `max_failure_rate`
- pure-R schema validator now evaluates `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, and rejects non-finite values;
- bootstrap PS-clipping diagnostics are aggregated and emitted in evidence/draw metadata;
- Repair #2 task IDs 10.R12–10.R19 are documented consistently;
- `max_failure_rate` default is consistently 0.05;
- small-cell masking remains explicitly deferred and is not falsely claimed as implemented.

Recorded execution evidence reports:

- `tests/test_iptw_inference.R`: 69 PASS / 0 FAIL
- `tests/test_comparative_schemas.R`: 71 PASS / 0 FAIL
- `tests/test_vcd_categorical_reporting.R`: 35 PASS / 0 FAIL
- targeted total: 175 PASS / 0 FAIL
- regression suite: 41/41 PASS
- OpenSpec strict validation: valid / 0 issues
- `git diff --check`: clean

GitHub has no commit-bound workflow/status evidence for this commit, so the execution results above are implementation-record evidence rather than independently reproduced CI evidence.

---

# 2. Residual Finding M4-01 — IPTW Schema Diagnostic Contract Is Still Looser Than Runtime

**Severity:** MEDIUM  
**Gate impact:** Non-blocking  
**Area:** `comparative-evidence-v1.json`, `comparative-draws-v1.json`, schema tests

## 2.1 PS boundary upper limit differs from runtime

Runtime validation requires:

```text
0 < lower < upper < 1
```

Current schema uses:

```json
"upper": {
  "type": "number",
  "exclusiveMinimum": 0,
  "maximum": 1
}
```

Therefore `upper = 1` passes schema although runtime rejects it.

### Required correction

In both evidence and draws schemas:

```json
"upper": {
  "type": "number",
  "exclusiveMinimum": 0,
  "exclusiveMaximum": 1
}
```

Add explicit negative test with **exactly `upper = 1`**.

---

## 2.2 Raw/effective positivity summaries are emitted but not strictly required

Runtime emits:

```text
positivity.target_ps
positivity.reference_ps
positivity.raw_target_ps
positivity.raw_reference_ps

positivity.common_support.min
positivity.common_support.max
positivity.common_support.has_overlap
positivity.common_support.effective_min
positivity.common_support.effective_max
positivity.common_support.effective_has_overlap
```

OpenSpec states that raw and effective PS summaries SHALL be preserved.

Current evidence schema requires only:

```text
target_ps
reference_ps
common_support
```

and the PS summary objects themselves have no required internal fields.

A malformed payload can therefore remove raw PS summaries or provide an empty PS summary object and still validate.

### Required correction

Define a reusable PS-summary object contract:

```json
{
  "type": "object",
  "required": ["min", "q25", "median", "mean", "q75", "max"],
  "properties": {
    "min":    { "type": "number", "minimum": 0, "maximum": 1 },
    "q25":    { "type": "number", "minimum": 0, "maximum": 1 },
    "median": { "type": "number", "minimum": 0, "maximum": 1 },
    "mean":   { "type": "number", "minimum": 0, "maximum": 1 },
    "q75":    { "type": "number", "minimum": 0, "maximum": 1 },
    "max":    { "type": "number", "minimum": 0, "maximum": 1 }
  }
}
```

Require under `positivity`:

```text
target_ps
reference_ps
raw_target_ps
raw_reference_ps
common_support
```

Require under `common_support`:

```text
min
max
has_overlap
effective_min
effective_max
effective_has_overlap
```

All PS support bounds SHALL be constrained to `[0,1]`.

### Required tests

Negative fixtures:

1. remove `raw_target_ps`;
2. remove `raw_reference_ps`;
3. set `target_ps = {}`;
4. remove `effective_has_overlap`;
5. set a PS summary value to `1.1`;
6. set boundary `upper = 1`.

Expected result: all invalid.

---

# 3. Residual Finding M4-02 — Batch 011 Archive Summary Contains Historical Naming/Method Errors

**Severity:** MEDIUM documentation accuracy  
**Gate impact:** Non-blocking  
**Area:** `docs/Archives/archived_summary_011_0924.md`

The archived source files can remain immutable. The **summary document** should be corrected because it is intended as the navigation/traceability layer.

## 3.1 Section 9 method wording

Current summary states approximately:

```text
1:k matched sets conditional logistic regression and atomic bootstrap
```

Section 9 canonical implementation is instead:

```text
ATT set-weighted matched-set estimator
+
atomic matched-set cluster bootstrap
```

It is not a conditional-logistic-regression implementation.

### Required correction

Replace the Section 9 summary wording with:

```text
1:k matched-set ATT set-weighted inference and atomic matched-set cluster bootstrap
```

or equivalent wording consistent with frozen OpenSpec.

---

## 3.2 Historical implementation filenames

Current summary references:

```text
.agents/shared/matched_pair_inference.R
tests/test_matched_pair_inference.R
```

Canonical repository files are:

```text
.agents/shared/matched_pair_dirichlet.R
tests/test_matched_pair_dirichlet.R
```

### Required correction

Update only `archived_summary_011_0924.md`.

Do not rewrite archived source artifacts solely to normalize historical wording.

---

# 4. Post-Acceptance Tasks

## 10.R20 — Tighten IPTW Positivity/Boundary Schema

**Priority:** P1  
**Gate:** post-acceptance

### Files

- `schemas/comparative-evidence-v1.json`
- `schemas/comparative-draws-v1.json`
- `tests/test_comparative_schemas.R`

### Tasks

- [ ] Change PS boundary `upper` from `maximum: 1` to `exclusiveMaximum: 1` in evidence schema.
- [ ] Apply the same constraint in draws schema.
- [ ] Add negative test for `upper = 1`.
- [ ] Require `raw_target_ps` and `raw_reference_ps` in evidence positivity metadata.
- [ ] Require internal PS summary fields `min/q25/median/mean/q75/max`.
- [ ] Require `effective_min`, `effective_max`, `effective_has_overlap` in `common_support`.
- [ ] Add value-range tests for raw/effective PS summary values.
- [ ] Confirm runtime-generated evidence still validates.
- [ ] Confirm runtime-generated draws still validate.

### Acceptance Criteria

```text
runtime-valid PS boundary ⇒ schema-valid
runtime-invalid upper=1 ⇒ schema-invalid
missing raw/effective positivity provenance ⇒ schema-invalid
```

---

## 10.R21 — Correct Batch 011 Archive Summary

**Priority:** P2  
**Gate:** post-acceptance documentation cleanup

### File

- `docs/Archives/archived_summary_011_0924.md`

### Tasks

- [ ] Remove the inaccurate Section 9 “conditional logistic regression” wording.
- [ ] Replace it with ATT set-weighted matched-set estimator / atomic cluster bootstrap terminology.
- [ ] Replace `.agents/shared/matched_pair_inference.R` with `.agents/shared/matched_pair_dirichlet.R`.
- [ ] Replace `tests/test_matched_pair_inference.R` with `tests/test_matched_pair_dirichlet.R`.
- [ ] Search the summary for other renamed/nonexistent canonical paths.
- [ ] Do not modify archived source documents unless a separate archival-integrity decision requires it.

### Acceptance Criteria

All implementation/test paths in the archive summary resolve to canonical repository paths, and Section 9 method wording matches frozen OpenSpec semantics.

---

## 10.R22 — Post-Acceptance Verification

**Priority:** P1

After R20/R21:

```bash
Rscript tests/test_comparative_schemas.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Also perform static checks:

```text
PS boundary upper=1 rejected by schema
raw/effective PS summaries required
Batch 011 summary contains no conditional-logistic claim for Section 9
Batch 011 canonical matched-pair paths resolve
```

Record the execution results in the next implementation execution note.

---

# 5. Final QA Decision

```text
Phase 2 Section 10 — IPTW Engine & Reporting

Reviewed commit:
4829cb0b64adb7f1a5130fe6018ce295a0b1767b

Acceptance Gate:
PASS / ACCEPT

Blocker: 0
High:    0
Medium:  2 (non-blocking, post-acceptance hardening)
```

The prior HOLD findings are considered closed. Section 10 may be frozen and work may proceed to Section 11, while 10.R20–10.R22 are tracked as non-blocking hardening/documentation cleanup.
