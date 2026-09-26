# Section 13 Phase A — Independent QA Review 1 / Repair Plan

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Baseline:** `7cd4b11c6e0ad74d46b359e2a283c564c1338f65`  
**Reviewed commit:** `2b474299c631e2a85f920d26ce6b9baff60c0b3d`  
**Scope:** Section 13 Phase A — 13.1, 13.2, 13.3 only  
**Out of scope:** 13.4+  
**Review date:** 2026-09-24 JST  
**Reviewer:** GPT-5.6 Sol

## QA Gate

```text
Section 13 Phase A:
HOLD

Blocker: 0
High:    1
Medium:  3
```

The feature extractor itself is coherent and the decision-label source guard is conservative. However, Phase A cannot yet be accepted because Task 13.1 explicitly requires `evidence-run-layout` conformance, while the new skill does not complete the canonical `run_meta.json` lifecycle and the shared run reader rejects the new skill.

---

# 1. Scope / Commit Verification

The requested baseline and reviewed commit form a single direct repair/development step:

```text
baseline:
7cd4b11c6e0ad74d46b359e2a283c564c1338f65

reviewed:
2b474299c631e2a85f920d26ce6b9baff60c0b3d
```

At review time, branch HEAD equals the reviewed commit.

GitHub returned:

```text
combined status: empty
workflow runs: none
```

Therefore there is no commit-bound CI evidence for this revision.

The implementation execution record reports:

```text
tests/test_evidence_feature_extract.R:
15 PASS / 0 FAIL

OpenSpec strict:
valid / issue 0

git diff --check:
clean
```

These remain implementer claims because R tests were not independently reproduced in the reviewer runtime.

Static inspection confirms that the new test source contains the expected 15 assertion outcomes.

---

# 2. Positive Findings

## 13.2 — Feature extractor core logic

`.agents/shared/evidence_feature_extract.R` correctly:

- accepts `comparative-evidence-v1`;
- extracts RD estimate and interval width;
- extracts direction support;
- separates `core` and `delta_dependent`;
- includes resolution grade and zero-reference diagnostics;
- makes delta features conditional in generated output;
- preserves only source metadata outside the clustering fields.

The extractor's canonical key sets are explicit:

```text
CORE_CLUSTERING_KEYS
DELTA_CLUSTERING_KEYS
```

## 13.3 — Runtime source guard

The recursive key scanner rejects decision/regulatory keys before feature construction.

Examples covered by tests:

```text
decision_code
regulatory_label
```

The implementation also checks generated `clustering_feature_keys` against the forbidden-key list.

This runtime path is conservative and appropriate.

## Phase boundary

13.4+ is not implemented. Gower, HAC, K-means, precedent retrieval, ledger, discordance and stability work remain outside this commit as requested.

---

# 3. H13A-01 — `evidence-run-layout` Lifecycle Is Incomplete

**Severity:** HIGH  
**Task:** 13.1  
**Gate impact:** Phase A HOLD

## Evidence

Task 13.1 is marked complete as:

```text
Initialize evidence-decision-review skill complying with evidence-run-layout.
```

The canonical `evidence-run-layout` specification requires isolated runs and a `run_meta.json` audit contract.

The proposal also states that `evidence-decision-review` must conform strictly to:

```text
evidence_runs/<skill_slug>/run_<canonical_id>[_N]/
```

with `run_meta.json`.

### Problem 1 — Initializer only reserves a directory

`.agents/shared/evidence_feature_extract.R`:

```r
init_evidence_decision_run <- function(...) {
  ...
  reserve_run_output_dir(
    out_root = out_root,
    skill = "evidence-decision-review",
    run_id = run_id
  )
}
```

This reserves the run directory only.

It does not create or finalize:

```text
run_meta.json
```

The Phase A test writes:

```text
evidence_feature.json
results_manifest.json
```

but does not write or verify canonical run metadata.

### Problem 2 — Shared run reader rejects the new skill

`.agents/shared/run_scope.R` currently validates:

```r
if (!meta$skill %in% c(
  "vcd-bayesian-evidence-analysis",
  "vcd-categorical-analysis",
  "vcd-categorical-reporting",
  "questionnaire-batch-analysis"
)) stop("[ERROR] 不明なskill")
```

`evidence-decision-review` is absent.

The same file *does* register the skill in:

```text
manifest_roles()
primary artifact switch
```

so the lifecycle is internally inconsistent:

```text
manifest writer: accepts evidence-decision-review
run_meta reader: rejects evidence-decision-review
```

### Impact

A formally conforming run cannot be round-tripped through the shared audit contract.

Even if a caller later writes a valid `run_meta.json` with:

```text
skill = evidence-decision-review
```

`read_run_control()` rejects it as an unknown skill.

This violates the explicit 13.1 acceptance intent and the repository-wide audit contract.

## Required Repair

