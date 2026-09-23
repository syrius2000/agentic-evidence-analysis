## 0. Specification and Ownership Gate

- [ ] 0.1 Create `docs/Artifacts/implementation_plan_NNN_0923.md` from the approved plan and verify file existence.
- [ ] 0.2 Initialize active OpenSpec change directory `openspec/changes/comparative-evidence-reporting-v3/` and verify structure.
- [ ] 0.3 Populate `proposal.md`, `design.md`, delta specs, and `tasks.md` conforming to OpenSpec schema.
- [ ] 0.4 Declare and verify capabilities: `pass0-analysis-routing`, `comparative-evidence-reporting`, `comparative-design-inference`, and `evidence-decision-consistency`.
- [ ] 0.5 Confirm `two-way-evidence-analysis` spec remains intact for contingency-table association/residual analysis without modifications.
- [ ] 0.6 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [ ] 0.7 Obtain explicit Owner approval before transitioning to implementation phase.

## 1. Pass 0 Consultation Gateway

- [ ] 1.1 Extend Pass 0 schema with domain, estimand, analysis unit, target/reference, design, practical-difference mode, hierarchy, reporting purpose, and decision-review flag, verifying against schema test.
- [ ] 1.2 Implement inspection for non-integer counts, verifying warning/error emission on float inputs.
- [ ] 1.3 Add duplicate subject diagnostic checks within PT and SOC, verified by unit test fixture.
- [ ] 1.4 Detect optional column patterns (weight, matched-set, cluster, person-time, SOC/PT, study) and verify detection in summary output.
- [ ] 1.5 Implement deterministic routing logic outputting `routing_decision.json` and verify against test cases.
- [ ] 1.6 Require explicit input or fail-fast for ambiguous choices (primary estimand, ATE/ATT, primary delta, regulatory reporting purpose), verified by consultation test suite.
- [ ] 1.7 Enforce fail-fast guard preventing weighted analyses from routing to unweighted Beta-Binomial engine, verified by negative test.
- [ ] 1.8 Add comprehensive Pass 0 test suite and verify `Rscript tests/test_pass0_routing.R` passes.

## 2. Shared Schemas and Contrast Engine

- [ ] 2.1 Implement `comparative-draws-v1.json` schema and verify schema validation tests.
- [ ] 2.2 Implement `comparative-evidence-v1.json` schema and verify schema validation tests.
- [ ] 2.3 Implement shared contrast transformation engine in `.agents/shared/comparative_contrasts.R` and verify unit tests.
- [ ] 2.4 Implement risk difference (RD) and incidence rate difference (IRD) draw transformations, verified by mathematical test cases.
- [ ] 2.5 Implement relative risk (RR) and incidence rate ratio (IRR) draw transformations, verified by mathematical test cases.
- [ ] 2.6 Implement excess events per natural unit (per 100, per 1000) conversions and verify output format.
- [ ] 2.7 Implement direction support metric $P(RD > 0)$ and verify boundary tests (0.0 to 1.0).
- [ ] 2.8 Implement delta profile evaluations over grid $\delta \in \{0.005, 0.01, 0.02, 0.05, 0.10\}$ and verify monotonic properties.
- [ ] 2.9 Implement $q_H, q_N, q_B$ probabilities when `primary_delta` is set, and verify $q_H + q_N + q_B = 1.0$ invariant.
- [ ] 2.10 Implement configurable U0–U3 uncertainty presentation classification and verify against test cases.
- [ ] 2.11 Support `inferential_semantics = posterior | bootstrap` flag and verify proper serialization in output metadata.
- [ ] 2.12 Enforce terminology separation between Bayesian posterior probabilities and bootstrap resample fractions, verified by linting tests.
- [ ] 2.13 Implement zero and sparse count diagnostic badges (`ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`) and verify test fixtures.
- [ ] 2.14 Add schema invariant test suite and verify `Rscript tests/test_comparative_schemas.R` passes.

## 3. Independent Jeffreys Binary Engine

