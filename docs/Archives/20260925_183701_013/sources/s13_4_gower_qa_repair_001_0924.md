# Section 13.4 — Independent QA Review 1 / Repair Plan

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `ab20a86a328ce6d91574d56b37471ae5061b7a52`
- **Reviewed commit:** `e6bdce544ea99e59640677afccc1a12c5293daa4`
- **Scope:** Section 13.4 only — Gower distance + `frozen_reference_range`
- **Out of scope:** 13.5–13.8
- **Review date:** 2026-09-24 JST
- **Reviewer:** GPT-5.6 Sol
- **Execution policy:** implementer PASS counts treated as claims; R tests were not independently rerun because `Rscript` is unavailable in the reviewer runtime.

## Decision

```text
Section 13.4:
HOLD

Blocker: 0
High:    1
Medium:  2
```

Do **not** start 13.5 yet.

The basic mixed-type Gower structure, missing-value pairwise averaging, version fields, warning code, and symmetric matrix construction are reasonable. The blocking issue is that numeric overflow is implemented with **input clipping before differencing**, which is not the OpenSpec formula.

---

# 1. Scope / Commit Verification

The requested range is exactly one commit:

```text
ab20a86a328ce6d91574d56b37471ae5061b7a52
    ↓
e6bdce544ea99e59640677afccc1a12c5293daa4
```

Changed implementation surface includes:

- `.agents/shared/evidence_gower.R`
- `schemas/frozen-reference-range-v1.json`
- `schemas/fixtures/frozen_reference_range_default_v1.json`
- `tests/test_evidence_gower.R`
- regression registration
- Section 13.4 OpenSpec/design/task documentation

No Section 13.5–13.8 implementation was reviewed.

GitHub reports no commit-bound combined status or workflow run for the reviewed commit.

Implementer evidence states:

```text
tests/test_evidence_gower.R       23 PASS / 0 FAIL
tests/run_regression_suite.R      44/44 PASS
OpenSpec strict                   valid
git diff --check                  clean
```

These remain implementer claims.

---

# 2. Positive Findings

The implementation correctly provides:

- frozen range version and feature-schema version binding;
- numeric and categorical contributions;
- missing-value pairwise exclusion;
- pairwise result metadata including `range_version`;
- distance matrix symmetry;
- `GOWER_NO_COMPARABLE_FEATURES`;
- `FEATURE_SCHEMA_VERSION_MISMATCH`;
- `GOWER_REFERENCE_RANGE_EXCEEDED`;
- zero-width range runtime rejection;
- regression-suite registration.

The default frozen range also covers the current canonical Phase A clustering features.

---

# 3. H13.4-01 — Overflow Distance Formula Does Not Match OpenSpec

**Severity:** HIGH
**Gate:** Blocking

## Required contract

OpenSpec 13.4 defines:

```text
d_j = min(1, |x_i - x_j| / R_j)
```

with `GOWER_REFERENCE_RANGE_EXCEEDED` when an observation lies outside the frozen reference range.

This is **contribution clipping**: calculate the raw difference using the observations, divide by the frozen width, then cap the contribution at 1.

## Current implementation

`.agents/shared/evidence_gower.R` first clips each observation into `[min,max]`:

```r
if (x < min_v || x > max_v) {
  warnings_acc <- c(warnings_acc, "GOWER_REFERENCE_RANGE_EXCEEDED")
  x <- max(min_v, min(max_v, x))
}
```

and later computes:

```r
dj <- min(1, abs(ca$value - cb$value) / Rj)
```

So the formula actually implemented is approximately:

```text
d_j =
min(
  1,
  |clip(x_i) - clip(x_j)| / R_j
)
```

That is not the specified formula.

## Concrete independent reproduction

Frozen range:

```text
[-1, 1]
R = 2
```

Observations:

```text
x_i = 5
x_j = 0
```

OpenSpec:

```text
min(1, |5 - 0| / 2)
= min(1, 2.5)
= 1.0
```

Current implementation:

```text
clip(5) = 1
clip(0) = 0

|1 - 0| / 2
= 0.5
```

More seriously:

```text
x_i = 5
x_j = 3
```

OpenSpec:

```text
min(1, |5 - 3| / 2) = 1
```

Current implementation:

```text
clip(5) = 1
clip(3) = 1

distance = 0
```

Thus two materially different out-of-range observations can become **identical under Gower**.

This can materially alter the future hierarchical clustering in 13.5.

## Why the existing test does not catch it

`tests/test_evidence_gower.R` currently checks:

```r
approx_eq(over$distance, 1) || over$distance <= 1
```

and then:

```r
over$distance <= 1
```

Those assertions only verify boundedness, not the specified formula.

The test comment explicitly assumes input clipping:

```text
After clip to 1.0 ...
```

which confirms that the implementation interpretation diverged from the OpenSpec equation.

## Required repair

For numeric features:

1. detect whether either observation exceeds `[min,max]`;
2. append `GOWER_REFERENCE_RANGE_EXCEEDED`;
3. compute with the **original numeric values**:

```r
raw <- abs(x_i - x_j) / Rj
dj <- min(1, raw)
```

Do not replace `x_i` / `x_j` with range boundaries before differencing.

### Required exact tests

Add deterministic fixtures independent of the Bayesian engine:

```text
range [-1,1]

0.2 vs 0.0 -> 0.1
5.0 vs 0.0 -> 1.0 + warning
5.0 vs 3.0 -> 1.0 + warning
5.0 vs 5.0 -> 0.0 + warning
-5.0 vs 5.0 -> 1.0 + warning
```

