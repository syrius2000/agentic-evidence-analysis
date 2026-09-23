## 0. Specification and Ownership Gate

- [ ] 0.1 Create `docs/Artifacts/implementation_plan_NNN_0923.md` from the approved plan and verify file existence.
- [ ] 0.2 Initialize active OpenSpec change directory `openspec/changes/comparative-evidence-reporting-v3/` and verify structure.
- [ ] 0.3 Populate `proposal.md`, `design.md`, delta specs, and `tasks.md` conforming to OpenSpec schema.
- [ ] 0.4 Declare and verify capabilities: `pass0-analysis-routing`, `comparative-evidence-reporting`, `comparative-design-inference`, and `evidence-decision-consistency`.
- [ ] 0.5 Confirm `two-way-evidence-analysis` spec remains intact for contingency-table association/residual analysis without modifications.
- [ ] 0.6 Synchronize `openspec/specs/deterministic-r-dependencies/spec.md` to reference `tests/run_regression_suite.R` as the dynamic canonical registry rather than a fixed test count.
- [ ] 0.7 Verify integration contract with `evidence-run-layout` ensuring all new skills use `evidence_runs/<skill_slug>/run_<canonical_id>[_N]/`.
- [ ] 0.8 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [ ] 0.9 Obtain explicit Owner approval before transitioning to implementation phase.

## 1. Pass 0 Consultation Gateway

- [ ] 1.1 Extend Pass 0 schema with domain, estimand, analysis unit, target/reference, design, practical-difference mode, hierarchy, reporting purpose, and decision-review flag, verifying against schema test.
- [ ] 1.2 Implement inspection for non-integer counts, verifying warning/error emission on float inputs.
- [ ] 1.3 Add duplicate subject diagnostic checks within PT and SOC, reporting duplication counts and proposing standard counting rules without silent data transformation.
- [ ] 1.4 Detect optional column patterns (weight, matched-set, cluster, person-time, SOC/PT, study) and verify detection in summary output.
- [ ] 1.5 Implement deterministic routing logic outputting `routing_decision.json` with input hashes, configuration hashes, target engine slug, and inferential semantics.
- [ ] 1.6 Support explicit `practical_difference.mode = "none"` with `primary_delta = null` as a valid non-blocking state, while requiring explicit confirmation for ambiguous causal estimands (ATE vs ATT).
- [ ] 1.7 Enforce fail-fast guard intercepting complex survey sampling weights with code `UNSUPPORTED_SURVEY_DESIGN` and preventing weighted pseudo-counts from entering the independent Beta-Binomial engine.
- [ ] 1.8 Add comprehensive Pass 0 test suite and verify `Rscript tests/test_pass0_routing.R` passes.

## 2. Shared Schemas and Contrast Engine

- [ ] 2.1 Implement logical runtime schema `comparative-draws-v1.json` supporting `inferential_semantics = "posterior" | "bootstrap"` with ephemeral in-memory management.
- [ ] 2.2 Implement permanent deliverable schema `comparative-evidence-v1.json` and verify schema validation tests.
- [ ] 2.3 Implement shared contrast transformation engine in `.agents/shared/comparative_contrasts.R` and verify unit tests.
- [ ] 2.4 Implement risk difference (RD) and incidence rate difference (IRD) draw transformations, verified by mathematical test cases.
- [ ] 2.5 Implement relative risk (RR) and incidence rate ratio (IRR) draw transformations, verified by mathematical test cases.
- [ ] 2.6 Implement excess events per natural unit (per 100 and per 1000) conversions and verify output format.
- [ ] 2.7 Implement direction support metric, labeling Bayesian outputs as $P(RD > 0)$ and bootstrap outputs as `bootstrap_support_fraction_rd_gt_zero`.
- [ ] 2.8 Implement configurable delta profile evaluations over user-specified or non-normative default threshold vectors, asserting monotonic properties.
- [ ] 2.9 Implement $q_T, q_N, q_R$ practical region probabilities across canonical regions (`TARGET_EXCESS`, `PRACTICAL_NEUTRAL`, `REFERENCE_EXCESS`) when `primary_delta` exists, verifying $q_T + q_N + q_R = 1.0$ invariant.
- [ ] 2.10 Implement Practical-Region Resolution Grade (U0–U3) from $C = \max(q_T, q_N, q_R)$, documenting that U-grade reflects region classification decisiveness rather than generic sampling precision.
- [ ] 2.11 Implement separate continuous precision metrics (`rd_eti_width`, `log_rr_eti_width`, effective sample size) and verify presence in JSON output.
- [ ] 2.12 Enforce strict terminology separation between Bayesian posterior probabilities and bootstrap resample fractions, verified by linting tests.
- [ ] 2.13 Implement zero and sparse count diagnostic badges (`ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`) and continuous instability metrics (`log_rr_eti_width`).
- [ ] 2.14 Add schema invariant test suite and verify `Rscript tests/test_comparative_schemas.R` passes.

