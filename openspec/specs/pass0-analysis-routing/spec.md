# pass0-analysis-routing Specification

## Purpose
Define the specification for the Pass 0 consultation and analysis routing gateway. This capability inspects input data structure, validates study design and estimand specifications, verifies subject-level counting rules, and deterministically routes execution to the appropriate statistical engine while failing fast on invalid or unsupported configurations.

## Requirements

### Requirement: Input Structure and Duplicate Inspection

The system SHALL inspect tabular inputs for data integrity, distinguishing integer count summaries from non-integer weights, detecting optional design columns (weights, matched set IDs, cluster IDs, person-time exposure, MedDRA SOC/PT identifiers), and quantifying duplicate subject records within analysis groups.

#### Scenario: Inspecting input columns and subject duplication

- **WHEN** raw tabular input is submitted to Pass 0 consultation
- **THEN** the system MUST verify whether cell counts are non-negative integers, detect presence of optional design columns, quantify duplicate subject occurrences within PT and SOC, and propose standard deduplication counting rules without silently modifying the raw data.

### Requirement: Explicit Subject-Level Collapse of Repeated Binary Observations

For an `independent_binary` design with `analysis_unit = "subject"`, the system SHALL permit repeated observational rows only when a confirmed `repeated_rows` policy names the subject, group, and binary outcome columns, selects `event_rule = "any_event"`, sets `confirmed = true`, and sets `no_other_subject_dependence_confirmed = true`. Optional `cluster_cols` and `matched_cols` SHALL be merged with heuristic dependency aliases before guarding. It SHALL reject missing identifiers or outcomes, non-binary outcomes, treatment-group changes within a subject, matched-set structure (canonical or declared/heuristic noncanonical names), and clusters shared by multiple subjects or varying within a subject. When valid, it SHALL derive one binary outcome per subject, retain the original input and hash, record target/reference subject event and total counts plus a canonical `engine_input` handoff in the routing decision, and route those counts to the independent Beta-Binomial engine. It SHALL NOT silently infer a collapse rule or treat hierarchical clusters as independent subjects.

#### Scenario: Routing confirmed repeated observations

- **WHEN** repeated 0/1 observations have stable group assignment per subject and an explicitly confirmed `any_event` policy with no-other-dependence confirmation
- **THEN** Pass 0 MUST emit subject-level target/reference counts, a canonical `engine_input` block, preserve the original input hash, and route to the independent binary engine without rewriting the input.

#### Scenario: Rejecting hierarchical or unconfirmed repeated observations

- **WHEN** the collapse policy is unconfirmed, no-other-dependence confirmation is absent, matched-set identifiers are present (including noncanonical aliases such as `matched_group_id`), or a site/cluster (including noncanonical aliases such as `facility_id` / `hospital_id`, or explicitly configured columns) groups multiple subjects
- **THEN** Pass 0 MUST fail before independent-subject routing and identify the unsupported structure.

### Requirement: Cluster Bootstrap Extension and GLMM/GEE Boundary

The system SHALL specify a future cluster-level bootstrap interface with an atomic cluster ID, whole-cluster resampling, estimator/refitting scope, and failure/interval diagnostics. Section 12 SHALL NOT implement a cluster bootstrap estimator, GLMM, or GEE. Those estimators require a separate OpenSpec change with explicit estimands, correlation assumptions, and independent verification.

#### Scenario: Encountering a higher-level cluster

- **WHEN** multiple subjects share a cluster identifier in a repeated-row input
- **THEN** Pass 0 MUST stop rather than route those observations to an independence-assuming binary engine or silently substitute GLMM/GEE.

### Requirement: Explicit Estimand and Delta State Specification

The system SHALL require explicit specification of the primary estimand and practical difference mode, permitting `practical_difference.mode = "none"` with `primary_delta = null` as a valid non-blocking state, while requiring explicit confirmation for ambiguous causal estimands (ATE vs ATT).

#### Scenario: Validating practical difference configuration

- **WHEN** analysis configuration specifies `mode: "none"` and `primary_delta: null`
- **THEN** the system MUST accept the configuration without triggering a fail-fast error, configuring downstream reporting to generate direction support and delta profile matrices without discrete practical-region classifications.

### Requirement: Deterministic Routing Decision Generation

The system SHALL generate a reproducible routing artifact `routing_decision.json` conforming to `pass0-routing-v1`, containing input checksums, configuration hashes, target execution engine slug, inferential semantics (`posterior` or `bootstrap`), unresolved reviewer decisions, and when repeated-row collapse applies, both `subject_level_counts` and a canonical `engine_input` handoff block.

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
