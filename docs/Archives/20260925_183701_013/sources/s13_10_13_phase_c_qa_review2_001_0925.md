# Section 13.10–13.13 — Independent Re-QA Review 2

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `fa58926b7fee423898805d8290fafd5319a8c53e`
- **Reviewed commit:** `75bffb0092f5ca3788c55264f1c0e75e74af7261`
- **Prior QA:** `docs/Artifacts/s13_10_13_phase_c_qa_review1_001_0925.md`
- **Scope:** Section 13.10–13.13 QA repair only
- **Out of scope:** Section 14; post-QA Medium backlog (precedent JST parity, attach stale fields)
- **Review mode:** blind-first independent Re-QA
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
Section 13.10–13.13:
HOLD

Blocker: 0
High:    0
Medium:  1
```

The four prior findings are closed. One new in-scope Medium remains at the 13.13 refit callback boundary.

**Do not start Section 14 until M13.13-03 is closed.**

---

## 1. Commit / Scope Verification

The requested repair range is exactly one commit:

```text
fa58926b7fee423898805d8290fafd5319a8c53e
    ↓
75bffb0092f5ca3788c55264f1c0e75e74af7261
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = fa58926...
```

No commit-bound GitHub status or workflow run was present for the reviewed commit.

The changed implementation surface is consistent with the requested repair:

- `.agents/shared/evidence_discordance.R`
- `.agents/shared/evidence_trajectory.R`
- `.agents/shared/evidence_cluster.R`
- tests for discordance / trajectory / cluster stability
- plan / execution record / OpenSpec task metadata

Section 14 is not part of the reviewed implementation.

---

## 2. Prior Finding Closure

### H13.10-01 — CLOSED

The forbidden-language audit is now scoped to system-controlled fields only:

```text
wording
severity
advisory_flag
```

Domain decision labels such as:

```text
REJECT
REJECTED
```

are no longer scanned.

The repair tests cover:

```text
REJECT vs ACCEPT
ACCEPT vs REJECTED
```

and preserve:

```text
is_qa_review_candidate = TRUE
advisory_flag = "QA Review Candidate"
severity = "advisory"
halts_workflow = FALSE
```

while system wording such as `fatal system error` is still rejected.

**13.10.R1 / 13.11.R1: CLOSED.**

---

### M13.12-01 — CLOSED

`trajectory_from_ledger()` now requires the accepted Section 13.9 verifier:

```r
verify_decision_ledger(ledger)
```

before reading ledger decision state, timestamp, record ID, or actor ID.

The repair tests include:

```text
tampered decision_state
broken previous-record hash
mutated duplicate record ID
```

and all are rejected through the ledger integrity boundary.

**13.12.R1: CLOSED.**

---

### H13.13-01 — CLOSED

The previous fixed-distance pseudo-bootstrap path has been removed.

The ASSESSED path now requires all of:

```text
patient_rows with subject_id + unit_id
refit_features callback
frozen_range
```

and bootstrap replicates perform:

```text
sample subjects with replacement
    ↓
refit_features(sampled_subject_ids)
    ↓
gower_distance_matrix(...)
    ↓
hclust(..., fixed k)
    ↓
co-clustering accumulation
```

The sampled subject vector preserves bootstrap multiplicity; the prior `unique(idx)` unit-resampling behavior is gone.

The test fixture also correctly allows the same subject to appear in multiple units/themes.

If the required patient-level refit components are absent, the function returns only:

```text
stability_status = "NOT_ASSESSED"
stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"
```

and does not claim patient-level stability.

**13.13.R1: CLOSED.**

---

### M13.13-02 — CLOSED

`attach_cluster_stability()` now rejects incompatible ASSESSED stability unless:

```text
cluster method = hierarchical_agglomerative
n_cases = n_units
k matches
linkage matches
cluster labels = stability unit_ids
pair co-clustering dimensions match
pair co-clustering dimnames match
```

The repair tests cover mismatched:

```text
k
n
linkage
labels
clustering method
```

and reject them with `STABILITY_ATTACH_INCOMPATIBLE`.

The attachment also persists the repaired provenance fields:

```text
stability_k
stability_linkage
stability_unit_ids
stability_n_bootstrap_usable
stability_n_bootstrap_failed
```

**13.13.R2: CLOSED.**

---

## 3. M13.13-03 — Refit Callback Output Is Not Enforced as Canonical `evidence-feature-v1`

**Severity:** MEDIUM  
**Gate impact:** blocking final 13.13 acceptance

The new callback contract is documented as:

```text
refit_features(sampled_subject_ids)
  -> named list of evidence-feature-v1 keyed by unit_id
