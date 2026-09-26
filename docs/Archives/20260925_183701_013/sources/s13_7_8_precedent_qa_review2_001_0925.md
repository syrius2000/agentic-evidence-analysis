# Section 13.7.R1 / 13.8.R1 — Independent Re-QA Review 2

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `c802b595a2757a1677cf195d9fea08c9f821de38`
- **Reviewed commit:** `c71e96b23e65ac9ba1d4380b45398851a59a4b86`
- **Original HOLD commit:** `d2695ba9c74b081c4852d655cadec8941ae951e2`
- **Scope:** Section 13.7.R1 + 13.8.R1 only
- **Out of scope:** 13.9–13.13
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
H13.7-01:
PARTIALLY CLOSED
  original High condition materially repaired
  residual runtime/schema parity issue remains (Medium)

M13.8-01:
CLOSED

Blocker: 0
High:    0
Medium:  1

Section 13.7 / 13.8:
HOLD — narrow parity repair only
```

Do not start 13.9–13.13 until the residual canonical-runtime parity issue is closed.

---

## 1. Commit / Scope Verification

The requested repair range is exactly one commit:

```text
c802b595a2757a1677cf195d9fea08c9f821de38
    ↓
c71e96b23e65ac9ba1d4380b45398851a59a4b86
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = c802b595...
```

No commit-bound GitHub status or workflow run was present for the reviewed commit.

The changed implementation surface is consistent with the requested repair:

- `.agents/shared/evidence_feature_extract.R`
- `.agents/shared/evidence_precedent.R`
- `schemas/historical-precedent-case-v1.json`
- `tests/test_evidence_precedent.R`
- repair plan / review / execution documentation
- OpenSpec task metadata

13.9–13.13 implementation was not reviewed.

Implementer execution claims:

```text
test_evidence_feature_extract.R : 39 PASS / 0 FAIL
test_evidence_gower.R           : 39 PASS / 0 FAIL
test_evidence_cluster.R         : 53 PASS / 0 FAIL
test_evidence_precedent.R       : 37 PASS / 0 FAIL
full regression                 : 46/46 PASS
OpenSpec strict                 : valid
git diff --check                : clean
```

These remain implementer claims because R was not independently rerun in the reviewer runtime.

---

## 2. H13.7-01 — Material Repair Verified

The prior High finding was that a precedent could claim the current feature schema version while containing only a partial, non-canonical feature object.

That major defect is repaired.

### Runtime improvements

The new:

```r
assert_evidence_feature_v1()
```

now verifies:

- required root fields;
- root additional properties;
- `schema_version`;
- non-empty `feature_schema_version`;
- forbidden decision/regulatory keys;
- source required fields and allowed source keys;
- all mandatory core fields;
- core field ranges/types for clustering-relevant values;
- delta required fields;
- delta additional properties;
- delta atomicity;
- clustering-key allowlist and delta-state rules.

It is now invoked from:

```text
extract_evidence_features()
complete_evidence_decision_feature_run()
assert_historical_precedent_case()
retrieve_nearest_precedents() query boundary
```

The old schema-invalid `minimal_feat()` precedent fixture was replaced by a canonical full fixture.

### Nested Draft-07 binding

`historical-precedent-case-v1.json` now uses:

```json
"evidence_feature": {
  "$ref": "evidence-feature-v1.json"
}
```

I independently reproduced this with Python Draft-07 validation:

```text
canonical historical precedent:
VALID

historical precedent containing the former partial feature:
INVALID
```

The partial case was rejected for missing canonical fields such as:

```text
source
rd_interval_width
direction_support
rr_mean_is_finite
has_zero_reference
...
```

Therefore the schema-side repair is confirmed independently.

---

## 3. M13.8-01 — CLOSED

The prior issue was that `require_version_match=FALSE` still allowed a feature-schema mismatch to reach Gower and abort the entire retrieval.

The repair correctly separates:

```text
version_compatible
distance_scorable
```

### Current behavior

For a feature-schema mismatch:

```text
distance_scorable = FALSE
distance_status   = NOT_COMPARABLE
gower_distance    = null
```

and the case is placed in:

```text
unscorable_cases
```

instead of being passed to Gower.

Dictionary/delta-policy mismatches remain distance-scorable when the feature schema matches.

For strict mode:

```text
require_version_match = TRUE
```

all version-incompatible cases are excluded before ranking.

The mixed A/B/C test correctly covers:

```text
A = fully compatible
B = dictionary mismatch only
C = feature-schema mismatch
```

Expected behavior:

```text
non-strict:
  A ranked
  B ranked + mismatch flag
  C unscorable / NOT_COMPARABLE

