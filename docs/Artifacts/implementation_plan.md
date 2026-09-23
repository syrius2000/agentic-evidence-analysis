# Implementation Plan: Comparative Evidence Reporting / Design-Aware Inference / Decision Review

created: 2026-09-23 (JST)  
status: proposal / implementation not authorized  
target repository: `syrius2000/agentic-evidence-analysis`  
proposed OpenSpec change: `comparative-evidence-reporting-v3`

## 0. Executive decision

### Repository decision

本変更は **`agentic-evidence-analysis` に実装する**。

理由:

1. 現行 `AGENTS.md` は本リポジトリを「統計解析・エビデンス分析スキル、統計schema、統計品質契約、Rテンプレート、回帰テストの唯一の正本」と定義している。
2. `openspec/specs/` が規範的挙動（WHAT）の唯一の正本であり、今回の変更は統計estimand、推論方式、出力schema、品質ゲートを同時に変更するため、別repo化するとSpec driftのリスクが高い。
3. RWD/DB実行・データ取得は既存方針どおり外部ハブに残し、本repoは **統計契約・計算・レポート意味論** を担当する。
4. 将来 `evidence-decision-review` が永続DB、組織横断ワークフロー、規制文書管理システム等へ発展した場合、実行アプリだけ別repoへ分離してよい。ただし canonical schema と statistical contract は本repoを正本としてversion pinする。

### Top-level architecture

既存名 `vcd-categorical-reporting` は保持するが、deprecated legacy templateから次の責務へ刷新する。

1. **Pass 0 Consultation Gateway**
   - estimand / analysis unit / design / domain / practical delta / reporting purpose を確定
   - 解析経路をrouting
2. **`vcd-categorical-reporting`**
   - independent binary comparisonを直接計算
   - design-aware engineから受領したdrawsも同一contrast layerで処理
   - Safety / RWD / Prescription profileを表示
3. **`comparative-design-analysis`（新規）**
   - IPTW / matching / matched sets / cluster-aware / rate design等
   - target/referenceのuncertainty draws + design diagnosticsを生成
4. **`evidence-decision-review`（新規）**
   - clustering / nearest precedent / historical decision ledger / discordance QA / trajectory
   - 最終判断は行わない

---

## 1. Background and problem statement

実務では、治験安全性、市販後調査、RWD、購入処方データで次の比較が大量に発生する。

\[
x_T/n_T \quad \text{vs} \quad x_R/n_R
\]

従来の報告では、Fisher検定、Wald系CI、`0を跨ぐ/跨がない` といった二値的解釈に偏りやすい。特に安全性では標本数・イベント数が小さく、例えば `3 vs 0`, `1/200 vs 0/1000`, `0/200 vs 2/1000` が頻発するため、raw RRが未定義、CIが極端に広い、検出力不足、といった問題が常態化する。

本変更では、以下を分離して同時に表示する。

- **Effect magnitude**: RD, RR, excess per 100
- **Direction**: target > reference の支持
- **Practical relevance**: \(P(RD>\delta)\)
- **Uncertainty**: CrI / resampling interval / U-grade / sparse flags
- **Domain context**: Safety SOC/PT, RWD category/item, prescription class/product
- **Decision consistency**: 過去判断との類似・不整合（別Skill）

---

## 2. Scope

### 2.1 In scope — Version 3.0 Core

- Pass 0をStatistical Consultation Gatewayへ拡張
- `vcd-categorical-reporting` deprecated解除・責務再定義
- 独立2群のbinary proportion比較
- Jeffreys prior \(Beta(0.5,0.5)\)
- zero-cellを含むposterior inference
- multi-theme batch
- multi-group explicit contrasts / reference-vs-all
- RD / RR / excess per 100
- posterior median / 95% ETI
- \(P(RD>0)\)
- prespecified \(\delta\) がある場合の \(P(RD>\delta)\), \(P(|RD|\le\delta)\), \(P(RD<-\delta)\)
- delta profile
- H/N/B region + U0–U3 uncertainty classification
- Safety SOC/PT adapter
- RWD generic parent/item adapter
- Prescription parent/item adapter
- domain-neutral canonical JSON schema
- HTML/Markdown report
- zero/sparse/RR-instability diagnostics
- classical compatibility columns (raw proportion, optional Fisher) but no p-value-first narrative