## 3. Independent Jeffreys Binary Engine

- [ ] 3.1 Implement `.agents/shared/independent_beta_binomial.R` and verify file creation.
- [ ] 3.2 Add assertion enforcing strictly non-negative integer counts for events and positive totals ($n > 0$), rejecting $n=0$ cohorts.
- [ ] 3.3 Validate $0 \le x_T \le n_T$ and $0 \le x_R \le n_R$ bounds, verified by unit assertions.
- [ ] 3.4 Implement Jeffreys prior $\text{Beta}(0.5, 0.5)$ sampling, verified against theoretical posterior quantile benchmarks.
- [ ] 3.5 Support deterministic pseudo-random seeds for exact uncertainty draw reproducibility, verified by seed equality tests.
- [ ] 3.6 Generate target and reference posterior summaries (median, mean, 95% ETI), verified by numerical assertions.
- [ ] 3.7 Output standardized uncertainty draws conforming to the logical `comparative-draws-v1` interface, verified by in-memory schema validator.
- [ ] 3.8 Implement detection of zero-reference counts causing infinite theoretical expectation for $RR$, setting `mean = null` and `mean_is_finite = false`.
- [ ] 3.9 Enforce safeguard preventing empirical Monte-Carlo mean of $RR$ from being reported when theoretical expectation diverges, verified by unit test.
- [ ] 3.10 Add relative risk continuous instability diagnostics (`log_rr_eti_width`, `rr_interval_fold_range`), verified by test assertions.
- [ ] 3.11 Implement golden regression cases (`3/100 vs 0/100`, `0/100 vs 0/100`, `30/100 vs 20/100`, `3/30 vs 30/300`, `1/200 vs 0/1000`, `1/200 vs 2/1000`, `0/200 vs 2/1000`) and verify all outputs.
- [ ] 3.12 Add tests asserting delta-profile monotonicity and verify test pass.
- [ ] 3.13 Add tests asserting $q_T + q_N + q_R = 1.0$ within floating point tolerance and verify test pass.
- [ ] 3.14 Test that `primary_delta = null` disables practical classification categories and visual hue assignment, verified by unit test.

## 4. `vcd-categorical-reporting` Skill Revival

- [ ] 4.1 Update skill manifest to transition `vcd-categorical-reporting` from deprecated to active comparative evidence skill.
- [ ] 4.2 Rewrite `.agents/skills/vcd-categorical-reporting/SKILL.md` to specify comparative evidence reporting workflow and verify docs.
- [ ] 4.3 Preserve historical reporting templates under explicit legacy compatibility namespaces and verify legacy tests continue passing.
- [ ] 4.4 Add multi-theme long-format dataset ingestion adapter and verify tabular parsing tests.
- [ ] 4.5 Add support for explicit pairwise contrast specifications across multiple study groups, verified by unit tests.
- [ ] 4.6 Implement contrast generation for $>2$ groups defaulting to reference-vs-all and requiring explicit request for all-pairs, verified by unit test.
- [ ] 4.7 Generate canonical output artifacts `comparative_evidence.json` and `comparative_summary.csv`, verified by schema validation.
- [ ] 4.8 Implement self-contained offline Markdown and HTML summary reports complying with zero-external-asset rules and verify browser rendering.
- [ ] 4.9 Retain raw event counts ($x/n$), sample sizes, and optional SAS PROC FREQ / Fisher exact test compatibility columns in output.
- [ ] 4.10 Implement narrative guard in AI reporting template prohibiting claims that "non-significance implies equivalence", verified by template test.
- [ ] 4.11 Implement narrative guard prohibiting claims that posterior direction implies causal superiority, verified by template test.
- [ ] 4.12 Enforce visual encoding rule: cell background hue SHALL NOT be determined by posterior direction alone, verified by CSS/HTML audit.
- [ ] 4.13 Add mandatory exploratory screening disclaimer in multi-theme batch reports stating posterior probabilities do not guarantee familywise error rate control.

## 5. Clinical Safety Adapter

