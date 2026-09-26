# Phase 2 Section 10 IPTW — Independent QA Review & Repair Plan #2

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Baseline:** `cba3960090518392467d98d03167a6a9db91a4bb`  
**Reviewed commit:** `cee26ff9f0324eba2030372d9d8f22324bdfdbf7`  
**Review date:** 2026-09-24 JST  
**Scope:** Section 10 IPTW Engine & Reporting — prior HOLD repair verification  
**Independent QA Gate:** **HOLD**

---

## 1. Executive Summary

Reviewed commit `cee26ff...` substantially repairs the previous Section 10 findings.

The following canonical Repair #1 items are materially implemented:

- inferential terminology branches between Bayesian posterior/ETI and bootstrap percentile/support fraction;
- PS clamping is configurable and observed-sample raw/clamped summaries plus clipping counts are emitted;
- IPTW cohort objects no longer expose raw `events` / `total`;
- `max_failure_rate` is public, validated, emitted, and exercised by a fail-fast test;
- arm-specific truncation tests now use known analytical expectations;
- extreme-weight and no-overlap fixtures were added;
- supplied subject IDs are checked for missing/duplicate rows;
- draw provenance includes refit mode, truncation, scaling mode, PS model/covariates, boundary policy, ESS and convergence threshold;
- ambiguous ATT stabilization is rejected;
- OpenSpec and skill documentation were updated.

However, the HOLD cannot yet be removed because two end-to-end contract defects remain and the submitted repair-summary table is not aligned with the repository's canonical `implementation_plan_009_0924.md`.

### Remaining Findings

| ID | Severity | Finding | Gate |
|---|---:|---|---|
| H3-01 | **HIGH** | Design-aware IPTW reporting reintroduces aggregate `df` raw events/totals and optional Fisher p-values even when the estimates come from `evidence_overrides`; no evidence/data identity guard exists | **Block ACCEPT** |
| H3-02 | **HIGH** | `comparative-evidence-v1.json` does not require or validate the new IPTW provenance fields emitted in `evidence$iptw` (`iptw_mode`, PS model, boundary policy, top-level failure threshold) | **Block ACCEPT** |
| M3-01 | MEDIUM | The local Draft-07 test validator ignores `maximum`, `exclusiveMinimum`, and `exclusiveMaximum`; schema-bound tests therefore overstate coverage | Repair |
| M3-02 | MEDIUM | The submitted 10.R1–10.R11 summary does not match canonical `implementation_plan_009`; several claims are absent from code or use different defaults | Governance repair |
| M3-03 | MEDIUM | PS-clipping diagnostics record the observed sample only; repeated clipping across bootstrap refits is not summarized | Recommended |
| M3-04 | MEDIUM | The IPTW reporting integration test deliberately combines evidence from one synthetic patient dataset with counts from a different aggregate dataset, proving that mismatched evidence/count provenance is currently accepted | Repair with H3-01 |

**Gate:** `HOLD`

---

## 2. Repository State Verification

Verified from GitHub:

- reviewed commit exists: `cee26ff9f0324eba2030372d9d8f22324bdfdbf7`;
- its direct parent is baseline `cba3960090518392467d98d03167a6a9db91a4bb`;
- baseline → reviewed is exactly 1 commit;
- branch `feat/comparative-evidence-reporting-v3` currently points to the reviewed commit;
- GitHub combined commit statuses are empty;
- no commit-associated workflow runs were found.

The repository execution record reports:

- `test_iptw_inference.R`: 66 PASS / 0 FAIL;
- `test_comparative_schemas.R`: 54 PASS / 0 FAIL;
- `test_vcd_categorical_reporting.R`: 31 PASS / 0 FAIL;
- canonical regression suite: 41/41 PASS;
- OpenSpec strict validation: valid;
- `git diff --check`: clean.

These execution results are **implementer-recorded evidence**. They were not independently re-executed in this QA environment because `Rscript` is unavailable and GitHub CI evidence is absent.

