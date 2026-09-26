## 0. Specification and Ownership Gate

- [x] 0.1 Create `docs/Artifacts/implementation_plan_NNN_0923.md` from the approved plan and verify file existence.
- [x] 0.2 Initialize active OpenSpec change directory `openspec/changes/comparative-evidence-reporting-v3/` and verify structure.
- [x] 0.3 Populate `proposal.md`, `design.md`, delta specs, and `tasks.md` conforming to OpenSpec schema.
- [x] 0.4 Declare and verify capabilities: `pass0-analysis-routing`, `comparative-evidence-reporting`, `comparative-design-inference`, and `evidence-decision-consistency`.
- [x] 0.5 Confirm `two-way-evidence-analysis` spec remains intact for contingency-table association/residual analysis without modifications.
- [x] 0.6 Verify delta spec `specs/deterministic-r-dependencies/spec.md` references `tests/run_regression_suite.R` as the dynamic canonical registry.
- [x] 0.7 Verify integration contract with `evidence-run-layout` ensuring all new skills use `evidence_runs/<skill_slug>/run_<canonical_id>[_N]/`.
- [x] 0.8 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [x] 0.9 Obtain explicit Owner approval before transitioning to implementation phase.

## 1. Pass 0 Consultation Gateway

- [x] 1.1 Extend Pass 0 schema with domain, estimand, analysis unit, target/reference, design, practical-difference mode, hierarchy, reporting purpose, and decision-review flag, verifying against schema test.
- [x] 1.2 Implement inspection for non-integer counts, verifying warning/error emission on float inputs.
- [x] 1.3 Add duplicate subject diagnostic checks within PT and SOC, reporting duplication counts and proposing standard counting rules without silent data transformation.
- [x] 1.4 Detect optional column patterns (weight, matched-set, cluster, person-time, SOC/PT, study) and verify detection in summary output.
- [x] 1.5 Implement deterministic routing logic outputting `routing_decision.json` with input hashes, configuration hashes, target engine slug, and inferential semantics.
- [x] 1.6 Support explicit `practical_difference.mode = "none"` with `primary_delta = null` as a valid non-blocking state, while requiring explicit confirmation for ambiguous causal estimands (ATE vs ATT).
- [x] 1.7 Enforce fail-fast guard intercepting complex survey sampling weights with code `UNSUPPORTED_SURVEY_DESIGN` and preventing weighted pseudo-counts from entering the independent Beta-Binomial engine.
- [x] 1.8 Add comprehensive Pass 0 test suite and verify `Rscript tests/test_pass0_routing.R` passes.

## 2. Shared Schemas and Contrast Engine

- [x] 2.1 Implement logical runtime schema `comparative-draws-v1.json` supporting `inferential_semantics = "posterior" | "bootstrap"` with ephemeral in-memory management.
- [x] 2.2 Implement permanent deliverable schema `comparative-evidence-v1.json` supporting explicit point estimate sources (`estimate.source = "posterior_median" | "observed_sample_estimate"`) and nested intervals (`interval: { method = "posterior_eti" | "bootstrap_percentile", ... }`).
- [x] 2.3 Implement shared contrast transformation engine in `.agents/shared/comparative_contrasts.R` and verify unit tests.
- [x] 2.4 Implement risk difference (RD) and incidence rate difference (IRD) draw transformations, verified by mathematical test cases.
- [x] 2.5 Implement relative risk (RR) and incidence rate ratio (IRR) draw transformations, verified by mathematical test cases.
- [x] 2.6 Implement excess per natural unit conversions with domain-aware field names (`additional_subjects_per_100_treated`, `additional_events_per_100_person_years`).
- [x] 2.7 Implement direction support metric, labeling Bayesian outputs as $P(RD > 0)$ and bootstrap outputs as `bootstrap_support_fraction_rd_gt_zero`.
- [x] 2.8 Implement configurable delta profile evaluations over user-specified or non-normative default threshold vectors, asserting monotonic properties.
- [x] 2.9 Implement practical region support values ($q_T, q_N, q_R$) under container `practical_region_support` across canonical regions (`target_excess`, `practical_neutral`, `reference_excess`), verifying $q_T + q_N + q_R = 1.0$ invariant.
- [x] 2.10 Implement Practical-Region Resolution Grade (U0–U3) from $C = \max(q_T, q_N, q_R)$, documenting that U-grade reflects region classification decisiveness of the active uncertainty distribution rather than generic sampling precision.
- [x] 2.11 Implement separate continuous precision metrics (`rd_interval_width`, `log_rr_interval_width`, effective sample size) and verify presence in JSON output.
- [x] 2.12 Enforce strict terminology separation: "credible interval (ETI)" and "posterior probability" for Bayesian posteriors vs "bootstrap percentile interval" and "bootstrap support fraction" for bootstrap replicates, verified by linting tests.
- [x] 2.13 Implement zero and sparse count diagnostic badges (`ZERO_REFERENCE`, `ZERO_BOTH`, `SPARSE_EVENTS`) and continuous instability metrics (`log_rr_interval_width`).
- [x] 2.14 Add schema invariant test suite and verify `Rscript tests/test_comparative_schemas.R` passes.

