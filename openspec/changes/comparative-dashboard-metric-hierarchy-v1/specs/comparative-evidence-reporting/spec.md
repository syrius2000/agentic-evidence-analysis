## ADDED Requirements

### Requirement: Comparative Dashboard Metric Presentation Hierarchy

The system SHALL render the comparative evidence summary table (HTML dashboard and Markdown report) with exactly twelve presentation columns in the following canonical order, preserving the statistical separation of concepts on the presentation surface:

1. テーマ (`theme`)
2. 比較 (`target_arm`, `reference_arm`)
3. 記述N (T / R) (`target_total`, `reference_total`)
4. 記述イベント数 (T / R) (`target_events`, `reference_events`)
5. RD 推定値 [区間] (`rd_estimate`, interval bounds)
6. 100人あたり差 (E100) (`excess_per_100`)
7. NNT・NNH-like (`reciprocal_absolute_rd`, `reciprocal_status`, `reciprocal_direction`)
8. RR 推定値 [区間] (RR estimate and interval)
9. 方向支持指標 (`direction_support`)
10. 実務領域・U-Grade (`dominant_region`, `u_grade`)
11. 精度指標 (ESS / 区間幅) (ESS and `rd_interval_width`)
12. 診断バッジ (`badges`)

The previously combined column「100人あたり差 / NNT・NNH-like」SHALL be replaced by two independent columns (items 6 and 7). The Practical Region / U-Grade column SHALL be retained. Practical-region background color SHALL be applied only to the Practical Region / U-Grade cell and SHALL NOT propagate to RD, E100, NNT/NNH-like, RR, Direction Support, Precision, Diagnostics, or entire rows. HTML and Markdown SHALL use identical semantic column order, names, and reciprocal suppression rules. Display values for E100 and reciprocal RD SHALL be taken from canonical `summary_df` fields (`excess_per_100`, `reciprocal_absolute_rd`, `reciprocal_status`, `reciprocal_direction`) and SHALL NOT be recomputed from RD in client-side JavaScript.

Canonical contract separation SHALL be preserved:

- `comparative_evidence.json` / `comparative-evidence-v1` nested evidence contract SHALL remain unchanged.
- Canonical `summary_df` and dashboard CSV export SHALL remain exactly 40 canonical summary fields.
- No presentation-only field SHALL be added to either canonical contract.

Safety-domain reciprocal direction mapping SHALL be frozen as follows when `reciprocal_status = "STABLE_DIRECTION"` and `reciprocal_absolute_rd` is finite:

- `reciprocal_direction = "target_excess"` MUST render `NNH-like ≈ xx.x人`.
- `reciprocal_direction = "reference_excess"` MUST render `NNT-like ≈ xx.x人`.

For non-Safety domains under the same stable finite conditions, the NNT/NNH-like cell MUST render `1/|RD| ≈ xx.x人` and MUST NOT render `NNT-like` or `NNH-like`.

#### Scenario: Rendering the twelve-column HTML summary table

- **WHEN** a comparative evidence dashboard is generated from a standard Safety fixture
- **THEN** the HTML table header MUST contain exactly twelve columns in the canonical order above, every data row MUST contain exactly twelve cells, and the former combined「100人あたり差 / NNT・NNH-like」header MUST NOT appear

#### Scenario: Synchronizing Markdown report column order with HTML

- **WHEN** `comparative_report.md` is generated alongside the HTML dashboard
- **THEN** the Markdown summary table MUST present the same semantic metric order (RD → E100 → NNT/NNH-like → RR → Direction → U-Grade / Region → Precision → Diagnostics) and the same reciprocal suppression / labeling rules as the HTML table

#### Scenario: Separating E100 and reciprocal RD display cells

- **WHEN** a row has finite `excess_per_100` and `reciprocal_status = "STABLE_DIRECTION"` with a finite `reciprocal_absolute_rd`
- **THEN** the E100 cell MUST display the natural-unit translation derived only from `excess_per_100` (for example `+3.20 / 100人`), and the adjacent NNT/NNH-like cell MUST independently display the reciprocal label without combining both metrics into a single cell

#### Scenario: Rendering Safety NNH-like for target_excess

- **WHEN** domain is Safety, `reciprocal_status = "STABLE_DIRECTION"`, `reciprocal_direction = "target_excess"`, and `reciprocal_absolute_rd` is finite
- **THEN** the NNT/NNH-like cell MUST render `NNH-like ≈ xx.x人` and MUST NOT render `NNT-like`

#### Scenario: Rendering Safety NNT-like for reference_excess

