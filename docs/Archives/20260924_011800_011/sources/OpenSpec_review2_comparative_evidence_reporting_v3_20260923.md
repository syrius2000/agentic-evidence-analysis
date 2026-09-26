# OpenSpec Re-Review — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `cf51d8cb99dd488cdce490d0fbed4adcb23a53ff`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Plan-stage re-review / commit-fixed / read-only  
**Previous verdict:** CONDITIONAL HOLD  
**Current verdict:** **CONDITIONAL GO FOR PHASE 1 / HOLD FOR PHASE 2–3 UNTIL SPEC REPAIR**

---

# 1. Executive Summary

The revision is materially improved. The previous four Blocker findings have been addressed in the OpenSpec text:

1. U0–U3 is now correctly separated from generic numerical precision.
2. Posterior vs bootstrap semantics are explicitly distinguished.
3. Gamma-Poisson person-time inference now has a reproducible Jeffreys / shape-rate contract.
4. Raw Monte-Carlo draws are now ephemeral by default rather than mandatory large JSON artifacts.

Most of the previous High findings were also corrected:

- `primary_delta = null` is now a valid explicit state.
- complex survey weights fail fast.
- Pass 0 no longer silently deduplicates Safety data.
- canonical Safety hierarchy is SOC → PT.
- pooled Safety output is explicitly `descriptive_pooled`.
- delta profile is configurable.
- arbitrary group-count boundary for all-pairs was removed.
- arbitrary NNH 0.95 direction threshold was removed.
- hard-coded 80% historical-decision consensus was replaced by configurable policy.
- decision ledger is now described as append-only/tamper-evident.
- H/N/B was replaced by domain-neutral region naming.
- batch multiplicity/selection disclaimer was added.
- fixed “23 regression tests” drift was corrected.

The architecture is now sufficiently mature for the **Phase-1 independent binary vertical slice**, after one remaining cross-engine semantic issue is corrected.

However, the full Change should not yet be treated as implementation-ready for IPTW / 1:k matching / decision clustering.

---

# 2. Previous Findings — Disposition Matrix

| Previous finding | Current status | Comment |
|---|---|---|
| B-01 U-grade mislabeled as precision | **RESOLVED** | `Practical-Region Resolution Grade` is now separated from `rd_eti_width`, `log_rr_eti_width`, ESS |
| B-02 bootstrap called posterior | **MOSTLY RESOLVED** | draw semantics fixed; interval semantics still inconsistent — see R-01 |
| B-03 Gamma-Poisson under-specified | **RESOLVED** | Jeffreys prior, shape-rate parameterization, exposure model specified |
| B-04 raw draw persistence undefined | **RESOLVED** | runtime interface + ephemeral draws default |
| H-01 primary delta null conflict | **RESOLVED** | `mode:none`, `primary_delta:null` explicit |
| H-02 survey weights routed to unsupported engine | **RESOLVED** | `UNSUPPORTED_SURVEY_DESIGN` |
| H-03 Pass 0 silently deduplicates | **RESOLVED** | inspection/proposal only |
| H-04 Safety hierarchy mismatch | **RESOLVED** | SOC → PT canonical |
| H-05 pooled Safety undefined | **RESOLVED** | `descriptive_pooled`, no heterogeneity claim |
| H-06 fixed delta grid | **RESOLVED** | configurable/non-normative |
| H-07 all-pairs `>4` rule | **RESOLVED** | reference-vs-all default, explicit all-pairs |
| H-08 NNH arbitrary probability cutoff | **RESOLVED** | `reciprocal_status` approach |
| H-09 IPTW contract | **PARTIAL** | semantics improved; exact ATE/ATT weight formulas still absent |
| H-10 1:k matched estimator | **PARTIAL** | ATT target added; estimator formula still not uniquely pinned |
| H-11 fixed 80% precedent consensus | **RESOLVED** | configurable neighborhood policy |
| H-12 immutable ledger claim | **RESOLVED** | append-only / tamper-evident |
| H-13 H/N/B domain semantics | **RESOLVED** | TARGET_EXCESS / PRACTICAL_NEUTRAL / REFERENCE_EXCESS |
| H-14 multiplicity warning | **RESOLVED** | explicit exploratory disclaimer |
| H-15 evidence-run-layout integration | **PARTIAL** | conformance declared; OpenSpec delta/governance issue remains |
| H-16 23-vs-31 regression count drift | **CONTENT RESOLVED** | but canonical spec was edited directly during active Change; see R-04 |
| M-01 zero numerator vs zero denominator wording | **RESOLVED** |
| M-02 HDI scope creep | **RESOLVED** | ETI only |
| M-03 RR instability threshold | **RESOLVED** | continuous metrics retained |
| M-04 missing delta feature handling | **RESOLVED** |
| M-05 historical policy/version context | **RESOLVED** |
| M-06 parallel bootstrap reproducibility | **RESOLVED** | serial reproducible bootstrap specified |