## 3. Independent Jeffreys Binary Engine

- [x] 3.1 Implement `.agents/shared/independent_beta_binomial.R` and verify file creation.
- [x] 3.2 Add assertion enforcing strictly non-negative integer counts for events and positive totals ($n > 0$), rejecting $n=0$ cohorts.
- [x] 3.3 Validate $0 \le x_T \le n_T$ and $0 \le x_R \le n_R$ bounds, verified by unit assertions.
- [x] 3.4 Implement Jeffreys prior $\text{Beta}(0.5, 0.5)$ sampling, verified against theoretical posterior quantile benchmarks.
- [x] 3.5 Support deterministic pseudo-random seeds for exact uncertainty draw reproducibility, verified by seed equality tests.
- [x] 3.6 Generate target and reference posterior summaries (median, mean, 95% ETI), setting `estimate.source = "posterior_median"`, verified by numerical assertions.
- [x] 3.7 Output standardized uncertainty draws conforming to the logical `comparative-draws-v1` interface, verified by in-memory schema validator.
- [x] 3.8 Implement detection of zero-reference counts causing infinite theoretical expectation for $RR$, setting `mean = null` and `mean_is_finite = false`.
- [x] 3.9 Enforce safeguard preventing empirical Monte-Carlo mean of $RR$ from being reported when theoretical expectation diverges, verified by unit test.
- [x] 3.10 Add relative risk continuous instability diagnostics (`log_rr_interval_width`, `rr_interval_fold_range`), verified by test assertions.
- [x] 3.11 一様事前分布 $\text{Beta}(1.0, 1.0)$ との感度比較を `prior_sensitivity.mode = "zero_cell" | "off" | "explicit"`（既定 `"zero_cell"`）で制御し、RD 中央値差・方向支持差・U-grade の変化を記録する。未承認の二値 `robust` 判定を出力せず、主解析の U-grade を変更しないことをテストで確認する。
- [x] 3.12 Implement golden regression cases (`3/100 vs 0/100`, `0/100 vs 0/100`, `30/100 vs 20/100`, `3/30 vs 30/300`, `1/200 vs 0/1000`, `1/200 vs 2/1000`, `0/200 vs 2/1000`) and verify all outputs.
- [x] 3.13 Add tests asserting delta-profile monotonicity and $q_T + q_N + q_R = 1.0$ within floating point tolerance.
- [x] 3.14 Test that `primary_delta = null` disables practical classification categories and visual hue assignment, verified by unit test.

## 4. `vcd-categorical-reporting` Skill Revival

- [x] 4.1 Update skill manifest to transition `vcd-categorical-reporting` from deprecated to active comparative evidence skill.
- [x] 4.2 Rewrite `.agents/skills/vcd-categorical-reporting/SKILL.md` to specify comparative evidence reporting workflow and verify docs.
- [x] 4.3 Preserve historical reporting templates under explicit legacy compatibility namespaces and verify legacy tests continue passing.
- [x] 4.4 Add multi-theme long-format dataset ingestion adapter and verify tabular parsing tests.
- [x] 4.5 Add support for explicit pairwise contrast specifications across multiple study groups, verified by unit tests.
- [x] 4.6 Implement contrast generation for $>2$ groups defaulting to reference-vs-all and requiring explicit request for all-pairs, verified by unit test.
- [x] 4.7 Generate canonical output artifacts `comparative_evidence.json` and `comparative_summary.csv`, verified by schema validation.
- [x] 4.8 Implement self-contained offline Markdown and HTML summary reports complying with zero-external-asset rules and verify browser rendering.
- [x] 4.9 Retain raw event counts ($x/n$), sample sizes, and optional SAS PROC FREQ / Fisher exact test compatibility columns in output.
- [x] 4.10 Implement narrative guard in AI reporting template prohibiting claims that "non-significance implies equivalence", verified by template test.
- [x] 4.11 Implement narrative guard prohibiting claims that posterior direction implies causal superiority, verified by template test.
- [x] 4.12 Enforce visual encoding rule: cell background hue SHALL NOT be determined by posterior direction alone, verified by CSS/HTML audit.
- [x] 4.13 Add mandatory exploratory screening disclaimer in multi-theme batch reports stating posterior probabilities do not guarantee familywise error rate control.

## 5. Clinical Safety Adapter

