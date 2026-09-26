# Section 16 — Blind-First Independent QA Review 1

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `fabae6ef8de31608bb458055ef2e5adbd64e9da7`
- Reviewed commit: `f3e1a18ccee98695eaf326ee21033a134a5a834c`
- Scope: Section 16 — Independent QA and Regression Verification Gate (Tasks 16.1–16.13)
- Plan: `docs/Artifacts/implementation_plan_021_0926.md`
- Execution record: `docs/Artifacts/s16_independent_qa_exec_001_0926.md`
- Review mode: blind-first independent QA
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
Section 16: HOLD

Blocker: 0
High:    1
Medium:  1
```

The underlying implementation and previously accepted Section 13–15 contracts remain materially sound. The HOLD is caused by defects in the Section 16 verification artifacts themselves plus the still-unobtained Owner adjudication required by Task 16.13.

Section 17 must remain gated.

---

## 1. Commit / Scope Verification

The requested range is exactly one commit:

```text
fabae6ef8de31608bb458055ef2e5adbd64e9da7
    ↓
f3e1a18ccee98695eaf326ee21033a134a5a834c
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = fabae6e...
```

Changed files are limited to:

```text
docs/Artifacts/implementation_plan_021_0926.md
docs/Artifacts/s16_independent_qa_exec_001_0926.md
openspec/changes/comparative-evidence-reporting-v3/tasks.md
```

No implementation/runtime code changed in the reviewed commit.

No commit-bound GitHub status or workflow run exists for the reviewed SHA.

The reviewer runtime does not provide `Rscript` / `R`, so the claimed R test counts were not independently rerun.

---

## 2. Blind-First Contract Verification — Positive Findings

### 16.2 Zero-reference mathematical behavior

The independent Jeffreys Beta-Binomial engine correctly enforces integer counts and routes posterior draws into the shared contrast engine.

For `x_R = 0`:

```text
relative_risk.mean           = null
relative_risk.mean_is_finite = false
diagnostics.badges           includes ZERO_REFERENCE
estimate.source              = posterior_median
interval.method              = posterior_eti
```

The zero-reference tests also confirm a finite posterior RR median while suppressing the divergent theoretical mean.

### 16.3 Practical-difference disablement

The runtime correctly implements:

```text
primary_delta = NULL
practical_region_support = NULL
resolution_grade.grade = "NONE"
resolution_grade.dominant_region = "none"
```

The dashboard renderer leaves the Practical Difference cell transparent when the active delta is absent.

### 16.4 U-Grade semantics

The shared contrast engine derives U0–U3 from `C = max(q_T, q_N, q_R)` and keeps it structurally separate from precision metrics.

The accepted Section 14 renderer correctly uses the non-alarm U3 override:

```text
rgba(148, 163, 184, 0.12)
```

and the deterministic dashboard QA fixture explicitly tests this value.

### 16.5 Posterior / bootstrap terminology separation

The shared contrast engine selects:

```text
posterior:
  estimate.source = posterior_median
  interval.method = posterior_eti
  direction label = P(RD > 0)

bootstrap:
  estimate.source = observed_sample_estimate
  interval.method = bootstrap_percentile
  direction label = Bootstrap Support Fraction (RD > 0)
```

The report renderer derives displayed interval/support labels from these semantics rather than hard-coding ETI for bootstrap evidence.

### 16.6 Weighted/non-integer input boundary

Two distinct guards exist:

```text
independent engine:
  non-integer count -> NON_INTEGER_COUNT

Pass 0 routing:
  weighted/non-integer independent pseudo-count -> UNSUPPORTED_WEIGHTED_INPUT
  complex survey weight -> UNSUPPORTED_SURVEY_DESIGN
  IPTW weights -> comparative-design-analysis / bootstrap
