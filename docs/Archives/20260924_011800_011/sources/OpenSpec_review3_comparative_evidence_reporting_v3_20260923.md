# OpenSpec Re-Review — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `3e02d41da666b3bd1be671dd2cddbcc18382ec08`  
**Compared against:** `cf51d8cb99dd488cdce490d0fbed4adcb23a53ff`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Plan-stage / blind-first follow-up / read-only  
**Implementation status:** Planning/specification only  
**Verdict:** **NEAR-GO — fix common bootstrap semantics before freezing schemas; Phase 1 otherwise ready**

---

# 1. Executive Summary

This commit addresses the previous review substantially and correctly.

The following previously open issues are now explicitly repaired:

- Bayesian ETI vs bootstrap percentile interval semantics
- 1:k matched-set ATT estimator
- exact IPTW ATE/ATT weight formulas
- exploratory hierarchical clustering and optional K-means restored
- frozen/versioned Gower scaling ranges
- Safety subject-risk wording changed from “events” to “subjects”
- optional sparse-data prior sensitivity added
- cross-theme dependency boundary documented
- deterministic regression-suite update represented as an OpenSpec `MODIFIED Requirements` delta

The mathematical/statistical design is now much closer to implementation-ready.

The remaining issues are mostly **schema semantics and governance**, not architecture.

### Current phase disposition

| Phase | Status |
|---|---|
| Phase 1: independent binary / Safety core | **GO after 2 small schema fixes** |
| Phase 2: 1:1 matched / person-time | **GO after common schema fix** |
| Phase 2: 1:k matched / IPTW | **CONDITIONAL GO; estimator formulas are now adequate, but weighted point-estimate semantics should be fixed** |
| Phase 3: Decision Intelligence | **CONDITIONAL GO; Gower out-of-range and cluster-stability methods need explicit policy** |

### Current severity

- **Blocker before common schema freeze:** 2
- **High before archive / later phases:** 3
- **Medium:** 4

---

# 2. Previous Review Findings — Disposition

| Previous finding | Status at `3e02d41` |
|---|---|
| Bootstrap ETI vs percentile interval conflation | **RESOLVED** |
| 1:k matching estimator under-specified | **RESOLVED** |
| IPTW ATE/ATT formulas absent | **RESOLVED** |
| OpenSpec delta for deterministic dependencies absent | **RESOLVED IN CHANGE**, but canonical direct edit remains — see N-03 |
| Hierarchical clustering/K-means disappeared | **RESOLVED** |
| Subject incidence called excess “events” | **RESOLVED** |
| Sparse prior sensitivity absent | **RESOLVED conceptually**, trigger needs refinement |
| Cross-theme dependence absent | **RESOLVED conceptually** |
| Gower scaling not versioned | **RESOLVED conceptually**, out-of-range rule still needed |

---

# 3. Strong Improvements Confirmed

## 3.1 Interval semantics are now explicitly separated

The design now defines:

```yaml
interval:
  lower: ...
  upper: ...
  level: 0.95
  method: posterior_eti | bootstrap_percentile
  inferential_semantics: posterior | bootstrap
```

This is the correct architectural direction.

Bayesian outputs use:

```text
posterior_eti
```

while IPTW / matched-set resampling uses:

```text
bootstrap_percentile
```

This resolves the prior semantic conflict.

---

## 3.2 1:k matched-set ATT is now testable

The revised estimator is explicit:

\[
\hat p_T
=
\frac{1}{J}\sum_{j=1}^{J}Y_{Tj}
\]

\[
\hat p_R
=
\frac{1}{J}\sum_{j=1}^{J}
\left(
\frac{1}{k_j}\sum_{\ell=1}^{k_j}Y_{Rj\ell}
\right)
\]

with:

- one treated subject per matched set
- variable \(k_j\)
- no matching replacement
- matched-set bootstrap
- equal matched-set contribution
- ATT interpretation

This is a materially better contract than “stratum-weighted or conditional proportions”.

---

## 3.3 IPTW now has explicit causal-weight formulas

The spec now pins:

### ATE

\[
w_i^{ATE}
=
\frac{A_i}{e_i}
+
\frac{1-A_i}{1-e_i}
\]

### ATT

\[
w_i^{ATT}
=
A_i
+
(1-A_i)\frac{e_i}{1-e_i}
\]

and separately defines stabilized variants.

