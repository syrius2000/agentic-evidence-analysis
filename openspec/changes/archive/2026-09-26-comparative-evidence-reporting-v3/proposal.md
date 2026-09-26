# Proposal: Comparative Evidence Reporting v3

## Executive Summary

Introduce a standardized, design-aware comparative statistical evidence layer within `agentic-evidence-analysis`. This system evaluates differences and ratios across comparative cohorts, observational studies, and real-world data (RWD) without reducing evidence to a single P-value, arbitrary significance threshold, or hard-coded regulatory decision rule.

The architecture strictly separates:
\[
\text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Region Resolution} \ne \text{Numerical Precision} \ne \text{Decision}
\]

This change revives `vcd-categorical-reporting` as the comparative reporting hub, extends `vcd-pass0-consultation` with intelligent design routing, establishes `comparative-design-analysis` for complex observational designs (1:1 matched pairs, 1:k matched sets, IPTW, and person-time incidence rates), and adds `evidence-decision-review` for unsupervised consistency auditing against historical precedents.

## Capabilities

### New Capabilities

- `pass0-analysis-routing`: Interactive consultation inspecting input structure, validating estimand specifications, and deterministically routing analyses to independent binary, design-aware, or legacy contingency table workflows, while failing fast on unsupported configurations (such as complex survey weights or uncollapsible clusters).
- `comparative-evidence-reporting`: Multi-group, multi-theme comparative evidence engine and reporting pipeline providing risk differences, risk ratios, excess events per natural unit, direction support, delta profiles, practical-region resolution grades (U0–U3), separate continuous interval precision metrics, and self-contained offline reports with zero external web dependencies.
- `comparative-design-inference`: Standardized uncertainty draw generation across complex designs, covering 1:1 matched pairs (4-cell Dirichlet), 1:k matched sets (cluster bootstrap), IPTW (patient bootstrap with propensity score refitting), and person-time exposure (shape-rate Gamma-Poisson rate models). Outputs conform to the logical `comparative-draws-v1` runtime interface.
- `evidence-decision-consistency`: Unsupervised audit engine converting statistical profiles into decision-label-free evidence feature vectors, retrieving similar historical precedents via Gower distance, and flagging discordances as "QA Review Candidates" without imposing automated regulatory decisions.

### Modified / Conforming Existing Capabilities

- `evidence-run-layout`: All new and revived analytical skills (`vcd-categorical-reporting`, `comparative-design-analysis`, `evidence-decision-review`) conform strictly to the canonical layout `evidence_runs/<skill_slug>/run_<canonical_id>[_N]/`, providing full isolation, directory hashing, and `run_meta.json` audit contracts.
- `deterministic-r-dependencies`: All new R calculation modules rely exclusively on pre-installed libraries without runtime package installation, and execution paths separate statistical calculation dependencies from optional HTML reporting dependencies.

## Key Boundaries & Constraints

1. **Statistical Separation of Concepts**:
   \[
   \text{Effect Magnitude} \ne \text{Direction Support} \ne \text{Practical Relevance} \ne \text{Region Resolution} \ne \text{Continuous Precision} \ne \text{Human Decision}
   \]
   - Direction support $P(RD > 0)$ measures the mass above zero; it does not indicate practical importance.
   - Region resolution grade (U0–U3) measures how decisively the uncertainty distribution falls into one of three predefined practical regions ($q_T, q_N, q_R$); it is not a measure of generic sampling precision, data quality, or clinical severity. Continuous precision is tracked independently via credible interval widths (`rd_eti_width`, `log_rr_eti_width`), effective sample size (ESS), and sample sizes.
2. **Zero-Event Cells and Non-Finite Expectations**:
   - Zero-event numerators are analyzable under Jeffreys prior inference; empty cohorts ($n=0$) remain invalid and strictly unanalyzable.
   - When reference event count $x_R = 0$, theoretical expectation $E(RR) = \infty$. The system reports median and 95% ETI, explicitly setting `mean = null` and `mean_is_finite = false`. Substituting an empirical Monte-Carlo mean is strictly prohibited.
3. **Inferential Semantics & Uncertainty Draw Contract**:
   - The term **uncertainty draws** serves as the neutral runtime interface.
   - Models with explicit priors (Beta-Binomial, Dirichlet, Gamma-Poisson) output `inferential_semantics = "posterior"`.
   - Resampling designs (IPTW, matched-set bootstrap) output `inferential_semantics = "bootstrap"` and MUST report `bootstrap_support_fraction` rather than posterior probabilities.
   - `comparative-draws-v1` is a logical runtime interface; raw draws are **ephemeral** by default (`persist_raw_draws: false`). Permanent deliverables focus on summaries (`comparative_evidence.json`, `comparative_summary.csv`, `run_meta.json`).
4. **Batch Multiplicity & Exploratory Screening**:
   - When screening hundreds or thousands of Preferred Terms (PTs) or themes, posterior direction probabilities and ranking heuristics are exploratory tools and do not provide automatic familywise error rate (FWER) or false discovery rate (FDR) control.
5. **Clinical Safety Hierarchy and Pooling**:
   - Primary reporting hierarchy is SOC $\rightarrow$ PT. HLGT and HLT levels remain optional drill-downs.
   - Analysis within SOC deduplicates subjects experiencing multiple distinct PTs.
   - Study-specific inference is canonical. Aggregated multi-study summaries are designated as `descriptive_pooled` without claiming to model between-study heterogeneity.
6. **Visual Integrity**:
   - Cell background hue SHALL NEVER be assigned based on posterior direction alone. Hue is reserved for the dominant practical region ($q_T, q_N, q_R$) only when an approved `primary_delta` exists.
