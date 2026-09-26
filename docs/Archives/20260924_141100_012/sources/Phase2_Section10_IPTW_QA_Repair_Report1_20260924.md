# Independent QA Report — Phase 2 Section 10: IPTW Repair Recommendations

**Repository:** `syrius2000/agentic-evidence-analysis`  
**Branch:** `feat/comparative-evidence-reporting-v3`  
**Reviewed commit:** `cba3960090518392467d98d03167a6a9db91a4bb`  
**Baseline commit:** `ef5f74505dd7a5bcec8b7cf611d3a2d7eec8e040`  
**Branch merge-base (vs main):** `8174a47003c133ba7bd16d86f9130253fd10c28e`  
**Target:** Phase 2 Section 10 — Design-Aware Inference Engine: IPTW  
**Review date:** 2026-09-23 / QA repair report generated 2026-09-24 JST  
**Acceptance Gate:** **HOLD**

---

## 1. Executive Summary

Section 10 の IPTW 実装は、数理コアについては概ね妥当である。

確認できた主な positive findings:

- ATE / ATT の IPTW weight formula は OpenSpec と整合
- stabilized ATE および marginal-odds-scaled ATT を実装
- arm-normalized Hájek 型 weighted marginal risk を実装
- Kish effective sample size (ESS) を実装
- patient-row bootstrap 内で propensity score model を再推定
- bootstrap percentile interval semantics を core inference engine で利用
- weighted / unweighted SMD を記録
- RR zero-denominator suppression policy を実装
- seed reproducibility test を追加
- non-integer IPTW pseudo-counts を independent Beta-Binomial engine が reject する境界を確認
- canonical regression suite に `test_iptw_inference.R` を登録

一方、Section 10 を freeze / ACCEPT とするには、統計計算そのものよりも **analysis governance / semantic contract / downstream reporting / diagnostic verification** に未解決事項が残る。

### QA Severity Summary

| ID | Severity | Finding | Gate Impact |
|---|---|---|---|
| H-01 | **HIGH** | IPTW report が posterior / ETI 用語をハードコードしており Task 10.13 が未達 | Required fix |
| H-02 | **HIGH** | PS を `[1e-6, 1-1e-6]` に silent clipping しているが仕様・metadata・diagnostics がない | Required fix |
| H-03 | **HIGH** | IPTW weighted risk と raw `events/total` が同じ cohort object に混在 | Required fix |
| H-04 | **HIGH** | convergence failure threshold が public API から設定不能で Task 10.11 の "configurable" 契約未達 | Required fix |
| M-01 | **MEDIUM** | arm-specific percentile truncation test が実質的に truncation を検証していない | Test repair |
| M-02 | **MEDIUM** | extreme-weight warning / positivity overlap の verification evidence 不足 | Test repair |
| M-03 | **MEDIUM** | patient-level bootstrap を主張するが subject ID uniqueness / repeated-row guard がない | Hardening |
| M-04 | **MEDIUM** | `iptw_metadata` に refit mode / truncation / scaling / clipping provenance が不足 | Schema hardening |

**Current verdict: `HOLD`**

---

## 2. Positive Findings — 数理コア

### 2.1 ATE / ATT Weight Formulas

ATE:

\[
w_i^{ATE}
=
\frac{A_i}{e_i}
+
\frac{1-A_i}{1-e_i}
\]

ATT:

\[
w_i^{ATT}
=
A_i
+
(1-A_i)\frac{e_i}{1-e_i}
\]

Stabilized ATE:

\[
sw_i^{ATE}
=
A_i\frac{P(A=1)}{e_i}
+
(1-A_i)\frac{P(A=0)}{1-e_i}
\]

Marginal-odds-scaled ATT:

\[
sw_i^{ATT}
=
A_i
+
(1-A_i)\frac{e_i}{1-e_i}
\frac{P(A=1)}{P(A=0)}
\]

コードは現行 OpenSpec の数式と整合している。

**Status: PASS**

---

### 2.2 Weighted Marginal Risks

観測標本の点推定量は arm-normalized weighted risks:

\[
\hat p_T
=
\frac{\sum_{i:A_i=1}w_iY_i}
{\sum_{i:A_i=1}w_i}
\]

\[
\hat p_R
=
\frac{\sum_{i:A_i=0}w_iY_i}
{\sum_{i:A_i=0}w_i}
\]

を使用している。

RD:

\[
\widehat{RD}
=
\hat p_T-\hat p_R
\]