- [x] 5.1 Define canonical Safety reporting hierarchy as Primary SOC $\rightarrow$ PT in `.agents/shared/safety_adapter.R`, keeping HLGT and HLT as optional secondary drill-downs.
- [x] 5.2 Require MedDRA version provenance and dictionary release metadata in input analysis configuration, verified by validation test.
- [x] 5.3 Enforce Primary SOC mapping as the standard aggregation level, verified by hierarchy test fixtures.
- [x] 5.4 Deduplicate subjects within PT so that an individual with multiple occurrences of the same PT is counted once, verified by test assertion.
- [x] 5.5 Deduplicate subjects within SOC so that an individual experiencing multiple distinct PTs within the same SOC is counted once in that SOC, verified by test fixture.
- [x] 5.6 Assert that unique subject count in a SOC never exceeds the group denominator, verified by automated assertion.
- [x] 5.7 Assert and verify that SOC incidence count is never calculated by summing child PT incident counts, verified by unit test.
- [x] 5.8 Support study-specific output stratification as canonical, designating multi-study pooled aggregations as `descriptive_pooled` without asserting unmodeled between-study homogeneity.
- [x] 5.9 Implement clinical safety domain labels (`additional_subjects_per_100_treated`, SOC, PT, Incidence Proportion, RR, U-grade) in reports.
- [x] 5.10 Manage reciprocal-RD (NNH) rendering using `reciprocal_status` (`STABLE_DIRECTION`, `SIGN_AMBIGUOUS`, `RD_NEAR_ZERO`, `NOT_INTERPRETABLE`), suppressing naive intervals when the RD interval crosses zero.
- [x] 5.11 Add Safety regression test fixture featuring recurrent adverse events across multiple PTs within a single SOC, verified by test script.
- [x] 5.12 Add Safety zero-cell adverse event test fixture and verify safe report rendering.

## 6. RWD and Prescription Adapters

- [x] 6.1 Implement generic hierarchical adapter supporting arbitrary parent-child theme structures (`parent_theme -> item_theme`), verified by unit test.
- [x] 6.2 Implement Real-World Data (RWD) clinical context extension mapping diagnoses and procedures, verified by test fixture.
- [x] 6.3 Implement Prescription/Formulary analysis context extension mapping drug classes to active ingredients, verified by test fixture.
- [x] 6.4 Implement domain-specific presentation decorators without altering underlying canonical statistical fields, verified by output validation.
- [x] 6.5 Add statistical invariance test asserting that identical counts passed through Safety, RWD, and Prescription adapters yield identical comparative evidence statistics, verified by `Rscript tests/test_domain_invariance.R`.

## 7. Practical Difference and Uncertainty Policy

- [x] 7.1 Implement default `primary_delta = null` (`mode: "none"`) configuration, verified by test assertion.
- [x] 7.2 Implement natural-unit conversions for delta specifications (`per_100`, `per_1000`, absolute probability), verified by unit tests.
- [x] 7.3 Implement explicit prespecified delta evaluation mode, verified by parameter configuration test.
- [ ] 7.4 [DEFERRED / OUT-OF-SCOPE] Implement versioned departmental policy mode for delta boundaries (Owner-adjudicated deferred to future policy change; prototype helper get_departmental_delta_policy() retained in R shared library).
- [x] 7.5 Ensure delta profile matrix is computed and archived even when no primary delta is approved, verified by JSON schema validation.
- [x] 7.6 Implement simulation utility to evaluate candidate U0–U3 uncertainty thresholds under various sample sizes and base rates.
- [x] 7.7 Validate provisional U0–U3 cutoff parameters against synthetic sparse and imbalanced cohorts, documenting recommendations.
- [x] 7.8 Verify all generated documentation and report tooltips explicitly clarify that U-grade reflects region classification decisiveness of the active uncertainty distribution, not sampling precision or clinical severity.

## 8. Design-Aware Inference Engine: 1:1 Matched Pairs

