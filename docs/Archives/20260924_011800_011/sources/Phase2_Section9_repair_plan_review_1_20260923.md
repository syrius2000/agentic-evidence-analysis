# Phase 2 Section 9 Repair Plan — Independent Plan Review

**Source plan:** `implementation_plan_006_0923`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Baseline HEAD:** `51f846b8ea8db7604156fc1b1a65b3a15310773b`  
**Review date:** 2026-09-23 (JST)  
**Review type:** Pre-implementation Plan Gate  
**Verdict:** **HOLD — plan is substantially correct, but four statistical/contract decisions must be specified before implementation**

## 1. Executive Summary

The repair plan correctly incorporates almost all findings from the preceding Section 9 code review:

- zero-variance SMD is no longer automatically mapped to 0;
- raw descriptive control counts are separated conceptually from the ATT-weighted reference risk;
- zero-reference RR is to be suppressed rather than made artificially finite;
- ATT weighting is to be used for control-side SMD variance;
- misleading `smd_unmatched` is removed;
- subject identity is introduced to validate no-replacement matching;
- `estimand = ATT` and fixed-matched-set bootstrap scope become machine-readable;
- schemas, SKILL documentation, tests, canonical regression, strict OpenSpec validation and `git diff --check` are included.

This is the correct repair direction.

However, implementation should not begin until four remaining ambiguities are fixed in the plan.

---

## 2. Findings already well addressed

### B-01 Zero-variance SMD

The plan explicitly distinguishes:

```text
zero variance + zero mean difference
  -> SMD = 0

zero variance + nonzero mean difference
  -> SMD = null
  -> ZERO_VARIANCE_NONZERO_DIFFERENCE
```

This directly repairs the prior false-perfect-balance failure.

**Plan status: PASS**

### B-02 Raw counts vs ATT-weighted risk

The plan recognizes that raw descriptive counts and ATT-weighted counterfactual risk are different quantities and introduces `estimate_semantics = "att_set_weighted_risk"`.

**Plan direction: PASS**, but schema details remain incomplete (see H-03 below).

### B-03 Zero-reference RR

The plan correctly rejects the previous `1e-15` artificial-finite-RR behavior for the case where the observed reference risk is zero.

**Plan direction: PASS**, but partial undefined bootstrap replicates remain unspecified (see H-01).

### H-01 ATT-weighted balance

The plan correctly requires control-side SMD variance to use ATT weights proportional to `1/k_j`.

**Plan direction: PASS**, but exact weighted variance definition remains unspecified (see H-02).

### H-02 misleading pre-match SMD

Removing `smd_unmatched` from a matched-only engine is the cleanest Phase 2 choice.

**Plan status: PASS**

### H-03 no-replacement validation

Requiring subject identity is the correct way to verify that the same control is not reused across matched sets.

**Plan direction: PASS**, subject to making `subject_id_col` mandatory rather than merely optional.

### H-04/H-05 estimand and bootstrap scope

The plan correctly adds:

```text
estimand = ATT
bootstrap_scope = conditional_on_fixed_matched_sets
```

and documents that the bootstrap does not capture uncertainty from reconstructing the match itself.

**Plan status: PASS**

---

# 3. HIGH H-01 — Partial zero-denominator bootstrap RR is still undefined in the plan

The plan covers the case:

```text
observed reference risk = 0
```

and proposes complete RR suppression.

It does not specify what happens when:

```text
observed reference risk > 0
```

but one or more bootstrap replicates have:

```text
p_R* = 0.
```

That case is common in sparse matched-set data and was explicitly identified in the previous review.

Before implementation, choose a governed policy.

Recommended metadata:

```yaml
rr_bootstrap_diagnostics:
  defined_replicates: <integer>
  undefined_replicates: <integer>
  defined_fraction: <number>
```

Then choose one rule explicitly:

### Conservative option

If any bootstrap replicate is undefined:

```text
RR percentile interval = null
```

and retain RD as the stable primary contrast.

### Threshold option

Compute the RR interval only if a prespecified valid-replicate fraction is met.

If this option is chosen, the threshold must be specified in OpenSpec/configuration, not invented inside code.

Do not silently discard zero-denominator replicates without recording their fraction.

**Severity: HIGH — unresolved inferential contract**

---

# 4. HIGH H-02 — “Use ATT-weighted control variance” needs an exact formula

