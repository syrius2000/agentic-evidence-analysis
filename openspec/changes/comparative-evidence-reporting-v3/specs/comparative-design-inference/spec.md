## Purpose

Define the specification for design-aware comparative statistical inference across observational and real-world designs, including 1:1 matched pairs, 1:k matched sets, inverse probability of treatment weighting (IPTW), and person-time exposure rates. This engine generates standardized uncertainty draws conforming to the logical `comparative-draws-v1` interface, enforces explicit estimator formulas for ATT and ATE targets, and strictly preserves inferential semantics between Bayesian posterior distributions and bootstrap resampling distributions.

## ADDED Requirements

### Requirement: Design-Aware Uncertainty Draw Interface

The system SHALL provide a design-aware inference engine that accepts design metadata and input data, validates design-specific structural preconditions, and generates standardized uncertainty draws matching the logical `comparative-draws-v1` runtime interface, explicitly labeling `inferential_semantics` as either `"posterior"` or `"bootstrap"`, designating point estimate sources, and nesting `interval: { method = "posterior_eti" | "bootstrap_percentile", ... }`.

#### Scenario: Routing and executing design-aware inference

- **WHEN** an analysis configuration specifying a supported design (`matched_1to1`, `matched_1tok`, `iptw`, or `person_time`) is processed
- **THEN** the system MUST route execution to the corresponding design sampler, produce a standardized in-memory uncertainty draws object, and set the appropriate inferential semantics, estimate source, and interval method labels.

### Requirement: 1:1 Matched-Pair Analysis via Multinomial Dirichlet Posterior

The system SHALL evaluate 1:1 matched-pair binary outcomes using a 4-cell multinomial Dirichlet posterior model with Jeffreys prior $\boldsymbol{\alpha} = (0.5, 0.5, 0.5, 0.5)$, deriving marginal event probabilities and posterior contrasts ($RD = p_{10} - p_{01}$, $RR$, $OR$) with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`.

#### Scenario: Sampling 1:1 matched pair Dirichlet draws

- **WHEN** 1:1 matched-pair contingency counts $(n_{11}, n_{10}, n_{01}, n_{00})$ are provided
- **THEN** the system MUST sample cell probabilities $\mathbf{p} \sim \text{Dirichlet}(n_{11}+0.5, n_{10}+0.5, n_{01}+0.5, n_{00}+0.5)$, calculate marginal risks $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$, compute contrast draws, and assign `inferential_semantics = "posterior"` with `estimate.source = "posterior_median"`.

### Requirement: 1:k Matched-Set Cluster Bootstrap with Set-Weighted ATT Estimator

The system SHALL evaluate 1:k matched-set cohort data (one treated subject and $k_j \ge 1$ controls per matched set $j=1,\dots,J$, without replacement) using atomic matched-set cluster bootstrap resampling targeting the ATT estimand, where the primary point estimate is computed from the observed sample ($\hat{p}_{T,obs} = \frac{1}{J}\sum Y_{Tj}$, $\hat{p}_{R,obs} = \frac{1}{J}\sum \frac{1}{k_j}\sum Y_{Rj\ell}$ with `estimate.source = "observed_sample_estimate"`), while replicate distributions determine bootstrap percentile intervals (`interval.method = "bootstrap_percentile"`) and bootstrap region support fractions.

#### Scenario: Resampling matched sets with variable matching ratios

- **WHEN** matched cohort data with variable $k_j$ controls per matched set are provided
- **THEN** the system MUST compute observed sample ATT estimates, resample entire matched sets atomically with replacement, evaluate post-match balance (SMD), and emit the replicate distribution with `inferential_semantics = "bootstrap"`, `estimate.source = "observed_sample_estimate"`, `interval.method = "bootstrap_percentile"`, and `bootstrap_support_fraction_rd_gt_zero`.

### Requirement: IPTW Propensity Score Bootstrap with In-Replicate Refitting and Arm-Specific Truncation

The system SHALL perform IPTW-adjusted comparative inference via patient-level bootstrap resampling with propensity score refitting inside *every* bootstrap replicate (`iptw_mode = "refit_ps"`), computing the primary point estimate from the original observed sample (`estimate.source = "observed_sample_estimate"`), evaluating exact weights:

- Unstabilized ATE: $w_i^{ATE} = \frac{A_i}{e_i} + \frac{1-A_i}{1-e_i}$
- Unstabilized ATT: $w_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}$
- Stabilized ATE: $sw_i^{ATE} = A_i \frac{P(A=1)}{e_i} + (1-A_i)\frac{P(A=0)}{1-e_i}$
- Scaled ATT: $sw_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}\frac{P(A=1)}{P(A=0)}$ governed by `att_weight_scaling.mode = "conventional" | "marginal_odds_scaled"`
applying percentile weight truncation to final computed weights separately by treatment arm, and assigning `inferential_semantics = "bootstrap"` and `interval.method = "bootstrap_percentile"`.

#### Scenario: Computing IPTW bootstrap replicates with model refitting

- **WHEN** observational patient data with treatment assignment, outcome, and baseline covariates are supplied for IPTW analysis
- **THEN** the system MUST evaluate the observed sample IPTW contrast, draw bootstrap samples with replacement, re-estimate the propensity score within each replicate, compute weights with arm-specific truncation, evaluate ESS, and derive replicate bounds with `interval.method = "bootstrap_percentile"`.

### Requirement: Person-Time Gamma-Poisson Rate Contrast Posterior

The system SHALL evaluate incidence rate data with person-time exposure using an exact conjugate Gamma-Poisson rate model under the Jeffreys rate prior $\pi(\lambda_g) \propto \lambda_g^{-1/2}$, generating posterior rate draws $\lambda_g \mid x_g, T_g \sim \text{Gamma}(x_g + 0.5, T_g)$ under the shape-rate parameterization, and deriving incidence rate difference (IRD) and incidence rate ratio (IRR) draws with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`.

#### Scenario: Evaluating rate comparisons with person-time exposure

- **WHEN** event counts $x_g$ and person-time exposure denominators $T_g$ are supplied
- **THEN** the system MUST sample Poisson rates $\lambda_g \sim \text{Gamma}(x_g + 0.5, T_g)$, record `gamma_parameterization: "shape_rate"`, derive $IRD = \lambda_T - \lambda_R$ and $IRR = \lambda_T / \lambda_R$, set `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`, and document constant hazard assumptions.

### Requirement: Standardized Output Conformance to comparative-draws-v1

The system SHALL ensure that all design-aware inference samplers output data adhering to the logical `comparative-draws-v1` interface, providing consistent accessors for contrast transformation, interval estimation, and risk classification while maintaining serial reproducibility without requiring persistent raw draw serialization.

#### Scenario: Validating uncertainty draws interface

- **WHEN** any design-aware inference sampler completes execution
- **THEN** the resulting in-memory draws object MUST conform to `comparative-draws-v1` specifications and supply verified summary accessors for downstream reporting without requiring raw draw JSON persistence.
