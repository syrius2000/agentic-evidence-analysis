# Planning QA Review 001: comparative-dashboard-metric-hierarchy-v1

- **レビュー種別**: OpenSpec Planning Gate QA（実装前）
- **Change ID**: `comparative-dashboard-metric-hierarchy-v1`
- **Branch**: `codex/Gower-PCoA`
- **Reviewed commit**: `6c9d8329de0176621ec6675fcbc7489d67e572c3`
- **Baseline**: `41d575e28d553b42e6d7f02e1afa09225438bea2`
- **Plan baseline**: `07ab0853fe8499509822a323e9b521c3c8399fc3`
- **Source plan**: `docs/Artifacts/implementation_plan_024_0927.md`
- **レビュー日**: 2026-09-27 (JST)
- **QA disposition**: **HOLD — planning gate 修正後に再QA**
- **実装コード評価**: 対象外
- **Rテスト実行**: 対象外
- **OpenSpec CLI strict validation**: 本QA環境では未実行。修正後に実行証跡を要求する。

---

## 1. Executive Summary

今回の OpenSpec planning artifact は、Plan 024 の主要設計を概ね正しく反映している。

特に以下は良好である。

1. **presentation-only change** として境界が明確。
2. HTML / Markdown の主表を 11 列から 12 列へ変更し、E100 と reciprocal RD を分離している。
3. **U-Grade / Practical Region を削除せず維持**している。
4. canonical `summary_df` を表示の正本とし、新しい canonical field を導入しない方針が明記されている。
5. Gower / PCoA / HAC の feature contract、RD/RR inference、U-Grade threshold を non-goal として明確にしている。
6. delta spec は `## ADDED Requirements`、`### Requirement`、`#### Scenario`、WHEN/THEN、および SHALL/MUST を使用しており、OpenSpec planning artifact としての構造は良好。
7. `tasks.md` は Plan Q1–Q24 を範囲として全件カバーしている。

一方、planning gate としては以下の点を修正してから実装へ進むべきである。

- **H1**: Safety における `target_excess → NNH-like` / `reference_excess → NNT-like` の正本マッピングが delta spec で明文化されていない。
- **M1**: 「JSON / CSV canonical schema = 40 summary fields」と読める表現があり、nested JSON evidence contract と flat summary/export contract の境界が曖昧。
- **M2**: U-Grade scenario が `primary_delta configured` と `delta = null` を同一 WHEN に混在させている。
- **M3**: Q1–Q24 の task coverage はあるが、特に誤実装リスクの高い Q4–Q8 / Q15 / Q20 を task レベルで明文化した方がよい。
- **G1**: `openspec validate comparative-dashboard-metric-hierarchy-v1 --strict` の実行証跡が本QAでは確認できていない。

---

## 2. Review Scope Confirmation

比較対象:

```text
git diff 41d575e28d553b42e6d7f02e1afa09225438bea2..6c9d8329de0176621ec6675fcbc7489d67e572c3
```

差分は以下の 5 ファイルのみである。

1. `openspec/changes/comparative-dashboard-metric-hierarchy-v1/.openspec.yaml`
2. `openspec/changes/comparative-dashboard-metric-hierarchy-v1/proposal.md`
3. `openspec/changes/comparative-dashboard-metric-hierarchy-v1/design.md`
4. `openspec/changes/comparative-dashboard-metric-hierarchy-v1/tasks.md`
5. `openspec/changes/comparative-dashboard-metric-hierarchy-v1/specs/comparative-evidence-reporting/spec.md`

以下は reviewed commit では変更されていない。

- `.agents/skills/vcd-categorical-reporting/comparative_reporting.R`
- `schemas/comparative-evidence-v1.json`
- `.agents/shared/comparative_contrasts.R`
- `.agents/shared/evidence_gower.R`
- `.agents/shared/evidence_feature_extract.R`

したがって、本commitは planning-only change としてスコープ境界を守っている。

---

## 3. QA Focus Assessment

| QA focus | 判定 | コメント |
|:---|:---:|:---|
| Data / Provenance First | **CONDITIONAL PASS** | `summary_df` reuse / no new canonical fields は良好。ただし JSON と 40-field summary/export の文言分離が必要。 |
| Concept separation | **PASS** | RD ≠ E100 ≠ reciprocal ≠ Direction ≠ U-Grade ≠ Precision ≠ Diagnostics が12列順序に反映。 |
| Zero-Guesswork | **HOLD** | NNH/NNT方向マッピングを delta spec 自体に固定する必要あり。 |
| Test Matrix Q1–Q24 | **CONDITIONAL PASS** | 範囲網羅あり。高リスク境界ケースを tasks に明文化推奨。 |
| Non-goals | **PASS** | schema / Gower / PCoA / inference 不変、U-Grade維持が明確。 |
| Spec quality | **PASS, CLI pending** | SHALL/MUST + Scenario WHEN/THEN は適切。strict CLI実行証跡は未確認。 |