---

# 3. Remaining Findings

## R-01 — BLOCKER: Bootstrap intervals are still semantically conflated with Bayesian ETI / credible intervals

### Evidence in current spec

`comparative-evidence-reporting/spec.md` says the common uncertainty-draw processor:

> calculate median, mean (when finite), and **95% equal-tailed credible intervals (ETI)** for contrasts

But this same processor explicitly consumes:

```text
inferential_semantics = posterior | bootstrap
```

For an IPTW or matched-set bootstrap, the empirical 2.5% and 97.5% quantiles are **bootstrap percentile intervals**, not Bayesian credible intervals / ETIs.

`tasks.md` also still contains:

> relative risk point estimate or **credible interval**

in the generic dashboard section.

### Why this matters

The entire architecture correctly distinguishes:

\[
\text{posterior probability}
\neq
\text{bootstrap support fraction}
\]

The same distinction must apply to intervals:

\[
\text{Bayesian ETI}
\neq
\text{bootstrap percentile interval}
\]

Otherwise the schema repairs the draw semantics but reintroduces the same conflation at the report layer.

### Required fix

Use a generic quantile interval representation:

```yaml
interval:
  lower: ...
  upper: ...
  level: 0.95
  method: posterior_eti | bootstrap_percentile
  inferential_semantics: posterior | bootstrap
```

Presentation rules:

- posterior → “95% credible interval (ETI)”
- bootstrap → “95% bootstrap percentile interval”

Generic internal fields may remain:

```text
q025
q975
interval_width
```

but report wording MUST be semantics-aware.

### Files to update

- `specs/comparative-evidence-reporting/spec.md`
- `design.md`
- `tasks.md` §§2, 14, 16
- future `comparative-evidence-v1`

### Gate

**Must fix before freezing the common schema or starting Phase 1 implementation.**

---

## R-02 — HIGH: 1:k matching remains under-specified despite ATT label

### Current text

The revised spec now says:

- target estimand = ATT
- resample matched sets atomically
- compute “stratum-weighted event proportions”

This is improved but still not unique.

### Missing mathematical contract

For the common 1-treated : \(k_j\)-control case, the spec should define the estimator, for example:

\[
\hat p_T
=
\frac{1}{J}
\sum_{j=1}^{J}Y_{Tj}
\]

and:

\[
\hat p_R
=
\frac{1}{J}
\sum_{j=1}^{J}
\left(
\frac{1}{k_j}
\sum_{\ell=1}^{k_j}Y_{Rj\ell}
\right)
\]

which weights each treated matched set equally and gives an ATT-aligned matched-control risk.

This is different from pooling all matched controls:

\[
\frac{\sum_j\sum_\ell Y_{Rj\ell}}
{\sum_j k_j}
\]

when \(k_j\) varies.

The two estimators answer different weighted questions.

### Also specify

- exactly one treated subject per set or general matched-set support?
- replacement allowed?
- if matching with replacement, how reused comparator subjects contribute
- whether original matching weights are honored
- what happens to incomplete/invalid sets
- bootstrap replicate estimator formula

### Recommendation

For v3.5, support only:

> **one treated subject per matched set, variable number of matched controls, no matching replacement**

as the initial canonical mode.

Expand later if needed.

### Gate

Does **not** block Phase 1, but **must be fixed before Phase 2 matching implementation**.

---

## R-03 — HIGH: IPTW ATE/ATT formulas remain implementation-dependent

### Current improvement

The spec now correctly requires:

- `iptw_mode = refit_ps`
- PS refitting in every bootstrap replicate
- ATE/ATT explicit
- stabilization/truncation configurable
- ESS/balance/positivity diagnostics

### Remaining problem

It does not define the exact canonical weight formulas.

At minimum, define the unstabilized formulas:

#### ATE

\[
w_i^{ATE}
=
\frac{A_i}{e_i}
+
\frac{1-A_i}{1-e_i}
\]

#### ATT

\[
w_i^{ATT}
=
A_i
+
(1-A_i)\frac{e_i}{1-e_i}
\]

Then define how stabilized weights are constructed, if enabled.

The current phrase “compute stabilized weights” is insufficient because different implementations can yield different results.

### Also clarify

- PS model formula is part of `analysis_config.json`
- categorical encoding / missing-covariate policy
- truncation is applied to PS or to final weight?
- truncation percentile computed globally or by treatment group?
- main-sample diagnostics vs per-bootstrap diagnostics
- externally supplied fixed weights remain unsupported in canonical `refit_ps` mode unless a separate mode is specified

### Gate

Does not block Phase 1.  
**Must be fixed before IPTW implementation.**

---

## R-04 — HIGH (OpenSpec governance): canonical spec was directly edited during an active Change

