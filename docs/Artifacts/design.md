# Design: Comparative Evidence Reporting v3

status: proposed  
change: `comparative-evidence-reporting-v3`  
target repository: `syrius2000/agentic-evidence-analysis`

## 1. Design goals

The system SHALL support the recurring comparison pattern:

\[
x_T/n_T \quad \text{vs} \quad x_R/n_R
\]

across:

- clinical-trial safety
- post-marketing surveillance
- RWD
- purchased prescription data
- generic binary comparative analyses

while preserving statistical meaning for:
- zero cells
- unequal denominators
- matching
- IPTW
- person-time rates
- uncertainty and practical relevance
- historical decision consistency

The design MUST separate:

\[
Domain \ne Design \ne Inference \ne Contrast \ne Decision
\]

---

## 2. Architectural decisions

### Decision 1 — Keep the implementation in `agentic-evidence-analysis`

**Choice:** same repository.

**Reason:** this repository is already the statistical source of truth and OpenSpec owner. Splitting now would duplicate schemas, math contracts, tests, and versioning.

**Boundary:** DB extraction / operational RWD integration stays outside. Future decision-workflow services may split operationally, but import the canonical schemas from this repository.

### Decision 2 — Revive `vcd-categorical-reporting`, but do not turn it into a monolith

`vcd-categorical-reporting` becomes the common comparative evidence/reporting layer.

It SHALL own:
- independent-binomial Jeffreys inference
- common contrast transforms
- domain reporting profiles
- uncertainty presentation

It SHALL NOT own:
- IPTW model fitting
- matching construction
- propensity-score estimation
- historical decision clustering

Those are separate skills.

### Decision 3 — Pass 0 is a consultation gateway

`vcd-pass0-consultation` routes analysis based on the estimand and design, not on the domain name alone.

Inputs it resolves:
- estimand
- analysis unit
- target/reference orientation
- weighting/matching/repeated structure
- practical-difference status
- domain hierarchy
- reporting purpose
- decision-review requirement

Outputs:
- `analysis_config.json`
- `analysis_scope.md`
- `routing_decision.json`

Pass 0 MAY recommend, but SHALL NOT silently decide material clinical/statistical policy.

### Decision 4 — All downstream comparison logic consumes draws

Common interface:

```text
draw_id
target_value
reference_value
scale
inferential_semantics
method
estimand
```

This permits the same contrast layer to consume:
- Beta posterior draws
- matched Dirichlet posterior draws
- Gamma-Poisson posterior draws
- bootstrap draws

The contrast layer SHALL NOT infer the semantic type from numeric values.

### Decision 5 — Posterior and bootstrap semantics remain distinct

For posterior draws:

\[
P(RD>0|D)
\]

For bootstrap:

\[
\frac{1}{B}\sum_b I(RD_b>0)
\]

These may be numerically similar but are not semantically identical.

Schema requires `inferential_semantics`. Presentation labels SHALL be generated from that field.

---

## 3. Statistical design

### 3.1 Independent risk engine

\[
p_g|D \sim Beta(x_g+0.5,n_g-x_g+0.5)
\]

Primary estimator is the posterior median, not the raw maximum-likelihood proportion, though raw n/N remains visible.

Generated quantities:
- risk difference
- risk ratio
- excess per 100
- direction support
- practical-difference profile

No continuity correction is required for zero cells.

### 3.2 RR zero-cell design

A zero reference event count yields a posterior shape \(a=0.5\).

Because:

\[
E(1/p)=\infty \quad \text{for } p\sim Beta(a,b),\ a\le1
\]

the RR posterior mean may not exist.

The system SHALL:
- use median + ETI as the canonical RR summary
- explicitly mark a non-finite theoretical mean
- never substitute a finite Monte-Carlo sample mean

This is a mathematical contract, not a display preference.

### 3.3 Practical-difference design

Primary classification requires an approved \(\delta\).

No universal default.

When available:

\[
q_H=P(RD>\delta)
\]
\[
q_N=P(|RD|\le\delta)
\]
\[
q_B=P(RD<-\delta)
\]

