# Section 13.7/13.8 — R1 Repair Execution Record

created: 2026-09-25 08:36 (JST)
update: 2026-09-25 08:36 (JST)
author: Auto (Composer)
plan: [implementation_plan_022_0925.md](implementation_plan_022_0925.md)
review: [s13_7_8_precedent_qa_review1_001_0925.md](s13_7_8_precedent_qa_review1_001_0925.md)

## 対象

QA HOLD 修復 **13.7.R1** / **13.8.R1** / **13.7/13.8.R2**。13.9+ は未着手。

## 対応

| ID | 結果 |
|---|---|
| 13.7.R1 | `assert_evidence_feature_v1()` を追加。query / historical / `complete_evidence_decision_feature_run` で使用。`historical-precedent-case-v1.json` の `evidence_feature` を `$ref: evidence-feature-v1.json` に拘束。不正 `minimal_feat` を canonical fixture に置換。負例（source欠落・core欠落・delta原子性・未知/禁止キー）追加。 |
| 13.8.R1 | `distance_scorable` を `version_compatible` から分離。feature-schema 不一致は Gower 前に `unscorable_cases`（`NOT_COMPARABLE`、距離なし）へ。辞書/delta のみ不一致は距離可能のまま返す。候補0は `[PRECEDENT_NO_SCORABLE_CASES]`。混合ライブラリ A/B/C テスト追加。 |
| 13.7/13.8.R2 | 下記検証。 |

## 検証結果（実装者）

| 検証 | 結果 |
|---|---|
| `Rscript tests/test_evidence_feature_extract.R` | **39** PASS / 0 FAIL |
| `Rscript tests/test_evidence_gower.R` | **39** PASS / 0 FAIL |
| `Rscript tests/test_evidence_cluster.R` | **53** PASS / 0 FAIL |
| `Rscript tests/test_evidence_precedent.R` | **37** PASS / 0 FAIL |
| `Rscript tests/run_regression_suite.R` | **46/46** PASS（86.95s） |
| `openspec validate comparative-evidence-reporting-v3 --strict` | valid |
| `git diff --check` | 問題なし |

独立 QA・Owner 判定・commit / push は未実施。