- [ ] 3.1 Implement `.agents/shared/independent_beta_binomial.R` and verify file creation.
- [ ] 3.2 Add assertion enforcing strictly non-negative integer counts for events and totals, verified by failure on invalid inputs.
- [ ] 3.3 Validate $0 \le x_T \le n_T$ and $0 \le x_R \le n_R$ bounds, verified by unit assertions.
- [ ] 3.4 Implement Jeffreys prior $\text{Beta}(0.5, 0.5)$ sampling, verified against theoretical posterior quantile benchmarks.
- [ ] 3.5 Support deterministic pseudo-random seeds for exact posterior draw reproducibility, verified by seed equality tests.
- [ ] 3.6 Generate target and reference posterior summaries (median, mean, 95% ETI, 95% HDI), verified by numerical assertions.
- [ ] 3.7 Output standardized draws object conforming to `comparative-draws-v1`, verified by schema validator.
- [ ] 3.8 Implement detection of zero-reference counts causing infinite theoretical expectation for $RR$, setting `mean = null` and `mean_is_finite = false`.
- [ ] 3.9 Enforce safeguard preventing empirical Monte-Carlo mean of $RR$ from being reported when theoretical expectation diverges, verified by unit test.
- [ ] 3.10 Add relative risk instability diagnostics (flagging wide intervals, ratio of upper/lower bounds), verified by test assertions.
- [ ] 3.11 Implement golden regression cases (`3/100 vs 0/100`, `0/100 vs 0/100`, `30/100 vs 20/100`, `3/30 vs 30/300`, `1/200 vs 0/1000`, `1/200 vs 2/1000`, `0/200 vs 2/1000`) and verify all outputs.
- [ ] 3.12 Add tests asserting delta-profile monotonicity and verify test pass.
- [ ] 3.13 Add tests asserting $q_H + q_N + q_B = 1.0$ within floating point tolerance and verify test pass.
- [ ] 3.14 Test that `primary_delta = null` disables practical classification categories and visual hue assignment, verified by unit test.

## 4. `vcd-categorical-reporting` Skill Revival

- [ ] 4.1 Update skill manifest to transition `vcd-categorical-reporting` from deprecated to active comparative evidence skill.
- [ ] 4.2 Rewrite `.agents/skills/vcd-categorical-reporting/SKILL.md` to specify comparative evidence reporting workflow and verify docs.
- [ ] 4.3 Preserve historical reporting templates under explicit legacy compatibility namespaces and verify legacy tests continue passing.
- [ ] 4.4 Add multi-theme long-format dataset ingestion adapter and verify tabular parsing tests.
- [ ] 4.5 Add support for explicit pairwise contrast specifications across multiple study groups, verified by unit tests.
- [ ] 4.6 Implement reference-vs-all group contrast generator and verify contrast matrix construction.
- [ ] 4.7 Enforce guard restricting default all-pairs generation when group count exceeds 4 without explicit override, verified by test.
- [ ] 4.8 Generate canonical output artifact `comparative_evidence.json` and `comparative_summary.csv`, verified by schema validation.
- [ ] 4.9 Implement self-contained offline Markdown and HTML summary reports and verify browser rendering.
- [ ] 4.10 Retain raw event counts ($x/n$), sample sizes, and optional SAS PROC FREQ / Fisher exact test compatibility columns in output.
- [ ] 4.11 Implement narrative guard in AI reporting template prohibiting claims that "non-significance implies equivalence", verified by template test.
- [ ] 4.12 Implement narrative guard prohibiting claims that posterior direction implies causal superiority, verified by template test.
- [ ] 4.13 Enforce visual encoding rule: cell background hue SHALL NOT be determined by posterior direction alone, verified by CSS/HTML audit.

## 5. Clinical Safety Adapter

- [ ] 5.1 Define canonical MedDRA hierarchy representation (SOC $\rightarrow$ HLGT $\rightarrow$ HLT $\rightarrow$ PT) in `.agents/shared/safety_adapter.R`.
- [ ] 5.2 Require MedDRA version provenance and dictionary release metadata in input analysis configuration, verified by validation test.
- [ ] 5.3 Enforce Primary SOC mapping as the standard aggregation level, verified by hierarchy test fixtures.
- [ ] 5.4 Retain HLGT and HLT levels as optional secondary drill-down tables, verified by report generator.
- [ ] 5.5 Deduplicate subjects within PT so that an individual with multiple occurrences of the same PT is counted once, verified by test assertion.
- [ ] 5.6 Deduplicate subjects within SOC so that an individual experiencing multiple distinct PTs within the same SOC is counted once in that SOC, verified by test fixture.
- [ ] 5.7 Assert that unique subject count in a SOC never exceeds the group denominator, verified by automated assertion.
- [ ] 5.8 Assert and verify that SOC incidence count is never calculated by summing child PT incident counts, verified by unit test.
- [ ] 5.9 Support study-specific output stratification in multiregional clinical trial datasets, verified by test fixture.
- [ ] 5.10 Support pooled cohort analysis with traceable study-level breakdown tables, verified by integration tests.
- [ ] 5.11 Implement clinical safety domain labels (Adverse Event, SOC, PT, Incidence Rate, Excess Cases per 100, RR, U-grade) in reports.
- [ ] 5.12 Ensure NNH/NNT metrics remain optional secondary metrics and are suppressed when effect direction contains significant uncertainty ($P(RD > 0) \in [0.05, 0.95]$), verified by unit test.
- [ ] 5.13 Add Safety regression test fixture featuring recurrent adverse events across multiple PTs within a single SOC, verified by test script.
- [ ] 5.14 Add Safety zero-cell adverse event test fixture and verify safe report rendering.

