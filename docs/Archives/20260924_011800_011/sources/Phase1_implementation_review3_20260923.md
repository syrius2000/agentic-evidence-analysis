# Phase 1 Implementation Repair — Independent Review #3

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**User-supplied reviewed SHA:** `7fabe584c3114d56d11fefad7d4f9bf80db30310`  
**Actual branch HEAD reviewed:** `7fabe58bb5709349aca00be1d76afdedfbe30750`  
**Baseline:** `8174a47003c133ba7bd16d86f9130253fd10c28e`  
**Review date:** 2026-09-23 (JST)  
**Review mode:** Independent static implementation review using GitHub connector  
**Verdict:** **CONDITIONAL PASS — all prior Blocker/High repair items are resolved; one new dependency reproducibility High remains**

---

## 1. Commit identity correction

The SHA supplied in the review request does not exist in GitHub.

The GitHub branch endpoint reports the current branch HEAD as:

```text
7fabe58bb5709349aca00be1d76afdedfbe30750
```

with parent:

```text
8174a47003c133ba7bd16d86f9130253fd10c28e
```

and commit message:

```text
Yip: resolve review2 blockers, harden Phase 1 contracts, and adopt topic-branch review policy
```

Therefore this review treats `7fabe58bb5709349aca00be1d76afdedfbe30750` as the intended reviewed commit.

---

# 2. Executive conclusion

The repair is successful.

Every prior item explicitly requested for follow-up has been repaired in code/spec/tests:

| Prior finding | Verdict |
|---|---|
| B-01 `%||%` undefined | **RESOLVED** |
| B-02 run-control lifecycle incomplete | **RESOLVED** |
| H-01 in-memory data hash provenance | **RESOLVED** |
| H-02 multi-study Safety denominators | **RESOLVED** |
| H-03 actual JSON Schema validation | **RESOLVED FUNCTIONALLY** |
| H-04 hidden binary `robust` threshold | **RESOLVED** |
| H-05 departmental policy mode overstated | **RESOLVED** |
| H-06 duplicate `(theme, group)` rows | **RESOLVED** |
| H-07 silent run-scope fallback | **RESOLVED** |
| M-01 practical-neutral color | **RESOLVED** |
| M-05 delta grid provenance | **RESOLVED** |

The previous two Blockers are no longer present.

No architectural regression was found in the repaired statistical core.

However, H-03 introduces a new canonical test dependency on Python packages `jsonschema` and `referencing`, while the repository's deterministic dependency contract does not yet declare/preflight/version those Python dependencies. That is a new reproducibility risk and should be closed before final Phase 1 acceptance/archive.

---

# 3. Detailed follow-up

## B-01 — `%||%` undefined in standalone modules

### Verdict: RESOLVED

`pass0_routing.R` no longer uses `%||%` for count-column resolution.

It now uses explicit null logic:

```r
declared_count_cols <- if (!is.null(config$count_columns)) {
  config$count_columns
} else {
  config$events_col
}
```

It also rejects ambiguous numeric input when no count columns can be identified:

```text
[COUNT_COLUMNS_REQUIRED]
```

`safety_adapter.R` likewise replaces `%||%` with explicit precedence:

```r
release_date
 -> release
 -> build
```

Neither standalone file contains the `%||%` operator anymore.

This removes the clean-process runtime failure identified in Review 2.

---

## B-02 — `vcd-categorical-reporting` run-control lifecycle

### Verdict: RESOLVED

The shared `run_scope.R` now recognizes:

```text
vcd-categorical-reporting
```

in `read_run_control()`.

`manifest_roles()` now defines:

```text
primary_results
summary_table
summary_report
report_html
```

for this skill.

The canonical primary result is explicitly:

```text
comparative_evidence.json
```

The reporter now executes the correct lifecycle:

```text
reserve_run_output_dir
 -> write artifacts
 -> write_results_manifest
 -> write_run_meta(results_manifest_sha256=...)
 -> verify_results_manifest
```

Because `write_run_meta()` receives `results_manifest_sha256`, the shared lifecycle sets:

```text
pass_status.pass1 = completed
```

The reporting test now explicitly verifies:

```r
meta <- read_run_control(res$run_output_dir)
meta$skill == "vcd-categorical-reporting"
meta$pass_status$pass1 == "completed"
verify_results_manifest(...)
```

This closes the previous writer/reader mismatch.

---

# 4. High findings follow-up

## H-01 — In-memory data-frame SHA-256 provenance

### Verdict: RESOLVED

The reporter constructs a canonical serialized object containing:

```text
column names
column types
column classes
values
row order
```

and computes:

```r
digest(..., algo="sha256", serialize=TRUE, serializeVersion=2L)
```

