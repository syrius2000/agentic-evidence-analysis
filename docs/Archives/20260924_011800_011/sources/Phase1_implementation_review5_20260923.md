# Independent Code Review — Phase 2 Section 8 Matched-Pair OR Semantics

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Reviewed commit:** `b80d7e983502178808bf95d065d15b87c7605d72`  
**Baseline:** `e40c18a269e0c0bfe8e675dc57a4427825ee11bf`  
**Implementation Plan:** `docs/Artifacts/implementation_plan_003_0923.md`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Independent static code/spec review  
**Verdict:** **CONDITIONAL PASS — mathematical correction is sound; two semantic-contract High findings remain**

## 1. Executive Summary

The core statistical correction in this commit is correct.

The previous implementation stored

\[
\frac{p_{11}p_{00}}{p_{10}p_{01}}
\]

under the generic field `matched_pair.odds_ratio`. For paired binary data this is not the standard matched-pair odds ratio comparing the two members of a pair. The revised implementation correctly makes the primary matched-pair odds ratio

\[
OR_{\text{matched}}
=
\frac{p_{10}}{p_{01}},
\]

which depends only on discordant pairs, and moves the cross-product quantity to:

```text
matched_pair.intra_pair_association_or
```

This is mathematically and epidemiologically well motivated.

The theoretical posterior-mean finiteness logic is also correct under the Jeffreys-type Dirichlet posterior.

No Blocker-level mathematical defect was found.

However, two High findings remain:

1. `conditional treatment-effect OR` is causally stronger terminology than the supported matched observational design warrants.
2. `matched_pair.odds_ratio` changed meaning at the same output path, while the JSON schemas do not actually define or validate the matched-pair extension. This is a semantic API breaking change that schema validation will not catch.

Several Medium improvements are also recommended, especially replacing Monte-Carlo posterior means with exact analytic means.

## 2. Mathematical Review

### 2.1 Cell definitions

For paired binary responses:

| | Reference=1 | Reference=0 |
|---|---:|---:|
| Target=1 | \(p_{11}\) | \(p_{10}\) |
| Target=0 | \(p_{01}\) | \(p_{00}\) |

The implementation uses:

\[
p_T=p_{11}+p_{10}
\]

\[
p_R=p_{11}+p_{01}
\]

and therefore:

\[
RD=p_T-p_R=p_{10}-p_{01}.
\]

This is correct.

### 2.2 Primary matched-pair odds ratio

The revised implementation uses:

```r
conditional_or_draws <- p10 / p01
```

or mathematically:

\[
OR_{\text{discordant}}
=
\frac{p_{10}}{p_{01}}.
\]

This is the standard matched-pair odds ratio based on discordant pairs.

The McNemar null hypothesis corresponds to:

\[
p_{10}=p_{01},
\]

or equivalently:

\[
OR_{\text{discordant}}=1.
\]

Therefore the correction from the old cross-product ratio to \(p_{10}/p_{01}\) is appropriate.

**Verdict: PASS**

### 2.3 Intra-pair association odds ratio

The old quantity is preserved as:

```r
intra_pair_association_or
```

with:

\[
OR_{\text{association}}
=
\frac{p_{11}p_{00}}{p_{10}p_{01}}.
\]

This cross-product odds ratio measures association between the two binary outcomes within a pair.

It is a different estimand from the discordant-pair matched odds ratio and should not be presented as the primary treatment/comparison odds ratio.

Separating the two quantities is therefore correct.

**Verdict: PASS**

## 3. Dirichlet Posterior and Mean Finiteness

The posterior is:

\[
(p_{11},p_{10},p_{01},p_{00})
\sim
Dirichlet(\alpha_{11},\alpha_{10},\alpha_{01},\alpha_{00})
\]

with:

\[
\alpha_{jk}=n_{jk}+0.5.
\]

Using the gamma representation of a Dirichlet distribution:

\[
p_j=\frac{G_j}{\sum_k G_k},
\qquad
G_j\sim Gamma(\alpha_j,1)
\]

independently.

### 3.1 Conditional matched-pair OR mean

Since the common denominator cancels,

\[
\frac{p_{10}}{p_{01}}
=
\frac{G_{10}}{G_{01}}.
\]

Therefore:

\[
E\left[\frac{p_{10}}{p_{01}}\right]
=
\frac{\alpha_{10}}{\alpha_{01}-1}
\]

when:

\[
\alpha_{01}>1.
\]

With the Jeffreys-type prior:

\[
\alpha_{01}=n_{01}+0.5.
\]

Thus the mean is finite iff:

\[
n_{01}\ge 1.
\]

The code uses:

```r
conditional_or_mean_finite <- cell_counts[["n01"]] > 0L
```

which is exactly correct for integer counts.

**Verdict: PASS**

### 3.2 Intra-pair association OR mean

Because the common Dirichlet normalization again cancels:

\[
OR_{\text{association}}
=
\frac{G_{11}G_{00}}{G_{10}G_{01}}.
\]

Its posterior mean is:

\[
E(OR_{\text{association}})
=
\frac{\alpha_{11}\alpha_{00}}
     {(\alpha_{10}-1)(\alpha_{01}-1)}
\]

provided:

\[
\alpha_{10}>1
\quad\text{and}\quad
\alpha_{01}>1.
\]

Under the \(+0.5\) prior this means:

\[
n_{10}\ge1
\quad\text{and}\quad
n_{01}\ge1.
\]

The implementation uses:

```r
association_or_mean_finite <-
  cell_counts[["n10"]] > 0L &&
  cell_counts[["n01"]] > 0L
```

which is correct.

**Verdict: PASS**

## 4. Test Review

The updated tests materially improve semantic protection.

They now independently recompute:

```r
median(p10 / p01)
```

and:

```r
median((p11 * p00) / (p10 * p01))
```

from persisted cell-probability draws and compare them against the two output fields.

This is a strong test because it fixes the meaning of each output path rather than merely checking that a value exists.

The tests also check:

- reproducible fixed-seed output;
- matched-pair cell counts;
- RD identity;
- marginal risks;
- zero \(n_{01}\) suppressing the conditional OR mean;
- zero \(n_{10}\) suppressing only the association-OR mean.

**Verdict: PASS**

## 5. HIGH H-01 — `treatment-effect` terminology is too causal for the general matched-pair engine

The OpenSpec now calls:

```text
conditional treatment-effect OR
```

for:

\[
p_{10}/p_{01}.
\]

The numerical quantity is correct, but the label is stronger than the supported design contract.

The same repository's `comparative-design-analysis/SKILL.md` explicitly says that results must not be interpreted as causal superiority.

For randomized paired treatment assignment, a treatment-effect interpretation may be defensible under the design.

For observational propensity-score matched pairs, however, matching alone does not make the contrast a causal treatment effect. Exchangeability, positivity, consistency, appropriate matching/analysis assumptions, and residual confounding considerations remain necessary.

### Recommended terminology

Prefer one of:

```text
matched_pair_odds_ratio
discordant_pair_odds_ratio
conditional_matched_pair_or
```

and describe it as:

> odds ratio comparing the two discordant pair orientations.

Avoid making `treatment-effect` part of the canonical statistical field definition.

**Severity: HIGH semantic/governance risk**

## 6. HIGH H-02 — `matched_pair.odds_ratio` is a semantic breaking change not protected by schema

Before this commit:

```text
matched_pair.odds_ratio
```

meant:

\[
\frac{p_{11}p_{00}}{p_{10}p_{01}}.
\]

After this commit the same path means:

\[
\frac{p_{10}}{p_{01}}.
\]

That is an intentional correction, but it is still a semantic API breaking change.

### Internal repository impact

No existing reporting consumer was found in the reviewed relevant files that reads:

```text
matched_pair.odds_ratio
```

so there is no identified internal downstream break.

However, an external consumer of the JSON/R object could silently receive a completely different number at the same path.

### Schema issue

Neither:

```text
schemas/comparative-evidence-v1.json
```

nor:

```text
schemas/comparative-draws-v1.json
```

defines:

```text
matched_pair
matched_pair.odds_ratio
matched_pair.intra_pair_association_or
matched_pair_counts
cell_probability_draws
```

The schemas allow these fields only because `additionalProperties` is permissive by default.

Therefore schema validation does **not** validate the matched-pair OR contract itself.

### Recommended repair

At minimum add an optional matched-pair extension to `comparative-evidence-v1`.

Also consider explicit metadata:

```yaml
odds_ratio_definition: discordant_pair_p10_over_p01
```

or:

```yaml
matched_pair_semantics_version: "1"
```

This makes the meaning machine-auditable.

**Severity: HIGH contract/versioning risk**

## 7. MEDIUM M-01 — Use exact analytic posterior means instead of Monte-Carlo means

The implementation correctly determines whether the theoretical mean exists, but when it exists it returns:

```r
mean(or_draws)
```

rather than the exact posterior mean.

For the conditional OR:

\[
E(OR_{\text{discordant}})
=
\frac{\alpha_{10}}{\alpha_{01}-1}.
\]

