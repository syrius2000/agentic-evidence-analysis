# Section 15 — Independent Re-QA Review 2

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `94e05f14e65fe3a7bd2d1c0317e30370b044774e`
- **Reviewed commit:** `c7383cece5c7d5cefef41622c07747c010eb6137`
- **Scope:** Section 15 — Documentation and Ecosystem Synchronization, including remediation for H15-01 / M15-01 / M15-02 / M15-03
- **Review mode:** blind-first independent Re-QA
- **Review date:** 2026-09-26 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
Section 15:
HOLD

Blocker: 0
High:    1
Medium:  3
```

The four findings from Review1 are closed. Four new in-scope synchronization/integrity findings remain.

---

## 1. Commit / Scope Verification

GitHub compare:

```text
base          = 94e05f14e65fe3a7bd2d1c0317e30370b044774e
head          = c7383cece5c7d5cefef41622c07747c010eb6137
status        = ahead
ahead_by      = 3
behind_by     = 0
total_commits = 3
merge_base    = 94e05f1...
```

No commit-bound GitHub status or workflow run is present for the reviewed SHA.

The reviewed range contains the original Section 15 implementation plus remediation commits.

---

## 2. Review1 Finding Closure

### H15-01 — CLOSED

The repository now contains exactly nine skill directories under `.agents/skills`:

```text
comparative-design-analysis
evidence-decision-review
questionnaire-batch-analysis
sas-proc-freq
sas-proc-means
vcd-bayesian-evidence-analysis
vcd-categorical-analysis
vcd-categorical-reporting
vcd-pass0-consultation
```

`AGENTS.md` and `README.md` now both state `全9スキル`.

`tests/test_skill_ownership_contract.py` now enumerates all nine skills and requires every SKILL frontmatter description to start with `Use when`. Independent fixed-SHA inspection confirmed all nine current SKILL descriptions satisfy that contract.

**H15-01: CLOSED.**

### M15-01 — CLOSED

`.agents/skills/vcd-categorical-reporting/SKILL.md` now correctly states:

```text
comparative_evidence.json:
top-level      = comparative-evidence-batch-v1
contrasts[*]   = comparative-evidence-v1
```

This matches `comparative_reporting.R`.

**M15-01: CLOSED.**

### M15-02 — CLOSED

The person-time guide now documents the Jeffreys improper prior as:

```text
p(lambda) proportional to lambda^(-1/2)
posterior Gamma(x_g + 0.5, rate=T_g)
```

and the zero-reference diagnostic as:

```text
incidence_rate_ratio$diagnostic = "ZERO_REFERENCE_EVENTS"
```

This matches `.agents/shared/comparative_contrasts.R` and `tests/test_person_time_rate.R`.

**M15-02: CLOSED.**

### M15-03 — CLOSED

The historical Batch 001 summary and its batch-local copy now carry an explicit Historical Record / Superseded Architecture note explaining that the old five-skill / legacy `vcd-categorical-reporting` statement is historical and superseded by the current nine-skill ecosystem.

This satisfies the requested legacy/supersession marking without rewriting the historical statement itself.

**M15-03: CLOSED.**

---

## 3. H15-02 — Archive Manifest Integrity Broken by Editing Archived Source Bytes

**Severity:** HIGH  
**Task:** 15.8

Task 15.8 requires historical archive artifacts to remain untouched except where necessary for pointer reconciliation.

The reviewed range changes two archived source files that are protected by stored SHA-256 values in:

```text
docs/Archives/20260912_183500_002/archive_manifest.json
```

The affected files are:

```text
docs/Archives/20260912_183500_002/sources/implementation_plan_006_0906.md
docs/Archives/20260912_183500_002/sources/implementation_plan_013_0912.md
```

The changes are not limited to an external summary pointer. They alter the archived source bytes, including removal/rewording of historical absolute-path references.

The reviewer independently recomputed SHA-256 from the exact files in the reviewed commit.

### implementation_plan_006_0906.md

```text
manifest SHA-256:
8f0941066623d9a815be3764358581b92a2eba67cdde9ccddc599fa053b94af2

current SHA-256:
671f601e75022ad1220c058b1a9fb8c4fcb277e24a970250c9b7b0a12afb249a

MATCH = FALSE
```

### implementation_plan_013_0912.md

```text
manifest SHA-256:
f9ed4c691041a105c31084c31711e831af3f5a93d1e1e4a66a7b358c96d38ae9

current SHA-256:
235a1dd845c546c8fb7d586abc7321fa5c5e6a4de31fa71311154e2fddf53368

