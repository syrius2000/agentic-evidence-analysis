# Section 14 — Blind-First Independent Re-QA Review 3

- **Repository:** `syrius2000/agentic-evidence-analysis`
- **Branch:** `feat/comparative-evidence-reporting-v3`
- **Baseline:** `0da9e264b7e18f2feb76add7f5f2b9a6598ee88e`
- **Reviewed commit:** `4456110bfa04934618f106c950c240d3cac7aca6`
- **Scope:** Section 14 Re-QA Review2 findings repair — 14.R3b / 14.R5 only
- **Previous review:** `docs/Artifacts/s14_dashboard_report_qa_review2_001_0926.md`
- **Implementation plan:** `docs/Artifacts/implementation_plan_018_0926.md`
- **Execution record:** `docs/Artifacts/s14_dashboard_report_exec_003_0926.md`
- **Review mode:** blind-first independent Re-QA
- **Review date:** 2026-09-26 JST
- **Reviewer:** GPT-5.6 Sol

## Decision

```text
Section 14:
HOLD

Blocker: 0
High:    0
Medium:  1
```

14.R5 is closed. 14.R3b is materially improved but not fully closed because the tracked exact browser artifact does not contain a U3 row, while the execution record claims U3 muted rendering was visually verified.

Do not start Section 15 until this final Medium is closed.

---

## 1. Commit / Scope Verification

The requested repair range is exactly one commit:

```text
0da9e264b7e18f2feb76add7f5f2b9a6598ee88e
    ↓
4456110bfa04934618f106c950c240d3cac7aca6
```

GitHub compare:

```text
status        = ahead
ahead_by      = 1
behind_by     = 0
total_commits = 1
merge_base    = 0da9e26...
```

No commit-bound GitHub status or workflow run is present for the reviewed SHA.

The changed implementation is limited to the requested repair plus tracked visual QA artifacts and supporting documentation/tests.

---

## 2. 14.R5 / M14-03 — CLOSED

The Markdown renderer now uses the same RR availability contract as the HTML renderer:

```r
rr_str_md <- if (is.na(row$rr_estimate)) {
  "N/A"
} else if (is.na(row$rr_interval_lower) || is.na(row$rr_interval_upper)) {
  sprintf("%.2f [N/A]", row$rr_estimate)
} else {
  sprintf("%.2f [%.2f, %.2f]", ...)
}
```

This closes the prior inconsistency where partial suppression produced:

```text
1.33 [NA, NA]
```

instead of:

```text
1.33 [N/A]
```

The revised tests explicitly verify:

```text
partial suppression -> Markdown contains 1.33 [N/A]
complete suppression -> Markdown contains N/A
Markdown contains no [NA, NA]
```

The code and tests satisfy the Review2 acceptance criteria.

**M14-03 / 14.R5: CLOSED.**

---

## 3. 14.R3b — Exact Artifact Tracking and Integrity Are Now Proven

The exact visual QA run is now tracked in the reviewed commit:

```text
evidence_runs/visual_qa_s14/run_20260926_035222/
```

including:

```text
dashboard.html
screenshot_1280x800.png
comparative_evidence.json
comparative_report.md
comparative_summary.csv
results_manifest.json
run_meta.json
```

### Independent hash verification

The reviewer independently recomputed SHA-256 from the tracked GitHub bytes.

```text
dashboard.html
computed: 1cc08d9fa5ff2446c5b185c4e02ec25e22fb037b63d9277a4f1e7be20c6b0533
claimed : 1cc08d9fa5ff2446c5b185c4e02ec25e22fb037b63d9277a4f1e7be20c6b0533
match   : TRUE

screenshot_1280x800.png
computed: 3dbba0f84d95fe14da26bba509e90f8096cad02b9b85c25ab3740b32ee37078c
claimed : 3dbba0f84d95fe14da26bba509e90f8096cad02b9b85c25ab3740b32ee37078c
match   : TRUE
```

The screenshot PNG IHDR independently reports:

```text
width  = 1280
height = 800
```

### Visual inspection

The tracked screenshot visibly confirms:

