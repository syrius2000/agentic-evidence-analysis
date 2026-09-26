# Draft Implementation Plan 023: Evidence Signature Map with Gower / PCoA / Clustering

## 1. Status

- Proposed future change: `comparative-evidence-exploration-v1`
- Status: DRAFT — design discussion required before OpenSpec change creation
- Relationship to current v3: separate analytical extension; do not block `comparative-evidence-reporting-v3` archive once Plan 022 and Section 16 are accepted.
- Primary concept: compress exact repeated evidence patterns into Evidence Signatures, then visualize similarity with Gower distance + PCoA and optional HAC clustering.

---

## 2. Why this should be a separate change

CSV/filter/accordion are reporting-layer changes. Gower/PCoA/clustering changes the analytical layer by introducing:

- a new unit of analysis (Evidence Signature)
- a new distance-to-coordinate transformation
- optional clustering semantics
- new visualization encodings
- new provenance and reproducibility requirements

Therefore this should not be added as a late UI patch to Section 14.

---

## 3. Empirical motivation from `examples/Drug-Safty-example.csv`

Independent repository inspection of the current example gives:

```text
rows                                      = 250
unique (Drug,Dsize,Placebo,Psize) patterns = 67
duplicate pattern groups                    = 20
rows belonging to repeated patterns         = 203 / 250 = 81.2%
```

largest repeated patterns include:

```text
(1,219,0,219) -> 77 PT rows
(0,219,1,219) -> 50 PT rows
(2,219,0,219) -> 14 PT rows
(3,219,0,219) -> 8 PT rows
(1,219,1,219) -> 8 PT rows
```

250 labelsをそのまま Euclidean clustering に投入すると、頻出 count pattern がクラスタ中心を過度に支配する。

したがって最初に exact-equivalence compression を行う。

---

## 4. Evidence Signature layer

### 4.1 Initial scope

v1 の exact Evidence Signature はまず independent two-group count evidence を対象とする。

canonical key candidate:

```text
inferential_semantics
target_events
target_total
reference_events
reference_total
primary_delta
interval_level
model/prior version
```

PT/SOC label は signature key に含めず metadata membership とする。

### 4.2 Why labels are excluded

同じ count evidence で PT 名だけ異なるケースは同じ統計モデル・同じ入力状態を表す。

Signature は統計的同値クラスであり、医学用語同値クラスではない。

### 4.3 Design-aware evidence

IPTW / matched-set / matched-pair 等は raw counts が同じでも design-aware evidence が異なり得る。

そのため v1 では以下のいずれかを選ぶ必要がある。

- Option A (recommended): independent count evidence のみ exact signature compression; design-aware rows are one-case-per-signature
- Option B: design-specific provenance fieldsを signature key に追加
- Option C: canonical evidence-feature hashを signature とする

Option A を初期推奨とする。

### 4.4 Signature output

新規 artifact candidate:

`evidence_signature_summary.csv`

最低限の列:

- signature_id
- inferential_semantics
- target_events / target_total
- reference_events / reference_total
- multiplicity
- SOC count
- PT count
- member labels / member row keys
- representative evidence feature ID

### 4.5 Weighting contract

primary map / clustering では **1 signature = 1 observation** を default とする。

`multiplicity` は point size / tooltip / descriptive summary にのみ使用し、distance/clustering weight には使用しない。

これにより `(1,219,0,219)` の77重複が geometry を77倍支配することを防ぐ。

---

## 5. Feature space

既存 `evidence-feature-v1` と `.agents/shared/evidence_feature_extract.R` を再利用する。

既存 core clustering features:

- `rd_estimate`
- `rd_interval_width`
- `direction_support`
- `resolution_grade`
- `rr_mean_is_finite`
- `has_zero_reference`
- `target_n`
- `reference_n`
- `quarantine_flag_count`

delta-dependent:

- `primary_delta`
- `target_excess`
- `practical_neutral`
- `reference_excess`

### 5.1 Recommended two-map model

delta sensitivity を明確化するため2 view を推奨する。

#### Core Evidence Map

delta-independent core keys only.

目的: `primary_delta` を変更しても比較可能な evidence geometry。

#### Practical Evidence Map

core + delta-dependent keys.

目的: active practical threshold 下での region-resolution structure を可視化。

---

## 6. Gower distance

既存 `.agents/shared/evidence_gower.R` と frozen-reference-range contract を再利用する。

Gower を primary distance とする理由:

- numeric + categorical mixed features を扱える
- U-Grade を人工的な連続値として K-means に押し込まなくてよい
- zero-reference boolean / grade / continuous RD を同一 framework に置ける
- existing frozen range / warning / version contract を再利用できる

decision labels / regulatory outcomes は距離 feature に含めない。

---

## 7. PCoA

### 7.1 Definition

Gower distance matrix `D` から principal coordinates を得る。

```math
J = I - (1/n) 11^T
B = -1/2 J D^2 J
B = V Lambda V^T
X_k = V_k Lambda_k^(1/2)
```

primary output は Axis 1 / Axis 2 とする。

### 7.2 Non-Euclidean diagnostics

Gower dissimilarity は負の eigenvalue を生じ得る。

PCoA result は必ず以下を記録する。

- positive eigenvalues
- negative eigenvalues
- negative inertia fraction
- axis explained positive inertia