For the association OR:

\[
E(OR_{\text{association}})
=
\frac{\alpha_{11}\alpha_{00}}
     {(\alpha_{10}-1)(\alpha_{01}-1)}.
\]

These are available analytically.

With sparse discordant data the mean can exist while the variance is infinite, so Monte-Carlo means may be unstable.

For the test fixture:

\[
(n_{11},n_{10},n_{01},n_{00})=(3,2,1,4),
\]

the exact means are:

```text
conditional matched OR mean = 5
association OR mean = 21
```

Keep Monte-Carlo medians and ETIs, but calculate `mean` analytically.

**Severity: MEDIUM**

## 8. MEDIUM M-02 — `pmax(..., 1e-15)` silently truncates posterior tails

The implementation uses:

```r
pmax(p01, 1e-15)
```

and:

```r
pmax(p10 * p01, 1e-15)
```

to prevent numerical division by very small values.

This is pragmatic but imposes an undocumented upper-tail cap.

Prefer log-ratios:

\[
\log OR_c = \log p_{10}-\log p_{01}
\]

\[
\log OR_a =
\log p_{11}+\log p_{00}-\log p_{10}-\log p_{01}
\]

and calculate median/quantiles on the log scale before exponentiating.

**Severity: MEDIUM**

## 9. MEDIUM M-03 — Boundary tests should be completed symmetrically

Recommended additional tests:

```text
n10>0, n01=0:
  association mean must also be non-finite

n10=0, n01=0:
  conditional mean non-finite
  association mean non-finite
```

Also test exact analytic means in a finite case.

**Severity: MEDIUM**

## 10. MEDIUM M-04 — Skill documentation does not expose the OR distinction

`comparative-design-analysis/SKILL.md` documents RD and marginal risks but does not explain either OR.

Add:

```text
odds_ratio = p10/p01
intra_pair_association_or = p11*p00/(p10*p01)
```

and explain that they answer different questions.

**Severity: MEDIUM documentation**

## 11. Specification Consistency

- `design.md`: PASS, subject to H-01 terminology.
- `comparative-design-inference/spec.md`: PASS, subject to H-01.
- `tasks.md`: PASS.
- `implementation_plan_003_0923.md`: PASS.

## 12. Downstream Compatibility

`compute_comparative_contrasts()` continues to produce the common marginal evidence:

- target/reference risks;
- marginal RR;
- RD;
- direction support;
- practical-region support.

The matched-pair OR is added separately under:

```text
evidence$matched_pair
```

and does not overwrite the common marginal RR.

No common-contrast regression was found.

However:

```text
schema-valid != matched-pair contract validated
```

because matched-specific fields are currently outside the defined schemas.

## 13. CI / Execution Evidence

GitHub reports for:

```text
b80d7e983502178808bf95d065d15b87c7605d72
```

- no workflow runs;
- no combined commit statuses.

The implementation plan records:

```text
test_matched_pair_dirichlet.R: 20/20 PASS
test_comparative_schemas.R: 37/37 PASS
full regression: 39/39 PASS
OpenSpec strict validation: valid
git diff --check: success
```

These are implementer-reported local verification results.

This independent review verified the code/test/spec logic but did not independently execute the repository suite.

## 14. Final Gate

### Mathematical correction

**PASS**

### Mean-finiteness logic

**PASS**

### OpenSpec implementation consistency

**PASS**

### Output/API contract

**CONDITIONAL PASS**

because of:

- H-01 causal terminology;
- H-02 semantic API/schema versioning.

## 15. Recommended Minimal Repair

Before closing Section 8:

1. replace `conditional treatment-effect OR` with a neutral label such as `discordant-pair matched OR`;
2. retain the field if desired, but add `odds_ratio_definition = "p10_over_p01"`;
3. add `matched_pair` structure to the evidence schema;
4. preferably add matched-specific fields to the draws schema;
5. calculate finite posterior means analytically;
6. add symmetric zero-discordant boundary tests;
7. update `comparative-design-analysis/SKILL.md`.

No change to the primary formula \(p_{10}/p_{01}\) is recommended.

## 16. Final Verdict

**CONDITIONAL PASS**

The commit fixes the central statistical error correctly.

The remaining work is semantic-contract hardening rather than a redesign of the matched-pair model.

\[
\boxed{
OR_{\text{discordant pair}}
=
\frac{p_{10}}{p_{01}}
\ne
\frac{p_{11}p_{00}}{p_{10}p_{01}}
=
OR_{\text{within-pair association}}
}
\]
