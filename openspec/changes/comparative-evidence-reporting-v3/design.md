## Context

In clinical-trial safety, post-marketing surveillance, RWD, and prescription analytics, comparative proportion analyses \(x_T/n_T \text{ vs } x_R/n_R\) are recurring. Existing methods frequently over-rely on Fisher exact tests, Wald-type confidence intervals, or rigid p-value thresholds, leading to undefined risk ratios under zero cells, erratic intervals, and lost clinical context. See `proposal.md` for background and motivation.

## Goals / Non-Goals

**Goals:**
- Implement an end-to-end comparative evidence architecture that cleanly separates:
  \[
  \text{Domain} \ne \text{Design} \ne \text{Inference} \ne \text{Contrast} \ne \text{Decision}
  \]
- Support independent proportion comparisons via Jeffreys priors (\(\text{Beta}(0.5, 0.5)\)) with stable zero-cell handling, finite Monte-Carlo expectation safeguards, and explicit prior declarations.
- Support complex designs (1:1 and 1:k matching, IPTW with propensity score re-estimation, person-time rates) via dedicated design-aware inference producing standardized draws (`comparative-draws-v1`).
- Compute standardized contrasts (RD, RR, excess per natural unit, direction support, delta profiles, H/N/B practical-difference regions, and U0–U3 uncertainty grades).
- Provide domain reporting adapters for Safety (SOC/PT with MedDRA provenance), generic RWD (parent/item), and Prescriptions.
- Provide historical decision consistency auditing without usurping human decision-making authority.

**Non-Goals:**
- Replacing contingency table association and residual diagnosis (`two-way-evidence-analysis` remains strictly for cross-tabulation association/residuals).
- Automated regulatory or medical decision-making (the system audits precedent consistency and discordance, but never automates clinical policy).
- In-memory database query execution (raw data extraction remains in external toolkit/SQL hubs).

## Decisions

### Decision 1 — Keep implementation in `agentic-evidence-analysis`
- **Choice:** Consolidate within the canonical statistical repository.
- **Rationale:** This repository is the Single Source of Truth for statistical contracts, schemas, and regression tests. Splitting would lead to spec drift.
- **Alternatives Considered:** Creating a separate standalone repository (rejected due to schema synchronization overhead).

### Decision 2 — Revive `vcd-categorical-reporting` as the core comparative evidence layer
- **Choice:** Redefine `vcd-categorical-reporting` to own independent Jeffreys inference, contrast transforms, domain adapters, and uncertainty rendering.
- **Rationale:** Preserves skill discovery while clarifying that it does not own propensity models or matching logic.
- **Alternatives Considered:** Creating a completely new skill name (rejected to avoid fragmentation).

### Decision 3 — Pass 0 as a Statistical Consultation Gateway
- **Choice:** Extend `vcd-pass0-consultation` to inspect inputs, validate design/estimand constraints, and output `routing_decision.json`.
- **Rationale:** Prevents inappropriate model routing (e.g. routing weighted data to Beta-Binomial) at inception.

### Decision 4 — Downstream comparison logic consumes standardized draws
- **Choice:** Standardize on `comparative-draws-v1` containing `draw_id`, `target_value`, `reference_value`, `scale`, `inferential_semantics`, `method`, and `estimand`.
- **Rationale:** Unifies contrast calculations across analytical posteriors (Beta, Dirichlet, Gamma) and empirical resamples (bootstrap).

### Decision 5 — Separation of posterior and bootstrap semantics
- **Choice:** Maintain strict semantic and label distinction between Bayesian posterior probabilities (\(P(RD>0|D)\)) and bootstrap empirical support fractions (\(\frac{1}{B}\sum I(RD_b>0)\)).

### Decision 6 — Zero-cell reference RR mathematical safeguarding
- **Choice:** For zero reference events where \(a \le 1\), the theoretical mean of \(1/p\) diverges to \(\infty\). The system reports median + ETI and explicitly flags non-finite theoretical expectations, prohibiting the reporting of Monte-Carlo sample means as finite posterior expectations.

## Statistical and Domain Architecture

### Independent Risk Engine
- Prior: \(p_g|D \sim \text{Beta}(x_g + 0.5, n_g - x_g + 0.5)\).
- Estimators: Posterior median, 95% equal-tailed intervals (ETI), excess per 100, direction support \(P(RD>0)\).
- Practical Difference: When an approved \(\delta\) is provided, computes:
  \[
  q_H = P(RD > \delta), \quad q_N = P(|RD| \le \delta), \quad q_B = P(RD < -\delta)
  \]
  Uncertainty grade \(C = \max(q_H, q_N, q_B)\) mapped to U0 (\(\ge 0.95\)), U1 (\([0.80, 0.95)\)), U2 (\([0.60, 0.80)\)), U3 (\(< 0.60\)).
- Visual Guard: Hue encodes dominant practical region; saturation/opacity encodes certainty. Never color by raw posterior direction alone.

### Domain Adapters
- **Safety**: Primary SOC / PT hierarchy. Subject-level deduplication within PT and SOC. MedDRA version provenance tracking.
- **RWD / Prescription**: Generic parent_theme / item_theme structure with study/database provenance.

### Design-Aware Engine (`comparative-design-analysis`)
- 1:1 matching: 4-cell multinomial Dirichlet posterior (\(\text{Dirichlet}(0.5, 0.5, 0.5, 0.5)\)).
- 1:k matching: Matched-set resampling bootstrap (never split matched sets).
- IPTW: Patient-level bootstrap with propensity model re-estimation in each replicate; outputs ESS, balance, positivity diagnostics.
- Person-time rates: Gamma-Poisson conjugate model.

### Decision Consistency Engine (`evidence-decision-consistency`)
- Unsupervised distance (Gower) and hierarchical clustering on evidence features strictly excluding decision labels.
- Historical precedent retrieval displaying past evidence, regulatory decisions, and rationale.
- Discordance flagged as "QA review candidate", never labeled as an "error".

## Risks / Trade-offs

- **[Risk]** Heavy bootstrap replicates in IPTW may cause execution delays in large datasets.  
  → **Mitigation:** Provide deterministic seeds, parallel worker options, and progress telemetry in R.
- **[Risk]** Users may misinterpret U3 ("uncertain") as clinically severe.  
  → **Mitigation:** Enforce neutral visual palettes (muted grays/stripes) for U3 and display explanatory tooltips.
- **[Risk]** Legacy code depending on old `vcd-categorical-reporting` templates might break.  
  → **Mitigation:** Isolate legacy templates behind explicit legacy interface flags while directing new workflows to v3 runtime.

## Migration Plan

1. Core schemas (`comparative-draws-v1`, `comparative-evidence-v1`) introduced to `.agents/shared/`.
2. Core statistical R functions implemented and verified via unit tests.
3. Pass 0 gateway extended.
4. `vcd-categorical-reporting` upgraded and validated.
5. New skills `comparative-design-analysis` and `evidence-decision-review` integrated.