### 2.2 In scope — Version 3.5 Design-aware

新Skill `comparative-design-analysis`:

- 1:1 matching: 4-cell Dirichlet posterior
- 1:k matching: matched-set bootstrap
- IPTW: patient bootstrap with propensity-score re-estimation
- ATE / ATT metadata
- weight diagnostics, ESS, balance diagnostics, positivity warnings
- person-time rate: Gamma-Poisson
- cluster bootstrap extension point
- standardized `comparative-draws-v1` output

### 2.3 In scope — Version 4.0 Decision intelligence

新Skill `evidence-decision-review`:

- Evidence feature matrix
- Gower + hierarchical clustering as primary mixed-feature clustering
- K-means as optional standardized continuous-only exploratory view
- cluster stability
- nearest historical precedent retrieval
- decision ledger
- decision discordance QA
- temporal signal trajectory
- no automated label inclusion / causality / benefit-risk decision

### 2.4 Out of scope for initial implementation

- automatic causality determination
- automatic CTD / label inclusion decision
- automatic pharmacovigilance signal confirmation
- joint fully Bayesian propensity + outcome model
- automatic HLT/HLGT primary reporting
- unvalidated universal practical-difference threshold
- combining multiple evidence dimensions into a single opaque score
- rewriting or deleting legacy artifacts without explicit migration plan

---

## 3. Canonical statistical contract

### 3.1 Independent binary comparison

For theme \(k\), group \(g\):

\[
X_{kg}\sim Binomial(n_{kg},p_{kg})
\]

Primary prior:

\[
p_{kg}\sim Beta(0.5,0.5)
\]

Posterior:

\[
p_{kg}|D \sim Beta(x_{kg}+0.5,n_{kg}-x_{kg}+0.5)
\]

For each contrast target \(T\) vs reference \(R\):

\[
RD=p_T-p_R
\]

\[
RR=\frac{p_T}{p_R}
\]

\[
E100=100RD
\]

Primary summaries:

- target/reference posterior median, q025, q975
- RD median, q025, q975
- RR median, q025, q975
- \(P(RD>0)\)
- delta profile \(G(\delta)=P(RD>\delta)\)

### 3.2 Zero-cell contract

If reference observed events = 0 under Jeffreys prior:

\[
p_R|D\sim Beta(0.5,n_R+0.5)
\]

RR posterior draws are valid, but

\[
E(1/p_R)=\infty
\]

when the posterior Beta shape for \(p_R\) is \(\le 1\); therefore posterior mean RR is not a canonical summary.

Required behavior:

- `rr_median`: finite when numerically valid
- `rr_q025`, `rr_q975`
- `rr_mean`: `null`
- `rr_mean_state`: `NONFINITE_EXPECTATION` when mathematically non-finite
- no Monte-Carlo sample mean shall be presented as if the true posterior expectation were finite
- `ZERO_REFERENCE` / `ZERO_TARGET` flags
- `RR_UNSTABLE` flag based on log-RR interval diagnostics, not as a clinical severity flag

### 3.3 Excess per 100 and reciprocal RD

\[
E100=100RD
\]

This is a canonical domain-neutral quantity.

Domain labels:
- Safety: additional adverse-event subjects per 100 treated
- RWD: additional cases per 100 persons
- Prescription: additional users/prescriptions per 100 eligible persons

The reciprocal:

\[
1/|RD|
\]

is stored as a **secondary clinical translation**, not a primary estimand.

Rules:
- Core field is domain-neutral (`reciprocal_absolute_rd`)
- Safety adapter may render NNH/NNT-like wording depending on direction
- no naive continuous reciprocal CI shall be displayed across RD = 0
- display shall be suppressible when directional mass is insufficient or posterior includes substantial sign ambiguity

### 3.4 Practical difference \(\delta\)

`primary_delta` MUST NOT have a universal default.

Three modes:

1. `prespecified`: explicit SOP/SAP/medical threshold
2. `policy`: versioned event-class threshold policy
3. `null`: no approved primary delta

Always allow a delta profile, for example:

```yaml
delta_profile:
  - 0
  - 0.001
  - 0.0025
  - 0.005
  - 0.01
  - 0.02
```

If `primary_delta = null`:
- calculate direction \(P(RD>0)\)
- calculate the delta profile
- do not assign H/N/B practical region
- do not assign delta-dependent U-grade
- report `classification_status = NOT_CLASSIFIED`

If a prespecified delta exists:

\[
q_H=P(RD>\delta)
\]

\[
q_N=P(|RD|\le\delta)
\]

\[
q_B=P(RD<-\delta)
\]

and \(q_H+q_N+q_B=1\).

### 3.5 Uncertainty grade and color contract

Provisional presentation classification:

\[
C=\max(q_H,q_N,q_B)
\]

- U0: \(C \ge 0.95\)
- U1: \(0.80 \le C < 0.95\)
- U2: \(0.60 \le C < 0.80\)
- U3: \(C < 0.60\)

These thresholds are **presentation defaults only**, not regulatory or clinical decision thresholds. They MUST be configurable, versioned, and validated by simulation and historical-case review before SOP adoption.

Color rules:
- hue = dominant practical region (H red family / N neutral gray / B blue family)
- saturation/opacity = uncertainty grade
- U3 uses minimal saturation / hatch / explicit label
- **IRON LAW: never color by posterior direction alone**
- if `primary_delta=null`, practical-region color coding is disabled

Independent diagnostics remain visible:
- `ZERO_TARGET`
- `ZERO_REFERENCE`
- `SPARSE_LT5`
- `SPARSE_LT10`
- `RR_UNSTABLE`
- design-specific diagnostics

### 3.6 Bootstrap semantics

For IPTW/matched-set bootstrap outputs, the common contrast layer may calculate the same numerical transforms, but MUST NOT call bootstrap fractions posterior probabilities.

Schema requires:

```text
inferential_semantics = posterior | bootstrap
```

Examples:
- posterior: `posterior_probability_rd_gt_zero`
- bootstrap: `bootstrap_support_fraction_rd_gt_zero`

AI narrative and dashboard labels MUST derive wording from this field.

---

## 4. Pass 0 Consultation Gateway

### 4.1 Required decisions

Pass 0 SHALL determine or explicitly defer:

1. domain: safety / rwd / prescription / generic
2. estimand: subject risk / rate / other
3. analysis unit: subject / matched pair / matched set / cluster / person-time
4. target and reference direction
5. independent vs matched vs weighted vs repeated/clustered
6. practical delta status and natural unit
7. hierarchy: parent/item
8. reporting purpose: exploratory / regulatory / descriptive / decision-support
9. decision-history review required or not

### 4.2 Automated inspection

Where possible inspect automatically:
- integer/non-integer counts
- duplicate subject IDs
- weight column
- matching/set IDs
- person-time fields
- SOC/PT fields
- MedDRA version metadata
- study IDs
- denominator consistency
- zero/sparse cells

### 4.3 Artifacts

Pass 0 SHALL emit:

1. `analysis_config.json`
2. `analysis_scope.md`
3. `routing_decision.json`

`routing_decision.json` records:
- selected route
- reasons
- rejected routes
- unresolved blockers
- whether owner approval is still required

Pass 0 is a consultation/gatekeeper, not an autopilot. Estimand, ATE/ATT, primary delta, and regulatory purpose must be explicitly recorded, not silently inferred when material.

---

## 5. Domain adapters

### 5.1 Safety

Canonical primary hierarchy:

\[
Study \rightarrow SOC \rightarrow PT
\]

Rules:
- Primary SOC for standard aggregation
- SOC/PT are primary report hierarchy
- HLT/HLGT retained as optional drill-down, not required primary output
- MedDRA version required provenance
- subject-level incidence uses one subject once per PT and once per SOC
- invariant: \(0 \le n_{SOC}\le N\)
- SOC count is not the sum of child PT subject counts
- maintain study-specific results even when pooled result is generated

