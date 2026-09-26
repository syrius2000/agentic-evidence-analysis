# OpenSpec Re-Review #4 — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `48b48aad2e8f3346dc021dd54bd620695f4e26b6`  
**Compared against:** `3e02d41da666b3bd1be671dd2cddbcc18382ec08`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Plan-stage / blind-first follow-up / read-only  
**Verdict:** **PHASE 1 GO / PHASE 2–3 CONDITIONAL GO**

---

# 1. Executive Summary

The revision is successful.

The previous review’s core remaining issues N-01 through N-09 are now materially addressed:

- Bayesian posterior median vs bootstrap observed-sample estimate is explicitly separated.
- Bayesian practical-region probability vs bootstrap support fraction is explicitly separated.
- Interval representation is normalized to nested `interval.method`.
- OpenSpec `deterministic-r-dependencies` change is now represented as a `MODIFIED Requirements` delta while the canonical spec remains at the pre-change state.
- Frozen Gower ranges now have an explicit overflow clipping policy and diagnostic.
- Cluster stability now uses patient-level bootstrap co-clustering when individual-level data are available and explicitly returns `NOT_ASSESSED` otherwise.
- Prior sensitivity has an explicit trigger policy.
- IPTW truncation is explicitly applied to final weights by treatment arm.
- ATT scaling is explicitly versioned as a configuration choice.

The design is now sufficiently specified to begin **Phase 1 implementation** after strict OpenSpec validation.

The remaining findings are narrower and primarily affect Phase 2 and Phase 3.

---

# 2. Previous Review Findings — Current Disposition

| Previous finding | Status |
|---|---|
| N-01 bootstrap primary point estimate semantics | **RESOLVED** |
| N-02 posterior vs bootstrap practical-region semantics | **RESOLVED** |
| N-03 canonical/delta OpenSpec duplication | **RESOLVED** |
| N-04 Gower frozen-range overflow policy | **RESOLVED** |
| N-05 cluster stability method | **MOSTLY RESOLVED** |
| N-06 prior-sensitivity trigger | **RESOLVED** |
| N-07 IPTW truncation convention | **RESOLVED at high level** |
| N-08 ATT scaling convention | **RESOLVED** |
| N-09 `interval.method` field normalization | **RESOLVED** |

---

# 3. Strong Improvements Confirmed

## 3.1 Point estimate semantics are now correct

The design now distinguishes:

```yaml
estimate:
  value: <float>
  source: posterior_median | observed_sample_estimate
```

This is the correct contract.

Bayesian engines use:

```text
posterior_median
```

Bootstrap engines use the effect estimated on the original unresampled dataset:

```text
observed_sample_estimate
```

while bootstrap replicates are used for uncertainty intervals and support fractions.

This resolves an important auditability problem.

---

## 3.2 Practical-region support is now inferential-semantics aware

The new container:

```yaml
practical_region_support:
  inferential_semantics: posterior | bootstrap
  target_excess: ...
  practical_neutral: ...
  reference_excess: ...
```

correctly prevents:

\[
\text{posterior probability}
\]

from being silently conflated with:

\[
\text{bootstrap support fraction}
\]

The U-grade is now described as resolution of the **active uncertainty distribution**, which is a better domain-neutral formulation.

---

## 3.3 OpenSpec governance is repaired

The active Change now contains:

```text
openspec/changes/comparative-evidence-reporting-v3/
  specs/
    deterministic-r-dependencies/
      spec.md
```

with:

```text
## MODIFIED Requirements
```

while the canonical file remains on the prior accepted text.

This is now consistent with the repository’s OpenSpec change/archive model.

---

## 3.4 Gower overflow behavior is now deterministic

The Change now specifies:

\[
d_j = \min(1, |x_i-x_j|/R_j)
\]

with diagnostic:

```text
GOWER_REFERENCE_RANGE_EXCEEDED
```

This prevents frozen scaling ranges from silently yielding distances greater than one and preserves historical comparability.

---

## 3.5 Prior-sensitivity policy is explicit

The design now uses:

```yaml
prior_sensitivity:
  mode: zero_cell | off | explicit
```

with default:

```text
zero_cell
```

This avoids inventing an undefined “sparse” cutoff while retaining sensitivity analysis for the use case where it matters most.

---

# 4. Remaining High Findings

## R4-01 — HIGH before Phase 2A: matched-pair OR is ambiguous

### Current specification

The 1:1 matched-pair requirement says the Dirichlet model derives:

```text
RD, RR, OR
```

but only RD is explicitly defined:

\[
RD = p_{10}-p_{01}
\]

### Problem

For matched binary pairs there are at least two plausible odds-ratio estimands.

### Marginal OR

Using marginal risks:

\[
OR_{marginal}
=
\frac{p_T/(1-p_T)}
     {p_R/(1-p_R)}
\]

where:

\[
p_T=p_{11}+p_{10},\quad
p_R=p_{11}+p_{01}
\]

### Discordant-pair / matched OR

Using discordant probabilities:

\[
OR_{matched}
=
\frac{p_{10}}{p_{01}}
\]

These are not the same quantity.

A programmer could implement either one and still believe they complied with the current wording.

### Required correction

Explicitly name the intended quantities.

Recommended:

```text
marginal_rr
marginal_or
matched_discordant_or
```

If only one OR is needed in v3.5, choose it explicitly.

Given the common reporting architecture, the most coherent default is:

- RD = marginal risk difference
- RR = marginal risk ratio
- OR = marginal odds ratio

and optionally expose:

```text
matched_discordant_or
```

as a design-specific secondary diagnostic.

### Gate

Does not block Phase 1.

Must be fixed before 1:1 matching implementation.

---

## R4-02 — HIGH before Phase 2B: IPTW truncation thresholds must be recomputed inside each bootstrap replicate

### Current specification

The Change correctly says:

- refit PS inside every bootstrap replicate
- calculate weights
- apply percentile truncation to final weights separately by treatment arm

### Remaining ambiguity

It does not explicitly state whether the percentile cut points are:

1. computed once on the original sample and then reused in every replicate, or
2. recomputed from the final weights inside each bootstrap replicate.

These are different bootstrap procedures.

### Recommendation

The canonical bootstrap should reproduce the complete estimator pipeline in every replicate:

```text
resample patient
 -> refit PS
 -> compute weights
 -> compute arm-specific truncation percentiles within replicate
 -> truncate replicate weights
 -> compute marginal risks
```

The observed sample estimate analogously uses cut points computed on the observed sample.

Add one sentence to the design/spec and one unit/simulation test.

### Gate

Does not block Phase 1.

Must be fixed before IPTW implementation.

---

## R4-03 — HIGH before using U-grade for bootstrap designs: resolution cutoffs need semantics-aware validation

The current U-grade cutoffs are:

- U0: \(C \ge 0.95\)
- U1: \(0.80 \le C < 0.95\)
- U2: \(0.60 \le C < 0.80\)
- U3: \(C < 0.60\)

The new architecture correctly distinguishes posterior region mass from bootstrap support fractions.

However, it still applies the same U0–U3 thresholds to both.

### Problem

A value of:

```text
0.95 posterior probability
```

and:

```text
0.95 bootstrap support fraction
```

are not inferentially equivalent.

Using the same boundaries is acceptable only if U-grade is explicitly a **presentation-resolution index**, not a probabilistic decision threshold, and the policy has been validated for both uncertainty semantics.

### Recommended correction

Add:

```yaml
resolution_policy:
  version: ...
  applies_to:
    - posterior
    - bootstrap
```

or allow semantics-specific thresholds:

```yaml
posterior_cutoffs: [...]
bootstrap_cutoffs: [...]
```

The initial implementation may use identical values, but that equality should be a versioned policy choice, not an implicit mathematical equivalence.

### Gate

Phase 1 Bayesian-only implementation can proceed.

Must be addressed before U-grade is enabled on bootstrap designs.

---

# 5. Remaining Medium Findings

## R4-04 — Hierarchical clustering linkage method is unspecified

The spec now correctly chooses:

- Gower distance
- hierarchical agglomerative clustering

but does not specify the linkage method.

Possible choices include:

- average linkage
- complete linkage
- single linkage

They can produce materially different clusters.

Ward linkage should generally not be the default for arbitrary Gower dissimilarities because Ward’s criterion is tied to Euclidean variance geometry.

### Recommendation

Choose and version a canonical default, e.g.:

```yaml
hierarchical_clustering:
  linkage: average
```

and preserve the linkage value in analysis provenance.

---

## R4-05 — Cluster stability still needs a cluster-cut policy

Patient-level bootstrap co-clustering is a good choice because it avoids raw cluster-label switching.

However, co-clustering requires converting each hierarchical tree into a partition.

The specification does not yet define:

- fixed number of clusters \(K\),
- fixed dendrogram cut height,
- dynamic rule.

Without this, co-clustering probabilities are not reproducible.

### Recommendation

For v4:

```yaml
cluster_partition:
  mode: fixed_k
  k: <explicit>
```

as the simplest auditable starting point.

Do not automatically infer a “true K”.

Silhouette/gap statistics may be reported as diagnostics, not as an automatic regulatory decision rule.

---

## R4-06 — Gower constant-range features need a zero-range rule

The frozen-range formula uses:

\[
|x_i-x_j|/R_j
\]

If a numeric feature has:

\[
R_j=0
\]

the distance is undefined.

### Recommendation