RR:

\[
\widehat{RR}
=
\frac{\hat p_T}{\hat p_R}
\]

であり、`estimate.source = "observed_sample_estimate"` として扱う設計も妥当。

**Status: PASS**

---

### 2.3 Kish Effective Sample Size

\[
ESS_g
=
\frac{\left(\sum_{i\in g}w_i\right)^2}
{\sum_{i\in g}w_i^2}
\]

を target / reference 別に算出している。

**Status: PASS**

---

### 2.4 In-Replicate Propensity Score Refitting

bootstrap replicate ごとに:

1. patient rows を有復元抽出
2. logistic PS model を再推定
3. IPTW weights を再計算
4. truncation を再適用
5. weighted risk を再計算

する構造になっている。

PS 推定 uncertainty を固定せず bootstrap に取り込む設計として妥当。

**Status: PASS**

---

## 3. H-01 — IPTW Reporting Semantics / Task 10.13

### Finding

`openspec/.../tasks.md` は Task 10.13 を完了済みとしている:

> Verify that reports generated from IPTW use bootstrap percentile interval and resampling terminology, verified by narrative test.

しかし downstream reporting implementation は posterior-oriented field / terminology をハードコードしている。

代表例:

```text
rd_posterior_median
rd_eti_lower
rd_eti_upper
rr_posterior_median
rr_eti_lower
rr_eti_upper
```

Markdown report の表現も:

```text
RD 中央値 [95% ETI]
RR 中央値 [95% ETI]
P(RD > 0)
```

となっている。

IPTW の canonical semantics は:

```text
inferential_semantics = "bootstrap"
interval.method = "bootstrap_percentile"
direction_support.metric_name = "bootstrap_support_fraction_rd_gt_zero"
```

であり、posterior / ETI terminology とは区別すべき。

### Risk

統計量自体が同じ数値でも、`posterior probability` と `bootstrap support fraction`、`ETI` と `bootstrap percentile interval` は推論上の意味が異なる。

製薬/RWD downstream report で inferential semantics を誤表示することは、単なる UI label bug ではなく evidence interpretation の誤りにつながる。

### Required Repair

reporting layer を `inferential_semantics` / `interval.method` に応じて切り替える。

推奨例:

```text
posterior:
  "Posterior median"
  "95% ETI"
  "P(RD > 0)"

bootstrap:
  "Observed estimate"
  "95% bootstrap percentile interval"
  "Bootstrap support fraction (RD > 0)"
```

内部 dataframe field も可能なら neutral terminology に変更:

```text
rd_estimate
rd_interval_lower
rd_interval_upper
rr_estimate
rr_interval_lower
rr_interval_upper
direction_support
```

### Required Tests

- IPTW evidence を report renderer に渡す integration test
- output に `ETI`, `posterior median`, `P(RD > 0)` が現れないこと
- output に bootstrap / resampling terminology が現れること
- independent Beta-Binomial report の posterior terminology が回帰していないこと

### Acceptance Criterion

**Task 10.13 を `[x]` とする条件:**

```text
IPTW report → bootstrap percentile / resampling terminology
Bayesian report → posterior / ETI terminology
```

の両方を automated test で確認する。

---

## 4. H-02 — Silent Propensity Score Clipping

### Finding

PS estimation 後に:

```r
ps_raw <- stats::predict(fit, type = "response")
ps <- pmin(pmax(ps_raw, 1e-6), 1 - 1e-6)
```

として無条件 clipping が行われる。

つまり:

\[
10^{-6}
\le e_i
\le
1-10^{-6}
\]

に強制される。

しかしこの処理は:

- OpenSpec
- design.md
- SKILL.md
- evidence metadata
- draws metadata

に記録されていない。

### Risk

weak positivity / separation / quasi-separation による極端 PS が silent clipping により有限化されるため、以下が起こり得る。

```text
near-zero / near-one raw PS
        ↓
silent clipping
        ↓
finite weights
        ↓
analysis continues
        ↓
diagnostic layer sees only clipped PS
```

現在 `compute_ps_positivity_diagnostics()` に渡されるのも clipped PS であるため、raw PS distribution の severity を失う。

### Required Design Decision

以下のどちらかを明示的に採用する。

#### Option A — Clipping を正式な governed analysis policy にする

metadata:

```yaml
propensity_score_boundary_policy:
  mode: clamp
  lower: 1.0e-6
  upper: 0.999999
  clipped_low_count: ...
  clipped_high_count: ...
```

