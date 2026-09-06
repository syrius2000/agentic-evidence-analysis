---
id: QA-0001
title: "statistical-foundation-skill-migration"
document_type: spec-driven-qa-review
status: author-action-required
result: null
qa_profile: strict
risk_level: high
current_cycle: 2
created_at: "2026-09-06T22:38:17+09:00"
updated_at: "2026-09-06T23:16:52+09:00"
subject:
  targets:
    - "docs/Artifacts/statistical_foundation_skill_migration_plan_001_0906.md"
  implementation_revision: "c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480"
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
  high: {open: 0, resolved: 3}
  medium: {open: 2, resolved: 5}
  low: {open: 0, resolved: 0}
handoff_contract_version: "1.0"
---

# QA Pulse

| Item | Current |
|---|---|
| Status | `author-action-required` |
| Cycle | 2 / 3 |
| Implementation revision | `c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480` |
| Critical open | 0 |
| High open | 0 |
| Medium open | 2 |
| Next actor | `implementer` |
| Next action | Cycle 2 author-response for F04 and F06 |
| Updated | 2026-09-06 23:16 JST |

## 1. Purpose and Review Objective

計画の Purpose は、(1) 4軸セル診断・Leverage補正 Score・明示式 BIC・Dirichlet 推論の本番移植、(2) 旧セル Score の払拭、である。Cycle 1 検証では High 3 件を解消した。Stability 契約のゼロセル欠落と旧 CLI スキーマ残存が残る。

## 2. Scope

変更なし（Cycle 1 independent-review と同じ）。検証対象リビジョンは `c0ecbc1`。

## 3. Baseline

| Artifact | Revision |
|---|---|
| Cycle 0 implementation | `3d5fb36d1ab02210a721b10fe0c8b56b9a987b09` |
| Cycle 1 fix | `c0ecbc16057a66c61fcf1e4aeb0b4b207eb08480` |
| Reviewer HEAD at verification | `d12daeba1f258fdb4de04255899087f152919edb` |

## 4. Current Assessment

- Overall: High は解消。ケースは **未クローズ**（Medium 2 件が `partially-fixed`）。
- Pass 1 中核計算、Pass 2 数値整合、旧スコア生成経路の隔離、4 元ガード、BIC 掲載式、V 不変主張の撤回は独立に確認した。`CONFIRMED`
- F04 / F06 は作者主張どおり完了していない。`CONFLICT` with author `fix-submitted` completeness

## 5. Open Material Findings

| ID | Sev | Status | Remaining |
|---|---|---|---|
| QA-0001-F04 | Medium | open / partially-fixed | 文書の Stability 式がゼロセルを省略。`h=0.80` を跨ぐ fixture なし |
| QA-0001-F06 | Medium | open / partially-fixed | `config_validation.R` と `analysis_config.schema.json` に旧キーが残存 |

Verified this cycle: F01, F02, F03, F05, F07, F08, F09, F10.

## 6. Traceability Summary

See `traceability.yaml`. CLAIM-001/002/003/005 は概ね `supported`。スキーマ契約（CLAIM-004 の一部）と Stability 定義の完全一致は未完了。

## 7. Residual Risks

- `skill_out/` は gitignore。Pass 2/3 の数値整合は当該マシンのローカル成果物に依存する。
- `effectsize::cramers_v` は厳密な度数比不変量ではない（報告で明記済み）。
- 全セル DT の既定ソートは Score のまま。
- エンジン `log_p` は $\ln p$。作者回答の $-\log_{10}(P)$ は誤り（製品コードには未反映）。
- `tests/test_vcd_bayesian_pass2_stub.R` は旧トップレベル JSON のまま。
- Dual-Filter 閾値は SKILL 既定 `2000`、`analysis.R` 既定 `1000` が残る。

## 8. Latest Events

| Timestamp | Cycle | Actor | Action | Result |
|---|---:|---|---|---|
| 2026-09-06T22:38:17+09:00 | 0 | system | case_created | draft |
| 2026-09-06T22:41:20+09:00 | 1 | cursor-reviewer | independent-review | findings-issued |
| 2026-09-06T23:05:00+09:00 | 1 | antigravity-implementer | author-response | fix-submitted |
| 2026-09-06T23:16:52+09:00 | 1 | cursor-reviewer | reviewer-verification | partially-fixed |

## 9. Next Required Action

`REQUIRED:AUTHOR-RESPONSE:QA-0001-F04:CYCLE-2`

`REQUIRED:AUTHOR-RESPONSE:QA-0001-F06:CYCLE-2`

F04: コードの `y==0 | E<5 | h>=0.80` と文書式を一致させ、`h>=0.80` を跨ぐ fixture を追加する。  
F06: `config_validation.R` と `analysis_config.schema.json` から旧キーを削除するか、明示的に deprecated と記載する。