strict:
  only A ranked
```

The implementation matches that contract.

**M13.8-01 is CLOSED.**

---

## 4. Residual M13.7-02 — Runtime Validator Still Does Not Fully Match Draft-07

**Severity:** MEDIUM
**Gate:** narrow closure item

The function is documented as:

```text
Full canonical evidence-feature-v1 contract
(parity with schemas/evidence-feature-v1.json)
```

but two type checks required by the schema are still absent.

### A. `delta_dependent.present` is not required to be boolean at runtime

The JSON schema requires:

```json
"present": { "type": "boolean" }
```

but runtime `assert_delta_dependent_atomicity()` only checks:

```r
is.null(delta$present)
length(delta$present) != 1
is.na(delta$present)
```

and then branches via:

```r
if (isTRUE(delta$present)) {
   ...
} else {
   ...
}
```

Therefore this invalid R object can pass runtime validation:

```r
delta_dependent = list(
  present = 0,
  primary_delta = NULL,
  target_excess = NULL,
  practical_neutral = NULL,
  reference_excess = NULL
)
```

because:

```r
isTRUE(0) == FALSE
```

and the object is treated as the valid `present=false` state.

An independent Draft-07 check rejects the equivalent JSON instance:

```text
0 is not of type 'boolean'
```

### B. `source.contrast_id` / `source.theme` types are not checked

The JSON schema requires:

```json
"contrast_id": { "type": ["string", "null"] },
"theme":       { "type": ["string", "null"] }
```

Runtime verifies only that source keys are allowed, not the types of these optional values.

For example:

```r
source$contrast_id <- 123
```

is accepted by `assert_evidence_feature_v1()`.

Independent Draft-07 validation rejects the equivalent object:

```text
123 is not of type 'string', 'null'
```

### Why this remains a finding

The original repair acceptance condition was:

```text
No object may claim feature_schema_version=1.0.0
and participate in retrieval unless it conforms
to the canonical feature contract.
```

That condition is not yet literally true at the runtime boundary.

The large original defect — missing canonical core/source/delta structure — is fixed, so the prior High severity no longer applies. The remaining issue is a narrow runtime/schema parity defect and is therefore classified **Medium**.

---

## 5. Required Repair — 13.7.R1b

### Runtime parity

Add explicit checks:

```r
if (!is.logical(delta$present) ||
    length(delta$present) != 1L ||
    is.na(delta$present)) {
  stop("[INVALID_DELTA_DEPENDENT] present must be a boolean")
}
```

For optional source fields:

```r
assert_nullable_single_string <- function(x, field) {
  if (is.null(x)) return(invisible(TRUE))
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop("[INVALID_EVIDENCE_FEATURE] ", field, " must be string or null")
  }
}
```

Apply to:

```text
source.contrast_id
source.theme
```

### Required parity tests

Add runtime/Draft-07 paired negatives:

```text
delta.present = 0
delta.present = "false"
source.contrast_id = 123
source.theme = list(...)
```

For each fixture:

```text
runtime: reject
Draft-07: reject
```

Retain canonical positive fixtures.

---

## 6. Final Gate

Current (post implementer 13.7.R1b; independent Re-QA pending):

```text
13.7.R1:
PARTIALLY CLOSED → R1b applied (implementer)
High removed
Medium 0 open (M13.7-02 repaired)

13.8.R1:
CLOSED

Blocker 0
High    0
Medium  0

Section 13.7 / 13.8:
REPAIR COMPLETE (implementer) — awaiting independent Re-QA
```

Expected after independent Re-QA of 13.7.R1b:

```text
13.7.R1: CLOSED
13.8.R1: CLOSED

Blocker 0
High    0
Medium  0

Section 13.7 / 13.8:
PASS / ACCEPT
```
