# Section 13.6.R1 / 13.7 / 13.8 — Independent QA Review 1

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `96a2156a130837117be5f7e5ad90c227917a024f`
- **Reviewed commit:** `d2695ba9c74b081c4852d655cadec8941ae951e2`
- **Scope:** 13.6.R1 + 13.7 + 13.8 (plan 021)
- **Out of scope:** 13.9–13.13
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol
- **Execution policy:** implementer PASS counts are claims unless independently reproduced.

## Decision

```text
13.6.R1: CLOSED

Section 13.7 / 13.8:
HOLD

Blocker: 0
High:    1
Medium:  1
```

**Do not start 13.9–13.12 yet.**

The K-means repair is correct. The new precedent layer has a sound overall structure, but its feature-schema binding is not yet enforceable: objects that do not conform to canonical `evidence-feature-v1` can be admitted and ranked while claiming the current feature schema version.

---

## 1. Scope / Commit Verification

The requested range is exactly one commit:

```text
96a2156a130837117be5f7e5ad90c227917a024f
    ↓
d2695ba9c74b081c4852d655cadec8941ae951e2
```

GitHub compare:

```text
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 96a2156...
```

No commit-bound combined status or workflow run was found.

Implementer evidence:

```text
tests/test_evidence_cluster.R   : 53 PASS / 0 FAIL
tests/test_evidence_precedent.R : 19 PASS / 0 FAIL
tests/test_evidence_gower.R     : 39 PASS / 0 FAIL
tests/run_regression_suite.R    : 46/46 PASS
OpenSpec strict                 : passed=1 failed=0
git diff --check                : clean
```

These counts remain implementer claims.

---

## 2. 13.6.R1 — CLOSED

The previous Medium finding is correctly repaired.

After standardization:

```r
n_distinct <- nrow(unique(as.data.frame(
  built$matrix_scaled,
  stringsAsFactors = FALSE
)))
```

and:

```r
if (k > n_distinct) {
  stop("[KMEANS_INSUFFICIENT_DISTINCT_CASES] ...")
}
```

The repair also records:

```text
n_distinct_cases
algorithm = Hartigan-Wong
iter.max = 10
```

and hardens finite checks for `nstart` and `seed`.

Tests include the exact prior acceptance fixture:

```text
[0,0,1,1], k=2 -> ACCEPT
[0,0,1,1], k=3 -> KMEANS_INSUFFICIENT_DISTINCT_CASES
```

**M13.6-01 is CLOSED.**

---

## 3. Positive Findings for 13.7 / 13.8

The overall precedent architecture is appropriate:

- decision labels are kept in `decision_context`, outside clustering input;
- required version fields exist:
  - `dictionary_release_version`
  - `delta_policy_version`
  - `feature_schema_version`;
- historical `case_id` uniqueness is enforced;
- nearest results are sorted by Gower distance then `case_id`;
- each hit carries distance, used Gower keys, warnings, version compatibility metadata, decision context, and evidence feature;
- `require_version_match=TRUE` filters mismatches;
- no singular prescribed regulatory decision is returned;
- deterministic simple-distance ordering is correct.

For the test example with frozen numeric range `[-1,1]`:

```text
query = 0.06
near  = 0.05 -> |0.01|/2 = 0.005
mid   = 0.40 -> |0.34|/2 = 0.17
far   = 0.95 -> |0.89|/2 = 0.445
```

so the expected order `near < mid < far` is correct.

---

## 4. H13.7-01 — Feature Schema Version Is Bound by String but Canonical `evidence-feature-v1` Conformance Is Not Enforced

**Severity:** HIGH
**Gate:** Blocking 13.7 / 13.8

A precedent case claiming:

```text
versions.feature_schema_version = 1.0.0
```

must contain an actual feature object conforming to the `evidence-feature-v1` contract for that version.

That schema requires, among other fields:

```text
source
all 9 core fields
all 5 delta_dependent fields
canonical clustering_feature_keys constraints
delta present-state atomicity
```

### Current runtime validation

`assert_historical_precedent_case()` calls:

```r
flat <- flatten_evidence_feature_values(case$evidence_feature)
```

but `flatten_evidence_feature_values()` only checks:

- `schema_version == evidence-feature-v1`;
- `clustering_feature_keys` exists;
- each listed key is found in `core` or `delta_dependent`.

It does **not** enforce the complete canonical `evidence-feature-v1` schema.

The historical precedent JSON Schema similarly defines:

```json
"evidence_feature": {
  "type": "object",
  "description": "evidence-feature-v1 object (validated at runtime)"
}
```

so standalone Draft-07 validation also does not enforce `evidence-feature-v1`.

### Concrete proof from current tests

`tests/test_evidence_precedent.R` defines:

```r
minimal_feat <- function(...) {
  list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = ...,
    core = list(
      rd_estimate = ...,
      resolution_grade = ...
    ),
    delta_dependent = list(present = FALSE),
    clustering_feature_keys =
      list("rd_estimate", "resolution_grade")
  )
}
```

This object is **not schema-valid** under `schemas/evidence-feature-v1.json` because it lacks:

- `source`;
- 7 required core attributes;
- `primary_delta`;
- `target_excess`;
- `practical_neutral`;
- `reference_excess`.

Yet it is accepted by:

```r
make_historical_precedent_case()
```

and used successfully in nearest-precedent retrieval tests.

Therefore the current tests demonstrate that feature-schema version binding is only nominal.

### Impact

A malformed or legacy/partial feature object can:

1. claim the current feature schema version;
2. enter the historical library;
3. receive a Gower distance;
4. affect nearest-neighbor ordering;
5. contribute decision context to later QA review.

That undermines the audit meaning of `feature_schema_version`.

### Required repair — 13.7.R1