---

# 4. Findings

## QA024-H01 — Safety NNT/NNH-like direction mapping is underspecified

**Severity**: High
**Status**: Open
**Planning gate impact**: Must fix before implementation

### Finding

Plan 024 と既存 implementation contract は、Safety domain における reciprocal RD の direction-aware label を以下のように固定している。

```text
reciprocal_direction = "target_excess"    -> NNH-like
reciprocal_direction = "reference_excess" -> NNT-like
```

また非 Safety domain では stable finite reciprocal RD を:

```text
1/|RD| ≈ xx.x人
```

として表示し、NNT/NNH と断定しない。

しかし reviewed delta spec の Scenario は、

> display the reciprocal label according to domain and `reciprocal_direction`

までしか規定しておらず、**どの direction が NNT-like / NNH-like に対応するかを normative に固定していない**。

### Risk

実装者が direction mapping を逆転しても、形式上「according to reciprocal_direction」と解釈できる余地が残る。
Safety dashboard では意味が逆転するため、Zero-Guesswork contract 上 High と判定する。

### Required repair

delta spec に以下の normative mapping を明示する。

```text
For domain = "safety":

- reciprocal_status = "STABLE_DIRECTION"
  AND reciprocal_direction = "target_excess"
  MUST render "NNH-like ≈ xx.x人".

- reciprocal_status = "STABLE_DIRECTION"
  AND reciprocal_direction = "reference_excess"
  MUST render "NNT-like ≈ xx.x人".

For domain != "safety":

- a stable finite reciprocal RD MUST render "1/|RD| ≈ xx.x人"
  and MUST NOT render NNT-like or NNH-like.
```

### Traceability

- Plan 024: Q4, Q5, Q8
- Existing canonical fields:
  - `reciprocal_absolute_rd`
  - `reciprocal_status`
  - `reciprocal_direction`

---

## QA024-M01 — JSON contract and 40-field summary/export contract must be separated

**Severity**: Medium
**Status**: Open
**Planning gate impact**: Must fix wording before implementation

### Finding

Reviewed proposal/spec には、以下の意味に読める表現がある。

```text
JSON / CSV canonical schema (40 fields)
```

また delta spec では、

```text
Canonical JSON / CSV schema (exactly 40 summary fields)
```

という表現がある。

一方、現行正本では:

- `summary_df` / dashboard CSV export = **40 canonical summary fields**
- `comparative_evidence.json` = nested comparative evidence structure

であり、JSON 自体を「40 fields」と定義しているわけではない。

### Risk

presentation-only change のはずが、実装者が JSON evidence schema も flat 40-field contract と誤解する可能性がある。
Data / Provenance First の責務分離上、明確化が必要。

### Required repair

proposal/spec/design の表現を以下のように分離する。

```text
- comparative_evidence.json / comparative-evidence-v1 evidence contract
  SHALL remain unchanged.

- canonical summary_df and dashboard CSV export
  SHALL remain exactly 40 canonical summary fields.

- No presentation-only field SHALL be added to either canonical contract.
```

### Traceability

- Plan 024 §7.1, §7.3
- Plan QA Q17
- Existing main spec: Excel-Compatible Canonical Dashboard CSV Export

---

## QA024-M02 — U-Grade configured-delta and null-delta scenarios should be split

**Severity**: Medium
**Status**: Open
**Planning gate impact**: Recommended repair before implementation

### Finding

Reviewed spec の U-Grade scenario は概ね:

```text
WHEN primary_delta is configured and U-Grades U0–U3
(or NONE when delta is null) are present
```

という構造になっている。

`primary_delta is configured` と `primary_delta = null` は別状態であり、一つの WHEN に混在させると acceptance condition が曖昧になる。

### Required repair

2 scenario に分割する。

#### Scenario A: configured practical threshold

```text
WHEN primary_delta is positive/configured
THEN U0–U3 + dominant region SHALL remain visible,
AND practical-region hue SHALL be confined to the practical cell,
AND U3 SHALL remain muted/achromatic.
```

#### Scenario B: practical threshold disabled

```text
WHEN primary_delta is null
THEN U-Grade MUST be NONE,
dominant region MUST be none,
AND practical-region color highlighting MUST be disabled.
```

### Traceability

