# Independent Review — Phase 2 Section 9: 1:k Matched Sets Inference Engine Repair

**Repository:** `syrius2000/agentic-evidence-analysis`
**Branch:** `feat/comparative-evidence-reporting-v3`
**Reviewed commit:** `e8b7726803e50dfbf36d0004ca18ef28083c9377`
**Baseline commit:** `51f846b8ea8db7604156fc1b1a65b3a15310773b`
**Branch merge-base (vs main):** `8174a47003c133ba7bd16d86f9130253fd10c28e`
**Review date:** 2026-09-23 (JST)
**Target:** Phase 2 Section 9 — 1:k Matched Sets Inference Engine Repair
**Review type:** Independent implementation review / acceptance gate

---

## 1. Executive Summary

### 結論

**Verdict: HOLD**

今回の修正は、前回レビューで指摘された主要な統計・契約上の問題をかなり適切に修復している。
特に以下は改善が確認できた。

- ATT 点推定量の定義
- variable-ratio matching に対する ATT 重み
- matched-set 単位の atomic bootstrap
- raw descriptive counts と ATT-weighted risk の分離
- subject ID 一意性による non-replacement validation
- ATT-weighted SMD
- zero-variance SMD の状態分類
- observed zero-reference および partial undefined bootstrap RR の suppression policy
- `estimand = "ATT"` と bootstrap scope の machine-readable metadata 化

一方で、Section 9 acceptance を止めるべき問題が残る。

### 主要 findings

| ID | Severity | Finding | Gate impact |
|---|---|---|---|
| B-01 | **BLOCKER** | RR suppression 後も共通 contrast engine が `1e-15` floor 由来の RR precision metric を残す | **Acceptance blocker** |
| H-01 | **HIGH** | `num_draws` の runtime / schema / shared engine contract が不整合。finite validation も不足 | Required fix |
| H-02 | **HIGH** | SMD の `1e-12` absolute threshold が scale invariance を破壊 | Required fix |
| H-03 | **HIGH** | Evidence / Draws schema が新しい Section 9 contract を十分 enforce しない | Required fix |
| M-01 | **MEDIUM** | Baseline に存在した seed reproducibility test が削除 | Restore test |
| M-02 | **MEDIUM** | Abadie & Imbens (2008) の引用表現が fixed-set bootstrap の正当化に読める | Documentation fix |

---

## 2. Repository / Commit Verification

確認済み事項:

- `feat/comparative-evidence-reporting-v3` の remote HEAD は reviewed commit `e8b7726...` と一致。
- Reviewed commit の直親は baseline `51f846b...`。
- `main` との merge-base は `8174a470...`。
- Reviewed branch は `main` に対して 9 commits ahead / 0 behind。
- Baseline → Reviewed は 1 commit、12 files changed。
- GitHub combined status は空。
- Reviewed commit に紐づく workflow run は確認できなかった。
- Branch protection 上も required status checks は設定されていない。

したがって、repository state はレビュー対象として整合している一方、`tests 100% PASS` の主張について GitHub CI の独立証跡は確認できない。

---

## 3. Positive Findings — 修復が妥当と評価できる点

### 3.1 ATT estimator

Observed-sample ATT point estimates は、1 treated subject per set の matched-set design に対して妥当。

\[
\hat p_T = \frac{1}{J}\sum_{j=1}^J Y_{Tj}
\]

\[
\hat p_R = \frac{1}{J}\sum_{j=1}^J \bar Y_{Rj}
= \frac{1}{J}\sum_{j=1}^J \left(\frac{1}{k_j}\sum_{\ell=1}^{k_j}Y_{Rj\ell}\right)
\]

したがって、各 matched set の寄与は等しく、control subject は set 内で相対重み `1/k_j` を持つ。

**Status: PASS**

---

### 3.2 Atomic matched-set bootstrap

`sample.int(J, J * B, replace = TRUE)` で matched set index を resample し、同じ index matrix を treated と reference の双方に適用している。

このため within-set dependence を保った cluster-level bootstrap になっている。

**Status: PASS mechanically**

ただし、この bootstrap は matching procedure 自体を再実行しないため、scope はあくまで:

```text
conditional_on_fixed_matched_sets
```

である。

---