- [ ] 5.1 Define canonical Safety reporting hierarchy as Primary SOC $\rightarrow$ PT in `.agents/shared/safety_adapter.R`, keeping HLGT and HLT as optional secondary drill-downs.
- [ ] 5.2 Require MedDRA version provenance and dictionary release metadata in input analysis configuration, verified by validation test.
- [ ] 5.3 Enforce Primary SOC mapping as the standard aggregation level, verified by hierarchy test fixtures.
- [ ] 5.4 Deduplicate subjects within PT so that an individual with multiple occurrences of the same PT is counted once, verified by test assertion.
- [ ] 5.5 Deduplicate subjects within SOC so that an individual experiencing multiple distinct PTs within the same SOC is counted once in that SOC, verified by test fixture.
- [ ] 5.6 Assert that unique subject count in a SOC never exceeds the group denominator, verified by automated assertion.
- [ ] 5.7 Assert and verify that SOC incidence count is never calculated by summing child PT incident counts, verified by unit test.
- [ ] 5.8 Support study-specific output stratification as canonical, designating multi-study pooled aggregations as `descriptive_pooled` without asserting unmodeled between-study homogeneity.
- [ ] 5.9 Implement clinical safety domain labels (Adverse Event, SOC, PT, Incidence Proportion, Excess Cases per 100, RR, U-grade) in reports.
- [ ] 5.10 Manage reciprocal-RD (NNH) rendering using `reciprocal_status` (`STABLE_DIRECTION`, `SIGN_AMBIGUOUS`, `RD_NEAR_ZERO`, `NOT_INTERPRETABLE`), suppressing naive confidence intervals when the RD interval crosses zero.
- [ ] 5.11 Add Safety regression test fixture featuring recurrent adverse events across multiple PTs within a single SOC, verified by test script.
- [ ] 5.12 Add Safety zero-cell adverse event test fixture and verify safe report rendering.

## 6. RWD and Prescription Adapters

- [ ] 6.1 Implement generic hierarchical adapter supporting arbitrary parent-child theme structures (`parent_theme -> item_theme`), verified by unit test.
- [ ] 6.2 Implement Real-World Data (RWD) clinical context extension mapping diagnoses and procedures, verified by test fixture.
- [ ] 6.3 Implement Prescription/Formulary analysis context extension mapping drug classes to active ingredients, verified by test fixture.
- [ ] 6.4 Implement domain-specific presentation decorators without altering underlying canonical statistical fields, verified by output validation.
- [ ] 6.5 Add statistical invariance test asserting that identical counts passed through Safety, RWD, and Prescription adapters yield identical comparative evidence statistics, verified by `Rscript tests/test_domain_invariance.R`.

## 7. Practical Difference and Uncertainty Policy

- [ ] 7.1 Implement default `primary_delta = null` (`mode: "none"`) configuration, verified by test assertion.
- [ ] 7.2 Implement natural-unit conversions for delta specifications (`per_100`, `per_1000`, absolute probability), verified by unit tests.
- [ ] 7.3 Implement explicit prespecified delta evaluation mode, verified by parameter configuration test.
- [ ] 7.4 Implement versioned departmental policy mode for delta boundaries, verified by configuration loader.
- [ ] 7.5 Ensure delta profile matrix is computed and archived even when no primary delta is approved, verified by JSON schema validation.
- [ ] 7.6 Implement simulation utility to evaluate candidate U0–U3 uncertainty thresholds under various sample sizes and base rates.
- [ ] 7.7 Validate provisional U0–U3 cutoff parameters against synthetic sparse and imbalanced cohorts, documenting recommendations.
- [ ] 7.8 Verify all generated documentation and report tooltips explicitly clarify that U-grade reflects region classification decisiveness, not sampling precision or clinical severity.

## 8. Design-Aware Inference Engine: 1:1 Matched Pairs

- [ ] 8.1 Initialize `.agents/skills/comparative-design-analysis/` skill complying with `evidence-run-layout`.
- [ ] 8.2 Implement 4-cell paired contingency table extractor ($(n_{11}, n_{10}, n_{01}, n_{00})$) from matched pair datasets, verified by unit test.
- [ ] 8.3 Implement multinomial Dirichlet sampler with prior $\boldsymbol{\alpha} = (0.5, 0.5, 0.5, 0.5)$ for cell probabilities, verified by test assertions.
- [ ] 8.4 Derive marginal risk draws $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$ across posterior samples, verified by unit test.
- [ ] 8.5 Verify mathematical invariant $RD = p_{10} - p_{01}$ across draws in unit test.
- [ ] 8.6 Generate standardized uncertainty draws object conforming to `comparative-draws-v1` with `inferential_semantics = "posterior"`, verified by schema validator.
- [ ] 8.7 Implement matched-pair golden test cases and verify numerical accuracy against analytical reference solutions.
- [ ] 8.8 Record matched-pair sample size, concordant, and discordant pair counts in output metadata, verified by JSON output inspection.