## 6. RWD and Prescription Adapters

- [ ] 6.1 Implement generic hierarchical adapter supporting arbitrary parent-child theme structures (`parent_theme -> item_theme`), verified by unit test.
- [ ] 6.2 Implement Real-World Data (RWD) clinical context extension mapping diagnoses and procedures, verified by test fixture.
- [ ] 6.3 Implement Prescription/Formulary analysis context extension mapping drug classes to active ingredients, verified by test fixture.
- [ ] 6.4 Implement domain-specific presentation decorators without altering underlying canonical statistical fields, verified by output validation.
- [ ] 6.5 Add statistical invariance test asserting that identical counts passed through Safety, RWD, and Prescription adapters yield identical posterior metrics, verified by `Rscript tests/test_domain_invariance.R`.

## 7. Practical Difference and Uncertainty Policy

- [ ] 7.1 Implement default `primary_delta = null` configuration requiring explicit user setting, verified by test assertion.
- [ ] 7.2 Implement natural-unit conversions for delta specifications (`per_100`, `per_1000`, absolute probability), verified by unit tests.
- [ ] 7.3 Implement explicit prespecified delta evaluation mode, verified by parameter configuration test.
- [ ] 7.4 Implement versioned departmental policy mode for delta boundaries, verified by configuration loader.
- [ ] 7.5 Ensure delta profile matrix is computed and archived even when no primary delta is approved, verified by JSON schema validation.
- [ ] 7.6 Implement simulation utility to evaluate candidate U0–U3 uncertainty thresholds under various sample sizes and base rates.
- [ ] 7.7 Validate provisional U0–U3 cutoff parameters against synthetic sparse and imbalanced cohorts, documenting recommendations.
- [ ] 7.8 Verify all generated documentation and report tooltips explicitly clarify that U-grade reflects estimation precision, not clinical severity.

## 8. Design-Aware Inference Engine: 1:1 Matched Pairs

- [ ] 8.1 Initialize `.agents/skills/comparative-design-analysis/` skill and verify manifest.
- [ ] 8.2 Implement 4-cell paired contingency table extractor ($(n_{11}, n_{10}, n_{01}, n_{00})$) from matched pair datasets, verified by unit test.
- [ ] 8.3 Implement multinomial Dirichlet sampler with prior $\alpha = (0.5, 0.5, 0.5, 0.5)$ for cell probabilities, verified by test assertions.
- [ ] 8.4 Derive marginal risk draws $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$ across posterior samples, verified by unit test.
- [ ] 8.5 Verify mathematical invariant $RD = p_{10} - p_{01}$ across draws in unit test.
- [ ] 8.6 Generate standardized draws object adhering to `comparative-draws-v1`, verified by schema validator.
- [ ] 8.7 Implement matched-pair golden test cases and verify numerical accuracy against analytical reference solutions.
- [ ] 8.8 Record matched-pair sample size, concordant, and discordant pair counts in output metadata, verified by JSON output inspection.

## 9. Design-Aware Inference Engine: 1:k Matched Sets

- [ ] 9.1 Implement cluster bootstrap sampler for 1:k matched sets in `.agents/shared/matched_set_inference.R`, verified by unit tests.
- [ ] 9.2 Enforce atomic resampling of matched sets with replacement, verified by cluster membership assertions.
- [ ] 9.3 Record matching ratio, caliper, with/without replacement status, and matched/discarded patient counts in metadata, verified by test.
- [ ] 9.4 Compute and record post-match covariate balance metrics (standardized mean differences), verified by unit tests.
- [ ] 9.5 Emit output draws with `inferential_semantics = "bootstrap"` and verify downstream narrative adaptation.
- [ ] 9.6 Add bootstrap reproducibility and seed consistency tests, verified by regression test pass.

## 10. Design-Aware Inference Engine: IPTW