Tests must assert exact expected contributions, not only `<= 1`.

---

# 4. M13.4-01 — Missing Frozen-Range Features Are Silently Dropped

**Severity:** MEDIUM
**Gate:** Fix before 13.5

Current selection logic:

```r
if (is.null(keys)) {
  keys <- intersect(flat_a$keys, flat_b$keys)
} else {
  keys <- as.character(keys)
}

keys <- intersect(keys, names(frozen_range$features))
```

This silently removes any selected/canonical feature that does not have a frozen-range entry.

Example:

```text
requested/shared keys:
  rd_estimate
  direction_support
  resolution_grade

frozen range accidentally contains:
  rd_estimate
  resolution_grade
```

The calculation proceeds without `direction_support` and without a warning or error.

Likewise an explicit request:

```r
keys = c("rd_estimate", "direction_support")
```

silently becomes only `rd_estimate` if the frozen range omits `direction_support`.

## Impact

Distance semantics can change silently when a frozen-range artifact is incomplete. That undermines the purpose of frozen/versioned scaling and makes historical distances hard to compare.

## Required repair

Distinguish:

```text
candidate keys
range-covered keys
missing-range keys
```

If any requested/shared clustering key is missing from the frozen range, Fail-Fast, for example:

```text
[FROZEN_RANGE_MISSING_FEATURE]
```

If intentional subset selection is supported, it must be explicit through the `keys=` argument and **every explicitly requested key must still have a range definition**.

Do not use `intersect()` as silent validation.

### Required tests

- default `keys=NULL`, one canonical range entry removed → reject;
- explicit two-key request, one missing from range → reject;
- explicit valid subset with all range entries present → accept.

---

# 5. M13.4-02 — Single-Item Matrix Bypasses Range / Version Validation

**Severity:** MEDIUM
**Gate:** Fix before 13.5 or restrict API

`gower_distance_matrix()` accepts any non-empty list:

```r
if (!is.list(feature_list) || length(feature_list) < 1L) ...
```

For a single item, the loop reaches:

```r
if (i == j) {
  mat[i, j] <- 0
  next
}
```

and never calls `gower_pairwise_distance()`.

Therefore for `n=1`, the function can return a valid-looking `0 × self` matrix without independently validating:

- `frozen_range`;
- `feature_schema_version`;
- clustering-key/range coverage;
- overflow diagnostics.

A one-item matrix containing a feature with `feature_schema_version = "9.9.9"` can therefore bypass the mismatch check that pairwise Gower enforces.

## Required repair

Choose one:

### Option A — validate matrix inputs before loops

At matrix entry:

```text
assert_frozen_reference_range()
flatten / validate every feature
feature_schema_version equality
range coverage
```

Then construct the matrix.

### Option B — require at least two rows

If a Gower distance matrix is semantically meaningful only for clustering:

```text
length(feature_list) >= 2
```

and Fail-Fast otherwise.

Option A is preferable because it keeps the matrix API complete and auditable.

### Required tests

- single feature with correct version → 1x1 zero matrix, after validation;
- single feature with wrong `feature_schema_version` → reject;
- single feature + malformed frozen range → reject;
- single out-of-range feature → warning behavior explicitly defined and tested.

---

# 6. Repair Tasks

## 13.4.R1 — Implement the OpenSpec Gower Overflow Formula

**Priority:** P0 / HIGH

- [x] Remove input-value clipping from numeric distance calculation.
- [x] Preserve overflow detection and warning.
- [x] Compute `min(1, abs(x_i-x_j)/Rj)` from original values.
- [x] Add exact deterministic numeric tests.
- [x] Include same-side overflow fixture (`5 vs 3`) to prevent collapse-to-zero regression.

### Acceptance

The implementation exactly matches the OpenSpec equation for in-range and out-of-range observations.

---

## 13.4.R2 — Enforce Frozen-Range Coverage

**Priority:** P1

- [x] Calculate missing range keys before distance calculation.
- [x] Reject missing selected/shared features with explicit diagnostic.
- [x] Do not silently shrink the feature set via `intersect()`.
- [x] Test implicit full set and explicit subset behavior.
- [x] Document whether partial feature selection is supported.

### Acceptance

Every feature contributing to the configured Gower contract has an explicit frozen range/type definition.

---

## 13.4.R3 — Validate Matrix Inputs Before Diagonal Shortcut

**Priority:** P1

- [x] Validate frozen range at matrix entry.
- [x] Validate all feature schema versions before loop.
- [x] Validate key/range coverage before loop.
- [x] Define single-item matrix behavior.
- [x] Add negative single-item validation tests.

### Acceptance

`gower_distance_matrix()` cannot bypass validations that apply to `gower_pairwise_distance()`.

---

## 13.4.R4 — Regression / Gate Recheck

Run and record separately:

```bash
Rscript tests/test_evidence_gower.R
Rscript tests/test_evidence_feature_extract.R
Rscript tests/test_skill_run_isolation.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Also independently cross-check deterministic numeric fixtures in a second implementation/language where practical.

---

# 7. Final Gate

Current (post-repair claim; awaiting independent re-QA):

```text
Section 13.4:
PASS candidate (implementer)

Blocker 0
High    0 (H13.4-01 repaired)
Medium  0 (M13.4-01 / M13.4-02 repaired)

13.5:
may begin after independent QA ACCEPT
```

Previous HOLD decision remains until independent re-QA closes the gate.
