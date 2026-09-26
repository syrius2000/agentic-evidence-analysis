# 実装計画 018 — Section 13 Phase B（13.4 Gower distance）

created: 2026-09-24 15:14 (JST)
author: Auto (Composer)
approval: ユーザー指示「規指摘なし…次は Section 13 Phase B、13.4 Gower distance に進んで問題ありません」を本範囲の実装承認として扱う

## 1. 目的

Phase A ACCEPT 後、OpenSpec Section 13 Phase B の先頭タスク **13.4** のみを実装する。

## 2. 範囲

| ID | 内容 | 本計画 |
|---|---|---|
| **13.4** | frozen `frozen_reference_range` による Gower 非類似度、`d_j = min(1, |x_i-x_j|/R_j)`、範囲超過時 `GOWER_REFERENCE_RANGE_EXCEEDED` | **実施** |
| 13.5–13.8 | 階層クラスタ / K-means / 版バインド / 先例検索 | **含めない**（別計画） |

## 3. 契約

1. **純 R 実装**（`cluster::daisy` の動的レンジに依存しない）。依存は `jsonlite` のみ（既存契約）。
2. **数値特徴**: 凍結 `[min,max]` から `R_j = max-min`。観測が境界外なら警告コードを記録し、値を境界へクリップしてから差分計算。寄与は常に `min(1, |·|/R_j)`。
3. **カテゴリ／論理**: 一致 0 / 不一致 1（simple matching）。
4. **欠損**: 片方でも NA/NULL の特徴はペアから除外し、利用可能特徴で平均（Gower 標準）。利用可能特徴が 0 なら Fail-Fast。
5. **版**: `frozen_reference_range` に `range_version` + `feature_schema_version` を必須化。
6. **出力**: ペア距離、距離行列、警告コード配列。決定ラベルは入力に含めない（特徴側は Phase A 契約を再利用）。

## 4. 変更対象

- `.agents/shared/evidence_gower.R`（新規）
- `schemas/frozen-reference-range-v1.json`（新規）
- `schemas/fixtures/frozen_reference_range_default_v1.json`（既定レンジ、新規）
- `tests/test_evidence_gower.R`（新規）
- `tests/run_regression_suite.R`（登録）
- `.agents/skills/evidence-decision-review/SKILL.md`（Phase B 13.4 追記）
- `openspec/.../tasks.md`、`design.md`（必要最小）
- `docs/Artifacts/s13_4_gower_exec_001_0924.md`

## 5. 検証

1. `Rscript tests/test_evidence_gower.R`
2. `Rscript tests/run_regression_suite.R`
3. `openspec validate comparative-evidence-reporting-v3 --strict`
4. `git diff --check`

commit / push は別指示まで行わない。13.5 へ進む前に計画更新と再承認を得る。