- Plan 024 Q11, Q12, Q13
- Existing main spec:
  - Practical Difference and Resolution Across Active Uncertainty Distributions

---

## QA024-M03 — Q1–Q24 task coverage is complete but high-risk cases should be explicit

**Severity**: Medium
**Status**: Open
**Planning gate impact**: Improvement strongly recommended

### Finding

`tasks.md` は:

- Q1–Q13
- Q14–Q19
- Q20–Q24

として番号範囲上は完全網羅している。

これは coverage としては合格である。

ただし、以下は誤実装時の意味的影響が大きく、単なる range reference より task 本文に expected result を明記した方がよい。

- Q4: RD > 0 stable → NNH-like
- Q5: RD < 0 stable → NNT-like
- Q6: zero-crossing → SIGN_AMBIGUOUS / directional label suppression
- Q7: RD near zero → reciprocal null / RD_NEAR_ZERO
- Q8: non-Safety → `1/|RD|` only
- Q15: reciprocal sort → stable finite numeric, suppressed = missing
- Q20: RR instability warning remains while RD/E100 remain usable

### Recommended repair

`tasks.md` 3.1–3.3 の下に、少なくとも以下の repair bullets を追加する。

```text
- Explicitly assert Q4/Q5 direction mapping for Safety.
- Explicitly assert Q6/Q7 suppression boundary states.
- Explicitly assert Q8 non-Safety generic reciprocal label.
- Explicitly assert Q15 reciprocal sort missing-state behavior.
- Explicitly assert Q20 RR-instability regression while RD/E100 remain available.
```

---

## QA024-G01 — Strict OpenSpec validation execution evidence not yet verified

**Severity**: Gate condition
**Status**: Pending
**Planning gate impact**: Required before final PASS

### Finding

本QAでは repository artifact の静的検査を実施したが、QA環境から `openspec validate` CLI を実行した証拠は得られていない。
対象commitにも CI status / workflow run は確認できなかった。

### Required gate

修正後、以下を実行し結果を提示する。

```bash
openspec validate comparative-dashboard-metric-hierarchy-v1 --strict
```

Expected:

```text
valid / zero validation errors
```

可能なら併せて:

```bash
git diff --check
```

も PASS を記録する。

---

# 5. Positive Findings

## P01 — Presentation-only architecture is correctly preserved

`design.md` は以下を明示している。

- canonical fields already exist
- no schema change
- geometry modules out of scope
- split is presentation-only

これは Plan 024 の Data / Provenance First と一致する。

## P02 — Twelve-column concept hierarchy is correct

以下の正本順序が spec で固定されている。

```text
1. Theme
2. Contrast
3. Descriptive N
4. Descriptive events
5. RD
6. E100
7. NNT/NNH-like
8. RR
9. Direction Support
10. Practical Region / U-Grade
11. Precision
12. Diagnostics
```

この順序は:

```text
Effect
!= Natural-unit translation
!= Reciprocal translation
!= Direction support
!= Practical-region resolution
!= Precision
!= Diagnostics
```

を UI 上で保持する。

## P03 — U-Grade retention is correctly prioritized

U-Grade は削除対象ではなく、Practical Region とともに主表へ残されている。

また:

- effect size ではない
- sample size / generic precision ではない
- clinical severity ではない

という既存 conceptual contract と整合している。

## P04 — Reciprocal RD remains secondary

delta spec / design は reciprocal RD を primary estimand に昇格させず、secondary interpretation metric としている。
これは因果的 NNT の過剰解釈を避ける上で適切。

## P05 — Geometry boundary is preserved

以下は Gower feature key に追加しない方針が維持されている。

- `excess_per_100`
- `reciprocal_absolute_rd`
- `reciprocal_status`
- `reciprocal_direction`

これは Plan 023/024 の幾何安定性契約と整合する。

---

# 6. Required Repair Tasks

以下を **planning repair tasks** として実施することを推奨する。

## R1 — Freeze Safety reciprocal direction mapping

**Files**:

- `openspec/changes/comparative-dashboard-metric-hierarchy-v1/specs/comparative-evidence-reporting/spec.md`
- 必要に応じて `design.md`, `proposal.md`, `tasks.md`

**Action**:

- `target_excess → NNH-like`
- `reference_excess → NNT-like`
- non-Safety → `1/|RD|`, NNT/NNH label禁止

を normative requirement/scenario として明示。

**Acceptance**:
Q4 / Q5 / Q8 が spec 文面だけから一意に導出できる。

---

## R2 — Separate JSON evidence contract from 40-field summary/export contract

**Files**:

- `proposal.md`
- `design.md`
- `specs/comparative-evidence-reporting/spec.md`

