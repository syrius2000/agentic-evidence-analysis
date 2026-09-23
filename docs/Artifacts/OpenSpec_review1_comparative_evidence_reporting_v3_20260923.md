# OpenSpec Plan Review — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed target:** `openspec/changes/comparative-evidence-reporting-v3/`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Plan-stage / blind-first / read-only  
**Implementation status:** **NOT STARTED by this review**  
**Verdict:** **CONDITIONAL HOLD — revise OpenSpec before implementation**

---

## 1. Executive Summary

### Overall assessment

The proposed architecture is strong and aligned with the repository’s existing statistical-governance philosophy:

\[
\text{Domain}
\ne
\text{Design}
\ne
\text{Inference}
\ne
\text{Contrast}
\ne
\text{Decision}
\]

The decision to keep the work in `agentic-evidence-analysis` is appropriate because this repository already owns the statistical schemas, OpenSpec SSOT, R implementations, quality contracts, and regression tests.

The proposed separation into:

1. `vcd-pass0-consultation`
2. `vcd-categorical-reporting`
3. `comparative-design-analysis`
4. `evidence-decision-review`

is also conceptually sound.

However, several plan-level issues should be corrected **before code implementation**. The largest problems are not cosmetic; they affect the statistical meaning of outputs, schema semantics, design-aware inference, and future auditability.

### Review disposition

- **Architecture:** APPROVE WITH REVISIONS
- **Statistical contract:** HOLD
- **Implementation start:** NOT RECOMMENDED YET
- **OpenSpec correction required:** YES
- **Repository split required:** NO

### Severity summary

- **Blocker:** 4
- **High:** 12
- **Medium:** 6

---

# 2. Blocker Findings

## B-01 — `U0–U3` is not “estimation precision”

### Current design

The current design defines:

\[
q_T=P(RD>\delta),\quad
q_N=P(|RD|\le\delta),\quad
q_R=P(RD<-\delta)
\]

and

\[
C=\max(q_T,q_N,q_R)
\]

then maps `C` to U0–U3.

The documentation/tasks describe U-grade as “uncertainty” or “estimation precision”.

### Problem

`C` measures **how decisively the posterior falls into one of the practical-difference regions**. It does **not** measure estimation precision in the usual statistical sense.

A very narrow posterior centered exactly on `RD = delta` can have approximately equal mass in two adjacent regions and therefore receive U3, even though the numerical estimator is highly precise. Conversely, a broad posterior almost entirely above `delta` can receive U0 even if its credible interval is wide.

### Required correction

Rename/redefine this quantity as something such as:

- `practical_region_resolution_grade`
- `region_resolution_grade`
- display alias may remain `U0–U3`

but documentation MUST say:

> U-grade measures posterior resolution among prespecified practical-difference regions; it is not a generic measure of sampling precision, clinical severity, or data quality.

Keep separate continuous precision diagnostics:

- `rd_eti_width`
- `rd_eti_width_per_100`
- `log_rr_eti_width`
- design-specific ESS
- zero/sparse flags

### Files affected

- `design.md`
- `specs/comparative-evidence-reporting/spec.md`
- `tasks.md` §§2, 7, 14, 16
- future report vocabulary

---

## B-02 — Bootstrap outputs are incorrectly called posterior draws

### Current conflict

`design.md` correctly says posterior and bootstrap semantics must remain distinct.

However `comparative-design-inference/spec.md` says:

- “standardized posterior draws”
- “MCMC/posterior simulation draws”
- matched-set bootstrap produces “posterior contrast distributions”
- all samplers output “posterior parameter vectors”

### Problem

This directly contradicts the proposed field:

```text
inferential_semantics = posterior | bootstrap
```

An IPTW patient bootstrap is not a Bayesian posterior unless a Bayesian model is actually specified.

### Required correction

Use the neutral canonical term:

> **uncertainty draws / uncertainty replicates**

Then specialize:

- Beta / Dirichlet / Gamma engine → `posterior`
- matched-set / IPTW bootstrap → `bootstrap`

For bootstrap results use wording such as:

```text
bootstrap_support_fraction_rd_gt_zero
```

not:

```text
posterior_probability_rd_gt_zero
```

### Files affected

- `specs/comparative-design-inference/spec.md`
- `proposal.md`
- `design.md`
- `tasks.md`

This should be fixed before `comparative-draws-v1` is frozen.

---