```

The routing tests explicitly exercise weighted-pseudo-count and complex-survey cases.

### 16.7 Safety hierarchy invariant

`safety_adapter.R` separately deduplicates subjects within PT and within SOC. The fixture proves child PT counts can sum to 2 while the SOC subject count remains 1.

### 16.8 Multiplicity disclaimer

The generated Markdown and HTML contain explicit exploratory-screening wording that FWER is not controlled and the output is for hypothesis generation / exploratory prioritization.

### 16.9 No automated regulatory decision

The evidence feature contract explicitly forbids decision/regulatory label keys from clustering features. Discordance output is advisory-only:

```text
is_qa_review_candidate
advisory_flag = "QA Review Candidate"
severity      = "advisory"
halts_workflow = false
exploratory_only = true
decision_rule = false
```

---

## 3. H16-01 — Final Verification Artifacts Contain Multiple Non-Canonical / Unsupported Contract Claims

Severity: HIGH

Section 16 is itself the final independent QA and regression verification gate. Its plan labels a section Zero-Guesswork and the execution record declares `ALL GATES PASSED (PASS: 13 / 13 Tasks)`, but multiple statements do not match the reviewed runtime/schema/test contracts.

This is not a new statistical-engine defect. It is a defect in the evidence used to certify the final gate.

### H16-01a — Independent zero-reference RR diagnostic is mis-specified

Plan 021 states the posterior independent zero-reference contract includes:

```text
relative_risk.diagnostic = "ZERO_REFERENCE_RISK"
```

The independent Beta-Binomial path actually provides:

```text
relative_risk.mean           = null
relative_risk.mean_is_finite = false
diagnostics.badges           includes ZERO_REFERENCE
```

`comparative_contrasts.R` does not add `relative_risk$diagnostic` for this posterior path. `ZERO_REFERENCE_RISK` belongs to design-aware/bootstrap RR suppression paths.

### H16-01b — `primary_delta = null` canonical structure is mis-specified

Plan 021 states `u_grade = null` and `region = null`. The actual evidence contract is:

```text
practical_region_support = NULL
resolution_grade.grade = "NONE"
resolution_grade.dominant_region = "none"
resolution_grade.max_region_probability = NULL
```

### H16-01c — Decision-ledger genesis hash contract is wrong

Plan 021 states `previous_record_sha256` is 64 hex or genesis `0000...`.

The accepted Section 13.9 runtime/schema require:

```text
genesis previous_record_sha256 = null
non-genesis previous_record_sha256 = prior record_sha256
```

Runtime explicitly rejects a non-null previous hash when `expect_genesis=TRUE`.

### H16-01d — Discordance advisory fields are invented/misnamed

Plan 021 states:

```text
divergence_status = "QA_REVIEW_CANDIDATE"
```

No such canonical field/value exists. The actual schema/runtime uses:

```text
is_qa_review_candidate = true|false
advisory_flag = "QA Review Candidate" | null
severity = "advisory" | null
halts_workflow = false
exploratory_only = true
decision_rule = false
```

The execution record repeats the noncanonical underscore value `QA_REVIEW_CANDIDATE`.

### H16-01e — U3 color evidence cites the wrong color

Plan TM16.3 and the execution record state U3 renders as `#e2e8f0`.

The canonical Section 14 renderer and deterministic test use:

```text
rgba(148, 163, 184, 0.12)
```

`#e2e8f0` is used elsewhere as a generic border/grid color, not the U3 Practical Difference override.

### H16-01f — Zero-reference UI evidence claims unimplemented em-dash/tooltip behavior

The execution record claims zero-reference RR is shown as an em dash plus tooltip.

The reviewed renderer actually uses:

```text
N/A
or x.xx [N/A]
plus #numerical-instability-warning callout
plus diagnostic badge(s)
```

No RR-specific tooltip contract was found.

### H16-01g — Nonexistent departmental policy evidence is claimed

Task 16.4 execution evidence claims validation of `departmental_policy.json` and a U-Grade disclaimer therein.

No `departmental_policy.json` exists in the reviewed repository, and OpenSpec Task 7.4 remains unchecked.