さらに:

- positivity diagnostics は raw PS と effective PS を分離
- clipping occurrence を diagnostic badge 化
- clipping threshold を configurable にするか、versioned contract とする

#### Option B — Clipping をやめる

raw PS を使用し、0/1 boundary / separation / extreme weight に対して governed warning / failure を定義する。

### Required Tests

- near-complete separation fixture
- raw PS が threshold 外に到達する fixture
- clipped count が metadata と一致
- positivity diagnostics が raw distribution を保持
- overlap failure / weak overlap warning を検証

### Acceptance Criterion

PS boundary operation が **silent operation ではなく machine-readable governed operation** になっていること。

---

## 5. H-03 — Raw Counts vs IPTW Weighted Risk Semantic Mixing

### Finding

shared contrast engine には raw:

```text
target_cohort.events
target_cohort.total
reference_cohort.events
reference_cohort.total
```

が入る。

その後 IPTW engine は:

```r
target_cohort$estimate_semantics <- "iptw_weighted_risk"
target_cohort$incidence_proportion <- obs_risks$p_target
target_cohort$estimate$value <- obs_risks$p_target
```

等だけを上書きする。

結果として:

```json
{
  "events": 20,
  "total": 100,
  "incidence_proportion": 0.31,
  "estimate_semantics": "iptw_weighted_risk"
}
```

のように、

\[
20/100 \ne 0.31
\]

という object が正規出力になり得る。

### Risk

machine consumer が `events / total` を incidence proportion の numerator / denominator と解釈すると誤った解析結果になる。

Section 9 では同種の問題を:

```text
raw descriptive counts
vs
ATT-weighted estimand
```

として分離済みであり、IPTW でも同じ原則を適用すべき。

### Required Repair

推奨:

```r
contrasts$target_cohort["events"] <- list(NULL)
contrasts$target_cohort["total"] <- list(NULL)

contrasts$reference_cohort["events"] <- list(NULL)
contrasts$reference_cohort["total"] <- list(NULL)
```

raw counts は既存:

```text
iptw.raw_patient_counts
```

へ集約する。

必要なら:

```text
target_cohort.estimate_semantics = "iptw_weighted_risk"
reference_cohort.estimate_semantics = "iptw_weighted_risk"
```

を schema enum として拘束する。

### Required Tests

- weighted risk が raw event proportion と異なる fixture
- cohort `events/total` が `null`
- `iptw.raw_patient_counts` に raw counts が存在
- weighted `estimate.value` が正しい
- schema negative test

### Acceptance Criterion

weighted estimand と raw descriptive count の semantics が同一 object 内で numerator/denominator 関係に見えないこと。

---

## 6. H-04 — Configurable Convergence Failure Threshold

### Finding

internal function:

```r
sample_iptw_bootstrap(
  ...,
  max_failure_rate = 0.05
)
```

は threshold を持つ。

しかし public entry point:

```r
run_iptw_inference()
```

に `max_failure_rate` 引数がない。

したがって caller は threshold を設定できない。

Task 10.11:

> Implement convergence monitoring with configurable failure threshold, failing fast if failure rate exceeds threshold, verified by test.

とは一致していない。

さらに test suite には:

```text
max_failure_rate
IPTW_CONVERGENCE_FAILURE
```

を直接検証する test が存在しない。

### Required Repair

public API:

```r
run_iptw_inference(
  ...,
  max_failure_rate = 0.05
)
```

を追加。

validation:

```text
numeric scalar
finite
0 <= max_failure_rate < 1
```

を推奨。

draws / evidence metadata に:

```text
bootstrap_diagnostics.max_failure_rate
```

も記録する。

### Required Tests

deterministic fixture を作成し:

```text
custom threshold honored
threshold exceeded → IPTW_CONVERGENCE_FAILURE
threshold not exceeded → completes
```

を検証する。

単に「正常 dataset で failure_rate <= 0.05」は threshold behavior の test ではない。

### Acceptance Criterion

Task 10.11 の `configurable` と `fail-fast` を public API と automated negative test の双方で証明する。

---

## 7. M-01 — Arm-Specific Truncation Test Is Ineffective

### Finding

test code は:

```r
raw_weights <- c(0.1, 0.5, 1.0, 5.0, 100.0, ...)
```

を作成するが、この vector は `compute_iptw_weights()` に渡されない。

実際には:

```r
ps = rep(0.5, 10)
```

