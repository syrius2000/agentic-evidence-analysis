## Purpose

Define the specification for design-aware comparative statistical inference across complex observational and real-world designs, including 1:1 matched pairs, 1:k matched sets, inverse probability of treatment weighting (IPTW), and person-time incidence rates. This engine produces standardized posterior draws conforming to `comparative-draws-v1` to decouple design-specific probability models from downstream reporting.

## ADDED Requirements

### Requirement: Design-Specific Inference Engine Interface

The system SHALL provide a design-aware inference engine that accepts design metadata and input data, validates design-specific structural preconditions, and generates standardized MCMC/posterior simulation draws matching the `comparative-draws-v1` schema.

#### Scenario: Validating design configuration and invoking design engine

- **WHEN** an analysis configuration specifying a design type (such as `matched_1to1`, `matched_1tok`, `iptw`, or `person_time`) is provided along with appropriate data
- **THEN** the system MUST route execution to the corresponding design-specific sampler and produce a standardized draws object containing posterior parameter vectors and sample metadata.

### Requirement: 1:1 Matched-Pair Analysis via Multinomial Dirichlet

The system SHALL evaluate 1:1 matched-pair binary outcomes using a 4-cell multinomial Dirichlet model over concordant and discordant pair configurations, deriving the marginal event rates, risk difference (RD), relative risk (RR), and odds ratio (OR) across posterior draws.

#### Scenario: Computing matched pair posterior draws

- **WHEN** 1:1 matched pair binary outcome contingency counts $(n_{11}, n_{10}, n_{01}, n_{00})$ are provided
- **THEN** the system MUST sample the cell multinomial probabilities $\mathbf{p} \sim \text{Dirichlet}(\alpha_{11}, \alpha_{10}, \alpha_{01}, \alpha_{00})$, compute marginal probabilities $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$, derive contrast metrics ($RD = p_T - p_R$, $RR = p_T / p_R$, $OR = p_{10} / p_{01}$), and populate the standardized draws object.

### Requirement: 1:k Variable Ratio Matched-Set Inference

The system SHALL evaluate 1:k matched cohort data using a matched-set cluster bootstrap approach, preserving the integrity of matched clusters across resamples, and generating posterior contrast distributions.

#### Scenario: Sampling matched sets with variable matching ratios

- **WHEN** matched cohort data with variable k ratios per stratum are provided
- **THEN** the system MUST resample entire matched sets with replacement, compute stratum-weighted or conditional event proportions, and emit the resulting bootstrap contrast distribution.

### Requirement: IPTW Propensity Score Weighted Inference

The system SHALL perform IPTW-adjusted comparative inference using patient-level bootstrap resampling that refits the propensity score model within each bootstrap replicate to account for estimation uncertainty, while computing effective sample size (ESS), covariate balance metrics, and positivity diagnostics.

#### Scenario: Computing IPTW bootstrap draws with refitting

- **WHEN** observational patient-level data with treatment assignment, outcome, and baseline covariates are provided for IPTW analysis
- **THEN** the system MUST draw bootstrap samples with replacement, re-estimate the propensity score within each replicate, compute stabilized weights, evaluate ESS and maximum weight, issue warnings if extreme weights or poor balance (standardized mean difference > 0.1) are detected, and derive weighted contrast draws.

### Requirement: Person-Time Gamma-Poisson Rate Contrast Inference

The system SHALL evaluate incidence rate data with exposure times using conjugate or semi-conjugate Gamma-Poisson rate models, producing posterior distributions for incidence rate difference (IRD) and incidence rate ratio (IRR).

#### Scenario: Evaluating rate comparisons with person-time exposure

- **WHEN** event counts and person-time denominators are supplied for test and reference groups
- **THEN** the system MUST sample Poisson rates $\lambda_T \sim \text{Gamma}(\alpha_T + x_T, \beta_T + Y_T)$ and $\lambda_R \sim \text{Gamma}(\alpha_R + x_R, \beta_R + Y_R)$, derive $IRD = \lambda_T - \lambda_R$ and $IRR = \lambda_T / \lambda_R$, and populate the standardized draws object.

### Requirement: Standardized Output Conformance to comparative-draws-v1

The system SHALL ensure that all design-aware inference samplers output data adhering to the `comparative-draws-v1` schema, including parameter draws, Monte Carlo diagnostics, effective sample size, and model fit metadata.

#### Scenario: Emitting standardized draws object

- **WHEN** any design-aware inference sampler completes execution
- **THEN** the resulting output MUST validate against the `comparative-draws-v1` schema contract and provide identical downstream accessors for contrast transformation, interval estimation, and risk classification.