### 3.3 Raw count vs ATT-weighted risk separation

今回の修正で、

```text
matched_set.raw_target_counts
matched_set.raw_reference_counts
```

を導入し、reference cohort 側は

```text
estimate_semantics = "att_set_weighted_risk"
```

として generic raw denominator との混同を抑制している。

`reference_cohort.events` / `total` を `null` にした点も適切。

**Status: PASS implementation**

---

### 3.4 Subject ID based non-replacement validation

`subject_id` を必須化し、全 cohort で duplicate ID を reject することで、同一 subject の再利用を検証可能にした。

**Status: PASS**

---

### 3.5 ATT-weighted covariate balance

Control weight:

\[
w_{Rj\ell}=1/k_j
\]

Treated weight:

\[
w_{Tj}=1
\]

として、analysis weight の総和を両群とも `J` に揃えた second central moment を使っている。

今回採用した OpenSpec の式にはコードが整合している。

**Status: PASS against stated formula**

---

### 3.6 Zero-variance SMD classification

以前の「分散ゼロなら常に SMD = 0」という誤りは修復され、

```text
ZERO_VARIANCE_ZERO_DIFFERENCE
ZERO_VARIANCE_NONZERO_DIFFERENCE
```

を区別するようになった。

**Status: PASS with one remaining scale-invariance issue**

---

### 3.7 Zero-reference / partial undefined RR governance

Observed reference risk = 0 の場合:

```text
RR estimate = null
RR interval = null
RR mean = null
mean_is_finite = false
diagnostic = ZERO_REFERENCE_RISK
```

Observed reference risk > 0 だが bootstrap replicate に `p_R*=0` が存在する場合:

```text
RR interval = null
diagnostic = PARTIAL_UNDEFINED_BOOTSTRAP_REPLICATES
```

とする policy は、明示的で保守的な設計として妥当。

**Status: PASS for direct RR fields**

---

## 4. BLOCKER B-01 — RR suppression 後も artificial precision metric が残る

### 問題

`sample_matched_set_bootstrap()` は zero denominator を `NA` として適切に扱っている。

しかし `run_matched_set_inference()` から呼び出される shared engine `compute_comparative_contrasts()` は、内部で再び:

```r
rr_draws <- target_draws / pmax(reference_draws, 1e-15)
```

を計算している。

さらに:

```r
log_rr_width <- log(rr_upper) - log(rr_lower)
```

を求め、最終的に:

```text
precision_metrics.log_rr_interval_width
```

に格納する。

matched-set engine 側は後段で `relative_risk$interval` 等を `null` にしているが、`precision_metrics.log_rr_interval_width` は消していない。

### 反例

Observed:

\[
p_T = 1, \quad p_R = 0
\]

の場合、shared engine 内では:

\[
RR^* = \frac{1}{10^{-15}}=10^{15}
\]

となる。

すべての draw が同じなら:

\[
\log(RR_{0.975}) - \log(RR_{0.025}) = 0
\]

したがって最終 payload は概念上:

```text
relative_risk.interval = null
relative_risk.diagnostic = ZERO_REFERENCE_RISK

precision_metrics.log_rr_interval_width = 0
```

となり得る。

これは「RR は未定義だが precision は完全」という意味論的矛盾。

### 改善案

**推奨:** shared contrast engine に governed RR draws を明示的に渡す。

最低限の patch としては、RR suppression 時に:

```r
evidence$precision_metrics$log_rr_interval_width <- NULL
evidence$precision_metrics$rr_interval_fold_range <- NULL
```

を行う。

また、現在生成されている:

```r
clean_rr_draws
effective_rr_draws
```

は未使用なので、正式に shared engine 入力へ組み込むか削除する。

### Required test

T10 を追加:

```text
Observed p_R = 0
Expected:
  relative_risk.interval = null
  relative_risk.mean = null
  precision_metrics.log_rr_interval_width = null
  precision_metrics.rr_interval_fold_range = null
```

**Severity: BLOCKER**

---

## 5. HIGH H-01 — Runtime argument contract inconsistency

### 5.1 `num_draws`

Matched-set engine は:

```text
num_draws >= 1
```

を accept する。

Schema も:

```json
"minimum": 1
```

である。

一方 shared engine は:

```r
if (S < 10L) stop(...)
```

