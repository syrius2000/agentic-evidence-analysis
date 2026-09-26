# Phase 1 Implementation Review — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `e9806f38759247088f5c532589af2083b07c45ef`  
**Baseline:** `48b48aad2e8f3346dc021dd54bd620695f4e26b6`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Blind-first implementation review / read-only  
**Verdict:** **HOLD — core statistics are promising, but Phase 1 acceptance is not yet satisfied**

---

# 1. Executive Summary

The Phase 1 implementation is substantial and directionally correct.

The following core pieces are present:

- independent Jeffreys Beta-Binomial engine
- zero-reference RR mean divergence guard
- RD / RR / direction support / delta profile
- practical-region support and U-grade
- prior-sensitivity mode
- Pass 0 routing
- Safety SOC/PT adapter
- RWD / Prescription adapters
- comparative schemas
- multi-theme reporting
- self-contained HTML/Markdown output
- dedicated tests

The statistical core is much closer to the OpenSpec than a superficial implementation.

However, the implementation currently has several **contract-level defects** that prevent Phase 1 from being considered complete.

### Severity summary

- **Blocker:** 5
- **High:** 8
- **Medium:** 5

The strongest positive conclusion is:

> The Jeffreys/RD/RR core can be repaired without architectural redesign.

The strongest negative conclusion is:

> Several tasks are marked `[x]` although the implementation or executable evidence does not satisfy the stated acceptance criterion.

---

# 2. Overall Phase Gate

| Area | Status |
|---|---|
| Independent Beta-Binomial mathematics | **Mostly PASS** |
| Zero-cell semantics | **PASS with QA strengthening needed** |
| Common contrast semantics | **PARTIAL** |
| JSON schemas | **FAIL / inconsistent** |
| Pass 0 routing | **FAIL for non-Phase-1 designs** |
| Safety aggregation | **PARTIAL** |
| Multi-theme reporting | **PARTIAL** |
| Run isolation / provenance | **FAIL** |
| Canonical regression registration | **FAIL** |
| OpenSpec task completion evidence | **FAIL / overstated** |

### Current verdict

\[
\boxed{\text{Phase 1 HOLD}}
\]

A focused repair commit should be enough to reach GO.

---

# 3. Blocker Findings

## B1 — `comparative-draws-v1` schema contradicts the default ephemeral-draw implementation

### Schema

`schemas/comparative-draws-v1.json` requires:

```text
target_draws
reference_draws
```

as arrays.

### Implementation

`run_independent_beta_binomial()` constructs:

```r
runtime_draws <- list(
  ...
  target_draws = if (persist_raw_draws) target_draws else NULL,
  reference_draws = if (persist_raw_draws) reference_draws else NULL,
  ...
)
```

The default is:

```r
persist_raw_draws = FALSE
```

Therefore the default returned object does **not** conform to its own schema.

### Why tests missed it

`tests/test_comparative_schemas.R` does not actually validate the runtime object against `schemas/comparative-draws-v1.json`.

### Required fix

Choose one contract.

Recommended:

```json
"target_draws": {
  "type": ["array", "null"]
},
"reference_draws": {
  "type": ["array", "null"]
}
```

and add:

```text
draw_storage = ephemeral | persisted
```

Alternatively do not return a schema-labeled draw object after disposal.

### Acceptance test

Actually validate against the JSON Schema using the repository-approved validator.

---

## B2 — Written `comparative_evidence.json` does not conform to `comparative-evidence-v1`

### Schema expects

Top-level fields such as:

```text
schema_version
inferential_semantics
target_cohort
reference_cohort
risk_difference
relative_risk
...
```

### Reporter writes

```r
json_deliverable <- list(
  schema_version = "comparative-evidence-v1",
  run_timestamp = ...,
  domain = domain,
  primary_delta = primary_delta,
  contrasts = evidence_list
)
```

This is a **batch wrapper**, not a `comparative-evidence-v1` object.

Therefore the output claims:

```text
schema_version = comparative-evidence-v1
```

while structurally violating that schema.

### Required fix