を使用するため ATE weight はほぼ全員同じになる。

そのうえ:

```r
max(weight) <= 100
```

を確認しており、arm-specific percentile truncation の正確性を証明していない。

### Required Repair

既知 PS から極端 weight を生成し、arm ごとに quantile を手計算する。

例:

```text
T arm raw weights: known vector
R arm raw weights: known vector

expected q10 / q90 by arm
expected clamped values
```

として `all.equal(actual, expected)` を検証。

### Acceptance Criterion

- treatment arm の lower / upper percentile clipping
- control arm の lower / upper percentile clipping

をそれぞれ数値的に exact test する。

---

## 8. M-02 — Extreme Weight / Positivity Tests Missing

### Finding

`test_iptw_inference.R` には以下の verification がない。

```text
EXTREME_WEIGHTS_WARNING
weight_summary
positivity
has_overlap
```

Tasks 10.8 / 10.10 は `[x]` だが executable evidence が不足している。

### Required Tests

#### Extreme-weight test

意図的に極端 PS を生成し:

```text
EXTREME_WEIGHTS_WARNING
```

が付くことを検証。

#### Positivity test

PS distributions が重ならない / 極端に狭い overlap fixture を作成し:

```text
common_support.has_overlap
common_support.min
common_support.max
```

を検証。

必要なら diagnostic badge:

```text
NO_PROPENSITY_SCORE_OVERLAP
WEAK_PROPENSITY_SCORE_OVERLAP
```

等の導入を検討。

---

## 9. M-03 — Patient-Level Bootstrap Unit Contract

### Finding

SKILL / design は:

```text
1 row = 1 subject
Patient-level Bootstrap
```

を前提とする。

しかし:

```r
subject_id_col = NULL
```

は optional であり、指定しても uniqueness / duplicate check がない。

同じ患者が複数行あれば row-level bootstrap として扱われる。

### Required Repair

最低限:

```text
subject_id_col supplied:
  NA → reject
  duplicate → reject or explicit repeated-measurement routing error
```

を推奨。

より厳密には patient-level causal IPTW engine では subject ID を mandatory にすることも検討。

Section 12 の repeated-measurement routing と責務分担を明文化する。

### Acceptance Criterion

engine が repeated rows を暗黙に independent patients として扱わない。

---

## 10. M-04 — IPTW Draw Provenance Is Incomplete

### Finding

現在の `iptw_metadata` は主に:

```text
estimand
stabilization
effective_sample_size
bootstrap_diagnostics
```

を持つ。

しかし inference provenance として重要な:

```text
iptw_mode = "refit_ps"
truncation
att_scaling_mode
PS model / covariates
PS clipping policy
```

が detached draws payload から分からない。

### Required Repair

推奨 metadata:

```yaml
iptw_metadata:
  estimand: ATE | ATT
  iptw_mode: refit_ps
  stabilization: true | false
  att_scaling_mode: ...
  truncation:
    lower: ...
    upper: ...
  propensity_model:
    family: binomial
    link: logit
    covariates: [...]
  propensity_score_boundary_policy:
    ...
  effective_sample_size:
    ...
  bootstrap_diagnostics:
    ...
```

### Acceptance Criterion

draws object 単体から、主要な IPTW resampling / weighting policy を再構成できる。

---

## 11. Additional API Consistency Issue — ATT Stabilization

### Finding

以下の combination:

```text
estimand = ATT
stabilization = TRUE
att_scaling_mode = conventional
```

では実装上 conventional ATT:

\[
1,\quad \frac{e}{1-e}
\]

が返る。

しかし output は:

```text
stabilization = true
att_scaling_mode = conventional
```

となり、`stabilization=true` の意味が不明瞭。

### Recommendation

ATT は `stabilization` boolean ではなく:

```text
att_weight_scaling.mode =
  conventional
  marginal_odds_scaled
```

に一本化するか、

```text
stabilization=TRUE + conventional
```

を invalid combination とする。

**Severity: LOW–MEDIUM design clarity**

---

## 12. Repair Task List

以下を Section 10 Repair #1 のタスクとして推奨する。