- [ ] 10.1 Implement patient-level bootstrap resampling for IPTW in `.agents/shared/iptw_inference.R`, verified by unit tests.
- [ ] 10.2 Refit the propensity score model inside each bootstrap replicate, verified by simulation test.
- [ ] 10.3 Recompute propensity weights inside each bootstrap replicate, verified by weight calculation assertions.
- [ ] 10.4 Implement weight stabilization and percentile truncation options, verified by parameter configuration tests.
- [ ] 10.5 Support explicit ATE (average treatment effect) and ATT (average treatment effect on treated) estimand targets, verified by test cases.
- [ ] 10.6 Compute weighted marginal event proportions across bootstrap replicates, verified by test assertions.
- [ ] 10.7 Compute and record effective sample size (ESS) for target and reference groups, verified by output validation.
- [ ] 10.8 Record weight distribution quantiles and maximum weight, issuing warning if extreme weights occur, verified by test.
- [ ] 10.9 Record before and after weighting standardized mean differences (SMD) across baseline covariates, verified by test output.
- [ ] 10.10 Record positivity and propensity score overlap diagnostics, verified by report visualizer.
- [ ] 10.11 Implement convergence monitoring and record failed bootstrap replicates, failing fast if failure rate exceeds 5%, verified by negative test.
- [ ] 10.12 Verify that non-integer pseudo-counts from IPTW are rejected by the independent Beta-Binomial engine, verified by unit test.
- [ ] 10.13 Verify that reports generated from IPTW use bootstrap resampling terminology rather than Bayesian posterior terminology, verified by narrative test.

## 11. Person-Time Incidence Rate Engine

- [ ] 11.1 Implement Gamma-Poisson rate model in `.agents/shared/person_time_rate.R` and verify file creation.
- [ ] 11.2 Generate target and reference Poisson incidence rate draws from posterior Gamma distributions, verified by test assertions.
- [ ] 11.3 Feed rate draws into shared contrast engine to derive incidence rate difference (IRD) and incidence rate ratio (IRR), verified by unit tests.
- [ ] 11.4 Record exposure units (person-years, person-months) and denominator metadata in output draws, verified by schema validation.
- [ ] 11.5 Add zero-event person-time test fixtures and verify numerical stability.

## 12. Clustering and Repeated Measurements Boundary

- [ ] 12.1 Implement Pass 0 check determining whether repeated observational rows can be collapsed to subject-level binary status, verified by test cases.
- [ ] 12.2 Route to subject-level binary engine when valid collapsing is confirmed, verified by routing test.
- [ ] 12.3 Specify cluster-level bootstrap extension interface for hierarchical clustering data, verified by design documentation.
- [ ] 12.4 Verify explicit architecture boundary keeping GLMM and GEE estimation out of scope until future dedicated OpenSpec change, verified by documentation check.

## 13. Evidence-Decision Review Engine

- [ ] 13.1 Initialize `.agents/skills/evidence-decision-review/` skill and verify manifest.
- [ ] 13.2 Define evidence feature vector schema extracting purely objective statistical summaries without human decision labels, verified by schema test.
- [ ] 13.3 Verify assertion that clinical decision codes and regulatory labels are excluded from clustering input features, verified by unit test.
- [ ] 13.4 Implement Gower distance dissimilarity calculation for mixed numeric and categorical evidence features, verified by test assertions.
- [ ] 13.5 Implement hierarchical agglomerative clustering over historical evidence profiles, verified by clustering test.
- [ ] 13.6 Add optional standardized K-means clustering for purely continuous feature subsets, verified by test suite.
- [ ] 13.7 Enforce validation rejecting unscaled continuous inputs for K-means clustering, verified by negative test.
- [ ] 13.8 Implement nearest historical precedent retrieval returning top matching cases with distance metrics, verified by retrieval tests.
- [ ] 13.9 Define immutable decision ledger schema recording decision state, timestamp, author, and markdown justification, verified by schema validator.
- [ ] 13.10 Implement discordance detection flagging cases where provisional decision departs from precedent consensus, verified by test fixture.
- [ ] 13.11 Enforce wording contract designating divergences as "QA Review Candidates" rather than system errors or invalid states, verified by string audit.
- [ ] 13.12 Implement trajectory tracking capturing longitudinal changes in decisions across study phases or data cutoffs, verified by test script.
- [ ] 13.13 Implement bootstrap cluster stability assessment or emit explicit `NOT_ASSESSED` warning, verified by test assertion.
- [ ] 13.14 Add test demonstrating that cluster assignment alone never triggers automated regulatory actions or label modifications, verified by governance test.

