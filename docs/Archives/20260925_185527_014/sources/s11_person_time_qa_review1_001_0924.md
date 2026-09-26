# Phase 2 Section 11 — Independent QA Review 1 / Post-Acceptance Hardening Plan

**Repository:** `syrius2000/agentic-evidence-analysis`
**Branch:** `feat/comparative-evidence-reporting-v3`
**Baseline:** `4829cb0b64adb7f1a5130fe6018ce295a0b1767b`
**Reviewed commit:** `1d42f4ae7a7e0649b755ab437c9e67c673078cc2`
**Review date:** 2026-09-24 JST
**Scope:** Section 10 post-acceptance repairs 10.R20–10.R22 + Section 11 person-time Gamma-Poisson 11.1–11.6
**QA Gate:** **PASS / ACCEPT**
**Residual findings:** Blocker 0 / High 0 / Medium 4
**Policy:** residual items are post-acceptance hardening and do not reopen Section 10 or Section 11 unless a new High/Blocker is found.

---

# 1. Executive Decision

## Section 10 — 10.R20–10.R22

**PASS**

Confirmed:

- PS boundary `upper < 1` is now enforced with `exclusiveMaximum: 1` in evidence/draw schemas.
- Shared `comparative-ps-summary-v1.json` is used for raw/effective PS summaries.
- raw/effective positivity summaries and effective common-support fields are required.
- Batch 011 archive summary Section 9 wording and matched-pair canonical paths were corrected.
- Section 10 remains `PASS / ACCEPT`.

## Section 11 — 11.1–11.6

**PASS / ACCEPT**

The central statistical implementation is correct:

\[
\lambda_g \mid x_g,T_g \sim \mathrm{Gamma}(x_g+0.5,\;T_g)
\]

under shape-rate parameterization.

Verified statically:

- nonnegative integer event-count validation;
- strictly positive finite exposure validation;
- `person_years` / `person_months` unit support;
- posterior rate draws from `rgamma(shape=x+0.5, rate=T)`;
- IRD = \(\lambda_T-\lambda_R\);
- IRR = \(\lambda_T/\lambda_R\);
- posterior-median / posterior-ETI semantics;
- IRD annualization:
  - person-years: `IRD × 100`;
  - person-months: `IRD × 1200`;
- reference zero-event case:
  \[
  E\left[\frac{\lambda_T}{\lambda_R}\right]
  \]
  diverges because reference shape is \(0.5\), and runtime correctly emits:
  ```text
  mean = null
  mean_is_finite = false
  diagnostic = ZERO_REFERENCE_EVENTS
  ```
  while preserving IRR median and ETI;
- rate evidence uses dedicated `incidence_rate_difference` / `incidence_rate_ratio` fields and does not reuse binary-risk top-level fields.

No High-level statistical defect was identified.

---

# 2. Verification Evidence

GitHub state:

- reviewed commit exists;
- reviewed commit direct parent is baseline `4829cb0...`;
- baseline → reviewed is exactly one commit;
- branch HEAD currently equals reviewed commit `1d42f4a...`;
- GitHub commit combined status is empty;
- no commit-bound workflow run was found.

Repository execution records report:

- `tests/test_person_time_rate.R`: **30 PASS / 0 FAIL**
- `tests/test_comparative_schemas.R`: **96 PASS / 0 FAIL**
- `tests/run_regression_suite.R`: **42/42 PASS**
- OpenSpec strict validation: valid / 0 issues
- Draft-07 validation: valid
- `git diff --check`: clean

These are implementer-recorded execution results; no GitHub CI evidence is attached to this commit.

---

# 3. M11-01 — Person-Time Draw Schema Does Not Fully Bind Inferential Semantics

**Severity:** MEDIUM
**Gate impact:** Non-blocking
**File:** `schemas/comparative-draws-v1.json`

Current person-time condition requires:

```text
design = "person_time"
→ person_time_metadata required
```

but it does not additionally require:

```text
inferential_semantics = "posterior"
```

Therefore this malformed object can be schema-valid in principle:

```yaml
design: person_time
inferential_semantics: bootstrap
person_time_metadata: ...
```

Runtime never emits this state, but the schema is intended to be the machine-readable contract.

## Required Repair

Extend the existing root `if/then`:

```json
"if": {
  "properties": {
    "design": { "const": "person_time" }
  },
  "required": ["design"]
},
"then": {
  "required": ["person_time_metadata"],
  "properties": {
    "inferential_semantics": { "const": "posterior" }
  }
}
```

## Required Test

```text
design = person_time
inferential_semantics = bootstrap
→ schema invalid
```

---

# 4. M11-02 — Exposure Unit and Rate Unit Are Independently Valid but Not Cross-Validated