The commit modifies:

```text
openspec/specs/deterministic-r-dependencies/spec.md
```

directly.

At the same time `comparative-evidence-reporting-v3` is still an active Change.

Repository precedent shows changes to existing capabilities are normally represented in:

```text
openspec/changes/<change>/specs/<capability>/spec.md
```

using:

```text
## MODIFIED Requirements
```

and canonical `openspec/specs/...` is synchronized when the Change is archived/accepted.

### Why this matters

The content correction — removing the stale fixed “23 tests” count — is correct.

The issue is **change governance / provenance**, not the substance.

### Recommended fix

Either:

**Option A — preferred**

Add:

```text
openspec/changes/comparative-evidence-reporting-v3/
  specs/
    deterministic-r-dependencies/
      spec.md
```

with the modified requirement, and revert the direct canonical edit until archive.

Or:

**Option B**

Treat the regression-count fix as a separate already-approved maintenance change/commit with its own audit trail.

### `evidence-run-layout`

For `evidence-run-layout`, if no requirement itself changes and new skills merely conform to it, a new delta spec is not necessarily required. But the task and design should continue to verify conformance.

---

## R-05 — HIGH: Clustering functionality was accidentally lost from the revised active Change

### User requirement / original plan

The intended Decision Intelligence layer included:

- Gower distance
- hierarchical clustering
- optional standardized K-means
- cluster stability
- nearest precedents
- decision discordance

### Current revised OpenSpec

The current `evidence-decision-consistency/spec.md` contains:

- feature vectors
- Gower nearest precedent retrieval
- decision distribution
- discordance policy
- audit ledger

But **no explicit hierarchical clustering requirement**.

`tasks.md` likewise removed:

- hierarchical clustering implementation
- optional K-means implementation
- K-means input validation

while still retaining:

> bootstrap cluster stability assessment

This creates an internal contradiction: cluster stability is required, but no clustering algorithm is required.

### Recommended fix

Restore a dedicated requirement:

### Requirement: Exploratory Evidence Clustering

Primary:
- Gower distance
- hierarchical agglomerative clustering

Optional:
- K-means only on explicitly selected standardized continuous features

Rules:
- decision labels excluded from clustering inputs
- cluster ID is not a decision rule
- cluster membership is exploratory
- stability MUST be assessed or `NOT_ASSESSED`

Add corresponding tasks back.

### Gate

Does not block Phase 1/2.  
**Must be corrected before Phase 3 implementation.**

---

## R-06 — MEDIUM: “Excess events per 100” is still semantically wrong for subject-incidence Safety analyses

For Safety subject incidence, the estimand is:

\[
P(\text{subject has ≥1 qualifying event})
\]

Therefore:

\[
100\times RD
\]

means approximately:

> additional **subjects** per 100 treated

not additional event episodes.

Current documents still use generic phrases such as:

- “Excess Events per Natural Unit”
- “excess events per 100/1000”

### Recommended naming

Canonical machine field:

```text
absolute_difference_per_unit
```

or:

```text
excess_per_unit
```

Domain rendering:

- Safety subject risk → `additional_subjects_per_100_treated`
- RWD binary outcome → `additional_cases_per_100_persons`
- Prescription → `additional_users_per_100`
- person-time → `additional_events_per_100_person_years`

This prevents estimand drift between risk and rate modes.

---

## R-07 — MEDIUM/HIGH: Sparse zero-event analyses would benefit from explicit prior sensitivity

The primary Jeffreys prior is well specified:

\[
Beta(0.5,0.5)
\]

However, the intended use case includes extreme sparse comparisons such as:

```text
1/200 vs 0/1000
0/200 vs 2/1000
3/100 vs 0/100
```

In this regime, prior choice can materially influence posterior tail probabilities and RR behavior.

The existing repository already uses a pattern of:

- primary Jeffreys \(\alpha=0.5\)
- sensitivity Laplace/uniform \(\alpha=1\)

for categorical posterior analysis.

### Recommendation

Add an optional but canonical sensitivity analysis:

\[
p_g \sim Beta(1,1)
\]

for key sparse/zero-cell results.

Persist, for example:

```text
prior_sensitivity:
  primary: jeffreys_0_5
  sensitivity: uniform_1
  rd_median_shift
  direction_support_shift
  practical_region_shift
```

Do **not** blend the sensitivity result into the primary U-grade.

Instead show:

> primary inference is / is not robust to the prespecified prior sensitivity.

### Why this fits the design

This reinforces the system’s critical stance: uncertainty due to sparse data includes **prior sensitivity**, not just interval width.

### Gate

Not required to unblock Phase 1, but strongly recommended before declaring zero-cell Safety support mature.

---

## R-08 — MEDIUM: Multi-theme subject correlation should be stated explicitly