For in-memory input the run metadata stores:

```text
source_kind = builtin
logical_label = in_memory_data_frame
sha256 = df_sha256
data_frame_hash_contract =
  "R-serialize-v2: column names, types, classes, values, row order"
```

Tests verify:

- input hash exists;
- the input hash equals `data_frame_sha256`;
- changing event values changes the hash;
- file-backed input records the actual file SHA-256.

This satisfies the requested provenance contract.

### Minor note

The contract is reproducible within the stated R serialization contract, but it is tied to R serialization semantics rather than a language-neutral canonical serialization. This is acceptable for Phase 1 because the contract is explicitly recorded.

---

## H-02 — Multi-study Safety denominator contract

### Verdict: RESOLVED

For multi-study input, the adapter now requires:

```text
named list keyed exactly by study ID
```

and rejects:

- a shared denominator vector;
- missing study keys;
- unexpected `total`;
- non-finite denominators;
- non-positive denominators;
- non-integer denominators.

Study-specific denominators are validated independently.

The pooled denominator is calculated with:

```r
Reduce(`+`, per_study_denominators)
```

Tests now assert:

```text
STUDY_101 target denominator = 100
STUDY_102 reference denominator = 115
pooled target denominator = 220
pooled reference denominator = 215
```

and verify that a shared vector is rejected.

This closes Review 2 H-02.

---

## H-03 — Actual Draft 7 JSON Schema validation

### Verdict: RESOLVED FUNCTIONALLY, NEW DEPENDENCY RISK

A real offline validator was added:

```text
tests/validate_comparative_schema.py
```

using:

```python
jsonschema.Draft7Validator
referencing.Registry
referencing.Resource
```

`test_comparative_schemas.R` invokes this validator against:

1. ephemeral draw payload;
2. persisted draw payload;
3. single evidence payload;
4. written batch evidence payload;
5. a deliberately invalid legacy payload containing `robust`.

The reference-registry approach used for:

```text
comparative-evidence-v1.json#
```

is structurally valid.

Therefore the previous defect — “tests do not actually validate against JSON Schema” — is repaired.

### New High: Python schema-validator dependencies are not yet part of the deterministic environment contract

The canonical regression suite now invokes `test_comparative_schemas.R`, which requires Python packages:

```text
jsonschema
referencing
```

The test fails fast if they are missing, which is preferable to runtime installation.

However:

- no root dependency/lock file was found declaring these Python packages;
- the deterministic dependency OpenSpec still describes R packages/system dependencies generically;
- the implementation plan explicitly says the packages were verified only in the current Mac Python environment;
- GitHub reports no workflow run/status evidence for this commit.

Thus the canonical `38/38` suite is no longer reproducible from repository declarations alone.

### Required closure

Before final Phase 1 acceptance, add one of:

- a versioned Python test-dependency file; or
- an explicit environment/dependency manifest documenting `python`, `jsonschema`, `referencing`; and
- a deterministic preflight check included in the canonical dependency verification.

No runtime auto-install should be introduced.

**Severity:** HIGH, but not a regression in statistical logic.

---

## H-04 — Unapproved binary prior-sensitivity `robust`

### Verdict: RESOLVED

The binary field and hidden `0.20` threshold have been removed.

The implementation now persists only descriptive sensitivity outputs:

```text
rd_median_delta
direction_support_delta
u_grade_changed
```

Tests explicitly assert that:

```text
robust
```

is absent for:

- zero-cell mode;
- off mode;
- explicit mode.

The JSON Schema now rejects the legacy `robust` field using:

```json
"not": { "required": ["robust"] }
```

The primary U-grade is also tested to remain unchanged by sensitivity mode.

This is a clean repair.

---

## H-05 — Departmental policy mode scope overstatement

### Verdict: RESOLVED

Task 7.4 is now:

```text
[ ]
```

rather than `[x]`.

Therefore the active Phase 1 scope no longer claims end-to-end implementation of the departmental `mode=policy` path.

The implemented Phase 1 contract remains:

```text
none
fixed_delta
```

This is consistent with the implementation.

---

## H-06 — Duplicate `(theme, group)` rows silently ignored

### Verdict: RESOLVED

Before run reservation, the reporter now checks:

```r
anyDuplicated(df[c(theme_col, group_col)])
```

and stops with:

```text
[DUPLICATE_THEME_GROUP]
```

The corresponding test verifies this failure path.

This prevents the previous silent `[[1L]]` first-row truncation.

---

## H-07 — Silent run-scope fallback

### Verdict: RESOLVED

The reporter now fails immediately if `run_scope.R` is unavailable:

```text
[SHARED_RUN_SCOPE_UNAVAILABLE]
```

