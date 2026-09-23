# Tasks: Comparative Evidence Reporting v3

status: proposed  
change: `comparative-evidence-reporting-v3`

> Task completion requires executable evidence. Checkboxes MUST NOT be marked complete from code inspection alone where runtime verification is applicable.

## 0. Specification and ownership gate

- [ ] 0.1 Create `docs/Artifacts/implementation_plan_<NNN>_0923.md` from the approved implementation plan.
- [ ] 0.2 Create active OpenSpec change `openspec/changes/comparative-evidence-reporting-v3/`.
- [ ] 0.3 Create `proposal.md`, `design.md`, delta specs, and `tasks.md`.
- [ ] 0.4 Define new capabilities:
  - [ ] `pass0-analysis-routing`
  - [ ] `comparative-evidence-reporting`
  - [ ] `comparative-design-inference`
  - [ ] `evidence-decision-consistency`
- [ ] 0.5 Confirm `two-way-evidence-analysis` remains the contingency-table association/residual-analysis spec and is not repurposed.
- [ ] 0.6 Run `openspec validate --strict`.
- [ ] 0.7 Obtain Owner approval before implementation.

## 1. Pass 0 Consultation Gateway

- [ ] 1.1 Extend Pass 0 schema with domain, estimand, analysis unit, target/reference, design, practical-difference mode, hierarchy, reporting purpose, and decision-review flag.
- [ ] 1.2 Add inspection for integer/non-integer counts.
- [ ] 1.3 Add duplicate subject diagnostics.
- [ ] 1.4 Detect optional weight, matching-set, cluster, person-time, SOC/PT, study columns.
- [ ] 1.5 Generate `routing_decision.json`.
- [ ] 1.6 Require explicit state for material ambiguous choices: primary estimand, ATE/ATT, primary delta, regulatory reporting purpose.
- [ ] 1.7 Add fail-fast when a weighted analysis would otherwise be routed to Beta-Binomial.
- [ ] 1.8 Add Pass 0 routing tests.

## 2. Shared schemas and contrast engine

- [ ] 2.1 Add schema `comparative-draws-v1`.
- [ ] 2.2 Add schema `comparative-evidence-v1`.
- [ ] 2.3 Implement one shared contrast engine.
- [ ] 2.4 Implement RD/IRD.
- [ ] 2.5 Implement RR/IRR.
- [ ] 2.6 Implement excess-per-natural-unit.
- [ ] 2.7 Implement direction support.
- [ ] 2.8 Implement delta profile.
- [ ] 2.9 Implement H/N/B probabilities only when `primary_delta` exists.
- [ ] 2.10 Implement configurable U0–U3 presentation classification.
- [ ] 2.11 Implement `inferential_semantics=posterior|bootstrap`.
- [ ] 2.12 Enforce wording/field separation for posterior probability vs bootstrap support fraction.
- [ ] 2.13 Implement zero/sparse diagnostic flags.
- [ ] 2.14 Add schema invariant tests.

## 3. Independent Jeffreys binary engine

- [ ] 3.1 Add `independent_beta_binomial.R`.
- [ ] 3.2 Enforce integer event/denominator inputs.
- [ ] 3.3 Enforce \(0 \le x \le n\).
- [ ] 3.4 Use primary Jeffreys \(Beta(0.5,0.5)\).
- [ ] 3.5 Support deterministic posterior draws.
- [ ] 3.6 Generate target/reference posterior summaries.
- [ ] 3.7 Generate common draws interface.
- [ ] 3.8 Implement zero-reference RR non-finite expectation detection.
- [ ] 3.9 Prevent Monte-Carlo RR sample mean from being reported as a finite posterior expectation when the theoretical mean diverges.
- [ ] 3.10 Add RR instability diagnostics.
- [ ] 3.11 Add golden cases: `3/100 vs 0/100`, `0/100 vs 0/100`, `30/100 vs 20/100`, `3/30 vs 30/300`, `1/200 vs 0/1000`, `1/200 vs 2/1000`, `0/200 vs 2/1000`.
- [ ] 3.12 Test delta-profile monotonicity.
- [ ] 3.13 Test H/N/B sum-to-one invariant.
- [ ] 3.14 Test `primary_delta=null` disables practical classification/color.

## 4. `vcd-categorical-reporting` revival