Define a second schema, e.g.:

```text
comparative-evidence-batch-v1
```

with:

```yaml
schema_version
run_meta
domain
primary_delta
contrasts:
  <contrast_id>: comparative-evidence-v1
```

Or write one valid `comparative-evidence-v1` object per contrast.

### Severity

**Blocker**, because Task 4.7 claims schema-validated canonical output.

---

## B3 — `vcd-categorical-reporting` violates `evidence-run-layout`

### Specification

All statistical skills must write under:

```text
evidence_runs/<skill_slug>/run_<canonical_id>[_N]/
```

with:

- run isolation
- collision handling
- `run_meta.json`
- provenance binding

### Implementation

`generate_comparative_report()`:

```r
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
```

then writes files directly into `output_dir`.

It does not:

- create canonical run directory
- call shared run-scope helper
- create `run_meta.json`
- bind path-schema version
- create input hash provenance
- enforce collision-safe run reservation

### Test problem

`tests/test_vcd_categorical_reporting.R` intentionally passes a temporary directory and only checks that files exist there.

Thus the test validates the non-compliant behavior.

### Required fix

Use the existing run-scope infrastructure.

Expected:

```text
evidence_runs/vcd_categorical_reporting/run_<id>/
  run_meta.json
  comparative_evidence.json
  comparative_summary.csv
  comparative_report.md
  dashboard.html
```

Add collision and metadata tests.

---

## B4 — New Phase 1 tests are not registered in the canonical regression suite

`tests/run_regression_suite.R` still contains the existing 31 official tests.

It does **not** include:

```text
tests/test_comparative_schemas.R
tests/test_domain_invariance.R
tests/test_independent_beta_binomial.R
tests/test_pass0_routing.R
tests/test_practical_difference.R
tests/test_safety_adapter.R
tests/test_vcd_categorical_reporting.R
```

### Consequence

The canonical command:

```text
Rscript tests/run_regression_suite.R
```

can pass while every new Phase 1 test is broken or not executed.

This directly contradicts the updated deterministic-dependency OpenSpec.

### Required fix

Register all canonical Phase 1 tests in `official_tests`.

Then execute the full suite.

---

## B5 — Pass 0 routing assigns wrong inferential semantics to matched-pair and person-time designs

Current code:

```r
} else if (design %in% c("matched_pair", "matched_set", "iptw", "person_time")) {
  target_engine_slug <- "comparative-design-analysis"
  ...
  inferential_semantics <- "bootstrap"
}
```

But the approved design says:

| Design | Semantics |
|---|---|
| matched_pair | **posterior** |
| matched_set | bootstrap |
| IPTW | bootstrap |
| person_time | **posterior** |

Therefore Pass 0 currently misroutes semantic metadata for two future designs.

It also generates module names by:

```r
sprintf(".agents/shared/%s_engine.R", design)
```

which does not match planned files such as:

```text
matched_set_inference.R
iptw_inference.R
person_time_rate.R
```

### Required fix

Use an explicit routing table, not string construction.

Although these engines are Phase 2, **Pass 0 was marked complete in Phase 1**, so the routing contract must already be correct.

---

# 4. High Findings

## H1 — `effective_sample_size = S` confuses Monte-Carlo draws with statistical ESS

Current code:

```r
precision_metrics = list(
  ...
  effective_sample_size = S
)
```

where:

```text
S = number of uncertainty draws
```

For the independent posterior engine, `S=4000` is a Monte-Carlo sample count.

It is **not**:

- patient sample size
- information ESS
- IPTW Kish ESS

### Required fix

Use:

```text
monte_carlo_draws = S
```

and:

```text
effective_sample_size = NULL
```

for independent Beta-Binomial.

Reserve statistical ESS for design-aware weighting diagnostics.

---

## H2 — Pass 0 treats every numeric column as a count candidate

`inspect_tabular_input()` does:

```r
count_cols <- names(df)[vapply(df, is.numeric, logical(1L))]
```

then excludes only a narrow set of known ID/weight/person-time columns.