## 14. Dashboard and Self-Contained Report QA

- [ ] 14.1 Structure HTML report layout with dedicated, separated columns for Effect Size, Direction, Practical Difference, and Uncertainty, verified by visual inspection.
- [ ] 14.2 Enforce visual color palette using practical region hue ($q_H, q_N, q_B$) modulated by U-grade intensity only when primary delta is set, verified by CSS audit.
- [ ] 14.3 Verify that U3 category renders with muted, desaturated tones indicating high uncertainty rather than alarmist red hues, verified by visual test.
- [ ] 14.4 Render zero and sparse event diagnostic badges separately from statistical estimates, verified by report layout test.
- [ ] 14.5 Display prominent warning callout when relative risk point estimate or credible interval displays numerical instability, verified by visual inspection.
- [ ] 14.6 Audit generated HTML and verify zero external HTTP/HTTPS network dependencies (fonts, CDNs, scripts), verified by static regex scan.
- [ ] 14.7 Audit generated HTML and verify zero OS-specific local absolute paths, verified by static path scanner.
- [ ] 14.8 Implement automated structural HTML tests validating DOM element IDs and accessibility attributes, verified by test suite.
- [ ] 14.9 Perform browser visual verification using subagent or manual render to confirm responsive layout on desktop viewports.

## 15. Documentation and Ecosystem Synchronization

- [ ] 15.1 Update `AGENTS.md` with new skill dispatch guidelines and iron laws, verified by file inspection.
- [ ] 15.2 Update `README.md` introducing comparative evidence reporting and design-aware capabilities, verified by markdown check.
- [ ] 15.3 Update `docs/reference/skill_responsibilities.md` with updated boundary matrices, verified by documentation review.
- [ ] 15.4 Update `.agents/skills/vcd-pass0-consultation/SKILL.md` documenting new routing questions and parameters.
- [ ] 15.5 Update `.agents/skills/vcd-categorical-reporting/SKILL.md` reflecting comparative reporting capabilities.
- [ ] 15.6 Document newly created skills (`comparative-design-analysis`, `evidence-decision-review`) in skill guides.
- [ ] 15.7 Explicitly mark historical reporting references in archive files as legacy, verified by documentation scan.
- [ ] 15.8 Verify that historical archive artifacts remain untouched except where necessary for pointer reconciliation.
- [ ] 15.9 Run documentation cross-link consistency check verifying all internal links use relative paths, verified by link auditor.

## 16. Independent QA and Regression Verification Gate

- [ ] 16.1 Conduct blind-first independent QA review reading OpenSpec and code/tests prior to implementer narrative review.
- [ ] 16.2 Mathematically verify zero-cell behavior: median + ETI reported, `mean = null`, `mean_is_finite = false` when $x_R = 0$.
- [ ] 16.3 Verify practical difference delta semantics: `primary_delta = null` disables classification and color cues.
- [ ] 16.4 Verify that U-grade reflects estimation uncertainty and is never presented as clinical severity.
- [ ] 16.5 Verify strict separation of Bayesian posterior probability vs bootstrap resample frequency terminology.
- [ ] 16.6 Verify that weighted pseudo-counts are rejected by independent Beta-Binomial engine.
- [ ] 16.7 Verify Safety hierarchy accounting invariants: subject deduplication and SOC count $\ne$ sum of PT counts.
- [ ] 16.8 Verify that no component triggers automated regulatory decisions or label determinations.
- [ ] 16.9 Execute complete canonical regression test suite and verify 100% test pass.
- [ ] 16.10 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [ ] 16.11 Run `git diff --check` and verify clean diff without whitespace or delimiter errors.
- [ ] 16.12 Record unresolved risks and obtain explicit Owner adjudication.

## 17. Completion and Archive Readiness Gate

- [ ] 17.1 Verify all tasks 0.1 through 16.12 have verified executable evidence.
- [ ] 17.2 Confirm zero unadjudicated Blocker or High severity QA findings.
- [ ] 17.3 Freeze and version all statistical JSON schemas (`comparative-draws-v1`, `comparative-evidence-v1`).
- [ ] 17.4 Confirm full alignment between code implementation, tests, and OpenSpec delta specifications.
- [ ] 17.5 Obtain explicit Owner sign-off accepting remaining documented operational risks.
- [ ] 17.6 Require explicit, separate authorization before invoking `/opsx-archive`.