---

## 3. Repair #1 Status — Canonical `implementation_plan_009`

The authoritative task mapping SHALL remain the mapping in `implementation_plan_009_0924.md`.

| Canonical ID | Requirement | Review |
|---|---|---|
| 10.R1 | bootstrap/Bayesian reporting terminology split | **PASS core semantics; end-to-end raw-count issue remains under H3-01** |
| 10.R2 | governed PS boundary/clipping | **PASS observed-sample governance** |
| 10.R3 | raw counts vs weighted risk separation | **PASS engine; FAIL end-to-end report path** |
| 10.R4 | configurable `max_failure_rate` | **PASS** |
| 10.R5 | exact arm-specific truncation test | **PASS** |
| 10.R6 | extreme-weight warning test | **PASS basic diagnostic** |
| 10.R7 | positivity/overlap test | **PASS** |
| 10.R8 | subject ID duplicate/NA guard | **PASS** |
| 10.R9 | IPTW draws provenance | **PASS draws schema** |
| 10.R10 | ATT stabilization/scaling contract | **PASS** |
| 10.R11 | OpenSpec task reconciliation | **PARTIAL — completion state should wait for Repair #2** |

---

# 4. H3-01 — Design-Aware Reporting Reintroduces Raw-Count Semantics

## 4.1 Current Behavior

The IPTW inference engine correctly removes:

```r
target_cohort$events
target_cohort$total
reference_cohort$events
reference_cohort$total
```

and stores raw counts separately under:

```text
evidence.iptw.raw_patient_counts
```

However, `generate_comparative_report()` still always obtains:

```r
x_T <- row_t[[events_col]][[1L]]
n_T <- row_t[[total_col]][[1L]]
x_R <- row_r[[events_col]][[1L]]
n_R <- row_r[[total_col]][[1L]]
```

from the aggregate reporting `df`.

When `evidence_overrides[[pair_key]]` is supplied, those aggregate values are still written to:

```text
summary_df.target_events
summary_df.target_total
summary_df.reference_events
summary_df.reference_total
```

and displayed in Markdown/HTML as:

```text
標本サイズ (T / R)
イベント数 (T / R)
```

The same aggregate values are also used for optional Fisher exact testing.

## 4.2 Why This Is a High Finding

This permits:

```text
IPTW estimate derived from patient dataset A
+
raw counts displayed from aggregate dataset B
```

without any identity or provenance validation.

The current integration test actually constructs IPTW evidence from a separate random patient-level dataset and renders it beside the existing aggregate `batch_df`. Therefore the test demonstrates that mismatched evidence/count provenance is accepted rather than rejected.

This defeats the intended end-to-end semantic separation of:

```text
raw descriptive counts ≠ IPTW weighted estimand
```

even though the inference object itself is correct.

## 4.3 Required Design

Introduce an explicit design-aware reporting contract.

### Rule A — `evidence_overrides` is authoritative for statistical evidence

When an override is present:

- do not infer IPTW display counts from generic aggregate `df`;
- use `evidence$iptw$raw_patient_counts` when raw descriptive counts are allowed;
- use `evidence$iptw$effective_sample_size` for ESS display;
- do not calculate Fisher exact p-values from the generic aggregate rows unless an explicitly separate, labeled compatibility analysis is requested.

### Rule B — display raw counts and ESS under different labels

Do **not** replace raw sample size with ESS under the same label.

Use:

```text
Raw descriptive N (T / R)
Raw events (T / R)
ESS (T / R)
```

or, when raw counts are suppressed:

```text
Raw descriptive counts: suppressed
ESS (T / R): ...
```

### Rule C — evidence/data identity guard

At least one of the following SHALL be implemented:

1. preferred: a `source_data_hash` / `analysis_id` stored in evidence and required to match reporting input;
2. acceptable interim: verify the aggregate raw counts in the report input equal `evidence$iptw$raw_patient_counts`;
3. if counts are not intended to be the same representation, prohibit generic raw-count display for overrides.

