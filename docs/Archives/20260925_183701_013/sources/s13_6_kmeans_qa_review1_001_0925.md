# Section 13.6 / 13.14 — Independent QA Review 1

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `58b29846a1c89c5e7a76d29a2ff7614bd656ea77`
- **Reviewed commit:** `96a2156a130837117be5f7e5ad90c227917a024f`
- **Scope:** Section 13.6 standardized K-means + Section 13.14 cluster governance gate
- **Out of scope:** 13.7–13.13 except 13.14
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol
- **Execution policy:** implementer PASS counts are treated as claims; `Rscript` is unavailable in the reviewer runtime, so R test counts were not independently rerun.

## Decision

```text
Section 13.6:
PASS / ACCEPT with 1 non-blocking Medium hardening

Section 13.14:
PASS / ACCEPT

Blocker: 0
High:    0
Medium:  1
```

**13.7–13.8 may proceed.**

The remaining Medium concerns controlled validation when requested `k` exceeds the number of distinct standardized case vectors. It does not alter the accepted common-path K-means result and does not affect the primary HAC/Gower path.

---

## 1. Scope / Commit Verification

The requested range is exactly one commit:

```text
58b29846a1c89c5e7a76d29a2ff7614bd656ea77
    ↓
96a2156a130837117be5f7e5ad90c227917a024f
```

Changed implementation surface is limited to the intended batch:

- `.agents/shared/evidence_cluster.R`
- `.agents/skills/evidence-decision-review/SKILL.md`
- `tests/test_evidence_cluster.R`
- OpenSpec task/design documentation
- plan 020 and execution record

No 13.7–13.13 implementation was reviewed.

GitHub reports no commit-bound status checks or workflow runs for the reviewed commit.

Implementer evidence reports:

```text
tests/test_evidence_cluster.R : 51 PASS / 0 FAIL
tests/test_evidence_gower.R   : 39 PASS / 0 FAIL
tests/run_regression_suite.R  : 45/45 PASS
OpenSpec strict               : passed=1 failed=0
git diff --check              : clean
```

These remain implementer claims.

---

## 2. Section 13.6 — Positive Findings

### Optional secondary path is preserved

HAC/Gower remains the primary clustering path. `evidence_kmeans()` is a separate optional function and does not replace the accepted HAC route.

### Continuous/numeric-only contract

Under plan 020's explicit contract (`continuous := frozen_reference_range type == "numeric"`):

- explicit categorical keys are rejected with `KMEANS_NON_CONTINUOUS_FEATURE`;
- `keys=NULL` resolves shared clustering keys, then filters to numeric keys;
- zero-variance explicit keys fail with `KMEANS_ZERO_VARIANCE_FEATURE`;
- zero-variance automatic keys are dropped;
- all-unusable numeric keys fail.

The default frozen range correctly keeps logical/categorical fields such as `resolution_grade`, `rr_mean_is_finite`, and `has_zero_reference` out of K-means.

### Standardization

The implementation builds the raw continuous matrix and applies:

```r
scale(mat, center = TRUE, scale = TRUE)
```

with finite-output validation.

For the deterministic test vector:

```text
0.00, 0.05, 0.90, 0.95
```

independent calculation gives approximately:

```text
mean = 0.475
sample SD = 0.5204165

z =
-0.9127305
-0.8166536
+0.8166536
+0.9127305
```

with mean 0 and sample variance 1.

### Fixed-k / provenance

The result records:

- method = `kmeans_standardized`
- partition_mode = `fixed_k`
- k
- feature keys
- `scaled=TRUE`
- scaling center and scale
- nstart
- optional seed
- range version
- feature schema version
- within/between sum-of-squares diagnostics
- assignments

### Reproducibility path

An explicit seed is accepted and recorded before `stats::kmeans()` invocation. `nstart` defaults to 10 and is recorded.

---

## 3. Section 13.14 — PASS / ACCEPT

The governance boundary is coherent for both HAC and K-means.

Generated results carry:

```text
exploratory_only = TRUE
decision_rule = FALSE
```

and the wording explicitly denies regulatory-decision use.

