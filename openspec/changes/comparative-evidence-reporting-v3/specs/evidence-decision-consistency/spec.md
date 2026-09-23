## Purpose

Define the specification for the Evidence-Decision Consistency review engine. This component measures concordance between decision-label-free statistical evidence profiles and human expert decisions across historical analyses, retrieves relevant precedents via unsupervised Gower distance, presents precedent distributions without imposing automated regulatory decisions, and maintains an append-only, tamper-evident audit ledger.

## ADDED Requirements

### Requirement: Decision-Label-Free Evidence Feature Construction

The system SHALL construct standardized evidence feature vectors from statistical analysis summaries, strictly excluding human clinical verdict codes, regulatory outcome labels, and prior decision attributes from the feature representation, while partitioning features into mandatory core attributes and optional delta-dependent attributes.

#### Scenario: Generating feature vectors from comparative analysis outputs
- **WHEN** a comparative analysis profile is processed for consistency auditing
- **THEN** the system MUST extract purely statistical summary metrics (such as $RD$ median, $RD$ interval width, direction support, effective sample size, and quarantine flags) into a feature vector conforming to `evidence-feature-v1`, handling missing practical-region probabilities appropriately when `primary_delta` is `null`.

### Requirement: Gower Distance Precedent Retrieval with Version Binding

The system SHALL calculate pairwise dissimilarities between the current evidence feature vector and historical case vectors using Gower distance, binding comparisons to historical metadata including dictionary release version, delta policy version, and feature schema version.

#### Scenario: Querying historical precedents for an active case
- **WHEN** an evidence feature vector is submitted to the consistency engine
- **THEN** the system MUST compute Gower distance across available numeric and categorical attributes against historical cases, expose version differences across cases, rank historical cases by proximity, and retrieve the nearest precedent cohort.

### Requirement: Precedent Distribution and Context Presentation

The system SHALL present retrieved historical precedents along with their recorded decisions, supporting statistical evidence, documented reviewer rationales, and context metadata side-by-side with the active analysis case.

#### Scenario: Displaying precedent review profile
- **WHEN** historical precedents are retrieved for an active review session
- **THEN** the system MUST display the distribution of historical expert decisions, associated interval widths, sample sizes, and qualitative justification notes without presenting a singular prescriptive decision.

### Requirement: Configurable Discordance Advisory as QA Review Candidates

The system SHALL evaluate case decisions against precedent distributions using a configurable discordance policy (neighborhood size $k$ or distance radius), flagging divergence as an informational "QA Review Candidate" prompting expert rationale documentation, and SHALL NOT classify divergence as a fatal error, system defect, or automatic rejection.

#### Scenario: Identifying discordant decision relative to precedent cluster
- **WHEN** an expert's provisional decision diverges from the dominant pattern of its nearest precedent neighborhood under the active discordance policy
- **THEN** the system MUST generate an advisory notification flagging the case as a "QA Review Candidate", prompting the reviewer to document their context-specific rationale, without halting workflow progression or labeling the state as an error.

### Requirement: Append-Only Tamper-Evident Decision Ledger

The system SHALL maintain an append-only, tamper-evident audit ledger recording every decision submission and modification, capturing record ID, previous record SHA-256 hash, evidence profile checksum, decision state, reviewer justification markdown, actor identifier, and JST timestamp.

#### Scenario: Logging expert decision rationale
- **WHEN** a reviewer submits or updates a decision for an analysis case
- **THEN** the system MUST append a new tamper-evident audit record linking to the previous record hash, recording the complete rationale and timestamp, and verifying cryptographic chain integrity.