- [x] 8.1 Initialize `.agents/skills/comparative-design-analysis/` skill complying with `evidence-run-layout`.
- [x] 8.2 Implement 4-cell paired contingency table extractor ($(n_{11}, n_{10}, n_{01}, n_{00})$) from matched pair datasets, verified by unit test.
- [x] 8.3 Implement multinomial Dirichlet sampler with prior $\boldsymbol{\alpha} = (0.5, 0.5, 0.5, 0.5)$ for cell probabilities, verified by test assertions.
- [x] 8.4 Derive marginal risk draws $p_T = p_{11} + p_{10}$ and $p_R = p_{11} + p_{01}$ across posterior samples, verified by unit test.
- [x] 8.5 Verify mathematical invariant $RD = p_{10} - p_{01}$ across draws in unit test.
- [x] 8.6 Generate standardized uncertainty draws object conforming to `comparative-draws-v1` with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval: { method = "posterior_eti" }`.
- [x] 8.7 Implement matched-pair golden test cases and verify numerical accuracy against analytical reference solutions.
- [x] 8.8 Record matched-pair sample size, concordant, and discordant pair counts in output metadata, verified by JSON output inspection.
- [x] 8.9 Define `odds_ratio` as the discordant-pair matched OR $p_{10}/p_{01}$, retain $p_{11}p_{00}/(p_{10}p_{01})$ as `intra_pair_association_or`, and verify both with fixed-seed tests.

## 9. Design-Aware Inference Engine: 1:k Matched Sets

- [x] 9.1 Implement cluster bootstrap sampler for 1:k matched sets in `.agents/shared/matched_set_inference.R` using atomic set resampling without matching replacement.
- [x] 9.2 Implement set-weighted marginal ATT estimator formulas $\hat{p}_T = \frac{1}{J}\sum_{j=1}^J Y_{Tj}$ and $\hat{p}_R = \frac{1}{J}\sum_{j=1}^J \left(\frac{1}{k_j}\sum_{\ell=1}^{k_j} Y_{Rj\ell}\right)$ computed on observed sample (`estimate.source = "observed_sample_estimate"`), verified by unit tests.
- [x] 9.3 Record matching ratio, caliper, with/without replacement status, and matched/discarded patient counts in metadata, verified by test.
- [x] 9.4 Compute and record post-match covariate balance metrics (standardized mean differences), verified by unit tests.
- [x] 9.5 Emit output draws with `inferential_semantics = "bootstrap"` and `interval: { method = "bootstrap_percentile" }`, verifying downstream narrative adaptation.
- [x] 9.6 Add bootstrap reproducibility and seed consistency tests, verified by regression test pass.
- [x] 9.7 Require unique subject identifiers (`subject_id_col`) across sets and validate non-replacement matching without duplicate subjects, verified by fail-fast test.
- [x] 9.8 Implement ATT-weighted control variance for SMD, classify zero-variance cases into `ZERO_VARIANCE_ZERO_DIFFERENCE` or `ZERO_VARIANCE_NONZERO_DIFFERENCE`, and remove misleading `smd_unmatched`, verified by balance tests.
- [x] 9.9 Separate raw descriptive cohort counts (`matched_set.raw_*_counts`) from ATT-weighted reference risk (`reference_cohort.estimate_semantics = "att_set_weighted_risk"`), verified by output schema validation.
- [x] 9.10 Implement governed zero-denominator RR policy: record `rr_bootstrap_diagnostics`, suppress RR interval (`null`) if any replicate has $p_R^*=0$, and suppress RR completely (`null`) with `diagnostic = "ZERO_REFERENCE_RISK"` if observed reference risk is 0, verified by test cases.
- [x] 9.11 Expose explicit `estimand = "ATT"` and `bootstrap_scope: { type = "conditional_on_fixed_matched_sets", rematching_within_replicate = false, propensity_model_refit = false }` in evidence and draws outputs, verified by schema validation.
- [x] 9.12 Add comprehensive unit tests (T1–T9) covering zero-variance SMD, ATT-weighted variance, partial zero RR suppression, subject deduplication, argument validation, and schema conformance, verified by test suite.
- [x] 9.13 Implement RR semantic atomicity: atomically suppress RR-derived precision metrics (`log_rr_interval_width` and `rr_interval_fold_range`) whenever relative risk is suppressed (zero-reference or partial-undefined replicates), verified by T10 test.
- [x] 9.14 Normalize draw-count contract: unify `num_draws` minimum to 10 across runtime validator, shared contrast engine, and JSON schema, verified by T12 test and schema validation.
- [x] 9.15 Implement finite-value runtime validation: enforce `is.finite()` across `caliper`, `discarded_target`, `discarded_reference`, `num_draws`, `seed`, `level`, and covariates, verified by fail-fast tests.
- [x] 9.16 Enforce scale-invariant SMD zero-variance policy: eliminate absolute `1e-12` cutoff in favor of exact zero variance classification ($s_{pooled}=0$), verified by unit scaling invariance test (T11).
- [x] 9.17 Harden schema governance: require `raw_target_counts` and `raw_reference_counts` in evidence schema, require metadata and enforce enum in draws schema, and add negative schema tests.
- [x] 9.18 Restore seed reproducibility regression test: verify identical target/reference draws and RD interval for identical seed (T13).
- [x] 9.19 Clarify documentation and citation: update `design.md`, `spec.md`, and `SKILL.md` to accurately cite Abadie & Imbens (2008) regarding conditional fixed-set scope versus matching estimator bootstrap.
- [x] 9.20 Execute verification gate: confirm 100% pass across matched set tests, schema validation, and full regression suite.

## 10. Design-Aware Inference Engine: IPTW

- [x] 10.1 Implement patient-level bootstrap resampling for IPTW in `.agents/shared/iptw_inference.R` using reproducible serial resampling.
- [x] 10.2 Refit the propensity score model inside *every* bootstrap replicate (`iptw_mode = "refit_ps"`), verified by simulation test.
- [x] 10.3 Implement exact weight formulas for unstabilized ATE ($w_i = A_i/e_i + (1-A_i)/(1-e_i)$), unstabilized ATT ($w_i = A_i + (1-A_i)e_i/(1-e_i)$), stabilized ATE, and scaled ATT (`att_weight_scaling.mode = "conventional" | "marginal_odds_scaled"`).
- [x] 10.4 Implement percentile weight truncation (e.g. 1st / 99th percentiles) applied to final computed weights separately by treatment arm, verified by parameter configuration tests.
- [x] 10.5 Support explicit ATE and ATT estimand targets with `estimate.source = "observed_sample_estimate"`, verified by test cases.
- [x] 10.6 Compute weighted marginal event proportions across bootstrap replicates, verified by test assertions.
- [x] 10.7 Compute and record effective sample size (ESS) for target and reference groups, verified by output validation.
- [x] 10.8 Record weight distribution quantiles and maximum weight, issuing warning if extreme weights occur, verified by an extreme-weight diagnostic assertion.
- [x] 10.9 Record before and after weighting standardized mean differences (SMD) across baseline covariates, verified by test output.
- [x] 10.10 Record raw/effective positivity and propensity score overlap diagnostics, verified by overlap and no-overlap tests.
- [x] 10.11 Implement convergence monitoring with public configurable failure threshold, failing fast if failure rate exceeds threshold, verified by threshold metadata and deterministic failure-path test.
- [x] 10.12 Verify that non-integer pseudo-counts from IPTW are rejected by the independent Beta-Binomial engine, verified by unit test.
- [x] 10.13 Verify that reports generated from IPTW use bootstrap percentile interval and resampling terminology, while Bayesian reports retain posterior/ETI terminology, verified by narrative integration tests.
- [x] 10.14 Govern propensity-score clamping with configurable bounds, raw/effective summaries, clipping counts, and raw-score overlap diagnostics.
- [x] 10.15 Separate weighted cohort risks from raw counts and preserve raw counts only under `iptw.raw_patient_counts`.
- [x] 10.16 Validate supplied subject identifiers and reject missing or repeated subject rows.
- [x] 10.17 Record refit mode, truncation, ATT scaling, propensity model/covariates, PS boundary policy, and convergence threshold in IPTW draw metadata; validate schema positive and negative cases.
- [x] 10.18 Reject ambiguous ATT stabilization configuration; `stabilization = TRUE` requires marginal-odds scaling.
- [x] 10.R12 Reconcile Repair #2 documentation with canonical Repair #1 mapping in `implementation_plan_009_0924.md`; preserve 0.05 failure-rate default, raw/clamped PS terminology, no pseudo-replication warning, and no unapproved small-cell masking.
- [x] 10.R13 Make design-aware report overrides authoritative for raw descriptive counts and ESS, require count provenance match, label ESS separately, and suppress Fisher compatibility by default.
- [x] 10.R15 Require IPTW provenance fields consistently in evidence and draws schemas, including bootstrap clipping diagnostics.
- [x] 10.R16 Enforce JSON Schema `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, and finite-number validation in the local test validator.
- [x] 10.R17 Verify same-source IPTW evidence/report integration, provenance mismatch rejection, ESS display, and Fisher suppression.
- [x] 10.R18 Summarize propensity-score clipping across successful bootstrap refits in evidence and draws.
- [x] 10.R19 Run the targeted tests, canonical regression suite, strict OpenSpec validation, and diff checks; record the execution evidence.
- [x] 10.R20 Post-acceptance: require raw/effective IPTW positivity summaries and strict PS boundary `upper < 1` in evidence/draw schemas, with positive and negative schema fixtures.
- [x] 10.R21 Post-acceptance: correct the Batch 011 archive summary's Section 9 method wording and canonical matched-pair paths without changing archived source artifacts.
- [x] 10.R22 Post-acceptance: run schema tests, the canonical regression suite, strict OpenSpec validation, static checks, and diff checks; record execution evidence.