The plan says:

```text
Use ATT weights (1/k_j) for control variance
```

but weighted variance is not uniquely defined unless the normalization and finite-sample correction are specified.

For a balance diagnostic, a simple deterministic convention is recommended.

Define treated weights:

\[
w_{Tj}=1
\]

and control weights:

\[
w_{Rj\ell}=1/k_j.
\]

Both groups then have total analysis weight \(J\).

Recommended weighted means:

\[
\bar X_T =
\frac{\sum_j w_{Tj}X_{Tj}}
     {\sum_j w_{Tj}}
\]

\[
\bar X_R =
\frac{\sum_{j,\ell} w_{Rj\ell}X_{Rj\ell}}
     {\sum_{j,\ell} w_{Rj\ell}}.
\]

Recommended SMD diagnostic variances as weighted second central moments:

\[
s_T^2 =
\frac{\sum_j w_{Tj}(X_{Tj}-\bar X_T)^2}
     {\sum_j w_{Tj}}
\]

\[
s_R^2 =
\frac{\sum_{j,\ell} w_{Rj\ell}(X_{Rj\ell}-\bar X_R)^2}
     {\sum_{j,\ell} w_{Rj\ell}}.
\]

Then:

\[
s_{pooled} =
\sqrt{\frac{s_T^2+s_R^2}{2}},
\qquad
SMD =
\frac{\bar X_T-\bar X_R}{s_{pooled}}.
\]

Other conventions can be used, but **one formula must be normative in the plan/OpenSpec before coding**.

This is particularly important for binary covariates and variable-ratio sets, where different weighting/variance conventions can produce materially different SMDs.

**Severity: HIGH — numerical contract incomplete**

---

# 5. HIGH H-03 — Raw-count / ATT-risk schema change is not fully reflected in the Proposed Schema section

The key decision section says:

```text
raw_events
raw_total
estimate_semantics = att_set_weighted_risk
```

but the schema modification section only lists:

```text
matched_set.estimand
matched_set.bootstrap_scope
SMD status
remove smd_unmatched
```

It does not explicitly add the raw-count separation or `estimate_semantics`.

That is a planning inconsistency.

Before implementation, specify the exact schema location.

Recommended shape:

```yaml
reference_cohort:
  estimate:
    value: <ATT-weighted risk>
    source: observed_sample_estimate
  estimate_semantics: att_set_weighted_risk

matched_set:
  raw_reference_counts:
    events: <integer>
    total: <integer>
```

For symmetry, consider:

```yaml
matched_set:
  raw_target_counts:
    events: ...
    total: ...
```

even though treated weights are all 1 in this design.

Also specify whether the generic `reference_cohort.events` and `reference_cohort.total` remain populated. If they remain, downstream users can still infer the wrong denominator. The safest design is either:

1. move raw matched counts entirely into `matched_set.raw_*_counts`; or
2. clearly rename/annotate generic cohort counts.

**Severity: HIGH — schema/output contract incomplete**

---

# 6. HIGH H-04 — Active OpenSpec changes are not listed as a repair target

The plan metadata points to:

```text
openspec/changes/comparative-evidence-reporting-v3/
```

and the verification plan includes strict validation.

However, the Proposed Changes section does not list modifications to:

```text
specs/comparative-design-inference/spec.md
tasks.md
design.md
```

The repair changes statistical semantics, not only code:

- zero-reference bootstrap RR;
- ATT-weighted SMD;
- zero-variance SMD status;
- no-replacement subject identity;
- conditional fixed-matched-set bootstrap scope;
- raw descriptive vs ATT-weighted risk separation.

These should be normative OpenSpec requirements before implementation.

Recommended:

```text
[MODIFY] comparative-design-inference/spec.md
[MODIFY] design.md
[MODIFY] tasks.md
```

For `tasks.md`, either:

- reopen affected Section 9 tasks; or
- add explicit repair tasks such as 9.7–9.12.

Do not leave Tasks 9.1–9.6 appearing fully complete while the accepted contract is being materially repaired.

**Severity: HIGH — governance/specification gap**

---

# 7. MEDIUM M-01 — `subject_id_col` should be required for the no-replacement engine

The plan says:

```text
Add subject_id_col validation
```

but does not state whether the parameter is mandatory.

If the engine emits:

```yaml
replacement: false
```

