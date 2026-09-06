# AGENTS.md — Evidence-Driven Statistical Analysis Guidelines

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
   - Inspect data structure, counts, missingness, and cell sparsity using `.agents/shared/inspect_data.R`.
   - Propose dimensional reduction, stratification, or scale handling to the user.
   - **Contract**: Generate **`analysis_config.json`** as the Single Source of Truth.
2. **Pass 1: R Engine Computation**
   - Execute statistical scripts (e.g., `analysis.R`) using the `--config` flag pointing strictly to `analysis_config.json`.
   - **3次元正本経路 (`three-way-results-v1`)**:
     - 全主効果を含む 9 階層対数線形モデル（M1〜M9）を適合。
     - 総度数 $N$ 基準のポアソン明示式 $\mathrm{BIC}_{\mathrm{explicit}} = -2\ln L + p\ln N$ を計算（R 既定 `stats::BIC` や Deviance 式の使用禁止）。
     - **新 4 軸セル診断フレームワーク**:
       1. **Effect（効果量: $N$ 不変）**: 局所対数効果比 $\log(O_i/E_i)$、標準化差 $e_i$、率差 $d_i$。
       2. **Evidence（証拠強度: $N$ 比例）**: Rao (1948) の局所スコア検定統計量 $T_i^{\rm score} = \frac{r_{P,i}^2}{1-h_{ii}}$、対数 P 値 $\ln(P)$。
       3. **Influence（影響度）**: ハット行列対角成分 Leverage $h_{ii}$（Pregibon, 1981）。
       4. **Stability（数値安定性）**: 観測ゼロ $O_i=0$、疎セル $E_i < 5.0$、過大 Leverage $h_{ii} \ge 0.80$ の 3 条件論理和判定（`QUARANTINED` / `REGULAR`）。
     - **大標本 Dual-Filter 原則 ($N > 2,000$)**:
       $|\log(O/E)| \ge 0.50$（Effect スクリーニング）かつ $T_i^{\rm score} \ge 3.84$（Evidence ノイズ排除）の 2 段階判定を適用。
     - **多項 Dirichlet 事後推論**: 共役事前分布による事後平均、条件付き割合の 95% 信用区間（HDI/ETI）、Freeman-Tukey 事後予測チェック（PPP-value）。
     - **旧指標の監査列化**: 旧エビデンススコア（$r^2 - k\ln N$）は大標本エビデンス飽和のため監査専用列とし、真の信号判定・セル合否判定・セルBFとして扱わない。
   - **Contract**: Generate structured results JSON (e.g., `evidence_results.json`).
3. **Pass 2: AI Review & Narrative**
   - Act as an expert statistical consultant to interpret JSON results.
   - **Contract**: Write `executive_summary.md` in **Japanese**.
   - If ambiguity or quality concerns exist (e.g., quarantined cells, non-convergence), document interpretation holds in `quality_check.md`.
4. **Pass 3: Report Integration & Visualization**
   - Render the interactive HTML dashboard (`dashboard.html` / `dashboard.Rmd`).
   - In 3-way analysis, use `render_report.R` to integrate model comparisons, cell diagnostics, stratified heatmaps, conditional rates, prior sensitivities, and Japanese narrative.

---

## Evidence Judgment Criteria & Statistical Philosophy

- **P 値単独による判断の完全禁止**: 普遍的な標本サイズ境界や、P 値・BF・効果量の一律閾値から重要性を機械的に自動判定しない。
- **次元の分離原則**:
  1. **全体連関構造**（9 階層対数線形モデルと明示式 BIC）
  2. **差の大きさ**（$\log(O/E)$、標準化差、率差）
  3. **統計的証拠**（Rao スコア検定統計量 $T_i^{\rm score}$、対数 P 値）
  4. **影響度と安定性**（Leverage $h_{ii}$、Stability 3 条件による QUARANTINED 判定）
  5. **不確実性**（多項 Dirichlet 事後信用区間、事前感度、PPP-value）
  6. **実務判断**（費用、リスク、意思決定基準）
- **100倍拡張実験の解釈**: 人工的な度数 100 倍化は標本サイズ感度を検証するための教材であり、新しい独立観測の追加ではない。

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
- **正本リポジトリ**: この `agentic-evidence-analysis` リポジトリを、同名 5 スキル、統計 schema、統計品質契約、R テンプレート、統計回帰テストの唯一の正本とする。
- **数理リファレンス**: 指標の定義・数理導出・参考文献（一次情報）は [`docs/reference/README.md`](docs/reference/README.md) を入口とする。
- **Skill Tree**: `.agents/skills` is the only managed skill tree. Do not create or restore `.cursor/skills`.
- **Ecosystem Boundaries**:
  - `Productivity-Skill`: 一般コード・SQLコード理解を担当する。
  - `rwd-mysql-skill-toolkit`: RWD/DB実行・統合ハブを担当する。
  - DB/SQL/Python実行補助をこのリポジトリへ複製しない。統計仕様・実装の変更はこの正本へ反映する。