The core ATT formula is consistent with standard propensity-score ATT weighting: treated subjects have weight 1 and controls receive treatment odds \(e/(1-e)\).

The key improvement is that implementation is no longer free to choose an unstated weighting convention.

---

## 3.4 Decision Intelligence capability is restored

The revised Change again includes:

- Gower distance
- hierarchical agglomerative clustering
- optional standardized continuous-feature K-means
- cluster stability / `NOT_ASSESSED`
- nearest precedents
- decision ledger
- discordance advisory

This restores the intended “Evidence Landscape” / historical consistency use case.

---

# 4. Remaining Blockers Before Common Schema Freeze

## N-01 — BLOCKER: Bootstrap primary point estimate is still not distinguished from the bootstrap replicate distribution

### Current common requirement

`comparative-evidence-reporting/spec.md` says:

> calculate median, mean (when finite), and 95% quantile intervals

for generic uncertainty draws.

This is appropriate for a Bayesian posterior distribution, where a posterior median is a meaningful point summary.

For a bootstrap analysis, however, the canonical point estimate should normally be the estimate computed from the **original analysis sample**, while the bootstrap replicate distribution provides the uncertainty interval.

For IPTW, for example:

\[
\hat{RD}_{obs}
=
\hat p_{T,obs}-\hat p_{R,obs}
\]

should remain the point estimate.

The bootstrap median:

\[
median(\hat{RD}^{*(1)},\ldots,\hat{RD}^{*(B)})
\]

is a property of the bootstrap distribution, not automatically the primary treatment-effect estimate.

### Risk

Without a field separating these concepts, downstream reporting may accidentally display:

```text
bootstrap median
```

as if it were the observed-sample effect estimate.

This can lead to small but unnecessary shifts and, more importantly, ambiguous audit semantics.

### Required correction

Add a generic schema contract such as:

```yaml
estimate:
  value: <float>
  source: posterior_median | observed_sample_estimate
```

For Bayesian models:

```text
source = posterior_median
```

For bootstrap models:

```text
source = observed_sample_estimate
```

Optionally retain bootstrap diagnostics:

```yaml
bootstrap_distribution:
  median: ...
  mean: ...
```

but do not use them as the canonical point estimate unless explicitly requested.

### Update

- `design.md`
- `comparative-evidence-reporting/spec.md`
- `comparative-design-inference/spec.md`
- `tasks.md`
- future `comparative-evidence-v1`

### Gate

Fix before implementing/freezing the shared contrast schema.

---

## N-02 — BLOCKER: Practical-region “probabilities” and U-grade remain semantically Bayesian in bootstrap modes

The architecture correctly distinguishes:

```text
posterior_probability_rd_gt_zero
```

from:

```text
bootstrap_support_fraction_rd_gt_zero
```

But practical-region classification is still written generically as:

\[
q_T=P(RD>\delta),\quad
q_N=P(|RD|\le\delta),\quad
q_R=P(RD<-\delta)
\]

and U-grade documentation still uses language such as:

> posterior resolution among practical-difference regions

The common contrast engine also accepts bootstrap uncertainty replicates.

### Problem

For IPTW / matched-set bootstrap:

\[
q_T
=
\frac{1}{B}\sum_b I(RD_b^*>\delta)
\]

is a **bootstrap support fraction**, not a Bayesian posterior probability.

The same numerical transform is valid, but its inferential interpretation is different.

### Recommended schema

Use a neutral container:

```yaml
practical_region_support:
  inferential_semantics: posterior | bootstrap
  target_excess: ...
  practical_neutral: ...
  reference_excess: ...
```

Rendering:

- posterior → “posterior probability”
- bootstrap → “bootstrap support fraction”

U-grade can remain a display resolution index across either distribution, but its definition should say:

> resolution of the active uncertainty distribution across practical regions

not:

> posterior resolution

unless `inferential_semantics = posterior`.

### Gate

Fix before common schema freeze.

---

# 5. High Findings

## N-03 — HIGH: The OpenSpec governance duplication still exists

This commit correctly adds:

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

That is the correct active-Change representation.

However, the canonical file:

```text
openspec/specs/deterministic-r-dependencies/spec.md
```

is **already modified** to the new dynamic registry wording.

Therefore the same change exists simultaneously:

1. as an active delta, and
2. already in the canonical spec.

### Why this matters

The content itself is correct. The issue is audit history.