Repair #2 item 10.R14 (small-cell presentation masking) is deferred pending explicit Owner policy decision and is not part of this Change.

## 11. Person-Time Incidence Rate Engine

- [x] 11.1 Implement conjugate Gamma-Poisson rate model in `.agents/shared/person_time_rate.R` using shape-rate parameterization $\text{Gamma}(x_g + 0.5, T_g)$ under Jeffreys prior, verified by unit test.
- [x] 11.2 Generate target and reference Poisson incidence rate draws from posterior Gamma distributions with `inferential_semantics = "posterior"`, `estimate.source = "posterior_median"`, and `interval: { method = "posterior_eti" }`.
- [x] 11.3 Feed rate draws into shared contrast engine to derive incidence rate difference (IRD) and incidence rate ratio (IRR), verified by unit tests.
- [x] 11.4 Record exposure units (person-years, person-months), parameterization (`shape_rate`), and denominator metadata in output, verified by schema validation.
- [x] 11.5 Document limitations regarding constant hazard and lack of within-subject recurrent event clustering, verified by test output.
- [x] 11.6 Add zero-event person-time test fixtures and verify numerical stability.
- [x] 11.R7 Post-acceptance: bind person-time draw semantics to posterior and preserve legacy draw validity.
- [x] 11.R8 Post-acceptance: enforce person-year/person-month exposure and rate unit pairs in draw and rate-evidence schemas.
- [x] 11.R9 Post-acceptance: enforce atomic zero-reference IRR mean, finiteness flag, and diagnostic state in the rate-evidence schema.
- [x] 11.R10 Post-acceptance: require positive persisted person-time draw arrays and explicit null ephemeral arrays.
- [x] 11.R11 Reconcile assertion and script counts, run targeted/full regression, strict OpenSpec, Draft-07, and diff checks; record the results.

