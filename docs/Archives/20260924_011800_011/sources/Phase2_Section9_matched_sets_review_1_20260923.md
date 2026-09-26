# Independent Code Review — Phase 2 Section 9: 1:k Matched Sets Inference Engine

Repository: `syrius2000/agentic-evidence-analysis`  
Reviewed commit: `51f846b8ea8db7604156fc1b1a65b3a15310773b`  
Baseline: `7987cb6e1f46a999964c9faabb5a62b17ffec95d`  
Review date: 2026-09-23 (JST)  
Verdict: **HOLD — ATT estimator and atomic set bootstrap mechanics are sound, but SMD/output-contract defects block Section 9 acceptance**

## Executive summary

The observed-sample ATT estimator is correctly implemented for one treated subject per matched set and variable numbers of controls:

- treated risk = mean of one treated outcome per set;
- reference risk = mean of within-set control means.

Thus each treated set contributes equally and each control within set j receives relative weight 1/k_j. This is the correct fixed-matched-sample ATT construction.

The bootstrap also resamples matched sets atomically: the same sampled set indices are applied to treated and reference set contributions. Inferential terminology is properly separated (`bootstrap`, `observed_sample_estimate`, `bootstrap_percentile`, bootstrap support fraction).

However, three acceptance-critical defects remain:

1. SMD can return 0.0 for complete covariate separation when both within-group variances are zero.
2. Under variable matching ratios, `reference_cohort.events/total` is raw-control risk while `incidence_proportion` and `estimate.value` are ATT-weighted risk, so one object contains two different estimands.
3. Zero-reference RR is forced finite by the `1e-15` denominator floor, contradicting the implementation plan's stated `mean_is_finite = FALSE`.

Additional High findings: the matched SMD denominator does not use ATT-consistent control weighting; `smd_unmatched` is not truly pre-match; `replacement=false` is asserted without subject-ID validation; the output lacks machine-readable `estimand=ATT` and bootstrap scope metadata.

## ATT estimator — PASS

For set j with one treated subject and k_j controls:

p_T = (1/J) sum_j Y_Tj

p_R = (1/J) sum_j [(1/k_j) sum_l Y_Rjl]

The code implements exactly this. The variable-ratio test (1:1, 1:2, 1:3) correctly expects p_R = (1 + 0.5 + 0)/3 = 0.5, rather than the raw control event fraction 2/6.

## Atomic set bootstrap — PASS mechanically

`sample.int(J, J*B, replace=TRUE)` generates set indices, and the same index matrix is used for both y_T and y_R_bar. Therefore within-set pairing is preserved in every bootstrap replicate.

This should be described as uncertainty **conditional on the fixed matched sets**. It does not re-estimate propensity scores or repeat the matching algorithm.

## BLOCKER B-01 — Zero-variance SMD can falsely report perfect balance

Current logic:

```r
s_pooled <- sqrt((var_T + var_R_raw) / 2)
smd_matched <- if (s_pooled > 1e-12) (mean_T - mean_R_weighted) / s_pooled else 0.0
```

If all treated covariate values are 1 and all controls are 0:

- mean difference = 1;
- both variances = 0;
- s_pooled = 0;
- returned SMD = 0.

This reports perfect balance for complete separation.

Required policy:

- zero denominator + zero difference -> SMD 0;
- zero denominator + nonzero difference -> `null` plus explicit status such as `ZERO_VARIANCE_NONZERO_DIFFERENCE`.

## BLOCKER B-02 — `reference_cohort` mixes raw and ATT-weighted estimands

The engine passes raw control counts to the common contrast engine, then overwrites only the reference incidence and estimate with ATT-weighted values.

In the current variable-ratio test:

- raw controls: events=2, total=6 => 0.3333;
- ATT-weighted reference risk: 0.5.

The resulting object can therefore imply:

```yaml
reference_cohort:
  events: 2
  total: 6
  incidence_proportion: 0.5
  estimate.value: 0.5
```

A downstream consumer recomputing events/total gets a different risk.

Fix by separating raw descriptive counts from the ATT-weighted estimand, e.g. `raw_events/raw_total` plus explicit `estimate_semantics: att_set_weighted_risk`, or define a matched-set-specific cohort summary.

## BLOCKER B-03 — Zero-reference bootstrap RR is artificially finite

The common bootstrap engine uses:

```r
rr_draws <- target_draws / pmax(reference_draws, 1e-15)
rr_mean <- mean(rr_draws)
rr_mean_finite <- is.finite(rr_mean)
```

For the zero-reference test, all reference bootstrap risks are zero. They become 1e-15, producing huge finite RR values and `mean_is_finite=TRUE`.

This contradicts the implementation plan, which states that zero-reference RR should have a null point estimate and `mean_is_finite=FALSE`.

Recommended zero-reference policy:

```yaml
relative_risk:
  estimate.value: null
  interval.lower: null
  interval.upper: null
  mean: null
  mean_is_finite: false
  diagnostic: ZERO_REFERENCE_RISK
```