- dashboard title and guidance callout;
- numerical-instability warning;
- full comparison table;
- diagnostic badges in the dedicated Diagnostics column;
- practical-region colors restricted to Practical Difference cells;
- target-excess coral/red and reference-excess blue rendering;
- no obvious page-level horizontal overflow in the captured viewport.

The exact artifact tracking/integrity problem from Review2 is therefore closed.

---

## 4. Residual M14-01 — Exact Browser Artifact Does Not Contain U3

**Severity:** MEDIUM

The prior Review2 acceptance requirement for 14.R3b included visual confirmation of:

```text
U3 muted appearance
```

and the execution record claims:

```text
U3 -> rgba(148, 163, 184, 0.12) -> PASS
```

However the tracked exact `dashboard.html` does not contain a U3 row.

The row named:

```text
T4_U3_Uncertain
```

is actually rendered as:

```html
<td class='col-practical practical-u2 practical-practical-neutral'
    style='background-color: rgba(100, 116, 139, 0.08);'>
  <span class='ugrade'>U2</span>
  ...
</td>
```

The tracked `comparative_summary.csv` likewise records:

```text
T4_U3_Uncertain -> U2 / practical_neutral
```

and the screenshot visibly shows **U2**, not U3.

Therefore the exact browser artifact supports U0/U2 practical coloring, but it cannot support the execution-record claim that U3 muted rendering was visually verified.

This is a provenance/evidence gap rather than a renderer defect: the automated Section 14 test separately exercises the U3 style contract, but Task 14.9 / Review2 specifically requested browser evidence for U3 appearance.

### Required repair — 14.R3c

Generate one exact visual QA artifact containing a deterministic U3 row using the same fixture contract already used by the automated test.

For example:

```text
events T/R = 10/10
N T/R      = 100/100
primary_delta = 0.01
```

or another fixture proven to produce U3 in the current model.

Then:

1. render the exact artifact at 1280×800;
2. track `dashboard.html` and screenshot;
3. record and hash both;
4. confirm the U3 row has:
   ```text
   class includes practical-u3
   background = rgba(148, 163, 184, 0.12)
   ```
5. confirm the screenshot visibly contains the U3 row.

Do not label a fixture "U3" unless the generated evidence actually has `resolution_grade == U3`.

---

## 5. Layout Measurement Evidence

The execution record reports:

```text
window.innerWidth                    = 1280
document.documentElement.scrollWidth = 1265
horizontal_overflow                  = false
table_width                          = 1217
guidance_callout_visible             = true
numerical_instability_warning_visible= true
```

The tracked 1280×800 screenshot is visually consistent with those claims, and the repaired CSS contains the responsive `.table-container { overflow-x: auto; }` wrapper.

The reviewer independently verified artifact integrity and screenshot dimensions, but did not independently replay the same browser DOM-measurement script. These metrics therefore remain execution-record evidence rather than independently rerun measurements.

This does not create an additional finding.

---

## 6. Implementer Evidence — Consulted After Blind Review

Supplied execution evidence:

```text
test_comparative_dashboard_qa.R : 68 PASS / 0 FAIL
test_vcd_categorical_reporting.R: 35 PASS / 0 FAIL
OpenSpec validation               : valid
git diff --check                  : clean
```

These are treated as implementer execution evidence, not the basis of the independent decision.

No commit-bound CI/status evidence exists for the reviewed SHA.

---

## 7. Final Gate

Current:

```text
H14-01 / 14.R1: CLOSED
H14-02 / 14.R2: CLOSED
M14-02 / 14.R4: CLOSED
M14-03 / 14.R5: CLOSED

M14-01 / 14.R3b:
PARTIALLY CLOSED
  - exact artifact tracked: CLOSED
  - hashes independently verified: CLOSED
  - 1280x800 screenshot tracked: CLOSED
  - U3 browser visual evidence: OPEN

Blocker 0
High    0
Medium  1

Section 14:
HOLD
```

Expected after 14.R3c:

```text
Blocker 0
High    0
Medium  0

Section 14:
PASS / ACCEPT
```

**Section 15 should remain gated until the exact browser artifact includes and verifies a true U3 row.**