## 12. Clustering and Repeated Measurements Boundary

- [x] 12.1 Implement Pass 0 check determining whether repeated observational rows can be collapsed to subject-level binary status, verified by test cases.
- [x] 12.2 Route to subject-level binary engine when valid collapsing is confirmed, verified by routing test.
- [x] 12.3 Specify cluster-level bootstrap extension interface for hierarchical clustering data, verified by design documentation.
- [x] 12.4 Verify explicit architecture boundary keeping GLMM and GEE estimation out of scope until future dedicated OpenSpec change, verified by documentation check.

## 12.R QA-0001 Cycle 1 Repair (Section 12)

- [x] 12.R1 Make dependency structure explicit via configured `cluster_cols` / `matched_cols`, merge with expanded heuristic aliases, and require `no_other_subject_dependence_confirmed` (QA0001-H01).
- [x] 12.R2 Emit canonical `engine_input` handoff and prove executable call into `run_independent_beta_binomial()` (QA0001-M01).
- [x] 12.R3 Add `schemas/pass0-routing-v1.json` covering repeated-row counts and `engine_input` (QA0001-M02).
- [x] 12.R4 Add runtime/Draft-07 parity fixtures for `pass0-config-v1` and document runtime-only invariants (QA0001-M03).
- [x] 12.R5 Extend pure-R Draft-07 validator with `minLength` / `uniqueItems` and negative fixtures for empty/duplicate dependency columns (QA0001.R6).
- [x] 12.R6 Document length-1 R character as native form with canonical JSON array serialization and round-trip proof (QA0001.R7).

## 13. Evidence-Decision Review Engine

