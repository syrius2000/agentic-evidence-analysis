# shared-dashboard-theme-assets 独立QA・回帰テスト文書

- Date: 2026-09-20
- Target: `shared-dashboard-theme-assets` repair
- Profile: strict
- Review mode: blind-first
- Sample fixture basis (Pre-repair baseline): `skill_out/vcd_categorical/run_2874db181400f83e/dashboard.html`
- Pre-repair SHA-256: `9460d7c914a5127b5cd1c968054fe4c74d912b13f236ef2f16aa6c01a5965101`
- Post-repair fixture: `skill_out/vcd_categorical/run_2874db181400f83e_post_repair/dashboard.html`
- Post-repair SHA-256: `0cf1e2e6b3159fd0a678883f119d4c15bd201203b0e717feeb8df628dfc4a9f6`

## 1. QA順序

レビュー担当は実装者の説明・自己評価を先に読まない。

1. `openspec/specs/` 正本
2. active change proposal/spec/design/tasks
3. Acceptance Criteria
4. tests
5. implementation
6. generated evidence / dashboard HTML
7. verification reports
8. developer explanation
9. Owner adjudication

## 2. テストセット

### T01 — JSON Schema syntax gate

**Purpose**
`analysis_config.schema.json` 自体の構文破壊を検出する。

**Target**
`.agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json`

**Test**

- JSON parser で parse
- JSON Schema validator で load

**Expected**

- parse error = 0
- schema load error = 0

**Suggested R**

```r
schema_path <- ".agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json"
x <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
stopifnot(is.list(x))
stopifnot(identical(x$type, "object"))
stopifnot(!is.null(x$properties$dirichlet_prior))
stopifnot(!is.null(x$properties$arm_min_confidence))
```

### T02 — prior fixed contract

**Purpose**
OpenSpecで固定した主/感度事前を実装が勝手に拡張しない。

**Cases**

| primary | sensitivity | Expected |
|---:|---:|---|
| 0.5 | 1.0 | PASS |
| omitted | omitted | PASS → defaults 0.5 / 1.0 |
| 0.25 | 1.0 | REJECT |
| 0.5 | 2.0 | REJECT |
| 1.0 | 0.5 | REJECT |
| -0.5 | 1.0 | REJECT |

**Expected error**
明示的で再現可能なvalidation error。暗黙補正しない。

### T03 — conditional-rate-view capability ownership

**Purpose**
Jeffreys移行が presentation spec だけに埋没しないことを確認。

**Test**
以下が active delta または archive後正本の `conditional-rate-view` に存在すること。

- primary alpha=0.5
- sensitivity alpha=1.0
- support definition
- structural zero policy
- rare probability precision
- interval level
- provenance
- old-run non-relabel

**Expected**
presentation側だけに統計計算MUSTが孤立していない。

### T04 — rare event precision regression

**Input**
response counts:

```r
c(0, 1, 30000, 40000, 50000)
```

numerator = first 2 categories
denominator = all 5 categories
primary alpha = 0.5
sensitivity alpha = 1.0
interval = 0.90

**Analytic primary posterior**
Aggregated numerator:

- observed numerator = 1
- prior numerator = 2 * 0.5 = 1
- posterior numerator shape = 2

Aggregated denominator complement:

- observed = 120000
- prior complement = 3 * 0.5 = 1.5
- posterior complement shape = 120001.5

Thus:

```text
Beta(2, 120001.5)
```

**Checks**

- post_mean > 0
- ci_lower > 0
- ci_upper > ci_lower
- JSON round-trip preserves nonzero values
- no fixed-decimal zeroing
- MC result agrees with Beta analytic result within predeclared MC tolerance

### T05 — zero denominator HOLD

**Purpose**
precision repair must not break existing HOLD semantics.

**Case**
one requested conditional slice has denominator count = 0.

**Expected**

- slice status = `HOLD_ZERO_DENOMINATOR`
- overall = `PARTIAL_HOLD` when other valid slices exist
- no NaN/Inf serialized as ordinary valid probability

### T06 — 90% / 95% ETI consistency

Generate two dashboards.

Case A:

```json
"interval_level": 0.90
```

Case B:

```json
"interval_level": 0.95
```

Check consistency across:

- JSON config echo
- table column names
- figure titles
- glossary wording
- textual captions

**Expected**
No `95%` hardcode in the 90% output.

### T07 — 2-way section contract

**Expected analysis sections**
exactly the analytical sequence:

1. Executive Summary
2. Global Association & Effect Size
3. Effect × Evidence & Dual-Filter
4. Adjusted Residual Structure
5. Cell Explorer
6. Joint Posterior Credible Intervals
7. Conditional Posterior Distributions
8. Uncertainty Ranking
9. Posterior Departure from Independence
10. Prior Sensitivity Analysis
11. Quality & Provenance

**Glossary rule**
Glossary is not numbered `12.`.

Allowed:

```text
Appendix — Glossary...
```

or unnumbered:

```text
Glossary...
```

**Reject**

```text
12. Glossary...
```

### T08 — glossary navigation correctness

For the 2-way dashboard, verify glossary links/text point to current sections.

Minimum matrix:

| Concept | Expected |
|---|---|
| Pearson X² | Section 2 |
| Cramér's V | Section 2 |
| corrected Cramér's V | Section 2 |
| Effect | Section 3 |
| Evidence | Section 3 |
| adjusted residual | Section 4 |
| leverage / cell explorer | Section 5 |
| joint posterior | Section 6 |
| conditional posterior | Section 7 |
| uncertainty | Section 8 |
| posterior departure | Section 9 |
| prior sensitivity | Section 10 |
| provenance | Section 11 |

Prefer context injection over hardcoded section strings inside shared glossary helpers.

### T09 — wording regression: unconditional N proportional claim

Search:

- `.agents/shared/dashboard_glossary.R`
- 2-way dashboard template
- 3-way dashboard template
- 3-way `analysis.R`
- generated 2D/3D HTML

Reject as an unconditional summary:

```text
標本数Nに正比例
標本数比例の証拠強度
```

Allow conditionally qualified explanation:

```text
同じ度数構成を c 倍し、同一モデルを再適合する場合...
```

### T10 — MathML retention / no KaTeX scope creep

The user-provided sample contains MathML and no KaTeX.

**Generated 2-way HTML checks**

- `<math ... xmlns="http://www.w3.org/1998/Math/MathML">` exists when equations are present
- `.katex` nodes = 0
- no KaTeX CSS/JS external dependency added

This is a scope-preservation test, not a claim that MathML is universally superior.

### T11 — Zero-External-Asset static scan

Scan generated 2D and 3D HTML.

Reject in resource-bearing attributes:

```regex
https?://
^//
file://
/Users/
/home/
```

Exception:
namespace strings or plain-text bibliography URLs must be classified separately from resource loads.
The test should inspect actual `src`, `href`, CSS `url()`, module/import/resource references rather than blindly fail on every textual occurrence of `http`.

**Expected**
external network resources = 0
local absolute resources = 0

### T12 — shared asset injection

For both generated dashboards verify:

- shared theme CSS content is inline
- DataTables Japanese dictionary is effective
- glossary is real DOM, not escaped `<pre>/<code>`
- missing shared asset fails explicitly
- rendering from an external temporary working directory can still resolve confirmed repo root

### T13 — 3-way prior metadata

New run must contain:

```json
{
  "family": "symmetric_dirichlet",
  "primary_alpha": 0.5,
  "primary_role": "primary",
  "primary_name": "jeffreys",
  "sensitivity_alpha": 1.0,
  "sensitivity_role": "sensitivity",
  "sensitivity_name": "uniform"
}
```

Check in:

- `conditional_rate_view`
- config echo
- `run_meta.json`
- handover/provenance as defined by contract

Old alpha=1.0 runs must not be relabeled.

### T14 — Poisson / local diagnostics non-regression

The prior migration must not modify:

- Poisson model definitions
- model BIC computation
- local diagnostic formulas
- zero-cell diagnostic convention
- 3-way candidate rule

Use an existing canonical fixture such as UCB Admissions and compare pre/post fields outside `conditional_rate_view`.

### T15 — official regression registration

`tests/run_regression_suite.R` or explicitly documented official QA runners must include/gate:

```text
test_shared_dashboard_math.R
test_three_way_dashboard_html.R
test_vcd_categorical_dashboard_v4.R
test_three_way_analysis_config_schema.R
```

If render tests are split from core:

- core gate must be mandatory
- render/integration gate must be mandatory before archive
- final evidence records both results

### T16 — OpenSpec strict validation

Run:

```bash
openspec validate shared-dashboard-theme-assets --strict --json
```

Expected:

```text
valid=true
issues=[]
```

This is necessary but not sufficient; it does not replace T01 JSON Schema syntax test.

### T17 — generated sample structural verification