then subject identity must be verifiable.

Recommended contract:

```text
subject_id_col is required for 1:k matched-set inference
```

and validate:

- no missing subject ID;
- no duplicate subject row;
- treated subject appears in one set only;
- control subject appears in one set only.

If optional input must be retained for compatibility, then the engine must not claim verified `replacement=false`; it should record validation status separately.

---

# 8. MEDIUM M-02 — `bootstrap_scope` should also be present in draw metadata

The evidence schema is planned to contain bootstrap scope, but the draws schema proposal mentions only:

```text
matched_set_metadata.estimand
```

For a portable uncertainty object, recommend:

```yaml
matched_set_metadata:
  estimand: ATT
  bootstrap_scope: conditional_on_fixed_matched_sets
  rematching_within_replicate: false
```

This prevents a detached draws object from losing its inferential scope.

---

# 9. MEDIUM M-03 — SMD schema needs explicit null/status contract

The plan says “add SMD status” but should explicitly change:

```text
smd_matched
```

from:

```json
"type": "number"
```

to:

```json
"type": ["number", "null"]
```

and define an enum such as:

```text
OK
ZERO_VARIANCE_ZERO_DIFFERENCE
ZERO_VARIANCE_NONZERO_DIFFERENCE
```

If `ZERO_VARIANCE_ZERO_DIFFERENCE` returns 0, retaining a status is still useful for provenance.

---

# 10. MEDIUM M-04 — Runtime argument validation from Review #6 is absent

The prior review also identified validation gaps for:

```text
caliper
discarded_target
discarded_reference
num_draws
seed
```

These are not included in the repair plan.

Add fail-fast tests for:

- scalar;
- finite;
- non-negative;
- integer where required;
- `seed=NULL` serializes as JSON null.

This is lower priority than the statistical contract issues, but should be included while Section 9 is being repaired.

---

# 11. Test plan additions required

The listed tests are directionally good, but add the following explicit cases.

## T1 — Constant equal covariate

```text
treated = 1,1,1
controls = 1,1,...
```

Expected:

```text
smd = 0
status = ZERO_VARIANCE_ZERO_DIFFERENCE
```

## T2 — Complete separation

```text
treated = 1,1,1
controls = 0,0,...
```

Expected:

```text
smd = null
status = ZERO_VARIANCE_NONZERO_DIFFERENCE
```

## T3 — Variable-ratio weighted variance

Use 1:1 / 1:2 / 1:4 sets where raw and ATT-weighted control variances differ.

Assert the hand-calculated weighted SMD.

## T4 — Raw counts vs ATT risk

Use the existing fixture:

```text
raw control risk = 2/6
ATT-weighted risk = 0.5
```

Assert that the output does not imply equality between them.

## T5 — Observed zero-reference RR

Assert:

```text
estimate = null
interval = null
mean = null
mean_is_finite = false
diagnostic = ZERO_REFERENCE_RISK
```

## T6 — Partial undefined RR bootstrap replicates

Create data where the observed reference risk is positive but some set-bootstrap samples contain no reference events.

Assert the chosen governed policy and replicate counts.

## T7 — Subject reuse

Use the same control subject in two sets.

Expected fail-fast.

## T8 — Metadata/schema

Assert:

```text
estimand = ATT
bootstrap_scope = conditional_on_fixed_matched_sets
rematching_within_replicate = false
```

in both evidence and draws metadata.

## T9 — Runtime metadata validation

Invalid `caliper`, discard counts, draw count and seed behavior.

---

# 12. Plan Gate

## What is already good enough to freeze

Do not redesign:

```text
ATT observed-sample estimator
atomic set resampling
bootstrap percentile interval semantics
bootstrap support-fraction terminology
```

## What must be edited before implementation

1. define partial zero-denominator RR replicate policy;
2. write exact ATT-weighted SMD variance formula;
3. make raw-count vs ATT-risk schema representation explicit;
4. add OpenSpec/design/tasks repair changes.

Recommended additional cleanup:

5. require subject identity;
6. add bootstrap scope to draws;
7. specify SMD null/status schema;
8. include runtime argument validation.

## Verdict

**PLAN GATE = HOLD**

This is a **near-ready plan**, not a rejected design.

Once the four High items above are written into `implementation_plan_006_0923.md` and the active OpenSpec delta, implementation can proceed without another redesign discussion.
