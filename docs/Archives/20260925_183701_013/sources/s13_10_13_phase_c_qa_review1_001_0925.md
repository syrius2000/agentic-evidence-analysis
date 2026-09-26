# Section 13.10–13.13 — Independent QA Review 1

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `9f7e4a38e2593e2b84e3114e8ac210eea6cc8e10`
- **Reviewed commit:** `bfc53bc33333d22905ec0bc8b32e176d9f4fae66`
- **Scope:** Section 13.10–13.13 only
- **Out of scope:** 13.9 ledger (CLOSED), Section 14 HTML, Section 15 docs sync
- **Review mode:** blind-first independent QA
- **Review date:** 2026-09-25 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
Section 13.10–13.13:
HOLD

Blocker: 0
High:    2
Medium:  2
```

**Do not start Section 14 yet.**

The common-path implementation for configurable discordance, advisory wording, trajectory construction, and the NOT_ASSESSED stability fallback is directionally sound. However, two core semantic violations remain:

1. legitimate decision-state text can make the advisory path throw instead of remaining advisory-only; and
2. the ASSESSED stability path is not a patient-level bootstrap despite being labeled as such.

---

## 1. Commit / Scope Verification

The requested review range is exactly one commit:

```text
9f7e4a38e2593e2b84e3114e8ac210eea6cc8e10
    ↓
bfc53bc33333d22905ec0bc8b32e176d9f4fae66
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 9f7e4a38...
```

The changed implementation surface is consistent with the requested scope:

- `.agents/shared/evidence_discordance.R`
- `.agents/shared/evidence_trajectory.R`
- `.agents/shared/evidence_cluster.R` (13.13 additions)
- `schemas/discordance-advisory-v1.json`
- `schemas/decision-trajectory-v1.json`
- tests for discordance / trajectory / cluster stability
- OpenSpec task and skill documentation
- plan 026 / execution record

No Section 14 HTML implementation was reviewed.

No commit-bound GitHub status or workflow run was present for the reviewed commit.

---

## 2. Blind-First Positive Findings

### 13.10 configurable discordance

The policy boundary is clear and mutually exclusive:

```text
k_neighbors      -> positive integer k, radius must be NULL
distance_radius  -> finite radius in [0,1], k must be NULL
```

Neighborhood hits are sorted by Gower distance, the selected neighborhood decision distribution is counted, and a unique modal state is used as `dominant_state`. A tie is explicitly represented and does not raise a candidate.

The generated candidate object is advisory-only:

```text
advisory_flag = "QA Review Candidate"
severity = "advisory"
halts_workflow = FALSE
exploratory_only = TRUE
decision_rule = FALSE
```

### 13.11 wording intent

The canonical wording correctly says the divergence is informational and does not halt workflow progression. Explicit hard-failure wording patterns are defined and tested.

### 13.12 trajectory common path

`build_decision_trajectory()`:

- requires one case identity;
- sorts by decision timestamp, then record ID;
- records state sequence and transition count;
- carries study phase / data cutoff metadata;
- preserves exploratory-only / non-decision-rule governance.

The direct event path is coherent.

### 13.13 NOT_ASSESSED fallback

When patient-level dependence is unavailable:

```text
stability_status = "NOT_ASSESSED"
stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"
```

is returned without claiming pseudo-stability from marginal term summaries. This part matches the OpenSpec requirement.

---

## 3. H13.10-01 — Wording Audit Scans Decision States and Can Halt Legitimate Advisory Evaluation

**Severity:** HIGH  
**Gate:** blocking 13.10 / 13.11

The wording contract is intended to prevent the **system** from labeling discordance as an error, invalid state, fatal defect, or automatic rejection.

The implementation instead recursively scans **every character value** in the advisory result:

```r
collect(obj)
blob <- paste(texts, collapse = "\n")
```

This includes user/historical domain data such as:

```text
provisional_decision_state
dominant_state
```

The forbidden pattern list includes:

```r
"\\breject(ed|ion)?\\b"
```

Therefore a legitimate decision state such as:

```text
REJECT
REJECTED
```

causes `assert_discordance_wording_contract()` to throw `DISCORDANCE_WORDING_VIOLATION`.

Example:

```text
provisional_decision_state = "REJECT"
precedent dominant state    = "ACCEPT"
```

The function first identifies a discordance, constructs an advisory result, and then rejects its own output because the **decision label** contains a forbidden wording token.

This violates the Section 13.10/13.11 requirement that divergence itself must remain an informational advisory and **must not halt workflow progression**.

### Required repair — 13.10.R1 / 13.11.R1

Restrict the wording audit to **system-controlled advisory fields**, for example:

```text
wording
severity
advisory_flag
optional system status/reason fields
```

Do **not** apply forbidden-language scanning to:

```text
provisional_decision_state
dominant_state
historical decision labels
case IDs
other source/domain data
```

Continue validating:

```text
halts_workflow == FALSE
candidate -> advisory_flag == "QA Review Candidate"
candidate -> severity == "advisory"
non-candidate -> no severity/advisory_flag
```

### Required tests

```text
provisional = REJECT, dominant = ACCEPT
  -> QA Review Candidate
  -> no exception

