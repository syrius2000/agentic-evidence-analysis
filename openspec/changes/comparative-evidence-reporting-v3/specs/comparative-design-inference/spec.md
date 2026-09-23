## Purpose

Define the specification for design-aware comparative statistical inference across observational and real-world designs, including 1:1 matched pairs, 1:k matched sets, inverse probability of treatment weighting (IPTW), and person-time exposure rates. This engine generates standardized uncertainty draws conforming to the logical `comparative-draws-v1` interface while strictly preserving inferential semantics between Bayesian posterior distributions and bootstrap resampling distributions.

## ADDED Requirements

### Requirement: Design-Aware Uncertainty Draw Interface

The system SHALL provide a design-aware inference engine that accepts design metadata and input data, validates design-specific structural preconditions, and generates standardized uncertainty draws matching the logical `comparative-draws-v1` runtime interface, explicitly labeling `inferential_semantics` as either `"posterior"` or `"bootstrap"`.

#### Scenario: Routing and executing design-aware inference
- **WHEN** an analysis configuration specifying a supported design (`matched_1to1`, `matched_1tok`, `iptw`, or `person_time`) is processed
- **THEN** the system MUST route execution to the corresponding design sampler, produce a standardized in-memory uncertainty draws object, and set the appropriate inferential semantics label.

### Requirement: 1:1 Matched-Pair Analysis via Multinomial Dirichlet Posterior

The system SHALL evaluate 1:1 matched-pair binary outcomes using a 4-cell multinomial Dirichlet posterior model with Jeffreys prior $\boldsymbol{\alpha} = (0.5, 0.5, 0.5, 0.5)$, deriving marginal event probabilities and posterior contrasts ($RD = p_{10} - p_{01}$, $RR$, $OR$) with `inferential_semantics = "posterior"`.

#### Scenario: Sampling 1:1 matched pair Dirichlet draws
- **WHEN** 1:1 matched-pair contingency counts $(n_{11}, n_{10}, n_{01}, n_{00})$ are provided
- **THEN** the system MUST sample cell probabilities $\mathbf{p} \sim \text{Dirichlet}(n_{11}+0.5, n_{10}+0.5, n_{01}+0.5, n_{00}+0.5)$, calculate marginal risks $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$, compute contrast draws, and assign `inferential_semantics = "posterior"`.

### Requirement: 1:k Matched-Set Cluster Bootstrap Inference

The system SHALL evaluate 1:k matched-set cohort data using an atomic matched-set cluster bootstrap approach targeting the ATT estimand, resampling entire matched clusters with replacement to generate empirical uncertainty replicate distributions with `inferential_semantics = "bootstrap"`.

#### Scenario: Resampling matched sets with variable matching ratios
- **WHEN** matched cohort data with variable $k$ ratios per stratum are provided
- **THEN** the system MUST resample entire matched sets atomically with replacement, compute stratum-weighted event proportions per bootstrap replicate, evaluate post-match balance (SMD), and emit the replicate distribution with `inferential_semantics = "bootstrap"` and `bootstrap_support_fraction_rd_gt_zero`.

### Requirement: IPTW Propensity Score Bootstrap with In-Replicate Model Refitting

The system SHALL perform IPTW-adjusted comparative inference via patient-level bootstrap resampling that refits the propensity score model inside *every* bootstrap replicate (`iptw_mode = "refit_ps"`), supporting explicit ATE and ATT estimands, stabilized weights, and weight truncation, while recording effective sample size (ESS), maximum weight, and covariate balance diagnostics.

#### Scenario: Computing IPTW bootstrap replicates with model refitting
- **WHEN** observational patient data with treatment assignment, outcome, and baseline covariates are supplied for IPTW analysis
- **THEN** the system MUST draw bootstrap samples with replacement, re-estimate the propensity score within each replicate, compute stabilized weights, evaluate ESS, issue warnings if extreme weights or poor balance (SMD > 0.1) are detected, and derive weighted contrast replicates with `inferential_semantics = "bootstrap"`.

### Requirement: Person-Time Gamma-Poisson Rate Contrast Posterior

The system SHALL evaluate incidence rate data with person-time exposure using an exact conjugate Gamma-Poisson rate model under the Jeffreys rate prior $\pi(\lambda_g) \propto \lambda_g^{-1/2}$, generating posterior rate draws $\lambda_g \mid x_g, T_g \sim \text{Gamma}(x_g + 0.5, T_g)$ under the shape-rate parameterization, and deriving incidence rate difference (IRD) and incidence rate ratio (IRR) draws with `inferential_semantics = "posterior"`.

#### Scenario: Evaluating rate comparisons with person-time exposure
- **WHEN** event counts $x_g$ and person-time exposure denominators $T_g$ are supplied
- **THEN** the system MUST sample Poisson rates $\lambda_g \sim \text{Gamma}(x_g + 0.5, T_g)$, record `gamma_parameterization: "shape_rate"`, derive $IRD = \lambda_T - \lambda_R$ and $IRR = \lambda_T / \lambda_R$, set `inferential_semantics = "posterior"`, and document the constant hazard and independent event assumptions.

### Requirement: Standardized Output Conformance to comparative-draws-v1

The system SHALL ensure that all design-aware inference samplers output data adhering to the logical `comparative-draws-v1` interface, providing consistent accessors for contrast transformation, interval estimation, and risk classification while maintaining serial reproducibility without requiring persistent raw draw serialization.

#### Scenario: Validating uncertainty draws interface
- **WHEN** any design-aware inference sampler completes execution
- **THEN** the resulting in-memory draws object MUST conform to `comparative-draws-v1` specifications and supply verified summary accessors for downstream reporting without requiring raw draw JSON persistence.
