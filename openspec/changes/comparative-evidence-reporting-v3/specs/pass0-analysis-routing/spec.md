## Purpose

Define the specification for the Pass 0 consultation and analysis routing gateway. This capability inspects input data structure, validates study design and estimand specifications, verifies subject-level counting rules, and deterministically routes execution to the appropriate statistical engine while failing fast on invalid or unsupported configurations.

## ADDED Requirements

### Requirement: Input Structure and Duplicate Inspection

The system SHALL inspect tabular inputs for data integrity, distinguishing integer count summaries from non-integer weights, detecting optional design columns (weights, matched set IDs, cluster IDs, person-time exposure, MedDRA SOC/PT identifiers), and quantifying duplicate subject records within analysis groups.

#### Scenario: Inspecting input columns and subject duplication
- **WHEN** raw tabular input is submitted to Pass 0 consultation
- **THEN** the system MUST verify whether cell counts are non-negative integers, detect presence of optional design columns, quantify duplicate subject occurrences within PT and SOC, and propose standard deduplication counting rules without silently modifying the raw data.

### Requirement: Explicit Estimand and Delta State Specification

The system SHALL require explicit specification of the primary estimand and practical difference mode, permitting `practical_difference.mode = "none"` with `primary_delta = null` as a valid non-blocking state, while requiring explicit confirmation for ambiguous causal estimands (ATE vs ATT).

#### Scenario: Validating practical difference configuration
- **WHEN** analysis configuration specifies `mode: "none"` and `primary_delta: null`
- **THEN** the system MUST accept the configuration without triggering a fail-fast error, configuring downstream reporting to generate direction support and delta profile matrices without discrete practical-region classifications.

### Requirement: Deterministic Routing Decision Generation

The system SHALL generate a reproducible routing artifact `routing_decision.json` containing input checksums, configuration hashes, target execution engine slug, inferential semantics (`posterior` or `bootstrap`), and unresolved reviewer decisions.

#### Scenario: Routing independent binary cohort comparisons
- **WHEN** independent two-group binary counts with integer values and no matching or weighting variables are inspected
- **THEN** the system MUST emit `routing_decision.json` assigning the analysis to `vcd-categorical-reporting` using the independent Jeffreys Beta-Binomial engine with `inferential_semantics = "posterior"`.

### Requirement: Incompatible and Unsupported Design Fail-Fast Guards

The system SHALL fail fast with structured, actionable diagnostic codes when an analysis configuration violates engine assumptions, specifically preventing weighted or pseudo-count data from entering unweighted Beta-Binomial engines, and rejecting complex survey sampling weights with code `UNSUPPORTED_SURVEY_DESIGN`.

#### Scenario: Rejecting survey weights
- **WHEN** tabular data containing complex survey sampling weights (e.g. strata and cluster survey weights) are submitted
- **THEN** the system MUST immediately halt execution with diagnostic code `UNSUPPORTED_SURVEY_DESIGN` and provide guidance on supported design capabilities.

#### Scenario: Intercepting weighted pseudo-counts
- **WHEN** non-integer weighted frequencies resulting from propensity score weighting are directed to the unweighted independent Beta-Binomial engine
- **THEN** the system MUST fail fast, explaining that weighted observational cohorts must be routed to `comparative-design-analysis` (IPTW bootstrap engine).