material negative inertia が存在する場合は additive correction を用いるかを明示する。

初期推奨:

- uncorrected result を diagnostic として計算
- negative inertia が preset threshold を超える場合 `stats::cmdscale(..., add=TRUE)` 相当の correction を適用
- correction constant / method を provenance に記録

threshold は実装前 Owner decision とする。

---

## 8. Clustering

### 8.1 Primary clustering

既存 `.agents/shared/evidence_cluster.R` の HAC over Gower を再利用する。

allowed linkage:

- average
- complete
- single

Ward linkage は使用しない。

### 8.2 Cluster count

v1 では cluster overlay を optional とし、強制的な自動 k 選択はしないことを推奨する。

初期 contract:

- map は k 無しでも表示可能
- cluster overlay を使う場合は explicit `k`
- silhouette-based k suggestion は将来拡張

### 8.3 K-means

K-means は primary method にしない。

既存実装どおり、continuous standardized features に限定した secondary sensitivity analysis とする。

categorical U-Grade / badges / region を数値化して K-means に直接投入しない。

---

## 9. Visualization design

primary interactive/self-contained view:

```text
x/y position    = PCoA Axis 1 / Axis 2
fill hue        = practical region
point size      = signature multiplicity
point shape     = U-Grade
stroke/border   = diagnostic presence
tooltip/details = signature counts + SOC/PT members + RD/RR/support
```

cluster membership を色に使うと practical region hue と競合するため、cluster は次のいずれかを使う。

- hull / contour
- outer ring
- cluster label
- toggleable secondary view

SOC/PT は default clustering feature にせず metadata/filter/tooltip とする。

---

## 10. Proposed artifacts

- `evidence_signature_summary.csv`
- `evidence_signature_membership.csv`
- `evidence_map.json`
- `evidence_map.html`
- optional `evidence_cluster_summary.csv`

`evidence_map.json` は以下を provenance-bind する。

- feature schema version
- frozen range version
- Gower keys
- signature definition version
- PCoA correction method
- eigen diagnostics
- clustering method/linkage/k if active

---

## 11. Proposed implementation modules

Reuse:

- `.agents/shared/evidence_feature_extract.R`
- `.agents/shared/evidence_gower.R`
- `.agents/shared/evidence_cluster.R`

New modules candidate:

- `.agents/shared/evidence_signature.R`
- `.agents/shared/evidence_pcoa.R`
- `.agents/skills/vcd-categorical-reporting/evidence_map_reporting.R` or a dedicated exploration skill

専用 skill 化する場合は current nine-skill ownership contract への影響があるため、OpenSpec design phase で決定する。

---

## 12. Acceptance fixtures

### 12.1 Drug Safety duplicate compression

`examples/Drug-Safty-example.csv` について independent exact-count signature mode で:

```text
input rows = 250
unique exact count signatures = 67
```

を deterministic fixture とする。

`(1,219,0,219)` signature multiplicity = 77 を確認する。

`(0,219,1,219)` signature multiplicity = 50 を確認する。

### 12.2 No duplicate weighting

signature map geometry が member count を重複投入していないことを検証する。

### 12.3 Gower invariants

- symmetric matrix
- diagonal zero
- finite range [0,1]
- feature version/frozen range binding
- no decision-label feature

### 12.4 PCoA

- deterministic coordinates up to sign reflection
- eigenvalue diagnostics present
- sign-invariant pairwise geometry tests
- correction provenance when applied

### 12.5 HAC overlay

- explicit k required
- allowed linkage only
- cluster assignment is exploratory-only
- cluster result never generates decision labels

---

## 13. Owner decision points before implementation

以下は追加議論が必要。

### D1. Signature scope

Recommendation: v1 は independent count evidence の exact signature を正式対象とし、design-aware evidence は collapse しない。

### D2. Core Map vs Practical Map

Recommendation: 両方提供する。Core を default、Practical を toggle view。

### D3. PCoA negative-eigenvalue correction

Recommendation: diagnostic threshold を事前規定し、threshold 超過時だけ additive correction。具体 threshold は議論して固定する。

### D4. Cluster k

Recommendation: v1 は explicit k のみ。自動最適 k は実装しない。

### D5. SOC/PT role

Recommendation: metadata/filter only。clustering feature には含めない。

### D6. Multiplicity weighting

Recommendation: geometry/clustering は unweighted、point size のみ multiplicity。

---

## 14. Suggested development sequence

```text
Design discussion D1–D6
  ↓
new OpenSpec change: comparative-evidence-exploration-v1
  ↓
Evidence Signature schema + deterministic compression
  ↓
reuse evidence-feature-v1 / Gower
  ↓
PCoA + eigen diagnostics
  ↓
self-contained Evidence Map
  ↓
optional HAC overlay
  ↓
Drug-Safety 250 -> 67 acceptance fixture
  ↓
independent QA
```

---

## 15. Deferred ideas

次は v1 から外す。

- MCA as primary visualization
- automated silhouette/gap-statistic k selection
- supervised decision prediction
- regulatory outcome labels
- patient-level causal inference changes
- multiplicity-weighted clustering

MCA は categorical-only exploratory expert view として将来検討可能だが、mixed evidence の primary representation は Gower/PCoA を推奨する。