## B-03 — Gamma-Poisson person-time contract is under-specified

### Current requirement

The current spec uses a generic expression:

\[
\lambda_T\sim Gamma(\alpha_T+x_T,\beta_T+Y_T)
\]

without fully defining:

- `Y_T`
- Gamma parameterization
- primary prior
- whether the prior is Jeffreys or user-configurable
- recurrent-event assumptions

### Problem

The model cannot be reproduced uniquely from the current specification.

### Recommended canonical v3 contract

For event count `x_g` and person-time `T_g`:

\[
X_g\sim Poisson(\lambda_g T_g)
\]

Primary Jeffreys prior:

\[
\pi(\lambda_g)\propto\lambda_g^{-1/2}
\]

which gives, under **shape-rate** parameterization:

\[
\lambda_g|D\sim
Gamma\left(
 x_g+\frac12,\;
 T_g
\right)
\]

The schema MUST explicitly record:

```text
gamma_parameterization: shape_rate
prior: poisson_rate_jeffreys
exposure_unit: person_year | person_month | ...
```

Also add a limitation:

> Simple Poisson rate inference does not by itself solve within-subject recurrent-event dependence or overdispersion.

### Files affected

- `specs/comparative-design-inference/spec.md`
- `design.md`
- `tasks.md` §11

---

## B-04 — Raw draw persistence is not defined and may become unscalable

### Current proposal

The proposal suggests artifacts including:

```text
comparative_draws.json
```

At the same time this system is intended for hundreds or thousands of PTs/themes with 10,000 posterior/bootstrap draws.

### Problem

For example:

\[
1000\ themes\times10000\ draws\times2\ groups
\]

already produces 20 million numeric draw values before metadata/JSON overhead.

Persisting this as JSON is unnecessarily large and conflicts with the existing repository tendency to persist statistical summaries rather than all raw Monte-Carlo draws.

### Required design decision

Define `comparative-draws-v1` as a **logical runtime interface**, not automatically as a permanent JSON artifact.

Recommended default:

```yaml
draw_persistence:
  mode: ephemeral
  persist_raw_draws: false
```

Canonical permanent output:

```text
comparative_evidence.json
comparative_summary.csv
run_meta.json
```

If process-to-process handoff is required, use a temporary/versioned representation and explicitly define cleanup and provenance.

Do not freeze `comparative-draws-v1` until this is resolved.

---

# 3. High-Severity Findings

## H-01 — Pass 0 conflicts with `primary_delta = null`

`tasks.md` 1.6 says primary delta ambiguity should fail fast.

But the comparative reporting spec explicitly allows:

```text
primary_delta = null
```

and in that case computes direction + delta profile while disabling discrete practical classification.

### Fix

Require an explicit **delta state**, not an explicit numeric delta:

```yaml
practical_difference:
  mode: none | prespecified | policy
  primary_delta: null
```

`mode: none` is valid and MUST NOT block execution.

---

## H-02 — Survey weights are routed to an engine that does not exist

`pass0-analysis-routing` states that survey weights or IPTW weights should be rejected by Beta-Binomial and routed to design-aware inference.

But the current design-aware scope implements IPTW, not complex survey inference.

### Fix

Separate:

```text
IPTW / causal weights
```

from:

```text
survey sampling weights
```

For survey weights in v3:

```text
UNSUPPORTED_SURVEY_DESIGN
```

unless a dedicated survey inference contract is added.

---

## H-03 — Pass 0 should inspect duplicate subjects, not silently deduplicate

The Pass 0 spec says duplicate subjects under a PT are detected and subject-level deduplication is “enforced”.

### Risk

Deduplication changes the estimand unless the counting rule has already been approved.

### Fix

Pass 0:

- detect
- quantify
- propose counting rule
- require/record approval

Safety adapter/runtime:

- apply `at_least_one_qualifying_event_per_subject`
- produce raw vs deduplicated audit counts

Pass 0 should not silently transform data.

---

## H-04 — Safety hierarchy in `tasks.md` conflicts with the agreed/reporting spec

`tasks.md` 5.1 defines:

\[
SOC\rightarrow HLGT\rightarrow HLT\rightarrow PT
\]

as the canonical hierarchy.

But the design/spec and intended workflow use **SOC → PT** as the primary reporting hierarchy, with HLGT/HLT optional.

### Fix

Canonical report hierarchy:

```text
SOC -> PT
```

