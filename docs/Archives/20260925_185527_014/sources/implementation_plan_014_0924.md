# 実装計画 014 — QA-0001 Cycle 1 指摘修復（Section 12）

created: 2026-09-24 13:35 (JST)
author: Auto (Composer)
approval: ユーザー指示「QA指摘に則り実装開始」を本範囲の実装承認として扱う

## 1. 目的

[s12_qa0001_cycle01_qa_001_0924.md](s12_qa0001_cycle01_qa_001_0924.md) の Open Finding 4件を同一サイクルで修復する。Section 11 は変更しない。Section 13 以降には進まない。

| Finding | Severity | 修復内容 |
|---|---|---|
| QA0001-H01 | High | `repeated_rows` に明示的依存列と「他依存なし確認」を追加。ヒューリスティック別名を拡張し、設定列とマージしてガードする。 |
| QA0001-M01 | Medium | routing artifact に正規 `engine_input` を追加し、その値で `run_independent_beta_binomial()` を呼ぶ統合テストを追加する。 |
| QA0001-M02 | Medium | `schemas/pass0-routing-v1.json` を新設し、`subject_level_counts` / `engine_input` / `diagnostics.repeated_rows` を契約化する。 |
| QA0001-M03 | Medium | valid/invalid config fixture を runtime と Draft-07 の双方で検証し、runtime-only 不変条件を文書化する。 |

## 2. 変更対象

- `.agents/shared/pass0_routing.R`
- `schemas/pass0-config-v1.json`
- `schemas/pass0-routing-v1.json`（新規）
- `tests/test_pass0_routing.R`
- `tests/test_comparative_schemas.R`（parity / routing schema）
- `openspec/changes/comparative-evidence-reporting-v3/design.md`
- `openspec/changes/comparative-evidence-reporting-v3/specs/pass0-analysis-routing/spec.md`
- `docs/Artifacts/s12_qa0001_cycle01_repair_exec_001_0924.md`（実施記録）

本計画にないエンジン本体・解析データ・依存関係・Section 13 以降は変更しない。

## 3. 契約詳細

### H01

`repeated_rows` 必須追加:

- `no_other_subject_dependence_confirmed: true`
- 任意: `cluster_cols[]`, `matched_cols[]`

検出列 = ヒューリスティック別名 ∪ 設定列。非カノニカル負例: `facility_id`, `hospital_id`, `matched_group_id`。

### M01

```text
engine_input:
  contract: independent_binary_counts_v1
  target_events / target_total / reference_events / reference_total
  source: repeated_rows_any_event_collapse
```

### M03 runtime-only（schema 非表現）

- `subject_id_col` / `group_col` / `outcome_col` の相互非重複
- `target` ≠ `reference`
- 設定された依存列が入力データに実在すること（データ依存）

## 4. 検証

1. `Rscript tests/test_pass0_routing.R`
2. `Rscript tests/test_comparative_schemas.R`
3. `Rscript tests/test_independent_beta_binomial.R`（handoff 統合の前提）
4. `openspec validate comparative-evidence-reporting-v3 --strict --json`（利用可能な場合）
5. `git diff --check`

commit / push は行わない。