なので、`num_draws = 1..9` は local validation と schema を通った後に fail する。

### 改善

契約を一本化する。

推奨:

```r
if (!is.numeric(num_draws) ||
    length(num_draws) != 1L ||
    !is.finite(num_draws) ||
    num_draws < 10L ||
    num_draws != floor(num_draws)) {
  stop("[INVALID_ARGUMENT] ...")
}
```

Schema:

```json
"minimum": 10
```

へ同期する。

---

### 5.2 finite validation

Plan Gate では numeric runtime argument に finite validation が必要とされていたが、現コードは `Inf` を十分に reject できない。

対象:

```text
caliper
discarded_target
discarded_reference
num_draws
seed
level
primary_delta / delta_thresholds も検討対象
```

最低限、今回変更対象の引数には `is.finite()` を追加する。

### Required tests

```text
num_draws = 9 -> INVALID_ARGUMENT
num_draws = Inf -> INVALID_ARGUMENT
seed = Inf -> INVALID_ARGUMENT
caliper = Inf -> INVALID_ARGUMENT
discarded_target = Inf -> INVALID_ARGUMENT
```

**Severity: HIGH**

---

## 6. HIGH H-02 — SMD absolute threshold breaks scale invariance

### 問題

現在:

```r
if (s_pooled <= 1e-12) {
  if (abs(mean_diff) <= 1e-12) {
    smd_matched <- 0.0
```

としている。

しかし SMD は standardized effect size なので、正の定数 `c` に対して:

\[
SMD(cX)=SMD(X)
\]

であることが望ましい。

### 反例

\[
X_T=(2,4)\times10^{-13}
\]

\[
X_R=(1,3)\times10^{-13}
\]

とすると:

\[
\bar X_T-\bar X_R=10^{-13}
\]

\[
s_{pooled}=10^{-13}
\]

なので:

\[
SMD=1
\]

しかし current code は両者を `1e-12` 未満とみなし:

```text
SMD = 0
ZERO_VARIANCE_ZERO_DIFFERENCE
```

とする。

同じデータを単位変換で `10^13` 倍すると SMD = 1 に戻る。

### 改善

finite numeric covariates を保証したうえで、推奨は:

```r
if (s_pooled == 0) {
```

を基本とする。

numerical tolerance を残すなら、absolute threshold ではなく scale-relative threshold とし、その式を OpenSpec に明示する。

例:

```text
scale = max(1, abs(mean_T), abs(mean_R), sd-like reference)
tol = .Machine$double.eps^0.5 * scale
```

ただし SMD denominator は単位を持つため、単純な `max(1, ...)` も design choice になる。最も明快なのは exact zero 判定。

### Required tests

T11:

```text
X and c*X must yield identical SMD within numerical tolerance
```

特に `c = 1e-13`, `1`, `1e13` を含む scale transformation test を追加する。

**Severity: HIGH**

---

## 7. HIGH H-03 — Schema contract enforcement is incomplete

### Evidence schema

`matched_set.required` に以下が含まれていない:

```text
raw_target_counts
raw_reference_counts
```

したがって raw count separation を欠く payload でも schema-valid になり得る。

### Draws schema

`matched_set_metadata` 内で:

```text
set_count
matching_ratio_type
estimand
bootstrap_scope
rr_bootstrap_diagnostics
```

がほぼ required 化されていない。

また `bootstrap_scope.type` も enum ではなく generic string。

### 改善

Evidence:

```json
"required": [
  "set_count",
  "matching_ratio",
  "replacement",
  "patient_counts",
  "estimand",
  "bootstrap_scope",
  "raw_target_counts",
  "raw_reference_counts"
]
```

Draws:

```json
"matched_set_metadata": {
  "required": [
    "set_count",
    "matching_ratio_type",
    "estimand",
    "bootstrap_scope",
    "rr_bootstrap_diagnostics"
  ]
}
```

`bootstrap_scope.type`:

```json
"enum": ["conditional_on_fixed_matched_sets"]
```

`rr_bootstrap_diagnostics` についても minimum / maximum を Evidence 側と揃える。

### Required negative schema tests