When unavailable:
- retain direction support
- retain full delta profile
- no practical-region classification

Delta natural-unit conversion SHALL be supported:
- per 100
- per 1,000
- absolute probability

Example: “2 additional subjects per 1,000” -> \(\delta=0.002\).

### 3.4 Uncertainty design

If a primary delta exists:

\[
C=\max(q_H,q_N,q_B)
\]

Provisional display grades:
- U0: >= .95
- U1: [.80, .95)
- U2: [.60, .80)
- U3: < .60

The exact thresholds are configuration/version data, not hard-coded medical truths.

Additional continuous diagnostics:
- RD interval width
- log-RR interval width
- posterior/resampling SD if appropriate
- event-count flags

A sparse flag does not itself define uncertainty grade.

### 3.5 Visual encoding

The table MUST NOT use “red = high posterior direction probability”.

Allowed encoding when an approved delta exists:
- hue: dominant practical region
- opacity/saturation: certainty
- text/badge: sparse/zero/design issues

U3 must visually read as “uncertain”, not “severe”.

If no primary delta:
- no H/N/B practical-color encoding
- direction remains numeric/textual

---

## 4. Safety domain design

### 4.1 Hierarchy

Canonical standard report:

```text
SOC
  PT
```

HLGT/HLT:
- retained if supplied
- optional drill-down
- not required primary report hierarchy

### 4.2 Counting

PT:
- one subject counted once if at least one qualifying event

SOC:
- one subject counted once if at least one child PT in the SOC

Standard aggregation uses Primary SOC.

### 4.3 Provenance

Required:
- MedDRA version
- counting rule
- analysis population
- study
- arm
- treatment-emergent definition when applicable

### 4.4 Study pooling

Pooled results SHALL NOT destroy study-level evidence.

Output keeps both:
- study-specific
- pooled

No causal interpretation is introduced by pooling.

---

## 5. Generic RWD / Prescription domain design

The core hierarchy is:

```text
parent_theme
  item_theme
```

Canonical core fields remain domain-neutral.

RWD context MAY include:
- exposure definition
- outcome definition
- index date
- follow-up
- database
- eligibility

Prescription context MAY include:
- therapeutic class
- ingredient/product
- new-user/switch/add-on definition
- observation window

---

## 6. Design-aware skill

### 6.1 Skill boundary

`comparative-design-analysis` produces uncertainty draws and diagnostics.

It does not own the final report or historical decision review.

### 6.2 1:1 matched design

Use four joint outcome cells:

```text
T=1,R=1
T=1,R=0
T=0,R=1
T=0,R=0
```

with:

\[
Dirichlet(0.5,0.5,0.5,0.5)
\]

This preserves pair dependence.

### 6.3 1:k matching

Use matched-set resampling.

Atomic sampling unit = matched set.

Never split a matched set within a bootstrap replicate.

### 6.4 IPTW

Bootstrap unit = patient.

Every replicate:
1. resample patients
2. refit propensity model
3. reconstruct weights
4. apply configured stabilization/truncation
5. compute weighted marginal risks

Required diagnostics:
- ESS
- balance
- overlap
- extreme weights
- bootstrap failure

Weighted pseudo-events SHALL NOT be passed to the independent-binomial engine.

### 6.5 Repeated / clustered data

First ask whether the estimand can be collapsed to one subject-level binary outcome.

If yes:
- collapse and use independent/matched design as appropriate.

If no:
- cluster bootstrap is the first extension.
- GLMM/GEE requires a separate explicit specification before canonical use.

---

## 7. Decision review design

### 7.1 Separation of evidence and decision

Evidence features are constructed without label/regulatory decision fields.

Decision fields are overlaid after evidence similarity is computed.

This prevents circular clustering.

### 7.2 Similarity

Primary mixed-data distance:
- Gower

Primary clustering:
- hierarchical

Optional:
- standardized continuous-feature K-means

### 7.3 Historical precedent

For a new item, retrieve nearest historical evidence profiles and display:
- similarity/distance
- historical decision
- rationale
- version/date

