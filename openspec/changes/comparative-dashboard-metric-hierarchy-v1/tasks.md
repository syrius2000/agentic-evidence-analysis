## 1. HTML Presentation Hierarchy

- [ ] 1.1 Update HTML table headers in `comparative_reporting.R` to the twelve-column canonical order (テーマ → … → 診断バッジ) and verify the combined header「100人あたり差 / NNT・NNH-like」no longer appears
- [ ] 1.2 Split `absolute_translation_html` into separate E100 and NNT/NNH-like cells sourced only from `summary_df$excess_per_100` / reciprocal fields, and verify each data row emits exactly twelve `<td>` cells
- [ ] 1.3 Add independent `e100_sort_val` and `reciprocal_sort_val` `data-sort-value` keys (finite-before-missing; no display-string reparsing) and verify keyboard click/Enter/Space sorting plus `aria-sort` still work
- [ ] 1.4 Keep Practical Region / U-Grade cell-local coloring (no row-wide hue; U3 muted) and verify overflow-x/compact typography still apply without dropping Precision or Diagnostics columns

## 2. Markdown and Metric Guide Sync

- [ ] 2.1 Update Markdown summary table headers/rows to the same semantic order and reciprocal labeling/suppression rules as HTML, and verify Q3-style header parity in generated `comparative_report.md`
- [ ] 2.2 Rewrite Risk Difference Metric Guide copy to hierarchy RD (primary) → E100 (natural unit) → reciprocal RD (secondary) with Safety mapping `target_excess → NNH-like` / `reference_excess → NNT-like`, and verify the ten-accordion `#metric-guide` structure remains intact
- [ ] 2.3 Confirm U-Grade guide item remains and stays aligned with the retained Practical Region / U-Grade column (including `primary_delta = null` → NONE / none / achromatic)

## 3. QA Matrix and Non-Regression

- [ ] 3.1 Extend `tests/test_comparative_dashboard_qa.R` for Q1–Q13 and verify assertions fail before implementation then pass after, with explicit expected results:
      - Q4: Safety + stable + `target_excess` → `NNH-like ≈ ...人` (not NNT-like)
      - Q5: Safety + stable + `reference_excess` → `NNT-like ≈ ...人` (not NNH-like)
      - Q6: zero-crossing interval → `SIGN_AMBIGUOUS` and directional label suppression
      - Q7: RD near zero → reciprocal null / `RD_NEAR_ZERO`
      - Q8: non-Safety stable finite → `1/|RD| ≈ ...人` only (no NNT/NNH wording)
      - Q11–Q13: U-Grade retention; U3 muted; `primary_delta = null` → NONE / none / no practical-region hue
- [ ] 3.2 Add/extend assertions for Q14–Q19 and verify they pass, with explicit expected results:
      - Q14: E100 sort uses `excess_per_100` machine key (no display-string reparsing)
      - Q15: reciprocal sort → stable finite values numeric; suppressed states treated as missing (finite-before-missing)
      - Q16–Q19: keyboard/`aria-sort` retained; CSV remains exactly 40 canonical summary fields; filtered export order matches view; Zero-External-Asset scan clean
- [ ] 3.3 Add/extend assertions for Q20–Q24 and verify they pass, with explicit expected results:
      - Q20: RR zero-reference instability warning remains while RD/E100 stay usable
      - Q21–Q23: Bayesian / Bootstrap / mixed guide semantics retained
      - Q24: E100 / reciprocal fields excluded from Gower clustering feature keys
- [ ] 3.4 Run `Rscript tests/test_comparative_dashboard_qa.R` (and any required related comparative dashboard regression entry points) and verify overall PASS with no schema or geometry module edits

## 3.R Planning QA Repair (Cycle 1 → Cycle 2)

- [x] 3.R1 Freeze Safety reciprocal label mapping in delta spec: `target_excess → NNH-like`, `reference_excess → NNT-like`; non-Safety stable reciprocal → `1/|RD|` only. Verify Q4, Q5, and Q8 are directly derivable from the spec.
- [x] 3.R2 Separate evidence JSON contract from summary/export contract: `comparative_evidence.json` remains `comparative-evidence-batch-v1` with nested `comparative-evidence-v1` contrasts; `summary_df`/dashboard CSV remain exactly 40 canonical fields; no presentation-only canonical fields are added.
- [x] 3.R3 Split Practical Region / U-Grade scenarios: positive `primary_delta` → U0–U3 + dominant region + cell-local hue; `primary_delta = null` → NONE / none / no practical-region hue. Verify Q11–Q13 independently.
- [x] 3.R4 Make high-risk QA expectations explicit in tasks: Q4/Q5 direction mapping, Q6/Q7 suppression, Q8 non-Safety, Q15 reciprocal numeric/missing sort, Q20 RR-instability with RD/E100 retained.
- [x] 3.R5 Run `openspec validate comparative-dashboard-metric-hierarchy-v1 --strict` and `git diff --check`; record zero OpenSpec validation errors plus clean diff.

## 4. Validation Gate

- [ ] 4.1 Re-run `openspec validate comparative-dashboard-metric-hierarchy-v1 --strict` after implementation edits and verify zero validation errors
- [ ] 4.2 Confirm `schemas/comparative-evidence-batch-v1.json`, `schemas/comparative-evidence-v1.json`, `comparative_contrasts.R`, `evidence_gower.R`, and `evidence_feature_extract.R` are unchanged by this change (git diff empty for those paths)