It additionally checks for required functions:

```text
reserve_run_output_dir
write_results_manifest
write_run_meta
read_run_control
verify_results_manifest
```

The manual fallback run directory has been removed.

This now matches the mandatory `evidence-run-layout` contract.

---

# 5. Medium findings requested

## M-01 — `practical_neutral` rendering

### Verdict: RESOLVED

The previous green/equivalence presentation has been changed to neutral gray:

```text
rgba(100, 116, 139, ...)
```

The code also explicitly states:

```text
Practical-neutral is a region label, not an equivalence claim.
```

The test verifies neutral-gray rendering.

This is preferable for Safety because it avoids “green = safe/equivalent” semantics.

---

## M-05 — `delta_thresholds` provenance

### Verdict: RESOLVED

`generate_comparative_report()` now exposes:

```r
delta_thresholds
```

as an API parameter.

The exact grid is written to:

```text
comparative_evidence.json
run_meta.json
```

and passed into the Beta-Binomial engine.

Tests verify that a custom grid:

```text
0.02, 0.04
```

is preserved in both batch evidence and run metadata.

---

# 6. Other positive repairs

The new commit also improves two prior medium items beyond the requested checklist:

- Pass 0 no longer falls back to “all remaining numeric columns”; ambiguous numeric inputs now require explicit count mappings.
- `ZERO_BOTH` / golden regression coverage has been expanded in `test_independent_beta_binomial.R`.

The general repair strategy remains consistent with the approved architecture.

---

# 7. New findings

## N-01 — HIGH: Canonical regression suite now has an undeclared Python dependency

As described under H-03, `tests/run_regression_suite.R` now transitively depends on:

```text
Python
jsonschema
referencing
```

through `test_comparative_schemas.R`.

The repository currently does not establish a versioned, portable dependency baseline for these packages.

### Risk

A clean offline environment with all documented R dependencies may still fail the canonical regression suite.

That conflicts with the intent of:

```text
deterministic-r-dependencies
```

and with the regression suite's own claim of offline deterministic execution.

### Recommended repair

Add a minimal test dependency contract such as:

```text
tests/requirements.txt
```

or a repository-level environment manifest with pinned/compatible ranges, plus preflight verification.

Do not auto-install at test runtime.

---

## N-02 — MEDIUM: No independent executable CI evidence is attached to this commit

GitHub connector reports:

```text
workflow_runs = []
combined statuses = []
```

The implementation plan states:

```text
38/38 PASS
OpenSpec strict validation valid
git diff --check clean
```

but those remain implementer-reported local results.

This review could not independently rerun the repository because the execution environment cannot clone GitHub over the network.

### Recommendation

Before final Owner adjudication, attach one reproducible artifact:

- GitHub Actions run;
- committed verification log;
- or another independently generated execution record.

This is an evidence-gap finding, not a code defect.

---

## N-03 — LOW/MEDIUM: Review request SHA is incorrect

The supplied commit:

```text
7fabe584c3114d56d11fefad7d4f9bf80db30310
```

does not exist.

The branch HEAD is:

```text
7fabe58bb5709349aca00be1d76afdedfbe30750
```

For QA traceability, future review records should use the exact immutable SHA.

---

# 8. Phase 1 gate

## Previous Blockers

\[
\boxed{\text{B-01 RESOLVED}}
\]

\[
\boxed{\text{B-02 RESOLVED}}
\]

## Previous High findings

\[
\boxed{\text{H-01 through H-07 RESOLVED}}
\]

H-03 is resolved as an implementation requirement, but introduces new dependency-governance risk N-01.

## Overall Phase 1 implementation status

**CONDITIONAL PASS**

The implementation itself is now coherent enough to close the prior Review 2 defects.

I would not require another statistical-core redesign.

Before final Phase 1 acceptance / Phase 2 start, close:

1. **N-01** Python schema-validator dependency declaration/preflight;
2. **N-02** independent executable verification evidence.

---

# 9. Recommended next action

Do **not** reopen the repaired B/H findings.

Create a very small Phase 1 verification/dependency patch only:

```text
1. declare Python test dependencies
2. add preflight verification
3. run canonical 38-test suite in a clean/offline-capable environment
4. persist execution evidence
5. Owner adjudication
```

If that execution is clean, the Phase 1 gate can move from:

```text
CONDITIONAL PASS
```

to:

```text
PASS / READY FOR PHASE 2
```

without another architectural review.

---

# 10. Final verdict

The repair is technically successful.

The important distinction is:

> **The prior implementation defects are resolved. The remaining issue is reproducibility evidence/dependency governance, not statistical design.**

That is a substantial improvement over Review 2.
