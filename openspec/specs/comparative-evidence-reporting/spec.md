# comparative-evidence-reporting Specification

## Purpose

Define the specification for multi-theme, multi-group comparative evidence analysis and reporting. This capability calculates standardized risk contrasts (risk difference, excess per natural unit, relative risk), separates canonical point estimate sources (posterior median vs observed sample estimate), evaluates practical-region resolution grades (U0–U3) across active uncertainty distributions, preserves inferential semantics for region support and interval bounds, and delivers self-contained offline reports complying with canonical execution layout and zero-external-asset rules.

## Requirements

### Requirement: Independent Jeffreys Binary Inference and Prior Sensitivity Policy

The system SHALL evaluate independent two-group binary counts using primary objective Jeffreys prior $\text{Beta}(0.5, 0.5)$, producing exact Bayesian posterior draws for target and reference event probabilities from proper posteriors $\text{Beta}(x_g + 0.5, n_g - x_g + 0.5)$, while rejecting invalid empty denominators ($n_g = 0$), and providing a configurable prior sensitivity check against the uniform prior $\text{Beta}(1.0, 1.0)$ governed by `prior_sensitivity.mode = "zero_cell" | "off" | "explicit"` (defaulting to `"zero_cell"`) without modifying the primary U-grade.

#### Scenario: Sampling independent cohort posterior event probabilities

- **WHEN** valid integer counts $(x_T, n_T)$ and $(x_R, n_R)$ with $n_T > 0$ and $n_R > 0$ are provided
- **THEN** 独立した事後イベント確率をサンプリングし、ゼロイベント時には一様事前分布との感度比較を行い、RD 中央値差・方向支持差・U-grade の変化を記録し、`inferential_semantics = "posterior"` と `estimate.source = "posterior_median"` を設定する。未承認の閾値による二値 `robust` 判定は出力しない。

### Requirement: Contrast Derivations, Point Estimate Sources, and Ephemeral Draws

The system SHALL derive contrast metrics including Risk Difference ($RD$), Excess per natural unit ($E100 = 100 RD$), reciprocal absolute RD ($1/|RD|$) as a secondary NNT/NNH-like translation, Relative Risk ($RR$), and Direction Support from uncertainty draws, explicitly declaring the source of the primary point estimate (`estimate.source = "posterior_median"` for Bayesian models and `estimate.source = "observed_sample_estimate"` for bootstrap models), while managing raw draws as ephemeral in-memory objects by default (`persist_raw_draws = false`). The reciprocal metric SHALL be defined from the canonical RD point estimate rather than as a posterior/bootstrap summary of transformed draws.

#### Scenario: Deriving contrast metrics with explicit estimate source

- **WHEN** uncertainty draws for comparative groups are processed
- **THEN** the system MUST assign `estimate.value` based on `estimate.source` (posterior median for Bayes or observed sample estimate for bootstrap), compute nested interval bounds `interval: { lower, upper, level: 0.95, method: "posterior_eti" | "bootstrap_percentile" }`, compute `excess_per_100 = 100 * RD`, compute `reciprocal_absolute_rd = 1 / abs(RD)` when numerically defined, assign `reciprocal_status` and `reciprocal_direction`, persist summary metrics into `comparative_evidence.json`, and release raw Monte-Carlo draws from memory.

#### Scenario: Rendering reciprocal RD under directional uncertainty

- **WHEN** the RD uncertainty interval includes zero
- **THEN** the system MUST set `reciprocal_status = "SIGN_AMBIGUOUS"`, retain the finite reciprocal point value when numerically defined, suppress an NNT/NNH-like directional display, and SHALL NOT construct a naive contiguous reciprocal interval across zero.
- **AND WHEN** the canonical RD point estimate is numerically zero within machine-precision tolerance
- **THEN** the system MUST set `reciprocal_status = "RD_NEAR_ZERO"`, `reciprocal_absolute_rd = null`, and `reciprocal_direction = "none"`.

### Requirement: Zero-Cell Reference Safeguard for Relative Risk

The system SHALL detect cases where reference event counts are zero ($x_R = 0$) resulting in infinite theoretical expectation $E(RR) = \infty$, report the median and 95% quantile interval as valid statistics, explicitly set `mean = null` and `mean_is_finite = false`, and prohibit substituting the empirical sample mean.