If only some bootstrap replicates have zero denominator, record the number/fraction of undefined RR replicates and define a governed interval policy. Do not turn undefined ratios into finite evidence with `1e-15`.

## HIGH H-01 — SMD weighting is inconsistent with ATT weights

The numerator uses an ATT-weighted control mean:

```r
mean_R_weighted <- mean(x_R_bar)
```

but the denominator uses the variance of raw control rows:

```r
var_R_raw <- var(x_R_raw)
```

With variable k_j, large matched sets receive more influence in the variance than in the mean. The balance metric therefore mixes two weighting systems.

Use ATT-consistent control weights (each control within set j weighted proportional to 1/k_j) for the matched balance calculation, or use a clearly prespecified fixed standardization denominator.

## HIGH H-02 — `smd_unmatched` is not actually pre-match balance

Only matched data are provided to `compute_covariate_balance()`. The function's `smd_unmatched` compares treated subjects against the raw controls that survived matching.

That is not the pre-match cohort.

Either:

- remove `smd_unmatched` from this matched-only engine; or
- require pre-match data / pre-match reference moments if true before-vs-after balance is required.

## HIGH H-03 — `replacement=false` is not verifiable

The engine requires no subject identifier but outputs:

```yaml
replacement: false
```

Without `subject_id`, it cannot detect reuse of the same control in multiple sets.

This is both a provenance problem and an inferential problem: shared controls would create dependence between matched sets, violating the cluster-resampling assumption.

Require subject IDs and verify uniqueness across sets, or accept explicit upstream matching provenance instead of asserting validated non-replacement status.

## HIGH H-04 — Bootstrap scope should be machine-readable

Recommended metadata:

```yaml
estimand: ATT
bootstrap_scope: conditional_on_fixed_matched_sets
rematching_within_replicate: false
propensity_model_refit: false
```

This prevents consumers from treating the percentile interval as uncertainty from the full matching procedure.

## HIGH H-05 — ATT is not stored as a machine-readable estimand

Section 10 will introduce ATE/ATT choices for IPTW. Section 9 should already emit:

```yaml
estimand: ATT
```

and protect it in schema.

## Schema review

Positive:

- `matched_set` is explicitly defined;
- matching ratio, patient counts, replacement, and balance structures are schema-protected;
- invalid ratio type is tested.

Remaining gaps:

- `replacement` is any boolean although this engine supports only no-replacement matching;
- no `estimand`;
- no bootstrap scope;
- no SMD status for zero-variance edge cases.

## Medium input-validation findings

Validate before returning evidence:

- `discarded_target` and `discarded_reference` must be scalar finite nonnegative integers;
- `caliper` must be scalar finite and nonnegative;
- `num_draws` must satisfy the common minimum;
- `seed=NULL` should serialize as null rather than `integer(0)`.

## Required test additions

Add tests for:

1. complete covariate separation with zero variance;
2. variable-ratio ATT-weighted SMD where raw and weighted variances differ;
3. true pre-match SMD or removal of `smd_unmatched`;
4. zero-reference RR mean/interval suppression;
5. duplicated subject ID across sets;
6. explicit raw-vs-weighted reference-risk semantics;
7. machine-readable `estimand=ATT`;
8. bootstrap scope metadata.

## Literature boundary

Abadie & Imbens (2008) showed that the ordinary bootstrap can fail for fixed-match nearest-neighbor matching estimators. The current engine resamples already-formed matched sets rather than repeating the matching procedure, so it should be described as a conditional fixed-set cluster bootstrap, not as capturing uncertainty from the full matching algorithm.

Matching-method guidance also emphasizes that when matching induces analysis weights, those weights should be used in balance diagnostics.

## Execution evidence

GitHub reports no workflow runs and no combined commit status for this commit. The plan records 38/38 matched-set tests, 41/41 schema tests, 40/40 regression tests, strict OpenSpec validation, and clean `git diff --check`; these remain implementer-reported local results.

## Final gate

- ATT point estimator: **PASS**
- Atomic set-resampling mechanics: **PASS**
- Bootstrap/Bayesian semantic separation: **PASS**
- Schema direction: **MOSTLY PASS**
- SMD implementation: **FAIL**
- Zero-reference RR contract: **FAIL**
- Common cohort output consistency: **FAIL**

**Section 9 overall: HOLD**

Recommended repair order:

1. fix zero-variance SMD;
2. make SMD weighting ATT-consistent;
3. remove or correctly source true pre-match SMD;
4. repair raw-count vs weighted-risk cohort semantics;
5. define zero-denominator bootstrap RR policy;
6. validate no-replacement matching using subject identity;
7. add `estimand: ATT`;
8. add `bootstrap_scope: conditional_on_fixed_matched_sets`;
9. tighten metadata input validation;
10. extend tests.

The ATT estimator itself does not need redesign. The required repair is concentrated in diagnostics and evidence-contract semantics.