provisional = ACCEPT, dominant = REJECTED
  -> QA Review Candidate
  -> no exception

system wording = "fatal system error"
  -> DISCORDANCE_WORDING_VIOLATION
```

---

## 4. H13.13-01 — ASSESSED Path Is Not a Patient-Level Bootstrap

**Severity:** HIGH  
**Gate:** blocking 13.13

The OpenSpec and plan require:

```text
joint patient-level resampling
patient rows available
resample patients
re-evaluate clustering in each replicate
preserve cross-theme dependence
```

The current implementation does not do this.

### Current algorithm

The function accepts:

```r
distance_matrix
patient_rows
```

but `patient_rows` contributes only a `subject_id` vector.

It then requires:

```r
nrow(patient_rows) == nrow(distance_matrix)
anyDuplicated(subject_id) == FALSE
```

and performs:

```r
idx <- sample.int(n, size = n, replace = TRUE)
uniq <- unique(idx)
sub_mat <- distance_matrix[uniq, uniq, drop = FALSE]
hclust(as.dist(sub_mat))
```

### Why this is not patient-level resampling

1. **No patient measurements are resampled.**  
   The bootstrap never uses outcomes, treatment/group membership, theme/PT membership, or any raw patient-level analytical data.

2. **The distance matrix is fixed.**  
   Evidence features and pairwise Gower distances are never recomputed within a replicate.

3. **Clustered units are resampled, not patients.**  
   `sample.int(n)` indexes the rows/columns of the already-computed cluster distance matrix.

4. **Bootstrap multiplicity is discarded.**  
   `unique(idx)` removes repeated draws, converting the procedure into stochastic inclusion/subsampling of clustering units rather than a bootstrap refit.

5. **Shared patient dependence cannot be represented.**  
   The function explicitly rejects duplicate `subject_id`, while cross-theme patient-level dependence normally requires the same subject to contribute across multiple theme/PT rows.

The current test reinforces the mismatch:

```r
patients <- data.frame(
  subject_id = c("S1", "S2", "S3")
)
```

with exactly one subject ID per distance-matrix clustering unit.

A caller can therefore supply arbitrary unique identifiers next to a fixed distance matrix and receive:

```text
stability_status = "ASSESSED"
method = "patient_bootstrap_co_clustering"
```

without any patient-level resampling having occurred.

That is a false semantic claim and does not satisfy Section 13.13.

### Required repair — 13.13.R1

Choose one of two safe paths.

#### Preferred: real patient-level bootstrap

Require enough raw patient-level information and a replicate callback / engine contract to:

1. identify atomic subject IDs;
2. sample subjects with replacement;
3. preserve all rows for each sampled subject across themes/terms;
4. recompute the evidence features for all clustered units;
5. recompute Gower distance;
6. rerun HAC with the same fixed `k` / linkage;
7. map replicate assignments back to the original clustering units;
8. accumulate co-clustering probabilities;
9. record failed/skipped replicate diagnostics.

The bootstrap interface must distinguish:

```text
patient rows
clustered evidence-profile units
subject membership across themes
```

#### Safe interim alternative

Until a true patient-level refit interface exists, keep:

```text
stability_status = "NOT_ASSESSED"
stability_reason = "CROSS_THEME_DEPENDENCE_UNAVAILABLE"
```

and do not expose the current fixed-distance subsampling procedure as `patient_bootstrap_co_clustering`.

### Required tests

Use a fixture where subjects appear across multiple themes/units and verify that a bootstrap replicate is driven by sampled subjects and regenerated evidence/distances, not by selecting rows/columns of a precomputed distance matrix.

---

## 5. M13.12-01 — `trajectory_from_ledger()` Does Not Verify Ledger Integrity

**Severity:** MEDIUM

The Section 13.12 helper is explicitly presented as the connection to the Section 13.9 tamper-evident ledger.

However:

```r
trajectory_from_ledger()
```

does not call:

```r
verify_decision_ledger(ledger)
```

before reading:

```text
decision_state
decided_at_jst
record_id
actor_id
```

A ledger record can therefore be modified after hashing, or a chain link can be broken, and the trajectory helper can still consume the modified values.

The test suite exercises only a valid ledger path.

### Required repair — 13.12.R1

At the beginning of `trajectory_from_ledger()`:

```r
verify_decision_ledger(ledger)
```

or enforce an equivalent verified-ledger boundary.

Required negative tests:

```text
tampered decision_state with stale hash -> reject
broken previous_record_sha256 chain     -> reject
duplicate ledger record_id              -> reject via ledger verifier
```

This keeps ledger-derived trajectories cryptographically tied to the accepted 13.9 provenance contract.

---

## 6. M13.13-02 — Stability Can Be Attached to an Unrelated Cluster Result

**Severity:** MEDIUM

`assess_cluster_stability()` returns provenance including:

```text
n_units
k
linkage
seed
subject_ids
pair_co_clustering dimensions
```

but `attach_cluster_stability()` does not verify that the assessment matches the target cluster result.

It can attach an assessment generated with different:

```text
n / labels
k
linkage
dataset
```

and it does not preserve all of those provenance fields on the cluster result.

It also accepts any list-shaped cluster result, so an HAC-derived stability object can be attached to a different clustering method without compatibility checks.

### Required repair — 13.13.R2

Before attachment, verify at least:

```text
cluster_result n_cases == stability n_units
cluster_result k       == stability k
cluster_result linkage == stability linkage  (for HAC)
pair_co_clustering dimensions / dimnames match cluster labels
```

Either:

- restrict the API to compatible HAC results; or
- define method-specific stability contracts.

Persist enough provenance on the attached result to audit which stability assessment was used.

Required tests:

```text
mismatched k       -> reject
mismatched n       -> reject
mismatched linkage -> reject
mismatched labels  -> reject
compatible object  -> accept
```

---

## 7. Implementer Claims — Checked Only After Blind Review

The supplied execution record reports:

```text
tests/test_evidence_discordance.R : 23 PASS / 0 FAIL
tests/test_evidence_trajectory.R  : 15 PASS / 0 FAIL
tests/test_evidence_cluster.R     : 65 PASS / 0 FAIL
run_regression_suite.R            : 49/49 PASS
OpenSpec strict                   : valid
git diff --check                  : clean
```

These do not alter the independent findings above.

The tests cover the intended happy paths but do not cover:

- legitimate decision labels containing `REJECT/REJECTED`;
- a true multi-theme patient-level bootstrap refit;
- tampered ledger input to `trajectory_from_ledger()`;
- attaching stability to an incompatible cluster result.

No commit-bound CI/status evidence was present.

---

## 8. Repair Tasks

### 13.10/13.11.R1 — Scope Wording Audit to System-Generated Advisory Text

**Priority:** P0  
**Severity:** High

- [ ] exclude domain decision labels from forbidden wording scan;
- [ ] keep strict checks on system wording, severity, advisory flag, and `halts_workflow`;
- [ ] add REJECT/REJECTED decision-state fixtures;
- [ ] prove discordance never throws merely because of a legitimate decision label.

### 13.13.R1 — Replace Fixed-Distance Unit Resampling with Real Patient-Level Refit

**Priority:** P0  
**Severity:** High

- [ ] define patient-to-theme/unit membership contract;
- [ ] bootstrap subjects with replacement;
- [ ] preserve all rows for sampled subjects;
- [ ] recompute evidence features and Gower distances per replicate;
- [ ] rerun HAC fixed-k per replicate;
- [ ] accumulate co-clustering on original clustering units;
- [ ] record failed/usable replicate counts;
- [ ] otherwise remain `NOT_ASSESSED`.

### 13.12.R1 — Verify Ledger Before Deriving Trajectory

**Priority:** P1  
**Severity:** Medium

- [ ] call `verify_decision_ledger()` or equivalent;
- [ ] add tamper / broken-chain negatives.

### 13.13.R2 — Bind Stability Provenance to Target Cluster Result

**Priority:** P1  
**Severity:** Medium

- [ ] verify n / k / method / linkage / labels compatibility;
- [ ] reject cross-dataset or cross-method attachment;
- [ ] persist stability provenance on the attached result.

### Regression gate

After repair, rerun and record:

```bash
Rscript tests/test_evidence_discordance.R
Rscript tests/test_evidence_trajectory.R
Rscript tests/test_evidence_cluster.R
Rscript tests/test_evidence_precedent.R
Rscript tests/test_evidence_ledger.R
Rscript tests/run_regression_suite.R
openspec validate comparative-evidence-reporting-v3 --strict
git diff --check
```

---

## 9. Final Gate

Current:

```text
13.10 / 13.11:
HOLD
High 1

13.12:
Core path implemented
Medium 1 open

13.13:
HOLD
High 1
Medium 1

Overall:
Blocker 0
High    2
Medium  2

Section 13.10–13.13:
HOLD
```

Expected after repair:

```text
Blocker 0
High    0
Medium  0

Section 13.10–13.13:
PASS / ACCEPT
```

**Section 14 should remain gated until the two High findings are independently closed.**
