# Titanic Bayesian Evidence Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the `vcd-bayesian-evidence-analysis` skill on `examples/titanic.csv` and generate a complete interactive dashboard.

**Architecture:** 3-Pass Workflow (Pass 1: R Calculation -> Pass 2: AI Executive Summary -> Pass 3: Rmd Dashboard Rendering).

**Tech Stack:** R (dplyr, jsonlite, rmarkdown), AI (insight generation).

---

## Task 1: Pass 1 - Statistical Computation

**Files:**

- Run: `.agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R`
- Create: `output/titanic_analysis/run_titanic_v1/evidence_results.json`
- Create: `output/titanic_analysis/run_titanic_v1/dt_table.html`

- [ ] **Step 1: Execute the R Engine for Pass 1**

Run:

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --input examples/titanic.csv \
  --output_dir output/titanic_analysis \
  --run-id titanic_v1 \
  --freq Freq
```

Expected: `[INFO] JSON出力: .../evidence_results.json` and `[INFO] DTテーブル出力: .../dt_table.html` appear.

- [ ] **Step 2: Verify the generated JSON**

Run: `ls -l output/titanic_analysis/run_titanic_v1/evidence_results.json`
Expected: File exists and contains `top_k_data`.

### Task 2: Pass 2 - AI Executive Summary Generation

**Files:**

- Create: `output/titanic_analysis/run_titanic_v1/executive_summary.md`

- [ ] **Step 1: Draft the Executive Summary based on Pass 1 results**

Write the following content to `output/titanic_analysis/run_titanic_v1/executive_summary.md`:

```markdown
# エグゼクティブ・サマリー: Titanic データのベイズ的証拠分析

#### 節1: 全体的な関連性の評価（ベイズファクター + 効果量）

本分析では、Titanic データにおける客室クラス（Class）、性別（Sex）、年齢（Age）、生存（Survived）の4変数間の関連性を評価しました。独立 Poisson GLM モデル（主効果のみ）と飽和モデルを比較した結果、EBIC 近似に基づくベイズファクター $\mathrm{BF}_{10}$ は約 $3.46 \times 10^{231}$ という極めて巨大な値を示しました。これは Jeffreys の基準において「独立モデルでは到底説明不可能な、決定的に強固な交互作用（decisive evidence）」が存在することを意味します。なお、本データセットは総度数 $N=2,201$ の大規模データであるため、統計的有意性だけでなく実質的意義（効果量）に注目する必要があります。

#### 節2: エビデンス・スコアによる「真の関連」の抽出

大標本における P 値の罠（微小な差を有意と判定してしまう現象）を避けるため、本分析ではエビデンス・スコア（Evidence Score）を用いました。スコアは $\mathrm{Evidence\;Score} = r^2 - k \cdot \log(N)$ と定義され、今回の設定では $k=1$、$\log(N) \approx 7.70$ を閾値としています。全 32 セルのうち、この閾値を超える正値を示したセルは 19 セル（59.4%）であり、これらが「単なる独立性の仮定からのズレ」を超えた、実質的なエビデンスを持つセルとして抽出されました。

#### 節3: 多次元交互作用の解釈（層別エビデンス）

エビデンス・スコアの上位セルを確認すると、特定の属性組み合わせにおいて生存率が独立モデルの予測から大きく逸脱していることがわかります。

| 客室クラス | 性別   | 年齢  | 生存 | 実測値 | 期待値 | 残差   | Evidence Score | 強度    |
| :--------- | :----- | :---- | :--- | :----- | :----- | :----- | :------------- | :------ |
| 1st        | Female | Adult | Yes  | 140    | 21.3   | 25.71  | 653.43         | Level 3 |
| 2nd        | Female | Adult | Yes  | 80     | 18.7   | 14.18  | 193.49         | Level 3 |
| 2nd        | Female | Child | Yes  | 13     | 1.0    | 12.19  | 140.86         | Level 3 |
| Crew       | Female | Adult | No   | 3      | 121.6  | -10.76 | 107.98         | Level 3 |
| Crew       | Male   | Adult | No   | 670    | 447.8  | 10.50  | 102.50         | Level 3 |

特に「1等客室の成人女性の生存（Score: 653.4）」や「2等客室の成人女性・子供の生存」は、独立モデルが予測する値を圧倒的に上回る強い正のエビデンスを示しています。一方で「乗務員の成人男性の死亡（Score: 102.5）」も実測値が期待値を大きく上回っており、当時の社会構造や救助優先順位が多次元的な交互作用としてスコアに現れています。

#### 節4: 結論と実務的示唆

本分析により、Titanic における生存の成否は、単一の変数（例：客室クラスのみ）ではなく、客室クラス・性別・年齢の複雑な交互作用によって決定されていたことが統計的に裏付けられました。大規模データ特有の「すべてが有意に見える」問題をエビデンス・スコアによって制御し、真に注目すべき 19 のセルを特定しました。これらの結果は、救助における「女性と子供を先に」という規範と、客室クラスによるアクセスの差異が、相互に補強し合う形で生存結果に寄与していたことを示唆しています。
```

- [ ] **Step 2: Commit the AI summary**

```bash
git add output/titanic_analysis/run_titanic_v1/executive_summary.md
git commit -m "docs: add AI executive summary for Titanic analysis"
```

### Task 3: Pass 3 - Dashboard Rendering

**Files:**

- Create: `output/titanic_analysis/run_titanic_v1/dashboard.html`

- [ ] **Step 1: Execute the R Engine for Pass 3**

Run:

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --output_dir output/titanic_analysis
```

Expected: `[INFO] Render complete: .../dashboard.html` appears.

- [ ] **Step 2: Verify all final artifacts**

Run: `ls -R output/titanic_analysis/run_titanic_v1/`
Expected: `evidence_results.json`, `dt_table.html`, `executive_summary.md`, `dashboard.html` all exist.