Recommended safety columns:
- SOC/PT
- target n/N (%)
- reference n/N (%)
- RD [interval]
- excess per 100
- direction support
- practical-excess support
- RR [interval]
- uncertainty grade
- sparse/zero flags

### 5.2 RWD

Generic hierarchy:

```text
parent_theme -> item_theme
```

Examples:
- ICD category -> diagnosis
- procedure class -> procedure
- drug class -> drug

Required provenance:
- population definition
- index date
- exposure definition
- follow-up window
- denominator definition
- design/weighting method

### 5.3 Prescription data

Same canonical comparison kernel.

Examples:
- drug class -> ingredient
- therapeutic class -> product
- treatment pattern -> item

Domain adapter changes labels, not statistics.

---

## 6. Design-aware inference skill

### 6.1 1:1 matched binary data

Four-cell paired distribution:

\[
(\pi_{11},\pi_{10},\pi_{01},\pi_{00})
\]

Primary prior:

\[
Dirichlet(0.5,0.5,0.5,0.5)
\]

Posterior draws yield:

\[
p_T=\pi_{11}+\pi_{10}
\]

\[
p_R=\pi_{11}+\pi_{01}
\]

\[
RD=\pi_{10}-\pi_{01}
\]

and RR from marginal risks.

### 6.2 1:k matching

Primary v3.5 implementation:
- resample matched sets, not individual rows
- calculate target/reference risks for every replicate
- return `draw_type=bootstrap`

Required metadata:
- matching ratio
- with/without replacement
- caliper
- matched set count
- discarded count
- balance diagnostics

### 6.3 IPTW

Primary v3.5 implementation:
- patient-level bootstrap
- re-fit propensity model in every replicate
- recompute weights
- apply prespecified truncation/stabilization
- recompute weighted marginal risks

Required:
- ATE/ATT
- propensity model provenance
- pre/post weighting SMD
- weight quantiles
- max weight
- group ESS: \(ESS=(\sum w)^2/\sum w^2\)
- positivity/overlap diagnostic
- bootstrap failure rate

Weighted pseudo-counts MUST NOT be silently passed to Jeffreys Beta-Binomial.

### 6.4 Person-time

For event counts \(Y_g\), exposure \(T_g\):

\[
Y_g\sim Poisson(\lambda_g T_g)
\]

Jeffreys-type rate prior yields Gamma posterior.

Output:
- target/reference rates
- IRD
- IRR
- rate-difference profile
- uncertainty semantics = posterior

### 6.5 Cluster/repeated observations

v3.5 SHALL support:
- patient-level aggregation back to one Bernoulli observation when estimand permits
- cluster bootstrap extension

GLMM/GEE/full hierarchical causal models remain extension points unless independently specified and validated.

---

## 7. Common draw interface

New schema: `comparative-draws-v1`.

Minimum fields:

```text
draw_id
target_value
reference_value
scale = risk | rate
inferential_semantics = posterior | bootstrap
method
estimand
```

Design diagnostics are attached separately.

The common contrast engine consumes this interface and is the ONLY implementation of:
- RD/IRD
- RR/IRR
- excess per natural unit
- direction support
- practical-difference profile
- H/N/B and U-grade
- quantile summaries

Golden requirement: the same draw table MUST yield bitwise-identical contrast output regardless of originating domain adapter.

---

## 8. Canonical evidence output

New schema: `comparative-evidence-v1`.

Required top-level groups:

```text
meta
context
theme
contrast_definition
group_summaries
effect
direction
practical_difference
uncertainty
diagnostics
provenance
```

No Safety-specific field is allowed in the statistical core. Safety/RWD/Prescription metadata MAY appear under domain-specific context extensions.

---

## 9. Decision intelligence skill

### 9.1 Scope

Consumes finalized comparative evidence, not raw clinical rows.

Features:
- evidence similarity
- mixed-feature clustering
- nearest historical precedents
- historical decision ledger
- decision discordance flag
- trajectory over study/development/post-marketing stages

### 9.2 Clustering

Primary:
- Gower distance
- hierarchical clustering

