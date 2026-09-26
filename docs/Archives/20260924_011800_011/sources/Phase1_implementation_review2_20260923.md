# Phase 1 Repair Re-Review — `comparative-evidence-reporting-v3`

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Reviewed commit:** `8174a47003c133ba7bd16d86f9130253fd10c28e`  
**Baseline:** `e9806f38759247088f5c532589af2083b07c45ef`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Blind-first repair review / read-only  
**Verdict:** **HOLD — major prior blockers repaired, but two executable blockers remain**

## Executive summary

This repair commit materially improves the Phase 1 implementation. The prior blockers around ephemeral draws, batch schema, canonical regression registration, ESS semantics, routing semantics, numerical golden checks, study-specific Safety output, MedDRA release metadata, and visual region encoding were addressed.

However, Phase 1 should still remain **HOLD** because two executable/integration blockers remain:

1. `%||%` is used in standalone modules without being defined or sourced.
2. `vcd-categorical-reporting` writes `run_meta.json`, but the shared `run_scope.R` reader/manifest registry still does not recognize this skill and the run lifecycle remains `pass1=pending`.

### Previous findings disposition

| Previous finding | Status |
|---|---|
| Draw schema vs ephemeral draws | RESOLVED structurally |
| Batch object mislabeled as single evidence schema | RESOLVED |
| Evidence-run-layout integration | PARTIAL |
| Phase 1 tests missing from canonical suite | RESOLVED |
| Matched-pair/person-time routing semantics wrong | RESOLVED |
| Monte-Carlo draws mislabeled ESS | RESOLVED |
| Numeric columns broadly treated as counts | MOSTLY RESOLVED |
| Study-specific Safety output absent | PARTIAL |
| MedDRA release provenance absent | RESOLVED |
| Visual region × U-grade encoding absent | MOSTLY RESOLVED |
| Golden tests lacked numeric benchmarks | IMPROVED |
| Prior-sensitivity hard-coded robustness threshold | NOT RESOLVED |
| Departmental policy mode overstated | NOT RESOLVED |

## Blocker B-01 — `%||%` undefined in standalone modules

`pass0_routing.R` uses:

```r
declared_count_cols <- config$count_columns %||% config$events_col %||% NULL
```

but does not define `%||%` and does not source a module that defines it.

`safety_adapter.R` similarly uses:

```r
rel_meta <- meddra_metadata$release_date %||%
            meddra_metadata$release %||%
            meddra_metadata$build %||% NULL
```

without defining/sourceing `%||%`.

`test_pass0_routing.R` and `test_safety_adapter.R` each source these modules directly in clean R processes. Therefore clean `Rscript` execution is expected to fail with an undefined infix operator.

### Required fix

Prefer explicit null checks or a tiny shared utility module. Avoid sourcing the whole `run_scope.R` solely for `%||%`.

After repair, verify in clean processes:

```text
Rscript tests/test_pass0_routing.R
Rscript tests/test_safety_adapter.R
```

## Blocker B-02 — run-control writer and reader disagree on the new skill

`generate_comparative_report()` now correctly calls:

```r
reserve_run_output_dir(...)
write_run_meta(...)
```

but shared `run_scope.R` currently only permits these skills in `read_run_control()`:

```text
vcd-bayesian-evidence-analysis
vcd-categorical-analysis
questionnaire-batch-analysis
```

`vcd-categorical-reporting` is absent.

Therefore a generated run can write `run_meta.json` but the canonical reader rejects it as an unknown skill.

`manifest_roles()` also does not include `vcd-categorical-reporting`.

### Lifecycle issue

`write_run_meta()` is called before final artifacts exist and without `results_manifest_sha256`, so:

```text
pass_status.pass1 = pending
```

The reporter does not later update this to `completed`.

### Required fix

Extend shared run infrastructure for `vcd-categorical-reporting`:

- add the skill to `read_run_control()` allowlist;
- define allowed manifest roles;
- define `comparative_evidence.json` as canonical primary result;
- generate a result manifest if required by the run-control lifecycle;
- update `run_meta.json` after successful artifact creation with `pass1=completed`;
- test:

```r
meta <- read_run_control(res$run_output_dir)
```

and assert success.

## High H-01 — In-memory data frame has no immutable input provenance

The reporter accepts `df` directly and `input_data_path` defaults to `NULL`. In the normal in-memory path, `run_meta.json` may contain no data input hash.

Bind a deterministic hash such as `sha256_df(df)` to run metadata whenever no file path is supplied.

## High H-02 — Multi-study Safety denominator contract remains ambiguous

The new Safety adapter supports study stratification, which is good, but denominator semantics remain underspecified.

With a simple vector:

```r
c("Drug_A"=100, "Placebo"=100)
```

the same denominator is applied to every study and the pooled result.

With a per-study list lacking a special `$total` element, the pooled denominator lookup can fail.