Optional provenance/drilldown:

```text
SOC -> HLGT -> HLT -> PT
```

Do not make HLGT/HLT mandatory for v3 primary output.

---

## H-05 — Safety pooled inference is not statistically specified

The spec requires study-specific and pooled summaries, but does not define what “pooled” means.

Simple aggregation:

\[
\frac{\sum x}{\sum n}
\]

implicitly assumes a common underlying risk and can conceal study-level heterogeneity / Simpson-type reversals.

### Fix

For v3 choose one of:

**Option A — recommended initial scope**
- study-specific inference is canonical
- aggregated pooled count result is allowed only as `descriptive_pooled`
- explicitly state that between-study heterogeneity is not modeled

**Option B**
- specify a stratified/hierarchical pooling model in a separate OpenSpec extension

Do not report an unqualified “pooled posterior”.

---

## H-06 — Delta profile grid is hard-coded despite “no universal delta”

`tasks.md` 2.8 fixes:

\[
\delta\in\{0.005,0.01,0.02,0.05,0.10\}
\]

This conflicts with the agreed principle that the system must not create an implicit medical policy.

### Fix

Make the grid configuration-driven:

```yaml
delta_profile:
  values: [0, 0.001, 0.0025, 0.005, 0.01]
  unit: probability
```

A convenience display grid may exist, but MUST be labeled non-normative and overrideable.

---

## H-07 — Automatic all-pairs threshold `group_count > 4` is arbitrary

`tasks.md` 4.7 adds a special cutoff at 4 groups.

### Fix

Use the simpler rule:

- 2 groups → one contrast
- >2 groups → explicit contrast set or reference-vs-all
- all-pairs → only when explicitly requested

No arbitrary “4 groups” boundary is required.

---

## H-08 — NNH/NNT suppression rule uses an arbitrary 0.05/0.95 cutoff

`tasks.md` 5.12 suppresses reciprocal-RD metrics when:

\[
P(RD>0)\in[0.05,0.95]
\]

This creates another unvalidated universal threshold.

### Fix

Canonical output should instead report:

```text
reciprocal_absolute_rd
reciprocal_status
```

with states such as:

```text
STABLE_DIRECTION
SIGN_AMBIGUOUS
RD_NEAR_ZERO
NOT_INTERPRETABLE
```

At minimum:

- if the RD interval spans 0, do not display a naive contiguous NNH confidence/credible interval
- reciprocal-RD remains secondary
- no universal 0.95 cutoff unless versioned policy explicitly adopts one

---

## H-09 — IPTW estimator contract is still too loose

The current plan says:

- refit propensity score in each bootstrap
- stabilized weights
- ATE / ATT
- SMD > 0.1 warning
- fail if bootstrap failures >5%

But it does not fully specify:

- estimand-specific weight formulas
- whether stabilization is mandatory or optional
- truncation/winsorization policy
- precomputed weights vs reproducible PS model
- positivity gate semantics

### Fix

Specify separately:

```text
iptw_mode = refit_ps
```

Canonical v3.5 should require:
- treatment variable
- baseline covariates
- exact PS model specification
- estimand = ATE | ATT
- weight formula
- stabilization policy
- truncation policy

If only externally generated weights are supplied, either:
- reject with a specific code, or
- define a separate `fixed_weight` mode with weaker inferential claims

Also make 0.1 SMD / 5% failure thresholds configurable operational policies, not universal statistical truths.

---

## H-10 — 1:k matching estimator is not uniquely defined

The current spec says:

> compute stratum-weighted **or** conditional event proportions

That is not a testable statistical contract.

### Fix before implementation

Specify:

- target estimand (usually ATT-like for matched treated cohort)
- matched-set weighting
- treatment/control contribution per set
- variable-ratio handling
- replacement/multiplicity handling
- bootstrap unit
- final marginal risk estimator

If this cannot be finalized now, keep 1:k matching as a future follow-up change rather than implementing an ambiguous estimator.

---

## H-11 — Decision-consistency `80% precedent consensus` is arbitrary

The spec says a decision differing from ≥80% of nearest precedents becomes a QA Review Candidate.

### Risk

This turns historical majority behavior into a quasi-decision threshold.

Historical decisions may also contain legacy inconsistency or policy drift.

### Fix

Make discordance policy versioned/configurable:

```yaml
discordance_policy:
  neighborhood: k_nearest | distance_radius
  k: null
  max_distance: null
  consensus_threshold: null
```