MATCH = FALSE
```

This is a deterministic audit-integrity failure: the archive manifest claims exact source identities that no longer match the archived files.

### Required repair — 15.R1

Restore the two archived source files byte-for-byte to their manifest-bound versions.

Do **not** update the manifest hashes to the newly edited bytes; the manifest records the archived originals.

For current documentation hygiene:

- keep supersession/legacy notes in archive summaries or an archive index;
- perform pointer reconciliation in summaries/indexes;
- exclude immutable archived source bodies from a current-doc local-path hygiene rule when the path is historical evidence;
- or treat historical path strings as non-navigation content without modifying archived source bytes.

Add an archive-integrity test that recomputes every manifest-bound source SHA-256 and fails on mismatch.

---

## 4. M15-04 — Pass 0 Canonical Skill Guide Still Has the Old Applicability Boundary

**Severity:** MEDIUM  
**Tasks:** 15.1 / 15.4

`AGENTS.md` and `docs/reference/skill_responsibilities.md` now say Pass 0 is mandatory for `comparative-design-analysis` design-aware workflows.

However the canonical entry skill itself still says:

```text
Pass 0は、新規の vcd-categorical-analysis および
vcd-bayesian-evidence-analysis で必須です。
questionnaire-batch-analysis では...推奨します。
```

It does not mention:

```text
comparative-design-analysis -> mandatory
vcd-categorical-reporting  -> recommended
```

despite later sections adding routing questions for those workflows.

This leaves the ecosystem with contradictory instructions at the exact skill that governs Pass 0.

### Required repair — 15.R2

Synchronize `.agents/skills/vcd-pass0-consultation/SKILL.md` applicability text with the accepted governance matrix:

```text
mandatory:
  vcd-categorical-analysis
  vcd-bayesian-evidence-analysis
  comparative-design-analysis design-aware routes

recommended:
  vcd-categorical-reporting
  questionnaire-batch-analysis

not required:
  sas-proc-freq
  sas-proc-means
  tests / code-doc maintenance
```

Add this contract to an executable documentation test so future routing changes cannot drift.

---

## 5. M15-05 — Plan 020 “Zero-Guesswork” Section Still Contains Non-Canonical Names

**Severity:** MEDIUM

`docs/Artifacts/implementation_plan_020_0926.md` remains an active Section 15 traceability artifact and explicitly labels its section as **Zero-Guesswork**, but it contains several values that do not match the reviewed runtime/repository.

Examples:

### IPTW/matched-set inference semantics

Plan:

```text
inferential_semantics = "bootstrap_resampling"
resample_median
```

Runtime:

```text
inferential_semantics = "bootstrap"
estimate.source        = "observed_sample_estimate"
interval.method        = "bootstrap_percentile"
```

### Decision-ledger schema filename

Plan:

```text
schemas/decision-ledger-v1.json
```

Repository:

```text
schemas/decision-ledger-record-v1.json
```

### Skill-count / conceptual-count wording

The plan still refers to:

```text
統計 6 次元
既存 5 スキルに加え...
```

while the implemented ecosystem documents the seven-way separation and nine-skill inventory.

### Required repair — 15.R3

Revise Plan 020's final/as-executed contract or append an explicit post-execution correction section containing the actual canonical values.

Because this is an audit artifact, do not silently rewrite intent without noting that the correction was made after implementation.

---

## 6. M15-06 — Quality Loop Manual Pointer Was Reconciled to the Wrong Plan

**Severity:** MEDIUM  
**Task:** 15.9 / pointer reconciliation

`docs/reference/quality_loop_manual_001_0912.md` displays:

```text
implementation_plan_016_0912.md
```

but the reviewed range changes its target to:

```text
docs/Archives/20260912_183500_002/sources/implementation_plan_013_0912.md
```

That target exists, so a simple broken-link checker passes, but it is the wrong document.

The actual archived plan is recorded under Batch 003:

```text
docs/Archives/20260913_195758_003/sources/implementation_plan_016_0912.md
```

and the Batch 003 archive manifest records the same source/destination relationship.

### Required repair — 15.R4

Point the manual's `implementation_plan_016_0912.md` reference to the actual Batch 003 source.

This is a semantic-link correctness issue that path-existence-only auditing cannot detect.

---

## 7. Link / Ownership Verification Notes

The current nine-skill inventory is internally consistent across the actual skill directory and the updated ownership test.

The previously identified legacy report-template `./skill_out/...` links are inside a fenced legacy template example and should not be treated as live repository navigation links.

The implementer reports:

```text
python3 tests/test_skill_ownership_contract.py : 8 PASS / 0 FAIL
Rscript tests/test_vcd_categorical_reporting.R: 35 PASS / 0 FAIL
Rscript tests/test_comparative_dashboard_qa.R : 68 PASS / 0 FAIL
OpenSpec strict validation                     : valid
git diff --check                              : clean
```

These are implementer execution evidence. No commit-bound CI/status evidence is present for the reviewed SHA.

The independent review did not rerun the R suites.

---

## 8. Final Gate

```text
Review1 findings:
H15-01: CLOSED
M15-01: CLOSED
M15-02: CLOSED
M15-03: CLOSED

New findings:
H15-02: OPEN  — archive manifest/source SHA mismatch
M15-04: OPEN  — Pass 0 applicability drift
M15-05: OPEN  — Plan 020 canonical-name drift
M15-06: OPEN  — semantic mis-link to plan 013 instead of plan 016

Blocker 0
High    1
Medium  3

Section 15:
HOLD
```

Section 16 should remain gated until 15.R1–15.R4 are independently closed.