Mismatch SHALL fail with a governed code such as:

```text
[EVIDENCE_REPORT_PROVENANCE_MISMATCH]
```

### Rule D — optional small-cell display suppression

The review request states a `<10` display-suppression requirement, but this is not part of canonical `implementation_plan_009`.

If the Owner intends this policy, formalize it before implementation:

```yaml
reporting_display_policy:
  raw_count_display: masked_below_threshold
  threshold: 10
```

Recommended behavior:

- keep exact raw counts in the governed structured evidence only if policy permits;
- presentation layer renders `<10` or `suppressed`;
- ESS remains numeric and clearly labeled as ESS;
- do not silently substitute ESS for raw N.

## 4.4 Required Tests

Add integration fixtures:

### T-RPT-01: same-source IPTW evidence

- build IPTW evidence from one patient dataset;
- derive expected raw counts from that same dataset;
- render;
- assert displayed raw counts equal `iptw.raw_patient_counts`;
- assert ESS equals `iptw.effective_sample_size`.

### T-RPT-02: provenance mismatch

- create evidence from dataset A;
- provide reporting aggregate counts from dataset B;
- expect `EVIDENCE_REPORT_PROVENANCE_MISMATCH`.

### T-RPT-03: no Fisher leakage

For IPTW override with default settings:

```text
fisher_p_value = NA
```

unless an explicitly labeled compatibility mode is requested.

### T-RPT-04: small-cell policy, if adopted

- raw count 7 → display `<10` or `suppressed`;
- ESS remains visible;
- structured evidence behavior follows the approved policy.

### Acceptance Criterion

No final IPTW report may combine weighted estimates with unrelated or ambiguously labeled raw aggregate counts.

---

# 5. H3-02 — Evidence Schema Does Not Enforce New IPTW Provenance

## 5.1 Current Runtime Output

`evidence$iptw` now emits:

```text
iptw_mode
propensity_model
propensity_score_boundary_policy
max_failure_rate
truncation
att_scaling_mode
...
```

## 5.2 Current Evidence Schema

`schemas/comparative-evidence-v1.json` still requires only the older IPTW set:

```text
estimand
stabilization
effective_sample_size
raw_patient_counts
weight_summary
covariate_balance
positivity
bootstrap_diagnostics
```

The schema does not define/require:

```text
iptw_mode
propensity_model
propensity_score_boundary_policy
max_failure_rate
```

at the `iptw` level.

Because JSON Schema permits unspecified properties unless `additionalProperties` is constrained, current payloads validate but the new provenance contract is not machine-enforced.

By contrast, `comparative-draws-v1.json` correctly requires the expanded provenance.

## 5.3 Required Repair

Synchronize `comparative-evidence-v1.json` with the runtime/OpenSpec contract.

### Required `iptw` fields

Add to `required`:

```json
[
  "estimand",
  "stabilization",
  "iptw_mode",
  "truncation",
  "att_scaling_mode",
  "propensity_model",
  "propensity_score_boundary_policy",
  "max_failure_rate",
  "effective_sample_size",
  "raw_patient_counts",
  "weight_summary",
  "covariate_balance",
  "positivity",
  "bootstrap_diagnostics"
]
```

### Required schemas

`iptw_mode`:

```json
{ "type": "string", "enum": ["refit_ps"] }
```

`propensity_model`:

```text
family = binomial
link = logit
covariates = array[string]
```

`propensity_score_boundary_policy`:

```text
mode = clamp
lower
upper
clipped_low_count
clipped_high_count
raw_min
raw_max
```

`max_failure_rate`:

```text
0 <= value < 1
```

### Evidence/Draw Schema Parity

The same semantic fields SHALL have compatible definitions in evidence and draws.

A schema drift test should compare the relevant required-field names or use a shared schema definition via `$ref`.

