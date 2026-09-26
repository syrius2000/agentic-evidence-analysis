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

The system SHALL derive contrast metrics including Risk Difference ($RD$), Excess per natural unit, Relative Risk ($RR$), and Direction Support from uncertainty draws, explicitly declaring the source of the primary point estimate (`estimate.source = "posterior_median"` for Bayesian models and `estimate.source = "observed_sample_estimate"` for bootstrap models), while managing raw draws as ephemeral in-memory objects by default (`persist_raw_draws = false`).

#### Scenario: Deriving contrast metrics with explicit estimate source

- **WHEN** uncertainty draws for comparative groups are processed
- **THEN** the system MUST assign `estimate.value` based on `estimate.source` (posterior median for Bayes or observed sample estimate for bootstrap), compute nested interval bounds `interval: { lower, upper, level: 0.95, method: "posterior_eti" | "bootstrap_percentile" }`, persist summary metrics into `comparative_evidence.json`, and release raw Monte-Carlo draws from memory.

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

### Requirement: Excel-Compatible Canonical Dashboard CSV Export

The system SHALL provide client-side CSV export functionality for both all comparative records (`#btn-export-all`) and currently filtered/sorted records (`#btn-export-filtered`), exporting exactly 36 canonical summary fields matching `summary_df` (strictly excluding internal presentation keys such as `row_key`), formatted with UTF-8 BOM (`\uFEFF`), CRLF line terminators, RFC 4180 compliant quoting, and deterministic ordering reflecting the current table view without performing client-side statistical recomputations.

#### Scenario: Exporting filtered and sorted dashboard data to CSV

- **WHEN** a user triggers the filtered CSV export button after applying filters and sorting
- **THEN** the system MUST generate and download a CSV containing the active filtered records in their displayed sort order, serialize all 36 canonical fields, prepend UTF-8 BOM (`\uFEFF`), terminate lines with CRLF, quote strings containing commas or quotes per RFC 4180, and exclude internal presentation keys.

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

### Requirement: Domain Adapters, Safety Invariants, and Pooled Descriptive Summaries

The system SHALL support domain adapters for Clinical Safety (MedDRA), Real-World Data (RWD), and Prescription data, enforcing subject deduplication within PT and SOC, labeling subject-incidence excess as `additional_subjects_per_100_treated`, designating multi-study safety pooling as `descriptive_pooled` without asserting unmodeled between-study homogeneity, and ensuring identical counts yield invariant statistical statistics across domains.

#### Scenario: Aggregating Adverse Events across SOC and PT hierarchy

- **WHEN** clinical adverse event records with MedDRA hierarchy are processed
- **THEN** the system MUST aggregate events at the primary SOC and PT levels, deduplicate subjects experiencing multiple PTs within a single SOC, assert that SOC subject count is less than or equal to denominator, render excess as additional subjects per 100 treated, and designate pooled cross-study tables as descriptive.

### Requirement: Multiplicity Disclaimers and Presentation Safeguards

The system SHALL enforce narrative and visual safeguards, prohibiting claims that "non-significance implies equivalence" or that "posterior direction implies causal superiority", providing an explicit exploratory multiplicity disclaimer when batch screening multiple terms, using "credible interval (ETI)" for Bayesian models and "bootstrap percentile interval" for bootstrap models, and restricting reciprocal-RD (NNH) rendering when directional uncertainty exists.

#### Scenario: Rendering batch report narrative with correct interval terminology

- **WHEN** comparative evidence reports are compiled for multiple screening terms
- **THEN** the report narrative MUST include the exploratory screening disclaimer, use semantics-aware interval terminology (credible interval vs bootstrap percentile interval), and SHALL NOT assign cell background hue based on posterior direction alone.