- [ ] 4.1 Remove deprecated-only behavior after OpenSpec acceptance.
- [ ] 4.2 Rewrite `SKILL.md` around comparative evidence/reporting.
- [ ] 4.3 Preserve legacy templates under explicit compatibility/version boundary.
- [ ] 4.4 Add multi-theme long input.
- [ ] 4.5 Add multi-group explicit contrasts.
- [ ] 4.6 Add reference-vs-all contrasts.
- [ ] 4.7 Do not default to all-pairs for large group counts.
- [ ] 4.8 Add canonical JSON/CSV output.
- [ ] 4.9 Add offline Markdown/HTML report.
- [ ] 4.10 Keep raw n/N and optional Fisher compatibility columns.
- [ ] 4.11 Add narrative guard against “non-significant = no difference”.
- [ ] 4.12 Add narrative guard against “posterior direction = causality”.
- [ ] 4.13 Add visual iron law: never color by posterior direction alone.

## 5. Safety adapter

- [ ] 5.1 Define SOC/PT canonical hierarchy.
- [ ] 5.2 Require MedDRA version provenance.
- [ ] 5.3 Use Primary SOC for standard aggregation.
- [ ] 5.4 Retain HLT/HLGT only as optional drill-down.
- [ ] 5.5 Deduplicate subject within PT.
- [ ] 5.6 Deduplicate subject within SOC.
- [ ] 5.7 Assert SOC count <= denominator.
- [ ] 5.8 Assert SOC count is not computed as sum of child PT counts.
- [ ] 5.9 Support study-specific output.
- [ ] 5.10 Support pooled output while retaining study-level traceability.
- [ ] 5.11 Render Safety labels for RD, excess/100, RR, U-grade, sparse/zero flags.
- [ ] 5.12 Keep NNH/NNT-like rendering secondary and suppressible when sign ambiguity is material.
- [ ] 5.13 Add Safety fixture with repeated events and multiple PTs in one SOC.
- [ ] 5.14 Add zero-cell Safety fixture.

## 6. RWD and Prescription adapters

- [ ] 6.1 Add generic `parent_theme -> item_theme`.
- [ ] 6.2 Add RWD context extension.
- [ ] 6.3 Add Prescription context extension.
- [ ] 6.4 Add domain-specific column labels without changing canonical statistical fields.
- [ ] 6.5 Add invariance test: identical counts across Safety/RWD/Prescription produce identical comparative evidence statistics.

## 7. Practical-difference policy

- [ ] 7.1 Implement `primary_delta = null` default.
- [ ] 7.2 Implement natural-unit conversion (`per_100`, `per_1000`, probability).
- [ ] 7.3 Implement explicit prespecified mode.
- [ ] 7.4 Implement versioned policy mode.
- [ ] 7.5 Store delta profile even when no primary delta is approved.
- [ ] 7.6 Add simulation tool for proposed U-grade thresholds.
- [ ] 7.7 Validate provisional U0/U1/U2/U3 cutoffs against simulated sparse/imbalanced cases.
- [ ] 7.8 Document that U-grade is presentation uncertainty, not clinical severity.

## 8. `comparative-design-analysis`: 1:1 matching

- [ ] 8.1 Create new skill.
- [ ] 8.2 Implement 4-cell paired outcome extraction.
- [ ] 8.3 Implement Jeffreys-type Dirichlet(0.5,0.5,0.5,0.5).
- [ ] 8.4 Generate marginal target/reference risk draws.
- [ ] 8.5 Verify \(RD=\pi_{10}-\pi_{01}\).
- [ ] 8.6 Generate common draw interface.
- [ ] 8.7 Add matched-pair golden tests.
- [ ] 8.8 Record matched-pair sample size and discordant counts.

## 9. `comparative-design-analysis`: 1:k matching

- [ ] 9.1 Implement matched-set bootstrap.
- [ ] 9.2 Resample matched sets atomically.
- [ ] 9.3 Record matching ratio, caliper, replacement, matched/discarded counts.
- [ ] 9.4 Record balance diagnostics.
- [ ] 9.5 Output `inferential_semantics=bootstrap`.
- [ ] 9.6 Add bootstrap reproducibility/failure tests.

## 10. `comparative-design-analysis`: IPTW

- [ ] 10.1 Implement patient bootstrap.
- [ ] 10.2 Refit propensity model inside every replicate.
- [ ] 10.3 Recompute weights inside every replicate.
- [ ] 10.4 Implement configured stabilization/truncation.
- [ ] 10.5 Support explicit ATE/ATT metadata.
- [ ] 10.6 Calculate weighted marginal target/reference risks.
- [ ] 10.7 Calculate group ESS.
- [ ] 10.8 Record weight quantiles/max.
- [ ] 10.9 Record before/after SMD balance.
- [ ] 10.10 Record positivity/overlap diagnostics.
- [ ] 10.11 Record failed bootstrap replicates.
- [ ] 10.12 Reject non-integer weighted pseudo-counts in the independent Beta-Binomial engine.
- [ ] 10.13 Test that final narrative uses bootstrap terminology, not posterior terminology.