## 5.4 Required Negative Tests

At minimum:

- missing evidence `iptw_mode` → invalid;
- missing evidence `propensity_model` → invalid;
- missing evidence boundary policy → invalid;
- missing evidence `max_failure_rate` → invalid;
- invalid `iptw_mode` → invalid;
- invalid PS boundary lower/upper bounds → invalid;
- invalid failure threshold ≥1 → invalid.

---

# 6. M3-01 — Local Schema Validator Does Not Implement Important Draft-07 Bounds

The repository's pure-R `validate_payload_against_schema()` currently checks:

- type;
- enum;
- minimum;
- required;
- properties;
- limited additionalProperties;
- items;
- limited `not`.

It does **not** implement:

```text
maximum
exclusiveMinimum
exclusiveMaximum
```

Yet the IPTW schemas rely on those keywords.

Therefore passing `test_comparative_schemas.R` does not prove that upper/exclusive bounds are honored.

## Required Repair

Extend `check_node()`:

```r
if (!is.null(sc[["maximum"]]) && is.numeric(val) && val > sc[["maximum"]]) ...
if (!is.null(sc[["exclusiveMinimum"]]) && is.numeric(val) && val <= sc[["exclusiveMinimum"]]) ...
if (!is.null(sc[["exclusiveMaximum"]]) && is.numeric(val) && val >= sc[["exclusiveMaximum"]]) ...
```

Also reject non-finite JSON numeric values at the validator boundary.

## Required Tests

Direct schema-negative fixtures:

```text
max_failure_rate = 1.0
boundary.lower = 0
boundary.upper = 1.1
defined_fraction = 1.1
```

must fail schema validation for the correct reason.

---

# 7. M3-02 — Repair Request Summary and Canonical Plan Are Inconsistent

The submitted review request describes 10.R1–10.R11 differently from `implementation_plan_009_0924.md`.

Examples:

| Submitted request claim | Repository canonical state |
|---|---|
| 10.R1 = `ps_boundary_rule` 4 types | no `ps_boundary_rule`; current governed mode is `clamp` with configurable bounds |
| 10.R3 = raw PS × IPTW weight “effective PS” | implementation uses raw PS vs **clamped PS**, not PS×weight |
| 10.R4 = `<10` raw-count suppression and ESS replacement | not part of `implementation_plan_009`; not implemented |
| 10.R5 default `max_failure_rate = 0.20` | runtime/skill currently use **0.05** |
| 10.R8 = pseudo-repeat warning metadata | no such canonical Repair #1 task or implementation |
| 10.R9 = strict evidence schema additions | evidence schema does not currently enforce the new provenance fields |

## Required Governance Repair

Create one canonical mapping table and use it consistently in:

- implementation plan;
- execution report;
- QA request;
- OpenSpec tasks.

Do not reuse `10.R1` etc. for different meanings.

### Decision on `max_failure_rate`

Current runtime + skill default is `0.05`.

Recommended action:

- keep `0.05` as canonical unless Owner explicitly approves `0.20`;
- correct documents that state `0.20`.

### Decision on “effective PS”

Use unambiguous terminology:

```text
raw_ps
clamped_ps / effective_ps_for_weighting
```

Do **not** define `raw_ps × weight` as a propensity score unless a separate mathematical quantity is explicitly specified.

### Decision on pseudo-repeat warning

Bootstrap resampling intentionally samples with replacement. Repeated observations inside a bootstrap replicate are expected and should not be generically warned as pseudo-replication.

If a different condition is intended, define the exact invariant before implementation.

---

# 8. M3-03 — Bootstrap-Replicate PS Clipping Diagnostics

Observed-sample clipping provenance is now recorded, which resolves the original silent-clipping issue.

However, each bootstrap replicate re-estimates and clamps its own PS, while aggregate bootstrap diagnostics do not report how often clipping occurred.

## Recommended Extension