Optional:
- K-means on explicitly standardized continuous-only feature subset

Decision variables (`included/not included/deferred`) MUST NOT be used to create evidence clusters. They are overlaid after clustering.

### 9.3 Cluster stability

Cluster assignment SHALL be marked exploratory unless stability is assessed. Possible implementation: resampling or uncertainty-draw perturbation with co-clustering probability / assignment stability.

No cluster ID may directly trigger a regulatory decision.

### 9.4 Decision discordance

Candidate discrepancy:

\[
distance(i,j)<\epsilon
\]

AND

\[
decision_i\ne decision_j
\]

This is a QA flag only. System wording: “similar evidence, different recorded decision — review rationale”. Never “decision error” without human adjudication.

### 9.5 Historical ledger

Minimum:
- item identity and hierarchy
- evidence version
- decision status
- rationale codes/text
- date/version
- reviewer/owner provenance if available
- source references

---

## 10. OpenSpec plan

Create active change:

```text
openspec/changes/comparative-evidence-reporting-v3/
├── proposal.md
├── design.md
├── tasks.md
└── specs/
    ├── pass0-analysis-routing/spec.md
    ├── comparative-evidence-reporting/spec.md
    ├── comparative-design-inference/spec.md
    └── evidence-decision-consistency/spec.md
```

Expected canonical specs after acceptance/archive:
- `openspec/specs/pass0-analysis-routing/`
- `openspec/specs/comparative-evidence-reporting/`
- `openspec/specs/comparative-design-inference/`
- `openspec/specs/evidence-decision-consistency/`

Existing `two-way-evidence-analysis` remains for contingency-table association/residual analysis. Do not redefine it as the new binary comparative reporting spec.

---

## 11. Proposed code layout

```text
.agents/
├── shared/
│   └── comparative/
│       ├── contrast_engine.R
│       ├── uncertainty_classification.R
│       ├── schemas/
│       └── validators.R
└── skills/
    ├── vcd-pass0-consultation/
    ├── vcd-categorical-reporting/
    │   ├── R/
    │   │   ├── independent_beta_binomial.R
    │   │   ├── batch_comparison.R
    │   │   └── domain_adapters.R
    │   └── references/
    ├── comparative-design-analysis/
    │   ├── R/
    │   │   ├── matched_pair_dirichlet.R
    │   │   ├── matched_set_bootstrap.R
    │   │   ├── iptw_bootstrap.R
    │   │   └── gamma_poisson_rate.R
    │   └── references/
    └── evidence-decision-review/
        ├── R/
        │   ├── evidence_features.R
        │   ├── clustering.R
        │   ├── stability.R
        │   └── discordance.R
        └── references/
```

Avoid duplicating contrast formulas across skills.

---

## 12. Test strategy

### 12.1 Mathematical golden cases

At minimum:

1. `3/100 vs 0/100`
2. `0/100 vs 0/100`
3. `30/100 vs 20/100`
4. `3/30 vs 30/300`
5. `1/200 vs 0/1000`
6. `1/200 vs 2/1000`
7. `0/200 vs 2/1000`

Assertions:
- posterior propriety
- quantile ordering
- RD finite
- zero-reference RR mean state is non-finite when mathematically required
- RR median/quantiles finite when computationally valid
- delta-profile monotonicity
- H/N/B probabilities sum to 1
- U-grade boundary tests
- `primary_delta=null` disables H/N/B color classification

### 12.2 Safety aggregation tests

- repeated PT events from same subject count once
- subject with multiple PTs in same SOC counts once at SOC level
- Primary SOC-only standard aggregation
- MedDRA version recorded
- SOC count never exceeds denominator
- pooled and study-specific outputs remain traceable

### 12.3 Domain invariance tests

The same canonical counts must produce identical statistical JSON under Safety, RWD, and Prescription labels. Only presentation/context may differ.

### 12.4 Matching tests

1:1:
- Dirichlet draws sum to 1
- marginal risks correct
- RD equals \(\pi_{10}-\pi_{01}\)
- symmetric discordant counts yield centered RD