**Severity:** MEDIUM
**Gate impact:** Non-blocking
**Files:**

- `schemas/comparative-draws-v1.json`
- `schemas/comparative-rate-evidence-v1.json`

Current enums separately allow:

```text
exposure_unit:
  person_years | person_months

rate_unit:
  events_per_person_year | events_per_person_month
```

but the schema does not prevent:

```yaml
exposure_unit: person_years
rate_unit: events_per_person_month
```

or the reverse.

Runtime produces consistent pairs, but malformed external payloads can pass schema validation.

## Required Repair

Add cross-field conditional validation to both evidence and draw metadata.

Required mapping:

```text
person_years  → events_per_person_year
person_months → events_per_person_month
```

Draft-07 implementation can use `if/then/else`, or `allOf` with two conditional clauses.

If `else` or `allOf` is used, update the pure-R validator so the local test engine supports the same keyword.

## Required Tests

1. `person_years + events_per_person_month` → invalid
2. `person_months + events_per_person_year` → invalid
3. both canonical pairings → valid

---

# 5. M11-03 — Zero-Reference IRR Mean Atomicity Is Runtime-Enforced but Not Schema-Enforced

**Severity:** MEDIUM
**Gate impact:** Non-blocking
**File:** `schemas/comparative-rate-evidence-v1.json`

Runtime correctly implements the mathematical boundary:

When:

```text
reference_cohort.events = 0
```

then:

```text
incidence_rate_ratio.mean = null
incidence_rate_ratio.mean_is_finite = false
incidence_rate_ratio.diagnostic = ZERO_REFERENCE_EVENTS
```

However, current rate evidence schema validates each field independently and does not enforce the joint state.

A malformed payload could therefore claim:

```yaml
reference_cohort:
  events: 0

incidence_rate_ratio:
  mean: 2.4
  mean_is_finite: true
  diagnostic: null
```

and remain structurally valid.

## Required Repair

Add a root conditional:

```text
IF reference_cohort.events == 0
THEN:
  incidence_rate_ratio.mean must be null
  mean_is_finite must be false
  diagnostic must equal ZERO_REFERENCE_EVENTS
```

Optionally enforce the complementary positive-reference state:

```text
IF reference_cohort.events >= 1
THEN:
  mean must be numeric
  mean_is_finite = true
  diagnostic = null
```

## Required Tests

- zero reference events + finite mean → invalid;
- zero reference events + `mean_is_finite=true` → invalid;
- zero reference events + missing diagnostic → invalid;
- valid zero-event runtime evidence → valid;
- positive-reference runtime evidence → valid.

---

# 6. M11-04 — QA Request Test Count Does Not Match Reviewed Repository Evidence

**Severity:** MEDIUM governance / audit evidence
**Gate impact:** Non-blocking

The review request states:

```text
tests/test_person_time_rate.R: 42 Passed / 0 Failed
```

but the reviewed repository's execution record states:

```text
tests/test_person_time_rate.R: 30 PASS / 0 FAIL
```

and the reviewed test source contains **30 executed assertions** when loop iterations are expanded.

The current regression-suite count is:

```text
42/42 test scripts PASS
```

which appears to be the likely source of the number 42.

## Required Correction

Use these distinct labels:

```text
test_person_time_rate.R:
  30 assertions PASS / 0 FAIL

tests/run_regression_suite.R:
  42/42 test scripts PASS
```

Do not report `42 Passed` for the person-time unit test unless the file is later expanded to 42 assertions and execution evidence is updated.

Also note:

- Section 10 post-acceptance execution record reported `test_comparative_schemas.R` = 85 PASS before Section 11;
- current Section 11 execution record reports `test_comparative_schemas.R` = 96 PASS after rate-schema tests were added.

This difference is expected and should remain time-scoped in documentation.

---

# 7. Additional Recommended Hardening — Persisted Person-Time Draw Contract

**Severity:** MEDIUM-LOW
**Gate impact:** Non-blocking

Current shared draw schema allows `draw_storage = "persisted"` while `target_draws` / `reference_draws` can still be absent or null.

Runtime is correct:

```text
persisted → numeric arrays
ephemeral → null draws
```

but schema does not fully encode that relationship.

This is broader than Section 11, so implementation may be deferred to a shared draw-interface hardening task.

Recommended person-time-specific contract:

```text
IF design=person_time AND draw_storage=persisted
THEN:
  target_draws required array
  reference_draws required array
  minItems >= 10
  each item > 0

IF design=person_time AND draw_storage=ephemeral
THEN:
  target_draws/reference_draws null or absent according to canonical policy
```

