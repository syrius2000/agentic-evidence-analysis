## Purpose

Provides core comparative evidence computation and multi-domain reporting capabilities, executing independent-binomial Jeffreys posterior inference, computing standardized contrast transforms, generating practical-difference profiles, and rendering offline Scientific Reports.

## ADDED Requirements

### Requirement: Independent Jeffreys Binomial Posterior Inference

The system SHALL perform Bayesian posterior inference for independent binary proportion comparisons using symmetric Jeffreys priors \(\text{Beta}(0.5, 0.5)\) without requiring artificial continuity corrections.

#### Scenario: Posterior parameter calculation under zero event counts

- **WHEN** event count is zero (\(x_g = 0\)) out of \(n_g\) subjects
- **THEN** the system SHALL compute the posterior as \(\text{Beta}(0.5, n_g + 0.5)\), yield a non-zero positive posterior median, and report the complete equal-tailed credible interval

#### Scenario: Generating deterministic posterior draws

- **WHEN** inferential execution is invoked with a specified random seed and draw count \(S\)
- **THEN** the system SHALL generate exactly \(S\) paired draws of target and reference proportions conforming to the `comparative-draws-v1` schema

### Requirement: Contrast Transformation and Draw Processing

The system SHALL consume paired target and reference draws to compute risk difference (RD), risk ratio (RR), and excess events per 100/1,000 subjects.

#### Scenario: Risk difference and excess computation

- **WHEN** paired draws are processed
- **THEN** the system SHALL calculate draw-wise \(RD = p_T - p_R\) and \(\text{Excess} = RD \times \text{scale}\), deriving posterior median, 95% ETI, and directional support \(P(RD > 0)\)

#### Scenario: Consumption of design-aware external draws

- **WHEN** `comparative-draws-v1` produced by an upstream design-aware engine is provided
- **THEN** the system SHALL process the draws through the identical contrast pipeline while respecting the `inferential_semantics` attribute (posterior vs bootstrap)

### Requirement: Mathematical Safeguard for Zero-Cell Risk Ratio

The system SHALL safeguard risk ratio inference when reference event counts are zero by strictly reporting posterior median and ETI while explicitly flagging the theoretical expectation as non-finite.

#### Scenario: Zero reference events RR evaluation

- **WHEN** reference group event count is zero (\(x_R = 0\))
- **THEN** the system SHALL report the median and ETI for RR, record `mean = null`, set `mean_is_finite = false`, and prohibit substituting the Monte-Carlo sample mean as a finite posterior expectation

### Requirement: Practical Difference and Uncertainty Classification

When an approved clinical/practical threshold \(\delta\) is defined, the system SHALL partition posterior risk differences into High (\(RD > \delta\)), Neutral (\(|RD| \le \delta\)), and Below (\(RD < -\delta\)) regions and assign an uncertainty grade (U0 to U3).

#### Scenario: Three-region probability partitioning

- **WHEN** an approved \(\delta > 0\) is supplied
- **THEN** the system SHALL calculate probabilities \(q_H = P(RD > \delta)\), \(q_N = P(|RD| \le \delta)\), and \(q_B = P(RD < -\delta)\), verifying that their sum equals 1.0 within numerical precision

#### Scenario: Absence of primary practical threshold

- **WHEN** configuration does not specify a primary delta threshold (`primary_delta = null`)
- **THEN** the system SHALL compute continuous delta profiles and directional support, but SHALL disable discrete H/N/B categorization and suppress practical-color highlighting

### Requirement: Domain-Specific Reporting Profiles

The system SHALL support domain-specific presentation profiles including Safety (Primary SOC / PT hierarchy with subject deduplication), generic RWD (parent/item), and Prescription data.

#### Scenario: Safety hierarchy deduplication

- **WHEN** Safety adverse event data is processed
- **THEN** the system SHALL ensure SOC event counts reflect distinct subjects having at least one qualifying PT event within the SOC, asserting that SOC count does not exceed denominator and is not a simple sum of child PTs

#### Scenario: Preservation of study-level provenance in pooled analyses

- **WHEN** pooled safety analyses across multiple studies are generated
- **THEN** the report SHALL present both study-specific breakdowns and pooled summaries without erasing individual study traceability

### Requirement: Visual and Narrative Non-Significance Guards

The system SHALL enforce strict narrative and visual rules preventing misleading claims of equivalence, absence of effect, or causal assertion from posterior direction alone.

#### Scenario: Narrative guard on wide credible intervals

- **WHEN** a credible interval spans zero with a wide interval width
- **THEN** the generated narrative SHALL NOT describe the outcome as \"no difference\" or \"proved safe\", but SHALL explicitly characterize it as \"inconclusive with substantial uncertainty\"

#### Scenario: Visual guard against coloring on direction alone

- **WHEN** rendering report tables or dashboards
- **THEN** cell background hue SHALL NOT be colored based purely on directional support \(P(RD > 0)\), reserving hue for dominant practical regions when \(\delta\) is approved
