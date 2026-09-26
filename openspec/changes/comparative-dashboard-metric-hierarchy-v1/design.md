## Context

See `proposal.md` for motivation. Current presentation in `comparative_reporting.R` builds one HTML/Markdown cell (`absolute_translation_html` / `absolute_translation_md`) that concatenates E100 and reciprocal RD, backed by a single `absolute_sort_val` from `excess_per_100`. Canonical fields already exist on `summary_df` / `comparative-evidence-v1`; this change is presentation-only. Geometry modules (`evidence_gower.R`, `evidence_feature_extract.R`) and JSON schema remain out of scope.

## Goals / Non-Goals

**Goals:**

- Split the combined absolute-translation cell into two independent columns with separate sort keys.
- Enforce the twelve-column canonical order in HTML and Markdown.
- Keep U-Grade / Practical Region, color locality, reciprocal suppression, CSV 40-field export, and Zero-External-Asset contracts intact.
- Align Metric Guide RD hierarchy with the new table reading order.

**Non-Goals:**

- New NNT estimand, causal NNT claims, reciprocal posterior median, zero-crossing reciprocal intervals.
- Schema version bump, CSV field add/remove, U-Grade threshold changes, RD/RR inference changes.
- Gower / PCoA / HAC redesign or feature-key expansion.

## Decisions

1. **Presentation-only split (no schema change)**
   Reuse `excess_per_100`, `reciprocal_absolute_rd`, `reciprocal_status`, `reciprocal_direction` from `summary_df`. Do not add presentation columns to JSON/CSV.
   *Alternative considered*: promote E100/reciprocal display strings into schema → rejected (violates “no new canonical field” contract).

2. **Two sort keys in the HTML renderer**
   Keep `e100_sort_val` from `excess_per_100`; add `reciprocal_sort_val` (numeric when `STABLE_DIRECTION` + finite; empty when suppressed). Continue finite-before-missing table sort policy; do not invent ordinal ranks for status labels.
   *Alternative considered*: keep one combined sort on E100 only → rejected (reciprocal column would not be independently sortable).

3. **Surgical edits in `comparative_reporting.R`**
   Update HTML header/row builders, Markdown table builder, and Risk Difference guide copy in one module. Leave contrast computation and shared geometry code untouched.
   *Alternative considered*: new template file → rejected as overkill for a column split.

4. **QA expansion in `tests/test_comparative_dashboard_qa.R`**
   Encode plan matrix Q1–Q24 as assertions (column order, cell count, Safety/non-Safety labels, suppression, provenance, U-Grade retention, sort/export/geometry non-regression).
   *Alternative considered*: manual visual QA only → rejected (fails Zero-Guesswork / reproducible acceptance).

5. **Width mitigation without dropping columns**
   Keep `overflow-x: auto` and compact typography on E100 / NNT columns rather than deleting Precision or Diagnostics.
   *Alternative considered*: drop precision/diagnostics to fit viewport → rejected (breaks concept hierarchy).

## Risks / Trade-offs

- [Wider table / more horizontal scroll] → Keep container overflow; compact E100/NNT cells; do not drop later columns.
- [NNT/NNH over-interpretation] → Keep canonical name `reciprocal_absolute_rd`; Safety-only `NNT-like`/`NNH-like`; non-Safety `1/|RD|`; Guide secondary-interpretation wording.
- [U-Grade unfamiliarity] → Retain column + Guide as practical-region resolution, not effect size / sample size / severity.
- [HTML/Markdown drift] → Shared label helpers or paired assertions in QA matrix Q3.

## Migration Plan

1. Spec delta lands with this change; no runtime migration.
2. Implement renderer + guide + tests on branch `codex/Gower-PCoA`.
3. Rollback = revert the three touchpoints (`comparative_reporting.R`, QA test, archived delta sync); no data migration because schema is unchanged.

## Open Questions

None — column order, suppression rules, and non-goals are fixed in `docs/Artifacts/implementation_plan_024_0927.md`.