1:k:
- matched sets resampled as units
- no row-level split of sets

### 12.5 IPTW tests

- non-integer weighted events are never accepted by Beta-Binomial engine
- PS refit occurs inside bootstrap
- ATE/ATT metadata binding
- ESS exact formula
- extreme-weight warning
- balance diagnostics before/after
- bootstrap failure rate
- result wording is bootstrap, not posterior

### 12.6 Decision review tests

- identical evidence vectors have zero distance
- evidence cluster construction excludes decision label
- same evidence + different decision -> discordance candidate
- discordance never auto-classified as error
- K-means rejects mixed nonstandardized feature input
- cluster stability recorded or explicitly unavailable

### 12.7 Regression / repository tests

- `openspec validate --strict`
- `Rscript tests/run_regression_suite.R`
- `python3 tests/test_skill_ownership_contract.py`
- `python3 scripts/test_doc_consistency.py`
- `git diff --check`
- Zero-External-Asset checks
- evidence run isolation tests

---

## 13. Migration strategy

### Phase A — Specification only
- create OpenSpec change
- add proposal/design/specs/tasks
- update no production code
- resolve naming and schema review
- owner approval required

### Phase B — Core reporting
- shared contrast engine
- independent Jeffreys engine
- canonical schemas
- Pass 0 routing
- generic/Safety/RWD/Prescription profiles
- tests

### Phase C — Design-aware
- matched pair
- matched set
- IPTW
- person-time
- diagnostics
- tests

### Phase D — Decision intelligence
- feature schema
- historical ledger interface
- clustering/similarity
- discordance
- stability
- trajectory

### Phase E — Migration of legacy reporting
Only after B–D validation:
- remove deprecated marker from `vcd-categorical-reporting`
- update ownership/reference docs
- keep legacy template compatibility explicitly versioned
- do not silently reinterpret old outputs

---

## 14. Acceptance criteria

Implementation is not complete unless:

1. OpenSpec strict validation passes.
2. Single canonical contrast engine exists.
3. zero-cell golden tests pass.
4. RR non-finite-mean contract is enforced.
5. delta profile is generated without inventing a primary delta.
6. H/N/B × U-grade is only produced when primary delta is approved.
7. color cannot be driven by direction probability alone.
8. Safety SOC/PT subject-level aggregation invariants pass.
9. matching/IPTW semantics are design-specific and not silently treated as independent binomial.
10. posterior vs bootstrap wording is schema-driven.
11. decision clustering cannot make regulatory decisions.
12. all existing canonical regression tests remain passing.
13. documents and `skill_responsibilities.md` are synchronized from accepted Spec.
14. owner reviews verification evidence before archive.

---

## 15. Critical risks

### Risk 1 — Scope explosion
Mitigation: implement in B/C/D phases; do not merge Decision Intelligence into statistical core.

### Risk 2 — Bayesian threshold becomes a new p-value
Mitigation: no single probability alone drives color or decision; effect, practical relevance, uncertainty remain separate.

### Risk 3 — Arbitrary delta becomes policy
Mitigation: no universal default; profile always available; primary classification only with prespecified/policy delta.

### Risk 4 — Weighted pseudo-count misuse
Mitigation: Beta-Binomial engine accepts only integer independent-binomial counts; IPTW routes elsewhere.

### Risk 5 — Cluster becomes decision rule
Mitigation: clustering is information organization/QA only; decisions overlaid after clustering.

### Risk 6 — Repository split creates drift
Mitigation: keep statistical contracts and schemas here; split only external execution service later if operationally necessary.

---

## 16. Recommended first implementation slice

Implement only the smallest end-to-end vertical slice:

1. Pass 0 route for `independent_binary`
2. generic canonical long input: `theme / target_event / target_n / reference_event / reference_n`
3. Jeffreys Beta-Binomial
4. RD / RR / E100 / direction / delta profile
5. zero/sparse flags
6. `primary_delta=null` and explicit-delta modes
7. Safety SOC/PT adapter
8. one offline HTML/Markdown report
9. golden test suite

Do not begin IPTW, clustering, or historical decision review until this slice passes independent QA.