## 9. Design-Aware Inference Engine: 1:k Matched Sets

- [ ] 9.1 Implement cluster bootstrap sampler for 1:k matched sets in `.agents/shared/matched_set_inference.R`, verified by unit tests.
- [ ] 9.2 Enforce atomic resampling of matched sets with replacement targeting ATT estimand, verified by cluster membership assertions.
- [ ] 9.3 Record matching ratio, caliper, with/without replacement status, and matched/discarded patient counts in metadata, verified by test.
- [ ] 9.4 Compute and record post-match covariate balance metrics (standardized mean differences), verified by unit tests.
- [ ] 9.5 Emit output draws with `inferential_semantics = "bootstrap"` and verify downstream narrative adaptation using `bootstrap_support_fraction`.
- [ ] 9.6 Add bootstrap reproducibility and seed consistency tests, verified by regression test pass.

## 10. Design-Aware Inference Engine: IPTW

- [ ] 10.1 Implement patient-level bootstrap resampling for IPTW in `.agents/shared/iptw_inference.R` using reproducible serial resampling.
- [ ] 10.2 Refit the propensity score model inside *every* bootstrap replicate (`iptw_mode = "refit_ps"`), verified by simulation test.
- [ ] 10.3 Recompute propensity weights inside each bootstrap replicate, verified by weight calculation assertions.
- [ ] 10.4 Implement configurable weight stabilization and percentile truncation options, verified by parameter configuration tests.
- [ ] 10.5 Support explicit ATE and ATT estimand targets, verified by test cases.
- [ ] 10.6 Compute weighted marginal event proportions across bootstrap replicates, verified by test assertions.
- [ ] 10.7 Compute and record effective sample size (ESS) for target and reference groups, verified by output validation.
- [ ] 10.8 Record weight distribution quantiles and maximum weight, issuing warning if extreme weights occur, verified by test.
- [ ] 10.9 Record before and after weighting standardized mean differences (SMD) across baseline covariates, verified by test output.
- [ ] 10.10 Record positivity and propensity score overlap diagnostics, verified by report visualizer.
- [ ] 10.11 Implement convergence monitoring with configurable failure threshold, failing fast if failure rate exceeds threshold, verified by test.
- [ ] 10.12 Verify that non-integer pseudo-counts from IPTW are rejected by the independent Beta-Binomial engine, verified by unit test.
- [ ] 10.13 Verify that reports generated from IPTW use bootstrap resampling terminology rather than Bayesian posterior terminology, verified by narrative test.

## 11. Person-Time Incidence Rate Engine

- [ ] 11.1 Implement conjugate Gamma-Poisson rate model in `.agents/shared/person_time_rate.R` using shape-rate parameterization $\text{Gamma}(x_g + 0.5, T_g)$ under Jeffreys prior, verified by unit test.
- [ ] 11.2 Generate target and reference Poisson incidence rate draws from posterior Gamma distributions with `inferential_semantics = "posterior"`, verified by test assertions.
- [ ] 11.3 Feed rate draws into shared contrast engine to derive incidence rate difference (IRD) and incidence rate ratio (IRR), verified by unit tests.
- [ ] 11.4 Record exposure units (person-years, person-months), parameterization (`shape_rate`), and denominator metadata in output, verified by schema validation.
- [ ] 11.5 Document limitations regarding constant hazard and lack of within-subject recurrent event clustering, verified by test output.
- [ ] 11.6 Add zero-event person-time test fixtures and verify numerical stability.

## 12. Clustering and Repeated Measurements Boundary

- [ ] 12.1 Implement Pass 0 check determining whether repeated observational rows can be collapsed to subject-level binary status, verified by test cases.
- [ ] 12.2 Route to subject-level binary engine when valid collapsing is confirmed, verified by routing test.
- [ ] 12.3 Specify cluster-level bootstrap extension interface for hierarchical clustering data, verified by design documentation.
- [ ] 12.4 Verify explicit architecture boundary keeping GLMM and GEE estimation out of scope until future dedicated OpenSpec change, verified by documentation check.

## 13. Evidence-Decision Review Engine