### Required fix

Define a strict multi-study denominator schema, for example:

```yaml
STUDY_101:
  Drug_A: 100
  Placebo: 100
STUDY_102:
  Drug_A: 120
  Placebo: 115
```

and compute descriptive pooled denominators explicitly as sums across studies unless an explicitly supplied pooled-population contract overrides this.

Add numeric denominator assertions to the test, not only structural assertions.

## High H-03 — JSON Schema files still are not actually used by tests

`tests/test_comparative_schemas.R` performs manual R-list assertions but does not validate generated payloads against:

```text
schemas/comparative-draws-v1.json
schemas/comparative-evidence-v1.json
schemas/comparative-evidence-batch-v1.json
```

Add actual offline JSON Schema validation for:

- ephemeral draw object;
- persisted draw object;
- single evidence object;
- written batch evidence object.

## High H-04 — Prior-sensitivity `robust` remains a hidden threshold

The implementation now records useful continuous shifts, but still computes:

```r
robust <- (dir_diff < 0.20) && (...)
```

The `0.20` cutoff is not an approved/versioned policy.

Prefer removing the binary `robust` flag or define a versioned sensitivity policy.

## High H-05 — Departmental policy mode still marked complete without end-to-end support

Task 7.4 remains complete, yet Pass 0 configuration still supports only `none | fixed_delta`. A policy loader alone is not an implemented policy mode.

Either implement `mode=policy` end-to-end or mark the task incomplete/deferred.

## High H-06 — Duplicate `(theme, group)` rows are silently truncated

The reporter selects the first row:

```r
x_T <- row_t[[events_col]][[1L]]
```

If multiple rows exist for one `(theme, group)`, remaining rows are silently ignored.

Require uniqueness for aggregate input and fail explicitly on duplicates unless a stratification/aggregation contract is provided.

## High H-07 — run-scope has a silent fallback

If shared run-scope functions are unavailable, the reporter falls back to a weaker manual run directory.

Because evidence-run-layout is mandatory, this should fail fast with a clear error such as:

```text
SHARED_RUN_SCOPE_UNAVAILABLE
```

rather than silently degrade.

## Medium findings

### M-01 — Practical-neutral is rendered as green / “practical equivalence”

The canonical region is `practical_neutral`, not automatically equivalence. Prefer neutral gray or muted teal and avoid “equivalence” wording unless an explicit equivalence estimand is configured.

### M-02 — ZERO_BOTH should explicitly assert RR mean divergence

For `0/100 vs 0/100`, add:

```r
is.null(ev2$relative_risk$mean)
ev2$relative_risk$mean_is_finite == FALSE
```

### M-03 — Golden tolerances are improved but still broad

Maintain a small canonical reference table with expected medians, intervals, and direction probabilities for the core fixtures.

### M-04 — Count-column fallback is still heuristic

If canonical count names cannot be detected, require explicit event/denominator mappings rather than checking all remaining numeric columns.

### M-05 — Delta-profile grid is not fully bound to report provenance

The engine accepts `delta_thresholds`, but the report API does not expose it and run metadata does not persist the grid. Expose and record it.

## Verification evidence

For commit `8174a47003c133ba7bd16d86f9130253fd10c28e`, GitHub reports no workflow runs and no combined status checks.

Because the `%||%` issue is visible statically, the canonical regression suite should not yet be considered demonstrated clean.

## Recommended repair order

1. remove/source `%||%` correctly;
2. extend `run_scope.R` allowlists/manifest support for `vcd-categorical-reporting`;
3. finalize `run_meta.json` with `pass1=completed`;
4. remove silent run-scope fallback;
5. bind in-memory input SHA-256;
6. add true JSON Schema validation;
7. fix multi-study denominator schema;
8. reject duplicate `(theme, group)` rows;
9. remove/version prior-sensitivity threshold;
10. implement or uncheck policy mode;
11. add ZERO_BOTH RR-mean assertion;
12. bind delta-profile grid to provenance.

## Suggested Phase 1 exit gate

Require all of:

```text
Rscript tests/test_pass0_routing.R
Rscript tests/test_safety_adapter.R
Rscript tests/test_comparative_schemas.R
Rscript tests/test_independent_beta_binomial.R
Rscript tests/test_domain_invariance.R
Rscript tests/test_practical_difference.R
Rscript tests/test_vcd_categorical_reporting.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

and verify:

```r
meta <- read_run_control(run_output_dir)
```

with:

```text
skill = vcd-categorical-reporting
pass_status.pass1 = completed
input hash present
```

## Final verdict

The repair quality is **strong**, and most prior conceptual defects are closed.

Current Phase 1 status remains:

**HOLD**

The remaining blockers are now localized:

- undefined `%||%` in standalone modules;
- incomplete integration with the shared run-control lifecycle.

One more Phase 1 repair-only commit should be sufficient before moving to Phase 2.
