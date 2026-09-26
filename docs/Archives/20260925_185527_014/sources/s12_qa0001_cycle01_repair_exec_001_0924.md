# QA-0001 Cycle 1 修復 実施記録 001

created: 2026-09-24 13:50 (JST)
author: Auto (Composer)
plan: [implementation_plan_014_0924.md](implementation_plan_014_0924.md)
review: [s12_qa0001_cycle01_qa_001_0924.md](s12_qa0001_cycle01_qa_001_0924.md)

## 1. 対象

Cycle 1 Independent Review の Open Finding 4件（H01, M01–M03）を修復した。ベースは `feat/comparative-evidence-reporting-v3`（対象 revision `9a74bcf` 以降）。Section 11 / Section 13 は変更していない。

## 2. Finding 対応

| ID | 対応 |
|---|---|
| QA0001-H01 | `repeated_rows` に `cluster_cols` / `matched_cols` / `no_other_subject_dependence_confirmed` を追加。ヒューリスティック別名を拡張し設定列とマージ。負例: `facility_id`, `hospital_id`, `matched_group_id`, 設定カスタム列。 |
| QA0001-M01 | routing artifact に `engine_input`（`independent_binary_counts_v1`）を追加。同値で `run_independent_beta_binomial()` を呼ぶ統合テストを追加。 |
| QA0001-M02 | `schemas/pass0-routing-v1.json` を新設。反復行時は `subject_level_counts` と `engine_input` を条件付き必須化。 |
| QA0001-M03 | runtime と Draft-07 の valid/invalid 対偶フィクスチャを追加。列名相互非重複は runtime-only として明示。 |

## 3. 検証結果（実装者実行）

| 検証 | 結果 |
|---|---|
| `Rscript tests/test_pass0_routing.R` | 40 assertions PASS / 0 FAIL |
| `Rscript tests/test_comparative_schemas.R` | 122 assertions PASS / 0 FAIL |
| `Rscript tests/test_independent_beta_binomial.R` | 42 assertions PASS / 0 FAIL |
| `openspec validate comparative-evidence-reporting-v3 --strict --json` | valid, issue 0 |
| `git diff --check` | 問題なし |

独立 QA・Owner 判定・commit・push は未実施。本記録は実装者 Evidence であり、受入を主張しない。