- [ ] 13.1 Initialize `.agents/skills/evidence-decision-review/` skill complying with `evidence-run-layout`.
- [ ] 13.2 Define evidence feature vector schema extracting decision-label-free statistical summaries, partitioning into mandatory core and optional delta-dependent attributes, verified by schema test.
- [ ] 13.3 Verify assertion that clinical decision codes and regulatory labels are strictly excluded from clustering input features, verified by unit test.
- [ ] 13.4 Implement Gower distance dissimilarity calculation for mixed numeric and categorical evidence features, safely handling missing delta features, verified by test assertions.
- [ ] 13.5 Bind historical precedent metadata to dictionary release version, delta policy version, and feature schema version, verified by unit test.
- [ ] 13.6 Implement nearest historical precedent retrieval returning matching cases with distance metrics and full decision context, verified by retrieval tests.
- [ ] 13.7 Define append-only, tamper-evident decision ledger schema recording record ID, previous record SHA-256 hash, decision state, reviewer justification markdown, actor ID, and JST timestamp.
- [ ] 13.8 Implement configurable discordance policy (neighborhood size $k$ or distance radius), presenting precedent distribution and flagging divergence as "QA Review Candidate", verified by test fixture.
- [ ] 13.9 Enforce wording contract designating divergences as "QA Review Candidates" rather than system errors or invalid states, verified by string audit.
- [ ] 13.10 Implement trajectory tracking capturing longitudinal changes in decisions across study phases or data cutoffs, verified by test script.
- [ ] 13.11 Implement bootstrap cluster stability assessment or emit explicit `NOT_ASSESSED` warning, verified by test assertion.
- [ ] 13.12 Add test demonstrating that cluster assignment alone never triggers automated regulatory actions or label modifications, verified by governance test.

## 14. Dashboard and Self-Contained Report QA

- [ ] 14.1 Structure HTML report layout with dedicated, separated columns for Effect Size, Direction, Practical Difference, and Precision, verified by visual inspection.
- [ ] 14.2 Enforce visual color palette using practical region hue (`TARGET_EXCESS`, `PRACTICAL_NEUTRAL`, `REFERENCE_EXCESS`) modulated by U-grade intensity only when primary delta is set, verified by CSS audit.
- [ ] 14.3 Verify that U3 category renders with muted, desaturated tones indicating indeterminate resolution rather than alarmist red hues, verified by visual test.
- [ ] 14.4 Render zero and sparse event diagnostic badges separately from statistical estimates, verified by report layout test.
- [ ] 14.5 Display prominent warning callout when relative risk point estimate or credible interval displays numerical instability, verified by visual inspection.
- [ ] 14.6 Audit generated HTML and verify zero external HTTP/HTTPS network dependencies (fonts, CDNs, scripts), verified by static regex scan.
- [ ] 14.7 Audit generated HTML and verify zero OS-specific local absolute paths, verified by static path scanner.
- [ ] 14.8 Implement automated structural HTML tests validating DOM element IDs and accessibility attributes, verified by test suite.
- [ ] 14.9 Perform browser visual verification using subagent or manual render to confirm responsive layout on desktop viewports.

## 15. Documentation and Ecosystem Synchronization

- [ ] 15.1 Update `AGENTS.md` with new skill dispatch guidelines, run layout contracts, and statistical separation rules, verified by file inspection.
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
- [ ] 16.4 Verify that U-grade reflects practical region resolution decisiveness and is never presented as sampling precision or clinical severity.
- [ ] 16.5 Verify strict separation of Bayesian posterior probability vs bootstrap resample frequency terminology.
- [ ] 16.6 Verify that weighted pseudo-counts and complex survey weights are rejected by independent Beta-Binomial engine.
- [ ] 16.7 Verify Safety hierarchy accounting invariants: subject deduplication and SOC count $\ne$ sum of PT counts.
- [ ] 16.8 Verify that multi-theme exploratory batch screening includes explicit multiplicity disclaimer.
- [ ] 16.9 Verify that no component triggers automated regulatory decisions or label determinations.
- [ ] 16.10 Execute complete canonical regression test suite and verify 100% test pass.
- [ ] 16.11 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [ ] 16.12 Run `git diff --check` and verify clean diff without whitespace or delimiter errors.
- [ ] 16.13 Record unresolved risks and obtain explicit Owner adjudication.

## 17. Completion and Archive Readiness Gate

- [ ] 17.1 Verify all tasks 0.1 through 16.13 have verified executable evidence.
- [ ] 17.2 Confirm zero unadjudicated Blocker or High severity QA findings.
- [ ] 17.3 Freeze and version all statistical JSON schemas (`comparative-draws-v1`, `comparative-evidence-v1`).
- [ ] 17.4 Confirm full alignment between code implementation, tests, and OpenSpec delta specifications.
- [ ] 17.5 Obtain explicit Owner sign-off accepting remaining documented operational risks.
- [ ] 17.6 Require explicit, separate authorization before invoking `/opsx-archive`.