During bootstrap accumulate:

```text
replicates_with_any_clipping
total_clipped_low
total_clipped_high
max_clipped_fraction_in_replicate
```

Optionally:

```text
bootstrap_ps_clipping_fraction
```

This is especially useful when observed-sample PS looks acceptable but resampled fits repeatedly approach the positivity boundary.

**Severity:** MEDIUM / recommended hardening.  
This is not by itself an acceptance blocker if H3-01 and H3-02 are repaired.

---

# 9. Revised Implementation Task List — Repair #2

Use new IDs to preserve audit history.

## 10.R12 — Canonical Repair Contract Reconciliation

**Priority:** P0

### Files

- `docs/Artifacts/implementation_plan_010_0924.md` or next available plan number
- `docs/Artifacts/iptw_qa_repair_execution_002_0924.md`
- `openspec/.../tasks.md`
- review-request template if maintained

### Actions

1. Declare `implementation_plan_009` mapping immutable as historical Repair #1.
2. Document Repair #2 as 10.R12 onward.
3. Correct:
   - `max_failure_rate` default;
   - PS boundary naming;
   - small-cell policy status;
   - pseudo-repeat claim;
   - evidence-schema status.
4. Do not mark 10.R12+ complete until executable evidence exists.

### Acceptance

No ID has multiple meanings across QA/plan/execution documents.

---

## 10.R13 — Design-Aware Reporting Data Contract

**Priority:** P0 / HIGH

### Files

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- `tests/test_vcd_categorical_reporting.R`
- OpenSpec reporting/design spec

### Actions

1. Add explicit reporting mode:
   ```text
   count_model
   design_aware_override
   ```
2. In design-aware mode, source IPTW descriptive counts from:
   ```text
   ev$iptw$raw_patient_counts
   ```
3. Source ESS from:
   ```text
   ev$iptw$effective_sample_size
   ```
4. Never use generic `df` count values as if they were the IPTW analysis population without a provenance check.
5. Add governed mismatch error.
6. Disable Fisher exact compatibility by default for design-aware overrides.
7. Label all raw counts explicitly as descriptive.
8. Keep weighted estimates and ESS visually separate.

### Acceptance

A report cannot combine IPTW evidence from dataset A with raw display counts from dataset B.

---

## 10.R14 — Small-Cell Presentation Policy, If Owner-Approved

**Priority:** P0 if required by governance; otherwise defer

### Precondition

Owner confirms that `<10` suppression is an actual product/governance requirement.

### Actions

Introduce explicit configuration, e.g.:

```r
raw_count_display_policy = c("exact", "mask_below_threshold", "hidden")
raw_count_threshold = 10L
```

For IPTW:

- mask raw `N` / event counts below threshold in Markdown/HTML/CSV as policy requires;
- do not modify statistical computations;
- do not call ESS a raw sample size.

### Tests

- `N=9` masked;
- `N=10` behavior defined;
- ESS remains displayed under `ESS`;
- evidence JSON follows separately approved persistence policy.

---

## 10.R15 — IPTW Evidence Schema Provenance Hardening

**Priority:** P0 / HIGH

### Files

- `schemas/comparative-evidence-v1.json`
- optionally shared `$defs`/schema component
- `tests/test_comparative_schemas.R`

### Actions

Require and validate:

```text
iptw_mode
truncation
att_scaling_mode
propensity_model
propensity_score_boundary_policy
max_failure_rate
```

Keep evidence/draw definitions synchronized.

### Negative Tests

One negative fixture per required field plus enum/range violations.

---

## 10.R16 — Draft-07 Validator Bound Support

**Priority:** P1

### File

- `tests/test_comparative_schemas.R`
- preferably extract validator to reusable test helper later

### Implement

- `maximum`
- `exclusiveMinimum`
- `exclusiveMaximum`

### Tests

Validate that out-of-range IPTW schema values are actually rejected.

---