#### Scenario: Evaluating relative risk with zero reference events

- **WHEN** reference group events $x_R = 0$ with $x_T > 0$
- **THEN** the system MUST evaluate $RR$ quantiles (median, 2.5%, 97.5%), set `mean = null`, set `mean_is_finite = false`, record diagnostic code `ZERO_REFERENCE`, and log continuous instability metric `log_rr_interval_width`.

### Requirement: Practical Difference and Resolution Across Active Uncertainty Distributions

The system SHALL evaluate practical-region support across canonical regions (`target_excess`, `practical_neutral`, `reference_excess`) under neutral container `practical_region_support`, rendering values as posterior probabilities for Bayesian models and as bootstrap support fractions for resampling models, compute Practical-Region Resolution Grade (U0–U3) from $C = \max(q_T, q_N, q_R)$ measuring resolution of the active uncertainty distribution, report separate continuous precision metrics (`rd_interval_width`, `log_rr_interval_width`, effective sample size), and disable region classifications when `primary_delta` is `null`.

#### Scenario: Evaluating region resolution with approved delta

- **WHEN** a positive practical threshold $\delta$ is approved
- **THEN** the system MUST evaluate support values $q_T, q_N, q_R$ summing to 1.0, assign resolution grade U0–U3 based on $C$, label support values according to `inferential_semantics`, and record that U-grade reflects active distribution resolution rather than generic sampling precision.

#### Scenario: Evaluating evidence profile with null delta

- **WHEN** `primary_delta` is configured as `null` (`mode: "none"`)
- **THEN** the system MUST compute directional support and the configurable delta profile matrix, set `practical_region_support = null`, set `resolution_grade = { grade: "NONE", dominant_region = "none", max_region_probability: null }`, and disable practical-region background color highlighting (achromatic cell presentation).

### Requirement: Self-Contained Sortable Comparative Evidence Summary Table

The system SHALL provide a fully self-contained client-side sortable comparative summary table, supporting ascending and descending sorts triggered by mouse click and keyboard navigation (`Enter` and `Space`), updating `aria-sort` attributes dynamically, utilizing explicit machine-readable sort values via `data-sort-value`, enforcing stable tie-breaking, sorting U-Grades ordinally (`U0 < U1 < U2 < U3 < NONE`), placing finite values before missing/NA values, and requiring zero external JavaScript libraries or CSS frameworks.

#### Scenario: Interacting with sortable table columns

- **WHEN** a user activates a table column header (via click, Enter, or Space)
- **THEN** the system MUST sort the visible rows based on the explicit `data-sort-value`, toggle sort direction between ascending and descending, update `aria-sort`, sort U-Grade values ordinally (`U0 < U1 < U2 < U3 < NONE`), preserve diagnostic badge layouts and practical region color coding, and operate without any external network assets.

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

- `comparative_evidence.json` SHALL continue to conform to `comparative-evidence-batch-v1`, whose `contrasts` entries SHALL continue to conform to `comparative-evidence-v1`.
- Canonical `summary_df` and dashboard CSV export SHALL remain exactly 40 canonical summary fields.
- No presentation-only field SHALL be added to any of these canonical contracts.

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
- **THEN** dashboard CSV export MUST still serialize exactly the 40 canonical summary fields (excluding presentation-only keys), `comparative_evidence.json` MUST remain a `comparative-evidence-batch-v1` document whose `contrasts` entries remain `comparative-evidence-v1`, and `excess_per_100`, `reciprocal_absolute_rd`, `reciprocal_status`, and `reciprocal_direction` MUST NOT be added to Gower clustering feature keys

### Requirement: Excel-Compatible Canonical Dashboard CSV Export

The system SHALL provide client-side CSV export functionality for both all comparative records (`#btn-export-all`) and currently filtered/sorted records (`#btn-export-filtered`), exporting exactly 40 canonical summary fields matching `summary_df` (strictly excluding internal presentation keys such as `row_key`), formatted with UTF-8 BOM (`\uFEFF`), CRLF line terminators, RFC 4180 compliant quoting, and deterministic ordering reflecting the current table view without performing client-side statistical recomputations.

#### Scenario: Exporting filtered and sorted dashboard data to CSV