For the user-provided sample characteristics, newly generated 2-way HTML should preserve:

- dashboard title
- 11 analytical sections
- provenance section
- offline/self-contained behavior
- MathML equations
- glossary content

while correcting:

- Glossary `12.` numbering
- stale section routing
- any remaining unconditional N-proportional wording

### T18 — browser interaction

Manual or browser automation evidence:

- glossary accordion opens/closes
- DataTables search/sort/pagination work where enabled
- no console-breaking JS error
- network panel shows no external asset request
- equations remain readable
- long labels do not make key tables unusable

Record browser/tool/environment.

## 3. Suggested automated test file

Create:

`tests/test_three_way_analysis_config_schema.R`

Minimum:

```r
#!/usr/bin/env Rscript

library(jsonlite)

repo_root <- normalizePath(".")
schema_path <- file.path(
  repo_root,
  ".agents/skills/vcd-bayesian-evidence-analysis/references/analysis_config.schema.json"
)

schema <- fromJSON(schema_path, simplifyVector = FALSE)

stopifnot(identical(schema$type, "object"))
stopifnot(is.list(schema$properties))
stopifnot(is.list(schema$properties$dirichlet_prior))
stopifnot(is.list(schema$properties$arm_min_confidence))

dp <- schema$properties$dirichlet_prior$properties
stopifnot(identical(dp$primary_alpha$const, 0.5))
stopifnot(identical(dp$sensitivity_alpha$const, 1.0))

cat("[PASS] three-way analysis_config.schema.json syntax and prior contract\n")
```

Also add config-validation integration cases for invalid alpha values.

## 4. Sample HTML evidence checks

### Pre-repair Baseline Fixture

Reference sample:
`skill_out/vcd_categorical/run_2874db181400f83e/dashboard.html`
SHA-256:
`9460d7c914a5127b5cd1c968054fe4c74d912b13f236ef2f16aa6c01a5965101`

Observed baseline:

- MathML `<math>` count: 87
- KaTeX nodes: 0
- external `src/href`: 0
- local absolute `src/href`: 0
- analytical sections: 7 sections in old template
- glossary: renders as `<span>12.</span>` Glossary (stale numbering)

### Post-repair Canonical Fixture

Reference sample:
`skill_out/vcd_categorical/run_2874db181400f83e_post_repair/dashboard.html`
SHA-256:
`0cf1e2e6b3159fd0a678883f119d4c15bd201203b0e717feeb8df628dfc4a9f6`

Observed post-repair characteristics:

- MathML `<math>` count: 87
- KaTeX nodes: 0
- external `src/href`: 0
- local absolute `src/href`: 0
- analytical sections: exactly 12 H2 headings (complete 11 sections + unnumbered Appendix)
- Section 1 outline: executive_summary headings safely demoted to unnumbered H3, eliminating duplicate Section 1-7 H2s
- glossary: renders as `Appendix — 統計用語集・方法論解説・学術リファレンス` (unnumbered, no `12.`)

The pre-repair sample is historical evidence of baseline behavior before repair.
The post-repair sample is canonical evidence of current rendered behavior meeting all Acceptance Criteria.
Do not require identical HTML hash across environments due to timestamp variations.

## 5. Exit criteria

### BLOCK

Any of:

- invalid JSON schema
- prior values outside agreed contract accepted
- rare positive probability lost to zero
- wrong ETI level displayed
- 2-way analysis sections renumbered/broken
- external resource introduced
- old run relabeled as Jeffreys
- presentation layer recomputes statistical values
- mandatory regression fails

### PASS

All:

- T01–T18 applicable tests pass
- OpenSpec strict valid
- official core + render gates pass
- generated 2D/3D artifacts reviewed
- no material findings remain
- independent reviewer signs off
- Owner accepts residual risks

## 6. Independent QA report format

```markdown
# shared-dashboard-theme-assets final independent QA

HEAD:
OpenSpec change:
Reviewer:
Date:

## Scope
...

## Blind-first order followed
- [ ] canonical specs
- [ ] active change specs
- [ ] tests
- [ ] implementation
- [ ] generated evidence
- [ ] prior verification reports
- [ ] developer explanation

## Results
| Test | Result | Evidence |
|---|---|---|
| T01 | PASS/FAIL | ... |
...

## Findings
### F-...
Severity:
Contract:
Evidence:
Impact:
Required remediation:

## Residual risk
...

## Final state
PASS / HOLD

## Owner adjudication required
YES
```