Specify:

> Numeric features with frozen reference range 0 are excluded from the Gower denominator for that feature-schema version and recorded as `CONSTANT_FEATURE_IGNORED`.

This should be tested explicitly.

---

## R4-07 — Proposal.md contains some stale high-level vocabulary

The detailed design/spec has moved to neutral terminology, but `proposal.md` still contains phrases such as:

```text
excess events per natural unit
```

and:

```text
credible interval widths (rd_eti_width, log_rr_eti_width)
```

as generic capability descriptions.

For subject-incidence Safety data the canonical concept is excess **subjects**, not event episodes, and bootstrap designs do not use credible intervals.

### Recommendation

Refresh the proposal wording to:

```text
excess per natural unit
```

and:

```text
semantics-aware uncertainty interval widths
```

This is documentation consistency rather than a mathematical defect.

---

## R4-08 — Explicit zero-both RR assertion should be retained

The golden suite already includes:

```text
0/100 vs 0/100
```

Under independent Jeffreys posteriors, a zero reference count still implies:

\[
E(RR)=\infty
\]

even when the target observed count is also zero.

The generic requirement appears broad enough to cover this, but the zero-reference Scenario specifically shows \(x_T>0\).

### Recommendation

Add a direct assertion to the `0/100 vs 0/100` golden test:

```text
rr_mean = null
rr_mean_is_finite = false
```

This prevents future special-case implementation drift.

---

# 6. Phase Assessment

## Phase 1 — Independent Binary / Safety Core

### Verdict: **GO**

The previous schema blockers are resolved.

The following are now sufficiently specified:

- Pass 0 routing
- Jeffreys Beta-Binomial
- zero-event behavior
- theoretical RR expectation guard
- posterior median point estimate
- posterior ETI
- prior sensitivity
- delta profile
- practical-region support
- U-grade as region resolution
- subject-incidence domain semantics
- SOC/PT deduplication
- descriptive pooled output
- multiplicity disclaimer
- ephemeral raw draws
- run-layout conformance

### Remaining gate

Execute and record:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

before production implementation.

---

## Phase 2A — 1:1 Matched Pair / Person-Time

### Verdict: **CONDITIONAL GO**

Person-time specification is sufficiently explicit.

1:1 matching is ready except for R4-01 OR naming/estimand.

---

## Phase 2B — 1:k Matching / IPTW

### Verdict: **CONDITIONAL GO**

The major estimator ambiguity has been solved.

Before implementation:

- R4-02 bootstrap truncation recalculation
- R4-03 semantics-aware U-grade policy for bootstrap

should be fixed.

---

## Phase 3 — Decision Intelligence

### Verdict: **CONDITIONAL HOLD**

The architecture is now sound, but deterministic clustering still requires:

- R4-04 linkage
- R4-05 cut policy
- R4-06 zero-range Gower behavior

before implementation.

---

# 7. OpenSpec / CI Verification Status

For commit:

```text
48b48aad2e8f3346dc021dd54bd620695f4e26b6
```

the GitHub connector reports:

- no associated workflow runs
- no combined status checks

Therefore this review confirms the **textual/statistical specification**, but not successful execution of:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

or the R regression suite.

Those remain separate executable acceptance gates.

---

# 8. Recommended Minimal Final Planning Patch

Before implementation:

### Required for Phase 1

No further statistical-design change is required.

Only execute:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

and obtain Owner approval.

### Before Phase 2

Patch:

1. matched-pair OR naming/definition
2. bootstrap replicate truncation-percentile recalculation
3. semantics-aware U-grade policy for bootstrap

### Before Phase 3

Patch:

4. hierarchical linkage
5. cluster-cut policy
6. Gower zero-range behavior

### Documentation cleanup

7. refresh proposal terminology
8. add explicit ZERO_BOTH RR expectation assertion

---

# 9. Critical Position

The design has crossed an important threshold: the remaining issues are no longer foundational architecture failures.

The core model now preserves:

\[
\boxed{
\text{Estimate}
\ne
\text{Uncertainty Distribution}
\ne
\text{Interval Meaning}
\ne
\text{Practical-Region Support}
\ne
\text{Resolution Grade}
\ne
\text{Numerical Precision}
\ne
\text{Human Decision}
}
\]

That separation is the central strength of this Change.

The most important next discipline is to avoid letting later implementation convenience erase the distinctions that the specification now correctly makes.

---

# 10. Final Verdict

## Overall

**The revision is successful.**

### Phase 1

\[
\boxed{\text{GO}}
\]

after strict OpenSpec validation and explicit Owner approval.

### Full v3/v4 roadmap

Still requires small design closures in matching/IPTW/clustering, but no longer requires architectural redesign.

This is now a credible implementation-ready specification for the first vertical slice.