| Task | Priority | Action | Verification |
|---|---|---|---|
| 10.R1 | **P0** | IPTW reporting を bootstrap terminology 対応 | integration narrative test |
| 10.R2 | **P0** | PS clipping / boundary policy を specification + metadata 化 | separation / clipping fixture |
| 10.R3 | **P0** | raw counts と weighted risk を cohort output で分離 | semantic fixture + schema test |
| 10.R4 | **P0** | `max_failure_rate` を public configurable API 化 | deterministic failure-path test |
| 10.R5 | **P1** | arm-specific truncation test を analytical test に置換 | exact expected weights |
| 10.R6 | **P1** | extreme-weight warning test を追加 | diagnostic assertion |
| 10.R7 | **P1** | positivity / no-overlap test を追加 | `has_overlap` + diagnostic |
| 10.R8 | **P1** | subject ID / repeated-row guard を追加 | duplicate subject fail-fast |
| 10.R9 | **P1** | `iptw_metadata` provenance を拡張 | schema positive/negative tests |
| 10.R10 | P2 | ATT stabilization API semantics を整理 | combination tests |
| 10.R11 | P2 | Section 10 tasks の false-complete checkbox を実装証拠に合わせて更新 | OpenSpec review |

---

## 13. Suggested Acceptance Tests

Section 10 Repair #1 後の最低限 acceptance suite:

### A. Weight Math

- unstabilized ATE exact
- stabilized ATE exact
- conventional ATT exact
- marginal-odds-scaled ATT exact

### B. Truncation

- treatment arm exact percentile clamp
- reference arm exact percentile clamp
- truncation disabled case
- invalid percentile ordering

### C. PS / Positivity

- normal overlap
- no overlap
- near separation
- clipping / boundary-policy metadata
- extreme weights warning

### D. Bootstrap

- PS is re-estimated per replicate
- fixed seed reproducibility
- custom failure threshold
- threshold exceeded fail-fast
- sufficient successful draws returned

### E. Output Semantics

- raw counts isolated under `iptw.raw_patient_counts`
- cohort estimates are weighted risks
- generic events / total do not imply pseudo numerator/denominator
- ESS present
- full IPTW provenance present

### F. Reporting

- bootstrap percentile terminology for IPTW
- bootstrap support fraction terminology
- no posterior / ETI wording in IPTW reports
- Bayesian reports retain posterior / ETI wording

### G. Schema

Negative tests for:

- missing IPTW estimand
- missing ESS
- invalid scaling mode
- missing refit mode
- missing truncation metadata if required
- invalid failure threshold
- invalid PS boundary policy

---

## 14. Proposed Gate Criteria

Section 10 を `ACCEPT` に変更する条件:

1. **High findings = 0**
2. H-01〜H-04 の regression tests がすべて PASS
3. Tasks 10.8 / 10.10 / 10.11 / 10.13 に executable verification evidence が存在
4. weighted estimand と raw counts の semantic separation が machine-readable
5. PS boundary / positivity behavior が silent operation ではない
6. full canonical regression suite PASS
7. `openspec validate comparative-evidence-reporting-v3 --strict --json` = 0 errors
8. `git diff --check` clean
9. unresolved Medium findings が Owner-adjudicated

---

## 15. Final QA Position

### Current Gate

```text
Phase 2 Section 10 — IPTW
Acceptance Gate: HOLD
```

### Rationale

現実装は「IPTW 数式が成立していない」状態ではない。

むしろ:

\[
\text{Core statistical computation}
\approx
\text{sound}
\]

である一方、

\[
\text{Governance}
+
\text{diagnostic transparency}
+
\text{output semantics}
+
\text{reporting semantics}
\]

が completion criteria に達していない。

RWD / pharmacoepidemiology では、positivity、weight instability、PS model provenance、weighted/raw quantity の識別は最終的な解釈可能性に直結するため、Section 10 freeze 前に修復する価値が高い。

---

## 16. 提案

Section 10 は全面再実装せず、**Repair #1 を contract-hardening sprint として限定実施**することを推奨する。

優先順:

```text
Reporting semantics
→ PS/positivity governance
→ weighted/raw output separation
→ configurable convergence threshold
→ diagnostic / truncation tests
→ provenance schema
```

この順なら core estimator をほぼ変更せず、QA上の主要リスクを閉じられる。

---

## 17. 批判的立場

今回最も注意すべき点は、「数式テストが通ること」と「IPTW evidence system として安全に解釈できること」は同義ではないことである。

特に silent PS clipping、posterior terminology の downstream reuse、raw counts と weighted risks の同居は、結果数値がもっともらしいまま semantic error を残しやすい。

したがって次回 Acceptance Gate では、単純な PASS 件数よりも **推論 semantics と provenance が end-to-end で保持されること**を重点確認する。