In actual RWD data, numeric variables may include:

- age
- BMI
- lab values
- baseline score
- dose
- calendar year

A non-integer age/lab field can set:

```text
non_integer_counts.detected = TRUE
```

and cause an independent binary analysis to fail even though the actual event/denominator columns are valid integers.

### Required fix

Count validation must be schema/config-driven.

Only declared event/denominator count fields should receive integer-count validation.

---

## H3 — Safety “study-specific output” task is marked complete but not implemented

Task 5.8 is `[x]`:

> Support study-specific output stratification as canonical, designating multi-study pooled aggregations as `descriptive_pooled`.

`aggregate_safety_data()` accepts:

```r
study_col = NULL
```

but never uses it.

There is no:

- study-stratified result
- pooled result type
- `descriptive_pooled` metadata

### Required fix

Either implement study-stratified hierarchy now, or uncheck/defer Task 5.8.

---

## H4 — MedDRA provenance task is only partially implemented

Task 5.2 says:

> Require MedDRA version provenance and dictionary release metadata.

Implementation only checks:

```r
meddra_metadata$version
```

It does not require release date/build or equivalent release metadata.

### Required fix

Define exact minimum provenance fields, then make code/test match the OpenSpec.

---

## H5 — Visual encoding does not implement the approved hue × resolution contract

The approved design says:

- **hue** = dominant practical region
- **intensity/saturation** = U-grade

Current report code colors by **U-grade only**.

It does not distinguish:

```text
target_excess
practical_neutral
reference_excess
```

### Required fix

Persist dominant region in summary output, then map region to hue and U-grade to intensity.

---

## H6 — “Golden” regression tests do not test golden numerical values

`tests/test_independent_beta_binomial.R` labels seven cases as Golden Regression Cases but asserts mainly:

- RD is finite
- zero-reference mean is NULL
- badges exist

It does **not** assert known expected values/tolerances for:

- target posterior median
- reference posterior median
- RD median
- RD interval
- direction probability
- RR median/quantiles

### Required fix

Add numerical reference assertions with tolerances.

For the canonical `3/100 vs 0/100` case, expected approximate behavior should be asserted rather than only checking finiteness.

---

## H7 — Prior-sensitivity `robust` boolean uses an undocumented hard-coded threshold

Current implementation:

```r
robust <- (dir_diff < 0.15) && (grade_match || is.null(primary_delta))
```

The `0.15` threshold is not defined in OpenSpec/policy.

### Required fix

Prefer recording continuous sensitivity deltas.

If a boolean `robust` is desired, move the threshold into a versioned policy.

---

## H8 — Practical-difference policy task completion is overstated

Task 7.4 is `[x]`:

> Implement versioned departmental policy mode.

There is a policy loader, but `pass0-config-v1.json` only permits:

```text
mode = none | fixed_delta
```

There is no policy mode in the configuration schema and no demonstrated end-to-end integration.

Likewise Task 7.7 claims cutoff validation and recommendations, while the test only verifies that the simulation returns a result structure.

### Required fix

Implement `mode = policy` end-to-end or uncheck/defer Task 7.4.

Leave Task 7.7 incomplete until an actual validation artifact/recommendation exists.

---

# 5. Medium Findings

## M1 — The batch output needs its own schema

Recommended:

```text
comparative-evidence-v1
comparative-evidence-batch-v1
```

This will support multi-theme/multi-group output cleanly.

---

## M2 — `practical_region_support` should include its own inferential semantics

For audit clarity:

```yaml
practical_region_support:
  inferential_semantics: posterior | bootstrap
```

is preferable.

---

## M3 — Default delta profile is still embedded in code

`compute_comparative_contrasts()` defaults to:

```r
delta_thresholds = c(0.01, 0.02, 0.05, 0.10)
```

This grid can remain a convenience grid, but it should be configuration-driven, explicitly non-normative, and recorded in provenance.

---

## M4 — Same seed is reset for every theme/contrast

`generate_comparative_report()` calls each comparison with the same seed.

This is deterministic but creates correlated Monte-Carlo error across comparisons.