A useful default is to **show decision distribution and disagreement** without declaring a thresholded discordance unless a policy has been approved.

---

## H-12 — “Immutable decision ledger” is not guaranteed by the current storage architecture

The spec requires an immutable audit trajectory including user identity.

The current repository/file-output model does not by itself provide immutable storage or authenticated identity.

### Fix

For this repository define:

> append-only, tamper-evident decision ledger artifact

Possible fields:

```text
record_id
previous_record_hash
evidence_profile_sha256
decision_state
rationale
actor_id_source
timestamp_jst
```

True immutable/authenticated audit storage should remain an external operational-system responsibility unless explicitly implemented.

---

# 4. Additional High-Priority Design Corrections

## H-13 — Canonical H/N/B labels are not domain-neutral

`H/N/B` can imply harm/neutral/benefit, but the core is also used for prescription and generic RWD analyses.

### Fix

Canonical region names:

```text
TARGET_EXCESS
PRACTICAL_NEUTRAL
REFERENCE_EXCESS
```

Safety adapter may render:

```text
harm-side / neutral / reverse-side
```

when medically appropriate.

---

## H-14 — Multi-theme multiplicity / selection warning should be normative

Hundreds or thousands of PTs/themes will be screened.

Bayesian posterior probabilities do not automatically eliminate multiplicity or selection bias.

### Add requirement

For batch ranking/screening:

> Ranking, clustering, or large posterior direction probabilities are exploratory prioritization aids and do not constitute familywise/FDR control or automatic safety-signal confirmation.

This should appear in:
- spec
- report narrative
- decision-review input contract

---

## H-15 — New skills need explicit integration with `evidence-run-layout`

The existing canonical spec says **all statistical analysis skills** use:

```text
evidence_runs/<skill_slug>/run_<id>[_N]/
```

with run isolation and `run_meta.json`.

The current change creates new skills but does not include a delta modification/integration scenario for the canonical output-layout capability.

### Fix

Add a modified capability delta or explicit conformance requirement for:

- `vcd-categorical-reporting`
- `comparative-design-analysis`
- `evidence-decision-review`

including:
- canonical slug
- run root
- `run_meta.json`
- path-schema version
- collision behavior
- path safety

---

## H-16 — Existing dependency SSOT already contains a 23-vs-31 regression-suite drift

The current canonical file:

```text
openspec/specs/deterministic-r-dependencies/spec.md
```

still states that the canonical regression suite contains **23 tests**.

The current:

```text
tests/run_regression_suite.R
```

contains **31 official tests**.

This is pre-existing debt, but the new Change depends on this capability and proposes more tests/dependencies.

### Required precondition

Before or as part of this Change:

- remove fixed regression-test count from the canonical dependency spec
- reference `tests/run_regression_suite.R` as the dynamic registry/SSOT
- add dependency inventory/pre-flight tasks for any new packages used by:
  - Gower distance
  - HTML reporting
  - bootstrap/parallelism
  - HDI if retained

Do not introduce runtime package installation.

---

# 5. Medium Findings

## M-01 — Proposal wording “zero-cell numerators/denominators” is unsafe

A zero numerator is analyzable under Jeffreys inference.

A zero denominator is not.

Change wording to:

> zero-event cells / zero numerators

and keep `n=0` explicitly unanalyzable.

---

## M-02 — HDI appears in tasks but not in the canonical design

`tasks.md` 3.6 adds:

- mean
- ETI
- HDI

The design/spec only establishes median + ETI as canonical.

### Recommendation

For v3 core:
- median
- mean for group-level Beta risk may be optional
- 95% ETI canonical
- defer HDI unless explicitly specified and dependency-tested

Avoid unnecessary v3 scope expansion.

---

## M-03 — RR instability badge threshold is unspecified

The plan mentions:
- wide interval
- upper/lower ratio

but does not define the threshold.

### Recommendation

Persist continuous diagnostics:

```text
log_rr_eti_width
rr_interval_fold_range
```

Make badge threshold a versioned presentation policy, not a hidden hard-coded constant.

---

## M-04 — Evidence feature schema must handle missing q-values

When `primary_delta = null`, then practical-region probabilities are not defined.

The decision-review feature schema currently assumes them.

### Fix

Define:
- mandatory feature set
- optional feature set
- missing-value behavior in Gower calculation
- feature schema version

