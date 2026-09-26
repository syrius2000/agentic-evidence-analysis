# 実装計画 022 — Section 13.7/13.8 QA修復（13.7.R1 / 13.8.R1）

created: 2026-09-25 08:32 (JST)
update: 2026-09-25 08:32 (JST)
author: Auto (Composer)
approval: ユーザー指示「指摘対応おねがいします」を本範囲の実装承認として扱う
review: [s13_7_8_precedent_qa_review1_001_0925.md](s13_7_8_precedent_qa_review1_001_0925.md)

## 1. 目的

Independent QA Review1（Downloads 正本と同内容）の HOLD を閉じる。

| ID | 内容 |
|---|---|
| **13.7.R1** | 正規 `assert_evidence_feature_v1()` + 歴史 schema の nested 拘束 |
| **13.8.R1** | `version_compatible` と `distance_scorable` を分離 |
| **13.7/13.8.R2** | 回帰ゲート |

## 2. 範囲外

- 13.9–13.13
- 13.6.R1（CLOSED 維持）

## 3. 変更対象

- `.agents/shared/evidence_feature_extract.R`
- `.agents/shared/evidence_precedent.R`
- `schemas/historical-precedent-case-v1.json`
- `tests/test_evidence_precedent.R`
- QA チェック更新 + 実行証跡

## 4. 検証

1. `Rscript tests/test_evidence_feature_extract.R`
2. `Rscript tests/test_evidence_gower.R`
3. `Rscript tests/test_evidence_cluster.R`
4. `Rscript tests/test_evidence_precedent.R`
5. `Rscript tests/run_regression_suite.R`
6. `openspec validate comparative-evidence-reporting-v3 --strict`
7. `git diff --check`