## 11. Person-time rate engine

- [ ] 11.1 Implement Gamma-Poisson rate posterior.
- [ ] 11.2 Generate target/reference rate draws.
- [ ] 11.3 Use common contrast engine for IRD/IRR.
- [ ] 11.4 Add person-time provenance and unit labels.
- [ ] 11.5 Add zero-event rate test cases.

## 12. Cluster/repeated-data boundary

- [ ] 12.1 Implement Pass 0 check: can repeated rows be collapsed to one subject-level binary estimand?
- [ ] 12.2 If yes, route to subject-level binary engine.
- [ ] 12.3 Add cluster-bootstrap extension contract.
- [ ] 12.4 Keep GLMM/GEE canonical implementation out of scope until a separate spec/change is approved.

## 13. `evidence-decision-review`

- [ ] 13.1 Create new skill.
- [ ] 13.2 Define evidence feature schema.
- [ ] 13.3 Ensure decision fields are excluded from evidence clustering input.
- [ ] 13.4 Implement Gower distance.
- [ ] 13.5 Implement hierarchical clustering.
- [ ] 13.6 Add optional continuous-only standardized K-means.
- [ ] 13.7 Reject invalid mixed/unscaled K-means input.
- [ ] 13.8 Implement nearest-precedent retrieval.
- [ ] 13.9 Define decision ledger schema.
- [ ] 13.10 Implement decision discordance candidate detection.
- [ ] 13.11 Word discordance as QA candidate, never automatic error.
- [ ] 13.12 Implement trajectory by study/development/cutoff.
- [ ] 13.13 Implement cluster stability or emit explicit `NOT_ASSESSED`.
- [ ] 13.14 Add tests proving cluster ID never triggers label/regulatory decision.

## 14. Dashboard / report QA

- [ ] 14.1 Report Effect, Direction, Practical Difference, Uncertainty as distinct columns/sections.
- [ ] 14.2 Implement color by practical-region hue and uncertainty intensity only when primary delta exists.
- [ ] 14.3 Ensure U3 appears visually uncertain, not severe.
- [ ] 14.4 Render zero/sparse badges separately.
- [ ] 14.5 Add RR instability warning.
- [ ] 14.6 Ensure no external web assets.
- [ ] 14.7 Ensure no local absolute paths.
- [ ] 14.8 Add HTML structural tests.
- [ ] 14.9 Perform browser visual verification before declaring presentation complete.

## 15. Documentation synchronization

- [ ] 15.1 Update `AGENTS.md`.
- [ ] 15.2 Update `README.md`.
- [ ] 15.3 Update `docs/reference/skill_responsibilities.md`.
- [ ] 15.4 Update `vcd-pass0-consultation/SKILL.md`.
- [ ] 15.5 Update `vcd-categorical-reporting/SKILL.md`.
- [ ] 15.6 Add new skill docs.
- [ ] 15.7 Mark legacy reporting references explicitly.
- [ ] 15.8 Do not rewrite archive evidence except where archival metadata requires it.
- [ ] 15.9 Run doc-consistency checks.

## 16. Independent QA gate

- [ ] 16.1 Blind-first QA: reviewer reads OpenSpec + code/tests before implementer narrative.
- [ ] 16.2 Verify zero-cell mathematics.
- [ ] 16.3 Verify delta null/prespecified semantics.
- [ ] 16.4 Verify U-grade is uncertainty, not severity.
- [ ] 16.5 Verify posterior/bootstrap semantic separation.
- [ ] 16.6 Verify weighted pseudo-count rejection.
- [ ] 16.7 Verify Safety SOC/PT counting invariants.
- [ ] 16.8 Verify no automatic regulatory decision.
- [ ] 16.9 Run full canonical regression suite.
- [ ] 16.10 Run `openspec validate --strict`.
- [ ] 16.11 Run `git diff --check`.
- [ ] 16.12 Record unresolved risks and owner adjudication.

## 17. Completion gate

The change is not archive-ready until:

- [ ] 17.1 All required tests pass.
- [ ] 17.2 No Blocker/High QA finding remains unadjudicated.
- [ ] 17.3 Statistical schemas are versioned and frozen for the release.
- [ ] 17.4 Documentation agrees with OpenSpec.
- [ ] 17.5 Owner explicitly accepts remaining risks.
- [ ] 17.6 Archive operation is separately authorized.