Separate Jeffreys Beta-Binomial analyses for each PT are valid as marginal theme-specific analyses when each PT is reduced to one binary value per subject.

But the same subject may contribute to many PTs.

Therefore:

- theme-specific marginal posterior estimates are valid under the stated subject-level counting rule
- cross-theme posterior draws are **not** a joint model of PT dependence
- ranking/clustering across PTs does not automatically model within-subject correlation across themes

### Important consequence for future cluster stability

If cluster stability is generated by independently perturbing each PT posterior, the procedure will ignore cross-PT dependence.

Preferred options:

1. patient-level resampling across all PTs simultaneously when raw patient data is available
2. otherwise mark cross-theme stability as approximate / not assessed

Add this boundary to Safety and Decision Review specs.

---

## R-09 — MEDIUM: Historical Gower distance needs a versioned scaling/range rule

Gower numeric distances depend on feature ranges.

If the historical repository expands, an outlier can change the effective scaling and therefore nearest neighbors.

The spec already binds:

- dictionary version
- delta-policy version
- feature-schema version

Add a distance-normalization policy to the feature schema version, e.g.:

```text
gower_scaling:
  mode: frozen_reference_range
  feature_schema_version: evidence-feature-v1
```

or explicitly define dynamic ranges and accept that nearest-neighbor distances are run-dependent.

For auditability, frozen/versioned reference ranges are preferable.

---

# 4. Phase Gate Assessment

## Phase 1 — Independent binary / Safety core

### Status

**CONDITIONAL GO**

Before implementation, fix:

- **R-01 interval semantics**
- preferably R-04 OpenSpec canonical-spec governance

Then Phase 1 is sufficiently specified:

- Pass 0 independent binary route
- Jeffreys Beta-Binomial
- zero-event handling
- RD/RR
- excess per natural unit
- configurable delta profile
- region resolution
- SOC/PT adapter
- `descriptive_pooled`
- multiplicity disclaimer
- ephemeral draws
- offline report

---

## Phase 2 — Design-aware inference

### Status

**HOLD**

Before implementation fix:

- R-02 exact 1:k estimator
- R-03 exact ATE/ATT weight formulas
- interval semantics inherited from R-01

1:1 matched-pair and Gamma-Poisson portions are otherwise well specified.

---

## Phase 3 — Decision Intelligence

### Status

**HOLD**

Before implementation fix:

- R-05 restore clustering requirement/tasks
- R-08 cross-theme correlation boundary for stability
- R-09 Gower scaling/version policy

Nearest precedent retrieval and tamper-evident decision ledger are otherwise materially improved.

---

# 5. Additional Review Notes

## No CI / validation evidence attached to this commit

The GitHub commit currently has:

- no workflow runs associated with the commit
- no combined-status checks

Therefore this review verifies the **textual/statistical plan**, but does not claim that:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

has passed.

That remains a required execution gate.

---

# 6. Recommended Minimal Patch Before Phase 1

The smallest corrective patch is:

1. define semantics-aware intervals:
   - posterior → ETI
   - bootstrap → percentile interval
2. add `interval_method` to `comparative-evidence-v1`
3. replace generic “credible interval” wording in dashboard tasks
4. move/re-express the deterministic dependency SSOT edit through an OpenSpec `MODIFIED Requirements` delta, or separate maintenance change
5. restore hierarchical clustering/K-means tasks now, even if Phase 3 implementation is deferred, so the approved plan retains the intended capability

Then run:

```text
openspec validate comparative-evidence-reporting-v3 --strict --json
```

and re-review only the delta.

---

# 7. Critical Position

The revised plan now avoids the largest conceptual failure modes identified in the first review.

The remaining most important rule is:

\[
\boxed{
\text{same numerical operation}
\neq
\text{same inferential meaning}
}
\]

Examples:

- posterior quantile interval ≠ bootstrap percentile interval
- posterior region probability ≠ bootstrap region fraction
- subject risk difference ×100 ≠ event-count increase
- ATT matched-set weighting ≠ pooled matched-control proportion
- historical cluster majority ≠ regulatory truth

This semantic discipline should remain stronger than implementation convenience.

---

# 8. Final Verdict

## Current overall verdict

**CONDITIONAL GO FOR PHASE 1**

The first review’s major structural problems are substantially repaired.

### Before Phase 1 implementation

Must fix:
- **R-01 bootstrap/posterior interval semantics**

Should fix:
- **R-04 OpenSpec canonical-spec governance**

### Before Phase 2

Must fix:
- **R-02 1:k estimator**
- **R-03 IPTW exact weight formulas**

### Before Phase 3

Must fix:
- **R-05 clustering capability restoration**
- clarify R-08/R-09

### Overall repository decision

Continue in the same `agentic-evidence-analysis` repository.  
No separate repository is warranted at this stage.