JSON Schema cannot easily assert array length equals `num_draws`; that equality should remain a runtime/test invariant.

---

# 8. Implementation Tasks

Use new repair IDs so 11.1–11.6 remain immutable historical feature tasks.

## 11.R7 — Bind Person-Time Draw Inferential Semantics

**Priority:** P1
**Files:**

- `schemas/comparative-draws-v1.json`
- `tests/test_comparative_schemas.R`

### Tasks

- [ ] Extend person-time `if/then` to require `inferential_semantics = "posterior"`.
- [ ] Add negative fixture `design=person_time + inferential_semantics=bootstrap`.
- [ ] Confirm valid runtime person-time draws still pass.
- [ ] Confirm non-person-time legacy draws remain unaffected.

### Acceptance

```text
person_time + posterior → valid
person_time + bootstrap → invalid
```

---

## 11.R8 — Enforce Exposure/Rate Unit Pairing

**Priority:** P1
**Files:**

- `schemas/comparative-rate-evidence-v1.json`
- `schemas/comparative-draws-v1.json`
- `tests/test_comparative_schemas.R`

### Tasks

- [ ] Add conditional mapping `person_years → events_per_person_year`.
- [ ] Add conditional mapping `person_months → events_per_person_month`.
- [ ] Apply the rule to rate evidence.
- [ ] Apply the rule to `person_time_metadata`.
- [ ] Extend pure-R validator if new Draft-07 keyword support is required.
- [ ] Add positive and negative fixtures for all four unit combinations.

### Acceptance

Only the two canonical exposure/rate pairings validate.

---

## 11.R9 — Encode Zero-Reference IRR Mean Atomicity

**Priority:** P1
**Files:**

- `schemas/comparative-rate-evidence-v1.json`
- `tests/test_comparative_schemas.R`

### Tasks

- [ ] Add root conditional on `reference_cohort.events == 0`.
- [ ] Require `mean = null`.
- [ ] Require `mean_is_finite = false`.
- [ ] Require `diagnostic = "ZERO_REFERENCE_EVENTS"`.
- [ ] Add complementary positive-reference contract if practical.
- [ ] Add negative tests for all inconsistent zero-event combinations.

### Acceptance

Schema and runtime enforce the same IRR-mean existence rule.

---

## 11.R10 — Harden Person-Time Persisted Draw Semantics

**Priority:** P2
**Files:**

- `schemas/comparative-draws-v1.json`
- `tests/test_comparative_schemas.R`

### Tasks

- [ ] For persisted person-time draws, require target/reference draw arrays.
- [ ] Require `minItems >= 10`.
- [ ] Require rate draw values `> 0`.
- [ ] Define canonical ephemeral representation (`null` vs absent).
- [ ] Add malformed persisted-draw fixtures.
- [ ] Keep `length(draws) == num_draws` as runtime/test invariant if not expressible cleanly in Draft-07.

### Acceptance

A person-time artifact cannot claim persisted draws without actually carrying valid positive rate draws.

---

## 11.R11 — Reconcile QA Evidence and Re-run Gate

**Priority:** P1
**Files:**

- `docs/Archives/20260924_141100_012/sources/person_time_section11_execution_001_0924.md` or next execution note
- next QA request / handoff document
- `openspec/.../tasks.md` if repair tracking is added

### Tasks

- [ ] Correct person-time unit-test count to 30 assertions for reviewed commit.
- [ ] Keep regression-suite result separately labeled `42/42 test scripts`.
- [ ] Run:
  ```bash
  Rscript tests/test_person_time_rate.R
  Rscript tests/test_comparative_schemas.R
  Rscript tests/run_regression_suite.R
  openspec validate comparative-evidence-reporting-v3 --strict --json
  git diff --check
  ```
- [ ] Run a real Draft-07 validator against:
  - valid person-time draw;
  - invalid bootstrap-semantics person-time draw;
  - invalid unit pairing;
  - invalid zero-reference IRR mean state.
- [ ] Record exact assertion/test-script counts without conflating them.

### Acceptance

Execution records, source assertion counts, and QA request metadata agree.

---

# 9. Final QA Decision

```text
Section 10 — IPTW post-acceptance repair:
PASS

Section 11 — Gamma-Poisson person-time engine:
PASS / ACCEPT

Reviewed commit:
1d42f4ae7a7e0649b755ab437c9e67c673078cc2

Blocker: 0
High:    0
Medium:  4
```

The central Section 11 mathematics and runtime behavior are acceptable. Remaining findings concern schema semantic strictness and audit-evidence consistency rather than the statistical estimator itself.

Section 11 may be frozen and work may proceed to Section 12 while 11.R7–11.R11 are tracked as non-blocking post-acceptance hardening.