If canonical specs are intended to represent accepted/archived state, then the active delta no longer describes a future modification — it describes something already applied.

### Preferred fix

Revert the canonical file to its pre-change text while this Change is active.

Then, at archive/acceptance time, apply the delta to canonical.

Alternative:

Document that the canonical correction was a separately approved maintenance repair and remove it from this active Change.

Do not keep both pathways ambiguous.

---

## N-04 — HIGH before Phase 3: Frozen Gower ranges require an out-of-range policy

The Decision Review spec now uses:

```text
frozen_reference_range
```

This improves historical reproducibility.

However, suppose a future value lies outside the frozen range:

\[
x_{new} > max_{reference}
\]

The standard normalized numeric Gower component:

\[
d=\frac{|x_i-x_j|}{range}
\]

can exceed 1 unless explicitly bounded or the range is revised.

### Required policy

Choose and version one behavior:

### Option A — clip with warning

\[
d_j=\min(1, |x_i-x_j|/R_j)
\]

and emit:

```text
GOWER_REFERENCE_RANGE_EXCEEDED
```

### Option B — fail / require new feature-schema version

More conservative and audit-friendly.

### Option C — expand range dynamically

Not recommended for historical audit because old nearest-neighbor distances can change.

### Recommendation

Use **Option B** for regulated/historical consistency work, or Option A for exploratory display.

Whichever is chosen must be explicit.

---

## N-05 — HIGH before Phase 3: Cluster stability is required but the stability estimator is not defined

The revised plan correctly restores clustering and requires:

```text
stability_status = assessed | NOT_ASSESSED
```

But “cluster stability assessment” is still unspecified.

Possible methods answer different questions:

- bootstrap Jaccard cluster stability
- co-clustering probability
- adjusted Rand index across resamples
- posterior/uncertainty perturbation
- patient-level bootstrap

For Safety PTs, dependence across PTs complicates posterior-independent perturbation.

### Recommended initial contract

If patient-level rows across themes are available:

1. bootstrap patients jointly,
2. recompute PT/SOC comparative features,
3. recompute Gower distances/clusters,
4. calculate pairwise co-clustering probability.

If only aggregated PT summaries are available:

```text
stability_status = NOT_ASSESSED
reason = CROSS_THEME_DEPENDENCE_UNAVAILABLE
```

Do not simulate each PT independently and call that full cluster stability.

---

# 6. Medium Findings

## N-06 — Prior sensitivity trigger is still ambiguous

The spec says the \(\text{Beta}(1,1)\) sensitivity analysis is:

> optional ... for sparse or zero-event comparisons

but “sparse” is not formally defined.

Avoid creating another hidden threshold.

### Better contract

```yaml
prior_sensitivity:
  mode: off | zero_cell | explicit
```

Optionally:

```yaml
mode: explicit
themes: [...]
```

or a versioned `sparse_policy`.

A simple initial default is:

```text
mode = zero_cell
```

because zero cells are objectively defined and central to this use case.

---

## N-07 — IPTW truncation convention should be pinned one step further

The spec says:

> configurable percentile weight truncation (e.g. 1st / 99th percentiles)

Still define whether percentiles are calculated:

- on final weights globally,
- separately by treatment arm,
- on propensity scores before weight construction.

These are not identical procedures.

### Recommended v3.5 default

Use:

> percentile truncation of the **final computed weights**, calculated separately by treatment arm

or choose global final-weight truncation and state it explicitly.

The point is deterministic reproducibility.

---

## N-08 — “Stabilized ATT” should be treated as an explicit optional scaling convention

The core ATT weights:

\[
1,\quad e/(1-e)
\]

are standard.

The current design also defines a stabilized ATT control multiplier using marginal treatment odds.

Because group-normalized weighted risk estimates are invariant to a common positive scaling of all control weights, this scaling does not change the normalized ATT control mean, but it does change raw weight summaries such as maximum weight.

### Recommendation

Represent this as:

```yaml
att_weight_scaling:
  mode: conventional | marginal_odds_scaled
```

rather than implying there is a universally canonical “stabilized ATT” definition.

This keeps diagnostics reproducible.

---

## N-09 — `interval.method` vs `interval_method` field naming should be unified

`design.md` shows:

```yaml
interval:
  method: posterior_eti
```

while design-aware specs/tasks use:

```text
interval_method = "posterior_eti"
```

This is minor now but should be resolved before schema implementation.

### Recommendation

Prefer the nested form:

```yaml
interval:
  level: 0.95
  method: posterior_eti | bootstrap_percentile
  lower: ...
  upper: ...
```

and remove the parallel top-level `interval_method`.

---

# 7. Mathematical Review of IPTW Formulas

The revised unstabilized formulas are coherent:

### ATE

\[
w_i=
\frac{A_i}{e_i}
+
\frac{1-A_i}{1-e_i}
\]

### ATT

\[
w_i=
A_i+(1-A_i)\frac{e_i}{1-e_i}
\]

These match standard propensity-score weighting definitions.

The stabilized ATE formula is also conventional.

For ATT, marginal-odds rescaling of control weights is a constant scaling within controls; when the weighted control risk is normalized by the sum of weights, the ATT point estimate is unchanged. The main requirement is therefore to specify the scaling convention explicitly because diagnostics such as raw maximum weight depend on it.

---

# 8. OpenSpec Validation / CI Status

For commit:

```text
3e02d41da666b3bd1be671dd2cddbcc18382ec08
```

the GitHub connector reports:

- no associated workflow runs
- no combined commit status checks

Therefore this review validates the **specification content**, not execution of:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

or the repository regression suite.

Those remain mandatory gates.

---

# 9. Updated Phase Gate

## Phase 1 — Independent binary / Safety

### Verdict: **GO after N-01 and N-02 schema repair**

All core statistical elements are now sufficiently specified:

- Jeffreys Beta-Binomial
- zero-event behavior
- theoretical RR mean divergence guard
- posterior ETI
- subject-incidence domain labels
- delta profile
- practical-region resolution
- prior sensitivity
- SOC/PT counting
- descriptive pooled reporting
- batch multiplicity disclaimer
- ephemeral draws

N-01/N-02 should be fixed first because they affect the shared output schema.

---

## Phase 2A — 1:1 matched / person-time

### Verdict: **GO after common schema repair**

The mathematical model is sufficiently explicit.

---

## Phase 2B — 1:k matched / IPTW

### Verdict: **CONDITIONAL GO**

The major prior ambiguity is resolved.

Before implementation:

- settle N-07 truncation convention
- settle N-08 ATT scaling nomenclature
- apply N-01/N-02 point/region semantics

---

## Phase 3 — Decision Intelligence

### Verdict: **HOLD until N-04 and N-05 are specified**

Clustering capability is now restored, but:

- frozen-range overflow behavior
- stability estimator

must be pinned before implementation.

---

# 10. Recommended Minimal Next Patch

Before writing production code, make one final planning patch:

1. add canonical `estimate.source`
   - `posterior_median`
   - `observed_sample_estimate`
2. make practical-region support semantics-aware
   - posterior probability
   - bootstrap support fraction
3. unify `interval.method` field naming
4. resolve deterministic-r-dependencies canonical/delta duplication
5. define Gower out-of-range policy
6. define cluster-stability method / `NOT_ASSESSED` conditions
7. define prior-sensitivity trigger
8. pin IPTW truncation convention

Then run:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

and begin Phase 1.

---

# 11. Critical Position

The Change is now technically coherent enough that the biggest risk is no longer “wrong mathematics”.

The main remaining risk is **semantic leakage through a shared schema**.

The following distinctions should remain explicit all the way into JSON and reporting:

\[
\boxed{
\begin{aligned}
\text{posterior median}
&\ne
\text{observed bootstrap estimator} \\
\text{posterior region probability}
&\ne
\text{bootstrap region support fraction} \\
\text{credible ETI}
&\ne
\text{bootstrap percentile interval} \\
\text{subject excess}
&\ne
\text{event excess} \\
\text{cluster similarity}
&\ne
\text{decision recommendation}
\end{aligned}
}
\]

The architecture is now strong enough that preserving these semantic boundaries should be the priority.

---

# 12. Final Verdict

**NEAR-GO**

Compared with the previous commit, the specification has improved materially and most major statistical concerns are resolved.

### Required before Phase 1

- N-01 bootstrap point-estimate semantics
- N-02 practical-region posterior/bootstrap semantics

### Required before archive / governance completion

- N-03 canonical-vs-delta duplication

### Required before Phase 3

- N-04 frozen Gower range overflow behavior
- N-05 cluster stability method

Once N-01/N-02 are fixed and strict OpenSpec validation passes, I would consider the **Phase-1 implementation plan ready to start**.