Create one reusable canonical validator, for example:

```r
assert_evidence_feature_v1(features)
```

and use it consistently in:

```text
feature construction completion
historical precedent validation
query validation
Gower entry points as appropriate
```

It should enforce at least the same contract as `evidence-feature-v1.json`, including:

- required root fields;
- source contract;
- all required core fields and types/ranges;
- delta atomicity;
- clustering key allowlist/state rules;
- decision-label exclusion.

Also make the historical precedent schema enforce the nested evidence feature contract, preferably via a resolvable Draft-07 `$ref`:

```json
"evidence_feature": {
  "$ref": "evidence-feature-v1.json"
}
```

or an explicitly documented two-schema validation pipeline if the local validator cannot resolve refs.

### Required negative fixtures

Reject precedent/query objects with:

```text
missing source
missing mandatory core attribute
present=false but missing required null delta fields
present=true but incomplete delta keys
unknown clustering key
forbidden decision/regulatory key
```

### Acceptance

No object may claim `feature_schema_version=1.0.0` and participate in retrieval unless it conforms to the canonical feature contract.

---

## 5. M13.8-01 — `require_version_match=FALSE` Cannot Tolerate Feature-Schema Mismatch

**Severity:** MEDIUM
**Gate:** Repair with H13.7-01

The API documentation says:

```text
require_version_match = TRUE -> drop version-incompatible cases
```

which implies that when `FALSE`, incompatible cases remain available with:

```text
version_compatible = false
version_mismatches = [...]
```

That works for dictionary or delta-policy mismatches because they do not prevent distance computation.

It does **not** work for a feature-schema mismatch.

### Current path

Suppose:

```text
query feature_schema_version = 1.0.0
frozen range feature_schema_version = 1.0.0
historical case feature_schema_version = 2.0.0
require_version_match = FALSE
```

Then:

```r
compare_precedent_versions()
```

correctly reports the mismatch and the case is not filtered.

But the next call:

```r
gower_pairwise_distance(...)
```

requires both features to match the frozen range and stops with:

```text
[FEATURE_SCHEMA_VERSION_MISMATCH]
```

Therefore one old-schema case can abort the entire default retrieval instead of being represented as an explicit incompatibility.

The tests cover only a dictionary-version mismatch, not a feature-schema mismatch.

### Required repair — 13.8.R1

Define separate concepts:

```text
version_compatible
distance_scorable
```

Recommended policy:

- dictionary/delta-policy mismatch:
  - distance may still be scorable if feature schema is compatible;
  - when `require_version_match=FALSE`, return with mismatch metadata.
- feature-schema mismatch:
  - do **not** attempt Gower distance;
  - record as non-scorable incompatibility;
  - do not let it abort retrieval of otherwise valid candidates.
- when `require_version_match=TRUE`:
  - exclude all version-incompatible cases.
- if no scorable candidates remain:
  - Fail-Fast with an explicit precedent diagnostic.

A result may include, for example:

```text
incompatible_cases
excluded_cases
n_unscorable
distance_status = NOT_COMPARABLE
```

Do not assign a fake numeric distance across incompatible feature schemas.

### Required tests

Include a mixed library:

```text
case A: feature schema 1.0.0
case B: dictionary mismatch only
case C: feature schema 2.0.0
```

Verify:

```text
require_version_match=FALSE:
  A ranked
  B ranked + version mismatch flag
  C reported non-scorable, no crash

require_version_match=TRUE:
  only fully compatible cases ranked
```

---

## 6. Non-Findings / Deferred

Not raised as findings in this review:

- `range_version` is optional and is not one of the three required 13.7 version keys.
- `decided_at_jst` format strictness can be handled with the later ledger contract if desired.
- `notes` cardinality / extra-property normalization are secondary schema-hardening concerns.
- ledger, discordance, trajectory, bootstrap stability remain outside scope.

---

## 7. Repair Tasks

### 13.7.R1 — Enforce Canonical Nested Evidence-Feature Contract

**Priority:** P0
**Severity:** High

- [x] add/reuse full `assert_evidence_feature_v1()`;
- [x] validate query feature with it;
- [x] validate every historical case feature with it;
- [x] bind historical JSON schema to `evidence-feature-v1`;
- [x] replace schema-invalid `minimal_feat()` precedent fixtures with canonical fixtures;
- [x] add negative schema/runtime parity tests.

### 13.8.R1 — Separate Version Compatibility from Distance Scorability

**Priority:** P1
**Severity:** Medium

- [x] handle feature-schema mismatch before Gower;
- [x] do not abort whole retrieval when `require_version_match=FALSE`;
- [x] expose non-scorable incompatibility explicitly;
- [x] add mixed-version library tests;
- [x] preserve current dictionary/delta mismatch behavior.

### 13.7/13.8.R2 — Regression Gate

Run and record:

```bash
Rscript tests/test_evidence_feature_extract.R
Rscript tests/test_evidence_gower.R
Rscript tests/test_evidence_cluster.R
Rscript tests/test_evidence_precedent.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```

Also validate `historical-precedent-case-v1.json` against canonical positive and negative nested feature fixtures with a real Draft-07 validator.

---

## 8. Final Gate

Current (post implementer repair; independent Re-QA pending):

```text
13.6.R1:
PASS / CLOSED

13.7 / 13.8:
REPAIR COMPLETE (implementer) — awaiting independent Re-QA

Blocker 0
High    0 open (H13.7-01 repaired)
Medium  0 open (M13.8-01 repaired)
```

**Do not start 13.9–13.12 until independent Re-QA accepts 13.7.R1.**

Expected after independent Re-QA:

```text
13.6.R1: CLOSED
13.7: PASS / ACCEPT
13.8: PASS / ACCEPT

Blocker 0
High    0
Medium  0
```
