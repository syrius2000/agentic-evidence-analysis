## Purpose

Define the specification for the Evidence-Decision Consistency review engine. This component measures concordance between statistical evidence profiles and human expert decisions across historical analyses, retrieves relevant precedents via unsupervised feature distance, flags discordances as QA review candidates without overriding human judgment, and maintains an audit trajectory of decision rationale.

## ADDED Requirements

### Requirement: Unsupervised Evidence Feature Vector Construction

The system SHALL construct a standardized, multidimensional evidence feature vector from statistical analysis results without incorporating prior human decision labels or clinical verdict codes into the feature representation.

#### Scenario: Generating feature vectors from comparative analysis outputs

- **WHEN** a completed comparative analysis profile containing posterior probabilities, interval widths, sample sizes, and balance metrics is processed
- **THEN** the system MUST extract purely objective statistical summary features (including $RD$ median, $P(RD > 0)$, $q_H$, $q_N$, $q_B$, uncertainty interval width, sample size, and quarantine status) into an unsupervised feature vector.

### Requirement: Gower Distance Precedent Retrieval

The system SHALL calculate pairwise dissimilarities between the current evidence feature vector and historical case vectors using Gower distance, retrieving the most similar historical precedents and hierarchical clusters.

#### Scenario: Querying historical precedents for a new evidence profile

- **WHEN** a new evidence profile is submitted to the consistency engine
- **THEN** the system MUST compute Gower distance across numerical and ordinal attributes against the historical repository, rank past analyses by similarity, and return the top matching cases along with their recorded context.

### Requirement: Historical Context and Decision Narrative Display

The system SHALL present retrieved historical precedents along with their recorded decisions, supporting statistical evidence, and documented rationale to provide context for expert review.

#### Scenario: Displaying precedent review card

- **WHEN** top historical precedents are retrieved for an active review session
- **THEN** the system MUST format and display the past cases' evidence metrics, original expert decisions, and rationale notes side-by-side with the current evidence profile.

### Requirement: Discordance Flagging as Quality Review Candidates

The system SHALL flag instances where an assigned or provisional decision markedly diverges from the cluster consensus of historical precedents as a "QA Review Candidate", and MUST NOT classify or report such divergence as a fatal error, system defect, or automatic rejection.

#### Scenario: Identifying discordant decision relative to precedent cluster

- **WHEN** the provisional decision on a case differs substantially from the decisions documented in 80% or more of its nearest precedent cluster
- **THEN** the system MUST generate an informational advisory flagging the case as a "QA Review Candidate", prompting the reviewer to document their context-specific rationale, without blocking workflow progression or labeling the state as an error.

### Requirement: Decision Trajectory and Rationale Audit Trail

The system SHALL record an immutable audit trajectory for any decision change, capturing the timestamp, previous state, new state, user identity, and qualitative rationale.

#### Scenario: Logging expert decision rationale upon update

- **WHEN** a reviewer submits or modifies a decision for an analysis case
- **THEN** the system MUST append an audit record to the case metadata containing the previous decision, updated decision, markdown justification, timestamp (JST), and evidence profile checksum.
