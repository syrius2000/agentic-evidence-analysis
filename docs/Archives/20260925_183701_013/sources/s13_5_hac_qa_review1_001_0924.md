# Section 13.5 — Independent QA Review 1

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `b6286d5942728999e9b5b9cf30a0f48c25083615`
- **Reviewed commit:** `363c1f7914798ee268731036ccc9a6c7b7b1276d`
- **Tip (meta, excluded):** `1c065d2567c4f39491cbd7f8168c6b756ca1a54c`
- **Scope:** Section 13.5 Hierarchical Agglomerative Clustering only
- **Out of scope:** 13.6–13.8, 13.13
- **Review date:** 2026-09-24 JST
- **Reviewer:** GPT-5.6 Sol
- **Execution policy:** implementer PASS counts treated as claims; R tests were not independently rerun because `Rscript` is unavailable in the reviewer runtime.

## Decision

```text
Section 13.5:
PASS / ACCEPT

Blocker: 0
High:    0
Medium:  2 non-blocking hardening
```

**13.6 may proceed.**

Before historical precedent/version binding work in 13.7–13.8, close the two Medium audit/input-contract items below.

---

# 1. Scope / Commit Verification

The requested review range is exactly one commit:

```text
b6286d5942728999e9b5b9cf30a0f48c25083615
    ↓
363c1f7914798ee268731036ccc9a6c7b7b1276d
```

The reviewed implementation adds:

- `.agents/shared/evidence_cluster.R`
- `tests/test_evidence_cluster.R`
- regression-suite registration
- Section 13.5 documentation / OpenSpec updates
- implementer execution record

No Section 13.6–13.8 or 13.13 implementation was reviewed.

GitHub returned no commit-bound status or workflow run for the reviewed commit.

Implementer evidence reports:

```text
tests/test_evidence_cluster.R : 22 PASS / 0 FAIL
tests/test_evidence_gower.R   : 39 PASS / 0 FAIL
tests/run_regression_suite.R  : 45/45 PASS
OpenSpec strict               : valid
git diff --check              : clean
```

These remain implementer claims.

---

# 2. Positive Findings

The core Section 13.5 implementation is coherent.

## HAC contract

`evidence_hclust()` correctly implements:

- `stats::hclust`;
- default linkage `average`;
- allowed linkages `average`, `complete`, `single`;
- explicit rejection of Ward-family methods;
- explicit `fixed_k`;
- required integer `k`;
- `2 <= k <= n`;
- `n >= 2`;
- symmetric, finite, non-negative distance-matrix validation;
- zero diagonal validation;
- exploratory-only governance fields.

## Governance boundary

The result explicitly carries:

```text
exploratory_only = TRUE
decision_rule = FALSE
```

and the wording states that cluster assignments are not regulatory decisions.

## Stability boundary

Within the explicit 13.5 scope, the implementation emits:

```text
stability_status = "NOT_ASSESSED"
stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"
```

Patient-level bootstrap stability remains deferred to 13.13 as requested.

## Gower integration

`cluster_evidence_features()` correctly chains:

```text
evidence-feature-v1
→ gower_distance_matrix()
→ evidence_hclust()
```

and propagates:

- `range_version`;
- `feature_schema_version`;
- `gower_warnings`;
- the distance matrix.

An independent second-language calculation of the near/far four-case example reproduced the intended two-cluster grouping under average linkage and `k=2`.

---

# 3. M13.5-01 — `NA` Cluster Labels Are Not Rejected

**Severity:** MEDIUM
**Gate impact:** non-blocking for 13.6; repair before external use of assignment IDs

Current validation:

```r
labels <- as.character(labels)
if (length(labels) != n || anyDuplicated(labels) || any(!nzchar(labels))) {
  stop("[INVALID_CLUSTER_LABELS] ...")
}
```

The intended contract is:

```text
labels must be unique non-empty strings of length n
```

However, `nzchar()` uses `keepNA = FALSE` by default. In R, `nzchar(NA_character_)` is treated as non-empty rather than rejecting the missing value.

Therefore a label vector such as:

```r
c("A", NA_character_, "C")
```

can evade the explicit missing-label check when the NA is not duplicated.

