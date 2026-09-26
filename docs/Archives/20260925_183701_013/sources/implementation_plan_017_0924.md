# 実装計画 017 — Section 13 Phase A QA修復（13.A.R1–R4）

created: 2026-09-24 14:45 (JST)
author: Auto (Composer)
approval: ユーザー指示「RepairPlan を実装して」を本範囲の実装承認として扱う
review: [s13_phaseA_qa_repair_001_0924.md](s13_phaseA_qa_repair_001_0924.md)

## 範囲

| ID | 内容 |
|---|---|
| 13.A.R1 | `RUN_SCOPE_SUPPORTED_SKILLS` 共通化、`read_run_control` に `evidence-decision-review`、完全 lifecycle（run_meta + manifest 結合） |
| 13.A.R2 | `clustering_feature_keys` を canonical enum に拘束（Option B） |
| 13.A.R3 | `delta_dependent.present` の条件付き原子状態 |
| 13.A.R4 | 対象テスト + run isolation + 正規回帰 + OpenSpec + diff を実施記録 |

Phase B（13.4+）には進まない。
