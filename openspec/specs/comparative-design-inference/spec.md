# comparative-design-inference Specification

## Purpose
Define the specification for design-aware comparative statistical inference across observational and real-world designs, including 1:1 matched pairs, 1:k matched sets, inverse probability of treatment weighting (IPTW), and person-time exposure rates. This engine generates standardized uncertainty draws conforming to the logical `comparative-draws-v1` interface, enforces explicit estimator formulas for ATT and ATE targets, and strictly preserves inferential semantics between Bayesian posterior distributions and bootstrap resampling distributions.

## Requirements

### Requirement: Design-Aware Uncertainty Draw Interface

The system SHALL provide a design-aware inference engine that accepts design metadata and input data, validates design-specific structural preconditions, and generates standardized uncertainty draws matching the logical `comparative-draws-v1` runtime interface, explicitly labeling `inferential_semantics` as either `"posterior"` or `"bootstrap"`, designating point estimate sources, and nesting `interval: { method = "posterior_eti" | "bootstrap_percentile", ... }`.

#### Scenario: Routing and executing design-aware inference

- **WHEN** an analysis configuration specifying a supported design (`matched_1to1`, `matched_1tok`, `iptw`, or `person_time`) is processed
- **THEN** the system MUST route execution to the corresponding design sampler, produce a standardized in-memory uncertainty draws object, and set the appropriate inferential semantics, estimate source, and interval method labels.

### Requirement: 1:1 Matched-Pair Analysis via Multinomial Dirichlet Posterior