- [x] 13.1 Initialize `.agents/skills/evidence-decision-review/` skill complying with `evidence-run-layout`.
- [x] 13.2 Define evidence feature vector schema extracting decision-label-free statistical summaries, partitioning into mandatory core and optional delta-dependent attributes, verified by schema test.
- [x] 13.3 Verify assertion that clinical decision codes and regulatory labels are strictly excluded from clustering input features, verified by unit test.
- [x] 13.A.R1 Complete evidence-decision-review run_meta lifecycle and shared skill allowlist (QA H13A-01).
- [x] 13.A.R2 Constrain clustering_feature_keys to canonical allowlist enum (QA M13A-01).
- [x] 13.A.R3 Make delta_dependent present-state atomic in schema and runtime (QA M13A-02).
- [x] 13.A.R4 Record targeted, run-isolation, and full regression evidence (QA M13A-03).
- [x] 13.A.R5 Bind present=true to complete delta clustering key set in schema and tests (QA M13A-02 residual).
- [x] 13.4 Implement Gower distance dissimilarity calculation for mixed numeric and categorical evidence features using versioned reference ranges (`frozen_reference_range`), applying bounded clipping ($d_j = \min(1, |x_i-x_j|/R_j)$) and logging `GOWER_REFERENCE_RANGE_EXCEEDED` on range overflow.
- [x] 13.4.R1 Compute overflow via contribution clipping only (no input clip); exact numeric fixtures including 5 vs 3 (QA H13.4-01).
- [x] 13.4.R2 Fail-Fast `FROZEN_RANGE_MISSING_FEATURE` when selected/shared keys lack frozen-range entries (QA M13.4-01).
- [x] 13.4.R3 Validate frozen range / schema / key coverage in `gower_distance_matrix` before diagonal shortcut, including n=1 (QA M13.4-02).
- [x] 13.4.R4 Re-run Gower, feature-extract, run-isolation, and full regression gates after R1–R3.
- [x] 13.5 Implement hierarchical agglomerative clustering over Gower distance matrix (average linkage default, fixed_k partition, exploratory-only), verified by clustering test.
- [x] 13.6 Implement optional standardized K-means clustering strictly restricted to continuous features with input scaling validation, verified by test suite.
- [x] 13.6.R1 Validate distinct standardized case count before `stats::kmeans` (`KMEANS_INSUFFICIENT_DISTINCT_CASES`), verified by duplicate-profile fixtures.
- [x] 13.7 Bind historical precedent metadata to dictionary release version, delta policy version, and feature schema version, verified by unit test.
- [x] 13.7.R1 Enforce canonical nested `evidence-feature-v1` on query/historical cases (`assert_evidence_feature_v1` + schema `$ref`), verified by negative fixtures.
- [x] 13.7.R1b Runtime/schema parity for `delta.present` boolean and `source.contrast_id`/`theme` string|null, verified by paired Draft-07 negatives.
- [x] 13.8 Implement nearest historical precedent retrieval returning matching cases with distance metrics and full decision context, verified by retrieval tests.
- [x] 13.8.R1 Separate `version_compatible` from `distance_scorable`; feature-schema mismatch is non-scorable without aborting retrieval, verified by mixed-library tests.
- [x] 13.9 Define append-only, tamper-evident decision ledger schema recording record ID, previous record SHA-256 hash, decision state, reviewer justification markdown, actor ID, and JST timestamp.
- [x] 13.9.R1 Enforce exact ledger record field set (reject extra/missing/duplicate/unnamed), verified by runtime + Draft-07 negatives.
- [x] 13.9.R2 Enforce canonical `YYYY-MM-DD HH:MM:SS JST` for `decided_at_jst` in runtime and schema pattern.
- [x] 13.10 Implement configurable discordance policy (neighborhood size $k$ or distance radius), presenting precedent distribution and flagging divergence as "QA Review Candidate", verified by test fixture.
- [x] 13.10.R1 / 13.11.R1 Scope wording audit to system advisory fields only (do not scan decision labels such as REJECT/REJECTED), verified by fixtures.
- [x] 13.11 Enforce wording contract designating divergences as "QA Review Candidates" rather than system errors or invalid states, verified by string audit.
- [x] 13.12 Implement trajectory tracking capturing longitudinal changes in decisions across study phases or data cutoffs, verified by test script.
- [x] 13.12.R1 Call `verify_decision_ledger()` before `trajectory_from_ledger()` derivation, verified by tamper/broken-chain negatives.
- [x] 13.13 Implement cluster stability assessment via patient-level bootstrap co-clustering when individual rows are present, or emit explicit `stability_status = "NOT_ASSESSED"` with reason `CROSS_THEME_DEPENDENCE_UNAVAILABLE` when only term summaries are available.
- [x] 13.13.R1 Require `patient_rows` + `refit_features` + `frozen_range` for ASSESSED; remove fixed-distance unit resampling, verified by cross-theme subject fixtures.
- [x] 13.13.R2 Bind stability provenance to target HAC result (n/k/linkage/labels), verified by incompatible attach negatives.
- [x] 13.13.R3 Enforce canonical `evidence-feature-v1` on `refit_features` outputs via `assert_evidence_feature_v1` before Gower, verified by non-canonical negatives.
- [x] 13.14 Add test demonstrating that cluster assignment alone never triggers automated regulatory actions or label modifications, verified by governance test.

## 14. Dashboard and Self-Contained Report QA

- [x] 14.1 Structure HTML report layout with dedicated, separated columns for Effect Size, Direction, Practical Difference, and Precision, verified by visual inspection.
- [x] 14.2 Enforce visual color palette using practical region hue (`target_excess`, `practical_neutral`, `reference_excess`) modulated by U-grade intensity only when primary delta is set, verified by CSS audit.
- [x] 14.3 Verify that U3 category renders with muted, desaturated tones indicating indeterminate resolution rather than alarmist red hues, verified by visual test.
- [x] 14.4 Render zero and sparse event diagnostic badges separately from statistical estimates, verified by report layout test.
- [x] 14.5 Display prominent warning callout when relative risk point estimate or uncertainty interval displays numerical instability, verified by visual inspection.
- [x] 14.6 Audit generated HTML and verify zero external HTTP/HTTPS network dependencies (fonts, CDNs, scripts), verified by static regex scan.
- [x] 14.7 Audit generated HTML and verify zero OS-specific local absolute paths, verified by static path scanner.
- [x] 14.8 Implement automated structural HTML tests validating DOM element IDs and accessibility attributes, verified by test suite.
- [x] 14.9 Perform browser visual verification using subagent or manual render to confirm responsive layout on desktop viewports.
- [x] 14.10 Implement self-contained sortable Comparative Evidence Summary table: click/keyboard ascending-descending sort, `aria-sort` state, explicit machine-readable sort keys, stable ordering, finite-before-N/A semantics, U-Grade ordinal sorting (`U0 < U1 < U2 < U3 < NONE`), preservation of existing badges/colors/accessibility, zero external dependencies, and browser interaction verification; rerun affected Section 16 regression/QA gates before archive readiness.
- [x] 14.11 Add Excel-compatible dashboard CSV export for all rows and current filtered/sorted rows using canonical summary data, UTF-8 BOM, RFC4180-safe quoting, full canonical columns, and no statistical recomputation; verify exported row order/count against the dashboard.
- [x] 14.12 Add accessible multi-select filters for Theme, Practical Region/U-Grade, and Diagnostic Badges with OR-within-group / AND-across-group semantics, visible-row count, reset control, safe Japanese/hostile-label handling, and composition with existing sorting.
- [x] 14.13 Add a default-collapsed mathematical and usage guide using native HTML details/summary plus self-contained MathML for RD, RR, interval semantics, direction support, practical regions, U-Grade, precision/ESS, diagnostics, and multiplicity guidance; keep zero external assets and synchronize meanings with the Markdown report.
- [x] 14.14 Perform integrated browser/CSV/accessibility QA for Tasks 14.11-14.13 using a new coherent visual QA run, verify filter+sort composition, filtered CSV contents/order, accordion interaction, no layout regression, manifest/hash consistency, then rerun Section 16 regression and independent QA before Section 17.