```text
- raw_reference_counts missing -> reject
- estimand missing -> reject
- bootstrap_scope missing -> reject
- bootstrap_scope.type invalid -> reject
- rr_bootstrap_diagnostics missing from matched-set draws -> reject
```

**Severity: HIGH**

---

## 8. MEDIUM M-01 — Seed reproducibility test regression

Baseline の `tests/test_matched_set_inference.R` には同じ seed で 2 回実行し:

```r
identical(run_res1$draws$target_draws,
          run_res2$draws$target_draws)
```

を検証する test が存在した。

Reviewed commit では削除されている。

一方 `tasks.md` の 9.6 は:

```text
Add bootstrap reproducibility and seed consistency tests
```

が完了済み `[x]`。

### 改善

Baseline test を復活させる。

最低限:

```text
same seed -> identical target_draws
same seed -> identical reference_draws
same seed -> identical RD interval
```

異なる seed が必ず異なることを hard assert する必要はない。

**Severity: MEDIUM**

---

## 9. MEDIUM M-02 — Abadie & Imbens (2008) の引用表現

Current documentation は fixed matched-set bootstrap scope の説明に Abadie & Imbens (2008) を関連づけている。

しかし同論文の重要なメッセージは、nearest-neighbor matching estimator に対して ordinary bootstrap が一般に妥当とは限らない、という点。

### 改善

「この fixed-set bootstrap が Abadie & Imbens により正当化される」と読める表現は避ける。

推奨表現:

```text
This procedure is explicitly conditional on the realized matched sets and is
not a bootstrap of the matching estimator itself. Abadie & Imbens (2008)
show why ordinary bootstrap inference for nearest-neighbor matching estimators
cannot generally be assumed valid.
```

日本語:

```text
本手法は観測された matched sets を固定した条件付き resampling であり、
matching estimator 自体を bootstrap するものではない。
Abadie & Imbens (2008) は nearest-neighbor matching estimator に対して
通常の bootstrap の妥当性を一般に仮定できないことを示している。
```

**Severity: MEDIUM**

---

## 10. Improvement Priorities

### Priority 0 — Acceptance blocker

1. RR suppression と RR-derived precision metrics を atomic にする。
2. Shared engine 内の `1e-15` floor を matched-set governed policy と矛盾させない。

### Priority 1 — Statistical / Runtime contract

1. `num_draws` minimum を implementation / schema / shared engine で統一。
2. numeric arguments の `is.finite()` validation を追加。
3. SMD zero-variance 判定を scale-invariant にする。

### Priority 2 — Schema governance

1. `raw_*_counts` を required 化。
2. draws metadata を required / enum enforcement。
3. negative schema tests を追加。

### Priority 3 — Regression / documentation

1. seed reproducibility test を復活。
2. Abadie & Imbens の引用表現を修正。

---

## 11. Proposed Task List — Section 9 Repair #2

### 9.13 RR semantic atomicity

- [ ] `relative_risk` suppression 時に RR-derived precision metrics も `null` にする。
- [ ] `effective_rr_draws` の用途を確定し、shared engine に渡すか dead code として削除する。
- [ ] zero-reference test で `log_rr_interval_width = null` を assert。
- [ ] partial undefined bootstrap case でも RR-derived precision を suppress するか、定義済み replicate conditional metric として別名にするかを OpenSpec で明示する。

### 9.14 Draw-count contract normalization

- [ ] `num_draws` の minimum を 10 に統一、または shared engine の `<10` 制約を廃止する。
- [ ] `comparative-draws-v1.json` と runtime validator を同期する。
- [ ] `num_draws = 9` negative test を追加。

### 9.15 Finite-value runtime validation

- [ ] `caliper` に `is.finite()` validation。
- [ ] `discarded_target` / `discarded_reference` に `is.finite()` validation。
- [ ] `num_draws` に `is.finite()` validation。
- [ ] `seed` に `is.finite()` validation。
- [ ] `level` に `is.finite()` validation。
- [ ] 必要なら `primary_delta`, `delta_thresholds` も共通 validator に移す。
- [ ] `Inf`, `-Inf`, `NaN` の fail-fast tests を追加。

### 9.16 Scale-invariant SMD zero-variance policy

- [ ] `1e-12` absolute threshold を再設計。
- [ ] OpenSpec / design の normative formula を更新。
- [ ] unit scaling invariance test を追加。
- [ ] binary covariate / continuous covariate の両方で確認。