The system SHALL evaluate 1:1 matched-pair binary outcomes using a 4-cell multinomial Dirichlet posterior model with Jeffreys prior $\boldsymbol{\alpha} = (0.5, 0.5, 0.5, 0.5)$, deriving marginal event probabilities, posterior contrasts ($RD = p_{10} - p_{01}$, $RR$), and the discordant-pair matched odds ratio ($OR_{discordant} = p_{10}/p_{01}$) with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`. The system SHALL expose the distinct intra-pair association odds ratio $OR_{association} = p_{11}p_{00}/(p_{10}p_{01})$ only as `intra_pair_association_or`.

#### Scenario: Sampling 1:1 matched pair Dirichlet draws

- **WHEN** 1:1 matched-pair contingency counts $(n_{11}, n_{10}, n_{01}, n_{00})$ are provided
- **THEN** the system MUST sample cell probabilities $\mathbf{p} \sim \text{Dirichlet}(n_{11}+0.5, n_{10}+0.5, n_{01}+0.5, n_{00}+0.5)$, calculate marginal risks $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$, compute contrast draws, and assign `inferential_semantics = "posterior"` with `estimate.source = "posterior_median"`.

### Requirement: 1:k Matched-Set Cluster Bootstrap with Set-Weighted ATT Estimator

The system SHALL evaluate 1:k matched-set cohort data (one treated subject and $k_j \ge 1$ controls per matched set $j=1,\dots,J$, without replacement) using atomic matched-set cluster bootstrap resampling targeting the ATT estimand (`estimand = "ATT"`) with `num_draws >= 10` finite integer draws. The system SHALL require unique subject identifiers across sets to enforce non-replacement matching without duplicate subjects and validate that all numerical arguments are finite. The primary point estimate SHALL be computed analytically from the observed sample ($\hat{p}_{T,obs} = \frac{1}{J}\sum Y_{Tj}$, $\hat{p}_{R,obs} = \frac{1}{J}\sum \bar{Y}_{Rj}$ with `estimate.source = "observed_sample_estimate"` and `estimate_semantics = "att_set_weighted_risk"` in the reference cohort), keeping raw descriptive counts in `matched_set.raw_*_counts`. Post-match standardized mean differences (SMD) SHALL use ATT-weighted second central moments ($s_T^2 = \frac{1}{J}\sum(X_{Tj}-\bar{X}_T)^2$, $s_R^2 = \frac{1}{J}\sum_{j,\ell}\frac{1}{k_j}(X_{Rj\ell}-\bar{X}_R)^2$, $s_{pooled}=\sqrt{(s_T^2+s_R^2)/2}$) and classify zero-variance cases in a scale-invariant manner ($s_{pooled} = 0$) into `ZERO_VARIANCE_ZERO_DIFFERENCE` ($SMD=0.0$) or `ZERO_VARIANCE_NONZERO_DIFFERENCE` ($SMD=\text{null}$). The system SHALL emit `bootstrap_scope: { type = "conditional_on_fixed_matched_sets", rematching_within_replicate = false, propensity_model_refit = false }` clarifying that inference is explicitly conditional on realized matched sets rather than a bootstrap of the matching estimator itself (noting Abadie & Imbens 2008 on why ordinary matching bootstrap is not generally valid), record `rr_bootstrap_diagnostics`, and suppress the RR point estimate, interval, mean, and RR-derived precision metrics (`null`) if observed reference risk is zero, or suppress the RR interval and precision metrics if any bootstrap replicate has an undefined ratio ($p_R^* = 0$).

#### Scenario: Resampling matched sets with variable matching ratios

- **WHEN** matched cohort data with variable $k_j$ controls per matched set and subject identifiers are provided
- **THEN** the system MUST validate subject uniqueness across sets, compute observed sample ATT estimates, resample entire matched sets atomically with replacement, evaluate post-match balance (SMD) with ATT weights and scale-invariant zero-variance status, emit `estimand = "ATT"`, `bootstrap_scope`, and `interval.method = "bootstrap_percentile"`, and suppress RR bounds and precision metrics if any replicate has a zero reference denominator.

### Requirement: IPTW Propensity Score Bootstrap with In-Replicate Refitting and Arm-Specific Truncation

The system SHALL perform IPTW-adjusted comparative inference via patient-level bootstrap resampling with propensity score refitting inside *every* bootstrap replicate (`iptw_mode = "refit_ps"`), computing the primary point estimate from the original observed sample (`estimate.source = "observed_sample_estimate"`), evaluating exact weights:

- Unstabilized ATE: $w_i^{ATE} = \frac{A_i}{e_i} + \frac{1-A_i}{1-e_i}$
- Unstabilized ATT: $w_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}$
- Stabilized ATE: $sw_i^{ATE} = A_i \frac{P(A=1)}{e_i} + (1-A_i)\frac{P(A=0)}{1-e_i}$
- Scaled ATT: $sw_i^{ATT} = A_i + (1-A_i)\frac{e_i}{1-e_i}\frac{P(A=1)}{P(A=0)}$ governed by `att_weight_scaling.mode = "conventional" | "marginal_odds_scaled"`
applying percentile weight truncation to final computed weights separately by treatment arm, and assigning `inferential_semantics = "bootstrap"` and `interval.method = "bootstrap_percentile"`.

The engine SHALL treat each input row as one subject, reject missing or duplicated values when `subject_id_col` is supplied, expose a configurable finite `max_failure_rate` in `[0, 1)`, and fail when the bootstrap cannot meet that threshold. The propensity-score clamp SHALL be explicit and configurable through `ps_boundary`, defaulting to `c(1e-6, 1 - 1e-6)`; outputs SHALL preserve raw and effective PS summaries, boundary values, and clipping counts, and raw-score distributions SHALL drive positivity overlap diagnostics. Raw patient counts SHALL remain under `iptw.raw_patient_counts`; weighted cohort risks SHALL NOT expose raw `events`/`total` values as their numerator/denominator. Draw metadata SHALL record `iptw_mode`, truncation, ATT scaling, propensity model/covariates, PS boundary policy, and maximum failure rate. ATT stabilization SHALL be invalid unless `att_scaling_mode = "marginal_odds_scaled"`.

Both IPTW evidence and draw schemas SHALL require the same analysis provenance: `iptw_mode`, truncation, ATT scaling mode, propensity model/covariates, propensity-score boundary policy, bootstrap clipping diagnostics, and `max_failure_rate`. The default maximum failure rate SHALL be `0.05`. Successful bootstrap refits SHALL summarize clipping replicates, low/high clipped score totals, and the maximum clipped fraction in any replicate.

#### Scenario: Computing IPTW bootstrap replicates with model refitting

- **WHEN** observational patient data with treatment assignment, outcome, and baseline covariates are supplied for IPTW analysis
- **THEN** the system MUST evaluate the observed sample IPTW contrast, draw bootstrap samples with replacement, re-estimate the propensity score within each replicate, compute weights with arm-specific truncation, evaluate ESS, and derive replicate bounds with `interval.method = "bootstrap_percentile"`.

#### Scenario: Reporting IPTW inference semantics

- **WHEN** bootstrap IPTW evidence is supplied to the comparative report renderer
- **THEN** the report MUST use bootstrap percentile interval and bootstrap support fraction terminology, MUST NOT use posterior median, ETI, or `P(RD > 0)` labels, and MUST preserve Bayesian posterior/ETI terminology for Bayesian evidence.

#### Scenario: Rendering IPTW evidence with count provenance

- **WHEN** IPTW evidence is supplied to the report renderer with corresponding aggregate descriptive rows
- **THEN** the renderer MUST verify the row counts against `iptw.raw_patient_counts`, fail with `EVIDENCE_REPORT_PROVENANCE_MISMATCH` when they differ, source displayed raw descriptive counts from the IPTW evidence, display effective sample size in separate ESS fields, and omit Fisher exact output by default for the design-aware override.

The reporting contract SHALL NOT adopt a small-cell masking threshold in this change. Bootstrap resampling duplicates are expected and SHALL NOT be labeled as pseudo-replication.

### Requirement: Person-Time Gamma-Poisson Rate Contrast Posterior

The system SHALL evaluate incidence rate data with person-time exposure using an exact conjugate Gamma-Poisson rate model under the Jeffreys rate prior $\pi(\lambda_g) \propto \lambda_g^{-1/2}$, generating posterior rate draws $\lambda_g \mid x_g, T_g \sim \text{Gamma}(x_g + 0.5, T_g)$ under the shape-rate parameterization, and deriving incidence rate difference (IRD) and incidence rate ratio (IRR) draws with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`.

