## Purpose

Provides a statistical consultation gateway that inspects input dataset integrity, validates study design and count constraints, resolves estimand and practical delta parameters, and generates deterministic analysis routing decisions.

## ADDED Requirements

### Requirement: Input Inspection and Count Validation

The system SHALL inspect tabular comparative inputs for count validity, non-negative integer counts, denominator boundaries, and subject duplication before any inferential computation.

#### Scenario: Non-integer count rejection in binomial designs

- **WHEN** user inputs non-integer event or sample count values for an unweighted binary proportion analysis
- **THEN** the system SHALL reject the execution with a fail-fast validation error and record the invalid input in the inspection summary

#### Scenario: Zero denominator boundary detection

- **WHEN** input rows contain a zero denominator count (\(n_g = 0\))
- **THEN** the system SHALL flag the row as unanalyzable for proportion estimation and prevent division-by-zero execution in downstream engines

#### Scenario: Duplicate subject verification in safety data

- **WHEN** safety adverse event data is supplied with repeated subject records under the same Preferred Term (PT)
- **THEN** the system SHALL detect duplicate subjects, enforce subject-level deduplication rules, and report raw vs deduplicated counts in the inspection output

### Requirement: Design and Estimand Specification

The consultation gateway SHALL capture and validate the primary estimand, analysis unit, target and reference groups, design type, and practical-difference status from user configuration.

#### Scenario: Complete specification resolution

- **WHEN** user provides valid configuration specifying design (independent, matched, IPTW, rate), primary estimand (subject risk, marginal risk, incidence rate), and optional practical delta
- **THEN** the system SHALL validate that all required parameters for the specified design are present and emit an approved configuration object

#### Scenario: Material ambiguity consultation requirement

- **WHEN** user submits ambiguous configuration lacking primary estimand or target/reference group orientation
- **THEN** the system SHALL halt automated routing, list the material choices requiring resolution, and prompt for explicit user confirmation

### Requirement: Deterministic Routing Decision Generation

The system SHALL generate a structured `routing_decision.json` binding the input data hash, selected design engine, target skill, and execution parameters.

#### Scenario: Independent binary comparison routing

- **WHEN** input data represents unweighted independent two-group binary counts
- **THEN** the system SHALL route the analysis to `vcd-categorical-reporting` and record target engine `independent_beta_binomial` in `routing_decision.json`

#### Scenario: Design-aware comparative routing

- **WHEN** input data contains matching identifiers or propensity score weights
- **THEN** the system SHALL route the analysis to `comparative-design-analysis` and record the appropriate design method (matched_set or iptw_bootstrap) in `routing_decision.json`

### Requirement: Incompatible Design Fail-Fast Guard

The system SHALL immediately halt with an error if a design requiring complex adjustment (e.g. propensity score weights or clustered sampling) is targeted at the independent binomial engine.

#### Scenario: Preventing weighted data from independent binomial inference

- **WHEN** input data includes survey weights or IPTW weights but the user requests simple Beta-Binomial execution
- **THEN** the system SHALL reject execution with error `INCOMPATIBLE_DESIGN_ROUTING` and require design-aware inference routing
