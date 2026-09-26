## 1. HTML Presentation Hierarchy

- [ ] 1.1 Update HTML table headers in `comparative_reporting.R` to the twelve-column canonical order (テーマ → … → 診断バッジ) and verify the combined header「100人あたり差 / NNT・NNH-like」no longer appears
- [ ] 1.2 Split `absolute_translation_html` into separate E100 and NNT/NNH-like cells sourced only from `summary_df$excess_per_100` / reciprocal fields, and verify each data row emits exactly twelve `<td>` cells
- [ ] 1.3 Add independent `e100_sort_val` and `reciprocal_sort_val` `data-sort-value` keys (finite-before-missing; no display-string reparsing) and verify keyboard click/Enter/Space sorting plus `aria-sort` still work
- [ ] 1.4 Keep Practical Region / U-Grade cell-local coloring (no row-wide hue; U3 muted) and verify overflow-x/compact typography still apply without dropping Precision or Diagnostics columns

## 2. Markdown and Metric Guide Sync

- [ ] 2.1 Update Markdown summary table headers/rows to the same semantic order and reciprocal labeling/suppression rules as HTML, and verify Q3-style header parity in generated `comparative_report.md`
- [ ] 2.2 Rewrite Risk Difference Metric Guide copy to hierarchy RD (primary) → E100 (natural unit) → reciprocal RD (secondary) with Safety-only NNT/NNH-like caution, and verify the ten-accordion `#metric-guide` structure remains intact
- [ ] 2.3 Confirm U-Grade guide item remains and stays aligned with the retained Practical Region / U-Grade column (including `primary_delta = null` → NONE / achromatic)

## 3. QA Matrix and Non-Regression

- [ ] 3.1 Extend `tests/test_comparative_dashboard_qa.R` for Q1–Q13 (column order, cell count, Markdown sync, Safety/non-Safety labels, suppression, E100/reciprocal provenance, U-Grade retention/color) and verify the new assertions fail before implementation then pass after
- [ ] 3.2 Add/extend assertions for Q14–Q19 (E100/reciprocal sort keys, keyboard/`aria-sort`, CSV 40-field export invariance, filtered export order, Zero-External-Asset scan) and verify they pass
- [ ] 3.3 Add/extend assertions for Q20–Q24 (RR zero-reference regression, Bayesian/Bootstrap/mixed guide semantics, Gower feature-key exclusion of E100/reciprocal fields) and verify they pass
- [ ] 3.4 Run `Rscript tests/test_comparative_dashboard_qa.R` (and any required related comparative dashboard regression entry points) and verify overall PASS with no schema or geometry module edits

## 4. Validation Gate

- [ ] 4.1 Run `openspec validate comparative-dashboard-metric-hierarchy-v1 --strict` and verify zero validation errors
- [ ] 4.2 Confirm `schemas/comparative-evidence-v1.json`, `comparative_contrasts.R`, `evidence_gower.R`, and `evidence_feature_extract.R` are unchanged by this change (git diff empty for those paths)