The engine SHALL accept non-negative integer events and finite positive exposure time in a common `person_years` or `person_months` unit, including event counts greater than exposure time. It SHALL return the shared `comparative-draws-v1` interface with required person-time metadata and rate-specific `comparative-rate-evidence-v1` evidence using `incidence_rate_difference` and `incidence_rate_ratio`, without labeling rates as binary risks. It SHALL annualize the IRD for `additional_events_per_100_person_years`, preserve ephemeral raw-draw behavior by default, and record the constant-rate and unmodeled within-subject recurrent-event clustering limitations. For zero reference events, it SHALL retain IRR posterior median and ETI while setting its divergent theoretical mean to null with `mean_is_finite = false`.

#### Scenario: Evaluating rate comparisons with person-time exposure

- **WHEN** event counts $x_g$ and person-time exposure denominators $T_g$ are supplied
- **THEN** the system MUST sample Poisson rates $\lambda_g \sim \text{Gamma}(x_g + 0.5, T_g)$, record `gamma_parameterization: "shape_rate"`, derive $IRD = \lambda_T - \lambda_R$ and $IRR = \lambda_T / \lambda_R$, set `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval.method = "posterior_eti"`, and document constant hazard assumptions.

### Requirement: Standardized Output Conformance to comparative-draws-v1

The system SHALL ensure that all design-aware inference samplers output data adhering to the logical `comparative-draws-v1` interface, providing consistent accessors for contrast transformation, interval estimation, and risk classification while maintaining serial reproducibility without requiring persistent raw draw serialization.

#### Scenario: Validating uncertainty draws interface

- **WHEN** any design-aware inference sampler completes execution
- **THEN** the resulting in-memory draws object MUST conform to `comparative-draws-v1` specifications and supply verified summary accessors for downstream reporting without requiring raw draw JSON persistence.