Prefer a deterministic contrast-specific seed derived from the run seed and contrast ID.

---

## M5 — Reciprocal RD zero-crossing test should include boundary zero

Current Safety code checks:

```r
rd_lower < 0 && rd_upper > 0
```

Prefer:

```r
rd_lower <= 0 && rd_upper >= 0
```

so intervals touching zero are not treated as stable reciprocal-RD cases.

---

# 6. Test and Verification Gaps

## 6.1 No GitHub CI evidence

For commit:

```text
e9806f38759247088f5c532589af2083b07c45ef
```

GitHub reports:

- no workflow runs
- no combined status checks

Therefore this review cannot independently verify the claimed local PASS results.

---

## 6.2 Strict OpenSpec validation is claimed but not committed as evidence

`implementation_plan_001_0923.md` states strict validation passed, but no validation JSON/log artifact was found in the reviewed commit.

For strict acceptance evidence, persist validation output or CI evidence.

---

## 6.3 Schema tests are structural assertions, not actual schema validation

`tests/test_comparative_schemas.R` does not load and validate against the JSON Schema files.

This is precisely why B1/B2 escaped.

Add real schema-validation tests.

---

# 7. What Is Already Good

The following implementation choices should be preserved:

- exact integer count guards
- explicit `EMPTY_DENOMINATOR`
- zero-reference theoretical RR mean suppression
- deterministic seed support
- posterior-vs-bootstrap terminology in common contrast engine
- `primary_delta = NULL` disabling practical-region classification
- delta-profile monotonic logic
- SOC/PT subject deduplication
- domain-invariance test concept
- raw-draw ephemeral default
- narrative guards against equivalence and causal overclaim
- external-asset-free HTML intent

---

# 8. Recommended Repair Order

## Repair 1 — Contract integrity

1. fix `comparative-draws-v1` ephemeral/null schema
2. define batch evidence schema
3. add actual JSON Schema validation
4. replace `effective_sample_size = S`

## Repair 2 — Run/provenance integration

5. integrate `run_scope.R`
6. generate `run_meta.json`
7. add run-directory isolation/collision tests

## Repair 3 — Pass 0 correctness

8. explicit route registry
9. matched-pair/person-time posterior semantics
10. declared count-column validation only

## Repair 4 — Acceptance tests

11. register all new tests in `run_regression_suite.R`
12. add true numerical golden benchmarks
13. add ZERO_BOTH explicit RR-mean assertion
14. persist strict OpenSpec / regression evidence

## Repair 5 — Safety/reporting completion

15. implement or defer study-specific Safety output
16. enforce MedDRA provenance contract
17. fix practical-region hue × U-grade intensity
18. integrate/defer policy mode
19. remove hidden prior-sensitivity threshold

---

# 9. Suggested Acceptance Gate After Repair

Phase 1 should be marked complete only when all of these pass:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
Rscript tests/run_regression_suite.R
Rscript tests/test_comparative_schemas.R
Rscript tests/test_independent_beta_binomial.R
Rscript tests/test_pass0_routing.R
Rscript tests/test_safety_adapter.R
Rscript tests/test_domain_invariance.R
Rscript tests/test_practical_difference.R
Rscript tests/test_vcd_categorical_reporting.R
git diff --check
```

and the canonical regression registry includes the new test files.

---

# 10. Final Verdict

## Statistical core

**PROMISING / NEAR PASS**

The Jeffreys binary engine, zero-cell treatment, RD/RR generation, practical-region logic, and domain adapters show good implementation direction.

## Phase 1 as a complete deliverable

**HOLD**

The largest blockers are contract and integration defects:

\[
\boxed{
\text{Schema validity}
+
\text{Run provenance}
+
\text{Routing correctness}
+
\text{Canonical test registration}
}
\]

Fixing these should be the next commit before moving to Phase 2.

## Recommended next action

Create a focused **Phase 1 repair commit only**.

Do not begin 1:1 matching / IPTW / person-time implementation until this Phase 1 QA gate is clean.