- **WHEN** domain is Safety, `reciprocal_status = "STABLE_DIRECTION"`, `reciprocal_direction = "reference_excess"`, and `reciprocal_absolute_rd` is finite
- **THEN** the NNT/NNH-like cell MUST render `NNT-like ≈ xx.x人` and MUST NOT render `NNH-like`

#### Scenario: Rendering non-Safety generic reciprocal label

- **WHEN** domain is not Safety, `reciprocal_status = "STABLE_DIRECTION"`, and `reciprocal_absolute_rd` is finite
- **THEN** the NNT/NNH-like cell MUST render `1/|RD| ≈ xx.x人` and MUST NOT render `NNT-like` or `NNH-like`

#### Scenario: Suppressing directional reciprocal labels under uncertainty

- **WHEN** `reciprocal_status` is `SIGN_AMBIGUOUS`, `RD_NEAR_ZERO`, or `NOT_INTERPRETABLE`
- **THEN** the NNT/NNH-like cell MUST suppress direction-aware NNT/NNH-like labels, MUST NOT construct a naive contiguous reciprocal interval across zero, and MUST surface the suppression status (for example `— (SIGN_AMBIGUOUS)`)

#### Scenario: Retaining U-Grade under configured practical threshold

- **WHEN** `primary_delta` is configured as a positive practical threshold and U-Grades U0–U3 are present
- **THEN** the Practical Region / U-Grade column MUST remain in the twelve-column table, U-Grade values MUST continue to display with dominant region, practical-region hue MUST be confined to that cell, and U3 MUST remain muted/achromatic per existing contract

#### Scenario: Disabling practical-region highlighting when primary_delta is null

- **WHEN** `primary_delta` is null
- **THEN** U-Grade MUST be `NONE`, dominant region MUST be `none`, and practical-region color highlighting MUST be disabled (achromatic)

#### Scenario: Machine-readable sort keys without display-string reparsing

- **WHEN** a user sorts by the E100 column or the NNT/NNH-like column
- **THEN** the system MUST sort using explicit machine-readable `data-sort-value` keys derived from `excess_per_100` and a presentation-layer reciprocal sort key (finite stable reciprocal values sortable numerically; suppressed states treated as missing), MUST place finite values before missing/NA, and MUST NOT reparse displayed Japanese label strings to recover numeric sort order

#### Scenario: Preserving canonical export and geometry contracts

- **WHEN** CSV export or Gower / PCoA / HAC feature extraction runs after the presentation hierarchy change
- **THEN** dashboard CSV export MUST still serialize exactly the 40 canonical summary fields (excluding presentation-only keys), `comparative_evidence.json` nested evidence structure MUST remain unchanged, and `excess_per_100`, `reciprocal_absolute_rd`, `reciprocal_status`, and `reciprocal_direction` MUST NOT be added to Gower clustering feature keys

### Requirement: Risk Difference Guide Hierarchy for E100 and Reciprocal RD

The system SHALL structure the Risk Difference portion of the Metric Guide (`#metric-guide`) so that the following hierarchy is explicit and semantics-adaptive (Bayesian / Bootstrap / mixed):

1. RD is the primary absolute contrast estimand
2. E100 (`100 × RD`) is the preferred natural-unit translation of RD and does not replace the primary estimand
3. Reciprocal absolute RD (`1/|RD|`) is a secondary interpretation metric
4. NNT-like / NNH-like labels are direction-aware Safety-domain presentation labels only when `reciprocal_status = "STABLE_DIRECTION"`, with frozen mapping `target_excess → NNH-like` and `reference_excess → NNT-like`; non-Safety domains MUST use `1/|RD|` wording only
5. Reciprocal RD SHALL NOT be promoted to a primary estimand
6. Zero-crossing RD intervals SHALL suppress direction labels and SHALL NOT invent reciprocal intervals

The existing ten-accordion Metric Guide structure SHALL be retained. The U-Grade guide item SHALL remain and SHALL stay semantically aligned with the retained Practical Region / U-Grade table column.

#### Scenario: Expanding the Risk Difference guide accordion

- **WHEN** a user expands the Risk Difference guide item within `#metric-guide`
- **THEN** the guide MUST present RD, E100, and reciprocal RD as distinct hierarchical roles (primary contrast / natural-unit translation / secondary interpretation), MUST warn against causal NNT misinterpretation, MUST state the Safety direction mapping (`target_excess → NNH-like`, `reference_excess → NNT-like`), and MUST remain aligned with Markdown report wording for the active inferential semantics
