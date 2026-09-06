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
   - Compute Bayes Factors, Evidence Scores, and standardized residuals.
   - **Contract**: Generate structured results JSON (e.g., `evidence_results.json`).
3. **Pass 2: AI Review & Narrative**
   - Act as an expert statistical consultant to interpret JSON results.
   - **Contract**: Write `executive_summary.md` in **Japanese**.
   - If ambiguity or quality concerns exist, document interpretation holds in `quality_check.md`.
4. **Pass 3: Report Integration & Visualization**
   - Render the interactive HTML dashboard (`dashboard.html` / `dashboard.Rmd`).
   - Merge statistical metrics and AI narratives into a cohesive artifact.

---

## Evidence Judgment Criteria

P値だけで判断しない。標本サイズの普遍的な境界や、BF・効果量の一律閾値から重要性を自動判定しない。

新しい3元表は `vcd-bayesian-evidence-analysis` の `three-way-results-v1` 経路を使用する。全体構造、基準モデルに対するセル診断、効果の大きさ、不確実性、推定保留を分ける。旧 `r² − k log N` は局所BFでも真の信号の判定でもなく監査専用。全体BFをセルへ転用しない。人工100倍化は標本サイズ感度の検証であり、新しい独立観測ではない。

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
