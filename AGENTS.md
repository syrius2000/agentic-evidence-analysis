# AGENTS.md — Evidence-Driven Statistical Analysis

This file provides AI agents with the foundational rules and "Iron Laws" for executing statistical analysis workflows in this repository.

> [!CAUTION]
> **IRON LAW of ANALYSIS**:
> You MUST NOT start statistical computation (Pass 1) without first executing **Pass 0 (Interactive Consultation)**.
> Skipping the consultation leads to the "Curse of Dimensionality" and uninterpretable results.
> **Step 1 is always Pass 0.**

---

## 4-Pass Analysis Pipeline (Strict Execution Sequence)

All agents MUST follow this sequence for any analysis request:

1. **Pass 0: Interactive Consultation (`vcd-pass0-consultation`)**
   - Inspect data structure and counts using `.agents/shared/inspect_data.R`.
   - Propose dimensional reduction, stratification, or scale handling to the user.
   - **Contract**: Generate **`analysis_config.json`** as the Single Source of Truth.
2. **Pass 1: R Engine Computation**
   - Execute statistical scripts (e.g., `analysis.R`) using the `--config` flag pointing to `analysis_config.json`.
   - Compute 4-axis cell diagnostics (Effect, Evidence, Influence, Stability), explicit BIC, and standardized residuals.
   - **Contract**: Generate structured results JSON (e.g., `evidence_results.json`).
3. **Pass 2: AI Review & Narrative**
   - Act as an expert statistical consultant to interpret JSON results.
   - **Contract**: Write `executive_summary.md` in **Japanese**.
   - If ambiguity or quality concerns exist, document interpretation holds in `quality_check.md`.
4. **Pass 3: Report Integration & Visualization**
   - Render the interactive HTML dashboard (`dashboard.html` / `dashboard.Rmd`).
   - Merge statistical metrics and AI narratives into a cohesive artifact.

---

## Evidence Judgment Criteria (4-Axis Framework)

Do NOT rely on P-values alone. When $N > 2,000$, statistical significance is trivial.
Always separate sample-invariant **Effect** from sample-dependent **Evidence** (Dual-Filter approach).

| Axis / Metric | Criterion / Formula | Goal / Interpretation |
| :--- | :--- | :--- |
| **Effect Size (Sample-Invariant)** | $\log(O_i/E_i) \neq 0$ / Cramér's V > 0.1 | Primary criterion for practical/substantive significance. Invariant to $N$. |
| **Evidence (Sample-Dependent)** | $T_i^{\rm score} = \frac{r_{P,i}^2}{1 - h_{ii}} > 10$ / $\Delta\mathrm{BIC} > 10$ | Decisive statistical evidence against independence (Rao score statistic & explicit BIC). |
| **Influence (Structure Impact)** | Leverage $h_{ii} = \text{hatvalues}(fit)$ | Detect influential cells constraining model fit ($h_{ii} \in [0, 1]$). |
| **Stability (Robustness)** | Status: `REGULAR` vs `QUARANTINED` | Isolate zero cells, sparse counts ($\hat{\mu} < 5$), and boundary fits. |

> [!NOTE]
> The legacy formula $r^2 - k \cdot \log(N)$ has been deprecated and retired due to local LRT divergence and evidence inflation in large samples.

---

## Operational Constraints & Rules

### 1. Single Source of Truth
- Always use **`analysis_config.json`** to pass parameters between passes.
- Do not guess variable names; read them strictly from Pass 0 inspection artifacts.

### 2. Output Isolation & Directory Layout
Save artifacts under skill-specific output trees:
- **`vcd-bayesian-evidence-analysis`**: `<output_dir>/run_<first 16 chars of run_id>/` (via `.agents/shared/run_scope.R`). Never create nested `runs/<slug>/`.
- **`vcd-categorical-analysis`**: always `<out>/run_<first16>[_N]/`; use a JST timestamp when run ID is omitted, and add collision suffix when needed.
- **`questionnaire-batch-analysis`**: with `--run-id`, typically `<out>/runs/<id>/`.
- Deterministic isolation: Use input file SHA-256 hash or an explicit meaningful `run_id`.

### 3. Language & Locale
- All AI-generated narratives (`executive_summary.md`, `vcd_analysis_report.md`, reports) MUST be written in **Japanese** unless explicitly requested otherwise.
- Timestamps and analysis context follow **JST (Japan Standard Time)**.

### 4. Repository Boundaries & Governance
- **正本リポジトリ**: この `agentic-evidence-analysis` リポジトリを、同名5スキル、統計schema、統計品質契約、Rテンプレート、統計回帰テストの唯一の正本とする。
- **Skill Tree**: `.agents/skills` is the only managed skill tree. Do not create or restore `.cursor/skills`.
- **Ecosystem Boundaries**:
  - `Productivity-Skill`: 一般コード・SQLコード理解を担当する。
  - `rwd-mysql-skill-toolkit`: RWD/DB実行・統合ハブを担当する。
  - DB/SQL/Python実行補助をこのリポジトリへ複製しない。統計仕様・実装の変更はこの正本へ反映する。