Do not implement deferred Task 7.4 merely to make Section 16 documentation true; remove/correct the evidence claim unless separately authorized.

### H16-01h — Archive test description overstates coverage

The execution record says the five archive-integrity suites validate all historical archive metadata, SHA-256, and relative-path links.

The Python test verifies SHA-256 for selected batches/entries. It is not a generic all-manifest metadata/link audit and does not cover every SHA-bearing archive manifest.

### Required repair — 16.R1

Reconcile both:

```text
docs/Artifacts/implementation_plan_021_0926.md
docs/Artifacts/s16_independent_qa_exec_001_0926.md
```

against runtime/schema/test source of truth.

Prefer an explicit post-execution canonical reconciliation section if preserving the original plan draft is desired.

At minimum correct:

```text
posterior zero-reference badge/mean contract
primary_delta NULL -> resolution_grade NONE
ledger genesis previous hash -> NULL
discordance canonical fields and "QA Review Candidate" value
U3 exact rgba override
zero-reference N/A + warning presentation
remove nonexistent departmental_policy.json evidence
state exact archive-integrity test coverage
```

Do not change already accepted runtime behavior merely to make the Section 16 documentation true.

---

## 4. M16-01 — Task 16.13 Is Checked Complete Before Explicit Owner Adjudication Exists

Severity: MEDIUM

OpenSpec Task 16.13 requires:

```text
Record unresolved risks and obtain explicit Owner adjudication.
```

The execution record records three residual operational conditions, but also explicitly says:

```text
要 Owner 最終確認
Owner の裁定を仰ぐ
```

Therefore the record itself shows that Owner adjudication had not occurred when the reviewed commit marked `[x] 16.13` and declared all 13/13 gates passed.

The current request is a request for independent QA, not an explicit acceptance/rejection of those residual risks.

### Required repair — 16.R2

Until Owner adjudication occurs:

```text
16.13 = [ ]
Section 16 = HOLD
```

After the Owner explicitly accepts, rejects, or conditions the three residual risks:

- record the adjudication with enough scope/date/SHA context;
- then mark 16.13 complete.

Section 17.5 separately requires explicit Owner sign-off on remaining documented operational risks, so Section 16 must not manufacture that sign-off in advance.

---

## 5. Task 16.1 Status After This Review

This report supplies the independent QA artifact required by Task 16.1. Therefore 16.1 itself does not need another implementation repair, but the review outcome is HOLD, not unconditional PASS.

The Section 16 execution record should reference this QA report rather than self-certifying independent review completion.

---

## 6. Implementer Evidence

The execution record reports:

```text
R canonical regression suite     : 50 / 50 PASS
Python skill ownership tests     : 10 / 10 PASS
Python archive integrity suites  : 5 / 5 PASS
OpenSpec strict validation       : valid / 0 issues
git diff --check                 : clean
```

These are treated as implementer execution evidence.

The reviewer runtime has no `Rscript` or `R`, so the R suite was not independently rerun. No commit-bound GitHub CI/status evidence exists for the reviewed SHA.

The source/test inspection found no new in-scope statistical-engine or renderer defect.

---

## 7. Final Gate

```text
16.1: independent review now performed — outcome HOLD
16.2–16.9: underlying implementation contracts materially verified
16.10: implementer regression evidence present; no commit-bound CI
16.11: implementer OpenSpec-valid evidence present
16.12: implementer diff-clean evidence present
16.13: OPEN — explicit Owner adjudication not yet obtained

H16-01: OPEN — Section 16 final QA artifacts contain noncanonical/unsupported claims
M16-01: OPEN — Owner adjudication pending

Blocker 0
High    1
Medium  1

Section 16:
HOLD
```

Expected after 16.R1 + 16.R2:

```text
Blocker 0
High    0
Medium  0

Section 16:
PASS / ACCEPT
```

Section 17 must remain gated until the Section 16 evidence record is reconciled and explicit Owner adjudication is recorded.