- **WHEN** a user triggers the filtered CSV export button after applying filters and sorting
- **THEN** the system MUST generate and download a CSV containing the active filtered records in their displayed sort order, serialize all 40 canonical fields, prepend UTF-8 BOM (`\uFEFF`), terminate lines with CRLF, quote strings containing commas or quotes per RFC 4180, and exclude internal presentation keys.

### Requirement: Accessible Multi-Select Dashboard Filtering

The system SHALL provide an accessible client-side multi-select filtering interface allowing independent filtering by Theme, Practical Region/U-Grade, and Diagnostic Badges, evaluating filters with OR-within-attribute and AND-across-attributes semantics, updating visible row count via an `aria-live="polite"` counter, providing a dedicated reset control (`#btn-reset-filters`), escaping Japanese and hostile string literals safely, and composing deterministically with active column sorting.

#### Scenario: Filtering comparative evidence by multiple criteria

- **WHEN** a user selects filter values across Theme, Practical Region/U-Grade, or Diagnostic Badges
- **THEN** the system MUST display rows matching at least one selected value within each active filter group (OR) and satisfying all active filter groups simultaneously (AND), update the live row counter (`aria-live="polite"`), preserve active sort ordering across visible rows, and reset all filters to show all rows upon activating the reset control.

### Requirement: Inferential-Semantics-Adaptive Mathematical and Usage Guide

The system SHALL provide a self-contained mathematical and interpretation guide rendered within `<section id="metric-guide">`, containing 10 independent native `<details class="guide-accordion">` / `<summary>` items (each default collapsed). Each item SHALL contain the guidance subsections: Definition, Interpretation, Cautions & Invariants, and When to Use. Formula-bearing metric items SHALL render mathematical notation via native MathML (`<math display="block">`). The guide SHALL dynamically adapt formula presentations and textual interpretations across Bayesian posterior (`posterior_median`, `posterior_eti`), Bootstrap resampling (`observed_sample_estimate`, `bootstrap_percentile`), and mixed inferential semantics, while maintaining complete semantic alignment with Markdown summary reports.

#### Scenario: Displaying mathematical definitions matching analysis semantics

- **WHEN** a user expands any of the 10 independent guide accordion items within `#metric-guide`
- **THEN** the system MUST display the structured subsections (Definition, Interpretation, Cautions & Invariants, When to Use), render native MathML formulas for formula-bearing metric items adaptively matching the dataset's `inferential_semantics` (Bayesian posterior, Bootstrap resampling, or mixed) without referencing external stylesheet/script CDNs, and maintain definitions identical to corresponding Markdown report documentation.

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

### Requirement: Domain Adapters, Safety Invariants, and Pooled Descriptive Summaries

The system SHALL support domain adapters for Clinical Safety (MedDRA), Real-World Data (RWD), and Prescription data, enforcing subject deduplication within PT and SOC, labeling subject-incidence excess as `additional_subjects_per_100_treated`, designating multi-study safety pooling as `descriptive_pooled` without asserting unmodeled between-study homogeneity, and ensuring identical counts yield invariant statistical statistics across domains.

#### Scenario: Aggregating Adverse Events across SOC and PT hierarchy

- **WHEN** clinical adverse event records with MedDRA hierarchy are processed
- **THEN** the system MUST aggregate events at the primary SOC and PT levels, deduplicate subjects experiencing multiple PTs within a single SOC, assert that SOC subject count is less than or equal to denominator, render excess as additional subjects per 100 treated, and designate pooled cross-study tables as descriptive.

### Requirement: Multiplicity Disclaimers and Presentation Safeguards

The system SHALL enforce narrative and visual safeguards, prohibiting claims that "non-significance implies equivalence" or that "posterior direction implies causal superiority", providing an explicit exploratory multiplicity disclaimer when batch screening multiple terms, using "credible interval (ETI)" for Bayesian models and "bootstrap percentile interval" for bootstrap models, and restricting reciprocal-RD (NNT/NNH-like) rendering when directional uncertainty exists. Reciprocal RD SHALL remain a secondary interpretation metric and SHALL NOT be promoted to the primary estimand.

#### Scenario: Rendering batch report narrative with correct interval terminology

- **WHEN** comparative evidence reports are compiled for multiple screening terms
- **THEN** the report narrative MUST include the exploratory screening disclaimer, use semantics-aware interval terminology (credible interval vs bootstrap percentile interval), and SHALL NOT assign cell background hue based on posterior direction alone.