**Action**:
「JSON / CSV = 40 fields」と読める表現を除去し、

- JSON evidence contract unchanged
- summary_df / dashboard CSV = exactly 40 canonical fields
- no presentation-only canonical additions

へ分離。

**Acceptance**:
nested evidence JSON と flat summary/export の責務が混同されない。

---

## R3 — Split U-Grade scenario into active-delta and null-delta cases

**Files**:

- `specs/comparative-evidence-reporting/spec.md`

**Action**:

- configured delta → U0–U3 + region + local hue
- null delta → NONE / none / achromatic

を別 Scenario とする。

**Acceptance**:
Q11 / Q12 / Q13 が独立して検証可能。

---

## R4 — Expand high-risk QA tasks

**Files**:

- `tasks.md`

**Action**:
Q1–Q24 range coverage を維持したまま、特に以下を明示。

- Q4/Q5 direction mapping
- Q6/Q7 suppression
- Q8 non-Safety
- Q15 reciprocal sorting
- Q20 RR instability regression

**Acceptance**:
実装者が tasks.md のみ読んでも expected result を誤解しない。

---

## R5 — Execute strict planning validation

**Action**:

```bash
openspec validate comparative-dashboard-metric-hierarchy-v1 --strict
git diff --check
```

**Acceptance**:

- OpenSpec: valid / 0 errors
- diff check: clean

---

# 7. Suggested tasks.md Repair Block

以下はそのまま `tasks.md` へ取り込める粒度の提案である。

```markdown
## 3.R Planning QA Repair

- [ ] 3.R1 Freeze Safety reciprocal label mapping in delta spec:
      target_excess -> NNH-like, reference_excess -> NNT-like;
      non-Safety stable reciprocal -> 1/|RD| only.
      Verify Q4, Q5, and Q8 are directly derivable from the spec.

- [ ] 3.R2 Separate evidence JSON contract from summary/export contract:
      comparative_evidence.json schema remains unchanged;
      summary_df/dashboard CSV remain exactly 40 canonical fields;
      no presentation-only canonical fields are added.

- [ ] 3.R3 Split Practical Region / U-Grade scenarios:
      positive primary_delta -> U0-U3 + dominant region + cell-local hue;
      primary_delta = null -> NONE / none / no practical-region hue.
      Verify Q11-Q13 independently.

- [ ] 3.R4 Make high-risk QA expectations explicit in tasks:
      Q6 SIGN_AMBIGUOUS suppression,
      Q7 RD_NEAR_ZERO reciprocal null,
      Q15 reciprocal numeric/missing sort behavior,
      Q20 RR-instability warning with RD/E100 retained.

- [ ] 3.R5 Run:
      openspec validate comparative-dashboard-metric-hierarchy-v1 --strict
      git diff --check
      and record zero OpenSpec validation errors plus clean diff.
```

---

# 8. Re-QA Request Template

修正後は以下を提示すれば Cycle 2 QA を短く実施できる。

```text
## OpenSpec Planning QA Cycle 2 Request

Change ID: comparative-dashboard-metric-hierarchy-v1
Branch: codex/Gower-PCoA
Reviewed commit: <NEW_COMMIT_SHA>
Baseline: 6c9d8329de0176621ec6675fcbc7489d67e572c3
Plan baseline: 07ab0853fe8499509822a323e9b521c3c8399fc3

Repair targets:
- QA024-H01
- QA024-M01
- QA024-M02
- QA024-M03
- QA024-G01

Validation evidence:
- openspec validate comparative-dashboard-metric-hierarchy-v1 --strict: <RESULT>
- git diff --check: <RESULT>

Review scope:
- openspec/changes/comparative-dashboard-metric-hierarchy-v1/proposal.md
- openspec/changes/comparative-dashboard-metric-hierarchy-v1/design.md
- openspec/changes/comparative-dashboard-metric-hierarchy-v1/tasks.md
- openspec/changes/comparative-dashboard-metric-hierarchy-v1/specs/comparative-evidence-reporting/spec.md
```

---

# 9. Final Planning-Gate Position

現時点の設計方針そのものには重大な欠陥はない。

特に:

- E100 / reciprocal RD の列分離
- U-Grade の維持
- canonical field 非追加
- Gower / PCoA 非変更
- inference 非変更
- HTML / Markdown 同期

は妥当である。

ただし **Safety の NNT/NNH方向対応は意味を逆転させ得るため、実装前に仕様で一意に固定することが必須**。
また canonical JSON と 40-field summary/export の責務を文言上も分離し、実装者が schema を誤解しない状態にすること。

上記 R1–R5 を完了後、Planning Gate を再評価する。