That can produce assignment output containing an `NA` case name.

## Required repair

Use explicit missing-value validation:

```r
if (
  length(labels) != n ||
  anyNA(labels) ||
  anyDuplicated(labels) ||
  any(!nzchar(trimws(labels)))
) {
  stop("[INVALID_CLUSTER_LABELS] ...")
}
```

## Required tests

Add negative tests for:

```text
NA label
"" label
whitespace-only label
duplicate label
```

The duplicate and empty cases are already partially covered by implementation logic; make the test contract explicit.

---

# 4. M13.5-02 — Selected Gower Feature Keys Are Not Preserved in Clustering Provenance

**Severity:** MEDIUM
**Gate impact:** non-blocking for 13.6; should close before 13.7–13.8

`cluster_evidence_features()` accepts:

```r
keys = NULL
```

or an explicit feature subset:

```r
keys = c(...)
```

Different selected feature sets can produce different distance matrices and therefore different clusters.

The output currently records:

```text
linkage
k
range_version
feature_schema_version
gower_warnings
distance_matrix
```

but it does **not** record the actual Gower feature keys used.

When `keys=NULL`, the effective key set is resolved dynamically from shared feature keys. When `keys=` is supplied, the explicit subset is not persisted in the clustering result.

This weakens audit reproducibility: the final clustering artifact cannot directly state which feature subset generated its distance matrix.

## Required repair

Persist the resolved feature set, for example:

```text
gower_feature_keys
```

or:

```text
provenance:
  distance_metric: gower
  feature_keys: [...]
  range_version: ...
  feature_schema_version: ...
  linkage: average
  partition_mode: fixed_k
  k: 2
```

Preferred implementation:

1. have `gower_distance_matrix()` return `keys_used` / `resolved_keys`;
2. propagate the exact resolved list through `cluster_evidence_features()`;
3. add a test with an explicit two-feature subset;
4. add a test with `keys=NULL` proving the resolved canonical set is recorded.

## Acceptance

A stored clustering result must identify the exact feature dimensions that generated the distance matrix without relying on reconstruction from caller state.

---

# 5. Additional Hardening Note — Gower Upper Bound on Direct Matrix API

**Severity:** P2 / optional hardening, not a formal finding

`.assert_symmetric_distance_matrix()` accepts arbitrary non-negative dissimilarities, including values greater than 1.

That is mathematically valid for generic HAC, and the function documentation currently says:

```text
Gower (or other) distance matrix
```

However, Section 13.5's product contract is specifically HAC over Gower distances.

If `evidence_hclust()` is intended to remain generic, document the distinction clearly.

If it is intended to be a Gower-only public boundary, add:

```r
if (any(mat > 1 + tolerance)) ...
```

and update the deterministic test matrix to stay within `[0,1]`.

No gate impact is assigned because the primary wrapper `cluster_evidence_features()` obtains its matrix directly from the accepted Gower implementation.

---

# 6. Repair Tasks

## 13.5.R1 — Strict Cluster Label Validation

**Priority:** P1
**Blocking:** No
**Status:** CLOSED by independent Re-QA ([Review2-1](s13_5_hac_qa_review2_001_0925.md)) on `24b0618`

- [x] reject `NA` labels explicitly;
- [x] reject whitespace-only labels;
- [x] retain duplicate / empty rejection;
- [x] add negative tests.

---

## 13.5.R2 — Persist Resolved Gower Feature Provenance

**Priority:** P1
**Blocking:** No for 13.6; required before 13.7–13.8
**Status:** CLOSED by independent Re-QA ([Review2-1](s13_5_hac_qa_review2_001_0925.md)) on `24b0618`

- [x] expose resolved Gower keys from the distance-matrix layer;
- [x] propagate them into clustering output;
- [x] record distance metric = Gower;
- [x] test explicit subset;
- [x] test default resolved feature set.

---

# 7. Final Gate

```text
Section 13.5:
PASS / ACCEPT

Blocker 0
High    0
Medium  2 non-blocking
```

**13.6 may begin.**

Recommended sequencing:

```text
13.6 can proceed now.

13.5.R1 and 13.5.R2 should be closed before
13.7–13.8 historical precedent/version-binding work.
```
