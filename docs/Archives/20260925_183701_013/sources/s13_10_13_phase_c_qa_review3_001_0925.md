# Section 13.10–13.13 — Independent Re-QA Review 3

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `11f96690337b2d24e8dca214c586aa51293d3803`
- **Reviewed commit:** `7b51fd10bfe2cf6fcc7851669a06225fd84dae2e`
- **Scope:** Section 13.13.R3 only — canonical `evidence-feature-v1` enforcement on `refit_features` before Gower
- **Out of scope:** Section 14; post-QA Medium backlog (precedent JST parity, attach stale fields)
- **Review mode:** blind-first independent Re-QA
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
13.13.R3:
CLOSED

Blocker: 0
High:    0
Medium:  0

Section 13.10–13.13:
PASS / ACCEPT
```

The prior M13.13-03 is closed. No new in-scope findings were identified.

---

## 1. Commit / Scope Verification

The requested repair range is exactly one commit:

```text
11f96690337b2d24e8dca214c586aa51293d3803
    ↓
7b51fd10bfe2cf6fcc7851669a06225fd84dae2e
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 11f9669...
```

Changed implementation surface is limited to the requested repair and supporting tests/docs:

- `.agents/shared/evidence_cluster.R`
- `tests/test_evidence_cluster.R`
- `.agents/skills/evidence-decision-review/SKILL.md`
- OpenSpec task metadata
- plan 028 / repair execution record

No Section 14 implementation was reviewed.

No commit-bound GitHub status or workflow run was present for the reviewed commit.

---

## 2. M13.13-03 — CLOSED

The previous finding was that `refit_features()` could return partial/noncanonical feature objects that were still passed into Gower and could contribute to an ASSESSED stability result.

The repair now adds an explicit dependency check:

```r
if (!exists("assert_evidence_feature_v1", mode = "function")) {
  stop("[MISSING_EVIDENCE_FEATURE_ASSERT] ...")
}
```

and validates every callback feature that is about to participate in the replicate:

```r
for (nm in present_units) {
  out[[nm]] <- assert_evidence_feature_v1(
    feat_res[[nm]],
    context = paste0("stability.refit_features.", nm)
  )
}
```

This occurs **before**:

```r
gower_distance_matrix(...)
```

so a noncanonical feature cannot enter Gower or co-clustering accumulation.

If validation fails, the replicate is counted as failed and skipped:

```r
n_failed <- n_failed + 1L
next
```

If no usable replicate remains, the assessment terminates with:

```text
STABILITY_BOOTSTRAP_FAILED
```

Therefore an invalid callback cannot silently produce `stability_status="ASSESSED"`.

---

## 3. Canonical Positive Fixture Verified

The 13.13 refit fixture was replaced by `canonical_feat()`, which now supplies the full runtime contract required by `assert_evidence_feature_v1()`:

### Root

```text
schema_version
feature_schema_version
source
core
delta_dependent
clustering_feature_keys
```

### Source

```text
evidence_schema_version = comparative-evidence-v1
inferential_semantics   = posterior
contrast_id             = null
theme                   = null
```

### Core

All mandatory core fields are present:

```text
rd_estimate
rd_interval_width
direction_support
resolution_grade
rr_mean_is_finite
has_zero_reference
target_n
reference_n
quarantine_flag_count
```

### Delta state

The `present=false` state is atomic:

```text
primary_delta      = null
target_excess      = null
practical_neutral  = null
reference_excess   = null
```

The test explicitly confirms that `canonical_feat()` passes `assert_evidence_feature_v1()`.

---

## 4. Negative Contract Tests Verified

The repair includes negative callbacks for the exact classes required by Review2.

### Partial legacy/minimal feature

```text
minimal_feat()
```

is independently asserted noncanonical, and a callback returning only minimal features never reaches ASSESSED; all replicates fail and the function returns `STABILITY_BOOTSTRAP_FAILED`.

### Missing source

A callback removing:

```r
feat$source <- NULL
```

is rejected before Gower.

### Invalid delta atomicity

A callback setting:

```r
delta_dependent$present <- TRUE
primary_delta <- NULL
```

is rejected before Gower.

These negative fixtures demonstrate that noncanonical refit output is excluded from the ASSESSED distance/co-clustering path.

---

## 5. Ordering / Contamination Check

The critical execution order is now:

```text
subject bootstrap
    ↓
refit_features(sampled_subject_ids)
    ↓
callback structure/name checks
    ↓
assert_evidence_feature_v1() on every participating unit
    ↓
Gower distance
    ↓
HAC
    ↓
co-clustering accumulation
```

This closes the prior contamination route.

A feature that fails canonical validation cannot:

- contribute to `gower_distance_matrix()`;
- contribute to HAC;
- increment `n_bootstrap_usable`;
- contribute to `co_sum` / `co_den`;
- support an ASSESSED result unless at least one separate valid replicate remains.

That behavior matches the accepted 13.13.R3 contract.

---

## 6. Blind-First Result

Before consulting the implementation execution record, the fixed-SHA code and tests were sufficient to close M13.13-03.

No new in-scope Blocker, High, or Medium finding was identified.

The following remain explicitly outside this review and are not reopened:

- precedent `decided_at_jst` JST parity;
- NOT_ASSESSED attachment stale-field cleanup;
- Section 14 implementation.

---

## 7. Implementer Evidence — Consulted After Independent Review

The repair record reports:

```text
tests/test_evidence_cluster.R : 78 PASS / 0 FAIL
run_regression_suite.R        : 49/49 PASS
openspec validate --strict    : valid
git diff --check              : clean
```

These are treated as implementer execution evidence, not as the basis of acceptance.

The reviewer environment does not provide `Rscript`, so the R test counts were not independently rerun.

No commit-bound CI/status evidence was present for the reviewed SHA.

---

## 8. Final Gate

```text
13.10.R1 / 13.11.R1: CLOSED
13.12.R1:             CLOSED
13.13.R1:             CLOSED
13.13.R2:             CLOSED
13.13.R3:             CLOSED

Blocker 0
High    0
Medium  0

Section 13.10–13.13:
PASS / ACCEPT
```

**Section 14 may proceed.**