The system does not recommend a regulatory choice.

### 7.4 Discordance

A discordance candidate means:
- similar evidence
- different decision

It SHALL be worded as a QA review candidate.

Not:
- “error”
- “incorrect decision”

unless human adjudication establishes that conclusion.

### 7.5 Trajectory

Evidence can be indexed by:
- study
- phase
- submission
- post-marketing cutoff

The system can display how effect/direction/uncertainty evolved over time.

---

## 8. Schema design

### 8.1 `comparative-draws-v1`

```json
{
  "schema": "comparative-draws-v1",
  "scale": "risk",
  "inferential_semantics": "posterior",
  "method": "independent_beta_binomial_jeffreys",
  "estimand": "subject_risk",
  "draws": [
    {"draw_id": 1, "target_value": 0.03, "reference_value": 0.01}
  ],
  "diagnostics": {}
}
```

### 8.2 `comparative-evidence-v1`

```json
{
  "schema": "comparative-evidence-v1",
  "context": {},
  "theme": {},
  "contrast_definition": {},
  "group_summaries": {},
  "effect": {},
  "direction": {},
  "practical_difference": {},
  "uncertainty": {},
  "diagnostics": {},
  "provenance": {}
}
```

### 8.3 Route schema

`routing_decision.json` contains:
- selected engine
- selected reporting profile
- selected optional review skill
- reasons
- blockers
- unresolved owner decisions

---

## 9. Compatibility design

Existing:
- `vcd-categorical-analysis`: contingency-table association / residual analysis
- `vcd-bayesian-evidence-analysis`: 3-way table structure / loglinear evidence analysis

New comparative reporting MUST NOT absorb or redefine those capabilities.

Routing example:

```text
Question: "Are treatment and placebo event proportions different for many PTs?"
 -> comparative reporting

Question: "Which cells drive association in a 2-way contingency table?"
 -> vcd-categorical-analysis

Question: "What 3-way interaction structure is supported?"
 -> vcd-bayesian-evidence-analysis
```

---

## 10. Repository governance

OpenSpec is authoritative.

Required synchronization after acceptance:
- `openspec/specs/...`
- `AGENTS.md`
- `docs/reference/skill_responsibilities.md`
- skill `SKILL.md`
- JSON schemas
- R implementation
- tests

Archive documents remain historical evidence and are not mass-rewritten.

---

## 11. Security / reproducibility

All generated runs:
- use existing `evidence_runs/<skill_slug>/run_<id>[_N]/`
- bind `run_meta.json`
- preserve deterministic seed where posterior Monte Carlo is used
- remain offline/self-contained for final HTML
- do not runtime-install packages
- do not expose absolute local paths

Bootstrap runs record:
- seed
- number of replicates
- failed replicates
- model/weight config hash

---

## 12. Rejected alternatives

### Alternative A — One giant `vcd-categorical-reporting`
Rejected because IPTW, matching, clustering, reporting, and decision history have distinct validation requirements.

### Alternative B — Separate new repository now
Rejected because it creates statistical SSOT duplication and OpenSpec drift.

### Alternative C — Universal delta = 0.5% or 1%
Rejected because clinical meaning differs by event severity/context and domain.

### Alternative D — Event-count thresholds define uncertainty
Rejected because 0/200 vs 2/1000 may provide meaningful information about large absolute risk differences despite few events.

### Alternative E — Posterior probability alone drives red color
Rejected because direction is not the same as magnitude, practical importance, or precision.

### Alternative F — Continuity-corrected raw RR as primary zero-cell solution
Rejected because Jeffreys posterior directly handles zero risk uncertainty and provides coherent generated quantities.

---

## 13. Critical design principle

The platform SHALL preserve this separation:

```text
Effect        = how large?
Direction     = which way?
Practical     = large enough to matter under prespecified policy?
Uncertainty  = how well resolved?
Design        = how was comparability constructed?
Decision      = what did humans decide, and was it consistent?
```

No single score may collapse these dimensions in the canonical output.