---

## M-05 — Historical comparisons require policy/dictionary version context

Safety precedent comparison can be distorted by:
- MedDRA version changes
- delta-policy changes
- different exposure windows
- different analysis populations

### Recommendation

Historical case metadata should bind:

```text
meddra_version
delta_policy_id
delta_policy_version
estimand
population_definition
time_window
feature_schema_version
```

Similarity retrieval should expose incompatibilities rather than silently compare them.

---

## M-06 — Parallel bootstrap is not yet reproducibility-safe by specification

`design.md` proposes parallel workers as an IPTW mitigation.

Parallel RNG can break deterministic reproduction if not explicitly controlled.

### Recommendation

Do not make parallelism a v3.5 requirement until a deterministic RNG-stream strategy is specified and regression-tested.

Start with reproducible serial bootstrap; optimize later.

---

# 6. File-by-File Revision Guidance

## `proposal.md`

Revise:

1. Replace “zero-cell numerators/denominators” with “zero-event numerators / zero cells”.
2. State `comparative-draws-v1` is a logical uncertainty-draw interface, not necessarily a persistent raw JSON artifact.
3. Add modified/inherited canonical capabilities:
   - `evidence-run-layout`
   - `deterministic-r-dependencies` when dependencies change.
4. Clarify that batch screening is exploratory and does not solve multiplicity.
5. Clarify pooled Safety inference method or mark pooled output descriptive-only.

---

## `design.md`

Revise:

1. Rename U-grade semantic to “practical-region resolution”.
2. Add separate precision metrics.
3. Replace generic “posterior draws” wording for bootstrap engines.
4. Fully specify Gamma-Poisson prior + parameterization.
5. Define draw persistence.
6. Remove/qualify parallel worker requirement.
7. Make 1:k matching estimator explicit.
8. Make IPTW mode and estimand-specific weighting explicit.
9. Make canonical practical regions domain-neutral.

---

## `specs/pass0-analysis-routing/spec.md`

Revise:

1. Pass 0 detects duplicates but does not silently deduplicate.
2. Explicitly support `primary_delta_state = none`.
3. Separate IPTW weights from survey weights.
4. Survey-weighted design should fail with explicit unsupported code until supported.
5. Bind routing decision to:
   - input hash
   - config hash
   - target engine
   - semantic type
   - unresolved owner decisions

---

## `specs/comparative-evidence-reporting/spec.md`

Revise:

1. Rename H/N/B canonical regions.
2. Define U-grade as region resolution, not generic precision.
3. Add separate interval-width precision fields.
4. Add batch multiplicity/selection guard.
5. Specify pooled Safety output semantics.
6. Clarify reciprocal RD/NNH behavior around zero.
7. Define raw-draw persistence behavior.

---

## `specs/comparative-design-inference/spec.md`

Revise before implementation:

1. Replace all bootstrap “posterior” wording.
2. Fully define matched 1:k estimator.
3. Fully define IPTW estimand/weights/refit contract.
4. Remove hard-coded generic SMD/failure thresholds or move to versioned operational policy.
5. Fully define Gamma-Poisson prior/parameterization.
6. Distinguish person-time Poisson assumptions from recurrent-event/overdispersion problems.

---

## `specs/evidence-decision-consistency/spec.md`

Revise:

1. Replace “objective” with “decision-label-free statistical evidence features”.
2. Define optional/missing feature behavior.
3. Remove hard-coded 80% consensus rule.
4. Define neighborhood and discordance policy explicitly.
5. Replace “immutable” with append-only/tamper-evident unless an immutable store exists.
6. Bind historical cases to policy/dictionary/schema versions.
7. Keep decision labels excluded from cluster construction.

---

## `tasks.md`

Correct at minimum:

- 1.6: allow explicit `primary_delta = null`
- 2.8: remove hard-coded universal delta grid
- 3.6: remove HDI unless newly specified
- 4.7: remove arbitrary `>4` all-pair boundary
- 5.1: canonical Safety reporting hierarchy = SOC → PT
- 5.11: do not call subject proportion “Incidence Rate”
- 5.12: remove hard-coded 0.05/0.95 NNH suppression rule
- 10.11: make bootstrap-failure threshold versioned/configurable
- 13.9: replace unsupported “immutable ledger” claim
- add output-layout/dependency-inventory tasks
- add selection/multiplicity narrative tests
- add pooled-Safety semantics tests

