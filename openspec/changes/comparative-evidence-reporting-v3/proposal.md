## Why

In clinical-trial safety, post-marketing surveillance, real-world data (RWD), and purchased prescription analyses, comparative proportion analyses of the form \(x_T/n_T \text{ vs } x_R/n_R\) are ubiquitous. Existing workflows frequently collapse into binary p-value significance testing or unstable Wald-type confidence intervals that break down under zero cells, small sample sizes, unequal denominators, and complex designs (e.g. matching, IPTW, person-time).

This change establishes an end-to-end comparative evidence architecture that cleanly separates Domain context, Design, Statistical Inference, Contrast transformations, and Decision consistency, providing reliable Bayesian posterior inference with explicit priors, design-aware uncertainty draws, standardized domain profiles, and historical precedent auditing.

## What Changes

- **Pass 0 Consultation Gateway (`pass0-analysis-routing`)**: Expands Pass 0 from simple dimensionality checking to an estimand-, design-, and domain-aware consultation gateway that produces `routing_decision.json`, validates input count integrity and duplicate subjects, and routes to appropriate downstream engines.
- **Comparative Evidence Reporting Revival (`comparative-evidence-reporting`)**: Redefines and revives `vcd-categorical-reporting` as the core comparative evidence and reporting engine. Directly executes independent-binomial Jeffreys posterior inference (\(\text{Beta}(0.5, 0.5)\)), handles zero-cell numerators/denominators stably, consumes draws from design-aware engines, computes standardized contrasts (RD, RR, excess per 100, delta profile, H/N/B classifications, U0–U3 uncertainty grades), and renders Safety (SOC/PT), RWD, and Prescription reporting profiles.
- **Design-Aware Comparative Engine (`comparative-design-inference`)**: Introduces a new skill and engine for non-independent designs including 1:1 and 1:k matching, propensity-score IPTW, and Gamma-Poisson person-time rates, generating standardized `comparative-draws-v1` with design diagnostics (ESS, balance, positivity).
- **Decision Consistency Auditing (`evidence-decision-consistency`)**: Introduces a new skill and engine for retrieving historical decision precedents, evaluating concordance/discordance across historical decision ledgers, and surfacing consistency context while strictly keeping human agency over final decisions.
- **Shared Schemas and Contracts**: Establishes `comparative-draws-v1` and `comparative-evidence-v1` JSON schemas ensuring interoperability across design engines, contrast layers, and presentation adapters.

## Capabilities

### New Capabilities

- `pass0-analysis-routing`: Statistical consultation gateway that inspects input counts, validates design constraints, resolves primary estimand and practical delta, and produces structured routing decisions.
- `comparative-evidence-reporting`: Common comparative evidence layer handling independent Jeffreys proportions, draw-based contrast calculations (RD, RR, excess), delta profiles, U-grades, and Safety/RWD/Prescription domain reporting profiles.
- `comparative-design-inference`: Design-aware inference engine covering matching, IPTW, and person-time rates that outputs standardized comparative draws and design diagnostics.
- `evidence-decision-consistency`: Historical decision retrieval, nearest precedent clustering, and discordance QA auditing against past regulatory/clinical decision ledgers.

### Modified Capabilities

None. (Existing capabilities like `two-way-evidence-analysis` remain contingency-table association/residual diagnostics and are not repurposed).

## Impact

- **Skills**:
  - `vcd-pass0-consultation`: Extended with consultation gateway templates and schema.
  - `vcd-categorical-reporting`: Deprecated legacy templates preserved behind explicit compatibility boundary; skill revived with comparative evidence runtime, templates, and domain adapters.
  - `comparative-design-analysis`: New skill created for design-aware inference.
  - `evidence-decision-review`: New skill created for decision review and precedent clustering.
- **Shared Code (`.agents/shared/`)**: Added `comparative_draws.R`, `comparative_contrasts.R`, `independent_beta_binomial.R`, and updated schemas.
- **APIs & Output Layout**: Generates `comparative_evidence.json`, `comparative_draws.json`, offline standalone HTML/Markdown reports under `evidence_runs/comparative_reporting/run_<id>/`.
