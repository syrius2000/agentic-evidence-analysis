## Purpose

Define the specification for multi-theme, multi-group comparative evidence analysis and reporting. This capability calculates standardized risk contrasts (risk difference, excess per natural unit, relative risk), evaluates practical-difference profiles and practical-region resolution grades (U0–U3), separates continuous precision metrics, maintains strict semantic distinction between Bayesian credible intervals (ETI) and bootstrap percentile intervals, and delivers self-contained offline reports complying with canonical execution layout and zero-external-asset rules.

## ADDED Requirements

### Requirement: Independent Jeffreys Beta-Binomial Inference with Prior Sensitivity

The system SHALL evaluate independent two-group binary counts using primary objective Jeffreys prior $\text{Beta}(0.5, 0.5)$, producing exact Bayesian posterior draws for target and reference event probabilities from proper posteriors $\text{Beta}(x_g + 0.5, n_g - x_g + 0.5)$, while rejecting invalid empty denominators ($n_g = 0$), and providing an optional sensitivity check against the uniform Laplace prior $\text{Beta}(1.0, 1.0)$ for sparse or zero-event comparisons without altering the primary U-grade.

#### Scenario: Sampling independent cohort posterior event probabilities

- **WHEN** valid integer counts $(x_T, n_T)$ and $(x_R, n_R)$ with $n_T > 0$ and $n_R > 0$ are provided
- **THEN** the system MUST sample independent posterior event probabilities, compute joint draw distributions, record sensitivity contrast shifts under $\text{Beta}(1.0, 1.0)$ for sparse events, and set `inferential_semantics = "posterior"`.

### Requirement: Contrast Derivations, Interval Semantics, and Ephemeral Draw Management

The system SHALL derive contrast metrics including Risk Difference ($RD$), Excess per natural unit, Relative Risk ($RR$), and Direction Support from uncertainty draws, formatting uncertainty intervals strictly according to inferential semantics (`method = "posterior_eti"` for Bayesian models and `method = "bootstrap_percentile"` for resampling models), while managing raw draws as ephemeral in-memory objects by default (`persist_raw_draws = false`).

#### Scenario: Computing summary contrast metrics with semantics-aware intervals

- **WHEN** uncertainty draws for comparative groups are processed
- **THEN** the system MUST calculate median, mean (when finite), and 95% quantile intervals, persisting `method: "posterior_eti"` for posterior draws or `method: "bootstrap_percentile"` for bootstrap replicates into `comparative_evidence.json`, and release raw Monte-Carlo draws from memory.

### Requirement: Zero-Cell Reference Safeguard for Relative Risk

The system SHALL detect cases where reference event counts are zero ($x_R = 0$) resulting in infinite theoretical expectation $E(RR) = \infty$, report the median and 95% quantile interval as valid statistics, explicitly set `mean = null` and `mean_is_finite = false`, and prohibit substituting the empirical sample mean.

#### Scenario: Evaluating relative risk with zero reference events

- **WHEN** reference group events $x_R = 0$ with $x_T > 0$
- **THEN** the system MUST evaluate $RR$ quantiles (median, 2.5%, 97.5%), set `mean = null`, set `mean_is_finite = false`, record diagnostic code `ZERO_REFERENCE`, and log continuous instability metric `log_rr_eti_width`.

### Requirement: Practical Difference and Practical-Region Resolution Grade (U0–U3)

The system SHALL evaluate practical-difference probabilities across canonical regions (`TARGET_EXCESS`, `PRACTICAL_NEUTRAL`, `REFERENCE_EXCESS`) when an approved $\delta > 0$ exists, compute the Practical-Region Resolution Grade (U0–U3) from $C = \max(q_T, q_N, q_R)$, report separate continuous precision metrics (`rd_interval_width`, `log_rr_interval_width`, effective sample size), and disable region classifications when $\delta$ is `null`.

#### Scenario: Evaluating region resolution with approved delta

- **WHEN** a positive practical threshold $\delta$ is approved
- **THEN** the system MUST compute $q_T = P(RD > \delta)$, $q_N = P(|RD| \le \delta)$, and $q_R = P(RD < -\delta)$, assign resolution grade U0–U3 based on $C$, and record that U-grade reflects region classification decisiveness rather than generic sampling precision.

#### Scenario: Evaluating evidence profile with null delta

- **WHEN** `primary_delta` is configured as `null` (`mode: "none"`)
- **THEN** the system MUST compute directional support and the configurable delta profile matrix, while setting practical region probabilities and U-grade to `null` and disabling background color highlighting.

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
