# Section 14 — Blind-First Independent Re-QA Review 2

- Repository: `syrius2000/agentic-evidence-analysis`
- Branch: `feat/comparative-evidence-reporting-v3`
- Baseline: `b45308bdc2e044d855139127cd3d8e1b65cf2f0a`
- Reviewed commit: `063b1cd8973eabf74043cb5fd65e33631c788f51`
- Scope: Section 14 QA findings repair (14.R1–14.R4)
- Previous review: `docs/Artifacts/s14_dashboard_report_qa_review1_001_0926.md`
- Implementation plan: `docs/Artifacts/implementation_plan_017_0926.md`
- Execution record: `docs/Artifacts/s14_dashboard_report_exec_002_0926.md`
- Review mode: blind-first independent Re-QA
- Review date: 2026-09-26 JST
- Reviewer: GPT-5.6 Sol

## Decision

```text
Section 14:
HOLD

Blocker: 0
High:    0
Medium:  2
```

Prior High findings H14-01 and H14-02 are closed. Prior M14-02 is closed. Prior M14-01 remains open because Task 14.9 still lacks an actual browser/manual render of the exact generated artifact. One new Medium remains in the Markdown suppressed-RR presentation path.

Do not start Section 15 until both Medium findings are closed.

## 1. Commit / Scope Verification

The requested range is exactly one commit:

```text
b45308bdc2e044d855139127cd3d8e1b65cf2f0a
    ↓
063b1cd8973eabf74043cb5fd65e33631c788f51
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = b45308b...
```

No commit-bound GitHub status or workflow run is present for the reviewed commit.

## 2. Prior Finding Closure

### H14-01 — CLOSED

The renderer now normalizes nullable RR estimate / interval values before arithmetic and conditional evaluation. `relative_risk$interval = NULL` maps to `rr_interval_available = FALSE` and `NA_real_` bounds rather than zero-length values.

Governed suppression is preserved: null `log_rr_interval_width` / `rr_interval_fold_range` are not recomputed unless an actual RR interval is available.

New IPTW override tests cover both partial-undefined bootstrap RR and complete zero-reference suppression. The HTML path renders unavailable RR intervals as `1.33 [N/A]` or `N/A`, keeps RD visible, and triggers `#numerical-instability-warning`.

**14.R1 / H14-01: CLOSED.**

### H14-02 — CLOSED

A common `html_escape()` boundary now escapes `&`, `<`, `>`, double quote, and single quote. Theme, arm labels, support label, U-grade/region display text, and diagnostic badge text are escaped before HTML insertion.

Enum-derived CSS classes are allowlisted rather than built from arbitrary input text.

Hostile-label tests verify that raw `<img>` / `<script>` tags are absent, escaped visible text remains, and the active external-resource scanner detects no active external media/style dependency.

**14.R2 / H14-02: CLOSED.**

### M14-02 — CLOSED

Bootstrap provenance extraction now reads the actual producer structures:

- `relative_risk.rr_bootstrap_diagnostics.defined_replicates / undefined_replicates`
- `iptw.bootstrap_diagnostics.defined_rr_replicates / undefined_rr_replicates`

The IPTW repair fixture asserts concrete summary values `950L / 50L`, not merely column existence.

**14.R4 / M14-02: CLOSED.**

## 3. M14-01 — Task 14.9 Browser Visual Verification Still Not Completed

**Severity: MEDIUM**

The prior review required an actual render of the exact generated artifact at 1280×800 using browser subagent, localhost Chromium, page-content browser automation, or documented manual rendering.

The repair execution record still reports that `browser_subagent` failed because of Playwright/ARM64 constraints, and then concludes layout correctness from DOM/CSS rules.

That remains static inspection rather than browser/manual rendering.

The repaired CSS now correctly includes:

```css
.table-container { width: 100%; overflow-x: auto; margin-top: 16px; }
```

so the prior code/documentation mismatch is fixed. However the required visual evidence remains absent.

The claimed exact artifact:

```text
evidence_runs/visual_qa_s14/run_20260926_034007/dashboard.html
SHA-256 1cc08d9fa5ff2446c5b185c4e02ec25e22fb037b63d9277a4f1e7be20c6b0533
```

is not present in the reviewed commit, so the independent reviewer cannot render or hash-check that exact artifact from GitHub.

### Required repair — 14.R3b

Perform one real browser/manual render of the exact generated HTML and record:

```text
artifact path + SHA-256
render method
viewport = 1280x800
window.innerWidth
document.documentElement.scrollWidth
table/container bounding width
warning callout visibility
badge placement
U3 muted appearance
practical-cell-only hue
```

A static DOM/CSS source review is not sufficient for Task 14.9.

## 4. M14-03 — Suppressed RR Markdown Still Renders `[NA, NA]`

**Severity: MEDIUM**

The 14.R1 null-safety repair fixes the HTML path, but `comparative_report.md` still uses:

```r
rr_str <- if (is.na(row$rr_estimate))
  "N/A"
else
  sprintf("%.2f [%.2f, %.2f]",
          row$rr_estimate,
          row$rr_interval_lower,
          row$rr_interval_upper)
```

For the intended partial-undefined bootstrap fixture, the point estimate is available while the interval is suppressed. The Markdown therefore becomes:

```text
1.33 [NA, NA]
```

while the HTML correctly renders:

```text
1.33 [N/A]
```

The prior QA acceptance criterion explicitly required the suppressed RR interval to render as unavailable rather than `[NA, NA]`. Section 14 is a dashboard/report QA section, so this inconsistent report output remains in scope.

### Required repair — 14.R5

Use the same availability contract for Markdown and HTML:

```r
rr_str_md <- if (is.na(row$rr_estimate)) {
  "N/A"
} else if (is.na(row$rr_interval_lower) || is.na(row$rr_interval_upper)) {
  sprintf("%.2f [N/A]", row$rr_estimate)
} else {
  sprintf("%.2f [%.2f, %.2f]", ...)
}
```

Add tests for both:

```text
partial suppression -> Markdown contains 1.33 [N/A]
complete suppression -> Markdown contains N/A
Markdown does not contain [NA, NA]
```

## 5. Test Adequacy

The previous vacuous U3 assertion was removed. The revised test now requires the synthetic fixture to actually produce U3 and fails otherwise. This closes the prior test-adequacy note.

The hostile-label tests and IPTW provenance-value assertions are materially stronger than Review1.

## 6. Implementer Evidence

Supplied / execution-record evidence:

```text
test_comparative_dashboard_qa.R : 65 PASS / 0 FAIL
test_vcd_categorical_reporting.R: 35 PASS / 0 FAIL
OpenSpec validation               : valid
git diff --check                  : clean
```

The execution record additionally reports a regression-suite environment limitation (48/50 in sandbox, with two pandoc-dependent tests claimed passing outside the sandbox). These remain implementer execution claims and are not used as the basis of acceptance.

No commit-bound GitHub CI/status evidence exists for the reviewed SHA.

## 7. Final Gate

Current:

```text
14.R1: CLOSED
14.R2: CLOSED
14.R3: PARTIALLY CLOSED
14.R4: CLOSED

M14-03: OPEN

Blocker 0
High    0
Medium  2

Section 14:
HOLD
```

Expected after 14.R3b + 14.R5:

```text
Blocker 0
High    0
Medium  0

Section 14:
PASS / ACCEPT
```

**Section 15 should remain gated until both remaining Medium items are independently closed.**