```

However, `assess_cluster_stability()` does not call the already available canonical validator:

```r
assert_evidence_feature_v1()
```

on each callback result before Gower calculation.

Instead, it passes the callback output directly into:

```r
gower_distance_matrix(feat_list, frozen_range, keys = keys)
```

The Gower layer validates flattenable clustering fields and feature-schema version, but it does not enforce the complete canonical `evidence-feature-v1` structure.

### Concrete evidence from the current test fixture

`tests/test_evidence_cluster.R` still defines:

```r
minimal_feat <- function(rd_estimate, ...) {
  list(
    schema_version = "evidence-feature-v1",
    feature_schema_version = ...,
    core = list(
      rd_estimate = rd_estimate,
      resolution_grade = ...
    ),
    delta_dependent = list(present = FALSE),
    clustering_feature_keys = list("rd_estimate", "resolution_grade")
  )
}
```

This object is not canonical `evidence-feature-v1`.

It lacks required fields including:

```text
source
rd_interval_width
direction_support
rr_mean_is_finite
has_zero_reference
target_n
reference_n
quarantine_flag_count
delta null fields
```

Yet the 13.13 `refit_features` test returns these partial objects and the stability path successfully produces:

```text
stability_status = "ASSESSED"
method = "patient_bootstrap_co_clustering"
```

Therefore the new callback boundary can certify an ASSESSED stability result using objects that do not satisfy the contract it claims to require.

### Why this remains material

Section 13 already established a canonical feature contract and runtime validator in the 13.7 repair.

The patient-level refit path is a new feature-construction boundary. If its output is not revalidated, a callback bug or legacy partial representation can bypass the canonical evidence-feature contract and still contribute to Gower distances and co-clustering stability.

This does not recreate the prior false-bootstrap High defect; actual subject resampling/refit now occurs. The residual issue is therefore classified **Medium**.

---

## 4. Required Repair — 13.13.R3

After receiving `feat_res` and before Gower:

```r
for (nm in names(feat_res)) {
  assert_evidence_feature_v1(
    feat_res[[nm]],
    context = paste0("stability.refit_features.", nm)
  )
}
```

If the validator is unavailable, Fail-Fast with an explicit dependency diagnostic rather than silently accepting partial objects.

### Required tests

Replace the partial 13.13 callback fixture with canonical full `evidence-feature-v1` objects.

Add negatives:

```text
callback result missing source
  -> reject / count failed replicate

callback result missing mandatory core field
  -> reject / count failed replicate

callback result with invalid delta atomicity
  -> reject / count failed replicate

canonical callback output
  -> ASSESSED path remains valid
```

Either behavior is acceptable for an invalid replicate:

```text
A. fail the entire stability assessment with explicit contract error
or
B. count the replicate in n_bootstrap_failed
```

but a noncanonical feature must never contribute to Gower/co-clustering.

---

## 5. Blind-First Review Notes

No new finding was raised for the user-declared out-of-scope post-QA backlog:

- precedent JST parity;
- NOT_ASSESSED attachment stale-field cleanup.

Those remain outside this review.

The reviewer runtime does not provide `Rscript`, so R execution counts were not independently rerun.

---

## 6. Implementer Claims — Consulted Only After Blind Review

The execution record reports:

```text
tests/test_evidence_discordance.R : 28 PASS / 0 FAIL
tests/test_evidence_trajectory.R  : 18 PASS / 0 FAIL
tests/test_evidence_cluster.R     : 73 PASS / 0 FAIL
run_regression_suite.R            : 49/49 PASS
openspec validate --strict        : valid
git diff --check                  : clean
```

These remain implementer execution evidence and do not override the independent Medium finding.

---

## 7. Final Gate

Current:

```text
13.10.R1 / 13.11.R1:
CLOSED

13.12.R1:
CLOSED

13.13.R1:
CLOSED

13.13.R2:
CLOSED

M13.13-03:
OPEN

Blocker 0
High    0
Medium  1

Section 13.10–13.13:
HOLD
```

Expected after 13.13.R3:

```text
Blocker 0
High    0
Medium  0

Section 13.10–13.13:
PASS / ACCEPT
```

**Section 14 should remain gated until 13.13.R3 is independently closed.**