## 15. Documentation and Ecosystem Synchronization

- [x] 15.1 Update `AGENTS.md` with new skill dispatch guidelines, run layout contracts, and statistical separation rules, verified by file inspection.
- [x] 15.2 Update `README.md` introducing comparative evidence reporting and design-aware capabilities, verified by markdown check.
- [x] 15.3 Update `docs/reference/skill_responsibilities.md` with updated boundary matrices, verified by documentation review.
- [x] 15.4 Update `.agents/skills/vcd-pass0-consultation/SKILL.md` documenting new routing questions and parameters.
- [x] 15.5 Update `.agents/skills/vcd-categorical-reporting/SKILL.md` reflecting comparative reporting capabilities.
- [x] 15.6 Document newly created skills (`comparative-design-analysis`, `evidence-decision-review`) in skill guides.
- [x] 15.7 Explicitly mark historical reporting references in archive files as legacy, verified by documentation scan.
- [x] 15.8 Verify that historical archive artifacts remain untouched except where necessary for pointer reconciliation.
- [x] 15.9 Run documentation cross-link consistency check verifying all internal links use relative paths, verified by link auditor.

## 16. Independent QA and Regression Verification Gate

- [x] 16.1 Conduct blind-first independent QA review reading OpenSpec and code/tests prior to implementer narrative review.
- [x] 16.2 Mathematically verify zero-cell behavior: median + quantile interval reported, `mean = null`, `mean_is_finite = false` when $x_R = 0$.
- [x] 16.3 Verify practical difference delta semantics: `primary_delta = null` disables classification and color cues.
- [x] 16.4 Verify that U-grade reflects practical region resolution decisiveness of active uncertainty distribution and is never presented as sampling precision or clinical severity.
- [x] 16.5 Verify strict separation of Bayesian posterior ETI vs bootstrap percentile interval terminology across schemas and reports.
- [x] 16.6 Verify that weighted pseudo-counts and complex survey weights are rejected by independent Beta-Binomial engine.
- [x] 16.7 Verify Safety hierarchy accounting invariants: subject deduplication and SOC count $\ne$ sum of PT counts.
- [x] 16.8 Verify that multi-theme exploratory batch screening includes explicit multiplicity disclaimer.
- [x] 16.9 Verify that no component triggers automated regulatory decisions or label determinations.
- [x] 16.10 Execute complete canonical regression test suite and verify 100% test pass.
- [x] 16.11 Run `openspec validate comparative-evidence-reporting-v3 --strict --json` and verify 0 validation errors.
- [x] 16.12 Run `git diff --check` and verify clean diff without whitespace or delimiter errors.
- [x] 16.13 Record unresolved risks and obtain explicit Owner adjudication.

## 17. Completion and Archive Readiness Gate

- [x] 17.1 Verify all in-scope tasks 0.1 through 16.13 have verified executable evidence, excluding Owner-adjudicated deferred Task 7.4.
- [x] 17.2 Confirm zero unadjudicated Blocker or High severity QA findings.
- [x] 17.3 Freeze and version all statistical JSON schemas (`comparative-draws-v1`, `comparative-evidence-v1`).
- [x] 17.4 Confirm full alignment between code implementation, tests, and OpenSpec delta specifications.
- [x] 17.5 Obtain explicit Owner sign-off accepting remaining documented operational risks.
- [x] 17.6 Require explicit, separate authorization before invoking `/opsx-archive` (Owner authorized 2026-09-26).