---

# 7. Recommended Revised Architecture

```text
Pass 0
  |
  +-- independent binary ----------------------+
  |                                            |
  +-- matched/IPTW/rate -> design engine ------+--> shared contrast engine
                                               |
                                               +--> comparative_evidence
                                                        |
                                                        +--> domain report
                                                        |
                                                        +--> optional decision review
```

Important runtime rule:

> Separate **skill responsibility**, but do not require raw Monte-Carlo draws to be permanently serialized between every layer.

---

# 8. Recommended Implementation Order After OpenSpec Repair

## Phase 0A — OpenSpec repair only

Do not write production R code yet.

1. Fix Blocker/High issues above.
2. Add/update affected capability specs.
3. Resolve deterministic dependency-spec drift.
4. Run strict OpenSpec validation.
5. Obtain Owner approval.

## Phase 1 — Small vertical slice

Implement only:

- Pass 0 independent-binary route
- long-format multi-theme input
- Jeffreys Beta-Binomial
- zero-cell handling
- RD
- RR median + ETI
- excess per 100
- direction support
- configurable delta profile
- practical-region resolution
- Safety SOC/PT adapter
- canonical evidence JSON
- offline report
- golden test cases

Do **not** implement IPTW, clustering, or historical decision review until Phase 1 passes independent QA.

## Phase 2 — Design-aware inference

Implement:
- 1:1 matching first
- Gamma-Poisson rate
- then IPTW
- then 1:k matching after estimator contract is finalized

## Phase 3 — Decision consistency

Implement only after the comparative evidence schema is stable.

---

# 9. Required Golden Tests

At minimum:

```text
3/100 vs 0/100
0/100 vs 0/100
30/100 vs 20/100
3/30 vs 30/300
1/200 vs 0/1000
1/200 vs 2/1000
0/200 vs 2/1000
```

Required properties:

1. zero-event posterior is proper
2. RD summaries finite
3. RR median/quantiles finite when numerically valid
4. theoretical RR mean is not reported when non-finite
5. delta profile monotone
6. region probabilities sum to one
7. no practical-region color when delta state is `none`
8. domain label changes do not alter statistical output

---

# 10. Go / No-Go Criteria

## NO-GO for implementation while any of the following remain unresolved

- U-grade still described as generic estimation precision
- bootstrap still called posterior
- person-time prior not pinned
- raw draw persistence undefined
- primary-delta null semantics contradictory
- 1:k matched estimator ambiguous
- IPTW estimand/weight contract ambiguous
- Safety pooled inference undefined
- hard-coded medical/QA thresholds remain unexplained

## GO after

- all Blocker findings corrected
- High findings either corrected or explicitly deferred out of scope
- `openspec validate ... --strict` passes
- canonical dependency/run-layout contracts are synchronized
- Owner explicitly approves implementation

---

# 11. Repository Decision

**Keep this work in `agentic-evidence-analysis`.**

Do not create a separate repository at this stage.

Reason:

- statistical contracts already live here
- OpenSpec is already the SSOT here
- regression and quality contracts are here
- splitting now would create duplicated schemas and drift

A future external operational system for:
- historical decision database
- authenticated user workflow
- immutable regulated audit storage

may live elsewhere, but it should consume versioned schemas defined in this repository.

---

# 12. Critical Position

The current plan is promising precisely because it avoids reducing safety/RWD evidence to one p-value.

The same discipline must be applied to the new Bayesian layer.

The following must remain separate:

\[
\boxed{
\text{Effect magnitude}
\neq
\text{Direction}
\neq
\text{Practical relevance}
\neq
\text{Region resolution}
\neq
\text{Numerical precision}
\neq
\text{Design validity}
\neq
\text{Human decision}
}
\]

The most important correction is therefore not a code change but a semantic one:

> **Do not let U-grade become a new single-number “truth score”.**

Similarly:

> **Do not let precedent-cluster majority become a new automatic regulatory rule.**

The system should expose uncertainty and historical inconsistency so that reviewers can make better decisions; it should not silently replace one threshold culture with another.

---

# 13. Final Review Result

**Result: CONDITIONAL HOLD**

The OpenSpec Change should be revised before implementation.

The architecture should be retained.

The highest-value next action is:

1. patch OpenSpec only,
2. re-review the revised Change,
3. run strict validation,
4. then begin the Phase-1 vertical slice.
