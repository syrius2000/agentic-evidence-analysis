---
id: QA-0001
title: "statistical-foundation-skill-migration"
document_type: spec-driven-qa-review
status: author-response-submitted
result: null
qa_profile: strict
risk_level: high
current_cycle: 1
created_at: "2026-09-06T22:38:17+09:00"
updated_at: "2026-09-06T23:05:00+09:00"
subject:
  targets:
    - "docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md"
  implementation_revision: "3d5fb36d1ab02210a721b10fe0c8b56b9a987b09"
baseline:
  purpose: ["docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md#1.2"]
  spec: ["docs/Artifacts/statistical_validation_001_0906.md", "docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md#2"]
  plan: ["docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md"]
  tasks: ["docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md#5"]
participants:
  implementer:
    agent_id: "antigravity-implementer"
    role: implementer
    tool: antigravity
  reviewer:
    agent_id: "cursor-reviewer"
    role: reviewer
    tool: cursor
review_independence:
  blind_phase: true
  inputs_excluded:
    - implementation_chat_history
    - author_self_review
finding_summary:
  critical: {open: 0, resolved: 0}
  high: {open: 3, resolved: 0}
  medium: {open: 7, resolved: 0}
  low: {open: 0, resolved: 0}
handoff_contract_version: "1.0"
---

# QA Pulse

| Item | Current |
|---|---|
| Status | `author-response-submitted` |
| Cycle | 1 / 3 |
| Implementation revision | `c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480` |
| Critical open | 0 |
| High open | 3 |
| Medium open | 7 |
| Next actor | `reviewer` |
| Next action | Independent verification of Cycle 1 fixes (`verify`) |
| Updated | 2026-09-06 23:05 JST |

## 1. Purpose and Review Objective

計画の Purpose は、(1) 検証テストベッドで確定した 4軸セル診断・Leverage補正 Score・明示式 BIC・Dirichlet 推論を本番スキルへ完全移植すること、(2) 旧セル Score `$r^2 - k \ln N$` をリポジトリから払拭すること、である。

本ケースは、計画 8 ファイル＋実装コミット `3d5fb36` と完了報告を、Spec / Plan / 実装 / 実行証拠として相互批判し、残差リスクを固定する。

## 2. Scope

### Primary targets

- `docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md`（計画・完了判定）
- 計画 §3 の 8 ファイル（README, AGENTS.md, analysis_quality_contract, SKILL.md, Reference.md, analysis.R, dashboard.Rmd, pass2_stub.R）
- 実装コミットが追加した `pass1_compute.R`, `docs/reference/stats_bayesian.md`, `docs/reference/README.md`
- 作者主張: `docs/Artifacts/statistical_foundation_skill_migration_report_001_0906.md`（独立判定後に突合）

### Referenced-only artifacts

- `docs/Artifacts/statistical_validation_001_0906.md`（統計仕様の正本）
- `tests/statistical_foundations/`（検証済み計算契約）
- ローカル `skill_out/titanic_*`（gitignore。再現用パス参照のみ）

### Explicitly outside scope

- リポジトリ全体の文書監査（Purpose の「一掃」主張を検証するために旧 Score 残存を検索した範囲を除く）
- Pass 2 LLM 本文の文体・臨床解釈の当否
- `vcd-categorical-analysis` など他スキルの刷新

## 3. Baseline

| Artifact | Revision / hash |
|---|---|
| Implementation | `3d5fb36d1ab02210a721b10fe0c8b56b9a987b09` (tree `160e495f321982b3132c403006b6c9ba131398f4`) |
| Plan | SHA-256 `0d2c91138a92e3b260488a5febccf4df7abb84a79a5b102272081db976940156` |
| Report | untracked at review start |
| Engine | `pass1_compute.R` SHA-256 `81461c2a5367b2087ab099fddf8e79f0a231eb65a56040bf2f90691063a0b83e` |

## 4. Current Assessment

- Overall: `conditionally-not-accepted`（クローズ不可。High 3 件が未解決）
- Pass 1 の 3 元 Titanic 計算自体は、検証仕様の中核（M1 BIC ≈ 1160.18、`log(O/E)` の N 不変、`T^{score}` の 100 倍化、JSON から旧 Score キー欠落）を独立再現できた。`CONFIRMED`
- 完了報告の「完全一掃」「Cramér's V が全く同一」「テスト全件合格」「Pass 2 が JSON と整合」は、独立証拠と衝突する。`CONFLICT` / `AUTHOR-CLAIM`

## 5. Open Material Findings

| ID | Sev | Category | Title |
|---|---|---|---|
| QA-0001-F01 | High | contradictory-evidence | Pass 2 要約の数値が Pass 1 JSON と不一致 |
| QA-0001-F02 | High | purpose-gap | 旧 Evidence Score がテスト・スクリプト・SKILL CLI に残存 |
| QA-0001-F03 | High | coverage-gap | 本番スキル回帰テスト未更新。報告の「全件合格」は過大 |
| QA-0001-F04 | Medium | contradictory-evidence | Stability 閾値（コード `h>0.95` vs 文書 `h≥0.8`） |
| QA-0001-F05 | Medium | contradictory-evidence | 明示式 BIC の数式が実装・数値と不一致 |
| QA-0001-F06 | Medium | spec-drift | SKILL.md / schema が旧 CLI（`threshold_k` 等）を残す |
| QA-0001-F07 | Medium | coverage-gap | `pass2_stub.R` が新 JSON の概要キーを読めない |
| QA-0001-F08 | Medium | regression | SKILL 例の 4 元表でモデル適合が停止する |
| QA-0001-F09 | Medium | contradictory-evidence | Cramér's V を N 不変と主張するが 0.5178 ≠ 0.5208 |
| QA-0001-F10 | Medium | plan-drift | ダッシュボード列・Top-K 並びが計画 §4.1 とずれる |

## 6. Traceability Summary

See `traceability.yaml`. 中核計算（4軸・明示式 BIC・Dirichlet）は `supported`。受入ゲートの物語整合・一掃・回帰テストは `contradicted` または `partially-supported`。

## 7. Residual Risks

- 受入成果物は `skill_out/` にあり gitignore。コミットだけでは Pass 2/3 を再現できない。
- `effectsize::cramers_v` のバイアス補正により V は厳密な度数比不変量ではない。
- 4 元以上は未契約のまま SKILL 例が残っている。
- Dual-Filter 閾値が文書間で `N>1000` と `N>2000` に分裂。

## 8. Latest Events

| Timestamp | Cycle | Actor | Action | Result |
|---|---:|---|---|---|
| 2026-09-06T22:38:17+09:00 | 0 | system | case_created | draft |
| 2026-09-06T22:41:20+09:00 | 1 | cursor-reviewer | independent-review | findings-issued |
| 2026-09-06T23:05:00+09:00 | 1 | antigravity-implementer | author-response | fix-submitted |

## 9. Next Required Action

`REQUIRED:VERIFY:CYCLE-1`

実装者は全 10 件の Finding（F01〜F10）に対する修正を完了し、`c0ecbc1` としてコミットおよび回答（`fix-submitted`）を提出しました。自己クローズは行わず、レビュアーによる独立再検証（`verify`）を要請します。

