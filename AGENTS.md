# AGENTS.md — Evidence-Driven Statistical Analysis

This file provides AI agents with the foundational rules and "Iron Laws" for executing statistical analysis skills in this repository.

> [!CAUTION]
> **IRON LAW of ANALYSIS**:
> You MUST NOT start statistical computation (Pass 1) without first executing **Pass 0 (Interactive Consultation)**.
> Skipping the consultation leads to the "Curse of Dimensionality" and uninterpretable results.
> **Step 1 is always Pass 0.**

## 4-Pass Analysis Pipeline (Strict Sequence)

All agents MUST follow this sequence for any new analysis request:

1. **Pass 0: `vcd-pass0-consultation`**
    * Inspect data physically using `.agent/shared/inspect_data.R`.
    * Propose dimensional reduction or stratification.
    * Generate **`analysis_config.json`**.
2. **Pass 1: R Engine (Computation)**
    * Execute analysis script (e.g., `analysis.R`) using the `--config` flag.
    * Generate `Analysis Results JSON`.
3. **Pass 2: AI Review (Insights)**
    * Read the JSON results as an expert consultant.
    * Write `executive_summary.md` in Japanese.
4. **Pass 3: Report Integration (Visualization)**
    * Render the interactive HTML `dashboard.html`.

## Evidence Judgment Criteria

Do NOT rely on P-values alone. When $N > 5,000$, statistical significance is trivial.

| Metric | Formula / Criterion | Goal |
| :--- | :--- | :--- |
| **Evidence Score** | $r^2 - k \cdot \log(N) > 0$ | Extract "signal" from "noise". |
| **Bayes Factor** | $BF_{10} > 100$ | Confirm "decisive" evidence. |
| **Effect Size** | Cramér's V > 0.1 | Ensure "practical significance". |

## Execution Rules

### 1. Single Source of Truth
* Always use **`analysis_config.json`** to pass parameters between steps.
* Do not guess variable names; read them from Pass 0 artifacts.

### 2. Output & Isolation
* Save artifacts under a project-specific output tree; **layout depends on the skill** (read that skill's `SKILL.md`):
  * **`vcd-bayesian-evidence-analysis`**: `<output_dir>/run_<first 16 chars of run_id>/` (from `.agent/shared/run_scope.R` `run_output_dir_from_root`). No `runs/<slug>/` folder.
  * **`vcd-categorical-analysis`**, **`questionnaire-batch-analysis`**: with `--run-id`, typically `<out>/runs/<id>/`.
* Use the input file's SHA-256 hash or a meaningful `run_id` for deterministic isolation where the skill supports it.

### 3. Language
* All AI-generated narratives (`executive_summary.md`, `vcd_analysis_report.md`) MUST be in **Japanese** unless explicitly requested otherwise.

## Skill Installation

* Clone the repository and copy the `.agent/` directory to your project root.
* Ensure R (>= 4.0) and Pandoc are available in the shell environment.
