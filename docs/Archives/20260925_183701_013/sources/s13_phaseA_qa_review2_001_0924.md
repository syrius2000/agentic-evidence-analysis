# Section 13 Phase A — Independent Re-QA Review 2

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Baseline:** `d827e8b39148e640ada18fab69356aabcb49adfc`
- **Reviewed commit:** `712baa63e293398e8d2ec39433172db0c4a1ba6a`
- **Original HOLD commit:** `2b474299c631e2a85f920d26ce6b9baff60c0b3d`
- **Scope:** Section 13 Phase A repair verification only (`13.A.R1–R4`)
- **Out of scope:** Section 13.4+
- **Review date:** 2026-09-24 JST
- **Reviewer:** GPT-5.6 Sol
- **Execution policy:** implementer PASS counts treated as claims; R tests were not independently rerun because `Rscript` is unavailable in reviewer runtime.

## Decision

```text
H13A-01: CLOSED
M13A-01: CLOSED
M13A-02: PARTIALLY CLOSED
M13A-03: CLOSED

Blocker: 0
High:    0
Medium:  1 residual

Section 13 Phase A:
HOLD (narrow residual)

Section 13.4+:
DO NOT START YET
```

The original High finding is closed. The remaining issue is a schema/runtime parity gap in the `present=true` delta state.

---

## H13A-01 — CLOSED

The repair now provides:

- centralized `RUN_SCOPE_SUPPORTED_SKILLS`;
- `evidence-decision-review` accepted by `read_run_control()`;
- `complete_evidence_decision_feature_run()`;
- `evidence_feature.json`;
- `results_manifest.json`;
- `run_meta.json`;
- bound `results_manifest_sha256`;
- `read_run_control()` round-trip test;
- `verify_results_manifest()` test;
- no-root-leakage test;
- collision suffix `_2` test.

This closes the original run-lifecycle defect.

---

## M13A-01 — CLOSED

`clustering_feature_keys` is now constrained by JSON Schema to the canonical feature enum.

Runtime also rejects:

- decision/regulatory keys;
- unknown keys;
- duplicate/empty key sets;
- delta keys when `present=false`.

Tests cover `decision_code`, `regulatory_label`, and an arbitrary unknown feature.

The original unconstrained-selector defect is closed.

---

## M13A-02 — PARTIALLY CLOSED

### What is fixed

`delta_dependent` now has Draft-07 conditional state constraints:

- `present=true` requires numeric delta fields;
- `primary_delta > 0`;
- probabilities in `[0,1]`;
- `present=false` requires all delta fields to be `null`.

Runtime additionally enforces the practical-region sum invariant.

The schema also correctly prohibits delta clustering keys when `present=false`.

### Residual parity gap

Runtime requires **all four delta clustering keys** when `present=true`:

```r
if (isTRUE(delta_present)) {
  missing_delta <- setdiff(DELTA_CLUSTERING_KEYS, keys)
  if (length(missing_delta) > 0L) {
    stop("[MISSING_DELTA_CLUSTERING_KEYS] ...")
  }
}
```

But `schemas/evidence-feature-v1.json` does not impose the equivalent requirement.

The root schema only has a conditional for:

```text
present=false
→ clustering_feature_keys limited to core keys
```

There is no corresponding `present=true` constraint requiring:

```text
primary_delta
target_excess
practical_neutral
reference_excess
```

Therefore a payload such as:

```yaml
delta_dependent:
  present: true
  primary_delta: 0.05
  target_excess: 0.8
  practical_neutral: 0.1
  reference_excess: 0.1

clustering_feature_keys:
  - rd_estimate
  - rd_interval_width
  - direction_support
  - resolution_grade
  - rr_mean_is_finite
  - has_zero_reference
  - target_n
  - reference_n
  - quarantine_flag_count
```

is consistent with the current JSON Schema but is rejected by runtime.

That violates the intended schema/runtime atomic contract before Phase B consumes `evidence-feature-v1`.

### Missing negative test

`tests/test_evidence_feature_extract.R` tests:

- `present=true` with null delta values;
- `present=false` with numeric values;
- `present=false` with a delta clustering key;
- `primary_delta <= 0`.

It does **not** test:

```text
present=true + valid delta values + one or more missing delta clustering keys
```

---

## M13A-03 — CLOSED

The execution record now separately reports:

```text
tests/test_evidence_feature_extract.R : 35 PASS / 0 FAIL
tests/test_skill_run_isolation.R      : 73 PASS / 0 FAIL
tests/run_regression_suite.R          : 43/43 PASS
OpenSpec strict                       : valid / issue 0
git diff --check                      : clean
```

These remain implementer claims, but the requested evidence categories are now recorded distinctly and the test sources contain the corresponding lifecycle checks.

No GitHub commit-bound status/workflow run was found for the reviewed commit.

---

# Repair Task

## 13.A.R5 — Bind `present=true` to Complete Delta Clustering Key Set

**Priority:** P0 before 13.4  
**Severity:** Medium  
**Scope:** narrow schema/runtime parity repair

- [ ] Extend `evidence-feature-v1.json` with a `present=true` conditional for `clustering_feature_keys`.
- [ ] Require all four delta keys when `delta_dependent.present=true`.
- [ ] Preserve the existing core/delta canonical enum.
- [ ] Add negative fixture: `present=true` with valid delta values but missing `primary_delta` from `clustering_feature_keys`.
- [ ] Add another negative fixture missing one practical-region key.
- [ ] Verify both JSON Schema and `assert_clustering_feature_keys()` reject the fixtures.
- [ ] Re-run targeted test, run-isolation regression, full regression, OpenSpec strict, and `git diff --check`.

### Suggested Draft-07 shape

One acceptable pattern is:

```json
{
  "if": {
    "properties": {
      "delta_dependent": {
        "properties": {
          "present": { "const": true }
        },
        "required": ["present"]
      }
    },
    "required": ["delta_dependent"]
  },
  "then": {
    "properties": {
      "clustering_feature_keys": {
        "allOf": [
          { "contains": { "const": "primary_delta" } },
          { "contains": { "const": "target_excess" } },
          { "contains": { "const": "practical_neutral" } },
          { "contains": { "const": "reference_excess" } }
        ]
      }
    }
  }
}
```

Draft-07 supports `contains`. An equivalent explicit contract is acceptable.

---

## Final Gate

After `13.A.R5` is independently verified:

```text
expected:
Blocker 0
High    0
Medium  0

Section 13 Phase A:
PASS / ACCEPT

Section 13 Phase B:
13.4 may begin
```
