# 実装計画 021 — Section 13 Phase B グループ2（13.7–13.8 先例版バインド + 最近傍検索）

created: 2026-09-25 08:02 (JST)
update: 2026-09-25 08:02 (JST)
author: Auto (Composer)
approval: ユーザー指示「レビュー対応後、13.7–13.8 は進めてよいです」＋ Review1 Decision「13.7–13.8 may proceed」を本範囲の実装承認として扱う

## 1. 目的

1. **13.6.R1**（先行）: distinct standardized cases 検証を閉じる（Review1 M13.6-01）。
2. **13.7–13.8**: 歴史先例メタの版バインドと Gower 最近傍検索を実装する。

## 2. 範囲

| ID | 内容 | 本計画 |
|---|---|---|
| **13.6.R1** | `k <= n_distinct` Fail-Fast | **実施**（先行） |
| **13.7** | dictionary / delta_policy / feature_schema 版バインド | **実施** |
| **13.8** | 最近傍先例検索（距離 + 決定コンテキスト） | **実施** |
| 13.9–13.13 | ledger / discordance / trajectory / bootstrap | **含めない** |

## 3. 契約（13.7）

1. 歴史ケースは `historical-precedent-case-v1`。必須版フィールド:
   - `versions.dictionary_release_version`（例: MedDRA リリース文字列）
   - `versions.delta_policy_version`
   - `versions.feature_schema_version`
2. 決定ラベルは `decision_context` にのみ置き、Gower 入力の `evidence_feature` には含めない。
3. クエリと歴史ケースの版比較は明示結果を返す（不一致を黙殺しない）。`version_compatible` + `version_mismatches`。

## 4. 契約（13.8）

1. 距離は既存 `gower_pairwise` / `gower_distance_matrix`（凍結範囲・寄与クリップ）。
2. `retrieve_nearest_precedents()` は距離昇順で上位 `n_neighbors`（既定 5）を返す。
3. 各ヒットは距離、warnings、版互換フラグ、`decision_context` 全文、case_id を含む。
4. `require_version_match=TRUE` のとき版不一致ケースを除外。候補0なら Fail-Fast `[PRECEDENT_NO_COMPATIBLE_CASES]`。
5. 単一の処方的決定は返さない（分布提示用の raw 近傍リストのみ）。

## 5. 変更対象

- `.agents/shared/evidence_cluster.R`（13.6.R1）
- `.agents/shared/evidence_precedent.R`（新規）
- `schemas/historical-precedent-case-v1.json`（新規）
- `tests/test_evidence_precedent.R`（新規）+ regression 登録
- `tests/test_evidence_cluster.R`（13.6.R1）
- SKILL / design / tasks / QA Review1 チェック更新
- 実行証跡 Artifact

## 6. 検証

1. `Rscript tests/test_evidence_cluster.R`
2. `Rscript tests/test_evidence_precedent.R`
3. `Rscript tests/test_evidence_gower.R`
4. `Rscript tests/run_regression_suite.R`
5. `openspec validate comparative-evidence-reporting-v3 --strict`
6. `git diff --check`
