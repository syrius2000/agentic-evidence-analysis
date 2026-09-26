# Section 14 Dashboard Extension — Independent Re-QA Review 4

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `c7b54d18e16cd55d0c4a6c13b13c38a3d57b660f`
- Reviewed: `384bddf9c9d264200d11c53bc78b26762e34ef50`
- Scope: remediation of H14.13-01 / M14.11-01 / M14.14-01
- Plan: `docs/Artifacts/implementation_plan_022_0926.md`
- Execution record: `docs/Artifacts/s16_independent_qa_exec_002_0926.md`
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
M14.11-01 / 14.11.R1: CLOSED
M14.14-01 / 14.14.R1: CLOSED
H14.13-01 / 14.13.R1: PARTIAL — residual H14.13-02 OPEN

Blocker 0
High    1
Medium  0

Tasks 14.11–14.14: HOLD
Section 16 final gate: HOLD
```

## 1. Commit / scope verification

The requested range is exactly one commit, merge-base equals the supplied baseline, and branch HEAD equals the reviewed SHA.

No commit-bound GitHub status or workflow run exists for the reviewed SHA.

## 2. M14.11-01 — CLOSED

The embedded dashboard JSON retains the internal `row_key`, but `generateCsv()` now explicitly excludes it:

```javascript
Object.keys(rowsData[0]).filter(function(h) { return h !== "row_key"; })
```

The canonical tracked `comparative_summary.csv` has 36 columns. The embedded JSON has those same 36 canonical columns plus `row_key` = 37 fields.

The new regression assertion checks that export headers are identical, in order, to `names(summary_df)` after excluding `row_key`.

Therefore the Excel-facing CSV contract is now correctly separated from the DOM linkage key.

## 3. M14.14-01 — CLOSED

The execution record now correctly identifies:

- six fixture rows;
- 36 canonical CSV columns;
- 37 embedded fields including `row_key`;
- `SPARSE_EVENTS` as the canonical badge name;
- Node.js/static logic audit separately from Chrome rendering and Owner visual inspection.

A new coherent visual QA run exists at:

`evidence_runs/visual_qa_s14/run_20260926_170532/`

The reviewer independently recomputed the tracked HTML SHA-256:

```text
manifest:
3bafd39eda66f4d853af91ec6b1e378db4a35535a048aaa639df5a2e7647e90c

recomputed:
3bafd39eda66f4d853af91ec6b1e378db4a35535a048aaa639df5a2e7647e90c

MATCH = TRUE
```

The screenshot is a new artifact for the new run and the Owner reports the visual appearance as acceptable.

## 4. H14.13-02 — HTML mathematical guide is not inferential-semantics adaptive

Severity: HIGH

The remediation correctly makes the Markdown guide adaptive through:

```text
has_bayesian_sem
has_bootstrap_sem
```

and the bootstrap Markdown path avoids posterior/ETI terminology.

However the HTML accordion remains a single fixed literal block. Its Risk section always states:

```text
Jeffreys Beta(0.5, 0.5)
posterior median
95% ETI
```

even when the rendered rows are `inferential_semantics = "bootstrap"` (e.g. IPTW or matched-set evidence).

This is not only irrelevant wording. It contradicts the canonical runtime contract:

```text
posterior:
  estimate.source = posterior_median
  interval.method = posterior_eti

bootstrap:
  estimate.source = observed_sample_estimate
  interval.method = bootstrap_percentile
```

The current tests exercise Bayesian HTML guide wording and bootstrap Markdown wording, but do not assert that bootstrap HTML is free of posterior/Jeffreys point-estimate claims.

The RR accordion also presents the Jeffreys zero-reference theoretical-mean divergence as a universal `x_R = 0` explanation. Design-aware/bootstrap evidence instead has its own governed RR availability/diagnostic contract, so this text must be conditioned by inferential semantics as well.

Additionally, the bootstrap-only Markdown Risk guide currently says:

```text
リサンプリング分布に基づくブートストラップ推定量を使用
```

but the canonical shared contrast engine uses `estimate.source = observed_sample_estimate`; bootstrap draws govern interval/support, not the primary point-estimate source.

### Required repair — 14.13.R2

Make the HTML mathematical guide use the same semantic branching as the Markdown guide.

Recommended contract:

```text
posterior-only report:
  describe Jeffreys model + posterior median + posterior ETI

bootstrap-only report:
  describe observed-sample point estimate
  bootstrap percentile interval
  bootstrap support fraction
  no Jeffreys/posterior-median claim as the active estimator

mixed report:
  explicitly describe both contracts and state that each row follows inferential_semantics
```

For zero-reference RR, distinguish:

- independent posterior: theoretical posterior RR mean may diverge while median/ETI can remain finite;
- design-aware/bootstrap: RR estimate/interval may be unavailable or governed by bootstrap diagnostics.

Correct the bootstrap Markdown point-estimate sentence to `observed_sample_estimate` semantics.

Add regression assertions using the existing `html_iptw_part` fixture, at minimum:

```text
bootstrap-only HTML does not claim posterior median as its active point estimate
bootstrap-only HTML does not claim Jeffreys prior as its active model
bootstrap HTML labels observed-sample estimate + bootstrap percentile semantics
mixed semantics guide explicitly distinguishes both
```

After this content change, regenerate a fresh coherent visual QA run and update its manifest/screenshot/execution evidence.

## 5. Implementer evidence

Supplied evidence:

```text
tests/test_comparative_dashboard_qa.R : 146 / 146 PASS
tests/test_vcd_categorical_reporting.R: 35 / 35 PASS
tests/run_regression_suite.R          : 50 / 50 PASS
Python ownership + manifest           : 15 / 15 PASS
DOM/static interaction audit          : 11 / 11 PASS
OpenSpec strict validation            : valid / 0 issues
git diff --check                      : clean
Owner visual inspection               : PASS
```

These are treated as implementer/Owner evidence. No commit-bound CI/status is present.

## 6. Final gate

```text
M14.11-01: CLOSED
M14.14-01: CLOSED
H14.13-01: PARTIAL
H14.13-02: OPEN

Blocker 0
High    1
Medium  0

Tasks 14.11–14.14: HOLD
Section 16 final acceptance: HOLD
Section 17: GATED
```

Expected after 14.13.R2:

```text
Blocker 0
High    0
Medium  0

Tasks 14.11–14.14: PASS / ACCEPT
Section 16: PASS / ACCEPT
```