### 9.17 Schema hardening

- [ ] `matched_set.raw_target_counts` required 化。
- [ ] `matched_set.raw_reference_counts` required 化。
- [ ] `matched_set_metadata.estimand` required 化。
- [ ] `matched_set_metadata.bootstrap_scope` required 化。
- [ ] `bootstrap_scope.type` を enum 化。
- [ ] `rr_bootstrap_diagnostics` の required fields / bounds を evidence と draws で揃える。
- [ ] negative schema tests を追加。

### 9.18 Reproducibility regression restoration

- [ ] Same seed -> identical target draws。
- [ ] Same seed -> identical reference draws。
- [ ] Same seed -> identical percentile interval。
- [ ] `seed = NULL` metadata test は維持。

### 9.19 Documentation / citation clarification

- [ ] `design.md` の Abadie & Imbens 記述を修正。
- [ ] `spec.md` も同様に fixed-set conditional scope と matching-estimator bootstrap の違いを明記。
- [ ] `SKILL.md` の説明も同期。

### 9.20 Verification gate

- [ ] `Rscript tests/test_matched_set_inference.R`
- [ ] `Rscript tests/test_comparative_schemas.R`
- [ ] `Rscript tests/run_regression_suite.R`
- [ ] `openspec validate comparative-evidence-reporting-v3 --strict --json`
- [ ] `git diff --check`
- [ ] GitHub Actions または equivalent CI で commit-bound test evidence を残す。

---

## 12. Acceptance Criteria for Next Review

次回 independent review で Section 9 を ACCEPT 候補にする最低条件:

1. zero-reference / partial undefined RR で RR-derived precision metrics が矛盾なく suppress される。
2. `num_draws` contract が runtime / schema / shared engine で一致する。
3. numeric runtime parameters が `Inf`, `-Inf`, `NaN` を governed error で reject する。
4. SMD 判定が unit scaling に対して invariant。
5. matched-set specific schema metadata が required として enforce される。
6. negative schema tests が追加される。
7. fixed-seed reproducibility test が復活する。
8. OpenSpec / design / SKILL の理論説明が実装と一致する。
9. regression suite + strict OpenSpec validation の実行証跡が commit に紐づく。

---

## 13. Suggested Minimal Patch Order

```text
1. B-01 RR semantic atomicity
   ↓
2. H-01 num_draws + finite validation
   ↓
3. H-02 SMD scale invariance
   ↓
4. H-03 schema hardening
   ↓
5. M-01 reproducibility tests
   ↓
6. M-02 documentation citation cleanup
   ↓
7. full regression + OpenSpec validation
```

この順序を推奨する理由は、B-01 が downstream scientific interpretation に直接影響し、H-01/H-02 が numerical contract、H-03 が machine-readable governance を担うため。

---

## 14. Final Verdict

**HOLD — one semantic blocker plus three high-priority statistical/contract findings remain.**

今回の commit は、前回 Review 6 / Plan Gate で指摘された設計問題の大部分を妥当に修復している。
ATT estimator、atomic set bootstrap、ATT-weighted SMD、raw count separation、subject uniqueness、RR diagnostic policy の方向性は維持してよい。

再設計すべきなのは Section 9 全体ではなく、以下の境界である。

- RR suppression と downstream precision semantics
- runtime/schema/shared-engine contract
- SMD zero-variance numerical policy
- schema enforcement strength
- reproducibility regression coverage

これらを修正すれば、Section 9 は acceptance にかなり近い。

---

## 15. Critical Perspective

最も強い問題は B-01 である。
RR 自体を未定義として suppress しているにもかかわらず、shared engine が人工的 denominator floor に基づく finite precision を残す状態は、単なる表示問題ではなく inferential semantics の矛盾である。

H-02 の SMD threshold は design choice の余地がある。ただし standardized metric が単位変換によって 0 と 1 の間で変わるのは望ましくないため、少なくとも current absolute threshold を normative contract として固定することには慎重であるべき。

また CI evidence が存在しない状態では、repository 内に "100% PASS" と記載されていても、それを独立 verification と同一視しない方がよい。QMS 的には commit-bound automated evidence を残す運用が望ましい。
