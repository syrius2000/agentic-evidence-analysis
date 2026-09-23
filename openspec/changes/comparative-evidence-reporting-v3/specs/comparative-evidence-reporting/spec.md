## Purpose

Define the specification for multi-theme, multi-group comparative evidence analysis and reporting. This capability calculates standardized risk contrasts (risk difference, excess per natural unit, relative risk), evaluates practical-difference profiles and practical-region resolution grades (U0–U3), separates continuous precision metrics, and delivers self-contained offline reports complying with canonical execution layout and zero-external-asset rules.

## ADDED Requirements

### Requirement: Independent Jeffreys Beta-Binomial Inference

The system SHALL evaluate independent two-group binary counts using objective Jeffreys prior $\text{Beta}(0.5, 0.5)$, producing exact Bayesian posterior draws for target and reference event probabilities from proper posteriors $\text{Beta}(x_g + 0.5, n_g - x_g + 0.5)$, while rejecting invalid empty denominators ($n_g = 0$).

#### Scenario: Sampling independent cohort posterior event probabilities
- **WHEN** valid integer counts $(x_T, n_T)$ and $(x_R, n_R)$ with $n_T > 0$ and $n_R > 0$ are provided
- **THEN** the system MUST sample independent posterior event probabilities, compute joint draw distributions, and set `inferential_semantics = "posterior"`.

### Requirement: Contrast Derivations and Ephemeral Draw Management

The system SHALL derive contrast metrics including Risk Difference ($RD$), Excess Events per natural unit (per 100 and per 1000), Relative Risk ($RR$), and Direction Support from uncertainty draws, managing raw draws as ephemeral memory objects by default (`persist_raw_draws = false`) to ensure scalability across thousands of analysis terms.

#### Scenario: Computing summary contrast metrics without raw draw bloat
- **WHEN** uncertainty draws for comparative groups are processed
- **THEN** the system MUST calculate median, mean (when finite), and 95% equal-tailed credible intervals (ETI) for contrasts, persist the statistical summaries into `comparative_evidence.json`, and release raw Monte-Carlo draws from memory unless explicit raw persistence is requested.

### Requirement: Zero-Cell Reference Safeguard for Relative Risk

The system SHALL detect cases where reference event counts are zero ($x_R = 0$) resulting in infinite theoretical expectation $E(RR) = \infty$, report the median and 95% ETI as valid quantile statistics, explicitly set `mean = null` and `mean_is_finite = false`, and prohibit substituting the empirical sample mean.

#### Scenario: Evaluating relative risk with zero reference events
- **WHEN** reference group events $x_R = 0$ with $x_T > 0$
- **THEN** the system MUST evaluate $RR$ quantiles (median, 2.5%, 97.5%), set `mean = null`, set `mean_is_finite = false`, record diagnostic code `ZERO_REFERENCE`, and log continuous instability metric `log_rr_eti_width`.

### Requirement: Practical Difference and Practical-Region Resolution Grade (U0–U3)

The system SHALL evaluate practical-difference probabilities across canonical regions (`TARGET_EXCESS`, `PRACTICAL_NEUTRAL`, `REFERENCE_EXCESS`) when an approved $\delta > 0$ exists, compute the Practical-Region Resolution Grade (U0–U3) from $C = \max(q_T, q_N, q_R)$, report separate continuous precision metrics (`rd_eti_width`, `log_rr_eti_width`, effective sample size), and disable region classifications when $\delta$ is `null`.

#### Scenario: Evaluating region resolution with approved delta
- **WHEN** a positive practical threshold $\delta$ is approved
- **THEN** the system MUST compute $q_T = P(RD > \delta)$, $q_N = P(|RD| \le \delta)$, and $q_R = P(RD < -\delta)$, assign resolution grade U0–U3 based on $C$, and record that U-grade reflects region classification decisiveness rather than generic sampling precision.

#### Scenario: Evaluating evidence profile with null delta
- **WHEN** `primary_delta` is configured as `null` (`mode: "none"`)
- **THEN** the system MUST compute directional support $P(RD > 0)$ and the configurable delta profile matrix, while setting practical region probabilities and U-grade to `null` and disabling background color highlighting.

### Requirement: Domain Adapters, Safety Invariants, and Pooled Descriptive Summaries

The system SHALL support domain adapters for Clinical Safety (MedDRA), Real-World Data (RWD), and Prescription data, enforcing subject deduplication within PT and SOC, designating multi-study safety pooling as `descriptive_pooled` without asserting unmodeled between-study homogeneity, and ensuring identical counts yield invariant statistical statistics across domains.

#### Scenario: Aggregating Adverse Events across SOC and PT hierarchy
- **WHEN** clinical adverse event records with MedDRA hierarchy are processed
- **THEN** the system MUST aggregate events at the primary SOC and PT levels, deduplicate subjects experiencing multiple PTs within a single SOC, assert that SOC subject count is less than or equal to denominator, and designate pooled cross-study tables as descriptive.

### Requirement: Multiplicity Disclaimers and Presentation Safeguards

The system SHALL enforce narrative and visual safeguards, prohibiting claims that "non-significance implies equivalence" or that "posterior direction implies causal superiority", providing an explicit exploratory multiplicity disclaimer when batch screening multiple terms, and restricting reciprocal-RD (NNH) rendering when directional uncertainty exists.

#### Scenario: Rendering batch report narrative
- **WHEN** comparative evidence reports are compiled for multiple screening terms
- **THEN** the report narrative MUST include a disclaimer that ranking and posterior direction probabilities are exploratory prioritization aids that do not guarantee familywise error rate control, and SHALL NOT assign cell background hue based on posterior direction alone.