Add `evidence-decision-review` to the canonical run-control skill allowlist.

Prefer centralizing the supported-skill set so these do not drift independently:

```text
read_run_control
manifest_roles
primary artifact mapping
other run-scope validators
```

Phase A must prove a complete lifecycle:

```text
reserve run
→ write evidence_feature.json
→ write results_manifest.json
→ write run_meta.json
→ read_run_control()
→ verify_results_manifest()
→ run_meta / manifest consistency
```

The test must assert:

- `run_meta.json` exists;
- `meta$skill == "evidence-decision-review"`;
- path schema version is canonical;
- logical/physical run ID relationship is valid;
- results manifest hash is bound;
- `read_run_control()` succeeds;
- no root leakage occurs;
- same requested run ID collision creates `_2`, not overwrite.

## Acceptance

A complete `evidence-decision-review` run must satisfy the same audit lifecycle as the other evidence-run-layout skills.

---

# 4. M13A-01 — `clustering_feature_keys` Is an Unconstrained Selector

**Severity:** MEDIUM  
**Tasks:** 13.2 / 13.3  
**Gate impact:** Must fix before Phase B clustering consumes the contract

## Evidence

Runtime has a strong guard:

```r
overlap <- intersect(
  tolower(unlist(features$clustering_feature_keys)),
  tolower(FORBIDDEN_DECISION_LABEL_KEYS)
)

if (length(overlap) > 0L) {
  stop("[DECISION_LABEL_IN_FEATURE_KEYS] ...")
}
```

However `schemas/evidence-feature-v1.json` defines:

```json
"clustering_feature_keys": {
  "type": "array",
  "minItems": 1,
  "uniqueItems": true,
  "items": {
    "type": "string",
    "minLength": 1
  }
}
```

There is no enum / allowlist.

Therefore a payload can be structurally schema-valid with:

```json
"clustering_feature_keys": ["decision_code"]
```

or:

```json
"clustering_feature_keys": ["regulatory_label"]
```

The root `not.anyOf` only prohibits object properties with those names; it does not inspect string values inside `clustering_feature_keys`.

The current extractor never generates this malformed state, but `evidence-feature-v1` is intended to be the machine-readable contract consumed by later Phase B clustering.

## Required Repair

Preferred design: make the clustering set derivable rather than user-selectable.

Option A — remove `clustering_feature_keys` from persisted contract and let Phase B derive keys from:

```text
core
delta_dependent.present
```

Option B — retain it but constrain item values to an explicit enum:

```text
rd_estimate
rd_interval_width
direction_support
resolution_grade
rr_mean_is_finite
has_zero_reference
target_n
reference_n
quarantine_flag_count
primary_delta
target_excess
practical_neutral
reference_excess
```

At minimum add schema-negative tests:

```text
decision_code
regulatory_label
arbitrary_unknown_feature
```

and runtime/schema parity tests.

## Acceptance

No schema-valid feature vector may nominate a decision/regulatory field or unknown attribute as a clustering input.

---

# 5. M13A-02 — Delta-Dependent State Is Not Atomic in the Schema

**Severity:** MEDIUM  
**Task:** 13.2  
**Gate impact:** Contract hardening before Gower implementation

## Evidence

The extractor emits a coherent pair of states.

### Delta enabled

```text
present = true
primary_delta = number
target_excess = number
practical_neutral = number
reference_excess = number
```

### Delta disabled

```text
present = false
primary_delta = null
target_excess = null
practical_neutral = null
reference_excess = null
```

But the schema independently allows nullable fields regardless of `present`.

Thus these malformed states are schema-valid in principle:

```yaml
present: true
primary_delta: null
target_excess: null
practical_neutral: null
reference_excess: null
```

and:

```yaml
present: false
primary_delta: 0.05
target_excess: 0.8
practical_neutral: 0.1
reference_excess: 0.1
```

The schema also does not bind delta keys in `clustering_feature_keys` to the `present` state.

## Required Repair

Add Draft-07 conditional logic.

Conceptually:

```text
IF delta_dependent.present == true
THEN:
  primary_delta > 0
  target_excess numeric [0,1]
  practical_neutral numeric [0,1]
  reference_excess numeric [0,1]

IF present == false
THEN:
  all four fields must be null
```

If `clustering_feature_keys` is retained:

```text
present=false
→ delta keys prohibited

present=true
→ delta-key policy explicitly defined
```

The probability-sum invariant:

```text
target_excess + practical_neutral + reference_excess ≈ 1
```

may remain a runtime/test invariant because Draft-07 does not conveniently express cross-field arithmetic.

## Required Tests

Negative fixtures:

1. `present=true` + null delta values;
2. `present=false` + numeric delta values;
3. `present=false` + delta clustering keys;
4. `primary_delta <= 0` when present.

Positive fixtures:

1. canonical delta-enabled extractor output;
2. canonical null-delta extractor output.

---

# 6. M13A-03 — Shared `run_scope.R` Changed Without Full Regression Evidence

**Severity:** MEDIUM governance / regression assurance  
**Task:** 13.1 verification

## Evidence

This commit modifies the shared:

```text
.agents/shared/run_scope.R
```

and registers the new test in:

```text
tests/run_regression_suite.R
```

However the execution record reports only:

```text
Rscript tests/test_evidence_feature_extract.R
openspec validate ...
git diff --check
```

It does not report execution of:

```text
Rscript tests/run_regression_suite.R
```

The shared run-scope module is used by multiple existing skills, so targeted Phase A tests are insufficient to establish no regression.

The missing `read_run_control()` registration also demonstrates why lifecycle-level shared regression matters.

## Required Repair

After H13A-01 and schema fixes:

```bash
Rscript tests/test_evidence_feature_extract.R
Rscript tests/test_skill_run_isolation.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Record:

- targeted assertion count;
- run-isolation assertion/result count;
- regression script count;
- failures / not-found count;
- OpenSpec result.

Treat each count category separately.

---

# 7. Repair Tasks

Use Phase-A repair IDs rather than redefining 13.1–13.3 history.

## 13.A.R1 — Complete Evidence Run Lifecycle

**Priority:** P0 / HIGH

- [ ] Add `evidence-decision-review` to canonical `read_run_control()` skill support.
- [ ] Audit all run-scope skill allowlists for the same slug.
- [ ] Prefer a shared supported-skill constant to prevent future drift.
- [ ] Add Phase A lifecycle helper or test path that writes `run_meta.json`.
- [ ] Bind `results_manifest_sha256` into run metadata.
- [ ] Verify `read_run_control()` succeeds for the new skill.
- [ ] Verify manifest/run-meta skill identity.
- [ ] Verify canonical path schema fields.
- [ ] Verify run collision suffix behavior.
- [ ] Verify no root leakage.

### Acceptance

`evidence-decision-review` is a first-class `evidence-run-layout` skill, not only a manifest role.

---

## 13.A.R2 — Close Clustering Feature-Key Contract

**Priority:** P1

- [ ] Decide whether `clustering_feature_keys` should be derived or persisted.
- [ ] If persisted, constrain to a canonical allowlist.
- [ ] Reject all forbidden decision/regulatory key names.
- [ ] Reject arbitrary unknown feature names.
- [ ] Add runtime/schema parity fixtures.
- [ ] Document canonical key-order policy if order is material for downstream matrix construction.

### Acceptance

A schema-valid payload cannot select a forbidden or unknown clustering attribute.

---

## 13.A.R3 — Make Delta State Atomic

**Priority:** P1

- [ ] Add `present` conditional schema rules.
- [ ] `present=true` requires non-null valid delta values.
- [ ] `present=false` requires all delta values null.
- [ ] Bind clustering delta keys to the same state if key list remains persisted.
- [ ] Add four negative fixtures and two positive fixtures.
- [ ] Keep probability-sum consistency as runtime/test invariant if needed.

### Acceptance

Schema and extractor expose exactly the same two canonical delta states.

---

## 13.A.R4 — Full Regression / Audit Evidence

**Priority:** P0

Run and record:

```bash
Rscript tests/test_evidence_feature_extract.R
Rscript tests/test_skill_run_isolation.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict --json
git diff --check
```

Also explicitly test:

```text
write_run_meta(skill="evidence-decision-review")
read_run_control()
verify_results_manifest()
```

### Acceptance

No High/Blocker remains and shared run-scope regression is clean.

---

# 8. Non-Findings / Deferred Scope

The following are not findings against this Phase A commit:

- Gower distance is not implemented — 13.4 is out of scope.
- HAC / K-means are not implemented — 13.5–13.6 are out of scope.
- precedent retrieval and historical decision context are not implemented — 13.7–13.8 are out of scope.
- decision ledger / discordance / stability are not implemented — Phase C.
- person-time `comparative-rate-evidence-v1` support is not judged in this review because the Phase A implementation contract explicitly starts from `comparative-evidence-v1`; broader design-aware feature harmonization should be addressed before Phase B if required by the owner.

---

# 9. Final QA Position

```text
Reviewed commit:
2b474299c631e2a85f920d26ce6b9baff60c0b3d

Baseline:
7cd4b11c6e0ad74d46b359e2a283c564c1338f65

Section 13 Phase A:
HOLD

Blocker: 0
High:    1
Medium:  3
```

## Development Gate

Do **not** start Section 13 Phase B (13.4+) yet.

Repair `13.A.R1` first because it is the evidence-run-layout audit boundary.  
`13.A.R2` and `13.A.R3` should be closed in the same repair cycle before the Gower engine begins consuming `evidence-feature-v1`.