The implementation also:

- defines a forbidden top-level regulatory/result key list;
- checks generated HAC and K-means results;
- exposes `promote_cluster_to_regulatory_action()` only as a Fail-Fast refusal path;
- verifies that even a supplied `decision="approve"` argument cannot promote a cluster assignment.

No automatic decision or label-modification side effect was found.

**13.14 is CLOSED.**

---

## 4. M13.6-01 — `k <= n` Is Not Sufficient for `stats::kmeans()` When Cases Are Duplicated

**Severity:** MEDIUM
**Gate impact:** non-blocking; repair recommended before final Section 13 archival

The current K-means input contract validates:

```text
2 <= k <= n
```

and verifies non-zero feature variance.

However, that does not guarantee that there are at least `k` **distinct standardized rows**.

A valid-looking input can therefore pass all project checks and then fail inside base R.

Example:

```text
standardized source values:
0, 0, 1, 1

n = 4
k = 3
variance > 0
```

This satisfies the documented current checks:

```text
n >= 2
p >= 1
2 <= k <= n
non-zero variance
```

but there are only **2 distinct case vectors**.

`stats::kmeans()` chooses distinct rows as initial centers when `centers` is numeric; if fewer than `k` distinct rows exist, base R stops with:

```text
more cluster centers than distinct data points
```

Thus the project API can leak an uncontrolled base-R error for an input that satisfies its stated contract.

### Required repair

After standardization and before calling `stats::kmeans()`:

1. count distinct rows;
2. require `n_distinct >= k`;
3. Fail-Fast with a project diagnostic such as:

```text
[KMEANS_INSUFFICIENT_DISTINCT_CASES]
```

1. include `n_distinct` and requested `k` in the error;
2. add deterministic tests.

Suggested conceptual check:

```r
n_distinct <- nrow(unique(as.data.frame(built$matrix_scaled)))

if (k > n_distinct) {
  stop(
    "[KMEANS_INSUFFICIENT_DISTINCT_CASES] k=", k,
    " exceeds distinct standardized case vectors=", n_distinct
  )
}
```

### Required tests

```text
[0, 0, 1, 1], k=2 -> accept
[0, 0, 1, 1], k=3 -> project Fail-Fast
all identical -> existing zero-variance diagnostic remains authoritative
```

---

## 5. Optional Hardening Notes — Not Findings

### Integer parameter finiteness

`nstart` and `seed` validate integer-like values, but explicit `is.finite()` checks would make `Inf` / `-Inf` diagnostics cleaner instead of relying on integer coercion behavior.

Recommended but not gate-relevant:

```r
is.finite(nstart)
is.finite(seed)
```

### K-means algorithm provenance

`stats::kmeans()` currently relies on its default Hartigan-Wong algorithm and default iteration limit. For long-term audit reproducibility, explicitly setting and recording:

```text
algorithm = "Hartigan-Wong"
iter.max = 10
```

would make provenance stronger.

These are P2 hardening only.

---

## 6. Repair Task

### 13.6.R1 — Validate Distinct Standardized Case Count

**Priority:** P1
**Severity:** Medium
**Blocking 13.7–13.8:** No
**Status:** CLOSED by implementer repair (pending independent Re-QA)

- [x] compute distinct standardized row count before `stats::kmeans()`;
- [x] reject `k > n_distinct` with project diagnostic;
- [x] add duplicate-profile positive/negative fixtures;
- [x] preserve current zero-variance behavior;
- [ ] rerun cluster tests, Gower tests, regression suite, OpenSpec strict, and `git diff --check` (see execution artifact; independent Re-QA pending).

---

## 7. Final Gate

```text
Section 13.6:
PASS / ACCEPT
Medium 1 non-blocking

Section 13.14:
PASS / ACCEPT
No open finding

Blocker 0
High    0
Medium  1
```

### Development gate

**13.7–13.8 may proceed.**

Recommended sequencing:

```text
13.7–13.8 implementation may proceed now.

13.6.R1 should be closed before final Section 13
closure/archive so K-means has a fully controlled
input/error contract.
```