## 10.R17 — IPTW Report Provenance Integration Tests

**Priority:** P0

### Replace Current Test Pattern

Do not create IPTW evidence from an unrelated random dataset and combine it with an arbitrary aggregate `batch_df`.

### Required Fixture

From one source patient dataset:

1. calculate IPTW evidence;
2. derive the report's descriptive metadata/counts from the same dataset/evidence;
3. render;
4. verify:
   - weighted RD/RR;
   - bootstrap labels;
   - raw counts provenance;
   - ESS;
   - no unintended Fisher value;
   - no Bayesian terminology.

### Negative Fixture

Deliberately supply mismatched counts and expect governed failure.

---

## 10.R18 — Bootstrap PS Clipping Diagnostics

**Priority:** P1

### File

- `.agents/shared/iptw_inference.R`
- evidence/draw schemas
- tests

### Add

```text
bootstrap_clipping_diagnostics:
  replicates_with_any_clipping
  total_clipped_low
  total_clipped_high
  max_clipped_fraction
```

### Test

Separation/near-separation bootstrap fixture must exercise nonzero clipping diagnostics.

---

## 10.R19 — Regression and Acceptance Gate

**Priority:** P0

Run and record:

```bash
Rscript tests/test_iptw_inference.R
Rscript tests/test_comparative_schemas.R
Rscript tests/test_vcd_categorical_reporting.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Also verify:

```text
Bayesian Beta-Binomial terminology unchanged
matched pair tests unchanged
matched set tests unchanged
IPTW report no Bayesian labels
IPTW report no raw/weighted provenance mismatch
evidence + draws schemas both enforce IPTW provenance
```

If CI is available, attach commit-bound test evidence. Otherwise save the local execution transcript under `docs/Artifacts/`.

---

# 10. Repair #2 Acceptance Criteria

Section 10 MAY move from HOLD to ACCEPT only when all of the following are true:

1. **H3-01 closed**: design-aware reports cannot combine unrelated aggregate counts with IPTW evidence.
2. **H3-02 closed**: evidence schema requires the governed IPTW provenance already emitted by runtime.
3. IPTW report displays ESS and raw descriptive counts under distinct labels.
4. Any `<10` masking policy is explicitly approved and tested, or removed from claims.
5. Fisher exact output is not silently mixed into design-aware IPTW reporting.
6. Local schema validator enforces the bound keywords used by the schemas.
7. Repair task IDs and descriptions are consistent across plan, execution report, OpenSpec, and QA request.
8. `max_failure_rate` default is identical in code, skill, spec, tests, and documentation.
9. Same-source and mismatch-provenance reporting tests both pass.
10. All canonical regression tests pass.
11. OpenSpec strict validation passes.
12. `git diff --check` is clean.
13. No unadjudicated Blocker/High finding remains.

---

# 11. Suggested Implementation Order

```text
10.R12 Contract reconciliation
        ↓
10.R13 Reporting data/provenance contract
        ↓
10.R15 Evidence schema hardening
        ↓
10.R16 Schema-validator bound support
        ↓
10.R17 Same-source + mismatch integration tests
        ↓
10.R14 Small-cell policy (only if Owner-approved)
        ↓
10.R18 Bootstrap clipping diagnostics
        ↓
10.R19 Full verification gate
```

This order minimizes rework because report semantics and schema contracts are fixed before broad regression verification.

---

# 12. Final QA Position

```text
Phase 2 Section 10 — IPTW Engine & Reporting
Reviewed commit: cee26ff9f0324eba2030372d9d8f22324bdfdbf7

Gate: HOLD
Blocker: 0
High: 2
Medium: 4
```

The statistical estimator implementation is in substantially better condition than the baseline commit. The remaining acceptance risk is now concentrated in **end-to-end provenance and schema governance**, not in the central ATE/ATT formulas.

The next repair should therefore be small and contract-focused rather than a rewrite of the IPTW engine.
